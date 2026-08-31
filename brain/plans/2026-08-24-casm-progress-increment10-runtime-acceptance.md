---
feature: casm-progress-increment10-runtime-acceptance
created: 2026-08-24
status: complete
approved: 2026-08-31
closed: 2026-08-31
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment09-implementation-review, approved and complete
---

# Plan: CASM Progress Increment 10 - Runtime Acceptance

## Status

**COMPLETE - user-accepted 2026-08-31.** Live evidence and user-acceptance
gate; no production behavior change. User-confirmed decisions 2026-08-31:
(1) add a `casmpgbad.s` mid-assembly-failure fixture to
`casm_progress_test_d64` so the transient-clear-over-a-diagnostic +
partial-output-cleanup case is on the same self-bootable disk; (2)
re-drive a representative subset (~4 cases) live against the current
`1379` binary with screenshots, and cite Increment 4 for the exhaustive
10/10 + option-identity matrix.

## Objective

Demonstrate the reviewed candidate from a booted Command64 shell and obtain user
acceptance of actual status behavior, readability, ordering, and failure handling.

## Runtime Matrix

- Boot Command64 and launch CASM by shell command from the dedicated progress disk.
- Observe short and long source loading, 256-byte boundaries, multiple roots,
  nested includes, frame push/pop, and first-eight-byte filename identity.
- Observe Pass 1/2 start, 64-statement cadence, totals, and final summary.
- Observe large `.RES`/`.FILL`/`.ALIGN` and `.INCBIN` without apparent stalls.
- Exercise static, R6, `/L`, `/M`, and `/L /M`; verify status never overwrites
  map/listing/diagnostic rows and native COMP confirms artifacts.
- Exercise syntax, undefined symbol, include load/cycle/depth, assertion,
  `.INCBIN`, output, listing/map, overflow, and mismatch failures available in
  approved fixtures; confirm transient clear and primary diagnostic readability.
- Repeat success/failure runs and confirm shell prompt, handles, VMM, and outputs.

## Atomic Increments

1. Start VICE under the repository workflow and prove Command64 boot prerequisite.
2. Run success matrix with screenshots/transcripts and artifact comparisons.
3. Run failure/cleanup matrix and repeated invocation.
4. Run representative and stress timing witnesses if visual overhead is disputed.
5. Record exact observed results and any deviations in the walkthrough.
6. Ask the user to accept or reject Increment 10; do not self-approve.

## Expected Files

| File | Planned action |
| --- | --- |
| Matching walkthrough | Create/append live evidence |
| This plan | Append runtime progress |
| Production/tests | No change unless a separately approved remediation is required |

## Stop Conditions

Stop on unavailable VICE MCP and ask the user to test; also stop on boot failure,
screen corruption, stale transient text, artifact mismatch, cleanup/resource leak,
timing cap breach, unexpected diagnostic, or new defect. Do not tactical-fix a
runtime finding without a plan amendment or separate follow-up approval.

## Documentation, Task, and DOX Updates

Record runtime evidence and acceptance state only. Release/user documentation is
updated in Increment 11 after acceptance, not speculatively here.

## Completion Gate

All required live cases have evidence, open findings are resolved or explicitly
deferred without violating scope, and the user explicitly accepts runtime behavior.

## Progress

- 2026-08-24: Detailed runtime plan drafted; no live acceptance performed.
- 2026-08-31: Plan approved. Added `casmpgbad.s` (mid-assembly failure
  fixture) to `casm_progress_test_d64`; disk rebuilt clean, `casm.prg`
  unchanged (`72549659`, `BUILD_CASM` 1379), `git diff --check` clean.
- 2026-08-31: **Live runtime matrix executed** (VICE 3.10, fresh boot,
  `CASM V0.4.0.1379`). Six cases, all pass, no findings:
  1. `CASM CASMPG64.S` - `P1/P2 DONE 00064`, `WRITE`, `DONE ... 00065
     BYTES`, legible + ordered.
  2. `CASM CASMPGINCA` - nested include + re-inclusion, `00012` count =
     all frames traversed, `DONE ... 00009 BYTES`.
  3. `CASM CASMPG128.S /O:AL.PRG /M /L` - `SYMBOL MAP` / `000 SYMBOLS` /
     `DONE` in clean order, no transient residue, `al.lst` written.
  4. `CASM CASMPGR6.S` - `WRITE: casmpgr6.prg`, `DONE ... 00054 BYTES`
     (R6 table + footer in the accounting).
  5. `CASM CASMPGBAD.S` (NEW) - transient line cleared before the
     `CASM: BRANCH OUT OF RANGE` diagnostic (rendered at statement 64,
     wiped by `diagPrintFatal`); diagnostic + source context + caret fully
     readable; `DIR` confirms **no `casmpgbad.prg` orphan**; clean shell
     return.
  6. `CASM CASMPG65.S /O:R1.PRG` then `/O:R2.PRG` - identical output both
     runs, `comp r1.prg r2.prg` -> `FILES COMPARE OK`, no resource leak
     between invocations.
  Screenshots under this session's scratchpad. Walkthrough:
  `brain/walkthroughs/2026-08-24-casm-progress-increment10-runtime-acceptance.md`.
- 2026-08-31: **User accepted the runtime behavior.** Increment 10 closed;
  `casmpgbad.s` fixture + walkthrough committed. Only Increment 11
  (completion gate) remains for the feature.
