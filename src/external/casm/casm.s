; src/external/casm/casm.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM native 6502/6510 assembler entry point. Owns the production assembly
; orchestration (Phase 4 WP14): initialize resources/CLI/file-IO/source/lexer,
; derive and create the output PRG, run the single-pass compiler loop
; (parse -> match -> emit) to EOF, finalize the output, and route every success
; and failure through central cleanup. Handle ownership, partial-output abort,
; and single-close semantics are documented at start and startParseLoop below.

.include "command64.inc"
.include "common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "27"
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
.import diagClearLoc
.import exitSuccess
.import exitFatal

.import lexerInit
.import parserParseStatement
.import CasmParserStmt
.import opcodesFindOpcode
.import diagPrintPhase2Ready

.import CasmOutputName
.import fileCreateOutput
.import outputAbort
.import emitInit
.import emitInstruction
.import emitDirective
.import emitFinalize

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

; ---------------------------------------------------------------------------
; start
; Initialize CASM, parse the command line, assemble the source to an output PRG,
; and return to Command 64 through central cleanup.
;
; Inputs:  Command 64 external-application launch state
; Outputs: does not return directly; exitSuccess invokes DOS_EXIT
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
start:
    ; Invalidate the diagnostic location before anything can raise: CasmDiagLoc*
    ; lives in uninitialized BSS, so a locationless diagnostic (I/O or stream
    ; failure, NOT IMPLEMENTED, ...) would otherwise print a stale, garbage
    ; "AT LINE .../COL ..." trailer left over from whatever the RAM held.
    jsr diagClearLoc
    jsr resourcesInit
    bcs startInitFatal
    jsr cliInit
    bcs startInitFatal
    jsr fileIoInit
    bcs startInitFatal
    jsr sourceInit
    bcs startInitFatal
    lda #CASM_PHASE_CLI_FILE
    sta CasmPhase

    ldx #<versionBanner
    ldy #>versionBanner
    jsr diagPrintString

    jsr cliParse
    bcs startInitFatal

    ; WP13 makes output operational: a successful assembly writes a PRG by
    ; default, and /S (static) selects that now-default output mode. The map
    ; and listing options remain unimplemented.
    lda CasmCliOptions
    and #(CASM_OPT_MAP | CASM_OPT_LIST)
    beq startOptionsReady
    lda #CASM_DIAG_NOT_IMPLEMENTED
    jmp exitFatal

startOptionsReady:
    jsr cliDeriveOutputName
    bcs startInitFatal
    jsr sourceOpen
    bcs startInitFatal

    jsr lexerInit
    bcs startInitFatal

    ; Create the output PRG and initialize the emission engine.
    ldx #<CasmOutputName
    ldy #>CasmOutputName
    jsr fileCreateOutput
    bcs startInitFatal
    jsr emitInit
    bcs startInitFatal
    jmp startParseLoop

startInitFatal:
    ; Trampoline: initialization branches are out of direct range of the
    ; fatal tail below.
    jmp startFatal

    ; Production compiler loop (Phase 4 WP14). Single pass: parse one statement,
    ; then dispatch by type -- a MNEMONIC is matched by the opcode table and
    ; emitted, a DIRECTIVE is handled by the emission engine, a NEWLINE emits
    ; nothing, and EOF finalizes. Every syntax, addressing-mode, operand-range,
    ; and emission diagnostic returns C set with A = CASM_DIAG_* and funnels
    ; through startFatal. On success the output is left registry-owned for a
    ; checked close during cleanup; INPUT VALIDATED prints only after the final
    ; buffered write (emitFinalize) succeeds.
    ;
    ; The WP14 audit kept this loop in casm.s rather than extracting a
    ; compiler.s module: it is bounded dispatch glue over the already-modular
    ; parser/opcode/emit ABIs, tightly coupled to the entry init sequence and
    ; the startInitFatal/startFatal trampolines, so a separate module would add
    ; an export boundary without clarifying one. It also must not anticipate the
    ; later Pass 1/Pass 2 architecture.
startParseLoop:
    jsr parserParseStatement
    bcs startFatal
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    cmp #CASM_TOKEN_MNEMONIC
    beq startEmitInsn
    cmp #CASM_TOKEN_DIRECTIVE
    beq startEmitDir
    cmp #CASM_TOKEN_EOF
    beq startAssembled
    jmp startParseLoop          ; NEWLINE: nothing to emit
startEmitInsn:
    jsr opcodesFindOpcode
    bcs startFatal
    jsr emitInstruction
    bcs startFatal
    jmp startParseLoop
startEmitDir:
    jsr emitDirective
    bcs startFatal
    jmp startParseLoop

startAssembled:
    jsr emitFinalize
    bcs startFatal
    jsr diagPrintPhase2Ready
    jsr sourceClose
    bcs startFatal
    jmp exitSuccess

startFatal:
    ; Best-effort delete of any partial output while preserving the primary
    ; diagnostic in A, then route through central cleanup.
    jsr outputAbort
    jmp exitFatal

.segment "RODATA"

versionBanner:
    .byte "CASM V", VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE, "."
    .byte BUILD_NUMBER
    .byte PetCr, 0
