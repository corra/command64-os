---
feature: casm-progress-increment01-activation-baseline
plan: brain/plans/2026-08-24-casm-progress-increment01-activation-baseline.md
date: 2026-08-24
status: approved
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
---

# Walkthrough: CASM Progress Increment 1 -- Activation and Baseline

## Summary

This increment activated the optional progress-indication feature as a
measured effort and captured a reproducible baseline from current `main`
(== `feature/casm-progress-indication`, both at `4e3f921`). No CASM
production code was touched. Two significant findings surfaced that should
inform Increment 2's design/ABI review before any implementation begins.

## Increment 1: Reconcile branch/phase/plan/task/version state

- `feature/casm-progress-indication` and `main` are identical
  (`4e3f921add755f63c7534afe17084362a762858b`); no reconciliation drift.
- CASM at `0.4.0` build `1349`, Command64 OS at `0.4.1` build `2680` --
  matches the parent plan's own 2026-08-24 reconciliation baseline exactly.
- Phase 9-13 completion memories checked against the current tree: all
  agree (Phase 13 closed 2026-08-21 at `0.4.0` build `1349`, matching
  `BUILD_CASM` verbatim). No disagreement found -- no stop condition
  triggered.
- Taskwarrior task 33 (`1acb36e3-2c0e-4f24-998b-279b2578bee4`) tagged
  `activated`; left `Pending`, not marked complete, per the plan's own
  instruction ("synchronize the feature task ... without marking any
  implementation complete").

## Increment 2: Refresh call paths

Symbol lookup used `search_graph` (confirmed indexed, zero call edges for
`.s` sources per the standing `codebase-mcp-asm-gap` finding); actual
call-path tracing used `grep`, per that same finding. Swept and confirmed
current for all seven required areas:

- **Orchestration**: `casm.s` `start` -> init -> Pass 1 (`casmRunPass`
  under `CASM_PASS_MODE_MEASURE`) -> `casmResolveConstants` ->
  Pass 2 (`casmRunPass` under `CASM_PASS_MODE_EMIT`) ->
  `includeReplayFinalCheck` -> `emitCheckPassAgreement` ->
  `listingCaptureFinalize` -> `emitFinalize` -> `relocFinalize` ->
  `sourceClose` -> `outputCommit` -> `listingWriteFile` (`/L` only) ->
  `mapPrint` (`/M` only) -> `diagPrintPhase2Ready` -> `exitSuccess`.
- **Dispatch loop** (`casmRunPass`, `casm.s:428`): per-statement dispatch
  on token type -- `crpLabel`, `crpConstant`, `crpInsn` (via
  `opcodesFindOpcode`/`emitInstruction`), `crpDir` (splits on
  `CASM_DIRECTIVE_INCLUDE` -> `crpInclude`, else `crpEmitDir` ->
  `emitDirective`), `crpDone` at EOF. Listing-capture transactions
  (`crpListingBegin`/`crpListingCommit`) are gated to Pass 2 only.
- **Source/include**: `source.s` (`sourceInit`/`sourceLoad`/`sourceOpen`/
  `sourceNextByte`/`sourceRewind`/`sourceFramePush`/`sourceRefill`/
  `sourceClose`, 20 entry points total) and `include.s`
  (`includeCatalogInit`/`includeCatalogLookup`/`includeEventRecord`/
  `includeEventReplay`/`includeReplayReset`/`includeReplayFinalCheck`).
- **Directives**: `emit.s` (`emitDirective`, `emitOrg`, `emitByteList`/
  `emitWordList`, `emitRes`/`emitFill`/`emitAlign`/`emitAlignMod`/
  `emitFillLoop`, `emitIncbin`, `emitAssert`).
- **Writes**: `fileio.s` (`fileOpenInput`/`fileCreateOutput`/`fileRead`/
  `fileWrite`/`fileClose`/`fileDelete`), `emit.s`
  (`emitByte`/`emitRawByte`/`emitFlush`).
- **Diagnostics**: `diagnostics.s` (34 entry points -- `diagPrintFatal`,
  `diagClearLoc`, `diagSetLocFrom*`, `diagPrintLineAndCaret`,
  `diagPrintSourceContext`, `diagPrintIncludeTraceback`, `diagDumpToken`).
- **Listing**: `listing.s` (`listingStateInit`/`listingCaptureInit`/
  `listingBeginLine`/`listingMirrorByte`/`listingCommitLine`/
  `listingCaptureFinalize`/`listingWriteFile`, 19 entry points).
- **Map**: `map.s` (`mapPrint`/`mapValidateRecord`/`mapFormatRow`/
  `mapWriteHexByte`/`mapFormatTotal`/`mapSuffixSymbols`).

This matches the parent plan's integration-point contracts; no drift found.

## Increment 3: Configure and build baseline through CMake

- `cmake -B build` clean; full `cmake --build build` clean.
- `image_d64`, `test_image_d64`, and all seven Phase 9-13 disk targets
  (`casm_include_test_d64`, `casm_listing_test_d64`, `casm_opcode_test_d64`,
  `casm_overflow_test_d64`, `casm_phase10_test_d64`, `casm_phase12_test_d64`,
  `casm_phase13_test_d64`) built clean.
- **No-change rebuild stable**: `casm.prg` SHA-256 identical
  (`696f3a23...4b7b6b1`) before and after a full rebuild with no source
  changes; `BUILD_CASM` unchanged at `1349`.

## Increment 4: Artifact hashes, envelope, zero page, disk capacity

### MAIN envelope -- CRITICAL FINDING

Relinked `build/out_casm/*.o` directly with `ld65 -C
build/build_casm_cfg/casm_3800.cfg -m -Ln` to get exact linker-reported
sizes (the CMake build itself does not emit a mapfile).

- MEMORY contract: `MAIN: start=$3800, size=$6C00` (budget end `$A400`).
- `__MAIN_LAST__` (true end of CODE+RODATA+DATA+BSS) = `$A319`.
- **Used: `$6B19` = 27417 bytes. Headroom: `$00E7` = 231 bytes (0.8%).**

This is far tighter than the parent plan's own framing suggested -- `$6C00`
is the *budget size*, not free space, and only 231 bytes remain in it. Any
progress-indication code, however minimal, must fit in this margin or
CASM's own MAIN segment must be re-budgeted first. This is the single most
important fact Increment 2's design/ABI review must open with.

### Zero page -- CRITICAL FINDING

CASM's private ZP contract (`common.inc:22-98`) is `$70-$8F` (32 bytes,
`.assert`-enforced). Every byte is already named and aliased across
CLI/source/lexer/parser/expr/diagnostics/pass/emit phases (e.g.
`CasmDiagWinStart` overlays `CasmExprScratch0`, documented safe because the
diagnostic renderer only runs after evaluation has stopped). **There is no
spare ZP byte.** Any progress state needing persistent ZP must reuse an
existing alias under a new, explicitly documented non-overlapping lifetime
window, exactly as the diagnostics module already does -- or it cannot be
represented in ZP at all.

### Disk capacity (free blocks, all disks rebuilt from scratch)

| Disk | Free blocks |
|---|---|
| `image.d64` | 304 |
| `test.d64` | 112 |
| `casm_include_test.d64` | 75 |
| `casm_listing_test.d64` | 123 |
| `casm_opcode_test.d64` | 458 |
| `casm_overflow_test.d64` | 23 |
| `casm_phase10_test.d64` | 480 |
| `casm_phase12_test.d64` | 284 |
| `casm_phase13_test.d64` | 343 |

`casm_overflow_test.d64` (23 blocks = ~5.7KB free) is too tight for a
dedicated progress-feature test image without either cuts elsewhere or a
new disk. This directly informs the "dedicated progress image contract"
decision the plan defers to Increment 2.

### Fixture selection

- **Large**: `casmbiga.s` + `casmbigb.s` (WP36, 12011 + 12000 bytes,
  3000 NOP statements each, two-file successful assembly via CASM's
  documented multi-file source syntax -- `CASM CASMBIGA.S CASMBIGB.S`,
  confirmed via `cli.s`'s `CasmSourceCount`-based token loop).
- **Short-statement stress**: `casmopall.s` (2028 bytes, 151 statements,
  one per opcode).
- **Byte-heavy directive: NO qualifying fixture exists.** `casmres1.s`
  (29B), `casmfill1.s` (23B), `casmalign1.s` (30B), `casmincbin1.s`/`.dat`
  (37B / 4B) are all tiny Phase 13 correctness fixtures, not timing
  stress fixtures. The parent plan's own Prerequisites section already
  anticipates this gap ("Add one byte-heavy directive fixture containing
  large fill/alignment output and `.INCBIN` payload processing"), and
  Increment 1 explicitly excludes fixture creation. `casmincbin1.s` was
  used below as the closest available proxy for the `.INCBIN` code path
  only, not as a byte-heavy timing baseline -- **flagged for creation in
  a future increment**, not resolved here.

## Increment 5: Timing baselines and artifact witnesses

All runs live under VICE (PAL, true-drive emulation, one continuous
session), on a purpose-built scratch disk (`baseline_timing.d64`:
`command64.prg`, `casm.prg`, the selected fixtures) attached on unit 8.
Command64 banner verified (`Command 64-DOS Version 0.4.1.2680`) before each
run. Completion detected via CASM's own terminal message
(`CASM: INPUT VALIDATED`, `diagnostics.s:1717`) read directly from screen
RAM, not by a fixed delay. Every run used a never-before-used output
filename to avoid the known `fileCreateOutput` no-`@0:` replace limitation
([[project-casm-filecreateoutput-no-replace]]) -- confirmed hit once during
setup (`OUTPUT WRITE FAILED` / `Drive 8 status: 63, file exists`) when a
debugging-only partial run left a stale `OPALL.PRG`; not a new defect, and
not counted in the timings below.

| Run | Command | Wall time | Result |
|---|---|---|---|
| Short-statement stress | `CASM CASMOPALL.S /O:OPALL2.PRG` | 87.74s | `CASM: INPUT VALIDATED` |
| Large, two-file | `CASM CASMBIGA.S CASMBIGB.S /O:BIG1.PRG` | 228.14s | `CASM: INPUT VALIDATED` |
| `.INCBIN` proxy + `/L /M` | `CASM CASMINCBIN1.S /O:INC1.PRG /L /M` | 86.24s | `CASM: INPUT VALIDATED`, `SYMBOL MAP` / `000 SYMBOLS` |
| R6-output capture | `CASM CASMR6.S /O:R6.PRG` (no `.ORG`) | 81.73s | `CASM: INPUT VALIDATED` |

The three small runs cluster at 82-88s despite trivially different source
sizes -- this floor is `casm.prg`'s own ~31KB true-drive-emulation load
time, not assembly work. The large fixture adds roughly 140s beyond that
floor for 6000 NOP statements across two files. This split (load-dominated
vs. dispatch-loop-dominated) is directly relevant to where progress
indication needs to appear first.

### Artifact hashes (SHA-256)

| Artifact | Bytes | SHA-256 |
|---|---|---|
| `casm.prg` (assembler itself) | 31185 | `696f3a23eb1ca1605a201bad2e05c56f33efde9858ab0d54a126fe81764bcd97` |
| `command64.prg` | 12281 | `0e7e460c2982e55a2fb4516b026a47188b99c1cd3cb91f0753c3a999b6813161` |
| `OPALL2.PRG` (static, `.ORG`-pinned) | 323 | `0bccfbc18392bb108c26b91b9c6b289b1a4537c40b995bdde2e7409939c9f6fc` |
| `BIG1.PRG` (static, `.ORG`-pinned) | 6002 | `7288e48919ca646b4ddd242ad6dcc6a05cecccdd181a380d5d559a1682ae391d` |
| `INC1.PRG` (static, `.ORG`-pinned) | 6 | `6130236c271623e324eed61863bb4ef03f464db2821fd1922aad44f2945d1aa1` |
| `INC1.LST` (`/L` listing) | 164 | `f24811760d1bea16ecef2336ed0ca8a9feb79b67ba5810a2f1258700efc4d78f` |
| `R6.PRG` (relocatable, no `.ORG`) | 9 | `2f43fc2ec563f0e44c8055622d0767cff277499f7feb9db6e0a0ccf8ce3903b3` |

Notes:
- `INC1.PRG`'s hash matches `tests/fixtures/casm/casmincbin1.ref.hex`'s
  trusted-reference bytes exactly (`6130236c...`) -- confirms `.INCBIN`
  output correctness independent of this baseline's own purpose.
- Static vs. R6 output is controlled by whether the source uses an
  explicit `.ORG` (static) or not (R6-relocatable at CASM's default
  `$3400` origin), **not** by the `/S` flag alone
  (`reloc.s:170`, `CasmRelocatableMode`) -- all three fixture runs used
  `.ORG` for self-contained addressing, so a fourth minimal run
  (`casmr6.s`, one bare `NOP`, no `.ORG`) was added specifically to
  capture a genuine R6 footer: `00 34 EA 00 34 00 00 52 36` --
  header ($3400) + `NOP` + footer (BaseAddr=$3400, TableSize=0,
  `'R'` `'6'`), matching the documented R6 footer format exactly
  (`loader.asm:64-90`).
- `INC1.PRG` at 6 bytes (2-byte header + `DE AD BE EF`) confirms
  `casmincbin1.dat`'s actual payload is 4 bytes, matching the disk
  extraction.
- `/M` screen output for the `.INCBIN` proxy: `SYMBOL MAP` / `000 SYMBOLS`
  (no labels defined in that fixture) -- correct, no output-byte deviation
  from Phase 10's completed contract observed.

### Operational finding (recorded to memory, not a stop condition)

Editing a `.d64` on the host with `cc1541` while VICE has it attached is
silently reverted by VICE's own in-memory disk state on next write-back --
confirmed when adding `casmbigb.s` to the already-attached scratch disk:
`cc1541` reported success and showed the file in its listing, but a
`vice_disk_detach`/`vice_disk_attach` cycle made it disappear again, and a
fresh host-side extraction proved it was never actually written. Fixed by
always detaching before any host-side edit. Recorded as
[[reference-vice-attached-disk-host-edit-reverted]] for future sessions.

## Stop Conditions

None triggered. Phase records agree, current `main` reproduces trusted
artifacts (`INC1.PRG` == its own `.ref.hex`), all baseline harnesses
succeeded, timing was directly observed (not estimated), the no-change
build is stable, and disk capacity was measured, not assumed.

## Completion Gate

- [x] All baseline fields and raw timing runs recorded above.
- [x] Trusted outputs reproduce (`INC1.PRG` byte-identical to
      `casmincbin1.ref.hex`).
- [x] Trackers agree (Taskwarrior 33 tagged `activated`, not completed;
      parent plan's reconciliation confirmed current).
- [x] User explicitly approves Increment 1's baseline.

## Carry-forward for Increment 2 (design/ABI review)

1. **231 bytes of MAIN headroom (0.8%)** is the binding constraint --
   any progress-indication code must fit in this, or CASM's MAIN budget
   needs to grow first. This should be the design review's opening
   question, not an afterthought.
2. **Zero spare CASM zero-page bytes** (`$70-$8F` fully allocated) --
   any persistent progress state needs a documented alias-reuse window,
   not a new byte.
3. **No byte-heavy directive timing fixture exists yet** -- needed before
   Increment 2 can responsibly reason about `.RES`/`.FILL`/`.ALIGN`/
   `.INCBIN` progress visibility at realistic scale.
4. `casm_overflow_test.d64` has only 23 free blocks -- the "dedicated
   progress image" decision the parent plan defers to this point should
   account for that tightness explicitly.
