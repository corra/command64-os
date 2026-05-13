# Code Review Remediation — Build 2413 Implementation Plan

> **Sync note:** This file is mirrored at `brain/plans/2026-05-13-code-review-remediation.md`.
> Both copies must be kept identical. Edit both or neither.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remediate all bugs and cleanup items found in the Build 2413 code review across `shell.asm`, `debug.asm`, `path.asm`, `vmm.asm`, `loader.asm`, and `utils.asm`.

**Architecture:** Six independent fix groups, ordered by severity. Each task touches one or two files and can be built and verified independently. There is no automated test framework — verification is a manual KickAssembler build followed by VICE emulator smoke-test for the affected feature.

**Tech Stack:** KickAssembler 5.25, 6502/6510 assembly, VICE C64 emulator, PETSCII encoding

---

## Related Plan

`brain/plans/2026-05-13_remediation-pass.md` (Gemini companion agent) covers four additional bugs
found independently, **not duplicated here**:

| ID | Bug | File |
|----|-----|------|
| C2 | `ahExit` leaks the return stack — crashes after ~120 external command runs | `api.asm` |
| C4 | `frError`/`fwError` exit without calling `KernalCLRCHN` — locks I/O channel | `file.asm` |
| M1 | `ffAppendPrg` has no length check — long filenames corrupt memory past NamePtr | `path.asm` |
| M2 | `FileScratch` (64 bytes) too small for long `R:new=old` rename strings | `vmm.asm` |

Both plans should be executed before declaring this remediation complete.

---

## Build Command Reference

**Main OS:**
```bash
java -jar tools/KickAss.jar build/command64.asm -odir build/
```
Expected output on success: `... Writing file : build/command64.prg`

**Debug external app:**
```bash
java -jar tools/KickAss.jar src/external/debug/debug.asm -odir build/
```
Expected output on success: `... Writing file : build/debug.prg`

Any error line containing `Error` or `at line` means the build failed — fix before continuing.

---

## File Map

| File | Changes |
|------|---------|
| `src/command64/shell.asm` | Task 1 (ccCloseSrcErr), Task 5 (dead string, dead instruction, help text) |
| `src/external/debug/debug.asm` | Task 2 (parseHexArg, dispatch case), Task 5 (duplicate verMsg) |
| `src/command64/path.asm` | Task 3 (LFN 14 for checkExistence) |
| `src/command64/vmm.asm` | Task 4 (zero-size guard) |
| `src/command64/loader.asm` | Task 5 (remove PetLl) |
| `src/command64/utils.asm` | Task 5 (normalizeName contract comment) |
| `CHANGELOG.md` | Updated every task |

---

## Task 1: Fix `ccCloseSrcErr` Handle Leak — `shell.asm`

**Severity: High** — The COPY command leaks the source file handle every time the destination open fails.

**Root cause:** `ccCloseSrcErr` loads `TempLo` ($64) to close the source file, but `TempLo` at that point holds the last byte index from the DestBuf copy scan. The actual source handle lives in `SrcHandle` ($6E).

**Files:**
- Modify: `src/command64/shell.asm` at `ccCloseSrcErr` (~line 891)
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Locate the bug**

Open `src/command64/shell.asm`. Find the label `ccCloseSrcErr` (search for it). The current code is:

```asm
ccCloseSrcErr:
    lda TempLo
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr apiHandler
    jmp ccOpenErr
```

- [ ] **Step 2: Apply the one-line fix**

Replace `lda TempLo` with `lda SrcHandle`. The corrected block:

```asm
ccCloseSrcErr:
    lda SrcHandle           // Source handle (not TempLo — TempLo holds scan index here)
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr apiHandler
    jmp ccOpenErr
```

- [ ] **Step 3: Build the OS**

```bash
java -jar tools/KickAss.jar build/command64.asm -odir build/
```

Expected: clean build, `Writing file : build/command64.prg`. Fix any assembler errors before proceeding.

- [ ] **Step 4: Smoke-test COPY error path in VICE**

Load `command64.prg` in VICE. At the `C64:>` prompt:

1. `copy nonexistent.prg dest.prg` — should print `Load error` (destination of a nonexistent source triggers the open-source error path, not ccCloseSrcErr, but verifies COPY doesn't crash).
2. `copy hello.prg /invalid` — triggers the destination-open failure path. Verify the shell returns to the prompt cleanly with no hang or crash. (Exact error message is `Load error`.)

- [ ] **Step 5: Update CHANGELOG.md**

Add under the `[Unreleased]` section:

```
### Fixed
- shell: COPY command no longer leaks source file handle when destination OPEN fails
  (`ccCloseSrcErr` now reads `SrcHandle` instead of `TempLo`)
```

- [ ] **Step 6: Commit**

```bash
git add src/command64/shell.asm CHANGELOG.md
git commit -m "fix(shell): use SrcHandle in ccCloseSrcErr to prevent handle leak on COPY error"
```

---

## Task 2: Fix `parseHexArg` and `dispatch` in `debug.asm`

**Severity: Medium** — Three related issues in the debug external app:
1. Uppercase A–F hex digits ($41–$46, produced by SHIFT+letter in lowercase mode) are rejected.
2. `parseHexArg` has no digit-count limit — more than 4 hex digits silently overflows `HexValHi`.
3. `dispatch` case conversion uses `and #$7F` which has no effect on unshifted uppercase ($41–$5A), so SHIFT+letter commands are silently rejected as unknown.

**Background on PETSCII:** command64 runs in lowercase mode (after `CHR$(14)`). In this mode, regular letter keys produce lowercase PETSCII ($61–$7A). SHIFT+letter produces uppercase ($41–$5A). The existing `and #$7F` was intended to handle shifted PETSCII ($C1–$DA, the "uppercase mode" equivalents), but those values are already rejected by `cmp #'Z'+1` before reaching the `and`. The conversion is a no-op for its intended range and wrong for the actual range.

**Files:**
- Modify: `src/external/debug/debug.asm`
- Modify: `CHANGELOG.md`

### 2a: Fix `parseHexArg` — uppercase A–F and digit-count limit

- [ ] **Step 1: Locate parseHexArg in debug.asm**

Search for `parseHexArg:` in `src/external/debug/debug.asm`. The block to replace begins after the `cmp #'9' + 1; bcc phDigit` check and ends before `phDigit:`. The current code is:

```asm
    // Convert shifted to unshifted
    cmp #'A'
    bcc phInvalid
    cmp #'Z' + 1
    bcs phInvalid
    and #$7F                // To unshifted

    cmp #'a'
    bcc phInvalid
    cmp #'f' + 1
    bcs phInvalid
    sec
    sbc #('a' - 10)
    jmp phAdd
phDigit:
    sec
    sbc #'0'

phAdd:
    pha                     // Save digit
    // HexVal = HexVal * 16
    lda HexValLo
    asl
    rol HexValHi
    asl
    rol HexValHi
    asl
    rol HexValHi
    asl
    rol HexValHi
    sta HexValLo

    pla                     // Restore digit
    ora HexValLo
    sta HexValLo
    inx
    iny
    jmp phLoop
```

- [ ] **Step 2: Replace that block with the fixed version**

```asm
    // Check A-F: SHIFT+letter in lowercase mode produces $41-$46
    cmp #'A'                // $41
    bcc phInvalid
    cmp #'F' + 1            // $47
    bcc phUpperHex

    // Check a-f: $61-$66
    cmp #'a'                // $61
    bcc phInvalid
    cmp #'f' + 1            // $67
    bcs phInvalid
    sec
    sbc #('a' - 10)         // $61→10, $62→11, ..., $66→15
    jmp phAdd
phUpperHex:
    sec
    sbc #('A' - 10)         // $41→10, $42→11, ..., $46→15
    // fall through to phAdd
phDigit:
    sec
    sbc #'0'

phAdd:
    pha                     // Save digit
    // HexVal = HexVal * 16
    lda HexValLo
    asl
    rol HexValHi
    asl
    rol HexValHi
    asl
    rol HexValHi
    asl
    rol HexValHi
    sta HexValLo

    pla                     // Restore digit
    ora HexValLo
    sta HexValLo
    cpx #4
    beq phInvalid           // reject more than 4 hex digits (16-bit limit)
    inx
    iny
    jmp phLoop
```

### 2b: Fix `dispatch` case conversion

- [ ] **Step 3: Locate the case conversion block in dispatch**

Search for `dNotLetter` in `src/external/debug/debug.asm`. The current block is:

```asm
    cmp #'A'
    bcc dNotLetter
    cmp #'Z' + 1
    bcs dNotLetter
    and #$7F                // Shifted ($C1) -> Unshifted ($41)
dNotLetter:
```

- [ ] **Step 4: Replace `and #$7F` with `ora #$20`**

```asm
    cmp #'A'
    bcc dNotLetter
    cmp #'Z' + 1
    bcs dNotLetter
    ora #$20                // uppercase ($41-$5A) → lowercase ($61-$7A)
dNotLetter:
```

`ora #$20` sets bit 5, converting any $41–$5A to $61–$7A, matching the lowercase command comparisons that follow.

- [ ] **Step 5: Build debug**

```bash
java -jar tools/KickAss.jar src/external/debug/debug.asm -odir build/
```

Expected: clean build, `Writing file : build/debug.prg`.

- [ ] **Step 6: Smoke-test in VICE**

Load `debug.prg` from the command64 shell (`load debug`). At the `-` prompt:

1. Type `D 1000` (lowercase) — should dump 128 bytes starting at $1000.
2. Type `D` then SHIFT+D (which sends $44, i.e., 'D') — should also dump memory (verifies uppercase dispatch works).
3. Type `E 2100 41 42 43` — enter three bytes at $2100.
4. Type `E 2100 4142434445464748` (8+ hex digits) — should print `error` (digit-count limit).
5. Type `H 1000 0100` — should print `1100  0F00` (sum and difference).
6. Type `H 1000 010` with SHIFT+'A' for the A in 010A → should accept A-F via SHIFT+letter.

- [ ] **Step 7: Update CHANGELOG.md**

```
### Fixed
- debug: parseHexArg now accepts uppercase A-F (SHIFT+letter in lowercase mode, $41-$46)
- debug: parseHexArg rejects input longer than 4 hex digits to prevent HexVal overflow
- debug: dispatch case conversion corrected (ora #$20 instead of and #$7F) so SHIFT+letter
  commands are recognized
```

- [ ] **Step 8: Commit**

```bash
git add src/external/debug/debug.asm CHANGELOG.md
git commit -m "fix(debug): accept uppercase A-F hex input, add digit limit, fix dispatch case conversion"
```

---

## Task 3: Fix LFN 2 Conflict in `checkExistence` and `cmdDir`

**Severity: Low** — `checkExistence` in `path.asm` opens files using LFN 2, which is also the LFN pre-assigned to Handle 0 in the handle table, and is also used directly by `cmdDir`. If Handle 0 is open when `checkExistence` is called, the KERNAL rejects the duplicate LFN and `checkExistence` falsely reports "not found."

**Fix:** Assign LFN 14 to `checkExistence` and LFN 13 to `cmdDir`. LFNs 2–9 are reserved for the handle table, LFN 15 for the command channel — 10–14 are unused.

**Files:**
- Modify: `src/command64/path.asm`
- Modify: `src/command64/shell.asm` (cmdDir section only)
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Fix checkExistence in path.asm**

Find `checkExistence:` in `src/command64/path.asm`. Replace the `KernalSETLFS` and `KernalCLOSE` calls:

```asm
// Before:
    lda #2                  // File number 2
    ldx #8                  // Device 8
    ldy #0                  // Secondary address 0 (Read)
    jsr KernalSETLFS
    
    jsr KernalOPEN
    
    php
    lda #2
    jsr KernalCLOSE
    plp
    rts
```

```asm
// After:
    lda #14                 // LFN 14 — avoids handle table LFNs (2-9) and command channel (15)
    ldx #8                  // Device 8
    ldy #0                  // Secondary address 0 (Read)
    jsr KernalSETLFS
    
    jsr KernalOPEN
    
    php
    lda #14
    jsr KernalCLOSE
    plp
    rts
```

- [ ] **Step 2: Fix cmdDir in shell.asm**

Find `cmdDir:` in `src/command64/shell.asm`. Replace all three occurrences of the hard-coded file number 2:

```asm
// Before:
    lda #2                  // File 2
    ldx #8                  // Device 8
    ldy #0                  // Secondary 0
    jsr KernalSETLFS
    
    jsr KernalOPEN
    bcs cdDevError
    
    ldx #2
    jsr KernalCHKIN
    ...
cdDone:
    jsr KernalCLRCHN
    lda #2
    jsr KernalCLOSE
```

```asm
// After:
    lda #13                 // LFN 13 — avoids handle table LFNs (2-9), checkExistence (14), cmd channel (15)
    ldx #8                  // Device 8
    ldy #0                  // Secondary 0
    jsr KernalSETLFS
    
    jsr KernalOPEN
    bcs cdDevError
    
    ldx #13
    jsr KernalCHKIN
    ...
cdDone:
    jsr KernalCLRCHN
    lda #13
    jsr KernalCLOSE
```

- [ ] **Step 3: Build the OS**

```bash
java -jar tools/KickAss.jar build/command64.asm -odir build/
```

Expected: clean build. Fix any errors before proceeding.

- [ ] **Step 4: Smoke-test DIR in VICE**

At the `C64:>` prompt, type `dir`. Verify the directory listing appears correctly. Then type `load hello` to confirm file loading (which triggers `checkExistence`) still works.

- [ ] **Step 5: Update CHANGELOG.md**

```
### Fixed
- path: checkExistence uses LFN 14 instead of LFN 2 to prevent conflict with handle table slot 0
- shell: cmdDir uses LFN 13 instead of LFN 2 for the same reason
```

- [ ] **Step 6: Commit**

```bash
git add src/command64/path.asm src/command64/shell.asm CHANGELOG.md
git commit -m "fix(fs): assign dedicated LFNs to checkExistence (14) and cmdDir (13)"
```

---

## Task 4: Fix `vmmAlloc` Zero-Paragraph Edge Case — `vmm.asm`

**Severity: Low** — A zero-paragraph request yields `TempHi = 0`. The commit step then executes `ldx #0; dex` → X=$FF, marking 255 spurious tail pages in the MCT. In practice this is never called with zero, but the guard costs 4 bytes and eliminates a latent corruption risk.

**Files:**
- Modify: `src/command64/vmm.asm`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Locate vmmAlloc in vmm.asm**

Find `vaInitOk:` in `src/command64/vmm.asm`. The current code immediately begins the round-up calculation:

```asm
vaInitOk:
    // 1. Round up paragraphs to pages (1 page = 256 paragraphs = $0100)
    // PageCount = (Paragraphs + 255) >> 8
    lda VmmSegLo
    clc
    adc #$FF
```

- [ ] **Step 2: Insert the zero-size guard**

```asm
vaInitOk:
    // Guard: zero-paragraph request is invalid (commit logic would underflow)
    lda VmmSegLo
    ora VmmSegHi
    beq vaZeroErr

    // 1. Round up paragraphs to pages (1 page = 256 paragraphs = $0100)
    // PageCount = (Paragraphs + 255) >> 8
    lda VmmSegLo
    clc
    adc #$FF
```

- [ ] **Step 3: Add the error label**

The `vaZeroErr` label must be placed so that execution doesn't fall through into it. Insert it before `vaNoMem:` (which already exists and returns `VMM_ERR_NOMEM`). Add just before `vaNoMem:`:

```asm
vaZeroErr:
    lda #VMM_ERR_INVALID
    rts
vaNoMem:
    lda #VMM_ERR_NOMEM
    rts
```

- [ ] **Step 4: Build the OS**

```bash
java -jar tools/KickAss.jar build/command64.asm -odir build/
```

Expected: clean build.

- [ ] **Step 5: Update CHANGELOG.md**

```
### Fixed
- vmm: vmmAlloc returns VMM_ERR_INVALID for zero-paragraph requests instead of
  corrupting 255 MCT tail entries
```

- [ ] **Step 6: Commit**

```bash
git add src/command64/vmm.asm CHANGELOG.md
git commit -m "fix(vmm): guard vmmAlloc against zero-paragraph request to prevent MCT corruption"
```

---

## Task 5: Cleanup — Dead Code, Help Text, PetLl, and Docs

**Severity: Low / Style** — Six independent cleanup items. Apply all in a single pass, then build and commit together.

**Files:**
- Modify: `src/command64/shell.asm` (3 items)
- Modify: `src/external/debug/debug.asm` (1 item)
- Modify: `src/command64/loader.asm` (1 item)
- Modify: `src/command64/utils.asm` (1 item)
- Modify: `CHANGELOG.md`

### Item A — Remove dead `dirStubMsg` string (`shell.asm`)

- [ ] **Step 1: Find and delete dirStubMsg**

In `src/command64/shell.asm`, find and remove this block (it is never referenced since `cmdDir` is fully implemented):

```asm
dirStubMsg:
    .text "Directory listing not yet implemented"
    .byte $0D, 0
```

### Item B — Add ERASE and RENAME to helpMsg (`shell.asm`)

- [ ] **Step 2: Extend helpMsg to list aliases**

In `src/command64/shell.asm`, find `helpMsg:`. The current block ends with:

```asm
    .text "REN    - RENAME [OLD] [NEW]"
    .byte $0D
    .text "VER    - SHOW VERSION"
    .byte $0D, 0
```

Replace with:

```asm
    .text "REN    - RENAME [OLD] [NEW]"
    .byte $0D
    .text "RENAME - ALIAS FOR REN"
    .byte $0D
    .text "ERASE  - ALIAS FOR DEL"
    .byte $0D
    .text "VER    - SHOW VERSION"
    .byte $0D, 0
```

### Item C — Remove dead `lda #DOS_OPEN_FILE` in cmdType (`shell.asm`)

- [ ] **Step 3: Remove the orphaned lda**

In `src/command64/shell.asm`, find `cmdType:`. The open-file setup block currently has a dead first instruction:

```asm
    // Open file
    lda #0
    sta HexValLo            // Read mode
    lda #DOS_OPEN_FILE      // <-- DEAD: immediately overwritten below
    ldx #<CommandBuffer
    stx NamePtrLo           // Use ZP to compute absolute addr
    lda NamePtrLo
    clc
    adc TempLo
    tax                     // X = Lo byte of filename
    lda #>CommandBuffer
    adc #0
    tay                     // Y = Hi byte of filename
    lda #DOS_OPEN_FILE
    jsr apiHandler
```

Remove the orphaned `lda #DOS_OPEN_FILE` (the first one, line ~543):

```asm
    // Open file
    lda #0
    sta HexValLo            // Read mode
    ldx #<CommandBuffer
    stx NamePtrLo           // Use ZP to compute absolute addr
    lda NamePtrLo
    clc
    adc TempLo
    tax                     // X = Lo byte of filename
    lda #>CommandBuffer
    adc #0
    tay                     // Y = Hi byte of filename
    lda #DOS_OPEN_FILE
    jsr apiHandler
```

### Item D — Deduplicate verMsg/startupMsg in debug.asm

- [ ] **Step 4: Point verMsg at startupMsg**

In `src/external/debug/debug.asm`, find the data section. Currently:

```asm
startupMsg:
    .text "DEBUG v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
    .text " (Build " + BUILD_NUMBER + ")"
    .byte $0D, 0

verMsg:
    .text "DEBUG v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
    .text " (Build " + BUILD_NUMBER + ")"
    .byte $0D, 0
```

Replace with (point verMsg at startupMsg to share the same bytes):

```asm
startupMsg:
verMsg:
    .text "DEBUG v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
    .text " (Build " + BUILD_NUMBER + ")"
    .byte $0D, 0
```

### Item E — Remove spurious PetLl output in loader.asm

- [ ] **Step 5: Remove the PetLl output from shellLoadPrg**

In `src/command64/loader.asm`, the loading message prints a CR then an unexpected line feed:

```asm
    lda #<loadingMsg
    ldy #>loadingMsg
    jsr petPrintString
    lda #PetCr
    jsr KernalChROUT
    lda #PetLl              // <-- REMOVE: $0A is not a standard C64 screen-editor code
    jsr KernalChROUT
```

Remove the two `PetLl` lines:

```asm
    lda #<loadingMsg
    ldy #>loadingMsg
    jsr petPrintString
    lda #PetCr
    jsr KernalChROUT
```

### Item F — Document normalizeName return contract (`utils.asm`)

- [ ] **Step 6: Add Y = length to normalizeName function header**

In `src/command64/utils.asm`, find the `normalizeName` block comment. The current header is:

```asm
// --- normalizeName ---
// Converts a string to lowercase PETSCII ($41-$5A).
// Input:  A = low byte of string pointer
//         Y = high byte of string pointer
//         X = string length
// Clobbers: A, Y, PrintPtrLo/Hi
```

Replace with:

```asm
// --- normalizeName ---
// Converts a string to lowercase PETSCII ($41-$5A).
// Input:  A = low byte of string pointer
//         Y = high byte of string pointer
//         X = string length
// Output: Y = string length (loop exits when Y == TempLo == input X)
//         X = preserved (unchanged — callers may use it after the call)
// Clobbers: A, TempLo, PrintPtrLo/Hi
```

### Build and commit all cleanup items

- [ ] **Step 7: Build OS (covers all shell.asm, loader.asm, utils.asm changes)**

```bash
java -jar tools/KickAss.jar build/command64.asm -odir build/
```

Expected: clean build.

- [ ] **Step 8: Build debug (covers debug.asm change)**

```bash
java -jar tools/KickAss.jar src/external/debug/debug.asm -odir build/
```

Expected: clean build.

- [ ] **Step 9: Smoke-test in VICE**

1. `help` — output must include `RENAME - ALIAS FOR REN` and `ERASE - ALIAS FOR DEL`.
2. `type hello.prg` — file contents print without crash (dead-instruction removal in cmdType).
3. `load hello` — "loading..." appears with a single blank line, no double-scroll (PetLl removed).
4. In debug: `v` — version string appears once (shared startupMsg/verMsg).

- [ ] **Step 10: Update CHANGELOG.md**

```
### Changed
- shell: helpMsg now lists RENAME and ERASE as aliases
- shell: removed unreferenced dirStubMsg string (saves ~42 bytes)
- shell: removed dead `lda #DOS_OPEN_FILE` in cmdType setup
- debug: verMsg and startupMsg now share a single string literal
- loader: removed spurious PetLl ($0A) after loading message
- utils: normalizeName header documents Y=length return value and X-preserved guarantee
```

- [ ] **Step 11: Commit**

```bash
git add src/command64/shell.asm src/external/debug/debug.asm src/command64/loader.asm src/command64/utils.asm CHANGELOG.md
git commit -m "chore: cleanup dead code, fix help text aliases, document normalizeName contract"
```

---

## Summary

| Task | Severity | Files | Risk |
|------|----------|-------|------|
| 1 — ccCloseSrcErr handle leak | High | shell.asm | One-line, isolated |
| 2 — debug parseHexArg + dispatch | Medium | debug.asm | Self-contained in debug |
| 3 — LFN conflict | Low | path.asm, shell.asm | Constant changes only |
| 4 — vmmAlloc zero guard | Low | vmm.asm | Additive guard |
| 5 — Cleanup (6 items) | Style | 4 files | All cosmetic/docs |

Total changed lines: ~30 across 6 source files. All changes are isolated to their respective modules with no cross-module dependencies.
