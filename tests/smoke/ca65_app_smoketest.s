; tests/smoke/ca65_app_smoketest.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; Minimal source for proving add_ca65_app's versioning/link/relocation path.

.include "command64.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_ca65_app_smoketest.inc"

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

msg:
    .byte "CA65 SMOKETEST V"
    .byte VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE, "."
    .byte BUILD_NUMBER
    .byte $0D, $00
