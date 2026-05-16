# C64 Ultimate — KERNAL / SwiftDriver programs

If the **direct SwiftLink** programs in the repo root (`http-get.bas`, `wotd.bas`, `word-search.bas`) **freeze** while waiting on `PEEK(SR)` / `(S AND 8)=0`, try these versions instead.

They use **Bo Zimmerman’s SwiftDriver** loaded at `$C000`, then normal **KERNAL** `OPEN` / `PRINT#` / `GET#` — the same approach described in the Ultimate’s internal modem docs and community examples such as [v8id-mmo/swiftlink-basic](https://github.com/v8id-mmo/swiftlink-basic).

## What’s in this folder

| File | Purpose |
|------|---------|
| `swiftdrvr49152.prg` | SwiftDriver binary (same file as [`../swiftdriver/swiftdrvr49152.prg`](../swiftdriver/swiftdrvr49152.prg)) |
| `http-get.bas` | Fetch and display a web page over HTTP (same as root `http-get-kernal.bas`) |
| `wotd.bas` | Word of the Day from the Python BBS (`bbs.py` on port 6464) |
| `word-search.bas` | Compute! word-search demo (HTTP + on-screen game) |

**Source code, assembly, and license** for the driver live in **[`../swiftdriver/`](../swiftdriver/)** (`swiftdrvr.asm`, `LICENSE`, `PROVENANCE.md`). Copy `swiftdrvr49152.prg` onto your C64 disk together with whichever `.bas` you run.

## C64 Ultimate menu settings

Before running, enable the emulated modem (factory defaults usually work):

1. Ultimate menu → **ACIA (6551) mapping** → **`DE00/NMI`**
2. **Hardware mode** → **SwiftLink**
3. Ensure nothing else is mapped to `$DE00` (I/O conflict = garbage or hangs)

If the modem still misbehaves after errors, try a **full power cycle** (not just reset).

## How to run on a real C64 / Ultimate

1. Copy **`swiftdrvr49152.prg`** plus the program you want onto your C64 drive (disk image or SD/USB).
2. Load the driver **once per power-on** (each program below does this automatically if needed):
   - `LOAD "SWIFTDRVR49152",8,1` — change `8` to your device number.
   - `SYS 49152`
3. Run the program, e.g. `LOAD "WORD-SEARCH",8` then `RUN`.

Programs open the serial port at **600 baud** (`CHR$(7)`), which is slower but much more reliable in BASIC on the C64U than direct `POKE` at 38400.

## Baud rate codes (`CHR$()` for `OPEN`)

The fourth `OPEN` parameter selects the line speed. Pass `CHR$(n)` where `n` is from the table below:

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

Turbo232 speeds (38400 / 57600 / 115200) **not supported** by this driver. Example — open at 9600 baud:

```basic
OPEN 5,2,0,CHR$(14)
```

## Studying or changing the driver

See **[`../swiftdriver/`](../swiftdriver/)**:

- `swiftdrvr.asm` — 6502 source  
- `swiftdrvr.LADS.prg` — LADS project  
- `README` — baud rates, `SYS 49152`, example BASIC  
- `PROVENANCE.md` — where this copy came from  

Rebuild or relocate the driver with your own toolchain; respect the **Apache 2.0** terms in `../swiftdriver/LICENSE`.

## Tokenizing for C64 Ultimate HTTP runner

From the repo root (with `petcat` and `.env` set up — see main [`README.md`](../README.md)):

```bash
./rbas.sh c64u-kernal/word-search.bas
./rbas.sh c64u-kernal/http-get.bas
./rbas.sh c64u-kernal/wotd.bas
```

## Credits

| Component | Author / source | License |
|-----------|-----------------|---------|
| **SwiftDriver** | Bo Zimmerman (2016), [Swiftdriver.zip](https://www.zimmers.net/anonftp/pub/cbm/c64/comm/Swiftdriver.zip) | Apache 2.0 — [`../swiftdriver/LICENSE`](../swiftdriver/LICENSE) |
| **BASIC in this folder** | Chris G (adapted from direct-ACIA versions in parent repo) | Same as parent repo [`LICENSE`](../LICENSE) |
| **C64U usage notes** | Informed by [v8id-mmo/swiftlink-basic](https://github.com/v8id-mmo/swiftlink-basic) | — |

## Which version should I use?

| Situation | Try |
|-----------|-----|
| Real SwiftLink cartridge, VICE with direct ACIA, older C64U firmware | Root `*.bas` (direct `PEEK`/`POKE` at `$DE00`) |
| C64 Ultimate, new firmware, hangs on connect | **`c64u-kernal/*.bas`** + `swiftdrvr49152.prg` |
| Still stuck | Confirm menu settings, 600 baud, power cycle; report firmware version |
