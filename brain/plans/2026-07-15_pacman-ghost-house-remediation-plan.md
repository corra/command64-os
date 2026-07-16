# Pac-Man Ghost House Remediation Implementation Plan

Date: 2026-07-15
Status: Proposed; Awaiting Implementation

## Objective

Implement a coherent, arcade-accurate ghost-house state machine while
preserving the rule that `updateGhosts` exclusively owns committed coordinate
movement.

## Design Decisions

- Ghost lifecycle modes remain `MODE_HOUSE`, `MODE_EXITING`, `MODE_EATEN`, and
  the active outside modes chase, scatter, and frightened.
- `ghostRow` and `ghostCol` are modified only by the common movement stage in
  `updateGhosts`, except initialization/reset code and temporary collision
  probes that restore the original value.
- Dot counters are updated when a dot or energizer is consumed, not when a
  ghost movement timer expires.
- The inactivity timer is non-blocking and advances once per gameplay jiffy.
- Global post-death thresholds use exact equality—7, 17, and 32—to reproduce
  arcade behavior.
- The scheduled outside mode is derived from `zpCycleStep`; house lifecycle
  modes must never be overwritten by the scheduler.

### Reviewed design decision: exit-into-frightened re-trigger (2026-07-15)

User-observed behavior during implementation testing: a ghost that exits the
house (either freshly released from `MODE_HOUSE`, or revived from
`MODE_EATEN` via `MODE_EXITING`) while `zpFrightenedTimer` is still active
becomes `MODE_FRIGHTENED` immediately upon crossing the door
(`handleHouseExit`'s `@atDoorCol` check, pacman_ai.s). This was flagged as
possibly unintended because it can visibly re-trigger frightened state on a
ghost that was already eaten once this same power-pellet window.

Investigated and confirmed: this is deliberate, per this plan's own Phase 2/3
spec ("EXITING: outside boundary + frightened active -> FRIGHTENED") and
matches documented real-arcade behavior — a ghost released or revived while
the fright timer is still live does turn blue again on exit; there is no
retrigger loop, it is a one-time transition per door crossing, and the
Phase-2-adjacent gate-check fix (`isTargetTileLegal`'s `@gateCheck`, only
`MODE_EATEN`/`MODE_EXITING` may cross the door) prevents an already-frightened
ghost from wandering back in to repeat it.

Decision: keep the current arcade-accurate behavior as implemented. Flagged
here as a reviewed design decision rather than a defect — revisit only if
future playtesting shows it materially hurts pacing/fairness.

## Phase 1: Establish State-Machine Invariants

Document the legal transitions before changing behavior:

```text
Reset:
  Blinky -> SCATTER
  Pinky  -> HOUSE
  Inky   -> HOUSE
  Clyde  -> HOUSE

HOUSE:
  release condition -> EXITING

EXITING:
  outside boundary + frightened active -> FRIGHTENED
  outside boundary + scatter phase     -> SCATTER
  outside boundary + chase phase       -> CHASE

SCATTER/CHASE:
  energizer -> FRIGHTENED

FRIGHTENED:
  timer expiry -> scheduled SCATTER/CHASE
  captured -> EATEN

EATEN:
  reaches revival position -> EXITING
```

An eaten ghost reaching the house should transition through controlled exit
routing rather than immediately becoming an outside targeting mode while still
inside.

Deliverables:

- Add the lifecycle table beside the ghost-mode definitions or AI dispatcher.
- Audit each `ghostMode` writer against the table.
- Document the exit boundary constants.

## Phase 2: Make House Movement Direction-Only

### `handleHouseBouncing`

Change the routine so it:

1. Loads `X` from `zpGhostIdx`.
2. Calls the release evaluator.
3. Reloads `X` after the call.
4. If released, stores `MODE_EXITING` and selects the direction needed to
   align with the door.
5. Otherwise applies these direction changes:

```text
Row 12 + DIR_UP   -> DIR_DOWN
Row 13 + DIR_DOWN -> DIR_UP
Any other combination -> no coordinate correction
```

It must not write `ghostRow` or `ghostCol`.

### `handleHouseExit`

Change the routine so it selects direction only:

```text
Col < 13 -> RIGHT
Col > 13 -> LEFT
Col = 13 and Row > 11 -> UP
Col = 13 and Row = 11 -> transition outside mode, then UP
```

The common movement stage performs the resulting one-cell move.

Implementation requirements:

- Transition at Row 11 before the common movement so the same tick moves the
  ghost to Row 10.
- Reload `X` after any subroutine that may clobber it.
- Avoid returning a meaningful carry unless explicitly documented.
- Do not snap unexpected positions to the expected exit path.

Acceptance checks:

- Every moving ghost changes Manhattan position by exactly one cell.
- Waiting ghosts alternate only between Rows 12 and 13.
- Exit alignment visits Column 13 rather than skipping across it.
- No ghost enters Row 11 except as part of the door route.

## Phase 3: Protect Lifecycle Modes from Scheduler Transitions

Modify `transitionGhostModes` so it skips:

- `MODE_HOUSE`
- `MODE_EXITING`
- `MODE_EATEN`
- `MODE_FRIGHTENED`

Only active chase/scatter ghosts should receive the new scheduled mode and
reverse direction.

Add a helper such as `getScheduledGhostMode`:

```text
zpCycleStep even -> MODE_SCATTER
zpCycleStep odd  -> MODE_CHASE
```

Use it when:

- An exiting ghost reaches the outside boundary.
- Frightened mode expires.
- A revived ghost becomes eligible to leave the house.

Do not store scheduled chase/scatter directly into a ghost that is still
inside.

Optional arcade-fidelity enhancement:

- Add a pending exit-direction/reversal bit if scatter/chase transitions while
  a ghost is inside must affect its first outside turn.
- Keep this bit independent from `ghostMode`.

Acceptance checks:

- A scheduler transition cannot make a house ghost bypass release checks.
- An exiting ghost completes the door path across scheduler transitions.
- Outside ghosts still reverse exactly once on scatter/chase transitions.
- Frightened, eaten, and house ghosts do not receive inappropriate reversals.

## Phase 4: Replace Derived Totals with Explicit Release Counters

### Required State

Prefer BSS unless profiling demonstrates a zero-page requirement:

```assembly
ghostPersonalDots: .res 4
activeDotOwner:    .res 1
globalReleaseDots: .res 1
releaseIdleLo:     .res 1
releaseIdleHi:     .res 1
```

`ghostPersonalDots + GHOST_BLINKY` may be omitted or reserved as zero. Do not
allocate additional zero-page bytes without verifying the `$70-$8F`
app-private contract.

### Personal Counter Initialization

On a new level:

- Clear all personal counters.
- Disable global release mode.
- Set active owner to Pinky.
- Reset the inactivity timer.

On life loss:

- Preserve personal counters.
- Enable global release mode.
- Clear `globalReleaseDots`.
- Reset the inactivity timer.
- Reset ghost positions and lifecycle modes.

### Counter Ownership

Only one personal counter may advance per consumed dot.

Priority:

1. Pinky, if still in `MODE_HOUSE`
2. Inky, if still in `MODE_HOUSE`
3. Clyde, if still in `MODE_HOUSE`
4. None

When the active owner begins exiting:

- Select the next preferred waiting ghost.
- Do not reset the released ghost's personal counter.
- Do not retroactively credit dots to the next ghost.

### Personal Limits

| Level | Pinky | Inky | Clyde |
|---|---:|---:|---:|
| 1 | 0 | 30 | 60 |
| 2 | 0 | 0 | 50 |
| 3+ | 0 | 0 | 0 |

Zero-limit ghosts should be processed deterministically at round start. They
may enter `MODE_EXITING` immediately, but physical exit routing remains
serialized by position and movement timers.

Acceptance checks:

- Level 1 Inky receives the first 30 applicable dots.
- Clyde begins at zero when Inky starts exiting.
- Clyde needs 60 subsequent dots, normally placing release around 90 total
  dots.
- A life loss does not erase personal-counter progress.

## Phase 5: Move Release Accounting into Item Consumption

Add a routine such as `recordReleaseDot`, called exactly once from the shared
dot/energizer consumption path:

```text
consume dot or energizer
  -> decrement remaining-dot count
  -> recordReleaseDot
  -> reset release inactivity timer
  -> process fruit/level-clear behavior
```

`recordReleaseDot` behavior:

```text
if post-death global mode:
    increment globalReleaseDots
    evaluate exact global release event
else:
    increment active owner's personal counter
    evaluate that owner's personal limit
```

Remove release dependence on polling:

```assembly
zpTotalDots - dotsRemainingLo
```

Polling couples release behavior to ghost movement frequency and cannot model
exclusive counter ownership.

Processor contract:

- Explicitly document clobbered registers and temporaries.
- Preserve `X` if the consuming routine relies on it.
- Set carry deliberately if release status is returned.
- Do not expose incidental carry from `INC`, `CMP`, or subtraction.

## Phase 6: Implement Exact Global Post-Death Behavior

When global mode is active:

- Increment `globalReleaseDots` once per consumed dot.
- At exactly 7, release Pinky if she is inside.
- At exactly 17, release Inky if he is inside.
- At exactly 32, release Clyde if he is inside and disable global mode.

For arcade-exact behavior:

- Do not release a ghost merely because the counter exceeds its threshold.
- Do not disable global mode at 32 if Clyde is not waiting inside.
- Preserve the known missed-threshold behavior.
- Forced release must not automatically disable global mode.

If robustness is preferred over arcade fidelity, use `>=`, document it as a
deliberate deviation, and update the review and verification accordingly. This
plan recommends exact behavior.

Acceptance checks:

- Values 6/7/8 distinguish Pinky's exact event.
- Values 16/17/18 distinguish Inky's exact event.
- Values 31/32/33 distinguish Clyde's exact event.
- Global mode disables only under the selected Clyde-at-32 condition.

## Phase 7: Add the Non-Blocking Inactivity Timer

Use a 16-bit countdown or elapsed-jiffy counter.

Limits:

- Levels 1-4: approximately 240 jiffies
- Levels 5+: approximately 180 jiffies

Update it once per elapsed gameplay jiffy, not once per ghost movement.

Reset it when:

- A dot is consumed.
- An energizer is consumed.
- A ghost is forced to exit.
- A round or life begins.

Pause it during:

- READY banner
- Pause state
- Ghost-eaten freeze
- Death animation
- Level-clear handling

On expiry:

1. Select the highest-priority ghost still in `MODE_HOUSE`.
2. Change it to `MODE_EXITING`.
3. Reset the inactivity timer.
4. Preserve personal and global counter values.
5. Leave the global-mode enable flag unchanged.

Acceptance checks:

- With no dots consumed, the preferred ghost exits after the configured delay.
- Regular dot consumption continually postpones forced release.
- Pause/freeze time does not consume the timer.
- Forced release does not corrupt counter ownership.

## Phase 8: Correct Eaten-Ghost Revival Routing

Audit the revival logic in `updateGhosts`. The current behavior changes an
eaten ghost directly to scatter/chase when it reaches the interior revival
tile. That can leave a normal ghost inside the house without controlled exit
routing.

Remediation:

- At the revival tile, transition `MODE_EATEN` to `MODE_EXITING`.
- Select the appropriate initial exit direction.
- Let `handleHouseExit` route the ghost through Column 13 and the door.
- At Row 11, select frightened or scheduled outside mode.
- Revived ghosts should leave without waiting for personal limits.

Acceptance checks:

- Eaten eyes reach the revival tile.
- The revived ghost does not begin ordinary chase/scatter navigation inside.
- It leaves through the controlled exit path.
- Revival does not consume or reactivate a personal release counter.

## Phase 9: Add Invariant-Oriented Diagnostics

During development, expose or log:

- Ghost index
- Mode
- Row and column
- Direction
- Active personal-counter owner
- Personal counter values
- Global counter and enable flag
- Inactivity timer

Useful invariants:

```text
MODE_HOUSE:
  row must be 12 or 13

MODE_EXITING:
  position must be inside the known alignment/door route

Outside SCATTER/CHASE/FRIGHTENED:
  position must not be in the house interior

Per movement tick:
  abs(deltaRow) + abs(deltaCol) <= 1
```

Diagnostics should be removable or compile-time gated and must not alter jiffy
timing.

## Phase 10: Documentation and Task Synchronization

Once implementation is authorized:

- Create or update measurable task records in `wiki/tasks/*.md`.
- Synchronize corresponding Task Warrior entries.
- Update `CHANGELOG.md`.
- Record the state-machine and counter contracts in the nearest durable Pac-Man
  documentation.
- Update `brain/KNOWLEDGE.md` and `brain/MEMORY.md` as required by project
  workflow and memory-map changes.
- Perform the DOX closeout pass.
- Do not mark tasks done until the user completes runtime verification and
  confirms acceptance.

## Verification Matrix

| Scenario | Expected Result |
|---|---|
| New Level 1 | Pinky exits immediately |
| First 30 eligible dots | Inky exits |
| Next 60 eligible dots | Clyde exits |
| Level 2 | Pinky/Inky immediate; Clyde limit 50 |
| Level 3+ | All personal limits zero |
| No dots eaten | Preferred ghost forced out after timeout |
| Life lost | Personal counters preserved; global counter starts at zero |
| Global count 7 | Pinky exact release event |
| Global count 17 | Inky exact release event |
| Global count 32 with Clyde inside | Clyde exits; global mode disables |
| Global count 32 with Clyde outside | Exact arcade edge behavior retained |
| Scheduler transition while waiting | House lifecycle mode preserved |
| Scheduler transition while exiting | Door routing preserved |
| Energizer during exit | Exit completes, then frightened behavior applies |
| Eaten ghost returns | Revives and exits through controlled route |
| Jiffy low-byte rollover | READY/flash delays complete correctly |

## Execution Order and Atomic Increments

Implement in these reviewable increments:

1. Direction-only bounce and exit movement.
2. Scheduler protection for lifecycle modes.
3. Revival through `MODE_EXITING`.
4. Explicit personal counters and ownership.
5. Dot-consumption counter updates.
6. Exact global post-death counter.
7. Non-blocking inactivity timer.
8. Diagnostics and invariant audit.
9. Build verification.
10. User-run VICE walkthrough and acceptance.

Each increment must build cleanly before the next begins. Runtime-sensitive
increments remain incomplete until user confirmation.

## Completion Criteria

- Each ghost moves at most one cell per movement tick.
- House bouncing remains within Rows 12-13.
- Exiting ghosts reach Column 13 without overshoot and pass through the door.
- Scheduler transitions never destroy lifecycle modes.
- Personal counters have exclusive ownership and persist across a life loss.
- Global counter semantics match the documented arcade-exact policy.
- The inactivity timer forces the correct waiting ghost out.
- Revived ghosts leave through controlled exit routing.
- `delayA` remains rollover-safe for all callers below 256 jiffies.
- The Pac-Man target builds without warnings or errors.
- The user completes the runtime verification walkthrough and confirms the
  observed behavior.
