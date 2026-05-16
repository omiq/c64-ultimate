10 rem ------------------------------------------------------------
20 rem compute! word search (c64 ultimate / kernal + swiftdriver)
30 rem ------------------------------------------------------------
40 dim wd$(7): wd=1
50 tg$="":tt=0
60 cn=5:ld=0
70 if ld=0 then ld=1:load "swiftdrvr",8,1
80 sys 49152
90 print chr$(142);chr$(147);chr$(5);"connecting ...";chr$(31):s=0
100 open cn,2,0,chr$(7):rem 600 baud
110 gosub 3000
120 ts$="atdt php.retrogamecoders.com:80"+chr$(13)
130 gosub 700
140 rs$="":to=0
150 to=to+1:if to>30000 then print "connect timeout":close cn:end
160 get#cn,a$:if a$="" then goto 150
170 rs$=rs$+a$
180 if right$(rs$,7)<>"connect" and right$(rs$,7)<>"CONNECT" then goto 150
190 crlf$=chr$(13)+chr$(10)
200 ts$="get /word-search.php http/1.1"+crlf$
210 ts$=ts$+"host: php.retrogamecoders.com"+crlf$+crlf$
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
700 rem send string ts$
710 for i=1 to len(ts$)
720 print#cn,mid$(ts$,i,1);
730 next
740 gosub 800
750 return
800 if (peek(663) and 8)=0 then 800
810 return
1000 rem process html tag in tg$
1040 if tg$="h1" then print chr$(147);chr$(18);chr$(159);:tg$="":return
1050 if tg$="/h1" then print chr$(156);chr$(5);chr$(13);:tg$="":return
1055 if tg$="h2" then print chr$(158);:tg$="":return
1060 if tg$="/h2" then print chr$(13);chr$(5);:tg$="":return
1065 if tg$="br" then print chr$(13);:tg$="":return
1070 if tg$="li" then print chr$(5);chr$(119);" ";:tg$="":st$="":return
1075 if tg$="/li" then tg$="":wd$(wd)=st$:st$="":wd=wd+1:return
1095 if tg$="/html" then gosub 3000:close cn:goto 4000:return
2000 tg$="":return
3000 rem hangup
3010 ts$="+++":gosub 700
3020 for w=1 to 500:next
3030 ts$="ath"+chr$(13):gosub 700
3040 return
3200 if len(st$)<40 and c<>13 then st$=st$+chr$(c)
3220 if left$(st$,15)="400 bad request" then print chr$(5);
3225 if left$(st$,15)="400 bad request" then print " trying again!":goto 90
3240 print chr$(c);
3250 return
4000 rem interactive portion
4001 cy = 2: cx = 14
4002 fw$=""
4003 gosub 10100
4005 gosub 7000: print chr$(158);"use wasd, space, return";chr$(5): cy=3
4010 x=1: y=2: ox=x: oy=y
4020 poke 55296 + (oy*40)+ox, 1
4030 poke 55296 + (y*40)+x, 0
4040 ox=x: oy=y
4050 get k$: if k$="" then goto 4050
4060 if k$="w" and y>2 then y=y-1
4070 if k$="s" and y<11 then y=y+1
4080 if k$="a" and x>1 then x=x-1
4090 if k$="d" and x<10 then x=x+1
4100 if k$=chr$(32) then gosub 5100
4110 if k$=chr$(13) then gosub 5200
4190 goto 4020
5100 gosub 6000
5190 return
5200 cy=3: cx = 14: gosub 7000
5220 for i = 0 to 7
5230 if fw$=wd$(i) then print "found ";fw$;"!": gosub 10300: return
5240 next i
5250 gosub 10200
5260 print "             ":fw$=""
5270 return
6000 l$=chr$(peek(1024+(y*40)+x)+64)
6020 gosub 7000
6030 if cx=14 then print l$;"                  "
6040 if cx>14 then print l$;
6050 cx=cx+1: fw$=fw$+l$
6060 return
7000 poke 214, cy: poke 211, cx: sys 58732
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
