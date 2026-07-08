; spike/ca65-conway/common.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Shared constants/equates for the ca65 port of the Conway spike.
; ca65 has no import/export machinery for plain equates -- both
; conway_main.s and conway_grid.s just .include this file, exactly like
; a C header shared between translation units.

; ---------------------------------------------------------------------------
; OS entry points this app relies on (see include/command64.inc)
; ---------------------------------------------------------------------------
KernalGetIn = $FFE4             ; raw keyboard input (bypasses screen editor)

; ---------------------------------------------------------------------------
; Grid dimensions
; ---------------------------------------------------------------------------
GRID_W    = 40
GRID_H    = 24
GRID_SIZE = 960
STATUS_ROW_OFFSET = 960

; ---------------------------------------------------------------------------
; Hardware addresses
; ---------------------------------------------------------------------------
VIC_BORD  = $D020
VIC_BGND  = $D021
SCREEN    = $0400
COLORRAM  = $D800
JIFFY_CLK = $A2

; ---------------------------------------------------------------------------
; Buffer base addresses (page-aligned; low byte always $00)
; ---------------------------------------------------------------------------
GRID0_LO  = $00
GRID0_HI  = $30
GRID1_LO  = $00
GRID1_HI  = $34

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
; Zero-page scratch ($70-$7D -- documented safe area for external programs)
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
