; src/external/casm/diagnostics.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Allocation-free CASM diagnostics. These routines remain safe while central
; resource cleanup is active and never acquire file or VMM resources.

.include "command64.inc"
.include "common.inc"

.export diagPrintString
.export diagPrintFatal
.export diagPrintPhase2Ready
.export diagDumpToken

.import CasmTokenRecord
.import CasmTokenText

.segment "CODE"

; ---------------------------------------------------------------------------
; diagPrintString
; Print one null-terminated PETSCII string through the Command 64 API.
;
; Inputs:  X = string address low byte
;          Y = string address high byte
; Outputs: none
; Flags:   undefined after OS_API
; Clobbers: A and any registers documented as volatile by DOS_PRINT_STR;
;           callers must treat X and Y as volatile across the OS call
; ---------------------------------------------------------------------------
diagPrintString:
    lda #DOS_PRINT_STR
    jsr OS_API
    rts

; ---------------------------------------------------------------------------
; diagPrintFatal
; Select and print the stable message for a fatal diagnostic identifier. Phase
; 2 diagnostic values $01-$13 are contiguous and index bounded parallel tables;
; zero, out-of-range, and $FF values use the unknown fallback.
;
; Inputs:  A = CASM_DIAG_* identifier
; Outputs: none
; Flags:   undefined after diagPrintString
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
diagPrintFatal:
    cmp #CASM_DIAG_INIT_FAILED
    bcc dpfUnknown
    cmp #CASM_DIAG_PHASE4_LAST + 1
    bcs dpfUnknown
    sec
    sbc #CASM_DIAG_INIT_FAILED
    tax
    lda diagMessageLo, x
    pha
    lda diagMessageHi, x
    tay
    pla
    tax
    jmp diagPrintString
dpfUnknown:
    ldx #<msgUnknown
    ldy #>msgUnknown
    jmp diagPrintString

; ---------------------------------------------------------------------------
; diagPrintPhase2Ready
; Print the stable successful-input-validation message.
;
; Inputs:  none
; Outputs: none
; Flags:   undefined after diagPrintString
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
diagPrintPhase2Ready:
    ldx #<msgPhase2Ready
    ldy #>msgPhase2Ready
    jmp diagPrintString

; ---------------------------------------------------------------------------
; printChar
; Prints a single character in A using DOS_PRINT_CHAR.
; ---------------------------------------------------------------------------
printChar:
    pha
    tax
    lda #DOS_PRINT_CHAR
    jsr OS_API
    pla
    rts

; ---------------------------------------------------------------------------
; printDec16
; Print a 16-bit decimal number in CasmValue0Lo/Hi to screen.
; Clobbers: A, X, Y
; ---------------------------------------------------------------------------
printDec16:
    lda #0
    sta CasmLexerScratch0 ; zero suppression flag (0 = suppressing, 1 = printing)
    
    ; 10000s digit
    ldy #0
@loop10k:
    lda CasmValue0Lo
    sec
    sbc #<10000
    tax
    lda CasmValue0Hi
    sbc #>10000
    bcc @done10k
    stx CasmValue0Lo
    sta CasmValue0Hi
    iny
    jmp @loop10k
@done10k:
    tya
    beq @skip10k
    jsr @printDigit
@skip10k:

    ; 1000s digit
    ldy #0
@loop1k:
    lda CasmValue0Lo
    sec
    sbc #<1000
    tax
    lda CasmValue0Hi
    sbc #>1000
    bcc @done1k
    stx CasmValue0Lo
    sta CasmValue0Hi
    iny
    jmp @loop1k
@done1k:
    tya
    bne @print1k
    lda CasmLexerScratch0
    beq @skip1k
@print1k:
    tya
    jsr @printDigit
@skip1k:

    ; 100s digit
    ldy #0
@loop100:
    lda CasmValue0Lo
    sec
    sbc #100
    bcc @done100
    sta CasmValue0Lo
    iny
    jmp @loop100
@done100:
    tya
    bne @print100
    lda CasmLexerScratch0
    beq @skip100
@print100:
    tya
    jsr @printDigit
@skip100:

    ; 10s digit
    ldy #0
@loop10:
    lda CasmValue0Lo
    sec
    sbc #10
    bcc @done10
    sta CasmValue0Lo
    iny
    jmp @loop10
@done10:
    tya
    bne @print10
    lda CasmLexerScratch0
    beq @skip10
@print10:
    tya
    jsr @printDigit
@skip10:

    ; 1s digit (always printed)
    lda CasmValue0Lo
    clc
    adc #$30
    jsr printChar
    rts

@printDigit:
    pha
    lda #1
    sta CasmLexerScratch0 ; enable printing for subsequent digits
    pla
    clc
    adc #$30
    jsr printChar
    rts

; ---------------------------------------------------------------------------
; diagDumpToken
; Format and print the current token to screen.
; ---------------------------------------------------------------------------
diagDumpToken:
    ; Print type name:
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_COUNT
    bcc @okType
    ldx #<msgUnknownTok
    ldy #>msgUnknownTok
    jsr diagPrintString
    jmp @printLoc
@okType:
    tax
    lda tokNamesLo, x
    pha
    lda tokNamesHi, x
    tay
    pla
    tax
    jsr diagPrintString

    ; Print subtype if applicable (DIRECTIVE, REGISTER, NUMBER, MNEMONIC)
    lda CasmTokenRecord + CASM_TOKEN_REC_TYPE
    cmp #CASM_TOKEN_DIRECTIVE
    bne @notDir
    ; Directive subtype
    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    cmp #CASM_DIRECTIVE_COUNT
    bcc @okDir
    ldx #<msgSubUnknown
    ldy #>msgSubUnknown
    jsr diagPrintString
    jmp @printText
@okDir:
    tax
    lda dirSubtypeNamesLo, x
    pha
    lda dirSubtypeNamesHi, x
    tay
    pla
    tax
    jsr diagPrintString
    jmp @printText

@notDir:
    cmp #CASM_TOKEN_REGISTER
    bne @notReg
    ; Register subtype
    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    cmp #CASM_REGISTER_COUNT
    bcc @okReg
    ldx #<msgSubUnknown
    ldy #>msgSubUnknown
    jsr diagPrintString
    jmp @printText
@okReg:
    tax
    lda regSubtypeNamesLo, x
    pha
    lda regSubtypeNamesHi, x
    tay
    pla
    tax
    jsr diagPrintString
    jmp @printText

@notReg:
    cmp #CASM_TOKEN_NUMBER
    bne @notNum
    ; Number subtype
    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    cmp #CASM_NUMBER_COUNT
    bcc @okNum
    ldx #<msgSubUnknown
    ldy #>msgSubUnknown
    jsr diagPrintString
    jmp @printText
@okNum:
    tax
    lda numSubtypeNamesLo, x
    pha
    lda numSubtypeNamesHi, x
    tay
    pla
    tax
    jsr diagPrintString
    jmp @printText

@notNum:
    cmp #CASM_TOKEN_MNEMONIC
    bne @printText
    ; Mnemonic subtype: print " (" followed by index, followed by ")"
    ldx #<msgMnemPrefix
    ldy #>msgMnemPrefix
    jsr diagPrintString
    lda CasmTokenRecord + CASM_TOKEN_REC_SUBTYPE
    sta CasmValue0Lo
    lda #0
    sta CasmValue0Hi
    jsr printDec16
    ldx #<msgMnemSuffix
    ldy #>msgMnemSuffix
    jsr diagPrintString

@printText:
    ; Print text: space then "[" then CasmTokenText then "]"
    lda CasmTokenRecord + CASM_TOKEN_REC_LENGTH
    beq @printLoc
    ldx #<msgTextPrefix
    ldy #>msgTextPrefix
    jsr diagPrintString
    ldx #<CasmTokenText
    ldy #>CasmTokenText
    jsr diagPrintString
    ldx #<msgTextSuffix
    ldy #>msgTextSuffix
    jsr diagPrintString

@printLoc:
    ; Print location: " L:<line> C:<col>"
    ldx #<msgLocLinePrefix
    ldy #>msgLocLinePrefix
    jsr diagPrintString
    
    lda CasmTokenRecord + CASM_TOKEN_REC_LINE_LO
    sta CasmValue0Lo
    lda CasmTokenRecord + CASM_TOKEN_REC_LINE_HI
    sta CasmValue0Hi
    jsr printDec16

    ldx #<msgLocColPrefix
    ldy #>msgLocColPrefix
    jsr diagPrintString

    lda CasmTokenRecord + CASM_TOKEN_REC_COLUMN
    sta CasmValue0Lo
    lda #0
    sta CasmValue0Hi
    jsr printDec16

    ; Print Carriage Return
    ldx #<msgCR
    ldy #>msgCR
    jsr diagPrintString
    rts

.segment "RODATA"

diagMessageLo:
    .byte <msgInitFailed
    .byte <msgRegistryFull
    .byte <msgCleanupFailed
    .byte <msgSourceRequired
    .byte <msgExtraSource
    .byte <msgMalformedOutput
    .byte <msgDuplicateOption
    .byte <msgUnknownOption
    .byte <msgFilenameTooLong
    .byte <msgNotImplemented
    .byte <msgInputOpenFailed
    .byte <msgInputReadFailed
    .byte <msgInputCloseFailed
    .byte <msgOutputCreateFailed
    .byte <msgOutputWriteFailed
    .byte <msgOutputCloseFailed
    .byte <msgOutputDeleteFailed
    .byte <msgOutputShortWrite
    .byte <msgStreamStateFailed
    .byte <msgSourceRewindFailed
    .byte <msgSourceOffsetOverflow
    .byte <msgSourceLocationOverflow
    .byte <msgSourceLineTooLong
    .byte <msgTokenTooLong
    .byte <msgInvalidSourceByte
    .byte <msgMalformedNumber
    .byte <msgLexerStateFailed
    .byte <msgSyntaxError
    .byte <msgExpectedNewline
    .byte <msgOperandOutOfRange
diagMessageLoEnd:

diagMessageHi:
    .byte >msgInitFailed
    .byte >msgRegistryFull
    .byte >msgCleanupFailed
    .byte >msgSourceRequired
    .byte >msgExtraSource
    .byte >msgMalformedOutput
    .byte >msgDuplicateOption
    .byte >msgUnknownOption
    .byte >msgFilenameTooLong
    .byte >msgNotImplemented
    .byte >msgInputOpenFailed
    .byte >msgInputReadFailed
    .byte >msgInputCloseFailed
    .byte >msgOutputCreateFailed
    .byte >msgOutputWriteFailed
    .byte >msgOutputCloseFailed
    .byte >msgOutputDeleteFailed
    .byte >msgOutputShortWrite
    .byte >msgStreamStateFailed
    .byte >msgSourceRewindFailed
    .byte >msgSourceOffsetOverflow
    .byte >msgSourceLocationOverflow
    .byte >msgSourceLineTooLong
    .byte >msgTokenTooLong
    .byte >msgInvalidSourceByte
    .byte >msgMalformedNumber
    .byte >msgLexerStateFailed
    .byte >msgSyntaxError
    .byte >msgExpectedNewline
    .byte >msgOperandOutOfRange
diagMessageHiEnd:

.assert diagMessageLoEnd - diagMessageLo = CASM_DIAG_PHASE4_LAST, error, "CASM diagnostic low table is incomplete"
.assert diagMessageHiEnd - diagMessageHi = CASM_DIAG_PHASE4_LAST, error, "CASM diagnostic high table is incomplete"

msgInitFailed:
    .byte "CASM: INITIALIZATION FAILED", PetCr, 0
msgRegistryFull:
    .byte "CASM: RESOURCE REGISTRY FULL", PetCr, 0
msgCleanupFailed:
    .byte "CASM: RESOURCE CLEANUP FAILED", PetCr, 0
msgSourceRequired:
    .byte "CASM: SOURCE FILE REQUIRED", PetCr, 0
msgExtraSource:
    .byte "CASM: TOO MANY SOURCE FILES", PetCr, 0
msgMalformedOutput:
    .byte "CASM: MALFORMED /O OPTION", PetCr, 0
msgDuplicateOption:
    .byte "CASM: DUPLICATE OPTION", PetCr, 0
msgUnknownOption:
    .byte "CASM: UNKNOWN OPTION", PetCr, 0
msgFilenameTooLong:
    .byte "CASM: FILENAME TOO LONG", PetCr, 0
msgNotImplemented:
    .byte "CASM: FEATURE NOT IMPLEMENTED", PetCr, 0
msgInputOpenFailed:
    .byte "CASM: CANNOT OPEN INPUT", PetCr, 0
msgInputReadFailed:
    .byte "CASM: INPUT READ FAILED", PetCr, 0
msgInputCloseFailed:
    .byte "CASM: INPUT CLOSE FAILED", PetCr, 0
msgOutputCreateFailed:
    .byte "CASM: CANNOT CREATE OUTPUT", PetCr, 0
msgOutputWriteFailed:
    .byte "CASM: OUTPUT WRITE FAILED", PetCr, 0
msgOutputCloseFailed:
    .byte "CASM: OUTPUT CLOSE FAILED", PetCr, 0
msgOutputDeleteFailed:
    .byte "CASM: OUTPUT DELETE FAILED", PetCr, 0
msgOutputShortWrite:
    .byte "CASM: SHORT OUTPUT WRITE", PetCr, 0
msgStreamStateFailed:
    .byte "CASM: INVALID STREAM STATE", PetCr, 0
msgSourceRewindFailed:
    .byte "CASM: SOURCE REWIND FAILED", PetCr, 0
msgSourceOffsetOverflow:
    .byte "CASM: SOURCE OFFSET OVERFLOW", PetCr, 0
msgSourceLocationOverflow:
    .byte "CASM: SOURCE LOCATION OVERFLOW", PetCr, 0
msgSourceLineTooLong:
    .byte "CASM: SOURCE LINE TOO LONG", PetCr, 0
msgTokenTooLong:
    .byte "CASM: TOKEN TOO LONG", PetCr, 0
msgInvalidSourceByte:
    .byte "CASM: INVALID SOURCE BYTE", PetCr, 0
msgMalformedNumber:
    .byte "CASM: MALFORMED NUMBER", PetCr, 0
msgLexerStateFailed:
    .byte "CASM: INVALID LEXER STATE", PetCr, 0
msgSyntaxError:
    .byte "CASM: SYNTAX ERROR", PetCr, 0
msgExpectedNewline:
    .byte "CASM: EXPECTED NEWLINE", PetCr, 0
msgOperandOutOfRange:
    .byte "CASM: OPERAND OUT OF RANGE", PetCr, 0
msgUnknown:
    .byte "CASM: INTERNAL ERROR", PetCr, 0
msgPhase2Ready:
    .byte "CASM: INPUT VALIDATED", PetCr, 0

; Token dump tables and strings
tokNamesLo:
    .byte <tokNameEof, <tokNameNewline, <tokNameId, <tokNameMnem
    .byte <tokNameDir, <tokNameReg, <tokNameNum, <tokNameComma
    .byte <tokNameColon, <tokNameHash, <tokNameLparen, <tokNameRparen
    .byte <tokNamePlus, <tokNameMinus, <tokNameLess, <tokNameGreater
tokNamesHi:
    .byte >tokNameEof, >tokNameNewline, >tokNameId, >tokNameMnem
    .byte >tokNameDir, >tokNameReg, >tokNameNum, >tokNameComma
    .byte >tokNameColon, >tokNameHash, >tokNameLparen, >tokNameRparen
    .byte >tokNamePlus, >tokNameMinus, >tokNameLess, >tokNameGreater

dirSubtypeNamesLo:
    .byte <dirNameUnknown, <dirNameOrg, <dirNameByte, <dirNameWord
    .byte <dirNameInclude, <dirNameStatic, <dirNameReloc
dirSubtypeNamesHi:
    .byte >dirNameUnknown, >dirNameOrg, >dirNameByte, >dirNameWord
    .byte >dirNameInclude, >dirNameStatic, >dirNameReloc

regSubtypeNamesLo:
    .byte <regNameA, <regNameX, <regNameY
regSubtypeNamesHi:
    .byte >regNameA, >regNameX, >regNameY

numSubtypeNamesLo:
    .byte <numNameDec, <numNameHex, <numNameBin
numSubtypeNamesHi:
    .byte >numNameDec, >numNameHex, >numNameBin

tokNameEof:       .byte "EOF", 0
tokNameNewline:   .byte "NEWLINE", 0
tokNameId:        .byte "IDENTIFIER", 0
tokNameMnem:      .byte "MNEMONIC", 0
tokNameDir:       .byte "DIRECTIVE", 0
tokNameReg:       .byte "REGISTER", 0
tokNameNum:       .byte "NUMBER", 0
tokNameComma:     .byte "COMMA", 0
tokNameColon:     .byte "COLON", 0
tokNameHash:      .byte "HASH", 0
tokNameLparen:    .byte "LPAREN", 0
tokNameRparen:    .byte "RPAREN", 0
tokNamePlus:      .byte "PLUS", 0
tokNameMinus:     .byte "MINUS", 0
tokNameLess:      .byte "LESS", 0
tokNameGreater:   .byte "GREATER", 0
msgUnknownTok:    .byte "UNKNOWN", 0

dirNameUnknown:   .byte " (UNKNOWN)", 0
dirNameOrg:       .byte " (ORG)", 0
dirNameByte:      .byte " (BYTE)", 0
dirNameWord:      .byte " (WORD)", 0
dirNameInclude:   .byte " (INCLUDE)", 0
dirNameStatic:    .byte " (STATIC)", 0
dirNameReloc:     .byte " (RELOC)", 0

regNameA:         .byte " (A)", 0
regNameX:         .byte " (X)", 0
regNameY:         .byte " (Y)", 0

numNameDec:       .byte " (DECIMAL)", 0
numNameHex:       .byte " (HEX)", 0
numNameBin:       .byte " (BINARY)", 0

msgSubUnknown:    .byte " (UNKNOWN)", 0
msgMnemPrefix:    .byte " (", 0
msgMnemSuffix:    .byte ")", 0
msgTextPrefix:    .byte " [", 0
msgTextSuffix:    .byte "]", 0
msgLocLinePrefix: .byte " L:", 0
msgLocColPrefix:  .byte " C:", 0
msgCR:            .byte PetCr, 0
