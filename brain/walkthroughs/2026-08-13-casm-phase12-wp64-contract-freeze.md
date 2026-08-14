# CASM Phase 12 WP64 Contract Freeze Walkthrough

Status: Complete; user approved 2026-08-13
Branch: `feature/casm-phase12-wp64`
Candidate: no version/build change — WP64 is design-only, no production
source touched.

## Scope

WP64 is Phase 12's contract-freeze work package: no production code
change, but every later Phase 12 WP (WP65-70) implements against the
contract recorded here. Governing plan:
`brain/plans/2026-08-13-casm-phase12-constants-expanded-expressions.md`;
WP64's own plan:
`brain/plans/2026-08-13-casm-phase12-wp64-contract-freeze.md`.

## Static Reconciliation

Every load-bearing claim was traced directly against live source, not
assumed:

- `expr.s`'s `exprEvaluate` (expr.s:68-230) is a single flat `.proc`
  implementing exactly `['<'|'>'] primary [('+'|'-') NUMBER]` — no
  operator stack, no precedence, no parentheses.
- `reloc.s`'s relocation table (reloc.s:83-143) records only a code
  offset — the value is baked into emitted bytes beforehand
  (`emit.s:549-594`). Confirmed: a relocatable value can only ever be one
  symbol plus a static addend; two symbols or a scaled/shifted
  relocatable value are structurally unrepresentable, not just
  unimplemented.
- `symbols.s`'s symbol record (`common.inc:1006-1023`) has only
  `CASM_SYMBOL_FLAG_DEFINED` defined; bits 1-7 are free for the new
  constant-kind flag.
- A leading `(` is unconditionally consumed by
  `posOperandDispatch`/`posIndirect` (`parser.s:276-287, 374-415`) for
  6502 indirect addressing before the expression evaluator ever runs —
  no fallback path exists for treating it as a generic sub-expression
  opener. This makes Scoping Decision 2 (no leading-paren-as-whole-
  operand) the only workable rule, not just a reasonable one.
- `parserParseExpressionValue` (`parser.s:492-587`) is the single shared
  integration boundary all three operand modes call into `exprEvaluate`
  through; its independent `FORCE_ABS` derivation (from `CASM_EXPR_FLAG_
  SYMBOL_DERIVED`, separate from `RELOCATABLE`) does not interact with
  the new static-only-operator rule, since a rejected relocatable operand
  never reaches a successful result.
- Envelope headroom measured directly via `ld65 -m` re-link: 21,646 of
  21,760 (`$5500`) bytes used — 114 bytes free, confirming the WP64 plan's
  own figure.

No discrepancy was found between the plan's claims and the live source.

## Frozen Contract

Recorded in full in `brain/KNOWLEDGE.md`'s new "CASM Phase 12 WP64
Contract Freeze" section:

1. Relocation representability: one symbol ± one static addend only; any
   new operator applied to a relocatable operand is rejected with
   `CASM_DIAG_EXPR_RELOC_UNSUPPORTED` ($45), never silently computed.
2. Parenthesization: `(expr)` valid only after a binary operator, never
   as a whole operand.
3. Evaluator: precedence-climbing, replacing `exprEvaluate`'s core,
   reusing its existing leaf-token helpers unchanged. Tentative tiers
   (tightest to loosest): unary `-`/`~` → `*`/`/` → `<<`/`>>` → `&` → `^`
   → `|` → `+`/`-`; final ordering is WP67's own deliverable.
4. Named constants: new `CASM_SYMBOL_FLAG_CONSTANT = %00000010` on the
   existing 512-entry symbol table; requires `map.s:130-131`'s
   exact-flags check to accept the new bit; new `CASM_DIAG_EXPR_CIRCULAR`
   ($43) for self-referential definitions. Exact directive syntax is
   WP65's own deliverable.
5. Current-address symbol: tentatively `*`, disambiguated from
   multiplication by parser position only (leaf = current-address,
   binary-operator position = multiplication).
6. New diagnostics: `$43` circular-constant, `$44` div-by-zero (static),
   `$45` reloc-unsupported-operator. `CASM_DIAG_PHASE12_WP64_LAST = $45`.
7. Envelope: ~114 bytes free today; WP64 recommends a `$5500`→`$6000`
   `PRG_SIZE_HEX` bump as part of WP65's own plan once WP65 has a firmer
   number.
8. Lowercase-PETSCII convention applies to every new token spelling this
   phase introduces.

## Stop Conditions Checked

- No Scoping-Decision rule was found unworkable against real fixtures —
  hand-tracing (Increment 2) confirmed all three hold.
- Hand-tracing found no existing shipped fixture whose behavior would
  change under the new representability rule — no Phase 12 risk-gate
  violation.
- Envelope estimate stands at the plan's own figure; no upward revision
  needed at this time.

## Documentation and Tracker Sync

- `brain/KNOWLEDGE.md`: new Phase 12 section recorded (also fixed a stale
  "not yet closed" sentence left over from Phase 11's own approval).
- No `docs/`/`wiki/casm-*.md` update — WP64 designs a contract for
  unshipped syntax; per this project's convention, user-facing docs
  describe only what's actually usable.

## Outcome

**WP64 complete, user-approved 2026-08-13.** No production source
changed. WP65 (named constants) is next and requires its own detailed
plan and separate approval before any source edit, per
`.agents/workflows/phased-implementation-planning.md`.
