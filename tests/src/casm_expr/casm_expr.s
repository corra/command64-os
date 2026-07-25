; tests/src/casm_expr/casm_expr.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; Standalone CASM expression evaluator fixture harness.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_expr.inc"

.import __MAIN_START__
.import exprEvaluate
.import exprGetResult

.export lexerNext
.export diagSetLocFromToken
.export CasmTokenRecord
.export CasmTokenText

; WP28: moved off $70/$71 (CasmPtr0Lo/CasmPtr0Hi). expr.s's exprEvaluate
; identifier branch now stages the resolver's name pointer through
; CasmPtr0Lo/Hi for the duration of each resolver call -- this harness's own
; ScriptLo/ScriptHi (a long-lived cursor spanning the whole exprEvaluate
; call, unlike the resolver's transient use) previously happened to alias
; that exact address, so a resolver call for any identifier-bearing fixture
; silently clobbered this cursor before the following lexerNext call (e.g.
; consumeIdentifier's), corrupting every token read for the rest of that
; fixture. $7C/$7D are untouched by expr.s (confirmed: its only zero-page
; use is CasmPtr0Lo/Hi and CasmExprScratch0 = $84).
ScriptLo  = $7C
ScriptHi  = $7D
TableLo   = $72
TableHi   = $73
ExpectLo  = $74
ExpectHi  = $75
ResultLo  = $76
ResultHi  = $77
OutputLo  = $78
OutputHi  = $79
StringLo  = $7A
StringHi  = $7B

CASE_SCRIPT_LO = 0
CASE_SCRIPT_HI = 1
CASE_EXPECT_LO = 2
CASE_EXPECT_HI = 3
CASE_DIAG      = 4
CASE_FINAL     = 5
CASE_CALLS     = 6
CASE_COLUMN    = 7
; WP39: per-case input to exprEvaluate's new A (relocatable-mode) parameter.
; 0 for every pre-WP39 case, preserving their exact expected results
; unchanged (the new code only ORs RELOCATABLE in additionally -- a no-op
; against 0 -- so it cannot affect any case that doesn't opt in).
CASE_RELOC_MODE = 8
CASE_SIZE      = 9
CASE_COUNT     = 34

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda #<caseTable
    sta TableLo
    lda #>caseTable
    sta TableHi
    lda #0
    sta CaseIndex
    sta FailCount

caseLoop:
    ldy #CASE_SCRIPT_LO
    lda (TableLo), y
    sta ScriptLo
    iny
    lda (TableLo), y
    sta ScriptHi
    iny
    lda (TableLo), y
    sta ExpectLo
    iny
    lda (TableLo), y
    sta ExpectHi
    iny
    lda (TableLo), y
    sta ExpectedDiag
    iny
    lda (TableLo), y
    sta ExpectedFinal
    iny
    lda (TableLo), y
    sta ExpectedCalls
    iny
    lda (TableLo), y
    sta ExpectedColumn
    iny
    lda (TableLo), y
    sta CaseRelocModeIn

    lda #0
    sta ResolverCalls
    sta DiagCalls
    sta TokenOrdinal
    jsr lexerNext
    bcs caseFail
    ldx #<fixtureResolver
    ldy #>fixtureResolver
    lda CaseRelocModeIn
    jsr exprEvaluate
    php
    sta ActualDiag
    plp
    lda ExpectedDiag
    beq expectSuccess
    bcc caseFail
    lda ActualDiag
    cmp ExpectedDiag
    bne caseFail
    lda DiagCalls
    cmp #1
    bne caseFail
    lda CasmTokenRecord + CASM_TOKEN_REC_LINE_LO
    cmp #1
    bne caseFail
    lda CasmTokenRecord + CASM_TOKEN_REC_LINE_HI
    bne caseFail
    jmp checkCommon

expectSuccess:
    bcs caseFail
    lda DiagCalls
    bne caseFail
    jsr exprGetResult
    stx ResultLo
    sty ResultHi
    ldy #0
compareRecord:
    lda (ResultLo), y
    cmp (ExpectLo), y
    bne caseFail
    iny
    cpy #CASM_EXPR_REC_SIZE
    bne compareRecord

checkCommon:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp ExpectedFinal
    bne caseFail
    lda ResolverCalls
    cmp ExpectedCalls
    bne caseFail
    lda CasmTokenRecord + CASM_TOKEN_REC_COLUMN
    cmp ExpectedColumn
    bne caseFail
    lda #$2E
    jsr KernalChROUT
    jmp nextCase
caseFail:
    inc FailCount
    lda #$46
    jsr KernalChROUT
nextCase:
    clc
    lda TableLo
    adc #CASE_SIZE
    sta TableLo
    lda TableHi
    adc #0
    sta TableHi
    inc CaseIndex
    lda CaseIndex
    cmp #CASE_COUNT
    beq casesDone
    jmp caseLoop
casesDone:

    lda #$0D
    jsr KernalChROUT
    lda FailCount
    beq allPass
    lda #<failMsg
    ldy #>failMsg
    jmp printResult
allPass:
    lda #<passMsg
    ldy #>passMsg
printResult:
    tax
    lda #DOS_PRINT_STR
    jsr OS_API
    lda #DOS_EXIT
    jsr OS_API

; Compact script entry: type, subtype, text length, text bytes. lexerNext leaves
; Script pointing at the entry after the token it installs.
lexerNext:
    ldy #0
    lda (ScriptLo), y
    sta CasmTokenRecord + CASM_TOKEN_REC_TYPE
    iny
    lda (ScriptLo), y
    sta CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    iny
    lda (ScriptLo), y
    sta CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    lda #0
    sta CasmTokenRecord + CASM_TOKEN_REC_FILE_ID
    sta CasmTokenRecord + CASM_TOKEN_REC_LINE_HI
    lda #1
    sta CasmTokenRecord + CASM_TOKEN_REC_LINE_LO
    inc TokenOrdinal
    lda TokenOrdinal
    sta CasmTokenRecord + CASM_TOKEN_REC_COLUMN
    ldx #0
copyToken:
    cpx CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    beq tokenCopied
    iny
    lda (ScriptLo), y
    sta CasmTokenText, x
    inx
    jmp copyToken
tokenCopied:
    lda #0
    sta CasmTokenText, x
    tya
    sec
    adc ScriptLo
    sta ScriptLo
    lda ScriptHi
    adc #0
    sta ScriptHi
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    clc
    rts

diagSetLocFromToken:
    inc DiagCalls
    rts

fixtureResolver:
    inc ResolverCalls
    stx OutputLo
    sty OutputHi
    ldx #<nameAbs
    ldy #>nameAbs
    jsr tokenEquals
    bcc resolveAbs
    ldx #<nameRel
    ldy #>nameRel
    jsr tokenEquals
    bcc resolveRel
    ldx #<nameUnres
    ldy #>nameUnres
    jsr tokenEquals
    bcc resolveUnres
    ldx #<nameUnabs
    ldy #>nameUnabs
    jsr tokenEquals
    bcc resolveUnabs
    ldx #<nameBad
    ldy #>nameBad
    jsr tokenEquals
    bcc resolveBad
    lda #CASM_DIAG_RESOLVER_FAILED
    sec
    rts
resolveAbs:
    lda #CASM_EXPR_FLAG_RESOLVED
    ldx #1
    ldy #0
    jsr storeResolveHead
    lda #$34
    ldx #$12
    jmp storeResolveValue
resolveRel:
    lda #(CASM_EXPR_FLAG_RESOLVED | CASM_EXPR_FLAG_RELOCATABLE)
    ldx #2
    ldy #0
    jsr storeResolveHead
    lda #0
    ldx #$20
    jmp storeResolveValue
resolveUnres:
    lda #CASM_EXPR_FLAG_RELOCATABLE
    ldx #3
    ldy #0
    jsr storeResolveHead
    clc
    rts
resolveUnabs:
    lda #0
    ldx #4
    ldy #0
    jsr storeResolveHead
    clc
    rts
resolveBad:
    ldy #CASM_RESOLVE_FLAGS
    lda #$80
    sta (OutputLo), y
    clc
    rts

storeResolveHead:
    pha
    txa
    pha
    ldy #CASM_RESOLVE_FLAGS
    pla
    tax
    pla
    sta (OutputLo), y
    iny
    txa
    sta (OutputLo), y
    iny
    lda #0
    sta (OutputLo), y
    rts
storeResolveValue:
    ldy #CASM_RESOLVE_VAL_LO
    sta (OutputLo), y
    iny
    txa
    sta (OutputLo), y
    clc
    rts

; X/Y points to length-prefixed expected identifier. C clear means equal.
tokenEquals:
    stx StringLo
    sty StringHi
    ldy #0
    lda (StringLo), y
    cmp CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    bne notEqual
    tax
    ldy #0
equalLoop:
    cpy CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    beq equal
    iny
    lda (StringLo), y
    dey
    cmp CasmTokenText, y
    bne notEqual
    iny
    jmp equalLoop
equal:
    clc
    rts
notEqual:
    sec
    rts

.segment "BSS"
CasmTokenRecord: .res CASM_TOKEN_REC_SIZE
CasmTokenText = CasmTokenRecord + CASM_TOKEN_REC_TEXT
CaseIndex:      .res 1
FailCount:      .res 1
ResolverCalls:  .res 1
DiagCalls:      .res 1
ExpectedDiag:   .res 1
ExpectedFinal:  .res 1
ExpectedCalls:  .res 1
ActualDiag:     .res 1
ExpectedColumn: .res 1
TokenOrdinal:   .res 1
CaseRelocModeIn: .res 1

.segment "RODATA"
passMsg: .byte "CASM EXPR: PASS", $0D, 0
failMsg: .byte "CASM EXPR: FAIL", $0D, 0
nameAbs:   .byte 6, "ABSVAL"
nameRel:   .byte 6, "RELVAL"
nameUnres: .byte 5, "UNRES"
nameUnabs: .byte 5, "UNABS"
nameBad:   .byte 7, "BADFLAG"

; Token macros keep scripts readable while preserving exact PETSCII bytes.
.macro T0 type, subtype
    .byte type, subtype, 0
.endmacro
.macro T1 type, subtype, byteval
    .byte type, subtype, 1, byteval
.endmacro
.macro TN type, subtype, text
    .byte type, subtype, .strlen(text), text
.endmacro

; Common delimiters are repeated in scripts so each case is self-contained.
sN0: TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "0"
     T0 CASM_TOKEN_NEWLINE, 0
sNMAX: TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$FFFF"
       T0 CASM_TOKEN_EOF, 0
sNLO: T1 CASM_TOKEN_LESS, 0, $3C
      TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$1234"
      T1 CASM_TOKEN_COMMA, 0, $2C
sNHI: T1 CASM_TOKEN_GREATER, 0, $3E
      TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$1234"
      T1 CASM_TOKEN_RPAREN, 0, $29

sAbs: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
      T0 CASM_TOKEN_NEWLINE, 0
sAbsAdd: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
         T1 CASM_TOKEN_PLUS, 0, $2B
         TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
         T0 CASM_TOKEN_EOF, 0
sAbsSub: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
         T1 CASM_TOKEN_MINUS, 0, $2D
         TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$34"
         T0 CASM_TOKEN_EOF, 0
sAbsZero: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
          T1 CASM_TOKEN_PLUS, 0, $2B
          TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "0"
          T0 CASM_TOKEN_EOF, 0
sAbsNegZero: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
             T1 CASM_TOKEN_MINUS, 0, $2D
             TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$0000"
             T0 CASM_TOKEN_EOF, 0
sRelAdd: TN CASM_TOKEN_IDENTIFIER, 0, "RELVAL"
         T1 CASM_TOKEN_PLUS, 0, $2B
         TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$100"
         T0 CASM_TOKEN_EOF, 0
sRelLo: T1 CASM_TOKEN_LESS, 0, $3C
        TN CASM_TOKEN_IDENTIFIER, 0, "RELVAL"
        T0 CASM_TOKEN_EOF, 0
sRelHi: T1 CASM_TOKEN_GREATER, 0, $3E
        TN CASM_TOKEN_IDENTIFIER, 0, "RELVAL"
        T0 CASM_TOKEN_EOF, 0
sUnrAdd: TN CASM_TOKEN_IDENTIFIER, 0, "UNRES"
         T1 CASM_TOKEN_PLUS, 0, $2B
         TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$FFFF"
         T0 CASM_TOKEN_EOF, 0
sUnrSub: TN CASM_TOKEN_IDENTIFIER, 0, "UNRES"
         T1 CASM_TOKEN_MINUS, 0, $2D
         TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$FFFF"
         T0 CASM_TOKEN_EOF, 0
sUnrLo: T1 CASM_TOKEN_LESS, 0, $3C
        TN CASM_TOKEN_IDENTIFIER, 0, "UNRES"
        T0 CASM_TOKEN_EOF, 0
sUnrHi: T1 CASM_TOKEN_GREATER, 0, $3E
        TN CASM_TOKEN_IDENTIFIER, 0, "UNRES"
        T0 CASM_TOKEN_EOF, 0
sUna: TN CASM_TOKEN_IDENTIFIER, 0, "UNABS"
      T1 CASM_TOKEN_PLUS, 0, $2B
      TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "5"
      T0 CASM_TOKEN_EOF, 0

sNumAdd: TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
         T1 CASM_TOKEN_PLUS, 0, $2B
         TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
sNumSub: TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
         T1 CASM_TOKEN_MINUS, 0, $2D
         TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
sNoPrimary: T1 CASM_TOKEN_LESS, 0, $3C
            T0 CASM_TOKEN_NEWLINE, 0
sRepeatExtract: T1 CASM_TOKEN_LESS, 0, $3C
                T1 CASM_TOKEN_LESS, 0, $3C
                TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$1234"
sBadAdd: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
         T1 CASM_TOKEN_PLUS, 0, $2B
         T0 CASM_TOKEN_NEWLINE, 0
sSymAdd: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
         T1 CASM_TOKEN_PLUS, 0, $2B
         TN CASM_TOKEN_IDENTIFIER, 0, "RELVAL"
sChain: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
        T1 CASM_TOKEN_PLUS, 0, $2B
        TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
        T1 CASM_TOKEN_PLUS, 0, $2B
sAdjNum: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
         TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
sAdjId: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
        TN CASM_TOKEN_IDENTIFIER, 0, "RELVAL"
sOver: TN CASM_TOKEN_IDENTIFIER, 0, "RELVAL"
       T1 CASM_TOKEN_PLUS, 0, $2B
       TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$FFFF"
sUnder: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
        T1 CASM_TOKEN_MINUS, 0, $2D
        TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$FFFF"
sUnknown: TN CASM_TOKEN_IDENTIFIER, 0, "absval"
sBadFlag: TN CASM_TOKEN_IDENTIFIER, 0, "BADFLAG"

; WP39: ABSVAL's fixtureResolver entry (resolveAbs) never sets
; CASM_EXPR_FLAG_RELOCATABLE itself -- unlike RELVAL/UNRES, which already
; exercised the pre-WP39 resolver-reports-it-directly path. <ABSVAL isolates
; the new relocMode-input path from extraction-clearing, distinct from
; sRelLo (which would test the same clearing behavior but confounded with
; the resolver's own already-set bit).
sAbsLo: T1 CASM_TOKEN_LESS, 0, $3C
        TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
        T0 CASM_TOKEN_EOF, 0

.macro EXPECT name, vlo, vhi, flags, extract, idlo, idhi, sign, maglo, maghi
name: .byte vlo, vhi, flags, extract, idlo, idhi, sign, maglo, maghi
.endmacro
EXPECT eN0, 0,0, CASM_EXPR_FLAG_RESOLVED, CASM_EXTRACTION_FULL, 0,0, 0,0,0
EXPECT eNMAX, $FF,$FF, CASM_EXPR_FLAG_RESOLVED, CASM_EXTRACTION_FULL, 0,0, 0,0,0
EXPECT eNLO, $34,0, CASM_EXPR_FLAG_RESOLVED, CASM_EXTRACTION_LO, 0,0, 0,0,0
EXPECT eNHI, $12,0, CASM_EXPR_FLAG_RESOLVED, CASM_EXTRACTION_HI, 0,0, 0,0,0
EXPECT eAbs, $34,$12, $03, 0, 1,0, 0,0,0
EXPECT eAbsAdd, $35,$12, $03, 0, 1,0, 0,1,0
EXPECT eAbsSub, 0,$12, $03, 0, 1,0, 1,$34,0
EXPECT eAbsNegZero, $34,$12, $03, 0, 1,0, 1,0,0
EXPECT eRelAdd, 0,$21, $07, 0, 2,0, 0,0,$01
EXPECT eRelLo, 0,0, $03, 1, 2,0, 0,0,0
EXPECT eRelHi, $20,0, $07, 2, 2,0, 0,0,0
EXPECT eUnrAdd, 0,0, $0E, 0, 3,0, 0,$FF,$FF
EXPECT eUnrSub, 0,0, $0E, 0, 3,0, 1,$FF,$FF
EXPECT eUnrLo, 0,0, $0A, 1, 3,0, 0,0,0
EXPECT eUnrHi, 0,0, $0E, 2, 3,0, 0,0,0
EXPECT eUna, 0,0, $0A, 0, 4,0, 0,5,0

; WP39: relocMode=1 expectations. Each mirrors its relocMode=0 counterpart
; above with CASM_EXPR_FLAG_RELOCATABLE ($04) added to the flags byte,
; except eAbsRelocLo, where LO-extraction clears it back out regardless
; (applyExtraction's clear runs after the resolver-merge OR, unconditionally
; for LO -- confirmed by re-reading the exact instruction order in expr.s).
EXPECT eAbsReloc, $34,$12, $07, 0, 1,0, 0,0,0
EXPECT eAbsAddReloc, $35,$12, $07, 0, 1,0, 0,1,0
EXPECT eAbsRelocLo, $34,0, $03, 1, 1,0, 0,0,0
EXPECT eUnaReloc, 0,0, $0E, 0, 4,0, 0,5,0

.macro CASE script, expect, diag, final, calls, column, relocmode
    .word script, expect
    .byte diag, final, calls, column, relocmode
.endmacro
caseTable:
    ; WP39: every pre-existing case passes relocMode=0, preserving its exact
    ; expected result -- the new resolver-merge OR is additive against an
    ; already-set bit (RELVAL/UNRES cases) or a no-op against a clear one
    ; (every other case), confirmed by re-reading the exact instruction
    ; sequence before adding this parameter, not assumed.
    CASE sN0, eN0, 0, CASM_TOKEN_NEWLINE, 0, 2, 0
    CASE sNMAX, eNMAX, 0, CASM_TOKEN_EOF, 0, 2, 0
    CASE sNLO, eNLO, 0, CASM_TOKEN_COMMA, 0, 3, 0
    CASE sNHI, eNHI, 0, CASM_TOKEN_RPAREN, 0, 3, 0
    CASE sAbs, eAbs, 0, CASM_TOKEN_NEWLINE, 1, 2, 0
    CASE sAbsAdd, eAbsAdd, 0, CASM_TOKEN_EOF, 1, 4, 0
    CASE sAbsSub, eAbsSub, 0, CASM_TOKEN_EOF, 1, 4, 0
    CASE sAbsZero, eAbs, 0, CASM_TOKEN_EOF, 1, 4, 0
    CASE sAbsNegZero, eAbsNegZero, 0, CASM_TOKEN_EOF, 1, 4, 0
    CASE sRelAdd, eRelAdd, 0, CASM_TOKEN_EOF, 1, 4, 0
    CASE sRelLo, eRelLo, 0, CASM_TOKEN_EOF, 1, 3, 0
    CASE sRelHi, eRelHi, 0, CASM_TOKEN_EOF, 1, 3, 0
    CASE sUnrAdd, eUnrAdd, 0, CASM_TOKEN_EOF, 1, 4, 0
    CASE sUnrSub, eUnrSub, 0, CASM_TOKEN_EOF, 1, 4, 0
    CASE sUnrLo, eUnrLo, 0, CASM_TOKEN_EOF, 1, 3, 0
    CASE sUnrHi, eUnrHi, 0, CASM_TOKEN_EOF, 1, 3, 0
    CASE sUna, eUna, 0, CASM_TOKEN_EOF, 1, 4, 0
    CASE sNumAdd, 0, CASM_DIAG_EXPR_UNSUPPORTED, CASM_TOKEN_PLUS, 0, 2, 0
    CASE sNumSub, 0, CASM_DIAG_EXPR_UNSUPPORTED, CASM_TOKEN_MINUS, 0, 2, 0
    CASE sNoPrimary, 0, CASM_DIAG_EXPR_MALFORMED, CASM_TOKEN_NEWLINE, 0, 2, 0
    CASE sRepeatExtract, 0, CASM_DIAG_EXPR_MALFORMED, CASM_TOKEN_LESS, 0, 2, 0
    CASE sBadAdd, 0, CASM_DIAG_EXPR_MALFORMED, CASM_TOKEN_NEWLINE, 1, 3, 0
    CASE sSymAdd, 0, CASM_DIAG_EXPR_MALFORMED, CASM_TOKEN_IDENTIFIER, 1, 3, 0
    CASE sChain, 0, CASM_DIAG_EXPR_UNSUPPORTED, CASM_TOKEN_PLUS, 1, 4, 0
    CASE sAdjNum, 0, CASM_DIAG_EXPR_UNSUPPORTED, CASM_TOKEN_NUMBER, 1, 2, 0
    CASE sAdjId, 0, CASM_DIAG_EXPR_UNSUPPORTED, CASM_TOKEN_IDENTIFIER, 1, 2, 0
    CASE sOver, 0, CASM_DIAG_EXPR_OVERFLOW, CASM_TOKEN_NUMBER, 1, 3, 0
    CASE sUnder, 0, CASM_DIAG_EXPR_OVERFLOW, CASM_TOKEN_NUMBER, 1, 3, 0
    CASE sUnknown, 0, CASM_DIAG_RESOLVER_FAILED, CASM_TOKEN_IDENTIFIER, 1, 1, 0
    CASE sBadFlag, 0, CASM_DIAG_RESOLVER_FAILED, CASM_TOKEN_IDENTIFIER, 1, 1, 0

    ; WP39: relocMode=1 cases, proving exprEvaluate's new input classifies a
    ; symbol reference as relocatable even when the resolver itself does not
    ; report it (ABSVAL's fixtureResolver entry never sets
    ; CASM_EXPR_FLAG_RELOCATABLE) -- the production gap this WP closes.
    CASE sAbs, eAbsReloc, 0, CASM_TOKEN_NEWLINE, 1, 2, 1
    CASE sAbsAdd, eAbsAddReloc, 0, CASM_TOKEN_EOF, 1, 4, 1
    CASE sAbsLo, eAbsRelocLo, 0, CASM_TOKEN_EOF, 1, 3, 1
    CASE sUna, eUnaReloc, 0, CASM_TOKEN_EOF, 1, 4, 1
