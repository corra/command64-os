; tests/src/apitest/apitest.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 port of tests/src/apitest/apitest.asm.

.include "command64.inc"

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

; "APITEST v0.1.0 (ca65 spike) - String output works!"
msg:
    .byte $41, $50, $49, $54, $45, $53, $54, $20, $56, $30, $2E, $31, $2E
    .byte $30, $20, $28, $43, $41, $36, $35, $20, $53, $50, $49, $4B, $45
    .byte $29, $20, $2D, $20, $53, $54, $52, $49, $4E, $47, $20, $4F, $55
    .byte $54, $50, $55, $54, $20, $57, $4F, $52, $4B, $53, $21, $0D, $00
