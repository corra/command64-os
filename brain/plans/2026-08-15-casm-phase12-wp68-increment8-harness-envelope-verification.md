---
feature: casm-phase12-wp68-increment8-harness-envelope-verification
created: 2026-08-15
status: approved
taskwarrior: c1b8e145-0a9c-4e15-aaab-4e82fc253363 (WP68, task 43)
depends-on: WP68 Increment 7, complete
---

# Plan: CASM Phase 12 WP68 Increment 8 - Harness and Envelope Verification

## Status

**Approved 2026-08-15.** The user approved this plan as drafted.
Implementation of the Atomic Steps below is authorized.

Parent plan (Atomic Increment 8 of 9):
`brain/plans/2026-08-14-casm-phase12-wp68-arithmetic-bitwise-operators.md`.
Prerequisite: Increment 7 (relocation, unresolved, and parser integration),
complete, user-approved, and committed (`4cc412f`).

The parent plan describes this increment as:

> Harness and envelope verification: expand the existing CASM lexer,
> expression, parser/pass, and diagnostics harnesses; run the full affected
> target set and disk-image build; inspect PRG/R6 sizes and relocation
> counts; confirm the `$6000` production cap and every test cap still hold,
> and confirm a no-change rebuild changes no artifact/build number.

## Objective

Perform one **consolidated** verification pass over the complete WP68 diff
accumulated across Increments 1-7 (token/lexer, precedence dispatcher,
bitwise/shift/unary operators, checked multiply/divide, and production
parser integration) -- not a slice of it. This increment adds no new
production behavior and, per the audit in this plan's own Atomic Step 1,
is expected to require no new harness test cases either: every increment
from 2 onward already expanded its own directly-relevant harness (lexer
cases in Increment 2, expression/diagnostic cases in Increments 3-6,
production parser-integration fixtures in Increment 7), each individually
build-verified and no-change-rebuild-checked at the time. What has *not*
yet happened is a single build/envelope/no-change-rebuild sweep run against
the *final, complete* WP68 diff as one unit -- confirming nothing in a
later increment silently regressed an earlier one's envelope or counters,
and giving one authoritative, consolidated measurement to cite from the
parent plan's Completion Gate instead of stitching together seven
per-increment claims.

This increment does **not** add new CASM source behavior, does not add new
production end-to-end fixtures (that is Increment 9's charter), and does
not re-litigate any per-operator correctness question already closed by
Increments 4-7.

## Scoping Decisions (user-confirmed 2026-08-15)

1. **Consolidation, not expansion, is this increment's real content.**
   Textual support: Increment 7's own subordinate plan explicitly excluded
   "WP68 Atomic Increment 8/9's own full affected-target build/envelope
   sweep and Phase-12-wide production fixture matrix (this increment's own
   Completion Gate only requires the narrower checks below; the parent
   plan's Increment 8/9 run the broader pass again over WP68's complete,
   final diff)" -- i.e. Increment 8 was always intended as the point where
   the accumulated diff gets swept as a whole, not as a vehicle for new
   test cases. Atomic Step 1 below audits the existing lexer/expression/
   pass1/passcheck/diagnostics harnesses against WP64's frozen operator
   inventory to confirm no case is actually missing before relying on this
   assumption; if the audit finds a real gap, this plan stops and reports
   before any harness file is touched.
2. **`$6000` in the parent plan's own Increment 8 charter text is stale.**
   The production cap was already raised to `$6100` during Increment 6
   (`CMakeLists.txt`, user-approved 2026-08-15, "WP68 Increment 6 Atomic
   Step 5"). This increment confirms the *current, real* cap (`$6100`) and
   every current test cap still hold against the complete diff -- it does
   not reopen or re-justify the `$6100` decision itself.

## Scope

**Included:**

- Full affected-target rebuild from clean: `casm`, `test_casm_lexer`,
  `test_casm_expr`, `test_casm_pass1`, `test_casm_passcheck`,
  `test_casm_frame`, `test_casm_listcap` (every target Increments 1-7
  touched or linked `parser.s`/`expr.s`/`lexer.s`/`diagnostics.s` into).
- Full rebuild of every disk image carrying an affected target:
  `image_d64`, `test_image_d64`, `casm_listing_test_d64`,
  `casm_phase12_test_d64`.
- PRG size and R6 relocation-record count inspection for every affected
  target, against its current approved cap.
- Free-block inspection for every affected disk image against its own
  established gate.
- One consolidated no-change rebuild proof (SHA-256 across every touched
  PRG/R6/disk image, before/after an immediate second full rebuild).
- The Atomic Step 1 harness-completeness audit described above.

**Excluded:**

- New production CASM source changes.
- New production end-to-end CASM fixtures exercising the new operators
  (Increment 9's charter).
- Any new unit-level lexer/expression/pass1/passcheck test case, *unless*
  Atomic Step 1's audit finds a genuine gap -- in which case this plan
  stops and reports rather than silently absorbing new scope.
- Re-running live VICE verification of behavior already live-verified in
  Increments 6/7 (no behavior changes here to re-verify; Increment 9 will
  do the next live pass over its own new fixtures).

## Atomic Steps

1. **Harness-completeness audit.** Re-read WP64's frozen operator
   inventory (`brain/plans/2026-08-13-casm-phase12-wp64-contract-freeze.md`)
   against the current case tables in `tests/src/casm_lexer/casm_lexer.s`,
   `tests/src/casm_expr/casm_expr.s`, and the diagnostic paths exercised
   there, plus `tests/src/casm_pass1/casm_pass1.s` /
   `tests/src/casm_passcheck/casm_passcheck.s`. Confirm every operator,
   precedence interaction, overflow/boundary case, and diagnostic already
   has harness coverage from a prior increment. If a real gap is found,
   stop and report before writing any new case (Scoping Decision 1).
2. **Full affected-target clean rebuild.** Rebuild `casm` and all six
   listed test harnesses from a clean `build/` tree; record PRG byte size
   and R6 relocation-record count for each against its current cap.
3. **Full affected disk-image rebuild.** Rebuild `image_d64`,
   `test_image_d64`, `casm_listing_test_d64`, `casm_phase12_test_d64`;
   record free-block counts against each disk's own established gate.
4. **No-change rebuild proof.** Immediately rebuild every target and disk
   image from Steps 2-3 a second time; SHA-256-compare every artifact
   against the first build. Any difference is a Stop Condition.
5. **Record consolidated evidence.** Append a single consolidated
   measurement table (target/size/cap/headroom, disk/free-blocks/gate) to
   the parent WP68 plan's Progress log, superseding the need to
   cross-reference each increment's own individual numbers.

## Expected Files

| File | Planned action |
| --- | --- |
| `brain/plans/2026-08-14-casm-phase12-wp68-arithmetic-bitwise-operators.md` | Append Atomic Increment 8 progress and consolidated measurement table |
| `brain/task.md`, `wiki/tasks/casm.md` | Append progress at completion |

No `src/external/casm/*.s`, `tests/src/casm_*/*.s`, `CMakeLists.txt`, or
`cmake/GenerateCasmTestFixtures.cmake` change is anticipated. An unexpected
need to modify any of them -- including a real gap found in Atomic Step 1 --
requires stopping and reporting before proceeding (see Stop Conditions).

## Stop Conditions

- Atomic Step 1's audit finds a genuine harness gap (an operator,
  precedence interaction, boundary case, or diagnostic with no existing
  coverage) -- stop and report before adding any case.
- Any affected target's PRG size or R6 relocation-record count exceeds its
  current approved cap.
- Any affected disk image's free-block count falls below its own
  established gate.
- A no-change rebuild changes any artifact, build counter, or PRG/disk
  SHA-256.
- Any harness fails unexpectedly during the clean rebuild -- root-cause
  before proposing any correction; do not silently re-run past a failure.
- A genuinely new defect outside this plan's scope is discovered --
  disclose and defer unless the user explicitly approves an inline fix.

## Documentation, Task, and DOX Updates

- No new Taskwarrior task; this remains under WP68's existing task 43.
- At completion, append the consolidated measurement table and Increment 8
  evidence to the parent WP68 plan's Progress log; synchronize
  `brain/task.md`/`wiki/tasks/casm.md`.
- No `AGENTS.md`/wiki/doc changes anticipated -- this increment verifies,
  it does not change, any durable contract.

## Completion Gate

Increment 8 completes only when: the Atomic Step 1 audit confirms no
harness gap (or any found gap has been disclosed, scoped, and separately
approved); every affected target's clean-build size/relocation count is
recorded and within its current cap; every affected disk image's
free-block count is recorded and within its gate; the no-change rebuild
proof is stable across every affected artifact; the consolidated evidence
is recorded in the parent WP68 plan's Progress log; and the user explicitly
approves closing Increment 8 and proceeding to Atomic Increment 9.

## Progress

- 2026-08-15: Drafted this plan after Increment 7's closure and commit
  (`4cc412f`), scoping Increment 8 as a consolidation-only verification
  pass per Increment 7's own forward-reference to it, and flagging the
  parent plan's `$6000` charter text as stale against the real, current
  `$6100` cap. User approved as drafted.
- 2026-08-15: **Atomic Step 1 (harness-completeness audit) complete.**
  Re-read WP64's frozen operator inventory (`*`, `/`, `<<`, `>>`, `&`, `|`,
  `^`, unary `~`, unary `-`) and its 7-tier precedence ordering against the
  current `tests/src/casm_lexer/casm_lexer.s` two-char/punctuation token
  table and `tests/src/casm_expr/casm_expr.s`'s 97-case table (script
  labels swept: every operator, chained-unary, mixed-precedence,
  overflow/truncation/boundary, division-by-zero, relocation-rejection,
  and unresolved-symbol case already present, added across Increments
  2-7). No gap found; no new harness case needed (Scoping Decision 1
  confirmed as assumed).
- 2026-08-15: **Atomic Steps 2-4 (build/envelope/no-change-rebuild)
  complete.** Full clean rebuild (`build/` removed, reconfigured) of
  `casm` and all six affected test harnesses, plus all four affected disk
  images. Every target's code-byte size and every disk's free-block count
  recorded against its current cap/gate -- all comfortably within bounds
  (`test_casm_expr` tightest at 158 bytes headroom, matching its known
  tight envelope from Increment 6). Immediate second full rebuild of every
  target and disk image; SHA-256 of all eleven artifacts identical before
  and after -- no-change rebuild confirmed stable.
- 2026-08-15: **Atomic Step 5 (record consolidated evidence) complete.**
  Consolidated measurement table (target/size/cap/headroom,
  disk/free-blocks/gate) appended to the parent WP68 plan's Progress log.

  All five Atomic Steps of this plan are complete. This increment's
  Completion Gate is satisfied: the harness-completeness audit found no
  gap; every affected target and disk image is recorded within its
  current cap/gate; the no-change rebuild proof is stable; consolidated
  evidence is recorded in the parent plan. Awaiting the user's explicit
  approval to close Increment 8 and proceed to Atomic Increment 9.
