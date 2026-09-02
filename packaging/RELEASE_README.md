# command64 OS

An MS-DOS style operating system for the Commodore 64.

## What's in this package

- **`image.d64`** — the command64 OS disk. Boot this. It carries the OS
  itself plus every shipped utility and game: `DEBUG`, `LABEL`, `FORMAT`,
  `COMP`, `CASM`, `EDLIN`, `DASH`, `CONWAY`, and `PACMAN` — plus `BANNER.S`,
  a small CASM source file to assemble yourself (BANNER is CASM-native and
  ships as source only, by design — see "Things to try" below).
- **`command64_casm_utils.d64`** — development utility disk containing the
  native CASM assembler source code files for the `DASH` dashboard (`dmain.s`,
  `dscr.s`, `dfmt.s`, `dsys.s`, `dapp.s`, `dvmm.s`, and `ddata.s`), `BANNER`'s
  own source (`banner.s`) alongside its compiled `banner.prg`, and the
  `casm.prg`, `edlin.prg`, and `comp.prg` utilities, plus `dash.ref` — the
  reviewed DASH reference binary — so you can `CASM DMAIN.S /O:DASH.PRG`
  and then `COMP DASH.PRG DASH.REF` to check your own assembly against it.
- **`docs/`** — reference documentation. Start with `docs/user-manual.md`;
  see `docs/casm-utility.md` for the full CASM language reference (syntax,
  directives, expressions, limits), `docs/dash-utility.md`,
  `docs/banner-utility.md`, and `docs/edlin-utility.md` for utility guides,
  and `docs/api-reference.md` / `docs/pet-sci-api.md` for the OS
  system-call interface external programs use.

## Requirements

- A Commodore 64 (or the VICE emulator).
- A RAM Expansion Unit (REU), 512KB or larger recommended. command64 uses
  it for virtual memory, environment storage, and several utilities'
  working buffers.
- A 1541/1571/1581/SD2IEC-compatible disk drive (device 8 by default).

## Booting

1. Insert/mount `image.d64` on device 8.
2. `LOAD "COMMAND64",8`
3. `RUN`

You'll see the command64 banner and the `C64:>` prompt.

## Things to try

- `DIR` — list what's on the disk.
- `HELP` — list the built-in shell commands.
- `CASM BANNER.S` then `BANNER HELLO` — the disk ships `BANNER.S` as
  source only; assemble it yourself with `CASM`, on the C64 itself, then
  run the PRG it produces. This is the fastest way to see the assembler
  and the shell's LOAD/RUN path work together.
- `EDLIN <filename>` — write or edit 6502 source (or any text file) with
  the ported MS-DOS line editor.
- `LOAD DASH` then `RUN` — a three-page system dashboard (System info,
  live Applications registry, VMM/REU hardware self-test), itself
  assembled entirely by native CASM. `F1`/`F3`/`F5` switch pages.
- `CONWAY` — a toroidal Game-of-Life with nine presets and custom rules.
- `PACMAN` — an in-progress character-grid Pac-Man clone.
- `DEBUG` — a machine-language monitor and memory editor with MS-DOS
  `DEBUG`-style commands.
- `FORMAT 8:MYDISK,01` — low-level-format a disk (destructive; asks for
  confirmation twice).
- `LABEL`, `COMP` — set a disk's volume label; compare two files byte for
  byte.

Every command above is covered in detail in `docs/user-manual.md`, along
with the full internal shell command reference, environment variables,
multi-device navigation, and troubleshooting.
