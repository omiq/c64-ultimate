0 print chr$(147);chr$(5);chr$(14);
10 if a=0 then a=1:print "loading c driver...":load "swiftc",8,1
15 poke 56833,0:poke 56835,31:poke 56834,9:for w=1 to 500:next
20 sys 49152 : rem init c driver
25 print "c driver ready."
28 close 5
30 open 5,2,0,chr$(7) : rem 600 baud (match working simple.bas)
35 crlf$=chr$(13)+chr$(10)
40 rem drain
45 get#5,a$:if a$<>"" then print a$;:goto 45
50 rem hangup
55 print#5,"+++";:for w=1 to 500:next:print#5,"ath"+chr$(13);
60 for w=1 to 1000:next
70 rem dial
80 print#5,"atdt php.retrogamecoders.com:80"+chr$(13);
100 for w=1 to 3000:next
110 print#5,"get / http/1.1"+crlf$;
120 print#5,"host: php.retrogamecoders.com"+crlf$+crlf$;
130 rem read forever
140 get#5,a$
150 if a$<>"" then print a$;
160 goto 140
