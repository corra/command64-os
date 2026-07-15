# Pac-Man ca65 Rewrite

Status: [/]
Taskwarrior: project `command64.pacman`, parent task 27; subtask IDs may shift
when completed tasks leave the pending list.

## Goal

Implement the Pac-Man external application as a modular ca65/ld65 program.
The active implementation slice is Phase 3.1: Blinky target selection,
movement, and scatter/chase scheduling.

## Completed Phases

- [x] Phase 1: core setup and ca65 build pipeline.
- [x] Phase 2 implementation: maze rendering, item generation, input, Pac-Man
  movement, score display, and movement timing.

## Phase 3.1 Remediation

- [x] Review the current Phase 2 and Phase 3.1 implementation.
- [x] Synchronize task records with the active implementation state.
- [x] Draw the maze before resetting and drawing actors.
- [/] Repair and harden `autotile.py`: implementation is in place and awaits
  user acceptance.
  - Syntax repaired.
  - Logical topology separated from rendered wall tile codes.
  - Ambiguous visual corners represented by validated presentation overrides.
  - Dimensions, replacement count, and idempotence validated.
  - Read-only consistency-check mode added.
- [/] Run the maze autotiler automatically before every Pac-Man build; CMake
  integration is implemented and awaits user acceptance.
- [x] Correct the Pac-Man utility and user manuals.
- [x] Build the relocatable `pacman` target without warnings or errors.
- [x] Implement and manually verify Phase 3.1 Pac-Man/Blinky collision and
  life-loss handling.
- [x] Investigate reported Blinky corner loops: the apparent loop around an
  invisible Pac-Man was a collision-state symptom; the normal 16-tile
  top-right scatter loop remains expected.
- [x] Manually verify immediate actor visibility, Blinky movement, collision
  reset, life decrement, and game over.

## Deferred Findings

- [ ] Adjust the visually evolving maze to exactly 240 dots and four pellets.
- [ ] Implement ghost warp-tunnel entry, wrapping, and tunnel slowdown.

## Completion Gate

Phase 3.1 and this remediation remain in progress until the user confirms the
manual verification walkthrough.
