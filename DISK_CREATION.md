# Creating kernal.d64

Files from `c64u-kernal/` packed into D64 disk image using `c1541` (VICE tool).

**Important:** `.bas` files in this repo are plain ASCII BASIC listings, not tokenized. They must be tokenized with `petcat` (also from VICE) before being written to disk as PRG, otherwise `LOAD` on the C64 will freeze.

## Commands

```bash
cd c64u-kernal

# 1. Tokenize each .bas → .prg (lowercase first; petcat expects lowercase keywords)
for f in http-get word-search wotd; do
  tr 'A-Z' 'a-z' < "$f.bas" | petcat -w2 -o "$f.prg" --
done

# 2. Format fresh D64 and write all PRGs
c1541 -format "kernal,01" d64 kernal.d64 \
      -write http-get.prg       http-get \
      -write swiftdrvr49152.prg swiftdrvr \
      -write word-search.prg    word-search \
      -write wotd.prg           wotd
```

## Explanation

- `tr 'A-Z' 'a-z'` — petcat expects lowercase BASIC keywords.
- `petcat -w2 -o out.prg --` — tokenize as BASIC v2 (C64), output PRG with load address `$0801`.
- `c1541 -format "name,id"` — make fresh empty D64 (disk name `kernal`, ID `01`).
- `c1541 -write <hostfile> <c64name>` — copy host file onto disk; second arg = filename on disk (16 char max).
- Default file type PRG.
- `README.md` deliberately excluded.

## Files included

| Host file              | Disk name    | Type |
|------------------------|--------------|------|
| http-get.prg           | http-get     | PRG  |
| swiftdrvr49152.prg     | swiftdrvr    | PRG  |
| word-search.prg        | word-search  | PRG  |
| wotd.prg               | wotd         | PRG  |

## Verify

```bash
c1541 -attach kernal.d64 -dir
```

## Why first attempt froze the C64U

Initial build wrote the `.bas` ASCII source files directly to the D64 as PRG. The C64 `LOAD` routine reads the first two bytes as a load address, then copies the rest into memory and (with `,8,1`) jumps to it — so ASCII text gets interpreted as machine code / a corrupt BASIC program, hanging the machine. Tokenizing first produces a real PRG (`$01 $08` load address + tokenized BASIC) that `LOAD` and `RUN` accept.
