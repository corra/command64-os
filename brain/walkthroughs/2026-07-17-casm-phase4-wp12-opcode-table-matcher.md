# CASM Phase 4 WP12 — Opcode Table and Addressing Mode Matcher Walkthrough

- **Date**: 2026-07-17
- **Version**: CASM `0.1.14`, build 1047
- **Plan**: `brain/plans/2026-07-17-casm-phase4-wp12-opcode-table-matcher.md`
- **Parent plan**: `brain/plans/2026-07-17-casm-phase4-statement-parser-opcode-table.md`

## Scope Delivered

- `opcodes.s` (new): the compressed legal-6502 opcode table (per-mnemonic
  13-bit supported-mode mask in `opcodeMaskLo/Hi`, `opcodeRunOffset`, and the
  151-byte packed `opcodeBytes` run, plus `modeLength`), the exported `CasmInsn`
  record, and `opcodesFindOpcode`. The matcher resolves a `CasmParserStmt`
  operand kind to one `CASM_MODE_*` (with zero-page/absolute promotion by value
  size and relative-branch detection), verifies mnemonic support against the
  mask, selects the opcode by counting set mask bits below the resolved mode,
  and records opcode/mode/length in `CasmInsn`.
- `common.inc`: `CASM_MODE_*` (13 modes), `CasmInsn` offsets, and
  `CASM_DIAG_INVALID_ADDR_MODE` ($1F) with contiguity/size asserts.
- `diagnostics.s`: `INVALID ADDRESSING MODE` message and table extension.
- `casm.s`: the temporary driver now calls `opcodesFindOpcode` on mnemonic
  statements so addressing-mode and operand-range errors reach the fatal path.
- Fixtures `casmam1`, `casmam2`, `casmrng1`.

## Plan Adherence and Deviations

- Implemented as planned. The relative-branch displacement/range check was
  never in WP12's implemented scope — it was reassigned to WP13 during the
  planning reconciliation (the program counter it needs is a WP13 artifact),
  and `CASM_DIAG_BRANCH_OUT_OF_RANGE` ($23) is reserved for WP13.
- `CASM_DIAG_OPERAND_OUT_OF_RANGE` ($1E, from WP11) is reused for immediate and
  indirect-zero-page operands wider than 8 bits; WP12 adds only $1F.
- No `CMakeLists.txt` source-list edit: `opcodes.s` is picked up by the
  glob-recursive `CASM_SRCS`.

## Automated Verification

- `cmake --build build --target casm` assembles and links cleanly; all size,
  range, and table asserts pass (mask/offset tables = 56 entries, `opcodeBytes`
  = 151, `modeLength` = 13).
- Linked image is 7199 code bytes, ~993 bytes under the `$2000` MAIN envelope
  (Stop Condition satisfied).
- No-change rebuild does not increment `BUILD_CASM` (held at 1047).
- A host-side model of `opcodesFindOpcode`, driven by the actual tables parsed
  from `opcodes.s`, reproduced the correct documented opcodes for all 14
  representative cases (implied, immediate, zero-page vs absolute promotion,
  absolute-X/Y, accumulator, both indirect indexed forms, indirect JMP, STX
  zero-page,Y, and branch to relative) and the correct INVALID/RANGE errors.

## Runtime Verification (user-confirmed in local VICE)

| Command | Expected | Result |
|---------|----------|--------|
| `casm casmwp11` | `CASM: INPUT VALIDATED` (all modes resolve to opcodes) | pass |
| `casm casmam1` (`LDA A`) | `CASM: INVALID ADDRESSING MODE` | pass |
| `casm casmam2` (`INX #5`) | `CASM: INVALID ADDRESSING MODE` | pass |
| `casm casmrng1` (`LDA #$1234`) | `CASM: OPERAND OUT OF RANGE` | pass |
| WP11 fixtures (`casmerr1`–`casmerr5`) | unchanged behavior | pass |

## Known Limitations / Follow-ups

- Selected opcode bytes are not observable at runtime (no dump); byte-exact
  correctness is verified by WP14's reference-binary comparison once emission
  exists. WP12's runtime evidence is the error paths plus a clean all-valid pass.
- The `casm.s` matcher call is temporary scaffolding; WP14 replaces the driver
  with the parser/emitter loop.

## Completion

- User confirmed all tests pass and approved marking WP12 done on 2026-07-17.
- Version stage advanced `13` → `14` (CASM `0.1.14`), build 1047.
