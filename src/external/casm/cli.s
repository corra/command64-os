; src/external/casm/cli.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Bounded Phase 2 command-line parsing. This module reads the OS-owned
; CommandBuffer without modifying it and copies accepted filename tokens into
; fixed-capacity CASM buffers.
;
; WP34 (Phase 7) grows the single source filename into an ordered
; CASM_SOURCE_COUNT_MAX-slot array (CasmSourceNames/CasmSourceLens,
; CasmSourceCount tracks how many are populated). cliCopySource writes to a
; runtime-selected slot via a compile-time slot-address lookup table
; (cliSourceSlotLo/Hi) rather than a runtime multiply -- CASM_FILENAME_BUFFER_SIZE
; (64) does not divide evenly into 256, so a per-slot table avoids any 16-bit
; multiply-by-64 arithmetic. cliDeriveOutputName always reads slot 0, a
; compile-time-constant base, so it keeps its original direct-indexed form
; unchanged. The table is exported: source.s's sourceLoad reuses it
; unchanged to open each file in turn, rather than duplicating it.

.include "command64.inc"
.include "common.inc"

.export cliInit
.export cliParse
.export cliDeriveOutputName
.export cliDeriveListingName

.export CasmSourceNames
.export CasmSourceLens
.export CasmSourceCount
.export CasmOutputName
.export CasmOutputLen
.export CasmListingName
.export CasmListingLen
.export CasmCliOptions
.export cliSourceSlotLo
.export cliSourceSlotHi

.segment "BSS"

CasmSourceNames: .res CASM_SOURCE_COUNT_MAX * CASM_FILENAME_BUFFER_SIZE
CasmSourceLens:  .res CASM_SOURCE_COUNT_MAX
CasmSourceCount: .res 1
CasmOutputName:  .res CASM_FILENAME_BUFFER_SIZE
CasmOutputLen:   .res 1
CasmListingName: .res CASM_FILENAME_BUFFER_SIZE
CasmListingLen:  .res 1
CasmCliOptions:  .res 1

.segment "RODATA"

; Compile-time slot base addresses for cliCopySource's indirect write,
; indexed by CasmSourceCount (0..CASM_SOURCE_COUNT_MAX-1).
cliSourceSlotLo:
    .repeat CASM_SOURCE_COUNT_MAX, I
    .byte <(CasmSourceNames + (I * CASM_FILENAME_BUFFER_SIZE))
    .endrepeat
cliSourceSlotHi:
    .repeat CASM_SOURCE_COUNT_MAX, I
    .byte >(CasmSourceNames + (I * CASM_FILENAME_BUFFER_SIZE))
    .endrepeat

.segment "CODE"

; ---------------------------------------------------------------------------
; cliInit
; Initialize all persistent Phase 2 CLI state.
;
; Inputs:    none
; Outputs:   A = CASM_PARSE_OK, C clear, Z set
; Preserves: Y
; Clobbers:  A, X, processor flags
; Scratch:   none
; ---------------------------------------------------------------------------
cliInit:
    lda #0
    sta CasmSourceCount
    sta CasmOutputLen
    sta CasmCliOptions
    ldx #CASM_SOURCE_COUNT_MAX - 1
ciClearLens:
    sta CasmSourceLens, x
    dex
    bpl ciClearLens
    ; CasmSourceNames is CASM_SOURCE_COUNT_MAX * CASM_FILENAME_BUFFER_SIZE
    ; bytes (264 at the Finding D cap) -- just over an 8-bit index, so one
    ; wrapping 256-byte pass plus a short tail clears it. The tail count MUST
    ; track the real buffer size: an over-long clear here would run off the
    ; end of CasmSourceNames into CasmOutputName and the BSS beyond it.
    .assert CASM_SOURCE_COUNT_MAX * CASM_FILENAME_BUFFER_SIZE > 256, error, "CASM source-name clear: buffer no longer needs the wrapping pass"
    .assert CASM_SOURCE_COUNT_MAX * CASM_FILENAME_BUFFER_SIZE <= 512, error, "CASM source-name clear: buffer no longer fits one wrapping pass plus an 8-bit tail"
    ldx #0
ciClearNames:
    sta CasmSourceNames, x
    inx
    bne ciClearNames
    ldx #(CASM_SOURCE_COUNT_MAX * CASM_FILENAME_BUFFER_SIZE) - 256 - 1
ciClearNamesTail:
    sta CasmSourceNames + 256, x
    dex
    bpl ciClearNamesTail
    ldx #CASM_FILENAME_BUFFER_SIZE - 1
ciClearOutput:
    sta CasmOutputName, x
    dex
    bpl ciClearOutput
    lda #CASM_PARSE_OK
    clc
    rts

; ---------------------------------------------------------------------------
; cliParse
; Parse one source token and `/O:<file>`, `/S`, `/M`, and `/L` options from
; CommandBuffer. Options may precede or follow the source. The command buffer
; is never modified.
;
; Inputs:    ParsePos identifies the external command's first byte
; Outputs:   C clear, A = CASM_PARSE_OK on success
;            C set, A = CASM_DIAG_* on failure
; Preserves: none
; Clobbers:  A, X, Y, processor flags
; Scratch:   CasmCliScratch
; ---------------------------------------------------------------------------
cliParse:
    ldy ParsePos
    cpy #CASM_COMMAND_BUFFER_SIZE
    bcs cpSourceRequired

    ; External dispatch preserves ParsePos at the command's first byte. Skip
    ; that token; accepting a position on its trailing space is harmless.
    lda CommandBuffer, y
    beq cpSourceRequired
    cmp #CASM_PETSCII_SPACE
    beq cpNextToken
cpSkipCommand:
    iny
    cpy #CASM_COMMAND_BUFFER_SIZE
    bcs cpSourceRequired
    lda CommandBuffer, y
    beq cpSourceRequired
    cmp #CASM_PETSCII_SPACE
    bne cpSkipCommand

cpNextToken:
    jsr cliSkipSpaces
    bcs cpSourceRequired
    lda CommandBuffer, y
    beq cpFinish
    cmp #CASM_PETSCII_SLASH
    beq cpOption
    jsr cliCopySource
    bcs cpReturn
    jmp cpNextToken

cpOption:
    jsr cliParseOption
    bcs cpReturn
    jmp cpNextToken

cpFinish:
    lda CasmSourceCount
    beq cpSourceRequired
    lda #CASM_PARSE_OK
    clc
cpReturn:
    rts

cpSourceRequired:
    lda #CASM_DIAG_SOURCE_REQUIRED
    sec
    rts

; ---------------------------------------------------------------------------
; cliSkipSpaces (private)
; Advance across spaces without crossing the CommandBuffer allocation.
;
; Inputs:    Y = current CommandBuffer index
; Outputs:   C clear with Y at a non-space byte; C set at the hard bound
; Preserves: X
; Clobbers:  A, Y, processor flags
; Scratch:   none
; ---------------------------------------------------------------------------
cliSkipSpaces:
    cpy #CASM_COMMAND_BUFFER_SIZE
    bcs cssBound
    lda CommandBuffer, y
    cmp #CASM_PETSCII_SPACE
    bne cssDone
    iny
    jmp cliSkipSpaces
cssDone:
    clc
    rts
cssBound:
    sec
    rts

; ---------------------------------------------------------------------------
; cliCopySource (private)
; Copy one non-empty positional token into the next free
; CasmSourceNames slot (CasmSourceCount, 0-based), via the compile-time
; cliSourceSlotLo/Hi lookup table -- CASM_FILENAME_BUFFER_SIZE (64) does not
; divide evenly into 256, so the slot's base address is looked up rather
; than computed with a runtime multiply.
;
; Inputs:    Y = first source-token byte
; Outputs:   C clear with Y at delimiter; C set with A = CASM_DIAG_* on error
; Preserves: none
; Clobbers:  A, X, Y, processor flags, CasmPtr0Lo/Hi
; Scratch:   CasmPtr0Lo/Hi (destination slot pointer, advanced one byte at a
;            time rather than indexed -- Y is the established CommandBuffer
;            cursor throughout cli.s's call chain and cannot double as the
;            indirect-store index too, so the pointer itself walks the
;            destination instead); CasmCliDestIndex (stashes Y across the
;            one instant a byte is stored, since (zp),Y addressing has no
;            index-register alternative -- both free here: cliParse's call
;            chain makes no OS_API call and no other CASM module has
;            started running yet)
; ---------------------------------------------------------------------------
cliCopySource:
    lda CasmSourceCount
    cmp #CASM_SOURCE_COUNT_MAX
    bcs ccsExtra
    tax
    lda cliSourceSlotLo, x
    sta CasmPtr0Lo
    lda cliSourceSlotHi, x
    sta CasmPtr0Hi
    ldx #0                    ; X = destination length counter (0..63)
ccsLoop:
    cpy #CASM_COMMAND_BUFFER_SIZE
    bcs ccsTooLong
    lda CommandBuffer, y
    beq ccsDone
    cmp #CASM_PETSCII_SPACE
    beq ccsDone
    cpx #CASM_FILENAME_MAX
    bcs ccsTooLong
    ; A already holds the byte to copy. Stash Y (the CommandBuffer cursor)
    ; so (CasmPtr0Lo),Y can use Y as the destination index for this one
    ; instruction, then restore it; the pointer itself advances by one byte
    ; afterward rather than being indexed, since Y cannot represent both
    ; positions at once.
    sty CasmCliDestIndex
    ldy #0
    sta (CasmPtr0Lo), y
    inc CasmPtr0Lo
    bne ccsPtrDone
    inc CasmPtr0Hi
ccsPtrDone:
    ldy CasmCliDestIndex
    inx
    iny
    jmp ccsLoop
ccsDone:
    ; Y currently holds the CommandBuffer delimiter position, which the
    ; caller requires preserved on return -- stash it across the
    ; null-terminator and length-array writes below.
    sty CasmCliDestIndex
    lda #0
    ldy #0
    sta (CasmPtr0Lo), y
    ldy CasmSourceCount
    txa
    sta CasmSourceLens, y
    inc CasmSourceCount
    ldy CasmCliDestIndex
    clc
    lda #CASM_PARSE_OK
    rts
ccsExtra:
    lda #CASM_DIAG_EXTRA_SOURCE
    sec
    rts
ccsTooLong:
    lda #CASM_DIAG_FILENAME_TOO_LONG
    sec
    rts

; ---------------------------------------------------------------------------
; cliParseOption (private)
; Parse a complete slash-prefixed option token.
;
; Inputs:    Y = slash byte
; Outputs:   C clear with Y at delimiter; C set with A = CASM_DIAG_* on error
; Preserves: none
; Clobbers:  A, X, Y, processor flags
; Scratch:   none
; ---------------------------------------------------------------------------
cliParseOption:
    iny
    cpy #CASM_COMMAND_BUFFER_SIZE
    bcs cpoUnknown
    lda CommandBuffer, y
    ; Clear PETSCII's case and high bits for option comparison only. Filename
    ; bytes never pass through this normalization.
    and #$5F
    cmp #CASM_PETSCII_O
    beq cpoOutput
    cmp #CASM_PETSCII_S
    beq cpoStatic
    cmp #CASM_PETSCII_M
    beq cpoMap
    cmp #CASM_PETSCII_L
    beq cpoList
cpoUnknown:
    lda #CASM_DIAG_UNKNOWN_OPTION
    sec
    rts

cpoStatic:
    lda #CASM_OPT_STATIC
    bne cpoFlag
cpoMap:
    lda #CASM_OPT_MAP
    bne cpoFlag
cpoList:
    lda #CASM_OPT_LIST
cpoFlag:
    sta CasmCliScratch
    and CasmCliOptions
    bne cpoDuplicate
    iny
    jsr cliRequireTokenEnd
    bcs cpoUnknown
    lda CasmCliOptions
    ora CasmCliScratch
    sta CasmCliOptions
    lda #CASM_PARSE_OK
    clc
    rts

cpoOutput:
    lda CasmCliOptions
    and #CASM_OPT_OUTPUT
    bne cpoDuplicate
    iny
    cpy #CASM_COMMAND_BUFFER_SIZE
    bcs cpoMalformedOutput
    lda CommandBuffer, y
    cmp #CASM_PETSCII_COLON
    bne cpoMalformedOutput
    iny
    ldx #0
cpoOutputLoop:
    cpy #CASM_COMMAND_BUFFER_SIZE
    bcs cpoOutputTooLong
    lda CommandBuffer, y
    beq cpoOutputDone
    cmp #CASM_PETSCII_SPACE
    beq cpoOutputDone
    cpx #CASM_FILENAME_MAX
    bcs cpoOutputTooLong
    sta CasmOutputName, x
    inx
    iny
    jmp cpoOutputLoop
cpoOutputDone:
    cpx #0
    beq cpoMalformedOutput
    lda #0
    sta CasmOutputName, x
    stx CasmOutputLen
    lda CasmCliOptions
    ora #CASM_OPT_OUTPUT
    sta CasmCliOptions
    lda #CASM_PARSE_OK
    clc
    rts

cpoDuplicate:
    lda #CASM_DIAG_DUPLICATE_OPTION
    sec
    rts
cpoMalformedOutput:
    lda #CASM_DIAG_MALFORMED_OUTPUT_OPTION
    sec
    rts
cpoOutputTooLong:
    lda #CASM_DIAG_FILENAME_TOO_LONG
    sec
    rts

; ---------------------------------------------------------------------------
; cliRequireTokenEnd (private)
; Require a flag option to end after its one-letter name.
;
; Inputs:    Y = byte following option letter
; Outputs:   C clear for null/space delimiter; C set otherwise or at bound
; Preserves: X, Y
; Clobbers:  A, processor flags
; Scratch:   none
; ---------------------------------------------------------------------------
cliRequireTokenEnd:
    cpy #CASM_COMMAND_BUFFER_SIZE
    bcs crteBad
    lda CommandBuffer, y
    beq crteGood
    cmp #CASM_PETSCII_SPACE
    bne crteBad
crteGood:
    clc
    rts
crteBad:
    sec
    rts

; ---------------------------------------------------------------------------
; cliDeriveOutputName
; Preserve an explicit `/O` filename, or derive `<source-base>.PRG` from the
; source filename. Only a dot after the last device-prefix colon is treated as
; an extension separator.
;
; Inputs:    parsed CasmSourceNames[0]/CasmSourceLens[0]/CasmSourceCount/
;            CasmCliOptions -- always derives from the first source slot
;            (WP34), matching the master plan's "otherwise CASM derives the
;            name from the first source file" CLI grammar text
; Outputs:   C clear, A = CASM_PARSE_OK, bounded CasmOutputName/CasmOutputLen
;            C set, A = CASM_DIAG_* on failure
; Preserves: Y
; Clobbers:  A, X, processor flags
; Scratch:   CasmCliScratch (last extension-dot index or $FF)
; ---------------------------------------------------------------------------
cliDeriveOutputName:
    lda CasmCliOptions
    and #CASM_OPT_OUTPUT
    beq cdonDerive
    lda CasmOutputLen
    beq cdonMalformed
    lda #CASM_PARSE_OK
    clc
    rts

cdonDerive:
    lda CasmSourceCount
    beq cdonSourceRequired
    lda #$FF
    sta CasmCliScratch
    ldx #0
cdonCopyLoop:
    cpx CasmSourceLens + 0
    beq cdonCopied
    lda CasmSourceNames + 0, x
    sta CasmOutputName, x
    cmp #CASM_PETSCII_COLON
    bne cdonCheckDot
    lda #$FF
    sta CasmCliScratch
    jmp cdonCopyNext
cdonCheckDot:
    cmp #CASM_PETSCII_DOT
    bne cdonCopyNext
    stx CasmCliScratch
cdonCopyNext:
    inx
    jmp cdonCopyLoop

cdonCopied:
    lda CasmCliScratch
    cmp #$FF
    beq cdonAppendExtension
    tax
    inx
    cpx #CASM_FILENAME_MAX - 2
    bcs cdonTooLong
    jmp cdonWritePrg

cdonAppendExtension:
    ldx CasmSourceLens + 0
    cpx #CASM_FILENAME_MAX - 3
    bcs cdonTooLong
    lda #CASM_PETSCII_DOT
    sta CasmOutputName, x
    inx

cdonWritePrg:
    lda #CASM_PETSCII_P
    sta CasmOutputName, x
    inx
    lda #CASM_PETSCII_R
    sta CasmOutputName, x
    inx
    lda #CASM_PETSCII_G
    sta CasmOutputName, x
    inx
    lda #0
    sta CasmOutputName, x
    stx CasmOutputLen
    lda #CASM_PARSE_OK
    clc
    rts

cdonMalformed:
    lda #CASM_DIAG_MALFORMED_OUTPUT_OPTION
    sec
    rts
cdonSourceRequired:
    lda #CASM_DIAG_SOURCE_REQUIRED
    sec
    rts
cdonTooLong:
    lda #CASM_DIAG_FILENAME_TOO_LONG
    sec
    rts

; ---------------------------------------------------------------------------
; cliDeriveListingName
; Derive `<output-base>.LST` from the already-derived CasmOutputName, mirroring
; cliDeriveOutputName's colon/dot scan: only a dot after the last device-prefix
; colon is treated as an extension separator, and the suffix is replaced (or
; appended) accordingly. WP53 owns no `/L` filename option, so there is no
; explicit-name branch -- the listing name always derives from the final
; output name. Must run after cliDeriveOutputName has succeeded.
;
; Inputs:    CasmOutputName/CasmOutputLen (already derived/validated)
; Outputs:   C clear, A = CASM_PARSE_OK, bounded CasmListingName/CasmListingLen
;            C set, A = CASM_DIAG_* on failure (malformed, too long, or a
;            byte-identical collision with CasmOutputName, checked before any
;            listing resource is touched)
; Preserves: Y
; Clobbers:  A, X, processor flags
; Scratch:   CasmCliScratch (last extension-dot index or $FF)
; ---------------------------------------------------------------------------
cliDeriveListingName:
    lda CasmOutputLen
    beq cdlnMalformed
    lda #$FF
    sta CasmCliScratch
    ldx #0
cdlnCopyLoop:
    cpx CasmOutputLen
    beq cdlnCopied
    lda CasmOutputName, x
    sta CasmListingName, x
    cmp #CASM_PETSCII_COLON
    bne cdlnCheckDot
    lda #$FF
    sta CasmCliScratch
    jmp cdlnCopyNext
cdlnCheckDot:
    cmp #CASM_PETSCII_DOT
    bne cdlnCopyNext
    stx CasmCliScratch
cdlnCopyNext:
    inx
    jmp cdlnCopyLoop

cdlnCopied:
    lda CasmCliScratch
    cmp #$FF
    beq cdlnAppendExtension
    tax
    inx
    cpx #CASM_FILENAME_MAX - 2
    bcs cdlnTooLong
    jmp cdlnWriteLst

cdlnAppendExtension:
    ldx CasmOutputLen
    cpx #CASM_FILENAME_MAX - 3
    bcs cdlnTooLong
    lda #CASM_PETSCII_DOT
    sta CasmListingName, x
    inx

cdlnWriteLst:
    lda #CASM_PETSCII_L
    sta CasmListingName, x
    inx
    lda #CASM_PETSCII_S
    sta CasmListingName, x
    inx
    lda #CASM_PETSCII_T
    sta CasmListingName, x
    inx
    lda #0
    sta CasmListingName, x
    stx CasmListingLen

    ; Reject a byte-identical collision with the committed output name before
    ; any listing resource (file, handle) is touched.
    lda CasmListingLen
    cmp CasmOutputLen
    bne cdlnOk
    ldx #0
cdlnCompareLoop:
    cpx CasmListingLen
    beq cdlnCollision
    lda CasmListingName, x
    cmp CasmOutputName, x
    bne cdlnOk
    inx
    jmp cdlnCompareLoop

cdlnCollision:
    lda #CASM_DIAG_LISTING_NAME_COLLISION
    sec
    rts

cdlnOk:
    lda #CASM_PARSE_OK
    clc
    rts

cdlnMalformed:
    lda #CASM_DIAG_MALFORMED_OUTPUT_OPTION
    sec
    rts
cdlnTooLong:
    lda #CASM_DIAG_FILENAME_TOO_LONG
    sec
    rts
