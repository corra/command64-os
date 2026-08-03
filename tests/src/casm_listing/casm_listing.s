; tests/src/casm_listing/casm_listing.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 10 WP51 increment 3 fixture harness. Exercises
; listing.s's listingStateInit/listingCaptureInit/listingMetaAppend/
; listingReplayReset/listingReplayNext directly against real
; DOS_ALLOC_MEM/DOS_VMM_READ/DOS_VMM_WRITE calls, mirroring casm_reloc.s's
; own isolated-module-first precedent (the metadata store is structurally
; identical to the relocation table: a fixed-size append-only VMM record
; list with a capacity check).
;
; listing.s imports sourceSetLineCapture (source.s) via listingCaptureInit;
; this harness deliberately does not link source.s (matching casm_reloc.s's
; own isolation from emit.s's real CasmPc/CasmPassMode) -- a trivial local
; stub satisfies the link, since this harness proves the VMM allocation/
; metadata/replay mechanics, not source-side capture enablement (that is
; Increment 6's real-path job, per the WP51 plan).
;
; Stubs diagPrintFatal locally rather than importing the real diagnostics.s,
; for the same reason casm_reloc.s/casm_vmm.s/casm_symbols.s already do:
; resources.s's exitSuccess/exitFatal reference it, and ld65 links whole
; object files, so it must resolve even though this harness never calls
; exitSuccess/exitFatal.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_listing.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import listingStateInit
.import listingCaptureInit
.import listingMetaAppend
.import listingReplayReset
.import listingReplayNext
.import listingBeginLine
.import listingMirrorByte
.import listingCommitLine
.import listingCaptureFinalize
.import CasmListingState
.import CasmListingMetaVmmSlot
.import CasmListingByteVmmSlot
.import CasmListingRecordCountLo
.import CasmListingRecordCountHi
.import CasmListingPendingFileId
.import CasmListingPendingFlags
.import CasmListingPendingLineLo
.import CasmListingPendingLineHi
.import CasmListingPendingOffsetLo
.import CasmListingPendingOffsetHi
.import CasmListingPendingLen
.import CasmListingPendingPcLo
.import CasmListingPendingPcHi
.import CasmListingPendingByteOffLo
.import CasmListingPendingByteOffHi
.import CasmListingPendingByteCountLo
.import CasmListingPendingByteCountHi
.import vmmStoreAlloc
.import vmmStoreFree
.import vmmWindowRead
.import CasmVmmBuffer
.import CasmListingByteCursorLo
.import CasmListingByteCursorHi
.import CasmListingByteFull
.import CasmListingStage
.import CasmListingStageLen
.import CasmListingTxnActive

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

    jsr listinginit1
    jsr reportCase
    jsr listingallocfail1
    jsr reportCase
    jsr listingappend1
    jsr reportCase
    jsr listingreplay1
    jsr reportCase
    jsr listingvmmfail1
    jsr reportCase
    jsr listingfull1
    jsr reportCase
    jsr listingtxn1
    jsr reportCase
    jsr listingtxnedge1
    jsr reportCase
    jsr listingstage1
    jsr reportCase
    jsr listingfull2
    jsr reportCase
    jsr listingfinalize1
    jsr reportCase

    ; Every fixture above frees whatever it allocates itself (matching
    ; casm_vmm.s's vmmalloc3 precedent) except listinginit1's own allocation,
    ; kept deliberately live for listingappend1/listingreplay1 to reuse
    ; (mirroring casm_reloc.s's relocinit1/relocrecord1/relocmeasure1
    ; chaining) and freed here at the very end, alongside a final registry
    ; sweep for anything a failed fixture might have left registered.
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
; FailCount. Called immediately after each fixture; JSR/RTS do not disturb
; the carry the fixture just set.
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
; listinginit1
; listingStateInit then listingCaptureInit: confirm success, both VMM slots
; distinct, record/replay counters zero, and CasmListingState transitions to
; ENABLED. Leaves the allocation live for listingappend1/listingreplay1.
; ---------------------------------------------------------------------------
listinginit1:
    jsr listingStateInit
    bcc :+
    jmp li1Fail
:
    jsr listingCaptureInit
    bcc :+
    jmp li1Fail
:
    lda CasmListingState
    cmp #CASM_LISTING_STATE_ENABLED
    beq :+
    jmp li1Fail
:
    lda CasmListingMetaVmmSlot
    cmp CasmListingByteVmmSlot
    bne :+
    jmp li1Fail                  ; the two stores must not share a slot
:
    lda CasmListingRecordCountLo
    ora CasmListingRecordCountHi
    beq :+
    jmp li1Fail
:
    clc
    rts
li1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; listingallocfail1
; Fill registry slots so exactly one is free, then call listingCaptureInit
; on a fresh state: the first allocation succeeds (claiming the last free
; slot), the second is rejected (registry full). Confirms CasmListingState
; stays NONE (the failed init never reached CASM_LISTING_STATE_ENABLED) and
; frees every slot this fixture touched, including listingCaptureInit's own
; partial first allocation, restoring a clean registry for later fixtures.
;
; The registry (CASM_VMM_CAPACITY = 8) already holds 2 live slots here --
; listinginit1's own metadata/byte-mirror allocations, deliberately left
; live for listingappend1/listingreplay1 to reuse. Only 5 more dummy slots
; are needed (2 + 5 = 7) to leave exactly one free.
;
; listingCaptureInit's own first (successful) allocation below overwrites
; the shared CasmListingMetaVmmSlot/CasmListingByteVmmSlot exported
; variables -- which still hold listinginit1's live slot numbers at this
; point. Saved here and restored before returning, or listingappend1 would
; silently resume against this fixture's own already-freed slot instead of
; listinginit1's real one.
; ---------------------------------------------------------------------------
listingallocfail1:
    lda CasmListingMetaVmmSlot
    sta SavedMetaSlot
    lda CasmListingByteVmmSlot
    sta SavedByteSlot
    lda #0
    sta SlotCount
laf1FillLoop:
    ldx #32
    ldy #0
    jsr vmmStoreAlloc
    bcc :+
    jmp laf1Fail
:
    txa
    ldy SlotCount
    sta SlotTable, y
    inc SlotCount
    lda SlotCount
    cmp #5                       ; 5 dummy slots (+2 already live) leave one free
    bne laf1FillLoop

    jsr listingStateInit
    bcc :+
    jmp laf1Fail
:
    jsr listingCaptureInit
    bcs :+
    jmp laf1Fail                 ; the second allocation must fail
:
    cmp #CASM_DIAG_VMM_ALLOC_FAILED
    beq :+
    jmp laf1Fail
:
    lda CasmListingState
    cmp #CASM_LISTING_STATE_NONE
    beq :+
    jmp laf1Fail
:
    ; Free listingCaptureInit's own successful first allocation (the store
    ; this harness never sees any other way to release, since
    ; listingCaptureInit itself never frees on a later failure).
    ldx CasmListingMetaVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp laf1Fail
:
    lda #0
    sta SlotCount
laf1FreeLoop:
    ldy SlotCount
    ldx SlotTable, y
    jsr vmmStoreFree
    bcc :+
    jmp laf1Fail
:
    inc SlotCount
    lda SlotCount
    cmp #5
    bne laf1FreeLoop

    ; Restore listinginit1's live slot numbers and ENABLED state for
    ; listingappend1/listingreplay1 to resume against.
    lda SavedMetaSlot
    sta CasmListingMetaVmmSlot
    lda SavedByteSlot
    sta CasmListingByteVmmSlot
    lda #CASM_LISTING_STATE_ENABLED
    sta CasmListingState
    clc
    rts
laf1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; listingappend1
; Append three records with distinct, fully-populated field values (reusing
; listinginit1's live allocation), deliberately dirtying CasmVmmBuffer with
; $FF before each append so the reserved-byte zero-fill is a real proof, not
; an accident of already-zero memory. Reads all 48 written bytes back in one
; vmmWindowRead and checks every byte's exact position, including both
; reserved offsets landing zero regardless of the dirtied staging buffer.
; ---------------------------------------------------------------------------
listingappend1:
    jsr laDirtyBuffer
    lda #$01
    sta CasmListingPendingFileId
    lda #$00
    sta CasmListingPendingFlags
    lda #$01
    sta CasmListingPendingLineLo
    lda #$00
    sta CasmListingPendingLineHi
    lda #$00
    sta CasmListingPendingOffsetLo
    sta CasmListingPendingOffsetHi
    lda #$05
    sta CasmListingPendingLen
    lda #<CASM_DEFAULT_ORIGIN
    sta CasmListingPendingPcLo
    lda #>CASM_DEFAULT_ORIGIN
    sta CasmListingPendingPcHi
    lda #$00
    sta CasmListingPendingByteOffLo
    sta CasmListingPendingByteOffHi
    lda #$05
    sta CasmListingPendingByteCountLo
    lda #$00
    sta CasmListingPendingByteCountHi
    jsr listingMetaAppend
    bcc :+
    jmp la1Fail
:
    jsr laDirtyBuffer
    lda #$02
    sta CasmListingPendingFileId
    lda #CASM_LISTING_META_FLAG_FINAL_UNTERMINATED
    sta CasmListingPendingFlags
    lda #$02
    sta CasmListingPendingLineLo
    lda #$00
    sta CasmListingPendingLineHi
    lda #$05
    sta CasmListingPendingOffsetLo
    lda #$00
    sta CasmListingPendingOffsetHi
    lda #$0A
    sta CasmListingPendingLen
    lda #<(CASM_DEFAULT_ORIGIN + 5)
    sta CasmListingPendingPcLo
    lda #>(CASM_DEFAULT_ORIGIN + 5)
    sta CasmListingPendingPcHi
    lda #$05
    sta CasmListingPendingByteOffLo
    lda #$00
    sta CasmListingPendingByteOffHi
    lda #$0A
    sta CasmListingPendingByteCountLo
    lda #$00
    sta CasmListingPendingByteCountHi
    jsr listingMetaAppend
    bcc :+
    jmp la1Fail
:
    jsr laDirtyBuffer
    lda #$FF
    sta CasmListingPendingFileId
    lda #$00
    sta CasmListingPendingFlags
    lda #$FF
    sta CasmListingPendingLineLo
    sta CasmListingPendingLineHi
    lda #$34
    sta CasmListingPendingOffsetLo
    lda #$12
    sta CasmListingPendingOffsetHi
    lda #$FF
    sta CasmListingPendingLen
    lda #$FE
    sta CasmListingPendingPcLo
    lda #$FF
    sta CasmListingPendingPcHi
    lda #$FE
    sta CasmListingPendingByteOffLo
    lda #$FF
    sta CasmListingPendingByteOffHi
    lda #$40
    sta CasmListingPendingByteCountLo
    lda #$01
    sta CasmListingPendingByteCountHi
    jsr listingMetaAppend
    bcc :+
    jmp la1Fail
:
    ldx CasmListingMetaVmmSlot
    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    lda #48
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowRead
    bcc :+
    jmp la1Fail
:
    ; Record 0
    lda CasmVmmBuffer + 0
    cmp #$01
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 1
    cmp #$00
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 2
    cmp #$01
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 3
    cmp #$00
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 4
    cmp #$00
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 5
    cmp #$00
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 6
    cmp #$05
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 7
    cmp #$00                     ; Reserved0 must be zero despite the dirty stage
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 8
    cmp #<CASM_DEFAULT_ORIGIN
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 9
    cmp #>CASM_DEFAULT_ORIGIN
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 10
    cmp #$00
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 11
    cmp #$00
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 12
    cmp #$05
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 13
    cmp #$00
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 14
    cmp #$00                     ; Reserved1 (2 bytes) must be zero
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 15
    cmp #$00
    beq :+
    jmp la1Fail
:

    ; Record 1 (base offset 16)
    lda CasmVmmBuffer + 16
    cmp #$02
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 17
    cmp #CASM_LISTING_META_FLAG_FINAL_UNTERMINATED
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 18
    cmp #$02
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 22
    cmp #$0A
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 23
    cmp #$00                     ; Reserved0
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 24
    cmp #<(CASM_DEFAULT_ORIGIN + 5)
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 25
    cmp #>(CASM_DEFAULT_ORIGIN + 5)
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 26
    cmp #$05
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 28
    cmp #$0A
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 30
    cmp #$00                     ; Reserved1
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 31
    cmp #$00
    beq :+
    jmp la1Fail
:

    ; Record 2 (base offset 32)
    lda CasmVmmBuffer + 32
    cmp #$FF
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 33
    cmp #$00
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 34
    cmp #$FF
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 35
    cmp #$FF
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 36
    cmp #$34
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 37
    cmp #$12
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 38
    cmp #$FF
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 39
    cmp #$00                     ; Reserved0
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 40
    cmp #$FE
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 41
    cmp #$FF
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 42
    cmp #$FE
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 43
    cmp #$FF
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 44
    cmp #$40
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 45
    cmp #$01
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 46
    cmp #$00                     ; Reserved1
    beq :+
    jmp la1Fail
:
    lda CasmVmmBuffer + 47
    cmp #$00
    beq :+
    jmp la1Fail
:

    lda CasmListingRecordCountLo
    cmp #3
    beq :+
    jmp la1Fail
:
    lda CasmListingRecordCountHi
    beq :+
    jmp la1Fail
:
    clc
    rts
la1Fail:
    sec
    rts

laDirtyBuffer:
    ldy #63
    lda #$FF
laDirtyLoop:
    sta CasmVmmBuffer, y
    dey
    bpl laDirtyLoop
    rts

; ---------------------------------------------------------------------------
; listingreplay1
; Force CasmListingState to COMPLETE (poked directly -- listingCaptureFinalize
; does not exist until Increment 4) over listingappend1's three live records,
; then confirm listingReplayReset/listingReplayNext replays all three in
; order with CASM_STREAM_DATA and the exact field values written, then
; CASM_STREAM_EOF, repeat-stable across two further calls.
; ---------------------------------------------------------------------------
listingreplay1:
    lda #CASM_LISTING_STATE_COMPLETE
    sta CasmListingState

    jsr listingReplayReset
    bcc :+
    jmp lr1Fail
:
    ; Record 0
    jsr listingReplayNext
    bcc :+
    jmp lr1Fail
:
    cmp #CASM_STREAM_DATA
    beq :+
    jmp lr1Fail
:
    lda CasmVmmBuffer + 0
    cmp #$01
    beq :+
    jmp lr1Fail
:
    lda CasmVmmBuffer + 6
    cmp #$05
    beq :+
    jmp lr1Fail
:

    ; Record 1
    jsr listingReplayNext
    bcc :+
    jmp lr1Fail
:
    cmp #CASM_STREAM_DATA
    beq :+
    jmp lr1Fail
:
    lda CasmVmmBuffer + 0
    cmp #$02
    beq :+
    jmp lr1Fail
:
    lda CasmVmmBuffer + 1
    cmp #CASM_LISTING_META_FLAG_FINAL_UNTERMINATED
    beq :+
    jmp lr1Fail
:

    ; Record 2
    jsr listingReplayNext
    bcc :+
    jmp lr1Fail
:
    cmp #CASM_STREAM_DATA
    beq :+
    jmp lr1Fail
:
    lda CasmVmmBuffer + 0
    cmp #$FF
    beq :+
    jmp lr1Fail
:
    lda CasmVmmBuffer + 6
    cmp #$FF
    beq :+
    jmp lr1Fail
:

    ; EOF, repeat-stable across two further calls.
    jsr listingReplayNext
    bcc :+
    jmp lr1Fail
:
    cmp #CASM_STREAM_EOF
    beq :+
    jmp lr1Fail
:
    jsr listingReplayNext
    bcc :+
    jmp lr1Fail
:
    cmp #CASM_STREAM_EOF
    beq :+
    jmp lr1Fail
:
    ; Restore ENABLED and free listinginit1/listingappend1's shared
    ; allocation now that every fixture reusing it is done.
    lda #CASM_LISTING_STATE_ENABLED
    sta CasmListingState
    ldx CasmListingMetaVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lr1Fail
:
    ldx CasmListingByteVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lr1Fail
:
    lda #CASM_LISTING_STATE_NONE
    sta CasmListingState
    clc
    rts
lr1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; listingvmmfail1
; Fresh allocation, then free the metadata slot out from under
; listingMetaAppend/listingReplayNext (both now targeting a slot whose
; registry FLAG is cleared) to force a real, deterministic local rejection
; -- CASM_DIAG_VMM_TRANSFER_FAILED -- from vmmWindowWrite/Read's own bounds
; check, rather than depending on an unreliable REU-exhaustion condition.
; ---------------------------------------------------------------------------
listingvmmfail1:
    jsr listingStateInit
    bcc :+
    jmp lv1Fail
:
    jsr listingCaptureInit
    bcc :+
    jmp lv1Fail
:
    ldx CasmListingMetaVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lv1Fail
:
    lda #$01
    sta CasmListingPendingFileId
    jsr listingMetaAppend
    bcs :+
    jmp lv1Fail                  ; append against a freed slot must fail
:
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    beq :+
    jmp lv1Fail
:
    ; Force COMPLETE to reach listingReplayNext's own transfer path against
    ; the same now-freed slot.
    lda #CASM_LISTING_STATE_COMPLETE
    sta CasmListingState
    jsr listingReplayReset
    bcc :+
    jmp lv1Fail
:
    ; One real record exists (count was never incremented by the failed
    ; append above), so replay reaches the transfer path rather than the
    ; empty-store EOF shortcut -- but the append above never actually wrote
    ; a real record, so stage one directly against the still-valid byte-
    ; mirror slot's count bookkeeping instead: bump the count by hand to
    ; force listingReplayNext past its own index-vs-count check.
    inc CasmListingRecordCountLo
    jsr listingReplayNext
    bcs :+
    jmp lv1Fail                  ; replay against a freed slot must fail
:
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    beq :+
    jmp lv1Fail
:
    lda #CASM_LISTING_STATE_NONE
    sta CasmListingState
    dec CasmListingRecordCountLo
    ldx CasmListingByteVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lv1Fail
:
    clc
    rts
lv1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; listingfull1
; Fresh allocation filled to exactly CASM_LISTING_META_MAX records; confirm
; every one succeeds, then confirm the next call fails with
; CASM_DIAG_LISTING_RECORDS_FULL specifically. A real fill, matching
; casm_reloc.s's relocfull1/casm_vmm.s's vmmalloc3 precedent of exercising
; the actual boundary rather than asserting it indirectly.
; ---------------------------------------------------------------------------
listingfull1:
    jsr listingStateInit
    bcc :+
    jmp lf1Fail
:
    jsr listingCaptureInit
    bcc :+
    jmp lf1Fail
:
    lda #0
    sta CasmListingPendingFileId
    sta CasmListingPendingFlags
    sta CasmListingPendingLineHi
    sta CasmListingPendingOffsetLo
    sta CasmListingPendingOffsetHi
    sta CasmListingPendingLen
    sta CasmListingPendingPcLo
    sta CasmListingPendingPcHi
    sta CasmListingPendingByteOffLo
    sta CasmListingPendingByteOffHi
    sta CasmListingPendingByteCountLo
    sta CasmListingPendingByteCountHi
    lda #1
    sta CasmListingPendingLineLo

    lda #<CASM_LISTING_META_MAX
    sta LoopLo
    lda #>CASM_LISTING_META_MAX
    sta LoopHi
lf1Loop:
    jsr listingMetaAppend
    bcc lf1Continue
    jmp lf1Fail
lf1Continue:
    lda LoopLo
    bne lf1DecLo
    dec LoopHi
lf1DecLo:
    dec LoopLo
    lda LoopLo
    ora LoopHi
    bne lf1Loop

    ; Table is now exactly full; one more call must fail with
    ; CASM_DIAG_LISTING_RECORDS_FULL specifically, not merely "some" failure.
    jsr listingMetaAppend
    bcs :+
    jmp lf1Fail
:
    cmp #CASM_DIAG_LISTING_RECORDS_FULL
    beq :+
    jmp lf1Fail
:
    ldx CasmListingMetaVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lf1Fail
:
    ldx CasmListingByteVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lf1Fail
:
    lda #CASM_LISTING_STATE_NONE
    sta CasmListingState
    clc
    rts
lf1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; listingtxn1
; Fresh allocation. Basic listingBeginLine/listingMirrorByte/listingCommitLine
; lifecycle: mirror three bytes, commit a real (non-synthetic) completed
; line, and read the resulting metadata record back to confirm PC/ByteOff/
; ByteCount/FileId/Line/Offset/Len/Flags are exactly right.
; ---------------------------------------------------------------------------
listingtxn1:
    jsr listingStateInit
    bcc :+
    jmp lt1Fail
:
    jsr listingCaptureInit
    bcc :+
    jmp lt1Fail
:
    lda #<$3412
    sta CasmPc
    lda #>$3412
    sta CasmPc + 1
    jsr listingBeginLine
    bcc :+
    jmp lt1Fail
:
    lda #$AA
    jsr listingMirrorByte
    bcc :+
    jmp lt1Fail
:
    lda #$BB
    jsr listingMirrorByte
    bcc :+
    jmp lt1Fail
:
    lda #$CC
    jsr listingMirrorByte
    bcc :+
    jmp lt1Fail
:
    lda #1
    sta StubHasPending
    lda #CASM_SOURCE_COMPLETED_FLAG_VALID
    sta CasmSourceCompletedFlags
    lda #$10
    sta CasmSourceCompletedStartLo
    lda #$00
    sta CasmSourceCompletedStartHi
    lda #7
    sta CasmSourceCompletedLength
    lda #3
    sta CasmSourceCompletedFileId
    lda #9
    sta CasmSourceCompletedLineLo
    lda #0
    sta CasmSourceCompletedLineHi
    jsr listingCommitLine
    bcc :+
    jmp lt1Fail
:
    lda CasmListingRecordCountLo
    cmp #1
    beq :+
    jmp lt1Fail
:
    lda CasmListingRecordCountHi
    beq :+
    jmp lt1Fail
:
    ldx CasmListingMetaVmmSlot
    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    lda #16
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowRead
    bcc :+
    jmp lt1Fail
:
    lda CasmVmmBuffer + 0     ; FileId
    cmp #3
    beq :+
    jmp lt1Fail
:
    lda CasmVmmBuffer + 1     ; Flags (real line, not final-unterminated)
    cmp #0
    beq :+
    jmp lt1Fail
:
    lda CasmVmmBuffer + 2     ; Line lo
    cmp #9
    beq :+
    jmp lt1Fail
:
    lda CasmVmmBuffer + 4     ; Offset lo
    cmp #$10
    beq :+
    jmp lt1Fail
:
    lda CasmVmmBuffer + 6     ; Len
    cmp #7
    beq :+
    jmp lt1Fail
:
    lda CasmVmmBuffer + 8     ; PC lo
    cmp #$12
    beq :+
    jmp lt1Fail
:
    lda CasmVmmBuffer + 9     ; PC hi
    cmp #$34
    beq :+
    jmp lt1Fail
:
    lda CasmVmmBuffer + 10    ; ByteOff lo (begin cursor was 0)
    cmp #0
    beq :+
    jmp lt1Fail
:
    lda CasmVmmBuffer + 11    ; ByteOff hi
    cmp #0
    beq :+
    jmp lt1Fail
:
    lda CasmVmmBuffer + 12    ; ByteCount lo (3 bytes mirrored)
    cmp #3
    beq :+
    jmp lt1Fail
:
    lda CasmVmmBuffer + 13    ; ByteCount hi
    cmp #0
    beq :+
    jmp lt1Fail
:
    ldx CasmListingMetaVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lt1Fail
:
    ldx CasmListingByteVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lt1Fail
:
    lda #CASM_LISTING_STATE_NONE
    sta CasmListingState
    clc
    rts
lt1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; listingtxnedge1
; Fresh allocation. Exercises listingCommitLine's other two clearing paths
; (no pending completion; a synthetic-only completion), a real zero-byte
; line (a legitimate blank/comment-only line, distinct from the synthetic
; case), and the duplicate-begin / mirror-without-transaction rejections.
; ---------------------------------------------------------------------------
listingtxnedge1:
    jsr listingStateInit
    bcc :+
    jmp lte1Fail
:
    jsr listingCaptureInit
    bcc :+
    jmp lte1Fail
:
    ; Mirror without an active transaction must fail.
    lda #$01
    jsr listingMirrorByte
    bcs :+
    jmp lte1Fail
:
    cmp #CASM_DIAG_LISTING_REPLAY_MISMATCH
    beq :+
    jmp lte1Fail
:
    lda #0
    sta CasmPc
    sta CasmPc + 1
    jsr listingBeginLine
    bcc :+
    jmp lte1Fail
:
    ; Duplicate begin must fail without disturbing the active transaction.
    jsr listingBeginLine
    bcs :+
    jmp lte1Fail
:
    cmp #CASM_DIAG_LISTING_REPLAY_MISMATCH
    beq :+
    jmp lte1Fail
:
    lda #$FF
    jsr listingMirrorByte
    bcc :+
    jmp lte1Fail
:
    ; No pending completion: commit clears the transaction, no record.
    lda #0
    sta StubHasPending
    jsr listingCommitLine
    bcc :+
    jmp lte1Fail
:
    lda CasmListingRecordCountLo
    ora CasmListingRecordCountHi
    beq :+
    jmp lte1Fail
:
    ; A synthetic-only completion: commit clears the transaction, no record.
    jsr listingBeginLine
    bcc :+
    jmp lte1Fail
:
    lda #$EE
    jsr listingMirrorByte
    bcc :+
    jmp lte1Fail
:
    lda #1
    sta StubHasPending
    lda #(CASM_SOURCE_COMPLETED_FLAG_VALID | CASM_SOURCE_COMPLETED_FLAG_SYNTHETIC_ONLY)
    sta CasmSourceCompletedFlags
    jsr listingCommitLine
    bcc :+
    jmp lte1Fail
:
    lda CasmListingRecordCountLo
    ora CasmListingRecordCountHi
    beq :+
    jmp lte1Fail
:
    ; A real, legitimately empty line (no bytes mirrored) still records.
    jsr listingBeginLine
    bcc :+
    jmp lte1Fail
:
    lda #1
    sta StubHasPending
    lda #CASM_SOURCE_COMPLETED_FLAG_VALID
    sta CasmSourceCompletedFlags
    lda #0
    sta CasmSourceCompletedStartLo
    sta CasmSourceCompletedStartHi
    sta CasmSourceCompletedLength
    sta CasmSourceCompletedFileId
    lda #1
    sta CasmSourceCompletedLineLo
    lda #0
    sta CasmSourceCompletedLineHi
    jsr listingCommitLine
    bcc :+
    jmp lte1Fail
:
    lda CasmListingRecordCountLo
    cmp #1
    beq :+
    jmp lte1Fail
:
    lda CasmListingRecordCountHi
    beq :+
    jmp lte1Fail
:
    ldx CasmListingMetaVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lte1Fail
:
    ldx CasmListingByteVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lte1Fail
:
    lda #CASM_LISTING_STATE_NONE
    sta CasmListingState
    clc
    rts
lte1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; listingstage1
; Fresh allocation. Mirrors exactly 63 bytes (no flush yet), then a 64th
; (flush to exactly one VMM window), then a 65th (fresh stage after flush),
; confirming CasmListingStageLen at each boundary and reading the flushed 64
; bytes back from the byte-mirror VMM store to confirm exact content and
; order. Commits the line and confirms the metadata record's ByteCount (65)
; and ByteOff (0, the begin-time cursor).
; ---------------------------------------------------------------------------
listingstage1:
    jsr listingStateInit
    bcc :+
    jmp lst1Fail
:
    jsr listingCaptureInit
    bcc :+
    jmp lst1Fail
:
    lda #<$4000
    sta CasmPc
    lda #>$4000
    sta CasmPc + 1
    jsr listingBeginLine
    bcc :+
    jmp lst1Fail
:
    lda #0
    sta LoopLo
lst1FillLoop:
    lda LoopLo
    jsr listingMirrorByte
    bcc :+
    jmp lst1Fail
:
    inc LoopLo
    lda LoopLo
    cmp #63
    bne lst1FillLoop

    lda CasmListingStageLen
    cmp #63
    beq :+
    jmp lst1Fail
:
    lda #63
    jsr listingMirrorByte
    bcc :+
    jmp lst1Fail
:
    lda CasmListingStageLen
    beq :+
    jmp lst1Fail
:
    lda #99
    jsr listingMirrorByte
    bcc :+
    jmp lst1Fail
:
    lda CasmListingStageLen
    cmp #1
    beq :+
    jmp lst1Fail
:
    ldx CasmListingByteVmmSlot
    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    lda #64
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowRead
    bcc :+
    jmp lst1Fail
:
    ldy #0
lst1CheckLoop:
    tya
    cmp CasmVmmBuffer, y
    beq lst1CheckOk
    jmp lst1Fail
lst1CheckOk:
    iny
    cpy #64
    bne lst1CheckLoop

    lda #1
    sta StubHasPending
    lda #CASM_SOURCE_COMPLETED_FLAG_VALID
    sta CasmSourceCompletedFlags
    lda #0
    sta CasmSourceCompletedStartLo
    sta CasmSourceCompletedStartHi
    lda #5
    sta CasmSourceCompletedLength
    lda #0
    sta CasmSourceCompletedFileId
    lda #1
    sta CasmSourceCompletedLineLo
    lda #0
    sta CasmSourceCompletedLineHi
    jsr listingCommitLine
    bcc :+
    jmp lst1Fail
:
    ldx CasmListingMetaVmmSlot
    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    lda #16
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr vmmWindowRead
    bcc :+
    jmp lst1Fail
:
    lda CasmVmmBuffer + 10    ; ByteOff lo
    cmp #0
    beq :+
    jmp lst1Fail
:
    lda CasmVmmBuffer + 11    ; ByteOff hi
    cmp #0
    beq :+
    jmp lst1Fail
:
    lda CasmVmmBuffer + 12    ; ByteCount lo (65 bytes mirrored total)
    cmp #65
    beq :+
    jmp lst1Fail
:
    lda CasmVmmBuffer + 13    ; ByteCount hi
    cmp #0
    beq :+
    jmp lst1Fail
:
    ldx CasmListingMetaVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lst1Fail
:
    ldx CasmListingByteVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lst1Fail
:
    lda #CASM_LISTING_STATE_NONE
    sta CasmListingState
    clc
    rts
lst1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; listingfull2
; Fresh allocation. Mirrors exactly 65,535 bytes (confirming the store is
; NOT yet full), then one more (the 65,536th, confirming the store BECOMES
; full and the cursor wraps to exactly zero), then attempts a 65,537th
; (confirming it is rejected with CASM_DIAG_LISTING_BYTES_FULL before any
; mutation). A real fill, matching listingfull1's own precedent for the
; metadata store's capacity boundary.
; ---------------------------------------------------------------------------
listingfull2:
    jsr listingStateInit
    bcc :+
    jmp lf2Fail
:
    jsr listingCaptureInit
    bcc :+
    jmp lf2Fail
:
    lda #0
    sta CasmPc
    sta CasmPc + 1
    jsr listingBeginLine
    bcc :+
    jmp lf2Fail
:
    lda #0
    sta LoopLo
    sta LoopHi
lf2Loop:
    lda #$42
    jsr listingMirrorByte
    bcc lf2Continue
    jmp lf2Fail
lf2Continue:
    inc LoopLo
    bne lf2CheckDone
    inc LoopHi
lf2CheckDone:
    lda LoopLo
    cmp #<65535
    bne lf2Loop
    lda LoopHi
    cmp #>65535
    bne lf2Loop

    lda CasmListingByteFull
    beq :+
    jmp lf2Fail                  ; must not be full yet (65,535 written)
:
    lda #$99
    jsr listingMirrorByte
    bcc :+
    jmp lf2Fail
:
    lda CasmListingByteFull
    bne :+
    jmp lf2Fail                  ; must be full now (65,536th just written)
:
    lda CasmListingByteCursorLo
    ora CasmListingByteCursorHi
    beq :+
    jmp lf2Fail                  ; cursor must have wrapped to exactly zero
:
    lda #$77
    jsr listingMirrorByte
    bcs :+
    jmp lf2Fail                  ; the 65,537th byte must be rejected
:
    cmp #CASM_DIAG_LISTING_BYTES_FULL
    beq :+
    jmp lf2Fail
:
    ; Close the transaction. The true 65,536-byte delta does not fit this
    ; fixture's own ByteCount verification -- listingtxn1/listingstage1
    ; already prove the ordinary delta arithmetic; this fixture's own scope
    ; is the endpoint/full-flag behavior, not this one record's own count.
    lda #1
    sta StubHasPending
    lda #CASM_SOURCE_COMPLETED_FLAG_VALID
    sta CasmSourceCompletedFlags
    lda #0
    sta CasmSourceCompletedStartLo
    sta CasmSourceCompletedStartHi
    sta CasmSourceCompletedLength
    sta CasmSourceCompletedFileId
    lda #1
    sta CasmSourceCompletedLineLo
    lda #0
    sta CasmSourceCompletedLineHi
    jsr listingCommitLine
    bcc :+
    jmp lf2Fail
:
    ldx CasmListingMetaVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lf2Fail
:
    ldx CasmListingByteVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lf2Fail
:
    lda #CASM_LISTING_STATE_NONE
    sta CasmListingState
    clc
    rts
lf2Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; listingfinalize1
; Fresh allocation. Confirms listingCaptureFinalize's two precondition
; failures (an active transaction; an unconsumed sidecar) and its success
; path (flushes a final partial stage, disables source capture through the
; stub, and marks CasmListingState complete), then replays both recorded
; lines from the same allocation.
; ---------------------------------------------------------------------------
listingfinalize1:
    jsr listingStateInit
    bcc :+
    jmp lfi1Fail
:
    jsr listingCaptureInit
    bcc :+
    jmp lfi1Fail
:
    lda #0
    sta CasmPc
    sta CasmPc + 1
    jsr listingBeginLine
    bcc :+
    jmp lfi1Fail
:
    ; An active transaction must reject finalize.
    jsr listingCaptureFinalize
    bcs :+
    jmp lfi1Fail
:
    cmp #CASM_DIAG_LISTING_REPLAY_MISMATCH
    beq :+
    jmp lfi1Fail
:
    lda #1
    sta StubHasPending
    lda #CASM_SOURCE_COMPLETED_FLAG_VALID
    sta CasmSourceCompletedFlags
    lda #0
    sta CasmSourceCompletedStartLo
    sta CasmSourceCompletedStartHi
    sta CasmSourceCompletedLength
    sta CasmSourceCompletedFileId
    sta CasmSourceCompletedLineHi
    lda #1
    sta CasmSourceCompletedLineLo
    jsr listingCommitLine
    bcc :+
    jmp lfi1Fail
:
    ; An unconsumed sidecar (peeked directly, independent of the active-
    ; transaction check above, which the prior commit already cleared).
    lda #CASM_SOURCE_COMPLETED_FLAG_VALID
    sta CasmSourceCompletedFlags
    jsr listingCaptureFinalize
    bcs :+
    jmp lfi1Fail
:
    cmp #CASM_DIAG_LISTING_REPLAY_MISMATCH
    beq :+
    jmp lfi1Fail
:
    lda #0
    sta CasmSourceCompletedFlags

    ; Leave a partial (non-flushed) stage so finalize's own flush is real.
    jsr listingBeginLine
    bcc :+
    jmp lfi1Fail
:
    lda #$55
    jsr listingMirrorByte
    bcc :+
    jmp lfi1Fail
:
    lda #1
    sta StubHasPending
    lda #CASM_SOURCE_COMPLETED_FLAG_VALID
    sta CasmSourceCompletedFlags
    lda #0
    sta CasmSourceCompletedStartLo
    sta CasmSourceCompletedStartHi
    sta CasmSourceCompletedLength
    sta CasmSourceCompletedFileId
    sta CasmSourceCompletedLineHi
    lda #2
    sta CasmSourceCompletedLineLo
    jsr listingCommitLine
    bcc :+
    jmp lfi1Fail
:
    lda CasmListingStageLen
    cmp #1
    beq :+
    jmp lfi1Fail
:
    jsr listingCaptureFinalize
    bcc :+
    jmp lfi1Fail
:
    lda CasmListingStageLen
    beq :+
    jmp lfi1Fail                 ; finalize must flush the trailing partial stage
:
    lda CasmListingState
    cmp #CASM_LISTING_STATE_COMPLETE
    beq :+
    jmp lfi1Fail
:
    jsr listingReplayReset
    bcc :+
    jmp lfi1Fail
:
    jsr listingReplayNext
    bcc :+
    jmp lfi1Fail
:
    cmp #CASM_STREAM_DATA
    beq :+
    jmp lfi1Fail
:
    jsr listingReplayNext
    bcc :+
    jmp lfi1Fail
:
    cmp #CASM_STREAM_DATA
    beq :+
    jmp lfi1Fail
:
    jsr listingReplayNext
    bcc :+
    jmp lfi1Fail
:
    cmp #CASM_STREAM_EOF
    beq :+
    jmp lfi1Fail
:
    ldx CasmListingMetaVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lfi1Fail
:
    ldx CasmListingByteVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp lfi1Fail
:
    lda #CASM_LISTING_STATE_NONE
    sta CasmListingState
    clc
    rts
lfi1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; diagPrintFatal (stub)
; resources.s's exitSuccess/exitFatal reference this; this harness never
; calls either, so a trivial stub satisfies the link without pulling in the
; real diagnostics.s (and transitively lexer.s/source.s). See the file
; header for the full rationale.
; ---------------------------------------------------------------------------
diagPrintFatal:
    rts

; ---------------------------------------------------------------------------
; sourceSetLineCapture (stub)
; listing.s's listingCaptureInit calls this; this harness never links the
; real source.s (see the file header), and does not care whether source-side
; capture actually enables anything -- only that listingCaptureInit's own
; VMM allocation/state-transition sequencing is correct.
; ---------------------------------------------------------------------------
sourceSetLineCapture:
    clc
    rts

; ---------------------------------------------------------------------------
; sourceTakeCompletedLine (stub, WP51 increment 4)
; listing.s's listingCommitLine/listingCaptureFinalize call this; this
; harness never links the real source.s (see the file header). Test-
; controlled: a fixture sets StubHasPending and CasmSourceCompletedFlags/
; StartLo/Hi/Length/FileId/LineLo/Hi directly before calling the routine
; under test, matching the real ABI's "fields remain readable after this
; call" contract exactly (they are plain exported BSS here, already holding
; whatever the fixture staged). Consumes StubHasPending (clears it) so a
; second call in the same fixture correctly reports "no pending" without
; needing the real VALID-bit state machine this stub does not implement.
; ---------------------------------------------------------------------------
sourceTakeCompletedLine:
    lda StubHasPending
    beq stclStubNone
    lda #0
    sta StubHasPending
    lda CasmSourceCompletedFlags
    pha
    lda #0
    sta CasmSourceCompletedFlags  ; consuming clears VALID, matching the real
                                  ; source.s contract listingCaptureFinalize's
                                  ; own direct peek relies on
    pla
    clc
    rts
stclStubNone:
    lda #0
    clc
    rts

.segment "RODATA"

passMsg:
    .byte "CASM LISTING: PASS", PetCr, 0
failMsg:
    .byte "CASM LISTING: FAIL", PetCr, 0

.segment "BSS"

FailCount: .res 1
LoopLo:    .res 1
StubHasPending: .res 1
CasmPc: .res 2
CasmSourceCompletedFlags:   .res 1
CasmSourceCompletedStartLo: .res 1
CasmSourceCompletedStartHi: .res 1
CasmSourceCompletedLength:  .res 1
CasmSourceCompletedFileId:  .res 1
CasmSourceCompletedLineLo:  .res 1
CasmSourceCompletedLineHi:  .res 1
LoopHi:    .res 1
SlotCount: .res 1
SlotTable: .res 8
SavedMetaSlot: .res 1
SavedByteSlot: .res 1
