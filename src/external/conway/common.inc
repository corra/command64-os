; src/external/conway/common.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; App-private constants for conway, not covered by the shared
; include/ca65/command64.inc (KernalGetIn and everything OS-level now
; comes from there, resolved via add_ca65_app's -I include/ca65). Both
; conway_main.s and conway_grid.s .include this file directly, exactly
; like a C header shared between translation units.

; ---------------------------------------------------------------------------
; Grid dimensions
; ---------------------------------------------------------------------------
GRID_W    = 40
GRID_H    = 24
GRID_SIZE = 960
STATUS_ROW_OFFSET = 960
MENU_PROMPT_OFFSET = 23 * GRID_W
GEN_LABEL_OFFSET   = STATUS_ROW_OFFSET + 31
GEN_DIGITS_OFFSET  = STATUS_ROW_OFFSET + 35

; ---------------------------------------------------------------------------
; Hardware addresses
; ---------------------------------------------------------------------------
VIC_BORD  = $D020
VIC_BGND  = $D021
SCREEN    = $0400
COLORRAM  = $D800
JIFFY_CLK = $A2

; ---------------------------------------------------------------------------
; Display
; ---------------------------------------------------------------------------
CHAR_LIVE = $A0
CHAR_DEAD = $20
CLR_LIVE  = 5

; ---------------------------------------------------------------------------
; Timing
; ---------------------------------------------------------------------------
GEN_DELAY = 3

; ---------------------------------------------------------------------------
; UI state values
; ---------------------------------------------------------------------------
MENU_STATE_NORMAL   = 0
MENU_STATE_BIRTH    = 1
MENU_STATE_SURVIVAL = 2
PRESET_CUSTOM       = $FF
PRESET_COUNT        = 9
RULE_COUNT          = 9

; ---------------------------------------------------------------------------
; Zero-page scratch ($70-$82 -- app-private external-program area)
; ---------------------------------------------------------------------------
zpPrevLo = $70
zpPrevHi = $71
zpCurrLo = $72
zpCurrHi = $73
zpNextLo = $74
zpNextHi = $75
zpDstLo  = $76
zpDstHi  = $77
zpRow    = $78
zpCol    = $79
zpCount  = $7A
zpLfsr   = $7B
zpPaused = $7C
zpBufSel = $7D
zpInMenu = $7E
zpMenuState = $7F
zpPresetIdx = $80
zpGenLo = $81
zpGenHi = $82
