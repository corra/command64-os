# DASH WP6 - System Page Task

## Task Metadata
- **Feature**: `casm-dash-wp6-system-page`
- **Status**: Complete
- **Parent Plan**: `brain/plans/2026-07-26-casm-dash-system-dashboard.md`
- **Plan File**: `brain/plans/2026-07-26-casm-dash-wp6-system-page.md`

## Objectives
1. Query `DOS_GET_SYSTEM_INFO` ($5C) exactly once per System-page redraw and
   render OS version, device, video standard, user/protected ranges, VMM
   availability/capacity/page counts, and application counts.
2. Fix the kernel-side hardcoded version literals (Task Warrior #41) as part
   of this WP, per the user's 2026-07-30 scoping decision, rather than as a
   separate change.
3. Never read private OS memory directly; capability-gate every optional
   (VMM-dependent) field; never display unavailable data as zero.

## Sub-Tasks
- [x] WP1 amendment: bump `StructVersion` to `$02`, reinterpret offset 22
      (`Reserved0`) as `OsPatch` (`brain/plans/2026-07-26-casm-dash-wp1-api-contract-freeze.md` section 7).
- [x] CMake: parse `VERSION` (`MAJOR.MINOR.PATCH[-dev]`) into
      `OsVersionMajor`/`Minor`/`Patch`/`Stage`, generated into both the Kick
      `build_config.inc` and a new ca65 `build_config_ca65/build_config.inc`.
- [x] `ahGetSystemInfo` (`api.asm`): emit live `OsMajor`/`OsMinor`/`OsPatch`/
      `OsStage` and `StructVersion = 2` instead of hardcoded immediates.
- [x] `include/command64.inc` / `include/ca65/command64.inc`: add
      `SYS_INFO_STRUCT_VER`, rename `SYS_INFO_OFF_RES0` to
      `SYS_INFO_OFF_OS_PAT`.
- [x] `tests/src/api/api.s`: assert `StructVersion == 2` and
      `OsMajor`/`OsMinor`/`OsPatch`/`OsStage` against the generated
      constants (tracks `VERSION` automatically instead of a stale literal).
- [x] `wiki/api-reference.md` / `docs/api-reference.md`: updated and
      re-synced byte-identical.
- [x] `dsys.s`: `querySystemInfo` wrapper (C clear/set per WP6 contract),
      `StructVersion`/`StructSize` validation before reading any field,
      10-row render (version, device, video, user range, protected range,
      VMM/REU, page size, page total, used/free, applications) using WP5's
      bounded `screenSetCursor`/`screenPutString`/`screenPutChar` -- not the
      old unbounded `PRINTAT`.
- [x] `ddata.s`: `SYSINFOBUF` (24-byte record) and all System-page label
      strings; removed the dead WP4-era `SYSLABEL1`/`SYSLABEL2` placeholders.
- [x] Fixed a real bug found during live verification: `FORMATDEC16`
      (`dfmt.s`) called `DIV10` (which clobbers X) while X held the digit
      write-index, corrupting every multi-digit render. See the plan file's
      Completion Note for the full root-cause writeup.
- [x] Added `DASHVERSTR` version banner on screen row 24, matching other
      external apps' `"APPNAME V<major>.<minor>.<stage/build>"` convention.
- [x] Build evidence: `command64`, `test_api`, `test_vmm`, `image_d64`,
      `test_image_d64`, and `dash_ref` (ca65 cross-check) all build clean.
- [x] Regenerated `dash.ref.hex` via native CASM; `COMP DASH.PRG DASH.REF`
      byte-matches `dash_ref.prg`. Live-verified on real hardware/VICE at
      `$3800` via COMMAND64's own `load`/`run` shell commands (device 9).
- [x] Task Warrior #41 closed.
- [x] Task Warrior #42 logged for deferred kernel-side inconsistencies found
      during live verification (not WP6's to fix -- see below).
- [x] User approved WP6 complete (2026-07-30), with the items below
      explicitly deferred rather than blocking closure.

## Deferred to a future point-fix WP (Task Warrior #42)

Not WP6 bugs -- DASH's System page accurately reports exactly what `$5C`
returns; these are kernel `apptable.asm`/`vmm.asm` behaviors that may need OS
changes:

- `VmmTotalPages`/`VmmPageSize` are hardcoded to a 16MB-REU assumption, not
  computed from the actually attached REU (`VmmFlags` bit 1 "REU probed" is
  defined but never set).
- `DOS_EXIT` doesn't clear `APT_FLAG_USED`/`APT_FLAG_RUNNING` or free the
  exiting program's VMM allocations; the manual `FREE` shell command left
  `APPLICATIONS` unchanged in a user-verified repro even though it partially
  reclaimed VMM pages -- possibly a bug in `aptRemoveAll` itself.

## Not independently re-verified in this pass

The full `$3800`/`$5000`/`$9000` load-address matrix from this plan's
original Completion Gate -- only `$3800` was exercised in this session.
