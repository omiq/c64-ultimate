rem ------------------------------------------------------------
rem http-new.bas
rem ------------------------------------------------------------
rem load a web page (c64u kernal + swiftdriver)
rem based on simple.bas pattern + ../http-get.bas logic
rem ------------------------------------------------------------
rem
rem
rem lower case and white text
print chr$(147);chr$(5);chr$(14);

rem check if already loaded
if a=0 then a=1:print "loading driver...":load "swiftdrvr",8,1
poke 56833,0:poke 56835,31:poke 56834,9:for w=1 to 500:next
sys 49152 : rem turn on swiftlink driver (also after reload restart)
print "driver ready."

close 5 : rem clear any leftover open from prior stop
open 5,2,0,chr$(7) : rem 600 baud (chr$(14)=9600 if you want faster)
crlf$=chr$(13)+chr$(10)

rem drain any junk in buffer before dialing
get#5,a$:if a$<>"" then print a$;:goto 45

rem hang up first for clean state
print#5,"+++";:for w=1 to 500:next:print#5,"ath"+chr$(13);
for w=1 to 1000:next

rem dial
print#5,"atdt php.retrogamecoders.com:80"+chr$(13);

rem send http request (wait a sec for connect first)
for w=1 to 3000:next
print#5,"get / http/1.1"+crlf$;
print#5,"host: php.retrogamecoders.com"+crlf$+crlf$;

chars:
rem read forever - keep looping whether or not bytes pending
get#5,a$
if a$<>"" then p=0:print a$;
if p<1000 then p=p+1:goto chars
end