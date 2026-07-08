; spike/ca65-conway/conway_grid.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; ca65 port of conway.asm's grid/drawing half. Split out from conway_main.s
; on purpose: this is the multi-object-file half of the ca65/ld65 spike --
; it .exports the routines conway_main.s calls, so ld65 has to resolve
; cross-module references instead of everything living in one flat file
; the way Kick Assembler's conway.asm does.

.include "common.inc"

.export randomizeGrid
.export drawGrid
.export drawStatusLine
.export computeNext
.export clearGrid
.export clearScreen

.segment "CODE"

; ---------------------------------------------------------------------------
; randomizeGrid -- fill the active buffer with ~25% live cells.
; 8-bit Galois LFSR (period 255, poly x^8+x^6+x^5+x^4+1).
; ---------------------------------------------------------------------------
randomizeGrid:
    jsr getCurrBase
    sta zpCurrLo
    stx zpCurrHi

    ldx #0
    ldy #0
rgCell:
    jsr lfsrStep
    and #$0A
    beq rgAlive
    lda #0
    jmp rgStore
rgAlive:
    lda #1
rgStore:
    sta (zpCurrLo), y
    iny
    bne rgCell

    inc zpCurrHi
    inx
    cpx #3
    bne rgCell

    ldy #0
rgTail:
    jsr lfsrStep
    and #$0A
    beq rgTailAlive
    lda #0
    jmp rgTailStore
rgTailAlive:
    lda #1
rgTailStore:
    sta (zpCurrLo), y
    iny
    cpy #192
    bne rgTail
    rts

; ---------------------------------------------------------------------------
; clearGrid -- set every cell in the active buffer to dead (0).
; ---------------------------------------------------------------------------
clearGrid:
    jsr getCurrBase
    sta zpCurrLo
    stx zpCurrHi

    lda #0
    ldx #0
    ldy #0
cgPage:
    sta (zpCurrLo), y
    iny
    bne cgPage
    inc zpCurrHi
    inx
    cpx #3
    bne cgPage
    ldy #0
cgTail:
    sta (zpCurrLo), y
    iny
    cpy #192
    bne cgTail
    rts

; ---------------------------------------------------------------------------
; clearScreen -- fill screen RAM ($0400) with space characters.
; ---------------------------------------------------------------------------
clearScreen:
    lda #<SCREEN
    sta zpDstLo
    lda #>SCREEN
    sta zpDstHi

    lda #CHAR_DEAD
    ldx #0
    ldy #0
csPage:
    sta (zpDstLo), y
    iny
    bne csPage
    inc zpDstHi
    inx
    cpx #3
    bne csPage
    ldy #0
csTail:
    sta (zpDstLo), y
    iny
    cpy #232
    bne csTail
    rts

; ---------------------------------------------------------------------------
; drawGrid -- copy active buffer to screen RAM, converting 0/1 -> PETSCII.
; ---------------------------------------------------------------------------
drawGrid:
    jsr getCurrBase
    sta zpCurrLo
    stx zpCurrHi

    lda #<SCREEN
    sta zpDstLo
    lda #>SCREEN
    sta zpDstHi

    lda #0
    sta dgPageCnt
    ldy #0
dgPage:
    lda (zpCurrLo), y
    tax
    lda cellCharTbl, x
    sta (zpDstLo), y
    iny
    bne dgPage

    inc zpCurrHi
    inc zpDstHi
    inc dgPageCnt
    lda dgPageCnt
    cmp #3
    bne dgPage

    ldy #0
dgTail:
    lda (zpCurrLo), y
    tax
    lda cellCharTbl, x
    sta (zpDstLo), y
    iny
    cpy #192
    bne dgTail
    rts

dgPageCnt: .byte 0

; ---------------------------------------------------------------------------
; computeNext -- evaluate one full generation of Conway's B3/S23 rules.
; ---------------------------------------------------------------------------
computeNext:
    lda #0
    sta zpRow

cnRowLoop:
    jsr setThreeRowPtrs
    jsr setDstRowPtr

    lda #0
    sta zpCol

cnColLoop:
    lda zpCol
    bne cnNotFirstCol
    lda #GRID_W - 1
    jmp cnGotLeft
cnNotFirstCol:
    sec
    sbc #1
cnGotLeft:
    tay

    lda #0
    sta zpCount

    lda (zpPrevLo), y
    clc
    adc zpCount
    sta zpCount

    lda (zpCurrLo), y
    clc
    adc zpCount
    sta zpCount

    lda (zpNextLo), y
    clc
    adc zpCount
    sta zpCount

    ldy zpCol

    lda (zpPrevLo), y
    clc
    adc zpCount
    sta zpCount

    lda (zpNextLo), y
    clc
    adc zpCount
    sta zpCount

    lda zpCol
    cmp #GRID_W - 1
    bne cnNotLastCol
    lda #0
    jmp cnGotRight
cnNotLastCol:
    clc
    adc #1
cnGotRight:
    tay

    lda (zpPrevLo), y
    clc
    adc zpCount
    sta zpCount

    lda (zpCurrLo), y
    clc
    adc zpCount
    sta zpCount

    lda (zpNextLo), y
    clc
    adc zpCount
    sta zpCount

    ldy zpCol
    lda (zpCurrLo), y
    beq cnDead

cnAlive:
    lda zpCount
    cmp #2
    beq cnSurvive
    cmp #3
    beq cnSurvive
    jmp cnKill

cnDead:
    lda zpCount
    cmp #3
    beq cnBorn
    jmp cnKill

cnSurvive:
cnBorn:
    lda #1
    ldy zpCol
    sta (zpDstLo), y
    jmp cnNext

cnKill:
    lda #0
    ldy zpCol
    sta (zpDstLo), y

cnNext:
    inc zpCol
    lda zpCol
    cmp #GRID_W
    beq cnColDone
    jmp cnColLoop
cnColDone:

    inc zpRow
    lda zpRow
    cmp #GRID_H
    beq cnAllDone
    jmp cnRowLoop
cnAllDone:
    rts

; ---------------------------------------------------------------------------
; setThreeRowPtrs -- zpPrev/Curr/Next Lo/Hi <- row (zpRow-1, zpRow, zpRow+1)
; addresses in the ACTIVE buffer, wrapping toroidally.
; ---------------------------------------------------------------------------
setThreeRowPtrs:
    jsr getCurrBase
    sta stpBLo
    stx stpBHi

    ldy zpRow
    clc
    lda stpBLo
    adc rowOffLo, y
    sta zpCurrLo
    lda stpBHi
    adc rowOffHi, y
    sta zpCurrHi

    lda zpRow
    beq stpPrevWrap
    sec
    sbc #1
    jmp stpPrevGot
stpPrevWrap:
    lda #GRID_H - 1
stpPrevGot:
    tay
    clc
    lda stpBLo
    adc rowOffLo, y
    sta zpPrevLo
    lda stpBHi
    adc rowOffHi, y
    sta zpPrevHi

    lda zpRow
    clc
    adc #1
    cmp #GRID_H
    bne stpNextOk
    lda #0
stpNextOk:
    tay
    clc
    lda stpBLo
    adc rowOffLo, y
    sta zpNextLo
    lda stpBHi
    adc rowOffHi, y
    sta zpNextHi

    rts

stpBLo: .byte 0
stpBHi: .byte 0

; ---------------------------------------------------------------------------
; setDstRowPtr -- zpDstLo/Hi <- start of zpRow in the INACTIVE buffer.
; ---------------------------------------------------------------------------
setDstRowPtr:
    jsr getNextBase
    ldy zpRow
    clc
    adc rowOffLo, y
    sta zpDstLo
    txa
    adc rowOffHi, y
    sta zpDstHi
    rts

; ---------------------------------------------------------------------------
; getCurrBase / getNextBase -- return base address of active/inactive buffer.
; Returns: A = lo byte, X = hi byte.
; ---------------------------------------------------------------------------
getCurrBase:
    lda zpBufSel
    bne gcbGrid1
    lda #GRID0_LO
    ldx #GRID0_HI
    rts
gcbGrid1:
    lda #GRID1_LO
    ldx #GRID1_HI
    rts

getNextBase:
    lda zpBufSel
    beq gnbGrid1
    lda #GRID0_LO
    ldx #GRID0_HI
    rts
gnbGrid1:
    lda #GRID1_LO
    ldx #GRID1_HI
    rts

; ---------------------------------------------------------------------------
; lfsrStep -- advance the 8-bit Galois LFSR; new state left in A and zpLfsr.
; ---------------------------------------------------------------------------
lfsrStep:
    lda zpLfsr
    lsr
    bcc lfsrNFB
    eor #$B8
lfsrNFB:
    sta zpLfsr
    rts

; ---------------------------------------------------------------------------
; Read-only data tables
; ---------------------------------------------------------------------------
cellCharTbl:
    .byte CHAR_DEAD
    .byte CHAR_LIVE

rowOffLo:
    .byte $00,$28,$50,$78,$A0,$C8,$F0
    .byte $18,$40,$68,$90,$B8,$E0
    .byte $08,$30,$58,$80,$A8,$D0,$F8
    .byte $20,$48,$70,$98

rowOffHi:
    .byte $00,$00,$00,$00,$00,$00,$00
    .byte $01,$01,$01,$01,$01,$01
    .byte $02,$02,$02,$02,$02,$02,$02
    .byte $03,$03,$03,$03

; ---------------------------------------------------------------------------
; drawStatusLine -- write the keybinding reminder to screen row 24.
; Bytes below are precomputed C64 screencodes for the string
; "space=pause  r=random  c=clear  q=quit" (ca65 has no direct equivalent
; of Kick's .encoding "screencode_mixed" pragma, so the conversion is done
; once, offline, instead of at assemble time).
; ---------------------------------------------------------------------------
drawStatusLine:
    ldx #0
dslLoop:
    lda statusText, x
    sta SCREEN + STATUS_ROW_OFFSET, x
    inx
    cpx #STATUS_TEXT_LEN
    bne dslLoop
    rts

statusText:
    .byte $13, $10, $01, $03, $05, $3D, $10, $01, $15, $13, $05, $20, $20
    .byte $12, $3D, $12, $01, $0E, $04, $0F, $0D, $20, $20, $03, $3D, $03
    .byte $0C, $05, $01, $12, $20, $20, $11, $3D, $11, $15, $09, $14
statusTextEnd:
STATUS_TEXT_LEN = statusTextEnd - statusText
