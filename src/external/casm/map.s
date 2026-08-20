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

.segment "BSS"

CasmMapCursorLo:    .res 1   ; symbolsReadByIndex iteration cursor (Lo/Hi)
CasmMapCursorHi:    .res 1
CasmMapCountLo:     .res 1   ; rows printed so far, 0..CASM_SYMBOL_MAX (Lo/Hi)
CasmMapCountHi:     .res 1
CasmMapScratchLo:   .res 1   ; mapFormatTotal's private decimal-division scratch
CasmMapScratchHi:   .res 1
CasmMapRowBuf:      .res 40  ; one formatted row; max content is 39 bytes
                             ; ("$HHHH " + 31-byte name + CR + null)

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

    jsr mapFormatRow
    ldx #<CasmMapRowBuf
    ldy #>CasmMapRowBuf
    jsr diagPrintString

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

    ; Flags must be exactly CASM_SYMBOL_FLAG_DEFINED (a label),
    ; DEFINED|CONSTANT|RESOLVED (a fully-resolved named constant with no
    ; label anywhere in its own reference chain), or
    ; DEFINED|CONSTANT|RESOLVED|LABEL_DERIVED (a fully-resolved named
    ; constant whose chain bottoms out at a label -- WP65's Increment 8).
    ; By the time Pass 2/map output runs, every constant has already
    ; passed through casmResolveConstants; an unresolved constant
    ; surviving to here is a bug in that sweep, not a valid row, and
    ; correctly still trips CASM_DIAG_SYMBOL_MAP_INVALID. An explicit
    ; allowlist, not a mask -- any other combination would need this rule
    ; revisited deliberately, not silently accepted.
    lda CasmVmmBuffer + CASM_SYMBOL_REC_FLAGS
    cmp #CASM_SYMBOL_FLAG_DEFINED
    beq mvrFlagsOk
    cmp #(CASM_SYMBOL_FLAG_DEFINED | CASM_SYMBOL_FLAG_CONSTANT | CASM_SYMBOL_FLAG_RESOLVED)
    beq mvrFlagsOk
    cmp #(CASM_SYMBOL_FLAG_DEFINED | CASM_SYMBOL_FLAG_CONSTANT | CASM_SYMBOL_FLAG_RESOLVED | CASM_SYMBOL_FLAG_LABEL_DERIVED)
    beq mvrFlagsOk
    jmp mvrInvalid
mvrFlagsOk:

    ; Reserved padding (offsets 37-63) must be zero-filled, per symbolsInsert.
    ldy #37
mvrResLoop:
    cpy #CASM_SYMBOL_REC_SIZE
    beq mvrOk
    lda CasmVmmBuffer, y
    bne mvrInvalid
    iny
    jmp mvrResLoop

mvrOk:
    clc
    rts

mvrInvalid:
    lda #CASM_DIAG_SYMBOL_MAP_INVALID
    sec
    rts

; ---------------------------------------------------------------------------
; mapFormatRow
; Formats "$HHHH LABEL<CR>\0" into CasmMapRowBuf from the validated record
; currently staged in CasmVmmBuffer. HHHH is the record's value, printed
; address-hi-byte-first (matching every other 16-bit field's display
; convention in this codebase). LABEL is exactly NameLen bytes, copied
; case-sensitively with no truncation or padding.
;
; Inputs:  CasmVmmBuffer holds one validated 64-byte symbol record
; Outputs: CasmMapRowBuf holds the formatted, null-terminated row
; Clobbers: A, X, Y
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

    ldx #0
mfrNameLoop:
    cpx CasmVmmBuffer + CASM_SYMBOL_REC_NAMELEN
    beq mfrNameDone
    lda CasmVmmBuffer + CASM_SYMBOL_REC_NAME, x
    sta CasmMapRowBuf, y
    iny
    inx
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
