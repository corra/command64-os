; tests/src/hello/hello.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 port of tests/src/hello/hello.asm.

.include "command64.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_hello.inc"

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

; "HELLO V" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
; + "." + BUILD_NUMBER + " - Hello from the C64 Disk!"
msg:
    .byte $48, $45, $4C, $4C, $4F, $20, $56
    .byte VERSION_MAJOR, $2E, VERSION_MINOR, $2E, VERSION_STAGE, $2E
    .byte BUILD_NUMBER
    .byte $20, $2D, $20, $48, $45, $4C, $4C, $4F, $20, $46, $52, $4F, $4D, $20
    .byte $54, $48, $45, $20, $43, $36, $34, $20, $44, $49, $53, $4B, $21
    .byte $0D, $00
