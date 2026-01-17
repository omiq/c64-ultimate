10 rem ------------------------------------------------------------
20 rem SWIFTLINK TCP TERMINAL (C64 BASIC V2)
30 rem Uses direct PEEK/POKE to the SwiftLink 6551 ACIA
40 rem ------------------------------------------------------------

50 rem ACIA REGISTER ADDRESSES (SWIFTLINK AT $DE00)
60 dr=56832 : rem data register (read = receive, write = transmit)
70 sr=56833 : rem status register (flags: rx ready, tx ready, errors)
80 cm=56834 : rem command register (parity, echo, DTR, interrupts)
90 ct=56835 : rem control register (baud rate, word size, stop bits)

100 rem CLEAR SCREEN AND SET TEXT COLOUR
110 print chr$(147);chr$(5);"swiftlink term"

120 rem RESET ACIA BY WRITING TO STATUS REGISTER
130 poke sr,0

140 rem CONTROL REGISTER
150 rem 31 = 8 data bits, 1 stop bit, internal clock,
160 rem 19,200 baud setting doubled by SwiftLink crystal = 38,400
170 poke ct,31

180 rem COMMAND REGISTER
190 rem no parity, no echo, DTR on, receive enabled
200 poke cm,9

210 rem SHORT DELAY TO LET HARDWARE SETTLE
220 for i=1 to 500:next

230 rem SEND "AT" TO WAKE UP TCP MODEM EMULATION
240 rem leading CR ensures clean command state
250 ts$=chr$(13)+"at"+chr$(13)
260 gosub 700

270 rem DIAL TCP SERVER (IP:PORT)
280 ts$="atdt 192.168.0.154:6464"+chr$(13)+chr$(13)+chr$(13)
290 gosub 700

300 t$=""
310 print "connected"

320 rem ------------------------------------------------------------
330 rem MAIN TERMINAL LOOP
340 rem - read keyboard and send characters
350 rem - poll ACIA for received data and print it
360 rem ------------------------------------------------------------

370 rem READ ONE KEY (NON-BLOCKING)
380 get a$

390 rem IF A KEY WAS PRESSED, SEND IT
400 rem ASC() CONVERTS CHARACTER TO BYTE VALUE
410 if a$<>"" then b=asc(a$):gosub 800

420 rem CHECK STATUS REGISTER
430 rem BIT 3 (VALUE 8) = RECEIVE DATA AVAILABLE
440 s=peek(sr)
450 if (s and 8)=0 then 370

460 rem READ RECEIVED BYTE
470 c=peek(dr)

480 rem NORMALISE LINE ENDINGS
490 rem MAP LF (10) TO CR (13) FOR C64 DISPLAY
500 if c=10 then c=13

510 rem PRINT RECEIVED CHARACTER
520 print chr$(c);

530 goto 370

700 rem ------------------------------------------------------------
710 rem SEND STRING TS$ CHARACTER BY CHARACTER
720 rem ------------------------------------------------------------
730 for i=1 to len(ts$)
740 b=asc(mid$(ts$,i,1))
750 gosub 800
760 next
770 return

800 rem ------------------------------------------------------------
810 rem SEND ONE BYTE IN B
820 rem WAIT UNTIL TRANSMIT REGISTER IS EMPTY
830 rem BIT 4 (VALUE 16) = TRANSMIT READY
840 rem ------------------------------------------------------------
850 s=peek(sr)
860 if (s and 16)=0 then 850
870 poke dr,b
880 return

