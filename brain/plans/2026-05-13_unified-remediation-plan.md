# Unified Implementation Plan: Phase 3 & 4 Remediation (Build 2413)

**Goal:** Consolidate and remediate all critical, major, and cleanup items identified in the Build 2413 code reviews from both Gemini and Claude agents.

**Status:** Implemented & Built — Awaiting Manual VICE Verification

---

## 1. Executive Summary of Bugs

This unified plan addresses the following issues across the MS-DOS C64 port:

| ID | Severity | Issue | File(s) | Impact |
|:---|:---|:---|:---|:---|
| **C1** | Critical | `COPY` Handle Leak | `shell.asm` | Exhausts LFNs; prevents subsequent opens. |
| **C2** | Major | `ahExit` Stack Leak | `api.asm` | Stack overflow/crash after ~63 program runs. |
| **C3** | Critical | `DEBUG` Hex Parsing Failure | `debug.asm` | Rejects shifted/uppercase A-F input. |
| **C4** | Defensive | I/O Channel Recovery | `file.asm` | `frError`/`fwError` reached before CHKIN/CHKOUT sets channel — no actual lock. Defensive guard only. |
| **C5** | Major | LFN 2 Conflict | `path.asm`, `shell.asm` | `DIR` or `LOAD` fails if Handle 0 is open. |
| **C6** | Major | `vmmAlloc` Zero Guard | `vmm.asm` | 0-paragraph request corrupts 255 MCT entries. |
| **M1** | Major | Filename Buffer Overflow | `path.asm` | Corruption if path + ".prg" > 80 bytes. |
| **M2** | Major | `FileScratch` Size Risk | `vmm.asm` | Buffer overflow on long Rename/Delete strings. |
| **U1** | Style | Cleanup & Dead Code | Multiple | Code bloat and confusing documentation. |

---

## 2. Proposed Remediations

### Group 1: OS Core & Stability

#### Task 1.1: Fix `COPY` Handle Leak (`shell.asm`)
- **Fix:** Update `ccCloseSrcErr` to load `SrcHandle` (ZP $6E) instead of `TempLo`.
- **Reason:** `TempLo` is clobbered during the copy scan; the actual handle was saved in `SrcHandle`.

#### Task 1.2: Prevent `ahExit` Stack Growth (`api.asm`)
- **Fix:** Add `ldx #$FF; txs` before the `jmp mainLoop` in `ahExit`.
- **Reason:** Each `DOS_EXIT` call orphans 4 bytes on the stack — 2 from `jsr UserProgStart` and 2 from the program's own `jsr $1000`. The 256-byte stack overflows after ~63 program runs. Resetting SP to $FF on every exit is safe for this single-threaded OS.

#### Task 1.3: I/O Channel Recovery (`file.asm`) *(Defensive)*
- **Fix:** Add `jsr KernalCLRCHN` to the `frError` and `fwError` paths in `fileRead` and `fileWrite`.
- **Reason:** Both error labels are only reachable *before* `KernalCHKIN`/`KernalCHKOUT` has set a channel (handle-not-open path or CHKIN/CHKOUT failure, which is atomic). The normal exit paths (`frDone`/`fwDone`) already call `KernalCLRCHN`. There is no confirmed lock condition in current code — this is a defensive guard against future code changes adding paths to these labels after a channel is set.

#### Task 1.4: LFN De-confliction (`path.asm`, `shell.asm`)
- **Fix:** 
  - `path.asm`: Change `checkExistence` to use LFN 14.
  - `shell.asm`: Change `cmdDir` to use LFN 13.
- **Reason:** LFN 2 is reserved for Handle Table Slot 0.

### Group 2: Memory & Buffer Safety

#### Task 2.1: `vmmAlloc` Zero-Size Guard (`vmm.asm`)
- **Fix:** Add `ora VmmSegHi; beq vaZeroErr` at the start of `vaInitOk`. Return `VMM_ERR_INVALID`.
- **Reason:** Prevents `ldx #0; dex` underflow which corrupts 255 pages of MCT.

#### Task 2.2: Secure Filename Processing (`path.asm`, `vmm.asm`)
- **Fix:**
  - `path.asm`: Add `cpy #77; bcs ffNotFound` in `ffAppendPrg` before the first write.
  - `vmm.asm`: Increase `fileScratch` from 64 to 96 bytes.
- **Reason:** Prevents buffer overflows on long filenames or complex rename strings (`R:new=old`).

### Group 3: Utility & Logic

#### Task 3.1: Fix `DEBUG` Hex Parsing & Dispatch (`debug.asm`)
- **Fix:**
  - `parseHexArg`: Support shifted letters ($41-$46) and add a 4-digit limit.
  - `dispatch`: Change `and #$7F` to `ora #$20` for case normalization.
- **Reason:** Shifted letters (SHIFT+A-F) were being rejected; dispatch was failing for shifted command keys.

#### Task 3.2: General Cleanup
- **Fixes:**
  - `shell.asm`: Remove dead `dirStubMsg`; Add `ERASE`/`RENAME` aliases to `helpMsg`; Remove redundant `lda #DOS_OPEN_FILE` in `cmdType`.
  - `loader.asm`: Remove spurious `PetLl` ($0A) after loading message.
  - `debug.asm`: Deduplicate `verMsg` and `startupMsg`.
  - `utils.asm`: Update `normalizeName` header to document Y=length return.

---

## 3. Implementation Sequence

### Phase 1: Safety & Buffer Hardening
1. Update `vmm.asm` (`fileScratch` size and `vmmAlloc` guard).
2. Update `path.asm` (LFN change and length check).
3. Update `file.asm` (I/O recovery).

### Phase 2: Shell & API Logic
1. Update `shell.asm` (`COPY` fix, LFN change, cleanup).
2. Update `api.asm` (`ahExit` fix).

### Phase 3: External Utilities
1. Update `debug.asm` (Hex parsing, dispatch, deduplication).
2. Update `loader.asm` (PetLl removal).

---

## 4. Verification Plan

### Automated Build
- Run `java -jar tools/KickAss.jar build/command64.asm -odir build/`
- Run `java -jar tools/KickAss.jar src/external/debug/debug.asm -odir build/`

### Manual Smoke Tests
1. **LFN Conflict:** Open a file (e.g., `TYPE hello.prg`), and while it's open (simulated or via code), run `DIR`.
2. **Handle Leak:** Perform `COPY hello.prg /invalid` 10 times; then verify `DIR` still works.
3. **Stack Leak:** Run a small external app (e.g., `hello`) 70 times via DOS_EXIT. Shell must remain stable.
4. **Hex Case:** In `DEBUG`, type `d c000` and `D C000` (shifted). Both must work.
5. **Buffer Overrun:** Type `LOAD` followed by 80 characters. Shell should not crash.
