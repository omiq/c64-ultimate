# httpget-tool

Single-PRG HTTP fetch tool for C64 Ultimate. Designed to be **called
from BASIC**: load once, fetch any URL, iterate the response bytes
out of REU via simple SYS + PEEK.

```
                     ┌─────────────────────────┐
   BASIC PROGRAM ────┤  SYS 49158, "http://…"  │  fetch into REU
                     │  SYS 49161              │  copy next byte
                     │  B = PEEK(zp_byte)      │  read it
                     └─────────────────────────┘
                              │
                              ▼ all the modem/HTTP plumbing in C
                     ┌─────────────────────────┐
                     │  ACIA + NMI ring buf    │
                     │  Hayes AT + HTTP parser │
                     │  REU stash (16 MB)      │
                     └─────────────────────────┘
```

## Why REU storage?

C64 main RAM is 64 KB total, with maybe 38 KB free for BASIC programs.
A single HTTP response can easily exceed that. The Ultimate's REU
emulation gives us up to **16 MB** of DMA-fast scratch space — more
than any HTTP response we'll ever care about. The response body lands
there, BASIC reads it back byte-at-a-time at its own pace.

## BASIC interface (planned)

| Entry point         | What it does                                          |
|---------------------|-------------------------------------------------------|
| `SYS HG_INSTALL`    | One-time setup: install ACIA / NMI / hooks            |
| `SYS HG_FETCH, U$`  | Dial + send GET + slurp body into REU starting at 0   |
| `SYS HG_SIZE`       | Total body bytes available → `PEEK(SZL) + 256*PEEK(SZH) + 65536*PEEK(SZX)` |
| `SYS HG_READ`       | Copy next byte from REU → `PEEK(HGBYTE)` (auto-advances pointer) |
| `SYS HG_REWIND`     | Reset REU read pointer to 0 (like BASIC `RESTORE`)    |
| `SYS HG_CLOSE`      | Hang up modem, free resources                         |

Concrete BASIC example (sketch):

```basic
10 sys 49152                    : rem install
20 u$ = "http://192.168.0.5:8080/"
30 for i = 1 to len(u$): poke 512+i-1, asc(mid$(u$,i,1)): next
40 poke 512+len(u$), 0          : rem null terminate
50 sys 49158                    : rem fetch
60 sz = peek(2) + 256*peek(3)
70 for i = 1 to sz
80   sys 49161
90   print chr$(peek(4));
100 next
110 sys 49167                   : rem close
```

## Layout (planned)

| File             | Purpose |
|------------------|---------|
| `Makefile`       | cc65 build, target $C000 |
| `httptool.c`     | main() + SYS dispatcher + URL parser + HTTP slurp |
| `nmi.s`          | NMI ring-buffer ISR (reused from `../httpget-c/`) |
| `entry.s`        | Fixed SYS entry-point JMP table at $C000 |
| `httptool.cfg`   | cc65 linker config — code at $C000, BSS above |

## Status

**Scaffold only.** Real fetch logic gets lifted from
`../httpget-c/httpget.c` (which is proven end-to-end working) and
re-shaped into resident SYS-callable functions backed by REU storage.

## Build

```sh
make            # produces httptool.prg
make run        # deploys via ../runner.py
```

Once shipped:

```basic
LOAD "HTTPTOOL",8,1
SYS 49152                       : REM install (one-time)
```
