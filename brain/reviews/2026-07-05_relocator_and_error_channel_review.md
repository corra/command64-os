# Code Review: Binary Relocator & Drive Error Channel Draining

This review analyzes the implementation of the Phase 6B Binary Relocator and the IEC Drive Error Channel draining mechanism in the uncommitted changes of the `command64-os` codebase.

## Scope

The following files and changes were reviewed:
1. **`src/command64/loader.asm`** — Binary Relocator (`aptRelocate`) implementation.
2. **`src/command64/file.asm`** — Drive status reading (`readErrorChannel` / `drainOpenErrorChannel`).
3. **`src/command64/path.asm`** — File existence check (`checkExistence`) integration.
4. **`src/command64/shell.asm`** — Integration of relocator into shell load and new `FLUSH` command.
5. **`src/external/label/label.asm`** — Interactive mode when no volume name argument is supplied.

---

## Findings

### 1. [CRITICAL] Truncation of Non-Relocatable Files via Unrestored `TempLo/Hi` on Relocation Failure
*   **File/Lines:** `src/command64/loader.asm`
*   **Issue:** At the beginning of `aptRelocate`, the routine subtracts `6` from `TempLo/Hi` to read the relocation footer fields:
    ```assembly
    sec
    lda TempLo
    sbc #6
    sta TempLo
    lda TempHi
    sbc #0
    sta TempHi
    ```
    If the Magic bytes do not match `'R'` and `'6'` (indicating a standard, non-relocatable program), the routine immediately exits with the Carry flag set:
    ```assembly
    ldy #4
    lda (TempLo),y          // Magic byte 0: 'R'
    cmp #$52
    beq aptRelocateMagic0Ok
    sec
    rts
    ```
    However, **it never restores the 6 bytes subtracted from `TempLo/Hi`.**
    Because the shell calling sequence (`shell.asm`) proceeds directly to call `aptRegister` (which uses `TempLo/Hi` to compute and record the loaded application's size in the app table), this leaves standard loaded binaries registered with a size that is **6 bytes smaller** than their actual size. This can lead to subsequent memory-management errors or truncated execution bounds.
*   **Remediation:** Introduce a failure path (`aptRelocateFail`) that adds `6` back to `TempLo/Hi` to restore them before returning with Carry set.

### 2. [LOW] Interactive Prompt Buffer Input Overflow in `LABEL`
*   **File/Lines:** `src/external/label/label.asm` (lines 167-178)
*   **Issue:** The newly implemented interactive prompt in `label.asm` correctly checks if the character count reached 16 (`cpy #16`) and ignores new characters (only accepting `DEL` and `RETURN`). However, if the user types exactly 16 characters and hits `RETURN`, `Y` is `16`.
    The loop terminates and jumps to `openChannels` with the buffer fully filled. This is correct. But if they press backspace when at 16 characters, `Y` is decremented correctly.
    One minor note: The prompt is printed using the `DOS_PRINT_STR` API via `jsr $1000`. This is clean and matches the local convention.
*   **Remediation:** None required (behavior is correct and safe), but it is a good pattern for interactive commands.

---

## Code Review Diagnostics

### Analysis of `aptRelocate` Loop Boundary
```assembly
aptRelocateLoop:
    lda PrintPtrLo
    cmp TempLo
    bne aptRelocatePatchOne
    lda PrintPtrHi
    cmp TempHi
    beq aptRelocateLoopDone // table pointer caught up to FooterPtr: done
```
*   **Evaluation:** This loop terminates when the walker `PrintPtrLo/Hi` reaches `TempLo/Hi` (the start of the footer). Since `TableStart = FooterPtr - TableSize * 2` and `PrintPtr` is incremented by `2` on each iteration, it is guaranteed to land exactly on `TempLo/Hi`. If `TableSize` is 0, the loop does not execute a single iteration because the initial comparison evaluates to equal and jumps to `aptRelocateLoopDone`. This is correct.

### Analysis of `drainOpenErrorChannel`
```assembly
drainOpenErrorChannel:
    ldy #0
docLoop:
    jsr KernalREADST
    bne docDone              // EOI or error — nothing more to read
    jsr KernalChRIN
    cmp #PetCr
    beq docDone
    sta SourceBuf, y
    ...
```
*   **Evaluation:** Checking `KernalREADST` at the start of the loop and before calling `KernalChRIN` is the correct and standard C64 KERNAL convention. Since the KERNAL status byte reflects the state of the serial transmission *after* the previous byte was read (or flags EOI during the transmission of the last byte), this sequence correctly reads the last character and terminates on EOI.

---

## Proposed Remediation Plan

We will modify `src/command64/loader.asm` to restore `TempLo/Hi` on relocation failure:

```diff
     ldy #4
     lda (TempLo),y          // Magic byte 0: 'R'
     cmp #$52
     beq aptRelocateMagic0Ok
-    sec
-    rts
+    jmp aptRelocateFail
 aptRelocateMagic0Ok:
     ldy #5
     lda (TempLo),y          // Magic byte 1: '6'
     cmp #$36
     beq aptRelocateMagic1Ok
-    sec
-    rts
+    jmp aptRelocateFail
 aptRelocateMagic1Ok:
...
+aptRelocateFail:
+    clc
+    lda TempLo
+    adc #6
+    sta TempLo
+    lda TempHi
+    adc #0
+    sta TempHi
+    sec                     // indicate failure
+    rts
```
