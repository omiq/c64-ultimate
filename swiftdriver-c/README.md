# SwiftDriver — C port (educational rewrite)

A line-by-line port of Bo Zimmerman's `swiftdrvr.asm` to C + minimal
hand-written 6502, built with **cc65**. Drop-in compatible — same load
address ($C000), same `SYS 49152` entry, same KERNAL hooks.

## Why port it?

Bo's original is ~244 lines of tight 6502 — fast and correct, but
opaque if you don't speak the dialect. This version trades a little
size and speed for **readability**:

* the bulk of the logic moves to C with one C function per asm block
* the NMI interrupt handler stays in asm (cycle-critical) but is
  heavily commented line-by-line
* every C function header cites the corresponding line range in
  `../swiftdriver/swiftdrvr.asm` so you can diff them

## Files

| File | Purpose |
|------|---------|
| `Makefile` | cc65 build rules (`make` → `swiftdrv.prg`) |
| `swift-c000.cfg` | linker config — fixes load address at $C000 |
| `swift.h` | public API + register/zero-page constants |
| `swift.c` | C bodies for INIT, DOOPEN, DOCLOSE, DOCHRIN, DOGETIN, DOPUT |
| `nmi.s` | hand-asm NMI handler (RX byte → ring buffer) |
| `test_loopback.c` | small standalone .prg that exercises the driver |

## Build

```sh
make             # builds swiftdrv.prg
make test        # also builds test_loopback.prg
make clean
```

Requires `cl65` (cc65 suite) on `PATH`. The retrogamecoders IDE has
this preinstalled and exposes it via API.

## Use (identical to Bo's original)

```basic
LOAD "SWIFTDRV",8,1
SYS 49152
OPEN 5,2,0,CHR$(8)   : REM 1200 baud
PRINT#5,"AT"+CHR$(13)
GET#5,A$
CLOSE 5
```

## Architecture

```
 ┌─────────────────────────┐
 │      BASIC program      │
 │  OPEN / PRINT# / GET#   │
 └────────────┬────────────┘
              │
 ┌────────────▼────────────┐  KERNAL ROM still entered first;
 │  KERNAL OPEN/CHRIN/...  │  it then JMPs through the indirect
 │  ($FFC0, $FFCF, ...)    │  vectors at $031A-$032B that we
 └────────────┬────────────┘  patched in swift_init().
              │
 ┌────────────▼────────────┐
 │  swift_do_open()        │
 │  swift_do_chrin()       │  C functions — readable, slow-ish
 │  swift_do_put() etc.    │
 └────────────┬────────────┘
              │ (RX path only)
 ┌────────────▼────────────┐
 │  nmi_handler (nmi.s)    │  pure asm — runs from NMI, must be
 │  reads $DE00 → ring buf │  cycle-tight
 └─────────────────────────┘
```

## Known limitations carried over from Bo's original

* `RCOUNT` ($B4) is incremented but never decremented — it's a
  monotonic byte-count, not a buffer fill level.
* Ring buffer is exactly **256 bytes** (head/tail are single-byte
  indices that wrap naturally). No overflow detection — fast incoming
  data at high baud will silently clobber unread bytes.
* No TX buffering — `PRINT#` blocks until each byte is sent.

## Roadmap

* **Phase 1** (this scaffold → working driver): port all 6 functions,
  match Bo's behaviour. Test against `simple.bas` from `c64u-kernal/`.
* **Phase 2**: add an AT-command layer (`ATGET http://...`, `ATPOST`,
  `ATDL`) on top — turns the driver into a tiny user-agent.
