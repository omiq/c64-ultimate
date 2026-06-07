# Creating kernal.d64

The **`c64u-kernal/build-disk.sh`** script is the maintained way to build the Compute! / reader disk. It tokenizes `.bas` sources with `petcat`, packs PRGs + `swiftdrvr.prg` into `kernal.d64`, and can FTP the image to a C64 Ultimate.

```bash
cd c64u-kernal
./build-disk.sh
```

Requires **petcat** and **c1541** (both ship with VICE).

## Why tokenize first?

`.bas` files in this repo are plain ASCII listings, not tokenized BASIC. Writing them raw to a D64 as PRG makes `LOAD` interpret ASCII as machine code and hang the C64. `petcat` produces a real PRG (`$0801` load address + tokens) that `LOAD` and `RUN` accept.

## Files on `kernal.d64`

| Host file (after build) | Disk name | Role |
|-------------------------|-----------|------|
| `swiftdrvr.prg` | `swiftdrvr` | SwiftDriver (required) |
| `simple.prg` | `simple` | HTTP smoke test — **run this first** |
| `simple-wotd.prg` | `simple-wotd` | BBS / raw TCP test |
| `http-get.prg` | `http-get` | Full HTTP + HTML display |
| `word-search.prg` | `word-search` | Word-search game |
| `wotd.prg` | `wotd` | Word-of-the-day game |
| `httpgetc.prg` | `httpgetc` | Pure-C client (built separately) |
| `swiftc.prg` | `swiftc` | C driver port (dev) |
| `simple-c.prg` | `simple-c` | Dev |
| `diag.prg` | `diag` | Dev |
| `http2.prg` | `http2` | Dev |
| `reset.prg` | `reset` | Dev |

`README.md` is not written to the disk.

## Manual equivalent (if you prefer by hand)

```bash
cd c64u-kernal

for f in http-get word-search wotd simple simple-wotd; do
  tr 'A-Z' 'a-z' < "$f.bas" | petcat -w2 -o "$f.prg" --
done

c1541 -format "kernal,01" d64 kernal.d64 \
      -write simple.prg         simple \
      -write simple-wotd.prg     simple-wotd \
      -write http-get.prg       http-get \
      -write swiftdrvr.prg       swiftdrvr \
      -write word-search.prg    word-search \
      -write wotd.prg           wotd
```

## Verify

```bash
c1541 -attach kernal.d64 -dir
```

## Reader instructions (short)

1. Copy `kernal.d64` to the C64 Ultimate SD/USB (or use FTP from `build-disk.sh`).
2. Menu: **ACIA `DE00/NMI`**, **SwiftLink** hardware mode.
3. `LOAD"SIMPLE",8` : `RUN` — you should see HTTP response text from the web.
4. `LOAD"HTTP-GET",8` : `RUN` for formatted page output.
5. `LOAD"WORD-SEARCH",8` : `RUN` for the game (slower; be patient).

See [`c64u-kernal/README.md`](c64u-kernal/README.md) for full detail.
