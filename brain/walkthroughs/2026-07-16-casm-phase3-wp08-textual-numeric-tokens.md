---
feature: casm-phase3-wp08-textual-numeric-tokens
created: 2026-07-17
completed: 2026-07-17
status: completed
implementation-status: implemented-verified
---

# Walkthrough: CASM Phase 3 WP8 Textual and Numeric Tokens

## Summary

WP8 extends `lexer.s` to implement scanning and validation of identifiers, dot-prefixed directives, case-insensitive register classification, and three numeric lexical forms (decimal, hexadecimal, and binary). It enforces the 31-character token text limit (`CASM_TOKEN_TEXT_MAX`) and validates lexical shapes (rejecting bare prefixes, invalid suffixes, and overlong tokens).

Per the approved plan, this is **Option 1 (static-only)**: the shipped entry-point behavior remains a non-regression path (verified with standard source files), and token-level observation becomes fully wired in WP10. Bumping the version stage to `10` advances the version to `0.1.10`.

## Files Changed

| File | Change | Notes |
|---|---|---|
| `src/external/casm/lexer.s` | Modify | Implement character checks, scanners, string comparison, case-insensitive register/directive classification, and malformed suffix skips |
| `src/external/casm/casm.s` | Modify | Bump `VERSION_STAGE` macro to `10` |
| `brain/plans/2026-07-16-casm-phase3-wp08-textual-numeric-tokens.md` | Create | Approved implementation plan |
| `wiki/tasks/casm.md`, `brain/task.md` | Task state | Mark WP8 completed |

## Scanner Model (as implemented)

- **Character Classification**: Added private check helpers `isIdFirst`, `isIdCont`, `isHexDigit`, `isBinDigit`, `isDecDigit`, and `normalizeChar`.
- **String Comparison**: Added case-insensitive `compareTokenText` helper matching against RODATA directive strings (`.ORG`, `.BYTE`, `.WORD`, `.INCLUDE`, `.STATIC`, `.RELOC`).
- **Identifier Scanner**: Scans starting letters/underscore and continues. Single-character identifiers are case-insensitively compared against `A`, `X`, `Y` to emit `CASM_TOKEN_REGISTER` with appropriate subtype.
- **Directive Scanner**: Scans dot-prefixed names and maps them to `CASM_TOKEN_DIRECTIVE` and subtype (`CASM_DIRECTIVE_*` or `CASM_DIRECTIVE_UNKNOWN`).
- **Hex/Binary/Decimal Scanners**: Validates prefixes (`$`, `%`) and digits. Any following continuation character (invalid suffix like `$12G` or `%102`) skips the remainder of the word and fails with `CASM_DIAG_MALFORMED_NUMBER`.
- **Bounds/Overlong Safeguard**: Exceeding 31 characters returns `CASM_DIAG_TOKEN_TOO_LONG`.
- **Long-Branch Safety**: Fixed relative branch range errors by inverting branch conditions and using explicit jumps (`jmp`) to targets like `lnFail` and `lnTokenTooLong`.

## Static Verification

- Compile and link: `cmake --build build --target casm` successfully compiles without warnings or errors.
- Verified that local symbols `CASM_PETSCII_DOLLAR`, `CASM_PETSCII_UPPER_X`, and `CASM_PETSCII_UPPER_Y` are correctly defined and do not conflict.
- Verified character checking logic behaves correctly on shifted vs unshifted letters, digits, and underscores.
- Verified case-insensitivity maps shifted letters to unshifted counterparts safely.
- Verified skip-loops for malformed numbers advance past invalid suffix/prefix tokens without polluting valid boundaries.

## Build and Artifact Results

- `cmake --build build --target casm`: passed as build 1032.
- No-change CASM rebuild preserved the build number.
- Linked code/data: 4,360 code bytes, within the `$2000` (8,192 bytes) MAIN envelope.
- Headroom remains 3,832 bytes of combined memory space.
- Relocation points: 596.
- Version is advanced to `0.1.10` and prints correctly in the startup banner.
- `image_d64`: passed; `casm` present on `build/image.d64`.

## Verification Boundary

The lexer has no caller on the entry-point path yet. End-to-end token output will become fully observable in WP10.

## User Runtime Matrix

Confirming non-regression of the shipped path:
- [x] Standard fixtures (`casmshort`, `casm256`, `casmmulti`) still build and verify.
- [x] Launching CASM prints `CASM V0.1.10.1032` banner.
- [x] Program exits cleanly back to shell.
