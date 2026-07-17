---
feature: casm-phase3-wp02-debug-reuse-feasibility
completed: 2026-07-16
status: completed
---

# Walkthrough: CASM Phase 3 WP2 DEBUG Reuse Feasibility

## Summary

Independently audited DEBUG's interactive assembler routines and metadata.
All 56 documented NMOS 6502 mnemonics and all table bounds were accounted for.
The user approved Strategy A: WP9 will implement a CASM-local 168-byte mnemonic
table using DEBUG's verified ordering only as reference knowledge.

## Decision

- No DEBUG routine, runtime state, include, or build input is reused.
- CASM omits DEBUG's `???` sentinel and uses explicit PETSCII bytes.
- Opcode, addressing-mode, promotion, branch, and emission decisions remain
  deferred to Phase 4.
- CASM advances from `0.1.3` to `0.1.4` after WP2 approval.

## Verification

- 56/56 mnemonics matched the independent repository reference.
- The branch set contains exactly eight expected conditional branches.
- DEBUG table cardinalities are 171, 256, 256, and 14 bytes.
- 151 documented and 105 invalid opcode slots are internally consistent.
- No DEBUG defect or WP2 stop condition was found.
- Full evidence is recorded in
  `brain/reviews/2026-07-16-casm-debug-assembler-reuse.md`.
- `cmake --build build --target casm` produced build 1016 with 2,256 linked
  code/data bytes and 241 relocation points.
- The 2,746-byte artifact begins at `$3400` and ends with R6 footer
  `00 34 F1 00 52 36`.
- A no-change rebuild preserved `BUILD_CASM` 1016.

## Manual Confirmation

Review the executive decision, mnemonic table, routine matrix, strategy costs,
and Phase 4 deferrals in the WP2 review. Confirm that Strategy A is approved
and that WP3 remains gated by a dedicated implementation plan.

The user approved Strategy A and WP2 completion on 2026-07-16.
