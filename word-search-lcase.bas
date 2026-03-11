10 rem ------------------------------------------------------------
20 rem compute! word search for c64
30 rem ------------------------------------------------------------
40 dim wd$(7): wd=1
50 tg$="":tt=0 :rem flag for tracking html tags (1 = inside tag, 0 = outside)
60 dr=56832 :rem data register (read = receive, write = transmit)
70 sr=56833 :rem status register (flags: rx ready, tx ready, errors)
80 cm=56834 :rem command register (parity, echo, dtr, interrupts)
90 ct=56835 :rem control register (baud rate, word size, stop bits)
100 rem clear screen and set text colour (remove chr$(31) to unhide headers)
110 print chr$(142);chr$(147);chr$(5);"connecting ...";chr$(31):s=0
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
230 gosub 3000
270 rem dial tcp server (ip:port)
280 ts$="atdt php.retrogamecoders.com:80"+chr$(13)
290 gosub 700
291 rs$=""
292 s=peek(sr): if (s and 8)=0 then goto 292
293 c=peek(dr): rs$=rs$+chr$(c)
294 if right$(rs$,7)<>"connect" then goto 292
295 crlf$=chr$(13)+chr$(10)
310 ts$="get /word-search.php http/1.1"+crlf$
312 ts$=ts$+"host: php.retrogamecoders.com"+crlf$
314 ts$=ts$+crlf$
322 gosub 700
325 ht=0: rem flag for if html started (1 = started, 0 = not started)
330 s=peek(sr)
335 if (s and 8)=0 then goto 330
340 c=peek(dr)
345 if c<>10 and c<>13 then cr=0: goto 330
350 cr=cr+1
355 if cr<4 then goto 330
360 ht=1
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
585 if tt=0 and tg$="" then gosub 3200
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
1025 rem print "*";tg$;"*"
1040 if tg$="h1" then print chr$(147);chr$(18);chr$(159);:tg$="": return
1050 if tg$="/h1" then print chr$(156);chr$(5);chr$(13);:tg$="": return
1055 if tg$="h2" then print chr$(158);:tg$="": return
1060 if tg$="/h2" then print chr$(13);chr$(5);:tg$="": return
1065 if tg$="br" then print chr$(13);:tg$="": return
1070 if tg$="li" then print chr$(5);chr$(119);" ";:tg$="": st$="": return
1075 if tg$="/li" then tg$="": wd$(wd)=st$: st$="": wd=wd+1: return
1095 if tg$="/html" then gosub 3000: gosub 700: goto 4000:return
2000 tg$="": return
3000 rem hangup
3010 for i=1 to 3
3015 b=asc("+")
3020 gosub 850
3025 for w=1 to 500:next w
3050 next i
3055 return
3200 rem build strings to store
3210 if len(st$)<40 and c<>13 then st$=st$+chr$(c)
3220 if left$(st$,15)="400 bad request" then print chr$(5);
3225 if left$(st$,15)="400 bad request" then print " trying again!":goto 10
3240 print chr$(c);
3250 return
4000 rem interactive portion
4001 cy = 2: cx = 14: rem avoid word grid at 1,2 to 10,11
4002 fw$="": rem found word
4003 gosub 10100
4005 gosub 7000: print chr$(158);"use wasd, space, return";chr$(5): cy=3
4010 x=1: y=2: ox=x: oy=y: rem player cursor position
4020 poke 55296 + (oy*40)+ox, 1: rem undo old position
4030 poke 55296 + (y*40)+x, 0: rem highlight position
4040 ox=x: oy=y
4050 get k$: if k$="" then goto 4050
4060 if k$="w" and y>2 then y=y-1
4070 if k$="s" and y<11 then y=y+1
4080 if k$="a" and x>1 then x=x-1
4090 if k$="d" and x<10 then x=x+1
4100 if k$=chr$(32) then gosub 5100: rem mark the letter
4110 if k$=chr$(13) then gosub 5200: rem check the word
4190 goto 4020
5100 gosub 6000
5110 rem
5190 return
5200 rem check the word
5210 cy=3: cx = 14: gosub 7000
5220 for i = 0 to 7
5230 if fw$=wd$(i) then print "found ";fw$;"!": gosub 10300: return
5240 next i
5250 gosub 10200
5260 print "             ":fw$=""
5270 return
6000 rem get the current letter
6010 l$=chr$(peek(1024+(y*40)+x)+64)
6020 gosub 7000
6030 if cx=14 then print l$;"                  "
6040 if cx>14 then print l$;
6050 cx=cx+1: fw$=fw$+l$
6060 return
7000 rem place the cursor at cx,cy
7010 poke 214, cy: poke 211, cx: sys 58732
7020 return
10100 rem noises -------------------------------
10110 poke 54296,15      :rem volume max
10140 return
10200 rem --- wrong answer ---
10201 poke 54277,125     :rem attack/decay
10205 poke 54278,50      :rem sustain/release
10210 for f=800 to 200 step -20
10220 poke 54272,f and 255
10230 poke 54273,f/256
10240 poke 54276,33      :rem triangle + gate on
10250 for d=1 to 5:next
10260 next
10270 poke 54276,16      :rem gate off
10280 return
10300 rem --- correct answer ---
10301 poke 54277,125       :rem attack/decay
10305 poke 54278,100       :rem sustain/release
10310 for f=20000 to 30000 step 5000
10320 poke 54272,f and 255
10330 poke 54273,f/256
10340 poke 54276,33      :rem sawtooth + gate
10350 for d=1 to 4:next
10360 next
10370 poke 54276,32
10380 return
