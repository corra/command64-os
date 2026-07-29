; tests/src/casm_event/casm_event.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 9 WP47 include-event log harness. Drives include.s's
; new event ABI -- includeEventRecord, includeEventReplay,
; includeReplayReset, includeReplayFinalCheck -- directly, with synthetic
; event tuples staged into CasmIncludeEventStage.
;
; Deliberately uses NO fixture files at all, unlike test_casm_catalog
; (WP45) and test_casm_frame (WP46). The event log is pure metadata: an
; event never carries source bytes, and Pass 2 re-reads a child's span from
; the catalog rather than from the event, so every property this harness
; proves (ordering, per-field correspondence, capacity, cursor discipline)
; is exercisable without a single byte of real source. That also keeps
; casm_overflow_test.d64's directory-entry budget untouched by this WP's
; unit-level coverage -- only the end-to-end .INCLUDE fixtures need disk
; entries.
;
; Links include.s plus every module it transitively needs (source.s for
; sourceAppendFile, and in turn fileio.s/state.s, plus resources.s and
; vmm_store.s). Mirrors casm_catalog.s's own precedent exactly: it declares
; its own stand-in CasmSourceNames/CasmSourceCount/cliSourceSlotLo/Hi rather
; than linking cli.s's whole CLI-parsing dependency chain, since source.s
; references those globals and ld65 links whole object files. sourceLoad is
; never called here (no fixtures), so those stand-ins exist purely to
; satisfy the linker.
;
; No CurrentDevice capture is needed (again unlike WP45/WP46's harnesses):
; nothing here opens a file, so the two-drive test setup is irrelevant to
; this harness's correctness.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_event.inc"

.import __MAIN_START__
.import resourcesInit
.import includeCatalogInit
.import includeEventRecord
.import includeEventReplay
.import includeReplayReset
.import includeReplayFinalCheck
.import CasmIncludeEventStage
.import CasmIncludeEventCount
.import CasmIncludeEventCursor
.import CasmIncludeMetaSlot
.import vmmWindowRead
.import CasmVmmBuffer

.export CasmSourceNames  ; this harness's own copy -- NOT linking cli.s, see header
.export CasmSourceLens   ; unused; declared so any cli-shaped reference resolves
.export CasmSourceCount  ; this harness's own copy -- never set (sourceLoad unused)
.export cliSourceSlotLo  ; this harness's own single-entry copy
.export cliSourceSlotHi
.export CasmOutputName   ; fileio.s's outputAbort references this by name
.export diagPrintFatal   ; stub -- see routine below; not linking diagnostics.s

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

    jsr includeCatalogInit
    bcc initOk
    jmp seedFailed

initOk:
    jsr evinit1
    jsr reportCase
    jsr evrecord1
    jsr reportCase
    jsr evstored1
    jsr reportCase
    jsr evreplay1
    jsr reportCase
    jsr evexhaust1
    jsr reportCase
    jsr evfinal1
    jsr reportCase
    jsr evorder1
    jsr reportCase
    jsr evfinal2
    jsr reportCase
    jsr evmismatch1
    jsr reportCase
    jsr evmismatch2
    jsr reportCase
    jsr evmismatch3
    jsr reportCase
    jsr evmismatch4
    jsr reportCase
    jsr evmismatch5
    jsr reportCase
    jsr evmismatch6
    jsr reportCase
    jsr evfull1
    jsr reportCase

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

seedFailed:
    lda #<seedFailMsg
    ldy #>seedFailMsg
    tax
    lda #DOS_PRINT_STR
    jsr OS_API
    lda #DOS_EXIT
    jsr OS_API

; ---------------------------------------------------------------------------
; reportCase
; Print '.' for a pass (carry clear) or 'F' for a fail (carry set), tallying
; FailCount. Matches casm_catalog.s/casm_frame.s's own reporting convention.
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
; stageEvent
; Stage one candidate/record tuple into CasmIncludeEventStage from this
; harness's own StageKind/StageId/StageLineLo/StageLineHi/StageColumn/
; StageChild scratch. Every case below sets those six, then calls this --
; keeping the field-offset writes in exactly one place.
;
; Deliberately does NOT clear the reserved tail: proving that
; includeEventRecord zero-fills it itself (evstored1) requires this harness
; to leave it dirty. StageDirty below is written into the tail before the
; first record call for exactly that reason.
; ---------------------------------------------------------------------------
stageEvent:
    lda StageKind
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_KIND
    lda StageId
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_ID
    lda StageLineLo
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_LINE_LO
    lda StageLineHi
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_LINE_HI
    lda StageColumn
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_COLUMN
    lda StageChild
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_CHILD_INDEX
    rts

; ---------------------------------------------------------------------------
; readEventRaw
; Read the raw stored event at index A into CasmVmmBuffer, so a case can
; inspect exactly what was persisted (including the reserved tail).
; Recomputes the offset from the public common.inc constants rather than
; calling include.s's private includeEventOffset -- an independent
; derivation, so a defect in that private helper cannot hide behind this
; harness agreeing with it.
;
; Inputs:  A = event index
; Outputs: C clear with CasmVmmBuffer holding the 16 stored bytes
; ---------------------------------------------------------------------------
readEventRaw:
    sta CasmVmmOffLo
    lda #0
    sta CasmVmmOffHi
    ldx #4                       ; * CASM_INCLUDE_EVENT_SIZE (16)
rerShift:
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    dex
    bne rerShift
    lda CasmVmmOffLo
    clc
    adc #<CASM_INCLUDE_EVENT_BASE
    sta CasmVmmOffLo
    lda CasmVmmOffHi
    adc #>CASM_INCLUDE_EVENT_BASE
    sta CasmVmmOffHi
    lda #CASM_INCLUDE_EVENT_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmIncludeMetaSlot
    jmp vmmWindowRead

; ---------------------------------------------------------------------------
; evinit1: includeCatalogInit already ran in start; confirm the event log
; starts empty with its replay cursor rewound. Proves WP47 extended that one
; init call rather than adding a second one callers must remember.
;
; Every check below uses its own local "sec/rts" fail tail immediately after
; its routine's success path (matching casm_catalog.s/casm_frame.s), rather
; than one shared distant fail label -- keeps every branch immune to the
; 6502's +/-127-byte range limit however many checks a routine accumulates.
; ---------------------------------------------------------------------------
evinit1:
    lda CasmIncludeEventCount
    bne ei1Fail
    lda CasmIncludeEventCursor
    bne ei1Fail
    clc
    rts
ei1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; evrecord1: append one event (root parent 0, line $0103, column 5, child
; 7). Expect success and CasmIncludeEventCount = 1.
; ---------------------------------------------------------------------------
evrecord1:
    ; Dirty the reserved tail first, so evstored1 below genuinely proves
    ; includeEventRecord zero-fills it rather than merely inheriting zeros.
    lda #$AA
    ldy #CASM_INCLUDE_EVENT_CHILD_INDEX + 1
er1DirtyLoop:
    cpy #CASM_INCLUDE_EVENT_SIZE
    bcs er1DirtyDone
    sta CasmIncludeEventStage, y
    iny
    jmp er1DirtyLoop
er1DirtyDone:

    lda #CASM_INCLUDE_EVENT_PARENT_KIND_ROOT
    sta StageKind
    lda #0
    sta StageId
    lda #$03
    sta StageLineLo
    lda #$01
    sta StageLineHi
    lda #5
    sta StageColumn
    lda #7
    sta StageChild
    jsr stageEvent
    jsr includeEventRecord
    bcs er1Fail
    lda CasmIncludeEventCount
    cmp #1
    bne er1Fail
    ; Recording is a Pass 1 activity and must never disturb the replay
    ; cursor.
    lda CasmIncludeEventCursor
    bne er1Fail
    clc
    rts
er1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; evstored1: read event 0 back raw and confirm every meaningful field
; round-tripped exactly, and that the reserved tail was stored as zero
; despite evrecord1 deliberately dirtying it with $AA.
; ---------------------------------------------------------------------------
evstored1:
    lda #0
    jsr readEventRaw
    bcs es1Fail
    lda CasmVmmBuffer + CASM_INCLUDE_EVENT_PARENT_KIND
    cmp #CASM_INCLUDE_EVENT_PARENT_KIND_ROOT
    bne es1Fail
    lda CasmVmmBuffer + CASM_INCLUDE_EVENT_PARENT_ID
    bne es1Fail
    lda CasmVmmBuffer + CASM_INCLUDE_EVENT_PARENT_LINE_LO
    cmp #$03
    bne es1Fail
    lda CasmVmmBuffer + CASM_INCLUDE_EVENT_PARENT_LINE_HI
    cmp #$01
    bne es1Fail
    lda CasmVmmBuffer + CASM_INCLUDE_EVENT_PARENT_COLUMN
    cmp #5
    bne es1Fail
    lda CasmVmmBuffer + CASM_INCLUDE_EVENT_CHILD_INDEX
    cmp #7
    bne es1Fail
    ; Reserved tail must be zero-filled by includeEventRecord itself.
    ldy #CASM_INCLUDE_EVENT_CHILD_INDEX + 1
es1TailLoop:
    cpy #CASM_INCLUDE_EVENT_SIZE
    bcs es1TailDone
    lda CasmVmmBuffer, y
    bne es1Fail
    iny
    jmp es1TailLoop
es1TailDone:
    clc
    rts
es1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; evreplay1: rewind the cursor and replay the one recorded event with a
; matching candidate tuple. Expect success and the cursor advanced to 1,
; with CasmIncludeEventCount deliberately unchanged (includeReplayReset must
; not clear the count -- Pass 2 needs it to know how many events to expect).
; ---------------------------------------------------------------------------
evreplay1:
    jsr includeReplayReset
    lda CasmIncludeEventCursor
    bne erp1Fail
    lda CasmIncludeEventCount
    cmp #1
    bne erp1Fail

    lda #CASM_INCLUDE_EVENT_PARENT_KIND_ROOT
    sta StageKind
    lda #0
    sta StageId
    lda #$03
    sta StageLineLo
    lda #$01
    sta StageLineHi
    lda #5
    sta StageColumn
    lda #7
    sta StageChild
    jsr stageEvent
    jsr includeEventReplay
    bcs erp1Fail
    lda CasmIncludeEventCursor
    cmp #1
    bne erp1Fail
    clc
    rts
erp1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; evexhaust1: a further replay with the cursor already at the count is an
; *extra* .INCLUDE Pass 1 never recorded -- a mismatch, not a quiet end
; condition. The cursor must not advance past the count.
; ---------------------------------------------------------------------------
evexhaust1:
    jsr includeEventReplay
    bcc ex1Fail                  ; must fail
    cmp #CASM_DIAG_INCLUDE_REPLAY_MISMATCH
    bne ex1Fail
    lda CasmIncludeEventCursor
    cmp #1
    bne ex1Fail
    clc
    rts
ex1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; evfinal1: with every recorded event consumed, the end-of-Pass-2 check
; passes.
; ---------------------------------------------------------------------------
evfinal1:
    jsr includeReplayFinalCheck
    bcs ef1Fail
    clc
    rts
ef1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; evorder1: append two more events (total 3), rewind, and replay all three
; in order. Then prove ordering is genuinely enforced: rewind again and
; replay event 0's tuple where event 1 is expected, which must be rejected.
; ---------------------------------------------------------------------------
evorder1:
    ; Event 1: nested-frame parent, catalog index 7, line 2, column 1,
    ; child 9.
    lda #CASM_INCLUDE_EVENT_PARENT_KIND_FRAME
    sta StageKind
    lda #7
    sta StageId
    lda #2
    sta StageLineLo
    lda #0
    sta StageLineHi
    lda #1
    sta StageColumn
    lda #9
    sta StageChild
    jsr stageEvent
    jsr includeEventRecord
    bcs eo1Fail

    ; Event 2: root parent 1 (a different top-level file), line 40,
    ; column 9, child 7 again (a legal repeat include of an already
    ; cataloged file).
    lda #CASM_INCLUDE_EVENT_PARENT_KIND_ROOT
    sta StageKind
    lda #1
    sta StageId
    lda #40
    sta StageLineLo
    lda #0
    sta StageLineHi
    lda #9
    sta StageColumn
    lda #7
    sta StageChild
    jsr stageEvent
    jsr includeEventRecord
    bcs eo1Fail

    lda CasmIncludeEventCount
    cmp #3
    bne eo1Fail

    ; Replay all three in recorded order.
    jsr includeReplayReset
    jsr stageEvent0
    jsr includeEventReplay
    bcs eo1Fail
    jsr stageEvent1
    jsr includeEventReplay
    bcs eo1Fail
    jsr stageEvent2
    jsr includeEventReplay
    bcs eo1Fail
    lda CasmIncludeEventCursor
    cmp #3
    bne eo1Fail

    ; Ordering is enforced: after a rewind, event 0's own tuple matches at
    ; position 0, but presenting it again at position 1 must be rejected.
    jsr includeReplayReset
    jsr stageEvent0
    jsr includeEventReplay
    bcs eo1Fail
    jsr stageEvent0
    jsr includeEventReplay
    bcc eo1Fail                  ; must fail: event 1 is not event 0
    cmp #CASM_DIAG_INCLUDE_REPLAY_MISMATCH
    bne eo1Fail
    lda CasmIncludeEventCursor
    cmp #1                       ; not advanced by the rejected compare
    bne eo1Fail
    clc
    rts
eo1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; evfinal2: the cursor now sits at 1 of 3 consumed events. The end-of-pass
; check must reject that -- this is the "missing trailing event" case the
; per-site correspondence check structurally cannot catch, since a replay
; that simply stops early never performs a disagreeing comparison.
; ---------------------------------------------------------------------------
evfinal2:
    jsr includeReplayFinalCheck
    bcc ef2Fail                  ; must fail
    cmp #CASM_DIAG_INCLUDE_REPLAY_MISMATCH
    bne ef2Fail
    clc
    rts
ef2Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; stageEvent0/1/2: restage the exact tuples evrecord1/evorder1 recorded, so
; the mismatch cases below can perturb exactly one field at a time from a
; known-good baseline.
; ---------------------------------------------------------------------------
stageEvent0:
    lda #CASM_INCLUDE_EVENT_PARENT_KIND_ROOT
    sta StageKind
    lda #0
    sta StageId
    lda #$03
    sta StageLineLo
    lda #$01
    sta StageLineHi
    lda #5
    sta StageColumn
    lda #7
    sta StageChild
    jmp stageEvent

stageEvent1:
    lda #CASM_INCLUDE_EVENT_PARENT_KIND_FRAME
    sta StageKind
    lda #7
    sta StageId
    lda #2
    sta StageLineLo
    lda #0
    sta StageLineHi
    lda #1
    sta StageColumn
    lda #9
    sta StageChild
    jmp stageEvent

stageEvent2:
    lda #CASM_INCLUDE_EVENT_PARENT_KIND_ROOT
    sta StageKind
    lda #1
    sta StageId
    lda #40
    sta StageLineLo
    lda #0
    sta StageLineHi
    lda #9
    sta StageColumn
    lda #7
    sta StageChild
    jmp stageEvent

; ---------------------------------------------------------------------------
; checkMismatch
; Shared body for the six single-field mismatch cases: rewind, stage
; event 0's known-good tuple, apply the caller's one-field perturbation
; (already written into the Stage* scratch by the caller), and require
; includeEventReplay to reject it without advancing the cursor.
;
; Inputs:  the Stage* scratch already perturbed in exactly one field
; Outputs: C clear when the mismatch was correctly rejected
; ---------------------------------------------------------------------------
checkMismatch:
    jsr stageEvent
    jsr includeEventReplay
    bcc cmFail                   ; must fail
    cmp #CASM_DIAG_INCLUDE_REPLAY_MISMATCH
    bne cmFail
    lda CasmIncludeEventCursor
    bne cmFail                   ; rewound to 0 by the caller; must not advance
    clc
    rts
cmFail:
    sec
    rts

; ---------------------------------------------------------------------------
; evmismatch1-6: each perturbs exactly one field of event 0's tuple and
; requires rejection. Proves every field genuinely participates in the
; correspondence check -- a field silently omitted from the comparison loop
; would let one of these pass.
;
; evmismatch1 is the case the parent-kind tag exists for: a nested-frame
; parent with catalog index 0 must NOT compare equal to top-level root 0,
; even though both carry id 0.
; ---------------------------------------------------------------------------
evmismatch1:
    jsr includeReplayReset
    jsr stageEvent0
    lda #CASM_INCLUDE_EVENT_PARENT_KIND_FRAME
    sta StageKind
    jmp checkMismatch

evmismatch2:
    jsr includeReplayReset
    jsr stageEvent0
    lda #1
    sta StageId
    jmp checkMismatch

evmismatch3:
    jsr includeReplayReset
    jsr stageEvent0
    lda #$04
    sta StageLineLo
    jmp checkMismatch

evmismatch4:
    jsr includeReplayReset
    jsr stageEvent0
    lda #$02
    sta StageLineHi
    jmp checkMismatch

evmismatch5:
    jsr includeReplayReset
    jsr stageEvent0
    lda #6
    sta StageColumn
    jmp checkMismatch

evmismatch6:
    jsr includeReplayReset
    jsr stageEvent0
    lda #8
    sta StageChild
    jmp checkMismatch

; ---------------------------------------------------------------------------
; evfull1: fill the log to its 128-event capacity and confirm the 129th
; append is rejected with CASM_DIAG_INCLUDE_EVENT_LOG_FULL, leaving the
; count unchanged (the capacity check runs before any write).
;
; Three events already exist, so 125 more reach the cap exactly. The
; boundary is checked from both sides: the 128th must still succeed.
; ---------------------------------------------------------------------------
evfull1:
    jsr stageEvent0              ; content is irrelevant to a capacity test
evf1FillLoop:
    lda CasmIncludeEventCount
    cmp #CASM_INCLUDE_EVENT_CAPACITY
    bcs evf1AtCap
    jsr includeEventRecord
    bcs evf1Fail                 ; every append below the cap must succeed
    jmp evf1FillLoop
evf1AtCap:
    lda CasmIncludeEventCount
    cmp #CASM_INCLUDE_EVENT_CAPACITY
    bne evf1Fail
    jsr includeEventRecord
    bcc evf1Fail                 ; the 129th must fail
    cmp #CASM_DIAG_INCLUDE_EVENT_LOG_FULL
    bne evf1Fail
    lda CasmIncludeEventCount
    cmp #CASM_INCLUDE_EVENT_CAPACITY
    bne evf1Fail                 ; count untouched by the rejected append
    clc
    rts
evf1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; diagPrintFatal stub
; This harness does not link diagnostics.s (it never renders a message), but
; fileio.s/source.s reference diagPrintFatal by name. Matches
; casm_catalog.s's own stub precedent.
; ---------------------------------------------------------------------------
diagPrintFatal:
    rts

.segment "BSS"

FailCount:   .res 1

StageKind:   .res 1
StageId:     .res 1
StageLineLo: .res 1
StageLineHi: .res 1
StageColumn: .res 1
StageChild:  .res 1

; Stand-ins for cli.s's globals -- see header. sourceLoad is never called by
; this harness, so these are only ever read by code that never runs.
CasmSourceNames: .res CASM_FILENAME_BUFFER_SIZE
CasmSourceLens:  .res 1
CasmSourceCount: .res 1
CasmOutputName:  .res CASM_FILENAME_BUFFER_SIZE

.segment "RODATA"

cliSourceSlotLo:
    .byte <CasmSourceNames
cliSourceSlotHi:
    .byte >CasmSourceNames

passMsg:
    .byte "CASM EVENT TESTS PASS", PetCr, 0
failMsg:
    .byte "CASM EVENT TESTS FAIL", PetCr, 0
seedFailMsg:
    .byte "CASM EVENT SEED FAILED", PetCr, 0
