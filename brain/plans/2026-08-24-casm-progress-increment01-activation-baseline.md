---
feature: casm-progress-increment01-activation-baseline
created: 2026-08-24
status: closed
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: CASM Phases 9-13, complete and user-approved
---

# Plan: CASM Progress Increment 1 - Activation and Baseline

## Status

**Approved 2026-08-24.** Implementation authorized for this increment: verification/baseline capture only -- no CASM production code changes.
Parent plan: `brain/plans/2026-07-29-casm-feature-progress-indication.md`.

## Objective

Activate the optional feature as a measured implementation effort and capture a
reproducible pre-change baseline from current `main`. This increment changes no
CASM production behavior and adds no progress source.

## Scope

**Included:** verify Phase 9-13 completion records; refresh code-graph traces;
record current CASM version/build, branch point, MAIN/BSS/envelope, zero-page
usage, artifact hashes, fixture timings, screen output, disk headroom, and task
state; select large, short-statement, and byte-heavy timing fixtures.

**Excluded:** ABI decisions, source edits, new CMake targets, fixture creation,
version changes, and runtime claims about unimplemented progress.

## Baseline Contract

- Use `feature/casm-progress-indication` from the then-current `main` history.
- Configure and build only through CMake.
- Capture `casm`, relevant harnesses, references, and Phase 9-13 disks.
- Record hashes for static and R6 outputs, `/L` files, and `/M` screen output.
- Measure representative large, short-statement, and Phase 13 byte-heavy runs in
  one documented VICE configuration; raw runs remain evidence, not estimates.
- Record the current `$6C00` production envelope and all private/shared
  zero-page use. Do not infer free space from successful linking alone.
- Audit disk directory entries and writable blocks before choosing the dedicated
  progress image contract in Increment 2.

## Atomic Increments

1. Reconcile branch, phase, plan, task, and version/build state.
2. Refresh call paths for orchestration, source/include, directives, writes,
   diagnostics, listing, and map output.
3. Configure and build the current baseline through CMake.
4. Capture artifact hashes, envelopes, imports/exports, zero-page allocation,
   disk capacity, and no-change rebuild behavior.
5. Run and record timing baselines and exact screen/artifact witnesses.
6. Write the Increment 1 walkthrough and request approval of the baseline.

## Expected Files

| File | Planned action |
| --- | --- |
| This plan | Append measured progress/evidence references |
| `brain/walkthroughs/2026-08-24-casm-progress-increment01-activation-baseline.md` | Create |
| `brain/task.md`, `wiki/tasks/casm-progress-indication.md`, Taskwarrior | Mark activation only after approval |

## Stop Conditions

Stop if phase records disagree, current `main` does not reproduce trusted
artifacts, any baseline harness fails, timing cannot be reproduced, a no-change
build changes an artifact, disk capacity is insufficient, or a new defect is
found. Disclose and defer unrelated defects.

## Documentation, Task, and DOX Updates

At activation, synchronize the feature task and parent plan without marking any
implementation complete. No user manual or DOX change is expected because no
behavior or durable workflow changes.

## Completion Gate

All baseline fields and raw timing runs are recorded in the walkthrough, trusted
outputs reproduce, trackers agree, and the user explicitly approves Increment 1.

## Progress

- 2026-08-24: Detailed plan drafted; no implementation authorized.
- 2026-08-24: Approved. All six atomic increments executed: branch/phase/
  task reconciled (no drift found), call-path map refreshed across all
  seven required areas, full clean build + no-change rebuild stable,
  artifact/envelope/zero-page/disk-capacity baseline captured, four live
  VICE timing runs recorded (wall-clock, load-dominated for small
  fixtures, ~140s of pure dispatch-loop time for the 6000-statement large
  fixture), walkthrough written. Two carry-forward findings for
  Increment 2: MAIN envelope headroom is only 231 bytes (0.8% of the
  $6C00 budget), and CASM's private zero page ($70-$8F) has zero spare
  bytes. A genuine byte-heavy directive timing fixture still does not
  exist and is deferred, as planned, to a future fixture-creation
  increment. Full detail:
  `brain/walkthroughs/2026-08-24-casm-progress-increment01-activation-baseline.md`.
  Awaiting user approval of the baseline before Increment 2 begins.
- 2026-08-24: **Closed, user-approved.** Increment 1 complete; walkthrough's Completion Gate fully checked.
