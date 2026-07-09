# CONWAY — Game of Life

**Version:** 0.4.0 (Build 1042)  
**File:** `conway.prg`  
**Load address:** `$2000`

## Overview

Conway's Game of Life rendered on the full 40×25 C64 text screen. Each character cell maps 1:1 to a simulation cell. The grid is toroidal (wrapping edges). Rules are B3/S23.

## Usage

```bash
CONWAY
```

No arguments. Starts immediately with ~25% random live cells.

## Controls

| Key | Action |
| --- | --- |
| `SPACE` | Pause / resume |
| `R` | Re-randomize |
| `C` | Clear (all dead) |
| `Q` / RUN-STOP | Quit to shell |

On quit, the screen is cleared and Conway prints its version banner
(`CONWAY v0.4.0.1042`) before returning to the shell.

## Architecture

### Double-buffered computation

Two 1024-byte page-aligned buffers at `$3000` and `$3400` alternate roles each generation. `computeNext` reads from the active buffer and writes to the inactive one; `swapBufs` toggles `zpBufSel` to exchange them. This guarantees neighbour reads always see the prior generation's state.

### Row pointer table

Multiplying a row index by 40 at runtime is avoided by a 25-entry precomputed offset table split into `rowOffLo`/`rowOffHi`. `setThreeRowPtrs` performs three 16-bit base+offset additions (carry propagates naturally from lo to hi) to set up `zpPrev`, `zpCurr`, and `zpNext` pointers for the current row before the column loop starts.

### Toroidal wrapping

Column 0's left neighbour is column 39; column 39's right neighbour is column 0. Row 0's previous row is row 24; row 24's next row is row 0. Both are handled with a compare-and-substitute before the neighbour accumulation.

### Branch-distance constraint

The column loop body (`cnColLoop`) is ~140 bytes — beyond the 6502's ±127-byte relative branch limit. The loop back-edge uses `JMP cnColLoop` guarded by `BEQ cnColDone` to stay within the opcode set.

### LFSR randomizer

8-bit Galois LFSR, polynomial `x⁸+x⁶+x⁵+x⁴+1`, mask `$B8`, period 255. Seeded from `$D012` (VIC raster) XOR `$A2` (jiffy) XOR `$0314` (IRQ vector), ORed with 1 to prevent the all-zero lockup state.

## Memory Map

| Address range | Contents |
| --- | --- |
| `$2000 – ~$227D` | Code, data tables, scratch bytes |
| `$3000 – $33FF` | Grid buffer 0 |
| `$3400 – $37FF` | Grid buffer 1 |
| `$70 – $7D` | Zero-page scratch |

## Source

[src/external/conway/conway.asm](../../src/external/conway/conway.asm)
