# Implementation Plan: CASM Phase 4 WP12 — Opcode Table and Addressing Mode Matcher

## Objective

WP12 turns a parsed statement into a concrete 6502 instruction encoding. It
adds a new module, `opcodes.s`, that owns a compressed legal-opcode table and
`opcodesFindOpcode`: a pure function of the WP11 `CasmParserStmt` record that
resolves the operand's concrete addressing mode, selects the correct opcode
byte, computes the instruction length, and reports invalid-mode and 8-bit
operand-range errors. It produces the encoding record the WP13 emission engine
consumes; it performs no I/O, tracks no program counter, and emits no bytes.

---

## Prerequisites

- WP11 complete (CASM `0.1.13`): `parser.s`/`parserParseStatement`,
  `CasmParserStmt`, the `CASM_OPKIND_*` set, and diagnostics `$1C`–`$1E` exist
  and are exercised by the temporary `casm.s` parse driver.
- The lexer's mnemonic table (`lexer.s`) assigns stable subtype indices `0`–`55`
  in the exact order the opcode table rows must follow.

## Inherited Decisions

- The parser records only nine coarse `CASM_OPKIND_*` operand categories and
  deliberately does **not** distinguish zero-page from absolute, nor mark
  relative branches. Resolving those is WP12's responsibility (see §3).
- Diagnostics stay contiguous in the dense `diagPrintFatal` table. WP11 already
  owns `CASM_DIAG_OPERAND_OUT_OF_RANGE` (`$1E`); WP12 reuses it for 8-bit
  operand overflow and adds only `CASM_DIAG_INVALID_ADDR_MODE` (`$1F`).
- Only the **legal** (documented) 6502 opcode set is supported. Undocumented
  opcodes are out of scope, which keeps `$FF` available as a table sentinel.
- `opcodesFindOpcode` is called only for `CasmParserStmt.Type == MNEMONIC`.
  Directive statements are handled by WP13; the WP14 orchestration loop
  dispatches on `Type`.

---

## Technical Specifications

### 1. Concrete addressing-mode enumeration

A fixed 13-mode enumeration `CASM_MODE_*`, with bit positions that are also the
canonical packing order of each mnemonic's opcode run:

| Bit | `CASM_MODE_*`         | Length | Operand width |
|-----|-----------------------|--------|---------------|
| 0   | `IMPLIED`             | 1      | none          |
| 1   | `ACCUMULATOR`         | 1      | none          |
| 2   | `IMMEDIATE`           | 2      | 8-bit         |
| 3   | `ZEROPAGE`            | 2      | 8-bit         |
| 4   | `ZEROPAGE_X`          | 2      | 8-bit         |
| 5   | `ZEROPAGE_Y`          | 2      | 8-bit         |
| 6   | `ABSOLUTE`            | 3      | 16-bit        |
| 7   | `ABSOLUTE_X`          | 3      | 16-bit        |
| 8   | `ABSOLUTE_Y`          | 3      | 16-bit        |
| 9   | `INDIRECT`            | 3      | 16-bit        |
| 10  | `INDEXED_INDIRECT`    | 2      | 8-bit         |
| 11  | `INDIRECT_INDEXED`    | 2      | 8-bit         |
| 12  | `RELATIVE`            | 2      | see §5        |

`CASM_MODE_COUNT = 13`. Lengths are stored in a 13-byte `modeLength` RODATA
table indexed by mode.

### 2. Compressed opcode table (`opcodes.s` RODATA)

A per-mnemonic bitmask plus a packed opcode run, indexed by the lexer's 0–55
mnemonic subtype:

- `opcodeMaskLo[56]`, `opcodeMaskHi[56]`: the 13-bit "supported modes" mask
  (bits 0–7 in Lo, bits 8–12 in Hi).
- `opcodeRunOffset[56]`: the start index of each mnemonic's opcode run within
  `opcodeBytes`.
- `opcodeBytes[]`: every legal opcode, grouped by mnemonic, ordered by ascending
  mode bit. Total length equals the legal-opcode count (151).

Presence is signalled by the mask bit, never by an opcode value, so `$00` (BRK)
is representable without a sentinel collision. `$FF` is reserved as an
unused/guard value and appears in no legal run.

Compile-time asserts: each of the three parallel tables has exactly 56 entries;
`opcodeBytes` spans exactly 151 bytes; `CASM_MODE_COUNT = 13`;
`CASM_MNEMONIC_COUNT = 56` (already asserted, re-referenced here).

Worked examples (validate the encoding):
- **LDA** (subtype 29): mask bits {2,3,4,6,7,8,10,11}; run `A9 A5 B5 AD BD B9 A1 B1`.
- **BNE** (subtype 8): mask bits {12}; run `D0`.
- **JMP** (subtype 27): mask bits {6,9}; run `4C 6C`.
- **INX** (subtype 25): mask bits {0}; run `E8`.

The complete pre-written 56-mnemonic table (masks, offsets, opcode runs) is in
**Appendix A**, ready to transcribe into `opcodes.s` `.byte` directives.

### 3. Operand-kind to concrete-mode resolution

`opcodesFindOpcode` maps `(OpKind, value size, mask)` to one `CASM_MODE_*`:

- `IMPLIED`  -> `IMPLIED`.
- `ACCUMULATOR` -> `ACCUMULATOR`.
- `IMMEDIATE` -> `IMMEDIATE`; require `ValHi == 0` else `OPERAND_OUT_OF_RANGE`.
- `INDIRECT` -> `INDIRECT` (16-bit; JMP only in the legal set).
- `INDEXED_INDIRECT` -> `INDEXED_INDIRECT`; require `ValHi == 0` else
  `OPERAND_OUT_OF_RANGE`.
- `INDIRECT_INDEXED` -> `INDIRECT_INDEXED`; require `ValHi == 0` else
  `OPERAND_OUT_OF_RANGE`.
- `ABSOLUTE`:
  - If the mask has `RELATIVE` set (i.e. the mnemonic is a branch), resolve to
    `RELATIVE` and do **not** apply the 8-bit check — the operand is a 16-bit
    target address; the displacement and its range check are WP13's job (§5).
  - Else if `ValHi == 0` and the mask has `ZEROPAGE` set -> `ZEROPAGE`.
  - Else -> `ABSOLUTE`.
- `ABSOLUTE_X`: if `ValHi == 0` and mask has `ZEROPAGE_X` -> `ZEROPAGE_X`, else
  `ABSOLUTE_X`.
- `ABSOLUTE_Y`: if `ValHi == 0` and mask has `ZEROPAGE_Y` -> `ZEROPAGE_Y`, else
  `ABSOLUTE_Y`.

"Supports `RELATIVE`" uniquely identifies a branch: no non-branch legal mnemonic
has a relative form, and branches have no other operand mode. After resolution,
if the mask bit for the resolved mode is clear, return
`CASM_DIAG_INVALID_ADDR_MODE`. Zero-page/absolute promotion above never yields
an unsupported mode because it only selects `ZEROPAGE*` when its bit is set and
otherwise falls back to the `ABSOLUTE*` form, whose support is then verified by
the same mask check.

### 4. Opcode selection

Given the resolved mode `m` with its bit set in the mask, the run index is the
number of set mask bits at positions `< m`. Iterate bits `0..m-1`, count set
bits, then `opcode = opcodeBytes[opcodeRunOffset[subtype] + index]`. Store the
result in the encoding record (§6) and set the length from `modeLength[m]`.

### 5. Relative branches (mode only; displacement deferred)

WP12 selects the `RELATIVE` mode and the branch opcode and sets length 2. It
does **not** compute the displacement or range-check it, because both require
the location counter (`CasmPc`), which does not exist until WP13. The 16-bit
branch target stays in `CasmParserStmt.Val`; WP13 computes
`target - (pc + 2)` at emit time and enforces the `-128..+127` range with a
dedicated WP13 diagnostic. This resolves a parent-plan dependency error (see the
Discrepancies section of the parent plan amendment).

### 6. Encoding output record

A small BSS record `CasmInsn` in `opcodes.s`, exported for WP13:

```
CASM_INSN_OPCODE = 0   ; selected opcode byte
CASM_INSN_MODE   = 1   ; resolved CASM_MODE_*
CASM_INSN_LENGTH = 2   ; 1..3 total instruction bytes
CASM_INSN_SIZE   = 3
```

---

## Proposed Changes

### Build System

No `CMakeLists.txt` change: `CASM_SRCS` is `GLOB_RECURSE` with
`CONFIGURE_DEPENDS`, so `src/external/casm/opcodes.s` is picked up on the next
`cmake -S . -B build`.

### CASM Codebase

#### [MODIFY] `common.inc`
- Add `CASM_MODE_*` (13 modes) + `CASM_MODE_COUNT` with a range assert.
- Add `CasmInsn` offsets + `CASM_INSN_SIZE` with a size assert.
- Add `CASM_DIAG_INVALID_ADDR_MODE = $1F`; advance `CASM_DIAG_PHASE4_LAST` to
  `$1F` and update the Phase 4 contiguity/last asserts.

#### [NEW] `opcodes.s`
- RODATA: `opcodeMaskLo/Hi[56]`, `opcodeRunOffset[56]`, `opcodeBytes[151]`,
  `modeLength[13]`, with the compile-time asserts from §2.
- BSS: `CasmInsn` (exported).
- Code: `opcodesFindOpcode` (exported) implementing §3–§6.

#### [MODIFY] `diagnostics.s`
- Append `msgInvalidAddrMode`; extend `diagMessageLo/Hi` and their
  completeness asserts to `CASM_DIAG_PHASE4_LAST` (`$1F`). `diagPrintFatal`'s
  range check already keys off `CASM_DIAG_PHASE4_LAST`, so it needs no edit
  beyond the constant moving.

#### [MODIFY] `casm.s` (temporary verification scaffolding)
- In the temporary WP11 parse loop, for each `MNEMONIC` statement call
  `opcodesFindOpcode` and branch to `startFatal` on carry set, so
  `INVALID ADDRESSING MODE` and immediate `OPERAND OUT OF RANGE` surface through
  the central fatal path. Directive statements skip the matcher. A clean run
  still prints `INPUT VALIDATED`. This extends the temporary driver; WP14
  replaces the whole loop with the parser/emitter path.

### Test Fixtures

#### [MODIFY] `cmake/GenerateCasmTestFixtures.cmake` + `CMakeLists.txt` list
- Reuse `casmwp11` (all valid modes) — it must still reach `INPUT VALIDATED`
  now that each mnemonic also resolves to a real opcode.
- `casmam1`: `LDA A`  -> accumulator mode unsupported by LDA -> INVALID ADDR MODE.
- `casmam2`: `INX #5` -> immediate mode unsupported by INX -> INVALID ADDR MODE.
- `casmrng1`: `LDA #$1234` -> immediate operand exceeds 8 bits -> OPERAND OUT OF RANGE.

---

## Register / Flag / Scratch Contract

`opcodesFindOpcode`
- **Inputs**: populated `CasmParserStmt` with `Type == MNEMONIC`.
- **Outputs (success)**: C clear; `CasmInsn.Opcode/Mode/Length` set; `A` = opcode.
- **Outputs (fail)**: C set; `A` = `CASM_DIAG_INVALID_ADDR_MODE` or
  `CASM_DIAG_OPERAND_OUT_OF_RANGE`.
- **Clobbers**: A, X, Y, `CasmExprScratch0`–`CasmExprScratch3` (`$84`–`$87`).
- **Preserves**: `CasmParserStmt` and all persistent lexer/source state.

Uses only the approved `$84`–`$87` expression scratch range; adds no zero-page
aliases.

---

## Atomic Increments

1. `common.inc`: mode enum, `CasmInsn` offsets, `$1F` diagnostic + asserts.
2. `diagnostics.s`: message + table extension + asserts. Build `casm`.
3. `opcodes.s`: tables + asserts (data only), then `opcodesFindOpcode`. Build `casm`.
4. `casm.s`: wire the matcher into the temporary driver. Build `casm`.
5. Fixtures + list registration. Build `test_image_d64`.

Each increment builds cleanly and preserves `BUILD_CASM` on a no-change rebuild
before the next begins.

## Failure and Cleanup Behavior

`opcodesFindOpcode` is allocation-free and owns no resources; it only returns
carry + a diagnostic. The temporary driver routes that through the existing
`startFatal`/`exitFatal` path, which already performs central cleanup and closes
the source. No new cleanup surface is introduced.

## Verification Plan

### Automated
- `cmake --build build --target casm` assembles and links; all size/range/table
  asserts pass. Confirm a no-change rebuild does not bump `BUILD_CASM`.
- Inspect the linked size against the `$2000` MAIN envelope (current ~6477 code
  bytes; the compressed table + matcher must stay within headroom — see Stop
  Conditions).

### Manual (user, local VICE)
- `casm casmwp11`  -> `CASM: INPUT VALIDATED` (all modes resolve to opcodes).
- `casm casmam1`   -> `CASM: INVALID ADDRESSING MODE`.
- `casm casmam2`   -> `CASM: INVALID ADDRESSING MODE`.
- `casm casmrng1`  -> `CASM: OPERAND OUT OF RANGE`.
- Note: selected opcode bytes are not yet observable (no dump); byte-exact
  correctness is verified by WP14's reference-binary comparison once emission
  exists. WP12's runtime evidence is limited to the error paths plus a clean
  all-valid pass.

## Documentation / Task / DOX Updates (on completion)

- `wiki/tasks/casm.md`: mark the WP12 task done with the completion note.
- Task Warrior: mark the WP12 task complete.
- `CHANGELOG.md`: WP12 entry.
- `brain/walkthroughs/2026-07-17-casm-phase4-wp12-opcode-table-matcher.md`.
- Memory: update if any non-obvious runtime behavior emerges.

## Stop Conditions

- If adding the table + matcher pushes the linked image beyond the `$2000` MAIN
  envelope, stop and raise an amended plan (envelope increase or table
  recompression) before continuing — do not silently grow the envelope.
- Any material deviation from §1–§6 (e.g. needing undocumented opcodes, or a
  different table shape) requires an amended plan and renewed approval.

## Completion Gate

Version stage advances `13` -> `14` (CASM `0.1.14`), recorded only after
automated verification, user runtime confirmation of the cases above, user
approval of the walkthrough, and the task/changelog/memory updates — together.

---

## Appendix A — Full Legal Opcode Table (pre-written for review)

Rows are in the lexer's mnemonic subtype order (0–55). `MaskLo`/`MaskHi` encode
the 13-bit supported-mode set (bit positions from §1: Lo holds bits 0–7, Hi
holds bits 8–12). `Off` is `opcodeRunOffset` into the packed `opcodeBytes`
array. `Opcode run` lists the mnemonic's opcodes in ascending mode-bit order,
which is exactly the packing order. Only documented opcodes are included; total
run length is 151.

| Idx | Mnem | Modes | MaskLo | MaskHi | Off | Opcode run (hex) |
|----:|------|-------|:------:|:------:|----:|------------------|
| 0  | ADC | imm,zp,zpx,abs,absx,absy,indX,indY | $DC | $0D | 0   | 69 65 75 6D 7D 79 61 71 |
| 1  | AND | imm,zp,zpx,abs,absx,absy,indX,indY | $DC | $0D | 8   | 29 25 35 2D 3D 39 21 31 |
| 2  | ASL | accum,zp,zpx,abs,absx | $DA | $00 | 16  | 0A 06 16 0E 1E |
| 3  | BCC | rel | $00 | $10 | 21  | 90 |
| 4  | BCS | rel | $00 | $10 | 22  | B0 |
| 5  | BEQ | rel | $00 | $10 | 23  | F0 |
| 6  | BIT | zp,abs | $48 | $00 | 24  | 24 2C |
| 7  | BMI | rel | $00 | $10 | 26  | 30 |
| 8  | BNE | rel | $00 | $10 | 27  | D0 |
| 9  | BPL | rel | $00 | $10 | 28  | 10 |
| 10 | BRK | implied | $01 | $00 | 29  | 00 |
| 11 | BVC | rel | $00 | $10 | 30  | 50 |
| 12 | BVS | rel | $00 | $10 | 31  | 70 |
| 13 | CLC | implied | $01 | $00 | 32  | 18 |
| 14 | CLD | implied | $01 | $00 | 33  | D8 |
| 15 | CLI | implied | $01 | $00 | 34  | 58 |
| 16 | CLV | implied | $01 | $00 | 35  | B8 |
| 17 | CMP | imm,zp,zpx,abs,absx,absy,indX,indY | $DC | $0D | 36  | C9 C5 D5 CD DD D9 C1 D1 |
| 18 | CPX | imm,zp,abs | $4C | $00 | 44  | E0 E4 EC |
| 19 | CPY | imm,zp,abs | $4C | $00 | 47  | C0 C4 CC |
| 20 | DEC | zp,zpx,abs,absx | $D8 | $00 | 50  | C6 D6 CE DE |
| 21 | DEX | implied | $01 | $00 | 54  | CA |
| 22 | DEY | implied | $01 | $00 | 55  | 88 |
| 23 | EOR | imm,zp,zpx,abs,absx,absy,indX,indY | $DC | $0D | 56  | 49 45 55 4D 5D 59 41 51 |
| 24 | INC | zp,zpx,abs,absx | $D8 | $00 | 64  | E6 F6 EE FE |
| 25 | INX | implied | $01 | $00 | 68  | E8 |
| 26 | INY | implied | $01 | $00 | 69  | C8 |
| 27 | JMP | abs,indirect | $40 | $02 | 70  | 4C 6C |
| 28 | JSR | abs | $40 | $00 | 72  | 20 |
| 29 | LDA | imm,zp,zpx,abs,absx,absy,indX,indY | $DC | $0D | 73  | A9 A5 B5 AD BD B9 A1 B1 |
| 30 | LDX | imm,zp,zpy,abs,absy | $6C | $01 | 81  | A2 A6 B6 AE BE |
| 31 | LDY | imm,zp,zpx,abs,absx | $DC | $00 | 86  | A0 A4 B4 AC BC |
| 32 | LSR | accum,zp,zpx,abs,absx | $DA | $00 | 91  | 4A 46 56 4E 5E |
| 33 | NOP | implied | $01 | $00 | 96  | EA |
| 34 | ORA | imm,zp,zpx,abs,absx,absy,indX,indY | $DC | $0D | 97  | 09 05 15 0D 1D 19 01 11 |
| 35 | PHA | implied | $01 | $00 | 105 | 48 |
| 36 | PHP | implied | $01 | $00 | 106 | 08 |
| 37 | PLA | implied | $01 | $00 | 107 | 68 |
| 38 | PLP | implied | $01 | $00 | 108 | 28 |
| 39 | ROL | accum,zp,zpx,abs,absx | $DA | $00 | 109 | 2A 26 36 2E 3E |
| 40 | ROR | accum,zp,zpx,abs,absx | $DA | $00 | 114 | 6A 66 76 6E 7E |
| 41 | RTI | implied | $01 | $00 | 119 | 40 |
| 42 | RTS | implied | $01 | $00 | 120 | 60 |
| 43 | SBC | imm,zp,zpx,abs,absx,absy,indX,indY | $DC | $0D | 121 | E9 E5 F5 ED FD F9 E1 F1 |
| 44 | SEC | implied | $01 | $00 | 129 | 38 |
| 45 | SED | implied | $01 | $00 | 130 | F8 |
| 46 | SEI | implied | $01 | $00 | 131 | 78 |
| 47 | STA | zp,zpx,abs,absx,absy,indX,indY | $D8 | $0D | 132 | 85 95 8D 9D 99 81 91 |
| 48 | STX | zp,zpy,abs | $68 | $00 | 139 | 86 96 8E |
| 49 | STY | zp,zpx,abs | $58 | $00 | 142 | 84 94 8C |
| 50 | TAX | implied | $01 | $00 | 145 | AA |
| 51 | TAY | implied | $01 | $00 | 146 | A8 |
| 52 | TSX | implied | $01 | $00 | 147 | BA |
| 53 | TXA | implied | $01 | $00 | 148 | 8A |
| 54 | TXS | implied | $01 | $00 | 149 | 9A |
| 55 | TYA | implied | $01 | $00 | 150 | 98 |

**Totals**: 56 rows; run offsets 0..150; `opcodeBytes` length = 151.

`modeLength[13]` (indexed by `CASM_MODE_*`, bit order from §1):
`1 1 2 2 2 2 3 3 3 3 2 2 2`.

Notes on non-obvious rows:
- **STA** has no immediate form (`#imm` store is illegal), so its mask omits bit 2.
- **LDX/STX** use zero-page,Y and absolute,Y (not X): LDX `B6/BE`, STX `96`.
- **JMP** is the only Indirect (bit 9) instruction; **JSR** is absolute-only.
- **BIT**, in the legal set, is zero-page/absolute only.
- All eight branches are relative-only (mask `$00/$10`), which is what the
  matcher uses to detect a branch when resolving an `ABSOLUTE` opkind (§3).
