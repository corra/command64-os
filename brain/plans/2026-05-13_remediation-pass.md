# Implementation Plan: Phase 3 & 4 Remediation (Lifecycle & Buffer Safety)

This plan addresses several critical and major bugs identified in the Phase 3 (File System) and Phase 4 (DEBUG Utility) implementations.

## Objective
Remediate handle leaks, stack leaks, I/O channel locking, and buffer overflow risks to ensure system stability and reliability.

## Classification of Bugs

| ID | File | Severity | Description | Impact | Potential Risk |
|----|------|----------|-------------|--------|----------------|
| **C1** | `shell.asm` | **Critical** | `COPY` handle leak on destination failure | Prevents subsequent file opens; exhausts LFNs | Low |
| **C2** | `api.asm` | **Major** | `ahExit` stack leak | Crash after ~120 executions (stack overflow) | Low |
| **C3** | `debug.asm` | **Critical** | Hex parsing fails for shifted letters | Command rejection for valid shifted input | Low |
| **C4** | `file.asm` | **Critical** | I/O channel lock on error | System hang/input lock on disk error | Medium |
| **M1** | `path.asm` | **Major** | Filename buffer overflow in extension appending | Code/data corruption on long input | Low |
| **M2** | `file.asm` | **Major** | `FileScratch` buffer overflow risk | System instability on long path operations | Medium |

## Proposed Solution

### 1. Code Review Documentation
- Create `brain/reviews/2026-05-13_phase3-phase4-remediation.md` to record these findings formally.

### 2. Fix C1: `COPY` Handle Leak (`shell.asm`)
- Update `ccCloseSrcErr` to load `SrcHandle` (ZP $6E) instead of `TempLo`.

### 3. Fix C2: `ahExit` Stack Reset (`api.asm`)
- Update `ahExit` to reset the stack pointer (`ldx #$FF; txs`) before jumping to `mainLoop`.

### 4. Fix C3: `DEBUG` Hex Parsing (`debug.asm`)
- Update `phLoop` in `parseHexArg` to correctly handle both uppercase/shifted and lowercase letters.

### 5. Fix C4: I/O Channel Recovery (`file.asm`)
- Add `jsr KernalCLRCHN` to the `frError` and `fwError` paths in `fileRead` and `fileWrite`.

### 6. Fix M1/M2: Buffer Safety (`path.asm`, `file.asm`)
- Add length checks in `ffAppendPrg` (`path.asm`).
- Increase `FileScratch` size in `vmm.asm` (or add bounds checks in `file.asm`).

## Implementation Steps

### Phase 1: Documentation & Safety
1. Create the formal review record in `brain/reviews/`.
2. Update `src/command64/vmm.asm` to increase `fileScratch` from 64 to 80 bytes.

### Phase 2: Core OS Fixes
1. Modify `src/command64/shell.asm` to fix the `COPY` handle leak.
2. Modify `src/command64/api.asm` to fix the `ahExit` stack leak.
3. Modify `src/command64/file.asm` to fix the I/O channel locking.
4. Modify `src/command64/path.asm` to add extension length checks.

### Phase 3: Utility Fixes
1. Modify `src/external/debug/debug.asm` to fix hex parsing for shifted characters.
2. Update `DEBUG` version/build info.

## Verification & Testing

### Automated Testing
- Run `tests/build_tests.sh` to verify assembly.
- Run `apitest.prg` and `vmmtest.prg`.

### Manual Testing
- **Handle Leak**: Try to `COPY` with an invalid destination 10 times in a row, then try a successful `TYPE`. If successful, handles are being closed correctly.
- **Stack Leak**: Run a small utility (like `HELLO.PRG`) 130 times. If the shell doesn't crash, the stack is stable.
- **I/O Lock**: Try to `TYPE` a file on a non-existent device (e.g., device 9). If the shell returns to the prompt and accepts keyboard input, the channel was restored.
- **Hex Case**: In `DEBUG`, type `D C000` (using SHIFT+C). It should dump memory.
