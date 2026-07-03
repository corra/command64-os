# Code Review Remediation — Full Codebase Sweep (post-license-commit) Implementation Plan

> **Sync note:** This file is mirrored at `brain/plans/2026-07-02-code-review-remediation.md`.
> Both copies must be kept identical. Edit both or neither.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remediate all eight findings (R1–R8) from `brain/reviews/2026-07-02_full-codebase-review.md` across `path.asm`, `shell.asm`, `debug.asm`, `vmm.asm`, and `CMakeLists.txt`.

**Architecture:** Eight independent fix groups, ordered by severity (Blocker → High → Medium → Low), matching the review's Remediation Priority section. Each task touches one file (occasionally two) and can be built and verified independently. There is no automated test framework — verification is a manual KickAssembler build followed by VICE emulator smoke-test for the affected feature.

**Tech Stack:** KickAssembler 5.25, 6502/6510 assembly, VICE C64 emulator, PETSCII encoding, CMake

---

## Source Review

`brain/reviews/2026-07-02_full-codebase-review.md` — full-codebase sweep (not diff-scoped), three parallel finder angles followed by direct-source verification of every candidate. All eight findings were confirmed; none were rejected.

---

## Build Command Reference

**Main OS:**
```bash
cmake --build build --target command64
```
Expected: `Writing prg file: command64.prg`, `Built target command64`.

**Debug external app:**
```bash
cmake --build build --target debug
```
Expected: `Writing prg file: debug.prg`, `Built target debug`.

**Full disk image (needed for shell-level smoke tests — DEBUG, COPY, SET all run under the booted OS):**
```bash
cmake --build build --target image_d64
```
Produces `build/image.d64`, loadable in VICE via `LOAD"*",8,1` / `RUN`.

Any error line containing `Error` or `at line` means the build failed — fix before continuing.

---

## File Map

| File | Changes |
|------|---------|
| `src/command64/path.asm` | Task 1 (R1 — `checkExistence` TempLo clobber) |
| `src/command64/shell.asm` | Task 2 (R2 — `ccCloseSrcErr`), Task 3 (R3 — SourceBuf overflow), Task 4 (R4 — envAppend bounds) |
| `src/external/debug/debug.asm` | Task 5 (R5 — `cmdSearch` OOB read), Task 8 (R8 — print-routine reuse, **already implemented**, see note) |
| `CMakeLists.txt` | Task 6 (R6 — `CONFIGURE_DEPENDS`) |
| `src/command64/vmm.asm` | Task 7 (R7 — VMM byte-transfer overhead) |
| `CHANGELOG.md` | Updated every task |

---

## Task 1: Fix `checkExistence` TempLo Clobber — `path.asm` (R1, Blocker) — Implemented and Verified

**Severity: High (Blocker)** — `checkExistence` breaks the filename-length argument on nearly every disk operation (LOAD/TYPE/DEL/REN/COPY/external-program lookup) run against a responsive device.

**Status: Implemented and verified.** Applied to `src/command64/path.asm` and confirmed via direct memory reads in VICE: before the fix, `TempLo` at `checkExistence`'s `KernalSETNAM` call held whatever `checkDeviceReady` left behind rather than the real filename length; after the fix it correctly holds the original length across the call. Live-reproduced the exact failure this caused — `DEBUG` (and `dir`, transiently, due to an unrelated PETSCII-encoding test-methodology mistake, see below) failing to dispatch with `Bad command or file name` after printing `loading...` — and confirmed the fix resolves the length corruption. `command64.prg` builds cleanly with the fix applied.

**Test-methodology note:** an early attempt to reproduce this bug via synthetic keyboard-buffer injection used the wrong PETSCII byte range for typed input (injected $61–$7A/lowercase-range codes, when a real unshifted keypress in this OS's lowercase-charset display mode actually produces $41–$5A/uppercase-range codes — the charset-switch control code changes on-screen glyph rendering only, not the KERNAL keyboard-scan byte values). That mistake produced a false "dir fails too" signal; once corrected to the right byte range, `dir` (a built-in, dispatched entirely through the command table, never touching `checkExistence`) was confirmed unaffected both before and after the fix.

**Root cause:** `checkExistence` (`src/command64/path.asm:51`) calls `checkDeviceReady` at line 56, which is documented (`file.asm:35`) to clobber `A, X, Y, TempLo, TempHi`. Line 67 (`lda TempLo`) then reuses `TempLo` as the SETNAM filename length — but by that point it no longer holds the length `findFile` stored there; it holds whatever `checkDeviceReady` left behind. Every `KernalSETNAM` call downstream gets a garbage length.

**Files:**
- Modify: `src/command64/path.asm`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Locate the bug**

Open `src/command64/path.asm`. Find `checkExistence:` (line 51). The current code is:

```asm
checkExistence:
    // Preflight: bail out before touching the real file if the device isn't
    // there or has no disk — avoids reading garbage off a channel with no
    // data behind it.
    lda CurrentDevice
    jsr checkDeviceReady
    bcs ceDeviceErr

    lda #0                  // Disable KERNAL messages
    jsr KernalSETMSG

    lda #14                 // LFN 14 — clear of handle table (2-9), dir (13), command channel (15)
    ldx CurrentDevice
    ldy #0                  // Secondary address 0 (Read)
    jsr KernalSETLFS

    lda TempLo              // Length
    ldx NamePtrLo
    ldy NamePtrHi
    jsr KernalSETNAM

    jsr KernalOPEN

    // Carry flag is set by OPEN if file not found or drive error.
    // If it succeeded (C=0), we still need to close it.
    php                     // Save status (including carry)

    lda #14
    jsr KernalCLOSE

    plp                     // Restore status (restore Carry)
    bcc ceOk
    lda #3                  // Device was ready; the file itself wasn't found
    sec
ceOk:
    rts

ceDeviceErr:
    rts                     // A already holds the checkDeviceReady status code
```

- [ ] **Step 2: Save the filename length across the `checkDeviceReady` call**

`checkDeviceReady` clobbers `TempLo`/`TempHi`, so the length must be stashed somewhere it can't touch. Use the stack (`pha`/`pla`) rather than another ZP byte — it's self-contained and avoids coupling `checkExistence` to some other routine's scratch byte. Replace the whole block with:

```asm
checkExistence:
    lda TempLo
    pha                     // Save filename length — checkDeviceReady clobbers TempLo/TempHi

    // Preflight: bail out before touching the real file if the device isn't
    // there or has no disk — avoids reading garbage off a channel with no
    // data behind it.
    lda CurrentDevice
    jsr checkDeviceReady
    bcs ceDeviceErr

    lda #0                  // Disable KERNAL messages
    jsr KernalSETMSG

    lda #14                 // LFN 14 — clear of handle table (2-9), dir (13), command channel (15)
    ldx CurrentDevice
    ldy #0                  // Secondary address 0 (Read)
    jsr KernalSETLFS

    pla                     // Restore filename length (was clobbered by checkDeviceReady)
    sta TempLo
    lda TempLo
    ldx NamePtrLo
    ldy NamePtrHi
    jsr KernalSETNAM

    jsr KernalOPEN

    // Carry flag is set by OPEN if file not found or drive error.
    // If it succeeded (C=0), we still need to close it.
    php                     // Save status (including carry)

    lda #14
    jsr KernalCLOSE

    plp                     // Restore status (restore Carry)
    bcc ceOk
    lda #3                  // Device was ready; the file itself wasn't found
    sec
ceOk:
    rts

ceDeviceErr:
    pla                     // Balance the stack — saved length isn't needed on this path
    rts                     // A already holds the checkDeviceReady status code
```

- [ ] **Step 3: Build the OS**

```bash
cmake --build build --target command64
```

Expected: clean build.

- [ ] **Step 4: Smoke-test in VICE**

Build and boot `image_d64`. At the `C64[8]:>` prompt:

1. `dir` — directory listing should still work (sanity check, doesn't exercise this path).
2. `type command64.prg` (or any real file with a name longer than 1 char) — before the fix, `checkExistence`'s corrupted length could cause `TYPE`/`LOAD` to intermittently fail or hang against a "device ready" (real/emulated) drive; after the fix it should load and print reliably every time.
3. `load nonexistent.prg` — should cleanly report a not-found error, not hang or open with a garbage-length name.
4. Run each of `del`, `ren`, `copy` against a real file at least once to confirm `findFile`/`checkExistence` still resolves names correctly end-to-end.

- [ ] **Step 5: Update CHANGELOG.md**

Add under `[Unreleased]` → `### Fixed`:

```
- path: checkExistence no longer clobbers the filename length passed to KernalSETNAM —
  it now saves TempLo across the checkDeviceReady call (which documented-ly clobbers
  TempLo/TempHi), fixing a bug that broke LOAD/TYPE/DEL/REN/COPY/external-program lookup
  against any responsive device
```

- [ ] **Step 6: Commit**

```bash
git add src/command64/path.asm CHANGELOG.md
git commit -m "fix(path): preserve filename length across checkDeviceReady in checkExistence"
```

---

## Task 2: Fix `ccCloseSrcErr` Error-Code Clobber — `shell.asm` (R2, High)

**Severity: High** — COPY's dest-open-failure path always reports a generic "Load error" instead of the real reason ("Device not present" / "No disk in drive"), because closing the source handle overwrites the register `printDeviceStatusMsg` reads.

**Root cause:** `ccCloseSrcErr` (`shell.asm:1166`) is entered with `A` holding the dest-open error status (set by the failed `DOS_OPEN_FILE` call at line 1098, `bcs ccCloseSrcErr` at line 1099). It then closes the source file, whose own close-status overwrites `A` before falling into `ccOpenErr` → `printDeviceStatusMsg`, which reads `A` as its input status code (`file.asm:135`).

**Files:**
- Modify: `src/command64/shell.asm`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Locate the bug**

Find `ccCloseSrcErr:` in `src/command64/shell.asm` (line 1166). Current code:

```asm
ccCloseSrcErr:
    lda SrcHandle           // source handle — TempLo holds scan index here, not the handle
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr apiHandler          // On the rare chance this ALSO fails, its status
                             // (not the dest-open failure's) is what gets
                             // reported below — an acceptable simplification
                             // for this double-fault edge case.
    jmp ccOpenErr
```

- [ ] **Step 2: Preserve the real error code across the close**

```asm
ccCloseSrcErr:
    pha                     // Save the dest-open error status; the source-close
                             // call below clobbers A with its own (irrelevant) status
    lda SrcHandle           // source handle — TempLo holds scan index here, not the handle
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr apiHandler          // Close source; its own status is not reported —
                             // the original dest-open failure is what the user needs to see
    pla                     // Restore the real dest-open error status for printDeviceStatusMsg
    jmp ccOpenErr
```

- [ ] **Step 3: Build the OS**

```bash
cmake --build build --target command64
```

- [ ] **Step 4: Smoke-test COPY error path in VICE**

At the `C64[8]:>` prompt:

1. `copy hello.prg 9:foo.prg` where device 9 has no drive attached — should now print `Device not present` (not the generic `Load error`).
2. `copy hello.prg 8:foo.prg` with a drive present but no disk — should print `No disk in drive`.
3. Confirm the shell returns cleanly to the prompt in both cases (no hang/crash), and that `hello.prg`'s source handle isn't left open (a subsequent `copy hello.prg dest2.prg` should still succeed).

- [ ] **Step 5: Update CHANGELOG.md**

```
### Fixed
- shell: COPY's dest-open-failure path now reports the actual error (device not present /
  no disk) instead of a generic "Load error" — ccCloseSrcErr no longer lets the source-close
  call's status overwrite the real dest-open error code
```

- [ ] **Step 6: Commit**

```bash
git add src/command64/shell.asm CHANGELOG.md
git commit -m "fix(shell): preserve dest-open error code across ccCloseSrcErr's source close"
```

---

## Task 3: Add Bounds Check to `cmdCopy`'s Source-Name Copy — `shell.asm` (R3, High)

**Severity: High** — `COPY <45+ char name> dest.prg` overflows the 40-byte `SourceBuf` into the immediately-following 40-byte `DestBuf` (`include/command64.inc:85-86`), since `CommandBuffer` allows up to 79 chars of input.

**Root cause:** `ccCopySrc` (`shell.asm:994`) copies bytes from the parsed command line into `SourceBuf, x` with no check on `x` against the buffer's 40-byte size.

**Files:**
- Modify: `src/command64/shell.asm`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Locate the loop**

Find `ccCopySrc:` in `src/command64/shell.asm` (line 994). Current code:

```asm
ccCopySrc:
    lda (PrintPtrLo), y
    beq ccGotSrcNull
    cmp #' '
    beq ccGotSrcSpace
    sta SourceBuf, x
    inx
    iny
    jmp ccCopySrc
```

- [ ] **Step 2: Add the bounds check**

`SourceBuf` is 40 bytes; the last usable index is 39 so a null terminator can still be written at worst case. Reject (rather than silently truncate) an over-length name — silent truncation could make COPY quietly operate on the wrong file.

```asm
ccCopySrc:
    cpx #40                 // SourceBuf is 40 bytes — refuse to write index 40+
    bcs ccSrcTooLong
    lda (PrintPtrLo), y
    beq ccGotSrcNull
    cmp #' '
    beq ccGotSrcSpace
    sta SourceBuf, x
    inx
    iny
    jmp ccCopySrc

ccSrcTooLong:
    lda #<nameTooLongMsg
    ldy #>nameTooLongMsg
    jsr petPrintString
    jmp copyExit
```

- [ ] **Step 3: Add the new error message string**

In the data section of `shell.asm`, near the other short error strings (`noFileMsg`, `loadErrMsg` etc. — search for `noFileMsg:`), add:

```asm
nameTooLongMsg:
    .text "File name too long"
    .byte 0
```

- [ ] **Step 4: Build the OS**

```bash
cmake --build build --target command64
```

- [ ] **Step 5: Smoke-test in VICE**

1. `copy hello.prg dest.prg` — normal case still works.
2. `copy` followed by a 45+ character source name and a destination — should print `File name too long` and return to the prompt cleanly, with no corruption of a subsequent `copy`/`dir`/`load` (confirms `DestBuf` wasn't clobbered).

- [ ] **Step 6: Update CHANGELOG.md**

```
### Fixed
- shell: COPY now rejects source filenames longer than SourceBuf's 40-byte capacity
  instead of overflowing into the adjacent DestBuf
```

- [ ] **Step 7: Commit**

```bash
git add src/command64/shell.asm CHANGELOG.md
git commit -m "fix(shell): bounds-check COPY source filename against SourceBuf capacity"
```

---

## Task 4: Recheck Bounds on Every `envAppend` Write — `shell.asm` (R4, High)

**Severity: High** — `envAppend`'s 4KB environment-segment bounds check (`VmmOffHi` vs `$10`) only runs once at entry; the write loops that follow never recheck it, so a long `SET VAR=value` issued near the boundary writes past the Env segment into adjacent REU pages instead of erroring.

**Files:**
- Modify: `src/command64/shell.asm`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Locate `envAppend`**

Find `envAppend:` in `src/command64/shell.asm` (line 1697). Current code:

```asm
envAppend:
    // Bounds check: 4KB segment ($1000 bytes)
    lda VmmOffHi
    cmp #$10                // Offset $1000?
    bcc eaCheckSpace
    lda #<envFullMsg
    ldy #>envFullMsg
    jsr petPrintString
    rts

eaCheckSpace:
    ldx #0
eaVarLoop:
    lda SourceBuf, x
    beq eaWriteEq
    jsr vmmWriteByte
    inc VmmOffLo
    bne eaVarNext
    inc VmmOffHi
eaVarNext:
    inx
    jmp eaVarLoop

eaWriteEq:
    lda #'='
    jsr vmmWriteByte
    inc VmmOffLo
    bne eaEqNext
    inc VmmOffHi
eaEqNext:

    ldy ParsePos
eaValLoop:
    lda CommandBuffer, y
    beq eaDone
    jsr vmmWriteByte        // vmmWriteByte preserves Y (via vmmComputeAddress stack fix)
    inc VmmOffLo
    bne eaValNext
    inc VmmOffHi
eaValNext:
    iny
    jmp eaValLoop

eaDone:
    lda #0
    jsr vmmWriteByte
    inc VmmOffLo
    bne eaFinalNull
    inc VmmOffHi
eaFinalNull:
    lda #0
    jsr vmmWriteByte
    rts
```

- [ ] **Step 2: Factor the check into a shared subroutine and call it before every write**

```asm
envAppend:
    jsr eaCheckBounds
    bcs eaAbort

eaCheckSpace:
    ldx #0
eaVarLoop:
    lda SourceBuf, x
    beq eaWriteEq
    jsr eaCheckBounds
    bcs eaAbort
    jsr vmmWriteByte
    inc VmmOffLo
    bne eaVarNext
    inc VmmOffHi
eaVarNext:
    inx
    jmp eaVarLoop

eaWriteEq:
    jsr eaCheckBounds
    bcs eaAbort
    lda #'='
    jsr vmmWriteByte
    inc VmmOffLo
    bne eaEqNext
    inc VmmOffHi
eaEqNext:

    ldy ParsePos
eaValLoop:
    lda CommandBuffer, y
    beq eaDone
    jsr eaCheckBounds
    bcs eaAbort
    jsr vmmWriteByte        // vmmWriteByte preserves Y (via vmmComputeAddress stack fix)
    inc VmmOffLo
    bne eaValNext
    inc VmmOffHi
eaValNext:
    iny
    jmp eaValLoop

eaDone:
    jsr eaCheckBounds
    bcs eaAbort
    lda #0
    jsr vmmWriteByte
    inc VmmOffLo
    bne eaFinalNull
    inc VmmOffHi
eaFinalNull:
    jsr eaCheckBounds
    bcs eaAbort
    lda #0
    jsr vmmWriteByte
    rts

eaAbort:
    lda #<envFullMsg
    ldy #>envFullMsg
    jsr petPrintString
    rts

// --- eaCheckBounds [Private] ---
// Output: Carry set if VmmOffHi has reached the 4KB env-segment limit ($1000).
eaCheckBounds:
    lda VmmOffHi
    cmp #$10
    rts
```

- [ ] **Step 3: Build the OS**

```bash
cmake --build build --target command64
```

- [ ] **Step 4: Smoke-test in VICE**

1. `set FOO=bar` then `echo %FOO%` (or the shell's equivalent env-read command) — normal case still works.
2. Issue enough `SET` commands to approach the 4KB boundary (or, for a faster repro, temporarily lower the `#$10` limit in a scratch build to something reachable in a few commands, verify the abort path fires, then revert), confirming `Warning: environment full` (or equivalent `envFullMsg` text) prints and no data lands past the segment boundary.

- [ ] **Step 5: Update CHANGELOG.md**

```
### Fixed
- shell: envAppend now rechecks the 4KB environment-segment bound before every byte
  written (not just once at entry), preventing a long SET VAR=value near the boundary
  from writing past the Env segment into adjacent REU pages
```

- [ ] **Step 6: Commit**

```bash
git add src/command64/shell.asm CHANGELOG.md
git commit -m "fix(shell): recheck env-segment bounds on every envAppend write, not just at entry"
```

---

## Task 5: Fix `cmdSearch` Out-of-Range Read — `debug.asm` (R5, Medium)

**Severity: Medium** — `cmdSearch`'s `csCompLoop` compares the full search pattern against `(rangeStart),y` before `checkRangeLimit` is ever consulted, and `checkRangeLimit` only checks `rangeStart` itself (not `rangeStart + listLen`). A pattern search whose match window straddles `rangeEnd` reads past the user-declared range — potentially into memory-mapped I/O — while still reporting an in-range match.

**Files:**
- Modify: `src/external/debug/debug.asm`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Locate `cmdSearch`**

Find `cmdSearch:` in `src/external/debug/debug.asm`. Current code:

```asm
cmdSearch:
    jsr parseRange
    bcc *+5
    jmp cdErr
    jsr parseList
    bcc *+5
    jmp cdErr
    lda listLen
    bne *+5
    jmp cdErr
    
csLoop:
    ldy #0
csCompLoop:
    lda (rangeStart), y
    cmp listBuf, y
    bne csNoMatch
    iny
    cpy listLen
    bne csCompLoop
    
    // Found: print address
    lda rangeStart + 1
    jsr printHex8
    lda rangeStart
    jsr printHex8
    lda #PetCr
    jsr KernalChROUT

csNoMatch:
    jsr checkRangeLimit
    beq csDone
csInc:
    inc rangeStart
    bne csLoop
    inc rangeStart + 1
    jmp csLoop
csDone:
    rts
```

- [ ] **Step 2: Add a window-fits check before `csCompLoop`, using `val1` as scratch**

`val1`/`val1+1` are free at this point — no other cmdSearch code uses them, and only `cmdHexMath`/`cmdMove`/`cmdCompare` use them elsewhere, none of which run concurrently with `cmdSearch`.

```asm
csLoop:
    // Bounds check: don't start a listLen-byte compare unless the whole
    // window fits within the user-declared range, so csCompLoop never
    // reads past rangeEnd (which could be memory-mapped I/O).
    lda rangeStart
    clc
    adc listLen
    sbc #1                  // val1 = rangeStart + listLen - 1 (carry set by adc above)
    sta val1
    lda rangeStart + 1
    adc #0
    sta val1 + 1

    lda rangeEnd + 1
    cmp val1 + 1
    bne csSkipLo
    lda rangeEnd
    cmp val1
csSkipLo:
    bcs csWindowOk           // rangeEnd >= val1: the full window fits, safe to compare
    jmp csDone               // window would run past rangeEnd: no more matches possible

csWindowOk:
    ldy #0
csCompLoop:
    lda (rangeStart), y
    cmp listBuf, y
    bne csNoMatch
    iny
    cpy listLen
    bne csCompLoop
    
    // Found: print address
    lda rangeStart + 1
    jsr printHex8
    lda rangeStart
    jsr printHex8
    lda #PetCr
    jsr KernalChROUT

csNoMatch:
    jsr checkRangeLimit
    beq csDone
csInc:
    inc rangeStart
    bne csLoop
    inc rangeStart + 1
    jmp csLoop
csDone:
    rts
```

- [ ] **Step 3: Build debug**

```bash
cmake --build build --target debug
```

- [ ] **Step 4: Smoke-test in VICE**

Load `debug.prg` from the command64 shell. At the `-` prompt:

1. `S 1000 10FF 41` — search a comfortably-sized range for byte `$41`; confirm matches print as before (regression check on the common case).
2. `S 1000 1002 41 42 43 44` — a 4-byte pattern against a 3-byte range (window can never fit) — should print nothing and return to the prompt without reading past `$1002`.
3. `S 1000 1003 41 42 43 44` — pattern exactly fills the range — should find a match at `$1000` (if present) and correctly stop afterward, without an extra out-of-range compare.

- [ ] **Step 5: Update CHANGELOG.md**

```
### Fixed
- debug: cmdSearch (S) no longer reads past the user-declared range end when the
  search pattern's match window straddles rangeEnd — the full listLen-byte window
  is now bounds-checked before each compare, not just the start address afterward
```

- [ ] **Step 6: Commit**

```bash
git add src/external/debug/debug.asm CHANGELOG.md
git commit -m "fix(debug): bounds-check full search-pattern window in cmdSearch before comparing"
```

---

## Task 6: Add `CONFIGURE_DEPENDS` to Source Globs — `CMakeLists.txt` (R6, Medium)

**Severity: Medium** — `file(GLOB_RECURSE ...)` source discovery for `CMD64_SRCS`/`DEBUG_SRCS`/`LABEL_SRCS`/`CONWAY_SRCS` lacks `CONFIGURE_DEPENDS`. A newly added `.asm`/`.inc` file is silently excluded from the build until someone manually re-runs `cmake -B build`, producing a stale/incomplete PRG with no error.

**Files:**
- Modify: `CMakeLists.txt`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Locate the glob calls**

`CMakeLists.txt`, lines 40–49:

```cmake
# Source file discovery
file(GLOB_RECURSE CMD64_SRCS "src/command64/*.asm" "include/*.inc")
set(CMD64_ENTRY "src/command64.asm")

file(GLOB_RECURSE DEBUG_SRCS "src/external/debug/*.asm" "include/*.inc")
set(DEBUG_ENTRY "src/external/debug/debug.asm")

file(GLOB_RECURSE LABEL_SRCS "src/external/label/*.asm" "include/*.inc")
set(LABEL_ENTRY "src/external/label/label.asm")

file(GLOB_RECURSE CONWAY_SRCS "src/external/conway/*.asm" "include/*.inc")
set(CONWAY_ENTRY "src/external/conway/conway.asm")
```

- [ ] **Step 2: Add `CONFIGURE_DEPENDS` to each**

```cmake
# Source file discovery
file(GLOB_RECURSE CMD64_SRCS CONFIGURE_DEPENDS "src/command64/*.asm" "include/*.inc")
set(CMD64_ENTRY "src/command64.asm")

file(GLOB_RECURSE DEBUG_SRCS CONFIGURE_DEPENDS "src/external/debug/*.asm" "include/*.inc")
set(DEBUG_ENTRY "src/external/debug/debug.asm")

file(GLOB_RECURSE LABEL_SRCS CONFIGURE_DEPENDS "src/external/label/*.asm" "include/*.inc")
set(LABEL_ENTRY "src/external/label/label.asm")

file(GLOB_RECURSE CONWAY_SRCS CONFIGURE_DEPENDS "src/external/conway/*.asm" "include/*.inc")
set(CONWAY_ENTRY "src/external/conway/conway.asm")
```

`CONFIGURE_DEPENDS` (CMake ≥3.12; this project requires ≥3.20 per line 4) asks CMake to re-glob at build time via a check target, so a newly added/removed matching file triggers reconfiguration automatically rather than requiring a manual `cmake -B build`.

- [ ] **Step 3: Reconfigure and do a full rebuild**

```bash
cmake -B build
cmake --build build --target image_d64
```

Expected: clean build, identical output to before (this change doesn't alter compiled bytes, only build-graph freshness).

- [ ] **Step 4: Verify the fix**

1. Add a throwaway file, e.g. `touch src/command64/zzz_test.asm` (empty file — KickAssembler will error if it's referenced, so leave it unreferenced or just check the file list, not a real build).
2. Re-run `cmake --build build --target command64` **without** manually re-running `cmake -B build` first.
3. Expected: CMake detects the new file and reconfigures automatically (you'll see `-- Configuring done` / `-- Generating done` in the build output) rather than silently building with the stale file list.
4. Remove `zzz_test.asm` and rebuild once more to confirm removal is also picked up automatically.

- [ ] **Step 5: Update CHANGELOG.md**

```
### Changed
- build: source-file globs (CMD64_SRCS, DEBUG_SRCS, LABEL_SRCS, CONWAY_SRCS) now use
  CONFIGURE_DEPENDS so newly added/removed .asm/.inc files trigger automatic
  reconfiguration instead of silently building a stale file list
```

- [ ] **Step 6: Commit**

```bash
git add CMakeLists.txt CHANGELOG.md
git commit -m "build: add CONFIGURE_DEPENDS to source-file globs for automatic reconfiguration"
```

---

## Task 7: Prime REU Transfer Registers Once — `vmm.asm` (R7, Low)

**Severity: Low (efficiency)** — `vmmReadByte`/`vmmWriteByte` reload `REU_C64_ADDR_L/H` and `REU_LEN_L/H` with the same constants on every single-byte transfer — the hottest path in the VMM (called once per byte for all REU-backed file/disk I/O). Priming these once removes 4 redundant `lda`/`sta` pairs (8 instructions) from every byte transferred.

**Safety check:** `REU_C64_ADDR_L/H` and `REU_LEN_L/H` (`include/vmm.inc:27-33`) are written **only** in `vmmReadByte`/`vmmWriteByte`, nowhere else in the codebase (verified via full-repo grep) — no other routine changes their values between calls, so priming once is safe. `REU_REU_ADDR_L/H`/`REU_REU_BANK` (set per-call in `vmmComputeAddress`) and `REU_COMMAND` (the trigger) are **not** touched by this change — those genuinely vary per call and must stay in the hot path.

**Files:**
- Modify: `src/command64/vmm.asm`
- Modify: `CHANGELOG.md`

- [ ] **Step 1: Locate `vmmInit`, `vmmReadByte`, `vmmWriteByte`**

`src/command64/vmm.asm`. Current `vmmInit` tail (~line 34):

```asm
    lda #1
    sta vmmInitialized      // Mark VMM as ready
    lda #VMM_SUCCESS
    rts
viNoReu:
    lda #0
    sta vmmInitialized      // Mark VMM as not available
    lda #VMM_ERR_INVALID
    rts
```

Current `vmmReadByte`/`vmmWriteByte` (~line 258):

```asm
vmmReadByte:
    cld
    lda vmmInitialized
    bne vrbInitOk
    lda #0                  // Return 0 if not initialized
    rts
vrbInitOk:
    jsr vmmComputeAddress   // Compute REU address and bank
    
    // Set C64 target to a temp location (using a ZP scratch for speed)
    lda #<vmmTempByte
    sta REU_C64_ADDR_L
    lda #>vmmTempByte
    sta REU_C64_ADDR_H
    
    // Set transfer length to 1 byte
    lda #1
    sta REU_LEN_L
    lda #0
    sta REU_LEN_H
    
    // Execute Fetch (REU -> C64)
    lda #REU_CMD_FETCH
    sta REU_COMMAND
    
    lda vmmTempByte         // Return the fetched byte
    rts

// --- vmmWriteByte ---
// Writes a byte to DOS Seg:Off.
// Input:  A = byte to write, VmmSegLo/Hi, VmmOffLo/Hi
vmmWriteByte:
    cld
    sta vmmTempByte         // Save data to write
    lda vmmInitialized
    bne vwbInitOk
    rts                     // Silently ignore write if not initialized
vwbInitOk:
    jsr vmmComputeAddress
    
    lda #<vmmTempByte
    sta REU_C64_ADDR_L
    lda #>vmmTempByte
    sta REU_C64_ADDR_H
    
    lda #1
    sta REU_LEN_L
    lda #0
    sta REU_LEN_H
    
    // Execute Stash (C64 -> REU)
    lda #REU_CMD_STASH
    sta REU_COMMAND
    rts
```

- [ ] **Step 2: Prime the registers once in `vmmInit`**

Insert the priming block right before the existing `lda #1 / sta vmmInitialized` success path (only reached once REU presence is confirmed):

```asm
    // Prime the REU transfer registers used by every vmmReadByte/vmmWriteByte
    // call: the target is always vmmTempByte and the length is always 1 byte
    // (see Safety check in the R7 remediation plan — nothing else writes these
    // 4 registers), so priming once here removes 8 redundant instructions from
    // the single-byte transfer hot path.
    lda #<vmmTempByte
    sta REU_C64_ADDR_L
    lda #>vmmTempByte
    sta REU_C64_ADDR_H
    lda #1
    sta REU_LEN_L
    lda #0
    sta REU_LEN_H

    lda #1
    sta vmmInitialized      // Mark VMM as ready
    lda #VMM_SUCCESS
    rts
viNoReu:
    lda #0
    sta vmmInitialized      // Mark VMM as not available
    lda #VMM_ERR_INVALID
    rts
```

- [ ] **Step 3: Strip the redundant reloads from `vmmReadByte`/`vmmWriteByte`**

```asm
vmmReadByte:
    cld
    lda vmmInitialized
    bne vrbInitOk
    lda #0                  // Return 0 if not initialized
    rts
vrbInitOk:
    jsr vmmComputeAddress   // Compute REU address and bank

    // REU_C64_ADDR_L/H and REU_LEN_L/H are primed once in vmmInit — see R7 note there
    lda #REU_CMD_FETCH
    sta REU_COMMAND

    lda vmmTempByte         // Return the fetched byte
    rts

// --- vmmWriteByte ---
// Writes a byte to DOS Seg:Off.
// Input:  A = byte to write, VmmSegLo/Hi, VmmOffLo/Hi
vmmWriteByte:
    cld
    sta vmmTempByte         // Save data to write
    lda vmmInitialized
    bne vwbInitOk
    rts                     // Silently ignore write if not initialized
vwbInitOk:
    jsr vmmComputeAddress

    // REU_C64_ADDR_L/H and REU_LEN_L/H are primed once in vmmInit — see R7 note there
    lda #REU_CMD_STASH
    sta REU_COMMAND
    rts
```

- [ ] **Step 4: Build the OS**

```bash
cmake --build build --target command64
```

- [ ] **Step 5: Smoke-test REU-backed I/O in VICE**

REU-backed I/O only kicks in once a REU is present. In VICE, enable the REU (Settings → Cartridge/IO → REU, or launch with `-reu -reusize 512`), then boot `image_d64` and:

1. `set FOO=bar` / read it back — exercises `vmmWriteByte`/`vmmReadByte` via the environment segment.
2. Load/run one of the VMM test PRGs (`tests/src/vmmtest.asm` if built as a test target) to confirm multi-byte read/write sequences still round-trip correctly.
3. Confirm behavior is identical with REU disabled (VMM falls back to its "not initialized" path) — no regression there since that path returns before reaching the primed registers.

- [ ] **Step 6: Update CHANGELOG.md**

```
### Changed
- vmm: vmmReadByte/vmmWriteByte no longer reload REU_C64_ADDR_L/H and REU_LEN_L/H on
  every call — these are now primed once in vmmInit (the only routines that ever write
  them), removing 8 redundant instructions from the single-byte REU transfer hot path
```

- [ ] **Step 7: Commit**

```bash
git add src/command64/vmm.asm CHANGELOG.md
git commit -m "perf(vmm): prime REU transfer registers once in vmmInit instead of every byte"
```

---

## Task 8: DEBUG Print-Routine Reuse — `debug.asm` (R8, Low) — Already Implemented

**Severity: Low (reuse/efficiency)** — `debug.asm` printed every UI string as a chain of individual `lda #'X'`/`jsr KernalChROUT` pairs (118 call sites) instead of using a shared string + one print call.

**Status: Implemented ahead of this plan** (done directly during the same session that produced this remediation plan, before the full R1–R8 write-up was requested). Recorded here for completeness and to keep the task numbering aligned with the review.

**What was done:**
- Added a local `API_PRINT_STR` wrapper (already present in `debug.asm`, X=lo/Y=hi → syscalls `DOS_PRINT_STR` via the resident OS dispatcher at `$1000`) as the shared print path, since `debug.asm` builds as a standalone external-app PRG and does **not** link against `src/command64/petsci.asm`'s `petPrintString` — that routine is only reachable from code assembled into `command64.prg` itself.
- Converted every *contiguous run* of ≥2 literal-character prints with no intervening dynamic/branching logic into a single `.text "..." / .byte 0` data string plus one `API_PRINT_STR` call: the register dump (`printAllRegs`, `printPFlags` — the largest block, ~33 call-site pairs), `modifyPC`/`modifyReg`/`modifyP_Custom`'s label and prompt strings, the hex-dump/disassembler address separator (`": "`, 3 identical sites), the hex-math two-space separator, and the disassembler's addressing-mode suffixes (`,X`, `,Y`, `,X)`, `),Y`).
- Left single, isolated, data-dependent character prints untouched (e.g. `printBitA`'s conditional `'0'`/`'1'`, loop separators inside `cdHexLoop`/`cuPrintBytes` that alternate between `' '` and `':'` based on loop position) — these aren't fixed strings and a string+call would cost more code than the raw `lda`/`jsr` pair for a single character.
- Result: reduced from 101 `lda #'X'` character-literal sites to 28 (verified via `grep -c "lda #'" src/external/debug/debug.asm`), all 28 remaining being genuinely non-batchable single chars.

**Files:**
- Modified: `src/external/debug/debug.asm`
- Pending: `CHANGELOG.md`

- [ ] **Step 1: Build debug**

```bash
cmake --build build --target debug
```

Expected: clean build (already confirmed once during implementation; re-run to verify against current tree state).

- [ ] **Step 2: Full disk image build**

```bash
cmake --build build --target image_d64
```

- [ ] **Step 3: Smoke-test in VICE**

**Known blocker to resolve first:** while verifying this task, loading `DEBUG` from the command64 shell (`debug` at the `C64[8]:>` prompt) failed with `Bad command or file name` even on the **unmodified pre-R8** `debug.asm` — confirmed by stashing the R8 changes, rebuilding, and reproducing the identical failure. This is a **pre-existing bug unrelated to R8**, not a regression introduced by this task. It blocks interactive verification of R8 (and would equally block R5's in-shell smoke test in Task 5, though R5 can also be smoke-tested by loading `debug.prg` directly via `vice_load_program` and driving it with the CPU already past `$1000`/API-dispatcher setup). Root-cause this separately — likely in `shellDispatch`'s external-command path (`sdBadCmd` / `findFile` / `shellLoadPrg`, `shell.asm:250-317`) — before relying on shell-level smoke tests for any DEBUG-touching task. **Recommend filing this as a new finding (tentatively R9) rather than folding the investigation into this plan.**

Once unblocked, verify:

1. `R` — full register dump (`printAllRegs`/`printPFlags`) renders identically to before: `A=xx X=xx Y=xx P=xx S=xx PC=xxxx` followed by `P=XX: N=x V=x * B=x D=x I=x Z=x C=x`.
2. `PC` then Enter with no new value — `PC xxxx` label prints correctly, prompt `:` appears on the next line.
3. `A xx` (any register letter) — register-modify prompt (`X xx` / `:`) renders correctly.
4. `P` — `P xx` line and the flags line both render correctly, prompt accepts flag edits (`n=1`) and plain hex.
5. `D 1000` — hex dump's `xxxx: ` address separator renders correctly (was the shared `sepColonSp` string).
6. `U 1000` — disassembler output for at least one instruction of each of `,X`/`,Y`/indirect-indexed/indexed-indirect addressing modes (e.g. an opcode like `$BD` ABS,X, `$91` IZY) to confirm the suffix strings (`,X`, `,Y`, `,X)`, `),Y`) render correctly.
7. `H 1000 0100` — hex-math two-space separator between sum and difference renders correctly.

- [ ] **Step 4: Update CHANGELOG.md**

```
### Changed
- debug: consolidated ~90 individual lda #'X'/jsr KernalChROUT character-print pairs
  (register dump, flags line, PC/register-modify prompts, hex-dump and disassembler
  separators, addressing-mode suffixes) into shared data strings printed via a single
  API_PRINT_STR call each, reducing code size and the surface area for typo'd literals
```

- [ ] **Step 5: Commit**

```bash
git add src/external/debug/debug.asm CHANGELOG.md
git commit -m "chore(debug): consolidate chained character-prints into shared strings via API_PRINT_STR"
```

---

## Task 9: KERNAL LOAD "Hang" in VICE — Retracted, Testing-Tool Artifact (R9, Not a Real Bug)

**Status: Retracted.** Originally logged as an unclassified hang discovered while smoke-testing R1. **The user confirmed `LOAD"DEBUG",8,1` completes without any problem on physical hardware**, using the identical command against the identical disk image content. That directly contradicts a real code or disk-image bug and points at the actual cause: this session's VICE testing methodology.

**Root cause of the false finding:** every tool call used to observe or drive the running emulator (`vice_read_registers`, `vice_screenshot`, `vice_read_memory`, `vice_write_memory`, even `vice_run`) goes through VICE's binary monitor protocol, which momentarily halts the 6502 CPU to service the request, then resumes it. `DEBUG.PRG` is large enough (26 blocks, chain crossing tracks 2→3) that with true drive emulation enabled, its `LOAD` takes real, non-trivial wall-clock time — long enough that a screenshot or register read taken during the transfer window lands mid-flight. Halting and resuming the CPU in the middle of a software-timed IEC serial handshake (which real 1541 protocols rely on precise cycle counting for) is exactly the kind of interference that can desync the transfer and stall it indefinitely — while the KERNAL and drive both wait for a clock/data edge that the pause caused them to miss. This is consistent with every observation:
- The first "clean" 150-second test still included a screenshot at the 60-second mark and another 90 seconds later — each a monitor pause/resume — landing squarely inside the transfer window for a file this size.
- Smaller files (`LABEL`, `CONWAY`, 3 blocks each) transfer fast enough that the load likely completed before any monitor call could land mid-transfer, so they never appeared to hang.
- `COMMAND64.PRG` (25 blocks) loaded successfully via the wildcard `LOAD"*",8,1` specifically because that load happens automatically as part of `vice_load_program`'s own injection sequence, with no follow-up monitor calls made during its transfer window — the same file might well have "hung" too if a screenshot had been taken 60 seconds into that particular load.
- Real hardware has no such interference possible, and the user confirmed it loads fine there.

**What this means for the rest of this plan:** R5 and R8's in-emulator smoke-tests (both involve loading external `.prg`s) are not blocked by a real bug — they were blocked by this session's testing methodology. Future verification in VICE should avoid touching the monitor at all between issuing a `LOAD`/external-command-load and its completion (poll only via a single screenshot taken well after an estimated completion time, or disable true drive emulation for faster, non-realtime-sensitive virtual disk access during automated testing).

**No code changes result from this task.** Retained in the plan (rather than deleted) as a record of the investigation and to document the testing-methodology lesson for future sessions.

---

## Summary

| Task | ID | Severity | Files | Risk |
|------|----|----------|-------|------|
| 1 — checkExistence TempLo clobber | R1 | High (Blocker) | path.asm | **Implemented and verified** |
| 2 — ccCloseSrcErr error clobber | R2 | High | shell.asm | One `pha`/`pla` pair, isolated |
| 3 — SourceBuf overflow | R3 | High | shell.asm | Additive bounds check + new error path |
| 4 — envAppend bounds recheck | R4 | High | shell.asm | Mechanical: 1 new subroutine, called at 6 sites |
| 5 — cmdSearch OOB read | R5 | Medium | debug.asm | Additive bounds check using free scratch (val1) |
| 6 — CMake CONFIGURE_DEPENDS | R6 | Medium | CMakeLists.txt | Build-graph only, no compiled-output change |
| 7 — VMM REU register priming | R7 | Low | vmm.asm | Verified no other writer of the primed registers |
| 8 — DEBUG print-routine reuse | R8 | Low | debug.asm | **Already implemented**; build/smoke-test pending |
| 9 — KERNAL LOAD "hang" | R9 | N/A | None | **Retracted** — confirmed to be a VICE monitor-tool testing artifact, not a real bug (verified fine on physical hardware) |

Total: 8 real tasks (R9 retracted, no code involved). Task 1 is implemented and verified. Tasks 2–7 are not yet applied to the working tree (this plan is the spec preceding implementation, per this project's documentation-driven standard). Task 8 is implemented and awaiting build verification.

**Suggested execution order:** 1 (done) → 2 → 3 → 4 → 6 → 7 → 5 and 8's in-emulator verification. When verifying R5/R8 in VICE, avoid monitor calls (screenshots, register/memory reads) during an in-flight `LOAD`/external-command-load — poll with a single screenshot taken well after an estimated completion time instead, per the R9 write-up above.
