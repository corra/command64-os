; tests/src/casm_faultinject_symbols/casm_faultsymbols.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 11 WP58 Increment 4 symbols.s fault-injection fixture. Links the
; real symbols.s/vmm_store.s/resources.s against the shared runtime OS_API
; fault hook (faultstub.inc), matching casm_faultsource.s's precedent for a
; real-module-surface fixture rather than an inline reimplementation.
;
; symbols.s makes exactly four OS_API-reachable calls, all through
; vmm_store.s (traced in the WP58 plan): symbolsInit's one vmmStoreAlloc,
; symbolsFindChain's one vmmWindowRead (shared by symbolsInsert and
; symbolsLookup), symbolsInsert's own vmmWindowWrite, and
; symbolsReadByIndex's own vmmWindowRead. Each case below forces exactly one
; of those four to fail and asserts the propagated diagnostic plus the
; specific state-consistency invariant symbols.s's own header comments
; document for that call site:
;   - allocFailureLeavesNoOwner: CasmVmmCount stays 0 (vmmStoreAlloc never
;     registers a slot on a rejected DOS_ALLOC_MEM).
;   - insertFindFailureLeavesCountUnchanged: a chain-walk read failure during
;     symbolsInsert must propagate CASM_DIAG_VMM_TRANSFER_FAILED, not be
;     misread as CASM_DIAG_DUPLICATE_SYMBOL, and must not bump
;     CasmSymbolCount -- proven here by inserting the SAME name again for
;     real afterward and confirming it is rejected as a genuine duplicate
;     (symbolsInsert's own comment: "Never leaves partial state on
;     failure").
;   - insertWriteFailureLeavesCountUnchanged: a write failure after a
;     successful not-found chain walk must also leave CasmSymbolCount
;     untouched -- proven by retrying the identical insert once the fault is
;     disarmed and asserting it lands at record index FirstIndex + 1 (the
;     count the earlier successful insert alone would produce, with no gap
;     left by the failed attempt).
;   - lookupFindFailurePropagates: a chain-walk read failure during
;     symbolsLookup must propagate CASM_DIAG_VMM_TRANSFER_FAILED rather than
;     silently reporting "not found" through the view.
;   - readByIndexFailurePropagates: symbolsReadByIndex's own read failure
;     propagates CASM_DIAG_VMM_TRANSFER_FAILED, distinct from its normal
;     CASM_STREAM_EOF/CASM_STREAM_DATA outcomes.
;
; Stubs diagPrintFatal locally for the same reason casm_symbols.s does:
; resources.s's exitSuccess/exitFatal reference it, and ld65 links whole
; object files, so importing resourcesInit alone would otherwise drag in
; diagnostics.s's transitive lexer.s/source.s dependencies.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_fsym.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import symbolsInit
.import symbolsInsert
.import symbolsLookup
.import symbolsReadByIndex
.import CasmVmmCount

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

    jsr allocFailureLeavesNoOwner
    jsr reportCase
    jsr insertFindFailureLeavesCountUnchanged
    jsr reportCase
    jsr insertWriteFailureLeavesCountUnchanged
    jsr reportCase
    jsr lookupFindFailurePropagates
    jsr reportCase
    jsr readByIndexFailurePropagates
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
; Fault DOS_ALLOC_MEM before the very first symbolsInit in this run. Assert
; the propagated diagnostic and that CasmVmmCount (resources.s's own
; registry counter) stays at 0 -- a rejected allocation must never register
; an owner. Then retry for real so every later case runs against a live
; symbol table.
; ---------------------------------------------------------------------------
allocFailureLeavesNoOwner:
    jsr resetFaultDescriptor
    lda #VMM_ERR_NOMEM
    sta FaultReturnA
    lda #DOS_ALLOC_MEM
    jsr armNextCall
    jsr symbolsInit
    bcc aflFail
    cmp #CASM_DIAG_VMM_ALLOC_FAILED
    bne aflFail
    lda CasmVmmCount
    bne aflFail
    jsr disarm
    jsr symbolsInit
    bcs aflFail
    clc
    rts
aflFail:
    jsr disarm
    sec
    rts

; ---------------------------------------------------------------------------
; insertFindFailureLeavesCountUnchanged
; Insert one real symbol (nameFirst), recording its record index. Fault
; DOS_VMM_READ on a second attempt to insert that SAME name -- guaranteed to
; hit a non-empty bucket and attempt a read, since symbolsFindChain always
; walks the bucket its own name hashes to. Assert the propagated diagnostic,
; then confirm a REAL insert of the same name afterward is rejected as a
; genuine duplicate (not CASM_DIAG_SYMBOL_TABLE_FULL, not an unexpected
; success) -- proving the failed find neither bumped CasmSymbolCount nor
; corrupted the chain.
; ---------------------------------------------------------------------------
insertFindFailureLeavesCountUnchanged:
    lda #<nameFirst
    sta CasmPtr0Lo
    lda #>nameFirst
    sta CasmPtr0Hi
    lda #5
    ldx #$11
    ldy #$00
    jsr symbolsInsert
    bcs iffFail
    stx FirstIndexLo
    sty FirstIndexHi

    lda #DOS_VMM_READ
    jsr armNextCall

    lda #<nameFirst
    sta CasmPtr0Lo
    lda #>nameFirst
    sta CasmPtr0Hi
    lda #5
    ldx #$22
    ldy #$00
    jsr symbolsInsert
    bcc iffFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne iffFail
    jsr disarm

    lda #<nameFirst
    sta CasmPtr0Lo
    lda #>nameFirst
    sta CasmPtr0Hi
    lda #5
    ldx #$33
    ldy #$00
    jsr symbolsInsert
    bcc iffFail
    cmp #CASM_DIAG_DUPLICATE_SYMBOL
    bne iffFail
    clc
    rts
iffFail:
    jsr disarm
    sec
    rts

; ---------------------------------------------------------------------------
; insertWriteFailureLeavesCountUnchanged
; Fault DOS_VMM_WRITE on the first insert of a brand-new name (nameSecond):
; the chain-walk find succeeds (not found), then the write itself is
; rejected. Assert the propagated diagnostic, then retry the identical
; insert for real and assert it lands at record index FirstIndex + 1 --
; exactly what a fresh insert after the ONE prior successful insert
; (nameFirst, from allocFailureLeavesNoOwner/insertFindFailureLeavesCount-
; Unchanged) should produce, proving the failed write never advanced the
; bump allocator.
; ---------------------------------------------------------------------------
insertWriteFailureLeavesCountUnchanged:
    lda #DOS_VMM_WRITE
    jsr armNextCall

    lda #<nameSecond
    sta CasmPtr0Lo
    lda #>nameSecond
    sta CasmPtr0Hi
    lda #6
    ldx #$44
    ldy #$00
    jsr symbolsInsert
    bcc iwfFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne iwfFail
    jsr disarm

    lda #<nameSecond
    sta CasmPtr0Lo
    lda #>nameSecond
    sta CasmPtr0Hi
    lda #6
    ldx #$55
    ldy #$00
    jsr symbolsInsert
    bcs iwfFail
    cpy FirstIndexHi
    bne iwfFail
    txa
    sec
    sbc FirstIndexLo
    cmp #1
    bne iwfFail
    clc
    rts
iwfFail:
    jsr disarm
    sec
    rts

; ---------------------------------------------------------------------------
; lookupFindFailurePropagates
; Fault DOS_VMM_READ on a lookup of nameFirst (guaranteed non-empty bucket,
; guaranteed read attempt). Assert the propagated diagnostic rather than a
; silent "not found" through the view, then confirm a real lookup right
; afterward still resolves normally -- the fault was call-scoped, not a
; lasting corruption of the table.
; ---------------------------------------------------------------------------
lookupFindFailurePropagates:
    lda #DOS_VMM_READ
    jsr armNextCall

    lda #<nameFirst
    sta CasmPtr0Lo
    lda #>nameFirst
    sta CasmPtr0Hi
    lda #5
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc lffFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne lffFail
    jsr disarm

    lda #<nameFirst
    sta CasmPtr0Lo
    lda #>nameFirst
    sta CasmPtr0Hi
    lda #5
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcs lffFail
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    beq lffFail
    clc
    rts
lffFail:
    jsr disarm
    sec
    rts

; ---------------------------------------------------------------------------
; readByIndexFailurePropagates
; Fault DOS_VMM_READ on symbolsReadByIndex against record index 0 (known to
; exist -- nameFirst's own record). Assert the propagated diagnostic,
; distinct from CASM_STREAM_EOF/CASM_STREAM_DATA, then confirm a real read
; of the same index afterward succeeds normally.
; ---------------------------------------------------------------------------
readByIndexFailurePropagates:
    ldx #0
    ldy #0
    lda #DOS_VMM_READ
    jsr armNextCall
    jsr symbolsReadByIndex
    bcc rbiFail
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne rbiFail
    jsr disarm

    ldx #0
    ldy #0
    jsr symbolsReadByIndex
    bcs rbiFail
    cmp #CASM_STREAM_DATA
    bne rbiFail
    clc
    rts
rbiFail:
    jsr disarm
    sec
    rts

; ---------------------------------------------------------------------------
; diagPrintFatal (stub)
; See file header.
; ---------------------------------------------------------------------------
diagPrintFatal:
    rts

.include "../casm_faultinject/faultstub.inc"

.segment "RODATA"

passMsg: .byte "CASM FAULT SYMBOLS: PASS", PetCr, 0
failMsg: .byte "CASM FAULT SYMBOLS: FAIL", PetCr, 0

nameFirst:  .byte "FIRST"
nameSecond: .byte "SECOND"

.segment "BSS"

FailCount:    .res 1
ResolveView:  .res CASM_RESOLVE_SIZE
FirstIndexLo: .res 1
FirstIndexHi: .res 1
