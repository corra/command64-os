# Pac-Man Ghost House Remediation

Status: [/]
Taskwarrior: project `command64.pacman`

## Goal

Implement the Pac-Man ghost house state machine and counters as specified in `brain/plans/2026-07-15_pacman-ghost-house-remediation-plan.md`.

## Tasks

- [ ] Phase 1: Establish state-machine invariants & document transitions.
- [ ] Phase 2: Make house movement direction-only (`handleHouseBouncing`, `handleHouseExit`).
- [ ] Phase 3: Protect lifecycle modes from scheduler transitions (`transitionGhostModes`).
- [ ] Phase 4: Replace derived totals with explicit release counters in BSS.
- [ ] Phase 5: Move release accounting into item consumption (`recordReleaseDot` inside `decDots`).
- [ ] Phase 6: Implement exact global post-death behavior (7/17/32 thresholds).
- [ ] Phase 7: Add the non-blocking inactivity timer.
- [ ] Phase 8: Correct eaten-ghost revival routing in `updateGhosts`.
- [ ] Phase 9: Add invariant-oriented diagnostics.
- [ ] Phase 10: Documentation and Task synchronization.
- [ ] Verification and User Acceptance.
