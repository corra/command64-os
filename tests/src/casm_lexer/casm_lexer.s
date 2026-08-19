; tests/src/casm_lexer/casm_lexer.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 11 WP61 Increment 5: symbol/token name-length-32 boundary
; harness. Links real lexer.s only -- no parser.s/source.s/state.s -- and
; supplies CasmLexerState/CasmLookahead*/CasmTokenRecord/CasmTokenText/
; CasmIncludeFilename* as local BSS plus a local stub sourceNextByte
; feeding a fixed-length run of identifier bytes ('A', $41), matching
; casm_bounds.s's/casm_opcodes.s's own narrow-link precedent. No harness
; for lexer.s existed before this increment (confirmed by search).
;
; Drives the real lnId identifier-scan loop (lexer.s) through lexerNext,
; not lexerTokenAppend directly (lexerTokenAppend is private, unexported).
; Case 1 feeds exactly 31 bytes (CASM_TOKEN_TEXT_MAX) then EOF: accept,
; length recorded as exactly 31. Case 2 feeds exactly 32 bytes: the 32nd
; lexerTokenAppend call (lexer.s:527-528, "cpx #CASM_TOKEN_TEXT_MAX / bcs
; ltaTooLong") rejects with CASM_DIAG_TOKEN_TOO_LONG, propagated up through
; lnTokenTooLong (lexer.s ~872-875), and the already-accepted 31-byte
; payload must be left unmodified -- the rejected 32nd byte is never
; written.
;
; diagSetLocFromLookahead/diagSetLocFromLookaheadPos/diagSetLocFromToken
; are stubbed to plain no-ops locally: real diagnostics.s pulls in
; CasmStmtLoc*/lexer.s state transitively this harness's cases never
; exercise, matching every other narrow-link harness's stubbing precedent.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_lexer.inc"

.import __MAIN_START__
.import lexerInit
.import lexerNext
.import CasmStringLength
.import CasmStringBuffer

.export CasmLexerState
.export CasmLookaheadValid
.export CasmLookaheadResult
.export CasmLookaheadByte
.export CasmLookaheadFileId
.export CasmLookaheadLineLo
.export CasmLookaheadLineHi
.export CasmLookaheadColumn
.export CasmTokenRecord
.export CasmTokenText
.export CasmIncludeFilename
.export CasmIncludeFilenameLen
.export CasmDiagCapture
.export CasmSourceResultByte
.export CasmSourceResultFileId
.export CasmSourceResultLineLo
.export CasmSourceResultLineHi
.export CasmSourceResultColumn
; WP65: absolute-token-offset provenance, mirrored here since this harness
; supplies its own source-layer stand-in rather than linking source.s.
; Unused by this harness's own coverage (no `=` statements), but lexer.s
; now unconditionally references them (lexerFill/lexerTokenReset).
.export CasmSourceResultOffsetLo
.export CasmSourceResultOffsetHi
.export CasmLookaheadOffsetLo
.export CasmLookaheadOffsetHi
.export sourceNextByte
.export diagSetLocFromLookahead
.export diagSetLocFromLookaheadPos
.export diagSetLocFromToken

.segment "HEADER"
    .word __MAIN_START__

.segment "BSS"
CasmLexerState:       .res 1
CasmLookaheadValid:   .res 1
CasmLookaheadResult:  .res 1
CasmLookaheadByte:    .res 1
CasmLookaheadFileId:  .res 1
CasmLookaheadLineLo:  .res 1
CasmLookaheadLineHi:  .res 1
CasmLookaheadColumn:  .res 1
CasmTokenRecord:      .res CASM_TOKEN_REC_SIZE
CasmTokenText:        .res CASM_TOKEN_TEXT_BUFFER_SIZE
CasmIncludeFilename:      .res CASM_INCLUDE_FILENAME_BUFFER_SIZE
CasmIncludeFilenameLen:   .res 1
CasmDiagCapture:      .res 1
CasmSourceResultByte:    .res 1
CasmSourceResultFileId:  .res 1
CasmSourceResultLineLo:  .res 1
CasmSourceResultLineHi:  .res 1
CasmSourceResultColumn:  .res 1
CasmSourceResultOffsetLo: .res 1
CasmSourceResultOffsetHi: .res 1
CasmLookaheadOffsetLo:    .res 1
CasmLookaheadOffsetHi:    .res 1
BytesRemaining:       .res 1
FailCount:            .res 1
SourceMode:           .res 1
SourceIndex:          .res 1
ExpectedIndex:        .res 1

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda #0
    sta FailCount
    sta SourceMode

    jsr caseAccept31
    jsr reportCase
    jsr caseReject32
    jsr reportCase
    jsr caseOperators
    jsr reportCase
    jsr caseCharValid
    jsr reportCase
    jsr caseCharQuoteContent
    jsr reportCase
    jsr caseCharUnterminated
    jsr reportCase
    jsr caseCharInvalidByte
    jsr reportCase
    jsr caseStringEmpty
    jsr reportCase
    jsr caseStringRaw
    jsr reportCase
    jsr caseStringUnterminated
    jsr reportCase
    jsr caseStringNewline
    jsr reportCase
    jsr caseStringInvalid7f
    jsr reportCase
    jsr caseStringInvalidff
    jsr reportCase

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

; ---------------------------------------------------------------------------
; reportCase
; Print '.' for a pass (carry clear) or 'F' for a fail (carry set), tallying
; FailCount.
; ---------------------------------------------------------------------------
reportCase:
    bcs rcFail
    lda #$2E
    jsr KernalChROUT
    rts
rcFail:
    inc FailCount
    lda #$46
    jsr KernalChROUT
    rts

; ---------------------------------------------------------------------------
; caseAccept31
; Feed exactly CASM_TOKEN_TEXT_MAX (31) identifier bytes then EOF. Expect
; C clear, token length exactly 31.
; ---------------------------------------------------------------------------
caseAccept31:
    lda #CASM_TOKEN_TEXT_MAX
    sta BytesRemaining
    jsr lexerInit
    jsr lexerNext
    bcs ca31Fail
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    cmp #CASM_TOKEN_TEXT_MAX
    bne ca31Fail
    clc
    rts
ca31Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; caseReject32
; Feed exactly CASM_TOKEN_TEXT_MAX+1 (32) identifier bytes. Expect C set,
; A = CASM_DIAG_TOKEN_TOO_LONG, and the token length left at 31 (the
; rejected 32nd byte never committed).
; ---------------------------------------------------------------------------
caseReject32:
    lda #CASM_TOKEN_TEXT_MAX + 1
    sta BytesRemaining
    jsr lexerInit
    jsr lexerNext
    bcc cr32Fail
    cmp #CASM_DIAG_TOKEN_TOO_LONG
    bne cr32Fail
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    cmp #CASM_TOKEN_TEXT_MAX
    bne cr32Fail
    clc
    rts
cr32Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; caseOperators
; Feed every WP68 operator spelling through the real lexer. Single '<'/'>'
; must remain extraction tokens, doubled forms must consume two bytes into
; one shift token, and each token location must stay at its first byte.
; ---------------------------------------------------------------------------
caseOperators:
    lda #1
    sta SourceMode
    lda #0
    sta SourceIndex
    sta ExpectedIndex
    jsr lexerInit
coLoop:
    jsr lexerNext
    bcs coFail
    ldx ExpectedIndex
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp operatorExpected, x
    bne coFail
    inx
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    cmp operatorExpected, x
    bne coFail
    inx
    lda CasmTokenText
    cmp operatorExpected, x
    bne coFail
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    cmp #2
    bne coColumn
    lda CasmTokenText + 1
    cmp CasmTokenText
    bne coFail
    lda CasmTokenText + 2
    bne coFail
coColumn:
    inx
    lda CasmTokenRecord + CASM_TOKEN_REC_COLUMN
    cmp operatorExpected, x
    bne coFail
    inx
    stx ExpectedIndex
    cpx #OPERATOR_EXPECTED_SIZE
    bcc coLoop
    jsr lexerNext
    bcs coFail
    cmp #CASM_TOKEN_EOF
    bne coFail
    lda CasmTokenRecord + CASM_TOKEN_REC_COLUMN
    cmp #OPERATOR_SOURCE_SIZE
    bne coFail
    lda #0
    sta SourceMode
    clc
    rts
coFail:
    lda #0
    sta SourceMode
    sec
    rts

; ---------------------------------------------------------------------------
; caseCharValid
; 'A' -- CASM_TOKEN_CHAR, length 1, text[0] = 'A' (unshifted PETSCII, no
; case folding), then EOF.
; ---------------------------------------------------------------------------
caseCharValid:
    lda #2
    sta SourceMode
    lda #0
    sta SourceIndex
    jsr lexerInit
    jsr lexerNext
    bcs ccvFail
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_CHAR
    bne ccvFail
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    cmp #1
    bne ccvFail
    lda CasmTokenText
    cmp #CASM_PETSCII_UPPER_A
    bne ccvFail
    jsr lexerNext
    bcs ccvFail
    cmp #CASM_TOKEN_EOF
    bne ccvFail
    clc
    rts
ccvFail:
    sec
    rts

; ---------------------------------------------------------------------------
; caseCharQuoteContent
; ''' (three apostrophes) -- mechanically lexes as the quote byte itself as
; content, no special-casing needed (this WP's own minimalism scoping
; decision): opener, content byte (itself '), closer.
; ---------------------------------------------------------------------------
caseCharQuoteContent:
    lda #3
    sta SourceMode
    lda #0
    sta SourceIndex
    jsr lexerInit
    jsr lexerNext
    bcs ccqFail
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_CHAR
    bne ccqFail
    lda CasmTokenText
    cmp #CASM_PETSCII_APOSTROPHE
    bne ccqFail
    clc
    rts
ccqFail:
    sec
    rts

; ---------------------------------------------------------------------------
; caseCharUnterminated
; '' (two apostrophes) then EOF -- the second ' is consumed as the one
; content byte, no third ' follows: CASM_DIAG_CHAR_UNTERMINATED, not a
; separate "empty literal" diagnostic (not special-cased, per this WP's own
; minimalism scoping decision).
; ---------------------------------------------------------------------------
caseCharUnterminated:
    lda #4
    sta SourceMode
    lda #0
    sta SourceIndex
    jsr lexerInit
    jsr lexerNext
    bcc cuFail
    cmp #CASM_DIAG_CHAR_UNTERMINATED
    bne cuFail
    clc
    rts
cuFail:
    sec
    rts

; ---------------------------------------------------------------------------
; caseCharInvalidByte
; A control byte ($01) as content -- CASM_DIAG_CHAR_INVALID_BYTE (outside
; the existing printable-PETSCII range .INCLUDE filenames already enforce).
; ---------------------------------------------------------------------------
caseCharInvalidByte:
    lda #5
    sta SourceMode
    lda #0
    sta SourceIndex
    jsr lexerInit
    jsr lexerNext
    bcc cibFail
    cmp #CASM_DIAG_CHAR_INVALID_BYTE
    bne cibFail
    clc
    rts
cibFail:
    sec
    rts

caseStringEmpty:
    lda #6
    jsr stringCaseInit
    jsr lexerNext
    bcs stringCaseFail
    cmp #CASM_TOKEN_STRING
    bne stringCaseFail
    lda CasmStringLength
    bne stringCaseFail
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    bne stringCaseFail
    clc
    rts

caseStringRaw:
    lda #7
    jsr stringCaseInit
    jsr lexerNext
    bcs stringCaseFail
    cmp #CASM_TOKEN_STRING
    bne stringCaseFail
    lda CasmStringLength
    cmp #5
    bne stringCaseFail
    ldx #4
@loop:
    lda CasmStringBuffer, x
    cmp stringRawExpected, x
    bne stringCaseFail
    dex
    bpl @loop
    clc
    rts

caseStringUnterminated:
    lda #8
    ldx #CASM_DIAG_STRING_UNTERMINATED
    jmp stringCaseDiagnostic

caseStringNewline:
    lda #9
    ldx #CASM_DIAG_STRING_UNTERMINATED
    jmp stringCaseDiagnostic

caseStringInvalid7f:
    lda #10
    ldx #CASM_DIAG_STRING_INVALID_BYTE
    jmp stringCaseDiagnostic

caseStringInvalidff:
    lda #11
    ldx #CASM_DIAG_STRING_INVALID_BYTE
stringCaseDiagnostic:
    stx ExpectedIndex
    jsr stringCaseInit
    jsr lexerNext
    bcc stringCaseFail
    cmp ExpectedIndex
    bne stringCaseFail
    clc
    rts

stringCaseInit:
    sta SourceMode
    lda #0
    sta SourceIndex
    jmp lexerInit
stringCaseFail:
    sec
    rts

; ---------------------------------------------------------------------------
; sourceNextByte (stub)
; Returns CASM_PETSCII_UPPER_A once per remaining byte in BytesRemaining,
; then CASM_SOURCE_EOF. Matches source.s's real CASM_SOURCE_BYTE/EOF
; result-record contract (CasmSourceResultByte/FileId/LineLo/Hi/Column),
; the only part of it lexer.s's lnId loop and lexerFill observe.
; ---------------------------------------------------------------------------
sourceNextByte:
    lda SourceMode
    bne :+
    jmp snbRepeatA
:
    cmp #1
    beq snbOperatorMode
    cmp #2
    beq snbCharValidMode
    cmp #3
    beq snbCharQuoteMode
    cmp #4
    beq snbCharUntermMode
    cmp #5
    beq snbCharInvalidMode
    jmp snbStringMode

snbOperatorMode:
    ldx SourceIndex
    cpx #OPERATOR_SOURCE_SIZE
    bcc :+
    jmp snbEof
:
    lda operatorSource, x
    jmp snbEmitTableByte
snbCharValidMode:
    ldx SourceIndex
    cpx #CHAR_VALID_SOURCE_SIZE
    bcc :+
    jmp snbEof
:
    lda charValidSource, x
    jmp snbEmitTableByte
snbCharQuoteMode:
    ldx SourceIndex
    cpx #CHAR_QUOTE_SOURCE_SIZE
    bcc :+
    jmp snbEof
:
    lda charQuoteSource, x
    jmp snbEmitTableByte
snbCharUntermMode:
    ldx SourceIndex
    cpx #CHAR_UNTERM_SOURCE_SIZE
    bcc :+
    jmp snbEof
:
    lda charUntermSource, x
    jmp snbEmitTableByte
snbCharInvalidMode:
    ldx SourceIndex
    cpx #CHAR_INVALID_SOURCE_SIZE
    bcc :+
    jmp snbEof
:
    lda charInvalidSource, x
    jmp snbEmitTableByte
snbStringMode:
    sec
    sbc #6
    tax
    lda stringSourceLo, x
    sta CasmPtr0Lo
    lda stringSourceHi, x
    sta CasmPtr0Hi
    lda stringSourceSize, x
    cmp SourceIndex
    beq snbStringEnd
    bcc snbStringEnd
    ldy SourceIndex
    lda (CasmPtr0Lo), y
    cmp #$0D
    beq snbStringNewline
    ldx SourceIndex
    jmp snbEmitTableByte
snbStringNewline:
    inc SourceIndex
    lda #CASM_SOURCE_NEWLINE
    clc
    rts
snbStringEnd:
    jmp snbEof
snbEmitTableByte:
    sta CasmSourceResultByte
    lda #0
    sta CasmSourceResultFileId
    sta CasmSourceResultLineHi
    txa
    sta CasmSourceResultColumn
    sta CasmSourceResultOffsetLo
    lda #0
    sta CasmSourceResultOffsetHi
    lda #1
    sta CasmSourceResultLineLo
    inc SourceIndex
    lda #CASM_SOURCE_BYTE
    clc
    rts
snbRepeatA:
    lda BytesRemaining
    bne snbHaveByte
snbEof:
    lda #0
    sta CasmSourceResultByte
    sta CasmSourceResultFileId
    sta CasmSourceResultLineLo
    sta CasmSourceResultLineHi
    sta CasmSourceResultColumn
    sta CasmSourceResultOffsetLo
    sta CasmSourceResultOffsetHi
    lda SourceMode
    beq snbEofReady
    lda #1
    sta CasmSourceResultLineLo
    lda SourceIndex
    sta CasmSourceResultColumn
    sta CasmSourceResultOffsetLo
snbEofReady:
    lda #CASM_SOURCE_EOF
    clc
    rts
snbHaveByte:
    dec BytesRemaining
    lda #CASM_PETSCII_UPPER_A
    sta CasmSourceResultByte
    lda #0
    sta CasmSourceResultFileId
    sta CasmSourceResultLineLo
    sta CasmSourceResultLineHi
    sta CasmSourceResultColumn
    lda #CASM_SOURCE_BYTE
    clc
    rts

; ---------------------------------------------------------------------------
; diagSetLocFromLookahead / diagSetLocFromLookaheadPos / diagSetLocFromToken
; (stubs)
; No-ops: neither case here inspects diagnostic location state.
; ---------------------------------------------------------------------------
diagSetLocFromLookahead:
    rts
diagSetLocFromLookaheadPos:
    rts
diagSetLocFromToken:
    rts

.segment "RODATA"

operatorSource:
    .byte CASM_PETSCII_LESS, CASM_PETSCII_SPACE
    .byte CASM_PETSCII_LESS, CASM_PETSCII_LESS, CASM_PETSCII_SPACE
    .byte CASM_PETSCII_GREATER, CASM_PETSCII_SPACE
    .byte CASM_PETSCII_GREATER, CASM_PETSCII_GREATER, CASM_PETSCII_SPACE
    .byte CASM_PETSCII_SLASH, CASM_PETSCII_SPACE
    .byte CASM_PETSCII_AMPERSAND, CASM_PETSCII_SPACE
    .byte CASM_PETSCII_CARET, CASM_PETSCII_SPACE
    .byte CASM_PETSCII_PIPE, CASM_PETSCII_SPACE
    .byte CASM_PETSCII_TILDE, CASM_PETSCII_SPACE
    .byte CASM_PETSCII_ASTERISK, CASM_PETSCII_SPACE, CASM_PETSCII_MINUS
OPERATOR_SOURCE_SIZE = * - operatorSource

; token type, text length, first text byte, source column
operatorExpected:
    .byte CASM_TOKEN_LESS,      1, CASM_PETSCII_LESS,       0
    .byte CASM_TOKEN_SHL,       2, CASM_PETSCII_LESS,       2
    .byte CASM_TOKEN_GREATER,   1, CASM_PETSCII_GREATER,    5
    .byte CASM_TOKEN_SHR,       2, CASM_PETSCII_GREATER,    7
    .byte CASM_TOKEN_SLASH,     1, CASM_PETSCII_SLASH,     10
    .byte CASM_TOKEN_AMPERSAND, 1, CASM_PETSCII_AMPERSAND, 12
    .byte CASM_TOKEN_CARET,     1, CASM_PETSCII_CARET,     14
    .byte CASM_TOKEN_PIPE,      1, CASM_PETSCII_PIPE,      16
    .byte CASM_TOKEN_TILDE,     1, CASM_PETSCII_TILDE,     18
    .byte CASM_TOKEN_STAR,      1, CASM_PETSCII_ASTERISK,  20
    .byte CASM_TOKEN_MINUS,     1, CASM_PETSCII_MINUS,     22
OPERATOR_EXPECTED_SIZE = * - operatorExpected
.assert OPERATOR_EXPECTED_SIZE = 11 * 4, error, "WP68 lexer operator fixture count changed"

; WP69 character-literal sources.
charValidSource:
    .byte CASM_PETSCII_APOSTROPHE, CASM_PETSCII_UPPER_A, CASM_PETSCII_APOSTROPHE
CHAR_VALID_SOURCE_SIZE = * - charValidSource
charQuoteSource:
    ; ''' -- opener, content (the quote byte itself), closer.
    .byte CASM_PETSCII_APOSTROPHE, CASM_PETSCII_APOSTROPHE, CASM_PETSCII_APOSTROPHE
CHAR_QUOTE_SOURCE_SIZE = * - charQuoteSource
charUntermSource:
    ; '' -- opener, then the second ' consumed as the one content byte;
    ; table exhausted (EOF) before a third ' can close it.
    .byte CASM_PETSCII_APOSTROPHE, CASM_PETSCII_APOSTROPHE
CHAR_UNTERM_SOURCE_SIZE = * - charUntermSource
charInvalidSource:
    ; opener, a control byte ($01, outside the printable range), closer
    ; (never reached -- rejected at the content byte itself).
    .byte CASM_PETSCII_APOSTROPHE, $01, CASM_PETSCII_APOSTROPHE
CHAR_INVALID_SOURCE_SIZE = * - charInvalidSource

stringEmptySource: .byte CASM_PETSCII_QUOTE, CASM_PETSCII_QUOTE
stringRawSource:
    .byte CASM_PETSCII_QUOTE, $41, $7E, $A0, $FE, $20, CASM_PETSCII_QUOTE
stringRawExpected: .byte $41, $7E, $A0, $FE, $20
stringUntermSource: .byte CASM_PETSCII_QUOTE, $41
stringNewlineSource: .byte CASM_PETSCII_QUOTE, $41, $0D
stringInvalid7fSource: .byte CASM_PETSCII_QUOTE, $7F, CASM_PETSCII_QUOTE
stringInvalidffSource: .byte CASM_PETSCII_QUOTE, $FF, CASM_PETSCII_QUOTE
stringSourceLo:
    .byte <stringEmptySource, <stringRawSource, <stringUntermSource
    .byte <stringNewlineSource, <stringInvalid7fSource, <stringInvalidffSource
stringSourceHi:
    .byte >stringEmptySource, >stringRawSource, >stringUntermSource
    .byte >stringNewlineSource, >stringInvalid7fSource, >stringInvalidffSource
stringSourceSize:
    .byte 2, 7, 2, 3, 3, 3

passMsg:
    .byte "CASM LEXER: PASS", PetCr, 0
failMsg:
    .byte "CASM LEXER: FAIL", PetCr, 0
