# SwiftDriver — copy in this repository

This directory is a **verbatim copy** of Bo Zimmerman’s **SwiftDriver** release (August 2016), taken from the official archive so the source stays available even if upstream mirrors move.

## Upstream

| | |
|--|--|
| **Author** | Bo Zimmerman |
| **Archive** | [Swiftdriver.zip](https://www.zimmers.net/anonftp/pub/cbm/c64/comm/Swiftdriver.zip) |
| **Mirror** | [bozimmerman.com/.../Swiftdriver.zip](https://bozimmerman.com/anonftp/pub/cbm/c64/comm/Swiftdriver.zip) |
| **Vendored in this repo** | May 2026 |

## Files (educational use)

| File | Description |
|------|-------------|
| `swiftdrvr.asm` | 6502 assembly source for the KERNAL wedge |
| `swiftdrvr.LADS.prg` | LADS assembler project |
| `swiftdrvr49152.prg` | Built driver (load at `$C000`, run `SYS 49152`) |
| `Swiftdriver.cbmprj` | CBM Prg Studio project file |
| `README` | Author’s usage notes and baud-rate table |
| `LICENSE` | **Apache License 2.0** |
| `NOTICE` | Credits |
| `CHANGES`, `TODO` | Project notes from upstream |

## License

SwiftDriver is **not** part of the MIT (or other) license on the rest of `c64-ultimate` unless stated otherwise. It is licensed under the **Apache License 2.0** — see `LICENSE` and `NOTICE` in this folder.

Programs in `c64u-kernal/` that `LOAD` `swiftdrvr49152.prg` are separate works that **use** this driver; keep this folder (or equivalent source + license) when you redistribute the driver binary.

## Related in this repo

- [`c64u-kernal/`](../c64u-kernal/) — BASIC clients that use the driver on C64 Ultimate
- Root `*.bas` — direct `$DE00` ACIA access (no driver)
