# httpget-c — C64 HTTP/TCP over SwiftLink (single PRG)

Pure **cc65** C programs that talk to the 6551 ACIA at `$DE00` directly,
with an **NMI ring buffer** (`nmi.s`) so RX is not lost during screen
scroll. No `LOAD "SWIFTDRVR"` step — one self-contained `.prg`.

## Programs

| Source | Output | Purpose |
|--------|--------|---------|
| `httpget.c` | `httpget.prg` | HTTP GET (default target in source; edit `HOST`/`PORT`) |
| `wotd.c` | `wotd.prg` | Raw TCP to BBS (`bbs.retrogamecoders.com:6464`) |

`Makefile` currently builds **`wotd.prg`** by default; change `OUT` to
build `httpget.c` instead.

## Build and run on C64 Ultimate

```bash
pip install requests python-dotenv   # for runner.py
# .env: C64U_PASSWORD=...

cd httpget-c
make run
```

Posts the PRG to the Ultimate via [`../runner.py`](../runner.py) (no disk,
no power cycle).

## Local debug server

```bash
python3 test_server.py
```

Point `httpget.c` at your Mac IP and the test server port.

## C64 Ultimate menu

Same as KERNAL path: **ACIA `DE00/NMI`**, **SwiftLink** hardware mode.

## Wire-protocol notes

See [`../SPEC.md`](../SPEC.md) — PETSCII strings on wire, `ATDT` with no
space before host, `\n` terminators, DTR-drop hangup, timeout counters.

## Alternative for BASIC readers

If you prefer a disk with BASIC demos and Bo's SwiftDriver, use
[`../c64u-kernal/`](../c64u-kernal/) and `kernal.d64` instead.
