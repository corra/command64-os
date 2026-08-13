# CASM Phase 11 WP60 Increment 1 Opcode/Mode Oracle

Status: Frozen for user review
Branch: `feature/casm-phase11-wp60`
Baseline: CASM `0.2.1` build `1264`
Plan: `brain/plans/2026-08-11-casm-phase11-wp60-opcode-addressing-boundary-hardening.md`
Taskwarrior: `bd441121-dffa-4d69-8f3a-8572e0643322` (depends on completed WP59
`4a1fab7c-28af-4404-af39-6f283b552e55`)

## Scope and Method

This is the Increment 1 gate artifact. It freezes an independent oracle of all
151 legal NMOS 6502/6510 mnemonic/addressing-mode combinations CASM's opcode
table claims to support, maps each tuple to the parser input shape that
selects it and a representative end-to-end fixture statement, and mechanically
reconciles the oracle against `src/external/casm/opcodes.s`'s packed tables.

No production or fixture source changed while producing this document. The
151 opcode/length values below were authored from documented NMOS 6502
encoding (the standard MOS 6502 instruction matrix) independent of
`opcodeBytes`/`opcodeMaskLo`/`opcodeMaskHi`/`opcodeRunOffset`; only the
reconciliation script (recorded verbatim below) reads the production file, and
only to compare, never to source expected values.

## Frozen Processor Contract

- Target: documented NMOS 6502 instructions as implemented by the C64's 6510.
- 56 contiguous mnemonic subtypes (`CASM_MNEMONIC_FIRST`..`CASM_MNEMONIC_LAST`,
  `$00`-`$37`), in the alphabetical order fixed by `opcodes.s`'s existing
  comment columns: ADC AND ASL BCC BCS BEQ BIT BMI BNE BPL BRK BVC BVS CLC CLD
  CLI CLV CMP CPX CPY DEC DEX DEY EOR INC INX INY JMP JSR LDA LDX LDY LSR NOP
  ORA PHA PHP PLA PLP ROL ROR RTI RTS SBC SEC SED SEI STA STX STY TAX TAY TSX
  TXA TXS TYA.
- 13 `CASM_MODE_*` values (`0`-`12`): Implied, Accumulator, Immediate, Zero
  Page, Zero Page,X, Zero Page,Y, Absolute, Absolute,X, Absolute,Y, Indirect,
  (Indirect,X), (Indirect),Y, Relative.
- Exactly 151 legal mnemonic/mode combinations exist among documented NMOS
  opcodes for these 56 mnemonics. No 57th mnemonic and no 14th mode exist in
  the documented instruction set.
- Explicitly excluded, and not present anywhere in the oracle below: every
  undocumented/"illegal" 6502 opcode (e.g. `LAX`, `SAX`, `DCP`, `SLO`, `ANC`,
  `ALR`, `ARR`, `SBX`, `ISC`, `RLA`, `RRA`, `SRE`, `NOP`/`SKB`/`SKW`
  duplicates); every 65C02/65SC02/R65C02/65816/65CE02 addition (e.g.
  `BRA`, `PHX`, `PHY`, `PLX`, `PLY`, `STZ`, `TRB`, `TSB`, `(zp)` without
  index, `BBR`/`BBS`, `RMB`/`SMB`, `WAI`, `STP`); cycle-count/timing
  certification; and execution-semantic CPU testing (flag/register
  side-effects of running an instruction). WP60 certifies parsing, mode
  selection, length, and emitted bytes only.

## OpKind -> Mode Resolution (from `parser.s`/`opcodesFindOpcode`)

Traced directly from `parser.s`'s `parseOperandSequence` (token grammar ->
`CasmParserStmt.OpKind`) and `opcodes.s`'s `opcodesFindOpcode` (OpKind ->
concrete `CASM_MODE_*`, given the mnemonic's support mask and operand value).
This is the general rule every row in the 151-tuple table below instantiates;
it is recorded once here rather than repeated 151 times.

| Source token shape | Parser `OpKind` | Resolved `CASM_MODE_*` | Selection condition |
| --- | --- | --- | --- |
| no operand (NEWLINE/EOF immediately after mnemonic) | `IMPLIED` | Implied | always |
| bare register token `A` | `ACCUMULATOR` | Accumulator | `TokenRecord.Subtype == REGISTER_A`, else syntax error |
| `#value` | `IMMEDIATE` | Immediate | value must fit 8 bits (`ValHi == 0`), else `OPERAND_OUT_OF_RANGE` |
| bare `value` | `ABSOLUTE` | Zero Page | mnemonic mask has ZP bit, no `FORCE_ABS` flag, `ValHi == 0` |
| bare `value` | `ABSOLUTE` | Absolute | ZP unsupported, or `FORCE_ABS` set, or `ValHi != 0` |
| bare `value`, mnemonic mask has Relative bit | `ABSOLUTE` | Relative | mnemonic is a branch; no 8-bit check (WP13 computes/range-checks the 16-bit-target displacement) |
| `value,X` | `ABSOLUTE_X` | Zero Page,X | mnemonic mask has ZP,X bit, no `FORCE_ABS`, `ValHi == 0` |
| `value,X` | `ABSOLUTE_X` | Absolute,X | ZP,X unsupported, or `FORCE_ABS` set, or `ValHi != 0` |
| `value,Y` | `ABSOLUTE_Y` | Zero Page,Y | mnemonic mask has ZP,Y bit, no `FORCE_ABS`, `ValHi == 0` |
| `value,Y` | `ABSOLUTE_Y` | Absolute,Y | ZP,Y unsupported, or `FORCE_ABS` set, or `ValHi != 0` |
| `(value)` | `INDIRECT` | Indirect | always (only `JMP` supports the mode bit) |
| `(value,X)` | `INDEXED_INDIRECT` | (Indirect,X) | value must fit 8 bits, else `OPERAND_OUT_OF_RANGE` |
| `(value),Y` | `INDIRECT_INDEXED` | (Indirect),Y | value must fit 8 bits, else `OPERAND_OUT_OF_RANGE` |

`opcodesFindOpcode` then verifies the resolved mode's bit is set in the
mnemonic's mask (else `CASM_DIAG_INVALID_ADDR_MODE`) and selects the opcode by
counting set mask bits below the resolved mode's bit position, indexing into
the mnemonic's packed run in `opcodeBytes`.

Fixture statements below use representative operand values (`$12` for 8-bit,
`$1234` for 16-bit, `TARGET` for a branch label) purely to instantiate each
row's syntax; Increment 2's boundary register separately covers `$00`/`$FF`/
`$0100`/`$FFFF` literal edges, and Increment 6 covers `FORCE_ABS` and 8-bit
rejection at those same tuples.

## The 151-Tuple Oracle

Independently authored from documented NMOS 6502 encoding, in mnemonic
subtype order (0-55) and ascending `CASM_MODE_*` bit order within each
mnemonic -- the same order `opcodeBytes` packs its runs, which lets the
reconciliation below compare position-for-position.

| # | Mnemonic | Subtype | Mode | Opcode | Length | Fixture statement |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | ADC | 0 | Immediate | $69 | 2 | `ADC #$12` |
| 2 | ADC | 0 | Zero Page | $65 | 2 | `ADC $12` |
| 3 | ADC | 0 | Zero Page,X | $75 | 2 | `ADC $12,X` |
| 4 | ADC | 0 | Absolute | $6D | 3 | `ADC $1234` |
| 5 | ADC | 0 | Absolute,X | $7D | 3 | `ADC $1234,X` |
| 6 | ADC | 0 | Absolute,Y | $79 | 3 | `ADC $1234,Y` |
| 7 | ADC | 0 | (Indirect,X) | $61 | 2 | `ADC ($12,X)` |
| 8 | ADC | 0 | (Indirect),Y | $71 | 2 | `ADC ($12),Y` |
| 9 | AND | 1 | Immediate | $29 | 2 | `AND #$12` |
| 10 | AND | 1 | Zero Page | $25 | 2 | `AND $12` |
| 11 | AND | 1 | Zero Page,X | $35 | 2 | `AND $12,X` |
| 12 | AND | 1 | Absolute | $2D | 3 | `AND $1234` |
| 13 | AND | 1 | Absolute,X | $3D | 3 | `AND $1234,X` |
| 14 | AND | 1 | Absolute,Y | $39 | 3 | `AND $1234,Y` |
| 15 | AND | 1 | (Indirect,X) | $21 | 2 | `AND ($12,X)` |
| 16 | AND | 1 | (Indirect),Y | $31 | 2 | `AND ($12),Y` |
| 17 | ASL | 2 | Accumulator | $0A | 1 | `ASL A` |
| 18 | ASL | 2 | Zero Page | $06 | 2 | `ASL $12` |
| 19 | ASL | 2 | Zero Page,X | $16 | 2 | `ASL $12,X` |
| 20 | ASL | 2 | Absolute | $0E | 3 | `ASL $1234` |
| 21 | ASL | 2 | Absolute,X | $1E | 3 | `ASL $1234,X` |
| 22 | BCC | 3 | Relative | $90 | 2 | `BCC TARGET` |
| 23 | BCS | 4 | Relative | $B0 | 2 | `BCS TARGET` |
| 24 | BEQ | 5 | Relative | $F0 | 2 | `BEQ TARGET` |
| 25 | BIT | 6 | Zero Page | $24 | 2 | `BIT $12` |
| 26 | BIT | 6 | Absolute | $2C | 3 | `BIT $1234` |
| 27 | BMI | 7 | Relative | $30 | 2 | `BMI TARGET` |
| 28 | BNE | 8 | Relative | $D0 | 2 | `BNE TARGET` |
| 29 | BPL | 9 | Relative | $10 | 2 | `BPL TARGET` |
| 30 | BRK | 10 | Implied | $00 | 1 | `BRK` |
| 31 | BVC | 11 | Relative | $50 | 2 | `BVC TARGET` |
| 32 | BVS | 12 | Relative | $70 | 2 | `BVS TARGET` |
| 33 | CLC | 13 | Implied | $18 | 1 | `CLC` |
| 34 | CLD | 14 | Implied | $D8 | 1 | `CLD` |
| 35 | CLI | 15 | Implied | $58 | 1 | `CLI` |
| 36 | CLV | 16 | Implied | $B8 | 1 | `CLV` |
| 37 | CMP | 17 | Immediate | $C9 | 2 | `CMP #$12` |
| 38 | CMP | 17 | Zero Page | $C5 | 2 | `CMP $12` |
| 39 | CMP | 17 | Zero Page,X | $D5 | 2 | `CMP $12,X` |
| 40 | CMP | 17 | Absolute | $CD | 3 | `CMP $1234` |
| 41 | CMP | 17 | Absolute,X | $DD | 3 | `CMP $1234,X` |
| 42 | CMP | 17 | Absolute,Y | $D9 | 3 | `CMP $1234,Y` |
| 43 | CMP | 17 | (Indirect,X) | $C1 | 2 | `CMP ($12,X)` |
| 44 | CMP | 17 | (Indirect),Y | $D1 | 2 | `CMP ($12),Y` |
| 45 | CPX | 18 | Immediate | $E0 | 2 | `CPX #$12` |
| 46 | CPX | 18 | Zero Page | $E4 | 2 | `CPX $12` |
| 47 | CPX | 18 | Absolute | $EC | 3 | `CPX $1234` |
| 48 | CPY | 19 | Immediate | $C0 | 2 | `CPY #$12` |
| 49 | CPY | 19 | Zero Page | $C4 | 2 | `CPY $12` |
| 50 | CPY | 19 | Absolute | $CC | 3 | `CPY $1234` |
| 51 | DEC | 20 | Zero Page | $C6 | 2 | `DEC $12` |
| 52 | DEC | 20 | Zero Page,X | $D6 | 2 | `DEC $12,X` |
| 53 | DEC | 20 | Absolute | $CE | 3 | `DEC $1234` |
| 54 | DEC | 20 | Absolute,X | $DE | 3 | `DEC $1234,X` |
| 55 | DEX | 21 | Implied | $CA | 1 | `DEX` |
| 56 | DEY | 22 | Implied | $88 | 1 | `DEY` |
| 57 | EOR | 23 | Immediate | $49 | 2 | `EOR #$12` |
| 58 | EOR | 23 | Zero Page | $45 | 2 | `EOR $12` |
| 59 | EOR | 23 | Zero Page,X | $55 | 2 | `EOR $12,X` |
| 60 | EOR | 23 | Absolute | $4D | 3 | `EOR $1234` |
| 61 | EOR | 23 | Absolute,X | $5D | 3 | `EOR $1234,X` |
| 62 | EOR | 23 | Absolute,Y | $59 | 3 | `EOR $1234,Y` |
| 63 | EOR | 23 | (Indirect,X) | $41 | 2 | `EOR ($12,X)` |
| 64 | EOR | 23 | (Indirect),Y | $51 | 2 | `EOR ($12),Y` |
| 65 | INC | 24 | Zero Page | $E6 | 2 | `INC $12` |
| 66 | INC | 24 | Zero Page,X | $F6 | 2 | `INC $12,X` |
| 67 | INC | 24 | Absolute | $EE | 3 | `INC $1234` |
| 68 | INC | 24 | Absolute,X | $FE | 3 | `INC $1234,X` |
| 69 | INX | 25 | Implied | $E8 | 1 | `INX` |
| 70 | INY | 26 | Implied | $C8 | 1 | `INY` |
| 71 | JMP | 27 | Absolute | $4C | 3 | `JMP $1234` |
| 72 | JMP | 27 | Indirect | $6C | 3 | `JMP ($1234)` |
| 73 | JSR | 28 | Absolute | $20 | 3 | `JSR $1234` |
| 74 | LDA | 29 | Immediate | $A9 | 2 | `LDA #$12` |
| 75 | LDA | 29 | Zero Page | $A5 | 2 | `LDA $12` |
| 76 | LDA | 29 | Zero Page,X | $B5 | 2 | `LDA $12,X` |
| 77 | LDA | 29 | Absolute | $AD | 3 | `LDA $1234` |
| 78 | LDA | 29 | Absolute,X | $BD | 3 | `LDA $1234,X` |
| 79 | LDA | 29 | Absolute,Y | $B9 | 3 | `LDA $1234,Y` |
| 80 | LDA | 29 | (Indirect,X) | $A1 | 2 | `LDA ($12,X)` |
| 81 | LDA | 29 | (Indirect),Y | $B1 | 2 | `LDA ($12),Y` |
| 82 | LDX | 30 | Immediate | $A2 | 2 | `LDX #$12` |
| 83 | LDX | 30 | Zero Page | $A6 | 2 | `LDX $12` |
| 84 | LDX | 30 | Zero Page,Y | $B6 | 2 | `LDX $12,Y` |
| 85 | LDX | 30 | Absolute | $AE | 3 | `LDX $1234` |
| 86 | LDX | 30 | Absolute,Y | $BE | 3 | `LDX $1234,Y` |
| 87 | LDY | 31 | Immediate | $A0 | 2 | `LDY #$12` |
| 88 | LDY | 31 | Zero Page | $A4 | 2 | `LDY $12` |
| 89 | LDY | 31 | Zero Page,X | $B4 | 2 | `LDY $12,X` |
| 90 | LDY | 31 | Absolute | $AC | 3 | `LDY $1234` |
| 91 | LDY | 31 | Absolute,X | $BC | 3 | `LDY $1234,X` |
| 92 | LSR | 32 | Accumulator | $4A | 1 | `LSR A` |
| 93 | LSR | 32 | Zero Page | $46 | 2 | `LSR $12` |
| 94 | LSR | 32 | Zero Page,X | $56 | 2 | `LSR $12,X` |
| 95 | LSR | 32 | Absolute | $4E | 3 | `LSR $1234` |
| 96 | LSR | 32 | Absolute,X | $5E | 3 | `LSR $1234,X` |
| 97 | NOP | 33 | Implied | $EA | 1 | `NOP` |
| 98 | ORA | 34 | Immediate | $09 | 2 | `ORA #$12` |
| 99 | ORA | 34 | Zero Page | $05 | 2 | `ORA $12` |
| 100 | ORA | 34 | Zero Page,X | $15 | 2 | `ORA $12,X` |
| 101 | ORA | 34 | Absolute | $0D | 3 | `ORA $1234` |
| 102 | ORA | 34 | Absolute,X | $1D | 3 | `ORA $1234,X` |
| 103 | ORA | 34 | Absolute,Y | $19 | 3 | `ORA $1234,Y` |
| 104 | ORA | 34 | (Indirect,X) | $01 | 2 | `ORA ($12,X)` |
| 105 | ORA | 34 | (Indirect),Y | $11 | 2 | `ORA ($12),Y` |
| 106 | PHA | 35 | Implied | $48 | 1 | `PHA` |
| 107 | PHP | 36 | Implied | $08 | 1 | `PHP` |
| 108 | PLA | 37 | Implied | $68 | 1 | `PLA` |
| 109 | PLP | 38 | Implied | $28 | 1 | `PLP` |
| 110 | ROL | 39 | Accumulator | $2A | 1 | `ROL A` |
| 111 | ROL | 39 | Zero Page | $26 | 2 | `ROL $12` |
| 112 | ROL | 39 | Zero Page,X | $36 | 2 | `ROL $12,X` |
| 113 | ROL | 39 | Absolute | $2E | 3 | `ROL $1234` |
| 114 | ROL | 39 | Absolute,X | $3E | 3 | `ROL $1234,X` |
| 115 | ROR | 40 | Accumulator | $6A | 1 | `ROR A` |
| 116 | ROR | 40 | Zero Page | $66 | 2 | `ROR $12` |
| 117 | ROR | 40 | Zero Page,X | $76 | 2 | `ROR $12,X` |
| 118 | ROR | 40 | Absolute | $6E | 3 | `ROR $1234` |
| 119 | ROR | 40 | Absolute,X | $7E | 3 | `ROR $1234,X` |
| 120 | RTI | 41 | Implied | $40 | 1 | `RTI` |
| 121 | RTS | 42 | Implied | $60 | 1 | `RTS` |
| 122 | SBC | 43 | Immediate | $E9 | 2 | `SBC #$12` |
| 123 | SBC | 43 | Zero Page | $E5 | 2 | `SBC $12` |
| 124 | SBC | 43 | Zero Page,X | $F5 | 2 | `SBC $12,X` |
| 125 | SBC | 43 | Absolute | $ED | 3 | `SBC $1234` |
| 126 | SBC | 43 | Absolute,X | $FD | 3 | `SBC $1234,X` |
| 127 | SBC | 43 | Absolute,Y | $F9 | 3 | `SBC $1234,Y` |
| 128 | SBC | 43 | (Indirect,X) | $E1 | 2 | `SBC ($12,X)` |
| 129 | SBC | 43 | (Indirect),Y | $F1 | 2 | `SBC ($12),Y` |
| 130 | SEC | 44 | Implied | $38 | 1 | `SEC` |
| 131 | SED | 45 | Implied | $F8 | 1 | `SED` |
| 132 | SEI | 46 | Implied | $78 | 1 | `SEI` |
| 133 | STA | 47 | Zero Page | $85 | 2 | `STA $12` |
| 134 | STA | 47 | Zero Page,X | $95 | 2 | `STA $12,X` |
| 135 | STA | 47 | Absolute | $8D | 3 | `STA $1234` |
| 136 | STA | 47 | Absolute,X | $9D | 3 | `STA $1234,X` |
| 137 | STA | 47 | Absolute,Y | $99 | 3 | `STA $1234,Y` |
| 138 | STA | 47 | (Indirect,X) | $81 | 2 | `STA ($12,X)` |
| 139 | STA | 47 | (Indirect),Y | $91 | 2 | `STA ($12),Y` |
| 140 | STX | 48 | Zero Page | $86 | 2 | `STX $12` |
| 141 | STX | 48 | Zero Page,Y | $96 | 2 | `STX $12,Y` |
| 142 | STX | 48 | Absolute | $8E | 3 | `STX $1234` |
| 143 | STY | 49 | Zero Page | $84 | 2 | `STY $12` |
| 144 | STY | 49 | Zero Page,X | $94 | 2 | `STY $12,X` |
| 145 | STY | 49 | Absolute | $8C | 3 | `STY $1234` |
| 146 | TAX | 50 | Implied | $AA | 1 | `TAX` |
| 147 | TAY | 51 | Implied | $A8 | 1 | `TAY` |
| 148 | TSX | 52 | Implied | $BA | 1 | `TSX` |
| 149 | TXA | 53 | Implied | $8A | 1 | `TXA` |
| 150 | TXS | 54 | Implied | $9A | 1 | `TXS` |
| 151 | TYA | 55 | Implied | $98 | 1 | `TYA` |

Notable NMOS asymmetries the oracle deliberately preserves (matched exactly
by production, confirmed below):

- `STA` has no Immediate mode (storing to an immediate is meaningless); its
  8-mode peers (`ADC`/`AND`/`CMP`/`EOR`/`LDA`/`ORA`/`SBC`) do.
- `LDX`/`STX` take Zero Page,Y (not ,X); `LDY`/`STY` take Zero Page,X (not
  ,Y) -- the X/Y roles swap relative to most other indexed mnemonics.
- `JMP` is the only mnemonic with Indirect mode, and it lacks Zero Page/
  Absolute,X/Absolute,Y/Immediate entirely (2 modes total, the fewest of any
  non-implied/non-branch mnemonic).
- `ASL`/`LSR`/`ROL`/`ROR` are the only mnemonics with Accumulator mode.
- All eight branches (`BCC` `BCS` `BEQ` `BMI` `BNE` `BPL` `BVC` `BVS`) are
  Relative-only, one opcode each.

## Mechanical Reconciliation

The independent oracle above was encoded in a script and compared
position-for-position against `opcodeMaskLo`/`opcodeMaskHi`/`opcodeRunOffset`/
`opcodeBytes`/`modeLength` as parsed directly out of
`src/external/casm/opcodes.s`. The script never reads expected values from the
production file; it only parses production bytes for the comparison step.

Result, run against baseline `0.2.1` build `1264`:

```
Total independently authored legal tuples: 151
Parsed production: maskLo=56 maskHi=56 runOffset=56 opcodeBytes=151 modeLength=13
MATCH: opcodeMaskLo (56 entries)
MATCH: opcodeMaskHi (56 entries)
MATCH: opcodeRunOffset (56 entries)
MATCH: opcodeBytes (151 entries)
MATCH: modeLength (13 entries)

ALL MATCH -- production table verified byte-for-byte against independent oracle

Total set mask bits across all 56 mnemonics: 151 (expect 151)
Total packed opcode bytes: 151 (expect 151)
```

This proves, independent of the production source:

- every one of the 151 oracle tuples has exactly one corresponding production
  mask bit (151 set bits total, across all 56 masks) and exactly one
  corresponding `opcodeBytes` entry (151 packed bytes total) -- the required
  one-to-one correspondence with no duplicate or missing bit/byte;
- `opcodeMaskLo`/`opcodeMaskHi` legality, `opcodeRunOffset` run starts, and
  the packed `opcodeBytes` run contents match the independent oracle exactly,
  mnemonic by mnemonic and mode by mode;
- `modeLength` (Implied/Accumulator = 1; Immediate/Zero Page variants/
  (Indirect,X)/(Indirect),Y/Relative = 2; Absolute variants/Indirect = 3)
  matches documented NMOS instruction lengths exactly;
- no undocumented or 65C02-family opcode appears in the packed table (the
  independent oracle contains none, and the byte-for-byte match rules out
  production carrying extras the oracle lacks).

No defect was found in `opcodeMaskLo`, `opcodeMaskHi`, `opcodeRunOffset`,
`opcodeBytes`, or `modeLength`. This reconciliation record supersedes the need
to re-derive these five tables by hand in Increment 4/9; those increments
build the executable matcher and consolidated audit on top of this frozen
result rather than re-proving it.

## Unsupported Processor/Features (explicit record)

Per the plan's Frozen Processor Contract, WP60 does not add and this oracle
does not certify:

- Undocumented/"illegal" NMOS opcodes (`LAX`, `SAX`, `DCP`, `SLO`, `RLA`,
  `SRE`, `RRA`, `ISC`/`ISB`, `ANC`, `ALR`/`ASR`, `ARR`, `SBX`/`AXS`, `SHA`,
  `SHX`, `SHY`, `TAS`, `LAS`, duplicate `NOP`/`SKB`/`SKW` encodings, and the
  `JAM`/`KIL`/`HLT` halt opcodes).
- CMOS-family additions (65C02/65SC02/R65C02/65816/65CE02): `BRA`, `PHX`,
  `PHY`, `PLX`, `PLY`, `STZ`, `TRB`, `TSB`, indirect-without-index `(zp)` for
  `ADC`/`AND`/`CMP`/`EOR`/`LDA`/`ORA`/`SBC`/`STA`, `BBR0`-`BBR7`,
  `BBS0`-`BBS7`, `RMB0`-`RMB7`, `SMB0`-`SMB7`, `WAI`, `STP`.
- Cycle-count/timing certification and execution-semantic CPU testing
  (register/flag/memory side effects of actually running an instruction).
  WP60 certifies parsing, mode selection, length, and emitted bytes only.

## Sign-off

Static reconciliation is complete: the independent oracle matches production
exactly across all five tables, with the required one-to-one bit/byte
correspondence proven mechanically. No production defect found.

Requesting user approval of this frozen oracle before Increment 2 (freeze the
boundary evidence register) activates. Per the plan, no executable fixture
(`test_casm_opcodes`, `casmopall.s`) is added until this increment is
approved.
