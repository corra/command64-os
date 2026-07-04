// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors

.encoding "petscii_mixed"
.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "0"
#import "build_test_hello.inc"

#import "build_config.inc"
* = UserProgStart "Hello"
    lda #<msg
    ldy #>msg
    jsr printString
    rts

msg: .text "HELLO v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE + "." + BUILD_NUMBER
     .text " - Hello from the C64 Disk!"
     .byte $0d, 0

printString:
    sta $22
    sty $23
    ldy #0
loop:
    lda ($22), y
    beq done
    jsr $ffd2 // CHROUT
    iny
    jmp loop
done:
    rts
