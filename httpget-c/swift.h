/* --------------------------------------------------------------------
 * swift.h  —  thin C wrapper around Bo Zimmerman's SwiftDriver
 * --------------------------------------------------------------------
 *
 * Bo's driver is 292 bytes of proven 6502 assembly that wedges into
 * the C64 KERNAL's OPEN/CLOSE/CHRIN/GETIN/BSOUT vectors. Once
 * installed, the normal cc65 cbm_open/cbm_read/cbm_write calls just
 * work — they route through Bo's hooks and out the SwiftLink ACIA.
 *
 * This header gives us idiomatic-looking C names. The driver bytes
 * are embedded as a const blob in swiftdrvr_blob.h.
 * -------------------------------------------------------------------- */

#ifndef SWIFT_H
#define SWIFT_H

#include <stdint.h>
#include <cbm.h>
#include <string.h>

#include "swiftdrvr_blob.h"   /* extern unsigned char swiftdrvr_bin[]; */

#define SWIFT_LOAD_ADDR  ((void*)0xC000)

/* Install Bo's driver: copy bytes to $C000, call its INIT (which patches
 * the KERNAL indirect vectors at $031A-$032B and $0318 NMI). After this
 * the normal cbm_open(...,2,...) calls go through SwiftLink. */
static void swift_install(void) {
    memcpy(SWIFT_LOAD_ADDR, swiftdrvr_bin, swiftdrvr_bin_len);
    __asm__("jsr $C000");           /* run INIT */
}

/* Open the modem at the given baud code (Bo's table: 7=600, 8=1200,
 * ..., 14=9600, 15=19200). Returns same status code as cbm_open. */
static uint8_t swift_open(uint8_t lfn, uint8_t baud_code) {
    char name[2];
    name[0] = (char)baud_code;
    name[1] = 0;
    return cbm_open(lfn, 2, 0, name);
}

/* Send a NUL-terminated C string through the modem. cc65 string
 * literals are PETSCII; we translate uppercase/lowercase letters to
 * ASCII on the wire (the modem and HTTP server expect ASCII). */
static void swift_send_str(uint8_t lfn, const char *s) {
    uint8_t b;
    while (*s) {
        b = (uint8_t)*s++;
        if      (b >= 0xC1 && b <= 0xDA) b -= 0x80;   /* PETSCII upper → ASCII upper */
        else if (b >= 0x41 && b <= 0x5A) b += 0x20;   /* PETSCII lower → ASCII lower */
        cbm_write(lfn, &b, 1);
    }
}

/* Non-blocking single-byte recv. Returns 1 if got byte (into *out),
 * 0 if nothing pending right now. KERNAL ST bit 6 (=0x40) = empty. */
static uint8_t swift_recv(uint8_t lfn, uint8_t *out) {
    if (cbm_read(lfn, out, 1) == 1) return 1;
    return 0;
}

static void swift_close(uint8_t lfn) {
    cbm_close(lfn);
}

#endif
