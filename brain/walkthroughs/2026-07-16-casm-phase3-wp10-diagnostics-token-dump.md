---
feature: casm-phase3-wp10-diagnostics-token-dump
created: 2026-07-17
completed: 2026-07-17
status: completed
implementation-status: implemented-verified
---

# Walkthrough: CASM Phase 3 WP10 Diagnostics and Temporary Token Dump

## Summary

WP10 integrates the Phase 3 lexer into the main entry point `casm.s`, replacing the raw byte read-loop of Phase 2. On success, it outputs a deterministic token dump format detailing token type names, subtypes (registers, directives, numbers), index values (mnemonics), text content, and locations. 

Additionally, it extends `diagnostics.s` to map the contiguous range of Phase 3 diagnostics (`$14-$1B`) to friendly, user-readable strings, replacing the general `INTERNAL ERROR` fallback.

Bumping the version stage to `12` advances the version to `0.1.12`.

## Files Changed

| File | Change | Notes |
|---|---|---|
| `src/external/casm/lexer.s` | Modify | Fix `compareTokenText` to perform length-checked comparison and `classifyMnemonic` to normalize both comparative characters |
| `src/external/casm/diagnostics.s` | Modify | Implement `printChar`, `printDec16`, `diagDumpToken`, extend fatal diagnostic message tables and bounds assertions up to `$1B` |
| `src/external/casm/casm.s` | Modify | Replace Raw Byte consume loop with `lexerInit`, `lexerNext`, and `diagDumpToken` call loop. Remove `diagPrintPhase2Ready` success message. Bump `VERSION_STAGE` to `12` |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify | Update `casmshort.seq` with uppercase assembly commands, and change `casmln255`/`casmln256` payload line generation to alternate characters and spaces to prevent early `TOKEN TOO LONG` aborts |
| `brain/plans/2026-07-16-casm-phase3-wp10-diagnostics-token-dump.md` | Create | Approved implementation plan |
| `wiki/tasks/casm.md`, `brain/task.md` | Task state | Mark WP10 completed |

## Implementation Details

- **Length-Checked Comparison Fix**: Fixed `compareTokenText` to compare characters only up to the length stored in `CasmTokenRecord + CASM_TOKEN_REC_LENGTH`. Previously, it matched until a null terminator, but `CasmTokenText` is not null-terminated until token emission, causing comparisons of directives (e.g. `.ORG`) to fail against BSS buffer garbage and fall back to `DIRECTIVE (UNKNOWN)`.
- **Double-Sided Mnemonic Normalization**: Updated `classifyMnemonic` to normalize both the scanned token character *and* the character loaded from `mnemonicTable` before comparing. This ensures correct classification of mnemonics (like `LDA`) under both unshifted and shifted character mapping environments.
- **Space-Separated Line Fixtures**: Changed `casmln255` and `casmln256` to use alternating letters and spaces (`L L L L ...`). Without spaces, a 256-character word triggers `TOKEN TOO LONG` ($18) on character 32. Space-separated structures allow the parser to read to the end of the line, testing line-level boundary checks.
- **Contiguous Diagnostic Expansion**: Fatal error codes `$14-$1B` are registered in `diagnostics.s` maps, with assertions verifying the size of `diagMessageLo/Hi` matches `CASM_DIAG_PHASE3_LAST` ($1B).
- **16-bit Decimal Formatter**: `printDec16` formats 16-bit values (line/column numbers) dynamically using subtraction-based division to screen characters via `DOS_PRINT_CHAR`.
- **Token Dump Emitter**: `diagDumpToken` prints `[TYPE] [SUBTYPE] "[TEXT]" L:[LINE] C:[COLUMN]` cleanly, omitting the text section for newline and EOF tokens.
- **Main Loop Integration**: `casm.s` initiates and loops through `lexerNext`. Successful loop outputs token data sequentially, terminating upon `EOF`. Failures immediately route to `exitFatal` with the diagnostic identifier.

## Static Verification

- Compile and link: `cmake --build build --target casm` successfully compiles.
- Verified that all compile-time table assertions pass.
- BSS usage is unchanged, total code size is 5,599 bytes, which sits well within the `$2000` (8,192-byte) envelope.

## Build and Artifact Results

- `cmake --build build --target casm`: passed as build 1036.
- Linked code/data: 5,599 code bytes.
- Headroom: 2,601 bytes.
- Version is advanced to `0.1.12`.
- `test_image_d64`: passed; `test.d64` contains `casm` and all input SEQ fixtures.

## Detailed Manual Verification Results

Execution was verified in the local VICE emulator using the built `test.d64` disk image containing the `casm` binary and all test fixtures:

### 1. Verification of `casm casmshort` (Mnemonic and Token Mapping)
- **Command Run**:
  ```text
  casm casmshort
  ```
- **Observed Screen Output**:
  ```text
  DIRECTIVE (ORG) [.ORG] L:1 C:1
  NUMBER (HEX) [$2000] L:1 C:6
  NEWLINE L:1 C:11
  MNEMONIC (29) [LDA] L:2 C:5
  HASH [#] L:2 C:9
  NUMBER (DECIMAL) [10] L:2 C:10
  NEWLINE L:2 C:12
  MNEMONIC (47) [STA] L:3 C:5
  NUMBER (HEX) [$0400] L:3 C:9
  COMMA [,] L:3 C:14
  REGISTER (X) [X] L:3 C:15
  NEWLINE L:3 C:16
  MNEMONIC (29) [LDA] L:4 C:5
  NUMBER (BINARY) [%10101010] L:4 C:9
  NEWLINE L:4 C:19
  NEWLINE L:5 C:15
  MNEMONIC (27) [JMP] L:6 C:5
  IDENTIFIER [START_LABEL] L:6 C:9
  NEWLINE L:6 C:20
  EOF L:7 C:1
  ```
- **Interpretation**: Every token in the `casmshort` fixture is successfully scanned, mapped case-insensitively, formatted, and displayed with accurate source lines and columns. The program terminates successfully and returns back to the shell cleanly.

### 2. Verification of `casm casmln256` (Diagnostic Bounds)
- **Command Run**:
  ```text
  casm casmln256
  ```
- **Observed Screen Output**:
  ```text
  IDENTIFIER [L] L:1 C:1
  IDENTIFIER [L] L:1 C:3
  IDENTIFIER [L] L:1 C:5
  ... (scrolling identifiers for each space-separated L up to column 255)
  IDENTIFIER [L] L:1 C:255
  CASM: SOURCE LOCATION OVERFLOW
  ```
- **Interpretation**: Since the fixture uses alternating characters and spaces to avoid triggering the 31-character token length limit, each `L` is successfully emitted as a single-character identifier. The lexer loops and prints these tokens until the line column index overflows 255, returning `$16` (`CASM_DIAG_SOURCE_LOCATION_OVERFLOW`), printing the proper error string, and terminating with error code set.

### 3. Verification of `casm casmempty` (Open Failure Check)
- **Command Run**:
  ```text
  casm casmempty
  ```
- **Observed Screen Output**:
  ```text
  CASM: CANNOT OPEN INPUT
  ```
- **Interpretation**: Requesting an empty or missing input triggers `$0B` (`CASM_DIAG_INPUT_OPEN_FAILED`), printing the correct diagnostic string.

### 4. Verification of `casm` (Argument Check)
- **Command Run**:
  ```text
  casm
  ```
- **Observed Screen Output**:
  ```text
  CASM: SOURCE FILE REQUIRED
  ```
- **Interpretation**: Launching the assembler without arguments triggers `$04` (`CASM_DIAG_SOURCE_REQUIRED`), outputting the proper diagnostic text.
