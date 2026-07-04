// tests/src/vmmtest.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// Tests the INT 21h Service Bus: DOS_ALLOC_MEM, DOS_FREE_MEM, DOS_PRINT_STR

.encoding "petscii_mixed"

.const DOS_PRINT_STR  = $09
.const DOS_ALLOC_MEM  = $48
.const DOS_FREE_MEM   = $49
.const DOS_EXIT       = $4C
.const API            = $1000

.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "0"
#import "build_test_vmmtest.inc"

* = $2200 "VmmTest"
    cld                     // Ensure binary mode
    lda #$0E                // Switch to lowercase mode
    jsr $FFD2               // CHROUT
    
    // 1. Print start message
    lda #DOS_PRINT_STR
    ldx #<msgStart
    ldy #>msgStart
    jsr API

    // 2. Request 1 page (256 paragraphs = $0100)
    lda #DOS_ALLOC_MEM
    ldx #$00
    ldy #$01
    jsr API
    // Returns Status in A, Page Index (SegHi) in X, Bank in Y
    bcs alloc_fail

    // Save alloc result before print call clobbers X/Y
    // $64 = TempLo (Page Index), $65 = TempHi (Bank)
    stx $64
    sty $65

    // 3. Print success message
    lda #DOS_PRINT_STR
    ldx #<msgOk
    ldy #>msgOk
    jsr API

    // 4. Free the memory — restore page/bank saved before the print
    ldx $64
    ldy $65
    lda #DOS_FREE_MEM
    jsr API
    bcs free_fail

    // 5. Done
    lda #DOS_PRINT_STR
    ldx #<msgDone
    ldy #>msgDone
    jsr API
    jmp exit

alloc_fail:
    lda #DOS_PRINT_STR
    ldx #<msgErrAlloc
    ldy #>msgErrAlloc
    jsr API
    jmp exit

free_fail:
    lda #DOS_PRINT_STR
    ldx #<msgErrFree
    ldy #>msgErrFree
    jsr API

exit:
    lda #DOS_EXIT
    jsr API

msgStart:    .text "VMMTEST v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE + "." + BUILD_NUMBER
             .text " - Testing VMM Allocation via API..."
             .byte $0d, 0
msgOk:       .text "Allocation successful!"
             .byte $0d, 0
msgDone:     .text "Deallocation successful. Test complete."
             .byte $0d, 0
msgErrAlloc: .text "Error: Memory allocation failed."
             .byte $0d, 0
msgErrFree:  .text "Error: Memory deallocation failed."
             .byte $0d, 0
