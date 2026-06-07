# C64 Ultimate — KERNAL / SwiftDriver programs

If the **direct SwiftLink** programs in the repo root (`http-get.bas`, `wotd.bas`, `word-search.bas`) **freeze** while waiting on `PEEK(SR)` / `(S AND 8)=0`, use these versions instead.

They use **Bo Zimmerman’s SwiftDriver** (`LOAD "swiftdrvr",8,1` then `SYS 49152`), then normal **KERNAL** `OPEN` / `PRINT#` / `GET#`. Same approach as the Ultimate’s internal modem docs and [v8id-mmo/swiftlink-basic](https://github.com/v8id-mmo/swiftlink-basic).

**Verified on C64 Ultimate (2026):** `SIMPLE`, `SIMPLE-WOTD`, `HTTP-GET`, and `WORD-SEARCH` all work. Word-search is slower (HTTP download + game) but completes successfully.

## Quick start (readers / Compute! disk)

1. Ultimate menu → **ACIA `DE00/NMI`**, **Hardware mode SwiftLink**.
2. Build or copy **`kernal.d64`** (see [`build-disk.sh`](build-disk.sh) or [`../DISK_CREATION.md`](../DISK_CREATION.md)).
3. On the C64: `LOAD"SIMPLE",8` then `RUN` — confirms driver + HTTP work.
4. Then try `HTTP-GET`, `SIMPLE-WOTD`, `WORD-SEARCH`.

Disable **JiffyDOS** if KERNAL programs misbehave (vector hook conflicts).

## Programs on `kernal.d64`

| Disk name | Source | Purpose | Status |
|-----------|--------|---------|--------|
| `SWIFTDRVR` | `swiftdrvr.prg` | Bo Zimmerman’s driver at `$C000` | Required |
| `SIMPLE` | `simple.bas` | Minimal HTTP GET smoke test | **Works** |
| `SIMPLE-WOTD` | `simple-wotd.bas` | Raw TCP to BBS (`bbs.py` :6464) | **Works** |
| `HTTP-GET` | `http-get.bas` | Fetch page + HTML tag formatting | **Works** |
| `WORD-SEARCH` | `word-search.bas` | HTTP word-search game | **Works** (slower) |
| `WOTD` | `wotd.bas` | Word-of-the-day guessing game via BBS | Untested recently |
| `HTTPGETC` | `httpgetc.prg` | Pure-C HTTP client (no driver file) | See `httpget-c/` |
| `SIMPLE-C` | `simple-c.bas` | BASIC wrapper experiments | Dev |
| `SWIFTC` | `swiftc.prg` | C-port driver (`swiftdriver-c/`) | Dev / `diag.bas` |
| `DIAG` | `diag.bas` | Debug SwiftC KERNAL hooks | Dev |
| `RESET` | `reset.bas` | Utility | Dev |
| `HTTP2` | `http2.bas` | Alternate HTTP experiment | Dev |

**Start with `SIMPLE`.** It is the smallest program that proves the stack (driver load, dial, HTTP, receive loop).

## How the programs work

Typical flow (see `simple.bas` / `http-get.bas`):

1. `LOAD "swiftdrvr",8,1` once per session (variable `A` or `LD` prevents reload loop after `LOAD` restarts the program).
2. Optional direct ACIA poke (`POKE 56833,0` etc.) before `SYS 49152`.
3. `SYS 49152` — **never call `SYS` inside a `GOSUB`** (clears return stack → `RETURN WITHOUT GOSUB`).
4. `OPEN 5,2,0,CHR$(n)` — see baud table below.
5. Drain RX buffer, `+++` / `ATH` hangup for clean state.
6. `PRINT#5,"ATDT host:port"+CHR$(13)` — no space after `ATDT` on C64U.
7. `GET#5` receive loop (or HTML parsing in `HTTP-GET` / `WORD-SEARCH`).

**Baud in current sources:**

| Program | `OPEN` speed | Notes |
|---------|--------------|-------|
| `simple.bas` | `CHR$(7)` = 600 | Safest; good first test |
| `http-get.bas`, `word-search.bas` | `CHR$(8)` = 1200 | Faster; still reliable here |

To go faster, try `CHR$(14)` (9600) on `SIMPLE` first before changing the larger programs.

## Baud rate codes (`CHR$()` for `OPEN`)

| Baud  | `CHR$()` code |
|------:|:-------------:|
|    50 |  1 |
|    75 |  2 |
|   110 |  3 |
|   135 |  4 |
|   150 |  5 |
|   300 |  6 |
|   600 |  7 |
|  1200 |  8 |
|  1800 |  9 |
|  2400 | 10 |
|  3600 | 11 |
|  4800 | 12 |
|  7200 | 13 |
|  9600 | 14 |
| 19200 | 15 |

Turbo232 speeds (38400+) are **not** supported by SwiftDriver.

## Build the disk

```bash
cd c64u-kernal
./build-disk.sh
```

Requires **petcat** and **c1541** (VICE). Tokenizes all `.bas` files, writes `kernal.d64`, optionally FTPs to the Ultimate (edit host/path in the script).

## Remote hosts used by the demos

| Program | Target |
|---------|--------|
| `SIMPLE`, `HTTP-GET`, `WORD-SEARCH` | `php.retrogamecoders.com:80` |
| `SIMPLE-WOTD`, `WOTD` | `bbs.retrogamecoders.com:6464` (run [`../bbs.py`](../bbs.py) on the server) |

## Pure C alternative (no driver on disk)

[`../httpget-c/`](../httpget-c/) — single `.prg`, direct ACIA + NMI ring buffer. Deploy with `make run` via [`../runner.py`](../runner.py). See [`../SPEC.md`](../SPEC.md) for architecture and wire-protocol notes.

## Driver source and license

Full upstream tree: **[`../swiftdriver/`](../swiftdriver/)** (`swiftdrvr.asm`, Apache 2.0). On disk the binary is **`SWIFTDRVR`** (8-character name; do not use `swiftdrvr49152` as the C64 filename).

## Tokenize one program for Ultimate HTTP runner

From repo root (`.env` with `C64U_PASSWORD`, `petcat` on PATH):

```bash
./rbas.sh c64u-kernal/simple.bas
./rbas.sh c64u-kernal/http-get.bas
```

## Which version should I use?

| Situation | Try |
|-----------|-----|
| C64 Ultimate, new firmware, hangs on connect | **`c64u-kernal/`** + `kernal.d64`, start with **`SIMPLE`** |
| Single PRG, no driver file | **`httpget-c/`** (`make run`) |
| Real SwiftLink cartridge, VICE, older C64U | Root `*.bas` (direct `PEEK`/`POKE` at `$DE00`) |
| Still stuck | Menu settings, JiffyDOS off, power cycle, try 600 baud |

## Credits

| Component | Source | License |
|-----------|--------|---------|
| **SwiftDriver** | Bo Zimmerman, [Swiftdriver.zip](https://www.zimmers.net/anonftp/pub/cbm/c64/comm/Swiftdriver.zip) | Apache 2.0 |
| **BASIC in this folder** | Chris G | Repo [`LICENSE`](../LICENSE) |
| **C64U notes** | Informed by [v8id-mmo/swiftlink-basic](https://github.com/v8id-mmo/swiftlink-basic) | — |
