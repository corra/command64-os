# Raw Findings: Full Codebase Review (July 3, 2026)

**Date**: 2026-07-03
**Scope**: All source files in the core OS (`src/command64/*.asm`, `src/*.asm`, `include/*.inc`), external apps/tests (`src/external/*/*.asm`, `tests/src/*.asm`), and the SPA site workspace (`command64-os-site/` HTML/CSS/JS).
**Method**: Independent source review and structural trace focusing on logical correctness, boundary conditions, zero-page register usage, and hardware compatibility.

---

## Findings Detailed Logs

### 1. [VMM] vmmComputeAddress completely ignores VmmBank ZP variable (Critical Bug)
* **File**: [src/command64/vmm.asm](file:///home/morgan/development/c64/command64-os/src/command64/vmm.asm#L318-L382)
* **Code Segment**: `vmmComputeAddress` private function.
* **Analysis**:
  `vmmComputeAddress` computes the 20-bit physical REU address using the formula `Address = (Segment << 4) + Offset`.
  The code retrieves the Segment values from `VmmSegLo` ($68) and `VmmSegHi` ($69):
  ```asm
  lda VmmSegLo
  asl
  ...
  lda VmmSegHi
  lsr
  lsr
  lsr
  lsr
  tay // Y holds the bank byte (SegHi >> 4)
  ```
  It then sets `REU_REU_BANK` directly to `Y` (plus any carry from offset addition):
  ```asm
  tya
  adc #0
  sta REU_REU_BANK
  ```
  However, `VmmSegHi` only holds the bank-relative page offset (0-255) returned from allocation. The 1MB block index itself is returned in `VmmBank` (ZP $6C). Since `vmmComputeAddress` never loads or adds `VmmBank`, the bank calculation is limited strictly to `VmmSegHi >> 4` (mapping everything to Bank 0 of the 1MB region).
* **Failure Scenario**: 
  When allocating REU memory beyond the first 1MB boundary, `vmmAlloc` returns a non-zero `VmmBank` (1-15). If a program subsequently attempts to read or write bytes in this space using `vmmReadByte`/`vmmWriteByte`, the memory operations are silently redirected to bank 0. This corrupts environment variables or other code/data active in the first 1MB block.

---

### 2. [SHELL] Missing VmmBank initialization in environment operations (High Bug)
* **File**: [src/command64/shell.asm](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm#L1527-L1545)
* **Code Segment**: `cmdSetPrint`, `envAppend`, `envSearch`, `envDelete`, `envFindEnd`, `envPrintVal`.
* **Analysis**:
  All environment-variable operations read/write from the environment segment stored in `EnvSegmentLo/Hi`. They load `EnvSegmentLo/Hi` into `VmmSegLo/Hi` before calling `vmmReadByte`/`vmmWriteByte`.
  However, none of these routines load the corresponding environment bank (stored on allocation) into `VmmBank` (ZP $6C).
  Today, this works only because `vmmComputeAddress` has the bug described in Finding 1 (it ignores `VmmBank` and defaults to bank 0, where the environment segment is allocated).
* **Failure Scenario**:
  If the `vmmComputeAddress` bug is fixed to respect `VmmBank` without updating the shell environment routines, any environment variable read/write will use whatever random value happens to be left in zero-page register `$6C` (`VmmBank`) by other operations, causing immediate reads/writes to garbage banks and breaking the environment block entirely.

---

### 3. [SHELL] ccCopyDest has no bounds check on destination name length (High Bug)
* **File**: [src/command64/shell.asm](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm#L1059-L1071)
* **Code Segment**: `cmdCopy` -> `ccCopyDest` loop.
* **Analysis**:
  While `ccCopySrc` was updated with a bounds check `cpx #40` (remediating R3 in the previous pass), the destination copy loop `ccCopyDest` still lacks any length checks:
  ```asm
  ccCopyDest:
      lda (PrintPtrLo), y
      beq ccGotDest
      cmp #' '
      beq ccGotDest
      sta DestBuf, x
      inx
      iny
      jmp ccCopyDest
  ```
  `DestBuf` is defined at `$03CA` and is only 40 bytes.
* **Failure Scenario**:
  If a user inputs a destination path longer than 40 characters (e.g., `copy file.prg 8:this_is_an_extremely_long_destination_filename_that_exceeds_limits.prg`), it will overflow `DestBuf` (which ends at `$03F1`). The write will corrupt the end of the Cassette Buffer and, if the name exceeds 54 characters, will write directly into Screen RAM (starting at `$0400`), causing screen corruption or crash.

---

### 4. [PATH] Mismatch in findFile header documentation (Low/Documentation)
* **File**: [src/command64/path.asm](file:///home/morgan/development/c64/command64-os/src/command64/path.asm#L9-L19)
* **Code Segment**: `findFile` header comment.
* **Analysis**:
  The function header documentation claims:
  `// If not found and no extension provided, tries again with .prg.`
  However, automatic `.prg` appending was removed from the actual implementation:
  `// Note: Automatic .prg appending removed as disk entries no longer include extensions.`
* **Impact**: Minor developer confusion when reading the function header comments.

---

### 5. [TEST] Leftover dead instructions in filetest.asm (Low/Cleanup)
* **File**: [tests/src/filetest.asm](file:///home/morgan/development/c64/command64-os/tests/src/filetest.asm#L50-L53)
* **Code Segment**: `filetest` WRITE call preparation.
* **Analysis**:
  The setup for the file write contains redundant pointer loads:
  ```asm
      ldx #<writeData
      ldy #>fname             // wait, writeData
      ldx #<writeData
      ldy #>writeData
  ```
  The first two instructions are immediately overwritten by the next two.
* **Impact**: Unnecessary bytes in test binary, leftover comments, and maintaining bad patterns.

---

### 6. [SITE] Commented-out Markdown Alert processing in app.js (Low/Omission)
* **File**: [app.js (site workspace)](file:///home/morgan/development/c64/command64-os-site/app.js#L325-L327)
* **Code Segment**: `loadDocumentationFile` function.
* **Analysis**:
  The code contains a comment:
  `// Process GitHub markdown alerts into HTML blockquotes`
  But the actual line underneath only reads:
  `let processedMarkdown = markdown;`
  There is no regex or processing logic to translate GitHub Alerts (`> [!NOTE]`, `> [!IMPORTANT]`) into CSS/HTML alert divs.
* **Impact**: GitHub Markdown Alerts in doc files render as plain raw text blockquotes on the site rather than styled alert callouts.

---

### 7. [PETSCI] Outdated zero-page address comment in petPrintString (Low/Documentation)
* **File**: [src/command64/petsci.asm](file:///home/morgan/development/c64/command64-os/src/command64/petsci.asm#L20)
* **Code Segment**: `petPrintString` comment header.
* **Analysis**:
  The comment states:
  `// Uses:   PrintPtrLo ($22), PrintPtrHi ($23)`
  However, `include/command64.inc` sets `PrintPtrLo = $FB` and `PrintPtrHi = $FC`.
* **Impact**: Developer confusion regarding register allocation.
