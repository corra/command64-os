---
feature: casm-dash-wp10-documentation-completion-gate
created: 2026-07-26
updated: 2026-07-30
status: complete (user-approved 2026-07-30)
---

# Plan: DASH WP10 - Documentation and Completion Gate

## Objective

Document the final as-built DASH application and native CASM workflow,
synchronize required public and durable records, perform the DOX closeout,
present all static/runtime evidence, and ask for explicit completion approval.

WP10 makes no functional implementation change unless a separately approved
documentation discrepancy plan explicitly includes it.

## Prerequisites

- WP9 matrix passed and explicitly approved.
- Final binary hash, size, origin, R6 count, disk location, and controls known.
- User supplied all required runtime results.
- API and memory contracts are stable.
- No unresolved blocker or unexplained anomaly remains.
- Exact tasks/Taskwarrior records to close are identified, but remain open.

## Mandatory Activation Review

Re-read all changed code, final behavior, parent/WP plans, public docs, task
records, changelog, knowledge/memory, walkthrough conventions, and applicable
DOX chains.

Any material discrepancy in behavior, command syntax, API, artifact,
documentation ownership/mirroring, tasks, versioning, or closeout evidence
stops work. Record expected/observed behavior and root cause, amend the plan or
create the proper remediation WP, and obtain renewed approval. Documentation
must not conceal or normalize an implementation defect.

## Known Documentation Discrepancy

`wiki/casm-utility.md` may still claim one source, mandatory `.ORG`, no labels,
and no relocation support. Before adding a DASH command example:

- Reconcile it comprehensively to current as-built CASM behavior, or
- Stop and create a separate CASM documentation reconciliation package.

Do not insert a narrow DASH example into surrounding contradictory guidance.

## Expected Public Documentation

Likely:

- `wiki/dash-utility.md`
- `wiki/Home.md`
- `wiki/casm-utility.md`
- `wiki/casm-programmers-reference.md`
- `wiki/api-reference.md` and byte-identical `docs/api-reference.md`
- `wiki/programmers-reference.md` and mirror
- `wiki/user-manual.md` and mirror

Mirrored pairs must remain byte-identical. DASH's application-specific manual
belongs in `wiki/` unless an approved project convention adds another copy.

## DASH Manual Contract

Document:

1. Purpose, command name, disk filename, and supported hardware.
2. Runtime with optional REU versus native assembly requiring REU/VMM.
3. Exact ordered source filenames and native CASM command.
4. Source/candidate/reviewed shipping artifact distinction.
5. Default and explicit relocated launch syntax.
6. F1/F3/F5/R/T/Q controls.
7. System fields and `N/A` validity behavior.
8. Application columns, name truncation, inclusive ranges, and U/R/V/S
   meanings/limitations.
9. VMM patterns, states, cleanup, and cleanup-failure response.
10. Memory/ZP/public API contract and prohibited private access.
11. R6 relocation behavior and verification at three addresses.
12. Known limitations and troubleshooting by failure stage.
13. Final version/build/hash only where repository convention requires it.

## Durable Records

Review/update as warranted by actual implementation:

- `CHANGELOG.md`
- `brain/KNOWLEDGE.md`
- `brain/MEMORY.md` only if memory ownership/layout changed
- `brain/task.md`
- `wiki/tasks/*.md`
- Taskwarrior records
- Parent and WP plan status
- New walkthrough under `brain/walkthroughs/`

Do not create or complete tasks during this planning pass. During WP10,
completion state remains pending until the user approves the walkthrough.

## DOX Closeout

For every changed path:

1. Re-read root-to-nearest AGENTS chain.
2. Update nearest ownership/contracts only when behavior, artifacts, workflow,
   or structure changed.
3. Refresh affected Child DOX Index entries.
4. Remove stale or contradictory text.
5. State which applicable docs were intentionally unchanged and why.

Likely review set includes root, `src`, `src/external`, `src/external/dash`,
`tests`, `wiki`, and `wiki/tasks` AGENTS files.

## Atomic Increments

1. Reconcile live CASM behavior with stale CASM public documentation.
2. Add/update DASH manual and wiki navigation.
3. Synchronize API/programmer/user docs and mirrors.
4. Update changelog, knowledge, and memory only as warranted.
5. Draft task/state changes but do not mark complete.
6. Perform full DOX pass and link/mirror checks.
7. Prepare final walkthrough with all evidence/anomalies.
8. Present walkthrough and ask whether DASH/WP10 are complete.
9. Only after approval, synchronize task, Taskwarrior, plan, version, and final
   completion records in a separate closeout increment.
10. Verify closeout-only diff and no-change build stability.

## Documentation Verification

- DASH manual matches final behavior and exact command.
- API records/statuses match both include dialects and implementation.
- Wiki/docs mirrored pairs are byte-identical.
- User memory/protection statements match `$C000` MCT ownership.
- Wiki Home links to DASH.
- Changelog claims only verified behavior.
- Knowledge records durable architecture, not session diary.
- Memory changes only for actual ownership/address changes.
- Task checkboxes, `brain/task.md`, and Taskwarrior remain synchronized.
- Plans/walkthrough do not say complete before approval.
- Relative links resolve by inspection.
- Git diff contains no unrelated edits.

## Walkthrough Contract

Include:

- Baseline commit, OS/CASM/DASH versions, approved plans, and prerequisites.
- Every delivered source, API, test, artifact, build, doc, task, and DOX file.
- Configure/build results, PRG size/header/hash, R6 count/footer, disk inventory,
  and no-change rebuild evidence.
- Complete expected/actual relocation ledger and fixed/private exclusions.
- Runtime result rows for `$3800/$5000/$9000`, all pages/controls, REU tests,
  no-REU behavior, repeated lifecycle, and clean exit.
- Every anomaly, reproduction result, root cause, fix/no-fix decision, and
  blocking assessment.
- Mirrored-doc and DOX closeout results.
- A direct completion question.

## Completion Sequence

1. Complete static checks.
2. Obtain user runtime results.
3. Investigate discrepancies.
4. Prepare and present walkthrough.
5. Ask whether work is complete.
6. Wait for explicit affirmative approval.
7. In a subsequent approved closeout increment, mark tasks/plans/Taskwarrior
   complete and apply any required version-stage/final record updates.
8. Verify closeout diff and build stability.

## Must Remain Untouched

Unless a discrepancy is separately activated and approved:

- `ms-dos/`
- CASM parser/lexer/expression/source/include/emitter/relocation production
  code
- Loader relocation implementation
- Frozen API/private app-table/MCT layouts
- Existing unrelated trusted fixtures
- `tools/reloc.py` and `scripts/hex_manifest_to_bin.py`
- Unrelated applications/tasks/history/build counters
- Historical completed plans/walkthroughs
- Broken `c64-testing` or web emulator configuration

## Stop Conditions

- WP9 is not approved.
- Public docs disagree with final implementation and correction exceeds scope.
- Runtime evidence is incomplete.
- An anomaly lacks root-cause/blocking assessment.
- Mirrored docs cannot be synchronized.
- Task/Taskwarrior identity is ambiguous.
- DOX ownership/index changes are unresolved.
- Completion would require marking records before user approval.

## Completion Gate

End the walkthrough by asking whether the user approves WP10 and the DASH
initiative as complete and authorizes final task, Taskwarrior, plan, version,
and completion-record updates. Do not perform those updates before an explicit
affirmative response.

### Closeout (user-approved 2026-07-30)

Walkthrough presented: stale `wiki/casm-utility.md` (Phase 4) and
`wiki/casm-programmers-reference.md` (WP46) reconciled to current CASM
(`0.1.50` build 1204, Phase 9 complete); new `wiki/dash-utility.md` manual
added (mirrored to `docs/`); a pre-existing `wiki`/`docs` desync in
`programmers-reference.md` (missing `ApiExt` segment) fixed; `wiki/Home.md`,
`wiki/AGENTS.md`, `src/external/dash/AGENTS.md`, `CHANGELOG.md`, and
`brain/KNOWLEDGE.md` updated. `command64`/`casm`/`dash`/`image_d64`/
`test_image_d64` all build clean; `git diff` contained only documentation.

The user approved WP10 and the DASH initiative as complete, and additionally
directed a version bump: DASH's on-screen version banner advanced from
`V0.1.3` to `V0.1.4` (`ddata.s`'s `DASHVERSTR`), with `dash.ref.hex`
regenerated against the rebuilt `dash_ref` ca65 cross-check (still the
explicit interim provenance approved during WP9 -- unchanged code/relocation
counts, new SHA-256). This plan, WP9, and the parent
`2026-07-26-casm-dash-system-dashboard.md` plan are marked complete in this
same closeout increment, per this gate's own Completion Sequence.
