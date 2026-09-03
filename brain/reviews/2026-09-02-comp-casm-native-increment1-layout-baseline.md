# COMP CASM-Native Increment 1 - Layout and Baseline Freeze

Date: 2026-09-02
Plan: `brain/plans/2026-09-02-comp-casm-native-migration.md`
Taskwarrior: `74845ecf-9e39-4253-8e78-6dfb4104d635` (task 42, project `comp`)
Status: completion candidate; exact native layout awaiting user approval

## Baseline Identity

- Repository commit: `39b0ef5ce15de11476d42721f1f60151f6a88c0a`.
- Build command: `cmake --build build --target comp`.
- Result: target built successfully.
- Artifact: `build/comp.prg`, 1,020 bytes.
- SHA-256:
  `e4de95c814b2bf7bff6c0346f9d1b8e178b4b62db651bba71856f63c5c5c8bf8`.
- Source inputs: `comp.s`, `common.inc`, shared `include/ca65` files, generated
  `build_comp.inc`, and `BUILD_COMP` (`1006` at survey time).

This is the frozen pre-migration differential artifact. It is supporting
evidence only and will not supply canonical expected bytes.

## Current ca65/ld65 Layout

The generated linker contract places `CODE`, `RODATA`, and `DATA` in the file,
then allocates `BSS` in the same `MAIN` memory area without writing it.

| Region | Start | End | Bytes | Present in PRG |
| --- | ---: | ---: | ---: | --- |
| Code + messages | `$3800` | `$3B79` | 890 (`$037A`) | yes |
| `File1Buf` | `$3B7A` | `$3BA1` | 40 | no, BSS |
| `File2Buf` | `$3BA2` | `$3BC9` | 40 | no, BSS |
| `Buf1` | `$3BCA` | `$3C09` | 64 | no, BSS |
| `Buf2` | `$3C0A` | `$3C49` | 64 | no, BSS |
| Runtime allocation total | `$3800` | `$3C49` | 1,098 (`$044A`) | mixed |

The R6 artifact consists of the two-byte `$3800` load header, 890-byte program
image, 122-byte relocation table, and six-byte footer: 1,020 bytes total.

## Frozen ca65 Relocation Baseline

Footer: base `$3800`, count 61, magic `R6`.

Sorted relocation offsets:

```text
0016 001B 001E 0021 0026 0029 002C 002F 0032 0046 0049 0058 005D 0062 0071 0076
007B 00B3 00D5 00E5 00E9 00F1 00F5 00FD 0101 010A 0118 0122 012E 0138 0165 016E
0173 0176 017B 017E 0181 0193 019B 01A8 01BA 01BD 01C8 01CB 0203 0206 020D 0214
021D 0221 0231 023B 0240 0245 0249 0253 0257 0261 0276 028C 029A
```

`scripts/casm_r6_verify.py build/comp.prg` reports the structural header,
ordering, uniqueness, and offset range correctly, then rejects offsets `$01C8`,
`$0206`, and `$020D` because their high bytes are `$3C`, beyond the emitted
image's final page `$3B`. These are references to the valid runtime BSS
addresses in `Buf1`/`Buf2`; they demonstrate why the ca65 artifact is not a
self-contained native-application oracle.

## Proposed Native CASM Layout

CASM's implicit base is `$3400`. The conversion preserves the 890-byte
code/message extent and appends all 208 storage bytes in source order.

| Region | Start | End | Bytes | Emission |
| --- | ---: | ---: | ---: | --- |
| Code + messages | `$3400` | `$3779` | 890 (`$037A`) | existing bytes, rebased |
| `File1Buf` | `$377A` | `$37A1` | 40 | `.RES 40, 0` |
| `File2Buf` | `$37A2` | `$37C9` | 40 | `.RES 40, 0` |
| `Buf1` | `$37CA` | `$3809` | 64 | `.RES 64, 0` |
| `Buf2` | `$380A` | `$3849` | 64 | `.RES 64, 0` |
| Native program image | `$3400` | `$3849` | 1,098 (`$044A`) | all emitted |

Predicted unchanged relocation count: 61. The exact CASM relocation ledger
must still be independently derived and reviewed in Increment 3; this
prediction is not the oracle.

If all 61 offsets remain unchanged, the native artifact will contain:

- two-byte `$3400` load header;
- 1,098-byte program image;
- 122-byte relocation table;
- six-byte footer;
- 1,228 bytes total (`$04CC`), ending on disk after the footer rather than at a
  runtime memory address.

At runtime the loader may relocate the image to `$3800`; the emitted image then
occupies `$3800-$3C49`, exactly matching the old ca65 runtime allocation. Thus
the chosen storage disposition changes file size but not COMP's runtime memory
ceiling.

## Source Conversion Boundary

- Inline all constants from `common.inc` at the top of `comp.s`, then delete the
  include. This avoids the known included-zero-page constant defect.
- Remove the shared ca65 include by independently defining only the OS/KERNAL
  constants COMP actually consumes.
- Remove unused `VERSION_*`, `build_comp.inc`, linker import, segments, and
  manual header.
- Preserve the 16-byte external-app zero-page allocation `$70-$7F` exactly.
- Preserve every message byte and runtime branch unless a separately approved
  mismatch investigation requires otherwise.

## Frozen Functional Matrix

The dedicated migration disk will carry deterministic fixture pairs for:

1. identical files;
2. one mismatch at a known offset;
3. more than ten mismatches;
4. file 1 longer;
5. file 2 longer;
6. missing first file;
7. missing second file;
8. missing and extra arguments;
9. rejected slash option;
10. PRG files whose load-address bytes differ;
11. one established CASM source/reference pair;
12. the known cross-device equal-file failure, characterization only.

Expected text and same-device semantics remain those in
`wiki/tasks/comp-command.md`. The cross-device result remains governed by
`wiki/tasks/comp-cross-device-regression.md` and is not fixed here.

## Increment 1 Gate

Approve the exact native layout `$3400-$3849`, including emitted storage at
`$377A-$3849`, before Increment 2 changes `comp.s`, deletes `common.inc`, or
changes CMake.
