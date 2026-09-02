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
.define VERSION_MINOR "6"
.define VERSION_STAGE "0"
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
.import CasmLabelDefinedAtOffsetLo
.import CasmLabelDefinedAtOffsetHi
.import opcodesFindOpcode
.import diagPrintPhase2Ready

.import sourceRewind
.import symbolsInit
.import symbolsInsert
.import CasmSymbolInsertFlags
.import CasmSymbolInsertRefVmmLo
.import CasmSymbolInsertRefVmmHi
.import CasmSymbolInsertRefLen
.import CasmSymbolInsertRefAddendLo
.import CasmSymbolInsertRefAddendHi
.import CasmSymbolInsertRefSign
.import CasmSymbolInsertRefExtract
.import CasmSymbolInsertDefinedAtOffsetLo
.import CasmSymbolInsertDefinedAtOffsetHi
.import CasmSymbolInsertScopeLo
.import CasmSymbolInsertScopeHi
.import CasmSymbolLookupScopeLo
.import CasmSymbolLookupScopeHi

; WP65: ppsConstant's own staged output (parser.s) for a just-parsed
; `identifier = expr` statement.
.import CasmConstantResolved
.import CasmConstantValueLo
.import CasmConstantValueHi
.import CasmConstantRefVmmLo
.import CasmConstantRefVmmHi
.import CasmConstantRefLen
.import CasmConstantRefAddendSign
.import CasmConstantRefAddendLo
.import CasmConstantRefAddendHi
.import CasmConstantRefExtract
.import CasmConstantIsCurAddr

; WP65: casmResolveConstants' own dependencies -- symbolsReadByIndex/
; symbolsUpdateByIndex to walk and patch the symbol table directly by
; record index, symbolsLookup to resolve a deferred reference's own name,
; CasmSourceVmmSlot + vmmWindowRead to re-fetch that name's raw bytes from
; the single shared source VMM allocation via the absolute offset
; ppsConstant captured, CasmVmmBuffer as the shared VMM staging area every
; one of those calls stages through, and diagClearLoc so a diagnostic
; raised from the sweep (no "current token" exists at this point) never
; shows a stale location left over from Pass 1's last parsed statement.
.import symbolsReadByIndex
.import symbolsUpdateByIndex
.import symbolsLookup
.import CasmSourceVmmSlot
.import vmmWindowRead
.import CasmVmmBuffer
.import diagClearLoc

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

; Progress Increment 4.
.import progressInit
.import progressBeginPass
.import progressStatement
.import progressCompletePass
.import progressCheckPassTotals
.import progressRenderTransient
.import progressSuspend
.import progressFinalSummary
.import progressSourceLoadBytes
.import CasmProgArgDepth
.import CasmProgArgFileId
.import CasmProgArgLineLo
.import CasmProgArgLineHi
.import CasmProgArgNameBuf
.import CasmSourceLineLo
.import CasmSourceLineHi

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
    ; WP60 Increment 3: structural entry invariant, independent of OS_API
    ; ordering. CASM has no supported decimal-mode entry contract; this
    ; hardens against a future reachable ADC/SBC ever running before the
    ; first OS_API call (which currently -- incidentally -- clears D itself).
    cld
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
    ; Progress state: zeroed HERE, not at startPass1 (task 43), for the same
    ; reason as the three clears above. Any diagnostic raised before Pass 1
    ; -- CLI/file/lexer-init failures -- reaches diagPrintFatal, whose first
    ; act is progressClearTransient; that routine tests CasmProgFlags, which
    ; only progressInit clears. Without this call CasmProgFlags is
    ; uninitialized RAM and a bit-0-set garbage byte makes
    ; progressClearTransient erase the current screen line (the banner).
    ; progressInit is a pure BSS clear, no OS/VMM call, cannot fail.
    ; Placed before resourcesInit so even a future fallible early init is
    ; covered. Nothing writes progress state between here and
    ; progressBeginPass, so one init point is correct.
    jsr progressInit
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
    ; Progress Increment 5: seed the load line's identity before sourceLoad
    ; opens anything. CasmSourceFileId is not yet meaningful here (nothing
    ; has been traversed), so the top-level slot 0 name is resolved directly
    ; -- the first file sourceLoad reads. Included files re-seed this from
    ; crpInclude before their own sourceAppendFile runs.
    lda #0
    sta CasmProgArgFileId
    sta CasmProgLastFileId
    lda #0                       ; top-level slot 0 = the first source file
    jsr crpSnapshotName
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
    ; Progress Increment 4 placed progressInit here (before Pass 1's first
    ; "p1: start" line). Task 43 moved it up into the early-init block, so
    ; diagPrintFatal is safe on a pre-Pass-1 fatal too; nothing between
    ; there and here touches progress state.
    ; Pass 1 (WP29): measure addresses and define labels. No output file
    ; exists yet -- emitOrg's header write and every emitRawByte call
    ; automatically no-op under CASM_PASS_MODE_MEASURE (emit.s), so it is
    ; safe to drive the full dispatch here before fileCreateOutput ever runs.
    jsr emitInit
    bcs startFatalNear1
    lda #CASM_PASS_MODE_MEASURE
    sta CasmPassMode
    ; WP89: no local-label scope is open until the first global label of
    ; this pass. CASM_SYMBOL_CHAIN_END ($FFFF) is the "none yet" sentinel;
    ; crpLabel bumps this on every global label, identically in both
    ; passes (globals appear in the same order each pass), so a local's
    ; owning-scope ordinal is stable across the Pass1->Pass2 boundary.
    lda #<CASM_SYMBOL_CHAIN_END
    sta CasmCurrentScopeLo
    lda #>CASM_SYMBOL_CHAIN_END
    sta CasmCurrentScopeHi
    ; Progress Increment 4: begin Pass 1 only after CasmPassMode is set to
    ; MEASURE, per the Hook Contract -- progressBeginPass cannot fail.
    lda #$FF                    ; Increment 5: force a name snapshot on the
    sta CasmProgLastFileId       ; first statement of this pass
    sta CasmProgLastDepth
    lda #1
    jsr progressBeginPass
    jsr casmRunPass
    bcs startFatalNear1         ; outputAbort is a safe no-op: no output
                                 ; file was ever created this pass
    ; Progress Increment 4: Pass 1 dispatch is done -- latch its total and
    ; print "p1: done NNNNN statements" before moving on to constant
    ; resolution/Pass 2 setup. Cannot fail.
    jsr progressCompletePass
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

    ; WP65: resolve every named constant Pass 1 left deferred, now that
    ; every label and every constant's own name is in the symbol table --
    ; the one point in casm's own control flow both are simultaneously true
    ; without yet having rewound into Pass 2's real emission.
    ; WP89: the constant-resolution sweep looks up only global/constant
    ; names (Phase 14 forbids a local on a constant's RHS), so force the
    ; lookup scope filter to "no scope" -- a matched global record is
    ; never scope-checked, but this keeps the sweep from carrying the last
    ; statement's stale scope value.
    lda #<CASM_SYMBOL_CHAIN_END
    sta CasmSymbolLookupScopeLo
    lda #>CASM_SYMBOL_CHAIN_END
    sta CasmSymbolLookupScopeHi
    jsr casmResolveConstants
    bcc startPass1ConstantsOk
    jmp startFatal
startPass1ConstantsOk:
    jmp startPass2Setup

; Progress Increment 4: Pass 1's completion sequence (progressInit's call
; site, progressBeginPass/progressCompletePass) pushed sourceRewind's and
; includeReplayReset's own fatal checks out of branch range from
; startFatalNear -- this near trampoline reaches it directly, same
; precedent as startFatalNear1 above.
startFatalNear2:
    jmp startFatalNear

startPass2Setup:

    ; Pass 2 (WP29): rewind the identical source, recreate the output PRG,
    ; and re-drive the same dispatch for real now that every label the
    ; source defines is in the symbol table.
    jsr sourceRewind
    bcs startFatalNear2
    ; WP47: rewind the include-event replay cursor alongside the source
    ; itself. sourceRewind deliberately knows nothing about include.s (that
    ; module has never been a source.s dependency, and the reverse layering
    ; is what WP46 froze), so the shared caller sequences both -- exactly as
    ; it already sequences sourceRewind and lexerInit. The recorded event
    ; *count* is deliberately preserved: it is precisely what Pass 2 must
    ; consume in full.
    jsr includeReplayReset
    bcs startFatalNear2
    ; WP54: enable listing capture (both VMM stores plus source-side line
    ; capture) only for /L, and only after the rewind/replay reset above --
    ; capture must observe Pass 2's real traversal from its very first
    ; statement.
    lda CasmCliOptions
    and #CASM_OPT_LIST
    beq startListingCaptureDone
    jsr listingCaptureInit
    bcs startFatalNear2          ; Increment 5 growth pushed startFatalNear
                                 ; out of range from here too
startListingCaptureDone:
    jsr lexerInit
    bcs startFatalNear2          ; Increment 7 growth pushed startFatalNear
                                 ; out of range from these three checks too
    ldx #<CasmOutputName
    ldy #>CasmOutputName
    jsr fileCreateOutput
    bcs startFatalNear2
    ; WP40: allocate the relocation table once, before Pass 2's real
    ; emission begins, unconditionally regardless of static/relocatable
    ; mode -- a static assembly's table simply stays empty (Phase 0C.14/17
    ; freeze; see reloc.s).
    jsr relocInit
    bcs startFatalNear2
    jsr emitInit
    bcs startFatalNear2          ; Increment 7 growth pushed startFatalNear
                                 ; out of range from this check too
    lda #CASM_PASS_MODE_EMIT
    sta CasmPassMode
    ; WP89: reset the scope ordinal for Pass 2 exactly as Pass 1 did.
    lda #<CASM_SYMBOL_CHAIN_END
    sta CasmCurrentScopeLo
    lda #>CASM_SYMBOL_CHAIN_END
    sta CasmCurrentScopeHi
    ; Progress Increment 4: begin Pass 2 only after CasmPassMode is set to
    ; EMIT. Resets the active counter/divider and flips the internal
    ; pass-2 flag; cannot fail.
    lda #$FF                    ; Increment 5: force a name snapshot on the
    sta CasmProgLastFileId       ; first statement of this pass
    sta CasmProgLastDepth
    lda #2
    jsr progressBeginPass
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

    ; Progress Increment 4: an additional deterministic-replay check, not a
    ; replacement for the final-PC/include-event agreement checks above --
    ; per the Hook Contract, this runs after both of them and before
    ; listing capture finalization, and "p2: done" (progressCompletePass,
    ; just below) prints only once this has also passed.
    jsr progressCheckPassTotals
    bcs startFatalNear
    jsr progressCompletePass

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

    ; Progress Increment 7 (Atomic Increment 3): the "write: <name>"
    ; persistent finalization line, per the Hook Contract -- after pass/
    ; listing-capture agreement, before emitFinalize. progressCompletePass
    ; just above already cleared the transient line as its own first
    ; action, so there is nothing left on screen to clear here. A one-shot
    ; print straight from casm.s, not a progress.s routine: the Increment 2
    ; design review's own conclusion for exactly this case ("load:"/
    ; "write:" persistent lines are cheap enough for the calling module to
    ; emit directly"). The full CasmOutputName is printed, not an 8-char
    ; truncated field -- this is a persistent line, not the 34-column
    ; transient status line, so no width contract applies.
    ldx #<msgWritePrefix
    ldy #>msgWritePrefix
    jsr diagPrintString
    ldx #<CasmOutputName
    ldy #>CasmOutputName
    jsr diagPrintString
    ldx #<msgProgressCrOnly
    ldy #>msgProgressCrOnly
    jsr diagPrintString

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
    ; Progress Increment 7 (Atomic Increment 5): suspend before
    ; listingWriteFile, per the Hook Contract. progressCompletePass at
    ; Pass 2's own end already cleared the transient line and nothing
    ; between there and here renders it again -- this call is defensive
    ; completeness against a future increment adding rendering to any of
    ; the intervening steps, not a fix for an observed bug today.
    ; progressSuspend is idempotent (its own progressClearTransient no-ops
    ; when nothing is visible), so calling it here even though the line is
    ; already clear costs nothing and asserts the ownership boundary
    ; explicitly: listing rows, map symbol iteration, and VMM capture
    ; loops must never be instrumented.
    jsr progressSuspend
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
    ; Progress Increment 7 (Atomic Increment 5): suspend before mapPrint --
    ; same rationale as the listingWriteFile suspend above. Both fire in
    ; sequence when /L and /M are combined, matching "including option
    ; combinations."
    jsr progressSuspend
    jsr mapPrint
    bcs startFatalNear
startMapDone:

    ; Progress Increment 7 (Atomic Increment 6): print the approved final
    ; summary ("done: p1 NNNNN, p2 NNNNN, NNNNN bytes") ahead of the
    ; existing success message, rather than replacing it. Keeping
    ; "CASM: INPUT VALIDATED" is deliberate: docs/casm-utility.md documents
    ; it as CASM's success signal verbatim ("On success, it prints CASM:
    ; INPUT VALIDATED and returns to the shell"), so removing it would be a
    ; breaking documentation change, not an internal detail -- user-decided
    ; 2026-08-26. progressFinalSummary clears the transient line itself
    ; first; nothing has rendered since the last mapPrint/listingWriteFile
    ; suspend, so that call is a no-op here, not a fix for a live bug.
    jsr progressFinalSummary
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
    bcc crpBeginOk
    jmp crpFail
crpBeginOk:
    ; WP89: publish the current local-label scope for this statement's
    ; operand expression, which parserParseStatement evaluates inline
    ; (parseOperandSequence -> parserParseExpressionValue -> the
    ; symbolsLookup resolver). CasmCurrentScope already reflects every
    ; global label dispatched before this statement -- a label is always
    ; its own statement, so a `@local` reference can never appear in the
    ; same statement that opened its scope.
    lda CasmCurrentScopeLo
    sta CasmSymbolLookupScopeLo
    lda CasmCurrentScopeHi
    sta CasmSymbolLookupScopeHi
    jsr parserParseStatement
    bcc :+
    jmp crpFail
    :
        lda CasmParserStmt + CASM_PARSER_STMT_TYPE
    cmp #CASM_TOKEN_IDENTIFIER
    beq crpCountLabel
    cmp #CASM_TOKEN_EQUALS
    beq crpCountConstant
    cmp #CASM_TOKEN_MNEMONIC
    bne :+
    jmp crpCountInsn
    :
    cmp #CASM_TOKEN_DIRECTIVE
    bne :+
    jmp crpCountDir
    :
    cmp #CASM_TOKEN_EOF
    bne :+
    jmp crpDone
    :
    ; NEWLINE: nothing to emit, but still commit the physical line just ended.
    jsr crpListingCommit
    bcc :+
    jmp crpFail
    :
        jmp casmRunPass

; ---------------------------------------------------------------------------
; crpCountLabel/Constant/Insn/Dir (Progress Increment 4, private)
; The shared statement-count hook (progressStatement) for the four token
; types the parent plan says to count: label, constant, mnemonic, and
; directive (.INCLUDE counts once here too, as a DIRECTIVE, before crpDir's
; own INCLUDE/emit split). Four tiny trampolines, not one shared call site,
; because the dispatch above is a sequential cmp/beq chain against a single
; loaded A -- calling progressStatement (which clobbers A) partway through
; that chain would corrupt the remaining comparisons for token types
; checked later in the chain. Each trampoline already knows statically
; which handler it's headed to, so there is nothing to "reload" once inside
; one: the four real handlers below were already reading whatever they need
; fresh from CasmParserStmt in memory, not from a carried-over register.
; ---------------------------------------------------------------------------
crpCountLabel:
    jsr crpProgressHook
    bcc :+
    jmp crpFail
    :
        jmp crpLabel
crpCountConstant:
    jsr crpProgressHook
    bcc :+
    jmp crpFail
    :
        jmp crpConstant
crpCountInsn:
    jsr crpProgressHook
    bcc :+
    jmp crpFail
    :
        jmp crpInsn
crpCountDir:
    jsr crpProgressHook
    bcc :+
    jmp crpFail
    :
        jmp crpDir

; ---------------------------------------------------------------------------
; crpProgressHook (Progress Increment 5, private)
; Count one dispatched statement, then redraw the transient line when either
; the 64-statement throttle says one is due OR the active physical file has
; changed since the last redraw.
;
; The identity check is what makes this one hook cover every case the
; Increment 5 Hook Contract lists -- include frame push, frame pop, EVERY
; cascading pop, and each committed root transition -- without a single hook
; inside source.s's own frame machinery. Any of those events changes
; CasmSourceFileId; the next dispatched statement observes the change and
; redraws immediately with a freshly resolved filename, bypassing the
; throttle. This is strictly "after commit" by construction (the statement
; cannot dispatch until the traversal state is committed), and it keeps
; every cli.s/include.s dependency here in casm.s, which already imports
; them -- source.s must not depend on include.s (the layering WP46 froze).
;
; Out: C=0 on success; C=1 with A = CASM_DIAG_* propagated from
;      progressStatement's own counter-overflow guard.
; Clobbers: A, X, Y, and -- on the identity-changed path only (first
;           statement of a pass, every frame push/pop) -- CasmPtr0Lo/Hi,
;           via crpSnapshotName. Verified safe (Increment 9 review PR-4):
;           emit.s/opcodes.s never read CasmPtr0, and crpLabel/crpConstant/
;           crpInclude set it fresh -- but a future CasmPtr0 use added to
;           crpInsn/crpDir, or a parser change that left something durable
;           there, would need this hook moved or CasmPtr0 saved.
; ---------------------------------------------------------------------------
crpProgressHook:
    jsr progressStatement
    bcs cphOut                   ; overflow -> propagate C=1 and A untouched
    tax                          ; X = throttle verdict (1 = redraw due)
    ; Identity is (file id, frame depth), not file id alone. Increment 5
    ; verified live that CasmSourceFileId reads F00 for BOTH a parent and
    ; its included child, so keying on it alone never fires on a push or
    ; pop -- the child's name stayed on screen after the pop returned to
    ; the parent. CasmFrameDepth does change on every push, pop, and each
    ; step of a cascading pop, and the pair together still distinguishes
    ; two different roots that happen to sit at the same depth.
    lda CasmFrameDepth
    cmp CasmProgLastDepth
    bne cphIdentityChanged
    lda CasmSourceFileId
    cmp CasmProgLastFileId
    beq cphThrottleOnly          ; same file and depth -> honor the throttle
cphIdentityChanged:
    lda CasmFrameDepth
    sta CasmProgLastDepth
    lda CasmSourceFileId
    sta CasmProgLastFileId
    jsr crpSnapshotName          ; identity changed -> refresh the name and
    jmp cphRender                ; redraw now, regardless of the throttle
cphThrottleOnly:
    cpx #0
    beq cphOk
cphRender:
    lda CasmFrameDepth
    sta CasmProgArgDepth
    lda CasmSourceFileId
    sta CasmProgArgFileId
    lda CasmSourceLineLo
    sta CasmProgArgLineLo
    lda CasmSourceLineHi
    sta CasmProgArgLineHi
    jsr progressRenderTransient
cphOk:
    clc
cphOut:
    rts

; ---------------------------------------------------------------------------
; crpSnapshotName (Progress Increment 5, private)
; Fill CasmProgArgNameBuf with the first eight characters of the active
; file's name, space-padded, resolving the packed identity in
; CasmSourceFileId the same way diagnostics.s's diagPrintIncludeIdentity
; does: bit 7 clear = a top-level slot (cliSourceSlotLo/Hi), bit 7 set = an
; include-catalog record. Kept explicitly distinct, per the Hook Contract's
; "top-level ID, include catalog ID, packed diagnostic ID, and displayed
; physical-file ID" separation -- this routine is the single place the
; packed form is decoded for display.
;
; A failed includeCatalogRead is not fatal here: the buffer is left
; space-filled and the line simply shows a blank name, since progress
; rendering must never mask or replace a real assembler diagnostic.
; In: A = packed physical-file identity to resolve (NOT read from
;     CasmSourceFileId directly -- the pre-traversal top-level load call
;     site has no meaningful CasmSourceFileId yet and passes slot 0).
; Clobbers: A, X, Y, CasmPtr0Lo/Hi
; ---------------------------------------------------------------------------
crpSnapshotName:
    ; Resolve from the FRAME STACK, not from CasmSourceFileId's packed
    ; form. Increment 5 verified live that CasmSourceFileId reads $00
    ; throughout an included file's traversal -- it never carries the
    ; frame flag or the catalog index -- so decoding it returns the
    ; top-level slot no matter how deep the include nesting is, which is
    ; exactly the wrong answer (the child's correct name, seeded by
    ; crpInclude, was being overwritten with the parent's on every push).
    ; CasmFrameCatalogIndex[depth-1] is the authoritative catalog index of
    ; the file actually being traversed; depth 0 means a top-level source
    ; slot. A is ignored and kept only for call-site compatibility.
    ldx CasmFrameDepth
    beq csnTopLevel
    dex
    lda CasmFrameCatalogIndex, x
    jsr includeCatalogRead
    bcc csnStage
    ldx #<msgProgBlankName       ; unavailable -> render a blank name
    ldy #>msgProgBlankName
    jmp crpSnapshotNameFromPtr
csnTopLevel:
    ; Depth 0: the active top-level source slot. CasmSourceFileId IS
    ; meaningful here (it selects among multiple top-level files).
    lda CasmSourceFileId
    and #CASM_DIAG_FILEID_ID_MASK
    tax
    lda cliSourceSlotHi, x
    tay
    lda cliSourceSlotLo, x
    tax
    jmp crpSnapshotNameFromPtr
csnStage:
    ldx #<(CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAME)
    ldy #>(CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAME)
    ; fall through

; ---------------------------------------------------------------------------
; crpSnapshotNameFromPtr (Progress Increment 5, private)
; Copy up to eight bytes of a null-terminated name into the transient
; line's fixed 8-byte field, space-padding a shorter name. Shared by the
; packed-identity resolver above and by crpInclude, which seeds a child's
; name straight from CasmIncludeFilename before the child is loaded (the
; catalog index that would let the packed resolver find it does not exist
; until includeCatalogLoad returns).
; In: X/Y = pointer lo/hi to a null-terminated name
; Clobbers: A, X, Y, CasmPtr0Lo/Hi
; ---------------------------------------------------------------------------
crpSnapshotNameFromPtr:
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    ldy #7
    lda #' '
csnBlank:
    sta CasmProgArgNameBuf, y
    dey
    bpl csnBlank
    ldy #0
csnCopyLoop:
    lda (CasmPtr0Lo), y
    beq csnDone                  ; short name -> keep the space padding
    sta CasmProgArgNameBuf, y
    iny
    cpy #8
    bne csnCopyLoop
csnDone:
    rts

msgProgBlankName:
    .byte 0

crpLabel:
    ; WP38: mark output started (and, on the very first qualifying statement
    ; of a relocatable assembly, write the default-origin header) before the
    ; pass-mode branch below, not after -- this must run identically in both
    ; passes so a later .ORG is rejected in Pass 1 exactly when it will also
    ; be rejected in Pass 2. Skipping this call in EMIT mode (mirroring the
    ; "nothing else to do for a label" skip just below) would let Pass 2
    ; silently disagree with Pass 1 whenever a label is the first statement.
    jsr emitMarkStarted
    bcc @markOk
    jmp crpFail
@markOk:
    ; WP89: a `@name` label is a local scoped to the most recent global
    ; label; anything else is a global label that opens a new scope.
    lda CasmLabelName
    cmp #CASM_PETSCII_AT
    beq crpLabelLocal

    ; Global label: bump the scope ordinal ($FFFF -> 0 -> 1 ...), the same
    ; way in both passes (globals dispatch in identical order each pass),
    ; so a local's owning-scope value is stable across the Pass1->Pass2
    ; boundary without any record-index lookup.
    inc CasmCurrentScopeLo
    bne @scopeBumped
    inc CasmCurrentScopeHi
@scopeBumped:
    lda CasmPassMode
    cmp #CASM_PASS_MODE_MEASURE
    bne crpLabelCommit            ; EMIT: symbol already inserted in Pass 1
    ldx #<CasmLabelName
    ldy #>CasmLabelName
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmSymbolInsertFlags
    lda CasmLabelNameLen
    ldx CasmPc
    ldy CasmPc + 1
    jsr symbolsInsert
    bcc crpLabelCommit
    jmp crpFail

crpLabelLocal:
    ; A local label needs a scope already open (a preceding global label).
    lda CasmCurrentScopeLo
    cmp #<CASM_SYMBOL_CHAIN_END
    bne @localScoped
    lda CasmCurrentScopeHi
    cmp #>CASM_SYMBOL_CHAIN_END
    bne @localScoped
    ; WP89: point the diagnostic at this label statement (CasmStmtLoc was
    ; stamped for it by parserParseStatement), not at wherever the last
    ; expression-operand parse left CasmDiagLoc.
    jsr diagSetLocFromStmt
    lda #CASM_DIAG_LOCAL_WITHOUT_SCOPE
    sec
    jmp crpFail
@localScoped:
    lda CasmPassMode
    cmp #CASM_PASS_MODE_MEASURE
    bne crpLabelCommit            ; EMIT: symbol already inserted in Pass 1
    ldx #<CasmLabelName
    ldy #>CasmLabelName
    stx CasmPtr0Lo
    sty CasmPtr0Hi
    lda #(CASM_SYMBOL_FLAG_DEFINED | CASM_SYMBOL_FLAG_LOCAL)
    sta CasmSymbolInsertFlags
    lda CasmCurrentScopeLo
    sta CasmSymbolInsertScopeLo
    lda CasmCurrentScopeHi
    sta CasmSymbolInsertScopeHi
    lda CasmLabelNameLen
    ldx CasmPc
    ldy CasmPc + 1
    jsr symbolsInsert
    bcc crpLabelCommit
    pha                          ; symbolsInsert's diag code
    jsr diagSetLocFromStmt        ; WP89: point at this label statement (clobbers A)
    pla
    cmp #CASM_DIAG_DUPLICATE_SYMBOL
    bne @localPropagate
    lda #CASM_DIAG_DUPLICATE_LOCAL
@localPropagate:
    sec
    jmp crpFail

    crpLabelCommit:
    jsr crpListingCommit
    bcc :+
    jmp crpFail
    :
        jmp casmRunPass

; ---------------------------------------------------------------------------
; crpConstant (WP65, private)
; Insert an `identifier = expr` statement's symbol, Pass 1 (MEASURE) only --
; mirrors crpLabel's own pass-mode gate exactly, since a constant's
; existence in the table (like a label's) only needs establishing once.
; Unlike a label, a constant's own VALUE may still be unresolved after this
; call (an identifier RHS forward-referencing a not-yet-defined symbol);
; casmRunPass's caller runs casmResolveConstants (below) at the Pass1->
; Pass2 boundary specifically to finish what this call leaves deferred.
; No emitMarkStarted call: a bare constant definition has no address of its
; own and must not itself trigger the default-origin header a label or
; instruction would (WP38's own concern doesn't apply here).
; ---------------------------------------------------------------------------
crpConstant:
    lda CasmPassMode
    cmp #CASM_PASS_MODE_MEASURE
    beq crpConstantMeasure
    jmp crpConstantCommit         ; EMIT: nothing else to do -- the symbol
                                   ; and its final value already exist from
                                   ; Pass 1 plus the resolution sweep
crpConstantMeasure:
    ldx #<CasmLabelName
    ldy #>CasmLabelName
    stx CasmPtr0Lo
    sty CasmPtr0Hi

    ; WP66: '*' RHS. Unlike an identifier's forward reference, CasmPc is
    ; already final the instant this Pass 1 statement runs (the same fact
    ; crpLabel itself relies on, immediately below in this file) -- so this
    ; resolves inline here rather than waiting for casmResolveConstants'
    ; Pass1->Pass2 sweep. Computes CasmPc [+/- addend][extraction] into
    ; CasmConstantValueLo/Hi, marks Resolved, and clears the addend/
    ; extraction staging fields back to the zero state symbolsInsert's
    ; Ref* copy below expects for any already-resolved record (map.s's
    ; mapValidateRecord requires that whole span zero-filled once
    ; resolved -- same invariant ppsConstant's own numeric-RHS path
    ; already keeps at definition time).
    ldx CasmConstantIsCurAddr
    beq crpConstantFlags
    lda CasmPc
    sta CasmConstantValueLo
    lda CasmPc + 1
    sta CasmConstantValueHi
    lda CasmConstantRefAddendLo
    ora CasmConstantRefAddendHi
    beq crpConstantCurAddrExtract      ; zero addend: value is just CasmPc
    lda CasmConstantRefAddendSign
    cmp #CASM_ADDEND_SIGN_POSITIVE
    beq crpConstantCurAddrAdd
    lda CasmConstantValueLo
    sec
    sbc CasmConstantRefAddendLo
    sta CasmConstantValueLo
    lda CasmConstantValueHi
    sbc CasmConstantRefAddendHi
    sta CasmConstantValueHi
    bcs crpConstantCurAddrExtract
    jmp crpConstantCurAddrOverflow
crpConstantCurAddrAdd:
    lda CasmConstantValueLo
    clc
    adc CasmConstantRefAddendLo
    sta CasmConstantValueLo
    lda CasmConstantValueHi
    adc CasmConstantRefAddendHi
    sta CasmConstantValueHi
    bcc crpConstantCurAddrExtract
crpConstantCurAddrOverflow:
    lda #CASM_DIAG_EXPR_OVERFLOW
    sec
    jmp crpFail
crpConstantCurAddrExtract:
    lda CasmConstantRefExtract
    beq crpConstantCurAddrResolved      ; FULL: nothing to apply
    cmp #CASM_EXTRACTION_LO
    beq crpConstantCurAddrClearHigh
    lda CasmConstantValueHi             ; HI: move high byte down
    sta CasmConstantValueLo
crpConstantCurAddrClearHigh:
    lda #0
    sta CasmConstantValueHi
crpConstantCurAddrResolved:
    lda #1
    sta CasmConstantResolved
    lda #0
    sta CasmConstantRefAddendSign
    sta CasmConstantRefAddendLo
    sta CasmConstantRefAddendHi
    sta CasmConstantRefExtract

crpConstantFlags:
    lda #CASM_SYMBOL_FLAG_DEFINED | CASM_SYMBOL_FLAG_CONSTANT
    ldx CasmConstantResolved
    beq crpConstantCheckCurAddr
    ora #CASM_SYMBOL_FLAG_RESOLVED
crpConstantCheckCurAddr:
    ldx CasmConstantIsCurAddr
    beq crpConstantStoreFlags
    ora #CASM_SYMBOL_FLAG_LABEL_DERIVED
crpConstantStoreFlags:
    sta CasmSymbolInsertFlags

    lda CasmConstantRefVmmLo
    sta CasmSymbolInsertRefVmmLo
    lda CasmConstantRefVmmHi
    sta CasmSymbolInsertRefVmmHi
    lda CasmConstantRefLen
    sta CasmSymbolInsertRefLen
    lda CasmConstantRefAddendLo
    sta CasmSymbolInsertRefAddendLo
    lda CasmConstantRefAddendHi
    sta CasmSymbolInsertRefAddendHi
    lda CasmConstantRefAddendSign
    sta CasmSymbolInsertRefSign
    lda CasmConstantRefExtract
    sta CasmSymbolInsertRefExtract
    lda CasmLabelDefinedAtOffsetLo
    sta CasmSymbolInsertDefinedAtOffsetLo
    lda CasmLabelDefinedAtOffsetHi
    sta CasmSymbolInsertDefinedAtOffsetHi

    lda CasmLabelNameLen
    ldx CasmConstantValueLo
    ldy CasmConstantValueHi
    jsr symbolsInsert
    bcc :+
    jmp crpFail
    :
    crpConstantCommit:
    jsr crpListingCommit
    bcc :+
    jmp crpFail
    :
        jmp casmRunPass

crpInsn:
    jsr opcodesFindOpcode
    bcc :+
    jmp crpFail
    :
        jsr emitInstruction
    bcc :+
    jmp crpFail
    :
        jsr crpListingCommit
    bcc :+
    jmp crpFail
    :
        jmp casmRunPass

crpDir:
    lda CasmParserStmt + CASM_PARSER_STMT_SUBTYPE
    cmp #CASM_DIRECTIVE_INCLUDE
    bne crpEmitDir
    ; crpInclude commits the parent's own line itself, before pushing the
    ; child frame -- see its header comment.
    jsr crpInclude
    bcc :+
    jmp crpFail
    :
        jmp casmRunPass
crpEmitDir:
    jsr emitDirective
    bcc :+
    jmp crpFail
    :
        jsr crpListingCommit
    bcc :+
    jmp crpFail
    :
        jmp casmRunPass

crpDone:
    ; EOF: commit any pending final (unterminated) physical line. This adds
    ; no record of its own for EOF -- listingCommitLine only ever appends a
    ; record for a real physical line sourceTakeCompletedLine reports as
    ; pending, which is exactly the FINAL_UNTERMINATED case here; a source
    ; that ended cleanly on its last newline has nothing pending and this is
    ; a no-op.
    jsr crpListingCommit
    bcc :+
    jmp crpFail
    :
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
; casmResolveConstants (private, WP65)
; Pass1->Pass2 boundary: resolve every named constant Pass 1 left deferred
; (an identifier-RHS whose own reference wasn't yet in the symbol table at
; definition time -- a forward reference to another constant defined later,
; or to a label, whose address only becomes final once Pass 1 completes in
; full). Called once, after Pass 1's own CasmPc snapshot and before Pass 2's
; sourceRewind -- by this point every label and every constant's own name
; already exists in the table (Pass 1 always inserts a constant's name
; immediately, per crpConstant, even when its value is deferred), so a
; deferred reference's target is guaranteed either already resolvable or
; genuinely undefined; it can never still be "not yet reached".
;
; Walks every symbol record in definition order (symbolsReadByIndex); for
; each still-unresolved constant, hands off to crcResolveChain to walk and
; resolve its own reference chain, in full, before continuing the sweep.
;
; Inputs:    none (every label/constant already in the symbol table)
; Outputs:   C clear on success (every constant resolved)
;            C set, A = CASM_DIAG_EXPR_CIRCULAR, CASM_DIAG_UNDEFINED_SYMBOL,
;                CASM_DIAG_EXPR_OVERFLOW, or CASM_DIAG_VMM_TRANSFER_FAILED
;                on the first failure
; Clobbers:  A, X, Y, Crc* scratch, symbols.s/source.s volatile state
; ---------------------------------------------------------------------------
casmResolveConstants:
    lda #0
    sta CrcSweepIndexLo
    sta CrcSweepIndexHi

crcSweepLoop:
    ldx CrcSweepIndexLo
    ldy CrcSweepIndexHi
    jsr symbolsReadByIndex
    bcc crcSweepReadOk
    rts                              ; C set, A = CASM_DIAG_VMM_TRANSFER_FAILED
crcSweepReadOk:
    cmp #CASM_STREAM_EOF
    beq crcSweepDone
    lda CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    and #CASM_SYMBOL_FLAG_CONSTANT
    beq crcSweepNext
    lda CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    and #CASM_SYMBOL_FLAG_RESOLVED
    bne crcSweepNext                 ; already resolved (a numeric RHS)
    jsr crcResolveChain
    bcc crcSweepNext
    rts                              ; propagate C set, A = diagnostic
crcSweepNext:
    inc CrcSweepIndexLo
    bne crcSweepLoop
    inc CrcSweepIndexHi
    jmp crcSweepLoop
crcSweepDone:
    clc
    rts

; ---------------------------------------------------------------------------
; crcResolveChain (private, WP65)
; Resolve one unresolved constant's whole reference chain, starting at
; CrcSweepIndexLo/Hi. Two phases: walk forward (crcWalkLoop) following each
; node's own deferred reference, marking CrcBitmap and recording the path in
; CrcChainLo/Hi, until reaching a symbol that is already resolved (a label,
; or a constant an earlier sweep iteration already finished) -- that becomes
; the chain's base value. Then unwind CrcChainLo/Hi in reverse (crcUnwind),
; applying each visited node's own addend/extraction against the value
; inherited from its successor, writing each node's final VAL_LO/HI and
; CASM_SYMBOL_FLAG_RESOLVED back via symbolsUpdateByIndex as it goes -- so a
; later chain that happens to pass through an already-unwound node (shared
; by two different starting constants) finds it already resolved and stops
; immediately, doing no repeated work.
;
; Inputs:    CrcSweepIndexLo/Hi = the starting (outermost) unresolved
;                constant's record index
; Outputs:   C clear on success (every node in the chain resolved and
;                written back)
;            C set, A = CASM_DIAG_EXPR_CIRCULAR (a true cycle, or the chain
;                exceeded CASM_CONST_CHAIN_MAX), CASM_DIAG_UNDEFINED_SYMBOL
;                (the chain's final reference names no symbol at all),
;                CASM_DIAG_EXPR_OVERFLOW, or CASM_DIAG_VMM_TRANSFER_FAILED
; Clobbers:  A, X, Y, Crc* scratch
; ---------------------------------------------------------------------------
crcResolveChain:
    ldy #0
crcClearBitmapLoop:
    lda #0
    sta CrcBitmap, y
    iny
    cpy #64
    bne crcClearBitmapLoop

    lda #0
    sta CrcChainCount
    lda CrcSweepIndexLo
    sta CrcCurIndexLo
    lda CrcSweepIndexHi
    sta CrcCurIndexHi

crcWalkLoop:
    ; --- cycle check + mark CrcCurIndex visited ---
    lda CrcCurIndexLo
    and #7
    sta CrcBitIndex
    lda CrcCurIndexLo
    sta CrcScratchLo
    lda CrcCurIndexHi
    sta CrcScratchHi
    lsr CrcScratchHi
    ror CrcScratchLo
    lsr CrcScratchHi
    ror CrcScratchLo
    lsr CrcScratchHi
    ror CrcScratchLo
    lda CrcScratchLo
    sta CrcByteIndex

    ldx CrcBitIndex
    lda CrcBitMaskTable, x
    ldy CrcByteIndex
    and CrcBitmap, y
    beq crcNotVisited
    jmp crcCircular
crcNotVisited:
    ldx CrcBitIndex
    lda CrcBitMaskTable, x
    ldy CrcByteIndex
    ora CrcBitmap, y
    sta CrcBitmap, y

    ; --- depth check ---
    lda CrcChainCount
    cmp #CASM_CONST_CHAIN_MAX
    bcc crcDepthOk
    jmp crcCircular
crcDepthOk:

    ; --- record this index in the chain path ---
    ldx CrcChainCount
    lda CrcCurIndexLo
    sta CrcChainLo, x
    lda CrcCurIndexHi
    sta CrcChainHi, x
    inc CrcChainCount

    ; --- read this node's own record to recover its deferred reference ---
    ldx CrcCurIndexLo
    ldy CrcCurIndexHi
    jsr symbolsReadByIndex
    bcc crcWalkReadOk
    rts                               ; C set, A = CASM_DIAG_VMM_TRANSFER_FAILED
crcWalkReadOk:
    ; symbolsReadByIndex cannot report EOF here -- CrcCurIndex always names a
    ; real record, either the sweep's own already-validated starting index
    ; or a record symbolsLookup below just found.
    lda CasmVmmBuffer + CASM_SYMBOL_REC_REF_VMM_LO
    sta CrcRefVmmLo
    lda CasmVmmBuffer + CASM_SYMBOL_REC_REF_VMM_HI
    sta CrcRefVmmHi
    lda CasmVmmBuffer + CASM_SYMBOL_REC_REF_LEN
    sta CrcRefLen

    ; --- re-fetch the deferred reference's own name text from source ---
    lda CrcRefVmmLo
    sta CasmVmmOffLo
    lda CrcRefVmmHi
    sta CasmVmmOffHi
    lda CrcRefLen
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmSourceVmmSlot
    jsr vmmWindowRead
    bcc crcNameReadOk
    rts                               ; C set, A = CASM_DIAG_VMM_TRANSFER_FAILED
crcNameReadOk:
    ldy #0
crcCopyNameLoop:
    cpy CrcRefLen
    beq crcCopyNameDone
    lda CasmVmmBuffer, y
    sta CrcNameBuf, y
    iny
    jmp crcCopyNameLoop
crcCopyNameDone:

    ; --- look up the reference target ---
    lda #<CrcNameBuf
    sta CasmPtr0Lo
    lda #>CrcNameBuf
    sta CasmPtr0Hi
    lda CrcRefLen
    ldx #<CrcResolveView
    ldy #>CrcResolveView
    jsr symbolsLookup
    bcc crcLookupOk
    rts                               ; C set, A = CASM_DIAG_VMM_TRANSFER_FAILED
crcLookupOk:
    lda CrcResolveView + CASM_RESOLVE_FLAGS
    and #CASM_EXPR_FLAG_RESOLVED
    bne crcFound
    jmp crcUndefined
crcFound:
    ; --- is the target itself already resolved (base), or another
    ; unresolved constant to keep walking? ---
    lda CrcResolveView + CASM_RESOLVE_SYM_FLAGS
    and #CASM_SYMBOL_FLAG_CONSTANT
    beq crcBase                      ; a label: always resolved, always base
    lda CrcResolveView + CASM_RESOLVE_SYM_FLAGS
    and #CASM_SYMBOL_FLAG_RESOLVED
    beq crcContinue                  ; another unresolved constant: keep walking
crcBase:
    lda CrcResolveView + CASM_RESOLVE_VAL_LO
    sta CrcValueLo
    lda CrcResolveView + CASM_RESOLVE_VAL_HI
    sta CrcValueHi
    ; WP65 Increment 8: CASM_SYMBOL_FLAG_LABEL_DERIVED propagates to every
    ; node in this chain, not just the one adjacent to the base -- a label
    ; is always derived; an already-resolved constant base propagates its
    ; own LABEL_DERIVED bit (itself already correctly propagated when that
    ; constant's own chain was unwound, possibly by an earlier sweep
    ; iteration).
    lda CrcResolveView + CASM_RESOLVE_SYM_FLAGS
    and #CASM_SYMBOL_FLAG_CONSTANT
    beq crcBaseLabelDerived      ; not a constant -> a label -> always derived
    lda CrcResolveView + CASM_RESOLVE_SYM_FLAGS
    and #CASM_SYMBOL_FLAG_LABEL_DERIVED
    beq crcBaseNotDerived
crcBaseLabelDerived:
    lda #1
    sta CrcLabelDerived
    jmp crcUnwind
crcBaseNotDerived:
    lda #0
    sta CrcLabelDerived
    jmp crcUnwind

crcContinue:
    lda CrcResolveView + CASM_RESOLVE_ID_LO
    sta CrcCurIndexLo
    lda CrcResolveView + CASM_RESOLVE_ID_HI
    sta CrcCurIndexHi
    jmp crcWalkLoop

crcCircular:
    jsr diagClearLoc
    lda #CASM_DIAG_EXPR_CIRCULAR
    sec
    rts

crcUndefined:
    jsr diagClearLoc
    lda #CASM_DIAG_UNDEFINED_SYMBOL
    sec
    rts

crcOverflow:
    jsr diagClearLoc
    lda #CASM_DIAG_EXPR_OVERFLOW
    sec
    rts

; ---------------------------------------------------------------------------
; crcUnwind (private, WP65)
; Apply CrcChainLo/Hi's path in reverse, from the node closest to the
; resolved base back out to the original start, computing and persisting
; each node's own final value. CrcValueLo/Hi enters holding the resolved
; base value (crcBase, above).
; ---------------------------------------------------------------------------
crcUnwind:
    lda CrcChainCount
    bne crcUnwindLoop                 ; the normal case (a chain always
                                       ; records at least its own start)
    jmp crcUnwindDone                 ; unreachable in practice, kept for
                                       ; safety
crcUnwindLoop:
    dec CrcChainCount
    ldx CrcChainCount

    lda CrcChainLo, x
    sta CrcCurIndexLo
    lda CrcChainHi, x
    sta CrcCurIndexHi
    ldx CrcCurIndexLo
    ldy CrcCurIndexHi
    jsr symbolsReadByIndex
    bcc crcUnwindReadOk
    rts                                ; C set, A = CASM_DIAG_VMM_TRANSFER_FAILED
crcUnwindReadOk:

    ; Apply the addend (checked 16-bit add/sub, mirroring expr.s's own
    ; exprCheckedAdd/Sub -- duplicated here rather than reused, since those
    ; read their operand from expr.s's own private, non-exported result
    ; record, not from an externally-supplied sign/magnitude).
    lda CasmVmmBuffer + CASM_SYMBOL_REC_REF_ADDEND_LO
    ora CasmVmmBuffer + CASM_SYMBOL_REC_REF_ADDEND_HI
    beq crcUnwindExtract               ; zero addend: no-op
    lda CasmVmmBuffer + CASM_SYMBOL_REC_REF_SIGN
    cmp #CASM_ADDEND_SIGN_POSITIVE
    beq crcUnwindAdd
    lda CrcValueLo
    sec
    sbc CasmVmmBuffer + CASM_SYMBOL_REC_REF_ADDEND_LO
    sta CrcValueLo
    lda CrcValueHi
    sbc CasmVmmBuffer + CASM_SYMBOL_REC_REF_ADDEND_HI
    sta CrcValueHi
    bcs crcUnwindExtract
    jmp crcOverflow
crcUnwindAdd:
    lda CrcValueLo
    clc
    adc CasmVmmBuffer + CASM_SYMBOL_REC_REF_ADDEND_LO
    sta CrcValueLo
    lda CrcValueHi
    adc CasmVmmBuffer + CASM_SYMBOL_REC_REF_ADDEND_HI
    sta CrcValueHi
    bcc crcUnwindExtract
    jmp crcOverflow

crcUnwindExtract:
    lda CasmVmmBuffer + CASM_SYMBOL_REC_REF_EXTRACT
    beq crcUnwindPatch                 ; FULL: nothing to apply
    cmp #CASM_EXTRACTION_LO
    beq crcUnwindClearHigh
    lda CrcValueHi
    sta CrcValueLo
crcUnwindClearHigh:
    lda #0
    sta CrcValueHi

crcUnwindPatch:
    ; CasmVmmBuffer still holds this node's own freshly-read record (the
    ; addend/extraction application above touched only CrcValueLo/Hi, not
    ; the buffer) -- patch VAL_LO/HI and set RESOLVED in place, then write
    ; the whole record back. The Ref* fields (reserved padding once
    ; resolved) are zeroed too -- mapValidateRecord (map.s) requires that
    ; whole span zero-filled, and this deferred reference's own bytes are
    ; no longer meaningful once RESOLVED is set (ppsConstant's own
    ; numeric-RHS path keeps this same invariant at definition time; this
    ; is the deferred-RHS path's equivalent, established here instead of
    ; at definition time since the value wasn't known until now).
    lda CrcValueLo
    sta CasmVmmBuffer + CASM_SYMBOL_REC_VAL_LO
    lda CrcValueHi
    sta CasmVmmBuffer + CASM_SYMBOL_REC_VAL_HI
    lda CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    ora #CASM_SYMBOL_FLAG_RESOLVED
    ldx CrcLabelDerived
    beq crcUnwindFlagsSet
    ora #CASM_SYMBOL_FLAG_LABEL_DERIVED
crcUnwindFlagsSet:
    sta CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    lda #0
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_VMM_LO
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_VMM_HI
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_LEN
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_ADDEND_LO
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_ADDEND_HI
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_SIGN
    sta CasmVmmBuffer + CASM_SYMBOL_REC_REF_EXTRACT
    ldx CrcCurIndexLo
    ldy CrcCurIndexHi
    jsr symbolsUpdateByIndex
    bcc crcUnwindNext
    rts                                 ; C set, A = CASM_DIAG_VMM_TRANSFER_FAILED
crcUnwindNext:
    lda CrcChainCount
    beq crcUnwindDone
    jmp crcUnwindLoop
crcUnwindDone:
    clc
    rts

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
    ; Progress Increment 5: seed the load line's name from the operand we
    ; just parsed, before the child is opened -- the packed-identity
    ; resolver cannot help here, since the catalog index it needs is only
    ; assigned by includeCatalogLoad below. The id field still shows the
    ; parent's until that index exists; the name, which is what actually
    ; identifies the file on screen, is correct from the first block.
    ldx #<CasmIncludeFilename
    ldy #>CasmIncludeFilename
    jsr crpSnapshotNameFromPtr
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

; Progress Increment 5: the physical file identity the transient line was
; last drawn for. Compared against CasmSourceFileId on every counted
; statement so any include push, pop, cascading pop, or root transition
; forces an immediate redraw with a freshly resolved name. Seeded to $FF
; (never a valid packed id -- the id mask is $7F) at each pass start so the
; first statement of both passes always snapshots a name.
CasmProgLastFileId:  .res 1
CasmProgLastDepth:   .res 1   ; frame depth the transient line last showed

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

; WP65: casmResolveConstants/crcResolveChain's own private scratch (the
; Pass1->Pass2 named-constant resolution sweep). CrcBitmap is a 512-bit
; (64-byte) "visited during this chain's own walk" marker, one bit per
; symbol record index, cleared fresh at the start of each top-level
; unresolved constant crcResolveChain is called for -- catches a genuine
; cycle (a=b, b=a) the instant the walk revisits an index already marked.
; CrcChainLo/Hi/Count record the walk's own path (bounded by
; CASM_CONST_CHAIN_MAX) so the addend/extraction each visited node's own
; definition carries can be unwound in reverse, from the resolved base
; back out to the original start, once the walk succeeds.
CrcSweepIndexLo:   .res 1
CrcSweepIndexHi:   .res 1
CrcCurIndexLo:     .res 1
CrcCurIndexHi:     .res 1
CrcByteIndex:      .res 1
CrcBitIndex:       .res 1
CrcScratchLo:       .res 1
CrcScratchHi:       .res 1
CrcRefVmmLo:       .res 1
CrcRefVmmHi:       .res 1
CrcRefLen:         .res 1
CrcChainCount:     .res 1
CrcChainLo:        .res CASM_CONST_CHAIN_MAX
CrcChainHi:        .res CASM_CONST_CHAIN_MAX
CrcNameBuf:        .res CASM_TOKEN_TEXT_MAX
CrcResolveView:    .res CASM_RESOLVE_SIZE
CrcValueLo:        .res 1
CrcValueHi:        .res 1
CrcLabelDerived:   .res 1
CrcBitmap:         .res 64

; Phase 14 WP86: the record index of the most recently committed global
; label -- the scope every subsequent `@local` definition/reference
; belongs to until the next global label. CASM_SYMBOL_CHAIN_END ($FFFF)
; means "no scope open yet" (no global label seen so far in this pass).
; Reset to that sentinel at the start of every pass (Pass 1 and Pass 2
; independently, so a mid-file scope reopens identically in both). crpLabel
; (WP89) sets it on every successful global-label commit; it is not yet
; read or written anywhere -- that wiring is WP89. Copied into
; CasmSymbolInsertScopeLo/Hi (symbols.s) before a local's symbolsInsert
; call, and into CasmSymbolLookupScopeLo/Hi before each statement's
; expression evaluation.
CasmCurrentScopeLo: .res 1
CasmCurrentScopeHi: .res 1

.segment "RODATA"

CrcBitMaskTable: .byte 1, 2, 4, 8, 16, 32, 64, 128

versionBanner:
    .byte "CASM V", VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE, "."
    .byte BUILD_NUMBER
    .byte PetCr, 0

; Progress Increment 7.
msgWritePrefix:
    .byte "WRITE: ", 0
msgProgressCrOnly:
    .byte PetCr, 0
