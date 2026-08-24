---
feature: casm-progress-increment10-runtime-acceptance
created: 2026-08-24
status: proposed
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment09-implementation-review, approved and complete
---

# Plan: CASM Progress Increment 10 - Runtime Acceptance

## Status

**Proposed, not yet approved.** This is a live evidence and user-acceptance gate,
not authority to change production behavior beyond separately approved fixes.

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
