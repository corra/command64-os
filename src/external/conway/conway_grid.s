; src/external/conway/conway_grid.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; conway's grid/drawing half. Split out from conway_main.s on purpose: it
; .exports the routines conway_main.s calls, so ld65 resolves cross-module
; references instead of everything living in one flat file (this is a
; genuine multi-object-file ca65 app, unlike Kick Assembler's single-file
; conway.asm).

.include "command64.inc"
.include "common.inc"
.include "screencode.inc"

.export randomizeGrid
.export drawGrid
.export drawStatusLine
.export computeNext
.export clearGrid
.export clearScreen
.export loadPreset
.export toggleBirth
.export toggleSurvival
.export getBirthRule
.export getSurvivalRule

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
    ldx zpCount
    lda ruleSurvival, x
    jmp cnStoreRule

cnDead:
    ldx zpCount
    lda ruleBirth, x

cnStoreRule:
    and #1
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
    lda #<grid0
    ldx #>grid0
    rts
gcbGrid1:
    lda #<grid1
    ldx #>grid1
    rts

getNextBase:
    lda zpBufSel
    beq gnbGrid1
    lda #<grid0
    ldx #>grid0
    rts
gnbGrid1:
    lda #<grid1
    ldx #>grid1
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
; loadPreset -- expand compact 9-bit B/S masks into hot-path lookup tables.
; Input:  A = preset index (0..PRESET_COUNT-1)
; Output: C clear on success; C set if A is out of range.
; Clobbers: A, X, Y, N, Z. On failure, active rules and zpPresetIdx are intact.
; ---------------------------------------------------------------------------
loadPreset:
    cmp #PRESET_COUNT
    bcs lpInvalid
    pha
    asl
    tax

    lda presetBirthMasks, x
    sta ruleMaskScratch
    ldy #0
lpBirthLoop:
    lsr ruleMaskScratch
    lda #0
    rol
    sta ruleBirth, y
    iny
    cpy #8
    bne lpBirthLoop
    lda presetBirthMasks + 1, x
    and #1
    sta ruleBirth + 8

    lda presetSurvivalMasks, x
    sta ruleMaskScratch
    ldy #0
lpSurvivalLoop:
    lsr ruleMaskScratch
    lda #0
    rol
    sta ruleSurvival, y
    iny
    cpy #8
    bne lpSurvivalLoop
    lda presetSurvivalMasks + 1, x
    and #1
    sta ruleSurvival + 8

    pla
    sta zpPresetIdx
    clc
    rts

lpInvalid:
    sec
    rts

; ---------------------------------------------------------------------------
; toggleBirth / toggleSurvival -- toggle one active neighbour count.
; Input: X = neighbour count (0..8)
; Output: C clear on success; C set if X is out of range.
; Preserves: X, Y. Clobbers: A, N, Z. A valid toggle marks the rule custom.
; ---------------------------------------------------------------------------
toggleBirth:
    cpx #RULE_COUNT
    bcs tbInvalid
    lda ruleBirth, x
    eor #1
    sta ruleBirth, x
    lda #PRESET_CUSTOM
    sta zpPresetIdx
    clc
    rts
tbInvalid:
    sec
    rts

toggleSurvival:
    cpx #RULE_COUNT
    bcs tsInvalid
    lda ruleSurvival, x
    eor #1
    sta ruleSurvival, x
    lda #PRESET_CUSTOM
    sta zpPresetIdx
    clc
    rts
tsInvalid:
    sec
    rts

; ---------------------------------------------------------------------------
; getBirthRule / getSurvivalRule -- read one active rule-table entry.
; Input: X = neighbour count (0..8)
; Output: A = 0/1 and C clear; invalid X returns A=0 and C set.
; Preserves: X, Y.
; ---------------------------------------------------------------------------
getBirthRule:
    cpx #RULE_COUNT
    bcs gbrInvalid
    lda ruleBirth, x
    clc
    rts
gbrInvalid:
    lda #0
    sec
    rts

getSurvivalRule:
    cpx #RULE_COUNT
    bcs gsrInvalid
    lda ruleSurvival, x
    clc
    rts
gsrInvalid:
    lda #0
    sec
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
; Uses include/ca65/screencode.inc's screencode_mixed/petscii_mixed
; macros, mirroring Kick's ".encoding "screencode_mixed"" toggle idiom
; (conway.asm:711/715) -- these macros were built and verified specifically
; against this string's previous hand-encoded bytes.
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

screencode_mixed
statusText:
    .byte "space=pause  r=random  c=clear  q=quit"
statusTextEnd:
petscii_mixed
STATUS_TEXT_LEN = statusTextEnd - statusText

; Compact preset database: each entry is a low/high pair for neighbour
; counts 0..7 and count 8 (high bit 0). loadPreset expands one pair into each
; private 9-byte lookup table before publishing zpPresetIdx.
presetBirthMasks:
    .byte $08,$00               ; 1. Conway's Life: B3
    .byte $08,$00               ; 2. Ant Colony: B3
    .byte $18,$00               ; 3. World on Fire: B34
    .byte $38,$00               ; 4. Blinkers: B345
    .byte $08,$00               ; 5. Mazectric: B3
    .byte $08,$00               ; 6. Maze: B3
    .byte $08,$00               ; 7. Life without Death: B3
    .byte $08,$00               ; 8. Coral: B3
    .byte $08,$00               ; 9. Assimilation: B3

presetSurvivalMasks:
    .byte $0C,$00               ; 1. Conway's Life: S23
    .byte $1C,$00               ; 2. Ant Colony: S234
    .byte $0C,$00               ; 3. World on Fire: S23
    .byte $04,$00               ; 4. Blinkers: S2
    .byte $1E,$00               ; 5. Mazectric: S1234
    .byte $3E,$00               ; 6. Maze: S12345
    .byte $FF,$01               ; 7. Life without Death: S012345678
    .byte $F0,$01               ; 8. Coral: S45678
    .byte $F0,$00               ; 9. Assimilation: S4567

; Emitted mutable state: it must remain inside the relocatable app extent.
ruleBirth:
    .res 9, 0
ruleSurvival:
    .res 9, 0
ruleMaskScratch:
    .byte 0

; ---------------------------------------------------------------------------
; Runtime buffers (relocatable, page-aligned)
; ---------------------------------------------------------------------------
.align 256
grid0:
    .res 960, 0
.align 256
grid1:
    .res 960, 0
