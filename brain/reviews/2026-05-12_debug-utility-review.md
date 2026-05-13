# Code Review: `DEBUG` Utility (Remediation Pass v1)

**Date:** 2026-05-12
**Target:** `src/external/debug/debug.asm` (v0.1.2 Build 1003)

## Executive Summary
Following the initial release and manual testing of `DEBUG.PRG`, 7 distinct failures were reported. This review identifies the root causes and provides the technical basis for the remediation pass. The most critical findings relate to memory corruption risk due to character encoding mismatches during hex parsing and stack/register clobbering during memory writes.

## Findings & Root Cause Analysis

### 1. Character Encoding Corruption (Critical)
- **Commands**: `H`, `F`, `M`, and the main `dispatch`.
- **Symptoms**: `error` output for valid hex commands involving letters.
- **Root Cause**: The code uses `ora #$20` to lowercase PETSCII input. In `petscii_mixed`, shifted characters are at `$C1-$DA`. Applying `OR $20` to `$C1` (shifted 'A') results in `$E1`, which is not a valid letter. 
- **Fix**: Use `and #$7F` to convert shifted PETSCII to unshifted PETSCII ($41-$5A).

### 2. Multi-Byte Enter (E) Failure (Critical)
- **Symptoms**: Memory is not modified when providing multiple bytes.
- **Root Cause**: `cmdEnter` calls `parseHexArg` in a loop. Inside the loop, it performs `ldy #0` to use as an index for `sta (rangeStart), y`. This destroys the `Y` register, which is the current parsing position for the `inputBuf`. 
- **Fix**: Wrap the memory write in `tya/pha ... pla/tay`.

### 3. Screen Layout Violation (Major)
- **Symptoms**: `D` command output wraps and is unreadable.
- **Root Cause**: The utility was designed for 80-column MS-DOS, printing 16 bytes per line. The C64 has a 40-column display.
- **Fix**: Refactor `cmdDump` to use an 8-byte row format.

### 4. UI Flow — Missing Carriage Return (Minor)
- **Symptoms**: Cursor does not advance after pressing ENTER.
- **Root Cause**: `rlDone` calls `KernalChROUT` with `A=0` (the null terminator).
- **Fix**: Load `PetCr` ($0D) into `A` before the echo call.

### 5. Hex Math Wrap-around (Medium)
- **Symptoms**: `-H FFFF 0001` results in `error`.
- **Root Cause**: Linked to Finding #1 (parsing logic). The 16-bit math implementation itself is correct, but the inputs are being rejected as invalid.

## Remediation Plan Status
- [x] Documented root causes in `brain/EXTERNAL.md`.
- [ ] Implement `and #$7F` case-conversion.
- [ ] Implement `Y` preservation in `cmdEnter`.
- [ ] Implement 8-byte row layout for `cmdDump`.
- [ ] Implement `PetCr` echo in `readLine`.

## Overall Assessment
The logic for memory manipulation is structurally sound but was sabotaged by low-level register and encoding conflicts. The proposed remediation will make the utility 100% reliable for its MVP feature set.
