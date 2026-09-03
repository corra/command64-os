---
title: COMP → CASM-native migration — completion-gate walkthrough
date: 2026-09-02
plan: brain/plans/2026-09-02-comp-casm-native-migration.md
taskwarrior: 74845ecf-9e39-4253-8e78-6dfb4104d635 (task 42, project comp)
status: complete — user-approved 2026-09-02
---

# COMP CASM-native Migration — Walkthrough

Live and observed evidence for the Completion Gate of
`brain/plans/2026-09-02-comp-casm-native-migration.md`. Nothing here is an
intention — every line is a recorded result. Second external-application
migration (after LABEL), and the first to convert true ld65 BSS into emitted
CASM `.RES` storage.

## Increment gates (all user-approved 2026-09-02)

| Increment | Evidence | Gate |
| --- | --- | --- |
| 1 baseline + layout | `brain/reviews/2026-09-02-comp-casm-native-increment1-layout-baseline.md` | approved |
| 2 source conversion | `brain/reviews/2026-09-02-comp-casm-native-increment2-source-conversion.md` | approved |
| 3 oracle + native assembly | `brain/reviews/2026-09-02-comp-casm-native-increment3-oracle-and-native-assembly.md` | approved |
| 4 manifest + build transition | `brain/reviews/2026-09-02-comp-casm-native-increment4-manifest-and-build-transition.md` | approved |
| 5 functional + bootstrap | `brain/reviews/2026-09-02-comp-casm-native-increment5-functional-verification.md` | approved |
| 6 consolidation | this walkthrough | pending |

## What shipped

- `src/external/comp/comp.s` — self-contained native CASM source: constants
  inline (KERNAL `$FFD2`; OS API `$1000` + selectors `$09/$3D/$3E/$3F/$4C`;
  Command64 globals `$033C/$63/$66/$67/$6D/$FB/$FC`; PETSCII CR; app ZP
  `$70–$7F`; `common.inc` deleted), `@local` routine-internal labels,
  `.RES FILENAME_MAX+1,$00` / `.RES CHUNK_SIZE,$00` for the four buffers.
- `src/external/comp/comp.ref.hex` — reviewed shipping manifest
  (`scripts/build_comp_manifest.py` regenerates it; not a build step).
- `src/external/comp/comp-derivation.md` — independent byte + 61-entry R6
  derivation (the oracle), `provenance: CANONICAL-INDEPENDENT`.
- `CMakeLists.txt` — `add_ca65_app(comp …)` + `Ca65_FOUND` branch +
  `COMP_SRCS`/`COMP_ENTRY` removed; manifest-derived `comp` target (next to
  `label`); `command64_comp_test_d64` (native-assembly disk) and
  `command64_comp_func_test_d64` (functional matrix + `comp_func_fixtures`).
- `scripts/gen_comp_func_fixtures.py` — deterministic functional fixtures.
- `scripts/casm_oracle_inventory.py` — `comp.ref.hex` added to
  `NATIVE_MANIFESTS`.
- Docs: `CHANGELOG.md`, `brain/KNOWLEDGE.md`, `brain/EXTERNAL.md`,
  `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` (Ledger A + matrix
  rows), `wiki/tasks/comp-command.md` (manual-verification box), task spec.

## Storage disposition (the reason this was its own migration)

ld65 placed COMP's two 40-byte filename buffers + two 64-byte chunk buffers
in `BSS`, not written to the PRG. CASM has no BSS; the approved disposition
emits all **208 bytes** as `.RES …,$00` zero-fill in source order after the
messages. Consequences, all confirmed:

| | ca65 (pre) | CASM-native (post) |
| --- | --- | --- |
| load base | `$3800` (link) | `$3400` (CASM implicit) |
| image bytes | 890 (BSS absent) | 1098 (208 emitted) |
| PRG file | 1020 | 1228 |
| R6 entries | 61 | 61 |
| runtime footprint after relocate to `$3800` | `$3800–$3C49` | `$3800–$3C49` (identical) |

File grew by 208 bytes; runtime memory ceiling did not move.

## Independent oracle → native assembly (Increment 3)

`src/external/comp/comp-derivation.md` derives every byte from the NMOS 6502
encoding + CASM semantics + PRG/R6 framing + hand arithmetic. Peer-reviewed
and approved **before** CASM output was consulted. The frozen ca65
relocation structure was used only as differential evidence — it exposed one
missing source-site entry (`JMP @PTLOOP`, `$00B3`) in the first draft, which
was re-enumerated and re-reviewed.

Native **CASM 0.6.2 build 1419** on `command64_comp_test.d64` under VICE 3.10:

```
P1: DONE 00462 STATEMENTS
P2: DONE 00462 STATEMENTS
WRITE: comp.prg
DONE: P1 00462, P2 00462, 01228 BYTES
CASM: INPUT VALIDATED
```

Extracted `comp.prg` (1228 bytes, sha256
`1a0bfbf7be31a9c2844ea3ae2bfe56084f9f90571631bbe7ff212d89eec528e8`) compared
byte-for-byte against an image assembled from the derivation's ledgers +
serialized relocation table + footer: **EXACT MATCH, 0 differing bytes**.

Two byte-neutral source fixes were required to get there (both Increment 2
conversion errors; each corrected form assembles to the exact derived bytes):

1. `PRINTHEX8` bare `LSR` ×4 → `LSR A` — CASM needs the explicit accumulator
   operand (`CASM: INVALID ADDRESSING MODE` otherwise). Opcode `$4A` both
   ways. *(The diagnostic reported `AT LINE 238`; the real line is 494 —
   CASM's located-diagnostic line field wraps mod 256.)*
2. `@READERROR` / `@DONE` referenced from `COMPAREFILES` but scoped to a
   later global label → `@READERROR:` promoted to global `CFREADERROR`,
   `BNE @DONE` → `BNE CMPDONE`. Same addresses (`$35A5`, `$35A4`), same
   `$1E` branch displacement, exactly as derived.

Source hash: `34727919…` (review gate) → `597b6237…` (corrected), retained as
`source-sha256-at-review` in the derivation front matter.

## R6 relocation

`scripts/casm_r6_verify.py build/comp.prg`:

```
ok  footer: base $3400  count 61  magic 'R6'
ok  load header $3400 == footer base $3400
ok  program image 1098 bytes  $3400..$3849
ok  relocation table 122 bytes at file offset 1100..1221
ok  offsets strictly ascending and unique
ok  all 61 entries point at an in-image high byte (pages $34..$38)
ok  relocate to $3800 / $5000 / $9000: all high bytes in range
R6 VERIFY: PASS
```

The 61 offsets are identical to the derivation's sorted list
(`0016 … 029A`). Unlike the pre-migration ca65 artifact (whose table
referenced unemitted BSS at pages `$3C`), the native image is a
self-contained R6 oracle.

## Manifest + build transition (Increment 4)

- `comp.prg` now ships via
  `hex_manifest_to_bin.py comp.ref.hex comp.prg --source-dir src/external/comp`.
- `${COMP_TARGET}` and the target name `comp` unchanged; every image that
  packaged COMP resolves to the new artifact with no per-disk rewiring.
- Stale-source guard: appending a byte to `comp.s` →
  `cmake --build build --target comp` **hard-fails** with the sha mismatch;
  reverting restores a clean build.
- `comp.ref.hex` records `source_sha256` for `comp.s` and `BUILD_COMP`
  (frozen `1006`). No version banner, no generated version source.

## Live functional matrix (Increment 5)

Migrated `comp.prg` on `command64_comp_func_test.d64`, dispatched by name
from the Command64 shell (`Command 64-DOS Version 0.4.1.2680`), each command
returning to `c64[8]:>`:

| Command | Observed |
| --- | --- |
| `comp id1 id2` | `FILES COMPARE OK` |
| `comp one1 one2` | `COMPARE ERROR AT $000032: $9B $64` (one line) |
| `comp many1 many2` | 10 errors `$03 $0A $14 $21 $2F $3D $4A $58 $63 $70` then `10 MISMATCHES - STOPPING` |
| `comp long1 long2` / `long2 long1` | `FILES ARE DIFFERENT SIZES` (both directions) |
| `comp nope id2` / `comp id1 nope` | `FILE OPEN ERROR`; after #2, ZP `$70=$71=$FF` |
| `comp` / `comp id1 id2 id1` / `comp /x` | `USAGE…` / `TOO MANY ARGUMENTS`+usage / `UNKNOWN OPTION`+usage |
| `comp prga prgb` | `COMPARE ERROR AT $000001: $20 $30` (PRG load-address byte) |
| `casm casmhello.seq` → `comp casmhello.prg casmhello.ref` | `00040 BYTES`, `CASM: INPUT VALIDATED`; `FILES COMPARE OK` |
| `comp id1 9:id1` (cross-device) | `FILES ARE DIFFERENT SIZES` — pre-existing defect, unchanged, no hang |

Both file handles close on every open/exit path checked (`$70`/`$71` = `$FF`
after the open-error and mismatch-stop paths; parse-error paths never open a
file). Screenshot: `build/comp_inc5_final.png`.

## Build verification (Increment 6)

```
rm -rf build && cmake -B build               # clean configure, no warnings
cmake --build build                          # FULL BUILD OK, zero errors/warnings
```

16 COMP-carrying image targets all build: `image_d64`, `test_image_d64`,
`command64_casm_utils_d64`, `command64_label_test_d64`,
`command64_comp_test_d64`, `command64_comp_func_test_d64`,
`casm_overflow_test_d64`, `casm_include_test_d64`,
`casm_phase12/13/14/15_test_d64`, `casm_phase10_test_d64`,
`casm_progress_test_d64`, `casm_opcode_test_d64`, `casm_oracle_test_d64`.

| Check | Result |
| --- | --- |
| `build/comp.prg` sha256 | `1a0bfbf7…` == manifest `# sha256:` |
| clean rebuild from scratch | same sha256 (deterministic) |
| no-change rebuild | no regeneration work |
| `casm_r6_verify.py build/comp.prg` | `R6 VERIFY: PASS` |
| stale-source guard | hard-fails on `comp.s` edit without manifest regen |
| `casm_oracle_inventory` | `4 native manifests`, `71/71` sha + independent-derivation, `reconciliation: OK` |
| `image.d64` directory | `comp` prg present |

## Deviations from the approved plan

- None to the scope. The plan anticipated conversion-syntax fixes at
  Increment 3 ("classify any mismatch before editing source or oracle"); the
  two byte-neutral fixes above are exactly that. The Increment 3 gate
  explicitly covered the resulting source-hash move.

## Pre-existing issues noted (not addressed — out of scope)

- **Cross-device false size mismatch** (`wiki/tasks/comp-cross-device-regression.md`)
  — characterized as unchanged (Increment 5), still open.
- **CASM located-diagnostic line number wraps mod 256** — found during
  Increment 3, recorded in `brain/KNOWLEDGE.md`, filed as Taskwarrior 43
  (project `casm`, priority L). Not a shipping-byte issue.
- **CASM `.INCLUDE`d zero-page constant → 3-byte absolute** (Taskwarrior 42
  follow-up from the LABEL migration) — the reason COMP's constants are
  inline; unchanged.

## Reviewer sign-off

- [x] Independent reviewer: derivation reproduced (addresses, encodings,
      lengths, hashes, 61 R6 entries) — recorded in
      `src/external/comp/comp-derivation.md` (user, 2026-09-02, before native
      CASM output was consulted).
- [x] Completion gate: user approved this walkthrough 2026-09-02; trackers
      close.
