; src/external/casm/expr.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Bounded Phase 5 expression result storage and its initialization/accessor
; surface. Parsing, arithmetic, resolution, and extraction begin in later work
; packages.

.include "common.inc"

.export exprInit
.export exprGetResult

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

.segment "BSS"

CasmExprResultRecord:
    .res CASM_EXPR_REC_SIZE
CasmExprResultRecordEnd:

.assert CasmExprResultRecordEnd - CasmExprResultRecord = CASM_EXPR_REC_SIZE, error, "CASM expression result record size changed"
