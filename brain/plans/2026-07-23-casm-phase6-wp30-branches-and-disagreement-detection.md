---
feature: casm-phase6-wp30-branches-and-disagreement-detection
created: 2026-07-23
status: complete
---

# Plan: CASM Phase 6B WP30 - Relative Branches and Pass 1/Pass 2 Disagreement Detection

## Objective

WP30 closes the two remaining items the parent Phase 6 plan assigned to it:
proving relative branches resolve correctly from real forward and backward
labels (including the out-of-range case), and implementing the internal
fatal error for a Pass 1/Pass 2 final-PC disagreement
(`CASM_DIAG_PASS_MISMATCH`, reserved since WP26/27). Direct research at
planning time found the first item needs no production code at all —
`opcodesFindOpcode` already selects `CASM_MODE_RELATIVE` for any branch
mnemonic before it ever consults `CASM_PARSER_STMT_FORCE_ABS`, and
`emitInstruction`'s `eiRelative` path already computes displacement purely
from `CasmParserStmt.VAL_LO/VAL_HI` regardless of numeric-literal or
resolved-symbol origin — so WP30's only new production code is the
disagreement check itself.

Taskwarrior: `a9a117d2-b4e5-4f5c-8df1-19239b1e4cf7`.

Prerequisite: WP29 is complete and approved (CASM `0.1.31` build 1126).
Approval of this plan is required before activation or source edits, per the
CASM `AGENTS.md` gate.

## Baseline

- CASM `0.1.31` build 1126. `casm.s`'s two-pass orchestrator (WP29) drives
  `casmRunPass` twice — `CASM_PASS_MODE_MEASURE` then `CASM_PASS_MODE_EMIT`
  — with no comparison of the two passes' results beyond each pass
  independently succeeding.
- `emit.s` exports `CasmPc`/`CasmPassMode`; no `CasmPass1FinalPc` or
  pass-agreement check exists yet.
- `CASM_DIAG_PASS_MISMATCH = $2F` (`CASM_DIAG_PHASE6B_LAST`) is reserved and
  already has real message text (`msgPassMismatch`, "CASM: PASS 1/2
  MISMATCH", wired since WP27) but is never raised anywhere.
- No fixture, Phase 4 or since, has ever used a label as a relative-branch
  target. `casmbrp1.seq`/`casmbrp2.seq`/`casmbrn1.seq`/`casmbrn2.seq`
  (Phase 4) all use raw literal addresses (`BNE $C081`, etc.) to test the
  `-128..127` boundary; confirmed by direct inspection of
  `cmake/GenerateCasmTestFixtures.cmake`.
- `opcodesFindOpcode`'s branch-mode selection (`opcodes.s:179-185`) checks
  `ofMaskHi & OF_BIT_HI_RELATIVE` and unconditionally resolves to
  `CASM_MODE_RELATIVE` *before* falling through to the `@notBranch` label,
  which is where the zero-page/absolute choice (and `FORCE_ABS`
  consultation) happens. A branch mnemonic never reaches that code at all —
  confirmed by direct inspection, not inferred.
- `emitInstruction`'s `eiRelative` path (`emit.s:121-157`, unchanged since
  Phase 4) computes `disp = CasmParserStmt.VAL_LO/HI - (CasmPc + 1)` with no
  knowledge of where `VAL_LO/HI` came from.
- MAIN currently `12137` of `12288` bytes used (151 bytes headroom, measured
  directly via `ld65 -m` at WP29's close).

## Dependency Review and Discrepancies Reconciled

1. **Relative-branch resolution from a symbol needs zero production-code
   changes — confirmed by direct inspection during this plan's drafting, not
   assumed from WP29's carried-forward note.** Both the addressing-mode
   selection (`opcodesFindOpcode`) and the displacement computation
   (`eiRelative`) were re-read line-by-line specifically for this plan.
   Neither has ever depended on `CASM_PARSER_STMT_FORCE_ABS`, resolution
   state, or operand origin for a branch mnemonic. **Resolved:** WP30 adds
   zero lines to `opcodes.s`/`emit.s`'s existing addressing/displacement
   logic; its only production code is the new disagreement check
   (Contract item 2).
2. **No fixture has ever proven this in practice, which is a real, closeable
   gap — not merely a formality.** The master plan's own high-risk section
   calls out exactly this failure class ("a forward symbol may appear
   absolute in Pass 1 and zero-page in Pass 2... possibly oscillating branch
   ranges"), and while WP28/29's `p1fwd1`/`p1back1`/`p1size1` fixtures prove
   the general FORCE_ABS mechanism for `LDA`/`JMP`-class operands, none of
   them uses a short relative branch, and no fixture has ever exercised
   `CASM_DIAG_BRANCH_OUT_OF_RANGE` against a resolved label rather than a
   literal delta. **Resolved per the user's confirmed decision:** three new
   trusted/diagnostic fixtures close this (Contract item 1).
3. **A genuine Pass 1/Pass 2 disagreement is believed unreachable through any
   legitimate CASM source today — confirmed by tracing the actual
   determinism chain, not assumed.** Every per-statement size depends only
   on: the mnemonic/directive (identical text, same file, both passes), the
   parsed `OpKind` (grammar-determined, identical both passes), and
   `CASM_PARSER_STMT_FORCE_ABS`. The last is derived from
   `CASM_EXPR_FLAG_SYMBOL_DERIVED`, which `symbolsLookup` causes to be set
   identically in both passes regardless of whether the symbol is actually
   found (`symbolsLookup` never returns `C` set for "not found" — WP27's
   frozen contract). Branch mnemonics additionally never even consult
   `FORCE_ABS` at all (item 1). So no combination of forward/backward
   reference, resolved/unresolved state, or branch/non-branch operand can
   currently produce a different size in Pass 2 than Pass 1. **Resolved:**
   this plan documents `CASM_DIAG_PASS_MISMATCH` as a defensive internal
   invariant against future defects (e.g., a later phase's macro or include
   expansion breaking this determinism), matching the master plan's own
   hedged wording ("if one can be triggered deterministically") — it
   implements the check but does not claim to demonstrate it firing through
   real CASM source, and does not search for an artificial way to corrupt
   parsing to trigger it.
4. **Positive proof the fatal path itself works still matters, and
   `casm.s` cannot be linked by any standalone test harness to get it.**
   Every existing CASM test harness (`test_casm_vmm`, `test_casm_symbols`,
   `test_casm_pass1`) deliberately excludes `casm.s`, because its `HEADER`
   segment and entry point would collide with the harness's own. Per the
   user's confirmed decision: the comparison logic (snapshot-and-compare)
   is co-located in `emit.s` — which already owns `CasmPc` and is a normal
   importable module — as an exported `CasmPass1FinalPc` cell and an
   exported `emitCheckPassAgreement` routine, so a small new standalone
   harness can poke both `CasmPc` and `CasmPass1FinalPc` directly to
   deliberately mismatched and matched values and observe the routine's
   `C`/`A` result directly, without going through any real two-pass
   assembly. `casm.s` itself only calls `emitCheckPassAgreement` at the
   right two points; it owns no comparison logic of its own.
5. **The new unit-style harness must link the same module set `emit.s`
   already pulls in, matching `test_casm_pass1`'s own precedent exactly.**
   `emit.s` already imports from `parser.s` (indirectly, via
   `parserParseExpressionValue`), which imports from `expr.s`/`symbols.s`,
   which import from `vmm_store.s`/`resources.s`; `emit.s` also imports
   `fileWrite` (`fileio.s`), `lexerNext` (`lexer.s`), and
   `CasmTokenRecord` (`state.s`) directly. None of these are exercised by
   the new harness's actual test logic (it never calls `sourceOpen`,
   `lexerInit`, or `parserParseStatement`), but `ld65` links whole object
   files, so every symbol `emit.s` references must still resolve.
   **Resolved:** the new harness's `TEST_CA65_SRCS` entry reuses
   `test_casm_pass1`'s exact source list (`fileio.s`, `source.s`, `state.s`,
   `lexer.s`, `parser.s`, `opcodes.s`, `emit.s`, `expr.s`, `diagnostics.s`,
   `resources.s`, `vmm_store.s`, `symbols.s`, `common.inc`) rather than
   attempting to hand-trim it, since that set is already proven to link
   cleanly for anything touching `emit.s`.
6. **No `resourcesInit`/cleanup call is needed by the new harness at all.**
   It never opens a file or allocates VMM (it calls neither `sourceOpen` nor
   `symbolsInit`), so — matching `test_casm_vmm`/`test_casm_symbols`'s own
   precedent for a harness with nothing to clean up — it exits via
   `DOS_EXIT` directly with no registration or cleanup path.
7. **`emitCheckPassAgreement` must not attach a stale source location to its
   diagnostic.** It fires after Pass 2 reaches `CASM_TOKEN_EOF`, by which
   point `CasmDiagLoc*` holds whatever the last real statement's location
   was — printing that would misleadingly suggest the mismatch is "at" an
   unrelated line. **Resolved:** the routine calls `diagClearLoc` on its
   failure path, matching `start`'s own precedent at entry for the same
   reason (locationless diagnostics must not inherit stale location state).
8. **MAIN growth is expected to be negligible.** WP30 adds one 2-byte BSS
   cell and one ~10-line comparison routine to `emit.s`, plus two call sites
   and one snapshot copy in `casm.s` — no new module, unlike WP27/28.
   Measured, not pre-sized, per the established WP13/19/23/24/26/27/28/29
   precedent.

## Contract / Implementation Details

1. **Three new fixtures prove relative-branch resolution from real labels,
   reusing the existing trusted-reference and diagnostic-fixture mechanisms
   exactly:**

   `tests/fixtures/casm/brfwd1.ref.hex` — forward branch to a label:

   ```text
   Source (.ORG $C000):
     BNE LOOP
     NOP
     NOP
   LOOP: RTS

   D0 opcode at $C000-$C001 (2 bytes); nextPc = $C002. NOP,NOP = 2 bytes
   ($C002-$C003). LOOP resolves to $C004. Displacement = $C004 - $C002 = +2.

   00 C0        PRG load-address header ($C000, little-endian)
   D0 02        BNE +2 (forward reference, resolved to LOOP = $C004)
   EA           NOP
   EA           NOP
   60           RTS (at $C004, defines LOOP)
   ```

   `tests/fixtures/casm/brback1.ref.hex` — backward branch to a label:

   ```text
   Source (.ORG $C000):
   LOOP: NOP
     NOP
     BNE LOOP

   LOOP defined at $C000. NOP,NOP = 2 bytes ($C000-$C001). BNE at
   $C002-$C003; nextPc = $C004. Displacement = $C000 - $C004 = -4 = $FC.

   00 C0        PRG load-address header ($C000, little-endian)
   EA           NOP (at $C000, defines LOOP)
   EA           NOP
   D0 FC        BNE -4 (backward reference, resolved to LOOP = $C000)
   ```

   `cmake/GenerateCasmTestFixtures.cmake`'s new `brrng1.seq` (diagnostic
   fixture, no trusted-reference PRG — expected to fail assembly, matching
   `casmbrp2`/`casmbrn2`'s own precedent):

   ```text
   .ORG $C000
   BNE LOOP
   <128 NOP instructions, generated via string(REPEAT "NOP\n" 128 ...)>
   LOOP: RTS
   ```

   `BNE` is 2 bytes ($C000-$C001); nextPc = $C002. 128 one-byte `NOP`s place
   `LOOP` at exactly $C002 + 128 = `$C082` — the identical, already-proven
   boundary Phase 4's `casmbrp2.seq` uses (`BNE $C082`, displacement +128,
   one past the `+127` maximum). Reusing this exact boundary value (rather
   than deriving a new one) means the expected outcome
   (`CASM_DIAG_BRANCH_OUT_OF_RANGE`) is already independently verified by
   `casmbrp2`'s own Phase 4 walkthrough; this fixture only proves the same
   boundary check still fires when the operand is a resolved label instead
   of a literal.
2. **`emit.s` gains `CasmPass1FinalPc` and `emitCheckPassAgreement`:**

   ```text
   .export CasmPass1FinalPc
   .export emitCheckPassAgreement
   .import diagClearLoc        ; new import; diagSetLocFrom{Token,Stmt} are
                                ; already imported

   .segment "BSS"
   CasmPass1FinalPc: .res 2    ; CasmPc snapshotted at the end of Pass 1

   .segment "CODE"
   ; emitCheckPassAgreement
   ; Compare CasmPc against CasmPass1FinalPc. C clear if they match; C set +
   ; A = CASM_DIAG_PASS_MISMATCH if they differ (locationless -- calls
   ; diagClearLoc first, since this failure is not "at" any specific
   ; source line).
   emitCheckPassAgreement:
       lda CasmPc
       cmp CasmPass1FinalPc
       bne ecpaMismatch
       lda CasmPc + 1
       cmp CasmPass1FinalPc + 1
       bne ecpaMismatch
       clc
       rts
   ecpaMismatch:
       jsr diagClearLoc
       lda #CASM_DIAG_PASS_MISMATCH
       sec
       rts
   ```
3. **`casm.s` gains a snapshot after Pass 1 and a check after Pass 2, no
   other orchestration change:**

   ```text
   ; Pass 1, after casmRunPass succeeds (before sourceRewind):
       jsr casmRunPass
       bcs startFatalNear
       lda CasmPc
       sta CasmPass1FinalPc
       lda CasmPc + 1
       sta CasmPass1FinalPc + 1
       jsr sourceRewind
       ...

   ; Pass 2, after casmRunPass succeeds (before emitFinalize):
       jsr casmRunPass
       bcs startFatalNear
       jsr emitCheckPassAgreement
       bcs startFatalNear
       jsr emitFinalize
       ...
   ```

   New imports: `CasmPass1FinalPc`, `emitCheckPassAgreement`. A mismatch
   routes through the existing `startFatalNear` -> `startFatal` ->
   `outputAbort` -> `exitFatal` path identically to any other Pass 2
   failure — `outputAbort` already correctly deletes whatever partial
   output Pass 2 had written by that point (WP29 confirmed this path
   works; a mismatch is just one more `C`-set case funneled through it).
4. **New standalone `tests/src/casm_passcheck/casm_passcheck.s` harness**
   proves `emitCheckPassAgreement` fires correctly in both directions,
   without any real two-pass assembly: sets `CasmPc`/`CasmPass1FinalPc`
   directly, calls `emitCheckPassAgreement`, and checks the result.
   Two fixtures:

   ```text
   pcmatch1:    CasmPc = CasmPass1FinalPc = $1234 -> expect C clear
   pcmismatch1: CasmPc = $1235, CasmPass1FinalPc = $1234 -> expect C set,
                A = CASM_DIAG_PASS_MISMATCH
   ```

## Scope

Included:

- `src/external/casm/emit.s`: `CasmPass1FinalPc` BSS cell,
  `emitCheckPassAgreement` routine, new `diagClearLoc` import.
- `src/external/casm/casm.s`: Pass 1 snapshot, Pass 2 check call, two new
  imports.
- `cmake/GenerateCasmTestFixtures.cmake`: new `brrng1.seq` diagnostic
  fixture (128-NOP generated block).
- `tests/fixtures/casm/brfwd1.ref.hex`, `brback1.ref.hex`: new
  trusted-reference manifests.
- `CMakeLists.txt`: `brfwd1`/`brback1` appended to `CASM_REF_NAMES`;
  `brrng1.seq` added to `CASM_TEST_FIXTURES`; new
  `tests/src/casm_passcheck/casm_passcheck.s` harness wired as a
  `TEST_CA65_SRCS` special case (reusing `test_casm_pass1`'s source list);
  MAIN size if the measured overflow requires it (expected negligible).
- `tests/src/casm_passcheck/casm_passcheck.s`,
  `tests/src/casm_passcheck/BUILD_TEST_CASM_PASSCHECK`: new harness.

Excluded (each requires its own dedicated plan per `AGENTS.md`, or belongs to
WP31 per WP26's own division of labor):

- the full duplicate/undefined/case-sensitivity/table-full error-fixture
  matrix through production `casm.s` — WP31's explicit scope;
- any change to `opcodesFindOpcode`'s addressing-mode selection or
  `emitInstruction`'s displacement computation — neither needs one
  (Dependency Review item 1);
- any attempt to artificially construct a real Pass 1/Pass 2 disagreement
  through legitimate CASM source — believed unreachable by design
  (Dependency Review item 3), not attempted;
- `.include` processing, listings, maps, macros — unrelated, later phases.

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-23-casm-phase6-wp30-branches-and-disagreement-detection.md` | this document |
| `src/external/casm/emit.s` | Modify: `CasmPass1FinalPc`, `emitCheckPassAgreement`, new import |
| `src/external/casm/casm.s` | Modify: Pass 1 snapshot, Pass 2 check call |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify: new `brrng1.seq` |
| `tests/fixtures/casm/brfwd1.ref.hex` | Create |
| `tests/fixtures/casm/brback1.ref.hex` | Create |
| `tests/src/casm_passcheck/casm_passcheck.s` | Create |
| `tests/src/casm_passcheck/BUILD_TEST_CASM_PASSCHECK` | Create |
| `CMakeLists.txt` | Modify: `CASM_REF_NAMES`, `CASM_TEST_FIXTURES`, `casm_passcheck` `TEST_CA65_SRCS` special case, MAIN size if needed |
| `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md` | Closeout updates |

## ABI, Storage, and Runtime Effects

- New: `CasmPass1FinalPc` (2-byte BSS, `emit.s`), `emitCheckPassAgreement`
  (exported routine, `emit.s`).
- No change to any existing exported routine's calling convention, to
  `CasmParserStmt`/`CASM_EXPR_*`/`CASM_RESOLVE_*`/`CASM_SYMBOL_*` record
  layouts, or to `opcodesFindOpcode`/`emitInstruction`'s addressing/
  displacement logic.
- `CASM_DIAG_PASS_MISMATCH` becomes reachable in production for the first
  time (previously reserved-but-unraised since WP26/27).

## Verification Plan

1. **`brfwd1`/`brback1` match their new trusted references byte-for-byte**
   in VICE (`CASM BRFWD1.S` / `COMP BRFWD1.PRG BRFWD1.REF`, and the same for
   `brback1`) — proving real Pass 2 emission of a relative branch resolved
   from a real forward and a real backward label.
2. **`brrng1` fails with `CASM_DIAG_BRANCH_OUT_OF_RANGE`** — proving the
   existing range check still fires when the branch operand is a resolved
   label rather than a literal delta, at the exact boundary already
   established by Phase 4's `casmbrp2`.
3. **`test_casm_passcheck`'s two fixtures pass**: `pcmatch1` (C clear) and
   `pcmismatch1` (C set, `A = CASM_DIAG_PASS_MISMATCH`) — the only positive
   proof the fatal path itself is wired correctly, since no real CASM
   source can reach it (Dependency Review items 3-4).
4. **Regression: the five Phase 4/5 trusted references and the three WP29
   label references (`p1fwd1`/`p1back1`/`p1size1`) still match
   byte-for-byte** — confirming the `emit.s`/`casm.s` changes altered no
   existing output.
5. Build both relocation bases and `test_image_d64`; confirm a no-change
   rebuild holds `BUILD_CASM` stable before any source edit and increments
   exactly once after.
6. Every failing case is investigated before completion is requested,
   matching every prior work package's discipline.

## Atomic Implementation Increments

1. `emit.s`: add `CasmPass1FinalPc`, `emitCheckPassAgreement`, the new
   `diagClearLoc` import. Confirm production `casm` still builds (the new
   routine has no caller yet at this point).
2. `casm.s`: add the Pass 1 snapshot and Pass 2 check call, plus the two new
   imports. Build production `casm` alone; confirm the five existing
   trusted references and the three WP29 label references still match
   byte-for-byte before adding any new fixture (an early regression gate on
   the orchestration change itself).
3. Hand-derive and write `brfwd1.ref.hex`/`brback1.ref.hex`; add `brrng1.seq`
   to `cmake/GenerateCasmTestFixtures.cmake`; append `brfwd1`/`brback1` to
   `CASM_REF_NAMES` and `brrng1` to `CASM_TEST_FIXTURES` in `CMakeLists.txt`.
4. Create `tests/src/casm_passcheck/casm_passcheck.s` +
   `BUILD_TEST_CASM_PASSCHECK`; add its `TEST_CA65_SRCS` special case
   (reusing `test_casm_pass1`'s source list); implement `pcmatch1`/
   `pcmismatch1`.
5. Build both relocation bases and `test_image_d64`; measure MAIN overflow
   (expected negligible); propose and get approval for any needed size
   increase.
6. Run the full verification matrix in VICE (ask the user): `brfwd1`,
   `brback1`, `brrng1`, `test_casm_passcheck`'s two fixtures, and the
   regression set (5 Phase 4/5 + 3 WP29 references). Record the full result
   in a walkthrough.
7. Apply the version-only completion increment, rebuild, confirm no-change
   rebuild stability, both images pass.
8. Update `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md`,
   `CHANGELOG.md`, Taskwarrior.

## Failure and Cleanup

No new failure mode beyond `CASM_DIAG_PASS_MISMATCH` itself becoming
reachable, which routes through the existing `startFatalNear` ->
`outputAbort` -> `exitFatal` path exactly like any other Pass 2 failure — no
new cleanup owner. The `test_casm_passcheck` harness registers no resource
and calls `DOS_EXIT` directly, matching `test_casm_vmm`/`test_casm_symbols`'s
precedent for a harness with nothing to clean up.

## Documentation and DOX Closeout

Update this plan, `brain/KNOWLEDGE.md` (new Phase 0C.8 section amending
0C.5-0C.7: the disagreement-check design, its "believed unreachable through
real source" finding, and the branch-fixture results), `brain/task.md`,
`wiki/tasks/casm.md`, `CHANGELOG.md`, Taskwarrior, and a new walkthrough.
`AGENTS.md` needs no change (it does not cite branch or pass-mismatch
specifics). Re-read the `src`/`external`/`casm`/`tests` DOX chain after
source edits.

## Stop Conditions

Stop if the Atomic Increment 2 regression check (five Phase 4/5 references
plus the three WP29 label references) fails after the `emit.s`/`casm.s`
changes, before any new fixture is added — that would mean the snapshot/check
wiring itself has a defect unrelated to branches. Stop if `brfwd1`/`brback1`/
`brrng1`/`test_casm_passcheck` reveal a defect whose scope or fix is not
small and well-understood enough for the user to approve fixing in place.
Stop if a further material discrepancy is found during implementation,
requiring this plan to be amended and re-approved.

## Completion Gate

WP30 is complete when: `brfwd1`/`brback1` match their trusted references
byte-for-byte, `brrng1` fails with `CASM_DIAG_BRANCH_OUT_OF_RANGE`,
`test_casm_passcheck`'s two fixtures pass, the full regression set (5 Phase
4/5 + 3 WP29 references) still matches, any measured MAIN size increase is
approved and applied, the version-only completion increment is verified, and
the user explicitly approves. This does not activate WP31 (verification,
walkthrough, and Phase 6B completion gate), which remains separately gated
per `AGENTS.md`.

## Progress

- 2026-07-23: Drafted after WP29 closed (CASM `0.1.31` build 1126). Direct
  inspection of `opcodesFindOpcode` and `eiRelative` (re-read specifically
  for this plan, not carried forward from WP29's note without re-checking)
  confirmed relative branches never consult `CASM_PARSER_STMT_FORCE_ABS` at
  all and never depend on symbol-resolution state, so WP30 needs zero
  `opcodes.s`/`emit.s` addressing-logic changes -- its only new production
  code is the Pass 1/Pass 2 disagreement check. Traced the full
  determinism chain (mnemonic/directive text, grammar-determined OpKind,
  `FORCE_ABS`'s `SYMBOL_DERIVED` derivation, `symbolsLookup`'s
  never-`C`-set contract) and concluded a real Pass 1/Pass 2 size
  disagreement is unreachable through any legitimate CASM source today --
  documented as a defensive invariant rather than a demonstrable path,
  matching the master plan's own hedged wording. Asked the user two
  questions: where the disagreement-check logic and its positive-proof unit
  test should live (given `casm.s` itself can never be linked by a
  standalone harness), and whether to add new label-based relative-branch
  fixtures given no fixture has ever used one. Per the user's confirmed
  decisions: co-locate the check in `emit.s` (which already owns `CasmPc`)
  as exported `CasmPass1FinalPc`/`emitCheckPassAgreement`, with a new
  standalone `test_casm_passcheck` unit harness proving both directions;
  and add three new branch fixtures (`brfwd1`, `brback1` as trusted
  references, `brrng1` reusing Phase 4's already-proven `casmbrp2` boundary
  with a label operand instead of a literal). Awaiting user approval before
  implementation begins.
- 2026-07-23: Approved and implemented on `feature/casm-phase6-wp30`.
  `emit.s`/`casm.s` wiring for `CasmPass1FinalPc`/`emitCheckPassAgreement`
  went in exactly as planned. `brfwd1` (the first fixture ever to use a
  forward-referenced label as a branch target) immediately exposed a real,
  previously-latent defect not anticipated by this plan: `eiRelative`
  computed the branch range check even in `CASM_PASS_MODE_MEASURE`, using
  the resolver's `$0000` placeholder for the still-unresolved forward
  reference, producing a spurious `CASM_DIAG_BRANCH_OUT_OF_RANGE` in Pass 1
  regardless of the real, in-range Pass 2 distance -- latent since Phase 4.
  Presented the exact root cause and proposed fix to the user before
  touching source, since it was a material deviation from this plan's
  scope; fixed with explicit approval by making `eiRelative`
  pass-mode-aware (mirroring the existing `CASM_DIAG_UNDEFINED_SYMBOL`
  pattern). The fix's new code pushed an existing branch past ca65's
  +/-127-byte range, fixed with a `bcc :+ / jmp eiRet / :` trampoline. User
  ran the full VICE matrix twice (round 1 caught the `brfwd1` defect; round
  2, after the fix, added a regression check against Phase 4's
  literal-target branch fixtures `casmbrp1`/`brp2`/`brn1`/`brn2`): both
  rounds confirmed "All tests pass." MAIN measured at 12191 of 12288 bytes
  (97 bytes headroom), no size increase needed. Version-only completion
  increment applied: final CASM `0.1.32` build 1130, no-change rebuild
  stable, both `image_d64` and `test_image_d64` build clean. Walkthrough:
  `brain/walkthroughs/2026-07-23-casm-phase6-wp30-branches-and-disagreement-detection.md`.
  **WP30 is complete.** WP31 is unblocked in Taskwarrior but requires its
  own dedicated plan and approval before the full duplicate/undefined/
  case-sensitivity error-fixture matrix and the Phase 6B completion gate
  are attempted.
