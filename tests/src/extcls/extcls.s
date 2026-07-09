; tests/src/extcls/extcls.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 port of tests/src/extcls/extcls.asm.

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
    ldx #<msgStart
    ldy #>msgStart
    jsr OS_API

    lda #$93            ; clear screen
    jsr KernalChROUT
    rts

; "EXTCLS v0.1.0 (ca65 spike) - Clearing screen"
msgStart:
    .byte $45, $58, $54, $43, $4C, $53, $20, $56, $30, $2E, $31, $2E, $30
    .byte $20, $28, $43, $41, $36, $35, $20, $53, $50, $49, $4B, $45, $29
    .byte $20, $2D, $20, $43, $4C, $45, $41, $52, $49, $4E, $47, $20, $53
    .byte $43, $52, $45, $45, $4E, $0D, $00
