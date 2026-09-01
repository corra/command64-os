; src/external/casm/map.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM Phase 10 WP52: deterministic /M symbol map formatting. mapPrint walks
; symbol records in definition (insertion) order via symbolsReadByIndex --
; never CasmSymbolBuckets hash order -- and prints "$HHHH LABEL" rows plus a
; final "NNN SYMBOLS" total. WP54 wired mapPrint into production `/M` dispatch
; after the PRG and optional listing are committed.
;
; This module owns no VMM/file/source resource of its own: symbolsReadByIndex
; is the only VMM access it performs, entirely through the symbol table's own
; registered slot. No zero-page growth; all state here is ordinary BSS.
;
; Deliberately independent of diagnostics.s's own private hex/decimal
; formatters (printHex8/printNibble/printDec16): those print directly via
; OS_API one character at a time, but mapPrint needs a complete row built in
; a buffer first, so it owns its own buffer-writing formatters instead.

.include "command64.inc"
.include "common.inc"

.import symbolsReadByIndex
.import diagPrintString
.import CasmVmmBuffer

.export mapPrint

; WP90: combined "<owner>@<local>" name portion is capped at this many
; bytes so a formatted row stays within the 40-column screen and the
; 40-byte CasmMapRowBuf ("$HHHH " = 6, + name, + CR + null <= 39). Same
; ceiling the pre-WP90 code already imposed implicitly via the 31-byte
; Name slot; a qualified name past it is truncated (rare -- test fixture
; names are short).
CASM_MAP_NAME_MAX = 31

.segment "BSS"

CasmMapCursorLo:    .res 1   ; symbolsReadByIndex iteration cursor (Lo/Hi)
CasmMapCursorHi:    .res 1
CasmMapCountLo:     .res 1   ; rows printed so far, 0..CASM_SYMBOL_MAX (Lo/Hi)
CasmMapCountHi:     .res 1
CasmMapScratchLo:   .res 1   ; mapFormatTotal's private decimal-division scratch
CasmMapScratchHi:   .res 1
CasmMapRowBuf:      .res 40  ; one formatted row; max content is 39 bytes
                             ; ("$HHHH " + up to CASM_MAP_NAME_MAX name + CR + null)

; WP90: definition-order walk state for @local qualified-name rendering.
; Records iterate in insert order == source order, and a @local is always
; inserted while its own scope's global label is "current" with no other
; global between them -- so the most recent plain-DEFINED (global) label
; record seen during the walk IS a @local record's owner. Rendered as
; "<owner>@<local>" (the local's stored name already begins with '@').
CasmMapOwnerName:  .res 31
CasmMapOwnerLen:   .res 1
; Count of global labels seen so far -- cross-checks a @local's stored
; SCOPE ordinal (CASM_SYMBOL_REC_SCOPE_LO/HI, a 0-based global-label
; ordinal, WP89) against the walk: a mismatch means the pass driver's
; Pass 1 and Pass 2 scope tracking disagreed, so the map is not trustworthy.
CasmMapGlobalCountLo: .res 1
CasmMapGlobalCountHi: .res 1
CasmMapNameCount:  .res 1   ; mapFormatRow's name-length cap counter

.segment "CODE"

; ---------------------------------------------------------------------------
; mapPrint
; Prints the complete deterministic symbol map: a header, one row per symbol
; record in definition order, and a final "NNN SYMBOLS" total. Repeated calls
; restart at record index zero and are deterministic (symbolsReadByIndex is
; stateless; all iteration state lives in this module's own BSS, reset here).
;
; Inputs:  none
; Outputs: C clear, A = CASM_DIAG_NONE (every row printed)
;          C set, A = CASM_DIAG_SYMBOL_MAP_INVALID (a record failed
;              validation: bad NameLen, DEFINED clear, reserved flag bits
;              set, or nonzero reserved bytes 37-63) or
;              CASM_DIAG_VMM_TRANSFER_FAILED (symbolsReadByIndex's own
;              internal VMM failure)
; Clobbers: A, X, Y, CasmMap* state, CasmVmmOffLo/OffHi, CasmIoLenLo/Hi,
;           CasmVmmBuffer (via symbolsReadByIndex), and OS API-defined
;           volatile registers
; ---------------------------------------------------------------------------
mapPrint:
    lda #0
    sta CasmMapCursorLo
    sta CasmMapCursorHi
    sta CasmMapCountLo
    sta CasmMapCountHi
    sta CasmMapOwnerLen       ; WP90: no owner global seen yet
    sta CasmMapGlobalCountLo
    sta CasmMapGlobalCountHi

    ldx #<msgMapHeader
    ldy #>msgMapHeader
    jsr diagPrintString

mpLoop:
    ldx CasmMapCursorLo
    ldy CasmMapCursorHi
    jsr symbolsReadByIndex
    bcs mpPropagate           ; A = CASM_DIAG_VMM_TRANSFER_FAILED, C set
    cmp #CASM_STREAM_EOF
    beq mpDone

    ; CASM_STREAM_DATA: CasmVmmBuffer holds the record.
    jsr mapValidateRecord
    bcs mpPropagate           ; A = CASM_DIAG_SYMBOL_MAP_INVALID, C set

    ; WP90: a @local record must have an owner global already seen in the
    ; walk, and its stored SCOPE ordinal must match how many globals that
    ; is (0-based). Both are structurally guaranteed by the pass driver
    ; (LOCAL_WITHOUT_SCOPE is rejected in Pass 1; the ordinal is bumped
    ; identically in both passes) -- a failure here means that guarantee
    ; broke, so the map is untrustworthy.
    lda CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    and #CASM_SYMBOL_FLAG_LOCAL
    beq mpLocalCheckDone
    lda CasmMapOwnerLen
    beq mpMapInvalid
    ; expected ordinal = CasmMapGlobalCount - 1
    lda CasmMapGlobalCountLo
    sec
    sbc #1
    cmp CasmVmmBuffer + CASM_SYMBOL_REC_SCOPE_LO
    bne mpMapInvalid
    lda CasmMapGlobalCountHi
    sbc #0
    cmp CasmVmmBuffer + CASM_SYMBOL_REC_SCOPE_HI
    bne mpMapInvalid
mpLocalCheckDone:

    jsr mapFormatRow
    ldx #<CasmMapRowBuf
    ldy #>CasmMapRowBuf
    jsr diagPrintString

    ; WP90: after rendering, if this record is a plain (global) label it
    ; becomes the owner for any @local rows that follow.
    jsr mapUpdateOwner

    inc CasmMapCursorLo
    bne mpNoCursorCarry
    inc CasmMapCursorHi
mpNoCursorCarry:
    inc CasmMapCountLo
    bne mpLoop
    inc CasmMapCountHi
    jmp mpLoop

mpDone:
    jsr mapFormatTotal
    ldx #<CasmMapRowBuf
    ldy #>CasmMapRowBuf
    jsr diagPrintString
    lda #CASM_DIAG_NONE
    clc
    rts

mpPropagate:
    rts                       ; A/C already set by symbolsReadByIndex or
                               ; mapValidateRecord

mpMapInvalid:
    lda #CASM_DIAG_SYMBOL_MAP_INVALID
    sec
    rts

; ---------------------------------------------------------------------------
; mapUpdateOwner (WP90, private)
; If the record staged in CasmVmmBuffer is a plain (global) label -- flags
; exactly CASM_SYMBOL_FLAG_DEFINED, i.e. LOCAL/CONSTANT/RESOLVED/LABEL_
; DERIVED all clear -- copy its name into CasmMapOwnerName/Len and bump
; CasmMapGlobalCount. Any other record type is a no-op.
;
; Inputs:  CasmVmmBuffer holds one validated 64-byte symbol record
; Outputs: CasmMapOwnerName/Len and CasmMapGlobalCountLo/Hi updated when the
;          record is a global label
; Clobbers: A, X
; ---------------------------------------------------------------------------
mapUpdateOwner:
    lda CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    cmp #CASM_SYMBOL_FLAG_DEFINED
    bne muoDone
    lda CasmVmmBuffer + CASM_SYMBOL_REC_NAMELEN
    sta CasmMapOwnerLen
    ldx #0
muoCopy:
    cpx CasmMapOwnerLen
    beq muoCount
    lda CasmVmmBuffer + CASM_SYMBOL_REC_NAME, x
    sta CasmMapOwnerName, x
    inx
    jmp muoCopy
muoCount:
    inc CasmMapGlobalCountLo
    bne muoDone
    inc CasmMapGlobalCountHi
muoDone:
    rts

; ---------------------------------------------------------------------------
; mapValidateRecord
; Validates the record currently staged in CasmVmmBuffer. Never inspects the
; collision-chain Next field (offsets 35-36) -- only NameLen, Flags, and the
; reserved padding are load-bearing for map output.
;
; Inputs:  CasmVmmBuffer holds one 64-byte symbol record
; Outputs: C clear on a valid record
;          C set, A = CASM_DIAG_SYMBOL_MAP_INVALID otherwise
; Clobbers: A, Y
; ---------------------------------------------------------------------------
mapValidateRecord:
    lda CasmVmmBuffer + CASM_SYMBOL_REC_NAMELEN
    beq mvrInvalid            ; 0 is not a valid length (must be 1-31)
    cmp #32
    bcs mvrInvalid            ; >=32 exceeds the 31-byte Name slot

    ; Flags must be exactly one of:
    ;   CASM_SYMBOL_FLAG_DEFINED                        - a global label
    ;   DEFINED|LOCAL                                   - a @local label (WP89)
    ;   DEFINED|CONSTANT|RESOLVED                       - a resolved named
    ;       constant with no label in its own reference chain
    ;   DEFINED|CONSTANT|RESOLVED|LABEL_DERIVED         - a resolved named
    ;       constant whose chain bottoms out at a label (WP65 Increment 8)
    ; By map-output time every constant has passed through
    ; casmResolveConstants; an unresolved one surviving here is a sweep bug
    ; and correctly still trips CASM_DIAG_SYMBOL_MAP_INVALID. An explicit
    ; allowlist, not a mask -- any other combination needs this rule
    ; revisited deliberately, not silently accepted.
    lda CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    cmp #CASM_SYMBOL_FLAG_DEFINED
    beq mvrFlagsOk
    cmp #(CASM_SYMBOL_FLAG_DEFINED | CASM_SYMBOL_FLAG_LOCAL)
    beq mvrFlagsOk
    cmp #(CASM_SYMBOL_FLAG_DEFINED | CASM_SYMBOL_FLAG_CONSTANT | CASM_SYMBOL_FLAG_RESOLVED)
    beq mvrFlagsOk
    cmp #(CASM_SYMBOL_FLAG_DEFINED | CASM_SYMBOL_FLAG_CONSTANT | CASM_SYMBOL_FLAG_RESOLVED | CASM_SYMBOL_FLAG_LABEL_DERIVED)
    beq mvrFlagsOk
    jmp mvrInvalid
mvrFlagsOk:

    ; Record-tail validation, per the layout as it actually stands after
    ; WP65/76/86:
    ;   37-43  REF_*        zero always (zeroed by casmResolveConstants once
    ;                       a deferred constant resolves; never set for a label)
    ;   44-45  DEFINED_AT   the constant's own source position -- any value
    ;                       for a CONSTANT record, zero for a label/@local
    ;                       (WP76; folded into map validation here in WP90 --
    ;                       before this, ANY constant defined past file
    ;                       offset 0 tripped SYMBOL MAP INVALID)
    ;   46-47  SCOPE        the @local's owning-scope ordinal -- any value
    ;                       for a LOCAL record, zero otherwise (WP86/89)
    ;   48-63  reserved     zero always
    ldy #37
mvrTailLoop:
    cpy #CASM_SYMBOL_REC_DEFINED_AT_OFFSET_LO   ; reached 44
    beq mvrCheckDefinedAt
    cpy #CASM_SYMBOL_REC_SCOPE_LO               ; reached 46
    beq mvrCheckScope
    cpy #CASM_SYMBOL_REC_SIZE
    beq mvrOk
    lda CasmVmmBuffer, y
    bne mvrInvalid
    iny
    jmp mvrTailLoop
mvrCheckDefinedAt:
    ; 44-45: skip the two DEFINED_AT bytes for a CONSTANT record; require
    ; them zero otherwise.
    lda CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    and #CASM_SYMBOL_FLAG_CONSTANT
    bne mvrSkipDefinedAt
    lda CasmVmmBuffer + CASM_SYMBOL_REC_DEFINED_AT_OFFSET_LO
    ora CasmVmmBuffer + CASM_SYMBOL_REC_DEFINED_AT_OFFSET_HI
    bne mvrInvalid
mvrSkipDefinedAt:
    ldy #CASM_SYMBOL_REC_SCOPE_LO
    jmp mvrTailLoop
mvrCheckScope:
    ; 46-47: skip the two SCOPE bytes for a LOCAL record; require them
    ; zero otherwise.
    lda CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    and #CASM_SYMBOL_FLAG_LOCAL
    bne mvrSkipScope
    lda CasmVmmBuffer + CASM_SYMBOL_REC_SCOPE_LO
    ora CasmVmmBuffer + CASM_SYMBOL_REC_SCOPE_HI
    bne mvrInvalid
mvrSkipScope:
    ldy #(CASM_SYMBOL_REC_SCOPE_HI + 1)         ; 48
    jmp mvrTailLoop

mvrOk:
    clc
    rts

mvrInvalid:
    lda #CASM_DIAG_SYMBOL_MAP_INVALID
    sec
    rts

; ---------------------------------------------------------------------------
; mapFormatRow
; Formats "$HHHH NAME<CR>\0" into CasmMapRowBuf from the validated record
; currently staged in CasmVmmBuffer. HHHH is the record's value, printed
; address-hi-byte-first (matching every other 16-bit field's display
; convention in this codebase).
;
; NAME is the record's own name (case-sensitive, no padding) EXCEPT for a
; @local record (CASM_SYMBOL_FLAG_LOCAL set), where it is
; "<owner>@<local>": CasmMapOwnerName (the most recent global label seen
; in the walk) followed by the local's own stored name, which already
; begins with '@'. The combined name is capped at CASM_MAP_NAME_MAX bytes
; (truncated, not wrapped) so the row fits the 40-column screen.
;
; Inputs:  CasmVmmBuffer holds one validated 64-byte symbol record;
;          CasmMapOwnerName/Len valid when the record is a @local
; Outputs: CasmMapRowBuf holds the formatted, null-terminated row
; Clobbers: A, X, Y, CasmMapNameCount
; ---------------------------------------------------------------------------
mapFormatRow:
    ldy #0
    lda #'$'
    sta CasmMapRowBuf, y
    iny

    lda CasmVmmBuffer + CASM_SYMBOL_REC_VAL_HI
    jsr mapWriteHexByte
    lda CasmVmmBuffer + CASM_SYMBOL_REC_VAL_LO
    jsr mapWriteHexByte

    lda #' '
    sta CasmMapRowBuf, y
    iny

    lda #0
    sta CasmMapNameCount

    ; @local: emit the owner-global prefix first.
    lda CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    and #CASM_SYMBOL_FLAG_LOCAL
    beq mfrOwnName
    ldx #0
mfrOwnerLoop:
    cpx CasmMapOwnerLen
    beq mfrOwnName
    lda CasmMapNameCount
    cmp #CASM_MAP_NAME_MAX
    beq mfrNameDone            ; cap hit inside the owner prefix
    lda CasmMapOwnerName, x
    sta CasmMapRowBuf, y
    iny
    inx
    inc CasmMapNameCount
    jmp mfrOwnerLoop

mfrOwnName:
    ldx #0
mfrNameLoop:
    cpx CasmVmmBuffer + CASM_SYMBOL_REC_NAMELEN
    beq mfrNameDone
    lda CasmMapNameCount
    cmp #CASM_MAP_NAME_MAX
    beq mfrNameDone
    lda CasmVmmBuffer + CASM_SYMBOL_REC_NAME, x
    sta CasmMapRowBuf, y
    iny
    inx
    inc CasmMapNameCount
    jmp mfrNameLoop
mfrNameDone:

    lda #PetCr
    sta CasmMapRowBuf, y
    iny
    lda #0
    sta CasmMapRowBuf, y
    rts

; ---------------------------------------------------------------------------
; mapWriteHexByte
; Writes two uppercase hexadecimal ASCII digits for the byte in A into
; CasmMapRowBuf at the current Y index.
;
; Inputs:  A = byte to format; Y = buffer index to write the high nibble at
; Outputs: Y advanced by 2
; Clobbers: A, X
; ---------------------------------------------------------------------------
mapWriteHexByte:
    pha
    lsr a
    lsr a
    lsr a
    lsr a
    jsr mapWriteNibble
    pla
    and #$0F
    jsr mapWriteNibble
    rts

; ---------------------------------------------------------------------------
; mapWriteNibble
; Writes one uppercase hexadecimal ASCII digit for the nibble (0-15) in A
; into CasmMapRowBuf at the current Y index.
;
; Inputs:  A = nibble (0-15); Y = buffer index
; Outputs: Y advanced by 1
; Clobbers: A
; ---------------------------------------------------------------------------
mapWriteNibble:
    cmp #10
    bcc mwnDigit
    clc
    adc #'A' - 10
    jmp mwnStore
mwnDigit:
    clc
    adc #'0'
mwnStore:
    sta CasmMapRowBuf, y
    iny
    rts

; ---------------------------------------------------------------------------
; mapFormatTotal
; Formats "NNN SYMBOLS<CR>\0" into CasmMapRowBuf from CasmMapCountLo/Hi.
; Always exactly three digits, zero-padded (CasmMapCountLo/Hi never exceeds
; CASM_SYMBOL_MAX = 512, so three digits and a 16-bit-aware hundreds
; extraction are always sufficient).
;
; Inputs:  CasmMapCountLo/Hi = total rows printed (0..512)
; Outputs: CasmMapRowBuf holds the formatted, null-terminated total line
; Clobbers: A, X, Y, CasmMapScratchLo/Hi
; ---------------------------------------------------------------------------
mapFormatTotal:
    lda CasmMapCountLo
    sta CasmMapScratchLo
    lda CasmMapCountHi
    sta CasmMapScratchHi

    ; Hundreds digit: repeated 16-bit subtraction of 100 (0-5 iterations,
    ; since the count never exceeds 512).
    ldx #0
mftHunLoop:
    lda CasmMapScratchLo
    sec
    sbc #<100
    tay
    lda CasmMapScratchHi
    sbc #>100
    bcc mftHunDone
    sta CasmMapScratchHi
    sty CasmMapScratchLo
    inx
    jmp mftHunLoop
mftHunDone:
    ; CasmMapScratchLo now holds the 0-99 remainder (Hi is always 0 here).
    txa
    clc
    adc #'0'
    ldy #0
    sta CasmMapRowBuf, y
    iny

    ; Tens digit: repeated 8-bit subtraction of 10 from the remainder.
    ldx #0
mftTenLoop:
    lda CasmMapScratchLo
    sec
    sbc #10
    bcc mftTenDone
    sta CasmMapScratchLo
    inx
    jmp mftTenLoop
mftTenDone:
    txa
    clc
    adc #'0'
    sta CasmMapRowBuf, y
    iny

    ; Ones digit: whatever remains.
    lda CasmMapScratchLo
    clc
    adc #'0'
    sta CasmMapRowBuf, y
    iny

    ldx #0
mftSuffixLoop:
    lda mapSuffixSymbols, x
    beq mftSuffixDone
    sta CasmMapRowBuf, y
    iny
    inx
    jmp mftSuffixLoop
mftSuffixDone:

    lda #PetCr
    sta CasmMapRowBuf, y
    iny
    lda #0
    sta CasmMapRowBuf, y
    rts

msgMapHeader:
    .byte "SYMBOL MAP", PetCr, 0

mapSuffixSymbols:
    .byte " SYMBOLS", 0
