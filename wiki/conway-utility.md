# command64 OS CONWAY Utility Manual

**File Name:** `conway.prg`
**Load Address:** Relocatable (selected by the command64 app manager)
**Version:** 0.4.1 (Build 1058)

## Overview

`CONWAY` is a menu-driven Life-like cellular automaton rendered directly on
the C64 text screen. Rows 0–23 form a 40×24 live grid and row 24 displays
controls plus a five-digit generation counter. The menu initially selects
John Conway's B3/S23 rules:

- **Birth:** A dead cell with exactly 3 live neighbours becomes alive.
- **Survival:** A live cell with 2 or 3 live neighbours survives.
- **Death:** All other cells die or remain dead.

The grid is **toroidal**: the left edge wraps to the right, and the top edge wraps to the bottom, giving every cell a full 8-cell Moore neighbourhood with no special-case boundary handling.

## Command Syntax

```sh
CONWAY
```

No arguments. The utility opens on its Multiverse menu with preset 1 selected
and a randomized field retained behind the menu.

---

## Controls

| Key | Action |
| --- | --- |
| `SPACE` | Pause / resume the simulation |
| `R` | Re-randomize the grid and reset the counter |
| `C` | Clear the grid, reset the counter, and pause |
| `Q` | Return to the Multiverse menu |
| RUN/STOP | Quit and return to the command64 shell |

While paused, only the status word `pause` changes to cyan. It returns to green
when simulation resumes.

### Menu controls

| Key | Action |
| --- | --- |
| `1`–`9` | Select one of the nine Life-like presets |
| `B`, then `0`–`8` | Toggle one Birth count, mark the rule custom, and return to the normal menu |
| `S`, then `0`–`8` | Toggle one Survival count, mark the rule custom, and return to the normal menu |
| RETURN | Run the retained field with the selected rule |
| `R` | Randomize and run with the selected rule |
| `Q` or RUN/STOP | Exit to the command64 shell |

To change multiple counts, press `B` or `S` again before each additional
digit. A non-digit cancels the pending edit without changing the rule. Empty
Birth or Survival sets are displayed as `none`.

On quit, the screen is cleared and CONWAY prints its version banner
(`CONWAY v0.4.1.1058`) before returning to the shell.

### Rule presets

| Key | Name | Rule |
| --- | --- | --- |
| `1` | Conway's Life | B3/S23 |
| `2` | Ant Colony | B3/S234 |
| `3` | World on Fire | B34/S23 |
| `4` | Blinkers | B345/S2 |
| `5` | Mazectric | B3/S1234 |
| `6` | Maze | B3/S12345 |
| `7` | Life without Death | B3/S012345678 |
| `8` | Coral | B3/S45678 |
| `9` | Assimilation | B3/S4567 |

---

## Display

| Element | Appearance |
| --- | --- |
| Live cell | Green solid block (`$A0`, reverse-space glyph) |
| Dead cell | Black (space character, background shows through) |
| Border / background | Black (`$D020`/`$D021` set to 0) |
| Generation | `gen:00000` at the right of the status row; increments after each completed generation |
| Menu version | Full patch/build version (`0.4.1.1058`) at the bottom-right |

Color RAM is filled with green (VIC-II color 5) at startup. Only the five
letters in `pause` are recolored during simulation: cyan while paused and
green while running. The live/dead distinction is carried by the character
written to screen RAM (`$A0` vs `$20`).

---

## Technical Details

### Algorithm

Each generation is computed using **double buffering**: a source buffer is read for neighbour counts while a separate destination buffer receives the new state. The buffers swap roles after every generation, so reads and writes never alias.

- **Buffers:** `grid0` and `grid1` are emitted, relocatable, page-aligned
  960-byte buffers (40×24 cells each).
- **Cell encoding:** 1 byte per cell — `0` = dead, `1` = alive.
- **Swap mechanism:** `computeNext` reads from the active buffer and writes to the inactive one; `swapBufs` toggles `zpBufSel` to exchange them, guaranteeing neighbour reads always see the prior generation's state.

To avoid multiplying a row index by 40 at runtime, a 24-entry precomputed
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

Animation speed is controlled by the KERNAL jiffy clock (`$A2`). The
simulation waits for **3 jiffy ticks** between generations, giving a nominal
20 generations per second on NTSC and about 16.7 on PAL, before computation
and drawing overhead.

### Memory Usage

| Region | Purpose |
| --- | --- |
| Relocatable app image | Code, compact preset masks, active rules, counter scratch, and both emitted grid buffers |
| `$0400–$07E7` | Screen RAM: 24-row grid/menu plus status row |
| `$D800–$DBE7` | Color RAM |
| `$70–$82` | App-private zero-page state and scratch |

### Zero Page Layout

| Address | Label | Purpose |
| --- | --- | --- |
| `$70–$71` | `zpPrevLo/Hi` | Pointer to previous row in active buffer |
| `$72–$73` | `zpCurrLo/Hi` | Pointer to current row in active buffer |
| `$74–$75` | `zpNextLo/Hi` | Pointer to next row in active buffer |
| `$76–$77` | `zpDstLo/Hi` | Pointer to current row in inactive buffer |
| `$78` | `zpRow` | Row loop counter (0–23) |
| `$79` | `zpCol` | Column loop counter (0–39) |
| `$7A` | `zpCount` | Moore-neighbourhood live count |
| `$7B` | `zpLfsr` | LFSR state byte |
| `$7C` | `zpPaused` | Pause flag (0 = running, $FF = paused) |
| `$7D` | `zpBufSel` | Active buffer selector (0 = grid0, 1 = grid1) |
| `$7E` | `zpInMenu` | Nonzero while the menu is active |
| `$7F` | `zpMenuState` | Normal, Birth-edit, or Survival-edit state |
| `$80` | `zpPresetIdx` | Preset index 0–8, or `$FF` for a custom rule |
| `$81–$82` | `zpGenLo/Hi` | 16-bit generation counter |

---

## Practical Examples

### Start the simulation

```sh
CONWAY
```

The Multiverse menu opens with preset 1 selected and a randomized field
retained behind it. Press RETURN to run that field.

### Pause, inspect, resume

Press `SPACE` to freeze the display. Press `SPACE` again to continue.

### Try a different pattern

Press `R` during simulation to discard the current state and seed a fresh
random grid. From the menu, `R` randomizes and immediately starts.

### Return to shell

From simulation, press `Q` to return to the menu or RUN/STOP to exit directly.
From the menu, press `Q` or RUN/STOP to return to the shell.

## Source

[src/external/conway/conway_main.s](../src/external/conway/conway_main.s), [src/external/conway/conway_grid.s](../src/external/conway/conway_grid.s)
