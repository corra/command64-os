---
feature: casm-progress-increment05-source-include-integration
plan: brain/plans/2026-08-24-casm-progress-increment05-source-include-integration.md
date: 2026-08-24
status: approved
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
---

# Walkthrough: CASM Progress Increment 5 -- Source and Include Integration

## Summary

The transient status line renders for the first time. Increment 4 wired the
counting and the persistent lines but never called
`progressRenderTransient`, so `progressStatement`'s "redraw due" verdict was
computed and thrown away and the `p1: dNN fNN NAME lNNNNN tNNNNN` line
never appeared at all. Increment 5 closes that, adds source/include load
reporting, and tracks file identity across include push, pop, cascading
pop, and root transitions.

Four real defects were found and fixed here, every one of them caught by
watching the actual screen under VICE rather than by reasoning about the
code.

## Scope reconciliation

This plan's Hook Contract predates the Increment 2 review and asked for
byte-cadence load reporting that Increment 2 had dropped (with approval,
and with the parent plan formally amended). Raised before implementing;
the user chose **reconciled scope + restore byte cadence**. So
`progressSourceLoadBytes` is back for source/include loading only --
`.INCBIN`/`.RES`/`.FILL`/`.ALIGN` cadence stays dropped -- and the parent
plan is re-amended to match.

## What was built

- **`progress.s`**: `progressSourceLoadBytes` restored. It takes the
  *cumulative committed cursor* rather than a per-block delta, because
  `source.s`'s `CasmSourceStreamCursor` is advanced only after a
  `vmmWindowWrite` succeeds -- it is already exactly the "cumulative
  committed cursor, not final 64-byte chunk" the Hook Contract asks for.
  Passing it whole means progress.s keeps no load accumulator and cannot
  drift from the real committed total.
- **`source.s`**: one hook in `sourceAppendFile`, at the point an
  up-to-256-byte input block has fully committed (every 64-byte chunk
  written). A short final block reaches the same point, so "report the
  final short block" needs no separate EOF hook. The hook cannot fail and
  introduces no carry path into the load loop.
- **`casm.s`**: `crpProgressHook` replaces the four bare `progressStatement`
  calls. It redraws when the 64-statement throttle fires **or** when file
  identity changed, and `crpSnapshotName` resolves the active filename.

## Design: one identity check covers every traversal transition

Rather than hooking `sourceFramePush`/`sourceFramePopInternal` directly,
`crpProgressHook` compares the active `(file id, frame depth)` against what
the line last displayed. Any push, pop, *every* step of a cascading pop, and
any root transition changes that pair; the next dispatched statement sees
it, re-resolves the name, and redraws immediately, bypassing the throttle.

This is strictly "after commit" by construction (a statement cannot
dispatch until traversal state is committed), needs no hook inside
`source.s`'s frame machinery, and keeps every `cli.s`/`include.s`
dependency in `casm.s`, which already imports them -- `source.s` must not
depend on `include.s` (the layering WP46 froze). The only deviation from
the plan's literal wording is that notification lands on the next
statement rather than the instant of commit, which for a status *display*
is equivalent and strictly safer.

## Four defects found live

1. **Width mismatch shredded the screen.** `CASM_PROG_LINE_WIDTH` was 38
   but the status line printed 27 characters, so every redraw rewound 11
   columns too far and walked backwards through the output above it. The
   first capture is unreadable garbage. Fixed by making the width contract
   exact (34 columns) and documenting that every builder must print
   exactly that many characters -- with per-field character budgets in the
   code so the next change cannot silently break it. The load line is
   space-padded to the same 34.
2. **First render ate the persistent line.** `progressRenderTransient`
   rewound before it had ever drawn anything, so the first redraw after
   `p1: start` (which ends in `PetCr`, leaving the cursor at column 0 of a
   fresh row) walked 34 columns left into the row above and overwrote it --
   `P1: START` was being chewed down to `P1: ST`. Fixed with the same
   already-visible guard `progressClearTransient` uses.
3. **Include loads showed the parent's filename.** `crpInclude` never
   re-seeded identity before the child's load, so `LOAD F00 i5main.s`
   appeared while `i5child.s` was actually being read. Fixed by seeding the
   name from `CasmIncludeFilename` (the operand just parsed) before
   `includeCatalogLoad`. Note the code comment claiming this was already
   handled was written before the code was -- caught by the live capture,
   not by review.
4. **Identity could not be resolved from `CasmSourceFileId` at all.** The
   pop left the child's name on screen; investigating showed
   `CasmSourceFileId` reads `$00` for *both* a parent and its included
   child -- it never carries the frame flag or catalog index -- so the
   packed decode borrowed from `diagnostics.s` returned the top-level slot
   at any nesting depth, and once identity-change detection started firing
   it actively *overwrote* the correct child name with the parent's. Fixed
   by resolving from the authoritative frame stack instead:
   `CasmFrameCatalogIndex[depth-1]` at depth > 0, top-level slot at depth 0.

Defect 4 is worth remembering: a field that looks like a file identity is
not necessarily maintained as one on every path.

## Envelope

MAIN was grown a second time, `$7000` -> `$7400` (+1024 bytes), on measured
evidence and explicit approval, per the parent plan's own rule. Headroom
across this increment: 340 bytes at entry -> 101 after restoring the byte
cadence -> 56 after the width fix -> 42 after the first-render guard ->
**~1050 bytes after the growth**, with Increments 6-11 still ahead. Still
~4.4KB clear of the hard `$C000` I/O boundary.

Nine test harnesses needed envelope bumps: eight because they link
`source.s` (which now calls `progressSourceLoadBytes`, so they link
`progress.s` too), and `casm_spanread` twice as growth accumulated. Each
bump is the smallest round-page fit with its measured overflow recorded in
`CMakeLists.txt`, matching this codebase's long-standing convention.

## Evidence

Live under VICE, assembling a 452-statement two-file fixture
(`i5main.s` with a `.INCLUDE` of `i5child.s`):

- Transient line redraws cleanly in place, throttling at exactly
  64/128/192: `P1: D00 F00 i5main.s L00065 T00064` -> `L00129 T00128` ->
  `L00193 T00192`.
- Depth tracks the include: `D00` -> `D01` on push -> `D00` after pop, the
  push redraw landing immediately at the transition rather than waiting
  for the throttle.
- Load lines report the child during its load:
  `LOAD F00 i5child. 01488` -> `01744` -> `01832`.
- Pass totals agree and assembly completes normally
  (`P1: DONE 00452 STATEMENTS`, `P2: DONE 00452 STATEMENTS`).
- Full build clean; no-change rebuild stable.

## Known limitations (honest)

- During an include's *load* the `fNN` field still shows the parent's id,
  because the child's catalog index does not exist until
  `includeCatalogLoad` returns. The *name* is correct from the first
  block, which is what identifies the file on screen.
- The load line uses a compact `LOAD FNN NAME NNNNN` form without the
  status line's `f`/`l`/`t` markers.
- No synthetic production-source fixture yet drives the counter-overflow
  or pass-total-mismatch diagnostics through real dispatch; both are
  covered at module level by `test_casm_progress`. Increment 8 (automated
  verification) is the natural home for that.

## Completion Gate

- [x] Committed-block load cadence, identity, depth, filename, line, and
      throttle cadence all verified live.
- [x] Pass 2 performs no source file I/O: the load hook sits inside
      `sourceAppendFile`, reached only through the Pass-1-only
      `CASM_PASS_MODE_MEASURE` branch of `crpInclude`.
- [x] No catalog/frame/event record changed; no new zero page.
- [x] Envelope growth measured and approved; no-change rebuild stable.
- [x] Trackers agree (Taskwarrior annotated; plan Progress update below).
- [x] User approves Increment 5.
