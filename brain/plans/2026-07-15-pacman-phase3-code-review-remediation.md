---
feature: pacman-phase3-code-review-remediation
created: 2026-07-15
status: in-progress
---

# Plan: Pac-Man Phase 3.1 Code Review Remediation

## Goal & Rationale

Restore immediate actor rendering, make the maze autotiler safe and
deterministic, and synchronize project records with the actual Phase 3.1
Blinky-only implementation.

## Scope

Included: actor redraw ordering, autotiler syntax and data contract, task and
documentation synchronization, build verification, and a manual C64/VICE
walkthrough.

Deferred: the 240-dot target while visual maze changes are underway, and ghost
warp behavior until warp tunnels are implemented.

## Files to Create/Modify

| File | Action | Notes |
| --- | --- | --- |
| `src/external/pacman/pacman_main.s` | Modify | Draw maze before resetting actor positions. |
| `src/external/pacman/autotile.py` | Modify | Separate topology input from rendered tile output and add validation/check mode. |
| `CMakeLists.txt` | Modify | Run the maze generator before the Pac-Man ca65 target. |
| `src/external/pacman/AGENTS.md` | Create | Document the generated-maze workflow and verification contract. |
| `src/external/AGENTS.md` | Modify | Index the Pac-Man child DOX contract. |
| `wiki/tasks/pacman-ca65-rewrite.md` | Create | Canonical measurable task status. |
| `wiki/pacman-utility.md` | Modify | Describe current implementation only. |
| `wiki/user-manual.md` | Modify | Correct the Pac-Man summary. |
| `brain/task.md` | Modify | Mirror Phase 3.1 status. |
| `brain/KNOWLEDGE.md` | Modify | Record the maze representation contract. |
| `brain/MEMORY.md` | Modify | Record active Pac-Man phase and deferred work. |
| `CHANGELOG.md` | Modify | Record the remediation after verification. |

## Key Design Decisions

- The autotiler consumes a logical topology with distinct path, wall, gate,
  and pellet values; it emits the current render/collision encoding used by
  `pacman_game.s`.
- Generation must validate 24x28 dimensions and replace exactly one
  `mazeWalls` block.
- A read-only `--check` mode is the primary automated consistency test.
- Deferred findings remain visible in both the wiki task and Taskwarrior.

## Verification Plan

- Parse `autotile.py` and run its read-only consistency check.
- Confirm generation is idempotent and preserves a 24x28 output table.
- Build the `pacman` target and inspect the relocatable output.
- Ask the user to verify immediate Pac-Man/Blinky visibility and Blinky motion
  in C64/VICE.
- Do not mark the remediation complete without user confirmation.

## Progress

- [x] Review completed and findings classified with the user.
- [x] Establish synchronized wiki, brain, and Taskwarrior records (Tasks 27-33).
- [/] Correct actor redraw ordering (implemented; manual confirmation pending).
- [/] Repair and harden the autotiler (implemented; user acceptance pending).
- [/] Integrate automatic maze generation into the Pac-Man build (implemented;
  user acceptance pending).
- [ ] Synchronize user and maintainer documentation.
- [ ] Complete automated and manual verification.
