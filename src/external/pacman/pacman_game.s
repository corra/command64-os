; src/external/pacman/pacman_game.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Pac-Man Game Engine layout & rendering.

.include "command64.inc"
.include "common.inc"

.export clearScreen
.export drawMaze
.export resetItems
.export drawGridCell
.export getWallCell
.export getItemCell
.export setItemCell



.segment "BSS"
mazeItems: .res 672

.segment "RODATA"
wallCharTable:
    .byte $20 ; 0 = empty space
    .byte $40 ; 1 = horizontal top line
    .byte $40 ; 2 = horizontal bottom line
    .byte $42 ; 3 = vertical left line
    .byte $42 ; 4 = vertical right line
    .byte $55 ; 5 = top-left corner
    .byte $49 ; 6 = top-right corner
    .byte $4a ; 7 = bottom-left corner
    .byte $4b ; 8 = bottom-right corner
    .byte 96 ; 9 = solid fill block (second SPACE)
    .byte $40 ; 10 = door/gate

.segment "CODE"

; --- Offsets for row * 40 ---
rowOffLo:
    .byte 0, 40, 80, 120, 160, 200, 240, 24, 64, 104, 144, 184, 224, 8, 48, 88, 128, 168, 208, 248, 32, 72, 112, 152
rowOffHi:
    .byte 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3

; --- Offsets for row * 28 ---
rowOff28Lo:
    .byte <(0*28), <(1*28), <(2*28), <(3*28), <(4*28), <(5*28), <(6*28), <(7*28)
    .byte <(8*28), <(9*28), <(10*28), <(11*28), <(12*28), <(13*28), <(14*28), <(15*28)
    .byte <(16*28), <(17*28), <(18*28), <(19*28), <(20*28), <(21*28), <(22*28), <(23*28)
rowOff28Hi:
    .byte >(0*28), >(1*28), >(2*28), >(3*28), >(4*28), >(5*28), >(6*28), >(7*28)
    .byte >(8*28), >(9*28), >(10*28), >(11*28), >(12*28), >(13*28), >(14*28), >(15*28)
    .byte >(16*28), >(17*28), >(18*28), >(19*28), >(20*28), >(21*28), >(22*28), >(23*28)

; ---------------------------------------------------------------------------
; clearScreen -- Fills screen RAM with spaces ($20) and color RAM with black
; ---------------------------------------------------------------------------
clearScreen:
    lda #CHAR_EMPTY
    ldx #0
@loop:
    sta SCREEN, x
    sta SCREEN+256, x
    sta SCREEN+512, x
    inx
    bne @loop
    ldy #0
@tail:
    sta SCREEN+768, y
    iny
    cpy #232
    bne @tail

    ; Color RAM fills with black
    lda #COLOR_BLACK
    ldx #0
@clrloop:
    sta COLORRAM, x
    sta COLORRAM+256, x
    sta COLORRAM+512, x
    inx
    bne @clrloop
    ldy #0
@clrtail:
    sta COLORRAM+768, y
    iny
    cpy #232
    bne @clrtail
    rts

; ---------------------------------------------------------------------------
; resetItems -- regenerate mazeItems from mazeWalls (open cell -> dot/pellet),
; factoring in the ghost house, warp tunnels, spawn tiles, and corner pellets.
; ---------------------------------------------------------------------------
resetItems:
    lda #<mazeItems
    sta zpTmpPtrLo
    lda #>mazeItems
    sta zpTmpPtrHi
    lda #<mazeWalls
    sta zpTmpDistLo
    lda #>mazeWalls
    sta zpTmpDistHi
    
    lda #0
    sta dotsRemainingLo
    sta dotsRemainingHi
    sta zpTmpRow
    sta zpTmpCol

@rowLoop:
@colLoop:
    ldy #0
    lda (zpTmpDistLo), y
    beq @isOpenPath
    cmp #11
    beq @setPellet
    jmp @setNone

@isOpenPath:
    ; Warp tunnels (row 10, cols 0-4 and 23-27)
    lda zpTmpRow
    cmp #10
    bne @notTunnel
    lda zpTmpCol
    cmp #5
    bcc @setNone
    cmp #23
    bcs @setNone
@notTunnel:

    ; Ghost house interior (row 12, cols 11-16)
    lda zpTmpRow
    cmp #12
    bne @notHouse
    lda zpTmpCol
    cmp #11
    bcc @notHouse
    cmp #17
    bcc @setNone
@notHouse:

    ; Pac-man spawn (row 16, cols 13-14)
    lda zpTmpRow
    cmp #16
    bne @notSpawn
    lda zpTmpCol
    cmp #13
    beq @setNone
    cmp #14
    beq @setNone
@notSpawn:

@setDot:
    lda #ITEM_DOT
    jmp @incItems

@setPellet:
    lda #ITEM_PELLET
@incItems:
    pha
    inc dotsRemainingLo
    bne :+
    inc dotsRemainingHi
:   pla
    jmp @writeItem

@setNone:
    lda #ITEM_NONE

@writeItem:
    ldy #0
    sta (zpTmpPtrLo), y

    ; Advance pointers
    clc
    lda zpTmpPtrLo
    adc #1
    sta zpTmpPtrLo
    lda zpTmpPtrHi
    adc #0
    sta zpTmpPtrHi

    clc
    lda zpTmpDistLo
    adc #1
    sta zpTmpDistLo
    lda zpTmpDistHi
    adc #0
    sta zpTmpDistHi

    inc zpTmpCol
    lda zpTmpCol
    cmp #28
    beq :+
    jmp @colLoop
:

    inc zpTmpRow
    lda zpTmpRow
    cmp #24
    beq @done
    
    ; Reset col
    lda #0
    sta zpTmpCol
    jmp @rowLoop
@done:
    rts

; ---------------------------------------------------------------------------
; drawMaze -- Full-screen redraw of the centered 28x24 grid
; ---------------------------------------------------------------------------
drawMaze:
    lda #0
    sta zpTmpRow
    sta zpTmpCol
@rowLoop:
@colLoop:
    jsr drawGridCell
    inc zpTmpCol
    lda zpTmpCol
    cmp #28
    bne @colLoop

    inc zpTmpRow
    lda zpTmpRow
    cmp #24
    beq @done
    
    lda #0
    sta zpTmpCol
    jmp @rowLoop
@done:
    rts

; ---------------------------------------------------------------------------
; getCellIndex -- Computes row*28 + col into zpTmpPtrLo/Hi
; ---------------------------------------------------------------------------
getCellIndex:
    ldy zpTmpRow
    lda rowOff28Lo, y
    clc
    adc zpTmpCol
    sta zpTmpPtrLo
    lda rowOff28Hi, y
    adc #0
    sta zpTmpPtrHi
    rts

; ---------------------------------------------------------------------------
; getWallCell -- returns wall type at (zpTmpRow, zpTmpCol) in A
; ---------------------------------------------------------------------------
getWallCell:
    jsr getCellIndex
    lda zpTmpPtrLo
    clc
    adc #<mazeWalls
    sta zpTmpPtrLo
    lda zpTmpPtrHi
    adc #>mazeWalls
    sta zpTmpPtrHi
    ldy #0
    lda (zpTmpPtrLo), y
    rts

; ---------------------------------------------------------------------------
; getItemCell -- returns item type at (zpTmpRow, zpTmpCol) in A
; ---------------------------------------------------------------------------
getItemCell:
    jsr getCellIndex
    lda zpTmpPtrLo
    clc
    adc #<mazeItems
    sta zpTmpPtrLo
    lda zpTmpPtrHi
    adc #>mazeItems
    sta zpTmpPtrHi
    ldy #0
    lda (zpTmpPtrLo), y
    rts

; ---------------------------------------------------------------------------
; setItemCell -- writes item type in A to (zpTmpRow, zpTmpCol)
; ---------------------------------------------------------------------------
setItemCell:
    pha
    jsr getCellIndex
    lda zpTmpPtrLo
    clc
    adc #<mazeItems
    sta zpTmpPtrLo
    lda zpTmpPtrHi
    adc #>mazeItems
    sta zpTmpPtrHi
    pla
    ldy #0
    sta (zpTmpPtrLo), y
    rts

; ---------------------------------------------------------------------------
; drawGridCell -- Render screen/color values for (zpTmpRow, zpTmpCol)
; ---------------------------------------------------------------------------
drawGridCell:
    jsr getWallCell
    beq @drawPath
    cmp #11
    beq @drawPath
    cmp #10
    beq @drawDoor

    ; It is a wall code (1 to 9). Resolve the character!
    tax
    lda wallCharTable, x
    ldx #COLOR_BLUE
    jmp @writeToScreen

@drawPath:
    jsr getItemCell
    cmp #ITEM_DOT
    beq @drawDot
    cmp #ITEM_PELLET
    beq @drawPellet
    cmp #ITEM_FRUIT
    beq @drawFruit

    lda #CHAR_EMPTY
    ldx #COLOR_BLACK
    jmp @writeToScreen

@drawDoor:
    lda #$40 ; horizontal door line
    ldx #COLOR_WHITE
    jmp @writeToScreen

@drawDot:
    lda #CHAR_DOT
    ldx #COLOR_WHITE
    jmp @writeToScreen

@drawPellet:
    lda #$51 ; centered large dot (solid ball)
    ldx #COLOR_YELLOW
    jmp @writeToScreen

@drawFruit:
    lda #6 ; 'F'
    ldx #COLOR_RED

@writeToScreen:
    pha
    txa
    pha

    lda zpTmpCol
    clc
    adc #6
    clc
    ldy zpTmpRow
    adc rowOffLo, y
    sta zpTmpPtrLo
    lda rowOffHi, y
    adc #>SCREEN
    sta zpTmpPtrHi

    lda zpTmpCol
    clc
    adc #6
    clc
    ldy zpTmpRow
    adc rowOffLo, y
    sta zpTmpDistLo
    lda rowOffHi, y
    adc #>COLORRAM
    sta zpTmpDistHi

    pla
    ldy #0
    sta (zpTmpDistLo), y
    pla
    sta (zpTmpPtrLo), y
    rts

; ---------------------------------------------------------------------------
; mazeWalls -- 28x24 wall definition. 0=Open path, 1-2=H-lines, 3-4=V-lines, 
;              5-8=Corners, 9=Solid block, 10=Door.
; ---------------------------------------------------------------------------
    ; 0 = empty space
    ; 1 = horizontal top line
    ; 2 = horizontal bottom line
    ; 3 = vertical left line
    ; 4 = vertical right line
    ; 5 = top-left corner
    ; 6 = top-right corner
    ; 7 = bottom-left corner
    ; 8 = bottom-right corner
    ; 9 = solid fill block
    ; 10 = door/gate
    ; 11 = Large Dot (Power Pellet)

mazeWalls:
    .byte 5,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,6 ; Row 0
    .byte 3,0,0,0,0,0,0,0,0,0,0,0,0,3,4,0,0,0,0,0,0,0,0,0,0,0,0,4 ; Row 1
    .byte 3,0,5,1,1,6,0,5,1,1,1,6,0,3,4,0,5,1,1,1,6,0,5,1,1,6,0,4 ; Row 2
    .byte 3,11,7,2,2,8,0,7,2,2,2,8,0,7,8,0,7,2,2,2,8,0,7,2,2,8,11,4 ; Row 3
    .byte 3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4 ; Row 4
    .byte 3,0,5,1,1,6,0,5,6,0,5,1,1,1,1,1,1,6,0,5,6,0,5,1,1,6,0,4 ; Row 5
    .byte 3,0,7,2,2,8,0,3,4,0,7,2,2,6,5,2,2,8,0,3,4,0,7,2,2,8,0,4 ; Row 6
    .byte 3,0,0,0,0,0,0,3,4,0,0,0,0,3,4,0,0,0,0,3,4,0,0,0,0,0,0,4 ; Row 7
    .byte 5,1,1,1,1,6,0,3,7,1,1,6,0,3,4,0,5,1,1,8,4,0,5,1,1,1,1,6 ; Row 8
    .byte 3,9,9,9,9,4,0,7,2,2,2,8,0,7,8,0,7,2,2,2,8,0,3,9,9,9,9,4 ; Row 9
    .byte 3,9,9,9,9,4,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,3,9,9,9,9,4 ; Row 10
    .byte 7,9,9,9,9,8,0,5,6,0,5,1,1,10,10,1,1,6,0,5,6,0,7,9,9,9,9,8 ; Row 11
    .byte 3,9,9,9,9,4,0,3,4,0,3,0,0,0,0,0,0,3,0,3,4,0,3,9,9,9,9,4 ; Row 12
    .byte 5,9,9,9,9,6,0,3,4,0,7,1,1,1,1,1,1,8,0,3,4,0,5,9,9,9,9,6 ; Row 13
    .byte 3,9,9,9,9,4,0,3,4,0,0,0,0,0,0,0,0,0,0,3,4,0,3,9,9,9,9,4 ; Row 14
    .byte 7,2,2,2,2,8,0,7,8,0,1,1,1,1,1,1,1,1,0,7,8,0,7,2,2,2,2,8 ; Row 15
    .byte 3,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,4 ; Row 16
    .byte 3,0,1,1,1,6,0,1,1,1,1,1,0,5,6,0,1,1,1,1,1,0,5,1,1,1,0,4 ; Row 17
    .byte 3,11,0,0,3,4,0,0,0,0,0,0,0,3,4,0,0,0,0,0,0,0,3,4,0,0,11,4 ; Row 18
    .byte 3,1,1,0,7,8,0,5,6,0,1,1,1,9,9,1,1,1,0,5,6,0,7,8,0,1,1,4 ; Row 19
    .byte 3,0,0,0,0,0,0,3,4,0,0,0,0,3,4,0,0,0,0,3,4,0,0,0,0,0,0,4 ; Row 20
    .byte 3,0,1,1,1,1,1,2,2,1,1,1,0,3,4,0,1,1,1,2,2,1,1,1,1,1,0,4 ; Row 21
    .byte 3,0,0,0,0,0,0,0,0,0,0,0,0,3,4,0,0,0,0,0,0,0,0,0,0,0,0,4 ; Row 22
    .byte 7,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,2,8 ; Row 23
