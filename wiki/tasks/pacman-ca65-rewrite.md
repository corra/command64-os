# Pac-Man ca65 Rewrite

Status: [/]
Taskwarrior: 27 (parent), 28-33 (subtasks/deferred work)

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
- [/] Draw the maze before resetting and drawing actors; source change is in
  place and awaits manual C64/VICE confirmation.
- [/] Repair and harden `autotile.py`: implementation is in place and awaits
  user acceptance.
  - Syntax repaired.
  - Logical topology separated from rendered wall tile codes.
  - Ambiguous visual corners represented by validated presentation overrides.
  - Dimensions, replacement count, and idempotence validated.
  - Read-only consistency-check mode added.
- [/] Run the maze autotiler automatically before every Pac-Man build; CMake
  integration is implemented and awaits user acceptance.
- [ ] Correct the Pac-Man utility and user manuals.
- [ ] Build the relocatable `pacman` target without warnings or errors.
- [ ] Manually verify immediate actor visibility and Blinky movement in C64/VICE.

## Deferred Findings

- [ ] Adjust the visually evolving maze to exactly 240 dots and four pellets.
- [ ] Implement ghost warp-tunnel entry, wrapping, and tunnel slowdown.

## Completion Gate

Phase 3.1 and this remediation remain in progress until the user confirms the
manual verification walkthrough.
