10 if a=0 then a=1:print "loading driver...":load "swiftdrvr",8,1
15 poke 56833,0:poke 56835,31:poke 56834,9:for w=1 to 500:next
20 sys 49152 : rem turn on swiftlink driver (also after reload restart)
25 print "driver ready."
28 close 5 : rem clear any leftover open from prior stop
30 open 5,2,0,chr$(7) : rem 600 baud (chr$(14)=9600 if you want faster)
35 crlf$=chr$(13)+chr$(10)
40 rem drain any junk in buffer before dialing
45 get#5,a$:if a$<>"" then print a$;:goto 45
50 rem hang up first for clean state
55 print#5,"+++";:for w=1 to 500:next:print#5,"ath"+chr$(13);
60 for w=1 to 1000:next
70 rem dial
80 print#5,"atdt php.retrogamecoders.com:80"+chr$(13);
90 rem send http request (wait a sec for connect first)
100 for w=1 to 3000:next
110 print#5,"get / http/1.1"+crlf$;
120 print#5,"host: php.retrogamecoders.com"+crlf$+crlf$;
130 rem read forever — keep looping whether or not bytes pending
140 get#5,a$
150 if a$<>"" then print a$;
160 goto 140
