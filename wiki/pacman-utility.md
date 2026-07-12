# command64 OS PACMAN Utility Manual

**File Name:** `pacman.prg`
**Target Address:** `UserProgStart` (currently `$2C00`)
**Version:** 0.1.0

## Overview

`PACMAN` (internally "Pac64") is a character-grid Pac-Man clone for the
40×24 C64 text screen (row 24 is a dynamic status line). Pac-Man and four
ghosts — Blinky, Pinky, Inky, and Clyde — move one grid tile at a time, each
on its own independently tunable jiffy-clock timer. Ghost behaviour is the
full authentic scatter/chase/frightened/eaten state machine with all four
classic personalities, not a simplified chase-only bot.

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
| RUN/STOP | Quit and return to the command64 shell |

---

## Technical Details

### Maze tables

`mazeWalls` (read-only: 0=open, 1=wall, 2=ghost-only door) and `mazeItems`
(mutable: 0=empty, 1=dot=10pts, 2=power pellet=50pts) are both 960-byte
tables. Unlike CONWAY's grid buffers, neither is pinned to a fixed address:
CONWAY's small code leaves headroom below its hardcoded `$3000`/`$3400`, but
a full ghost-AI game does not reliably fit in the ~1KB gap between
`UserProgStart` and `$3000`, so both tables are ordinary labelled data
placed wherever the assembler lays them out. `mazeItems` starts as reserved
zero bytes and is populated at runtime by `resetItems`.

The ghost-only door (value 2) blocks Pac-Man's `canMovePac` check but not
ghosts' `canMoveGhost` check, so Pac-Man cannot wander into the ghost house.

### Grid-locked, per-actor movement

Movement is one tile per tick, where a tick fires when a per-actor
jiffy-driven delay counter expires — unlike CONWAY's single whole-grid
update per generation. This lets Pac-Man and all four ghosts move at
independently tunable speeds without a raster IRQ.

### Ghost AI

Ghosts are stored as parallel arrays (`ghostRow/Col/Dir/Mode/...`) indexed
by ghost identity, not four copy-pasted variable sets. Each elapsed tick,
`ghostMoveTick` runs a two-pass update: pass 1 computes every pending
ghost's target tile from positions as they stood at the start of the tick
(so Inky's target reads Blinky's pre-move position regardless of update
order); pass 2 resolves and applies each pending ghost's move. A legal
direction is chosen by minimum squared distance to the target tile
(precomputed `sqrTbl` avoids a runtime multiply), tie-broken in fixed order
up > left > down > right, excluding the reverse of the ghost's current
heading (except while eaten).

- **Blinky** chases Pac-Man's tile directly.
- **Pinky** targets 4 tiles ahead of Pac-Man's facing direction.
- **Inky** targets the point reflected through Blinky's position from 2
  tiles ahead of Pac-Man.
- **Clyde** chases Pac-Man until within 8 tiles, then retreats to his own
  scatter corner.

Scatter/chase phases repeat on a timed schedule; a power pellet flips
non-eaten/non-housed ghosts to frightened (award 200/400/800/1600 doubling
per ghost eaten within one pellet's window). Ghost-house release is a v1
simplification: a housed ghost pops directly to the door-exit tile when its
own release timer expires, rather than authentic dot-count-based release.

### Score rendering

The 3-byte binary score (a 16-bit counter would overflow before a real game
ends) is expanded to 6 decimal digits via repeated subtraction against a
table of 24-bit powers of ten.

### Memory Usage

| Address range | Contents |
| --- | --- |
| `UserProgStart` (`$2C00`) onward | Code, ghost/Pac-Man state, maze tables, read-only tables (~5.5KB total) |
| `$70 – $75` | Zero-page scratch (subset of the `$70-$7F` external-program range) |

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
Press `Q` or the RUN/STOP key to quit back to the shell prompt.

## Source

[src/external/pacman/pacman.asm](../src/external/pacman/pacman.asm)
