# Peer Review: FileOpen PRG Type Default and File Read/Write Fixes

This review documents the peer evaluation of the proposed plan [2026-07-10-fileopen-prg-type-default-fix.md](file:///home/morgan/development/c64/command64-os/brain/plans/2026-07-10-fileopen-prg-type-default-fix.md) and its referenced sub-plan [2026-07-10-file-io-readst-bug-fix.md](file:///home/morgan/development/c64/command64-os/brain/plans/2026-07-10-file-io-readst-bug-fix.md). The Companion Agent performed this analysis to ensure technical compatibility, correct assembly implementation, and KERNAL compliance.

---

## Scope

The following plans and related source files were reviewed:

1. **`brain/plans/2026-07-10-fileopen-prg-type-default-fix.md`** — Core plan.
2. **`brain/plans/2026-07-10-file-io-readst-bug-fix.md`** — Referenced read status plan.
3. **`src/command64/file.asm`** — File subsystem implementation.
4. **`tests/src/filetest/filetest.s`** — File read/write verification test.
5. **`tests/src/handletest/handletest.s`** — File handle stress test.
6. **`docs/api-reference.md`** and **`wiki/api-reference.md`** — API documentation.

---

## Technical Findings & Vulnerability Analysis

### 1. Fatal Parameter Loss in `frDone` / `frHandleStatus`

* **File:** [brain/plans/2026-07-10-file-io-readst-bug-fix.md](file:///home/morgan/development/c64/command64-os/brain/plans/2026-07-10-file-io-readst-bug-fix.md) (lines 67-85)
* **Vulnerability:** The proposed assembly code for handling EOF/errors in `fileRead` branches directly to `frDone`. However, the proposed `frDone` only performs `KernalCLRCHN` and `rts`:

    ```assembly
    frDone:
        jsr KernalCLRCHN        // Reset to keyboard
        rts
    ```

    This completely bypasses the original function's output plumbing where `ReadCountLo/Hi` are copied into the output registers `HexValLo/Hi` and the carry flag is cleared (`clc`):

    ```assembly
    // Original output sequence:
    lda ReadCountLo
    sta HexValLo
    lda ReadCountHi
    sta HexValHi
    clc
    rts
    ```

    Bypassing this sequence will cause `fileRead` to return garbage byte counts and unset success indicators, causing callers (such as `test_filetest`, which relies on `HexValLo` to null-terminate the buffer) to crash or fail.
* **Remediation:** Restore the output parameters and Carry status updating in the exit paths. The final assembly routines should look like this:

    ```assembly
    frDoneOK:
        jsr KernalCLRCHN        // Reset to keyboard
        lda ReadCountLo
        sta HexValLo
        lda ReadCountHi
        sta HexValHi
        clc                     // Carry clear = Success
        rts

    frReadError:
        jsr KernalCLRCHN        // Reset to keyboard
        lda ReadCountLo
        sta HexValLo
        lda ReadCountHi
        sta HexValHi
        sec                     // Carry set = Error
        rts
    ```

### 2. Error Carry Flag propagation on non-EOF status

* **Vulnerability:** In the proposed status-handling logic:

    ```assembly
    frHandleStatus:
        tya
        and #$BF                // Mask out EOI bit
        bne frDone              // If other error bits are set, exit without storing
    ```

    If a real bus error (e.g. timeout or device not present) occurs, the code exits via `frDone` (which in the original returns success via `clc`). This reports a failed read operation as a success, masking errors from the application layer.
* **Remediation:** Change `bne frDone` to `bne frReadError` so that any non-EOI errors set the Carry flag to indicate a transport failure.

### 3. Clobber-Free LFN 15 Status Draining in `checkDeviceReady`

* **Vulnerability:** The plan correctly identifies that `checkDeviceReady` only reads the first two status characters, leaving the remainder of the status string (e.g. `", OK, 00, 00\r"`) in the drive's channel buffer. However, using the generic `drainOpenErrorChannel` would overwrite the global `SourceBuf` array, which may be in use by concurrent API operations.
* **Remediation:** Implement a local, register-only draining loop in `checkDeviceReady` right after reading the first two digits. This avoids clobbering global buffers:

    ```assembly
    cdrDrainLoop:
        jsr KernalREADST
        bne cdrDrainDone        // EOI or error -> nothing more to read
        jsr KernalChRIN
        cmp #$0D                // PETSCII Carriage Return
        bne cdrDrainLoop
    cdrDrainDone:
        jsr KernalCLRCHN
    ```

### 4. Empty File Read Behavior

* **Analysis:** Under the C64 KERNAL and IEC bus protocol, the talker (drive) must transmit at least one byte to complete a read channel handshake. For an empty file, the 1541 drive transmits a single byte (normally Carriage Return `$0D` or null `$00`) with the EOI line held low. Consequently, any KERNAL-compliant byte-by-byte reader will read exactly 1 byte from a 0-byte file before hitting EOF.
* **Evaluation:** This is a hardware/firmware constraint of the target Commodore platform. Trying to intercept this would require looking up the file size via the directory first, which is extremely expensive. The proposed `fileRead` logic correctly accepts this constraint.

---

## Action Plan Recommendations

The overall plan is solid and addresses the root cause of the PRG default mistyping footgun. The following changes should be incorporated into the implementation phase:

1. **`src/command64/file.asm` (`fileOpen`):**
    * Change the fallback type byte on line 187 from `#$50` ('P') to `#$53` ('S').
2. **`src/command64/file.asm` (`checkDeviceReady`):**
    * Insert the non-clobbering status-line draining loop after retrieving the status digits.
3. **`src/command64/file.asm` (`fileRead`):**
    * Rewrite the loop to check status *after* reading, utilizing the remediated `frDoneOK` and `frReadError` labels to correctly manage output registers and the carry flag.
4. **`tests/src/filetest/filetest.s` & `tests/src/handletest/handletest.s`:**
    * Modify test opens to explicitly set `HexValHi = 'S'` and `'P'` respectively, removing the dependency on silent fallbacks.
5. **Documentation:**
    * Update [docs/api-reference.md](file:///home/morgan/development/c64/command64-os/docs/api-reference.md) and [wiki/api-reference.md](file:///home/morgan/development/c64/command64-os/wiki/api-reference.md) to document `HexValHi` as the optional write-mode file type input for `DOS_OPEN_FILE`.
