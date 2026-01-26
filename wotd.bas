10 rem ------------------------------------------------------------
20 rem swiftlink tcp terminal (c64 basic v2)
30 rem uses direct peek/poke to the swiftlink 6551 acia
40 rem ------------------------------------------------------------
50 rem acia register addresses (swiftlink at $de00)
60 dr=56832 :rem data register (read = receive, write = transmit)
70 sr=56833 :rem status register (flags: rx ready, tx ready, errors)
80 cm=56834 :rem command register (parity, echo, dtr, interrupts)
90 ct=56835 :rem control register (baud rate, word size, stop bits)
100 rem clear screen and set text colour
110 print chr$(147);chr$(5);"connecting ...":s=0
120 rem reset acia by writing to status register
130 poke sr,0
140 rem control register
150 rem 31 = 8 data bits, 1 stop bit, internal clock,
160 rem baud setting doubled by swiftlink crystal = 38,400
170 poke ct,16:rem poke ct,31 on c64u
180 rem command register
190 rem no parity, no echo, dtr on, receive enabled
200 poke cm,9
210 rem short delay to let hardware settle
220 for i=1 to 500:next
230 rem send "at"to wake up tcp modem emulation
240 rem leading cr ensures clean command state
250 ts$=chr$(13)+"at"+chr$(13)
260 gosub 700
270 rem dial tcp server (ip:port)
280 ts$="atdt 127.0.0.1:6464"+chr$(13)+chr$(13)+chr$(13)
290 gosub 700
300 t$=""
320 rem ------------------------------------------------------------
330 rem online lookup loop
440 s=peek(sr)
450 if (s and 8)=0 then goto 440
470 c=peek(dr)
500 if c<>35 then goto 440
510 s=peek(sr)
520 if (s and 8)=0 then goto 510
530 c=peek(dr)
540 if c<>13 then i$=i$+chr$(c)
550 if c=35 then w$=w$+i$:i$="":sg=sg+1:print chr$(147)"loading "sg
560 if sg<4 then goto 510
570 rem jump to game part
580 goto 1000
700 rem ------------------------------------------------------------
710 rem send string ts$ character by character
720 rem ------------------------------------------------------------
730 for i=1 to len(ts$)
740 b=asc(mid$(ts$,i,1))
750 gosub 800
760 next
770 return
800 rem ------------------------------------------------------------
810 rem send one byte in b
820 rem wait until transmit register is empty
830 rem bit 4 (value 16) = transmit ready
840 rem ------------------------------------------------------------
850 s=peek(sr)
860 if (s and 16)=0 then 850
870 poke dr,b
880 return
1000 rem word guessing game
1020 w$ = mid$(w$,5,len(w$)-6): c=0
1030 print chr$(147)chr$(5)spc(3)"can you guess the word of the day?"
1040 print
1050 c=c+1
1060 if mid$(w$,c,1) <> "#"then goto 1050
1070 gw$ = left$(w$,c-1): rem word to guess
1080 gd$ = mid$(w$,c+1): rem word definition
1090 print "the word is "len(gw$)" letters long";chr$(13)
1100 for tr = 1 to 10: rem 10 tries
1110 print "enter your guess";: input a$
1120 if a$=gw$ then goto 3000
1130 for c=1 to len(gw$)
1140 if mid$(a$,c,1)=mid$(gw$,c,1) then print mid$(gw$,c,1);
1150 if mid$(a$,c,1)<>mid$(gw$,c,1) then print "*";
1160 next c
1200 print chr$(13);(10-tr);" attempts remaining";chr$(13)
1210 next tr
2000 rem failed!
2010 print chr$(147);chr$(5);
2020 print "better luck next time, the word was"
2030 print chr$(13)gw$chr$(13)
2040 print gd$
2050 get a$: if a$="" then 2050
2060 end
3000 rem correct guess
3010 print chr$(147);chr$(5);
3020 print "well done you guessed correctly!"
3030 print chr$(13)gw$chr$(13)
3040 print gd$
3050 get a$: if a$="" then 3050
3060 end
