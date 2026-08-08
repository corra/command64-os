; tests/src/casm_spanread/casm_spanread.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 10 WP53 increment 2 fixture harness for
; source.s's sourceReadSpanChunk -- the random-access source-span reader
; WP53's listing serializer replays recorded spans through.
;
; Drives the real routine against a real VMM-backed source store loaded by
; the real sourceLoad from a real disk fixture (casmlc02, ".BYTE 65" + CR =
; 9 bytes), following casm_listcap.s's real-path precedent rather than
; poking a stand-in store. CasmSourceVmmSlot and CasmSourceLoadedLenLo/Hi
; are deliberately *not* imported: WP53's stop conditions forbid exposing
; the source slot, so this harness proves the contract only through the
; public API, exactly as the serializer will have to.
;
; Like casm_listcap.s, this harness supplies its own CasmSourceNames/
; CasmSourceCount/cliSourceSlotLo/Hi stand-in rather than linking cli.s.
;
; TWO DIFFERENT CASE RULES APPLY IN THIS FILE, and mixing them up silently
; produces a harness that can never pass (this cost a full session at
; increment 1):
;   * Disk filename literals are UPPERCASE ("CASMLC02"). ca65's C64 charmap
;     turns those into shifted PETSCII, which the OS's name normalization
;     accepts -- casm_listcap.s's own proven convention for these same
;     fixtures.
;   * Expected *content* literals are lowercase (".byte 65"). The charmap
;     turns lowercase into unshifted PETSCII ($2E $42 $59 ...), which is
;     byte-identical to the raw ASCII the CMake fixture generator wrote into
;     casmlc02.seq. An uppercase content literal would compare shifted bytes
;     against unshifted file bytes and never match.
.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_spanread.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import fileIoInit
.import sourceInit
.import sourceLoad
.import sourceOpen
.import sourceNextByte
.import sourceReadSpanChunk
.import CasmVmmBuffer
.import CasmSourceFileId
.import CasmSourceLineLo
.import CasmSourceLineHi
.import CasmSourceColumn
.import CasmSourceResultByte

.export CasmSourceNames
.export CasmSourceCount
.export cliSourceSlotLo
.export cliSourceSlotHi
; fileio.s references cli.s's output-name buffer, which this harness does not
; link. Same stand-in precedent as casm_listcap.s -- never written here, since
; no case in this file opens an output file.
.export CasmOutputName

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

    jsr spanReadHead
    jsr reportCase
    jsr resourcesCleanup

    jsr spanReadWhole
    jsr reportCase
    jsr resourcesCleanup

    jsr spanReadTailBoundary
    jsr reportCase
    jsr resourcesCleanup

    jsr spanRejectPastEnd
    jsr reportCase
    jsr resourcesCleanup

    jsr spanRejectZeroLen
    jsr reportCase
    jsr resourcesCleanup

    jsr spanRejectOverLen
    jsr reportCase
    jsr resourcesCleanup

    jsr spanRejectLenHi
    jsr reportCase
    jsr resourcesCleanup

    jsr spanPreservesTraversal
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
; reportCase
; Print '.' for a pass (carry clear) or 'F' for a fail (carry set), tallying
; FailCount. Preserves nothing.
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
; loadFixture
; Stage CASMLC02 in slot 0 and run the real sourceInit/fileIoInit/sourceLoad
; sequence, leaving a real VMM-backed 9-byte source store loaded.
; Outputs: C clear on success; C set on any real failure
; ---------------------------------------------------------------------------
loadFixture:
    ldy #0
lfCopy:
    lda fixtureName, y
    sta CasmSourceNames, y
    beq lfCopied
    iny
    bne lfCopy
lfCopied:
    lda #1
    sta CasmSourceCount
    jsr sourceInit
    jsr fileIoInit
    jmp sourceLoad

; ---------------------------------------------------------------------------
; requestSpan
; Set up a span request: A = length, X/Y = offset lo/hi, then call the real
; sourceReadSpanChunk.
; ---------------------------------------------------------------------------
requestSpan:
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    stx CasmVmmOffLo
    sty CasmVmmOffHi
    jmp sourceReadSpanChunk

; ---------------------------------------------------------------------------
; compareBuffer
; Compare CasmVmmBuffer against the literal at CasmPtr1Lo/Hi for
; CasmSpanLen bytes.
; Outputs: C clear if every byte matches; C set otherwise
; ---------------------------------------------------------------------------
compareBuffer:
    ldy #0
cbLoop:
    cpy CasmSpanLen
    beq cbEqual
    lda CasmVmmBuffer, y
    cmp (CasmPtr1Lo), y
    bne cbNotEqual
    iny
    bne cbLoop
cbNotEqual:
    sec
    rts
cbEqual:
    clc
    rts

; ---------------------------------------------------------------------------
; expectMismatch
; Shared tail for the four rejection cases: the call must have failed with
; CASM_DIAG_LISTING_REPLAY_MISMATCH. Carry/A as returned by the request.
; ---------------------------------------------------------------------------
expectMismatch:
    bcc emFail                   ; success is the bug in a rejection case
    cmp #CASM_DIAG_LISTING_REPLAY_MISMATCH
    bne emFail
    clc
    rts
emFail:
    sec
    rts

; ---------------------------------------------------------------------------
; spanReadHead
; Offset 0, length 8 returns the fixture's first 8 bytes (".byte 65"),
; stopping short of its CR.
; ---------------------------------------------------------------------------
spanReadHead:
    jsr loadFixture
    bcs srhFail
    lda #8
    ldx #0
    ldy #0
    jsr requestSpan
    bcs srhFail
    lda #8
    sta CasmSpanLen
    lda #<expectStmt
    sta CasmPtr1Lo
    lda #>expectStmt
    sta CasmPtr1Hi
    jmp compareBuffer
srhFail:
    sec
    rts

; ---------------------------------------------------------------------------
; spanReadWhole
; Offset 0, length 9 returns the entire fixture including its trailing CR --
; a span whose end lands exactly on the loaded length must be accepted.
; ---------------------------------------------------------------------------
spanReadWhole:
    jsr loadFixture
    bcs srwFail
    lda #9
    ldx #0
    ldy #0
    jsr requestSpan
    bcs srwFail
    lda #9
    sta CasmSpanLen
    lda #<expectWhole
    sta CasmPtr1Lo
    lda #>expectWhole
    sta CasmPtr1Hi
    jmp compareBuffer
srwFail:
    sec
    rts

; ---------------------------------------------------------------------------
; spanReadTailBoundary
; Offset 1, length 8 also ends exactly on the loaded length, this time from
; a non-zero offset: the complementary boundary to spanReadWhole.
; ---------------------------------------------------------------------------
spanReadTailBoundary:
    jsr loadFixture
    bcs srtFail
    lda #8
    ldx #1
    ldy #0
    jsr requestSpan
    bcs srtFail
    lda #8
    sta CasmSpanLen
    lda #<expectTail
    sta CasmPtr1Lo
    lda #>expectTail
    sta CasmPtr1Hi
    jmp compareBuffer
srtFail:
    sec
    rts

; ---------------------------------------------------------------------------
; spanRejectPastEnd
; Offset 2, length 8 ends one byte past the 9-byte store: must raise
; CASM_DIAG_LISTING_REPLAY_MISMATCH.
; ---------------------------------------------------------------------------
spanRejectPastEnd:
    jsr loadFixture
    bcs srpFail
    lda #8
    ldx #2
    ldy #0
    jsr requestSpan
    jmp expectMismatch
srpFail:
    sec
    rts

; ---------------------------------------------------------------------------
; spanRejectZeroLen
; A zero-length span is a replay disagreement, not a silent success.
; ---------------------------------------------------------------------------
spanRejectZeroLen:
    jsr loadFixture
    bcs srzFail
    lda #0
    ldx #0
    ldy #0
    jsr requestSpan
    jmp expectMismatch
srzFail:
    sec
    rts

; ---------------------------------------------------------------------------
; spanRejectOverLen
; One byte past the single-transfer staging limit (CASM_VMM_BUFFER_SIZE).
; ---------------------------------------------------------------------------
spanRejectOverLen:
    jsr loadFixture
    bcs sroFail
    lda #CASM_VMM_BUFFER_SIZE + 1
    ldx #0
    ldy #0
    jsr requestSpan
    jmp expectMismatch
sroFail:
    sec
    rts

; ---------------------------------------------------------------------------
; spanRejectLenHi
; A non-zero length high byte can never describe a legal single-chunk span,
; even when the low byte alone would be in range.
; ---------------------------------------------------------------------------
spanRejectLenHi:
    jsr loadFixture
    bcs srlFail
    lda #4
    sta CasmIoLenLo
    lda #1
    sta CasmIoLenHi
    lda #0
    sta CasmVmmOffLo
    sta CasmVmmOffHi
    jsr sourceReadSpanChunk
    jmp expectMismatch
srlFail:
    sec
    rts

; ---------------------------------------------------------------------------
; spanPreservesTraversal
; The contract that makes this routine safe to call from the serializer:
; a span read must change no traversal state. Open the source, consume two
; bytes, snapshot the traversal position, read a span that deliberately
; overlaps a completely different part of the store, and require both the
; snapshot and the *next* delivered byte to be unchanged.
; ---------------------------------------------------------------------------
spanPreservesTraversal:
    jsr loadFixture
    bcs sptFail
    jsr sourceOpen
    bcs sptFail
    jsr sourceNextByte
    bcs sptFail
    jsr sourceNextByte
    bcs sptFail

    lda CasmSourceFileId
    sta SnapFileId
    lda CasmSourceLineLo
    sta SnapLineLo
    lda CasmSourceLineHi
    sta SnapLineHi
    lda CasmSourceColumn
    sta SnapColumn

    ; Read a span from further along the store than the cursor sits.
    lda #4
    ldx #5
    ldy #0
    jsr requestSpan
    bcs sptFail

    lda CasmSourceFileId
    cmp SnapFileId
    bne sptFail
    lda CasmSourceLineLo
    cmp SnapLineLo
    bne sptFail
    lda CasmSourceLineHi
    cmp SnapLineHi
    bne sptFail
    lda CasmSourceColumn
    cmp SnapColumn
    bne sptFail

    ; Traversal must resume exactly where it was: the third byte of
    ; ".byte 65" is 'y'.
    jsr sourceNextByte
    bcs sptFail
    lda CasmSourceResultByte
    cmp #$59                     ; unshifted PETSCII 'Y'
    bne sptFail
    clc
    rts
sptFail:
    sec
    rts

.segment "RODATA"

; UPPERCASE: disk filename, per this file's header note.
fixtureName: .byte "CASMLC02", 0

; lowercase: raw fixture content bytes, per this file's header note.
expectStmt:  .byte ".byte 65"
expectWhole: .byte ".byte 65", $0D
expectTail:  .byte "byte 65", $0D

passMsg: .byte "CASM SPANREAD: PASS", $0D, 0
failMsg: .byte "CASM SPANREAD: FAIL", $0D, 0

; Slot-base table sourceLoad indexes exactly as cli.s's own; single slot.
cliSourceSlotLo:
    .byte <CasmSourceNames
cliSourceSlotHi:
    .byte >CasmSourceNames

.segment "BSS"

FailCount:   .res 1
TestDevice:  .res 1
CasmSpanLen: .res 1
SnapFileId:  .res 1
SnapLineLo:  .res 1
SnapLineHi:  .res 1
SnapColumn:  .res 1

CasmSourceNames: .res CASM_FILENAME_BUFFER_SIZE
CasmSourceCount: .res 1
CasmOutputName:  .res CASM_FILENAME_BUFFER_SIZE
