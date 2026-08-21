; tests/src/casm_directives/casm_directives.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 13 WP81: .RES/.FILL/.ALIGN isolation harness. Links real emit.s
; only and drives it directly through CasmParserStmt/CasmFillCountLo/Hi/
; CasmFillValue records and emitDirective's RES/FILL/ALIGN dispatch,
; bypassing lexer.s/parser.s's ppsFillDirective entirely -- proves
; emitRes/emitFill/emitAlign/emitFillLoop/emitAlignMod's own program-counter
; arithmetic, zero-count/zero-padding short-circuits, boundary-zero
; rejection, and overflow-propagation in isolation, independent of what the
; real lexer/parser would produce for any given source text. Same structural
; precedent as casm_bounds.s (Phase 11 WP60 Increment 6): that harness
; proves emitInstruction's PC/range-check bookkeeping the same way for
; branches; this one proves the equivalent for the three new fill-shaped
; directives. Actual emitted BYTE VALUES are proven separately by this WP's
; own production .ref.hex fixtures (COMP-verified against hand-derived
; references) -- CasmEmitBuffer is private to emit.s (not exported), so this
; harness (like casm_bounds before it) can only observe CasmPc and the
; returned diagnostic, not byte content.
;
; emit.s pulls in lexer.s/parser.s/fileio.s/listing.s/reloc.s symbols
; (lexerNext, CasmTokenRecord, parserParseExpressionValue, relocRecord,
; listingMirrorByte, diagSetLocFromToken, diagSetLocFromStmt, diagClearLoc,
; fileWrite, CasmCliOptions) only for its .BYTE/.WORD-list and relocatable-
; record paths -- none of which this harness's cases reach (every
; CasmParserStmt.Flags stays 0, so emitMaybeRecordLo/Hi's RELOCATABLE gate
; never calls relocRecord; the emit buffer never fills within a handful of
; bytes per case, so emitFlush/fileWrite is never reached). Each stubbed
; locally to the minimum needed to satisfy the linker, matching
; casm_bounds.s's own precedent exactly.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_directives.inc"

.import __MAIN_START__
.import emitInit
.import emitDirective
.import CasmPc

.export CasmParserStmt
.export CasmInsn
.export CasmCliOptions
.export CasmTokenRecord
.export CasmTokenText
.export CasmStringLength
.export CasmStringBuffer
.export diagSetLocFromStmt
.export diagSetLocFromToken
.export diagClearLoc
.export lexerNext
.export parserParseExpressionValue
.export relocRecord
.export listingMirrorByte
.export fileWrite
; This harness supplies these directly (the whole point -- ppsFillDirective
; is bypassed), not as unreachable stand-ins.
.export CasmFillCountLo
.export CasmFillCountHi
.export CasmFillValue

.segment "HEADER"
    .word __MAIN_START__

.segment "BSS"
CasmParserStmt:    .res CASM_PARSER_STMT_SIZE
; emit.s links whole, so emitInstruction's own CasmInsn references need
; resolving even though this harness never calls emitInstruction (every
; case dispatches through emitDirective's .ORG/.RES/.FILL/.ALIGN paths
; only) -- same stand-in precedent as CasmTokenText/CasmStringLength below.
CasmInsn:          .res CASM_INSN_SIZE
CasmCliOptions:    .res 1
CasmTokenRecord:   .res CASM_TOKEN_REC_SIZE
; emit.s links whole, but this harness never enters .BYTE list parsing. These
; one-byte stand-ins resolve its unreachable CHAR/STRING imports without
; importing lexer.s or duplicating production-sized payload storage --
; same precedent as casm_bounds.s.
CasmTokenText:     .res 1
CasmStringLength:  .res 1
CasmStringBuffer:  .res 1
CasmFillCountLo:   .res 1
CasmFillCountHi:   .res 1
CasmFillValue:     .res 1
FailCount:         .res 1
OrgLo:             .res 1
OrgHi:             .res 1

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda #0
    sta FailCount
    ; BSS is not guaranteed zeroed on load -- explicitly zeroed rather than
    ; trusted to .res's initial content, same precedent as casm_bounds.s's
    ; own CasmCliOptions zeroing.
    sta CasmCliOptions

    jsr resZeroCount
    jsr reportCase
    jsr resNormalCount
    jsr reportCase
    jsr resDefaultValue
    jsr reportCase
    jsr fillNormalCount
    jsr reportCase
    jsr fillZeroCount
    jsr reportCase
    jsr alignAlreadyAligned
    jsr reportCase
    jsr alignNeedsPadding
    jsr reportCase
    jsr alignBoundaryZero
    jsr reportCase
    jsr resOverflow
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
; FailCount. Called immediately after each case routine below.
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
; setOrg (private helper)
; emitInit, then emitDirective a real ".ORG <X/Y>" statement (16-bit
; little-endian in X/Y). Outputs: emitDirective's own C/A; CasmPc set on
; success. Every caller below passes a well-formed literal, so failure here
; is never expected.
; ---------------------------------------------------------------------------
setOrg:
    stx OrgLo
    sty OrgHi
    jsr emitInit
    lda #CASM_DIRECTIVE_ORG
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    lda #CASM_OPKIND_ABSOLUTE
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    lda #0
    sta CasmParserStmt + CASM_PARSER_STMT_FLAGS
    lda OrgLo
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    lda OrgHi
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    jmp emitDirective

; ---------------------------------------------------------------------------
; resZeroCount
; .ORG $C000; .RES 0,$FF -- zero-iteration loop, no bytes written. Expect
; C clear, CasmPc unchanged at $C000 (emitFillLoop's own count==0 short-
; circuit, checked before the first emitByte call).
; ---------------------------------------------------------------------------
resZeroCount:
    ldx #<$C000
    ldy #>$C000
    jsr setOrg
    bcs rzcFail
    lda #CASM_DIRECTIVE_RES
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    lda #0
    sta CasmFillCountLo
    sta CasmFillCountHi
    lda #$FF
    sta CasmFillValue
    jsr emitDirective
    bcs rzcFail
    lda CasmPc
    cmp #$00
    bne rzcFail
    lda CasmPc + 1
    cmp #$C0
    bne rzcFail
    clc
    rts
rzcFail:
    sec
    rts

; ---------------------------------------------------------------------------
; resNormalCount
; .ORG $C000; .RES 5,$AA -- expect C clear, CasmPc=$C005 (5 bytes emitted).
; ---------------------------------------------------------------------------
resNormalCount:
    ldx #<$C000
    ldy #>$C000
    jsr setOrg
    bcs rncFail
    lda #CASM_DIRECTIVE_RES
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    lda #5
    sta CasmFillCountLo
    lda #0
    sta CasmFillCountHi
    lda #$AA
    sta CasmFillValue
    jsr emitDirective
    bcs rncFail
    lda CasmPc
    cmp #$05
    bne rncFail
    lda CasmPc + 1
    cmp #$C0
    bne rncFail
    clc
    rts
rncFail:
    sec
    rts

; ---------------------------------------------------------------------------
; resDefaultValue
; .ORG $C000; .RES 3 (no second operand -- CasmFillValue left at its
; ppsFillDirective-staged default of 0, simulated here directly). Expect
; C clear, CasmPc=$C003. Byte VALUE correctness (that all 3 bytes are
; genuinely $00) is proven by the production .ref.hex fixture, not here
; (CasmEmitBuffer is private to emit.s) -- this case exists to prove the
; count/PC arithmetic path is identical regardless of fill value.
; ---------------------------------------------------------------------------
resDefaultValue:
    ldx #<$C000
    ldy #>$C000
    jsr setOrg
    bcs rdvFail
    lda #CASM_DIRECTIVE_RES
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    lda #3
    sta CasmFillCountLo
    lda #0
    sta CasmFillCountHi
    sta CasmFillValue
    jsr emitDirective
    bcs rdvFail
    lda CasmPc
    cmp #$03
    bne rdvFail
    lda CasmPc + 1
    cmp #$C0
    bne rdvFail
    clc
    rts
rdvFail:
    sec
    rts

; ---------------------------------------------------------------------------
; fillNormalCount
; .ORG $C000; .FILL 4,$40 -- expect C clear, CasmPc=$C004. Same mechanism as
; resNormalCount, proven through emitFill's own dispatch entry instead of
; emitRes's.
; ---------------------------------------------------------------------------
fillNormalCount:
    ldx #<$C000
    ldy #>$C000
    jsr setOrg
    bcs fncFail
    lda #CASM_DIRECTIVE_FILL
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    lda #4
    sta CasmFillCountLo
    lda #0
    sta CasmFillCountHi
    lda #$40
    sta CasmFillValue
    jsr emitDirective
    bcs fncFail
    lda CasmPc
    cmp #$04
    bne fncFail
    lda CasmPc + 1
    cmp #$C0
    bne fncFail
    clc
    rts
fncFail:
    sec
    rts

; ---------------------------------------------------------------------------
; fillZeroCount
; .ORG $C000; .FILL 0,$40 -- .FILL's required-value grammar still allows a
; zero count (the Language Contract only requires the value operand be
; present, not that count be nonzero). Expect C clear, CasmPc unchanged.
; ---------------------------------------------------------------------------
fillZeroCount:
    ldx #<$C000
    ldy #>$C000
    jsr setOrg
    bcs fzcFail
    lda #CASM_DIRECTIVE_FILL
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    lda #0
    sta CasmFillCountLo
    sta CasmFillCountHi
    lda #$40
    sta CasmFillValue
    jsr emitDirective
    bcs fzcFail
    lda CasmPc
    cmp #$00
    bne fzcFail
    lda CasmPc + 1
    cmp #$C0
    bne fzcFail
    clc
    rts
fzcFail:
    sec
    rts

; ---------------------------------------------------------------------------
; alignAlreadyAligned
; .ORG $C010; .ALIGN $10 -- CasmPc is already a multiple of the boundary, so
; emitAlignMod's remainder is 0 and emitAlign's own padding computation
; short-circuits to CasmEmitScratch0/1=0 (zero-iteration emitFillLoop, same
; shape as resZeroCount). Expect C clear, CasmPc unchanged at $C010.
; ---------------------------------------------------------------------------
alignAlreadyAligned:
    ldx #<$C010
    ldy #>$C010
    jsr setOrg
    bcs aaaFail
    lda #CASM_DIRECTIVE_ALIGN
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    lda #$10
    sta CasmFillCountLo
    lda #0
    sta CasmFillCountHi
    sta CasmFillValue
    jsr emitDirective
    bcs aaaFail
    lda CasmPc
    cmp #$10
    bne aaaFail
    lda CasmPc + 1
    cmp #$C0
    bne aaaFail
    clc
    rts
aaaFail:
    sec
    rts

; ---------------------------------------------------------------------------
; alignNeedsPadding
; .ORG $C003; .ALIGN $10 -- CasmPc mod $10 = 3, so padding = $10-3 = 13
; ($0D) bytes. Expect C clear, CasmPc=$C003+$0D=$C010 (the next boundary).
; Independently reconciled by hand: $C003 mod 16 = 3 (0xC003 = 0xC000 + 3,
; and 0xC000 is itself 16-aligned), so padding = 16-3 = 13.
; ---------------------------------------------------------------------------
alignNeedsPadding:
    ldx #<$C003
    ldy #>$C003
    jsr setOrg
    bcs anpFail
    lda #CASM_DIRECTIVE_ALIGN
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    lda #$10
    sta CasmFillCountLo
    lda #0
    sta CasmFillCountHi
    sta CasmFillValue
    jsr emitDirective
    bcs anpFail
    lda CasmPc
    cmp #$10
    bne anpFail
    lda CasmPc + 1
    cmp #$C0
    bne anpFail
    clc
    rts
anpFail:
    sec
    rts

; ---------------------------------------------------------------------------
; alignBoundaryZero
; .ORG $C000; .ALIGN 0 -- CasmFillCountLo/Hi both 0 (the resolved-boundary
; simulated directly, as ppsFillDirective would stage it). Expect C set,
; A=CASM_DIAG_ALIGN_BOUNDARY_ZERO, CasmPc unchanged (rejected before any
; padding is computed or emitted).
; ---------------------------------------------------------------------------
alignBoundaryZero:
    ldx #<$C000
    ldy #>$C000
    jsr setOrg
    bcs abzFail
    lda #CASM_DIRECTIVE_ALIGN
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    lda #0
    sta CasmFillCountLo
    sta CasmFillCountHi
    sta CasmFillValue
    jsr emitDirective
    bcc abzFail             ; must fail -- success here is the fixture failure
    cmp #CASM_DIAG_ALIGN_BOUNDARY_ZERO
    bne abzFail
    lda CasmPc
    cmp #$00
    bne abzFail
    lda CasmPc + 1
    cmp #$C0
    bne abzFail
    clc
    rts
abzFail:
    sec
    rts

; ---------------------------------------------------------------------------
; resOverflow
; .ORG $FFFE; .RES 3,$00 -- the first two bytes commit ($FFFE, $FFFF,
; wrapping CasmPc to $0000 and setting emitByte's own overflow latch on the
; second write), then the third emitFillLoop iteration's emitByte call fails
; with CASM_DIAG_ADDRESS_OVERFLOW before writing anything (emitByte's
; CasmPcOverflow gate, checked before emitRawByte -- same commit-point shape
; as casm_bounds.s's own pcRejectOverflow). Expect C set,
; A=CASM_DIAG_ADDRESS_OVERFLOW, CasmPc=$0000 (left at the value the second,
; successful byte produced; the failed third iteration never touches PC).
; ---------------------------------------------------------------------------
resOverflow:
    ldx #<$FFFE
    ldy #>$FFFE
    jsr setOrg
    bcs roFail
    lda #CASM_DIRECTIVE_RES
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    lda #3
    sta CasmFillCountLo
    lda #0
    sta CasmFillCountHi
    sta CasmFillValue
    jsr emitDirective
    bcc roFail              ; must fail -- success here is the fixture failure
    cmp #CASM_DIAG_ADDRESS_OVERFLOW
    bne roFail
    lda CasmPc
    bne roFail
    lda CasmPc + 1
    bne roFail
    clc
    rts
roFail:
    sec
    rts

; ---------------------------------------------------------------------------
; diagSetLocFromStmt / diagSetLocFromToken / diagClearLoc (local stand-ins)
; No test case in this harness inspects diagnostic *location* (only the
; diagnostic code and CasmPc state), so these record nothing -- they exist
; solely to satisfy emit.s's linker references without pulling in
; diagnostics.s's transitive lexer.s/parser.s state, matching
; casm_bounds.s's own precedent.
; ---------------------------------------------------------------------------
diagSetLocFromStmt:
diagSetLocFromToken:
diagClearLoc:
    rts

; ---------------------------------------------------------------------------
; lexerNext / parserParseExpressionValue (local stand-ins)
; Only reachable from emitDirective's .BYTE/.WORD-list paths, which this
; harness never invokes (every case uses .ORG or a direct .RES/.FILL/.ALIGN
; dispatch with CasmFillCountLo/Hi/CasmFillValue supplied directly).
; ---------------------------------------------------------------------------
lexerNext:
parserParseExpressionValue:
    clc
    rts

; ---------------------------------------------------------------------------
; relocRecord (local stand-in)
; Only reachable when CASM_PARSER_STMT_RELOCATABLE is set, which no case
; here ever sets (every CasmParserStmt.Flags stays 0) -- .RES/.FILL/.ALIGN
; never call relocRecord regardless (parent plan's Research Summary point 4).
; ---------------------------------------------------------------------------
relocRecord:
    clc
    rts

; ---------------------------------------------------------------------------
; listingMirrorByte (local stand-in)
; Real listingMirrorByte is a no-op whenever listing capture is disabled;
; this harness never enables it, so this always takes that same no-op path.
; ---------------------------------------------------------------------------
listingMirrorByte:
    clc
    rts

; ---------------------------------------------------------------------------
; fileWrite (local stand-in)
; Only reachable via emitFlush, which only runs when the emit buffer fills
; (CASM_EMIT_BUFFER_SIZE bytes) -- no case here emits more than a handful of
; bytes, so this is never actually called.
; ---------------------------------------------------------------------------
fileWrite:
    clc
    rts

.segment "RODATA"

passMsg:
    .byte "CASM DIRECTIVES: PASS", PetCr, 0
failMsg:
    .byte "CASM DIRECTIVES: FAIL", PetCr, 0
