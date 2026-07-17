; tests/src/sendcmd/sendcmd.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; Verifies DOS_SEND_COMMAND ($58): sends a harmless "8:I0" (initialize)
; command to device 8's command channel and prints the drive's response.

.include "command64.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_sendcmd.inc"

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

    ; DOS_SEND_COMMAND: X/Y = command string pointer, PrintPtrLo/Hi =
    ; caller-supplied output buffer pointer.
    lda #<respBuf
    sta PrintPtrLo
    lda #>respBuf
    sta PrintPtrHi

    ldx #<cmdStr
    ldy #>cmdStr
    lda #DOS_SEND_COMMAND
    jsr OS_API
    bcs send_err

    lda #DOS_PRINT_STR
    ldx #<msgOk
    ldy #>msgOk
    jsr OS_API

    lda #DOS_PRINT_STR
    ldx #<respBuf
    ldy #>respBuf
    jsr OS_API

    lda #$0D
    jsr KernalChROUT

    lda #DOS_EXIT
    jsr OS_API

send_err:
    lda #DOS_PRINT_STR
    ldx #<msgErr
    ldy #>msgErr
    jsr OS_API
    lda #DOS_EXIT
    jsr OS_API

cmdStr:
    .byte "8:I0", 0

msgStart:
    .byte "SENDCMDTEST V"
    .byte VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE, "."
    .byte BUILD_NUMBER
    .byte $0D, 0

msgOk:
    .byte "DOS_SEND_COMMAND OK - RESPONSE: ", 0

msgErr:
    .byte "DOS_SEND_COMMAND FAILED (TRANSPORT ERROR)", $0D, 0

respBuf:
    .res 40
