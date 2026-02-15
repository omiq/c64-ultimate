10 rem ------------------------------------------------------------
20 rem swiftlink tcp terminal (c64 basic v2)
30 rem uses direct peek/poke to the swiftlink 6551 acia
40 rem acia register addresses (swiftlink at $de00)
45 rem ------------------------------------------------------------
50 tg$="":tt=0 :rem flag for tracking html tags (1 = inside tag, 0 = outside)
60 dr=56832 :rem data register (read = receive, write = transmit)
70 sr=56833 :rem status register (flags: rx ready, tx ready, errors)
80 cm=56834 :rem command register (parity, echo, dtr, interrupts)
90 ct=56835 :rem control register (baud rate, word size, stop bits)
100 rem clear screen and set text colour
110 print chr$(142);chr$(147);chr$(5);"connecting ...":s=0
120 rem reset acia by writing to status register
130 poke sr,0
140 rem control register
150 rem 31 = 8 data bits, 1 stop bit, internal clock,
160 rem baud setting doubled by swiftlink crystal = 38,400
170 poke ct,31:rem poke ct,31 on c64u and 16 on vice
180 rem command register
190 rem no parity, no echo, dtr on, receive enabled
200 poke cm,9
210 rem short delay to let hardware settle
220 for i=1 to 500:next
230 rem send "at"to wake up tcp modem emulation
240 rem leading cr ensures clean command state
250 ts$=chr$(13)+"+++"+chr$(13)
260 gosub 700
270 rem dial tcp server (ip:port)
280 ts$="atdt php.retrogamecoders.com:80"+chr$(13)
290 gosub 700
300 crlf$=chr$(13)+chr$(10)
310 ts$="get / http/1.1"+crlf$+"host: php.retrogamecoders.com"+crlf$+"connection: close"+crlf$+crlf$
320 gosub 700
390 ht=0: rem flag for if html started (1 = started, 0 = not started)
400 rem ------------------------------------------------------------
410 rem main loop to read and process incoming data
420 rem ------------------------------------------------------------
440 s=peek(sr)
450 if (s and 8)=0 then goto 440
455 c=peek(dr)
460 if c>=97 and c<=122 then c=c-32
465 if c=asc("<") then tt=1: tg$="": goto 440
470 if c=asc(">") then tt=0: goto 440
475 if tt=1 then tg$=tg$+chr$(c)
480 if tt=0 and tg$<>"" then gosub 1000
585 if tt=0 and tg$="" then print chr$(c);
590 goto 440
600 end
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
1000 rem ------------------------------------------------------------
1010 rem process html tag in tg$
1020 rem ------------------------------------------------------------
1030 if tg$="html" or tg$="html" then print "{clr}";
1040 if tg$="h1" then print "{rvs on}";
1050 if tg$="/h1" then print "{rvs off}";
2000 tg$="": return
