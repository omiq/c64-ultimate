10 dr=56832:sr=56833:cm=56834:ct=56835
20 print chr$(147);chr$(5);"swiftlink term"
30 poke sr,0:poke ct,31:poke cm,9
40 for i=1 to 500:next
50 ts$=chr$(13)+"at"+chr$(13):gosub 700
60 ts$="atdt 192.168.0.154:6464"+chr$(13):gosub 700
70 print:print "connected"
100 rem main loop
110 get a$
120 if a$<>"" then b=asc(a$):gosub 800
130 s=peek(sr)
140 if (s and 8)=0 then 110
150 c=peek(dr)
160 if c=10 then c=13
170 print chr$(c);
180 goto 110
700 for i=1 to len(ts$)
710 b=asc(mid$(ts$,i,1))
720 gosub 800
730 next
740 return
800 s=peek(sr)
810 if (s and 16)=0 then 800
820 poke dr,b
830 return
