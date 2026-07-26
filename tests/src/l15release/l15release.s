; tests/src/l15release/l15release.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Verifies DOS_RELEASE_L15 ($5B) against a real/true-emulated drive.
; Reproduces the exact conflict diagnosed in
; brain/plans/label-l15-cache-release.md before proving the fix, rather
; than merely asserting it:
;
;   1. DOS_SEND_COMMAND leaves KERNAL LFN 15 genuinely open on device 8
;      (sendSA15Command never closes it -- that's the whole point of the
;      OS's persistent-open cache, ensureL15Open/L15Device in file.asm).
;   2. A raw KernalOPEN of LFN 15 (exactly what an external program like
;      LABEL does, with no visibility into that cache) must then FAIL
;      with KERNAL error 2 (FILE ALREADY OPEN) -- proving the conflict is
;      real, not just a claim from reading the source.
;   3. DOS_RELEASE_L15, called with LFN 15 still genuinely open (no manual
;      close first) -- matches LABEL's own entry-side usage, and the
;      primitive must actively close LFN 15 itself, not just reset a
;      flag and trust the caller already closed it.
;   4. The same raw KernalOPEN must now SUCCEED.
;   5. Closing it and calling DOS_RELEASE_L15 again (mirroring LABEL's own
;      labelExit sequence), then a further DOS_SEND_COMMAND must still
;      succeed cleanly -- proving the fix doesn't regress the normal
;      caching path for future callers.
;
; This cannot be an automated pass/fail harness (it depends on real IEC/
; KERNAL state against an actual drive), matching tests/src/sendcmd/
; sendcmd.s's own precedent -- run manually in VICE with true drive
; emulation and read the printed results.

.include "command64.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_l15release.inc"

.import __MAIN_START__

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT

    lda #DOS_PRINT_STR
    ldx #<msgStart
    ldy #>msgStart
    jsr OS_API

    ; --- Step 1: DOS_SEND_COMMAND leaves LFN 15 open on device 8 ---
    lda #<respBuf
    sta PrintPtrLo
    lda #>respBuf
    sta PrintPtrHi
    ldx #<cmdStr
    ldy #>cmdStr
    lda #DOS_SEND_COMMAND
    jsr OS_API
    bcs step1Fail

    lda #DOS_PRINT_STR
    ldx #<msg1Ok
    ldy #>msg1Ok
    jsr OS_API
    jmp step2

step1Fail:
    lda #DOS_PRINT_STR
    ldx #<msg1Fail
    ldy #>msg1Fail
    jsr OS_API
    jmp allDone

    ; --- Step 2: raw OPEN of LFN 15 must FAIL (FILE ALREADY OPEN) ---
step2:
    jsr rawOpen15
    bcc step2UnexpectedOk

    cmp #2
    beq step2Ok
    ; Some other error code -- print it, but still treat as "did fail",
    ; which is the property this step actually needs.
    sta LastErrCode
    lda #DOS_PRINT_STR
    ldx #<msg2FailOther
    ldy #>msg2FailOther
    jsr OS_API
    jsr printErrCode
    jmp step3

step2Ok:
    lda #DOS_PRINT_STR
    ldx #<msg2Ok
    ldy #>msg2Ok
    jsr OS_API
    jmp step3

step2UnexpectedOk:
    ; OPEN succeeded when it should have conflicted -- close it so step 3
    ; isn't left holding a real, unaccounted-for open channel, then report
    ; the failure and stop (the whole premise this test exists to prove
    ; didn't reproduce; see the plan's Stop Conditions).
    lda #15
    jsr KernalCLOSE
    lda #DOS_PRINT_STR
    ldx #<msg2Fail
    ldy #>msg2Fail
    jsr OS_API
    jmp allDone

    ; --- Step 3: DOS_RELEASE_L15, with LFN 15 still genuinely open from
    ; step 1 (no manual close first) -- matches LABEL's own entry-side
    ; usage exactly: the primitive must actively close LFN 15 itself when
    ; the cache says it's open, not merely reset a flag and trust the
    ; caller already closed it (that weaker contract was tried first and
    ; confirmed insufficient -- LABEL's own first OPEN of LFN 15 kept
    ; failing, since nothing had actually closed the real channel yet). ---
step3:
    lda #DOS_RELEASE_L15
    jsr OS_API

    lda #DOS_PRINT_STR
    ldx #<msg3Ok
    ldy #>msg3Ok
    jsr OS_API

    ; --- Step 4: raw OPEN of LFN 15 must now SUCCEED ---
    jsr rawOpen15
    bcs step4Fail

    lda #DOS_PRINT_STR
    ldx #<msg4Ok
    ldy #>msg4Ok
    jsr OS_API
    jmp step5

step4Fail:
    sta LastErrCode
    lda #DOS_PRINT_STR
    ldx #<msg4Fail
    ldy #>msg4Fail
    jsr OS_API
    jsr printErrCode
    jmp allDone

    ; --- Step 5: close LFN 15, release again (mirrors LABEL's labelExit),
    ; then confirm DOS_SEND_COMMAND still works cleanly afterward ---
step5:
    lda #15
    jsr KernalCLOSE
    lda #DOS_RELEASE_L15
    jsr OS_API

    lda #<respBuf
    sta PrintPtrLo
    lda #>respBuf
    sta PrintPtrHi
    ldx #<cmdStr
    ldy #>cmdStr
    lda #DOS_SEND_COMMAND
    jsr OS_API
    bcs step5Fail

    lda #DOS_PRINT_STR
    ldx #<msg5Ok
    ldy #>msg5Ok
    jsr OS_API
    jmp allDone

step5Fail:
    lda #DOS_PRINT_STR
    ldx #<msg5Fail
    ldy #>msg5Fail
    jsr OS_API

allDone:
    lda #DOS_EXIT
    jsr OS_API

; ---------------------------------------------------------------------------
; rawOpen15
; Opens KERNAL LFN 15 directly on device 8, no filename -- exactly what
; label.s's openChannels does, deliberately bypassing ensureL15Open.
; Output: Carry/A = KernalOPEN's own result.
; ---------------------------------------------------------------------------
rawOpen15:
    lda #0
    jsr KernalSETNAM
    lda #15
    ldx #8
    ldy #15
    jsr KernalSETLFS
    jsr KernalOPEN
    rts

; ---------------------------------------------------------------------------
; printErrCode
; Prints LastErrCode as two decimal digits followed by CR. Same idiom as
; label.s's own printErrCode (see label.s and the plan for why).
; ---------------------------------------------------------------------------
printErrCode:
    lda LastErrCode
    ldx #$2F
pecTens:
    inx
    sec
    sbc #10
    bcs pecTens
    adc #10
    pha
    txa
    jsr KernalChROUT
    pla
    clc
    adc #'0'
    jsr KernalChROUT
    lda #$0D
    jsr KernalChROUT
    rts

cmdStr:
    .byte "8:I0", 0

msgStart:
    .byte "L15RELEASE TEST V"
    .byte VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE, "."
    .byte BUILD_NUMBER
    .byte $0D, 0

msg1Ok:
    .byte "1: DOS_SEND_COMMAND OPENED LFN15 - OK", $0D, 0
msg1Fail:
    .byte "1: DOS_SEND_COMMAND FAILED (TRANSPORT) - ABORT", $0D, 0

msg2Ok:
    .byte "2: RAW OPEN LFN15 FAILED WITH ERROR 02 - OK (CONFLICT REPRODUCED)", $0D, 0
msg2FailOther:
    .byte "2: RAW OPEN LFN15 FAILED WITH ERROR ", 0
msg2Fail:
    .byte "2: RAW OPEN LFN15 UNEXPECTEDLY SUCCEEDED - FAIL", $0D, 0

msg3Ok:
    .byte "3: DOS_RELEASE_L15 CALLED", $0D, 0

msg4Ok:
    .byte "4: RAW OPEN LFN15 SUCCEEDED - OK (CACHE RELEASED)", $0D, 0
msg4Fail:
    .byte "4: RAW OPEN LFN15 STILL FAILED WITH ERROR ", 0

msg5Ok:
    .byte "5: DOS_SEND_COMMAND AFTER RELEASE - OK (NO REGRESSION)", $0D, 0
msg5Fail:
    .byte "5: DOS_SEND_COMMAND AFTER RELEASE FAILED - FAIL", $0D, 0

respBuf:
    .res 40

LastErrCode:
    .res 1
