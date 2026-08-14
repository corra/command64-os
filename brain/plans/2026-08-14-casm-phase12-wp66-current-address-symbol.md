---
feature: casm-phase12-wp66-current-address-symbol
created: 2026-08-14
status: approved
taskwarrior: 074c9d56-f6d9-4d65-8de4-96421d4c21b1
depends-on: c307441c-74ab-47a8-bb4c-e997d38bcf99 (WP64, complete)
---

# Plan: CASM Phase 12 WP66 — Current-Address Symbol

## Status

**Approved 2026-08-14**, including the confirmed Scoping Decision (`name
= *` ships in this WP). Implementation of the Atomic Increments below is
now authorized. Taskwarrior task 43
(`074c9d56-f6d9-4d65-8de4-96421d4c21b1`) created, depends on WP64.

Parent plan:
`brain/plans/2026-08-13-casm-phase12-constants-expanded-expressions.md`.
Prerequisite: WP64 (contract freeze), complete and user-approved
2026-08-13 —
`brain/plans/2026-08-13-casm-phase12-wp64-contract-freeze.md`. WP66 is
listed as independent of the WP64→WP67→WP68→WP70→WP71 dependency spine
and of WP65 (named constants, already complete — see
`brain/walkthroughs/2026-08-13-casm-phase12-wp65-named-constants.md`).

## Objective

Add a current-address expression primitive, spelled `*` per WP64's
contract and ca65 convention, evaluating to the program counter CASM is
about to emit at (`CasmPc`, `emit.s:57`), relocatable by construction
following the identical treatment WP64 specifies for a label reference.
Confirmed against live source (not assumed): `exprEvaluate`
(`expr.s:68-227`) is still the flat `['<'|'>'] primary [('+'|'-')
NUMBER]` parser WP64 described, with `primary` dispatching only on
`CASM_TOKEN_NUMBER`/`CASM_TOKEN_IDENTIFIER` (`expr.s:90-92`); no `*`
token exists anywhere in the lexer today (`lexer.s:1101-1115`'s
punctuation table has no `CASM_PETSCII_ASTERISK` entry, so a bare `*` in
source currently trips `CASM_DIAG_INVALID_SOURCE_BYTE`).

Because WP67 (parentheses/precedence-climbing rewrite) and WP68
(multiplication) have not landed, there is **no live `*`-as-multiply
token yet** — WP64's own positional-disambiguation note ("leaf position
is always current-address, binary-operator position is multiplication")
is a future-proofing concern for WP67/68 to honor when they arrive, not
something WP66 itself has to build. WP66 adds `*` as a pure leaf/primary
token; a future WP67/68 evaluator rewrite must preserve WP66's
leaf-position reading as its `*`-in-primary-position case.

## Scoping Decisions (user-confirmed 2026-08-14)

One real fork this plan surfaced that neither WP64's contract nor WP65's
plan resolved (WP65 explicitly excluded the current-address symbol from
its own scope):

1. **`name = *` (a named constant defined as the current address) ships
   in WP66 — confirmed, not deferred.** Traced `ppsConstant`
   (`parser.s:291-450+`): it is a **separate, hand-rolled RHS parser**
   from `exprEvaluate` — it does not call `exprEvaluate` at all, only
   `exprParseNumeric`/`exprParseAddend` directly, with its own
   `@numeric`/`@identifier` dispatch (`parser.s:371-450`). Adding `*`
   support to `exprEvaluate` (used by every instruction/directive operand
   via `parserParseExpressionValue`, `parser.s:817-852`) does **not**
   automatically make `name = *` parse — that needs a third dispatch arm
   inside `ppsConstant` itself, plus deciding whether it resolves
   immediately (like `ppsConstant`'s numeric RHS) or defers to the
   Pass1→Pass2 resolution sweep (like its identifier RHS) — trivially
   immediate, actually, since `CasmPc` is already known the instant
   `ppsConstant` runs, with no forward-reference problem at all. A small,
   natural extension (immediate resolution, no deferred-bookmark
   plumbing needed) — leaving it out would make `*` unusable in the one
   place named constants are the norm (e.g. `bufstart = *`).

## Technical Design

**Token**: new `CASM_TOKEN_STAR = $11` (`common.inc:493`, bumping
`CASM_TOKEN_COUNT` to `$12`, with the same `PriorLast + 1` /
`.assert`-pinned contiguity style as `CASM_TOKEN_EQUALS`,
`common.inc:571-572`). New `CASM_PETSCII_ASTERISK = $2A`
(`common.inc:190-204`, unshifted PETSCII matches ASCII for this
character — same convention as every other existing punctuation
constant in that table). New `lexerPunctBytes`/`lexerPunctTypes` row
(`lexer.s:1101-1115`), appended after the existing `EQUALS` entry.

**`exprEvaluate` primary dispatch** (`expr.s:88-93`): add a third
comparison, `cmp #CASM_TOKEN_STAR / beq curAddr`, alongside the existing
NUMBER/IDENTIFIER checks. New `curAddr:` branch:

- Load `CasmPc`/`CasmPc+1` (new `.import CasmPc` from `emit.s`, which
  already `.export`s it as a plain `BSS`-segment word — no zero-page or
  ABI change needed) into `CASM_EXPR_VAL_LO/HI`.
- Set `CASM_EXPR_FLAG_RESOLVED` unconditionally (the current PC is
  always known — no forward-reference/unresolved case exists for `*`,
  unlike an identifier).
- Set `CASM_EXPR_FLAG_SYMBOL_DERIVED` unconditionally. This is the one
  place WP66 goes beyond a literal reading of "identical treatment to a
  label reference" (WP64) to reach the *effect* WP64 actually wants:
  `parserParseExpressionValue` derives `CASM_PARSER_STMT_FORCE_ABS`
  strictly from `SYMBOL_DERIVED` (`parser.s:853-860`), not from
  `RESOLVED`, and the whole point of forcing absolute width on any
  symbol-derived operand is to prevent a Pass 1/Pass 2 width
  disagreement (`parser.s:794-800`'s own rationale). `*`'s value is
  exactly as load-address-sensitive as a label's, so it needs the same
  protection even though it never goes through the resolver callback
  that normally sets this bit.
- Set `CASM_EXPR_FLAG_RELOCATABLE` iff `CasmExprRelocatableModeIn`
  (staged from caller's `A` at entry, `expr.s:69`) is nonzero — the
  identical unconditional check the identifier path applies at
  `evApplyMode` (`expr.s:180-183`), with none of the
  `CASM_SYMBOL_FLAG_CONSTANT`/`LABEL_DERIVED` gating that only applies
  to *resolved named constants* (`expr.s:161-179`) — `*` is not
  symbol-table-derived at all, so that gate doesn't apply.
- `jsr lexerNext` to advance past the `*` token, then **fall into the
  existing `consumeIdentifier` control flow** (`expr.s:191-223`:
  checks for a trailing `+`/`-` addend via `exprParseAddend`, then
  `rejectContinuation`/`applyExtraction`) rather than duplicating it —
  this is what makes `*+3`/`*-1` (a common "reserve N bytes from here"
  idiom) work for free, and reuses the addend/extraction/continuation
  logic exactly as an identifier does, since by this point `*`'s result
  record looks identical in shape to a resolved, symbol-derived
  identifier's.

No new diagnostic is needed: `*` in leaf/primary position is never a
syntax error (WP64's own framing — "a `*` in leaf/primary position is
*always* current-address, never a syntax error"), and every failure mode
downstream of the `curAddr:` branch (bad addend, unsupported
continuation, extraction) already has a diagnostic via the reused
`consumeIdentifier` path. `$44`/`$45` remain reserved for WP68 as WP64
left them (`common.inc:721-726`); WP66 raises none of them.

**`ppsConstant`**: add a third
`@primary` dispatch arm (`parser.s:372-380`) for `CASM_TOKEN_STAR`,
paralleling `@numeric` (`parser.s:382-388`) — load `CasmPc` into
`CasmConstantValueLo/Hi`, apply extraction/addend via the same
`exprParseAddend`/`exprApplyAddend` sequence `@numeric` already uses
(`parser.s:389-431`), then set `CasmConstantResolved = 1` immediately
(no `CasmConstantRef*` bookmark fields touched — mirrors the numeric
path exactly, not the deferred identifier path). `casm.s`'s
`crpConstant`/resolution sweep needs no change: a `*`-defined constant
arrives already `RESOLVED` as a numeric one would, but per the primary
`exprEvaluate` design above it must still classify as
`SYMBOL_DERIVED`/relocatable-eligible — confirm during implementation
whether `crpConstant`'s existing flag-setting for a resolved-at-parse-
time constant already threads a relocatable/label-derived bit through
correctly for this new case, or needs its own small extension (this is
the one piece of this plan not fully traced against `casm.s`'s
`crpConstant` body yet, since WP65's resolution-sweep design predates
`*` entirely — Increment 4 below verifies this directly against live
source before writing any code).

**Envelope**: WP64's own estimate for this sub-feature was +50-100 bytes
(smallest of all Phase 12 sub-features — "one new primary-token case,
reuses existing relocatable-classification path"). WP65 already bumped
`PRG_SIZE_HEX` from `$5500` to `$6000` (`CMakeLists.txt:320`); WP66 is
expected to fit inside that existing headroom without a further bump,
confirmed by a real build in Increment 6, not assumed.

## Scope

**Included:**

- `CASM_PETSCII_ASTERISK`, `CASM_TOKEN_STAR` (lexer/token table).
- `exprEvaluate`'s new `curAddr:` primary-dispatch arm (`expr.s`).
- `ppsConstant`'s new `*`-RHS dispatch arm (`parser.s`).
- New test coverage (Increment 7).

**Excluded:**

- Any parenthesization or new binary operator (WP67/68) — `*` remains
  leaf-only; nothing here anticipates the eventual `*`-as-multiply
  disambiguation beyond preserving leaf-position reading unchanged.
- Character literals (WP69).
- Any relocation-algebra verification beyond what Increment 5's own
  fixtures directly exercise — the consolidated cross-WP proof is WP70's
  job.

## Atomic Increments

1. **Token/lexer plumbing**: add `CASM_PETSCII_ASTERISK = $2A`,
   `CASM_TOKEN_STAR = $11` (bump `CASM_TOKEN_COUNT` to `$12`) with
   `.assert`-pinned contiguity in `common.inc`; new `lexerPunctBytes`/
   `lexerPunctTypes` row in `lexer.s`. Verify: existing lexer harness
   (`tests/src/casm_lexer/`) unaffected; new coverage that a bare `*`
   tokenizes as `CASM_TOKEN_STAR` and no longer trips
   `CASM_DIAG_INVALID_SOURCE_BYTE`.
2. **`exprEvaluate` primary dispatch**: implement the `curAddr:` branch
   per Technical Design above — `CasmPc` import, RESOLVED/SYMBOL_DERIVED
   unconditional, RELOCATABLE conditional on
   `CasmExprRelocatableModeIn`, fall into `consumeIdentifier`. Verify:
   existing `casm_expr` harness unaffected (pure addition, no touched
   code path for NUMBER/IDENTIFIER).
3. **`*` operand fixtures**: `.byte *`/`.word *`, `*` alone (implicit
   full-width), `<*`/`>*` extraction, `*+N`/`*-N` addend, at least one
   case both under `.STATIC` and (relocatable mode, once such a fixture
   exists in this project's convention) to confirm the RELOCATABLE bit
   comes out correctly in each mode. Verify byte-identical output
   against hand-computed expected addresses.
4. **Trace `crpConstant`/`ppsConstant`**: read `casm.s`'s `crpConstant`
   body directly (not yet traced in this plan) to confirm how a constant
   resolved-at-parse-time gets its relocatable/label-derived
   classification, and whether `*`'s SYMBOL_DERIVED-but-not-symbol-
   table-derived shape needs a small `crpConstant` extension or already
   falls out correctly. Stop and report back before Increment 5 if this
   reveals materially more work than estimated.
5. **`ppsConstant` `*`-RHS dispatch**: new `@primary` arm per Technical
   Design; `bufstart = *` fixture, including one case referencing the
   constant afterward in an operand to confirm end-to-end correctness.
6. **Build + envelope verification**: full `casm` target rebuild;
   confirm the existing `$6000` cap is not exceeded; confirm a no-change
   rebuild is stable and every pre-existing CASM fixture's output stays
   byte-identical.
7. **Test harness integration**: extend `tests/src/casm_expr/` (and
   `tests/src/casm_symbols/` if Increment 5 is in scope) rather than
   creating a new top-level harness directory — mirrors WP65's own
   precedent of extending existing harnesses (`test_casm_expr`,
   `test_casm_symbols`) rather than adding a new one, since WP66 has no
   large enough surface to justify a dedicated harness. Live-verify under
   VICE per this project's testing convention.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/common.inc` | Modify (`CASM_PETSCII_ASTERISK`, `CASM_TOKEN_STAR`, `.assert`s) |
| `src/external/casm/lexer.s` | Modify (punctuation table) |
| `src/external/casm/expr.s` | Modify (`curAddr:` primary-dispatch arm, `.import CasmPc`) |
| `src/external/casm/parser.s` | Modify (`ppsConstant` `*`-RHS arm) |
| `src/external/casm/casm.s` | Modify, only if Increment 4 finds `crpConstant` needs a small extension — otherwise untouched |
| `tests/src/casm_expr/*`, `tests/src/casm_symbols/*` | Modify (new fixtures) |
| `brain/KNOWLEDGE.md`, `brain/task.md`, `wiki/tasks/casm.md` | Modify (activation now, completion summary at close) |
| `docs/casm-utility.md`, `wiki/casm-utility.md`, `wiki/casm-programmers-reference.md` | Modify at completion — user-facing: `*` becomes real, usable syntax |

## Stop Conditions

- Any existing harness/fixture fails unexpectedly after the lexer/token
  or `exprEvaluate` changes (both are meant to be behavior-preserving for
  every existing NUMBER/IDENTIFIER path).
- Increment 4's trace of `crpConstant` reveals the `*`-RHS extension is
  materially larger than estimated (e.g. requires touching the
  Pass1→Pass2 resolution sweep after all) — stop and report before
  proceeding, rather than silently expanding scope.
- The `$6000` envelope cap is exceeded by the real build.
- A no-change rebuild changes any artifact.
- A genuinely new defect outside this WP's own scope is found — disclose
  and defer as a separate follow-up (default), unless the user directs
  an inline fix in the moment.

## Documentation, Task, and DOX Updates

- Taskwarrior: new task under Phase 12 parent, depends-on WP64.
- `brain/task.md`, `wiki/tasks/casm.md`: activation entry now; completion
  summary at close.
- `brain/KNOWLEDGE.md`: new WP66 section at close (as-built record,
  including the final answer to Scoping Decision 1).
- User-facing docs: `*` gets a short section/example alongside named
  constants, lowercase-PETSCII convention note per WP64's contract.
- `CHANGELOG.md`: entry at close.

## Completion Gate

WP66 completes only when: all increments above are implemented and
verified (existing harnesses green, new fixtures green under live VICE);
the envelope stays within the existing `$6000` cap; a completion-gate
walkthrough exists in `brain/walkthroughs/` with live evidence; all
trackers are synchronized; and the user explicitly approves closing
WP66.

## Progress

- 2026-08-14: Drafted for review. Grounded against live source via an
  Explore sub-agent plus direct follow-up reads: `expr.s:68-227`
  (`exprEvaluate`'s current primary dispatch and the `consumeIdentifier`/
  addend/extraction control flow WP66 reuses), `lexer.s:1101-1115`
  (punctuation table, confirmed no `*` token exists today),
  `common.inc:182-217,486-493,571-572,958-962` (PETSCII/token constants,
  `CASM_EXPR_FLAG_*` bits), `emit.s:44-57` (`CasmPc`, plain exported BSS
  word), `parser.s:783-860` (`parserParseExpressionValue`, confirmed
  `FORCE_ABS` derives strictly from `SYMBOL_DERIVED`), `parser.s:291-450`
  (`ppsConstant`, confirmed it is a separate hand-rolled RHS parser from
  `exprEvaluate` — surfaced Scoping Decision 1, not assumed).
  **Not yet approved.**
- 2026-08-14: User confirmed Scoping Decision 1 — `name = *` ships in
  WP66 (not deferred). Plan updated accordingly (all "iff confirmed"
  conditionals resolved to unconditional). Presenting for full-plan
  approval next.
- 2026-08-14: **User approved this plan as drafted, no changes.**
  Taskwarrior task 43 created, depends on WP64 (task/UUID
  `c307441c-74ab-47a8-bb4c-e997d38bcf99`). Parent Phase 12 governing plan
  separately amended same day to insert WP71 (DASH adoption of Phase 12
  syntax) — does not affect WP66's own scope. Implementation of
  Increment 1 begins next.
- 2026-08-14: All 7 Atomic Increments implemented and live-verified.
  Increment 4's live trace of `crpConstant` (as the plan itself called
  for, rather than assuming the numeric-RHS path could be mirrored
  as-is) found a real gap: a naive implementation would never have set
  `CASM_SYMBOL_FLAG_LABEL_DERIVED` for `name = *`, silently misclassifying
  it as static. Fixed with a new `CasmConstantIsCurAddr` staging flag
  before any of Increment 5's code was considered final. Full disk-image
  tree rebuild (Increment 6) surfaced three test-harness envelope
  overflows from shared-module growth (`test_casm_pass1`,
  `test_casm_frame`, `test_casm_include`) plus one resulting disk-
  capacity shortfall (`test_casm_freloc` relocated off
  `casm_overflow_test_d64`) — all resolved per this project's existing
  `PriorSize -> NewSize` bump convention, not scope creep. Two new live
  end-to-end fixtures (`casmcuraddr1.s`, `casmcuraddr2.s`) live-verified
  byte-exact against the real `casm.prg` binary under VICE, alongside
  regression re-verification of five existing harnesses (all PASS). Full
  completion-gate walkthrough:
  `brain/walkthroughs/2026-08-14-casm-phase12-wp66-current-address-
  symbol.md`. Documentation gap WP65's own walkthrough flagged (no
  user-facing doc update in that pass) closed for both WP65 and WP66
  together: `docs/casm-utility.md`/`wiki/casm-utility.md`/`wiki/casm-
  programmers-reference.md` updated. `brain/KNOWLEDGE.md`, `brain/
  task.md`, `wiki/tasks/casm.md`, `CHANGELOG.md` all updated. Taskwarrior
  task marked done.
- 2026-08-14: **User approved closing WP66.** WP66 complete. WP67
  (parentheses and explicit precedence) is next and requires its own
  detailed plan and separate approval before any source edit.
