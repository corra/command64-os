---
feature: casm-progress-increment11-completion-gate
created: 2026-08-24
status: complete
approved: 2026-08-31
closed: 2026-08-31
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment10-runtime-acceptance, approved and complete
---

# Plan: CASM Progress Increment 11 - Completion Gate

## Status

**COMPLETE - user-approved 2026-08-31.** This increment reconciled and closed
the feature; it adds no new production behavior beyond the approved
version-string promotion.

User-confirmed decisions 2026-08-31:
- **Version:** promote CASM `0.4.0` -> `0.5.0` (`VERSION_MINOR "4"` ->
  `"5"` in `casm.s`), and update the CASM implementation/task plans to
  reflect that progress indication shipped as an optional feature outside
  the master plan's numbered phases and CASM is now at `0.5.0`.
- **Re-verification:** FULL consolidated sweep - clean build + every
  `test_casm_*` harness across all six disks + the `casmpg*` matrix +
  failure cases, re-run fresh in one continuous live-VICE session against
  the final `0.5.0` candidate. Do not cite earlier-increment evidence as
  a substitute.
- **Merge:** after explicit feature-complete sign-off, merge
  `feature/casm-progress-indication` to `main` as the final step.

Ordering note: the version promotion (Atomic Increment 5 in the plan
below) is done **before** the live sweep, not after, so the sweep verifies
the final `0.5.0` binary in one pass rather than requiring a second live
session. Deviation from the plan's step order, recorded here.

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
- 2026-08-31: Plan approved (version increment + update the CASM
  implementation plans; full consolidated sweep; merge after sign-off).
  - **Version promoted** `casm.s` `VERSION_MINOR "4"` -> `"5"` (CASM
    `0.4.0` -> `0.5.0`). Clean `rm -rf build` rebuild reproduces
    `casm.prg` sha256 `e8a6731f...`, `BUILD_CASM` 1379 -> 1380, size
    unchanged (33,398). Exact no-change rebuild stable
    (`casm_progress_test.d64` `eb4066e6...` also byte-stable).
  - **Host audit:** full `cmake --build build` exit 0, 31 test PRGs + 11
    disk images, no envelope overflow. `ld65 -m`: CODE `$3800`-`$8BE6`,
    RODATA to `$9AE5`, BSS to `$A97D`; **642 bytes MAIN headroom** at
    `$7400`. No new zero page.
  - **Consolidated live sweep** (VICE 3.10, `CASM V0.5.0.1380` banner
    confirmed): **31/31 harnesses PASS** across `test.d64` (5),
    `casm_overflow_test.d64` (3), `casm_include_test.d64` (9),
    `casm_phase12_test.d64` (2), `casm_phase13_test.d64` (1),
    `casm_listing_test.d64` (11); plus `test_casm_progress` on its own
    disk (32). **10/10 `casmpg*` fixtures `FILES COMPARE OK`** with exact
    `DONE:` byte counts; `casmpgbad` failure case clean (transient
    cleared, `DIR`-confirmed no orphan PRG); `/M /L` output identity
    `COMP OK`. **No findings.** Overlay `test`/`pass` event fired.
  - **Docs/DOX closeout:** `CHANGELOG.md`, `docs`+`wiki` `casm-utility.md`
    (new Progress Display section), `casm-programmers-reference.md` status
    header, `brain/KNOWLEDGE.md` (new section), `wiki/tasks/casm.md`,
    `wiki/tasks/casm-progress-indication.md`,
    `src/external/casm/AGENTS.md`, the master implementation plan
    (`2026-07-16-casm-assembler-implementation-plan.md` Current Status +
    change-in-scope note), and `release/` (regenerated via the `release`
    target) all updated.
  - Walkthrough:
    `brain/walkthroughs/2026-08-24-casm-progress-increment11-completion-gate.md`.
  - **User signed off feature-complete 2026-08-31.** Increment 11 closed,
    the progress-indication feature closed (Taskwarrior 33 done), committed
    on `feature/casm-progress-indication`, and merged to `main`.
