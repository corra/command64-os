# CASM Phase 11 WP61 Increment 4 FORCE_ABS Two-Pass Closure

Status: Frozen for user review
Plan: `brain/plans/2026-08-12-casm-phase11-wp61-determinism-and-boundary-spot-checks.md`
Taskwarrior: `f6845310-bcce-4448-b5f2-0aa19a73723b`

## Scope

Closes WP60 Increment 9's residual item 1: prove `FORCE_ABS` (`CASM_PARSER_STMT_FORCE_ABS`, `parser.s:562-575`) holds across a genuine two-pass real assembly for a **forward**-referenced symbol resolving into the zero-page range, complementing the existing `p1back1` single-pass/backward-reference unit evidence.

## Fixture

New `casmfa2p.s` (`.ORG $0010` / `LDA TARGET` / `TARGET: NOP`), generated via `cmake/GenerateCasmTestFixtures.cmake`, with an independently hand-authored `tests/fixtures/casm/casmfa2p.ref.hex` (not derived from CASM). Joined `casm_opcode_test_d64` (487→486 blocks free).

## Live VICE Results

- `casm casmfa2p.s /o:fa1.prg` → `CASM: INPUT VALIDATED`
- `comp fa1.prg casmfa2p.ref` → `FILES COMPARE OK`
- `casm casmfa2p.s /o:fa2.prg` → `CASM: INPUT VALIDATED`
- `comp fa1.prg fa2.prg` (self-compare) → `FILES COMPARE OK`

## Findings

`LDA TARGET` emitted as 3-byte absolute (`AD 13 00`), not 2-byte zero-page, matching the hand-derived reference exactly, and identically across two independent live runs. No production defect; no production source change. FORCE_ABS two-pass stability: **closed**.

Requesting review before Increment 5 (symbol/token name-length-32 closure) activates.
