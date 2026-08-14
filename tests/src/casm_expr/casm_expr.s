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
.export CasmPc

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
CASE_COUNT     = 55

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    ; WP66: fixed for the whole harness run -- every '*' EXPECT record
    ; (eStar*) below is computed against this exact value ($4050).
    lda #$50
    sta CasmPc
    lda #$40
    sta CasmPc + 1
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
CasmPc:         .res 2

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

; WP60 Increment 6: isolated numeric-literal boundary rows. sN0/sNMAX above
; already cover $0000/$FFFF as bare literals; sRelAdd (below) uses $0100 only
; as an identifier addend, not isolated -- these four give $00FF and $0100
; their own bare-literal case, plus the two rows Increment 2's register found
; zero coverage for anywhere in tests/: a >16-bit literal (exprParseNumeric's
; own digit-accumulation overflow, CASM_DIAG_OPERAND_OUT_OF_RANGE -- distinct
; from sOver/sUnder below, which are RELVAL+$FFFF/ABSVAL-$FFFF *expression*
; overflow, not a literal token overflowing on its own) and a bare
; CASM_NUMBER_BINARY literal (never exercised anywhere in this harness).
sN00FF: TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$00FF"
        T0 CASM_TOKEN_NEWLINE, 0
sN0100: TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$0100"
        T0 CASM_TOKEN_NEWLINE, 0
; exprParseNumeric's hexLoop skips index 0 ('$') and multiply16s each
; remaining digit in; the fifth hex digit shifts $1000 left by 4 more bits to
; $10000, setting CasmExprValueExt non-zero (sticky CasmExprOverflow) before
; the digit loop even reaches the trailing "0" -- five hex digits is the
; minimum literal that can trip this regardless of its low nibble.
sNumOverflow: TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$10000"
              T0 CASM_TOKEN_NEWLINE, 0
; Binary mirrors hex/decimal's index-0-is-prefix convention ('%', skipped by
; exprParseNumeric's own ldy #1 before binaryLoop) -- eight 1-bits is $FF,
; independently computed, not derived by comparing against a hex case.
sBin255: TN CASM_TOKEN_NUMBER, CASM_NUMBER_BINARY, "%11111111"
         T0 CASM_TOKEN_NEWLINE, 0

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

; WP67: NUMBER now reaches the same shared +/- operator loop as IDENTIFIER/
; '*' (the pre-WP67 restriction that only they could take a trailing
; addend is lifted, user-confirmed 2026-08-14) -- '1+1'/'1-1' succeed
; instead of CASM_DIAG_EXPR_UNSUPPORTED. Explicit NEWLINE terminators
; (absent pre-WP67, when NUMBER's own tail errored out immediately after
; the '+'/'-' without ever reading further) are now load-bearing, not
; cosmetic.
sNumAdd: TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
         T1 CASM_TOKEN_PLUS, 0, $2B
         TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
         T0 CASM_TOKEN_NEWLINE, 0
sNumSub: TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
         T1 CASM_TOKEN_MINUS, 0, $2D
         TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
         T0 CASM_TOKEN_NEWLINE, 0
; WP67: left-associative triple chain (1+2-3 = 0, not 1+(2-3) = 2) --
; proves the loop applies operators strictly left-to-right, not with any
; unintended right-associativity or grouping.
sNumChain: TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
           T1 CASM_TOKEN_PLUS, 0, $2B
           TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "2"
           T1 CASM_TOKEN_MINUS, 0, $2D
           TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "3"
           T0 CASM_TOKEN_NEWLINE, 0
; WP67: parenthesized sub-expression, the simplest case -- (5).
sParenSimple: T1 CASM_TOKEN_LPAREN, 0, $28
              TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "5"
              T1 CASM_TOKEN_RPAREN, 0, $29
              T0 CASM_TOKEN_NEWLINE, 0
; WP67: '1+(2+3)' -- grouping combined with the outer chain.
sParenAdd: TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
           T1 CASM_TOKEN_PLUS, 0, $2B
           T1 CASM_TOKEN_LPAREN, 0, $28
           TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "2"
           T1 CASM_TOKEN_PLUS, 0, $2B
           TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "3"
           T1 CASM_TOKEN_RPAREN, 0, $29
           T0 CASM_TOKEN_NEWLINE, 0
; WP67: '(1+2)+(3+4)' -- two separate groups combined by the outer chain.
sParenTwoGroups: T1 CASM_TOKEN_LPAREN, 0, $28
                 TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
                 T1 CASM_TOKEN_PLUS, 0, $2B
                 TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "2"
                 T1 CASM_TOKEN_RPAREN, 0, $29
                 T1 CASM_TOKEN_PLUS, 0, $2B
                 T1 CASM_TOKEN_LPAREN, 0, $28
                 TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "3"
                 T1 CASM_TOKEN_PLUS, 0, $2B
                 TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "4"
                 T1 CASM_TOKEN_RPAREN, 0, $29
                 T0 CASM_TOKEN_NEWLINE, 0
; WP67: unclosed paren -- CASM_DIAG_EXPR_MALFORMED.
sParenUnclosed: T1 CASM_TOKEN_LPAREN, 0, $28
                TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "5"
                T0 CASM_TOKEN_NEWLINE, 0
; WP67: extraction (a whole-expression, top-level-only concept, applied
; once after the full primary+operator-tail chain returns) combined with
; a parenthesized RHS -- proves applyExtraction's own unchanged logic
; correctly sees whatever the group computed, not just a bare primary.
sParenExtractLo: T1 CASM_TOKEN_LESS, 0, $3C
                 T1 CASM_TOKEN_LPAREN, 0, $28
                 TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
                 T1 CASM_TOKEN_PLUS, 0, $2B
                 TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
                 T1 CASM_TOKEN_RPAREN, 0, $29
                 T0 CASM_TOKEN_EOF, 0
; WP67: '*' (WP66's current-address symbol) as a group's own inner
; primary -- '(*+3)' should produce exactly the same result as WP66's own
; bare '*+3' (sStarAdd/eStarAdd), just reached through parsePrimary's
; recursive group arm instead of directly.
sParenStar: T1 CASM_TOKEN_LPAREN, 0, $28
            T0 CASM_TOKEN_STAR, 0
            T1 CASM_TOKEN_PLUS, 0, $2B
            TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "3"
            T1 CASM_TOKEN_RPAREN, 0, $29
            T0 CASM_TOKEN_EOF, 0
; WP67: ABSVAL+(RELVAL) -- one relocatable component, wrapped in a group,
; combined with a static primary. Representable (WP64's rule): at most
; one relocatable component total, regardless of which side it's on or
; whether it's parenthesized.
sParenReloc: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
             T1 CASM_TOKEN_PLUS, 0, $2B
             T1 CASM_TOKEN_LPAREN, 0, $28
             TN CASM_TOKEN_IDENTIFIER, 0, "RELVAL"
             T1 CASM_TOKEN_RPAREN, 0, $29
             T0 CASM_TOKEN_EOF, 0
; WP67: RELVAL+(RELVAL) -- two relocatable components. Not representable
; as one symbol + static addend -- CASM_DIAG_EXPR_RELOC_UNSUPPORTED.
sParenRelocReject: TN CASM_TOKEN_IDENTIFIER, 0, "RELVAL"
                   T1 CASM_TOKEN_PLUS, 0, $2B
                   T1 CASM_TOKEN_LPAREN, 0, $28
                   TN CASM_TOKEN_IDENTIFIER, 0, "RELVAL"
                   T1 CASM_TOKEN_RPAREN, 0, $29
                   T0 CASM_TOKEN_EOF, 0
; WP67: 9 levels of nesting -- one past CASM_EXPR_PAREN_MAX_DEPTH (8) --
; CASM_DIAG_EXPR_PAREN_TOO_DEEP. Fails at the 9th '(' itself before ever
; reading the (absent) content/closing parens, so nothing after the 9th
; open is needed.
sParenTooDeep:
    T1 CASM_TOKEN_LPAREN, 0, $28
    T1 CASM_TOKEN_LPAREN, 0, $28
    T1 CASM_TOKEN_LPAREN, 0, $28
    T1 CASM_TOKEN_LPAREN, 0, $28
    T1 CASM_TOKEN_LPAREN, 0, $28
    T1 CASM_TOKEN_LPAREN, 0, $28
    T1 CASM_TOKEN_LPAREN, 0, $28
    T1 CASM_TOKEN_LPAREN, 0, $28
    T1 CASM_TOKEN_LPAREN, 0, $28
    T0 CASM_TOKEN_NEWLINE, 0
sNoPrimary: T1 CASM_TOKEN_LESS, 0, $3C
            T0 CASM_TOKEN_NEWLINE, 0
sRepeatExtract: T1 CASM_TOKEN_LESS, 0, $3C
                T1 CASM_TOKEN_LESS, 0, $3C
                TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$1234"
sBadAdd: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
         T1 CASM_TOKEN_PLUS, 0, $2B
         T0 CASM_TOKEN_NEWLINE, 0
; WP67: RHS is now a full recursive primary parse (parsePrimary), not
; exprParseAddend's own NUMBER-only, resolver-never-touching parse -- an
; IDENTIFIER RHS now reaches the resolver and the relocation-
; representability check instead of failing immediately at "expected
; NUMBER". ABSVAL+RELVAL is exactly one relocatable component (RELVAL;
; ABSVAL is static at relocMode=0) -- representable, now succeeds.
; Explicit EOF terminator added (WP67; previously relied on erroring out
; before ever reading past RELVAL's own token).
sSymAdd: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
         T1 CASM_TOKEN_PLUS, 0, $2B
         TN CASM_TOKEN_IDENTIFIER, 0, "RELVAL"
         T0 CASM_TOKEN_EOF, 0
; WP67: a second '+' with nothing after it -- still MALFORMED (parsePrimary
; sees NEWLINE where a primary was expected), same diagnostic as before,
; but the loop now actually applies the *first* '+' (ABSVAL+1) before
; discovering the second one has no RHS, so final/column shift. Explicit
; NEWLINE terminator added (WP67).
sChain: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
        T1 CASM_TOKEN_PLUS, 0, $2B
        TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
        T1 CASM_TOKEN_PLUS, 0, $2B
        T0 CASM_TOKEN_NEWLINE, 0
sAdjNum: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
         TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
sAdjId: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
        TN CASM_TOKEN_IDENTIFIER, 0, "RELVAL"
; WP67: parsePrimary's own NUMBER arm now always advances past its own
; token before returning (matching every other primary kind), unlike the
; pre-WP67 exprParseAddend/exprParseNumeric convention of leaving the
; addend's NUMBER current for the caller to advance past -- so the
; overflow (detected in parseOperatorTail's own arithmetic, independent
; of lexer position) is now discovered with the *following* token
; current, not the NUMBER itself. Explicit NEWLINE terminators added
; (WP67) so that following token is deterministic.
sOver: TN CASM_TOKEN_IDENTIFIER, 0, "RELVAL"
       T1 CASM_TOKEN_PLUS, 0, $2B
       TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$FFFF"
       T0 CASM_TOKEN_NEWLINE, 0
sUnder: TN CASM_TOKEN_IDENTIFIER, 0, "ABSVAL"
        T1 CASM_TOKEN_MINUS, 0, $2D
        TN CASM_TOKEN_NUMBER, CASM_NUMBER_HEX, "$FFFF"
        T0 CASM_TOKEN_NEWLINE, 0
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

; WP66: current-address symbol ('*'). Column/final-token shapes mirror the
; structurally identical ABSVAL/RELVAL identifier cases above exactly
; (same token sequence, same lexerNext count) -- the only difference is
; ResolverCalls staying 0, since '*' never reaches the resolver callback.
sStar: T0 CASM_TOKEN_STAR, 0
       T0 CASM_TOKEN_NEWLINE, 0
sStarAdd: T0 CASM_TOKEN_STAR, 0
          T1 CASM_TOKEN_PLUS, 0, $2B
          TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "3"
          T0 CASM_TOKEN_EOF, 0
sStarSub: T0 CASM_TOKEN_STAR, 0
          T1 CASM_TOKEN_MINUS, 0, $2D
          TN CASM_TOKEN_NUMBER, CASM_NUMBER_DECIMAL, "1"
          T0 CASM_TOKEN_EOF, 0
sStarLo: T1 CASM_TOKEN_LESS, 0, $3C
         T0 CASM_TOKEN_STAR, 0
         T0 CASM_TOKEN_EOF, 0
sStarHi: T1 CASM_TOKEN_GREATER, 0, $3E
         T0 CASM_TOKEN_STAR, 0
         T0 CASM_TOKEN_EOF, 0

.macro EXPECT name, vlo, vhi, flags, extract, idlo, idhi, sign, maglo, maghi
name: .byte vlo, vhi, flags, extract, idlo, idhi, sign, maglo, maghi
.endmacro
EXPECT eN0, 0,0, CASM_EXPR_FLAG_RESOLVED, CASM_EXTRACTION_FULL, 0,0, 0,0,0
EXPECT eNMAX, $FF,$FF, CASM_EXPR_FLAG_RESOLVED, CASM_EXTRACTION_FULL, 0,0, 0,0,0
EXPECT eNLO, $34,0, CASM_EXPR_FLAG_RESOLVED, CASM_EXTRACTION_LO, 0,0, 0,0,0
EXPECT eNHI, $12,0, CASM_EXPR_FLAG_RESOLVED, CASM_EXTRACTION_HI, 0,0, 0,0,0
EXPECT eN00FF, $FF,0, CASM_EXPR_FLAG_RESOLVED, CASM_EXTRACTION_FULL, 0,0, 0,0,0
EXPECT eN0100, 0,$01, CASM_EXPR_FLAG_RESOLVED, CASM_EXTRACTION_FULL, 0,0, 0,0,0
EXPECT eBin255, $FF,0, CASM_EXPR_FLAG_RESOLVED, CASM_EXTRACTION_FULL, 0,0, 0,0,0
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

; WP66: current-address symbol, evaluated against CasmPc = $4050 (fixed for
; this whole harness run -- StarPc below). $03 = RESOLVED|SYMBOL_DERIVED
; (no resolver ever ran, so no symbol id/RELOCATABLE beyond what relocMode
; itself contributes); $07 adds RELOCATABLE for the relocMode=1 cases.
EXPECT eStar, $50,$40, $03, 0, 0,0, 0,0,0
EXPECT eStarAdd, $53,$40, $03, 0, 0,0, 0,3,0
EXPECT eStarSub, $4F,$40, $03, 0, 0,0, 1,1,0
EXPECT eStarLo, $50,0, $03, 1, 0,0, 0,0,0
EXPECT eStarHi, $40,0, $03, 2, 0,0, 0,0,0
EXPECT eStarReloc, $50,$40, $07, 0, 0,0, 0,0,0
EXPECT eStarLoReloc, $50,0, $03, 1, 0,0, 0,0,0

; WP67: NUMBER now reaches the shared +/- operator loop; ADDEND_SIGN/MAG
; hold the *last* applied operator's own sign/RHS-value (parseOperatorTail's
; own convention, matching the pre-WP67 single-addend record exactly when
; there's exactly one operator with a NUMBER RHS).
EXPECT eNumAdd, 2,0, CASM_EXPR_FLAG_RESOLVED, 0, 0,0, 0,1,0
EXPECT eNumSub, 0,0, CASM_EXPR_FLAG_RESOLVED, 0, 0,0, 1,1,0
EXPECT eNumChain, 0,0, CASM_EXPR_FLAG_RESOLVED, 0, 0,0, 1,3,0
; ABSVAL+RELVAL: one relocatable component (RELVAL) -- representable.
EXPECT eSymAdd, $34,$32, $07, 0, 1,0, 0,$00,$20
; Parenthesized sub-expressions. A group with no operator around it at
; all (eParenSimple) never touches ADDEND (no operator loop iteration
; ever ran, inner or outer) -- stays at exprInit's zero default.
EXPECT eParenSimple, 5,0, CASM_EXPR_FLAG_RESOLVED, 0, 0,0, 0,0,0
EXPECT eParenAdd, 6,0, CASM_EXPR_FLAG_RESOLVED, 0, 0,0, 0,5,0
EXPECT eParenTwoGroups, 10,0, CASM_EXPR_FLAG_RESOLVED, 0, 0,0, 0,7,0
; ABSVAL+(RELVAL): one relocatable component, wrapped in a group --
; representable regardless of which side it's on or whether it's
; parenthesized (WP64's rule).
EXPECT eParenReloc, $34,$32, $07, 0, 1,0, 0,$00,$20
; <(ABSVAL+1): extraction applies to the group's own final value, same as
; any other primary's.
EXPECT eParenExtractLo, $35,0, $03, CASM_EXTRACTION_LO, 1,0, 0,1,0

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
    ; WP60 Increment 6: isolated numeric-literal boundary cases.
    CASE sN00FF, eN00FF, 0, CASM_TOKEN_NEWLINE, 0, 2, 0
    CASE sN0100, eN0100, 0, CASM_TOKEN_NEWLINE, 0, 2, 0
    ; exprParseNumeric's own overflow fires BEFORE exprEvaluate's post-primary
    ; lexerNext call (unlike sNumAdd/sNumSub, whose EXPR_UNSUPPORTED fires
    ; AFTER a successful primary already fetched the next token) -- only the
    ; harness's initial lexerNext (fetching the NUMBER itself) ever runs, so
    ; TokenOrdinal (this harness's own "column" stand-in) is 1, not 2.
    CASE sNumOverflow, 0, CASM_DIAG_OPERAND_OUT_OF_RANGE, CASM_TOKEN_NUMBER, 0, 1, 0
    CASE sBin255, eBin255, 0, CASM_TOKEN_NEWLINE, 0, 2, 0
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
    ; WP67: NUMBER now succeeds through the shared +/- loop instead of
    ; CASM_DIAG_EXPR_UNSUPPORTED (restriction lifted, user-confirmed
    ; 2026-08-14).
    CASE sNumAdd, eNumAdd, 0, CASM_TOKEN_NEWLINE, 0, 4, 0
    CASE sNumSub, eNumSub, 0, CASM_TOKEN_NEWLINE, 0, 4, 0
    CASE sNumChain, eNumChain, 0, CASM_TOKEN_NEWLINE, 0, 6, 0
    CASE sNoPrimary, 0, CASM_DIAG_EXPR_MALFORMED, CASM_TOKEN_NEWLINE, 0, 2, 0
    CASE sRepeatExtract, 0, CASM_DIAG_EXPR_MALFORMED, CASM_TOKEN_LESS, 0, 2, 0
    CASE sBadAdd, 0, CASM_DIAG_EXPR_MALFORMED, CASM_TOKEN_NEWLINE, 1, 3, 0
    ; WP67: IDENTIFIER is now a valid RHS via the recursive primary parse
    ; (previously CASM_DIAG_EXPR_MALFORMED, since exprParseAddend required
    ; NUMBER) -- ABSVAL+RELVAL is exactly one relocatable component,
    ; representable, now succeeds.
    CASE sSymAdd, eSymAdd, 0, CASM_TOKEN_EOF, 2, 4, 0
    ; WP67: the loop now actually applies ABSVAL+1 before discovering the
    ; second '+' has no RHS (previously stopped at the first symbolDone/
    ; rejectContinuation check without ever trying).
    CASE sChain, 0, CASM_DIAG_EXPR_MALFORMED, CASM_TOKEN_NEWLINE, 1, 5, 0
    CASE sAdjNum, 0, CASM_DIAG_EXPR_UNSUPPORTED, CASM_TOKEN_NUMBER, 1, 2, 0
    CASE sAdjId, 0, CASM_DIAG_EXPR_UNSUPPORTED, CASM_TOKEN_IDENTIFIER, 1, 2, 0
    ; WP67: parsePrimary's NUMBER arm now always advances past its own
    ; token before returning (unlike the pre-WP67 exprParseAddend/
    ; exprParseNumeric convention of leaving it current) -- the overflow
    ; is discovered with the *following* token current, not the NUMBER.
    CASE sOver, 0, CASM_DIAG_EXPR_OVERFLOW, CASM_TOKEN_NEWLINE, 1, 4, 0
    CASE sUnder, 0, CASM_DIAG_EXPR_OVERFLOW, CASM_TOKEN_NEWLINE, 1, 4, 0
    CASE sUnknown, 0, CASM_DIAG_RESOLVER_FAILED, CASM_TOKEN_IDENTIFIER, 1, 1, 0
    CASE sBadFlag, 0, CASM_DIAG_RESOLVER_FAILED, CASM_TOKEN_IDENTIFIER, 1, 1, 0
    ; WP67: parenthesized sub-expressions.
    CASE sParenSimple, eParenSimple, 0, CASM_TOKEN_NEWLINE, 0, 4, 0
    CASE sParenAdd, eParenAdd, 0, CASM_TOKEN_NEWLINE, 0, 8, 0
    CASE sParenTwoGroups, eParenTwoGroups, 0, CASM_TOKEN_NEWLINE, 0, 12, 0
    CASE sParenUnclosed, 0, CASM_DIAG_EXPR_MALFORMED, CASM_TOKEN_NEWLINE, 0, 3, 0
    CASE sParenReloc, eParenReloc, 0, CASM_TOKEN_EOF, 2, 6, 0
    CASE sParenRelocReject, 0, CASM_DIAG_EXPR_RELOC_UNSUPPORTED, CASM_TOKEN_EOF, 2, 6, 0
    CASE sParenTooDeep, 0, CASM_DIAG_EXPR_PAREN_TOO_DEEP, CASM_TOKEN_LPAREN, 0, 9, 0
    CASE sParenExtractLo, eParenExtractLo, 0, CASM_TOKEN_EOF, 1, 7, 0
    CASE sParenStar, eStarAdd, 0, CASM_TOKEN_EOF, 0, 6, 0

    ; WP39: relocMode=1 cases, proving exprEvaluate's new input classifies a
    ; symbol reference as relocatable even when the resolver itself does not
    ; report it (ABSVAL's fixtureResolver entry never sets
    ; CASM_EXPR_FLAG_RELOCATABLE) -- the production gap this WP closes.
    CASE sAbs, eAbsReloc, 0, CASM_TOKEN_NEWLINE, 1, 2, 1
    CASE sAbsAdd, eAbsAddReloc, 0, CASM_TOKEN_EOF, 1, 4, 1
    CASE sAbsLo, eAbsRelocLo, 0, CASM_TOKEN_EOF, 1, 3, 1
    CASE sUna, eUnaReloc, 0, CASM_TOKEN_EOF, 1, 4, 1

    ; WP66: current-address symbol. Column/final/calls mirror the
    ; structurally identical ABSVAL/RELVAL cases above (sAbs/sAbsAdd/
    ; sAbsSub/sRelLo/sRelHi), calls=0 throughout since '*' never reaches
    ; fixtureResolver.
    CASE sStar, eStar, 0, CASM_TOKEN_NEWLINE, 0, 2, 0
    CASE sStarAdd, eStarAdd, 0, CASM_TOKEN_EOF, 0, 4, 0
    CASE sStarSub, eStarSub, 0, CASM_TOKEN_EOF, 0, 4, 0
    CASE sStarLo, eStarLo, 0, CASM_TOKEN_EOF, 0, 3, 0
    CASE sStarHi, eStarHi, 0, CASM_TOKEN_EOF, 0, 3, 0
    CASE sStar, eStarReloc, 0, CASM_TOKEN_NEWLINE, 0, 2, 1
    CASE sStarLo, eStarLoReloc, 0, CASM_TOKEN_EOF, 0, 3, 1
