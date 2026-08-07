; tests/src/casm_listwrite/casm_listwrite.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 10 WP53 increment 4 fixture harness for listing.s's
; `.LST` file I/O: listingCreate/Write/Close/Delete/Abort. Drives every real
; routine against real DOS_OPEN_FILE/DOS_WRITE_FILE/DOS_READ_FILE/
; DOS_DELETE_FILE calls, so persistence, replacement, and deletion are all
; proven on the real disk through a readback, not asserted from in-memory
; state alone -- following casm_spancommit.s's own increment-3 precedent
; exactly.
;
; The core new mechanism this increment introduces -- CBM DOS's native
; "@0:" replace-on-open marker (WP50's frozen file-ownership resolution) --
; is proven directly: createReplacesExisting writes a real file, closes it,
; then creates the identical name again, which must transparently replace
; it rather than erroring "FILE EXISTS", with the readback showing only the
; new content.
;
; The staged first file is created through listingCreate itself rather than
; the PRG-output path, so both files are the same CBM type (SEQ). An earlier
; version staged a PRG and the drive rejected the mismatched replace, then
; left its error channel latched -- which failed every later case that
; touched the same device, not just this one.
;
; Does not link cli.s: CasmListingName/Len are set directly per case,
; standing in for an already-completed cliDeriveListingName call, matching
; casm_spancommit.s's own CasmOutputName precedent.
;
; TWO DIFFERENT CASE RULES APPLY, per casm_cliderive.s's own header note:
;   * Disk filename literals are UPPERCASE ("SPLW01.LST") -- ca65's C64
;     charmap turns them into shifted PETSCII, which DOS_OPEN_FILE accepts
;     (casm_spancommit.s's own precedent).
;   * Expected *content* literals -- read back and compared byte-for-byte
;     here, unlike casm_spancommit.s -- are lowercase ("hello"), so the
;     charmap produces unshifted PETSCII identical to what listingWrite
;     itself sends untouched to DOS_WRITE_FILE.
.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_listwrite.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import fileIoInit
.import fileOpenInput
.import fileRead
.import fileClose
.import listingFileInit
.import listingCreate
.import listingWrite
.import listingClose
.import listingAbort
.import listingReplayReset
.import listingValidateRecord
.import CasmListFileCommitted
.import CasmIoBuffer
.import CasmListingState
.import CasmVmmBuffer
.import CasmListResolvedName
.import CasmListResolvedNameLen

.export CasmOutputName   ; fileio.s's outputAbort references this by name
.export CasmListingName
.export CasmListingLen
; listing.s is linked whole, so its WP51 capture code (unrelated to this
; increment's `.LST` file-I/O routines and never called by any case here)
; still needs these to resolve. Stubbed locally rather than linking
; source.s/diagnostics.s/state.s/include.s to satisfy them -- casm_spancommit.s's
; own precedent for the same situation (see its own CMakeLists.txt entry).
.export diagPrintFatal
.export sourceSetLineCapture
.export sourceTakeCompletedLine
.export CasmPc
.export CasmSourceCompletedFlags
.export CasmSourceCompletedStartLo
.export CasmSourceCompletedStartHi
.export CasmSourceCompletedLength
.export CasmSourceCompletedFileId
.export CasmSourceCompletedLineLo
.export CasmSourceCompletedLineHi
.export CasmSourceCount
.export cliSourceSlotLo
.export cliSourceSlotHi
.export CasmIncludeCatalogCount
.export CasmIncludeRecordStage
.export includeCatalogRead
.export includeDeviceStrLo
.export includeDeviceStrHi

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    lda CurrentDevice
    sta TestDevice
    jsr resourcesInit
    lda #0
    sta FailCount

    ; WP53 increment 5: fixed sizes for cliSourceSlotLo/Hi's real 2-entry
    ; table and the fake catalog's own 2 entries (both RODATA, initialized
    ; at assembly time). $FF disables FakeCatalogFailIndex ("never match")
    ; until a specific case opts in.
    lda #2
    sta CasmSourceCount
    sta CasmIncludeCatalogCount
    lda #$FF
    sta FakeCatalogFailIndex

    jsr createWriteCloseRoundtrip
    jsr reportCase
    jsr resourcesCleanup

    jsr createWithDevicePrefix
    jsr reportCase
    jsr resourcesCleanup

    jsr createReplacesExisting
    jsr reportCase
    jsr resourcesCleanup

    jsr abortAfterCommitProtects
    jsr reportCase
    jsr resourcesCleanup

    jsr abortWhileOpenDeletes
    jsr reportCase
    jsr resourcesCleanup

    jsr validateAcceptsTopLevelThenSecondRecordMonotonic
    jsr reportCase

    jsr validateAcceptsIncludedHeaderThenSecondRecordMonotonic
    jsr reportCase

    jsr validateRejectsUnknownFlagBit
    jsr reportCase

    jsr validateRejectsNonzeroReserved0
    jsr reportCase

    jsr validateRejectsNonzeroReserved1Byte0
    jsr reportCase

    jsr validateRejectsNonzeroReserved1Byte1
    jsr reportCase

    jsr validateRejectsSourceSpanOverflow
    jsr reportCase

    jsr validateRejectsByteCountOverflow
    jsr reportCase

    jsr validateRejectsNonMonotonicByteOff
    jsr reportCase

    jsr validateRejectsTopLevelFileIdOutOfRange
    jsr reportCase

    jsr validateRejectsFrameFileIdOutOfRange
    jsr reportCase

    jsr validatePropagatesVmmTransferFailure
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
; copyNullTerminated
; Copy the null-terminated literal at X/Y into the buffer at CasmPtr0Lo/Hi.
; Outputs: Y = length copied (excluding the null)
; ---------------------------------------------------------------------------
copyNullTerminated:
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldy #0
cntLoop:
    lda (CasmPtr1Lo), y
    sta (CasmPtr0Lo), y
    beq cntDone
    iny
    bne cntLoop
cntDone:
    rts

; ---------------------------------------------------------------------------
; setListingName
; Copy the null-terminated literal at X/Y into CasmListingName and set
; CasmListingLen, standing in for an already-completed cliDeriveListingName
; call.
; ---------------------------------------------------------------------------
setListingName:
    lda #<CasmListingName
    sta CasmPtr0Lo
    lda #>CasmListingName
    sta CasmPtr0Hi
    jsr copyNullTerminated
    sty CasmListingLen
    rts

; ---------------------------------------------------------------------------
; writeListingLiteral
; Write the null-terminated literal at X/Y through listingWrite (one
; bounded block).
; Outputs: C/A as listingWrite
; ---------------------------------------------------------------------------
writeListingLiteral:
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldy #0
wllLenLoop:
    lda (CasmPtr1Lo), y
    beq wllLenDone
    iny
    bne wllLenLoop
wllLenDone:
    sty CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmPtr1Lo
    ldy CasmPtr1Hi
    jmp listingWrite

; ---------------------------------------------------------------------------
; readBackAndCompare
; Open CasmListingName for input, read up to 32 bytes, and compare against
; the null-terminated literal at X/Y (exact length and content).
; Outputs: C clear if the file opened and its content matches exactly;
;          C set otherwise
; ---------------------------------------------------------------------------
readBackAndCompare:
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldx #<CasmListingName
    ldy #>CasmListingName
    jsr fileOpenInput
    bcs rbacFail
    lda #32
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx #<CasmIoBuffer
    ldy #>CasmIoBuffer
    jsr fileRead
    bcs rbacFail
    ldy #0
rbacLoop:
    lda (CasmPtr1Lo), y
    beq rbacExpectEnd
    cmp CasmIoBuffer, y
    bne rbacFail
    iny
    jmp rbacLoop
rbacExpectEnd:
    ; Expected literal ended; the actual read length (CasmIoLenLo -- always
    ; under 256 for these short fixtures, so CasmIoLenHi is always 0) must
    ; match exactly, or the real file has trailing/extra bytes.
    cpy CasmIoLenLo
    bne rbacFail
    clc
    rts
rbacFail:
    sec
    rts

; ---------------------------------------------------------------------------
; createWriteCloseRoundtrip
; No device prefix. Create, write a short pattern, close, then read the real
; file back and confirm it matches exactly.
; ---------------------------------------------------------------------------
createWriteCloseRoundtrip:
    jsr fileIoInit
    jsr listingFileInit
    ldx #<nameNoPrefix
    ldy #>nameNoPrefix
    jsr setListingName
    jsr listingCreate
    bcs cwcFail
    ldx #<contentHello
    ldy #>contentHello
    jsr writeListingLiteral
    bcs cwcFail
    jsr listingClose
    bcs cwcFail
    ldx #<contentHello
    ldy #>contentHello
    jmp readBackAndCompare
cwcFail:
    sec
    rts

; ---------------------------------------------------------------------------
; createWithDevicePrefix
; The complementary listingBuildOpenName branch: a device-prefixed name
; ("9:..."), proving the "@0:" marker lands correctly after the colon too.
; ---------------------------------------------------------------------------
createWithDevicePrefix:
    jsr fileIoInit
    jsr listingFileInit
    ldx #<namePrefixed
    ldy #>namePrefixed
    jsr setListingName
    jsr listingCreate
    bcs cwdFail
    ldx #<contentHello
    ldy #>contentHello
    jsr writeListingLiteral
    bcs cwdFail
    jsr listingClose
    bcs cwdFail
    ; Read back via the same (still device-prefixed) CasmListingName -- the
    ; OS's own parsePointerDevice strips the prefix on this open exactly as
    ; it did on listingCreate's, resolving to the identical real file.
    ldx #<contentHello
    ldy #>contentHello
    jmp readBackAndCompare
cwdFail:
    sec
    rts

; ---------------------------------------------------------------------------
; createReplacesExisting
; The core WP53 mechanism: a real stale file already exists under the exact
; target name (created through the ordinary PRG-output path, unrelated to
; listing.s). listingCreate's embedded "@0:" marker must transparently
; replace it -- never "FILE EXISTS" -- and the readback must show only the
; new content, proving genuine replacement rather than append or silent
; no-op.
; ---------------------------------------------------------------------------
createReplacesExisting:
    jsr fileIoInit
    jsr listingFileInit
    ldx #<nameReplace
    ldy #>nameReplace
    jsr setListingName

    ; Stage the stale file through listingCreate itself, not the PRG-output
    ; path. The staged file must be the same CBM file type (SEQ) as the one
    ; that will replace it: an earlier version staged it as a PRG through
    ; fileCreateOutput, and the drive rejected the mismatched replace, which
    ; then left the error channel latched and cascaded into every later
    ; case on the same device.
    jsr listingCreate
    bcs creFail
    ldx #<contentOld
    ldy #>contentOld
    jsr writeListingLiteral
    bcs creFail
    jsr listingClose
    bcs creFail

    ; listingClose leaves the state CLOSED, so a second listingCreate is a
    ; legal call -- and it must transparently replace the file just written.
    jsr listingCreate
    bcs creFail
    ldx #<contentNew
    ldy #>contentNew
    jsr writeListingLiteral
    bcs creFail
    jsr listingClose
    bcs creFail
    ldx #<contentNew
    ldy #>contentNew
    jmp readBackAndCompare
creFail:
    sec
    rts

; ---------------------------------------------------------------------------
; abortAfterCommitProtects
; Mirrors casm_spancommit.s's own increment-3 case: a committed listing
; (CasmListFileCommitted poked directly -- WP53 increment 4 has no setter
; yet, that is increment 6's serializer's job) must never be deleted by
; listingAbort, which must still return the caller's own primary
; diagnostic. Abort is called after an ordinary successful close, so this
; exercises listingAbort's already-CLOSED (delete-only) branch.
; ---------------------------------------------------------------------------
abortAfterCommitProtects:
    jsr fileIoInit
    jsr listingFileInit
    ldx #<nameCommit
    ldy #>nameCommit
    jsr setListingName
    jsr listingCreate
    bcs aacFail
    ldx #<contentHello
    ldy #>contentHello
    jsr writeListingLiteral
    bcs aacFail
    jsr listingClose
    bcs aacFail
    lda #CASM_LISTFILE_COMMITTED
    sta CasmListFileCommitted
    lda #CASM_DIAG_SYNTAX_ERROR    ; arbitrary nonzero stand-in primary
    jsr listingAbort
    bcc aacFail                    ; must still report failure (nonzero A)
    cmp #CASM_DIAG_SYNTAX_ERROR
    bne aacFail
    ldx #<contentHello
    ldy #>contentHello
    jmp readBackAndCompare         ; must still be there, unchanged
aacFail:
    sec
    rts

; ---------------------------------------------------------------------------
; abortWhileOpenDeletes
; Regression, and listingAbort's other branch: called while the listing is
; still OPEN (never closed), uncommitted. Must close it, delete it, and
; return the caller's primary; a post-delete probe must fail.
; ---------------------------------------------------------------------------
abortWhileOpenDeletes:
    jsr fileIoInit
    jsr listingFileInit
    ldx #<nameAbortOpen
    ldy #>nameAbortOpen
    jsr setListingName
    jsr listingCreate
    bcs awoFail
    lda #CASM_DIAG_NONE
    jsr listingAbort
    bcs awoFail                    ; primary was NONE -- must report success
    ldx #<contentHello
    ldy #>contentHello
    jsr readBackAndCompare
    bcc awoFail                    ; must be ABSENT now -- success is the bug
    clc
    rts
awoFail:
    sec
    rts

; =============================================================================
; WP53 increment 5: listingValidateRecord / listingResolveFilename
;
; This harness never runs the real WP51 capture pipeline, so CasmVmmBuffer
; (real -- vmm_store.s is linked for increment 4's own real-disk proof) is
; poked directly with hand-built metadata records, standing in for a real
; listingReplayNext call. cliSourceSlotLo/Hi and the fake catalog below
; stand in for cli.s/include.s's own real tables -- listingResolveFilename
; only depends on their contract (id in, name out), not on how a real
; source.s/include.s populates them.
; =============================================================================

; ---------------------------------------------------------------------------
; resetValidation
; Set CasmListingState to COMPLETE (standing in for an already-finished
; capture) and tail-call the real listingReplayReset, which is what
; actually zeroes listingValidateRecord's own running expected-byte-offset.
; ---------------------------------------------------------------------------
resetValidation:
    lda #CASM_LISTING_STATE_COMPLETE
    sta CasmListingState
    jmp listingReplayReset

; ---------------------------------------------------------------------------
; buildBaseRecord
; Poke a single canonical, well-formed metadata record into CasmVmmBuffer.
; FILEID = $00 (top-level id 0, resolves to nameMain); BYTEOFF = 0, matching
; a fresh resetValidation. Individual cases overwrite one field afterward.
; ---------------------------------------------------------------------------
buildBaseRecord:
    lda #0
    sta CasmVmmBuffer + CASM_LISTING_META_FILEID
    sta CasmVmmBuffer + CASM_LISTING_META_FLAGS
    sta CasmVmmBuffer + CASM_LISTING_META_LINE_LO
    sta CasmVmmBuffer + CASM_LISTING_META_LINE_HI
    sta CasmVmmBuffer + CASM_LISTING_META_OFF_HI
    sta CasmVmmBuffer + CASM_LISTING_META_RESERVED0
    sta CasmVmmBuffer + CASM_LISTING_META_PC_LO
    sta CasmVmmBuffer + CASM_LISTING_META_BYTEOFF_LO
    sta CasmVmmBuffer + CASM_LISTING_META_BYTEOFF_HI
    sta CasmVmmBuffer + CASM_LISTING_META_BYTECOUNT_HI
    sta CasmVmmBuffer + CASM_LISTING_META_RESERVED1
    sta CasmVmmBuffer + CASM_LISTING_META_RESERVED1 + 1
    lda #$10
    sta CasmVmmBuffer + CASM_LISTING_META_OFF_LO
    lda #5
    sta CasmVmmBuffer + CASM_LISTING_META_LEN
    lda #$34
    sta CasmVmmBuffer + CASM_LISTING_META_PC_HI
    lda #3
    sta CasmVmmBuffer + CASM_LISTING_META_BYTECOUNT_LO
    rts

; ---------------------------------------------------------------------------
; compareResolvedName
; Compare CasmListResolvedName/Len against the null-terminated literal at
; X/Y. Outputs: C clear + exact match; C set otherwise.
; ---------------------------------------------------------------------------
compareResolvedName:
    stx CasmPtr1Lo
    sty CasmPtr1Hi
    ldy #0
crnLoop:
    lda (CasmPtr1Lo), y
    beq crnExpectEnd
    cmp CasmListResolvedName, y
    bne crnFail
    iny
    jmp crnLoop
crnExpectEnd:
    cpy CasmListResolvedNameLen
    bne crnFail
    clc
    rts
crnFail:
    sec
    rts

; ---------------------------------------------------------------------------
; expectMismatchTail
; Tail target after jsr listingValidateRecord: C clear + A = CASM_DIAG_NONE
; (test failed -- should not have been accepted) or C set + wrong A. Outputs
; C clear only when listingValidateRecord returned C set/A =
; CASM_DIAG_LISTING_REPLAY_MISMATCH exactly, matching reportCase's
; carry-means-fail convention for this case's own pass/fail (not
; listingValidateRecord's).
; ---------------------------------------------------------------------------
expectMismatchTail:
    bcc emtFail
    cmp #CASM_DIAG_LISTING_REPLAY_MISMATCH
    bne emtFail
    clc
    rts
emtFail:
    sec
    rts

; ---------------------------------------------------------------------------
; validateAcceptsTopLevelThenSecondRecordMonotonic
; Two consecutive valid top-level records after one resetValidation: proves
; the running byte-offset genuinely accumulates across calls (not just a
; single-record check), and that both top-level FILEIDs resolve to their
; exact CLI-spelled names via cliSourceSlotLo/Hi.
; ---------------------------------------------------------------------------
validateAcceptsTopLevelThenSecondRecordMonotonic:
    jsr resetValidation
    bcs vatlFail
    jsr buildBaseRecord
    jsr listingValidateRecord
    bcs vatlFail
    ldx #<nameMain
    ldy #>nameMain
    jsr compareResolvedName
    bcs vatlFail

    jsr buildBaseRecord
    lda #1
    sta CasmVmmBuffer + CASM_LISTING_META_FILEID
    lda #3                         ; must equal first record's own BYTECOUNT
    sta CasmVmmBuffer + CASM_LISTING_META_BYTEOFF_LO
    lda #5
    sta CasmVmmBuffer + CASM_LISTING_META_BYTECOUNT_LO
    jsr listingValidateRecord
    bcs vatlFail
    ldx #<nameUtil
    ldy #>nameUtil
    jmp compareResolvedName
vatlFail:
    sec
    rts

; ---------------------------------------------------------------------------
; validateAcceptsIncludedHeaderThenSecondRecordMonotonic
; Same monotonic proof, for the frame (included-header) branch: device +
; colon + prefix-stripped catalog name, via the fake includeCatalogRead
; below.
; ---------------------------------------------------------------------------
validateAcceptsIncludedHeaderThenSecondRecordMonotonic:
    jsr resetValidation
    bcs vaihFail
    jsr buildBaseRecord
    lda #$80
    sta CasmVmmBuffer + CASM_LISTING_META_FILEID
    lda #4
    sta CasmVmmBuffer + CASM_LISTING_META_BYTECOUNT_LO
    jsr listingValidateRecord
    bcs vaihFail
    ldx #<nameSub
    ldy #>nameSub
    jsr compareResolvedName
    bcs vaihFail

    jsr buildBaseRecord
    lda #$81
    sta CasmVmmBuffer + CASM_LISTING_META_FILEID
    lda #4                         ; continuation of first record's BYTECOUNT
    sta CasmVmmBuffer + CASM_LISTING_META_BYTEOFF_LO
    lda #2
    sta CasmVmmBuffer + CASM_LISTING_META_BYTECOUNT_LO
    jsr listingValidateRecord
    bcs vaihFail
    ldx #<nameDeep
    ldy #>nameDeep
    jmp compareResolvedName
vaihFail:
    sec
    rts

; ---------------------------------------------------------------------------
; validateRejectsUnknownFlagBit
; FLAGS with any bit set outside CASM_LISTING_META_FLAG_FINAL_UNTERMINATED
; (bit 0) must be rejected.
; ---------------------------------------------------------------------------
validateRejectsUnknownFlagBit:
    jsr resetValidation
    bcs vrufFail
    jsr buildBaseRecord
    lda #%00000010
    sta CasmVmmBuffer + CASM_LISTING_META_FLAGS
    jsr listingValidateRecord
    jmp expectMismatchTail
vrufFail:
    sec
    rts

; ---------------------------------------------------------------------------
; validateRejectsNonzeroReserved0
; ---------------------------------------------------------------------------
validateRejectsNonzeroReserved0:
    jsr resetValidation
    bcs vrr0Fail
    jsr buildBaseRecord
    lda #1
    sta CasmVmmBuffer + CASM_LISTING_META_RESERVED0
    jsr listingValidateRecord
    jmp expectMismatchTail
vrr0Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; validateRejectsNonzeroReserved1Byte0
; ---------------------------------------------------------------------------
validateRejectsNonzeroReserved1Byte0:
    jsr resetValidation
    bcs vrr1aFail
    jsr buildBaseRecord
    lda #1
    sta CasmVmmBuffer + CASM_LISTING_META_RESERVED1
    jsr listingValidateRecord
    jmp expectMismatchTail
vrr1aFail:
    sec
    rts

; ---------------------------------------------------------------------------
; validateRejectsNonzeroReserved1Byte1
; ---------------------------------------------------------------------------
validateRejectsNonzeroReserved1Byte1:
    jsr resetValidation
    bcs vrr1bFail
    jsr buildBaseRecord
    lda #1
    sta CasmVmmBuffer + CASM_LISTING_META_RESERVED1 + 1
    jsr listingValidateRecord
    jmp expectMismatchTail
vrr1bFail:
    sec
    rts

; ---------------------------------------------------------------------------
; validateRejectsSourceSpanOverflow
; OFF + LEN must not overflow 16 bits.
; ---------------------------------------------------------------------------
validateRejectsSourceSpanOverflow:
    jsr resetValidation
    bcs vrssFail
    jsr buildBaseRecord
    lda #$FF
    sta CasmVmmBuffer + CASM_LISTING_META_OFF_LO
    sta CasmVmmBuffer + CASM_LISTING_META_OFF_HI
    lda #2
    sta CasmVmmBuffer + CASM_LISTING_META_LEN
    jsr listingValidateRecord
    jmp expectMismatchTail
vrssFail:
    sec
    rts

; ---------------------------------------------------------------------------
; validateRejectsByteCountOverflow
; PC + BYTECOUNT must not overflow 16 bits.
; ---------------------------------------------------------------------------
validateRejectsByteCountOverflow:
    jsr resetValidation
    bcs vrbcFail
    jsr buildBaseRecord
    lda #$FF
    sta CasmVmmBuffer + CASM_LISTING_META_PC_LO
    sta CasmVmmBuffer + CASM_LISTING_META_PC_HI
    lda #2
    sta CasmVmmBuffer + CASM_LISTING_META_BYTECOUNT_LO
    lda #0
    sta CasmVmmBuffer + CASM_LISTING_META_BYTECOUNT_HI
    jsr listingValidateRecord
    jmp expectMismatchTail
vrbcFail:
    sec
    rts

; ---------------------------------------------------------------------------
; validateRejectsNonMonotonicByteOff
; A fresh reset expects BYTEOFF = 0; anything else must be rejected.
; ---------------------------------------------------------------------------
validateRejectsNonMonotonicByteOff:
    jsr resetValidation
    bcs vrnmFail
    jsr buildBaseRecord
    lda #5
    sta CasmVmmBuffer + CASM_LISTING_META_BYTEOFF_LO
    jsr listingValidateRecord
    jmp expectMismatchTail
vrnmFail:
    sec
    rts

; ---------------------------------------------------------------------------
; validateRejectsTopLevelFileIdOutOfRange
; FILEID's id (no frame bit) >= CasmSourceCount must be rejected without
; ever dereferencing cliSourceSlotLo/Hi out of bounds.
; ---------------------------------------------------------------------------
validateRejectsTopLevelFileIdOutOfRange:
    jsr resetValidation
    bcs vrtlFail
    jsr buildBaseRecord
    lda #2                          ; CasmSourceCount is 2 -- 0/1 valid, 2 not
    sta CasmVmmBuffer + CASM_LISTING_META_FILEID
    jsr listingValidateRecord
    jmp expectMismatchTail
vrtlFail:
    sec
    rts

; ---------------------------------------------------------------------------
; validateRejectsFrameFileIdOutOfRange
; FILEID's id (frame bit set) >= CasmIncludeCatalogCount must be rejected at
; listingResolveFilename's own gate, never reaching includeCatalogRead.
; ---------------------------------------------------------------------------
validateRejectsFrameFileIdOutOfRange:
    jsr resetValidation
    bcs vrflFail
    jsr buildBaseRecord
    lda #$82                        ; CasmIncludeCatalogCount is 2 -- 0/1 valid
    sta CasmVmmBuffer + CASM_LISTING_META_FILEID
    jsr listingValidateRecord
    jmp expectMismatchTail
vrflFail:
    sec
    rts

; ---------------------------------------------------------------------------
; validatePropagatesVmmTransferFailure
; A genuine catalog-read failure (fake includeCatalogRead, index 0 selected
; to fail) must propagate CASM_DIAG_VMM_TRANSFER_FAILED unchanged -- distinct
; from this module's own CASM_DIAG_LISTING_REPLAY_MISMATCH, proving real I/O
; failure and structural corruption are not conflated.
; ---------------------------------------------------------------------------
validatePropagatesVmmTransferFailure:
    jsr resetValidation
    bcs vptfFail
    jsr buildBaseRecord
    lda #$80
    sta CasmVmmBuffer + CASM_LISTING_META_FILEID
    lda #0
    sta FakeCatalogFailIndex
    jsr listingValidateRecord
    bcc vptfRestoreFail             ; unexpectedly succeeded
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne vptfRestoreFail             ; wrong diagnostic (e.g. the $3C mismatch)
    pha
    lda #$FF
    sta FakeCatalogFailIndex        ; restore "never match" for later cases
    pla
    clc
    rts
vptfRestoreFail:
    lda #$FF
    sta FakeCatalogFailIndex        ; restore "never match" for later cases
    jmp vptfFail
vptfFail:
    sec
    rts

; ---------------------------------------------------------------------------
; Stubs for listing.s's WP51 capture-code dependencies (see the .export
; block above). Unreachable from every case in this file.
; ---------------------------------------------------------------------------
diagPrintFatal:
    rts
sourceSetLineCapture:
    clc
    rts
sourceTakeCompletedLine:
    lda #0
    clc
    rts

; ---------------------------------------------------------------------------
; includeCatalogRead (fake, WP53 increment 5)
; Controllable stand-in for include.s's real VMM-backed routine.
; listingResolveFilename only depends on the contract -- id in A (already
; range-checked against CasmIncludeCatalogCount before this is ever called),
; populate CasmIncludeRecordStage's DEVICE/NAME fields, C/A result -- not on
; real VMM storage, so this indexes a small local table directly.
; FakeCatalogFailIndex selects one index that instead returns
; CASM_DIAG_VMM_TRANSFER_FAILED, C set; $FF (its default) disables this.
; ---------------------------------------------------------------------------
includeCatalogRead:
    cmp FakeCatalogFailIndex
    bne icrOk
    lda #CASM_DIAG_VMM_TRANSFER_FAILED
    sec
    rts
icrOk:
    tax
    lda fakeCatalogDevice, x
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_DEVICE
    lda fakeCatalogNameLo, x
    sta CasmPtr1Lo
    lda fakeCatalogNameHi, x
    sta CasmPtr1Hi
    ldy #0
icrNameLoop:
    lda (CasmPtr1Lo), y
    sta CasmIncludeRecordStage + CASM_INCLUDE_PHYS_REC_NAME, y
    beq icrNameDone
    iny
    jmp icrNameLoop
icrNameDone:
    lda #CASM_DIAG_NONE
    clc
    rts

.segment "RODATA"

; WP53 increment 5: real device-string table, identical to include.s's own
; includeSynthesizeOpenName table (index = device - CASM_DEVICE_MIN).
includeDeviceStrLo: .byte <includeDeviceStr8, <includeDeviceStr9, <includeDeviceStr10, <includeDeviceStr11
includeDeviceStrHi: .byte >includeDeviceStr8, >includeDeviceStr9, >includeDeviceStr10, >includeDeviceStr11
includeDeviceStr8:  .byte "8", 0
includeDeviceStr9:  .byte "9", 0
includeDeviceStr10: .byte "10", 0
includeDeviceStr11: .byte "11", 0

; WP53 increment 5: cliSourceSlotLo/Hi stand-in, a real 2-entry pointer
; table matching cli.s's own top-level source-name table's contract exactly
; (index = FILEID's own id bits, values = null-terminated CLI-spelled
; names). Real cli.s is not linked (this harness never establishes a real
; top-level source), so a fixed table is enough for listingResolveFilename's
; own copy loop to exercise.
cliSourceSlotLo: .byte <nameMain, <nameUtil
cliSourceSlotHi: .byte >nameMain, >nameUtil
nameMain: .byte "MAIN.S", 0
nameUtil: .byte "8:UTIL.S", 0

; WP53 increment 5: fake catalog for includeCatalogRead's own table above.
; Two real entries (id 0, 1, devices 8/9); CasmIncludeCatalogCount stays 2
; so id 2 is used only to prove listingResolveFilename's own out-of-range
; gate, never reaching this table.
fakeCatalogDevice: .byte 8, 9
fakeCatalogNameLo: .byte <fakeCatalogName0, <fakeCatalogName1
fakeCatalogNameHi: .byte >fakeCatalogName0, >fakeCatalogName1
fakeCatalogName0:  .byte "SUB.S", 0
fakeCatalogName1:  .byte "DEEP.S", 0
nameSub:  .byte "8:SUB.S", 0
nameDeep: .byte "9:DEEP.S", 0

nameNoPrefix:  .byte "SPLW01.LST", 0
; Device prefix deliberately names device 8 (the boot device), not another
; drive: this case exercises listingBuildOpenName's after-the-colon marker
; placement, which is identical for any device number, and an 8: prefix
; keeps the case self-contained on the harness's own disk. An earlier 9:
; spelling silently wrote its output onto whatever unrelated image happened
; to be mounted on drive 9.
namePrefixed:  .byte "8:SPLW02.LST", 0
nameReplace:   .byte "SPLW03.LST", 0
nameCommit:    .byte "SPLW04.LST", 0
nameAbortOpen: .byte "SPLW05.LST", 0

contentHello: .byte "hello", 0
contentOld:   .byte "oldstaledata", 0
contentNew:   .byte "newdata", 0

passMsg: .byte "CASM LISTWRITE: PASS", $0D, 0
failMsg: .byte "CASM LISTWRITE: FAIL", $0D, 0

.segment "BSS"

FailCount:  .res 1
TestDevice: .res 1

CasmOutputName:  .res CASM_FILENAME_BUFFER_SIZE  ; link-only; never used here
CasmListingName: .res CASM_FILENAME_BUFFER_SIZE
CasmListingLen:  .res 1

; Stand-ins for listing.s's WP51 capture-code dependencies; never written
; or read by any case in this file.
CasmPc:                     .res 2
CasmSourceCompletedFlags:   .res 1
CasmSourceCompletedStartLo: .res 1
CasmSourceCompletedStartHi: .res 1
CasmSourceCompletedLength:  .res 1
CasmSourceCompletedFileId:  .res 1
CasmSourceCompletedLineLo:  .res 1
CasmSourceCompletedLineHi:  .res 1

; WP53 increment 5: listingResolveFilename dependencies. CasmSourceCount and
; CasmIncludeCatalogCount are set to 2 in start (cliSourceSlotLo/Hi's own
; real 2-entry table and the fake catalog's own 2 entries are both RODATA,
; initialized at assembly time -- see the RODATA segment above).
; CasmIncludeRecordStage is the fake includeCatalogRead's own write target,
; matching the real routine's contract exactly.
CasmSourceCount:  .res 1
CasmIncludeCatalogCount: .res 1
CasmIncludeRecordStage:  .res CASM_INCLUDE_PHYS_REC_SIZE
FakeCatalogFailIndex: .res 1
