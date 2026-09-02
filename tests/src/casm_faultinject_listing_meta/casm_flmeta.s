; tests/src/casm_faultinject_listing_meta/casm_flmeta.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 11 WP59 Increment 6 filename/device/header harness.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

CASM_FAULT_BOUNDARY_COUNTERS = 1

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_flmeta.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import fileIoInit
.import listingStateInit
.import listingFileInit
.import listingCaptureInit
.import listingBeginLine
.import listingMirrorByte
.import listingCommitLine
.import listingCaptureFinalize
.import listingWriteFile
.import listingAbort
.import listingResolveFilename
.import CasmListResolvedName
.import CasmListResolvedNameLen
.import CasmVmmBuffer
.import CasmVmmRegistry
.import CasmFileCount
.import CasmOutputCommitted
.import CasmListFileHandle
.import CasmListFileSlot
.import CasmListFileState
.import CasmListFileOpened
.import CasmListFileCommitted
.import CasmListFileDeletePending

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

    jsr resolveIncludedDevice8
    jsr reportCase
    jsr resolveIncludedDevice11
    jsr reportCase
    jsr resolveInvalidDevice7
    jsr reportCase
    jsr resolveInvalidDevice12
    jsr reportCase
    jsr resolveRootIdentity
    jsr reportCase
    jsr resolveMaxIncludedName
    jsr reportCase
    jsr serializerHeader31
    jsr reportCase
    jsr serializerHeader32
    jsr reportCase
    jsr serializerCatalogClobberSnapshot
    jsr reportCase

    lda #PetCr
    jsr KernalChROUT
    lda FailCount
    beq allPass
    lda #<failMsg
    ldy #>failMsg
    bne printResult
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

resetBoundaryCounters:
    lda #0
    sta FaultOpenCalls
    sta FaultWriteCalls
    sta FaultCloseCalls
    sta FaultDeleteCalls
    sta FaultVmmReadCalls
    sta IncludeReadCalls
    sta SourceSpanCalls
    sta IncludeCorruptBuffer
    sta VerifySourceRequest
    sta SourceRequestMismatch
    rts

resetIncludeStandin:
    lda #CASM_DEVICE_MIN
    sta IncludeDevice
    lda #<includeNameI
    sta IncludeNameLo
    lda #>includeNameI
    sta IncludeNameHi
    lda #0
    sta IncludeCorruptBuffer
    rts

prepareResolveInclude:
    lda #1
    sta CasmIncludeCatalogCount
    jsr resetBoundaryCounters
    jsr resetIncludeStandin
    rts

checkResolveText:
    sta ExpectedNameLen
    stx ExpectedNameLo
    sty ExpectedNameHi
    tsx
    stx SavedSp
    lda TestFileId
    jsr listingResolveFilename
    bcs crtFail
    cmp #CASM_DIAG_NONE
    bne crtFail
    tsx
    cpx SavedSp
    bne crtFail
    lda CasmListResolvedNameLen
    cmp ExpectedNameLen
    bne crtFail
    lda ExpectedNameLo
    sta CasmValue1Lo
    lda ExpectedNameHi
    sta CasmValue1Hi
    ldy #0
crtLoop:
    lda (CasmValue1Lo), y
    cmp CasmListResolvedName, y
    bne crtFail
    iny
    cpy ExpectedNameLen
    bcc crtLoop
    lda CasmListResolvedName, y
    bne crtFail
    clc
    rts
crtFail:
    sec
    rts

resolveIncludedDevice8:
    jsr prepareResolveInclude
    lda #CASM_DIAG_FILEID_FRAME_FLAG
    sta TestFileId
    ldx #<resolved8
    ldy #>resolved8
    lda #3
    jsr checkResolveText
    bcs rid8Fail
    lda IncludeReadCalls
    cmp #1
    bne rid8Fail
    clc
    rts
rid8Fail:
    sec
    rts

resolveIncludedDevice11:
    jsr prepareResolveInclude
    lda #CASM_DEVICE_MAX
    sta IncludeDevice
    lda #CASM_DIAG_FILEID_FRAME_FLAG
    sta TestFileId
    ldx #<resolved11
    ldy #>resolved11
    lda #4
    jsr checkResolveText
    bcs rid11Fail
    lda IncludeReadCalls
    cmp #1
    bne rid11Fail
    clc
    rts
rid11Fail:
    sec
    rts

checkInvalidDevice:
    sta IncludeDevice
    lda #$A5
    sta CasmListResolvedNameLen
    sta CasmListResolvedName
    tsx
    stx SavedSp
    lda #CASM_DIAG_FILEID_FRAME_FLAG
    jsr listingResolveFilename
    bcc cidFail
    cmp #CASM_DIAG_LISTING_REPLAY_MISMATCH
    bne cidFail
    tsx
    cpx SavedSp
    bne cidFail
    lda IncludeReadCalls
    cmp #1
    bne cidFail
    lda CasmListResolvedNameLen
    cmp #$A5
    bne cidFail
    lda CasmListResolvedName
    cmp #$A5
    bne cidFail
    clc
    rts
cidFail:
    sec
    rts

resolveInvalidDevice7:
    jsr prepareResolveInclude
    lda #CASM_DEVICE_MIN - 1
    jmp checkInvalidDevice

resolveInvalidDevice12:
    jsr prepareResolveInclude
    lda #CASM_DEVICE_MAX + 1
    jmp checkInvalidDevice

resolveRootIdentity:
    jsr resetBoundaryCounters
    lda #1
    sta CasmSourceCount
    lda #<rootIdentityName
    sta cliSourceSlotLo
    lda #>rootIdentityName
    sta cliSourceSlotHi
    lda #0
    sta TestFileId
    ldx #<rootIdentityName
    ldy #>rootIdentityName
    lda #18
    jsr checkResolveText
    bcs rriFail
    lda IncludeReadCalls
    bne rriFail
    clc
    rts
rriFail:
    sec
    rts

resolveMaxIncludedName:
    jsr prepareResolveInclude
    lda #<includeNameCap
    sta IncludeNameLo
    lda #>includeNameCap
    sta IncludeNameHi
    lda #CASM_DEVICE_MAX
    sta IncludeDevice
    lda #CASM_DIAG_FILEID_FRAME_FLAG
    sta TestFileId
    ldx #<resolvedMaxIncluded
    ldy #>resolvedMaxIncluded
    lda #35
    jmp checkResolveText

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

prepareSerializer:
    jsr resetOwnedState
    bcs psRet
    jsr listingCaptureInit
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

cleanupSuccessfulSerializer:
    lda #CASM_LISTFILE_NOT_COMMITTED
    sta CasmListFileCommitted
    lda #CASM_DIAG_NONE
    jsr listingAbort
    bcs cssFail
    jsr checkNoListOwnership
    bne cssFail
    clc
    rts
cssFail:
    sec
    rts

serializerHeader31:
    lda #<serializerHeader31Name
    sta TestNameLo
    lda #>serializerHeader31Name
    sta TestNameHi
    lda #0
    sta TestFileId
    sta TestSourceLen
    jsr prepareSerializer
    bcs sh31Fail
    lda #<headerName31
    sta cliSourceSlotLo
    lda #>headerName31
    sta cliSourceSlotHi
    jsr faultInstall
    jsr resetBoundaryCounters
    tsx
    stx SavedSp
    jsr listingWriteFile
    bcs sh31Fail
    cmp #CASM_DIAG_NONE
    bne sh31Fail
    tsx
    cpx SavedSp
    bne sh31Fail
    lda CasmIoLenLo
    cmp #82
    bne sh31Fail
    lda CasmIoLenHi
    bne sh31Fail
    lda FaultWriteCalls
    cmp #1
    bne sh31Fail
    jsr cleanupSuccessfulSerializer
    bcs sh31Fail
    jsr faultUninstall
    clc
    rts
sh31Fail:
    jsr faultUninstall
    sec
    rts

serializerHeader32:
    lda #<serializerHeader32Name
    sta TestNameLo
    lda #>serializerHeader32Name
    sta TestNameHi
    lda #0
    sta TestFileId
    sta TestSourceLen
    jsr prepareSerializer
    bcs sh32Fail
    lda #<headerName32
    sta cliSourceSlotLo
    lda #>headerName32
    sta cliSourceSlotHi
    jsr faultInstall
    jsr resetBoundaryCounters
    tsx
    stx SavedSp
    jsr listingWriteFile
    bcs sh32Fail
    cmp #CASM_DIAG_NONE
    bne sh32Fail
    tsx
    cpx SavedSp
    bne sh32Fail
    lda CasmIoLenLo
    cmp #123
    bne sh32Fail
    lda CasmIoLenHi
    bne sh32Fail
    lda FaultWriteCalls
    cmp #1
    bne sh32Fail
    jsr cleanupSuccessfulSerializer
    bcs sh32Fail
    jsr faultUninstall
    clc
    rts
sh32Fail:
    jsr faultUninstall
    sec
    rts

serializerCatalogClobberSnapshot:
    lda #<serializerSnapshotName
    sta TestNameLo
    lda #>serializerSnapshotName
    sta TestNameHi
    lda #CASM_DIAG_FILEID_FRAME_FLAG
    sta TestFileId
    lda #1
    sta TestSourceLen
    jsr prepareSerializer
    bcs scsFail
    lda #1
    sta IncludeCorruptBuffer
    sta VerifySourceRequest
    jsr faultInstall
    jsr resetBoundaryCounters
    jsr resetIncludeStandin
    lda #1
    sta IncludeCorruptBuffer
    sta VerifySourceRequest
    jsr listingWriteFile
    bcs scsFail
    cmp #CASM_DIAG_NONE
    bne scsFail
    lda SourceRequestMismatch
    bne scsFail
    lda SourceSpanCalls
    cmp #1
    bne scsFail
    jsr cleanupSuccessfulSerializer
    bcs scsFail
    jsr faultUninstall
    clc
    rts
scsFail:
    jsr faultUninstall
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
    lda IncludeCorruptBuffer
    beq icrDone
    ldy #CASM_LISTING_META_REC_SIZE - 1
    lda #$A5
icrCorrupt:
    sta CasmVmmBuffer, y
    dey
    bpl icrCorrupt
icrDone:
    lda #CASM_DIAG_NONE
    clc
    rts
sourceReadSpanChunk:
    inc SourceSpanCalls
    lda VerifySourceRequest
    beq srcStandinNoVerify
    lda CasmVmmOffLo
    ora CasmVmmOffHi
    ora CasmIoLenHi
    bne srcStandinMismatch
    lda CasmIoLenLo
    cmp #1
    beq srcStandinNoVerify
srcStandinMismatch:
    inc SourceRequestMismatch
srcStandinNoVerify:
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

.segment "RODATA"
includeDeviceStrLo: .lobytes device8, device9, device10, device11
includeDeviceStrHi: .hibytes device8, device9, device10, device11
device8: .byte "8", 0
device9: .byte "9", 0
device10: .byte "10", 0
device11: .byte "11", 0
serializerSourceName: .byte "SRC", 0
serializerHeader31Name: .byte "FLI06A.LST", 0
serializerHeader32Name: .byte "FLI06B.LST", 0
serializerSnapshotName: .byte "FLI06C.LST", 0
standinSourceData: .byte "S"
includeNameI: .byte "I", 0
resolved8: .byte "8:I"
resolved11: .byte "11:I"
rootIdentityName: .byte "ROOT-IDENTITY-NAME", 0
headerName31: .byte "1234567890123456789012345678901", 0
headerName32: .byte "12345678901234567890123456789012", 0
; Finding D (memory-optimization WP, task 42, 2026-08-31): the include
; filename cap dropped 63 -> 32. This case exercises listingResolveFilename's
; success path at the new maximum -- a 32-char include name under device 11
; resolves to "11:" + 32 chars = 35 bytes. (Sibling re-pins landed in
; casm_include validCap / casm_cliderive cderboundary1; this one was missed
; until the Phase 14 WP92 sweep -- see brain/plans/2026-09-01-casm-flmeta-
; maxincluded-regression.md.)
includeNameCap: .byte "12345678901234567890123456789012", 0
resolvedMaxIncluded: .byte "11:12345678901234567890123456789012"
passMsg: .byte "CASM FAULT META: PASS", PetCr, 0
failMsg: .byte "CASM FAULT META: FAIL", PetCr, 0

.segment "BSS"
FailCount: .res 1
SavedSp: .res 1
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
TestNameLo: .res 1
TestNameHi: .res 1
TestFileId: .res 1
TestSourceLen: .res 1
IncludeReadCalls: .res 1
SourceSpanCalls: .res 1
IncludeDevice: .res 1
IncludeNameLo: .res 1
IncludeNameHi: .res 1
IncludeCorruptBuffer: .res 1
ExpectedNameLo: .res 1
ExpectedNameHi: .res 1
ExpectedNameLen: .res 1
VerifySourceRequest: .res 1
SourceRequestMismatch: .res 1
