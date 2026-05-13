# Implementation Plan: Fix "Load error" and Register Mismatches

## Objective
Resolve persistent "Load error"s in `TYPE` and `COPY` commands caused by incorrect KERNAL API usage and filename casing issues.

## Key Files & Context
- `src/command64/file.asm`: Contains `fileOpen`, `fileRead`, and `fileWrite`.
- `src/command64/utils.asm`: Contains `normalizeName`.

## Root Cause Analysis
1. **Case Sensitivity**: Shell mixed-case produced lowercase filenames; disk drive expects unshifted PETSCII (uppercase).
2. **Register Swap (SETLFS)**: `fileOpen` passed Device (8) in `A` and LFN in `X`. KERNAL expects LFN in `A` and Device in `X`.
3. **Register Mismatch (CHKIN/CHKOUT)**: `fileRead/Write` passed LFN in `A`. KERNAL expects LFN in `X`.
4. **Channel Conflict**: `COPY` used hardcoded Secondary Address 2 for both files.

## Implementation Steps
1. **Fix SETLFS**: Swap `A` and `X` in `fileOpen`.
2. **Fix CHKIN/CHKOUT**: Add `tax` before calling KERNAL routines in `fileRead/Write`.
3. **Normalize Name**: Call `normalizeName` in `fileOpen` to convert input to uppercase.
4. **Unique Channels**: Use LFN as Secondary Address in `SETLFS`.

## Verification & Testing
1. Rebuild `command64.prg`.
2. Execute `TYPE readme.txt` (verify lowercase input works).
3. Execute `COPY src dst` (verify simultaneous files work).
