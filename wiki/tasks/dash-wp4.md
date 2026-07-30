# DASH WP4 - Relocatable Skeleton Task

## Task Metadata
- **Feature**: `casm-dash-wp4-relocatable-skeleton`
- **Status**: Complete
- **Parent Plan**: `brain/plans/2026-07-26-casm-dash-system-dashboard.md`
- **Plan File**: `brain/plans/2026-07-26-casm-dash-wp4-relocatable-skeleton.md`

## Objectives
1. Establish the seven-file DASH source layout (`dmain.s`, `dscr.s`, `dfmt.s`,
   `dsys.s`, `dapp.s`, `dvmm.s`, `ddata.s`) in the dual-assembler (native CASM
   / ca65) subset documented in `src/external/dash/AGENTS.md`.
2. Implement the page dispatch trampoline and event loop (`dmain.s`) with
   placeholder page renderers.
3. Establish the reviewed hex-manifest artifact provenance
   (`dash.ref.hex` + `scripts/hex_manifest_to_bin.py` /
   `scripts/build_dash_manifest.py`) with the ca65 `dash_ref` target as a
   non-circular independent cross-check.
4. Confirm R6 relocation behavior at multiple load addresses with no REU
   required at runtime.

## Sub-Tasks
- [x] Create the seven-file DASH source layout under `src/external/dash/`.
- [x] Implement `START`/`EVENTLOOP`/`DISPATCHPAGE` dispatch trampoline.
- [x] Wire placeholder per-page renderers via `PAGEROUTINETABLE`.
- [x] Add `dash_wrapper.s` ca65-only wrapper and `dash_ref` CMake target.
- [x] Adopt native CASM `.INCLUDE` (CASM WP47) so source order is specified
      once in `dmain.s` instead of duplicated across the CASM command line
      and `dash_wrapper.s`.
- [x] Establish hex-manifest provenance and unblock
      `scripts/hex_manifest_to_bin.py` on the WP4 placeholder manifest.
- [x] Verify `dash_ref` builds clean and R6 relocation entries exclude fixed
      targets (`$1000`, `$FFE4`, screen/color RAM, ZP `$70`-`$8F`).

## Completion Note (2026-07-30)
Approved complete alongside WP5. See
`brain/plans/2026-07-26-casm-dash-wp5-panel-ui-formatting.md` Completion Note
for the current `dash_ref` build evidence (base `$3400`, 1151 code bytes, 90
relocation points).
