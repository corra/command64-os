; src/external/casm/expr.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Bounded Phase 5 expression storage, numeric conversion, addend parsing, and
; checked arithmetic. Primary dispatch, resolution, and extraction begin in
; later work packages.

.include "common.inc"

.import lexerNext
.import CasmTokenRecord
.import CasmTokenText
.import diagSetLocFromToken

.export exprInit
.export exprGetResult
.export exprParseNumeric
.export exprParseAddend
.export exprCheckedAdd
.export exprCheckedSub
.export exprApplyAddend
.export exprEvaluate

.segment "CODE"

; ---------------------------------------------------------------------------
; exprInit
; Reset the private expression record to its empty, unresolved defaults.
;
; Inputs:    none
; Outputs:   A = 0, Z set, N clear; expression record cleared
; Preserves: X, Y, C, V, D, I, zero page, balanced stack
; Clobbers:  A, N, Z
; Scratch:   none
; ---------------------------------------------------------------------------
.proc exprInit
    lda #0
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
    sta CasmExprResultRecord + CASM_EXPR_EXTRACTION
    sta CasmExprResultRecord + CASM_EXPR_SYMBOL_ID_LO
    sta CasmExprResultRecord + CASM_EXPR_SYMBOL_ID_HI
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_SIGN
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_LO
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_HI
    rts
.endproc

; ---------------------------------------------------------------------------
; exprEvaluate
; Evaluate one Phase 5 expression through a caller-supplied symbol resolver.
;
; Inputs:    current token begins expression; X/Y = resolver address; D clear
; Outputs:   success: result record valid, first following token current, C clear
;            failure: A = stable diagnostic, result invalid, C set
; Preserves: V, D, I, zero page, balanced stack, parser/emitter/resources
; Clobbers:  A, X, Y, N, Z, C, lexer state, expression and private scratch BSS
; Resolver:  current token is IDENTIFIER; X/Y point to five-byte output view;
;            C clear accepts output, C set is reported as resolver failure
; ---------------------------------------------------------------------------
.proc exprEvaluate
    stx CasmExprResolverAddrLo
    sty CasmExprResolverAddrHi
    jsr exprInit

    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_LESS
    beq lowPrefix
    cmp #CASM_TOKEN_GREATER
    bne primary
    lda #CASM_EXTRACTION_HI
    bne storeExtraction
lowPrefix:
    lda #CASM_EXTRACTION_LO
storeExtraction:
    sta CasmExprResultRecord + CASM_EXPR_EXTRACTION
    jsr lexerNext
    bcs return

primary:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_NUMBER
    beq number
    cmp #CASM_TOKEN_IDENTIFIER
    beq identifier
malformed:
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_MALFORMED
    sec
return:
    rts

number:
    jsr exprParseNumeric
    bcs return
    stx CasmExprResultRecord + CASM_EXPR_VAL_LO
    sty CasmExprResultRecord + CASM_EXPR_VAL_HI
    lda #CASM_EXPR_FLAG_RESOLVED
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
    jsr lexerNext
    bcs return
    jsr rejectContinuation
    bcs return
    jmp applyExtraction

identifier:
    ; WP28: stage the resolver's name-pointer/length arguments. This is the
    ; only point in exprEvaluate's control flow that reliably has them: the
    ; current token is still IDENTIFIER here (consumeIdentifier's lexerNext,
    ; which would overwrite CasmTokenText, has not run yet), and A cannot be
    ; pre-staged by any caller further out since exprEvaluate's own entry
    ; dispatch (the </>/NUMBER/IDENTIFIER checks above) already clobbers A
    ; for its own purposes before this branch is even reached.
    lda #<CasmTokenText
    sta CasmPtr0Lo
    lda #>CasmTokenText
    sta CasmPtr0Hi
    ldx #<CasmExprResolverOutput
    ldy #>CasmExprResolverOutput
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    jsr callResolver
    bcc resolverReturned
    jmp resolverFailed
resolverReturned:
    lda CasmExprResolverOutput + CASM_RESOLVE_FLAGS
    and #($FF - CASM_RESOLVE_FLAG_MASK)
    beq resolverValid
    jmp resolverFailed
resolverValid:

    ldx CasmExprResolverOutput + CASM_RESOLVE_ID_LO
    stx CasmExprResultRecord + CASM_EXPR_SYMBOL_ID_LO
    ldy CasmExprResolverOutput + CASM_RESOLVE_ID_HI
    sty CasmExprResultRecord + CASM_EXPR_SYMBOL_ID_HI
    lda CasmExprResolverOutput + CASM_RESOLVE_FLAGS
    ora #CASM_EXPR_FLAG_SYMBOL_DERIVED
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    beq unresolved
    lda CasmExprResolverOutput + CASM_RESOLVE_VAL_LO
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
    lda CasmExprResolverOutput + CASM_RESOLVE_VAL_HI
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
    jmp consumeIdentifier
unresolved:
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    ora #CASM_EXPR_FLAG_FORCE_ABS
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
consumeIdentifier:
    jsr lexerNext
    bcs return

    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_PLUS
    beq addend
    cmp #CASM_TOKEN_MINUS
    bne symbolDone
addend:
    jsr exprParseAddend
    bcc :+
    jmp return
:
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    beq consumeAddend
    ldx CasmExprResultRecord + CASM_EXPR_VAL_LO
    ldy CasmExprResultRecord + CASM_EXPR_VAL_HI
    jsr exprApplyAddend
    bcc addendApplied
    jmp return
addendApplied:
    stx CasmExprResultRecord + CASM_EXPR_VAL_LO
    sty CasmExprResultRecord + CASM_EXPR_VAL_HI
consumeAddend:
    jsr lexerNext
    bcc symbolDone
    jmp return
symbolDone:
    jsr rejectContinuation
    bcc applyExtraction
    jmp return

applyExtraction:
    lda CasmExprResultRecord + CASM_EXPR_EXTRACTION
    beq success
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    beq classifyExtraction
    lda CasmExprResultRecord + CASM_EXPR_EXTRACTION
    cmp #CASM_EXTRACTION_LO
    beq clearHigh
    lda CasmExprResultRecord + CASM_EXPR_VAL_HI
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
clearHigh:
    lda #0
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
classifyExtraction:
    lda CasmExprResultRecord + CASM_EXPR_EXTRACTION
    cmp #CASM_EXTRACTION_LO
    bne success
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #($FF - CASM_EXPR_FLAG_RELOCATABLE)
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
success:
    clc
    rts

resolverFailed:
    jsr diagSetLocFromToken
    lda #CASM_DIAG_RESOLVER_FAILED
    sec
    rts
.endproc

; Reject only tokens that unambiguously continue the bounded expression. Other
; punctuation remains current for the future parser adapter.
.proc rejectContinuation
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_PLUS
    beq unsupported
    cmp #CASM_TOKEN_MINUS
    beq unsupported
    cmp #CASM_TOKEN_LESS
    beq unsupported
    cmp #CASM_TOKEN_GREATER
    beq unsupported
    cmp #CASM_TOKEN_NUMBER
    beq unsupported
    cmp #CASM_TOKEN_IDENTIFIER
    beq unsupported
    clc
    rts
unsupported:
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_UNSUPPORTED
    sec
    rts
.endproc

; 6502 has no indirect JSR. Push the synthetic return address in JSR order,
; then transfer through the callback pointer; resolver RTS returns at resume.
;
; WP28: A must survive this preamble -- the caller (exprEvaluate's identifier
; branch) sets A to the resolver's nameLen argument immediately before this
; call, but the return-address push below clobbers A twice before the actual
; indirect jump. Stash it in CasmExprScratch0 (private to this module, not
; live across any other call in this window) and restore it immediately
; before the jump, so the resolver receives the caller's A unchanged. X/Y
; need no such handling: this routine never touches them.
.proc callResolver
    sta CasmExprScratch0
    lda #>(resume - 1)
    pha
    lda #<(resume - 1)
    pha
    lda CasmExprScratch0
    jmp (CasmExprResolverAddrLo)
resume:
    rts
.endproc

; ---------------------------------------------------------------------------
; exprGetResult
; Return a stable pointer to the private expression result record.
;
; Inputs:    none
; Outputs:   X/Y = record address low/high; C clear; N/Z reflect Y
; Preserves: A, V, D, I, zero page, balanced stack
; Clobbers:  X, Y, N, Z, C
; Scratch:   none
; ---------------------------------------------------------------------------
.proc exprGetResult
    ldx #<CasmExprResultRecord
    ldy #>CasmExprResultRecord
    clc
    rts
.endproc

; ---------------------------------------------------------------------------
; exprParseNumeric
; Convert the current NUMBER token to an unsigned 16-bit value.
;
; Inputs:    current token is NUMBER; D clear (CASM application invariant)
; Outputs:   success: X/Y = value low/high, C clear, token remains current
;            failure: A = CASM_DIAG_OPERAND_OUT_OF_RANGE, C set, token location
; Preserves: V, D, I, balanced stack, lexer state, expression result record
; Clobbers:  A, X, Y, N, Z, C, private numeric scratch
; ---------------------------------------------------------------------------
.proc exprParseNumeric
    lda #0
    sta CasmExprValueLo
    sta CasmExprValueHi
    sta CasmExprValueExt
    sta CasmExprOverflow

    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    cmp #CASM_NUMBER_DECIMAL
    beq decimalStart
    cmp #CASM_NUMBER_HEX
    beq hexStart
    ldy #1
    jmp binaryLoop
hexStart:
    ldy #1
    jmp hexLoop
decimalStart:
    ldy #0

decimalLoop:
    cpy CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    beq done
    lda CasmTokenText, y
    sec
    sbc #CASM_PETSCII_DIGIT_0
    tax
    jsr multiply10
    jsr addDigit
    iny
    jmp decimalLoop

hexLoop:
    cpy CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    beq done
    lda CasmTokenText, y
    jsr hexDigitValue
    jsr multiply16
    jsr addDigit
    iny
    jmp hexLoop

binaryLoop:
    cpy CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    beq done
    lda CasmTokenText, y
    sec
    sbc #CASM_PETSCII_DIGIT_0
    tax
    jsr multiply2
    jsr addDigit
    iny
    jmp binaryLoop

done:
    lda CasmExprOverflow
    beq success
    jsr diagSetLocFromToken
    lda #CASM_DIAG_OPERAND_OUT_OF_RANGE
    sec
    rts
success:
    ldx CasmExprValueLo
    ldy CasmExprValueHi
    clc
    rts
.endproc

; A = PETSCII hex digit; returns X = 0..15.
.proc hexDigitValue
    cmp #CASM_PETSCII_DIGIT_0
    bcc letter
    cmp #CASM_PETSCII_DIGIT_9 + 1
    bcs letter
    sec
    sbc #CASM_PETSCII_DIGIT_0
    tax
    rts
letter:
    cmp #CASM_PETSCII_SHIFTED_A
    bcc normalized
    cmp #CASM_PETSCII_SHIFTED_Z + 1
    bcs normalized
    and #$7F
normalized:
    sec
    sbc #CASM_PETSCII_UPPER_A
    clc
    adc #10
    tax
    rts
.endproc

; Private 24-bit arithmetic keeps overflow sticky after the first high byte.
.proc multiply2
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    lda CasmExprValueExt
    beq return
    lda #1
    sta CasmExprOverflow
return:
    rts
.endproc

.proc multiply16
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    lda CasmExprValueExt
    beq return
    lda #1
    sta CasmExprOverflow
return:
    rts
.endproc

.proc multiply10
    lda CasmExprValueLo
    sta CasmExprTempLo
    lda CasmExprValueHi
    sta CasmExprTempHi
    lda CasmExprValueExt
    sta CasmExprTempExt

    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt

    asl CasmExprTempLo
    rol CasmExprTempHi
    rol CasmExprTempExt

    ; Keep this chain explicit: loop control would destroy inter-byte carry.
    clc
    lda CasmExprValueLo
    adc CasmExprTempLo
    sta CasmExprValueLo
    lda CasmExprValueHi
    adc CasmExprTempHi
    sta CasmExprValueHi
    lda CasmExprValueExt
    adc CasmExprTempExt
    sta CasmExprValueExt

    lda CasmExprValueExt
    beq return
    lda #1
    sta CasmExprOverflow
return:
    rts
.endproc

.proc addDigit
    clc
    txa
    adc CasmExprValueLo
    sta CasmExprValueLo
    lda CasmExprValueHi
    adc #0
    sta CasmExprValueHi
    lda CasmExprValueExt
    adc #0
    sta CasmExprValueExt
    beq return
    lda #1
    sta CasmExprOverflow
return:
    rts
.endproc

; ---------------------------------------------------------------------------
; exprParseAddend
; Parse optional +number/-number metadata. A parsed NUMBER remains current.
;
; Inputs:    current token follows primary; result record initialized; D clear
; Outputs:   success: sign/magnitude stored, C clear
;            failure: A = stable diagnostic, C set, result invalid
; Preserves: V, D, I, balanced stack
; Clobbers:  A, X, Y, N, Z, C, lexer state when operator present, numeric scratch
; ---------------------------------------------------------------------------
.proc exprParseAddend
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_PLUS
    beq positive
    cmp #CASM_TOKEN_MINUS
    beq negative

    lda #CASM_ADDEND_SIGN_POSITIVE
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_SIGN
    lda #0
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_LO
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_HI
    clc
    rts

positive:
    lda #CASM_ADDEND_SIGN_POSITIVE
    jmp storeSign
negative:
    lda #CASM_ADDEND_SIGN_NEGATIVE
storeSign:
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_SIGN
    jsr lexerNext
    bcs return
    cmp #CASM_TOKEN_NUMBER
    beq parseMagnitude
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_MALFORMED
    sec
    rts
parseMagnitude:
    jsr exprParseNumeric
    bcs return
    stx CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_LO
    sty CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_HI
    clc
return:
    rts
.endproc

; ---------------------------------------------------------------------------
; exprCheckedAdd / exprCheckedSub
; Apply the result record's unsigned magnitude to X/Y without wraparound.
; Input precondition: D clear (CASM application invariant).
; Success returns adjusted X/Y and C clear. Failure returns A = $26, C set;
; X/Y are unspecified. Result record and lexer state are preserved.
; ---------------------------------------------------------------------------
.proc exprCheckedAdd
    txa
    clc
    adc CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_LO
    tax
    tya
    adc CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_HI
    tay
    bcs overflow
    clc
    rts
overflow:
    lda #CASM_DIAG_EXPR_OVERFLOW
    sec
    rts
.endproc

.proc exprCheckedSub
    txa
    sec
    sbc CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_LO
    tax
    tya
    sbc CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_HI
    tay
    bcc underflow
    clc
    rts
underflow:
    lda #CASM_DIAG_EXPR_OVERFLOW
    sec
    rts
.endproc

; ---------------------------------------------------------------------------
; exprApplyAddend
; Dispatch checked arithmetic by sign and stamp the current magnitude token on
; overflow. Zero magnitude is a no-op for either sign. D must be clear.
; ---------------------------------------------------------------------------
.proc exprApplyAddend
    lda CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_LO
    ora CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_HI
    beq success
    lda CasmExprResultRecord + CASM_EXPR_ADDEND_SIGN
    cmp #CASM_ADDEND_SIGN_POSITIVE
    beq add
    jsr exprCheckedSub
    bcc success
    jmp failed
add:
    jsr exprCheckedAdd
    bcc success
failed:
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_OVERFLOW
    sec
    rts
success:
    clc
    rts
.endproc

.segment "BSS"

CasmExprResultRecord:
    .res CASM_EXPR_REC_SIZE
CasmExprResultRecordEnd:

; Private 24-bit numeric accumulator and temporary workspace.
CasmExprValueLo:  .res 1
CasmExprValueHi:  .res 1
CasmExprValueExt: .res 1
CasmExprOverflow: .res 1
CasmExprTempLo:   .res 1
CasmExprTempHi:   .res 1
CasmExprTempExt:  .res 1
CasmExprResolverAddrLo: .res 1
CasmExprResolverAddrHi: .res 1
CasmExprResolverOutput: .res CASM_RESOLVE_SIZE

.assert CasmExprResultRecordEnd - CasmExprResultRecord = CASM_EXPR_REC_SIZE, error, "CASM expression result record size changed"
.assert <CasmExprResolverAddrLo <> $FF, lderror, "CASM resolver callback pointer crosses an NMOS 6502 indirect-jump page"
