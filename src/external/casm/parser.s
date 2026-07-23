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
; WP28 (Phase 6B): a statement beginning with IDENTIFIER is a label
; definition (IDENTIFIER COLON) -- see ppsLabel. parserParseExpressionValue
; binds symbolsLookup as the production identifier resolver and is
; pass-mode-aware via CasmPassMode.

.include "common.inc"

.import lexerNext
.import CasmTokenRecord
.import CasmTokenText
.import exprEvaluate
.import exprGetResult
.import CasmPassMode
.import symbolsLookup

; WP15 diagnostic context.
.import diagSetLocFromToken
.import diagStampStmtLoc

.export CasmParserStmt
.export parserParseStatement
.export parserParseExpressionValue
.export CasmLabelName
.export CasmLabelNameLen

.segment "BSS"

; Persistent statement record consumed by the downstream addressing-mode
; matcher and emission engine.
CasmParserStmt:
    .res CASM_PARSER_STMT_SIZE

; WP28: a label statement's name and length, staged here for the Pass 1
; driver (the future casm_pass1 test harness; casm.s's own two-pass
; orchestration in WP29) to read and pass to symbolsInsert along with the
; current CasmPc. parser.s does not import CasmPc or symbolsInsert and never
; calls symbolsInsert itself -- defining a symbol is a semantic action that
; stays the driver's responsibility; this module remains a pure grammar
; module. Sized to match CASM_TOKEN_TEXT_BUFFER_SIZE (31 usable bytes + a
; terminator byte that is never written here, kept only for the size match).
CasmLabelName:    .res 32
CasmLabelNameLen: .res 1

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
    cmp #CASM_TOKEN_IDENTIFIER
    beq ppsLabel
    jmp ppsSyntaxError

ppsEmpty:
    sta CasmParserStmt + CASM_PARSER_STMT_TYPE
    lda #CASM_SUBTYPE_NONE
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    sta CasmParserStmt + CASM_PARSER_STMT_REG_SUBTYPE
    sta CasmParserStmt + CASM_PARSER_STMT_FLAGS
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
    sta CasmParserStmt + CASM_PARSER_STMT_FLAGS
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
; ppsLabel (private)
; Parse a label-definition statement: IDENTIFIER COLON. The current token is
; the already-consumed IDENTIFIER (CasmTokenRecord/CasmTokenText describe it).
; Its name and length are copied into the persistent CasmLabelName/
; CasmLabelNameLen buffer *before* calling lexerNext again, since lexerNext
; overwrites CasmTokenText unconditionally on every call -- if this copy ran
; after requiring COLON, the label's own name would already be destroyed.
; Populates CasmParserStmt as a CASM_TOKEN_IDENTIFIER statement with all
; other fields zeroed; does not itself advance CasmPc or insert any symbol --
; the caller (the future Pass 1 driver) reads CasmLabelName/CasmLabelNameLen
; and CasmPc and calls symbolsInsert; this module never calls symbolsInsert.
;
; Inputs:    current token is the just-consumed IDENTIFIER
; Outputs:   success: C clear, A = CASM_TOKEN_IDENTIFIER, CasmParserStmt and
;                      CasmLabelName/CasmLabelNameLen populated, COLON consumed
;            failure: C set, A = CASM_DIAG_SYNTAX_ERROR (or a propagated
;                      lexer/source diagnostic)
; Clobbers:  A, X, Y, CasmParserStmt, CasmLabelName, CasmLabelNameLen
; ---------------------------------------------------------------------------
ppsLabel:
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    sta CasmLabelNameLen
    ldy #0
@copyLoop:
    cpy CasmLabelNameLen
    beq @copyDone
    lda CasmTokenText, y
    sta CasmLabelName, y
    iny
    jmp @copyLoop
@copyDone:

    ; Require and consume COLON.
    jsr lexerNext
    bcc @ok1
    rts
@ok1:
    cmp #CASM_TOKEN_COLON
    beq @colonOk
    jsr diagSetLocFromToken     ; the token that should have been a colon
    lda #CASM_DIAG_SYNTAX_ERROR
    sec
    rts
@colonOk:
    lda #CASM_TOKEN_IDENTIFIER
    sta CasmParserStmt + CASM_PARSER_STMT_TYPE
    lda #CASM_SUBTYPE_NONE
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    sta CasmParserStmt + CASM_PARSER_STMT_REG_SUBTYPE
    sta CasmParserStmt + CASM_PARSER_STMT_FLAGS
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    clc
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
    cmp #CASM_TOKEN_IDENTIFIER
    beq posAbsoluteJmp
    cmp #CASM_TOKEN_LESS
    beq posAbsoluteJmp
    cmp #CASM_TOKEN_GREATER
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
    cmp #CASM_TOKEN_IDENTIFIER
    beq posImmediateNumber
    cmp #CASM_TOKEN_LESS
    beq posImmediateNumber
    cmp #CASM_TOKEN_GREATER
    beq posImmediateNumber
    jmp posSyntaxError
posImmediateNumber:
    jsr parserParseExpressionValue
    bcc @ok1
    rts
@ok1:
    lda #CASM_OPKIND_IMMEDIATE
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    jmp posValidateTerminator

posAbsolute:
    jsr parserParseExpressionValue
    bcc @ok1
    rts
@ok1:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
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
    cmp #CASM_TOKEN_IDENTIFIER
    beq posIndirectNumber
    cmp #CASM_TOKEN_LESS
    beq posIndirectNumber
    cmp #CASM_TOKEN_GREATER
    beq posIndirectNumber
    jmp posSyntaxError
posIndirectNumber:
    jsr parserParseExpressionValue
    bcc @ok1
    rts
@ok1:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
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
posValidateTerminator:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
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
; parserParseExpressionValue
; Adapt the current Phase 5 expression into the Phase 4 statement value fields.
; Binds symbolsLookup as the production resolver (WP28) and is pass-mode-aware
; via CasmPassMode: in CASM_PASS_MODE_MEASURE an unresolved identifier is
; tolerated (a zero placeholder is stored, never emitted); in
; CASM_PASS_MODE_EMIT it is a hard CASM_DIAG_UNDEFINED_SYMBOL failure.
;
; CASM_PARSER_STMT_FORCE_ABS (CASM_PARSER_STMT_FLAGS bit 0) is derived from
; the expression result's CASM_EXPR_FLAG_SYMBOL_DERIVED bit -- set the moment
; ANY resolver call succeeds with C clear, whether or not the symbol actually
; resolved -- and NOT from CASM_EXPR_FLAG_FORCE_ABS (set only on the
; unresolved sub-path). Any operand derived from a symbol reference at all
; must force absolute width unconditionally: otherwise a resolved backward
; reference with a small value (e.g. a label under $100 defined earlier in
; the same pass) could disagree in size with an unresolved forward reference
; to that same label processed in a different pass, corrupting every
; following address (the exact Pass 1/Pass 2 mismatch risk the master plan
; warns about).
;
; Inputs:    current token begins expression; D clear
; Outputs:   success: ValLo/ValHi stored, Flags' FORCE_ABS bit set correctly,
;                      following delimiter current, C clear
;            failure: A = stable diagnostic, C set, statement value invalid
; Preserves: V, D, I, balanced stack, resources and emitter state
; Clobbers:  A, X, Y, N, Z, C, CasmPtr0, lexer/evaluator scratch and result
; ---------------------------------------------------------------------------
parserParseExpressionValue:
    ; Preserve the expression start for post-evaluation width checks such as
    ; .BYTE $100; exprEvaluate may leave NEWLINE/COMMA current on success.
    jsr diagSetLocFromToken
    ldx #<symbolsLookup
    ldy #>symbolsLookup
    jsr exprEvaluate
    bcs pevReturn
    jsr exprGetResult
    stx CasmPtr0Lo
    sty CasmPtr0Hi

    ; Derive FORCE_ABS from SYMBOL_DERIVED unconditionally, before the
    ; RESOLVED check below, since it must apply on both the resolved and
    ; unresolved sub-paths.
    ldy #CASM_EXPR_FLAGS
    lda (CasmPtr0Lo), y
    and #CASM_EXPR_FLAG_SYMBOL_DERIVED
    beq pevNotForceAbs
    lda #CASM_PARSER_STMT_FORCE_ABS
    jmp pevStoreForceAbs
pevNotForceAbs:
    lda #0
pevStoreForceAbs:
    sta CasmParserStmt + CASM_PARSER_STMT_FLAGS

    ldy #CASM_EXPR_FLAGS
    lda (CasmPtr0Lo), y
    and #CASM_EXPR_FLAG_RESOLVED
    beq pevUnresolved
    ldy #CASM_EXPR_VAL_LO
    lda (CasmPtr0Lo), y
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    iny
    lda (CasmPtr0Lo), y
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    clc
pevReturn:
    rts

pevUnresolved:
    lda CasmPassMode
    cmp #CASM_PASS_MODE_MEASURE
    beq pevMeasureUnresolved
    lda #CASM_DIAG_UNDEFINED_SYMBOL
    sec
    rts
pevMeasureUnresolved:
    lda #0
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    clc
    rts
