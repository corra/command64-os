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

; Phase 2 managed file services and shared transfer state.
.import inputStreamOpen
.import inputStreamRead
.import inputStreamClose
.import CasmIoBuffer
.import CasmInputState
.import CasmInputTotalLo
.import CasmInputTotalHi

.export sourceInit
.export sourceOpen
.export sourceNextByte
.export sourceGetLocation
.export sourceClose

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
; Inputs:    source state READY/BYTE or EOF/BYTE
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
; ---------------------------------------------------------------------------
sourceNextByte:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_EOF
    beq snbEof
    cmp #CASM_SOURCE_STATE_READY
    bne snbBadState

snbFetch:
    jsr sourceFetchPhysical
    bcs snbFail                 ; fetch error; source already ERROR
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
    jsr inputStreamRead
    bcs srReadFailed
    cmp #CASM_STREAM_EOF
    beq srEof

    ; DATA: validate the actual block length is 1-256 before exposing a byte.
    lda CasmIoLenHi
    beq srCheckLoNonZero        ; high 0 -> low must be 1-255
    cmp #$01
    bne srInvalidBlock          ; high > 1 -> length > 256
    lda CasmIoLenLo
    bne srInvalidBlock          ; $01xx with low != 0 -> length > 256
    jmp srInstall               ; length == $0100 (256)
srCheckLoNonZero:
    lda CasmIoLenLo
    beq srInvalidBlock          ; length 0 with a DATA result is inconsistent
srInstall:
    lda CasmIoLenLo
    sta CasmSourceBlockLenLo
    lda CasmIoLenHi
    sta CasmSourceBlockLenHi
    lda #0
    sta CasmSourceBlockIndexLo
    sta CasmSourceBlockIndexHi
    lda #CASM_STREAM_DATA
    clc
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
