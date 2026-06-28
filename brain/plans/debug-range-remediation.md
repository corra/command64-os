---
feature: debug-range-remediation
created: 2026-06-27
status: planned
---

# Plan: DEBUG Range and Dump Remediation

## Goal & Rationale
The `DEBUG` utility has two known bugs affecting memory ranges:
1. **Uppercase `L` Case-Sensitivity Bug**: Range commands with length parameters (e.g., `F 1000 L 10 FF` or `U 2000 L 10`) fail if typed with an uppercase `L` (Shift+L) because of a character conversion discrepancy under `petscii_mixed` encoding.
2. **Missing Dump Range Support**: The Dump (`D`) command only accepts a starting address and always dumps 128 bytes, ignoring end address or length range specifiers (e.g. `D 1000 1020` or `D 1000 L 20`), despite being documented as range-capable.

This plan addresses both issues to restore range parity as specified in the user manual.

## Scope
- Modify `src/external/debug/debug.asm` to:
  - Fix length identifier parsing in `parseRange`.
  - Add range and length parameter parsing and enforcement to `cmdDump`.
- Modify `CHANGELOG.md` to document the fixes.

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `src/external/debug/debug.asm` | Modify | Fix range parsing case-sensitivity and implement `D` command range logic. |
| `CHANGELOG.md` | Modify | Add build notes. |

## Key Design Decisions

### 1. Fix Uppercase `L` Parsing
In `parseRange`:
```asm
    // Check for 'L' or 'l'
    lda inputBuf, y
    cmp #'l'
    beq prLength
    and #$7F
    cmp #'L'
    beq prLength
```
Since `'L'` compiles to `$CC` in `petscii_mixed`, the `and #$7F` instruction yields `$4C` from shifted `$CC`, but comparing it against `'L'` (`$CC`) fails. Changing `cmp #'L'` to `cmp #'l'` (or comparing the masked value to `'l'`) resolves the case-insensitive comparison correctly.

### 2. Implement `D` Command Range Logic
Refactor `cmdDump` to use a structure similar to `cmdUnassemble`:
- Try parsing the arguments as a range first via `parseRange`.
- If `parseRange` succeeds:
  - Set `currentAddr` to `rangeStart`.
  - Set `DebugTemp` (the row counter) to `$FF` (sentinel to use range check).
- If it fails:
  - Reset to parse a single hex argument.
  - If a single address is parsed:
    - Set `currentAddr` to `HexVal`.
    - Set `DebugTemp` to 16 (default rows).
  - If no arguments:
    - Keep current `currentAddr`.
    - Set `DebugTemp` to 16 (default rows).

In the row loop of `cmdDump`:
- After advancing `currentAddr` by 8, check if `DebugTemp` is `$FF`.
- If it is `$FF`, branch to a check: `currentAddr` vs `rangeEnd`.
  - If `currentAddr` <= `rangeEnd` (inclusive check), loop again.
  - Otherwise, exit.

This mirrors the robust, tested disassembly range loop logic in `cmdUnassemble`.

## Verification Plan

### Manual Verification
1. Build the updated debug utility using `make`.
2. Boot into the OS and launch `debug`.
3. Verify Uppercase `L` parsing:
   - `-F 4000 L 10 AA` (using uppercase `L`).
   - `-D 4000` -> Verify range filled with `AA`.
4. Verify Dump range/length commands:
   - `-D 4000 4003` -> Should dump exactly 1 row (covering 4000-4007).
   - `-D 4000 L 10` -> Should dump exactly 2 rows (covering 4000-400F).
   - `-D 4000` -> Should dump exactly 16 rows (default 128 bytes).

## Progress
- [ ] Implement uppercase `L` fix in `parseRange`
- [ ] Refactor `cmdDump` to parse and enforce ranges
- [ ] Verify fix in build
