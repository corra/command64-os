# Plan: CASM Phase 11 WP62 - Documentation Sync

## Status

Drafted 2026-08-12 for user review. No WP62 task, documentation change, or
build-system change is authorized until this plan is explicitly approved.
After approval, each atomic increment remains separately gated by user
review of the preceding increment, per this project's established
convention.

## Objective

Close WP62's charter from the Phase 11 parent plan
(`brain/plans/2026-08-08-casm-phase11-base-release-hardening-documentation.md`):
a **systematic pass, not incidental fixes**, bringing every tier of CASM
documentation back into agreement with the actual shipped `0.2.2` behavior.
Per the governing plan and WP56's own precedent, this starts from a
**clean-room re-read of each doc against current code**, not a diff against
what's already believed correct -- WP54/WP55 already found real,
multi-week-old staleness this way, and this plan's own research already
found more (see Findings below).

WP62 adds no new language feature, directive, or output format, matching
every other Phase 11 work package. It is documentation-only; no CASM source
change is authorized by this plan.

## Prerequisites

- WP56 (contract reconciliation/audit-priority triage), WP60 (opcode/
  addressing/boundary hardening), and WP61 (determinism/remaining spot-
  checks) are complete. CASM is `0.2.2` build `1266`.
- WP56's own remediation plan assigned two items here: the missing Phase 4
  `brain/KNOWLEDGE.md` section, and the general systematic-sync mandate
  itself.

## Findings (from this plan's own pre-drafting research, user-confirmed 2026-08-12)

Beyond WP56's originally-flagged Phase 4 gap, this plan's research found
**`brain/KNOWLEDGE.md` also has no section for Phase 10 or all of Phase 11
(WP56-61)** -- the file's CASM sections stop at `### CASM Phase 9 WP48
Included-Source Diagnostics`. User-confirmed: WP62 backfills all three
gaps (Phase 4, Phase 10, Phase 11), not just Phase 4.

`wiki/casm-programmers-reference.md`, `wiki/casm-utility.md`, and
`docs/casm-utility.md` all still claim `0.2.0` build `1260` -- stale since
WP59 (currently `0.2.2` build `1266`), predating the entirety of WP59's
listing/map hardening completion and all of WP60/WP61. User-confirmed: full
clean-room re-read, not a lighter version-bump-only pass.

`wiki/casm-utility.md` and `docs/casm-utility.md` are byte-identical
duplicates (457 lines each). User-confirmed: keep both in sync rather than
consolidating -- this plan does not investigate why the duplication exists,
only preserves it.

`CHANGELOG.md`'s `[Unreleased]` section has an entry for WP60 but none for
WP61. User-confirmed: WP62 adds one, framed as test-infrastructure/
verification work (WP61 made no production change), matching WP60's own
precedent of logging even mostly-test-only work packages.

## Frozen Scope

**In scope** (per the governing plan, as refined by the findings above):

- `brain/KNOWLEDGE.md`: backfill Phase 4, Phase 10, and Phase 11 (WP56-61)
  contract sections.
- `wiki/casm-programmers-reference.md`: full clean-room re-sync.
- `wiki/casm-utility.md` and `docs/casm-utility.md`: full clean-room
  re-sync, kept identical to each other.
- `CHANGELOG.md`: add the missing WP61 entry; scan the rest of
  `[Unreleased]` for any other gap from WP56-61 found during the sync.
- `src/external/casm/AGENTS.md`: check for durable-contract claims (version-
  stage references, phase-status language) that drifted; other AGENTS.md
  files are out of scope unless a specific CASM-durable-contract claim is
  found stale in one during this pass.
- `brain/task.md` / `wiki/tasks/casm.md`: spot-check for internal
  consistency against this plan's own findings (these are living logs
  already kept current through WP60/WP61; not a rewrite, a verification
  pass).

**Out of scope:**

- Any CASM production source change.
- WP63's verification/walkthrough/completion-gate work.
- Consolidating `wiki/casm-utility.md`/`docs/casm-utility.md` into one file
  (explicitly deferred per the user's decision above).
- Full rewrite of any doc found substantively correct -- this is a sync
  pass, not a rewrite; only actual drift gets changed, and every change is
  traceable to a specific current-code fact it now matches.

**No CASM version bump is planned or authorized.** Documentation-only work
packages do not bump version in this project (WP56's own precedent); WP62
closes at `0.2.2` build `1266` unless a doc-sync pass discloses a genuine
code defect, which would require a separate approved plan to fix, not a
WP62 side effect.

## Method: Clean-Room Re-Read

For each in-scope doc, per increment:

1. Read the doc's current claims in full (not a diff against memory of what
   it "should" say).
2. Independently re-verify each durable claim against current source
   (`.s`/`.inc` files) or, for historical/phase-completion claims, the
   authoritative plan/walkthrough that closed that phase.
3. Record every discrepancy found (stale version/build number, stale
   behavior description, missing feature, superseded diagnostic) before
   editing -- mirroring WP60/WP61's own "register before implementation"
   convention, scaled down for a documentation WP.
4. Edit only what's confirmed stale; leave correct content untouched.
5. Re-read the edited doc once more for internal consistency (a section
   fixed in isolation must not contradict a neighboring section this pass
   didn't touch).

No fixture, build, or live-VICE verification applies to this WP -- its
correctness bar is "does the doc match the code," verified by direct
reading, not by running anything. Increment 7 (audit/walkthrough) still
applies WP60/WP61's row-by-row reconciliation discipline to the sync work
itself.

## `brain/KNOWLEDGE.md` Backfill Source Material

- **Phase 4** (parser completion, opcode table, numeric emission,
  orchestration; WP12-15, closed 2026-07-21): per WP56's own remediation
  note, ground in `brain/plans/2026-07-20-casm-phase4-wp14-orchestration-
  binary-validation.md`, `2026-07-20-casm-phase4-wp15-phase-verification-
  closeout.md`, `2026-07-21-casm-phase4-wp14-test-plan.md`, plus a direct
  re-read of `parser.s`/`opcodes.s`/`emit.s` as they stand today (not as
  those plans described them at the time).
- **Phase 10** (symbol map / listing; WP51-55, closed 2026-08-08): ground
  in `brain/plans/2026-07-29-casm-phase10-symbol-map-listing.md` and the
  WP51-55 walkthroughs, plus a direct re-read of `map.s`/`listing.s`.
- **Phase 11** (base-release hardening; WP56-61, closed 2026-08-12): ground
  in `brain/plans/2026-08-08-casm-phase11-base-release-hardening-
  documentation.md` and every WP56-61 walkthrough/review already produced,
  plus this plan's own record of what changed (only Increment 3 of WP60,
  the `CLD` addition, touched production source across all of Phase 11).
- Each new section follows the exact heading and content convention
  neighboring sections already use (contract statement, frozen ABI/data
  shapes, cross-references) -- confirmed by reading at least two existing
  sections immediately before drafting the new ones, not assumed from
  memory of the convention.

## Expected Files

- `brain/KNOWLEDGE.md`
- `wiki/casm-programmers-reference.md`
- `wiki/casm-utility.md`
- `docs/casm-utility.md`
- `CHANGELOG.md`
- `src/external/casm/AGENTS.md` (only if a stale durable-contract claim is
  found)
- `brain/task.md`, `wiki/tasks/casm.md` (only if the spot-check finds an
  actual inconsistency to fix; not touched otherwise)
- this plan
- a frozen Increment 1 scope/staleness register under `brain/reviews/`
- WP62 walkthrough under `brain/walkthroughs/`

## Atomic Increments

### Increment 1 - Freeze scope and staleness register

- Read every in-scope file in full; record its current claims and every
  discrepancy found against current code/records, per the Method above.
- Confirm the exact source material list for each `KNOWLEDGE.md` backfill
  section.
- Freeze the increment sequencing below and request approval before any
  doc edit begins.

### Increment 2 - `brain/KNOWLEDGE.md` backfill

- Add `### CASM Phase 4 Parser/Opcode/Emission Contract`,
  `### CASM Phase 10 Symbol Map/Listing Contract`, and
  `### CASM Phase 11 Base-Release Hardening Contract` sections, in their
  correct chronological position, matching neighboring sections' heading
  and content convention exactly.
- Re-read the whole file once after all three insertions for ordering/
  cross-reference consistency.

### Increment 3 - `wiki/casm-programmers-reference.md` clean-room re-sync

- Full re-read against current source; fix every confirmed discrepancy
  (version/build banner, `/M`/`/L` status language, opcode/addressing
  coverage claims, any WP59-61-affected section).

### Increment 4 - `wiki/casm-utility.md` / `docs/casm-utility.md` re-sync

- Full re-read against current source and current CLI/diagnostic behavior;
  fix every confirmed discrepancy in one copy, then make the other
  byte-identical to it.

### Increment 5 - `CHANGELOG.md` sync

- Add the missing WP61 `[Unreleased]` entry (test-infrastructure/
  verification framing, no production change).
- Scan the rest of `[Unreleased]` for any other WP56-61 gap surfaced during
  Increments 2-4's research; add only confirmed-missing entries.

### Increment 6 - AGENTS.md / DOX pass

- Re-read `src/external/casm/AGENTS.md` in full; fix any durable-contract
  claim (version-stage references, phase-status language) confirmed stale.
- Note explicitly if no change is needed (a clean result is still a
  recorded finding, not a skipped step).

### Increment 7 - Audit and walkthrough, completion gate

- Row-by-row reconciliation of the Increment 1 register against what
  Increments 2-6 actually closed.
- Spot-check `brain/task.md`/`wiki/tasks/casm.md` for internal consistency
  against this plan's own findings; fix only if an actual inconsistency is
  found.
- Record metrics (files touched, discrepancies found/fixed, sections
  added), confirm no CASM version bump occurred, and record the walkthrough.
- Request explicit WP62 completion approval.

## Stop Conditions

Stop and request user direction if:

- a doc-sync pass discloses a genuine CASM production code defect (not just
  a doc/code mismatch where the doc is wrong) -- this becomes a separate
  approved item, not a WP62 side-fix;
- the `KNOWLEDGE.md` heading/content convention this plan assumes turns out
  not to match what Increment 2 actually finds in neighboring sections;
- a doc claim cannot be resolved as clearly stale or clearly correct without
  a decision only the user can make (e.g., a genuinely ambiguous behavior
  description);
- work expands into WP63's verification/walkthrough/completion-gate
  territory.

## Completion Criteria

WP62 completes only when:

1. `brain/KNOWLEDGE.md` has Phase 4, Phase 10, and Phase 11 sections,
   matching the existing heading/content convention;
2. `wiki/casm-programmers-reference.md`, `wiki/casm-utility.md`, and
   `docs/casm-utility.md` all reflect current `0.2.2` behavior, verified by
   clean-room re-read, not assumed correct;
3. `wiki/casm-utility.md` and `docs/casm-utility.md` remain byte-identical;
4. `CHANGELOG.md` has a WP61 entry and no other WP56-61 gap found during
   this pass is left unaddressed;
5. `src/external/casm/AGENTS.md` is confirmed current or corrected;
6. no CASM production source or version changed;
7. records, walkthrough, and Taskwarrior agree;
8. the user explicitly approves completion.

## Approval Decision

Approve this seven-increment WP62 plan and activate Increment 1 only, or
request changes. Approval creates a WP62 Taskwarrior task dependent on
completed WP61 and updates task records; it does not authorize later
increments before their individual gates.
