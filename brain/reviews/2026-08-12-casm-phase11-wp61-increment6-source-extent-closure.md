# CASM Phase 11 WP61 Increment 6 Source Extent Closure

Status: Frozen for user review
Plan: `brain/plans/2026-08-12-casm-phase11-wp61-determinism-and-boundary-spot-checks.md`
Taskwarrior: `f6845310-bcce-4448-b5f2-0aa19a73723b`

## Scope

Closes WP60 Increment 9's residual item 2: the source domain's 65,535-byte accepted combined extent (`CASM_SOURCE_VMM_MAX_BYTES`) and 65,536-byte first-reject boundary, never attempted at any prior increment.

## Fixtures

- `casmsrcmax.seq`: exactly 65,535 bytes of valid CASM source (`.ORG $C000\n` = 11 bytes + 16,381 `NOP\n` lines = 65,524 bytes), generated via `string(REPEAT ...)` for an exact byte count.
- `casmsrcbit.seq`: exactly 1 byte (`\n`), reused as a second source file so the combined total reaches exactly 65,536 without needing a second ~259-block fixture.

Both joined `casm_include_test_d64`, which also gained `command64` (making it directly bootable) since it previously carried only `casm`/`comp`.

## Live VICE Results

| Case | Command | Result |
| --- | --- | --- |
| Accept (65,535 combined) | `casm casmsrcmax.s /o:xmax.prg` | `CASM: INPUT VALIDATED`; `xmax.prg` committed (65 blocks) |
| Reject (65,536 combined) | `casm casmsrcmax.s casmsrcbit.s /o:xrej.prg` | `CASM: SOURCE OFFSET OVERFLOW` (`CASM_DIAG_SOURCE_OFFSET_OVERFLOW`, `$15`), no location trailer (matches the `casmmfovf1/2` precedent -- raised during `sourceLoad`'s raw disk-streaming phase, before any lexing); `xrej.prg` correctly absent, no partial commit |

Both runs returned cleanly to the shell. This overflow fires in `sourceLoad`'s combined-cap check (`slCheckCap`, `source.s:369-373`), a different code path from the separately-tracked phantom-EOF-byte defect (which affects later per-byte lexer consumption of an already-loaded exactly-1-byte source) -- confirmed not to interact with or mask that defect.

## Findings

No production defect found. No production source change; only new test fixtures and a `command64` addition to `casm_include_test_d64`. Source-extent boundary: **closed**.

Requesting review before Increment 7 (consolidated build and compatibility verification) activates.
