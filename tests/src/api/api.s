; tests/src/api/api.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 API test.

.include "command64.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_api.inc"

.import __MAIN_START__

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT

    ; Print header
    lda #DOS_PRINT_STR
    ldx #<msg
    ldy #>msg
    jsr OS_API

    ; --- Test 1: DOS_GET_SYSTEM_INFO with Null Pointer ---
    lda #DOS_GET_SYSTEM_INFO
    ldx #0
    ldy #0
    jsr OS_API
    bcc test_fail          ; Carry must be set on null pointer error
    cmp #DOS_ERR_INVALID_ARG
    bne test_fail          ; Error code must be DOS_ERR_INVALID_ARG ($04)

    ; --- Test 2: DOS_GET_SYSTEM_INFO with Valid Buffer ---
    ; Setup guard bytes
    lda #$AA
    sta sys_guard_pre
    lda #$55
    sta sys_guard_post

    lda #DOS_GET_SYSTEM_INFO
    ldx #<sys_buf
    ldy #>sys_buf
    jsr OS_API
    bcs test_fail          ; Carry must be clear on success
    cmp #DOS_ERR_OK
    bne test_fail          ; Status must be DOS_ERR_OK ($00)

    ; Verify Guard Bytes
    lda sys_guard_pre
    cmp #$AA
    bne test_fail
    lda sys_guard_post
    cmp #$55
    bne test_fail

    ; Verify StructVersion (byte 0) == 1
    lda sys_buf + SYS_INFO_OFF_VER
    cmp #1
    bne test_fail

    ; Verify StructSize (byte 1) == 24
    lda sys_buf + SYS_INFO_OFF_SIZE
    cmp #SYS_INFO_SIZE
    bne test_fail

    ; Verify OsMajor (byte 2) == 4
    lda sys_buf + SYS_INFO_OFF_OS_MAJ
    cmp #4
    bne test_fail

    ; Verify OsMinor (byte 3) == 0
    lda sys_buf + SYS_INFO_OFF_OS_MIN
    cmp #0
    bne test_fail

    ; Verify UserProgStart (bytes 7-8) == $0800
    lda sys_buf + SYS_INFO_OFF_PROG_LO
    cmp #$00
    bne test_fail
    lda sys_buf + SYS_INFO_OFF_PROG_HI
    cmp #$08
    bne test_fail

    ; Verify UserProgEnd (bytes 9-10) == $BFFF
    lda sys_buf + SYS_INFO_OFF_END_LO
    cmp #$FF
    bne test_fail
    lda sys_buf + SYS_INFO_OFF_END_HI
    cmp #$BF
    bne test_fail

    ; Verify AppMaxSlots (byte 20) == 16
    lda sys_buf + SYS_INFO_OFF_MAX_SLOT
    cmp #16
    bne test_fail

    ; Print Success Message
    lda #DOS_PRINT_STR
    ldx #<pass_msg
    ldy #>pass_msg
    jsr OS_API

    lda #DOS_EXIT
    jsr OS_API

test_fail:
    lda #DOS_PRINT_STR
    ldx #<fail_msg
    ldy #>fail_msg
    jsr OS_API

    lda #DOS_EXIT
    jsr OS_API

; "APITEST V" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
; + "." + BUILD_NUMBER + " - String output works!"
msg:
    .byte $41, $50, $49, $54, $45, $53, $54, $20, $56
    .byte VERSION_MAJOR, $2E, VERSION_MINOR, $2E, VERSION_STAGE, $2E
    .byte BUILD_NUMBER
    .byte $20, $2D, $20, $53, $54, $52, $49, $4E, $47, $20, $4F, $55
    .byte $54, $50, $55, $54, $20, $57, $4F, $52, $4B, $53, $21, $0D, $00

pass_msg:
    .byte $0D, $44, $4F, $53, $5F, $47, $45, $54, $5F, $53, $59, $53, $54, $45, $4D, $5F, $49, $4E, $46, $4F, $20, $50, $41, $53, $53, $45, $44, $21, $0D, $00

fail_msg:
    .byte $0D, $41, $50, $49, $20, $54, $45, $53, $54, $20, $46, $41, $49, $4C, $45, $44, $21, $0D, $00

.segment "BSS"
sys_guard_pre:  .res 1
sys_buf:        .res 24
sys_guard_post: .res 1
