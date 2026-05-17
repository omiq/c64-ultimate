10 rem ------------------------------------------------------------
20 rem load a web page (c64u kernal + swiftdriver)
30 rem based on simple.bas pattern + ../http-get.bas logic
40 rem ------------------------------------------------------------
50 tg$="":tt=0
60 if ld=0 then ld=1:print "loading driver...":load "swiftdrvr",8,1
65 poke 56833,0:poke 56835,31:poke 56834,9:for w=1 to 500:next
70 sys 49152
80 print chr$(147);chr$(5);"connecting ..."
85 close 5 : rem clear any leftover open from prior stop
90 open 5,2,0,chr$(15) : rem 19200 baud
100 crlf$=chr$(13)+chr$(10)
110 rem quiet-drain: keep reading until silent for q iters
120 gosub 5000
130 rem hangup first for a clean modem state
140 print#5,"+++";:for w=1 to 800:next
150 print#5,"ath"+chr$(13);:for w=1 to 1500:next
160 gosub 5000
170 rem dial
180 print#5,"atdt php.retrogamecoders.com:80"+chr$(13);
190 rem wait for connect string
200 rs$="":tm=0
210 get#5,a$
220 if a$="" then tm=tm+1:if tm>30000 then print "timeout":close 5:end
225 if a$="" then 210
230 tm=0:rs$=rs$+a$
240 for i=1 to len(rs$)-6:if mid$(rs$,i,7)="CONNECT" then 250
245 next i:goto 210
250 rem send http request
260 ts$="get / http/1.1"+crlf$+"host: php.retrogamecoders.com"+crlf$+crlf$
270 print#5,ts$;
280 rem skip headers - wait for blank line (4 cr/lf in a row)
290 cr=0
300 get#5,a$:if a$="" then 300
310 c=asc(a$)
320 if c<>10 and c<>13 then cr=0:goto 300
330 cr=cr+1:if cr<4 then 300
340 rem main parse loop
350 get#5,a$:if a$="" then 350
360 c=asc(a$)
370 if c>=97 and c<=122 then c=c-32
380 if c=asc("<") then tt=1:tg$="":goto 350
390 if c=asc(">") then tt=0:goto 350
400 if tt=1 then tg$=tg$+chr$(c)
410 if tt=0 and tg$<>"" then gosub 1000
420 if tt=0 and tg$="" then gosub 3200
430 goto 350
1000 rem process html tag in tg$
1040 if tg$="H1" then print chr$(147);chr$(18);chr$(159);:tg$="":return
1050 if tg$="/H1" then print chr$(156);chr$(5);chr$(13);:tg$="":return
1055 if tg$="H2" then print chr$(158);:tg$="":return
1060 if tg$="/H2" then print chr$(13);chr$(5);:tg$="":return
1065 if tg$="P" then print chr$(13);chr$(13);:tg$="":return
1070 if tg$="LI" then print chr$(5);chr$(119);" ";:tg$="":return
1075 if tg$="/LI" then tg$="":return
1095 if tg$="/HTML" then gosub 3000:close 5:end
1099 tg$="":return
3000 rem hangup
3010 print#5,"+++";:for w=1 to 800:next
3020 print#5,"ath"+chr$(13);:for w=1 to 1500:next
3030 return
3200 rem build/print body bytes
3210 if len(st$)<40 and c<>13 then st$=st$+chr$(c)
3220 if left$(st$,15)="400 BAD REQUEST" then close 5:print " trying again!":goto 10
3240 print chr$(c);
3250 return
5000 rem drain until sustained quiet (or total cap)
5010 q=0:dt=0: print "{clear}draining..."
5020 get#5,a$
5030 if a$<>"" then print a$;:q=0:goto 5040
5035 q=q+1
5040 dt=dt+1:if q<50 and dt<8000 then 5020
5050 return
