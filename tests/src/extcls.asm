// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors

.encoding "petscii_mixed"

.const DOS_PRINT_STR = $09
.const API = $1000

.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "0"
#import "build_test_extcls.inc"

* = $2200 "Cls"
    cld
    lda #$0e
    jsr $ffd2
    
    lda #DOS_PRINT_STR
    ldx #<msgStart
    ldy #>msgStart
    jsr API
    
    lda #$93 // Clear screen
    jsr $ffd2
    rts

msgStart: .text "EXTCLS v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE + "." + BUILD_NUMBER
          .text " - Clearing screen"
          .byte $0d, 0
