; tests/src/casm_bounds/casm_bounds.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 11 WP60 Increment 6: Relative Branch and Program Counter
; boundary harness. Links real emit.s only and drives it directly through
; CasmParserStmt/CasmInsn records and emitDirective's .ORG path, bypassing
; lexer.s/parser.s/source.s entirely -- proves emitInstruction's own
; relative-displacement range check (eiRelative) and emitByte's own
; program-counter/overflow bookkeeping in isolation, independent of what the
; real lexer/parser would produce for any given source text. This is a
; different production routine than Increment 4's opcodesFindOpcode-only
; matcher: mode SELECTION (opcodesFindOpcode) and displacement COMPUTATION/
; RANGE-CHECKING (emitInstruction) are separate routines, and only the
; latter is exercised here.
;
; Every branch case's literal target reconciles by hand against
; nextPc = CasmPc(after opcode)+1 and disp = target-nextPc, independently of
; production -- e.g. .ORG $C000: the opcode byte at $C000 advances CasmPc to
; $C001 (operand position), so nextPc = $C002 and target = nextPc+disp. The
; four accept targets ($C081/+127, $BF83/-127, $C002/0, $BF82/-128) and two
; reject targets ($C082/+128, $BF81/-129) match this project's existing
; Phase 4/6 fixtures (casmbrp1/brn1/brp2/brn2's own .seq generators in
; cmake/GenerateCasmTestFixtures.cmake) at the two shared boundary values,
; confirming this harness's independent arithmetic agrees with those
; fixtures' own hand-derived literals rather than silently disagreeing.
;
; emit.s pulls in lexer.s/parser.s/fileio.s/listing.s/reloc.s symbols
; (lexerNext, CasmTokenRecord, parserParseExpressionValue, relocRecord,
; listingMirrorByte, diagSetLocFromToken, diagClearLoc, fileWrite,
; CasmCliOptions) only for its .BYTE/.WORD-list and relocatable-record
; paths -- none of which this harness's cases reach (no directive besides
; .ORG is ever emitted; every CasmParserStmt.Flags stays 0, so
; emitMaybeRecordLo/Hi's RELOCATABLE-flag gate never calls relocRecord; the
; emit buffer never fills within a handful of bytes per case, so
; emitFlush/fileWrite is never reached). Each is stubbed locally to the
; minimum needed to satisfy the linker, matching casm_opcodes.s's own
; diagSetLocFromStmt-stub precedent -- diagSetLocFromStmt itself is stubbed
; the same way here for the same reason (real diagnostics.s pulls in
; CasmStmtLoc*/lexer.s state transitively).
;
; Case routines follow casm_pass1.s's per-fixture-subroutine convention
; (not casm_opcodes.s's uniform case-table convention): the twelve required
; rows are heterogeneous enough (single emitInstruction calls vs. chained
; multi-call PC-overflow/repeat-reset sequences) that a shared table would
; need per-row special-casing anyway.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_bounds.inc"

.import __MAIN_START__
.import emitInit
.import emitInstruction
.import emitDirective
.import CasmPc
.import CasmPassMode
.import CasmRelocatableMode

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
; WP81: emit.s links whole, so its new emitRes/emitFill/emitAlign pull in
; parser.s's CasmFillCountLo/Hi/CasmFillValue externs even though this
; harness never dispatches .RES/.FILL/.ALIGN -- one-byte stand-ins, same
; precedent as CasmTokenText/CasmStringLength/CasmStringBuffer above.
.export CasmFillCountLo
.export CasmFillCountHi
.export CasmFillValue
; WP82: emit.s links whole, so its new emitIncbin pulls in parser.s's
; CasmIncbinFilename and fileio.s's inputStreamOpen/Read/Close/CasmIoBuffer
; externs even though this harness never dispatches .INCBIN -- same
; one-byte/no-op stand-in precedent as above.
.export CasmIncbinFilename
.export CasmIoBuffer
.export inputStreamOpen
.export inputStreamRead
.export inputStreamClose
; WP83: emit.s links whole, so its new emitAssert pulls in parser.s's
; CasmAssertValueLo/Hi externs even though this harness never dispatches
; .ASSERT -- same one-byte stand-in precedent as above.
.export CasmAssertValueLo
.export CasmAssertValueHi

; BNE, Implied CLC -- real documented NMOS opcodes, independently known
; (also cross-checked against the WP60 Increment 1 oracle: BNE/Relative =
; $D0, CLC/Implied = $18).
OP_BNE = $D0
OP_CLC = $18

.segment "HEADER"
    .word __MAIN_START__

.segment "BSS"
CasmParserStmt:    .res CASM_PARSER_STMT_SIZE
CasmInsn:          .res CASM_INSN_SIZE
CasmCliOptions:    .res 1
CasmTokenRecord:   .res CASM_TOKEN_REC_SIZE
; emit.s links whole, but this harness never enters .BYTE list parsing. These
; one-byte stand-ins resolve its unreachable CHAR/STRING imports without
; importing lexer.s or duplicating production-sized payload storage.
CasmTokenText:     .res 1
CasmStringLength:  .res 1
CasmStringBuffer:  .res 1
CasmFillCountLo:   .res 1
CasmFillCountHi:   .res 1
CasmFillValue:     .res 1
CasmIncbinFilename: .res 1
CasmIoBuffer:      .res 1
CasmAssertValueLo: .res 1
CasmAssertValueHi: .res 1
FailCount:         .res 1
OrgLo:             .res 1
OrgHi:             .res 1
TargetLo:          .res 1
TargetHi:          .res 1

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda #0
    sta FailCount
    ; BSS is not guaranteed zeroed on load; pcRepeatReset depends on this
    ; genuinely being 0 (not static) to observe emitInit's real default-
    ; origin priming, so it is zeroed explicitly rather than trusted to
    ; .res's initial content -- see that case's own header comment.
    sta CasmCliOptions

    jsr brAcceptPos127
    jsr reportCase
    jsr brAcceptNeg127
    jsr reportCase
    jsr brAcceptZero
    jsr reportCase
    jsr brAcceptNeg128
    jsr reportCase
    jsr brRejectPos128
    jsr reportCase
    jsr brRejectNeg129
    jsr reportCase
    jsr brWrapEndpoint
    jsr reportCase

    jsr pcOrgZero
    jsr reportCase
    jsr pcOrgFFFE
    jsr reportCase
    jsr pcEndAtFFFF
    jsr reportCase
    jsr pcRejectOverflow
    jsr reportCase
    jsr pcRepeatReset
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
; branchCase (private helper)
; A 2-byte BNE/Relative instruction targeting X/Y, against whatever CasmPc
; the caller already established via setOrg. Outputs: emitInstruction's own
; C/A.
; ---------------------------------------------------------------------------
branchCase:
    stx TargetLo
    sty TargetHi
    lda #OP_BNE
    sta CasmInsn + CASM_INSN_OPCODE
    lda #CASM_MODE_RELATIVE
    sta CasmInsn + CASM_INSN_MODE
    lda #2
    sta CasmInsn + CASM_INSN_LENGTH
    lda #0
    sta CasmParserStmt + CASM_PARSER_STMT_FLAGS
    lda TargetLo
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    lda TargetHi
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    jmp emitInstruction

; ---------------------------------------------------------------------------
; oneByteCase (private helper)
; A 1-byte CLC/Implied instruction, against whatever CasmPc the caller
; already established. Outputs: emitInstruction's own C/A.
; ---------------------------------------------------------------------------
oneByteCase:
    lda #OP_CLC
    sta CasmInsn + CASM_INSN_OPCODE
    lda #CASM_MODE_IMPLIED
    sta CasmInsn + CASM_INSN_MODE
    lda #1
    sta CasmInsn + CASM_INSN_LENGTH
    lda #0
    sta CasmParserStmt + CASM_PARSER_STMT_FLAGS
    jmp emitInstruction

; ---------------------------------------------------------------------------
; brAcceptPos127
; +127 (accept, upper boundary). .ORG $C000; BNE $C081. nextPc=$C002,
; disp=$C081-$C002=+$7F=+127. Expect C clear, CasmPc=$C002 (opcode+operand
; both committed).
; ---------------------------------------------------------------------------
brAcceptPos127:
    ldx #<$C000
    ldy #>$C000
    jsr setOrg
    bcs bap127Fail
    ldx #<$C081
    ldy #>$C081
    jsr branchCase
    bcs bap127Fail
    lda CasmPc
    cmp #$02
    bne bap127Fail
    lda CasmPc + 1
    cmp #$C0
    bne bap127Fail
    clc
    rts
bap127Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; brAcceptNeg127
; -127 (accept). .ORG $C000; BNE $BF83. nextPc=$C002, disp=$BF83-$C002=-127.
; ---------------------------------------------------------------------------
brAcceptNeg127:
    ldx #<$C000
    ldy #>$C000
    jsr setOrg
    bcs banFail
    ldx #<$BF83
    ldy #>$BF83
    jsr branchCase
    bcs banFail
    lda CasmPc
    cmp #$02
    bne banFail
    lda CasmPc + 1
    cmp #$C0
    bne banFail
    clc
    rts
banFail:
    sec
    rts

; ---------------------------------------------------------------------------
; brAcceptZero
; 0 (accept, branch to the instruction immediately following itself).
; .ORG $C000; BNE $C002. nextPc=$C002, disp=0.
; ---------------------------------------------------------------------------
brAcceptZero:
    ldx #<$C000
    ldy #>$C000
    jsr setOrg
    bcs bazFail
    ldx #<$C002
    ldy #>$C002
    jsr branchCase
    bcs bazFail
    lda CasmPc
    cmp #$02
    bne bazFail
    lda CasmPc + 1
    cmp #$C0
    bne bazFail
    clc
    rts
bazFail:
    sec
    rts

; ---------------------------------------------------------------------------
; brAcceptNeg128
; -128 (accept, lower boundary). .ORG $C000; BNE $BF82. nextPc=$C002,
; disp=$BF82-$C002=-$80=-128.
; ---------------------------------------------------------------------------
brAcceptNeg128:
    ldx #<$C000
    ldy #>$C000
    jsr setOrg
    bcs ban128Fail
    ldx #<$BF82
    ldy #>$BF82
    jsr branchCase
    bcs ban128Fail
    lda CasmPc
    cmp #$02
    bne ban128Fail
    lda CasmPc + 1
    cmp #$C0
    bne ban128Fail
    clc
    rts
ban128Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; brRejectPos128
; +128 (reject, one past the upper boundary). .ORG $C000; BNE $C082.
; nextPc=$C002, disp=+128. Expect C set, A=CASM_DIAG_BRANCH_OUT_OF_RANGE,
; and CasmPc=$C001 -- the opcode byte is committed (emitByte runs before the
; range check) but the operand byte is not (eiBranchErr returns before its
; own emitByte call), so CasmPc stops one byte short of the 2-byte length.
; ---------------------------------------------------------------------------
brRejectPos128:
    ldx #<$C000
    ldy #>$C000
    jsr setOrg
    bcs brp128Fail
    ldx #<$C082
    ldy #>$C082
    jsr branchCase
    bcc brp128Fail          ; must fail -- success here is the fixture failure
    cmp #CASM_DIAG_BRANCH_OUT_OF_RANGE
    bne brp128Fail
    lda CasmPc
    cmp #$01
    bne brp128Fail
    lda CasmPc + 1
    cmp #$C0
    bne brp128Fail
    clc
    rts
brp128Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; brRejectNeg129
; -129 (reject, one past the lower boundary). .ORG $C000; BNE $BF81.
; nextPc=$C002, disp=-129. Same commit-point shape as brRejectPos128.
; ---------------------------------------------------------------------------
brRejectNeg129:
    ldx #<$C000
    ldy #>$C000
    jsr setOrg
    bcs brn129Fail
    ldx #<$BF81
    ldy #>$BF81
    jsr branchCase
    bcc brn129Fail
    cmp #CASM_DIAG_BRANCH_OUT_OF_RANGE
    bne brn129Fail
    lda CasmPc
    cmp #$01
    bne brn129Fail
    lda CasmPc + 1
    cmp #$C0
    bne brn129Fail
    clc
    rts
brn129Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; brWrapEndpoint
; Wrap-sensitive PC endpoint: a branch whose own nextPc computation crosses
; the $FFFF/$0000 boundary. .ORG $FFFE: the opcode byte at $FFFE advances
; CasmPc to $FFFF (operand position); nextPc = $FFFF+1 wraps to $0000.
; Targeting $0000 gives disp=0 (in range) -- proves the 8-bit ADC chain that
; computes nextPc wraps correctly rather than mis-ranging at the top of
; address space. Expect C clear, CasmPc=$0000 (operand byte itself also
; wraps when written). Does NOT assert CasmPcOverflow: emit.s does not
; .export it (private BSS to that module -- confirmed by grepping its own
; .export list), so a same-named byte declared here would be a disconnected
; shadow, never written by real emitByte, and reading it back would either
; always read this harness's own uninitialized BSS content (not guaranteed
; zero on load) or silently pass/fail by accident depending on whatever
; garbage happened to be there -- caught live: an earlier revision of this
; harness declared exactly that shadow and it produced a false pass here
; purely from incidental nonzero BSS content, not from exercising anything
; real. CasmPc alone (genuinely exported/shared) is sufficient evidence for
; this row: the wrap only reads as $0000 if the operand byte was actually
; committed at the $FFFF/$0000 boundary.
; ---------------------------------------------------------------------------
brWrapEndpoint:
    ldx #<$FFFE
    ldy #>$FFFE
    jsr setOrg
    bcs bweFail
    ldx #<$0000
    ldy #>$0000
    jsr branchCase
    bcs bweFail
    lda CasmPc
    bne bweFail
    lda CasmPc + 1
    bne bweFail
    clc
    rts
bweFail:
    sec
    rts

; ---------------------------------------------------------------------------
; pcOrgZero
; .ORG $0000 (lower PC boundary). Expect C clear, CasmPc=$0000. Does NOT
; assert CasmOutputStarted: also private to emit.s (not exported), same
; disconnected-shadow hazard as CasmPcOverflow above -- see brWrapEndpoint's
; header for the live false-result this class of bug already produced in
; this file before being caught and removed.
; ---------------------------------------------------------------------------
pcOrgZero:
    ldx #<$0000
    ldy #>$0000
    jsr setOrg
    bcs pczFail
    lda CasmPc
    bne pczFail
    lda CasmPc + 1
    bne pczFail
    clc
    rts
pczFail:
    sec
    rts

; ---------------------------------------------------------------------------
; pcOrgFFFE
; .ORG $FFFE. Expect C clear, CasmPc=$FFFE.
; ---------------------------------------------------------------------------
pcOrgFFFE:
    ldx #<$FFFE
    ldy #>$FFFE
    jsr setOrg
    bcs pcfFail
    lda CasmPc
    cmp #$FE
    bne pcfFail
    lda CasmPc + 1
    cmp #$FF
    bne pcfFail
    clc
    rts
pcfFail:
    sec
    rts

; ---------------------------------------------------------------------------
; pcEndAtFFFF
; Emission ending exactly at $FFFF (accept). .ORG $FFFF; one 1-byte
; instruction writes to address $FFFF itself -- the last valid address.
; Expect C clear (the write succeeds) and CasmPc wraps to $0000 as an
; immediate side effect of that last valid write (emitByte's own
; inc-with-overflow-detect, not a separate failure). Does NOT assert
; CasmPcOverflow directly (private to emit.s, not exported -- see
; brWrapEndpoint's header); pcRejectOverflow below proves the overflow
; latch was really set, indirectly but reliably, via the one channel emit.s
; does expose it through: the very next write's own returned diagnostic.
; ---------------------------------------------------------------------------
pcEndAtFFFF:
    ldx #<$FFFF
    ldy #>$FFFF
    jsr setOrg
    bcs peaFail
    jsr oneByteCase
    bcs peaFail
    lda CasmPc
    bne peaFail
    lda CasmPc + 1
    bne peaFail
    clc
    rts
peaFail:
    sec
    rts

; ---------------------------------------------------------------------------
; pcRejectOverflow
; Reject the first byte past the $FFFF overflow. .ORG $FFFF; one 1-byte
; instruction succeeds (as pcEndAtFFFF proves) and leaves the overflow latch
; set; a second 1-byte instruction must now fail with
; CASM_DIAG_ADDRESS_OVERFLOW before writing anything (emitByte's own
; CasmPcOverflow gate, checked before emitRawByte) -- this diagnostic is
; itself the proof the latch was set, since emitByte's gate is the only
; thing that can produce it.
; ---------------------------------------------------------------------------
pcRejectOverflow:
    ldx #<$FFFF
    ldy #>$FFFF
    jsr setOrg
    bcs proFail
    jsr oneByteCase
    bcs proFail
    jsr oneByteCase
    bcc proFail             ; must fail -- success here is the fixture failure
    cmp #CASM_DIAG_ADDRESS_OVERFLOW
    bne proFail
    clc
    rts
proFail:
    sec
    rts

; ---------------------------------------------------------------------------
; pcRepeatReset
; No leaked CasmPc across runs without a following .ORG. .ORG $FFFF; one
; 1-byte instruction leaves CasmPc=$0000 (as pcEndAtFFFF proves); a fresh
; emitInit (simulating the next assembly run, no .ORG yet) must reprime
; CasmPc to CASM_DEFAULT_ORIGIN, not inherit the prior run's final wrapped
; state. Requires CasmCliOptions genuinely 0 (not static) at this point --
; explicitly zeroed in start: below rather than trusted to BSS's initial
; content, since .res does not guarantee zeroed memory on a real load (this
; exact class of assumption is what produced the CasmPcOverflow/
; CasmOutputStarted false results this file already hit and removed above).
; Does not assert an overflow latch for the same not-exported reason as
; pcEndAtFFFF; CasmPc reaching the real default origin is sufficient
; evidence emitInit's priming ran cleanly.
; ---------------------------------------------------------------------------
pcRepeatReset:
    ldx #<$FFFF
    ldy #>$FFFF
    jsr setOrg
    bcs prrFail
    jsr oneByteCase
    bcs prrFail
    jsr emitInit
    lda CasmPc
    cmp #<CASM_DEFAULT_ORIGIN
    bne prrFail
    lda CasmPc + 1
    cmp #>CASM_DEFAULT_ORIGIN
    bne prrFail
    clc
    rts
prrFail:
    sec
    rts

; ---------------------------------------------------------------------------
; diagSetLocFromStmt / diagSetLocFromToken / diagClearLoc (local stand-ins)
; No test case in this harness inspects diagnostic *location* (only the
; diagnostic code and CasmPc state), so these record nothing -- they exist
; solely to satisfy emit.s's linker references without pulling in
; diagnostics.s's transitive lexer.s/parser.s state, matching
; casm_opcodes.s's own diagSetLocFromStmt-stub precedent.
; ---------------------------------------------------------------------------
diagSetLocFromStmt:
diagSetLocFromToken:
diagClearLoc:
    rts

; ---------------------------------------------------------------------------
; lexerNext / parserParseExpressionValue (local stand-ins)
; Only reachable from emitDirective's .BYTE/.WORD-list paths, which this
; harness never invokes (every case uses .ORG or a direct instruction
; record). Return C clear defensively rather than leaving them unreachable
; stubs that would mask a future accidental call with silent success.
; ---------------------------------------------------------------------------
lexerNext:
parserParseExpressionValue:
    clc
    rts

; ---------------------------------------------------------------------------
; inputStreamOpen / inputStreamRead / inputStreamClose (local stand-ins,
; WP82)
; Only reachable from emitDirective's .INCBIN path, which this harness
; never invokes. Same defensive-C-clear precedent as lexerNext above.
; ---------------------------------------------------------------------------
inputStreamOpen:
inputStreamRead:
inputStreamClose:
    clc
    rts

; ---------------------------------------------------------------------------
; relocRecord (local stand-in)
; Only reachable when CASM_PARSER_STMT_RELOCATABLE is set, which no case
; here ever sets (every CasmParserStmt.Flags stays 0).
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
    .byte "CASM BOUNDS: PASS", PetCr, 0
failMsg:
    .byte "CASM BOUNDS: FAIL", PetCr, 0
