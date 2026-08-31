---
feature: casm-progress-increment03-progress-core
plan: brain/plans/2026-08-24-casm-progress-increment03-progress-core.md
date: 2026-08-24
status: approved
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
---

# Walkthrough: CASM Progress Increment 3 -- Progress Core

## Summary

`src/external/casm/progress.s` now exists in-tree, implementing the full
Increment 2-frozen ABI (routine table, BSS map, screen protocol, two new
diagnostic IDs). A focused harness
(`tests/src/casm_progress/casm_progress.s`, `test_casm_progress`) exercises
every routine and, live under VICE, caught and drove the fix of **two real
bugs** before this increment could close -- exactly what a focused harness
at this stage exists to do. No production CASM orchestration was touched:
`grep`-confirmed zero references to any `progress*` symbol from `casm.s`,
`emit.s`, `diagnostics.s`, or any other module. `progress.s` is linked into
the real `casm.prg` (forced by `CASM_SRCS`'s glob + ld65's whole-object
linking -- see the forced-consequence note below) but is completely
unreachable dead code from `casm.s`'s own entry point.

## Forced consequence: the Increment 2-approved MAIN growth had to apply now

Creating `progress.s` under `src/external/casm/` was expected to be inert
until Increment 4 wires real call sites. It was not: `CMakeLists.txt`
globs `src/external/casm/*.s` into `CASM_SRCS`, and `ld65` links whole
object files passed to it, not per-symbol -- so the instant the file
existed, the very next `cmake --build build --target casm` failed with
`ld65`'s own `Segment 'BSS' overflows memory area 'MAIN' by 503 bytes`,
reproducing Increment 2's measurement exactly, even though `casm.s` never
imports anything from it. The Increment 2-approved `$6C00` -> `$7000` MAIN
growth (`CMakeLists.txt`'s `add_ca65_app(casm ...)` call site) was applied
immediately as a result -- not scope creep, just the mechanical reality of
this build system surfacing an already-approved-but-not-yet-applied
decision earlier than expected. Comment added at the call site recording
why, matching the codebase's own established convention for every prior
envelope change.

## Atomic Increments

### 1: Focused harness skeleton and CMake source boundary

`tests/src/casm_progress/casm_progress.s` created, `BUILD_TEST_CASM_PROGRESS`
seeded, and a `TEST_NAME STREQUAL "casm_progress"` block added to
`CMakeLists.txt`'s test-target loop, linking `progress.s` + `common.inc`
directly -- no stand-in stubs needed, since `progress.s` imports nothing
(no diagnostics.s/listing.s/map.s/VMM/resources dependency, by the
Increment 2 design). Built clean on the first attempt at the default
`$1000` (4096-byte) test-harness budget; 1542-1690 code bytes measured
across iterations, comfortable margin.

### 2-6: BSS init, formatting/boundary, counters/overflow/mismatch, cadence, clear/redraw/suspend

20 cases (`caseInitZeroesState` through `caseFinalSummaryClearsAndPrints`,
lettered A-T on screen for unambiguous live identification) cover: BSS
zeroing, pass-begin reset and pass-2 flag flip, statement increment across
the Lo/Hi boundary, throttle due-ness at exact counts 64/128 and a
non-multiple midpoint, counter-overflow-before-wrap, Pass 1 total latching,
pass-total match/mismatch, output-byte accumulation and its carry, and
idempotent clear/suspend. Full detail and the two real defects found are
below.

### 7: Build the focused target, inspect envelope/zero-page, no-change build

- `test_casm_progress` builds clean (`$1000` budget, ~1.6-1.7KB used).
- Real `casm` target, forced to grow per above: `$6C00` -> `$7000`. Final
  measured envelope: `__MAIN_START__`=`$3800`, `__MAIN_SIZE__`=`$7000`,
  `__MAIN_LAST__`=`$A5F7`. **Used 28151 of 28672 bytes; 521 bytes (1.8%)
  headroom** -- tighter than the isolated Increment 2 test predicted
  (1033 bytes), because that test linked a driver stub, not real `casm.s`
  and its own actual content; still comfortably positive.
- Zero page: `casm_3800.cfg` defines no `ZEROPAGE` memory area at all --
  CASM's `$70-$8F` contract is hand-managed via `common.inc`, not
  linker-tracked. `progress.s` declares no zero-page storage anywhere.
  Unchanged.
- No-change rebuild: `casm.prg` SHA-256 and `BUILD_CASM`'s build number
  both stable across a repeated `cmake --build build` with no source
  changes.
- **Regression check**: re-ran the exact `CASM CASMOPALL.S /O:...` command
  from Increment 1's own baseline under VICE against the new,
  MAIN-grown, progress.s-linked `casm.prg`. Output hash
  `0bccfbc18392bb108c26b91b9c6b289b1a4537c40b995bdde2e7409939c9f6fc`
  matches Increment 1's recorded baseline **exactly** -- the growth and
  the dead-linked module have zero effect on CASM's real output.

### 8: Walkthrough evidence and approval request

This document.

## Two real defects found and fixed

Both caught live under VICE by the focused harness -- exactly the value a
harness is supposed to provide before wider integration.

### Defect 1 (in `progress.s` itself): X-register clobber causes an infinite loop

`progressReturnToStart` and `progressClearTransient` both looped
`CASM_PROG_LINE_WIDTH` (38) times calling `progressPrintChar`, using `X` as
the loop counter. `progressPrintChar` passes its character to `OS_API` in
`X` (`ahPrintChar`'s own documented input register, `src/command64/api.asm:157`)
and does not preserve it -- so `X` was reset to the PETSCII character value
(157 for `PetLeft`) on every single call, and the subsequent `dex`/`bne`
never converged. First live run hung indefinitely inside
`progressReturnToStart`, confirmed via `vice_backtrace` showing the call
chain frozen three frames deep (case function -> `progressRenderTransient`
-> `progressReturnToStart`) with the CPU still executing (not crashed).
Fixed by switching both loops to `Y` (verified against `ahPrintChar`'s
actual body: it never touches `Y`, and `KernalChROUT` is documented to
preserve `Y`).

### Defect 2 (in `progress.s` itself): pass number stored into the counter it should zero

`progressBeginPass`'s first two lines stored `A` (still holding the
pass-number argument, 1 or 2) into `CasmProgActiveLo` *before* zeroing it,
instead of after -- so every pass's statement counter silently started at
the pass number instead of zero. Caught by `caseDecimalBoundaryZero`
reporting `P1: DONE 00001 STATEMENTS` instead of `00000` after zero real
`progressStatement` calls. One-line reorder fix (zero `A` before storing
into `ActiveLo`, not after).

### One test-harness-only bug found and fixed (not in `progress.s`)

The first draft of the three throttle cases (`caseThrottleAt64`,
`caseThrottleAt128`, `caseThrottleNotDueMidRange`) checked
`progressStatement`'s carry/`A` return *after* the loop's own
`inx`/`cpx`/`bne` bookkeeping -- but `cpx` sets carry on every comparison,
so by the time the loop exited the carry flag reflected `cpx`'s own
result, not `progressStatement`'s. This produced three false failures with
`progress.s` itself correct. Fixed by stashing the processor status
(`php`) and `A` into local scratch bytes immediately after each
`jsr progressStatement`, before any loop-control instruction can disturb
them.

## Live VICE Evidence

Scratch verification disk (`command64.prg` + `test_casm_progress.prg`,
truncated 16-char name `test_casm_progre`), one continuous VICE session,
port 7000. Banner verified before each run. Full transcript captured via
incremental screen-RAM snapshots (0.1s poll) to see every case's own
letter marker and result character, not just the final line.

Final run, all 20 cases: `A. B. C. D. E. F. G. H. I. J. K. L. M. N. O. P.
Q. R. S. T.` (every case printed its letter then a `.`, no `F` markers) --

```
DONE: P1 00001, P2 00001, 00010 BYTES
.
CASM PROGRESS: PASS
```

confirmed via two independent full-screen captures (snapshot 6 and 7 in
the session, one at the exact moment `PASS` appeared and one after the
shell prompt returned).

## Stop Conditions

None triggered as a hard stop. The plan's approved ABI did not change; no
formatting exceeds 40 columns (`CASM_PROG_LINE_WIDTH` = 38, unchanged);
no zero page was added; the focused harness's two real defects were found
and fixed as part of this increment's own normal completion criteria
("Add bounded BSS initialization and reset tests" etc.), not treated as
out-of-scope surprises; envelope growth (`$6C00` -> `$7000`) was already
approved by Increment 2 with measured evidence, applied here only because
the build system forced it earlier than planned (documented above, not a
new unapproved growth); the no-change rebuild is stable; and the
regression check found no artifact drift.

## Completion Gate

- [x] All 20 focused cases pass (live VICE evidence above).
- [x] Map/envelope evidence recorded (521 bytes / 1.8% headroom at the
      approved `$7000` budget; zero-page unchanged).
- [x] No production hook is active (`grep`-confirmed zero references from
      any other CASM module).
- [x] This walkthrough exists.
- [x] Trackers agree (Taskwarrior annotation and plan Progress update
      follow this walkthrough).
- [x] User approves Increment 3.
