; src/external/edlin/edlin.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; EDLIN line-oriented text editor, ported from MS-DOS 4.00's EDLIN
; (ms-dos/v4.0/src/CMD/EDLIN/). Design/scope:
; brain/plans/2026-07-09-edlin-port-feasibility.md; phased build-out:
; brain/plans/2026-07-09-edlin-implementation-phases.md. Calls into
; Command64's own jump table (OS_API = $1000, function-selector-in-A
; convention, include/ca65/command64.inc).
;
; Phase 1: loads a filename given on the command line into the buffer
; (buffer.s) and prints a temporary debug dump (line count + first two
; line offsets) so correctness can be eyeballed before List/Page (Phase 2)
; exist. printDec16 and the debug-dump call site are temporary and must be
; deleted once Phase 2 lands real output commands.
;
; PETSCII note: mirrors src/external/label/label.s -- ca65 has no
; equivalent to Kick's ".encoding petscii_mixed" auto-translation, so
; message strings are precomputed uppercase-ASCII/PETSCII hex bytes
; rather than quoted string literals.

.include "command64.inc"
.include "common.inc"

.import bufInit
.import bufLoadFile
.import findLine

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '1'
.include "build_edlin.inc"

.import __MAIN_START__

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------
start:
    ldx #<verMsg
    ldy #>verMsg
    lda #DOS_PRINT_STR
    jsr OS_API

    ; --- Parse filename argument out of CommandBuffer ---
    ldy ParsePos
skipToken:
    lda CommandBuffer, y
    bne skipTokenNotNull
    jmp noArgErr
skipTokenNotNull:
    iny
    cmp #' '
    bne skipToken
skipSpaces:
    lda CommandBuffer, y
    cmp #' '
    bne endSpaces
    iny
    jmp skipSpaces
endSpaces:
    cmp #0
    bne haveArg
    jmp noArgErr
haveArg:

    ; Null-terminate the filename token in place at the first trailing space.
    tya
    tax                       ; X = filename start index into CommandBuffer
    stx FilenameIdx
trimLoop:
    lda CommandBuffer, y
    beq startLoad
    cmp #' '
    bne trimNext
    lda #0
    sta CommandBuffer, y
    jmp startLoad
trimNext:
    iny
    jmp trimLoop

startLoad:
    jsr bufInit

    lda FilenameIdx
    clc
    adc #<CommandBuffer
    sta FilenamePtrLo
    lda #>CommandBuffer
    adc #0
    sta FilenamePtrHi

    ldx FilenamePtrLo
    ldy FilenamePtrHi
    jsr bufLoadFile
    bcc dumpLineCount
    ldx #<msgOpenErr
    ldy #>msgOpenErr
    lda #DOS_PRINT_STR
    jsr OS_API
    jmp exit

; --- Temporary Phase 1 debug dump (delete before Phase 2) ---
dumpLineCount:
    ldx #<msgIsVmm
    ldy #>msgIsVmm
    lda #DOS_PRINT_STR
    jsr OS_API
    lda BufIsVmm
    clc
    adc #'0'
    jsr KernalChROUT
    lda #PetCr
    jsr KernalChROUT

    ldx #<msgBufEnd
    ldy #>msgBufEnd
    lda #DOS_PRINT_STR
    jsr OS_API
    lda BufEndLo
    sta ScanPtrLo
    lda BufEndHi
    sta ScanPtrHi
    jsr printDec16
    lda #PetCr
    jsr KernalChROUT

    ldx #<msgLineCount
    ldy #>msgLineCount
    lda #DOS_PRINT_STR
    jsr OS_API

    lda #$FF
    sta FindTargetLo
    sta FindTargetHi
    jsr findLine              ; scans whole buffer; CurLineLo/Hi = last+1

    ; findLine's "last+1" result (DOS EDLIN's own "#" convention -- the
    ; insertion point one past the last real line) is what later phases
    ; actually need. For this human-readable debug dump only, subtract 1
    ; to show the true line count.
    lda CurLineLo
    sec
    sbc #1
    sta ScanPtrLo              ; printDec16 borrows ScanPtrLo/Hi as PdValLo/Hi
    lda CurLineHi
    sbc #0
    sta ScanPtrHi
    jsr printDec16

    lda #PetCr
    jsr KernalChROUT

    ldx #<msgLine1Off
    ldy #>msgLine1Off
    lda #DOS_PRINT_STR
    jsr OS_API
    lda #1
    sta FindTargetLo
    lda #0
    sta FindTargetHi
    jsr findLine
    lda CurPtrLo
    sta ScanPtrLo
    lda CurPtrHi
    sta ScanPtrHi
    jsr printDec16
    lda #PetCr
    jsr KernalChROUT

    ldx #<msgLine2Off
    ldy #>msgLine2Off
    lda #DOS_PRINT_STR
    jsr OS_API
    lda #2
    sta FindTargetLo
    lda #0
    sta FindTargetHi
    jsr findLine
    lda CurPtrLo
    sta ScanPtrLo
    lda CurPtrHi
    sta ScanPtrHi
    jsr printDec16
    lda #PetCr
    jsr KernalChROUT

    jmp exit

noArgErr:
    ldx #<msgNoArg
    ldy #>msgNoArg
    lda #DOS_PRINT_STR
    jsr OS_API

exit:
    lda #DOS_EXIT
    jsr OS_API

; ---------------------------------------------------------------------------
; printDec16 — prints a 16-bit value as fixed 5-digit decimal (leading
; zeros included; this is throwaway debug-dump code, not worth trimming).
; Input: ScanPtrLo/ScanPtrHi (reused here as PdValLo/PdValHi — safe, this
; only ever runs after buffer/findLine work for the call has completed).
; Reuses TmpLenLo/TmpLenHi as PdPlaceLo/PdPlaceHi scratch for the same
; reason. Temporary: delete alongside the debug dump before Phase 2.
; ---------------------------------------------------------------------------
printDec16:
    lda #0
    sta PdTableIdx
pd16Digit:
    lda #0
    sta PdDigit
    ldx PdTableIdx
pd16SubLoop:
    lda placeValues+1, x
    sta TmpLenHi
    lda placeValues, x
    sta TmpLenLo

    lda ScanPtrHi
    cmp TmpLenHi
    bcc pd16NoSub
    bne pd16DoSub
    lda ScanPtrLo
    cmp TmpLenLo
    bcc pd16NoSub
pd16DoSub:
    lda ScanPtrLo
    sec
    sbc TmpLenLo
    sta ScanPtrLo
    lda ScanPtrHi
    sbc TmpLenHi
    sta ScanPtrHi
    inc PdDigit
    jmp pd16SubLoop
pd16NoSub:
    lda PdDigit
    clc
    adc #'0'
    tax
    lda #DOS_PRINT_CHAR
    jsr OS_API

    lda PdTableIdx
    clc
    adc #2
    sta PdTableIdx
    cmp #10
    bne pd16Digit
    rts

.segment "RODATA"

; "EDLIN V" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
; + "." + BUILD_NUMBER, same banner format as label.s/format.s.
verMsg:
    .byte $45, $44, $4C, $49, $4E, $20, $56
    .byte VERSION_MAJOR, $2E, VERSION_MINOR, $2E, VERSION_STAGE, $2E
    .byte BUILD_NUMBER
    .byte $0D, $00
; "USAGE: EDLIN <FILENAME>"
msgNoArg:
    .byte $55, $53, $41, $47, $45, $3A, $20, $45, $44, $4C, $49, $4E, $20
    .byte $3C, $46, $49, $4C, $45, $4E, $41, $4D, $45, $3E, $0D, $00
; "ERROR: COULD NOT OPEN FILE."
msgOpenErr:
    .byte $45, $52, $52, $4F, $52, $3A, $20, $43, $4F, $55, $4C, $44, $20
    .byte $4E, $4F, $54, $20, $4F, $50, $45, $4E, $20, $46, $49, $4C, $45
    .byte $2E, $0D, $00
; "BUFISVMM: " (temporary diagnostic, delete before Phase 2)
msgIsVmm:
    .byte $42, $55, $46, $49, $53, $56, $4D, $4D, $3A, $20, $00
; "BUFEND: " (temporary diagnostic, delete before Phase 2)
msgBufEnd:
    .byte $42, $55, $46, $45, $4E, $44, $3A, $20, $00
; "LINE COUNT: "
msgLineCount:
    .byte $4C, $49, $4E, $45, $20, $43, $4F, $55, $4E, $54, $3A, $20, $00
; "LINE 1 OFFSET: "
msgLine1Off:
    .byte $4C, $49, $4E, $45, $20, $31, $20, $4F, $46, $46, $53, $45, $54
    .byte $3A, $20, $00
; "LINE 2 OFFSET: "
msgLine2Off:
    .byte $4C, $49, $4E, $45, $20, $32, $20, $4F, $46, $46, $53, $45, $54
    .byte $3A, $20, $00

; Place-value table for printDec16 (10000, 1000, 100, 10, 1), little-endian words.
placeValues:
    .word 10000, 1000, 100, 10, 1

.segment "BSS"
FilenameIdx:   .res 1
FilenamePtrLo: .res 1
FilenamePtrHi: .res 1
