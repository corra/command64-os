; tests/src/vmmtest/vmmtest.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 port of tests/src/vmmtest/vmmtest.asm.

.include "command64.inc"

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '0'
.include "build_test_ca65_vmmtest.inc"

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

    ; Request 1 page (256 paragraphs = $0100)
    lda #DOS_ALLOC_MEM
    ldx #$00
    ldy #$01
    jsr OS_API
    bcs alloc_fail

    stx $64
    sty $65

    lda #DOS_PRINT_STR
    ldx #<msgOk
    ldy #>msgOk
    jsr OS_API

    ldx $64
    ldy $65
    lda #DOS_FREE_MEM
    jsr OS_API
    bcs free_fail

    lda #DOS_PRINT_STR
    ldx #<msgDone
    ldy #>msgDone
    jsr OS_API
    jmp exit

alloc_fail:
    lda #DOS_PRINT_STR
    ldx #<msgErrAlloc
    ldy #>msgErrAlloc
    jsr OS_API
    jmp exit

free_fail:
    lda #DOS_PRINT_STR
    ldx #<msgErrFree
    ldy #>msgErrFree
    jsr OS_API

exit:
    lda #DOS_EXIT
    jsr OS_API

; "VMMTEST V" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
; + "." + BUILD_NUMBER + " - Testing VMM Allocation via API..."
msgStart:
    .byte $56, $4D, $4D, $54, $45, $53, $54, $20, $56
    .byte VERSION_MAJOR, $2E, VERSION_MINOR, $2E, VERSION_STAGE, $2E
    .byte BUILD_NUMBER
    .byte $20, $2D, $20, $54, $45, $53, $54, $49, $4E, $47, $20, $56
    .byte $4D, $4D, $20, $41, $4C, $4C, $4F, $43, $41, $54, $49, $4F, $4E
    .byte $20, $56, $49, $41, $20, $41, $50, $49, $2E, $2E, $2E, $0D, $00
; "ALLOCATION SUCCESSFUL!"
msgOk:
    .byte $41, $4C, $4C, $4F, $43, $41, $54, $49, $4F, $4E, $20, $53, $55
    .byte $43, $43, $45, $53, $53, $46, $55, $4C, $21, $0D, $00
; "DEALLOCATION SUCCESSFUL. TEST COMPLETE."
msgDone:
    .byte $44, $45, $41, $4C, $4C, $4F, $43, $41, $54, $49, $4F, $4E, $20
    .byte $53, $55, $43, $43, $45, $53, $53, $46, $55, $4C, $2E, $20, $54
    .byte $45, $53, $54, $20, $43, $4F, $4D, $50, $4C, $45, $54, $45, $2E
    .byte $0D, $00
; "ERROR: MEMORY ALLOCATION FAILED."
msgErrAlloc:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $4D, $45, $4D, $4F, $52, $59
    .byte $20, $41, $4C, $4C, $4F, $43, $41, $54, $49, $4F, $4E, $20, $46
    .byte $41, $49, $4C, $45, $44, $2E, $0D, $00
; "ERROR: MEMORY DEALLOCATION FAILED."
msgErrFree:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $4D, $45, $4D, $4F, $52, $59
    .byte $20, $44, $45, $41, $4C, $4C, $4F, $43, $41, $54, $49, $4F, $4E
    .byte $20, $46, $41, $49, $4C, $45, $44, $2E, $0D, $00
