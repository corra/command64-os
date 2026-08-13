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
BytesRemaining:       .res 1
FailCount:            .res 1

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda #0
    sta FailCount

    jsr caseAccept31
    jsr reportCase
    jsr caseReject32
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
; sourceNextByte (stub)
; Returns CASM_PETSCII_UPPER_A once per remaining byte in BytesRemaining,
; then CASM_SOURCE_EOF. Matches source.s's real CASM_SOURCE_BYTE/EOF
; result-record contract (CasmSourceResultByte/FileId/LineLo/Hi/Column),
; the only part of it lexer.s's lnId loop and lexerFill observe.
; ---------------------------------------------------------------------------
sourceNextByte:
    lda BytesRemaining
    bne snbHaveByte
    lda #0
    sta CasmSourceResultByte
    sta CasmSourceResultFileId
    sta CasmSourceResultLineLo
    sta CasmSourceResultLineHi
    sta CasmSourceResultColumn
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

passMsg:
    .byte "CASM LEXER: PASS", PetCr, 0
failMsg:
    .byte "CASM LEXER: FAIL", PetCr, 0
