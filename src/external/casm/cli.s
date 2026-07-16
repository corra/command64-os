; src/external/casm/cli.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Bounded Phase 2 command-line parsing. This module reads the OS-owned
; CommandBuffer without modifying it and copies accepted filename tokens into
; fixed-capacity CASM buffers.

.include "command64.inc"
.include "common.inc"

.export cliInit
.export cliParse
.export cliDeriveOutputName

.export CasmSourceName
.export CasmOutputName
.export CasmSourceLen
.export CasmOutputLen
.export CasmCliOptions

.segment "BSS"

CasmSourceName: .res CASM_FILENAME_BUFFER_SIZE
CasmOutputName: .res CASM_FILENAME_BUFFER_SIZE
CasmSourceLen:  .res 1
CasmOutputLen:  .res 1
CasmCliOptions: .res 1

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
    sta CasmSourceLen
    sta CasmOutputLen
    sta CasmCliOptions
    ldx #CASM_FILENAME_BUFFER_SIZE - 1
ciClearNames:
    sta CasmSourceName, x
    sta CasmOutputName, x
    dex
    bpl ciClearNames
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
    lda CasmSourceLen
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
; Copy one non-empty positional token into CasmSourceName.
;
; Inputs:    Y = first source-token byte
; Outputs:   C clear with Y at delimiter; C set with A = CASM_DIAG_* on error
; Preserves: none
; Clobbers:  A, X, Y, processor flags
; Scratch:   none
; ---------------------------------------------------------------------------
cliCopySource:
    lda CasmSourceLen
    bne ccsExtra
    ldx #0
ccsLoop:
    cpy #CASM_COMMAND_BUFFER_SIZE
    bcs ccsTooLong
    lda CommandBuffer, y
    beq ccsDone
    cmp #CASM_PETSCII_SPACE
    beq ccsDone
    cpx #CASM_FILENAME_MAX
    bcs ccsTooLong
    sta CasmSourceName, x
    inx
    iny
    jmp ccsLoop
ccsDone:
    lda #0
    sta CasmSourceName, x
    stx CasmSourceLen
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
; Inputs:    parsed CasmSourceName/CasmSourceLen/CasmCliOptions
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
    lda CasmSourceLen
    beq cdonSourceRequired
    lda #$FF
    sta CasmCliScratch
    ldx #0
cdonCopyLoop:
    cpx CasmSourceLen
    beq cdonCopied
    lda CasmSourceName, x
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
    ldx CasmSourceLen
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
