# Walkthrough: DASH-MOD WP2 - Full `@local` migration (output-preserving)

Plan: `brain/plans/2026-09-01-dash-mod-wp2-full-local-migration.md`
Parent: `brain/plans/2026-09-01-dash-modernization.md`
Taskwarrior: WP2 (task 51, child of `94ec17b3`)
Branch: `feature/casm-phase14`
Baseline: DASH shipping manifest sha256 `3238b786...`, 4766 bytes.

## What this WP delivers

**84 routine-local helper labels** demoted from global to `@local` cheap
locals across five DASH code files. Pure rename -- the assembled DASH.PRG
is **byte-for-byte identical** to the pre-increment shipping manifest
under both ca65 (`dash_ref`) and native CASM on real hardware, proven
three ways (see Verification).

| File | `@local` defs |
| --- | --- |
| `dscr.s` | 13 |
| `dsys.s` | 14 |
| `dapp.s` | 10 |
| `dvmm.s` | 44 |
| `dmain.s` | 3 (`DISPATCHPAGE` only) |
| **total** | **84** |

DASH's `/M` symbol map shrinks by 84 entries; routine internals now read
as `@LOOP`/`@DONE`/`@FAIL` instead of manual `SPS_`/`DAPP`/`DVMMRT_`
prefixes.

## Eligibility analysis (static pass over all seven files)

A label is `@local`-eligible iff it is defined inside a routine and every
reference to it is a branch/jump within that same routine's span, where
routine boundaries are the "entry" labels (JSR'd anywhere, referenced
from another file, or named in `ddata.s`'s `.WORD` page-routine table).

Independent safety net: a mis-localized cross-routine label **fails to
assemble** (CASM `UNDEFINED LOCAL`/`UNDEFINED SYMBOL`, ca65 cheap-local
scope error) -- it cannot silently produce wrong bytes. Byte-identity vs
the manifest is the final backstop. Both held: every file assembled and
every increment was byte-identical.

DASH has no mid-code `=` equate (all 11 are at the top of `dmain.s`), so
ca65's and CASM's cheap-local scope boundaries coincide throughout --
re-confirmed per file.

### Converted (was -> `@new`)

**`dscr.s`**
- `CLEARSCREEN`: `CLEARLOOP`->`@LOOP`, `CLEARREMLOOP`->`@REMLOOP`
- `SCREENSETCURSOR`: `SSC_INVALID`->`@INVALID`
- `SCREENPUTCHAR`: `SPC_INVALID`->`@INVALID`
- `SCREENPUTSTRING`: `SPS_LENOK`->`@LENOK`, `SPS_LOOP`->`@LOOP`,
  `SPS_TRUNCATED`->`@TRUNCATED`, `SPS_DONE`->`@DONE`
- `HIGHLIGHTTABS`: `HT_LOOP`->`@LOOP`, `HT_COLORSET`->`@COLORSET`,
  `HT_FILL`->`@FILL`, `HT_NEXTTAB`->`@NEXTTAB`, `HT_DONE`->`@DONE`

**`dsys.s`**
- `PRINTDEC16`: `PD16SKIP`->`@SKIP`, `PD16FOUND`->`@FOUND`
- `DSYSRENDER`: `DSYSFAIL`->`@FAIL`
- `DSYSROWVERSION`: `DSYSVERDONE`->`@DONE`
- `DSYSROWVIDEO`: `DSYSVIDNTSC`->`@NTSC`, `DSYSVIDPAL`->`@PAL`,
  `DSYSVIDPRINT`->`@PRINT`
- `DSYSROWVMM`: `DSYSVMMINACTIVE`->`@INACTIVE`, `DSYSVMMPRINT`->`@VMMPRINT`,
  `DSYSREUUNPROBED`->`@UNPROBED`, `DSYSREUPRINT`->`@REUPRINT`
- `DSYSROWPGSIZE`: `DSYSPGSIZENA`->`@NA`
- `DSYSROWPGTOTAL`: `DSYSPGTOTALNA`->`@NA`
- `DSYSROWUSEDFREE`: `DSYSUSEDFREENA`->`@NA`

**`dapp.s`**
- `DAPPRENDER` (scope spans `DAPPRENDER:`..`DAPPHEADER:`, includes the
  physically-separate but jump-only-entered `DAPPQUERYERR`):
  `DAPPLOOP`->`@LOOP`, `DAPPCHECKFAIL`->`@CHECKFAIL`,
  `DAPPNEXTSLOT`->`@NEXTSLOT`, `DAPPLOOPDONE`->`@LOOPDONE`,
  `DAPPDONE`->`@DONE`, `DAPPQUERYERR`->`@QUERYERR`
- `DAPPPRINTNAME`: `DAPPNAMELOOP`->`@LOOP`, `DAPPNAMEPAD`->`@PAD`,
  `DAPPNAMEDONE`->`@DONE`
- `DAPPPRINTRANGE`: `DAPPRANGEBAD`->`@BAD`

**`dvmm.s`**
- `DVMMREFRESHCAP`: `DVMMRC_UNAVAIL`->`@UNAVAIL`, `DVMMRC_DONE`->`@DONE`
- `DVMMRENDERSTATUS`: `DVMMRS_{UNAVAIL,READY,RUNNING,PASSED,FAILED,PRINT}`
  -> `@{UNAVAIL,READY,RUNNING,PASSED,FAILED,PRINT}`
- `DVMMRENDERDETAIL` (scope spans `DVMMRENDERDETAIL:`..`DVMMRUNTEST:`,
  includes fall-through/jump-only `DVMMRD_SHOWFAIL`, `DVMMRD_SHOWOFFSET`,
  `DVMMRD_INSTRUCTION`): `DVMMRD_HASRUN`->`@HASRUN`,
  `DVMMRD_SHOWFAIL`->`@SHOWFAIL`, `DVMMRD_STG{ALLOC,WRITE,READ,COMPARE,
  FREE,PRINT}`->`@STG*`, `DVMMRD_SHOWOFFSET`->`@SHOWOFFSET`,
  `DVMMRD_INSTRUCTION`->`@INSTRUCTION`, `DVMMRD_INSTR{UNAVAIL,RESTART,
  PRINT}`->`@INSTR*`
- `DVMMRUNTEST` (includes jump-only `DVMMRUNTEST_REJECT`):
  `DVMMRT_{CHECKSTATE,CHECKUNAVAIL,PROCEED,ALLOCOK,PATTERNLOOP,BLOCKLOOP,
  WOK,READPHASE,COMPAREPHASE,BLOCKDONE,CLEANUP,DONE,FREEFAIL}`->`@*`,
  `DVMMRUNTEST_REJECT`->`@REJECT`
- `DVMMCHECKBLOCK`: `DVMMCHK_OK`->`@OK`
- `DVMMFILLPATTERN`: `DVMMFP_LOOP`->`@LOOP`
- `DVMMCLEARBUFFER`: `DVMMCB_LOOP`->`@LOOP`
- `DVMMGENBYTE`: `DVMMGB_00`->`@Z00`, `DVMMGB_55AA`->`@Z55AA`,
  `DVMMGB_55`->`@Z55`, `DVMMGB_INCR`->`@INCR` (leading digit not allowed
  after `@`, hence the `Z` prefix)
- `DVMMCOMPAREBLOCK`: `DVMMCMP_LOOP`->`@LOOP`, `DVMMCMP_MISMATCH`->`@MISMATCH`

**`dmain.s`** -- `DISPATCHPAGE` only:
- `PAGEVALID`->`@PAGEVALID`, `DISPATCHRETURNMINUSONE`->`@RETURNMINUSONE`,
  `DISPATCHRETURN`->`@RETURN`. The `#>`/`#<` extraction of `@RETURNMINUSONE`'s
  address (pushed for the RTS trampoline) is handled identically by both
  assemblers -- byte-identity confirms it; no revert needed.

### Deferred by design (explicitly not forgotten)

- `dmain.s` event-loop graph (`EVENTLOOP`/`POLLINPUT`/`SELECT*`/
  `TRYRUNVMMTEST`/`SETREDRAW`/`EXITAPP`) -- WP4 restructures it.
- `dscr.s` `DRAWFRAME` internals (`ROW0LOOP`..`ROW23LOOP`, `DRAWMIDROWS`,
  `CLEARMIDROWLOOP`, `DRAWMIDDONE`) -- WP5 collapses the 7 row loops.
- `dapp.s` `DAPPPRINTFLAGS` internals (`DAPPF{U,R,V,S}_{OFF,PRINT}`) --
  WP5 collapses the 4 flag cells.
- `dfmt.s` -- already fully migrated in Phase 14 WP91.
- `ddata.s` -- all-data; its labels are the cross-file symbol surface.
- `PRINTAT` (`dfmt.s`) -- file-leading entry with no preceding scope, so
  it cannot be a `@local` anyway; possible dead code, flagged for WP5.

## Atomic increments (each ended with the ca65 byte-identity check)

| # | File | `check_casm_source_bytes.py` | ca65 `dash_ref.prg` vs shipping bytes |
| --- | --- | --- | --- |
| 1 | `dscr.s` | OK | byte-identical |
| 2 | `dsys.s` | OK | byte-identical |
| 3 | `dapp.s` | OK | byte-identical |
| 4 | `dvmm.s` | OK | byte-identical |
| 5 | `dmain.s` | OK | byte-identical |

Shipping bytes = `hex_manifest_to_bin.py` transcription of the prior
`dash.ref.hex` (sha256 `3238b786...`).

## Verification -- byte-identical, proven three ways

1. **ca65 `dash_ref`** rebuilt with all 84 `@local` labels: `dash_ref.prg`
   is byte-identical (4766 bytes, sha256 `3238b786...`) to the prior
   shipping manifest.
2. **Native CASM under VICE** (`CASM V0.5.2.1404`, 16MB REU): booted
   Command64 (`image.d64` unit 8), `command64_casm_utils.d64` on unit 9,
   `DRIVE 9`, `CASM DMAIN.S /O:DASH.PRG` -> `P1: DONE 01621 STATEMENTS`,
   `P2: DONE 01621 STATEMENTS`, `DONE: P1 01621, P2 01621, 04766 BYTES`,
   `CASM: INPUT VALIDATED`. `COMP DASH.PRG DASH.REF` -> **`FILES COMPARE
   OK`**.
3. Extracted the native `dash.prg` from the disk (`cc1541 -X`): `cmp`
   byte-identical to both `build/dash_ref.prg` and the prior shipping
   manifest bytes. All three sha256 `3238b786...`.

### Manifest regenerated

`scripts/build_dash_manifest.py <native dash.prg> --cross-check
build/dash_ref.prg` rewrote `src/external/dash/dash.ref.hex`: same 4766
bytes, same sha256 `3238b786...`, `cross-check: MATCHES dash_ref.prg
byte-for-byte`, fresh `source_sha256` for the five changed files
(`dmain.s dscr.s dsys.s dapp.s dvmm.s`); `dfmt.s`/`ddata.s` hashes
unchanged. No `--allow-host-bytes`. The `dash` CMake target then rebuilt
`dash.prg` (sha256 `3238b786...`), which re-validates every source hash
via `hex_manifest_to_bin.py --source-dir`.

## Build evidence

- `dash_ref`, `dash`, `command64_casm_utils_d64`, `image_d64`, and a full
  `cmake --build build` all clean.
- `BUILD_DASH_REF` counter bumped to 1032 (real rebuilds).
- `casm.prg` unchanged (no CASM source touched this WP).

## Overlay events

`test`/`testing` and `test`/`pass` for `dash-mod-wp2` via the
`c64-overlay-api` MCP.

## Runtime note

Per the plan's Completion Gate, runtime is not separately re-verified
here: byte-identical output means the running DASH is bit-for-bit the
shipped one. Runtime re-verification starts at WP4, the first WP that
changes bytes.

## Sign-off

**Approved by the user 2026-09-01.** WP2 closed; Taskwarrior task 51
done. 84 `@local` labels adopted across
`dscr.s`/`dsys.s`/`dapp.s`/`dvmm.s`/`dmain.s`, DASH output byte-identical
under ca65 and native CASM (triple-checked), manifest regenerated with
matching bytes and fresh source hashes, full build green, three label
sets explicitly deferred to WP4/WP5. Next: WP3 (computed constants +
`.ASSERT` invariants) — needs its own detailed sub-plan first.
