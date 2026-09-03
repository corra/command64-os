# command64 OS FORMAT Utility Manual

**File Name:** `format.prg`
**Version:** `0.1.0.1013` (banner: `FORMAT v0.1.0.1013`)
**Target Address:** R6-relocatable, implicit origin `$3400`; loaded and
relocated to `UserProgStart` (currently `$3800`) by the shell's external-
command loader. Runs unchanged at any load base (verified `$3800` / `$5000`
/ `$9000`).
**Assembler:** native CASM only — no ca65 build (see *Artifact Provenance*
below).

## Overview

`FORMAT` low-level-formats a 1541 floppy by sending CBM DOS's native
`N:<name>,<id>` (NEW) command to the target drive's command channel via the
`DOS_SEND_COMMAND` OS API primitive. The drive firmware owns the actual
format logic — `FORMAT` only builds and validates the command string,
guards the destructive operation behind a two-step confirmation, sends it,
and reports the drive's real status-channel response.

Full behavioural spec: [wiki/tasks/format.md](tasks/format.md).

## Command Syntax

```text
FORMAT <dev>:<name>,<id>        e.g. FORMAT 8:MYDISK,01
```

* **`<dev>`** — target device, `8`–`11`. Optional; defaults to the current
  device.
* **`<name>`** — new disk name, 1–16 characters, no `,` or `:`. Trailing
  spaces are stripped; leading spaces are preserved.
* **`<id>`** — exactly 2 characters.

With no arguments, or an argument that has no comma, `FORMAT` prompts
interactively for device, name, and id in turn (each re-prompts on invalid
input). A CLI argument that has a comma but fails validation is a hard error
— CLI mode does not fall back to prompting.

## Destructive-action confirmation

1. `format drive <dev> - all data will be lost. continue? (y/n)` — abort on
   anything but `Y`.
2. `re-enter disk name to confirm:` — must match the name already supplied
   exactly, or the format is aborted with no drive I/O.

On success the drive's status channel is printed verbatim, e.g.
`result: 00, ok,00,00`.

## On-screen text

All prompts, errors, and the result line render **lowercase** (the version
banner keeps `FORMAT` as an uppercase glyph). The retired ca65 build
rendered everything uppercase; the CASM-native build's unshifted PETSCII
message bytes render lowercase on Command 64's mixed-case charset. This is
the only user-visible change from the previous build — the parsing,
validation, confirmation, and command bytes are unchanged. (The `N` in the
assembled `:N:` command is now the canonical `$4E` rather than the ca65
build's shifted `$CE`; the 1541 accepts either, so formatting behaviour is
identical.)

## Artifact Provenance

`FORMAT` is a **CASM-native application**: `src/external/format/format.s`
(constants inline, all-uppercase ASCII outside string literals) is assembled
only by the native CASM assembler running on the C64. There is no
ca65/ld65 build (retired in the 2026-09-02 migration —
`brain/plans/2026-09-02-format-casm-native-migration.md`).

* **Shipping artifact** — `src/external/format/format.ref.hex`, a
  human-reviewed hex manifest that `scripts/hex_manifest_to_bin.py`
  transcribes back into `format.prg` at build time. Regenerating it is a
  deliberate, reviewed act (`scripts/build_format_manifest.py`), never a
  build step.
* **Stale-source guard** — the manifest embeds a `source_sha256` line for
  each of `format.s`, `FORMAT_VERSION`, and `BUILD_FORMAT`; editing any of
  them without regenerating the manifest hard-fails the build.
* **Version banner** — `formatver.s` (the `FORMATVERMSG` data) is generated
  at build time by `scripts/gen_format_version.py` from `FORMAT_VERSION`
  (`0.1.0`, hand-bumped) and `BUILD_FORMAT`, matching `DEBUG`'s
  `DEBUG v0.5.0.1128` banner format.
* **Correctness oracle** — `src/external/format/format-derivation.md`: the
  code/data bytes are independently corroborated by a same-base (`$3400`)
  ca65 build of a messages-forced-to-explicit-hex transform of `format.s`
  (**all 1539 image bytes identical**), and the 159-entry R6 relocation
  table is independently verified (`scripts/casm_r6_verify.py`). Live
  proof: `COMP FMT.PRG FORMAT.REF` → `FILES COMPARE OK` on the C64, plus
  an end-to-end scratch-disk format.
* **Native reassembly** — the `command64_format_test_d64` CMake target
  builds a disk with `command64`, `casm`, `comp`, `format.s`,
  `formatver.s`, and the reviewed `format.ref`:
  `CASM FORMAT.S /O:FORMAT.PRG` then `COMP FORMAT.PRG FORMAT.REF`. Native
  CASM assembly needs a REU; the resulting `FORMAT` runtime does not.
