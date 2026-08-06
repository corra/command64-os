; tests/src/casm_frame/casm_frame.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 9 WP46 frame stack, nested traversal, and cycle
; detection fixture harness. Links include.s plus the same whole-object
; surface as test_casm_pass1.s (fileio.s, source.s, state.s, lexer.s,
; parser.s, opcodes.s, emit.s, expr.s, diagnostics.s, resources.s,
; vmm_store.s, symbols.s, reloc.s) -- real diagnostics.s this time, not a
; stubbed diagPrintFatal like test_casm_catalog.s, because several cases
; here directly inspect the real diagnostic echo-buffer bookkeeping
; (CasmDiagPrevNoLo/Hi, CasmDiagPrevLen/Clipped).
; Deliberately not cli.s (its own single/double-slot stand-in copies of
; CasmSourceNames/CasmSourceCount/cliSourceSlotLo/Hi below, matching
; test_casm_pass1.s's/test_casm_catalog.s's own precedent exactly) or
; casm.s (owns its own HEADER/entry point).
;
; This harness's own driver loop calls parserParseStatement directly and,
; on a parsed .INCLUDE statement, manually performs what WP47's real
; production dispatch will eventually do: resolve the operand through
; include.s's includeCatalogLoad, read the resulting record's start/length
; out of CasmIncludeRecordStage, and call source.s's sourceFramePush --
; proving the exact sequence a real future caller will use, without
; needing casmRunPass itself. sourceFramePush has no casmRunPass call site
; anywhere in production; only this harness calls it.
;
; Fixtures (cmake/GenerateCasmTestFixtures.cmake, packaged on
; casm_overflow_test_d64 under bare lowercase disk names, matching the
; established cc1541/ca65 case-pairing convention -- deliberately not the
; ".S"-suffixed CASM-source-fixture convention test_image_d64 uses, even
; though this content is real CASM syntax: these fixtures reference each
; other by exact operand text, and bare names exactly replicate WP45's
; own already-proven-correct pairing rather than risk a second naming
; mismatch):
;   casmfrp1.seq / casmfrc1.seq       -- single push/pop
;   casmfrp2.seq / casmfrc2.seq / casmfrc3.seq -- three-level nesting
;   casmfrp3.seq (reuses casmfrc1.seq twice)   -- sequential reinclusion
;   casmfrp4.seq / casmfrcr1.seq      -- pending-CR boundary
;   casmfrr1.seq / casmfrr2.seq       -- two top-level files, no includes
;
; Every real-load case reads the actual CurrentDevice ($039E) at startup
; into TestDevice rather than assuming a fixed device number -- see
; test_casm_catalog.s's own header and brain memory
; project-vice-two-drive-test-setup for why.
;
; Depth-exceeded and cycle-detection cases are exercised synthetically
; (direct sourceFramePush calls with fabricated catalog indices and
; arbitrary start/end offsets), never traversed for real -- mirrors
; test_casm_catalog.s's own precedent of pre-populating synthetic catalog
; records directly rather than requiring 16+ real distinct fixture files.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_frame.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import fileIoInit
.import sourceInit
.import sourceLoad
.import sourceOpen
.import sourceClose
.import sourceFramePush
.import CasmFrameDepth
.import includeCatalogInit
.import includeCatalogLoad
.import CasmIncludeRecordStage
.import lexerInit
.import parserParseStatement
.import CasmParserStmt
.import CasmIncludeFilename
.import CasmIncludeFilenameLen
.import CasmStmtLocLineLo
.import CasmStmtLocLineHi
.import CasmDiagLineNoLo
.import CasmDiagLineNoHi
.import CasmDiagPrevNoLo
.import CasmDiagPrevNoHi
.import CasmDiagPrevLen
.import CasmDiagPrevClipped
.import CasmDiagLocByte

.export CasmSourceNames  ; this harness's own copy -- NOT linking cli.s, see header
.export CasmSourceLens   ; unused by sourceLoad (per-file lengths are cli.s's
                          ; own concept, never read here) but declared so
                          ; cliDeriveOutputName-shaped references, if any,
                          ; still resolve -- harmless, zero-initialized
.export CasmSourceCount  ; this harness's own copy -- 1 or 2 depending on the case
.export cliSourceSlotLo  ; this harness's own two-entry copy, see BSS section
.export cliSourceSlotHi
.export CasmOutputName   ; fileio.s's outputAbort references this by name
.export CasmListingName  ; listing.s's WP53 file I/O references these
.export CasmListingLen
.export CasmCliOptions   ; emit.s reads this; harness's own zero-initialized
                          ; copy, matching test_casm_pass1.s's own precedent

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    ; Capture the real CurrentDevice once, before anything else runs --
    ; see file header.
    lda CurrentDevice
    sta TestDevice
    jsr resourcesInit
    jsr fileIoInit
    jsr sourceInit
    lda #0
    sta FailCount

    ldx #<pFrp1Name
    ldy #>pFrp1Name
    jsr frSinglePushPop
    jsr reportCase
    jsr resourcesCleanup

    ldx #<pFrp2Name
    ldy #>pFrp2Name
    jsr frNestedPushPop
    jsr reportCase
    jsr resourcesCleanup

    ldx #<pFrp3Name
    ldy #>pFrp3Name
    jsr frSequentialReinclusion
    jsr reportCase
    jsr resourcesCleanup

    ldx #<pFrp4Name
    ldy #>pFrp4Name
    jsr frPendingCrBoundary
    jsr reportCase
    jsr resourcesCleanup

    jsr frRootBoundaryEchoReset
    jsr reportCase
    jsr resourcesCleanup

    jsr frDepthExceeded
    jsr reportCase

    jsr frDirectCycle
    jsr reportCase

    jsr frIndirectCycle
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

seedFailed:
    lda #<seedFailMsg
    ldy #>seedFailMsg
    tax
    lda #DOS_PRINT_STR
    jsr OS_API
    lda #DOS_EXIT
    jsr OS_API

; ---------------------------------------------------------------------------
; reportCase
; Print '.' for a pass (carry clear) or 'F' for a fail (carry set), tallying
; FailCount.
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
; runFrameTraversal (shared driver)
; Load exactly one top-level file (X/Y = its filename pointer) and drive
; real statement-level traversal to EOF, logging every label statement's
; own line number into CasmFrLogLo/Hi (up to CASM_FR_LOG_MAX entries) and
; manually performing frame push on every parsed .INCLUDE statement --
; the same sequence WP47's real dispatch will eventually use.
;
; Inputs:    X/Y = top-level filename pointer (null-terminated PETSCII)
; Outputs:   C clear with CasmFrLogLen entries logged, reached real EOF,
;            CasmFrameDepth back to 0; source closed (CLOSED state)
;            C set with A = CASM_DIAG_* on any unexpected failure (parse
;            error, catalog-load failure, or frame-push rejection)
; Clobbers:  A, X, Y and the full source/lexer/parser/catalog/frame call
;            chain's documented volatile state
; ---------------------------------------------------------------------------
runFrameTraversal:
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldy #0
rftCopyLoop:
    lda (CasmPtr1Lo), y
    sta CasmSourceNames, y
    beq rftCopyDone
    iny
    cpy #CASM_FILENAME_BUFFER_SIZE
    bcc rftCopyLoop
rftCopyDone:
    lda #1
    sta CasmSourceCount

    jsr sourceLoad
    bcc rftLoadOk
    jmp rftFail
rftLoadOk:
    jsr sourceOpen
    bcs rftFailNear
    jsr includeCatalogInit
    bcs rftFailNear
    jsr lexerInit
    bcs rftFailNear
    lda #0
    sta CasmFrLogLen

rftLoop:
    jsr parserParseStatement
    bcs rftFailNear
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    cmp #CASM_TOKEN_EOF
    beq rftDoneNear
    cmp #CASM_TOKEN_IDENTIFIER
    beq rftLabel
    cmp #CASM_TOKEN_DIRECTIVE
    beq rftDirective
    jmp rftLoop                  ; NEWLINE or anything else: skip

rftLabel:
    ldx CasmFrLogLen
    cpx #CASM_FR_LOG_MAX
    bcs rftFailNear              ; more labels than the log can hold -- a
                                  ; fixture-authoring bug, not a real case
    lda CasmStmtLocLineLo
    sta CasmFrLogLo, x
    lda CasmStmtLocLineHi
    sta CasmFrLogHi, x
    inc CasmFrLogLen
    jmp rftLoop

rftDirective:
    lda CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    cmp #CASM_DIRECTIVE_INCLUDE
    bne rftLoop                  ; not reachable by these fixtures; safe no-op

    lda TestDevice
    ldx #<CasmIncludeFilename
    ldy #>CasmIncludeFilename
    jsr includeCatalogLoad
    bcs rftFailNear

    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_LO
    sta CasmValue0Lo
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_HI
    sta CasmValue0Hi
    clc
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_LO
    adc CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_LENGTH_LO
    sta CasmValue1Lo
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_HI
    adc CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_LENGTH_HI
    sta CasmValue1Hi

    txa                          ; X still holds the catalog record index
    jsr sourceFramePush
    bcs rftFailNear
    jmp rftLoop

rftDoneNear:
    jmp rftDone
rftFailNear:
    jmp rftFail

rftDone:
    jsr sourceClose
    bcs rftFail
    clc
    rts
rftFail:
    rts                          ; A/C already set by the failing call

; ---------------------------------------------------------------------------
; frSinglePushPop: casmfrp1.seq (P1/P2/.INCLUDE/P3/P4) includes casmfrc1.seq
; (C1/C2) once. Expect the label log 1,2,1,2,4,5 (parent's own numbering
; resumes correctly after the child's automatic pop) and depth back to 0.
; ---------------------------------------------------------------------------
frSinglePushPop:
    jsr runFrameTraversal
    bcs fs1Fail
    lda CasmFrameDepth
    bne fs1Fail
    lda CasmFrLogLen
    cmp #6
    bne fs1Fail
    ldx #0
    lda #<expectSingle
    sta CasmPtr1Lo
    lda #>expectSingle
    sta CasmPtr1Hi
    jsr frCompareLog
    bcs fs1Fail
    clc
    rts
fs1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; frNestedPushPop: casmfrp2.seq includes casmfrc2.seq, which itself
; includes casmfrc3.seq. Expect the label log 1,1,1,2,3,3 (cascading push,
; then cascading automatic pop back through both levels) and depth 0.
; ---------------------------------------------------------------------------
frNestedPushPop:
    jsr runFrameTraversal
    bcs fn1Fail
    lda CasmFrameDepth
    bne fn1Fail
    lda CasmFrLogLen
    cmp #6
    bne fn1Fail
    lda #<expectNested
    sta CasmPtr1Lo
    lda #>expectNested
    sta CasmPtr1Hi
    jsr frCompareLog
    bcs fn1Fail
    clc
    rts
fn1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; frSequentialReinclusion: casmfrp3.seq includes casmfrc1.seq twice from
; two different .INCLUDE sites, the second one after the first frame has
; already popped. Expect the label log 1,1,2,3,1,2,5 -- the second
; .INCLUDE must be a deduplicated cache hit (Phase 0C.19) reusing the same
; physical bytes, and must not be rejected as a cycle (it is no longer on
; the active chain by the time it is re-encountered).
; ---------------------------------------------------------------------------
frSequentialReinclusion:
    jsr runFrameTraversal
    bcs fsr1Fail
    lda CasmFrameDepth
    bne fsr1Fail
    lda CasmFrLogLen
    cmp #7
    bne fsr1Fail
    lda #<expectSequential
    sta CasmPtr1Lo
    lda #>expectSequential
    sta CasmPtr1Hi
    jsr frCompareLog
    bcs fsr1Fail
    clc
    rts
fsr1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; frPendingCrBoundary: casmfrp4.seq includes casmfrcr1.seq, which ends in a
; bare CR (no trailing LF) as its very last byte. casmfrp4.seq resumes with
; a blank line (a lone LF) immediately after the .INCLUDE. Expect the label
; log 1,1,4: P1(line1), C1(line1, the CR-terminated child label), P3(line4
; -- NOT line3, which is what a wrongly-collapsed CRLF spanning the frame
; boundary would produce, losing the blank line).
; ---------------------------------------------------------------------------
frPendingCrBoundary:
    jsr runFrameTraversal
    bcs fpc1Fail
    lda CasmFrameDepth
    bne fpc1Fail
    lda CasmFrLogLen
    cmp #3
    bne fpc1Fail
    lda #<expectPendingCr
    sta CasmPtr1Lo
    lda #>expectPendingCr
    sta CasmPtr1Hi
    jsr frCompareLog
    bcs fpc1Fail
    clc
    rts
fpc1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; frRootBoundaryEchoReset: two top-level files (casmfrr1.seq/casmfrr2.seq,
; no includes at all), each one line, sharing line number 1. Proves the
; pre-existing WP34 echo-identity gap fix: crossing the root boundary
; between them must reset the diagnostic echo bookkeeping the same way a
; frame push/pop does. Verified directly against the exported echo-state
; fields (CASM_DIAG_LINE_NONE = 0) rather than rendering real output.
;
; Only the PREVIOUS-line fields (CasmDiagPrevNoLo/Hi, CasmDiagPrevLen,
; CasmDiagPrevClipped) are checked, not CasmDiagLineLen/CasmDiagLineClipped:
; by the time parserParseStatement returns having recognized file 2's own
; label, the lexer has already fetched and echoed that label's own bytes
; ("R2:") into the CURRENT buffer via source.s's snbByteReturn (every
; delivered byte is echoed unconditionally, independent of any diagnostic
; ever firing) -- so CasmDiagLineLen is expected to be non-zero at this
; observation point, and asserting it were zero could never pass regardless
; of whether the boundary-echo reset itself is correct.
; ---------------------------------------------------------------------------
frRootBoundaryEchoReset:
    ldx #<pFrr1Name
    ldy #>pFrr1Name
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldy #0
frr1CopyLoop1:
    lda (CasmPtr1Lo), y
    sta CasmSourceNames, y
    beq frr1CopyDone1
    iny
    cpy #CASM_FILENAME_BUFFER_SIZE
    bcc frr1CopyLoop1
frr1CopyDone1:
    ldx #<pFrr2Name
    ldy #>pFrr2Name
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldy #0
frr1CopyLoop2:
    lda (CasmPtr1Lo), y
    sta CasmSourceNames + CASM_FILENAME_BUFFER_SIZE, y
    beq frr1CopyDone2
    iny
    cpy #CASM_FILENAME_BUFFER_SIZE
    bcc frr1CopyLoop2
frr1CopyDone2:
    lda #2
    sta CasmSourceCount

    jsr sourceLoad
    bcc frr1LoadOk
    jmp frr1Fail
frr1LoadOk:
    jsr sourceOpen
    bcs frr1FailNear
    jsr lexerInit
    bcs frr1FailNear

frr1Loop:
    jsr parserParseStatement
    bcs frr1FailNear
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    cmp #CASM_TOKEN_EOF
    beq frr1EofNear
    cmp #CASM_TOKEN_IDENTIFIER
    bne frr1Loop
    ; A label: if this is the SECOND file's own label (file 2's line 1,
    ; recognized simply by CasmFrLogLen already having one entry from file
    ; 1's own label), check the echo-reset fields right here, immediately
    ; after crossing the root boundary.
    ldx CasmFrLogLen
    cpx #0
    bne frr1CheckEcho
    ; First label (file 1): just record that we've seen it.
    inc CasmFrLogLen
    jmp frr1Loop
frr1CheckEcho:
    lda CasmDiagPrevNoLo
    ora CasmDiagPrevNoHi
    bne frr1FailNear             ; must be the CASM_DIAG_LINE_NONE sentinel (0)
    lda CasmDiagPrevLen
    bne frr1FailNear             ; no stale "previous line" content survived
    lda CasmDiagPrevClipped
    bne frr1FailNear
    jmp frr1Done

frr1EofNear:
    jmp frr1Eof
frr1FailNear:
    jmp frr1Fail

frr1Eof:
    ; Reached EOF without ever seeing the second file's label -- the root
    ; transition never happened as expected.
    jsr sourceClose
    sec
    rts

frr1Done:
    jsr sourceClose
    bcs frr1Fail
    clc
    rts
frr1Fail:
    sec
    rts








; ---------------------------------------------------------------------------
; frCompareLog (private)
; Compare CasmFrLogLo/Hi[0 .. CasmFrLogLen-1] against a null-terminated
; (0,0-sentinel) table of expected 16-bit line numbers pointed to by
; CasmPtr1Lo/Hi.
;
; Inputs:    CasmFrLogLen, CasmFrLogLo/Hi already populated;
;            CasmPtr1Lo/Hi = expected-value table pointer
; Outputs:   C clear if every entry matches; C set otherwise
; Clobbers:  A, X, Y
; ---------------------------------------------------------------------------
frCompareLog:
    ldx #0
fclLoop:
    cpx CasmFrLogLen
    beq fclDone
    txa
    asl
    tay
    lda (CasmPtr1Lo), y
    cmp CasmFrLogLo, x
    bne fclMismatch
    iny
    lda (CasmPtr1Lo), y
    cmp CasmFrLogHi, x
    bne fclMismatch
    inx
    jmp fclLoop
fclDone:
    clc
    rts
fclMismatch:
    sec
    rts

; ---------------------------------------------------------------------------
; frDepthExceeded: 16 synthetic pushes (distinct fabricated catalog indices,
; arbitrary start/end offsets -- never traversed for real) must all
; succeed; the 17th must fail with CASM_DIAG_INCLUDE_DEPTH_EXCEEDED and
; leave CasmFrameDepth unchanged at 16.
; ---------------------------------------------------------------------------
frDepthExceeded:
    lda #0
    sta CasmFrameDepth
    sta CasmFrSynthIndex
    lda #0
    sta CasmValue0Lo
    sta CasmValue0Hi
    lda #1
    sta CasmValue1Lo
    lda #0
    sta CasmValue1Hi
fde1Loop:
    lda CasmFrSynthIndex
    cmp #CASM_INCLUDE_MAX_DEPTH
    bcs fde1TryOverflow
    jsr sourceFramePush
    bcs fde1Fail
    inc CasmFrSynthIndex
    jmp fde1Loop
fde1TryOverflow:
    lda #CASM_INCLUDE_MAX_DEPTH   ; a 17th distinct fabricated index
    jsr sourceFramePush
    bcc fde1Fail                  ; must fail
    cmp #CASM_DIAG_INCLUDE_DEPTH_EXCEEDED
    bne fde1Fail
    lda CasmFrameDepth
    cmp #CASM_INCLUDE_MAX_DEPTH
    bne fde1Fail
    clc
    rts
fde1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; frDirectCycle: push a fabricated catalog index, then push the SAME index
; again immediately -- must fail with CASM_DIAG_INCLUDE_CYCLE_DETECTED.
; ---------------------------------------------------------------------------
frDirectCycle:
    lda #0
    sta CasmFrameDepth
    sta CasmValue0Lo
    sta CasmValue0Hi
    lda #1
    sta CasmValue1Lo
    lda #0
    sta CasmValue1Hi
    lda #5
    jsr sourceFramePush
    bcs fdc1Fail
    lda #5
    jsr sourceFramePush
    bcc fdc1Fail                  ; must fail
    cmp #CASM_DIAG_INCLUDE_CYCLE_DETECTED
    bne fdc1Fail
    clc
    rts
fdc1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; frIndirectCycle: push index 5, push index 7, then push index 5 again --
; must still fail with CASM_DIAG_INCLUDE_CYCLE_DETECTED (the active-chain
; scan must find a match at any depth, not only the topmost).
; ---------------------------------------------------------------------------
frIndirectCycle:
    lda #0
    sta CasmFrameDepth
    sta CasmValue0Lo
    sta CasmValue0Hi
    lda #1
    sta CasmValue1Lo
    lda #0
    sta CasmValue1Hi
    lda #5
    jsr sourceFramePush
    bcs fic1Fail
    lda #7
    jsr sourceFramePush
    bcs fic1Fail
    lda #5
    jsr sourceFramePush
    bcc fic1Fail                  ; must fail
    cmp #CASM_DIAG_INCLUDE_CYCLE_DETECTED
    bne fic1Fail
    clc
    rts
fic1Fail:
    sec
    rts

.segment "RODATA"

pFrp1Name: .byte "CASMFRP1", 0
pFrp2Name: .byte "CASMFRP2", 0
pFrp3Name: .byte "CASMFRP3", 0
pFrp4Name: .byte "CASMFRP4", 0
pFrr1Name: .byte "CASMFRR1", 0
pFrr2Name: .byte "CASMFRR2", 0

; Expected label-line sequences (16-bit little-endian pairs), matching
; frCompareLog's own indexing convention.
expectSingle:
    .word 1, 2, 1, 2, 4, 5
expectNested:
    .word 1, 1, 1, 2, 3, 3
expectSequential:
    .word 1, 1, 2, 3, 1, 2, 5
expectPendingCr:
    .word 1, 1, 4

passMsg: .byte "CASM FRAME: PASS", $0D, 0
failMsg: .byte "CASM FRAME: FAIL", $0D, 0
seedFailMsg: .byte "CASM FRAME: SEED LOAD FAILED", $0D, 0

.segment "BSS"

FailCount:       .res 1
TestDevice:      .res 1
CasmFrSynthIndex: .res 1

CASM_FR_LOG_MAX = 8
CasmFrLogLen: .res 1
CasmFrLogLo:  .res CASM_FR_LOG_MAX
CasmFrLogHi:  .res CASM_FR_LOG_MAX

; This harness's own two-slot stand-in for cli.s's WP34 multi-file arrays
; -- see header. Most cases use only slot 0 (CasmSourceCount = 1);
; frRootBoundaryEchoReset uses both (CasmSourceCount = 2).
CasmSourceNames: .res CASM_FILENAME_BUFFER_SIZE * 2
CasmSourceLens:  .res 2
CasmSourceCount: .res 1
CasmOutputName:  .res CASM_FILENAME_BUFFER_SIZE
CasmCliOptions:  .res 1
; WP53 increment 4: listing.s's new `.LST` file I/O (linked whole, unused
; by this harness) references these (cli.s), which this harness does not
; link either.
CasmListingName: .res CASM_FILENAME_BUFFER_SIZE
CasmListingLen:  .res 1

.segment "RODATA"

cliSourceSlotLo:
    .byte <(CasmSourceNames + 0), <(CasmSourceNames + CASM_FILENAME_BUFFER_SIZE)
cliSourceSlotHi:
    .byte >(CasmSourceNames + 0), >(CasmSourceNames + CASM_FILENAME_BUFFER_SIZE)
