#!/usr/bin/env python3
"""Diagnose Pac64 maze dot-completion bugs by comparing three independent
views of the same maze that the ca65 sources currently maintain by hand:

  1. autotile.py's TOPOLOGY / generate_tiles() -- the wall/collision codes
     ghosts and Pac-Man actually path against (getWallCell/canMovePac).
  2. resetItems' hardcoded row/col exclusion zones in pacman_game.s, which
     decide where a dot/pellet is placed at level start.
  3. A BFS reachability flood from Pac-Man's spawn tile, using the same
     legality rule canMovePac uses (wall code 0 or 11 is walkable; the
     door, code 10, is not, matching the arcade rule that Pac-Man cannot
     enter the ghost house).

If any tile that receives a dot is not reachable from spawn, the level can
never report zero dots remaining -- this is the concrete failure mode for
"eating all the pellets doesn't complete the level."

Usage: python3 scripts/pacman_maze_reachability.py
"""

from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

PACMAN_DIR = Path(__file__).resolve().parent.parent / "src" / "external" / "pacman"
sys.path.insert(0, str(PACMAN_DIR))

import autotile  # noqa: E402  (path must be extended first)

PAC_SPAWN_ROW = 16
PAC_SPAWN_COL = 13

# resetItems' hardcoded exclusion zones (pacman_game.s resetItems), mirrored
# here exactly so this script tests what the assembly actually does, not
# what it is intended to do.
def resetitems_excludes_dot(row: int, col: int) -> bool:
    if row == 10 and (col < 5 or col >= 23):
        return True  # warp tunnel
    if row == 12 and 11 <= col < 17:
        return True  # ghost house interior
    if row == 16 and col in (13, 14):
        return True  # Pac-Man spawn
    if row == 14 and col == 13:
        return True  # fruit rest tile (FRUIT_SPAWN_ROW/COL in common.inc)
    return False


def walkable(tiles: list[list[int]], row: int, col: int) -> bool:
    if row < 0 or row >= autotile.ROWS:
        return False
    # Tunnel row wraps horizontally; treat out-of-range columns on row 10
    # as their wrapped counterpart rather than out of bounds.
    if col < 0 or col >= autotile.COLS:
        if row != 10:
            return False
        col %= autotile.COLS
    code = tiles[row][col]
    return code in (0, 11)


def bfs_reachable(tiles: list[list[int]], start: tuple[int, int]) -> set[tuple[int, int]]:
    seen = {start}
    queue = deque([start])
    while queue:
        row, col = queue.popleft()
        for dr, dc in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            nr, nc = row + dr, col + dc
            if row == 10 and (nc < 0 or nc >= autotile.COLS):
                nc %= autotile.COLS
            if not walkable(tiles, nr, nc):
                continue
            if (nr, nc) in seen:
                continue
            seen.add((nr, nc))
            queue.append((nr, nc))
    return seen


def main() -> int:
    autotile.validate_topology()
    tiles = autotile.generate_tiles()

    reachable = bfs_reachable(tiles, (PAC_SPAWN_ROW, PAC_SPAWN_COL))

    dot_cells = []
    unreachable_dots = []
    for row in range(autotile.ROWS):
        for col in range(autotile.COLS):
            code = tiles[row][col]
            if code not in (0, 11):
                continue  # wall/gate: resetItems never places a dot here
            if resetitems_excludes_dot(row, col):
                continue
            dot_cells.append((row, col, code))
            if (row, col) not in reachable:
                unreachable_dots.append((row, col, code))

    print(f"Total open/pellet tiles reachable from Pac-Man spawn: {len(reachable)}")
    print(f"Total tiles resetItems would place a dot/pellet on:  {len(dot_cells)}")
    print()

    if unreachable_dots:
        print(f"UNREACHABLE dot/pellet tiles ({len(unreachable_dots)}) -- these can "
              f"never be eaten, so dotsRemaining can never reach zero:")
        for row, col, code in unreachable_dots:
            kind = "pellet" if code == 11 else "dot"
            print(f"  row {row:2d} col {col:2d} ({kind}, wall code {code})")
    else:
        print("No unreachable dot/pellet tiles found -- every placed item is reachable.")

    print()
    print(f"Placed dot/pellet count: {len(dot_cells)} (arcade target: 240)")
    return 1 if unreachable_dots else 0


if __name__ == "__main__":
    raise SystemExit(main())
