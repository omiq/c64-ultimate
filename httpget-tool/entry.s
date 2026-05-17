; --------------------------------------------------------------------
; entry.s  —  PRG load header + SYS entry table at $C000
; --------------------------------------------------------------------
;
; BASIC user calls into our code via fixed SYS addresses. The first
; bytes at $C000 are a JMP table — each entry is a 3-byte JMP to the
; real C function. SYS skips past these JMPs cleanly and the C func
; returns via RTS, putting us back in BASIC.
;
;  $C000  SYS 49152  -> hg_install
;  $C003  SYS 49155  -> hg_fetch
;  $C006  SYS 49158  -> hg_size
;  $C009  SYS 49161  -> hg_read
;  $C00C  SYS 49164  -> hg_rewind
;  $C00F  SYS 49167  -> hg_close
; --------------------------------------------------------------------

.import _hg_install
.import _hg_fetch
.import _hg_size
.import _hg_read
.import _hg_rewind
.import _hg_close

.segment "EXEHDR"
        .word $C000

.segment "CODE"
        jmp _hg_install         ; $C000
        jmp _hg_fetch           ; $C003
        jmp _hg_size            ; $C006
        jmp _hg_read            ; $C009
        jmp _hg_rewind          ; $C00C
        jmp _hg_close           ; $C00F
