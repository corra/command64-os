#!/usr/bin/env python3
"""Generate Pac64's rendered maze-wall table from logical topology."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


ROWS = 24
COLS = 28

PATH = "."
WALL = "#"
GATE = "G"
PELLET = "P"

TILE_TOP_LEFT = 5
TILE_TOP_RIGHT = 6
TILE_BOTTOM_LEFT = 7
TILE_BOTTOM_RIGHT = 8

# Logical collision/item topology. Rendering codes do not belong here:
#   . = open path, # = wall, G = ghost gate, P = open power-pellet tile.
TOPOLOGY = (
    "############################",
    "#............##............#",
    "#.####.#####.##.#####.####.#",
    "#P####.#####.##.#####.####P#",
    "#..........................#",
    "#.####.##.########.##.####.#",
    "#.####.##.########.##.####.#",
    "#......##....##....##......#",
    "######.#####.##.#####.######",
    "######.#####.##.#####.######",
    "............................",
    "######.##.###GG###.##.######",
    "######.##.#......#.##.######",
    "######.##.########.##.######",
    "######.##..........##.######",
    "######.##.########.##.######",
    "#..........................#",
    "#.####.#####.##.#####.####.#",
    "#P..##.......##.......##..P#",
    "###.##.##.########.##.##.###",
    "#......##....##....##......#",
    "#.##########.##.##########.#",
    "#............##............#",
    "############################",
)

# Occupancy alone cannot distinguish a few intentionally different outline
# corners. These presentation-only overrides preserve those shapes without
# leaking render codes into the gameplay topology.
TILE_OVERRIDES = {
    (6, 13): TILE_TOP_RIGHT,
    (6, 14): TILE_TOP_LEFT,
    (8, 8): TILE_BOTTOM_LEFT,
    (8, 19): TILE_BOTTOM_RIGHT,
    (11, 5): TILE_BOTTOM_RIGHT,
    (11, 22): TILE_BOTTOM_LEFT,
    (13, 5): TILE_TOP_RIGHT,
    (13, 22): TILE_TOP_LEFT,
}

MAZE_BLOCK_RE = re.compile(
    r"mazeWalls:\s*\n(?:\s*\.byte\s+[0-9,]+\s*(?:;[^\n]*)?\n){24}"
)


def validate_topology() -> None:
    """Reject malformed or ambiguous logical maze input."""
    if len(TOPOLOGY) != ROWS:
        raise ValueError(f"topology has {len(TOPOLOGY)} rows; expected {ROWS}")

    allowed = {PATH, WALL, GATE, PELLET}
    for row_index, row in enumerate(TOPOLOGY):
        if len(row) != COLS:
            raise ValueError(
                f"topology row {row_index} has {len(row)} columns; expected {COLS}"
            )
        invalid = set(row) - allowed
        if invalid:
            raise ValueError(
                f"topology row {row_index} contains invalid symbols: {invalid}"
            )

    pellet_count = sum(row.count(PELLET) for row in TOPOLOGY)
    if pellet_count != 4:
        raise ValueError(f"topology has {pellet_count} pellets; expected 4")

    gate_count = sum(row.count(GATE) for row in TOPOLOGY)
    if gate_count != 2:
        raise ValueError(f"topology has {gate_count} gate cells; expected 2")

    for (row, col), tile in TILE_OVERRIDES.items():
        if not (0 <= row < ROWS and 0 <= col < COLS):
            raise ValueError(f"tile override ({row}, {col}) is out of bounds")
        if TOPOLOGY[row][col] != WALL:
            raise ValueError(f"tile override ({row}, {col}) does not target a wall")
        if tile not in range(1, 10):
            raise ValueError(f"tile override ({row}, {col}) uses invalid code {tile}")


def is_wall(row: int, col: int) -> bool:
    """Return whether a neighboring topology cell is a solid wall."""
    if row < 0 or row >= ROWS or col < 0 or col >= COLS:
        return True
    return TOPOLOGY[row][col] == WALL


def render_wall(row: int, col: int) -> int:
    """Choose a C64 wall character code from neighboring logical walls."""
    override = TILE_OVERRIDES.get((row, col))
    if override is not None:
        return override

    # The outer boundary faces into the playfield. Out-of-grid neighbors do not
    # describe that orientation, so encode its four edges explicitly.
    if row == 0:
        if col == 0:
            return 5
        if col == COLS - 1:
            return 6
        return 1
    if row == ROWS - 1:
        if col == 0:
            return 7
        if col == COLS - 1:
            return 8
        return 2
    if col == 0:
        return {8: 5, 11: 7, 13: 5, 15: 7}.get(row, 3)
    if col == COLS - 1:
        return {8: 6, 11: 8, 13: 6, 15: 8}.get(row, 4)

    up = is_wall(row - 1, col)
    down = is_wall(row + 1, col)
    left = is_wall(row, col - 1)
    right = is_wall(row, col + 1)

    if not left and not up and right and down:
        return 5
    if not right and not up and left and down:
        return 6
    if not left and not down and right and up:
        return 7
    if not right and not down and left and up:
        return 8
    if not up and not down:
        return 1
    if up and down and left and right:
        return 9
    if not left and not right:
        return 3
    if up and down:
        return 3 if not left else 4
    if left and right:
        return 1 if not up else 2
    return 9


def generate_tiles() -> list[list[int]]:
    """Translate logical topology into the assembly render/collision encoding."""
    validate_topology()
    tiles: list[list[int]] = []
    for row_index, row in enumerate(TOPOLOGY):
        rendered_row: list[int] = []
        for col_index, cell in enumerate(row):
            if cell == PATH:
                rendered_row.append(0)
            elif cell == GATE:
                rendered_row.append(10)
            elif cell == PELLET:
                rendered_row.append(11)
            else:
                rendered_row.append(render_wall(row_index, col_index))
        tiles.append(rendered_row)
    return tiles


def format_maze_block(tiles: list[list[int]]) -> str:
    """Format a validated 24x28 tile grid as ca65 source."""
    lines = ["mazeWalls:"]
    for row_index, row in enumerate(tiles):
        values = ",".join(str(value) for value in row)
        lines.append(f"    .byte {values} ; Row {row_index}")
    return "\n".join(lines) + "\n"


def update_source(source: str, maze_block: str) -> str:
    """Replace exactly one complete mazeWalls block."""
    updated, replacement_count = MAZE_BLOCK_RE.subn(maze_block, source)
    if replacement_count != 1:
        raise ValueError(
            f"found {replacement_count} complete mazeWalls blocks; expected exactly 1"
        )
    return updated


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="report whether pacman_game.s matches generated output without writing",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    source_path = Path(__file__).resolve().with_name("pacman_game.s")

    try:
        source = source_path.read_text(encoding="utf-8")
        expected = update_source(source, format_maze_block(generate_tiles()))
    except (OSError, ValueError) as error:
        print(f"autotile: {error}", file=sys.stderr)
        return 2

    if args.check:
        if expected != source:
            print(f"autotile: {source_path.name} is out of date", file=sys.stderr)
            return 1
        print(f"autotile: {source_path.name} is up to date")
        return 0

    if expected == source:
        print(f"autotile: {source_path.name} is already up to date")
        return 0

    source_path.write_text(expected, encoding="utf-8")
    print(f"autotile: updated {source_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
