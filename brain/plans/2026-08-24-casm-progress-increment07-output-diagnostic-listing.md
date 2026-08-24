---
feature: casm-progress-increment07-output-diagnostic-listing
created: 2026-08-24
status: proposed
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment06-directive-integration, approved and complete
---

# Plan: CASM Progress Increment 7 - Output, Diagnostics, Listing, and Map

## Status

**Proposed, not yet approved.** Parent plan:
`brain/plans/2026-07-29-casm-feature-progress-indication.md`.

## Objective

Complete production integration for primary-output byte accounting, finalization,
diagnostic clearing, `/L` and `/M` suspension, and the successful final summary.

## Output and Screen Contract

- Count complete physical PRG/R6 bytes only after successful writes: header,
  body, final short flush, relocation chunks, and footer. Exclude `.LST` bytes.
- Prefer dedicated accounting at `emitFlush` and relocation write sites over a
  rendering call from generic `fileWrite`; preserve existing 64-byte writes.
- Redraw output progress only when the accumulated total crosses a 256-byte
  boundary and once after the final successful short write.
- Announce finalization after pass/listing-capture agreement and before
  `emitFinalize`; print success only after output commit and optional `/L`/`/M`
  work succeeds.
- Clear transient status at entry to `diagPrintFatal`, preserving diagnostic A
  and never recursing into fatal diagnostics.
- Suspend idempotently once before `listingWriteFile` and once before `mapPrint`;
  never instrument listing rows, map symbol iteration, or VMM capture loops.
- Preserve current order: PRG commit, listing commit, map rows, final success.

## Atomic Increments

1. Add primary-artifact accounting for emit flushes and relocation table/footer.
2. Add 256-byte throttling, final short-write handling, and full-size summary.
3. Add finalization transition and output-commit ordering tests.
4. Add universal fatal transient clear with diagnostic-ID preservation tests.
5. Add orchestration suspension before `/L` and `/M`, including option combinations.
6. Replace/reconcile existing success text with the approved final summary.
7. Run output-commit, relocation, listing/listcap/listwrite/fault, map, source-fault,
   cleanup, and production option-identity comparisons.
8. Measure size/performance, no-change build, and write walkthrough evidence.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/casm.s` | Modify orchestration |
| `src/external/casm/progress.s` | Extend |
| `src/external/casm/emit.s`, `reloc.s` | Add successful primary-write accounting |
| `src/external/casm/diagnostics.s` | Add transient clear entry call |
| `src/external/casm/listing.s`, `map.s` | Review; modify only if orchestration cannot own suspension |
| Focused and existing fault harnesses | Extend as required |

## Stop Conditions

Stop if listing bytes contaminate totals, flush boundaries change, success prints
before commit, diagnostic A is lost, an import cycle appears, row loops require
instrumentation, committed PRG behavior changes after listing/map failure,
performance/envelope caps fail, tests drift, or an unrelated defect appears.

## Documentation, Task, and DOX Updates

Update feature trackers and technical evidence. Do not yet advertise the feature
as shipped. Keep real-time `/M` and duration backlog records separate.

## Completion Gate

Byte totals equal physical artifacts, all screen/failure orderings and option
combinations pass, regressions and caps pass, walkthrough exists, and user approves.

## Progress

- 2026-08-24: Detailed plan drafted; final production integration not authorized.
