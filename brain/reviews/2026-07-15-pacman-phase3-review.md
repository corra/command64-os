# Pac-Man Phase 3.1 Code Review

Date: 2026-07-15
Status: Remediated; two findings explicitly deferred

## Scope

Review the ca65 Pac-Man rewrite with emphasis on the active Phase 3.1 Blinky
integration and regressions inherited from Phase 2.

## Findings

| ID | Severity | Finding | Disposition |
| --- | --- | --- | --- |
| P1 | High | Maze currently generates 246 dots rather than the specified 240. | Deferred while the maze is adjusted for visual quality. |
| P2 | High | `resetPositions` draws actors before `drawMaze`, which erases them. | Source remediated; manual confirmation pending. |
| P3 | High | Ghost direction evaluation prevents entry into warp-wrap coordinates. | Deferred until warp tunnels are implemented. |
| P4 | High | `autotile.py` does not parse as Python. | Remediated and user accepted. |
| P5 | High | The autotiler mixes logical topology values with rendered wall-character values. | Remediated with logical topology, inferred tiles, and validated visual overrides; user accepted. |
| P6 | Medium | Project records stop at Phase 2 although Phase 3.1 is active. | Remediated and user accepted. |
| P7 | Medium | The Pac-Man manual describes unimplemented behavior and stale layouts. | Remediated and user accepted. |

## Verification Evidence

- `mazeWalls` contains 24 rows and 672 cells.
- Runtime item generation currently produces 246 dots and four pellets.
- Python AST parsing reports an unterminated list in `autotile.py`.
- Source comments identify the active runtime slice as Phase 3.1 with only
  Blinky enabled.

## Remediation

See `brain/plans/2026-07-15-pacman-phase3-code-review-remediation.md`.
