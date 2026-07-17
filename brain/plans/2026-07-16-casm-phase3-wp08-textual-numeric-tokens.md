---
feature: casm-native-assembler
phase: 3
work-package: 8
created: 2026-07-17
status: proposed
implementation-status: proposed
depends-on: casm-phase-3-wp07-minimal-lexer-core
approval-required: true
---

# CASM Phase 3 WP8 Plan: Textual and Numeric Tokens

## Approval Gate

This detailed implementation plan defines the scanning rules, internal routines, diagnostics, and acceptance criteria for CASM Phase 3 Work Package 8. The user must explicitly approve this plan before task activation or source edits begin. Material changes to token types, scanner logic, diagnostic mapping, or target envelope require an amended plan and renewed approval.

WP8 completion is separately gated: after implementation and static verification, the user must run the supported non-regression matrix, inspect linked sizes, and explicitly confirm completion before the version advances from `0.1.9` to `0.1.10`.

## Objective

Extend `lexer.s` to implement scanning and validation of identifiers, dot-prefixed directives, case-insensitive register classification, and three numeric lexical forms (decimal, hexadecimal, and binary). Enforce bounds checks (maximum 31 payload bytes) and lexical structure (reject bare prefixes, invalid suffixes, and overlong tokens).

WP8 does not implement statement parsing (Phase 4), evaluate numeric values/expressions (Phase 4/5), or classify mnemonics (WP9). It does not wire the token dump into the entry point (WP10).

## Prerequisites and Inherited Decisions

- WP7 is complete at `0.1.9`, build 1028. The minimal lexer core, lookahead, and punctuation token emission are complete.
- CASM version component system was migrated to generalized multi-digit string macros in commit `5eab286242fea46d1bcb31d8b45cd219f2252063`, so completing WP8 will advance CASM cleanly to `0.1.10`.
- BSS allocation in `state.s` is frozen. No new BSS variables are added.
- The linked target envelope is `$2000` (8,192 bytes). Current code is well within the boundary, leaving ample headroom.

## Sub-Phase Dependency Audit and Resolutions

| Package | WP8 provides | Explicitly deferred |
|---|---|---|
| WP9 mnemonic classification | Scanned identifiers ready for mnemonic matching | Mnemonic table and case-insensitive matching |
| WP10 diagnostics/token dump | Identifiers, directives, registers, and numbers ready for output formatting | Token-dump driver and diagnostic text formatting |
| WP11 closeout | Textual and numeric token scanning static evidence | Cumulative Phase 3 verification |

### Resolved Discrepancies

1. **Acceptance Envelope Discrepancy**: The Phase 3 parent plan and the acceptance checklist in `wiki/tasks/casm.md` still mention the `$1000` MAIN envelope on line 174, but WP6 raised the envelope to `$2000`.
   - *Resolution*: This plan updates the acceptance check to `$2000` in `wiki/tasks/casm.md` and explicitly notes the correction.
2. **Observability Boundary**: Like WP7, WP8 has no direct runtime driver until WP10.
   - *Resolution*: Option 1 (static-only) remains the path. Non-regression is verified by assembling, linking, and checking that the existing byte-stream loop runs successfully. Token-level behavior is verified statically by code audit and tracing.

## Scope

### Included

- Scan identifiers starting with `A-Z`, `a-z`, or `_` (and PETSCII shifted equivalents) followed by letters, digits `0-9`, or `_`.
- Scan dot-prefixed directives.
- Compare directive strings case-insensitively and map them to `CASM_DIRECTIVE_*` subtypes (`.org`, `.byte`, `.word`, `.include`, `.static`, `.reloc`), defaulting to `CASM_DIRECTIVE_UNKNOWN`.
- Classify single-letter identifiers matching `A`, `X`, or `Y` case-insensitively as `CASM_TOKEN_REGISTER`.
- Scan decimal numbers (digits `0-9`).
- Scan hexadecimal numbers (prefix `$`, followed by hex digits `0-9`, `A-F`, `a-f`, and shifted equivalents).
- Scan binary numbers (prefix `%`, followed by binary digits `0` or `1`).
- Enforce the 31-character token text capacity (`CASM_TOKEN_TEXT_MAX`). Exceeding this returns `CASM_DIAG_TOKEN_TOO_LONG` (`$18`).
- Reject malformed numbers (bare `$` or `%`, or invalid suffixes like `$12G` or `%102`) returning `CASM_DIAG_MALFORMED_NUMBER` (`$1A`).
- Skip trailing identifier continuation characters on numeric error to align the stream to the next word boundary.
- Build, artifact, and memory verification.

### Excluded

- Mnemonic classification (WP9).
- Token-dump entry-point integration and display text (WP10).
- Statement parsing or expression evaluation.

## Textual and Numeric Scanning Model

### Character Classification Routines

To support scanning, the following private helpers will be implemented in `lexer.s`:

1. `isIdFirst`: Carry clear if `A` is in `[A-Z]`, `[a-z]` (PETSCII equivalents), or is `_` (`$5F`).
2. `isIdCont`: Carry clear if `A` is `isIdFirst` or in `[0-9]` (`$30-$39`).
3. `isHexDigit`: Carry clear if `A` is in `[0-9]`, `[A-F]`, or shifted `[A-F]`.
4. `isBinDigit`: Carry clear if `A` is `0` or `1`.
5. `isDecDigit`: Carry clear if `A` is in `[0-9]`.
6. `normalizeChar`: Convert a shifted letter `[$C1, $DA]` to unshifted `[$41, $5A]` by clearing bit 7 (subtracting `$80`). Other characters remain unchanged.

### Scanning Logic

The default branch of `lexerNext` will be replaced with character-class checks:

- **Directive (`.`)**:
  - Reset token. Append `.`. Consume `.`.
  - Loop: if lookahead is `isIdCont`, append and consume. If append fails, fail with `$18`.
  - If lookahead is not `isIdCont`, terminate loop.
  - Classify using case-insensitive string comparison against `.ORG`, `.BYTE`, `.WORD`, `.INCLUDE`, `.STATIC`, `.RELOC` in RODATA.
  - Emit `CASM_TOKEN_DIRECTIVE` with the matching subtype (or `CASM_DIRECTIVE_UNKNOWN`).

- **Hex Number (`$`)**:
  - Reset token. Append `$`. Consume `$`.
  - If lookahead is not `isHexDigit`, handle as malformed number.
  - Loop: append hex digit and consume. If append fails, fail with `$18`.
  - If lookahead is `isHexDigit`, repeat.
  - If lookahead is `isIdCont` (invalid suffix), handle as malformed number.
  - Emit `CASM_TOKEN_NUMBER` with subtype `CASM_NUMBER_HEX`.

- **Binary Number (`%`)**:
  - Reset token. Append `%`. Consume `%`.
  - If lookahead is not `isBinDigit`, handle as malformed number.
  - Loop: append binary digit and consume. If append fails, fail with `$18`.
  - If lookahead is `isBinDigit`, repeat.
  - If lookahead is `isIdCont` (invalid suffix), handle as malformed number.
  - Emit `CASM_TOKEN_NUMBER` with subtype `CASM_NUMBER_BINARY`.

- **Decimal Number (`0-9`)**:
  - Reset token.
  - Loop: append decimal digit and consume. If append fails, fail with `$18`.
  - If lookahead is `isDecDigit`, repeat.
  - If lookahead is `isIdCont` (invalid suffix), handle as malformed number.
  - Emit `CASM_TOKEN_NUMBER` with subtype `CASM_NUMBER_DECIMAL`.

- **Identifier (`isIdFirst`)**:
  - Reset token.
  - Loop: append character and consume. If append fails, fail with `$18`.
  - If lookahead is `isIdCont`, repeat.
  - If length is 1:
    - Normalize character to unshifted letter.
    - If `A`, `X`, or `Y`, emit `CASM_TOKEN_REGISTER` with matching subtype.
  - Else, emit `CASM_TOKEN_IDENTIFIER` with `CASM_SUBTYPE_NONE`.

### Malformed Number Error Handler

When a numeric scan encounters a malformed prefix or invalid suffix:

- Run a loop consuming characters from lookahead as long as they are `isIdCont`.
- Do not append them to the token text (to avoid polluting the valid prefix and to prevent unnecessary token-too-long errors on skipped malformed tails).
- Once a non-continuation character is hit, fail with `CASM_DIAG_MALFORMED_NUMBER` (`$1A`).

## String Comparison helper

A case-insensitive string comparison helper `compareTokenText` will be added to `lexer.s`:

- Inputs: `X/Y` pointing to an unshifted uppercase null-terminated string.
- Logic: Compares character-by-character against `CasmTokenText`, normalizing both character streams via `normalizeChar`.
- Output: Carry clear if match, Carry set if mismatch.
- RODATA strings:

  ```assembly
  dirOrgStr:      .byte ".ORG", 0
  dirByteStr:     .byte ".BYTE", 0
  dirWordStr:     .byte ".WORD", 0
  dirIncludeStr:  .byte ".INCLUDE", 0
  dirStaticStr:   .byte ".STATIC", 0
  dirRelocStr:    .byte ".RELOC", 0
  ```

## Planned Files

| Path | Action | Responsibility |
|---|---|---|
| `brain/plans/2026-07-16-casm-phase3-wp08-textual-numeric-tokens.md` | Create | Approved implementation plan |
| `src/external/casm/lexer.s` | Modify | Implement character checks, scanners, comparisons, and register/directive classification |
| `wiki/tasks/casm.md` | Modify | Update task status and fix the accepted MAIN envelope size to `$2000` |
| `brain/task.md` | Modify | Update Taskwarrior UUID tracking for WP8 |
| `brain/KNOWLEDGE.md` | Modify at closeout | Document scanning rules and case-insensitive normalization |
| `brain/MEMORY.md` | Modify at closeout | Record BSS/linked memory growth |
| `CHANGELOG.md` | Modify at closeout | Record the stage completion and version update |
| `brain/walkthroughs/2026-07-16-casm-phase3-wp08-textual-numeric-tokens.md` | Create at closeout | Build and non-regression evidence |

## Routine ABI

No public ABIs are altered or added. The existing `lexerNext` internal dispatch is extended.

## Atomic Implementation Increments

1. Activate WP8 task in `wiki/tasks/casm.md` and `brain/task.md`.
2. Add private character check helpers (`isIdFirst`, `isIdCont`, `isHexDigit`, `isBinDigit`, `isDecDigit`, `normalizeChar`) and tests to `lexer.s`.
3. Add `compareTokenText` helper and RODATA directive strings to `lexer.s`.
4. Implement the identifier scanner, including register case-insensitive classification.
5. Implement the directive scanner and classification.
6. Implement hexadecimal, binary, and decimal scanners.
7. Implement malformed number error handler (skipping invalid suffixes).
8. Verify clean compilation and linking.
9. Verify non-regression on standard source files via C64 execution (Option 1).
10. Update wiki tasks and prepare walkthrough.

## Verification Plan

### Static Verification

- Compile and link the target: `cmake --build build --target casm`.
- Audit `lexer.s` to verify that all registers and memory locations match zero-page scratch boundaries and do not clobber state.
- Verify that a rebuild with no changes does not increment `BUILD_CASM`.
- Verify the size and alignment of the resulting `casm.prg` is within the `$2000` envelope.

### Non-Regression Runtime Matrix

- The user will launch `casm` with existing fixtures (`casmshort`, `casm256`, `casmmulti`).
- Confirm that normal source files still produce `INPUT VALIDATED`.
- Confirm that files exceeding column limits or showing file-system errors produce the expected diagnostic codes.

## Stop Conditions

Stop and request an plan amendment if:

- Linked size exceeds the `$2000` envelope.
- Implementations leak or modify zero-page beyond `$70-$8F`.
- Statement parsing or opcode lookup is introduced.

## Completion Gate

WP8 is complete and ready for approval when:

- Static checks prove that all character checks and scanning loops are correct.
- Non-regression is verified on standard fixtures.
- `wiki/tasks/casm.md` acceptance checklist and status are updated.
- The version is bumped to `0.1.10` in `casm.s`.
- Walkthrough, changelog, memory, and knowledge records are updated and approved.
