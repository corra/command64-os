# Investigation & Implementation Plan - File I/O Bug Fix

## 1. Goal

Resolve the file read/write bug where `test_filetest` outputs `read from file: G` and the file on disk appears to be missing the first two characters (`"He"`) when loaded via the `debug` utility.

---

## 2. Investigation & Findings

### The "Missing He" Mystery
* **Symptom**: When `test_filetest` writes `"HELLO FROM COMMAND64!"` and we load the file using the `debug` utility, the contents appear in memory starting with `"llo from command 64!"` (rendered in mixed-case as lowercase `"llo..."`).
* **Explanation**: The C64 KERNAL `LOAD` routine (which `debug` uses under the hood to load files) always interprets the first two bytes of any file as a 16-bit destination address. When `debug` loads `TEST.TXT`, it consumes the first two bytes (`'H'` and `'E'`, or `$48` and `$45`) as the load address `$4548`, and loads the rest of the file (`"LLO FROM COMMAND64!"`) starting at that address. In mixed-case mode, `"LLO..."` is displayed as `"llo..."`.
* **Conclusion**: The write operation is completely correct and writes all 21 bytes to disk. The "missing" first two bytes are a red herring caused by `debug` using `KernalLOAD` to load a raw data file without a C64 PRG header.

### The "Read from file: G" Bug (Task 24)
* **Symptom**: When `test_filetest` reads the file using the byte-by-byte file read API (`DOS_READ_FILE` / `fileRead`), it gets `"G"` (a single byte) instead of the file contents.
* **Explanation**:
  1. In `fileRead` (`src/command64/file.asm`), `KernalREADST` ($90) is checked *before* performing the first `KernalChRIN` on the channel.
  2. If the status channel LFN 15 was read previously (which happens during `fileOpen` for Read via `readErrorChannel`), the KERNAL status register `$90` retains the EOI (End of File) status (`$40`).
  3. When `fileRead` starts, it clears `$90` to `0`. However, the KERNAL status checking before/during the first byte read is misaligned, causing the loop to prematurely abort or fail to read/store correctly.
* **Conclusion**: We need to query `KernalREADST` *after* calling `KernalChRIN` to determine the status of the read byte, rather than checking it before any byte has been requested on the channel.

---

## 3. Proposed Changes

### File System Module

#### [MODIFY] [file.asm](file:///home/morgan/development/c64/command64-os/src/command64/file.asm)

We will rewrite the `fileRead` loop in `src/command64/file.asm` to check `KernalREADST` after calling `KernalChRIN`. If status is non-zero, we will verify whether it was a normal EOI (bit 6 = `$40`), in which case the last read byte is still valid and must be stored before exiting.

```assembly
// Proposed fix to fileRead loop:
frDoRead:
    // Restore pointer clobbered by KERNAL ChRIN
    lda IoBufPtrLo
    sta PrintPtrLo
    lda IoBufPtrHi
    sta PrintPtrHi
    
    jsr KernalChRIN         // Read char from channel
    
    pha                     // Save the character read
    jsr KernalREADST        // Check status immediately after read
    sta TempHi              // Save status in TempHi
    pla                     // Restore character
    
    // Check if the read succeeded (no error/EOF)
    ldy TempHi
    bne frHandleStatus      // If status is non-zero, handle EOF/error
    
    // Normal case: store byte, advance, and loop
    ldy #0
    sta (PrintPtrLo), y
    
    inc IoBufPtrLo
    bne frSkipInc
    inc IoBufPtrHi
frSkipInc:
    inc ReadCountLo
    bne frLoop
    inc ReadCountHi
    jmp frLoop

frHandleStatus:
    // If the status has EOI (bit 6 = $40) set, this is the last byte of the file.
    // We should still store this byte, increment the count, and then exit.
    // If it has any other error bits (e.g. timeout, device not present), we discard it.
    tya
    and #$BF                // Mask out EOI bit
    bne frDone              // If other error bits are set, exit without storing
    
    // EOI case: store the final byte, increment count, and then exit
    ldy #0
    sta (PrintPtrLo), y
    
    inc ReadCountLo
    bne frDone
    inc ReadCountHi
frDone:
    jsr KernalCLRCHN        // Reset to keyboard
    rts
```

---

## 4. Verification Plan

### Automated/Manual Verification
1. Run `make` to compile the core OS and the test binaries.
2. Run `test_filetest` in the C64 emulator and verify that the output is:
   `read from file: hello from command64!` (rendered in lowercase/uppercase appropriately).
