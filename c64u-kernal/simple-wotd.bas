0 print chr$(147);chr$(5);chr$(14);
10 if a=0 then a=1:print "loading driver...":load "swiftdrvr",8,1
15 poke 56833,0:poke 56835,31:poke 56834,9:for w=1 to 500:next
20 sys 49152 : rem turn on swiftlink driver
25 print "driver ready."
28 close 5 : rem clear any leftover open from prior stop
30 open 5,2,0,chr$(7) : rem 600 baud
40 rem drain any junk in buffer before dialing
45 get#5,a$:if a$<>"" then print a$;:goto 45
50 rem hang up first for clean state
55 print#5,"+++";:for w=1 to 500:next:print#5,"ath"+chr$(13);
60 for w=1 to 1000:next
70 rem dial bbs raw tcp on port 6464
80 print#5,"atdt bbs.retrogamecoders.com:6464"+chr$(13);
90 rem read forever - shows whatever bbs sends
140 get#5,a$
150 if a$<>"" then print a$;
160 goto 140
