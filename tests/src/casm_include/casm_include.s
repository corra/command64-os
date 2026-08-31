; tests/src/casm_include/casm_include.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 9 WP44 embedded-script harness. Links the real lexer, parser, and
; persistent state while supplying a bounded in-memory source backend and
; semantic stubs for parser paths these include-only fixtures never enter.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_include.inc"

.import __MAIN_START__
.import lexerInit
.import parserParseStatement
.import CasmParserStmt
.import CasmIncludeFilename
.import CasmIncludeFilenameLen
.import CasmSourceResultByte
.import CasmSourceFileId
.import CasmSourceLineLo
.import CasmSourceLineHi
.import CasmSourceColumn
.import CasmSourceResultFileId
.import CasmSourceResultLineLo
.import CasmSourceResultLineHi
.import CasmSourceResultColumn
.import CasmDiagLocValid
.import CasmDiagLocLineLo
.import CasmDiagLocLineHi
.import CasmDiagLocColumn
.import CasmDiagLocByte
.import CasmDiagLocFileId
.import CasmStmtLocLineLo
.import CasmStmtLocLineHi
.import CasmStmtLocColumn
.import CasmStmtLocFileId
.import CasmTokenRecord
.import CasmLookaheadByte
.import CasmLookaheadFileId
.import CasmLookaheadLineLo
.import CasmLookaheadLineHi
.import CasmLookaheadColumn

.export sourceNextByte
.export diagSetLocFromLookahead
.export diagSetLocFromLookaheadPos
.export diagSetLocFromToken
.export diagStampStmtLoc
.export exprEvaluate
.export exprGetResult
.export exprParseNumeric
.export exprParseAddend
.export exprApplyAddend
.export symbolsLookup
.export emitMarkStarted
.export CasmPassMode
.export CasmRelocatableMode

CASE_SCRIPT_LO   = 0
CASE_SCRIPT_HI   = 1
CASE_SCRIPT_LEN  = 2
CASE_EXPECT_DIAG = 3
CASE_EXPECT_LEN  = 4
CASE_EXPECT_LO   = 5
CASE_EXPECT_HI   = 6
CASE_EXPECT_COL  = 7
CASE_SIZE        = 8
CASE_COUNT       = 14

ScriptPtr   = CasmIoPtrLo

.segment "HEADER"
    .word __MAIN_START__

.segment "BSS"
ScriptLen:           .res 1
ScriptPos:           .res 1
CaseTablePtr:        .res 2
ExpectedAddr:        .res 2
ExpectedDiag:        .res 1
ExpectedLen:         .res 1
ExpectedCol:         .res 1
FailCount:           .res 1
CasmPassMode:        .res 1
CasmRelocatableMode: .res 1

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda #0
    sta FailCount
    lda #<caseTable
    sta CaseTablePtr
    lda #>caseTable
    sta CaseTablePtr + 1
    ldx #CASE_COUNT
caseLoop:
    txa
    pha
    jsr runCase
    bcc :+
    inc FailCount
    lda #$46                    ; F
    bne @print
:
    lda #$2E                    ; .
@print:
    jsr KernalChROUT
    clc
    lda CaseTablePtr
    adc #CASE_SIZE
    sta CaseTablePtr
    bcc :+
    inc CaseTablePtr + 1
:
    pla
    tax
    dex
    bne caseLoop

    lda #$0D
    jsr KernalChROUT
    lda FailCount
    beq allPass
    ldx #<failMsg
    ldy #>failMsg
    bne printResult
allPass:
    ldx #<passMsg
    ldy #>passMsg
printResult:
    lda #DOS_PRINT_STR
    jsr OS_API
    lda #DOS_EXIT
    jsr OS_API

runCase:
    ; Production lexer helpers use CasmPtr0, so the durable table cursor lives
    ; in BSS and is copied to zero page only while this fixed record is read.
    lda CaseTablePtr
    sta CasmPtr0Lo
    lda CaseTablePtr + 1
    sta CasmPtr0Hi
    ldy #CASE_SCRIPT_LO
    lda (CasmPtr0Lo), y
    sta ScriptPtr
    iny
    lda (CasmPtr0Lo), y
    sta ScriptPtr + 1
    iny
    lda (CasmPtr0Lo), y
    sta ScriptLen
    iny
    lda (CasmPtr0Lo), y
    sta ExpectedDiag
    iny
    lda (CasmPtr0Lo), y
    sta ExpectedLen
    iny
    lda (CasmPtr0Lo), y
    sta ExpectedAddr
    iny
    lda (CasmPtr0Lo), y
    sta ExpectedAddr + 1
    iny
    lda (CasmPtr0Lo), y
    sta ExpectedCol

    lda #0
    sta ScriptPos
    sta CasmSourceFileId
    sta CasmSourceLineHi
    lda #1
    sta CasmSourceLineLo
    sta CasmSourceColumn
    jsr lexerInit
    bcs caseFail
    jsr parserParseStatement
    ldx ExpectedDiag
    beq expectSuccess
    bcc caseFail
    cmp ExpectedDiag
    bne caseFail
    lda CasmDiagLocColumn
    cmp ExpectedCol
    bne caseFail
    clc
    rts

expectSuccess:
    bcs caseFail
    cmp #CASM_TOKEN_DIRECTIVE
    bne caseFail
    lda CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    cmp #CASM_DIRECTIVE_INCLUDE
    bne caseFail
    lda CasmParserStmt + CASM_PARSER_STMT_OPKIND
    cmp #CASM_OPKIND_IMPLIED
    bne caseFail
    lda CasmIncludeFilenameLen
    cmp ExpectedLen
    bne caseFail
    tax
    lda CasmIncludeFilename, x
    bne caseFail
    ; Parser/lexer code may clobber CasmPtr1 in future; publish the durable BSS
    ; address only for this immediate comparison.
    lda ExpectedAddr
    sta CasmPtr1Lo
    lda ExpectedAddr + 1
    sta CasmPtr1Hi
    ldy #0
@compare:
    cpy ExpectedLen
    beq casePass
    lda (CasmPtr1Lo), y
    cmp CasmIncludeFilename, y
    bne caseFail
    iny
    bne @compare
casePass:
    clc
    rts
caseFail:
    sec
    rts

; Length-bounded embedded source backend. CR is normalized to NEWLINE; every
; other byte, including null, is returned as a source BYTE.
;
; WP46 fix: stamps CasmSourceResultFileId/LineLo/Hi/Column with this
; delivered result's own provenance -- the position *before* this byte's
; own column/line advance below, matching source.s's sfpHaveByte/sfpEof
; convention -- since lexerFill now reads these instead of snapshotting
; CasmSourceFileId/LineLo/Hi/Column itself before calling sourceNextByte.
; This stub has no frame-pop concept at all (a single flat embedded
; script), so the distinction never actually matters here, but the
; contract is the same one every sourceNextByte-shaped provider must honor.
sourceNextByte:
    ldy ScriptPos
    cpy ScriptLen
    bcs @eof
    lda (ScriptPtr), y
    inc ScriptPos
    cmp #CASM_PETSCII_CR
    beq @newline
    pha
    jsr stampResultLoc
    pla
    sta CasmSourceResultByte
    inc CasmSourceColumn
    lda #CASM_SOURCE_BYTE
    clc
    rts
@newline:
    jsr stampResultLoc
    inc CasmSourceLineLo
    bne :+
    inc CasmSourceLineHi
:
    lda #1
    sta CasmSourceColumn
    lda #CASM_SOURCE_NEWLINE
    clc
    rts
@eof:
    jsr stampResultLoc
    lda #CASM_SOURCE_EOF
    clc
    rts

; Copies the current (pre-advance) CasmSourceFileId/LineLo/Hi/Column into
; the CasmSourceResult* fields lexerFill now reads. Preserves A.
stampResultLoc:
    pha
    lda CasmSourceFileId
    sta CasmSourceResultFileId
    lda CasmSourceLineLo
    sta CasmSourceResultLineLo
    lda CasmSourceLineHi
    sta CasmSourceResultLineHi
    lda CasmSourceColumn
    sta CasmSourceResultColumn
    pla
    rts

diagSetLocFromLookahead:
    jsr copyLookaheadLoc
    lda CasmLookaheadByte
    sta CasmDiagLocByte
    lda #CASM_DIAG_LOC_BYTE
    sta CasmDiagLocValid
    rts
diagSetLocFromLookaheadPos:
    jsr copyLookaheadLoc
    lda #CASM_DIAG_LOC_VALID
    sta CasmDiagLocValid
    rts
copyLookaheadLoc:
    lda CasmLookaheadLineLo
    sta CasmDiagLocLineLo
    lda CasmLookaheadLineHi
    sta CasmDiagLocLineHi
    lda CasmLookaheadColumn
    sta CasmDiagLocColumn
    lda CasmLookaheadFileId
    sta CasmDiagLocFileId
    rts
diagSetLocFromToken:
    lda CasmTokenRecord + CASM_TOKEN_REC_LINE_LO
    sta CasmDiagLocLineLo
    lda CasmTokenRecord + CASM_TOKEN_REC_LINE_HI
    sta CasmDiagLocLineHi
    lda CasmTokenRecord + CASM_TOKEN_REC_COLUMN
    sta CasmDiagLocColumn
    lda CasmTokenRecord + CASM_TOKEN_REC_FILE_ID
    sta CasmDiagLocFileId
    lda #CASM_DIAG_LOC_VALID
    sta CasmDiagLocValid
    rts
diagStampStmtLoc:
    lda CasmTokenRecord + CASM_TOKEN_REC_LINE_LO
    sta CasmStmtLocLineLo
    lda CasmTokenRecord + CASM_TOKEN_REC_LINE_HI
    sta CasmStmtLocLineHi
    lda CasmTokenRecord + CASM_TOKEN_REC_COLUMN
    sta CasmStmtLocColumn
    lda CasmTokenRecord + CASM_TOKEN_REC_FILE_ID
    sta CasmStmtLocFileId
    rts

; Whole-object parser dependencies unreachable from include-only fixtures.
; WP65: exprParseNumeric/exprParseAddend/exprApplyAddend joins this list --
; parser.s's new ppsConstant references them, but this harness never parses
; an `identifier = expr` statement.
exprEvaluate:
symbolsLookup:
emitMarkStarted:
exprParseNumeric:
exprParseAddend:
exprApplyAddend:
    lda #CASM_DIAG_EXPR_UNSUPPORTED
    sec
    rts
exprGetResult:
    ldx #0
    ldy #0
    rts

.segment "RODATA"

.macro CASE script, scriptBytes, diag, length, expected, column
    .byte <script, >script, scriptBytes, diag, length, <expected, >expected
    .byte column
.endmacro

caseTable:
    CASE validOne,      13, 0, 1, expectedA, 0
    CASE validBounds,   17, 0, 6, expectedBounds, 0
    ; Finding D (task 42): the include filename cap dropped 63 -> 32. These
    ; two cases pin the new at-cap / over-cap boundary.
    CASE validCap,      44, 0, 32, expectedCap, 0
    CASE validSpace,    24, 0, 1, expectedA, 0
    CASE tooLong,       45, CASM_DIAG_INCLUDE_FILENAME_TOO_LONG, 0, emptyExpected, 43
    CASE emptyName,     12, CASM_DIAG_INVALID_INCLUDE_FILENAME, 0, emptyExpected, 10
    CASE unterminated,  12, CASM_DIAG_INVALID_INCLUDE_FILENAME, 0, emptyExpected, 10
    CASE missingName,   10, CASM_DIAG_INCLUDE_FILENAME_EXPECTED, 0, emptyExpected, 10
    CASE unquotedName,  11, CASM_DIAG_INCLUDE_FILENAME_EXPECTED, 0, emptyExpected, 10
    CASE invalidLow,    13, CASM_DIAG_INVALID_INCLUDE_FILENAME, 0, emptyExpected, 11
    CASE invalidGapLo,  13, CASM_DIAG_INVALID_INCLUDE_FILENAME, 0, emptyExpected, 11
    CASE invalidGapHi,  13, CASM_DIAG_INVALID_INCLUDE_FILENAME, 0, emptyExpected, 11
    CASE invalidFf,     13, CASM_DIAG_INVALID_INCLUDE_FILENAME, 0, emptyExpected, 11
    CASE trailingByte,  14, CASM_DIAG_EXPECTED_NEWLINE, 0, emptyExpected, 13

validOne:      .byte ".INCLUDE ", $22, "A", $22, $0D
validBounds:   .byte ".include", $09, $22, $20, $21, $23, $7E, $A0, $FE, $22
validSpace:    .byte ".INCLUDE  ", $22, "A", $22, $09, $20, ";COMMENT", $0D
validCap:      .byte ".INCLUDE ", $22
               .repeat 32
               .byte "A"
               .endrepeat
               .byte $22, $0D
tooLong:       .byte ".INCLUDE ", $22
               .repeat 33
               .byte "A"
               .endrepeat
               .byte $22, $0D
emptyName:     .byte ".INCLUDE ", $22, $22, $0D
unterminated:  .byte ".INCLUDE ", $22, "A", $0D
missingName:   .byte ".INCLUDE ", $0D
unquotedName:  .byte ".INCLUDE A", $0D
invalidLow:    .byte ".INCLUDE ", $22, $1F, $22, $0D
invalidGapLo:  .byte ".INCLUDE ", $22, $7F, $22, $0D
invalidGapHi:  .byte ".INCLUDE ", $22, $9F, $22, $0D
invalidFf:     .byte ".INCLUDE ", $22, $FF, $22, $0D
trailingByte:  .byte ".INCLUDE ", $22, "A", $22, "X", $0D

expectedA:      .byte "A"
expectedBounds: .byte $20, $21, $23, $7E, $A0, $FE
expectedCap:    .repeat 32
                .byte "A"
                .endrepeat
emptyExpected:

passMsg: .byte "CASM INCLUDE: ALL PASS", $0D, 0
failMsg: .byte "CASM INCLUDE: FAIL", $0D, 0
