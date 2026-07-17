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
.define VERSION_STAGE "13"
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
.import sourceClose
.import diagPrintString
.import exitSuccess
.import exitFatal

.import lexerInit
.import parserParseStatement
.import CasmParserStmt
.import diagPrintPhase2Ready

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

    jsr lexerInit
    bcs startFatal

    ; WP11 temporary verification driver: parse each statement so any syntax
    ; diagnostic surfaces through the central fatal path, and print the
    ; validated banner once the stream parses to EOF. WP14 replaces this with
    ; the parser/emitter loop.
startParseLoop:
    jsr parserParseStatement
    bcs startFatal
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    cmp #CASM_TOKEN_EOF
    bne startParseLoop

    jsr diagPrintPhase2Ready
    jsr sourceClose
    bcs startFatal
    jmp exitSuccess

startFatal:
    jmp exitFatal

.segment "RODATA"

versionBanner:
    .byte "CASM V", VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE, "."
    .byte BUILD_NUMBER
    .byte PetCr, 0
