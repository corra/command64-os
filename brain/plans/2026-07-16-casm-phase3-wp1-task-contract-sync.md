---
feature: casm-native-assembler
phase: 3
work-package: 1
created: 2026-07-16
status: approved
depends-on: casm-phase-3-source-stream-lexer-plan
---

# CASM Phase 3 Work Package 1: Task and Contract Synchronization

Approved by the user on 2026-07-16. This work package establishes Phase 3 as
the active CASM milestone, applies the approved dependency corrections, and
records Phase 0C.1 without changing CASM source or build behavior.

## Objective

Synchronize Taskwarrior, `wiki/tasks/casm.md`, and `brain/task.md`; correct the
master and Phase 2 dependency records; record the approved Phase 0C.1 contract;
and update the CASM-local DOX contract before implementation work begins.

## Preconditions

- CASM Phase 2 remains completed as Taskwarrior task `df2f766c`.
- The Phase 3 parent plan and this work-package plan are user-approved.
- Unrelated repository and Taskwarrior state must remain unchanged.
- No CASM source, CMake, fixture, build-counter, or walkthrough change is in
  scope.

## Files in Scope

| Path | Action |
|---|---|
| `wiki/tasks/casm.md` | Make Phase 3 current and add its gate, subtasks, and acceptance criteria |
| `brain/task.md` | Add matching Taskwarrior identifiers and status |
| `brain/plans/2026-07-16-casm-assembler-implementation-plan.md` | Correct the dependency chain |
| `brain/plans/2026-07-16-casm-phase2-cli-file-services.md` | Correct Phase 5 output references to Phase 4 |
| `brain/KNOWLEDGE.md` | Record approved Phase 0C.1 and dependency decisions |
| `src/external/casm/AGENTS.md` | Record incremental Phase 0C gates and Phase 3 boundaries |

`CHANGELOG.md` remains unchanged because this package changes planning and task
metadata, not functional behavior.

## Increment 1.1: Taskwarrior Hierarchy

Create one active parent task named `CASM Phase 3 source stream and minimal
lexer` with project `command64.casm`, medium priority, tags `casm` and `phase3`,
and a dependency on completed Phase 2 task `df2f766c`.

Create eleven measurable child tasks matching the parent plan:

1. Synchronize tasks and Phase 0C.1 contracts.
2. Investigate DEBUG assembler reuse feasibility.
3. Declare source/lexer ABI and bounded state.
4. Implement rewindable source backend.
5. Implement newline normalization and provenance.
6. Implement deterministic rewind and bounded line API.
7. Implement minimal lexer core.
8. Implement textual and numeric lexical tokens.
9. Implement mnemonic classification.
10. Implement diagnostics and token dump.
11. Verify artifacts and obtain runtime confirmation.

Dependencies form a strict WP1 through WP11 chain. The parent depends on every
child. Only WP1 becomes active; WP2 through WP11 remain pending.

Verification exports the new records and checks project, tags, descriptions,
UUIDs, statuses, and dependencies. Phase 2 and unrelated tasks must remain
unchanged. Stop if the hierarchy cannot be represented without modifying
unrelated records.

## Increment 1.2: Wiki Task Synchronization

Update `wiki/tasks/casm.md` to:

- mark Phase 3 as the current in-progress milestone;
- reference the Phase 3 parent Taskwarrior ID/UUID and plan;
- retain completed Phase 1 and Phase 2 history verbatim;
- record completed Phase 2, approved Phase 3 plan, and approved Phase 0C.1 as
  prerequisites;
- list the eleven child UUIDs with WP1 in progress and WP2-WP11 pending; and
- add measurable Phase 3 acceptance criteria from the parent plan.

Every Phase 3 UUID must appear exactly once and every status must match
Taskwarrior.

## Increment 1.3: Brain Task Synchronization

Add the Phase 3 parent and eleven children after the completed Phase 2 block in
`brain/task.md`. Use Taskwarrior's reported IDs and UUIDs; do not manually
renumber existing tasks. Descriptions and status markers must agree with
Taskwarrior and `wiki/tasks/casm.md`.

## Increment 1.4: Master Dependency Corrections

Update `brain/plans/2026-07-16-casm-assembler-implementation-plan.md` to:

1. rename Phase 4 to **Statement Parser, Opcode Table, and Numeric Static
   Assembly**;
2. assign bounded statement parsing, numeric conversion, addressing syntax,
   `.org`/`.byte`/`.word`, trailing-token rejection, and static output
   activation to Phase 4;
3. divide Phase 6 into Phase 6A VMM storage foundation and Phase 6B symbol
   table/two-pass assembly;
4. make Phase 6B depend on Phase 6A and Phase 7 reuse Phase 6A storage;
5. replace monolithic Phase 0C with Phase 0C.1 through Phase 0C.5;
6. replace the critical path with the approved corrected chain; and
7. reference the dedicated Phase 3 plan.

Later public phase numbers remain stable.

## Increment 1.5: Phase 2 Reference Corrections

In `brain/plans/2026-07-16-casm-phase2-cli-file-services.md`, change only
references where Phase 5 incorrectly means numeric static output or production
output activation. Those references become `Phase 4 numeric static-output
consumer`. Genuine references to the Phase 5 expression evaluator remain.

Add a short correction note stating that Phase 2 behavior did not change; only
the downstream phase assignment was corrected. A final search must classify
every remaining `Phase 5` occurrence and find no output-activation references.

## Increment 1.6: Phase 0C.1 Knowledge Record

Add a concise dated CASM entry to `brain/KNOWLEDGE.md` recording:

- one top-level source and reuse of the existing 256-byte input buffer;
- close/reopen rewind;
- CR/LF/CRLF normalization;
- one-based file/line/column provenance;
- 255-byte logical lines and 31-byte token text;
- identifier and numeric lexical grammar;
- token categories and case rules;
- mandatory DEBUG reuse investigation before mnemonic implementation; and
- deferral of statement parsing and emission to Phase 4.

The knowledge record summarizes durable decisions and does not duplicate the
full parent plan.

## Increment 1.7: CASM DOX Update

Update `src/external/casm/AGENTS.md` to replace the broad later-Phase-0C wording
with the approved Phase 0C.1-0C.5 gate model. Record only operational Phase 3
rules: reuse the existing input buffer, preserve provenance, use close/reopen
rewind, keep statement parsing out of Phase 3, and complete DEBUG reuse analysis
before mnemonic-table implementation.

No parent Child DOX Index changes are required because no ownership boundary is
created.

## Verification

1. Export CASM Taskwarrior records.
2. Compare UUIDs, statuses, descriptions, and dependencies with both task files.
3. Confirm Phase 1 and Phase 2 histories remain completed and intact.
4. Search the Phase 2 plan for incorrect output-related Phase 5 references.
5. Confirm the master plan contains the corrected Phase 4 and Phase 6A/6B.
6. Confirm Phase 0C.1-0C.5 are consistent across plans, knowledge, and DOX.
7. Confirm no source, build, fixture, build-counter, or walkthrough file changed.
8. Run `git diff --check` and inspect `git diff --stat`.
9. Confirm unrelated working-tree changes remain present and unchanged.
10. Perform the required DOX closeout pass.

No build is required because WP1 changes planning and task metadata only.

## Stop Conditions

Stop and request direction if:

- Taskwarrior dependencies require altering unrelated tasks;
- an existing CASM Phase 3 task hierarchy conflicts with this plan;
- dependency corrections would renumber later public phases;
- an applicable DOX contract conflicts with the approved Phase 0C.1 values; or
- any requested edit requires changing CASM source or build behavior.

## Completion Gate

WP1 is ready for completion approval only when:

- the Taskwarrior parent and eleven children exist;
- WP1 alone is active;
- UUIDs and states agree across Taskwarrior and both task files;
- all approved dependency corrections are present;
- Phase 0C.1 is recorded in knowledge and CASM DOX;
- completed Phase 1 and Phase 2 records remain intact;
- no CASM source or build file changed;
- no unrelated Taskwarrior or repository state changed;
- verification passes; and
- the user explicitly approves marking WP1 complete.

