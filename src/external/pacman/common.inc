; src/external/pacman/common.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; App-private zero-page allocations and constants for Pac-Man (Pac64) rewrite.
; Scratch ZP range: $70-$8F.

; --- Zero-Page Allocations ---
zpPacRow       = $70 ; Pac-Man row
zpPacCol       = $71 ; Pac-Man column
zpPacDir       = $72 ; Pac-Man current direction (DIR_UP, DIR_DOWN, etc.)
zpPacNextDir   = $73 ; Pac-Man buffered input direction
zpPacTimer     = $74 ; Pac-Man move tick timer

zpGameState    = $75 ; Game state (0=Menu, 1=Playing, 2=Life Lost, 3=Level Clear, 4=Game Over)
zpPaused       = $76 ; Pause status (0=Running, 1=Paused)
zpLfsr         = $77 ; Galois LFSR state (RNG for frightened ghosts)
zpLastJiffy    = $78 ; Saved jiffy clock snapshot (reads $A2)
zpLevel        = $79 ; Current level (1-256)
zpLives        = $7A ; Lives remaining (0-3)

; Temporaries and calculation scratch
zpTmpRow       = $7B
zpTmpCol       = $7C
zpTmpVal       = $7D
zpTmpPtrLo     = $7E
zpTmpPtrHi     = $7F
zpTmpDistLo    = $80
zpTmpDistHi    = $81
zpGhostIdx     = $82 ; Index of currently processing ghost (0-3)
dotsRemainingLo = $83
dotsRemainingHi = $84


; --- Directions ---
DIR_UP    = 0
DIR_DOWN  = 1
DIR_LEFT  = 2
DIR_RIGHT = 3
DIR_NONE  = $FF

; --- Game States ---
STATE_MENU        = 0
STATE_PLAYING     = 1
STATE_LIFE_LOST   = 2
STATE_LEVEL_CLEAR = 3
STATE_GAME_OVER   = 4

; --- Dimensions ---
GRID_W = 40
GRID_H = 25
PLAY_H = 24 ; Active maze rows (0 to 23), row 24 is status bar

SCREEN   = $0400
COLORRAM = $D800
JIFFY_CLK = $A2
; --- Item Constants ---
ITEM_NONE   = 0
ITEM_DOT    = 1
ITEM_PELLET = 2
ITEM_FRUIT  = 3


; --- Grid Characters ---
CHAR_WALL   = $A0 ; Reverse space for walls
CHAR_EMPTY  = $20 ; Standard space
CHAR_DOT    = $2E ; PETSCII '.'
CHAR_PELLET = $56 ; PETSCII '*' or similar symbol
CHAR_PACMAN = $51 ; PETSCII 'Q' (Pac-Man like shape)
CHAR_GHOST  = $47 ; PETSCII 'G' (Ghost)
CHAR_EYES   = $3A ; PETSCII ':' (Eaten ghost eyes)

; --- Colors ---
COLOR_BLACK  = 0
COLOR_WHITE  = 1
COLOR_RED    = 2
COLOR_CYAN   = 3
COLOR_PINK   = 10
COLOR_ORANGE = 8
COLOR_YELLOW = 7
COLOR_BLUE   = 6

; --- Ghost Index Constants ---
GHOST_BLINKY = 0
GHOST_PINKY  = 1
GHOST_INKY   = 2
GHOST_CLYDE  = 3

; --- Ghost Modes ---
MODE_CHASE      = 0
MODE_SCATTER    = 1
MODE_FRIGHTENED = 2
MODE_EATEN      = 3

