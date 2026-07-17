---
feature: casm-phase3-wp09-mnemonic-classification
created: 2026-07-17
completed: 2026-07-17
status: completed
implementation-status: implemented-verified
---

# Walkthrough: CASM Phase 3 WP9 Mnemonic Classification

## Summary

WP9 implements case-insensitive 6502 mnemonic classification (Strategy A from WP2) in `lexer.s`. Scanned identifiers of length 3 are compared against a local compact table of 56 three-byte entries (168 bytes of RODATA). Matches are transformed into `CASM_TOKEN_MNEMONIC` tokens with the corresponding subtype index (0-55). Unmatched identifiers remain `CASM_TOKEN_IDENTIFIER`.

Per the approved plan, this is **Option 1 (static-only)**: the shipped entry-point behavior remains a non-regression path (verified with standard source files), and token-level observation becomes fully wired in WP10. Bumping the version stage to `11` advances the version to `0.1.11`.

## Files Changed

| File | Change | Notes |
|---|---|---|
| `src/external/casm/lexer.s` | Modify | Define `mnemonicTable`, add 168-byte `.assert` check, implement `classifyMnemonic` routine, and call it under the `lnId` path |
| `src/external/casm/casm.s` | Modify | Bump `VERSION_STAGE` macro to `11` |
| `brain/plans/2026-07-16-casm-phase3-wp09-mnemonic-classification.md` | Create | Approved implementation plan |
| `wiki/tasks/casm.md`, `brain/task.md` | Task state | Mark WP9 completed |

## Mnemonic Table & Lookup (as implemented)

- **Mnemonic Table**: Emitted in `lexer.s` RODATA with exactly 56 entries * 3 bytes = 168 bytes. An `.assert` segment-difference check guarantees the exact size of 168 bytes.
- **Search Optimization**: Skips linear search immediately if `length != 3`.
- **Search Routine**: `classifyMnemonic` loads the base address in `CasmPtr0Lo/Hi` and loops `X` from 0 to 55 comparing `CasmTokenText[0..2]` against each table entry case-insensitively using `normalizeChar`.
- **Emitter Integration**: If a match occurs, the identifier is emitted as `CASM_TOKEN_MNEMONIC` with its subtype set to the matching table index (0-55).

## Static Verification

- Compile and link: `cmake --build build --target casm` successfully compiles without warnings or errors.
- Verified that compile-time segment check `.assert MnemonicTableSize = 168` passes.
- Verified that all zero-page variables are transiently used and segment-safety is maintained.

## Build and Artifact Results

- `cmake --build build --target casm`: passed as build 1033.
- No-change CASM rebuild preserved the build number.
- Linked code/data: 4,613 code bytes, within the `$2000` (8,192 bytes) MAIN envelope.
- Headroom remains 3,579 bytes of combined memory space.
- Relocation points: 606.
- Version is advanced to `0.1.11` and prints correctly in the startup banner.
- `image_d64`: passed; `casm` present on `build/image.d64`.

## Verification Boundary

The lexer has no caller on the entry-point path yet. Mnemonic token output will become fully observable in WP10.

## User Runtime Matrix

Confirming non-regression of the shipped path:
- [x] Standard fixtures (`casmshort`, `casm256`, `casmmulti`) still build and verify.
- [x] Launching CASM prints `CASM V0.1.11.1033` banner.
- [x] Program exits cleanly back to shell.
