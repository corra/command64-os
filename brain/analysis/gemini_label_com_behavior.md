# Analysis: LABEL Command Behavior, Syntax Errors, and CBM DOS Specifications

This document analyzes the persistent `"31,syntax error"` in the `LABEL` command implementation, corrects the BAM sector offset math, outlines the MS-DOS 4.0 `LABEL.COM` behavior, and evaluates the choice between an internal and external command.

---

## 1. Root Cause of "31,syntax error"

The syntax error is caused by two distinct issues in how commands are compiled and sent to the disk drive.

### Issue A: `petscii_mixed` Encoding Bug (The Primary Blocker)

In [shell.asm](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm), the source code is compiled with KickAssembler using the `.encoding "petscii_mixed"` directive.

* Under `petscii_mixed`, uppercase letters in source code (e.g. `'I'`, `'U'`, `'B'`, `'P'`) compile to **shifted PETSCII** characters (hex values `$C1–$DA`).
* The 1541 disk drive controller expects **unshifted ASCII/PETSCII** characters (hex values `$41–$5A`) for all command letters.
* Because of this mapping, the drive receives:
  * `$C9` (shifted `'I'`) instead of `$49` (unshifted `'I'`)
  * `$D5` (shifted `'U'`) instead of `$55` (unshifted `'U'`)
  * `$C2` (shifted `'B'`) instead of `$42` (unshifted `'B'`)
  * `$D0` (shifted `'P'`) instead of `$50` (unshifted `'P'`)
* **Impact:** The very first byte sent to the command channel (e.g., `'I'` as `$C9`) is immediately rejected by the drive with a `"31,syntax error"`. The drive never even sees or processes the track/sector parameters.

### Issue B: Binary vs. ASCII Parameter Bug

The 1541 command channel is a text-based protocol. Numbers in commands must be sent as ASCII decimal character digits (e.g. `'2'`, `'1'`, `'8'`), not as raw binary bytes.

* In the previous refactored helpers (`labelSendBlockCmd` and `labelSendBPCmd`), the parameters for the secondary address/channel, track, and sector were sent as raw binary byte values:
  * `lda labelLfn` (sends binary `$02` instead of ASCII `$32` / `'2'`)
  * `lda #18` (sends binary `$12` instead of ASCII `$31, $38` / `'18'`)
* **Impact:** Even if the command prefix (`"U1:"`) was correctly encoded, sending binary values would trigger a syntax error because the drive's string parser expects ASCII digits.

---

## 2. Verification of Disk Name BAM Offset

There was a discrepancy regarding whether the disk name is located at offset `4` or offset `144` within Track 18, Sector 0. We verified the layout of the 1541 BAM sector:

1. **BAM Memory Block:** The BAM bitmap tracks sectors for 35 tracks, allocating 4 bytes per track.
   $$\text{Total BAM Size} = 35 \text{ tracks} \times 4 \text{ bytes} = 140 \text{ bytes}$$
2. **BAM Offset:** The BAM starts at offset `4` in the sector.
   $$\text{BAM Range} = 4 \text{ to } (4 + 140 - 1) = 4 \text{ to } 143$$
3. **Disk Header Details:** The disk name immediately follows the BAM bitmap.
   $$\text{Disk Name Offset} = 144$$

* **Conclusion:** The disk name resides exactly at byte offsets **144 to 159**. An offset of `4` would overwrite the BAM for Tracks 1 and 2, corrupting the disk. The value **144** used in [volume_name_asm.md](file:///home/morgan/development/c64/command64-os/brain/research/volume_name_asm.md) is mathematically and technically correct.

---

## 3. MS-DOS 4.0 `LABEL.COM` Behavior

According to [label_com_behavior.md](file:///home/morgan/development/c64/command64-os/brain/research/label_com_behavior.md), MS-DOS 4.0 `LABEL` supports two execution flows:

### Non-Interactive Mode

* **Trigger:** Invoking the command with an argument: `LABEL [drive:][label-text]` (e.g., `LABEL A:MYDISK` or `LABEL MYDISK`).
* **Behavior:** Modifies the disk label immediately without asking questions and exits.

### Interactive Mode

* **Trigger:** Invoking the command without a new label: `LABEL` or `LABEL A:`.
* **Behavior:**
  1. Displays the current volume label and volume serial number.
  2. Prompts: `Volume label (11 characters, ENTER for none)?` (16 characters on C64).
  3. If the user types a name, it updates the label.
  4. If the user presses **Enter** on an empty line, it asks: `Delete current volume label (Y/N)?`.
     * If `Y`, it deletes/clears the label.
     * If `N`, it exits without modifying the disk.

---

## 4. Architectural Choice: Internal vs. External Command

| Aspect | Internal Command (in `shell.asm`) | External Command (`LABEL.PRG`) |
| :--- | :--- | :--- |
| **Memory Footprint** | Bloats the resident shell binary (~150+ bytes of code and strings). | Keeps the shell lean; memory is reclaimed after execution. |
| **MS-DOS 4.0 Alignment**| Inconsistent (MS-DOS `VOL` is internal, but `LABEL` is external). | **Consistent** with MS-DOS 4.0 where `LABEL.COM` is external. |
| **Diagnostics / Debugging**| Harder to add verbose debug prints due to shell size constraints. | **Excellent**; we can include verbose status prints to isolate drive errors. |
| **Interactive Prompt** | Adds complexity and input polling loops to the main shell. | Easier to structure cleanly inside a dedicated program main loop. |
| **Availability** | Always available in the shell. | Requires the binary to be on the active disk/PATH. |

---

## 5. Technical Recommendations for the Fix

Regardless of whether `LABEL` is kept internal or external, the code must be fixed using the following encoding and formatting rules:

1. **Unshifted Command Characters:** Avoid character literals like `'U'` or `'B'` in strings. Either compile using lowercase literals (e.g., `.text "u1: "`) or declare explicit byte values:
   * `"I\r"` $\rightarrow$ `.byte $49, $0D, $00`
   * `"U1"` $\rightarrow$ `.byte $55, $31`
   * `"B-P"` $\rightarrow$ `.byte $42, $2D, $50`
   * `"U2"` $\rightarrow$ `.byte $55, $32`
2. **ASCII Parameters:** Format the channel, drive, track, and sector as ASCII character digits separated by spaces:
   * **`U1` Command:** `U1 <channel> 0 18 0` $\rightarrow$ `.byte $55, $31, $20, [channel_char], $20, $30, $20, $31, $38, $20, $30, $0D, $00`
   * **`B-P` Command:** `B-P <channel> 144` $\rightarrow$ `.byte $42, $2D, $50, $20, [channel_char], $20, $31, $34, $34, $0D, $00`
   * **`U2` Command:** `U2 <channel> 0 18 0` $\rightarrow$ `.byte $55, $32, $20, [channel_char], $20, $30, $20, $31, $38, $20, $30, $0D, $00`
3. **Channel Patching:** Patch the ASCII representation of the secondary address LFN:

   ```asm
   lda labelLfn
   clc
   adc #$30                // Convert binary LFN (2-9) to ASCII digit ('2'-'9')
   sta cmdU1Str+3          // Patches "U1 X 0 18 0"
   sta cmdBPStr+4          // Patches "B-P X 144"
   sta cmdU2Str+3          // Patches "U2 X 0 18 0"
   ```
