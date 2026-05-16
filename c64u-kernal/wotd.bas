10 rem ------------------------------------------------------------
20 rem word of the day via bbs (c64 ultimate / kernal + swiftdriver)
30 rem ------------------------------------------------------------
40 cn=5:ld=0
50 if ld=0 then ld=1:load "swiftdrvr",8,1
60 sys 49152
70 print chr$(147);chr$(5);"connecting ...":s=0
80 open cn,2,0,chr$(7):rem 600 baud
90 cr$=chr$(13)
100 ts$=cr$+"at"+cr$:gosub 700
110 ts$="atdt bbs.retrogamecoders.com:6464"+cr$
120 gosub 700
130 i$="":w$="":sg=0
140 get#cn,a$:if a$="" then goto 140
150 c=asc(a$)
160 if c<>35 then goto 140
170 get#cn,a$:if a$="" then goto 170
180 c=asc(a$)
190 if c<>13 then i$=i$+chr$(c)
200 if c=35 then w$=w$+i$:i$="":sg=sg+1:print chr$(147)"loading "sg
210 if sg<4 then goto 170
220 close cn
230 goto 1000
700 rem send ts$
710 for i=1 to len(ts$)
720 print#cn,mid$(ts$,i,1);
730 next
740 gosub 800
750 return
800 if (peek(663) and 8)=0 then 800
810 return
1000 rem word guessing game
1020 w$ = mid$(w$,5,len(w$)-6): c=0
1030 print chr$(147)chr$(5)spc(3)"can you guess the word of the day?"
1040 print
1050 c=c+1
1060 if mid$(w$,c,1) <> "#"then goto 1050
1070 gw$ = left$(w$,c-1)
1080 gd$ = mid$(w$,c+1)
1090 print "the word is "len(gw$)" letters long";chr$(13)
1100 for tr = 1 to 10
1110 print "enter your guess";: input a$
1120 if a$=gw$ then goto 3000
1130 for c=1 to len(gw$)
1140 if mid$(a$,c,1)=mid$(gw$,c,1) then print mid$(gw$,c,1);
1150 if mid$(a$,c,1)<>mid$(gw$,c,1) then print "*";
1160 next c
1200 print chr$(13);(10-tr);" attempts remaining";chr$(13)
1210 next tr
2000 print chr$(147);chr$(5);
2010 print "better luck next time, the word was"
2020 print chr$(13)gw$chr$(13)
2030 print gd$
2040 get a$: if a$="" then 2040
2050 end
3000 print chr$(147);chr$(5);
3010 print "well done you guessed correctly!"
3020 print chr$(13)gw$chr$(13)
3030 print gd$
3040 get a$: if a$="" then 3040
3050 end
