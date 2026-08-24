---
feature: casm-progress-increment02-design-abi-review
plan: brain/plans/2026-08-24-casm-progress-increment02-design-abi-review.md
date: 2026-08-24
status: awaiting-approval
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
---

# Walkthrough: CASM Progress Increment 2 -- Design and ABI Review

## Summary

All six atomic increments executed. Rather than reasoning about feasibility
in the abstract, a real `progress.s` was written against the parent plan's
full spec, assembled with `ca65`, and linked with `ld65` against CASM's
actual `casm_3800.cfg` and actual compiled object files -- giving exact,
linker-verified numbers instead of estimates at every decision point. Full
detail, the frozen ABI, and the three findings are in
`brain/reviews/2026-08-24-casm-progress-design-abi-review.md`; this
walkthrough summarizes the increment's own execution.

## Increment 1: Re-read Increment 1 evidence and current source contracts

Re-confirmed against the committed Increment 1 walkthrough: MAIN envelope
231 bytes (0.8%) headroom, CASM zero page (`$70-$8F`) fully allocated, no
byte-heavy timing fixture exists yet. Re-read `casm.s`, `emit.s`,
`diagnostics.s`, `source.s`, `include.s` at their current (unchanged since
Increment 1) state.

## Increment 2: Resolve the five proposed decisions

All five adopted as originally proposed -- none required a tradeoff only
the user could judge (statement-counting timing, output-byte definition,
best-effort rendering vs. fatal diagnostics, a dedicated test harness/disk,
and the one-way `progress.s`/`diagnostics.s` import boundary are all
technical defaults consistent with the rest of the codebase's conventions).
A sixth, unplanned decision *did* need the user: see Increment 3 below.

## Increment 3: Produce the ABI, BSS map, call graph, screen layout, diagnostics

Produced by actually writing and measuring the module, not by drafting
tables in the abstract. This surfaced three real findings before any
production source was touched:

1. **The full spec does not fit 231 bytes -- by exactly 573 bytes**
   (measured: 804 bytes needed; `ld65`'s own overflow error, not an
   estimate). Presented to the user with three options (shrink to fit,
   grow MAIN, or split); the user chose to split the difference and asked
   that the untaken road be noted for future expansion.
2. **A caller-supplied filename pointer needs zero page**, which the ABI
   forbids -- `ca65` rejected `(ptr),Y` addressing outright. Resolved by
   having the caller copy the truncated 8-byte name into a buffer
   `progress.s` owns (allowed "bounded rendering scratch"), not a pointer.
3. **`CASM_DIAG_PASS_MISMATCH` ($2F) already exists** (Phase 6B/WP30,
   raised today by `emitCheckPassAgreement`'s final-PC check) but is a
   different check than the new statement-count disagreement the parent
   plan wants -- two new contiguous IDs (`$55`/`$56`) were frozen instead
   of reusing it, matching the parent plan's own explicit "not a
   replacement for final PC ... agreement" instruction.

The resulting split: scope trimmed (dropped `progressSourceLoadBytes` and
`progressDirectiveBytes` -- the source-load and `.INCBIN`/`.RES`/`.FILL`/
`.ALIGN` byte-cadence transient displays, which feed nothing else and cost
70 measured bytes to keep) and MAIN grown from `$6C00` to `$7000` in
`casm_3800.cfg`/`casm_3900.cfg`. Verified by re-linking the trimmed module
against CASM's real objects at the grown size: succeeds, with 1033 bytes
of fresh headroom remaining (`__MAIN_LAST__` = `$A5F7` against
`__MAIN_SIZE__` = `$7000`), still 6665 bytes clear of the `$C000` hard
boundary.

Full routine table, BSS map (22 bytes, no zero page), screen protocol
(38-column transient field, `PetLeft`-based in-place redraw, fixed-width
zero-padded decimal fields matching the plan's own `d03`/`f07`/`l00128`/
`t00412` examples), and diagnostic IDs are frozen in the review document.

## Increment 4: Prove no cycle, no record growth, no unbounded loop, no ZP growth

- **Import cycle**: none. `progress.s` owns private duplicates of
  `diagPrintString`/`printChar`/`printDec16`-equivalents rather than
  importing `diagnostics.s`'s (which are either not exported or would
  create a two-way edge); `diagnostics.s` will import only
  `progressClearTransient`. The successful link across every real CASM
  object plus `progress.o` is itself proof no `.import`/`.export`
  resolution failure exists.
- **Zero page**: zero bytes added -- Finding 2 above was resolved
  specifically to keep this true.
- **Record growth**: none. Audited every parser/token/include/frame/
  symbol/listing/map/relocation/directive record; `progress.s` never holds
  a pointer into or writes any of them.
- **Unbounded loops**: none. Every loop (digit extraction, name copy,
  cursor-return, line-clear) has a static bound, mirroring
  `diagnostics.s`'s own proven `printDec16` shape for the one genuinely
  data-dependent loop (bounded by the 16-bit value range itself).

## Increment 5: Freeze focused harness and dedicated-disk contracts

Proposed decision 4 confirmed: a new `test_casm_progress` harness and a
dedicated, self-bootable, writable `casm_progress_test_d64` -- not reusing
`casm_overflow_test.d64` (only 23 free blocks per Increment 1) or any other
existing disk. Deferred to Increment 8 (automated verification) to actually
create; frozen here only as the contract.

## Increment 6: Static peer review and this walkthrough

Self-reviewed against the parent plan's full "Register, Flag, and Scratch
Contract" checklist -- no unresolved finding. Detail in the review document.

## Stop Conditions

The "MAIN increase before measurement and approval" stop condition
*was* triggered by Finding 1 -- correctly: measurement was taken (exact,
linker-verified), and approval was obtained from the user before any
production source edit, exactly as the parent plan requires. No other stop
condition triggered.

## Completion Gate

- [x] Every ABI/storage/layout decision is explicit (review document).
- [x] Peer review has no unresolved finding.
- [x] This walkthrough exists.
- [ ] Trackers agree (Taskwarrior annotation and plan Progress update follow
      this walkthrough).
- [ ] User approves the design before Increment 3 source edits.
