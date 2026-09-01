; src/external/casm/diagnostics.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Allocation-free CASM diagnostics. These routines remain safe while central
; resource cleanup is active and never acquire file or VMM resources.

.include "command64.inc"
.include "common.inc"

.export diagPrintString
.export diagPrintFatal
.export diagPrintPhase2Ready
.if CASM_ENABLE_DIAG_DUMP_TOKEN
.export diagDumpToken
.endif
.export diagClearLoc
.export diagSetLocFromLookahead
.export diagSetLocFromLookaheadPos
.export diagSetLocFromToken
.export diagSetLocFromStmt
.export diagStampStmtLoc

.import CasmTokenRecord
.if CASM_ENABLE_DIAG_DUMP_TOKEN
.import CasmTokenText          ; used only by diagDumpToken
.endif

.import CasmLookaheadLineLo
.import CasmLookaheadLineHi
.import CasmLookaheadColumn
.import CasmLookaheadByte
.import CasmLookaheadFileId

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

; WP35: multi-file diagnostic filename lookup (cli.s). Both standalone
; harnesses that link the real diagnostics.s already carry stand-in copies
; of these three names, as a side effect of WP34's own sourceLoad fix --
; confirmed by tracing, not assumed.
.import CasmSourceCount
.import cliSourceSlotLo
.import cliSourceSlotHi

; WP48 included-source identity and traceback state. Catalog reads use the
; immutable VMM metadata store and never touch the source filesystem.
.import includeCatalogRead
.import CasmIncludeRecordStage
.import CasmFrameDepth
.import CasmFrameCatalogIndex
.import CasmFrameRootFileId
.import CasmFrameResumeLineLo
.import CasmFrameResumeLineHi
.import CasmFrameSiteLineLo
.import CasmFrameSiteLineHi
.import CasmFrameSiteColumn

; WP83 Increment 6: .ASSERT's optional user-supplied message, echoed on a
; failing assertion instead of the generic fixed text.
.import CasmAssertMessage
.import CasmAssertMessageLen

.import CasmDiagLineBufA
.import CasmDiagLineBufB
.import CasmDiagLineSel
.import CasmDiagLineLen
.import CasmDiagLineClipped
.import CasmDiagLineNoLo
.import CasmDiagLineNoHi
.import CasmDiagPrevLen
.import CasmDiagPrevClipped
.import CasmDiagPrevNoLo
.import CasmDiagPrevNoHi

; Terminal, fatal-path-only line recovery. See its contract in source.s.
.import sourceDrainLineTail

; Progress Increment 7 (Atomic Increment 4): one-way edge, matching
; progress.s's own module boundary (see its file header) -- diagnostics.s
; may import only this one routine, never anything else from progress.s,
; and progress.s never imports anything back.
.import progressClearTransient

.segment "BSS"

; Fatal rendering can drain the remainder of an unterminated included line.
; That drain may reach child EOF and pop the live frame, so retain the depth
; observed on entry. The bounded frame arrays themselves remain intact.
CasmDiagTraceDepth: .res 1
CasmDiagTraceIndex: .res 1

.segment "CODE"

; ---------------------------------------------------------------------------
; diagPrintString
; Print one null-terminated PETSCII string through the Command 64 API.
;
; Inputs:  X = string address low byte
;          Y = string address high byte
; Outputs: none
; Flags:   undefined after OS_API
; Clobbers: A and any registers documented as volatile by DOS_PRINT_STR;
;           callers must treat X and Y as volatile across the OS call
; ---------------------------------------------------------------------------
diagPrintString:
    lda #DOS_PRINT_STR
    jsr OS_API
    rts

; ---------------------------------------------------------------------------
; diagPrintMessage
; Print one diagnostic line: the shared "CASM: " prefix, then the
; null-terminated message body at X/Y, then a trailing PETSCII CR. This is
; the form every fatal/summary diagnostic shares -- factoring the prefix and
; CR out of all ~89 message strings into one place (memory-optimization WP,
; task 42, Finding B). diagPrintString above stays byte-for-byte unchanged:
; the non-message prints (filenames, source-line echo, carets, location
; lines, include tracebacks -- and casm.s/map.s's banner/header/row text)
; must NOT gain a prefix or a forced CR, so they keep calling it directly.
;
; Inputs:  X = message body address low byte
;          Y = message body address high byte
; Outputs: none
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
diagPrintMessage:
    txa
    pha
    tya
    pha
    ldx #<msgCasmPrefix
    ldy #>msgCasmPrefix
    jsr diagPrintString
    pla
    tay
    pla
    tax
    jsr diagPrintString
    ldx #<msgCR
    ldy #>msgCR
    jmp diagPrintString

; ---------------------------------------------------------------------------
; diagPrintFatal
; Select and print the stable "CASM: " message for a fatal diagnostic
; identifier, then (for all but the locationless run) its source context.
;
; Finding C (memory-optimization WP, task 42): one dense parallel table,
; diagMsgLo/Hi, holds every message pointer in identifier order
; ($01 = CASM_DIAG_INIT_FAILED .. CASM_DIAG_LAST). Dispatch
; is: reject out-of-range -> unknown fallback; peel off the
; CASM_DIAG_ASSERTION_FAILED user-message echo; index the table; and skip
; the trailing diagPrintSourceContext call for exactly the
; CASM_DIAG_LOCLESS_FIRST..LAST window ($3D..$43), tested with two compares.
; This replaces the six separate range tables (main / listing / WP81 / WP82
; / WP83 / progress) and the nine-way cmp/beq chain that had accreted here,
; each of which repeated the same 20-byte table-lookup idiom. The message
; strings, their "CASM: " prefix (msgCasmPrefix) and trailing CR (msgCR)
; are unchanged -- see diagPrintMessage.
;
; Inputs:  A = CASM_DIAG_* identifier
; Outputs: none
; Flags:   undefined after diagPrintMessage
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
diagPrintFatal:
    ; Progress Increment 7: universal transient clear before any fatal
    ; diagnostic prints, per the Hook Contract. A holds the identifier the
    ; dispatch still needs and progressClearTransient clobbers A/X/Y, so A
    ; is stashed across the call. progressClearTransient has no error path
    ; (a pure OS_API print sequence), so it cannot recurse here.
    pha
    jsr progressClearTransient
    pla

    cmp #CASM_DIAG_INIT_FAILED
    bcc dpfUnknown
    cmp #CASM_DIAG_LAST + 1       ; single id-space bound (common.inc)
    bcs dpfUnknown

    ; CASM_DIAG_ASSERTION_FAILED ($54) with a user-supplied .ASSERT message
    ; echoes that text between the message body and the CR -- the one id
    ; that cannot go through diagPrintMessage. cmp leaves A intact for the
    ; generic path.
    cmp #CASM_DIAG_ASSERTION_FAILED
    bne dpfClassify
    lda CasmAssertMessageLen
    beq dpfAssertNoMessage
    ldx #<msgCasmPrefix
    ldy #>msgCasmPrefix
    jsr diagPrintString
    ldx #<msgAssertionFailedPrefix
    ldy #>msgAssertionFailedPrefix
    jsr diagPrintString
    ldx #<CasmAssertMessage
    ldy #>CasmAssertMessage
    jsr diagPrintString
    ldx #<msgCR
    ldy #>msgCR
    jsr diagPrintString
    jmp diagPrintSourceContext
dpfAssertNoMessage:
    lda #CASM_DIAG_ASSERTION_FAILED      ; the CasmAssertMessageLen load clobbered A

dpfClassify:
    ; A = identifier ($01..$56). The CASM_DIAG_LOCLESS_FIRST..LAST run is
    ; printed bare; every other id also gets diagPrintSourceContext (which
    ; self-gates when the raise site recorded no location).
    cmp #CASM_DIAG_LOCLESS_FIRST
    bcc dpfLocationed
    cmp #CASM_DIAG_LOCLESS_LAST + 1
    bcc dpfEmitFromTable                 ; $3D..$43: tail-call, no source context
dpfLocationed:
    jsr dpfEmitFromTable
    jmp diagPrintSourceContext

; Index diagMsgLo/Hi by (identifier - CASM_DIAG_INIT_FAILED) and hand the
; message body to diagPrintMessage.
; In:  A = identifier ($01..$56)
; Out: tail-calls diagPrintMessage (ends in rts)
dpfEmitFromTable:
    sec
    sbc #CASM_DIAG_INIT_FAILED
    tax
    lda diagMsgLo, x
    pha
    lda diagMsgHi, x
    tay
    pla
    tax
    jmp diagPrintMessage

dpfUnknown:
    ldx #<msgUnknown
    ldy #>msgUnknown
    jmp diagPrintMessage

; ---------------------------------------------------------------------------
; diagPrintPhase2Ready
; Print the stable successful-input-validation message.
;
; Inputs:  none
; Outputs: none
; Flags:   undefined after diagPrintString
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
diagPrintPhase2Ready:
    ldx #<msgPhase2Ready
    ldy #>msgPhase2Ready
    jmp diagPrintMessage

; ---------------------------------------------------------------------------
; diagClearLoc
; Invalidate any recorded source location. Every path that reports a
; diagnostic without a source position must call this first: a location left
; over from an earlier raise would otherwise attach itself to an unrelated
; message and point the user at an innocent line.
;
; Inputs:    none
; Outputs:   CasmDiagLocValid = CASM_DIAG_LOC_INVALID
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
diagClearLoc:
    lda #CASM_DIAG_LOC_INVALID
    sta CasmDiagLocValid
    rts

; ---------------------------------------------------------------------------
; diagSetLocFromLookahead
; Record the pending lookahead byte's provenance as the diagnostic location,
; including the byte itself. This is the correct source for a failure about a
; specific byte the lexer is looking at but has not yet consumed; the live
; source cursor has already moved past it.
;
; The caller must hold a valid lookahead (CasmLookaheadValid set by lexerFill).
;
; Inputs:    valid lookahead
; Outputs:   CasmDiagLoc* populated; CasmDiagLocValid = CASM_DIAG_LOC_BYTE
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
diagSetLocFromLookahead:
    lda CasmLookaheadLineLo
    sta CasmDiagLocLineLo
    lda CasmLookaheadLineHi
    sta CasmDiagLocLineHi
    lda CasmLookaheadColumn
    sta CasmDiagLocColumn
    lda CasmLookaheadByte
    sta CasmDiagLocByte
    lda CasmLookaheadFileId
    sta CasmDiagLocFileId
    lda #CASM_DIAG_LOC_BYTE
    sta CasmDiagLocValid
    rts

; ---------------------------------------------------------------------------
; diagSetLocFromLookaheadPos
; Record only the pending lookahead result's position. Unlike
; diagSetLocFromLookahead, this does not attach an offending byte; it is used
; when NEWLINE or EOF marks a missing include operand.
;
; Inputs:    valid lookahead
; Outputs:   CasmDiagLoc* populated; CasmDiagLocValid = CASM_DIAG_LOC_VALID
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
diagSetLocFromLookaheadPos:
    lda CasmLookaheadLineLo
    sta CasmDiagLocLineLo
    lda CasmLookaheadLineHi
    sta CasmDiagLocLineHi
    lda CasmLookaheadColumn
    sta CasmDiagLocColumn
    lda CasmLookaheadFileId
    sta CasmDiagLocFileId
    lda #CASM_DIAG_LOC_VALID
    sta CasmDiagLocValid
    rts

; ---------------------------------------------------------------------------
; diagSetLocFromToken
; Record the current token's start as the diagnostic location. Used by
; failures that concern a whole token rather than one byte, so no offending
; byte is reported.
;
; Inputs:    populated CasmTokenRecord
; Outputs:   CasmDiagLoc* populated; CasmDiagLocValid = CASM_DIAG_LOC_VALID
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
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

; ---------------------------------------------------------------------------
; diagSetLocFromStmt
; Record the current statement's start as the diagnostic location. The
; emission engine raises after a statement's tokens are consumed, so the token
; record points past the statement and only the stamped statement location
; still identifies it.
;
; Inputs:    CasmStmtLoc* stamped by parserParseStatement
; Outputs:   CasmDiagLoc* populated; CasmDiagLocValid = CASM_DIAG_LOC_VALID
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
diagSetLocFromStmt:
    lda CasmStmtLocLineLo
    sta CasmDiagLocLineLo
    lda CasmStmtLocLineHi
    sta CasmDiagLocLineHi
    lda CasmStmtLocColumn
    sta CasmDiagLocColumn
    lda CasmStmtLocFileId
    sta CasmDiagLocFileId
    lda #CASM_DIAG_LOC_VALID
    sta CasmDiagLocValid
    rts

; ---------------------------------------------------------------------------
; diagStampStmtLoc
; Copy the current token's start into the statement location. Called by
; parserParseStatement once per statement, on the statement's first token.
;
; Inputs:    populated CasmTokenRecord
; Outputs:   CasmStmtLoc* populated
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
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

; ---------------------------------------------------------------------------
; printChar
; Prints a single character in A using DOS_PRINT_CHAR.
; ---------------------------------------------------------------------------
printChar:
    pha
    tax
    lda #DOS_PRINT_CHAR
    jsr OS_API
    pla
    rts

; ---------------------------------------------------------------------------
; printDec16
; Print a 16-bit decimal number in CasmValue0Lo/Hi to screen.
; Clobbers: A, X, Y
; ---------------------------------------------------------------------------
printDec16:
    lda #0
    sta CasmLexerScratch0 ; zero suppression flag (0 = suppressing, 1 = printing)
    
    ; 10000s digit
    ldy #0
@loop10k:
    lda CasmValue0Lo
    sec
    sbc #<10000
    tax
    lda CasmValue0Hi
    sbc #>10000
    bcc @done10k
    stx CasmValue0Lo
    sta CasmValue0Hi
    iny
    jmp @loop10k
@done10k:
    tya
    beq @skip10k
    jsr @printDigit
@skip10k:

    ; 1000s digit
    ldy #0
@loop1k:
    lda CasmValue0Lo
    sec
    sbc #<1000
    tax
    lda CasmValue0Hi
    sbc #>1000
    bcc @done1k
    stx CasmValue0Lo
    sta CasmValue0Hi
    iny
    jmp @loop1k
@done1k:
    tya
    bne @print1k
    lda CasmLexerScratch0
    beq @skip1k
@print1k:
    tya
    jsr @printDigit
@skip1k:

    ; 100s digit
    ldy #0
@loop100:
    lda CasmValue0Lo
    sec
    sbc #100
    bcc @done100
    sta CasmValue0Lo
    iny
    jmp @loop100
@done100:
    tya
    bne @print100
    lda CasmLexerScratch0
    beq @skip100
@print100:
    tya
    jsr @printDigit
@skip100:

    ; 10s digit
    ldy #0
@loop10:
    lda CasmValue0Lo
    sec
    sbc #10
    bcc @done10
    sta CasmValue0Lo
    iny
    jmp @loop10
@done10:
    tya
    bne @print10
    lda CasmLexerScratch0
    beq @skip10
@print10:
    tya
    jsr @printDigit
@skip10:

    ; 1s digit (always printed)
    lda CasmValue0Lo
    clc
    adc #$30
    jsr printChar
    rts

@printDigit:
    pha
    lda #1
    sta CasmLexerScratch0 ; enable printing for subsequent digits
    pla
    clc
    adc #$30
    jsr printChar
    rts

; ---------------------------------------------------------------------------
; printHex8
; Print "$XX" for the byte in A.
;
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
printHex8:
    pha
    lda #$24                    ; '$'
    jsr printChar
    pla
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    jsr printNibble
    pla
    and #$0F
printNibble:
    cmp #10
    bcc @digit
    clc
    adc #$37                    ; 10 -> 'A'
    jmp printChar
@digit:
    clc
    adc #$30                    ; 0 -> '0'
    jmp printChar

; ---------------------------------------------------------------------------
; diagSanitizeByte
; Map a source byte to something safe to send to the screen.
;
; This is a correctness requirement, not cosmetics. The diagnostic that most
; needs this display is INVALID SOURCE BYTE, which fires precisely because the
; byte is not ordinary; echoing a raw $93 would clear the screen and erase the
; message, and $12 would leave the display in reverse video.
;
; Inputs:    A = raw source byte
; Outputs:   A = the byte, or CASM_DIAG_SUBST_CHAR if it is a control code
; Preserves: X, Y
; ---------------------------------------------------------------------------
diagSanitizeByte:
    cmp #CASM_DIAG_PRINT_LO_MIN
    bcc @subst                  ; $00-$1F control
    cmp #CASM_DIAG_PRINT_LO_MAX + 1
    bcc @ok                     ; $20-$7F printable
    cmp #CASM_DIAG_PRINT_HI_MIN
    bcc @subst                  ; $80-$9F control
@ok:
    rts
@subst:
    lda #CASM_DIAG_SUBST_CHAR
    rts

; ---------------------------------------------------------------------------
; diagResolveView
; Decide which echo buffer, if either, holds the diagnostic's line, and publish
; it as the view the renderer reads.
;
; The current buffer holds the line being consumed; the previous buffer holds
; the one before it, which is where an emit diagnostic's line lives because the
; parser consumed the statement's terminating newline before emit ran.
;
; Inputs:    CasmDiagLocLineLo/Hi and both buffers' line numbers
; Outputs:   C clear with CasmDiagViewSel/Len/Clipped published when a buffer
;            matches; C set when neither does
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
diagResolveView:
    lda CasmDiagLocLineLo
    cmp CasmDiagLineNoLo
    bne drvTryPrev
    lda CasmDiagLocLineHi
    cmp CasmDiagLineNoHi
    bne drvTryPrev
    ; The current line.
    lda CasmDiagLineSel
    sta CasmDiagViewSel
    lda CasmDiagLineLen
    sta CasmDiagViewLen
    lda CasmDiagLineClipped
    sta CasmDiagViewClipped
    clc
    rts
drvTryPrev:
    lda CasmDiagLocLineLo
    cmp CasmDiagPrevNoLo
    bne drvNoMatch
    lda CasmDiagLocLineHi
    cmp CasmDiagPrevNoHi
    bne drvNoMatch
    ; The previous line, which lives in the buffer the selector does not point
    ; at. It is already complete, since it ended with a newline.
    lda CasmDiagLineSel
    eor #$01
    sta CasmDiagViewSel
    lda CasmDiagPrevLen
    sta CasmDiagViewLen
    lda CasmDiagPrevClipped
    sta CasmDiagViewClipped
    clc
    rts
drvNoMatch:
    sec
    rts

; ---------------------------------------------------------------------------
; diagViewByte
; Read one byte from the resolved view buffer.
;
; Inputs:    X = index, CasmDiagViewSel
; Outputs:   A = byte
; Preserves: X, Y
; ---------------------------------------------------------------------------
diagViewByte:
    lda CasmDiagViewSel
    bne @bufB
    lda CasmDiagLineBufA,x
    rts
@bufB:
    lda CasmDiagLineBufB,x
    rts

; ---------------------------------------------------------------------------
; diagComputeWindow
; Choose the slice of the echoed line to display and where the caret falls.
;
; A source line may be 255 bytes; the screen is 40 columns. The window slides
; to keep the failing column visible, and a two-character prefix is always
; emitted (either indent or a left clip marker) so the caret offset is uniform.
;
; Inputs:    CasmDiagViewLen, CasmDiagLocColumn, CasmDiagViewClipped
; Outputs:   CasmDiagWinStart, CasmDiagWinCount, CasmDiagCaretPos,
;            CasmDiagWinFlags
; Clobbers:  A, X, Y
; ---------------------------------------------------------------------------
diagComputeWindow:
    lda #0
    sta CasmDiagWinFlags

    ; Zero-based index of the failing byte. Column 0 is the source layer's
    ; column-exhausted latch, which can only occur past byte 254.
    ldx CasmDiagLocColumn
    bne @haveCol
    ldx #CASM_DIAG_LINE_MAX
    bne @indexReady
@haveCol:
    dex                         ; 1-based column -> 0-based index
@indexReady:
    ; X = index. Short lines never scroll.
    lda CasmDiagViewLen
    cmp #CASM_DIAG_WINDOW_WIDTH + 1
    bcc @startZero              ; len <= 38: whole line fits
    cpx #CASM_DIAG_WINDOW_WIDTH
    bcc @startZero              ; error within the first 38 columns

    ; Center the window on the error, then pull it back so it does not run
    ; past the end of the line.
    txa
    sec
    sbc #CASM_DIAG_WINDOW_WIDTH / 2
    sta CasmDiagWinStart
    clc
    adc #CASM_DIAG_WINDOW_WIDTH
    cmp CasmDiagViewLen
    bcc @startSet               ; window ends within the line
    lda CasmDiagViewLen
    sec
    sbc #CASM_DIAG_WINDOW_WIDTH
    sta CasmDiagWinStart
@startSet:
    lda #CASM_DIAG_CLIP_LEFT
    sta CasmDiagWinFlags
    jmp @count
@startZero:
    lda #0
    sta CasmDiagWinStart

@count:
    ; count = min(WINDOW_WIDTH, len - start)
    lda CasmDiagViewLen
    sec
    sbc CasmDiagWinStart
    cmp #CASM_DIAG_WINDOW_WIDTH + 1
    bcc @countSet
    lda #CASM_DIAG_WINDOW_WIDTH
@countSet:
    sta CasmDiagWinCount

    ; Right clip when the window stops short of the end, or when the line
    ; itself overflowed the echo buffer.
    lda CasmDiagWinStart
    clc
    adc CasmDiagWinCount
    cmp CasmDiagViewLen
    bcs @checkOverflow
    lda CasmDiagWinFlags
    ora #CASM_DIAG_CLIP_RIGHT
    sta CasmDiagWinFlags
    jmp @caret
@checkOverflow:
    lda CasmDiagViewClipped
    beq @caret
    lda CasmDiagWinFlags
    ora #CASM_DIAG_CLIP_RIGHT
    sta CasmDiagWinFlags

@caret:
    ; Caret sits under the failing byte, offset by the two-character prefix.
    ; An index past the window (a failure reported at end of line) parks the
    ; caret just after the last rendered character.
    txa
    sec
    sbc CasmDiagWinStart
    cmp CasmDiagWinCount
    bcc @caretSet
    lda CasmDiagWinCount
@caretSet:
    clc
    adc #CASM_DIAG_INDENT
    sta CasmDiagCaretPos
    rts

; ---------------------------------------------------------------------------
; diagPrintLineAndCaret
; Print the windowed source line followed by the caret row.
;
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
diagPrintLineAndCaret:
    jsr diagComputeWindow

    ; Prefix: left clip marker, or plain indent.
    lda CasmDiagWinFlags
    and #CASM_DIAG_CLIP_LEFT
    beq @indent
    ldx #<msgClipLeft
    ldy #>msgClipLeft
    jsr diagPrintString
    jmp @body
@indent:
    ldx #<msgIndent
    ldy #>msgIndent
    jsr diagPrintString

@body:
    ldy #0
@bodyLoop:
    cpy CasmDiagWinCount
    beq @bodyDone
    tya
    pha                         ; save the loop index across printChar
    clc
    adc CasmDiagWinStart        ; A still holds Y: window index -> buffer index
    tax
    jsr diagViewByte
    jsr diagSanitizeByte
    jsr printChar
    pla
    tay
    iny
    jmp @bodyLoop
@bodyDone:

    lda CasmDiagWinFlags
    and #CASM_DIAG_CLIP_RIGHT
    beq @endLine
    ldx #<msgClipRight
    ldy #>msgClipRight
    jsr diagPrintString
@endLine:
    ldx #<msgCR
    ldy #>msgCR
    jsr diagPrintString

    ; Caret row: emitted as its own line so it never depends on how the OS
    ; print routine wrapped the row above.
    ldy #0
@caretLoop:
    cpy CasmDiagCaretPos
    beq @caretDone
    tya
    pha
    lda #$20                    ; ' '
    jsr printChar
    pla
    tay
    iny
    jmp @caretLoop
@caretDone:
    lda #$5E                    ; '^'
    jsr printChar
    ldx #<msgCR
    ldy #>msgCR
    jmp diagPrintString

; ---------------------------------------------------------------------------
; diagPrintSourceContext
; Print the location line for a source-position diagnostic, and the offending
; line with a caret when the echo buffer still holds that line.
;
; Does nothing when no location was recorded, which is how CLI, file, and
; internal-state diagnostics stay bare.
;
; Inputs:    CasmDiagLoc* and the echo buffer
; Outputs:   none
; Clobbers:  A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
diagPrintSourceContext:
    lda CasmDiagLocValid
    bne @haveLoc
    rts
@haveLoc:
    lda CasmFrameDepth
    sta CasmDiagTraceDepth
    ; A token at an unterminated child EOF may already have caused lookahead
    ; to pop one or more frames before its diagnostic is raised. Its packed
    ; FILE_ID remains authoritative and the bounded frame arrays are retained.
    ; Recover the original depth by finding that catalog id. Active-chain cycle
    ; prevention makes the first ascending match unambiguous; indices below it
    ; are its distinct ancestors, while stale entries can only follow it.
    lda CasmDiagLocFileId
    bpl @traceDepthReady
    and #CASM_DIAG_FILEID_ID_MASK
    sta CasmDiagTraceIndex
    ldx #0
@findTraceDepth:
    cpx #CASM_INCLUDE_MAX_DEPTH
    bcs @traceDepthReady         ; corrupt/missing metadata: retain live depth
    cmp CasmFrameCatalogIndex, x
    beq @traceDepthFound
    inx
    bne @findTraceDepth         ; bounded at 16, always taken
@traceDepthFound:
    inx                         ; array index -> 1-based frame depth
    stx CasmDiagTraceDepth
@traceDepthReady:

    ; WP48: an included-file location always names its physical file. Preserve
    ; WP35's existing gate for roots so a single-root, no-include diagnostic
    ; remains byte-identical to prior releases.
    lda CasmDiagLocFileId
    bmi @printFileName
    lda CasmSourceCount
    cmp #2
    bcc @skipFileName
@printFileName:
    ldx #<msgInFile
    ldy #>msgInFile
    jsr diagPrintString
    lda CasmDiagLocFileId
    jsr diagPrintIncludeIdentity
    ldx #<msgCR
    ldy #>msgCR
    jsr diagPrintString
@skipFileName:
    ldx #<msgAtLine
    ldy #>msgAtLine
    jsr diagPrintString
    lda CasmDiagLocLineLo
    sta CasmValue0Lo
    lda CasmDiagLocLineHi
    sta CasmValue0Hi
    jsr printDec16

    ldx #<msgColPrefix
    ldy #>msgColPrefix
    jsr diagPrintString
    lda CasmDiagLocColumn
    sta CasmValue0Lo
    lda #0
    sta CasmValue0Hi
    jsr printDec16

    ; Both conventions are printed: COL is 1-based, matching the existing
    ; diagDumpToken output, while OFFSET is the 0-based byte index into the
    ; line. Cheap here, and it removes an ambiguity the user would otherwise
    ; have to resolve by experiment.
    ldx #<msgOffsetPrefix
    ldy #>msgOffsetPrefix
    jsr diagPrintString
    lda CasmDiagLocColumn
    beq @offsetZero
    sec
    sbc #1
    jmp @offsetStore
@offsetZero:
    lda #0
@offsetStore:
    sta CasmValue0Lo
    lda #0
    sta CasmValue0Hi
    jsr printDec16
    ldx #<msgOffsetSuffix
    ldy #>msgOffsetSuffix
    jsr diagPrintString

    ; The offending byte, when the raise site recorded one. Printed as hex
    ; because the rendered line substitutes a '.' for exactly these bytes.
    lda CasmDiagLocValid
    cmp #CASM_DIAG_LOC_BYTE
    bne @noByte
    ldx #<msgBytePrefix
    ldy #>msgBytePrefix
    jsr diagPrintString
    lda CasmDiagLocByte
    jsr printHex8
@noByte:
    ldx #<msgCR
    ldy #>msgCR
    jsr diagPrintString

    ; Only two lines are retained. If the diagnostic refers to any earlier
    ; line, the text is gone and a caret would point into unrelated source, so
    ; the location line stands alone.
    jsr diagResolveView
    bcs @noText

    ; Drain only when the diagnostic is on the line still being consumed. The
    ; previous line already ended at a newline and is complete, and draining
    ; would append the *following* line's bytes to the current buffer.
    lda CasmDiagViewSel
    cmp CasmDiagLineSel
    bne @render
    ; Recover the rest of the line before rendering. Deliberately sequenced
    ; after the message and location are already on screen: the drain is a
    ; terminal, best-effort read, so if it fails or hangs the user still has
    ; the diagnostic that matters.
    jsr sourceDrainLineTail
    lda CasmDiagLineLen         ; the drain extended it; refresh the view
    sta CasmDiagViewLen
    lda CasmDiagLineClipped
    sta CasmDiagViewClipped
@render:
    jsr diagPrintLineAndCaret
    jmp diagPrintIncludeTraceback
@noText:
    jmp diagPrintIncludeTraceback

; ---------------------------------------------------------------------------
; diagPrintIncludeIdentity (private, WP48)
; Print a filename selected by the packed FILE_ID provenance byte.
;
; Inputs:    A = packed FILE_ID (bit 7 frame kind, bits 0-6 id)
; Outputs:   none
; Preserves: none
; Clobbers:  A, X, Y, processor flags, CasmIncludeRecordStage for frame ids
; Failure:   a catalog-read failure prints a fixed placeholder and returns;
;            it never replaces or propagates over the primary diagnostic
; ---------------------------------------------------------------------------
diagPrintIncludeIdentity:
    pha
    and #CASM_DIAG_FILEID_FRAME_FLAG
    bne @frame
    pla
    and #CASM_DIAG_FILEID_ID_MASK
    tax
    lda cliSourceSlotLo, x
    pha
    lda cliSourceSlotHi, x
    tay
    pla
    tax
    jmp diagPrintString
@frame:
    pla
    and #CASM_DIAG_FILEID_ID_MASK
    jsr includeCatalogRead
    bcs @unavailable
    ldx #<(CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAME)
    ldy #>(CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAME)
    jmp diagPrintString
@unavailable:
    ldx #<msgIncludeUnavailable
    ldy #>msgIncludeUnavailable
    jmp diagPrintString

; ---------------------------------------------------------------------------
; diagPrintIncludeTraceback (private, WP48)
; Print active include sites from innermost parent to the depth-zero root.
;
; Inputs:    CasmDiagTraceDepth captured at diagnostic-render entry;
;            frame catalog/site/root arrays
; Outputs:   none
; Preserves: none
; Clobbers:  A, X, Y, processor flags, CasmValue0Lo/Hi,
;            CasmIncludeRecordStage, CasmDiagTraceIndex
; ---------------------------------------------------------------------------
diagPrintIncludeTraceback:
    lda CasmDiagTraceDepth
    sta CasmDiagTraceIndex
@loop:
    lda CasmDiagTraceIndex
    beq @done

    ldx #<msgIncludedFrom
    ldy #>msgIncludedFrom
    jsr diagPrintString

    lda CasmDiagTraceIndex
    cmp #1
    beq @rootParent
    sec
    sbc #2
    tax
    lda CasmFrameCatalogIndex, x
    ora #CASM_DIAG_FILEID_FRAME_FLAG
    bne @printParent            ; flag guarantees nonzero
@rootParent:
    lda CasmFrameRootFileId      ; outermost frame's originating CLI root
@printParent:
    jsr diagPrintIncludeIdentity

    ldx #<msgLinePrefix
    ldy #>msgLinePrefix
    jsr diagPrintString
    ldx CasmDiagTraceIndex
    dex
    lda CasmFrameSiteLineLo, x
    sta CasmValue0Lo
    lda CasmFrameSiteLineHi, x
    sta CasmValue0Hi
    jsr printDec16

    ldx #<msgColumnPrefix
    ldy #>msgColumnPrefix
    jsr diagPrintString
    ldx CasmDiagTraceIndex
    dex
    lda CasmFrameSiteColumn, x
    sta CasmValue0Lo
    lda #0
    sta CasmValue0Hi
    jsr printDec16
    ldx #<msgCR
    ldy #>msgCR
    jsr diagPrintString

    dec CasmDiagTraceIndex
    jmp @loop
@done:
    rts

; ---------------------------------------------------------------------------
; diagDumpToken
; Format and print the current token to screen. Lexer/parser development aid
; with no production call site since the Phase 3 WP10 token loop was
; replaced; gated off by default (see CASM_ENABLE_DIAG_DUMP_TOKEN in
; common.inc). The routine and its token-name tables/strings below are
; wrapped in the same .if so ld65 has nothing to link when it is off.
; ---------------------------------------------------------------------------
.if CASM_ENABLE_DIAG_DUMP_TOKEN
diagDumpToken:
    ; Print type name:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_COUNT
    bcc @okType
    ldx #<msgUnknownTok
    ldy #>msgUnknownTok
    jsr diagPrintString
    jmp @printLoc
@okType:
    tax
    lda tokNamesLo, x
    pha
    lda tokNamesHi, x
    tay
    pla
    tax
    jsr diagPrintString

    ; Print subtype if applicable (DIRECTIVE, REGISTER, NUMBER, MNEMONIC)
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_DIRECTIVE
    bne @notDir
    ; Directive subtype
    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    cmp #CASM_DIRECTIVE_COUNT
    bcc @okDir
    ldx #<msgSubUnknown
    ldy #>msgSubUnknown
    jsr diagPrintString
    jmp @printText
@okDir:
    tax
    lda dirSubtypeNamesLo, x
    pha
    lda dirSubtypeNamesHi, x
    tay
    pla
    tax
    jsr diagPrintString
    jmp @printText

@notDir:
    cmp #CASM_TOKEN_REGISTER
    bne @notReg
    ; Register subtype
    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    cmp #CASM_REGISTER_COUNT
    bcc @okReg
    ldx #<msgSubUnknown
    ldy #>msgSubUnknown
    jsr diagPrintString
    jmp @printText
@okReg:
    tax
    lda regSubtypeNamesLo, x
    pha
    lda regSubtypeNamesHi, x
    tay
    pla
    tax
    jsr diagPrintString
    jmp @printText

@notReg:
    cmp #CASM_TOKEN_NUMBER
    bne @notNum
    ; Number subtype
    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    cmp #CASM_NUMBER_COUNT
    bcc @okNum
    ldx #<msgSubUnknown
    ldy #>msgSubUnknown
    jsr diagPrintString
    jmp @printText
@okNum:
    tax
    lda numSubtypeNamesLo, x
    pha
    lda numSubtypeNamesHi, x
    tay
    pla
    tax
    jsr diagPrintString
    jmp @printText

@notNum:
    cmp #CASM_TOKEN_MNEMONIC
    bne @printText
    ; Mnemonic subtype: print " (" followed by index, followed by ")"
    ldx #<msgMnemPrefix
    ldy #>msgMnemPrefix
    jsr diagPrintString
    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    sta CasmValue0Lo
    lda #0
    sta CasmValue0Hi
    jsr printDec16
    ldx #<msgMnemSuffix
    ldy #>msgMnemSuffix
    jsr diagPrintString

@printText:
    ; Print text: space then "[" then CasmTokenText then "]"
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    beq @printLoc
    ldx #<msgTextPrefix
    ldy #>msgTextPrefix
    jsr diagPrintString
    ldx #<CasmTokenText
    ldy #>CasmTokenText
    jsr diagPrintString
    ldx #<msgTextSuffix
    ldy #>msgTextSuffix
    jsr diagPrintString

@printLoc:
    ; Print location: " L:<line> C:<col>"
    ldx #<msgLocLinePrefix
    ldy #>msgLocLinePrefix
    jsr diagPrintString
    
    lda CasmTokenRecord + CASM_TOKEN_REC_LINE_LO
    sta CasmValue0Lo
    lda CasmTokenRecord + CASM_TOKEN_REC_LINE_HI
    sta CasmValue0Hi
    jsr printDec16

    ldx #<msgLocColPrefix
    ldy #>msgLocColPrefix
    jsr diagPrintString

    lda CasmTokenRecord + CASM_TOKEN_REC_COLUMN
    sta CasmValue0Lo
    lda #0
    sta CasmValue0Hi
    jsr printDec16

    ; Print Carriage Return
    ldx #<msgCR
    ldy #>msgCR
    jsr diagPrintString
    rts
.endif  ; CASM_ENABLE_DIAG_DUMP_TOKEN

.segment "RODATA"

; Finding C (memory-optimization WP, task 42): one dense message table in
; identifier order -- $01 CASM_DIAG_INIT_FAILED .. CASM_DIAG_LAST.
; Replaces diagMessageLo/Hi + diagListMessageLo/Hi + diagWp81/82/83MessageLo/Hi
; + diagProgressMessageLo/Hi. diagPrintFatal indexes it by
; (identifier - CASM_DIAG_INIT_FAILED). Order is fixed by the CASM_DIAG_*
; numbering and the contiguity asserts in common.inc; the two asserts below
; pin the table length to CASM_DIAG_LAST -- which is also exactly what
; diagPrintFatal's runtime range check bounds against, so a new CASM_DIAG_*
; without a matching entry here fails the build AND the runtime check can
; never fall behind the table.
diagMsgLo:
    .byte <msgInitFailed           ; $01
    .byte <msgRegistryFull         ; $02
    .byte <msgCleanupFailed        ; $03
    .byte <msgSourceRequired       ; $04
    .byte <msgExtraSource          ; $05
    .byte <msgMalformedOutput      ; $06
    .byte <msgDuplicateOption      ; $07
    .byte <msgUnknownOption        ; $08
    .byte <msgFilenameTooLong      ; $09
    .byte <msgNotImplemented       ; $0A
    .byte <msgInputOpenFailed      ; $0B
    .byte <msgInputReadFailed      ; $0C
    .byte <msgInputCloseFailed     ; $0D
    .byte <msgOutputCreateFailed   ; $0E
    .byte <msgOutputWriteFailed    ; $0F
    .byte <msgOutputCloseFailed    ; $10
    .byte <msgOutputDeleteFailed   ; $11
    .byte <msgOutputShortWrite     ; $12
    .byte <msgStreamStateFailed    ; $13
    .byte <msgSourceRewindFailed   ; $14
    .byte <msgSourceOffsetOverflow ; $15
    .byte <msgSourceLocationOverflow ; $16
    .byte <msgSourceLineTooLong    ; $17
    .byte <msgTokenTooLong         ; $18
    .byte <msgInvalidSourceByte    ; $19
    .byte <msgMalformedNumber      ; $1A
    .byte <msgLexerStateFailed     ; $1B
    .byte <msgSyntaxError          ; $1C
    .byte <msgExpectedNewline      ; $1D
    .byte <msgOperandOutOfRange    ; $1E
    .byte <msgInvalidAddrMode      ; $1F
    .byte <msgDuplicateOrg         ; $20
    .byte <msgOrgRequired          ; $21
    .byte <msgAddressOverflow      ; $22
    .byte <msgBranchOutOfRange     ; $23
    .byte <msgExprMalformed        ; $24
    .byte <msgExprUnsupported      ; $25
    .byte <msgExprOverflow         ; $26
    .byte <msgResolverFailed       ; $27
    .byte <msgVmmUnavailable       ; $28
    .byte <msgVmmAllocFailed       ; $29
    .byte <msgVmmFreeFailed        ; $2A
    .byte <msgVmmTransferFailed    ; $2B
    .byte <msgDuplicateSymbol      ; $2C
    .byte <msgUndefinedSymbol      ; $2D
    .byte <msgSymbolTableFull      ; $2E
    .byte <msgPassMismatch         ; $2F
    .byte <msgRelocTableFull       ; $30
    .byte <msgIncludeFilenameExpected ; $31
    .byte <msgInvalidIncludeFilename ; $32
    .byte <msgIncludeFilenameTooLong ; $33
    .byte <msgIncludeCatalogFull   ; $34
    .byte <msgIncludeDepthExceeded ; $35
    .byte <msgIncludeCycleDetected ; $36
    .byte <msgIncludeEventLogFull  ; $37
    .byte <msgIncludeReplayMismatch ; $38
    .byte <msgListingNameCollision ; $39
    .byte <msgListingRecordsFull   ; $3A
    .byte <msgListingBytesFull     ; $3B
    .byte <msgListingReplayMismatch ; $3C
    .byte <msgListingCreateFailed  ; $3D
    .byte <msgListingWriteFailed   ; $3E
    .byte <msgListingCloseFailed   ; $3F
    .byte <msgListingDeleteFailed  ; $40
    .byte <msgListingShortWrite    ; $41
    .byte <msgSymbolMapInvalid     ; $42
    .byte <msgExprCircular         ; $43
    .byte <msgExprDivZero          ; $44
    .byte <msgExprRelocUnsupported ; $45
    .byte <msgExprParenTooDeep     ; $46
    .byte <msgCharUnterminated     ; $47
    .byte <msgCharInvalidByte      ; $48
    .byte <msgStringUnterminated   ; $49
    .byte <msgStringInvalidByte    ; $4A
    .byte <msgResFillAlignUnresolved ; $4B
    .byte <msgFillValueRequired    ; $4C
    .byte <msgValueOutOfRange      ; $4D
    .byte <msgAlignBoundaryZero    ; $4E
    .byte <msgIncbinFilenameExpected ; $4F
    .byte <msgInvalidIncbinFilename ; $50
    .byte <msgIncbinFilenameTooLong ; $51
    .byte <msgAssertUnresolved     ; $52
    .byte <msgAssertMessageTooLong ; $53
    .byte <msgAssertionFailed      ; $54
    .byte <msgProgressCounterOverflow ; $55
    .byte <msgProgressPassTotalMismatch ; $56
    .byte <msgLocalWithoutScope     ; $57
    .byte <msgDuplicateLocal        ; $58
    .byte <msgUndefinedLocal        ; $59
    .byte <msgLocalInConstant       ; $5A
diagMsgLoEnd:

diagMsgHi:
    .byte >msgInitFailed           ; $01
    .byte >msgRegistryFull         ; $02
    .byte >msgCleanupFailed        ; $03
    .byte >msgSourceRequired       ; $04
    .byte >msgExtraSource          ; $05
    .byte >msgMalformedOutput      ; $06
    .byte >msgDuplicateOption      ; $07
    .byte >msgUnknownOption        ; $08
    .byte >msgFilenameTooLong      ; $09
    .byte >msgNotImplemented       ; $0A
    .byte >msgInputOpenFailed      ; $0B
    .byte >msgInputReadFailed      ; $0C
    .byte >msgInputCloseFailed     ; $0D
    .byte >msgOutputCreateFailed   ; $0E
    .byte >msgOutputWriteFailed    ; $0F
    .byte >msgOutputCloseFailed    ; $10
    .byte >msgOutputDeleteFailed   ; $11
    .byte >msgOutputShortWrite     ; $12
    .byte >msgStreamStateFailed    ; $13
    .byte >msgSourceRewindFailed   ; $14
    .byte >msgSourceOffsetOverflow ; $15
    .byte >msgSourceLocationOverflow ; $16
    .byte >msgSourceLineTooLong    ; $17
    .byte >msgTokenTooLong         ; $18
    .byte >msgInvalidSourceByte    ; $19
    .byte >msgMalformedNumber      ; $1A
    .byte >msgLexerStateFailed     ; $1B
    .byte >msgSyntaxError          ; $1C
    .byte >msgExpectedNewline      ; $1D
    .byte >msgOperandOutOfRange    ; $1E
    .byte >msgInvalidAddrMode      ; $1F
    .byte >msgDuplicateOrg         ; $20
    .byte >msgOrgRequired          ; $21
    .byte >msgAddressOverflow      ; $22
    .byte >msgBranchOutOfRange     ; $23
    .byte >msgExprMalformed        ; $24
    .byte >msgExprUnsupported      ; $25
    .byte >msgExprOverflow         ; $26
    .byte >msgResolverFailed       ; $27
    .byte >msgVmmUnavailable       ; $28
    .byte >msgVmmAllocFailed       ; $29
    .byte >msgVmmFreeFailed        ; $2A
    .byte >msgVmmTransferFailed    ; $2B
    .byte >msgDuplicateSymbol      ; $2C
    .byte >msgUndefinedSymbol      ; $2D
    .byte >msgSymbolTableFull      ; $2E
    .byte >msgPassMismatch         ; $2F
    .byte >msgRelocTableFull       ; $30
    .byte >msgIncludeFilenameExpected ; $31
    .byte >msgInvalidIncludeFilename ; $32
    .byte >msgIncludeFilenameTooLong ; $33
    .byte >msgIncludeCatalogFull   ; $34
    .byte >msgIncludeDepthExceeded ; $35
    .byte >msgIncludeCycleDetected ; $36
    .byte >msgIncludeEventLogFull  ; $37
    .byte >msgIncludeReplayMismatch ; $38
    .byte >msgListingNameCollision ; $39
    .byte >msgListingRecordsFull   ; $3A
    .byte >msgListingBytesFull     ; $3B
    .byte >msgListingReplayMismatch ; $3C
    .byte >msgListingCreateFailed  ; $3D
    .byte >msgListingWriteFailed   ; $3E
    .byte >msgListingCloseFailed   ; $3F
    .byte >msgListingDeleteFailed  ; $40
    .byte >msgListingShortWrite    ; $41
    .byte >msgSymbolMapInvalid     ; $42
    .byte >msgExprCircular         ; $43
    .byte >msgExprDivZero          ; $44
    .byte >msgExprRelocUnsupported ; $45
    .byte >msgExprParenTooDeep     ; $46
    .byte >msgCharUnterminated     ; $47
    .byte >msgCharInvalidByte      ; $48
    .byte >msgStringUnterminated   ; $49
    .byte >msgStringInvalidByte    ; $4A
    .byte >msgResFillAlignUnresolved ; $4B
    .byte >msgFillValueRequired    ; $4C
    .byte >msgValueOutOfRange      ; $4D
    .byte >msgAlignBoundaryZero    ; $4E
    .byte >msgIncbinFilenameExpected ; $4F
    .byte >msgInvalidIncbinFilename ; $50
    .byte >msgIncbinFilenameTooLong ; $51
    .byte >msgAssertUnresolved     ; $52
    .byte >msgAssertMessageTooLong ; $53
    .byte >msgAssertionFailed      ; $54
    .byte >msgProgressCounterOverflow ; $55
    .byte >msgProgressPassTotalMismatch ; $56
    .byte >msgLocalWithoutScope     ; $57
    .byte >msgDuplicateLocal        ; $58
    .byte >msgUndefinedLocal        ; $59
    .byte >msgLocalInConstant       ; $5A
diagMsgHiEnd:

.assert diagMsgLoEnd - diagMsgLo = CASM_DIAG_LAST, error, "CASM diagnostic message table (lo) length must equal CASM_DIAG_LAST"
.assert diagMsgHiEnd - diagMsgHi = CASM_DIAG_LAST, error, "CASM diagnostic message table (hi) length must equal CASM_DIAG_LAST"

; Finding B (memory-optimization WP, task 42): the "CASM: " that used to
; lead every one of the ~89 message strings below, and the trailing PETSCII
; CR that ended all but msgAssertionFailedPrefix, are factored out here and
; into diagPrintMessage. Every message below is now just the bare text plus
; a null terminator; diagPrintMessage emits msgCasmPrefix, the body, then
; msgCR.
msgCasmPrefix:
    .byte "CASM: ", 0

msgInitFailed:
    .byte "INITIALIZATION FAILED", 0
msgRegistryFull:
    .byte "RESOURCE REGISTRY FULL", 0
msgCleanupFailed:
    .byte "RESOURCE CLEANUP FAILED", 0
msgSourceRequired:
    .byte "SOURCE FILE REQUIRED", 0
msgExtraSource:
    .byte "TOO MANY SOURCE FILES", 0
msgMalformedOutput:
    .byte "MALFORMED /O OPTION", 0
msgDuplicateOption:
    .byte "DUPLICATE OPTION", 0
msgUnknownOption:
    .byte "UNKNOWN OPTION", 0
msgFilenameTooLong:
    .byte "FILENAME TOO LONG", 0
msgNotImplemented:
    .byte "FEATURE NOT IMPLEMENTED", 0
msgInputOpenFailed:
    .byte "CANNOT OPEN INPUT", 0
msgInputReadFailed:
    .byte "INPUT READ FAILED", 0
msgInputCloseFailed:
    .byte "INPUT CLOSE FAILED", 0
msgOutputCreateFailed:
    .byte "CANNOT CREATE OUTPUT", 0
msgOutputWriteFailed:
    .byte "OUTPUT WRITE FAILED", 0
msgOutputCloseFailed:
    .byte "OUTPUT CLOSE FAILED", 0
msgOutputDeleteFailed:
    .byte "OUTPUT DELETE FAILED", 0
msgOutputShortWrite:
    .byte "SHORT OUTPUT WRITE", 0
msgStreamStateFailed:
    .byte "INVALID STREAM STATE", 0
msgSourceRewindFailed:
    .byte "SOURCE REWIND FAILED", 0
msgSourceOffsetOverflow:
    .byte "SOURCE OFFSET OVERFLOW", 0
msgSourceLocationOverflow:
    .byte "SOURCE LOCATION OVERFLOW", 0
msgSourceLineTooLong:
    .byte "SOURCE LINE TOO LONG", 0
msgTokenTooLong:
    .byte "TOKEN TOO LONG", 0
msgInvalidSourceByte:
    .byte "INVALID SOURCE BYTE", 0
msgMalformedNumber:
    .byte "MALFORMED NUMBER", 0
msgLexerStateFailed:
    .byte "INVALID LEXER STATE", 0
msgSyntaxError:
    .byte "SYNTAX ERROR", 0
msgExpectedNewline:
    .byte "EXPECTED NEWLINE", 0
msgOperandOutOfRange:
    .byte "OPERAND OUT OF RANGE", 0
msgInvalidAddrMode:
    .byte "INVALID ADDRESSING MODE", 0
msgDuplicateOrg:
    .byte "DUPLICATE ORG", 0
msgOrgRequired:
    .byte "ORG REQUIRED", 0
msgAddressOverflow:
    .byte "ADDRESS OVERFLOW", 0
msgBranchOutOfRange:
    .byte "BRANCH OUT OF RANGE", 0
msgExprMalformed:
    .byte "MALFORMED EXPRESSION", 0
msgExprUnsupported:
    .byte "EXPRESSION UNSUPPORTED", 0
msgExprOverflow:
    .byte "EXPRESSION OVERFLOW", 0
msgResolverFailed:
    .byte "RESOLVER FAILED", 0
msgVmmUnavailable:
    .byte "VMM UNAVAILABLE", 0
msgVmmAllocFailed:
    .byte "VMM ALLOCATION FAILED", 0
msgVmmFreeFailed:
    .byte "VMM FREE FAILED", 0
msgVmmTransferFailed:
    .byte "VMM TRANSFER FAILED", 0
msgDuplicateSymbol:
    .byte "DUPLICATE SYMBOL", 0
msgUndefinedSymbol:
    .byte "UNDEFINED SYMBOL", 0
msgSymbolTableFull:
    .byte "SYMBOL TABLE FULL", 0
msgPassMismatch:
    .byte "PASS 1/2 MISMATCH", 0
msgRelocTableFull:
    .byte "RELOC TABLE FULL", 0
msgIncludeFilenameExpected:
    .byte "INCLUDE FILENAME EXPECTED", 0
msgInvalidIncludeFilename:
    .byte "INVALID INCLUDE FILENAME", 0
msgIncludeFilenameTooLong:
    .byte "INCLUDE FILENAME TOO LONG", 0
msgIncludeCatalogFull:
    .byte "INCLUDE CATALOG FULL", 0
msgIncludeDepthExceeded:
    .byte "INCLUDE DEPTH EXCEEDED", 0
msgIncludeCycleDetected:
    .byte "INCLUDE CYCLE DETECTED", 0
msgIncludeEventLogFull:
    .byte "INCLUDE EVENT LOG FULL", 0
msgIncludeReplayMismatch:
    .byte "INCLUDE REPLAY MISMATCH", 0
msgListingNameCollision:
    .byte "LISTING NAME COLLISION", 0
msgListingRecordsFull:
    .byte "LISTING RECORDS FULL", 0
msgListingBytesFull:
    .byte "LISTING BYTES FULL", 0
msgListingReplayMismatch:
    .byte "LISTING REPLAY MISMATCH", 0
msgSymbolMapInvalid:
    .byte "SYMBOL MAP INVALID", 0
; WP65: locationless (in the CASM_DIAG_LOCLESS_FIRST..LAST run, see
; common.inc), same as msgSymbolMapInvalid above -- the Pass1->Pass2
; resolution sweep runs after the live lexer/parser have moved on, with no
; line/column to attach.
msgExprCircular:
    .byte "CIRCULAR CONSTANT DEFINITION", 0
; WP68 Increment 6 Atomic Step 5: static division by zero.
msgExprDivZero:
    .byte "EXPRESSION DIVISION BY ZERO", 0
; WP67: a relocatable value reached a combine that already had one --
; representable only as one symbol + a static addend (WP64's rule).
msgExprRelocUnsupported:
    .byte "EXPRESSION RELOCATION UNSUPPORTED", 0
; WP67: parenthesized sub-expression nesting exceeded CASM_EXPR_PAREN_MAX_
; DEPTH (8).
msgExprParenTooDeep:
    .byte "EXPRESSION TOO DEEPLY NESTED", 0
; WP69: character literal ('x') diagnostics.
msgCharUnterminated:
    .byte "CHARACTER LITERAL UNTERMINATED", 0
msgCharInvalidByte:
    .byte "CHARACTER LITERAL INVALID BYTE", 0
msgStringUnterminated:
    .byte "STRING UNTERMINATED", 0
msgStringInvalidByte:
    .byte "STRING INVALID BYTE", 0
; WP81: .RES/.FILL/.ALIGN diagnostics.
msgResFillAlignUnresolved:
    .byte "OPERAND NOT RESOLVED", 0
msgFillValueRequired:
    .byte ".FILL REQUIRES A VALUE", 0
msgValueOutOfRange:
    .byte "VALUE OUT OF RANGE", 0
msgAlignBoundaryZero:
    .byte "ALIGN BOUNDARY ZERO", 0
; WP82: .INCBIN filename-grammar diagnostics.
msgIncbinFilenameExpected:
    .byte "INCBIN FILENAME EXPECTED", 0
msgInvalidIncbinFilename:
    .byte "INVALID INCBIN FILENAME", 0
msgIncbinFilenameTooLong:
    .byte "INCBIN FILENAME TOO LONG", 0
; WP83: .ASSERT diagnostics.
msgAssertUnresolved:
    .byte "ASSERT OPERAND NOT RESOLVED", 0
msgAssertMessageTooLong:
    .byte "ASSERT MESSAGE TOO LONG", 0
msgAssertionFailed:
    .byte "ASSERTION FAILED", 0
; WP83 Increment 6: printed (after the shared msgCasmPrefix) immediately
; before the echoed CasmAssertMessage text -- no trailing CR of its own,
; the echoed message's null terminator ends the payload and dpfWp83's own
; msgCR print supplies the line break after it. Finding B stripped the
; "CASM: " that used to lead this string; the caller now prints
; msgCasmPrefix explicitly.
msgAssertionFailedPrefix:
    .byte "ASSERTION FAILED: ", 0
; Progress Increment 4.
msgProgressCounterOverflow:
    .byte "STATEMENT COUNT OVERFLOW", 0
msgProgressPassTotalMismatch:
    .byte "PASS 1/PASS 2 STATEMENT MISMATCH", 0
; Phase 14 WP89: local-label (@name) diagnostics.
msgLocalWithoutScope:
    .byte "LOCAL LABEL BEFORE ANY GLOBAL LABEL", 0
msgDuplicateLocal:
    .byte "DUPLICATE LOCAL LABEL IN SCOPE", 0
msgUndefinedLocal:
    .byte "UNDEFINED LOCAL LABEL", 0
msgLocalInConstant:
    .byte "LOCAL LABEL NOT ALLOWED IN CONSTANT", 0
; The five listing-file I/O diagnostics ($3D-$41): the head of the
; CASM_DIAG_LOCLESS_FIRST..LAST locationless run (see common.inc).
msgListingCreateFailed:
    .byte "LISTING CREATE FAILED", 0
msgListingWriteFailed:
    .byte "LISTING WRITE FAILED", 0
msgListingCloseFailed:
    .byte "LISTING CLOSE FAILED", 0
msgListingDeleteFailed:
    .byte "LISTING DELETE FAILED", 0
msgListingShortWrite:
    .byte "LISTING SHORT WRITE", 0
msgUnknown:
    .byte "INTERNAL ERROR", 0
msgPhase2Ready:
    .byte "INPUT VALIDATED", 0

; Token dump tables and strings -- gated with diagDumpToken itself (Finding
; A). msgCR below is deliberately outside the .if: it is shared by
; diagPrintFatal and the source-context/traceback printers.
.if CASM_ENABLE_DIAG_DUMP_TOKEN
tokNamesLo:
    .byte <tokNameEof, <tokNameNewline, <tokNameId, <tokNameMnem
    .byte <tokNameDir, <tokNameReg, <tokNameNum, <tokNameComma
    .byte <tokNameColon, <tokNameHash, <tokNameLparen, <tokNameRparen
    .byte <tokNamePlus, <tokNameMinus, <tokNameLess, <tokNameGreater
    .byte <tokNameEquals, <tokNameStar, <tokNameSlash, <tokNameAmpersand
    .byte <tokNameCaret, <tokNamePipe, <tokNameTilde, <tokNameShl
    .byte <tokNameShr, <tokNameChar, <tokNameString
tokNamesHi:
    .byte >tokNameEof, >tokNameNewline, >tokNameId, >tokNameMnem
    .byte >tokNameDir, >tokNameReg, >tokNameNum, >tokNameComma
    .byte >tokNameColon, >tokNameHash, >tokNameLparen, >tokNameRparen
    .byte >tokNamePlus, >tokNameMinus, >tokNameLess, >tokNameGreater
    .byte >tokNameEquals, >tokNameStar, >tokNameSlash, >tokNameAmpersand
    .byte >tokNameCaret, >tokNamePipe, >tokNameTilde, >tokNameShl
    .byte >tokNameShr, >tokNameChar, >tokNameString

dirSubtypeNamesLo:
    .byte <dirNameUnknown, <dirNameOrg, <dirNameByte, <dirNameWord
    .byte <dirNameInclude, <dirNameStatic, <dirNameReloc
dirSubtypeNamesHi:
    .byte >dirNameUnknown, >dirNameOrg, >dirNameByte, >dirNameWord
    .byte >dirNameInclude, >dirNameStatic, >dirNameReloc

regSubtypeNamesLo:
    .byte <regNameA, <regNameX, <regNameY
regSubtypeNamesHi:
    .byte >regNameA, >regNameX, >regNameY

numSubtypeNamesLo:
    .byte <numNameDec, <numNameHex, <numNameBin
numSubtypeNamesHi:
    .byte >numNameDec, >numNameHex, >numNameBin

tokNameEof:       .byte "EOF", 0
tokNameNewline:   .byte "NEWLINE", 0
tokNameId:        .byte "IDENTIFIER", 0
tokNameMnem:      .byte "MNEMONIC", 0
tokNameDir:       .byte "DIRECTIVE", 0
tokNameReg:       .byte "REGISTER", 0
tokNameNum:       .byte "NUMBER", 0
tokNameComma:     .byte "COMMA", 0
tokNameColon:     .byte "COLON", 0
tokNameHash:      .byte "HASH", 0
tokNameLparen:    .byte "LPAREN", 0
tokNameRparen:    .byte "RPAREN", 0
tokNamePlus:      .byte "PLUS", 0
tokNameMinus:     .byte "MINUS", 0
tokNameLess:      .byte "LESS", 0
tokNameGreater:   .byte "GREATER", 0
tokNameEquals:    .byte "EQUALS", 0
tokNameStar:      .byte "STAR", 0
tokNameSlash:     .byte "SLASH", 0
tokNameAmpersand: .byte "AMPERSAND", 0
tokNameCaret:     .byte "CARET", 0
tokNamePipe:      .byte "PIPE", 0
tokNameTilde:     .byte "TILDE", 0
tokNameShl:       .byte "SHL", 0
tokNameShr:       .byte "SHR", 0
tokNameChar:      .byte "CHAR", 0
tokNameString:    .byte "STRING", 0
msgUnknownTok:    .byte "UNKNOWN", 0

dirNameUnknown:   .byte " (UNKNOWN)", 0
dirNameOrg:       .byte " (ORG)", 0
dirNameByte:      .byte " (BYTE)", 0
dirNameWord:      .byte " (WORD)", 0
dirNameInclude:   .byte " (INCLUDE)", 0
dirNameStatic:    .byte " (STATIC)", 0
dirNameReloc:     .byte " (RELOC)", 0

regNameA:         .byte " (A)", 0
regNameX:         .byte " (X)", 0
regNameY:         .byte " (Y)", 0

numNameDec:       .byte " (DECIMAL)", 0
numNameHex:       .byte " (HEX)", 0
numNameBin:       .byte " (BINARY)", 0

msgSubUnknown:    .byte " (UNKNOWN)", 0
msgMnemPrefix:    .byte " (", 0
msgMnemSuffix:    .byte ")", 0
msgTextPrefix:    .byte " [", 0
msgTextSuffix:    .byte "]", 0
msgLocLinePrefix: .byte " L:", 0
msgLocColPrefix:  .byte " C:", 0
.endif  ; CASM_ENABLE_DIAG_DUMP_TOKEN
msgCR:            .byte PetCr, 0

; WP15 source context strings.
; WP35/WP48: root names print when CasmSourceCount > 1; included-file names
; always print. Traceback strings follow the same identity renderer.
msgInFile:       .byte "IN FILE ", 0
msgIncludedFrom: .byte "INCLUDED FROM ", 0
msgLinePrefix:   .byte " LINE ", 0
msgColumnPrefix: .byte " COLUMN ", 0
msgIncludeUnavailable: .byte "<INCLUDE?>", 0
msgAtLine:       .byte "AT LINE ", 0
msgColPrefix:    .byte ", COL ", 0
msgOffsetPrefix: .byte " (OFFSET ", 0
msgOffsetSuffix: .byte ")", 0
msgBytePrefix:   .byte " BYTE ", 0
msgIndent:       .byte "  ", 0
msgClipLeft:     .byte "<.", 0
msgClipRight:    .byte ".>", 0
