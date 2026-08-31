---
feature: casm-progress-increment09-implementation-review
created: 2026-08-24
status: complete
approved: 2026-08-31
closed: 2026-08-31
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment08-automated-verification, approved and complete
---

# Plan: CASM Progress Increment 9 - Full Implementation Review

## Status

**COMPLETE - user-approved 2026-08-31.** Review/remediation only. Finding
disposition (user-confirmed 2026-08-31): fix CRITICAL/HIGH and small
clearly-in-scope defects inline; disclose-and-defer anything larger.
PR-1/PR-2/PR-4 fixed and re-verified; PR-3/PR-5 recorded. Increments 10
(runtime acceptance) and 11 (completion gate) remain for the feature.

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
- 2026-08-31: Plan approved (disposition: fix in-scope inline, defer rest).
  **Atomic Increment 1 - candidate frozen:** commit `fb2fe48`
  ("casm: close progress Increment 8"), `casm.prg` sha256
  `af1bacdab72a40bf20983a8676592873d76b0bd74d2b6c0b68155b6f7c3d819c`,
  `BUILD_CASM` 1378, CASM `V0.4.0.1378`. Feature branch base (merge-base
  with `main`) `4e3f921`. Progress-feature production diff spans:
  `progress.s` (+710, entirely new), `casm.s` (+361), `emit.s` (+90),
  `diagnostics.s` (+74), `source.s` (+29), `reloc.s` (+7), `common.inc`
  (+14), plus `AGENTS.md` (+12) and `CMakeLists.txt` (+246). Evidence
  inventory: Increments 3-8 walkthroughs + the Increment 2 frozen ABI
  (`brain/reviews/2026-08-24-casm-progress-design-abi-review.md`).
  Review register: `brain/reviews/2026-08-24-casm-progress-implementation-review.md`.
- 2026-08-31: **Full review executed.** Every changed production file read
  line-by-line against the Increment 2 frozen ABI. Core design + integration
  found sound and consistent with Increment 4 live evidence. Five findings:
  - **PR-1 (MEDIUM, FIXED):** `progressReturnToStart`/`progressClearTransient`
    clobber-doc headers said `A, Y`; actual is `A, X, Y` (X via
    `progressPrintChar`). Frozen ABI + `diagnostics.s:156` also wrong. No
    live bug. Corrected three doc sites.
  - **PR-2 (MEDIUM, FIXED):** `CASM_PROG_FLAG_SUSPENDED` was write-only -
    the `/L`/`/M` `progressSuspend` calls enforced nothing. Added a
    `SUSPENDED` early-return to `progressRenderTransient`/
    `progressSourceLoadBytes`/`progressDirectiveBytes`. Inert in the current
    flow (nothing renders after a suspend); future-proofing.
  - **PR-3 (LOW, DEFERRED):** `DONE: ... nnnnn BYTES` is a 16-bit
    accumulator; output > 64KB (`.FILL 65535` from `.ORG $0000`) wraps the
    display. File itself stays correct. Recorded, not actioned.
  - **PR-4 (LOW, FIXED):** `crpProgressHook` comment didn't note
    `crpSnapshotName`'s `CasmPtr0` clobber. Verified safe today; extended
    the comment.
  - **PR-5 (INFO):** uppercase message literals, consistent with CASM; no
    action.
  Remediation applied (`progress.s`/`diagnostics.s`/`casm.s`), build clean
  (`casm.prg` `72549659...`, `BUILD_CASM` 1378->1379, +30 bytes, `$7400`
  still fits), exact no-change rebuild stable, `git diff --check` clean.
  Live-VICE smoke (`CASM V0.4.0.1379`): `casmpg64` assembles identically +
  `COMP OK`; `casmpg64 /M /L` renders `SYMBOL MAP`/`DONE` cleanly with the
  new `SUSPENDED` guards active. Walkthrough:
  `brain/walkthroughs/2026-08-24-casm-progress-increment09-implementation-review.md`.
- 2026-08-31: **User approved closing Increment 9.** Committed on
  `feature/casm-progress-indication`. Increments 10-11 remain.
