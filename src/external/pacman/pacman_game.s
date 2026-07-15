; src/external/pacman/pacman_game.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Pac-Man Game Engine layout & rendering.

.include "command64.inc"
.include "common.inc"

.export clearScreen
.export drawMaze

.segment "CODE"

; ---------------------------------------------------------------------------
; clearScreen -- Fills screen RAM with spaces ($20) and color RAM with white
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
; drawMaze -- Proves rendering works by drawing a border
; ---------------------------------------------------------------------------
drawMaze:
    ; Draw blue border around the center 28x24 grid area
    ; Screen columns 6 to 33, rows 0 to 23
    ; We will just color color RAM in the active area to prove it works
    lda #COLOR_BLUE
    ldy #0
@rowLoop:
    ; Center is columns 6 to 33 (length 28)
    ldx #6
@colLoop:
    ; Compute screen address: SCREEN + row*40 + col
    ; We will just draw a wall character at top row (row 0)
    lda #CHAR_WALL
    sta SCREEN + 0*40, x
    sta SCREEN + 23*40, x
    
    inx
    cpx #34
    bne @colLoop
    iny
    cpy #24
    bne @rowLoop
    rts
