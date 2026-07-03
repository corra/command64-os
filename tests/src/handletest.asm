// tests/src/handletest.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// Tests file handle limits (max 8) and API open/close/delete services.

.encoding "petscii_mixed"

.const DOS_PRINT_STR  = $09
.const DOS_OPEN_FILE  = $3D
.const DOS_CLOSE_FILE = $3E
.const DOS_DELETE_FILE = $41
.const DOS_EXIT       = $4C
.const API            = $1000

.label HexValLo = $66
.label HexValHi = $67
.label FileHandle = $6D

.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "0"
#import "build_test_handletest.inc"

* = $2000 "HandleTest"
    cld                     // Binary mode
    lda #$0e                // Lowercase mode
    jsr $ffd2               // CHROUT
    
    // Print start message
    lda #DOS_PRINT_STR
    ldx #<msgStart
    ldy #>msgStart
    jsr API

    // 1. Initial cleanup: delete t0-t7 if they exist
    jsr cleanup_files

    // 2. Open 8 files (t0-t7) for Write
    lda #0                  // Loop index
    sta tempIndex
open_loop:
    jsr get_filename_ptr    // Returns X/Y pointing to current filename "tX.prg"
    lda #1
    sta HexValLo            // Mode = 1 (Write)
    lda #DOS_OPEN_FILE
    jsr API
    bcs open_err            // If open fails, jump to error
    
    // Save handle in handles table
    ldy tempIndex
    sta handles, y
    
    inc tempIndex
    lda tempIndex
    cmp #8
    bne open_loop

    // 3. Attempt to open a 9th file (t8.prg)
    ldx #<fname8
    ldy #>fname8
    lda #1
    sta HexValLo            // Mode = 1
    lda #DOS_OPEN_FILE
    jsr API
    bcc limit_failed        // If it succeeds, the 8-handle limit failed!

    // 4. Close all 8 files
    lda #0
    sta tempIndex
close_loop:
    ldy tempIndex
    lda handles, y
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr API
    bcs close_err
    
    inc tempIndex
    lda tempIndex
    cmp #8
    bne close_loop

    // 5. Final cleanup: delete files
    jsr cleanup_files

    // 6. Test passes!
    lda #DOS_PRINT_STR
    ldx #<msgPass
    ldy #>msgPass
    jsr API
    jmp exit

open_err:
    lda #DOS_PRINT_STR
    ldx #<msgErrOpen
    ldy #>msgErrOpen
    jsr API
    jmp exit

limit_failed:
    lda #DOS_PRINT_STR
    ldx #<msgErrLimit
    ldy #>msgErrLimit
    jsr API
    // Close successfully opened handles before exiting
    jmp exit

close_err:
    lda #DOS_PRINT_STR
    ldx #<msgErrClose
    ldy #>msgErrClose
    jsr API

exit:
    lda #DOS_EXIT
    jsr API

// --- HELPER SUBROUTINES ---

cleanup_files:
    lda #0
    sta tempIndex
cleanup_loop:
    jsr get_filename_ptr    // X/Y = filename
    lda #DOS_DELETE_FILE
    jsr API                 // Delete (ignore carry flag error if file doesn't exist)
    inc tempIndex
    lda tempIndex
    cmp #8
    bne cleanup_loop
    rts

get_filename_ptr:
    // Update filename string character with current index
    lda tempIndex
    clc
    adc #'0'
    sta fname_digit
    ldx #<fname_template
    ldy #>fname_template
    rts

// --- DATA ---

tempIndex: .byte 0
handles:   .fill 8, 0

fname_template: .text "t"
fname_digit:    .text "0.prg"
                .byte 0

fname8:         .text "t8.prg"
                .byte 0

msgStart:    .text "HANDLETEST v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE + "." + BUILD_NUMBER
             .text " - Testing file handle stress and limits..."
             .byte $0d, 0
msgPass:     .text "FILE HANDLE STRESS & API: PASS"
             .byte $0d, 0
msgErrOpen:  .text "Error: Failed to open 8 files: FAIL"
             .byte $0d, 0
msgErrLimit: .text "Error: Enforced 8-handle limit failed: FAIL"
             .byte $0d, 0
msgErrClose: .text "Error: Failed to close handles: FAIL"
             .byte $0d, 0
