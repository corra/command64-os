---
feature: casm-phase8-wp39-relocation-classification
created: 2026-07-24
status: planned
---

# Plan: CASM Phase 8 WP39 - Relocation Classification

## Objective

Implement Phase 0C.14 Contract item 3: make `CASM_EXPR_FLAG_RELOCATABLE` a
real, correctly-produced classification (today it exists in the ABI but is
never set) and derive a new `CASM_PARSER_STMT_RELOCATABLE` bit from it, at
the same `parser.s` site `CASM_PARSER_STMT_FORCE_ABS` is already derived.
This WP implements no relocation-table storage and touches no emission
site -- `emitInstruction`/`emitByteList`/`emitWordList` are unchanged.
WP40 consumes the new classification bit; this WP only makes it correct.

Taskwarrior: `4a26fc20-3fcf-4d77-b41b-a46704af1491` (unblocked by WP38's
completion).

Prerequisite: CASM Phase 8 WP38 is complete and approved (CASM `0.1.40`
build 1145, `.ORG` optional, default relocatable origin `$3400` wired).
Approval of this plan is required before activation or source edits, per
the CASM `AGENTS.md` gate.

## Baseline

- CASM `0.1.40` build 1145. MAIN headroom 128 of 13568 bytes.
- `CASM_EXPR_FLAG_RELOCATABLE` (`common.inc`) already exists inside
  `CASM_RESOLVE_FLAG_MASK` and already flows unchanged from a resolver's
  output flags into the expression result
  (`expr.s`, `resolverValid: ... ora #CASM_EXPR_FLAG_SYMBOL_DERIVED / sta
  CasmExprResultRecord + CASM_EXPR_FLAGS` -- this `ora`+`sta` already
  preserves any `RESOLVED`/`RELOCATABLE` bits the resolver itself set,
  confirmed by re-reading the exact instruction sequence, not assumed).
  It is already correctly cleared on `<` low-byte extraction and preserved
  on `>` high-byte extraction and `symbol +/- constant` addends
  (`applyExtraction`/`consumeAddend`). `symbolsLookup` never sets it --
  `symbols.s:388`'s own comment: "symbols are always absolute, never
  RELOCATABLE."
- `CasmParserStmt.Flags` (`common.inc`) has exactly one bit defined,
  `CASM_PARSER_STMT_FORCE_ABS` (bit 0); bits 1-7 are reserved, added by
  WP28 for exactly this kind of extension.
- `emitInit` (WP38) conditionally primes `CasmPc` based on `/S`
  (`CasmCliOptions & CASM_OPT_STATIC`), but nothing today records *which*
  mode was chosen anywhere queryable -- only `CasmOutputStarted`
  ("has output begun") exists, not "which kind."
- `parserParseExpressionValue` (`parser.s`) is the single shared adapter
  between `exprEvaluate` and every operand-bearing statement kind
  (instructions via `parseOperandSequence`, `.BYTE`/`.WORD` via their own
  per-element loop in `emitByteList`/`emitWordList`). It already derives
  `CASM_PARSER_STMT_FORCE_ABS` from `CASM_EXPR_FLAG_SYMBOL_DERIVED`
  unconditionally (regardless of `RESOLVED`), for the documented reason
  that an unresolved Pass 1 forward reference and its resolved Pass 2
  counterpart must classify identically.

## Dependency Review and Discrepancies Reconciled

1. **A real ordering hazard exists that neither the Phase 0C.14 freeze nor
   WP38 accounted for: for the very first statement of a no-`.ORG` source,
   if that statement is a bare instruction with a symbol operand (e.g.
   `JMP TARGET` with no leading label), its operand expression is evaluated
   *before* relocatable mode would otherwise be locked in.** Traced the
   exact call sequence: `casmRunPass` calls `parserParseStatement`, which
   for a MNEMONIC or non-`.BYTE`/`.WORD` DIRECTIVE statement calls
   `parseOperandSequence` -> `parserParseExpressionValue` -> `exprEvaluate`
   *inside the same call*, before ever returning to `casmRunPass`. Only
   after `parserParseStatement` returns does `casmRunPass` dispatch to
   `emitInstruction`, whose own `emitMarkStarted` call (WP38) is what
   commits the mode. So for a bare instruction as the first statement, the
   symbol reference in its operand is classified *before* the event that
   was supposed to decide whether classification should even apply.
   - `.BYTE`/`.WORD` do **not** have this problem: `parserParseStatement`
     defers their operands entirely (`ppsDeferOperands`, no expression
     evaluated), and `emitByteList`/`emitWordList` each call
     `emitMarkStarted` themselves *before* their own per-element
     `parserParseExpressionValue` loop begins.
   - A label (`crpLabel`) has no expression operand at all -- not affected.
   - `casmnoorg1` (WP38's own forward-reference fixture) does not exercise
     this: it starts with `START:`, a label, so `crpLabel`'s
     `emitMarkStarted` call already locks the mode before the following
     `JMP TARGET` statement's expression ever evaluates. A source starting
     directly with `JMP TARGET` (no leading label) was never fixture-tested
     and would hit the hazard.
2. **`.ORG`'s own operand is parsed through the identical
   `parserParseExpressionValue` path and can itself, per WP28's design,
   contain a symbol reference** (`CASM_OPKIND_ABSOLUTE` already covers
   symbol-derived operands, not just numeric literals -- confirmed by
   re-reading `emitOrg`'s existing kind check, which accepts either).
   `.ORG SOMELABEL` is therefore already syntactically reachable today,
   pre-WP39, and any fix that adds a blanket "commit mode before every
   expression" call must not fire for `.ORG`'s own operand: doing so would
   write the default-origin header and set `CasmOutputStarted` *before*
   `emitOrg` itself runs, causing `emitOrg` to then reject its own `.ORG`
   statement as a spurious duplicate/late `.ORG`. This is a real
   functional-regression risk, not merely a classification nicety --
   confirmed by tracing `emitOrg`'s existing `CasmOutputStarted` check.
   (The classification *value* itself would be harmless if wrong here,
   since `.ORG`'s resolved value is consumed directly by `emitOrg`, which
   never inspects `CASM_PARSER_STMT_RELOCATABLE` at all -- only the
   premature *side effect* of the commit call is the real hazard.)
3. **Resolution for items 1-2: extend `parserParseExpressionValue` to call
   `emitMarkStarted` before invoking `exprEvaluate`, skipped specifically
   when the current statement is `.ORG`** (checked via
   `CasmParserStmt.Type == CASM_TOKEN_DIRECTIVE` and
   `CasmParserStmt.Subtype == CASM_DIRECTIVE_ORG`, both already populated
   by `ppsMnemonic` before `parseOperandSequence`/`parserParseExpressionValue`
   ever runs). This closes the hazard for every statement kind uniformly
   through the one shared adapter, without duplicating the check across
   `parseOperandSequence`'s many addressing-mode branches. The four
   existing WP38 call sites (`emitInstruction`, `emitByteList`,
   `emitWordList`, `crpLabel`) remain necessary and unchanged: they still
   cover the operand-less statement shapes (implied/accumulator-mode
   instructions, bare labels) this new call cannot reach, since
   `parserParseExpressionValue` is never invoked for those.
4. **`CasmOutputStarted` alone cannot answer "is this assembly
   relocatable" for a later statement, because it does not record *which*
   path set it.** A new persisted flag is needed. Proposed:
   `CasmRelocatableMode` (`emit.s`, exported), reset to 0 in `emitInit`
   (matching `CasmPc`'s static-mode default), set to 0 by `emitOrg`'s
   `eoSet` success path (explicit `.ORG` -> static), and set to 1 by
   `emitMarkStarted`'s `emsDefault` path (implicit default -> relocatable).
   By the time any symbol reference is classified (item 3 guarantees the
   commit has already happened before `exprEvaluate` runs, for every
   statement including the first), `CasmRelocatableMode` is always a
   settled, correct value.
5. **`CASM_EXPR_FLAG_RELOCATABLE` must be derived unconditionally
   alongside `CASM_EXPR_FLAG_SYMBOL_DERIVED`, not gated on `RESOLVED`** --
   the exact same reasoning `CASM_PARSER_STMT_FORCE_ABS` already follows:
   an unresolved Pass 1 forward reference and its resolved Pass 2
   counterpart must receive identical classification, or WP40's later
   relocation-table entries could disagree between passes.
6. **Where the new classification code should live is a real module-
   boundary question, not a default.** Two options were weighed:
   - Have `expr.s` import `CasmRelocatableMode` directly from `emit.s`.
     Rejected: `expr.s` currently has zero dependency on `emit.s`, and its
     standalone harness (`test_casm_expr.s`) deliberately tests expression
     evaluation in isolation -- exactly like `casm_symbols.s`/`casm_vmm.s`
     stub `diagPrintFatal` to avoid dragging in unrelated modules,
     `test_casm_expr.s` would need its own `CasmRelocatableMode` stand-in
     symbol just to satisfy the linker (the same class of friction WP38
     just hit with `CasmCliOptions` in `test_casm_pass1`/
     `test_casm_passcheck`), for a fact that isn't actually about
     expression evaluation at all.
   - **Extend `exprEvaluate`'s existing input ABI with one more input: `A`
     = relocatable-mode flag on entry, alongside the existing `X/Y` =
     resolver address.** `parser.s` (which already imports `CasmPassMode`
     from `emit.s` -- an established precedent for this module reading
     emit-owned state) reads `CasmRelocatableMode` and passes it in at its
     one call site. Confirmed by grep that `exprEvaluate` has exactly two
     call sites total (`parser.s` and `test_casm_expr.s`), both of which
     this WP updates anyway. **Recommended and used below** -- keeps
     `expr.s` fully decoupled from `emit.s`, consistent with the existing
     module-layering discipline, and lets `test_casm_expr.s` prove the
     classification in true isolation by simply passing `A = 0` or `A = 1`
     per fixture, which is also a stronger, more direct test than an
     imported global would allow.
7. **`symbols.s` requires no change**, confirming WP37's Dependency Review
   item 5: classification is a whole-assembly-mode property applied once
   at the resolver-merge point, not a per-symbol property.
8. **No new diagnostic, no MAIN-size-affecting storage growth beyond one
   new BSS byte** (`CasmRelocatableMode`) and reuse of an already-reserved
   `CasmParserStmt.Flags` bit. Code-size growth in `parser.s`/`expr.s` is
   expected but not pre-sized, matching every prior phase's precedent.
9. **No end-to-end fixture can directly observe the classification bit
   itself** -- no relocation table or R6 footer exists until WP40, so
   `CASM_PARSER_STMT_RELOCATABLE`'s correctness is provable now only
   through a standalone harness (mirroring WP27's isolated-module-first
   precedent, explicitly named in the Phase 0C.14 freeze) plus static
   audit of the call sites. An end-to-end fixture in this WP can only prove
   the new `parserParseExpressionValue` hook doesn't regress assembly
   correctness (right bytes, no crash) for the specific ordering-hazard
   shape (bare instruction first, no `.ORG`) -- it cannot itself prove the
   classification bit's value. WP40/WP42 close this observability gap once
   the table and footer exist to inspect.

## Design Decisions for Approval

1. **`parser.s` gains a new call into `emit.s`** (`emitMarkStarted`, via
   `parserParseExpressionValue`), extending the existing precedent that
   `parser.s` already reads `CasmPassMode` from `emit.s`, now including a
   state-mutating call. `parser.s`'s file header currently describes it as
   binding `symbolsLookup` as "the production identifier resolver" but
   otherwise staying a "pure grammar module" that never itself calls
   `symbolsInsert`; this WP does not touch symbol *definition*, only reuses
   the existing, already-imported `CasmPassMode`-reading precedent for a
   second piece of `emit.s`-owned state. Recommended and used below.
2. **`exprEvaluate` gains a new input parameter** (`A` = relocatable-mode
   flag on entry) rather than `expr.s` importing `emit.s` state directly.
   Recommended and used below, per Dependency Review item 6.

## Contract to Freeze (amends Phase 0C.14)

1. New `common.inc` constant: `CASM_PARSER_STMT_RELOCATABLE = %00000010`
   (`CasmParserStmt.Flags` bit 1), with the matching single-bit and
   combined-mask asserts `CASM_PARSER_STMT_FORCE_ABS`'s constants already
   use as a template.
2. New `emit.s` exported BSS byte `CasmRelocatableMode`: reset to 0 in
   `emitInit`; set to 0 in `emitOrg`'s `eoSet` (explicit `.ORG`); set to 1
   in `emitMarkStarted`'s `emsDefault` (implicit default origin).
3. `exprEvaluate`'s documented inputs grow from "current token begins
   expression; `X/Y` = resolver address; `D` clear" to also include `A` =
   relocatable-mode flag (0 = not relocatable, nonzero = relocatable). At
   the resolver-merge point (`resolverValid`), after the existing
   `ora #CASM_EXPR_FLAG_SYMBOL_DERIVED`, conditionally
   `ora #CASM_EXPR_FLAG_RELOCATABLE` when the entry `A` was nonzero, before
   the `sta CasmExprResultRecord + CASM_EXPR_FLAGS`. Applied unconditionally
   alongside `SYMBOL_DERIVED` (Dependency Review item 5), not gated on
   `RESOLVED`.
4. `parserParseExpressionValue` (`parser.s`):
   - Before calling `exprEvaluate`: if the current statement is `.ORG`
     (`CasmParserStmt.Type == CASM_TOKEN_DIRECTIVE` and
     `.Subtype == CASM_DIRECTIVE_ORG`), skip the commit call (Dependency
     Review item 2); otherwise call `emitMarkStarted`, propagating C
     set/`CASM_DIAG_ORG_REQUIRED` on failure exactly as the four existing
     call sites do.
   - Load `A` from `CasmRelocatableMode` before calling `exprEvaluate`.
   - After the existing `CASM_PARSER_STMT_FORCE_ABS` derivation (from
     `CASM_EXPR_FLAG_SYMBOL_DERIVED`), derive
     `CASM_PARSER_STMT_RELOCATABLE` the same way from the (now correctly
     populated) `CASM_EXPR_FLAG_RELOCATABLE`, OR'd into the same
     `CasmParserStmt.Flags` store.
5. `test_casm_expr.s`'s two-call-site update (its own `exprEvaluate` call)
   gains an explicit `A` load per fixture case, plus new fixture cases
   proving the classification (item below).

## Scope

Included in WP39:

- `common.inc`: `CASM_PARSER_STMT_RELOCATABLE` and its asserts.
- `emit.s`: `CasmRelocatableMode` (export, reset, and the two commit-site
  writes in `emitOrg`/`emitMarkStarted`).
- `expr.s`: `exprEvaluate`'s new `A` input and the conditional
  `CASM_EXPR_FLAG_RELOCATABLE` OR at the resolver-merge point.
- `parser.s`: `parserParseExpressionValue`'s new `.ORG`-skipped
  `emitMarkStarted` call, `CasmRelocatableMode` read, and the new
  `CASM_PARSER_STMT_RELOCATABLE` derivation.
- `tests/src/casm_expr/casm_expr.s`: updated call site plus new fixture
  cases proving relocatable-mode classification in isolation.
- One new end-to-end fixture proving the ordering-hazard fix (bare
  instruction as the first statement, no `.ORG`, symbol operand) assembles
  correctly through real `casm.s`.
- Regression: every existing static (`.ORG`-first) and WP38 relocatable
  fixture re-confirmed byte-identical, proving the new
  `parserParseExpressionValue` hook does not change any existing output.

Excluded from WP39 (deferred to WP40 per the Phase 0C.14 breakdown):

- any change to `emitInstruction`, `emitByteList`, `emitWordList`, or
  `eiTwoByte` (the four emission sites that will eventually *consume*
  `CASM_PARSER_STMT_RELOCATABLE`);
- any relocation-table storage, VMM allocation, or capacity diagnostic;
- any R6 footer serialization;
- `symbols.s` (confirmed unaffected, Dependency Review item 7).

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-24-casm-phase8-wp39-relocation-classification.md` | this document |
| `src/external/casm/common.inc` | `CASM_PARSER_STMT_RELOCATABLE` and asserts |
| `src/external/casm/emit.s` | `CasmRelocatableMode` |
| `src/external/casm/expr.s` | `exprEvaluate` ABI extension, RELOCATABLE OR |
| `src/external/casm/parser.s` | `parserParseExpressionValue` commit call, RELOCATABLE derivation |
| `tests/src/casm_expr/casm_expr.s` | updated call site, new fixture cases |
| `cmake/GenerateCasmTestFixtures.cmake` / `CMakeLists.txt` | one new end-to-end fixture |
| `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md` (Phase 0C.16), `CHANGELOG.md` | completion records |

## ABI, Storage, and Runtime Effects

- `exprEvaluate`'s calling convention gains one input register (`A`). Both
  of its two call sites are updated in this WP; no other module calls it.
- `CasmParserStmt.Flags` gains a second defined bit (`CASM_PARSER_STMT_RELOCATABLE`,
  bit 1); no size change (already 7 bytes, `Flags` already existed).
- `emit.s` gains one new exported BSS byte (`CasmRelocatableMode`). No
  zero-page impact -- ordinary BSS, matching `CasmOutputStarted`.
- No VMM, symbol-table, or file-handle effects.

## Verification and Fixture Strategy

- `test_casm_expr` (standalone harness, isolated from `emit.s`/`casm.s`):
  new fixture cases proving `CASM_EXPR_FLAG_RELOCATABLE` is set for a
  resolved symbol reference with `A` (relocatable-mode input) nonzero, and
  clear when `A` is zero; preserved through a `symbol + constant` addend;
  cleared by `<` low-extraction; preserved by `>` high-extraction --
  mirroring WP27's isolated-module-first precedent named in the Phase
  0C.14 freeze.
- Every existing `test_casm_expr` fixture re-run with `A = 0` (the
  pre-WP39-equivalent default) and confirmed byte-for-byte identical
  results, proving the ABI extension does not change any existing case's
  outcome.
- New end-to-end fixture: a no-`.ORG` source whose first statement is a
  bare instruction with a forward symbol operand (e.g. `JMP TARGET` with
  no leading label, `TARGET:` `NOP` following), assembled and compared
  against a hand-derived trusted reference -- proves the ordering-hazard
  fix (Dependency Review items 1-3) does not break real assembly, though
  per item 9 it cannot itself observe the classification bit's value.
- Regression: every existing static fixture (`casmemit1`, `casmhello`,
  etc.) and every WP38 fixture (`casmorg1`, `casmorgexpl1`, `casmnoorg1`,
  `casmorglate1`) re-run unmodified and confirmed unchanged, including a
  fixture where `.ORG`'s own presence is the very first statement
  (confirms the new skip-check correctly identifies real `.ORG` statements
  and does not regress them).

## Atomic Implementation Increments

1. `common.inc`: add `CASM_PARSER_STMT_RELOCATABLE` and asserts.
2. `emit.s`: add `CasmRelocatableMode`, wire its three write sites
   (`emitInit` reset, `emitOrg` static, `emitMarkStarted` relocatable).
3. `expr.s`: extend `exprEvaluate`'s input contract and the resolver-merge
   OR.
4. `parser.s`: add the `.ORG`-skipped `emitMarkStarted` call and the
   `CASM_PARSER_STMT_RELOCATABLE` derivation in `parserParseExpressionValue`.
5. Update `test_casm_expr.s`'s call site and add new classification
   fixtures; add the new end-to-end fixture.
6. Build, measure MAIN headroom via `ld65 -m`, run the full regression and
   new-fixture matrix.
7. User runtime verification in the supported local emulator; record a
   walkthrough.
8. Version-only completion increment, no-change rebuild check, all three
   disk images, `brain/KNOWLEDGE.md` Phase 0C.16 entry, task/changelog
   updates, request completion approval.

## Failure and Cleanup

No new resource-ownership path. `emitMarkStarted`'s existing failure mode
(`CASM_DIAG_ORG_REQUIRED` under `/S` with no `.ORG` yet) is now reachable
one statement earlier in some cases (during operand expression evaluation
rather than at instruction-emission time), but the observable diagnostic
and location are unchanged in shape -- confirmed by reusing
`emitMarkStarted` verbatim rather than duplicating its logic.

## Documentation and DOX Closeout

Update this plan's Progress section, `brain/KNOWLEDGE.md` (new Phase 0C.16
entry amending 0C.14/0C.15), `wiki/tasks/casm.md`, `brain/task.md`,
`CHANGELOG.md`, and Taskwarrior. `AGENTS.md`'s "Treat resource cleanup,
source provenance, expression relocation class, and instruction-size
stability as foundational interfaces" line already anticipates this WP;
no wording change expected there.

## Stop Conditions

Stop if CASM Phase 8 WP38 is not complete and approved. Stop if
implementation surfaces a further material discrepancy against this
document -- in particular, if a legitimate program shape is found where
the new `parserParseExpressionValue` commit call fires at the wrong time
(beyond the `.ORG` case already accounted for), requiring this document to
be amended and re-approved.

## Completion Gate

WP39 is complete when: every fixture in the Verification and Fixture
Strategy section passes; every existing static and WP38 fixture remains
byte-identical; MAIN headroom is measured and recorded; the user completes
a runtime walkthrough; and the user explicitly approves completion,
together with the version-only increment and
`brain/KNOWLEDGE.md`/task/changelog updates.

## Progress

- 2026-07-24: Drafted after WP38's approval. Found, by tracing the exact
  call sequence from `casmRunPass` through `parserParseStatement` rather
  than assuming WP38's four commit sites were sufficient, a real ordering
  hazard: a bare instruction with a symbol operand as the very first
  statement of a no-`.ORG` source evaluates that operand's expression
  *before* any of WP38's four `emitMarkStarted` call sites would run for
  that statement, since `parserParseStatement` itself parses the operand
  inline for MNEMONIC/non-`.BYTE`/`.WORD`-DIRECTIVE statements. WP38's own
  `casmnoorg1` fixture happened not to exercise this (it starts with a
  label). Also found that `.ORG`'s own operand is parsed through the
  identical expression path and can itself reference a symbol
  (`CASM_OPKIND_ABSOLUTE` already covers symbol-derived operands per
  WP28), so a naive "commit mode before every expression" fix would cause
  `.ORG` to spuriously reject itself as a duplicate. Resolved by extending
  `parserParseExpressionValue` with a single `.ORG`-skipped
  `emitMarkStarted` call, reaching every statement kind through the one
  shared adapter. Weighed two designs for where the classification logic
  itself should live -- `expr.s` importing `emit.s` state directly, versus
  extending `exprEvaluate`'s existing input ABI -- and recommend the latter
  to keep `expr.s` and its standalone `test_casm_expr` harness fully
  decoupled from `emit.s`, matching this codebase's existing module-
  layering discipline and avoiding a repeat of WP38's `CasmCliOptions`
  stand-in-symbol friction. Both design decisions are presented for
  approval alongside this plan.
