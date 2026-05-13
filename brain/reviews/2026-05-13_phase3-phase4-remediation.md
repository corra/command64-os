# Code Review: Phase 3 & 4 — File System & External Utilities

**Date:** 2026-05-13
**Status:** remediation-pending

## Scope
Review of Phase 3 (Handle-based I/O) and Phase 4 (DEBUG utility) implementations against MS-DOS specification and C64 hardware constraints.

| File | Role |
|------|------|
| `src/command64/shell.asm` | Internal commands (`COPY`, `TYPE`, `REN`, `DEL`) |
| `src/command64/api.asm` | DOS Service Bus (Handle I/O dispatch) |
| `src/command64/file.asm` | Handle Table and KERNAL File primitives |
| `src/command64/path.asm` | Extension appending logic |
| `src/external/debug/debug.asm` | External Debugger/Monitor |

## Findings Scorecard

| ID | File | Severity | Issue | Impact | Fix | Risk |
|----|------|----------|-------|--------|-----|------|
| **C1** | `shell.asm` | **Critical** | `COPY` handle leak on failure | Prevents subsequent file opens; locks disk channel | Load `SrcHandle` (not `TempLo`) for close | Low |
| **C2** | `api.asm` | **Major** | `ahExit` stack leak | Crash after ~120 executions (stack overflow) | `ldx #$FF; txs` before jump | Low |
| **C3** | `debug.asm` | **Critical** | Hex parsing fails for shifted letters | `D C000` (shifted C) results in `error` | `ora #$20` after `and #$7F` or handle both cases | Low |
| **C4** | `file.asm` | **Critical** | I/O channel lock on error | System hangs/locks keyboard on read/write error | `jsr KernalCLRCHN` in error handlers | Medium |
| **M1** | `path.asm` | **Major** | Filename buffer overflow | Corrupts code/memory if path > 75 chars | Add `cpy #75; bcs` length check | Low |
| **M2** | `file.asm` | **Major** | `FileScratch` overflow risk | Buffer overflow (64 bytes) on long paths | Increment `FileScratch` size or add bounds checks | Medium |

## Detailed Analysis

### C1: `COPY` Handle Leak
In `shell.asm`, the error path `ccCloseSrcErr` loads the handle from `TempLo`. However, the `DOS_OPEN_FILE` API returns the handle in `A`, and the shell immediately stores it in `SrcHandle`. `TempLo` is likely clobbered or contains stale data. Failing to close the source handle when the destination fails will eventually exhaust the Handle Table and LFNs.

### C2: `ahExit` Stack Growth
Programs call `DOS_EXIT` via a jump to the API stub. Since the shell entered the program via `JSR UserProgStart`, and the program likely called the API via `JSR $1000`, there are multiple return addresses on the stack. Jumping directly to `mainLoop` orphans these bytes.

### C3: `DEBUG` Hex Parsing
The `DEBUG` utility uses `and #$7F` to convert shifted PETSCII to unshifted. This turns `$C3` (shifted C) into `$43` ('C'). However, the subsequent parsing logic expects lowercase 'a'-'f' ($61-$66). The routine must normalize to one case or allow both.

### C4: KERNAL Channel Lock
In `fileRead` and `fileWrite`, `KernalCHKIN` or `KernalCHKOUT` is used to redirect I/O. If these fail, or if a `KernalREADST` check triggers an error exit, the routine must call `KernalCLRCHN` to restore I/O to the keyboard/screen. Failure to do so leaves the system in a state where keyboard input is redirected to a non-existent or failed file channel.

## Overall Assessment
The system is functionally rich but suffers from several "lifecycle" bugs where error states or repeated executions lead to instability. Remediation is required to ensure the system meets production-grade reliability.
