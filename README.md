c64-ultimate
============

Programming the C64 and C64 Ultimate from modern tools: BASIC, cc65 C, Python servers, and SwiftLink-style TCP/HTTP over the Ultimate’s emulated modem.

## What works today (C64 Ultimate)

| Approach | Where | Verified |
|----------|-------|----------|
| **BASIC + SwiftDriver** | `c64u-kernal/` on `kernal.d64` | `SIMPLE`, `SIMPLE-WOTD`, `HTTP-GET`, `WORD-SEARCH` |
| **Pure C (no driver file)** | `httpget-c/` | `httpget.c`, `wotd.c` via `make run` |
| **Direct ACIA BASIC** | Root `http-get.bas`, `word-search.bas` | Real SwiftLink / VICE / some older C64U setups only |

New C64 Ultimate firmware often **hangs** on root programs that poll `$DE00` directly (`PEEK(SR)` bit 3). Use **`c64u-kernal/`** or **`httpget-c/`** instead.

## Quick start — C64 Ultimate readers

1. Menu → **ACIA mapping `DE00/NMI`**, **Hardware mode SwiftLink**.
2. Build the disk: `cd c64u-kernal && ./build-disk.sh`
3. On the C64: `LOAD"SIMPLE",8` then `RUN` (HTTP smoke test).
4. Then `HTTP-GET`, `SIMPLE-WOTD`, `WORD-SEARCH`.

Full instructions: [`c64u-kernal/README.md`](c64u-kernal/README.md), [`DISK_CREATION.md`](DISK_CREATION.md).

## What’s in the repo

### `c64u-kernal/` — KERNAL programs for C64 Ultimate

BASIC programs that `LOAD "swiftdrvr"` and use `OPEN` / `PRINT#` / `GET#` through Bo Zimmerman’s SwiftDriver. **`build-disk.sh`** produces **`kernal.d64`** for Compute! / community distribution.

- **`simple.bas`** — minimal HTTP test (start here)
- **`simple-wotd.bas`** — raw TCP to the Python BBS
- **`http-get.bas`** — fetch and format a web page
- **`word-search.bas`** — Compute! word-search demo (works; slower at 1200 baud)
- **`swiftdrvr.prg`** — driver binary (disk name `SWIFTDRVR`)

### `httpget-c/` — single-PRG C HTTP/TCP clients

Direct 6551 ACIA access at `$DE00` with an NMI ring buffer (`nmi.s`). No separate driver file. Deploy to the Ultimate with:

```bash
cd httpget-c && make run
```

Uses [`runner.py`](runner.py) (HTTP POST to the Ultimate’s `run_prg` API). See [`SPEC.md`](SPEC.md) for wire-protocol gotchas and architecture.

### `swiftdriver/` — Bo Zimmerman’s SwiftDriver (full source)

Vendored from [Swiftdriver.zip](https://www.zimmers.net/anonftp/pub/cbm/c64/comm/Swiftdriver.zip): `swiftdrvr.asm`, LADS project, **Apache License 2.0**. See [`swiftdriver/PROVENANCE.md`](swiftdriver/PROVENANCE.md).

### Python BBS (`bbs.py`, `wotd.py`, `funct.py`)

PETSCII BBS server for C64 clients over TCP (port **6464**). Used by `SIMPLE-WOTD` and `wotd.bas`. Based on [jalbarracinv/python-cbm-petscii-bbs](https://github.com/jalbarracinv/python-cbm-petscii-bbs).

```bash
pip install requests
python3 bbs.py
```

### Root BASIC programs (direct ACIA)

`http-get.bas`, `word-search.bas`, `wotd.bas`, `swiftlink.bas` — **direct `PEEK`/`POKE`** at `$DE00`, often at 38400 baud. Fine on hardware SwiftLink or VICE; **not** the first choice on new C64 Ultimate firmware.

`http-get-kernal.bas` duplicates the KERNAL approach at repo root (canonical copies live in `c64u-kernal/`).

### Other

- **`httpget-tool/`** — planned BASIC-callable resident HTTP tool (REU storage); scaffold only
- **`swiftdriver-c/`** — educational C port of SwiftDriver
- **`multiplex.c-c64/`** — sprite multiplexing demo (separate from HTTP work)
- **`runner.py`**, **`rbas.sh`** — tokenize BASIC with `petcat`, POST PRG to C64 Ultimate

## C64 Ultimate: programs freeze while connecting?

Symptoms: “connecting…” then hang, or host-side timeout with no data.

1. Confirm menu: **ACIA `DE00/NMI`**, **SwiftLink** mode.
2. Use **`kernal.d64`** from `c64u-kernal/`, not root direct-ACIA programs.
3. Disable **JiffyDOS** for KERNAL/SwiftDriver programs.
4. Full **power cycle** after modem errors (reset alone may not clear the emulated modem).

## Deploy a single program to the Ultimate (no disk)

Requirements: `petcat` (VICE), `requests`, `python-dotenv`, `.env` with `C64U_PASSWORD`.

```bash
./rbas.sh c64u-kernal/simple.bas
```

Or for C:

```bash
cd httpget-c && make run
```

`runner.py` POSTs to `http://<your-ultimate>/v1/runners:run_prg`.

## Remote hosts (demos)

| Service | Host | Port |
|---------|------|------|
| HTTP demos | `php.retrogamecoders.com` | 80 |
| BBS / WOTD | `bbs.retrogamecoders.com` | 6464 |

## Project documentation

| Doc | Contents |
|-----|----------|
| [`SPEC.md`](SPEC.md) | Architecture, gotchas, roadmap |
| [`c64u-kernal/README.md`](c64u-kernal/README.md) | KERNAL programs, baud table, credits |
| [`DISK_CREATION.md`](DISK_CREATION.md) | Building `kernal.d64` |

## Licenses

- **This repo’s own code** (BASIC, Python, C except vendored driver) — [`LICENSE`](LICENSE)
- **SwiftDriver** (`swiftdriver/`) — **Apache License 2.0**, Bo Zimmerman — [`swiftdriver/LICENSE`](swiftdriver/LICENSE)
