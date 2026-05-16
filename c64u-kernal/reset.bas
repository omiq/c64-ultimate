10 rem ------------------------------------------------------------
20 rem modem reset — run after stop/restore left things hung
30 rem ------------------------------------------------------------
40 close 5
50 poke 56833,0:poke 56835,31:poke 56834,9:for w=1 to 500:next
60 sys 49152
70 open 5,2,0,chr$(15) : rem 19200 baud
80 print "draining..."
90 q=0
100 get#5,a$
110 if a$<>"" then q=0:goto 100
120 q=q+1:if q<500 then 100
130 print "hangup..."
140 print#5,"+++";:for w=1 to 2500:next
150 print#5,"ath"+chr$(13);:for w=1 to 2500:next
160 close 5
170 print "modem reset. ok to run other programs."
