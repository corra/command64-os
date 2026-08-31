---
feature: casm-progress-increment08-automated-verification
created: 2026-08-24
status: complete
approved: 2026-08-31
closed: 2026-08-31
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment07-output-diagnostic-listing, approved and complete
---

# Plan: CASM Progress Increment 8 - Automated Verification

## Status

**COMPLETE - user-approved 2026-08-31** (with Atomic Increments 6 & 7 waived
as redundant re-checks of a byte-identical binary). This increment added
verification artifacts and performed no intentional production behavior
change.

## Objective

Run the complete automated/static matrix against one candidate, add a dedicated
self-bootable progress disk and permanent fixtures where approved, and produce
reviewable artifact, resource, size, and timing evidence.

## Verification Architecture

- Add `casm_progress_test_d64` rather than consuming `test.d64`, listing, overflow,
  or Phase 13 disk capacity. Include `command64`, `casm`, `comp`, focused harness,
  sources, includes, payloads, and trusted references with writable headroom.
- Use CMake for all configure/build/fixture/disk/toolchain operations.
- Cover <64, 64/65/128 statements, blanks/comments, multi-root, filename widths,
  nested/reincluded includes, large fixed fills/alignment, `.INCBIN`, static/R6,
  `/L`, `/M`, `/L /M`, diagnostics, cleanup, overflow, and mismatch.
- Compare emitted artifacts and listings against trusted references/native COMP.
- Run all existing relevant CASM harnesses and Phase 9-13 production fixtures.
- Inspect production/focused envelopes, BSS, imports/exports, zero page, disk
  entries/blocks, handles/VMM cleanup, and repeat-run behavior.
- Enforce <=5% representative and <=10% short-statement slowdown from Increment 1.

## Atomic Increments

1. Add fixture/reference generation and focused target dependencies.
2. Add the dedicated disk with collision-safe names and explicit writable reserve.
3. Build the focused target, candidate CASM, references, and all affected disks.
4. Run focused and complete relevant harness matrices.
5. Run static/R6/listing/map native comparisons and failure cleanup checks.
6. Run repeated timing matrix in the same VICE configuration.
7. Perform exact no-change rebuild and hash/counter comparison.
8. Record all evidence and unresolved findings in the walkthrough.

## Expected Files

| File | Planned action |
| --- | --- |
| `CMakeLists.txt` | Add fixtures, target dependencies, and dedicated disk |
| `cmake/GenerateCasmTestFixtures.cmake` | Add deterministic fixtures if required |
| `tests/fixtures/casm/*` or existing CASM fixture location | Add sources/payloads/references |
| `tests/AGENTS.md` | Update only for durable disk/launch contracts |
| `tools/casm_progress_inc8_matrix.sh` | Helper: emits the live-VICE command `vice_keyboard_petscii` payloads |
| Matching walkthrough | Create |

## Stop Conditions

Stop on any unexpected test failure, artifact difference, cleanup leak, disk
overflow/name collision, cap breach, no-change counter/hash drift, undeclared
generated dependency, or new defect. Disclose and defer unrelated defects.

## Documentation, Task, and DOX Updates

Record matrix state in trackers. Update tests DOX with the dedicated disk's stable
location, contents, launch contract, and capacity requirement if created. Apply
the CMake overlay-event workflow to any qualifying build-system additions.

## Completion Gate

All matrix rows pass with raw evidence, no unresolved blocker remains, artifacts
and no-change builds are stable, walkthrough exists, and user approves Increment 8.

## Progress

- 2026-08-24: Detailed verification plan drafted; no fixtures or disk added.
- 2026-08-31: Plan approved by the user ("approve as drafted, begin"). Work
  begins on `feature/casm-progress-indication` directly, matching Increments
  3-7's own on-branch commit convention (no per-increment sub-branch).
  Baseline confirmed: `CASM 0.4.0` build `1378`, `casm.prg` sha256
  `af1bacdab72a40bf20983a8676592873d76b0bd74d2b6c0b68155b6f7c3d819c`,
  `$7400` MAIN, 666 bytes headroom (Increment 7 close). Redraw cadence is
  mod-64 statements (`CasmProgDivider`, `progress.s:91`; fires at exact
  counts 64/128/192...), so the statement-count matrix rows are 63 (<64,
  no throttled redraw), 64 (exactly one), 65 (one plus a 1-statement
  remainder), and 128 (two).
  Atomic Increment 1 starting: progress-cadence fixtures + focused target
  dependencies.
- 2026-08-31 (Atomic Increments 1-3, host side):
  - **Fixtures** added to `cmake/GenerateCasmTestFixtures.cmake`: `casmpg63`,
    `casmpg64`, `casmpg65`, `casmpg128` (`.ORG $C000` + N NOP, cadence
    boundaries); `casmpgblank` (blank/comment lines must not advance the
    counter, 5 real statements); `casmpgrta`/`casmpgrtb` (multi top-level
    source, combined PC); `casmpginca`/`casmpgincb`/`casmpgincc` (nested
    include + sequential re-inclusion, bare disk names referenced by
    operand); `casmpgfill` (`.RES 100` + `.FILL 50,$AB` + `.ALIGN 256`);
    `casmpgincbin` (`.INCBIN` of an 8-byte payload); `casmpgr6` (no `.ORG`,
    forward label -> one real R6 relocation entry).
  - **Trusted references** (10 new `tests/fixtures/casm/casmpg*.ref.hex`,
    hand-derived from the 6502 instruction set via a reviewed repetition
    rule, never from CASM; all validate through `hex_manifest_to_bin.py`)
    plus `tests/fixtures/casm/casmpgbin.dat` (8-byte binary asset).
    Added to `CASM_REF_NAMES`; excluded from the generic test.d64
    reference loop (`REF_NAME MATCHES "^casmpg"`).
  - **Disk**: new `add_c64_disk_image(casm_progress_test_d64)` producing
    `casm_progress_test.d64`, self-bootable (`command64` + `casm` + `comp`),
    carrying `test_casm_progress` (the 20-case unit harness, regression) plus
    every casmpg* fixture and reference. Built clean: **435 blocks free**
    (ample writable headroom for `test_casm_progress`'s own runtime output
    files). Overlay build events wired via the standard `WRAPPER_CC1541`
    pattern.
  - **Build evidence**: `cmake -B build` and full `cmake --build build`
    both exit 0, no real toolchain errors (the only `grep -i error/fail`
    hits are the substrings in disk-image *names*). `casm.prg` sha256
    **`af1bacda...` unchanged** from the Increment 7 baseline; `BUILD_CASM`
    still **1378** (no production source touched); targeted no-change
    rebuild of `casm` reproduced the identical hash; `git diff --check`
    clean.
  - **Cadence off-by-one caught before hand-off**: `casm.s`'s
    `crpProgressHook` counts label/constant/mnemonic **and directive**
    statements, so `.ORG` counts. The cadence fixtures were adjusted to
    carry `.ORG` + (N-1) NOP so a fixture named for N *counted* statements
    actually hits the boundary: `casmpg63` = `.ORG` + 62 NOP (63 counted,
    no redraw), `casmpg64` = +63 NOP (64, one redraw), `casmpg65` = +64 NOP,
    `casmpg128` = +127 NOP (two redraws). References + expected sizes
    (64/65/66/129) regenerated to match; full build re-verified green,
    `casm.prg` still `af1bacda...`.
  - **Walkthrough skeleton** written:
    `brain/walkthroughs/2026-08-24-casm-progress-increment08-automated-verification.md`
    -- the full ordered live-VICE procedure (session setup + freshness
    check, the 10-row dispatch/assertion table with exact
    `vice_keyboard_petscii` `data` arrays, option-identity sub-matrix,
    cleanup checks, the 31-harness regression roster, timing matrix,
    no-change rebuild), with a `___` result cell for every row.
  - **Helper**: `tools/casm_progress_inc8_matrix.sh` prints every command's
    `vice_keyboard_petscii` `data` array (wraps `tools/vice_type_command.py`)
    so the live session never hand-derives PETSCII/case bytes.
  - Atomic Increments 4-8 (focused + full harness matrix, native
    COMP/listing/map comparisons, failure-cleanup checks, repeated timing
    matrix, exact no-change disk rebuild, walkthrough result capture) are
    live-VICE and remain to be run per the project verification policy.
- 2026-08-31 (live-VICE session, VICE 3.10 PAL C64SC, `WarpMode: 0`;
  `command64` booted from `casm_progress_test.d64` on unit 8, CASM banner
  `CASM V0.4.0.1378` confirmed):
  - **Atomic Increment 4 - COMPLETE, 10/10 + 5/5 PASS.** Every `casmpg*`
    fixture: P1==P2 statement counts, `DONE:` byte total matched the
    hand-derived reference size exactly (64/65/66/129/7/258/10/54/82/9),
    `comp` -> `FILES COMPARE OK`. `casmpgblank` counter = 6 (blank/comment
    lines excluded). `casmpgfill` 258 (fixed-fill accounting). `casmpgr6`
    54 (R6 table + footer included). `casmpginc` 12 counted (nested +
    sequential re-inclusion both traversed). Multi-root `casmpgrt` 81
    combined. Option-identity: default/`/M`/`/L`/`/M /L`/`/S` all
    byte-identical 129 bytes; `pc.lst`==`pd.lst`==21 blocks; `/M` map +
    `/L` listing clean screen ownership. Overlay test `pass` event fired.
  - **Atomic Increment 5 - PARTIAL.** `casm nosuchfil.s` -> `CASM: CANNOT
    OPEN INPUT`, clean shell return, no residue (fatal input-open path
    clean with `progress.s` linked). The mid-assembly fatal +
    partial-output-cleanup case needs a bad fixture added to the disk -
    deferred within this increment.
  - **Atomic Increment 8 - COMPLETE, PASS.** Two consecutive full builds:
    `casm.prg` (`af1bacda...`) and `casm_progress_test.d64`
    (`1bf0df83...`) byte-identical; `BUILD_CASM` 1378; `git diff --check`
    clean.
  - **Atomic Increments 6 (31-harness regression re-confirmation) and 7
    (timing matrix) remain** - large live-VICE efforts at normal speed
    (warp could not be toggled via the MCP wrapper); best as a dedicated
    session. The binary is unchanged from Increment 7's own 31/31 pass, so
    Increment 6 is a provenance re-check, not new coverage.
  Walkthrough updated with all raw results.
- 2026-08-31: User accepted the Increment 4 evidence ("Increment 4 is
  fine"). Increments 6 and 7 proposed **waived** in the walkthrough's
  Completion Gate: the production binary is byte-identical to the one
  Increment 7 already ran through the full 31-harness sweep (zero
  failures) and the caps were formally amended non-blocking 2026-08-26, so
  both are redundant re-checks of an unchanged artifact rather than new
  coverage. `docs/casm-utility.md` confirmed drift-free against observed
  output. Increment 5 left partial (fatal input-open clean; mid-assembly
  fatal needs a bad fixture - noted, not blocking). Awaiting explicit user
  approval to close Increment 8.
