
## SwiftLink TCP “terminal” in C64 BASIC V2: a detailed walkthrough

This program turns a C64 into a simple “terminal” that talks to a TCP server through a SwiftLink (6551 ACIA) running a Hayes-style “TCP modem” firmware (or similar emulation). It:

1. Sets up the SwiftLink 6551 registers
2. Sends `AT` and `ATDT ip:port` to connect
3. Waits for a response from the server and collects it
4. Starts a word guessing game using the received data

You can use the communications part as a template for any SwiftLink-based project: chat, BBS menus, online lookups, and so on.

 

## 1) The ACIA registers (where SwiftLink lives)

SwiftLink maps a 6551 ACIA into the C64’s I/O space. In your program it’s at `$DE00`, which in decimal is `56832`.

```basic
60 dr=56832 :rem data register (read = receive, write = transmit)
70 sr=56833 :rem status register (flags: rx ready, tx ready, errors)
80 cm=56834 :rem command register (parity, echo, dtr, interrupts)
90 ct=56835 :rem control register (baud rate, word size, stop bits)
```

Think of these as four “ports”:

* **DR (Data Register)**
  Read from it to get incoming bytes. Write to it to send a byte.

* **SR (Status Register)**
  Read-only flags that tell you what the ACIA is ready to do.

  * Bit 3 (value 8): receive data ready
  * Bit 4 (value 16): transmit register empty (ready to send)

* **CM (Command Register)**
  Settings like parity, echo, DTR, interrupts, and receive enable.

* **CT (Control Register)**
  Baud rate and framing (data bits, stop bits, clock source). The exact meaning depends on the 6551, plus SwiftLink’s crystal affects the final speed.

 

## 2) Startup: clear screen, reset ACIA, set speed

```basic
110 print chr$(147);chr$(5);"connecting ...":s=0
130 poke sr,0
170 poke ct,16:rem poke ct,31 on c64u
200 poke cm,9
220 for i=1 to 500:next
```

### Clear screen and set colour

* `CHR$(147)` clears the screen.
* `CHR$(5)` sets text colour (green on a stock C64).
* `s=0` just initialises a variable used later.

### Reset the 6551

`POKE sr,0` is a common “reset-ish” trick with the 6551. On real hardware, the 6551 reset behaviour is a bit quirky, but for SwiftLink setups this is often enough to clear state.

### Control register: baud and framing

You’ve got:

```basic
170 poke ct,16:rem poke ct,31 on c64u
```

This is the part you’ll likely tweak most.

* On many SwiftLink setups, the effective baud rate can be different from the raw 6551 table because SwiftLink uses a different crystal (commonly “doubles” the typical rates compared to a stock 6551 setup).
* Your comment suggests:

  * `ct=16` for your current setup
  * `ct=31` for C64 Ultimate

So in the tutorial, I’d present this as: “use the value that matches your hardware/firmware, and test which is stable”.

### Command register: parity/echo/DTR/receive enable

```basic
200 poke cm,9
```

You’ve noted it as “no parity, no echo, DTR on, receive enabled”.

Even if someone doesn’t memorise the bit meanings, the important practical takeaway is: this enables receive and sets a sensible default line configuration for modem-style traffic.

### Delay

The short delay:

```basic
220 for i=1 to 500:next
```

gives the cartridge/firmware time to settle after the register writes, and helps avoid missing the first characters when you start sending `AT` commands.

 

## 3) Sending modem commands: `AT` and `ATDT`

The program sends commands by building a string in `ts$` and calling a subroutine that transmits it one character at a time.

```basic
250 ts$=chr$(13)+"at"+chr$(13)
260 gosub 700

280 ts$="atdt 127.0.0.1:6464"+chr$(13)+chr$(13)+chr$(13)
290 gosub 700
```

### Why the leading CR?

The first command is:

```basic
chr$(13)+"at"+chr$(13)
```

That leading carriage return helps if the modem emulator is mid-line or waiting for a previous command to finish. It’s a simple way to “get back to a clean prompt state”.

### Why multiple CRs after ATDT?

You used three CRs:

```basic
... + chr$(13)+chr$(13)+chr$(13)
```

That’s belt-and-braces. Some emulators are picky about line endings, and extra CRs usually don’t hurt. If you want to tighten it up later, you can reduce it to one CR once you know your modem emulator behaves consistently.

### The send-string subroutine

```basic
700 rem send string ts$ character by character
730 for i=1 to len(ts$)
740 b=asc(mid$(ts$,i,1))
750 gosub 800
760 next
770 return
```

* `MID$` extracts one character from the string.
* `ASC` converts that character into its byte value (0–255).
* It stores that byte in `b`, then calls the “send one byte” routine.

### The send-one-byte routine

```basic
800 rem send one byte in b
850 s=peek(sr)
860 if (s and 16)=0 then 850
870 poke dr,b
880 return
```

This is the core of reliable sending:

* `PEEK(sr)` reads status flags.
* `(s AND 16)` tests bit 4 (transmit ready).
* If transmit isn’t ready, it loops until it is.
* Then it `POKE`s the byte to the data register, which transmits it.

That “wait until ready” step is why this works better than just blindly writing bytes.

 

## 4) Reading from the server: a tight receive loop

After dialing, the program waits for the server response and builds up `w$`.

Here’s the key structure:

```basic
440 s=peek(sr)
450 if (s and 8)=0 then goto 440
470 c=peek(dr)
```

* `(s AND 8)` checks bit 3 (receive data ready).
* Only when data is ready does it read from `dr`.

### Using `#` and CR as delimiters

You’re using `#` (ASCII 35) and carriage return (13) as markers in the incoming stream.

```basic
500 if c<>35 then goto 440
...
530 c=peek(dr)
540 if c<>13 then i$=i$+chr$(c)
550 if c=35 then w$=w$+i$:i$="":sg=sg+1:print chr$(147)"loading "sg
560 if sg<4 then goto 510
```

This logic is a little unusual at first glance, but the intent is clear:

* You’re waiting for `#` to appear, which signals “a chunk is starting” (or a prompt from your server).
* Then you read characters into `i$` until you hit a terminator (you treat CR specially, and you also use `#` to mark chunk boundaries).
* Every time you see a `#`, you treat it as “chunk complete”: append `i$` onto `w$`, clear `i$`, increment `sg`, and show a “loading” screen.
* After 4 chunks (`sg < 4`), you continue; once you have enough chunks, you jump to the game.

### What the server needs to send

Given the later parsing in the game (splitting `w$` into word and definition using `#`), the cleanest protocol is:

* Send a few “chunks” that start/end with `#` (matching your `sg` counter), and include the final payload somewhere inside.
* The final payload should contain:
  `word#definition`

For example, the actual meaningful payload string could be:

```
#apple#A fruit with crisp flesh#
```

or, if you prefer more structure:

```
#DATA#apple#A fruit with crisp flesh#
```

Your game code expects there to be a `#` between the word and the definition.

 

## 5) The game: parsing `w$` into word and definition

Once the receive stage finishes:

```basic
580 goto 1000
```

### Cleaning up the received string

```basic
1020 w$ = mid$(w$,5,len(w$)-6): c=0
```

This strips characters off the start and end. The exact numbers (start at 5, trim 6 off the end) are tailored to whatever your server wraps around the payload.

If you change the server’s formatting later, this is the first line you’ll revisit.

### Extracting the word and definition

```basic
1050 c=c+1
1060 if mid$(w$,c,1) <> "#"then goto 1050
1070 gw$ = left$(w$,c-1): rem word to guess
1080 gd$ = mid$(w$,c+1): rem word definition
```

This finds the first `#` in `w$`.

* Everything before the first `#` becomes the word `gw$`
* Everything after becomes the definition `gd$`

So the payload needs to look like:

```
word#definition text...
```

### Guess loop with letter hints

```basic
1100 for tr = 1 to 10
1110 print "enter your guess";: input a$
1120 if a$=gw$ then goto 3000
1130 for c=1 to len(gw$)
1140 if mid$(a$,c,1)=mid$(gw$,c,1) then print mid$(gw$,c,1);
1150 if mid$(a$,c,1)<>mid$(gw$,c,1) then print "*";
1160 next c
1200 print chr$(13);(10-tr);" attempts remaining";chr$(13)
1210 next tr
```

This gives a Wordle-style hint line:

* If a letter is correct in the correct position, it prints the letter.
* Otherwise it prints `*`.

There’s no check for length mismatches. If the user enters a shorter guess, `MID$` past the end returns `""`, which just won’t match, so you get `*` for those positions. That’s acceptable for a simple game, but you could optionally enforce `LEN(a$)=LEN(gw$)`.

### End states

* Fail path prints the word and definition and waits for a keypress.
* Success path does the same with a congratulation message.

 

## 6) Practical tweaks you’ll probably want

### A) Swap localhost for a real server

Right now you dial:

```basic
atdt 127.0.0.1:6464
```

On a real C64, `127.0.0.1` is “the SwiftLink device itself”, so it only makes sense if the modem emulator treats it specially. Normally you’ll change it to your server’s IP or hostname (depending on what your firmware supports).

Example:

```basic
ts$="atdt 5.75.xxx.xxx:6464"+chr$(13)
```

### B) Make receive buffering more robust

Your current loop waits for specific markers and then reads more bytes. If anything arrives out-of-order, or if you miss a byte, it can get stuck.

A more general pattern is:

* If RX ready, read a byte and append it to a buffer
* Check the buffer for an end marker (like `#END#` or a final `#`)
* When marker found, stop receiving

Even if you keep your current protocol, consider having the server send a clear terminator string so the C64 knows when it has the full payload.

### C) Clear variables before receive

You use `i$`, `w$`, `sg` but don’t initialise them right before the receive loop. It will usually work because BASIC defaults to empty/0, but it’s safer to explicitly do:

```basic
300 t$="": i$="": w$="": sg=0
```

(You already set `t$=""` but don’t use it afterwards.)

### D) Case handling

If the server sends lowercase but the user types uppercase (or vice versa), `a$=gw$` will fail. You can either:

* Force both to uppercase with `a$=chr$(asc(a$) and 223)` style logic (messy in BASIC), or
* Tell players “type in lowercase”.

 

## 7) What to tell readers about the “AT modem” assumption

A key point for anyone copying this: the SwiftLink itself does not magically speak TCP. You need some layer that turns serial bytes into a TCP connection, which could be:

* A SwiftLink-compatible firmware/device that offers Hayes `AT` commands and TCP dialing
* A bridge box on the user port or cartridge that does serial-to-TCP
* An emulator setup (VICE + tcpser, etc.)

This program assumes that sending `AT` and `ATDT host:port` will work.

