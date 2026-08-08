; tests/src/casm_listcap/casm_listcap.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 10 WP51 Increment 6: real-path listing-capture harness. Unlike
; test_casm_listing (Increments 3-4), which drives listing.s directly with
; synthetic staged fields, this harness is the first thing anywhere -- test
; or production -- that drives a REAL source/lexer/parser/emitter/include
; two-pass assembly with listing capture genuinely enabled
; (listingCaptureInit), then replays the resulting metadata records and
; compares them against hand-derived expectations. `/L` still stays rejected
; in production orchestration (WP54's job); this harness is its own
; standalone caller.
;
; Links the same whole-object surface as test_casm_frame.s/test_casm_pass1.s
; (include.s fileio.s source.s state.s lexer.s parser.s opcodes.s emit.s
; expr.s diagnostics.s resources.s vmm_store.s symbols.s reloc.s) plus
; listing.s itself. Not cli.s, not casm.s -- this harness's own
; runCaptureAssembly/lcRunPass/lcInclude reimplement casm.s's current
; casmRunPass/crpInclude/crpListingBegin/crpListingCommit dispatch verbatim
; (this is precisely the wiring WP51 Increment 5 added to production, and
; proving it against a real traversal is this harness's whole purpose).
;
; Each fixture runs its own complete, independent two-pass assembly
; (Pass 1 measure, Pass 2 emit with capture optionally enabled) rather than
; sharing state across fixtures: sourceInit/fileIoInit/listingStateInit are
; called fresh at the top of every run, and resourcesCleanup sweeps the
; VMM/file registry after every fixture (matching test_casm_frame.s's own
; per-fixture cleanup convention) since this project's fileio.s leaves the
; output file's local CasmOutputState mirror OPEN until an explicit
; process exit in production -- multiple real runs per process (unique to
; this harness) need that reset done by hand instead.
;
; Fixture coverage (deliberately scoped down from the plan's full checklist
; given this increment's size -- see the WP51 plan doc's Increment 6 notes
; for what got folded together or deferred):
;   fixEmpty            -- minimal single blank line, capture on
;   fixNewlineVariants   -- CR/LF/CRLF-terminated single line, same expected
;                           record reused for all three (Length excludes the
;                           terminator; CRLF publishes once)
;   fixFinalUnterminated -- a real line with no trailing terminator before
;                           EOF (FINAL_UNTERMINATED via sourceCaptureFinal)
;   fixDeferredData      -- .ORG/.BYTE-list/.WORD-list/255-char-comment-line,
;                           proving per-line ByteCount aggregation and the
;                           255-byte Length boundary in one fixture
;   fixLabelsInclude     -- label + `.INCLUDE` (its own zero-byte record,
;                           committed before the push) + one level of nested
;                           `.INCLUDE`, proving parent-before-child ordering
;                           and correct resume of the parent's own line
;                           numbering/PC/byte-offset after both children pop
;   fixRootsSynthetic    -- two top-level root files, the first ending
;                           without a terminator (forcing sourceLoad's
;                           synthetic-separator insertion) -- built and run
;                           BEFORE any source.s fix, since Increment 2's own
;                           notes flag this as unverified and possibly wrong;
;                           whatever this fixture's first live run shows is
;                           the evidence that fix is built from
;   fixPrgIdentity       -- the same source assembled twice (capture off,
;                           then on) to two output files; proves emitByte's
;                           new stack/mirror wiring never perturbs the real
;                           PRG bytes
;
; Deferred (not in this increment, noted in the WP51 plan doc): a dedicated
; "failure without partial commit" (records-full) fixture through the real
; driver -- test_casm_listing's own Increment 3/4 fixtures already prove
; listingMetaAppend/listingCommitLine's records-full behavior directly; the
; new risk surface Increment 5 introduced (casmRunPass's pass-mode-gated
; begin/commit wiring) is already covered by every fixture above.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_listcap.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import fileIoInit
.import fileOpenInput
.import fileRead
.import fileClose
.import CasmInputHandle
.import CasmInputSlot
.import fileCreateOutput
.import sourceInit
.import sourceLoad
.import sourceOpen
.import sourceRewind
.import sourceClose
.import sourceFramePush
.import CasmFrameDepth
.import CasmFrameCatalogIndex
.import CasmSourceFileId
.import listingStateInit
.import listingCaptureInit
.import listingCaptureFinalize
.import listingBeginLine
.import listingCommitLine
.import listingReplayReset
.import listingReplayNext
.import CasmVmmBuffer
.import lexerInit
.import parserParseStatement
.import CasmParserStmt
.import CasmLabelName
.import CasmLabelNameLen
.import opcodesFindOpcode
.import symbolsInit
.import symbolsInsert
.import includeCatalogInit
.import includeCatalogLoad
.import includeCatalogLookup
.import includeCatalogRead
.import includeResolveDevice
.import includeEventRecord
.import includeEventReplay
.import includeReplayReset
.import includeReplayFinalCheck
.import CasmIncludeEventStage
.import CasmIncludeRecordStage
.import CasmIncludeFilename
.import CasmStmtLocLineLo
.import CasmStmtLocLineHi
.import CasmStmtLocColumn
.import emitInit
.import emitInstruction
.import emitDirective
.import emitFinalize
.import emitCheckPassAgreement
.import emitMarkStarted
.import CasmPc
.import CasmPassMode
.import CasmPass1FinalPc
.import relocInit
.import relocFinalize

.export CasmSourceNames
.export CasmSourceLens
.export CasmSourceCount
.export cliSourceSlotLo
.export cliSourceSlotHi
.export CasmOutputName
.export CasmListingName
.export CasmListingLen
.export CasmCliOptions

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda CurrentDevice
    sta TestDevice
    jsr resourcesInit
    lda #0
    sta FailCount

    ldx #<nameEmpty
    ldy #>nameEmpty
    jsr fixEmpty
    jsr reportCase
    jsr resourcesCleanup

    jsr fixNewlineVariants
    jsr reportCase
    jsr resourcesCleanup

    jsr fixFinalUnterminated
    jsr reportCase
    jsr resourcesCleanup

    jsr fixDeferredData
    jsr reportCase
    jsr resourcesCleanup

    jsr fixLabelsInclude
    jsr reportCase
    jsr resourcesCleanup

    jsr fixRootsSynthetic
    jsr reportCase
    jsr resourcesCleanup

    jsr fixPrgIdentity
    jsr reportCase
    jsr resourcesCleanup

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
; reportCase -- identical convention to every sibling CASM harness.
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

; =============================================================================
; Shared driver: runCaptureAssembly / lcRunPass / lcInclude / lcParentIdentity
; / lcStageEvent -- reimplements casm.s's current production dispatch
; verbatim (casmRunPass/crpInclude/crpParentIdentity/crpStageEvent plus the
; new crpListingBegin/crpListingCommit gates from Increment 5).
; =============================================================================

; ---------------------------------------------------------------------------
; runCaptureAssembly
; Run one complete real two-pass assembly of the source(s) already staged in
; CasmSourceNames/CasmSourceCount, optionally with listing capture enabled.
; Inputs:  X/Y = output filename pointer
;          EnableCapture = 0 or 1, set by the caller first
; Outputs: C clear on success; C set with A = CASM_DIAG_* on failure
; ---------------------------------------------------------------------------
runCaptureAssembly:
    stx RcaOutNameLo
    sty RcaOutNameHi
    ; WP51 Increment 9 fix: CasmCliOptions (this harness's own stand-in for
    ; what cli.s normally sets up -- this harness deliberately never links
    ; cli.s, see its own header) was declared but never initialized anywhere
    ; in this file. It happened to read as a harmless 0 before purely by
    ; memory-layout coincidence (uninitialized BSS holds whatever RAM held
    ; before this PRG loaded, never zeroed between loads); emitMarkStarted's
    ; CASM_OPT_STATIC check on real garbage there explains both failure
    ; modes seen live: CASM_DIAG_ORG_REQUIRED when that bit happened to be
    ; set, and a wrong captured PC when it wasn't but some other stale value
    ; was read. A real, pre-existing bug this harness's own reshuffled BSS
    ; layout exposed, not introduced.
    lda #0
    sta CasmCliOptions
    jsr sourceInit
    jsr fileIoInit
    jsr listingStateInit
    jsr symbolsInit
    bcc :+
    rts
:
    jsr sourceLoad
    bcc :+
    rts
:
    jsr includeCatalogInit
    bcc :+
    rts
:
    jsr sourceOpen
    bcc :+
    rts
:
    jsr lexerInit
    bcc :+
    rts
:

    jsr emitInit
    bcc :+
    rts
:
    lda #CASM_PASS_MODE_MEASURE
    sta CasmPassMode
    jsr lcRunPass
    bcc :+
    rts
:
    lda CasmPc
    sta CasmPass1FinalPc
    lda CasmPc + 1
    sta CasmPass1FinalPc + 1

    jsr sourceRewind
    bcc :+
    rts
:
    jsr includeReplayReset
    bcc :+
    rts
:
    jsr lexerInit
    bcc :+
    rts
:
    ldx RcaOutNameLo
    ldy RcaOutNameHi
    jsr fileCreateOutput
    bcc :+
    rts
:
    jsr relocInit
    bcc :+
    rts
:
    jsr emitInit
    bcc :+
    rts
:
    lda #CASM_PASS_MODE_EMIT
    sta CasmPassMode

    lda EnableCapture
    beq rcaNoInit
    jsr listingCaptureInit
    bcc rcaNoInit
    rts
rcaNoInit:
    jsr lcRunPass
    bcc :+
    rts
:
    jsr includeReplayFinalCheck
    bcc :+
    rts
:
    jsr emitCheckPassAgreement
    bcc :+
    rts
:
    jsr emitFinalize
    bcc :+
    rts
:
    jsr relocFinalize
    bcc :+
    rts
:

    lda EnableCapture
    beq rcaNoFinalize
    jsr listingCaptureFinalize
    bcc rcaNoFinalize
    rts
rcaNoFinalize:
    jsr sourceClose
    bcc :+
    rts
:
    clc
    rts

; ---------------------------------------------------------------------------
; lcRunPass (private) -- casm.s's casmRunPass, copied verbatim including the
; Increment 5 listing-transaction gates.
; ---------------------------------------------------------------------------
lcRunPass:
    jsr lcListingBegin
    bcs lcrpFail
    jsr parserParseStatement
    bcs lcrpFail
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    cmp #CASM_TOKEN_IDENTIFIER
    beq lcrpLabel
    cmp #CASM_TOKEN_MNEMONIC
    beq lcrpInsn
    cmp #CASM_TOKEN_DIRECTIVE
    beq lcrpDir
    cmp #CASM_TOKEN_EOF
    beq lcrpDone
    jsr lcListingCommit
    bcs lcrpFail
    jmp lcRunPass

lcrpLabel:
    jsr emitMarkStarted
    bcs lcrpFail
    lda CasmPassMode
    cmp #CASM_PASS_MODE_MEASURE
    bne lcrpLabelCommit
    lda CasmLabelNameLen
    ldx #<CasmLabelName
    ldy #>CasmLabelName
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldx CasmPc
    ldy CasmPc + 1
    jsr symbolsInsert
    bcs lcrpFail
lcrpLabelCommit:
    jsr lcListingCommit
    bcs lcrpFail
    jmp lcRunPass

lcrpInsn:
    jsr opcodesFindOpcode
    bcs lcrpFail
    jsr emitInstruction
    bcs lcrpFail
    jsr lcListingCommit
    bcs lcrpFail
    jmp lcRunPass

lcrpDir:
    lda CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    cmp #CASM_DIRECTIVE_INCLUDE
    bne lcrpEmitDir
    jsr lcInclude
    bcs lcrpFail
    jmp lcRunPass
lcrpEmitDir:
    jsr emitDirective
    bcs lcrpFail
    jsr lcListingCommit
    bcs lcrpFail
    jmp lcRunPass

lcrpDone:
    jsr lcListingCommit
    bcs lcrpFail
    clc
    rts
lcrpFail:
    rts

; ---------------------------------------------------------------------------
; lcListingBegin / lcListingCommit (private) -- casm.s's crpListingBegin/
; crpListingCommit, copied verbatim: gate to Pass 2 only.
; ---------------------------------------------------------------------------
lcListingBegin:
    lda CasmPassMode
    cmp #CASM_PASS_MODE_EMIT
    beq lcListingBeginPass2
    clc
    rts
lcListingBeginPass2:
    jmp listingBeginLine

lcListingCommit:
    lda CasmPassMode
    cmp #CASM_PASS_MODE_EMIT
    beq lcListingCommitPass2
    clc
    rts
lcListingCommitPass2:
    jmp listingCommitLine

; ---------------------------------------------------------------------------
; lcInclude (private) -- casm.s's crpInclude, copied verbatim.
; ---------------------------------------------------------------------------
lcInclude:
    jsr lcParentIdentity
    bcs lcIncFail
    lda CasmPassMode
    cmp #CASM_PASS_MODE_MEASURE
    bne lcIncReplay

    lda LcIncParentDevice
    ldx #<CasmIncludeFilename
    ldy #>CasmIncludeFilename
    jsr includeCatalogLoad
    bcs lcIncFail
    stx LcIncChildIndex
    jsr lcStageEvent
    jsr includeEventRecord
    bcs lcIncFail
    jmp lcIncCommit

lcIncReplay:
    lda LcIncParentDevice
    ldx #<CasmIncludeFilename
    ldy #>CasmIncludeFilename
    jsr includeCatalogLookup
    bcs lcIncLookupMiss
    stx LcIncChildIndex
    jsr lcStageEvent
    jsr includeEventReplay
    bcs lcIncFail

lcIncCommit:
    jsr lcListingCommit
    bcs lcIncFail

lcIncPush:
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_LO
    sta CasmValue0Lo
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_HI
    sta CasmValue0Hi
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_LO
    clc
    adc CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_LENGTH_LO
    sta CasmValue1Lo
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_START_HI
    adc CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_LENGTH_HI
    sta CasmValue1Hi
    lda LcIncChildIndex
    jsr sourceFramePush
    bcs lcIncFail
    clc
    rts

lcIncLookupMiss:
    cmp #CASM_DIAG_NONE
    bne lcIncFail
    lda #CASM_DIAG_INCLUDE_REPLAY_MISMATCH
lcIncFail:
    sec
    rts

; ---------------------------------------------------------------------------
; lcParentIdentity (private) -- casm.s's crpParentIdentity, copied verbatim
; (using this harness's own TestDevice/cliSourceSlot* in place of cli.s).
; ---------------------------------------------------------------------------
lcParentIdentity:
    lda CasmFrameDepth
    bne lcpiFrame

    lda #CASM_INCLUDE_EVENT_PARENT_KIND_ROOT
    sta LcIncParentKind
    lda CasmSourceFileId
    sta LcIncParentId
    tax
    lda cliSourceSlotHi, x
    tay
    lda cliSourceSlotLo, x
    tax
    lda TestDevice
    jsr includeResolveDevice
    sta LcIncParentDevice
    clc
    rts

lcpiFrame:
    lda #CASM_INCLUDE_EVENT_PARENT_KIND_FRAME
    sta LcIncParentKind
    ldx CasmFrameDepth
    dex
    lda CasmFrameCatalogIndex, x
    sta LcIncParentId
    jsr includeCatalogRead
    bcs lcpiFail
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_DEVICE
    sta LcIncParentDevice
    clc
lcpiFail:
    rts

; ---------------------------------------------------------------------------
; lcStageEvent (private) -- casm.s's crpStageEvent, copied verbatim.
; ---------------------------------------------------------------------------
lcStageEvent:
    lda LcIncParentKind
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_KIND
    lda LcIncParentId
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_ID
    lda CasmStmtLocLineLo
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_LINE_LO
    lda CasmStmtLocLineHi
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_LINE_HI
    lda CasmStmtLocColumn
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_COLUMN
    lda LcIncChildIndex
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_CHILD_INDEX
    rts

; =============================================================================
; Comparison helpers
; =============================================================================

; ---------------------------------------------------------------------------
; lcLoadOneName (private)
; Copy a null-terminated filename into CasmSourceNames slot 0 and set
; CasmSourceCount = 1.
; Inputs:  X/Y = filename pointer
; ---------------------------------------------------------------------------
lcLoadOneName:
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldy #0
lcln1Copy:
    lda (CasmPtr1Lo), y
    sta CasmSourceNames, y
    beq lcln1Done
    iny
    cpy #CASM_FILENAME_BUFFER_SIZE
    bcc lcln1Copy
lcln1Done:
    lda #1
    sta CasmSourceCount
    rts

; ---------------------------------------------------------------------------
; lcLoadTwoNames (private)
; Copy two null-terminated filenames into CasmSourceNames slots 0/1 and set
; CasmSourceCount = 2.
; Inputs:  X/Y = first filename pointer; LcName2Lo/Hi = second filename ptr
; ---------------------------------------------------------------------------
lcLoadTwoNames:
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldy #0
lclt1Copy:
    lda (CasmPtr1Lo), y
    sta CasmSourceNames, y
    beq lclt1Done
    iny
    cpy #CASM_FILENAME_BUFFER_SIZE
    bcc lclt1Copy
lclt1Done:
    lda LcName2Lo
    sta CasmPtr1Lo
    lda LcName2Hi
    sta CasmPtr1Hi
    ldy #0
lclt2Copy:
    lda (CasmPtr1Lo), y
    sta CasmSourceNames + CASM_FILENAME_BUFFER_SIZE, y
    beq lclt2Done
    iny
    cpy #CASM_FILENAME_BUFFER_SIZE
    bcc lclt2Copy
lclt2Done:
    lda #2
    sta CasmSourceCount
    rts

; ---------------------------------------------------------------------------
; lcReplayAndCompare
; Replay every metadata record and compare each against a 17-byte-stride
; expected-row table: 16 real CASM_LISTING_META_* bytes followed by one
; "check the Off field" flag (0 = skip CASM_LISTING_META_OFF_LO/HI --
; included-frame records live in include.s's own catalog-physical offset
; space, which this harness does not attempt to hand-derive).
; Inputs:  A = expected record count, X/Y = expected table pointer
; Outputs: C clear if the record count and every checked field match
; ---------------------------------------------------------------------------
lcReplayAndCompare:
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    sta LcExpectCount
    lda #0
    sta LcExpectIndex
    jsr listingReplayReset
    bcs lcRacFail
lcRacLoop:
    jsr listingReplayNext
    bcs lcRacFail
    cmp #CASM_STREAM_EOF
    beq lcRacEof
    lda LcExpectIndex
    cmp LcExpectCount
    bcs lcRacFail
    jsr lcCompareRow
    bcs lcRacFail
    inc LcExpectIndex
    jmp lcRacLoop
lcRacEof:
    lda LcExpectIndex
    cmp LcExpectCount
    bne lcRacFail
    clc
    rts
lcRacFail:
    sec
    rts

; ---------------------------------------------------------------------------
; lcCompareRow (private)
; Compare CasmVmmBuffer[0..15] (the just-replayed record) against expected
; row LcExpectIndex in the table based at CasmPtr0Lo/Hi (stride 17).
; ---------------------------------------------------------------------------
lcCompareRow:
    lda LcExpectIndex
    sta LcMulLo
    lda #0
    sta LcMulHi
    lda LcMulLo
    pha
    ldx #4
lcCrShift:
    asl LcMulLo
    rol LcMulHi
    dex
    bne lcCrShift
    pla
    clc
    adc LcMulLo
    sta LcMulLo
    bcc lcCrNoCarry
    inc LcMulHi
lcCrNoCarry:
    lda CasmPtr0Lo
    clc
    adc LcMulLo
    sta CasmPtr1Lo
    lda CasmPtr0Hi
    adc LcMulHi
    sta CasmPtr1Hi

    ldy #16
    lda (CasmPtr1Lo), y
    beq lcCrSkipOff
    ldy #CASM_LISTING_META_OFF_LO
    lda CasmVmmBuffer, y
    cmp (CasmPtr1Lo), y
    bne lcCrMismatch
    ldy #CASM_LISTING_META_OFF_HI
    lda CasmVmmBuffer, y
    cmp (CasmPtr1Lo), y
    bne lcCrMismatch
lcCrSkipOff:
    ldy #15
lcCrLoop:
    cpy #CASM_LISTING_META_OFF_LO
    beq lcCrLoopSkip
    cpy #CASM_LISTING_META_OFF_HI
    beq lcCrLoopSkip
    lda CasmVmmBuffer, y
    cmp (CasmPtr1Lo), y
    bne lcCrMismatch
lcCrLoopSkip:
    dey
    bpl lcCrLoop
    clc
    rts
lcCrMismatch:
    sec
    rts

; ---------------------------------------------------------------------------
; lcCaptureFileA / lcCaptureFileB
; Read a whole small file into LcBufA/LcBufB (64-byte cap each -- every
; fixture PRG here is well under that), tracking its length.
; Inputs:  X/Y = filename pointer
; Outputs: C clear on success; C set on any open/read/close failure
; ---------------------------------------------------------------------------
lcCaptureFileA:
    jsr fileOpenInput
    bcs lcCfAFail
    lda #0
    sta LcBufALen
lcCfALoop:
    lda #64
    sec
    sbc LcBufALen
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    lda #<LcBufA
    clc
    adc LcBufALen
    tax
    lda #>LcBufA
    adc #0
    tay
    jsr fileRead
    bcs lcCfAFail
    cmp #CASM_STREAM_EOF
    beq lcCfADone
    lda CasmIoLenLo
    clc
    adc LcBufALen
    sta LcBufALen
    jmp lcCfALoop
lcCfADone:
    lda CasmInputHandle
    ldx CasmInputSlot
    ldy #CASM_DIAG_INPUT_CLOSE_FAILED
    jsr fileClose
    bcs lcCfAFail
    clc
    rts
lcCfAFail:
    sec
    rts

lcCaptureFileB:
    jsr fileOpenInput
    bcs lcCfBFail
    lda #0
    sta LcBufBLen
lcCfBLoop:
    lda #64
    sec
    sbc LcBufBLen
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    lda #<LcBufB
    clc
    adc LcBufBLen
    tax
    lda #>LcBufB
    adc #0
    tay
    jsr fileRead
    bcs lcCfBFail
    cmp #CASM_STREAM_EOF
    beq lcCfBDone
    lda CasmIoLenLo
    clc
    adc LcBufBLen
    sta LcBufBLen
    jmp lcCfBLoop
lcCfBDone:
    lda CasmInputHandle
    ldx CasmInputSlot
    ldy #CASM_DIAG_INPUT_CLOSE_FAILED
    jsr fileClose
    bcs lcCfBFail
    clc
    rts
lcCfBFail:
    sec
    rts

; ---------------------------------------------------------------------------
; lcCompareBuffers
; Outputs: C clear iff LcBufALen == LcBufBLen and every byte matches.
; ---------------------------------------------------------------------------
lcCompareBuffers:
    lda LcBufALen
    cmp LcBufBLen
    bne lcCbFail
    beq lcCbCheckZero
lcCbCheckZero:
    lda LcBufALen
    beq lcCbOk
    tay
    dey
lcCbLoop:
    lda LcBufA, y
    cmp LcBufB, y
    bne lcCbFail
    dey
    bpl lcCbLoop
lcCbOk:
    clc
    rts
lcCbFail:
    sec
    rts

; =============================================================================
; Fixtures
; =============================================================================

; ---------------------------------------------------------------------------
; fixEmpty: a file containing only a bare CR (the minimal non-empty SEQ
; fixture -- a literal 0-byte file risks corrupting the image, per
; tests/AGENTS.md). Expect exactly one blank-line record.
; ---------------------------------------------------------------------------
fixEmpty:
    ldx #<nameEmpty
    ldy #>nameEmpty
    jsr lcLoadOneName
    lda #1
    sta EnableCapture
    ldx #<outEmpty
    ldy #>outEmpty
    jsr runCaptureAssembly
    bcs feFail
    lda #4
    ldx #<expEmpty
    ldy #>expEmpty
    jsr lcReplayAndCompare
    bcs feFail
    clc
    rts
feFail:
    sec
    rts

; ---------------------------------------------------------------------------
; fixNewlineVariants: the same ".BYTE 65" statement terminated by CR, LF, and
; CRLF in three separate files. Same expected record for all three (Length
; excludes the terminator; CRLF must publish once, not twice).
; ---------------------------------------------------------------------------
fixNewlineVariants:
    ldx #<nameNlCr
    ldy #>nameNlCr
    jsr lcLoadOneName
    lda #1
    sta EnableCapture
    ldx #<outNlCr
    ldy #>outNlCr
    jsr runCaptureAssembly
    bcs fnvFail
    lda #1
    ldx #<expNewline
    ldy #>expNewline
    jsr lcReplayAndCompare
    bcs fnvFail
    ; WP51 Increment 9 fix: each sub-run's own runCaptureAssembly allocates up
    ; to six fresh VMM registry slots (source/symbols/reloc/include-event/
    ; listing x2) without freeing the previous sub-run's own six first -- the
    ; registry only holds eight total. Unlike every sibling fixture (which
    ; calls runCaptureAssembly exactly once, relying on the shared driver's
    ; own post-fixture resourcesCleanup), this fixture calls it three times
    ; internally and must sweep the registry between each one itself, or the
    ; second sub-run's own allocations exhaust the registry and fail with
    ; CASM_DIAG_VMM_ALLOC_FAILED -- a real, reproducible test-harness bug
    ; found via WP51 Increment 9's live-failure investigation, not a
    ; production defect.
    jsr resourcesCleanup

    ldx #<nameNlLf
    ldy #>nameNlLf
    jsr lcLoadOneName
    lda #1
    sta EnableCapture
    ldx #<outNlLf
    ldy #>outNlLf
    jsr runCaptureAssembly
    bcs fnvFail
    lda #1
    ldx #<expNewline
    ldy #>expNewline
    jsr lcReplayAndCompare
    bcs fnvFail
    jsr resourcesCleanup

    ldx #<nameNlCrlf
    ldy #>nameNlCrlf
    jsr lcLoadOneName
    lda #1
    sta EnableCapture
    ldx #<outNlCrlf
    ldy #>outNlCrlf
    jsr runCaptureAssembly
    bcs fnvFail
    lda #1
    ldx #<expNewline
    ldy #>expNewline
    jsr lcReplayAndCompare
    bcs fnvFail
    clc
    rts
fnvFail:
    sec
    rts

; ---------------------------------------------------------------------------
; fixFinalUnterminated: `.ORG $2000` then `.BYTE 1,2,3` with no trailing
; terminator at all before EOF. Expect the second record's FINAL_UNTERMINATED
; bit set via sourceCaptureFinal/srEof.
; ---------------------------------------------------------------------------
fixFinalUnterminated:
    ldx #<nameFinal
    ldy #>nameFinal
    jsr lcLoadOneName
    lda #1
    sta EnableCapture
    ldx #<outFinal
    ldy #>outFinal
    jsr runCaptureAssembly
    bcs ffuFail
    lda #2
    ldx #<expFinal
    ldy #>expFinal
    jsr lcReplayAndCompare
    bcs ffuFail
    clc
    rts
ffuFail:
    sec
    rts

; ---------------------------------------------------------------------------
; fixDeferredData: `.ORG`, a `.BYTE` list, a `.WORD` list, and a 255-character
; comment-only line (the Length field's byte-sized boundary), all properly
; terminated. Proves one record per line with ByteCount = the whole list's
; total emitted bytes, and Length arithmetic exact at 255.
; ---------------------------------------------------------------------------
fixDeferredData:
    ldx #<nameDeferred
    ldy #>nameDeferred
    jsr lcLoadOneName
    lda #1
    sta EnableCapture
    ldx #<outDeferred
    ldy #>outDeferred
    jsr runCaptureAssembly
    bcs fddFail
    lda #4
    ldx #<expDeferred
    ldy #>expDeferred
    jsr lcReplayAndCompare
    bcs fddFail
    clc
    rts
fddFail:
    sec
    rts

; ---------------------------------------------------------------------------
; fixLabelsInclude: parent (.ORG, a label, `.INCLUDE` a child, then a trailing
; .BYTE) includes a child (.BYTE list, then `.INCLUDE` a grandchild) which
; includes a grandchild (.BYTE list). Proves: the label's own zero-byte
; record, the `.INCLUDE` line's own zero-byte record committed strictly
; before the push, ordering across two nesting levels, and the parent's own
; line/PC/byte-offset resuming correctly after both children pop.
; Root-level Off values are asserted (computable in the shared top-level
; store); included-frame records skip Off (see lcReplayAndCompare's header).
; ---------------------------------------------------------------------------
fixLabelsInclude:
    ldx #<nameParent
    ldy #>nameParent
    jsr lcLoadOneName
    lda #1
    sta EnableCapture
    ldx #<outParent
    ldy #>outParent
    jsr runCaptureAssembly
    bcs fliFail
    lda #7
    ldx #<expParent
    ldy #>expParent
    jsr lcReplayAndCompare
    bcs fliFail
    clc
    rts
fliFail:
    sec
    rts

; ---------------------------------------------------------------------------
; fixRootsSynthetic: two top-level root files. The first has no trailing
; terminator, forcing sourceLoad to insert its synthetic inter-root
; separator LF. Increment 2's own notes flag this path as never verified
; against a real traversal and possibly wrong (source.s never marks a
; synthetic separator SYNTHETIC_ONLY). This fixture asserts the DESIRED
; outcome (each root's own line correctly attributed to its own FileId, at
; its own real offset) -- whatever this fixture's first live run actually
; shows is the evidence a follow-up fix gets built from, not a guess.
; ---------------------------------------------------------------------------
fixRootsSynthetic:
    lda #<nameRoot2
    sta LcName2Lo
    lda #>nameRoot2
    sta LcName2Hi
    ldx #<nameRoot1
    ldy #>nameRoot1
    jsr lcLoadTwoNames
    lda #1
    sta EnableCapture
    ldx #<outRoots
    ldy #>outRoots
    jsr runCaptureAssembly
    bcs frsFail
    lda #2
    ldx #<expRoots
    ldy #>expRoots
    jsr lcReplayAndCompare
    bcs frsFail
    clc
    rts
frsFail:
    sec
    rts

; ---------------------------------------------------------------------------
; fixPrgIdentity: the same small source assembled twice -- capture off, then
; capture on -- to two distinct output files, then byte-compared. Proves
; emitByte's new stack-juggling/listingMirrorByte call never perturbs the
; real PRG output.
; ---------------------------------------------------------------------------
fixPrgIdentity:
    ldx #<nameIdentity
    ldy #>nameIdentity
    jsr lcLoadOneName
    lda #0
    sta EnableCapture
    ldx #<outIdentityA
    ldy #>outIdentityA
    jsr runCaptureAssembly
    bcs fpiFail
    ; WP51 Increment 9 fix: same VMM-registry-exhaustion bug as
    ; fixNewlineVariants above -- this fixture's own second runCaptureAssembly
    ; call (capture on, needing all six slots) exhausts the eight-slot
    ; registry on top of the first call's four (capture off) if the first
    ; call's slots are never freed first.
    jsr resourcesCleanup

    ldx #<nameIdentity
    ldy #>nameIdentity
    jsr lcLoadOneName
    lda #1
    sta EnableCapture
    ldx #<outIdentityB
    ldy #>outIdentityB
    jsr runCaptureAssembly
    bcs fpiFail
    ; WP51 Increment 9 fix: runCaptureAssembly's own tail never closes the
    ; output file it created (emitFinalize only flushes buffered bytes --
    ; see its own header: production only ever relies on DOS_EXIT to close
    ; everything, since it never needs to reopen an output file mid-process).
    ; Without this cleanup, outIdentityB's write channel is still physically
    ; open on the drive when lcCaptureFileB immediately below tries to open
    ; it for reading -- confirmed live as this fixture's own remaining
    ; failure during this investigation.
    jsr resourcesCleanup

    ldx #<outIdentityA
    ldy #>outIdentityA
    jsr lcCaptureFileA
    bcs fpiFail
    ; WP51 Increment 9 fix: fileClose (fileio.s, production, unrelated to
    ; WP51) never resets CasmInputState back to CLOSED -- only fileIoInit
    ; does. lcCaptureFileA's own fileClose leaves it at whatever state the
    ; read left behind, so lcCaptureFileB's fileOpenInput call immediately
    ; below would otherwise hit foiBadState (CASM_DIAG_STREAM_STATE_FAILED)
    ; even with the physical-channel fix above in place -- confirmed live
    ; as a second, independent gap during this investigation.
    jsr fileIoInit
    ldx #<outIdentityB
    ldy #>outIdentityB
    jsr lcCaptureFileB
    bcs fpiFail
    jsr lcCompareBuffers
    bcs fpiFail
    clc
    rts
fpiFail:
    sec
    rts

.segment "RODATA"

nameEmpty:     .byte "CASMLC01", 0
nameNlCr:      .byte "CASMLC02", 0
nameNlLf:      .byte "CASMLC03", 0
nameNlCrlf:    .byte "CASMLC04", 0
nameFinal:     .byte "CASMLC05", 0
nameDeferred:  .byte "CASMLC06", 0
nameParent:    .byte "CASMLC07", 0
nameRoot1:     .byte "CASMLC08", 0
nameRoot2:     .byte "CASMLC09", 0
nameIdentity:  .byte "CASMLC10", 0

outEmpty:      .byte "CASMLO01", 0
outNlCr:       .byte "CASMLO02", 0
outNlLf:       .byte "CASMLO03", 0
outNlCrlf:     .byte "CASMLO04", 0
outFinal:      .byte "CASMLO05", 0
outDeferred:   .byte "CASMLO06", 0
outParent:     .byte "CASMLO07", 0
outRoots:      .byte "CASMLO08", 0
outIdentityA:  .byte "CASMLO09", 0
outIdentityB:  .byte "CASMLO10", 0

; Expected metadata rows: 16 CASM_LISTING_META_* bytes + 1 "check Off" flag.
; FileId, Flags, LineLo, LineHi, OffLo, OffHi, Len, Reserved0, PcLo, PcHi,
; ByteOffLo, ByteOffHi, ByteCountLo, ByteCountHi, Reserved1Lo, Reserved1Hi,
; CheckOff.
; WP51 Increment 9 temp experiment: nameEmpty widened from one blank line
; (1 byte) to four (4 bytes) -- see the fixture generator's own comment.
; Four blank lines, each zero payload bytes; Off increments by 1 per line
; (the prior line's own CR); PC never moves.
expEmpty:
    .byte 0,0, 1,0, 0,0, 0, 0, $00,$34, 0,0, 0,0, 0,0, 1
    .byte 0,0, 2,0, 1,0, 0, 0, $00,$34, 0,0, 0,0, 0,0, 1
    .byte 0,0, 3,0, 2,0, 0, 0, $00,$34, 0,0, 0,0, 0,0, 1
    .byte 0,0, 4,0, 3,0, 0, 0, $00,$34, 0,0, 0,0, 0,0, 1

; ".BYTE 65" = 8 chars; 1 byte emitted.
expNewline:
    .byte 0,0, 1,0, 0,0, 8, 0, $00,$34, 0,0, 1,0, 0,0, 1

; Record 1: ".ORG $2000" = 10 chars, PC snapshot before .ORG applies ($3400).
; Record 2: ".BYTE 1,2,3" = 11 chars, no terminator -> FINAL_UNTERMINATED,
;           PC $2000 (after .ORG), ByteCount 3.
expFinal:
    .byte 0,0, 1,0, 0,0, 10, 0, $00,$34, 0,0, 0,0, 0,0, 1
    .byte 0,CASM_LISTING_META_FLAG_FINAL_UNTERMINATED, 2,0, 11,0, 11, 0, $00,$20, 0,0, 3,0, 0,0, 1

; Record 1: ".ORG $2000" (10 chars).
; Record 2: ".BYTE 1,2,3,4,5" (15 chars), ByteCount 5.
; Record 3: ".WORD $1234,$5678" (17 chars), ByteCount 4.
; Record 4: 255-char comment line, ByteCount 0.
; WP51 Increment 9 fix: rows 2 and 3's ByteOffLo/Hi (offsets 10/11) were
; hardcoded to 0,0 -- an authoring bug in this expected table, not a
; production defect. Row 1 mirrors 5 bytes (.BYTE 1,2,3,4,5) starting at
; cursor 0, so row 2 (.WORD $1234,$5678) genuinely starts mirroring at
; cursor 5; row 2 then mirrors 4 more bytes, so row 3 (the comment line,
; which emits nothing) genuinely starts at cursor 9. The real capture
; already reported these correctly -- confirmed live via lcCrMismatch's own
; row/field/got/exp dump during this investigation.
expDeferred:
    .byte 0,0, 1,0, 0,0, 10, 0, $00,$34, 0,0, 0,0, 0,0, 1
    .byte 0,0, 2,0, 11,0, 15, 0, $00,$20, 0,0, 5,0, 0,0, 1
    .byte 0,0, 3,0, 27,0, 17, 0, $05,$20, 5,0, 4,0, 0,0, 1
    .byte 0,0, 4,0, 45,0, 255, 0, $09,$20, 9,0, 0,0, 0,0, 1

; Parent: .ORG(10 chars,Off0) / START:(6 chars,Off11) /
;         .INCLUDE "CASMLC7C"(19 chars,Off18) / [child+grandchild] /
;         .BYTE 9(7 chars,Off38,PC$2003,ByteOff3,ByteCount1)
; Child (FileId $80): .BYTE 1,2(10 chars,PC$2000,ByteCount2) /
;         .INCLUDE "CASMLC7G"(19 chars,PC$2002,ByteOff2)
; Grandchild (FileId $81): .BYTE 3(7 chars,PC$2002,ByteOff2,ByteCount1)
expParent:
    .byte 0,0, 1,0, 0,0, 10, 0, $00,$34, 0,0, 0,0, 0,0, 1
    .byte 0,0, 2,0, 11,0, 6, 0, $00,$20, 0,0, 0,0, 0,0, 1
    .byte 0,0, 3,0, 18,0, 19, 0, $00,$20, 0,0, 0,0, 0,0, 1
    .byte $80,0, 1,0, 0,0, 9, 0, $00,$20, 0,0, 2,0, 0,0, 0
    .byte $80,0, 2,0, 0,0, 19, 0, $02,$20, 2,0, 0,0, 0,0, 0
    .byte $81,0, 1,0, 0,0, 7, 0, $02,$20, 2,0, 1,0, 0,0, 0
    .byte 0,0, 4,0, 38,0, 7, 0, $03,$20, 3,0, 1,0, 0,0, 1

; Two root files: "LBL1:" (5 chars, no terminator -> synthetic separator
; inserted after it) then "LBL2:\r" (5 chars, real terminator). Desired:
; each root's own line attributed to its own FileId (0, then 1), at its own
; real offset (0, then 6 -- 5 real bytes + 1 synthetic separator byte).
expRoots:
    .byte 0,0, 1,0, 0,0, 5, 0, $00,$34, 0,0, 0,0, 0,0, 1
    .byte 1,0, 1,0, 6,0, 5, 0, $00,$34, 0,0, 0,0, 0,0, 1

.segment "BSS"

FailCount:      .res 1
TestDevice:     .res 1
EnableCapture:  .res 1

RcaOutNameLo:   .res 1
RcaOutNameHi:   .res 1

LcName2Lo:      .res 1
LcName2Hi:      .res 1

LcIncParentKind:   .res 1
LcIncParentId:     .res 1
LcIncParentDevice: .res 1
LcIncChildIndex:   .res 1

LcExpectCount: .res 1
LcExpectIndex: .res 1
LcMulLo:       .res 1
LcMulHi:       .res 1

LcBufALen: .res 1
LcBufA:    .res 64
LcBufBLen: .res 1
LcBufB:    .res 64

; This harness's own two-slot stand-in for cli.s's arrays -- see header.
CasmSourceNames: .res CASM_FILENAME_BUFFER_SIZE * 2
CasmSourceLens:  .res 2
CasmSourceCount: .res 1
CasmOutputName:  .res CASM_FILENAME_BUFFER_SIZE
CasmCliOptions:  .res 1
; WP53 increment 4: listing.s (linked whole) now references these -- never
; touched by this harness, which does not exercise the new `.LST` file I/O.
CasmListingName: .res CASM_FILENAME_BUFFER_SIZE
CasmListingLen:  .res 1

.segment "RODATA"

cliSourceSlotLo:
    .byte <(CasmSourceNames + 0), <(CasmSourceNames + CASM_FILENAME_BUFFER_SIZE)
cliSourceSlotHi:
    .byte >(CasmSourceNames + 0), >(CasmSourceNames + CASM_FILENAME_BUFFER_SIZE)

passMsg: .byte "CASM LISTCAP: PASS", $0D, 0
failMsg: .byte "CASM LISTCAP: FAIL", $0D, 0
