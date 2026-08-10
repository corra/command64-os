; tests/src/casm_faultinject_vmm/casm_faultvmm.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 11 WP58 VMM fault-injection fixture. Links the real, unmodified
; vmm_store.s and resources.s modules, then uses WP57's shared $1000 OS_API
; hook to exercise every VMM service failure contract. Real allocations set
; up valid owned slots before free/read/write failures; each case disarms the
; hook and releases its allocation before returning.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_faultvmm.inc"

.import __MAIN_START__
.import resourcesInit
.import vmmStoreAlloc
.import vmmStoreFree
.import vmmWindowRead
.import vmmWindowWrite
.import CasmVmmCount
.import CasmVmmRegistry

.export diagPrintFatal

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

    jsr allocUnavailableIsDiagnosed
    jsr reportCase
    jsr allocNoMemoryIsDiagnosed
    jsr reportCase
    jsr freeFailureRetainsOwnership
    jsr reportCase
    jsr readFailureRetainsOwnership
    jsr reportCase
    jsr writeFailureRetainsOwnership
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

registryIsEmpty:
    lda CasmVmmCount
    bne rieFail
    ldy #0
rieLoop:
    lda CasmVmmRegistry + CASM_VMM_REC_FLAG, y
    bne rieFail
    tya
    clc
    adc #CASM_VMM_REC_SIZE
    tay
    cpy #CASM_VMM_REGISTRY_BYTES
    bcc rieLoop
    clc
    rts
rieFail:
    sec
    rts

savedSlotIsOwned:
    lda CasmVmmCount
    cmp #1
    bne ssioFail
    lda SavedSlot
    asl
    asl
    tay
    lda CasmVmmRegistry + CASM_VMM_REC_FLAG, y
    cmp #CASM_RESOURCE_OWNED
    bne ssioFail
    clc
    rts
ssioFail:
    sec
    rts

cleanupSavedSlot:
    lda #0
    sta FaultArmed
    ldx SavedSlot
    jsr vmmStoreFree
    rts

allocUnavailableIsDiagnosed:
    jsr resourcesInit
    jsr resetFaultDescriptor
    lda #VMM_ERR_INVALID
    sta FaultReturnA
    lda #DOS_ALLOC_MEM
    jsr armNextCall
    ldx #32
    ldy #0
    jsr vmmStoreAlloc
    bcc auiFail
    cmp #CASM_DIAG_VMM_UNAVAILABLE
    bne auiFail
    jsr registryIsEmpty
    bcs auiFail
    clc
    rts
auiFail:
    sec
    rts

allocNoMemoryIsDiagnosed:
    jsr resourcesInit
    jsr resetFaultDescriptor
    lda #VMM_ERR_NOMEM
    sta FaultReturnA
    lda #DOS_ALLOC_MEM
    jsr armNextCall
    ldx #32
    ldy #0
    jsr vmmStoreAlloc
    bcc anmFail
    cmp #CASM_DIAG_VMM_ALLOC_FAILED
    bne anmFail
    jsr registryIsEmpty
    bcs anmFail
    clc
    rts
anmFail:
    sec
    rts

freeFailureRetainsOwnership:
    jsr resourcesInit
    jsr resetFaultDescriptor
    ldx #32
    ldy #0
    jsr vmmStoreAlloc
    bcs ffrFailNoSlot
    stx SavedSlot
    lda #DOS_FREE_MEM
    jsr armNextCall
    ldx SavedSlot
    jsr vmmStoreFree
    bcc ffrFail
    cmp #CASM_DIAG_VMM_FREE_FAILED
    bne ffrFail
    jsr savedSlotIsOwned
    bcs ffrFail
    jsr cleanupSavedSlot
    bcs ffrFailNoSlot
    clc
    rts
ffrFail:
    jsr cleanupSavedSlot
ffrFailNoSlot:
    sec
    rts

readFailureRetainsOwnership:
    jsr resourcesInit
    jsr resetFaultDescriptor
    ldx #32
    ldy #0
    jsr vmmStoreAlloc
    bcs rfrFailNoSlot
    stx SavedSlot
    lda #DOS_VMM_READ
    jsr armNextCall
    jsr prepareTransfer
    jsr vmmWindowRead
    bcc rfrFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne rfrFail
    jsr savedSlotIsOwned
    bcs rfrFail
    jsr cleanupSavedSlot
    bcs rfrFailNoSlot
    clc
    rts
rfrFail:
    jsr cleanupSavedSlot
rfrFailNoSlot:
    sec
    rts

writeFailureRetainsOwnership:
    jsr resourcesInit
    jsr resetFaultDescriptor
    ldx #32
    ldy #0
    jsr vmmStoreAlloc
    bcs wfrFailNoSlot
    stx SavedSlot
    lda #DOS_VMM_WRITE
    jsr armNextCall
    jsr prepareTransfer
    jsr vmmWindowWrite
    bcc wfrFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne wfrFail
    jsr savedSlotIsOwned
    bcs wfrFail
    jsr cleanupSavedSlot
    bcs wfrFailNoSlot
    clc
    rts
wfrFail:
    jsr cleanupSavedSlot
wfrFailNoSlot:
    sec
    rts

prepareTransfer:
    ldx SavedSlot
    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    sta CasmIoLenHi
    lda #1
    sta CasmIoLenLo
    rts

; Shared runtime OS_API hook and control table.
.include "../casm_faultinject/faultstub.inc"

; resources.s references this through terminal paths this fixture never calls.
diagPrintFatal:
    rts

.segment "RODATA"

passMsg: .byte "CASM FAULT VMM: PASS", PetCr, 0
failMsg: .byte "CASM FAULT VMM: FAIL", PetCr, 0

.segment "BSS"

FailCount: .res 1
SavedSlot: .res 1
