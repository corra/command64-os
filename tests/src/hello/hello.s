; tests/src/hello/hello.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 port of tests/src/hello/hello.asm.

.include "command64.inc"

.import __MAIN_START__

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    lda #<msg
    ldy #>msg
    jsr printString
    rts

printString:
    sta $22
    sty $23
    ldy #0
loop:
    lda ($22), y
    beq done
    jsr KernalChROUT
    iny
    jmp loop
done:
    rts

; "HELLO v0.1.0 (ca65 spike) - Hello from the C64 Disk!"
msg:
    .byte $48, $45, $4C, $4C, $4F, $20, $56, $30, $2E, $31, $2E, $30, $20
    .byte $28, $43, $41, $36, $35, $20, $53, $50, $49, $4B, $45, $29, $20
    .byte $2D, $20, $48, $45, $4C, $4C, $4F, $20, $46, $52, $4F, $4D, $20
    .byte $54, $48, $45, $20, $43, $36, $34, $20, $44, $49, $53, $4B, $21
    .byte $0D, $00
