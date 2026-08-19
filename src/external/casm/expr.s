; src/external/casm/expr.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Bounded Phase 5 expression storage, numeric conversion, addend parsing, and
; checked arithmetic. Primary dispatch, resolution, and extraction begin in
; later work packages.

.include "common.inc"

.import lexerNext
.import CasmTokenRecord
.import CasmTokenText
.import diagSetLocFromToken
.import CasmPc

.export exprInit
.export exprGetResult
.export exprParseNumeric
.export exprParseAddend
.export exprCheckedAdd
.export exprCheckedSub
.export exprApplyAddend
.export exprEvaluate

.segment "CODE"

; ---------------------------------------------------------------------------
; exprInit
; Reset the private expression record to its empty, unresolved defaults.
;
; Inputs:    none
; Outputs:   A = 0, Z set, N clear; expression record cleared
; Preserves: X, Y, C, V, D, I, zero page, balanced stack
; Clobbers:  A, N, Z
; Scratch:   none
; ---------------------------------------------------------------------------
.proc exprInit
    lda #0
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
    sta CasmExprResultRecord + CASM_EXPR_EXTRACTION
    sta CasmExprResultRecord + CASM_EXPR_SYMBOL_ID_LO
    sta CasmExprResultRecord + CASM_EXPR_SYMBOL_ID_HI
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_SIGN
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_LO
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_HI
    ; WP67: defensive reset -- every parsePrimary `group` exit path already
    ; balances its own inc/dec, so this is redundant insurance, not a
    ; correctness dependency, matching this project's own determinism
    ; convention (e.g. ppsConstant's top-of-routine zeroing).
    sta CasmExprParenDepth
    sta CasmExprMinPrec
    rts
.endproc

; ---------------------------------------------------------------------------
; exprEvaluate
; Evaluate one Phase 5 expression through a caller-supplied symbol resolver.
;
; Inputs:    current token begins expression; X/Y = resolver address;
;            A = relocatable-mode flag (0 = not relocatable, nonzero =
;            relocatable; WP39 -- the caller's whole-assembly mode, not a
;            per-symbol property, so a resolved identifier's classification
;            depends on this input rather than anything the resolver itself
;            reports); D clear
; Outputs:   success: result record valid, first following token current, C clear
;            failure: A = stable diagnostic, result invalid, C set
; Preserves: V, D, I, zero page, balanced stack, parser/emitter/resources
; Clobbers:  A, X, Y, N, Z, C, lexer state, expression and private scratch BSS
; Resolver:  current token is IDENTIFIER; X/Y point to five-byte output view;
;            C clear accepts output, C set is reported as resolver failure
; WP66:      grammar is now ['<'|'>'] (NUMBER|IDENTIFIER|'*') [('+'|'-')
;            NUMBER] -- '*' (current address, CasmPc) never reaches the
;            resolver; it is resolved on the spot and follows the
;            identifier path's own addend/extraction handling.
; ---------------------------------------------------------------------------
.proc exprEvaluate
    sta CasmExprRelocatableModeIn
    stx CasmExprResolverAddrLo
    sty CasmExprResolverAddrHi
    jsr exprInit

    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_LESS
    beq lowPrefix
    cmp #CASM_TOKEN_GREATER
    bne noExtraction
    lda #CASM_EXTRACTION_HI
    bne storeExtraction
lowPrefix:
    lda #CASM_EXTRACTION_LO
storeExtraction:
    sta CasmExprResultRecord + CASM_EXPR_EXTRACTION
    jsr lexerNext
    bcs return
noExtraction:

    ; WP67: primary dispatch and the +/- operator loop are now standalone
    ; procs (parsePrimary/parseOperatorTail below) so a parenthesized
    ; sub-expression can recurse into them -- see parsePrimary's own
    ; `group` arm. Extraction stays a whole-expression, top-level-only
    ; concept, applied once here after the full operator loop returns,
    ; exactly as before; nested calls never see or touch it.
    jsr parsePrimary
    bcs return
    lda #CASM_EXPR_PREC_LOWEST
    jsr parseOperatorTail
    bcs return
    jsr rejectContinuation
    bcs return

applyExtraction:
    lda CasmExprResultRecord + CASM_EXPR_EXTRACTION
    beq success
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    beq classifyExtraction
    lda CasmExprResultRecord + CASM_EXPR_EXTRACTION
    cmp #CASM_EXTRACTION_LO
    beq clearHigh
    lda CasmExprResultRecord + CASM_EXPR_VAL_HI
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
clearHigh:
    lda #0
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
classifyExtraction:
    lda CasmExprResultRecord + CASM_EXPR_EXTRACTION
    cmp #CASM_EXTRACTION_LO
    bne success
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #($FF - CASM_EXPR_FLAG_RELOCATABLE)
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
success:
    clc
return:
    rts
.endproc

; ---------------------------------------------------------------------------
; parsePrimary (WP67, private)
; Parse one primary: NUMBER, IDENTIFIER, '*' (current address), or a
; parenthesized sub-expression -- '(' recurses into parsePrimary +
; parseOperatorTail for the group's own content, then requires ')'.
; Reused three ways: exprEvaluate's own top-level primary, a parenthesized
; group's inner content, and (indirectly, via parseOperatorTail) the RHS
; of every '+'/'-' application -- WP67 lifts the pre-WP67 restriction that
; only IDENTIFIER/'*' primaries could take a trailing addend (user-
; confirmed 2026-08-14): NUMBER now reaches the same shared operator loop
; as everything else, so `1+1`/`2+3` (bare or inside parens) succeed
; instead of CASM_DIAG_EXPR_UNSUPPORTED.
;
; A leading '(' can only reach this proc from a RECURSIVE call (via
; parseOperatorTail's RHS parse, or nested inside another group) -- when
; called as exprEvaluate's own outermost primary, parser.s's own operand
; dispatch has already exclusively claimed a leading '(' for 6502 indirect
; addressing before exprEvaluate ever runs (WP64's frozen Parenthesization
; Rule), so this arm is structurally unreachable at that position in
; today's only call chain; it stays here as the single source of truth
; for '(' handling wherever it IS reachable, rather than being duplicated.
;
; Inputs:    current token begins a primary; CasmExprResolverAddrLo/Hi and
;            CasmExprRelocatableModeIn already staged (exprEvaluate's own
;            entry); D clear
; Outputs:   success: CasmExprResultRecord's VAL_LO/HI, FLAGS, SYMBOL_ID_LO/HI
;            populated (EXTRACTION/ADDEND untouched -- exclusively owned by
;            exprEvaluate and parseOperatorTail respectively); following
;            token current; C clear
;            failure: A = stable diagnostic, C set
; Preserves: V, D, I, zero page (except CasmPtr0, transient), balanced stack
; Clobbers:  A, X, Y, N, Z, C, lexer state, CasmExprResultRecord's VAL/
;            FLAGS/SYMBOL_ID fields, CasmExprParenDepth (net zero on return)
; ---------------------------------------------------------------------------
.proc parsePrimary
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_MINUS
    beq unary
    cmp #CASM_TOKEN_TILDE
    beq unary
    cmp #CASM_TOKEN_NUMBER
    bne primaryNotNumber
    jmp number
primaryNotNumber:
    cmp #CASM_TOKEN_IDENTIFIER
    bne primaryNotIdentifier
    jmp identifier
primaryNotIdentifier:
    cmp #CASM_TOKEN_STAR
    beq curAddr
    cmp #CASM_TOKEN_LPAREN
    bne notGroup
    jmp group
notGroup:
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_MALFORMED
    sec
return:
    rts

; WP68: unary '-'/'~' recurse through parsePrimary so chains bind
; right-to-left and tighter than every binary tier. The operator token is
; kept on the hardware stack across lexer/RHS parsing; every exit balances it.
unary:
    pha
    jsr lexerNext
    bcc unaryTokenOk
    tax
    pla
    txa
    rts
unaryTokenOk:
    jsr parsePrimary
    bcc unaryPrimaryOk
    tax
    pla
    txa
    rts
unaryPrimaryOk:
    pla
    sta CasmExprOpToken
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #CASM_EXPR_FLAG_RELOCATABLE
    beq unaryNotReloc
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_RELOC_UNSUPPORTED
    sec
    rts
unaryNotReloc:
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    beq unarySuccess
    lda CasmExprOpToken
    cmp #CASM_TOKEN_TILDE
    beq unaryComplement
    lda CasmExprResultRecord + CASM_EXPR_VAL_LO
    eor #$FF
    clc
    adc #1
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
    lda CasmExprResultRecord + CASM_EXPR_VAL_HI
    eor #$FF
    adc #0
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
    jmp unarySuccess
unaryComplement:
    lda CasmExprResultRecord + CASM_EXPR_VAL_LO
    eor #$FF
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
    lda CasmExprResultRecord + CASM_EXPR_VAL_HI
    eor #$FF
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
unarySuccess:
    clc
    rts

; WP66: current-address symbol ('*'). Always known immediately (no
; forward-reference case exists for it, unlike an identifier), so it is
; resolved on the spot from CasmPc.
;
; SYMBOL_DERIVED is set unconditionally (not just RESOLVED) even though
; '*' never goes through the resolver callback: parserParseExpressionValue
; derives CASM_PARSER_STMT_FORCE_ABS strictly from SYMBOL_DERIVED, and
; '*'s value is exactly as load-address-sensitive as a label's, so it
; needs the same Pass 1/Pass 2 width-agreement protection.
curAddr:
    lda CasmPc
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
    lda CasmPc + 1
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
    lda #(CASM_EXPR_FLAG_RESOLVED | CASM_EXPR_FLAG_SYMBOL_DERIVED)
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
    ldy CasmExprRelocatableModeIn
    beq curAddrNotReloc
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    ora #CASM_EXPR_FLAG_RELOCATABLE
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
curAddrNotReloc:
    jmp lexerNextTail

number:
    jsr exprParseNumeric
    bcc numberOk
    rts
numberOk:
    stx CasmExprResultRecord + CASM_EXPR_VAL_LO
    sty CasmExprResultRecord + CASM_EXPR_VAL_HI
    lda #CASM_EXPR_FLAG_RESOLVED
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
    jmp lexerNextTail

identifier:
    ; WP28: stage the resolver's name-pointer/length arguments. This is the
    ; only point with reliable access to them: the current token is still
    ; IDENTIFIER here (the tail's own lexerNext, which would overwrite
    ; CasmTokenText, has not run yet).
    lda #<CasmTokenText
    sta CasmPtr0Lo
    lda #>CasmTokenText
    sta CasmPtr0Hi
    ldx #<CasmExprResolverOutput
    ldy #>CasmExprResolverOutput
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    jsr callResolver
    bcc resolverReturned
    jmp resolverFailed
resolverReturned:
    lda CasmExprResolverOutput + CASM_RESOLVE_FLAGS
    and #($FF - CASM_RESOLVE_FLAG_MASK)
    beq resolverValid
    jmp resolverFailed
resolverValid:

    ldx CasmExprResolverOutput + CASM_RESOLVE_ID_LO
    stx CasmExprResultRecord + CASM_EXPR_SYMBOL_ID_LO
    ldy CasmExprResolverOutput + CASM_RESOLVE_ID_HI
    sty CasmExprResultRecord + CASM_EXPR_SYMBOL_ID_HI
    lda CasmExprResolverOutput + CASM_RESOLVE_FLAGS
    ora #CASM_EXPR_FLAG_SYMBOL_DERIVED
    sta CasmExprResultRecord + CASM_EXPR_FLAGS

    ; WP39: apply the caller's whole-assembly relocatable-mode input
    ; unconditionally alongside SYMBOL_DERIVED, not gated on RESOLVED below
    ; -- an unresolved Pass 1 forward reference and its resolved Pass 2
    ; counterpart must classify identically, mirroring FORCE_ABS's own
    ; SYMBOL_DERIVED-not-RESOLVED precedent (parser.s).
    ;
    ; WP65: unlike a label (CASM_RESOLVE_SYM_FLAGS' CONSTANT bit clear),
    ; unconditionally eligible exactly as before, a *resolved* named
    ; constant is relocatable only when its own reference chain bottoms
    ; out at a label (CASM_SYMBOL_FLAG_LABEL_DERIVED) -- a pure numeric
    ; constant's value never depends on load address regardless of mode.
    ; An *unresolved* constant is only reachable during Pass 1, before
    ; casmResolveConstants (casm.s) has run -- Pass 2 never sees one, since
    ; every constant is fully resolved before Pass 2 begins -- and takes
    ; the unconditional label-shaped path below unchanged: harmless, since
    ; Pass 1 never acts on RELOCATABLE (only on FORCE_ABS, already
    ; unconditional above).
    ; A miss leaves CASM_RESOLVE_SYM_FLAGS unspecified by resolver contract.
    ; Treat unresolved identifiers as label-shaped before inspecting it, or a
    ; preceding constant lookup can leak stale kind flags into this result.
    lda CasmExprResolverOutput + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    beq evApplyMode
    lda CasmExprResolverOutput + CASM_RESOLVE_SYM_FLAGS
    and #CASM_SYMBOL_FLAG_CONSTANT
    beq evApplyMode
    lda CasmExprResolverOutput + CASM_RESOLVE_SYM_FLAGS
    and #CASM_SYMBOL_FLAG_RESOLVED
    beq evApplyMode
    lda CasmExprResolverOutput + CASM_RESOLVE_SYM_FLAGS
    and #CASM_SYMBOL_FLAG_LABEL_DERIVED
    bne evApplyMode
    ; WP72: a resolved, non-label-derived constant's value can never differ
    ; between Pass 1 and Pass 2 (casmResolveConstants, casm.s, fully resolves
    ; every such constant before either pass ever evaluates an instruction
    ; operand naming it -- see this proc's own WP65 comment above), unlike a
    ; label or the current-address symbol, whose SYMBOL_DERIVED must stay set
    ; unconditionally so parserParseExpressionValue's FORCE_ABS derivation
    ; (parser.s) can never disagree in width between passes. Clearing
    ; SYMBOL_DERIVED here lets such a constant fall through to the same
    ; value-based zero-page/absolute selection in opcodes.s that a bare
    ; numeric literal already gets -- fixing STA SYMBOL (SYMBOL = $70)
    ; wrongly assembling as 3-byte absolute instead of 2-byte zero-page.
    ; The binary-operator RHS-propagation sites below (combineFlags/
    ; staticFlags) need no matching change: they only OR in whatever
    ; SYMBOL_DERIVED state an operand already carries, so a compound
    ; expression like SYMBOL+1 correctly inherits this same clear bit.
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #($FF - CASM_EXPR_FLAG_SYMBOL_DERIVED)
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
    jmp evNotRelocatable             ; resolved, non-label-derived constant
evApplyMode:
    ldy CasmExprRelocatableModeIn
    beq evNotRelocatable
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    ora #CASM_EXPR_FLAG_RELOCATABLE
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
evNotRelocatable:
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    beq idUnresolved
    lda CasmExprResolverOutput + CASM_RESOLVE_VAL_LO
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
    lda CasmExprResolverOutput + CASM_RESOLVE_VAL_HI
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
    bne lexerNextTail
idUnresolved:
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    ora #CASM_EXPR_FLAG_FORCE_ABS
    sta CasmExprResultRecord + CASM_EXPR_FLAGS

lexerNextTail:
    jsr lexerNext
    rts

resolverFailed:
    jsr diagSetLocFromToken
    lda #CASM_DIAG_RESOLVER_FAILED
    sec
    rts

; WP67: parenthesized sub-expression. Depth-bounded (CASM_EXPR_PAREN_MAX_
; DEPTH) since every level costs at least one JSR against the 6502's small
; hardware stack, shared with every other nested call in the assembler.
group:
    inc CasmExprParenDepth
    lda CasmExprParenDepth
    cmp #CASM_EXPR_PAREN_MAX_DEPTH + 1
    bcc groupDepthOk
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_PAREN_TOO_DEEP
    sec
    dec CasmExprParenDepth
    rts
groupDepthOk:
    jsr lexerNext                 ; consume '(', fetch the group's own first token
    bcc groupOpened
    dec CasmExprParenDepth
    rts
groupOpened:
    jsr parsePrimary              ; recurse: the group's own leading primary
    bcc groupPrimaryOk
    dec CasmExprParenDepth
    rts
groupPrimaryOk:
    lda #CASM_EXPR_PREC_LOWEST
    jsr parseOperatorTail         ; recurse: the group's own +/- chain
    bcc groupTailOk
    dec CasmExprParenDepth
    rts
groupTailOk:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_RPAREN
    beq groupClose
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_MALFORMED
    sec
    dec CasmExprParenDepth
    rts
groupClose:
    dec CasmExprParenDepth
    jsr lexerNext                 ; consume ')'; C/A already correct either way
    rts
.endproc

; ---------------------------------------------------------------------------
; parseOperatorTail (WP67/WP68, private)
; Minimum-precedence, left-associative operator loop. WP68 Increment 3
; establishes the complete recursion contract while deliberately classifying
; only the already-shipped '+'/'-' tier: consume an operator whose precedence
; is at least A, parse one RHS primary, recursively consume only tighter RHS
; operators (current precedence + 1), then combine. Later increments populate
; the other frozen tiers without changing this control-flow shape.
;
; Since parsePrimary shares the same CasmExprResultRecord for whatever it
; is currently parsing, this proc saves the accumulator's VAL_LO/HI,
; FLAGS, and SYMBOL_ID_LO/HI (5 bytes -- EXTRACTION/ADDEND are exclusively
; top-level/this-proc's-own-output and never read back in, so they need
; no save) on the 6502 hardware stack before each recursive parsePrimary
; call for the RHS, and restores them after -- net zero stack growth per
; loop iteration (chained operators at the same level don't accumulate
; stack; only parsePrimary's own paren recursion does, separately bounded
; by CASM_EXPR_PAREN_MAX_DEPTH).
;
; Per WP64's frozen relocation representability rule, formalized here: an
; RHS whose own RELOCATABLE flag is set is rejected with
; CASM_DIAG_EXPR_RELOC_UNSUPPORTED if the accumulator is already
; RELOCATABLE too (two relocatable components can never collapse to one
; symbol + static addend); otherwise the RHS's RELOCATABLE/SYMBOL_DERIVED
; bits simply propagate into the accumulator.
;
; Inputs:    A = minimum accepted precedence; current token follows a
;            just-parsed primary; CasmExprResultRecord holds that primary's
;            value; D clear
; Outputs:   success: CasmExprResultRecord's VAL_LO/HI/FLAGS updated for
;            every '+'/'-' applied (zero or more); ADDEND_SIGN/MAG_LO/HI
;            hold the *last* applied operator's own sign and RHS value
;            (matches the pre-WP67 single-addend record exactly when
;            exactly one operator with a NUMBER RHS was applied); first
;            non-operator token current; C clear
;            failure: A = stable diagnostic, C set
; Preserves: V, D, I, zero page, balanced stack
; Clobbers:  A, X, Y, N, Z, C, lexer state, CasmExprResultRecord's VAL/
;            FLAGS/ADDEND fields, CasmExprMinPrec/OpToken/OpPrec/RhsValLo/RhsValHi/
;            RhsFlags
; ---------------------------------------------------------------------------
.proc parseOperatorTail
    tax
    lda CasmExprMinPrec
    pha
    stx CasmExprMinPrec
loop:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_PLUS
    beq classifyAdd
    cmp #CASM_TOKEN_MINUS
    beq classifyAdd
    cmp #CASM_TOKEN_PIPE
    beq classifyOr
    cmp #CASM_TOKEN_CARET
    beq classifyXor
    cmp #CASM_TOKEN_AMPERSAND
    beq classifyAnd
    cmp #CASM_TOKEN_SHL
    beq classifyShift
    cmp #CASM_TOKEN_SHR
    beq classifyShift
    cmp #CASM_TOKEN_STAR
    beq classifyMulDiv
    cmp #CASM_TOKEN_SLASH
    beq classifyMulDiv
    jmp done
classifyAdd:
    lda #CASM_EXPR_PREC_ADD
    bne classified
classifyOr:
    lda #CASM_EXPR_PREC_OR
    bne classified
classifyXor:
    lda #CASM_EXPR_PREC_XOR
    bne classified
classifyAnd:
    lda #CASM_EXPR_PREC_AND
    bne classified
classifyShift:
    lda #CASM_EXPR_PREC_SHIFT
    bne classified
classifyMulDiv:
    ; WP68 Increment 6 Atomic Step 3: '*' here is unambiguously infix --
    ; this loop only runs after a primary has already been parsed, so the
    ; primary-position current-address reading of CASM_TOKEN_STAR (see
    ; parsePrimary) never reaches this classifier.
    lda #CASM_EXPR_PREC_MULDIV
classified:
    sta CasmExprOpPrec
    cmp CasmExprMinPrec
    bcs applyOp
    jmp done
applyOp:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    pha                            ; stash operator token
    lda CasmExprOpPrec
    pha                            ; stash precedence across recursive RHS
    jsr lexerNext                  ; consume operator, fetch RHS first token
    bcc opTokenOk
    tax
    pla
    pla
    txa
    jmp failReturn
opTokenOk:
    lda CasmExprResultRecord + CASM_EXPR_VAL_LO
    pha
    lda CasmExprResultRecord + CASM_EXPR_VAL_HI
    pha
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    pha
    lda CasmExprResultRecord + CASM_EXPR_SYMBOL_ID_LO
    pha
    lda CasmExprResultRecord + CASM_EXPR_SYMBOL_ID_HI
    pha
    jsr parsePrimary                ; RHS -- overwrites CasmExprResultRecord
    bcc opRhsOk
    tax
    pla
    pla
    pla
    pla
    pla
    pla
    pla                              ; drop accumulator, precedence, and token
    txa
    jmp failReturn
opRhsOk:
    tsx
    lda $0106, x                    ; precedence below 5 saved accumulator bytes
    clc
    adc #1
    jsr parseOperatorTail
    bcc opRhsTailOk
    tax
    pla
    pla
    pla
    pla
    pla
    pla
    pla                              ; drop accumulator, precedence, and token
    txa
    jmp failReturn
opRhsTailOk:
    ; capture the RHS's own value/flags before the accumulator's saved
    ; bytes (about to be restored) overwrite the shared record.
    lda CasmExprResultRecord + CASM_EXPR_VAL_LO
    sta CasmExprRhsValLo
    lda CasmExprResultRecord + CASM_EXPR_VAL_HI
    sta CasmExprRhsValHi
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    sta CasmExprRhsFlags
    pla
    sta CasmExprResultRecord + CASM_EXPR_SYMBOL_ID_HI
    pla
    sta CasmExprResultRecord + CASM_EXPR_SYMBOL_ID_LO
    pla
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
    pla
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
    pla
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
    pla
    sta CasmExprOpPrec              ; discard saved precedence into scratch
    pla
    sta CasmExprOpToken

    lda CasmExprOpToken
    cmp #CASM_TOKEN_PLUS
    beq checkAddReloc
    cmp #CASM_TOKEN_MINUS
    bne checkStaticReloc
checkAddReloc:
    ; Existing +/- representability rule: at most one relocatable component.
    lda CasmExprRhsFlags
    and #CASM_EXPR_FLAG_RELOCATABLE
    bne checkAddLeftReloc
    jmp combineAddend
checkAddLeftReloc:
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #CASM_EXPR_FLAG_RELOCATABLE
    bne addRelocFail
    jmp combineAddend
addRelocFail:
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_RELOC_UNSUPPORTED
    sec
    jmp failReturn

checkStaticReloc:
    ; Every new WP68 operator is static-only: either relocatable operand is
    ; rejected, even when the other operand is static.
    lda CasmExprRhsFlags
    and #CASM_EXPR_FLAG_RELOCATABLE
    bne staticRelocFail
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #CASM_EXPR_FLAG_RELOCATABLE
    beq combineStatic
staticRelocFail:
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_RELOC_UNSUPPORTED
    sec
    jmp failReturn

combineStatic:
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne staticLeftResolved
    jmp staticUnresolved
staticLeftResolved:
    lda CasmExprRhsFlags
    and #CASM_EXPR_FLAG_RESOLVED
    bne staticBothResolved
    jmp staticUnresolved
staticBothResolved:
    lda CasmExprOpToken
    cmp #CASM_TOKEN_AMPERSAND
    beq staticAnd
    cmp #CASM_TOKEN_CARET
    beq staticXor
    cmp #CASM_TOKEN_SHL
    beq staticShift
    cmp #CASM_TOKEN_SHR
    beq staticShift
    cmp #CASM_TOKEN_STAR
    beq staticMul
    cmp #CASM_TOKEN_SLASH
    beq staticDiv
    ; CASM_TOKEN_PIPE
    lda CasmExprResultRecord + CASM_EXPR_VAL_LO
    ora CasmExprRhsValLo
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
    lda CasmExprResultRecord + CASM_EXPR_VAL_HI
    ora CasmExprRhsValHi
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
    jmp staticFlags
staticMul:
    ; WP68 Increment 6 Atomic Step 4: checked unsigned 16-bit multiply.
    ; Atomic Step 5's growth pushed staticFlags out of bcc's short-branch
    ; range; local bcs + absolute JMP trampolines keep both outcomes correct
    ; without relying on branch distance.
    jsr mulUnsigned16
    bcs staticMulOverflow
    jmp staticFlags
staticMulOverflow:
    jmp staticOverflow
staticDiv:
    ; WP68 Increment 6 Atomic Step 5: the divisor-zero check is
    ; unconditional and runs before any division arithmetic, matching the
    ; plan's algorithm ("check the divisor for zero before entering the
    ; loop"). A zero divisor raises the real, permanent
    ; CASM_DIAG_EXPR_DIV_ZERO diagnostic regardless of whether the bounded
    ; division loop exists yet.
    lda CasmExprRhsValLo
    ora CasmExprRhsValHi
    bne staticDivNonzero
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_DIV_ZERO
    sec
    jmp failReturn
staticDivNonzero:
    ; WP68 Increment 6 Atomic Step 6: bounded unsigned division. Always
    ; succeeds once reached -- the caller (staticDiv, above) already
    ; rejected a zero divisor, and divUnsigned16 has no other failure mode.
    jsr divUnsigned16
    jmp staticFlags
staticAnd:
    lda CasmExprResultRecord + CASM_EXPR_VAL_LO
    and CasmExprRhsValLo
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
    lda CasmExprResultRecord + CASM_EXPR_VAL_HI
    and CasmExprRhsValHi
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
    jmp staticFlags
staticXor:
    lda CasmExprResultRecord + CASM_EXPR_VAL_LO
    eor CasmExprRhsValLo
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
    lda CasmExprResultRecord + CASM_EXPR_VAL_HI
    eor CasmExprRhsValHi
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
    jmp staticFlags
staticShift:
    ; Counts are unsigned 16-bit values but only 0..15 are valid.
    lda CasmExprRhsValHi
    bne staticOverflow
    lda CasmExprRhsValLo
    cmp #16
    bcs staticOverflow
    tax
    beq staticFlags
    lda CasmExprOpToken
    cmp #CASM_TOKEN_SHR
    beq staticShiftRight
staticShiftLeftLoop:
    asl CasmExprResultRecord + CASM_EXPR_VAL_LO
    rol CasmExprResultRecord + CASM_EXPR_VAL_HI
    bcs staticOverflow
    dex
    bne staticShiftLeftLoop
    jmp staticFlags
staticShiftRight:
    lsr CasmExprResultRecord + CASM_EXPR_VAL_HI
    ror CasmExprResultRecord + CASM_EXPR_VAL_LO
    dex
    bne staticShiftRight
    jmp staticFlags
staticOverflow:
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_OVERFLOW
    sec
    jmp failReturn
staticUnresolved:
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #(255 - CASM_EXPR_FLAG_RESOLVED)
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
staticFlags:
    lda CasmExprRhsFlags
    and #CASM_EXPR_FLAG_SYMBOL_DERIVED
    ora CasmExprResultRecord + CASM_EXPR_FLAGS
    and #(255 - CASM_EXPR_FLAG_RELOCATABLE)
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
    jmp loop

combineAddend:
    lda #CASM_ADDEND_SIGN_POSITIVE
    ldx CasmExprOpToken
    cpx #CASM_TOKEN_MINUS
    bne storeAddendSign
    lda #CASM_ADDEND_SIGN_NEGATIVE
storeAddendSign:
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_SIGN
    lda CasmExprRhsValLo
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_LO
    lda CasmExprRhsValHi
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_HI

    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    beq notBothResolved
    lda CasmExprRhsFlags
    and #CASM_EXPR_FLAG_RESOLVED
    beq notBothResolved
    ldx CasmExprResultRecord + CASM_EXPR_VAL_LO
    ldy CasmExprResultRecord + CASM_EXPR_VAL_HI
    jsr exprApplyAddend
    bcc applied
    jmp failReturn
applied:
    stx CasmExprResultRecord + CASM_EXPR_VAL_LO
    sty CasmExprResultRecord + CASM_EXPR_VAL_HI
    jmp combineFlags
notBothResolved:
    lda CasmExprResultRecord + CASM_EXPR_FLAGS
    and #(255 - CASM_EXPR_FLAG_RESOLVED)
    sta CasmExprResultRecord + CASM_EXPR_FLAGS
combineFlags:
    lda CasmExprRhsFlags
    and #(CASM_EXPR_FLAG_SYMBOL_DERIVED | CASM_EXPR_FLAG_RELOCATABLE)
    ora CasmExprResultRecord + CASM_EXPR_FLAGS
    sta CasmExprResultRecord + CASM_EXPR_FLAGS

    ; No lexerNext here: parsePrimary (the RHS parse above) already
    ; advanced past its own token internally (its own lexerNextTail) --
    ; unlike exprParseAddend/exprParseNumeric's older "leaves the token
    ; current" contract this loop's own predecessor relied on. The
    ; current token is already correctly positioned for the next
    ; iteration's own check.
    jmp loop
done:
    pla
    sta CasmExprMinPrec
    clc
    rts
failReturn:
    tax
    pla
    sta CasmExprMinPrec
    txa
    sec
    rts
.endproc

; Reject only tokens that unambiguously continue the bounded expression. Other
; punctuation remains current for the future parser adapter.
.proc rejectContinuation
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_PLUS
    beq unsupported
    cmp #CASM_TOKEN_MINUS
    beq unsupported
    cmp #CASM_TOKEN_LESS
    beq unsupported
    cmp #CASM_TOKEN_GREATER
    beq unsupported
    cmp #CASM_TOKEN_NUMBER
    beq unsupported
    cmp #CASM_TOKEN_IDENTIFIER
    beq unsupported
    cmp #CASM_TOKEN_STAR
    beq unsupported
    cmp #CASM_TOKEN_SLASH
    beq unsupported
    cmp #CASM_TOKEN_AMPERSAND
    beq unsupported
    cmp #CASM_TOKEN_CARET
    beq unsupported
    cmp #CASM_TOKEN_PIPE
    beq unsupported
    cmp #CASM_TOKEN_TILDE
    beq unsupported
    cmp #CASM_TOKEN_SHL
    beq unsupported
    cmp #CASM_TOKEN_SHR
    beq unsupported
    clc
    rts
unsupported:
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_UNSUPPORTED
    sec
    rts
.endproc

; 6502 has no indirect JSR. Push the synthetic return address in JSR order,
; then transfer through the callback pointer; resolver RTS returns at resume.
;
; WP28: A must survive this preamble -- the caller (exprEvaluate's identifier
; branch) sets A to the resolver's nameLen argument immediately before this
; call, but the return-address push below clobbers A twice before the actual
; indirect jump. Stash it in CasmExprScratch0 (private to this module, not
; live across any other call in this window) and restore it immediately
; before the jump, so the resolver receives the caller's A unchanged. X/Y
; need no such handling: this routine never touches them.
.proc callResolver
    sta CasmExprScratch0
    lda #>(resume - 1)
    pha
    lda #<(resume - 1)
    pha
    lda CasmExprScratch0
    jmp (CasmExprResolverAddrLo)
resume:
    rts
.endproc

; ---------------------------------------------------------------------------
; exprGetResult
; Return a stable pointer to the private expression result record.
;
; Inputs:    none
; Outputs:   X/Y = record address low/high; C clear; N/Z reflect Y
; Preserves: A, V, D, I, zero page, balanced stack
; Clobbers:  X, Y, N, Z, C
; Scratch:   none
; ---------------------------------------------------------------------------
.proc exprGetResult
    ldx #<CasmExprResultRecord
    ldy #>CasmExprResultRecord
    clc
    rts
.endproc

; ---------------------------------------------------------------------------
; exprParseNumeric
; Convert the current NUMBER token to an unsigned 16-bit value.
;
; Inputs:    current token is NUMBER; D clear (CASM application invariant)
; Outputs:   success: X/Y = value low/high, C clear, token remains current
;            failure: A = CASM_DIAG_OPERAND_OUT_OF_RANGE, C set, token location
; Preserves: V, D, I, balanced stack, lexer state, expression result record
; Clobbers:  A, X, Y, N, Z, C, private numeric scratch
; ---------------------------------------------------------------------------
.proc exprParseNumeric
    lda #0
    sta CasmExprValueLo
    sta CasmExprValueHi
    sta CasmExprValueExt
    sta CasmExprOverflow

    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    cmp #CASM_NUMBER_DECIMAL
    beq decimalStart
    cmp #CASM_NUMBER_HEX
    beq hexStart
    ldy #1
    jmp binaryLoop
hexStart:
    ldy #1
    jmp hexLoop
decimalStart:
    ldy #0

decimalLoop:
    cpy CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    beq done
    lda CasmTokenText, y
    sec
    sbc #CASM_PETSCII_DIGIT_0
    tax
    jsr multiply10
    jsr addDigit
    iny
    jmp decimalLoop

hexLoop:
    cpy CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    beq done
    lda CasmTokenText, y
    jsr hexDigitValue
    jsr multiply16
    jsr addDigit
    iny
    jmp hexLoop

binaryLoop:
    cpy CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    beq done
    lda CasmTokenText, y
    sec
    sbc #CASM_PETSCII_DIGIT_0
    tax
    jsr multiply2
    jsr addDigit
    iny
    jmp binaryLoop

done:
    lda CasmExprOverflow
    beq success
    jsr diagSetLocFromToken
    lda #CASM_DIAG_OPERAND_OUT_OF_RANGE
    sec
    rts
success:
    ldx CasmExprValueLo
    ldy CasmExprValueHi
    clc
    rts
.endproc

; A = PETSCII hex digit; returns X = 0..15.
.proc hexDigitValue
    cmp #CASM_PETSCII_DIGIT_0
    bcc letter
    cmp #CASM_PETSCII_DIGIT_9 + 1
    bcs letter
    sec
    sbc #CASM_PETSCII_DIGIT_0
    tax
    rts
letter:
    cmp #CASM_PETSCII_SHIFTED_A
    bcc normalized
    cmp #CASM_PETSCII_SHIFTED_Z + 1
    bcs normalized
    and #$7F
normalized:
    sec
    sbc #CASM_PETSCII_UPPER_A
    clc
    adc #10
    tax
    rts
.endproc

; Private 24-bit arithmetic keeps overflow sticky after the first high byte.
.proc multiply2
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    lda CasmExprValueExt
    beq return
    lda #1
    sta CasmExprOverflow
return:
    rts
.endproc

.proc multiply16
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    lda CasmExprValueExt
    beq return
    lda #1
    sta CasmExprOverflow
return:
    rts
.endproc

.proc multiply10
    lda CasmExprValueLo
    sta CasmExprTempLo
    lda CasmExprValueHi
    sta CasmExprTempHi
    lda CasmExprValueExt
    sta CasmExprTempExt

    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt
    asl CasmExprValueLo
    rol CasmExprValueHi
    rol CasmExprValueExt

    asl CasmExprTempLo
    rol CasmExprTempHi
    rol CasmExprTempExt

    ; Keep this chain explicit: loop control would destroy inter-byte carry.
    clc
    lda CasmExprValueLo
    adc CasmExprTempLo
    sta CasmExprValueLo
    lda CasmExprValueHi
    adc CasmExprTempHi
    sta CasmExprValueHi
    lda CasmExprValueExt
    adc CasmExprTempExt
    sta CasmExprValueExt

    lda CasmExprValueExt
    beq return
    lda #1
    sta CasmExprOverflow
return:
    rts
.endproc

.proc addDigit
    clc
    txa
    adc CasmExprValueLo
    sta CasmExprValueLo
    lda CasmExprValueHi
    adc #0
    sta CasmExprValueHi
    lda CasmExprValueExt
    adc #0
    sta CasmExprValueExt
    beq return
    lda #1
    sta CasmExprOverflow
return:
    rts
.endproc

; ---------------------------------------------------------------------------
; exprParseAddend
; Parse optional +number/-number metadata. A parsed NUMBER remains current.
;
; Inputs:    current token follows primary; result record initialized; D clear
; Outputs:   success: sign/magnitude stored, C clear
;            failure: A = stable diagnostic, C set, result invalid
; Preserves: V, D, I, balanced stack
; Clobbers:  A, X, Y, N, Z, C, lexer state when operator present, numeric scratch
; ---------------------------------------------------------------------------
.proc exprParseAddend
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_PLUS
    beq positive
    cmp #CASM_TOKEN_MINUS
    beq negative

    lda #CASM_ADDEND_SIGN_POSITIVE
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_SIGN
    lda #0
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_LO
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_HI
    clc
    rts

positive:
    lda #CASM_ADDEND_SIGN_POSITIVE
    jmp storeSign
negative:
    lda #CASM_ADDEND_SIGN_NEGATIVE
storeSign:
    sta CasmExprResultRecord + CASM_EXPR_ADDEND_SIGN
    jsr lexerNext
    bcs return
    cmp #CASM_TOKEN_NUMBER
    beq parseMagnitude
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_MALFORMED
    sec
    rts
parseMagnitude:
    jsr exprParseNumeric
    bcs return
    stx CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_LO
    sty CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_HI
    clc
return:
    rts
.endproc

; ---------------------------------------------------------------------------
; exprCheckedAdd / exprCheckedSub
; Apply the result record's unsigned magnitude to X/Y without wraparound.
; Input precondition: D clear (CASM application invariant).
; Success returns adjusted X/Y and C clear. Failure returns A = $26, C set;
; X/Y are unspecified. Result record and lexer state are preserved.
; ---------------------------------------------------------------------------
.proc exprCheckedAdd
    txa
    clc
    adc CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_LO
    tax
    tya
    adc CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_HI
    tay
    bcs overflow
    clc
    rts
overflow:
    lda #CASM_DIAG_EXPR_OVERFLOW
    sec
    rts
.endproc

.proc exprCheckedSub
    txa
    sec
    sbc CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_LO
    tax
    tya
    sbc CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_HI
    tay
    bcc underflow
    clc
    rts
underflow:
    lda #CASM_DIAG_EXPR_OVERFLOW
    sec
    rts
.endproc

; ---------------------------------------------------------------------------
; exprApplyAddend
; Dispatch checked arithmetic by sign and stamp the current magnitude token on
; overflow. Zero magnitude is a no-op for either sign. D must be clear.
; ---------------------------------------------------------------------------
.proc exprApplyAddend
    lda CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_LO
    ora CasmExprResultRecord + CASM_EXPR_ADDEND_MAG_HI
    beq success
    lda CasmExprResultRecord + CASM_EXPR_ADDEND_SIGN
    cmp #CASM_ADDEND_SIGN_POSITIVE
    beq add
    jsr exprCheckedSub
    bcc success
    jmp failed
add:
    jsr exprCheckedAdd
    bcc success
failed:
    jsr diagSetLocFromToken
    lda #CASM_DIAG_EXPR_OVERFLOW
    sec
    rts
success:
    clc
    rts
.endproc

; ---------------------------------------------------------------------------
; mulUnsigned16 (WP68 Increment 6 Atomic Step 4, private)
; Bounded unsigned 16x16->16 shift/add multiply with overflow detection.
; Standard right-shift-multiplier/left-shift-multiplicand algorithm, capped
; at 16 iterations with an early exit once the multiplier reaches zero.
; Checking multiplier-zero before shifting the multiplicand is load-bearing:
; it avoids a false overflow on the multiplicand's own final left shift for
; valid products such as $8000*1, where that shift is never needed and its
; leading bit is irrelevant to the (already complete) result.
;
; Inputs:    CasmExprResultRecord VAL_LO/HI = left operand (multiplicand);
;            CasmExprRhsValLo/Hi = right operand (multiplier); D clear
; Outputs:   success: CasmExprResultRecord VAL_LO/HI = 16-bit product; C clear
;            failure: C set (product would exceed $FFFF); ResultRecord
;            VAL_LO/HI unchanged (caller must not commit a partial product)
; Preserves: V, D, I, zero page, balanced stack, CasmExprResultRecord on
;            failure
; Clobbers:  A, X, N, Z, C, CasmExprMulcandLo/Hi, CasmExprMulplierLo/Hi,
;            CasmExprProductLo/Hi
; ---------------------------------------------------------------------------
.proc mulUnsigned16
    lda CasmExprResultRecord + CASM_EXPR_VAL_LO
    sta CasmExprMulcandLo
    lda CasmExprResultRecord + CASM_EXPR_VAL_HI
    sta CasmExprMulcandHi
    lda CasmExprRhsValLo
    sta CasmExprMulplierLo
    lda CasmExprRhsValHi
    sta CasmExprMulplierHi
    lda #0
    sta CasmExprProductLo
    sta CasmExprProductHi

    ldx #16
loop:
    lsr CasmExprMulplierHi
    ror CasmExprMulplierLo         ; carry out = multiplier's own bit 0
    bcc noAdd
    clc
    lda CasmExprProductLo
    adc CasmExprMulcandLo
    sta CasmExprProductLo
    lda CasmExprProductHi
    adc CasmExprMulcandHi
    sta CasmExprProductHi
    bcs overflow
noAdd:
    lda CasmExprMulplierLo
    ora CasmExprMulplierHi
    beq done                       ; no remaining multiplier bits -- early out
    asl CasmExprMulcandLo
    rol CasmExprMulcandHi
    bcs overflow
    dex
    bne loop
done:
    lda CasmExprProductLo
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
    lda CasmExprProductHi
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
    clc
    rts
overflow:
    sec
    rts
.endproc

; ---------------------------------------------------------------------------
; divUnsigned16 (WP68 Increment 6 Atomic Step 6, private)
; Bounded unsigned 16/16->16 restoring binary long division. Returns the
; truncated quotient only; the remainder is private scratch and is discarded.
; Always succeeds when reached -- the caller (staticDiv) already rejected a
; zero divisor before calling this, so there is no failure path here.
;
; Standard technique: each of the 16 iterations shifts the dividend/quotient
; pair and the (17-bit-capable) remainder left together as one wide rotate
; (quotient low -> quotient high -> remainder low -> remainder high ->
; remainder extension bit), most significant dividend bit first. The 17-bit
; remainder (extension:high:low) is then compared against the 16-bit
; divisor; if it is not smaller, the divisor is subtracted and the vacated
; quotient bit 0 (just shifted in as 0) is set to 1.
;
; Inputs:    CasmExprResultRecord VAL_LO/HI = dividend; CasmExprRhsValLo/Hi =
;            nonzero divisor; D clear
; Outputs:   CasmExprResultRecord VAL_LO/HI = truncated unsigned quotient
; Preserves: V, D, I, zero page, balanced stack
; Clobbers:  A, X, N, Z, C, CasmExprDivisorLo/Hi, CasmExprQuotientLo/Hi,
;            CasmExprRemainderLo/Hi, CasmExprRemainderExt
; ---------------------------------------------------------------------------
.proc divUnsigned16
    lda CasmExprResultRecord + CASM_EXPR_VAL_LO
    sta CasmExprQuotientLo         ; initially the dividend
    lda CasmExprResultRecord + CASM_EXPR_VAL_HI
    sta CasmExprQuotientHi
    lda CasmExprRhsValLo
    sta CasmExprDivisorLo
    lda CasmExprRhsValHi
    sta CasmExprDivisorHi
    lda #0
    sta CasmExprRemainderLo
    sta CasmExprRemainderHi
    sta CasmExprRemainderExt

    ldx #16
loop:
    asl CasmExprQuotientLo
    rol CasmExprQuotientHi
    rol CasmExprRemainderLo
    rol CasmExprRemainderHi
    rol CasmExprRemainderExt

    lda CasmExprRemainderExt
    bne doSub                      ; 17th bit set -- remainder > any 16-bit divisor
    lda CasmExprRemainderHi
    cmp CasmExprDivisorHi
    bcc noSub
    bne doSub
    lda CasmExprRemainderLo
    cmp CasmExprDivisorLo
    bcc noSub
doSub:
    sec
    lda CasmExprRemainderLo
    sbc CasmExprDivisorLo
    sta CasmExprRemainderLo
    lda CasmExprRemainderHi
    sbc CasmExprDivisorHi
    sta CasmExprRemainderHi
    lda CasmExprRemainderExt
    sbc #0
    sta CasmExprRemainderExt
    lda CasmExprQuotientLo
    ora #1                         ; set the freshly shifted-in quotient bit 0
    sta CasmExprQuotientLo
noSub:
    dex
    bne loop

    lda CasmExprQuotientLo
    sta CasmExprResultRecord + CASM_EXPR_VAL_LO
    lda CasmExprQuotientHi
    sta CasmExprResultRecord + CASM_EXPR_VAL_HI
    clc
    rts
.endproc

.segment "BSS"

CasmExprResultRecord:
    .res CASM_EXPR_REC_SIZE
CasmExprResultRecordEnd:

; Private 24-bit numeric accumulator and temporary workspace.
CasmExprValueLo:  .res 1
CasmExprValueHi:  .res 1
CasmExprValueExt: .res 1
CasmExprOverflow: .res 1
CasmExprTempLo:   .res 1
CasmExprTempHi:   .res 1
CasmExprTempExt:  .res 1
; Pad bytes: WP46's lexerFill fix grew CODE (source.s/lexer.s), which
; shifts the whole BSS segment's own start address in MAIN -- and that
; pushed CasmExprResolverAddrLo's low byte onto exactly the $FF the
; .assert below exists to catch. Padding here (this symbol's own file, so
; it directly controls its offset within expr.o's own BSS layout) is the
; targeted fix; padding in some other module's BSS block would not have
; worked, since expr.o links before source.o/state.o and its own BSS
; offset is fixed by everything before *it*, not after. WP54's listing.s
; fix grew CODE again and retripped the same assert for
; TEST_CASM_PASSCHECK specifically; re-tuned from 1 to 2 bytes.
CasmExprResolverAddrPad: .res 2
CasmExprResolverAddrLo: .res 1
CasmExprResolverAddrHi: .res 1
CasmExprResolverOutput: .res CASM_RESOLVE_SIZE

; WP39: the incoming A (relocatable-mode flag) stashed before exprInit
; clobbers A. Private -- expr.s stays fully decoupled from emit.s; the
; caller (parser.s) reads CasmRelocatableMode itself and passes it in here.
CasmExprRelocatableModeIn: .res 1

; WP67: parsePrimary's own parenthesized-group nesting counter (0 at the
; top; bounded by CASM_EXPR_PAREN_MAX_DEPTH). parseOperatorTail's own
; scratch for combining one RHS primary into the running accumulator --
; transient per operator application, never needs saving across a nested
; call (parsePrimary's own save/restore of the accumulator's 5 bytes uses
; the hardware stack directly, not these).
CasmExprParenDepth: .res 1
CasmExprMinPrec:    .res 1
CasmExprOpToken:    .res 1
CasmExprOpPrec:     .res 1
CasmExprRhsValLo:   .res 1
CasmExprRhsValHi:   .res 1
CasmExprRhsFlags:   .res 1

; WP68 Increment 6 Atomic Step 4: mulUnsigned16's own private scratch --
; transient per multiply application, same lifetime shape as the RHS scratch
; above.
CasmExprMulcandLo:  .res 1
CasmExprMulcandHi:  .res 1
CasmExprMulplierLo: .res 1
CasmExprMulplierHi: .res 1
CasmExprProductLo:  .res 1
CasmExprProductHi:  .res 1

; WP68 Increment 6 Atomic Step 6: divUnsigned16's own private scratch --
; same lifetime shape as the multiply scratch above. 13 bytes total between
; the two, at the plan's approved ceiling.
CasmExprDivisorLo:    .res 1
CasmExprDivisorHi:    .res 1
CasmExprQuotientLo:   .res 1
CasmExprQuotientHi:   .res 1
CasmExprRemainderLo:  .res 1
CasmExprRemainderHi:  .res 1
CasmExprRemainderExt: .res 1

.assert CasmExprResultRecordEnd - CasmExprResultRecord = CASM_EXPR_REC_SIZE, error, "CASM expression result record size changed"
.assert <CasmExprResolverAddrLo <> $FF, lderror, "CASM resolver callback pointer crosses an NMOS 6502 indirect-jump page"
