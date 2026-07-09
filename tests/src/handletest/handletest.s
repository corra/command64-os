; tests/src/handletest/handletest.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 port of tests/src/handletest/handletest.asm.

.include "command64.inc"

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '0'
.include "build_test_ca65_handletest.inc"

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

    ; 1. Initial cleanup: delete t0-t7 if they exist
    jsr cleanup_files

    ; 2. Open 8 files (T0.PRG-T7.PRG) for Write
    lda #0
    sta tempIndex
open_loop:
    jsr get_filename_ptr
    lda #1
    sta HexValLo
    lda #DOS_OPEN_FILE
    jsr OS_API
    bcs open_err

    ldy tempIndex
    sta handles, y

    inc tempIndex
    lda tempIndex
    cmp #8
    bne open_loop

    ; 3. Attempt to open a 9th file (T8.PRG)
    ldx #<fname8
    ldy #>fname8
    lda #1
    sta HexValLo
    lda #DOS_OPEN_FILE
    jsr OS_API
    bcc limit_failed

    ; 4. Close all 8 files
    lda #0
    sta tempIndex
close_loop:
    ldy tempIndex
    lda handles, y
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr OS_API
    bcs close_err

    inc tempIndex
    lda tempIndex
    cmp #8
    bne close_loop

    ; 5. Final cleanup: delete files
    jsr cleanup_files

    ; 6. Test passes!
    lda #DOS_PRINT_STR
    ldx #<msgPass
    ldy #>msgPass
    jsr OS_API
    jmp exit

open_err:
    lda #DOS_PRINT_STR
    ldx #<msgErrOpen
    ldy #>msgErrOpen
    jsr OS_API
    jmp exit

limit_failed:
    lda #DOS_PRINT_STR
    ldx #<msgErrLimit
    ldy #>msgErrLimit
    jsr OS_API
    jmp exit

close_err:
    lda #DOS_PRINT_STR
    ldx #<msgErrClose
    ldy #>msgErrClose
    jsr OS_API

exit:
    lda #DOS_EXIT
    jsr OS_API

; --- HELPER SUBROUTINES ---

cleanup_files:
    lda #0
    sta tempIndex
cleanup_loop:
    jsr get_filename_ptr
    lda #DOS_DELETE_FILE
    jsr OS_API
    inc tempIndex
    lda tempIndex
    cmp #8
    bne cleanup_loop
    rts

get_filename_ptr:
    lda tempIndex
    clc
    adc #$30            ; '0'
    sta fname_digit
    ldx #<fname_template
    ldy #>fname_template
    rts

; --- DATA ---

tempIndex: .byte 0
handles:   .res 8, 0

; "T" + "0.PRG"
fname_template:
    .byte $54
fname_digit:
    .byte $30, $2E, $50, $52, $47, $00

; "T8.PRG"
fname8:
    .byte $54, $38, $2E, $50, $52, $47, $00

; "HANDLETEST V" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
; + "." + BUILD_NUMBER + " - Testing file handle stress and limits..."
msgStart:
    .byte $48, $41, $4E, $44, $4C, $45, $54, $45, $53, $54, $20, $56
    .byte VERSION_MAJOR, $2E, VERSION_MINOR, $2E, VERSION_STAGE, $2E
    .byte BUILD_NUMBER
    .byte $20, $2D, $20, $54, $45, $53, $54, $49, $4E
    .byte $47, $20, $46, $49, $4C, $45, $20, $48, $41, $4E, $44, $4C, $45
    .byte $20, $53, $54, $52, $45, $53, $53, $20, $41, $4E, $44, $20, $4C
    .byte $49, $4D, $49, $54, $53, $2E, $2E, $2E, $0D, $00
; "FILE HANDLE STRESS & API: PASS"
msgPass:
    .byte $46, $49, $4C, $45, $20, $48, $41, $4E, $44, $4C, $45, $20, $53
    .byte $54, $52, $45, $53, $53, $20, $26, $20, $41, $50, $49, $3A, $20
    .byte $50, $41, $53, $53, $0D, $00
; "ERROR: FAILED TO OPEN 8 FILES: FAIL"
msgErrOpen:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $46, $41, $49, $4C, $45, $44
    .byte $20, $54, $4F, $20, $4F, $50, $45, $4E, $20, $38, $20, $46, $49
    .byte $4C, $45, $53, $3A, $20, $46, $41, $49, $4C, $0D, $00
; "ERROR: ENFORCED 8-HANDLE LIMIT FAILED: FAIL"
msgErrLimit:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $45, $4E, $46, $4F, $52, $43
    .byte $45, $44, $20, $38, $2D, $48, $41, $4E, $44, $4C, $45, $20, $4C
    .byte $49, $4D, $49, $54, $20, $46, $41, $49, $4C, $45, $44, $3A, $20
    .byte $46, $41, $49, $4C, $0D, $00
; "ERROR: FAILED TO CLOSE HANDLES: FAIL"
msgErrClose:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $46, $41, $49, $4C, $45, $44
    .byte $20, $54, $4F, $20, $43, $4C, $4F, $53, $45, $20, $48, $41, $4E
    .byte $44, $4C, $45, $53, $3A, $20, $46, $41, $49, $4C, $0D, $00
