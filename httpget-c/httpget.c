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
#define HOST   "php.retrogamecoders.com"
#define PORT   "80"
#define PATH   "/"

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

/* One-shot hardware init. Status-register write of any value resets
 * the ACIA per the WDC65C51 datasheet — must do this first. */
static void acia_init(void) {
    ACIA_STATUS  = 0;               /* soft reset */
    delay(2000);                    /* let it settle */
    ACIA_CONTROL = CTRL_1200_8N1;
    ACIA_COMMAND = CMD_POLLED;
}

/* Non-blocking receive. Returns 1 + writes byte to *out if a byte
 * was ready; 0 if RX buffer empty. */
static uint8_t acia_recv(uint8_t *out) {
    if (ACIA_STATUS & ST_RX_READY) {
        *out = ACIA_DATA;
        return 1;
    }
    return 0;
}

/* Blocking send. Spins on STATUS bit 4 until the TX register can
 * accept a byte, then writes it. */
static void acia_send(uint8_t b) {
    while (!(ACIA_STATUS & ST_TX_EMPTY)) { }
    ACIA_DATA = b;
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

/* Wait for a substring (case-insensitive) to appear in the RX stream.
 * Echoes everything received. Returns 1 on match, 0 on timeout.
 *
 * `idle_secs` ≈ how many seconds of silence we tolerate before giving
 * up. Each iteration is a few µs on stock C64; we treat 200000 iters
 * as roughly one second of polling at our speed. */
static uint8_t wait_for(const char *needle, uint8_t idle_secs) {
    uint8_t  nlen = strlen(needle);
    uint8_t  pos = 0;
    uint8_t  b;
    uint32_t budget = (uint32_t)idle_secs * 200000UL;
    uint32_t left = budget;

    while (left--) {
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

/* Send the standard Hayes hangup sequence.
 *
 * Hayes guard time spec: at least 1 second of NO data BEFORE +++ and
 * AT LEAST 1 second AFTER, otherwise modem treats +++ as data and
 * stays in online mode. We use 1.5s both sides to be safe. */
static void hangup(void) {
    cputs("\n\rhangup...\n\r");
    delay_tenths(15);               /* 1.5s guard before +++ */
    acia_send_str("+++");
    delay_tenths(15);               /* 1.5s guard after  +++ */
    acia_send_str("ATH\r");
    delay_tenths(10);
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
    cputc(14);                      /* switch to lower/uppercase mode */
    cputs("httpget v1\n\r");
    cputs("target: " HOST ":" PORT PATH "\n\r\n\r");

    cputs("init acia 1200 8n1...\n\r");
    acia_init();

    cputs("drain...\n\r");
    drain(3000);

    hangup();

    /* Force modem into VERBOSE response mode (CONNECT not 1) plus
     * echo on (so we see what we send). Some modems / C64U firmware
     * default to terse numeric responses. We don't care about the
     * response to THIS command — just drain and proceed. */
    cputs("\n\rconfig modem (atv1e1)...\n\r");
    acia_send_str("ATV1E1\r");
    delay_tenths(10);
    drain(3000);

    cputs("\n\rdialing...\n\r");
    acia_send_str("ATDT " HOST ":" PORT "\r");

    /* Wait for CONNECT (verbose) or 1 (numeric — in case ATV1 didn't
     * take). Try CONNECT first since most C64U firmware does verbose
     * after ATV1. */
    cputs("\n\rwaiting connect...\n\r");
    if (!wait_for("CONNECT", 60)) {
        cputs("\n\rno connect - abort\n\r");
        return 1;
    }
    cputs("\n\rCONNECTED\n\r\n\r");

    /* small pause before sending request */
    delay(20000);

    cputs("sending GET...\n\r");
    acia_send_str("GET " PATH " HTTP/1.1\r\n"
                  "Host: " HOST "\r\n"
                  "Connection: close\r\n"
                  "\r\n");

    /* open the SEQ result file */
    cputs("opening " RESULT_FILE "...\n\r");
    fd_status = cbm_open(RESULT_LFN, RESULT_DEV, RESULT_SA, RESULT_FILE);
    if (fd_status != 0) {
        cputs("file open failed — body only goes to screen\n\r");
    }

    cputs("\n\r--- response ---\n\r");

    /* Receive loop:
     *   - Echo every byte to screen
     *   - Once past the 4-byte \r\n\r\n header terminator, also
     *     append to the SEQ file
     *   - Exit when RX stays silent for "idle" iterations
     */
    idle = 0;
    while (idle < 30000) {
        if (!acia_recv(&b)) {
            idle++;
            continue;
        }
        idle = 0;
        cputc(b);

        /* Header-skip state machine: count consecutive CR/LF bytes.
         * 4 in a row = end of headers (CRLF CRLF). */
        if (in_headers) {
            if (b == 13 || b == 10) {
                cr_lf_count++;
                if (cr_lf_count >= 4) {
                    in_headers = 0;
                    cputs("\n\r--- body ---\n\r");
                }
            } else {
                cr_lf_count = 0;
            }
        } else {
            /* In body — write to SEQ file too. */
            if (fd_status == 0) {
                cbm_write(RESULT_LFN, &b, 1);
            }
            body_bytes++;
        }
    }

    if (fd_status == 0) {
        cbm_close(RESULT_LFN);
    }

    cputs("\n\r--- done ---\n\r");
    cprintf("body bytes saved: %u\n\r", body_bytes);

    hangup();
    return 0;
}
