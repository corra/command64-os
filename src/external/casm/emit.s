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
; each instruction. Output is a plain PRG; WP38 (Phase 8) adds the optional
; default relocatable origin, but no relocation table or R6 trailer exists
; yet (WP39-WP41).
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
.import CasmTokenText
.import CasmStringLength
.import CasmStringBuffer
.import parserParseExpressionValue
.import CasmCliOptions
.import relocRecord
.import listingMirrorByte
.import progressBeginDirective
.import progressDirectiveBytes
.import progressAccumulateOutputBytes

; WP81: .RES/.FILL/.ALIGN's resolved count/boundary and value/fill byte,
; staged by parser.s's ppsFillDirective.
.import CasmFillCountLo
.import CasmFillCountHi
.import CasmFillValue

; WP82: .INCBIN's filename, staged by parser.s's ppsIncbin, plus the
; managed input-stream wrappers (fileio.s) and the shared 256-byte I/O
; buffer they stream through.
.import CasmIncbinFilename
.import CasmAssertValueLo
.import CasmAssertValueHi
.import inputStreamOpen
.import inputStreamRead
.import inputStreamClose
.import CasmIoBuffer

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
.export emitMarkStarted
.export CasmPc
.export CasmPassMode
.export CasmPass1FinalPc
.export CasmRelocatableMode

.segment "BSS"

CasmPc:         .res 2   ; next emit address (program counter)
; WP38: renamed from CasmOrgSet and broadened from "an explicit .ORG has
; been processed" to "a label, a byte, or an explicit .ORG has already been
; processed this pass" -- 0 until the first such event. Read by emitOrg
; (reject a second/late .ORG) and emitMarkStarted (the shared guard for
; every other qualifying statement kind).
CasmOutputStarted: .res 1
; WP39: records *which* mode CasmOutputStarted committed to -- 0 for an
; explicit .ORG (static), 1 for the implicit default (relocatable).
; CasmOutputStarted alone cannot answer "is this assembly relocatable" for
; a later statement's expression classification, since it does not record
; which of the two commit sites (emitOrg vs. emitMarkStarted) set it. Reset
; every pass in emitInit; read by parser.s (parserParseExpressionValue) and
; passed into exprEvaluate as an input, not imported by expr.s directly.
CasmRelocatableMode: .res 1
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

; WP81: emitAlign's own bounded 16-iteration restoring-division scratch
; (CasmPc mod boundary), same algorithm shape as expr.s's private
; divUnsigned16 but remainder-only (no quotient needed) and self-contained
; here rather than exporting expr.s's private division internals just for
; this one caller.
CasmAlignDividendLo: .res 1
CasmAlignDividendHi: .res 1
CasmAlignRemLo:      .res 1
CasmAlignRemHi:      .res 1
CasmAlignRemExt:      .res 1

; WP82: emitIncbin's own per-chunk remaining-byte counter (16-bit; a full
; CasmIoBuffer chunk is up to 256 bytes, so CasmIncbinRemHi can be 0 or 1)
; and buffer read index.
CasmIncbinRemLo: .res 1
CasmIncbinRemHi: .res 1
CasmIncbinIdx:   .res 1
CasmIncbinAcceptedLo: .res 1
CasmIncbinAcceptedHi: .res 1

; CASM progress Increment 6: fixed-fill operations are processed in explicit
; chunks of at most 256 successfully accepted bytes. The accepted count remains
; emitter-owned until each chunk commits; Atomic Increment 3 will notify
; progress.s only at that boundary, never from the per-byte inner loop.
CasmFillChunkLo:    .res 1
CasmFillChunkHi:    .res 1
CasmFillAcceptedLo: .res 1
CasmFillAcceptedHi: .res 1

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
;
; WP38: also primes CasmPc every pass, closing a cross-pass hazard that only
; stayed safe while .ORG was mandatory-and-first: an explicit .ORG (if given)
; always overwrites CasmPc unconditionally before any label or byte (emitOrg),
; so priming a default value here first and letting .ORG overwrite it second
; is equivalent to today's behavior whenever .ORG is actually given. Under
; /S, CasmPc is left at zero instead -- static mode has no configured
; default, and a first statement reached with no .ORG yet is rejected by
; emitMarkStarted before CasmPc's value could matter.
; Outputs: C clear
; ---------------------------------------------------------------------------
emitInit:
    lda #0
    sta CasmOutputStarted
    sta CasmRelocatableMode
    sta CasmPcOverflow
    sta CasmEmitLen
    lda #CASM_PASS_MODE_EMIT
    sta CasmPassMode

    lda CasmCliOptions
    and #CASM_OPT_STATIC
    bne eiStatic
    lda #<CASM_DEFAULT_ORIGIN
    sta CasmPc
    lda #>CASM_DEFAULT_ORIGIN
    sta CasmPc + 1
    clc
    rts
eiStatic:
    lda #0
    sta CasmPc
    sta CasmPc + 1
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
    jsr emitMarkStarted
    bcc :+
    jmp eiRet                    ; WP30: pushed out of branch range by the
                                  ; new eiRelative pass-mode check below
:
    lda CasmInsn + CASM_INSN_OPCODE
    jsr emitByte
    bcs eiOpcodeFail             ; WP40: pushed out of branch range by the
                                  ; new length-3 relocation hooks below
    lda CasmInsn + CASM_INSN_LENGTH
    cmp #1
    beq eiLenOneDone             ; WP40: same reason
    cmp #2
    beq eiTwoByte
    jmp eiLenThree
eiOpcodeFail:
    jmp eiRet
eiLenOneDone:
    jmp eiDone
eiLenThree:
    ; length 3: 16-bit operand, little-endian. Covers CASM_MODE_ABSOLUTE/
    ; _X/_Y/_INDIRECT uniformly (WP37 finding, unchanged) -- one shared
    ; hook, no per-mode branching. WP40: emitMaybeRecordLo/Hi disambiguate
    ; a genuine full value (ValHi is the real relocatable byte) from a
    ; >-extracted value stored in ValLo (ValHi is applyExtraction's zero
    ; pad) using ValHi's own zero/nonzero state -- see this WP's plan.
    jsr emitMaybeRecordLo
    bcs eiRet
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    jsr emitByte
    bcs eiRet
    jsr emitMaybeRecordHi
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
    ; WP40: only CASM_MODE_IMMEDIATE may ever hold a relocatable byte here --
    ; the other length-2 modes sharing this code path (zero-page family,
    ; indexed-indirect, indirect-indexed) must never be recorded, even
    ; though a relocatable symbol can structurally reach indexed-indirect/
    ; indirect-indexed via explicit >-extraction (ofRequire8Bit in
    ; opcodes.s permits it) -- the master plan explicitly excludes those
    ; pointer bytes. Zero-page/_X/_Y are excluded defensively; they are
    ; already structurally unreachable for any symbol-derived operand
    ; (FORCE_ABS always promotes them to the absolute family instead).
    cmp #CASM_MODE_IMMEDIATE
    bne eiTwoByteEmit
    jsr emitMaybeRecordLo
    bcs eiRet
eiTwoByteEmit:
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
    cmp #CASM_DIRECTIVE_RES
    beq edRes
    cmp #CASM_DIRECTIVE_FILL
    beq edFill
    cmp #CASM_DIRECTIVE_ALIGN
    beq edAlign
    cmp #CASM_DIRECTIVE_INCBIN
    beq edIncbin
    cmp #CASM_DIRECTIVE_ASSERT
    beq edAssert
    cmp #CASM_DIRECTIVE_UNKNOWN
    beq edSyntax
    cmp #CASM_DIRECTIVE_INCLUDE
    beq edInternal
    ; .STATIC / .RELOC: out of scope this phase.
    lda #CASM_DIAG_NOT_IMPLEMENTED
    sec
    rts
edRes:
    jmp emitRes
edFill:
    jmp emitFill
edAlign:
    jmp emitAlign
edIncbin:
    jmp emitIncbin
edAssert:
    jmp emitAssert
edInternal:
    ; Includes alter the token source and are owned by casmRunPass. Reaching
    ; the emitter indicates an internal dispatch error, not unsupported syntax.
    lda #CASM_DIAG_UNKNOWN
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
; Set the program counter and write the PRG load-address header, forcing
; static mode at the given address. Rejects a .ORG that arrives after output
; has already started -- either a genuine second .ORG, or (WP38) one arriving
; after an implicit default-origin statement already ran.
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
    ; WP38: CasmOutputStarted now also catches a late .ORG arriving after an
    ; implicit default origin already began output (emitMarkStarted), not
    ; only a genuine second .ORG -- both are, structurally, ".ORG arrived
    ; after output had already started," and CASM_DIAG_DUPLICATE_ORG's
    ; existing message text does not claim the earlier event was itself an
    ; .ORG. Reuse confirmed during WP38 planning rather than adding a new
    ; diagnostic identifier.
    lda CasmOutputStarted
    beq eoSet
    jsr diagSetLocFromStmt      ; the offending .ORG
    lda #CASM_DIAG_DUPLICATE_ORG
    sec
    rts
eoSet:
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    sta CasmPc
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    sta CasmPc + 1
    lda #1
    sta CasmOutputStarted
    lda #0
    sta CasmPcOverflow
    sta CasmRelocatableMode     ; WP39: explicit .ORG -> static, not relocatable
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
    jsr emitMarkStarted
    bcs eblRet
eblRead:
    jsr lexerNext
    bcs eblRet
    ; WP69: a character literal is a direct 8-bit value, never a general
    ; expression primary -- short-circuits straight to CasmTokenText[0],
    ; bypassing parserParseExpressionValue/exprEvaluate entirely, same as
    ; posImmediateChar (parser.s).
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_STRING
    beq eblString
    cmp #CASM_TOKEN_CHAR
    bne eblExpr
    lda CasmTokenText
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    lda #0
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    sta CasmParserStmt + CASM_PARSER_STMT_FLAGS
    jsr lexerNext                ; advance past CHAR, leave delimiter current
    bcs eblRet
    jmp eblStore
eblString:
    lda #0
    sta CasmEmitScratch0
eblStringLoop:
    ldx CasmEmitScratch0
    cpx CasmStringLength
    beq eblStringDone
    lda CasmStringBuffer, x
    jsr emitByte
    bcs eblRet
    inc CasmEmitScratch0
    jmp eblStringLoop
eblStringDone:
    jsr lexerNext                ; advance past STRING, leave delimiter current
    bcs eblRet
    jmp eblDelimiter
eblExpr:
    jsr parserParseExpressionValue
    bcs eblRet
eblStore:
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    bne eblRange
    ; WP40: eblRange above already guarantees ValHi == 0 here, so the only
    ; way RELOCATABLE can be set on this single emitted byte is explicit
    ; >-extraction (ValLo holds the real relocatable byte) -- checking
    ; RELOCATABLE alone is already equivalent to the fuller ValHi==0 rule.
    jsr emitMaybeRecordLo
    bcs eblRet
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    jsr emitByte
    bcs eblRet
eblDelimiter:
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
    jsr emitMarkStarted
    bcs ewlRet
ewlRead:
    jsr lexerNext
    bcs ewlRet
    jsr parserParseExpressionValue
    bcs ewlRet
    ; WP40: same ValHi-zero/nonzero disambiguation as emitInstruction's
    ; length-3 branch -- .WORD >LABEL is valid syntax (parserParseExpressionValue
    ; is shared with every other operand context), so ValLo can equally
    ; hold the real relocatable byte here, with ValHi as applyExtraction's
    ; zero pad.
    jsr emitMaybeRecordLo
    bcs ewlRet
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    jsr emitByte
    bcs ewlRet
    jsr emitMaybeRecordHi
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
; emitRes / emitFill (WP81)
; Emit CasmFillCountLo/Hi bytes, each CasmFillValue, both already resolved by
; parser.s's ppsFillDirective in this pass (Scoping Decision 1 -- no
; unresolved-operand path reaches here). No relocation interaction: padding/
; reserved bytes are inert filler, identical to a `.BYTE $00` byte today
; (parent plan's Research Summary point 4).
; Outputs: C clear on success; C set with A = CASM_DIAG_* on failure
; ---------------------------------------------------------------------------
emitRes:
    jsr emitMarkStarted
    bcs erRet
    lda #CASM_DIRECTIVE_RES
    jsr progressBeginDirective
    lda CasmFillCountLo
    sta CasmEmitScratch0
    lda CasmFillCountHi
    sta CasmEmitScratch1
    jmp emitFillLoop
erRet:
    rts

emitFill:
    jsr emitMarkStarted
    bcs efRet
    lda #CASM_DIRECTIVE_FILL
    jsr progressBeginDirective
    lda CasmFillCountLo
    sta CasmEmitScratch0
    lda CasmFillCountHi
    sta CasmEmitScratch1
    jmp emitFillLoop
efRet:
    rts

; ---------------------------------------------------------------------------
; emitAlign (WP81)
; Pad with CasmFillValue bytes until CasmPc is a multiple of the resolved
; boundary (CasmFillCountLo/Hi -- ppsFillDirective stages .ALIGN's boundary
; operand into the same field .RES/.FILL use for their count). Padding is
; computed fresh from this pass's own CasmPc every call, never cached/
; carried between passes (Technical Design, brain/plans/2026-08-21-casm-
; phase13-wp81-res-fill-align.md).
; Outputs: C clear on success; C set with A = CASM_DIAG_ALIGN_BOUNDARY_ZERO
;          or another CASM_DIAG_* on failure
; ---------------------------------------------------------------------------
emitAlign:
    jsr emitMarkStarted
    bcs eaRet
    lda CasmFillCountLo
    ora CasmFillCountHi
    bne eaBoundaryOk
    jsr diagSetLocFromStmt      ; the .ALIGN statement itself
    lda #CASM_DIAG_ALIGN_BOUNDARY_ZERO
    sec
    rts
eaBoundaryOk:
    lda #CASM_DIRECTIVE_ALIGN
    jsr progressBeginDirective
    jsr emitAlignMod            ; CasmAlignRemLo/Hi = CasmPc mod boundary
    lda CasmAlignRemLo
    ora CasmAlignRemHi
    beq eaPadZero
    sec
    lda CasmFillCountLo
    sbc CasmAlignRemLo
    sta CasmEmitScratch0
    lda CasmFillCountHi
    sbc CasmAlignRemHi
    sta CasmEmitScratch1
    jmp emitFillLoop
eaPadZero:
    lda #0
    sta CasmEmitScratch0
    sta CasmEmitScratch1
    jmp emitFillLoop
eaRet:
    rts

; ---------------------------------------------------------------------------
; emitAlignMod (private)
; Bounded 16-iteration unsigned restoring division, remainder only: computes
; CasmAlignRemLo/Hi = CasmPc mod (CasmFillCountLo/Hi), the resolved nonzero
; boundary. Same shape as expr.s's private divUnsigned16 (which discards its
; own remainder) but self-contained here -- exporting expr.s's division
; internals for this one caller was not worth the coupling.
; Inputs:    CasmFillCountLo/Hi nonzero (caller's own eaBoundaryOk gate)
; Outputs:   CasmAlignRemLo/Hi = CasmPc mod boundary
; Clobbers:  A, X, CasmAlignDividendLo/Hi, CasmAlignRemLo/Hi/Ext
; ---------------------------------------------------------------------------
emitAlignMod:
    lda CasmPc
    sta CasmAlignDividendLo
    lda CasmPc + 1
    sta CasmAlignDividendHi
    lda #0
    sta CasmAlignRemLo
    sta CasmAlignRemHi
    sta CasmAlignRemExt
    ldx #16
eamLoop:
    asl CasmAlignDividendLo
    rol CasmAlignDividendHi
    rol CasmAlignRemLo
    rol CasmAlignRemHi
    rol CasmAlignRemExt
    lda CasmAlignRemExt
    bne eamDoSub
    lda CasmAlignRemHi
    cmp CasmFillCountHi
    bcc eamNoSub
    bne eamDoSub
    lda CasmAlignRemLo
    cmp CasmFillCountLo
    bcc eamNoSub
eamDoSub:
    sec
    lda CasmAlignRemLo
    sbc CasmFillCountLo
    sta CasmAlignRemLo
    lda CasmAlignRemHi
    sbc CasmFillCountHi
    sta CasmAlignRemHi
    lda CasmAlignRemExt
    sbc #0
    sta CasmAlignRemExt
eamNoSub:
    dex
    bne eamLoop
    rts

; ---------------------------------------------------------------------------
; emitFillLoop (private, WP81; bounded chunks added by progress Increment 6)
; Shared byte-emission loop for emitRes/emitFill/emitAlign: emit
; CasmEmitScratch1:CasmEmitScratch0 (16-bit remaining count) bytes of
; CasmFillValue in outer chunks of at most 256 bytes. The inner loop increments
; CasmFillAccepted only after emitByte succeeds, then decrements both the
; authoritative total remaining and current chunk remaining. emitByte's own
; CasmPassMode gate already handles Pass 1 discarding the write while CasmPc
; still advances for real (Research Summary point 2) -- no separate
; measure-only path needed here.
; Inputs:    CasmEmitScratch0/1 = remaining count (16-bit); CasmFillValue
; Outputs:   C clear on success; C set with A = CASM_DIAG_* on failure
; Clobbers:  A, X, Y, CasmEmitScratch0/1, CasmFillChunkLo/Hi,
;            CasmFillAcceptedLo/Hi, CasmPc, emitByte's own volatile state
; ---------------------------------------------------------------------------
emitFillLoop:
    lda #0
    sta CasmFillAcceptedLo
    sta CasmFillAcceptedHi
eflNextChunk:
    lda CasmEmitScratch0
    ora CasmEmitScratch1
    beq eflDone
    ; A nonzero high byte means at least 256 bytes remain: encode a full
    ; chunk as $0100. Otherwise the low byte is the final 1-255-byte tail.
    lda CasmEmitScratch1
    beq eflFinalChunk
    lda #0
    sta CasmFillChunkLo
    lda #1
    sta CasmFillChunkHi
    jmp eflByte
eflFinalChunk:
    lda CasmEmitScratch0
    sta CasmFillChunkLo
    lda #0
    sta CasmFillChunkHi
eflByte:
    lda CasmFillChunkLo
    ora CasmFillChunkHi
    bne :+
    lda CasmFillAcceptedLo
    ldx CasmFillAcceptedHi
    jsr progressDirectiveBytes
    jmp eflNextChunk
    :
    lda CasmFillValue
    jsr emitByte
    bcs eflRet
    inc CasmFillAcceptedLo
    bne :+
    inc CasmFillAcceptedHi
    :
    lda CasmEmitScratch0
    bne :+
    dec CasmEmitScratch1
    :
    dec CasmEmitScratch0
    lda CasmFillChunkLo
    bne :+
    dec CasmFillChunkHi
    :
    dec CasmFillChunkLo
    jmp eflByte
eflDone:
    clc
eflRet:
    rts

; ---------------------------------------------------------------------------
; emitIncbin (WP82)
; Stream CasmIncbinFilename's entire contents through emitByte, verbatim,
; starting at the current CasmPc. Opens/reads/closes the file transiently
; every pass (CasmInputState is guaranteed CLOSED whenever a statement is
; being parsed/emitted -- sourceLoad has already closed the main source by
; the time any statement runs, WP82 plan's own Research Summary point 3),
; relying on emitByte's existing CasmPassMode gate for Pass 1's discard-but-
; advance behavior (same minimalism as emitFillLoop, no separate measure-
; only path) and on the existing whole-assembly emitCheckPassAgreement for
; Pass1/Pass2 length agreement (Scoping Decision 2, user-confirmed
; 2026-08-21 -- no dedicated per-occurrence check).
; Outputs: C clear on success; C set with A = CASM_DIAG_* on failure
; ---------------------------------------------------------------------------
emitIncbin:
    jsr emitMarkStarted
    bcs eibRet
    lda #CASM_DIRECTIVE_INCBIN
    jsr progressBeginDirective
    lda #0
    sta CasmIncbinAcceptedLo
    sta CasmIncbinAcceptedHi
    ldx #<CasmIncbinFilename
    ldy #>CasmIncbinFilename
    jsr inputStreamOpen
    bcs eibRet
eibReadLoop:
    jsr inputStreamRead
    bcs eibReadFail
    cmp #CASM_STREAM_EOF
    beq eibEof
    lda CasmIoLenLo
    sta CasmIncbinRemLo
    lda CasmIoLenHi
    sta CasmIncbinRemHi
    lda #0
    sta CasmIncbinIdx
eibByteLoop:
    lda CasmIncbinRemLo
    ora CasmIncbinRemHi
    bne :+
    lda CasmIncbinAcceptedLo
    ldx CasmIncbinAcceptedHi
    jsr progressDirectiveBytes
    jmp eibReadLoop             ; chunk committed -- read the next one
    :
    ldx CasmIncbinIdx
    lda CasmIoBuffer, x
    jsr emitByte
    bcs eibEmitFail
    inc CasmIncbinAcceptedLo
    bne :+
    inc CasmIncbinAcceptedHi
    :
    inc CasmIncbinIdx
    lda CasmIncbinRemLo
    bne eibDec
    dec CasmIncbinRemHi
eibDec:
    dec CasmIncbinRemLo
    jmp eibByteLoop
eibEof:
    jmp inputStreamClose        ; C/A = its own NONE/CLOSE_FAILED result
eibReadFail:
    ; A/C already hold inputStreamRead's own diagnostic. Best-effort close
    ; without disturbing it -- a failed close here is not the reported cause.
    pha
    jsr inputStreamClose
    pla
    sec
    rts
eibEmitFail:
    ; Same precedent as eibReadFail -- emitByte's own diagnostic wins.
    pha
    jsr inputStreamClose
    pla
    sec
    rts
eibRet:
    rts

; ---------------------------------------------------------------------------
; emitAssert (WP83)
; Check ppsAssert's resolved expression value (CasmAssertValueLo/Hi):
; nonzero is a passing assertion (zero bytes emitted, success), zero fails
; the whole assembly with a diagnostic. No emitMarkStarted call -- .ASSERT
; never emits a byte, so it cannot be "the first statement" of a
; relocatable assembly in any meaningful sense (Language Contract,
; brain/plans/2026-08-21-casm-phase13-wp83-assert.md).
;
; This increment only implements the no-message failure path
; (CASM_DIAG_ASSERTION_FAILED) regardless of whether CasmAssertMessageLen
; is nonzero -- the message-echo diagnostic path is Increment 6's own
; work, per the plan's own increment split.
; Outputs: C clear on success (no bytes emitted); C set with
;          A = CASM_DIAG_ASSERTION_FAILED on failure
; ---------------------------------------------------------------------------
emitAssert:
    lda CasmAssertValueLo
    ora CasmAssertValueHi
    bne eaeOk
    jsr diagSetLocFromStmt      ; the failing .ASSERT statement itself
    lda #CASM_DIAG_ASSERTION_FAILED
    sec
    rts
eaeOk:
    clc
    rts

; ---------------------------------------------------------------------------
; emitMarkStarted
; WP38: the shared guard for every statement kind that establishes output has
; begun -- MNEMONIC/.BYTE/.WORD emission (emitInstruction/emitByteList/
; emitWordList) and label definitions (casm.s's crpLabel). No-ops immediately
; once output has already started -- the common case for every statement
; past the first, whether output began via an explicit .ORG (emitOrg sets
; CasmOutputStarted directly) or via this routine's own implicit-default
; path below.
;
; On the first qualifying statement of a pass: under /S with no .ORG yet,
; fails with CASM_DIAG_ORG_REQUIRED, exactly the prior mandatory-.ORG
; behavior, now reached only in this narrower case. Otherwise, this is the
; first statement of a relocatable (non-/S) assembly with no .ORG -- write
; the 2-byte PRG header from CasmPc, already primed to CASM_DEFAULT_ORIGIN by
; emitInit, through the same emitRawByte path emitOrg's own header write
; uses, so it inherits the existing CASM_PASS_MODE_MEASURE no-op gate with no
; new pass-mode branching here.
;
; emitOrg does not call this routine -- it performs its own explicit-origin
; header write and sets CasmOutputStarted directly, to avoid writing the
; header twice.
;
; WP39: the implicit-default path also sets CasmRelocatableMode = 1
; (emitOrg's own success path sets it 0), so a later statement's expression
; classification can tell which mode this pass committed to.
; Outputs: C clear on success (including the already-started no-op case);
;          C set with A = CASM_DIAG_ORG_REQUIRED or a write diagnostic on
;          failure
; ---------------------------------------------------------------------------
emitMarkStarted:
    lda CasmOutputStarted
    bne emsOk
    lda CasmCliOptions
    and #CASM_OPT_STATIC
    beq emsDefault
    jsr diagSetLocFromStmt      ; the first statement needing an origin
    lda #CASM_DIAG_ORG_REQUIRED
    sec
    rts
emsDefault:
    lda #1
    sta CasmOutputStarted
    sta CasmRelocatableMode     ; WP39: implicit default -> relocatable
    lda CasmPc
    jsr emitRawByte
    bcs emsFail
    lda CasmPc + 1
    jsr emitRawByte
    bcs emsFail
emsOk:
    clc
    rts
emsFail:
    rts

; ---------------------------------------------------------------------------
; emitMaybeRecordHi (private)
; WP40: record the current byte position (CasmPc) in the relocation table
; iff CASM_PARSER_STMT_RELOCATABLE is set and CasmParserStmt.ValHi != 0 --
; the full, non-extracted value case, where ValHi holds the real
; relocatable byte. Called immediately before the emitByte call that writes
; that same ValHi byte, so CasmPc still equals its address.
; Outputs: C clear on success (including the no-op case); C set with
;          A = CASM_DIAG_* on failure
; ---------------------------------------------------------------------------
emitMaybeRecordHi:
    lda CasmParserStmt + CASM_PARSER_STMT_FLAGS
    and #CASM_PARSER_STMT_RELOCATABLE
    beq emrhOk
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    beq emrhOk
    jmp relocRecord
emrhOk:
    clc
    rts

; ---------------------------------------------------------------------------
; emitMaybeRecordLo (private)
; WP40: record the current byte position (CasmPc) in the relocation table
; iff CASM_PARSER_STMT_RELOCATABLE is set and CasmParserStmt.ValHi == 0 --
; the explicit >-extraction case, where ValLo holds the real relocatable
; byte and ValHi is applyExtraction's zero pad (expr.s). A genuine
; relocatable address's real high byte can never be zero while running in
; EMIT mode (CASM_DEFAULT_ORIGIN is $3400), so ValHi == 0 alongside
; RELOCATABLE reliably means extraction happened, never a coincidental
; full-value match -- see this WP's plan (Dependency Review items 1-2) for
; the full reasoning. Called immediately before the emitByte call that
; writes that same ValLo byte.
; Outputs: C clear on success (including the no-op case); C set with
;          A = CASM_DIAG_* on failure
; ---------------------------------------------------------------------------
emitMaybeRecordLo:
    lda CasmParserStmt + CASM_PARSER_STMT_FLAGS
    and #CASM_PARSER_STMT_RELOCATABLE
    beq emrlOk
    lda CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    bne emrlOk
    jmp relocRecord
emrlOk:
    clc
    rts

; ---------------------------------------------------------------------------
; emitByte (private)
; Stage one program byte and advance the program counter with overflow check.
; WP51: also mirrors the byte into the listing capture's byte store
; (listingMirrorByte, a no-op when capture is disabled) after emitRawByte
; accepts it -- PRG acceptance therefore precedes mirror acceptance, and a
; mirror failure returns before the PC increment, following the existing
; incomplete-PRG abort path.
; Inputs:  A = byte
; Outputs: C clear on success; C set with A = ADDRESS_OVERFLOW, a write
;          diagnostic, or a listing diagnostic on failure
; Clobbers: A, X (the byte is stacked across emitRawByte/listingMirrorByte;
;          see listingMirrorByte for its own X/Y/VMM-scratch clobbers)
; ---------------------------------------------------------------------------
emitByte:
    ldx CasmPcOverflow
    beq ebEmit
    lda #CASM_DIAG_ADDRESS_OVERFLOW
    sec
    rts
ebEmit:
    pha                          ; preserve the byte for the mirror call below
    jsr emitRawByte
    bcs ebRawFail
    pla
    jsr listingMirrorByte        ; no-op when listing capture is disabled
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
ebRawFail:
    ; emitRawByte failed: A/C already hold its diagnostic. Discard the
    ; stacked byte without disturbing A.
    tax
    pla
    txa
    sec
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
    lda CasmIoLenLo
    ldx CasmIoLenHi
    jsr progressAccumulateOutputBytes
    lda #0
    sta CasmEmitLen
    clc
    rts
efFail:
    rts
