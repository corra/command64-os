; src/external/edlin/edlin.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; EDLIN line-oriented text editor, ported from MS-DOS 4.00's EDLIN
; (ms-dos/v4.0/src/CMD/EDLIN/). Design/scope:
; brain/plans/2026-07-09-edlin-port-feasibility.md; phased build-out:
; brain/plans/2026-07-09-edlin-implementation-phases.md. Calls into
; Command64's own jump table (OS_API = $1000, function-selector-in-A
; convention, include/ca65/command64.inc).
;
; Phase 0 (scaffold): prints a version banner and exits. No editing logic
; yet -- that begins in Phase 1 (VMM-backed buffer).
;
; PETSCII note: mirrors src/external/label/label.s -- ca65 has no
; equivalent to Kick's ".encoding petscii_mixed" auto-translation, so
; message strings are precomputed uppercase-ASCII/PETSCII hex bytes
; rather than quoted string literals.

.include "command64.inc"
.include "common.inc"

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '0'
.include "build_edlin.inc"

.import __MAIN_START__

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------
start:
    ldx #<verMsg
    ldy #>verMsg
    lda #DOS_PRINT_STR
    jsr OS_API

    lda #DOS_EXIT
    jsr OS_API

.segment "RODATA"

; "EDLIN V" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
; + "." + BUILD_NUMBER, same banner format as label.s/format.s.
verMsg:
    .byte $45, $44, $4C, $49, $4E, $20, $56
    .byte VERSION_MAJOR, $2E, VERSION_MINOR, $2E, VERSION_STAGE, $2E
    .byte BUILD_NUMBER
    .byte $0D, $00
