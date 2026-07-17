; src/external/casm/casm.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM native 6502/6510 assembler entry point. Phase 2 parses one bounded
; source filename, consumes it through managed native file services, and
; returns through central cleanup. Tokenization and assembly begin later.

.include "command64.inc"
.include "common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "10"
.include "build_casm.inc"

.import __MAIN_START__
.import resourcesInit
.import CasmPhase
.import cliInit
.import cliParse
.import cliDeriveOutputName
.import CasmCliOptions
.import fileIoInit
.import sourceInit
.import sourceOpen
.import sourceNextByte
.import sourceClose
.import diagPrintString
.import diagPrintPhase2Ready
.import exitSuccess
.import exitFatal

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

; ---------------------------------------------------------------------------
; start
; Initialize CASM, parse the Phase 2 command line, consume the bounded input
; stream, and return to Command 64 through central cleanup.
;
; Inputs:  Command 64 external-application launch state
; Outputs: does not return directly; exitSuccess invokes DOS_EXIT
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
start:
    jsr resourcesInit
    bcs startFatal
    jsr cliInit
    bcs startFatal
    jsr fileIoInit
    bcs startFatal
    jsr sourceInit
    bcs startFatal
    lda #CASM_PHASE_CLI_FILE
    sta CasmPhase

    ldx #<versionBanner
    ldy #>versionBanner
    jsr diagPrintString

    jsr cliParse
    bcs startFatal

    ; Phase 2 accepts these option spellings so their grammar is stable, but
    ; their features do not become operational until later phases.
    lda CasmCliOptions
    and #(CASM_OPT_STATIC | CASM_OPT_MAP | CASM_OPT_LIST)
    beq startOptionsReady
    lda #CASM_DIAG_NOT_IMPLEMENTED
    jmp exitFatal

startOptionsReady:
    jsr cliDeriveOutputName
    bcs startFatal
    jsr sourceOpen
    bcs startFatal

    ; Route the consume-only Phase 2 behavior through the WP4 source API. The
    ; loop traverses every raw byte and block boundary but does not inspect or
    ; print bytes, preserving the existing INPUT VALIDATED success output.
startReadLoop:
    jsr sourceNextByte
    bcs startFatal
    cmp #CASM_SOURCE_EOF
    beq startInputDone
    jmp startReadLoop

startInputDone:
    jsr sourceClose
    bcs startFatal
    jsr diagPrintPhase2Ready
    jmp exitSuccess

startFatal:
    jmp exitFatal

.segment "RODATA"

versionBanner:
    .byte "CASM V", VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE, "."
    .byte BUILD_NUMBER
    .byte PetCr, 0
