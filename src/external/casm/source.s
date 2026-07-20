; src/external/casm/source.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 3 source backend (WP4 traversal, WP5 normalization). This module
; owns the executable byte-stream source layer that sits over the Phase 2
; managed input wrapper and the WP3 bounded source subrecord in state.s. It
; initializes source state, opens exactly one source, refills and traverses the
; shared 256-byte CasmIoBuffer, exposes a repeat-stable EOF, and closes through
; the central resource owner.
;
; WP5 normalizes newlines and tracks provenance. sourceNextByte collapses CR,
; LF, and CRLF (including CRLF split across a block boundary) into one
; CASM_SOURCE_NEWLINE result via the persistent pending-CR latch, resolves a
; final CR before EOF, and advances one-based line/column plus the physical
; offset with checked commits. A non-newline byte is delivered raw in
; CasmSourceResultByte as CASM_SOURCE_BYTE; a zero byte remains a valid BYTE
; result and is never inferred from A or Z. CasmSourceResultByte is 0 for
; NEWLINE and EOF. sourceGetLocation exposes the next result's provenance.
;
; Rewind and the bounded line API remain WP6; the lexer remains WP7. This
; translation unit imports the WP3 source subrecord and the Phase 2 file
; wrappers. It defines no BSS, writes no lexer state, and calls no OS service
; except through inputStreamOpen/inputStreamRead/inputStreamClose.

.include "common.inc"

; WP3 bounded source state (storage-only state.s).
.import CasmSourceApiMode
.import CasmSourceState
.import CasmSourceFileId
.import CasmSourceBlockLenLo
.import CasmSourceBlockLenHi
.import CasmSourceBlockIndexLo
.import CasmSourceBlockIndexHi
.import CasmSourceOffsetLo
.import CasmSourceOffsetHi
.import CasmSourceLineLo
.import CasmSourceLineHi
.import CasmSourceColumn
.import CasmSourcePendingCr
.import CasmSourceResultByte
.import CasmSourceLineLength
.import CasmSourceLineState

; WP15 diagnostic line echo. Written here and never read by traversal: no
; source decision may depend on these.
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
.import CasmDiagCapture

; Phase 2 managed file services and shared transfer state.
.import inputStreamOpen
.import inputStreamRead
.import inputStreamReadInto
.import inputStreamClose
.import CasmIoBuffer
.import CasmInputState
.import CasmInputTotalLo
.import CasmInputTotalHi

.export sourceInit
.export sourceOpen
.export sourceNextByte
.export sourceNextLine
.export sourceGetLocation
.export sourceRewind
.export sourceClose
.export sourceDrainLineTail

.segment "CODE"

; ---------------------------------------------------------------------------
; sourceInit
; Initialize the complete 16-byte source subrecord to CLOSED/NONE with an
; initialized traversal cursor. Does not call fileIoInit, close a handle, or
; touch lexer state. Orchestration calls it after fileIoInit and before
; sourceOpen.
;
; Inputs:    none
; Outputs:   A = CASM_DIAG_NONE, C clear, Z set
; Preserves: X, Y
; Clobbers:  A, processor flags
; Scratch:   none
; ---------------------------------------------------------------------------
sourceInit:
    lda #CASM_SOURCE_API_NONE
    sta CasmSourceApiMode
    lda #CASM_SOURCE_STATE_CLOSED
    sta CasmSourceState
    jsr sourceResetTraversal
    lda #CASM_DIAG_NONE
    clc
    rts

; ---------------------------------------------------------------------------
; sourceOpen
; Open the parsed source through the Phase 2 wrapper. Only a successful open
; commits READY state and BYTE mode and resets the traversal cursor. An invalid
; state returns CASM_DIAG_STREAM_STATE_FAILED without an OS call; an open
; failure leaves the source CLOSED/NONE and does not alter Phase 2's central
; ownership outcome.
;
; Inputs:    initialized source state (CLOSED); parsed CasmSourceName;
;            initialized Phase 2 file services (input CLOSED)
; Outputs:   A = CASM_DIAG_NONE, C clear on success; state READY, API BYTE
;            A = CASM_DIAG_*, C set on failure
; Preserves: none
; Clobbers:  A, X, Y, source scratch, inputStreamOpen/OS volatile state
; Scratch:   none
; ---------------------------------------------------------------------------
sourceOpen:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_CLOSED
    bne soBadState
    lda CasmInputState
    cmp #CASM_FILE_STATE_CLOSED
    bne soBadState
    jsr inputStreamOpen
    bcs soOpenFailed
    ; Successful open: commit READY/BYTE, then reset the traversal cursor so a
    ; later WP6 reopen can share the same reset path.
    lda #CASM_SOURCE_STATE_READY
    sta CasmSourceState
    lda #CASM_SOURCE_API_BYTE
    sta CasmSourceApiMode
    jsr sourceResetTraversal
    lda #CASM_DIAG_NONE
    clc
    rts
soOpenFailed:
    ; A already holds the wrapper diagnostic; leave source CLOSED/NONE.
    sec
    rts
soBadState:
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; sourceNextByte (WP5 normalized ABI)
; Return the next normalized result: a raw non-newline byte, one collapsed
; newline for CR/LF/CRLF, a repeat-stable EOF, or a failure. The raw byte is
; delivered in CasmSourceResultByte and never inferred from A or Z; the byte is
; 0 for NEWLINE and EOF.
;
; Inputs:    source state READY/BYTE or EOF/BYTE; API mode BYTE
; Outputs:   Byte:    A = CASM_SOURCE_BYTE, C clear, Z clear;
;                     CasmSourceResultByte = raw byte at (line, column)
;            Newline: A = CASM_SOURCE_NEWLINE, C clear, Z clear;
;                     CasmSourceResultByte = 0
;            EOF:     A = CASM_SOURCE_EOF, C clear, Z clear;
;                     CasmSourceResultByte = 0
;            Fail:    A = CASM_DIAG_*, C set; source state ERROR
; Preserves: none
; Clobbers:  A, X, Y, source scratch (CasmSourceScratch0), refill/OS volatile
;            state on refill
; Scratch:   CasmSourceScratch0 holds the current physical byte
;
; The mode gate rejects a byte call once line mode has been claimed; the two
; APIs cannot be mixed without an explicit sourceRewind. sourceNextLine shares
; the normalization below through the private sourceNextResult entry, which
; carries no mode gate.
; ---------------------------------------------------------------------------
sourceNextByte:
    lda CasmSourceApiMode
    cmp #CASM_SOURCE_API_BYTE
    beq sourceNextResult
    jmp snbBadState             ; LINE claimed or NONE -> API mixing/state failure

; ---------------------------------------------------------------------------
; sourceNextResult (private)
; The WP5 normalized traversal without the API mode gate. sourceNextByte and
; sourceNextLine both enter here.
; ---------------------------------------------------------------------------
sourceNextResult:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_EOF
    beq snbEofNear
    cmp #CASM_SOURCE_STATE_READY
    bne snbBadStateNear
    jmp snbFetch

; Trampolines: the WP15 line echo lengthened the byte-return path, pushing the
; shared result and failure tails out of branch range from here.
snbEofNear:
    jmp snbEof
snbBadStateNear:
    jmp snbBadState
snbFailNear:
    jmp snbFail

snbFetch:
    jsr sourceFetchPhysical
    bcs snbFailNear             ; fetch error; source already ERROR
    cmp #CASM_SOURCE_EOF
    beq snbEofFromFetch
    ; A = CASM_STREAM_DATA; the physical byte is in CasmSourceScratch0.

    ; Pending-CR latch: if the previous result was a CR newline and this byte is
    ; the LF half of a CRLF, swallow it (its offset is already counted) and fetch
    ; the following byte. Any other byte ends the pending state.
    lda CasmSourcePendingCr
    beq snbClassify
    lda #0
    sta CasmSourcePendingCr
    lda CasmSourceScratch0
    cmp #CASM_PETSCII_LF
    beq snbFetch

snbClassify:
    lda CasmSourceScratch0
    cmp #CASM_PETSCII_CR
    beq snbNewlineCr
    cmp #CASM_PETSCII_LF
    beq snbNewlineLf

    ; Normal byte at the current column; the exhausted latch (column 0) means a
    ; further byte on this line would overflow the 8-bit column.
    lda CasmSourceColumn
    beq snbColumnOverflow
    lda CasmSourceScratch0
    sta CasmSourceResultByte
    ; Advance the column: 255 enters the exhausted latch, otherwise increment.
    lda CasmSourceColumn
    cmp #CASM_SOURCE_COLUMN_MAX
    bcc snbColumnInc            ; column < 255
    lda #0                      ; column == 255 -> exhausted latch
    sta CasmSourceColumn
    jmp snbByteReturn
snbColumnInc:
    inc CasmSourceColumn
snbByteReturn:
    ; WP15: echo the delivered byte into the diagnostic line buffer. Capture
    ; happens here, in the source layer, rather than in the lexer because the
    ; lexer discards whitespace and comment bodies without recording them; a
    ; line echoed from there would have holes in it and misalign the caret.
    lda CasmDiagCapture
    beq snbEchoDone
    lda CasmSourceResultByte
    jsr diagLineAppend
snbEchoDone:
    lda #CASM_SOURCE_BYTE
    clc
    rts

snbNewlineLf:
    ; LF newline: pending-CR stays clear.
    jsr sourceAdvanceNewline
    bcs snbLocFail
    lda #0
    sta CasmSourceResultByte
    lda #CASM_SOURCE_NEWLINE
    clc
    rts
snbNewlineCr:
    ; CR newline: emit one newline now and arm the pending-CR latch so an
    ; immediately following LF collapses into this CRLF.
    jsr sourceAdvanceNewline
    bcs snbLocFail
    lda #1
    sta CasmSourcePendingCr
    lda #0
    sta CasmSourceResultByte
    lda #CASM_SOURCE_NEWLINE
    clc
    rts

snbEof:
    ; Repeat-stable EOF: no OS read, no cursor mutation. CasmSourceResultByte
    ; was cleared when EOF was first committed.
    lda #CASM_SOURCE_EOF
    clc
    rts
snbEofFromFetch:
    ; sourceFetchPhysical committed EOF and cleared CasmSourceResultByte. Clear
    ; pending-CR: a final CR already emitted its newline before this EOF.
    lda #0
    sta CasmSourcePendingCr
    lda #CASM_SOURCE_EOF
    clc
    rts
snbFail:
    ; A holds the fetch diagnostic; source state is already ERROR.
    sec
    rts
snbLocFail:
    ; sourceAdvanceNewline set source ERROR and left A = diagnostic, C set.
    sec
    rts
snbColumnOverflow:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_SOURCE_LOCATION_OVERFLOW
    sec
    rts
snbBadState:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; sourceNextLine
; Return one bounded logical line. The payload is CasmIoBuffer[0 .. length-1],
; null-terminated at [length]; a 255-byte payload plus terminator exactly fills
; the 256-byte buffer. The line is valid only until the next source call.
;
; Line mode is claimed here on a fresh stream and reuses the WP5 normalization
; through sourceNextResult, so newline collapsing, provenance, and EOF behave
; exactly as in byte mode. While a line is built, CasmIoBuffer is partitioned:
; [0 .. lineLength-1] is the payload and [lineLength .. 255] is the unread
; transfer region that sourceRefill reads into.
;
; Buffer-aliasing safety: the write position (CasmSourceLineLength) is always
; less than or equal to the read position (CasmSourceBlockIndex). They are equal
; only immediately after a LINE-mode refill, and because sourceNextResult loads
; the byte into CasmSourceResultByte before it is stored here, that case is a
; read-then-write of the same cell. A CRLF swallow or a newline advances the
; read position without advancing the write position, only widening the margin.
;
; Inputs:    line mode claimed or claimable; state READY or EOF
; Outputs:   Line: A = CASM_SOURCE_NEWLINE, C clear; CasmSourceLineLength = length,
;                  CasmSourceLineState = READY (newline) or EOF (final partial)
;            EOF:  A = CASM_SOURCE_EOF, C clear; CasmSourceLineLength = 0
;            Fail: A = CASM_DIAG_STREAM_STATE_FAILED, CASM_DIAG_SOURCE_LINE_TOO_LONG,
;                  CASM_DIAG_INVALID_SOURCE_BYTE, or a propagated byte
;                  diagnostic; C set; source state ERROR
; Preserves: none
; Clobbers:  A, X, Y, source scratch, refill/OS volatile state
; ---------------------------------------------------------------------------
sourceNextLine:
    lda CasmSourceApiMode
    cmp #CASM_SOURCE_API_LINE
    beq snlModeReady            ; line mode already claimed
    cmp #CASM_SOURCE_API_BYTE
    bne snlBadStateNear         ; NONE -> not open
    ; Byte mode may be promoted to line mode only on a fresh stream. Once any
    ; byte has been consumed, mixing the APIs requires an explicit rewind.
    lda CasmSourceOffsetLo
    ora CasmSourceOffsetHi
    bne snlBadStateNear
    lda CasmSourceLineState
    cmp #CASM_SOURCE_LINE_IDLE
    bne snlBadStateNear
    lda #CASM_SOURCE_API_LINE
    sta CasmSourceApiMode
    jmp snlModeReady

snlBadStateNear:
    ; Trampoline: the shared failure tail is out of branch range from here.
    jmp snlBadState

snlModeReady:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_EOF
    beq snlEof
    cmp #CASM_SOURCE_STATE_READY
    bne snlBadStateNear

    lda #0
    sta CasmSourceLineLength
    lda #CASM_SOURCE_LINE_BUILDING
    sta CasmSourceLineState

snlLoop:
    jsr sourceNextResult
    bcs snlFail                 ; source already ERROR
    cmp #CASM_SOURCE_NEWLINE
    beq snlLineReady
    cmp #CASM_SOURCE_EOF
    beq snlEofReached

    ; Byte: an embedded null is invalid source in the line API (byte mode still
    ; returns it as a valid CASM_SOURCE_BYTE).
    lda CasmSourceResultByte
    beq snlInvalidByte
    ; Reject an overlong line before storing the overflowing byte.
    lda CasmSourceLineLength
    cmp #CASM_SOURCE_LINE_PAYLOAD_MAX
    bcs snlTooLong              ; already 255 payload bytes
    ldx CasmSourceLineLength
    lda CasmSourceResultByte
    sta CasmIoBuffer,x
    inc CasmSourceLineLength
    jmp snlLoop

snlLineReady:
    lda #CASM_SOURCE_LINE_READY
    sta CasmSourceLineState
snlReturnLine:
    ; Terminate at [length]. That cell is always an already-consumed byte or is
    ; past valid data, never unread input.
    ldx CasmSourceLineLength
    lda #0
    sta CasmIoBuffer,x
    lda #CASM_SOURCE_NEWLINE
    clc
    rts

snlEofReached:
    ; EOF while building: return a final unterminated line if one accumulated,
    ; otherwise report EOF. CasmSourceLineState distinguishes the two.
    lda #CASM_SOURCE_LINE_EOF
    sta CasmSourceLineState
    lda CasmSourceLineLength
    bne snlReturnLine
snlEof:
    lda #0
    sta CasmSourceLineLength
    lda #CASM_SOURCE_LINE_EOF
    sta CasmSourceLineState
    lda #CASM_SOURCE_EOF
    clc
    rts

snlFail:
    ; A holds the propagated byte diagnostic.
    sec
    rts
snlInvalidByte:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_INVALID_SOURCE_BYTE
    sec
    rts
snlTooLong:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_SOURCE_LINE_TOO_LONG
    sec
    rts
snlBadState:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; sourceDrainLineTail (WP15, diagnostic-only and TERMINAL)
; Append the remainder of the current physical line to the diagnostic echo
; buffer, stopping at CR, LF, EOF, a full buffer, or any read failure.
;
; The echo buffer ends at the byte that failed, because that is the last byte
; traversal delivered. Without this routine a diagnostic can only ever show the
; source up to the caret, never the text after it.
;
; CONTRACT -- read before calling:
;   * Call only on the fatal path, immediately before central cleanup. The
;     caller must already have decided to terminate.
;   * This routine deliberately bypasses the source state gate: it runs after
;     the source has been driven into ERROR, which is the whole point. It reads
;     raw physical bytes and does not maintain the line, column, offset, or
;     pending-CR invariants that the normalized traversal guarantees.
;   * It therefore leaves the source unusable for further traversal. Calling it
;     anywhere other than the fatal path will corrupt an in-progress assembly.
;   * It never reports a diagnostic of its own. Any failure silently truncates
;     the displayed line rather than masking the caller's primary diagnostic,
;     which is the diagnostic the user actually needs.
;
; The input stream is still open at this point: casm.s routes a fatal through
; startFatal -> exitFatal -> diagPrintFatal (here) -> resourcesCleanup, and the
; close happens in that last step.
;
; Inputs:    valid echo buffer contents for the current line
; Outputs:   CasmDiagLineLen extended; CasmDiagLineClipped set on overflow
; Preserves: nothing
; Clobbers:  A, X, Y, source scratch, refill/OS volatile state
; ---------------------------------------------------------------------------
sourceDrainLineTail:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_EOF
    beq sdtDone                 ; nothing further to read
sdtLoop:
    lda CasmDiagLineLen
    cmp #CASM_DIAG_LINE_MAX
    bcs sdtDone                 ; buffer full: diagLineAppend already latched it
    jsr sourceFetchPhysical
    bcs sdtDone                 ; read failure: keep what was already captured
    cmp #CASM_SOURCE_EOF
    beq sdtDone
    ; Raw byte: a newline in either encoding ends the line. No normalization is
    ; attempted, since a display tail does not need the pending-CR latch.
    lda CasmSourceScratch0
    cmp #CASM_PETSCII_CR
    beq sdtDone
    cmp #CASM_PETSCII_LF
    beq sdtDone
    jsr diagLineAppend
    jmp sdtLoop
sdtDone:
    rts

; ---------------------------------------------------------------------------
; diagLineAppend (private, WP15)
; Append one byte to whichever echo buffer is currently selected, latching the
; truncation flag instead of overflowing.
;
; Shared by the normalized echo in sourceNextResult and by the fatal-path
; drain, so buffer selection and bounds live in exactly one place.
;
; Inputs:    A = byte to append
; Outputs:   CasmDiagLineLen advanced, or CasmDiagLineClipped latched
; Preserves: nothing
; Clobbers:  A, X, Y, processor flags
; ---------------------------------------------------------------------------
diagLineAppend:
    ldx CasmDiagLineLen
    cpx #CASM_DIAG_LINE_MAX
    bcs dlaFull
    ldy CasmDiagLineSel
    bne dlaBufB
    sta CasmDiagLineBufA,x
    jmp dlaCommit
dlaBufB:
    sta CasmDiagLineBufB,x
dlaCommit:
    inc CasmDiagLineLen
    rts
dlaFull:
    lda #1
    sta CasmDiagLineClipped
    rts

; ---------------------------------------------------------------------------
; sourceRewind
; Close and reopen the source, then reset every source-owned field so a second
; traversal is byte-, newline-, and location-identical to the first. The reopen
; also resets the managed fetched total, so the EOF count invariant holds again.
;
; Lookahead invalidation is deliberately not performed here: lookahead is lexer
; state and this module writes none. WP7 owns invalidating CasmLookahead* after
; a rewind.
;
; Inputs:    source state READY or EOF
; Outputs:   Success: A = CASM_DIAG_NONE, C clear; state READY, API BYTE, reset
;            Fail:    A = CASM_DIAG_INPUT_CLOSE_FAILED (close; source ERROR and
;                     the handle retained in CLOSE_FAILED for central retry),
;                     CASM_DIAG_SOURCE_REWIND_FAILED (reopen; source CLOSED/NONE
;                     with no leaked handle), or CASM_DIAG_STREAM_STATE_FAILED;
;                     C set
; Preserves: none
; Clobbers:  A, X, Y, wrapper/OS volatile state
; ---------------------------------------------------------------------------
sourceRewind:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_READY
    beq srwClose
    cmp #CASM_SOURCE_STATE_EOF
    bne srwBadState
srwClose:
    jsr inputStreamClose
    bcs srwCloseFailed
    jsr inputStreamOpen
    bcs srwReopenFailed
    lda #CASM_SOURCE_STATE_READY
    sta CasmSourceState
    lda #CASM_SOURCE_API_BYTE
    sta CasmSourceApiMode
    jsr sourceResetTraversal
    lda #CASM_DIAG_NONE
    clc
    rts
srwCloseFailed:
    ; The close diagnostic is the primary failure and must not be masked by the
    ; rewind code; inputStreamClose retained ownership in CLOSE_FAILED.
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_INPUT_CLOSE_FAILED
    sec
    rts
srwReopenFailed:
    ; The close succeeded, so no handle is leaked. Report the rewind-specific
    ; primary and leave the source closed.
    lda #CASM_SOURCE_STATE_CLOSED
    sta CasmSourceState
    lda #CASM_SOURCE_API_NONE
    sta CasmSourceApiMode
    lda #CASM_DIAG_SOURCE_REWIND_FAILED
    sec
    rts
srwBadState:
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; sourceGetLocation
; Validate that the next result's provenance is available and representable,
; leaving it readable in the persistent source fields. This is an in-place
; snapshot accessor: the canonical location already lives in CasmSourceFileId,
; CasmSourceOffsetLo/Hi, CasmSourceLineLo/Hi, and CasmSourceColumn, describing
; the next result. A caller reads them immediately and copies them before the
; next mutating call.
;
; Inputs:    source state READY or EOF
; Outputs:   Success: A = CASM_DIAG_NONE, C clear; location fields readable
;            Fail:    A = CASM_DIAG_SOURCE_LOCATION_OVERFLOW (pending column
;                     overflow in READY) or CASM_DIAG_STREAM_STATE_FAILED
;                     (invalid state), C set; state unchanged
; Preserves: X, Y
; Clobbers:  A, processor flags
; Scratch:   none
; ---------------------------------------------------------------------------
sourceGetLocation:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_EOF
    beq sglOk                   ; EOF: location is final, no next byte to overflow
    cmp #CASM_SOURCE_STATE_READY
    bne sglBadState
    ; READY: reject a pending column-exhausted latch, since the next byte would
    ; overflow the 8-bit column.
    lda CasmSourceColumn
    beq sglOverflow
sglOk:
    lda #CASM_DIAG_NONE
    clc
    rts
sglOverflow:
    lda #CASM_DIAG_SOURCE_LOCATION_OVERFLOW
    sec
    rts
sglBadState:
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; sourceFetchPhysical (private)
; Fetch one physical byte from the current block, refilling when the block is
; exhausted. Every fetched byte advances the checked block index and physical
; offset so the offset stays equal to CasmInputTotal at EOF.
;
; Inputs:    source state READY
; Outputs:   Data: A = CASM_STREAM_DATA, C clear; CasmSourceScratch0 = byte,
;                  block index and physical offset advanced
;            EOF:  A = CASM_SOURCE_EOF, C clear; state EOF committed, result
;                  byte cleared (via sourceRefill)
;            Fail: A = CASM_DIAG_*, C set; source state ERROR
; Preserves: none
; Clobbers:  A, X, Y, refill/OS volatile state on refill
; ---------------------------------------------------------------------------
sourceFetchPhysical:
    ; Unsigned 16-bit index < length test decides availability.
    lda CasmSourceBlockIndexLo
    cmp CasmSourceBlockLenLo
    lda CasmSourceBlockIndexHi
    sbc CasmSourceBlockLenHi
    bcc sfpHaveByte             ; index < length -> a byte is available

    ; index >= length: only an exact index == length may refill; index above
    ; length is a corrupt cursor and a stream-state failure.
    lda CasmSourceBlockIndexLo
    cmp CasmSourceBlockLenLo
    bne sfpCursorFail
    lda CasmSourceBlockIndexHi
    cmp CasmSourceBlockLenHi
    bne sfpCursorFail

    jsr sourceRefill
    bcs sfpFail                 ; refill failed; source already ERROR
    cmp #CASM_SOURCE_EOF
    beq sfpEof
    ; Refill installed a nonempty block with index 0; a byte is now available.

sfpHaveByte:
    ; Offset overflow is validated before any cursor or byte is committed.
    lda CasmSourceOffsetLo
    cmp #$FF
    bne sfpOffsetOk
    lda CasmSourceOffsetHi
    cmp #$FF
    beq sfpOffsetOverflow       ; offset == $FFFF -> another byte would overflow
sfpOffsetOk:
    ; index < length and length <= 256 guarantee index high is zero here.
    ldx CasmSourceBlockIndexLo
    lda CasmIoBuffer,x
    sta CasmSourceScratch0
    ; Commit the block index (16-bit).
    inc CasmSourceBlockIndexLo
    bne sfpIndexDone
    inc CasmSourceBlockIndexHi
sfpIndexDone:
    ; Commit the physical consumed offset (16-bit).
    inc CasmSourceOffsetLo
    bne sfpOffsetDone
    inc CasmSourceOffsetHi
sfpOffsetDone:
    lda #CASM_STREAM_DATA
    clc
    rts
sfpEof:
    ; sourceRefill committed EOF with A = CASM_SOURCE_EOF, C clear.
    clc
    rts
sfpFail:
    sec
    rts
sfpOffsetOverflow:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_SOURCE_OFFSET_OVERFLOW
    sec
    rts
sfpCursorFail:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; sourceAdvanceNewline (private)
; Advance the location past one normalized newline: check the 16-bit line for
; overflow, increment it, and reset the column to 1. The column-exhausted latch
; is discarded because the line ended before a further byte was needed.
;
; Inputs:    none
; Outputs:   Success: C clear; line advanced, column reset to 1
;            Fail:    A = CASM_DIAG_SOURCE_LOCATION_OVERFLOW, C set; source ERROR
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
sourceAdvanceNewline:
    lda CasmSourceLineLo
    cmp #<CASM_SOURCE_LINE_MAX
    bne sanAdvance
    lda CasmSourceLineHi
    cmp #>CASM_SOURCE_LINE_MAX
    beq sanOverflow             ; line == $FFFF -> next line would overflow
sanAdvance:
    inc CasmSourceLineLo
    bne sanColumnReset
    inc CasmSourceLineHi
sanColumnReset:
    lda #CASM_SOURCE_COLUMN_INITIAL
    sta CasmSourceColumn
    ; WP15: the line just ended. Demote it to "previous" and start the new line
    ; in the other buffer. The buffers are swapped by flipping the selector, so
    ; no bytes are copied here. Retaining the previous line is what lets an emit
    ; diagnostic still show its source: the parser consumes a statement's
    ; terminating newline before the emission engine runs, so an emit failure
    ; always reports a line that is no longer the current one.
    ;
    ; Recorded unconditionally (not gated on CasmDiagCapture) so a buffer can
    ; never retain stale content from a period when capture was off. Uses only
    ; A, honoring this routine's X/Y preservation contract.
    lda CasmDiagLineLen
    sta CasmDiagPrevLen
    lda CasmDiagLineClipped
    sta CasmDiagPrevClipped
    lda CasmDiagLineNoLo
    sta CasmDiagPrevNoLo
    lda CasmDiagLineNoHi
    sta CasmDiagPrevNoHi
    lda CasmDiagLineSel
    eor #$01                    ; CASM_DIAG_SEL_A <-> CASM_DIAG_SEL_B
    sta CasmDiagLineSel
    lda #0
    sta CasmDiagLineLen
    sta CasmDiagLineClipped
    lda CasmSourceLineLo        ; already advanced to the new line above
    sta CasmDiagLineNoLo
    lda CasmSourceLineHi
    sta CasmDiagLineNoHi
    clc
    rts
sanOverflow:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_SOURCE_LOCATION_OVERFLOW
    sec
    rts

; ---------------------------------------------------------------------------
; sourceClose
; Close the source through the Phase 2 wrapper. Permitted in CLOSED, READY,
; EOF, and ERROR. CLOSED is repeat-safe. A successful close commits CLOSED/NONE
; and clears block/result state. A failed close leaves the source ERROR and the
; Phase 2 handle registered in CLOSE_FAILED so a later sourceClose or central
; cleanup can retry. It does not overwrite a caller's earlier primary
; diagnostic; callers with a primary failure jump to central fatal cleanup.
;
; Inputs:    initialized source state
; Outputs:   A = CASM_DIAG_NONE, C clear, Z set on success; source CLOSED/NONE
;            A = CASM_DIAG_INPUT_CLOSE_FAILED, C set on failure; source ERROR
;            and managed ownership retained
; Preserves: none
; Clobbers:  A, X, Y, inputStreamClose/OS volatile state
; Scratch:   none
; ---------------------------------------------------------------------------
sourceClose:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_CLOSED
    beq scAlreadyClosed
    jsr inputStreamClose
    bcs scFailed
    lda #CASM_SOURCE_STATE_CLOSED
    sta CasmSourceState
    lda #CASM_SOURCE_API_NONE
    sta CasmSourceApiMode
    lda #0
    sta CasmSourceBlockLenLo
    sta CasmSourceBlockLenHi
    sta CasmSourceBlockIndexLo
    sta CasmSourceBlockIndexHi
    sta CasmSourceResultByte
scAlreadyClosed:
    lda #CASM_DIAG_NONE
    clc
    rts
scFailed:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_INPUT_CLOSE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; sourceResetTraversal (private)
; Initialize the traversal, location, and line-window fields to their WP3
; initial values without touching lexer state or Phase 2 ownership. Uses only A
; so sourceInit can honor its X/Y preservation contract.
;
; Inputs:    none
; Outputs:   none
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
sourceResetTraversal:
    lda #0                      ; realizes the $00/$0000 initial values below
    sta CasmSourceFileId        ; CASM_SOURCE_FILE_ID_INITIAL
    sta CasmSourceBlockLenLo
    sta CasmSourceBlockLenHi
    sta CasmSourceBlockIndexLo
    sta CasmSourceBlockIndexHi
    sta CasmSourceOffsetLo      ; CASM_SOURCE_OFFSET_INITIAL
    sta CasmSourceOffsetHi
    sta CasmSourceLineHi        ; CASM_SOURCE_LINE_INITIAL high byte
    sta CasmSourcePendingCr
    sta CasmSourceResultByte
    sta CasmSourceLineLength
    sta CasmSourceLineState     ; CASM_SOURCE_LINE_IDLE
    lda #<CASM_SOURCE_LINE_INITIAL
    sta CasmSourceLineLo
    lda #CASM_SOURCE_COLUMN_INITIAL
    sta CasmSourceColumn
    ; WP15: the echo buffers track the traversal, so a reset or rewind must
    ; discard both and re-anchor the current one to the initial line. The
    ; previous-line number resets to CASM_DIAG_LINE_NONE, which no real
    ; 1-based location can match.
    lda #0
    sta CasmDiagLineLen
    sta CasmDiagLineClipped
    sta CasmDiagLineNoHi        ; CASM_SOURCE_LINE_INITIAL high byte
    sta CasmDiagLineSel         ; CASM_DIAG_SEL_A
    sta CasmDiagPrevLen
    sta CasmDiagPrevClipped
    sta CasmDiagPrevNoLo        ; CASM_DIAG_LINE_NONE
    sta CasmDiagPrevNoHi
    lda #<CASM_SOURCE_LINE_INITIAL
    sta CasmDiagLineNoLo
    rts

; ---------------------------------------------------------------------------
; sourceRefill (private)
; Refill from the managed input only when the current block is exhausted (the
; caller guarantees index == length). Install a validated 1-256-byte block, or
; commit a count-validated first EOF, or fail into source ERROR.
;
; Inputs:    index == length
; Outputs:   Data: A = CASM_STREAM_DATA, C clear; block installed, index 0
;            EOF:  A = CASM_SOURCE_EOF, C clear; state EOF, result byte cleared
;            Fail: A = CASM_DIAG_*, C set; state ERROR
; Preserves: none
; Clobbers:  A, X, Y, inputStreamRead/OS volatile state
; ---------------------------------------------------------------------------
sourceRefill:
    ; Refill only the transfer region above the protected line payload. In BYTE
    ; mode the base is 0, so this is a full-buffer read and the installed cursor
    ; is identical to the pre-WP6 form.
    jsr sourceComputeBase
    beq srFullBlock             ; base 0 -> whole buffer
    ; LINE mode with an accumulated payload: read into CasmIoBuffer + base with
    ; length 256 - base, preserving CasmIoBuffer[0 .. base-1].
    pha
    eor #$FF
    clc
    adc #$01                    ; A = 256 - base (base is 1..255)
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    pla
    clc
    adc #<CasmIoBuffer
    tax
    lda #>CasmIoBuffer
    adc #0
    tay
    jmp srDoRead
srFullBlock:
    lda #<CASM_IO_BUFFER_SIZE
    sta CasmIoLenLo
    lda #>CASM_IO_BUFFER_SIZE
    sta CasmIoLenHi
    ldx #<CasmIoBuffer
    ldy #>CasmIoBuffer
srDoRead:
    jsr inputStreamReadInto
    bcs srReadFailed
    cmp #CASM_STREAM_EOF
    beq srEof

    ; DATA: a zero-length DATA result is inconsistent.
    lda CasmIoLenLo
    ora CasmIoLenHi
    beq srInvalidBlock

    ; Install absolute cursor positions: index = base, length = base + count.
    ; The base is recomputed from persistent state because zero-page source
    ; scratch does not survive the OS read above.
    jsr sourceComputeBase
    sta CasmSourceBlockIndexLo
    lda #0
    sta CasmSourceBlockIndexHi
    lda CasmSourceBlockIndexLo
    clc
    adc CasmIoLenLo
    sta CasmSourceBlockLenLo
    lda #0
    adc CasmIoLenHi
    sta CasmSourceBlockLenHi

    ; Validate the installed end position is 1-256; length 256 encodes as $0100.
    lda CasmSourceBlockLenHi
    beq srInstallDone           ; end 1-255
    cmp #$01
    bne srInvalidBlock          ; end > 256
    lda CasmSourceBlockLenLo
    bne srInvalidBlock          ; $01xx with low != 0 -> end > 256
srInstallDone:
    lda #CASM_STREAM_DATA
    clc
    rts

; ---------------------------------------------------------------------------
; sourceComputeBase (private)
; Return the protected buffer prefix: 0 in BYTE mode, or the accumulated line
; payload length in LINE mode. Derived from persistent state so it is valid
; both before and after an OS read.
;
; Inputs:    none
; Outputs:   A = base, Z set when the base is 0
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
sourceComputeBase:
    lda CasmSourceApiMode
    cmp #CASM_SOURCE_API_LINE
    beq scbLine
    lda #0
    rts
scbLine:
    lda CasmSourceLineLength
    rts

srEof:
    ; First EOF: the consumed cursor must be exhausted and the returned offset
    ; must equal the managed fetched total before EOF is committed.
    lda CasmSourceBlockIndexLo
    cmp CasmSourceBlockLenLo
    bne srEofMismatch
    lda CasmSourceBlockIndexHi
    cmp CasmSourceBlockLenHi
    bne srEofMismatch
    lda CasmSourceOffsetLo
    cmp CasmInputTotalLo
    bne srEofMismatch
    lda CasmSourceOffsetHi
    cmp CasmInputTotalHi
    bne srEofMismatch
    lda #CASM_SOURCE_STATE_EOF
    sta CasmSourceState
    lda #0
    sta CasmSourceResultByte
    lda #CASM_SOURCE_EOF
    clc
    rts
srEofMismatch:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

srReadFailed:
    ; Preserve the wrapper diagnostic (read failure or mapped offset overflow)
    ; while recording the source ERROR state.
    pha
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    pla
    sec
    rts
srInvalidBlock:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts
