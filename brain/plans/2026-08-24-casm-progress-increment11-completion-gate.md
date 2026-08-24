---
feature: casm-progress-increment11-completion-gate
created: 2026-08-24
status: proposed
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment10-runtime-acceptance, approved and complete
---

# Plan: CASM Progress Increment 11 - Completion Gate

## Status

**Proposed, not yet approved.** This increment reconciles and closes the feature;
it adds no new production behavior.

## Objective

Perform a fresh consolidated verification of the final candidate, promote the
version/build only as approved, synchronize every durable record, and obtain
explicit feature-completion sign-off.

## Consolidated Gate

- Re-run the complete focused, regression, artifact, disk, cleanup, timing, and
  runtime matrix together against the final candidate; do not cite earlier
  increment evidence as a substitute.
- Verify static and R6 bytes, listing files, map output, progress totals, physical
  output-byte totals, version/build output, disk inventory, and shell return.
- Perform a clean build and exact no-change rebuild through CMake.
- Reinspect MAIN/BSS/envelopes, zero page, imports/exports, handles/VMM cleanup,
  test disk writable reserve, and all stop-condition dispositions.
- Update version/build only at the approved point and re-run affected evidence.
- Preserve `/q`, cancellation, duration, real-time `/M`, and the one-byte SEQ/EOI
  defect as separate backlog/out-of-scope records.

## Atomic Increments

1. Freeze final candidate and consolidated matrix checklist.
2. Clean-build every affected target/image and run all automated harnesses.
3. Run one continuous live VICE success/failure/cleanup session.
4. Perform artifact, timing, memory, disk, and no-change audits.
5. Apply approved version/build promotion and repeat affected checks.
6. Update changelog, user/programmer docs, task records, knowledge, memory, DOX,
   parent plan, and final completion walkthrough.
7. Present evidence and ask whether the feature is complete.

## Expected Files

| File | Planned action |
| --- | --- |
| `brain/walkthroughs/2026-08-24-casm-progress-increment11-completion-gate.md` | Create |
| Parent and increment plans | Final status/progress reconciliation after approval |
| `CHANGELOG.md`, `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `brain/task.md` | Update |
| `wiki/tasks/casm-progress-indication.md`, `wiki/tasks/casm.md`, Taskwarrior | Synchronize |
| CASM user/programmer docs and mirrors | Document shipped behavior |
| Applicable AGENTS.md files | DOX pass; modify only for durable contract/index changes |

## Stop Conditions

Stop on any consolidated failure, stale or contradictory record, artifact/timing/
memory/disk regression, no-change drift, unavailable required live verification,
unresolved review finding, or new defect. Do not mark complete partially.

## Documentation, Task, and DOX Updates

This increment owns final synchronization. Wiki-first mirrored documents must be
kept byte-identical where required. Taskwarrior and markdown trackers close only
after explicit user sign-off. Perform and report the full DOX closeout.

## Completion Gate

The consolidated walkthrough contains fresh evidence for every acceptance area,
all records agree, the final candidate is reproducible, and the user explicitly
approves marking the progress feature complete. Until then it remains pending.

## Progress

- 2026-08-24: Detailed completion-gate plan drafted; feature remains pending.
