5 print chr$(147);chr$(5);chr$(14);
10 if a=0 then a=1:print "loading...":load "swiftc",8,1
15 print chr$(147);
20 print "--- stage 1: ready to sys ---"
22 print "load bytes $c000:"
23 print "  ";peek(49152);peek(49153);peek(49154);peek(49155)
24 gosub 9000
30 sys 49152
35 print chr$(147);
36 print "--- stage 2: after sys ---"
37 print "031a="; peek(794)+256*peek(795);" w 49206"
38 print "031c="; peek(796)+256*peek(797);" w 49344"
39 print "0324="; peek(804)+256*peek(805);" w 49270"
40 print "032a="; peek(810)+256*peek(811);" w 49279"
41 print "0326="; peek(806)+256*peek(807);" w 49320"
49 gosub 9000
50 close 5:poke 56833,0:poke 56835,31:poke 56834,9
55 open 5,2,0,chr$(8)
60 print chr$(147);
61 print "--- stage 3: after open ---"
62 print "doopen entered (1):"; peek(820)
63 print "ba at entry:"; peek(821)
64 print "ba after f34a:"; peek(822)
65 print "is_modem entered (2):"; peek(823)
66 print "031a="; peek(794)+256*peek(795)
67 print "0318="; peek(792)+256*peek(793);" w 49390"
68 print "ba="; peek(186)
69 print "rbuff="; peek(247)+256*peek(248)
70 gosub 9000
75 close 5
80 print "done."
99 end
9000 print
9001 print "[any key]";
9002 get k$:if k$="" then 9002
9003 return
