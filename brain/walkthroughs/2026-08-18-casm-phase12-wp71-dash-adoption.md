---
feature: casm-phase12-wp71-dash-adoption
completed: 2026-08-18
status: completed
---

# Walkthrough: CASM Phase 12 WP71 DASH Adoption

## Summary

DASH adopted Phase 12 named constants for its documented private zero-page
registers without changing runtime bytes. Two CASM defects discovered by this
dogfooding work were resolved separately in WP72/WP73. Native CASM now rebuilds
DASH byte-identically to ca65, and the shipping manifest has genuine native
provenance.

## Native Provenance

- Image: `build/command64_casm_utils.d64`, 222 free blocks before assembly.
- Environment: VICE 3.10, 16MB REU, Command64 on unit 8, utility disk unit 9.
- Assembler: CASM `0.2.6.1318`.
- Exact PETSCII command: `CASM DMAIN.S /O:@:DASH.PRG`.
- Native result: 19-block `dash.prg`, normal `c64[9]:>` return.
- Exact PETSCII `COMP DASH.PRG DASH.REF`: `FILES COMPARE OK`.
- Extracted artifact: 4,766 bytes, load `$3400`, SHA-256
  `3238b7863cc9b7ba7b07202c94dccb8dcbd1fd0fe4c578362f311b79757b814b`.
- `build_dash_manifest.py --cross-check build/dash_ref.prg`: all 4,766 bytes
  match; no `--allow-host-bytes`; seven source hashes recorded.

## Build Evidence

- `dash`, `dash_ref`, `command64_casm_utils_d64`, and `image_d64`: pass.
- Production image: DASH 19 blocks, 317 blocks free after source append.
- Immediate no-change `image_d64` rebuild preserved:
  - `image.d64`: `50c0686c714a8c225b65d09b3534a2923ab6d2158213c407eca74fcb84fa2c6e`
  - `dash.prg`: `3238b7863cc9b7ba7b07202c94dccb8dcbd1fd0fe4c578362f311b79757b814b`
  - `BUILD_DASH_REF` and `BUILD_CASM`: unchanged hashes.

## Relocation Evidence

- `$3800`: default `LOAD DASH` / `RUN` rendered the System page correctly.
- `$5000`: `LOAD DASH 5000` / `RUN 5000` rendered correctly; F3 Applications
  page reported DASH range `5000-5ef3`.
- `$9000`: fresh `LOAD DASH 9000` / `RUN 9000` rendered correctly; F3 reported
  `9000-9ef3`.
- VICE was restored to a healthy production `c64[8]:>` shell and left running.

## Disclosed Documentation Finding

The manuals claimed `GO <address>` performed explicit relocation. Live
`GO 5000` returned `BAD COMMAND OR FILE NAME`; source confirms the supported
workflow is explicit `LOAD DASH <address>` followed by `RUN <address>`. The
byte-identical `wiki/docs/dash-utility.md` pair is corrected accordingly.

## Completion Gate

The user approved this completion gate on 2026-08-18. WP71 is complete, CASM
is promoted from `0.2.6` to `0.2.7`, and WP74 is unblocked.
