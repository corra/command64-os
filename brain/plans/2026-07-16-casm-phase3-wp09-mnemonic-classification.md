---
feature: casm-native-assembler
phase: 3
work-package: 9
created: 2026-07-17
status: proposed
implementation-status: proposed
depends-on: casm-phase-3-wp08-textual-numeric-tokens
approval-required: true
---

# CASM Phase 3 WP9 Plan: Mnemonic Classification

## Approval Gate

This detailed implementation plan defines the mnemonic-table strategy, lookup routine, and compile-time assertions for CASM Phase 3 Work Package 9. The user must explicitly approve this plan before task activation or source edits begin. Material changes to the mnemonic table, lookup algorithm, or version numbering require an amended plan and renewed approval.

WP9 completion is separately gated: after implementation and static verification, the user must run the supported non-regression matrix, inspect linked sizes, and explicitly confirm completion before the version advances from `0.1.10` to `0.1.11`.

## Objective

Implement case-insensitive 6502 mnemonic classification (Strategy A from WP2) in `lexer.s`. Scanned identifiers of length 3 are compared against a local compact table of 56 three-byte entries (168 bytes of RODATA). Matches are transformed into `CASM_TOKEN_MNEMONIC` tokens with the corresponding subtype index (0-55). Unmatched identifiers remain `CASM_TOKEN_IDENTIFIER`.

WP9 does not implement statement parsing, opcode lookup, or addressing-mode mapping (Phase 4). It adds no new BSS or zero-page variables.

## Prerequisites and Inherited Decisions

- WP8 is complete at `0.1.10`, build 1032. The identifier, directive, register, and numeric scanners are fully operational.
- WP2 approved Strategy A: a local 168-byte mnemonic table in `lexer.s` RODATA, omitting DEBUG's `???` sentinel and using explicit PETSCII comparisons, with zero build or runtime coupling to DEBUG.
- Target envelope remains `$2000` (8,192 bytes). Current code is ~4.3KB, leaving ample headroom.

## Sub-Phase Dependency Audit and Resolutions

| Package | WP9 provides | Explicitly deferred |
|---|---|---|
| WP10 diagnostics/token dump | Mnemonics classified and ready for formatting | Token-dump driver and diagnostic text formatting |
| WP11 closeout | Mnemonic classification static evidence | Cumulative Phase 3 verification |

### Resolved Discrepancies

1. **Table Count and Duplicate Verification**: The parent plan calls for table-count, subtype-range, duplicate, and completeness checks using build verification.
   - *Resolution*: Implement a compile-time ca65 segment-difference assertion (`* - mnemonicTable = 168`) to guarantee exact entry-count. Duplicate and spelling checks are verified statically by compiling the source and auditing the table order against the audited WP2 matrix.

## Scope

### Included

- Define `mnemonicTable` in `lexer.s` RODATA with exactly 56 three-byte entries in standard unshifted uppercase PETSCII, matching the verified WP2 index order.
- Add compile-time segment assertion `MnemonicTableSize = * - mnemonicTable` to ensure it is exactly 168 bytes.
- Implement `classifyMnemonic` in `lexer.s` to perform case-insensitive linear search on the table.
- Skip checks immediately for identifiers whose length is not exactly 3.
- Map matched identifiers to `CASM_TOKEN_MNEMONIC` and subtype index (0-55).
- Re-run builds and verify that version bumps to `0.1.11` cleanly.

### Excluded

- Opcode byte mapping or addressing-mode metadata.
- Statement parsing or instruction generation.
- Shared include or generator changes affecting DEBUG.

## Mnemonic Table and Search Model

### Mnemonic Table (RODATA)

The table will be defined in `lexer.s` RODATA:
```assembly
mnemonicTable:
    .byte "ADC", "AND", "ASL", "BCC", "BCS", "BEQ", "BIT", "BMI"
    .byte "BNE", "BPL", "BRK", "BVC", "BVS", "CLC", "CLD", "CLI"
    .byte "CLV", "CMP", "CPX", "CPY", "DEC", "DEX", "DEY", "EOR"
    .byte "INC", "INX", "INY", "JMP", "JSR", "LDA", "LDX", "LDY"
    .byte "LSR", "NOP", "ORA", "PHA", "PHP", "PLA", "PLP", "ROL"
    .byte "ROR", "RTI", "RTS", "SBC", "SEC", "SED", "SEI", "STA"
    .byte "STX", "STY", "TAX", "TAY", "TSX", "TXA", "TXS", "TYA"
MnemonicTableSize = * - mnemonicTable
.assert MnemonicTableSize = 168, error, "Mnemonic table must occupy exactly 168 bytes"
```

### Search Logic (`classifyMnemonic`)

1. Check `CasmTokenRecord + CASM_TOKEN_REC_LENGTH`. If not equal to 3, return carry set (mismatch).
2. Load the base pointer `mnemonicTable` into `CasmPtr0Lo/Hi`.
3. Loop `X` from 0 to 55 (`CASM_MNEMONIC_COUNT`):
   - Compare `CasmTokenText[0..2]` against `(CasmPtr0Lo),Y` where `Y` is 0, 1, 2.
   - For each character comparison, normalize the token character using `normalizeChar`.
   - If all three match, return carry clear with `X` containing the index.
   - If any character mismatches, add 3 to `CasmPtr0Lo/Hi`, increment `X`, and repeat loop.
4. If the loop completes without a match, return carry set.

### Dispatch Integration

In `lexer.s` under `lnId`, after verifying that the identifier is not a register:
```assembly
@notReg:
    jsr classifyMnemonic
    bcs @notMnem
    lda #CASM_TOKEN_MNEMONIC
    jmp lexerEmitWithSubtype
@notMnem:
    lda #CASM_TOKEN_IDENTIFIER
    jmp lexerEmit
```

## Planned Files

| Path | Action | Responsibility |
|---|---|---|
| `brain/plans/2026-07-16-casm-phase3-wp09-mnemonic-classification.md` | Create | Approved implementation plan |
| `src/external/casm/lexer.s` | Modify | Define mnemonic table, implement `classifyMnemonic`, and wire it into the identifier scanner |
| `src/external/casm/casm.s` | Modify | Bump `VERSION_STAGE` macro to `11` |
| `wiki/tasks/casm.md` | Modify | Update task status |
| `brain/task.md` | Modify | Update Taskwarrior UUID tracking for WP9 |
| `brain/KNOWLEDGE.md` | Modify at closeout | Document mnemonic lookup design |
| `brain/MEMORY.md` | Modify at closeout | Record memory growth |
| `CHANGELOG.md` | Modify at closeout | Record the stage completion and version update |
| `brain/walkthroughs/2026-07-16-casm-phase3-wp09-mnemonic-classification.md` | Create at closeout | Build and non-regression evidence |

## Atomic Implementation Increments

1. Activate WP9 task in `wiki/tasks/casm.md` and `brain/task.md`.
2. Add `mnemonicTable` and the `.assert` check to the RODATA segment of `lexer.s`.
3. Implement the `classifyMnemonic` routine in the CODE segment of `lexer.s`.
4. Integrate the call to `classifyMnemonic` in the `lnId` path of `lexerNext`.
5. Verify clean compilation and linking.
6. Verify version stage bump to `11` in `casm.s`.
7. Verify non-regression on standard source files via C64 execution (Option 1).
8. Update wiki tasks and prepare walkthrough.

## Verification Plan

### Static Verification
- Compile and link the target: `cmake --build build --target casm`.
- Verify the size and alignment of the resulting `casm.prg` is within the `$2000` envelope.
- Confirm a no-change build does not bump `BUILD_CASM`.
- Verify that `mnemonicTable` is compiled with the exact 168-byte size check.

### Non-Regression Runtime Matrix
- Run the test disk (`test.d64`) in local VICE.
- Confirm that existing fixtures (`casmshort`, etc.) compile and report `INPUT VALIDATED` without regressions or crashes.
- Confirm missing/bad args still fail with the correct diagnostic codes.

## Stop Conditions

Stop and request a plan amendment if:
- Table search overflows zero page or clobbers register contracts.
- Opcode-to-instruction logic is introduced.
- Memory size exceeds the `$2000` envelope.

## Completion Gate

WP9 is complete and ready for approval when:
- `classifyMnemonic` correctly matches all 56 mnemonics case-insensitively.
- The 168-byte compile-time table size check is active.
- Non-regression is verified.
- The version is bumped to `0.1.11` in `casm.s`.
- Walkthrough, changelog, memory, and knowledge records are updated and approved.
