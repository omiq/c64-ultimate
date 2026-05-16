# C64 Ultimate — KERNAL / SwiftDriver programs

If the **direct SwiftLink** programs in the repo root (`http-get.bas`, `wotd.bas`, `word-search.bas`) **freeze** while waiting on `PEEK(SR)` / `(S AND 8)=0`, try these versions instead.

They use **Bo Zimmerman’s SwiftDriver** (`swiftdrvr49152.prg`, GPLv3) loaded at `$C000`, then normal **KERNAL** `OPEN` / `PRINT#` / `GET#` — the same approach as [v8id-mmo/swiftlink-basic](https://github.com/v8id-mmo/swiftlink-basic) and the Ultimate’s internal modem docs.

## What’s in this folder

| File | Purpose |
|------|---------|
| `swiftdrvr49152.prg` | SwiftDriver (load at $C000, activate with `SYS 49152`) |
| `SWIFTDRIVER-LICENSE.txt` | GPLv3 license for the driver |
| `http-get.bas` | Fetch and display a web page over HTTP |
| `wotd.bas` | Word of the Day from the Python BBS (`bbs.py` on port 6464) |
| `word-search.bas` | Compute! word-search demo (HTTP + on-screen game) |

## C64 Ultimate menu settings

Before running, enable the emulated modem (factory defaults usually work):

1. Ultimate menu → **ACIA (6551) mapping** → **`DE00/NMI`**
2. **Hardware mode** → **SwiftLink**
3. Ensure nothing else is mapped to `$DE00` (I/O conflict = garbage or hangs)

If the modem still misbehaves after errors, try a **full power cycle** (not just reset) — see the swiftlink-basic notes.

## How to run on a real C64 / Ultimate

1. Copy this whole folder to your C64 drive (disk image or SD/USB).
2. Load the driver **once per power-on** (first line of each program does this if needed):
   - `LOAD "SWIFTDRVR49152",8,1` — change `8` to your device number.
   - `SYS 49152`
3. Run the program you want, e.g. `LOAD "HTTP-GET",8` then `RUN`.

Programs open the serial port at **600 baud** (`CHR$(7)`), which is slower but much more reliable in BASIC on the C64U than direct `POKE` at 38400.

## Tokenizing for C64 Ultimate HTTP runner

From the repo root (with `petcat` and `.env` set up — see main `README.md`):

```bash
./rbas.sh c64u-kernal/word-search.bas
./rbas.sh c64u-kernal/http-get.bas
./rbas.sh c64u-kernal/wotd.bas
```

## Credits

- **SwiftDriver** — Bo Zimmerman (2016), GPLv3. Original: [Swiftdriver.zip](https://www.zimmers.net/anonftp/pub/cbm/c64/comm/Swiftdriver.zip)
- **C64U example / packaging** — [v8id-mmo/swiftlink-basic](https://github.com/v8id-mmo/swiftlink-basic)
- **BASIC programs in this folder** — Chris G (adapted from the direct-ACIA versions in the parent repo)

## Which version should I use?

| Situation | Try |
|-----------|-----|
| Real SwiftLink cartridge, VICE with direct ACIA, older C64U firmware | Root `*.bas` (direct `PEEK`/`POKE` at `$DE00`) |
| C64 Ultimate, new firmware, hangs on connect | **`c64u-kernal/*.bas`** + `swiftdrvr49152.prg` |
| Still stuck | Confirm menu settings, 600 baud, power cycle; report firmware version |
