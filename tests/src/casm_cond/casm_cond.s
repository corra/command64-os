; tests/src/casm_cond/casm_cond.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 15 WP95 standalone conditional-nesting state-machine harness.
; Exercises cond.s (condResetForPass/condOpenIf/condElseif/condElse/
; condEndif/condCurrentlyEmitting/condTopParentEmitting/condAtEof/
; condSiteDecision) directly -- there is no pass-driver call site yet
; (WP96 wires it into casmRunPass), so this cannot be a real .s source
; fixture. cond.s links with zero dependencies beyond common.inc.
;
; Convention (matching casm_scope.s / casm_symbols.s): one flat sequence
; of fixtures, each returning C clear on pass / C set on fail; reportCase
; prints '.' or 'F' and tallies FailCount.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_cond.inc"

.import __MAIN_START__
.import condResetForPass
.import condOpenIf
.import condElseif
.import condElse
.import condEndif
.import condCurrentlyEmitting
.import condTopParentEmitting
.import condAtEof
.import condSiteDecision
.import CasmCondDepth
.import CasmCondOpenLocLineLo
.import CasmCondOpenLocLineHi
.import CasmCondOpenLocColumn
.import CasmCondOpenLocFileId
.import CasmCondOpenLineLo

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda #0
    sta FailCount

    jsr caseResetEmitting
    jsr reportCase
    jsr caseIfTrue
    jsr reportCase
    jsr caseIfFalse
    jsr reportCase
    jsr caseElseOfFalse
    jsr reportCase
    jsr caseElseOfTrue
    jsr reportCase
    jsr caseElseifLadder
    jsr reportCase
    jsr caseNested
    jsr reportCase
    jsr caseNestedInSkipped
    jsr reportCase
    jsr caseNestingOverflow
    jsr reportCase
    jsr caseWithoutIf
    jsr reportCase
    jsr caseElseAfterElse
    jsr reportCase
    jsr caseAtEof
    jsr reportCase
    jsr caseTopParentEmitting
    jsr reportCase
    jsr caseSiteRoundTrip
    jsr reportCase
    jsr caseSiteOverflow
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
; Helpers
; ---------------------------------------------------------------------------
; expectEmit: A = expected condCurrentlyEmitting result. Returns C set
; (fail) on mismatch, C clear (pass) on match.
expectEmit:
    sta Expected
    jsr condCurrentlyEmitting
    cmp Expected
    beq @ok
    sec
    rts
@ok:
    clc
    rts

; openIf: A = decision. Sets a fixed dummy location first, calls condOpenIf.
; Returns condOpenIf's C/A verbatim.
openIf:
    pha
    lda #10
    sta CasmCondOpenLocLineLo
    lda #0
    sta CasmCondOpenLocLineHi
    lda #1
    sta CasmCondOpenLocColumn
    sta CasmCondOpenLocFileId
    pla
    jmp condOpenIf

; ---------------------------------------------------------------------------
; Case 1: reset -> emitting (depth 0)
; ---------------------------------------------------------------------------
caseResetEmitting:
    jsr condResetForPass
    lda #1
    jmp expectEmit

; ---------------------------------------------------------------------------
; Case 2: .if <true> -> emitting; .endif -> emitting, depth 0
; ---------------------------------------------------------------------------
caseIfTrue:
    jsr condResetForPass
    lda #1
    jsr openIf
    bcs @fail
    lda #1
    jsr expectEmit
    bcs @fail
    jsr condEndif
    bcs @fail
    lda CasmCondDepth
    bne @fail
    lda #1
    jmp expectEmit
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Case 3: .if <false> -> not emitting; .endif -> emitting
; ---------------------------------------------------------------------------
caseIfFalse:
    jsr condResetForPass
    lda #0
    jsr openIf
    bcs @fail
    lda #0
    jsr expectEmit
    bcs @fail
    jsr condEndif
    bcs @fail
    lda #1
    jmp expectEmit
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Case 4: .if <false> / .else -> emitting
; ---------------------------------------------------------------------------
caseElseOfFalse:
    jsr condResetForPass
    lda #0
    jsr openIf
    bcs @fail
    jsr condElse
    bcs @fail
    lda #1
    jsr expectEmit
    bcs @fail
    jsr condEndif
    bcs @fail
    clc
    rts
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Case 5: .if <true> / .else -> not emitting
; ---------------------------------------------------------------------------
caseElseOfTrue:
    jsr condResetForPass
    lda #1
    jsr openIf
    bcs @fail
    jsr condElse
    bcs @fail
    lda #0
    jsr expectEmit
    bcs @fail
    jsr condEndif
    clc
    rts
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Case 6: .if 0 / .elseif 0 / .elseif 1 -> emitting / .else -> not emitting
; ---------------------------------------------------------------------------
caseElseifLadder:
    jsr condResetForPass
    lda #0
    jsr openIf
    bcs @fail
    lda #0
    jsr condElseif
    bcs @fail
    lda #0
    jsr expectEmit
    bcs @fail
    lda #1
    jsr condElseif
    bcs @fail
    lda #1
    jsr expectEmit
    bcs @fail
    jsr condElse
    bcs @fail
    lda #0
    jsr expectEmit
    bcs @fail
    jsr condEndif
    clc
    rts
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Case 7: .if 1 / .if 0 -> not emitting; inner .endif -> emitting; outer -> 1
; ---------------------------------------------------------------------------
caseNested:
    jsr condResetForPass
    lda #1
    jsr openIf
    bcs @fail
    lda #0
    jsr openIf
    bcs @fail
    lda #0
    jsr expectEmit
    bcs @fail
    jsr condEndif
    bcs @fail
    lda #1
    jsr expectEmit
    bcs @fail
    jsr condEndif
    bcs @fail
    lda #1
    jmp expectEmit
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Case 8: .if 0 / .if 1 -> not emitting (parent suppressed); inner .else
;         still not emitting; both .endif
; ---------------------------------------------------------------------------
caseNestedInSkipped:
    jsr condResetForPass
    lda #0
    jsr openIf
    bcs @fail
    lda #1
    jsr openIf
    bcs @fail
    lda #0
    jsr expectEmit
    bcs @fail
    jsr condElse
    bcs @fail
    lda #0
    jsr expectEmit
    bcs @fail
    jsr condEndif
    bcs @fail
    jsr condEndif
    bcs @fail
    lda #1
    jmp expectEmit
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Case 9: 16 x .if OK; 17th -> CASM_DIAG_CONDITIONAL_NESTING_OVERFLOW
; ---------------------------------------------------------------------------
caseNestingOverflow:
    jsr condResetForPass
    lda #CASM_COND_MAX_DEPTH
    sta SaveX                     ; condOpenIf clobbers X -- count in memory
@push:
    lda #1
    jsr openIf
    bcs @fail
    dec SaveX
    bne @push
    ; 17th
    lda #1
    jsr openIf
    bcc @fail                    ; must have failed
    cmp #CASM_DIAG_CONDITIONAL_NESTING_OVERFLOW
    bne @fail
    clc
    rts
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Case 10: .else / .elseif / .endif at depth 0 -> CONDITIONAL_WITHOUT_IF
; ---------------------------------------------------------------------------
caseWithoutIf:
    jsr condResetForPass
    jsr condElse
    bcc @fail
    cmp #CASM_DIAG_CONDITIONAL_WITHOUT_IF
    bne @fail
    lda #0
    jsr condElseif
    bcc @fail
    cmp #CASM_DIAG_CONDITIONAL_WITHOUT_IF
    bne @fail
    jsr condEndif
    bcc @fail
    cmp #CASM_DIAG_CONDITIONAL_WITHOUT_IF
    bne @fail
    clc
    rts
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Case 11: .if 0 / .else / .else -> 2nd -> ELSE_AFTER_ELSE; .elseif too
; ---------------------------------------------------------------------------
caseElseAfterElse:
    jsr condResetForPass
    lda #0
    jsr openIf
    bcs @fail
    jsr condElse
    bcs @fail
    jsr condElse
    bcc @fail
    cmp #CASM_DIAG_CONDITIONAL_ELSE_AFTER_ELSE
    bne @fail
    lda #1
    jsr condElseif
    bcc @fail
    cmp #CASM_DIAG_CONDITIONAL_ELSE_AFTER_ELSE
    bne @fail
    jsr condEndif
    clc
    rts
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Case 12: condAtEof balanced -> OK; with a level open -> UNTERMINATED,
;          the open location readable.
; ---------------------------------------------------------------------------
caseAtEof:
    jsr condResetForPass
    jsr condAtEof
    bcs @fail
    lda #1
    jsr openIf
    bcs @fail
    jsr condAtEof
    bcc @fail
    cmp #CASM_DIAG_UNTERMINATED_CONDITIONAL
    bne @fail
    lda CasmCondOpenLineLo          ; level 0's stamped line == openIf's 10
    cmp #10
    bne @fail
    jsr condEndif
    clc
    rts
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Case 13: condTopParentEmitting
; ---------------------------------------------------------------------------
caseTopParentEmitting:
    jsr condResetForPass
    jsr condTopParentEmitting        ; depth 0 -> 1
    cmp #1
    bne @fail
    lda #1
    jsr openIf                       ; .if 1
    bcs @fail
    jsr condTopParentEmitting        ; parent (depth 0) was emitting -> 1
    cmp #1
    bne @fail
    lda #0
    jsr openIf                       ; .if 0 nested
    bcs @fail
    jsr condTopParentEmitting        ; parent (.if 1) still emitting -> 1
    cmp #1
    bne @fail
    lda #1
    jsr openIf                       ; .if 1 nested under the .if 0
    bcs @fail
    jsr condTopParentEmitting        ; parent (.if 0) not emitting -> 0
    cmp #0
    bne @fail
    jsr condEndif
    jsr condEndif
    jsr condEndif
    clc
    rts
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Case 14: condSiteDecision Pass 1 record then Pass 2 replay of 1,0,1,1,0.
; ---------------------------------------------------------------------------
caseSiteRoundTrip:
    jsr condResetForPass
    ldx #0
@rec:
    stx SaveX
    lda decSeq, x
    ldx #1                           ; pass 1
    jsr condSiteDecision
    bcs @fail
    ldx SaveX
    cmp decSeq, x                    ; pass 1 returns the passed-in value
    bne @fail
    inx
    cpx #5
    bne @rec
    ; reset the counter only (bitmap kept) -- condResetForPass does exactly
    ; that plus depth, which is already 0.
    jsr condResetForPass
    ldx #0
@rep:
    stx SaveX
    lda #0                           ; deliberately wrong -- pass 2 ignores it
    ldx #2                           ; pass 2
    jsr condSiteDecision
    bcs @fail
    ldx SaveX
    cmp decSeq, x
    bne @fail
    inx
    cpx #5
    bne @rep
    clc
    rts
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Case 15: 512 records OK, 513th -> CONDITIONAL_SITE_OVERFLOW
; ---------------------------------------------------------------------------
caseSiteOverflow:
    jsr condResetForPass
    lda #<CASM_COND_MAX_SITES
    sta CountLo
    lda #>CASM_COND_MAX_SITES
    sta CountHi
@loop:
    lda #1
    ldx #1
    jsr condSiteDecision
    bcs @fail
    dec CountLo
    lda CountLo
    cmp #$FF
    bne @noBorrow
    dec CountHi
@noBorrow:
    lda CountLo
    ora CountHi
    bne @loop
    ; counter is now 512 -- next call overflows
    lda #1
    ldx #1
    jsr condSiteDecision
    bcc @fail
    cmp #CASM_DIAG_CONDITIONAL_SITE_OVERFLOW
    bne @fail
    clc
    rts
@fail:
    sec
    rts

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
decSeq: .byte 1, 0, 1, 1, 0

passMsg: .byte "CASM COND: PASS", PetCr, 0
failMsg: .byte "CASM COND: FAIL", PetCr, 0

.segment "BSS"

FailCount: .res 1
Expected:  .res 1
SaveX:     .res 1
CountLo:   .res 1
CountHi:   .res 1
