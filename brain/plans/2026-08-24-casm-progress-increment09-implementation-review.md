---
feature: casm-progress-increment09-implementation-review
created: 2026-08-24
status: proposed
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment08-automated-verification, approved and complete
---

# Plan: CASM Progress Increment 9 - Full Implementation Review

## Status

**Proposed, not yet approved.** Review/remediation only; no runtime acceptance is
authorized until this gate closes.

## Objective

Perform an independent full-candidate review of UX, 6502 correctness, ABI,
memory, cycles, I/O, diagnostics, deterministic replay, tests, and documentation.

## Review Register

- Compare implementation line-by-line with the Increment 2 ABI and parent plan.
- Audit every call site's live A/X/Y, carry/zero, stack balance, scratch ownership,
  committed-state ordering, and primary-diagnostic precedence.
- Audit loops/cadence for accidental per-byte screen output and overflow edges.
- Audit all BSS/MAIN/zero-page/record effects and CMake dependency declarations.
- Trace source/include Pass 1 and Pass 2 paths, directive paths, primary writes,
  listing/map order, failure cleanup, and repeated invocation.
- Review exact 40-column output on PAL/NTSC-independent screen semantics.
- Classify findings by severity and resolve only in-scope findings through small,
  separately verified remediation increments appended to this plan.

## Atomic Increments

1. Freeze candidate commit/diff and evidence inventory.
2. Conduct static ABI/carry/stack/scratch and memory review.
3. Conduct behavior, screen, I/O, replay, cleanup, and performance review.
4. Conduct harness/fixture/CMake/DOX evidence review.
5. Publish a finding register with file:line references and dispositions.
6. Plan, approve where material, implement, and reverify in-scope remediations.
7. Re-run affected and full automated gates; write review walkthrough.

## Expected Files

| File | Planned action |
| --- | --- |
| `brain/reviews/2026-08-24-casm-progress-implementation-review.md` | Create |
| This plan | Append findings/remediation progress |
| Production/tests | Modify only for approved in-scope findings |
| Matching walkthrough | Create |

## Stop Conditions

Stop for CRITICAL/HIGH unresolved findings, contract changes needing amendment,
new out-of-scope defects, failed remediation tests, cap breach, artifact drift,
or evidence gaps that prevent independent reproduction.

## Documentation, Task, and DOX Updates

Record review findings and dispositions in the plan/review and synchronize task
state. Do not mark the feature shipped or update release docs yet.

## Completion Gate

The review register has no unresolved blocker, all remediation evidence is clean,
the candidate is frozen, walkthrough exists, and the user approves Increment 9.

## Progress

- 2026-08-24: Detailed review plan drafted; no review claims made.
