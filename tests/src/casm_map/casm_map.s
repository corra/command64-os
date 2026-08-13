; tests/src/casm_map/casm_map.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Standalone CASM Phase 10 WP52 fixture harness. Exercises symbols.s's
; symbolsReadByIndex and map.s's mapPrint/mapValidateRecord directly against
; real symbols/VMM/resources, the same way casm_symbols.s (WP27) and
; casm_listing.s (WP51) exercise their own modules. This isolated module-level
; evidence complements WP54's production call path. The 23 cases use one shared table for insertion-order coverage
; and fresh, explicitly freed tables where exact-count boundaries require it.
;
; Stubs diagPrintFatal locally for the same reason casm_symbols.s/
; casm_listing.s do: resources.s's exitSuccess/exitFatal reference it, and
; ld65 links whole object files, so it must resolve even though this
; harness never calls exitSuccess/exitFatal.
;
; Stubs diagPrintString locally too -- map.s imports it from diagnostics.s
; in production, but this harness never links diagnostics.s (the same
; lexer.s/source.s dependency-avoidance reason casm_symbols.s gives for not
; importing the real diagPrintFatal). This local diagPrintString is a sink,
; not a no-op: each call increments MapSinkCallCount and, only when that
; 16-bit count (before incrementing) equals MapSinkCaptureIndexLo/Hi,
; copies the null-terminated string into MapSinkCapture for exact
; comparison. mapPrint's own call sequence is deterministic -- one header
; call, one call per row, one total call -- so a fixture that wants to
; inspect one specific row re-runs mapPrint with MapSinkCaptureIndex set to
; that row's position (mapPrint is stateless/repeat-deterministic per its
; own contract) rather than this harness ever retaining all rows from a
; single pass. mapfull1 (512 symbols) relies on exactly this: it never
; captures row content at all, only the final MapSinkCallCount.
;
; CASM_SYMBOL_MAX (512) full-table testing needed a generated-name pattern
; distinct from every other fixture's names, matching casm_symbols.s's
; symfull1 "SF"+counter convention -- this file uses "MF"+counter instead
; so the two test binaries' conventions do not need to match, only be
; internally distinct within this file.

.include "command64.inc"
.include "../../../src/external/casm/common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_test_casm_map.inc"

.import __MAIN_START__
.import resourcesInit
.import resourcesCleanup
.import symbolsInit
.import symbolsInsert
.import symbolsReadByIndex
.import CasmSymbolVmmSlot
.import vmmWindowRead
.import vmmWindowWrite
.import vmmStoreFree
.import CasmVmmBuffer
.import mapPrint

.export diagPrintFatal
.export diagPrintString

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT
    jsr resourcesInit
    lda #0
    sta FailCount

    jsr mapempty1
    jsr reportCase
    jsr mapreadidx1
    jsr reportCase
    jsr mapone1
    jsr reportCase
    jsr maporder1a
    jsr reportCase
    jsr maporder1b
    jsr reportCase
    jsr mapcase1a
    jsr reportCase
    jsr mapcase1b
    jsr reportCase
    jsr maplen31
    jsr reportCase
    jsr mapinvalidnamelen32
    jsr reportCase
    jsr mapinvalidnamelen255
    jsr reportCase
    jsr mapboundary1
    jsr reportCase
    jsr maprepeat1
    jsr reportCase
    jsr mapreadidx2
    jsr reportCase
    jsr mapinvalidnamelen1
    jsr reportCase
    jsr mapdefinedclear1
    jsr reportCase
    jsr mapreservedflags1
    jsr reportCase
    jsr mapinvalidpad37
    jsr reportCase
    jsr mapinvalidpad63
    jsr reportCase
    jsr mappartialvmmfail1
    jsr reportCase
    jsr maptotaltransitions1
    jsr reportCase
    jsr mapcontract1
    jsr reportCase
    jsr mapvmmfail1
    jsr reportCase
    jsr mapfull1
    jsr reportCase

    ; Free the symbol table's VMM allocation before exit, matching
    ; casm_symbols.s's WP41-fix precedent -- a fresh DOS_EXIT does not
    ; implicitly release DOS_ALLOC_MEM's tracked capacity.
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
; mapRunCapture
; Shared helper: reset the sink (MapSinkCallCount = 0, MapSinkCaptureIndex =
; A on entry), call mapPrint, and return mapPrint's own C/A untouched so the
; caller can check both the sink's captured content and mapPrint's result.
; Inputs:  A = call index to capture (0 = header, 1 = first row, ...)
; Outputs: C/A = mapPrint's own result; MapSinkCallCount = total calls made;
;          MapSinkCapture/MapSinkCaptureLen = the targeted call's string
; Clobbers: A, X, Y, MapSink* state, and everything mapPrint clobbers
; ---------------------------------------------------------------------------
mapRunCapture:
    sta MapSinkCaptureIndex
    lda #0
    sta MapSinkCaptureIndexHi
    sta MapSinkCallCount
    sta MapSinkCallCountHi
    jmp mapPrint

; ---------------------------------------------------------------------------
; mapCompareCapture
; Compares MapSinkCapture (null-terminated) against the literal string
; whose pointer is in CasmPtr1Lo/Hi.
; Outputs: C clear if equal; C set if not
; Clobbers: A, Y
; ---------------------------------------------------------------------------
mapCompareCapture:
    ldy #0
mccLoop:
    lda MapSinkCapture, y
    cmp (CasmPtr1Lo), y
    bne mccNotEqual
    ; Equal at this position. Explicitly re-test the byte itself (not the
    ; stale Z flag from the cmp above, which reflects "operands equal," not
    ; "this byte is zero") -- a zero byte at a matching position means both
    ; strings terminated here identically.
    lda MapSinkCapture, y
    beq mccEqual
    iny
    jmp mccLoop
mccNotEqual:
    sec
    rts
mccEqual:
    clc
    rts

; Copy the current capture to CasmPtr1 for repeat-determinism comparison.
mapCopyCapture:
    ldy #0
mcpLoop:
    lda MapSinkCapture, y
    sta (CasmPtr1Lo), y
    beq mcpDone
    iny
    bne mcpLoop
mcpDone:
    rts

; Compare capture against CasmPtr0 without disturbing the transition-table
; cursor held separately in TotalTablePtrLo/Hi.
mapCompareCapturePtr0:
    ldy #0
mccpLoop:
    lda MapSinkCapture, y
    cmp (CasmPtr0Lo), y
    bne mccpFail
    lda MapSinkCapture, y
    beq mccpOk
    iny
    bne mccpLoop
mccpFail:
    sec
    rts
mccpOk:
    clc
    rts

; ---------------------------------------------------------------------------
; mapempty1
; mapPrint against a freshly initialized (empty) symbol table prints exactly
; two rows: the header and "000 SYMBOLS" (zero-padded, no data rows).
; ---------------------------------------------------------------------------
mapempty1:
    jsr symbolsInit
    bcc :+
    jmp me1Fail
:
    lda #0                       ; capture call 0 (the header)
    jsr mapRunCapture
    bcc :+
    jmp me1Fail
:
    lda #<msgExpectHeader
    sta CasmPtr1Lo
    lda #>msgExpectHeader
    sta CasmPtr1Hi
    jsr mapCompareCapture
    bcc :+
    jmp me1Fail
:
    lda #1                       ; capture call 1 (must be the total: no rows)
    jsr mapRunCapture
    bcc :+
    jmp me1Fail
:
    lda #<msgExpectTotal000
    sta CasmPtr1Lo
    lda #>msgExpectTotal000
    sta CasmPtr1Hi
    jsr mapCompareCapture
    bcc :+
    jmp me1Fail
:
    lda MapSinkCallCount
    cmp #2                       ; header + total, no data rows
    beq :+
    jmp me1Fail
:
    clc
    rts
me1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; mapreadidx1
; symbolsReadByIndex against the still-empty table: index 0 is already
; out of bounds (CasmSymbolCount = 0) and must report EOF, repeat-stable.
; ---------------------------------------------------------------------------
mapreadidx1:
    ldx #0
    ldy #0
    jsr symbolsReadByIndex
    bcc :+
    jmp mr1Fail
:
    cmp #CASM_STREAM_EOF
    beq :+
    jmp mr1Fail
:
    ; Repeat-stable: calling again returns EOF again.
    ldx #0
    ldy #0
    jsr symbolsReadByIndex
    bcc :+
    jmp mr1Fail
:
    cmp #CASM_STREAM_EOF
    beq :+
    jmp mr1Fail
:
    clc
    rts
mr1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; mapone1
; Insert exactly one symbol ("ONE", value $1234) and confirm mapPrint's row
; is "$1234 ONE" and the total is "001 SYMBOLS".
; ---------------------------------------------------------------------------
mapone1:
    lda #<nameOne
    sta CasmPtr0Lo
    lda #>nameOne
    sta CasmPtr0Hi
    lda #3
    ldx #$34
    ldy #$12
    jsr symbolsInsert
    bcc :+
    jmp mo1Fail
:
    lda #1                       ; capture call 1 (the only row)
    jsr mapRunCapture
    bcc :+
    jmp mo1Fail
:
    lda #<msgExpectOneRow
    sta CasmPtr1Lo
    lda #>msgExpectOneRow
    sta CasmPtr1Hi
    jsr mapCompareCapture
    bcc :+
    jmp mo1Fail
:
    lda #2                       ; capture call 2 (the total)
    jsr mapRunCapture
    bcc :+
    jmp mo1Fail
:
    lda #<msgExpectTotal001
    sta CasmPtr1Lo
    lda #>msgExpectTotal001
    sta CasmPtr1Hi
    jsr mapCompareCapture
    bcc :+
    jmp mo1Fail
:
    clc
    rts
mo1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; maporder1
; Insert "ZEBRA" then "APPLE" (alphabetically/hash-bucket order would very
; likely differ from insertion order) and confirm mapPrint's rows print in
; insertion order: ZEBRA (record index 1, inserted after ONE) first, APPLE
; (record index 2) second -- never re-sorted.
; ---------------------------------------------------------------------------
maporder1a:
    lda #<nameZebra
    sta CasmPtr0Lo
    lda #>nameZebra
    sta CasmPtr0Hi
    lda #5
    ldx #$00                 ; ValLo=$00, ValHi=$11 -> displays "$1100"
    ldy #$11
    jsr symbolsInsert
    bcc :+
    jmp mord1aFail
:
    cpx #1                        ; second insert overall (ONE, ZEBRA) -> index 1
    beq :+
    jmp mord1aFail
:
    lda #2                       ; capture call 2: row for record index 1 (ZEBRA)
    jsr mapRunCapture
    bcc :+
    jmp mord1aFail
:
    lda #<msgExpectZebraRow
    sta CasmPtr1Lo
    lda #>msgExpectZebraRow
    sta CasmPtr1Hi
    jsr mapCompareCapture
    bcc :+
    jmp mord1aFail
:
    clc
    rts
mord1aFail:
    sec
    rts

maporder1b:
    lda #<nameApple
    sta CasmPtr0Lo
    lda #>nameApple
    sta CasmPtr0Hi
    lda #5
    ldx #$00                 ; ValLo=$00, ValHi=$22 -> displays "$2200"
    ldy #$22
    jsr symbolsInsert
    bcc :+
    jmp mord1bFail
:
    cpx #2                        ; third insert overall (ONE, ZEBRA, APPLE) -> index 2
    beq :+
    jmp mord1bFail
:
    lda #3                       ; capture call 3: row for record index 2 (APPLE)
    jsr mapRunCapture
    bcc :+
    jmp mord1bFail
:
    lda #<msgExpectAppleRow
    sta CasmPtr1Lo
    lda #>msgExpectAppleRow
    sta CasmPtr1Hi
    jsr mapCompareCapture
    bcc :+
    jmp mord1bFail
:
    clc
    rts
mord1bFail:
    sec
    rts

; ---------------------------------------------------------------------------
; mapcase1
; "Case" and "CASE" are distinct symbols (symbolsInsert is case-sensitive);
; both rows must preserve exact case.
; ---------------------------------------------------------------------------
mapcase1a:
    lda #<nameCaseLower
    sta CasmPtr0Lo
    lda #>nameCaseLower
    sta CasmPtr0Hi
    lda #4
    ldx #$00                 ; ValLo=$00, ValHi=$01 -> displays "$0100"
    ldy #$01
    jsr symbolsInsert
    bcc :+
    jmp mc1aFail
:
    cpx #3                       ; fifth insert overall (ONE, ZEBRA, APPLE, Case) -> index 3
    beq :+
    jmp mc1aFail
:
    lda #4                       ; capture call 4: row for record index 3 (Case)
    jsr mapRunCapture
    bcc :+
    jmp mc1aFail
:
    lda #<msgExpectCaseLowerRow
    sta CasmPtr1Lo
    lda #>msgExpectCaseLowerRow
    sta CasmPtr1Hi
    jsr mapCompareCapture
    bcc :+
    jmp mc1aFail
:
    clc
    rts
mc1aFail:
    sec
    rts

mapcase1b:
    lda #<nameCaseUpper
    sta CasmPtr0Lo
    lda #>nameCaseUpper
    sta CasmPtr0Hi
    lda #4
    ldx #$00                 ; ValLo=$00, ValHi=$02 -> displays "$0200"
    ldy #$02
    jsr symbolsInsert
    bcc :+
    jmp mc1bFail
:
    cpx #4                       ; sixth insert overall -> index 4
    beq :+
    jmp mc1bFail
:
    lda #5                       ; capture call 5: row for record index 4 (CASE)
    jsr mapRunCapture
    bcc :+
    jmp mc1bFail
:
    lda #<msgExpectCaseUpperRow
    sta CasmPtr1Lo
    lda #>msgExpectCaseUpperRow
    sta CasmPtr1Hi
    jsr mapCompareCapture
    bcc :+
    jmp mc1bFail
:
    clc
    rts
mc1bFail:
    sec
    rts

; ---------------------------------------------------------------------------
; maplen31
; A full 31-byte name prints without truncation or padding.
; ---------------------------------------------------------------------------
maplen31:
    lda #<nameLen31
    sta CasmPtr0Lo
    lda #>nameLen31
    sta CasmPtr0Hi
    lda #31
    ldx #$FF
    ldy #$00
    jsr symbolsInsert
    bcc :+
    jmp ml31Fail
:
    lda #6                       ; capture call 6: row for record index 5
    jsr mapRunCapture
    bcc :+
    jmp ml31Fail
:
    lda #<msgExpectLen31Row
    sta CasmPtr1Lo
    lda #>msgExpectLen31Row
    sta CasmPtr1Hi
    jsr mapCompareCapture
    bcc :+
    jmp ml31Fail
:
    clc
    rts
ml31Fail:
    sec
    rts

; NameLen 32 and 255 are independently rejected at the upper boundary and
; after 8-bit wrap-prone input. mapInvalidWithRestore always restores record 0.
mapinvalidnamelen32:
    lda #32
    jmp mapInvalidNameLen

mapinvalidnamelen255:
    lda #255
mapInvalidNameLen:
    sta CorruptValue
    lda #<corruptNameLenValue
    ldy #>corruptNameLenValue
    jmp mapInvalidWithRestore

corruptNameLenValue:
    lda CorruptValue
    sta CasmVmmBuffer + CASM_SYMBOL_REC_NAMELEN
    rts

; ---------------------------------------------------------------------------
; mapboundary1
; Values $0000 and $FFFF both format as exactly four uppercase hex digits.
; ---------------------------------------------------------------------------
mapboundary1:
    lda #<nameZero
    sta CasmPtr0Lo
    lda #>nameZero
    sta CasmPtr0Hi
    lda #4
    ldx #$00
    ldy #$00
    jsr symbolsInsert
    bcc :+
    jmp mb1Fail
:
    lda #<nameMax
    sta CasmPtr0Lo
    lda #>nameMax
    sta CasmPtr0Hi
    lda #3
    ldx #$FF
    ldy #$FF
    jsr symbolsInsert
    bcc :+
    jmp mb1Fail
:
    lda #7                       ; capture call 7: row for record index 6 (ZERO, $0000)
    jsr mapRunCapture
    bcc :+
    jmp mb1Fail
:
    lda #<msgExpectZeroRow
    sta CasmPtr1Lo
    lda #>msgExpectZeroRow
    sta CasmPtr1Hi
    jsr mapCompareCapture
    bcc :+
    jmp mb1Fail
:
    lda #8                       ; capture call 8: row for record index 7 (MAX, $FFFF)
    jsr mapRunCapture
    bcc :+
    jmp mb1Fail
:
    lda #<msgExpectMaxRow
    sta CasmPtr1Lo
    lda #>msgExpectMaxRow
    sta CasmPtr1Hi
    jsr mapCompareCapture
    bcc :+
    jmp mb1Fail
:
    clc
    rts
mb1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; maprepeat1
; mapPrint is stateless/deterministic: calling it twice in a row produces an
; identical boundary rows, total text, and call count (8 symbols so far).
; ---------------------------------------------------------------------------
maprepeat1:
    lda #7                       ; $0000 ZERO row
    jsr mapRunCapture
    bcc :+
    jmp mrp1Fail
:
    lda MapSinkCallCount
    sta RepeatFirstCount
    lda #<RepeatFirstCapture
    sta CasmPtr1Lo
    lda #>RepeatFirstCapture
    sta CasmPtr1Hi
    jsr mapCopyCapture
    lda #7
    jsr mapRunCapture
    bcc :+
    jmp mrp1Fail
:
    lda MapSinkCallCount
    cmp RepeatFirstCount
    beq :+
    jmp mrp1Fail
:
    ; 8 symbols so far -> header + 8 rows + total = 10 calls.
    lda MapSinkCallCount
    cmp #10
    beq :+
    jmp mrp1Fail
:
    lda #<RepeatFirstCapture
    sta CasmPtr1Lo
    lda #>RepeatFirstCapture
    sta CasmPtr1Hi
    jsr mapCompareCapture
    bcs mrp1Fail
    lda #9                       ; exact total on the repeat pass
    jsr mapRunCapture
    bcs mrp1Fail
    lda #<msgExpectTotal008
    sta CasmPtr1Lo
    lda #>msgExpectTotal008
    sta CasmPtr1Hi
    jsr mapCompareCapture
    bcs mrp1Fail
    clc
    rts
mrp1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; mapreadidx2
; symbolsReadByIndex directly: index 7 (the last valid record, MAX) returns
; DATA with the correct value; index 8 (== CasmSymbolCount) and index 9
; (beyond) both return EOF, repeat-stable.
; ---------------------------------------------------------------------------
mapreadidx2:
    ldx #7
    ldy #0
    jsr symbolsReadByIndex
    bcc :+
    jmp mri2Fail
:
    cmp #CASM_STREAM_DATA
    beq :+
    jmp mri2Fail
:
    lda CasmVmmBuffer + CASM_SYMBOL_REC_VAL_LO
    cmp #$FF
    beq :+
    jmp mri2Fail
:
    lda CasmVmmBuffer + CASM_SYMBOL_REC_VAL_HI
    cmp #$FF
    beq :+
    jmp mri2Fail
:
    ldx #8
    ldy #0
    jsr symbolsReadByIndex
    bcc :+
    jmp mri2Fail
:
    cmp #CASM_STREAM_EOF
    beq :+
    jmp mri2Fail
:
    ldx #9
    ldy #0
    jsr symbolsReadByIndex
    bcc :+
    jmp mri2Fail
:
    cmp #CASM_STREAM_EOF
    beq :+
    jmp mri2Fail
:
    clc
    rts
mri2Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; mapCorruptRecord
; Shared helper: read record index A (0 in every fixture that uses this --
; record 0, "ONE") into CasmVmmBuffer, apply the caller's corruption (via a
; subroutine pointer in CorruptPtrLo/Hi), and write it back.
; Inputs:  CorruptPtrLo/Hi = subroutine to apply the corruption to
;              CasmVmmBuffer (clobbers A/Y only)
; Outputs: C clear on success
; Clobbers: A, X, Y, CasmVmmOffLo/OffHi, CasmIoLenLo/Hi, CasmVmmBuffer
; ---------------------------------------------------------------------------
mapCorruptRecord:
    lda CorruptRecordLo
    sta CasmVmmOffLo
    lda CorruptRecordHi
    sta CasmVmmOffHi
    ; Convert record index to its 64-byte VMM offset.
    ldx #6
mcrShift:
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    dex
    bne mcrShift
    lda #CASM_SYMBOL_REC_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmSymbolVmmSlot
    jsr vmmWindowRead
    bcc :+
    rts
:
    jsr callCorruptPtr

    lda CorruptRecordLo
    sta CasmVmmOffLo
    lda CorruptRecordHi
    sta CasmVmmOffHi
    ldx #6
mcrWriteShift:
    asl CasmVmmOffLo
    rol CasmVmmOffHi
    dex
    bne mcrWriteShift
    lda #CASM_SYMBOL_REC_SIZE
    sta CasmIoLenLo
    lda #0
    sta CasmIoLenHi
    ldx CasmSymbolVmmSlot
    jmp vmmWindowWrite

callCorruptPtr:
    jmp (CorruptPtrLo)

; ---------------------------------------------------------------------------
; mapinvalidnamelen1
; Corrupt record 0's NameLen to 0 (out of the valid 1-31 range); mapPrint
; must report CASM_DIAG_SYMBOL_MAP_INVALID and stop (not print past it).
; ---------------------------------------------------------------------------
mapinvalidnamelen1:
    lda #0
    sta CorruptRecordLo
    sta CorruptRecordHi
    lda #<corruptNameLenZero
    sta CorruptPtrLo
    lda #>corruptNameLenZero
    sta CorruptPtrHi
    jsr mapCorruptRecord
    bcc :+
    jmp min1Fail
:
    jsr mapPrint
    bcs :+
    jmp min1Fail                 ; must fail, not succeed
:
    cmp #CASM_DIAG_SYMBOL_MAP_INVALID
    beq :+
    jmp min1Fail
:
    ; Restore a valid record so later fixtures (mapinvalidflags1 onward)
    ; start from known-good state.
    lda #<corruptRestoreOne
    sta CorruptPtrLo
    lda #>corruptRestoreOne
    sta CorruptPtrHi
    jsr mapCorruptRecord
    bcc :+
    jmp min1Fail
:
    clc
    rts
min1Fail:
    sec
    rts

corruptNameLenZero:
    lda #0
    sta CasmVmmBuffer + CASM_SYMBOL_REC_NAMELEN
    rts

corruptRestoreOne:
    lda #3
    sta CasmVmmBuffer + CASM_SYMBOL_REC_NAMELEN
    rts

; ---------------------------------------------------------------------------
; DEFINED clear is rejected independently from every reserved flag bit. The
; reserved-bit case walks $02 through $80 one bit at a time, always alongside
; DEFINED, so no combination can mask an individual invalid bit.
; ---------------------------------------------------------------------------
mapdefinedclear1:
    lda #0
    sta CorruptValue
    lda #<corruptFlagsValue
    ldy #>corruptFlagsValue
    jmp mapInvalidWithRestore

mapreservedflags1:
    lda #$02
mrfLoop:
    sta ReservedFlagBit
    ora #CASM_SYMBOL_FLAG_DEFINED
    sta CorruptValue
    lda #<corruptFlagsValue
    ldy #>corruptFlagsValue
    jsr mapInvalidWithRestore
    bcs mrfFail
    asl ReservedFlagBit
    lda ReservedFlagBit
    bne mrfLoop
    clc
    rts
mrfFail:
    sec
    rts

corruptFlagsValue:
    lda CorruptValue
    sta CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    rts

; ---------------------------------------------------------------------------
; Both endpoints of the reserved range, offsets 37 and 63, reject nonzero.
; ---------------------------------------------------------------------------
mapinvalidpad37:
    lda #37
    bne mapInvalidPad
mapinvalidpad63:
    lda #63
mapInvalidPad:
    sta CorruptOffset
    lda #<corruptPadByte
    ldy #>corruptPadByte
    jmp mapInvalidWithRestore

corruptPadByte:
    ldy CorruptOffset
    lda #$01
    sta CasmVmmBuffer, y
    rts

corruptRestoreRecord:
    lda #3
    sta CasmVmmBuffer + CASM_SYMBOL_REC_NAMELEN
    lda #CASM_SYMBOL_FLAG_DEFINED
    sta CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    ldy #37
mirClearReserved:
    lda #0
    sta CasmVmmBuffer, y
    iny
    cpy #CASM_SYMBOL_REC_SIZE
    bne mirClearReserved
    rts

; Apply corruption pointer A/Y to record 0, require exact invalid diagnostic,
; then restore every field touched by this increment before returning.
mapInvalidWithRestore:
    sta CorruptPtrLo
    sty CorruptPtrHi
    lda #0
    sta CorruptRecordLo
    sta CorruptRecordHi
    jsr mapCorruptRecord
    bcs miwrFail
    jsr mapPrint
    bcc miwrRestoreFail
    cmp #CASM_DIAG_SYMBOL_MAP_INVALID
    bne miwrRestoreFail
    lda #<corruptRestoreRecord
    sta CorruptPtrLo
    lda #>corruptRestoreRecord
    sta CorruptPtrHi
    jsr mapCorruptRecord
    rts
miwrRestoreFail:
    php
    lda #<corruptRestoreRecord
    sta CorruptPtrLo
    lda #>corruptRestoreRecord
    sta CorruptPtrHi
    jsr mapCorruptRecord
    plp
miwrFail:
    sec
    rts

; Corrupt record 1, allowing header and record 0 to print, then free the slot.
; mapPrint must propagate the VMM failure with exactly two sink calls emitted.
mappartialvmmfail1:
    lda #0
    sta MapSinkCallCount
    sta MapSinkCallCountHi
    lda #1
    sta MapSinkFreeAfterRow
    lda #0                       ; capture header; content is irrelevant
    jsr mapRunCapture
    sta SavedResult
    php
    lda #0
    sta MapSinkFreeAfterRow
    plp
    bcc mpvfFail
    lda SavedResult
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    bne mpvfFail
    lda MapSinkCallCount
    cmp #2
    bne mpvfFail
    lda MapSinkCallCountHi
    bne mpvfFail
    ; The slot is already freed; rebuild the shared 8-record fixture for the
    ; remaining corruption/failure cases rather than retaining stale state.
    jsr mapBuildEight
    rts
mpvfFail:
    sec
    rts

; Exact decimal transitions use fresh tables and capture count+1 as a 16-bit
; call index. Each scenario frees its VMM store before the next allocation.
maptotaltransitions1:
    jsr mapFreeTable
    bcc :+
    jmp mttFail
:
    lda #<totalCases
    sta TotalTablePtrLo
    lda #>totalCases
    sta TotalTablePtrHi
    lda #8
    sta TotalCasesLeft
mttLoop:
    lda TotalTablePtrLo
    sta CasmPtr1Lo
    lda TotalTablePtrHi
    sta CasmPtr1Hi
    ldy #0
    lda (CasmPtr1Lo), y
    sta FillTargetLo
    iny
    lda (CasmPtr1Lo), y
    sta FillTargetHi
    iny
    lda (CasmPtr1Lo), y
    sta ExpectedPtrLo
    iny
    lda (CasmPtr1Lo), y
    sta ExpectedPtrHi
    jsr mapFreshFill
    bcs mttFail
    lda FillTargetLo
    clc
    adc #1
    sta MapSinkCaptureIndex
    lda FillTargetHi
    adc #0
    sta MapSinkCaptureIndexHi
    lda #0
    sta MapSinkCallCount
    sta MapSinkCallCountHi
    jsr mapPrint
    bcs mttFreeFail
    lda ExpectedPtrLo
    sta CasmPtr0Lo
    lda ExpectedPtrHi
    sta CasmPtr0Hi
    jsr mapCompareCapturePtr0
    bcs mttFreeFail
    jsr mapFreeTable
    bcs mttFail
    clc
    lda TotalTablePtrLo
    adc #4
    sta TotalTablePtrLo
    bcc :+
    inc TotalTablePtrHi
:
    dec TotalCasesLeft
    bne mttLoop
    jsr mapBuildEight
    rts
mttFreeFail:
    jsr mapFreeTable
mttFail:
    sec
    rts

; Exported mapPrint contract: success returns A=$00/C clear and preserves SP;
; invalid-record failure returns A=$42/C set and preserves SP. The sink
; intentionally clobbers A/X/Y, matching diagPrintString's documented
; volatile-register assumption rather than accidentally preserving them.
mapcontract1:
    tsx
    stx SavedSp
    jsr mapPrint
    bcs mcxFail
    cmp #CASM_DIAG_NONE
    bne mcxFail
    tsx
    cpx SavedSp
    bne mcxFail
    lda #0
    sta CorruptRecordLo
    sta CorruptRecordHi
    lda #<corruptNameLenZero
    sta CorruptPtrLo
    lda #>corruptNameLenZero
    sta CorruptPtrHi
    jsr mapCorruptRecord
    bcs mcxFail
    tsx
    stx SavedSp
    jsr mapPrint
    bcc mcxRestoreFail
    cmp #CASM_DIAG_SYMBOL_MAP_INVALID
    bne mcxRestoreFail
    tsx
    cpx SavedSp
    bne mcxRestoreFail
    lda #<corruptRestoreRecord
    sta CorruptPtrLo
    lda #>corruptRestoreRecord
    sta CorruptPtrHi
    jsr mapCorruptRecord
    rts
mcxRestoreFail:
    lda #<corruptRestoreRecord
    sta CorruptPtrLo
    lda #>corruptRestoreRecord
    sta CorruptPtrHi
    jsr mapCorruptRecord
mcxFail:
    sec
    rts

; Build a fresh symbol table with FillTargetHi:Lo distinct four-byte names.
; Generated names are "MT" plus the 16-bit insertion index.
mapFreshFill:
    jsr symbolsInit
    bcs mffFail
    lda #0
    sta FullCounterLo
    sta FullCounterHi
mffLoop:
    lda FullCounterHi
    cmp FillTargetHi
    bne :+
    lda FullCounterLo
    cmp FillTargetLo
    beq mffDone
:
    lda #'M'
    sta FullNameBuf
    lda #'T'
    sta FullNameBuf + 1
    lda FullCounterLo
    sta FullNameBuf + 2
    lda FullCounterHi
    sta FullNameBuf + 3
    lda #<FullNameBuf
    sta CasmPtr0Lo
    lda #>FullNameBuf
    sta CasmPtr0Hi
    lda #4
    ldx FullCounterLo
    ldy FullCounterHi
    jsr symbolsInsert
    bcs mffFreeFail
    inc FullCounterLo
    bne mffLoop
    inc FullCounterHi
    jmp mffLoop
mffDone:
    clc
    rts
mffFreeFail:
    jsr mapFreeTable
mffFail:
    sec
    rts

mapFreeTable:
    ldx CasmSymbolVmmSlot
    jmp vmmStoreFree

mapBuildEight:
    lda #8
    sta FillTargetLo
    lda #0
    sta FillTargetHi
    jmp mapFreshFill

; ---------------------------------------------------------------------------
; mapvmmfail1
; Free the symbol table's VMM slot out from under symbolsReadByIndex, the
; same deterministic-rejection technique casm_listing.s's listingvmmfail1
; uses: a real, local vmmWindowRead bounds rejection rather than depending
; on an unreliable REU-exhaustion condition. This ends use of the current
; freed table; mapfull1 subsequently initializes a fresh one.
; ---------------------------------------------------------------------------
mapvmmfail1:
    ldx CasmSymbolVmmSlot
    jsr vmmStoreFree
    bcc :+
    jmp mvf1Fail
:
    ldx #0
    ldy #0
    jsr symbolsReadByIndex
    bcs :+
    jmp mvf1Fail                 ; must fail against a freed slot
:
    cmp #CASM_DIAG_VMM_TRANSFER_FAILED
    beq :+
    jmp mvf1Fail
:
    clc
    rts
mvf1Fail:
    sec
    rts

; ---------------------------------------------------------------------------
; mapfull1
; Fresh table, filled to exactly CASM_SYMBOL_MAX (512) distinct generated
; names ("MF" + a 16-bit counter, matching casm_symbols.s's symfull1
; "SF"+counter convention with a distinct prefix). mapPrint's total call
; count must be exactly 514 (header + 512 rows + total); row content is
; never captured here, only counted -- MapSinkCaptureIndex is left at a
; value no real call index reaches ($FFFF is never used as an index, but
; any value >= 514 works equally; 0 is deliberately avoided so the header
; itself is not spuriously captured/compared against stale state).
; ---------------------------------------------------------------------------
mapfull1:
    jsr symbolsInit
    bcc :+
    jmp mf1Fail
:
    lda #0
    sta FullCounterLo
    sta FullCounterHi
mf1InsertLoop:
    ; Loop while (FullCounterHi:FullCounterLo) < CASM_SYMBOL_MAX (512).
    lda FullCounterHi
    cmp #>CASM_SYMBOL_MAX
    bcc mf1InsertGo
    bne mf1InsertLoopDone
    lda FullCounterLo
    cmp #<CASM_SYMBOL_MAX
    bcc mf1InsertGo
mf1InsertLoopDone:
    jmp mf1InsertDone
mf1InsertGo:
    lda #<'M'
    sta FullNameBuf
    lda #<'F'
    sta FullNameBuf + 1
    lda FullCounterLo
    sta FullNameBuf + 2
    lda FullCounterHi
    sta FullNameBuf + 3

    lda #<FullNameBuf
    sta CasmPtr0Lo
    lda #>FullNameBuf
    sta CasmPtr0Hi
    lda #4
    ldx FullCounterLo
    ldy FullCounterHi
    jsr symbolsInsert
    bcc :+
    jmp mf1Fail
:
    inc FullCounterLo
    bne mf1InsertLoop
    inc FullCounterHi
    jmp mf1InsertLoop
mf1InsertDone:

    lda #$FF                     ; $FFFF is outside the 0..513 call range
    sta MapSinkCaptureIndex
    sta MapSinkCaptureIndexHi
    lda #0
    sta MapSinkCallCount
    sta MapSinkCallCountHi
    jsr mapPrint
    bcc :+
    jmp mf1Fail
:
    lda MapSinkCallCount
    cmp #<514
    bne mf1Fail
    ; MapSinkCallCount is a single byte (0-255) and 514 does not fit --
    ; MapSinkCallCountHi holds the overflow. See its BSS declaration.
    lda MapSinkCallCountHi
    cmp #>514
    beq :+
    jmp mf1Fail
:
    clc
    rts
mf1Fail:
    sec
    rts

.segment "RODATA"

passMsg:
    .byte "CASM MAP: PASS", PetCr, 0
failMsg:
    .byte "CASM MAP: FAIL", PetCr, 0

; Explicit link check retained alongside the direct fixture calls: forces ld65
; to resolve symbolsReadByIndex/mapPrint by exact name.
mapLinkTable:
    .word symbolsReadByIndex
    .word mapPrint

nameOne:
    .byte "ONE"
nameZebra:
    .byte "ZEBRA"
nameApple:
    .byte "APPLE"
nameCaseLower:
    .byte "Case"
nameCaseUpper:
    .byte "CASE"
nameLen31:
    .byte "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"    ; exactly 31 bytes
nameZero:
    .byte "ZERO"
nameMax:
    .byte "MAX"

msgExpectHeader:
    .byte "SYMBOL MAP", PetCr, 0
msgExpectTotal000:
    .byte "000 SYMBOLS", PetCr, 0
msgExpectTotal001:
    .byte "001 SYMBOLS", PetCr, 0
msgExpectTotal008:
    .byte "008 SYMBOLS", PetCr, 0
msgExpectOneRow:
    .byte "$1234 ONE", PetCr, 0
msgExpectZebraRow:
    .byte "$1100 ZEBRA", PetCr, 0
msgExpectAppleRow:
    .byte "$2200 APPLE", PetCr, 0
msgExpectCaseLowerRow:
    .byte "$0100 Case", PetCr, 0
msgExpectCaseUpperRow:
    .byte "$0200 CASE", PetCr, 0
msgExpectLen31Row:
    .byte "$00FF XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX", PetCr, 0
msgExpectZeroRow:
    .byte "$0000 ZERO", PetCr, 0
msgExpectMaxRow:
    .byte "$FFFF MAX", PetCr, 0

msgExpectTotal009: .byte "009 SYMBOLS", PetCr, 0
msgExpectTotal010: .byte "010 SYMBOLS", PetCr, 0
msgExpectTotal099: .byte "099 SYMBOLS", PetCr, 0
msgExpectTotal100: .byte "100 SYMBOLS", PetCr, 0
msgExpectTotal255: .byte "255 SYMBOLS", PetCr, 0
msgExpectTotal256: .byte "256 SYMBOLS", PetCr, 0
msgExpectTotal511: .byte "511 SYMBOLS", PetCr, 0
msgExpectTotal512: .byte "512 SYMBOLS", PetCr, 0

totalCases:
    .word 9,   msgExpectTotal009
    .word 10,  msgExpectTotal010
    .word 99,  msgExpectTotal099
    .word 100, msgExpectTotal100
    .word 255, msgExpectTotal255
    .word 256, msgExpectTotal256
    .word 511, msgExpectTotal511
    .word 512, msgExpectTotal512

.segment "BSS"

FailCount:  .res 1

; maporder1/mapcase1 rely on symbolsInsert's record-index return value
; matching this file's fixed insertion sequence exactly: ONE=0, ZEBRA=1,
; APPLE=2, Case=3, CASE=4, the 31-byte name=5, ZERO=6, MAX=7. If a future
; fixture is inserted between these without updating every capture index
; below it, the mismatch shows up immediately as a content-comparison
; failure, not a silent pass.

RepeatFirstCount: .res 1
RepeatFirstCapture: .res 40

CorruptPtrLo: .res 1
CorruptPtrHi: .res 1
CorruptRecordLo: .res 1
CorruptRecordHi: .res 1
CorruptValue:    .res 1
CorruptOffset:   .res 1
ReservedFlagBit: .res 1

FillTargetLo:    .res 1
FillTargetHi:    .res 1
ExpectedPtrLo:   .res 1
ExpectedPtrHi:   .res 1
TotalTablePtrLo: .res 1
TotalTablePtrHi: .res 1
TotalCasesLeft:  .res 1
SavedSp:         .res 1
SavedResult:     .res 1

FullCounterLo: .res 1
FullCounterHi: .res 1
FullNameBuf:   .res 4

; ---------------------------------------------------------------------------
; diagPrintFatal / diagPrintString stubs
; ---------------------------------------------------------------------------
.segment "CODE"

diagPrintFatal:
    rts

; See the file header comment for the sink's exact contract.
diagPrintString:
    stx CasmPtr0Lo
    sty CasmPtr0Hi

    lda MapSinkCallCount
    cmp MapSinkCaptureIndex
    bne dpsSkipCapture
    lda MapSinkCallCountHi
    cmp MapSinkCaptureIndexHi
    bne dpsSkipCapture

    ldy #0
dpsCopyLoop:
    lda (CasmPtr0Lo), y
    sta MapSinkCapture, y
    beq dpsCopyDone
    iny
    cpy #39
    bcc dpsCopyLoop
dpsCopyDone:
    sty MapSinkCaptureLen

dpsSkipCapture:
    inc MapSinkCallCount
    bne dpsNoCarry
    inc MapSinkCallCountHi
dpsNoCarry:
    lda MapSinkFreeAfterRow
    beq dpsReturn
    lda MapSinkCallCount
    cmp #2                       ; header + first valid row emitted
    bne dpsReturn
    lda MapSinkCallCountHi
    bne dpsReturn
    ldx CasmSymbolVmmSlot
    jsr vmmStoreFree
dpsReturn:
    ; Production diagPrintString's A/X/Y are documented volatile. Return
    ; conspicuous values so mapPrint cannot accidentally depend on this stub
    ; preserving any of them.
    lda #$A5
    ldx #$5A
    ldy #$C3
    rts

.segment "BSS"

MapSinkCallCount:     .res 1
MapSinkCallCountHi:   .res 1
MapSinkCaptureIndex:  .res 1
MapSinkCaptureIndexHi:.res 1
MapSinkCapture:       .res 40
MapSinkCaptureLen:    .res 1
MapSinkFreeAfterRow:  .res 1
