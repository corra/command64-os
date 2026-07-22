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

.assert CasmExprResultRecordEnd - CasmExprResultRecord = CASM_EXPR_REC_SIZE, error, "CASM expression result record size changed"
