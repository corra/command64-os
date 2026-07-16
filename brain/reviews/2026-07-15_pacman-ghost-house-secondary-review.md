# Pac-Man Ghost House Secondary Code Review

Date: 2026-07-15
Status: Secondary Review Completed; Integrated Audit Record

## Purpose & Scope

This document represents the secondary code correctness and architectural analysis of the uncommitted ghost house bouncing, release, and scheduler mechanics in the Pac-Man external app. It explicitly integrates, verifies, and expands upon the primary review findings documented in:
* [2026-07-15_pacman-ghost-house-review.md](file:///home/morgan/development/c64/command64-os/brain/reviews/2026-07-15_pacman-ghost-house-review.md)

---

## 1. Synthesis of Primary Review Findings

A rigorous technical validation of the primary findings has been conducted. The secondary review confirms the correctness and severity of the following issues:

* **Finding 1: Bouncing Coordinate Drift & Ceiling Lock (High Severity)**
  * *Verification*: Confirmed. By setting `ghostRow, x` directly inside `handleHouseBouncing` (which is part of the AI tick) AND subsequently executing the common movement stage in `updateGhosts`, ghosts bounce between Row 14 and Row 11, eventually getting trapped inside the ceiling walls (Row 11) indefinitely.
* **Finding 2: Exit Double-Movement & Door-Column Overshoot (High Severity)**
  * *Verification*: Confirmed. Manual coordinate decrement/increment in `handleHouseExit` combined with `updateGhosts` physics updates causes ghosts to move at double speed. If a ghost ever starts at distance 1 from `Col 13` (e.g. `Col 12`), it will oscillate infinitely between `Col 12` and `Col 14`, never exiting.
* **Finding 3: Scatter/Chase Scheduler Corrupts House States (High Severity)**
  * *Verification*: Confirmed. `transitionGhostModes` in `pacman_ai.s` overwrites the ghost modes of those inside the house (`MODE_HOUSE` and `MODE_EXITING`) with `MODE_SCATTER` or `MODE_CHASE` when a cycle phase occurs. This breaks their release loop and causes pathfinding errors inside the house.
* **Finding 4: Improper Personal Dot Counter Representation (High Severity)**
  * *Verification*: Confirmed. The code subtracts `dotsRemainingLo` from `zpTotalDots` for all ghosts. This models a single global counter instead of individual counters (where Clyde's counter should activate only after Inky's release).
* **Finding 5: Global Counter Comparison Semantics (Medium Severity)**
  * *Verification*: Confirmed. The global counter uses `>=` thresholds instead of exact equality checks (`== 7`, `== 17`, `== 32`). While more robust against missed ticks, it deviates from the original arcade timing logic.
* **Finding 6: Absence of Inactivity Release Timer (Medium Severity)**
  * *Verification*: Confirmed. There is no fallback timer to release ghosts if the player stops consuming dots, allowing players to trap ghosts inside the house.
* **Finding 7: `delayA` Jiffy Rollover Safety (Pass)**
  * *Verification*: Confirmed. Unsigned subtraction `current - start` correctly maps elapsed time up to 256 ticks.

---

## 2. New Secondary Findings & Enhancements

In addition to validating the primary findings, this secondary audit has uncovered two new structural issues:

### 1. The Open-Gate Frightened Bug (Medium-High Severity)

In the uncommitted logic, `isTargetTileLegal`'s gate check allows all ghosts through:

```assembly
@gateCheck:
    ; Ghosts are allowed to pass through the door gate
    sec
    rts
```

* **Impact**: Frightened ghosts (`MODE_FRIGHTENED`), which move randomly via the LFSR, can randomly pass back down through the gate and re-enter the house during gameplay.
* **Remediation**: Constraint the gate check to only allow `MODE_EATEN` or `MODE_EXITING` ghosts to pass:

```assembly
@gateCheck:
    lda ghostMode, x
    cmp #MODE_EATEN
    beq @gateLegal
    cmp #MODE_EXITING
    beq @gateLegal
    clc ; Treat as wall for chase/scatter/frightened ghosts
    rts
@gateLegal:
    sec
    rts
```

### 2. ca65 Compatibility & Label Hygiene (Low Severity)

* **Audit**: The proposed refactoring in the primary review utilized anonymous labels (`:+`, `:-`). 
* **Enhancement**: To prevent potential local scope collisions and compiler syntax variance, the refactoring should use explicit, unique local labels (e.g. `@check13`, `@doneBounce`) to maintain high quality and portability.
* **Timer Check Correctness**: The 16-bit timer checks for `zpFrightenedTimer` in the exit path (`lda zpFrightenedTimer; ora zpFrightenedTimer+1; beq @setScatter`) are confirmed as cycle-efficient and mathematically correct for 6502.

### 3. Eaten-to-Revived Handshake Integrity

An audit of the revival sequence reveals that when an eaten ghost (`MODE_EATEN`) targets `Row 12, Col 13` and is revived:
1. It is placed in `MODE_HOUSE` at `Row 12, Col 13` moving `DIR_DOWN`.
2. On its next update tick, `handleHouseBouncing` sees `Row == 12` and `DIR_DOWN`. Since the proposed bouncing refactoring only flips `DIR_UP` to `DIR_DOWN`, the ghost's `DIR_DOWN` direction remains unchanged.
3. The ghost moves down to `Row 13` naturally, correctly initiating the bounce cycle. The transition is verified as seamless.

---

## 3. Consolidated Recommendations & Refactoring Blueprint

To remediate all findings from both reviews, implement the following changes in `src/external/pacman/pacman_ai.s`:

### 1. Direction-Only Bouncing (`handleHouseBouncing`)

```assembly
handleHouseBouncing:
    ldx zpGhostIdx
    jsr checkGhostRelease
    bcc @continueBounce
    
    ; Release the ghost!
    lda #MODE_EXITING
    sta ghostMode, x
    rts
    
@continueBounce:
    lda ghostRow, x
    cmp #12
    bne @check13
    
    ; Row is 12: if moving UP, reverse to DOWN
    lda ghostDir, x
    cmp #DIR_UP
    bne @doneBounce
    lda #DIR_DOWN
    sta ghostDir, x
@doneBounce:
    rts
    
@check13:
    cmp #13
    bne @doneBounce
    ; Row is 13: if moving DOWN, reverse to UP
    lda ghostDir, x
    cmp #DIR_DOWN
    bne @doneBounce
    lda #DIR_UP
    sta ghostDir, x
    rts
```

### 2. Direction-Only Exiting (`handleHouseExit`)

```assembly
handleHouseExit:
    ldx zpGhostIdx
    lda ghostCol, x
    cmp #13
    beq @goUp
    bcc @goRight
    
    ; Col > 13: face Left (let updateGhosts move it)
    lda #DIR_LEFT
    sta ghostDir, x
    rts
    
@goRight:
    ; Col < 13: face Right (let updateGhosts move it)
    lda #DIR_RIGHT
    sta ghostDir, x
    rts
    
@goUp:
    ; Col == 13: face Up (let updateGhosts move it)
    lda #DIR_UP
    sta ghostDir, x
    
    ; Transition when the ghost is at Row 11 (the gate), 
    ; because moving UP from Row 11 will place it at Row 10 (exited).
    lda ghostRow, x
    cmp #11
    bne @exitDone
    
    ; Exited! SCATTER or FRIGHTENED if active
    lda zpFrightenedTimer
    ora zpFrightenedTimer+1
    beq @setScatter
    lda #MODE_FRIGHTENED
    sta ghostMode, x
    rts
@setScatter:
    lda #MODE_SCATTER
    sta ghostMode, x
@exitDone:
    rts
```

### 3. Strict Gate Check (`isTargetTileLegal`)

```assembly
isTargetTileLegal:
    ; ... (bounds check and getWallCell checks) ...
    cmp #10
    beq @gateCheck
    ; ...
@gateCheck:
    ; Only allow exiting or eaten ghosts to pass
    lda ghostMode, x
    cmp #MODE_EATEN
    beq @gateLegal
    cmp #MODE_EXITING
    beq @gateLegal
    clc
    rts
@gateLegal:
    sec
    rts
```

### 4. Scheduler Isolation (`transitionGhostModes`)

Modify `transitionGhostModes` in `pacman_ai.s` to skip ghosts in `MODE_HOUSE` or `MODE_EXITING`:

```assembly
transitionGhostModes:
    ; ...
    lda ghostMode, x
    cmp #MODE_EATEN
    beq @skip
    cmp #MODE_HOUSE
    beq @skip
    cmp #MODE_EXITING
    beq @skip
    ; ...
```
