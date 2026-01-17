10 rem swiftlink tcp call + read loop
20 dr=56832
30 sr=56833
40 cm=56834
50 ct=56835
60 print chr$(147)
70 print "swiftlink tcp test"
80 rem reset acia
90 poke sr,0
100 rem control: 8n1, internal clock, baud (x2)
110 poke ct,31
120 rem command: no parity, no echo, dtr on, rx enable
130 poke cm,9
140 for i=1 to 500:next
150 rem send ate0
160 ts$=chr$(13)+"at"+chr$(13)
170 gosub 700
180 rem dial tcp
190 ts$="atdt 192.168.0.154:6464"+chr$(13)
200 gosub 700
205 for i=1 to 2000:next
206 s=peek(sr):s=peek(sr)
210 print "connected, listening..."
220 rem main read loop
230 s=peek(sr)
240 if (s and 8)=0 then 230
250 c=peek(dr)
260 if c=10 then c=13
270 print chr$(c);
280 goto 230
700 rem send string ts$
710 for i=1 to len(ts$)
720 b=asc(mid$(ts$,i,1))
730 gosub 800
740 next
750 return
800 rem wait tx ready, send b
810 s=peek(sr)
820 if (s and 16)=0 then 810
830 poke dr,b
840 return
