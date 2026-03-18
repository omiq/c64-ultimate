10 rem dungeon v2 - poke screen coords 
20 rem ================================
30 rem
40 rem first initialise variables
50 col=20 : row=10 : a=0 : br=53281 : na=12288 : da=53248
60 rem set initial start position
70 gosub 4000            
80 rem     
 
100 rem ........................
110 rem now we need our c64 font
120 print "{clear}please wait"
140 gosub 7000
150 rem now show map
160 gosub 6000
                 
1000 rem start of game loop
1010 ox=col : oy=row
1020 gosub 3000 : rem get keyboard input
1030 if row<>oy or col<>ox then print "{left} "
1040 gosub 4000 : rem set the char pos
1050 print "{light blue}@";
1060 poke 2021,3   : rem c
1070 poke 2022,54  : rem 6
1080 poke 2023,52  : rem 4
1090 goto 1000 : rem go back to loop
 
3000 rem ...........................                                
3010 rem get keyboard input
3020 get p$ : rem peek(197) also works
3030 rem print asc(p$) to work out keys
3040 if p$="o" then col=col-1 : rem <
3050 if p$="p" then col=col+1 : rem >
3060 if p$="q" then row=row-1 : rem ^ 
3070 if p$="a" then row=row+1 : rem v
3080 if col < 0 then col=0
3090 if col > 39 then col=39
3100 if row < 0 then row=0
3110 if row > 23 then row=23
3120 if peek(1024+(row*40)+col)=32 then return
3130 rem don't move if not to a space
3140 row=oy : col=ox
3150 return
 
4000 rem                                
4010 rem ........................... 
4020 rem set cursor row and column
4030 x=row : y=col
4040 poke 780,a : rem set a register 
4050 poke 781,x : rem set x reg (row)
4060 poke 782,y : rem set y reg (col)
4070 poke 783,0 : rem set status reg
4080 sys 65520  : rem set the cursor
4090 return
 
6000 rem 
6010 rem ............................
6020 print "{clear}{home}{right}{right}{down}{down}{down}{cyan}press keys: q,a,o,p{white}"
6030 rem init vars, set initial position
6040 rem 
6050 dim row$( 12)
6060 row$(0) = "                    "
6070 row$(1) = "                {dark gray}======="
6080 row$(2) = "                =========="
6090 row$(3) = "                =       <="
6100 row$(4) = "                {brown}{192}      {dark gray}  {brown}{192}"
6110 row$(5) = "                {dark gray}=        ="
6120 row$(6) = "                =   {white}@    {dark gray}="
6130 row$(7) = "                =        ="
6140 row$(8) = "                =     =  ="
6150 row$(9) = "                =     =  ="
6160 row$(10) = "                = >   =  ="
6170 row$(11) = "                ========{brown}{192}{dark gray}="
6180 rem
6190 rem print the test map
6200 for r=0 to 11: print row$(r): next
6210 poke br,0 : poke br-1,0
6280 return
 
7000 rem
7020 rem ................................ 
7030 rem load customised chars 
7040 rem ................................
7050 rem
7120 rem set characterset pointer to address 12288
7130 poke 53272,(peek(53272)and240)+12
7140 ch = 0  : gosub 8020
7150 ch = 32 : gosub 8020
7160 ch = 60 : gosub 8020
7180 ch = 61 : gosub 8020
7200 ch = 62 : gosub 8020
7220 ch = 64 : gosub 8020
7230 for ch = 1 to 26 :  gosub 8020 : next
7240 for ch = 48 to 57 :  gosub 8020 : next
7250 ch = 58 : gosub 8020
7260 ch = 44 : gosub 8020
7900 return
 
8000 rem ............................... 
8010 rem load specific custom character
8020 rem ...............................
8030 for byte = 0 to 7  
8040 read cd
8050 poke 12288+(8*ch)+byte,cd
8060 next byte
8070 return
 
 
9000 data 092,087,233,089,057,030,020,054 : rem character 0
9005 data 0,0,0,0,0,0,0,0                 : rem space 
9010 data 000,126,000,060,000,024,000,000 : rem character 60
9020 data 239,138,012,000,254,170,128,000 : rem character 61
9030 data 000,000,024,000,060,000,126,000 : rem character 62
9040 data 000,060,126,254,122,126,254,126 : rem character 64
9060 data 016,040,040,068,124,068,238,000 : rem character 1
9070 data 252,066,066,124,066,066,252,000 : rem character 2
9080 data 056,068,130,128,130,068,056,000 : rem character 3
9090 data 252,066,066,066,066,066,252,000 : rem character 4
9100 data 254,066,072,120,072,066,254,000 : rem character 5
9110 data 254,066,072,120,072,064,224,000 : rem character 6
9120 data 060,066,128,142,130,066,060,000 : rem character 7
9130 data 238,068,124,068,068,068,238,000 : rem character 8
9140 data 254,016,016,016,016,016,254,000 : rem character 9
9150 data 124,016,016,016,144,144,096,000 : rem character 10
9160 data 238,068,072,112,072,068,238,000 : rem character 11
9170 data 224,064,064,064,066,066,254,000 : rem character 12
9180 data 238,084,084,084,068,068,238,000 : rem character 13
9190 data 238,100,084,084,076,076,228,000 : rem character 14
9200 data 056,068,130,130,130,068,056,000 : rem character 15
9210 data 252,066,066,066,124,064,224,000 : rem character 16
9220 data 056,068,130,130,146,076,058,000 : rem character 17
9230 data 252,066,066,066,124,072,238,000 : rem character 18
9240 data 124,130,128,124,002,130,124,000 : rem character 19
9250 data 254,146,016,016,016,016,056,000 : rem character 20
9260 data 238,068,068,068,068,068,056,000 : rem character 21
9270 data 238,068,068,040,040,040,016,000 : rem character 22
9280 data 238,068,068,084,084,108,068,000 : rem character 23
9290 data 238,068,040,016,040,068,238,000 : rem character 24
9300 data 238,068,040,040,016,016,056,000 : rem character 25
9310 data 254,132,008,016,032,066,254,000 : rem character 26
 
9320 DATA 056,068,130,130,130,068,056,000 : REM CHARACTER 0
9330 DATA 048,080,144,016,016,016,254,000 : REM CHARACTER 1
9340 DATA 124,130,002,124,128,130,254,000 : REM CHARACTER 2
9350 DATA 254,132,008,028,130,130,124,000 : REM CHARACTER 3
9360 DATA 012,024,040,074,254,010,028,000 : REM CHARACTER 4
9370 DATA 254,130,252,002,130,130,124,000 : REM CHARACTER 5
9380 DATA 124,130,128,252,130,130,124,000 : REM CHARACTER 6
9390 DATA 254,132,008,008,016,016,056,000 : REM CHARACTER 7
9400 DATA 124,130,130,124,130,130,124,000 : REM CHARACTER 8
9410 DATA 124,130,130,130,124,004,120,000 : REM CHARACTER 9
9420 data 000,000,024,000,000,024,000,000 : rem character 58
9430 data 000,000,000,000,000,024,024,048 : rem character 44

