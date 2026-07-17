; src/external/casm/fileio.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Managed Command 64 file wrappers for CASM Phase 2. Every successful open is
; registered immediately with the central resource owner. Output routines are
; compiled against the stable ABI but remain inactive until static output has
; real bytes to serialize.

.include "command64.inc"
.include "common.inc"

.import resourceRegisterHandle
.import resourceReleaseHandle
.import CasmSourceName
.import CasmOutputName

.export fileIoInit
.export fileOpenInput
.export fileCreateOutput
.export fileRead
.export fileWrite
.export fileClose
.export fileDelete
.export inputStreamOpen
.export inputStreamRead
.export inputStreamClose
.export outputAbort

.export CasmIoBuffer
.export CasmInputHandle
.export CasmInputSlot
.export CasmInputState
.export CasmInputTotalLo
.export CasmInputTotalHi
.export CasmOutputHandle
.export CasmOutputSlot
.export CasmOutputState
.export CasmOutputCreated
.export CasmOutputValid

.segment "BSS"

CasmIoBuffer:      .res CASM_IO_BUFFER_SIZE
CasmInputHandle:   .res 1
CasmInputSlot:     .res 1
CasmInputState:    .res 1
CasmInputTotalLo:  .res 1
CasmInputTotalHi:  .res 1
CasmOutputHandle:  .res 1
CasmOutputSlot:    .res 1
CasmOutputState:   .res 1
CasmOutputCreated: .res 1
CasmOutputValid:   .res 1
CasmRequestLo:     .res 1
CasmRequestHi:     .res 1
CasmCloseSlot:     .res 1
CasmCloseDiag:     .res 1
CasmFilePrimary:   .res 1

.segment "CODE"

; ---------------------------------------------------------------------------
; fileIoInit
; Initialize all local file and stream ownership mirrors.
;
; Inputs:    none
; Outputs:   A = CASM_DIAG_NONE, C clear, Z set
; Preserves: X, Y
; Clobbers:  A, processor flags
; Scratch:   none
; ---------------------------------------------------------------------------
fileIoInit:
    lda #CASM_INVALID_HANDLE
    sta CasmInputHandle
    sta CasmOutputHandle
    lda #CASM_INVALID_SLOT
    sta CasmInputSlot
    sta CasmOutputSlot
    lda #CASM_FILE_STATE_CLOSED
    sta CasmInputState
    sta CasmOutputState
    lda #0
    sta CasmInputTotalLo
    sta CasmInputTotalHi
    sta CasmOutputCreated
    sta CasmOutputValid
    sta CasmRequestLo
    sta CasmRequestHi
    sta CasmCloseSlot
    sta CasmCloseDiag
    sta CasmFilePrimary
    clc
    rts

; ---------------------------------------------------------------------------
; fileOpenInput
; Open and immediately register one read-only source file.
;
; Inputs:    X/Y = null-terminated filename pointer (low/high)
; Outputs:   C clear, A = CASM_DIAG_NONE on success
;            C set, A = CASM_DIAG_INPUT_OPEN_FAILED or registry diagnostic
; Preserves: none
; Clobbers:  A, X, Y, HexValLo/Hi, FileHandle, OS API volatile state
; Scratch:   CasmValue1Lo
; ---------------------------------------------------------------------------
fileOpenInput:
    lda CasmInputState
    cmp #CASM_FILE_STATE_CLOSED
    bne foiBadState
    lda #CASM_FILE_MODE_READ
    sta HexValLo
    lda #0
    sta HexValHi
    lda #DOS_OPEN_FILE
    jsr OS_API
    bcs foiOpenFailed
    sta CasmValue1Lo
    jsr resourceRegisterHandle
    bcs foiRegistrationFailed
    stx CasmInputSlot
    lda CasmValue1Lo
    sta CasmInputHandle
    lda #CASM_FILE_STATE_OPEN
    sta CasmInputState
    lda #CASM_DIAG_NONE
    clc
    rts

foiRegistrationFailed:
    sta CasmFilePrimary
    lda CasmValue1Lo
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr OS_API
    lda CasmFilePrimary
    sec
    rts
foiOpenFailed:
    lda #CASM_DIAG_INPUT_OPEN_FAILED
    sec
    rts
foiBadState:
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; fileCreateOutput
; Create and immediately register one future PRG output file.
;
; Inputs:    X/Y = null-terminated filename pointer (low/high)
; Outputs:   C clear, A = CASM_DIAG_NONE on success
;            C set, A = CASM_DIAG_OUTPUT_CREATE_FAILED or registry diagnostic
; Preserves: none
; Clobbers:  A, X, Y, HexValLo/Hi, FileHandle, OS API volatile state
; Scratch:   CasmValue1Lo
; ---------------------------------------------------------------------------
fileCreateOutput:
    lda CasmOutputState
    cmp #CASM_FILE_STATE_CLOSED
    bne fcoBadState
    lda #CASM_FILE_MODE_WRITE
    sta HexValLo
    lda #CASM_OUTPUT_FILE_TYPE
    sta HexValHi
    lda #DOS_OPEN_FILE
    jsr OS_API
    bcs fcoCreateFailed
    sta CasmValue1Lo
    jsr resourceRegisterHandle
    bcs fcoRegistrationFailed
    stx CasmOutputSlot
    lda CasmValue1Lo
    sta CasmOutputHandle
    lda #CASM_FILE_STATE_OPEN
    sta CasmOutputState
    lda #CASM_OUTPUT_CREATED
    sta CasmOutputCreated
    lda #CASM_OUTPUT_VALID
    sta CasmOutputValid
    lda #CASM_DIAG_NONE
    clc
    rts

fcoRegistrationFailed:
    sta CasmFilePrimary
    lda CasmValue1Lo
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr OS_API
    lda CasmFilePrimary
    sec
    rts
fcoCreateFailed:
    lda #CASM_DIAG_OUTPUT_CREATE_FAILED
    sec
    rts
fcoBadState:
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; fileRead
; Read a bounded block from the managed input handle and normalize EOF.
;
; Inputs:    X/Y = destination pointer (low/high)
;            CasmIoLenLo/Hi = requested byte count
; Outputs:   C clear, A = CASM_STREAM_DATA or CASM_STREAM_EOF
;            CasmIoLenLo/Hi = actual byte count
;            C set, A = CASM_DIAG_* on failure
; Preserves: none
; Clobbers:  A, X, Y, HexValLo/Hi, FileHandle, OS API volatile state
; Scratch:   none
; ---------------------------------------------------------------------------
fileRead:
    lda CasmInputState
    cmp #CASM_FILE_STATE_OPEN
    bne frBadState
    lda CasmInputHandle
    sta FileHandle
    lda CasmIoLenLo
    sta HexValLo
    lda CasmIoLenHi
    sta HexValHi
    lda #DOS_READ_FILE
    jsr OS_API
    php
    lda HexValLo
    sta CasmIoLenLo
    lda HexValHi
    sta CasmIoLenHi
    plp
    bcc frOsSuccess
    lda CasmIoLenLo
    ora CasmIoLenHi
    beq frEof
    lda #CASM_STREAM_ERROR
    sta CasmInputState
    lda #CASM_DIAG_INPUT_READ_FAILED
    sec
    rts
frOsSuccess:
    lda CasmIoLenLo
    ora CasmIoLenHi
    beq frEof
    lda #CASM_STREAM_DATA
    clc
    rts
frEof:
    lda #CASM_STREAM_EOF
    sta CasmInputState
    clc
    rts
frBadState:
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; fileWrite
; Write one bounded block to the managed output and reject short writes.
;
; Inputs:    X/Y = source pointer (low/high)
;            CasmIoLenLo/Hi = requested byte count
; Outputs:   C clear, A = CASM_DIAG_NONE on full write
;            CasmIoLenLo/Hi = actual byte count
;            C set, A = output write/short-write diagnostic on failure
; Preserves: none
; Clobbers:  A, X, Y, HexValLo/Hi, FileHandle, OS API volatile state
; Scratch:   none
; ---------------------------------------------------------------------------
fileWrite:
    lda CasmOutputState
    cmp #CASM_FILE_STATE_OPEN
    bne fwBadState
    lda CasmIoLenLo
    sta CasmRequestLo
    sta HexValLo
    lda CasmIoLenHi
    sta CasmRequestHi
    sta HexValHi
    lda CasmOutputHandle
    sta FileHandle
    lda #DOS_WRITE_FILE
    jsr OS_API
    php
    lda HexValLo
    sta CasmIoLenLo
    lda HexValHi
    sta CasmIoLenHi
    plp
    bcs fwWriteFailed
    lda CasmIoLenLo
    cmp CasmRequestLo
    bne fwShortWrite
    lda CasmIoLenHi
    cmp CasmRequestHi
    bne fwShortWrite
    lda #CASM_DIAG_NONE
    clc
    rts
fwWriteFailed:
    lda #CASM_OUTPUT_INVALID
    sta CasmOutputValid
    lda #CASM_DIAG_OUTPUT_WRITE_FAILED
    sec
    rts
fwShortWrite:
    lda #CASM_OUTPUT_INVALID
    sta CasmOutputValid
    lda #CASM_DIAG_OUTPUT_SHORT_WRITE
    sec
    rts
fwBadState:
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; fileClose
; Close one registered handle and release its registry slot only after the OS
; close succeeds.
;
; Inputs:    A = file handle, X = registry slot, Y = failure diagnostic
; Outputs:   C clear, A = CASM_DIAG_NONE on success
;            C set, A = caller-supplied close diagnostic on failure
; Preserves: none
; Clobbers:  A, X, Y, FileHandle, OS API volatile state
; Scratch:   CasmCloseSlot, CasmCloseDiag
; ---------------------------------------------------------------------------
fileClose:
    stx CasmCloseSlot
    sty CasmCloseDiag
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr OS_API
    bcs fcFailed
    ldx CasmCloseSlot
    jsr resourceReleaseHandle
    bcs fcFailed
    lda #CASM_DIAG_NONE
    clc
    rts
fcFailed:
    lda CasmCloseDiag
    sec
    rts

; ---------------------------------------------------------------------------
; fileDelete
; Delete the bounded output filename through the native file service.
;
; Inputs:    X/Y = null-terminated filename pointer (low/high)
; Outputs:   C clear, A = CASM_DIAG_NONE on success
;            C set, A = CASM_DIAG_OUTPUT_DELETE_FAILED on failure
; Preserves: none
; Clobbers:  A, X, Y, OS API volatile state
; Scratch:   none
; ---------------------------------------------------------------------------
fileDelete:
    lda #DOS_DELETE_FILE
    jsr OS_API
    bcs fdFailed
    lda #CASM_DIAG_NONE
    clc
    rts
fdFailed:
    lda #CASM_DIAG_OUTPUT_DELETE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; inputStreamOpen
; Open CasmSourceName and reset the checked 16-bit consumed-byte count.
;
; Inputs:    CasmSourceName = parsed null-terminated filename
; Outputs:   C clear, A = CASM_DIAG_NONE on success; C set with diagnostic
; Preserves: none
; Clobbers:  A, X, Y and fileOpenInput clobbers
; Scratch:   none
; ---------------------------------------------------------------------------
inputStreamOpen:
    lda #0
    sta CasmInputTotalLo
    sta CasmInputTotalHi
    ldx #<CasmSourceName
    ldy #>CasmSourceName
    jmp fileOpenInput

; ---------------------------------------------------------------------------
; inputStreamRead
; Read the next 256-byte block into CasmIoBuffer and advance the checked total.
;
; Inputs:    managed input stream is open
; Outputs:   C clear, A = CASM_STREAM_DATA or CASM_STREAM_EOF
;            CasmIoLenLo/Hi = actual byte count
;            C set, A = CASM_DIAG_* on failure or 16-bit total overflow
; Preserves: none
; Clobbers:  A, X, Y and fileRead clobbers
; Scratch:   none
; ---------------------------------------------------------------------------
inputStreamRead:
    lda #<CASM_IO_BUFFER_SIZE
    sta CasmIoLenLo
    lda #>CASM_IO_BUFFER_SIZE
    sta CasmIoLenHi
    ldx #<CasmIoBuffer
    ldy #>CasmIoBuffer
    jsr fileRead
    bcs isrReturn
    cmp #CASM_STREAM_EOF
    beq isrEof
    lda CasmInputTotalLo
    clc
    adc CasmIoLenLo
    sta CasmInputTotalLo
    lda CasmInputTotalHi
    adc CasmIoLenHi
    sta CasmInputTotalHi
    bcs isrOverflow
    lda #CASM_STREAM_DATA
    clc
isrReturn:
    rts
isrEof:
    clc
    rts
isrOverflow:
    ; A source larger than 65,535 bytes overruns the checked fetched total.
    ; WP4 maps this to the single stable source-offset overflow diagnostic so
    ; oversized input has one code shared with sourceNextByte's offset guard.
    lda #CASM_STREAM_ERROR
    sta CasmInputState
    lda #CASM_DIAG_SOURCE_OFFSET_OVERFLOW
    sec
    rts

; ---------------------------------------------------------------------------
; inputStreamClose
; Close the managed input. A failed close remains owned for central cleanup.
;
; Inputs:    local input state
; Outputs:   C clear, A = CASM_DIAG_NONE if closed/already closed
;            C set, A = CASM_DIAG_INPUT_CLOSE_FAILED on failure
; Preserves: none
; Clobbers:  A, X, Y and fileClose clobbers
; Scratch:   none
; ---------------------------------------------------------------------------
inputStreamClose:
    lda CasmInputState
    cmp #CASM_FILE_STATE_CLOSED
    beq iscAlreadyClosed
    lda CasmInputHandle
    ldx CasmInputSlot
    ldy #CASM_DIAG_INPUT_CLOSE_FAILED
    jsr fileClose
    bcs iscFailed
    lda #CASM_INVALID_HANDLE
    sta CasmInputHandle
    lda #CASM_INVALID_SLOT
    sta CasmInputSlot
    lda #CASM_FILE_STATE_CLOSED
    sta CasmInputState
iscAlreadyClosed:
    lda #CASM_DIAG_NONE
    clc
    rts
iscFailed:
    lda #CASM_FILE_STATE_CLOSE_FAILED
    sta CasmInputState
    lda #CASM_DIAG_INPUT_CLOSE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; outputAbort
; Best-effort close and delete for a Phase 5-created incomplete output while
; preserving the primary failure. Phase 2 compiles this path but does not call
; it from production orchestration.
;
; Inputs:    A = primary CASM_DIAG_* value, or CASM_DIAG_NONE
; Outputs:   A = preserved primary, or first cleanup diagnostic if none
;            C set when returned A is nonzero, clear otherwise
; Preserves: none
; Clobbers:  A, X, Y and fileClose/fileDelete clobbers
; Scratch:   CasmFilePrimary
; ---------------------------------------------------------------------------
outputAbort:
    sta CasmFilePrimary
    lda CasmOutputState
    cmp #CASM_FILE_STATE_CLOSED
    beq oaDelete
    lda CasmOutputHandle
    ldx CasmOutputSlot
    ldy #CASM_DIAG_OUTPUT_CLOSE_FAILED
    jsr fileClose
    bcs oaCloseFailed
    lda #CASM_INVALID_HANDLE
    sta CasmOutputHandle
    lda #CASM_INVALID_SLOT
    sta CasmOutputSlot
    lda #CASM_FILE_STATE_CLOSED
    sta CasmOutputState
    jmp oaDelete
oaCloseFailed:
    lda #CASM_FILE_STATE_CLOSE_FAILED
    sta CasmOutputState
    lda #CASM_DIAG_OUTPUT_CLOSE_FAILED
    jsr oaRecordSecondary
    jmp oaReturn

oaDelete:
    lda CasmOutputCreated
    beq oaReturn
    ldx #<CasmOutputName
    ldy #>CasmOutputName
    jsr fileDelete
    bcc oaDeleteDone
    jsr oaRecordSecondary
    jmp oaReturn
oaDeleteDone:
    lda #CASM_OUTPUT_NOT_CREATED
    sta CasmOutputCreated

oaReturn:
    lda CasmFilePrimary
    beq oaSuccess
    sec
    rts
oaSuccess:
    clc
    rts

; Input: A = secondary diagnostic. Preserve a nonzero primary.
oaRecordSecondary:
    pha
    lda CasmFilePrimary
    bne oaKeepPrimary
    pla
    sta CasmFilePrimary
    rts
oaKeepPrimary:
    pla
    rts
