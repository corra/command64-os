---
feature: casm-phase12-wp70-relocation-algebra-closure
created: 2026-08-15
status: approved
taskwarrior: 99886bbd-782b-412e-9bd4-efff9c6bfd47
depends-on: WP65-69, all complete
---

# Plan: CASM Phase 12 WP70 — Relocation Algebra Closure

## Status

**Approved 2026-08-15.** The user approved this plan as drafted.
Implementation of the Atomic Steps below is authorized. Taskwarrior task
45 (`99886bbd-782b-412e-9bd4-efff9c6bfd47`) created, depends on WP68/69.

Parent plan:
`brain/plans/2026-08-13-casm-phase12-constants-expanded-expressions.md`.
Prerequisite: WP65 (named constants), WP66 (current-address symbol), WP67
(parentheses/precedence), WP68 (arithmetic/bitwise operators), WP69
(character literals) — all complete and user-approved. WP70 is the last
dependency-spine WP before WP71 (DASH adoption) and WP72 (Phase 12
completion gate).

## Objective

The parent plan describes WP70 as: "Consolidated verification that every
operator/operand combination WP65-69 actually shipped matches WP64's
representability contract exactly: accepted combinations produce correct
R6 relocation entries, rejected combinations produce a clear diagnostic
rather than silently wrong output. This is where the master plan's risk
gate gets its direct proof, not assumed from WP64's design alone."

This WP adds **no new production behavior**. Its job is to trace,
enumerate, and where a genuine gap is found, close it — directly, with
live evidence, not by re-asserting what earlier WPs already proved.

## Research Findings (before drafting scope below)

Traced the actual current code (not assumed) to establish exactly what
WP64's representability contract requires and where each part is proven
today:

1. **Two distinct rules govern relocation, confirmed by reading
   `expr.s`'s `parseOperatorTail` dispatch directly:**
   - `+`/`-` (`checkAddReloc`, pre-existing since before Phase 12): reject
     only when **both** the accumulator and the RHS are relocatable — one
     relocatable component plus any number of static components always
     succeeds.
   - Every WP68 operator (`*`, `/`, `<<`, `>>`, `&`, `^`, `|`) and both
     unary operators (`-`, `~`) (`checkStaticReloc` for binary, an
     equivalent inline check in the unary path): reject if **either**
     operand is relocatable at all — these operators are static-only,
     per WP64's own frozen rule. Confirmed this is one single shared
     routine for all seven binary operators (no per-operator branching
     before the check runs) and one single shared check for both unary
     operators — an operator-specific dispatch bug bypassing the check
     would require a code change to the shared routine itself, not a
     per-operator gap.
2. **The "rejected" side already has live proof for one operator per
   rule**: WP67's `casmparen2.seq` (two relocatable labels via `+`) and
   WP68 Increment 7's `casmareloc1.seq`/`casmareloc2.seq` (`*` applied to
   a real label and a label-derived constant). No live fixture exists for
   any of the other six WP68 static-only operators applied to a real
   relocatable operand — algebraically covered by the shared routine, but
   never proven live for more than one representative.
3. **The "accepted" side has a genuine, unproven gap.** Every existing
   fixture that verifies a real R6 relocation-table entry byte-for-byte
   (`casmrelop1.ref.hex`, `casmrelop2.ref.hex`, `casmreloc1.seq`'s own
   runtime-loading proof) predates Phase 12 entirely and uses the old
   flat, non-parenthesized, single-addend grammar — none of them reach
   WP67's recursive `parsePrimary`/`parseOperatorTail` architecture at
   all. Every Phase 12 fixture that *does* exercise a real relocatable
   label (`casmparen2`, `casmareloc1`/`2`) is a **rejection** case — none
   of them assemble successfully and verify the resulting R6 table.
   **No fixture anywhere proves that a relocatable label combined with a
   static addend, reached through the new precedence-climbing/
   parenthesized architecture, still produces a byte-correct R6
   relocation table entry.** This is the one real, concrete gap this plan
   exists to close.

## Scope

**Included:**

- One new production fixture proving R6 relocation-table byte-exact
  correctness for a relocatable label combined with a static addend via
  `+`, reached through a parenthesized sub-expression, in genuinely
  relocatable (non-`.ORG`) mode — the "accepted" side of WP64's
  representability contract, never previously proven through the new
  architecture.
- One new production fixture applying a second, distinct WP68 static-only
  operator (not `*`, already proven in WP68 Increment 7) to a real
  relocatable label, live — a second live data point for the shared
  `checkStaticReloc` mechanism, complementing the existing algebraic
  proof that it's operator-independent.
- A coverage audit (recorded in this plan and in `brain/KNOWLEDGE.md`)
  enumerating exactly which representability-contract combination is
  proven where (synthetic harness, live production fixture, or both) —
  the direct, checkable evidence the master plan's risk gate calls for.
- Full affected-target/disk-image build verification and a no-change
  rebuild proof, matching every prior Phase 12 WP's own bar.
- Live VICE verification of both new fixtures against the real
  `casm.prg`.

**Excluded:**

- Any production source change — this WP's own research (above) found no
  defect requiring one; if implementation surfaces one, it is disclosed
  and deferred per this plan's own Stop Conditions, not fixed inline
  without explicit approval.
- Re-proving any combination already covered by an existing synthetic or
  live fixture (`casmparen2`, `casmareloc1`/`2`, the 97-case
  `test_casm_expr` harness's own reloc/unresolved cases) — cited, not
  duplicated.
- A full combinatorial matrix of all 7 static-only operators × every
  relocatable-operand kind — the shared-mechanism argument (Research
  Finding 1) makes that redundant; one additional live data point closes
  the gap between "proven algebraically" and "proven live for more than
  one operator," which is what this WP's charter actually calls for.
- WP71 (DASH adoption) and WP72 (Phase 12 completion gate) — separate WPs
  with their own plans.

## Technical Design

### Fixture 1: `casmrelocaccept.seq` — accepted case, R6-verified

A relocatable label combined with a static addend via `+`, inside a
parenthesized sub-expression, in default relocatable output (no `.ORG`):

```asm
START:
    LDA #<(TARGET+1)
TARGET:
    NOP
```

`TARGET` is relocatable; `TARGET+1` combines one relocatable component
with one static component via `+` inside a group — accepted per WP64's
rule, reached through `parsePrimary`'s parenthesized-group recursion
(WP67) for the first time with a genuinely relocatable operand. Atomic
Step 1 (below) hand-derives the exact program bytes and R6 table/footer
entries before any fixture is written, following `casmrelop1.ref.hex`'s
own established full-byte-including-R6-footer format.

### Fixture 2: `casmarelocb.seq` — rejected case, second operator

A real relocatable label combined via `&` (bitwise AND — chosen as a
distinct operator family from WP68 Increment 7's `*`) with a static
value, in default relocatable output:

```asm
LOOP:
    NOP
    LDA #LOOP&$FF
```

Expects `CASM_DIAG_EXPR_RELOC_UNSUPPORTED` at the `&` operator, the same
shape as `casmareloc1.seq` but through a different operator, live-proving
`checkStaticReloc`'s shared mechanism a second time rather than resting
on the algebraic argument alone.

## Atomic Steps

1. **Audit and hand-derive expected bytes.** Confirm this plan's Research
   Findings against a fresh read of the current `expr.s`/`parser.s`/
   `emit.s`/`reloc.s` (in case anything changed since this plan was
   drafted). Hand-derive `casmrelocaccept.seq`'s exact program bytes and
   R6 table/footer entries, matching `casmrelop1.ref.hex`'s own format
   and non-circularity rule (derived from the 6502/R6 spec, never from
   `opcodes.s`/`reloc.s` themselves). Confirm `casmarelocb.seq`'s expected
   diagnostic and location. Stop and report if any Research Finding above
   turns out wrong.
2. **Fixtures.** Add both `.seq` fixtures and `casmrelocaccept.ref.hex`;
   wire into `CASM_REF_NAMES`/disk packaging (`casm_phase12_test_d64`,
   watching its free-block gate — currently 441 free, still comfortably
   above `>=40`, but confirm before and after).
3. **Build verification.** Narrow builds, full affected-target rebuild,
   disk-image packaging, no-change rebuild proof (SHA-256 across every
   touched artifact).
4. **Live VICE verification.** Boot `casm_phase12_test.d64`; run
   `casmrelocaccept.s` through real `casm.prg` with `comp.prg` confirming
   byte-exact output including the R6 table/footer; run `casmarelocb.s`
   confirming the exact `CASM_DIAG_EXPR_RELOC_UNSUPPORTED` message/
   location; re-run every harness whose linked shared modules changed
   (none are expected to, since no production source changes — confirm
   this holds, don't assume).
5. **Coverage audit and close-out.** Record the enumerated coverage table
   in `brain/KNOWLEDGE.md`'s WP70 as-built section; no `docs`/`wiki`
   `casm-utility.md` user-facing change is anticipated (this WP proves
   existing documented behavior, doesn't change or newly document
   syntax); `CHANGELOG.md` entry; version bump per the existing per-WP
   policy; walkthrough; tracker sync.

## Expected Files

| File | Planned action |
| --- | --- |
| `cmake/GenerateCasmTestFixtures.cmake` | Add two new `.seq` fixture blocks |
| `tests/fixtures/casm/casmrelocaccept.ref.hex` | Add hand-derived trusted reference (full R6 table/footer) |
| `CMakeLists.txt` | Register `casmrelocaccept` in `CASM_REF_NAMES`; add both fixtures/the one ref binary to `casm_phase12_test_d64` |
| `brain/KNOWLEDGE.md`, `CHANGELOG.md`, `brain/task.md`, `wiki/tasks/casm.md` | As-built/completion entries |
| `src/external/casm/casm.s` | `VERSION_STAGE` bump only, at completion |

No other `src/external/casm/*.s` change is anticipated. An unexpected need
to modify production source requires stopping and reporting before
proceeding.

## Stop Conditions

- Atomic Step 1's audit finds any Research Finding above wrong (the two-
  rule model, the shared-mechanism claim, or the identified R6 gap) —
  stop and report before writing fixtures against a false premise.
- `casmarelocb.seq` fails to raise `CASM_DIAG_EXPR_RELOC_UNSUPPORTED`, or
  raises it at the wrong location.
- `casmrelocaccept.seq`'s real assembled output (program bytes **and**
  R6 table/footer) does not byte-exact-match its hand-derived reference.
- `casm_phase12_test_d64`'s free-block gate (`>=40`) is threatened.
- A no-change rebuild changes any artifact or build counter.
- A genuinely new defect is discovered (e.g., the shared relocation check
  turns out not to be as uniform as Research Finding 1 claims) —
  disclose and defer unless the user explicitly approves an inline fix.

## Documentation, Task, and DOX Updates

- Create/activate a Taskwarrior task for WP70 under Phase 12, depending
  on WP65-69, once this plan is approved.
- At completion: `brain/KNOWLEDGE.md` as-built section (including the
  coverage-audit table), `CHANGELOG.md` entry, CASM stage-version bump,
  `brain/walkthroughs/` completion-gate doc, `brain/task.md`/
  `wiki/tasks/casm.md` sync. No `docs`/`wiki` `casm-utility.md` change
  anticipated (no new user-facing syntax or semantics).

## Completion Gate

WP70 completes only when: the coverage audit is recorded and every
representability-contract combination is either cited to existing
evidence or newly proven; `casmrelocaccept.seq` byte-exact matches its
hand-derived reference, including the R6 table/footer; `casmarelocb.seq`
raises the correct diagnostic at the correct location; full affected-
target build and envelope inspection pass; no-change rebuild is stable;
live VICE evidence is recorded in a walkthrough; documentation/version/
tracker sync is complete; and the user explicitly approves closing WP70.

## Progress

- 2026-08-15: Drafted this plan after WP69's closure and commit
  (`8fa949e`). Traced `expr.s`'s actual relocation-check code to confirm
  the two-rule model and the shared-mechanism claim before drafting
  scope, and confirmed by reading every Phase 12 fixture's own source
  that no fixture has ever verified a real R6 relocation-table entry
  through the new WP67 architecture — every fixture that reaches a real
  relocatable label either predates Phase 12 (old flat grammar) or is
  itself a rejection case. User approved as drafted; Taskwarrior task 45
  created.
- 2026-08-15: **All Atomic Steps complete.** Fixtures added
  (`casmrelacc.seq`/`casmarelocb.seq`), a genuine hand-derivation mistake
  in `casmrelacc.ref.hex` (missing `JMP MID`'s own R6 entry) found by the
  fixture's own COMP mismatch and corrected from spec, and a
  `hex_manifest_to_bin.py` comment-formatting gotcha (twice) fixed
  before any live testing. Full affected-target/disk rebuild and a
  no-change rebuild proof both passed (no production source changed).
  Live VICE 3.10: `casmrelacc.s` -> `FILES COMPARE OK` (R6 table
  byte-exact after the correction); `casmarelocb.s` -> the exact
  `CASM_DIAG_EXPR_RELOC_UNSUPPORTED` message/location for a second
  distinct operator (`&`); `test_casm_expr`/`test_casm_lexer` both
  re-ran clean. Coverage-audit table recorded in `brain/KNOWLEDGE.md`.
  CASM promoted `0.2.4` -> `0.2.5`, live-verified as `V0.2.5.1312`.
  Walkthrough: `brain/walkthroughs/2026-08-15-casm-phase12-wp70-
  relocation-algebra-closure.md`.

  This WP's Completion Gate is satisfied: coverage audit recorded; both
  fixtures behave exactly as designed; full build/envelope inspection
  and no-change rebuild pass; live VICE evidence recorded; documentation/
  version/tracker sync complete. **WP70 complete, user-approved
  2026-08-15.** Taskwarrior task 45 marked done.
