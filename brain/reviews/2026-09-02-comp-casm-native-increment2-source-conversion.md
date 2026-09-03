# COMP CASM-Native Increment 2 - Source Conversion

Date: 2026-09-02
Plan: `brain/plans/2026-09-02-comp-casm-native-migration.md`
Taskwarrior: `74845ecf-9e39-4253-8e78-6dfb4104d635` (task 42, project `comp`)
Status: completion candidate; Increment 3 approval pending

## Changes

- Converted `src/external/comp/comp.s` to uppercase-ASCII native CASM source.
- Inlined the exact fixed-address constants COMP consumes:
  - KERNAL: `KERNALCHROUT = $FFD2`;
  - Command64 API: `$1000`, selectors `$09/$3D/$3E/$3F/$4C`;
  - Command64 globals/scratch: `$033C`, `$63`, `$66/$67`, `$6D`, `$FB/$FC`;
  - PETSCII CR `$0D`;
  - unchanged app-private zero page `$70-$7F`.
- Removed ca65-only `.INCLUDE`, `.DEFINE`, `.IMPORT`, `.SEGMENT`, generated
  build-include use, and manual load-header source.
- Deleted `src/external/comp/common.inc`; its constants now live beside their
  use so CASM selects zero-page addressing correctly.
- Demoted 38 routine-internal targets to CASM `@local` labels. Routine entry
  points and data symbols remain global.
- Replaced true BSS with the approved emitted layout:
  - `FILE1BUF`: `.RES FILENAME_MAX + 1, $00`;
  - `FILE2BUF`: `.RES FILENAME_MAX + 1, $00`;
  - `BUF1`: `.RES CHUNK_SIZE, $00`;
  - `BUF2`: `.RES CHUNK_SIZE, $00`.

## Static Verification

- `scripts/check_casm_source_bytes.py src/external/comp/comp.s`: PASS,
  uppercase ASCII and no case-colliding identifiers.
- Source size: 9,855 bytes, below CASM's 65,535-byte combined-source cap by
  55,680 bytes.
- Symbol estimate from source definitions: 39 constants + 36 global labels +
  38 local labels = 113, below CASM's 512-symbol cap by 399.
- Search for `.SEGMENT`, `.IMPORT`, `.DEFINE`, `.INCLUDE`, `__MAIN_START__`,
  and `BUILD_COMP.INC`: no matches.
- `git diff --check` on both COMP source paths: PASS.
- Code statements, API calls, zero-page assignments, messages, and runtime
  branch relationships are unchanged apart from label spelling/scope.

## Deliberately Deferred

- Native assembly and exact address confirmation belong to Increment 3.
- The independent code-byte and relocation derivation belongs to Increment 3.
- CMake still names the retired ca65 source model until Increment 4; no build
  transition is claimed by this source-only increment.
- The existing cross-device stream invalidation defect remains unchanged and
  out of scope.

## Increment 2 Gate

Approve this source conversion to activate Increment 3: independent byte/R6
derivation, reviewer gate, dedicated native-assembly disk, and mismatch
classification. No shipping manifest or build transition is authorized yet.
