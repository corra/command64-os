; tests/src/casm_pass1/casm_pass1.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 6B WP28 "Pass 1 measure engine" fixture harness.
; Unlike casm_symbols.s (WP27) and casm_vmm.s (WP25), which stub
; diagPrintFatal to avoid dragging in lexer.s/source.s, this harness links
; almost the entire CASM module set (fileio.s, source.s, state.s, lexer.s,
; parser.s, opcodes.s, emit.s, expr.s, diagnostics.s, resources.s,
; vmm_store.s, symbols.s) because parser.s/lexer.s/source.s already depend
; on the REAL diagnostics.s directly -- that stubbing trick does not apply
; here. It deliberately does NOT link cli.s or casm.s: casm.s owns its own
; HEADER/entry point (which would conflict with this harness's own), and
; cli.s is unnecessary for a harness that opens each fixture directly by
; name rather than through casm.s's own command-line parsing -- this file
; declares its own CasmSourceName/CasmOutputName buffers (see the BSS
; segment below) instead of pulling in all of cli.s's CLI-parsing
; dependency chain just for those two globals. fileio.s imports both names
; even though only CasmSourceName is ever written here: fileio.s's
; outputAbort references CasmOutputName directly, and ld65 links whole
; object files, so the symbol must resolve even though outputAbort itself
; is never called from this harness.
;
; Each fixture drives sourceOpen/lexerInit/emitInit(+override to
; CASM_PASS_MODE_MEASURE)/parserParseStatement in a loop over one .seq
; fixture file, dispatching label statements (CasmParserStmt.Type ==
; CASM_TOKEN_IDENTIFIER) to symbolsInsert and mnemonic/directive statements
; to opcodesFindOpcode/emitInstruction/emitDirective, then inspects the
; resulting CasmPc and/or symbol resolutions.
;
; Deliberate deviation from a literal single-shared-table design: every
; fixture below except p1undef1 defines a label named "LOOP" (see
; cmake/GenerateCasmTestFixtures.cmake's WP28 group) -- a single symbol
; table shared across all 7 fixtures would make every fixture after the
; first fail its own "LOOP:" insert with CASM_DIAG_DUPLICATE_SYMBOL purely
; from cross-fixture pollution, which is not what any fixture's hand-
; verified expected value assumes (each is computed against an empty
; table). symbolsInit is therefore called fresh at the top of each of the
; 7 fixture routines below (including p1dup1's own custom driver), giving
; each an isolated table -- p1dup1's two "LOOP:" inserts still collide only
; with each other, exactly as intended, just without leaking into any
; other fixture. symbolsInit's own vmmStoreAlloc call is cheap (32768 bytes
; each; 7 calls total, one per fixture, well within
; CASM_VMM_CAPACITY == 8 registry slots) and this harness exits via
; DOS_EXIT without any explicit cleanup, matching test_casm_vmm/
; test_casm_symbols's own precedent of not bothering to free VMM
; allocations in a short-lived test PRG.
;
; Every check against a same-routine failure uses inline "sec / rts" at the
; point of failure (matching test_casm_vmm.s/test_casm_symbols.s's own
; inverted-branch convention functionally, just without a shared trailing
; Fail label) -- this keeps every branch a few bytes long and immune to the
; 6502's +/-127-byte branch-range limit regardless of how a fixture grows.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_pass1.inc"

.import __MAIN_START__
.import resourcesInit
.import fileIoInit
.import sourceInit
.import sourceOpen
.import sourceClose
.import lexerInit
.import parserParseStatement
.import CasmParserStmt
.import CasmLabelName
.import CasmLabelNameLen
.import opcodesFindOpcode
.import emitInit
.import emitInstruction
.import emitDirective
.import CasmPc
.import CasmPassMode
.import symbolsInit
.import symbolsInsert
.import symbolsLookup

.export CasmSourceName   ; this harness's own copy -- NOT linking cli.s, see header
.export CasmOutputName   ; fileio.s's outputAbort references this by name

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    jsr resourcesInit
    jsr fileIoInit
    jsr sourceInit
    lda #0
    sta FailCount

    jsr p1label1
    jsr reportCase
    jsr p1labelinsn1
    jsr reportCase
    jsr p1fwd1
    jsr reportCase
    jsr p1back1
    jsr reportCase
    jsr p1undef1
    jsr reportCase
    jsr p1dup1
    jsr reportCase
    jsr p1size1
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
; runMeasurePass
; Open the fixture named by X/Y (a null-terminated PETSCII filename), drive
; the Pass 1 measure loop to EOF, then close the source. Label statements
; call symbolsInsert(CasmLabelName, CasmLabelNameLen, CasmPc) -- CasmPc is
; read BEFORE any instruction on the same line advances it, so the label's
; value is "the address of what comes next." Any C-set result from
; parserParseStatement/opcodesFindOpcode/emitInstruction/emitDirective, or
; from symbolsInsert (an UNEXPECTED duplicate/table-full/internal error --
; p1dup1 does NOT use this helper, precisely because it expects one), aborts
; the pass as a fixture failure.
;
; Inputs:  X/Y = fixture filename pointer (null-terminated PETSCII)
; Outputs: C clear on a clean run to EOF; C set on any unexpected failure
; Clobbers: A, X, Y and the full source/lexer/parser/opcode/emit/symbol
;           call chain's documented volatile state
; ---------------------------------------------------------------------------
runMeasurePass:
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldy #0
rmpCopyLoop:
    lda (CasmPtr1Lo), y
    sta CasmSourceName, y
    beq rmpCopyDone
    iny
    cpy #CASM_FILENAME_BUFFER_SIZE
    bcc rmpCopyLoop
rmpCopyDone:

    jsr sourceOpen
    bcc rmpSourceOk
    sec
    rts
rmpSourceOk:
    jsr lexerInit
    bcc rmpLexOk
    sec
    rts
rmpLexOk:
    jsr emitInit             ; resets CasmPc/CasmOrgSet/CasmPcOverflow/CasmEmitLen
                              ; -- and CasmPassMode to CASM_PASS_MODE_EMIT, which
                              ; MUST be overridden back to MEASURE immediately
                              ; below, every time, since emitInit's default
                              ; safety behavior assumes production single-pass use.
    lda #CASM_PASS_MODE_MEASURE
    sta CasmPassMode

rmpLoop:
    jsr parserParseStatement
    bcc rmpParseOk
    sec
    rts
rmpParseOk:
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    cmp #CASM_TOKEN_IDENTIFIER
    beq rmpLabel
    cmp #CASM_TOKEN_MNEMONIC
    beq rmpInsn
    cmp #CASM_TOKEN_DIRECTIVE
    beq rmpDir
    cmp #CASM_TOKEN_EOF
    beq rmpDone
    jmp rmpLoop               ; NEWLINE: nothing to do

rmpLabel:
    ; symbolsInsert wants: CasmPtr0Lo/Hi = namePtr, A = nameLen, X/Y = value.
    ; Stage the pointer first, then reload A/X/Y with the actual arguments
    ; (A is loaded before X/Y so the subsequent stx/sty/ldx/ldy sequence
    ; never clobbers it before the call).
    lda CasmLabelNameLen
    ldx #<CasmLabelName
    ldy #>CasmLabelName
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldx CasmPc
    ldy CasmPc + 1
    jsr symbolsInsert
    bcc rmpLoop
    sec
    rts

rmpInsn:
    jsr opcodesFindOpcode
    bcc rmpInsnOk
    sec
    rts
rmpInsnOk:
    jsr emitInstruction
    bcc rmpLoop
    sec
    rts

rmpDir:
    jsr emitDirective
    bcc rmpLoop
    sec
    rts

rmpDone:
    jsr sourceClose
    bcc rmpSuccess
    rts                       ; C set, A = close diagnostic
rmpSuccess:
    clc
    rts

; ---------------------------------------------------------------------------
; p1label1
; Bare label statement (LOOP: alone, no following instruction). LOOP must
; resolve to $C000 and does not itself advance CasmPc.
; ---------------------------------------------------------------------------
p1label1:
    jsr symbolsInit
    bcc p1l1InitOk
    sec
    rts
p1l1InitOk:
    ldx #<p1label1Name
    ldy #>p1label1Name
    jsr runMeasurePass
    bcc p1l1RmpOk
    sec
    rts
p1l1RmpOk:
    lda #<nameLOOP
    sta CasmPtr0Lo
    lda #>nameLOOP
    sta CasmPtr0Hi
    lda #4                    ; "LOOP" length
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc p1l1LookOk
    sec
    rts
p1l1LookOk:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne p1l1ResOk
    sec
    rts
p1l1ResOk:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$00
    bne p1l1Fail
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$C0
    bne p1l1Fail
    clc
    rts
p1l1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; p1labelinsn1
; LOOP: NOP on one line. LOOP resolves to $C000; NOP is its own following
; statement (1 byte), so final CasmPc = $C001.
; ---------------------------------------------------------------------------
p1labelinsn1:
    jsr symbolsInit
    bcc p1liInitOk
    sec
    rts
p1liInitOk:
    ldx #<p1labelinsn1Name
    ldy #>p1labelinsn1Name
    jsr runMeasurePass
    bcc p1liRmpOk
    sec
    rts
p1liRmpOk:
    lda #<nameLOOP
    sta CasmPtr0Lo
    lda #>nameLOOP
    sta CasmPtr0Hi
    lda #4
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc p1liLookOk
    sec
    rts
p1liLookOk:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne p1liResOk
    sec
    rts
p1liResOk:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$00
    bne p1liFail
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$C0
    bne p1liFail
    lda CasmPc
    cmp #$01
    bne p1liFail
    lda CasmPc + 1
    cmp #$C0
    bne p1liFail
    clc
    rts
p1liFail:
    sec
    rts

; ---------------------------------------------------------------------------
; p1fwd1
; Forward reference: "LDA LOOP" precedes "LOOP:"'s own definition. LOOP is
; unresolved when the LDA operand is processed, so it must size as absolute
; (3 bytes) via CASM_PARSER_STMT_FORCE_ABS, tolerated (not a runMeasurePass
; failure) in CASM_PASS_MODE_MEASURE. LOOP resolves to $0013; final CasmPc
; = $0014.
; ---------------------------------------------------------------------------
p1fwd1:
    jsr symbolsInit
    bcc p1fwInitOk
    sec
    rts
p1fwInitOk:
    ldx #<p1fwd1Name
    ldy #>p1fwd1Name
    jsr runMeasurePass
    bcc p1fwRmpOk
    sec
    rts
p1fwRmpOk:
    lda #<nameLOOP
    sta CasmPtr0Lo
    lda #>nameLOOP
    sta CasmPtr0Hi
    lda #4
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc p1fwLookOk
    sec
    rts
p1fwLookOk:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne p1fwResOk
    sec
    rts
p1fwResOk:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$13
    bne p1fwFail
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$00
    bne p1fwFail
    lda CasmPc
    cmp #$14
    bne p1fwFail
    lda CasmPc + 1
    cmp #$00
    bne p1fwFail
    clc
    rts
p1fwFail:
    sec
    rts

; ---------------------------------------------------------------------------
; p1back1
; Backward reference: "LOOP:" is defined ($0010, deliberately a zero high
; byte) BEFORE "LDA LOOP" resolves it. Proves CASM_PARSER_STMT_FORCE_ABS is
; derived from CASM_EXPR_FLAG_SYMBOL_DERIVED (set on every resolver success,
; resolved or not), not CASM_EXPR_FLAG_FORCE_ABS (unresolved-only): if it
; were derived from the latter, this resolved backward reference would
; wrongly shrink to zero-page (2 bytes) and final CasmPc would be $0013
; instead of $0014. LOOP resolves to $0010; final CasmPc = $0014.
; ---------------------------------------------------------------------------
p1back1:
    jsr symbolsInit
    bcc p1bkInitOk
    sec
    rts
p1bkInitOk:
    ldx #<p1back1Name
    ldy #>p1back1Name
    jsr runMeasurePass
    bcc p1bkRmpOk
    sec
    rts
p1bkRmpOk:
    lda #<nameLOOP
    sta CasmPtr0Lo
    lda #>nameLOOP
    sta CasmPtr0Hi
    lda #4
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc p1bkLookOk
    sec
    rts
p1bkLookOk:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne p1bkResOk
    sec
    rts
p1bkResOk:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$10
    bne p1bkFail
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$00
    bne p1bkFail
    lda CasmPc
    cmp #$14
    bne p1bkFail
    lda CasmPc + 1
    cmp #$00
    bne p1bkFail
    clc
    rts
p1bkFail:
    sec
    rts

; ---------------------------------------------------------------------------
; p1undef1
; GHOST is never defined anywhere in the fixture. A genuinely undefined
; symbol is tolerated in CASM_PASS_MODE_MEASURE (not a runMeasurePass
; failure): LDA GHOST sizes as absolute (3 bytes, FORCE_ABS forces it
; regardless of the zero placeholder value) and no diagnostic is raised.
; Final CasmPc = $0013.
; ---------------------------------------------------------------------------
p1undef1:
    jsr symbolsInit
    bcc p1udInitOk
    sec
    rts
p1udInitOk:
    ldx #<p1undef1Name
    ldy #>p1undef1Name
    jsr runMeasurePass
    bcc p1udRmpOk
    sec
    rts
p1udRmpOk:
    lda CasmPc
    cmp #$13
    bne p1udFail
    lda CasmPc + 1
    cmp #$00
    bne p1udFail
    clc
    rts
p1udFail:
    sec
    rts

; ---------------------------------------------------------------------------
; p1dup1
; Duplicate label definition. Does NOT use runMeasurePass, since it expects
; one specific, deliberate symbolsInsert failure partway through: the
; SECOND "LOOP:" statement's symbolsInsert call must return C set with
; A = CASM_DIAG_DUPLICATE_SYMBOL, which is this fixture's SUCCESS
; condition -- the harness stops right there (sourceClose, clc, rts)
; rather than continuing to EOF. If the first insert fails unexpectedly,
; or the second one succeeds, or fails with any diagnostic other than
; CASM_DIAG_DUPLICATE_SYMBOL, that is a fixture failure.
; ---------------------------------------------------------------------------
p1dup1:
    jsr symbolsInit
    bcc p1dpInitOk
    sec
    rts
p1dpInitOk:
    ldx #<p1dup1Name
    ldy #>p1dup1Name
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldy #0
p1dpCopyLoop:
    lda (CasmPtr1Lo), y
    sta CasmSourceName, y
    beq p1dpCopyDone
    iny
    cpy #CASM_FILENAME_BUFFER_SIZE
    bcc p1dpCopyLoop
p1dpCopyDone:

    jsr sourceOpen
    bcc p1dpOpenOk
    sec
    rts
p1dpOpenOk:
    jsr lexerInit
    bcc p1dpLexOk
    sec
    rts
p1dpLexOk:
    jsr emitInit
    lda #CASM_PASS_MODE_MEASURE
    sta CasmPassMode

    lda #0
    sta P1dpLabelCount

p1dpLoop:
    jsr parserParseStatement
    bcc p1dpParseOk
    sec
    rts
p1dpParseOk:
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    cmp #CASM_TOKEN_IDENTIFIER
    beq p1dpLabel
    cmp #CASM_TOKEN_MNEMONIC
    beq p1dpInsn
    cmp #CASM_TOKEN_DIRECTIVE
    beq p1dpDir
    cmp #CASM_TOKEN_EOF
    beq p1dpUnexpectedEof     ; the fixture must yield its 2nd label first
    jmp p1dpLoop              ; NEWLINE

p1dpLabel:
    inc P1dpLabelCount
    lda P1dpLabelCount
    cmp #2
    beq p1dpSecondLabel

    ; First label: expect a clean insert.
    lda CasmLabelNameLen
    ldx #<CasmLabelName
    ldy #>CasmLabelName
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldx CasmPc
    ldy CasmPc + 1
    jsr symbolsInsert
    bcc p1dpLoop
    sec
    rts

p1dpSecondLabel:
    ; Second label: expect CASM_DIAG_DUPLICATE_SYMBOL specifically.
    lda CasmLabelNameLen
    ldx #<CasmLabelName
    ldy #>CasmLabelName
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldx CasmPc
    ldy CasmPc + 1
    jsr symbolsInsert
    bcs p1dpCheckDup
    sec                       ; unexpectedly succeeded -- fixture failure
    rts
p1dpCheckDup:
    cmp #CASM_DIAG_DUPLICATE_SYMBOL
    bne p1dpFail
    jsr sourceClose
    clc
    rts

p1dpInsn:
    jsr opcodesFindOpcode
    bcc p1dpInsnOk
    sec
    rts
p1dpInsnOk:
    jsr emitInstruction
    bcc p1dpLoop
    sec
    rts

p1dpDir:
    jsr emitDirective
    bcc p1dpLoop
    sec
    rts

p1dpUnexpectedEof:
    sec
    rts
p1dpFail:
    sec
    rts

; ---------------------------------------------------------------------------
; p1size1
; Comprehensive sanity check: forward reference (JMP LOOP), backward-
; referenced labels (LOOP/DATA/VALS), and .byte/.word directives together.
; Hand-verified final CasmPc = $C010; LOOP resolves to $C003, DATA to
; $C009, VALS to $C00C.
; ---------------------------------------------------------------------------
p1size1:
    jsr symbolsInit
    bcc p1szInitOk
    sec
    rts
p1szInitOk:
    ldx #<p1size1Name
    ldy #>p1size1Name
    jsr runMeasurePass
    bcc p1szRmpOk
    rts                       ; C set, A = failure diagnostic
p1szRmpOk:
    lda CasmPc
    cmp #$10
    beq p1szPcOk1
    jmp p1szFail
p1szPcOk1:
    lda CasmPc + 1
    cmp #$C0
    beq p1szPcOk2
    jmp p1szFail
p1szPcOk2:

    lda #<nameLOOP
    sta CasmPtr0Lo
    lda #>nameLOOP
    sta CasmPtr0Hi
    lda #4
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc p1szLook1Ok
    sec
    rts
p1szLook1Ok:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne p1szRes1Ok
    jmp p1szFail
p1szRes1Ok:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$03
    beq p1szLoopLoOk
    jmp p1szFail
p1szLoopLoOk:
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$C0
    beq p1szLoopHiOk
    jmp p1szFail
p1szLoopHiOk:

    lda #<nameDATA
    sta CasmPtr0Lo
    lda #>nameDATA
    sta CasmPtr0Hi
    lda #4
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc p1szLook2Ok
    sec
    rts
p1szLook2Ok:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne p1szRes2Ok
    jmp p1szFail
p1szRes2Ok:
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$09
    beq p1szDataLoOk
    jmp p1szFail
p1szDataLoOk:
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$C0
    beq p1szDataHiOk
    jmp p1szFail
p1szDataHiOk:

    lda #<nameVALS
    sta CasmPtr0Lo
    lda #>nameVALS
    sta CasmPtr0Hi
    lda #4
    ldx #<ResolveView
    ldy #>ResolveView
    jsr symbolsLookup
    bcc p1szLook3Ok
    sec
    rts
p1szLook3Ok:
    lda ResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    beq p1szFail
    lda ResolveView + CASM_RESOLVE_VAL_LO
    cmp #$0C
    bne p1szFail
    lda ResolveView + CASM_RESOLVE_VAL_HI
    cmp #$C0
    bne p1szFail
    clc
    rts
p1szFail:
    sec
    rts

.segment "RODATA"

passMsg:
    .byte "CASM PASS1: PASS", PetCr, 0
failMsg:
    .byte "CASM PASS1: FAIL", PetCr, 0

; Fixture filenames, opened directly via CasmSourceName rather than through
; casm.s's CLI. Uppercase ASCII string literals produce byte values
; numerically identical to unshifted PETSCII for A-Z ($41-$5A) -- the exact
; byte range cc1541 -f writes into the directory entry when given a
; lowercase disk-name argument, per this project's cc1541 filename-case
; contract, and CMakeLists.txt's CASM_FIXTURE_DISK_NAME loop lowercases
; every "<name>.s" CASM source fixture disk name (see da0cc3c).
p1label1Name:       .byte "P1LABEL1.S", 0
p1labelinsn1Name:   .byte "P1LABELINSN1.S", 0
p1fwd1Name:         .byte "P1FWD1.S", 0
p1back1Name:        .byte "P1BACK1.S", 0
p1undef1Name:       .byte "P1UNDEF1.S", 0
p1dup1Name:         .byte "P1DUP1.S", 0
p1size1Name:        .byte "P1SIZE1.S", 0

; Label-name literals for symbolsLookup: bare bytes, no terminator (length
; is passed separately in A), matching tests/src/casm_symbols/casm_symbols.s's
; own fixture convention (nameLoop, etc.).
;
; Declared as explicit unshifted-ASCII .byte values, NOT quoted string
; literals: ca65's default charmap shifts letters in quoted string literals
; by +$80 (e.g. "LOOP" assembles to $CC,$CF,$CF,$D0, not $4C,$4F,$4F,$50) --
; confirmed empirically during WP28 debugging by dumping both sides of a
; failing comparison as raw hex. The lexer reads the fixture .seq files'
; content completely unconverted (cc1541 -w performs no content conversion
; at all, also confirmed empirically by parsing the D64 image directly), so
; CasmLabelName always holds plain unshifted ASCII. A quoted string literal
; here would silently mismatch every comparison. (Filenames like
; p1label1Name below are unaffected by this: they use ca65's charmap too,
; but cc1541 -f apparently encodes disk directory names the same shifted way
; by default, so sourceOpen's filename comparison already matched on both
; sides -- only this content-vs-quoted-literal comparison was broken.)
nameLOOP: .byte $4C, $4F, $4F, $50
nameDATA: .byte $44, $41, $54, $41
nameVALS: .byte $56, $41, $4C, $53

.segment "BSS"

FailCount:      .res 1

; Shared symbolsLookup output view (CASM_RESOLVE_* layout), reused across
; fixtures the same way ResolveView is reused in test_casm_symbols.s.
ResolveView:    .res CASM_RESOLVE_SIZE

; runMeasurePass/p1dup1's filename copy loop stages the fixture filename
; pointer in CasmPtr1Lo/Hi (common.inc's general-purpose zero-page pointer
; pair) rather than a private BSS cell here: (indirect),Y addressing
; requires a genuine zero-page operand, and this cell is only ever read
; back within the same copy loop, well before any CASM routine that also
; uses CasmPtr1Lo/Hi as its own transient scratch runs.

; p1dup1 scratch: counts label (IDENTIFIER) statements seen so far, so its
; own driver knows which "LOOP:" occurrence it is on.
P1dpLabelCount: .res 1

; This harness's own copies of the two filename buffers fileio.s imports
; (CasmSourceName/CasmOutputName) -- normally provided by cli.s, which this
; harness does not link. See the file header for the full rationale.
CasmSourceName: .res CASM_FILENAME_BUFFER_SIZE
CasmOutputName: .res CASM_FILENAME_BUFFER_SIZE
