; src/external/pacman/pacman_main.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Pac64 — Pac-Man for Command 64 OS. Modular ca65 rewrite.

.include "command64.inc"
.include "common.inc"

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '1'
.include "build_pacman.inc"

.import __MAIN_START__
.import clearScreen
.import drawMaze

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"


; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------
start:
    ; Set border and background to black
    lda #COLOR_BLACK
    sta $D020
    sta $D021

    jsr clearScreen
    jsr drawMaze

    ; Clear and return to shell
    jsr exitToShell
    rts

; ---------------------------------------------------------------------------
; exitToShell -- Restore screen and return
; ---------------------------------------------------------------------------
exitToShell:
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
    rts

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

exitBanner:
    .byte "PACMAN v", VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE
    .byte ".", BUILD_NUMBER, PetCr, 0
