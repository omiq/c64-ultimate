; --------------------------------------------------------------------
; nmi.s  —  NMI ring-buffer ISR for httpget
; --------------------------------------------------------------------
;
; Same architecture as Bo's SwiftDriver / CCGMS: when the 6551 ACIA
; has a byte ready, it raises NMI via the SwiftLink IRQ-to-NMI wire.
; The C64 KERNAL NMI handler at $FE43 jumps through ($0318) — that's
; where we land.
;
; This handler:
;   1. Saves A/X/Y.
;   2. Reads STATUS, briefly disables ACIA IRQs (to ack).
;   3. If the RX-ready bit was set, reads the byte, stores it in the
;      ring buffer at index (ring_tail), bumps ring_tail.
;   4. Re-enables RX IRQs.
;   5. Restores A/X/Y, RTI.
;
; The ring buffer + tail live in BSS in httpget.c so C can read them.
; cc65 exports C symbols with a leading underscore.
; --------------------------------------------------------------------

ACIA_DATA    = $DE00
ACIA_STATUS  = $DE01
ACIA_COMMAND = $DE02

; ACIA COMMAND values:
;   $09 = DTR on, RX-IRQ on, RTS low, TX-IRQ off (normal listening)
;   $0B = DTR on, RX-IRQ off, RTS low, TX-IRQ off (during ISR / ack)
CMD_RX_ON   = $09
CMD_RX_OFF  = $0B

.import _ring          ; uint8_t ring[256]   (in C)
.import _ring_tail     ; uint8_t ring_tail   (in C)

.export _nmi_handler

.segment "CODE"

_nmi_handler:
        pha
        txa
        pha
        tya
        pha

        lda ACIA_STATUS         ; latch status
        ldx #CMD_RX_OFF         ; ack: disable RX IRQ briefly
        stx ACIA_COMMAND
        and #$08                ; RX-ready bit?
        beq @done

        lda ACIA_DATA           ; pull the received byte
        ldy _ring_tail
        sta _ring,y             ; ring[tail] = byte
        inc _ring_tail          ; advance (wraps naturally at 256)

        lda #CMD_RX_ON          ; re-enable RX IRQ
        sta ACIA_COMMAND

@done:
        pla
        tay
        pla
        tax
        pla
        rti
