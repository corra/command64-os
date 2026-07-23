---
feature: casm-phase6-wp28-pass1-address-assignment
created: 2026-07-22
status: planned
---

# Plan: CASM Phase 6B WP28 - Pass 1 Address Assignment and Definitions

## Objective

WP28 builds the "Pass 1 measure engine": `CasmParserStmt` grows to carry a
force-absolute-width flag, `parser.s` gains a label-definition production,
`opcodes.s` consults the new flag before its zero-page-shrink heuristic,
`emit.s` gains a single pass-mode gate, a small necessary wiring fix lands in
`expr.s`, and `symbols.s`'s `symbolsLookup` is bound as the real resolver in
place of the always-failing stub. It is verified through a new standalone
`tests/src/casm_pass1` harness that drives `sourceOpen`/`lexerInit`/
`symbolsInit`/`parserParseStatement` directly over fixture source with
forward and backward label references -- **`casm.s` is not touched at all**.
This mirrors exactly how `vmm_store.s` (Phase 6A) and `symbols.s` (WP27) were
each built and fixture-tested before any production call site existed. WP29
wires these already-proven pieces into `casm.s`'s real two-pass orchestration
and adds real Pass 2 emission.

Taskwarrior: `712fe7af-1e41-46c9-9a19-49c2632cd15a`.

Prerequisite: WP27 is complete and approved (CASM `0.1.29` build 1113).
Approval of this plan is required before activation or source edits, per the
CASM `AGENTS.md` gate.

## Baseline

- CASM `0.1.29` build 1113. `casm.s` is still single-pass; it imports
  nothing from `symbols.s`.
- `CasmParserStmt` is 6 bytes (`common.inc` asserts `CASM_PARSER_STMT_SIZE =
  6`).
- `opcodes.s`'s three zero-page-eligible branches (`@notBranch`, `@notAbsX`,
  `@notAbsY`) each decide zero-page vs. absolute purely from
  `CasmParserStmt.ValHi == 0`; no "force absolute" concept exists anywhere in
  the file.
- `emit.s` has no `CasmPassMode`; `emitRawByte` unconditionally stages and
  (when full) flushes to the output file.
- `parser.s`'s `parserParseExpressionValue` calls `exprEvaluate` with
  `parserRejectIdentifier` (a private, unexported stub that unconditionally
  fails, ignoring all its inputs) as the resolver; `parserParseStatement` has
  no production for a leading `CASM_TOKEN_IDENTIFIER` (falls through to
  `ppsSyntaxError`).
- `expr.s`'s `exprEvaluate` identifier branch does not stage
  `CasmPtr0Lo/Hi` or `A` before invoking the resolver callback -- it has
  never needed to, since the only resolver ever bound ignores its inputs.
  `exprEvaluate` sets `CASM_EXPR_FLAG_FORCE_ABS` only on the *unresolved*
  sub-path; `CASM_EXPR_FLAG_SYMBOL_DERIVED` is set on *both* the resolved and
  unresolved paths (unconditionally, the moment the resolver call succeeds
  with `C` clear).
- `symbols.s` (WP27, complete) exports `symbolsInit`/`symbolsInsert`/
  `symbolsLookup`/`CasmSymbolVmmSlot`. `symbolsLookup`'s calling convention
  matches `exprEvaluate`'s resolver callback ABI exactly (register
  conventions, 5-byte `CASM_RESOLVE_*` view layout, carry semantics) --
  confirmed by direct comparison, not merely by the two modules' own design
  intent.

## Dependency Review and Discrepancies Reconciled

This plan was drafted after dispatching four independent research agents to
audit `casm.s`, `parser.s`, `opcodes.s`/`emit.s`, and `symbols.s`/`expr.s`
respectively against the actual current source (not against the WP26 plan's
prose). All four confirmed every mechanical claim in the WP26 freeze exactly
-- dispatch structure, `emitInit`/`emitRawByte`/`emitOrg`/`emitFlush`'s
precise behavior, the three opcode-table branches, every `CasmParserStmt`
write site, the `CasmStmtLoc*` precedent, and `symbols.s`'s exact ABI. This
gives WP28 unusually low mechanical-ambiguity risk. Two things emerged that
the WP26 freeze did not anticipate:

1. **`expr.s` itself needs a small, additive amendment -- a real gap, not
   merely unaudited.** `parserParseExpressionValue` currently stages neither
   `CasmPtr0Lo/Hi` (name pointer) nor `A` (name length) before calling
   `exprEvaluate`, because the only resolver ever bound ignores its inputs
   entirely. Tracing `exprEvaluate`'s own entry sequence found it clobbers
   `A` immediately for its own token-type dispatch (checking for a `<`/`>`
   prefix, then `NUMBER` vs. `IDENTIFIER`) -- so `A` cannot be pre-staged by
   any caller far in advance; it must be set at the exact moment the
   resolver actually runs. The only point with that property is
   `exprEvaluate`'s own `identifier:` branch, immediately before its `jsr
   callResolver` -- safe because the current token is still `IDENTIFIER` at
   that exact point (the branch's own `consumeIdentifier` call to
   `lexerNext`, which would overwrite `CasmTokenText`, has not run yet).
   **Resolved:** `expr.s`'s `identifier:` branch gains two staging lines
   (`CasmPtr0Lo/Hi = &CasmTokenText`; `A = CasmTokenRecord +
   CASM_TOKEN_REC_LENGTH`) immediately before `jsr callResolver` -- a small,
   purely additive change to a "closed" Phase 5 module, required because
   Phase 5 never had a real resolver to expose this gap. No existing
   `expr.s` behavior changes for any caller; the two new lines only affect
   state a resolver reads, and the only resolver that will ever read it is
   the one WP28 binds.
2. **A genuine correctness bug, found by reasoning through *why*
   `CASM_PARSER_STMT_FORCE_ABS` needs to exist, not merely by auditing
   existing code.** Consider `JMP LOOP` where `LOOP` is defined *later* in
   the source (a forward reference). In Pass 1, `LOOP` is not yet in the
   symbol table when this statement is reached, so `symbolsLookup` correctly
   reports "not found" -- `exprEvaluate`'s existing (frozen, Phase 5) logic
   sets `CASM_EXPR_FLAG_FORCE_ABS` only on exactly this unresolved path, so
   Pass 1 correctly sizes the operand as absolute (3 bytes). In Pass 2, the
   full symbol table already exists (Pass 1 finished defining every label
   first), so this same `JMP LOOP` now resolves successfully -- and
   `exprEvaluate`'s existing logic does **not** set `FORCE_ABS` on the
   resolved path. If `LOOP`'s real address happens to be under `$100`,
   `opcodes.s`'s existing zero-page-shrink heuristic (`ValHi == 0`) would
   legitimately pick zero-page mode for this *same* operand in Pass 2 --
   disagreeing with Pass 1's absolute-mode choice. This is exactly the
   failure mode the master plan's own high-risk section names explicitly:
   "A forward symbol may appear absolute in Pass 1 and zero-page in Pass 2,
   changing all following addresses" -- and deriving
   `CASM_PARSER_STMT_FORCE_ABS` from `CASM_EXPR_FLAG_FORCE_ABS` (only set on
   the unresolved sub-case) would not have prevented it. **Resolved:**
   `CASM_PARSER_STMT_FORCE_ABS` must instead derive from
   `CASM_EXPR_FLAG_SYMBOL_DERIVED` -- a bit `exprEvaluate` already sets
   unconditionally the moment a resolver call succeeds with `C` clear,
   regardless of whether the symbol was resolved or not. Any operand derived
   from a symbol reference at all forces absolute width, matching the master
   plan's literal wording precisely: "Symbolic operands therefore remain
   absolute-width in the base release" (no resolved/unresolved qualifier).
   This is deliberately more conservative than strictly necessary for a
   `<`/`>`-extracted operand (which is always <= 255 regardless of the full
   symbol value, so it could theoretically still use an 8-bit encoding
   safely) -- left conservative rather than special-cased, consistent with
   the master plan's own preference for simple, safe rules over precise
   optimization elsewhere (e.g. its conservative relocation-algebra scope).
3. **WP28's scope boundary, resolved by user decision.** The parent Phase 6
   plan's own phrasing splits "bind the resolver" into WP29's description
   ("Pass 2 -- resolution and emission ... bind the WP27 symbol table as the
   production resolver callback"), which would leave WP28 unable to
   meaningfully test the actual interesting case (forward/backward label
   references in operands) -- only bare label definitions. The user
   confirmed WP28 should instead bind the resolver now and verify the full
   "Pass 1 measure engine" through a dedicated standalone harness, with zero
   `casm.s` changes; WP29's scope narrows to the `casm.s` two-pass
   orchestration rewrite and real Pass 2 emission, wiring in
   already-fixture-proven pieces rather than debugging the resolver binding
   and the orchestration rewrite simultaneously.
4. **Minor documentation drift (non-blocking).** `state.s:157`'s comment
   describing the `CasmStmtLoc*` precedent says `CasmParserStmt`'s "6-byte
   size is an asserted shared ABI" -- accurate today, stale once this plan
   grows it to 7. A one-line comment fix lands alongside the growth itself.
5. **MAIN growth is expected to be modest, unlike WP27's.** `symbols.s`
   (the large new module) is already counted in the `0.1.29` baseline
   (`CASM_SRCS`'s `GLOB_RECURSE` already compiles it into production `casm`
   even with zero call sites, which is what drove WP27's 848-byte
   overflow). WP28 only adds incremental logic to already-existing
   `parser.s`/`opcodes.s`/`emit.s`/`expr.s` plus one new 32-byte BSS
   buffer (`CasmLabelName`) -- no new module. Still measured, not
   pre-sized, per the established WP13/19/23/24/26/27 precedent.

## Contract / Implementation Details

1. **`CasmParserStmt` grows from 6 to 7 bytes.** New
   `CASM_PARSER_STMT_FLAGS` byte (offset 6), bit 0 =
   `CASM_PARSER_STMT_FORCE_ABS`. `CASM_PARSER_STMT_SIZE`'s assert updates to
   7. Four write sites need the new byte initialized:
   - `ppsEmpty` (`parser.s`, the NEWLINE/EOF empty statement) -- `Flags = 0`.
   - `ppsMnemonic` (before dispatching into the operand grammar) --
     `Flags = 0`.
   - `parserParseExpressionValue` -- the production write site (see item 3).
   - The new label-statement site (`ppsLabel`, item 2) -- `Flags = 0`.
2. **Label-statement grammar (parser.s):**
   - New persistent BSS, exported from `parser.s` (following the
     `CasmStmtLoc*` precedent of keeping new state parallel to
     `CasmParserStmt` rather than growing it further): `CasmLabelName: .res
     32` (31 usable bytes + terminator, matching
     `CASM_TOKEN_TEXT_BUFFER_SIZE`), `CasmLabelNameLen: .res 1`.
   - `parser.s` gains `.import CasmTokenText` (not currently imported --
     confirmed by audit).
   - `parserParseStatement`'s dispatch: insert `cmp #CASM_TOKEN_IDENTIFIER /
     beq ppsLabel` between the existing `beq ppsMnemonic` (DIRECTIVE case)
     and the `jmp ppsSyntaxError` fallback -- the exact, confirmed insertion
     point.
   - `ppsLabel` (new): copy `CasmTokenRecord + CASM_TOKEN_REC_LENGTH` into
     `CasmLabelNameLen`; copy that many bytes from `CasmTokenText` into
     `CasmLabelName` -- **before calling `lexerNext` again**, since
     `lexerNext` overwrites `CasmTokenText` unconditionally (confirmed
     hazard, no peek API exists); call `lexerNext` once to require and
     consume `COLON` (any other token is `CASM_DIAG_SYNTAX_ERROR`); set
     `CasmParserStmt.Type = CASM_TOKEN_IDENTIFIER` (reusing the existing
     token-type-as-`Type` convention), zero
     `Subtype`/`OpKind`/`ValLo`/`ValHi`/`RegSubtype`/`Flags`; return `C`
     clear without consuming anything past the colon. The driver (the new
     test harness in WP28; `casm.s`'s real orchestration in WP29) calls
     `parserParseStatement` again for whatever follows on the same physical
     line.
3. **`parserParseExpressionValue` binds the real resolver and becomes
   pass-mode-aware:**
   - `.import CasmPassMode` (new, from `emit.s`) and `.import symbolsLookup`
     (new, from `symbols.s`).
   - Replace the `ldx #<parserRejectIdentifier / ldy #>parserRejectIdentifier`
     resolver-address setup with `ldx #<symbolsLookup / ldy #>symbolsLookup`.
     `parserRejectIdentifier` itself is deleted (no longer referenced).
   - After `exprGetResult`, before the existing `RESOLVED` check: read
     `CASM_EXPR_FLAGS` and extract `CASM_EXPR_FLAG_SYMBOL_DERIVED` into
     `CasmParserStmt + CASM_PARSER_STMT_FLAGS` as
     `CASM_PARSER_STMT_FORCE_ABS` (item 2 of the Dependency Review --
     derived from `SYMBOL_DERIVED`, not `FORCE_ABS`, and applied whether or
     not the symbol resolved). A non-symbol (plain numeric) primary leaves
     `SYMBOL_DERIVED` clear, so `Flags` correctly stays 0 for numeric
     operands.
   - The existing `RESOLVED`-set path (copies `VAL_LO`/`VAL_HI`) is
     unchanged.
   - `pevUnresolved` is replaced with pass-mode-aware logic: read
     `CasmPassMode`. In `CASM_PASS_MODE_MEASURE`: store `ValLo = ValHi = 0`
     (a placeholder, never emitted, since `MEASURE` mode never writes
     bytes -- `Flags` was already set above), return `C` clear. In
     `CASM_PASS_MODE_EMIT`: return `C` set, `A = CASM_DIAG_UNDEFINED_SYMBOL`
     (already reserved by WP27, message text already wired by WP27's
     `diagnostics.s` fix).
4. **`opcodes.s` consults `CASM_PARSER_STMT_FORCE_ABS` at all three
   zero-page-eligible branches** (`@notBranch`, `@notAbsX`, `@notAbsY`):
   insert `lda CasmParserStmt + CASM_PARSER_STMT_FLAGS / and
   #CASM_PARSER_STMT_FORCE_ABS / bne @useAbs*` immediately before each
   branch's existing `lda ... VAL_HI` check, so a set flag forces the
   absolute path unconditionally without even consulting `ValHi`.
5. **`emit.s` gains `CasmPassMode` and a single gate.** New BSS:
   `CasmPassMode: .res 1`, in the existing `BSS` segment alongside `CasmPc`/
   `CasmOrgSet`/etc. New `common.inc` constants (placed in a new "Phase 6B
   two-pass contract (WP28)" section immediately after WP27's symbol-table
   section): `CASM_PASS_MODE_MEASURE = $00`, `CASM_PASS_MODE_EMIT = $01`.
   `emitRawByte` gains exactly two new lines at its very top: `lda
   CasmPassMode / cmp #CASM_PASS_MODE_MEASURE / beq <return C clear>` --
   before `ldx CasmEmitLen` (confirmed safe: nothing precedes that line
   today, so nothing is skipped by inserting first). No other routine in
   `emit.s` changes: `emitByte`'s `CasmPc`/overflow logic runs unconditionally
   above its call to `emitRawByte`; `emitOrg`'s two header-byte writes
   automatically no-op in `MEASURE` mode through the same single gate;
   `emitFinalize`/`emitFlush` need no change since `CasmEmitLen` never
   increments in `MEASURE` mode.
6. **`expr.s`'s `identifier:` branch gains two staging lines** (Dependency
   Review item 1): immediately before `jsr callResolver`, set `CasmPtr0Lo =
   <CasmTokenText`, `CasmPtr0Hi = >CasmTokenText`, `A = CasmTokenRecord +
   CASM_TOKEN_REC_LENGTH`. `expr.s` already imports `CasmTokenText` for its
   own numeric-parsing use, so no new import is needed.
7. **`symbolsInit` and `symbolsInsert` are called from the new test
   harness, not from `casm.s`** (WP28 does not touch `casm.s` at all, per
   the confirmed scope). The harness calls `symbolsInit` once at startup,
   then for each label-statement result (`CasmParserStmt.Type ==
   CASM_TOKEN_IDENTIFIER`) calls `symbolsInsert(CasmLabelName,
   CasmLabelNameLen, CasmPc)` before continuing to the next statement --
   `CasmPc` is read at this point, before any following instruction on the
   same line has been parsed or emitted, so the label's value is correctly
   "the address of what comes next." This exact sequencing is what WP29's
   real `casm.s` orchestration will also do, in `CASM_PASS_MODE_MEASURE`
   only.

## Scope

Included:

- `common.inc`: `CASM_PARSER_STMT_FLAGS`/`FORCE_ABS` constants and updated
  size assert; new `CASM_PASS_MODE_*` constants.
- `parser.s`: `CasmParserStmt` growth, label-statement grammar
  (`CasmLabelName`/`CasmLabelNameLen`), resolver binding swap, pass-mode-aware
  `parserParseExpressionValue`, `SYMBOL_DERIVED`-based `FORCE_ABS`
  derivation. Deletion of `parserRejectIdentifier`.
- `opcodes.s`: `FORCE_ABS` consultation at all three zero-page-eligible
  branches.
- `emit.s`: `CasmPassMode` BSS byte and the single `emitRawByte` gate.
- `expr.s`: the two-line `identifier:` branch staging fix.
- `state.s`: one-line comment correction (item 4 of Dependency Review).
- A new standalone `tests/src/casm_pass1/casm_pass1.s` fixture harness plus
  its `BUILD_TEST_CASM_PASS1` counter and a `CMakeLists.txt`
  `TEST_CA65_SRCS` special case.
- MAIN envelope measurement and a justified size proposal if needed.

Excluded (each requires its own dedicated plan per `AGENTS.md`):

- any `casm.s` change at all (the two-pass orchestration rewrite is WP29's
  entire scope);
- real Pass 2 emission or end-to-end PRG byte verification (WP29);
- relative-branch migration to consume resolved symbol values, and Pass
  1/Pass 2 disagreement detection (`CASM_DIAG_PASS_MISMATCH`) -- both WP30;
- `.include` processing, listings, maps, macros (unrelated, later phases).

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-22-casm-phase6-wp28-pass1-address-assignment.md` | this document |
| `src/external/casm/common.inc` | Modify: `CASM_PARSER_STMT_FLAGS`/`FORCE_ABS`, size assert, `CASM_PASS_MODE_*` |
| `src/external/casm/parser.s` | Modify: grammar, resolver binding, pass-mode logic (item 2-3 above) |
| `src/external/casm/opcodes.s` | Modify: `FORCE_ABS` consultation (3 sites) |
| `src/external/casm/emit.s` | Modify: `CasmPassMode` BSS + single gate |
| `src/external/casm/expr.s` | Modify: 2-line staging fix in `identifier:` |
| `src/external/casm/state.s` | Modify: 1-line comment correction |
| `tests/src/casm_pass1/casm_pass1.s` | Create: fixture driver |
| `tests/src/casm_pass1/BUILD_TEST_CASM_PASS1` | Create: build counter |
| `CMakeLists.txt` | Add `casm_pass1` special case to `TEST_CA65_SRCS`; MAIN size if needed |
| `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md` | Closeout updates |

`casm.s` is deliberately absent from this table.

## ABI, Storage, and Runtime Effects

- `CASM_PARSER_STMT_SIZE`: 6 -> 7 (a stable-ABI amendment, exactly the kind
  `AGENTS.md` requires an approved plan for -- this is that plan).
- New: `CasmLabelName`/`CasmLabelNameLen` (parser.s), `CasmPassMode`
  (emit.s), `CASM_PASS_MODE_*` constants.
- `parserRejectIdentifier` is removed; nothing else imports it (confirmed).
- No change to the Phase 5 `CASM_EXPR_*`/`CASM_RESOLVE_*` record layouts
  themselves -- only two new lines in `exprEvaluate`'s existing control
  flow, and only `parser.s`'s consumption of the existing `SYMBOL_DERIVED`
  bit changes.
- No change to `vmm_store.s`/`resources.s`/`symbols.s`'s own ABIs.

## Verification Plan

Fixtures in `test_casm_pass1` (sequential, driving `sourceOpen`/
`lexerInit`/`symbolsInit` once, then `parserParseStatement` in a loop over
each fixture source, dispatching label-statements to `symbolsInsert` and
mnemonic/directive statements to `opcodesFindOpcode`/`emitInstruction`/
`emitDirective` with `CasmPassMode = CASM_PASS_MODE_MEASURE`, checking final
`CasmPc` and/or specific `CasmInsn`/`CasmParserStmt` fields per case):

1. `p1label1` -- a bare label statement (`LOOP:` alone) is accepted, defines
   a symbol at the current `CasmPc`, and does not itself advance `CasmPc`.
2. `p1labelinsn1` -- `LOOP: NOP` on one line: the label defines correctly,
   then `NOP` parses and sizes as its own following statement, on the same
   physical line, with no `NEWLINE` between them.
3. `p1fwd1` -- a forward reference (`JMP LOOP` before `LOOP:`'s definition)
   sizes as absolute (3 bytes) even though the resolver reports "not found"
   at the point it's processed; verify `CASM_PARSER_STMT_FORCE_ABS` was set
   and no diagnostic fired (`MEASURE` mode tolerates it).
4. `p1back1` -- a backward reference (`JMP LOOP` after `LOOP:`, `LOOP`'s
   address low, e.g. under `$100`) resolves successfully AND still sizes as
   absolute (proving the `SYMBOL_DERIVED`-based force-abs derivation, item 2
   of the Dependency Review -- this is the fixture that would have caught
   the bug this plan found if `FORCE_ABS` had incorrectly derived from
   `CASM_EXPR_FLAG_FORCE_ABS` instead).
5. `p1undef1` -- a genuinely undefined symbol reference is tolerated (not a
   fixture failure) in `MEASURE` mode: `C` clear, placeholder value, force-abs
   set. (A real "still undefined at Pass 2" failure path belongs to WP29,
   which has a real Pass 2 to test it against.)
6. `p1dup1` -- two label definitions with the same name: the second
   `symbolsInsert` call returns `CASM_DIAG_DUPLICATE_SYMBOL`, and the harness
   confirms this propagates as a fixture-visible failure signal (not
   silently ignored).
7. `p1size1` -- a short representative program (a handful of instructions,
   a forward and a backward reference, `.byte`/`.word` directives) measures
   to a specific, hand-verified final `CasmPc`, confirming the whole
   dispatch loop (label handling + instruction sizing + directive sizing)
   produces a correct total size with nothing emitted (no output file
   created by the harness at all -- confirming `MEASURE` mode never touches
   file output).

Build both relocation bases and `test_image_d64`; run in VICE; record the
full matrix in the walkthrough. Every failing fixture is investigated before
completion is requested, matching prior work packages' discipline.

## Atomic Implementation Increments

1. `common.inc`: add `CASM_PARSER_STMT_FLAGS`/`FORCE_ABS`, update the size
   assert to 7; add `CASM_PASS_MODE_*`. Confirm the build still succeeds for
   the (as-yet-unmodified) production `casm` target (the size-assert bump
   alone should not break anything, since nothing populates the new byte
   yet).
2. `emit.s`: add `CasmPassMode` and the single `emitRawByte` gate. Confirm
   production `casm` still builds and (if practical) spot-check that a
   trivial static fixture still assembles identically to before (the gate
   defaults to whatever `CasmPassMode`'s uninitialized value is --
   **note:** decide and document whether `emitInit` should also reset
   `CasmPassMode` to `CASM_PASS_MODE_EMIT` as a safe default, so any
   existing single-pass-style caller that never sets `CasmPassMode`
   explicitly continues to behave exactly as today, since WP28 does not
   touch `casm.s` and the production build's only caller of `emitInit`
   still expects unconditional real emission).
3. `opcodes.s`: add the three `FORCE_ABS` consultations.
4. `parser.s`: `CasmParserStmt` growth's two wholesale-init sites; the
   label-statement grammar (`CasmLabelName`/`Len`, `ppsLabel`); the resolver
   binding swap and `SYMBOL_DERIVED`-based force-abs derivation in
   `parserParseExpressionValue`; deletion of `parserRejectIdentifier`.
5. `expr.s`: the two-line `identifier:` staging fix.
6. `state.s`: the one-line comment correction.
7. Create `tests/src/casm_pass1/casm_pass1.s` + `BUILD_TEST_CASM_PASS1`; add
   the CMake special case.
8. Implement fixtures 1-7 incrementally, confirming the build after each
   small batch.
9. Build both relocation bases and `test_image_d64`; measure MAIN overflow
   (expected modest per Dependency Review item 5); propose and get approval
   for any needed size increase.
10. Run the harness in VICE (ask the user); record the dot/summary output in
    a walkthrough.
11. Apply the version-only completion increment, rebuild, confirm no-change
    rebuild stability, both images pass.
12. Update `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md`,
    `CHANGELOG.md`, Taskwarrior.

## Failure and Cleanup

The harness is not a production code path: a failing fixture prints a
failure marker and continues to the next case (matching `test_casm_vmm`/
`test_casm_symbols`'s precedent) rather than aborting, and calls `DOS_EXIT`
directly rather than through the full production cleanup contract. No new
resource-ownership concerns are introduced: `symbolsInit`'s VMM allocation
is registered exactly as it was in WP27's own harness.

## Documentation and DOX Closeout

Update this plan, `brain/KNOWLEDGE.md` (a new "CASM Phase 6B Pass 1 Contract
(Phase 0C.6, frozen)" section or an amendment to the existing Phase 0C.5
section -- decide which during implementation based on how much changed
versus what WP26 already froze), `brain/task.md`, `wiki/tasks/casm.md`,
`CHANGELOG.md`, Taskwarrior, and a new walkthrough. `AGENTS.md` needs a
one-line update: it currently cites `CasmParserStmt`'s 6-byte size as an
example of frozen ABI (in its general "treat ... as stable ABI" guidance) --
that citation becomes stale once this plan grows it to 7 and should be
corrected or generalized. Re-read the `src`/`external`/`casm`/`tests` DOX
chain after source edits.

## Stop Conditions

Stop if any fixture reveals a defect whose scope or fix isn't small and
well-understood enough for the user to approve fixing in place. Stop if the
Atomic Increment 2 question (whether `emitInit` should default
`CasmPassMode` to `EMIT`) surfaces any production-build behavior change for
the still-single-pass `casm.s` target -- that would mean the gate isn't as
inert as designed and needs its own reconciliation before proceeding. Stop
if a further material discrepancy is found during implementation, requiring
this plan to be amended and re-approved.

## Completion Gate

WP28 is complete when fixtures 1-7 pass in VICE, both images build, any
measured MAIN size is approved and applied, the version-only increment is
verified, and the user explicitly approves. This does not activate WP29,
which remains separately gated per `AGENTS.md`.

## Progress

- 2026-07-22: Drafted after WP27 closed (CASM `0.1.29` build 1113).
  Dispatched four parallel research agents to independently audit `casm.s`,
  `parser.s`, `opcodes.s`/`emit.s`, and `symbols.s`/`expr.s` against the
  actual current source; all four confirmed the WP26 freeze's mechanical
  claims exactly, with zero discrepancies on dispatch structure, write
  sites, or ABI layouts. Synthesizing their findings surfaced two things the
  freeze didn't anticipate: a small necessary wiring fix in `expr.s`
  (staging the resolver's name-pointer/length arguments, which no prior
  phase needed since only a stub resolver ever existed), and a genuine
  correctness bug in how `CASM_PARSER_STMT_FORCE_ABS` was going to be
  derived (must come from `CASM_EXPR_FLAG_SYMBOL_DERIVED`, not
  `CASM_EXPR_FLAG_FORCE_ABS`, or a resolved backward reference with a small
  address could disagree between Pass 1 and Pass 2 for a forward reference
  to the same label -- exactly the failure mode the master plan's high-risk
  section warns about). Asked the user to resolve WP28's scope boundary
  against the parent plan's ambiguous phrasing; confirmed WP28 binds the
  real resolver now and verifies everything through a new standalone
  harness with zero `casm.s` changes, deferring the orchestration rewrite
  to WP29. Awaiting user approval before implementation begins.
