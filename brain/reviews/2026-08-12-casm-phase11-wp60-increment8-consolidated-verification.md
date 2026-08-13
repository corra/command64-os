# CASM Phase 11 WP60 Increment 8 Consolidated Build and Compatibility Verification

Status: Frozen for user review
Branch: `feature/casm-phase11-wp60`
Baseline: CASM `0.2.1` build `1265` (unchanged since Increment 3)
Plan: `brain/plans/2026-08-11-casm-phase11-wp60-opcode-addressing-boundary-hardening.md`
Taskwarrior: `bd441121-dffa-4d69-8f3a-8572e0643322`

## Scope and Method

This is the Increment 8 gate artifact. It re-verifies, together and after a
full clean build, everything Increments 3-7 introduced or touched: the
production `CLD` hardening, the direct 151-tuple opcode matcher, the
end-to-end `casmopall.s`/`casmopall.ref` artifact, the strengthened
numeric/addressing/branch/PC boundary harnesses, and the strengthened
symbol/relocation/VMM/source boundary harnesses. No production or fixture
source changed while producing this record.

## Build Verification

- `cmake -B build` reconfigured clean.
- Built narrowly first (`casm`, `test_casm_opcodes`, `test_casm_bounds`,
  `test_casm_expr`, `test_casm_reloc`, `test_casm_symbols`, `test_casm_vmm`,
  `test_casm_spanread`, `casm_opcode_test_d64`, `casm_listing_test_d64`,
  `casm_overflow_test_d64`), then `image_d64`/`test_image_d64`, then a full
  unrestricted `cmake --build .` with no target filter. No target failed; no
  `error`/`fail` text in any build log.
- No-change rebuild: re-running `cmake --build . --target casm` left
  `src/external/casm/BUILD_CASM` at `1265` with an identical SHA-256 hash --
  confirms the build system is idempotent for an unmodified tree.

## Production Envelope (casm)

- Built `out_casm/casm_base.prg` and `out_casm/casm_next.prg` (the two
  base/base+1-page links CMake already produces for `tools/reloc.py`) and ran
  `reloc.py` on them independently: **18581 code bytes, 2806 relocation
  points**, base `$3800`. Byte-for-byte identical to `build/casm.prg`
  (`cmp` exit 0).
- This exactly matches Increment 3's measured post-`CLD` envelope
  (`18580 -> 18581` code bytes, relocations unchanged at `2806`). Increments
  4-7 are test-only and did not move `casm.s` again -- confirmed by the
  unchanged build counter (`1265`) and identical hash.

## Artifact and Disk Inspection

| Disk | Directory entries | Blocks free | Notes |
| --- | --- | --- | --- |
| `image.d64` | n/a (PRG-only image) | 334 | unchanged from the `0.2.1` baseline recorded at Increment 3 |
| `test.d64` | 144/144 (full) | 36 | directory-track-full, pre-existing condition; not touched by WP60 |
| `casm_overflow_test.d64` | 19 | 7 | pre-existing condition; not touched by WP60 |
| `casm_listing_test.d64` | 45 | 38 | carries Increment 4/6/7 harnesses (`test_casm_opcode`, `test_casm_bounds`, `test_casm_spanre`) |
| `casm_opcode_test.d64` | 7 (+ smoke-test artifacts below) | 491 | dedicated Increment 5 disk, ample headroom |

No disk exceeded its 1541 capacity; the full build produced no directory- or
block-overflow error on any target.

## Live VICE Matrix (VICE 3.10, embedded MCP)

All runs booted Command64 from the disk under test, dispatched the harness by
typing its real 16-char-truncated disk name, and confirmed both the PASS
banner and a clean return to the `C64[<device>]:>` shell prompt per the
mandatory testing workflow.

| Harness / step | Disk | Result |
| --- | --- | --- |
| `test_casm_opcode` (Increment 4, 197 cases) | `casm_opcode_test.d64` | `CASM OPCODES: PASS`, clean return |
| `casm casmopall.s /o:casmopa.prg` + `comp casmopa.prg casmopall.ref` (Increment 5, 151/151) | `casm_opcode_test.d64` | `CASM: INPUT VALIDATED`; `FILES COMPARE OK` -- byte-identical |
| `test_casm_bounds` (Increment 6) | `casm_listing_test.d64` | `CASM BOUNDS: PASS`, clean return |
| `test_casm_spanre` (Increment 7, source domain) | `casm_listing_test.d64` | `CASM SPANREAD: PASS`, clean return |
| `test_casm_symbol` (Increment 7, symbol domain) | `test.d64` | `CASM SYMBOLS: PASS`, clean return |
| `test_casm_reloc` (Increment 7, relocation domain) | `test.d64` | `CASM RELOC: PASS`, clean return |
| `test_casm_vmm` (Increment 7, VMM domain) | `test.d64` | `CASM VMM: PASS`, clean return |
| Production `/M /L` smoke (`casm casmopall.s /o:casmoml.prg /m /l`) | `casm_opcode_test.d64` | `SYMBOL MAP` (8 branch-target symbols) printed, `CASM: INPUT VALIDATED`; `casmoml.prg` (2 blocks) and `casmoml.lst` (33 blocks) both committed to disk |

Two harness-side (not product) issues surfaced and were resolved without
touching production or fixture sources:

1. **Dispatch typos, not defects.** Several first attempts at a harness name
   used the untruncated 18-char name or a keyboard call that sent literal
   ASCII `_` (`$5F`, PETSCII left-arrow) instead of the real underscore byte
   (`$A4`) via `vice_keyboard_petscii`. Both produced `Bad command or file
   name` against the real, correctly-named disk entries -- confirmed by
   `vice_disk_list` and by every harness passing once dispatched correctly.
   No disk, catalog, or shell defect.
2. **Disk-selection mistake on the first `/M /L` smoke attempt.** Targeting
   `test.d64` (directory-track-full, a pre-existing condition documented in
   `.agents/workflows/vice-mcp-testing.md`) correctly produced
   `CASM: OUTPUT WRITE FAILED` / `Drive 8 status: 72, DISK FULL` from
   `fileCreateOutput`. Retried on `casm_opcode_test.d64` (491 blocks free)
   and passed cleanly. This is CASM correctly reporting a real IEC/DOS
   condition, not a defect -- recorded here rather than silently discarded
   because it is a real product diagnostic exercised live.

## Findings

No production defect found. No production, fixture, or CMake change made in
this increment. `casm.s`'s `CLD` hardening (Increment 3) and every test
module and fixture added in Increments 4-7 remain mutually consistent after a
full clean rebuild and a live re-run of the entire changed/affected set.

## Outstanding

Per the plan, Increment 9 (audit and walkthrough, record synchronization) and
Increment 10 (version bump to `0.2.2` and final no-change proof) remain
separately gated and are not authorized by this record.

## Approval Requested

Confirm Increment 8 is accepted so Increment 9 (audit/walkthrough and record
synchronization) can begin.
