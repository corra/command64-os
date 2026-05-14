# debug.asm: ZP Alias and listBuf Overflow Remediation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix two bugs in `src/external/debug/debug.asm` found in the 2026-05-13 code review — a zero-page aliasing bug that corrupts the disassembler's row counter on every relative branch instruction, and a missing bounds check in `parseList` that allows a buffer overflow into adjacent variables.

**Architecture:** Both fixes are isolated to `debug.asm`. Bug 1 rewrites `cuOpRel` to use the stack instead of `DebugTemp`/`DebugTemp+1` (which aliases `disasmTemp` at $7B). Bug 2 adds a four-byte bounds guard in two places inside `parseList`. No new labels, no cross-file changes.

**Tech Stack:** KickAssembler 5.25, 6502/6510 assembly, VICE C64 emulator

---

## Background

### Zero-Page Layout (relevant excerpt)

```
$70  currentAddr  (2 bytes)
$72  rangeStart   (2 bytes)
$74  rangeEnd     (2 bytes)
$76  val1         (2 bytes)
$78  val2         (2 bytes)
$7A  DebugTemp    (1 byte — comment says 1 byte, but cuOpRel writes 2!)
$7B  disasmTemp   (1 byte — loop counter for cmdUnassemble)
```

`DebugTemp + 1 == disasmTemp` ($7A + 1 = $7B). Any write to `DebugTemp + 1` silently clobbers `disasmTemp`.

### Bug 1 Failure Mode

`cuOpRel` (the relative-branch operand handler) computes a 16-bit branch target base:

```asm
; debug.asm:925-928
lda currentAddr
clc
adc #2
sta DebugTemp           // base lo → $7A (ok)
lda currentAddr + 1
adc #0
sta DebugTemp + 1       // base hi → $7B ← ALIASES disasmTemp!
```

`cuDoneLine` then reads `disasmTemp` ($7B) to decide whether to decrement a count or check a range sentinel:

```asm
; debug.asm:1041-1047
lda disasmTemp          // reads corrupted value
cmp #$FF
beq cuCheckRange        // range mode (sentinel = $FF)
dec disasmTemp
beq cuDoneCount         // count mode
jmp cuLoop
```

After any BEQ/BNE/BCC/BCS/BPL/BMI/BVC/BVS is disassembled:
- **Count mode** (`U 2000`, 16-line default): the row counter is replaced by the high byte of `currentAddr + 2` (e.g. $20 for code at $2000–$20FF). The loop runs ~32 more lines instead of the correct remaining count.
- **Range mode** (`U 2000 20FF`): the $FF sentinel check fails; code falls to `dec disasmTemp` and stops after one wrong iteration.

### Bug 2 Failure Mode

`parseList` accumulates bytes into `listBuf` (64 bytes, `debug.asm:1390`) without checking `listLen < 64`:

```asm
; debug.asm:1153-1156 (hex byte path)
ldx listLen
lda HexValLo
sta listBuf, x          // no bounds guard
inc listLen
```

Data section layout after `listBuf`:
```
listBuf:   .fill 64, 0   ; $xx+00 to $xx+3F
parsePos:  .byte 0       ; $xx+64  ← overwritten at listLen==64
inputLen:  .byte 0       ; $xx+65  ← overwritten at listLen==65
inputBuf:  .fill 64, 0   ; $xx+66  ← overwritten at listLen>=66
```

Any `E`, `F`, or `S` command with more than 64 bytes/characters in the list corrupts `parsePos`, `inputLen`, and eventually `inputBuf` — leading to a corrupted parse state for all subsequent commands.

---

## Build Command Reference

```bash
# Assemble debug only
java -jar tools/KickAss.jar src/external/debug/debug.asm -odir build/

# Or build the full image (includes debug)
make
```

Expected success output: `... Writing file : build/debug.prg`
Any line containing `Error` or `at line` means failure — fix before continuing.

---

## File Map

| File | Changes |
|------|---------|
| `src/external/debug/debug.asm` | Task 1 (cuOpRel), Task 2 (parseList) |
| `CHANGELOG.md` | Updated in each task |

---

## Task 1: Fix `cuOpRel` — Eliminate `DebugTemp+1` / `disasmTemp` Alias

**Severity: High** — Every relative branch instruction encountered during `U` corrupts the disassembler's loop counter.

**Files:**
- Modify: `src/external/debug/debug.asm` lines 914–954 (`cuOpRel`)
- Modify: `CHANGELOG.md`

**Fix strategy:** The offset byte and the 16-bit base are never needed at the same time. Read the offset byte first, push it on the stack (`PHA`), compute the base into `val2` ($78–$79, which is safe to clobber inside an operand handler), then `PLA` the offset and add it to `val2` directly — no intermediate zero-page storage needed.

`val2` ($78–$79) is already used as scratch throughout the operand handlers and is not live across operand handler calls. Using it here is consistent with the surrounding code.

- [ ] **Step 1: Locate `cuOpRel` in `debug.asm`**

  Open `src/external/debug/debug.asm`. Search for `cuOpRel:`. The current block (lines 915–954) is:

  ```asm
  cuOpRel:
      lda #'$'
      jsr KernalChROUT
      // Target = currentAddr + 2 + signed_offset
      ldy #1
      lda (currentAddr), y
      sta val2                // offset
      lda currentAddr
      clc
      adc #2
      sta DebugTemp           // base lo
      lda currentAddr + 1
      adc #0
      sta DebugTemp + 1       // base hi  ← BUG: aliases disasmTemp at $7B
      
      lda val2
      bpl cuRelPos
      // Negative offset: add to 16-bit base
      lda DebugTemp
      clc
      adc val2
      tax
      lda DebugTemp + 1
      adc #$FF                // sign extend
      tay
      jmp cuRelPrint
  cuRelPos:
      lda DebugTemp
      clc
      adc val2
      tax
      lda DebugTemp + 1
      adc #0
      tay
  cuRelPrint:
      tya
      jsr printHex8
      txa
      jsr printHex8
      jmp cuDoneLine
  ```

- [ ] **Step 2: Replace the entire `cuOpRel` block with the fixed version**

  The replacement eliminates all writes to `DebugTemp` and `DebugTemp+1`. The offset byte is saved on the hardware stack; the base address goes into `val2`/`val2+1` ($78/$79).

  ```asm
  cuOpRel:
      lda #'$'
      jsr KernalChROUT
      // Target = currentAddr + 2 + signed_offset
      // Save offset on stack; compute base into val2 (avoids DebugTemp+1 = disasmTemp alias)
      ldy #1
      lda (currentAddr), y
      pha                     // push signed offset; restored after base is ready
      
      lda currentAddr
      clc
      adc #2
      sta val2                // base lo ($78)
      lda currentAddr + 1
      adc #0
      sta val2 + 1            // base hi ($79) — safe, no alias with disasmTemp ($7B)
      
      pla                     // restore offset → A; sign still intact
      bpl cuRelPos
      // Negative offset: target = base + sign-extended offset
      clc
      adc val2
      tax                     // target lo → X
      lda val2 + 1
      adc #$FF                // sign extend carry (offset was negative)
      tay                     // target hi → Y
      jmp cuRelPrint
  cuRelPos:
      // Positive offset: target = base + offset
      clc
      adc val2
      tax                     // target lo → X
      lda val2 + 1
      adc #0
      tay                     // target hi → Y
  cuRelPrint:
      tya
      jsr printHex8
      txa
      jsr printHex8
      jmp cuDoneLine
  ```

- [ ] **Step 3: Build debug**

  ```bash
  java -jar tools/KickAss.jar src/external/debug/debug.asm -odir build/
  ```

  Expected: `Writing file : build/debug.prg` with no errors. Fix any assembler errors before proceeding.

- [ ] **Step 4: Smoke-test in VICE — relative branches in count mode**

  Load `debug.prg` from the command64 shell. At the `-` prompt:

  1. `U 1000` — unassemble 16 instructions from $1000. Verify exactly 16 lines appear and the prompt returns cleanly.
  2. `U 1024` or any address that yields a BEQ/BNE/BCC/BCS/BPL/BMI/BVC/BVS — verify the target address printed is correct (it should be the current instruction address + 2 + signed offset) and that the loop still produces 16 lines total.
  3. Known relative branch at a fixed address: `U FF80` — the KERNAL at $FF80+ contains several branch instructions. Confirm correct target address display and correct line count.

- [ ] **Step 5: Smoke-test — relative branches in range mode**

  At the `-` prompt:

  1. `U FF80 FF9F` — disassemble a known KERNAL range containing branches. Verify output stops at or just past $FF9F, not prematurely after the first branch.
  2. `U 1000 1020` — small range in RAM (likely all $00 = BRK, mode IMP — no branch). Verify the range boundary works correctly even without branches as a baseline.

- [ ] **Step 6: Update CHANGELOG.md**

  Add under `[Unreleased]` → `### Fixed`:

  ```
  - debug: cuOpRel no longer writes to DebugTemp+1 ($7B = disasmTemp); base address now
    computed into val2/val2+1 via stack-saved offset, eliminating ZP alias that corrupted
    the U command's row counter after any relative branch instruction
  ```

- [ ] **Step 7: Commit**

  ```bash
  git add src/external/debug/debug.asm CHANGELOG.md
  git commit -m "fix(debug): eliminate DebugTemp+1/disasmTemp ZP alias in cuOpRel"
  ```

---

## Task 2: Fix `parseList` — Add bounds check to prevent `listBuf` overflow

**Severity: Medium** — More than 64 bytes in a single `E`/`F`/`S` list corrupts `parsePos`, `inputLen`, and `inputBuf`, breaking all subsequent commands in the session.

**Files:**
- Modify: `src/external/debug/debug.asm` lines 1153–1156 and 1168–1171 (`parseList`)
- Modify: `CHANGELOG.md`

**Fix strategy:** Add `cpx #64 / bcs plErr` immediately after each `ldx listLen` before the store. `plErr` already exists (`sec / rts`) and is the correct path — it causes the calling command handler to print `error` and return, which is the right behavior when the user's input is too long.

- [ ] **Step 1: Locate `parseList` in `debug.asm`**

  Search for `parseList:`. The hex byte store block (lines 1153–1157) is:

  ```asm
      ldx listLen
      lda HexValLo
      sta listBuf, x
      inc listLen
      jmp plLoop
  ```

  The string character store block (lines 1168–1172) is:

  ```asm
      ldx listLen
      sta listBuf, x
      inc listLen
      iny
      jmp plStrLoop
  ```

- [ ] **Step 2: Add bounds guard to the hex byte path**

  Replace the hex byte store block with:

  ```asm
      ldx listLen
      cpx #64             // listBuf is 64 bytes; index 64 would overflow into parsePos
      bcs plErr
      lda HexValLo
      sta listBuf, x
      inc listLen
      jmp plLoop
  ```

  Note: `cpx` does not affect A. The `lda HexValLo` after the guard still loads the parsed byte correctly.

- [ ] **Step 3: Add bounds guard to the string character path**

  At the string store, A already holds the character from `lda inputBuf, y` (the load happens three lines above). Replace the string character store block with:

  ```asm
      ldx listLen
      cpx #64             // listBuf is 64 bytes; index 64 would overflow into parsePos
      bcs plErr
      sta listBuf, x      // A still holds the character from lda inputBuf,y above
      inc listLen
      iny
      jmp plStrLoop
  ```

- [ ] **Step 4: Build debug**

  ```bash
  java -jar tools/KickAss.jar src/external/debug/debug.asm -odir build/
  ```

  Expected: clean build. Fix any errors before proceeding.

- [ ] **Step 5: Smoke-test in VICE — normal list (under limit)**

  At the `-` prompt:

  1. `F 2000 20FF 00` — fill with one byte. Verify the fill completes and returns to the prompt.
  2. `E 2000 41 42 43 44` — enter four bytes. Confirm with `D 2000` that $2000–$2003 contains `41 42 43 44`.
  3. `S 2000 20FF "hello"` — search for a five-character string. Verify no crash.

- [ ] **Step 6: Smoke-test — list at the limit and beyond**

  1. Construct a fill command with exactly 64 hex bytes (32 pairs). Example start:
     `F 2000 207F 00 01 02 03 04 05 06 07 08 09 0A 0B 0C 0D 0E 0F 10 11 12 13 14 15 16 17 18 19 1A 1B 1C 1D 1E 1F 20 21 22 23 24 25 26 27 28 29 2A 2B 2C 2D 2E 2F 30 31 32 33 34 35 36 37 38 39 3A 3B 3C 3D 3E 3F`
     Verify: command completes without error (64 bytes exactly hits the guard boundary on the 65th, which doesn't exist here since we stopped at 64).

  2. Add one more byte to push to 65 hex bytes:
     `F 2000 207F 00 01 02 ... 3F 40`
     Expected: `error` printed, no crash, no corruption of subsequent commands.

  3. After the error, type `D 2000` — verify the dump still works correctly (confirms `parsePos`/`inputLen`/`inputBuf` are not corrupted).

- [ ] **Step 7: Update CHANGELOG.md**

  Add under `[Unreleased]` → `### Fixed`:

  ```
  - debug: parseList now rejects lists longer than 64 bytes (returns error) instead of
    overflowing listBuf into parsePos, inputLen, and inputBuf
  ```

- [ ] **Step 8: Commit**

  ```bash
  git add src/external/debug/debug.asm CHANGELOG.md
  git commit -m "fix(debug): add bounds check in parseList to prevent listBuf overflow"
  ```

---

## Summary

| Task | Severity | Root Cause | Lines Changed |
|------|----------|------------|---------------|
| 1 — cuOpRel ZP alias | High | `DebugTemp+1` ($7B) aliases `disasmTemp` ($7B); cuOpRel overwrites it, corrupting U command loop counter | ~20 lines rewritten in cuOpRel |
| 2 — parseList overflow | Medium | No `listLen < 64` guard before `sta listBuf, x`; overflow corrupts parsePos/inputLen/inputBuf | 2 × 2-line guard insertions |

Total net new lines: ~6. Both fixes are fully isolated within `debug.asm`. No cross-file dependencies.
