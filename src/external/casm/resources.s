; src/external/casm/resources.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM central resource ownership and terminal paths. Phase 1 owns no live OS
; resources; cleanup records are nevertheless fully bounded and repeat-safe.
; The private close/free helpers are explicit stubs until the file-service and
; VMM phases introduce real acquisitions.

.include "command64.inc"
.include "common.inc"

.import diagPrintFatal

.export resourcesInit
.export resourceRegisterHandle
.export resourceReleaseHandle
.export resourceRegisterVmm
.export resourceReleaseVmm
.export resourcesCleanup
.export exitSuccess
.export exitFatal

.export CasmPhase
.export CasmLastDiag
.export CasmCleanupGuard
.export CasmFileCount
.export CasmVmmCount

.segment "BSS"

CasmPhase:         .res 1
CasmLastDiag:      .res 1
CasmCleanupGuard:  .res 1
CasmFileCount:     .res 1
CasmVmmCount:      .res 1
CasmFileRegistry:  .res CASM_FILE_REGISTRY_BYTES
CasmVmmRegistry:   .res CASM_VMM_REGISTRY_BYTES

.segment "CODE"

; ---------------------------------------------------------------------------
; resourcesInit
; Initialize all ownership and status state.
;
; Inputs:  none
; Outputs: C clear, A = CASM_DIAG_NONE
; Clobbers: A, X
; ---------------------------------------------------------------------------
resourcesInit:
    lda #CASM_PHASE_SCAFFOLD
    sta CasmPhase
    lda #CASM_DIAG_NONE
    sta CasmLastDiag
    sta CasmCleanupGuard
    sta CasmFileCount
    sta CasmVmmCount

    ldx #0
riFileLoop:
    lda #CASM_RESOURCE_FREE
    sta CasmFileRegistry + CASM_FILE_REC_FLAG, x
    lda #CASM_INVALID_HANDLE
    sta CasmFileRegistry + CASM_FILE_REC_HANDLE, x
    inx
    inx
    cpx #CASM_FILE_REGISTRY_BYTES
    bcc riFileLoop

    ldx #0
riVmmLoop:
    lda #CASM_RESOURCE_FREE
    sta CasmVmmRegistry + CASM_VMM_REC_FLAG, x
    sta CasmVmmRegistry + CASM_VMM_REC_SEGHI, x
    sta CasmVmmRegistry + CASM_VMM_REC_BANK, x
    txa
    clc
    adc #CASM_VMM_REC_SIZE
    tax
    cpx #CASM_VMM_REGISTRY_BYTES
    bcc riVmmLoop

    lda #CASM_DIAG_NONE
    clc
    rts

; ---------------------------------------------------------------------------
; resourceRegisterHandle
; Register ownership immediately after a successful DOS_OPEN_FILE.
;
; Inputs:  A = Command 64 file handle
; Outputs: C clear and X = slot (0..7) on success
;          C set and A = CASM_DIAG_REGISTRY_FULL on failure
; Clobbers: A, X, Y, CasmValue0Lo
; ---------------------------------------------------------------------------
resourceRegisterHandle:
    sta CasmValue0Lo
    ldx #0
    ldy #0
rrhFind:
    lda CasmFileRegistry + CASM_FILE_REC_FLAG, y
    beq rrhFound
    iny
    iny
    inx
    cpx #CASM_FILE_CAPACITY
    bcc rrhFind
    lda #CASM_DIAG_REGISTRY_FULL
    sta CasmLastDiag
    sec
    rts
rrhFound:
    lda #CASM_RESOURCE_OWNED
    sta CasmFileRegistry + CASM_FILE_REC_FLAG, y
    lda CasmValue0Lo
    sta CasmFileRegistry + CASM_FILE_REC_HANDLE, y
    inc CasmFileCount
    lda #CASM_DIAG_NONE
    clc
    rts

; ---------------------------------------------------------------------------
; resourceReleaseHandle
; Remove a handle from the ownership registry after it has been closed.
;
; Inputs:  X = slot returned by resourceRegisterHandle
; Outputs: C clear, A = CASM_DIAG_NONE for an owned or already-free slot
;          C set, A = CASM_DIAG_UNKNOWN for an out-of-range slot
; Clobbers: A, Y
; ---------------------------------------------------------------------------
resourceReleaseHandle:
    cpx #CASM_FILE_CAPACITY
    bcs rrhBadSlot
    txa
    asl
    tay
    lda CasmFileRegistry + CASM_FILE_REC_FLAG, y
    beq rrhReleased
    lda #CASM_RESOURCE_FREE
    sta CasmFileRegistry + CASM_FILE_REC_FLAG, y
    lda #CASM_INVALID_HANDLE
    sta CasmFileRegistry + CASM_FILE_REC_HANDLE, y
    lda CasmFileCount
    beq rrhReleased
    dec CasmFileCount
rrhReleased:
    lda #CASM_DIAG_NONE
    clc
    rts
rrhBadSlot:
    lda #CASM_DIAG_UNKNOWN
    sta CasmLastDiag
    sec
    rts

; ---------------------------------------------------------------------------
; resourceRegisterVmm
; Register ownership immediately after a successful DOS_ALLOC_MEM.
;
; Inputs:  X = segment high byte, Y = REU bank returned by DOS_ALLOC_MEM
; Outputs: C clear and X = slot (0..7) on success
;          C set and A = CASM_DIAG_REGISTRY_FULL on failure
; Clobbers: A, X, Y, CasmValue0Lo/CasmValue0Hi
; ---------------------------------------------------------------------------
resourceRegisterVmm:
    stx CasmValue0Lo
    sty CasmValue0Hi
    ldx #0
    ldy #0
rrvFind:
    lda CasmVmmRegistry + CASM_VMM_REC_FLAG, y
    beq rrvFound
    tya
    clc
    adc #CASM_VMM_REC_SIZE
    tay
    inx
    cpx #CASM_VMM_CAPACITY
    bcc rrvFind
    lda #CASM_DIAG_REGISTRY_FULL
    sta CasmLastDiag
    sec
    rts
rrvFound:
    lda #CASM_RESOURCE_OWNED
    sta CasmVmmRegistry + CASM_VMM_REC_FLAG, y
    lda CasmValue0Lo
    sta CasmVmmRegistry + CASM_VMM_REC_SEGHI, y
    lda CasmValue0Hi
    sta CasmVmmRegistry + CASM_VMM_REC_BANK, y
    inc CasmVmmCount
    lda #CASM_DIAG_NONE
    clc
    rts

; ---------------------------------------------------------------------------
; resourceReleaseVmm
; Remove a VMM allocation from the registry after it has been freed.
;
; Inputs:  X = slot returned by resourceRegisterVmm
; Outputs: C clear, A = CASM_DIAG_NONE for an owned or already-free slot
;          C set, A = CASM_DIAG_UNKNOWN for an out-of-range slot
; Clobbers: A, Y, CasmValue0Lo
; ---------------------------------------------------------------------------
resourceReleaseVmm:
    cpx #CASM_VMM_CAPACITY
    bcs rrvBadSlot
    stx CasmValue0Lo
    txa
    asl
    clc
    adc CasmValue0Lo
    tay
    lda CasmVmmRegistry + CASM_VMM_REC_FLAG, y
    beq rrvReleased
    lda #CASM_RESOURCE_FREE
    sta CasmVmmRegistry + CASM_VMM_REC_FLAG, y
    sta CasmVmmRegistry + CASM_VMM_REC_SEGHI, y
    sta CasmVmmRegistry + CASM_VMM_REC_BANK, y
    lda CasmVmmCount
    beq rrvReleased
    dec CasmVmmCount
rrvReleased:
    lda #CASM_DIAG_NONE
    clc
    rts
rrvBadSlot:
    lda #CASM_DIAG_UNKNOWN
    sta CasmLastDiag
    sec
    rts

; ---------------------------------------------------------------------------
; resourcesCleanup
; Best-effort, bounded, repeat-safe cleanup of all registered ownership.
;
; Phase 1 close/free helpers only invalidate records: Phase 2 replaces the
; file helper with DOS_CLOSE_FILE, and the VMM-storage phase replaces the VMM
; helper with DOS_FREE_MEM. Phase 1 never registers a live OS resource.
;
; Inputs:  none
; Outputs: C clear, A = CASM_DIAG_NONE
; Clobbers: A, X
; ---------------------------------------------------------------------------
resourcesCleanup:
    lda CasmCleanupGuard
    bne rcAlreadyActive
    lda #CASM_CLEANUP_ACTIVE
    sta CasmCleanupGuard

    ldx #0
rcFileLoop:
    jsr cleanupFileStub
    inx
    inx
    cpx #CASM_FILE_REGISTRY_BYTES
    bcc rcFileLoop
    lda #0
    sta CasmFileCount

    ldx #0
rcVmmLoop:
    jsr cleanupVmmStub
    txa
    clc
    adc #CASM_VMM_REC_SIZE
    tax
    cpx #CASM_VMM_REGISTRY_BYTES
    bcc rcVmmLoop
    lda #0
    sta CasmVmmCount
    sta CasmCleanupGuard
rcAlreadyActive:
    lda #CASM_DIAG_NONE
    clc
    rts

; Input: X = file-record byte offset. Phase 2 replaces invalidation with a
; real close followed by invalidation only when the close succeeds.
cleanupFileStub:
    lda #CASM_RESOURCE_FREE
    sta CasmFileRegistry + CASM_FILE_REC_FLAG, x
    lda #CASM_INVALID_HANDLE
    sta CasmFileRegistry + CASM_FILE_REC_HANDLE, x
    rts

; Input: X = VMM-record byte offset. The VMM-storage phase replaces this with
; a real free followed by invalidation only when the free succeeds.
cleanupVmmStub:
    lda #CASM_RESOURCE_FREE
    sta CasmVmmRegistry + CASM_VMM_REC_FLAG, x
    sta CasmVmmRegistry + CASM_VMM_REC_SEGHI, x
    sta CasmVmmRegistry + CASM_VMM_REC_BANK, x
    rts

; ---------------------------------------------------------------------------
; exitSuccess
; Clean all ownership and return to the shell.
;
; Inputs: none
; Outputs: does not return
; Clobbers: A, X and OS API-defined registers
; ---------------------------------------------------------------------------
exitSuccess:
    lda #CASM_DIAG_NONE
    sta CasmLastDiag
    jsr resourcesCleanup
    lda #DOS_EXIT
    jsr OS_API
esUnexpectedReturn:
    jmp esUnexpectedReturn

; ---------------------------------------------------------------------------
; exitFatal
; Print and preserve a primary diagnostic, clean ownership, and exit.
;
; Inputs: A = CASM_DIAG_* primary failure
; Outputs: does not return
; Clobbers: A, X, Y and OS API-defined registers
; ---------------------------------------------------------------------------
exitFatal:
    sta CasmLastDiag
    jsr diagPrintFatal
    jsr resourcesCleanup
    lda #DOS_EXIT
    jsr OS_API
efUnexpectedReturn:
    jmp efUnexpectedReturn
