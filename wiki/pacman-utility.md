# command64 OS PACMAN Utility Manual

**File Name:** `pacman.prg`
**Target Address:** `UserProgStart` (currently `$3400`)
**Version:** 0.1.3.1055

## Overview

`PACMAN` (internally "Pac64") is an in-progress character-grid Pac-Man clone.
The maze occupies a centered 28×24 playfield on the C64's 40×25 text screen;
row 24 is a dynamic status line. Pac-Man movement, Phase 3.1 Blinky
scatter/chase movement, collision, life loss, and game over are active. Pinky,
Inky, Clyde, frightened/eaten behavior, fruit, and ghost tunnel traversal are
not yet playable.

## Command Syntax

```
PACMAN
```

No arguments. Starts immediately at level 1 with 3 lives.

---

## Controls

| Key | Action |
| --- | --- |
| `W` / `A` / `S` / `D` | Move up / left / down / right (buffered: an early turn is taken the instant it becomes legal) |
| `P` / `SPACE` | Pause / resume |
| `Q` | Quit and return to the command64 shell |

---

## Technical Details

### Maze tables

`mazeWalls` and `mazeItems` are each 672-byte tables covering 28×24 cells.
`mazeWalls` uses 0 for an open path, 1–9 for rendered wall shapes, 10 for the
ghost gate, and 11 for an open power-pellet marker. `mazeItems` is mutable:
0=empty, 1=dot, 2=power pellet, and 3=fruit. It is populated at runtime by
`resetItems`.

The logical topology lives in `autotile.py`. Normal wall shapes are inferred
from neighboring topology cells; eight presentation-only overrides preserve
ambiguous corners. CMake runs this generator before every Pac-Man build, and
`autotile.py --check` verifies that `pacman_game.s` is current.

The gate (value 10) blocks Pac-Man. Ghost gate entry and warp-tunnel traversal
are deferred.

### Grid-locked, per-actor movement

Movement is one tile per actor-timer expiration. Pac-Man and Blinky currently
use independently tunable jiffy-driven delays without a raster IRQ. The other
three ghost records and timers are initialized but not advanced in Phase 3.1.

### Ghost AI

Ghosts are stored as parallel arrays (`ghostRow/Col/Dir/Mode/...`) indexed by
identity. Blinky is the only ghost currently updated and drawn. A legal
direction is chosen by minimum squared distance to the target tile using a
square lookup table, tie-broken in fixed order up > left > down > right, while
excluding reversal unless no forward candidate exists.

- **Blinky:** active in Phase 3.1; alternates between his scatter corner and
  Pac-Man's tile.
- **Pinky, Inky, and Clyde:** target calculations exist in `pacman_ai.s`, but
  their movement remains disabled pending later Phase 3 integration.

The scatter/chase scheduler is active. A collision is checked after either
Pac-Man or Blinky moves; harmful contact decrements one life, resets the maze
and actors while lives remain, and freezes play at zero lives. Power pellets
currently award 50 points and apply Pac-Man's movement delay, but they do not
yet activate frightened mode. Ghost consumption, house release, and
eaten-ghost recovery remain unimplemented.

### Score rendering

The 3-byte binary score (a 16-bit counter would overflow before a real game
ends) is expanded to 6 decimal digits via repeated subtraction against a
table of 24-bit powers of ten.

### Memory Usage

| Address range | Contents |
| --- | --- |
| `UserProgStart` (`$3400`) onward | Relocatable code, actor state, maze tables, and lookup tables |
| `$70–$84` | App-private Pac-Man state and scratch zero page |

---

## Practical Examples

### Start the game
```
PACMAN
```
The maze is drawn and the game begins at level 1 with 3 lives.

### Pause, inspect, resume
Press `P` or `SPACE` to freeze the display. Press it again to continue.

### Return to shell
Press `Q` to quit back to the shell prompt.

## Source

- [pacman_main.s](../src/external/pacman/pacman_main.s)
- [pacman_game.s](../src/external/pacman/pacman_game.s)
- [pacman_ai.s](../src/external/pacman/pacman_ai.s)
- [autotile.py](../src/external/pacman/autotile.py)
