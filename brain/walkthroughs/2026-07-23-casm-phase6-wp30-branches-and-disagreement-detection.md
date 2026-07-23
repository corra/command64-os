---
feature: casm-phase6-wp30-branches-and-disagreement-detection
created: 2026-07-23
status: complete
---

# Walkthrough: CASM Phase 6B WP30 Relative Branches and Pass 1/Pass 2 Disagreement Detection

Plan: `brain/plans/2026-07-23-casm-phase6-wp30-branches-and-disagreement-detection.md`

Taskwarrior: `a9a117d2-b4e5-4f5c-8df1-19239b1e4cf7`

## Outcome

WP30 implemented the `CASM_DIAG_PASS_MISMATCH` disagreement check
(`CasmPass1FinalPc` + `emitCheckPassAgreement` in `emit.s`, called by `casm.s`
at the end of each pass) and proved relative branches resolve correctly from
real forward and backward labels. Planning-time inspection confirmed
`opcodesFindOpcode` and `emitInstruction`'s displacement computation needed
no changes for symbol-derived branch targets — but the very first fixture
built specifically to test that claim (`brfwd1`, a *forward*-referenced
branch) immediately exposed a real, previously-latent defect: `eiRelative`
computed the `-128..127` range check even in `CASM_PASS_MODE_MEASURE`, using
the `$0000` placeholder `parser.s` stores for a still-unresolved forward
reference — producing a spurious `CASM_DIAG_BRANCH_OUT_OF_RANGE` in Pass 1
regardless of the real, in-range Pass 2 distance. This had been latent since
Phase 4 (`eiRelative` predates Phase 6B entirely) because no fixture, ever,
had used a label as a branch target until this work package. Fixed with the
same tolerate-in-MEASURE/enforce-in-EMIT pattern already used for
`CASM_DIAG_UNDEFINED_SYMBOL`. All fixtures pass in VICE after the fix,
including a full regression re-run covering the exact code path the fix
touched.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase6-wp30` |
| Branch point | `feature/casm-phase6-wp29` at `25cfa8e` |
| Baseline version | `0.1.31` build 1126 |
| Plan approval | Approved as drafted, including both confirmed decisions (co-locate the check in `emit.s` with a unit harness; add 3 new branch fixtures) |

## Dependency Review Findings, Reconciled Before Implementation

1. **Relative-branch resolution needs no `opcodes.s`/`emit.s` addressing
   changes.** `opcodesFindOpcode` resolves any branch mnemonic to
   `CASM_MODE_RELATIVE` before it ever reaches the zero-page/absolute
   decision — confirmed by direct inspection specifically for this plan.
2. **A genuine Pass 1/Pass 2 disagreement is believed unreachable through any
   legitimate CASM source** given `CASM_PARSER_STMT_FORCE_ABS`'s derivation
   and `symbolsLookup`'s never-`C`-set contract. `CASM_DIAG_PASS_MISMATCH`
   is documented as a defensive internal invariant, not a demonstrated
   user-reachable path — matching the master plan's own hedged wording.
3. **`casm.s` can never be linked by a standalone test harness** (its
   `HEADER` would collide with any harness's own), so the disagreement-check
   logic was co-located in `emit.s` (which already owns `CasmPc`) specifically
   so a new harness could get positive proof of the fatal path.

## Implementation

- `src/external/casm/emit.s`: new exported `CasmPass1FinalPc` (2-byte BSS)
  and `emitCheckPassAgreement` (compares `CasmPc` against
  `CasmPass1FinalPc`; `C` clear on match, `C` set + `CASM_DIAG_PASS_MISMATCH`
  on mismatch, clearing any stale diagnostic location first). New
  `diagClearLoc` import.
- `src/external/casm/casm.s`: snapshots `CasmPc` into `CasmPass1FinalPc`
  right after Pass 1's `casmRunPass` succeeds; calls
  `emitCheckPassAgreement` right after Pass 2's `casmRunPass` succeeds
  (before `emitFinalize`). Both route through the existing `startFatalNear`
  path on failure — no new cleanup owner.
- `cmake/GenerateCasmTestFixtures.cmake`: new `brfwd1.seq` (forward branch),
  `brback1.seq` (backward branch), `brrng1.seq` (out-of-range branch to a
  label, reusing Phase 4's `casmbrp2` boundary exactly via 128
  CMake-generated `NOP` lines).
- `tests/fixtures/casm/brfwd1.ref.hex`, `brback1.ref.hex`: new
  trusted-reference manifests, self-validated against
  `hex_manifest_to_bin.py`.
- `CMakeLists.txt`: `brfwd1`/`brback1` appended to `CASM_REF_NAMES`;
  `brfwd1.seq`/`brback1.seq`/`brrng1.seq` appended to `CASM_TEST_FIXTURES`;
  new `casm_passcheck` `TEST_CA65_SRCS` special case (reusing
  `test_casm_pass1`'s exact source list, since `emit.s` transitively
  references the same module chain regardless of which of its routines a
  harness actually exercises at runtime).
- `tests/src/casm_passcheck/casm_passcheck.s` (new): standalone unit harness,
  2 fixtures (`pcmatch1`, `pcmismatch1`) pokes `CasmPc`/`CasmPass1FinalPc`
  directly and calls `emitCheckPassAgreement` — no real two-pass assembly.
  Declares its own `CasmSourceName`/`CasmOutputName` (mirroring
  `casm_pass1.s`'s precedent, since `fileio.s`'s `outputAbort` references
  both names directly and `ld65` links whole object files). No
  `resourcesInit`/cleanup — nothing is opened or allocated.

## Bug Found During Runtime Verification (Real Defect, Not Test Infrastructure)

**`eiRelative` computed the branch range check using Pass 1's unresolved
placeholder value.** `brfwd1` (`.ORG $C000` / `BNE LOOP` / `NOP` / `NOP` /
`LOOP: RTS`) reported `BRANCH OUT OF RANGE` when it should have assembled
cleanly (LOOP resolves to $C004, displacement +2, well in range). Root
cause: `parser.s`'s `pevMeasureUnresolved` correctly tolerates an
unresolved forward reference in `CASM_PASS_MODE_MEASURE` by storing a
`$0000` placeholder, but `emitInstruction`'s `eiRelative` path computed
`displacement = $0000 - nextPc` against the real `CasmPc` regardless of
pass mode — for `brfwd1` that's `$0000 - $C002`, wildly out of the
`-128..127` range, so Pass 1 raised `CASM_DIAG_BRANCH_OUT_OF_RANGE` before
Pass 2 ever computed the real, in-range distance. This had never been
caught before because no prior fixture (Phase 4's `casmbrp1`/`brp2`/`brn1`/
`brn2` included) ever used a label — only literal addresses, which are
always immediately resolved and so never exercise the placeholder path.
`brback1` (backward reference) never triggered it either, since `LOOP` is
already resolved by the time its `BNE` is parsed. `brrng1`'s "pass" before
the fix was coincidental: it got the *right* diagnostic
(`BRANCH OUT OF RANGE`) for the *wrong* reason (Pass 1's spurious
placeholder-based error, not Pass 2's real resolved-value check) — after
the fix it still reports the same diagnostic, now for the correct reason.

Presented to the user with the exact root cause and proposed fix before
touching any source, per the material-deviation gate (the fix was not in
the approved plan's scope). Fixed, with explicit user approval, by adding
a `CasmPassMode` check to `eiRelative`: `MEASURE` mode skips the range
check entirely (the operand byte's value doesn't matter either, since
`emitRawByte`'s single gate never writes it) and falls through to the same
`emitByte` call; `EMIT` mode enforces the range exactly as before. This
mirrors the same tolerate-in-MEASURE/enforce-in-EMIT pattern already
established for `CASM_DIAG_UNDEFINED_SYMBOL`.

Applying the fix's ~6 new code bytes pushed one existing branch
(`emitInstruction`'s `bcs eiRet` immediately after `emitRequireOrg`) past
ca65's ±127-byte range — caught immediately by the assembler, fixed with a
`bcc :+ / jmp eiRet / :` trampoline, the same class of fix this codebase has
hit repeatedly (WP15's `source.s` comment, WP28's `p1size1` cleanup, WP29's
`casm.s` rewrite).

## Static Verification

- All modules assemble with zero ca65 warnings/errors after both fixes.
- MAIN measured directly via `ld65 -m`: `CODE 0x20A4` (8356) +
  `RODATA 0x090C` (2316) + `BSS 0x05EF` (1519) = 12191 of 12288 bytes —
  **97 bytes headroom, no MAIN size increase needed** (down from WP29's 107;
  the eiRelative fix plus its trampoline account for the small additional
  growth).
- Both new `.ref.hex` manifests self-validated against
  `hex_manifest_to_bin.py` before use.
- A no-change rebuild held `BUILD_CASM` stable at each intermediate step
  (1129 after the fixes, 1130 after the version bump).
- Both `image_d64` and `test_image_d64` build clean with `TEST_CASM_PASSCHECK`
  packaged alongside every prior CASM test target; `test.d64` reports 141
  blocks free.

## Runtime Verification

The user ran the full matrix from `build/test.d64` and `build/image.d64` in
VICE, in two rounds (the first surfaced the `eiRelative` defect above; the
second re-verified everything after the fix):

| Fixture | Command | Round 1 | Round 2 (post-fix) |
| --- | --- | --- | --- |
| `brfwd1` (forward branch) | `CASM BRFWD1.S` -> `COMP` vs `.REF` | **FAIL** (spurious `BRANCH OUT OF RANGE`) | pass |
| `brback1` (backward branch) | `CASM BRBACK1.S` -> `COMP` vs `.REF` | pass | pass |
| `brrng1` (out-of-range, label operand) | `CASM BRRNG1.S` | pass (coincidental reason) | pass (correct reason) |
| `TEST_CASM_PASSCHECK` | run directly | pass | pass |
| Regression: `casmemit1`/`casmhello`/`casmmodes`/`casmnum2`/`casmexprn` | `CASM` + `COMP` each | pass | pass |
| Regression: `p1fwd1`/`p1back1`/`p1size1` | `CASM` + `COMP` each | pass | pass |
| Regression: Phase 4 literal-target branches `casmbrp1`/`brp2`/`brn1`/`brn2` | `CASM` each | pass | pass |

The user confirmed both rounds: "All tests pass" (round 1, reporting the
`brfwd1` failure alongside) and "All tests pass" (round 2, full matrix
including the added Phase 4 branch-fixture regression check).

## Phase 6B Acceptance (through WP30's own scope)

Closed out in `wiki/tasks/casm.md`:

- [x] Relative branches are computed from resolved symbols (forward and
      backward, including the out-of-range boundary).
- [x] A Pass 1/Pass 2 disagreement is treated as fatal
      (`CASM_DIAG_PASS_MISMATCH`, proven via the isolated
      `test_casm_passcheck` unit harness since no real source can reach it).
- [ ] Symbol table duplicate, undefined, case-sensitive, and max-length
      behavior match the frozen contract (full matrix remains WP31).

## DOX Closeout

Root, `src`, `src/external`, `src/external/casm`, `tests` contracts
rechecked. `brain/KNOWLEDGE.md` amended with a new Phase 0C.8 section
(amending 0C.5-0C.7): the disagreement-check design, its "believed
unreachable through real source" finding, and the `eiRelative` defect and
fix. `AGENTS.md` needed no change (it does not cite branch or
pass-mismatch specifics).

## Completion Dry-Run and Final Increment (`0.1.31` -> `0.1.32`)

| Measurement | Value |
| --- | --- |
| Baseline | `0.1.31` build 1126 |
| Applied version | `0.1.32` |
| Build number | 1130 (incremented through 1127-1129 during implementation/fix iterations, then exactly once more for the version bump itself) |
| No-change rebuild | pass, held at 1130 |
| `image_d64` | pass |
| `test_image_d64` | pass |

## Approval

The user confirmed both VICE verification rounds ("All tests pass").

WP30 is complete. Taskwarrior (`a9a117d2`), `wiki/tasks/casm.md`, and
`brain/task.md` are marked done. Taskwarrior WP31 (`86d8ac7e`) is unblocked
but not yet planned in detail — it requires its own dedicated plan and
approval before the full duplicate/undefined/case-sensitivity error-fixture
matrix and the Phase 6B completion gate itself are attempted, per the CASM
`AGENTS.md` gate. The CASM Phase 6B milestone remains open.
