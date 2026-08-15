---
feature: casm-phase12-wp68-increment9-live-end-to-end
created: 2026-08-15
status: approved
taskwarrior: c1b8e145-0a9c-4e15-aaab-4e82fc253363 (WP68, task 43)
depends-on: WP68 Increment 8, complete
---

# Plan: CASM Phase 12 WP68 Increment 9 - Live End-to-End Verification

## Status

**Approved 2026-08-15.** The user approved this plan as drafted.
Implementation of the Atomic Steps below is authorized.

Parent plan (Atomic Increment 9 of 9, the last increment):
`brain/plans/2026-08-14-casm-phase12-wp68-arithmetic-bitwise-operators.md`.
Prerequisite: Increment 8 (harness and envelope verification), complete,
user-approved, and committed (`42b91ad`).

The parent plan describes this increment as:

> Live end-to-end verification: add production CASM fixtures containing
> mixed-precedence, unary, shift, multiplication/division, and diagnostic
> cases; boot Command64 and run them through the real `casm.prg` under the
> approved VICE MCP workflow, then re-run every harness whose linked shared
> modules or disk placement changed.

## Objective

Close the one real gap left in WP68's own operator inventory: Increment 7
proved the production pipeline (real `casm.prg`, not the synthetic
`exprEvaluate` harness) for exactly one representative operator per family
(`*`, `&`, `<<`, unary `-`) plus relocation rejection, by explicit Scoping
Decision. Four operators from WP64's frozen inventory — `/` (division),
`^` (XOR), `|` (OR), `>>` (right shift) — and one WP68-new diagnostic
(`CASM_DIAG_EXPR_DIV_ZERO`) have only ever been proven against the
synthetic harness (`test_casm_expr`, Increments 5-6), never through the
real production pipeline. This increment adds one more production fixture
pair to close that gap, giving every WP68 operator and its one WP68-new
diagnostic at least one live, real-`casm.prg` proof before WP68's own
Completion Gate can be claimed.

This increment does not re-verify per-operator numeric correctness (closed
in the expression harness), does not repeat Increment 7's already-proven
representative operators/relocation-rejection forms, and does not perform
WP68's own final close-out (KNOWLEDGE.md/wiki/CHANGELOG updates, version
bump, walkthrough doc) — that is a separate step after this increment,
per the phased-planning skill's closing checklist, not part of Increment
9's own charter.

## Scope

**Included:**

- One new production `.seq` fixture exercising `/`, `^`, `|`, `>>` across
  representative operand contexts (immediate, `.BYTE`/`.WORD`), COMP-
  verified against a new hand-derived `.ref.hex`.
- One new forbidden-form `.seq` fixture live-verifying
  `CASM_DIAG_EXPR_DIV_ZERO`'s exact message and location through the real
  production pipeline for the first time (source comment in
  `common.inc:770` still literally says "not yet raised anywhere" and is
  stale as of Increment 6's synthetic-harness wiring; this increment is
  the first real end-to-end proof).
- Packaging both fixtures on `casm_phase12_test_d64` (same disk Increment
  7 used; still comfortably within its `>=40` free-block gate at 452
  blocks free per Increment 8's own measurement).
- Live VICE verification of both fixtures against the real `casm.prg`.
- Re-run of `test_casm_expr`/`test_casm_lexer` to confirm no regression
  (same closing check Increment 7 performed), since this increment
  touches the same shared disk image.

**Excluded:**

- Re-proving `*`, `&`, `<<`, unary `-`, or relocation rejection (already
  closed, Increment 7).
- Any change to `parser.s`/`expr.s`/`emit.s`/`diagnostics.s` — this
  increment expects existing Increment 4-7 behavior to already be correct;
  an unexpected need to change production source is a Stop Condition, not
  silently absorbed scope.
- WP68's own final Completion Gate close-out (docs, `CHANGELOG.md`,
  `KNOWLEDGE.md`, version bump, walkthrough) — a separate step after this
  increment closes.

## Technical Design

### Fixture Set

1. **`casmarith3.seq` — division, XOR, OR, right-shift, every context,
   success.** `.ORG $C000`; representative expressions:
   - `LDA #10/2` (immediate division, result fits zero-page-width 8-bit
     immediate: `$05`)
   - `LDA #$0F^$03` (immediate XOR: `$0C`)
   - `LDA #$0F|$03` (immediate OR: `$0F`)
   - `.BYTE 10/2, $0F^$03` (directive operands)
   - `.WORD $0F|$03, $8001>>1` (`.WORD` operands; `$8001>>1` is a logical,
     zero-filling right shift of a 16-bit value: `$4000`, chosen to prove
     the shift is unsigned/logical, not arithmetic, through the real
     pipeline — the same property `sShr`'s synthetic-harness case already
     established, now proven end-to-end)
   COMP-verified against a new hand-derived `casmarith3.ref.hex`,
   registered in `CASM_REF_NAMES`.
2. **`casmdivzero.seq` — forbidden form, division by a static zero.**
   `LDA #5/0`. No `.ORG` needed either way since this is a static-constant
   division, not a relocation case. No `.ref` (failure case); live-verified
   for the exact `CASM_DIAG_EXPR_DIV_ZERO` message and source location.

Atomic Step 1 (below) confirms the exact expected bytes/diagnostic against
the real `expr.s`/`opcodes.s` code before either fixture is written,
matching Increment 7's and Increment 6's own "audit before asserting"
discipline. Fixture and generated-file names are kept at or under
cc1541's 16-character PETSCII limit (`casmarith3.s` = 12 chars,
`casmdivzero.s` = 13 chars), avoiding the silent-truncation mistake
Increment 7 found and fixed for its own fixture names.

### Disk and COMP Wiring

Same shape as Increment 7: `casm_phase12_test_d64` already carries
`comp.prg`; this increment adds `casmarith3.s`/`.ref` and
`casmdivzero.s` alongside the four Increment 7 fixtures already there.

## Atomic Steps

1. **Audit expected bytes/diagnostic.** Trace `expr.s`'s division,
   XOR/OR, and right-shift implementations (the same code Increment 6
   proved correct in the synthetic harness) against this plan's proposed
   fixture expressions; confirm each hand-derived expected byte and the
   exact `CASM_DIAG_EXPR_DIV_ZERO` trigger point before writing any
   fixture. If any prediction is wrong, stop and report.
2. **`casmarith3.seq` + hand-derived `.ref.hex`.** Add the fixture and its
   trusted reference; wire into `CASM_REF_NAMES`/`casm_phase12_test_d64`;
   verify narrow build and COMP match.
3. **`casmdivzero.seq`.** Add the forbidden-form fixture; no `.ref`
   needed; wire onto `casm_phase12_test_d64`.
4. **Build verification.** Narrow builds, `casm_phase12_test_d64`
   packaging and free-block inspection, full affected-target rebuild,
   no-change rebuild proof (SHA-256 across every touched artifact) —
   matching Increment 7's/8's own bar.
5. **Live VICE verification.** Boot `casm_phase12_test.d64`; run
   `casmarith3.s` through real `casm.prg` with `comp.prg` confirming
   byte-exact output; run `casmdivzero.s` confirming the exact
   `CASM_DIAG_EXPR_DIV_ZERO` message and location; re-run
   `test_casm_expr`/`test_casm_lexer` to confirm no regression. Record
   evidence in the parent WP68 plan's Progress log.

## Expected Files

| File | Planned action |
| --- | --- |
| `cmake/GenerateCasmTestFixtures.cmake` | Add two new `.seq` fixture blocks |
| `tests/fixtures/casm/casmarith3.ref.hex` | Add hand-derived trusted reference |
| `CMakeLists.txt` | Register `casmarith3` in `CASM_REF_NAMES`; add both fixtures/the one ref binary to `casm_phase12_test_d64` |
| `brain/plans/2026-08-14-casm-phase12-wp68-arithmetic-bitwise-operators.md` | Append Atomic Increment 9 progress |
| `brain/task.md`, `wiki/tasks/casm.md` | Append progress at completion |

No `src/external/casm/*.s` production source change is anticipated. An
unexpected need to modify `parser.s`/`emit.s`/`expr.s` requires stopping
and reporting before proceeding.

## Stop Conditions

- Atomic Step 1's audit finds any expected byte or diagnostic prediction
  wrong — stop and report before writing fixtures against a false
  assumption.
- `casmdivzero.seq` fails to raise `CASM_DIAG_EXPR_DIV_ZERO`, or raises it
  at the wrong location.
- `casmarith3.seq`'s real assembled output does not byte-exact-match its
  hand-derived `.ref.hex`.
- `casm_phase12_test_d64`'s free-block gate (`>=40`) is threatened.
- A no-change rebuild changes any artifact or build counter.
- A genuinely new defect outside this plan's scope is discovered —
  disclose and defer unless the user explicitly approves an inline fix.

## Documentation, Task, and DOX Updates

- No new Taskwarrior task; this remains under WP68's existing task 43.
- At completion, append Increment 9 evidence to the parent WP68 plan's
  Progress log; synchronize `brain/task.md`/`wiki/tasks/casm.md`.
- WP68's own final close-out (`brain/KNOWLEDGE.md`, `wiki/casm-utility.md`/
  `docs/casm-utility.md`, `wiki/casm-programmers-reference.md`,
  `CHANGELOG.md`, version bump, `brain/walkthroughs/` doc) happens after
  this increment closes, as WP68's own Completion Gate, not as part of
  this increment.

## Completion Gate

Increment 9 completes only when: `casmarith3.seq` byte-exact matches its
hand-derived reference via COMP; `casmdivzero.seq` raises
`CASM_DIAG_EXPR_DIV_ZERO` with the correct message and location; every
WP64-frozen operator has now been proven at least once through the real
production pipeline; full affected-target build and envelope inspection
pass; no-change rebuild is stable; live VICE evidence is recorded in the
parent WP68 plan's Progress log; and the user explicitly approves closing
Increment 9 — at which point WP68 itself moves to its own final
close-out and completion-gate walkthrough.

## Progress

- 2026-08-15: Drafted this plan after Increment 8's closure and commit
  (`42b91ad`), scoping Increment 9 narrowly around the one real gap in
  WP68's live-verification coverage: `/`, `^`, `|`, `>>`, and
  `CASM_DIAG_EXPR_DIV_ZERO` have never been proven through the real
  production pipeline, only the synthetic expression harness. User
  approved as drafted.
- 2026-08-15: **Atomic Step 1 (audit) complete.** Traced `expr.s:640-731`
  (`staticDiv`/`staticXor`/the `|`-branch/`staticShiftRight`): division is
  the unconditional-zero-check-then-`divUnsigned16` path already proven
  correct in the synthetic harness; XOR is a plain `eor`; OR is a plain
  `ora`; right shift is `lsr`/`ror` on the high/low bytes, zero-filling,
  confirming `$8001>>1 = $4000` is correct. All predicted bytes for
  `casmarith3.seq` and the exact `CASM_DIAG_EXPR_DIV_ZERO` trigger point
  for `casmdivzero.seq` confirmed against source; no correction needed.
- 2026-08-15: **Atomic Steps 2-4 (fixtures, build verification) complete.**
  Added `casmarith3.seq`/`casmdivzero.seq` to
  `cmake/GenerateCasmTestFixtures.cmake`, hand-derived
  `casmarith3.ref.hex` (14 bytes), registered `casmarith3` in
  `CASM_REF_NAMES` and the `test_image_d64` exclusion list (matching
  Increment 7's own precedent), and appended both fixtures plus the one
  `.ref` binary to `casm_phase12_test_d64` via a second `POST_BUILD`
  command block. Full affected-target rebuild (`casm`,
  `test_casm_lexer/expr/pass1/passcheck/frame/listcap`) and full
  affected-disk rebuild (`image_d64` 318, `test_image_d64` 21,
  `casm_listing_test_d64` 11 -- all unchanged; `casm_phase12_test_d64` 449,
  down 3 from Increment 8's 452 for the two new fixtures) both passed. A
  no-change rebuild (SHA-256 across all eleven artifacts, before/after an
  immediate second full rebuild) was identical.
- 2026-08-15: **Atomic Step 5 (live VICE verification) complete.**
  Attached the freshly rebuilt `casm_phase12_test.d64`, booted Command64,
  and ran both fixtures against the real `casm.prg`:
  - `casm casmarith3.s /o:carith3.prg` -> `CASM: INPUT VALIDATED`; `comp
    carith3.prg casmarith3.ref` -> `FILES COMPARE OK`.
  - `casm casmdivzero.s` -> `CASM: EXPRESSION DIVISION BY ZERO AT LINE 1,
    COL 9 (OFFSET 8)`, echoed source `lda #5/0` with caret -- the first
    real end-to-end proof of `CASM_DIAG_EXPR_DIV_ZERO`.
  - `test_casm_expr` re-run: `CASM EXPR: PASS`. `test_casm_lexer` re-run:
    `CASM LEXER: PASS`. Neither regressed.

  A harness-only complication, not a product defect: several shell-dispatch
  attempts for the two re-run harnesses returned spurious `BAD COMMAND OR
  FILE NAME` with a garbled command echo, resolved each time by a fresh
  `flush\n` immediately before retyping the command, per the mandatory
  `.agents/workflows/vice-mcp-testing.md` recovery procedure. Recorded in
  the parent WP68 plan's Progress log; not investigated further as
  out-of-scope for this increment.

  All five Atomic Steps of this plan are complete. This increment's
  Completion Gate is satisfied: `casmarith3.seq` byte-exact matches its
  hand-derived reference via COMP; `casmdivzero.seq` raises
  `CASM_DIAG_EXPR_DIV_ZERO` with the correct message and location; every
  WP64-frozen operator has now been proven at least once through the real
  production pipeline; full affected-target build/envelope inspection and
  no-change rebuild both pass; live VICE evidence is recorded in the
  parent WP68 plan's Progress log. Awaiting the user's explicit approval
  to close Increment 9 -- at which point WP68 itself moves to its own
  final close-out and completion-gate walkthrough.
