---
feature: casm-phase12-wp72-constant-zeropage-width
created: 2026-08-17
status: complete
taskwarrior: d439019e-5487-4f76-bf08-3fc792d43813
depends-on: WP71 (discovered the defect; this WP unblocks its Atomic Step 5)
---

# Plan: CASM Phase 12 WP72 — Named-Constant Zero-Page Width Selection Fix

## Status

**Approved 2026-08-17.** Implementation of the Atomic Increments below is
authorized. Taskwarrior task 44 (`d439019e-5487-4f76-bf08-3fc792d43813`)
created and started; task 43 (WP71) now depends on it.

Not a sub-WP of a parent plan — a standalone point-fix WP inserted into
Phase 12's numbering because it was discovered mid-WP71 and blocks WP71's
completion. See
`brain/plans/2026-08-15-casm-phase12-wp71-dash-adoption.md`, Progress
section, 2026-08-17 entry, for the original discovery, reproduction, and
root-cause analysis this plan is built on.

## Objective

Fix a confirmed CASM code-generation defect: an instruction operand that
is a **named-constant (equate) symbol** whose resolved value fits in the
zero-page range ($00-$FF) is always encoded with **absolute** (3-byte)
addressing, never **zero-page** (2-byte) addressing — even though the
identical numeric value written as a bare literal (`STA $70` vs
`STA SYMBOL` where `SYMBOL = $70`) correctly selects zero-page. This
produces larger, slower code than the source's own literal-operand form
would, and — because CASM's native output disagrees with the ca65
cross-check on exactly this point — it silently breaks the dual-assembler
byte-for-byte equivalence the project's whole cross-check testing strategy
depends on wherever a real program uses named constants in an instruction
operand at scale (first surfaced by WP71's DASH adoption work).

**Delivers:** a fix in `src/external/casm/expr.s` narrowing the
unconditional `FORCE_ABS`-triggering behavior so a *resolved,
non-label-derived constant* (a pure numeric equate, not a label and not a
relocatable/address-derived constant) flows through the normal
value-based zero-page/absolute selection in `opcodes.s`, exactly as a
literal operand already does. Plus regression coverage proving it, and
re-verification of WP71's blocked native-provenance regen once this
lands.

**Does not deliver:** any change to label or current-address-symbol
(`*`) width selection — both remain unconditionally forced to absolute,
correctly, for the Pass 1/Pass 2 agreement reason documented in the
existing code (see Technical Design below). Does not deliver WP71's own
remaining Atomic Steps 5-6 (those resume, under WP71's own plan, once
this fix is verified) — this plan's own completion gate is the fix itself
plus its regression proof, not WP71's native regen.

## Root Cause (confirmed by direct source reading, not the reporting
sub-agent's word alone — independently re-read and verified against
`src/external/casm/expr.s`, `parser.s`, and `opcodes.s` at their current
line numbers before drafting this plan)

Three cooperating pieces, all in `src/external/casm/`:

1. **`expr.s::identifier`** (the symbol-reference evaluator, invoked for
   every operand token that is a name rather than a number), lines
   312-320: on every successful resolver call, it unconditionally does
   `ora #CASM_EXPR_FLAG_SYMBOL_DERIVED` into the expression's flags byte
   — regardless of `CASM_SYMBOL_FLAG_CONSTANT`/`LABEL_DERIVED`, the same
   symbol-kind flags the *very next block* (lines 339-348) already reads
   to decide `RELOCATABLE` classification correctly. `SYMBOL_DERIVED` is
   set identically whether the identifier resolves to a label or to a
   pure numeric equate.

2. **`parser.s::parserParseExpressionValue`**, lines 972-984 (documented
   at 909-919): derives `CASM_PARSER_STMT_FORCE_ABS` straight from
   `CASM_EXPR_FLAG_SYMBOL_DERIVED`, unconditionally, "before the RESOLVED
   check... since it must apply on both the resolved and unresolved
   sub-paths." The stated reason is real and correct **for labels**: "a
   resolved backward reference with a small value... could disagree in
   size with an unresolved forward reference to that same label processed
   in a different pass" (Pass 1 vs Pass 2 width must never differ for a
   forward-referenceable address). It does not distinguish a label from a
   constant, because `SYMBOL_DERIVED` itself doesn't (defect 1).

3. **`opcodes.s`**, three symmetric sites (ZeroPage,X ~line 143-145;
   ZeroPage,Y ~line 167-169; plain ZeroPage/Absolute ~line 192-194): each
   checks `CASM_PARSER_STMT_FORCE_ABS` *before* the value-based `VAL_HI`
   check and unconditionally takes the absolute branch if it's set. This
   part of the logic is correct as written — it's a faithful consumer of
   an already-wrong input.

**Why a constant doesn't need this protection**: `expr.s`'s own WP65
comment (lines 328-338) already establishes that every named constant is
fully resolved, for both passes, before any instruction operand is ever
evaluated (`casmResolveConstants`, called from `casm.s`, runs to
completion before Pass 1's instruction stream is processed) — a
constant's value literally cannot disagree between Pass 1 and Pass 2 the
way a forward-referenced label's can. The code already draws exactly this
distinction for `RELOCATABLE` (lines 339-348: a resolved, non-label-
derived constant is explicitly walked past the "apply unconditionally"
path). It never applies the same distinction to `SYMBOL_DERIVED`/
`FORCE_ABS`, which is the actual defect: two structurally identical
"is this genuinely load-address-sensitive" questions, answered correctly
in one place and not the other, four lines apart.

**Compound expressions confirmed to flow correctly once the primary is
fixed**: `expr.s`'s binary-operator loop (documented ~line 442-447)
propagates the RHS's own `SYMBOL_DERIVED`/`RELOCATABLE` bits into the
accumulator for `+`/`-`. `DISPATCHVECTOR+1` (WP71's own second confirmed
mismatch site) is exactly this shape — fixing the primary
(`identifier`)'s flag-setting is sufficient; no separate fix is needed in
the addend-combination logic itself.

**`*` (current-address symbol, WP66) is correctly unaffected**: its own
handler (`expr.s` lines 257-272) sets `SYMBOL_DERIVED` unconditionally
with its own explicit comment explaining why — `*`'s value is exactly as
load-address-sensitive as a label's. This plan's fix must not touch that
path.

## Scope

**Included:**
- The gating fix in `expr.s::identifier`: only set the
  `SYMBOL_DERIVED`-equivalent bit that drives `FORCE_ABS` when the
  resolved symbol is *not* a plain, resolved, non-label-derived constant.
  Reuses the same `CASM_SYMBOL_FLAG_CONSTANT`/`RESOLVED`/
  `LABEL_DERIVED` classification already computed at lines 339-348 for
  `RELOCATABLE` — this plan's Technical Design section below settles the
  exact mechanism (new flag bit vs. reordering vs. shared helper) before
  implementation.
- Verification that unresolved-constant references (reachable only
  during `casmResolveConstants` itself resolving one constant from
  another, never during instruction-operand evaluation, per the existing
  WP65 comment) are unaffected or provably unreachable for this code
  path — confirm by reading `casm.s`'s pass ordering, not just citing the
  existing comment.
- Regression coverage proving the fix end-to-end (real source text, real
  encoded bytes) — not just an expr.s-level flag check or an
  opcodes.s-level isolated-input check, since neither of those two
  existing harnesses individually spans the seam where this defect
  actually lives (see Test Strategy below).
- Re-running the existing full CASM test suite to confirm zero
  regressions elsewhere (labels, `*`, relocatable constants, and every
  existing WP65-70 fixture must all still pass unchanged).
- Once the fix is verified: hand control back to WP71's own plan to
  resume its Atomic Step 5 (native regen) — noted here, not performed by
  this plan.

**Excluded:**
- Any change to label or `*` width selection.
- Any change to `RELOCATABLE` classification (already correct).
- WP71's own remaining work (Atomic Steps 5-6) — this plan only unblocks
  it.
- Any DASH source change — none needed; DASH's source was already correct
  Phase-12-adopted syntax, per WP71's own Atomic Step 1 audit.
- Any broader audit of other `FORCE_ABS`/width-selection edge cases
  beyond this specific constant-vs-label distinction, unless Atomic
  Increment 1's re-read of the surrounding code surfaces one directly on
  this same seam.

## Technical Design

**Mechanism choice** (to settle during Atomic Increment 1, before writing
the fix, since the "right" shape depends on details worth re-confirming
live rather than assuming from the research pass):

- Option A: reorder `identifier` so the constant-classification check
  (currently at lines 339-348, computed *after* `SYMBOL_DERIVED` is
  already set at line 319) runs first, and skip the
  `ora #CASM_EXPR_FLAG_SYMBOL_DERIVED` entirely when the "resolved,
  non-label-derived constant" condition holds.
- Option B: keep `SYMBOL_DERIVED` as today (still useful for whatever
  else reads it — confirm via the existing grep hits at lines 743/783,
  the binary-operator propagation) and introduce the gating at the
  `RELOCATABLE`-classification block instead, storing a *second*,
  narrower flag bit (e.g. `CASM_EXPR_FLAG_WIDTH_UNSAFE`) that
  `parser.s::parserParseExpressionValue` reads for `FORCE_ABS` instead of
  `SYMBOL_DERIVED`.

Option A is simpler (one bit, no new flag) but must confirm nothing else
in the codebase depends on `SYMBOL_DERIVED` being set for a resolved
constant specifically (the binary-operator-propagation reads at lines
743/783 need checking: do they need `SYMBOL_DERIVED` for constants to
propagate `RELOCATABLE` correctly through `+`/`-`, or is `RELOCATABLE`
tracked independently already?). Atomic Increment 1 reads those sites
before choosing.

**Unresolved-constant reachability**: the existing WP65 comment claims an
instruction operand can never reference an unresolved constant (all
constants are resolved before Pass 1's instruction stream runs). Atomic
Increment 1 confirms this directly in `casm.s`'s pass driver before
relying on it — if it's wrong, the fix needs a fallback (unresolved
constant references still force absolute, same as today) rather than
assuming the comment is accurate.

## Atomic Increments

1. **Confirm preconditions.** Re-read `casm.s`'s pass driver to confirm
   `casmResolveConstants` genuinely completes before any instruction
   operand is evaluated (so a constant reference reaching `identifier` is
   always `RESOLVED`). Re-read the `SYMBOL_DERIVED` consumers at `expr.s`
   lines 743/783 (binary-operator RHS propagation) to determine whether
   Option A or Option B (above) is correct. Stop and report if either
   check contradicts this plan's Root Cause section.
2. **Implement the fix** in `expr.s::identifier` per the mechanism chosen
   in Increment 1. Minimal diff — this is a gating condition, not a
   restructure.
3. **Unit-level proof**: extend `tests/src/casm_expr/casm_expr.s` (which
   already exercises `identifier`/symbol resolution in isolation) with
   cases proving a resolved, non-label-derived constant no longer sets
   the `FORCE_ABS`-triggering bit, while a label and `*` still do.
4. **End-to-end proof**: add a case to `tests/src/casm_pass1/` (or
   wherever the project's established full-pipeline source-to-bytes
   fixture pattern lives — confirm the right harness during this
   increment rather than assuming `casm_pass1`) that assembles real
   source text equivalent to WP71's own reproduction (`SYMBOL = $70` /
   `STA SYMBOL` / `STA SYMBOL+1`) and asserts the emitted bytes are the
   2-byte zero-page encoding, not 3-byte absolute. This is the only test
   that spans the actual `expr.s`-to-`opcodes.s` seam where the defect
   lived — neither existing `casm_expr` (expr.s in isolation) nor
   existing `casm_opcodes` (opcodes.s fed synthetic `CasmParserStmt`
   input, bypassing expr.s entirely) would have caught this bug, which is
   why it shipped through WP65-70 undetected until WP71's real-world use.
5. **Full regression**: run the complete existing CASM test suite
   (`casm_expr`, `casm_opcodes`, `casm_pass1`, `casm_reloc`, `casm_symbols`,
   and any other harness touching constants/relocation/width selection)
   to confirm zero unintended change — labels, `*`, and already-shipped
   WP65-70 fixtures must produce byte-identical output to before this fix.
6. **ca65 cross-check re-verification**: rebuild `dash_ref` (the ca65
   cross-check target already proven correct at 3,828 code bytes/465
   relocation points per WP71's Atomic Step 2) to confirm it's untouched
   by this change (it should be — this fix only affects native CASM).
7. **Report back to close this plan**, then hand off to WP71's own plan
   to resume its Atomic Step 5 (native CASM regen of `dash.prg`), which
   should now produce output byte-identical to the ca65 reference.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/expr.s` | Fix: gate `FORCE_ABS`-triggering flag on constant-vs-label distinction |
| `tests/src/casm_expr/casm_expr.s` | Add unit-level constant/label/`*` distinction cases |
| `tests/src/casm_pass1/casm_pass1.s` (or equivalent full-pipeline harness, confirmed in Increment 4) | Add end-to-end zero-page-selection regression case |
| `brain/plans/2026-08-15-casm-phase12-wp71-dash-adoption.md` | Progress note once this fix lands and WP71's Step 5 resumes |

## Stop Conditions

- Atomic Increment 1's re-read contradicts this plan's Root Cause
  analysis (e.g. an unresolved constant genuinely can reach `identifier`
  during instruction-operand evaluation, or something else already
  depends on `SYMBOL_DERIVED` being set for constants) — stop and report
  before implementing against a false premise.
- Any existing CASM test (not just the two new ones this plan adds)
  changes behavior after the fix — a real regression, not expected from a
  narrowly-scoped gating change.
- The end-to-end fixture (Increment 4) still shows absolute addressing
  for the constant case after the fix — the mechanism chosen in
  Increment 1 was wrong; stop and re-diagnose rather than layering a
  second, competing fix on top.
- The ca65 cross-check (Increment 6) changes byte output — it should be
  entirely unaffected by a native-CASM-only change; if it changes, that's
  a sign the fix touched something shared/misdiagnosed.

## Documentation, Task, and DOX Updates

- Create/activate a Taskwarrior task for this WP under Phase 12, blocking
  WP71's own task, once this plan is approved.
- At completion: `brain/KNOWLEDGE.md` Phase 12 section (as-built note),
  `CHANGELOG.md` entry, `brain/walkthroughs/` completion-gate doc,
  `brain/task.md`/`wiki/tasks/casm.md` sync. `docs/casm-utility.md` update
  only if this changes any user-observable CASM behavior description
  (likely: a note that named constants now correctly use zero-page
  addressing when eligible, matching literal-operand behavior) — confirm
  during close-out whether that doc currently claims otherwise.

## Completion Gate

This WP completes only when: the fix is implemented and narrowly scoped
to the constant-vs-label distinction; the new unit-level and end-to-end
tests both pass and demonstrably fail without the fix (verified by
running them against the pre-fix source, not just asserting they would);
the full existing CASM test suite passes unchanged; the ca65 cross-check
target remains byte-identical; a `brain/walkthroughs/` doc records live
evidence; and the user explicitly approves closing this WP. WP71's own
Atomic Step 5 re-attempt (confirming `COMP` now passes byte-for-byte) is
tracked and reported under WP71's own plan, not this one, but is the
practical proof this fix actually solved the originating problem.

## Progress

- 2026-08-17: **Implementation complete, all Atomic Increments done,
  awaiting user approval to close.** Full detail in
  `brain/walkthroughs/2026-08-17-casm-phase12-wp72-constant-zeropage-width.md`.
  Summary: fixed `expr.s::identifier` per the plan's Root Cause analysis
  (Option A, exactly as anticipated); found and fixed a genuine
  pre-existing unrelated off-by-one in `casm_expr`'s own harness driver
  (`CASE_COUNT`) that was silently skipping the table's true last case,
  discovered because it caused the new regression case to falsely pass
  against deliberately-broken code; found and deliberately left unfixed
  (out of scope, confirmed harmless/inert) a second dormant control-flow
  quirk in the same proc. New unit-level case demonstrated fail-before/
  pass-after live under VICE. Full regression suite (pass1/reloc/
  symbol/opcodes/expr) clean post-fix. `dash_ref` ca65 cross-check
  confirmed byte-identical (unaffected, as expected). New end-to-end
  native-CASM fixture (`casmzpconst1`, mirroring DASH's real
  `DISPATCHVECTOR` source verbatim) COMP-verified byte-exact against a
  hand-derived reference. `casm_phase12_test_d64` at 435 free blocks
  (down 2 from WP70's 437), gate not threatened.
- 2026-08-17: Drafted this plan after independently re-verifying the
  root-cause analysis from WP71's Progress log by direct source reading
  (`expr.s` lines 292-367 and 257-279, `parser.s` lines 895-990,
  `opcodes.s` lines 120-201) rather than taking the discovery at face
  value. Confirmed the exact `SYMBOL_DERIVED`/`FORCE_ABS` mechanism, the
  existing `RELOCATABLE`-classification precedent this fix should mirror,
  and that `*`'s own handling is a separate, correctly-unconditional path
  that must not be touched. Surveyed existing test harnesses
  (`casm_expr`, `casm_opcodes`, `casm_pass1`) and confirmed neither
  existing harness spans the seam where the defect lives, which is why
  regression coverage needs a new end-to-end case, not just a unit-level
  one. Awaiting user approval before implementation begins.
