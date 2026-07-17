---
feature: casm-native-assembler
phase: 3
work-package: 10
created: 2026-07-17
status: proposed
implementation-status: proposed
depends-on: casm-phase-3-wp09-mnemonic-classification
approval-required: true
---

# CASM Phase 3 WP10 Plan: Diagnostics and Temporary Token Dump

## Approval Gate

This detailed implementation plan defines the main-application integration, diagnostic expansions, and output formatting for CASM Phase 3 Work Package 10. The user must explicitly approve this plan before task activation or source edits begin. Material changes to the print formatting, error handling, or version numbering require an amended plan and renewed approval.

WP10 completion is separately gated: after implementation and verification, the user must run the supported non-regression matrix, confirm diagnostic print behavior, and explicitly confirm completion before the version advances from `0.1.11` to `0.1.12`.

## Objective

Integrate the lexical analyzer into the primary CASM application loop in `casm.s`, replacing the Phase 2 raw consume-only loop. For successful parses, output a temporary, deterministic token dump detailing token type, subtype names (registers, directives, numbers), decimal index values (mnemonics), text content (if applicable), and file location (line and column numbers). 

Additionally, extend `diagnostics.s` to map Phase 3 diagnostics (errors `$14` through `$1B`) to user-friendly messages, replacing the general `INTERNAL ERROR` fallback.

WP10 does not implement Phase 4 symbol tables or code emission.

## Prerequisites and Inherited Decisions

- WP9 is complete at `0.1.11`, build 1033.
- Table and classification support for identifiers, directives, registers, numbers, and mnemonics is fully implemented and statically verified.
- Target envelope remains `$2000` (8,192 bytes). Headroom is ~3.5KB, which is more than sufficient.

## Sub-Phase Dependency Audit and Resolutions

| Package | WP10 provides | Explicitly deferred |
|---|---|---|
| WP11 closeout | End-to-end runtime token-level validation evidence | Cumulative Phase 3 verification |

### Resolved Discrepancies

1. **Option 1 Success Message**: The parent plan specifies that the token dump replaces the `INPUT VALIDATED` message.
   - *Resolution*: The main entry point in `casm.s` will no longer call `diagPrintPhase2Ready` (which prints `INPUT VALIDATED`) on success. Instead, the loop will print every scanned token (ending with the `EOF` token) and exit successfully.

## Scope

### Included

- Extend `diagnostics.s` to support contiguous Phase 3 diagnostics:
  - `$14` -> `CASM: SOURCE REWIND FAILED`
  - `$15` -> `CASM: SOURCE OFFSET OVERFLOW`
  - `$16` -> `CASM: SOURCE LOCATION OVERFLOW`
  - `$17` -> `CASM: SOURCE LINE TOO LONG`
  - `$18` -> `CASM: TOKEN TOO LONG`
  - `$19` -> `CASM: INVALID SOURCE BYTE`
  - `$1A` -> `CASM: MALFORMED NUMBER`
  - `$1B` -> `CASM: INVALID LEXER STATE`
- Extend compile-time assertions in `diagnostics.s` to check up to `CASM_DIAG_PHASE3_LAST` ($1B).
- Implement a 16-bit decimal printing utility `printDec16` in `diagnostics.s` utilizing subtraction-based division.
- Implement `diagDumpToken` in `diagnostics.s` to format and print `CasmTokenRecord` to the screen using `DOS_PRINT_STR` and `DOS_PRINT_CHAR`.
- Modify `casm.s` to initialize the lexer (`lexerInit`), run the token loop (`lexerNext`), print each token (`diagDumpToken`), terminate successfully on `EOF`, and route failures to `exitFatal`.
- Bump the version stage in `casm.s` to `"12"`, advancing the version to `0.1.12`.

### Excluded

- Phase 4 statement validation or symbol parsing.
- Persistent output file writing.

## Print Formatting & Utility Design

### Diagnostic Message Extension (`diagnostics.s`)
- Check upper bounds in `diagPrintFatal` using `CASM_DIAG_PHASE3_LAST + 1`.
- Append the 8 new error message strings in the `RODATA` segment and reference them in `diagMessageLo/Hi`.

### Decimal Formatter (`printDec16`)
- Inputs: `CasmValue0Lo/Hi` (16-bit value).
- Logic: Sequentially subtract powers of 10 (`10000`, `1000`, `100`, `10`, `1`), printing digit characters (`$30` + digit). Suppress leading zeros using a zero-suppression flag in scratch zero-page `CasmLexerScratch0`.

### Token Dump Format (`diagDumpToken`)
- Format: `[TYPE_NAME] [SUBTYPE_NAME_OR_INDEX] "[TEXT]" L:[LINE] C:[COLUMN]`
- If type has no text (like `NEWLINE` or `EOF`), omit `"[TEXT]"`.
- Subtype names:
  - Directives: `(ORG)`, `(BYTE)`, `(WORD)`, `(INCLUDE)`, `(STATIC)`, `(RELOC)`, `(UNKNOWN)`
  - Registers: `(A)`, `(X)`, `(Y)`
  - Numbers: `(DECIMAL)`, `(HEX)`, `(BINARY)`
  - Mnemonics: `(<index>)` (printed as decimal 0-55)

### Application Loop (`casm.s`)
```assembly
    jsr sourceOpen
    bcs startFatal
    jsr lexerInit
    bcs startFatal
startLexerLoop:
    jsr lexerNext
    bcs startFatal
    jsr diagDumpToken
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_EOF
    bne startLexerLoop
    jsr sourceClose
    bcs startFatal
    jmp exitSuccess
```

## Proposed Changes

### CASM Assembler Component

#### [MODIFY] [lexer.s](src/external/casm/lexer.s)
No modifications to the file itself, but is used by `casm.s`.

#### [MODIFY] [diagnostics.s](src/external/casm/diagnostics.s)
Implement `printDec16`, `printChar` (invoking `DOS_PRINT_CHAR`), and `diagDumpToken`. Extend diagnostic message tables and bounds assertions up to `$1B`.

#### [MODIFY] [casm.s](src/external/casm/casm.s)
Replace the source byte loop with the tokenization loop. Import `lexerInit`, `lexerNext`, and `diagDumpToken`. Bump `VERSION_STAGE` to `12`.

#### [MODIFY] [casm.md](wiki/tasks/casm.md)
Update task records.

#### [MODIFY] [task.md](brain/task.md)
Update task records.

## Verification Plan

### Automated Tests
- Build `cmake --build build --target casm` to verify compilation.
- Verify size remains within the `$2000` envelope.
- Confirm a no-change build does not increment `BUILD_CASM`.

### Manual Verification
- Run VICE with `test.d64`.
- Execute `casm casmshort` and confirm that it prints the banner followed by a list of all tokens with correct types, text, and lines/columns, concluding with `EOF` and exiting back to C64 shell.
- Execute `casm casmln256` and verify it terminates with `CASM: SOURCE LINE TOO LONG` (or correct diagnostic message) instead of an internal error.
