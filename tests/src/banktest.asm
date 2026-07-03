// tests/src/banktest.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// Tests the memory banking: verifies RAM under BASIC ROM ($A000-$BFFF) is writable/readable.

.encoding "petscii_mixed"

.const DOS_PRINT_STR  = $09
.const DOS_EXIT       = $4C
.const API            = $1000

.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "0"
#import "build_test_banktest.inc"

* = $2000 "BankTest"
    cld                     // Binary mode
    lda #$0e                // Lowercase mode
    jsr $ffd2               // CHROUT
    
    // Print start message
    lda #DOS_PRINT_STR
    ldx #<msgStart
    ldy #>msgStart
    jsr API

    // Write pattern to $A000-$A0FF
    ldx #0
write_loop_a:
    txa
    sta $a000, x
    inx
    bne write_loop_a

    // Verify pattern at $A000-$A0FF
    ldx #0
verify_loop_a:
    txa
    cmp $a000, x
    bne test_fail
    inx
    bne verify_loop_a

    // Write pattern to $B000-$B0FF
    ldx #0
write_loop_b:
    txa
    eor #$ff                // Alternating pattern
    sta $b000, x
    inx
    bne write_loop_b

    // Verify pattern at $B000-$B0FF
    ldx #0
verify_loop_b:
    txa
    eor #$ff
    cmp $b000, x
    bne test_fail
    inx
    bne verify_loop_b

    // All matches! Test passed.
    lda #DOS_PRINT_STR
    ldx #<msgPass
    ldy #>msgPass
    jsr API
    jmp exit

test_fail:
    lda #DOS_PRINT_STR
    ldx #<msgFail
    ldy #>msgFail
    jsr API

exit:
    lda #DOS_EXIT
    jsr API

msgStart: .text "BANKTEST v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE + "." + BUILD_NUMBER
          .text " - Testing BASIC ROM Banking RAM access..."
          .byte $0d, 0
msgPass:  .text "RAM under BASIC ROM fully writable: PASS"
          .byte $0d, 0
msgFail:  .text "Error: RAM under BASIC ROM not writable: FAIL"
          .byte $0d, 0
