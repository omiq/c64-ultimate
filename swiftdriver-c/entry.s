; --------------------------------------------------------------------
; entry.s  —  PRG header + swift_init (pure asm port)
; --------------------------------------------------------------------
;
; Two jobs:
;   1. Emit the 2-byte PRG load-address header ($C000) so the file
;      loads at $C000 instead of relocating to BASIC.
;   2. Provide _swift_init as the first instruction at $C000 — the
;      jump target of `SYS 49152`.
;
; swift_init is in pure asm (not C) because Phase 1 doesn't need
; anything from cc65's C runtime, and avoiding C means we don't have
; to manage cc65's software stack / zero-page allocations. Phase 2
; (AT command layer) will introduce C, but by then the driver is
; already installed and stable.
;
; Replaces Bo's INIT block (swiftdrvr.asm lines 58-81).
; --------------------------------------------------------------------

; ===== KERNAL indirect vectors we hijack =====
IOPEN_VEC   = $031A             ; OPEN
ICLOSE_VEC  = $031C             ; CLOSE
ICHRIN_VEC  = $0324             ; CHRIN
IGETIN_VEC  = $032A             ; GETIN
IBSOUT_VEC  = $0326             ; BSOUT

; ===== external symbols (hook bodies live in hooks.s) =====
.import _swift_do_open
.import _swift_do_close
.import _swift_do_chrin
.import _swift_do_getin
.import _swift_do_put

; ===== PRG load-address header (2 bytes at start of .prg) =====
.segment "EXEHDR"
        .word $C000

; ===== code, starting at $C000 =====
.segment "CODE"

; --------------------------------------------------------------------
; swift_init  —  patch the 5 KERNAL indirect vectors and return.
;
; SEI/CLI bracket the writes so an interrupt firing between the lo and
; hi byte of a vector can't dispatch through a half-formed pointer.
;
; install_vec_inline is implemented as a macro so each call expands to
; four bytes (LDA #lo / STA vec / LDA #hi / STA vec+1) with no JSR
; overhead — total swift_init is ~40 bytes of asm.
; --------------------------------------------------------------------
.macro INSTALL_VEC vec, fn
        lda #<fn
        sta vec
        lda #>fn
        sta vec+1
.endmacro

.export _swift_init
_swift_init:
        sei                                     ; mask IRQs
        INSTALL_VEC IOPEN_VEC,  _swift_do_open
        INSTALL_VEC ICLOSE_VEC, _swift_do_close
        INSTALL_VEC ICHRIN_VEC, _swift_do_chrin
        INSTALL_VEC IGETIN_VEC, _swift_do_getin
        INSTALL_VEC IBSOUT_VEC, _swift_do_put
        cli                                     ; re-enable IRQs
        rts
