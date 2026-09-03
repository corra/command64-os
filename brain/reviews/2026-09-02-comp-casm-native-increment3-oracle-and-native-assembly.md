# COMP CASM-Native Increment 3 - Independent Oracle and Native Assembly

Date: 2026-09-02
Plan: `brain/plans/2026-09-02-comp-casm-native-migration.md`
Taskwarrior: `74845ecf-9e39-4253-8e78-6dfb4104d635` (task 42, project `comp`)
Status: completion candidate; Increment 3 gate approval pending

## Summary

Native CASM 0.6.2 (build 1419) assembled `src/external/comp/comp.s` on the
dedicated bootstrap disk and produced a 1,228-byte R6 PRG that is
**byte-for-byte identical** to the independently derived oracle in
`src/external/comp/comp-derivation.md` (user-approved 2026-09-02, before any
CASM output was consulted). `scripts/casm_r6_verify.py` passes and the image
relocates cleanly at three bases.

Two source defects were found by native assembly and fixed. Both were
Increment 2 conversion errors, not oracle errors; both corrected forms
assemble to the exact bytes already in the reviewed derivation, so the
oracle's byte and R6 ledgers are unchanged.

## Oracle (unchanged from the approved derivation)

- `src/external/comp/comp-derivation.md`, `provenance: CANONICAL-INDEPENDENT`.
- Image `$3400-$3849`, 1,098 bytes: 683 code + 207 messages + 208 zero-fill.
- 61 R6 relocation entries; 122-byte table; footer `00 34 3D 00 52 36`.
- Total serialized size 1,228 bytes (`$04CC`).

## Source Corrections Applied This Increment

Reviewed source at the Increment 2 gate: SHA-256 `34727919...`
(`source-sha256-at-review` in the derivation front matter).
Corrected source now: SHA-256
`597b6237d9a6cbeac07216f598d60f00380aa02fc3193fde5585c922cacf6ed7`.

| # | Native diagnostic | Cause | Fix | Byte effect |
| --- | --- | --- | --- | --- |
| 1 | `CASM: INVALID ADDRESSING MODE` at `LSR` (reported line wraps mod 256) | `PRINTHEX8` used bare `LSR` x4; CASM requires the explicit `LSR A` accumulator operand | `LSR` -> `LSR A` x4 | none - opcode `$4A` both ways; derivation already shows `48 4A 4A 4A 4A` |
| 2 | `CASM: UNDEFINED LOCAL LABEL` at `@READERROR` (P2) | CASM resets the `@name` namespace at every global label. `COMPAREFILES` referenced `@READERROR`/`@DONE`; `@READERROR:` is defined after the global `CMPDONE:` (new scope) and `@DONE:` was the retired ca65 `closeFiles` shared-`RTS` trick | `@READERROR` -> global `CFREADERROR` (addr `$35A5`); `BNE @DONE` -> `BNE CMPDONE` (`RTS` at `$35A4`, disp `$1E`) | none - both targets and the branch displacement are exactly as derived |

A static scope check (`@name` reference vs. per-global-label definition
scope) now reports no unresolved local labels.

## Native Assembly Evidence

- Disk: `build/command64_comp_test.d64` (target `command64_comp_test_d64`):
  `command64`, `casm`, `comp.s` (SEQ). Pre-build gate
  `check_casm_source_bytes.py` passes.
- VICE 3.10 / C64SC via the `c64` MCP. Command64 banner
  `Command 64-DOS Version 0.4.1.2680` confirmed by screen-RAM decode.
- Shell dispatch: `casm comp.s`.
- CASM output:
  `P1: DONE 00462 STATEMENTS`, `P2: DONE 00462 STATEMENTS`,
  `WRITE: comp.prg`, `DONE: P1 00462, P2 00462, 01228 BYTES`,
  `CASM: INPUT VALIDATED`. Clean return to `c64[8]:>`.
- `comp.prg` extracted host-side (`c1541 -read`): 1,228 bytes, SHA-256
  `1a0bfbf7be31a9c2844ea3ae2bfe56084f9f90571631bbe7ff212d89eec528e8`
  (recorded as `native-observation` in the derivation front matter).

## Byte and R6 Reconciliation

- Expected image assembled from the derivation's instruction/data/storage
  ledgers + serialized relocation table + footer = 1,228 bytes. Native
  `comp.prg` compared byte-for-byte: **EXACT MATCH**, zero differing bytes.
- Load header `$3400` == footer base `$3400`.
- Relocation table: 61 offsets, strictly ascending, unique, identical to the
  derivation's sorted offset list (`0016 ... 029A`).
- `scripts/casm_r6_verify.py /tmp/comp_native.prg`: **R6 VERIFY: PASS** -
  program image 1,098 bytes `$3400..$3849`; all 61 entries point at an
  in-image high byte (pages `$34..$38`); relocations valid at `$3800`
  (+4 pages), `$5000` (+28), `$9000` (+92).

## Deliberately Deferred

- `comp.ref.hex`, `scripts/build_comp_manifest.py`, and the ca65 -> manifest
  build transition are Increment 4.
- Functional matrix (identical/mismatch/size-asymmetry/missing-arg/slash/raw
  PRG, both-handles-close, an established CASM fixture comparison, the known
  cross-device characterization) is Increment 5.
- Determinism / no-change-rebuild / stale-source failure and the full image
  dependency sweep are Increment 6.
- The known cross-device stream-invalidation defect
  (`wiki/tasks/comp-cross-device-regression.md`) remains open and untouched.

## Increment 3 Gate

Requested: acknowledge that the reviewed derivation's bound source hash moved
from `34727919...` to `597b6237...` for the two byte-neutral corrections
above, and approve that the reviewed oracle and the native artifact agree
exactly. Approval activates Increment 4 (manifest + build transition). No
shipping manifest or CMake change is authorized yet.
