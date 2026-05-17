/* --------------------------------------------------------------------
 * swift.h  —  public API for the C port of Bo Zimmerman's SwiftDriver
 * --------------------------------------------------------------------
 *
 * The driver wedges itself into the C64 KERNAL so existing BASIC code
 * keeps working unchanged:
 *
 *     LOAD "SWIFTDRV",8,1   : REM load this driver at $C000
 *     SYS 49152             : REM call swift_init() — installs hooks
 *     OPEN 5,2,0,CHR$(8)    : REM 1200 baud   (calls our DOOPEN)
 *     PRINT#5,"hello"       : REM             (calls our DOPUT)
 *     GET#5,A$              : REM             (calls our DOGETIN)
 *     CLOSE 5               : REM             (calls our DOCLOSE)
 *
 * Baud codes (4th OPEN param) match Bo's table and cc65 conventions:
 *
 *     1 = 50      6 = 300     11 = 3600
 *     2 = 75      7 = 600     12 = 4800
 *     3 = 110     8 = 1200    13 = 7200
 *     4 = 135     9 = 1800    14 = 9600
 *     5 = 150    10 = 2400    15 = 19200
 * -------------------------------------------------------------------- */

#ifndef SWIFT_H
#define SWIFT_H

#include <stdint.h>

/* -------- ACIA 6551 register addresses (SwiftLink @ $DE00) -------- */
#define ACIA_DATA     0xDE00     /* read=RX byte, write=TX byte       */
#define ACIA_STATUS   0xDE01     /* bit3=RX ready, bit4=TX ready      */
#define ACIA_COMMAND  0xDE02     /* parity, echo, DTR, IRQ enables    */
#define ACIA_CONTROL  0xDE03     /* baud rate, word size, stop bits   */

/* -------- KERNAL indirect vectors we hijack ---------------------- */
#define IOPEN_VEC     0x031A     /* OPEN     -> DOOPEN                */
#define ICLOSE_VEC    0x031C     /* CLOSE    -> DOCLOSE               */
#define ICHKIN_VEC    0x031E     /* (Bo skips — KERNAL handles dev 2) */
#define ICHRIN_VEC    0x0324     /* CHR-IN   -> DOCHRIN               */
#define IBSOUT_VEC    0x0326     /* BSOUT    -> DOPUT                 */
#define IGETIN_VEC    0x032A     /* GETIN    -> DOGETIN               */
#define NMI_VEC       0x0318     /* NMI      -> nmi_handler (asm)     */

/* -------- zero-page locations the driver re-uses ----------------- *
 * Bo reuses the same zp bytes the KERNAL RS232 routines use, so we
 * inherit the buffer pointer ($F7/$F8) that $F34A (KERNAL IOPEN)
 * allocates on our behalf. Do not change these without also patching
 * nmi.s, which reads them directly.
 * ----------------------------------------------------------------- */
#define ZP_RHEAD      0x00A7     /* ring buffer read index (0..255)   */
#define ZP_RTAIL      0x00A8     /* ring buffer write index (0..255)  */
#define ZP_RBUFF      0x00F7     /* 16-bit ptr to ring buf page       */
#define ZP_RCOUNT     0x00B4     /* total bytes seen (stat counter)   */
#define ZP_ERRORS     0x00B5     /* last STATUS byte at NMI time      */
#define ZP_XMO        0x00B6     /* COMMAND reg, RX-only state        */
#define ZP_XMF        0x00BD     /* COMMAND reg, RX+IRQ state         */

/* -------- public entry points ------------------------------------ *
 * These three are what the user calls from BASIC via SYS, plus the
 * implicit OPEN/CLOSE/GET#/PRINT# wedges.
 * ----------------------------------------------------------------- */

void swift_init(void);          /* install KERNAL hooks. SYS 49152.  */

/* The functions below are not called directly from BASIC — they are
 * installed as KERNAL vector replacements by swift_init(). They are
 * exposed in the header for the test harness. */

void swift_do_open(void);       /* IOPEN replacement when dev=2      */
void swift_do_close(void);      /* ICLOSE replacement when dev=2     */
void swift_do_chrin(void);      /* CHRIN replacement when curdev=2   */
void swift_do_getin(void);      /* GETIN replacement when curdev=2   */
void swift_do_put(void);        /* BSOUT replacement when curdev=2   */

/* The NMI handler lives in nmi.s — declared here so swift_init() can
 * take its address and poke it into NMI_VEC. */
extern void nmi_handler(void);

#endif /* SWIFT_H */
