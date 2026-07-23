; tests/src/casm_passcheck/casm_passcheck.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 6B WP30 fixture harness for emit.s's
; emitCheckPassAgreement. No real two-pass assembly runs here: the harness
; pokes CasmPc and CasmPass1FinalPc directly to deliberately matched and
; mismatched values, calls emitCheckPassAgreement, and checks its C/A result
; -- the only positive proof the CASM_DIAG_PASS_MISMATCH fatal path itself
; is wired correctly, since no legitimate CASM source is believed able to
; reach it (see emitCheckPassAgreement's own header comment in emit.s).
;
; Like casm_pass1.s (not casm_symbols.s/casm_vmm.s, which stub diagPrintFatal
; to avoid dragging in lexer.s/source.s), this harness links almost the
; entire CASM module set: emit.s imports parserParseExpressionValue
; (parser.s), which imports exprEvaluate (expr.s) and symbolsLookup
; (symbols.s, which imports vmm_store.s/resources.s), and emit.s also
; imports fileWrite (fileio.s), lexerNext (lexer.s), and CasmTokenRecord
; (state.s) directly -- none of which this harness's own test logic ever
; exercises at runtime (it never calls sourceOpen/lexerInit/
; parserParseStatement), but ld65 links whole object files, so every symbol
; emit.s references must still resolve. The stubbing trick does not apply
; here for the same reason casm_pass1.s's header explains it doesn't apply
; there: parser.s/lexer.s/source.s already depend on the REAL diagnostics.s
; directly.
;
; No resourcesInit/fileIoInit/sourceInit call is needed: this harness opens
; no file and allocates no VMM (emitCheckPassAgreement's only dependency,
; diagClearLoc, is a plain BSS write with no initialization requirement), so
; -- matching casm_vmm.s/casm_symbols.s's own precedent for a harness with
; nothing to clean up -- it exits via DOS_EXIT directly with no registration
; or cleanup path.
;
; Declares its own CasmSourceName/CasmOutputName buffers (normally provided
; by cli.s, which this harness does not link) for the same reason
; casm_pass1.s does: fileio.s's outputAbort references both names directly,
; and ld65 links whole object files, so they must resolve even though
; outputAbort is never called from here.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_passcheck.inc"

.import __MAIN_START__
.import CasmPc
.import CasmPass1FinalPc
.import emitCheckPassAgreement

.export CasmSourceName   ; fileio.s's outputAbort references this by name
.export CasmOutputName   ; fileio.s's outputAbort references this by name

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda #0
    sta FailCount

    jsr pcmatch1
    jsr reportCase
    jsr pcmismatch1
    jsr reportCase

    lda #$0D
    jsr KernalChROUT
    lda FailCount
    beq allPass
    lda #<failMsg
    ldy #>failMsg
    jmp printResult
allPass:
    lda #<passMsg
    ldy #>passMsg
printResult:
    tax
    lda #DOS_PRINT_STR
    jsr OS_API
    lda #DOS_EXIT
    jsr OS_API

; ---------------------------------------------------------------------------
; reportCase
; Print '.' for a pass (carry clear) or 'F' for a fail (carry set), tallying
; FailCount. Called immediately after each fixture below.
; ---------------------------------------------------------------------------
reportCase:
    bcs rcFail
    lda #$2E
    jsr KernalChROUT
    rts
rcFail:
    inc FailCount
    lda #$46
    jsr KernalChROUT
    rts

; ---------------------------------------------------------------------------
; pcmatch1
; CasmPc == CasmPass1FinalPc ($1234) -> emitCheckPassAgreement must return
; C clear. That result IS this fixture's pass/fail signal, unmodified.
; ---------------------------------------------------------------------------
pcmatch1:
    lda #$34
    sta CasmPc
    sta CasmPass1FinalPc
    lda #$12
    sta CasmPc + 1
    sta CasmPass1FinalPc + 1
    jsr emitCheckPassAgreement
    rts

; ---------------------------------------------------------------------------
; pcmismatch1
; CasmPc ($1235) != CasmPass1FinalPc ($1234) -> emitCheckPassAgreement must
; return C set with A = CASM_DIAG_PASS_MISMATCH. That is this fixture's
; SUCCESS condition -- an unexpected C-clear match, or a C-set result with
; any other diagnostic, is the fixture failure.
; ---------------------------------------------------------------------------
pcmismatch1:
    lda #$35
    sta CasmPc
    lda #$34
    sta CasmPass1FinalPc
    lda #$12
    sta CasmPc + 1
    sta CasmPass1FinalPc + 1
    jsr emitCheckPassAgreement
    bcs pmCheckDiag
    sec                       ; unexpectedly matched -- fixture failure
    rts
pmCheckDiag:
    cmp #CASM_DIAG_PASS_MISMATCH
    bne pmFail
    clc                       ; correctly detected the mismatch -- pass
    rts
pmFail:
    sec
    rts

.segment "RODATA"

passMsg:
    .byte "CASM PASSCHECK: PASS", PetCr, 0
failMsg:
    .byte "CASM PASSCHECK: FAIL", PetCr, 0

.segment "BSS"

FailCount: .res 1

; This harness's own copies of the two filename buffers fileio.s imports
; (CasmSourceName/CasmOutputName) -- normally provided by cli.s, which this
; harness does not link. See the file header for the full rationale.
CasmSourceName: .res CASM_FILENAME_BUFFER_SIZE
CasmOutputName: .res CASM_FILENAME_BUFFER_SIZE
