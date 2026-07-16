# Pac-Man Ghost House Bouncing & Release Code Review

Date: 2026-07-15
Status: Review Updated; Corrective Implementation Required

## Scope

Review the uncommitted changes in `src/external/pacman/pacman_ai.s` and
`src/external/pacman/pacman_main.s` targeting:

1. Ghost-house bouncing (`handleHouseBouncing`)
2. Ghost-house exiting (`handleHouseExit`)
3. Release logic (`checkGhostRelease`, personal/global dot counters, and the
   forced-release timer)
4. Scatter/chase transitions while ghosts are inside or exiting the house
5. Timing utility (`delayA`)

The arcade behavior references in this review use *The Pac-Man Dossier*:
<https://pacman.holenet.info/>.

## Executive Summary

The changes establish useful house and exiting modes, but they do not yet
provide a correct or arcade-accurate ghost-house state machine. Six findings
require attention:

1. **High — Bouncing coordinate drift and ceiling lock.**
   `handleHouseBouncing` changes a coordinate before `updateGhosts` moves the
   ghost again, eventually pinning a waiting ghost at Row 11.
2. **High — Exit double movement and target overshoot.**
   `handleHouseExit` changes coordinates before the common movement stage,
   producing two-cell steps and oscillation around the door column.
3. **High — Scheduler corruption of house states.**
   `transitionGhostModes` converts `MODE_HOUSE` and `MODE_EXITING` ghosts to
   scatter/chase, bypassing their house routing and release checks.
4. **High — Personal dot counters are modeled as one level-total count.**
   Clyde leaves at 60 total dots on Level 1 rather than after his own 60-dot
   counter becomes active following Inky's release (normally about 90 total
   dots under continuous dot consumption).
5. **Medium — Global counter comparisons use greater-than-or-equal semantics.**
   The arcade global counter recognizes the exact values 7, 17, and 32. The
   current `CMP`/carry return recognizes any value at or above each threshold.
6. **Medium — The inactivity forced-release timer is absent.**
   No timer releases the preferred waiting ghost after Pac-Man stops eating
   dots, so ghosts can remain inside indefinitely.

The rollover-safe `delayA` change passes review for its current delays below
256 jiffies. A direction-only movement refactor is necessary, but it is not
sufficient by itself: house modes, personal counters, the global counter, and
the inactivity timer must be corrected as one coherent state machine.

## Architecture and Execution Path

`updateGhosts` owns coordinate movement:

1. Decrement the selected ghost's movement timer.
2. Reload its speed when the timer expires.
3. Erase its current cell.
4. Call `updateGhostAI` to select state and direction.
5. Move exactly one row or column according to `ghostDir`.
6. Apply tunnel wrapping and revival transitions.
7. Draw the ghost.

Therefore, routines reached through `updateGhostAI` must not commit a second
movement unless they also provide an explicit contract that causes the common
movement stage to be skipped. The current code has no such skip result.

## Detailed Findings

### 1. Bouncing Coordinate Drift and Ceiling Lock — High

`handleHouseBouncing` writes both `ghostRow` and `ghostDir`:

```assembly
@continueBounce:
    lda ghostRow, x
    cmp #12
    bne :+

    lda #13
    sta ghostRow, x
    lda #DIR_DOWN
    sta ghostDir, x
    rts

:   lda #12
    sta ghostRow, x
    lda #DIR_UP
    sta ghostDir, x
    rts
```

After `updateGhostAI` returns, `updateGhosts` unconditionally applies another
movement from `ghostDir`:

```assembly
    jsr updateGhostAI

    ldx zpGhostIdx
    lda ghostDir, x
    cmp #DIR_UP
    bne :+
    dec ghostRow, x
```

#### Execution trace

Starting with Clyde at Row 12, `DIR_UP`, `MODE_HOUSE`:

1. The house handler changes Row 12 to Row 13 and selects down.
2. The common movement stage increments Row 13 to Row 14.
3. On the next movement tick, the handler treats every row other than 12 as
   the lower endpoint, forces Row 12, and selects up.
4. The common movement stage decrements Row 12 to Row 11.
5. Each later house tick repeats the Row 12 assignment followed by the move to
   Row 11, leaving the ghost locked in the house ceiling.

This behavior also skips proper presentation restoration because the erased
cell and final actor cell no longer describe a one-tile movement.

#### Remediation plan

Make `handleHouseBouncing` direction-only:

- At Row 12, reverse only `DIR_UP` to `DIR_DOWN`.
- At Row 13, reverse only `DIR_DOWN` to `DIR_UP`.
- Do not write `ghostRow` or `ghostCol`.
- Leave an unexpected row/direction combination unchanged rather than snapping
  it to a coordinate; an invariant failure should remain observable.
- Preserve `zpGhostIdx`. Reload `X` from `zpGhostIdx` after
  `checkGhostRelease`, because the callee contract should not be inferred to
  preserve `X`.
- Return no movement result through carry; `checkGhostRelease` owns carry only
  until the caller consumes it.

Expected sequence after remediation:

```text
Row 12, Up -> select Down -> common movement -> Row 13
Row 13, Down -> select Up -> common movement -> Row 12
```

### 2. Exit Double Movement and Door-Column Overshoot — High

`handleHouseExit` changes `ghostCol` or `ghostRow`, then `updateGhosts` changes
the same coordinate again from the selected direction. Every exit step is
therefore two cells.

For a ghost at Column 12:

1. `handleHouseExit` increments Column 12 to 13 and selects right.
2. `updateGhosts` increments Column 13 to 14.
3. The following tick decrements 14 to 13 in the handler and 13 to 12 in the
   movement stage.
4. The ghost oscillates between Columns 12 and 14 and never observes Column 13
   at handler entry.

The current Level 1 spawn columns happen to be two cells from Column 13 for
Inky and Clyde, which masks this defect for those initial alignments.

#### Remediation plan

Make `handleHouseExit` direction-only:

- Column below 13: select `DIR_RIGHT`.
- Column above 13: select `DIR_LEFT`.
- Column equal to 13: select `DIR_UP`.
- Do not write `ghostRow` or `ghostCol`.
- When the ghost enters the handler at Row 11, Column 13, transition it to its
  active outside mode before returning. The common movement stage then moves
  it up to Row 10 on that tick.
- If frightened time is active at exit, select `MODE_FRIGHTENED`; otherwise use
  the currently scheduled scatter/chase phase rather than assuming the state
  from a stale house mode.

The implementation must document whether Row 11 is the door/gate cell and Row
10 is the first outside cell. If maze topology changes, these state-machine
constants must be updated with it.

### 3. Scatter/Chase Scheduler Corrupts House States — High

`transitionGhostModes` currently skips only `MODE_EATEN` and
`MODE_FRIGHTENED`. It overwrites every other ghost with the new scatter/chase
mode and reverses its direction. This includes `MODE_HOUSE` and
`MODE_EXITING`.

Once overwritten, `updateGhostAI` no longer dispatches to
`handleHouseBouncing` or `handleHouseExit`. A waiting ghost can leave the house
without satisfying a release rule, route into a wall, or lose its exit path.
The direction-only refactor proposed for Findings 1 and 2 does not correct this
independent failure.

#### Remediation plan

Separate **location/lifecycle state** from **outside targeting phase**:

- Preserve `MODE_HOUSE`, `MODE_EXITING`, and `MODE_EATEN` during ordinary
  scatter/chase transitions.
- Keep `zpCycleStep` as the authoritative scheduled outside phase. On exit,
  derive `MODE_SCATTER` or `MODE_CHASE` from `zpCycleStep` unless frightened
  mode is active.
- Decide explicitly how arcade-compatible mode reversals while inside the
  house are represented. If they affect exit direction, store a separate
  pending reversal/exit-side bit; do not encode that fact by destroying the
  lifecycle mode.
- `transitionGhostModes` should reverse only active outside ghosts. It must not
  reverse `MODE_HOUSE`, `MODE_EXITING`, `MODE_EATEN`, or an actively
  frightened ghost.
- `endFrightenedMode` should continue to transition only ghosts actually in
  `MODE_FRIGHTENED`.

Minimum safe patch: add explicit skips for `MODE_HOUSE` and `MODE_EXITING`.
Arcade-compatible patch: add independent lifecycle and scheduled-mode state so
mode changes inside the house can influence exit behavior without disabling
house routing.

### 4. Personal Dot Counters Are Not Personal — High

The individual release path computes:

```assembly
    lda zpTotalDots
    sec
    sbc dotsRemainingLo
    sta zpTmpVal
```

Every waiting ghost compares the same level-total value against its nominal
limit. This is not the arcade counter model. Only one personal ghost counter is
active at a time, in Pinky, Inky, Clyde priority order:

- Pinky's limit is zero, so she begins exiting immediately.
- Inky's counter becomes active after Pinky begins exiting.
- Clyde's counter becomes active after Inky begins exiting.

On Level 1, Inky requires 30 dots on his counter and Clyde subsequently
requires 60 on his own counter. With uninterrupted dot collection and no
forced release, this normally places Clyde's release around 90 total dots, not
60. The existing subtraction releases Clyde 30 dots early.

#### Remediation plan

Implement explicit counter ownership and persistent personal counts:

- Add one byte for each personal counter that must survive exits and returns,
  or add counters only for Inky and Clyde if Pinky's zero limit is represented
  directly.
- Add an active-counter owner or determine the preferred waiting ghost in
  Pinky/Inky/Clyde order whenever a dot is consumed.
- Increment exactly one personal counter per dot while global mode is
  inactive.
- Compare the active ghost's counter against its level-specific limit.
- When it reaches the limit, put that ghost into `MODE_EXITING` and transfer
  ownership to the next waiting ghost. Do not reset the released ghost's
  personal counter during the level.
- Reset personal counters only at the start of a new level. A life loss enables
  the global counter instead of resetting the personal counters.
- Keep dot-consumption updates in or immediately below `consumeItem`/`decDots`;
  polling `dotsRemainingLo` from each ghost movement tick cannot faithfully
  represent counter ownership.

Suggested data contract:

```text
ghostPersonalDots[4]  persistent for current level
activeDotOwner        Pinky, Inky, Clyde, or NONE
globalReleaseDots     reset after life loss
releaseIdleTimer      reset whenever Pac-Man consumes a dot
```

If zero-page space is insufficient, these values are not movement hot-path
scratch and may live in BSS. Any new zero-page allocation must remain within
the Pac-Man `$70-$8F` contract and be checked for collisions in `common.inc`.

### 5. Global Release Counter Uses the Wrong Comparison Semantics — Medium

The post-death path subtracts the current remaining-dot count from a spawn
snapshot and returns the carry from `CMP #7`, `CMP #17`, or `CMP #32`. This is
greater-than-or-equal behavior.

Arcade behavior recognizes the exact global-counter values:

- Pinky at exactly 7
- Inky at exactly 17
- Clyde at exactly 32
- Global mode is disabled only when Clyde is inside and released at 32

The exact-value behavior creates a known original-game edge case if Clyde is
outside when the counter reaches 32. Whether to reproduce that quirk is a
product decision, but the current code must not be described as exact arcade
behavior while it uses threshold semantics.

#### Remediation plan

Choose and document one of these policies:

1. **Arcade-exact:** Maintain an incrementing `globalReleaseDots` byte and use
   equality branches. Disable global mode only when Clyde is waiting inside at
   exactly 32 and is sent to exit.
2. **Intentional robustness:** Use `>=` comparisons to prevent missed releases,
   document the deviation, and test values beyond all thresholds.

For arcade-exact behavior, avoid deriving the count by subtraction during each
ghost tick. Increment the global counter exactly once in the dot-consumption
path. This also avoids coupling release behavior to movement speeds or polling
order.

Carry discipline for a comparison helper must be explicit:

- `SEC` means release approved.
- `CLC` means remain in the house.
- Every return path must set carry deliberately; do not expose incidental carry
  from arithmetic unless the routine contract explicitly requires it.

### 6. Inactivity Forced-Release Timer Is Missing — Medium

The arcade release system also tracks time since the last dot was eaten. If the
timer expires, the preferred ghost still waiting in the house is forced to
exit. The initial limit is approximately four seconds and becomes three
seconds from Level 5 onward.

Without this control, a player who stops eating dots can hold Inky or Clyde in
the house indefinitely. Dot thresholds alone therefore do not implement the
core release mechanics.

#### Remediation plan

- Add a release inactivity timer advanced once per game jiffy while gameplay is
  active.
- Reset it whenever Pac-Man consumes a dot or power pellet.
- Pause it whenever the game simulation is paused or frozen, consistent with
  the chosen scheduler semantics.
- Use a four-second limit on Levels 1-4 and a three-second limit from Level 5.
- On expiry, select the highest-priority ghost still in `MODE_HOUSE`, change it
  to `MODE_EXITING`, and reset the timer.
- Ensure this forced exit does not incorrectly reset personal counters.
- Under post-death global mode, preserve the intended global-counter behavior
  if a forced exit occurs before count 32.

A 16-bit jiffy counter is preferable for 180/240-jiffy limits. Decrementing a
16-bit remaining count avoids wrap-sensitive absolute-time comparisons and
makes pause behavior explicit.

### 7. `delayA` Rollover Audit — Pass with Contract Constraint

`delayA` stores the starting low jiffy byte and loops until unsigned subtraction
reaches the requested duration:

```assembly
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
```

`SEC` before `SBC` correctly computes `current - start` modulo 256, so the
current 15- and 120-jiffy calls tolerate low-byte rollover. The routine is valid
only for requested waits below 256 jiffies and assumes the loop observes the
clock before a full 256-jiffy alias occurs.

Document these clobbers:

- Input: `A` = delay in jiffies
- Clobbers: `A`, processor flags, `zpTmpDistLo`, `zpTmpVal`
- Preserves: `X`, `Y`

Do not reuse `delayA` for the ghost inactivity timer; it busy-waits and would
halt gameplay.

## Consolidated Implementation Sequence

Implement the remediation in small, independently verifiable stages:

1. **Establish lifecycle invariants.**
   Document legal transitions among `MODE_HOUSE`, `MODE_EXITING`, active
   scatter/chase/frightened modes, and `MODE_EATEN`.
2. **Make house AI direction-only.**
   Remove coordinate writes from `handleHouseBouncing` and `handleHouseExit`.
3. **Protect lifecycle modes from the scheduler.**
   Prevent `transitionGhostModes` from overwriting house, exiting, and eaten
   states; derive the scheduled outside mode at exit.
4. **Move release accounting to dot consumption.**
   Add persistent personal/global counters and update exactly one applicable
   counter for each consumed dot or energizer.
5. **Implement inactivity release.**
   Add a non-blocking 16-bit jiffy timer and preferred-waiting-ghost selection.
6. **Define arcade fidelity policy.**
   Use equality for exact global behavior or explicitly document robust `>=`
   semantics as a deviation.
7. **Add diagnostic observability.**
   During development, make ghost mode, row, column, active counter owner, and
   counter values inspectable without altering release timing.

## Verification Plan

### Static and build verification

1. Run `python3 src/external/pacman/autotile.py --check` and confirm the
   generated maze table is current.
2. Run `cmake --build build --target pacman` and require zero assembler/linker
   warnings and errors.
3. Inspect the linked map for BSS and zero-page changes; confirm no overlap with
   the `$70-$8F` Pac-Man allocation contract.
4. Trace every `ghostMode` writer and verify it follows the lifecycle table.
5. Trace every `ghostRow`/`ghostCol` writer and confirm house AI no longer moves
   coordinates before the common movement stage.

### User-run C64/VICE verification

Runtime verification must be performed by the user because the project forbids
the broken `c64-testing` MCP and web emulators.

1. **Bounce stability:** Do not eat dots. Confirm Inky and Clyde alternate only
   between Rows 12 and 13 without entering Row 11 or Row 14.
2. **Pinky release:** Start Level 1 and confirm Pinky immediately aligns to
   Column 13 and exits through Rows 11 then 10 with one-cell steps.
3. **Level 1 personal counters:** Eat continuously. Confirm Inky releases after
   30 counted dots and Clyde after 60 additional counted dots, subject to no
   forced-release timeout.
4. **Level 2 limits:** Confirm Pinky and Inky release immediately and Clyde uses
   a 50-dot personal limit.
5. **Level 3+ limits:** Confirm all three house ghosts become eligible
   immediately but still route through the door without double movement.
6. **Mode transition in house:** Keep Clyde inside across a scatter/chase
   transition. Confirm he remains in house lifecycle state and later exits
   correctly.
7. **Frightened during exit:** Eat an energizer while a ghost is exiting.
   Confirm it completes door routing and enters the intended frightened state
   at the outside boundary.
8. **Post-death global counter:** Lose a life and verify releases at the chosen
   exact or robust policy for 7, 17, and 32.
9. **Forced release:** Stop eating dots and confirm the preferred waiting ghost
   exits after about four seconds on Levels 1-4 and three seconds from Level 5.
10. **Delay rollover:** Trigger READY or level flashing with `JIFFY_CLK` near
    `$FF`; confirm both delays finish with the expected duration.

## Completion Criteria

The corrective work is ready for user acceptance only when:

- Each ghost moves at most one cell per movement tick.
- House bouncing remains within Rows 12-13.
- Exiting ghosts reach Column 13 without overshoot and pass through the door.
- Scheduler transitions never destroy lifecycle modes.
- Personal counters have exclusive ownership and persist correctly across a
  life loss.
- Global counter semantics match the documented fidelity policy.
- The inactivity timer forces the correct waiting ghost out.
- `delayA` remains rollover-safe for all callers.
- The Pac-Man target builds without warnings or errors.
- The user completes the runtime verification walkthrough and confirms the
  observed behavior.
