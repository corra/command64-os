---
title: LABEL → CASM-native migration — completion-gate walkthrough
date: 2026-09-02
plan: brain/plans/2026-09-02-label-casm-native-migration.md
taskwarrior: 53e5934a-4617-4263-a870-de7e1cfeb592 (task 41, project label)
status: complete — user-approved 2026-09-02
---

# LABEL CASM-native Migration — Walkthrough

Live evidence for the Completion Gate of
`brain/plans/2026-09-02-label-casm-native-migration.md`. Nothing here is an
intention — every line is an observed result.

## What shipped

- `src/external/label/label.s` — self-contained native CASM source:
  constants inline (KERNAL/OS/PETSCII/protocol; `command64.inc` and
  `common.inc` dropped), `@local` routine-internal labels, native
  string/character literals for user-facing messages, `.RES` buffers,
  `VOL_NAME_LEN±1` / `STATUSBUFLEN-2` bounded-expression addends. Drive
  protocol strings (`CMDINIT`/`CMDU1`/`CMDBP`/`CMDU2`) kept as explicit
  reviewed hex.
- `src/external/label/LABEL_VERSION` (`0.4.0`) + `scripts/gen_label_version.py`
  → build-time `labelver.s` (`${CMAKE_BINARY_DIR}`, not checked in).
- `src/external/label/label.ref.hex` — reviewed shipping manifest;
  `scripts/build_label_manifest.py`.
- `src/external/label/label-derivation.md` — independent byte + R6
  derivation (oracle).
- `CMakeLists.txt` — `add_ca65_app(label …)` removed; manifest-derived
  `label` target + `labelver.s` generator + `command64_label_test_d64`
  added.
- `scripts/casm_oracle_inventory.py` — `label.ref.hex` added to
  `NATIVE_MANIFESTS`.
- Docs: `wiki/label-utility.md` (Artifact Provenance section; synced to
  `docs/`), `CHANGELOG.md`, `brain/KNOWLEDGE.md`, audit register row.

## Assembly + byte identity

Native CASM **0.6.2 build 1419** under VICE 3.10 (16 MB REU),
`CASM LABEL.S /O:LBL.PRG` from the SEQ sources on
`command64_label_test.d64`:

```
P1: DONE 00382 STATEMENTS
P2: DONE 00382 STATEMENTS
DONE: P1 00382, P2 00382, 00956 BYTES
CASM: INPUT VALIDATED
```

Reproduced byte-identically across three independent runs (pre-inline
constants → 1186 B and wrong; inlined constants → 956 B; DEBUG-format
banner → 956 B, final). Final `LBL.PRG` SHA-256
`d02469304f224788dad4c9c7ccb20f98f076a86fc6cec0007e88027a1cf174cf`.

**Independent reference:** ca65/ld65 build of the *pre-migration* `label.s`
linked at the same `$3400` base (`label_base3400.prg`, 846 B, SHA-256
`83161418…`). ca65 and CASM share no code.

**Host diff, program image `$3400..$374B` (844 bytes): 1 byte differs.**

| Offset | ca65 | CASM | Meaning |
| --- | --- | --- | --- |
| `$3706` | `$D6` | `$56` | banner `V` (shifted, uppercase glyph) → `v` (unshifted, lowercase) — the user-approved DEBUG-format change |

843/844 image bytes identical. ca65 symbol map reconciles every routine and
data address to the CASM layout — the migration is length-preserving.

## R6 relocation

`scripts/casm_r6_verify.py` on `LBL.PRG`:

```
footer: base $3400  count 52  magic 'R6'
program image 844 bytes  $3400..$374B
relocation table 104 bytes at file offset 846..949
offsets strictly ascending and unique   range $0003..$023D
all 52 entries point at an in-image high byte (pages $34..$37)
relocate to $3800 / $5000 / $9000: every high byte in range
R6 VERIFY: PASS
```

**Independent eligibility reconciliation:** 45 three-byte absolute operands
(every target matches the ca65 map) + 7 `#>label` high-byte immediates
= **52, exactly CASM's count**. Zero entries for fixed addresses
(`$1000` / `$FFxx` / `$039E` / `$033C`) or `#<label` low bytes.

## Live COMP

`command64_label_test.d64` on device 8, `CASM LABEL.S /O:LABEL.PRG` then:

```
comp label.prg label.ref
FILES COMPARE OK
```

Native CASM assembly of the shipping `label.s` == the manifest-derived
`label.ref`, on the C64. Overlay `test`/`pass` event fired.

## Functional sweep (dispatched by name → loaded `$3800` → R6-relocated)

| Invocation | Observed |
| --- | --- |
| any run | banner `LABEL v0.4.0.1047` (uppercase LABEL glyph, lowercase v) |
| `LABEL` | `label name required` |
| `LABEL ABCDEFGHIJKLMNOPQR` (18 ch) | `label too long (max 16)` |
| `LABEL 8:` → prompt → `MYVOL`⏎ | `VOLUME LABEL (16 CHARS MAX)? ` prompt, input echoed, `label updated` |
| write persistence | detached disk BAM name = `4D 59 56 4F 4C A0×11` — "MYVOL" padded to 16 with `$A0` |
| `LABEL 11:X` (device absent) | `drive error 05` (2-digit KERNAL code via `PRINTERRCODE`) |
| every run | clean return to `C64[8]:>` |

The U1 / B-P / U2 direct-access volume-name write is correct end to end.

## Build verification

- Fresh `rm -rf build && cmake -B build`: **no warnings or errors.**
- Full `cmake --build build`: **all targets build.** `build/label.prg`
  SHA-256 == the manifest. `image.d64` carries `LABEL` (position 3);
  `test_image_d64` builds.
- **No-change rebuild:** `label.prg`, `image.d64`,
  `command64_label_test.d64` byte-identical.
- **Stale-source gate:** appending a comment to `label.s` without
  regenerating the manifest → hard build failure
  (`hex_manifest_to_bin.py: source file 'label.s' has changed since the
  manifest was generated`); reverting → clean.
- `scripts/casm_oracle_inventory.py`: `reconciliation: OK`, 3 native
  manifests, 70/70 declared sha256.
- No `add_ca65_app` / `__MAIN_START__` / `command64.inc` / `build_label.inc`
  reference to LABEL anywhere.

## Deviations from the approved plan

1. **`labelconst.s` → inline constants.** Increment 3 found CASM 0.6.2
   emits 3-byte *absolute* addressing for a zero-page-valued named constant
   defined in an `.INCLUDE`d file (inline definitions correctly select zero
   page). The separate constants include the plan specified does not work;
   constants were inlined into `label.s` (BANNER precedent). User-approved
   mid-session. Defect filed as **Taskwarrior task 42** (not fixed here);
   memory `project-casm-included-constant-zp-absolute`.
2. **Banner format.** Rather than "keep lowercase" or "keep uppercase", the
   user chose to match DEBUG's `DEBUG v0.5.0.1128` format — app name
   uppercase glyph (shifted PETSCII), lowercase `v`, digits. This is the
   single `$3706` byte difference from the retired ca65 build.

## Pre-existing issues noted (not addressed — out of scope)

- `hex_manifest_to_bin.py`'s stale-source hint text names
  `build_dash_manifest.py` regardless of which app tripped it (cosmetic,
  shared tooling).
- `wiki/label-utility.md`'s "no arguments prompts interactively" was
  imprecise (bare `LABEL` errors; a trailing space or bare prefix
  prompts). Corrected in passing since the same file gained the provenance
  section; the underlying behaviour is unchanged from the retired build.

## Reviewer sign-off

- [x] `src/external/label/label-derivation.md` independent-reviewer line —
  user, 2026-09-02 (byte agreement, single intentional `$3706` difference,
  52-entry R6 ledger reconciled).
- [x] Completion-gate approval — user, 2026-09-02. Taskwarrior task 41
  closed. Provenance state for `label.ref.hex`: **`CANONICAL-INDEPENDENT`**.
