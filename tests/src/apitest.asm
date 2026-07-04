// tests/src/apitest.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// Tests the INT 21h Service Bus: DOS_PRINT_STR and DOS_EXIT

.encoding "petscii_mixed"

.const DOS_PRINT_STR  = $09
.const DOS_EXIT       = $4C
.const API            = $1000

.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "0"
#import "build_test_apitest.inc"

* = $2200 "ApiTest"
    cld                     // Ensure binary mode
    lda #$0E                // Switch to lowercase mode
    jsr $FFD2               // CHROUT
    
    // Print the welcome message using the API
    lda #DOS_PRINT_STR
    ldx #<msg
    ldy #>msg
    jsr API

    // Terminate via API
    lda #DOS_EXIT
    jsr API

msg: .text "APITEST v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE + "." + BUILD_NUMBER
     .text " - String output works!"
     .byte $0d, 0
