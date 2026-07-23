; src/external/casm/emit.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 4 WP13 emission engine. This module tracks the program counter,
; writes the 2-byte PRG load-address header and the assembled bytes to the
; managed output file, processes the .ORG/.BYTE/.WORD directives, and encodes
; each matched instruction's operand bytes -- including the relative-branch
; displacement and range check deferred here from WP12.
;
; A single forward pass is sufficient: Phase 4 has no symbols or forward
; references, so every operand is a literal and the program counter is known at
; each instruction. Output is a plain absolute PRG (no relocation trailer).
;
; Bytes are staged in the bounded CasmEmitBuffer and flushed through fileWrite;
; the 256-byte CasmIoBuffer stays reserved for input, which is live during the
; same pass.

.include "common.inc"

.import CasmParserStmt
.import CasmInsn
.import fileWrite
.import lexerNext
.import CasmTokenRecord
.import parserParseExpressionValue

; WP15 diagnostic context. Statement-level failures use the stamped statement
; location; failures inside a .BYTE/.WORD operand list use the token record,
; which still points at the offending value.
.import diagSetLocFromToken
.import diagSetLocFromStmt

; WP30: emitCheckPassAgreement's failure is not "at" any particular source
; line (it fires after Pass 2 reaches EOF), so it clears any stale location
; left over from the last real statement rather than inheriting it.
.import diagClearLoc

.export emitInit
.export emitInstruction
.export emitDirective
.export emitFinalize
.export emitCheckPassAgreement
.export CasmPc
.export CasmPassMode
.export CasmPass1FinalPc

.segment "BSS"

CasmPc:         .res 2   ; next emit address (program counter)
CasmOrgSet:     .res 1   ; 0 until the initial .ORG is processed
CasmPcOverflow: .res 1   ; latched when the PC advances past $FFFF
CasmEmitLen:    .res 1   ; staged byte count in CasmEmitBuffer
CasmPassMode:   .res 1   ; CASM_PASS_MODE_MEASURE or CASM_PASS_MODE_EMIT
CasmEmitBuffer: .res CASM_EMIT_BUFFER_SIZE

; WP30: CasmPc snapshotted by the orchestration driver (casm.s) at the end of
; Pass 1, compared against the final CasmPc at the end of Pass 2 by
; emitCheckPassAgreement below. Lives here (not casm.s) so a standalone test
; harness can poke both cells directly and prove the comparison itself works
; -- casm.s's own HEADER/entry point can never be linked by a harness.
CasmPass1FinalPc: .res 2

.segment "CODE"

; ---------------------------------------------------------------------------
; emitInit
; Reset emission state for a fresh assembly. Does not create the output file.
; CasmPassMode is explicitly set to CASM_PASS_MODE_EMIT here rather than left
; to whatever BSS happens to hold at cold-start: CASM_PASS_MODE_EMIT is $01
; and CASM_PASS_MODE_MEASURE is $00, so uninitialized-to-zero BSS would
; silently default to MEASURE and produce no output. casm.s's current single
; caller of emitInit still expects one unconditional real-emission pass, so
; this keeps that behavior exact while giving a future two-pass orchestration
; an explicit point to override the mode before each pass.
; Outputs: C clear
; ---------------------------------------------------------------------------
emitInit:
    lda #0
    sta CasmOrgSet
    sta CasmPcOverflow
    sta CasmEmitLen
    lda #CASM_PASS_MODE_EMIT
    sta CasmPassMode
    clc
    rts

; ---------------------------------------------------------------------------
; emitFinalize
; Flush any staged bytes. The caller closes the output afterward.
; Outputs: C clear on success; C set with A = write diagnostic on failure
; ---------------------------------------------------------------------------
emitFinalize:
    jmp emitFlush

; ---------------------------------------------------------------------------
; emitCheckPassAgreement
; Compare CasmPc against CasmPass1FinalPc (the value the orchestration driver
; snapshotted at the end of Pass 1). A genuine disagreement is not believed
; reachable through any legitimate CASM source under the current grammar --
; CASM_PARSER_STMT_FORCE_ABS is derived from CASM_EXPR_FLAG_SYMBOL_DERIVED,
; which is set identically in both passes regardless of resolution state, and
; branch mnemonics never consult it at all -- this exists as a defensive
; internal invariant, not a demonstrated user-reachable path.
; Inputs:  CasmPc = the final program counter just reached (either pass);
;          CasmPass1FinalPc = the value snapshotted at the end of Pass 1
; Outputs: C clear if they match; C set with A = CASM_DIAG_PASS_MISMATCH if
;          they differ (locationless -- calls diagClearLoc first, since this
;          failure is not "at" any specific source line)
; Clobbers: A, processor flags
; ---------------------------------------------------------------------------
emitCheckPassAgreement:
    lda CasmPc
    cmp CasmPass1FinalPc
    bne ecpaMismatch
    lda CasmPc + 1
    cmp CasmPass1FinalPc + 1
    bne ecpaMismatch
    clc
    rts
ecpaMismatch:
    jsr diagClearLoc
    lda #CASM_DIAG_PASS_MISMATCH
    sec
    rts

; ---------------------------------------------------------------------------
; emitInstruction
; Emit a matched instruction: opcode followed by its operand bytes per
; CasmInsn.Length/Mode, using CasmParserStmt.Val.
; Inputs:  CasmInsn and CasmParserStmt populated for a MNEMONIC statement
; Outputs: C clear on success; C set with A = CASM_DIAG_* on failure
; Clobbers: A, X, Y, CasmEmitScratch0-3, fileWrite volatile state
; ---------------------------------------------------------------------------
emitInstruction:
    jsr emitRequireOrg
    bcc :+
    jmp eiRet                    ; WP30: pushed out of branch range by the
                                  ; new eiRelative pass-mode check below
:
    lda CasmInsn + CASM_INSN_OPCODE
    jsr emitByte
    bcs eiRet
    lda CasmInsn + CASM_INSN_LENGTH
    cmp #1
    beq eiDone
    cmp #2
    beq eiTwoByte
    ; length 3: 16-bit operand, little-endian
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    jsr emitByte
    bcs eiRet
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    jsr emitByte
    bcs eiRet
    clc
    rts

eiTwoByte:
    lda CasmInsn + CASM_INSN_MODE
    cmp #CASM_MODE_RELATIVE
    beq eiRelative
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    jsr emitByte
    bcs eiRet
    clc
    rts

eiRelative:
    ; nextPc = CasmPc + 1 (address after the operand byte = branch + 2). The
    ; opcode already advanced CasmPc by 1, so CasmPc is the operand position.
    lda CasmPc
    clc
    adc #1
    sta CasmEmitScratch0
    lda CasmPc + 1
    adc #0
    sta CasmEmitScratch1
    ; disp = target(Val) - nextPc
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    sec
    sbc CasmEmitScratch0
    sta CasmEmitScratch2          ; displacement low
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    sbc CasmEmitScratch1
    sta CasmEmitScratch3          ; displacement high (sign)

    ; WP30: a still-unresolved forward reference carries a $0000 placeholder
    ; in MEASURE mode (parser.s's pevMeasureUnresolved), which computes a
    ; meaningless displacement against this pass's real CasmPc -- almost
    ; always wildly out of range regardless of the real (Pass 2) resolved
    ; distance. Skip the range check entirely in MEASURE mode: the operand
    ; byte's value doesn't matter either, since emitRawByte's single gate
    ; never writes it. Enforce the range for real only in EMIT mode, once
    ; every symbol is genuinely resolved -- mirrors the same tolerate-in-
    ; MEASURE/enforce-in-EMIT pattern already used for
    ; CASM_DIAG_UNDEFINED_SYMBOL (parser.s's pevUnresolved).
    lda CasmPassMode
    cmp #CASM_PASS_MODE_MEASURE
    beq eiRelEmit

    ; Valid range -128..+127: high==$00 with low<$80, or high==$FF with low>=$80.
    lda CasmEmitScratch3
    beq eiRelPos
    cmp #$FF
    bne eiBranchErr
    lda CasmEmitScratch2
    cmp #$80
    bcc eiBranchErr               ; high==$FF but low<128 -> out of range
    bcs eiRelEmit
eiRelPos:
    lda CasmEmitScratch2
    cmp #$80
    bcs eiBranchErr               ; high==0 but low>=128 -> out of range
eiRelEmit:
    lda CasmEmitScratch2
    jsr emitByte
    bcs eiRet
    clc
    rts
eiBranchErr:
    jsr diagSetLocFromStmt      ; the branch instruction's own line
    lda #CASM_DIAG_BRANCH_OUT_OF_RANGE
    sec
    rts

eiDone:
    clc
eiRet:
    rts

; ---------------------------------------------------------------------------
; emitDirective
; Dispatch a DIRECTIVE statement. .ORG uses the operand already parsed into
; CasmParserStmt.Val; .BYTE/.WORD read their comma-separated operand lists
; directly from the lexer (the parser deferred them). Unsupported directives
; are rejected.
; Outputs: C clear on success; C set with A = CASM_DIAG_* on failure
; ---------------------------------------------------------------------------
emitDirective:
    lda CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    cmp #CASM_DIRECTIVE_ORG
    beq edOrg
    cmp #CASM_DIRECTIVE_BYTE
    beq edByte
    cmp #CASM_DIRECTIVE_WORD
    beq edWord
    cmp #CASM_DIRECTIVE_UNKNOWN
    beq edSyntax
    ; .STATIC / .RELOC / .INCLUDE: out of scope this phase.
    lda #CASM_DIAG_NOT_IMPLEMENTED
    sec
    rts
edSyntax:
    jsr diagSetLocFromStmt      ; the unrecognized directive
    lda #CASM_DIAG_SYNTAX_ERROR
    sec
    rts
edOrg:
    jmp emitOrg
edByte:
    jmp emitByteList
edWord:
    jmp emitWordList

; ---------------------------------------------------------------------------
; emitOrg (private)
; Set the program counter and write the PRG load-address header. Rejects a
; second .ORG.
; ---------------------------------------------------------------------------
emitOrg:
    ; .ORG requires a plain numeric operand. The statement grammar is shared
    ; with instructions, so a bare ".ORG" parses as OPKIND_IMPLIED with value 0
    ; and every other operand form (".ORG A", ".ORG #$10", ".ORG $10,X",
    ; ".ORG ($10)") parses as its own kind -- all of which would otherwise be
    ; accepted here as a silent origin of $0000 or a bogus origin, because the
    ; value fields alone cannot distinguish them. OPKIND_ABSOLUTE covers both
    ; zero-page and absolute numeric operands, so it is the only kind allowed.
    lda CasmParserStmt + CASM_PARSER_STMT_OPKIND
    cmp #CASM_OPKIND_ABSOLUTE
    beq eoKindOk
    jsr diagSetLocFromStmt      ; the malformed .ORG statement
    lda #CASM_DIAG_SYNTAX_ERROR
    sec
    rts
eoKindOk:
    lda CasmOrgSet
    beq eoSet
    jsr diagSetLocFromStmt      ; the offending second .ORG
    lda #CASM_DIAG_DUPLICATE_ORG
    sec
    rts
eoSet:
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    sta CasmPc
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    sta CasmPc + 1
    lda #1
    sta CasmOrgSet
    lda #0
    sta CasmPcOverflow
    ; Write the 2-byte load address as the PRG header (no PC advance).
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    jsr emitRawByte
    bcs eoFail
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    jsr emitRawByte
    bcs eoFail
    clc
    rts
eoFail:
    rts

; ---------------------------------------------------------------------------
; emitByteList / emitWordList (private)
; Read a comma-separated numeric operand list from the lexer and emit it. At
; least one value is required. .BYTE values must fit 8 bits.
; ---------------------------------------------------------------------------
emitByteList:
    jsr emitRequireOrg
    bcs eblRet
eblRead:
    jsr lexerNext
    bcs eblRet
    jsr parserParseExpressionValue
    bcs eblRet
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    bne eblRange
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    jsr emitByte
    bcs eblRet
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_COMMA
    beq eblRead
    cmp #CASM_TOKEN_NEWLINE
    beq eblDone
    cmp #CASM_TOKEN_EOF
    beq eblDone
eblSyntax:
    jsr diagSetLocFromToken     ; the bad token within the .BYTE list
    lda #CASM_DIAG_SYNTAX_ERROR
    sec
    rts
eblRange:
    ; parserParseExpressionValue preserved the expression-start location before
    ; advancing to this element's delimiter.
    lda #CASM_DIAG_OPERAND_OUT_OF_RANGE
    sec
    rts
eblDone:
    clc
eblRet:
    rts

emitWordList:
    jsr emitRequireOrg
    bcs ewlRet
ewlRead:
    jsr lexerNext
    bcs ewlRet
    jsr parserParseExpressionValue
    bcs ewlRet
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    jsr emitByte
    bcs ewlRet
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    jsr emitByte
    bcs ewlRet
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_COMMA
    beq ewlRead
    cmp #CASM_TOKEN_NEWLINE
    beq ewlDone
    cmp #CASM_TOKEN_EOF
    beq ewlDone
ewlSyntax:
    jsr diagSetLocFromToken     ; the bad token within the .WORD list
    lda #CASM_DIAG_SYNTAX_ERROR
    sec
    rts
ewlDone:
    clc
ewlRet:
    rts

; ---------------------------------------------------------------------------
; emitRequireOrg (private)
; Outputs: C clear when .ORG has been seen; C set with A = ORG_REQUIRED else.
; ---------------------------------------------------------------------------
emitRequireOrg:
    lda CasmOrgSet
    bne eroOk
    jsr diagSetLocFromStmt      ; the first statement needing an origin
    lda #CASM_DIAG_ORG_REQUIRED
    sec
    rts
eroOk:
    clc
    rts

; ---------------------------------------------------------------------------
; emitByte (private)
; Stage one program byte and advance the program counter with overflow check.
; Inputs:  A = byte
; Outputs: C clear on success; C set with A = ADDRESS_OVERFLOW or write
;          diagnostic on failure
; ---------------------------------------------------------------------------
emitByte:
    ldx CasmPcOverflow
    beq ebEmit
    lda #CASM_DIAG_ADDRESS_OVERFLOW
    sec
    rts
ebEmit:
    jsr emitRawByte
    bcs ebFail
    inc CasmPc
    bne ebDone
    inc CasmPc + 1
    bne ebDone
    lda #1
    sta CasmPcOverflow
ebDone:
    clc
    rts
ebFail:
    rts

; ---------------------------------------------------------------------------
; emitRawByte (private)
; Append one byte to the staging buffer, flushing when full. Does not touch the
; program counter (used for the PRG header and by emitByte).
; In CASM_PASS_MODE_MEASURE, the byte in A is silently discarded and no buffer
; state changes -- MEASURE mode exists to compute sizes/addresses without
; producing output, and this is the single gate all emission paths funnel
; through (emitByte's PC/overflow tracking still runs unconditionally above
; its call here, so addresses stay correct in both modes). The input byte is
; stashed in X across the CasmPassMode check (X is otherwise unused until
; CasmEmitLen is loaded below) so the pass-mode load does not clobber it.
; Inputs:  A = byte
; Outputs: C clear on success; C set with A = write diagnostic on failure
; ---------------------------------------------------------------------------
emitRawByte:
    tax
    lda CasmPassMode
    cmp #CASM_PASS_MODE_MEASURE
    beq erbDone
    txa
    ldx CasmEmitLen
    sta CasmEmitBuffer, x
    inx
    stx CasmEmitLen
    cpx #CASM_EMIT_BUFFER_SIZE
    bcc erbDone
    jsr emitFlush
    bcs erbFail
erbDone:
    clc
    rts
erbFail:
    rts

; ---------------------------------------------------------------------------
; emitFlush (private)
; Write the staged bytes to the managed output and clear the buffer.
; Outputs: C clear on success; C set with A = write diagnostic on failure
; ---------------------------------------------------------------------------
emitFlush:
    lda CasmEmitLen
    bne efWrite
    clc
    rts
efWrite:
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx #<CasmEmitBuffer
    ldy #>CasmEmitBuffer
    jsr fileWrite
    bcs efFail
    lda #0
    sta CasmEmitLen
    clc
    rts
efFail:
    rts
