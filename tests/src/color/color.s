; tests/src/color/color.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 port of tests/src/color/color.asm.

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

    inc $D020
    rts

; "COLOR v0.1.0 (ca65 spike) - Cycling border color"
msgStart:
    .byte $43, $4F, $4C, $4F, $52, $20, $56, $30, $2E, $31, $2E, $30, $20
    .byte $28, $43, $41, $36, $35, $20, $53, $50, $49, $4B, $45, $29, $20
    .byte $2D, $20, $43, $59, $43, $4C, $49, $4E, $47, $20, $42, $4F, $52
    .byte $44, $45, $52, $20, $43, $4F, $4C, $4F, $52, $0D, $00
