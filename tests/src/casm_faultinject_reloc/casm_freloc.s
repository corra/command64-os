; tests/src/casm_faultinject_reloc/casm_freloc.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 11 WP58 Increment 4 reloc.s fault-injection fixture. Links the
; real reloc.s/vmm_store.s/resources.s against the shared runtime OS_API
; fault hook (faultstub.inc), matching casm_reloc.s's own isolation
; precedent: CasmPc/CasmPassMode/CasmRelocatableMode are this harness's own
; exported stand-ins (reloc.s imports them from emit.s, which this harness
; deliberately does not link), poked directly to drive relocRecord/
; relocFinalize's inputs. fileWrite is a trivial stub, matching casm_reloc.s's
; own precedent -- every case below forces relocFinalize's failure on its
; OWN vmmWindowRead, before the table-copy loop ever reaches a real
; fileWrite call, so the stub is never exercised as anything but a
; link-satisfying placeholder.
;
; reloc.s makes exactly three OS_API-reachable calls through vmm_store.s
; (traced in the WP58 plan): relocInit's one vmmStoreAlloc, relocRecord's
; own vmmWindowWrite, and relocFinalize's own vmmWindowRead (its first
; table-copy chunk). Each case forces exactly one to fail and asserts the
; propagated diagnostic plus the state-consistency invariant reloc.s's own
; header comments imply for that call site:
;   - allocFailureLeavesNoOwner: CasmVmmCount stays 0 (vmmStoreAlloc never
;     registers a slot on a rejected DOS_ALLOC_MEM) -- same invariant as
;     symbols.s's own allocInit case.
;   - recordWriteFailureLeavesCountUnchanged: relocRecord's own comment
;     ("inc CasmRelocCount" only after "jsr vmmWindowWrite / bcs rrRet")
;     means a failed write must never bump the bump allocator. Since
;     CasmRelocCount is not exported, this is proven indirectly: after the
;     failed write, a REAL relocRecord call for a distinct CasmPc must
;     land at table offset 0 (record index 0), read back directly through
;     the exported CasmRelocVmmSlot -- if the failed attempt HAD bumped the
;     counter, the real entry would land at offset 2 instead.
;   - finalizeReadFailurePropagates: relocFinalize's first table-copy chunk
;     read failing must propagate CASM_DIAG_VMM_TRANSFER_FAILED directly
;     (rfLoop's "jsr vmmWindowRead / bcs rfRet"), never falling through to
;     attempt the chunk's fileWrite.
;
; Stubs diagPrintFatal locally for the same reason casm_reloc.s does:
; resources.s's exitSuccess/exitFatal reference it, and ld65 links whole
; object files, so importing resourcesInit alone would otherwise drag in
; diagnostics.s's transitive lexer.s/source.s dependencies.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_freloc.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import relocInit
.import relocRecord
.import relocFinalize
.import CasmRelocVmmSlot
.import vmmWindowRead
.import CasmVmmBuffer
.import CasmVmmCount

.export diagPrintFatal
.export CasmPc
.export CasmPassMode
.export CasmRelocatableMode
.export fileWrite

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
    jsr recordWriteFailureLeavesCountUnchanged
    jsr reportCase
    jsr finalizeReadFailurePropagates
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
; Fault DOS_ALLOC_MEM before the very first relocInit in this run. Assert
; the propagated diagnostic and that CasmVmmCount stays at 0, then retry for
; real so every later case runs against a live relocation table.
; ---------------------------------------------------------------------------
allocFailureLeavesNoOwner:
    jsr resetFaultDescriptor
    lda #VMM_ERR_NOMEM
    sta FaultReturnA
    lda #DOS_ALLOC_MEM
    jsr armNextCall
    jsr relocInit
    bcc aflFail
    cmp #CASM_DIAG_VMM_ALLOC_FAILED
    bne aflFail
    lda CasmVmmCount
    bne aflFail
    jsr disarm
    jsr relocInit
    bcs aflFail
    clc
    rts
aflFail:
    jsr disarm
    sec
    rts

; ---------------------------------------------------------------------------
; recordWriteFailureLeavesCountUnchanged
; Fault DOS_VMM_WRITE on a relocRecord call (CasmPc = origin + $10). Assert
; the propagated diagnostic, then issue a REAL relocRecord call for a
; distinct CasmPc (origin + $20) and read back table offset 0 directly
; through CasmRelocVmmSlot -- it must hold $0020 (the real call's own
; offset), proving the failed write never advanced CasmRelocCount past 0.
; ---------------------------------------------------------------------------
recordWriteFailureLeavesCountUnchanged:
    lda #CASM_PASS_MODE_EMIT
    sta CasmPassMode

    lda #DOS_VMM_WRITE
    jsr armNextCall

    lda #<(CASM_DEFAULT_ORIGIN + $10)
    sta CasmPc
    lda #>(CASM_DEFAULT_ORIGIN + $10)
    sta CasmPc + 1
    jsr relocRecord
    bcc rwfFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne rwfFail
    jsr disarm

    lda #<(CASM_DEFAULT_ORIGIN + $20)
    sta CasmPc
    lda #>(CASM_DEFAULT_ORIGIN + $20)
    sta CasmPc + 1
    jsr relocRecord
    bcs rwfFail

    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    lda #2
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmRelocVmmSlot
    jsr vmmWindowRead
    bcs rwfFail
    lda CasmVmmBuffer
    cmp #$20
    bne rwfFail
    lda CasmVmmBuffer + 1
    bne rwfFail
    clc
    rts
rwfFail:
    jsr disarm
    sec
    rts

; ---------------------------------------------------------------------------
; finalizeReadFailurePropagates
; The table already holds exactly one real entry (from
; recordWriteFailureLeavesCountUnchanged). Fault DOS_VMM_READ, set
; CasmRelocatableMode nonzero, and call relocFinalize -- its first
; table-copy chunk read must fail and propagate
; CASM_DIAG_VMM_TRANSFER_FAILED immediately, never reaching fileWrite (the
; stub below would otherwise mask a real failure by silently "succeeding").
; ---------------------------------------------------------------------------
finalizeReadFailurePropagates:
    lda #1
    sta CasmRelocatableMode

    lda #DOS_VMM_READ
    jsr armNextCall

    jsr relocFinalize
    bcc frpFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne frpFail
    jsr disarm
    clc
    rts
frpFail:
    jsr disarm
    sec
    rts

; ---------------------------------------------------------------------------
; diagPrintFatal (stub)
; See file header.
; ---------------------------------------------------------------------------
diagPrintFatal:
    rts

; ---------------------------------------------------------------------------
; fileWrite (stub)
; Never reached by any case above (each forces relocFinalize's failure on
; its own vmmWindowRead before the table-copy loop's fileWrite call).
; Trivial link-satisfying stub, matching casm_reloc.s's own precedent.
; ---------------------------------------------------------------------------
fileWrite:
    clc
    rts

.include "../casm_faultinject/faultstub.inc"

.segment "RODATA"

passMsg: .byte "CASM FAULT RELOC: PASS", PetCr, 0
failMsg: .byte "CASM FAULT RELOC: FAIL", PetCr, 0

.segment "BSS"

FailCount: .res 1

; reloc.s imports these from emit.s, which this harness deliberately does
; not link (matching casm_reloc.s's own isolation precedent). Exported so
; this harness's own test logic can poke them directly.
CasmPc:              .res 2
CasmPassMode:        .res 1
CasmRelocatableMode: .res 1
