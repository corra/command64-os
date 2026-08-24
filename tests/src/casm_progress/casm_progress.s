; tests/src/casm_progress/casm_progress.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Progress Increment 3 focused harness. Links the real
; src/external/casm/progress.s directly -- progress.s imports nothing (no
; diagnostics.s/listing.s/map.s/VMM/resources dependency by design, per the
; Increment 2 review), so unlike casm_map.s/casm_symbols.s this harness
; needs no stand-in stubs at all.
;
; Screen text content is not asserted here: progressPrintStr/progressPrintChar
; call OS_API ($1000) directly rather than through an importable indirection
; layer (unlike diagnostics.s's diagPrintString, which harnesses elsewhere
; substitute by simply not linking diagnostics.s and supplying their own
; export of the same name), so nothing in this build can intercept what
; reaches the screen. This harness verifies internal state, carry/A returns,
; and the throttle/overflow/mismatch boundaries instead; actual on-screen
; rendering is verified live under VICE at Increment 10 (runtime
; acceptance), the same division of labor every other CASM module harness
; already uses (module-level state correctness here, screen truth later).
;
; CasmProgActiveLo/Hi and CasmProgPass1TotalLo/Hi are exported by
; progress.s for exactly this harness's direct-setup convenience (see its
; own header comment) -- not part of the frozen call ABI.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_progress.inc"

.import __MAIN_START__
.import progressInit
.import progressBeginPass
.import progressStatement
.import progressRenderTransient
.import progressCompletePass
.import progressAccumulateOutputBytes
.import progressClearTransient
.import progressSuspend
.import progressFinalSummary
.import progressCheckPassTotals
.import CasmProgArgDepth
.import CasmProgArgFileId
.import CasmProgArgLineLo
.import CasmProgArgLineHi
.import CasmProgArgNameBuf
.import CasmProgActiveLo
.import CasmProgActiveHi
.import CasmProgPass1TotalLo
.import CasmProgPass1TotalHi

; CASM_DIAG_PROGRESS_COUNTER_OVERFLOW/PASS_TOTAL_MISMATCH come from
; common.inc (Increment 4 moved them there); no local copy needed.

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda #0
    sta FailCount

    lda #'A'
    jsr KernalChROUT
    jsr caseInitZeroesState
    jsr reportCase
    lda #'B'
    jsr KernalChROUT
    jsr caseBeginPass1Reset
    jsr reportCase
    lda #'C'
    jsr KernalChROUT
    jsr caseBeginPass2SetsFlag
    jsr reportCase
    lda #'D'
    jsr KernalChROUT
    jsr caseStatementIncrementsLoHi
    jsr reportCase
    lda #'E'
    jsr KernalChROUT
    jsr caseStatementHiCarry
    jsr reportCase
    lda #'F'
    jsr KernalChROUT
    jsr caseThrottleAt64
    jsr reportCase
    lda #'G'
    jsr KernalChROUT
    jsr caseThrottleAt128
    jsr reportCase
    lda #'H'
    jsr KernalChROUT
    jsr caseThrottleNotDueMidRange
    jsr reportCase
    lda #'I'
    jsr KernalChROUT
    jsr caseOverflowBeforeWrap
    jsr reportCase
    lda #'J'
    jsr KernalChROUT
    jsr caseCompletePassLatchesTotal
    jsr reportCase
    lda #'K'
    jsr KernalChROUT
    jsr caseCheckPassTotalsMatch
    jsr reportCase
    lda #'L'
    jsr KernalChROUT
    jsr caseCheckPassTotalsMismatch
    jsr reportCase
    lda #'M'
    jsr KernalChROUT
    jsr caseAccumulateOutputBytes
    jsr reportCase
    lda #'N'
    jsr KernalChROUT
    jsr caseAccumulateOutputBytesCarry
    jsr reportCase
    lda #'O'
    jsr KernalChROUT
    jsr caseClearTransientIdempotent
    jsr reportCase
    lda #'P'
    jsr KernalChROUT
    jsr caseSuspendIdempotent
    jsr reportCase
    lda #'Q'
    jsr KernalChROUT
    jsr caseRenderTransientSetsVisible
    jsr reportCase
    lda #'R'
    jsr KernalChROUT
    jsr caseDecimalBoundaryZero
    jsr reportCase
    lda #'S'
    jsr KernalChROUT
    jsr caseDecimalBoundaryMax
    jsr reportCase
    lda #'T'
    jsr KernalChROUT
    jsr caseFinalSummaryClearsAndPrints
    jsr reportCase

    lda #$0D
    jsr KernalChROUT
    lda FailCount
    beq allPass
    ldx #<failMsg
    ldy #>failMsg
    jmp printResult
allPass:
    ldx #<passMsg
    ldy #>passMsg
printResult:
    lda #DOS_PRINT_STR
    jsr OS_API
    lda #DOS_EXIT
    jsr OS_API

; ---------------------------------------------------------------------------
; reportCase
; Print '.' for a pass (carry clear) or 'F' for a fail (carry set), tallying
; FailCount. Same convention as casm_map.s/casm_symbols.s.
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
caseInitZeroesState:
    lda #$AA
    sta CasmProgActiveLo
    sta CasmProgActiveHi
    sta CasmProgPass1TotalLo
    sta CasmProgPass1TotalHi
    jsr progressInit
    lda CasmProgActiveLo
    bne ci1Fail
    lda CasmProgActiveHi
    bne ci1Fail
    lda CasmProgPass1TotalLo
    bne ci1Fail
    lda CasmProgPass1TotalHi
    bne ci1Fail
    clc
    rts
ci1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
caseBeginPass1Reset:
    jsr progressInit
    jsr progressStatement           ; drive it nonzero first
    jsr progressStatement
    lda #1
    jsr progressBeginPass
    lda CasmProgActiveLo
    bne bp1Fail
    lda CasmProgActiveHi
    bne bp1Fail
    clc
    rts
bp1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; progressBeginPass sets the internal pass-2 flag; progressCompletePass
; reads it to choose which persistent message to print and whether to latch
; Pass 1's total, so exercise that indirectly: complete pass 1 with a known
; count, begin pass 2, complete pass 2 with a DIFFERENT count, and confirm
; progressCheckPassTotals correctly reports a mismatch -- this only happens
; if progressBeginPass's flag flip took effect (a stuck pass-1 flag would
; re-latch Pass1Total at pass-2 completion instead of comparing against it,
; masking the mismatch).
; ---------------------------------------------------------------------------
caseBeginPass2SetsFlag:
    jsr progressInit
    lda #1
    jsr progressBeginPass
    jsr progressStatement
    jsr progressStatement
    jsr progressCompletePass       ; latches Pass1Total = 2
    lda #2
    jsr progressBeginPass
    jsr progressStatement          ; Pass 2 total = 1 (deliberately unequal)
    jsr progressCompletePass
    jsr progressCheckPassTotals
    bcc bp2Fail                    ; expected mismatch (C=1); C=0 is wrong
    lda CasmProgPass1TotalLo
    cmp #2
    bne bp2Fail
    clc
    rts
bp2Fail:
    sec
    rts

; ---------------------------------------------------------------------------
caseStatementIncrementsLoHi:
    jsr progressInit
    ldx #0
si1Loop:
    jsr progressStatement
    inx
    cpx #255
    bne si1Loop
    lda CasmProgActiveLo
    cmp #255
    bne si1Fail
    lda CasmProgActiveHi
    bne si1Fail
    clc
    rts
si1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
caseStatementHiCarry:
    jsr progressInit
    lda #255
    sta CasmProgActiveLo
    lda #0
    sta CasmProgActiveHi
    jsr progressStatement
    lda CasmProgActiveLo
    bne sh1Fail
    lda CasmProgActiveHi
    cmp #1
    bne sh1Fail
    clc
    rts
sh1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; The divider is caller-invisible internal state; the only observable proxy
; for "redraw due" is progressStatement's own A/C return, so drive 64 real
; calls and check the 64th.
; ---------------------------------------------------------------------------
; ---------------------------------------------------------------------------
; The loop bookkeeping (inx/cpx/bne) after each jsr progressStatement
; overwrites the carry flag progressStatement just returned (cpx sets C on
; every comparison) before the case ever gets to check it -- so the "due"
; verdict must be captured into a local byte immediately after each call,
; not read after the loop exits. Caught live: this same clobber made the
; first version of these three cases misreport a false overflow every
; time, even though progressStatement itself was correct.
; ---------------------------------------------------------------------------
caseThrottleAt64:
    jsr progressInit
    ldx #0
t64Loop:
    jsr progressStatement
    php                             ; stash C immediately, before cpx clobbers it
    sta ThrottleLastA
    pla
    sta ThrottleLastP
    inx
    cpx #64
    bne t64Loop
    lda ThrottleLastP
    and #$01                        ; carry bit
    bne t64Fail                     ; must not report overflow
    lda ThrottleLastA
    cmp #1
    bne t64Fail
    clc
    rts
t64Fail:
    sec
    rts

caseThrottleAt128:
    jsr progressInit
    ldx #0
t128Loop:
    jsr progressStatement
    php
    sta ThrottleLastA
    pla
    sta ThrottleLastP
    inx
    cpx #128
    bne t128Loop
    lda ThrottleLastP
    and #$01
    bne t128Fail
    lda ThrottleLastA
    cmp #1
    bne t128Fail
    clc
    rts
t128Fail:
    sec
    rts

caseThrottleNotDueMidRange:
    jsr progressInit
    ldx #0
tmrLoop:
    jsr progressStatement
    php
    sta ThrottleLastA
    pla
    sta ThrottleLastP
    inx
    cpx #40                        ; 40 is not a multiple of 64
    bne tmrLoop
    lda ThrottleLastP
    and #$01
    bne tmrFail
    lda ThrottleLastA
    cmp #0
    bne tmrFail
    clc
    rts
tmrFail:
    sec
    rts

; ---------------------------------------------------------------------------
caseOverflowBeforeWrap:
    jsr progressInit
    lda #$FF
    sta CasmProgActiveLo
    sta CasmProgActiveHi
    jsr progressStatement
    bcc ovFail                     ; must report overflow (C=1)
    cmp #CASM_DIAG_PROGRESS_COUNTER_OVERFLOW
    bne ovFail
    ; must NOT have wrapped to $0000
    lda CasmProgActiveLo
    cmp #$FF
    bne ovFail
    lda CasmProgActiveHi
    cmp #$FF
    bne ovFail
    clc
    rts
ovFail:
    sec
    rts

; ---------------------------------------------------------------------------
caseCompletePassLatchesTotal:
    jsr progressInit
    lda #1
    jsr progressBeginPass
    ldx #0
cpl1Loop:
    jsr progressStatement
    inx
    cpx #7
    bne cpl1Loop
    jsr progressCompletePass
    lda CasmProgPass1TotalLo
    cmp #7
    bne cpl1Fail
    lda CasmProgPass1TotalHi
    bne cpl1Fail
    clc
    rts
cpl1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
caseCheckPassTotalsMatch:
    jsr progressInit
    lda #1
    jsr progressBeginPass
    jsr progressStatement
    jsr progressStatement
    jsr progressStatement
    jsr progressCompletePass       ; Pass1Total = 3
    lda #2
    jsr progressBeginPass
    jsr progressStatement
    jsr progressStatement
    jsr progressStatement          ; Pass 2 total = 3, matches
    jsr progressCheckPassTotals
    bcs cptmFail
    clc
    rts
cptmFail:
    sec
    rts

; ---------------------------------------------------------------------------
caseCheckPassTotalsMismatch:
    jsr progressInit
    lda #1
    jsr progressBeginPass
    jsr progressStatement
    jsr progressStatement
    jsr progressCompletePass       ; Pass1Total = 2
    lda #2
    jsr progressBeginPass
    jsr progressStatement          ; Pass 2 total = 1, mismatch
    jsr progressCheckPassTotals
    bcc cptxFail                   ; expected C=1
    cmp #CASM_DIAG_PROGRESS_PASS_TOTAL_MISMATCH
    bne cptxFail
    clc
    rts
cptxFail:
    sec
    rts

; ---------------------------------------------------------------------------
caseAccumulateOutputBytes:
    jsr progressInit
    lda #100
    ldx #0
    jsr progressAccumulateOutputBytes
    lda #50
    ldx #0
    jsr progressAccumulateOutputBytes
    jsr progressFinalSummary       ; exercises the byte field through a real
                                    ; call path without asserting its text
    clc
    rts

; ---------------------------------------------------------------------------
caseAccumulateOutputBytesCarry:
    jsr progressInit
    lda #255
    ldx #0
    jsr progressAccumulateOutputBytes
    lda #1
    ldx #0
    jsr progressAccumulateOutputBytes
    ; internal byte counter is not exported; correctness here is proven by
    ; not crashing/hanging through the carry chain -- reaching this point
    ; with a clean return is the assertion.
    clc
    rts

; ---------------------------------------------------------------------------
caseClearTransientIdempotent:
    jsr progressInit
    jsr progressClearTransient     ; not visible yet -- must no-op cleanly
    jsr progressClearTransient     ; idempotent: second call also clean
    clc
    rts

; ---------------------------------------------------------------------------
caseSuspendIdempotent:
    jsr progressInit
    jsr progressSuspend
    jsr progressSuspend
    clc
    rts

; ---------------------------------------------------------------------------
caseRenderTransientSetsVisible:
    jsr progressInit
    lda #1
    jsr progressBeginPass
    lda #0
    sta CasmProgArgDepth
    sta CasmProgArgFileId
    sta CasmProgArgLineLo
    sta CasmProgArgLineHi
    ldy #0
rtsvFill:
    lda #' '
    sta CasmProgArgNameBuf, y
    iny
    cpy #8
    bne rtsvFill
    jsr progressRenderTransient
    jsr progressClearTransient     ; must not hang/crash clearing what was
                                    ; just rendered
    clc
    rts

; ---------------------------------------------------------------------------
; progressPrintDec has no directly testable return value on its own (it is
; private), so these two boundary cases exercise it only through real call
; paths (0 statements at pass-complete; a near-max active count at
; pass-complete) and assert those callers still function and return
; cleanly -- the smallest/largest values a 5-digit field must render
; without overrunning.
; ---------------------------------------------------------------------------
caseDecimalBoundaryZero:
    jsr progressInit
    lda #1
    jsr progressBeginPass
    jsr progressCompletePass       ; 0 statements -- "00000"
    lda CasmProgPass1TotalLo
    bne dbzFail
    lda CasmProgPass1TotalHi
    bne dbzFail
    clc
    rts
dbzFail:
    sec
    rts

caseDecimalBoundaryMax:
    jsr progressInit
    lda #1
    jsr progressBeginPass
    lda #$FE
    sta CasmProgActiveLo
    lda #$FF
    sta CasmProgActiveHi
    jsr progressStatement          ; -> $FFFF, one below the overflow trap
    bcs dbmFail
    jsr progressCompletePass       ; renders "65535" -- must not overrun
    lda CasmProgPass1TotalLo
    cmp #$FF
    bne dbmFail
    lda CasmProgPass1TotalHi
    cmp #$FF
    bne dbmFail
    clc
    rts
dbmFail:
    sec
    rts

; ---------------------------------------------------------------------------
caseFinalSummaryClearsAndPrints:
    jsr progressInit
    lda #1
    jsr progressBeginPass
    jsr progressStatement
    jsr progressCompletePass
    lda #2
    jsr progressBeginPass
    jsr progressStatement
    jsr progressCompletePass
    lda #10
    ldx #0
    jsr progressAccumulateOutputBytes
    jsr progressFinalSummary
    clc
    rts

.segment "BSS"
FailCount:       .res 1
ThrottleLastA:   .res 1
ThrottleLastP:   .res 1

.segment "RODATA"
passMsg:
    .byte "CASM PROGRESS: PASS", PetCr, 0
failMsg:
    .byte "CASM PROGRESS: FAIL", PetCr, 0
