; SRC/EXTERNAL/CONWAY/CONWAYGRID.S
; SPDX-LICENSE-IDENTIFIER: MIT
; COPYRIGHT (C) 2026 COMMAND64 PROJECT CONTRIBUTORS
;
; CONWAY'S GRID / DRAWING HALF. TEXTUALLY .INCLUDE'D BY CONWAY.S (LAST),
; SO EVERY LABEL LIVES IN ONE GLOBAL NAMESPACE -- THE CA65 .IMPORT /
; .EXPORT PAIRS ARE GONE. CONSTANTS (SCREEN, GRID_W, THE ZP BLOCK, ...)
; ARE DEFINED INLINE AT THE TOP OF CONWAY.S AND VISIBLE HERE BY TEXTUAL
; ORDER -- THEY MUST NOT BE RE-DECLARED OR MOVED INTO AN .INCLUDE (CASM
; 0.6.2 EMITS 3-BYTE ABSOLUTE FOR A ZP-VALUED CONSTANT READ FROM AN
; .INCLUDE'D FILE). SEE THE 2026-09-03 CONWAY CASM-NATIVE MIGRATION PLAN.
;
; SCREEN-CODE TEXT (STATUSTEXT) NOW LIVES IN THE GENERATED CONWAYMENU.S;
; STATUS_TEXT_LEN COMES FROM THERE TOO.

; ---------------------------------------------------------------------------
; RANDOMIZEGRID -- FILL THE ACTIVE BUFFER WITH ABOUT 25% LIVE CELLS.
; 8-BIT GALOIS LFSR (PERIOD 255, POLY X^8+X^6+X^5+X^4+1).
; ---------------------------------------------------------------------------
RANDOMIZEGRID:
    JSR GETCURRBASE
    STA ZPCURRLO
    STX ZPCURRHI

    LDX #0
    LDY #0
@CELL:
    JSR LFSRSTEP
    AND #$0A
    BEQ @ALIVE
    LDA #0
    JMP @STORE
@ALIVE:
    LDA #1
@STORE:
    STA (ZPCURRLO), Y
    INY
    BNE @CELL

    INC ZPCURRHI
    INX
    CPX #3
    BNE @CELL

    LDY #0
@TAIL:
    JSR LFSRSTEP
    AND #$0A
    BEQ @TAILALIVE
    LDA #0
    JMP @TAILSTORE
@TAILALIVE:
    LDA #1
@TAILSTORE:
    STA (ZPCURRLO), Y
    INY
    CPY #192
    BNE @TAIL
    RTS

; ---------------------------------------------------------------------------
; CLEARGRID -- SET EVERY CELL IN THE ACTIVE BUFFER TO DEAD (0).
; ---------------------------------------------------------------------------
CLEARGRID:
    JSR GETCURRBASE
    STA ZPCURRLO
    STX ZPCURRHI

    LDA #0
    LDX #0
    LDY #0
@PAGE:
    STA (ZPCURRLO), Y
    INY
    BNE @PAGE
    INC ZPCURRHI
    INX
    CPX #3
    BNE @PAGE
    LDY #0
@TAIL:
    STA (ZPCURRLO), Y
    INY
    CPY #192
    BNE @TAIL
    RTS

; ---------------------------------------------------------------------------
; CLEARSCREEN -- FILL SCREEN RAM ($0400) WITH SPACE CHARACTERS.
; ---------------------------------------------------------------------------
CLEARSCREEN:
    LDA #<SCREEN
    STA ZPDSTLO
    LDA #>SCREEN
    STA ZPDSTHI

    LDA #CHAR_DEAD
    LDX #0
    LDY #0
@PAGE:
    STA (ZPDSTLO), Y
    INY
    BNE @PAGE
    INC ZPDSTHI
    INX
    CPX #3
    BNE @PAGE
    LDY #0
@TAIL:
    STA (ZPDSTLO), Y
    INY
    CPY #232
    BNE @TAIL
    RTS

; ---------------------------------------------------------------------------
; DRAWGRID -- COPY ACTIVE BUFFER TO SCREEN RAM, CONVERTING 0/1 -> PETSCII.
; ---------------------------------------------------------------------------
DRAWGRID:
    JSR GETCURRBASE
    STA ZPCURRLO
    STX ZPCURRHI

    LDA #<SCREEN
    STA ZPDSTLO
    LDA #>SCREEN
    STA ZPDSTHI

    LDA #0
    STA DGPAGECNT
    LDY #0
@PAGE:
    LDA (ZPCURRLO), Y
    TAX
    LDA CELLCHARTBL, X
    STA (ZPDSTLO), Y
    INY
    BNE @PAGE

    INC ZPCURRHI
    INC ZPDSTHI
    INC DGPAGECNT
    LDA DGPAGECNT
    CMP #3
    BNE @PAGE

    LDY #0
@TAIL:
    LDA (ZPCURRLO), Y
    TAX
    LDA CELLCHARTBL, X
    STA (ZPDSTLO), Y
    INY
    CPY #192
    BNE @TAIL
    RTS

DGPAGECNT: .BYTE 0

; ---------------------------------------------------------------------------
; COMPUTENEXT -- EVALUATE ONE FULL GENERATION OF CONWAY'S B3/S23 RULES.
; ---------------------------------------------------------------------------
COMPUTENEXT:
    LDA #0
    STA ZPROW

@ROWLOOP:
    JSR SETTHREEROWPTRS
    JSR SETDSTROWPTR

    LDA #0
    STA ZPCOL

@COLLOOP:
    LDA ZPCOL
    BNE @NOTFIRSTCOL
    LDA #GRID_W - 1
    JMP @GOTLEFT
@NOTFIRSTCOL:
    SEC
    SBC #1
@GOTLEFT:
    TAY

    LDA #0
    STA ZPCOUNT

    LDA (ZPPREVLO), Y
    CLC
    ADC ZPCOUNT
    STA ZPCOUNT

    LDA (ZPCURRLO), Y
    CLC
    ADC ZPCOUNT
    STA ZPCOUNT

    LDA (ZPNEXTLO), Y
    CLC
    ADC ZPCOUNT
    STA ZPCOUNT

    LDY ZPCOL

    LDA (ZPPREVLO), Y
    CLC
    ADC ZPCOUNT
    STA ZPCOUNT

    LDA (ZPNEXTLO), Y
    CLC
    ADC ZPCOUNT
    STA ZPCOUNT

    LDA ZPCOL
    CMP #GRID_W - 1
    BNE @NOTLASTCOL
    LDA #0
    JMP @GOTRIGHT
@NOTLASTCOL:
    CLC
    ADC #1
@GOTRIGHT:
    TAY

    LDA (ZPPREVLO), Y
    CLC
    ADC ZPCOUNT
    STA ZPCOUNT

    LDA (ZPCURRLO), Y
    CLC
    ADC ZPCOUNT
    STA ZPCOUNT

    LDA (ZPNEXTLO), Y
    CLC
    ADC ZPCOUNT
    STA ZPCOUNT

    LDY ZPCOL
    LDA (ZPCURRLO), Y
    BEQ @DEAD

@ALIVE:
    LDX ZPCOUNT
    LDA RULESURVIVAL, X
    JMP @STORERULE

@DEAD:
    LDX ZPCOUNT
    LDA RULEBIRTH, X

@STORERULE:
    AND #1
    LDY ZPCOL
    STA (ZPDSTLO), Y

@NEXT:
    INC ZPCOL
    LDA ZPCOL
    CMP #GRID_W
    BEQ @COLDONE
    JMP @COLLOOP
@COLDONE:

    INC ZPROW
    LDA ZPROW
    CMP #GRID_H
    BEQ @ALLDONE
    JMP @ROWLOOP
@ALLDONE:
    RTS

; ---------------------------------------------------------------------------
; SETTHREEROWPTRS -- ZPPREV/CURR/NEXT LO/HI <- ROW (ZPROW-1, ZPROW, ZPROW+1)
; ADDRESSES IN THE ACTIVE BUFFER, WRAPPING TOROIDALLY.
; ---------------------------------------------------------------------------
SETTHREEROWPTRS:
    JSR GETCURRBASE
    STA STPBLO
    STX STPBHI

    LDY ZPROW
    CLC
    LDA STPBLO
    ADC ROWOFFLO, Y
    STA ZPCURRLO
    LDA STPBHI
    ADC ROWOFFHI, Y
    STA ZPCURRHI

    LDA ZPROW
    BEQ @PREVWRAP
    SEC
    SBC #1
    JMP @PREVGOT
@PREVWRAP:
    LDA #GRID_H - 1
@PREVGOT:
    TAY
    CLC
    LDA STPBLO
    ADC ROWOFFLO, Y
    STA ZPPREVLO
    LDA STPBHI
    ADC ROWOFFHI, Y
    STA ZPPREVHI

    LDA ZPROW
    CLC
    ADC #1
    CMP #GRID_H
    BNE @NEXTOK
    LDA #0
@NEXTOK:
    TAY
    CLC
    LDA STPBLO
    ADC ROWOFFLO, Y
    STA ZPNEXTLO
    LDA STPBHI
    ADC ROWOFFHI, Y
    STA ZPNEXTHI

    RTS

STPBLO: .BYTE 0
STPBHI: .BYTE 0

; ---------------------------------------------------------------------------
; SETDSTROWPTR -- ZPDSTLO/HI <- START OF ZPROW IN THE INACTIVE BUFFER.
; ---------------------------------------------------------------------------
SETDSTROWPTR:
    JSR GETNEXTBASE
    LDY ZPROW
    CLC
    ADC ROWOFFLO, Y
    STA ZPDSTLO
    TXA
    ADC ROWOFFHI, Y
    STA ZPDSTHI
    RTS

; ---------------------------------------------------------------------------
; GETCURRBASE / GETNEXTBASE -- RETURN BASE ADDRESS OF ACTIVE/INACTIVE BUFFER.
; RETURNS: A = LO BYTE, X = HI BYTE.
; ---------------------------------------------------------------------------
GETCURRBASE:
    LDA ZPBUFSEL
    BNE @USEG1
    LDA #<GRID0
    LDX #>GRID0
    RTS
@USEG1:
    LDA #<GRID1
    LDX #>GRID1
    RTS

GETNEXTBASE:
    LDA ZPBUFSEL
    BEQ @USEG1
    LDA #<GRID0
    LDX #>GRID0
    RTS
@USEG1:
    LDA #<GRID1
    LDX #>GRID1
    RTS

; ---------------------------------------------------------------------------
; LFSRSTEP -- ADVANCE THE 8-BIT GALOIS LFSR; NEW STATE LEFT IN A AND ZPLFSR.
; ---------------------------------------------------------------------------
LFSRSTEP:
    LDA ZPLFSR
    LSR A
    BCC @NFB
    EOR #$B8
@NFB:
    STA ZPLFSR
    RTS

; ---------------------------------------------------------------------------
; LOADPRESET -- EXPAND COMPACT 9-BIT B/S MASKS INTO HOT-PATH LOOKUP TABLES.
; INPUT:  A = PRESET INDEX (0..PRESET_COUNT-1)
; OUTPUT: C CLEAR ON SUCCESS; C SET IF A IS OUT OF RANGE.
; CLOBBERS: A, X, Y, N, Z. ON FAILURE, ACTIVE RULES AND ZPPRESETIDX ARE INTACT.
; ---------------------------------------------------------------------------
LOADPRESET:
    CMP #PRESET_COUNT
    BCS @INVALID
    PHA
    ASL A
    TAX

    LDA PRESETBIRTHMASKS, X
    STA RULEMASKSCRATCH
    LDY #0
@BIRTHLOOP:
    LSR RULEMASKSCRATCH
    LDA #0
    ROL A
    STA RULEBIRTH, Y
    INY
    CPY #8
    BNE @BIRTHLOOP
    LDA PRESETBIRTHMASKS + 1, X
    AND #1
    STA RULEBIRTH + 8

    LDA PRESETSURVIVALMASKS, X
    STA RULEMASKSCRATCH
    LDY #0
@SURVIVALLOOP:
    LSR RULEMASKSCRATCH
    LDA #0
    ROL A
    STA RULESURVIVAL, Y
    INY
    CPY #8
    BNE @SURVIVALLOOP
    LDA PRESETSURVIVALMASKS + 1, X
    AND #1
    STA RULESURVIVAL + 8

    PLA
    STA ZPPRESETIDX
    CLC
    RTS

@INVALID:
    SEC
    RTS

; ---------------------------------------------------------------------------
; TOGGLEBIRTH / TOGGLESURVIVAL -- TOGGLE ONE ACTIVE NEIGHBOUR COUNT.
; INPUT: X = NEIGHBOUR COUNT (0..8)
; OUTPUT: C CLEAR ON SUCCESS; C SET IF X IS OUT OF RANGE.
; PRESERVES: X, Y. CLOBBERS: A, N, Z. A VALID TOGGLE MARKS THE RULE CUSTOM.
; ---------------------------------------------------------------------------
TOGGLEBIRTH:
    CPX #RULE_COUNT
    BCS @INVALID
    LDA RULEBIRTH, X
    EOR #1
    STA RULEBIRTH, X
    LDA #PRESET_CUSTOM
    STA ZPPRESETIDX
    CLC
    RTS
@INVALID:
    SEC
    RTS

TOGGLESURVIVAL:
    CPX #RULE_COUNT
    BCS @INVALID
    LDA RULESURVIVAL, X
    EOR #1
    STA RULESURVIVAL, X
    LDA #PRESET_CUSTOM
    STA ZPPRESETIDX
    CLC
    RTS
@INVALID:
    SEC
    RTS

; ---------------------------------------------------------------------------
; GETBIRTHRULE / GETSURVIVALRULE -- READ ONE ACTIVE RULE-TABLE ENTRY.
; INPUT: X = NEIGHBOUR COUNT (0..8)
; OUTPUT: A = 0/1 AND C CLEAR; INVALID X RETURNS A=0 AND C SET.
; PRESERVES: X, Y.
; ---------------------------------------------------------------------------
GETBIRTHRULE:
    CPX #RULE_COUNT
    BCS @INVALID
    LDA RULEBIRTH, X
    CLC
    RTS
@INVALID:
    LDA #0
    SEC
    RTS

GETSURVIVALRULE:
    CPX #RULE_COUNT
    BCS @INVALID
    LDA RULESURVIVAL, X
    CLC
    RTS
@INVALID:
    LDA #0
    SEC
    RTS

; ---------------------------------------------------------------------------
; READ-ONLY DATA TABLES
; ---------------------------------------------------------------------------
CELLCHARTBL:
    .BYTE CHAR_DEAD
    .BYTE CHAR_LIVE

ROWOFFLO:
    .BYTE $00,$28,$50,$78,$A0,$C8,$F0
    .BYTE $18,$40,$68,$90,$B8,$E0
    .BYTE $08,$30,$58,$80,$A8,$D0,$F8
    .BYTE $20,$48,$70,$98

ROWOFFHI:
    .BYTE $00,$00,$00,$00,$00,$00,$00
    .BYTE $01,$01,$01,$01,$01,$01
    .BYTE $02,$02,$02,$02,$02,$02,$02
    .BYTE $03,$03,$03,$03

; ---------------------------------------------------------------------------
; DRAWSIMULATIONSTATUS -- WRITE THE EXACT 40-COLUMN SIMULATION STATUS ROW,
; THEN REPLACE THE TEMPLATE DIGITS WITH THE CURRENT GENERATION COUNT.
; STATUSTEXT / STATUS_TEXT_LEN COME FROM THE GENERATED CONWAYMENU.S (WAS A
; CA65 "SCREENCODE_MIXED" .CHARMAP BLOCK).
; CLOBBERS: A, X, Y, N, Z, C.
; ---------------------------------------------------------------------------
DRAWSIMULATIONSTATUS:
    LDX #0
@LOOP:
    LDA STATUSTEXT, X
    STA SCREEN + STATUS_ROW_OFFSET, X
    INX
    CPX #STATUS_TEXT_LEN
    BNE @LOOP
    JSR DRAWGENERATIONCOUNTER
    JMP DRAWPAUSECOLOR

; DRAW ONLY THE STATUS WORD "PAUSE" IN CYAN WHILE PAUSED, GREEN WHILE RUNNING.
; CLOBBERS: A, X, N, Z.
DRAWPAUSECOLOR:
    LDA #CLR_LIVE
    LDX ZPPAUSED
    BEQ @HAVECOLOR
    LDA #CLR_PAUSED
@HAVECOLOR:
    LDX #PAUSE_TEXT_LEN - 1
@LOOP:
    STA COLORRAM + PAUSE_TEXT_OFFSET, X
    DEX
    BPL @LOOP
    RTS

; ---------------------------------------------------------------------------
; DRAWGENERATIONCOUNTER -- CONVERT AND DRAW FIVE LEADING-ZERO DECIMAL DIGITS.
; CLOBBERS: A, X, Y, N, Z, C. THE LIVE 16-BIT COUNTER IS NOT MODIFIED.
; ---------------------------------------------------------------------------
DRAWGENERATIONCOUNTER:
    JSR CONVERTGENERATION
    LDX #0
@LOOP:
    LDA DIGITBUF, X
    CLC
    ADC #$30
    STA SCREEN + GEN_DIGITS_OFFSET, X
    INX
    CPX #5
    BNE @LOOP
    RTS

; ---------------------------------------------------------------------------
; CONVERTGENERATION -- CONVERT ZPGENHI:ZPGENLO TO FIVE NUMERIC DIGITS.
; USES HIGH-BYTE-FIRST COMPARISON AND PRESERVES THE LOW-BYTE SUBTRACTION
; BORROW INTO THE HIGH-BYTE SBC. CLOBBERS: A, Y, N, Z, C; PRESERVES X.
; ---------------------------------------------------------------------------
CONVERTGENERATION:
    LDA ZPGENLO
    STA TEMPVALLO
    LDA ZPGENHI
    STA TEMPVALHI
    LDY #0

@PLACELOOP:
    LDA #0
    STA DIGITBUF, Y

@SUBTRACTTEST:
    LDA TEMPVALHI
    CMP DECIMALDIVHI, Y
    BCC @PLACEDONE
    BNE @SUBTRACT
    LDA TEMPVALLO
    CMP DECIMALDIVLO, Y
    BCC @PLACEDONE

@SUBTRACT:
    LDA TEMPVALLO
    SEC
    SBC DECIMALDIVLO, Y
    STA TEMPVALLO
    LDA TEMPVALHI
    SBC DECIMALDIVHI, Y
    STA TEMPVALHI
    LDA DIGITBUF, Y
    CLC
    ADC #1
    STA DIGITBUF, Y
    JMP @SUBTRACTTEST

@PLACEDONE:
    INY
    CPY #4
    BNE @PLACELOOP
    LDA TEMPVALLO
    STA DIGITBUF + 4
    RTS

DECIMALDIVLO:
    .BYTE <10000, <1000, <100, <10
DECIMALDIVHI:
    .BYTE >10000, >1000, >100, >10

; COMPACT PRESET DATABASE: EACH ENTRY IS A LOW/HIGH PAIR FOR NEIGHBOUR
; COUNTS 0..7 AND COUNT 8 (HIGH BIT 0). LOADPRESET EXPANDS ONE PAIR INTO EACH
; PRIVATE 9-BYTE LOOKUP TABLE BEFORE PUBLISHING ZPPRESETIDX.
PRESETBIRTHMASKS:
    .BYTE $08,$00               ; 1. CONWAY'S LIFE: B3
    .BYTE $08,$00               ; 2. ANT COLONY: B3
    .BYTE $18,$00               ; 3. WORLD ON FIRE: B34
    .BYTE $38,$00               ; 4. BLINKERS: B345
    .BYTE $08,$00               ; 5. MAZECTRIC: B3
    .BYTE $08,$00               ; 6. MAZE: B3
    .BYTE $08,$00               ; 7. LIFE WITHOUT DEATH: B3
    .BYTE $08,$00               ; 8. CORAL: B3
    .BYTE $08,$00               ; 9. ASSIMILATION: B3

PRESETSURVIVALMASKS:
    .BYTE $0C,$00               ; 1. CONWAY'S LIFE: S23
    .BYTE $1C,$00               ; 2. ANT COLONY: S234
    .BYTE $0C,$00               ; 3. WORLD ON FIRE: S23
    .BYTE $04,$00               ; 4. BLINKERS: S2
    .BYTE $1E,$00               ; 5. MAZECTRIC: S1234
    .BYTE $3E,$00               ; 6. MAZE: S12345
    .BYTE $FF,$01               ; 7. LIFE WITHOUT DEATH: S012345678
    .BYTE $F0,$01               ; 8. CORAL: S45678
    .BYTE $F0,$00               ; 9. ASSIMILATION: S4567

; EMITTED MUTABLE STATE: IT MUST REMAIN INSIDE THE RELOCATABLE APP EXTENT.
RULEBIRTH:
    .RES 9, 0
RULESURVIVAL:
    .RES 9, 0
RULEMASKSCRATCH:
    .BYTE 0
TEMPVALLO:
    .BYTE 0
TEMPVALHI:
    .BYTE 0
DIGITBUF:
    .RES 5, 0

; ---------------------------------------------------------------------------
; RUNTIME BUFFERS (RELOCATABLE, PAGE-ALIGNED)
; ---------------------------------------------------------------------------
.ALIGN 256
GRID0:
    .RES 960, 0
.ALIGN 256
GRID1:
    .RES 960, 0
