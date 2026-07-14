; src/external/comp/comp.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; COMP: external raw byte-stream file comparison utility.
; Phase 1 scope: strict "COMP FILE1 FILE2" syntax, no options, raw bytes
; regardless of file type, 24-bit hex offsets, and 10 displayed mismatches.

.include "command64.inc"
.include "common.inc"

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '0'
.include "build_comp.inc"

.import __MAIN_START__

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------
start:
    lda #$FF
    sta File1Handle
    sta File2Handle
    lda #0
    sta OffsetLo
    sta OffsetMid
    sta OffsetHi
    sta MismatchCount
    sta StopFlag
    sta SizeDiffFlag

    jsr parseArgs
    bcc argsOk
    jsr printParseError
    jmp exit

argsOk:
    jsr openFiles
    bcc filesOpen
    jmp closeAndExit

filesOpen:
    jsr compareFiles
    jsr printSummary
    jmp closeAndExit

closeAndExit:
    jsr closeFiles
exit:
    lda #DOS_EXIT
    jsr OS_API

; ---------------------------------------------------------------------------
; parseArgs
; Parses CommandBuffer after the external command token.
; Output: Carry clear on success, File1Buf/File2Buf null-terminated.
;         Carry set and A = PARSE_* on error.
; ---------------------------------------------------------------------------
parseArgs:
    ldy ParsePos

paSkipToken:
    lda CommandBuffer, y
    beq paMissing
    cmp #' '
    beq paAfterToken
    iny
    jmp paSkipToken

paAfterToken:
    jsr skipSpaces
    lda CommandBuffer, y
    beq paMissing
    cmp #'/'
    beq paOption

    ldx #<File1Buf
    stx PrintPtrLo
    ldx #>File1Buf
    stx PrintPtrHi
    jsr parseToken
    bcs paError

    jsr skipSpaces
    lda CommandBuffer, y
    beq paMissing
    cmp #'/'
    beq paOption

    ldx #<File2Buf
    stx PrintPtrLo
    ldx #>File2Buf
    stx PrintPtrHi
    jsr parseToken
    bcs paError

    jsr skipSpaces
    lda CommandBuffer, y
    bne paExtra

    clc
    lda #PARSE_OK
    rts

paMissing:
    sec
    lda #PARSE_MISSING
    rts
paExtra:
    sec
    lda #PARSE_EXTRA
    rts
paOption:
    sec
    lda #PARSE_OPTION
    rts
paError:
    rts

; Input: Y = CommandBuffer token start, PrintPtrLo/Hi = destination buffer.
; Output: Y = first delimiter after token, Carry status.
parseToken:
    sty ArgStart
    lda #0
    sta DestIndex
ptLoop:
    ldy ArgStart
    lda CommandBuffer, y
    beq ptDone
    cmp #' '
    beq ptDone
    ldx DestIndex
    cpx #FILENAME_MAX
    bcs ptTooLong
    ldy DestIndex
    sta (PrintPtrLo), y
    inc DestIndex
    inc ArgStart
    jmp ptLoop

ptDone:
    lda DestIndex
    beq ptMissing
    tay
    lda #0
    sta (PrintPtrLo), y
    ldy ArgStart
    clc
    lda #PARSE_OK
    rts

ptMissing:
    sec
    lda #PARSE_MISSING
    rts
ptTooLong:
    sec
    lda #PARSE_TOO_LONG
    rts

skipSpaces:
    lda CommandBuffer, y
    cmp #' '
    bne ssDone
    iny
    jmp skipSpaces
ssDone:
    rts

printParseError:
    cmp #PARSE_OPTION
    beq ppeOption
    cmp #PARSE_EXTRA
    beq ppeExtra
    cmp #PARSE_TOO_LONG
    beq ppeTooLong
    jmp printUsage
ppeOption:
    ldx #<msgUnknownOption
    ldy #>msgUnknownOption
    lda #DOS_PRINT_STR
    jsr OS_API
    jmp printUsage
ppeExtra:
    ldx #<msgTooManyArgs
    ldy #>msgTooManyArgs
    lda #DOS_PRINT_STR
    jsr OS_API
    jmp printUsage
ppeTooLong:
    ldx #<msgNameTooLong
    ldy #>msgNameTooLong
    lda #DOS_PRINT_STR
    jsr OS_API
printUsage:
    ldx #<msgUsage
    ldy #>msgUsage
    lda #DOS_PRINT_STR
    jsr OS_API
    rts

; ---------------------------------------------------------------------------
; File open/close
; ---------------------------------------------------------------------------
openFiles:
    lda #0
    sta HexValLo
    ldx #<File1Buf
    ldy #>File1Buf
    lda #DOS_OPEN_FILE
    jsr OS_API
    bcc ofFile1Ok
    jsr printOpenError
    sec
    rts
ofFile1Ok:
    sta File1Handle

    lda #0
    sta HexValLo
    ldx #<File2Buf
    ldy #>File2Buf
    lda #DOS_OPEN_FILE
    jsr OS_API
    bcc ofFile2Ok
    jsr printOpenError
    sec
    rts
ofFile2Ok:
    sta File2Handle
    clc
    rts

closeFiles:
    lda File2Handle
    cmp #$FF
    beq cfSkip2
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr OS_API
    lda #$FF
    sta File2Handle
cfSkip2:
    lda File1Handle
    cmp #$FF
    beq cfDone
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr OS_API
    lda #$FF
    sta File1Handle
cfDone:
    rts

printOpenError:
    ldx #<msgOpenError
    ldy #>msgOpenError
    lda #DOS_PRINT_STR
    jsr OS_API
    rts

; ---------------------------------------------------------------------------
; Compare loop
; ---------------------------------------------------------------------------
compareFiles:
cfLoop:
    jsr readFile1
    bcc cfRead1Ok
    jmp cfReadError
cfRead1Ok:
    jsr readFile2
    bcc cfRead2Ok
    jmp cfReadError
cfRead2Ok:
    jsr setCompareCount
    jsr compareOverlap
    lda StopFlag
    bne cfDone

    lda Read1Count
    cmp Read2Count
    beq cfCountsEqual
    lda #1
    sta SizeDiffFlag
    ldx #<msgSizeDiff
    ldy #>msgSizeDiff
    lda #DOS_PRINT_STR
    jsr OS_API
    jmp cmpDone

cfCountsEqual:
    lda Read1Count
    beq cmpDone
    cmp #CHUNK_SIZE
    beq cfLoop
    ; Equal short reads mean both files ended after the same final chunk.
cmpDone:
    rts

cfReadError:
    ldx #<msgReadError
    ldy #>msgReadError
    lda #DOS_PRINT_STR
    jsr OS_API
    lda #1
    sta StopFlag
    rts

readFile1:
    lda File1Handle
    sta FileHandle
    ldx #<Buf1
    ldy #>Buf1
    jsr readChunk
    sta Read1Count
    rts

readFile2:
    lda File2Handle
    sta FileHandle
    ldx #<Buf2
    ldy #>Buf2
    jsr readChunk
    sta Read2Count
    rts

; Input: FileHandle, X/Y = buffer.
; Output: A = bytes read, Carry clear on success/EOF, Carry set on read error.
readChunk:
    lda #CHUNK_SIZE
    sta HexValLo
    lda #0
    sta HexValHi
    lda #DOS_READ_FILE
    jsr OS_API
    bcc rcOk
    lda HexValLo
    ora HexValHi
    beq rcEof              ; read-past-EOF compatibility path
    sec
    lda HexValLo
    rts
rcEof:
    clc
    lda #0
    rts
rcOk:
    lda HexValLo
    clc
    rts

setCompareCount:
    lda Read1Count
    cmp Read2Count
    bcc sccUseA
    lda Read2Count
sccUseA:
    sta CompareCount
    rts

compareOverlap:
    ldx #0
coLoop:
    cpx CompareCount
    beq coDone
    lda Buf1, x
    cmp Buf2, x
    beq coNext
    sta Byte1Save
    lda Buf2, x
    sta Byte2Save
    stx IndexSave
    jsr reportMismatch
    ldx IndexSave
    lda StopFlag
    bne coDone
coNext:
    jsr incOffset24
    inx
    jmp coLoop
coDone:
    rts

incOffset24:
    inc OffsetLo
    bne ioDone
    inc OffsetMid
    bne ioDone
    inc OffsetHi
ioDone:
    rts

reportMismatch:
    ldx #<msgCompareAt
    ldy #>msgCompareAt
    lda #DOS_PRINT_STR
    jsr OS_API
    lda OffsetHi
    jsr printHex8
    lda OffsetMid
    jsr printHex8
    lda OffsetLo
    jsr printHex8
    ldx #<msgColonDollar
    ldy #>msgColonDollar
    lda #DOS_PRINT_STR
    jsr OS_API
    lda Byte1Save
    jsr printHex8
    ldx #<msgSpaceDollar
    ldy #>msgSpaceDollar
    lda #DOS_PRINT_STR
    jsr OS_API
    lda Byte2Save
    jsr printHex8
    lda #PetCr
    jsr KernalChROUT

    inc MismatchCount
    lda MismatchCount
    cmp #MAX_MISMATCHES
    bcc rmDone
    lda #1
    sta StopFlag
    ldx #<msgStop
    ldy #>msgStop
    lda #DOS_PRINT_STR
    jsr OS_API
rmDone:
    rts

printSummary:
    lda StopFlag
    bne psDone
    lda MismatchCount
    bne psDone
    lda SizeDiffFlag
    bne psDone
    ldx #<msgOk
    ldy #>msgOk
    lda #DOS_PRINT_STR
    jsr OS_API
psDone:
    rts

printHex8:
    pha
    lsr
    lsr
    lsr
    lsr
    jsr phNibble
    pla
    and #$0F
phNibble:
    cmp #10
    bcc phnDigit
    clc
    adc #7
phnDigit:
    adc #48
    jsr KernalChROUT
    rts

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
msgUsage:
    .byte "USAGE: COMP FILE1 FILE2", PetCr, 0
msgUnknownOption:
    .byte "UNKNOWN OPTION", PetCr, 0
msgTooManyArgs:
    .byte "TOO MANY ARGUMENTS", PetCr, 0
msgNameTooLong:
    .byte "FILE NAME TOO LONG", PetCr, 0
msgOpenError:
    .byte "FILE OPEN ERROR", PetCr, 0
msgReadError:
    .byte "READ ERROR", PetCr, 0
msgCompareAt:
    .byte "COMPARE ERROR AT $", 0
msgColonDollar:
    .byte ": $", 0
msgSpaceDollar:
    .byte " $", 0
msgStop:
    .byte "10 MISMATCHES - STOPPING", PetCr, 0
msgSizeDiff:
    .byte "FILES ARE DIFFERENT SIZES", PetCr, 0
msgOk:
    .byte "FILES COMPARE OK", PetCr, 0

.segment "BSS"

File1Buf:
    .res FILENAME_MAX + 1
File2Buf:
    .res FILENAME_MAX + 1
Buf1:
    .res CHUNK_SIZE
Buf2:
    .res CHUNK_SIZE
