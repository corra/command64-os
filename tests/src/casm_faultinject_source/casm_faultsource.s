; tests/src/casm_faultinject_source/casm_faultsource.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 11 WP58 source.s fault-injection fixture. Drives the real source,
; file, VMM, and resource modules against a real tiny overflow-disk file.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_faultsource.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import fileIoInit
.import sourceInit
.import sourceLoad
.import sourceOpen
.import sourceNextByte
.import sourceReadSpanChunk
.import CasmSourceState
.import CasmSourceResultByte
.import CasmFileCount
.import CasmVmmCount
.import CasmVmmBuffer

.export CasmSourceNames
.export CasmSourceCount
.export cliSourceSlotLo
.export cliSourceSlotHi
.export CasmOutputName

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda #0
    sta FailCount
    jsr faultInstall

    jsr allocFailureLeavesNoOwner
    jsr reportCase
    jsr writeFailureCleansCentrally
    jsr reportCase
    jsr spanReadFailureIsRetryable
    jsr reportCase
    jsr refillFailureSetsError
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

initSourceFixture:
    jsr resourcesInit
    jsr fileIoInit
    jsr sourceInit
    jsr resetFaultDescriptor
    ldy #0
isfCopy:
    lda fixtureName, y
    sta CasmSourceNames, y
    beq isfDone
    iny
    bne isfCopy
isfDone:
    lda #1
    sta CasmSourceCount
    clc
    rts

cleanupAndFail:
    lda #0
    sta FaultArmed
    jsr resourcesCleanup
    sec
    rts

cleanupAndPass:
    lda #0
    sta FaultArmed
    jsr resourcesCleanup
    bcs capFail
    lda CasmFileCount
    ora CasmVmmCount
    bne capFail
    clc
    rts
capFail:
    sec
    rts

allocFailureLeavesNoOwner:
    jsr initSourceFixture
    lda #VMM_ERR_NOMEM
    sta FaultReturnA
    lda #DOS_ALLOC_MEM
    jsr armNextCall
    jsr sourceLoad
    bcc aflFail
    cmp #CASM_DIAG_VMM_ALLOC_FAILED
    bne aflFail
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_CLOSED
    bne aflFail
    lda CasmFileCount
    ora CasmVmmCount
    bne aflFail
    clc
    rts
aflFail:
    jmp cleanupAndFail

writeFailureCleansCentrally:
    jsr initSourceFixture
    lda #DOS_VMM_WRITE
    jsr armNextCall
    jsr sourceLoad
    bcc wfcFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne wfcFail
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_CLOSED
    bne wfcFail
    lda CasmFileCount
    cmp #1
    bne wfcFail
    lda CasmVmmCount
    cmp #1
    bne wfcFail
    jmp cleanupAndPass
wfcFail:
    jmp cleanupAndFail

spanReadFailureIsRetryable:
    jsr initSourceFixture
    jsr sourceLoad
    bcs srfFail
    lda #DOS_VMM_READ
    jsr armNextCall
    jsr requestFirstByte
    bcc srfFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne srfFail
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_CLOSED
    bne srfFail
    lda CasmVmmCount
    cmp #1
    bne srfFail
    lda #0
    sta FaultArmed
    jsr requestFirstByte
    bcs srfFail
    lda CasmVmmBuffer
    cmp #$31                    ; casmcat1 is ten ASCII '1' bytes
    bne srfFail
    jmp cleanupAndPass
srfFail:
    jmp cleanupAndFail

refillFailureSetsError:
    jsr initSourceFixture
    jsr sourceLoad
    bcs rfsFail
    jsr sourceOpen
    bcs rfsFail
    lda #DOS_VMM_READ
    jsr armNextCall
    jsr sourceNextByte
    bcc rfsFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne rfsFail
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_ERROR
    bne rfsFail
    lda CasmVmmCount
    cmp #1
    bne rfsFail
    jmp cleanupAndPass
rfsFail:
    jmp cleanupAndFail

requestFirstByte:
    lda #1
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    jmp sourceReadSpanChunk

.include "../casm_faultinject/faultstub.inc"

.segment "RODATA"

fixtureName: .byte "CASMCAT1", 0
passMsg: .byte "CASM FAULT SOURCE: PASS", PetCr, 0
failMsg: .byte "CASM FAULT SOURCE: FAIL", PetCr, 0

cliSourceSlotLo: .byte <CasmSourceNames
cliSourceSlotHi: .byte >CasmSourceNames

.segment "BSS"

FailCount: .res 1
CasmSourceNames: .res CASM_FILENAME_BUFFER_SIZE
CasmSourceCount: .res 1
CasmOutputName: .res CASM_FILENAME_BUFFER_SIZE
