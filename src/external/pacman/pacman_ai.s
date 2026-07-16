; src/external/pacman/pacman_ai.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Pac-Man Ghost AI Target Math & Direction Decisions.

.include "command64.inc"
.include "common.inc"

.import getWallCell

.export ghostRow
.export ghostCol
.export ghostDir
.export ghostTimer
.export ghostMode
.export ghostTargetRow
.export ghostTargetCol
.export zpCycleTimer
.export zpCycleStep
.export zpFrightenedTimer

.export initGhosts
.export updateGhostAI
.export getGhostColor
.export getGhostScatterTarget
.export getGhostSpeed
.export updateCycleScheduler
.export transitionGhostModes
.export triggerFrightenedMode
.export recordReleaseDot
.export resetReleaseIdleTimer
.export tickReleaseIdleTimer
.export initReleaseStateForLevel
.export initReleaseStateForLifeLoss

.segment "BSS"

ghostRow:       .res 4
ghostCol:       .res 4
ghostDir:       .res 4
ghostTimer:     .res 4
ghostMode:      .res 4
ghostTargetRow: .res 4
ghostTargetCol: .res 4

zpCycleTimer:    .res 2 ; 16-bit Jiffy scheduler timer
zpCycleStep:     .res 1 ; Current cycle step (0-7)
zpFrightenedTimer: .res 2 ; 16-bit timer for power pellet mode

; --- Ghost-house release accounting (brain/plans/2026-07-15_pacman-
; ghost-house-remediation-plan.md, Phases 4-7). Explicit counters replace
; the old zpTotalDots/zpSpawnDots-derived subtraction: release decisions
; must not be coupled to ghost movement/polling frequency. ---
ghostPersonalDots:  .res 4 ; per-ghost personal dot counter; index 0 (Blinky) unused
activeDotOwner:     .res 1 ; ghost index currently accruing personal dots, or GHOST_NONE
globalReleaseDots:  .res 1 ; post-death global release counter
releaseIdleLo:      .res 1 ; non-blocking forced-release inactivity timer (16-bit jiffies)
releaseIdleHi:      .res 1

; Target coordinate temporaries (signed 8-bit)
targetRow: .res 1
targetCol: .res 1
minDistLo: .res 1
minDistHi: .res 1
bestDir:   .res 1

.segment "RODATA"

; 16-bit square lookup table (index 0 to 31)
squareTableLo:
    .byte 0, 1, 4, 9, 16, 25, 36, 49, 64, 81, 100, 121, 144, 169, 196, 225
    .byte <256, <289, <324, <361, <400, <441, <484, <529, <576, <625, <676, <729, <784, <841, <900, <961
squareTableHi:
    .byte 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    .byte >256, >289, >324, >361, >400, >441, >484, >529, >576, >625, >676, >729, >784, >841, >900, >961

; Scatter corners:
; Blinky: Top-Right (0, 27)
; Pinky:  Top-Left (0, 0)
; Inky:   Bottom-Right (23, 27)
; Clyde:  Bottom-Left (23, 0)
scatterRows: .byte 0,  0, 23, 23
scatterCols: .byte 27, 0, 27, 0

; Personal ghost-house release dot limits, indexed by ghost (index 0,
; Blinky, is unused -- Blinky never waits in the house). Level 3+ always
; releases immediately (handled as a special case, not tabled).
personalLimitsLevel1: .byte 0, 0, 30, 60
personalLimitsLevel2: .byte 0, 0, 0,  50

; Timed scatter/chase sequence thresholds (in seconds, converted to jiffies * 60)
; Steps: Scatter 7s, Chase 20s, Scatter 7s, Chase 20s, Scatter 5s, Chase 20s, Scatter 5s, Chase permanent
cycleThresholdsLo:
    .byte <(7*60), <(20*60), <(7*60), <(20*60), <(5*60), <(20*60), <(5*60)
cycleThresholdsHi:
    .byte >(7*60), >(20*60), >(7*60), >(20*60), >(5*60), >(20*60), >(5*60)

frightenedDurationsLo:
    .byte <(360), <(300), <(240), <(180), <(120), <(60), <(60), <(60), <(0)
frightenedDurationsHi:
    .byte >(360), >(300), >(240), >(180), >(120), >(60), >(60), >(60), >(0)

.segment "CODE"

; ---------------------------------------------------------------------------
; initGhosts
; ---------------------------------------------------------------------------
initGhosts:
    ; Spawns:
    ; Blinky (0): Row 11, Col 13 (Outside, moves LEFT)
    ; Pinky  (1): Row 12, Col 13 (Inside, moves UP)
    ; Inky   (2): Row 12, Col 11 (Inside, moves UP)
    ; Clyde  (3): Row 12, Col 15 (Inside, moves UP)
    
    lda #11
    sta ghostRow + GHOST_BLINKY
    lda #13
    sta ghostCol + GHOST_BLINKY
    lda #DIR_LEFT
    sta ghostDir + GHOST_BLINKY
    
    lda #12
    sta ghostRow + GHOST_PINKY
    sta ghostRow + GHOST_INKY
    sta ghostRow + GHOST_CLYDE
    
    lda #13
    sta ghostCol + GHOST_PINKY
    lda #11
    sta ghostCol + GHOST_INKY
    lda #15
    sta ghostCol + GHOST_CLYDE
    
    lda #DIR_UP
    sta ghostDir + GHOST_PINKY
    sta ghostDir + GHOST_INKY
    sta ghostDir + GHOST_CLYDE
    
    ldx #3
@loop:
    lda #1
    sta ghostTimer, x
    cpx #GHOST_BLINKY
    beq @blinkyScatter
    lda #MODE_HOUSE
    sta ghostMode, x
    jmp @next
@blinkyScatter:
    lda #MODE_SCATTER
    sta ghostMode, x
@next:
    dex
    bpl @loop
    
    ; Reset cycle scheduling
    lda #0
    sta zpCycleStep
    sta zpCycleTimer
    sta zpCycleTimer+1
    sta zpFrightenedTimer
    sta zpFrightenedTimer+1
    sta zpFreezeTimer
    sta zpFruitTimerLo
    sta zpFruitTimerHi
    rts

; ---------------------------------------------------------------------------
; getGhostColor -- Returns color code in A for ghost in X
; ---------------------------------------------------------------------------
getGhostColor:
    lda ghostMode, x
    cmp #MODE_EATEN
    bne :+
    lda #COLOR_WHITE
    rts
:   cmp #MODE_FRIGHTENED
    bne @normalColor
    
    ; Check if timer is < 120 ticks (approx 2s) to flash
    lda zpFrightenedTimer+1
    bne @drawBlue
    lda zpFrightenedTimer
    cmp #120
    bcs @drawBlue
    
    ; Flashing check (bit 4 toggles every 16 ticks)
    and #16
    beq @drawBlue
    lda #COLOR_WHITE
    rts
@drawBlue:
    lda #COLOR_BLUE
    rts
@normalColor:   cpx #GHOST_BLINKY
    bne :+
    lda #COLOR_RED
    rts
:   cpx #GHOST_PINKY
    bne :+
    lda #COLOR_PINK
    rts
:   cpx #GHOST_INKY
    bne :+
    lda #COLOR_CYAN
    rts
:   lda #COLOR_ORANGE
    rts

; ---------------------------------------------------------------------------
; getGhostScatterTarget -- Row/Col target into targetRow/targetCol for ghost X
; ---------------------------------------------------------------------------
getGhostScatterTarget:
    lda scatterRows, x
    sta targetRow
    lda scatterCols, x
    sta targetCol
    rts

; ---------------------------------------------------------------------------
; updateGhostAI -- Computes targets and makes direction decisions for ghost in X
; ---------------------------------------------------------------------------
updateGhostAI:
    stx zpGhostIdx
    
    lda ghostMode, x
    cmp #MODE_HOUSE
    bne :+
    jsr handleHouseBouncing
    rts
:   cmp #MODE_EXITING
    bne :+
    jsr handleHouseExit
    rts
:   cmp #MODE_EATEN
    bne :+
    
    ; EATEN routing: Target ghost house interior revival tile
    lda #EATEN_REVIVE_ROW
    sta targetRow
    lda #EATEN_REVIVE_COL
    sta targetCol
    jmp @findNextDir
:
    ; If ghost is Frightened (MODE_FRIGHTENED), decide randomly via LFSR
    lda ghostMode, x
    cmp #MODE_FRIGHTENED
    bne @normalAI
    
    jsr makeRandomDecision
    rts

@normalAI:
    ; Choose between Chase and Scatter Target
    lda ghostMode, x
    cmp #MODE_SCATTER
    bne @doChaseTarget
    
    ; SCATTER Target
    jsr getGhostScatterTarget
    jmp @findNextDir
    
@doChaseTarget:
    ; Calculate Chase Target based on personality
    cpx #GHOST_BLINKY
    bne @tryPinky
    
    ; --- Blinky: Target = Pac-Man's Tile ---
    lda zpPacRow
    sta targetRow
    lda zpPacCol
    sta targetCol
    jmp @findNextDir

@tryPinky:
    cpx #GHOST_PINKY
    bne @tryInky
    
    ; --- Pinky: Target = Pac-Man + 4 tiles ahead ---
    ; (with original overflow bug: UP also adds 4 tiles LEFT)
    lda zpPacRow
    sta targetRow
    lda zpPacCol
    sta targetCol
    
    lda zpPacDir
    cmp #DIR_UP
    bne @pDn
    sec
    lda targetRow
    sbc #4
    sta targetRow
    sec
    lda targetCol
    sbc #4
    sta targetCol
    jmp @findNextDir
@pDn:
    cmp #DIR_DOWN
    bne @pLf
    clc
    lda targetRow
    adc #4
    sta targetRow
    jmp @findNextDir
@pLf:
    cmp #DIR_LEFT
    bne @pRt
    sec
    lda targetCol
    sbc #4
    sta targetCol
    jmp @findNextDir
@pRt:
    cmp #DIR_RIGHT
    bne @skipPinky
    clc
    lda targetCol
    adc #4
    sta targetCol
@skipPinky:
    jmp @findNextDir

@tryInky:
    cpx #GHOST_INKY
    bne @tryClyde
    
    ; --- Inky: Target = Double vector Blinky -> (Pac-Man + 2 ahead) ---
    ; (using overflow bug for UP: adds 2 tiles UP and 2 tiles LEFT)
    lda zpPacRow
    sta zpTmpRow
    lda zpPacCol
    sta zpTmpCol
    
    lda zpPacDir
    cmp #DIR_UP
    bne @iDn
    sec
    lda zpTmpRow
    sbc #2
    sta zpTmpRow
    sec
    lda zpTmpCol
    sbc #2
    sta zpTmpCol
    jmp @doubleVector
@iDn:
    cmp #DIR_DOWN
    bne @iLf
    clc
    lda zpTmpRow
    adc #2
    sta zpTmpRow
    jmp @doubleVector
@iLf:
    cmp #DIR_LEFT
    bne @iRt
    sec
    lda zpTmpCol
    sbc #2
    sta zpTmpCol
    jmp @doubleVector
@iRt:
    cmp #DIR_RIGHT
    bne @doubleVector
    clc
    lda zpTmpCol
    adc #2
    sta zpTmpCol
    
@doubleVector:
    ; Pivot coordinate in zpTmpRow/zpTmpCol
    ; targetRow = pivotRow + (pivotRow - blinkyRow) = 2 * pivotRow - blinkyRow
    sec
    lda zpTmpRow
    sbc ghostRow + GHOST_BLINKY
    clc
    adc zpTmpRow
    sta targetRow
    
    sec
    lda zpTmpCol
    sbc ghostCol + GHOST_BLINKY
    clc
    adc zpTmpCol
    sta targetCol
    jmp @findNextDir

@tryClyde:
    ; --- Clyde: Target = Pac-Man if distance >= 8, else Scatter corner (23,0) ---
    sec
    lda ghostRow + GHOST_CLYDE
    sbc zpPacRow
    jsr getAbsDiff
    tax
    sec
    lda ghostCol + GHOST_CLYDE
    sbc zpPacCol
    jsr getAbsDiff
    tay
    
    ; Calculate distance squared using lookup table
    clc
    lda squareTableLo, x
    adc squareTableLo, y
    sta minDistLo
    lda squareTableHi, x
    adc squareTableHi, y
    sta minDistHi
    
    ; Compare with 64 (8^2)
    lda minDistHi
    bne @clydeChase
    lda minDistLo
    cmp #64
    bcs @clydeChase
    
    ; Clyde is close: run to scatter corner (23, 0)
    lda #23
    sta targetRow
    lda #0
    sta targetCol
    jmp @findNextDir
@clydeChase:
    lda zpPacRow
    sta targetRow
    lda zpPacCol
    sta targetCol

; ---------------------------------------------------------------------------
; findNextDir -- Evaluates legal neighbor directions to targetRow/targetCol
; ---------------------------------------------------------------------------
@findNextDir:
    ; Initialize minDist to $FFFF
    lda #$FF
    sta minDistLo
    sta minDistHi
    lda #DIR_NONE
    sta bestDir
    
    ; Get current position and current direction
    ldx zpGhostIdx
    lda ghostRow, x
    sta zpTmpRow
    lda ghostCol, x
    sta zpTmpCol
    lda ghostDir, x
    sta zpTmpVal ; current direction
    
    ; Evaluate directions in order: UP (0), LEFT (2), DOWN (1), RIGHT (3)
    ; Strictly less '<' addition to enforce UP > LEFT > DOWN > RIGHT ties.
    
    ; --- 1. DIR_UP ---
    lda zpTmpVal
    cmp #DIR_DOWN ; prevent reversing
    beq @evalLeft
    
    dec zpTmpRow
    jsr isTargetTileLegal
    inc zpTmpRow ; restore
    bcc @evalLeft
    
    dec zpTmpRow
    jsr getTargetDistanceSquared
    inc zpTmpRow
    jsr updateBestDirection
    lda #DIR_UP
    sta bestDir
    
@evalLeft:
    ; --- 2. DIR_LEFT ---
    lda zpTmpVal
    cmp #DIR_RIGHT ; prevent reversing
    beq @evalDown
    
    dec zpTmpCol
    jsr isTargetTileLegal
    inc zpTmpCol ; restore
    bcc @evalDown
    
    dec zpTmpCol
    jsr getTargetDistanceSquared
    inc zpTmpCol
    jsr updateBestDirection
    bcc @evalDown ; if not updated, skip setting bestDir
    lda #DIR_LEFT
    sta bestDir

@evalDown:
    ; --- 3. DIR_DOWN ---
    lda zpTmpVal
    cmp #DIR_UP ; prevent reversing
    beq @evalRight
    
    inc zpTmpRow
    jsr isTargetTileLegal
    dec zpTmpRow
    bcc @evalRight
    
    inc zpTmpRow
    jsr getTargetDistanceSquared
    dec zpTmpRow
    jsr updateBestDirection
    bcc @evalRight
    lda #DIR_DOWN
    sta bestDir

@evalRight:
    ; --- 4. DIR_RIGHT ---
    lda zpTmpVal
    cmp #DIR_LEFT ; prevent reversing
    beq @doneEval
    
    inc zpTmpCol
    jsr isTargetTileLegal
    dec zpTmpCol ; restore
    bcc @doneEval
    
    inc zpTmpCol
    jsr getTargetDistanceSquared
    dec zpTmpCol
    jsr updateBestDirection
    bcc @doneEval
    lda #DIR_RIGHT
    sta bestDir

@doneEval:
    ; Apply best direction
    ldx zpGhostIdx
    lda bestDir
    cmp #DIR_NONE
    bne @apply
    
    ; Dead-end/loop fallback: reverse current direction
    lda ghostDir, x
    eor #1
    sta ghostDir, x
    jmp @exitAI
@apply:
    sta ghostDir, x
@exitAI:
    rts

; ---------------------------------------------------------------------------
; updateBestDirection -- Checks if computed distance < minDist.
; Updates minDist if carry is clear (strictly less). Sets carry if not better.
; ---------------------------------------------------------------------------
updateBestDirection:
    sec
    lda zpTmpDistLo
    sbc minDistLo
    lda zpTmpDistHi
    sbc minDistHi
    bcs @noUpdate ; if dist >= minDist, branch out
    
    ; Strictly less: update minDist
    lda zpTmpDistLo
    sta minDistLo
    lda zpTmpDistHi
    sta minDistHi
    sec ; set carry to signal update
    rts
@noUpdate:
    clc ; clear carry to signal NO update
    rts

; ---------------------------------------------------------------------------
; isTargetTileLegal -- Checks if tile at zpTmpRow/zpTmpCol is walkable for ghost
; returns carry set if legal, carry clear if wall.
; ---------------------------------------------------------------------------
isTargetTileLegal:
    ; Out of bounds?
    lda zpTmpRow
    bmi @illegal
    cmp #PLAY_H
    bcs @illegal
    lda zpTmpCol
    bmi @illegal
    cmp #28
    bcs @illegal
    
    jsr getWallCell
    beq @legal ; 0 = open path, legal
    cmp #10
    beq @gateCheck ; 10 = ghost house door, check if ghost is eaten/entering
    cmp #11
    beq @legal ; 11 = Power Pellet tile, legal
@illegal:
    clc
    rts
@gateCheck:
    ; Only EATEN (returning eyes) and EXITING (controlled exit routing)
    ; ghosts may cross the door gate; everyone else treats it as a wall.
    ldx zpGhostIdx
    lda ghostMode, x
    cmp #MODE_EATEN
    beq @legal
    cmp #MODE_EXITING
    beq @legal
    jmp @illegal
@legal:
    sec
    rts

; ---------------------------------------------------------------------------
; getTargetDistanceSquared -- computes distance^2 to targetRow/targetCol
; returns result in zpTmpDistLo/Hi.
; ---------------------------------------------------------------------------
getTargetDistanceSquared:
    sec
    lda zpTmpRow
    sbc targetRow
    jsr getAbsDiff
    tax
    sec
    lda zpTmpCol
    sbc targetCol
    jsr getAbsDiff
    tay
    
    clc
    lda squareTableLo, x
    adc squareTableLo, y
    sta zpTmpDistLo
    lda squareTableHi, x
    adc squareTableHi, y
    sta zpTmpDistHi
    rts

; ---------------------------------------------------------------------------
; getAbsDiff -- computes absolute value of A
; ---------------------------------------------------------------------------
getAbsDiff:
    bpl :+
    eor #$FF
    clc
    adc #1
:   cmp #31
    bcc :+
    lda #31
:   rts

; ---------------------------------------------------------------------------
; makeRandomDecision -- Pick a random direction for frightened ghost
; ---------------------------------------------------------------------------
makeRandomDecision:
    lda #0
    sta zpTmpVal ; Use as retry counter
@nextTry:
    ; LFSR step
    lda zpLfsr
    beq @seed
    asl
    bcc :+
    eor #$1D ; Galois polynomial taps
:   sta zpLfsr
    jmp @checkRandomDir
@seed:
    lda #$37
    sta zpLfsr
@checkRandomDir:
    ; Map bit 0-1 of LFSR to direction 0-3
    and #3
    sta bestDir
    
    ; Ensure it is not reversing (unless we have retried 8+ times)
    lda zpTmpVal
    cmp #8
    bcs @skipReverseCheck
    
    ldx zpGhostIdx
    lda ghostDir, x
    eor #1
    cmp bestDir
    beq @retryLFSR
@skipReverseCheck:
    
    ; Test if tile in bestDir is legal
    lda bestDir
    cmp #DIR_UP
    bne @tryLfRand
    dec ghostRow, x
    jsr isTargetTileLegalRand
    inc ghostRow, x
    bcs @applyRand
    jmp @retryLFSR
    
@tryLfRand:
    cmp #DIR_LEFT
    bne @tryDnRand
    dec ghostCol, x
    jsr isTargetTileLegalRand
    inc ghostCol, x
    bcs @applyRand
    jmp @retryLFSR

@tryDnRand:
    cmp #DIR_DOWN
    bne @tryRtRand
    inc ghostRow, x
    jsr isTargetTileLegalRand
    dec ghostRow, x
    bcs @applyRand
    jmp @retryLFSR

@tryRtRand:
    inc ghostCol, x
    jsr isTargetTileLegalRand
    dec ghostCol, x
    bcs @applyRand
    
@retryLFSR:
    inc zpTmpVal
    lda zpTmpVal
    cmp #16
    bcs @forceReverse
    
    ; Rotate LFSR and try again
    lda zpLfsr
    lsr
    sta zpLfsr
    jmp @checkRandomDir

@forceReverse:
    ldx zpGhostIdx
    lda ghostDir, x
    eor #1
    sta ghostDir, x
    rts

@applyRand:
    lda bestDir
    sta ghostDir, x
    rts

isTargetTileLegalRand:
    ldx zpGhostIdx
    lda ghostRow, x
    sta zpTmpRow
    lda ghostCol, x
    sta zpTmpCol
    jsr isTargetTileLegal
    rts

; ---------------------------------------------------------------------------
; getGhostSpeed -- Returns speed reload value in A for ghost in X
; ---------------------------------------------------------------------------
getGhostSpeed:
    ldx zpGhostIdx
    lda ghostMode, x
    cmp #MODE_EATEN
    bne @notEaten
    lda #3
    rts
    
@notEaten:
    cmp #MODE_FRIGHTENED
    bne @normalSpeed
    
    ; Frightened speed: Level 1 = 14, Level 2+ = 12
    lda zpLevel
    cmp #2
    bcc :+
    lda #12
    rts
:   lda #14
    rts

@normalSpeed:
    ; Normal base speed based on level
    lda zpLevel
    cmp #2
    bcc @level1
    cmp #5
    bcc @level2_4
    
    ; Level 5+
    lda #7
    jmp @checkBlinky
    
@level1:
    lda #10
    jmp @checkBlinky
    
@level2_4:
    lda #9
    
@checkBlinky:
    sta zpTmpVal
    
    ldx zpGhostIdx
    cpx #GHOST_BLINKY
    bne @done
    
    ; Blinky Cruise Elroy check
    lda dotsRemainingHi
    bne @done
    
    lda dotsRemainingLo
    cmp #15
    bcs :+
    
    ; Cruise Elroy 2: -2 ticks
    lda zpTmpVal
    sec
    sbc #2
    sta zpTmpVal
    jmp @done
    
:   cmp #30
    bcs @done
    
    ; Cruise Elroy 1: -1 tick
    dec zpTmpVal
    
@done:
    lda zpTmpVal
    rts

; ---------------------------------------------------------------------------
; updateCycleScheduler -- Increments timer and transitions modes
; ---------------------------------------------------------------------------
updateCycleScheduler:
    ; Check if frightened timer is active
    lda zpFrightenedTimer
    ora zpFrightenedTimer+1
    beq @normalScheduler

    ; Decrement frightened timer
    lda zpFrightenedTimer
    bne :+
    dec zpFrightenedTimer+1
:   dec zpFrightenedTimer

    ; Check if expired
    lda zpFrightenedTimer
    ora zpFrightenedTimer+1
    bne @exitScheduler

    ; Frightened timer just expired: transition ghosts back to current scheduler mode
    jsr endFrightenedMode
@exitScheduler:
    rts

@normalScheduler:
    inc zpCycleTimer
    bne :+
    inc zpCycleTimer+1
:
    lda zpCycleStep
    cmp #7
    bcs @doneCycle ; Step 7 is permanent chase

    tax
    lda zpCycleTimer
    cmp cycleThresholdsLo, x
    lda zpCycleTimer+1
    sbc cycleThresholdsHi, x
    bcc @doneCycle

    ; Threshold reached: step forward
    inc zpCycleStep
    
    lda #0
    sta zpCycleTimer
    sta zpCycleTimer+1
    
    jsr transitionGhostModes

@doneCycle:
    rts

; ---------------------------------------------------------------------------
; getScheduledGhostMode -- Returns the scheduled outside mode (SCATTER or
; CHASE) in A, derived from zpCycleStep. Does not touch X/Y.
; ---------------------------------------------------------------------------
getScheduledGhostMode:
    lda zpCycleStep
    and #1
    bne @chase
    lda #MODE_SCATTER
    rts
@chase:
    lda #MODE_CHASE
    rts

; ---------------------------------------------------------------------------
; transitionGhostModes -- Swaps all active outside ghosts to the new cycle
; mode. House lifecycle modes (HOUSE/EXITING/EATEN) and an active
; FRIGHTENED are never overwritten by the scheduler -- see the lifecycle
; state machine documented in common.inc.
; ---------------------------------------------------------------------------
transitionGhostModes:
    jsr getScheduledGhostMode
    sta zpTmpVal

    ldx #3
@loop:
    stx zpGhostIdx
    lda ghostMode, x
    cmp #MODE_EATEN
    beq @skip
    cmp #MODE_FRIGHTENED
    beq @skip
    cmp #MODE_HOUSE
    beq @skip
    cmp #MODE_EXITING
    beq @skip

    lda zpTmpVal
    sta ghostMode, x

    ; Reverse direction
    lda ghostDir, x
    eor #1
    sta ghostDir, x
@skip:
    dex
    bpl @loop
    rts

; ---------------------------------------------------------------------------
; endFrightenedMode -- Swaps all frightened ghosts back to normal mode
; ---------------------------------------------------------------------------
endFrightenedMode:
    jsr getScheduledGhostMode
    sta zpTmpVal

    ldx #3
@loop:
    stx zpGhostIdx
    lda ghostMode, x
    cmp #MODE_FRIGHTENED
    bne @skip

    lda zpTmpVal
    sta ghostMode, x
@skip:
    dex
    bpl @loop
    rts

; ---------------------------------------------------------------------------
; triggerFrightenedMode -- Triggers frightened mode for all active ghosts
; ---------------------------------------------------------------------------
triggerFrightenedMode:
    lda zpLevel
    sec
    sbc #1
    cmp #8
    bcc :+
    lda #8
:   tay
    lda frightenedDurationsLo, y
    sta zpFrightenedTimer
    lda frightenedDurationsHi, y
    sta zpFrightenedTimer+1
    
    lda zpFrightenedTimer
    ora zpFrightenedTimer+1
    beq @onlyReverse
    
    lda #0
    sta zpGhostsEatenCount
    
    ldx #3
@loop:
    stx zpGhostIdx
    lda ghostMode, x
    cmp #MODE_EATEN
    beq @skip
    cmp #MODE_HOUSE
    beq @skip
    cmp #MODE_EXITING
    beq @skip
    
    lda #MODE_FRIGHTENED
    sta ghostMode, x
    
    lda ghostDir, x
    eor #1
    sta ghostDir, x
@skip:
    dex
    bpl @loop
    rts

@onlyReverse:
    ldx #3
@loopOnlyRev:
    stx zpGhostIdx
    lda ghostMode, x
    cmp #MODE_EATEN
    beq @skipOnlyRev
    cmp #MODE_HOUSE
    beq @skipOnlyRev
    cmp #MODE_EXITING
    beq @skipOnlyRev
    
    lda ghostDir, x
    eor #1
    sta ghostDir, x
@skipOnlyRev:
    dex
    bpl @loopOnlyRev
    rts

; ---------------------------------------------------------------------------
; handleHouseBouncing -- Direction-only bounce inside the house. Never
; writes ghostRow/ghostCol; the common movement stage in updateGhosts
; (pacman_main.s) performs the actual one-cell move from ghostDir.
; ---------------------------------------------------------------------------
handleHouseBouncing:
    ldx zpGhostIdx
    jsr checkGhostRelease
    ldx zpGhostIdx      ; reload; checkGhostRelease's contract does not
                        ; guarantee X preservation across future changes
    bcc @continueBounce

    ; Release! Begin exiting immediately -- hand off to handleHouseExit so
    ; the same tick picks the correct alignment direction toward the door.
    lda #MODE_EXITING
    sta ghostMode, x
    jmp handleHouseExit

@continueBounce:
    lda ghostRow, x
    cmp #12
    bne @checkRow13
    lda ghostDir, x
    cmp #DIR_UP
    bne @done
    lda #DIR_DOWN
    sta ghostDir, x
    rts

@checkRow13:
    cmp #13
    bne @done
    lda ghostDir, x
    cmp #DIR_DOWN
    bne @done
    lda #DIR_UP
    sta ghostDir, x
@done:
    rts

; ---------------------------------------------------------------------------
; handleHouseExit -- Direction-only routing to Col EXIT_DOOR_COL, then UP
; out through the door. Never writes ghostRow/ghostCol; the common
; movement stage in updateGhosts performs the actual one-cell move.
; ---------------------------------------------------------------------------
handleHouseExit:
    ldx zpGhostIdx
    lda ghostCol, x
    cmp #EXIT_DOOR_COL
    beq @atDoorCol
    bcc @goRight

    ; Col > EXIT_DOOR_COL: face Left
    lda #DIR_LEFT
    sta ghostDir, x
    rts

@goRight:
    ; Col < EXIT_DOOR_COL: face Right
    lda #DIR_RIGHT
    sta ghostDir, x
    rts

@atDoorCol:
    lda ghostRow, x
    cmp #EXIT_DOOR_ROW
    bne @faceUp         ; still inside (Row 12/13): just face Up

    ; At the door row: select the outside mode this tick so the common
    ; movement stage's Up move lands the ghost outside already in mode.
    lda zpFrightenedTimer
    ora zpFrightenedTimer+1
    beq @setScheduled
    lda #MODE_FRIGHTENED
    sta ghostMode, x
    jmp @faceUp
@setScheduled:
    jsr getScheduledGhostMode
    ldx zpGhostIdx
    sta ghostMode, x
@faceUp:
    ldx zpGhostIdx
    lda #DIR_UP
    sta ghostDir, x
    rts

; ---------------------------------------------------------------------------
; checkGhostRelease -- Returns carry set if ghost in X is allowed to leave.
; Uses the explicit ghostPersonalDots/globalReleaseDots counters (Phases
; 4-6) instead of deriving dots-eaten by subtraction; counters are
; advanced exactly once per consumed dot by recordReleaseDot.
; ---------------------------------------------------------------------------
checkGhostRelease:
    ldx zpGhostIdx
    cpx #GHOST_BLINKY
    bne :+
    sec ; Blinky is always allowed out
    rts

:   lda zpPostDeathRelease
    bne @globalMode

    ; --- Individual (personal counter) release ---
    lda zpLevel
    cmp #3
    bcc :+
    sec ; Level 3+: all personal limits are zero, release immediately
    rts
:   jsr getPersonalLimit    ; A = this ghost's personal limit; X preserved
    sta zpTmpVal
    lda ghostPersonalDots, x
    cmp zpTmpVal            ; carry set if counter >= limit
    rts

@globalMode:
    ; --- Post-death global release: exact-value arcade semantics ---
    lda globalReleaseDots
    cpx #GHOST_PINKY
    bne @tryInkyGlobal
    cmp #7
    beq @releaseGlobal
    clc
    rts
@tryInkyGlobal:
    cpx #GHOST_INKY
    bne @clydeGlobal
    cmp #17
    beq @releaseGlobal
    clc
    rts
@clydeGlobal:
    ; Only GHOST_CLYDE remains here.
    cmp #32
    bne @notClydeExact
    lda #0
    sta zpPostDeathRelease  ; Clyde released at exactly 32: disable global mode
    sec
    rts
@notClydeExact:
    clc
    rts
@releaseGlobal:
    sec
    rts

; ---------------------------------------------------------------------------
; getPersonalLimit -- Returns the personal release-dot limit for ghost X
; (must be Pinky/Inky/Clyde) in A, based on zpLevel. Caller must handle
; Level 3+ (all-zero) separately. Does not clobber X.
; ---------------------------------------------------------------------------
getPersonalLimit:
    lda zpLevel
    cmp #2
    bcc @level1
    lda personalLimitsLevel2, x
    rts
@level1:
    lda personalLimitsLevel1, x
    rts

; ---------------------------------------------------------------------------
; getActiveDotOwner -- Scans Pinky/Inky/Clyde in priority order for the
; first still in MODE_HOUSE; returns its index in X (also cached in
; activeDotOwner for diagnostics), or GHOST_NONE in X if none remain
; waiting inside.
; ---------------------------------------------------------------------------
getActiveDotOwner:
    ldx #GHOST_PINKY
    lda ghostMode, x
    cmp #MODE_HOUSE
    beq @found
    ldx #GHOST_INKY
    lda ghostMode, x
    cmp #MODE_HOUSE
    beq @found
    ldx #GHOST_CLYDE
    lda ghostMode, x
    cmp #MODE_HOUSE
    beq @found
    ldx #GHOST_NONE
@found:
    stx activeDotOwner
    rts

; ---------------------------------------------------------------------------
; recordReleaseDot -- Called exactly once from decDots (pacman_main.s) for
; each dot or energizer consumed. Advances the post-death global counter
; or the current personal-counter owner, per the active release mode.
; Clobbers: A, X. Preserves: Y.
; ---------------------------------------------------------------------------
recordReleaseDot:
    lda zpPostDeathRelease
    beq @personalPath
    inc globalReleaseDots
    rts
@personalPath:
    jsr getActiveDotOwner
    cpx #GHOST_NONE
    beq @done
    inc ghostPersonalDots, x
@done:
    rts

; ---------------------------------------------------------------------------
; forceGhostRelease -- Forces the highest-priority ghost still waiting in
; the house to begin exiting (release-inactivity timeout). Does not
; consume any release counter -- a forced exit is not an earned release.
; ---------------------------------------------------------------------------
forceGhostRelease:
    ldx #GHOST_PINKY
    lda ghostMode, x
    cmp #MODE_HOUSE
    beq @release
    ldx #GHOST_INKY
    lda ghostMode, x
    cmp #MODE_HOUSE
    beq @release
    ldx #GHOST_CLYDE
    lda ghostMode, x
    cmp #MODE_HOUSE
    beq @release
    rts ; nobody waiting inside
@release:
    lda #MODE_EXITING
    sta ghostMode, x
    jsr getActiveDotOwner ; refresh cached owner now that one fewer ghost is housed
    rts

; ---------------------------------------------------------------------------
; resetReleaseIdleTimer -- Reloads the non-blocking forced-release timer
; per the level's configured delay (240 jiffies levels 1-4, 180 from
; level 5).
; ---------------------------------------------------------------------------
resetReleaseIdleTimer:
    lda zpLevel
    cmp #5
    bcc @levels1to4
    lda #<180
    sta releaseIdleLo
    lda #>180
    sta releaseIdleHi
    rts
@levels1to4:
    lda #<240
    sta releaseIdleLo
    lda #>240
    sta releaseIdleHi
    rts

; ---------------------------------------------------------------------------
; tickReleaseIdleTimer -- Decrements the inactivity timer once per elapsed
; gameplay jiffy (called from the main loop's @gameplay section, never
; from ghost movement). On expiry, forces a release and reloads the timer.
; ---------------------------------------------------------------------------
tickReleaseIdleTimer:
    lda releaseIdleLo
    bne @decLo
    dec releaseIdleHi
@decLo:
    dec releaseIdleLo
    lda releaseIdleLo
    ora releaseIdleHi
    bne @done
    jsr forceGhostRelease
    jsr resetReleaseIdleTimer
@done:
    rts

; ---------------------------------------------------------------------------
; resetPersonalCounters -- Clears all per-ghost personal release counters
; and sets the active dot owner to Pinky. Called only at the start of a
; new level; life loss preserves personal-counter progress.
; ---------------------------------------------------------------------------
resetPersonalCounters:
    lda #0
    sta ghostPersonalDots + GHOST_BLINKY
    sta ghostPersonalDots + GHOST_PINKY
    sta ghostPersonalDots + GHOST_INKY
    sta ghostPersonalDots + GHOST_CLYDE
    lda #GHOST_PINKY
    sta activeDotOwner
    rts

; ---------------------------------------------------------------------------
; initReleaseStateForLevel -- Called at the start of every new level
; (initial game start and level-advance). zpPostDeathRelease is cleared
; by the caller; this resets personal counters, the global counter, and
; the inactivity timer.
; ---------------------------------------------------------------------------
initReleaseStateForLevel:
    jsr resetPersonalCounters
    lda #0
    sta globalReleaseDots
    jsr resetReleaseIdleTimer
    rts

; ---------------------------------------------------------------------------
; initReleaseStateForLifeLoss -- Called when a life is lost.
; zpPostDeathRelease is set by the caller; personal counters are
; preserved, only the global counter and inactivity timer reset.
; ---------------------------------------------------------------------------
initReleaseStateForLifeLoss:
    lda #0
    sta globalReleaseDots
    jsr resetReleaseIdleTimer
    rts
