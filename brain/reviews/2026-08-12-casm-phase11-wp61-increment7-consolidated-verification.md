# CASM Phase 11 WP61 Increment 7 Consolidated Build and Compatibility Verification

Status: Frozen for user review
Baseline: CASM `0.2.2` build `1266` (unchanged since WP60)
Plan: `brain/plans/2026-08-12-casm-phase11-wp61-determinism-and-boundary-spot-checks.md`
Taskwarrior: `f6845310-bcce-4448-b5f2-0aa19a73723b`

## Scope

Re-verifies everything Increments 2-6 introduced, together and after a full clean/unrestricted rebuild, mirroring WP60 Increment 8's pattern.

## Setup Bug Found and Fixed (build-system only, no production impact)

The first full unrestricted rebuild attempted in this increment failed with `ERROR: Dir track full` building `test_image_d64`. Root cause: Increment 4 added `casmfa2p` to `CASM_REF_NAMES`, which drives a loop that appends every listed reference PRG to `test.d64` (144/144 directory entries, already full since WP60) unless explicitly excluded -- the existing `casmbig1`/`casmopall` exclusions were not extended to cover it. Fixed by adding `casmfa2p` to that exclusion list (matching the `casmopall` precedent: its source also lives only on `casm_opcode_test_d64`, not `test.d64`). This went unnoticed at Increment 4 because no full unrestricted build was run until now -- exactly what this increment exists to catch.

## Build Verification

- Full unrestricted `cmake --build .` (after the fix above): clean, no errors.
- No-change rebuild: `casm` build counter held at `1266` with an identical `BUILD_CASM` hash.
- `test.d64` re-confirmed at exactly 144/144 directory entries, content-identical to the WP60 baseline (no `casmfa2p.ref` present).
- Independently re-derived `casm.prg`'s envelope via `tools/reloc.py` against fresh base/base+1-page links: 18581 code bytes, 2806 relocation points, byte-identical to `build/casm.prg` -- confirms WP61 has made zero production changes through Increment 6.

## Live VICE Matrix (VICE 3.10, clean rebuild)

| Target | Disk | Result |
| --- | --- | --- |
| `test_casm_opcode` | `casm_opcode_test.d64` | `CASM OPCODES: PASS` (197/197) |
| `casmopall.s` vs `casmopall.ref` | `casm_opcode_test.d64` | `CASM: INPUT VALIDATED`; `FILES COMPARE OK` |
| `casmreloc1.s` vs `casmreloc1.ref` | `casm_opcode_test.d64` | `CASM: INPUT VALIDATED`; `FILES COMPARE OK` |
| `casmfa2p.s` vs `casmfa2p.ref` | `casm_opcode_test.d64` | `CASM: INPUT VALIDATED`; `FILES COMPARE OK` |
| `test_casm_lexer` | `casm_listing_test.d64` | `CASM LEXER: PASS` (2/2) |
| `casmsrcmax.s` + `casmsrcbit.s` (reject) | `casm_include_test.d64` | `CASM: SOURCE OFFSET OVERFLOW`, no partial output committed |

All runs returned cleanly to the shell. No dispatch or disk-selection mistakes this increment (both lessons from WP60/earlier WP61 increments were applied correctly throughout).

## Findings

One build-system defect found and fixed (directory-capacity oversight from Increment 4, described above) -- not a production defect, and fixed with an explicit, documented, non-silent change per this project's convention. No production defect found. `casm.prg` remains byte-identical to its WP60 state.

## Disposition

Consolidated build and compatibility verification: **closed**. All Increment 2-6 evidence re-confirmed from a clean rebuild.

Requesting user approval before Increment 8 (audit and walkthrough) activates.
