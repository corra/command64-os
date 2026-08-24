---
feature: casm-progress-increment06-directive-integration
created: 2026-08-24
status: proposed
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment05-source-include-integration, approved and complete
---

# Plan: CASM Progress Increment 6 - Directive Integration

## Status

**Proposed, not yet approved.** Parent plan:
`brain/plans/2026-07-29-casm-feature-progress-indication.md`.

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
