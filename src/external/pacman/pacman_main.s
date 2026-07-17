; src/external/pacman/pacman_main.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Pac64 — Pac-Man for Command 64 OS. Modular ca65 rewrite.

.include "command64.inc"
.include "common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "9"
.include "build_pacman.inc"

.import __MAIN_START__
.import clearScreen
.import drawMaze
.import resetItems
.import drawGridCell
.import getItemCell
.import setItemCell
.import getWallCell

; Ghost AI imports
.import ghostRow
.import ghostCol
.import ghostDir
.import ghostTimer
.import ghostMode
.import initGhosts
.import updateGhostAI
.import getGhostColor
.import getGhostSpeed
.import updateCycleScheduler
.import triggerFrightenedMode
.import zpCycleStep
.import recordReleaseDot
.import resetReleaseIdleTimer
.import tickReleaseIdleTimer
.import initReleaseStateForLevel
.import initReleaseStateForLifeLoss

.segment "HEADER"
    .word __MAIN_START__
.segment "BSS"
scoreLo:  .res 1
scoreMid: .res 1
scoreHi:  .res 1

remLo:    .res 1
remMid:   .res 1
remHi:    .res 1

.segment "RODATA"

; --- Offsets for row * 40 ---
rowOffLo:
    .byte 0, 40, 80, 120, 160, 200, 240, 24, 64, 104, 144, 184, 224, 8, 48, 88, 128, 168, 208, 248, 32, 72, 112, 152
rowOffHi:
    .byte 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 3, 3, 3, 3

.segment "CODE"

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------
start:
    ; Switch to graphics mode (PETSCII set 1)
    lda #$8E
    jsr KernalChROUT

    ; Initialize game variables
    lda #1
    sta zpLevel
    lda #3
    sta zpLives
    lda #STATE_PLAYING
    sta zpGameState
    lda #0
    sta zpPaused
    sta scoreLo
    sta scoreMid
    sta scoreHi
    sta zpExtraLifeAwarded
    sta zpPostDeathRelease

    lda JIFFY_CLK
    sta zpLastJiffy

    ; Set border and background to black
    lda #COLOR_BLACK
    sta $D020
    sta $D021

    jsr clearScreen
    jsr resetItems
    lda dotsRemainingLo
    sta zpTotalDots
    jsr initReleaseStateForLevel
    jsr drawMaze
    jsr resetPositions
    jsr drawStatusLabels
    jsr renderStatusRow
    jsr showReadyBanner
    lda JIFFY_CLK
    sta zpLastJiffy

; ---------------------------------------------------------------------------
; Main game loop
; ---------------------------------------------------------------------------
mainLoop:
    jsr handleKeys

    ; Check freeze timer
    lda zpFreezeTimer
    beq :+
    
    ; Ticks down freeze timer on jiffy clock
    lda JIFFY_CLK
    cmp zpLastJiffy
    beq mainLoop
    sta zpLastJiffy
    
    dec zpFreezeTimer
    jmp mainLoop
:
    ; Check if game paused
    lda zpPaused
    bne mainLoop

    ; Check if a tick elapsed (compare JIFFY_CLK to zpLastJiffy)
    lda JIFFY_CLK
    cmp zpLastJiffy
    beq mainLoop
    sta zpLastJiffy

    ; Level state check
    lda zpGameState
    cmp #STATE_LEVEL_CLEAR
    bne @checkLifeLost

    ; Flash border 4 times (8 toggles)
    ldx #7
@flashLoop:
    txa
    and #1
    bne :+
    lda #COLOR_BLACK
    jmp :++
:   lda #COLOR_WHITE
:   sta $D020

    stx zpGhostIdx
    jsr delay15
    ldx zpGhostIdx

    dex
    bpl @flashLoop

    ; Restore border to black
    lda #COLOR_BLACK
    sta $D020

    ; Advance level
    inc zpLevel
    lda #0
    sta zpPostDeathRelease
    jsr resetItems
    lda dotsRemainingLo
    sta zpTotalDots
    jsr initReleaseStateForLevel
    jsr drawMaze
    jsr resetPositions
    jsr renderStatusRow
    jsr showReadyBanner
    lda JIFFY_CLK
    sta zpLastJiffy
    lda #STATE_PLAYING
    sta zpGameState
    jmp mainLoop

@checkLifeLost:
    cmp #STATE_LIFE_LOST
    bne @checkGameOver

    lda #STATE_LIFE_LOST
    sta zpGameState
    lda #1
    sta zpPostDeathRelease
    jsr initReleaseStateForLifeLoss
    ; Restore the maze first, then draw actors at their reset positions.
    jsr drawMaze
    jsr resetPositions
    jsr showReadyBanner
    lda JIFFY_CLK
    sta zpLastJiffy
    lda #STATE_PLAYING
    sta zpGameState
    jmp mainLoop

@checkGameOver:
    cmp #STATE_GAME_OVER
    bne :+
    jmp mainLoop
:

@gameplay:
    jsr updateCycleScheduler
    jsr tickReleaseIdleTimer

    ; Ticks down fruit active timer
    lda zpFruitTimerLo
    ora zpFruitTimerHi
    beq @skipFruitTimer
    
    lda zpFruitTimerLo
    bne :+
    dec zpFruitTimerHi
:   dec zpFruitTimerLo
    
    lda zpFruitTimerLo
    ora zpFruitTimerHi
    bne @skipFruitTimer
    
    jsr despawnFruit
@skipFruitTimer:

    ; Decrement Pac-man move timer
    dec zpPacTimer
    bne @skipPacMove
    jsr getPacSpeed
    sta zpPacTimer
    jsr updatePacman
    jsr checkActiveGhostCollision
    bcc :+
    jmp mainLoop
:
@skipPacMove:

    jsr updateGhosts
    jsr checkActiveGhostCollision
    jmp mainLoop

; ---------------------------------------------------------------------------
; resetPositions -- Resets Pac-Man to starting position & speed
; ---------------------------------------------------------------------------
resetPositions:
    lda #16
    sta zpPacRow
    lda #13
    sta zpPacCol
    lda #DIR_LEFT
    sta zpPacDir
    lda #DIR_NONE
    sta zpPacNextDir
    
    jsr getPacSpeed
    sta zpPacTimer
    
    jsr drawPacman

    jsr initGhosts
    ldx #3
@loop:
    stx zpGhostIdx
    jsr drawGhost
    ldx zpGhostIdx
    dex
    bpl @loop
    rts

; ---------------------------------------------------------------------------
; getPacSpeed -- Gets Pac-Man reload speed based on level (lower is faster)
; ---------------------------------------------------------------------------
getPacSpeed:
    lda zpLevel
    sec
    sbc #1
    cmp #4
    bcc :+
    lda #4
:   tax
    lda pacSpeedTbl, x
    rts

pacSpeedTbl: .byte 8, 6, 6, 6, 6

; ---------------------------------------------------------------------------
; updatePacman -- Resolves keyboard/joystick input and moves Pac-Man
; ---------------------------------------------------------------------------
updatePacman:
    ; 1. Try to turn to zpPacNextDir if valid
    lda zpPacNextDir
    cmp #DIR_NONE
    beq @keepDir
    
    jsr canMovePac
    bcc @keepDir
    
    ; Next direction is valid! Make it the current direction
    lda zpPacNextDir
    sta zpPacDir
    lda #DIR_NONE
    sta zpPacNextDir
    jmp @doMove

@keepDir:
    ; 2. Continue in current direction
    lda zpPacDir
    cmp #DIR_NONE
    beq @done
    
    jsr canMovePac
    bcc @done

@doMove:
    ; Save target coordinates on stack
    lda zpTmpRow
    pha
    lda zpTmpCol
    pha

    ; Erase Pac-Man from current location
    lda zpPacRow
    sta zpTmpRow
    lda zpPacCol
    sta zpTmpCol
    jsr drawGridCell
    
    ; Retrieve target coordinates
    pla
    sta zpPacCol
    sta zpTmpCol
    pla
    sta zpPacRow
    sta zpTmpRow
    
    ; Consume item and redraw Pac-Man
    jsr consumeItem
    jsr drawPacman
    rts
@done:
    rts

; ---------------------------------------------------------------------------
; checkActiveGhostCollision -- Detect Pac-Man/Ghost tile overlap.
; Returns carry set when a life-loss/game-over transition was started.
; Frightened/eaten collisions are reserved for their later score behavior.
; ---------------------------------------------------------------------------
eatenScoreLo:
    .byte <200, <400, <800, <1600
eatenScoreHi:
    .byte >200, >400, >800, >1600

checkActiveGhostCollision:
    lda zpGameState
    cmp #STATE_PLAYING
    bne @noCollision

    ldx #3
@loop:
    stx zpGhostIdx
    lda ghostMode, x
    cmp #MODE_EATEN
    beq @next
    
    lda zpPacRow
    cmp ghostRow, x
    bne @next
    lda zpPacCol
    cmp ghostCol, x
    bne @next

    ; Collision detected!
    ; Check if ghost is frightened
    lda ghostMode, x
    cmp #MODE_FRIGHTENED
    bne @normalGhostCollision

    ; --- Frightened Ghost Collision (Eat Ghost) ---
    lda zpGhostsEatenCount
    cmp #4
    bcc :+
    lda #3
:   tay
    
    lda eatenScoreLo, y
    ldx eatenScoreHi, y
    txa
    tay ; Y gets Hi byte
    jsr addScore16
    
    inc zpGhostsEatenCount
    
    ldx zpGhostIdx
    lda #MODE_EATEN
    sta ghostMode, x
    
    ; Erase and draw eyes immediately
    lda ghostRow, x
    sta zpTmpRow
    lda ghostCol, x
    sta zpTmpCol
    jsr drawGridCell
    ldx zpGhostIdx
    jsr drawGhost
    
    ; Set freeze timer (30 jiffies = 0.5s)
    lda #30
    sta zpFreezeTimer
    
    jmp @next

@normalGhostCollision:
    jsr playDeathAnimation
    dec zpLives
    bne @lifeLost

    lda #STATE_GAME_OVER
    sta zpGameState
    lda #1
    sta zpPaused
    jsr renderStatusRow
    sec
    rts

@next:
    ldx zpGhostIdx
    dex
    bpl @loop
@noCollision:
    clc
    rts

@lifeLost:
    lda #STATE_LIFE_LOST
    sta zpGameState
    sec
    rts

; ---------------------------------------------------------------------------
; canMovePac -- Checks if Pac-Man can move in direction in A.
; Returns target coordinates in zpTmpRow/zpTmpCol.
; Carry set if legal, carry clear if blocked.
; ---------------------------------------------------------------------------
canMovePac:
    sta zpTmpVal ; save direction
    lda zpPacRow
    sta zpTmpRow
    lda zpPacCol
    sta zpTmpCol
    
    lda zpTmpVal
    cmp #DIR_UP
    bne @chkDown
    dec zpTmpRow
    jmp @checkBounds
@chkDown:
    cmp #DIR_DOWN
    bne @chkLeft
    inc zpTmpRow
    jmp @checkBounds
@chkLeft:
    cmp #DIR_LEFT
    bne @chkRight
    dec zpTmpCol
    jmp @checkBounds
@chkRight:
    cmp #DIR_RIGHT
    bne @done
    inc zpTmpCol

@checkBounds:
    ; Handle warp tunnel wrapping on row 10
    lda zpTmpRow
    cmp #10
    bne @noWrap
    lda zpTmpCol
    cmp #$FF
    bne @checkRightWrap
    lda #27
    sta zpTmpCol
    jmp @noWrap
@checkRightWrap:
    cmp #28
    bne @noWrap
    lda #0
    sta zpTmpCol
@noWrap:
    jsr getWallCell
    beq @allowMove
    cmp #11
    beq @allowMove
    jmp @blocked
@allowMove:
    sec
    rts
@blocked:
    clc
    rts
@done:
    clc
    rts

; ---------------------------------------------------------------------------
; drawPacman -- Draw Pac-Man at (zpPacRow, zpPacCol)
; ---------------------------------------------------------------------------
drawPacman:
    lda zpPacCol
    clc
    adc #6
    clc
    ldy zpPacRow
    adc rowOffLo, y
    sta zpTmpPtrLo
    lda rowOffHi, y
    adc #>SCREEN
    sta zpTmpPtrHi
    
    lda zpPacCol
    clc
    adc #6
    clc
    ldy zpPacRow
    adc rowOffLo, y
    sta zpTmpDistLo
    lda rowOffHi, y
    adc #>COLORRAM
    sta zpTmpDistHi
    
    ldy #0
    lda #COLOR_YELLOW
    sta (zpTmpDistLo), y
    lda #CHAR_PACMAN
    sta (zpTmpPtrLo), y
    rts

; ---------------------------------------------------------------------------
; consumeItem -- Process item at Pac-Man's location
; ---------------------------------------------------------------------------
consumeItem:
    lda zpPacRow
    sta zpTmpRow
    lda zpPacCol
    sta zpTmpCol
    jsr getItemCell
    cmp #ITEM_DOT
    beq @eatDot
    cmp #ITEM_PELLET
    beq @eatPellet
    cmp #ITEM_FRUIT
    beq @eatFruit
    rts

@eatFruit:
    lda #ITEM_NONE
    jsr setItemCell
    
    jsr getFruitScore
    jsr addScore16
    
    lda #0
    sta zpFruitTimerLo
    sta zpFruitTimerHi
    rts

@eatDot:
    lda #ITEM_NONE
    jsr setItemCell
    
    lda #10
    jsr addScoreLo
    jsr decDots
    
    ; Slowdown: +1 tick
    inc zpPacTimer
    rts

@eatPellet:
    lda #ITEM_NONE
    jsr setItemCell
    
    lda #50
    jsr addScoreLo
    jsr decDots
    
    ; Trigger Frightened Mode for ghosts
    jsr triggerFrightenedMode
    
    ; Slowdown: +3 ticks
    lda zpPacTimer
    clc
    adc #3
    sta zpPacTimer
    rts

; ---------------------------------------------------------------------------
; decDots -- Decrement remaining dots counter; the shared funnel for both
; dot and energizer consumption, so this is also where ghost-house release
; accounting (Phase 5) is driven exactly once per consumed item.
; ---------------------------------------------------------------------------
decDots:
    lda dotsRemainingLo
    bne @decLo
    dec dotsRemainingHi
@decLo:
    dec dotsRemainingLo

    jsr recordReleaseDot
    jsr resetReleaseIdleTimer

    ; Spawn fruit check: dots eaten = zpTotalDots - dotsRemainingLo
    lda zpTotalDots
    sec
    sbc dotsRemainingLo
    cmp #70
    beq @doSpawn
    cmp #170
    beq @doSpawn
    jmp @checkLevelClear
    
@doSpawn:
    jsr spawnFruit
    
@checkLevelClear:
    ; check if 0
    lda dotsRemainingLo
    ora dotsRemainingHi
    bne @done
    
    lda #STATE_LEVEL_CLEAR
    sta zpGameState
@done:
    rts

; ---------------------------------------------------------------------------
; addScoreLo -- Add points in A to 24-bit score
; ---------------------------------------------------------------------------
addScoreLo:
    clc
    adc scoreLo
    sta scoreLo
    lda scoreMid
    adc #0
    sta scoreMid
    lda scoreHi
    adc #0
    sta scoreHi
    jsr checkExtraLife
    jsr renderStatusRow
    rts

; ---------------------------------------------------------------------------
; addScore16 -- Add 16-bit points in A (Lo) and Y (Hi) to 24-bit score
; ---------------------------------------------------------------------------
addScore16:
    clc
    adc scoreLo
    sta scoreLo
    tya
    adc scoreMid
    sta scoreMid
    lda scoreHi
    adc #0
    sta scoreHi
    jsr checkExtraLife
    jsr renderStatusRow
    rts

; ---------------------------------------------------------------------------
; handleKeys -- Read keyboard (GETIN) & joystick port 2
; ---------------------------------------------------------------------------
handleKeys:
    ; 1. Read joystick port 2
    lda $DC00
    tay
    
    tya
    and #1 ; UP
    bne :+
    lda #DIR_UP
    sta zpPacNextDir
:   
    tya
    and #2 ; DOWN
    bne :+
    lda #DIR_DOWN
    sta zpPacNextDir
:   
    tya
    and #4 ; LEFT
    bne :+
    lda #DIR_LEFT
    sta zpPacNextDir
:   
    tya
    and #8 ; RIGHT
    bne :+
    lda #DIR_RIGHT
    sta zpPacNextDir
:

    ; 2. Read Keyboard
    jsr KernalGetIn
    beq @done
    
    cmp #'w'
    beq @setDirUp
    cmp #'W'
    beq @setDirUp
    
    cmp #'s'
    beq @setDirDown
    cmp #'S'
    beq @setDirDown
    
    cmp #'a'
    beq @setDirLeft
    cmp #'A'
    beq @setDirLeft
    
    cmp #'d'
    beq @setDirRight
    cmp #'D'
    beq @setDirRight
    
    cmp #'q'
    beq @exit
    cmp #'Q'
    beq @exit
    
    cmp #'p'
    beq @togglePause
    cmp #'P'
    beq @togglePause
    cmp #$20 ; SPACE
    beq @togglePause
@done:
    rts

@setDirUp:
    lda #DIR_UP
    sta zpPacNextDir
    rts
@setDirDown:
    lda #DIR_DOWN
    sta zpPacNextDir
    rts
@setDirLeft:
    lda #DIR_LEFT
    sta zpPacNextDir
    rts
@setDirRight:
    lda #DIR_RIGHT
    sta zpPacNextDir
    rts

@togglePause:
    lda zpPaused
    eor #1
    sta zpPaused
    rts

@exit:
    jmp exitToShell

; ---------------------------------------------------------------------------
; exitToShell -- Restore screen and return
; ---------------------------------------------------------------------------
exitToShell:
    ; Restore text mode (PETSCII set 2)
    lda #$0E
    jsr KernalChROUT

    lda #COLOR_BLACK
    sta $D020
    sta $D021
    jsr clearScreen

    ; Home cursor before printing exit banner
    lda #$13
    jsr KernalChROUT

    lda #<exitBanner
    ldy #>exitBanner
    jsr printString

    lda #DOS_EXIT
    jmp OS_API

; ---------------------------------------------------------------------------
; printString -- print a null-terminated PETSCII string via CHROUT.
; ---------------------------------------------------------------------------
printString:
    sta zpTmpPtrLo
    sty zpTmpPtrHi
    ldy #0
@loop:
    lda (zpTmpPtrLo), y
    beq @done
    jsr KernalChROUT
    iny
    jmp @loop
@done:
    rts

; ---------------------------------------------------------------------------
; drawStatusLabels -- Draw static text on row 24
; ---------------------------------------------------------------------------
drawStatusLabels:
    ; Set status color to light gray (1) or yellow (7) or white (1)
    lda #COLOR_WHITE
    ldx #0
@colorLoop:
    sta COLORRAM + 960 + 6, x
    inx
    cpx #28
    bne @colorLoop

    ; Draw "score:"
    ldx #0
@l1: lda labelScore, x
    sta SCREEN + 960 + 6, x
    inx
    cpx #6
    bne @l1

    ; Draw "lives:"
    ldx #0
@l2: lda labelLives, x
    sta SCREEN + 960 + 19, x
    inx
    cpx #6
    bne @l2

    ; Draw "level:"
    ldx #0
@l3: lda labelLevel, x
    sta SCREEN + 960 + 26, x  ; Shifted 1 column left (Col 26)
    inx
    cpx #6
    bne @l3
    rts

labelScore: .byte $13, $03, $0F, $12, $05, $3A ; "score:" in screen codes
labelLives: .byte $0C, $09, $16, $05, $13, $3A ; "lives:" in screen codes
labelLevel: .byte $0C, $05, $16, $05, $0C, $3A ; "level:" in screen codes

; ---------------------------------------------------------------------------
; renderStatusRow -- Render dynamic score, lives, and level values
; ---------------------------------------------------------------------------
renderStatusRow:
    jsr renderDecimalScore
    
    lda zpLives
    clc
    adc #$30
    sta SCREEN + 960 + 25
    
    lda zpLevel
    ldx #0
@div10:
    cmp #10
    bcc @divDone
    sec
    sbc #10
    inx
    jmp @div10
@divDone:
    pha
    txa
    clc
    adc #$30
    sta SCREEN + 960 + 32  ; Shifted 1 column left (Col 32)
    pla
    clc
    adc #$30
    sta SCREEN + 960 + 33  ; Shifted 1 column left (Col 33)
    rts

; ---------------------------------------------------------------------------
; renderDecimalScore -- Render 24-bit score as 6 digits on status row
; ---------------------------------------------------------------------------
renderDecimalScore:
    lda scoreLo
    sta remLo
    lda scoreMid
    sta remMid
    lda scoreHi
    sta remHi
    
    ldy #0
@digitLoop:
    lda #0
    sta zpTmpVal
@subLoop:
    jsr cmp24
    bcc @digitDone
    jsr sub24
    inc zpTmpVal
    jmp @subLoop
@digitDone:
    lda zpTmpVal
    clc
    adc #$30
    sta SCREEN + 960 + 12, y
    iny
    cpy #6
    bne @digitLoop
    rts

cmp24:
    lda remHi
    cmp placeHi, y
    bne @done
    lda remMid
    cmp placeMid, y
    bne @done
    lda remLo
    cmp placeLo, y
@done:
    rts

sub24:
    lda remLo
    sec
    sbc placeLo, y
    sta remLo
    lda remMid
    sbc placeMid, y
    sta remMid
    lda remHi
    sbc placeHi, y
    sta remHi
    rts

placeLo:  .byte $A0, $10, $E8, $64, $0A, $01     ; 100000, 10000, 1000, 100, 10, 1
placeMid: .byte $86, $27, $03, $00, $00, $00
placeHi:  .byte $01, $00, $00, $00, $00, $00

; ---------------------------------------------------------------------------
; updateGhosts -- Loops through all 4 ghosts to update their state and render
; ---------------------------------------------------------------------------
updateGhosts:
    ldx #3
@loop:
    stx zpGhostIdx
    
    ; Decrement ghost timer
    dec ghostTimer, x
    beq :+
    jmp @nextGhost
:
    
    ; Reload speed reload timer
    jsr getGhostSpeed
    ldx zpGhostIdx
    sta ghostTimer, x
    
    ; Erase ghost from current position
    lda ghostRow, x
    sta zpTmpRow
    lda ghostCol, x
    sta zpTmpCol
    jsr drawGridCell
    
    ; Update ghost direction via AI target math
    ldx zpGhostIdx
    jsr updateGhostAI
    
    ; Move ghost in direction
    ldx zpGhostIdx
    lda ghostDir, x
    cmp #DIR_UP
    bne :+
    dec ghostRow, x
    jmp @draw
:   cmp #DIR_DOWN
    bne :+
    inc ghostRow, x
    jmp @draw
:   cmp #DIR_LEFT
    bne :+
    dec ghostCol, x
    jmp @draw
:   cmp #DIR_RIGHT
    bne @draw
    inc ghostCol, x
    
@draw:
    ; Warp tunnel wrapping
    ldx zpGhostIdx
    lda ghostRow, x
    cmp #10
    bne @noWrap
    lda ghostCol, x
    cmp #$FF
    bne :+
    lda #27
    sta ghostCol, x
    jmp @noWrap
:   cmp #28
    bne @noWrap
    lda #0
    sta ghostCol, x
@noWrap:
    ; Revive check for eaten ghosts: transition EATEN -> EXITING so
    ; handleHouseExit routes the revived ghost through Col EXIT_DOOR_COL
    ; and the door under controlled exit logic (Phase 8). Revived ghosts
    ; leave without waiting on personal/global release counters.
    lda ghostMode, x
    cmp #MODE_EATEN
    bne @skipRevive
    lda ghostRow, x
    cmp #EATEN_REVIVE_ROW
    bne @skipRevive
    lda ghostCol, x
    cmp #EATEN_REVIVE_COL
    beq @revive
    cmp #EATEN_REVIVE_COL+1
    bne @skipRevive
@revive:
    lda #MODE_EXITING
    sta ghostMode, x
@skipRevive:
    jsr drawGhost
    
@nextGhost:
    ldx zpGhostIdx
    dex
    bpl :+
    rts
:   jmp @loop

; ---------------------------------------------------------------------------
; drawGhost -- Draws ghost in X at its row/col using single-carry 16-bit math
; ---------------------------------------------------------------------------
drawGhost:
    ldx zpGhostIdx
    ldy ghostRow, x
    
    ; Calculate screen RAM pointer (col + 6 + row offset)
    lda ghostCol, x
    clc
    adc #6
    clc
    ldy ghostRow, x
    adc rowOffLo, y
    sta zpTmpPtrLo
    lda rowOffHi, y
    adc #>SCREEN
    sta zpTmpPtrHi
    
    ; Calculate color RAM pointer
    ldx zpGhostIdx
    lda ghostCol, x
    clc
    adc #6
    clc
    ldy ghostRow, x
    adc rowOffLo, y
    sta zpTmpDistLo
    lda rowOffHi, y
    adc #>COLORRAM
    sta zpTmpDistHi
    
    ; Write color
    ldx zpGhostIdx
    jsr getGhostColor
    ldy #0
    sta (zpTmpDistLo), y
    
    ; Write character based on mode
    ldx zpGhostIdx
    lda ghostMode, x
    cmp #MODE_EATEN
    bne :+
    lda #CHAR_EYES
    jmp @write
:   lda ghostChars, x
@write:
    ldy #0
    sta (zpTmpPtrLo), y
    rts

ghostChars:
    .byte $02 ; 'B' for Blinky
    .byte $10 ; 'P' for Pinky
    .byte $09 ; 'I' for Inky
    .byte $03 ; 'C' for Clyde


exitBanner:
    .byte "PACMAN v", VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE
    .byte ".", BUILD_NUMBER, PetCr, 0

; ---------------------------------------------------------------------------
; spawnFruit -- Spawn fruit item on the fruit rest tile (resetItems keeps
; this tile permanently dot-free; see FRUIT_SPAWN_ROW/COL in common.inc)
; ---------------------------------------------------------------------------
spawnFruit:
    lda #FRUIT_SPAWN_ROW
    sta zpTmpRow
    lda #FRUIT_SPAWN_COL
    sta zpTmpCol
    lda #ITEM_FRUIT
    jsr setItemCell

    lda #FRUIT_SPAWN_ROW
    sta zpTmpRow
    lda #FRUIT_SPAWN_COL
    sta zpTmpCol
    jsr drawGridCell

    lda #<600
    sta zpFruitTimerLo
    lda #>600
    sta zpFruitTimerHi
    rts

; ---------------------------------------------------------------------------
; despawnFruit -- Despawn fruit from the fruit rest tile if present
; ---------------------------------------------------------------------------
despawnFruit:
    lda #FRUIT_SPAWN_ROW
    sta zpTmpRow
    lda #FRUIT_SPAWN_COL
    sta zpTmpCol
    jsr getItemCell
    cmp #ITEM_FRUIT
    bne @done

    lda #ITEM_NONE
    jsr setItemCell

    lda #FRUIT_SPAWN_ROW
    sta zpTmpRow
    lda #FRUIT_SPAWN_COL
    sta zpTmpCol
    jsr drawGridCell
@done:
    rts

; ---------------------------------------------------------------------------
; getFruitScore -- Returns fruit score Lo in A and Hi in Y based on level
; ---------------------------------------------------------------------------
getFruitScore:
    lda zpLevel
    sec
    sbc #1
    cmp #8
    bcc :+
    lda #7
:   tay
    lda fruitScoresLo, y
    pha
    lda fruitScoresHi, y
    tay ; Y gets Hi byte
    pla ; A gets Lo byte
    rts

fruitScoresLo:
    .byte <100, <300, <500, <700, <1000, <2000, <3000, <5000
fruitScoresHi:
    .byte >100, >300, >500, >700, >1000, >2000, >3000, >5000

; ---------------------------------------------------------------------------
; checkExtraLife -- Award 1 extra life at 10,000 points ($002710)
; ---------------------------------------------------------------------------
checkExtraLife:
    lda zpExtraLifeAwarded
    bne @done
    
    lda scoreHi
    bne @award
    lda scoreMid
    cmp #$27
    bcc @done
    bne @award
    lda scoreLo
    cmp #$10
    bcc @done
    
@award:
    inc zpLives
    lda #1
    sta zpExtraLifeAwarded
@done:
    rts

; ---------------------------------------------------------------------------
; playDeathAnimation -- Play retro C64 text dissolve animation on collision
; ---------------------------------------------------------------------------
playDeathAnimation:
    ; 1. Erase all ghosts from the screen
    ldx #3
@eraseGhosts:
    stx zpGhostIdx
    lda ghostRow, x
    sta zpTmpRow
    lda ghostCol, x
    sta zpTmpCol
    jsr drawGridCell
    ldx zpGhostIdx
    dex
    bpl @eraseGhosts
    
    ; 2. Animate Pac-Man shrinking
    lda zpPacRow
    sta zpTmpRow
    lda zpPacCol
    sta zpTmpCol
    
    ; Phase 1: Pac-Man 'Q' in Yellow
    lda #CHAR_PACMAN
    ldx #COLOR_YELLOW
    jsr @writePacChar
    jsr delay15
    
    ; Phase 2: Pellet '*' in Yellow
    lda #$51
    ldx #COLOR_YELLOW
    jsr @writePacChar
    jsr delay15
    
    ; Phase 3: Dot '.' in White
    lda #CHAR_DOT
    ldx #COLOR_WHITE
    jsr @writePacChar
    jsr delay15
    
    ; Phase 4: Empty space ' ' in Black
    lda #CHAR_EMPTY
    ldx #COLOR_BLACK
    jsr @writePacChar
    jsr delay15
    rts

@writePacChar:
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

delay15:
    lda #15
    jsr delayA
    rts

delayA:
    sta zpTmpDistLo
    lda JIFFY_CLK
    sta zpTmpVal
@loop:
    lda JIFFY_CLK
    sec
    sbc zpTmpVal
    cmp zpTmpDistLo
    bcc @loop
    rts

; ---------------------------------------------------------------------------
; showReadyBanner -- Display "READY!" centered below the ghost house gate
; ---------------------------------------------------------------------------
showReadyBanner:
    ; Draw "READY!" in yellow at Row 14, Cols 11–16
    ldx #0
@loop:
    lda charReady, x
    sta zpTmpVal
    
    txa
    clc
    adc #11
    sta zpTmpCol
    
    lda #14
    sta zpTmpRow
    
    lda zpTmpCol
    clc
    adc #6
    clc
    ldy #14
    adc rowOffLo, y
    sta zpTmpPtrLo
    lda rowOffHi, y
    adc #>SCREEN
    sta zpTmpPtrHi
    
    lda zpTmpCol
    clc
    adc #6
    clc
    ldy #14
    adc rowOffLo, y
    sta zpTmpDistLo
    lda rowOffHi, y
    adc #>COLORRAM
    sta zpTmpDistHi
    
    ldy #0
    lda #COLOR_YELLOW
    sta (zpTmpDistLo), y
    lda zpTmpVal
    sta (zpTmpPtrLo), y
    
    inx
    cpx #6
    bne @loop
    
    ; Delay 120 jiffies (~2 seconds)
    lda #120
    jsr delayA
    
    ; Cleanly erase "READY!" by redrawing Cols 11-16
    ldx #0
@erase:
    txa
    clc
    adc #11
    sta zpTmpCol
    lda #14
    sta zpTmpRow
    
    stx zpGhostIdx
    jsr drawGridCell
    ldx zpGhostIdx
    
    inx
    cpx #6
    bne @erase
    rts

charReady: .byte $12, $05, $01, $04, $19, $21 ; "READY!"
