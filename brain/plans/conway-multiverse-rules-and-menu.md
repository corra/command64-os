---
feature: conway-multiverse-rules-and-menu
created: 2026-07-08
status: planned
---

# Plan: Conway Multiverse Rules and Menu

This plan describes the technical architecture and detailed assembly implementation for adding a Main Menu, interactive rule customization (preset and custom), and a generation counter to the Conway cellular automaton application.

## Goal & Rationale
Currently, the `conway` utility starts the simulation immediately with hardcoded B3/S23 rules and does not display any information about the simulation progress (generations). 

Based on Cary Huang's (*carykh*) video, "The Conway Multiverse," we will generalize the rules of the Game of Life to support alternative 2D Life-like cellular automata. We will add a Main Menu allowing the user to select from 9 preset universes or dynamically configure custom Birth/Survival rules (0-8 neighbor counts), along with a 16-bit generation counter displayed at the bottom right.

---

## User Review Required

> [!IMPORTANT]
> **Open Question 1: Target Assembler / File Migration**
> The production version of Conway is currently compiled from Kick Assembler (`src/external/conway/conway.asm`). However, there is a planned migration to `ca65` (`spike/ca65-conway/`). 
> - **Option A (Recommended):** Migrate Conway to `ca65` as part of this change (moving it to `src/external/conway/` as `conway_main.s` and `conway_grid.s`), retire the Kick version, and implement these new features in the clean modular `ca65` codebase.
> - **Option B:** Implement the menu and counter directly in Kick Assembler (`src/external/conway/conway.asm`) and defer the ca65 migration to a later stage.
>
> *We will assume Option A for the rest of this plan, but can adjust if you prefer to retain the Kick version for now.*

---

## Detailed Technical Specification

### 1. Memory and Zero-Page Allocation

The app-private zero page region on Command 64 OS spans `$70-$8F` (32 bytes). Conway currently uses `$70-$7D` (14 bytes). We will allocate the next 5 bytes to manage our states:
*   `$7E`: `zpInMenu` (1 = in menu screen, 0 = simulation running)
*   `$7F`: `zpMenuState` (0 = normal menu, 1 = edit Birth rule, 2 = edit Survival rule)
*   `$80`: `zpPresetIdx` (0..8 for presets 1-9, or `$FF` for a Custom rule)
*   `$81-$82`: `zpGenLo`, `zpGenHi` (16-bit generation counter, resets to 0 at simulation start/randomize)

We will allocate the following variables in the program's data segment (`.data` / `.bss`):
*   `ruleBirth`: `9 bytes` (active birth counts; index is neighbor count 0-8, value is 1 if active, 0 if inactive)
*   `ruleSurvival`: `9 bytes` (active survival counts; format same as above)
*   `tempValLo`, `tempValHi`: `2 bytes` (scratch space for 16-bit math)
*   `digitBuf`: `5 bytes` (stores 5 BCD digits for the generation counter display)

---

### 2. Presets Database (18 bytes per preset)

The 9 connected universes from our research will be hardcoded in read-only memory:

```assembly
presetBirth:
    .byte 0,0,0,1,0,0,0,0,0     ; 1. Conway's Life (B3)
    .byte 0,0,0,1,0,0,0,0,0     ; 2. Ant Colony (B3)
    .byte 0,0,0,1,1,0,0,0,0     ; 3. World on Fire (B34)
    .byte 0,0,0,1,1,1,0,0,0     ; 4. Blinkers (B345)
    .byte 0,0,0,1,0,0,0,0,0     ; 5. Mazectric (B3)
    .byte 0,0,0,1,0,0,0,0,0     ; 6. Maze (B3)
    .byte 0,0,0,1,0,0,0,0,0     ; 7. Life no Death (B3)
    .byte 0,0,0,1,0,0,0,0,0     ; 8. Coral (B3)
    .byte 0,0,0,1,0,0,0,0,0     ; 9. Assimilation (B3)

presetSurvival:
    .byte 0,0,1,1,0,0,0,0,0     ; 1. Conway's Life (S23)
    .byte 0,0,1,1,1,0,0,0,0     ; 2. Ant Colony (S234)
    .byte 0,0,1,1,0,0,0,0,0     ; 3. World on Fire (S23)
    .byte 0,0,1,0,0,0,0,0,0     ; 4. Blinkers (S2)
    .byte 0,1,1,1,1,0,0,0,0     ; 5. Mazectric (S1234)
    .byte 0,1,1,1,1,1,0,0,0     ; 6. Maze (S12345)
    .byte 1,1,1,1,1,1,1,1,1     ; 7. Life no Death (S012345678)
    .byte 0,0,0,0,1,1,1,1,1     ; 8. Coral (S45678)
    .byte 0,0,0,0,1,1,1,1,0     ; 9. Assimilation (S4567)
```

To load a preset:
```assembly
loadPreset:
    ; presetIndex (0..8) in .A
    sta tempValLo
    asl                         ; A = index * 2
    asl                         ; A = index * 4
    asl                         ; A = index * 8
    clc
    adc tempValLo               ; A = index * 9
    tax                         ; X = source offset in preset tables
    ldy #0
lpLoop:
    lda presetBirth, x
    sta ruleBirth, y
    lda presetSurvival, x
    sta ruleSurvival, y
    inx
    iny
    cpy #9
    bne lpLoop
    rts
```

---

### 3. Neighbourhood Solver (RAM-table based)

Instead of the hardcoded B3/S23 checks in `computeNext`, we will perform lookups on the active RAM tables. This simplifies the 6502 assembly and makes it fully generic:

```assembly
    ; --- Apply dynamic Life-like rules ---
    ldy zpCol
    lda (zpCurrLo), y           ; current cell state (0 = dead, 1 = alive)
    beq cnDead

cnAlive:
    ldx zpCount                 ; Moore neighbor count (0..8)
    lda ruleSurvival, x         ; lookup survival active-flag
    beq cnKill                  ; if 0, cell dies
    lda #1                      ; else, survives
    sta (zpDstLo), y
    jmp cnNext

cnDead:
    ldx zpCount                 ; Moore neighbor count (0..8)
    lda ruleBirth, x            ; lookup birth active-flag
    beq cnKill                  ; if 0, remains dead
    lda #1                      ; else, is born
    sta (zpDstLo), y
    jmp cnNext

cnKill:
    lda #0
    sta (zpDstLo), y
```

---

### 4. Generation Counter Rendering

We will implement a 16-bit binary-to-decimal converter that runs once per generation and writes to the bottom status line:

```assembly
convertGenCounter:
    lda zpGenLo
    sta tempValLo
    lda zpGenHi
    sta tempValHi
    ldx #0
cgcDigitLoop:
    lda #0
    sta digitBuf, x
cgcSubLoop:
    sec
    lda tempValLo
    sbc power10Lo, x
    tay
    lda tempValHi
    sbc power10Hi, x
    bcc cgcNextDigit
    sta tempValHi
    sty tempValLo
    inc digitBuf, x
    jmp cgcSubLoop
cgcNextDigit:
    inx
    cpx #4
    bne cgcDigitLoop
    lda tempValLo
    sta digitBuf, x
    rts

power10Lo: .byte <10000, <1000, <100, <10
power10Hi: .byte >10000, >1000, >100, >10
```

To draw the generation counter during simulation (rendered at `SCREEN + STATUS_ROW_OFFSET + 34` to `+38`):
```assembly
drawGenCounter:
    jsr convertGenCounter
    ldx #0
dgcLoop:
    lda digitBuf, x
    clc
    adc #$30                    ; convert 0..9 to screen code '0'..'9'
    sta SCREEN + STATUS_ROW_OFFSET + 34, x
    inx
    cpx #5
    bne dgcLoop
    rts
```

---

### 5. Menu Screen Layout & Rendering

The menu screen will be defined as an array of 960 screen-code bytes (24 lines of 40 columns), utilizing screen code mixed mapping. On entry or return to menu, we perform a block copy of this array directly to screen RAM `$0400`–`$07BF`.

```
     conway's game of life multiverse   
     --------------------------------   
                                        
  select preset:                        
  > 1. conway's life (b3/s23)           
    2. ant colony    (b3/s234)          
    3. world on fire (b34/s23)          
    4. blinkers      (b345/s2)          
    5. mazectric     (b3/s1234)         
    6. maze          (b3/s12345)        
    7. life no death (b3/s0-8)          
    8. coral         (b3/s45678)        
    9. assimilation  (b3/s4567)         
                                        
  current rule:                         
  birth (b)    : 3                      
  survival (s) : 23                     
                                        
  controls:                             
    b [0-8]: toggle birth rule          
    s [0-8]: toggle survival rule       
    return : start simulation           
    r      : randomize & start          
q:exit to shell                         
```

#### Updating Menu Dynamics
Every time a key is pressed in the menu, `updateMenuDynamics` is called to:
1.  **Clear all selection arrows:** Overwrite column 2 on rows 4 to 12 with a space character.
2.  **Draw selection arrow:** If `zpPresetIdx` is between 0 and 8, write `>` (screencode `$3E`) at column 2 on row `4 + zpPresetIdx`.
3.  **Draw active Birth rule:** Write active indices in `ruleBirth` to row 15, starting at column 17. If no indices are active, write `none`.
4.  **Draw active Survival rule:** Write active indices in `ruleSurvival` to row 16, starting at column 17. If no indices are active, write `none`.

#### Overwriting Bottom Prompt Row
When `zpMenuState` changes to `1` (editing Birth) or `2` (editing Survival), we overwrite row 23 (offset 23 * 40) with the corresponding prompt string:
*   Normal: `q:exit to shell                         `
*   Birth: `press digit 0-8 to toggle birth rule    `
*   Survival: `press digit 0-8 to toggle survival rule `

---

### 6. Interactive Keyboard Polling State Machine

We will rewrite `handleKeys` to support state-based dispatching:

```
  [zpInMenu = 1]
    |-- [zpMenuState = 0] (Normal Menu)
    |     |-- '1'-'9': Set zpPresetIdx = key - '1', load preset, updateMenuDynamics
    |     |-- 'B': Set zpMenuState = 1, write Birth prompt row
    |     |-- 'S': Set zpMenuState = 2, write Survival prompt row
    |     |-- RETURN: Set zpInMenu = 0, reset genCounter, drawSimStatusLine, start sim
    |     |-- 'R': Randomize active grid, Set zpInMenu = 0, reset genCounter, drawSimStatusLine, start sim
    |     |-- 'Q' or RUN/STOP: Clear screen, RTS to shell
    |
    |-- [zpMenuState = 1] (Edit Birth Mode)
    |     |-- '0'-'8': Toggle ruleBirth[key - '0'], Set zpPresetIdx = $FF (Custom), 
    |     |            Set zpMenuState = 0, restore Normal prompt, updateMenuDynamics
    |     |-- Any other key: Set zpMenuState = 0, restore Normal prompt, updateMenuDynamics
    |
    |-- [zpMenuState = 2] (Edit Survival Mode)
          |-- '0'-'8': Toggle ruleSurvival[key - '0'], Set zpPresetIdx = $FF (Custom), 
          |            Set zpMenuState = 0, restore Normal prompt, updateMenuDynamics
          |-- Any other key: Set zpMenuState = 0, restore Normal prompt, updateMenuDynamics

  [zpInMenu = 0] (Simulation Running)
    |-- SPACE: Toggle zpPaused
    |-- 'R': Randomize active grid, reset genCounter, drawGenCounter, drawGrid
    |-- 'C': Clear active grid, reset genCounter, drawGenCounter, drawGrid, set zpPaused = $FF
    |-- 'Q': Set zpInMenu = 1, Set zpMenuState = 0, reset genCounter, drawMenu
    |-- RUN/STOP: Clear screen, RTS to shell
```

---

## Verification Plan

### Automated Tests
1.  Verify that all external apps build successfully:
    ```bash
    cmake -B build
    cmake --build build --target test_image_d64
    ```

### Manual Verification
1.  **Launch Conway:** `LOAD "CONWAY",8` then `RUN`.
2.  **Verify Menu Entry:** The screen must immediately draw the Conway Multiverse Menu. The cursor arrow `>` must point to Option 1, and the current rules displayed must be `birth (b) : 3` and `survival (s) : 23`.
3.  **Verify Preset Keys:** Press `2`. The arrow must move to Option 2, and the rules must change to Birth: `3`, Survival: `234`. Test options `3` through `9`.
4.  **Verify Custom Birth Editing:** Press `B`. The bottom row must display the prompt `press digit 0-8 to toggle birth rule`. Press `4`. The arrow next to the options must disappear, the Birth rule list must update to `34`, and the bottom prompt must restore to `q:exit to shell`.
5.  **Verify Custom Survival Editing:** Press `S`. Bottom row displays the survival prompt. Press `3`. The Survival rule list must update to `2` (since `3` was toggled off).
6.  **Verify Empty Rules Display:** Toggle off all birth digits. Verify the menu displays `none` for Birth.
7.  **Verify Randomize & Start:** Press `R` on the menu. The simulation must start immediately with a randomized grid.
8.  **Verify Generation Counter:** Verify that the bottom right display reads `gen:00000` and increments by 1 on each step.
9.  **Verify Pause/Resume:** Press `SPACE` to pause the simulation. Verify the counter halts. Press `SPACE` again to resume.
10. **Verify Clear:** Press `C` during simulation. The grid must clear, and the counter must reset to `00000`.
11. **Verify Return to Menu:** Press `Q` during simulation. The program must return to the Main Menu. The counter should be cleared and the menu drawn correctly.
12. **Verify Exit to Shell:** Press `Q` on the Main Menu. The utility must clear the screen and exit cleanly back to the `command64` shell prompt.
