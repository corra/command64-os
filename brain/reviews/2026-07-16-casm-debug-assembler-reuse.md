---
feature: casm-native-assembler
phase: 3
work-package: 2
reviewed: 2026-07-16
status: approved
---

# CASM Review: DEBUG Assembler Reuse Feasibility

## Executive Decision

Recommended for Phase 3: preserve DEBUG's independently verified mnemonic
ordering as reviewed reference knowledge, but implement a CASM-local table of
56 three-byte entries in WP9. The CASM table must use explicit PETSCII bytes,
omit DEBUG's `???` sentinel, and have no runtime, source-include, or build
coupling to DEBUG.

No DEBUG routine is suitable for direct Phase 3 reuse. Opcode, addressing-mode,
promotion, branch, and emission decisions remain Phase 4 or later work.

## Evidence Sources

- `src/external/debug/debug.s`: subject routines, tables, zero page, and BSS.
- `brain/kickassembler/KickAssembler.md`, Table A.3: independent
  repository-owned standard 6502 mnemonic/opcode/addressing reference.
- `brain/ca65/ca65.md`: ca65's standard legal-6502 versus illegal/65C02 mode
  distinction.
- `wiki/debug-test-plan.md`, Suite 9: existing DEBUG behavioral coverage.
- Approved Phase 0C.1 contract in
  `brain/plans/2026-07-16-casm-phase3-source-stream-lexer.md`.

DEBUG's own table was not used as the oracle for its audit.

## Component Inventory

| Component | Representation and ownership | Finding |
|---|---|---|
| `parseMnemonic` | `inputBuf,Y`; `mnemBuf`, `parsePos`; `mnemIndex` ZP | Fixed three-byte interactive parser; reject direct reuse |
| `parseOperand` | Interactive null-terminated line; DEBUG numeric and mode state | Combines syntax, evaluation, width choice, and branch deduction; reject |
| `parseHexWithDollar` | Optional `$`, then DEBUG `parseHexArg` | Bare input is hexadecimal, unlike CASM decimal; reject |
| `isBranchMnemonic` | Hard-coded DEBUG indices in `mnemIndex` | Branch set is correct; defer concept to Phase 4/6 |
| `calcRelOffset` | `currentAddr`, `operandVal`, `val1/val2` ZP | Arithmetic concept only; independently audit later |
| `lookupOpcode` | Linear scan of two 256-byte DEBUG tables | Phase 4 concern; fallback mutates deduced mode |
| `writeInstruction` | Writes through `(currentAddr),Y` | Conflicts with CASM structured output; reject |
| `modeLength` | 14-byte DEBUG RODATA | Structurally sound candidate evidence; Phase 4 approval deferred |
| `opStringTable` | 171 bytes: 56 names plus `???` | Names/order verified; only reviewed knowledge is reusable |
| `opMnemonicIndex` | 256-byte RODATA | Structurally consistent candidate; Phase 4 trust deferred |
| `opAddrMode` | 256-byte RODATA | Structurally consistent candidate; Phase 4 trust deferred |

DEBUG owns `$70-$7F` for `currentAddr`, range values, temporary values,
mnemonic/mode state, and operand values. It also owns a 64-byte `inputBuf`,
three-byte `mnemBuf`, and parser state in application BSS. Those locations and
representations are incompatible with CASM's Phase 0C.1 stream/token ABI.

## Mnemonic Completeness

The independent standard-6502 table and DEBUG match at every index. All names
are three bytes, unique, documented NMOS 6502 mnemonics. No illegal or 65C02
mnemonic appears. Recommended CASM subtype equals DEBUG index unless WP9's
detailed plan explicitly approves a different stable numbering.

| Index | Name | DEBUG bytes | Match | CASM subtype |
|---:|:---:|:---:|:---:|---:|
| 0 | ADC | ADC | yes | 0 |
| 1 | AND | AND | yes | 1 |
| 2 | ASL | ASL | yes | 2 |
| 3 | BCC | BCC | yes | 3 |
| 4 | BCS | BCS | yes | 4 |
| 5 | BEQ | BEQ | yes | 5 |
| 6 | BIT | BIT | yes | 6 |
| 7 | BMI | BMI | yes | 7 |
| 8 | BNE | BNE | yes | 8 |
| 9 | BPL | BPL | yes | 9 |
| 10 | BRK | BRK | yes | 10 |
| 11 | BVC | BVC | yes | 11 |
| 12 | BVS | BVS | yes | 12 |
| 13 | CLC | CLC | yes | 13 |
| 14 | CLD | CLD | yes | 14 |
| 15 | CLI | CLI | yes | 15 |
| 16 | CLV | CLV | yes | 16 |
| 17 | CMP | CMP | yes | 17 |
| 18 | CPX | CPX | yes | 18 |
| 19 | CPY | CPY | yes | 19 |
| 20 | DEC | DEC | yes | 20 |
| 21 | DEX | DEX | yes | 21 |
| 22 | DEY | DEY | yes | 22 |
| 23 | EOR | EOR | yes | 23 |
| 24 | INC | INC | yes | 24 |
| 25 | INX | INX | yes | 25 |
| 26 | INY | INY | yes | 26 |
| 27 | JMP | JMP | yes | 27 |
| 28 | JSR | JSR | yes | 28 |
| 29 | LDA | LDA | yes | 29 |
| 30 | LDX | LDX | yes | 30 |
| 31 | LDY | LDY | yes | 31 |
| 32 | LSR | LSR | yes | 32 |
| 33 | NOP | NOP | yes | 33 |
| 34 | ORA | ORA | yes | 34 |
| 35 | PHA | PHA | yes | 35 |
| 36 | PHP | PHP | yes | 36 |
| 37 | PLA | PLA | yes | 37 |
| 38 | PLP | PLP | yes | 38 |
| 39 | ROL | ROL | yes | 39 |
| 40 | ROR | ROR | yes | 40 |
| 41 | RTI | RTI | yes | 41 |
| 42 | RTS | RTS | yes | 42 |
| 43 | SBC | SBC | yes | 43 |
| 44 | SEC | SEC | yes | 44 |
| 45 | SED | SED | yes | 45 |
| 46 | SEI | SEI | yes | 46 |
| 47 | STA | STA | yes | 47 |
| 48 | STX | STX | yes | 48 |
| 49 | STY | STY | yes | 49 |
| 50 | TAX | TAX | yes | 50 |
| 51 | TAY | TAY | yes | 51 |
| 52 | TSX | TSX | yes | 52 |
| 53 | TXA | TXA | yes | 53 |
| 54 | TXS | TXS | yes | 54 |
| 55 | TYA | TYA | yes | 55 |

The independently confirmed branch set is exactly indices 3, 4, 5, 7, 8, 9,
11, and 12: `BCC BCS BEQ BMI BNE BPL BVC BVS`.

## Table Structure Audit

| Table | Verified structure | Result |
|---|---|---|
| `opStringTable` | 57 × 3 = 171 bytes | Entries 0-55 valid; `???` is entry 56 only |
| `opMnemonicIndex` | 16 rows × 16 = 256 bytes | Every value is 0-56; 56 is the illegal-opcode sentinel |
| `opAddrMode` | 16 rows × 16 = 256 bytes | Every value is `MODE_INV` 0 through `MODE_IZY` 13 |
| `modeLength` | 14 entries indexed 0-13 | Invalid maps to 1; valid modes map to lengths 1-3 |

Slot-by-slot comparison with the independent standard opcode table found 151
documented opcode slots and 105 invalid slots. Every documented slot maps to
the expected mnemonic and addressing mode. Every invalid mnemonic sentinel at
index 56 maps to `MODE_INV`, and no documented slot maps to `MODE_INV`.
Every mnemonic index 0-55 is reachable by at least one documented opcode.

`modeLength` values are correct for all 13 valid modes: implied and accumulator
are one byte; immediate, zero-page forms, relative, and indexed-indirect forms
are two bytes; absolute forms and indirect are three bytes. Its invalid-mode
length of one is safe for DEBUG disassembly traversal but must not become a CASM
error-recovery contract.

This establishes bounded plausibility only. Phase 4 must repeat the exhaustive
opcode audit against a trusted expected-byte oracle before adopting any table.

## Routine Dependency and Reuse Matrix

| Routine | Inputs/state | Flags and clobbers | Side effects | Reuse decision |
|---|---|---|---|---|
| `parseMnemonic` | Y cursor, 64-byte line, BSS token, ZP index | C status; A/X/Y and scratch clobbered | Advances parser state | Reject; reimplement stream-aware classification |
| `parseOperand` | Y cursor, DEBUG hex parser and mode/operand ZP | C status; A/Y and many scratch fields clobbered | Mutates mode and operand | Reject; Phase 4 statement grammar differs |
| `parseHexWithDollar` | Optional `$`; bare hex | Inherits `parseHexArg` carry/clobbers | Advances Y, stores `HexVal` | Reject; conflicts with decimal-default CASM |
| `isBranchMnemonic` | Hard-coded mnemonic index | C is Boolean; A clobbered | None beyond flags | Defer concept; do not copy index chain |
| `calcRelOffset` | Target and current address in DEBUG ZP | C status; A and `val1/val2` clobbered | Rewrites operand/mode | Defer independent arithmetic audit |
| `lookupOpcode` | DEBUG mnemonic/mode and tables | C status; A/X clobbered | Promotes/mutates mode recursively | Defer to Phase 4; redesign ABI |
| `writeInstruction` | X opcode, DEBUG address/operand/mode | Flags undocumented; A/Y/scratch clobbered | Writes RAM and advances address | Reject; incompatible emission architecture |

None carries file identity, line, column, token bounds, deterministic replay,
or resource-failure provenance. Direct linkage or transplantation is rejected.

## PETSCII and Case Findings

DEBUG compares character literals for space, `A`, `X`, `Y`, `#`, `(`, `)`,
comma, dollar, digits, and hexadecimal letters. `toUpper` maps `$41-$5A` to
`$C1-$DA` with `ORA #$80`; `parseHexArg` accepts `$41-$46` and `$C1-$C6` after
masking bit 7. The mnemonic table is emitted through ca65 string literals.

This behavior works within DEBUG's ca65/C64 character mapping but is not a safe
CASM source contract. CASM already encountered host-literal versus runtime
PETSCII mismatches in Phase 2. WP9 must therefore use explicit numeric PETSCII
bytes and an explicit fold operation while preserving original token spelling.
DEBUG's character-comparison code is not reusable.

## Language-Contract Comparison

| Feature | DEBUG | CASM | Decision |
|---|---|---|---|
| Input | 63-byte interactive RAM line | Rewindable file stream | Incompatible ABI |
| Mnemonic | Exactly three consumed bytes | Classified identifier token | Data compatible only |
| Case | DEBUG `toUpper` and ca65 literals | Explicit PETSCII fold | Reimplement |
| Labels/comments/directives | Unsupported | Required lexical classes | CASM-only |
| Bare number | Hexadecimal | Decimal | Fundamentally incompatible |
| `$` hexadecimal | Optional prefix | Required hexadecimal prefix | Parser not reusable |
| `%` binary | Unsupported | Required lexical form | CASM-only |
| Provenance | None | File ID, line, column | CASM-only |
| Width choice | Value selects ZP/absolute | Deferred; pass stability constrained | Do not reuse |
| Output | Direct memory write | Later structured file emission | Incompatible |

## Strategy Cost and Coupling Comparison

| Strategy | CASM RODATA | Estimated classifier CODE | BSS/ZP | Worst case | Coupling and fit |
|---|---:|---:|---:|---:|---|
| A: CASM-local table | 168 bytes | 35-55 bytes | 0 additional beyond token state | 56 entries / 168 byte compares | No DEBUG/build coupling; estimated 203-223 linked bytes; fits 1,391-byte baseline headroom |
| B: shared include | 168 bytes per app | 35-55 bytes CASM | 0 | Same runtime cost | Changes DEBUG source and regression surface; index coupling risk; no Phase 3 size benefit |
| C: generated tables | 168 bytes CASM | 35-55 bytes CASM | 0 | Same runtime cost | Adds canonical schema, generator, CMake, and both-app verification; excessive Phase 3 scope |

The estimates separate the 168 source-table bytes from lookup code. A local
table requires no alignment, BSS, zero-page, or relocation entries. Exact code
size and any linker padding must be measured in the approved WP9 implementation.
Even the upper estimate leaves roughly 1,168 bytes of the Phase 2 combined
envelope headroom before other Phase 3 packages; each package must still repeat
the cumulative memory gate.

## Phase 3 Decision

Adopt Strategy A: use DEBUG's verified order as reference knowledge and create
a CASM-local 168-byte table in WP9. Omit `???`; reserve only subtypes 0-55; use
explicit PETSCII numeric bytes; add compile-time count/range assertions and
build-integrated completeness checks. Do not link DEBUG, include DEBUG source,
or share DEBUG runtime state.

The user approved this decision on 2026-07-16.

## Phase 4 Deferrals

- Trust and representation of `opMnemonicIndex`, `opAddrMode`, and
  `modeLength`.
- Opcode lookup and possible declarative sharing.
- Zero-page/absolute promotion and accumulator/implied fallback.
- Branch recognition and relative displacement arithmetic.
- Statement parsing, addressing validation, and output-event design.
- Any DEBUG source or build change and its regression matrix.

Phase 4 must audit all 256 opcode slots against a trusted expected-byte oracle.

## Risks and Unresolved Questions

- Phase 3 total memory, not the mnemonic table alone, may exhaust the current
  envelope; every later work package retains its stop gate.
- Stable mnemonic subtype numbering must be frozen in the WP9 detailed plan.
- A shared declarative opcode source may become worthwhile in Phase 4, but only
  with explicit DEBUG regression authorization.
- DEBUG's invalid-mode length of one must not mask CASM errors.

No DEBUG defect was found and no stop condition was triggered.

## Verification Evidence

- 56/56 independent mnemonic names matched with no duplicate, omission,
  illegal instruction, or 65C02-only name.
- Branch set matched all eight expected conditional branches.
- Table cardinalities: 171, 256, 256, and 14 bytes respectively.
- All table indices and mode values remained in bounds.
- 151 documented and 105 invalid opcode slots were cross-consistent.
- All 56 documented mnemonic indices were reachable.
- DEBUG Test Suite 9 supports current behavior but was not treated as the
  independent oracle.
- No DEBUG, CASM, CMake, fixture, or build-counter file was changed by WP2.

## User Approval Status

The user approved Strategy A and WP2 completion on 2026-07-16.
