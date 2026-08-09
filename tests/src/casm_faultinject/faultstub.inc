; tests/src/casm_faultinject/faultstub.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 11 WP58 shared fault-injection library. Extracted from WP57's
; design-spike prototype (casm_faultinject.s), which proved a runtime patch
; at the single shared OS_API stub ($1000) as the interception mechanism
; against exactly one fault. Every fault-injection fixture from WP58 onward
; .include's this file once, matching this codebase's existing shared-include
; convention for command64.inc/common.inc.
;
; Extends WP57's SEC-only canned failure with an optional canned-return
; descriptor, needed by exactly two operations traced in the WP58 plan:
;   - DOS_READ_FILE: fileRead disambiguates EOF from a real failure by the
;     OS's returned byte count (HexValLo/Hi), not carry alone. A SEC-only
;     canned failure is silently reclassified as EOF. FaultSetCount arms a
;     nonzero canned count so the injected failure lands as
;     CASM_DIAG_INPUT_READ_FAILED instead.
;   - DOS_ALLOC_MEM: vmmStoreAlloc's failure path branches on the OS's
;     returned A (VMM_ERR_INVALID -> CASM_DIAG_VMM_UNAVAILABLE, anything else
;     -> CASM_DIAG_VMM_ALLOC_FAILED). FaultReturnA supplies that value.
;
; Every other traced operation (fileCreateOutput/fileClose/fileDelete/
; fileWrite's WRITE_FAILED path, DOS_FREE_MEM, DOS_VMM_READ, DOS_VMM_WRITE)
; substitutes its own diagnostic unconditionally without reading A or the
; byte count on the carry-set path, so leaving FaultReturnA/FaultSetCount at
; their zero defaults reproduces WP57's original SEC-only shape exactly.
;
; fileWrite's SHORT_WRITE case is a carry-CLEAR success with an
; under-count -- a different shape from the canned-failure path this file
; builds. Deliberately out of scope here (WP58 Increment 1); left for
; whichever increment first exercises it.
;
; This file declares no .segment of its own visible constants beyond the
; routines/storage below; the including fixture's CODE/DATA segments are
; already open when it is .include'd.

; ---------------------------------------------------------------------------
; faultInstall
; Save the real OS_API target (the JMP operand currently at $1001/$1002)
; into RealApiVector, then redirect that operand to faultStubEntry. Leaves
; the JMP opcode at $1000 itself untouched -- only the 2-byte target moves --
; so $1000 remains a valid `jmp` instruction throughout, matching the OS's
; own "stable entry point" contract (api.asm) as closely as a test-only
; patch can.
; ---------------------------------------------------------------------------
faultInstall:
    lda $1001
    sta RealApiVector
    lda $1002
    sta RealApiVector+1
    lda #<faultStubEntry
    sta $1001
    lda #>faultStubEntry
    sta $1002
    lda #0
    sta FaultArmed
    rts

; ---------------------------------------------------------------------------
; faultStubEntry
; Reached in place of apiHandler for every OS_API call for the rest of the
; including fixture's run. Mirrors apiHandler's own first instruction (cld)
; so a disarmed or non-matching call is byte-for-byte behaviorally identical
; to the unpatched OS. Touches only A internally (preserved via the stack)
; -- never X/Y -- since apiHandler's own ABI treats X as an argument
; register that every real handler depends on unchanged.
;
; Inputs:    A = OS_API function code (the real call's own input, untouched)
;            FaultArmed/FaultFuncCode/FaultCountdown = control table (caller
;              arms these directly before the targeted call)
;            FaultReturnA = A value on the canned-failure return (default 0;
;              only DOS_ALLOC_MEM's vsaAllocFailed reads this)
;            FaultSetCount = nonzero to also write FaultReturnCountLo/Hi into
;              HexValLo/Hi before returning (only DOS_READ_FILE's fileRead
;              reads this on the carry-set path)
; Outputs:   armed+matched+countdown-expired: C set, A = FaultReturnA
;              (canned failure; HexValLo/Hi also set when FaultSetCount != 0)
;            otherwise: falls through to the real apiHandler unchanged,
;              whatever it returns
; Preserves: X, Y (never touched)
; Clobbers:  A, processor flags (matches apiHandler's own contract)
; ---------------------------------------------------------------------------
faultStubEntry:
    cld
    pha
    lda FaultArmed
    beq fsPassThrough
    pla
    pha
    cmp FaultFuncCode
    bne fsPassThrough
    dec FaultCountdown
    bne fsPassThrough
    pla
    sec
    lda FaultSetCount
    beq fsNoCount
    lda FaultReturnCountLo
    sta HexValLo
    lda FaultReturnCountHi
    sta HexValHi
fsNoCount:
    lda FaultReturnA
    rts
fsPassThrough:
    pla
    jmp (RealApiVector)

.segment "DATA"

FaultArmed:          .byte 0
FaultFuncCode:       .byte 0
FaultCountdown:      .byte 0
FaultReturnA:        .byte 0
FaultSetCount:       .byte 0
FaultReturnCountLo:  .byte 0
FaultReturnCountHi:  .byte 0
RealApiVector:       .word 0

.segment "CODE"
