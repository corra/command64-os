# API/VMM Bug Remediation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix five confirmed bugs in `api.asm`, `vmm.asm`, `tests/src/vmmtest.asm`, and `tests/build_tests.sh` that collectively render the INT 21h service bus completely non-functional.

**Architecture:** Each fix is a surgical edit to a single file. No interfaces change. The five bugs are independent and can be fixed in any order, but Tasks 1–3 (all in `api.asm`/`vmm.asm`) should be committed together as a single logical unit since they all affect the same runtime path (a `DOS_ALLOC_MEM` → `DOS_FREE_MEM` round-trip).

**Tech Stack:** KickAssembler 5.25 (`tools/KickAss.jar`), 6502 assembly, C64 target, VICE emulator or real hardware for runtime verification.

---

## Bug Report Summary

| ID | File | Lines | Symptom | Root Cause |
|----|------|-------|---------|------------|
| A  | `src/command64/api.asm` | 108–120 | Carry flag never set/cleared; saved X register corrupted on every API call | `ahSetCarry`/`ahClearCarry` call `tsx` after a `jsr` pushes 2 bytes; `$0104,x` addresses saved X, not saved P |
| B  | `src/command64/vmm.asm` | 107–116, 122–132 | `vmmAlloc` corrupts zero page when backtracking; wrong allocations returned | `vaSearchReset`/`vaCommitAlloc` restore `PrintPtrHi` from the raw block index (0–15) instead of `$C0 + index` |
| E  | `src/command64/api.asm` | 83–91 | `DOS_FREE_MEM` always returns error regardless of actual `vmmFree` result | `beq _afOk` tests Z flag set by `tsx` (SP ≈ $FF, never zero); `sta` does not affect flags |
| F  | `tests/build_tests.sh` | 1, 10–14 | `apitest.asm` and `vmmtest.asm` are never assembled; script silently reports success | Paths use `src/*.asm` instead of `tests/src/*.asm`; shebang is malformed |
| J  | `tests/src/vmmtest.asm` | 27–37 | `DOS_FREE_MEM` receives garbage page/bank; test always fails at the free step | Intervening `DOS_PRINT_STR` BRK overwrites X/Y with message pointer before the free call |

---

## File Map

| File | Change |
|------|--------|
| `src/command64/api.asm` | Fix offset in `ahSetCarry`/`ahClearCarry` (Bug A); fix branch in `ahFreeMem` (Bug E) |
| `src/command64/vmm.asm` | Fix `PrintPtrHi` reconstruction in `vaSearchReset` and `vaCommitAlloc` (Bug B) |
| `tests/src/vmmtest.asm` | Save alloc result to ZP before print BRK; restore before free (Bug J) |
| `tests/build_tests.sh` | Fix shebang and source paths (Bug F) |

---

## Task 1: Fix `ahSetCarry`/`ahClearCarry` stack offset (Bug A)

**File:** `src/command64/api.asm`, lines 108–120

**The bug:** Both helpers call their own `tsx` after being entered via `jsr`. The `jsr` pushes a 2-byte return address onto the stack before `tsx` runs, so `X_helper = SP_original − 2`. Therefore `$0104,x` (inside the helper) addresses `$0102 + SP_original` = the saved **X register**, not saved P. Every `ahSetCarry`/`ahClearCarry` call corrupts the saved X register while leaving the carry bit in P untouched. The correct offset is `$0106,x`.

This is consistent whether the helpers are called from the top-level dispatch in `apiHandler` or from within `ahAllocMem`/`ahFreeMem`, because in both cases there is exactly one intervening `jsr` frame (2 bytes) at the time `tsx` runs inside the helper.

- [ ] **Step 1: Open `src/command64/api.asm` and locate the helpers**

  Current code at lines 108–120:
  ```asm
  ahSetCarry:
      tsx
      lda $0104, x            // Load pushed P
      ora #$01                // Set bit 0 (Carry)
      sta $0104, x
      rts

  ahClearCarry:
      tsx
      lda $0104, x            // Load pushed P
      and #$FE                // Clear bit 0 (Carry)
      sta $0104, x
      rts
  ```

- [ ] **Step 2: Apply the fix — change `$0104,x` to `$0106,x` in both helpers**

  Replace with:
  ```asm
  ahSetCarry:
      tsx
      lda $0106, x            // Load pushed P (+2 offset for JSR return addr on stack)
      ora #$01                // Set bit 0 (Carry)
      sta $0106, x
      rts

  ahClearCarry:
      tsx
      lda $0106, x            // Load pushed P (+2 offset for JSR return addr on stack)
      and #$FE                // Clear bit 0 (Carry)
      sta $0106, x
      rts
  ```

- [ ] **Step 3: Verify the fix assembles cleanly**

  Run from the project root:
  ```bash
  java -jar tools/KickAss.jar build/command64.asm -odir build/
  ```
  Expected: no errors, `build/command64.prg` updated. If KickAss reports an unresolved symbol on `apiHandler`, verify `build/command64.asm` contains `#import "../src/command64/api.asm"` and `Api` is in the `.file` segment list.

- [ ] **Step 4: Stage and hold for combined commit with Tasks 2 and 3**

  ```bash
  git add src/command64/api.asm
  ```

---

## Task 2: Fix `vmmAlloc` pointer restoration (Bug B)

**File:** `src/command64/vmm.asm`, lines 82–86, 107–116, 122–132

**The bug:** At `vaFoundPotential` (line 85–86), `TempLo` (the block counter, 0–15) is saved to `VmmOffHi`. When `vaSearchReset` and `vaCommitAlloc` restore the MCT scan pointer, they do `lda VmmOffHi : sta PrintPtrHi`, setting the pointer high byte to 0–15 instead of `$C0`–`$CF` (where the MCT lives at `VmmMctBase = $C000`). The fix is to reconstruct the correct high byte as `>VmmMctBase + VmmOffHi`. This matches the pattern already used correctly in `vmmFree`. `VmmOffHi` itself should remain a raw block index (0–15) because `vaCommitAlloc` uses it at line 177–178 to set `VmmBank` for the caller.

- [ ] **Step 1: Open `src/command64/vmm.asm` and locate `vaSearchReset` at line 107**

  Current code:
  ```asm
  vaSearchReset:
      // Restore pointer and continue search
      lda VmmOffHi
      sta PrintPtrHi
      ldy VmmOffLo
      iny
      bne vaSearchLoop
      inc PrintPtrHi
      inc TempLo
      jmp vaBlockLoop
  ```

- [ ] **Step 2: Fix `vaSearchReset` to reconstruct the MCT address**

  Replace the two-instruction restore with a three-instruction reconstruct:
  ```asm
  vaSearchReset:
      // Restore pointer and continue search
      // VmmOffHi holds the block index (0-15); add MCT base to get actual page addr
      lda #>VmmMctBase
      clc
      adc VmmOffHi
      sta PrintPtrHi
      ldy VmmOffLo
      iny
      bne vaSearchLoop
      inc PrintPtrHi
      inc TempLo
      jmp vaBlockLoop
  ```

- [ ] **Step 3: Locate `vaCommitAlloc` at line 122 and apply the same fix**

  Current code at lines 126–129:
  ```asm
  vaCommitAlloc:
      // Mark pages in MCT.
      // Start page = PAGE_HEAD, Tail pages = PAGE_TAIL

      // Restore start position
      lda VmmOffHi
      sta PrintPtrHi
      ldy VmmOffLo
  ```

  Replace the two-instruction restore:
  ```asm
  vaCommitAlloc:
      // Mark pages in MCT.
      // Start page = PAGE_HEAD, Tail pages = PAGE_TAIL

      // Restore start position; reconstruct MCT page addr from block index
      lda #>VmmMctBase
      clc
      adc VmmOffHi
      sta PrintPtrHi
      ldy VmmOffLo
  ```

- [ ] **Step 4: Verify the fix assembles cleanly**

  ```bash
  java -jar tools/KickAss.jar build/command64.asm -odir build/
  ```
  Expected: no errors.

- [ ] **Step 5: Stage and hold for combined commit with Tasks 1 and 3**

  ```bash
  git add src/command64/vmm.asm
  ```

---

## Task 3: Fix `ahFreeMem` branch condition (Bug E)

**File:** `src/command64/api.asm`, lines 83–91

**The bug:** After `jsr vmmFree` returns status in A, the code does `tsx : sta $0103,x : beq _afOk`. The `sta` instruction does **not** affect processor flags on 6502. The `tsx` sets N/Z based on the stack pointer value (~$FF), which is never zero. Therefore `beq _afOk` is always false — `vmmFree` always appears to fail. The fix matches the pattern already correct in `ahAllocMem` (lines 69–70): reload A from the stack slot after writing it, so the Z flag reflects the status value.

- [ ] **Step 1: Open `src/command64/api.asm` and locate `ahFreeMem` at line 77**

  Current code at lines 83–91:
  ```asm
      jsr vmmFree
      tsx
      sta $0103, x            // Return status in A
      beq _afOk               // Z is from tsx (SP ~$FF) — never zero; bug
      jsr ahSetCarry
      jmp ahDone
  _afOk:
      jsr ahClearCarry
      jmp ahDone
  ```

- [ ] **Step 2: Apply the fix — reload A after the sta to set flags from the status value**

  ```asm
      jsr vmmFree
      tsx
      sta $0103, x            // Return status in A
      lda $0103, x            // Reload to set Z flag from status value (sta does not set flags)
      beq _afOk
      jsr ahSetCarry
      jmp ahDone
  _afOk:
      jsr ahClearCarry
      jmp ahDone
  ```

- [ ] **Step 3: Assemble and commit Tasks 1, 2, and 3 together**

  ```bash
  java -jar tools/KickAss.jar build/command64.asm -odir build/
  git add src/command64/api.asm src/command64/vmm.asm
  git commit -m "fix(api,vmm): correct stack offsets, MCT pointer reconstruction, and free branch"
  ```
  Expected commit message covers all three related bugs in one logical unit.

---

## Task 4: Fix `build_tests.sh` paths and shebang (Bug F)

**File:** `tests/build_tests.sh`

**The bug:** Line 1 contains `tests/bin/bash` (a malformed shebang — missing `#!`). Lines 10–14 reference `src/*.asm` but test sources live under `tests/src/`. The script is designed to be run from the project root where `tools/KickAss.jar` resolves correctly, so only the source paths need updating (not the jar path). Without this fix, `apitest.asm` and `vmmtest.asm` are never compiled.

- [ ] **Step 1: Open `tests/build_tests.sh` and apply both fixes**

  Current file:
  ```bash
  tests/bin/bash
  # tests/build_tests.sh

  KICKASS="tools/KickAss.jar"
  OUTDIR="tests/bin"

  mkdir -p $OUTDIR

  echo "Compiling tests..."
  java -jar $KICKASS src/hello.asm -odir $OUTDIR
  java -jar $KICKASS src/color.asm -odir $OUTDIR
  java -jar $KICKASS src/extcls.asm -odir $OUTDIR
  java -jar $KICKASS src/apitest.asm -odir $OUTDIR
  java -jar $KICKASS src/vmmtest.asm -odir $OUTDIR

  echo "Done."
  ```

  Replace with:
  ```bash
  #!/bin/bash
  # tests/build_tests.sh
  # Run from the project root: bash tests/build_tests.sh

  set -e

  KICKASS="tools/KickAss.jar"
  SRCDIR="tests/src"
  OUTDIR="tests/src/bin"

  mkdir -p $OUTDIR

  echo "Compiling tests..."
  java -jar $KICKASS $SRCDIR/hello.asm    -odir $OUTDIR
  java -jar $KICKASS $SRCDIR/color.asm   -odir $OUTDIR
  java -jar $KICKASS $SRCDIR/extcls.asm  -odir $OUTDIR
  java -jar $KICKASS $SRCDIR/apitest.asm -odir $OUTDIR
  java -jar $KICKASS $SRCDIR/vmmtest.asm -odir $OUTDIR

  echo "Done. Binaries in $OUTDIR"
  ```

  Note: `set -e` added so any KickAss failure stops the script instead of silently continuing. `OUTDIR` updated to `tests/src/bin` to match where the existing compiled `.prg` files already live.

- [ ] **Step 2: Verify the script runs from the project root**

  ```bash
  bash tests/build_tests.sh
  ```
  Expected output ends with `Done. Binaries in tests/src/bin`. Each `java -jar` line should complete without error. If KickAss is not on the path, ensure `tools/KickAss.jar` exists.

- [ ] **Step 3: Commit**

  ```bash
  git add tests/build_tests.sh
  git commit -m "fix(tests): correct shebang and source paths in build_tests.sh"
  ```

---

## Task 5: Fix `vmmtest.asm` register preservation across print BRK (Bug J)

**File:** `tests/src/vmmtest.asm`, lines 24–37

**The bug:** After `DOS_ALLOC_MEM` returns the page index in X and bank in Y (via `ahAllocMem`'s stack manipulation), the test calls `DOS_PRINT_STR` with `ldx #<msgOk : ldy #>msgOk`. The KERNAL BRK handler pushes A/X/Y and restores them on exit via `$EA81`, so after the print BRK returns X = `<msgOk` and Y = `>msgOk`. The subsequent `DOS_FREE_MEM` at line 35 then uses these garbage values as the page/bank to free, hitting `vmmFree`'s `PAGE_HEAD` guard and returning `VMM_ERR_INVALID` every time.

The fix is to save X and Y to ZP scratch locations (`TempLo`/`TempHi`, defined as `$64`/`$65` in `command64.inc`) immediately after the alloc BRK, and restore them before the free BRK.

- [ ] **Step 1: Open `tests/src/vmmtest.asm` and locate the alloc-print-free sequence (lines 17–37)**

  Current code:
  ```asm
      // 2. Request 1 page (256 paragraphs = $0100)
      lda #DOS_ALLOC_MEM
      ldx #$00
      ldy #$01
      brk
      .byte 0
      // Returns Status in A, Page Index (SegHi) in X, Bank in Y
      bcs alloc_fail

      // 3. Print success message
      lda #DOS_PRINT_STR
      ldx #<msgOk
      ldy #>msgOk
      brk
      .byte 0

      // 4. Free the memory
      // X and Y still hold the page/bank returned by alloc
      lda #DOS_FREE_MEM
      brk
      .byte 0
      bcs free_fail
  ```

- [ ] **Step 2: Add ZP save/restore around the print call**

  ```asm
      // 2. Request 1 page (256 paragraphs = $0100)
      lda #DOS_ALLOC_MEM
      ldx #$00
      ldy #$01
      brk
      .byte 0
      // Returns Status in A, Page Index in X, Bank in Y
      bcs alloc_fail

      // Save alloc result before print call clobbers X/Y
      // TempLo ($64) = Page Index, TempHi ($65) = Bank
      stx $64
      sty $65

      // 3. Print success message
      lda #DOS_PRINT_STR
      ldx #<msgOk
      ldy #>msgOk
      brk
      .byte 0

      // 4. Free the memory — restore page/bank saved before the print
      ldx $64
      ldy $65
      lda #DOS_FREE_MEM
      brk
      .byte 0
      bcs free_fail
  ```

  Using raw addresses `$64`/`$65` keeps the test self-contained without requiring a header import. If the test is later updated to import `command64.inc`, replace `$64`/`$65` with `TempLo`/`TempHi`.

- [ ] **Step 3: Rebuild the test and verify it assembles**

  ```bash
  bash tests/build_tests.sh
  ```
  Expected: `tests/src/bin/vmmtest.prg` updated with no errors.

- [ ] **Step 4: Commit**

  ```bash
  git add tests/src/vmmtest.asm
  git commit -m "fix(tests): save/restore alloc result across print BRK in vmmtest"
  ```

---

## Verification (After All Tasks)

After all five tasks are committed, do a full rebuild and test-compile to confirm nothing was broken:

```bash
# Full shell binary
java -jar tools/KickAss.jar build/command64.asm -odir build/

# All test programs
bash tests/build_tests.sh
```

Both commands should complete with no errors.

**Runtime verification on emulator/hardware:**
1. Load `build/command64.prg` into VICE (`x64 build/command64.prg`)
2. At the `C64:> ` prompt, run `apitest` (load `tests/src/bin/apitest.prg` to `$2000`, then `SYS 8192`). Expected: `"Service Bus API: String output works!"` prints and returns to shell.
3. Run `vmmtest` similarly. Expected: `"Allocation successful!"` then `"Deallocation successful. Test complete."` — no `"Error:"` messages.

---

## Self-Review Checklist

- [x] All 5 bugs from the code review have a corresponding task
- [x] No "TBD" or placeholder steps — every step contains exact code
- [x] Function names, ZP addresses, and label names are consistent with the actual source files
- [x] Tasks 1–3 are staged together and committed as one logical unit (both are in `api.asm`/`vmm.asm` and affect the same runtime path)
- [x] Task 4 uses the existing `tests/src/bin` output directory to avoid breaking the existing `.prg` file locations
- [x] Task 5 uses raw ZP addresses to keep the test self-contained
