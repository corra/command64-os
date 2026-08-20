---
feature: casm-phase12-wp76-forward-reference-pass-agreement-fix
created: 2026-08-20
status: proposed
taskwarrior: UUID 25420ff2-5dd5-46d0-a790-4d10dda0b947 (numeric ID is
  session-local and shifts as other tasks are added/removed -- currently
  44, was 45 when this plan was first drafted; always resolve via UUID)
depends-on: CASM Phase 12 WP65, WP68, WP72 (complete); discovered mid-WP75
---

# Plan: CASM Phase 12 WP76 — Forward-Reference Pass-Agreement Fix for Named Constants

## Status

**Proposed, not yet approved.** Drafted 2026-08-20 for user review, per
this project's per-work-package-plan-approval requirement
(`.agents/workflows/phased-implementation-planning.md`). No implementation
is authorized until this plan is approved.

Numbered WP76 following the WP72/WP73 precedent: a corrective fix
discovered mid-adjacent-WP gets its own inserted WP number rather than
folding into the WP that found it. WP75 (verification/completion gate)
is paused pending this fix — see its own plan's Progress log, entry
2026-08-20, and Taskwarrior task 44 (UUID 25420ff2).

## Objective

Fix a genuine Pass 1/Pass 2 instruction-width disagreement for named
constants, first observed as Taskwarrior task 44 (UUID 25420ff2):
`casmarithfwd.s` (`.ORG $0010` / `LDA FWDCONST*2` / `FWDCONST = 5`) fails
`CASM: PASS 1/2 MISMATCH` instead of its documented `CASM: INPUT
VALIDATED`.

**Root cause, confirmed live** (VICE breakpoint-free memory read at the
mismatch point: `CasmPass1FinalPc = $0013`, `CasmPc = $0012` — a 1-byte
gap, exactly absolute-vs-zero-page): `FWDCONST` is referenced (as an
`LDA` operand) *before* its own defining statement. During Pass 1, the
reference at line 2 finds `FWDCONST` undefined — `expr.s`'s `identifier:`
proc takes the "label-shaped" path (line 340-353), leaving
`CASM_EXPR_FLAG_SYMBOL_DERIVED` set, which unconditionally forces
absolute (3-byte) addressing. By the time Pass 1 reaches line 3,
`FWDCONST` becomes a fully resolved, non-label-derived constant. Pass 2
replays the source top-to-bottom against the now-fully-populated symbol
table, so at line 2 `FWDCONST` is *already* resolved — WP72's exemption
(`expr.s:354-371`) fires, clears `SYMBOL_DERIVED`, and the value-based
selector picks zero-page (2 bytes) for `FWDCONST*2 = 10 = $0A`.

WP72's own governing comment (`expr.s:354-357`) asserts *"a resolved,
non-label-derived constant's value can never differ between Pass 1 and
Pass 2... fully resolves every such constant before either pass ever
evaluates an instruction operand naming it."* That is true of the
constant's *value* but false of its *resolution state at the moment of a
specific reference* — which is what actually drives `FORCE_ABS`. The
invariant holds for backward references (WP72's own fixture,
`casmzpconst1.s`, defines before use) and breaks for forward references.

**Does NOT deliver:** any change to CASM's documented named-constant
syntax, the zero-page optimization itself for the safe (define-before-use)
case, or any behavior outside this specific pass-agreement defect.

## Scoping Decisions (needs confirmation before implementation)

1. **Fix mechanism — recommended: per-symbol "defined-at" source position,
   compared against the current reference's position.** Extend the
   symbol record (64-byte record, bytes 44-63 currently reserved padding
   — see `common.inc` `CASM_SYMBOL_REC_*`) with a new 2-byte
   `DEFINED_AT_OFFSET_LO/HI` field, stamped from the already-global
   `CasmTokenStartOffsetLo/Hi` (lexer.s, stamped on *every* token,
   already imported by `parser.s`) at the moment `crpConstant` processes
   the constant's own defining statement. `expr.s`'s WP72 exemption gains
   one more condition: only clear `SYMBOL_DERIVED` if the *current*
   reference's `CasmTokenStartOffsetLo/Hi` is `>=` the symbol's
   `DEFINED_AT_OFFSET` — i.e., this reference is at or after the
   constant's own definition in source order. A reference strictly
   before it keeps `SYMBOL_DERIVED` set (forces absolute), in both
   passes, restoring the same width in both.
   - Why this shape over a new bounded "forward-referenced names" log:
     it reuses existing, already-global infrastructure
     (`CasmTokenStartOffsetLo/Hi`) instead of inventing a new auxiliary
     data structure with its own capacity limit and failure mode; it's a
     pure position comparison, not a flag that has to be set at exactly
     the right moment during a failed lookup (there is no failed-lookup
     hook to attach to today — see Technical Notes); and it handles both
     of Scoping Decision 2's candidate failure shapes uniformly, since
     it doesn't care *why* a symbol wasn't resolved yet, only *when* it
     was.
2. **Scope confirmation needed before finalizing the fix's exact touch
   points**: is the defect limited to *numeric-RHS forward references*
   (this plan's Objective, `casmarithfwd.s`'s shape), or does it also
   reach *identifier-RHS (deferred) constants* referenced as an operand
   regardless of source order — since a deferred constant is never
   resolved during Pass 1's main walk at all (only at the Pass1→Pass2
   boundary sweep, WP65), so *any* Pass 1 reference to one, even one
   textually after its own definition, would see it unresolved the same
   way a numeric forward-reference does. Atomic Increment 1 below
   confirms this live before the fix is scoped further. The recommended
   fix mechanism (Scoping Decision 1) already covers this shape too if
   it turns out to be real — it needs no adjustment either way, only the
   test-fixture set does.
3. **Version promotion**: this plan does not itself decide whether CASM
   promotes a version number on this fix's completion (WP75's own plan
   already reserves `0.2.8` -> `0.3.0` for its own closure) — recommend
   folding this fix's own bump into WP75's existing Increment 8, not a
   separate promotion here, since WP75 is blocked on this fix anyway and
   the two will close together.

## Scope

**Included:**
- `common.inc`: new `CASM_SYMBOL_REC_DEFINED_AT_OFFSET_LO/HI` fields in
  previously-reserved padding, `.assert`-pinned; no record-size change.
- `symbols.s`: `symbolsInsert` (or a thin wrapper `crpConstant` calls)
  stamps the new field for constant inserts only (labels don't need it —
  they stay unconditionally force-abs regardless, per WP39's existing
  design, untouched by this plan).
- `expr.s`: `identifier:` proc's WP72 exemption branch (lines 354-371)
  gains the position comparison described in Scoping Decision 1.
- New CASM test fixture(s) proving the fix: at minimum a native-CASM
  re-verification of `casmarithfwd.s` itself against its existing
  `casmarithfwd.ref.hex`; additional fixtures if Increment 1 confirms
  the deferred-constant shape is also real.
- WP75's own plan: unblock its paused Progress-log entry once this WP's
  completion gate closes.

**Excluded:**
- Any change to label addressing-width rules (WP39, already correct and
  unconditional).
- Any change to WP68's arithmetic/bitwise operators themselves — the
  operator evaluation is correct; only the *addressing-width decision*
  for the operand it produces is at issue.
- Re-litigating WP72's own zero-page optimization for the safe
  (define-before-use) case — that stays exactly as it is.
- Generalizing this position-tracking mechanism to anything beyond named
  constants (e.g., speculative future use for some other symbol kind) —
  out of scope unless a real need emerges.
- **Taskwarrior task 45 (UUID `b1369c8c-8fc6-4038-825c-1103a106257c`)**: a
  separate, unrelated parse defect found while probing this plan's own
  Increment 1 (a constant chained to another constant, `DEFCONST =
  BASECONST`, breaks the *following* line with `CASM: EXPECTED NEWLINE`
  — reproduces with no arithmetic operator involved, so it cannot be the
  same defect this plan targets). Logged and explicitly deferred per this
  project's disclose-and-defer norm; not investigated or fixed here.

## Technical Notes

### Why there's no existing hook to catch a failed lookup

`symbolsInsert` (`symbols.s:303`) calls `symbolsFindChain` first and
treats *any* existing entry as `CASM_DIAG_DUPLICATE_SYMBOL` — CASM's
symbol table has no placeholder/stub-then-promote mechanism for forward
references of any kind. A failed `symbolsLookup` during Pass 1 (the
"MEASURE mode tolerates an unresolved identifier" path, `parser.s`)
leaves no trace anywhere — it's a pure evaluation-time miss, not a table
mutation. This is why Scoping Decision 1 favors a position-comparison
approach (computed at the moment of *each* reference, using data that
already exists globally) over trying to detect-and-flag the failed
lookup itself (which would require inventing exactly the placeholder
mechanism that doesn't exist today).

### Symbol record capacity

`CASM_SYMBOL_REC_SIZE = 64`; WP65's own `REF_*` fields occupy bytes
37-43; bytes 44-63 (20 bytes) remain reserved, zero-filled padding —
ample room for a 2-byte `DEFINED_AT_OFFSET`.

### `CasmTokenStartOffsetLo/Hi` is already global and comparable

Stamped by `lexer.s` on every token (not just constant-related ones) and
already imported by `parser.s`. No new tracking infrastructure needed to
know "the current reference's source position" — only a new place to
remember "this constant's defined-at position," which fits in the
existing record's reserved padding.

### Both passes converge on the same rule with no special-casing

Because the position comparison is symmetric (doesn't ask "which pass am
I in," only "is this offset before or after that offset"), Pass 1 and
Pass 2 will independently compute the identical answer for the identical
statement — the actual property `emitCheckPassAgreement` needs, restored
without threading pass-number state through `expr.s` at all.

## Atomic Increments

1. **Confirm/bound the true failure shape live — partially blocked,
   proceed regardless.** A constant chained to a *label* can never hit
   this bug by design (`expr.s:352-353`: `LABEL_DERIVED` skips WP72's
   exemption unconditionally, same as a real label — always force-abs,
   both passes agree trivially). The only shape that would actually test
   Scoping Decision 2 is a constant chained to *another constant*
   (`DEFCONST = BASECONST`), which is exactly the shape task 45 (UUID
   `b1369c8c`) found broken at parse time — untestable until that
   separate defect is fixed. Since the recommended fix mechanism
   (Scoping Decision 1) covers both candidate shapes uniformly with no
   design change either way, this does not block Increments 2-6 — only
   the second test fixture (deferred-constant-chain case) is deferred
   until task 45 is separately resolved.
2. **Symbol record + insert-site change.** Add the new field to
   `common.inc` with its `.assert`. Update `crpConstant` (`casm.s`) or
   `symbolsInsert` (`symbols.s`) to stamp
   `CasmTokenStartOffsetLo/Hi` into the new field at constant-insert
   time. No behavior change yet — the field is written but not read.
3. **`expr.s` read-side change.** Add the position comparison to the
   `identifier:` proc's WP72 exemption branch. This is the only
   behavior-changing increment.
4. **Test fixtures.** At minimum, a live re-verification that
   `casmarithfwd.s` now produces `CASM: INPUT VALIDATED` and matches
   `casmarithfwd.ref.hex` via `COMP`. Add Increment 1's probe fixture (if
   it reproduced the defect) with its own hand-derived `.ref`. Re-run
   WP72's own fixture (`casmzpconst1.s`) and WP73's own fixture
   (`casmfwdstale1.s`) to confirm neither regresses.
5. **Consolidated live-VICE re-verification.** Re-run all ten WP75
   Increment 5 production fixtures together (not just the two/three this
   fix touches) on a fresh `casm_phase12_test.d64` attach, per this
   project's "Multi-WP phases" consolidated-verification norm — a fix
   landing here is exactly the kind of change that needs the full sweep
   repeated, not just the fixture that originally failed.
6. **Unblock WP75.** Update WP75's own plan Progress log to record this
   fix's completion and resume WP75's remaining increments (6-10) from
   where Increment 5 paused.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/common.inc` | Modify (Increment 2) |
| `src/external/casm/symbols.s` or `casm.s` | Modify (Increment 2) |
| `src/external/casm/expr.s` | Modify (Increment 3) |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify (Increment 4, if Increment 1's probe fixture is needed) |
| `tests/fixtures/casm/*.ref.hex` | Create, hand-derived (Increment 4) |
| `brain/plans/2026-08-19-casm-phase12-wp75-verification-walkthrough-completion-gate.md` | Modify — Progress log (Increment 6) |

## Stop Conditions

- Increment 1's probe reproduces a *third*, differently-shaped mismatch
  not explained by this plan's root-cause analysis — halt and re-analyze
  before proceeding to Increment 2.
- Any of WP72's or WP73's own fixtures regress after Increment 3's
  change.
- Increment 5's consolidated sweep finds any fixture outside this plan's
  own scope failing unexpectedly.
- A no-change rebuild after this fix alters any shipped artifact
  (`casm.prg` itself, or anything downstream like `dash.ref.hex`'s
  recorded bytes — this fix must not change output for any *already
  correct* case).
- Any approved directory-entry/byte-space ceiling on an affected disk
  image is exceeded.

## Documentation, Task, and DOX Updates

- **At approval**: link Taskwarrior task 44 (UUID 25420ff2) to this plan (already
  entered, `brain/task.md` gets a plan-reference note).
- **At completion**: `brain/KNOWLEDGE.md` (new WP76 entry, matching the
  WP65/WP68/WP72/WP73 entries' style), `CHANGELOG.md`, WP75's own plan
  Progress log (Increment 6), Taskwarrior task 44 (UUID 25420ff2) closed,
  `wiki/casm-programmers-reference.md`'s symbol-record documentation
  (deferred per the user's own decision to hold all CASM Phase 12 doc
  updates until WP75 closes — this plan's own completion doesn't trigger
  writing it, WP75's closure does).

## Completion Gate

- Live VICE evidence: Increment 1's scope-confirmation probe, Increment
  4's fixture re-verifications, and Increment 5's consolidated sweep, all
  recorded with real evidence (not just intentions) in
  `brain/walkthroughs/2026-08-20-casm-phase12-wp76-forward-reference-pass-agreement-fix.md`.
- `casmarithfwd.s` produces `CASM: INPUT VALIDATED` and matches its
  `.ref.hex` via `COMP`.
- No regression in any WP65/WP68/WP70/WP72/WP73/WP74 fixture.
- No-change rebuild stable.
- WP75's plan Progress log updated to reflect this fix and WP75's resumed
  status.
- Explicit user approval — this plan does not self-declare completion.

## Progress

- 2026-08-20: Plan drafted, pending approval. Root cause confirmed live
  via direct memory read (`CasmPass1FinalPc=$0013`,
  `CasmPc=$0012`) on `casm_phase12_test.d64` under VICE, following static
  analysis of `expr.s`'s WP72 exemption branch and `emit.s`'s
  `emitCheckPassAgreement`.
- 2026-08-20: Plan approved by user. Implementation complete, all
  increments closed:
  - **Increment 1**: partially blocked as anticipated. A constant chained
    to a label can never hit this defect by design (`expr.s:352-353`
    already forces absolute unconditionally for `LABEL_DERIVED`), so a
    label-based probe was skipped as uninformative. The only shape that
    would test the deferred-constant-chain question
    (`DEFCONST = BASECONST`) hit a *separate* defect (logged as
    Taskwarrior task 45, UUID `b1369c8c-8fc6-4038-825c-1103a106257c`:
    chaining a constant to another constant breaks parsing of the
    *following* line with `CASM: EXPECTED NEWLINE`, even with no
    arithmetic operator involved) — disclosed and deferred per this
    project's Stop Conditions, not investigated further here. Proceeded
    with Increments 2-6 regardless, since the recommended fix mechanism
    covers both candidate shapes with no design change either way.
  - **Increment 2**: added `CASM_SYMBOL_REC_DEFINED_AT_OFFSET_LO/HI`
    (`common.inc`, offsets 44-45, `.assert`-pinned); `ppsLabel` (`parser.s`)
    stamps `CasmLabelDefinedAtOffsetLo/Hi` from
    `CasmTokenStartOffsetLo/Hi` before consuming further tokens;
    `crpConstant` (`casm.s`) copies it into the new
    `CasmSymbolInsertDefinedAtOffsetLo/Hi` staging fields;
    `symbolsInsert` (`symbols.s`) copies those into the record, gated on
    `CASM_SYMBOL_FLAG_CONSTANT` alongside the existing `Ref*` fields.
    Also extended the resolver output view (`CASM_RESOLVE_*`,
    `CASM_RESOLVE_SIZE` 6->8) with
    `CASM_RESOLVE_DEFINED_AT_OFFSET_LO/HI`, populated by `symbolsLookup`
    at zero extra VMM-read cost (the matched record is already loaded).
  - **Increment 3**: `expr.s`'s `identifier:` proc's WP72 exemption
    branch now compares the current reference's
    `CasmTokenStartOffsetLo/Hi` against the matched constant's
    `CASM_RESOLVE_DEFINED_AT_OFFSET_LO/HI`; strictly-before falls through
    to the existing unconditional label-shaped path (`evApplyMode`),
    at-or-after proceeds to the original WP72 value-based selection.
  - **Increment 4**: live-verified `casmarithfwd.s` now produces
    `CASM: INPUT VALIDATED` and `FILES COMPARE OK` against
    `casmarithfwd.ref.hex` (previously `CASM: PASS 1/2 MISMATCH`).
    `casmzpconst1.s` (WP72) and `casmfwdstale1.s` (WP73) both re-verified
    with no regression.
  - **Increment 5**: consolidated fresh live-VICE re-verification of all
    11 WP75 Increment 5 production fixtures together on one dedicated
    disk (`wp76_consolidated.d64`): `casmarithfwd`, `casmzpconst1`,
    `casmfwdstale1`, `casmrelacc` (`INPUT VALIDATED` + `FILES COMPARE
    OK`); `casmarelocb`/`casmareloc1`/`casmareloc2` (exact documented
    `CASM: EXPRESSION RELOCATION UNSUPPORTED` at their exact
    line/col/offset); `casmarith2`, `casmarith3`, `casmchar1`,
    `casmstring1` (`INPUT VALIDATED` + `FILES COMPARE OK`). All 11 match
    their documented outcomes exactly, zero regressions.
  - Along the way, found and fixed a real build break the plan hadn't
    anticipated: `tests/src/casm_expr/casm_expr.s` (a synthetic
    unit-test harness for `expr.s` with no real `lexer.s` linked) didn't
    provide `CasmTokenStartOffsetLo/Hi`, and its own `resolveConst`
    fixture (the exact WP72-exemption test case) didn't populate the new
    resolver-view fields. Added both as zero-defaulted stubs, preserving
    that fixture's original expected outcome exactly (`0 >= 0`,
    at-or-after, safe). Full project build (`cmake --build build`, no
    target) now succeeds with zero errors/warnings, and a full no-change
    rebuild is byte-stable across every disk image.
  - Completion Gate met pending walkthrough and final user approval.
