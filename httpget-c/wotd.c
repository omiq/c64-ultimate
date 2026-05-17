/* --------------------------------------------------------------------
 * httpget.c  —  pure-C HTTP client for C64 + SwiftLink
 * --------------------------------------------------------------------
 *
 * Talks directly to the 6551 ACIA at $DE00 (SwiftLink slot) — NO
 * KERNAL RS232 hooks, NO interrupts, just polled I/O. Trade: CPU
 * busy-waits during transfer. Win: zero zero-page collisions, zero
 * driver-install steps, fully self-contained .prg.
 *
 * Flow:
 *   1. Init ACIA (1200 baud, 8N1, polled mode).
 *   2. Drain anything sitting in RX (prior session, modem chatter).
 *   3. Hangup any prior call ( "+++" guard "ATH" ).
 *   4. Dial: "ATDT <HOST>:<PORT>\r".
 *   5. Wait for "CONNECT" substring (case-insensitive).
 *   6. Send: "GET <PATH> HTTP/1.1\r\nHost: <HOST>\r\n\r\n".
 *   7. Skip HTTP headers (wait for double CRLF).
 *   8. Read body, simultaneously:
 *        a. echo to screen (visual debug)
 *        b. append to SEQ file "HGRESULT" on drive 8
 *   9. Close file, "+++ATH" hangup, exit to BASIC.
 *
 * For Phase-1 simplicity the URL is hardcoded — see HOST/PATH/PORT
 * macros below. Adding cmdline / memory-passed URL is trivial later.
 * -------------------------------------------------------------------- */

#include <stdio.h>
#include <conio.h>
#include <string.h>
#include <stdint.h>
#include <cbm.h>            /* cbm_open / cbm_write / cbm_close */

/* ====================================================================
 * Target URL — hardcoded for v1. Change & rebuild for now.
 * ==================================================================== */
  #define HOST   "bbs.retrogamecoders.com"
  #define PORT   "6464"
#define PATH   ""

/* ====================================================================
 * ACIA 6551 (SwiftLink) at $DE00
 * ==================================================================== */
#define ACIA_DATA     (*(volatile uint8_t*)0xDE00)
#define ACIA_STATUS   (*(volatile uint8_t*)0xDE01)
#define ACIA_COMMAND  (*(volatile uint8_t*)0xDE02)
#define ACIA_CONTROL  (*(volatile uint8_t*)0xDE03)

/* STATUS register bits */
#define ST_RX_READY   0x08      /* bit 3: byte available to read   */
#define ST_TX_EMPTY   0x10      /* bit 4: TX register can accept a byte */

/* CONTROL byte: baud / word / stop bits / clock-source
 *   bits 0-3 = baud index (8 = 1200 baud)
 *   bit 4    = 1 → internal baud generator
 *   bits 5-6 = 00 → 8 data bits
 *   bit 7    = 0 → 1 stop bit
 *
 * 1200 baud is the sweet spot: fast enough that a multi-KB response
 * doesn't take all day, slow enough that polled C keeps up without
 * loss even when echoing every byte to screen.
 */
#define CTRL_1200_8N1   0x18

/* COMMAND byte: parity / echo / IRQ enables / DTR
 *   bit 0    = 1 → DTR asserted (we're "online")
 *   bit 1    = 1 → RX IRQ disabled  (we poll, no NMI)
 *   bits 2-3 = 10 → RTS asserted, TX IRQ disabled
 *   bit 4    = 0 → no local echo
 *   bits 5-7 = 0 → no parity
 */
#define CMD_POLLED      0x0B

/* SEQ file on disk where body gets saved for BASIC to consume. */
#define RESULT_FILE     "HGRESULT,S,W"
#define RESULT_LFN      2       /* logical file number */
#define RESULT_DEV      8       /* drive 8 */
#define RESULT_SA       2       /* secondary address — non-zero =
                                   honour name & ,S,W type spec */

/* ====================================================================
 * Busy-loop delay measured in tenths of a second. cc65 compiles the
 * inner loop to roughly 20 cycles/iter; 50000 iters ≈ 1s @ 1MHz.
 * We multiply by tenths to compose longer waits without uint16 overflow.
 * ==================================================================== */
static void delay_tenths(uint16_t tenths) {
    uint16_t i;
    while (tenths--) {
        for (i = 0; i < 5000; i++) { __asm__("nop"); }
    }
}

/* legacy helper for tiny waits — keep at 100ms */
static void delay(uint16_t loops) {
    while (loops--) { __asm__("nop"); }
}

/* ====================================================================
 * ACIA primitives
 * ==================================================================== */

/* ====================================================================
 * NMI ring buffer (filled by nmi.s, drained here in C)
 *
 * Same idea as CCGMS / Bo Zimmerman SwiftDriver: when the 6551 has a
 * byte, it raises NMI via SwiftLink's IRQ-to-NMI wire. Our ISR (in
 * nmi.s) grabs the byte and pushes it into this 256-byte ring. C code
 * here just drains the ring at its own pace — no byte loss during
 * cputc / disk writes / etc.
 *
 * Both `ring` and `ring_tail` are referenced from asm via the symbols
 * `_ring` / `_ring_tail` (cc65 prepends the underscore).
 * ==================================================================== */
unsigned char ring[256];             /* 256-byte ring buffer */
unsigned char ring_tail;             /* ISR-only write index (wraps) */
static unsigned char ring_head;      /* main-thread read index */

extern void nmi_handler(void);       /* defined in nmi.s */

/* Init replicating simple-c.bas's exact sequence (proven to work):
 *   POKE 56833,0   -> reset ACIA
 *   POKE 56835,31  -> CONTROL = $1F (19200, 8N1, internal clock)
 *   POKE 56834,9   -> COMMAND = $09 (DTR on, RX IRQ on)
 *   wait ~500ms
 *   SYS swift_init / cbm_open      -> KERNAL RS232 setup
 *   COMMAND = $09                  -> ensure RX IRQ on after KERNAL
 *   install NMI vector             -> our ring-buffer ISR
 */
#define ACIA_LFN  6
static uint8_t acia_init(void) {
    static const char baud_name[2] = { 8, 0 };
    uint8_t st;

    /* Bo's SwiftDriver DOOPEN order:
     *   1. JSR $F34A (KERNAL OPEN — alloc RS232 buffer)
     *   2. Set ACIA CONTROL from baud byte
     *   3. Set ACIA COMMAND = $09
     *   4. Install NMI vector
     *
     * We match exactly. The earlier "POKE before cbm_open" order was
     * a misread of simple-c.bas (those POKEs happened before SYS, not
     * before OPEN — OPEN went through SwiftDriver which redid ACIA). */

    /* Step 1: KERNAL OPEN first — alloc RS232 buffer at top of mem */
    st = cbm_open(ACIA_LFN, 2, 0, baud_name);

    /* Step 2: configure ACIA for 1200 baud, 8N1 */
    ACIA_STATUS  = 0;                /* soft reset */
    ACIA_CONTROL = 0x18;             /* CHR$(8) | $10 = 1200 baud */
    delay_tenths(2);

    /* Step 3: COMMAND = DTR on, RX IRQ on */
    ACIA_COMMAND = 0x09;

    /* Step 4: install NMI vector → our ring-buffer ISR */
    ring_head = 0;
    ring_tail = 0;
    __asm__("sei");
    *(volatile uint8_t*)0x0318 = (uint8_t)((uint16_t)nmi_handler & 0xFF);
    *(volatile uint8_t*)0x0319 = (uint8_t)((uint16_t)nmi_handler >> 8);
    __asm__("cli");

    return st;
}

static void acia_close(void) {
    /* restore default NMI vector before closing */
    __asm__("sei");
    *(volatile uint8_t*)0x0318 = 0x47;
    *(volatile uint8_t*)0x0319 = 0xFE;
    __asm__("cli");
    cbm_close(ACIA_LFN);
}

/* Non-blocking receive from ring buffer. Returns 1 + writes byte to
 * *out if a byte was pending; 0 if ring is empty. */
static uint8_t acia_recv(uint8_t *out) {
    if (ring_head == ring_tail) return 0;
    *out = ring[ring_head++];        /* wraps at 256 automatically */
    return 1;
}

/* Blocking send with PETSCII→ASCII translation + inter-byte delay.
 *
 * cc65's c64 target stores C string literals as PETSCII bytes.
 * Translation to ASCII:
 *   PETSCII $C1-$DA → ASCII $41-$5A (uppercase)
 *   PETSCII $41-$5A → ASCII $61-$7A (lowercase)
 *
 * Inter-byte delay (~50ms) matches CCGMS's human-typing rate. The
 * C64U virtual modem's AT-command parser seems to need this — fast
 * back-to-back bytes get accepted as echo but never parsed as a
 * complete command. CCGMS works because humans type slowly. */
static void acia_send(uint8_t b) {
    uint16_t i;
    if (b >= 0xC1 && b <= 0xDA)      b -= 0x80;
    else if (b >= 0x41 && b <= 0x5A) b += 0x20;

    while (!(ACIA_STATUS & ST_TX_EMPTY)) { }
    ACIA_DATA = b;
    /* ~50ms inter-byte delay (loop tuned by eye on 1MHz C64) */
    for (i = 0; i < 2500; i++) { __asm__("nop"); }
}

/* Convenience: send a NUL-terminated C string. */
static void acia_send_str(const char *s) {
    while (*s) acia_send(*s++);
}

/* ====================================================================
 * Higher-level helpers
 * ==================================================================== */

/* Drain RX until silent for `quiet` consecutive empty polls.
 * Echoes drained bytes to screen so we see leftover noise. */
static void drain(uint16_t quiet) {
    uint16_t q = 0;
    uint8_t  b;
    while (q < quiet) {
        if (acia_recv(&b)) {
            q = 0;
            cputc(b);
        } else {
            q++;
        }
    }
}

/* Case-insensitive match of single character. */
static uint8_t ieq(uint8_t a, uint8_t b) {
    if (a >= 'A' && a <= 'Z') a += 32;
    if (b >= 'A' && b <= 'Z') b += 32;
    return a == b;
}

/* STOP-key check via the KERNAL's stop-key scan latch at $91.
 * Bit 7 = 0 when STOP held. Lets the user escape long busy-waits. */
#define STOP_PRESSED  ((*(volatile uint8_t*)0x0091 & 0x80) == 0)

/* Wait for a substring (case-insensitive) to appear in the RX stream.
 * Echoes everything received. Returns:
 *   1 = match
 *   0 = timeout
 *   2 = user pressed STOP
 *
 * Loop body costs ~25 cycles, so budget = idle_secs * 40000 ≈ 1 wall
 * second per "second" unit on stock C64 (1MHz). */
static uint8_t wait_for(const char *needle, uint8_t idle_secs) {
    uint8_t  nlen = strlen(needle);
    uint8_t  pos = 0;
    uint8_t  b;
    uint32_t budget = (uint32_t)idle_secs * 40000UL;
    uint32_t left = budget;

    while (left--) {
        if (STOP_PRESSED) {
            cputs("\n\r[STOP]\n\r");
            return 2;
        }
        if (acia_recv(&b)) {
            cputc(b);
            if (ieq(b, needle[pos])) {
                pos++;
                if (pos == nlen) return 1;
            } else {
                pos = ieq(b, needle[0]) ? 1 : 0;
            }
            left = budget;          /* reset on any byte (still alive) */
        }
    }
    return 0;
}

/* Force clean hangup: DTR drop only.
 *
 * Tested: simple-c (BASIC + C driver) without +++ATH connects fine
 * to Python server. WITH +++ATH it breaks modem state and ERRORs
 * subsequent commands. So we just drop DTR and let modem auto-reset. */
static void hangup(void) {
    cputs("\n\rhangup (dtr drop only)...\n\r");

    /* DTR off: bit 0=0, keep bit 3=1 (RTS low) */
    ACIA_COMMAND = 0x08;
    delay_tenths(10);               /* ~1s with DTR low */
    ACIA_COMMAND = 0x09;            /* DTR back on, RX IRQ on */
    delay_tenths(5);                /* settle */
    drain(3000);
}

/* ====================================================================
 * main — orchestrates the fetch
 * ==================================================================== */
int main(void) {
    uint8_t  b;
    uint16_t idle;
    uint16_t body_bytes = 0;
    uint8_t  cr_lf_count = 0;
    uint8_t  in_headers = 1;
    uint8_t  fd_status;

    clrscr();
    bordercolor(COLOR_BLUE);
    textcolor(COLOR_WHITE);

    cputs("init\n\r");
    {
        uint8_t st = acia_init();
        cprintf("kernal open: %u\n\r", st);
        /* Don't bail on non-zero — RS232 OPEN has weird status
         * semantics. Proceed and see if ACIA still works. */
    }

    acia_send_str("AT\n");
    {
        uint8_t  secs;
        uint16_t inner;
        uint8_t  b;
        for (secs = 0; secs < 3; secs++) {
            for (inner = 0; inner < 5000; inner++) {
                if (STOP_PRESSED) return 2;
                if (acia_recv(&b)) cputc(b);
            }
        }
    }

    cputs("\n\rdialing...\n\r");
    acia_send_str("ATDT" HOST ":" PORT "\n");

      

    /* Receive loop:
     *   - Echo every byte to screen
     *   - Once past the 4-byte \r\n\r\n header terminator, also
     *     append to the SEQ file
     *   - Exit when RX stays silent for ~30 seconds (server done)
     *   - Allow STOP key to abort
     *
     * Idle budget: 30 sec * 40000 iters/sec = 1.2M iters before bail.
     * Resets to 0 every time a byte arrives, so a slow start or
     * mid-transfer pause is fine.
     */
    /* Silent receive — uint16 counters keep loop body cheap so
     * timeouts are predictable. Outer loop = "seconds" via inner
     * count. Inner ~12000 iters ≈ 1 sec wall-clock on 1MHz C64
     * (rough cc65 calibration — bump if too fast). */
    {
        uint16_t inner;
        uint8_t  silent_secs = 0;
        uint16_t total_rx = 0;
        const uint8_t MAX_IDLE_SECS = 10;

        while (silent_secs < MAX_IDLE_SECS) {
            uint8_t got_this_sec = 0;
            for (inner = 0; inner < 12000; inner++) {
                if (STOP_PRESSED) { cputs("\n\r[STOP]\n\r"); goto recv_done; }
                if (!acia_recv(&b)) continue;
                got_this_sec = 1;
                total_rx++;

                /* echo to screen — safe with NMI ring buffer absorbing
                 * bytes while cputc scrolls. Print printable ascii as
                 * char, control bytes as <NN> for visibility. */
                switch (b) {
                case 35:
                    cputs("\r\n");
                    break;
                case 13:
                    cputs("\r");
                    break;
                case 10:
                    cputs("\n");
                    break;
                default:
                    if (b >= 32 && b < 127)
                        cputc(b);
                    else
                        cprintf("<%02x>", b);
                    break;
                }

                if (in_headers) {
                    if (b == 13 || b == 10) {
                        cr_lf_count++;
                        if (cr_lf_count >= 4) {
                            in_headers = 0;
                            
                        }
                    } else {
                        cr_lf_count = 0;
                    }
                } else {
                    if (fd_status == 0) cbm_write(RESULT_LFN, &b, 1);
                    body_bytes++;
                }
            }
            if (got_this_sec) silent_secs = 0;
            else              silent_secs++;
        }
recv_done:
        cprintf("\n\rtotal bytes: %u\n\r", total_rx);
    }


    hangup();
    acia_close();
    return 0;
}
