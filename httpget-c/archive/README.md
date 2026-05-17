# Archive — alternative SwiftDriver-blob approach

This folder holds an **unused** alternative path we explored before
the direct-ACIA approach in `../httpget.c` proved out.

## What's here

| File | Purpose |
|------|---------|
| `swift.h`           | Thin C wrapper API around Bo Zimmerman's compiled SwiftDriver |
| `swiftdrvr_blob.h`  | Bo's 292-byte `swiftdrvr.prg` payload as a C byte array (generated via `xxd -i`) |
| `swiftdrvr.bin`     | Raw 292 bytes of Bo's driver (PRG load-address header stripped) |

## Why not used

`httpget.c` ended up talking to the SwiftLink ACIA at `$DE00`
directly (with a small NMI handler in `nmi.s` for RX byte capture).
That works end-to-end on the C64 Ultimate's virtual modem, requires
no external driver file, and keeps the entire program in a single
self-contained `.prg`.

The blob-wrapper here would have:

1. `memcpy`'d the 292 bytes to `$C000`
2. Called `JSR $C000` (Bo's INIT) to install the KERNAL vector hooks
3. Used standard `cbm_open` / `cbm_read` / `cbm_write` which then route
   through Bo's wedge and out the ACIA

Both architectures are valid. We kept this one as a reference / fallback
in case the direct-ACIA approach ever stops working on future C64U
firmware revisions — at that point swapping to Bo's proven asm is one
include change away.

## Regenerating the blob

If `../swiftdrvr/swiftdrvr49152.prg` changes:

```sh
dd if=../../swiftdriver/swiftdrvr49152.prg of=swiftdrvr.bin bs=1 skip=2
xxd -i swiftdrvr.bin > swiftdrvr_blob.h
```
