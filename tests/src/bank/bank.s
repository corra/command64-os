; tests/src/bank/bank.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 RAM banking test.

.include "command64.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_bank.inc"

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

    ldx #0
write_loop_a:
    txa
    sta $A000, x
    inx
    bne write_loop_a

    ldx #0
verify_loop_a:
    txa
    cmp $A000, x
    bne test_fail
    inx
    bne verify_loop_a

    ldx #0
write_loop_b:
    txa
    eor #$FF
    sta $B000, x
    inx
    bne write_loop_b

    ldx #0
verify_loop_b:
    txa
    eor #$FF
    cmp $B000, x
    bne test_fail
    inx
    bne verify_loop_b

    lda #DOS_PRINT_STR
    ldx #<msgPass
    ldy #>msgPass
    jsr OS_API
    jmp exit

test_fail:
    lda #DOS_PRINT_STR
    ldx #<msgFail
    ldy #>msgFail
    jsr OS_API

exit:
    lda #DOS_EXIT
    jsr OS_API

; "BANKTEST V" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
; + "." + BUILD_NUMBER + " - Testing BASIC ROM Banking RAM access..."
msgStart:
    .byte $42, $41, $4E, $4B, $54, $45, $53, $54, $20, $56
    .byte VERSION_MAJOR, $2E, VERSION_MINOR, $2E, VERSION_STAGE, $2E
    .byte BUILD_NUMBER
    .byte $20, $2D, $20, $54, $45, $53, $54, $49, $4E, $47, $20
    .byte $42, $41, $53, $49, $43, $20, $52, $4F, $4D, $20, $42, $41, $4E
    .byte $4B, $49, $4E, $47, $20, $52, $41, $4D, $20, $41, $43, $43, $45
    .byte $53, $53, $2E, $2E, $2E, $0D, $00

; "RAM under BASIC ROM fully writable: PASS"
msgPass:
    .byte $52, $41, $4D, $20, $55, $4E, $44, $45, $52, $20, $42, $41, $53
    .byte $49, $43, $20, $52, $4F, $4D, $20, $46, $55, $4C, $4C, $59, $20
    .byte $57, $52, $49, $54, $41, $42, $4C, $45, $3A, $20, $50, $41, $53
    .byte $53, $0D, $00

; "Error: RAM under BASIC ROM not writable: FAIL"
msgFail:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $52, $41, $4D, $20, $55, $4E
    .byte $44, $45, $52, $20, $42, $41, $53, $49, $43, $20, $52, $4F, $4D
    .byte $20, $4E, $4F, $54, $20, $57, $52, $49, $54, $41, $42, $4C, $45
    .byte $3A, $20, $46, $41, $49, $4C, $0D, $00
