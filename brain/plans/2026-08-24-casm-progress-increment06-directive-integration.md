---
feature: casm-progress-increment06-directive-integration
created: 2026-08-24
status: in-progress
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment05-source-include-integration, approved and complete
---

# Plan: CASM Progress Increment 6 - Directive Integration

## Status

**Approved and activated 2026-08-24.** Parent plan:
`brain/plans/2026-07-29-casm-feature-progress-indication.md`.

## Scope Amendment (user-approved 2026-08-24)

Increment 2 originally removed directive byte cadence to recover 70 measured
bytes, and Increment 5 restored source/include cadence only. The user explicitly
approved restoring `.RES`, `.FILL`, `.ALIGN`, and `.INCBIN` directive cadence on
2026-08-24. This amendment supersedes that part of the Increment 2 scope trim.
Any MAIN envelope increase remains a measured stop gate requiring separate user
approval; cadence restoration does not pre-authorize growth beyond `$7400`.

Atomic Increment 1 extends the frozen ABI with three ordinary BSS bytes and two
non-rendering routines:

- `CasmProgDirectiveKind` (one byte) and `CasmProgDirectiveLo/Hi` (two bytes);
- `progressBeginDirective`: A = directive subtype; stores it, resets the
  cumulative directive-byte count; clobbers A;
- `progressDirectiveBytes`: A/X = cumulative successfully accepted directive
  bytes; stores the value; clobbers A/X.

These routines own no emitter state and cannot fail. Later atomic increments add
bounded emitter hooks and rendering only after this state boundary builds and is
measured.

## Objective

Keep status visibly active during long `.RES`, `.FILL`, `.ALIGN`, and `.INCBIN`
operations without changing directive sizing, accepted bytes, I/O ownership,
Pass 1/2 agreement, or emitted output.

## Directive Contract

- Preserve the current strict resolved-count/value grammar and 16-iteration
  alignment modulo loop; do not instrument parser or modulo hot paths.
- For fixed fills, add an outer bounded cadence around the shared fill loop.
  Notify after each 256 successfully accepted bytes and once after a final short
  unit; zero count emits and reports no byte increment.
- Increment only after `emitByte` returns carry clear. The accepted `$FFFF` byte
  and following overflow failure retain current semantics.
- Preserve fill remaining counters across rendering; do not use shared emitter
  zero-page scratch in progress.
- For `.INCBIN`, notify only after a complete up-to-256-byte read block has been
  successfully consumed by `emitByte`. Display cumulative payload bytes, but do
  not catalog the payload or change stream open/read/close behavior.
- Handle exact 256-byte multiples without duplicate completion updates and
  preserve the primary diagnostic across best-effort close.
- Execute equivalent operation accounting in both passes without creating
  additional statements.

## Atomic Increments

1. Add operation begin/reset state and focused cadence tests.
2. Restructure the shared fixed-fill path into bounded chunks without changing
   accepted bytes, PC updates, carry, or fill value.
3. Add fixed-fill periodic/final notifications and 0/1/255/256/257/65535 tests.
4. Add `.INCBIN` post-consumption block notifications and exact-boundary tests.
5. Cover PC overflow, read/emit/close failure precedence, and both pass modes.
6. Run directive, expression, pass, listing-capture, and Phase 13 production
   fixture/reference comparisons.
7. Measure directive-heavy timing, envelope, no-change behavior, and walkthrough.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/emit.s` | Modify |
| `src/external/casm/progress.s` | Extend |
| `tests/src/casm_progress/casm_progress.s` | Extend cadence/state cases |
| `tests/src/casm_directives/casm_directives.s` | Extend real-emitter cadence/failure cases if needed |
| Phase 13 fixture generation/reference | Add byte-heavy fixture only under approved dedicated disk plan |

## Stop Conditions

Stop for per-byte rendering, changed directive bytes/PC, parser changes, lost
diagnostic precedence, stream/catalog changes, Pass asymmetry, scratch collision,
performance/envelope breach, unexpected regression, no-change drift, or unrelated
defects.

## Documentation, Task, and DOX Updates

Update trackers and technical evidence. Existing Phase 13 documentation remains
authoritative because directive semantics must not change.

## Completion Gate

Cadence boundaries, both passes, overflow/failure paths, artifact identity,
performance, size, and regressions have walkthrough evidence and user approval.

## Progress

- 2026-08-24: Detailed plan drafted; directive integration not authorized.
- 2026-08-24: User approved restoring directive cadence and beginning Increment
  6. Plan activated with the Scope Amendment above; Atomic Increment 1 started.
- 2026-08-24: **Atomic Increment 1 complete; Atomic Increment 2 pending.** Added
  the approved three-byte BSS state and non-rendering
  `progressBeginDirective`/`progressDirectiveBytes` ABI. Extended
  `test_casm_progress` from 20 to 22 cases: directive-kind/reset and exact
  cumulative boundaries 0/1/255/256/257/65535. `test_casm_progress`, `casm`,
  their exact no-change rebuild, and `test_image_d64` all build clean through
  CMake. Live VICE 3.10 on the rebuilt `test.d64` printed
  `CASM PROGRESS: PASS` and returned to `c64[8]:>`. Production links inside
  the existing `$7400` envelope; no emitter hook or directive rendering exists
  yet. Evidence: `brain/walkthroughs/2026-08-24-casm-progress-increment06-directive-integration.md`.
- 2026-08-24: **Atomic Increment 2 complete; Atomic Increment 3 pending.**
  Reworked `emitFillLoop` into explicit at-most-256-byte outer chunks and a
  per-byte inner loop. Four emitter-private BSS bytes retain current chunk
  remaining and cumulative successfully accepted bytes; counters advance only
  after `emitByte` returns carry clear. Added a real 257-byte `.RES` harness
  case proving one `$0100` chunk plus a one-byte tail reaches PC `$C101` with
  carry clear. `test_casm_directives` (10 cases), `test_casm_progress`, and
  production `casm` build clean; production remains inside `$7400` at 25,023
  code bytes/3,982 relocations. Exact no-change rebuild is stable.
  `casm_include_test_d64` rebuilds clean. Live VICE 3.10 printed
  `CASM DIRECTIVES: PASS` and returned to `c64[8]:>`. No progress call or
  directive rendering was added in this atomic increment.
- 2026-08-24: **Atomic Increment 3 implementation candidate reached the
  measured envelope stop gate.** Fixed-fill handlers now call
  `progressBeginDirective`; each completed chunk calls
  `progressDirectiveBytes`, which renders a fixed-width directive/count line.
  The real-emitter harness independently proves notification counts for
  0/1/255/256/257/65535. Production CASM and both focused harnesses link at
  existing envelopes. The first aggregate disk build exposed a missing
  no-op progress stand-in in narrow `test_casm_bounds`; a complete `emit.s`
  link audit found it was the only deficient narrow boundary and fixed it.
  The rerun then measured six real-progress harness envelope overflows:
  catalog 101, event 137, pass1 212, passcheck 226, frame 76, listcap 256
  bytes. Per Stop Conditions, no CMake envelope was changed; approval is
  required for the smallest one-page increases before verification resumes.
- 2026-08-24: **Atomic Increment 3 verification complete; user sign-off
  pending.** The user approved all six smallest one-page harness-envelope
  increases. Aggregate and exact focused builds pass, including rebuilt
  `test.d64` and `casm_include_test.d64`. The first live progress run exposed
  a harness-only defect: its boundary loop retained its index in Y across
  `progressDirectiveBytes`, whose documented ABI clobbers Y. Preserving the
  index on the 6502 stack corrected the test without changing production code.
  Fresh VICE 3.10 runs then printed `CASM PROGRESS: PASS` on device 8 and
  `CASM DIRECTIVES: PASS` on device 9, each followed by the corresponding
  `c64[<device>]:>` prompt. `git diff --check` passes. Atomic Increment 4 must
  not begin until the user accepts this Atomic Increment 3 evidence.
- 2026-08-24: **Atomic Increment 3 approved complete; Atomic Increment 4
  pending.** The user accepted the recorded build, RCA, focused live-VICE, and
  shell-return evidence. Increment 6 remains active; `.INCBIN` begin/chunk
  integration is the next atomic increment.
- 2026-08-24: **Atomic Increment 4 implementation candidate reached the
  measured envelope stop gate.** `emitIncbin` now begins INCBIN progress,
  counts only bytes successfully accepted by `emitByte`, and notifies only
  when a complete input block has been consumed. The real-emitter harness uses
  a synthetic production-shaped stream to prove 0/1/255/256/257/65535-byte
  notification, cumulative-count, and PC boundaries. Focused
  `test_casm_directives` links at 2,311 code bytes/423 relocations; production
  CASM remains inside `$7400` at 25,228/4,020. Aggregate measurement stopped as
  required: `test_casm_passcheck` exceeds `$6400` by 5 bytes and
  `test_casm_listcap` exceeds `$6C00` by 35 bytes. `test_casm_frame`,
  `test_casm_faultsource`, and `test_casm_spanread` still fit. No CMake
  envelope was changed and no live verification was attempted; user approval
  is required for the smallest one-page increases to `$6500` and `$6D00`.
- 2026-08-24: **Atomic Increment 4 verification complete; user sign-off
  pending.** The user approved the measured `test_casm_passcheck` `$6500` and
  `test_casm_listcap` `$6D00` envelopes. CMake configure, the complete affected
  aggregate, rebuilt `test.d64`/`casm_include_test.d64`, and exact focused
  no-change builds pass. Fresh VICE 3.10 runs proved the Command64 banner,
  `CASM PROGRESS: PASS` with `c64[8]:>` return, and the expanded 12-case
  `CASM DIRECTIVES: PASS` with `c64[9]:>` return. Atomic Increment 5 must not
  begin until the user accepts this Atomic Increment 4 evidence.
- 2026-08-24: **Atomic Increment 4 approved complete; Atomic Increment 5
  pending.** The user accepted the recorded envelope, aggregate/no-change,
  exact-boundary, live-VICE, and shell-return evidence. Increment 6 remains
  active; PC overflow, read/emit/close failure precedence, and both-pass-mode
  coverage are next.
- 2026-08-24: **Atomic Increment 5 verification complete; user sign-off
  pending.** Extended only `test_casm_directives`; production code is unchanged.
  Six new cases prove fixed-fill and `.INCBIN` PC overflow, no notification for
  failed partial chunks, read-over-close and emit-over-close diagnostic
  precedence, completed-block notification before a later close failure, and
  identical 257-byte cadence/PC results in measure and emit modes. The focused
  harness links at 2,802 code bytes/506 relocations; the complete affected
  aggregate, rebuilt `casm_include_test.d64`, and exact no-change builds pass.
  Fresh VICE 3.10 printed 18 pass dots, `CASM DIRECTIVES: PASS`, and returned to
  `c64[9]:>`. Atomic Increment 6 must not begin until the user accepts this
  evidence.
- 2026-08-24: **Atomic Increment 5 approved complete; Atomic Increment 6
  pending.** The user accepted the recorded overflow, diagnostic-precedence,
  both-pass-mode, aggregate/no-change, live-VICE, and shell-return evidence.
  Increment 6 remains active; consolidated directive/expression/pass/listing
  regressions and Phase 13 production fixture/reference comparisons are next.
- 2026-08-24: **Atomic Increment 6 partially verified; Phase 13 artifact
  comparison inconclusive.** All seven planned harness targets and four disk
  images build, and exact no-change targets are stable. Fresh live runs pass for
  `test_casm_directives`, `test_casm_progress`, `test_casm_expr`,
  `test_casm_pass1`, `test_casm_listcap`, `test_casm_passcheck`, and
  `test_casm_frame`, each with normal shell return. On the first production
  fixture command (`casm casmres1.s`), neither the 30-second nor stronger
  60-second observation established application completion or shell return.
  Per the bounded VICE workflow, no third observation or subsequent command was
  issued into the uncertain session. This is inconclusive, not a product
  failure; the four COMP-exact WP81/WP82 comparisons remain pending a clean
  retry with a longer declared deadline.
- 2026-08-24: **Atomic Increment 6 verification complete; user sign-off
  pending.** The user approved a clean retry with a 150-second pre-observation
  deadline. The first retry exposed retained dirty companion media
  (`OUTPUT WRITE FAILED`), not product behavior: soft reset had preserved the
  prior partial output. Device 9 was detached, the Phase 13 image was forced
  through fresh base-image generation, its directory was proven free of
  runtime output, and it was reattached. Fresh production runs of
  `casmres1.s`, `casmfill1.s`, `casmalign1.s`, and `casmincbin1.s` each printed
  `CASM: INPUT VALIDATED`, returned to `c64[9]:>`, and COMP reported
  `FILES COMPARE OK` against the trusted reference. No source change was
  required. Atomic Increment 7 must not begin until the user accepts this
  consolidated evidence.
- 2026-08-24: **Atomic Increment 6 approved complete; Atomic Increment 7
  pending.** The user accepted the consolidated harness, clean-media recovery,
  production COMP-reference, no-change, live-VICE, and shell-return evidence.
  Increment 6 remains active; directive-heavy timing, final envelope/no-change
  verification, walkthrough reconciliation, and the Increment 6 completion
  gate are next.
