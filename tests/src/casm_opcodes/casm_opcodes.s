; tests/src/casm_opcodes/casm_opcodes.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 11 WP60 Increment 4: direct 151-tuple opcode/mode matcher
; harness. Links real opcodes.s only and feeds CasmParserStmt records
; directly, bypassing parser.s/lexer.s entirely -- proves
; opcodesFindOpcode's own mode-resolution/range-check/opcode-selection logic
; in isolation, independent of what the real parser would produce for any
; given source text (that pipeline-level proof is WP60 Increment 6/7's job).
;
; legalCases holds exactly the 151 legal mnemonic/mode tuples independently
; authored in
; brain/reviews/2026-08-12-casm-phase11-wp60-increment1-opcode-oracle.md
; (same data, transcribed into CasmParserStmt input shape plus expected
; opcode/mode/length). A 151-bit coverage bitmap (CoverageBitmap, 19 bytes)
; proves every one of the 151 tuples runs exactly once: bitmapSetCheck fails
; a case outright if its bit is already set (duplicate), and verifyBitmapFull
; fails the run if the final popcount isn't exactly 151 (missing).
;
; focusedCases exercises unsupported-mode rejection, 8-bit range accept/
; reject at $00/$FF/$0100 for Immediate/(Ind,X)/(Ind),Y, ZP/Absolute
; literal-magnitude selection at $00/$FF/$0100/$FFFF, FORCE_ABS zero-page-
; shrink prevention, independent ZP,X/ZP,Y promotion (including the
; LDX/STX/LDY/STY X<->Y role swap), all eight branches resolving to
; Relative with an unconstrained 16-bit target, and Implied/Accumulator
; distinctness. It reuses the same 10-byte case record as legalCases, with
; BitmapIdx = $FF marking "not part of the 151-tuple bitmap."
;
; diagSetLocFromStmt is stubbed locally (records only that the call
; happened) rather than linking the real diagnostics.s: that module pulls in
; CasmStmtLoc*/CasmTokenRecord state from lexer.s/parser.s transitively,
; which this harness must not link per the plan. CasmParserStmt is also
; declared locally (opcodes.s only .imports it) so the harness can populate
; it directly -- matches casm_symbols.s's/casm_expr.s's established
; precedent of locally stubbing a symbol solely to satisfy the linker
; without dragging in unrelated subsystems.
;
; Every check against a same-routine Fail label uses an inverted short
; branch over an inline JMP (ca65 unnamed labels, :/:+) is unnecessary here
; -- runOneCase's own body stays within short-branch range throughout, so
; ordinary named labels are used, matching casm_expr.s's simpler style for
; a single-pass per-case routine (as opposed to casm_symbols.s's long
; sequential fixtures, which do need the inverted-branch idiom).

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_opcodes.inc"

.import __MAIN_START__
.import opcodesFindOpcode
.import CasmInsn

.export CasmParserStmt
.export diagSetLocFromStmt

; Zero-page case-table walking pointer. $72/$73 matches casm_expr.s's own
; TableLo/TableHi choice; safe here regardless since expr.s is not linked
; into this harness. opcodesFindOpcode's own scratch (CasmExprScratch0-3,
; $84-$87) is a disjoint range, so this pointer survives every call.
CaseTableLo = $72
CaseTableHi = $73

; Case record layout (10 bytes), shared by legalCases and focusedCases:
CASE_SUBTYPE     = 0   ; mnemonic subtype 0-55
CASE_OPKIND      = 1   ; CASM_OPKIND_* fed to CasmParserStmt
CASE_VAL_LO      = 2
CASE_VAL_HI      = 3
CASE_FLAGS       = 4   ; CASM_PARSER_STMT_FLAGS input (FORCE_ABS etc.)
CASE_EXPECT_DIAG = 5   ; 0 = expect success; nonzero = expected diagnostic
CASE_EXPECT_MODE = 6   ; valid only when EXPECT_DIAG = 0
CASE_EXPECT_OP   = 7   ; valid only when EXPECT_DIAG = 0
CASE_EXPECT_LEN  = 8   ; valid only when EXPECT_DIAG = 0
CASE_BITMAP_IDX  = 9   ; 0-150, or $FF = not part of the 151-tuple bitmap
CASE_SIZE        = 10

.segment "HEADER"
    .word __MAIN_START__

.segment "BSS"
CasmParserStmt: .res CASM_PARSER_STMT_SIZE
StmtBefore:     .res CASM_PARSER_STMT_SIZE
FailCount:      .res 1
DiagLocStamped: .res 1
CoverageBitmap: .res 19        ; 151 required bits fit in 19*8 = 152 bits
CaseTableEndLo: .res 1
CaseTableEndHi: .res 1
SpBefore:       .res 1
ActualDiag:     .res 1         ; A on return from opcodesFindOpcode
ActualCarrySet: .res 1         ; 1 if carry was set (failure), else 0
BitMaskCur:     .res 1
PopcountLo:     .res 1

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda #0
    sta FailCount
    ldy #0
clearBitmap:
    sta CoverageBitmap, y
    iny
    cpy #19
    bne clearBitmap

    lda #<legalCases
    sta CaseTableLo
    lda #>legalCases
    sta CaseTableHi
    lda #<legalCasesEnd
    sta CaseTableEndLo
    lda #>legalCasesEnd
    sta CaseTableEndHi
    jsr runCaseTable

    lda #<focusedCases
    sta CaseTableLo
    lda #>focusedCases
    sta CaseTableHi
    lda #<focusedCasesEnd
    sta CaseTableEndLo
    lda #>focusedCasesEnd
    sta CaseTableEndHi
    jsr runCaseTable

    jsr verifyBitmapFull

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
; diagSetLocFromStmt (local stand-in for opcodesFindOpcode's only
; diagnostic-location dependency)
; Inputs:    none
; Outputs:   DiagLocStamped = 1
; Preserves: X, Y
; Clobbers:  A, processor flags -- matches the real routine's contract
; ---------------------------------------------------------------------------
diagSetLocFromStmt:
    lda #1
    sta DiagLocStamped
    rts

; ---------------------------------------------------------------------------
; runCaseTable
; Walk a CASE_SIZE-byte-record table from CaseTableLo/Hi (inclusive) to
; CaseTableEndLo/Hi (exclusive), running each record through runOneCase and
; printing '.'/'F' per case.
; ---------------------------------------------------------------------------
runCaseTable:
rctLoop:
    lda CaseTableLo
    cmp CaseTableEndLo
    bne rctRun
    lda CaseTableHi
    cmp CaseTableEndHi
    beq rctDone
rctRun:
    jsr runOneCase
    bcc rctPass
    inc FailCount
    lda #$46
    jsr KernalChROUT
    jmp rctNext
rctPass:
    lda #$2E
    jsr KernalChROUT
rctNext:
    clc
    lda CaseTableLo
    adc #CASE_SIZE
    sta CaseTableLo
    lda CaseTableHi
    adc #0
    sta CaseTableHi
    jmp rctLoop
rctDone:
    rts

; ---------------------------------------------------------------------------
; runOneCase
; Populate CasmParserStmt from the case record at (CaseTableLo), call
; opcodesFindOpcode, and assert its full contract: opcode/mode/length or
; diagnostic, A/carry, CasmParserStmt preservation, stack balance, location
; stamping on failure, and (for legal tuples) coverage-bitmap bookkeeping.
; Outputs: C clear = case passed; C set = case failed
; ---------------------------------------------------------------------------
runOneCase:
    ldy #CASE_SUBTYPE
    lda (CaseTableLo), y
    sta CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    ldy #CASE_OPKIND
    lda (CaseTableLo), y
    sta CasmParserStmt + CASM_PARSER_STMT_OPKIND
    ldy #CASE_VAL_LO
    lda (CaseTableLo), y
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_LO
    ldy #CASE_VAL_HI
    lda (CaseTableLo), y
    sta CasmParserStmt + CASM_PARSER_STMT_VAL_HI
    ldy #CASE_FLAGS
    lda (CaseTableLo), y
    sta CasmParserStmt + CASM_PARSER_STMT_FLAGS
    lda #0
    sta CasmParserStmt + CASM_PARSER_STMT_TYPE
    sta CasmParserStmt + CASM_PARSER_STMT_REG_SUBTYPE

    ldy #0
rocCopyBefore:
    lda CasmParserStmt, y
    sta StmtBefore, y
    iny
    cpy #CASM_PARSER_STMT_SIZE
    bne rocCopyBefore

    lda #0
    sta DiagLocStamped

    tsx
    stx SpBefore

    jsr opcodesFindOpcode
    sta ActualDiag          ; STA does not disturb carry
    lda #0
    rol a                   ; A = 1 if carry was set, else 0; carry cleared
    sta ActualCarrySet

    tsx
    cpx SpBefore
    beq rocSpOk
    sec
    rts
rocSpOk:

    ldy #0
rocCmpLoop:
    lda CasmParserStmt, y
    cmp StmtBefore, y
    bne rocFail
    iny
    cpy #CASM_PARSER_STMT_SIZE
    bne rocCmpLoop

    ldy #CASE_EXPECT_DIAG
    lda (CaseTableLo), y
    bne rocExpectFail

    ; --- expect success ---
    lda ActualCarrySet
    bne rocFail
    ldy #CASE_EXPECT_OP
    lda (CaseTableLo), y
    cmp ActualDiag
    bne rocFail
    lda CasmInsn + CASM_INSN_OPCODE
    ldy #CASE_EXPECT_OP
    cmp (CaseTableLo), y
    bne rocFail
    lda CasmInsn + CASM_INSN_MODE
    ldy #CASE_EXPECT_MODE
    cmp (CaseTableLo), y
    bne rocFail
    lda CasmInsn + CASM_INSN_LENGTH
    ldy #CASE_EXPECT_LEN
    cmp (CaseTableLo), y
    bne rocFail

    ldy #CASE_BITMAP_IDX
    lda (CaseTableLo), y
    cmp #$FF
    beq rocOkDone
    jsr bitmapSetCheck
    bcs rocFail
    jmp rocOkDone

rocExpectFail:
    ; --- expect failure ---
    lda ActualCarrySet
    beq rocFail
    ldy #CASE_EXPECT_DIAG
    lda (CaseTableLo), y
    cmp ActualDiag
    bne rocFail
    lda DiagLocStamped
    beq rocFail

rocOkDone:
    clc
    rts
rocFail:
    sec
    rts

; ---------------------------------------------------------------------------
; bitmapSetCheck
; Inputs:  A = bitmap index (0-150)
; Outputs: C clear and the bit set, if it was previously clear; C set
;          (duplicate) if the bit was already set. The bit is NOT modified
;          on the duplicate path, so a duplicate is reported exactly once.
; Clobbers: A, X
; ---------------------------------------------------------------------------
bitmapSetCheck:
    pha
    and #%00000111
    tax
    lda bitPosTable, x
    sta BitMaskCur
    pla
    lsr a
    lsr a
    lsr a
    tax
    lda CoverageBitmap, x
    and BitMaskCur
    bne bscDup
    lda CoverageBitmap, x
    ora BitMaskCur
    sta CoverageBitmap, x
    clc
    rts
bscDup:
    sec
    rts

; ---------------------------------------------------------------------------
; verifyBitmapFull
; Independently re-derives coverage from CoverageBitmap's raw bytes (not
; from a running counter kept alongside bitmapSetCheck) and requires the
; popcount across all 19 bytes to be exactly 151. Any legal tuple that
; failed its own assertions never reached bitmapSetCheck's set path, so a
; failed case shows up here too, as a missing bit -- independent of
; FailCount.
; ---------------------------------------------------------------------------
verifyBitmapFull:
    lda #0
    sta PopcountLo
    ldx #0
vbfByteLoop:
    cpx #19
    beq vbfByteDone
    lda CoverageBitmap, x
    ldy #8
vbfBitLoop:
    lsr a
    bcc vbfNoBit
    inc PopcountLo
vbfNoBit:
    dey
    bne vbfBitLoop
    inx
    jmp vbfByteLoop
vbfByteDone:
    lda PopcountLo
    cmp #151
    beq vbfOk
    inc FailCount
    lda #$3F
    jsr KernalChROUT
vbfOk:
    rts

.segment "RODATA"

bitPosTable:
    .byte 1, 2, 4, 8, 16, 32, 64, 128

; 151 independently authored legal tuples, in mnemonic-subtype/ascending-
; CASM_MODE_* order (same order and values as
; brain/reviews/2026-08-12-casm-phase11-wp60-increment1-opcode-oracle.md).
legalCases:
.include "casm_opcodes_legal.inc"
legalCasesEnd:

.assert (legalCasesEnd - legalCases) = 151 * CASE_SIZE, error, "WP60 opcode harness: legal tuple count changed from 151"
.assert CASM_MNEMONIC_COUNT = 56, error, "WP60 opcode harness: mnemonic count changed from 56"
.assert CASM_MODE_COUNT = 13, error, "WP60 opcode harness: mode count changed from 13"
.assert CASE_SIZE = 10, error, "WP60 opcode harness: case record size changed"

; Focused unsupported-mode/8-bit-range/selection/FORCE_ABS/ZPX-ZPY/branch/
; implied-accumulator cases. See the file header for the full bullet list.
focusedCases:
.include "casm_opcodes_focused.inc"
focusedCasesEnd:

passMsg:
    .byte "CASM OPCODES: PASS", PetCr, 0
failMsg:
    .byte "CASM OPCODES: FAIL", PetCr, 0
