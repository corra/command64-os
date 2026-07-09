; tests/src/extcls/extcls.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 port of tests/src/extcls/extcls.asm.

.include "command64.inc"

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '0'
.include "build_test_ca65_extcls.inc"

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

    lda #$93            ; clear screen
    jsr KernalChROUT
    rts

; "EXTCLS V" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
; + "." + BUILD_NUMBER + " - Clearing screen"
msgStart:
    .byte $45, $58, $54, $43, $4C, $53, $20, $56
    .byte VERSION_MAJOR, $2E, VERSION_MINOR, $2E, VERSION_STAGE, $2E
    .byte BUILD_NUMBER
    .byte $20, $2D, $20, $43, $4C, $45, $41, $52, $49, $4E, $47, $20, $53
    .byte $43, $52, $45, $45, $4E, $0D, $00
