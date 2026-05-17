; --------------------------------------------------------------------
; entry.s  —  the very first bytes at $C000.
;
; Two jobs:
;   1. Be the first thing in the CODE segment so SYS 49152 lands in
;      our `jmp _swift_init`.
;   2. Emit a 2-byte PRG load-address header at $0000 so the .prg
;      loads at $C000 instead of relocating to BASIC.
;
; ca65 places the EXEHDR segment first per the linker cfg.
; --------------------------------------------------------------------

.import     _swift_init

.segment    "EXEHDR"
        .word $C000             ; PRG load address: 00 C0 (little-endian)

.segment    "CODE"
        jmp _swift_init         ; SYS 49152 lands here -> init()
