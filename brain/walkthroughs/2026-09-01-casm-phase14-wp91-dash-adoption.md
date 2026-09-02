# Walkthrough: CASM Phase 14 WP91 - DASH @local Adoption

Plan: `brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md`
Taskwarrior: WP91 `af6a65ad-3d1a-42d4-9b1d-d0b26cc26c2a`
Branch: `feature/casm-phase14`

## What this WP delivers

### `dfmt.s` -- 5 global labels -> 3 routines' `@local` labels

DASH's `dfmt.s` had textbook routine-scoped helper labels. Migrated:

| routine | was | now |
| --- | --- | --- |
| `FORMATDEC16` | `FD16LOOP`, `FD16DONE` | `@LOOP`, `@DONE` |
| `PETTOSCREEN` | `PTSDONE` | `@DONE` |
| `DIV10` | `DIV10LOOP`, `DIV10SKIP` | `@LOOP`, `@SKIP` |

All five were verified referenced only within their own routine (`grep`).
`@LOOP`/`@DONE`/`@SKIP` are reused across the three routines -- three
distinct scopes (`PETTOSCREEN` sits between the other two), which both
ca65 (native cheap locals) and CASM (WP89 `@local`) treat as separate.

### `src/external/dash/AGENTS.md` -- new "Dual-Assembler Subset" clause

Added a bullet under "Work Guidance" -> "Dual-Assembler Subset":
`@local` labels are shared between ca65 and CASM; anonymous `:+`/`:-` are
not (deferred past Phase 14). It spells out the two constraints that keep
the assemblers in agreement:
- no `=` equate may sit between a label and its `@locals` (ca65 ends a
  cheap-local scope at any non-`@` symbol including an `=`; CASM only at a
  `NAME:` label -- DASH's "equates before code" rule already makes these
  coincide, but a new mid-code equate would split silently differently);
- never reuse one `@name` within a single CASM scope (CASM rejects
  `DUPLICATE LOCAL LABEL IN SCOPE`; ca65, whose scope may have been split
  by an `=`, might not).

## Verification -- zero byte change, proven three ways

1. **ca65 `dash_ref`** rebuilt with the `@local` labels: `dash_ref.prg`
   is **byte-identical** (4766 bytes, sha256 `3238b786...`) to the prior
   shipping `dash.ref.hex` manifest -- `cmp` against
   `hex_manifest_to_bin.py`'s transcription of the old manifest.
2. **Native CASM under VICE** (`CASM V0.5.2.1403`, 16MB REU): booted
   Command64 (image.d64 unit 8), `command64_casm_utils.d64` on unit 9,
   `DRIVE 9`, `CASM DMAIN.S /O:DASH.PRG` -> `DONE: P1 1621, P2 1621,
   04766 BYTES`, `CASM: INPUT VALIDATED`. `COMP DASH.PRG DASH.REF` ->
   **`FILES COMPARE OK`**.
3. Extracted the native `dash.prg` from the disk (`cc1541 -X`):
   `cmp` -> byte-identical to both `build/dash_ref.prg` (the independent
   ca65 cross-check) and the prior shipping manifest bytes.

### Manifest regenerated

`scripts/build_dash_manifest.py <native dash.prg> --cross-check
build/dash_ref.prg` rewrote `src/external/dash/dash.ref.hex`: same 4766
bytes, same sha256, `cross-check: MATCHES dash_ref.prg byte-for-byte`,
fresh `source_sha256` for all 7 files (only `dfmt.s`'s content actually
changed). The `dash` CMake target then built clean --
`hex_manifest_to_bin.py --source-dir` re-validated every source hash.
No `--allow-host-bytes` override.

## Folded-in WP89 build fix

The full-tree build surfaced a WP89 gap: `test_casm_include` links
`parser.s` but stubs the expression evaluator, and WP89's new
`parser.s` `.import CasmExprPrimaryWasLocal` (an `expr.s` export) was
unresolved there. WP89's own build runs never rebuilt that harness.
Added a one-byte BSS stub + export in `tests/src/casm_include/casm_include.s`
(the flag is never read on the stubbed `exprEvaluate` path). Full
`cmake --build build` now clean.

## Build evidence

- `dash_ref`, `dash`, `command64_casm_utils_d64`, `image_d64`,
  `test_image_d64`, and a full `cmake --build build` all clean.
- `casm.prg` unchanged (no CASM source touched this WP).
- Many `tests/src/*/BUILD_TEST_CASM_*` counters bumped -- the full build
  re-linked harnesses whose `common.inc` content-hash moved across
  WP86-90; the counters just record real rebuilds.

## Overlay events

`test`/`testing` + `test`/`pass` for `dash-wp91`, via curl (MCP still
down).

## Sign-off requested

WP91 is source-complete and verified: `@local` labels adopted in
`dfmt.s`, DASH output byte-identical under both ca65 and native CASM
(triple-checked), manifest regenerated with matching bytes, AGENTS.md
clause added, full build green. Requesting approval to close WP91 and
proceed to WP92 (consolidated completion gate: fresh re-run of every
`test_casm_*` harness + all Phase 14 fixtures + no-locals regression,
docs, CASM `0.6.0`, walkthrough).
