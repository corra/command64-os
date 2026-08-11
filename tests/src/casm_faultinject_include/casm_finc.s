; tests/src/casm_faultinject_include/casm_finc.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 11 WP58 Increment 4 include.s fault-injection fixture. Links
; the real include.s/vmm_store.s/resources.s against the shared runtime
; OS_API fault hook (faultstub.inc). Deliberately does NOT link source.s/
; fileio.s: every case below exercises include.s's own directly-exported VMM
; entry points (includeCatalogInit, includeCatalogRead, includeEventRecord,
; includeEventReplay) rather than includeCatalogLoad's on-miss path, which
; needs a real sourceAppendFile call and would otherwise pull in the same
; heavy source.s/fileio.s/state.s/diagnostics.s chain casm_faultsource.s
; already links. includeCatalogLoad/includeCatalogWrite's own fault coverage
; is deliberately deferred (matching WP58 Increment 1's own precedent of
; recording an explicit deferral rather than solving it speculatively here):
; includeCatalogWrite is private (not exported) and only reachable through
; includeCatalogLoad's miss branch, so covering it would require the full
; heavy link set for marginal additional VMM-path coverage over
; includeCatalogRead/includeEventRecord's already-proven write/read shapes.
; sourceAppendFile is therefore only a trivial link-satisfying stub here,
; never actually called.
;
; include.s makes five OS_API-reachable calls through vmm_store.s (traced in
; the WP58 plan): includeCatalogInit's one vmmStoreAlloc, includeCatalogRead's
; two vmmWindowRead calls (one per 64-byte transfer window), includeCatalogWrite's
; two vmmWindowWrite calls (deferred, see above), includeEventRecord's one
; vmmWindowWrite, and includeEventReplay's one vmmWindowRead. Each case below
; forces one directly-exercisable call to fail and asserts the propagated
; diagnostic plus the state-consistency invariant include.s's own header/
; routine comments document for that call site:
;   - allocFailureLeavesNoOwner: CasmVmmCount stays 0 -- same invariant as
;     symbols.s/reloc.s's own alloc-init cases.
;   - catalogReadFailurePropagates: includeCatalogRead's first transfer
;     window failing must propagate CASM_DIAG_VMM_TRANSFER_FAILED directly
;     (icrFail), without touching CasmIncludeRecordStage's second half.
;   - eventRecordWriteFailureLeavesCountUnchanged: includeEventRecord's own
;     comment ("the capacity check runs before any write, so a rejected
;     append leaves the log and CasmIncludeEventCount untouched") is proven
;     directly: CasmIncludeEventCount is exported, so the failed attempt's
;     effect (none) is read back directly rather than inferred indirectly.
;   - eventReplayReadFailureLeavesCursorUnchanged: includeEventReplay's own
;     comment ("the cursor is not advanced on any failure") is proven the
;     same direct way via the exported CasmIncludeEventCursor.
;
; Stubs diagPrintFatal locally for the same reason casm_catalog.s does:
; resources.s's exitSuccess/exitFatal reference it, and ld65 links whole
; object files, so importing resourcesInit alone would otherwise drag in
; diagnostics.s's transitive lexer.s/source.s dependencies.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_finc.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import includeCatalogInit
.import includeCatalogRead
.import includeEventRecord
.import includeEventReplay
.import CasmIncludeEventCount
.import CasmIncludeEventCursor
.import CasmIncludeEventStage
.import CasmVmmCount

.export diagPrintFatal
.export sourceAppendFile

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
    jsr faultInstall

    jsr allocFailureLeavesNoOwner
    jsr reportCase
    jsr catalogReadFailurePropagates
    jsr reportCase
    jsr eventRecordWriteFailureLeavesCountUnchanged
    jsr reportCase
    jsr eventReplayReadFailureLeavesCursorUnchanged
    jsr reportCase

    jsr resourcesCleanup

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
    lda #DOS_PRINT_STR
    jsr OS_API
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

resetFaultDescriptor:
    lda #0
    sta FaultArmed
    sta FaultReturnA
    sta FaultReturnSuccess
    sta FaultSetCount
    sta FaultReturnCountLo
    sta FaultReturnCountHi
    rts

armNextCall:
    sta FaultFuncCode
    lda #1
    sta FaultCountdown
    sta FaultArmed
    rts

disarm:
    lda #0
    sta FaultArmed
    rts

; ---------------------------------------------------------------------------
; allocFailureLeavesNoOwner
; Fault DOS_ALLOC_MEM before the very first includeCatalogInit in this run.
; Assert the propagated diagnostic and that CasmVmmCount stays at 0, then
; retry for real so every later case runs against a live metadata store.
; ---------------------------------------------------------------------------
allocFailureLeavesNoOwner:
    jsr resetFaultDescriptor
    lda #VMM_ERR_NOMEM
    sta FaultReturnA
    lda #DOS_ALLOC_MEM
    jsr armNextCall
    jsr includeCatalogInit
    bcc aflFail
    cmp #CASM_DIAG_VMM_ALLOC_FAILED
    bne aflFail
    lda CasmVmmCount
    bne aflFail
    jsr disarm
    jsr includeCatalogInit
    bcs aflFail
    clc
    rts
aflFail:
    jsr disarm
    sec
    rts

; ---------------------------------------------------------------------------
; catalogReadFailurePropagates
; Fault DOS_VMM_READ, then call includeCatalogRead for record index 0 (valid
; VMM address regardless of catalog population -- a raw indexed accessor).
; Assert the propagated diagnostic, then confirm a real read of the same
; index afterward succeeds normally.
; ---------------------------------------------------------------------------
catalogReadFailurePropagates:
    lda #DOS_VMM_READ
    jsr armNextCall

    lda #0
    jsr includeCatalogRead
    bcc crfFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne crfFail
    jsr disarm

    lda #0
    jsr includeCatalogRead
    bcs crfFail
    clc
    rts
crfFail:
    jsr disarm
    sec
    rts

; ---------------------------------------------------------------------------
; eventRecordWriteFailureLeavesCountUnchanged
; Stage a candidate event tuple, fault DOS_VMM_WRITE, and call
; includeEventRecord. Assert the propagated diagnostic and that
; CasmIncludeEventCount (exported) stays at 0, then retry for real and
; confirm it becomes 1.
; ---------------------------------------------------------------------------
eventRecordWriteFailureLeavesCountUnchanged:
    jsr stageEventTuple

    lda #DOS_VMM_WRITE
    jsr armNextCall
    jsr includeEventRecord
    bcc erwFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne erwFail
    lda CasmIncludeEventCount
    bne erwFail
    jsr disarm

    jsr stageEventTuple
    jsr includeEventRecord
    bcs erwFail
    lda CasmIncludeEventCount
    cmp #1
    bne erwFail
    clc
    rts
erwFail:
    jsr disarm
    sec
    rts

; ---------------------------------------------------------------------------
; eventReplayReadFailureLeavesCursorUnchanged
; The event log already holds exactly one real event (from
; eventRecordWriteFailureLeavesCountUnchanged), cursor at 0. Fault
; DOS_VMM_READ, stage the SAME candidate tuple, and call includeEventReplay.
; Assert the propagated diagnostic and that CasmIncludeEventCursor
; (exported) stays at 0, then retry for real and confirm it becomes 1.
; ---------------------------------------------------------------------------
eventReplayReadFailureLeavesCursorUnchanged:
    jsr stageEventTuple

    lda #DOS_VMM_READ
    jsr armNextCall
    jsr includeEventReplay
    bcc errFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne errFail
    lda CasmIncludeEventCursor
    bne errFail
    jsr disarm

    jsr stageEventTuple
    jsr includeEventReplay
    bcs errFail
    lda CasmIncludeEventCursor
    cmp #1
    bne errFail
    clc
    rts
errFail:
    jsr disarm
    sec
    rts

; ---------------------------------------------------------------------------
; stageEventTuple
; Populate CasmIncludeEventStage's six meaningful fields with a fixed
; candidate tuple, shared by every event-log case above (the same tuple
; both records and later replays, matching includeEventReplay's own
; "re-derived candidate" contract).
; ---------------------------------------------------------------------------
stageEventTuple:
    lda #CASM_INCLUDE_EVENT_PARENT_KIND_ROOT
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_KIND
    lda #0
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_ID
    lda #7
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_LINE_LO
    lda #0
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_LINE_HI
    lda #3
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_COLUMN
    lda #0
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_CHILD_INDEX
    rts

; ---------------------------------------------------------------------------
; diagPrintFatal (stub)
; See file header.
; ---------------------------------------------------------------------------
diagPrintFatal:
    rts

; ---------------------------------------------------------------------------
; sourceAppendFile (stub)
; Never reached: this harness deliberately never calls includeCatalogLoad
; (see file header). Trivial link-satisfying stub only.
; ---------------------------------------------------------------------------
sourceAppendFile:
    clc
    rts

.include "../casm_faultinject/faultstub.inc"

.segment "RODATA"

passMsg: .byte "CASM FAULT INCLUDE: PASS", PetCr, 0
failMsg: .byte "CASM FAULT INCLUDE: FAIL", PetCr, 0

.segment "BSS"

FailCount: .res 1
