---
feature: casm-phase15-wp95-cond-state-machine
created: 2026-09-01
status: complete (user-approved 2026-09-01, committed ecbd717)
taskwarrior: 1ed564ea-7b62-4eaa-b385-b9451935af95 (WP95), parent
  0678049c-7d67-4b9a-9305-14efb2353ae1 (Phase 15)
depends-on: WP93 (design freeze, committed 37bd4c8), WP94 (lexer keywords,
  committed fb21ff9)
---

# Plan: CASM Phase 15 WP95 — `cond.s` Conditional-Nesting State Machine

## Status

**Proposed, not yet approved.** WP95 builds the `cond.s` state machine
(the WP93-frozen D3/D4 stack + decision bitmap) and a standalone
`test_casm_cond` unit harness that drives it directly — the
`test_casm_scope` (Phase 14 WP88) precedent. **No `casm.s` / `parser.s`
integration and no `.if`/`.else`/`.endif` statement handling** — those
are WP96 (which also adds the `condScanSuppressedLine` scanner, the
`.if EXPR` truthiness eval, and the production fixtures). `casm.s` gets
exactly one new call this WP: `condResetForPass` at the top of each pass,
harmless because nothing pushes a level yet.

Branch `feature/casm-phase15`; WP95 commits directly on it.

## Objective

A correct, unit-tested conditional-nesting state machine in `cond.s`:
push/pop with the emit-state and branch-taken bookkeeping, the four
structural diagnostics, the EOF check, and the Pass-1-record /
Pass-2-replay decision bitmap. Everything a WP96 pass-driver needs to
call, with the evaluation of `.if`/`.ifdef` conditions left entirely to
the caller (this module never parses or evaluates — it is handed a
1/0 decision).

## `cond.s` public API (WP95 delivers all of it)

All routines: `C` clear = OK; `C` set + `A` = `CASM_DIAG_*` on a
structural error. Registers otherwise clobbered per each routine's
doc comment. `d` below = `CasmCondDepth - 1` (current top level index).

- **`condResetForPass`** — `CasmCondDepth = 0`, `CasmCondSiteCounter =
  0`. The bitmap is *not* cleared: Pass 1 writes every bit index it will
  later read, and the site counter bounds both passes identically.
  Called by `casm.s` at the start of each pass (WP95 adds that one call).

- **`condOpenIf`** (`A` = decision: 1 = condition true / taken, 0 =
  false; `X`/`Y`/… = open location fields via module inputs
  `CasmCondOpenLoc*` set by the caller) — handles `.if` / `.ifdef` /
  `.ifndef`:
  - `CasmCondDepth == CASM_COND_MAX_DEPTH` → `C` set, `A =
    CASM_DIAG_CONDITIONAL_NESTING_OVERFLOW`.
  - else push: `parentEmitting` = (`CasmCondDepth == 0`) ? 1 :
    `CasmCondEmitting[d_old]`. `CasmCondParentEmitting[d_new] =
    parentEmitting`. `CasmCondEmitting[d_new] = parentEmitting AND
    decision`. `CasmCondBranchTaken[d_new] = decision`.
    `CasmCondSeenElse[d_new] = 0`. Stamp `CasmCondOpenLine*/Column/FileId
    [d_new]` from the caller's `CasmCondOpenLoc*` inputs.
    `CasmCondDepth++`.
  - The caller passes `decision = 0` for a `.if` reached while already
    suppressed (WP96's scanner) — `parentEmitting` is then 0 anyway, so
    the level is inert, and no evaluation happened.

- **`condElseif`** (`A` = decision) — `.elseif`:
  - `CasmCondDepth == 0` → `CASM_DIAG_CONDITIONAL_WITHOUT_IF`.
  - `CasmCondSeenElse[d]` → `CASM_DIAG_CONDITIONAL_ELSE_AFTER_ELSE`.
  - `priorTaken = CasmCondBranchTaken[d]`.
    `CasmCondEmitting[d] = CasmCondParentEmitting[d] AND (NOT priorTaken)
    AND decision`. `if decision: CasmCondBranchTaken[d] = 1`.

- **`condElse`** — `.else`:
  - `CasmCondDepth == 0` → `CASM_DIAG_CONDITIONAL_WITHOUT_IF`.
  - `CasmCondSeenElse[d]` → `CASM_DIAG_CONDITIONAL_ELSE_AFTER_ELSE`.
  - `CasmCondEmitting[d] = CasmCondParentEmitting[d] AND (NOT
    CasmCondBranchTaken[d])`. `CasmCondBranchTaken[d] = 1`.
    `CasmCondSeenElse[d] = 1`.

- **`condEndif`** — `.endif`:
  - `CasmCondDepth == 0` → `CASM_DIAG_CONDITIONAL_WITHOUT_IF`.
  - else `CasmCondDepth--`.

- **`condCurrentlyEmitting`** — `A = 1` if `CasmCondDepth == 0` or
  `CasmCondEmitting[d] == 1`, else `A = 0`. `C` clear always. The
  pass driver's per-statement gate.

- **`condTopParentEmitting`** — `A = 1` if `CasmCondDepth == 0` or
  `CasmCondParentEmitting[d] == 1`, else `A = 0`. WP96's scanner reads
  this to decide whether a `.elseif` at the top level can possibly
  re-enable emitting (and therefore must be evaluated) or is inert
  (decision irrelevant, skip the eval).

- **`condAtEof`** — `C` set + `A = CASM_DIAG_UNTERMINATED_CONDITIONAL`
  if `CasmCondDepth != 0`; the unclosed `.if`'s location is left in
  `CasmCondOpenLine*/Column/FileId` for level `d` for the caller's
  diagnostic. `C` clear if balanced.

- **`condSiteDecision`** (`A` = freshly-computed decision, `X` = pass
  number 1 or 2) — the Pass-1-record / Pass-2-replay bitmap:
  - `CasmCondSiteCounter >= CASM_COND_MAX_SITES` → `C` set, `A =
    CASM_DIAG_CONDITIONAL_SITE_OVERFLOW`.
  - Pass 1: write bit `CasmCondSiteCounter` of `CasmCondDecisionBitmap`
    from `A`; return `A` unchanged.
  - Pass 2: read bit `CasmCondSiteCounter`; return it in `A` (the
    passed-in `A` is ignored — Pass 2 never re-evaluates).
  - either pass: `CasmCondSiteCounter++`, `C` clear.
  - Called by WP96 once per `.if`/`.elseif`/`.ifdef`/`.ifndef` that is
    *reached while its enclosing level is emitting* — never for a
    conditional inside a suppressed region (which consumes no index in
    either pass, keeping the counter deterministic).

New module inputs (BSS in `cond.s`, set by the caller before
`condOpenIf`): `CasmCondOpenLocLineLo/Hi`, `CasmCondOpenLocColumn`,
`CasmCondOpenLocFileId` — a 4-byte staging area, copied into the
per-level arrays on push (mirrors the `CasmSymbolInsert*` WP65 pattern).

## `test_casm_cond` harness (new, `tests/src/casm_cond/`)

Drives `cond.s` directly with no lexer/parser/casm.s — the
`test_casm_scope` / `test_casm_symbols` narrow-link precedent. Cases:

1. reset → `condCurrentlyEmitting` = 1 (depth 0).
2. `condOpenIf(1)` → emitting 1; `condEndif` → depth 0, emitting 1.
3. `condOpenIf(0)` → emitting 0; `condEndif` → emitting 1.
4. `condOpenIf(0)` then `condElse` → emitting 1 (else of a not-taken);
   `condEndif`.
5. `condOpenIf(1)` then `condElse` → emitting 0 (else of a taken).
6. `.elseif` ladder: `condOpenIf(0)`, `condElseif(0)`, `condElseif(1)`
   → emitting 1, `condElse` → emitting 0 (branch already taken),
   `condEndif`.
7. nested: `condOpenIf(1)` / `condOpenIf(0)` → emitting 0;
   inner `condEndif` → emitting 1; outer `condEndif` → 1.
8. nested inside a skipped outer: `condOpenIf(0)` / `condOpenIf(1)` →
   emitting 0 (parent suppressed); inner `condElse` → still 0;
   `condEndif` × 2.
9. overflow: 16 × `condOpenIf(1)` OK, 17th → `C` set +
   `CASM_DIAG_CONDITIONAL_NESTING_OVERFLOW`.
10. `condElse` / `condElseif` / `condEndif` at depth 0 → `C` set +
    `CASM_DIAG_CONDITIONAL_WITHOUT_IF`.
11. `condOpenIf(0)`, `condElse`, `condElse` → 2nd `C` set +
    `CASM_DIAG_CONDITIONAL_ELSE_AFTER_ELSE`; same for `condElseif`
    after `condElse`.
12. `condAtEof` with depth 0 → OK; with depth 1 → `C` set +
    `CASM_DIAG_UNTERMINATED_CONDITIONAL` and the stamped location
    readable.
13. `condTopParentEmitting`: after `condOpenIf(1)` → 1; after a further
    `condOpenIf(0)` → 1 (parent of the inner is the outer, still
    emitting); after `condOpenIf(0)`/`condOpenIf(1)` → 0.
14. `condSiteDecision` round-trip: Pass 1 record `1,0,1,1,0` at sites
    0-4; reset counter (not bitmap); Pass 2 replay → same `1,0,1,1,0`;
    Pass-2 passed-in decision is ignored (pass `0` for all, still get
    the recorded bits).
15. `condSiteDecision` overflow: 512 records OK, 513th → `C` set +
    `CASM_DIAG_CONDITIONAL_SITE_OVERFLOW`.
16. **structural-scan isolation**: after `condOpenIf(0)`,
    `condCurrentlyEmitting` = 0 — assert the harness never touched a
    symbol table or evaluator (there is none linked), i.e. the module is
    self-contained. (Implicit — recorded as an explicit assertion in the
    walkthrough.)

`CASM COND: PASS` / `FAIL`, `.` / `F` per case, same shape as
`test_casm_scope`.

## Atomic Increments

1. `cond.s`: implement the eleven routines above + the `CasmCondOpenLoc*`
   staging inputs. Keep the WP93 storage layout `.assert`s; add any
   needed new ones. `.export` every routine + the new inputs.
2. `casm.s`: add `.import condResetForPass` and one `jsr condResetForPass`
   at the top of each pass (next to the `CasmCurrentScope` reset). No
   other `casm.s` change.
3. `tests/src/casm_cond/casm_cond.s` + `BUILD_TEST_CASM_COND`; wire into
   `CMakeLists.txt` (narrow link: `cond.s` + `common.inc` +
   local BSS stand-ins for anything `cond.s` transitively needs — likely
   nothing beyond `common.inc`). New `casm_phase15_test_d64`? **No** —
   WP96 creates that image; for WP95 place `test_casm_cond` on an
   existing bootable image with room (candidate: `casm_include_test.d64`,
   ~which carried the WP67 relocations). WP96's plan will move it if the
   Phase 15 image is the better home.
4. Build clean (all link configs, all 31 existing harnesses +
   `test_casm_cond`). Live VICE: `test_casm_cond` → `CASM COND: PASS`.
5. Walkthrough; commit.

## Expected Files

| File | Action |
| --- | --- |
| `src/external/casm/cond.s` | Modify — 11 routines + `CasmCondOpenLoc*` inputs + `.code` segment |
| `src/external/casm/casm.s` | Modify — `.import` + one `jsr condResetForPass` per pass |
| `tests/src/casm_cond/casm_cond.s`, `.../BUILD_TEST_CASM_COND` | Create |
| `CMakeLists.txt` | Modify — `test_casm_cond` narrow-link entry + place on a bootable test image |
| `brain/plans/2026-09-01-casm-phase15-wp95-cond-state-machine.md` | Create (this file) |
| `brain/walkthroughs/2026-09-01-casm-phase15-wp95-cond-state-machine.md` | Create |

## Stop Conditions

- Any existing `test_casm_*` harness fails, or a no-change rebuild alters
  any assembled `.ref`.
- `casm.prg` assembled output changes (the single `jsr condResetForPass`
  is behaviour-neutral: depth is already implicitly 0, and nothing reads
  the stack yet — but `casmhello`/`casmassert1` must still `COMP` OK).
- CASM MAIN cannot stay within `$7400` after adding the `cond.s` code
  (~200-300 bytes estimated).
- A state-machine rule above turns out inconsistent when WP96 wires the
  scanner — return to WP93/this plan and re-freeze, do not improvise in
  WP96.
- `test_casm_cond` overflows its own load envelope — bump per the
  round-page convention.

## Completion Gate

- `cond.s` API complete; `test_casm_cond` green live (`CASM COND: PASS`).
- All 31 existing `test_casm_*` harnesses still build and (spot-checked)
  still pass — at minimum `test_casm_pass1` / `test_casm_expr` /
  `casmhello` COMP, since `casm.s` changed.
- CASM within `$7400`; no-change rebuild stable; `casmhello` /
  `casmassert1` byte-identical.
- Walkthrough recorded; **explicit user approval** before WP96.

## Progress

- 2026-09-01: Plan drafted. Eleven-routine `cond.s` API specified with
  the exact emit-state formulae; 16-case `test_casm_cond` harness
  outlined. WP95 is state-machine + unit-harness only; `casm.s` gets one
  `condResetForPass` call and nothing else. Awaiting approval.
- 2026-09-01: **Approved. WP95 implemented.**
  - `cond.s`: nine exported routines (`condResetForPass`, `condOpenIf`,
    `condElseif`, `condElse`, `condEndif`, `condCurrentlyEmitting`,
    `condTopParentEmitting`, `condAtEof`, `condSiteDecision`) + the
    private `condElseCommonCheck` + `CasmCondOpenLoc*` staging inputs.
    Decision bitmap: `condSiteDecision` computes byte index
    `(counterLo>>3) | (counterHi?$20:0)` and bit mask `1<<(counterLo&7)`,
    Pass 1 sets/clears the bit, Pass 2 reads and returns it; overflow at
    `counterHi>=2` (= 512).
  - `casm.s`: `.import condResetForPass` + one `jsr condResetForPass` in
    each pass's setup, next to the `CasmCurrentScope` reset. No other
    change.
  - `tests/src/casm_cond/casm_cond.s` (+ `BUILD_TEST_CASM_COND`): 15
    cases (merged two sub-plan cases). Narrowest link of any casm
    harness -- `cond.s` + `common.inc` only, no VMM / OS API / other
    module. `CMakeLists.txt`: `test_casm_cond` narrow-link block,
    `TEST_PRG_SIZE 0800`, placed on `casm_include_test_d64`, removed
    from `test.d64` (dir full).
  - One harness bug found + fixed on the first live run
    (`caseNestingOverflow` counted the push loop in `X`, which
    `condOpenIf` clobbers -> moved to a memory counter).
  - **Live VICE**: `test_casm_cond` -> `CASM COND: PASS` (15 cases).
    Regression witness: `casm casmassert1.s` + `comp casmassert1.prg
    casmassert1.ref` on `CASM V0.6.0.1411` -> `FILES COMPARE OK` -- the
    two `condResetForPass` calls are behaviour-neutral.
  - Build clean, all 32 `test_casm_*` targets build, no-change rebuild
    stable. Envelope: casm CODE `$545B` -> `$55C9` (+366 B, the cond.s
    routines), BSS +7 B, RODATA unchanged. MAIN headroom under `$7400`:
    1,373 -> **1,000 bytes** -- getting tight; WP96-99 must watch it.
  - `BUILD_CASM` -> 1411.
  Walkthrough
  `brain/walkthroughs/2026-09-01-casm-phase15-wp95-cond-state-machine.md`.
  Awaiting sign-off before WP96.
