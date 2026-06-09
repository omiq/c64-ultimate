; Minimal NMI ring-buffer ISR for direct-ACIA BASIC programs.
; Ring page $C200, tail $A8 (ISR), head $A7 (BASIC). Load at $C000.

RING      = $C200
ZP_HEAD   = $A7
ZP_TAIL   = $A8
ACIA_DATA = $DE00
ACIA_STAT = $DE01
ACIA_CMD  = $DE02

.segment "CODE"
.org $C000

nmi_handler:
        pha
        txa
        pha
        tya
        pha
        lda ACIA_STAT
        ldx #$0B
        stx ACIA_CMD
        and #$08
        beq done
        lda ACIA_DATA
        ldy ZP_TAIL
        sta RING,y
        inc ZP_TAIL
        lda #$09
        sta ACIA_CMD
done:
        pla
        tay
        pla
        tax
        pla
        rti
