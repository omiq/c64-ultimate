10 rem ------------------------------------------------------------
20 rem compute! word search (c64u kernal + swiftdriver)
30 rem based on simple.bas pattern + ../word-search.bas logic
40 rem ------------------------------------------------------------
50 tg$="":tt=0
60 if ld=0 then ld=1:print "loading driver...":load "swiftdrvr",8,1
65 poke 56833,0:poke 56835,31:poke 56834,9:for w=1 to 500:next
70 sys 49152
80 if dd=0 then dd=1:dim wd$(7):wd=1
90 print chr$(147);chr$(5);"connecting ..."
100 open 5,2,0,chr$(7)
110 crlf$=chr$(13)+chr$(10)
120 rem quiet-drain
130 gosub 5500
140 rem hangup first for clean state
150 print#5,"+++";:for w=1 to 800:next
160 print#5,"ath"+chr$(13);:for w=1 to 1500:next
170 gosub 5500
180 rem dial
190 print#5,"atdt php.retrogamecoders.com:80"+chr$(13);
200 rem wait for connect
210 rs$="":tm=0
220 get#5,a$
230 if a$="" then tm=tm+1:if tm>30000 then print "timeout":close 5:end
235 if a$="" then 220
240 tm=0:rs$=rs$+a$
250 if right$(rs$,7)<>"CONNECT" and right$(rs$,7)<>"connect" then 220
260 rem send http request
270 ts$="get /word-search.php http/1.1"+crlf$
280 ts$=ts$+"host: php.retrogamecoders.com"+crlf$+crlf$
290 print#5,ts$;
300 rem skip headers — blank line = 4 cr/lf in row
310 cr=0
320 get#5,a$:if a$="" then 320
330 c=asc(a$)
340 if c<>10 and c<>13 then cr=0:goto 320
350 cr=cr+1:if cr<4 then 320
360 rem main parse loop
370 get#5,a$:if a$="" then 370
380 c=asc(a$)
390 if c>=97 and c<=122 then c=c-32
400 if c=asc("<") then tt=1:tg$="":goto 370
410 if c=asc(">") then tt=0:goto 370
420 if tt=1 then tg$=tg$+chr$(c)
430 if tt=0 and tg$<>"" then gosub 1000
440 if tt=0 and tg$="" then gosub 3200
450 goto 370
1000 rem process html tag in tg$ (uppercase — input was uppercased above)
1040 if tg$="H1" then print chr$(147);chr$(18);chr$(159);:tg$="":return
1050 if tg$="/H1" then print chr$(156);chr$(5);chr$(13);:tg$="":return
1055 if tg$="H2" then print chr$(158);:tg$="":return
1060 if tg$="/H2" then print chr$(13);chr$(5);:tg$="":return
1065 if tg$="BR" then print chr$(13);:tg$="":return
1070 if tg$="LI" then print chr$(5);chr$(119);" ";:tg$="":st$="":return
1075 if tg$="/LI" then tg$="":wd$(wd)=st$:st$="":wd=wd+1:return
1095 if tg$="/HTML" then gosub 3000:close 5:goto 4000
1099 tg$="":return
3000 rem hangup
3010 print#5,"+++";:for w=1 to 800:next
3020 print#5,"ath"+chr$(13);:for w=1 to 1500:next
3030 return
5500 rem drain until sustained quiet
5510 q=0
5520 get#5,a$
5530 if a$<>"" then q=0:goto 5520
5540 q=q+1:if q<500 then 5520
5550 return
3200 if len(st$)<40 and c<>13 then st$=st$+chr$(c)
3220 if left$(st$,15)="400 BAD REQUEST" then print chr$(5);
3225 if left$(st$,15)="400 BAD REQUEST" then close 5:print " trying again!":goto 10
3240 print chr$(c);
3250 return
4000 rem interactive portion
4001 cy=2:cx=14
4002 fw$=""
4003 gosub 10100
4005 gosub 7000:print chr$(158);"use wasd, space, return";chr$(5):cy=3
4010 x=1:y=2:ox=x:oy=y
4020 poke 55296+(oy*40)+ox,1
4030 poke 55296+(y*40)+x,0
4040 ox=x:oy=y
4050 get k$:if k$="" then 4050
4060 if k$="w" and y>2 then y=y-1
4070 if k$="s" and y<11 then y=y+1
4080 if k$="a" and x>1 then x=x-1
4090 if k$="d" and x<10 then x=x+1
4100 if k$=chr$(32) then gosub 5100
4110 if k$=chr$(13) then gosub 5200
4190 goto 4020
5100 gosub 6000
5190 return
5200 cy=3:cx=14:gosub 7000
5220 for i=0 to 7
5230 if fw$=wd$(i) then print "found ";fw$;"!":gosub 10300:return
5240 next i
5250 gosub 10200
5260 print "             ":fw$=""
5270 return
6000 l$=chr$(peek(1024+(y*40)+x)+64)
6020 gosub 7000
6030 if cx=14 then print l$;"                  "
6040 if cx>14 then print l$;
6050 cx=cx+1:fw$=fw$+l$
6060 return
7000 poke 214,cy:poke 211,cx:sys 58732
7020 return
10100 poke 54296,15
10140 return
10200 poke 54277,125
10205 poke 54278,50
10210 for f=800 to 200 step -20
10220 poke 54272,f and 255
10230 poke 54273,f/256
10240 poke 54276,33
10250 for d=1 to 5:next
10260 next
10270 poke 54276,16
10280 return
10300 poke 54277,125
10305 poke 54278,100
10310 for f=20000 to 30000 step 5000
10320 poke 54272,f and 255
10330 poke 54273,f/256
10340 poke 54276,33
10350 for d=1 to 4:next
10360 next
10370 poke 54276,32
10380 return
