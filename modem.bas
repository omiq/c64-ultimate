1 cr$=chr$(10)+chr$(13)
2 print chr$(5): print chr$(147): print chr$(19);
3 open2,2,0,chr$(8)+chr$(0):rem open the serial port
4 rem 1200 baud: open2,2,0,chr$(0) + chr$(0) + chr$(61
8 print#2,"ate0";cr$;"atdt 192.168.0.154:6464";cr$
9 rem main loop
10 get k$:rem get from c64 keyboard
11 if k$ = chr$(13) then print#2,chr$(10)+chr$(13);
12 if k$<>"" and k$ <> chr$(13) then print#2,k$;
13 get#2,c$: s$=s$+c$
14 if (peek(663) and 8) = 0 then goto 13:rem wait until all chars transmitted
15 print s$;:s$="":rem print received chars
16 goto 10
17 close 2:end
