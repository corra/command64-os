// src/external/pacman/pacman.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// Pac64 — character-grid Pac-Man for Command 64 OS
//
// Design notes:
//   Grid: 40x24 playfield (row 24 is a dynamic status line: score/lives/level).
//   Rendering: direct writes to screen RAM ($0400) / color RAM ($D800), same
//              technique as conway.asm — no hardware sprites.
//   Movement: grid-locked, one tile per movement tick. Each actor (Pac-Man,
//             four ghosts) has its own jiffy-driven move timer, so speeds are
//             independently tunable without a raster IRQ — unlike conway's
//             single whole-grid-per-generation update.
//   Maze: two 960-byte tables mirror conway's grid-buffer idea but are NOT
//         pinned to fixed addresses ($3000/$3400): conway's own code fits in
//         under 1KB, leaving headroom before $3000, but a full ghost-AI game
//         does not reliably fit in the ~1KB gap between UserProgStart ($2C00)
//         and $3000. Both tables are therefore ordinary labelled data, placed
//         wherever the assembler naturally lays them out — no collision risk
//         regardless of code size.
//           mazeWalls (read-only): 0=open, 1=wall, 2=ghost-only door (blocks
//                                  Pac-Man, passable for ghosts).
//           mazeItems (mutable):   0=empty, 1=dot (10pts), 2=power pellet (50pts).
//   Ghost AI: authentic scatter/chase/frightened/eaten state machine with the
//             four classic personalities. Per-tile decision: legal directions
//             (no reverse, except on phase flip / frightened trigger-expiry /
//             while eaten) narrowed by minimum squared-distance-to-target,
//             tie-broken in fixed order up > left > down > right.
//   Timing: one shared "did a jiffy tick elapse" check per main-loop pass
//           (compare $A2 to a saved snapshot), then every independent timer
//           (Pac-Man move, each ghost's move, global scatter/chase phase,
//           frightened, ghost-house release) decrements and fires on its own.
//
// Controls:
//   W/A/S/D      move up/left/down/right (buffered: an early turn is taken
//                the instant it becomes legal at the next tile)
//   P / SPACE    pause / resume
//   Q / RUN-STOP quit (return to shell)

#import "../../../include/command64.inc"

.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "0"
#import "build_pacman.inc"

.encoding "petscii_mixed"

// ---------------------------------------------------------------------------
// Grid dimensions
// ---------------------------------------------------------------------------
.const GRID_W    = 40
.const GRID_H    = 24
.const GRID_SIZE = 960
.const STATUS_ROW_OFFSET = 960
.const TUNNEL_ROW = 7

// ---------------------------------------------------------------------------
// Hardware addresses
// ---------------------------------------------------------------------------
.const VIC_BORD  = $D020
.const VIC_BGND  = $D021
.const SCREEN    = $0400
.const COLORRAM  = $D800
.const JIFFY_CLK = $A2

// ---------------------------------------------------------------------------
// Maze cell values (mazeWalls)
// ---------------------------------------------------------------------------
.const CELL_OPEN = 0
.const CELL_WALL = 1
.const CELL_DOOR = 2

// mazeItems values
.const ITEM_NONE   = 0
.const ITEM_DOT    = 1
.const ITEM_PELLET = 2

// ---------------------------------------------------------------------------
// Glyphs & colours
// ---------------------------------------------------------------------------
.const CHAR_WALL    = $A0   // reverse space
.const CHAR_EMPTY   = $20   // space
.const CHAR_DOT     = '.'
.const CHAR_PELLET  = '*'
.const CHAR_PACMAN  = '@'
.const CHAR_GHOST   = '$'
.const CHAR_FRIGHT  = $A0   // reverse space (blue) while frightened
.const CHAR_EYES    = ':'

.const CLR_WALL    = 6   // blue
.const CLR_DOT     = 1   // white
.const CLR_PELLET  = 7   // yellow
.const CLR_PACMAN  = 7   // yellow
.const CLR_BLINKY  = 2   // red
.const CLR_PINKY   = 10  // light red
.const CLR_INKY     = 3  // cyan
.const CLR_CLYDE   = 8   // orange
.const CLR_FRIGHT  = 6   // blue
.const CLR_EYES    = 1   // white
.const CLR_EMPTY   = 0   // black (unused, space shows background)

// ---------------------------------------------------------------------------
// Directions
// ---------------------------------------------------------------------------
.const DIR_UP    = 0
.const DIR_DOWN  = 1
.const DIR_LEFT  = 2
.const DIR_RIGHT = 3
.const DIR_NONE  = $FF

// ---------------------------------------------------------------------------
// Ghost modes
// ---------------------------------------------------------------------------
.const MODE_SCATTER = 0
.const MODE_CHASE   = 1
.const MODE_FRIGHT  = 2
.const MODE_EATEN   = 3
.const MODE_HOUSE   = 4

.const GHOST_BLINKY = 0
.const GHOST_PINKY  = 1
.const GHOST_INKY   = 2
.const GHOST_CLYDE  = 3

// ---------------------------------------------------------------------------
// Top-level game states (gameState)
// ---------------------------------------------------------------------------
.const GAMESTATE_PLAYING     = 0
.const GAMESTATE_LIFE_LOST   = 1
.const GAMESTATE_LEVEL_CLEAR = 2
.const GAMESTATE_GAME_OVER   = 3

.const LIFE_LOST_PAUSE_LO   = 90    // ~1.5s
.const LIFE_LOST_PAUSE_HI   = 0
.const LEVEL_CLEAR_PAUSE_LO = 120   // ~2s
.const LEVEL_CLEAR_PAUSE_HI = 0

// ---------------------------------------------------------------------------
// Timing constants (units: elapsed jiffy ticks, ~60/sec NTSC, ~50/sec PAL)
// ---------------------------------------------------------------------------
.const PAC_SPEED          = 7
.const GHOST_SPEED_NORMAL = 8
.const GHOST_SPEED_FRIGHT = 12
.const GHOST_SPEED_EATEN  = 4

.const FRIGHTENED_RELOAD_LO = $68   // 360 ticks (~6s)
.const FRIGHTENED_RELOAD_HI = $01

.const RELEASE_PINKY_LO = 180       // 180 ticks  (~3s)
.const RELEASE_PINKY_HI = 0
.const RELEASE_INKY_LO  = 44
.const RELEASE_INKY_HI  = 1         // 300 ticks  (~5s) = 1*256 + 44
.const RELEASE_CLYDE_LO = 88
.const RELEASE_CLYDE_HI = 2         // 600 ticks  (~10s) = 2*256 + 88

.const EATEN_HOUSE_PAUSE_LO = 120   // ~2s regroup once eaten ghost reaches the door
.const EATEN_HOUSE_PAUSE_HI = 0

// Scatter/chase phase duration table index sentinel
.const PHASE_LAST_INDEX = 7

// ---------------------------------------------------------------------------
// Zero-page scratch ($70-$75 — a subset of the documented $70-$7F external-
// program scratch range; conway itself already uses all of $70-$7D, and
// only one external app occupies user space at a time, so reuse is safe).
// ---------------------------------------------------------------------------
.label zpCellLo = $70   // generic maze-cell pointer (wall/item lookup)
.label zpCellHi = $71
.label zpDrawLo = $72   // screen/colour RAM draw pointer
.label zpDrawHi = $73
.label zpTmpA   = $74   // scratch for squared-distance/address math
.label zpLfsr   = $75   // LFSR state (frightened-ghost RNG)

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
* = UserProgStart "Pac64Entry"

start:
    lda $D012
    eor JIFFY_CLK
    eor $0314
    ora #1
    sta zpLfsr

    lda #0
    sta gamePaused
    sta gameState
    sta phaseIndex
    sta globalPhase
    sta ghostEatenCount

    sta VIC_BORD
    sta VIC_BGND

    lda JIFFY_CLK
    sta lastJiffy

    jsr clearScreen
    jsr resetItems
    jsr resetPositions
    jsr drawMaze
    jsr drawActors
    jsr drawStatusLabels
    jsr renderScoreLivesLevel

// ---------------------------------------------------------------------------
// Main loop
// ---------------------------------------------------------------------------
mainLoop:
    jsr handleKeys

    lda gamePaused
    beq mlNotPaused
    jmp mainLoop
mlNotPaused:

    lda gameState
    cmp #GAMESTATE_GAME_OVER
    bne mlCheckTick
    jmp mainLoop            // game-over: handleKeys above already watches for
                             // "any key" (see its gameState check) to quit
mlCheckTick:
    jsr checkTick
    bcc mainLoop
    lda gameState
    beq mlPlayingTick
    jsr pauseStateTick      // life-lost / level-clear: run the pause countdown
    jmp mainLoop
mlPlayingTick:
    jsr tickUpdate
    jmp mainLoop

// ---------------------------------------------------------------------------
// handleKeys — non-blocking keyboard poll (mirrors conway's handleKeys).
// ---------------------------------------------------------------------------
handleKeys:
    jsr KernalGetIn
    beq hkNone

    ldx gameState
    cpx #GAMESTATE_GAME_OVER
    bne hkDispatch
    jmp hkQuit                   // any key during game-over returns to shell
hkDispatch:
    cmp #$51                    // Q
    beq hkQuit
    cmp #3                      // RUN/STOP
    beq hkQuit
    cmp #$20                    // SPACE
    beq hkPause
    cmp #$50                    // P
    beq hkPause
    cmp #$57                    // W = up
    beq hkUp
    cmp #$53                    // S = down
    beq hkDown
    cmp #$41                    // A = left
    beq hkLeft
    cmp #$44                    // D = right
    beq hkRight
hkNone:
    rts

hkQuit:
    // Stack at this point (top -> bottom):
    //   [mainLoop return addr hi]  <- pushed by mainLoop's "jsr handleKeys"
    //   [mainLoop return addr lo]
    //   [shell return addr hi]     <- pushed by the loader calling UserProgStart
    //   [shell return addr lo]
    // Discard the mainLoop frame before RTS, exactly like conway's hkQuit.
    lda #0
    sta VIC_BORD
    sta VIC_BGND
    jsr clearScreen
    pla
    pla
    rts

hkPause:
    lda gamePaused
    eor #$FF
    sta gamePaused
    rts

hkUp:
    lda #DIR_UP
    sta pacNextDir
    rts
hkDown:
    lda #DIR_DOWN
    sta pacNextDir
    rts
hkLeft:
    lda #DIR_LEFT
    sta pacNextDir
    rts
hkRight:
    lda #DIR_RIGHT
    sta pacNextDir
    rts

// ---------------------------------------------------------------------------
// checkTick — carry set if a new jiffy tick has elapsed since lastJiffy.
// ---------------------------------------------------------------------------
checkTick:
    lda JIFFY_CLK
    cmp lastJiffy
    beq ctNone
    sta lastJiffy
    sec
    rts
ctNone:
    clc
    rts

// ---------------------------------------------------------------------------
// tickUpdate — runs once per elapsed jiffy tick. Decrements every independent
// timer and fires each one's action on expiry, then resolves collisions.
// ---------------------------------------------------------------------------
tickUpdate:
    jsr houseReleaseTick        // ghost-house release timers (MODE_HOUSE only)

    dec pacMoveTimer
    bne tuSkipPac
    lda #PAC_SPEED
    sta pacMoveTimer
    jsr updatePacman
tuSkipPac:

    jsr ghostMoveTick           // pass1 (targets) + pass2 (moves) for any
                                 // ghost whose own move timer expires now

    jsr phaseTimerTick
    jsr frightTimerTick
    jsr collisionCheck
    rts

// ---------------------------------------------------------------------------
// updatePacman — one grid-locked movement step for Pac-Man.
// ---------------------------------------------------------------------------
updatePacman:
    lda pacNextDir
    cmp #DIR_NONE
    beq upKeepDir
    ldx pacRow
    ldy pacCol
    jsr canMovePac              // A=pacNextDir; returns carry set + targRow/Col
    bcc upKeepDir
    lda pacNextDir
    sta pacDir
    jmp upDoMove
upKeepDir:
    lda pacDir
    cmp #DIR_NONE
    beq upDone
    ldx pacRow
    ldy pacCol
    jsr canMovePac
    bcc upDone
upDoMove:
    // Erase Pac-Man from his old cell, move, redraw.
    lda pacRow
    sta curRow
    lda pacCol
    sta curCol
    jsr redrawCell
    lda targRow
    sta pacRow
    lda targCol
    sta pacCol
    jsr consumeItemAtPac
    lda pacRow
    sta curRow
    lda pacCol
    sta curCol
    lda #CHAR_PACMAN
    sta curChar
    lda #CLR_PACMAN
    sta curColor
    jsr pokeActor
upDone:
    rts

// ---------------------------------------------------------------------------
// consumeItemAtPac — look up mazeItems at (pacRow,pacCol); if a dot/pellet is
// there, clear it, award points, decrement dotsRemaining, and (for a pellet)
// trigger frightened mode. Falls through harmlessly if the cell is empty.
// ---------------------------------------------------------------------------
consumeItemAtPac:
    lda pacRow
    sta curRow
    lda pacCol
    sta curCol
    jsr setCellPtrItems         // zpCellLo/Hi -> &mazeItems[pacRow][pacCol]
    ldy #0
    lda (zpCellLo), y
    beq ciaDone                 // ITEM_NONE
    cmp #ITEM_PELLET
    beq ciaPellet

    // dot
    lda #0
    sta (zpCellLo), y
    lda #10
    sta addAmountLo
    lda #0
    sta addAmountHi
    jsr addScore
    jsr decDotsRemaining
    jmp ciaDone

ciaPellet:
    lda #0
    sta (zpCellLo), y
    lda #50
    sta addAmountLo
    lda #0
    sta addAmountHi
    jsr addScore
    jsr decDotsRemaining
    jsr triggerFrightened
ciaDone:
    rts

// ---------------------------------------------------------------------------
// canMovePac / canMoveGhost — shared target-tile + legality resolution.
// Input:  A = direction, X = row, Y = col.
// Output: carry set if legal; targRow/targCol hold the resulting tile.
// Pac-Man is blocked by CELL_WALL and CELL_DOOR; ghosts only by CELL_WALL.
// ---------------------------------------------------------------------------
canMovePac:
    jsr computeTargetTile
    lda targRow
    sta curRow
    lda targCol
    sta curCol
    jsr setCellPtrWalls
    ldy #0
    lda (zpCellLo), y
    cmp #CELL_OPEN
    beq cmpLegal
    clc
    rts
cmpLegal:
    sec
    rts

canMoveGhost:
    jsr computeTargetTile
    lda targRow
    sta curRow
    lda targCol
    sta curCol
    jsr setCellPtrWalls
    ldy #0
    lda (zpCellLo), y
    cmp #CELL_WALL
    beq cmgBlocked
    sec
    rts
cmgBlocked:
    clc
    rts

// ---------------------------------------------------------------------------
// computeTargetTile — A=dir, X=row, Y=col -> targRow/targCol (tunnel-aware).
// ---------------------------------------------------------------------------
computeTargetTile:
    stx dirRow
    sty dirCol
    tax
    lda dirDRow, x
    clc
    adc dirRow
    sta targRow
    lda dirDCol, x
    clc
    adc dirCol
    sta targCol

    // Tunnel wrap only applies on TUNNEL_ROW, at the two outer edges.
    lda targRow
    cmp #TUNNEL_ROW
    bne cttDone
    lda targCol
    cmp #$FF                    // wrapped left of column 0
    bne cttCheckRight
    lda #GRID_W - 1
    sta targCol
    jmp cttDone
cttCheckRight:
    cmp #GRID_W
    bne cttDone
    lda #0
    sta targCol
cttDone:
    rts

dirRow: .byte 0
dirCol: .byte 0
targRow: .byte 0
targCol: .byte 0

// ---------------------------------------------------------------------------
// Cell-pointer / drawing helpers. All read curRow/curCol (and, for drawing,
// curChar/curColor) rather than passing through registers — the calls below
// chain through several steps, and named scratch bytes avoid the fragility
// of threading state through A/X/Y across nested jsr's (conway avoids this
// same trap by keeping its row/col state in zpRow/zpCol rather than passing
// registers between routines).
// ---------------------------------------------------------------------------
setCellPtrWalls:
    ldy curRow
    lda #<mazeWalls
    clc
    adc rowOffLo, y
    sta zpCellLo
    lda #>mazeWalls
    adc rowOffHi, y
    sta zpCellHi
    lda zpCellLo
    clc
    adc curCol
    sta zpCellLo
    bcc scpwDone
    inc zpCellHi
scpwDone:
    rts

setCellPtrItems:
    ldy curRow
    lda #<mazeItems
    clc
    adc rowOffLo, y
    sta zpCellLo
    lda #>mazeItems
    adc rowOffHi, y
    sta zpCellHi
    lda zpCellLo
    clc
    adc curCol
    sta zpCellLo
    bcc scpiDone
    inc zpCellHi
scpiDone:
    rts

pointerForScreen:
    ldy curRow
    lda #<SCREEN
    clc
    adc rowOffLo, y
    sta zpDrawLo
    lda #>SCREEN
    adc rowOffHi, y
    sta zpDrawHi
    lda zpDrawLo
    clc
    adc curCol
    sta zpDrawLo
    bcc pfsDone
    inc zpDrawHi
pfsDone:
    rts

pointerForColor:
    ldy curRow
    lda #<COLORRAM
    clc
    adc rowOffLo, y
    sta zpDrawLo
    lda #>COLORRAM
    adc rowOffHi, y
    sta zpDrawHi
    lda zpDrawLo
    clc
    adc curCol
    sta zpDrawLo
    bcc pfcDone
    inc zpDrawHi
pfcDone:
    rts

// pokeActor — write curChar/curColor to the screen cell at curRow/curCol.
pokeActor:
    jsr pointerForScreen
    ldy #0
    lda curChar
    sta (zpDrawLo), y
    jsr pointerForColor
    lda curColor
    sta (zpDrawLo), y
    rts

// redrawCell — restore whatever mazeWalls/mazeItems says belongs at
// curRow/curCol (used whenever an actor leaves a tile).
redrawCell:
    jsr setCellPtrWalls
    ldy #0
    lda (zpCellLo), y
    cmp #CELL_WALL
    beq rcWall
    jsr setCellPtrItems
    ldy #0
    lda (zpCellLo), y
    tax
    lda itemCharTbl, x
    sta curChar
    lda itemColorTbl, x
    sta curColor
    jmp rcPoke
rcWall:
    lda #CHAR_WALL
    sta curChar
    lda #CLR_WALL
    sta curColor
rcPoke:
    jsr pokeActor
    rts

// ---------------------------------------------------------------------------
// Ghost movement: per-tile decision engine.
//
// Two-pass structure per elapsed tick (see ghostMoveTick): pass 1 computes
// every pending ghost's target tile from the positions as they stand at the
// start of the tick (so Inky's target reads Blinky's pre-move position
// regardless of update order); pass 2 actually moves each pending ghost
// using its already-computed target.
// ---------------------------------------------------------------------------

.const HOUSE_ENTRY_ROW = 10
.const HOUSE_ENTRY_COL = 19

.const BLINKY_SCATTER_ROW = 0
.const BLINKY_SCATTER_COL = GRID_W - 1
.const PINKY_SCATTER_ROW  = 0
.const PINKY_SCATTER_COL  = 0
.const INKY_SCATTER_ROW   = GRID_H - 1
.const INKY_SCATTER_COL   = GRID_W - 1
.const CLYDE_SCATTER_ROW  = GRID_H - 1
.const CLYDE_SCATTER_COL  = 0

ghostMoveTick:
    ldx #0
gmtLoop1:
    lda ghostMode, x
    cmp #MODE_HOUSE
    bne gmtTimerActive
    lda #0
    sta pendingMove, x
    jmp gmtNextIdx1
gmtTimerActive:
    dec ghostMoveTimer, x
    bne gmtNotPending
    jsr reloadGhostMoveTimer
    lda #1
    sta pendingMove, x
    jmp gmtNextIdx1
gmtNotPending:
    lda #0
    sta pendingMove, x
gmtNextIdx1:
    inx
    cpx #4
    bne gmtLoop1

    ldx #0
gmtPass1:
    lda pendingMove, x
    beq gmtPass1Next
    jsr computeGhostTarget
gmtPass1Next:
    inx
    cpx #4
    bne gmtPass1

    ldx #0
gmtPass2:
    lda pendingMove, x
    beq gmtPass2Next
    jsr moveOneGhost
gmtPass2Next:
    inx
    cpx #4
    bne gmtPass2
    rts

pendingMove: .byte 0,0,0,0

reloadGhostMoveTimer:
    lda ghostMode, x
    cmp #MODE_FRIGHT
    beq rgmtFright
    cmp #MODE_EATEN
    beq rgmtEaten
    lda #GHOST_SPEED_NORMAL
    jmp rgmtStore
rgmtFright:
    lda #GHOST_SPEED_FRIGHT
    jmp rgmtStore
rgmtEaten:
    lda #GHOST_SPEED_EATEN
rgmtStore:
    sta ghostMoveTimer, x
    rts

// computeGhostTarget — X = ghost index. Writes ghostTargetRow/Col, x.
computeGhostTarget:
    lda ghostMode, x
    cmp #MODE_FRIGHT
    beq cgtNone
    cmp #MODE_EATEN
    beq cgtEaten
    cpx #GHOST_BLINKY
    beq cgtBlinky
    cpx #GHOST_PINKY
    beq cgtPinky
    cpx #GHOST_INKY
    beq cgtInky
    jmp cgtClyde

cgtNone:
    rts

cgtEaten:
    lda #HOUSE_ENTRY_ROW
    sta ghostTargetRow, x
    lda #HOUSE_ENTRY_COL
    sta ghostTargetCol, x
    rts

cgtBlinky:
    lda ghostMode, x
    cmp #MODE_SCATTER
    bne cgtBlinkyChase
    lda #BLINKY_SCATTER_ROW
    sta ghostTargetRow, x
    lda #BLINKY_SCATTER_COL
    sta ghostTargetCol, x
    rts
cgtBlinkyChase:
    lda pacRow
    sta ghostTargetRow, x
    lda pacCol
    sta ghostTargetCol, x
    rts

cgtPinky:
    lda ghostMode, x
    cmp #MODE_SCATTER
    bne cgtPinkyChase
    lda #PINKY_SCATTER_ROW
    sta ghostTargetRow, x
    lda #PINKY_SCATTER_COL
    sta ghostTargetCol, x
    rts
cgtPinkyChase:
    stx ghostIdxSave2
    jsr computeAheadOfPac4
    ldx ghostIdxSave2
    lda aheadRow
    sta ghostTargetRow, x
    lda aheadCol
    sta ghostTargetCol, x
    rts

cgtInky:
    lda ghostMode, x
    cmp #MODE_SCATTER
    bne cgtInkyChase
    lda #INKY_SCATTER_ROW
    sta ghostTargetRow, x
    lda #INKY_SCATTER_COL
    sta ghostTargetCol, x
    rts
cgtInkyChase:
    stx ghostIdxSave2
    jsr computeAheadOfPac2
    // target = 2*ahead - blinkyPos, clamped to the grid
    lda aheadRow
    asl
    sec
    sbc ghostRow + GHOST_BLINKY
    sta zpTmpA
    jsr clampRowFromTmpA
    ldx ghostIdxSave2
    sta ghostTargetRow, x

    lda aheadCol
    asl
    sec
    sbc ghostCol + GHOST_BLINKY
    sta zpTmpA
    jsr clampColFromTmpA
    ldx ghostIdxSave2
    sta ghostTargetCol, x
    rts

cgtClyde:
    lda ghostMode, x
    cmp #MODE_SCATTER
    bne cgtClydeChaseCheck
    lda #CLYDE_SCATTER_ROW
    sta ghostTargetRow, x
    lda #CLYDE_SCATTER_COL
    sta ghostTargetCol, x
    rts
cgtClydeChaseCheck:
    stx ghostIdxSave2
    lda ghostRow, x
    sta distCandRow
    lda ghostCol, x
    sta distCandCol
    lda pacRow
    sta distTargRow
    lda pacCol
    sta distTargCol
    jsr calcDistSq
    ldx ghostIdxSave2
    lda distResultHi
    bne cgtClydeChase
    lda distResultLo
    cmp #65                     // sqrt(65) > 8: farther than 8 tiles
    bcs cgtClydeChase
    lda #CLYDE_SCATTER_ROW
    sta ghostTargetRow, x
    lda #CLYDE_SCATTER_COL
    sta ghostTargetCol, x
    rts
cgtClydeChase:
    lda pacRow
    sta ghostTargetRow, x
    lda pacCol
    sta ghostTargetCol, x
    rts

ghostIdxSave2: .byte 0
aheadRow: .byte 0
aheadCol: .byte 0

// computeAheadOfPac4/2 — N tiles ahead of Pac-Man's current facing
// direction, clamped to the grid (the classic "faces-up overflow" quirk is
// intentionally not reproduced). Output: aheadRow/aheadCol.
computeAheadOfPac4:
    ldy pacDir
    lda dirDRow, y
    asl
    asl
    clc
    adc pacRow
    sta zpTmpA
    jsr clampRowFromTmpA
    sta aheadRow

    ldy pacDir
    lda dirDCol, y
    asl
    asl
    clc
    adc pacCol
    sta zpTmpA
    jsr clampColFromTmpA
    sta aheadCol
    rts

computeAheadOfPac2:
    ldy pacDir
    lda dirDRow, y
    asl
    clc
    adc pacRow
    sta zpTmpA
    jsr clampRowFromTmpA
    sta aheadRow

    ldy pacDir
    lda dirDCol, y
    asl
    clc
    adc pacCol
    sta zpTmpA
    jsr clampColFromTmpA
    sta aheadCol
    rts

clampRowFromTmpA:
    lda zpTmpA
    bmi crfLow
    cmp #GRID_H
    bcc crfOk
    lda #GRID_H - 1
    rts
crfOk:
    lda zpTmpA
    rts
crfLow:
    lda #0
    rts

clampColFromTmpA:
    lda zpTmpA
    bmi ccfLow
    cmp #GRID_W
    bcc ccfOk
    lda #GRID_W - 1
    rts
ccfOk:
    lda zpTmpA
    rts
ccfLow:
    lda #0
    rts

// calcDistSq — squared Euclidean distance between (distCandRow,distCandCol)
// and (distTargRow,distTargCol) via the precomputed sqrTbl. 16-bit result
// in distResultLo/Hi (max 23^2+39^2 = 2050, comfortably fits).
calcDistSq:
    lda distCandRow
    sec
    sbc distTargRow
    bpl cdsRowPos
    eor #$FF
    clc
    adc #1
cdsRowPos:
    tay
    lda sqrTblLo, y
    sta distResultLo
    lda sqrTblHi, y
    sta distResultHi

    lda distCandCol
    sec
    sbc distTargCol
    bpl cdsColPos
    eor #$FF
    clc
    adc #1
cdsColPos:
    tay
    lda distResultLo
    clc
    adc sqrTblLo, y
    sta distResultLo
    lda distResultHi
    adc sqrTblHi, y
    sta distResultHi
    rts

distCandRow: .byte 0
distCandCol: .byte 0
distTargRow: .byte 0
distTargCol: .byte 0
distResultLo: .byte 0
distResultHi: .byte 0

// moveOneGhost — X = ghost index. Resolves and applies this ghost's single
// tile move for the current tick, using its pre-computed target tile
// (ghostTargetRow/Col, x) for scatter/chase/eaten, or a random legal
// direction for frightened.
moveOneGhost:
    stx ghostIdxSave
    lda ghostRow, x
    sta ghostRowTmp
    lda ghostCol, x
    sta ghostColTmp

    lda ghostMode, x
    cmp #MODE_FRIGHT
    bne mogNotFrightened
    jmp mogFrightened
mogNotFrightened:

    lda #$FF
    sta bestDistLo
    sta bestDistHi
    lda #DIR_NONE
    sta bestDir
    lda #0
    sta ordIdx

mogCandLoop:
    ldy ordIdx
    lda dirOrder, y
    sta candDir

    lda ghostMode, x
    cmp #MODE_EATEN
    beq mogSkipReverseCheck
    ldy candDir
    lda dirReverse, y
    cmp ghostDir, x
    beq mogCandSkip
mogSkipReverseCheck:
    lda candDir
    ldx ghostRowTmp
    ldy ghostColTmp
    jsr canMoveGhost
    bcc mogCandSkip

    lda targRow
    sta distCandRow
    lda targCol
    sta distCandCol
    ldx ghostIdxSave
    lda ghostTargetRow, x
    sta distTargRow
    lda ghostTargetCol, x
    sta distTargCol
    jsr calcDistSq

    lda distResultHi
    cmp bestDistHi
    bcc mogTakeBest
    bne mogCandSkip
    lda distResultLo
    cmp bestDistLo
    bcs mogCandSkip
mogTakeBest:
    lda distResultLo
    sta bestDistLo
    lda distResultHi
    sta bestDistHi
    lda candDir
    sta bestDir
    lda targRow
    sta bestRow
    lda targCol
    sta bestCol
mogCandSkip:
    ldx ghostIdxSave
    inc ordIdx
    lda ordIdx
    cmp #4
    beq mogCandLoopDone
    jmp mogCandLoop
mogCandLoopDone:

    lda bestDir
    cmp #DIR_NONE
    beq mogNoBestYet
    jmp mogApplyBest
mogNoBestYet:

    // Every non-reverse direction was blocked: allow reversal as a last
    // resort so a ghost can never become permanently stuck.
    ldx ghostIdxSave
    ldy ghostDir, x
    lda dirReverse, y
    sta candDir
    ldx ghostRowTmp
    ldy ghostColTmp
    jsr canMoveGhost
    bcs mogFallbackLegal1
    jmp mogNoMove
mogFallbackLegal1:
    lda candDir
    sta bestDir
    lda targRow
    sta bestRow
    lda targCol
    sta bestCol
    jmp mogApplyBest

mogFrightened:
    lda #0
    sta legalCount
    sta ordIdx
mogFrLoop:
    ldy ordIdx
    lda dirOrder, y
    sta candDir
    ldx ghostIdxSave
    ldy candDir
    lda dirReverse, y
    cmp ghostDir, x
    beq mogFrSkip
    lda candDir
    ldx ghostRowTmp
    ldy ghostColTmp
    jsr canMoveGhost
    bcc mogFrSkip
    ldy legalCount
    lda candDir
    sta legalDirs, y
    lda targRow
    sta legalRows, y
    lda targCol
    sta legalCols, y
    inc legalCount
mogFrSkip:
    inc ordIdx
    lda ordIdx
    cmp #4
    bne mogFrLoop

    lda legalCount
    bne mogFrHaveChoices

    ldx ghostIdxSave
    ldy ghostDir, x
    lda dirReverse, y
    sta candDir
    ldx ghostRowTmp
    ldy ghostColTmp
    jsr canMoveGhost
    bcs mogFallbackLegal2
    jmp mogNoMove
mogFallbackLegal2:
    lda candDir
    sta bestDir
    lda targRow
    sta bestRow
    lda targCol
    sta bestCol
    jmp mogApplyBest

mogFrHaveChoices:
    jsr lfsrStep
mogFrModLoop:
    cmp legalCount
    bcc mogFrModDone
    sec
    sbc legalCount
    jmp mogFrModLoop
mogFrModDone:
    tay
    lda legalDirs, y
    sta bestDir
    lda legalRows, y
    sta bestRow
    lda legalCols, y
    sta bestCol

mogApplyBest:
    ldx ghostIdxSave
    lda ghostRow, x
    sta curRow
    lda ghostCol, x
    sta curCol
    jsr redrawCell
    ldx ghostIdxSave
    lda bestRow
    sta ghostRow, x
    lda bestCol
    sta ghostCol, x
    lda bestDir
    sta ghostDir, x
    jsr drawGhostAt
    jsr checkEatenArrivedHome
mogNoMove:
    rts

ghostIdxSave: .byte 0
ghostRowTmp: .byte 0
ghostColTmp: .byte 0
candDir: .byte 0
bestDistLo: .byte 0
bestDistHi: .byte 0
bestDir: .byte 0
bestRow: .byte 0
bestCol: .byte 0
ordIdx: .byte 0
legalCount: .byte 0
legalDirs: .byte 0,0,0,0
legalRows: .byte 0,0,0,0
legalCols: .byte 0,0,0,0

// dirOrder — tie-break priority: up > left > down > right.
dirOrder: .byte DIR_UP, DIR_LEFT, DIR_DOWN, DIR_RIGHT
dirReverse: .byte DIR_DOWN, DIR_UP, DIR_RIGHT, DIR_LEFT   // indexed by DIR_*
dirDRow: .byte $FF, 1, 0, 0                               // up,down,left,right
dirDCol: .byte 0, 0, $FF, 1

// checkEatenArrivedHome — X = ghost index (still valid on entry, set by
// caller). If an eaten ghost has just reached the house-entry tile, put it
// into MODE_HOUSE for a short regroup pause; the existing release-timer
// machinery (houseReleaseTick) then pops it back out automatically.
checkEatenArrivedHome:
    ldx ghostIdxSave
    lda ghostMode, x
    cmp #MODE_EATEN
    bne ceahDone
    lda ghostRow, x
    cmp #HOUSE_ENTRY_ROW
    bne ceahDone
    lda ghostCol, x
    cmp #HOUSE_ENTRY_COL
    bne ceahDone
    lda #MODE_HOUSE
    sta ghostMode, x
    lda #EATEN_HOUSE_PAUSE_LO
    sta ghostReleaseTimerLo, x
    lda #EATEN_HOUSE_PAUSE_HI
    sta ghostReleaseTimerHi, x
ceahDone:
    rts

// ---------------------------------------------------------------------------
// Ghost-house release. Time-based v1 simplification (see plan): rather than
// authentic dot-count-based release, each housed ghost pops directly to the
// door-exit tile when its own release timer expires.
// ---------------------------------------------------------------------------
.const DOOR_EXIT_ROW = 9
.const DOOR_EXIT_COL = 19

houseReleaseTick:
    lda #0
    sta hrtIdx
hrtLoop:
    ldx hrtIdx
    lda ghostMode, x
    cmp #MODE_HOUSE
    bne hrtNext
    lda ghostReleaseTimerLo, x
    bne hrtDecLo
    lda ghostReleaseTimerHi, x
    beq hrtExpired
    dec ghostReleaseTimerHi, x
hrtDecLo:
    dec ghostReleaseTimerLo, x
    lda ghostReleaseTimerLo, x
    ora ghostReleaseTimerHi, x
    bne hrtNext
hrtExpired:
    lda ghostRow, x
    sta curRow
    lda ghostCol, x
    sta curCol
    jsr redrawCell
    ldx hrtIdx
    lda #DOOR_EXIT_ROW
    sta ghostRow, x
    lda #DOOR_EXIT_COL
    sta ghostCol, x
    lda globalPhase           // 0/1 alias exactly onto MODE_SCATTER/MODE_CHASE
    sta ghostMode, x
    lda #DIR_UP
    sta ghostDir, x
    jsr reloadGhostMoveTimer
    ldx hrtIdx
    jsr drawGhostAt
hrtNext:
    inc hrtIdx
    lda hrtIdx
    cmp #4
    bne hrtLoop
    rts

hrtIdx: .byte 0

// ---------------------------------------------------------------------------
// Scatter/chase global phase timer.
// ---------------------------------------------------------------------------
phaseTimerTick:
    lda globalPhaseTimerLo
    bne pttDecLo
    lda globalPhaseTimerHi
    beq pttExpired
    dec globalPhaseTimerHi
pttDecLo:
    dec globalPhaseTimerLo
    lda globalPhaseTimerLo
    ora globalPhaseTimerHi
    bne pttDone
pttExpired:
    lda phaseIndex
    cmp #PHASE_LAST_INDEX
    beq pttDone              // final phase is chase-forever: stay frozen
    inc phaseIndex
    lda globalPhase
    eor #1
    sta globalPhase
    ldy phaseIndex
    lda phaseDurationsLo, y
    sta globalPhaseTimerLo
    lda phaseDurationsHi, y
    sta globalPhaseTimerHi
    jsr forceReverseEligibleGhosts
pttDone:
    rts

// Forces a direction reversal on every ghost currently in scatter/chase
// (frightened/eaten/house-bound ghosts are unaffected), and syncs their mode
// to the freshly-toggled globalPhase.
forceReverseEligibleGhosts:
    lda #0
    sta hrtIdx
freLoop:
    ldx hrtIdx
    lda ghostMode, x
    cmp #MODE_SCATTER
    beq freReverse
    cmp #MODE_CHASE
    bne freNext
freReverse:
    lda globalPhase
    sta ghostMode, x
    ldy ghostDir, x
    lda dirReverse, y
    sta ghostDir, x
freNext:
    inc hrtIdx
    lda hrtIdx
    cmp #4
    bne freLoop
    rts

// ---------------------------------------------------------------------------
// Frightened-mode timer (power pellet).
// ---------------------------------------------------------------------------
frightTimerTick:
    lda frightActive
    beq fttDone
    lda frightenedTimerLo
    bne fttDecLo
    lda frightenedTimerHi
    beq fttExpired
    dec frightenedTimerHi
fttDecLo:
    dec frightenedTimerLo
    lda frightenedTimerLo
    ora frightenedTimerHi
    bne fttDone
fttExpired:
    jsr expireFrightened
fttDone:
    rts

frightActive: .byte 0

expireFrightened:
    lda #0
    sta frightActive
    lda #0
    sta hrtIdx
efLoop:
    ldx hrtIdx
    lda ghostMode, x
    cmp #MODE_FRIGHT
    bne efNext
    lda globalPhase
    sta ghostMode, x
    ldy ghostDir, x
    lda dirReverse, y
    sta ghostDir, x
    jsr reloadGhostMoveTimer
efNext:
    inc hrtIdx
    lda hrtIdx
    cmp #4
    bne efLoop
    rts

// triggerFrightened — called when Pac-Man eats a power pellet. Every ghost
// currently in scatter/chase flips to frightened (with a forced reversal);
// eaten/house ghosts are unaffected. Re-eating a pellet while already
// frightened just restarts the timer/counter below without re-reversing
// ghosts that are already frightened.
triggerFrightened:
    lda #1
    sta frightActive
    lda #FRIGHTENED_RELOAD_LO
    sta frightenedTimerLo
    lda #FRIGHTENED_RELOAD_HI
    sta frightenedTimerHi
    lda #0
    sta ghostEatenCount
    lda #0
    sta hrtIdx
tfLoop:
    ldx hrtIdx
    lda ghostMode, x
    cmp #MODE_SCATTER
    beq tfSet
    cmp #MODE_CHASE
    bne tfNext
tfSet:
    lda #MODE_FRIGHT
    sta ghostMode, x
    ldy ghostDir, x
    lda dirReverse, y
    sta ghostDir, x
    jsr reloadGhostMoveTimer
tfNext:
    inc hrtIdx
    lda hrtIdx
    cmp #4
    bne tfLoop
    rts

// ---------------------------------------------------------------------------
// Collision detection — tile-equality only (movement is grid-locked to the
// same tick boundary, so no continuous-motion overlap to worry about).
// ---------------------------------------------------------------------------
collisionCheck:
    lda #0
    sta hrtIdx
ccLoop:
    ldx hrtIdx
    lda ghostRow, x
    cmp pacRow
    bne ccNext
    lda ghostCol, x
    cmp pacCol
    bne ccNext

    lda ghostMode, x
    cmp #MODE_FRIGHT
    beq ccEat
    cmp #MODE_EATEN
    beq ccNext              // eyes are harmless
    cmp #MODE_HOUSE
    beq ccNext              // can't actually happen (door blocks Pac-Man)
    jsr loseLife
    rts                      // board state changed; stop scanning this tick
ccEat:
    jsr eatGhost
ccNext:
    inc hrtIdx
    lda hrtIdx
    cmp #4
    bne ccLoop
    rts

// eatGhost — X = ghost index (collision already confirmed by caller).
eatGhost:
    lda #MODE_EATEN
    sta ghostMode, x
    jsr reloadGhostMoveTimer
    stx ghostIdxSave
    lda ghostEatenCount
    tay
    lda eatScoreLo, y
    sta addAmountLo
    lda eatScoreHi, y
    sta addAmountHi
    jsr addScore
    inc ghostEatenCount
    ldx ghostIdxSave
    jsr drawGhostAt
    rts

eatScoreLo: .byte <200, <400, <800, <1600
eatScoreHi: .byte >200, >400, >800, >1600

// ---------------------------------------------------------------------------
// Life lost / level clear / game over.
// ---------------------------------------------------------------------------
loseLife:
    dec lives
    jsr renderScoreLivesLevel
    lda lives
    bne llContinue
    jmp gameOverSequence
llContinue:
    lda #GAMESTATE_LIFE_LOST
    sta gameState
    lda #LIFE_LOST_PAUSE_LO
    sta pauseTimerLo
    lda #LIFE_LOST_PAUSE_HI
    sta pauseTimerHi
    rts

gameOverSequence:
    jsr drawGameOverMessage
    lda #GAMESTATE_GAME_OVER
    sta gameState
    rts

// pauseStateTick — runs once per elapsed tick while gameState is
// LIFE_LOST or LEVEL_CLEAR; on expiry, resets the board appropriately and
// returns to GAMESTATE_PLAYING.
pauseStateTick:
    lda pauseTimerLo
    bne pstDecLo
    lda pauseTimerHi
    beq pstExpired
    dec pauseTimerHi
pstDecLo:
    dec pauseTimerLo
    lda pauseTimerLo
    ora pauseTimerHi
    bne pstDone
pstExpired:
    lda gameState
    cmp #GAMESTATE_LIFE_LOST
    beq pstLifeLost

    // Level clear
    jsr resetItems
    inc level
    jsr resetPositions
    jsr drawMaze
    jsr drawActors
    jsr renderScoreLivesLevel
    lda #GAMESTATE_PLAYING
    sta gameState
    rts

pstLifeLost:
    jsr resetPositions
    jsr drawActors
    lda #GAMESTATE_PLAYING
    sta gameState
pstDone:
    rts

pauseTimerLo: .byte 0
pauseTimerHi: .byte 0

// ---------------------------------------------------------------------------
// addScore / decDotsRemaining
// ---------------------------------------------------------------------------
addScore:
    clc
    lda scoreByte0
    adc addAmountLo
    sta scoreByte0
    lda scoreByte1
    adc addAmountHi
    sta scoreByte1
    lda scoreByte2
    adc #0
    sta scoreByte2
    jsr renderScoreLivesLevel
    rts

addAmountLo: .byte 0
addAmountHi: .byte 0
scoreByte0: .byte 0
scoreByte1: .byte 0
scoreByte2: .byte 0

decDotsRemaining:
    lda dotsRemainingLo
    bne ddrDecLo
    dec dotsRemainingHi
ddrDecLo:
    dec dotsRemainingLo
    lda dotsRemainingLo
    ora dotsRemainingHi
    bne ddrDone
    lda #GAMESTATE_LEVEL_CLEAR
    sta gameState
    lda #LEVEL_CLEAR_PAUSE_LO
    sta pauseTimerLo
    lda #LEVEL_CLEAR_PAUSE_HI
    sta pauseTimerHi
ddrDone:
    rts

dotsRemainingLo: .byte 0
dotsRemainingHi: .byte 0

// ---------------------------------------------------------------------------
// resetItems — regenerate mazeItems from mazeWalls (open cell -> dot),
// then carve out the ghost-house interior and drop the four power pellets.
// Same 3-page+192-tail sweep idiom as conway's grid routines, but uses
// absolute,X addressing directly on the fixed mazeWalls/mazeItems tables
// rather than zero-page indirect pointers (there is no double-buffer to
// swap here, so no pointer indirection is needed).
// ---------------------------------------------------------------------------
resetItems:
    ldx #0
riPage:
    lda mazeWalls, x
    jsr wallToItem
    sta mazeItems, x
    lda mazeWalls+256, x
    jsr wallToItem
    sta mazeItems+256, x
    lda mazeWalls+512, x
    jsr wallToItem
    sta mazeItems+512, x
    inx
    bne riPage

    ldx #0
riTail:
    lda mazeWalls+768, x
    jsr wallToItem
    sta mazeItems+768, x
    inx
    cpx #192
    bne riTail

    // Ghost-house interior (row 11, cols 17-22): CELL_OPEN in mazeWalls, but
    // ghosts start here, so no dot belongs on these cells.
    lda #ITEM_NONE
    sta mazeItems + 457
    sta mazeItems + 458
    sta mazeItems + 459
    sta mazeItems + 460
    sta mazeItems + 461
    sta mazeItems + 462

    // Power pellets (near the four corners).
    lda #ITEM_PELLET
    sta mazeItems + 41
    sta mazeItems + 78
    sta mazeItems + 841
    sta mazeItems + 878

    lda #<620
    sta dotsRemainingLo
    lda #>620
    sta dotsRemainingHi
    rts

// wallToItem — A(in) = mazeWalls cell value -> A(out) = mazeItems value.
// CELL_WALL and CELL_DOOR both yield ITEM_NONE; CELL_OPEN yields ITEM_DOT.
wallToItem:
    cmp #CELL_OPEN
    beq wtiOpen
    lda #ITEM_NONE
    rts
wtiOpen:
    lda #ITEM_DOT
    rts

// ---------------------------------------------------------------------------
// resetPositions — reset Pac-Man and all four ghosts to their level-start
// tiles/modes/timers. Never touches mazeItems/mazeWalls.
// ---------------------------------------------------------------------------
.const PAC_START_ROW = 17
.const PAC_START_COL = 19
.const BLINKY_START_ROW = 9
.const BLINKY_START_COL = 19
.const HOUSE_ROW = 11
.const PINKY_START_COL = 19
.const INKY_START_COL  = 18
.const CLYDE_START_COL = 20

resetPositions:
    lda #PAC_START_ROW
    sta pacRow
    lda #PAC_START_COL
    sta pacCol
    lda #DIR_LEFT
    sta pacDir
    lda #DIR_NONE
    sta pacNextDir
    lda #PAC_SPEED
    sta pacMoveTimer

    lda #0
    sta phaseIndex
    sta globalPhase
    sta frightActive
    sta ghostEatenCount
    lda phaseDurationsLo
    sta globalPhaseTimerLo
    lda phaseDurationsHi
    sta globalPhaseTimerHi

    // Blinky starts outside the house, already in scatter.
    lda #BLINKY_START_ROW
    sta ghostRow + GHOST_BLINKY
    lda #BLINKY_START_COL
    sta ghostCol + GHOST_BLINKY
    lda #DIR_UP
    sta ghostDir + GHOST_BLINKY
    lda #MODE_SCATTER
    sta ghostMode + GHOST_BLINKY
    lda #GHOST_SPEED_NORMAL
    sta ghostMoveTimer + GHOST_BLINKY

    // Pinky
    lda #HOUSE_ROW
    sta ghostRow + GHOST_PINKY
    lda #PINKY_START_COL
    sta ghostCol + GHOST_PINKY
    lda #DIR_UP
    sta ghostDir + GHOST_PINKY
    lda #MODE_HOUSE
    sta ghostMode + GHOST_PINKY
    lda #GHOST_SPEED_NORMAL
    sta ghostMoveTimer + GHOST_PINKY
    lda #RELEASE_PINKY_LO
    sta ghostReleaseTimerLo + GHOST_PINKY
    lda #RELEASE_PINKY_HI
    sta ghostReleaseTimerHi + GHOST_PINKY

    // Inky
    lda #HOUSE_ROW
    sta ghostRow + GHOST_INKY
    lda #INKY_START_COL
    sta ghostCol + GHOST_INKY
    lda #DIR_UP
    sta ghostDir + GHOST_INKY
    lda #MODE_HOUSE
    sta ghostMode + GHOST_INKY
    lda #GHOST_SPEED_NORMAL
    sta ghostMoveTimer + GHOST_INKY
    lda #RELEASE_INKY_LO
    sta ghostReleaseTimerLo + GHOST_INKY
    lda #RELEASE_INKY_HI
    sta ghostReleaseTimerHi + GHOST_INKY

    // Clyde
    lda #HOUSE_ROW
    sta ghostRow + GHOST_CLYDE
    lda #CLYDE_START_COL
    sta ghostCol + GHOST_CLYDE
    lda #DIR_UP
    sta ghostDir + GHOST_CLYDE
    lda #MODE_HOUSE
    sta ghostMode + GHOST_CLYDE
    lda #GHOST_SPEED_NORMAL
    sta ghostMoveTimer + GHOST_CLYDE
    lda #RELEASE_CLYDE_LO
    sta ghostReleaseTimerLo + GHOST_CLYDE
    lda #RELEASE_CLYDE_HI
    sta ghostReleaseTimerHi + GHOST_CLYDE
    rts

// ---------------------------------------------------------------------------
// drawMaze — full-screen redraw of the 24-row playfield from
// mazeWalls/mazeItems (same 3-page+192-tail sweep as conway's drawGrid).
// ---------------------------------------------------------------------------
drawMaze:
    ldx #0
dmPage:
    lda mazeItems, x
    sta glyphItemIn
    lda mazeWalls, x
    jsr cellGlyph
    lda glyphChar
    sta SCREEN, x
    lda glyphColor
    sta COLORRAM, x

    lda mazeItems+256, x
    sta glyphItemIn
    lda mazeWalls+256, x
    jsr cellGlyph
    lda glyphChar
    sta SCREEN+256, x
    lda glyphColor
    sta COLORRAM+256, x

    lda mazeItems+512, x
    sta glyphItemIn
    lda mazeWalls+512, x
    jsr cellGlyph
    lda glyphChar
    sta SCREEN+512, x
    lda glyphColor
    sta COLORRAM+512, x
    inx
    bne dmPage

    ldx #0
dmTail:
    lda mazeItems+768, x
    sta glyphItemIn
    lda mazeWalls+768, x
    jsr cellGlyph
    lda glyphChar
    sta SCREEN+768, x
    lda glyphColor
    sta COLORRAM+768, x
    inx
    cpx #192
    bne dmTail
    rts

// cellGlyph — A(in) = mazeWalls value, glyphItemIn (preset by caller) =
// mazeItems value -> glyphChar/glyphColor.
cellGlyph:
    cmp #CELL_WALL
    beq cgWall
    ldy glyphItemIn
    lda itemCharTbl, y
    sta glyphChar
    lda itemColorTbl, y
    sta glyphColor
    rts
cgWall:
    lda #CHAR_WALL
    sta glyphChar
    lda #CLR_WALL
    sta glyphColor
    rts

glyphItemIn: .byte 0
glyphChar: .byte 0
glyphColor: .byte 0

itemCharTbl:  .byte CHAR_EMPTY, CHAR_DOT, CHAR_PELLET
itemColorTbl: .byte CLR_EMPTY, CLR_DOT, CLR_PELLET

// ---------------------------------------------------------------------------
// drawActors — draw Pac-Man then all four ghosts on top of the maze.
// ---------------------------------------------------------------------------
drawActors:
    lda pacRow
    sta curRow
    lda pacCol
    sta curCol
    lda #CHAR_PACMAN
    sta curChar
    lda #CLR_PACMAN
    sta curColor
    jsr pokeActor

    ldx #0
daLoop:
    jsr drawGhostAt
    inx
    cpx #4
    bne daLoop
    rts

// drawGhostAt — X = ghost index. Glyph/colour depend on mode.
drawGhostAt:
    lda ghostMode, x
    cmp #MODE_FRIGHT
    beq dgaFright
    cmp #MODE_EATEN
    beq dgaEaten
    lda #CHAR_GHOST
    sta curChar
    lda ghostColorTbl, x
    sta curColor
    jmp dgaPoke
dgaFright:
    lda #CHAR_FRIGHT
    sta curChar
    lda #CLR_FRIGHT
    sta curColor
    jmp dgaPoke
dgaEaten:
    lda #CHAR_EYES
    sta curChar
    lda #CLR_EYES
    sta curColor
dgaPoke:
    lda ghostRow, x
    sta curRow
    lda ghostCol, x
    sta curCol
    jsr pokeActor
    rts

ghostColorTbl: .byte CLR_BLINKY, CLR_PINKY, CLR_INKY, CLR_CLYDE

// ---------------------------------------------------------------------------
// clearScreen — fill all 1000 screen-RAM bytes with spaces (used on quit,
// same idiom as conway's clearScreen).
// ---------------------------------------------------------------------------
clearScreen:
    lda #CHAR_EMPTY
    ldx #0
csPage:
    sta SCREEN, x
    sta SCREEN+256, x
    sta SCREEN+512, x
    inx
    bne csPage
    ldx #0
csTail:
    sta SCREEN+768, x
    inx
    cpx #232
    bne csTail
    rts

// ---------------------------------------------------------------------------
// Status line (row 24): static labels drawn once, digit fields updated
// whenever score/lives/level change.
// ---------------------------------------------------------------------------
.const SCORE_LABEL_COL  = 0
.const SCORE_DIGITS_COL = 6
.const LIVES_LABEL_COL  = 13
.const LIVES_DIGIT_COL  = 19
.const LEVEL_LABEL_COL  = 21
.const LEVEL_DIGITS_COL = 27

.encoding "screencode_mixed"
statusLabelScore: .text "score:"
statusLabelLives: .text "lives:"
statusLabelLevel: .text "level:"
.encoding "petscii_mixed"

drawStatusLabels:
    ldx #0
dslScoreLoop:
    lda statusLabelScore, x
    sta SCREEN + STATUS_ROW_OFFSET + SCORE_LABEL_COL, x
    inx
    cpx #6
    bne dslScoreLoop

    ldx #0
dslLivesLoop:
    lda statusLabelLives, x
    sta SCREEN + STATUS_ROW_OFFSET + LIVES_LABEL_COL, x
    inx
    cpx #6
    bne dslLivesLoop

    ldx #0
dslLevelLoop:
    lda statusLabelLevel, x
    sta SCREEN + STATUS_ROW_OFFSET + LEVEL_LABEL_COL, x
    inx
    cpx #6
    bne dslLevelLoop

    lda #CLR_DOT
    ldx #0
dslColorLoop:
    sta COLORRAM + STATUS_ROW_OFFSET, x
    inx
    cpx #40
    bne dslColorLoop
    rts

// renderScoreLivesLevel — re-render the three digit fields. Score uses a
// 24-bit repeated-subtraction-against-powers-of-ten decimal expansion (6
// digits); lives is a single digit; level is two digits via divide-by-10.
renderScoreLivesLevel:
    lda scoreByte0
    sta remLo
    lda scoreByte1
    sta remMid
    lda scoreByte2
    sta remHi

    lda #0
    sta rsllIdx
rsllDigitLoop:
    lda #0
    sta rsllDigit
    ldy rsllIdx
rsllSubLoop:
    jsr cmp24GE
    bcc rsllDigitDone
    jsr sub24
    inc rsllDigit
    jmp rsllSubLoop
rsllDigitDone:
    lda rsllDigit
    clc
    adc #$30                  // digit screencodes == PETSCII/ASCII '0'-'9'
    ldy rsllIdx
    sta SCREEN + STATUS_ROW_OFFSET + SCORE_DIGITS_COL, y
    inc rsllIdx
    lda rsllIdx
    cmp #6
    bne rsllDigitLoop

    lda lives
    clc
    adc #$30
    sta SCREEN + STATUS_ROW_OFFSET + LIVES_DIGIT_COL

    lda level
    sta levelRem
    lda #0
    sta levelTens
lvlTensLoop:
    lda levelRem
    cmp #10
    bcc lvlTensDone
    sec
    sbc #10
    sta levelRem
    inc levelTens
    jmp lvlTensLoop
lvlTensDone:
    lda levelTens
    clc
    adc #$30
    sta SCREEN + STATUS_ROW_OFFSET + LEVEL_DIGITS_COL
    lda levelRem
    clc
    adc #$30
    sta SCREEN + STATUS_ROW_OFFSET + LEVEL_DIGITS_COL + 1
    rts

// cmp24GE — Y = place-value index; carry set if (remHi:remMid:remLo) >=
// (placeHi:placeMid:placeLo)[y].
cmp24GE:
    lda remHi
    cmp placeHi, y
    bcc c24Lt
    bne c24Ge
    lda remMid
    cmp placeMid, y
    bcc c24Lt
    bne c24Ge
    lda remLo
    cmp placeLo, y
c24Ge:
    bcc c24Lt
    sec
    rts
c24Lt:
    clc
    rts

// sub24 — Y = place-value index; rem -= place[y] (caller already verified
// rem >= place[y] via cmp24GE).
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

placeLo:  .byte $A0, $10, $E8, $64, $0A, $01     // 100000,10000,1000,100,10,1
placeMid: .byte $86, $27, $03, $00, $00, $00
placeHi:  .byte $01, $00, $00, $00, $00, $00

rsllIdx: .byte 0
rsllDigit: .byte 0
remLo: .byte 0
remMid: .byte 0
remHi: .byte 0
levelRem: .byte 0
levelTens: .byte 0

// drawGameOverMessage — overwrite the status row with the end-of-game
// prompt (the game has ended; the score/lives/level fields no longer need
// to persist there).
.encoding "screencode_mixed"
gameOverText: .text "game over - press any key to quit"
gameOverTextEnd:
.encoding "petscii_mixed"
.const GAMEOVER_TEXT_LEN = gameOverTextEnd - gameOverText

drawGameOverMessage:
    ldx #0
gomLoop:
    lda gameOverText, x
    sta SCREEN + STATUS_ROW_OFFSET, x
    inx
    cpx #GAMEOVER_TEXT_LEN
    bne gomLoop
    rts

// ---------------------------------------------------------------------------
// lfsrStep — 8-bit Galois LFSR (poly x^8+x^6+x^5+x^4+1, mask $B8), same as
// conway's. Used for the frightened-ghost random direction pick.
// ---------------------------------------------------------------------------
lfsrStep:
    lda zpLfsr
    lsr
    bcc lfsrNFB
    eor #$B8
lfsrNFB:
    sta zpLfsr
    rts

// ---------------------------------------------------------------------------
// Generic single-cell draw/pointer parameters (see the cell-pointer /
// drawing helpers section above).
// ---------------------------------------------------------------------------
curRow:   .byte 0
curCol:   .byte 0
curChar:  .byte 0
curColor: .byte 0

// ---------------------------------------------------------------------------
// Global game state.
// ---------------------------------------------------------------------------
gamePaused: .byte 0     // 0 = running, $FF = paused
gameState:  .byte 0     // GAMESTATE_*
lastJiffy:  .byte 0
lives:      .byte 3
level:      .byte 1

// ---------------------------------------------------------------------------
// Pac-Man state.
// ---------------------------------------------------------------------------
pacRow:       .byte 0
pacCol:       .byte 0
pacDir:       .byte DIR_LEFT
pacNextDir:   .byte DIR_NONE
pacMoveTimer: .byte PAC_SPEED

// ---------------------------------------------------------------------------
// Ghost state — parallel arrays indexed by GHOST_BLINKY/PINKY/INKY/CLYDE.
// ---------------------------------------------------------------------------
ghostRow:            .byte 0,0,0,0
ghostCol:            .byte 0,0,0,0
ghostDir:            .byte 0,0,0,0
ghostMode:           .byte 0,0,0,0
ghostMoveTimer:      .byte 0,0,0,0
ghostReleaseTimerLo: .byte 0,0,0,0
ghostReleaseTimerHi: .byte 0,0,0,0
ghostTargetRow:      .byte 0,0,0,0
ghostTargetCol:      .byte 0,0,0,0

globalPhase:         .byte 0     // 0 = scatter, 1 = chase (aliases MODE_SCATTER/MODE_CHASE)
phaseIndex:          .byte 0
globalPhaseTimerLo:  .byte 0
globalPhaseTimerHi:  .byte 0
frightenedTimerLo:   .byte 0
frightenedTimerHi:   .byte 0
ghostEatenCount:     .byte 0

// Scatter/chase phase durations, in elapsed jiffy ticks (~60/sec NTSC):
// 7s,20s,7s,20s,5s,20s,5s,forever (index 7 is never actually reloaded —
// phaseTimerTick freezes once phaseIndex reaches PHASE_LAST_INDEX).
phaseDurationsLo: .byte $A4,$B0,$A4,$B0,$2C,$B0,$2C,$00
phaseDurationsHi: .byte $01,$04,$01,$04,$01,$04,$01,$00

// ---------------------------------------------------------------------------
// Row -> byte-offset table (row*40), reused by every single-cell pointer
// helper (setCellPtrWalls/Items, pointerForScreen/Color). Same table conway
// uses for its grid buffers.
// ---------------------------------------------------------------------------
rowOffLo:
    .byte $00,$28,$50,$78,$A0,$C8,$F0   // rows  0-6
    .byte $18,$40,$68,$90,$B8,$E0       // rows  7-12
    .byte $08,$30,$58,$80,$A8,$D0,$F8   // rows 13-19
    .byte $20,$48,$70,$98               // rows 20-23

rowOffHi:
    .byte $00,$00,$00,$00,$00,$00,$00   // rows  0-6   (offsets 0-240)
    .byte $01,$01,$01,$01,$01,$01       // rows  7-12  (offsets 280-480)
    .byte $02,$02,$02,$02,$02,$02,$02   // rows 13-19  (offsets 520-760)
    .byte $03,$03,$03,$03               // rows 20-23  (offsets 800-920)

// ---------------------------------------------------------------------------
// Squared-distance lookup table (index = absolute delta 0-39). Used by
// calcDistSq to avoid a runtime multiply when scoring ghost move candidates.
// ---------------------------------------------------------------------------
sqrTblLo: .byte $00,$01,$04,$09,$10,$19,$24,$31,$40,$51,$64,$79,$90,$A9,$C4,$E1,$00,$21,$44,$69,$90,$B9,$E4,$11,$40,$71,$A4,$D9,$10,$49,$84,$C1,$00,$41,$84,$C9,$10,$59,$A4,$F1
sqrTblHi: .byte $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$01,$01,$01,$01,$01,$01,$01,$02,$02,$02,$02,$02,$03,$03,$03,$03,$04,$04,$04,$04,$05,$05,$05,$05

// ---------------------------------------------------------------------------
// mazeWalls — hand-authored 40x24 maze (read-only). 0 = open, 1 = wall,
// 2 = ghost-only door (blocks Pac-Man, passable for ghosts). Row 7 is
// TUNNEL_ROW (fully open, including both outer edge columns). The ASCII art
// above each row is the authoritative layout; the .byte data below it must
// match ('#'=wall, '.'=open, 'D'=door). Rows 10-12 / cols 16-23 are the
// ghost house.
// ---------------------------------------------------------------------------
// ########################################
mazeWalls:
    .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1
// #......................................#
    .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
// #.###...###...###......###...###...###.#
    .byte 1,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,1
// #......................................#
    .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
// #.###...###...###......###...###...###.#
    .byte 1,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,1
// #......................................#
    .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
// #.###...###...###......###...###...###.#
    .byte 1,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,1
// ........................................    (TUNNEL_ROW: both edges open)
    .byte 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
// #.###...###...###......###...###...###.#
    .byte 1,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,1
// #......................................#
    .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
// #.###...###...###.###DD###.....###...###.#   (row 10: ghost-house top + door)
    .byte 1,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,1,1,2,2,1,1,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,1
// #...............#......#...............#    (row 11: ghost-house middle)
    .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1,0,0,0,0,0,0,1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
// #.###...###...############...###...###.#     (row 12: ghost-house bottom)
    .byte 1,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,1,1,1,1,1,1,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,1
// #......................................#
    .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
// #.###...###...###......###...###...###.#
    .byte 1,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,1
// #......................................#
    .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
// #.###...###...###......###...###...###.#
    .byte 1,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,1
// #......................................#
    .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
// #.###...###...###......###...###...###.#
    .byte 1,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,1
// #......................................#
    .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
// #.###...###...###......###...###...###.#
    .byte 1,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,1
// #......................................#
    .byte 1,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,1
// #.###...###...###......###...###...###.#
    .byte 1,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,0,0,0,1,1,1,0,0,0,1,1,1,0,0,0,1,1,1,0,1
// ########################################
    .byte 1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1

// mazeItems — mutable (dots/pellets), regenerated at runtime by resetItems.
// Reserved here as 960 zero bytes; never hand-authored.
mazeItems:
    .fill 960, 0
