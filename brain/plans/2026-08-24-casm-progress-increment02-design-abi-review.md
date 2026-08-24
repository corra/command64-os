---
feature: casm-progress-increment02-design-abi-review
created: 2026-08-24
status: proposed
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment01-activation-baseline, approved and complete
---

# Plan: CASM Progress Increment 2 - Design and ABI Review

## Status

**Proposed, not yet approved.** This review freezes implementation contracts; it
does not add production behavior. Parent plan:
`brain/plans/2026-07-29-casm-feature-progress-indication.md`.

## Objective

Turn the parent UX into an exact 6510-callable ABI, bounded storage layout,
screen protocol, call-site map, diagnostics allocation, and test architecture.

## Proposed Design Decisions Requiring Approval

1. Count a statement after successful parsing and explicit classification as
   label, constant, mnemonic, or directive, immediately before dispatch. A later
   semantic failure does not roll back the display count.
2. Final output bytes mean the complete physical PRG/R6 artifact: PRG header,
   body, relocation table, and footer; listing bytes are excluded.
3. Rendering/transition notifications after committed source or file state are
   best-effort and cannot replace the primary assembler diagnostic. Counter
   overflow and Pass 1/Pass 2 disagreement remain fatal semantic checks.
4. Add a focused `test_casm_progress` harness and a self-bootable,
   writable `casm_progress_test_d64`; do not consume constrained existing disks.
5. `progress.s` owns minimal private formatting and imports no fatal diagnostic
   renderer, preventing a `diagnostics.s`/`progress.s` cycle.

## ABI and Storage Contract

- Freeze each routine's inputs, outputs, A/X/Y preservation, carry/zero meaning,
  stack use, and legal call phases in an interface table before source edits.
- Keep state in bounded BSS: two pass totals, active count, redraw divider,
  activity/visibility/suspension flags, artifact byte count, operation count,
  and bounded 40-column rendering scratch.
- Add no zero-page storage and enlarge no parser, token, include, frame, symbol,
  listing, map, relocation, or directive record.
- Make clear/suspend idempotent. Preserve diagnostic A at `diagPrintFatal`.
- Define exact 40-column PETSCII rows, cursor-return/erase sequence, filename
  truncation, decimal widths, and behavior at field maxima.
- Freeze hooks at `casmRunPass`, pass transitions, committed source blocks,
  committed root/frame transitions, bounded directive chunks, primary-output
  writes, diagnostic entry, and listing/map orchestration boundaries.

## Atomic Increments

1. Re-read Increment 1 evidence and current source contracts.
2. Resolve the five proposed decisions with the user.
3. Produce routine ABI, BSS byte map, call graph, screen layouts, diagnostic IDs,
   artifact-byte semantics, and rendering-failure policy.
4. Prove no import cycle, record growth, zero-page growth, or unbounded loop.
5. Freeze focused harness and dedicated-disk contracts.
6. Complete a static peer review and write the walkthrough.

## Expected Files

| File | Planned action |
| --- | --- |
| This plan | Record approved decisions and frozen tables |
| Parent plan | Amend only if approved decisions change its contract |
| `brain/reviews/2026-08-24-casm-progress-design-abi-review.md` | Create |
| Matching walkthrough | Create |

## Stop Conditions

Stop for any required zero-page byte, record growth, unresolved import cycle,
unbounded rendering path, uncertain screen protocol, envelope increase without
measurement, failed static review, or newly discovered out-of-scope defect.

## Documentation, Task, and DOX Updates

Record the approved ABI in this plan and task trackers. Update programmer-facing
docs only when implementation ships. Update DOX only if a durable boundary or
verification rule changes.

## Completion Gate

Every ABI/storage/layout decision is explicit, peer review has no unresolved
finding, the walkthrough exists, trackers agree, and the user approves the
design before Increment 3 source edits.

## Progress

- 2026-08-24: Detailed plan drafted with five proposed decisions.
