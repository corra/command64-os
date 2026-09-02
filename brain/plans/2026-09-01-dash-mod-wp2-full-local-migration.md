---
feature: dash-mod-wp2-full-local-migration
created: 2026-09-01
status: done (user-approved 2026-09-01)
taskwarrior: task 51 (child of 94ec17b3)
depends-on: DASH-MOD WP1 (CASM .ASSERT ca65 keyword, done -- brain/walkthroughs/2026-09-01-dash-mod-wp1-casm-assert-ca65-keyword.md)
---

# Plan: DASH-MOD WP2 - Full `@local` migration (output-preserving)

## Status

**Proposed, not yet approved.** Second WP of the DASH Modernization
increment. Parent: `brain/plans/2026-09-01-dash-modernization.md`. WP1
approved and done. Branch: `feature/casm-phase14`. Baseline: DASH shipping
manifest sha256 `3238b786...`, 4766 bytes (unchanged since Phase 14 WP91).

## Objective

Convert every routine-local helper label in DASH's code files to a
`@local` cheap local. **Pure rename -- the assembled bytes must be
byte-for-byte identical to the current shipping manifest** under both ca65
and native CASM. No structural change, no behavior change.

**Delivered:** ~90 global labels demoted to `@local` across `dscr.s`,
`dsys.s`, `dapp.s`, `dvmm.s`, and a small isolated set in `dmain.s`.
DASH's `/M` symbol map shrinks correspondingly; the code reads with short
idiomatic `@LOOP`/`@DONE`/`@FAIL` names instead of manual routine
prefixes.

**Excluded (deferred, by design):**
- `dmain.s`'s event-loop block (`EVENTLOOP`/`POLLINPUT`/`SELECT*`/
  `TRYRUNVMMTEST`/`SETREDRAW`/`EXITAPP` and their targets) -- WP4
  restructures this whole graph; localizing then rewriting is churn.
  WP2 touches only `DISPATCHPAGE`'s own three internal labels.
- `dscr.s`'s `DRAWFRAME` internals (`ROW0LOOP`..`ROW23LOOP`,
  `DRAWMIDROWS`, `CLEARMIDROWLOOP`, `DRAWMIDDONE`) -- WP5 collapses the
  7 row loops into one `COPYROW` helper; those labels disappear.
- `dapp.s`'s `DAPPPRINTFLAGS` internals (`DAPPF{U,R,V,S}_{OFF,PRINT}`) --
  WP5 collapses the 4 flag cells into one helper.
- `dfmt.s` -- already fully migrated in Phase 14 WP91 (`@LOOP`/`@DONE`/
  `@SKIP` in `FORMATDEC16`/`PETTOSCREEN`/`DIV10`); nothing left.
- `ddata.s` -- all-data, its labels are the cross-file symbol surface,
  stay global.
- `PRINTAT` (`dfmt.s` line 3) -- referenced from nowhere; possibly dead.
  Flagged for WP5 investigation, untouched here (it is a file-leading
  routine entry with no preceding scope, so it *cannot* be a `@local`
  anyway).

## Eligibility method (done, this session)

A label is `@local`-eligible iff it is defined inside a routine and
**every reference to it is a branch / jump within that same routine's
span**, where routine boundaries are the "entry" labels: those
JSR'd anywhere, referenced from another file, or named in a `.WORD`
table (`ddata.s`). A static pass over all seven files (recorded in this
WP's walkthrough) classified every code-file label. Result: every
non-entry label is `OK` (all refs in-span). No cross-routine helper is a
false candidate.

Independent safety net: a mis-localized cross-routine label **fails to
assemble** -- CASM raises `UNDEFINED LOCAL`/`UNDEFINED SYMBOL` from the
out-of-scope reference, ca65 raises a cheap-local scope error. It cannot
silently produce wrong bytes. Byte-identity vs the manifest is the final
backstop.

DASH has **no mid-code `=` equate** (all 11 are at the top of `dmain.s`),
so ca65's and CASM's cheap-local scope boundaries coincide throughout --
re-confirmed per file during implementation.

## Per-file candidate lists

Names shown as `WAS -> @NEW`. `@NEW` drops the routine prefix; each is
unique within its owning `NAME:`-to-`NAME:` scope.

### `dscr.s`
- `CLEARSCREEN`: `CLEARLOOP -> @LOOP`, `CLEARREMLOOP -> @REMLOOP`
- `SCREENSETCURSOR`: `SSC_INVALID -> @INVALID`
- `SCREENPUTCHAR`: `SPC_INVALID -> @INVALID`
- `SCREENPUTSTRING`: `SPS_LENOK -> @LENOK`, `SPS_LOOP -> @LOOP`,
  `SPS_TRUNCATED -> @TRUNCATED`, `SPS_DONE -> @DONE`
- `HIGHLIGHTTABS`: `HT_LOOP -> @LOOP`, `HT_COLORSET -> @COLORSET`,
  `HT_FILL -> @FILL`, `HT_NEXTTAB -> @NEXTTAB`, `HT_DONE -> @DONE`

### `dsys.s`
- `PRINTDEC16`: `PD16SKIP -> @SKIP`, `PD16FOUND -> @FOUND`
- `DSYSRENDER`: `DSYSFAIL -> @FAIL`
- `DSYSROWVERSION`: `DSYSVERDONE -> @DONE`
- `DSYSROWVIDEO`: `DSYSVIDNTSC -> @NTSC`, `DSYSVIDPAL -> @PAL`,
  `DSYSVIDPRINT -> @PRINT`
- `DSYSROWVMM`: `DSYSVMMINACTIVE -> @INACTIVE`, `DSYSVMMPRINT -> @VMMPRINT`,
  `DSYSREUUNPROBED -> @UNPROBED`, `DSYSREUPRINT -> @REUPRINT`
  (four in one scope -- kept distinct)
- `DSYSROWPGSIZE`: `DSYSPGSIZENA -> @NA`
- `DSYSROWPGTOTAL`: `DSYSPGTOTALNA -> @NA`
- `DSYSROWUSEDFREE`: `DSYSUSEDFREENA -> @NA`

### `dapp.s`
- `DAPPRENDER`: `DAPPLOOP -> @LOOP`, `DAPPCHECKFAIL -> @CHECKFAIL`,
  `DAPPNEXTSLOT -> @NEXTSLOT`, `DAPPLOOPDONE -> @LOOPDONE`,
  `DAPPDONE -> @DONE`, `DAPPQUERYERR -> @QUERYERR`
- `DAPPPRINTNAME`: `DAPPNAMELOOP -> @LOOP`, `DAPPNAMEPAD -> @PAD`,
  `DAPPNAMEDONE -> @DONE`
- `DAPPPRINTRANGE`: `DAPPRANGEBAD -> @BAD`

### `dvmm.s`
- `DVMMREFRESHCAP`: `DVMMRC_UNAVAIL -> @UNAVAIL`, `DVMMRC_DONE -> @DONE`
- `DVMMRENDERSTATUS`: `DVMMRS_UNAVAIL -> @UNAVAIL`, `DVMMRS_READY -> @READY`,
  `DVMMRS_RUNNING -> @RUNNING`, `DVMMRS_PASSED -> @PASSED`,
  `DVMMRS_FAILED -> @FAILED`, `DVMMRS_PRINT -> @PRINT`
- `DVMMRENDERDETAIL`: `DVMMRD_HASRUN -> @HASRUN`, `DVMMRD_SHOWFAIL -> @SHOWFAIL`,
  `DVMMRD_STGALLOC -> @STGALLOC`, `DVMMRD_STGWRITE -> @STGWRITE`,
  `DVMMRD_STGREAD -> @STGREAD`, `DVMMRD_STGCOMPARE -> @STGCOMPARE`,
  `DVMMRD_STGFREE -> @STGFREE`, `DVMMRD_STGPRINT -> @STGPRINT`,
  `DVMMRD_SHOWOFFSET -> @SHOWOFFSET`, `DVMMRD_INSTRUCTION -> @INSTRUCTION`,
  `DVMMRD_INSTRUNAVAIL -> @INSTRUNAVAIL`, `DVMMRD_INSTRRESTART -> @INSTRRESTART`,
  `DVMMRD_INSTRPRINT -> @INSTRPRINT`
- `DVMMRUNTEST`: `DVMMRT_CHECKSTATE -> @CHECKSTATE`,
  `DVMMRT_CHECKUNAVAIL -> @CHECKUNAVAIL`, `DVMMRT_PROCEED -> @PROCEED`,
  `DVMMRT_ALLOCOK -> @ALLOCOK`, `DVMMRT_PATTERNLOOP -> @PATTERNLOOP`,
  `DVMMRT_BLOCKLOOP -> @BLOCKLOOP`, `DVMMRT_WOK -> @WOK`,
  `DVMMRT_READPHASE -> @READPHASE`, `DVMMRT_COMPAREPHASE -> @COMPAREPHASE`,
  `DVMMRT_BLOCKDONE -> @BLOCKDONE`, `DVMMRT_CLEANUP -> @CLEANUP`,
  `DVMMRT_DONE -> @DONE`, `DVMMRT_FREEFAIL -> @FREEFAIL`,
  `DVMMRUNTEST_REJECT -> @REJECT`
- `DVMMCHECKBLOCK`: `DVMMCHK_OK -> @OK`
- `DVMMFILLPATTERN`: `DVMMFP_LOOP -> @LOOP`
- `DVMMCLEARBUFFER`: `DVMMCB_LOOP -> @LOOP`
- `DVMMGENBYTE`: `DVMMGB_00 -> @Z00`, `DVMMGB_55AA -> @Z55AA`,
  `DVMMGB_55 -> @Z55`, `DVMMGB_INCR -> @INCR` (leading digit not allowed
  after `@`, so `@Z55` not `@55`)
- `DVMMCOMPAREBLOCK`: `DVMMCMP_LOOP -> @LOOP`, `DVMMCMP_MISMATCH -> @MISMATCH`

### `dmain.s` (minimal -- rest deferred to WP4)
- `DISPATCHPAGE`: `PAGEVALID -> @PAGEVALID`,
  `DISPATCHRETURNMINUSONE -> @RETURNMINUSONE`,
  `DISPATCHRETURN -> @RETURN` (`#>`/`#<` extraction of a `@local`
  address -- byte-identity confirms both assemblers handle it; if
  either does not, that pair reverts and stays global, documented).

## Atomic Increments

One file per increment; each ends with the ca65 byte-identity check.

1. `dscr.s` -> convert, `check_casm_source_bytes.py` still passes,
   `cmake --build build --target dash_ref`, `cmp dash_ref.prg` against the
   shipping-manifest transcription -> **byte-identical**.
2. `dsys.s` -> same.
3. `dapp.s` -> same.
4. `dvmm.s` -> same.
5. `dmain.s` (the `DISPATCHPAGE` three) -> same. If `@RETURNMINUSONE`'s
   `#>`/`#<` misbehaves under ca65, revert that pair.
6. **Native CASM + manifest.** One live VICE run: `CASM DMAIN.S
   /O:DASH.PRG` on `command64_casm_utils.d64`, `COMP DASH.PRG DASH.REF`
   -> `FILES COMPARE OK`. Extract `dash.prg`; `cmp` against both
   `dash_ref.prg` and the pre-increment shipping bytes -> byte-identical
   three ways. `build_dash_manifest.py --cross-check build/dash_ref.prg`
   regenerates `dash.ref.hex` -- **same 4766 bytes, same sha256**, fresh
   `source_sha256` for the four (five) changed files. `dash` CMake target
   builds clean.
7. Fire `c64-overlay-api` test events (curl fallback).

## Expected Files

| File | Action |
| --- | --- |
| `src/external/dash/dscr.s` `dsys.s` `dapp.s` `dvmm.s` `dmain.s` | Modify -- label renames only |
| `src/external/dash/dash.ref.hex` | Regenerate -- source hashes only, bytes unchanged |
| `src/external/dash/BUILD_DASH_REF` | Auto |
| `brain/walkthroughs/2026-09-0X-dash-mod-wp2-full-local-migration.md` | Create |
| `brain/plans/2026-09-01-dash-modernization.md` | Append Progress |
| `wiki/tasks/dash-modernization.md` | Tick WP2 |

## Stop Conditions

- ca65 `dash_ref.prg` differs by one byte from the shipping-manifest
  bytes after any file -> that file's last batch of renames is wrong;
  bisect and revert.
- Native CASM `DASH.PRG` is not byte-identical to `dash_ref.prg`.
- `build_dash_manifest.py` reports any byte change, or would need
  `--allow-host-bytes`.
- `check_casm_source_bytes.py` rejects a renamed file.
- A candidate label turns out to be cross-routine referenced (assembly
  fails) -> that label stays global; note it.
- Any construct needed that is outside the dual-assembler subset (none
  expected -- this is pure renaming).

## Documentation, Task, and Tracker Updates

- **At approval:** Taskwarrior WP2 (child of `94ec17b3`).
- **At completion:** walkthrough (with the full eligibility analysis
  table); parent plan Progress; `wiki/tasks/dash-modernization.md` tick.
  No `AGENTS.md` change (the `@local` rule is already stated, WP91).
  `CHANGELOG` / version at WP6.

## Completion Gate

- All five files converted; every deferred set explicitly listed as
  deferred (not forgotten).
- ca65 `dash_ref` == native CASM `DASH.PRG` == pre-increment shipping
  manifest, byte-for-byte.
- `dash.ref.hex` regenerated: identical bytes, identical sha256, updated
  source hashes, `--cross-check` MATCHES, no `--allow-host-bytes`.
- `dash` + `dash_ref` + `command64_casm_utils_d64` + `image_d64` +
  full `cmake --build build` clean.
- Walkthrough with live evidence; trackers synced; explicit user
  approval.
- (Runtime is not separately re-verified here -- byte-identical output
  means the running DASH is bit-for-bit the shipped one. Runtime
  re-verification starts at WP4, the first WP that changes bytes.)

## Progress

- 2026-09-01: Drafted for review. Eligibility analysis complete (all
  code-file labels classified; ~90 clean `@local` candidates, three sets
  deferred to WP4/WP5).
- 2026-09-01: **Approved.** Taskwarrior WP2 = task 51.
- 2026-09-01: Source-complete. 84 labels converted (dscr 13, dsys 14,
  dapp 10, dvmm 44, dmain 3). Five atomic increments, each ca65
  byte-identity-checked. Increment 6: native `CASM V0.5.2.1404` under
  VICE (image.d64 u8, command64_casm_utils.d64 u9, `DRIVE 9`,
  `CASM DMAIN.S /O:DASH.PRG` -> `04766 BYTES`, `INPUT VALIDATED`;
  `COMP DASH.PRG DASH.REF` -> `FILES COMPARE OK`). Extracted native
  `dash.prg` `cmp`-identical to `dash_ref.prg` and prior shipping bytes
  (all sha256 `3238b786...`). `dash.ref.hex` regenerated: same
  bytes/sha256, `--cross-check` MATCHES, source hashes updated for the 5
  changed files, no `--allow-host-bytes`. `dash` + full `cmake --build
  build` + `image_d64` green. Overlay `test`/`pass` fired. Walkthrough:
  `brain/walkthroughs/2026-09-01-dash-mod-wp2-full-local-migration.md`.
- 2026-09-01: **WP2 closed — user-approved.** Taskwarrior task 51 done.
