# Purpose

The `pacman` directory contains the ca65/ld65 Pac-Man external application,
its logical maze generator, generated maze table, and game/AI modules.

# Ownership

- Primary Owner: Companion Agent (Gemini)
- Peer Owner: Primary Architect (Claude)

# Local Contracts

- `autotile.py` owns the logical 24x28 maze topology.
- `pacman_game.s` contains the generated `mazeWalls` render/collision table.
- The `pacman` CMake target must run `pacman_autotile` before assembling source.
- Logical topology symbols describe gameplay; ambiguous visual wall shapes use
  validated presentation-only overrides.
- The exact 240-dot target and ghost warp-tunnel behavior are deferred tasks and
  must remain visible in project task records until implemented.

# Work Guidance

- Run `python3 src/external/pacman/autotile.py --check` after topology or tile
  inference changes.
- Do not hand-edit generated `mazeWalls` values without making the corresponding
  topology or override change in `autotile.py`.
- Preserve the app-private zero-page allocation contract in `common.inc`.

# Verification

- `autotile.py --check` must report that `pacman_game.s` is current.
- Repeated generation must not rewrite an unchanged `pacman_game.s`.
- `cmake --build build --target pacman` must assemble and link the relocatable
  application without warnings or errors.
- Runtime behavior requires user-run C64/VICE verification.

# Child DOX Index

- (none)
