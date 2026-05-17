# C64 Ultimate HTTP — project spec

End-2026-05 snapshot. Captures architecture decisions, current state,
and roadmap so any future session (human or AI) can pick up cleanly
without re-deriving everything from chat history.

## Goal

Enable C64 Ultimate users to make HTTP calls (and raw TCP) from their
programs — both pure-C standalone tools and BASIC programs that need
a single-PRG, no-extra-driver helper.

## Architecture decisions

### Direct ACIA + NMI ring buffer (winner)

`httpget-c/httpget.c` and `httpget-c/wotd.c` talk to the SwiftLink 6551
ACIA at `$DE00` directly. NMI ring buffer (`httpget-c/nmi.s`) catches
RX bytes during screen scroll / disk writes / etc. No external driver
file required — entire program is one self-contained `.prg`.

Trade-offs:
- ✓ Single PRG, no `LOAD "SWIFTDRVR",8,1` step beforehand
- ✓ No KERNAL vector collisions with JiffyDOS etc.
- ✓ Polled TX is simple
- ✗ Re-implements what Bo Zimmerman already wrote — bug surface is ours

### Alternative: SwiftDriver blob wrapper (archived)

`httpget-c/archive/swift.h` + `swiftdrvr_blob.h` would `memcpy` Bo's
292-byte `swiftdrvr.prg` to `$C000` at startup, then use `cbm_open/
read/write` which route through Bo's installed KERNAL hooks. Works,
but redundant now that direct ACIA does. Kept as fallback if C64U
firmware breaks the direct path.

### C-port of SwiftDriver (separate effort)

`swiftdriver-c/` was an earlier "rewrite Bo's asm in C for educational
value" exercise. Functional but exhibited subtle differences from Bo's
original (TCP didn't establish cleanly). Not used by current httpget
work but kept for the audience write-up about porting asm to C.

## Current artefacts

| Path | What it is | Status |
|------|------------|--------|
| `httpget-c/httpget.c` | Pure-C HTTP GET, fixed target URL | **Working end-to-end** |
| `httpget-c/wotd.c`    | Pure-C raw TCP BBS reader | **Working** |
| `httpget-c/nmi.s`     | NMI ring-buffer ISR (shared) | **Working** |
| `httpget-c/test_server.py` | Local Mac Python TCP debug server | Works |
| `httpget-c/archive/` | SwiftDriver-blob alternative | Reference only |
| `httpget-tool/` | Resident BASIC-callable HTTP tool with REU storage | **Scaffold builds, TODOs to fill** |
| `swiftdriver-c/` | Earlier C-port of Bo's asm | Educational reference |
| `c64u-kernal/` | BASIC programs + Bo's swiftdrvr | Working |

## Phase 2 plan: `httpget-tool/`

Single PRG loaded at `$C000`, exposes SYS entries for BASIC:

```
SYS 49152            -> hg_install   (one-time setup)
SYS 49155            -> hg_fetch     (URL pre-written to $0200)
SYS 49158            -> hg_size      (PEEK $02/$03/$04 for 24-bit len)
SYS 49161            -> hg_read      (PEEK $05 for next byte, auto-advances)
SYS 49164            -> hg_rewind    (reset read pointer to 0)
SYS 49167            -> hg_close     (hangup)
```

Body lives in REU (1750 register interface at `$DF00-$DF0A`) so size
is bounded by REU capacity (up to 16 MB on C64U) not C64 RAM.

BASIC user flow:
```basic
10 sys 49152                        : rem install
20 u$ = "http://php.retrogamecoders.com:80/"
30 for i = 1 to len(u$): poke 511+i, asc(mid$(u$,i,1)): next
40 poke 512+len(u$), 0
50 sys 49155                        : rem fetch
60 sz = peek(2) + 256*peek(3)
70 for i = 1 to sz: sys 49161: print chr$(peek(5));: next
```

## Hard-won wire-protocol gotchas

These cost a multi-hour session to find:

1. **cc65 c64-target strings are PETSCII, not ASCII** — must translate
   in `acia_send` for bytes-on-wire to be valid for HTTP/AT parsers.
2. **`ATDT` needs NO space before host** on C64U virtual modem.
   `ATDThost:port\r` connects; `ATDT host:port\r` returns NO ANSWER.
3. **AT command terminator: `\n`** works on C64U (not `\r` as spec).
4. **`+++ATH` hangup unreliable from fast C** — Hayes guard times
   (1s silence both sides of `+++`) hard to enforce. Use **DTR drop**
   instead: write `0x08` to ACIA COMMAND, wait ~1s, write `0x09`.
5. **JiffyDOS conflicts** with KERNAL vector hooks. Disable for
   anything that wedges `$031A-$032B` or `$0318`.
6. **cc65 `cputs('\n')` is a bug** — passes int as pointer. Use
   `cputc('\n')` for single char or `cputs("\n")` for string. Also
   note C64 newline is `\r` (13) not `\n` (10).
7. **cc65 `uint32_t` ops are slow** — ~100 cycles/increment. Use
   nested `uint8_t × uint16_t` for timeouts; otherwise "30-second
   timeout" can be 2-minute wall clock.

## Workflow

- Edit C / asm in `httpget-c/` or `httpget-tool/`
- `make run` deploys to C64U via `runner.py` (HTTP POST, no disk, no
  power cycle, auto-runs)
- Screen feedback on C64U or live `python3 test_server.py` on Mac
- Build timestamp via `__DATE__ __TIME__` macros prints at top of
  each program — confirms which build is actually running

For BASIC + driver shipping: `c64u-kernal/build-disk.sh` builds
`kernal.d64` from .bas sources and FTPs to C64U.

## Roadmap

- [x] Phase 1: working pure-C HTTP client (`httpget.c`)
- [x] Phase 1.5: same engine for raw TCP (`wotd.c`)
- [ ] Phase 2: BASIC-callable resident tool with REU storage
      (`httpget-tool/`)
- [ ] Phase 2.5: end-to-end C example demo (user's stream)
- [ ] Phase 3 possibilities:
  - Turbo mode (`$D030`) for receive loop
  - Higher baud (2400/4800/9600) once polling proven
  - URL parser supporting `?query=string` and POST
  - TLS proxy via local Mac if anyone cares

## Useful addresses

- ACIA registers: `$DE00` data, `$DE01` status, `$DE02` command, `$DE03` control
- KERNAL indirect vectors: `$0318` NMI, `$031A` OPEN, `$031C` CLOSE, `$0324` CHRIN, `$032A` GETIN, `$0326` BSOUT
- ACIA COMMAND values: `$09` = DTR+RX-IRQ on, `$0B` = DTR on RX-IRQ off, `$08` = DTR off (hangup)
- REU registers: `$DF00`-`$DF0A`; commands `$B0` stash-go, `$B1` fetch-go
