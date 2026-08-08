; src/external/casm/casm.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM native 6502/6510 assembler entry point. Owns the production assembly
; orchestration: initialize resources/CLI/file-IO/source/lexer/symbol table,
; run a real two-pass assembly (Phase 6B WP29) -- Pass 1 measures addresses and
; defines labels with no output file; Pass 2 rewinds the source, creates the
; output PRG, and emits for real, now that every label resolves through the
; WP27 symbol table -- finalize the output, and route every success and
; failure through central cleanup. Handle ownership, partial-output abort, and
; single-close semantics are documented at start and casmRunPass below.

.include "command64.inc"
.include "common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "56"
.include "build_casm.inc"

.import __MAIN_START__
.import resourcesInit
.import CasmPhase
.import cliInit
.import cliParse
.import cliDeriveOutputName
.import cliDeriveListingName
.import CasmCliOptions
.import fileIoInit
.import sourceInit
.import listingStateInit
.import listingFileInit
.import listingBeginLine
.import listingCommitLine
.import listingCaptureInit
.import listingCaptureFinalize
.import listingWriteFile
.import listingAbort
.import mapPrint
.import sourceLoad
.import sourceOpen
.import sourceClose
.import diagPrintString
.import diagClearLoc
.import diagSetLocFromStmt
.import exitSuccess
.import exitFatal

.import lexerInit
.import parserParseStatement
.import CasmParserStmt
.import CasmLabelName
.import CasmLabelNameLen
.import opcodesFindOpcode
.import diagPrintPhase2Ready

.import sourceRewind
.import symbolsInit
.import symbolsInsert

; WP47 include processing. casmRunPass is the one production bridge between
; include.s's catalog/event log and source.s's frame traversal: neither module
; imports the other (WP46 finding 4), so the shared caller sequences them --
; exactly the role tests/src/casm_frame's driver loop stood in for until now.
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
.import sourceFramePush
.import CasmFrameDepth
.import CasmFrameCatalogIndex
.import CasmSourceFileId
.import CasmStmtLocLineLo
.import CasmStmtLocLineHi
.import CasmStmtLocColumn
.import cliSourceSlotLo
.import cliSourceSlotHi

.import CasmOutputName
.import fileCreateOutput
.import outputAbort
.import outputCommit
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

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

; ---------------------------------------------------------------------------
; start
; Initialize CASM, parse the command line, assemble the source to an output PRG,
; and return to Command 64 through central cleanup.
;
; Inputs:  Command 64 external-application launch state
; Outputs: does not return directly; exitSuccess invokes DOS_EXIT
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
start:
    ; Invalidate the diagnostic location before anything can raise: CasmDiagLoc*
    ; lives in uninitialized BSS, so a locationless diagnostic (I/O or stream
    ; failure, NOT IMPLEMENTED, ...) would otherwise print a stale, garbage
    ; "AT LINE .../COL ..." trailer left over from whatever the RAM held.
    jsr diagClearLoc
    ; WP54: initialize both listing lifecycles (capture state and `.LST` file
    ; state) before resourcesInit ever runs, not after source/file/CLI init as
    ; WP51/WP53 originally placed listingStateInit -- both routines are pure
    ; BSS clears with no OS/VMM call, so they cannot fail, and doing this
    ; first guarantees artifactsAbort below can safely inspect
    ; CasmListingState/CasmListFileState from the very first fatal exit
    ; onward. Mirrors diagClearLoc's own placement immediately above, for the
    ; identical "stale BSS at a locationless early fatal" reason.
    jsr listingStateInit
    jsr listingFileInit
    jsr resourcesInit
    bcs startInitFatal
    jsr cliInit
    bcs startInitFatal
    jsr fileIoInit
    bcs startInitFatal
    jsr sourceInit
    bcs startInitFatal
    lda #CASM_PHASE_CLI_FILE
    sta CasmPhase

    ldx #<versionBanner
    ldy #>versionBanner
    jsr diagPrintString

    jsr cliParse
    bcs startInitFatal

    ; WP54: /M and /L are now activated below; only /O/S/E remain relevant
    ; here, and CASM_OPT_ALL already accepted every option cliParse itself
    ; recognizes, so there is nothing left to reject.
    jsr cliDeriveOutputName
    bcs startInitFatal

    ; WP54: the listing name derives from the output name and is needed only
    ; for /L; deriving it before symbol/source/include/lexer setup matches
    ; the plan's "before source/resource work" ordering.
    lda CasmCliOptions
    and #CASM_OPT_LIST
    beq startListingNameDone
    jsr cliDeriveListingName
    bcs startInitFatal
startListingNameDone:

    jsr symbolsInit
    bcs startInitFatal
    jsr sourceLoad
    bcs startInitFatal
    ; WP47: allocate the include metadata store (physical catalog + event
    ; log) once, after the source store exists -- the catalog's records point
    ; into that store, and every `.INCLUDE` Pass 1 resolves appends to it.
    ; This is include.s's first production call site: WP45 built the module
    ; standalone and WP46 built the traversal engine, both proven only by
    ; their own harnesses.
    jsr includeCatalogInit
    bcs startInitFatal
    jsr sourceOpen
    bcs startInitFatal
    jsr lexerInit
    bcs startInitFatal
    jmp startPass1

startInitFatal:
    ; Trampoline: initialization branches are out of direct range of the
    ; fatal tail below. Kept immediately after the init-only checks that use
    ; it (everything through the initial lexerInit) -- Pass 1/Pass 2 failures
    ; below use their own nearby startFatalNear trampoline instead, since this
    ; one is now too far from them to reach in a single branch.
    jmp startFatal

startPass1:
    ; Pass 1 (WP29): measure addresses and define labels. No output file
    ; exists yet -- emitOrg's header write and every emitRawByte call
    ; automatically no-op under CASM_PASS_MODE_MEASURE (emit.s), so it is
    ; safe to drive the full dispatch here before fileCreateOutput ever runs.
    jsr emitInit
    bcs startFatalNear1
    lda #CASM_PASS_MODE_MEASURE
    sta CasmPassMode
    jsr casmRunPass
    bcs startFatalNear1         ; outputAbort is a safe no-op: no output
                                 ; file was ever created this pass
    jmp startPass1Continue

startFatalNear1:
    ; Trampoline: WP54's growing Pass 2 tail pushed startFatalNear itself out
    ; of branch range from these two Pass 1 checks -- this one reaches
    ; startFatal directly instead.
    jmp startFatal

startPass1Continue:
    ; WP30: snapshot Pass 1's final program counter for the end-of-Pass-2
    ; agreement check below.
    lda CasmPc
    sta CasmPass1FinalPc
    lda CasmPc + 1
    sta CasmPass1FinalPc + 1

    ; Pass 2 (WP29): rewind the identical source, recreate the output PRG,
    ; and re-drive the same dispatch for real now that every label the
    ; source defines is in the symbol table.
    jsr sourceRewind
    bcs startFatalNear
    ; WP47: rewind the include-event replay cursor alongside the source
    ; itself. sourceRewind deliberately knows nothing about include.s (that
    ; module has never been a source.s dependency, and the reverse layering
    ; is what WP46 froze), so the shared caller sequences both -- exactly as
    ; it already sequences sourceRewind and lexerInit. The recorded event
    ; *count* is deliberately preserved: it is precisely what Pass 2 must
    ; consume in full.
    jsr includeReplayReset
    bcs startFatalNear
    ; WP54: enable listing capture (both VMM stores plus source-side line
    ; capture) only for /L, and only after the rewind/replay reset above --
    ; capture must observe Pass 2's real traversal from its very first
    ; statement.
    lda CasmCliOptions
    and #CASM_OPT_LIST
    beq startListingCaptureDone
    jsr listingCaptureInit
    bcs startFatalNear
startListingCaptureDone:
    jsr lexerInit
    bcs startFatalNear
    ldx #<CasmOutputName
    ldy #>CasmOutputName
    jsr fileCreateOutput
    bcs startFatalNear
    ; WP40: allocate the relocation table once, before Pass 2's real
    ; emission begins, unconditionally regardless of static/relocatable
    ; mode -- a static assembly's table simply stays empty (Phase 0C.14/17
    ; freeze; see reloc.s).
    jsr relocInit
    bcs startFatalNear
    jsr emitInit
    bcs startFatalNear
    lda #CASM_PASS_MODE_EMIT
    sta CasmPassMode
    jsr casmRunPass
    bcs startFatalNear

    ; WP47: every event Pass 1 recorded must have been consumed by the time
    ; Pass 2 reaches clean EOF. This catches a *missing* trailing event --
    ; a Pass 2 that never reached an `.INCLUDE` Pass 1 did -- which the
    ; per-site correspondence check structurally cannot detect, since a
    ; replay that stops early never performs a disagreeing comparison.
    ; Deliberately a post-loop gate, mirroring emitCheckPassAgreement below.
    jsr includeReplayFinalCheck
    bcs startFatalNear

    ; WP30: a genuine disagreement is not believed reachable through any
    ; legitimate source under the current grammar (see emitCheckPassAgreement's
    ; own header comment) -- this is a defensive internal-consistency check,
    ; not a demonstrated user-reachable path.
    jsr emitCheckPassAgreement
    bcs startFatalNear

    ; WP54: close out listing capture (flush the final byte-mirror stage,
    ; disable source-side capture) before emitFinalize/relocFinalize touch
    ; the output file -- capture only ever observes Pass 2's own dispatch,
    ; which just ended.
    lda CasmCliOptions
    and #CASM_OPT_LIST
    beq startListingFinalizeDone
    jsr listingCaptureFinalize
    bcs startFatalNear
startListingFinalizeDone:

    jsr emitFinalize
    bcs startFatalNear
    ; WP41: append the relocation table and R6 footer, unconditionally --
    ; relocFinalize itself no-ops for a static assembly (Phase 0C.14/18).
    jsr relocFinalize
    bcs startFatalNear
    jsr sourceClose
    bcs startFatalNear

    ; WP54: commit the PRG before any listing/map work -- once committed,
    ; artifactsAbort's outputAbort will never delete it, so a later listing
    ; or map failure retains a complete, valid PRG.
    jsr outputCommit
    bcs startFatalNear

    ; WP54: serialize the complete `.LST` file only for /L, only after the
    ; PRG itself is safely committed. listingWriteFile owns its own internal
    ; create/replay/format/write/close/commit sequence and its own abort on
    ; failure (never deletes an already-committed PRG).
    lda CasmCliOptions
    and #CASM_OPT_LIST
    beq startListingWriteDone
    jsr listingWriteFile
    bcs startFatalNear
startListingWriteDone:

    ; WP54: print the deterministic symbol map only for /M, only after the
    ; PRG (and any /L listing) are already committed. diagClearLoc first:
    ; CasmDiagLoc* still holds whatever the last statement stamped, which
    ; would otherwise misleadingly attach itself to a locationless map
    ; failure.
    lda CasmCliOptions
    and #CASM_OPT_MAP
    beq startMapDone
    jsr diagClearLoc
    jsr mapPrint
    bcs startFatalNear
startMapDone:

    jsr diagPrintPhase2Ready
    jmp exitSuccess

startFatalNear:
    ; Trampoline: Pass 1/Pass 2 failure branches are out of direct range of
    ; the fatal tail below (past the full casmRunPass routine).
    jmp startFatal

; ---------------------------------------------------------------------------
; casmRunPass (private)
; The single per-statement dispatch shared by both passes (WP29, per the
; Phase 0C.5 freeze): parse one statement, then dispatch by type -- a label
; (IDENTIFIER) inserts into the symbol table only under CASM_PASS_MODE_MEASURE
; (Pass 2 has nothing to do for a label: it was already defined in Pass 1), a
; MNEMONIC is matched by the opcode table and emitted, a DIRECTIVE is handled
; by the emission engine, a NEWLINE emits nothing, and EOF ends the pass
; cleanly. Every routine this calls is already pass-mode-correct on its own
; (emitRawByte's single CasmPassMode gate, parserParseExpressionValue's
; pass-mode-aware resolver handling) -- this loop itself branches on
; CasmPassMode only for the label case. On success the output is left
; registry-owned for a checked close during cleanup; INPUT VALIDATED prints
; only after the final buffered write (emitFinalize) succeeds.
;
; WP51: also drives one listing-capture transaction per statement, gated to
; Pass 2 only (crpListingBegin/crpListingCommit below) -- Pass 1 never opens
; a transaction, so a Pass-2-only commit call can never trip
; listingCommitLine's "no active transaction" guard. Both helpers are
; themselves already a no-op whenever listing capture isn't enabled, so this
; is harmless while `/L` stays rejected in production (WP54). Failed parse/
; dispatch commits nothing -- every failure branch here returns through
; crpFail without reaching a commit call, abandoning any open transaction to
; the fatal-abort path the caller takes next.
;
; Inputs:    CasmPassMode set by the caller for this pass; lexer/source READY
; Outputs:   C clear at CASM_TOKEN_EOF; C set with A = CASM_DIAG_* on any
;            parse, symbol-table, addressing-mode, emission, or listing-
;            capture failure
; Clobbers:  A, X, Y, CasmParser*/CasmLabelName* scratch, lexer/source/emit/
;            symbol/listing volatile state
; ---------------------------------------------------------------------------
casmRunPass:
    jsr crpListingBegin
    bcs crpFail
    jsr parserParseStatement
    bcs crpFail
    lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    cmp #CASM_TOKEN_IDENTIFIER
    beq crpLabel
    cmp #CASM_TOKEN_MNEMONIC
    beq crpInsn
    cmp #CASM_TOKEN_DIRECTIVE
    beq crpDir
    cmp #CASM_TOKEN_EOF
    beq crpDone
    ; NEWLINE: nothing to emit, but still commit the physical line just ended.
    jsr crpListingCommit
    bcs crpFail
    jmp casmRunPass

crpLabel:
    ; WP38: mark output started (and, on the very first qualifying statement
    ; of a relocatable assembly, write the default-origin header) before the
    ; pass-mode branch below, not after -- this must run identically in both
    ; passes so a later .ORG is rejected in Pass 1 exactly when it will also
    ; be rejected in Pass 2. Skipping this call in EMIT mode (mirroring the
    ; "nothing else to do for a label" skip just below) would let Pass 2
    ; silently disagree with Pass 1 whenever a label is the first statement.
    jsr emitMarkStarted
    bcs crpFail
    lda CasmPassMode
    cmp #CASM_PASS_MODE_MEASURE
    bne crpLabelCommit            ; EMIT: nothing else to do for a label
                                   ; statement besides the commit below
    lda CasmLabelNameLen
    ldx #<CasmLabelName
    ldy #>CasmLabelName
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldx CasmPc
    ldy CasmPc + 1
    jsr symbolsInsert
    bcs crpFail
crpLabelCommit:
    jsr crpListingCommit
    bcs crpFail
    jmp casmRunPass

crpInsn:
    jsr opcodesFindOpcode
    bcs crpFail
    jsr emitInstruction
    bcs crpFail
    jsr crpListingCommit
    bcs crpFail
    jmp casmRunPass

crpDir:
    lda CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    cmp #CASM_DIRECTIVE_INCLUDE
    bne crpEmitDir
    ; crpInclude commits the parent's own line itself, before pushing the
    ; child frame -- see its header comment.
    jsr crpInclude
    bcs crpFail
    jmp casmRunPass
crpEmitDir:
    jsr emitDirective
    bcs crpFail
    jsr crpListingCommit
    bcs crpFail
    jmp casmRunPass

crpDone:
    ; EOF: commit any pending final (unterminated) physical line. This adds
    ; no record of its own for EOF -- listingCommitLine only ever appends a
    ; record for a real physical line sourceTakeCompletedLine reports as
    ; pending, which is exactly the FINAL_UNTERMINATED case here; a source
    ; that ended cleanly on its last newline has nothing pending and this is
    ; a no-op.
    jsr crpListingCommit
    bcs crpFail
    clc
    rts
crpFail:
    rts                          ; C already set, A = CASM_DIAG_*

; ---------------------------------------------------------------------------
; crpListingBegin / crpListingCommit (private, WP51 increment 5)
; Gate listingBeginLine/listingCommitLine to Pass 2 (CASM_PASS_MODE_EMIT)
; only. Pass 1 never begins a transaction, so a Pass-1 commit call would
; otherwise trip listingCommitLine's own "no active transaction" ->
; CASM_DIAG_LISTING_REPLAY_MISMATCH guard the moment listing capture is ever
; enabled (WP54) -- both routines already no-op on their own whenever
; capture itself is disabled, but that alone does not make them Pass-1-safe
; once it isn't.
; Outputs: C clear on success (including every no-op case); C set with
;          A = CASM_DIAG_* propagated from the underlying listing.s call
; Clobbers: A, X, Y and the underlying listing.s call's own clobbers
; ---------------------------------------------------------------------------
crpListingBegin:
    lda CasmPassMode
    cmp #CASM_PASS_MODE_EMIT
    beq crpListingBeginPass2
    clc
    rts
crpListingBeginPass2:
    jmp listingBeginLine

crpListingCommit:
    lda CasmPassMode
    cmp #CASM_PASS_MODE_EMIT
    beq crpListingCommitPass2
    clc
    rts
crpListingCommitPass2:
    jmp listingCommitLine

; ---------------------------------------------------------------------------
; crpInclude (private, WP47)
; Handle one parsed `.INCLUDE` statement, in whichever pass is running. This
; is the production dispatch that WP44's/WP45's/WP46's temporary
; CASM_DIAG_NOT_IMPLEMENTED boundary stood in for, and the sequence
; tests/src/casm_frame's driver loop proved by hand: resolve the operand
; through include.s, then hand the resulting child span to source.s's frame
; push, which switches live traversal into the child transparently (the
; lexer and parser never learn a boundary was crossed; the matching pop is
; automatic at the child's own EOF, inside sourceRefill).
;
; Unlike every other statement type here, this one must branch on
; CasmPassMode itself rather than relying on a lower layer to be
; pass-mode-correct:
;
;   Pass 1 (MEASURE) discovers the include graph. It may open, read, close,
;   and append a not-yet-cataloged child (includeCatalogLoad), and records
;   one ordered event per *occurrence* -- a repeated include of an
;   already-cataloged file still records its own event, because Phase 0C.19
;   expands every time and deduplicates only the stored bytes.
;
;   Pass 2 (EMIT) replays that graph and must never touch the filesystem
;   (Phase 0C.19: "Pass 2 opens no source files"). It calls
;   includeCatalogLookup -- the load-free entry point -- and verifies the
;   independently re-derived child against the recorded event before pushing.
;   Every physical file a valid replay needs was already cataloged in Pass 1,
;   since Pass 2 only ever replays events Pass 1 itself recorded.
;
; Both paths push identically, so the bytes emitted for statements inside an
; included file depend on exactly the same traversal in both passes -- which
; is what keeps Pass 1's measured addresses and Pass 2's emitted output in
; agreement.
;
; Deliberately does NOT call emitMarkStarted: `.INCLUDE` emits nothing, and
; marking output started here would reject a `.ORG` at the top of an included
; file that the equivalent flattened source accepts. Flattened equivalence is
; the governing property (Phase 9 verification matrix), so the include
; statement itself must be emission-transparent.
;
; Inputs:    a parsed `.INCLUDE` statement; CasmIncludeFilename/…Len hold the
;            validated operand (WP44); CasmPassMode set for this pass
; Outputs:   C clear on success, with live traversal switched into the child
;            C set, A = CASM_DIAG_* on failure, with the diagnostic location
;            stamped to the `.INCLUDE` site itself (Phase 0C.19: "Include
;            load failures point at the parent `.INCLUDE` site")
; Clobbers:  A, X, Y, CasmValue0Lo/Hi, CasmValue1Lo/Hi, CrpInc* scratch and
;            every routine it calls
; ---------------------------------------------------------------------------
crpInclude:
    jsr crpParentIdentity
    bcs crpIncFail
    lda CasmPassMode
    cmp #CASM_PASS_MODE_MEASURE
    bne crpIncReplay

    ; --- Pass 1: discover, load (or reuse), and record -------------------
    lda CrpIncParentDevice
    ldx #<CasmIncludeFilename
    ldy #>CasmIncludeFilename
    jsr includeCatalogLoad
    bcs crpIncFail
    stx CrpIncChildIndex
    jsr crpStageEvent
    jsr includeEventRecord
    bcs crpIncFail
    jmp crpIncCommit

    ; --- Pass 2: replay, verifying correspondence ------------------------
crpIncReplay:
    lda CrpIncParentDevice
    ldx #<CasmIncludeFilename
    ldy #>CasmIncludeFilename
    jsr includeCatalogLookup
    bcs crpIncLookupMiss
    stx CrpIncChildIndex
    jsr crpStageEvent
    jsr includeEventReplay
    bcs crpIncFail

crpIncCommit:
    ; Commit the `.INCLUDE` statement's own (parent) physical line before
    ; switching live traversal into the child -- this directive is excluded
    ; from casmRunPass's ordinary post-dispatch commit (crpEmitDir), so it is
    ; committed here instead, exactly once, regardless of which pass path
    ; reached it. A commit failure prevents the push below.
    jsr crpListingCommit
    bcs crpIncFail

crpIncPush:
    ; The resolved child's own 128-byte record is already staged in
    ; CasmIncludeRecordStage -- by includeCatalogLoad (whether it hit an
    ; existing record or built a new one) or by includeCatalogLookup's hit.
    ; sourceFramePush wants start and *end*, so the length is added here;
    ; both are staged immediately before the call rather than carried across
    ; any intervening one, matching sourceFramePush's own documented
    ; contract.
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
    lda CrpIncChildIndex
    jsr sourceFramePush
    bcs crpIncFail
    clc
    rts

crpIncLookupMiss:
    ; C set from includeCatalogLookup: either a real failure (propagate it)
    ; or a genuine catalog miss. A miss cannot legitimately happen in Pass 2
    ; -- the catalog is immutable between passes and Pass 1 cataloged every
    ; child it recorded -- so it is a replay divergence, not a user error.
    cmp #CASM_DIAG_NONE
    bne crpIncFail
    lda #CASM_DIAG_INCLUDE_REPLAY_MISMATCH
crpIncFail:
    ; Stamp the `.INCLUDE` site itself, preserving the diagnostic in A.
    ; Done only on the failure path, matching this codebase's convention
    ; that a location is recorded when raising rather than speculatively on
    ; every statement (a location set by a *successful* statement would
    ; later attach itself to an unrelated locationless diagnostic).
    pha
    jsr diagSetLocFromStmt
    pla
    sec
    rts

; ---------------------------------------------------------------------------
; crpParentIdentity (private, WP47)
; Identify the file that *contains* the `.INCLUDE` statement being handled,
; and the device its unprefixed children should inherit.
;
; The two possible parents live in different namespaces, which is exactly why
; an include event stores a (kind, id) pair rather than a bare index:
;
;   depth 0 -- the parent is a top-level root, identified by
;   CasmSourceFileId. Top-level files are deliberately not catalog entries
;   (WP45/WP46 left that unification to WP48), so its device is re-derived
;   on demand from its own preserved CLI spelling (cli.s's CasmSourceNames,
;   reached through the compile-time cliSourceSlot tables) via the same
;   DOS_PARSE_PREFIX resolution include.s applies to a child, defaulting to
;   CurrentDevice when unprefixed. That is Phase 0C.19's "an unprefixed
;   top-level file captures CurrentDevice during initial load", evaluated
;   lazily rather than stored -- observably identical, since nothing in CASM
;   changes CurrentDevice during a run.
;
;   depth > 0 -- the parent is itself an included file, identified by the
;   active frame's catalog index, whose own record already stores its
;   resolved device.
;
; Inputs:    CasmFrameDepth and the live traversal state
; Outputs:   C clear, with CrpIncParentKind/CrpIncParentId/CrpIncParentDevice
;            populated
;            C set, A = CASM_DIAG_* (propagated from includeCatalogRead)
; Clobbers:  A, X, Y, CasmPtr0Lo/Hi and the called routines' own clobbers
; ---------------------------------------------------------------------------
crpParentIdentity:
    lda CasmFrameDepth
    bne cpiFrame

    lda #CASM_INCLUDE_EVENT_PARENT_KIND_ROOT
    sta CrpIncParentKind
    lda CasmSourceFileId
    sta CrpIncParentId
    tax
    lda cliSourceSlotHi, x
    tay
    lda cliSourceSlotLo, x
    tax                          ; X/Y = this root's own original spelling
    lda CurrentDevice            ; the unprefixed default, per Phase 0C.19
    jsr includeResolveDevice
    sta CrpIncParentDevice
    clc
    rts

cpiFrame:
    lda #CASM_INCLUDE_EVENT_PARENT_KIND_FRAME
    sta CrpIncParentKind
    ; 0-based array index of the currently active frame is CasmFrameDepth-1.
    ; Reloaded explicitly rather than reusing the depth still in A on entry
    ; from the branch above -- the kind constant just overwrote it, and a
    ; `tax` here would silently index frame 0 at every depth (harmlessly
    ; correct at depth 1, wrong at every deeper level).
    ldx CasmFrameDepth
    dex
    lda CasmFrameCatalogIndex, x
    sta CrpIncParentId
    jsr includeCatalogRead       ; A = index; fills CasmIncludeRecordStage
    bcs cpiFail
    lda CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_DEVICE
    sta CrpIncParentDevice
    clc
cpiFail:
    rts                          ; A/C already set by includeCatalogRead

; ---------------------------------------------------------------------------
; crpStageEvent (private, WP47)
; Stage the six-field include-event tuple describing the `.INCLUDE` currently
; being handled. Pass 1 persists it (includeEventRecord); Pass 2 stages the
; same tuple, independently re-derived this pass, as the candidate a recorded
; event must match (includeEventReplay). Both passes build it here, from one
; routine, so a replay can never disagree merely because the two paths
; assembled the tuple differently.
;
; The include-site line/column come from CasmStmtLoc*, stamped by
; parserParseStatement on this statement's first token -- deliberately not
; the live source position, which has already advanced past the operand by
; the time this runs.
;
; Inputs:    CrpIncParentKind/CrpIncParentId/CrpIncChildIndex populated;
;            CasmStmtLoc* stamped for this statement
; Outputs:   CasmIncludeEventStage's six meaningful fields populated
; Preserves: X, Y
; Clobbers:  A, processor flags
; ---------------------------------------------------------------------------
crpStageEvent:
    lda CrpIncParentKind
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_KIND
    lda CrpIncParentId
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_ID
    lda CasmStmtLocLineLo
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_LINE_LO
    lda CasmStmtLocLineHi
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_LINE_HI
    lda CasmStmtLocColumn
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_PARENT_COLUMN
    lda CrpIncChildIndex
    sta CasmIncludeEventStage + CASM_INCLUDE_EVENT_CHILD_INDEX
    rts

startFatal:
    ; Best-effort delete of any partial listing/output artifacts while
    ; preserving the primary diagnostic in A, then route through central
    ; cleanup.
    jmp artifactsAbort

; ---------------------------------------------------------------------------
; artifactsAbort (private, WP54)
; Unified fatal routing for every artifact this run may have created: the
; `.LST` listing file (if any) and the PRG output file. Chains listing.s's
; and fileio.s's own already-independently-safe abort routines, each of
; which is a documented no-op when nothing was ever created and never
; deletes an already-committed artifact -- calling both unconditionally on
; every fatal exit, regardless of how far initialization got or which
; options were active, is always safe.
;
; Both listingAbort and outputAbort share the identical "A in = primary (or
; CASM_DIAG_NONE), A out = primary or first cleanup diagnostic" contract, so
; chaining them here composes correctly: whichever of (the caller's primary,
; a listing cleanup failure, an output cleanup failure) occurred first is
; the one that survives to exitFatal.
;
; Inputs:    A = primary CASM_DIAG_* value, or CASM_DIAG_NONE
; Outputs:   does not return; falls into exitFatal with A = preserved
;            primary or first cleanup failure
; Clobbers:  A, X, Y and listingAbort/outputAbort's own clobbers
; ---------------------------------------------------------------------------
artifactsAbort:
    jsr listingAbort
    jsr outputAbort
    jmp exitFatal

.segment "BSS"

; WP47 `.INCLUDE` dispatch scratch. Held only across one crpInclude call, but
; kept in named BSS rather than shared zero-page scratch: crpInclude calls
; include.s and source.s routines that document CasmValue*/CasmPtr*/
; CasmSourceScratch* as their own scratch, and this project has already been
; bitten three times (WP23-25, WP44, WP45) by state that looked safe to carry
; across such a call and was not.
CrpIncParentKind:   .res 1
CrpIncParentId:     .res 1
CrpIncParentDevice: .res 1
CrpIncChildIndex:   .res 1

.segment "RODATA"

versionBanner:
    .byte "CASM V", VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE, "."
    .byte BUILD_NUMBER
    .byte PetCr, 0
