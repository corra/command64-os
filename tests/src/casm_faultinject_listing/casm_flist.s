; tests/src/casm_faultinject_listing/casm_flist.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 11 WP59 Increment 2-5 listing fault-injection harness. Links listing.s
; whole with its real VMM/resource dependencies and local stand-ins for the
; source/file/include/diagnostics modules, matching casm_listing.s.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

; Opt-in counters in faultstub.inc prove serializer boundary ordering without
; growing the other fault-injection harnesses that share that include.
CASM_FAULT_BOUNDARY_COUNTERS = 1

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_flist.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import fileIoInit
.import listingStateInit
.import listingFileInit
.import listingCaptureInit
.import listingMetaAppend
.import listingReplayReset
.import listingReplayNext
.import listingBeginLine
.import listingMirrorByte
.import listingCommitLine
.import listingCaptureFinalize
.import listingCreate
.import listingWrite
.import listingClose
.import listingAbort
.import listingWriteFile
.import CasmListingState
.import CasmListingMetaVmmSlot
.import CasmListingByteVmmSlot
.import CasmListingRecordCountLo
.import CasmListingRecordCountHi
.import CasmListingByteCursorLo
.import CasmListingByteCursorHi
.import CasmListingByteFull
.import CasmListingStageLen
.import CasmListingTxnActive
.import CasmListingStage
.import CasmVmmCount
.import CasmVmmRegistry
.import CasmVmmBuffer
.import CasmFileCount
.import CasmOutputCommitted
.import CasmListFileHandle
.import CasmListFileSlot
.import CasmListFileState
.import CasmListFileOpened
.import CasmListFileValid
.import CasmListFileCommitted
.import CasmListFileDeletePending

; resources.s places the private file registry immediately before its exported
; VMM registry. Use that durable record-layout contract without exporting a new
; production symbol solely for fault injection.
CasmFileRegistry = CasmVmmRegistry - CASM_FILE_REGISTRY_BYTES

.export diagPrintFatal
.export sourceSetLineCapture
.export sourceTakeCompletedLine
.export CasmPc
.export CasmSourceCompletedFlags
.export CasmSourceCompletedStartLo
.export CasmSourceCompletedStartHi
.export CasmSourceCompletedLength
.export CasmSourceCompletedFileId
.export CasmSourceCompletedLineLo
.export CasmSourceCompletedLineHi
.export CasmListingName
.export CasmListingLen
.export CasmOutputName
.export CasmSourceCount
.export cliSourceSlotLo
.export cliSourceSlotHi
.export CasmIncludeCatalogCount
.export CasmIncludeRecordStage
.export includeCatalogRead
.export includeDeviceStrLo
.export includeDeviceStrHi
.export sourceReadSpanChunk
.export CasmSourceState

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    jsr resourcesInit
    lda #0
    sta FailCount

    jsr vectorRestorePassThrough
    jsr reportCase
    jsr stateInitContract
    jsr reportCase
    jsr fileInitContract
    jsr reportCase
    jsr disabledBeginNoOp
    jsr reportCase
    jsr disabledMirrorNoOp
    jsr reportCase
    jsr disabledCommitNoOp
    jsr reportCase
    jsr duplicateBeginRejected
    jsr reportCase
    jsr commitWithoutTxnRejected
    jsr reportCase
    jsr captureInitWrongState
    jsr reportCase
    jsr replayResetWrongState
    jsr reportCase
    jsr captureFinalizeWrongState
    jsr reportCase
    jsr createWrongState
    jsr reportCase
    jsr writeWrongState
    jsr reportCase
    jsr closeWrongState
    jsr reportCase
    jsr writeFileWrongState
    jsr reportCase

    jsr allocUnavailable
    jsr reportCase
    jsr allocNoMem
    jsr reportCase
    jsr secondAllocNoMem
    jsr reportCase
    jsr metaWriteFailure
    jsr reportCase
    jsr mirrorFlushFailure
    jsr reportCase
    jsr finalizeWriteFailure
    jsr reportCase
    jsr replayReadFailure
    jsr reportCase
    jsr serializerMirrorReadFailure
    jsr reportCase
    jsr serializerMetaReadFailure
    jsr reportCase
    jsr serializerIncludeReadFailure
    jsr reportCase
    jsr serializerSourceReadFailure
    jsr reportCase
    jsr serializerWriteFailure
    jsr reportCase
    jsr serializerShortWrite
    jsr reportCase
    jsr serializerCloseFailure
    jsr reportCase
    jsr serializerAbortCloseFailure
    jsr reportCase
    jsr serializerAbortDeleteFailure
    jsr reportCase
    jsr createFailureNoOwnership
    jsr reportCase
    jsr registrationFailureCompensated
    jsr reportCase
    jsr writeFailureInvalidates
    jsr reportCase
    jsr shortWriteInvalidates
    jsr reportCase
    jsr registeredCloseRetry
    jsr reportCase
    jsr unregisteredCloseRetry
    jsr reportCase
    jsr deleteFailureRetry
    jsr reportCase
    jsr abortPreservesPrimary
    jsr reportCase
    jsr abortReturnsCloseFailure
    jsr reportCase
    jsr committedNeverDeleted
    jsr reportCase

    lda #PetCr
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
    jsr faultUninstall
    lda #DOS_PRINT_STR
    jsr OS_API
    jsr faultUninstall
    lda #DOS_EXIT
    jsr OS_API

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

; Capture the live vector independently, install/uninstall twice, then make a
; real OS_API call through the restored entry point.
vectorRestorePassThrough:
    lda $1001
    sta ExpectedVector
    lda $1002
    sta ExpectedVector+1
    jsr faultInstall
    lda $1001
    cmp #<faultStubEntry
    bne vrFail
    lda $1002
    cmp #>faultStubEntry
    bne vrFail
    jsr faultUninstall
    jsr faultUninstall
    lda $1001
    cmp ExpectedVector
    bne vrFail
    lda $1002
    cmp ExpectedVector+1
    bne vrFail
    ldx #<emptyMsg
    ldy #>emptyMsg
    lda #DOS_PRINT_STR
    jsr OS_API
    bcs vrFail
    clc
    rts
vrFail:
    jsr faultUninstall
    sec
    rts

poisonCaptureState:
    lda #$A5
    sta CasmListingState
    sta CasmListingRecordCountLo
    sta CasmListingRecordCountHi
    sta CasmListingByteCursorLo
    sta CasmListingByteCursorHi
    sta CasmListingByteFull
    sta CasmListingStageLen
    sta CasmListingTxnActive
    rts

checkCaptureZero:
    lda CasmListingState
    ora CasmListingRecordCountLo
    ora CasmListingRecordCountHi
    ora CasmListingByteCursorLo
    ora CasmListingByteCursorHi
    ora CasmListingByteFull
    ora CasmListingStageLen
    ora CasmListingTxnActive
    rts

stateInitContract:
    jsr poisonCaptureState
    tsx
    stx SavedSp
    ldx #$35
    ldy #$CA
    jsr listingStateInit
    bcs sicFail
    cmp #CASM_DIAG_NONE
    bne sicFail
    cpx #$35
    bne sicFail
    cpy #$CA
    bne sicFail
    tsx
    cpx SavedSp
    bne sicFail
    jsr checkCaptureZero
    bne sicFail
    jsr poisonCaptureState
    tsx
    stx SavedSp
    ldx #$35
    ldy #$CA
    jsr listingStateInit
    bcs sicFail
    cmp #CASM_DIAG_NONE
    bne sicFail
    cpx #$35
    bne sicFail
    cpy #$CA
    bne sicFail
    tsx
    cpx SavedSp
    bne sicFail
    jsr checkCaptureZero
    bne sicFail
    clc
    rts
sicFail:
    sec
    rts

poisonFileState:
    lda #$A5
    sta CasmListFileHandle
    sta CasmListFileSlot
    sta CasmListFileState
    sta CasmListFileOpened
    sta CasmListFileValid
    sta CasmListFileCommitted
    sta CasmListFileDeletePending
    rts

checkFileInit:
    lda CasmListFileHandle
    cmp #CASM_INVALID_HANDLE
    bne cfiBad
    lda CasmListFileSlot
    cmp #CASM_INVALID_SLOT
    bne cfiBad
    lda CasmListFileState
    cmp #CASM_FILE_STATE_CLOSED
    bne cfiBad
    lda CasmListFileOpened
    ora CasmListFileValid
    ora CasmListFileCommitted
    ora CasmListFileDeletePending
    rts
cfiBad:
    lda #1
    rts

fileInitContract:
    jsr poisonFileState
    tsx
    stx SavedSp
    ldx #$35
    ldy #$CA
    jsr listingFileInit
    bcs ficFail
    bne ficFail
    cpx #$35
    bne ficFail
    cpy #$CA
    bne ficFail
    tsx
    cpx SavedSp
    bne ficFail
    jsr checkFileInit
    bne ficFail
    jsr poisonFileState
    tsx
    stx SavedSp
    ldx #$35
    ldy #$CA
    jsr listingFileInit
    bcs ficFail
    bne ficFail
    cpx #$35
    bne ficFail
    cpy #$CA
    bne ficFail
    tsx
    cpx SavedSp
    bne ficFail
    jsr checkFileInit
    bne ficFail
    clc
    rts
ficFail:
    sec
    rts

disabledBeginNoOp:
    jsr listingStateInit
    lda #$A5
    sta CasmListingTxnActive
    tsx
    stx SavedSp
    jsr listingBeginLine
    bcs dbnFail
    tsx
    cpx SavedSp
    bne dbnFail
    lda CasmListingTxnActive
    cmp #$A5
    bne dbnFail
    clc
    rts
dbnFail:
    sec
    rts

disabledMirrorNoOp:
    jsr listingStateInit
    lda #$A5
    sta CasmListingByteCursorLo
    sta CasmListingStageLen
    tsx
    stx SavedSp
    lda #$77
    jsr listingMirrorByte
    bcs dmnFail
    tsx
    cpx SavedSp
    bne dmnFail
    lda CasmListingByteCursorLo
    cmp #$A5
    bne dmnFail
    lda CasmListingStageLen
    cmp #$A5
    bne dmnFail
    clc
    rts
dmnFail:
    sec
    rts

disabledCommitNoOp:
    jsr listingStateInit
    lda #$A5
    sta CasmListingTxnActive
    sta CasmListingRecordCountLo
    tsx
    stx SavedSp
    jsr listingCommitLine
    bcs dcnFail
    tsx
    cpx SavedSp
    bne dcnFail
    lda CasmListingTxnActive
    cmp #$A5
    bne dcnFail
    lda CasmListingRecordCountLo
    cmp #$A5
    bne dcnFail
    clc
    rts
dcnFail:
    sec
    rts

duplicateBeginRejected:
    jsr listingStateInit
    lda #CASM_LISTING_STATE_ENABLED
    sta CasmListingState
    jsr listingBeginLine
    bcs dbrFail
    tsx
    stx SavedSp
    jsr listingBeginLine
    bcc dbrFail
    cmp #CASM_DIAG_LISTING_REPLAY_MISMATCH
    bne dbrFail
    tsx
    cpx SavedSp
    bne dbrFail
    clc
    rts
dbrFail:
    sec
    rts

commitWithoutTxnRejected:
    jsr listingStateInit
    lda #CASM_LISTING_STATE_ENABLED
    sta CasmListingState
    tsx
    stx SavedSp
    jsr listingCommitLine
    bcc cwtrFail
    cmp #CASM_DIAG_LISTING_REPLAY_MISMATCH
    bne cwtrFail
    tsx
    cpx SavedSp
    bne cwtrFail
    clc
    rts
cwtrFail:
    sec
    rts

; Each wrong-state case checks the exact diagnostic and stack balance.
captureInitWrongState:
    lda #CASM_LISTING_STATE_ENABLED
    sta CasmListingState
    tsx
    stx SavedSp
    jsr listingCaptureInit
    jmp checkStateFailure

replayResetWrongState:
    lda #CASM_LISTING_STATE_NONE
    sta CasmListingState
    tsx
    stx SavedSp
    jsr listingReplayReset
    jmp checkStateFailure

captureFinalizeWrongState:
    lda #CASM_LISTING_STATE_NONE
    sta CasmListingState
    tsx
    stx SavedSp
    jsr listingCaptureFinalize
    jmp checkStateFailure

createWrongState:
    lda #CASM_FILE_STATE_OPEN
    sta CasmListFileState
    tsx
    stx SavedSp
    jsr listingCreate
    jmp checkStateFailure

writeWrongState:
    lda #CASM_FILE_STATE_CLOSED
    sta CasmListFileState
    tsx
    stx SavedSp
    jsr listingWrite
    jmp checkStateFailure

closeWrongState:
    lda #CASM_FILE_STATE_CLOSED
    sta CasmListFileState
    tsx
    stx SavedSp
    jsr listingClose
    jmp checkStateFailure

writeFileWrongState:
    lda #CASM_LISTING_STATE_NONE
    sta CasmListingState
    tsx
    stx SavedSp
    jsr listingWriteFile

checkStateFailure:
    bcc csfFail
    cmp #CASM_DIAG_STREAM_STATE_FAILED
    bne csfFail
    tsx
    cpx SavedSp
    bne csfFail
    clc
    rts
csfFail:
    sec
    rts

resetOwnedState:
    jsr resourcesCleanup
    bcs rosFail
    jsr resourcesInit
    jsr listingStateInit
    jsr listingFileInit
    jsr fileIoInit
    clc
rosFail:
    rts

armFault:
    sta FaultFuncCode
    stx FaultCountdown
    sty FaultReturnA
    lda #0
    sta FaultReturnSuccess
    sta FaultSetCount
    lda #1
    sta FaultArmed
    rts

checkSpDiag:
    bcc csdFail
    cmp ExpectedDiag
    bne csdFail
    tsx
    inx
    inx
    cpx SavedSp
    bne csdFail
    clc
    rts
csdFail:
    sec
    rts

allocUnavailable:
    jsr resetOwnedState
    bcs auFail
    jsr faultInstall
    lda #DOS_ALLOC_MEM
    ldx #1
    ldy #VMM_ERR_INVALID
    jsr armFault
    tsx
    stx SavedSp
    lda #CASM_DIAG_VMM_UNAVAILABLE
    sta ExpectedDiag
    jsr listingCaptureInit
    jsr checkSpDiag
    bcs auFail
    lda CasmListingState
    ora CasmVmmCount
    bne auFail
    jsr faultUninstall
    clc
    rts
auFail:
    jsr faultUninstall
    sec
    rts

allocNoMem:
    jsr resetOwnedState
    bcs anFail
    jsr faultInstall
    lda #DOS_ALLOC_MEM
    ldx #1
    ldy #VMM_ERR_NOMEM
    jsr armFault
    tsx
    stx SavedSp
    lda #CASM_DIAG_VMM_ALLOC_FAILED
    sta ExpectedDiag
    jsr listingCaptureInit
    jsr checkSpDiag
    bcs anFail
    lda CasmListingState
    ora CasmVmmCount
    bne anFail
    jsr faultUninstall
    clc
    rts
anFail:
    jsr faultUninstall
    sec
    rts

secondAllocNoMem:
    jsr resetOwnedState
    bcs sanFail
    jsr faultInstall
    lda #DOS_ALLOC_MEM
    ldx #2
    ldy #VMM_ERR_NOMEM
    jsr armFault
    tsx
    stx SavedSp
    lda #CASM_DIAG_VMM_ALLOC_FAILED
    sta ExpectedDiag
    jsr listingCaptureInit
    jsr checkSpDiag
    bcs sanFail
    lda CasmListingState
    bne sanFail
    lda CasmVmmCount
    cmp #1
    bne sanFail
    lda CasmVmmRegistry + CASM_VMM_REC_FLAG
    cmp #CASM_RESOURCE_OWNED
    bne sanFail
    jsr faultUninstall
    jsr resourcesCleanup
    bcs sanFail
    lda CasmVmmCount
    bne sanFail
    clc
    rts
sanFail:
    jsr faultUninstall
    sec
    rts

initCapture:
    jsr resetOwnedState
    bcs icRet
    jsr listingCaptureInit
icRet:
    rts

metaWriteFailure:
    jsr initCapture
    bcs mwfFail
    jsr faultInstall
    lda #DOS_VMM_WRITE
    ldx #1
    ldy #0
    jsr armFault
    tsx
    stx SavedSp
    lda #CASM_DIAG_VMM_TRANSFER_FAILED
    sta ExpectedDiag
    jsr listingMetaAppend
    jsr checkSpDiag
    bcs mwfFail
    lda CasmListingRecordCountLo
    ora CasmListingRecordCountHi
    bne mwfFail
    jsr faultUninstall
    clc
    rts
mwfFail:
    jsr faultUninstall
    sec
    rts

mirrorFlushFailure:
    jsr initCapture
    bcs mffFail
    jsr listingBeginLine
    bcs mffFail
    ldx #63
mffFill:
    txa
    jsr listingMirrorByte
    bcs mffFail
    dex
    bne mffFill
    jsr faultInstall
    lda #DOS_VMM_WRITE
    ldx #1
    ldy #0
    jsr armFault
    tsx
    stx SavedSp
    lda #CASM_DIAG_VMM_TRANSFER_FAILED
    sta ExpectedDiag
    lda #$3F
    jsr listingMirrorByte
    jsr checkSpDiag
    bcs mffFail
    lda CasmListingByteCursorLo
    cmp #64
    bne mffFail
    lda CasmListingByteCursorHi
    bne mffFail
    lda CasmListingStageLen
    cmp #64
    bne mffFail
    lda CasmListingTxnActive
    cmp #1
    bne mffFail
    lda #0
    sta FaultArmed
    jsr listingCommitLine
    bcs mffFail
    jsr listingCaptureFinalize
    bcs mffFail
    lda CasmListingState
    cmp #CASM_LISTING_STATE_COMPLETE
    bne mffFail
    lda CasmListingStageLen
    bne mffFail
    jsr faultUninstall
    clc
    rts
mffFail:
    jsr faultUninstall
    sec
    rts

finalizeWriteFailure:
    jsr initCapture
    bcs fwfFail
    jsr listingBeginLine
    lda #$A5
    jsr listingMirrorByte
    bcs fwfFail
    jsr listingCommitLine
    bcs fwfFail
    jsr faultInstall
    lda #DOS_VMM_WRITE
    ldx #1
    ldy #0
    jsr armFault
    tsx
    stx SavedSp
    lda #CASM_DIAG_VMM_TRANSFER_FAILED
    sta ExpectedDiag
    jsr listingCaptureFinalize
    jsr checkSpDiag
    bcs fwfFail
    lda CasmListingState
    cmp #CASM_LISTING_STATE_ENABLED
    bne fwfFail
    lda CasmListingStageLen
    cmp #1
    bne fwfFail
    lda #0
    sta FaultArmed
    jsr listingCaptureFinalize
    bcs fwfFail
    cmp #CASM_DIAG_NONE
    bne fwfFail
    lda CasmListingState
    cmp #CASM_LISTING_STATE_COMPLETE
    bne fwfFail
    lda CasmListingStageLen
    bne fwfFail
    jsr faultUninstall
    clc
    rts
fwfFail:
    jsr faultUninstall
    sec
    rts

makeMinimalCapture:
    jsr initCapture
    bcs mmcRet
    lda #CASM_SOURCE_COMPLETED_FLAG_VALID
    sta CasmSourceCompletedFlags
    lda #1
    sta CasmSourceCompletedLength
    sta CasmSourceCompletedLineLo
    lda #0
    sta CasmSourceCompletedFileId
    sta CasmSourceCompletedStartLo
    sta CasmSourceCompletedStartHi
    sta CasmSourceCompletedLineHi
    jsr listingBeginLine
    bcs mmcRet
    lda #$A9
    jsr listingMirrorByte
    bcs mmcRet
    jsr listingCommitLine
    bcs mmcRet
    jsr listingCaptureFinalize
mmcRet:
    rts

resetBoundaryCounters:
    lda #0
    sta FaultOpenCalls
    sta FaultWriteCalls
    sta FaultCloseCalls
    sta FaultDeleteCalls
    sta FaultVmmReadCalls
    sta IncludeReadCalls
    sta SourceSpanCalls
    sta IncludeReadFail
    sta SourceSpanFail
    rts

; Configure the include stand-in defaults used by every serializer case.
resetIncludeStandin:
    lda #CASM_DEVICE_MIN
    sta IncludeDevice
    lda #<includeNameI
    sta IncludeNameLo
    lda #>includeNameI
    sta IncludeNameHi
    lda #0
    rts

; Build one valid physical-line record, then install the requested unique
; listing name and serializer preconditions. TestFileId/TestSourceLen select
; the validation and formatting boundary reached by each case.
prepareSerializer:
    jsr initCapture
    bcs psRet
    lda #CASM_SOURCE_COMPLETED_FLAG_VALID
    sta CasmSourceCompletedFlags
    lda TestSourceLen
    sta CasmSourceCompletedLength
    lda #1
    sta CasmSourceCompletedLineLo
    lda TestFileId
    sta CasmSourceCompletedFileId
    lda #0
    sta CasmSourceCompletedStartLo
    sta CasmSourceCompletedStartHi
    sta CasmSourceCompletedLineHi
    jsr listingBeginLine
    bcs psRet
    lda #$A9
    jsr listingMirrorByte
    bcs psRet
    jsr listingCommitLine
    bcs psRet
    jsr listingCaptureFinalize
    bcs psRet
    ldy #0
psCopyName:
    lda TestNameLo
    sta CasmValue1Lo
    lda TestNameHi
    sta CasmValue1Hi
psCopyNameLoop:
    lda (CasmValue1Lo), y
    sta CasmListingName, y
    beq psNameDone
    iny
    bne psCopyNameLoop
psNameDone:
    sty CasmListingLen
    lda #1
    sta CasmSourceCount
    lda #<serializerSourceName
    sta cliSourceSlotLo
    lda #>serializerSourceName
    sta cliSourceSlotHi
    lda #1
    sta CasmIncludeCatalogCount
    lda #CASM_SOURCE_STATE_CLOSED
    sta CasmSourceState
    lda #CASM_OUTPUT_COMMITTED
    sta CasmOutputCommitted
    jsr resetBoundaryCounters
    jsr resetIncludeStandin
    clc
psRet:
    rts

; All fatal serializer cases retain the already-committed PRG contract.
checkOutputSafe:
    lda CasmOutputCommitted
    cmp #CASM_OUTPUT_COMMITTED
    rts

retrySerializerCleanup:
    jsr faultUninstall
    lda #0
    sta IncludeReadFail
    sta SourceSpanFail
    tsx
    stx SavedSp
    lda ExpectedDiag
    jsr listingAbort
    bcc rscFail
    cmp ExpectedDiag
    bne rscFail
    tsx
    cpx SavedSp
    bne rscFail
    jsr checkNoListOwnership
    bne rscFail
    jsr checkOutputSafe
    bne rscFail
    clc
    rts
rscFail:
    sec
    rts

replayReadFailure:
    jsr makeMinimalCapture
    bcs rrfFail
    jsr listingReplayReset
    bcs rrfFail
    jsr faultInstall
    lda #DOS_VMM_READ
    ldx #1
    ldy #0
    jsr armFault
    tsx
    stx SavedSp
    lda #CASM_DIAG_VMM_TRANSFER_FAILED
    sta ExpectedDiag
    jsr listingReplayNext
    jsr checkSpDiag
    bcs rrfFail
    lda #0
    sta FaultArmed
    jsr listingReplayNext
    bcs rrfFail
    cmp #CASM_STREAM_DATA
    bne rrfFail
    jsr faultUninstall
    clc
    rts
rrfFail:
    jsr faultUninstall
    sec
    rts

; Reused from Increment 4 because it already traverses listingWriteFile; the
; Increment 5 assertions below add exact boundary ordering and artifact safety.
serializerMirrorReadFailure:
    jsr makeMinimalCapture
    bcc smrfCaptureOk
    jmp smrfFail
smrfCaptureOk:
    ldx #0
smrfCopyName:
    lda serializerListingName, x
    sta CasmListingName, x
    beq smrfNameDone
    inx
    bne smrfCopyName
smrfNameDone:
    stx CasmListingLen
    lda #1
    sta CasmSourceCount
    lda #<serializerSourceName
    sta cliSourceSlotLo
    lda #>serializerSourceName
    sta cliSourceSlotHi
    lda #CASM_SOURCE_STATE_CLOSED
    sta CasmSourceState
    lda #CASM_OUTPUT_COMMITTED
    sta CasmOutputCommitted
    jsr faultInstall
    jsr resetBoundaryCounters
    lda #DOS_VMM_READ
    ldx #2
    ldy #0
    jsr armFault
    tsx
    stx SavedSp
    lda #CASM_DIAG_VMM_TRANSFER_FAILED
    sta ExpectedDiag
    jsr listingWriteFile
    jsr checkSpDiag
    bcs smrfFail
    lda CasmListFileOpened
    ora CasmListFileDeletePending
    ora CasmFileCount
    bne smrfFail
    lda CasmListFileState
    cmp #CASM_FILE_STATE_CLOSED
    bne smrfFail
    lda FaultOpenCalls
    cmp #1
    bne smrfFail
    lda FaultVmmReadCalls
    cmp #2
    bne smrfFail
    lda FaultWriteCalls
    ora SourceSpanCalls
    ora IncludeReadCalls
    bne smrfFail
    lda FaultCloseCalls
    cmp #1
    bne smrfFail
    lda FaultDeleteCalls
    cmp #1
    bne smrfFail
    jsr checkOutputSafe
    bne smrfFail
    jsr faultUninstall
    clc
    rts
smrfFail:
    jsr faultUninstall
    sec
    rts

serializerMetaReadFailure:
    lda #0
    sta TestFileId
    sta TestSourceLen
    lda #<serializerMetaName
    sta TestNameLo
    lda #>serializerMetaName
    sta TestNameHi
    jsr prepareSerializer
    bcs smerFail
    jsr faultInstall
    jsr resetBoundaryCounters
    lda #DOS_VMM_READ
    ldx #1
    ldy #0
    jsr armFault
    tsx
    stx SavedSp
    jsr listingWriteFile
    bcc smerFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne smerFail
    tsx
    cpx SavedSp
    bne smerFail
    lda FaultVmmReadCalls
    cmp #1
    bne smerFail
    lda FaultWriteCalls
    ora SourceSpanCalls
    ora IncludeReadCalls
    bne smerFail
    lda FaultCloseCalls
    cmp #1
    bne smerFail
    lda FaultDeleteCalls
    cmp #1
    bne smerFail
    jsr checkNoListOwnership
    bne smerFail
    jsr checkOutputSafe
    bne smerFail
    jsr faultUninstall
    clc
    rts
smerFail:
    jsr faultUninstall
    sec
    rts

serializerIncludeReadFailure:
    lda #CASM_DIAG_FILEID_FRAME_FLAG
    sta TestFileId
    lda #1
    sta TestSourceLen
    lda #<serializerIncludeName
    sta TestNameLo
    lda #>serializerIncludeName
    sta TestNameHi
    jsr prepareSerializer
    bcs sirfFail
    jsr faultInstall
    jsr resetBoundaryCounters
    lda #1
    sta IncludeReadFail
    tsx
    stx SavedSp
    jsr listingWriteFile
    bcc sirfFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne sirfFail
    tsx
    cpx SavedSp
    bne sirfFail
    lda IncludeReadCalls
    cmp #1
    bne sirfFail
    lda SourceSpanCalls
    ora FaultWriteCalls
    bne sirfFail
    lda FaultCloseCalls
    cmp #1
    bne sirfFail
    lda FaultDeleteCalls
    cmp #1
    bne sirfFail
    jsr checkNoListOwnership
    bne sirfFail
    jsr checkOutputSafe
    bne sirfFail
    jsr faultUninstall
    clc
    rts
sirfFail:
    jsr faultUninstall
    sec
    rts

serializerSourceReadFailure:
    lda #0
    sta TestFileId
    lda #1
    sta TestSourceLen
    lda #<serializerSourceFailName
    sta TestNameLo
    lda #>serializerSourceFailName
    sta TestNameHi
    jsr prepareSerializer
    bcs ssrfFail
    jsr faultInstall
    jsr resetBoundaryCounters
    lda #1
    sta SourceSpanFail
    tsx
    stx SavedSp
    jsr listingWriteFile
    bcc ssrfFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne ssrfFail
    tsx
    cpx SavedSp
    bne ssrfFail
    lda SourceSpanCalls
    cmp #1
    bne ssrfFail
    lda FaultWriteCalls
    ora IncludeReadCalls
    bne ssrfFail
    lda FaultCloseCalls
    cmp #1
    bne ssrfFail
    lda FaultDeleteCalls
    cmp #1
    bne ssrfFail
    jsr checkNoListOwnership
    bne ssrfFail
    jsr checkOutputSafe
    bne ssrfFail
    jsr faultUninstall
    clc
    rts
ssrfFail:
    jsr faultUninstall
    sec
    rts

; A normal minimal row reaches exactly one final aggregate write.
serializerWriteFailure:
    lda #<serializerWriteName
    ldy #>serializerWriteName
    ldx #CASM_DIAG_LISTING_WRITE_FAILED
    jmp serializerAggregateFailure

serializerShortWrite:
    lda #<serializerShortName
    ldy #>serializerShortName
    ldx #CASM_DIAG_LISTING_SHORT_WRITE

serializerAggregateFailure:
    sta TestNameLo
    sty TestNameHi
    stx ExpectedDiag
    lda #0
    sta TestFileId
    lda #1
    sta TestSourceLen
    jsr prepareSerializer
    bcs safFail
    jsr faultInstall
    jsr resetBoundaryCounters
    lda #DOS_WRITE_FILE
    ldx #1
    ldy #0
    jsr armFault
    lda ExpectedDiag
    cmp #CASM_DIAG_LISTING_SHORT_WRITE
    bne safArmed
    lda #1
    sta FaultReturnSuccess
    sta FaultSetCount
    lda #0
    sta FaultReturnCountLo
    sta FaultReturnCountHi
safArmed:
    tsx
    stx SavedSp
    jsr listingWriteFile
    bcc safFail
    cmp ExpectedDiag
    bne safFail
    tsx
    cpx SavedSp
    bne safFail
    lda SourceSpanCalls
    cmp #1
    bne safFail
    lda FaultWriteCalls
    cmp #1
    bne safFail
    lda FaultCloseCalls
    cmp #1
    bne safFail
    lda FaultDeleteCalls
    cmp #1
    bne safFail
    jsr checkNoListOwnership
    bne safFail
    jsr checkOutputSafe
    bne safFail
    jsr faultUninstall
    clc
    rts
safFail:
    jsr faultUninstall
    sec
    rts

serializerCloseFailure:
    lda #0
    sta TestFileId
    lda #1
    sta TestSourceLen
    lda #<serializerCloseName
    sta TestNameLo
    lda #>serializerCloseName
    sta TestNameHi
    jsr prepareSerializer
    bcs scfFail
    jsr faultInstall
    jsr resetBoundaryCounters
    lda #DOS_CLOSE_FILE
    ldx #1
    ldy #0
    jsr armFault
    tsx
    stx SavedSp
    jsr listingWriteFile
    bcc scfFail
    cmp #CASM_DIAG_LISTING_CLOSE_FAILED
    bne scfFail
    tsx
    cpx SavedSp
    bne scfFail
    lda FaultWriteCalls
    cmp #1
    bne scfFail
    lda FaultCloseCalls
    cmp #2
    bne scfFail
    lda FaultDeleteCalls
    cmp #1
    bne scfFail
    jsr checkNoListOwnership
    bne scfFail
    lda #CASM_DIAG_LISTING_CLOSE_FAILED
    sta ExpectedDiag
    jsr retrySerializerCleanup
    bcs scfFail
    clc
    rts
scfFail:
    jsr faultUninstall
    sec
    rts

serializerAbortCloseFailure:
    lda #<serializerAbortCloseName
    sta TestNameLo
    lda #>serializerAbortCloseName
    sta TestNameHi
    jsr prepareAbortSerializer
    bcs sacfFail
    jsr faultInstall
    jsr resetBoundaryCounters
    lda #1
    sta SourceSpanFail
    lda #DOS_CLOSE_FILE
    ldx #1
    ldy #0
    jsr armFault
    jsr callAbortSerializer
    bcs sacfFail
    lda FaultCloseCalls
    cmp #1
    bne sacfFail
    lda FaultDeleteCalls
    bne sacfFail
    lda CasmFileCount
    cmp #1
    bne sacfFail
    lda CasmListFileState
    cmp #CASM_FILE_STATE_CLOSE_FAILED
    bne sacfFail
    jsr retrySerializerCleanup
    bcs sacfFail
    clc
    rts
sacfFail:
    jsr faultUninstall
    sec
    rts

serializerAbortDeleteFailure:
    lda #<serializerAbortDeleteName
    sta TestNameLo
    lda #>serializerAbortDeleteName
    sta TestNameHi
    jsr prepareAbortSerializer
    bcs sadfFail
    jsr faultInstall
    jsr resetBoundaryCounters
    lda #1
    sta SourceSpanFail
    lda #DOS_DELETE_FILE
    ldx #1
    ldy #0
    jsr armFault
    jsr callAbortSerializer
    bcs sadfFail
    lda FaultCloseCalls
    cmp #1
    bne sadfFail
    lda FaultDeleteCalls
    cmp #1
    bne sadfFail
    lda CasmListFileDeletePending
    beq sadfFail
    lda CasmFileCount
    bne sadfFail
    lda CasmListFileOpened
    beq sadfFail
    jsr retrySerializerCleanup
    bcs sadfFail
    clc
    rts
sadfFail:
    jsr faultUninstall
    sec
    rts

prepareAbortSerializer:
    lda #0
    sta TestFileId
    lda #1
    sta TestSourceLen
    jsr prepareSerializer
    bcs pasRet
    lda #CASM_DIAG_VMM_TRANSFER_FAILED
    sta ExpectedDiag
    clc
pasRet:
    rts

; Return C clear only when the serializer preserved the source-read primary,
; balanced SP, and stopped serializer work before any aggregate write.
callAbortSerializer:
    tsx
    stx SavedSp
    jsr listingWriteFile
    bcc casBad
    cmp ExpectedDiag
    bne casBad
    tsx
    cpx SavedSp
    bne casBad
    lda SourceSpanCalls
    cmp #1
    bne casBad
    lda FaultWriteCalls
    ora IncludeReadCalls
    bne casBad
    jsr checkOutputSafe
    bne casBad
    clc
    rts
casBad:
    sec
    rts

; X/Y selects a unique null-terminated test filename.
prepareListingFile:
    txa
    pha
    tya
    pha
    jsr resetOwnedState
    bcs plfDropPointer
    pla
    sta CasmValue1Hi
    pla
    sta CasmValue1Lo
    ldy #0
plfCopy:
    lda (CasmValue1Lo), y
    sta CasmListingName, y
    beq plfDone
    iny
    bne plfCopy
plfDone:
    sty CasmListingLen
    lda #CASM_OUTPUT_COMMITTED
    sta CasmOutputCommitted
    lda #CASM_SOURCE_STATE_CLOSED
    sta CasmSourceState
    clc
plfRet:
    rts
plfDropPointer:
    pla
    pla
    sec
    rts

checkNoListOwnership:
    lda CasmFileCount
    bne cnloBad
    lda CasmListFileHandle
    cmp #CASM_INVALID_HANDLE
    bne cnloBad
    lda CasmListFileSlot
    cmp #CASM_INVALID_SLOT
    bne cnloBad
    lda CasmListFileState
    cmp #CASM_FILE_STATE_CLOSED
    bne cnloBad
    lda CasmListFileOpened
    ora CasmListFileDeletePending
    rts
cnloBad:
    lda #1
    rts

fillFakeRegistry:
    ldx #0
ffrLoop:
    lda #CASM_RESOURCE_OWNED
    sta CasmFileRegistry + CASM_FILE_REC_FLAG, x
    lda #CASM_INVALID_HANDLE
    sta CasmFileRegistry + CASM_FILE_REC_HANDLE, x
    inx
    inx
    cpx #CASM_FILE_REGISTRY_BYTES
    bcc ffrLoop
    rts

clearFakeRegistry:
    ldx #0
cfrLoop:
    lda #CASM_RESOURCE_FREE
    sta CasmFileRegistry + CASM_FILE_REC_FLAG, x
    lda #CASM_INVALID_HANDLE
    sta CasmFileRegistry + CASM_FILE_REC_HANDLE, x
    inx
    inx
    cpx #CASM_FILE_REGISTRY_BYTES
    bcc cfrLoop
    rts

createFailureNoOwnership:
    ldx #<createFailName
    ldy #>createFailName
    jsr prepareListingFile
    bcs cfnoFail
    jsr faultInstall
    lda #DOS_OPEN_FILE
    ldx #1
    ldy #0
    jsr armFault
    tsx
    stx SavedSp
    jsr listingCreate
    bcc cfnoFail
    cmp #CASM_DIAG_LISTING_CREATE_FAILED
    bne cfnoFail
    tsx
    cpx SavedSp
    bne cfnoFail
    jsr checkNoListOwnership
    bne cfnoFail
    jsr faultUninstall
    clc
    rts
cfnoFail:
    jsr faultUninstall
    sec
    rts

registrationFailureCompensated:
    ldx #<registerFailName
    ldy #>registerFailName
    jsr prepareListingFile
    bcs rfcFail
    jsr fillFakeRegistry
    tsx
    stx SavedSp
    jsr listingCreate
    php
    pha
    jsr clearFakeRegistry
    pla
    plp
    bcc rfcFail
    cmp #CASM_DIAG_LISTING_CREATE_FAILED
    bne rfcFail
    tsx
    cpx SavedSp
    bne rfcFail
    jsr checkNoListOwnership
    bne rfcFail
    clc
    rts
rfcFail:
    jsr clearFakeRegistry
    sec
    rts

writeFailureInvalidates:
    ldx #<writeFailName
    ldy #>writeFailName
    jsr prepareListingFile
    bcs wfiFail
    jsr listingCreate
    bcs wfiFail
    jsr faultInstall
    lda #DOS_WRITE_FILE
    ldx #1
    ldy #0
    jsr armFault
    lda #1
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx #<writeByte
    ldy #>writeByte
    tsx
    stx SavedSp
    jsr listingWrite
    bcc wfiFail
    cmp #CASM_DIAG_LISTING_WRITE_FAILED
    bne wfiFail
    tsx
    cpx SavedSp
    bne wfiFail
    lda CasmListFileValid
    bne wfiFail
    jsr faultUninstall
    lda #CASM_DIAG_LISTING_WRITE_FAILED
    jsr listingAbort
    bcc wfiFail
    jsr checkNoListOwnership
    bne wfiFail
    clc
    rts
wfiFail:
    jsr faultUninstall
    sec
    rts

shortWriteInvalidates:
    ldx #<shortWriteName
    ldy #>shortWriteName
    jsr prepareListingFile
    bcs swiFail
    jsr listingCreate
    bcs swiFail
    jsr faultInstall
    lda #DOS_WRITE_FILE
    ldx #1
    ldy #0
    jsr armFault
    lda #1
    sta FaultReturnSuccess
    sta FaultSetCount
    lda #0
    sta FaultReturnCountLo
    sta FaultReturnCountHi
    lda #1
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx #<writeByte
    ldy #>writeByte
    tsx
    stx SavedSp
    jsr listingWrite
    bcc swiFail
    cmp #CASM_DIAG_LISTING_SHORT_WRITE
    bne swiFail
    tsx
    cpx SavedSp
    bne swiFail
    lda CasmListFileValid
    bne swiFail
    jsr faultUninstall
    lda #CASM_DIAG_LISTING_SHORT_WRITE
    jsr listingAbort
    bcc swiFail
    jsr checkNoListOwnership
    bne swiFail
    clc
    rts
swiFail:
    jsr faultUninstall
    sec
    rts

registeredCloseRetry:
    ldx #<closeRetryName
    ldy #>closeRetryName
    jsr prepareListingFile
    bcs rcrFail
    jsr listingCreate
    bcs rcrFail
    jsr faultInstall
    lda #DOS_CLOSE_FILE
    ldx #1
    ldy #0
    jsr armFault
    tsx
    stx SavedSp
    jsr listingClose
    bcc rcrFail
    cmp #CASM_DIAG_LISTING_CLOSE_FAILED
    bne rcrFail
    tsx
    cpx SavedSp
    bne rcrFail
    lda CasmListFileState
    cmp #CASM_FILE_STATE_CLOSE_FAILED
    bne rcrFail
    lda CasmListFileOpened
    beq rcrFail
    lda CasmFileCount
    cmp #1
    bne rcrFail
    jsr faultUninstall
    jsr listingClose
    bcs rcrFail
    lda #CASM_DIAG_NONE
    jsr listingAbort
    bcs rcrFail
    jsr checkNoListOwnership
    bne rcrFail
    jsr faultUninstall
    clc
    rts
rcrFail:
    jsr faultUninstall
    sec
    rts

unregisteredCloseRetry:
    ldx #<unregisteredName
    ldy #>unregisteredName
    jsr prepareListingFile
    bcs ucrFail
    jsr fillFakeRegistry
    jsr faultInstall
    lda #DOS_CLOSE_FILE
    ldx #1
    ldy #0
    jsr armFault
    tsx
    stx SavedSp
    jsr listingCreate
    php
    pha
    jsr clearFakeRegistry
    pla
    plp
    bcc ucrFail
    cmp #CASM_DIAG_LISTING_CREATE_FAILED
    bne ucrFail
    tsx
    cpx SavedSp
    bne ucrFail
    lda CasmListFileSlot
    cmp #CASM_INVALID_SLOT
    bne ucrFail
    lda CasmListFileHandle
    cmp #CASM_INVALID_HANDLE
    beq ucrFail
    lda CasmListFileOpened
    beq ucrFail
    lda CasmListFileState
    cmp #CASM_FILE_STATE_CLOSE_FAILED
    bne ucrFail
    jsr faultUninstall
    lda #CASM_DIAG_LISTING_CREATE_FAILED
    jsr listingAbort
    bcc ucrFail
    cmp #CASM_DIAG_LISTING_CREATE_FAILED
    bne ucrFail
    jsr checkNoListOwnership
    bne ucrFail
    jsr faultUninstall
    clc
    rts
ucrFail:
    jsr clearFakeRegistry
    jsr faultUninstall
    sec
    rts

deleteFailureRetry:
    ldx #<deleteRetryName
    ldy #>deleteRetryName
    jsr prepareListingFile
    bcs dfrFail
    jsr listingCreate
    bcs dfrFail
    jsr listingClose
    bcs dfrFail
    jsr faultInstall
    lda #DOS_DELETE_FILE
    ldx #1
    ldy #0
    jsr armFault
    tsx
    stx SavedSp
    lda #CASM_DIAG_NONE
    jsr listingAbort
    bcc dfrFail
    cmp #CASM_DIAG_LISTING_DELETE_FAILED
    bne dfrFail
    tsx
    cpx SavedSp
    bne dfrFail
    lda CasmListFileDeletePending
    beq dfrFail
    lda CasmListFileOpened
    beq dfrFail
    jsr faultUninstall
    lda #CASM_DIAG_NONE
    jsr listingAbort
    bcs dfrFail
    jsr checkNoListOwnership
    bne dfrFail
    jsr faultUninstall
    clc
    rts
dfrFail:
    jsr faultUninstall
    sec
    rts

abortPreservesPrimary:
    ldx #<primaryAbortName
    ldy #>primaryAbortName
    jsr prepareListingFile
    bcs appFail
    jsr listingCreate
    bcs appFail
    jsr faultInstall
    lda #DOS_CLOSE_FILE
    ldx #1
    ldy #0
    jsr armFault
    tsx
    stx SavedSp
    lda #CASM_DIAG_LISTING_WRITE_FAILED
    jsr listingAbort
    bcc appFail
    cmp #CASM_DIAG_LISTING_WRITE_FAILED
    bne appFail
    tsx
    cpx SavedSp
    bne appFail
    jsr faultUninstall
    lda #CASM_DIAG_LISTING_WRITE_FAILED
    jsr listingAbort
    bcc appFail
    jsr checkNoListOwnership
    bne appFail
    jsr faultUninstall
    clc
    rts
appFail:
    jsr faultUninstall
    sec
    rts

abortReturnsCloseFailure:
    ldx #<secondaryAbortName
    ldy #>secondaryAbortName
    jsr prepareListingFile
    bcs arcfFail
    jsr listingCreate
    bcs arcfFail
    jsr faultInstall
    lda #DOS_CLOSE_FILE
    ldx #1
    ldy #0
    jsr armFault
    tsx
    stx SavedSp
    lda #CASM_DIAG_NONE
    jsr listingAbort
    bcc arcfFail
    cmp #CASM_DIAG_LISTING_CLOSE_FAILED
    bne arcfFail
    tsx
    cpx SavedSp
    bne arcfFail
    jsr faultUninstall
    lda #CASM_DIAG_NONE
    jsr listingAbort
    bcs arcfFail
    jsr checkNoListOwnership
    bne arcfFail
    jsr faultUninstall
    clc
    rts
arcfFail:
    jsr faultUninstall
    sec
    rts

committedNeverDeleted:
    ldx #<committedName
    ldy #>committedName
    jsr prepareListingFile
    bcs cndFail
    jsr listingCreate
    bcs cndFail
    jsr listingClose
    bcs cndFail
    lda #CASM_LISTFILE_COMMITTED
    sta CasmListFileCommitted
    tsx
    stx SavedSp
    lda #CASM_DIAG_NONE
    jsr listingAbort
    bcs cndFail
    tsx
    cpx SavedSp
    bne cndFail
    lda CasmListFileOpened
    beq cndFail
    lda #CASM_LISTFILE_NOT_COMMITTED
    sta CasmListFileCommitted
    lda #CASM_DIAG_NONE
    jsr listingAbort
    bcs cndFail
    jsr checkNoListOwnership
    bne cndFail
    clc
    rts
cndFail:
    sec
    rts

.include "../casm_faultinject/faultstub.inc"

diagPrintFatal:
    rts
sourceSetLineCapture:
    clc
    rts
sourceTakeCompletedLine:
    lda CasmSourceCompletedFlags
    pha
    and #($FF - CASM_SOURCE_COMPLETED_FLAG_VALID)
    sta CasmSourceCompletedFlags
    pla
    clc
    rts
includeCatalogRead:
    inc IncludeReadCalls
    lda IncludeReadFail
    bne standinReadFail
    lda IncludeDevice
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_DEVICE
    lda IncludeNameLo
    sta CasmValue1Lo
    lda IncludeNameHi
    sta CasmValue1Hi
    ldy #0
icrCopyName:
    lda (CasmValue1Lo), y
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAME, y
    beq icrNameDone
    iny
    cpy #CASM_INCLUDE_FILENAME_MAX + 1
    bcc icrCopyName
icrNameDone:
    lda #CASM_DIAG_NONE
    clc
    rts
sourceReadSpanChunk:
    inc SourceSpanCalls
    lda SourceSpanFail
    bne standinReadFail
    ldy #0
srcStandinCopy:
    cpy CasmIoLenLo
    beq srcStandinDone
    lda standinSourceData, y
    sta CasmVmmBuffer, y
    iny
    bne srcStandinCopy
srcStandinDone:
    lda #CASM_DIAG_NONE
    clc
    rts
standinReadFail:
    lda #CASM_DIAG_VMM_TRANSFER_FAILED
    sec
    rts

.segment "RODATA"
includeDeviceStrLo: .lobytes device8, device9, device10, device11
includeDeviceStrHi: .hibytes device8, device9, device10, device11
device8: .byte "8", 0
device9: .byte "9", 0
device10: .byte "10", 0
device11: .byte "11", 0
emptyMsg: .byte 0
serializerListingName: .byte "FLI03.LST", 0
serializerSourceName: .byte "SRC", 0
serializerMetaName: .byte "FLI05A.LST", 0
serializerIncludeName: .byte "FLI05B.LST", 0
serializerSourceFailName: .byte "FLI05C.LST", 0
serializerWriteName: .byte "FLI05D.LST", 0
serializerShortName: .byte "FLI05E.LST", 0
serializerCloseName: .byte "FLI05F.LST", 0
serializerAbortCloseName: .byte "FLI05G.LST", 0
serializerAbortDeleteName: .byte "FLI05H.LST", 0
standinSourceData: .byte "S"
includeNameI: .byte "I", 0
createFailName: .byte "FLI04A.LST", 0
registerFailName: .byte "FLI04B.LST", 0
writeFailName: .byte "FLI04C.LST", 0
shortWriteName: .byte "FLI04D.LST", 0
closeRetryName: .byte "FLI04E.LST", 0
unregisteredName: .byte "FLI04F.LST", 0
deleteRetryName: .byte "FLI04G.LST", 0
primaryAbortName: .byte "FLI04H.LST", 0
secondaryAbortName: .byte "FLI04I.LST", 0
committedName: .byte "FLI04J.LST", 0
writeByte: .byte $A5
passMsg: .byte "CASM FAULT LIST: PASS", PetCr, 0
failMsg: .byte "CASM FAULT LIST: FAIL", PetCr, 0

.segment "BSS"
FailCount: .res 1
SavedSp: .res 1
ExpectedVector: .res 2
CasmPc: .res 2
CasmSourceCompletedFlags: .res 1
CasmSourceCompletedStartLo: .res 1
CasmSourceCompletedStartHi: .res 1
CasmSourceCompletedLength: .res 1
CasmSourceCompletedFileId: .res 1
CasmSourceCompletedLineLo: .res 1
CasmSourceCompletedLineHi: .res 1
CasmListingName: .res CASM_FILENAME_BUFFER_SIZE
CasmListingLen: .res 1
CasmOutputName: .res CASM_FILENAME_BUFFER_SIZE
CasmSourceCount: .res 1
cliSourceSlotLo: .res 1
cliSourceSlotHi: .res 1
CasmIncludeCatalogCount: .res 1
CasmIncludeRecordStage: .res CASM_INCLUDE_PHYS_REC_SIZE
CasmSourceState: .res 1
ExpectedDiag: .res 1
TestNameLo: .res 1
TestNameHi: .res 1
TestFileId: .res 1
TestSourceLen: .res 1
IncludeReadCalls: .res 1
SourceSpanCalls: .res 1
IncludeReadFail: .res 1
SourceSpanFail: .res 1
IncludeDevice: .res 1
IncludeNameLo: .res 1
IncludeNameHi: .res 1
