; tests/src/vmm/vmm.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 VMM alloc/free/read/write test.

.include "command64.inc"

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '0'
.include "build_test_vmm.inc"

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
    bcc alloc_ok
    jmp alloc_fail
alloc_ok:

    ; Remember the allocated segment identity (SegHi/Bank) for the
    ; DOS_VMM_READ/WRITE round-trip below and the DOS_FREE_MEM call at exit.
    stx $64
    sty $65

    lda #DOS_PRINT_STR
    ldx #<msgOk
    ldy #>msgOk
    jsr OS_API

    ; --- DOS_VMM_WRITE/DOS_VMM_READ round-trip ---
    ; Write testPattern to the allocated segment at offset 0, read it back
    ; into a separate C64 RAM buffer, and confirm a byte-exact match.
    lda #0
    sta VmmSegLo
    sta VmmOffLo
    sta VmmOffHi
    lda $64
    sta VmmSegHi
    lda $65
    sta VmmBank

    ldx #<testPattern
    ldy #>testPattern
    lda #16
    sta HexValLo
    lda #0
    sta HexValHi
    lda #DOS_VMM_WRITE
    jsr OS_API
    bcs vmmwrite_fail

    ; VmmSegLo/Hi/OffLo/Hi/Bank are unchanged by the write call — read back
    ; from the same Seg:Off into a different C64 RAM buffer.
    ldx #<readBack
    ldy #>readBack
    lda #16
    sta HexValLo
    lda #0
    sta HexValHi
    lda #DOS_VMM_READ
    jsr OS_API
    bcs vmmread_fail

    ldx #0
compareLoop:
    lda testPattern,x
    cmp readBack,x
    bne compare_fail
    inx
    cpx #16
    bne compareLoop

    lda #DOS_PRINT_STR
    ldx #<msgRwOk
    ldy #>msgRwOk
    jsr OS_API
    jmp doFree

compare_fail:
    lda #DOS_PRINT_STR
    ldx #<msgRwMismatch
    ldy #>msgRwMismatch
    jsr OS_API
    jmp doFree

vmmwrite_fail:
    lda #DOS_PRINT_STR
    ldx #<msgErrVmmWrite
    ldy #>msgErrVmmWrite
    jsr OS_API
    jmp doFree

vmmread_fail:
    lda #DOS_PRINT_STR
    ldx #<msgErrVmmRead
    ldy #>msgErrVmmRead
    jsr OS_API
    ; fall through to doFree

doFree:
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
; "BLOCK READ/WRITE ROUNDTRIP OK!"
msgRwOk:
    .byte $42, $4C, $4F, $43, $4B, $20, $52, $45, $41, $44, $2F, $57, $52
    .byte $49, $54, $45, $20, $52, $4F, $55, $4E, $44, $54, $52, $49, $50
    .byte $20, $4F, $4B, $21, $0D, $00
; "ERROR: BLOCK READ/WRITE MISMATCH."
msgRwMismatch:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $42, $4C, $4F, $43, $4B, $20
    .byte $52, $45, $41, $44, $2F, $57, $52, $49, $54, $45, $20, $4D, $49
    .byte $53, $4D, $41, $54, $43, $48, $2E, $0D, $00
; "ERROR: DOS_VMM_WRITE FAILED."
msgErrVmmWrite:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $44, $4F, $53, $5F, $56, $4D
    .byte $4D, $5F, $57, $52, $49, $54, $45, $20, $46, $41, $49, $4C, $45
    .byte $44, $2E, $0D, $00
; "ERROR: DOS_VMM_READ FAILED."
msgErrVmmRead:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $44, $4F, $53, $5F, $56, $4D
    .byte $4D, $5F, $52, $45, $41, $44, $20, $46, $41, $49, $4C, $45, $44
    .byte $2E, $0D, $00

.segment "DATA"
; Known 16-byte pattern written to the REU and read back for comparison.
testPattern:
    .byte $01, $02, $03, $04, $05, $06, $07, $08
    .byte $09, $0A, $0B, $0C, $0D, $0E, $0F, $10

.segment "BSS"
readBack: .res 16
