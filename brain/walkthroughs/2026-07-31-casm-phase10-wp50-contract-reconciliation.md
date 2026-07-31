# CASM Phase 10 WP50 Verification Walkthrough

Status: Complete; user approved 2026-07-31
Branch: `feature/casm-phase10-wp50`
Candidate: CASM `0.1.51` build `1206`

## Scope

WP50 reconciles the approved Phase 10 parent-plan contract (symbol map and
native listing) against the live Phase 9 source, freezes the ABI WP51-WP55
depend on, and adds no production behavior. It develops and approves the
WP51-WP55 dedicated plans, resolves any open design question those plans
depend on, and measures the unchanged baseline before requesting a
version-only `0.1.51` completion bump.

## Static Reconciliation

Every claim in the WP50 plan's "Reconciled Findings" and ABI-freeze sections
was independently re-traced against the current `src/external/casm/` source
(not re-derived from the plan's own prior wording) and confirmed exact:

- `CasmStmtLoc*` (`state.s:169-172`) carries file/line/column only, no source
  offset or physical line length.
- `CasmSourceOffset*` (`state.s:72-73`, `source.s:1663-1691`) is a per-line
  boundary count that resets every line, not an absolute VMM address.
- `CasmSourceVmmCursor*` (`source.s:153-181`, `1774`) is the bulk-refill read
  head, confirmed by the module's own comments to be distinct from parse
  position.
- Token record is exactly 39 bytes (`common.inc:573`, asserted).
- Lexer state is exactly 47 bytes (`state.s:181`, asserted).
- Next free diagnostic is `$39` (`common.inc:726` shows WP47's range ends at
  `$38`).
- MAIN envelope is `$3900`-`$7BFF` (`$4300`, `casm_3900.cfg`); a fresh
  `ld65 --mapfile` relink from the current `.o`s (no source change) measured
  BSS ending at `$7BAB`, confirming exactly 85 bytes of free headroom.

No discrepancy was found between the plan's claims and the live source.

## Baseline Build Drift (Resolved, Benign)

The plan's recorded baseline of build `1204` is stale on `main`: commit
`f3b2e14` (DASH WP6, 2026-07-30) changed the shared `include/ca65/command64.inc`
header, which CASM's hash-gated build counter depends on, bumping
`BUILD_CASM` to `1205` alongside all nine `tests/src/casm_*` counters. No file
under `src/external/casm/` changed in that commit. This is recorded in the
WP50 plan's "Baseline Build Drift" section; the measured baseline in this
walkthrough is build `1205`.

## Resolved Design Question: Listing File Replacement

The parent and WP50 plans flagged an open question: WP53 needs safe
listing-file (`.LST`) replacement/deletion semantics, but no `DOS_OPEN_FILE`
replace mode was known to exist.

Traced `fileOpen` (`src/command64/file.asm:75`), `normalizeName`, and
`parsePointerDevice` (`src/command64/utils.asm:88,783`): `normalizeName` only
case-shifts A-Z, and `parsePointerDevice` matches only a literal
`8:`/`9:`/`10:`/`11:` prefix, forwarding everything else (including `@` and
`:`) untouched through `SETNAM`. This means CASM can embed CBM DOS's native
`@0:` replace marker itself -- `<device-digits>:@0:<basename>.LST` -- and no
`DOS_OPEN_FILE` change is required. `@0:` is unconditionally safe on real CBM
DOS whether or not the target exists (atomic scratch-and-rename), so WP53 uses
it unconditionally with no existence probe.

This is traced from source only, not yet runtime-verified. WP53's plan was
amended to require a `test_casm_listwrite` fixture proving the drive honors
`@0:` under VICE before production sequencing (WP54) relies on it.

## Dedicated Work-Package Plans

WP51-WP55 dedicated plans already exist under `brain/plans/` and are each
`approved-blocked`, chained by `depends-on` down to WP50. WP53's plan was
amended in this session to carry the resolved listing-replacement mechanism.
No other WP51-WP55 plan required amendment during this reconciliation.

## Baseline Measurement Record

Recorded in full in the WP50 plan's "Baseline Measurement Record" section:
PRG size 18,694 bytes with an intact R6 footer marker; segment sizes CODE
11,788 / RODATA 2,690 / BSS 2,590 bytes; MAIN headroom 85 bytes; CASM's
private zero page fully allocated (no new byte approved); `MAX_HANDLES = 8`
shared OS-wide; VMM worst-case occupancy already reconciled in the parent plan
(six of eight slots). No disk image rebuild was needed since no source
changed; a same-source `casm` target build reported already up to date.

## Documentation and Task Sync

`brain/task.md`, `wiki/tasks/casm.md`, and Taskwarrior (`task ad82f04d...`)
all agree WP50 is the sole active Phase 10 package, with WP51-WP55 pending and
blocked. No sync correction was required.

## Version-Only Completion Increment

User approved WP50 completion 2026-07-31. Applied the only production change
WP50 authorizes: `VERSION_STAGE` `"50"` -> `"51"` in `casm.s`. Results:

- The hash-gated build counter advanced exactly once: `1205` -> `1206`.
- A subsequent no-change rebuild reported the `casm` target already built,
  with no further counter movement.
- `build/casm.prg` held at 18,694 bytes, identical to the pre-bump size,
  confirming only the version-string bytes changed (both `"50"` and `"51"`
  are two PETSCII characters).
- `image_d64` and `test_image_d64` both rebuilt successfully, each carrying
  the updated `casm` PRG (74 blocks) in their directory listings.

## Completion Gate

Met 2026-07-31. CASM stands at `0.1.51` build `1206`, stable on no-change
rebuild. WP51 remains blocked pending its own explicit activation.
