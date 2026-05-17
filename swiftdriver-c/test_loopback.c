/* --------------------------------------------------------------------
 * test_loopback.c  —  smoke test for the C SwiftDriver
 * --------------------------------------------------------------------
 *
 * Builds as a separate .prg that:
 *   1. Assumes swiftdrv.prg has already been loaded at $C000
 *      (done from BASIC: LOAD "SWIFTDRV",8,1 then SYS 49152 then RUN
 *       another loader BASIC line that loads this .prg).
 *   2. Opens device 2 at 1200 baud, sends "AT\r", reads response,
 *      prints it to screen.
 *
 * For now this is also a SKELETON — fills in when swift.c bodies done.
 * -------------------------------------------------------------------- */

#include <stdio.h>
#include <conio.h>

int main(void) {
    clrscr();
    cputs("swiftdrv c-port loopback test\r\n");
    cputs("(skeleton — fill in once swift.c is done)\r\n");
    /* TODO:
     *  cbm_open(5, 2, 0, "\x08");   // 1200 baud (chr$(8))
     *  cbm_write(5, "AT\r", 3);
     *  poll cbm_read(5, ...) for a while, print bytes.
     *  cbm_close(5);
     */
    return 0;
}
