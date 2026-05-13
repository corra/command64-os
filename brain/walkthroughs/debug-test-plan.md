# Test Plan: DEBUG Utility

## 1. Introduction
This plan outlines the verification steps for the `DEBUG` external utility (v0.1). The goal is to ensure all core memory manipulation and system inspection commands function correctly and that the utility maintains technical integrity within the `command64` environment.

## 2. Environment Setup
1. Boot `command64.prg`.
2. Ensure `debug.prg` is present on the disk image (Device 8).
3. Execute `debug` from the shell prompt.

## 3. Test Cases

### TC 1: UI & Input Handling
- **Action**: Launch `DEBUG`. Type "abc", then use INST/DEL to delete characters. Press ENTER.
- **Expected**: Welcome message "DEBUG v0.1" appears. Prompt "-" appears. Backspace destructively deletes characters on screen. Empty command returns to a new prompt.

### TC 2: Hexadecimal Arithmetic (H)
- **Action**: `-H 1000 0050`
- **Expected**: `1050  0FB0` (Sum and Difference).
- **Action**: `-H FFFF 0001`
- **Expected**: `0000  FFFE` (Verify wrap-around/16-bit math).

### TC 3: Memory Fill & Dump (F, D)
- **Action**: `-F 4000 400F AA` (Fill $10 bytes with $AA).
- **Action**: `-D 4000`
- **Expected**: First row shows address `4000:` followed by sixteen `AA` bytes.
- **Action**: `-D`
- **Expected**: Displays next 128 bytes (advancing from $4010).

### TC 4: Memory Enter (E)
- **Action**: `-E 5000 11 22 33 44`
- **Action**: `-D 5000`
- **Expected**: Bytes at $5000 are `11 22 33 44`.

### TC 5: Memory Move (M)
- **Action**: `-F 6000 600F FF`
- **Action**: `-M 6000 600F 7000`
- **Action**: `-D 7000`
- **Expected**: Memory at $7000-$700F contains `FF`.

### TC 6: Memory Compare (C)
- **Action**: `-F 8000 800F 01`, then `-F 9000 900F 01`.
- **Action**: `-C 8000 800F 9000`
- **Expected**: No output (Identical blocks).
- **Action**: `-E 9005 02`, then `-C 8000 800F 9000`.
- **Expected**: Output: `8005 01 02 9005` (Showing mismatch at offset 5).

### TC 7: Memory Search (S)
- **Action**: `-F A000 A0FF 00`, then `-E A050 BB`.
- **Action**: `-S A000 A0FF BB`
- **Expected**: Output: `A050` (Found byte).

### TC 8: Register Display (R)
- **Action**: `-R`
- **Expected**: Output: `A=.. X=.. Y=.. P=.. S=..` with valid hex values.

### TC 9: Execution (G)
- **Action**: `-E B000 60` (6502 `RTS` opcode).
- **Action**: `-G B000`
- **Expected**: Returns immediately to the `-` prompt.

### TC 10: OS Integration & Exit (Q)
- **Action**: `-Q`
- **Expected**: Returns to the `C64:> ` prompt.

## 4. Pass/Fail Criteria
- All commands must produce the expected output without crashing.
- Memory modifications must be persistent within the session.
- The utility must return control to the shell cleanly.
