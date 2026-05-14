# Plan: Fix Environment Variable Hang and Path Command

## Objective
Fix the hang occurring during `set var=val` operations and correct the broken `path` command implementation.

## Background & Root Cause
1. **Hang in `set`**: The `envDelete` and `envFindEnd` functions in `src/command64/shell.asm` rely on finding a double-null (`\0\0`) to identify the end of the environment block. Since the REU memory is not zeroed upon initialization, these functions can wander into garbage memory, leading to an infinite loop or an extremely long "hang" as they process 64KB (or more) of REU data byte-by-byte.
2. **`path` command bugs**: 
    - `cmdPath` jumps to `csFoundEq` without initializing `X`, which is used as an index for `SourceBuf`.
    - `csFoundEq` expects to skip an `=` character, but the `path` command doesn't use one (e.g., `path C:\` vs `set path=C:\`), causing it to skip the first character of the path value.
    - `ParsePos` is not correctly updated in `cmdPath`.

## Proposed Changes

### 1. Initialization (`src/command64/shell.asm`)
- Zero out the entire 4KB environment segment during shell initialization. This ensures that `env*` functions always encounter a double-null at the end of the valid environment data.

### 2. `path` Command Refactoring (`src/command64/shell.asm`)
- Update `cmdPath` to correctly initialize `SourceBuf` with "path\0".
- Set `X` to 4.
- Update `ParsePos` to the start of the path value.
- Correctly branch to either `envSearch` (to check for/delete old value) and then `csCheckAppend`.

### 3. Environment Variable Case Normalization
- Ensure that the "path" variable name used by `cmdPath` matches the case expected by `cmdSet` (which normalizes to unshifted/lowercase PETSCII).

## Verification Plan

### Manual Verification
1. **Empty Environment**: Run `set` and `path` on a fresh boot. `set` should show nothing, `path` should say "Environment variable not defined".
2. **Setting Variables**: 
    - Run `set TEST=123`. It should return immediately.
    - Run `set` to verify `TEST=123` is displayed.
    - Run `set TEST=`. It should delete the variable.
3. **Path Command**:
    - Run `path C:\DOS`. It should return immediately.
    - Run `path` to verify it displays the path.
    - Run `set` to verify `path=C:\DOS` is in the environment.
4. **Variable Replacement**:
    - Run `set TEST=AAA`.
    - Run `set TEST=BBB`.
    - Verify `set` shows `TEST=BBB` and NOT `TEST=AAA`.
