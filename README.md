c64-ultimate
============

This repo is my playground for programming against the C64 (and Ultimate/SwiftLink-style setups) from modern tools. It’s a mix of C64 BASIC, 6502 assembly, and some helper Python to glue everything together.

What’s here
-----------

- **Python BBS server (`bbs.py`)**  

  This is based on an [original project started by @jalbarracinv](https://github.com/jalbarracinv/python-cbm-petscii-bbs)

  A very simple PETSCII BBS-style server that a C64 can call over TCP (typically via a SwiftLink-style modem setup or TCP-to-serial bridge).  
  - Talks PETSCII using the helpers in `funct.py`  
  - Shows a welcome screen from `seq/welcome.seq` / `seq/colaburger.seq`  
  - Has a basic per-connection session loop and user count tracking  
  - Integrates a “Word of the Day” banner via `wotd.py`

- **Word of the Day fetcher (`wotd.py`)**  
  Small helper that fetches Merriam‑Webster’s Word of the Day over HTTP (RSS), strips it down to a word + short definition, and feeds that into the BBS. This is where the BBS gets the `#WORD#DEFINITION#` header line.

- **PETSCII / terminal helpers (`funct.py`)**  
  Utility functions shared by the Python side:  
  - `cbmencode` / `cbmdecode` to translate between ASCII and PETSCII  
  - `send_line`, `send_control_code`, `send_seq` to push text, control codes, and SEQ “graphics” to the C64  
  - `get_char`, `input_line`, `input_pass` to read keys/lines/passwords from the remote C64 in a way that feels like BASIC’s `GET` and `INPUT`

- **BASIC programs**  
  - `swiftlink.bas`: C64 BASIC code that talks to the Python server over a SwiftLink-style interface / TCP bridge.  
  - `wotd.bas`: C64-side program for showing the Word of the Day coming from the Python side.  
  - `modem.bas`, `wotd.bas`, etc. are experiments around dialing/connecting and displaying remote content.

- **C64 Ultimate PRG runner (`runner.py`, `rbas.sh`, `word-search.bas`)**  
  - `runner.py`: small helper that HTTP‑posts a `.prg` to a C64 Ultimate (or compatible) using its `/v1/runners:run_prg` endpoint.  
  - `rbas.sh`: shell script that tokenizes a C64 BASIC v2 listing with `petcat` and then invokes `runner.py`.  
  - `word-search.bas`: example C64 BASIC v2 program that talks to a remote HTTP server using a SwiftLink‑style interface.

- **C / assembly multiplexing demo (`multiplex.c-c64/`)**  
  A separate little project showing sprite multiplexing on the C64 in C and 6502 assembly. This is mostly independent of the BBS work, but lives here as part of the broader “C64 experiments” theme.

Running the Python BBS
----------------------

Requirements:

- Python 3.10+ (what I’ve been testing with)
- `requests` for `wotd.py`:

```bash
pip install requests
```

To start the BBS server:

```bash
python3 bbs.py
```

By default it:

- Listens on TCP port `6464` on all interfaces  
- Logs new connections and a running user count  
- Speaks PETSCII only (this is meant to be driven by a C64 client, not a plain telnet terminal)

On the C64 side, I currently talk to it using a SwiftLink-style setup and `swiftlink.bas`, often via a TCPSerial bridge on the host. Exact wiring/details depend on your hardware and emulator, so you’ll likely need to adjust those for your setup.

Notes / caveats
---------------

- The BBS and helpers are intentionally minimal and experimental, not a full-featured BBS package.  
- The PETSCII mapping in `funct.py` is just enough for what I’m doing; some Unicode or punctuation from Merriam‑Webster may not display perfectly and might need further mapping/stripping.  
- The MySQL account system code in `bbs.py` is mostly stubbed out right now; I hard-code a test user for iteration and keep the DB bits commented until I want real persistence.

Running a BASIC program on a C64 Ultimate
-----------------------------------------

This flow uses `petcat` to tokenize a BASIC v2 listing and `runner.py` to send the resulting PRG to a C64 Ultimate over HTTP.

Requirements:

- `petcat` from VICE available on your `PATH` (used by `rbas.sh`)  
- Python 3.10+  
- `requests` and `python-dotenv`:

```bash
pip install requests python-dotenv
```

- A `.env` file in this repo with:

```bash
C64U_PASSWORD=your_ultimate_http_password_here
```

Usage (for `word-search.bas`):

```bash
./rbas.sh
```

You can also pass a different BASIC file:

```bash
./rbas.sh my-program.bas
```

What `rbas.sh` does:

- Takes the BASIC filename from `$1` (or defaults to `word-search.bas` if no argument is given).  
- Pipes that BASIC file through `tr` to lowercase it (VICE `petcat` expects lowercase BASIC keywords when tokenizing).  
- Calls `petcat -w2 -c` to tokenize as **C64 BASIC v2**, interpreting control‑code mnemonics like `{clr}`, `{rvon}`, `{rvof}`.  
- Writes `prg.prg`, then runs:

```bash
python3 runner.py prg.prg
```

`runner.py` reads the PRG and POSTs it as `application/octet-stream` to the C64 Ultimate at `http://192.168.0.64/v1/runners:run_prg` with the password from `C64U_PASSWORD`.

Notes:

- The BASIC source can be authored in uppercase (as you’d normally type it on a C64); `rbas.sh` lowercases it only for `petcat`.  
- Control codes in the BASIC source should use mnemonics that `petcat` understands, e.g. `{CLR}`, `{RVON}`, `{RVOF}`.

License
-------

See `LICENSE` for project licensing details.
