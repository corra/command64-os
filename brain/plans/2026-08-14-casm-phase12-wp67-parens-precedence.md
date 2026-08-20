---
feature: casm-phase12-wp67-parens-precedence
created: 2026-08-14
status: approved
taskwarrior: 8d988ac6-730a-440a-bc6e-a12e0c36888d
depends-on: c307441c-74ab-47a8-bb4c-e997d38bcf99 (WP64, complete)
---

# Plan: CASM Phase 12 WP67 — Parentheses and Explicit Precedence

## Status

**Approved 2026-08-14**, including all three confirmed Scoping Decisions.
Implementation of the Atomic Increments below is now authorized.
Taskwarrior task 43 (`8d988ac6-730a-440a-bc6e-a12e0c36888d`) created,
depends on WP64.

Parent plan:
`brain/plans/2026-08-13-casm-phase12-constants-expanded-expressions.md`.
Prerequisite: WP64 (contract freeze), complete and user-approved
2026-08-13. WP67 is the load-bearing head of the dependency spine
(WP64 → **WP67** → WP68 → WP70 → WP71 → WP72) — WP68's new operators
(`*`, `/`, `<<`, `>>`, `&`, `|`, `^`, unary `-`/`~`) are explicitly
sequenced *after* WP67 specifically so they land against a stable,
already-shipped precedence contract rather than changing already-shipped
expression results later.

## Objective

Build the precedence-climbing expression evaluator architecture WP64
designed but did not implement, and add parenthesized sub-expression
grouping — **without** adding any of WP68's new operators. Concretely:
`1+(2+3)` becomes valid; the only binary operators reachable through it
in this WP remain `+`/`-` (today's addend, generalized into the new
architecture's own operator-precedence loop). WP68 then only has to add
table rows for its new operators against this WP's already-proven
grouping/precedence machinery, not build the machinery itself.

Confirmed against live source (not assumed): `exprEvaluate`
(`expr.s:73-293`) is still exactly the flat evaluator WP66 left it —
primary is `NUMBER`/`IDENTIFIER`/`CASM_TOKEN_STAR`, with a shared
`consumeIdentifier:` tail (`expr.s:216+`) handling addend/extraction/
continuation, and `rejectContinuation` (`expr.s:294-317`) unconditionally
rejects any trailing operator/paren token as `CASM_DIAG_EXPR_UNSUPPORTED`
— this is the exact chokepoint WP67 replaces with a real operator loop.
`CASM_TOKEN_LPAREN`/`RPAREN` already exist as tokens (`parser.s:632-633`,
consumed by `posIndirect` for 6502 indirect addressing, e.g. `LDA
($10,X)`) — WP64's own Parenthesization Rule (frozen, not reopened here)
means WP67 never touches that dispatch; the new evaluator simply never
attempts to consume a `(` as an operand's very first token.

## Scoping Decisions (user-confirmed 2026-08-14)

Two real forks this plan surfaced that WP64's contract left as WP67's
own deliverable, plus one WP64 did not anticipate at all — all three
confirmed as recommended, no changes:

1. **Final precedence-tier ordering — confirmed: adopt WP64's proposed
   tentative ordering as-is** (unary `-`/`~` tightest; `*`,`/`;
   `<<`,`>>`; `&`; `^`; `|`; `+`,`-` loosest), which WP64 had left as
   "WP67's own deliverable, not fixed" (`brain/KNOWLEDGE.md`'s WP64
   section). Since WP68 hasn't landed, only the `+`/`-` tier is
   reachable through any *operator* in this WP — the other 6 tiers are
   inert table rows until WP68 populates them. Matches C-family/ca65
   convention; WP68 is free to flag a problem with a specific tier once
   it actually implements that operator, a cheaper time to discover an
   ordering issue than now with nothing concrete to validate it against.
2. **`ppsConstant` (named-constant RHS) stays hand-rolled, not upgraded
   to call the new evaluator — confirmed.** Traced live: `ppsConstant` (`parser.s`)
   has never called `exprEvaluate` — it's a separate parser with its own
   `NUMBER`/`IDENTIFIER`/`CASM_TOKEN_STAR` dispatch (WP65's own numeric/
   identifier arms, WP66's `*` arm), needed because a constant's RHS may
   be a *deferred* reference the Pass1→Pass2 resolution sweep resolves
   later — a fundamentally different resolution model than
   `exprEvaluate`'s "resolve now via callback" contract. WP65's own plan
   explicitly excluded parenthesized/WP67-68 grammar from constant RHS
   ("today's existing bounded expression grammar" only), and WP66
   followed the same precedent for its own `*`-RHS arm. Confirmed:
   `name = (expr)` and `name = a+b*c` stay unsupported in WP67 (and
   WP68) — `ppsConstant`'s grammar is untouched by this WP, matching
   WP65/66's own established boundary, not a new exclusion invented
   here. Revisiting this is a fair question for WP70/71 or a later
   dedicated WP, not this one.
3. **Maximum parenthesization nesting depth — confirmed: 8 levels**
   (not anticipated by WP64 at all — parens didn't exist yet when it was
   written). Every `(` nesting level needs at least one `JSR` (a
   bounded-recursion budget on a 6502's small hardware stack, ~256 bytes
   total shared with every other nested call in the whole assembler —
   parser, lexer, source, VMM), so an explicit bound with a new
   diagnostic (`CASM_DIAG_EXPR_PAREN_TOO_DEEP` or similar, next free
   code after WP65's `$43`) is needed rather than an unbounded recursive
   descent that could silently stack-overflow on pathological input —
   the project's own existing convention (`CASM_CONST_CHAIN_MAX`,
   VMM/source frame-stack bounds elsewhere) is to bound every recursive/
   iterative structure explicitly, never trust caller-supplied nesting
   to stay small. 8 is generous for realistic source while leaving
   comfortable stack headroom; final exact number still confirmed
   against a real measured stack budget in Increment 1 (this is a
   starting target, not yet proven safe against the actual call depth
   in play).

## Technical Design

**Precedence-climbing loop** (replaces `exprEvaluate`'s flat body):
parse one primary (unary-prefix-aware: `-`/`~` will be WP68's job to
populate, but the *slot* for a unary-prefix loop belongs here since it's
part of the architecture, not a specific operator — WP67 leaves it as a
loop that currently never matches any token, costing a few bytes of dead
code rather than requiring WP68 to re-open this proc), then loop: peek
the next token; if it's a binary operator with precedence ≥ the minimum
this call was invoked with, consume it, recursively parse the right-hand
side at that operator's own binding precedence (higher for left-
associative, matching WP64's "generalizing today's single-addend special
case" framing — `+`/`-` are left-associative, e.g. `1-2-3` = `(1-2)-3`),
combine, and continue looping; otherwise return. A parenthesized
sub-expression, reached only from primary position after a binary
operator or as a unary operand (never as the operand's own first token,
per WP64's frozen rule), recurses into the same loop at minimum
precedence, then requires a matching `)` — `CASM_DIAG_EXPR_MALFORMED` (or
a new specific diagnostic) if absent.

**Static-value-only enforcement, moved per-operator** (WP64's own
frozen rule, implemented for the first time here even though `+`/`-` are
the only operators that exist): each binary-operator application checks
both operands' `CASM_EXPR_FLAG_RELOCATABLE` bit before combining.
`+`/`-` keep exactly today's behavior (a relocatable primary plus a
static addend is allowed, unchanged) — this WP does not change what's
representable, only moves the check to fire at each application point
instead of once at the end, in preparation for WP68's operators (which
this rule then rejects with `CASM_DIAG_EXPR_RELOC_UNSUPPORTED`) reaching
the same enforcement point for free.

**Parenthesized-value relocation flag**: `(expr)`'s own `RELOCATABLE`/
`SYMBOL_DERIVED` flags are exactly whatever the inner expression
produced — grouping alone changes no classification, only evaluation
order once WP68 adds operators with different precedence than `+`/`-`.

**`rejectContinuation` retirement**: its current unconditional-reject
role is replaced by the new operator-precedence loop's own "no more
operators at this precedence level" fallthrough — the function itself is
deleted, not kept dead, since its entire contract (reject any trailing
token) is the opposite of what the new loop needs to do.

**Diagnostics**: no new diagnostic needed for grouping/precedence itself
beyond the nesting-depth bound (Scoping Decision 3) — `CASM_DIAG_
EXPR_MALFORMED`/`_UNSUPPORTED`/`_OVERFLOW` already cover a missing `)`,
an operator where a primary was expected, and arithmetic overflow
respectively, reused rather than duplicated. `CASM_DIAG_EXPR_RELOC_
UNSUPPORTED` (`$45`, WP64-reserved, unraised until now) becomes live for
the first time in this WP, though only reachable today via `+`/`-` on
two relocatable operands (e.g. `label1+label2`, previously silently
accepted or rejected some other way — Increment 2 confirms current
behavior before changing it).

**Envelope**: last measured production `casm` usage (fresh `ld65 -m`
re-link against the current object set, not assumed): CODE $4306 +
RODATA $0BE6 + BSS $0CC7 = 23,475 of 24,576 bytes (`$6000` cap) — 1,101
bytes free. WP64's own estimate for "precedence-climbing evaluator core"
was +400-700 bytes, which still fits, but WP68/69/70 need their own
share of the same shrinking pool — Increment 6 (build verification) must
re-measure and flag early if this WP alone consumes materially more than
estimated, rather than let it surface as a surprise in WP68.

## Scope

**Included:**

- Precedence-climbing rewrite of `exprEvaluate` (`expr.s`), replacing
  its flat body — primary dispatch (`NUMBER`/`IDENTIFIER`/`STAR`,
  unchanged from WP66) plus a new operator-precedence loop and
  parenthesized-sub-expression handling.
- `+`/`-` re-expressed as the loop's lowest-precedence tier (behavior-
  preserving for every existing case — Increment 1 is byte-for-byte
  regression proof of this before anything else is added).
- Per-operator static-value-only enforcement (moved, not newly invented
  — WP64's frozen rule).
- Parenthesization nesting-depth bound and its diagnostic.
- New test coverage in `tests/src/casm_expr/` (nested parens, left-
  associativity of chained `+`/`-`, the nesting-depth bound, `(expr)`
  after a unary-operand position once that slot exists even though no
  unary operator is implemented yet — confirm it correctly rejects a
  bare unary-position token today, not silently accept one).
- Live end-to-end fixture(s) analogous to WP65/66's `casmconst*`/
  `casmcuraddr*` proving real parenthesized expressions assemble
  correctly under VICE.

**Excluded:**

- Any of WP68's new operators (`*`, `/`, `<<`, `>>`, `&`, `|`, `^`, unary
  `-`/`~`) — the precedence tiers they'll occupy are structurally
  present (empty table rows) but nothing populates them in this WP.
- `ppsConstant`/named-constant RHS grammar (Scoping Decision 2).
- Character literals (WP69).
- The consolidated cross-WP relocation-algebra proof (WP70's own job).

## Atomic Increments

1. **Byte-for-byte regression baseline**: before writing the new
   evaluator, capture exact current output (assembled bytes, diagnostic
   codes/positions) for every existing `casm_expr` case and every
   Phase 1-11 fixture that exercises an expression. This is the
   before-picture Increment 4 below must reproduce exactly for every
   case that doesn't touch a paren.
2. **Precedence-climbing loop + `+`/`-` tier**: implement the new
   `exprEvaluate` body with only the `+`/`-` tier populated (no parens
   yet), verify it reproduces Increment 1's baseline exactly — proves
   the architecture change itself introduces no behavior drift before
   parens are even added.
3. **Parenthesized sub-expressions**: add `(`/`)` handling per the
   Technical Design above, the nesting-depth bound and its diagnostic
   (Scoping Decision 3's final number).
4. **Per-operator relocation enforcement**: move the static-value-only
   check to fire per operator application; confirm `CASM_DIAG_EXPR_
   RELOC_UNSUPPORTED` fires correctly for `label1+label2`-shaped cases
   (two relocatable operands) and that ordinary `label+NUMBER` is
   unaffected.
5. **New test coverage**: nested parens (`1+(2+3)`, `(1+2)+(3+4)`),
   left-associativity (`1-2-3` = `-4`, not `2`), the nesting-depth
   bound's own boundary (exactly N levels accepted, N+1 rejected), nested
   nesting-depth exactly matching the extraction/addend/`*`-current-
   address interactions WP66 already proved (e.g. `<(BUFSTART+1)`).
6. **Build + envelope verification**: full `casm` target rebuild across
   every disk image; confirm the `$6000` cap and every test-harness cap
   this WP's shared-module growth touches; flag early if the +400-700
   byte estimate is exceeded materially.
7. **Live end-to-end fixtures + regression**: new `casmparen*.s`
   fixture(s) on `casm_include_test_d64` (mirroring WP65/66's own
   `casmconst*`/`casmcuraddr*` precedent), live-verified against the
   real `casm.prg` under VICE; regression re-run of every existing
   harness this WP's shared-module growth could plausibly affect
   (`test_casm_expr`, `test_casm_symbols`, `test_casm_pass1`, plus
   whichever harnesses Increment 6 shows got an envelope bump).

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/expr.s` | Modify (evaluator rewrite — the substantial change this WP is about) |
| `src/external/casm/common.inc` | Modify (nesting-depth bound constant, new diagnostic if needed, `.assert`-pinned) |
| `tests/src/casm_expr/*` | Modify (new fixtures) |
| `cmake/GenerateCasmTestFixtures.cmake`, `CMakeLists.txt` | Modify (new live fixture(s), any envelope bumps Increment 6 finds) |
| `brain/KNOWLEDGE.md`, `brain/task.md`, `wiki/tasks/casm.md` | Modify (activation now, completion summary at close) |
| `docs/casm-utility.md`, `wiki/casm-utility.md`, `wiki/casm-programmers-reference.md` | Modify at completion — parenthesized expressions become real, usable syntax |

## Stop Conditions

- Increment 2 (precedence-climbing loop, `+`/`-` only) fails to
  reproduce Increment 1's byte-for-byte baseline for any existing case —
  stop, the architecture change itself has a defect, do not proceed to
  parens on top of an already-drifting foundation.
- The nesting-depth bound proves wrong once sized against a real
  measured stack budget (Scoping Decision 3) — stop and re-derive rather
  than guessing a second number.
- The `$6000` envelope cap is exceeded by the real build.
- A no-change rebuild changes any artifact.
- A genuinely new defect outside this WP's own scope is found — disclose
  and defer as a separate follow-up (default), unless the user directs
  an inline fix in the moment.

## Documentation, Task, and DOX Updates

- Taskwarrior: new task under Phase 12 parent, depends-on WP64.
- `brain/task.md`, `wiki/tasks/casm.md`: activation entry now; completion
  summary at close.
- `brain/KNOWLEDGE.md`: new WP67 section at close (as-built record).
- User-facing docs: parenthesized expressions get a short section/example
  in `docs/casm-utility.md`/`wiki/casm-utility.md`; `wiki/casm-
  programmers-reference.md`'s §11 updated to describe the new evaluator
  architecture (superseding this session's own WP65/66 update, which
  still describes the flat evaluator).
- `CHANGELOG.md`: entry at close.

## Completion Gate

WP67 completes only when: all increments above are implemented and
verified (existing harnesses green including byte-for-byte regression
proof, new fixtures green under live VICE); the envelope stays within
the `$6000` cap; a completion-gate walkthrough exists in
`brain/walkthroughs/` with live evidence; all trackers are synchronized;
and the user explicitly approves closing WP67.

## Progress

- 2026-08-14: Drafted for review. Grounded against live source directly
  and via an Explore sub-agent: `expr.s:73-293` (current flat evaluator,
  confirmed unchanged since WP66), `expr.s:294-317` (`rejectContinuation`,
  the chokepoint being replaced), `parser.s:632-633,730-744`
  (`posIndirect`'s leading-`(` claim, confirmed untouched by this plan),
  `brain/plans/2026-08-13-casm-phase12-wp64-contract-freeze.md`'s
  Expression Evaluator Architecture and Parenthesization Rule sections
  (the frozen contract this WP implements against, not redesigns), a
  fresh `ld65 -m` re-link (23,475 of 24,576 bytes used, 1,101 free).
  Surfaced three scoping forks not settled by WP64's contract: final
  tier ordering, whether `ppsConstant` gets upgraded to the new grammar,
  and a parenthesization nesting-depth bound (WP64 never anticipated
  parens at all).
- 2026-08-14: User confirmed all three scoping decisions as recommended
  (adopt WP64's tier ordering as-is; `ppsConstant` stays hand-rolled,
  unsupported; nesting-depth bound = 8 levels). Plan updated accordingly.
  Presenting for full-plan approval next.
- 2026-08-14: **User approved this plan as drafted, no changes.**
  Taskwarrior task 43 created, depends on WP64 (task/UUID
  `c307441c-74ab-47a8-bb4c-e997d38bcf99`). Implementation of Increment 1
  begins next.
- 2026-08-14: All 7 Atomic Increments implemented and live-verified.
  Increment 3 surfaced a real, previously-unflagged fork (should NUMBER
  finally support a trailing operator, per the plan's own `1+(2+3)`
  example) — asked and user-confirmed to lift the restriction rather than
  silently deciding either way, updating two existing fixtures'
  (`sNumAdd`/`sNumSub`) expected outcome deliberately. Increment 4
  (relocation enforcement) turned out to already be required by
  Increment 3's own correctness needs (parens made a relocatable RHS
  reachable for the first time) and became verification/audit rather than
  new code — a disclosed, reasonable adjustment as implementation
  unfolded. Increment 7's live VICE run caught two real integration gaps
  no static reading had surfaced: `parser.s`'s `posImmediate` token
  whitelist rejected `(` before `exprEvaluate` was ever reached (fixed
  with one new entry), and both new diagnostics
  (`CASM_DIAG_EXPR_RELOC_UNSUPPORTED`, `CASM_DIAG_EXPR_PAREN_TOO_DEEP`)
  had no message-table entry in `diagnostics.s` (fixed with two new
  entries, confirmed live). A live "regression" (`test_casm_listcap`
  failing 5 of 7 fixtures) was fully bisected against the pre-WP67 source
  (built and tested in complete isolation under `/tmp`) before concluding
  root cause — proved to be a disk-capacity crunch (`casm_listing_test.d64`
  reached 0 free blocks from WP67's own cumulative envelope growth,
  leaving no runtime headroom for the harness's own output-file writes),
  not a code defect. Resolved by relocating three genuinely self-contained
  harnesses (`test_casm_bounds`/`cliderive`/`lexer`) to
  `casm_include_test_d64`. Two new live end-to-end fixtures
  (`casmparen1.s`, `casmparen2.s`) verified byte-exact/message-exact
  against the real `casm.prg` binary under VICE, alongside regression
  re-verification of nine other harnesses (all PASS). Full completion-gate
  walkthrough: `brain/walkthroughs/2026-08-14-casm-phase12-wp67-parens-
  precedence.md`. Documentation updated: `docs/casm-utility.md`/`wiki/
  casm-utility.md`/`wiki/casm-programmers-reference.md`,
  `brain/KNOWLEDGE.md`, `brain/task.md`, `wiki/tasks/casm.md`,
  `CHANGELOG.md`. Taskwarrior task marked done. **Presented for final
  user approval to close WP67.**
