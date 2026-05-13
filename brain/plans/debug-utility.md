# Implementation Plan: DEBUG Utility

## Objective
Develop a C64 port of MS-DOS `DEBUG.COM` as an external program. Provide low-level memory inspection, modification, and execution.

## Design Decisions
1. **Memory Range Logic**: Use Process-then-Check (do-while) loop structure to ensure inclusive ranges (e.g. `F 1000 1000 FF` fills 1 byte).
2. **Overlap Safety**: `cmdMove` must check `dest > src` and copy backwards (tail-to-head) to prevent source corruption.
3. **Register Safety**: Preserve `Y` register across KERNAL `GETIN` calls to prevent input buffer corruption.
4. **Memory Map**: Use `$2000` entry point. Define private ZP scratch block at `$70-$7F`.

## Implementation Steps
1. Create `debug.asm` skeleton with input loop.
2. Implement 16-bit hex parser.
3. Implement core commands: Dump (D), Enter (E), Fill (F), Move (M), Compare (C), Search (S), Hex Math (H), Register (R), Go (G).
4. Refine UI: 8-byte row format for 40-col screen, midpoint `:` separator.

## Verification & Testing
- Follow `brain/walkthroughs/debug-test-plan.md`.
