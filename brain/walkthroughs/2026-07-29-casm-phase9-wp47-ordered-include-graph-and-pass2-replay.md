---
feature: casm-phase9-wp47-ordered-include-graph-and-pass2-replay
created: 2026-07-29
status: runtime-verified
---

# Walkthrough: CASM Phase 9 WP47 - Ordered Include Graph and Pass 2 Replay

Plan:
`brain/plans/2026-07-29-casm-phase9-wp47-ordered-include-graph-and-pass2-replay.md`.

## What changed

`.INCLUDE` assembles for real for the first time. Every prior Phase 9 work
package built a piece and left `casmRunPass` returning
`CASM_DIAG_NOT_IMPLEMENTED`: WP44 the operand grammar, WP45 the physical
catalog (`include.s`), WP46 the frame stack and nested traversal
(`source.s`). WP47 wires them together and adds the missing piece Pass 2
needed -- an ordered include-event log -- so the second pass can replay the
include graph without reopening a single source file.

- **Pass 1** resolves each `.INCLUDE`, loads the child if it is not already
  cataloged, records one ordered event per *occurrence*, and pushes a frame.
- **Pass 2** replays those events in order, re-deriving each child's
  identity from the catalog and verifying it against the recorded event
  before pushing. It performs no source filesystem I/O at all.
- `includeCatalogInit` gets its first production call site (the 8KB
  metadata store was never allocated in a real `casm` run until now).
- Two new diagnostics: `INCLUDE EVENT LOG FULL` (`$37`) and
  `INCLUDE REPLAY MISMATCH` (`$38`).

## Static verification already performed

- Full `cmake --build build` clean; `git diff --check` clean.
- `casm` build 1194, stable across a no-change rebuild.
- `build/casm.prg`: 18,301 bytes, load address `$3800`, R6 footer
  `00 38 01 08 52 36` (base `$3800`, 2049 relocation entries).
- MAIN `$4000` -> `$4200`, the smallest round-page step above the measured
  16,718-byte minimum (178 bytes headroom). `test_casm_catalog` `$1B00` ->
  `$1C00`; every other harness fits unchanged.
- All four disk images build: `image_d64`, `test_image_d64`,
  `casm_overflow_test_d64`, and the new `casm_include_test_d64`.
- **Zero Pass 2 source I/O, proven structurally**: `inputStreamOpen` has
  exactly two call sites, both in `source.s` -- inside `sourceLoad` (called
  once from `start:`, before Pass 1) and inside `sourceAppendFile`, whose
  only caller anywhere is `includeCatalogLoad` (`include.s:611`). That
  routine's only production call site is `casm.s:398`, inside
  `crpInclude`'s `CASM_PASS_MODE_MEASURE` branch. Pass 2 routes to
  `includeCatalogLookup`, from which no file open is reachable at all.
- One defect found and fixed in review before runtime:
  `crpParentIdentity`'s nested-parent path indexed the frame array with a
  stale `A` (the parent-kind constant), which would have read frame 0 at
  every depth -- coincidentally correct at depth 1, wrong from depth 2 up.

## Runtime verification needed

Two independent checks. Both run in the supported local emulator.

### 1. Event-log unit harness (`casm_overflow_test.d64`)

Boot `test.d64` on device 8 as usual and attach
`build/casm_overflow_test.d64` on device 9.

```text
LOAD"TEST_CASM_EVENT",9
RUN
```

Expected: 15 dots and `CASM EVENT TESTS PASS`. Any `F` marks a failing case
in the order listed in `tests/src/casm_event/casm_event.s`'s own dispatch
block (`evinit1`, `evrecord1`, `evstored1`, `evreplay1`, `evexhaust1`,
`evfinal1`, `evorder1`, `evfinal2`, `evmismatch1`-`6`, `evfull1`).

This harness needs no fixture files and opens nothing -- it drives the
event ABI directly with synthetic tuples, covering ordering, per-field
correspondence, the 128-event capacity boundary from both sides, cursor
discipline, and reserved-tail zero-filling.

### 2. End-to-end include assembly (`casm_include_test.d64`)

Attach `build/casm_include_test.d64` (574 blocks free, so there is room to
re-run). It carries `casm.prg`, `comp.prg`, and 12 source fixtures.

Each case assembles an `.INCLUDE` form and its hand-flattened equivalent,
then compares the two output PRGs. **They must be byte-identical** -- that
equivalence is the governing correctness property for this work package.

The option syntax is `/O:<file>` (colon, no space) -- an explicit output
name is used here rather than the derived `<source-base>.PRG` default, so
each pair's two outputs get distinct, obviously-paired names.

```text
CASM CASMIP1.S /O:OUT1P
CASM CASMIF1.S /O:OUT1F
COMP OUT1P OUT1F

CASM CASMIP2.S /O:OUT2P
CASM CASMIF2.S /O:OUT2F
COMP OUT2P OUT2F

CASM CASMIP3.S /O:OUT3P
CASM CASMIF3.S /O:OUT3F
COMP OUT3P OUT3F

CASM CASMIP4.S /O:OUT4P
CASM CASMIF4.S /O:OUT4F
COMP OUT4P OUT4F
```

Every `CASM` invocation should report `INPUT VALIDATED` and no diagnostic;
every `COMP` should report the files identical.

What each pair proves:

| Pair | Property |
| --- | --- |
| `casmip1` / `casmif1` | Single-level include with labels and a branch crossing the boundary in **both** directions -- the parent's `JMP` targets a label defined inside the child, and the child's `BNE` targets a parent label defined *after* the include site. Proves one continuous symbol scope across a frame boundary. |
| `casmip2` / `casmif2` | Three-level nesting (`casmip2` -> `casmic2` -> `casmic3`), with real statements before and after each include site, so a mis-resumed parent shows up as wrong emitted bytes rather than merely a wrong line number. This is the case that would have caught the `crpParentIdentity` defect above at depth 2. |
| `casmip3` / `casmif3` | Sequential reinclusion of one physical file from two sites. Phase 0C.19 stores the bytes once but expands both times, so the flattened form contains the child twice. Also proves two events referencing the same child index replay in the right order. |
| `casmip4` / `casmif4` | The same equivalence for a **relocatable** assembly (no `.ORG`, default `$3400` origin, R6 footer). The child's `JMP TARGET4` is an absolute reference to a parent label, so this pair proves the relocation *table* matches too, not just the code bytes. |

If a `COMP` reports a difference, that isolates an include-traversal defect
specifically: both sides of a pair run through the same opcode tables and
expression evaluator, so a defect there would move both outputs identically.

## Notes for the reviewer

- The `.INCLUDE` operands are spelled uppercase with the `.S` suffix
  (`.INCLUDE "CASMIC1.S"`) to pair with the lowercase `cc1541 -f` disk
  names. cc1541 maps lowercase host bytes to unshifted PETSCII, which is
  what uppercase ASCII in the source text becomes. Reversing that pairing
  makes `DOS_OPEN_FILE` silently miss the child.
- The fixtures are on their own disk because WP47's verification writes to
  the disk it reads from. `casm_overflow_test.d64` was down to ~10 free
  blocks.
- `casmip4`/`casmic4`/`casmif4` assemble to a `JMP` through code that is
  not meant to be executed; they exist only to be assembled and compared.

## Runtime results

**2026-07-29: both checks pass, confirmed by the user in the supported local
emulator.**

1. `test_casm_event` — all 15 cases pass (`CASM EVENT TESTS PASS`). Covers
   ordering, per-field correspondence across all six event fields, the
   128-event capacity boundary from both sides, cursor discipline on
   rejection, the exhausted-log ("extra `.INCLUDE`") case, the
   unconsumed-events ("missing trailing event") case, and reserved-tail
   zero-filling.
2. All four end-to-end pairs report `FILES COMPARE OK` — the `.INCLUDE`
   form and its hand-flattened equivalent assemble to byte-identical output
   PRGs for single-level (with labels and branches crossing the boundary in
   both directions), three-level nested, sequential-reinclusion, and
   relocatable (relocation table included) cases.

Notably, WP47 passed its runtime matrix on the first attempt, unlike WP46 --
whose first run failed every real-traversal case and exposed four cascading
production defects. The difference is that WP46 had already absorbed the
hard traversal work (frame push/pop, provenance capture, the depth-0 end
cap, the resume-offset correction), so WP47 built on a proven engine rather
than a theoretical one, and its one genuine defect (`crpParentIdentity`'s
stale-`A` frame index) was caught by code review before it ever ran.

## Status

Runtime verified. Awaiting explicit user completion approval before the
version-only `0.1.48` -> `0.1.49` increment and closeout record
synchronization.
