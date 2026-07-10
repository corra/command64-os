; tests/src/api/api.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 API test.

.include "command64.inc"

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '0'
.include "build_test_api.inc"

.import __MAIN_START__

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT

    lda #DOS_PRINT_STR
    ldx #<msg
    ldy #>msg
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
