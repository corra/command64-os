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
.import lexerScanIncludeOperand
.import lexerScanIncbinOperand
.import CasmStringLength
.import CasmStringBuffer
.import CasmTokenRecord
.import CasmTokenText
.import CasmTokenStartOffsetLo
.import CasmTokenStartOffsetHi
.import exprEvaluate
.import exprGetResult
.import CasmExprPrimaryWasLocal
.import exprParseNumeric
.import exprParseAddend
.import exprApplyAddend
.import CasmPassMode
.import symbolsLookup

; WP39: emitMarkStarted and CasmRelocatableMode are emit.s-owned state this
; module already has a read precedent for (CasmPassMode, above).
; parserParseExpressionValue commits the relocatable/static mode decision
; (skipped for .ORG's own operand) before every symbol reference is
; classified, closing an ordering hazard emitInstruction/emitByteList/
; emitWordList/crpLabel's own commit calls cannot reach on their own -- see
; brain/plans/2026-07-24-casm-phase8-wp39-relocation-classification.md.
.import emitMarkStarted
.import CasmRelocatableMode

; WP15 diagnostic context.
.import diagSetLocFromToken
.import diagStampStmtLoc

.export CasmParserStmt
.export parserParseStatement
.export parserParseExpressionValue
.export CasmLabelName
.export CasmLabelNameLen
.export CasmIncludeFilename
.export CasmIncludeFilenameLen
.export CasmIncbinFilename
.export CasmIncbinFilenameLen
.export CasmConstantResolved
.export CasmConstantValueLo
.export CasmConstantValueHi
.export CasmConstantRefVmmLo
.export CasmConstantRefVmmHi
.export CasmConstantRefLen
.export CasmConstantRefAddendSign
.export CasmConstantRefAddendLo
.export CasmConstantRefAddendHi
.export CasmConstantRefExtract
.export CasmConstantIsCurAddr
.export CasmLabelDefinedAtOffsetLo
.export CasmLabelDefinedAtOffsetHi
.export CasmFillCountLo
.export CasmFillCountHi
.export CasmFillValue
.export CasmAssertValueLo
.export CasmAssertValueHi
.export CasmAssertMessage
.export CasmAssertMessageLen

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

; WP76: the just-consumed IDENTIFIER's own source position, stamped by
; ppsLabel below from CasmTokenStartOffsetLo/Hi (lexer.s) before any further
; token is read -- same "copy before it's overwritten" reasoning as
; CasmLabelName itself, immediately above. Meaningful for a constant
; definition only (crpConstant, casm.s, copies it into the symbol record);
; a label statement leaves it populated but unused, harmless since labels
; stay unconditionally force-abs regardless (WP39).
CasmLabelDefinedAtOffsetLo: .res 1
CasmLabelDefinedAtOffsetHi: .res 1

; WP65: ppsConstant's own staged output for casm.s's crpConstant, mirroring
; CasmLabelName/CasmLabelNameLen's precedent exactly -- a named constant's
; own name reuses CasmLabelName/CasmLabelNameLen directly (a statement is
; never simultaneously a label and a constant, so the buffer is never
; needed for both at once). Resolved=1 means ValueLo/Hi already holds the
; final value (a numeric RHS); Resolved=0 means the Ref* fields describe a
; deferred reference for the resolution sweep to resolve later (an
; identifier RHS) -- these map directly onto symbols.s's
; CasmSymbolInsertFlags/CasmSymbolInsertRef* inputs.
CasmConstantResolved:      .res 1
CasmConstantValueLo:       .res 1
CasmConstantValueHi:       .res 1
CasmConstantRefVmmLo:      .res 1
CasmConstantRefVmmHi:      .res 1
CasmConstantRefLen:        .res 1
CasmConstantRefAddendSign: .res 1
CasmConstantRefAddendLo:   .res 1
CasmConstantRefAddendHi:   .res 1
CasmConstantRefExtract:    .res 1
; WP66: set only by ppsConstant's '*'-RHS arm (never by the numeric or
; identifier arms). '*' RHS reuses the identifier arm's own deferred-
; addend/extraction staging shape (CasmConstantRef{AddendSign,AddendLo,
; AddendHi,Extract}; CasmConstantRefVmmLo/Hi/Len stay zero -- there is no
; name to look up), but unlike an identifier's forward reference, its base
; value (CasmPc) is already known the instant crpConstant (casm.s) runs --
; no Pass1->Pass2 resolution-sweep involvement needed. crpConstant computes
; CasmPc [+/- addend][extraction] itself when this flag is set, then ORs
; CASM_SYMBOL_FLAG_LABEL_DERIVED into the inserted symbol's flags alongside
; RESOLVED: '*' resolves immediately (like a numeric RHS, never label-
; derived) but is relocatable-by-construction (like a label), so it needs
; both bits together -- a combination no other RHS kind produces.
CasmConstantIsCurAddr:     .res 1

; WP44: .INCLUDE filenames exceed the frozen 31-byte token payload. Keep the
; original PETSCII bytes in parser-owned bounded state for the later semantic
; include work packages; the scanner appends a null for diagnostic/file APIs.
CasmIncludeFilename:    .res CASM_INCLUDE_FILENAME_BUFFER_SIZE
CasmIncludeFilenameLen: .res 1
CasmIncludeFilenameEnd:

.assert CasmIncludeFilenameLen - CasmIncludeFilename = CASM_INCLUDE_FILENAME_BUFFER_SIZE, error, "CASM include filename buffer layout changed"
.assert CasmIncludeFilenameEnd - CasmIncludeFilename = CASM_INCLUDE_FILENAME_BUFFER_SIZE + 1, error, "CASM include filename state must be exactly CASM_INCLUDE_FILENAME_BUFFER_SIZE + 1 bytes"

; WP82: .INCBIN's own filename state, mirroring CasmIncludeFilename/Len's
; own precedent exactly (same 65-byte shape, same buffer size constant --
; the grammar is byte-identical, only the diagnostic identity differs,
; per this WP's own Scoping Decision 1).
CasmIncbinFilename:    .res CASM_INCLUDE_FILENAME_BUFFER_SIZE
CasmIncbinFilenameLen: .res 1
CasmIncbinFilenameEnd:

.assert CasmIncbinFilenameLen - CasmIncbinFilename = CASM_INCLUDE_FILENAME_BUFFER_SIZE, error, "CASM incbin filename buffer layout changed"
.assert CasmIncbinFilenameEnd - CasmIncbinFilename = CASM_INCLUDE_FILENAME_BUFFER_SIZE + 1, error, "CASM incbin filename state must be exactly CASM_INCLUDE_FILENAME_BUFFER_SIZE + 1 bytes"

; WP81: ppsFillDirective's own staged output for emit.s's emitRes/emitFill/
; emitAlign, mirroring CasmLabelName/CasmConstant*'s precedent of dedicated
; parser-owned scratch rather than reusing CasmParserStmt.Val* -- that field
; is clobbered by the *second* parserParseExpressionValue call (the value/
; fill operand), which would otherwise overwrite the already-resolved count/
; boundary from the first call.
CasmFillCountLo: .res 1
CasmFillCountHi: .res 1
CasmFillValue:   .res 1

; WP83: ppsAssert's own staged output for emit.s's emitAssert. The resolved
; expression value gets dedicated scratch for the same reason WP81's
; CasmFillCountLo/Hi/CasmFillValue does (CasmParserStmt.Val* would already
; be gone by the time emitAssert runs, once ppsAssert's own subsequent
; token-consuming calls -- the comma/message lookahead -- overwrite it). The
; message is copied here immediately from the lexer's shared
; CasmStringBuffer (Scoping Decision 5: no dedicated scanner, just the
; existing lnString/CASM_TOKEN_STRING tokenizer) rather than read from that
; shared scratch later, since nothing guarantees it survives untouched
; between ppsAssert's return and emitAssert's own call.
CasmAssertValueLo:    .res 1
CasmAssertValueHi:    .res 1
CasmAssertMessage:    .res CASM_ASSERT_MESSAGE_BUFFER_SIZE
CasmAssertMessageLen: .res 1
CasmAssertMessageEnd:

.assert CasmAssertMessageLen - CasmAssertMessage = CASM_ASSERT_MESSAGE_BUFFER_SIZE, error, "CASM assert message buffer layout changed"
.assert CasmAssertMessageEnd - CasmAssertMessage = CASM_ASSERT_MESSAGE_BUFFER_SIZE + 1, error, "CASM assert message state must be exactly 65 bytes"

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
    bcc :+
    jmp ppsFail
:

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
    beq ppsLabelDispatch
    jmp ppsSyntaxError
ppsLabelDispatch:
    jmp ppsLabel

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
    cmp #CASM_DIRECTIVE_INCLUDE
    beq ppsInclude
    cmp #CASM_DIRECTIVE_BYTE
    beq ppsDeferOperands
    cmp #CASM_DIRECTIVE_WORD
    beq ppsDeferOperands
    cmp #CASM_DIRECTIVE_RES
    beq ppsFillDirectiveDispatch
    cmp #CASM_DIRECTIVE_FILL
    beq ppsFillDirectiveDispatch
    cmp #CASM_DIRECTIVE_ALIGN
    beq ppsFillDirectiveDispatch
    cmp #CASM_DIRECTIVE_INCBIN
    beq ppsIncbinDispatch
    cmp #CASM_DIRECTIVE_ASSERT
    beq ppsAssertDispatch
ppsGrammar:
    jmp parseOperandSequence
ppsFillDirectiveDispatch:
    jmp ppsFillDirective
ppsIncbinDispatch:
    jmp ppsIncbin
ppsAssertDispatch:
    jmp ppsAssert
ppsDeferOperands:
    lda #CASM_OPKIND_IMPLIED
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    clc
    rts

ppsInclude:
    ; The dedicated scanner consumes the complete quoted operand and trailer,
    ; leaving NEWLINE/EOF buffered. Include semantics remain the pass driver's
    ; responsibility; this parser path performs no file or emitter operation.
    jsr lexerScanIncludeOperand
    bcs ppsFail
    lda #CASM_OPKIND_IMPLIED
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    clc
    rts

; ---------------------------------------------------------------------------
; ppsIncbin (WP82)
; Parse .INCBIN's quoted-filename operand via the dedicated
; lexerScanIncbinOperand (own diagnostic identity, Scoping Decision 1).
; Performs no file I/O itself -- that is emit.s's emitIncbin's job, same
; separation ppsInclude keeps from the real include semantics.
;
; Inputs:    current token is the .INCBIN DIRECTIVE, just classified by
;            ppsMnemonic
; Outputs:   success: C clear, A = CasmParserStmt.Type, CasmIncbinFilename/
;                     Len populated, terminator consumed
;            failure: C set, A = CASM_DIAG_INCBIN_FILENAME_EXPECTED/
;                     CASM_DIAG_INVALID_INCBIN_FILENAME/
;                     CASM_DIAG_INCBIN_FILENAME_TOO_LONG/
;                     CASM_DIAG_EXPECTED_NEWLINE
; ---------------------------------------------------------------------------
ppsIncbin:
    jsr lexerScanIncbinOperand
    bcs ppsFail
    lda #CASM_OPKIND_IMPLIED
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    clc
    rts

ppsFail:
    rts

; ---------------------------------------------------------------------------
; ppsFillDirective (WP81)
; Parse .RES/.FILL/.ALIGN's shared grammar: `expr [',' expr]`. Both operands
; use the full existing expression grammar (parserParseExpressionValue --
; named constants, '*', parens, operators; whatever the shared evaluator
; already accepts). Unlike an ordinary instruction operand, both must fully
; resolve *in this pass* (Scoping Decision 1, brain/plans/2026-08-21-casm-
; phase13-wp81-res-fill-align.md) -- a forward reference is a diagnostic
; error here, not a tolerated Pass-1 placeholder, since a .RES count feeds
; directly into byte length rather than an addressing-mode width decision
; that stays pass-invariant regardless of value.
;
; CasmParserStmt.Subtype (CASM_DIRECTIVE_RES/FILL/ALIGN) is already staged by
; ppsMnemonic before this routine is dispatched.
;
; Inputs:    current token begins the first (count/boundary) expression
; Outputs:   success: C clear, A = CasmParserStmt.Type, CasmFillCountLo/Hi =
;                      resolved count/boundary, CasmFillValue = resolved
;                      value/fill byte (0 default for .RES/.ALIGN),
;                      terminator consumed
;            failure: C set, A = CASM_DIAG_RES_FILL_ALIGN_UNRESOLVED,
;                      CASM_DIAG_FILL_VALUE_REQUIRED,
;                      CASM_DIAG_VALUE_OUT_OF_RANGE, CASM_DIAG_SYNTAX_ERROR,
;                      or a propagated expression diagnostic
; Clobbers:  A, X, Y, CasmParserStmt.Val*/Flags, CasmFillCountLo/Hi,
;            CasmFillValue, expression module's private result record
; ---------------------------------------------------------------------------
ppsFillDirective:
    ; Consume the DIRECTIVE token itself and fetch the first operand token --
    ; the current token on entry is still .RES/.FILL/.ALIGN (ppsMnemonic's own
    ; lexerNext fetched it, not this routine's), same opening move as
    ; parseOperandSequence's own first line. Missing this, caught live: an
    ; earlier revision called parserParseExpressionValue directly against the
    ; still-current DIRECTIVE token, which exprEvaluate's parsePrimary cannot
    ; recognize, producing a spurious CASM_DIAG_EXPR_MALFORMED at column 1
    ; instead of ever reaching the real operand.
    jsr lexerNext
    bcc @haveToken
    rts
@haveToken:
    jsr parserParseExpressionValue
    bcc @haveCount
    rts
@haveCount:
    jsr exprGetResult
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldy #CASM_EXPR_FLAGS
    lda (CasmPtr0Lo), y
    and #CASM_EXPR_FLAG_RESOLVED
    bne @countResolved
    lda #CASM_DIAG_RES_FILL_ALIGN_UNRESOLVED
    sec
    rts
@countResolved:
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    sta CasmFillCountLo
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    sta CasmFillCountHi
    lda #0
    sta CasmFillValue
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_COMMA
    beq @haveComma
    lda CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    cmp #CASM_DIRECTIVE_FILL
    bne @requireTerminator
    jsr diagSetLocFromToken     ; missing-value position (NEWLINE/EOF/junk)
    lda #CASM_DIAG_FILL_VALUE_REQUIRED
    sec
    rts
@haveComma:
    jsr lexerNext                ; consume ',', fetch the value/fill expr
    bcc @ok2
    rts
@ok2:
    jsr parserParseExpressionValue
    bcc @haveValue
    rts
@haveValue:
    jsr exprGetResult
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldy #CASM_EXPR_FLAGS
    lda (CasmPtr0Lo), y
    and #CASM_EXPR_FLAG_RESOLVED
    bne @valueResolved
    lda #CASM_DIAG_RES_FILL_ALIGN_UNRESOLVED
    sec
    rts
@valueResolved:
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    beq @valueRangeOk
    ; parserParseExpressionValue preserved the expression-start location
    ; before advancing to this operand's own delimiter (same precedent as
    ; emit.s's emitByteList/eblRange).
    lda #CASM_DIAG_VALUE_OUT_OF_RANGE
    sec
    rts
@valueRangeOk:
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    sta CasmFillValue
@requireTerminator:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_NEWLINE
    beq @terminatorOk
    cmp #CASM_TOKEN_EOF
    beq @terminatorOk
    jsr diagSetLocFromToken     ; the unexpected trailing token
    lda #CASM_DIAG_SYNTAX_ERROR
    sec
    rts
@terminatorOk:
    lda #CASM_OPKIND_IMPLIED
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    clc
    rts

; ---------------------------------------------------------------------------
; ppsAssert (WP83)
; Parse .ASSERT's grammar: `expr [',' STRING]`. The expression uses the
; full existing expression grammar (parserParseExpressionValue) and must
; fully resolve *in this pass* -- a forward reference is a diagnostic
; error, not a tolerated Pass-1 placeholder, same convention WP81
; established for .RES/.FILL/.ALIGN's count/boundary operand (Scoping
; Decision 1, brain/plans/2026-08-21-casm-phase13-wp83-assert.md).
;
; The optional message is scanned by an ordinary lexerNext call after the
; comma, which lands on the lexer's existing lnString/CASM_TOKEN_STRING
; tokenizer (WP74's `.BYTE "string"` support) -- no dedicated scanner
; (Scoping Decision 5). Its bytes are copied into CasmAssertMessage
; immediately, since CasmStringBuffer is shared scratch not guaranteed to
; survive until emit.s's emitAssert runs.
;
; CasmParserStmt.Subtype (CASM_DIRECTIVE_ASSERT) is already staged by
; ppsMnemonic before this routine is dispatched.
;
; Inputs:    current token begins the assert expression
; Outputs:   success: C clear, A = CasmParserStmt.Type, CasmAssertValueLo/Hi
;                      = resolved expression value, CasmAssertMessageLen = 0
;                      (no message given) or 1-63 with CasmAssertMessage
;                      populated, terminator consumed
;            failure: C set, A = CASM_DIAG_ASSERT_UNRESOLVED,
;                      CASM_DIAG_ASSERT_MESSAGE_TOO_LONG,
;                      CASM_DIAG_SYNTAX_ERROR, or a propagated
;                      expression/string diagnostic
; Clobbers:  A, X, Y, CasmParserStmt.Val*/Flags, CasmAssertValueLo/Hi,
;            CasmAssertMessage/Len, expression module's private result
;            record
; ---------------------------------------------------------------------------
ppsAssert:
    jsr lexerNext
    bcc @haveToken
    rts
@haveToken:
    jsr parserParseExpressionValue
    bcc @haveExpr
    rts
@haveExpr:
    jsr exprGetResult
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldy #CASM_EXPR_FLAGS
    lda (CasmPtr0Lo), y
    and #CASM_EXPR_FLAG_RESOLVED
    bne @exprResolved
    lda #CASM_DIAG_ASSERT_UNRESOLVED
    sec
    rts
@exprResolved:
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    sta CasmAssertValueLo
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    sta CasmAssertValueHi
    lda #0
    sta CasmAssertMessageLen
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_COMMA
    beq @haveComma
    jmp @requireTerminator
@haveComma:
    jsr lexerNext                ; consume ',', fetch the message token
    bcc @ok2
    rts
@ok2:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_STRING
    beq @haveMessage
    jsr diagSetLocFromToken     ; the token that should have been a string
    lda #CASM_DIAG_SYNTAX_ERROR
    sec
    rts
@haveMessage:
    lda CasmStringLength
    cmp #CASM_ASSERT_MESSAGE_MAX + 1
    bcc @messageLenOk
    jsr diagSetLocFromToken
    lda #CASM_DIAG_ASSERT_MESSAGE_TOO_LONG
    sec
    rts
@messageLenOk:
    sta CasmAssertMessageLen
    ldy #0
@copyLoop:
    cpy CasmAssertMessageLen
    beq @copyTerminate
    lda CasmStringBuffer, y
    sta CasmAssertMessage, y
    iny
    jmp @copyLoop
@copyTerminate:
    lda #0
    sta CasmAssertMessage, y      ; null-terminate for diagPrintString (emit.s)
@copyDone:
    jsr lexerNext                ; consume the STRING token, fetch terminator
    bcc @requireTerminator
    rts
@requireTerminator:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_NEWLINE
    beq @terminatorOk
    cmp #CASM_TOKEN_EOF
    beq @terminatorOk
    jsr diagSetLocFromToken     ; the unexpected trailing token
    lda #CASM_DIAG_SYNTAX_ERROR
    sec
    rts
@terminatorOk:
    lda #CASM_OPKIND_IMPLIED
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    clc
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
; WP65: the token after the copied identifier now also accepts EQUALS (a
; named-constant definition, `identifier = expr`) alongside the original
; COLON (a label). Position alone disambiguates -- no lookahead beyond the
; one token this routine already required. See ppsConstant below for the
; EQUALS branch's own grammar and outputs.
;
; Inputs:    current token is the just-consumed IDENTIFIER
; Outputs:   success (label): C clear, A = CASM_TOKEN_IDENTIFIER,
;                      CasmParserStmt and CasmLabelName/CasmLabelNameLen
;                      populated, COLON consumed
;            success (constant): see ppsConstant
;            failure: C set, A = CASM_DIAG_SYNTAX_ERROR (or a propagated
;                      lexer/source diagnostic)
; Clobbers:  A, X, Y, CasmParserStmt, CasmLabelName, CasmLabelNameLen
; ---------------------------------------------------------------------------
ppsLabel:
    lda CasmTokenStartOffsetLo
    sta CasmLabelDefinedAtOffsetLo
    lda CasmTokenStartOffsetHi
    sta CasmLabelDefinedAtOffsetHi

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

    ; Require and consume COLON or EQUALS.
    jsr lexerNext
    bcc @ok1
    rts
@ok1:
    cmp #CASM_TOKEN_COLON
    beq @colonOk
    cmp #CASM_TOKEN_EQUALS
    beq @equalsSeen
    jsr diagSetLocFromToken     ; the token that should have been a colon
    lda #CASM_DIAG_SYNTAX_ERROR
    sec
    rts
@equalsSeen:
    ; WP89: a `@local` name may not be the LHS of a named-constant
    ; definition (`@x = expr`). Phase 14 forbids locals anywhere in the
    ; constant deferred-reference machinery -- see the plan's Research
    ; item 7. CasmLabelName still holds the just-copied identifier.
    lda CasmLabelName
    cmp #CASM_PETSCII_AT
    bne ppsConstant
    jsr diagSetLocFromToken
    lda #CASM_DIAG_LOCAL_IN_CONSTANT
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
; ppsConstant (WP65)
; Parse a named-constant definition's RHS: `['<'|'>'] (NUMBER|IDENTIFIER)
; [('+'|'-') NUMBER]` -- today's existing bounded expression grammar,
; exactly as WP64's contract froze it (no parentheses, no new operators).
; A NUMBER (or NUMBER extraction/addend) RHS is fully resolvable now, since
; it depends on nothing else; its final value is computed here directly. An
; IDENTIFIER RHS may forward-reference a symbol not yet defined (another
; constant later in the source, or a label whose address isn't final until
; Pass 1 completes), so it is never resolved here -- only its own defining
; reference is captured (name length + the absolute source-position
; bookmark CasmTokenStartOffsetLo/Hi already stamps on every token, plus
; the addend/extraction) for casm.s's Pass1->Pass2 resolution sweep to
; resolve later. See brain/plans/2026-08-13-casm-phase12-wp65-named-
; constants.md's Technical Design section.
;
; This routine does not call symbolsInsert (same separation ppsLabel keeps
; from crpLabel): it stages CasmConstant* fields for casm.s's own
; crpConstant to read and act on.
;
; Inputs:    current token is EQUALS, just matched by ppsLabel above;
;            CasmLabelName/CasmLabelNameLen already hold the constant's own
;            name (copied before the COLON/EQUALS lookahead, same as a
;            label's)
; Outputs:   success: C clear, A = CASM_TOKEN_EQUALS, CasmParserStmt
;                      populated (Type = CASM_TOKEN_EQUALS, all other
;                      fields zeroed -- a constant carries no addressing-
;                      mode/emission payload of its own), CasmConstant*
;                      populated, terminator (NEWLINE/EOF) consumed
;            failure: C set, A = CASM_DIAG_* (CASM_DIAG_EXPR_MALFORMED for
;                      an unrecognized primary, CASM_DIAG_EXPR_UNSUPPORTED
;                      for a trailing token the grammar can't consume,
;                      CASM_DIAG_EXPECTED_NEWLINE for anything else before
;                      the terminator, CASM_DIAG_OPERAND_OUT_OF_RANGE on
;                      numeric overflow, or a propagated lexer/source
;                      diagnostic)
; Clobbers:  A, X, Y, CasmParserStmt, CasmConstant*, expression module's
;            private result record and numeric scratch
; ---------------------------------------------------------------------------
ppsConstant:
    ; Determinism: zero every staged field before parsing rather than
    ; relying solely on CasmConstantResolved to gate their use -- no stale
    ; bytes from a previous constant's parse survive into this one's
    ; record, matching this project's existing determinism conventions.
    ; Load-bearing, not just cosmetic: symbolsInsert copies the Ref* fields
    ; into the record's reserved-padding span (common.inc) for ANY
    ; constant, including a numeric RHS that never touches them again --
    ; map.s's mapValidateRecord requires that whole span zero-filled, so a
    ; numeric constant's Ref* fields must already be clean here, not just
    ; unused.
    lda #0
    sta CasmConstantValueLo
    sta CasmConstantValueHi
    sta CasmConstantRefVmmLo
    sta CasmConstantRefVmmHi
    sta CasmConstantRefLen
    sta CasmConstantRefAddendSign
    sta CasmConstantRefAddendLo
    sta CasmConstantRefAddendHi
    sta CasmConstantIsCurAddr
    jsr lexerNext               ; consume '=', fetch the RHS's first token
    bcc @haveFirst
    rts
@haveFirst:
    lda #CASM_EXTRACTION_FULL
    sta CasmConstantRefExtract
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_LESS
    beq @lowPrefix
    cmp #CASM_TOKEN_GREATER
    bne @primary
    lda #CASM_EXTRACTION_HI
    sta CasmConstantRefExtract
    jmp @consumePrefix
@lowPrefix:
    lda #CASM_EXTRACTION_LO
    sta CasmConstantRefExtract
@consumePrefix:
    jsr lexerNext
    bcc @primary
    rts

@primary:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_NUMBER
    beq @numeric
    cmp #CASM_TOKEN_IDENTIFIER
    beq @identifier
    cmp #CASM_TOKEN_STAR
    bne @notCurAddr
    jmp @curAddr
@notCurAddr:
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_MALFORMED
    sec
    rts

@numeric:
    jsr exprParseNumeric        ; X/Y = value; token remains current (NUMBER)
    stx CasmConstantValueLo
    sty CasmConstantValueHi
    jsr lexerNext                ; advance past NUMBER
    bcc @numericAddend
    rts
@numericAddend:
    ; exprParseAddend always safely zeroes the addend when no +/- is
    ; present (and leaves the token untouched in that case), so it is
    ; called unconditionally -- but on the sign-present path it leaves the
    ; addend NUMBER itself as the current token (exprParseNumeric's own
    ; "token remains current" contract), so an explicit extra lexerNext is
    ; still needed to advance past it there, exactly mirroring expr.s's own
    ; consumeIdentifier/consumeAddend sequence (expr.s:191-193), not
    ; assumed from exprParseAddend's name.
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_PLUS
    beq @numericAddendSign
    cmp #CASM_TOKEN_MINUS
    beq @numericAddendSign
    jsr exprParseAddend
    bcc @numericApply
    rts
@numericAddendSign:
    jsr exprParseAddend
    bcc @numericAddendConsume
    rts
@numericAddendConsume:
    jsr lexerNext                ; advance past the addend NUMBER
    bcc @numericApply
    rts
@numericApply:
    ldx CasmConstantValueLo
    ldy CasmConstantValueHi
    jsr exprApplyAddend           ; X/Y = value + addend, checked
    bcc @numericApplied
    rts
@numericApplied:
    stx CasmConstantValueLo
    sty CasmConstantValueHi
    lda CasmConstantRefExtract
    beq @numericTerminator        ; FULL: nothing to apply
    cmp #CASM_EXTRACTION_LO
    beq @numericClearHigh
    lda CasmConstantValueHi        ; HI: move high byte down
    sta CasmConstantValueLo
@numericClearHigh:
    lda #0
    sta CasmConstantValueHi
@numericTerminator:
    ; Already applied above -- clear so the resolved record's reserved
    ; padding stays zero-filled (see this proc's own top-of-routine note).
    lda #0
    sta CasmConstantRefExtract
    lda #1
    sta CasmConstantResolved
    jmp @requireTerminator

@identifier:
    ; WP89: a `@local` name may not be a named-constant RHS operand
    ; either (`y = @x`). CasmTokenText still holds the identifier here.
    lda CasmTokenText
    cmp #CASM_PETSCII_AT
    bne @identifierNotLocal
    jsr diagSetLocFromToken
    lda #CASM_DIAG_LOCAL_IN_CONSTANT
    sec
    rts
@identifierNotLocal:
    ; Capture length and start-offset while the token is still IDENTIFIER --
    ; the very next lexerNext overwrites CasmTokenText, exactly the hazard
    ; exprEvaluate's own identifier branch already documents (expr.s).
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    sta CasmConstantRefLen
    lda CasmTokenStartOffsetLo
    sta CasmConstantRefVmmLo
    lda CasmTokenStartOffsetHi
    sta CasmConstantRefVmmHi
    jsr lexerNext                 ; consume the identifier
    bcc @identifierAddend
    rts
@identifierAddend:
    ; Same two-step as @numericAddend above: exprParseAddend is always
    ; called (safely zeroes the addend when absent), but a sign-present
    ; result leaves the addend NUMBER itself as the current token, needing
    ; one more explicit lexerNext -- expr.s's own consumeIdentifier does
    ; this same extra advance (expr.s:191-193) after its own call.
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_PLUS
    beq @identifierAddendSign
    cmp #CASM_TOKEN_MINUS
    beq @identifierAddendSign
    jsr exprParseAddend
    bcc @identifierStore
    rts
@identifierAddendSign:
    jsr exprParseAddend
    bcc @identifierAddendConsume
    rts
@identifierAddendConsume:
    jsr lexerNext                 ; advance past the addend NUMBER
    bcc @identifierStore
    rts
@identifierStore:
    ; CasmExprResultRecord is expr.s's own private BSS, never exported by
    ; name -- exprGetResult is the only sanctioned accessor (mirrors how
    ; every other expr.s consumer reaches it).
    jsr exprGetResult
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldy #CASM_EXPR_ADDEND_SIGN
    lda (CasmPtr0Lo), y
    sta CasmConstantRefAddendSign
    ldy #CASM_EXPR_ADDEND_MAG_LO
    lda (CasmPtr0Lo), y
    sta CasmConstantRefAddendLo
    ldy #CASM_EXPR_ADDEND_MAG_HI
    lda (CasmPtr0Lo), y
    sta CasmConstantRefAddendHi
    lda #0
    sta CasmConstantResolved
    jmp @requireTerminator

; WP66: '*' RHS. Reuses @identifierAddend's own addend-capture tail
; verbatim (same exprParseAddend/exprGetResult sequence, staging into the
; same CasmConstantRefAddendSign/Lo/Hi fields) -- the only difference from
; @identifier is that there is no name to capture (CasmConstantRefVmmLo/
; Hi/Len stay at their top-of-routine zero) and CasmConstantIsCurAddr is
; set instead of leaving CasmConstantResolved clear, telling crpConstant
; (casm.s) to compute CasmPc [+/- addend][extraction] itself rather than
; deferring to the Pass1->Pass2 resolution sweep.
@curAddr:
    jsr lexerNext                 ; consume '*'
    bcc @curAddrAddend
    rts
@curAddrAddend:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_PLUS
    beq @curAddrAddendSign
    cmp #CASM_TOKEN_MINUS
    beq @curAddrAddendSign
    jsr exprParseAddend
    bcc @curAddrStore
    rts
@curAddrAddendSign:
    jsr exprParseAddend
    bcc @curAddrAddendConsume
    rts
@curAddrAddendConsume:
    jsr lexerNext                 ; advance past the addend NUMBER
    bcc @curAddrStore
    rts
@curAddrStore:
    jsr exprGetResult
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldy #CASM_EXPR_ADDEND_SIGN
    lda (CasmPtr0Lo), y
    sta CasmConstantRefAddendSign
    ldy #CASM_EXPR_ADDEND_MAG_LO
    lda (CasmPtr0Lo), y
    sta CasmConstantRefAddendLo
    ldy #CASM_EXPR_ADDEND_MAG_HI
    lda (CasmPtr0Lo), y
    sta CasmConstantRefAddendHi
    lda #1
    sta CasmConstantIsCurAddr
    jmp @requireTerminator

@requireTerminator:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_NEWLINE
    beq @terminatorOk
    cmp #CASM_TOKEN_EOF
    beq @terminatorOk
    jsr diagSetLocFromToken
    cmp #CASM_TOKEN_PLUS
    beq @unsupported
    cmp #CASM_TOKEN_MINUS
    beq @unsupported
    cmp #CASM_TOKEN_LESS
    beq @unsupported
    cmp #CASM_TOKEN_GREATER
    beq @unsupported
    cmp #CASM_TOKEN_NUMBER
    beq @unsupported
    cmp #CASM_TOKEN_IDENTIFIER
    beq @unsupported
    lda #CASM_DIAG_EXPECTED_NEWLINE
    sec
    rts
@unsupported:
    lda #CASM_DIAG_EXPR_UNSUPPORTED
    sec
    rts
@terminatorOk:
    lda #CASM_TOKEN_EQUALS
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
    ; WP68 Increment 7: current-address (WP66, pre-existing gap) and unary
    ; '-'/'~' (this WP) can all start a non-immediate operand expression
    ; ("LDA *", "LDA -1", "LDA ~1") -- without these, exprEvaluate's own
    ; parsePrimary (which already handles all three) is never reached at
    ; all, rejected here first as CASM_DIAG_SYNTAX_ERROR. Same class of gap
    ; WP67 fixed for a leading '(' in posImmediate's own whitelist below.
    cmp #CASM_TOKEN_STAR
    beq posAbsoluteJmp
    cmp #CASM_TOKEN_MINUS
    beq posAbsoluteJmp
    cmp #CASM_TOKEN_TILDE
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
    ; WP67: '(' after '#' is a parenthesized sub-expression (e.g.
    ; `lda #(1+2)`), not indirect addressing -- that ambiguity is already
    ; resolved one token earlier, since no 6502 indirect-addressing form
    ; begins with '#'. Without this, exprEvaluate's own parsePrimary
    ; (which does correctly accept '(' here) is never reached at all --
    ; this whitelist gate runs first and would otherwise reject it as
    ; CASM_DIAG_SYNTAX_ERROR before parserParseExpressionValue is even
    ; called.
    cmp #CASM_TOKEN_LPAREN
    beq posImmediateNumber
    ; WP68 Increment 7: same class of gap as '(' immediately above, for
    ; current-address (WP66, pre-existing gap) and unary '-'/'~' (this WP)
    ; as the first token after '#' (e.g. `lda #*`, `lda #-1`, `lda #~1`).
    cmp #CASM_TOKEN_STAR
    beq posImmediateNumber
    cmp #CASM_TOKEN_MINUS
    beq posImmediateNumber
    cmp #CASM_TOKEN_TILDE
    beq posImmediateNumber
    ; WP69: a character literal is a direct 8-bit value, never a general
    ; expression primary (this WP's own scoping decision) -- short-circuits
    ; straight to CasmTokenText[0], bypassing parserParseExpressionValue/
    ; exprEvaluate entirely, so expr.s needs no change for this feature.
    cmp #CASM_TOKEN_CHAR
    beq posImmediateChar
    jmp posSyntaxError
posImmediateNumber:
    jsr parserParseExpressionValue
    bcc @ok1
    rts
@ok1:
    lda #CASM_OPKIND_IMMEDIATE
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    jmp posValidateTerminator
posImmediateChar:
    jsr emitMarkStarted
    bcc @ok1
    rts
@ok1:
    lda CasmTokenText
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    lda #0
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    sta CasmParserStmt + CASM_PARSER_STMT_FLAGS
    jsr lexerNext                ; advance past CHAR, leave delimiter current
    bcc @ok2
    rts
@ok2:
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
; WP39: CASM_PARSER_STMT_RELOCATABLE (bit 1) is derived the same way, from
; CASM_EXPR_FLAG_RELOCATABLE. Before evaluating the expression, this routine
; also commits the relocatable/static mode decision via emitMarkStarted
; (skipped for .ORG's own operand) and passes CasmRelocatableMode into
; exprEvaluate as an input, so the resolver-merge classification always
; sees a settled mode -- see emitMarkStarted's own header comment (emit.s)
; and brain/plans/2026-07-24-casm-phase8-wp39-relocation-classification.md.
;
; Inputs:    current token begins expression; D clear
; Outputs:   success: ValLo/ValHi stored, Flags' FORCE_ABS/RELOCATABLE bits
;                      set correctly, following delimiter current, C clear
;            failure: A = stable diagnostic, C set, statement value invalid
; Preserves: V, D, I, balanced stack, resources and emitter state
; Clobbers:  A, X, Y, N, Z, C, CasmPtr0, lexer/evaluator scratch and result
; ---------------------------------------------------------------------------
parserParseExpressionValue:
    ; Preserve the expression start for post-evaluation width checks such as
    ; .BYTE $100; exprEvaluate may leave NEWLINE/COMMA current on success.
    jsr diagSetLocFromToken

    ; WP39: commit the relocatable/static mode decision before this operand's
    ; expression is evaluated, closing an ordering hazard where a bare
    ; instruction's symbol operand (the very first statement of a no-.ORG
    ; source) would otherwise be classified before any of
    ; emitInstruction/emitByteList/emitWordList/crpLabel's own commit calls
    ; run -- parserParseStatement evaluates the operand inline, before
    ; casmRunPass ever dispatches to one of those. Skipped for .ORG's own
    ; operand: calling it here would write the default-origin header and
    ; lock CasmOutputStarted before emitOrg gets a chance to run, causing
    ; emitOrg to reject its own .ORG as a spurious duplicate.
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    cmp #CASM_TOKEN_DIRECTIVE
    bne pevMarkStarted
    lda CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    cmp #CASM_DIRECTIVE_ORG
    beq pevSkipMark
pevMarkStarted:
    jsr emitMarkStarted
    bcc pevSkipMark
    rts
pevSkipMark:

    ldx #<symbolsLookup
    ldy #>symbolsLookup
    lda CasmRelocatableMode
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

    ; WP39: derive RELOCATABLE the same way, from CASM_EXPR_FLAG_RELOCATABLE
    ; -- unconditionally alongside SYMBOL_DERIVED's own classification above,
    ; not gated on RESOLVED below, for the identical Pass 1/Pass 2 agreement
    ; reason. OR'd into the Flags byte just stored, not overwriting FORCE_ABS.
    ldy #CASM_EXPR_FLAGS
    lda (CasmPtr0Lo), y
    and #CASM_EXPR_FLAG_RELOCATABLE
    beq pevNotRelocatable
    lda CasmParserStmt + CASM_PARSER_STMT_FLAGS
    ora #CASM_PARSER_STMT_RELOCATABLE
    sta CasmParserStmt + CASM_PARSER_STMT_FLAGS
pevNotRelocatable:

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
    ; WP89: if the expression's identifier primary was a `@local` name,
    ; report the scoped diagnostic instead of the generic one. The
    ; bounded-expression grammar's addend is always numeric, so the single
    ; identifier primary is the only symbol reference that can be
    ; unresolved here; expr.s's own identifier: branch stamps the flag
    ; while CasmTokenText still holds that name.
    lda CasmExprPrimaryWasLocal
    beq pevUnresolvedGlobal
    lda #CASM_DIAG_UNDEFINED_LOCAL
    sec
    rts
pevUnresolvedGlobal:
    lda #CASM_DIAG_UNDEFINED_SYMBOL
    sec
    rts
pevMeasureUnresolved:
    lda #0
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    clc
    rts
