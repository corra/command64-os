---
feature: casm-progress-increment03-progress-core
created: 2026-08-24
status: closed
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment02-design-abi-review, approved and complete
---

# Plan: CASM Progress Increment 3 - Progress Core

## Status

**Approved 2026-08-24.** Parent plan:
`brain/plans/2026-07-29-casm-feature-progress-indication.md`.

## Objective

Add isolated `progress.s` state, formatting, throttling, clear/redraw, and a
focused harness. Do not connect production CASM orchestration in this increment.

## Technical Contract

- Implement only the Increment 2-approved public ABI and BSS layout.
- Rendering is bounded to one 40-column row and uses the approved PETSCII cursor
  protocol; no KERNAL/OS call may leave shared scratch live.
- Statement updates occur at exact counts 64, 128, and so on; immediate
  transition calls bypass the divider without changing totals.
- Decimal conversion handles all unsigned 16-bit values and cannot overrun a
  field. Filename display retains the first eight bytes.
- Clear and suspend are idempotent and do not own handles, VMM, keyboard, timer,
  parser, emitter, or diagnostic state.
- The focused harness links real `progress.s` plus `common.inc`, with controlled
  output/state stand-ins modeled on `test_casm_map` and `test_casm_directives`.

## Atomic Increments

1. Add the focused harness skeleton and CMake source boundary.
2. Add bounded BSS initialization and reset tests.
3. Add decimal/filename/row formatting and boundary tests.
4. Add statement counters, overflow-before-wrap, pass totals, and mismatch tests.
5. Add 64-statement and 256-byte cadence state with exact-boundary tests.
6. Add in-place clear/redraw/suspend and captured-output tests.
7. Build the focused target, inspect envelope/zero-page use, and no-change build.
8. Write walkthrough evidence and request approval.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/progress.s` | Create |
| `tests/src/casm_progress/casm_progress.s` | Create |
| `tests/src/casm_progress/BUILD_TEST_CASM_PROGRESS` | Generated/created by build convention |
| `CMakeLists.txt` | Add focused target boundary and envelope |
| Matching walkthrough | Create |

## Stop Conditions

Stop if the approved ABI changes, any formatting exceeds 40 columns, the module
needs zero page or external resource ownership, focused tests fail, envelope
growth exceeds its approved bound, no-change artifacts move, or unrelated defects
appear.

## Documentation, Task, and DOX Updates

Record source/harness activation in trackers. Because a new `tests/src` boundary
is added, perform the tests DOX pass and update it only if durable guidance or
its index changes. Follow overlay/CMake workflow if the CMake shape triggers it.

## Completion Gate

All focused cases pass, map/envelope evidence is recorded, no production hook is
active, walkthrough and trackers exist, and the user approves Increment 3.

## Progress

- 2026-08-24: Detailed plan drafted; no source created.
- 2026-08-24: Approved and executed. src/external/casm/progress.s written
  in-tree against the Increment 2-frozen ABI; tests/src/casm_progress/
  casm_progress.s (20 cases, test_casm_progress) added. Building the real
  casm target immediately forced applying Increment 2's approved MAIN
  growth ($6C00 -> $7000): CASM_SRCS globs src/external/casm/*.s and ld65
  links whole object files, so creating progress.s alone reproduced the
  573-byte-class overflow (measured 503 bytes at $6C00) even with zero
  casm.s wiring. The focused harness caught two real progress.s defects
  live under VICE before this increment could close: an X-register clobber
  (progressPrintChar passes its char in X per OS_API's own convention and
  doesn't preserve it) causing an infinite loop in two cursor-movement
  loops that used X as their counter, and a pass-number-into-counter
  off-by-one in progressBeginPass. Both fixed; a related test-harness-only
  bug (carry flag clobbered by loop bookkeeping before the assertion read
  it) was also found and fixed. Final live-VICE run: 20/20 cases pass
  (CASM PROGRESS: PASS). Envelope: 521 bytes (1.8%) headroom at the grown
  budget. Regression check: re-ran Increment 1's own CASM CASMOPALL.S
  baseline against the new casm.prg -- byte-identical output hash,
  confirming zero effect on real CASM behavior (progress.s remains
  completely unreachable dead code from casm.s's entry point). Full detail:
  brain/walkthroughs/2026-08-24-casm-progress-increment03-progress-core.md.
  Awaiting user approval before Increment 4 wires real orchestration call
  sites.
- 2026-08-24: **Closed, user-approved.** Increment 3 complete; walkthrough's Completion Gate fully checked.
