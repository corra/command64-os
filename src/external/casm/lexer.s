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
.import CasmLookaheadOffsetLo
.import CasmLookaheadOffsetHi
.import CasmSourceResultOffsetLo
.import CasmSourceResultOffsetHi
.import CasmLookaheadResult
.import CasmLookaheadByte
.import CasmLookaheadFileId
.import CasmLookaheadLineLo
.import CasmLookaheadLineHi
.import CasmLookaheadColumn
.import CasmTokenRecord
.import CasmTokenText
.import CasmIncludeFilename
.import CasmIncludeFilenameLen
.import CasmIncbinFilename
.import CasmIncbinFilenameLen

; Source layer: the byte stream and the just-delivered byte's own true
; provenance (WP46 fix -- captured by sourceFetchPhysical itself, after any
; refill/pop/root-transition triggered by this fetch already committed, not
; snapshotted here before the call; see source.s's CasmSourceResultFileId
; field comment).
.import sourceNextByte
.import CasmSourceResultByte
.import CasmSourceResultFileId
.import CasmSourceResultLineLo
.import CasmSourceResultLineHi
.import CasmSourceResultColumn

; WP15 diagnostic context.
.import CasmDiagCapture
.import diagSetLocFromLookahead
.import diagSetLocFromLookaheadPos
.import diagSetLocFromToken

.export lexerInit
.export lexerNext
.export lexerGetToken
.export lexerScanIncludeOperand
.export lexerScanIncbinOperand
.export CasmTokenStartOffsetLo
.export CasmTokenStartOffsetHi
.export CasmStringLength
.export CasmStringBuffer

.segment "BSS"

; WP65: the current token's own absolute source position (see
; CasmSourceResultOffsetLo/Hi's field comment, state.s), stamped by
; lexerTokenReset from the lookahead exactly like FileId/Line/Column
; already are into CasmTokenRecord -- kept as a separate module-owned pair
; instead of growing the frozen 39-byte CASM_TOKEN_REC_SIZE record, same
; precedent as parser.s's own CasmLabelName/CasmLabelNameLen.
CasmTokenStartOffsetLo: .res 1
CasmTokenStartOffsetHi: .res 1
CasmStringLength:       .res 1
CasmStringBuffer:       .res CASM_STRING_BUFFER_SIZE

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
    ; WP15: the lexer is the BYTE-mode consumer of the source, so it owns
    ; enabling the line echo. LINE-mode callers already hold their line in
    ; CasmIoBuffer and must not pay the per-byte echo cost.
    lda #CASM_DIAG_CAPTURE_ON
    sta CasmDiagCapture
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
    cmp #CASM_PETSCII_LESS
    beq lnAngleJmp
    cmp #CASM_PETSCII_GREATER
    beq lnAngleJmp
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

    ; WP69: character literal ('x') -- multi-byte scan like $/% above, not a
    ; single-byte punctuation table entry.
    cmp #CASM_PETSCII_APOSTROPHE
    beq lnCharJmp

    cmp #CASM_PETSCII_QUOTE
    beq lnStringJmp

    ; Check if it's a decimal number (0-9)
    jsr isDecDigit
    bcc lnDecJmp

    ; Check if it's an identifier first character (A-Z, a-z, _)
    jsr isIdFirst
    bcc lnIdJmp

    ; Phase 14 WP87: '@' also enters lnId -- it is the one identifier-first
    ; byte lnId itself must validate further (a local label needs a real
    ; identifier-first byte right after the '@'), so it is dispatched here
    ; rather than accepted by isIdFirst.
    cmp #CASM_PETSCII_AT
    beq lnIdJmp

    ; None of the above: invalid source byte! The lookahead still holds the
    ; offending byte and its provenance; the live source cursor has already
    ; moved past it.
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_INVALID_SOURCE_BYTE
    jmp lnFailWithA

lnDirectiveJmp:
    jmp lnDirective
lnHexJmp:
    jmp lnHex
lnBinJmp:
    jmp lnBin
lnCharJmp:
    jmp lnChar
lnStringJmp:
    jmp lnString
lnAngleJmp:
    jmp lnAngle
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
    bne @commentNotNewline
    jmp lnSkip                  ; preserve the newline; re-dispatch emits it
@commentNotNewline:
    cmp #CASM_SOURCE_EOF
    bne @commentByte
    jmp lnSkip                  ; preserve EOF; re-dispatch emits it
@commentByte:
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
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_TOKEN_TOO_LONG
    jmp lnFailWithA

; WP68: distinguish the two-byte shift operators from the existing
; single-byte extraction tokens. The token location is stamped before the
; first byte is consumed. A differing second byte remains buffered as the
; next token; EOF/newline likewise terminates a single '<' or '>'.
lnAngle:
    jsr lexerTokenReset
    lda CasmLookaheadByte
    jsr lexerTokenAppend
    bcs lnAngleAppendFail
    jsr lexerConsume
    jsr lexerFill
    bcs lnFail
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_BYTE
    bne lnAngleSingle
    lda CasmLookaheadByte
    cmp CasmTokenText
    bne lnAngleSingle
    jsr lexerTokenAppend
    bcs lnAngleAppendFail
    jsr lexerConsume
    lda CasmTokenText
    cmp #CASM_PETSCII_LESS
    beq lnAngleShl
    lda #CASM_TOKEN_SHR
    jmp lexerEmit
lnAngleShl:
    lda #CASM_TOKEN_SHL
    jmp lexerEmit
lnAngleSingle:
    lda CasmTokenText
    cmp #CASM_PETSCII_LESS
    beq lnAngleLess
    lda #CASM_TOKEN_GREATER
    jmp lexerEmit
lnAngleLess:
    lda #CASM_TOKEN_LESS
    jmp lexerEmit
lnAngleAppendFail:
    jsr diagSetLocFromLookahead
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
; lexerScanIncludeOperand
; Scan the quoted filename following an already-consumed .INCLUDE directive.
; The stable token record is preserved; payload bytes go to the dedicated
; parser-owned 64-byte buffer. The statement terminator remains buffered so
; normal statement iteration retains its existing newline/EOF behavior.
;
; Inputs:    lexer READY; lookahead points at, or can fetch, the first source
;            result after the .INCLUDE token
; Outputs:   success: 1..63 original PETSCII bytes plus null in
;                     CasmIncludeFilename, length committed, A =
;                     CASM_DIAG_NONE, C clear
;            failure: lexer ERROR, A = include grammar diagnostic or
;                     CASM_DIAG_EXPECTED_NEWLINE, C set; operand invalid
; Preserves: token record, balanced stack, resources and pass/emitter state
; Clobbers:  A, X, Y, flags, CasmLexerScratch0/1, lookahead, source volatile
;            state, CasmIncludeFilename/CasmIncludeFilenameLen
; ---------------------------------------------------------------------------
lexerScanIncludeOperand:
    lda #0
    sta CasmLexerScratch0       ; working payload length; commit only on success
    sta CasmIncludeFilenameLen

lsioLeading:
    jsr lexerFill
    bcc :+
    jmp lsioPropagatedFail
:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_BYTE
    beq :+
    jmp lsioExpectedPos
:
    lda CasmLookaheadByte
    cmp #CASM_PETSCII_SPACE
    beq lsioConsumeLeading
    cmp #CASM_PETSCII_TAB
    beq lsioConsumeLeading
    cmp #CASM_PETSCII_QUOTE
    beq :+
    jmp lsioExpectedByte
:

    ; Preserve the opening quote's exact location for empty and unterminated
    ; operands before consuming it and advancing the live source cursor.
    jsr diagSetLocFromLookahead
    jsr lexerConsume

lsioPayload:
    jsr lexerFill
    bcc :+
    jmp lsioPropagatedFail
:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_BYTE
    beq :+
    jmp lsioInvalidAtOpening
:
    lda CasmLookaheadByte
    cmp #CASM_PETSCII_QUOTE
    beq lsioClose

    ; Printable raw PETSCII is $20-$7E or $A0-$FE. Quote was handled above as
    ; the delimiter; controls, $7F-$9F, and $FF fail at the offending byte.
    cmp #CASM_INCLUDE_PRINT_LO_MIN
    bcs :+
    jmp lsioInvalidByte
:
    cmp #CASM_INCLUDE_PRINT_LO_MAX + 1
    bcc lsioAppend
    cmp #CASM_INCLUDE_PRINT_HI_MIN
    bcs :+
    jmp lsioInvalidByte
:
    cmp #CASM_INCLUDE_PRINT_HI_MAX + 1
    bcs lsioInvalidByte

lsioAppend:
    ldx CasmLexerScratch0
    cpx #CASM_INCLUDE_FILENAME_MAX
    bcc :+
    jmp lsioTooLong
:
    sta CasmIncludeFilename, x
    inc CasmLexerScratch0
    jsr lexerConsume
    jmp lsioPayload

lsioClose:
    lda CasmLexerScratch0
    beq lsioInvalidAtOpening
    jsr lexerConsume

lsioTrailing:
    jsr lexerFill
    bcs lsioPropagatedFail
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_BYTE
    bne lsioSuccess
    lda CasmLookaheadByte
    cmp #CASM_PETSCII_SPACE
    beq lsioConsumeTrailing
    cmp #CASM_PETSCII_TAB
    beq lsioConsumeTrailing
    cmp #CASM_PETSCII_SEMICOLON
    beq lsioCommentStart
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_EXPECTED_NEWLINE
    jmp lsioFailWithA

lsioConsumeLeading:
    jsr lexerConsume
    jmp lsioLeading

lsioConsumeTrailing:
    jsr lexerConsume
    jmp lsioTrailing

lsioCommentStart:
    jsr lexerConsume
lsioComment:
    jsr lexerFill
    bcs lsioPropagatedFail
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_BYTE
    bne lsioSuccess
    jsr lexerConsume
    jmp lsioComment

lsioSuccess:
    ldx CasmLexerScratch0
    lda #0
    sta CasmIncludeFilename, x
    stx CasmIncludeFilenameLen
    lda #CASM_DIAG_NONE
    clc
    rts

lsioExpectedPos:
    jsr diagSetLocFromLookaheadPos
    lda #CASM_DIAG_INCLUDE_FILENAME_EXPECTED
    jmp lsioFailWithA

lsioExpectedByte:
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_INCLUDE_FILENAME_EXPECTED
    jmp lsioFailWithA

lsioInvalidByte:
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_INVALID_INCLUDE_FILENAME
    jmp lsioFailWithA

lsioInvalidAtOpening:
    lda #CASM_DIAG_INVALID_INCLUDE_FILENAME
    jmp lsioFailWithA

lsioTooLong:
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_INCLUDE_FILENAME_TOO_LONG
    jmp lsioFailWithA

lsioPropagatedFail:
    ; lexerFill already latched lexer ERROR and returned the source diagnostic.
    sec
    rts

lsioFailWithA:
    pha
    lda #CASM_LEXER_STATE_ERROR
    sta CasmLexerState
    pla
    sec
    rts

; ---------------------------------------------------------------------------
; lexerScanIncbinOperand (WP82)
; Scan the quoted filename following an already-consumed .INCBIN directive.
; Byte-for-byte the same grammar as lexerScanIncludeOperand above (leading
; whitespace, opening quote, printable-PETSCII payload, closing quote,
; trailing whitespace/comment, NEWLINE/EOF) -- kept as its own routine
; rather than a call into lexerScanIncludeOperand so a malformed .INCBIN
; operand reports its own diagnostic identity, not an .INCLUDE-branded one
; (this WP's own Scoping Decision 1, user-confirmed 2026-08-21).
;
; Inputs:    lexer READY; lookahead points at, or can fetch, the first source
;            result after the .INCBIN token
; Outputs:   success: 1..63 original PETSCII bytes plus null in
;                     CasmIncbinFilename, length committed, A =
;                     CASM_DIAG_NONE, C clear
;            failure: lexer ERROR, A = incbin grammar diagnostic or
;                     CASM_DIAG_EXPECTED_NEWLINE, C set; operand invalid
; Preserves: token record, balanced stack, resources and pass/emitter state
; Clobbers:  A, X, Y, flags, CasmLexerScratch0/1, lookahead, source volatile
;            state, CasmIncbinFilename/CasmIncbinFilenameLen
; ---------------------------------------------------------------------------
lexerScanIncbinOperand:
    lda #0
    sta CasmLexerScratch0       ; working payload length; commit only on success
    sta CasmIncbinFilenameLen

lsibLeading:
    jsr lexerFill
    bcc :+
    jmp lsibPropagatedFail
:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_BYTE
    beq :+
    jmp lsibExpectedPos
:
    lda CasmLookaheadByte
    cmp #CASM_PETSCII_SPACE
    beq lsibConsumeLeading
    cmp #CASM_PETSCII_TAB
    beq lsibConsumeLeading
    cmp #CASM_PETSCII_QUOTE
    beq :+
    jmp lsibExpectedByte
:

    ; Preserve the opening quote's exact location for empty and unterminated
    ; operands before consuming it and advancing the live source cursor.
    jsr diagSetLocFromLookahead
    jsr lexerConsume

lsibPayload:
    jsr lexerFill
    bcc :+
    jmp lsibPropagatedFail
:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_BYTE
    beq :+
    jmp lsibInvalidAtOpening
:
    lda CasmLookaheadByte
    cmp #CASM_PETSCII_QUOTE
    beq lsibClose

    ; Printable raw PETSCII is $20-$7E or $A0-$FE. Quote was handled above as
    ; the delimiter; controls, $7F-$9F, and $FF fail at the offending byte.
    cmp #CASM_INCLUDE_PRINT_LO_MIN
    bcs :+
    jmp lsibInvalidByte
:
    cmp #CASM_INCLUDE_PRINT_LO_MAX + 1
    bcc lsibAppend
    cmp #CASM_INCLUDE_PRINT_HI_MIN
    bcs :+
    jmp lsibInvalidByte
:
    cmp #CASM_INCLUDE_PRINT_HI_MAX + 1
    bcs lsibInvalidByte

lsibAppend:
    ldx CasmLexerScratch0
    cpx #CASM_INCLUDE_FILENAME_MAX
    bcc :+
    jmp lsibTooLong
:
    sta CasmIncbinFilename, x
    inc CasmLexerScratch0
    jsr lexerConsume
    jmp lsibPayload

lsibClose:
    lda CasmLexerScratch0
    beq lsibInvalidAtOpening
    jsr lexerConsume

lsibTrailing:
    jsr lexerFill
    bcs lsibPropagatedFail
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_BYTE
    bne lsibSuccess
    lda CasmLookaheadByte
    cmp #CASM_PETSCII_SPACE
    beq lsibConsumeTrailing
    cmp #CASM_PETSCII_TAB
    beq lsibConsumeTrailing
    cmp #CASM_PETSCII_SEMICOLON
    beq lsibCommentStart
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_EXPECTED_NEWLINE
    jmp lsibFailWithA

lsibConsumeLeading:
    jsr lexerConsume
    jmp lsibLeading

lsibConsumeTrailing:
    jsr lexerConsume
    jmp lsibTrailing

lsibCommentStart:
    jsr lexerConsume
lsibComment:
    jsr lexerFill
    bcs lsibPropagatedFail
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_BYTE
    bne lsibSuccess
    jsr lexerConsume
    jmp lsibComment

lsibSuccess:
    ldx CasmLexerScratch0
    lda #0
    sta CasmIncbinFilename, x
    stx CasmIncbinFilenameLen
    lda #CASM_DIAG_NONE
    clc
    rts

lsibExpectedPos:
    jsr diagSetLocFromLookaheadPos
    lda #CASM_DIAG_INCBIN_FILENAME_EXPECTED
    jmp lsibFailWithA

lsibExpectedByte:
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_INCBIN_FILENAME_EXPECTED
    jmp lsibFailWithA

lsibInvalidByte:
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_INVALID_INCBIN_FILENAME
    jmp lsibFailWithA

lsibInvalidAtOpening:
    lda #CASM_DIAG_INVALID_INCBIN_FILENAME
    jmp lsibFailWithA

lsibTooLong:
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_INCBIN_FILENAME_TOO_LONG
    jmp lsibFailWithA

lsibPropagatedFail:
    ; lexerFill already latched lexer ERROR and returned the source diagnostic.
    sec
    rts

lsibFailWithA:
    pha
    lda #CASM_LEXER_STATE_ERROR
    sta CasmLexerState
    pla
    sec
    rts

; ---------------------------------------------------------------------------
; lexerFill (private)
; Ensure the one-result lookahead is valid. Provenance is captured AFTER the
; fetch, from sourceFetchPhysical's own CasmSourceResultFileId/LineLo/Hi/
; Column (WP46 fix) -- not snapshotted from the source's in-place location
; fields before calling sourceNextByte. Capturing before the call is correct
; for an ordinary byte, where nothing changes out from under it, but is
; stale whenever this same call is the one that resolves a child frame's
; EOF and triggers an automatic pop: the pre-call snapshot would describe
; the abandoned child's position, not the parent's restored position the
; delivered byte actually belongs to. CasmSourceResultColumn already
; carries the column-exhausted-latch clamp to CASM_SOURCE_COLUMN_MAX; actual
; column overflow stays enforced by sourceNextByte.
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
    jsr sourceNextByte
    bcs lfFail
    sta CasmLookaheadResult
    lda CasmSourceResultFileId
    sta CasmLookaheadFileId
    lda CasmSourceResultLineLo
    sta CasmLookaheadLineLo
    lda CasmSourceResultLineHi
    sta CasmLookaheadLineHi
    lda CasmSourceResultColumn
    sta CasmLookaheadColumn
    lda CasmSourceResultOffsetLo
    sta CasmLookaheadOffsetLo
    lda CasmSourceResultOffsetHi
    sta CasmLookaheadOffsetHi
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
    lda CasmLookaheadOffsetLo
    sta CasmTokenStartOffsetLo
    lda CasmLookaheadOffsetHi
    sta CasmTokenStartOffsetHi
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
    ldx #<dirResStr
    ldy #>dirResStr
    jsr compareTokenText
    bcs @notRes
    lda #CASM_TOKEN_DIRECTIVE
    ldx #CASM_DIRECTIVE_RES
    jmp lexerEmitWithSubtype
@notRes:
    ldx #<dirFillStr
    ldy #>dirFillStr
    jsr compareTokenText
    bcs @notFill
    lda #CASM_TOKEN_DIRECTIVE
    ldx #CASM_DIRECTIVE_FILL
    jmp lexerEmitWithSubtype
@notFill:
    ldx #<dirAlignStr
    ldy #>dirAlignStr
    jsr compareTokenText
    bcs @notAlign
    lda #CASM_TOKEN_DIRECTIVE
    ldx #CASM_DIRECTIVE_ALIGN
    jmp lexerEmitWithSubtype
@notAlign:
    ldx #<dirIncbinStr
    ldy #>dirIncbinStr
    jsr compareTokenText
    bcs @notIncbin
    lda #CASM_TOKEN_DIRECTIVE
    ldx #CASM_DIRECTIVE_INCBIN
    jmp lexerEmitWithSubtype
@notIncbin:
    ldx #<dirAssertStr
    ldy #>dirAssertStr
    jsr compareTokenText
    bcs @notAssert
    lda #CASM_TOKEN_DIRECTIVE
    ldx #CASM_DIRECTIVE_ASSERT
    jmp lexerEmitWithSubtype
@notAssert:
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

; ---------------------------------------------------------------------------
; lnChar (private, WP69)
; Scan a character literal: '<one printable byte>'. No escape sequences --
; the content byte is taken raw, no case folding/charmap reinterpretation
; (matches CASM's existing verbatim treatment of identifier bytes). Exactly
; one content byte is always consumed regardless of its value, so a literal
; quote as content ('''  -- three apostrophes) needs no special-casing: the
; opening ', the quote-as-content byte, and the closing ' each fall out of
; the same mechanical read. An empty literal ('') is reported the same way
; as a genuinely unterminated one -- not special-cased separately, per this
; WP's own minimalism scoping decision.
; ---------------------------------------------------------------------------
lnChar:
    jsr lexerTokenReset
    jsr lexerConsume            ; consume opening '
    jsr lexerFill
    bcc @haveByte1
    jmp lnFail
@haveByte1:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_EOF
    beq lnCharUnterminated
    cmp #CASM_SOURCE_NEWLINE
    beq lnCharUnterminated

    ; Printable raw PETSCII is $20-$7E or $A0-$FE, same bounds
    ; .INCLUDE filenames already enforce (lexerScanIncludeOperand above).
    lda CasmLookaheadByte
    cmp #CASM_INCLUDE_PRINT_LO_MIN
    bcs @lowCheck
    jmp lnCharInvalidByte
@lowCheck:
    cmp #CASM_INCLUDE_PRINT_LO_MAX + 1
    bcc @content
    cmp #CASM_INCLUDE_PRINT_HI_MIN
    bcs @hiCheck
    jmp lnCharInvalidByte
@hiCheck:
    cmp #CASM_INCLUDE_PRINT_HI_MAX + 1
    bcc @content
    jmp lnCharInvalidByte
@content:
    jsr lexerTokenAppend
    bcc @ok1
    jmp lnTokenTooLong
@ok1:
    jsr lexerConsume            ; consume the content byte
    jsr lexerFill
    bcc @haveByte2
    jmp lnFail
@haveByte2:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_EOF
    beq lnCharUnterminated
    cmp #CASM_SOURCE_NEWLINE
    beq lnCharUnterminated
    lda CasmLookaheadByte
    cmp #CASM_PETSCII_APOSTROPHE
    bne lnCharUnterminated
    jsr lexerConsume            ; consume closing '
    lda #CASM_TOKEN_CHAR
    jmp lexerEmit

lnCharUnterminated:
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_CHAR_UNTERMINATED
    jmp lnFailWithA

lnCharInvalidByte:
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_CHAR_INVALID_BYTE
    jmp lnFailWithA

; ---------------------------------------------------------------------------
; lnString (private, WP74)
; Scan a bounded double-quoted raw-PETSCII string. Content lives in the
; lexer-owned 255-byte buffer rather than the frozen token text record.
; ---------------------------------------------------------------------------
lnString:
    jsr lexerTokenReset
    lda #0
    sta CasmStringLength
    jsr lexerConsume
lnStringLoop:
    jsr lexerFill
    bcc @haveResult
    jmp lnFail
@haveResult:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_EOF
    beq lnStringUnterminated
    cmp #CASM_SOURCE_NEWLINE
    beq lnStringUnterminated
    lda CasmLookaheadByte
    cmp #CASM_PETSCII_QUOTE
    beq lnStringClose
    cmp #CASM_INCLUDE_PRINT_LO_MIN
    bcc lnStringInvalidByte
    cmp #CASM_INCLUDE_PRINT_LO_MAX + 1
    bcc lnStringAppend
    cmp #CASM_INCLUDE_PRINT_HI_MIN
    bcc lnStringInvalidByte
    cmp #CASM_INCLUDE_PRINT_HI_MAX + 1
    bcs lnStringInvalidByte
lnStringAppend:
    ldx CasmStringLength
    cpx #CASM_STRING_BUFFER_SIZE
    bcs lnStringUnterminated
    sta CasmStringBuffer, x
    inc CasmStringLength
    jsr lexerConsume
    jmp lnStringLoop
lnStringClose:
    jsr lexerConsume
    lda #CASM_TOKEN_STRING
    sta CasmTokenRecord + CASM_TOKEN_REC_TYPE
    lda #CASM_SUBTYPE_NONE
    sta CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    lda CasmStringLength
    sta CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    lda #CASM_TOKEN_STRING
    clc
    rts
lnStringUnterminated:
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_STRING_UNTERMINATED
    jmp lnFailWithA
lnStringInvalidByte:
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_STRING_INVALID_BYTE
    jmp lnFailWithA

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
    ; Point at the start of the malformed number, not at wherever scanning
    ; gave up: the whole literal is what the user needs to look at.
    jsr diagSetLocFromToken
    lda #CASM_DIAG_MALFORMED_NUMBER
    jmp lnFailWithA

; Phase 14 WP87: a leading '@' (CASM_PETSCII_AT) starts a local-label
; identifier -- legal ONLY when immediately followed by an isIdFirst byte
; (A-Z, a-z, or '_'; never a digit, another '@', whitespace, a line
; terminator, or EOF). lnId is entered on '@' the same way it is entered on
; any other isIdFirst byte (see the dispatch below); it is the one case
; that needs a second byte of lookahead before it can accept, since '@' is
; not itself a valid identifier body -- unlike every other accepted first
; byte, which is always self-sufficient. A malformed form (bare '@', '@@',
; '@1', '@' at EOF/newline) is reported at the OFFENDING byte (the one
; after '@', or the '@' itself if that's exhausted) as
; CASM_DIAG_INVALID_SOURCE_BYTE -- the same diagnostic '@' alone already
; produced before this WP (it fell through every dispatch case to the
; catch-all invalid-byte path); no new diagnostic identifier is spent on
; this. See `brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md`.
lnId:
    jsr lexerTokenReset
    lda CasmLookaheadByte
    cmp #CASM_PETSCII_AT
    beq @idAt
    jmp @idLoop
@idAt:
    lda CasmLookaheadByte
    jsr lexerTokenAppend        ; append '@' itself
    bcc @idAtOk1
    jmp lnTokenTooLong
@idAtOk1:
    jsr lexerConsume
    jsr lexerFill
    bcc @idAtOk2
    jmp lnFail
@idAtOk2:
    lda CasmLookaheadResult
    cmp #CASM_SOURCE_EOF
    beq @idLocalMalformed
    cmp #CASM_SOURCE_NEWLINE
    beq @idLocalMalformed
    lda CasmLookaheadByte
    jsr isIdFirst
    bcs @idLocalMalformed       ; next byte is not a legal identifier start
    jmp @idLoop                 ; validated -- @idLoop appends it normally
@idLocalMalformed:
    jsr diagSetLocFromLookahead
    lda #CASM_DIAG_INVALID_SOURCE_BYTE
    jmp lnFailWithA
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
    jsr classifyMnemonic
    bcs @notMnem
    lda #CASM_TOKEN_MNEMONIC
    jmp lexerEmitWithSubtype
@notMnem:
    lda #CASM_TOKEN_IDENTIFIER
    jmp lexerEmit

lnTokenTooLong:
    jsr diagSetLocFromToken
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
    cpy CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    bne @useChar
    lda #0
    jmp @check
@useChar:
    lda CasmTokenText, y
@check:
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

; ---------------------------------------------------------------------------
; classifyMnemonic (private)
; Compare CasmTokenText against the mnemonic table case-insensitively.
;
; Outputs:   C clear and X = index (0-55) on match; C set on mismatch
; ---------------------------------------------------------------------------
classifyMnemonic:
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    cmp #3
    beq @checkTable
    sec
    rts
@checkTable:
    lda #<mnemonicTable
    sta CasmPtr0Lo
    lda #>mnemonicTable
    sta CasmPtr0Hi
    ldx #0
@loop:
    ldy #0
    lda CasmTokenText, y
    jsr normalizeChar
    sta CasmLexerScratch0
    lda (CasmPtr0Lo), y
    jsr normalizeChar
    cmp CasmLexerScratch0
    bne @next
    iny
    lda CasmTokenText, y
    jsr normalizeChar
    sta CasmLexerScratch0
    lda (CasmPtr0Lo), y
    jsr normalizeChar
    cmp CasmLexerScratch0
    bne @next
    iny
    lda CasmTokenText, y
    jsr normalizeChar
    sta CasmLexerScratch0
    lda (CasmPtr0Lo), y
    jsr normalizeChar
    cmp CasmLexerScratch0
    beq @match
@next:
    lda CasmPtr0Lo
    clc
    adc #3
    sta CasmPtr0Lo
    lda CasmPtr0Hi
    adc #0
    sta CasmPtr0Hi
    inx
    cpx #CASM_MNEMONIC_COUNT
    bcc @loop
    sec
    rts
@match:
    clc
    rts

.segment "RODATA"

lexerPunctBytes:
    .byte CASM_PETSCII_COMMA, CASM_PETSCII_COLON, CASM_PETSCII_HASH
    .byte CASM_PETSCII_LPAREN, CASM_PETSCII_RPAREN, CASM_PETSCII_PLUS
    .byte CASM_PETSCII_MINUS, CASM_PETSCII_LESS, CASM_PETSCII_GREATER
    .byte CASM_PETSCII_EQUALS, CASM_PETSCII_ASTERISK, CASM_PETSCII_SLASH
    .byte CASM_PETSCII_AMPERSAND, CASM_PETSCII_CARET, CASM_PETSCII_PIPE
    .byte CASM_PETSCII_TILDE
    .byte $FF
lexerPunctTypes:
    .byte CASM_TOKEN_COMMA, CASM_TOKEN_COLON, CASM_TOKEN_HASH
    .byte CASM_TOKEN_LPAREN, CASM_TOKEN_RPAREN, CASM_TOKEN_PLUS
    .byte CASM_TOKEN_MINUS, CASM_TOKEN_LESS, CASM_TOKEN_GREATER
    .byte CASM_TOKEN_EQUALS, CASM_TOKEN_STAR, CASM_TOKEN_SLASH
    .byte CASM_TOKEN_AMPERSAND, CASM_TOKEN_CARET, CASM_TOKEN_PIPE
    .byte CASM_TOKEN_TILDE

dirOrgStr:      .byte ".ORG", 0
dirByteStr:     .byte ".BYTE", 0
dirWordStr:     .byte ".WORD", 0
dirIncludeStr:  .byte ".INCLUDE", 0
dirStaticStr:   .byte ".STATIC", 0
dirRelocStr:    .byte ".RELOC", 0
dirResStr:      .byte ".RES", 0
dirFillStr:     .byte ".FILL", 0
dirAlignStr:    .byte ".ALIGN", 0
dirIncbinStr:   .byte ".INCBIN", 0
dirAssertStr:   .byte ".ASSERT", 0

mnemonicTable:
    .byte "ADC", "AND", "ASL", "BCC", "BCS", "BEQ", "BIT", "BMI"
    .byte "BNE", "BPL", "BRK", "BVC", "BVS", "CLC", "CLD", "CLI"
    .byte "CLV", "CMP", "CPX", "CPY", "DEC", "DEX", "DEY", "EOR"
    .byte "INC", "INX", "INY", "JMP", "JSR", "LDA", "LDX", "LDY"
    .byte "LSR", "NOP", "ORA", "PHA", "PHP", "PLA", "PLP", "ROL"
    .byte "ROR", "RTI", "RTS", "SBC", "SEC", "SED", "SEI", "STA"
    .byte "STX", "STY", "TAX", "TAY", "TSX", "TXA", "TXS", "TYA"
MnemonicTableSize = * - mnemonicTable
.assert MnemonicTableSize = 168, error, "Mnemonic table must occupy exactly 168 bytes"
