; src/external/casm/casm.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM native 6502/6510 assembler entry point. Phase 1 initializes bounded
; ownership state, prints the build-version banner, and returns through the
; central cleanup path. Parsing and assembly begin in later phases.

.include "command64.inc"
.include "common.inc"

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '0'
.include "build_casm.inc"

.import __MAIN_START__
.import resourcesInit
.import diagPrintString
.import exitSuccess
.import exitFatal

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

; ---------------------------------------------------------------------------
; start
; Initialize CASM, print its complete version, and return to Command 64.
;
; Inputs:  Command 64 external-application launch state
; Outputs: does not return directly; exitSuccess invokes DOS_EXIT
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
start:
    jsr resourcesInit
    bcc startReady
    jmp exitFatal

startReady:
    ldx #<versionBanner
    ldy #>versionBanner
    jsr diagPrintString
    jmp exitSuccess

.segment "RODATA"

versionBanner:
    .byte $43, $41, $53, $4D, $20, $56 ; "CASM V"
    .byte VERSION_MAJOR, $2E, VERSION_MINOR, $2E, VERSION_STAGE, $2E
    .byte BUILD_NUMBER
    .byte PetCr, 0
