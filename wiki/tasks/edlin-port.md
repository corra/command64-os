# Task Spec: EDLIN Port

## Objective

Port MS-DOS 4.00 EDLIN (`ms-dos/v4.0/src/CMD/EDLIN/`) to COMMAND64OS as a new
ca65/ld65 external app at `src/external/edlin/`. Design and phase breakdown
live in `brain/plans/2026-07-09-edlin-port-feasibility.md` and
`brain/plans/2026-07-09-edlin-implementation-phases.md`.

## Scope

- Flat VMM-backed text buffer, virtual line numbers via linear scan.
- Commands: edit-line, Insert, Delete, List, Page, Quit, Write/Append
  streaming, simplified Search/Replace.
- Out of scope: Copy/Move, Transfer/merge, `^V` quoting, DBCS/Kanji, message
  retriever indirection, dynamic screen-geometry paging, Ctrl-Break abort.

## Checklist

- [x] Phase 0 — Scaffold (`0.1.0`): app builds, appears in disk image, and
      boots/prints version banner in VICE — verified by user.
- [x] Phase 1 — Buffer core (`0.1.1`): VMM-backed buffer, file load, line
      scan — complete. Kernel prerequisite (`DOS_VMM_READ`/`DOS_VMM_WRITE`,
      `wiki/tasks/vmm-block-io.md`) landed and verified in VICE first. App
      side (`buffer.s`) verified against a 4-line test file: correct line
      count and byte offsets. REU-absent fallback path is implemented but
      not yet exercised against a no-REU config — carried forward.
- [x] Phase 2 — Core read/navigate (`0.1.2`): List/Page, line-number args,
      own line-input loop — complete. User-verified in VICE against a
      30-line fixture: `L`, `1,5L`, `P` (twice, confirming current-line
      repositioning), `<N>,<N>P` as a jump-to-line workaround. Three real
      bugs found and fixed (two via static re-read before ever touching
      VICE, one — a stale-flag bug only a *sequence* of commands could
      surface — during live testing). Detail/fixes:
      `brain/plans/2026-07-09-edlin-implementation-phases.md`.
- [x] Phase 3 — Edit commands (`0.1.3`): edit-line, Insert, Delete, Quit.
- [x] Phase 4 — Save/streaming (`0.1.4`): Write, Append, exit-drain save.
- [ ] Phase 5 — Search/Replace (`0.1.5`): simplified, no quote-char escaping.
- [ ] Phase 6 — Hardening/tests/docs (`0.1.6`): `tests/src/edlin/`, REU-absent
      fallback test, `docs/apps/edlin.md`, CHANGELOG entry.

## Verification

- `cmake --build build --target test_image_d64` clean after each phase.
- Manual VICE pass per phase per that phase's exit criteria in the
  implementation-phases plan.
- Full end-to-end create/edit/save/reload cycle verified in VICE before
  closing Phase 6.
