; src/external/casm/source.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 3 source backend (WP4 traversal, WP5 normalization). This module
; owns the executable byte-stream source layer that sits over the Phase 2
; managed input wrapper and the WP3 bounded source subrecord in state.s. It
; initializes source state, opens exactly one source, refills and traverses the
; shared 256-byte CasmIoBuffer, exposes a repeat-stable EOF, and closes through
; the central resource owner.
;
; WP5 normalizes newlines and tracks provenance. sourceNextByte collapses CR,
; LF, and CRLF (including CRLF split across a block boundary) into one
; CASM_SOURCE_NEWLINE result via the persistent pending-CR latch, resolves a
; final CR before EOF, and advances one-based line/column plus the physical
; offset with checked commits. A non-newline byte is delivered raw in
; CasmSourceResultByte as CASM_SOURCE_BYTE; a zero byte remains a valid BYTE
; result and is never inferred from A or Z. CasmSourceResultByte is 0 for
; NEWLINE and EOF. sourceGetLocation exposes the next result's provenance.
;
; Rewind and the bounded line API remain WP6; the lexer remains WP7. This
; translation unit imports the WP3 source subrecord and the Phase 2 file
; wrappers. It writes no lexer state and calls no OS service except through
; inputStreamOpen/inputStreamRead/inputStreamClose.
;
; WP33 (Phase 7) adds sourceLoad, a new pre-pass that streams the parsed
; input file into one VMM allocation before any traversal begins. sourceOpen
; and sourceRewind no longer perform any OS call -- both simply reset the
; traversal cursor to the start of the already-loaded VMM content, and
; sourceRefill fills CasmIoBuffer through chunked VMM reads instead of a
; direct OS read. sourceFetchPhysical and every byte-classification/
; newline-normalization routine below are unchanged: they only ever consult
; the block index/length window into CasmIoBuffer and the checked delivered-
; byte offset, both meaningful identically regardless of where CasmIoBuffer's
; contents came from.

.include "common.inc"

; WP3 bounded source state (storage-only state.s).
.import CasmSourceApiMode
.import CasmSourceState
.import CasmSourceFileId
.import CasmSourceBlockLenLo
.import CasmSourceBlockLenHi
.import CasmSourceBlockIndexLo
.import CasmSourceBlockIndexHi
.import CasmSourceOffsetLo
.import CasmSourceOffsetHi
.import CasmSourceLineLo
.import CasmSourceLineHi
.import CasmSourceColumn
; WP48: the `.INCLUDE` statement's own start column, captured into
; CasmFrameSiteColumn at push time -- see sourceFramePush.
.import CasmStmtLocColumn
.import CasmStmtLocLineLo
.import CasmStmtLocLineHi
.import CasmSourcePendingCr
.import CasmSourceResultByte
.import CasmSourceLineLength
.import CasmSourceLineState

; WP46 fix: the true provenance (file id, line, column) of the byte just
; delivered by sourceFetchPhysical, captured at sfpHaveByte/sfpEof -- the
; one point guaranteed to run only after any pending refill/automatic-pop/
; root-transition triggered by *this* fetch has already been committed, but
; before this byte's own column/line-advance side effects (snbColumnInc,
; sourceAdvanceNewline) run below. lexerFill (lexer.s) reads these after
; calling sourceNextByte instead of snapshotting CasmSourceFileId/LineLo/Hi/
; Column itself before the call -- see lexerFill's own header comment for
; why the "before" snapshot went stale across an automatic pop.
.import CasmSourceResultFileId
.import CasmSourceResultLineLo
.import CasmSourceResultLineHi
.import CasmSourceResultColumn
.import CasmSourceResultOffsetLo
.import CasmSourceResultOffsetHi

; WP15 diagnostic line echo. Written here and never read by traversal: no
; source decision may depend on these.
.import CasmDiagLineBufA
.import CasmDiagLineBufB
.import CasmDiagLineSel
.import CasmDiagLineLen
.import CasmDiagLineClipped
.import CasmDiagLineNoLo
.import CasmDiagLineNoHi
.import CasmDiagLocFileId
.import CasmDiagPrevLen
.import CasmDiagPrevClipped
.import CasmDiagPrevNoLo
.import CasmDiagPrevNoHi
.import CasmDiagCapture

; WP46: frame push/pop own invalidating the lexer's lookahead directly
; (CasmLookaheadValid = 0), matching sourceRewind's existing precedent
; that the state-owning caller invalidates lookahead rather than a
; private lexer routine -- source.s otherwise still writes no other
; lexer-owned state.
.import CasmLookaheadValid

; Phase 2 managed file services and shared transfer state.
.import inputStreamOpen
.import inputStreamRead
.import inputStreamClose
.import CasmIoBuffer

; Phase 6A VMM allocation and windowed transfer (WP33: VMM-backed source).
.import vmmStoreAlloc
.import vmmWindowRead
.import vmmWindowWrite
.import CasmVmmBuffer

; Phase 2 CLI ordered source list (WP34: multi-file top-level inputs).
.import CasmSourceNames
.import CasmSourceCount
.import cliSourceSlotLo
.import cliSourceSlotHi

.export sourceInit
.export sourceLoad
.export sourceAppendFile
.export sourceFramePush
; WP65: the single shared VMM allocation every file's raw bytes (top-level
; and included) permanently live in -- lets the Pass1->Pass2 constant-
; resolution sweep (casm.s) re-fetch a deferred reference's own identifier
; text directly, keyed by the absolute offset CasmTokenStartOffsetLo/Hi
; already stamps on every token. See CasmSourceResultOffsetLo/Hi's own
; field comment (state.s) for why this offset is stable across the whole
; assembly run.
.export CasmSourceVmmSlot
.export CasmFrameDepth
; WP47: the active chain's own physical identity, read by casmRunPass's
; `.INCLUDE` dispatch to name the *parent* of an include event when that
; parent is itself an included file (depth > 0) rather than a top-level root.
.export CasmFrameCatalogIndex
; WP48: the include-site column at each depth's push, read by diagnostics.s
; to render each traceback line's own site location.
.export CasmFrameResumeLineLo
.export CasmFrameResumeLineHi
.export CasmFrameSiteLineLo
.export CasmFrameSiteLineHi
.export CasmFrameSiteColumn
.export CasmFrameRootFileId
.export sourceOpen
.export sourceNextByte
.export sourceNextLine
.export sourceGetLocation
.export sourceRewind
.export sourceClose
.export sourceDrainLineTail
.export sourceSetLineCapture
.export sourceTakeCompletedLine
.export sourceReadSpanChunk
.export CasmSourceCompletedStartLo
.export CasmSourceCompletedStartHi
.export CasmSourceCompletedLength
.export CasmSourceCompletedFileId
.export CasmSourceCompletedLineLo
.export CasmSourceCompletedLineHi
.export CasmSourceCompletedFlags

; ---------------------------------------------------------------------------
; WP33/WP34 VMM-backed source load state
;
; Deliberately its own segment, not state.s's frozen Phase 3 source
; subrecord (CasmSourceStateStart/End, asserted exactly 16 bytes) --
; mirrors WP28's CasmLabelName precedent (parser.s) exactly: new state kept
; parallel to a size-asserted shared ABI rather than crammed into it.
;
; CasmSourceVmmSlot is the registry slot sourceLoad's vmmStoreAlloc call
; grants. CasmSourceLoadedLenLo/Hi is the total combined byte count
; sourceLoad wrote into that allocation across every file, fixed once
; loading finishes. CasmSourceVmmCursorLo/Hi is a running 16-bit offset
; reused for two different purposes at two different times, never
; simultaneously: during sourceLoad it is the next VMM *write* offset
; (running across every file, never reset between them); sourceOpen/
; sourceRewind reset it to 0 and every VMM-backed sourceRefill afterward
; advances it as the next VMM *read* offset. Safe because loading always
; completes fully before any refill begins.
;
; WP34 additions: CasmSourceFileTable records only each file's *start*
; offset (2 bytes/entry, CASM_SOURCE_COUNT_MAX entries) -- a file's end is
; implicitly the next file's start, or CasmSourceLoadedLenLo/Hi for the
; last file, so no separate length field is needed. CasmSourceLoadIndex is
; sourceLoad's own file-loop counter, deliberately separate from the
; traversal-owned CasmSourceFileId (state.s) even though their reset timing
; would make aliasing safe, to avoid any ambiguity between "which file is
; being loaded" and "which file is being traversed". CasmSourceLoadLastByte
; tracks the most recently written byte so sourceLoad can decide whether a
; synthetic inter-file newline is needed.
;
; WP45 addition: CasmSourceStreamCursorLo/Hi is the shared per-file streaming
; primitive's (slStreamOneFile) own running write offset, deliberately
; distinct from both CasmSourceVmmCursorLo/Hi (which keeps its exact
; existing dual role, untouched by this change) and CasmSourceLoadedLenLo/Hi.
; sourceLoad's static loop copies its own running CasmSourceVmmCursorLo/Hi in
; before each file and copies the advanced result back out after; the new
; sourceAppendFile entry point copies CasmSourceLoadedLenLo/Hi in and back out
; instead. Because the two callers never run concurrently (single-threaded,
; synchronous calls), one shared field is sufficient and neither
; CasmSourceVmmCursorLo/Hi (the live traversal read cursor once loading has
; finished) nor CasmSourceLoadedLenLo/Hi is ever read or written by the parts
; of this module that don't already have a reason to.
;
; CasmSourceAppendStartLo/Hi holds sourceAppendFile's own file-start offset
; across its entire streaming loop -- deliberately not CasmValue0Lo/Hi (the
; shared general-purpose zero-page scratch pair), because vwPrepareTransfer
; (vmm_store.s, reached via slVmmWrite on every chunk write) documents
; CasmValue0Lo/Hi as its own scratch and clobbers it on the very first
; chunk. CasmValue0Lo/Hi is written only once, at the very end, from this
; stable field.
; ---------------------------------------------------------------------------
.segment "BSS"

CasmSourceVmmSlot:        .res 1
CasmSourceLoadedLenLo:    .res 1
CasmSourceLoadedLenHi:    .res 1
; WP46 fix: the combined top-level content's own true end offset, fixed at
; sourceLoad's own completion (a snapshot of CasmSourceLoadedLenLo/Hi taken
; before any .INCLUDE child is ever appended). CasmSourceLoadedLenLo/Hi
; itself keeps growing as sourceAppendFile appends children mid-traversal,
; so it cannot be used as depth-0's own cap once any child has been
; appended -- without a separate, fixed boundary, a top-level file with
; real content after its own .INCLUDE would overread straight into an
; appended child's bytes on reaching its own true end, instead of hitting
; EOF. Mirrors the existing per-frame CasmFrameEndOffsetLo/Hi mechanism
; nested frames already have; depth-0 traversal never had an equivalent
; until now.
CasmSourceTopLevelEndLo:  .res 1
CasmSourceTopLevelEndHi:  .res 1
CasmSourceVmmCursorLo:    .res 1
CasmSourceVmmCursorHi:    .res 1
CasmSourceFileTable:      .res CASM_SOURCE_COUNT_MAX * 2
CasmSourceLoadIndex:      .res 1
CasmSourceLoadLastByte:   .res 1
CasmSourceStreamCursorLo: .res 1
CasmSourceStreamCursorHi: .res 1
CasmSourceAppendStartLo:  .res 1
CasmSourceAppendStartHi:  .res 1
; WP48 amendment: packed identity of the diagnostic line being drained. A
; child EOF may pop to its parent inside sourceFetchPhysical; the first parent
; byte is consumed but must never be appended to the child's displayed line.
CasmSourceDrainFileId:    .res 1

; ---------------------------------------------------------------------------
; Phase 10 WP51 listing capture: source-position tracking and the completed-
; line sidecar (WP50's "Phase 0C.20 Source-Span Freeze"). Exactly 11 bytes:
; four internal (this module only, no exported consumer) plus the seven-byte
; public sidecar listing.s reads after calling sourceTakeCompletedLine.
;
; CasmSourceBlockBaseLo/Hi is the absolute source-VMM address of the
; currently installed refill block; a fetched byte's own offset is block
; base plus block index, taken before advancement. CasmSourceLineStartLo/Hi
; tracks the first physical byte of the line currently being scanned; CR,
; LF, CRLF, EOF, frame push/pop, and synthetic separators all update it
; explicitly. Neither byte is exported: no consumer outside this module may
; reconstruct position from CasmSourceVmmCursorLo/Hi, and none may read
; these two pairs directly either -- only sourceTakeCompletedLine's sidecar
; below is the public contract.
CasmSourceBlockBaseLo:  .res 1
CasmSourceBlockBaseHi:  .res 1
CasmSourceLineStartLo:  .res 1
CasmSourceLineStartHi:  .res 1

; Completed-line sidecar. Published exactly once when a physical line
; completes; consumed (validity cleared) by sourceTakeCompletedLine. Length
; excludes CR/LF/CRLF. Flags: bit 0 VALID, bit 1 SYNTHETIC_ONLY, bit 2
; FINAL_UNTERMINATED, bits 3-7 reserved zero (CASM_SOURCE_COMPLETED_FLAG_*,
; common.inc).
CasmSourceCompletedStartLo: .res 1
CasmSourceCompletedStartHi: .res 1
CasmSourceCompletedLength:  .res 1
CasmSourceCompletedFileId:  .res 1
CasmSourceCompletedLineLo:  .res 1
CasmSourceCompletedLineHi:  .res 1
CasmSourceCompletedFlags:   .res 1

; ---------------------------------------------------------------------------
; WP46 nested-include frame stack (Phase 0C.19: 16 levels beyond a
; depth-zero top-level root). Plain BSS parallel arrays, 0-based, indexed
; by depth-1 while a frame at that depth is active or being saved/restored
; -- CasmFrameDepth itself is the 1-based count of currently active frames
; (0 = none, traversing a top-level root exactly as before Phase 9).
;
; CasmFrameCatalogIndex is the active chain's own physical identity, used
; only for cycle detection (Phase 0C.19: "scans the active frame chain
; only" -- a top-level root is never itself a catalog entry, so this
; array never needs to represent one). CasmFrameEndOffsetLo/Hi is the
; frame's own end in the combined store, sourceRefill's cap while that
; depth is active. CasmFrameResume* is the suspended parent's exact
; traversal state at the moment this depth was pushed, restored verbatim
; on pop.
; ---------------------------------------------------------------------------
CasmFrameDepth:           .res 1
CasmFrameCatalogIndex:    .res CASM_INCLUDE_MAX_DEPTH
; Root CLI identity retained with every frame so a diagnostic raised after
; multi-pop/root-transition lookahead can still name its originating root.
CasmFrameRootFileId:      .res CASM_INCLUDE_MAX_DEPTH
CasmFrameEndOffsetLo:     .res CASM_INCLUDE_MAX_DEPTH
CasmFrameEndOffsetHi:     .res CASM_INCLUDE_MAX_DEPTH
CasmFrameResumeOffsetLo:  .res CASM_INCLUDE_MAX_DEPTH
CasmFrameResumeOffsetHi:  .res CASM_INCLUDE_MAX_DEPTH
CasmFrameResumeLineLo:    .res CASM_INCLUDE_MAX_DEPTH
CasmFrameResumeLineHi:    .res CASM_INCLUDE_MAX_DEPTH
CasmFrameResumeColumn:    .res CASM_INCLUDE_MAX_DEPTH
CasmFrameResumePendingCr: .res CASM_INCLUDE_MAX_DEPTH
; WP51: the parent's CasmSourceLineStartLo/Hi at push time, restored
; verbatim on pop -- same resume-state precedent as CasmFrameResumeLine*
; above, added for listing capture's line-start anchor.
CasmFrameResumeLineStartLo: .res CASM_INCLUDE_MAX_DEPTH
CasmFrameResumeLineStartHi: .res CASM_INCLUDE_MAX_DEPTH

; WP48: the `.INCLUDE` statement's own start location at this depth's push.
; These are deliberately separate from CasmFrameResumeLine/Column, which are
; the parent's position after the whole statement and its consumed newline.
CasmFrameSiteLineLo:      .res CASM_INCLUDE_MAX_DEPTH
CasmFrameSiteLineHi:      .res CASM_INCLUDE_MAX_DEPTH
CasmFrameSiteColumn:      .res CASM_INCLUDE_MAX_DEPTH

.segment "CODE"

; ---------------------------------------------------------------------------
; sourceInit
; Initialize the complete 16-byte source subrecord to CLOSED/NONE with an
; initialized traversal cursor. Does not call fileIoInit, close a handle, or
; touch lexer state. Orchestration calls it after fileIoInit and before
; sourceOpen.
;
; Inputs:    none
; Outputs:   A = CASM_DIAG_NONE, C clear, Z set
; Preserves: X, Y
; Clobbers:  A, processor flags
; Scratch:   none
; ---------------------------------------------------------------------------
sourceInit:
    lda #CASM_SOURCE_API_NONE
    sta CasmSourceApiMode
    lda #CASM_SOURCE_STATE_CLOSED
    sta CasmSourceState
    jsr sourceResetTraversal
    lda #0
    sta CasmSourceVmmSlot
    sta CasmSourceLoadedLenLo
    sta CasmSourceLoadedLenHi
    sta CasmSourceTopLevelEndLo
    sta CasmSourceTopLevelEndHi
    sta CasmSourceVmmCursorLo
    sta CasmSourceVmmCursorHi
    sta CasmSourceLoadIndex
    sta CasmSourceLoadLastByte
    sta CasmSourceStreamCursorLo
    sta CasmSourceStreamCursorHi
    sta CasmSourceAppendStartLo
    sta CasmSourceAppendStartHi
    sta CasmFrameDepth
    ldx #(CASM_SOURCE_COUNT_MAX * 2) - 1
siClearFileTable:
    sta CasmSourceFileTable, x
    dex
    bpl siClearFileTable
    lda #CASM_DIAG_NONE
    clc
    rts

; ---------------------------------------------------------------------------
; sourceLoad (WP33, WP34: multi-file)
; Stream every parsed input file (CasmSourceNames[0 .. CasmSourceCount-1],
; cli.s) into one combined VMM allocation, in order. Opens each file through
; the Phase 2 wrapper, reads it in 256-byte CasmIoBuffer blocks via the
; existing inputStreamRead, and writes each block into the VMM allocation
; through up to four 64-byte vmmWindowWrite chunks (vmmWindowRead/Write
; always transfer through the fixed CasmVmmBuffer, so each chunk is staged
; there via a local copy first). Records each file's start offset into
; CasmSourceFileTable and, between files (never after the last), inserts one
; synthetic LF byte if the file's last written byte was not already a
; newline. Does not touch CasmSourceState -- the caller's following
; sourceOpen call commits READY.
;
; Unlike WP33's single-file cap (inherited for free from inputStreamRead's
; own per-file CasmInputTotalLo/Hi check), the *combined* 65535-byte cap
; across all files is not free once more than one file exists -- that
; per-file counter resets for every file inputStreamOpen opens. slCheckCap
; below is the explicit combined-cap check this requires.
;
; A failure at any step leaves whatever was already registered (the VMM
; slot, the input file handle) for the central resource owner's generic
; cleanup sweep to release -- no manual unwind is performed here, matching
; every other CASM init-path failure.
;
; Inputs:    source state CLOSED; parsed CasmSourceNames/CasmSourceCount;
;            initialized Phase 2 file services (input CLOSED)
; Outputs:   A = CASM_DIAG_NONE, C clear on success; CasmSourceVmmSlot holds
;            the granted registry slot; CasmSourceFileTable holds each
;            file's start offset; CasmSourceLoadedLenLo/Hi holds the total
;            combined bytes loaded; CasmSourceVmmCursorLo/Hi reset to 0
;            A = CASM_DIAG_*, C set on failure
; Preserves: none
; Clobbers:  A, X, Y, CasmSourceScratch0/1, CasmLexerScratch0/1, CasmIoBuffer,
;            CasmVmmBuffer, fileio.s/vmm_store.s volatile state
; Scratch:   CasmSourceScratch0/1 (16-bit remaining-in-block counter),
;            CasmLexerScratch0 (chunk source offset within the current
;            block) -- both source.s- and lexer.s-aliased cells are free
;            here: sourceLoad runs before lexerInit is ever called and
;            returns before any lexer call could observe them
; ---------------------------------------------------------------------------
sourceLoad:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_CLOSED
    bne slBadStateNear

    ldx #<CASM_SOURCE_VMM_MAX_BYTES
    ldy #>CASM_SOURCE_VMM_MAX_BYTES
    jsr vmmStoreAlloc
    bcs slFailNear
    stx CasmSourceVmmSlot

    lda #0
    sta CasmSourceVmmCursorLo
    sta CasmSourceVmmCursorHi
    sta CasmSourceLoadIndex
    jmp slFileLoop

; Trampolines: sourceLoad's early checks are out of direct branch range of
; the shared bad-state/failure tails defined near the end of the routine.
slBadStateNear:
    jmp slBadState
slFailNear:
    jmp slFail

slFileLoop:
    ; Record this file's start offset (CasmSourceFileTable, 2 bytes/entry).
    ldx CasmSourceLoadIndex
    txa
    asl
    tax
    lda CasmSourceVmmCursorLo
    sta CasmSourceFileTable, x
    lda CasmSourceVmmCursorHi
    sta CasmSourceFileTable + 1, x

    ; WP45: hand this file's streaming off to the shared per-file primitive
    ; (slCheckCap/slVmmWrite below) through CasmSourceStreamCursorLo/Hi --
    ; copied in from this loop's own running total here, and copied back out
    ; once the file (plus any synthetic newline) is fully written, at
    ; slAdvanceIndex below.
    lda CasmSourceVmmCursorLo
    sta CasmSourceStreamCursorLo
    lda CasmSourceVmmCursorHi
    sta CasmSourceStreamCursorHi

    ; This file's slot pointer, via cli.s's shared lookup table.
    ldy CasmSourceLoadIndex
    lda cliSourceSlotLo, y
    tax
    lda cliSourceSlotHi, y
    tay
    jsr inputStreamOpen
    bcs slFailNear

slReadLoop:
    jsr inputStreamRead
    bcs slFailNear
    cmp #CASM_STREAM_EOF
    beq slFileDoneNear

    ; DATA: CasmIoLenLo/Hi = 1..256 bytes now in CasmIoBuffer (256 encodes as
    ; Hi=1/Lo=0). Reject before committing to write this block if it would
    ; push the combined total past the cap.
    jsr slCheckCap
    bcs slFailNear

    ; Stage the block's remaining-to-write counter and the chunk source
    ; offset, then drain it in <=64-byte chunks.
    lda CasmIoLenLo
    sta CasmSourceScratch0
    lda CasmIoLenHi
    sta CasmSourceScratch1
    lda #0
    sta CasmLexerScratch0

slWriteChunkLoop:
    lda CasmSourceScratch0
    ora CasmSourceScratch1
    beq slReadLoop               ; block fully written -> read the next one

    lda CasmSourceScratch1
    bne slWriteChunkFull         ; remaining hi != 0 -> remaining > 255
    lda CasmSourceScratch0
    cmp #CASM_VMM_BUFFER_SIZE + 1
    bcs slWriteChunkFull         ; remaining >= 64 -> full chunk
    sta CasmIoLenLo               ; partial final chunk: chunkLen = remaining
    lda #0
    sta CasmIoLenHi
    jmp slWriteChunkStage
slWriteChunkFull:
    lda #CASM_VMM_BUFFER_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi

slWriteChunkStage:
    ; Source pointer = CasmIoBuffer + CasmLexerScratch0.
    lda CasmLexerScratch0
    clc
    adc #<CasmIoBuffer
    sta CasmIoPtrLo
    lda #>CasmIoBuffer
    adc #0
    sta CasmIoPtrHi

    ; Stage this chunk into CasmVmmBuffer (vmmWindowWrite's fixed source).
    ldy #0
slWriteCopyLoop:
    cpy CasmIoLenLo
    beq slWriteCopyDone
    lda (CasmIoPtrLo), y
    sta CasmVmmBuffer, y
    iny
    jmp slWriteCopyLoop
slWriteCopyDone:

    ; Track the last byte of this chunk for the inter-file synthetic-newline
    ; decision below (only consulted once this file's read loop reaches
    ; EOF; cheap to keep current on every chunk).
    ldy CasmIoLenLo
    dey
    lda CasmVmmBuffer, y
    sta CasmSourceLoadLastByte

    jsr slVmmWrite
    bcs slWriteFailNear

    ; Advance the chunk source offset by chunkLen; decrement the block's
    ; remaining-to-write counter by the same amount (slVmmWrite already
    ; advanced the combined VMM cursor).
    lda CasmLexerScratch0
    clc
    adc CasmIoLenLo
    sta CasmLexerScratch0

    lda CasmSourceScratch0
    sec
    sbc CasmIoLenLo
    sta CasmSourceScratch0
    lda CasmSourceScratch1
    sbc CasmIoLenHi
    sta CasmSourceScratch1
    jmp slWriteChunkLoop

slWriteFailNear:
    jmp slFail
slFileDoneNear:
    jmp slFileDone

slFileDone:
    jsr inputStreamClose
    bcs slWriteFailNear

    ; Synthetic inter-file newline: only between files (never after the
    ; last) and only when this file's last byte was not already a newline.
    lda CasmSourceLoadIndex
    clc
    adc #1
    cmp CasmSourceCount
    bcs slAdvanceIndex            ; this was the last file -- no trailing newline

    lda CasmSourceLoadLastByte
    cmp #CASM_PETSCII_CR
    beq slAdvanceIndex
    cmp #CASM_PETSCII_LF
    beq slAdvanceIndex

    lda #1
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    jsr slCheckCap
    bcs slWriteFailNear
    lda #CASM_PETSCII_LF
    sta CasmVmmBuffer + 0
    jsr slVmmWrite
    bcs slWriteFailNear

slAdvanceIndex:
    ; WP45: copy this file's (plus any synthetic newline's) advanced stream
    ; cursor back into this loop's own running total.
    lda CasmSourceStreamCursorLo
    sta CasmSourceVmmCursorLo
    lda CasmSourceStreamCursorHi
    sta CasmSourceVmmCursorHi
    inc CasmSourceLoadIndex
    lda CasmSourceLoadIndex
    cmp CasmSourceCount
    bcc slFileLoopNear
    jmp slAllDone
slFileLoopNear:
    jmp slFileLoop

slAllDone:
    lda CasmSourceVmmCursorLo
    sta CasmSourceLoadedLenLo
    sta CasmSourceTopLevelEndLo   ; WP46 fix: fixed snapshot before any
    lda CasmSourceVmmCursorHi     ; .INCLUDE child ever gets appended
    sta CasmSourceLoadedLenHi
    sta CasmSourceTopLevelEndHi
    lda #0
    sta CasmSourceVmmCursorLo
    sta CasmSourceVmmCursorHi
    lda #CASM_DIAG_NONE
    clc
    rts

slBadState:
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts
slFail:
    ; A already holds the failing call's own diagnostic; whatever it already
    ; registered (VMM slot, file handle) is released by central cleanup.
    sec
    rts

; ---------------------------------------------------------------------------
; slCheckCap (private, WP34; WP45: retargeted to the shared stream cursor)
; Verify CasmSourceStreamCursorLo/Hi + CasmIoLenLo/Hi does not exceed
; CASM_SOURCE_VMM_MAX_BYTES (65535), the combined multi-file cap. Because
; that cap is exactly the largest 16-bit value, a 16-bit add of cursor+count
; that does not carry is always within the cap (result <= 65535 by
; construction) and one that does carry always exceeds it (true sum >=
; 65536): no comparison beyond the carry flag itself is needed. Does not
; modify the cursor. Shared by sourceLoad's per-file loop (via the
; copy-in/copy-out at slFileLoop/slAdvanceIndex above) and sourceAppendFile
; below -- both stage the cursor they mean into CasmSourceStreamCursorLo/Hi
; before calling this.
;
; Inputs:    CasmIoLenLo/Hi = byte count about to be written
; Outputs:   C clear if the advance is within the cap; C set with
;            A = CASM_DIAG_SOURCE_OFFSET_OVERFLOW otherwise
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
slCheckCap:
    lda CasmSourceStreamCursorLo
    clc
    adc CasmIoLenLo
    lda CasmSourceStreamCursorHi
    adc CasmIoLenHi
    bcs slcOverflow
    clc
    rts
slcOverflow:
    lda #CASM_DIAG_SOURCE_OFFSET_OVERFLOW
    sec
    rts

; ---------------------------------------------------------------------------
; slVmmWrite (private, WP33/WP34; WP45: retargeted to the shared stream
; cursor)
; Write CasmIoLenLo/Hi bytes already staged in CasmVmmBuffer at the current
; shared stream cursor (CasmSourceStreamCursorLo/Hi), then advance the
; cursor by that count. Shared by the main per-file chunk-write loop, the
; synthetic inter-file newline, and sourceAppendFile below -- every place
; this module transfers staged bytes into the VMM allocation. The caller
; must already have checked the combined cap (slCheckCap) before calling.
;
; Inputs:    CasmIoLenLo/Hi = byte count staged in CasmVmmBuffer
; Outputs:   C clear on success; CasmSourceStreamCursorLo/Hi advanced
;            C set, A = CASM_DIAG_VMM_TRANSFER_FAILED on failure (cursor
;            unchanged)
; Clobbers:  A, X, Y, CasmVmmOffLo/Hi and vmmWindowWrite's own volatile state
; ---------------------------------------------------------------------------
slVmmWrite:
    lda CasmSourceStreamCursorLo
    sta CasmVmmOffLo
    lda CasmSourceStreamCursorHi
    sta CasmVmmOffHi
    ldx CasmSourceVmmSlot
    jsr vmmWindowWrite
    bcs slvwFail

    lda CasmSourceStreamCursorLo
    clc
    adc CasmIoLenLo
    sta CasmSourceStreamCursorLo
    lda CasmSourceStreamCursorHi
    adc CasmIoLenHi
    sta CasmSourceStreamCursorHi
    clc
    rts
slvwFail:
    rts

; ---------------------------------------------------------------------------
; sourceAppendFile (WP45)
; Stream exactly one more file into the already-loaded VMM source allocation,
; appending at the true end of loaded content (CasmSourceLoadedLenLo/Hi) --
; never at CasmSourceVmmCursorLo/Hi, which may currently be live traversal
; read-cursor state if this is called between sourceOpen and sourceClose.
; This routine neither reads nor writes CasmSourceVmmCursorLo/Hi, CasmIoBuffer
; refill state, CasmSourceFileTable, or CasmSourceLoadIndex -- those remain
; exclusively sourceLoad's/sourceRefill's. No synthetic newline is inserted:
; that behavior is specific to sourceLoad's flat multi-top-level-file
; concatenation and does not apply to one included file's own span.
;
; Inputs:    loading already completed via sourceLoad, so CasmSourceVmmSlot
;            is a valid granted slot -- this routine never reads
;            CasmSourceState itself, so it may be called with source CLOSED
;            (right after sourceLoad, before sourceOpen), READY, or EOF;
;            X/Y = null-terminated filename pointer (already resolved/
;            prefixed by the caller if a non-default device is needed --
;            this routine performs no device resolution of its own)
; Outputs:   Success: A = CASM_DIAG_NONE, C clear; CasmSourceLoadedLenLo/Hi
;            advanced by the appended byte count; CasmValue0Lo/Hi = this
;            file's start offset (the pre-call total), CasmValue1Lo/Hi =
;            the appended byte count
;            Failure: A = CASM_DIAG_*, C set (propagated open/read/close/
;            cap/transfer diagnostic); CasmSourceLoadedLenLo/Hi unchanged
; Preserves: CasmSourceVmmCursorLo/Hi (untouched)
; Clobbers:  A, X, Y, CasmSourceScratch0/1, CasmLexerScratch0, CasmIoBuffer,
;            CasmVmmBuffer, CasmSourceStreamCursorLo/Hi,
;            CasmSourceAppendStartLo/Hi, CasmValue0Lo/Hi, CasmValue1Lo/Hi,
;            fileio.s/vmm_store.s volatile state
; ---------------------------------------------------------------------------
sourceAppendFile:
    ; Remember this file's start (the pre-call total) in a dedicated field,
    ; not CasmValue0Lo/Hi: vwPrepareTransfer (vmm_store.s, reached via
    ; slVmmWrite on every chunk write below) documents CasmValue0Lo/Hi as its
    ; own offset+count scratch and clobbers it on the very first chunk --
    ; the same shared-scratch-clobber bug class that hit vmm_store.s three
    ; times in WP23-25. CasmValue0Lo/Hi is only written, once, at the very
    ; end (safFileDone) for the caller's benefit.
    lda CasmSourceLoadedLenLo
    sta CasmSourceAppendStartLo
    sta CasmSourceStreamCursorLo
    lda CasmSourceLoadedLenHi
    sta CasmSourceAppendStartHi
    sta CasmSourceStreamCursorHi

    jsr inputStreamOpen
    bcs safFail

safReadLoop:
    jsr inputStreamRead
    bcs safFail
    cmp #CASM_STREAM_EOF
    beq safFileDoneNear

    jsr slCheckCap
    bcs safFail

    lda CasmIoLenLo
    sta CasmSourceScratch0
    lda CasmIoLenHi
    sta CasmSourceScratch1
    lda #0
    sta CasmLexerScratch0

safWriteChunkLoop:
    lda CasmSourceScratch0
    ora CasmSourceScratch1
    beq safReadLoop              ; block fully written -> read the next one

    lda CasmSourceScratch1
    bne safWriteChunkFull        ; remaining hi != 0 -> remaining > 255
    lda CasmSourceScratch0
    cmp #CASM_VMM_BUFFER_SIZE + 1
    bcs safWriteChunkFull        ; remaining >= 64 -> full chunk
    sta CasmIoLenLo               ; partial final chunk: chunkLen = remaining
    lda #0
    sta CasmIoLenHi
    jmp safWriteChunkStage
safWriteChunkFull:
    lda #CASM_VMM_BUFFER_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi

safWriteChunkStage:
    lda CasmLexerScratch0
    clc
    adc #<CasmIoBuffer
    sta CasmIoPtrLo
    lda #>CasmIoBuffer
    adc #0
    sta CasmIoPtrHi

    ldy #0
safWriteCopyLoop:
    cpy CasmIoLenLo
    beq safWriteCopyDone
    lda (CasmIoPtrLo), y
    sta CasmVmmBuffer, y
    iny
    jmp safWriteCopyLoop
safWriteCopyDone:

    jsr slVmmWrite
    bcs safFail

    lda CasmLexerScratch0
    clc
    adc CasmIoLenLo
    sta CasmLexerScratch0

    lda CasmSourceScratch0
    sec
    sbc CasmIoLenLo
    sta CasmSourceScratch0
    lda CasmSourceScratch1
    sbc CasmIoLenHi
    sta CasmSourceScratch1
    jmp safWriteChunkLoop

safFileDoneNear:
    jmp safFileDone
safFail:
    rts                          ; A/C already set by the failing call

safFileDone:
    jsr inputStreamClose
    bcs safFail

    ; Commit: the shared stream cursor is now this file's end. The appended
    ; length is end - start (CasmSourceAppendStartLo/Hi, staged before the
    ; open above). CasmValue0Lo/Hi and CasmValue1Lo/Hi are written here, for
    ; the first time, only now that no further clobbering call remains.
    lda CasmSourceStreamCursorLo
    sta CasmSourceLoadedLenLo
    sec
    sbc CasmSourceAppendStartLo
    sta CasmValue1Lo
    lda CasmSourceStreamCursorHi
    sta CasmSourceLoadedLenHi
    sbc CasmSourceAppendStartHi
    sta CasmValue1Hi
    lda CasmSourceAppendStartLo
    sta CasmValue0Lo
    lda CasmSourceAppendStartHi
    sta CasmValue0Hi
    lda #CASM_DIAG_NONE
    clc
    rts

; ---------------------------------------------------------------------------
; sourceOpen
; Reset the traversal cursor to the start of the already-loaded VMM content
; (WP33: sourceLoad performs the real OS/VMM work above; sourceOpen itself
; makes no OS call and cannot fail except on a bad precondition state).
;
; Inputs:    source state CLOSED; content already loaded via sourceLoad
; Outputs:   A = CASM_DIAG_NONE, C clear; state READY, API BYTE
;            A = CASM_DIAG_STREAM_STATE_FAILED, C set on a bad precondition
; Preserves: none
; Clobbers:  A, X, Y, source scratch
; Scratch:   none
; ---------------------------------------------------------------------------
sourceOpen:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_CLOSED
    bne soBadState
    lda #CASM_SOURCE_STATE_READY
    sta CasmSourceState
    lda #CASM_SOURCE_API_BYTE
    sta CasmSourceApiMode
    lda #0
    sta CasmSourceVmmCursorLo
    sta CasmSourceVmmCursorHi
    jsr sourceResetTraversal
    lda #CASM_DIAG_NONE
    clc
    rts
soBadState:
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; sourceNextByte (WP5 normalized ABI)
; Return the next normalized result: a raw non-newline byte, one collapsed
; newline for CR/LF/CRLF, a repeat-stable EOF, or a failure. The raw byte is
; delivered in CasmSourceResultByte and never inferred from A or Z; the byte is
; 0 for NEWLINE and EOF.
;
; Inputs:    source state READY/BYTE or EOF/BYTE; API mode BYTE
; Outputs:   Byte:    A = CASM_SOURCE_BYTE, C clear, Z clear;
;                     CasmSourceResultByte = raw byte at (line, column)
;            Newline: A = CASM_SOURCE_NEWLINE, C clear, Z clear;
;                     CasmSourceResultByte = 0
;            EOF:     A = CASM_SOURCE_EOF, C clear, Z clear;
;                     CasmSourceResultByte = 0
;            Fail:    A = CASM_DIAG_*, C set; source state ERROR
; Preserves: none
; Clobbers:  A, X, Y, source scratch (CasmSourceScratch0), refill/OS volatile
;            state on refill
; Scratch:   CasmSourceScratch0 holds the current physical byte
;
; The mode gate rejects a byte call once line mode has been claimed; the two
; APIs cannot be mixed without an explicit sourceRewind. sourceNextLine shares
; the normalization below through the private sourceNextResult entry, which
; carries no mode gate.
; ---------------------------------------------------------------------------
sourceNextByte:
    lda CasmSourceApiMode
    cmp #CASM_SOURCE_API_BYTE
    beq sourceNextResult
    jmp snbBadState             ; LINE claimed or NONE -> API mixing/state failure

; ---------------------------------------------------------------------------
; sourceNextResult (private)
; The WP5 normalized traversal without the API mode gate. sourceNextByte and
; sourceNextLine both enter here.
; ---------------------------------------------------------------------------
sourceNextResult:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_EOF
    beq snbEofNear
    cmp #CASM_SOURCE_STATE_READY
    bne snbBadStateNear
    jmp snbFetch

; Trampolines: the WP15 line echo lengthened the byte-return path, pushing the
; shared result and failure tails out of branch range from here.
snbEofNear:
    jmp snbEof
snbBadStateNear:
    jmp snbBadState
snbFailNear:
    jmp snbFail

snbFetch:
    jsr sourceFetchPhysical
    bcs snbFailNear             ; fetch error; source already ERROR
    cmp #CASM_SOURCE_EOF
    beq snbEofFromFetch
    ; A = CASM_STREAM_DATA; the physical byte is in CasmSourceScratch0.

    ; Pending-CR latch: if the previous result was a CR newline and this byte is
    ; the LF half of a CRLF, swallow it (its offset is already counted) and fetch
    ; the following byte. Any other byte ends the pending state.
    lda CasmSourcePendingCr
    beq snbClassify
    lda #0
    sta CasmSourcePendingCr
    lda CasmSourceScratch0
    cmp #CASM_PETSCII_LF
    bne snbClassify
    ; WP51: sourceCaptureNewline already re-anchored CasmSourceLineStartLo/Hi
    ; at the CR, one byte short of this now-confirmed CRLF's true next-line
    ; start (it could not yet know an LF would follow). Nudge it by the one
    ; byte this swallow just consumed, unconditionally -- harmless when
    ; capture is disabled, since nothing reads the anchor in that case.
    inc CasmSourceLineStartLo
    bne snbFetch
    inc CasmSourceLineStartHi
    jmp snbFetch

snbClassify:
    lda CasmSourceScratch0
    cmp #CASM_PETSCII_CR
    beq snbNewlineCr
    cmp #CASM_PETSCII_LF
    beq snbNewlineLf

    ; Normal byte at the current column; the exhausted latch (column 0) means a
    ; further byte on this line would overflow the 8-bit column.
    lda CasmSourceColumn
    beq snbColumnOverflow
    lda CasmSourceScratch0
    sta CasmSourceResultByte
    ; Advance the column: 255 enters the exhausted latch, otherwise increment.
    lda CasmSourceColumn
    cmp #CASM_SOURCE_COLUMN_MAX
    bcc snbColumnInc            ; column < 255
    lda #0                      ; column == 255 -> exhausted latch
    sta CasmSourceColumn
    jmp snbByteReturn
snbColumnInc:
    inc CasmSourceColumn
snbByteReturn:
    ; WP15: echo the delivered byte into the diagnostic line buffer. Capture
    ; happens here, in the source layer, rather than in the lexer because the
    ; lexer discards whitespace and comment bodies without recording them; a
    ; line echoed from there would have holes in it and misalign the caret.
    lda CasmDiagCapture
    beq snbEchoDone
    lda CasmSourceResultByte
    jsr diagLineAppend
snbEchoDone:
    lda #CASM_SOURCE_BYTE
    clc
    rts

snbNewlineLf:
    ; LF newline: pending-CR stays clear.
    jsr sourceAdvanceNewline
    bcs snbLocFail
    lda #0
    sta CasmSourceResultByte
    lda #CASM_SOURCE_NEWLINE
    clc
    rts
snbNewlineCr:
    ; CR newline: emit one newline now and arm the pending-CR latch so an
    ; immediately following LF collapses into this CRLF.
    jsr sourceAdvanceNewline
    bcs snbLocFail
    lda #1
    sta CasmSourcePendingCr
    lda #0
    sta CasmSourceResultByte
    lda #CASM_SOURCE_NEWLINE
    clc
    rts

snbEof:
    ; Repeat-stable EOF: no OS read, no cursor mutation. CasmSourceResultByte
    ; was cleared when EOF was first committed.
    lda #CASM_SOURCE_EOF
    clc
    rts
snbEofFromFetch:
    ; sourceFetchPhysical committed EOF and cleared CasmSourceResultByte. Clear
    ; pending-CR: a final CR already emitted its newline before this EOF.
    lda #0
    sta CasmSourcePendingCr
    lda #CASM_SOURCE_EOF
    clc
    rts
snbFail:
    ; A holds the fetch diagnostic; source state is already ERROR.
    sec
    rts
snbLocFail:
    ; sourceAdvanceNewline set source ERROR and left A = diagnostic, C set.
    sec
    rts
snbColumnOverflow:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_SOURCE_LOCATION_OVERFLOW
    sec
    rts
snbBadState:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; sourceNextLine
; Return one bounded logical line. The payload is CasmIoBuffer[0 .. length-1],
; null-terminated at [length]; a 255-byte payload plus terminator exactly fills
; the 256-byte buffer. The line is valid only until the next source call.
;
; Line mode is claimed here on a fresh stream and reuses the WP5 normalization
; through sourceNextResult, so newline collapsing, provenance, and EOF behave
; exactly as in byte mode. While a line is built, CasmIoBuffer is partitioned:
; [0 .. lineLength-1] is the payload and [lineLength .. 255] is the unread
; transfer region that sourceRefill reads into.
;
; Buffer-aliasing safety: the write position (CasmSourceLineLength) is always
; less than or equal to the read position (CasmSourceBlockIndex). They are equal
; only immediately after a LINE-mode refill, and because sourceNextResult loads
; the byte into CasmSourceResultByte before it is stored here, that case is a
; read-then-write of the same cell. A CRLF swallow or a newline advances the
; read position without advancing the write position, only widening the margin.
;
; Inputs:    line mode claimed or claimable; state READY or EOF
; Outputs:   Line: A = CASM_SOURCE_NEWLINE, C clear; CasmSourceLineLength = length,
;                  CasmSourceLineState = READY (newline) or EOF (final partial)
;            EOF:  A = CASM_SOURCE_EOF, C clear; CasmSourceLineLength = 0
;            Fail: A = CASM_DIAG_STREAM_STATE_FAILED, CASM_DIAG_SOURCE_LINE_TOO_LONG,
;                  CASM_DIAG_INVALID_SOURCE_BYTE, or a propagated byte
;                  diagnostic; C set; source state ERROR
; Preserves: none
; Clobbers:  A, X, Y, source scratch, refill/OS volatile state
; ---------------------------------------------------------------------------
sourceNextLine:
    lda CasmSourceApiMode
    cmp #CASM_SOURCE_API_LINE
    beq snlModeReady            ; line mode already claimed
    cmp #CASM_SOURCE_API_BYTE
    bne snlBadStateNear         ; NONE -> not open
    ; Byte mode may be promoted to line mode only on a fresh stream. Once any
    ; byte has been consumed, mixing the APIs requires an explicit rewind.
    lda CasmSourceOffsetLo
    ora CasmSourceOffsetHi
    bne snlBadStateNear
    lda CasmSourceLineState
    cmp #CASM_SOURCE_LINE_IDLE
    bne snlBadStateNear
    lda #CASM_SOURCE_API_LINE
    sta CasmSourceApiMode
    jmp snlModeReady

snlBadStateNear:
    ; Trampoline: the shared failure tail is out of branch range from here.
    jmp snlBadState

snlModeReady:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_EOF
    beq snlEof
    cmp #CASM_SOURCE_STATE_READY
    bne snlBadStateNear

    lda #0
    sta CasmSourceLineLength
    lda #CASM_SOURCE_LINE_BUILDING
    sta CasmSourceLineState

snlLoop:
    jsr sourceNextResult
    bcs snlFail                 ; source already ERROR
    cmp #CASM_SOURCE_NEWLINE
    beq snlLineReady
    cmp #CASM_SOURCE_EOF
    beq snlEofReached

    ; Byte: an embedded null is invalid source in the line API (byte mode still
    ; returns it as a valid CASM_SOURCE_BYTE).
    lda CasmSourceResultByte
    beq snlInvalidByte
    ; Reject an overlong line before storing the overflowing byte.
    lda CasmSourceLineLength
    cmp #CASM_SOURCE_LINE_PAYLOAD_MAX
    bcs snlTooLong              ; already 255 payload bytes
    ldx CasmSourceLineLength
    lda CasmSourceResultByte
    sta CasmIoBuffer,x
    inc CasmSourceLineLength
    jmp snlLoop

snlLineReady:
    lda #CASM_SOURCE_LINE_READY
    sta CasmSourceLineState
snlReturnLine:
    ; Terminate at [length]. That cell is always an already-consumed byte or is
    ; past valid data, never unread input.
    ldx CasmSourceLineLength
    lda #0
    sta CasmIoBuffer,x
    lda #CASM_SOURCE_NEWLINE
    clc
    rts

snlEofReached:
    ; EOF while building: return a final unterminated line if one accumulated,
    ; otherwise report EOF. CasmSourceLineState distinguishes the two.
    lda #CASM_SOURCE_LINE_EOF
    sta CasmSourceLineState
    lda CasmSourceLineLength
    bne snlReturnLine
snlEof:
    lda #0
    sta CasmSourceLineLength
    lda #CASM_SOURCE_LINE_EOF
    sta CasmSourceLineState
    lda #CASM_SOURCE_EOF
    clc
    rts

snlFail:
    ; A holds the propagated byte diagnostic.
    sec
    rts
snlInvalidByte:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_INVALID_SOURCE_BYTE
    sec
    rts
snlTooLong:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_SOURCE_LINE_TOO_LONG
    sec
    rts
snlBadState:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; sourceDrainLineTail (WP15, diagnostic-only and TERMINAL)
; Append the remainder of the current physical line to the diagnostic echo
; buffer, stopping at CR, LF, EOF, a full buffer, or any read failure.
;
; The echo buffer ends at the byte that failed, because that is the last byte
; traversal delivered. Without this routine a diagnostic can only ever show the
; source up to the caret, never the text after it.
;
; CONTRACT -- read before calling:
;   * Call only on the fatal path, immediately before central cleanup. The
;     caller must already have decided to terminate.
;   * This routine deliberately bypasses the source state gate: it runs after
;     the source has been driven into ERROR, which is the whole point. It reads
;     raw physical bytes and does not maintain the line, column, offset, or
;     pending-CR invariants that the normalized traversal guarantees.
;   * It therefore leaves the source unusable for further traversal. Calling it
;     anywhere other than the fatal path will corrupt an in-progress assembly.
;   * It never reports a diagnostic of its own. Any failure silently truncates
;     the displayed line rather than masking the caller's primary diagnostic,
;     which is the diagnostic the user actually needs.
;
; The input stream is still open at this point: casm.s routes a fatal through
; startFatal -> exitFatal -> diagPrintFatal (here) -> resourcesCleanup, and the
; close happens in that last step.
;
; Inputs:    valid echo buffer contents for the current line
; Outputs:   CasmDiagLineLen extended; CasmDiagLineClipped set on overflow
; Preserves: nothing
; Clobbers:  A, X, Y, source scratch, refill/OS volatile state
; ---------------------------------------------------------------------------
sourceDrainLineTail:
    lda CasmDiagLocFileId
    sta CasmSourceDrainFileId
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_EOF
    beq sdtDone                 ; nothing further to read
sdtLoop:
    lda CasmDiagLineLen
    cmp #CASM_DIAG_LINE_MAX
    bcs sdtDone                 ; buffer full: diagLineAppend already latched it
    jsr sourceFetchPhysical
    bcs sdtDone                 ; read failure: keep what was already captured
    ; sourceFetchPhysical resolves frame EOF by popping and returning the next
    ; parent byte. Stop before appending when that delivered byte's packed
    ; provenance differs from the diagnostic line's identity.
    pha
    lda CasmSourceResultFileId
    cmp CasmSourceDrainFileId
    bne sdtDifferentFile
    pla
    cmp #CASM_SOURCE_EOF
    beq sdtDone
    ; Raw byte: a newline in either encoding ends the line. No normalization is
    ; attempted, since a display tail does not need the pending-CR latch.
    lda CasmSourceScratch0
    cmp #CASM_PETSCII_CR
    beq sdtDone
    cmp #CASM_PETSCII_LF
    beq sdtDone
    jsr diagLineAppend
    jmp sdtLoop
sdtDifferentFile:
    pla
sdtDone:
    rts

; ---------------------------------------------------------------------------
; diagLineAppend (private, WP15)
; Append one byte to whichever echo buffer is currently selected, latching the
; truncation flag instead of overflowing.
;
; Shared by the normalized echo in sourceNextResult and by the fatal-path
; drain, so buffer selection and bounds live in exactly one place.
;
; Inputs:    A = byte to append
; Outputs:   CasmDiagLineLen advanced, or CasmDiagLineClipped latched
; Preserves: nothing
; Clobbers:  A, X, Y, processor flags
; ---------------------------------------------------------------------------
diagLineAppend:
    ldx CasmDiagLineLen
    cpx #CASM_DIAG_LINE_MAX
    bcs dlaFull
    ldy CasmDiagLineSel
    bne dlaBufB
    sta CasmDiagLineBufA,x
    jmp dlaCommit
dlaBufB:
    sta CasmDiagLineBufB,x
dlaCommit:
    inc CasmDiagLineLen
    rts
dlaFull:
    lda #1
    sta CasmDiagLineClipped
    rts

; ---------------------------------------------------------------------------
; sourceRewind
; Reset every source-owned field so a second traversal of the already-loaded
; VMM content is byte-, newline-, and location-identical to the first (WP33:
; no OS call -- the content was loaded once by sourceLoad and is never
; re-read from disk). Textually the same reset sourceOpen performs.
;
; Lookahead invalidation is deliberately not performed here: lookahead is lexer
; state and this module writes none. WP7 owns invalidating CasmLookahead* after
; a rewind.
;
; Inputs:    source state READY or EOF
; Outputs:   Success: A = CASM_DIAG_NONE, C clear; state READY, API BYTE, reset
;            Fail:    A = CASM_DIAG_STREAM_STATE_FAILED, C set, on a bad
;                     precondition state
; Preserves: none
; Clobbers:  A, X, Y, source scratch
; ---------------------------------------------------------------------------
sourceRewind:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_READY
    beq srwReset
    cmp #CASM_SOURCE_STATE_EOF
    bne srwBadState
srwReset:
    lda #CASM_SOURCE_STATE_READY
    sta CasmSourceState
    lda #CASM_SOURCE_API_BYTE
    sta CasmSourceApiMode
    lda #0
    sta CasmSourceVmmCursorLo
    sta CasmSourceVmmCursorHi
    jsr sourceResetTraversal
    lda #CASM_DIAG_NONE
    clc
    rts
srwBadState:
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; sourceGetLocation
; Validate that the next result's provenance is available and representable,
; leaving it readable in the persistent source fields. This is an in-place
; snapshot accessor: the canonical location already lives in CasmSourceFileId,
; CasmSourceOffsetLo/Hi, CasmSourceLineLo/Hi, and CasmSourceColumn, describing
; the next result. A caller reads them immediately and copies them before the
; next mutating call.
;
; Inputs:    source state READY or EOF
; Outputs:   Success: A = CASM_DIAG_NONE, C clear; location fields readable
;            Fail:    A = CASM_DIAG_SOURCE_LOCATION_OVERFLOW (pending column
;                     overflow in READY) or CASM_DIAG_STREAM_STATE_FAILED
;                     (invalid state), C set; state unchanged
; Preserves: X, Y
; Clobbers:  A, processor flags
; Scratch:   none
; ---------------------------------------------------------------------------
sourceGetLocation:
    lda CasmSourceState
    cmp #CASM_SOURCE_STATE_EOF
    beq sglOk                   ; EOF: location is final, no next byte to overflow
    cmp #CASM_SOURCE_STATE_READY
    bne sglBadState
    ; READY: reject a pending column-exhausted latch, since the next byte would
    ; overflow the 8-bit column.
    lda CasmSourceColumn
    beq sglOverflow
sglOk:
    lda #CASM_DIAG_NONE
    clc
    rts
sglOverflow:
    lda #CASM_DIAG_SOURCE_LOCATION_OVERFLOW
    sec
    rts
sglBadState:
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; sourceComputePackedFileId (private, WP48)
; Compute the packed provenance byte a fetched byte should carry: bit 7 set
; and bits 0-6 the active frame's own catalog index when a nested `.INCLUDE`
; frame is active, or bit 7 clear and bits 0-6 the plain top-level index
; otherwise. See common.inc's CASM_DIAG_FILEID_FRAME_FLAG/ID_MASK header for
; the full rationale: this replaces the pre-WP48 behavior of always
; reporting the outermost top-level file's index, even for a byte fetched
; from deep inside a nested include.
;
; Inputs:    none
; Outputs:   A = packed FILE_ID byte
; Preserves: none
; Clobbers:  A, X, processor flags
; ---------------------------------------------------------------------------
sourceComputePackedFileId:
    lda CasmFrameDepth
    beq scpfRoot
    tax
    dex
    lda CasmFrameCatalogIndex, x
    ora #CASM_DIAG_FILEID_FRAME_FLAG
    rts
scpfRoot:
    lda CasmSourceFileId
    rts

; ---------------------------------------------------------------------------
; sourceFetchPhysical (private)
; Fetch one physical byte from the current block, refilling when the block is
; exhausted. Every fetched byte advances the checked block index and physical
; offset so the offset stays equal to CasmInputTotal at EOF.
;
; Inputs:    source state READY
; Outputs:   Data: A = CASM_STREAM_DATA, C clear; CasmSourceScratch0 = byte,
;                  block index and physical offset advanced
;            EOF:  A = CASM_SOURCE_EOF, C clear; state EOF committed, result
;                  byte cleared (via sourceRefill)
;            Fail: A = CASM_DIAG_*, C set; source state ERROR
; Preserves: none
; Clobbers:  A, X, Y, refill/OS volatile state on refill
; ---------------------------------------------------------------------------
sourceFetchPhysical:
    ; Unsigned 16-bit index < length test decides availability.
    lda CasmSourceBlockIndexLo
    cmp CasmSourceBlockLenLo
    lda CasmSourceBlockIndexHi
    sbc CasmSourceBlockLenHi
    bcc sfpHaveByte             ; index < length -> a byte is available

    ; index >= length: only an exact index == length may refill; index above
    ; length is a corrupt cursor and a stream-state failure.
    lda CasmSourceBlockIndexLo
    cmp CasmSourceBlockLenLo
    bne sfpCursorFailNear
    lda CasmSourceBlockIndexHi
    cmp CasmSourceBlockLenHi
    bne sfpCursorFailNear

    jsr sourceRefill
    bcc sfpRefillOk
    jmp sfpFail                 ; refill failed; source already ERROR
sfpRefillOk:
    cmp #CASM_SOURCE_EOF
    beq sfpEof
    ; Refill installed a nonempty block with index 0; a byte is now available.
    jmp sfpHaveByte

; Trampoline: sfpCursorFail is out of direct branch range from the checks
; above (the WP46 provenance-capture insert below pushed it further away).
sfpCursorFailNear:
    jmp sfpCursorFail

sfpHaveByte:
    ; WP46 fix: capture this byte's true provenance now -- any refill/pop/
    ; root-transition this call needed has already been committed above,
    ; and this byte's own column/line-advance side effects (in
    ; sourceNextByte, above this layer) have not run yet. See the field
    ; declarations' own header comment.
    ; WP48: FileId is now the packed (kind, id) byte -- see
    ; sourceComputePackedFileId's own header -- so a byte fetched from
    ; inside a nested `.INCLUDE` frame carries that frame's own catalog
    ; identity, not the outermost top-level file's index.
    jsr sourceComputePackedFileId
    sta CasmSourceResultFileId
    lda CasmSourceLineLo
    sta CasmSourceResultLineLo
    lda CasmSourceLineHi
    sta CasmSourceResultLineHi
    lda CasmSourceColumn
    bne sfpResultColumnStore
    lda #CASM_SOURCE_COLUMN_MAX  ; exhausted latch -> report the max column
sfpResultColumnStore:
    sta CasmSourceResultColumn

    ; Offset overflow is validated before any cursor or byte is committed.
    lda CasmSourceOffsetLo
    cmp #$FF
    bne sfpOffsetOk
    lda CasmSourceOffsetHi
    cmp #$FF
    beq sfpOffsetOverflow       ; offset == $FFFF -> another byte would overflow
sfpOffsetOk:
    ; WP65: absolute offset (within the single permanent shared VMM
    ; allocation) of the byte about to be fetched = CasmSourceVmmCursorLo/Hi
    ; (the offset one-past the end of the currently-installed block) minus
    ; CasmSourceBlockLenLo/Hi (this block's own length, giving the block's
    ; own start) plus CasmSourceBlockIndexLo/Hi (this byte's position within
    ; the block, still unincremented here). See state.s's field comment.
    lda CasmSourceVmmCursorLo
    sec
    sbc CasmSourceBlockLenLo
    sta CasmSourceResultOffsetLo
    lda CasmSourceVmmCursorHi
    sbc CasmSourceBlockLenHi
    sta CasmSourceResultOffsetHi
    lda CasmSourceResultOffsetLo
    clc
    adc CasmSourceBlockIndexLo
    sta CasmSourceResultOffsetLo
    lda CasmSourceResultOffsetHi
    adc CasmSourceBlockIndexHi
    sta CasmSourceResultOffsetHi

    ; index < length and length <= 256 guarantee index high is zero here.
    ldx CasmSourceBlockIndexLo
    lda CasmIoBuffer,x
    sta CasmSourceScratch0
    ; Commit the block index (16-bit).
    inc CasmSourceBlockIndexLo
    bne sfpIndexDone
    inc CasmSourceBlockIndexHi
sfpIndexDone:
    ; Commit the physical consumed offset (16-bit).
    inc CasmSourceOffsetLo
    bne sfpOffsetDone
    inc CasmSourceOffsetHi
sfpOffsetDone:
    lda #CASM_STREAM_DATA
    clc
    rts
sfpEof:
    ; WP46 fix: EOF has no byte of its own, but the caller (lexerFill) still
    ; stamps the EOF token's provenance from these fields. Capture the
    ; current (unchanged since the last real byte's own advance) position
    ; here too, matching the pre-fix behavior of snapshotting immediately
    ; before this call -- real combined EOF (depth 0, content exhausted)
    ; never mutates Line/Column/FileId itself, so "current" and "just
    ; before this call" are the same value on this path. Real combined EOF
    ; is depth-0-only (srEofOrPop pops and retries at depth > 0, never
    ; returning EOF while a frame is active), so this could use the raw
    ; root form directly -- sourceComputePackedFileId is called anyway for
    ; a single shared implementation rather than a second, narrower one.
    jsr sourceComputePackedFileId
    sta CasmSourceResultFileId
    lda CasmSourceLineLo
    sta CasmSourceResultLineLo
    lda CasmSourceLineHi
    sta CasmSourceResultLineHi
    lda CasmSourceColumn
    bne sfpEofColumnStore
    lda #CASM_SOURCE_COLUMN_MAX
sfpEofColumnStore:
    sta CasmSourceResultColumn
    ; sourceRefill committed EOF with A = CASM_SOURCE_EOF, C clear -- but the
    ; provenance capture above clobbered A, so it must be reloaded here
    ; rather than trusted to survive from the jsr sourceRefill/cmp above.
    lda #CASM_SOURCE_EOF
    clc
    rts
sfpFail:
    sec
    rts
sfpOffsetOverflow:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_SOURCE_OFFSET_OVERFLOW
    sec
    rts
sfpCursorFail:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

; ---------------------------------------------------------------------------
; sourceAdvanceNewline (private)
; Advance the location past one normalized newline: check the 16-bit line for
; overflow, increment it, and reset the column to 1. The column-exhausted latch
; is discarded because the line ended before a further byte was needed.
;
; WP51: also publishes the just-completed physical line through
; sourceCaptureNewline (a no-op when line capture is disabled) before
; incrementing the line, since CasmSourceLineLo/Hi here is still the line
; that just ended.
;
; Inputs:    none
; Outputs:   Success: C clear; line advanced, column reset to 1
;            Fail:    A = CASM_DIAG_SOURCE_LOCATION_OVERFLOW or
;                     CASM_DIAG_LISTING_REPLAY_MISMATCH, C set; source ERROR
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
sourceAdvanceNewline:
    lda CasmSourceLineLo
    cmp #<CASM_SOURCE_LINE_MAX
    bne sanAdvance
    lda CasmSourceLineHi
    cmp #>CASM_SOURCE_LINE_MAX
    beq sanOverflow             ; line == $FFFF -> next line would overflow
sanAdvance:
    txa
    pha
    jsr sourceCaptureNewline
    pla
    tax
    bcs sanCaptureFail
    inc CasmSourceLineLo
    bne sanColumnReset
    inc CasmSourceLineHi
sanColumnReset:
    lda #CASM_SOURCE_COLUMN_INITIAL
    sta CasmSourceColumn
    ; WP15: the line just ended. Demote it to "previous" and start the new line
    ; in the other buffer. The buffers are swapped by flipping the selector, so
    ; no bytes are copied here. Retaining the previous line is what lets an emit
    ; diagnostic still show its source: the parser consumes a statement's
    ; terminating newline before the emission engine runs, so an emit failure
    ; always reports a line that is no longer the current one.
    ;
    ; Recorded unconditionally (not gated on CasmDiagCapture) so a buffer can
    ; never retain stale content from a period when capture was off. Uses only
    ; A, honoring this routine's X/Y preservation contract.
    lda CasmDiagLineLen
    sta CasmDiagPrevLen
    lda CasmDiagLineClipped
    sta CasmDiagPrevClipped
    lda CasmDiagLineNoLo
    sta CasmDiagPrevNoLo
    lda CasmDiagLineNoHi
    sta CasmDiagPrevNoHi
    lda CasmDiagLineSel
    eor #$01                    ; CASM_DIAG_SEL_A <-> CASM_DIAG_SEL_B
    sta CasmDiagLineSel
    lda #0
    sta CasmDiagLineLen
    sta CasmDiagLineClipped
    lda CasmSourceLineLo        ; already advanced to the new line above
    sta CasmDiagLineNoLo
    lda CasmSourceLineHi
    sta CasmDiagLineNoHi
    clc
    rts
sanOverflow:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_SOURCE_LOCATION_OVERFLOW
    sec
    rts
sanCaptureFail:
    ; sourceCaptureNewline's only failure mode: an unconsumed sidecar was
    ; still pending (listing.s failed to consume the prior publish before
    ; this one). Not believed reachable under legitimate use -- same
    ; defensive-only status as CASM_DIAG_PASS_MISMATCH/
    ; CASM_DIAG_INCLUDE_REPLAY_MISMATCH.
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_LISTING_REPLAY_MISMATCH
    sec
    rts

; ---------------------------------------------------------------------------
; sourceCaptureNewline (private, WP51)
; If line capture is enabled, publish the just-completed physical line (the
; span from CasmSourceLineStartLo/Hi up to, but excluding, the CR/LF byte
; just consumed) into the completed-line sidecar, then re-anchor
; CasmSourceLineStartLo/Hi to the position immediately after this byte -- the
; presumptive start of the next physical line. Called from
; sourceAdvanceNewline before CasmSourceLineLo/Hi is incremented, so
; CasmSourceLineLo/Hi here is still the line that just ended.
;
; A CR that turns out to be the first half of a CRLF re-anchors one byte
; short (the LF has not been fetched yet); the LF-swallow site in
; sourceNextResult corrects it by one byte when the swallow is confirmed.
;
; Inputs:    CasmSourceResultFileId, CasmSourceLineLo/Hi (the line that just
;            ended), CasmSourceLineStartLo/Hi, CasmSourceBlockBaseLo/Hi,
;            CasmSourceBlockIndexLo/Hi (current absolute position, already
;            advanced past the CR/LF byte)
; Outputs:   Success: C clear; CasmSourceLineStartLo/Hi re-anchored; sidecar
;            published if capture is enabled
;            Failure: A = CASM_DIAG_LISTING_REPLAY_MISMATCH, C set (an
;            unconsumed sidecar was already pending); nothing changed
; Preserves: Y
; Clobbers:  A, X, processor flags, CasmSourceScratch0/1
; ---------------------------------------------------------------------------
sourceCaptureNewline:
    lda CasmSourceCompletedFlags
    and #CASM_SOURCE_CAPTURE_ENABLED
    beq scnReanchor              ; disabled: re-anchor only, always succeeds

    lda CasmSourceCompletedFlags
    and #CASM_SOURCE_COMPLETED_FLAG_VALID
    beq scnCompute
    lda #CASM_DIAG_LISTING_REPLAY_MISMATCH
    sec
    rts

scnCompute:
    ; now = CasmSourceBlockBaseLo/Hi + CasmSourceBlockIndexLo/Hi
    lda CasmSourceBlockBaseLo
    clc
    adc CasmSourceBlockIndexLo
    sta CasmSourceScratch0
    lda CasmSourceBlockBaseHi
    adc CasmSourceBlockIndexHi
    sta CasmSourceScratch1

    ; length = (now - 1) - CasmSourceLineStartLo/Hi
    lda CasmSourceScratch0
    sec
    sbc #1
    sta CasmSourceScratch0
    lda CasmSourceScratch1
    sbc #0
    sta CasmSourceScratch1
    lda CasmSourceScratch0
    sec
    sbc CasmSourceLineStartLo
    tax                          ; X = length low byte (0-255 expected)
    lda CasmSourceScratch1
    sbc CasmSourceLineStartHi
    beq scnPublish               ; length high byte 0 -> length fits 8 bits
    ; length > 255: cannot happen under the existing
    ; CASM_DIAG_SOURCE_LINE_TOO_LONG bound: treated as a defensive replay
    ; mismatch rather than silently truncating an out-of-range length.
    lda #CASM_DIAG_LISTING_REPLAY_MISMATCH
    sec
    rts

scnPublish:
    lda CasmSourceLineStartLo
    sta CasmSourceCompletedStartLo
    lda CasmSourceLineStartHi
    sta CasmSourceCompletedStartHi
    stx CasmSourceCompletedLength
    lda CasmSourceResultFileId
    sta CasmSourceCompletedFileId
    lda CasmSourceLineLo
    sta CasmSourceCompletedLineLo
    lda CasmSourceLineHi
    sta CasmSourceCompletedLineHi
    lda #(CASM_SOURCE_CAPTURE_ENABLED | CASM_SOURCE_COMPLETED_FLAG_VALID)
    sta CasmSourceCompletedFlags

scnReanchor:
    lda CasmSourceBlockBaseLo
    clc
    adc CasmSourceBlockIndexLo
    sta CasmSourceLineStartLo
    lda CasmSourceBlockBaseHi
    adc CasmSourceBlockIndexHi
    sta CasmSourceLineStartHi
    clc
    rts

; ---------------------------------------------------------------------------
; sourceCaptureFinal (private, WP51)
; If line capture is enabled and real payload has been consumed since the
; last anchor (current absolute offset > CasmSourceLineStartLo/Hi), publish
; one FINAL_UNTERMINATED completed-line record for it. Used both at true
; combined-content EOF (srEof, depth 0) and from sourceFramePopInternal, for
; a child frame's own final unterminated line before its state is discarded
; on pop. A file/frame with no trailing content since its last real newline
; (or an empty file/frame) publishes nothing.
;
; Inputs:    CasmSourceResultFileId, CasmSourceLineLo/Hi, CasmSourceLineStartLo/Hi,
;            CasmSourceBlockBaseLo/Hi, CasmSourceBlockIndexLo/Hi -- all
;            describing whichever traversal (root or the frame about to be
;            popped) is still live when this is called
; Outputs:   Success: C clear; sidecar published if applicable
;            Failure: A = CASM_DIAG_LISTING_REPLAY_MISMATCH, C set (an
;            unconsumed sidecar was already pending)
; Preserves: Y
; Clobbers:  A, X, processor flags, CasmSourceScratch0/1
; ---------------------------------------------------------------------------
sourceCaptureFinal:
    lda CasmSourceCompletedFlags
    and #CASM_SOURCE_CAPTURE_ENABLED
    beq scfOk                    ; disabled: nothing to do

    lda CasmSourceBlockBaseLo
    clc
    adc CasmSourceBlockIndexLo
    sta CasmSourceScratch0
    lda CasmSourceBlockBaseHi
    adc CasmSourceBlockIndexHi
    sta CasmSourceScratch1

    ; length = now - CasmSourceLineStartLo/Hi (no "-1": no terminator byte)
    lda CasmSourceScratch0
    sec
    sbc CasmSourceLineStartLo
    tax
    lda CasmSourceScratch1
    sbc CasmSourceLineStartHi
    bne scfOk                    ; > 255: defensive skip (see sourceCaptureNewline)
    cpx #0
    beq scfOk                    ; length 0: nothing pending, publish nothing

    lda CasmSourceCompletedFlags
    and #CASM_SOURCE_COMPLETED_FLAG_VALID
    beq scfPublish
    lda #CASM_DIAG_LISTING_REPLAY_MISMATCH
    sec
    rts
scfPublish:
    lda CasmSourceLineStartLo
    sta CasmSourceCompletedStartLo
    lda CasmSourceLineStartHi
    sta CasmSourceCompletedStartHi
    stx CasmSourceCompletedLength
    lda CasmSourceResultFileId
    sta CasmSourceCompletedFileId
    lda CasmSourceLineLo
    sta CasmSourceCompletedLineLo
    lda CasmSourceLineHi
    sta CasmSourceCompletedLineHi
    lda #(CASM_SOURCE_CAPTURE_ENABLED | CASM_SOURCE_COMPLETED_FLAG_VALID | CASM_SOURCE_COMPLETED_FLAG_FINAL_UNTERMINATED)
    sta CasmSourceCompletedFlags
scfOk:
    clc
    rts

; ---------------------------------------------------------------------------
; sourceClose
; Commit the source CLOSED/NONE and clear block/result state (WP33: no OS
; call -- the input file was already closed by sourceLoad once loading
; finished, and the loaded VMM allocation is released generically by the
; central resource owner's cleanup sweep, matching the symbol table's own
; established precedent of never freeing its VMM allocation explicitly).
; Permitted in CLOSED, READY, EOF, and ERROR; CLOSED is repeat-safe.
;
; Inputs:    initialized source state
; Outputs:   A = CASM_DIAG_NONE, C clear, Z set; source CLOSED/NONE
; Preserves: none
; Clobbers:  A
; Scratch:   none
; ---------------------------------------------------------------------------
sourceClose:
    lda #CASM_SOURCE_STATE_CLOSED
    sta CasmSourceState
    lda #CASM_SOURCE_API_NONE
    sta CasmSourceApiMode
    lda #0
    sta CasmSourceBlockLenLo
    sta CasmSourceBlockLenHi
    sta CasmSourceBlockIndexLo
    sta CasmSourceBlockIndexHi
    sta CasmSourceResultByte
    lda #CASM_DIAG_NONE
    clc
    rts

; ---------------------------------------------------------------------------
; sourceResetTraversal (private)
; Initialize the traversal, location, and line-window fields to their WP3
; initial values without touching lexer state or Phase 2 ownership. Uses only A
; so sourceInit can honor its X/Y preservation contract.
;
; Inputs:    none
; Outputs:   none
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
sourceResetTraversal:
    lda #0                      ; realizes the $00/$0000 initial values below
    sta CasmSourceFileId        ; CASM_SOURCE_FILE_ID_INITIAL
    sta CasmSourceBlockLenLo
    sta CasmSourceBlockLenHi
    sta CasmSourceBlockIndexLo
    sta CasmSourceBlockIndexHi
    sta CasmSourceOffsetLo      ; CASM_SOURCE_OFFSET_INITIAL
    sta CasmSourceOffsetHi
    sta CasmSourceLineHi        ; CASM_SOURCE_LINE_INITIAL high byte
    sta CasmSourcePendingCr
    sta CasmSourceResultByte
    sta CasmSourceLineLength
    sta CasmSourceLineState     ; CASM_SOURCE_LINE_IDLE
    lda #<CASM_SOURCE_LINE_INITIAL
    sta CasmSourceLineLo
    lda #CASM_SOURCE_COLUMN_INITIAL
    sta CasmSourceColumn
    ; WP15: the echo buffers track the traversal, so a reset or rewind must
    ; discard both and re-anchor the current one to the initial line. The
    ; previous-line number resets to CASM_DIAG_LINE_NONE, which no real
    ; 1-based location can match.
    lda #0
    sta CasmDiagLineLen
    sta CasmDiagLineClipped
    sta CasmDiagLineNoHi        ; CASM_SOURCE_LINE_INITIAL high byte
    sta CasmDiagLineSel         ; CASM_DIAG_SEL_A
    sta CasmDiagPrevLen
    sta CasmDiagPrevClipped
    sta CasmDiagPrevNoLo        ; CASM_DIAG_LINE_NONE
    sta CasmDiagPrevNoHi
    lda #<CASM_SOURCE_LINE_INITIAL
    sta CasmDiagLineNoLo
    ; WP51: a reset or rewind disables listing capture and clears any
    ; unconsumed sidecar. CasmSourceBlockBaseLo/Hi and
    ; CasmSourceLineStartLo/Hi are left stale (harmless): both are only
    ; ever read while capture is enabled, and sourceSetLineCapture always
    ; re-anchors CasmSourceLineStartLo/Hi fresh on enable.
    lda #0
    sta CasmSourceCompletedFlags
    rts

; ---------------------------------------------------------------------------
; sourceSetLineCapture (WP51)
; Enable or disable listing capture. Enabling anchors CasmSourceLineStartLo/
; Hi to the current traversal position (CasmSourceVmmCursorLo/Hi, valid
; immediately after sourceRewind since no block has been installed yet --
; the first sourceRefill will independently derive the identical value for
; CasmSourceBlockBaseLo/Hi) and clears any stale unconsumed sidecar.
; Disabling clears capture and any unconsumed sidecar.
;
; Inputs:    A = 0 disables; nonzero enables
; Outputs:   C clear always; no failure path
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
sourceSetLineCapture:
    cmp #0
    bne slcEnable
    lda #0
    sta CasmSourceCompletedFlags
    clc
    rts
slcEnable:
    lda #CASM_SOURCE_CAPTURE_ENABLED
    sta CasmSourceCompletedFlags
    lda CasmSourceVmmCursorLo
    sta CasmSourceLineStartLo
    lda CasmSourceVmmCursorHi
    sta CasmSourceLineStartHi
    clc
    rts

; ---------------------------------------------------------------------------
; sourceTakeCompletedLine (WP51)
; Consume the completed-line sidecar if a publish is pending. The private
; CASM_SOURCE_CAPTURE_ENABLED bit (shared with this byte -- see common.inc)
; is always masked out of the returned value, so a caller only ever
; observes the documented VALID/SYNTHETIC_ONLY/FINAL_UNTERMINATED bits with
; bits 3-7 reserved and zero, exactly as the public sidecar contract states.
;
; Inputs:    none
; Outputs:   Pending: C clear; A = flags with VALID set (and, when
;            applicable, FINAL_UNTERMINATED); CasmSourceCompletedStartLo/Hi,
;            Length, FileId, LineLo/Hi remain readable; pending-valid state
;            consumed
;            No pending: C clear; A = 0
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
sourceTakeCompletedLine:
    lda CasmSourceCompletedFlags
    and #CASM_SOURCE_COMPLETED_FLAG_VALID
    beq stclNone
    lda CasmSourceCompletedFlags
    and #%01111111               ; mask off the private ENABLED bit
    pha
    lda CasmSourceCompletedFlags
    and #%11111110               ; clear VALID; ENABLED/reserved bits survive
    sta CasmSourceCompletedFlags
    pla
    clc
    rts
stclNone:
    lda #0
    clc
    rts

; ---------------------------------------------------------------------------
; sourceReadSpanChunk (WP53)
; Read an arbitrary absolute span of the already-loaded combined source store
; into CasmVmmBuffer, so WP53's listing serializer can replay the source
; spans WP51 recorded. Deliberately a random-access reader, not a traversal
; step: it installs no refill block, advances no cursor, touches no frame
; stack, publishes no completed-line sidecar, and changes neither
; CasmSourceState nor CasmSourceApiMode -- so it is safe to call after
; traversal has closed, which is exactly when the serializer runs.
;
; The source registry slot stays private to this module: a caller names a
; span, never a slot. That keeps WP53's "exposes no source slot" stop
; condition structural rather than conventional.
;
; A zero-length request is rejected rather than quietly succeeding. The
; serializer has no legitimate zero-byte span, so one means its recorded
; metadata disagrees with the store -- the same class of fault as an
; out-of-range span, and therefore the same diagnostic.
;
; Inputs:    CasmVmmOffLo/Hi = absolute offset into the combined store
;            CasmIoLenLo/Hi  = byte count, 1..CASM_VMM_BUFFER_SIZE
; Outputs:   Success: C clear, A = CASM_DIAG_NONE, CasmVmmBuffer[0..len-1]
;                     holds the requested bytes
;            Fail:    C set, A = CASM_DIAG_LISTING_REPLAY_MISMATCH when the
;                     request disagrees with the authoritative loaded extent
;                     (zero or oversized length, non-zero length high byte,
;                     16-bit wrap, or end past CasmSourceLoadedLenLo/Hi);
;                     A = CASM_DIAG_VMM_TRANSFER_FAILED propagated unchanged
;                     from vmmWindowRead on a rejected transfer
; Preserves: all traversal state
; Clobbers:  A, X, Y, CasmSourceScratch0/1, CasmValue0Lo/Hi (the latter
;            inside vwPrepareTransfer), and OS API-defined volatile registers
; Scratch:   CasmSourceScratch0/1 (16-bit end-of-span sum)
;
; CasmSourceLoadedLenLo/Hi is the right bound here, not WP46's
; CasmSourceTopLevelEndLo/Hi: the serializer replays spans from included
; children too, and those live above the top-level end in the combined
; store. This routine is not traversal, so the depth-0 overread hazard
; CasmSourceTopLevelEndLo/Hi exists to prevent does not apply -- every span
; is explicitly named by a caller that recorded it, not walked into.
; ---------------------------------------------------------------------------
sourceReadSpanChunk:
    ; Length must be 1..CASM_VMM_BUFFER_SIZE so it fits one staged transfer.
    lda CasmIoLenHi
    bne srscMismatch
    lda CasmIoLenLo
    beq srscMismatch
    cmp #CASM_VMM_BUFFER_SIZE + 1
    bcs srscMismatch

    ; end = offset + length (16-bit). A carry out of the high byte means the
    ; span wrapped past $FFFF, which no real span can do.
    lda CasmVmmOffLo
    clc
    adc CasmIoLenLo
    sta CasmSourceScratch0
    lda CasmVmmOffHi
    adc #0
    sta CasmSourceScratch1
    bcs srscMismatch

    ; Reject end > CasmSourceLoadedLenLo/Hi; end == loaded length is the
    ; legitimate final span and must pass.
    lda CasmSourceScratch1
    cmp CasmSourceLoadedLenHi
    bcc srscInRange
    bne srscMismatch
    lda CasmSourceScratch0
    cmp CasmSourceLoadedLenLo
    beq srscInRange
    bcs srscMismatch

srscInRange:
    ldx CasmSourceVmmSlot
    jsr vmmWindowRead
    bcs srscPropagate
    lda #CASM_DIAG_NONE
    clc
    rts

srscPropagate:
    rts                          ; vmmWindowRead already set A and carry

srscMismatch:
    lda #CASM_DIAG_LISTING_REPLAY_MISMATCH
    sec
    rts

; ---------------------------------------------------------------------------
; srCheckFileBoundary (private, WP34)
; If a next file exists (CasmSourceFileId + 1 < CasmSourceCount) and the
; read cursor has reached exactly its recorded start offset
; (CasmSourceFileTable), commit the file-boundary transition before this
; refill computes anything else: CasmSourceFileId increments,
; CasmSourceLineLo/Hi resets to 1, CasmSourceColumn resets to 1, and
; CasmSourcePendingCr clears (user-confirmed: a bare-CR-ending file must
; never phantom-collapse with a following file's leading LF). Gated so a
; single-file source (CasmSourceCount == 1) never takes the true branch,
; degrading exactly to a no-op -- WP33's behavior.
;
; A single equality check is sufficient, never needing a "did we skip past
; it" case: srComputeRemaining's 3-way min (below) caps every refill's
; transfer at the next file boundary, so the cursor always lands exactly on
; it between refills, never beyond.
;
; Inputs:    none
; Outputs:   none (commits the transition on a boundary; no-op otherwise)
; Clobbers:  A, X, processor flags
;
; WP46: also resets the diagnostic echo/offset-guard state
; (sourceResetBoundaryEcho) on a real transition -- fixes a pre-existing
; gap where two different top-level files sharing a line number could
; show one file's cached echo text under the other's diagnostic, since
; nothing previously invalidated that bookkeeping at a file boundary.
; ---------------------------------------------------------------------------
srCheckFileBoundary:
    lda CasmSourceFileId
    clc
    adc #1
    cmp CasmSourceCount
    bcs srcfbDone                ; no next file -- nothing to check

    ; A still holds FileId+1 (unchanged by cmp); X = its file-table offset.
    asl
    tax
    lda CasmSourceVmmCursorLo
    cmp CasmSourceFileTable, x
    bne srcfbDone
    lda CasmSourceVmmCursorHi
    cmp CasmSourceFileTable + 1, x
    bne srcfbDone

    inc CasmSourceFileId
    lda #<CASM_SOURCE_LINE_INITIAL
    sta CasmSourceLineLo
    lda #>CASM_SOURCE_LINE_INITIAL
    sta CasmSourceLineHi
    lda #CASM_SOURCE_COLUMN_INITIAL
    sta CasmSourceColumn
    lda #0
    sta CasmSourcePendingCr
    jsr sourceResetBoundaryEcho
srcfbDone:
    rts

; ---------------------------------------------------------------------------
; sourceResetBoundaryEcho (private, WP46)
; Discard both diagnostic echo buffers' cached content at a source
; traversal boundary (top-level file transition, frame push, or frame
; pop) and reset the per-span byte-delivered overflow guard
; (CasmSourceOffsetLo/Hi). Must be called only after CasmSourceLineLo/Hi
; already holds the new position's correct line number: the reset
; "current" buffer is re-anchored to that line, empty, so a diagnostic on
; the very first byte after the boundary renders a blank line rather than
; stale or (before this fix) another file's text.
;
; CasmSourceOffsetLo/Hi has no consumer outside this module (only its own
; overflow guard and a "has any byte been consumed yet" check) -- once the
; same physical bytes can be delivered many times over through repeated
; inclusion, resetting it fresh at every boundary is correct: it protects
; only whatever span is currently active, never a global total.
;
; Inputs:    CasmSourceLineLo/Hi already set to the new position's line
; Outputs:   both echo buffers empty and re-anchored to the new current
;            line; CasmSourceOffsetLo/Hi = 0
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
sourceResetBoundaryEcho:
    lda #0
    sta CasmDiagLineLen
    sta CasmDiagLineClipped
    sta CasmDiagLineSel
    sta CasmDiagPrevLen
    sta CasmDiagPrevClipped
    sta CasmDiagPrevNoLo
    sta CasmDiagPrevNoHi
    sta CasmSourceOffsetLo
    sta CasmSourceOffsetHi
    lda CasmSourceLineLo
    sta CasmDiagLineNoLo
    lda CasmSourceLineHi
    sta CasmDiagLineNoHi
    rts

; ---------------------------------------------------------------------------
; sourceFramePush (WP46)
; Push a new nested include frame, switching live traversal to the child's
; span. Depth and active-chain cycle checks run first, before any state
; changes -- a rejected push leaves every frame-stack field, the live
; cursor, and the echo buffers completely untouched.
;
; The caller (a test harness now; WP47's real dispatch later) is
; responsible for resolving the child through include.s's
; includeCatalogLoad first and reading its start/length out of
; CasmIncludeRecordStage -- this routine has no dependency on include.s at
; all, keeping the two modules' layering exactly as it already was
; (include.s already imports from source.s; the reverse never happens).
;
; Inputs:    A = candidate catalog index (0..CASM_INCLUDE_PHYS_CAPACITY-1);
;            CasmValue0Lo/Hi = child start offset; CasmValue1Lo/Hi = child
;            end offset (start + length), both in the combined source
;            store -- staged by the caller immediately before this call,
;            not carried across any intervening call (unlike the WP45
;            defect this project already hit once with CasmValue0Lo/Hi).
; Outputs:   Success: A = CASM_DIAG_NONE, C clear; the parent's live
;            cursor/line/column/pending-CR saved into the new depth's
;            frame-stack slot; live traversal switched to the child's
;            start/line 1/column 1/pending-CR clear; the installed block
;            invalidated (forces a fresh refill); echo/offset-guard state
;            reset; lookahead invalidated; CasmFrameDepth incremented
;            Failure: A = CASM_DIAG_INCLUDE_DEPTH_EXCEEDED (depth already
;            at CASM_INCLUDE_MAX_DEPTH) or CASM_DIAG_INCLUDE_CYCLE_DETECTED
;            (the candidate catalog index already appears somewhere in the
;            active frame chain), C set; nothing changed
; Clobbers:  A, X, Y, CasmSourceScratch0/1, CasmLookaheadValid
; Scratch:   CasmSourceScratch0 (the candidate catalog index, held across
;            the cycle-scan loop below), CasmSourceScratch1 (the scan's
;            loop bound) -- both free here: this routine runs standalone,
;            never interleaved with sourceLoad/sourceAppendFile's own use
;            of the same cells
; ---------------------------------------------------------------------------
sourceFramePush:
    sta CasmSourceScratch0
    lda CasmFrameDepth
    cmp #CASM_INCLUDE_MAX_DEPTH
    bcc sfpDepthOk
    lda #CASM_DIAG_INCLUDE_DEPTH_EXCEEDED
    sec
    rts

sfpDepthOk:
    lda CasmFrameDepth
    beq sfpNoCycle               ; depth 0: nothing active to collide with
    sta CasmSourceScratch1
    ldx #0
sfpCycleLoop:
    cpx CasmSourceScratch1
    beq sfpNoCycle
    lda CasmFrameCatalogIndex, x
    cmp CasmSourceScratch0
    beq sfpCycle
    inx
    jmp sfpCycleLoop
sfpCycle:
    lda #CASM_DIAG_INCLUDE_CYCLE_DETECTED
    sec
    rts

sfpNoCycle:
    ; Save the parent's live state into the new depth's slot (0-based
    ; index = CasmFrameDepth's current, pre-increment value).
    ldx CasmFrameDepth
    lda CasmSourceScratch0
    sta CasmFrameCatalogIndex, x
    lda CasmValue1Lo
    sta CasmFrameEndOffsetLo, x
    lda CasmValue1Hi
    sta CasmFrameEndOffsetHi, x

    ; WP46 fix: the parent's resume offset is its LOGICAL parse position,
    ; not CasmSourceVmmCursorLo/Hi. That cursor is the bulk-refill read
    ; head: sourceRefill installs up to 256 bytes at a time, so by the time
    ; the lexer has parsed as far as an .INCLUDE line, the cursor has
    ; typically already run ahead to the end of the whole installed block
    ; (for a fixture smaller than the buffer, that means the file's very
    ; end). Resuming the parent from there would skip every byte still
    ; sitting unconsumed in the block.
    ;
    ; The true position is cursor - (blockLen - blockIndex): back the read
    ; head up by however much of the installed block the lexer has not yet
    ; consumed. CasmSourceScratch0/1 are free again here -- the candidate
    ; catalog index they carried was already stored above, and the cycle
    ; scan is finished.
    lda CasmSourceBlockLenLo
    sec
    sbc CasmSourceBlockIndexLo
    sta CasmSourceScratch0
    lda CasmSourceBlockLenHi
    sbc CasmSourceBlockIndexHi
    sta CasmSourceScratch1
    lda CasmSourceVmmCursorLo
    sec
    sbc CasmSourceScratch0
    sta CasmFrameResumeOffsetLo, x
    lda CasmSourceVmmCursorHi
    sbc CasmSourceScratch1
    sta CasmFrameResumeOffsetHi, x

    lda CasmSourceLineLo
    sta CasmFrameResumeLineLo, x
    lda CasmSourceLineHi
    sta CasmFrameResumeLineHi, x
    lda CasmSourceColumn
    sta CasmFrameResumeColumn, x
    lda CasmSourcePendingCr
    sta CasmFrameResumePendingCr, x
    lda CasmSourceLineStartLo
    sta CasmFrameResumeLineStartLo, x
    lda CasmSourceLineStartHi
    sta CasmFrameResumeLineStartHi, x

    ; WP48: capture the `.INCLUDE` statement's own start location. Runtime
    ; verification proved the parser has consumed the trailing newline before
    ; this push, so the resume line is already the following line and cannot
    ; double as the include-site line.
    lda CasmStmtLocLineLo
    sta CasmFrameSiteLineLo, x
    lda CasmStmtLocLineHi
    sta CasmFrameSiteLineHi, x
    lda CasmStmtLocColumn
    sta CasmFrameSiteColumn, x
    lda CasmSourceFileId
    sta CasmFrameRootFileId, x

    ; Switch the live cursor to the child's start. The installed block is
    ; invalidated (index = length = 0) rather than kept: unlike
    ; srCheckFileBoundary's own reset (always called from within
    ; sourceRefill, where the block is already guaranteed exhausted), this
    ; routine is called from *outside* the refill mechanism entirely, so
    ; whatever block the parent had mid-consumed must not be trusted for
    ; the child's completely different position.
    lda CasmValue0Lo
    sta CasmSourceVmmCursorLo
    ; WP51: the child's line-start anchor is exactly its own start offset --
    ; the same value just stored into the cursor above. Set directly rather
    ; than deferred to the next refill's own base snapshot (sourceRefill),
    ; since both independently compute the identical value; setting it here
    ; keeps it valid even if a diagnostic reads it before the first fetch.
    sta CasmSourceLineStartLo
    lda CasmValue0Hi
    sta CasmSourceVmmCursorHi
    sta CasmSourceLineStartHi
    lda #0
    sta CasmSourceBlockIndexLo
    sta CasmSourceBlockIndexHi
    sta CasmSourceBlockLenLo
    sta CasmSourceBlockLenHi
    lda #<CASM_SOURCE_LINE_INITIAL
    sta CasmSourceLineLo
    lda #>CASM_SOURCE_LINE_INITIAL
    sta CasmSourceLineHi
    lda #CASM_SOURCE_COLUMN_INITIAL
    sta CasmSourceColumn
    lda #0
    sta CasmSourcePendingCr
    jsr sourceResetBoundaryEcho
    inc CasmFrameDepth
    lda #0
    sta CasmLookaheadValid
    lda #CASM_DIAG_NONE
    clc
    rts

; ---------------------------------------------------------------------------
; srMin (private, WP33/WP34)
; CasmSourceScratch0/1 = min(CasmSourceScratch0/1, CasmValue0Lo/Hi). Shared
; by srComputeRemaining's two cap terms (loaded-content remaining, and
; WP34's next-file-boundary distance) so the 16-bit comparison exists in
; exactly one place.
;
; Inputs:    CasmSourceScratch0/1, CasmValue0Lo/Hi
; Outputs:   CasmSourceScratch0/1 = the smaller of the two
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
srMin:
    lda CasmValue0Hi
    cmp CasmSourceScratch1
    bcc srMinValueSmaller
    bne srMinDone
    lda CasmValue0Lo
    cmp CasmSourceScratch0
    bcs srMinDone
srMinValueSmaller:
    lda CasmValue0Lo
    sta CasmSourceScratch0
    lda CasmValue0Hi
    sta CasmSourceScratch1
srMinDone:
    rts

; ---------------------------------------------------------------------------
; sourceRefill (private, WP33: VMM-backed; WP34: file-boundary-aware)
; Refill from the loaded VMM allocation only when the current block is
; exhausted (the caller guarantees index == length). Install a validated
; 1-256-byte block, or commit a length-checked first EOF, or fail into
; source ERROR.
;
; requestLen (how much this refill could take, 1-256, identical to the old
; OS-direct computation) is capped by remaining (how much loaded content is
; left: CasmSourceLoadedLenLo/Hi - CasmSourceVmmCursorLo/Hi) and, when a
; next file exists, by the distance to that file's recorded start offset
; (CasmSourceFileTable) -- a 3-way min via the shared srMin helper -- to
; give transferLen, the actual byte count for this refill. The boundary cap
; is what guarantees a single installed block never spans two files, which
; is what makes srCheckFileBoundary's top-of-routine equality check
; sufficient. transferLen == 0 is combined-content EOF. Otherwise the
; block's final index/length is precomputed once from the original
; transferLen (needed because base + transferLen can be exactly 256, which
; does not fit an 8-bit running destination-offset counter), then
; transferLen bytes are moved from VMM into CasmIoBuffer + base through up
; to four 64-byte vmmWindowRead chunks (vmmWindowRead always fills the
; fixed CasmVmmBuffer, so each chunk is copied out to its real destination
; after the transfer).
;
; Inputs:    index == length
; Outputs:   Data: A = CASM_STREAM_DATA, C clear; block installed, index 0
;            EOF:  A = CASM_SOURCE_EOF, C clear; state EOF, result byte cleared
;            Fail: A = CASM_DIAG_*, C set; state ERROR
; Preserves: none
; Clobbers:  A, X, Y, source scratch, CasmVmmBuffer, vmmWindowRead volatile
;            state
; Scratch:   CasmSourceScratch0/1 (requestLen, then reused as the 16-bit
;            remaining-to-transfer counter), CasmLexerScratch0 (this
;            refill's fixed base, from sourceComputeBase), CasmLexerScratch1
;            (chunk destination offset within this refill's transfer region)
; ---------------------------------------------------------------------------
sourceRefill:
    ; WP46: the top-level file-boundary check is a depth-0 (root traversal)
    ; concept only -- while a nested include frame is active, reaching its
    ; own end is handled by the cap/pop logic below instead.
    lda CasmFrameDepth
    bne srSkipRootBoundary
    jsr srCheckFileBoundary
srSkipRootBoundary:
    jsr sourceComputeBase
    sta CasmLexerScratch0        ; base: needed again after computing requestLen
    beq srFullRequest            ; base 0 -> whole buffer -> requestLen = 256
    ; LINE mode with an accumulated payload: requestLen = 256 - base,
    ; preserving CasmIoBuffer[0 .. base-1].
    eor #$FF
    clc
    adc #$01                    ; A = 256 - base (base is 1..255)
    sta CasmSourceScratch0
    lda #0
    sta CasmSourceScratch1
    jmp srComputeRemaining
srFullRequest:
    lda #<CASM_IO_BUFFER_SIZE
    sta CasmSourceScratch0
    lda #>CASM_IO_BUFFER_SIZE
    sta CasmSourceScratch1       ; requestLen = 256 ($0100)

srComputeRemaining:
    ; remaining = CasmSourceLoadedLenLo/Hi - CasmSourceVmmCursorLo/Hi (16-bit).
    lda CasmSourceLoadedLenLo
    sec
    sbc CasmSourceVmmCursorLo
    sta CasmValue0Lo
    lda CasmSourceLoadedLenHi
    sbc CasmSourceVmmCursorHi
    sta CasmValue0Hi
    jsr srMin                    ; transferLen = min(requestLen, remaining)

    ; WP34: also cap at the next top-level file boundary, if one exists --
    ; keeps a single installed block from ever spanning two files
    ; (srCheckFileBoundary relies on this). Root traversal (depth 0) only.
    ; WP46: while a nested include frame is active (depth > 0), cap at
    ; that frame's own end offset instead -- the top-level file table has
    ; no relation to an included file's span, which can sit anywhere in
    ; the combined store.
    lda CasmFrameDepth
    bne srCapNested

    ; WP46 fix: cap depth-0 traversal at the combined top-level content's
    ; own fixed end (CasmSourceTopLevelEndLo/Hi) before the next-file-table
    ; check below. CasmSourceLoadedLenLo/Hi (what srComputeRemaining just
    ; used) grows as .INCLUDE children get appended mid-traversal; without
    ; this separate fixed bound, a top-level file with real content after
    ; its own .INCLUDE would overread straight into an appended child's
    ; bytes on reaching its own true end, instead of hitting EOF.
    lda CasmSourceTopLevelEndLo
    sec
    sbc CasmSourceVmmCursorLo
    sta CasmValue0Lo
    lda CasmSourceTopLevelEndHi
    sbc CasmSourceVmmCursorHi
    sta CasmValue0Hi
    jsr srMin

    lda CasmSourceFileId
    clc
    adc #1
    cmp CasmSourceCount
    bcc srCapRootHasNext
    jmp srTransferLenReady        ; no next file -- transferLen already final
srCapRootHasNext:
    asl
    tax
    lda CasmSourceFileTable, x
    sec
    sbc CasmSourceVmmCursorLo
    sta CasmValue0Lo
    lda CasmSourceFileTable + 1, x
    sbc CasmSourceVmmCursorHi
    sta CasmValue0Hi
    jsr srMin
    jmp srTransferLenReady
srCapNested:
    ; 0-based array index of the currently active frame is CasmFrameDepth-1.
    tax
    dex
    lda CasmFrameEndOffsetLo, x
    sec
    sbc CasmSourceVmmCursorLo
    sta CasmValue0Lo
    lda CasmFrameEndOffsetHi, x
    sbc CasmSourceVmmCursorHi
    sta CasmValue0Hi
    jsr srMin

srTransferLenReady:
    lda CasmSourceScratch0
    ora CasmSourceScratch1
    bne srHaveData
    jmp srEofOrPop                ; transferLen == 0: EOF, or a frame to pop

srHaveData:
    ; WP51: snapshot this block's absolute base before CasmSourceVmmCursorLo/
    ; Hi advances below. CASM's real traversal is always CASM_SOURCE_API_BYTE
    ; (the lexer never uses LINE mode), where sourceComputeBase always
    ; returns 0, so block index 0 always corresponds exactly to the cursor's
    ; current (not-yet-advanced) value -- no subtraction needed.
    lda CasmSourceVmmCursorLo
    sta CasmSourceBlockBaseLo
    lda CasmSourceVmmCursorHi
    sta CasmSourceBlockBaseHi

    ; Precompute the block's final index/length now, from the original
    ; (not-yet-decremented) transferLen: index = base; length = base +
    ; transferLen. Doing this before the chunk loop below avoids needing an
    ; 8-bit running destination-offset counter to ever represent 256.
    lda CasmLexerScratch0
    sta CasmSourceBlockIndexLo
    lda #0
    sta CasmSourceBlockIndexHi
    lda CasmSourceBlockIndexLo
    clc
    adc CasmSourceScratch0
    sta CasmSourceBlockLenLo
    lda CasmSourceBlockIndexHi
    adc CasmSourceScratch1
    sta CasmSourceBlockLenHi

    ; Validate the installed end position is 1-256; length 256 encodes as $0100.
    lda CasmSourceBlockLenHi
    beq srLenOk                 ; end 1-255
    cmp #$01
    bne srInvalidBlockNear      ; end > 256 -- cursor-math defect, not external input
    lda CasmSourceBlockLenLo
    bne srInvalidBlockNear
    jmp srLenOk
srInvalidBlockNear:
    ; Trampoline: srInvalidBlock's shared tail is out of direct branch range
    ; from here.
    jmp srInvalidBlock
srLenOk:
    lda #0
    sta CasmLexerScratch1        ; chunk destination offset within this refill

srReadChunkLoop:
    lda CasmSourceScratch0
    ora CasmSourceScratch1
    beq srInstallDone            ; all chunks for this refill transferred

    lda CasmSourceScratch1
    bne srReadChunkFull          ; remaining hi != 0 -> remaining > 255
    lda CasmSourceScratch0
    cmp #CASM_VMM_BUFFER_SIZE + 1
    bcs srReadChunkFull          ; remaining >= 64 -> full chunk
    sta CasmIoLenLo               ; partial final chunk: chunkLen = remaining
    lda #0
    sta CasmIoLenHi
    jmp srReadChunkStage
srReadChunkFull:
    lda #CASM_VMM_BUFFER_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi

srReadChunkStage:
    lda CasmSourceVmmCursorLo
    sta CasmVmmOffLo
    lda CasmSourceVmmCursorHi
    sta CasmVmmOffHi
    ldx CasmSourceVmmSlot
    jsr vmmWindowRead
    bcs srReadFailedNear

    ; Copy CasmIoLenLo bytes from CasmVmmBuffer into
    ; CasmIoBuffer + base + chunk-destination-offset. base + offset is
    ; always <= 255 (base <= 255, and the offset never reaches this chunk's
    ; own length before it is added below), so that sum alone cannot carry
    ; -- but CasmIoBuffer's own link address is not page-aligned ($DA low
    ; byte), so its low byte must be added as its own carried step, not
    ; folded into the CasmIoBuffer,y addressing mode's fixed high byte. A
    ; real WP33 fixture run caught an earlier version of this routine
    ; omitting the <CasmIoBuffer term entirely, which pointed every copy
    ; 218 bytes before the real buffer and corrupted unrelated BSS state.
    lda CasmLexerScratch0
    clc
    adc CasmLexerScratch1
    clc
    adc #<CasmIoBuffer
    sta CasmIoPtrLo
    lda #>CasmIoBuffer
    adc #0
    sta CasmIoPtrHi
    ldy #0
srCopyFromVmmLoop:
    cpy CasmIoLenLo
    beq srCopyFromVmmDone
    lda CasmVmmBuffer, y
    sta (CasmIoPtrLo), y
    iny
    jmp srCopyFromVmmLoop
srCopyFromVmmDone:

    ; Advance the VMM read cursor and the chunk destination offset by
    ; chunkLen; decrement this refill's remaining-to-transfer counter.
    lda CasmSourceVmmCursorLo
    clc
    adc CasmIoLenLo
    sta CasmSourceVmmCursorLo
    lda CasmSourceVmmCursorHi
    adc CasmIoLenHi
    sta CasmSourceVmmCursorHi

    lda CasmLexerScratch1
    clc
    adc CasmIoLenLo
    sta CasmLexerScratch1

    lda CasmSourceScratch0
    sec
    sbc CasmIoLenLo
    sta CasmSourceScratch0
    lda CasmSourceScratch1
    sbc CasmIoLenHi
    sta CasmSourceScratch1
    jmp srReadChunkLoop

srInstallDone:
    lda #CASM_STREAM_DATA
    clc
    rts

srReadFailedNear:
    ; Trampoline: the chunk loop above is out of direct branch range of the
    ; shared failure tail.
    jmp srReadFailed

; ---------------------------------------------------------------------------
; sourceComputeBase (private)
; Return the protected buffer prefix: 0 in BYTE mode, or the accumulated line
; payload length in LINE mode.
;
; Inputs:    none
; Outputs:   A = base, Z set when the base is 0
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
sourceComputeBase:
    lda CasmSourceApiMode
    cmp #CASM_SOURCE_API_LINE
    beq scbLine
    lda #0
    rts
scbLine:
    lda CasmSourceLineLength
    rts

; ---------------------------------------------------------------------------
; srEofOrPop (private, WP46)
; transferLen == 0 means either the whole combined traversal is exhausted
; (depth 0: unchanged WP33/34 behavior) or the currently active nested
; frame has reached its own end and must be popped back to its suspended
; parent. A pop retries the entire sourceRefill computation from the top
; -- which may itself immediately pop again, if the newly-resumed parent
; is *also* exactly at its own end (e.g. an included file's very last
; statement was itself another `.INCLUDE`).
;
; Inputs:    CasmFrameDepth
; Outputs:   depth 0: as srEof. depth > 0: never returns to the original
;            caller directly -- always re-enters sourceRefill instead,
;            unless sourceFramePopInternal's WP51 capture publish fails.
; ---------------------------------------------------------------------------
srEofOrPop:
    lda CasmFrameDepth
    beq srEofNear
    jsr sourceFramePopInternal
    bcs srEofOrPopFail
    jmp sourceRefill
srEofNear:
    jmp srEof
srEofOrPopFail:
    ; sourceFramePopInternal already set source ERROR and A = diagnostic.
    sec
    rts

; ---------------------------------------------------------------------------
; sourceFramePopInternal (private, WP46; WP51 capture publish)
; Restore the suspended parent's traversal state from the current depth's
; frame-stack slot and decrement CasmFrameDepth. Called only from
; srEofOrPop, when the active frame's own content is exhausted.
;
; WP51: before restoring anything, publishes the popped child's own final
; unterminated line (if any) through sourceCaptureFinal -- a no-op when
; capture is disabled or the child ended cleanly on a real newline -- since
; nothing else ever gets a chance to flush it once this frame's state is
; discarded below.
;
; Inputs:    CasmFrameDepth > 0
; Outputs:   Success: C clear; CasmSourceVmmCursorLo/Hi, CasmSourceLineLo/Hi,
;            CasmSourceColumn, CasmSourcePendingCr, CasmSourceLineStartLo/Hi
;            restored from the popped frame's saved resume state;
;            CasmSourceBlockIndexLo/Hi and CasmSourceBlockLenLo/Hi
;            invalidated (both zeroed, forcing sourceFetchPhysical's next
;            call to refill rather than trust the child's now-stale
;            installed block); echo/offset-guard state reset
;            (sourceResetBoundaryEcho); lookahead invalidated
;            (CasmLookaheadValid = 0, matching sourceRewind's existing
;            precedent that the state-owning caller invalidates lookahead,
;            not a private lexer routine); CasmFrameDepth decremented
;            Failure: A = CASM_DIAG_LISTING_REPLAY_MISMATCH, C set (an
;            unconsumed sidecar was already pending); nothing changed,
;            source ERROR
; Clobbers:  A, X
; ---------------------------------------------------------------------------
sourceFramePopInternal:
    jsr sourceCaptureFinal
    bcs sfpiCaptureFail
    ldx CasmFrameDepth
    dex                            ; 0-based array index of the frame being popped
    lda CasmFrameResumeOffsetLo, x
    sta CasmSourceVmmCursorLo
    lda CasmFrameResumeOffsetHi, x
    sta CasmSourceVmmCursorHi
    lda CasmFrameResumeLineLo, x
    sta CasmSourceLineLo
    lda CasmFrameResumeLineHi, x
    sta CasmSourceLineHi
    lda CasmFrameResumeColumn, x
    sta CasmSourceColumn
    lda CasmFrameResumePendingCr, x
    sta CasmSourcePendingCr
    lda CasmFrameResumeLineStartLo, x
    sta CasmSourceLineStartLo
    lda CasmFrameResumeLineStartHi, x
    sta CasmSourceLineStartHi
    lda #0
    sta CasmSourceBlockIndexLo
    sta CasmSourceBlockIndexHi
    sta CasmSourceBlockLenLo
    sta CasmSourceBlockLenHi
    jsr sourceResetBoundaryEcho
    dec CasmFrameDepth
    lda #0
    sta CasmLookaheadValid
    clc
    rts
sfpiCaptureFail:
    ; sourceCaptureFinal already set source ERROR and A = diagnostic.
    sec
    rts

srEof:
    ; Combined VMM content exhausted (transferLen computed as 0 above). The
    ; consumed cursor must already be exhausted before EOF is committed --
    ; guaranteed by the caller (sourceFetchPhysical), checked defensively.
    lda CasmSourceBlockIndexLo
    cmp CasmSourceBlockLenLo
    bne srEofMismatch
    lda CasmSourceBlockIndexHi
    cmp CasmSourceBlockLenHi
    bne srEofMismatch
    ; WP51: publish any final unterminated line before committing EOF --
    ; a no-op when capture is disabled or the source ended on a real newline.
    jsr sourceCaptureFinal
    bcs srEofCaptureFail
    lda #CASM_SOURCE_STATE_EOF
    sta CasmSourceState
    lda #0
    sta CasmSourceResultByte
    lda #CASM_SOURCE_EOF
    clc
    rts
srEofCaptureFail:
    ; sourceCaptureFinal already set source ERROR and A = diagnostic.
    sec
    rts
srEofMismatch:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts

srReadFailed:
    ; Preserve the wrapper diagnostic (vmmWindowRead failure) while
    ; recording the source ERROR state.
    pha
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    pla
    sec
    rts
srInvalidBlock:
    lda #CASM_SOURCE_STATE_ERROR
    sta CasmSourceState
    lda #CASM_DIAG_STREAM_STATE_FAILED
    sec
    rts
