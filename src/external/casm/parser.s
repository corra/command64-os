; src/external/casm/parser.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 4 WP11 statement parser. Consumes tokens one at a time from the
; lexer's single-token buffer, validates the restricted LL(1) statement
; grammar, converts numeric literals to 16-bit values, and reports syntax
; diagnostics. This module allocates and exports the persistent
; CasmParserStmt record; later Phase 4 work packages consume it to match
; addressing modes and emit code.
;
; Labels and symbols are out of scope: a statement beginning with IDENTIFIER
; is rejected with CASM_DIAG_SYNTAX_ERROR in this phase.

.include "common.inc"

.import lexerNext
.import CasmTokenRecord
.import CasmTokenText

.export CasmParserStmt
.export parserParseStatement
.export parseNumericValue

.segment "BSS"

; Persistent statement record consumed by the downstream addressing-mode
; matcher and emission engine.
CasmParserStmt:
    .res CASM_PARSER_STMT_SIZE

; Private 24-bit numeric accumulator. The extra Ext byte and the sticky
; Overflow flag detect any value exceeding 65535 regardless of how many
; digits follow; Overflow is monotonic within one parseNumericValue call.
CasmParserValueLo:  .res 1
CasmParserValueHi:  .res 1
CasmParserValueExt: .res 1
CasmParserOverflow: .res 1
CasmParserTempLo:   .res 1
CasmParserTempHi:   .res 1
CasmParserTempExt:  .res 1

.segment "CODE"

; ---------------------------------------------------------------------------
; parserParseStatement
; Parse exactly one statement from the lexer's token stream into
; CasmParserStmt. NEWLINE and EOF are valid empty statements. A statement
; beginning with IDENTIFIER (labels/symbols) or any other unexpected token is
; rejected with CASM_DIAG_SYNTAX_ERROR.
;
; Inputs:    lexer READY or EOF
; Outputs:   Success: C clear, A = CasmParserStmt.Type; statement populated
;            Fail:    C set, A = CASM_DIAG_* (propagated lexer/source
;                     diagnostic, CASM_DIAG_SYNTAX_ERROR,
;                     CASM_DIAG_EXPECTED_NEWLINE, or
;                     CASM_DIAG_OPERAND_OUT_OF_RANGE)
; Preserves: none
; Clobbers:  A, X, Y, CasmParser* scratch, lexer/source volatile state
; ---------------------------------------------------------------------------
parserParseStatement:
    jsr lexerNext
    bcs ppsFail

    cmp #CASM_TOKEN_EOF
    beq ppsEmpty
    cmp #CASM_TOKEN_NEWLINE
    beq ppsEmpty
    cmp #CASM_TOKEN_MNEMONIC
    beq ppsMnemonic
    cmp #CASM_TOKEN_DIRECTIVE
    beq ppsMnemonic
    jmp ppsSyntaxError

ppsEmpty:
    sta CasmParserStmt + CASM_PARSER_STMT_TYPE
    lda #CASM_SUBTYPE_NONE
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    sta CasmParserStmt + CASM_PARSER_STMT_REG_SUBTYPE
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    clc
    rts

ppsMnemonic:
    sta CasmParserStmt + CASM_PARSER_STMT_TYPE
    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    lda #0
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    sta CasmParserStmt + CASM_PARSER_STMT_REG_SUBTYPE
    ; The .BYTE/.WORD directives take a comma-separated numeric list that the
    ; single-operand addressing-mode grammar below cannot express. Return after
    ; classifying the directive and leave its operand tokens in the lexer stream
    ; for the WP13 emission engine to read and emit (parser contract refinement).
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    cmp #CASM_TOKEN_DIRECTIVE
    bne ppsGrammar
    lda CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    cmp #CASM_DIRECTIVE_BYTE
    beq ppsDeferOperands
    cmp #CASM_DIRECTIVE_WORD
    beq ppsDeferOperands
ppsGrammar:
    jmp parseOperandSequence
ppsDeferOperands:
    lda #CASM_OPKIND_IMPLIED
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    clc
    rts

ppsFail:
    rts

ppsSyntaxError:
    lda #CASM_DIAG_SYNTAX_ERROR
    sec
    rts

; ---------------------------------------------------------------------------
; parseOperandSequence (private)
; Parse the operand grammar following a consumed MNEMONIC or DIRECTIVE token,
; populate OpKind/ValLo/ValHi/RegSubtype, and consume through the statement's
; terminating NEWLINE or EOF token.
;
; Outputs: C clear, A = CasmParserStmt.Type on success; C set, A = CASM_DIAG_*
;          on failure
; ---------------------------------------------------------------------------
parseOperandSequence:
    jsr lexerNext
    bcc @ok1
    rts
@ok1:

    cmp #CASM_TOKEN_NEWLINE
    beq posImplied
    cmp #CASM_TOKEN_EOF
    beq posImplied
    cmp #CASM_TOKEN_HASH
    beq posImmediateJmp
    cmp #CASM_TOKEN_NUMBER
    beq posAbsoluteJmp
    cmp #CASM_TOKEN_REGISTER
    beq posAccumulatorJmp
    cmp #CASM_TOKEN_LPAREN
    beq posIndirectJmp
    jmp posSyntaxError

posImmediateJmp:
    jmp posImmediate
posAbsoluteJmp:
    jmp posAbsolute
posAccumulatorJmp:
    jmp posAccumulator
posIndirectJmp:
    jmp posIndirect

posImplied:
    lda #CASM_OPKIND_IMPLIED
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    jmp posDone

posImmediate:
    jsr lexerNext
    bcc @ok1
    rts
@ok1:
    cmp #CASM_TOKEN_NUMBER
    beq posImmediateNumber
    jmp posSyntaxError
posImmediateNumber:
    jsr parseNumericValue
    bcc @ok1
    rts
@ok1:
    lda #CASM_OPKIND_IMMEDIATE
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    jmp posExpectTerminator

posAbsolute:
    jsr parseNumericValue
    bcc @ok1
    rts
@ok1:
    jsr lexerNext
    bcc @ok2
    rts
@ok2:
    cmp #CASM_TOKEN_NEWLINE
    beq posAbsoluteDone
    cmp #CASM_TOKEN_EOF
    beq posAbsoluteDone
    cmp #CASM_TOKEN_COMMA
    beq posAbsoluteIndexed
    jmp posSyntaxError
posAbsoluteDone:
    lda #CASM_OPKIND_ABSOLUTE
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    jmp posDone
posAbsoluteIndexed:
    jsr lexerNext
    bcc @ok1
    rts
@ok1:
    cmp #CASM_TOKEN_REGISTER
    beq posAbsoluteIndexedReg
    jmp posSyntaxError
posAbsoluteIndexedReg:
    ldy CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    cpy #CASM_REGISTER_X
    beq posAbsoluteX
    cpy #CASM_REGISTER_Y
    beq posAbsoluteY
    jmp posSyntaxError
posAbsoluteX:
    lda #CASM_OPKIND_ABSOLUTE_X
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    lda #CASM_REGISTER_X
    sta CasmParserStmt + CASM_PARSER_STMT_REG_SUBTYPE
    jmp posExpectTerminator
posAbsoluteY:
    lda #CASM_OPKIND_ABSOLUTE_Y
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    lda #CASM_REGISTER_Y
    sta CasmParserStmt + CASM_PARSER_STMT_REG_SUBTYPE
    jmp posExpectTerminator

posAccumulator:
    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    cmp #CASM_REGISTER_A
    beq posAccumulatorOk
    jmp posSyntaxError
posAccumulatorOk:
    lda #CASM_OPKIND_ACCUMULATOR
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    lda #CASM_REGISTER_A
    sta CasmParserStmt + CASM_PARSER_STMT_REG_SUBTYPE
    jmp posExpectTerminator

posIndirect:
    jsr lexerNext
    bcc @ok1
    rts
@ok1:
    cmp #CASM_TOKEN_NUMBER
    beq posIndirectNumber
    jmp posSyntaxError
posIndirectNumber:
    jsr parseNumericValue
    bcc @ok1
    rts
@ok1:
    jsr lexerNext
    bcc @ok2
    rts
@ok2:
    cmp #CASM_TOKEN_RPAREN
    beq posIndirectClose
    cmp #CASM_TOKEN_COMMA
    beq posIndexedIndirect
    jmp posSyntaxError

posIndirectClose:
    jsr lexerNext
    bcc @ok1
    rts
@ok1:
    cmp #CASM_TOKEN_NEWLINE
    beq posIndirectPlain
    cmp #CASM_TOKEN_EOF
    beq posIndirectPlain
    cmp #CASM_TOKEN_COMMA
    beq posIndirectIndexedY
    jmp posSyntaxError
posIndirectPlain:
    lda #CASM_OPKIND_INDIRECT
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    jmp posDone
posIndirectIndexedY:
    jsr lexerNext
    bcc @ok1
    rts
@ok1:
    cmp #CASM_TOKEN_REGISTER
    beq posIndirectIndexedYReg
    jmp posSyntaxError
posIndirectIndexedYReg:
    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    cmp #CASM_REGISTER_Y
    beq posIndirectIndexedYOk
    jmp posSyntaxError
posIndirectIndexedYOk:
    lda #CASM_OPKIND_INDIRECT_INDEXED
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    lda #CASM_REGISTER_Y
    sta CasmParserStmt + CASM_PARSER_STMT_REG_SUBTYPE
    jmp posExpectTerminator

posIndexedIndirect:
    jsr lexerNext
    bcc @ok1
    rts
@ok1:
    cmp #CASM_TOKEN_REGISTER
    beq posIndexedIndirectReg
    jmp posSyntaxError
posIndexedIndirectReg:
    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    cmp #CASM_REGISTER_X
    beq posIndexedIndirectRparen
    jmp posSyntaxError
posIndexedIndirectRparen:
    jsr lexerNext
    bcc @ok1
    rts
@ok1:
    cmp #CASM_TOKEN_RPAREN
    beq posIndexedIndirectOk
    jmp posSyntaxError
posIndexedIndirectOk:
    lda #CASM_OPKIND_INDEXED_INDIRECT
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    lda #CASM_REGISTER_X
    sta CasmParserStmt + CASM_PARSER_STMT_REG_SUBTYPE
    jmp posExpectTerminator

posExpectTerminator:
    jsr lexerNext
    bcc @ok1
    rts
@ok1:
    cmp #CASM_TOKEN_NEWLINE
    beq posDone
    cmp #CASM_TOKEN_EOF
    beq posDone
    lda #CASM_DIAG_EXPECTED_NEWLINE
    sec
    rts

posDone:
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    clc
    rts

posSyntaxError:
    lda #CASM_DIAG_SYNTAX_ERROR
    sec
    rts

; ---------------------------------------------------------------------------
; parseNumericValue (private)
; Convert the current NUMBER token's text into a 16-bit value stored in
; CasmParserStmt.ValLo/ValHi. Hexadecimal and binary tokens carry their '$'
; or '%' prefix as the first text byte and are skipped; decimal tokens have
; no prefix. Values exceeding 65535 are rejected regardless of how many
; further digits follow.
;
; Inputs:    CasmTokenRecord/CasmTokenText hold a NUMBER token
; Outputs:   C clear on success, ValLo/ValHi stored; C set with
;            A = CASM_DIAG_OPERAND_OUT_OF_RANGE on overflow
; Clobbers:  A, X, Y, CasmParser* scratch
; ---------------------------------------------------------------------------
parseNumericValue:
    lda #0
    sta CasmParserValueLo
    sta CasmParserValueHi
    sta CasmParserValueExt
    sta CasmParserOverflow

    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    cmp #CASM_NUMBER_DECIMAL
    beq pnvDecimalStart
    cmp #CASM_NUMBER_HEX
    beq pnvHexStart
    ldy #1
    jmp pnvBinLoop
pnvHexStart:
    ldy #1
    jmp pnvHexLoop
pnvDecimalStart:
    ldy #0
    jmp pnvDecLoop

pnvDecLoop:
    cpy CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    beq pnvDone
    lda CasmTokenText, y
    sec
    sbc #CASM_PETSCII_DIGIT_0
    tax
    jsr pnvMul10
    jsr pnvAddDigit
    iny
    jmp pnvDecLoop

pnvHexLoop:
    cpy CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    beq pnvDone
    lda CasmTokenText, y
    jsr pnvHexDigitValue
    jsr pnvMul16
    jsr pnvAddDigit
    iny
    jmp pnvHexLoop

pnvBinLoop:
    cpy CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    beq pnvDone
    lda CasmTokenText, y
    sec
    sbc #CASM_PETSCII_DIGIT_0
    tax
    jsr pnvMul2
    jsr pnvAddDigit
    iny
    jmp pnvBinLoop

pnvDone:
    lda CasmParserOverflow
    beq pnvStore
    lda #CASM_DIAG_OPERAND_OUT_OF_RANGE
    sec
    rts
pnvStore:
    lda CasmParserValueLo
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    lda CasmParserValueHi
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    clc
    rts

; ---------------------------------------------------------------------------
; pnvHexDigitValue (private)
; Inputs:  A = PETSCII hex digit character
; Outputs: X = digit value 0-15
; Clobbers: A
; ---------------------------------------------------------------------------
pnvHexDigitValue:
    cmp #CASM_PETSCII_DIGIT_0
    bcc pnvhLetter
    cmp #CASM_PETSCII_DIGIT_9 + 1
    bcs pnvhLetter
    sec
    sbc #CASM_PETSCII_DIGIT_0
    tax
    rts
pnvhLetter:
    jsr normalizeHexChar
    sec
    sbc #CASM_PETSCII_UPPER_A
    clc
    adc #10
    tax
    rts

; ---------------------------------------------------------------------------
; normalizeHexChar (private)
; Fold a shifted-uppercase PETSCII letter ($C1-$DA) to its unshifted form.
; Inputs/Outputs: A
; ---------------------------------------------------------------------------
normalizeHexChar:
    cmp #CASM_PETSCII_SHIFTED_A
    bcc nhcDone
    cmp #CASM_PETSCII_SHIFTED_Z + 1
    bcs nhcDone
    and #$7F
nhcDone:
    rts

; ---------------------------------------------------------------------------
; pnvMul2 (private) - 24-bit accumulator *= 2. Sets CasmParserOverflow sticky
; when the extra byte becomes nonzero.
; ---------------------------------------------------------------------------
pnvMul2:
    asl CasmParserValueLo
    rol CasmParserValueHi
    rol CasmParserValueExt
    lda CasmParserValueExt
    beq pnvMul2Done
    lda #1
    sta CasmParserOverflow
pnvMul2Done:
    rts

; ---------------------------------------------------------------------------
; pnvMul16 (private) - 24-bit accumulator *= 16 (four left shifts).
; ---------------------------------------------------------------------------
pnvMul16:
    asl CasmParserValueLo
    rol CasmParserValueHi
    rol CasmParserValueExt
    asl CasmParserValueLo
    rol CasmParserValueHi
    rol CasmParserValueExt
    asl CasmParserValueLo
    rol CasmParserValueHi
    rol CasmParserValueExt
    asl CasmParserValueLo
    rol CasmParserValueHi
    rol CasmParserValueExt
    lda CasmParserValueExt
    beq pnvMul16Done
    lda #1
    sta CasmParserOverflow
pnvMul16Done:
    rts

; ---------------------------------------------------------------------------
; pnvMul10 (private) - 24-bit accumulator *= 10, computed as
; (accumulator * 8) + (accumulator * 2) using CasmParserTemp* as scratch.
; ---------------------------------------------------------------------------
pnvMul10:
    lda CasmParserValueLo
    sta CasmParserTempLo
    lda CasmParserValueHi
    sta CasmParserTempHi
    lda CasmParserValueExt
    sta CasmParserTempExt

    asl CasmParserValueLo
    rol CasmParserValueHi
    rol CasmParserValueExt
    asl CasmParserValueLo
    rol CasmParserValueHi
    rol CasmParserValueExt
    asl CasmParserValueLo
    rol CasmParserValueHi
    rol CasmParserValueExt

    asl CasmParserTempLo
    rol CasmParserTempHi
    rol CasmParserTempExt

    clc
    lda CasmParserValueLo
    adc CasmParserTempLo
    sta CasmParserValueLo
    lda CasmParserValueHi
    adc CasmParserTempHi
    sta CasmParserValueHi
    lda CasmParserValueExt
    adc CasmParserTempExt
    sta CasmParserValueExt

    lda CasmParserValueExt
    beq pnvMul10Done
    lda #1
    sta CasmParserOverflow
pnvMul10Done:
    rts

; ---------------------------------------------------------------------------
; pnvAddDigit (private) - accumulator += X (digit value 0-15).
; ---------------------------------------------------------------------------
pnvAddDigit:
    clc
    txa
    adc CasmParserValueLo
    sta CasmParserValueLo
    lda CasmParserValueHi
    adc #0
    sta CasmParserValueHi
    lda CasmParserValueExt
    adc #0
    sta CasmParserValueExt
    beq pnvAddDigitDone
    lda #1
    sta CasmParserOverflow
pnvAddDigitDone:
    rts
