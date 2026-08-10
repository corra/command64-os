; tests/src/casm_faultinject/casm_faultinject.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 11 WP57/WP58 file-I/O fault-injection harness. Proves the
; recommended interception mechanism (a runtime patch at the single shared
; OS_API stub, $1000, per the WP57 plan's "one universal interception
; point" finding) against fileio.s's real, unmodified operations.
;
; This harness links fileio.s whole (matching casm_vmm.s's own precedent
; for linking a real CASM module into a standalone fixture) and exercises
; it directly -- no CASM-source or OS-source change of any kind. The
; fault-injecting stub (faultStub, now WP58's shared faultstub.inc) lives in
; this harness's own CODE segment, not at the separate high-RAM address
; (e.g. $A000) the WP57 plan resolved for the eventual full-CASM-binary
; scenario: that scenario injects faults into a SEPARATELY loaded, full-size
; CASM binary coexisting in memory with its own loader, which needs the
; high-RAM placement; this harness IS both the "loader" and the exerciser in
; one PRG, so the stub can live anywhere in its own CODE segment. The
; RAM-placement question WP57's plan already answered remains correctly
; deferred to whichever fixture first needs it, not re-solved here.
;
; faultStub defaults to WP57's original carry-set, A=0 failure shape. WP58
; adds optional returned A/count fields and a carry-clear success mode for
; the two fileio contracts that inspect more than carry: fileRead's returned
; byte count and fileWrite's short-write count.
;
; Eight cases cover disarmed pass-through, create failure, write failure,
; short write, close failure, delete failure, zero-byte EOF normalization,
; and nonzero read failure. Every case calls the real fileio.s routine.
.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_faultinject.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import fileIoInit
.import fileCreateOutput
.import fileRead
.import fileWrite
.import fileClose
.import fileDelete
.import CasmInputState
.import CasmInputHandle
.import CasmOutputState
.import CasmOutputCreated
.import CasmOutputHandle
.import CasmOutputValid

; fileio.s .imports CasmOutputName at module scope (outputAbort's fileDelete
; call) even though this harness never reaches outputAbort -- ld65 links
; whole object files, so the import must resolve regardless. Matches
; casm_listwrite.s's own CasmOutputName-stand-in precedent.
.export CasmOutputName

; resources.s .imports diagPrintFatal (exitSuccess/exitFatal, unreached here)
; and vmmStoreFree (resourcesCleanup's registry sweep) at module scope --
; stubbed locally rather than linking diagnostics.s/vmm_store.s, exactly
; matching casm_vmm.s's own precedent (its header explains why: pulling in
; the real diagnostics.s would drag its own lexer.s/source.s dependencies
; for a symbol this harness never calls). vmmStoreFree always returns
; success: this harness makes no VMM allocation, so every registry slot
; resourcesCleanup's sweep visits is unowned, and an unowned free is a
; no-op success by vmm_store.s's own contract.
.export diagPrintFatal
.export vmmStoreFree

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

    jsr controlRunSucceeds
    jsr reportCase
    jsr resourcesCleanup

    jsr armedRunFails
    jsr reportCase
    jsr resourcesCleanup

    jsr writeFailureIsDiagnosed
    jsr reportCase

    jsr shortWriteIsDiagnosed
    jsr reportCase

    jsr closeFailureIsDiagnosed
    jsr reportCase

    jsr deleteFailureIsDiagnosed
    jsr reportCase

    jsr zeroByteReadIsEof
    jsr reportCase

    jsr nonzeroReadFailureIsDiagnosed
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

; ---------------------------------------------------------------------------
; reportCase
; Print '.' for a pass (carry clear) or 'F' for a fail (carry set), tallying
; FailCount. Matches every other CASM test harness's convention exactly.
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
; controlRunSucceeds
; faultStub is installed (from start's faultInstall) but FaultArmed is 0.
; A real fileCreateOutput against a fresh filename must succeed exactly as
; it would with no fault-injection harness present -- proves the
; pass-through path is a true no-op.
; ---------------------------------------------------------------------------
controlRunSucceeds:
    jsr fileIoInit
    lda #0
    sta FaultArmed
    ldx #<nameControl
    ldy #>nameControl
    jsr fileCreateOutput
    bcs crFail
    lda CasmOutputState
    cmp #CASM_FILE_STATE_OPEN
    bne crFail
    lda CasmOutputCreated
    cmp #CASM_OUTPUT_CREATED
    bne crFail
    clc
    rts
crFail:
    sec
    rts

; ---------------------------------------------------------------------------
; armedRunFails
; Arm faultStub for the next DOS_OPEN_FILE call (countdown 1), then call
; fileCreateOutput against a different fresh filename. Must fail with
; CASM_DIAG_OUTPUT_CREATE_FAILED, and CasmOutputState/CasmOutputCreated
; must show no partial registration -- exactly as a genuine KERNAL open
; failure would leave them (fcoCreateFailed returns before touching either).
; ---------------------------------------------------------------------------
armedRunFails:
    jsr fileIoInit
    lda #DOS_OPEN_FILE
    sta FaultFuncCode
    lda #1
    sta FaultCountdown
    lda #1
    sta FaultArmed
    ldx #<nameArmed
    ldy #>nameArmed
    jsr fileCreateOutput
    bcc afFail              ; must fail -- success means the fault never fired
    cmp #CASM_DIAG_OUTPUT_CREATE_FAILED
    bne afFail
    lda CasmOutputState
    cmp #CASM_FILE_STATE_CLOSED
    bne afFail
    lda CasmOutputCreated
    bne afFail
    ; disarm before returning: leaves no armed state for resourcesCleanup
    ; or any later case (defensive; this harness has none, but WP58's own
    ; multi-fixture reuse of this mechanism will).
    lda #0
    sta FaultArmed
    clc
    rts
afFail:
    lda #0
    sta FaultArmed
    sec
    rts

; Reset the optional canned-return fields before each case. The carry-set,
; A=0, no-count shape is the shared stub's default failure contract.
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

writeFailureIsDiagnosed:
    jsr fileIoInit
    jsr resetFaultDescriptor
    lda #CASM_FILE_STATE_OPEN
    sta CasmOutputState
    lda #CASM_OUTPUT_VALID
    sta CasmOutputValid
    lda #1
    sta CasmOutputHandle
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    lda #DOS_WRITE_FILE
    jsr armNextCall
    ldx #<ioByte
    ldy #>ioByte
    jsr fileWrite
    bcc wfFail
    cmp #CASM_DIAG_OUTPUT_WRITE_FAILED
    bne wfFail
    lda CasmOutputValid
    cmp #CASM_OUTPUT_INVALID
    bne wfFail
    clc
    rts
wfFail:
    sec
    rts

shortWriteIsDiagnosed:
    jsr fileIoInit
    jsr resetFaultDescriptor
    lda #CASM_FILE_STATE_OPEN
    sta CasmOutputState
    lda #CASM_OUTPUT_VALID
    sta CasmOutputValid
    lda #1
    sta CasmOutputHandle
    sta FaultReturnSuccess
    sta FaultSetCount
    sta FaultReturnCountLo
    lda #2
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    sta FaultReturnCountHi
    lda #DOS_WRITE_FILE
    jsr armNextCall
    ldx #<ioBytes
    ldy #>ioBytes
    jsr fileWrite
    bcc swFail
    cmp #CASM_DIAG_OUTPUT_SHORT_WRITE
    bne swFail
    lda CasmIoLenLo
    cmp #1
    bne swFail
    lda CasmIoLenHi
    bne swFail
    lda CasmOutputValid
    cmp #CASM_OUTPUT_INVALID
    bne swFail
    clc
    rts
swFail:
    sec
    rts

closeFailureIsDiagnosed:
    jsr resetFaultDescriptor
    lda #DOS_CLOSE_FILE
    jsr armNextCall
    lda #1
    ldx #0
    ldy #CASM_DIAG_OUTPUT_CLOSE_FAILED
    jsr fileClose
    bcc cfFail
    cmp #CASM_DIAG_OUTPUT_CLOSE_FAILED
    bne cfFail
    clc
    rts
cfFail:
    sec
    rts

deleteFailureIsDiagnosed:
    jsr resetFaultDescriptor
    lda #DOS_DELETE_FILE
    jsr armNextCall
    ldx #<nameDelete
    ldy #>nameDelete
    jsr fileDelete
    bcc dfFail
    cmp #CASM_DIAG_OUTPUT_DELETE_FAILED
    bne dfFail
    clc
    rts
dfFail:
    sec
    rts

zeroByteReadIsEof:
    jsr fileIoInit
    jsr resetFaultDescriptor
    lda #CASM_FILE_STATE_OPEN
    sta CasmInputState
    lda #1
    sta CasmInputHandle
    sta CasmIoLenLo
    sta FaultSetCount
    lda #0
    sta CasmIoLenHi
    lda #DOS_READ_FILE
    jsr armNextCall
    ldx #<ioByte
    ldy #>ioByte
    jsr fileRead
    bcs zeFail
    cmp #CASM_STREAM_EOF
    bne zeFail
    lda CasmInputState
    cmp #CASM_STREAM_EOF
    bne zeFail
    lda CasmIoLenLo
    ora CasmIoLenHi
    bne zeFail
    clc
    rts
zeFail:
    sec
    rts

nonzeroReadFailureIsDiagnosed:
    jsr fileIoInit
    jsr resetFaultDescriptor
    lda #CASM_FILE_STATE_OPEN
    sta CasmInputState
    lda #1
    sta CasmInputHandle
    sta CasmIoLenLo
    sta FaultSetCount
    sta FaultReturnCountLo
    lda #0
    sta CasmIoLenHi
    sta FaultReturnCountHi
    lda #DOS_READ_FILE
    jsr armNextCall
    ldx #<ioByte
    ldy #>ioByte
    jsr fileRead
    bcc nrFail
    cmp #CASM_DIAG_INPUT_READ_FAILED
    bne nrFail
    lda CasmInputState
    cmp #CASM_STREAM_ERROR
    bne nrFail
    lda CasmIoLenLo
    cmp #1
    bne nrFail
    lda CasmIoLenHi
    bne nrFail
    clc
    rts
nrFail:
    sec
    rts

; faultInstall/faultStubEntry and the shared control table (FaultArmed/
; FaultFuncCode/FaultCountdown/FaultReturnA/FaultReturnSuccess/FaultSetCount/
; FaultReturnCountLo/Hi/RealApiVector) now live in faultstub.inc (WP58
; extraction from this harness's own WP57 prototype). Ends back in the CODE
; segment, matching the flow below.
.include "faultstub.inc"

; ---------------------------------------------------------------------------
; diagPrintFatal / vmmStoreFree
; Local stubs for resources.s's module-scope imports (exitSuccess/exitFatal
; and resourcesCleanup's registry sweep, respectively) -- neither is
; exercised by this harness. Matches casm_vmm.s's own precedent exactly.
; ---------------------------------------------------------------------------
diagPrintFatal:
    rts

vmmStoreFree:
    clc
    rts

.segment "DATA"

nameControl: .byte "8:FTINJ01", 0
nameArmed:   .byte "8:FTINJ02", 0
nameDelete:  .byte "8:FTINJ03", 0
ioBytes:     .byte $11
ioByte:      .byte $22

CasmOutputName: .res CASM_FILENAME_BUFFER_SIZE

passMsg: .byte "CASM FAULTINJECT: PASS", $0D, 0
failMsg: .byte "CASM FAULTINJECT: FAIL", $0D, 0

.segment "BSS"

FailCount: .res 1
