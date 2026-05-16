10 rem ------------------------------------------------------------
20 rem load a web page (c64 ultimate / kernal + swiftdriver)
30 rem use this if direct peek/poke at $de00 freezes on (s and 8)
40 rem ------------------------------------------------------------
50 tg$="":tt=0
60 cn=5:rem file number for rs232
70 ld=0:rem driver load flag
80 if ld=0 then ld=1:load "swiftdrvr49152",8,1
90 sys 49152
100 print chr$(147);chr$(5);"connecting ...":s=0
110 open cn,2,0,chr$(7):rem 600 baud via kernal
120 crlf$=chr$(13)+chr$(10)
130 gosub 3000:rem hangup first for clean state
140 ts$="atdt php.retrogamecoders.com:80"+chr$(13)
150 gosub 700
160 rs$="":to=0
170 to=to+1:if to>30000 then print "connect timeout":close cn:end
180 get#cn,a$:if a$="" then goto 170
190 rs$=rs$+a$
200 if right$(rs$,7)<>"connect" and right$(rs$,7)<>"CONNECT" then goto 170
210 ts$="get / http/1.1"+crlf$+"host: php.retrogamecoders.com"+crlf$+crlf$
220 gosub 700
230 ht=0:cr=0
240 get#cn,a$:if a$="" then goto 240
250 c=asc(a$)
260 if c<>10 and c<>13 then cr=0:goto 240
270 cr=cr+1:if cr<4 then goto 240
280 ht=1
290 get#cn,a$:if a$="" then goto 290
300 c=asc(a$)
310 if c>=97 and c<=122 then c=c-32
320 if c=asc("<") then tt=1:tg$="":goto 290
330 if c=asc(">") then tt=0:goto 290
340 if tt=1 then tg$=tg$+chr$(c)
350 if tt=0 and tg$<>"" then gosub 1000
360 if tt=0 and tg$="" then gosub 3200
370 goto 290
380 close cn:end
700 rem send string ts$
710 for i=1 to len(ts$)
720 print#cn,mid$(ts$,i,1);
730 next
740 gosub 800
750 return
800 rem wait until transmit buffer empty
810 if (peek(663) and 8)=0 then 810
820 return
1000 rem process html tag in tg$
1040 if tg$="h1" then print chr$(147);chr$(18);chr$(159);:tg$="":return
1050 if tg$="/h1" then print chr$(156);chr$(5);chr$(13);:tg$="":return
1055 if tg$="h2" then print chr$(158);:tg$="":return
1060 if tg$="/h2" then print chr$(13);chr$(5);:tg$="":return
1065 if tg$="p" then print chr$(13);chr$(13);:tg$="":return
1070 if tg$="li" then print chr$(5);chr$(119);" ";:tg$="":return
1075 if tg$="/li" then tg$="":return
1095 if tg$="/html" then gosub 3000:return
2000 tg$="":return
3000 rem hangup
3010 ts$="+++":gosub 700
3020 for w=1 to 500:next
3030 ts$="ath"+chr$(13):gosub 700
3040 return
3200 if len(st$)<40 and c<>13 then st$=st$+chr$(c)
3220 if left$(st$,15)="400 bad request" then close cn:print chr$(5);" trying again!":goto 100
3240 print chr$(c);
3250 return
