; --------------------------------------------------------------------
; nmi.s  —  NMI interrupt handler for the SwiftDriver C port
; --------------------------------------------------------------------
;
; This file is hand-written 6502 because:
;
;   1. C function prologue/epilogue from cc65 saves more registers
;      than we need (uses the C "sp" pseudo-register etc), making
;      the ISR fatter and slower than necessary.
;   2. NMI handlers must save/restore A/X/Y themselves and end with
;      RTI — cc65's __interrupt__ pragma supports this but the
;      generated code is still larger than the ~30 bytes of hand asm.
;   3. The audience can read this top to bottom and see every cycle.
;
; Hooked into the C64 NMI vector at $0318/$0319 by swift_init().
; The KERNAL NMI handler at $FE43 saves PC+P automatically (CPU does
; that on any interrupt), checks RESTORE key, then does JMP ($0318).
; That's where we land. We must save A/X/Y ourselves and RTI.
;
; Side-by-side with Bo's original "NEWNMI" (asm lines 133-159):
;
;     Bo's asm         | What it does               | Our line
;     -----------------+----------------------------+----------
;     NOP              | placeholder, no-op         | (removed)
;     PHA / TXA / PHA  | save A, save X via stack   | save_regs
;     TYA / PHA        | save Y                     | save_regs
;     LDA STATUS       | read 6551 status reg       | read_status
;     LDX #%00000011   | command = DTR off + RX off | ack_irq
;     STX COMMAND      | (acks the IRQ source)      | ack_irq
;     STA ERRORS       | stash STATUS for debug     | stash_status
;     AND #%00001000   | was RX-ready bit set?      | check_rx
;     BEQ NREVD        | no -> just exit            | check_rx
;     LDA DATAPORT     | read the received byte     | read_byte
;     LDY RTAIL        | get tail index             | store_byte
;     STA (RBUFF),Y    | store at buf[tail]         | store_byte
;     INC RTAIL        | advance tail (wraps 0..ff) | store_byte
;     INC RCOUNT       | bump stat counter          | store_byte
;     LDA ZPXMF        | reload "RX+IRQ on" cmd     | restore_irq
;     STA COMMAND      | re-enable IRQ on RX        | restore_irq
;   NREVD:             |                            |
;     PLA / TAY / PLA  | restore Y, restore X       | restore_regs
;     TAX / PLA        | restore A                  | restore_regs
;     RTI              | return from interrupt      | restore_regs
; --------------------------------------------------------------------

; --- 6551 register addresses (must match swift.h) ---
ACIA_DATA    = $DE00
ACIA_STATUS  = $DE01
ACIA_COMMAND = $DE02

; --- Zero-page locations shared with C (must match swift.h) ---
ZP_RTAIL     = $A8     ; ring-buffer write index
ZP_RBUFF     = $F7     ; ring-buffer pointer (16-bit, lo/hi at $F7/$F8)
ZP_RCOUNT    = $B4     ; stat: total bytes received
ZP_ERRORS    = $B5     ; last STATUS byte (debugging)
ZP_XMF       = $BD     ; saved COMMAND value with RX-IRQ enabled

.export _nmi_handler   ; cc65 exports underscored symbols to C
.segment "CODE"

; ====================================================================
_nmi_handler:
; --------------------------------------------------------------------
; save_regs: stack A, X, Y so we can clobber them freely
; --------------------------------------------------------------------
        pha                     ; push A
        txa
        pha                     ; push X (via A)
        tya
        pha                     ; push Y (via A)

; --------------------------------------------------------------------
; read_status + ack_irq: read STATUS, immediately ack the IRQ by
; writing %00000011 to COMMAND (DTR off, RX-IRQ off). We re-enable
; RX-IRQ at the bottom if it was an RX event.
; --------------------------------------------------------------------
        lda ACIA_STATUS         ; bit3 = RX ready, bit4 = TX ready, etc
        ldx #%00000011          ; ack/disable
        stx ACIA_COMMAND
        sta ZP_ERRORS           ; stash for inspection from BASIC

; --------------------------------------------------------------------
; check_rx: was the RX-ready bit set? If not, we're done.
; --------------------------------------------------------------------
        and #%00001000          ; mask just the RX-ready bit
        beq nmi_exit            ; no RX -> skip the read

; --------------------------------------------------------------------
; read_byte + store_byte: pull byte from DATA reg, append to ring buf
; at (RBUFF),Y where Y = current tail index. Tail wraps 0..255 since
; it's a single byte and the buffer is exactly one page (256 bytes).
; --------------------------------------------------------------------
        lda ACIA_DATA           ; read the received byte
        ldy ZP_RTAIL            ; tail index into ring buffer
        sta (ZP_RBUFF),y        ; store at buf[tail]
        inc ZP_RTAIL            ; advance tail (wraps at 256)
        inc ZP_RCOUNT           ; bump global byte-seen counter

; --------------------------------------------------------------------
; restore_irq: put the COMMAND register back to "RX-IRQ enabled" so
; the next received byte fires another NMI.
; --------------------------------------------------------------------
        lda ZP_XMF              ; saved value: %00001001 (RX IRQ + DTR)
        sta ACIA_COMMAND

nmi_exit:
; --------------------------------------------------------------------
; restore_regs: pop Y, X, A in reverse order. RTI pops P+PC.
; --------------------------------------------------------------------
        pla
        tay                     ; restore Y
        pla
        tax                     ; restore X
        pla                     ; restore A
        rti                     ; return from interrupt
