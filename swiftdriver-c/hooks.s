; --------------------------------------------------------------------
; hooks.s  —  KERNAL vector replacements for the SwiftDriver port
; --------------------------------------------------------------------
;
; These six routines are installed into the KERNAL indirect vectors
; ($031A-$032B) by swift_init() in swift.c. They must use 6502 calling
; conventions (A/X/Y passed in registers, RTS to return) so they sit
; transparently between the user's BASIC code and KERNAL ROM.
;
; They cannot be written in C because cc65 always emits a C prologue
; that clobbers the registers KERNAL expects to be live. Each routine
; is therefore a near-verbatim port of Bo Zimmerman's swiftdrvr.asm,
; reformatted with one-purpose-per-block layout and a comment on every
; meaningful line.
;
; Cross-reference: header comments cite the asm line range each block
; replaces in ../swiftdriver/swiftdrvr.asm.
; --------------------------------------------------------------------

; ===== 6551 ACIA (SwiftLink @ $DE00) =====
ACIA_DATA    = $DE00            ; R=RX byte, W=TX byte
ACIA_STATUS  = $DE01            ; bit3=RX ready, bit4=TX empty
ACIA_COMMAND = $DE02            ; parity / echo / DTR / IRQ enables
ACIA_CONTROL = $DE03            ; baud / word / stop bits

; ===== zero-page state (shared with nmi.s, ABI with C) =====
ZP_RHEAD     = $A7              ; ring buf read index (1 byte, wraps)
ZP_RTAIL     = $A8              ; ring buf write index (1 byte, wraps)
ZP_RBUFF     = $F7              ; 16-bit ptr to ring buf (KERNAL alloc)
ZP_RCOUNT    = $B4              ; stat: total RX bytes seen
ZP_ERRORS    = $B5              ; last STATUS byte (debug)
ZP_XMO       = $B6              ; saved COMMAND, RX-only (no IRQ)
ZP_XMF       = $BD              ; saved COMMAND, RX-with-IRQ

; ===== KERNAL zero-page locations we read =====
ZP_DEVICE    = $BA              ; current file's device # (set by OPEN)
ZP_FN_PTR    = $BB              ; 16-bit ptr to current OPEN's filename
ZP_CURIN     = $99              ; current input channel
ZP_CUROUT    = $9A              ; current output channel

; ===== KERNAL ROM entry points we delegate to =====
KERNAL_OPEN  = $F34A            ; raw IOPEN (alloc buffers etc.)
KERNAL_CHRIN = $F157            ; raw CHRIN (post-device-check)
KERNAL_GETIN = $F13E            ; raw GETIN (post-device-check)
KERNAL_BSOUT = $F1CA            ; raw BSOUT (post-device-check)
KERNAL_CLOSEPRE = $F314         ; CLOSE: find FNUM in table, sets BA
KERNAL_SET_BA   = $F31F         ; CLOSE: set BA from current file
KERNAL_CLOSE_F  = $F291         ; CLOSE: actually close the file
KERNAL_NMI_LO   = $47           ; default NMI vector low byte ($FE47)
KERNAL_NMI_HI   = $FE           ; default NMI vector high byte

; ===== ours =====
.import     _nmi_handler        ; in nmi.s
.export     _swift_do_open
.export     _swift_do_close
.export     _swift_do_chrin
.export     _swift_do_getin
.export     _swift_do_put

.segment "CODE"

; ====================================================================
; SAVBYTE — scratch byte used by chrin/getin to return the RX char.
; In Bo's asm this is at the equivalent label, embedded in code space.
; ====================================================================
SAVBYTE:    .byte 0

; ====================================================================
; _swift_do_open  —  asm lines 83-131 of swiftdrvr.asm
;
; KERNAL OPEN dispatches here via the indirect vector at $031A. We:
;   1. Call KERNAL's raw IOPEN ($F34A) so buffers get allocated and
;      zero-page pointers ($F7-$FA) are populated. Preserve its return
;      A/Y on stack.
;   2. Check the current device ($BA). If != 2 (modem), restore A/Y
;      and RTS — not ours to handle further.
;   3. For device 2: zero ring-buffer state, pull baud-code from
;      filename byte 0 via ($BB),Y, OR with internal-clock bit, write
;      to ACIA CONTROL.
;   4. Write %00001001 to COMMAND (no parity, no echo, DTR on,
;      RX-IRQ enabled), stash variants in ZP_XMF / ZP_XMO for the ISR
;      to reload after each byte.
;   5. Install our NMI handler at $0318.
;   6. Restore A/Y, RTS.
; ====================================================================
_swift_do_open:
        jsr KERNAL_OPEN         ; do the normal IOPEN first
        pha                     ; save returned A
        tya
        pha                     ; save returned Y (via A)
        lda ZP_DEVICE           ; current device #
        cmp #$02
        beq @is_modem
        pla                     ; restore Y
        tay
        pla                     ; restore A
        rts                     ; not device 2 — done

@is_modem:
        ; ---- reset our ring-buffer accounting ----
        lda #$00
        sta ZP_RHEAD
        sta ZP_RTAIL
        sta ZP_RCOUNT
        sta ZP_ERRORS

        ; ---- configure CONTROL reg from baud-code in filename[0] ----
        ; Filename pointer set by KERNAL OPEN into ($BB).
        ; Bit pattern: 0001bbbb where bbbb is the baud index (1..15)
        ; plus the internal-clock bit (%00010000) we OR in.
        ldy #$00
        lda (ZP_FN_PTR),y
        ora #%00010000          ; internal clock = on (SwiftLink xtal)
        sta ACIA_CONTROL

        ; ---- configure COMMAND reg ----
        ; %00001001 = no parity, no echo, RX IRQ on, DTR on.
        lda #%00001001
        sta ACIA_COMMAND
        sta ZP_XMF              ; ISR uses this to re-enable RX IRQ

        ; Also stash an "IRQ-disabled" variant for future use.
        and #%11110000          ; clear low nibble
        ora #%00001001          ; same low nibble — for now same value
        sta ZP_XMO

        ; ---- install our NMI handler ----
        sei
        lda #<_nmi_handler
        sta $0318
        lda #>_nmi_handler
        sta $0319
        cli

        ; ---- restore A/Y and return ----
        pla
        tay
        pla
        rts

; ====================================================================
; _swift_do_chrin  —  asm lines 163-167
; _swift_do_getin  —  asm lines 168-172
;
; If the current input channel isn't device 2, fall through to the
; corresponding raw KERNAL routine. Otherwise pull a byte from our
; ring buffer (shared body at @from_modem).
; ====================================================================
_swift_do_chrin:
        lda ZP_CURIN            ; current input channel
        cmp #$02
        beq from_modem
        jmp KERNAL_CHRIN        ; not us — let KERNAL handle it

_swift_do_getin:
        lda ZP_CURIN
        cmp #$02
        beq from_modem
        jmp KERNAL_GETIN

; --------------------------------------------------------------------
; from_modem — common body for chrin/getin. Returns byte in A.
; CLC indicates "no error" (KERNAL convention).
; If head==tail, buffer is empty — returns 0 with CLC.
; Plain (non-local) label so both chrin and getin can branch to it
; across ca65's @-label scope boundary.
; --------------------------------------------------------------------
from_modem:
        tya                     ; save Y
        pha
        txa                     ; save X
        pha
        lda #$00
        sta SAVBYTE             ; default return = 0
        lda ZP_RHEAD
        cmp ZP_RTAIL
        beq @done               ; nothing pending
        tay                     ; Y = RHEAD
        lda (ZP_RBUFF),y        ; A = buf[head]
        inc ZP_RHEAD            ; advance head (wraps 0..255)
        sta SAVBYTE
@done:
        pla                     ; restore X
        tax
        pla                     ; restore Y
        tay
        lda SAVBYTE             ; return byte in A
        clc                     ; status = ok
        rts

; ====================================================================
; _swift_do_put  —  asm lines 197-214
;
; If current output channel isn't device 2, fall through to raw KERNAL
; BSOUT. Otherwise wait for TX-empty (STATUS bit 4) and write the byte
; to DATA. This is a *blocking* send.
; ====================================================================
_swift_do_put:
        pha                     ; stash the byte to send
        lda ZP_CUROUT
        cmp #$02
        beq @send
        pla                     ; restore A
        jmp KERNAL_BSOUT        ; not us
@send:
        lda ACIA_STATUS         ; poll until TX-empty bit set
        and #%00010000
        beq @send
        clc
        pla                     ; recover the byte
        sta ACIA_DATA           ; transmit
        rts

; ====================================================================
; _swift_do_close  —  asm lines 216-242
;
; CLOSE may target any file — let KERNAL figure out which. If it turns
; out to be device 2, we additionally:
;   1. Disable ACIA IRQs (write %00000011 to COMMAND).
;   2. Restore the default KERNAL NMI vector ($FE47) so RESTORE-key
;      behaviour returns to normal.
; ====================================================================
_swift_do_close:
        pha                     ; stash A (KERNAL convention)
        jsr KERNAL_CLOSEPRE     ; find FNUM in file table; Z=found
        beq @found
        pla
        clc
        rts                     ; not found — bail
@found:
        jsr KERNAL_SET_BA       ; sets $BA from the file table entry
        lda ZP_DEVICE
        cmp #$02
        beq @is_modem
        pla
        jmp KERNAL_CLOSE_F      ; not device 2 — normal close

@is_modem:
        pla
        jsr KERNAL_CLOSE_F      ; do the standard close first
        ldx #%00000011          ; disable ACIA IRQs
        stx ACIA_COMMAND
        sei
        lda #KERNAL_NMI_LO      ; restore KERNAL's default NMI vector
        sta $0318
        lda #KERNAL_NMI_HI
        sta $0319
        cli
        ldx #$00                ; return X=0 = no error
        rts
