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
.export diagDumpToken
.export diagClearLoc
.export diagSetLocFromLookahead
.export diagSetLocFromToken
.export diagSetLocFromStmt
.export diagStampStmtLoc

.import CasmTokenRecord
.import CasmTokenText

.import CasmLookaheadLineLo
.import CasmLookaheadLineHi
.import CasmLookaheadColumn
.import CasmLookaheadByte

.import CasmDiagLocValid
.import CasmDiagLocLineLo
.import CasmDiagLocLineHi
.import CasmDiagLocColumn
.import CasmDiagLocByte
.import CasmStmtLocLineLo
.import CasmStmtLocLineHi
.import CasmStmtLocColumn

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
; diagPrintFatal
; Select and print the stable message for a fatal diagnostic identifier. Phase
; 2 diagnostic values $01-$13 are contiguous and index bounded parallel tables;
; zero, out-of-range, and $FF values use the unknown fallback.
;
; Inputs:  A = CASM_DIAG_* identifier
; Outputs: none
; Flags:   undefined after diagPrintString
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
diagPrintFatal:
    cmp #CASM_DIAG_INIT_FAILED
    bcc dpfUnknown
    cmp #CASM_DIAG_PHASE6B_LAST + 1
    bcs dpfUnknown
    sec
    sbc #CASM_DIAG_INIT_FAILED
    tax
    lda diagMessageLo, x
    pha
    lda diagMessageHi, x
    tay
    pla
    tax
    jsr diagPrintString
    ; WP15: append the source location and caret when the raise site recorded
    ; one. Self-gating, so diagnostics with no source position are unchanged.
    jmp diagPrintSourceContext
dpfUnknown:
    ldx #<msgUnknown
    ldy #>msgUnknown
    jmp diagPrintString

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
    jmp diagPrintString

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
    lda #CASM_DIAG_LOC_BYTE
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
    jmp diagPrintLineAndCaret
@noText:
    rts

; ---------------------------------------------------------------------------
; diagDumpToken
; Format and print the current token to screen.
; ---------------------------------------------------------------------------
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

.segment "RODATA"

diagMessageLo:
    .byte <msgInitFailed
    .byte <msgRegistryFull
    .byte <msgCleanupFailed
    .byte <msgSourceRequired
    .byte <msgExtraSource
    .byte <msgMalformedOutput
    .byte <msgDuplicateOption
    .byte <msgUnknownOption
    .byte <msgFilenameTooLong
    .byte <msgNotImplemented
    .byte <msgInputOpenFailed
    .byte <msgInputReadFailed
    .byte <msgInputCloseFailed
    .byte <msgOutputCreateFailed
    .byte <msgOutputWriteFailed
    .byte <msgOutputCloseFailed
    .byte <msgOutputDeleteFailed
    .byte <msgOutputShortWrite
    .byte <msgStreamStateFailed
    .byte <msgSourceRewindFailed
    .byte <msgSourceOffsetOverflow
    .byte <msgSourceLocationOverflow
    .byte <msgSourceLineTooLong
    .byte <msgTokenTooLong
    .byte <msgInvalidSourceByte
    .byte <msgMalformedNumber
    .byte <msgLexerStateFailed
    .byte <msgSyntaxError
    .byte <msgExpectedNewline
    .byte <msgOperandOutOfRange
    .byte <msgInvalidAddrMode
    .byte <msgDuplicateOrg
    .byte <msgOrgRequired
    .byte <msgAddressOverflow
    .byte <msgBranchOutOfRange
    .byte <msgExprMalformed
    .byte <msgExprUnsupported
    .byte <msgExprOverflow
    .byte <msgResolverFailed
    .byte <msgVmmUnavailable
    .byte <msgVmmAllocFailed
    .byte <msgVmmFreeFailed
    .byte <msgVmmTransferFailed
    .byte <msgDuplicateSymbol
    .byte <msgUndefinedSymbol
    .byte <msgSymbolTableFull
    .byte <msgPassMismatch
diagMessageLoEnd:

diagMessageHi:
    .byte >msgInitFailed
    .byte >msgRegistryFull
    .byte >msgCleanupFailed
    .byte >msgSourceRequired
    .byte >msgExtraSource
    .byte >msgMalformedOutput
    .byte >msgDuplicateOption
    .byte >msgUnknownOption
    .byte >msgFilenameTooLong
    .byte >msgNotImplemented
    .byte >msgInputOpenFailed
    .byte >msgInputReadFailed
    .byte >msgInputCloseFailed
    .byte >msgOutputCreateFailed
    .byte >msgOutputWriteFailed
    .byte >msgOutputCloseFailed
    .byte >msgOutputDeleteFailed
    .byte >msgOutputShortWrite
    .byte >msgStreamStateFailed
    .byte >msgSourceRewindFailed
    .byte >msgSourceOffsetOverflow
    .byte >msgSourceLocationOverflow
    .byte >msgSourceLineTooLong
    .byte >msgTokenTooLong
    .byte >msgInvalidSourceByte
    .byte >msgMalformedNumber
    .byte >msgLexerStateFailed
    .byte >msgSyntaxError
    .byte >msgExpectedNewline
    .byte >msgOperandOutOfRange
    .byte >msgInvalidAddrMode
    .byte >msgDuplicateOrg
    .byte >msgOrgRequired
    .byte >msgAddressOverflow
    .byte >msgBranchOutOfRange
    .byte >msgExprMalformed
    .byte >msgExprUnsupported
    .byte >msgExprOverflow
    .byte >msgResolverFailed
    .byte >msgVmmUnavailable
    .byte >msgVmmAllocFailed
    .byte >msgVmmFreeFailed
    .byte >msgVmmTransferFailed
    .byte >msgDuplicateSymbol
    .byte >msgUndefinedSymbol
    .byte >msgSymbolTableFull
    .byte >msgPassMismatch
diagMessageHiEnd:

.assert diagMessageLoEnd - diagMessageLo = CASM_DIAG_PHASE6B_LAST, error, "CASM diagnostic low table is incomplete"
.assert diagMessageHiEnd - diagMessageHi = CASM_DIAG_PHASE6B_LAST, error, "CASM diagnostic high table is incomplete"

msgInitFailed:
    .byte "CASM: INITIALIZATION FAILED", PetCr, 0
msgRegistryFull:
    .byte "CASM: RESOURCE REGISTRY FULL", PetCr, 0
msgCleanupFailed:
    .byte "CASM: RESOURCE CLEANUP FAILED", PetCr, 0
msgSourceRequired:
    .byte "CASM: SOURCE FILE REQUIRED", PetCr, 0
msgExtraSource:
    .byte "CASM: TOO MANY SOURCE FILES", PetCr, 0
msgMalformedOutput:
    .byte "CASM: MALFORMED /O OPTION", PetCr, 0
msgDuplicateOption:
    .byte "CASM: DUPLICATE OPTION", PetCr, 0
msgUnknownOption:
    .byte "CASM: UNKNOWN OPTION", PetCr, 0
msgFilenameTooLong:
    .byte "CASM: FILENAME TOO LONG", PetCr, 0
msgNotImplemented:
    .byte "CASM: FEATURE NOT IMPLEMENTED", PetCr, 0
msgInputOpenFailed:
    .byte "CASM: CANNOT OPEN INPUT", PetCr, 0
msgInputReadFailed:
    .byte "CASM: INPUT READ FAILED", PetCr, 0
msgInputCloseFailed:
    .byte "CASM: INPUT CLOSE FAILED", PetCr, 0
msgOutputCreateFailed:
    .byte "CASM: CANNOT CREATE OUTPUT", PetCr, 0
msgOutputWriteFailed:
    .byte "CASM: OUTPUT WRITE FAILED", PetCr, 0
msgOutputCloseFailed:
    .byte "CASM: OUTPUT CLOSE FAILED", PetCr, 0
msgOutputDeleteFailed:
    .byte "CASM: OUTPUT DELETE FAILED", PetCr, 0
msgOutputShortWrite:
    .byte "CASM: SHORT OUTPUT WRITE", PetCr, 0
msgStreamStateFailed:
    .byte "CASM: INVALID STREAM STATE", PetCr, 0
msgSourceRewindFailed:
    .byte "CASM: SOURCE REWIND FAILED", PetCr, 0
msgSourceOffsetOverflow:
    .byte "CASM: SOURCE OFFSET OVERFLOW", PetCr, 0
msgSourceLocationOverflow:
    .byte "CASM: SOURCE LOCATION OVERFLOW", PetCr, 0
msgSourceLineTooLong:
    .byte "CASM: SOURCE LINE TOO LONG", PetCr, 0
msgTokenTooLong:
    .byte "CASM: TOKEN TOO LONG", PetCr, 0
msgInvalidSourceByte:
    .byte "CASM: INVALID SOURCE BYTE", PetCr, 0
msgMalformedNumber:
    .byte "CASM: MALFORMED NUMBER", PetCr, 0
msgLexerStateFailed:
    .byte "CASM: INVALID LEXER STATE", PetCr, 0
msgSyntaxError:
    .byte "CASM: SYNTAX ERROR", PetCr, 0
msgExpectedNewline:
    .byte "CASM: EXPECTED NEWLINE", PetCr, 0
msgOperandOutOfRange:
    .byte "CASM: OPERAND OUT OF RANGE", PetCr, 0
msgInvalidAddrMode:
    .byte "CASM: INVALID ADDRESSING MODE", PetCr, 0
msgDuplicateOrg:
    .byte "CASM: DUPLICATE ORG", PetCr, 0
msgOrgRequired:
    .byte "CASM: ORG REQUIRED", PetCr, 0
msgAddressOverflow:
    .byte "CASM: ADDRESS OVERFLOW", PetCr, 0
msgBranchOutOfRange:
    .byte "CASM: BRANCH OUT OF RANGE", PetCr, 0
msgExprMalformed:
    .byte "CASM: MALFORMED EXPRESSION", PetCr, 0
msgExprUnsupported:
    .byte "CASM: EXPRESSION UNSUPPORTED", PetCr, 0
msgExprOverflow:
    .byte "CASM: EXPRESSION OVERFLOW", PetCr, 0
msgResolverFailed:
    .byte "CASM: RESOLVER FAILED", PetCr, 0
msgVmmUnavailable:
    .byte "CASM: VMM UNAVAILABLE", PetCr, 0
msgVmmAllocFailed:
    .byte "CASM: VMM ALLOCATION FAILED", PetCr, 0
msgVmmFreeFailed:
    .byte "CASM: VMM FREE FAILED", PetCr, 0
msgVmmTransferFailed:
    .byte "CASM: VMM TRANSFER FAILED", PetCr, 0
msgDuplicateSymbol:
    .byte "CASM: DUPLICATE SYMBOL", PetCr, 0
msgUndefinedSymbol:
    .byte "CASM: UNDEFINED SYMBOL", PetCr, 0
msgSymbolTableFull:
    .byte "CASM: SYMBOL TABLE FULL", PetCr, 0
msgPassMismatch:
    .byte "CASM: PASS 1/2 MISMATCH", PetCr, 0
msgUnknown:
    .byte "CASM: INTERNAL ERROR", PetCr, 0
msgPhase2Ready:
    .byte "CASM: INPUT VALIDATED", PetCr, 0

; Token dump tables and strings
tokNamesLo:
    .byte <tokNameEof, <tokNameNewline, <tokNameId, <tokNameMnem
    .byte <tokNameDir, <tokNameReg, <tokNameNum, <tokNameComma
    .byte <tokNameColon, <tokNameHash, <tokNameLparen, <tokNameRparen
    .byte <tokNamePlus, <tokNameMinus, <tokNameLess, <tokNameGreater
tokNamesHi:
    .byte >tokNameEof, >tokNameNewline, >tokNameId, >tokNameMnem
    .byte >tokNameDir, >tokNameReg, >tokNameNum, >tokNameComma
    .byte >tokNameColon, >tokNameHash, >tokNameLparen, >tokNameRparen
    .byte >tokNamePlus, >tokNameMinus, >tokNameLess, >tokNameGreater

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
msgCR:            .byte PetCr, 0

; WP15 source context strings.
msgAtLine:       .byte "AT LINE ", 0
msgColPrefix:    .byte ", COL ", 0
msgOffsetPrefix: .byte " (OFFSET ", 0
msgOffsetSuffix: .byte ")", 0
msgBytePrefix:   .byte " BYTE ", 0
msgIndent:       .byte "  ", 0
msgClipLeft:     .byte "<.", 0
msgClipRight:    .byte ".>", 0
