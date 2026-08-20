---
feature: casm-phase12-wp64-contract-freeze
created: 2026-08-13
status: approved
taskwarrior: c307441c-74ab-47a8-bb4c-e997d38bcf99
depends-on: c547c74f-5080-4f2e-b086-e4e2273b5336
---

# Plan: CASM Phase 12 WP64 - Contract Freeze (Expression Evaluator Architecture and Relocation Algebra)

## Status and Authorization

**Approved 2026-08-13.** Drafted 2026-08-13, reviewed, approved as
drafted with no changes requested. This authorizes the design work below
(Atomic Increments) and recording its output as a frozen contract in
`brain/KNOWLEDGE.md`. WP64 itself makes **no production code change**;
WP65-70 each still require their own detailed plan and separate approval
before any source edit.

Parent plan:
`brain/plans/2026-08-13-casm-phase12-constants-expanded-expressions.md`
(approved 2026-08-13). Baseline: CASM `0.2.2` build `1266`.

Three architectural decisions were confirmed with the user before drafting
this plan (see Scoping Decisions), following research that traced the
actual current implementation of `expr.s`/`symbols.s`/`reloc.s`/
`common.inc` rather than assuming behavior from names.

## Objective

Produce the complete technical contract every Phase 12 implementation WP
(WP65-70) builds against, with no production behavior change of its own:
the expression evaluator's extended architecture, exactly which
operator/operand combinations on relocatable values remain representable,
how parenthesized expressions coexist with existing indirect-addressing
syntax, the named-constant symbol-table ABI, the current-address symbol's
representation, new diagnostic numbering, and a rough envelope-size
budget. This mirrors Phase 6A (VMM Storage Foundation) and Phase 11 WP56
(contract reconciliation)'s own precedent for a design-only opening WP.

## Scoping Decisions (user-confirmed 2026-08-13)

Three architectural questions, surfaced by tracing the actual current
source rather than assumed, were resolved before drafting the technical
sections below:

1. **New arithmetic/bitwise operators apply to static operands only.**
   Confirmed by tracing `reloc.s`: the relocation table is purely a
   *location* marker (`relocRecord` records only a code offset,
   `reloc.s:83-143`) — the actual value (symbol + addend) is baked into
   the emitted bytes beforehand. A relocatable value can only ever be
   represented as one symbol plus a compile-time addend (already
   supported today, for free, via the existing addend mechanism); two
   symbols together, or a relocatable symbol combined with `*`, `/`,
   `<<`, `>>`, `&`, `|`, `^`, are not representable as a single
   relocation entry and are not semantically valid under a linear
   +delta relocation patch regardless. **Rule**: every new operator this
   phase adds only accepts static (non-relocatable) operands. A
   relocatable operand reaching a new operator is rejected with a new
   diagnostic (§ Diagnostic Numbering), never silently computed. Named
   constants and the current-address symbol can still be relocatable —
   but only through the existing symbol±addend shape, same as a label.
2. **A leading `(` is never a whole-operand parenthesized expression.**
   Confirmed by tracing `parser.s:276-414`: `parserParseOperandSpec`
   already consumes a leading `(` for 6502 indirect addressing
   (`LDA ($10,X)`) *before* the expression evaluator ever runs, and this
   claim is exclusive at that syntactic position. **Rule**: `(expr)` is
   only valid as a sub-expression after a binary operator (`1+(2+3)`);
   a parenthesized expression can never be an operand's entire content
   (`LDA (CONST+1)` stays a syntax error, indistinguishable from today's
   indirect-mode grammar at that position). No lookahead disambiguation
   is attempted — simplicity and determinism over convenience here.
3. **WP64 estimates a rough envelope-size budget now.** CASM's linked
   envelope has only 114 bytes of headroom left (21,646 of 21,760 bytes
   used — measured directly via `ld65 -m` against the current object
   set, not assumed from stale notes). Given how tight this already is
   and how much Phase 12 adds, this plan includes a rough per-sub-feature
   byte estimate (§ Envelope Budget) so a `PRG_SIZE_HEX` increase can be
   requested and approved early rather than repeatedly in small
   increments across WP65-70.

## Scope

**Included:**
- Expression evaluator architecture design (§ below).
- Relocation representability rule, formalized and ready to cite from
  WP65-70 (§ above, Scoping Decision 1).
- Parenthesization-vs-indirect-addressing rule (§ above, Scoping
  Decision 2).
- New token inventory: `*`, `/`, `<<`, `>>`, `&`, `|`, `^`, `~`, unary
  `-`, `'` (character literal delimiter), and a current-address token.
- Named-constant symbol-table ABI (new flag bit, `map.s` interaction).
- Current-address symbol's representation and relocatable classification.
- Diagnostic numbering for every new error condition this phase
  introduces, starting at `$43` (the next free slot after
  `CASM_DIAG_PHASE10_WP52_LAST = $42`).
- Rough envelope-size budget estimate and a recommended `PRG_SIZE_HEX`
  target for WP65 to request.
- Lowercase-PETSCII-convention application to every new token spelling
  and design-doc example (per
  [[reference-c64-lowercase-petscii-convention]]).
- Recording the frozen contract in `brain/KNOWLEDGE.md` (a new Phase 12
  section) so WP65-70 cite it directly rather than re-deriving it.

**Excluded:**
- Any source edit to `expr.s`, `symbols.s`, `reloc.s`, `parser.s`,
  `lexer.s`, `common.inc`, or any other production module — that's
  WP65-70's job, each against this contract.
- Character-literal *documentation* (user-facing examples) — WP69's own
  scope; WP64 only fixes the encoding rule and token.
- Finalizing exact diagnostic *message text* — WP64 assigns numbers and
  one-line meanings; exact wording is each implementing WP's own call,
  matching this project's existing diagnostic-authoring pattern.

## Expression Evaluator Architecture

**Current state** (traced directly, `expr.s:68-230`): `exprEvaluate` is a
single flat `.proc` implementing exactly `['<'|'>'] primary [('+'|'-')
NUMBER]`, where `primary` is one `NUMBER` or `IDENTIFIER` token. There is
no operator stack, no precedence table, and no sub-expression concept —
the one binary operator (the addend) is parsed by a single dedicated
helper (`exprParseAddend`, expr.s:503-541) called from exactly one call
site. This is not a localized extension point.

**Proposed architecture**: precedence-climbing (operator-precedence
parsing), not a full recursive-descent grammar rewrite — cheaper on 6502
call-stack depth than classic recursive descent for a grammar this
shallow (no more than a handful of precedence tiers), and the existing
`exprParseNumeric` numeric-literal helpers (expr.s:296-491) are reusable
as-is as the parser's leaf-token consumer. Precedence tiers (highest to
lowest binding, tentative — final ordering is this WP's own deliverable,
not fixed here):

1. Unary `-` (negation), `~` (complement) — prefix, tightest binding.
2. `*`, `/` — multiplication, division.
3. `<<`, `>>` — shifts.
4. `&` — bitwise AND.
5. `^` — bitwise XOR.
6. `|` — bitwise OR.
7. `+`, `-` — binary addition/subtraction (today's addend, generalized).

This ordering matches C-family convention (and ca65's own), minimizing
surprise for anyone porting existing 6502 source. Each new operator's
own numeric implementation (software multiply/divide routine sizing,
shift-by-N cost, etc.) belongs to WP68, not this WP — WP64 only fixes
the grammar/precedence contract WP68 implements against.

**Static-value-only enforcement**: the relocation-classification check
(today, unconditionally at `expr.s:143-154`) must move to fire *per
operator application*, not just once at the top level — every binary/
unary operator node checks both operands' `CASM_EXPR_FLAG_RELOCATABLE`
bit before combining them; if a new operator's operand is relocatable,
raise `CASM_DIAG_EXPR_RELOC_UNSUPPORTED` (§ Diagnostic Numbering) instead
of evaluating. Only the existing `+`/`-` addend tier may combine a
relocatable primary with a static addend, preserving exactly today's
behavior for that one case.

## Relocation Representability Rule

Formalized from Scoping Decision 1: **a value is only relocatable if it
is a single symbol reference (a label, a relocatable named constant, or
the current-address symbol), optionally combined with exactly one static
`+`/`-` addend.** Any other combination involving a relocatable operand
— two symbols, a symbol under `*`/`/`/`<<`/`>>`/`&`/`|`/`^`/unary
`-`/`~` — is rejected with `CASM_DIAG_EXPR_RELOC_UNSUPPORTED`. This is
strictly what the reloc-table's location-only format can represent
(§ Objective/Scoping Decision 1) — not a conservative subset chosen for
convenience, the actual ceiling.

`relocRecord`/`relocFinalize` (`reloc.s`) themselves need **no format
change** — they already only ever record "this location holds a
relocatable word," which remains true for every combination this rule
still allows. The work is entirely in the classifier (evaluator), not
the recorder.

## Parenthesization Rule

Formalized from Scoping Decision 2: parenthesized sub-expressions are
valid only when they follow a binary operator or appear as an operand to
a unary prefix operator — never as the first token of an operand.
`parserParseOperandSpec`'s existing leading-`(` handling for indirect
addressing (`parser.s:276-414`) is **untouched**; the new
precedence-climbing evaluator simply never attempts to consume a `(` as
its very first token. Concretely: `lda #const+(2*3)` is valid;
`lda (const+1)` is not (and remains, exactly as today, indirect-mode
syntax expecting `,x)` or `,y` to follow) — this needs to be one of the
first fixture pairs any implementing WP proves live, since it's the one
place old and new grammar could plausibly be confused.

## Named-Constant Symbol-Table ABI

**Current state** (`common.inc:1006-1023`, `symbols.s:246-376`): a
64-byte record with `CASM_SYMBOL_REC_FLAGS` (offset 34) defining only
`CASM_SYMBOL_FLAG_DEFINED = %00000001`; every symbol inserted today (only
via `casm.s:416`'s `crpLabel`) is by construction a label. Bits 1-7 are
free. `map.s:130-131` checks flags for *exact* equality to
`CASM_SYMBOL_FLAG_DEFINED` (a corruption guard) — this needs updating to
accept the new bit alongside `DEFINED`, not just an additive OR.

**Proposed**: add `CASM_SYMBOL_FLAG_CONSTANT = %00000010` (next free
bit). A named constant is a symbol table entry with both `DEFINED` and
`CONSTANT` set; a label has only `DEFINED`. Both share the existing
512-entry table and 128-bucket hash — no separate table, no capacity
change (WP65 to confirm this shared-capacity choice explicitly, since it
does mean constants and labels compete for the same 512-entry ceiling).
Duplicate detection (`symbolsInsert`'s existing exact-name chain-walk)
applies identically regardless of kind — redefining a constant as a
label (or vice versa) is `CASM_DIAG_DUPLICATE_SYMBOL`, same as any other
redefinition; no new diagnostic needed for that case specifically.
Circular definition (`a = b`, `b = a`) is a distinct condition
(`CASM_DIAG_EXPR_CIRCULAR`, § below) detected at the point a constant's
own defining expression resolves to itself, directly or transitively —
WP65's own design deliverable is the exact detection algorithm (a
bounded-depth walk is the obvious candidate, given the existing
`CASM_SYMBOL_MAX` bound already caps worst-case chain length).

Syntax is WP65's own deliverable (not fixed here), but per the
lowercase-PETSCII convention, examples throughout WP65's plan and any
resulting documentation use lowercase (`name = expression`), not
uppercase.

## Current-Address Symbol

A new expression primitive, tentatively spelled `*` per ca65 convention
— **note this collides with the new multiplication operator's own `*`
token**; disambiguation is purely positional (a `*` in primary/leaf
position is the current-address symbol, a `*` in binary-operator
position is multiplication), which the precedence-climbing parser's own
structure already naturally provides (a leaf-position check happens
before any binary-operator check) — no new lexer-level distinction
needed, only a parser-level one. WP66 to confirm this exact
disambiguation holds once implemented against real fixtures, particularly
at expression-start where both readings are structurally possible
(`* + 1` — current address plus one — vs. a stray leading `*` that
should be a syntax error): the rule is that a `*` in leaf/primary
position is *always* current-address, never a syntax error, since binary
multiplication can never legally start an expression.

Represented as relocatable by construction (PC-relative to load
address), following the existing `CASM_EXPR_FLAG_RELOCATABLE`-when-
`CasmRelocatableMode`-set rule — identical treatment to a label
reference, not a new classification path.

## Diagnostic Numbering

Next free slot after `CASM_DIAG_PHASE10_WP52_LAST = $42` is `$43`.
Proposed assignments (numbers and one-line meanings only; exact message
text is each implementing WP's own call, matching this project's
existing pattern):

| Code | Name | Meaning | Owning WP |
| --- | --- | --- | --- |
| `$43` | `CASM_DIAG_EXPR_CIRCULAR` | Named constant's definition is circular (directly or transitively self-referential) | WP65 |
| `$44` | `CASM_DIAG_EXPR_DIV_ZERO` | Division (or modulo, if added) by a static zero | WP68 |
| `$45` | `CASM_DIAG_EXPR_RELOC_UNSUPPORTED` | A relocatable operand reached an operator that only accepts static operands (§ Relocation Representability Rule) | WP67/68 (raised by the shared evaluator core) |

`CASM_DIAG_PHASE12_WP64_LAST = CASM_DIAG_EXPR_RELOC_UNSUPPORTED` (`$45`),
with a `.assert CASM_DIAG_PHASE12_WP64_LAST = CASM_DIAG_PHASE10_WP52_LAST
+ 3` mirroring the existing contiguity-chain style
(`common.inc:721-769`). Later WP65-70 increments may need additional
diagnostics (e.g. a distinct message for the leading-paren-as-indirect
case, if the existing indirect-mode diagnostics don't already cover it
clearly enough) — those get assigned sequentially from `$46` onward by
whichever WP first needs them, following this same table format, not
reserved speculatively here.

## Envelope Budget

Current measured usage (via direct `ld65 -m` re-link, not assumed):
CODE+RODATA+BSS = 21,646 bytes against a `$5500` (21,760-byte) cap — 114
bytes free. Rough per-sub-feature estimate (order-of-magnitude, not a
commitment any implementing WP is held to byte-for-byte):

| Sub-feature | Rough estimate | Basis |
| --- | --- | --- |
| Precedence-climbing evaluator core (replaces current flat `exprEvaluate`) | +400-700 bytes | New operator-precedence dispatch table/loop, generalized from today's single-addend special case |
| New token recognition (lexer) | +150-250 bytes | 9 new punctuation/operator tokens plus `CASM_TOKEN_COUNT` bump |
| Named constants (WP65) | +200-350 bytes | New directive parse path, `CASM_SYMBOL_FLAG_CONSTANT` handling, circular-definition check |
| Current-address symbol (WP66) | +50-100 bytes | One new primary-token case, reuses existing relocatable-classification path |
| Arithmetic/bitwise operators incl. software multiply/divide (WP68) | +500-900 bytes | 6502 has no hardware multiply/divide; shift/AND/OR/XOR are cheap, multiply/divide are the real cost |
| Character literals (WP69) | +100-200 bytes | New lexer token plus PETSCII encoding path |
| New diagnostic message strings | +150-300 bytes | ~5-8 new fixed strings at this project's existing message-table density |
| **Total rough estimate** | **+1,550-2,600 bytes** | |

**Recommendation**: request a `PRG_SIZE_HEX` bump from `$5500` to `$6000`
(+2,048 bytes, a round-page step matching this project's existing bump
convention — see the CMakeLists.txt comment trail for `casm`'s own prior
increases) as part of WP65's own plan, once WP65's actual implementation
gives a firmer number for its own slice. This is a recommendation for the
first implementing WP to request, not an action this design-only WP
takes itself.

## Atomic Increments

1. Finalize the precedence-climbing evaluator architecture: exact tier
   ordering (above is tentative), the operator/operand internal
   representation, and how `exprParseNumeric`'s existing helpers plug in
   unchanged.
2. Finalize the relocation representability rule's enforcement point
   (which layer raises `CASM_DIAG_EXPR_RELOC_UNSUPPORTED`, and confirm
   by hand-tracing at least 3 representative expressions: `label+1`
   allowed, `label*2` rejected, `1+2*3` allowed static-only).
3. Finalize the leading-paren-vs-indirect-addressing rule's exact
   grammar boundary against `parserParseOperandSpec`'s real current
   branches (`parser.s:276-414`), confirming no existing addressing-mode
   fixture's behavior changes.
4. Finalize `CASM_SYMBOL_FLAG_CONSTANT`'s bit assignment and the
   `map.s:130-131` flag-check update it requires.
5. Finalize the current-address symbol's disambiguation rule against
   real tokenizer/parser leaf-vs-operator dispatch points.
6. Finalize the diagnostic table above (numbers final; message text
   deferred to implementing WPs) and its `.assert` contiguity chain.
7. Finalize the envelope budget table and recommended `PRG_SIZE_HEX`
   target.
8. Record the complete frozen contract as a new Phase 12 section in
   `brain/KNOWLEDGE.md`, cross-referenced from this plan and the Phase 12
   governing plan.

## Expected Files

| File | Planned action |
| --- | --- |
| This plan | Approved contract-freeze record |
| `brain/KNOWLEDGE.md` | New Phase 12 section recording the frozen contract |
| `brain/task.md`, `wiki/tasks/casm.md` | Synchronized activation/completion state |

No production source file changes — this WP is design-only.

## Stop Conditions

- Any of the three Scoping-Decision rules (static-only operators, no
  leading-paren-as-operand, envelope budget approach) is found
  unworkable once traced against real fixtures during the increments
  above — stop and bring the specific conflict back for renewed
  direction rather than silently reinterpreting the rule.
- Hand-tracing (Increment 2) finds an existing shipped fixture whose
  behavior would change under the new representability rule — that's a
  Phase 12 risk-gate violation and blocks this WP's own completion until
  resolved.
- The envelope estimate, once WP65+ give firmer numbers, turns out to
  need materially more than the `$6000` recommendation — flag rather
  than silently revise upward.

## Documentation, Task, and DOX Updates

- `brain/KNOWLEDGE.md`: new Phase 12 section (Increment 8).
- `brain/task.md`, `wiki/tasks/casm.md`: activation now, completion
  summary at WP64's own close.
- No `docs/`/`wiki/casm-*.md` user-facing update — WP64 designs a
  contract for unshipped syntax; user-facing docs describe only what's
  actually usable, per this project's existing convention (see
  `docs/casm-utility.md`'s own "Not Yet Supported" section for the
  precedent of naming unshipped-but-planned syntax without documenting
  it as usable).

## Completion Gate

WP64 completes only when: the precedence-climbing architecture,
relocation representability rule, parenthesization rule, named-constant
ABI, current-address symbol design, diagnostic table, and envelope
budget are all finalized (Increments 1-7) and recorded in
`brain/KNOWLEDGE.md` (Increment 8); the three hand-traced fixtures in
Increment 2 confirm no existing shipped behavior changes; trackers are
synchronized; and the user explicitly approves the frozen contract before
WP65 begins.

## Progress

- 2026-08-13: Phase 12 governing plan approved same day. Researched the
  actual current implementation of `expr.s`, `symbols.s`, `reloc.s`, and
  `common.inc` (via sub-agent, source-grounded with file:line citations,
  not inferred from names) to establish the real architecture WP64 must
  design against. Found three load-bearing facts requiring explicit
  scoping decisions rather than silent assumption: the reloc table is
  location-only (making multi-symbol/scaled-relocatable expressions
  structurally unrepresentable, not just unimplemented), a leading `(`
  already exclusively means indirect addressing, and only 114 bytes of
  envelope headroom remain. Asked three scoping questions; user confirmed
  all three recommended defaults (static-only new operators; no
  leading-paren-as-whole-operand; WP64 estimates an envelope budget).
  Drafted this plan recording the full technical contract design as
  WP64's own deliverable.
- 2026-08-13: **User approved this plan as drafted.** Completed
  Increments 1-8: hand-verified the parenthesization rule directly
  against `parser.s:276-415` (confirmed a leading `(` is unconditionally
  consumed by `posIndirect` with no fallback path — Scoping Decision 2 is
  the only workable rule, not just a reasonable one); confirmed
  `parserParseExpressionValue` (`parser.s:492-587`) as the single shared
  integration boundary across all three operand modes, and confirmed its
  independent `FORCE_ABS` derivation doesn't interact with the new
  static-only-operator rule (a rejected relocatable operand never reaches
  a successful result); finalized the diagnostic table (`$43`-`$45`) and
  its `.assert`-contiguity style, matching `common.inc:721-769` exactly.
  Recorded the complete frozen contract as a new Phase 12 section in
  `brain/KNOWLEDGE.md` (also fixed a stale "not yet closed" sentence left
  over from Phase 11's own approval in the same edit). All 8 increments
  done. **Not yet marked complete — awaiting explicit user approval to
  close WP64**, per this project's convention (no self-declared
  completion). Once approved, WP65 (named constants) needs its own
  detailed plan before any source edit begins.
