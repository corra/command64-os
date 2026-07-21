; src/external/casm/opcodes.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 4 WP12 opcode table and addressing-mode matcher. This module owns
; a compressed legal-6502 opcode table and opcodesFindOpcode, a pure function of
; the WP11 CasmParserStmt record: it resolves the operand's concrete addressing
; mode, selects the opcode byte, computes the instruction length, and reports
; invalid-mode and 8-bit operand-range errors into the exported CasmInsn record
; the WP13 emission engine consumes. It performs no I/O, tracks no program
; counter, and emits no bytes.
;
; The opcode table is indexed by the lexer's mnemonic subtype (0-55). Each
; mnemonic has a 13-bit supported-mode mask (opcodeMaskLo/Hi), a start offset
; into the packed opcodeBytes run (opcodeRunOffset), and its opcodes packed in
; ascending CASM_MODE_* bit order. Only documented opcodes are represented; mode
; presence is signalled by the mask bit, so $00 (BRK) needs no sentinel.

.include "common.inc"

.import CasmParserStmt
.import diagSetLocFromStmt

.export CasmInsn
.export opcodesFindOpcode

.segment "BSS"

CasmInsn:
    .res CASM_INSN_SIZE

.segment "CODE"

; ---------------------------------------------------------------------------
; opcodesFindOpcode
; Resolve the concrete addressing mode for the current mnemonic statement,
; select its opcode, and record opcode/mode/length in CasmInsn.
;
; Inputs:    CasmParserStmt populated with Type = MNEMONIC (Subtype = 0-55,
;            OpKind, Val)
; Outputs:   Success: C clear, A = opcode; CasmInsn.Opcode/Mode/Length set
;            Fail:    C set, A = CASM_DIAG_INVALID_ADDR_MODE or
;                     CASM_DIAG_OPERAND_OUT_OF_RANGE
; Preserves: CasmParserStmt
; Clobbers:  A, X, Y, CasmExprScratch0-3
; ---------------------------------------------------------------------------
; Scratch aliases (documented transient use within this call only).
ofResolvedMode = CasmExprScratch0   ; resolved CASM_MODE_*
ofMaskLo       = CasmExprScratch1   ; mnemonic support mask, low 8 bits
ofMaskHi       = CasmExprScratch2   ; mnemonic support mask, high 5 bits
ofScratch      = CasmExprScratch3   ; general scratch

opcodesFindOpcode:
    ; Load the mnemonic's support mask once; resolution and the presence check
    ; both consult it.
    ldx CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    lda opcodeMaskLo, x
    sta ofMaskLo
    lda opcodeMaskHi, x
    sta ofMaskHi

    ; Dispatch on the parser operand kind to a candidate concrete mode.
    lda CasmParserStmt + CASM_PARSER_STMT_OPKIND
    cmp #CASM_OPKIND_IMPLIED
    bne @notImplied
    lda #CASM_MODE_IMPLIED
    jmp ofHaveMode
@notImplied:
    cmp #CASM_OPKIND_ACCUMULATOR
    bne @notAccum
    lda #CASM_MODE_ACCUMULATOR
    jmp ofHaveMode
@notAccum:
    cmp #CASM_OPKIND_IMMEDIATE
    bne @notImm
    jsr ofRequire8Bit
    bcc @immOk
    jmp ofRangeError
@immOk:
    lda #CASM_MODE_IMMEDIATE
    jmp ofHaveMode
@notImm:
    cmp #CASM_OPKIND_INDIRECT
    bne @notInd
    lda #CASM_MODE_INDIRECT
    jmp ofHaveMode
@notInd:
    cmp #CASM_OPKIND_INDEXED_INDIRECT
    bne @notIndX
    jsr ofRequire8Bit
    bcc @indXOk
    jmp ofRangeError
@indXOk:
    lda #CASM_MODE_INDEXED_INDIRECT
    jmp ofHaveMode
@notIndX:
    cmp #CASM_OPKIND_INDIRECT_INDEXED
    bne @notIndY
    jsr ofRequire8Bit
    bcc @indYOk
    jmp ofRangeError
@indYOk:
    lda #CASM_MODE_INDIRECT_INDEXED
    jmp ofHaveMode
@notIndY:
    cmp #CASM_OPKIND_ABSOLUTE_X
    bne @notAbsX
    ; ZeroPage,X when the value fits a byte and the mode is supported.
    lda ofMaskLo
    and #(1 << CASM_MODE_ZEROPAGE_X)
    beq @useAbsX
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    bne @useAbsX
    lda #CASM_MODE_ZEROPAGE_X
    jmp ofHaveMode
@useAbsX:
    lda #CASM_MODE_ABSOLUTE_X
    jmp ofHaveMode
@notAbsX:
    cmp #CASM_OPKIND_ABSOLUTE_Y
    bne @notAbsY
    ; ZeroPage,Y bit lives in the high mask byte.
    lda ofMaskHi
    and #(1 << (CASM_MODE_ZEROPAGE_Y - 8))
    beq @useAbsY
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    bne @useAbsY
    lda #CASM_MODE_ZEROPAGE_Y
    jmp ofHaveMode
@useAbsY:
    lda #CASM_MODE_ABSOLUTE_Y
    jmp ofHaveMode
@notAbsY:
    ; Remaining kind is ABSOLUTE. A mnemonic that supports RELATIVE is a branch;
    ; its NUMBER operand is a 16-bit target, so resolve to RELATIVE with no
    ; 8-bit check (WP13 computes and range-checks the displacement).
    lda ofMaskHi
    and #(1 << (CASM_MODE_RELATIVE - 8))
    beq @notBranch
    lda #CASM_MODE_RELATIVE
    jmp ofHaveMode
@notBranch:
    ; ZeroPage when the value fits a byte and the mode is supported, else
    ; Absolute.
    lda ofMaskLo
    and #(1 << CASM_MODE_ZEROPAGE)
    beq @useAbs
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    bne @useAbs
    lda #CASM_MODE_ZEROPAGE
    jmp ofHaveMode
@useAbs:
    lda #CASM_MODE_ABSOLUTE

ofHaveMode:
    ; A = resolved mode. Verify the mnemonic supports it, then select the
    ; opcode and length.
    sta ofResolvedMode
    jsr ofModeSupported
    bcc ofModeError
    jsr ofSelectOpcode
    ; A = opcode. Store encoding.
    sta CasmInsn + CASM_INSN_OPCODE
    lda ofResolvedMode
    sta CasmInsn + CASM_INSN_MODE
    tax
    lda modeLength, x
    sta CasmInsn + CASM_INSN_LENGTH
    lda CasmInsn + CASM_INSN_OPCODE
    clc
    rts

ofModeError:
    jsr diagSetLocFromStmt      ; the offending instruction's own line
    lda #CASM_DIAG_INVALID_ADDR_MODE
    sec
    rts
ofRangeError:
    jsr diagSetLocFromStmt      ; the offending instruction's own line
    lda #CASM_DIAG_OPERAND_OUT_OF_RANGE
    sec
    rts

; ---------------------------------------------------------------------------
; ofRequire8Bit (private)
; Require CasmParserStmt.ValHi == 0 (operand fits one byte).
; Outputs: C clear when the value fits 8 bits; C set otherwise.
; ---------------------------------------------------------------------------
ofRequire8Bit:
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    beq @ok
    sec
    rts
@ok:
    clc
    rts

; ---------------------------------------------------------------------------
; ofModeSupported (private)
; Test whether ofResolvedMode's bit is set in the mnemonic mask.
; Outputs: C set when supported; C clear when not.
; Clobbers: A, X, Y
; ---------------------------------------------------------------------------
ofModeSupported:
    ldx ofResolvedMode
    cpx #8
    bcs @hi
    ; Bit index < 8: build the mask bit in ofMaskLo.
    lda #1
    cpx #0
    beq @loTest
@loShift:
    asl a
    dex
    bne @loShift
@loTest:
    and ofMaskLo
    bne @yes
    clc
    rts
@hi:
    ; Bit index 8-12: shift within the high byte.
    txa
    sec
    sbc #8
    tax
    lda #1
    cpx #0
    beq @hiTest
@hiShift:
    asl a
    dex
    bne @hiShift
@hiTest:
    and ofMaskHi
    bne @yes
    clc
    rts
@yes:
    sec
    rts

; ---------------------------------------------------------------------------
; ofSelectOpcode (private)
; With ofResolvedMode supported, compute the run index (count of set mask bits
; below the resolved mode) and load the opcode.
; Outputs: A = opcode byte
; Clobbers: A, X, Y, ofScratch
; ---------------------------------------------------------------------------
ofSelectOpcode:
    ; Count set bits at positions 0..resolvedMode-1 across the 13-bit mask.
    lda #0
    sta ofScratch          ; running index
    ldy #0                 ; current bit position
@loop:
    cpy ofResolvedMode
    beq @done
    jsr ofMaskBitSet       ; C set if mask bit Y is set
    bcc @next
    inc ofScratch
@next:
    iny
    jmp @loop
@done:
    ; opcode = opcodeBytes[opcodeRunOffset[subtype] + index]
    ldx CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    lda opcodeRunOffset, x
    clc
    adc ofScratch
    tax
    lda opcodeBytes, x
    rts

; ---------------------------------------------------------------------------
; ofMaskBitSet (private)
; Test bit Y (0-12) of the split mask in ofMaskLo/ofMaskHi.
; Inputs:  Y = bit position
; Outputs: C set when the bit is set; C clear otherwise
; Preserves: Y
; Clobbers: A, X
; ---------------------------------------------------------------------------
ofMaskBitSet:
    cpy #8
    bcs @hi
    tya
    tax
    lda #1
    cpx #0
    beq @loTest
@loShift:
    asl a
    dex
    bne @loShift
@loTest:
    and ofMaskLo
    bne @set
    clc
    rts
@hi:
    tya
    sec
    sbc #8
    tax
    lda #1
    cpx #0
    beq @hiTest
@hiShift:
    asl a
    dex
    bne @hiShift
@hiTest:
    and ofMaskHi
    bne @set
    clc
    rts
@set:
    sec
    rts

.segment "RODATA"

; Supported-mode masks (bits 0-7 in Lo, bits 8-12 in Hi), indexed by mnemonic
; subtype 0-55. See brain/plans/2026-07-17-casm-phase4-wp12-opcode-table-matcher.md
; Appendix A.
opcodeMaskLo:
    .byte $DC, $DC, $DA, $00, $00, $00, $48, $00 ; ADC AND ASL BCC BCS BEQ BIT BMI
    .byte $00, $00, $01, $00, $00, $01, $01, $01 ; BNE BPL BRK BVC BVS CLC CLD CLI
    .byte $01, $DC, $4C, $4C, $D8, $01, $01, $DC ; CLV CMP CPX CPY DEC DEX DEY EOR
    .byte $D8, $01, $01, $40, $40, $DC, $6C, $DC ; INC INX INY JMP JSR LDA LDX LDY
    .byte $DA, $01, $DC, $01, $01, $01, $01, $DA ; LSR NOP ORA PHA PHP PLA PLP ROL
    .byte $DA, $01, $01, $DC, $01, $01, $01, $D8 ; ROR RTI RTS SBC SEC SED SEI STA
    .byte $68, $58, $01, $01, $01, $01, $01, $01 ; STX STY TAX TAY TSX TXA TXS TYA
opcodeMaskLoEnd:

opcodeMaskHi:
    .byte $0D, $0D, $00, $10, $10, $10, $00, $10 ; ADC AND ASL BCC BCS BEQ BIT BMI
    .byte $10, $10, $00, $10, $10, $00, $00, $00 ; BNE BPL BRK BVC BVS CLC CLD CLI
    .byte $00, $0D, $00, $00, $00, $00, $00, $0D ; CLV CMP CPX CPY DEC DEX DEY EOR
    .byte $00, $00, $00, $02, $00, $0D, $01, $00 ; INC INX INY JMP JSR LDA LDX LDY
    .byte $00, $00, $0D, $00, $00, $00, $00, $00 ; LSR NOP ORA PHA PHP PLA PLP ROL
    .byte $00, $00, $00, $0D, $00, $00, $00, $0D ; ROR RTI RTS SBC SEC SED SEI STA
    .byte $00, $00, $00, $00, $00, $00, $00, $00 ; STX STY TAX TAY TSX TXA TXS TYA
opcodeMaskHiEnd:

; Start offset of each mnemonic's opcode run within opcodeBytes.
opcodeRunOffset:
    .byte 0,   8,   16,  21,  22,  23,  24,  26  ; ADC AND ASL BCC BCS BEQ BIT BMI
    .byte 27,  28,  29,  30,  31,  32,  33,  34  ; BNE BPL BRK BVC BVS CLC CLD CLI
    .byte 35,  36,  44,  47,  50,  54,  55,  56  ; CLV CMP CPX CPY DEC DEX DEY EOR
    .byte 64,  68,  69,  70,  72,  73,  81,  86  ; INC INX INY JMP JSR LDA LDX LDY
    .byte 91,  96,  97,  105, 106, 107, 108, 109 ; LSR NOP ORA PHA PHP PLA PLP ROL
    .byte 114, 119, 120, 121, 129, 130, 131, 132 ; ROR RTI RTS SBC SEC SED SEI STA
    .byte 139, 142, 145, 146, 147, 148, 149, 150 ; STX STY TAX TAY TSX TXA TXS TYA
opcodeRunOffsetEnd:

; Packed opcodes, grouped by mnemonic, ordered by ascending CASM_MODE_* bit.
opcodeBytes:
    .byte $69, $65, $75, $6D, $7D, $79, $61, $71 ; ADC (imm zp zpx abs absx absy indX indY)
    .byte $29, $25, $35, $2D, $3D, $39, $21, $31 ; AND
    .byte $0A, $06, $16, $0E, $1E                ; ASL (accum zp zpx abs absx)
    .byte $90                                    ; BCC (rel)
    .byte $B0                                    ; BCS
    .byte $F0                                    ; BEQ
    .byte $24, $2C                               ; BIT (zp abs)
    .byte $30                                    ; BMI
    .byte $D0                                    ; BNE
    .byte $10                                    ; BPL
    .byte $00                                    ; BRK (implied)
    .byte $50                                    ; BVC
    .byte $70                                    ; BVS
    .byte $18                                    ; CLC
    .byte $D8                                    ; CLD
    .byte $58                                    ; CLI
    .byte $B8                                    ; CLV
    .byte $C9, $C5, $D5, $CD, $DD, $D9, $C1, $D1 ; CMP
    .byte $E0, $E4, $EC                          ; CPX (imm zp abs)
    .byte $C0, $C4, $CC                          ; CPY
    .byte $C6, $D6, $CE, $DE                     ; DEC (zp zpx abs absx)
    .byte $CA                                    ; DEX
    .byte $88                                    ; DEY
    .byte $49, $45, $55, $4D, $5D, $59, $41, $51 ; EOR
    .byte $E6, $F6, $EE, $FE                     ; INC
    .byte $E8                                    ; INX
    .byte $C8                                    ; INY
    .byte $4C, $6C                               ; JMP (abs indirect)
    .byte $20                                    ; JSR (abs)
    .byte $A9, $A5, $B5, $AD, $BD, $B9, $A1, $B1 ; LDA
    .byte $A2, $A6, $B6, $AE, $BE                ; LDX (imm zp zpy abs absy)
    .byte $A0, $A4, $B4, $AC, $BC                ; LDY (imm zp zpx abs absx)
    .byte $4A, $46, $56, $4E, $5E                ; LSR (accum zp zpx abs absx)
    .byte $EA                                    ; NOP
    .byte $09, $05, $15, $0D, $1D, $19, $01, $11 ; ORA
    .byte $48                                    ; PHA
    .byte $08                                    ; PHP
    .byte $68                                    ; PLA
    .byte $28                                    ; PLP
    .byte $2A, $26, $36, $2E, $3E                ; ROL (accum zp zpx abs absx)
    .byte $6A, $66, $76, $6E, $7E                ; ROR
    .byte $40                                    ; RTI
    .byte $60                                    ; RTS
    .byte $E9, $E5, $F5, $ED, $FD, $F9, $E1, $F1 ; SBC
    .byte $38                                    ; SEC
    .byte $F8                                    ; SED
    .byte $78                                    ; SEI
    .byte $85, $95, $8D, $9D, $99, $81, $91      ; STA (zp zpx abs absx absy indX indY)
    .byte $86, $96, $8E                          ; STX (zp zpy abs)
    .byte $84, $94, $8C                          ; STY (zp zpx abs)
    .byte $AA                                    ; TAX
    .byte $A8                                    ; TAY
    .byte $BA                                    ; TSX
    .byte $8A                                    ; TXA
    .byte $9A                                    ; TXS
    .byte $98                                    ; TYA
opcodeBytesEnd:

; Total instruction length per resolved mode, indexed by CASM_MODE_*.
modeLength:
    .byte 1, 1, 2, 2, 2, 2, 3, 3, 3, 3, 2, 2, 2
modeLengthEnd:

.assert opcodeMaskLoEnd - opcodeMaskLo = CASM_MNEMONIC_COUNT, error, "opcode mask-low table must have 56 entries"
.assert opcodeMaskHiEnd - opcodeMaskHi = CASM_MNEMONIC_COUNT, error, "opcode mask-high table must have 56 entries"
.assert opcodeRunOffsetEnd - opcodeRunOffset = CASM_MNEMONIC_COUNT, error, "opcode run-offset table must have 56 entries"
.assert opcodeBytesEnd - opcodeBytes = 151, error, "packed opcode table must be 151 legal opcodes"
.assert modeLengthEnd - modeLength = CASM_MODE_COUNT, error, "mode length table must have 13 entries"
