10 rem ------------------------------------------------------------
20 rem word of the day (c64u kernal + swiftdriver)
30 rem based on simple.bas pattern + ../wotd.bas logic
40 rem raw tcp bbs (not http)
50 rem ------------------------------------------------------------
60 w$="":i$="":sg=0
70 if ld=0 then ld=1:print "loading driver...":load "swiftdrvr",8,1
75 poke 56833,0:poke 56835,31:poke 56834,9:for w=1 to 500:next
80 sys 49152
90 print chr$(147);chr$(5);"connecting ..."
95 close 5 : rem clear any leftover open from prior stop
100 open 5,2,0,chr$(7)
110 rem quiet-drain
120 gosub 5000
130 rem hangup first for a clean modem state
140 print#5,"+++";:for w=1 to 800:next
150 print#5,"ath"+chr$(13);:for w=1 to 1500:next
160 gosub 5000
170 rem wake up modem
180 print#5,chr$(13)+"at"+chr$(13);
190 for w=1 to 500:next
200 gosub 5000
210 rem dial
220 print#5,"atdt bbs.retrogamecoders.com:6464"+chr$(13);
230 rem wait until first '#' marker arrives
240 get#5,a$:if a$="" then 240
250 c=asc(a$):if c<>35 then 240
260 rem read 4 #-terminated segments into w$
270 get#5,a$:if a$="" then 270
280 c=asc(a$)
290 if c<>13 and len(i$)<200 then i$=i$+chr$(c)
300 if c=35 then w$=w$+i$:i$="":sg=sg+1:print chr$(147);"loading ";sg
310 if sg<4 then 270
320 gosub 3000:close 5
1000 rem word guessing game
1020 w$=mid$(w$,5,len(w$)-6):c=0
1030 print chr$(147);chr$(5);spc(3);"can you guess the word of the day?"
1040 print
1050 c=c+1
1060 if mid$(w$,c,1)<>"#" then 1050
1070 gw$=left$(w$,c-1)
1080 gd$=mid$(w$,c+1)
1090 print "the word is";len(gw$);"letters long";chr$(13)
1100 for tr=1 to 10
1110 print "enter your guess";:input a$
1120 if a$=gw$ then 4000
1130 for c=1 to len(gw$)
1140 if mid$(a$,c,1)=mid$(gw$,c,1) then print mid$(gw$,c,1);
1150 if mid$(a$,c,1)<>mid$(gw$,c,1) then print "*";
1160 next c
1200 print chr$(13);(10-tr);"attempts remaining";chr$(13)
1210 next tr
2000 print chr$(147);chr$(5)
2010 print "better luck next time, the word was"
2020 print chr$(13);gw$;chr$(13)
2030 print gd$
2040 get a$:if a$="" then 2040
2050 end
3000 rem hangup
3010 print#5,"+++";:for w=1 to 800:next
3020 print#5,"ath"+chr$(13);:for w=1 to 1500:next
3030 return
5000 rem drain until sustained quiet
5010 q=0
5020 get#5,a$
5030 if a$<>"" then q=0:goto 5020
5040 q=q+1:if q<500 then 5020
5050 return
4000 print chr$(147);chr$(5)
4010 print "well done you guessed correctly!"
4020 print chr$(13);gw$;chr$(13)
4030 print gd$
4040 get a$:if a$="" then 4040
4050 end
