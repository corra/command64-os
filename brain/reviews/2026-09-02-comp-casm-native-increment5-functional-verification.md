# COMP CASM-Native Increment 5 - Functional and Bootstrap Verification

Date: 2026-09-02
Plan: `brain/plans/2026-09-02-comp-casm-native-migration.md`
Taskwarrior: `74845ecf-9e39-4253-8e78-6dfb4104d635` (task 42, project `comp`)
Status: completion candidate; Increment 5 gate approval pending

## Summary

The migrated (manifest-derived) `comp.prg` was driven live under Command64 on
a dedicated functional-matrix disk. All 12 planned scenarios produced exactly
the expected output with a clean `c64[8]:>` return; both file handles close on
every open/exit path checked; the migrated COMP still fills its
repository-wide "byte-compare assembler output against a trusted reference"
role; and the known cross-device stream-invalidation defect is unchanged -
not fixed, not worsened.

## Bootstrap Authority (plan decisions 1, 5)

- Host-side byte check (Increment 3): native `comp.prg` == the independent
  derivation, all 1228 bytes.
- Manifest round-trip (Increment 4): `hex_manifest_to_bin.py` reproduces the
  same bytes; `casm_r6_verify.py` PASS.
- Only after those passed was the migrated COMP used as a live comparator
  here. It is not used as its own oracle.

## Test Vehicle

- Disk: `build/command64_comp_func_test.d64` (target
  `command64_comp_func_test_d64`): `command64`, `comp` (manifest-derived),
  `casm`, deterministic fixture pairs from
  `scripts/gen_comp_func_fixtures.py`, and the established `casmhello`
  CASM fixture (`casmhello.seq` + `casmhello.ref`).
- Cross-device: a copy of the same image attached to unit 9
  (`/tmp/comp_func_dev9.d64`; VICE locks a single image to one unit).
- VICE 3.10 / C64SC via the `c64` MCP. Banner
  `Command 64-DOS Version 0.4.1.2680` confirmed by screen-RAM decode.
- CASM version in the fixture-assembly step: `CASM V0.6.2.1419`.

## Fixture derivation (all raw bytes, recomputable by hand)

| File | Bytes | Definition |
| --- | ---: | --- |
| `id1`, `id2` | 200 | `(i*7+11) & 0xFF`, identical |
| `one1` | 100 | `(i*3+5) & 0xFF` |
| `one2` | 100 | `one1` with byte `$32` XOR `$FF` (`$9B` -> `$64`) |
| `many1` | 200 | `(i*5+1) & 0xFF` |
| `many2` | 200 | `many1` with `+$40` at offsets 3,10,20,33,47,61,74,88,99,112,130,151,168,180,199 |
| `long1` | 150 | `(i*9+2)&0xFF` for 100, then `(i*2+1)&0xFF` for 50 |
| `long2` | 100 | first 100 bytes of `long1` |
| `prga` | 22 | `00 20` + bytes `00..13` |
| `prgb` | 22 | `00 30` + bytes `00..13` |

## Observed Result Matrix

| # | Command | Expected | Observed | Verdict |
| --- | --- | --- | --- | --- |
| 1 | `comp id1 id2` | `FILES COMPARE OK` | `files compare ok` | PASS |
| 2 | `comp one1 one2` | one `COMPARE ERROR AT $000032: $9B $64` | exactly that, no OK line | PASS |
| 3 | `comp many1 many2` | 10 errors at `$03 $0A $14 $21 $2F $3D $4A $58 $63 $70` then `10 MISMATCHES - STOPPING` | exactly that (byte pairs `$10/$50 $33/$73 $65/$A5 $A6/$E6 $EC/$2C $32/$72 $73/$B3 $B9/$F9 $F0/$30 $31/$71`) | PASS |
| 4 | `comp long1 long2` | `FILES ARE DIFFERENT SIZES` | `files are different sizes` | PASS |
| 5 | `comp long2 long1` | `FILES ARE DIFFERENT SIZES` | `files are different sizes` | PASS |
| 6 | `comp nope id2` (missing 1st) | `FILE OPEN ERROR` | `file open error` | PASS |
| 7 | `comp id1 nope` (missing 2nd) | `FILE OPEN ERROR`, handle 1 closed | `file open error`; ZP `$70=$FF $71=$FF` | PASS |
| 8a | `comp` (no args) | `USAGE: COMP FILE1 FILE2` | `usage: comp file1 file2` | PASS |
| 8b | `comp id1 id2 id1` (extra) | `TOO MANY ARGUMENTS` + usage | both lines | PASS |
| 9 | `comp /x` (slash option) | `UNKNOWN OPTION` + usage | both lines | PASS |
| 10 | `comp prga prgb` (PRG load-addr bytes) | `COMPARE ERROR AT $000001: $20 $30` | exactly that | PASS |
| 11 | `casm casmhello.seq` then `comp casmhello.prg casmhello.ref` | assemble 40 B `INPUT VALIDATED`; `FILES COMPARE OK` | `DONE: ... 00040 BYTES`, `CASM: INPUT VALIDATED`; `files compare ok` | PASS |
| 12 | `comp id1 9:id1` (cross-device, byte-identical) | pre-existing defect: `FILES ARE DIFFERENT SIZES`, no hang/crash | `files are different sizes`, clean prompt | PASS (unchanged) |

Every command returned to `c64[8]:>` with no drive error and no `flush`
needed (one earlier `BAD COMMAND OR FILE NAME` was a stray screen-clear
control code injected by the harness, not a COMP dispatch failure; re-run via
`cls` then the same command succeeded).

## Handle-close evidence (all paths)

`START` calls `CLOSEFILES` on the compare/summary path and on the
open-failure path; `CLOSEFILES` issues `DOS_CLOSE_FILE` for any non-`$FF`
handle and resets it to `$FF`.

- Open-error path (`comp id1 nope`): `$70=$FF, $71=$FF` after exit (file 1 was
  opened, then closed).
- Mismatch-stop path (`comp many1 many2`): `$70=$FF, $71=$FF` after exit.
- OK path / size-diff path: same `CLOSEFILES` call; clean returns and working
  subsequent commands (no leaked LFN).
- Parse-error paths (`comp`, `comp /x`, `comp id1 id2 id1`): no file opened
  before the error, handles stay `$FF`; `START` jumps straight to `@EXIT`.

## Cross-Device Characterization

`wiki/tasks/comp-cross-device-regression.md` documents: COMP reports
`FILES ARE DIFFERENT SIZES` for byte-identical cross-device files because
opening the second file switches LFN 15 and invalidates the first device's
stream. Observed here: identical `FILES ARE DIFFERENT SIZES`, clean prompt
return, no hang or crash. The migration neither fixed nor worsened it; the
task stays open.

## New Repo Artifacts

- `scripts/gen_comp_func_fixtures.py` - deterministic fixture generator.
- CMakeLists.txt: `comp_func_fixtures` target + `command64_comp_func_test_d64`
  disk image (`command64` + `comp` + `casm` + fixtures + `casmhello`).
- `build/comp_inc5_final.png` - end-of-run screenshot (supporting evidence).

## Deferred to Increment 6

- Fresh-configure + full zero-warning build; every `${COMP_TARGET}` /
  `comp`-carrying image target; production `comp.prg` == manifest bytes and
  deterministic; no-change-rebuild identity; stale-source hard failure
  (spot-checked in Increment 4); oracle-inventory + R6 reconciliation.
- `CHANGELOG.md`, `brain/KNOWLEDGE.md`, `brain/EXTERNAL.md`, task/user docs,
  DOX; walkthrough + completion sign-off.
- `wiki/tasks/comp-command.md` "Complete manual C64/VICE verification"
  checkbox (this increment supplies that evidence).

## Increment 5 Gate

Requested: approve the observed functional matrix (12/12 as expected, clean
shell returns, handles close, cross-device unchanged). Approval activates
Increment 6 (consolidation + completion gate).
