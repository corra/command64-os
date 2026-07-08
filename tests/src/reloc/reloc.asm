// tests/src/reloc.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// Phase 6B integration test: this binary is built relocatable (dual $2600/
// $2700 compile + tools/reloc.py) like any other external app, then the
// test framework loads it at a non-standard page (e.g. $4000) to verify
// aptRelocate correctly patches its internal absolute references.

.encoding "petscii_mixed"

.const DOS_PRINT_STR  = $09
.const DOS_EXIT       = $4C
.const API            = $1000

.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "0"
#import "build_test_reloc.inc"

#import "build_config.inc"
* = UserProgStart "RelocTest"
    cld                     // Ensure binary mode

    // JSR to a subroutine elsewhere in this binary -- its absolute target
    // address is exactly the kind of high-byte reference aptRelocate must
    // patch when this program is loaded away from its compiled address.
    jsr printMsg

    // Terminate via API
    lda #DOS_EXIT
    jsr API

printMsg:
    // Absolute references to msg (both the immediate #>msg high byte and
    // the pointer table entry below) exercise the same relocation path.
    lda #DOS_PRINT_STR
    ldx #<msg
    ldy #>msg
    jsr API
    rts

msg: .text "RELOCTEST v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE + "." + BUILD_NUMBER
     .text " - Relocated correctly!"
     .byte $0d, 0
