; spike/ca65-label/label.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; ca65/ld65 relocation spike -- ported from src/external/label/label.asm.
; See spike/ca65-conway/README.md for the general spike rationale; this one
; adds a different stress test: calling into Command64's own jump table
; ($1000, function-selector-in-A convention) and reading OS globals
; (CommandBuffer/ParsePos/CurrentDevice), not just raw KERNAL vectors.
;
; PETSCII note: Kick's ".encoding petscii_mixed" auto-translates mixed-case
; source text so it displays correctly via CHROUT regardless of letter
; case (both the $41-$5A and $C1-$DA PETSCII ranges render as the same
; uppercase glyph in this OS's default charset). ca65 has no equivalent
; pragma, so all message strings below are precomputed: every letter maps
; to its uppercase ASCII/PETSCII code ($41-$5A), non-letters pass through
; unchanged.
;
; The version banner is a fixed "ca65 spike" string rather than wired into
; the Kick build's BUILD_NUMBER counter (cmake/IncrementBuildNumber.cmake)
; -- that machinery is Kick-build-specific and out of scope for the spike.

.include "common.inc"

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
    jsr $1000

    lda CurrentDevice
    sta SavedDevice

    ldy ParsePos

skipToken:
    lda CommandBuffer, y
    bne notTokenNull
    jmp noArgErr
notTokenNull:
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
    beq labelNoArg

    tya
    clc
    adc #<CommandBuffer
    sta PrintPtrLo
    lda #>CommandBuffer
    adc #0
    sta PrintPtrHi

    ldx #PrintPtrLo
    lda #DOS_PARSE_PREFIX
    jsr $1000
    sta CurrentDevice

    lda PrintPtrLo
    sec
    sbc #<CommandBuffer
    tay

skipSpacesPostPrefix:
    lda CommandBuffer, y
    cmp #' '
    bne checkNullPostPrefix
    iny
    jmp skipSpacesPostPrefix
checkNullPostPrefix:
    cmp #0
    bne labelNoPrefix

labelNoArg:
    ldx #15
    lda #$A0
initLabelBuf:
    sta labelBuf, x
    dex
    bpl initLabelBuf

    ldx #<promptMsg
    ldy #>promptMsg
    lda #DOS_PRINT_STR
    jsr $1000

    ldy #0
readLoop:
    tya
    pha
pollKey:
    jsr KernalGetIn
    beq pollKey
    tax
    pla
    tay
    txa

    cmp #PetCr
    beq doneInput

    cmp #PetDel
    bne handleChar

    tya
    beq readLoop
    dey
    lda #PetDel
    jsr KernalChROUT
    jmp readLoop

handleChar:
    cpy #16
    bcs readLoop

    jsr KernalChROUT

    sta labelBuf, y
    iny
    jmp readLoop

doneInput:
    lda #PetCr
    jsr KernalChROUT

    tya
    beq cancelExit

    jmp openChannels

cancelExit:
    jmp labelExit

labelNoPrefix:
countStart:
    sty ArgIdx
    ldx #0
countChars:
    lda CommandBuffer, y
    beq countDone
    inx
    iny
    cpx #17
    bne countChars
    jmp tooLongErr

countDone:
    ldy ArgIdx
    ldx #0
copyLabel:
    lda CommandBuffer, y
    beq padLabel
    sta labelBuf, x
    inx
    iny
    cpx #VOL_NAME_LEN
    bne copyLabel
    jmp openChannels

padLabel:
    lda #$A0
    sta labelBuf, x
    inx
    cpx #VOL_NAME_LEN
    bne padLabel

openChannels:
    lda #0
    jsr KernalSETNAM
    lda #CMD_CHANNEL
    ldx CurrentDevice
    ldy #CMD_CHANNEL
    jsr KernalSETLFS
    jsr KernalOPEN
    bcc openCmdOk
    jmp openErr
openCmdOk:

    ldx #CMD_CHANNEL
    jsr KernalCHKOUT
    ldx #0
sendInitLoop:
    lda cmdInit, x
    beq sendInitDone
    jsr KernalChROUT
    inx
    jmp sendInitLoop
sendInitDone:
    jsr KernalCLRCHN

    lda #1
    ldx #<bufName
    ldy #>bufName
    jsr KernalSETNAM
    lda #DATA_CHANNEL
    ldx CurrentDevice
    ldy #DATA_CHANNEL
    jsr KernalSETLFS
    jsr KernalOPEN
    bcc openDataOk
    lda #CMD_CHANNEL
    jsr KernalCLOSE
    jmp openErr
openDataOk:

    ldx #CMD_CHANNEL
    jsr KernalCHKOUT
    ldx #0
sendU1Loop:
    lda cmdU1, x
    beq sendU1Done
    jsr KernalChROUT
    inx
    jmp sendU1Loop
sendU1Done:
    jsr KernalCLRCHN

    ldx #CMD_CHANNEL
    jsr KernalCHKOUT
    ldx #0
sendBPLoop:
    lda cmdBP, x
    beq sendBPDone
    jsr KernalChROUT
    inx
    jmp sendBPLoop
sendBPDone:
    jsr KernalCLRCHN

    ldx #DATA_CHANNEL
    jsr KernalCHKOUT
    ldx #0
writeLabel:
    lda labelBuf, x
    jsr KernalChROUT
    inx
    cpx #VOL_NAME_LEN
    bne writeLabel
    jsr KernalCLRCHN

    ldx #CMD_CHANNEL
    jsr KernalCHKOUT
    ldx #0
sendU2Loop:
    lda cmdU2, x
    beq sendU2Done
    jsr KernalChROUT
    inx
    jmp sendU2Loop
sendU2Done:
    jsr KernalCLRCHN

    lda #DATA_CHANNEL
    jsr KernalCLOSE

    ldx #CMD_CHANNEL
    jsr KernalCHKIN
    jsr KernalChRIN
    sta statusBuf
    jsr KernalChRIN
    sta statusBuf+1

    ldy #2
readStatus:
    jsr KernalREADST
    bne readStatusDone
    jsr KernalChRIN
    cmp #$0D
    beq readStatusDone
    sta statusBuf, y
    iny
    cpy #38
    bne readStatus
readStatusDone:
    lda #0
    sta statusBuf, y
    jsr KernalCLRCHN

    lda statusBuf
    cmp #'0'
    bne closeCommandChannel
    lda statusBuf+1
    cmp #'0'
    bne closeCommandChannel

    ldx #CMD_CHANNEL
    jsr KernalCHKOUT
    ldx #0
sendFinalInitLoop:
    lda cmdInit, x
    beq sendFinalInitDone
    jsr KernalChROUT
    inx
    jmp sendFinalInitLoop
sendFinalInitDone:
    jsr KernalCLRCHN

closeCommandChannel:
    lda #CMD_CHANNEL
    jsr KernalCLOSE

    lda statusBuf
    cmp #'0'
    bne printDriveError
    lda statusBuf+1
    cmp #'0'
    bne printDriveError

    ldx #<okMsg
    ldy #>okMsg
    lda #DOS_PRINT_STR
    jsr $1000
    jmp labelExit

printDriveError:
    ldy #0
printErrLoop:
    lda statusBuf, y
    beq printErrDone
    jsr KernalChROUT
    iny
    jmp printErrLoop
printErrDone:
    lda #$0D
    jsr KernalChROUT
    jmp labelExit

noArgErr:
    ldx #<reqMsg
    ldy #>reqMsg
    lda #DOS_PRINT_STR
    jsr $1000
    jmp labelExit

tooLongErr:
    ldx #<lenMsg
    ldy #>lenMsg
    lda #DOS_PRINT_STR
    jsr $1000
    jmp labelExit

openErr:
    ldx #<devMsg
    ldy #>devMsg
    lda #DOS_PRINT_STR
    jsr $1000
    jmp labelExit

labelExit:
    lda #CMD_CHANNEL
    jsr KernalCLOSE
    lda #DATA_CHANNEL
    jsr KernalCLOSE
    lda SavedDevice
    sta CurrentDevice
    rts

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------

bufName:
    .byte $23               ; '#': requests a free drive RAM buffer

; Drive command strings as explicit hex bytes (bypasses PETSCII shifting --
; the 1541 command parser rejects the shifted range Kick's petscii_mixed
; would otherwise produce for uppercase source literals).
cmdInit:
    .byte $49, $0D, $00

cmdU1:
    .byte $55, $31, $3A, $32, $20, $30, $20, $31, $38, $20, $30, $0D, $00

cmdBP:
    .byte $42, $2D, $50, $3A, $32, $20, $31, $34, $34, $0D, $00

cmdU2:
    .byte $55, $32, $3A, $32, $20, $30, $20, $31, $38, $20, $30, $0D, $00

; Human-readable messages, precomputed to PETSCII (see file header comment).
okMsg:
    .byte $4C, $41, $42, $45, $4C, $20, $55, $50, $44, $41, $54, $45, $44
    .byte $0D, $00

lenMsg:
    .byte $4C, $41, $42, $45, $4C, $20, $54, $4F, $4F, $20, $4C, $4F, $4E
    .byte $47, $20, $28, $4D, $41, $58, $20, $31, $36, $29
    .byte $0D, $00

reqMsg:
    .byte $4C, $41, $42, $45, $4C, $20, $4E, $41, $4D, $45, $20, $52, $45
    .byte $51, $55, $49, $52, $45, $44
    .byte $0D, $00

promptMsg:
    .byte $56, $4F, $4C, $55, $4D, $45, $20, $4C, $41, $42, $45, $4C, $20
    .byte $28, $31, $36, $20, $43, $48, $41, $52, $53, $20, $4D, $41, $58
    .byte $29, $3F, $20
    .byte $00

devMsg:
    .byte $44, $45, $56, $49, $43, $45, $20, $4E, $4F, $54, $20, $50, $52
    .byte $45, $53, $45, $4E, $54
    .byte $0D, $00

verMsg:
    .byte $4C, $41, $42, $45, $4C, $20, $56, $30, $2E, $31, $2E, $30, $20
    .byte $28, $43, $41, $36, $35, $20, $53, $50, $49, $4B, $45, $29
    .byte $0D, $00

; Runtime buffers (initialized at load time)
statusBuf:
    .res 40, 0

labelBuf:
    .res 16, $A0
