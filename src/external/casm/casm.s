; src/external/casm/casm.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM native 6502/6510 assembler entry point. Owns the production assembly
; orchestration: initialize resources/CLI/file-IO/source/lexer/symbol table,
; run a real two-pass assembly (Phase 6B WP29) -- Pass 1 measures addresses and
; defines labels with no output file; Pass 2 rewinds the source, creates the
; output PRG, and emits for real, now that every label resolves through the
; WP27 symbol table -- finalize the output, and route every success and
; failure through central cleanup. Handle ownership, partial-output abort, and
; single-close semantics are documented at start and casmRunPass below.

.include "command64.inc"
.include "common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "33"
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
.import CasmLabelName
.import CasmLabelNameLen
.import opcodesFindOpcode
.import diagPrintPhase2Ready

.import sourceRewind
.import symbolsInit
.import symbolsInsert

.import CasmOutputName
.import fileCreateOutput
.import outputAbort
.import emitInit
.import emitInstruction
.import emitDirective
.import emitFinalize
.import emitCheckPassAgreement
.import CasmPc
.import CasmPassMode
.import CasmPass1FinalPc

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

    jsr symbolsInit
    bcs startInitFatal
    jsr sourceOpen
    bcs startInitFatal
    jsr lexerInit
    bcs startInitFatal
    jmp startPass1

startInitFatal:
    ; Trampoline: initialization branches are out of direct range of the
    ; fatal tail below. Kept immediately after the init-only checks that use
    ; it (everything through the initial lexerInit) -- Pass 1/Pass 2 failures
    ; below use their own nearby startFatalNear trampoline instead, since this
    ; one is now too far from them to reach in a single branch.
    jmp startFatal

startPass1:
    ; Pass 1 (WP29): measure addresses and define labels. No output file
    ; exists yet -- emitOrg's header write and every emitRawByte call
    ; automatically no-op under CASM_PASS_MODE_MEASURE (emit.s), so it is
    ; safe to drive the full dispatch here before fileCreateOutput ever runs.
    jsr emitInit
    bcs startFatalNear
    lda #CASM_PASS_MODE_MEASURE
    sta CasmPassMode
    jsr casmRunPass
    bcs startFatalNear          ; outputAbort is a safe no-op: no output
                                 ; file was ever created this pass

    ; WP30: snapshot Pass 1's final program counter for the end-of-Pass-2
    ; agreement check below.
    lda CasmPc
    sta CasmPass1FinalPc
    lda CasmPc + 1
    sta CasmPass1FinalPc + 1

    ; Pass 2 (WP29): rewind the identical source, recreate the output PRG,
    ; and re-drive the same dispatch for real now that every label the
    ; source defines is in the symbol table.
    jsr sourceRewind
    bcs startFatalNear
    jsr lexerInit
    bcs startFatalNear
    ldx #<CasmOutputName
    ldy #>CasmOutputName
    jsr fileCreateOutput
    bcs startFatalNear
    jsr emitInit
    bcs startFatalNear
    lda #CASM_PASS_MODE_EMIT
    sta CasmPassMode
    jsr casmRunPass
    bcs startFatalNear

    ; WP30: a genuine disagreement is not believed reachable through any
    ; legitimate source under the current grammar (see emitCheckPassAgreement's
    ; own header comment) -- this is a defensive internal-consistency check,
    ; not a demonstrated user-reachable path.
    jsr emitCheckPassAgreement
    bcs startFatalNear

    jsr emitFinalize
    bcs startFatalNear
    jsr diagPrintPhase2Ready
    jsr sourceClose
    bcs startFatalNear
    jmp exitSuccess

startFatalNear:
    ; Trampoline: Pass 1/Pass 2 failure branches are out of direct range of
    ; the fatal tail below (past the full casmRunPass routine).
    jmp startFatal

; ---------------------------------------------------------------------------
; casmRunPass (private)
; The single per-statement dispatch shared by both passes (WP29, per the
; Phase 0C.5 freeze): parse one statement, then dispatch by type -- a label
; (IDENTIFIER) inserts into the symbol table only under CASM_PASS_MODE_MEASURE
; (Pass 2 has nothing to do for a label: it was already defined in Pass 1), a
; MNEMONIC is matched by the opcode table and emitted, a DIRECTIVE is handled
; by the emission engine, a NEWLINE emits nothing, and EOF ends the pass
; cleanly. Every routine this calls is already pass-mode-correct on its own
; (emitRawByte's single CasmPassMode gate, parserParseExpressionValue's
; pass-mode-aware resolver handling) -- this loop itself branches on
; CasmPassMode only for the label case. On success the output is left
; registry-owned for a checked close during cleanup; INPUT VALIDATED prints
; only after the final buffered write (emitFinalize) succeeds.
;
; Inputs:    CasmPassMode set by the caller for this pass; lexer/source READY
; Outputs:   C clear at CASM_TOKEN_EOF; C set with A = CASM_DIAG_* on any
;            parse, symbol-table, addressing-mode, or emission failure
; Clobbers:  A, X, Y, CasmParser*/CasmLabelName* scratch, lexer/source/emit/
;            symbol volatile state
; ---------------------------------------------------------------------------
casmRunPass:
    jsr parserParseStatement
    bcs crpFail
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    cmp #CASM_TOKEN_IDENTIFIER
    beq crpLabel
    cmp #CASM_TOKEN_MNEMONIC
    beq crpInsn
    cmp #CASM_TOKEN_DIRECTIVE
    beq crpDir
    cmp #CASM_TOKEN_EOF
    beq crpDone
    jmp casmRunPass              ; NEWLINE: nothing to do

crpLabel:
    lda CasmPassMode
    cmp #CASM_PASS_MODE_MEASURE
    bne casmRunPass              ; EMIT: nothing to do for a label statement
    lda CasmLabelNameLen
    ldx #<CasmLabelName
    ldy #>CasmLabelName
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldx CasmPc
    ldy CasmPc + 1
    jsr symbolsInsert
    bcs crpFail
    jmp casmRunPass

crpInsn:
    jsr opcodesFindOpcode
    bcs crpFail
    jsr emitInstruction
    bcs crpFail
    jmp casmRunPass

crpDir:
    jsr emitDirective
    bcs crpFail
    jmp casmRunPass

crpDone:
    clc
    rts
crpFail:
    rts                          ; C already set, A = CASM_DIAG_*

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
