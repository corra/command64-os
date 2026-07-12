# command64 OS CONWAY Utility Manual

**File Name:** `conway.prg`
**Target Address:** `$2000` (Standard User Program Space)
**Version:** 0.4.0 (Build 1042)

## Overview

`CONWAY` is Conway's Game of Life — a classic cellular automaton — rendered directly on the C64 text screen. The full 40×25 character display becomes a live simulation grid. Each cell follows John Conway's B3/S23 rules:

- **Birth:** A dead cell with exactly 3 live neighbours becomes alive.
- **Survival:** A live cell with 2 or 3 live neighbours survives.
- **Death:** All other cells die or remain dead.

The grid is **toroidal**: the left edge wraps to the right, and the top edge wraps to the bottom, giving every cell a full 8-cell Moore neighbourhood with no special-case boundary handling.

## Command Syntax

```sh
CONWAY
```

No arguments. The simulation starts immediately with a randomly seeded grid (~25% live cells).

---

## Controls

| Key | Action |
| --- | --- |
| `SPACE` | Pause / resume the simulation |
| `R` | Re-randomize the grid (new random seed) |
| `C` | Clear the grid (all cells set to dead) |
| `Q` | Quit and return to the command64 shell |
| RUN/STOP | Quit and return to the command64 shell |

On quit, the screen is cleared and CONWAY prints its version banner
(`CONWAY v0.4.0.1042`) before returning to the shell.

---

## Display

| Element | Appearance |
| --- | --- |
| Live cell | Green solid block (`$A0`, reverse-space glyph) |
| Dead cell | Black (space character, background shows through) |
| Border / background | Black (`$D020`/`$D021` set to 0) |

Color RAM is filled with green (VIC-II color 5) at startup and is not modified per frame. The live/dead distinction is carried entirely by the character written to screen RAM (`$A0` vs `$20`).

---

## Technical Details

### Algorithm

Each generation is computed using **double buffering**: a source buffer is read for neighbour counts while a separate destination buffer receives the new state. The buffers swap roles after every generation, so reads and writes never alias.

- **Buffer addresses:** `$3000` (first buffer) and `$3400` (second buffer), each 1024 bytes, page-aligned (1000 cells used, 24 bytes of padding).
- **Cell encoding:** 1 byte per cell — `0` = dead, `1` = alive.
- **Swap mechanism:** `computeNext` reads from the active buffer and writes to the inactive one; `swapBufs` toggles `zpBufSel` to exchange them, guaranteeing neighbour reads always see the prior generation's state.

To avoid multiplying a row index by 40 at runtime, a 25-entry precomputed
offset table (split into `rowOffLo`/`rowOffHi`) is used instead.
`setThreeRowPtrs` performs three 16-bit base+offset additions (carry
propagates naturally from lo to hi) to set up `zpPrevLo/Hi`, `zpCurrLo/Hi`,
and `zpNextLo/Hi` for the current row before the column loop starts.

The column loop body (`cnColLoop`) is ~140 bytes — beyond the 6502's
±127-byte relative branch limit. The loop back-edge uses `JMP cnColLoop`
guarded by `BEQ cnColDone` to stay within the opcode set.

### Random Seeding

The pseudo-random number generator is an 8-bit Galois LFSR with polynomial `x⁸ + x⁶ + x⁵ + x⁴ + 1` (feedback mask `$B8`, period 255). The LFSR is seeded at startup from:

- VIC-II raster counter (`$D012`)
- KERNAL jiffy clock (`$A2`)
- IRQ vector low byte (`$0314`)

This produces a different starting pattern on each run.

### Timing

Animation speed is controlled by the KERNAL jiffy clock (`$A2`). The simulation waits for **3 jiffy ticks** between generations, giving approximately 20 generations per second on both PAL and NTSC systems.

### Memory Usage

| Region | Purpose |
| --- | --- |
| `$2000 – ~$227D` | CONWAY program code and data tables |
| `$3000 – $33FF` | Grid buffer 0 (1024 bytes) |
| `$3400 – $37FF` | Grid buffer 1 (1024 bytes) |
| `$70 – $7D` | Zero-page scratch (14 bytes) |

### Zero Page Layout

| Address | Label | Purpose |
| --- | --- | --- |
| `$70–$71` | `zpPrevLo/Hi` | Pointer to previous row in active buffer |
| `$72–$73` | `zpCurrLo/Hi` | Pointer to current row in active buffer |
| `$74–$75` | `zpNextLo/Hi` | Pointer to next row in active buffer |
| `$76–$77` | `zpDstLo/Hi` | Pointer to current row in inactive buffer |
| `$78` | `zpRow` | Row loop counter (0–24) |
| `$79` | `zpCol` | Column loop counter (0–39) |
| `$7A` | `zpCount` | Moore-neighbourhood live count |
| `$7B` | `zpLfsr` | LFSR state byte |
| `$7C` | `zpPaused` | Pause flag (0 = running, $FF = paused) |
| `$7D` | `zpBufSel` | Active buffer selector (0 = grid0, 1 = grid1) |

---

## Practical Examples

### Start the simulation

```sh
CONWAY
```

The screen goes black and the simulation begins with a randomized grid.

### Pause, inspect, resume

Press `SPACE` to freeze the display. Press `SPACE` again to continue.

### Try a different pattern

Press `R` to discard the current state and seed a fresh random grid.

### Return to shell

Press `Q` or the RUN/STOP key. The screen is cleared and the shell prompt returns.

## Source

[src/external/conway/conway_main.s](../src/external/conway/conway_main.s), [src/external/conway/conway_grid.s](../src/external/conway/conway_grid.s)
