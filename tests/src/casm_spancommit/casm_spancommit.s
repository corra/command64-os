; tests/src/casm_spancommit/casm_spancommit.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 10 WP53 increment 3 fixture harness for fileio.s's
; outputCommit and the amended outputAbort -- the PRG commit/abort
; protection pair. Drives both real routines against real DOS_OPEN_FILE/
; DOS_DELETE_FILE calls (through fileCreateOutput/fileOpenInput/outputAbort
; unmodified) so persistence and deletion are proven on the real disk, not
; asserted from in-memory state alone: a case that claims a file survives
; re-opens it for input to prove the claim, and a case that claims a file
; was deleted expects that same re-open to fail.
;
; Filename literals are UPPERCASE, matching casm_listcap.s's own precedent
; for real disk names (its own CASMLO01..CASMLO10 outputs) -- ca65's C64
; charmap turns them into shifted PETSCII, which the OS's DOS_OPEN_FILE
; filename handling accepts. This harness has no expected *content*
; literal to compare (unlike casm_cliderive.s/casm_spanread.s), so the
; lowercase-for-content rule those harnesses' headers document does not
; apply here -- there is no content case to get wrong.
.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_spancommit.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import fileIoInit
.import fileCreateOutput
.import fileOpenInput
.import fileClose
.import outputCommit
.import outputAbort
.import CasmOutputHandle
.import CasmOutputSlot
.import CasmOutputState
.import CasmOutputCommitted
.import CasmInputHandle
.import CasmInputSlot
.import CasmInputState

.export CasmOutputName
; resources.s's exitFatal/VMM-cleanup paths reference these; neither is
; reachable from this harness's all-success flow (see BUILD_CASM_SPANCOMMIT's
; own CMake comment for why they are stubbed here rather than linked whole).
.export diagPrintFatal
.export vmmStoreFree

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda CurrentDevice
    sta TestDevice
    jsr resourcesInit
    lda #0
    sta FailCount

    jsr commitPersists
    jsr reportCase
    jsr resourcesCleanup

    jsr abortAfterCommitProtects
    jsr reportCase
    jsr resourcesCleanup

    jsr abortWithoutCommitDeletes
    jsr reportCase
    jsr resourcesCleanup

    jsr commitBadState
    jsr reportCase
    jsr resourcesCleanup

    jsr doubleCommitFails
    jsr reportCase
    jsr resourcesCleanup

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
; setOutputName
; Copy the null-terminated literal at X/Y into CasmOutputName, so
; fileCreateOutput and outputAbort's own CasmOutputName reference (fileDelete
; target) always name the same real file.
; ---------------------------------------------------------------------------
setOutputName:
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldy #0
sonLoop:
    lda (CasmPtr1Lo), y
    sta CasmOutputName, y
    beq sonDone
    iny
    bne sonLoop
sonDone:
    rts

; ---------------------------------------------------------------------------
; probeFileExists
; Attempt to open CasmOutputName for input, then immediately close it if
; that succeeded. Does not touch CasmOutputState/CasmOutputHandle/Slot: uses
; the independent input mirror, so it is safe to call after outputCommit or
; outputAbort has already run.
; Outputs: C clear if the file opened (and was closed again); C set if it
;          did not (CASM_DIAG_INPUT_OPEN_FAILED) -- i.e. the file is absent
; ---------------------------------------------------------------------------
probeFileExists:
    ldx #<CasmOutputName
    ldy #>CasmOutputName
    jsr fileOpenInput
    bcs pfeAbsent
    lda CasmInputHandle
    ldx CasmInputSlot
    ldy #CASM_DIAG_INPUT_CLOSE_FAILED
    jsr fileClose
    clc
    rts
pfeAbsent:
    sec
    rts

; ---------------------------------------------------------------------------
; diagPrintFatal / vmmStoreFree (stubs)
; Unreachable from this harness's all-success flow; see this file's CMake
; entry for why they are stubbed here instead of linking diagnostics.s or
; vmm_store.s whole.
; ---------------------------------------------------------------------------
diagPrintFatal:
    rts
vmmStoreFree:
    clc
    rts

; ---------------------------------------------------------------------------
; commitPersists
; A freshly created output, once committed, survives: outputCommit reports
; success and releases the handle, and the file is genuinely still openable
; afterward.
; ---------------------------------------------------------------------------
commitPersists:
    jsr fileIoInit
    ldx #<nameCommit1
    ldy #>nameCommit1
    jsr setOutputName
    ldx #<CasmOutputName
    ldy #>CasmOutputName
    jsr fileCreateOutput
    bcs cp1Fail
    jsr outputCommit
    bcs cp1Fail
    cmp #CASM_DIAG_NONE
    bne cp1Fail
    lda CasmOutputState
    cmp #CASM_FILE_STATE_CLOSED
    bne cp1Fail
    lda CasmOutputHandle
    cmp #CASM_INVALID_HANDLE
    bne cp1Fail
    lda CasmOutputCommitted
    cmp #CASM_OUTPUT_COMMITTED
    bne cp1Fail
    jmp probeFileExists
cp1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; abortAfterCommitProtects
; The core WP53 contract: outputAbort called after a successful commit must
; not delete the file, and must still return the caller's own primary
; diagnostic unchanged.
; ---------------------------------------------------------------------------
abortAfterCommitProtects:
    jsr fileIoInit
    ldx #<nameCommit2
    ldy #>nameCommit2
    jsr setOutputName
    ldx #<CasmOutputName
    ldy #>CasmOutputName
    jsr fileCreateOutput
    bcs aapFail
    jsr outputCommit
    bcs aapFail
    lda #CASM_DIAG_SYNTAX_ERROR    ; arbitrary nonzero stand-in primary
    jsr outputAbort
    bcc aapFail                    ; must still report failure (nonzero A)
    cmp #CASM_DIAG_SYNTAX_ERROR
    bne aapFail
    jmp probeFileExists            ; must still be openable: never deleted
aapFail:
    sec
    rts

; ---------------------------------------------------------------------------
; abortWithoutCommitDeletes
; Regression: an uncommitted output is unchanged by WP53 -- outputAbort still
; closes and deletes it, and a post-delete probe must fail.
; ---------------------------------------------------------------------------
abortWithoutCommitDeletes:
    jsr fileIoInit
    ldx #<nameNoCommit
    ldy #>nameNoCommit
    jsr setOutputName
    ldx #<CasmOutputName
    ldy #>CasmOutputName
    jsr fileCreateOutput
    bcs andFail
    lda #CASM_DIAG_NONE
    jsr outputAbort
    bcs andFail                    ; primary was NONE -- must report success
    jsr probeFileExists
    bcc andFail                    ; must be ABSENT now -- success is the bug
    clc
    rts
andFail:
    sec
    rts

; ---------------------------------------------------------------------------
; commitBadState
; outputCommit called with no output ever created (state CLOSED from
; fileIoInit) must reject with CASM_DIAG_STREAM_STATE_FAILED and must not
; set CasmOutputCommitted.
; ---------------------------------------------------------------------------
commitBadState:
    jsr fileIoInit
    jsr outputCommit
    bcs :+
    jmp cbsFail                    ; must fail -- success is the bug here
:
    cmp #CASM_DIAG_STREAM_STATE_FAILED
    bne cbsFail
    lda CasmOutputCommitted
    cmp #CASM_OUTPUT_NOT_COMMITTED
    bne cbsFail
    clc
    rts
cbsFail:
    sec
    rts

; ---------------------------------------------------------------------------
; doubleCommitFails
; Commit is one-way: a second outputCommit call after the first succeeded
; must reject (state is already CLOSED), and CasmOutputCommitted must remain
; committed from the first call rather than being disturbed by the second's
; failure.
; ---------------------------------------------------------------------------
doubleCommitFails:
    jsr fileIoInit
    ldx #<nameDouble
    ldy #>nameDouble
    jsr setOutputName
    ldx #<CasmOutputName
    ldy #>CasmOutputName
    jsr fileCreateOutput
    bcs dcfFail
    jsr outputCommit
    bcs dcfFail
    jsr outputCommit
    bcs :+
    jmp dcfFail                    ; second commit must fail -- success is
                                    ; the bug here
:
    cmp #CASM_DIAG_STREAM_STATE_FAILED
    bne dcfFail
    lda CasmOutputCommitted
    cmp #CASM_OUTPUT_COMMITTED
    bne dcfFail
    clc
    rts
dcfFail:
    sec
    rts

.segment "RODATA"

nameCommit1: .byte "SPCM01", 0
nameCommit2: .byte "SPCM02", 0
nameNoCommit: .byte "SPCM03", 0
nameDouble:  .byte "SPCM04", 0

passMsg: .byte "CASM SPANCOMMIT: PASS", $0D, 0
failMsg: .byte "CASM SPANCOMMIT: FAIL", $0D, 0

.segment "BSS"

FailCount:  .res 1
TestDevice: .res 1

CasmOutputName: .res CASM_FILENAME_BUFFER_SIZE
