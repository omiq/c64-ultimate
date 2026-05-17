/* --------------------------------------------------------------------
 * httptool.c  —  resident HTTP fetcher, BASIC SYS-callable
 * --------------------------------------------------------------------
 *
 * Lives at $C000 after `LOAD"HTTPTOOL",8,1`. BASIC drives it through
 * the JMP table set up in entry.s — each SYS address lands in one of
 * the hg_* functions below.
 *
 * All the HTTP/modem/ACIA plumbing is C; the response body is stashed
 * in the REU so BASIC can iterate any size of payload without eating
 * main RAM.
 *
 * SKELETON. The real fetch loop will be lifted from httpget-c/httpget.c
 * (which is proven working end-to-end). Each function below has a TODO
 * marking what to fill in.
 * -------------------------------------------------------------------- */

#include <stdint.h>
#include <string.h>

/* ====================================================================
 * REU 1750 register interface ($DF00-$DF0A).
 *
 * cc65 has <reu.h> for the c64 target but we build -t none so we
 * roll our own — saves the libc dependency and keeps the tool fully
 * standalone. Behaviour identical to reu_read/reu_write/etc.
 *
 * Operation:
 *   1. Set C64 RAM address ($DF02/03), REU address ($DF04-06),
 *      byte count ($DF07/08), address-control ($DF0A = $00).
 *   2. Write command to $DF01:
 *        $90 = stash (C64 → REU)   "FETCH"
 *        $91 = fetch (REU → C64)   "STASH"
 *      Wait — Commodore's naming is backwards from intuition. From
 *      C64's POV:
 *        $90 STASH  = "store from c64 INTO reu"
 *        $91 FETCH  = "fetch FROM reu into c64"
 *      We use those names below to match the datasheet.
 *   3. The CPU is halted during DMA; when our code resumes, transfer
 *      is complete.
 * ==================================================================== */
#define REU_STATUS   (*(volatile uint8_t*)0xDF00)
#define REU_CMD      (*(volatile uint8_t*)0xDF01)
#define REU_C64_LO   (*(volatile uint8_t*)0xDF02)
#define REU_C64_HI   (*(volatile uint8_t*)0xDF03)
#define REU_REU_LO   (*(volatile uint8_t*)0xDF04)
#define REU_REU_HI   (*(volatile uint8_t*)0xDF05)
#define REU_REU_BANK (*(volatile uint8_t*)0xDF06)
#define REU_LEN_LO   (*(volatile uint8_t*)0xDF07)
#define REU_LEN_HI   (*(volatile uint8_t*)0xDF08)
#define REU_IRQ_MASK (*(volatile uint8_t*)0xDF09)
#define REU_ADDR_CTL (*(volatile uint8_t*)0xDF0A)

#define REU_CMD_STASH   0x90      /* c64 -> reu, with FF00 trigger    */
#define REU_CMD_FETCH   0x91      /* reu -> c64, with FF00 trigger    */
#define REU_CMD_STASH_GO 0xB0     /* c64 -> reu, execute immediately  */
#define REU_CMD_FETCH_GO 0xB1     /* reu -> c64, execute immediately  */

/* helpers — REU addresses are 24-bit */
static void reu_stash(const void *c64_src, uint32_t reu_dst, uint16_t len) {
    REU_C64_LO   = (uint8_t)((uint16_t)c64_src & 0xFF);
    REU_C64_HI   = (uint8_t)((uint16_t)c64_src >> 8);
    REU_REU_LO   = (uint8_t)(reu_dst & 0xFF);
    REU_REU_HI   = (uint8_t)((reu_dst >> 8) & 0xFF);
    REU_REU_BANK = (uint8_t)((reu_dst >> 16) & 0xFF);
    REU_LEN_LO   = (uint8_t)(len & 0xFF);
    REU_LEN_HI   = (uint8_t)((len >> 8) & 0xFF);
    REU_ADDR_CTL = 0x00;
    REU_CMD      = REU_CMD_STASH_GO;
}

static void reu_fetch(void *c64_dst, uint32_t reu_src, uint16_t len) {
    REU_C64_LO   = (uint8_t)((uint16_t)c64_dst & 0xFF);
    REU_C64_HI   = (uint8_t)((uint16_t)c64_dst >> 8);
    REU_REU_LO   = (uint8_t)(reu_src & 0xFF);
    REU_REU_HI   = (uint8_t)((reu_src >> 8) & 0xFF);
    REU_REU_BANK = (uint8_t)((reu_src >> 16) & 0xFF);
    REU_LEN_LO   = (uint8_t)(len & 0xFF);
    REU_LEN_HI   = (uint8_t)((len >> 8) & 0xFF);
    REU_ADDR_CTL = 0x00;
    REU_CMD      = REU_CMD_FETCH_GO;
}

/* ====================================================================
 * Public state — exposed to BASIC via fixed zero-page slots.
 *
 * BASIC reads these with PEEK. We hold the canonical values in C
 * globals and copy them out into low memory (well-known addresses)
 * after each SYS call. Use addresses that BASIC doesn't normally
 * touch — picking a few free bytes around $02-$06.
 * ==================================================================== */
#define ZP_SIZE_LO   ((volatile uint8_t*)0x02)   /* body size low  */
#define ZP_SIZE_HI   ((volatile uint8_t*)0x03)   /* body size mid  */
#define ZP_SIZE_BANK ((volatile uint8_t*)0x04)   /* body size hi   */
#define ZP_LAST_BYTE ((volatile uint8_t*)0x05)   /* last read byte */
#define ZP_STATUS    ((volatile uint8_t*)0x06)   /* 0=ok, nonzero=error */

/* URL buffer that BASIC pokes into. We re-use the BASIC input buffer
 * at $0200 (cassette buffer area, 192 bytes — plenty for a URL). */
#define URL_BUF      ((const char*)0x0200)
#define URL_BUF_MAX  192

/* ====================================================================
 * NMI ring buffer (filled by nmi.s, drained here in C)
 * Same layout as httpget-c — nmi.s expects _ring + _ring_tail globals.
 * ==================================================================== */
unsigned char ring[256];
unsigned char ring_tail;
extern void nmi_handler(void);

/* ====================================================================
 * Internal state
 * ==================================================================== */
static uint32_t body_len;        /* bytes stashed in REU */
static uint32_t read_pos;        /* current REU read pointer */
static uint8_t  installed;       /* 1 once hg_install has run */

/* ====================================================================
 * SYS 49152 — hg_install
 *
 * One-time setup. Called by BASIC right after LOAD. Wires up ACIA,
 * installs NMI handler, claims REU. Safe to call multiple times.
 * ==================================================================== */
void hg_install(void) {
    /* TODO: copy ACIA init + NMI vector install from httpget.c */
    body_len = 0;
    read_pos = 0;
    *ZP_STATUS = 0;
    installed = 1;
}

/* ====================================================================
 * SYS 49155 — hg_fetch
 *
 * URL is in $0200 (NUL-terminated). Parse out host/port/path, dial,
 * send HTTP/1.1 GET, slurp body into REU starting at REU addr 0.
 *
 * Sets *ZP_SIZE_* to the byte count fetched. Sets *ZP_STATUS to 0 on
 * success, non-zero on error (1=parse, 2=dial, 3=timeout, etc.).
 * ==================================================================== */
void hg_fetch(void) {
    /* TODO:
     *  - parse URL_BUF into host/port/path
     *  - DTR-drop hangup any prior session
     *  - acia_send_str("ATDT<host>:<port>\n")
     *  - wait for connect / timeout
     *  - acia_send_str("GET <path> HTTP/1.1\r\nHost: <host>\r\n\r\n")
     *  - skip headers (\r\n\r\n)
     *  - stream body into REU via reu_write in chunks
     *  - update body_len + ZP_SIZE_*
     *  - hangup
     */
    body_len = 0;
    read_pos = 0;
    *ZP_SIZE_LO   = 0;
    *ZP_SIZE_HI   = 0;
    *ZP_SIZE_BANK = 0;
    *ZP_STATUS    = 0;
}

/* ====================================================================
 * SYS 49158 — hg_size
 *
 * Refresh *ZP_SIZE_* (in case BASIC clobbered the zp bytes between
 * calls). After this returns, BASIC can:
 *
 *   SZ = PEEK(2) + 256*PEEK(3) + 65536*PEEK(4)
 * ==================================================================== */
void hg_size(void) {
    *ZP_SIZE_LO   = (uint8_t)(body_len & 0xFF);
    *ZP_SIZE_HI   = (uint8_t)((body_len >> 8) & 0xFF);
    *ZP_SIZE_BANK = (uint8_t)((body_len >> 16) & 0xFF);
}

/* ====================================================================
 * SYS 49161 — hg_read
 *
 * Copy ONE byte from current REU read position into *ZP_LAST_BYTE
 * and auto-advance the pointer. BASIC then does:
 *
 *   B = PEEK(5)
 *
 * If we've reached body_len, return last byte = 0 and ZP_STATUS = 6
 * (EOF). Calling rewind resets to start.
 * ==================================================================== */
void hg_read(void) {
    uint8_t b = 0;
    if (read_pos < body_len) {
        reu_fetch(&b, read_pos, 1);
        read_pos++;
        *ZP_STATUS = 0;
    } else {
        *ZP_STATUS = 6;          /* EOF */
    }
    *ZP_LAST_BYTE = b;
}

/* ====================================================================
 * SYS 49164 — hg_rewind
 *
 * Reset REU read pointer to 0. BASIC's equivalent of RESTORE.
 * ==================================================================== */
void hg_rewind(void) {
    read_pos = 0;
    *ZP_STATUS = 0;
}

/* ====================================================================
 * SYS 49167 — hg_close
 *
 * Send hangup, leave modem in clean state. Doesn't uninstall — next
 * hg_fetch will dial again.
 * ==================================================================== */
void hg_close(void) {
    /* TODO: DTR drop hangup */
    *ZP_STATUS = 0;
}
