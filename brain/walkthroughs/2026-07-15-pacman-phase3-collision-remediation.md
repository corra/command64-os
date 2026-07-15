# Walkthrough: Pac-Man Phase 3.1 Collision Remediation

Date: 2026-07-15
Version: 0.1.3.1055
Status: User verified

## Summary

Pac-Man and Blinky now check for tile overlap after either actor moves. Harmful
contact interrupts the tick, decrements one life, redraws the maze, and resets
both actors. At zero lives, gameplay freezes while `Q` remains available to
return to the shell. This prevents Blinky from overwriting Pac-Man and then
continuing to chase an invisibly active target.

## Files Changed

| File | Change |
| --- | --- |
| `src/external/pacman/pacman_main.s` | Added collision checks and life-loss/game-over transitions; advanced version to 0.1.3. |
| `wiki/pacman-utility.md` | Documented active collision behavior and version. |
| `wiki/user-manual.md` | Documented collision, reset, and game-over behavior. |
| `docs/user-manual.md` | Mirrored the wiki user-manual update. |
| `CHANGELOG.md` | Recorded the visibility fix and patch-stage bump. |

## Automated Verification

- `autotile.py --check` reports `pacman_game.s` current.
- `cmake --build build --target pacman` succeeds without warnings or errors.
- Build 1055 links 3,564 code bytes with 318 relocation points.

## Manual Verification

The user confirmed the build behaves correctly after observing the prior
invisible-Pac-Man failure:

1. Pac-Man/Blinky contact removes one life instead of leaving Pac-Man hidden.
2. The maze and both actors reset visibly while lives remain.
3. Repeated contact reaches game over at zero lives.
4. The apparent loop around an invisibly active Pac-Man no longer persists.

## Deferred Work

- Restore the visually evolving maze to exactly 240 dots and four pellets.
- Implement ghost warp-tunnel traversal and slowdown.
- Enable and verify Pinky, Inky, Clyde, frightened, and eaten behavior.
