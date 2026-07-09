; tests/src/devtest/devtest.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 port of tests/src/devtest/devtest.asm.
;
; The strCaseN data strings and their #'t'/#'d'/#'m' comparison literals
; both went through Kick's .encoding petscii_mixed in the original, so both
; sides of each comparison were transformed identically and stayed equal.
; ca65 has no such pragma, so both sides are hardcoded here to the same
; precomputed byte ($54/$44/$4D -- see spike/ca65-conway's PETSCII note)
; to preserve that same invariant.

.include "command64.inc"

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '0'
.include "build_test_ca65_devtest.inc"

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

    ; --- TEST CASE 1: "8:testfile" ---
    lda #<strCase1
    sta PrintPtrLo
    lda #>strCase1
    sta PrintPtrHi

    ldx #PrintPtrLo
    lda #DOS_PARSE_PREFIX
    jsr OS_API
    sta resDev1
    php
    pla
    sta resFlags1
    ldy #0
    lda (PrintPtrLo), y
    sta resChar1

    ; --- TEST CASE 2: "10:data" ---
    lda #<strCase2
    sta PrintPtrLo
    lda #>strCase2
    sta PrintPtrHi

    ldx #PrintPtrLo
    lda #DOS_PARSE_PREFIX
    jsr OS_API
    sta resDev2
    php
    pla
    sta resFlags2
    ldy #0
    lda (PrintPtrLo), y
    sta resChar2

    ; --- TEST CASE 3: "myfile" ---
    lda #<strCase3
    sta PrintPtrLo
    lda #>strCase3
    sta PrintPtrHi

    ldx #PrintPtrLo
    lda #DOS_PARSE_PREFIX
    jsr OS_API
    sta resDev3
    php
    pla
    sta resFlags3
    ldy #0
    lda (PrintPtrLo), y
    sta resChar3

    ; --- PRINT DIAGNOSTIC REPORT ---
    lda #DOS_PRINT_STR
    ldx #<msgRpt1
    ldy #>msgRpt1
    jsr OS_API
    lda resDev1
    jsr printHex8
    jsr printCarryAndChar1

    lda #DOS_PRINT_STR
    ldx #<msgRpt2
    ldy #>msgRpt2
    jsr OS_API
    lda resDev2
    jsr printHex8
    jsr printCarryAndChar2

    lda #DOS_PRINT_STR
    ldx #<msgRpt3
    ldy #>msgRpt3
    jsr OS_API
    lda resDev3
    jsr printHex8
    jsr printCarryAndChar3

    ; --- VERIFY PASS/FAIL ---
    lda resDev1
    cmp #8
    bne test_fail
    lda resFlags1
    and #$01
    beq test_fail
    lda resChar1
    cmp #$54            ; 't' mapped -> 'T'
    bne test_fail

    lda resDev2
    cmp #10
    bne test_fail
    lda resFlags2
    and #$01
    beq test_fail
    lda resChar2
    cmp #$44            ; 'd' mapped -> 'D'
    bne test_fail

    lda resDev3
    cmp CurrentDevice
    bne test_fail
    lda resFlags3
    and #$01
    bne test_fail
    lda resChar3
    cmp #$4D            ; 'm' mapped -> 'M'
    bne test_fail

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

; --- HELPERS ---

printCarryAndChar1:
    lda resFlags1
    ldx resChar1
    jmp printCarryAndCharCommon
printCarryAndChar2:
    lda resFlags2
    ldx resChar2
    jmp printCarryAndCharCommon
printCarryAndChar3:
    lda resFlags3
    ldx resChar3
printCarryAndCharCommon:
    pha
    txa
    pha

    lda #DOS_PRINT_CHAR
    ldx #' '
    jsr OS_API

    lda #DOS_PRINT_CHAR
    ldx #$43            ; 'C'
    jsr OS_API
    lda #DOS_PRINT_CHAR
    ldx #'='
    jsr OS_API

    pla
    tay
    pla
    and #$01
    jsr printHex8

    lda #DOS_PRINT_CHAR
    ldx #' '
    jsr OS_API

    tya
    tax
    lda #DOS_PRINT_CHAR
    jsr OS_API

    lda #DOS_PRINT_CHAR
    ldx #$0D
    jsr OS_API
    rts

printHex8:
    pha
    lsr
    lsr
    lsr
    lsr
    jsr printNibble
    pla
    and #$0F
printNibble:
    cmp #10
    bcc pnDigit
    clc
    adc #7
pnDigit:
    adc #48
    tax
    lda #DOS_PRINT_CHAR
    jsr OS_API
    rts

; --- DATA ---

resDev1:   .byte 0
resFlags1: .byte 0
resChar1:  .byte 0

resDev2:   .byte 0
resFlags2: .byte 0
resChar2:  .byte 0

resDev3:   .byte 0
resFlags3: .byte 0
resChar3:  .byte 0

; "DEVTEST V" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
; + "." + BUILD_NUMBER + " - Testing DOS_PARSE_PREFIX API call..."
msgStart:
    .byte $44, $45, $56, $54, $45, $53, $54, $20, $56
    .byte VERSION_MAJOR, $2E, VERSION_MINOR, $2E, VERSION_STAGE, $2E
    .byte BUILD_NUMBER
    .byte $20, $2D, $20, $54, $45, $53, $54, $49, $4E, $47, $20, $44
    .byte $4F, $53, $5F, $50, $41, $52, $53, $45, $5F, $50, $52, $45, $46
    .byte $49, $58, $20, $41, $50, $49, $20, $43, $41, $4C, $4C, $2E, $2E
    .byte $2E, $0D, $00
; "DOS_PARSE_PREFIX API: PASS"
msgPass:
    .byte $44, $4F, $53, $5F, $50, $41, $52, $53, $45, $5F, $50, $52, $45
    .byte $46, $49, $58, $20, $41, $50, $49, $3A, $20, $50, $41, $53, $53
    .byte $0D, $00
; "Error: DOS_PARSE_PREFIX API mismatch: FAIL"
msgFail:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $44, $4F, $53, $5F, $50, $41
    .byte $52, $53, $45, $5F, $50, $52, $45, $46, $49, $58, $20, $41, $50
    .byte $49, $20, $4D, $49, $53, $4D, $41, $54, $43, $48, $3A, $20, $46
    .byte $41, $49, $4C, $0D, $00

; "Case 1: DEV="
msgRpt1:
    .byte $43, $41, $53, $45, $20, $31, $3A, $20, $44, $45, $56, $3D, $00
; "Case 2: DEV="
msgRpt2:
    .byte $43, $41, $53, $45, $20, $32, $3A, $20, $44, $45, $56, $3D, $00
; "Case 3: DEV="
msgRpt3:
    .byte $43, $41, $53, $45, $20, $33, $3A, $20, $44, $45, $56, $3D, $00

; "8:testfile"
strCase1:
    .byte $38, $3A, $54, $45, $53, $54, $46, $49, $4C, $45, $00
; "10:data"
strCase2:
    .byte $31, $30, $3A, $44, $41, $54, $41, $00
; "myfile"
strCase3:
    .byte $4D, $59, $46, $49, $4C, $45, $00
