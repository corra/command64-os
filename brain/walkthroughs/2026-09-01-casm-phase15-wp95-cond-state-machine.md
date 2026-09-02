# Walkthrough: CASM Phase 15 WP95 — `cond.s` Conditional-Nesting State Machine

Plan: `brain/plans/2026-09-01-casm-phase15-wp95-cond-state-machine.md`
Phase plan: `brain/plans/2026-09-01-casm-phase15-conditional-assembly.md`
Taskwarrior: WP95 `1ed564ea`
Branch: `feature/casm-phase15`

WP95 builds the `cond.s` state machine and its unit harness. **No
`.if`/`.else` statement handling and no suppression scanner** — those are
WP96. `casm.s` gets exactly one new call per pass.

## Changes

- `src/external/casm/cond.s` — nine exported routines + one private helper,
  implementing the WP93 D3/D4 design:
  - `condResetForPass` — depth 0, site counter 0 (bitmap kept).
  - `condOpenIf` (A = decision) — push; `emitting = parentEmitting AND
    decision`; `NESTING_OVERFLOW` when full. Stamps the open location
    from the `CasmCondOpenLoc*` staging inputs.
  - `condElseif` (A = decision) — `emitting = parentEmitting AND (NOT
    priorBranchTaken) AND decision`.
  - `condElse` — `emitting = parentEmitting AND (NOT branchTaken)`;
    latches `SeenElse`.
  - `condEndif` — pop.
  - `condCurrentlyEmitting` / `condTopParentEmitting` — the query
    routines (A = 1/0).
  - `condAtEof` — depth ≠ 0 → `UNTERMINATED_CONDITIONAL`.
  - `condSiteDecision` (A = decision, X = pass) — byte index
    `(counterLo>>3) | (counterHi ? $20 : 0)`, bit mask
    `1 << (counterLo & 7)`; Pass 1 sets/clears the bit and returns the
    passed-in decision, Pass 2 reads and returns it; `SITE_OVERFLOW` at
    `counterHi >= 2` (= 512).
  - `condElseCommonCheck` (private) — the shared `WITHOUT_IF` /
    `ELSE_AFTER_ELSE` structural checks.
  - New `CasmCondOpenLoc{LineLo,LineHi,Column,FileId}` staging inputs +
    `condScratch`/`condMaskScratch`/`condPassScratch` (BSS, +7 bytes).

- `src/external/casm/casm.s` — `.import condResetForPass` + one
  `jsr condResetForPass` in each pass's setup block, immediately after
  the `CasmCurrentScope` reset. Nothing else.

- `tests/src/casm_cond/casm_cond.s` + `BUILD_TEST_CASM_COND` — 15-case
  unit harness driving `cond.s` directly. The narrowest link of any casm
  harness: `cond.s` + `common.inc` only (no VMM, no OS API, no other
  module). Cases: reset→emitting, `.if 1`/`.if 0`, `.else` of each,
  `.elseif` ladder, nested, nested-in-skipped (parent suppression wins),
  depth-16 overflow, `WITHOUT_IF` ×3, `ELSE_AFTER_ELSE` (`.else` and
  `.elseif` after `.else`), `condAtEof` balanced/open + location readback,
  `condTopParentEmitting` at four stack shapes, `condSiteDecision`
  Pass-1-record → Pass-2-replay round-trip (Pass 2 ignores the passed-in
  value), site overflow at 512.

- `CMakeLists.txt` — `test_casm_cond` narrow-link block (`TEST_PRG_SIZE
  0800`), added to `casm_include_test_d64`'s `PRGS`, removed from the
  default `test.d64` set (directory full — same as `test_casm_scope`).

## Defect found and fixed

`caseNestingOverflow` counted its 16-push loop in `X`, which `condOpenIf`
clobbers — the first live run showed `CASM COND: FAIL` at case 9 (marker
`........f......`). Moved the counter to a BSS byte; re-run clean. A
harness bug, not a `cond.s` bug.

## Verification

- **Build**: `cmake -B build && cmake --build build` clean. All 32
  `test_casm_*` targets build (31 + the new `test_casm_cond`).
  `BUILD_CASM` 1410 → 1411. No-change rebuild stable.
- **Live VICE** (3.10, `Command 64-DOS Version 0.4.1.2680`):
  - `casm_include_test.d64` → `test_casm_cond` → **`CASM COND: PASS`**
    (15 cases), clean shell return.
  - `casm_phase13_test.d64` → `casm casmassert1.s` (`CASM V0.6.0.1411`,
    P1/P2 DONE 3, 3 BYTES) + `comp casmassert1.prg casmassert1.ref` →
    **`FILES COMPARE OK`** — the two `condResetForPass` calls are
    byte-neutral through the real two-pass driver.
- **Envelope** (`ld65 -m`): casm CODE `$545B` → `$55C9` (+366 B, the
  `cond.s` routines + two `jsr`s), RODATA unchanged, BSS `$DA0` → `$DA7`
  (+7 B). BSS ends `$A818`; MAIN headroom under `$7400`: 1,373 →
  **1,000 bytes**. **Watch item**: WP96 (scanner + `.if EXPR` eval
  wiring) and WP97 (`.elseif`/`.ifdef`) will each add code; the `$7400`
  envelope may need a decision before WP99.

## Status

WP95 source-complete, build- and live-VICE-verified. Nothing committed at
time of writing. Requesting sign-off to close WP95 and start WP96 (the
`.if`/`.else`/`.endif` pass-driver wiring + `condScanSuppressedLine`
scanner + `.if EXPR` truthiness + `casm_phase15_test.d64` production
fixtures).
