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
.import exprParseNumeric

; WP15 diagnostic context.
.import diagSetLocFromToken
.import diagStampStmtLoc

.export CasmParserStmt
.export parserParseStatement
.export parseNumericValue

.segment "BSS"

; Persistent statement record consumed by the downstream addressing-mode
; matcher and emission engine.
CasmParserStmt:
    .res CASM_PARSER_STMT_SIZE

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

    ; WP15: record where this statement began. The emission engine raises
    ; after the statement's tokens are consumed, by which point the token
    ; record points past the statement and only this still identifies it.
    pha
    jsr diagStampStmtLoc
    pla

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
    jsr diagSetLocFromToken     ; the token that cannot start a statement
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
    jsr diagSetLocFromToken     ; the token that should have been a newline
    lda #CASM_DIAG_EXPECTED_NEWLINE
    sec
    rts

posDone:
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    clc
    rts

posSyntaxError:
    jsr diagSetLocFromToken     ; the unexpected token
    lda #CASM_DIAG_SYNTAX_ERROR
    sec
    rts

; ---------------------------------------------------------------------------
; parseNumericValue
; Compatibility adapter for existing Phase 4 parser/emitter callers.
;
; Inputs:    CasmTokenRecord/CasmTokenText hold a NUMBER token
; Outputs:   C clear on success, ValLo/ValHi stored; C set with
;            A = CASM_DIAG_OPERAND_OUT_OF_RANGE on overflow
; Clobbers:  A, X, Y, expression numeric scratch
; ---------------------------------------------------------------------------
parseNumericValue:
    jsr exprParseNumeric
    bcs pnvReturn
    stx CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    sty CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    clc
pnvReturn:
    rts
