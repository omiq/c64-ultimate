/* --------------------------------------------------------------------
 * swift.c  —  C entry point for the SwiftDriver port
 * --------------------------------------------------------------------
 *
 * Most of the driver logic lives in hooks.s and nmi.s — they must be
 * asm because the KERNAL indirect vectors expect raw 6502 calling
 * conventions (A/X/Y in registers, RTS to return). cc65 always emits
 * a C function prologue, which would clobber those registers.
 *
 * What lives here:
 *
 *   swift_init()   — entry from SYS 49152. Installs the five KERNAL
 *                    vector pokes (NMI vec is installed inside DOOPEN
 *                    instead, only when device 2 is opened).
 *
 *   PHASE 2 will add: at_cmd_get(), at_cmd_post(), parse_url() etc.
 *   Those are pure C — no register/timing constraints.
 *
 * Why is swift_init() in C? It's not on a hot path (called once), so
 * the cc65 prologue cost is irrelevant. Putting it here means the
 * audience can read "what gets wired to what" in plain C.
 * -------------------------------------------------------------------- */

#include "swift.h"

/* --------------------------------------------------------------------
 * Tiny POKE helper. *(volatile uint8_t*)(addr) = v in one line.
 * volatile prevents the optimiser from caching writes to memory-mapped
 * I/O (not strictly needed here — these are RAM vectors — but cheap
 * insurance and consistent with how we'll touch $DE0x later).
 * -------------------------------------------------------------------- */
#define POKE(addr, val) (*(volatile uint8_t*)(addr) = (uint8_t)(val))

/* --------------------------------------------------------------------
 * install_vec(vec_addr, fn) — splat a 16-bit function pointer into
 * two consecutive bytes at vec_addr. The KERNAL stores its indirect
 * vectors little-endian (low byte at vec_addr, high byte at vec_addr+1).
 *
 * Helper is static inline so it disappears at -O — no call overhead.
 * -------------------------------------------------------------------- */
static void install_vec(uint16_t vec_addr, void (*fn)(void)) {
    uint16_t a = (uint16_t)fn;
    POKE(vec_addr,     a & 0xFF);   /* low byte first */
    POKE(vec_addr + 1, a >> 8);     /* then high byte */
}

/* ====================================================================
 * swift_init()  —  replaces Bo's INIT (swiftdrvr.asm lines 58-81).
 *
 * Called once via SYS 49152. Patches the five KERNAL indirect vectors
 * that route OPEN/CLOSE/CHRIN/GETIN/BSOUT through this driver:
 *
 *     $031A IOPEN   -> swift_do_open
 *     $031C ICLOSE  -> swift_do_close
 *     $0324 ICHRIN  -> swift_do_chrin
 *     $0326 IBSOUT  -> swift_do_put
 *     $032A IGETIN  -> swift_do_getin
 *
 * The NMI vector ($0318) is *not* touched here — DOOPEN installs it
 * lazily on the first OPEN for device 2. That way, programs that
 * load the driver "just in case" don't pay an NMI tax until they
 * actually need RS232.
 *
 * SEI/CLI bracket the writes so an interrupt firing between the two
 * bytes of a vector update can't dispatch through a half-written
 * pointer (unlikely with NMI alone, but cheap belt-and-braces).
 * ==================================================================== */
void swift_init(void) {
    __asm__("sei");                              /* mask IRQs */

    install_vec(IOPEN_VEC,  swift_do_open);
    install_vec(ICLOSE_VEC, swift_do_close);
    install_vec(ICHRIN_VEC, swift_do_chrin);
    install_vec(IGETIN_VEC, swift_do_getin);
    install_vec(IBSOUT_VEC, swift_do_put);

    __asm__("cli");                              /* re-enable IRQs */
}

/* --------------------------------------------------------------------
 * SYS 49152 entry trampoline.
 *
 * The first bytes of the loaded $C000 image must be `JMP swift_init`
 * so a user typing `SYS 49152` lands in our init. cc65's linker has
 * no built-in "make this function the very first code emitted" knob.
 * The cleanest approach is a single inline-asm `jmp` placed in a
 * .segment that the cfg pins to the start of CODE.
 *
 * For now we rely on swift.c being the first compilation unit and
 * swift_init being the first function — the linker normally honours
 * that. If it doesn't, the build adds an explicit `entry.s` shim.
 * -------------------------------------------------------------------- */
