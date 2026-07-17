; src/external/casm/lexer.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 3 WP7 minimal lexer core. This module is the first consumer of the
; WP4-WP6 source layer. It owns the one-result lookahead and the token record in
; state.s, consumes the normalized byte stream through sourceNextByte, skips
; whitespace and semicolon comments (preserving the terminating newline token),
; and emits EOF, newline, and the punctuation/delimiter tokens with file, line,
; and column provenance captured before each token's first byte is consumed.
;
; WP7 does not scan identifiers, directives, registers, or numbers (WP8),
; classify mnemonics (WP9), or wire the token dump into the entry point (WP10).
; Any byte it cannot yet classify hits a single not-implemented default arm that
; WP8 will replace. This translation unit defines no BSS and never closes the
; source: a lexer failure is returned to orchestration with carry set.

.include "common.inc"

; Lexer/lookahead/token subrecord (storage-only state.s).
.import CasmLexerState
.import CasmLookaheadValid
.import CasmLookaheadResult
.import CasmLookaheadByte
.import CasmLookaheadFileId
.import CasmLookaheadLineLo
.import CasmLookaheadLineHi
.import CasmLookaheadColumn
.import CasmTokenRecord
.import CasmTokenText

; Source layer: the byte stream and its in-place location fields.
.import sourceNextByte
.import CasmSourceResultByte
.import CasmSourceFileId
.import CasmSourceLineLo
.import CasmSourceLineHi
.import CasmSourceColumn

.export lexerInit
.export lexerNext
.export lexerGetToken

.segment "CODE"

; ---------------------------------------------------------------------------
; lexerInit
; Reset the lexer to READY, invalidate the lookahead, and clear the token
; record. Orchestration calls this at startup and again after any successful
; sourceRewind (source.s writes no lexer state, so the lexer owns invalidating
; its lookahead across a rewind).
;
; Inputs:    source initialized/open
; Outputs:   A = CASM_DIAG_NONE, C clear
; Preserves: none
; Clobbers:  A and flags
; Scratch:   none
; ---------------------------------------------------------------------------
lexerInit:
    lda #CASM_LEXER_STATE_READY
    sta CasmLexerState
    lda #0
    sta CasmLookaheadValid
    sta CasmTokenRecord + CASM_TOKEN_REC_TYPE
    sta CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    sta CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    sta CasmTokenText
    lda #CASM_DIAG_NONE
    clc
    rts

; ---------------------------------------------------------------------------
; lexerNext
; Produce exactly one significant token in CasmTokenRecord. Whitespace and
; semicolon comments are skipped; the newline terminating a comment is still
; returned. EOF is a repeat-stable token.
;
; Inputs:    lexer READY or EOF
; Outputs:   Token: C clear, A = token type; token in CasmTokenRecord
;            Fail:  C set, A = CASM_DIAG_LEXER_STATE_FAILED, _TOKEN_TOO_LONG,
;                   _NOT_IMPLEMENTED, or a propagated source diagnostic; lexer
;                   ERROR; source left open for orchestration
; Preserves: none
; Clobbers:  A, X, Y, CasmLexerScratch0/1, source volatile state
; Scratch:   none persistent
; ---------------------------------------------------------------------------
lexerNext:
    lda CasmLexerState
    cmp #CASM_LEXER_STATE_READY
    beq lnSkip
    cmp #CASM_LEXER_STATE_EOF
    bne lnBadStateJmp
    ; Repeat-stable EOF: the EOF token already sits in CasmTokenRecord.
    lda #CASM_TOKEN_EOF
    clc
    rts
lnBadStateJmp:
    jmp lnBadState              ; shared failure tail is out of branch range

lnSkip:
    jsr lexerFill
    bcc @okFill
    jmp lnFail
@okFill:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_NEWLINE
    bne @notNewline
    jmp lnNewline
@notNewline:
    cmp #CASM_SOURCE_EOF
    bne @notEof
    jmp lnEof
@notEof:

    ; BYTE result: whitespace and comments are skipped; punctuation is emitted.
    lda CasmLookaheadByte
    cmp #CASM_PETSCII_SPACE
    beq lnSkipByte
    cmp #CASM_PETSCII_TAB
    beq lnSkipByte
    cmp #CASM_PETSCII_SEMICOLON
    beq lnComment
    jsr lexerClassifyPunct
    bcc lnPunct

    ; Check if it's a directive (.)
    lda CasmLookaheadByte
    cmp #CASM_PETSCII_DOT
    beq lnDirectiveJmp

    ; Check if it's a hex number ($)
    cmp #CASM_PETSCII_DOLLAR
    beq lnHexJmp

    ; Check if it's a binary number (%)
    cmp #CASM_PETSCII_PERCENT
    beq lnBinJmp

    ; Check if it's a decimal number (0-9)
    jsr isDecDigit
    bcc lnDecJmp

    ; Check if it's an identifier first character (A-Z, a-z, _)
    jsr isIdFirst
    bcc lnIdJmp

    ; None of the above: invalid source byte!
    lda #CASM_DIAG_INVALID_SOURCE_BYTE
    jmp lnFailWithA

lnDirectiveJmp:
    jmp lnDirective
lnHexJmp:
    jmp lnHex
lnBinJmp:
    jmp lnBin
lnDecJmp:
    jmp lnDec
lnIdJmp:
    jmp lnId

lnSkipByte:
    jsr lexerConsume
    jmp lnSkip

lnComment:
    jsr lexerConsume            ; consume the ';'
lnCommentBody:
    jsr lexerFill
    bcc @okComment
    jmp lnFail
@okComment:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_NEWLINE
    beq lnSkip                  ; preserve the newline; re-dispatch emits it
    cmp #CASM_SOURCE_EOF
    beq lnSkip                  ; preserve EOF; re-dispatch emits it
    jsr lexerConsume            ; consume a comment-body byte
    jmp lnCommentBody

lnPunct:
    ; A = token type from lexerClassifyPunct.
    pha
    jsr lexerTokenReset
    lda CasmLookaheadByte
    jsr lexerTokenAppend
    bcs lnPunctAppendFail
    jsr lexerConsume
    pla
    jmp lexerEmit               ; returns C clear, A = token type
lnPunctAppendFail:
    pla                         ; discard the saved type
    lda #CASM_DIAG_TOKEN_TOO_LONG
    jmp lnFailWithA

lnNewline:
    jsr lexerTokenReset
    jsr lexerConsume
    lda #CASM_TOKEN_NEWLINE
    jmp lexerEmit

lnEof:
    ; Latch a repeat-stable EOF token. The EOF lookahead is left valid; a later
    ; lexerInit (e.g. after rewind) clears it.
    jsr lexerTokenReset
    lda #CASM_LEXER_STATE_EOF
    sta CasmLexerState
    lda #CASM_TOKEN_EOF
    jmp lexerEmit

lnFail:
    ; A holds the propagated source diagnostic; lexer already ERROR.
    sec
    rts
lnFailWithA:
    pha
    lda #CASM_LEXER_STATE_ERROR
    sta CasmLexerState
    pla
    sec
    rts
lnBadState:
    lda #CASM_LEXER_STATE_ERROR
    sta CasmLexerState
    lda #CASM_DIAG_LEXER_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; lexerGetToken
; Return the address of the current token record.
;
; Inputs:    a token has been produced
; Outputs:   X = CasmTokenRecord low, Y = CasmTokenRecord high, C clear
; Preserves: the token record
; Clobbers:  A, X, Y, flags
; ---------------------------------------------------------------------------
lexerGetToken:
    ldx #<CasmTokenRecord
    ldy #>CasmTokenRecord
    clc
    rts

; ---------------------------------------------------------------------------
; lexerFill (private)
; Ensure the one-result lookahead is valid. Provenance is captured before the
; byte is consumed by reading the source's in-place location fields (the
; documented sourceGetLocation accessor surface); the column-exhausted latch
; (source column 0) is clamped to CASM_SOURCE_COLUMN_MAX, and actual column
; overflow stays enforced by sourceNextByte.
;
; Inputs:    lexer READY
; Outputs:   C clear when a result is buffered; C set with A = source diagnostic
;            and lexer ERROR on a source failure
; Preserves: none
; Clobbers:  A, X, Y, source volatile state on a fetch
; ---------------------------------------------------------------------------
lexerFill:
    lda CasmLookaheadValid
    bne lfValid
    lda CasmSourceFileId
    sta CasmLookaheadFileId
    lda CasmSourceLineLo
    sta CasmLookaheadLineLo
    lda CasmSourceLineHi
    sta CasmLookaheadLineHi
    lda CasmSourceColumn
    bne lfColumnStore
    lda #CASM_SOURCE_COLUMN_MAX  ; exhausted latch -> report the max column
lfColumnStore:
    sta CasmLookaheadColumn
    jsr sourceNextByte
    bcs lfFail
    sta CasmLookaheadResult
    lda CasmSourceResultByte
    sta CasmLookaheadByte
    lda #1
    sta CasmLookaheadValid
lfValid:
    clc
    rts
lfFail:
    pha
    lda #CASM_LEXER_STATE_ERROR
    sta CasmLexerState
    pla
    sec
    rts

; ---------------------------------------------------------------------------
; lexerConsume (private)
; Invalidate the lookahead so the next lexerFill advances the source.
; ---------------------------------------------------------------------------
lexerConsume:
    lda #0
    sta CasmLookaheadValid
    rts

; ---------------------------------------------------------------------------
; lexerTokenReset (private)
; Copy the lookahead provenance into the token record and set length 0.
; ---------------------------------------------------------------------------
lexerTokenReset:
    lda CasmLookaheadFileId
    sta CasmTokenRecord + CASM_TOKEN_REC_FILE_ID
    lda CasmLookaheadLineLo
    sta CasmTokenRecord + CASM_TOKEN_REC_LINE_LO
    lda CasmLookaheadLineHi
    sta CasmTokenRecord + CASM_TOKEN_REC_LINE_HI
    lda CasmLookaheadColumn
    sta CasmTokenRecord + CASM_TOKEN_REC_COLUMN
    lda #0
    sta CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    rts

; ---------------------------------------------------------------------------
; lexerTokenAppend (private)
; Append one byte to the token text, bounded to CASM_TOKEN_TEXT_MAX payload
; bytes. WP7's own tokens are one byte; WP8 exercises the overflow path.
;
; Inputs:    A = byte to append
; Outputs:   C clear on success; C set with A = CASM_DIAG_TOKEN_TOO_LONG when the
;            payload already holds 31 bytes
; ---------------------------------------------------------------------------
lexerTokenAppend:
    ldx CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    cpx #CASM_TOKEN_TEXT_MAX
    bcs ltaTooLong
    sta CasmTokenText, x
    inx
    stx CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    clc
    rts
ltaTooLong:
    lda #CASM_DIAG_TOKEN_TOO_LONG
    sec
    rts

; ---------------------------------------------------------------------------
; lexerEmit (private)
; Finalize the current token: set the type and CASM_SUBTYPE_NONE and terminate
; the text at [length]. Returns the token type.
;
; Inputs:    A = token type
; Outputs:   C clear, A = token type
; ---------------------------------------------------------------------------
lexerEmit:
    sta CasmTokenRecord + CASM_TOKEN_REC_TYPE
    lda #CASM_SUBTYPE_NONE
    sta CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    ldx CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    lda #0
    sta CasmTokenText, x
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    clc
    rts

; ---------------------------------------------------------------------------
; lexerClassifyPunct (private)
; Map CasmLookaheadByte to its punctuation token type.
;
; Outputs:   C clear, A = token type when the byte is a delimiter; C set when it
;            is not
; ---------------------------------------------------------------------------
lexerClassifyPunct:
    ldx #0
lcpLoop:
    lda lexerPunctBytes, x
    bmi lcpNotFound             ; $FF sentinel (no delimiter byte has bit 7 set)
    cmp CasmLookaheadByte
    beq lcpFound
    inx
    jmp lcpLoop
lcpFound:
    lda lexerPunctTypes, x
    clc
    rts
lcpNotFound:
    sec
    rts

; ---------------------------------------------------------------------------
; WP8 Scanner Jumps and Helpers
; ---------------------------------------------------------------------------

CASM_PETSCII_DOLLAR = $24
CASM_PETSCII_UPPER_X = $58
CASM_PETSCII_UPPER_Y = $59

lnDirective:
    jsr lexerTokenReset
    lda CasmLookaheadByte
    jsr lexerTokenAppend
    bcc @ok1
    jmp lnTokenTooLong
@ok1:
    jsr lexerConsume            ; consume '.'
@dirLoop:
    jsr lexerFill
    bcc @ok2
    jmp lnFail
@ok2:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_EOF
    beq @dirDone
    cmp #CASM_SOURCE_NEWLINE
    beq @dirDone
    lda CasmLookaheadByte
    jsr isIdCont
    bcs @dirDone
    jsr lexerTokenAppend
    bcc @ok3
    jmp lnTokenTooLong
@ok3:
    jsr lexerConsume
    jmp @dirLoop
@dirDone:
    ldx #<dirOrgStr
    ldy #>dirOrgStr
    jsr compareTokenText
    bcs @notOrg
    lda #CASM_TOKEN_DIRECTIVE
    ldx #CASM_DIRECTIVE_ORG
    jmp lexerEmitWithSubtype
@notOrg:
    ldx #<dirByteStr
    ldy #>dirByteStr
    jsr compareTokenText
    bcs @notByte
    lda #CASM_TOKEN_DIRECTIVE
    ldx #CASM_DIRECTIVE_BYTE
    jmp lexerEmitWithSubtype
@notByte:
    ldx #<dirWordStr
    ldy #>dirWordStr
    jsr compareTokenText
    bcs @notWord
    lda #CASM_TOKEN_DIRECTIVE
    ldx #CASM_DIRECTIVE_WORD
    jmp lexerEmitWithSubtype
@notWord:
    ldx #<dirIncludeStr
    ldy #>dirIncludeStr
    jsr compareTokenText
    bcs @notInclude
    lda #CASM_TOKEN_DIRECTIVE
    ldx #CASM_DIRECTIVE_INCLUDE
    jmp lexerEmitWithSubtype
@notInclude:
    ldx #<dirStaticStr
    ldy #>dirStaticStr
    jsr compareTokenText
    bcs @notStatic
    lda #CASM_TOKEN_DIRECTIVE
    ldx #CASM_DIRECTIVE_STATIC
    jmp lexerEmitWithSubtype
@notStatic:
    ldx #<dirRelocStr
    ldy #>dirRelocStr
    jsr compareTokenText
    bcs @notReloc
    lda #CASM_TOKEN_DIRECTIVE
    ldx #CASM_DIRECTIVE_RELOC
    jmp lexerEmitWithSubtype
@notReloc:
    lda #CASM_TOKEN_DIRECTIVE
    ldx #CASM_DIRECTIVE_UNKNOWN
    jmp lexerEmitWithSubtype

lnHex:
    jsr lexerTokenReset
    lda CasmLookaheadByte
    jsr lexerTokenAppend
    bcc @ok1
    jmp lnTokenTooLong
@ok1:
    jsr lexerConsume            ; consume '$'
    jsr lexerFill
    bcc @ok2
    jmp lnFail
@ok2:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_EOF
    beq lnMalformedHex
    cmp #CASM_SOURCE_NEWLINE
    beq lnMalformedHex
    lda CasmLookaheadByte
    jsr isHexDigit
    bcs lnMalformedHex
@hexLoop:
    jsr lexerTokenAppend
    bcc @ok3
    jmp lnTokenTooLong
@ok3:
    jsr lexerConsume
    jsr lexerFill
    bcc @ok4
    jmp lnFail
@ok4:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_EOF
    beq @hexDone
    cmp #CASM_SOURCE_NEWLINE
    beq @hexDone
    lda CasmLookaheadByte
    jsr isHexDigit
    bcc @hexLoop
    jsr isIdCont
    bcc lnMalformedHex
@hexDone:
    lda #CASM_TOKEN_NUMBER
    ldx #CASM_NUMBER_HEX
    jmp lexerEmitWithSubtype

lnMalformedHex:
    jmp lnMalformedNum

lnBin:
    jsr lexerTokenReset
    lda CasmLookaheadByte
    jsr lexerTokenAppend
    bcc @ok1
    jmp lnTokenTooLong
@ok1:
    jsr lexerConsume            ; consume '%'
    jsr lexerFill
    bcc @ok2
    jmp lnFail
@ok2:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_EOF
    beq lnMalformedBin
    cmp #CASM_SOURCE_NEWLINE
    beq lnMalformedBin
    lda CasmLookaheadByte
    jsr isBinDigit
    bcs lnMalformedBin
@binLoop:
    jsr lexerTokenAppend
    bcc @ok3
    jmp lnTokenTooLong
@ok3:
    jsr lexerConsume
    jsr lexerFill
    bcc @ok4
    jmp lnFail
@ok4:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_EOF
    beq @binDone
    cmp #CASM_SOURCE_NEWLINE
    beq @binDone
    lda CasmLookaheadByte
    jsr isBinDigit
    bcc @binLoop
    jsr isIdCont
    bcc lnMalformedBin
@binDone:
    lda #CASM_TOKEN_NUMBER
    ldx #CASM_NUMBER_BINARY
    jmp lexerEmitWithSubtype

lnMalformedBin:
    jmp lnMalformedNum

lnDec:
    jsr lexerTokenReset
@decLoop:
    lda CasmLookaheadByte
    jsr lexerTokenAppend
    bcc @ok1
    jmp lnTokenTooLong
@ok1:
    jsr lexerConsume
    jsr lexerFill
    bcc @ok2
    jmp lnFail
@ok2:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_EOF
    beq @decDone
    cmp #CASM_SOURCE_NEWLINE
    beq @decDone
    lda CasmLookaheadByte
    jsr isDecDigit
    bcc @decLoop
    jsr isIdCont
    bcc lnMalformedDec
@decDone:
    lda #CASM_TOKEN_NUMBER
    ldx #CASM_NUMBER_DECIMAL
    jmp lexerEmitWithSubtype

lnMalformedDec:
    jmp lnMalformedNum

lnMalformedNum:
@malLoop:
    jsr lexerFill
    bcc @ok
    jmp lnFail
@ok:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_EOF
    beq @malDone
    cmp #CASM_SOURCE_NEWLINE
    beq @malDone
    lda CasmLookaheadByte
    jsr isIdCont
    bcs @malDone
    jsr lexerConsume
    jmp @malLoop
@malDone:
    lda #CASM_DIAG_MALFORMED_NUMBER
    jmp lnFailWithA

lnId:
    jsr lexerTokenReset
@idLoop:
    lda CasmLookaheadByte
    jsr lexerTokenAppend
    bcc @ok1
    jmp lnTokenTooLong
@ok1:
    jsr lexerConsume
    jsr lexerFill
    bcc @ok2
    jmp lnFail
@ok2:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_EOF
    beq @idDone
    cmp #CASM_SOURCE_NEWLINE
    beq @idDone
    lda CasmLookaheadByte
    jsr isIdCont
    bcc @idLoop
@idDone:
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    cmp #1
    bne @notReg
    lda CasmTokenText
    jsr normalizeChar
    cmp #CASM_PETSCII_UPPER_A
    bne @notA
    lda #CASM_TOKEN_REGISTER
    ldx #CASM_REGISTER_A
    jmp lexerEmitWithSubtype
@notA:
    cmp #CASM_PETSCII_UPPER_X
    bne @notX
    lda #CASM_TOKEN_REGISTER
    ldx #CASM_REGISTER_X
    jmp lexerEmitWithSubtype
@notX:
    cmp #CASM_PETSCII_UPPER_Y
    bne @notY
    lda #CASM_TOKEN_REGISTER
    ldx #CASM_REGISTER_Y
    jmp lexerEmitWithSubtype
@notY:
@notReg:
    lda #CASM_TOKEN_IDENTIFIER
    jmp lexerEmit

lnTokenTooLong:
    lda #CASM_DIAG_TOKEN_TOO_LONG
    jmp lnFailWithA

lexerEmitWithSubtype:
    sta CasmTokenRecord + CASM_TOKEN_REC_TYPE
    stx CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    ldx CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    lda #0
    sta CasmTokenText, x
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    clc
    rts

; ---------------------------------------------------------------------------
; Helpers
; ---------------------------------------------------------------------------

isIdFirst:
    cmp #CASM_PETSCII_UNDERSCORE
    beq @yes
    cmp #CASM_PETSCII_UPPER_A
    bcc @notUn
    cmp #CASM_PETSCII_UPPER_Z + 1
    bcc @yes
@notUn:
    cmp #CASM_PETSCII_SHIFTED_A
    bcc @no
    cmp #CASM_PETSCII_SHIFTED_Z + 1
    bcc @yes
@no:
    sec
    rts
@yes:
    clc
    rts

isIdCont:
    jsr isIdFirst
    bcc @yes
    cmp #CASM_PETSCII_DIGIT_0
    bcc @no
    cmp #CASM_PETSCII_DIGIT_9 + 1
    bcc @yes
@no:
    sec
    rts
@yes:
    clc
    rts

isHexDigit:
    cmp #CASM_PETSCII_DIGIT_0
    bcc @notDig
    cmp #CASM_PETSCII_DIGIT_9 + 1
    bcc @yes
@notDig:
    cmp #CASM_PETSCII_UPPER_A
    bcc @notUn
    cmp #CASM_PETSCII_UPPER_A + 6
    bcc @yes
@notUn:
    cmp #CASM_PETSCII_SHIFTED_A
    bcc @no
    cmp #CASM_PETSCII_SHIFTED_A + 6
    bcc @yes
@no:
    sec
    rts
@yes:
    clc
    rts

isBinDigit:
    cmp #CASM_PETSCII_DIGIT_0
    beq @yes
    cmp #CASM_PETSCII_DIGIT_0 + 1
    beq @yes
    sec
    rts
@yes:
    clc
    rts

isDecDigit:
    cmp #CASM_PETSCII_DIGIT_0
    bcc @no
    cmp #CASM_PETSCII_DIGIT_9 + 1
    bcc @yes
@no:
    sec
    rts
@yes:
    clc
    rts

normalizeChar:
    cmp #CASM_PETSCII_SHIFTED_A
    bcc @done
    cmp #CASM_PETSCII_SHIFTED_Z + 1
    bcs @done
    and #$7F
@done:
    rts

compareTokenText:
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldy #0
@loop:
    lda (CasmPtr0Lo), y
    tax
    lda CasmTokenText, y
    bne @checkExp
    cpx #0
    beq @match
    bne @mismatch
@checkExp:
    cpx #0
    beq @mismatch
    jsr normalizeChar
    pha
    txa
    jsr normalizeChar
    sta CasmLexerScratch0
    pla
    cmp CasmLexerScratch0
    bne @mismatch
    iny
    jmp @loop
@match:
    clc
    rts
@mismatch:
    sec
    rts

.segment "RODATA"

lexerPunctBytes:
    .byte CASM_PETSCII_COMMA, CASM_PETSCII_COLON, CASM_PETSCII_HASH
    .byte CASM_PETSCII_LPAREN, CASM_PETSCII_RPAREN, CASM_PETSCII_PLUS
    .byte CASM_PETSCII_MINUS, CASM_PETSCII_LESS, CASM_PETSCII_GREATER
    .byte $FF
lexerPunctTypes:
    .byte CASM_TOKEN_COMMA, CASM_TOKEN_COLON, CASM_TOKEN_HASH
    .byte CASM_TOKEN_LPAREN, CASM_TOKEN_RPAREN, CASM_TOKEN_PLUS
    .byte CASM_TOKEN_MINUS, CASM_TOKEN_LESS, CASM_TOKEN_GREATER

dirOrgStr:      .byte ".ORG", 0
dirByteStr:     .byte ".BYTE", 0
dirWordStr:     .byte ".WORD", 0
dirIncludeStr:  .byte ".INCLUDE", 0
dirStaticStr:   .byte ".STATIC", 0
dirRelocStr:    .byte ".RELOC", 0
