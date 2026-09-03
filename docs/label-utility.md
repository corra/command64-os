# command64 OS LABEL Utility Manual

**File Name:** `label.prg`
**Version:** `0.4.0.1047` (banner: `LABEL v0.4.0.1047`)
**Target Address:** R6-relocatable, implicit origin `$3400`; loaded and
relocated to `UserProgStart` (currently `$3800`) by the shell's external-
command loader. Runs unchanged at any load base (verified `$3800` / `$5000`
/ `$9000`).
**Assembler:** native CASM only — no ca65 build (see *Artifact Provenance*
below).

## Overview

`LABEL` is an external disk management utility that allows you to change the volume name of a floppy disk without erasing its contents.

Standard Commodore DOS only permits setting a disk name when formatting a disk (using the `NEW` command), which destroys all existing files. `LABEL` bypasses the standard file system using CBM DOS Direct Access Commands, editing the BAM sector directly on Track 18, Sector 0.

## Command Syntax

```bash
LABEL [new-label]
```

### Parameters

* **`[new-label]`**: The new name for the disk. It can be up to 16 characters long.
  * If the label contains spaces, ensure they are typed directly.
  * Names shorter than 16 characters are automatically padded with PETSCII shifted space characters (`$A0`), which is the Commodore standard for directory headers.
  * Attempting to set a label longer than 16 characters will return an error without modifying the disk.

### Interactive Prompt Mode

Invoking `LABEL` with a target but no name — a bare trailing space
after `LABEL`, or a device prefix alone (`LABEL 9:`) — prompts interactively
rather than erroring. (`LABEL` with nothing after it prints
`label name required`.)

```text
VOLUME LABEL (16 CHARS MAX)?
```

Type the new label (up to 16 characters, with destructive backspace
support) and press `RETURN` to apply it. Pressing `RETURN` on an empty
line cancels — the disk is left unmodified.

---

## Direct Access Protocol (How it Works)

Under the hood, `LABEL` operates directly on the disk controller of the active drive:

1. **Initialize Command Channel:** Opens logical file 15 to the drive's command channel.
2. **Drive Reset:** Sends the Initialize (`I`) command to clear any previous error states.
3. **Open Data Channel:** Opens logical file 2 configured as a raw data channel (`#`) to request a free drive memory buffer.
4. **Block Read (U1):** Instructs the drive to read Track 18, Sector 0 (the directory header/BAM block) into the allocated drive buffer.
5. **Seek Offset (B-P):** Moves the drive buffer pointer to offset **144** (the start of the 16-character diskette name).
6. **Modify Buffer:** Writes the 16 bytes of the new label (including `$A0` padding) directly into the drive buffer.
7. **Block Write (U2):** Instructs the drive to write the modified buffer back to Track 18, Sector 0 on the physical diskette.
8. **Flush BAM Cache:** Sends a second Initialize (`I`) command to the drive command channel. This forces the drive to re-read Track 18, Sector 0 into its internal memory, synchronizing its directory header RAM cache immediately.
9. **Clean Up:** Closes both the data and command channels.

---

## Practical Examples

### 1. Renaming the Disk

To rename the disk currently in Drive 8 to "GAMES 2026":
`LABEL GAMES 2026`
*Output:* `Label updated`

To verify the change took effect immediately:
`VOL`
*Output:*

```text
Volume in drive 8 is GAMES 2026
Volume ID is 2A
```

### 2. Error Handling

* **Write Protected Disk:** If you attempt to rename a write-protected floppy disk:
  `LABEL NEWNAME`
  *Output:* `26, WRITE PROTECT ON, 00, 00`
* **Label Too Long:**
  `LABEL THISLABELISEXCEEDINGSIXTEEN`
  *Output:* `Label too long (max 16)`
* **Drive Error / Device Not Present:** If a channel cannot be opened
  (e.g. the target device is absent):
  `LABEL 11:TEST`
  *Output:* `drive error 05` (the trailing number is the real KERNAL
  error code — `05` = device not present).

---

## Artifact Provenance

`LABEL` is a **CASM-native application**: its source
(`src/external/label/label.s`, constants inline, uppercase ASCII) is
assembled only by the native CASM assembler running on the C64. There is
no ca65/ld65 build (retired in the 2026-09-02 migration —
`brain/plans/2026-09-02-label-casm-native-migration.md`).

* **Shipping artifact** — `src/external/label/label.ref.hex`, a
  human-reviewed hex manifest that `scripts/hex_manifest_to_bin.py`
  transcribes back into `label.prg` at build time. Regenerating it is a
  deliberate, reviewed act (`scripts/build_label_manifest.py`), never a
  build step.
* **Stale-source guard** — the manifest embeds a `source_sha256` line for
  each of `label.s`, `LABEL_VERSION`, and `BUILD_LABEL`; editing any of
  them without regenerating the manifest hard-fails the build.
* **Version banner** — `labelver.s` (the `LABELVERMSG` data) is generated
  at build time by `scripts/gen_label_version.py` from `LABEL_VERSION`
  (`0.4.0`, hand-bumped) and `BUILD_LABEL`. The app name is emitted as
  shifted PETSCII (uppercase glyph) followed by a lowercase `v` and the
  dotted version+build, matching `DEBUG`'s `DEBUG v0.5.0.1128` format.
* **Correctness oracle** — `src/external/label/label-derivation.md`: the
  code/data bytes are independently corroborated by a same-base (`$3400`)
  ca65 differential build of the pre-migration source (843 of 844 image
  bytes identical; the one difference is the intentional banner
  `V`→`v`), and the 52-entry R6 relocation table is independently
  verified (`scripts/casm_r6_verify.py`). Live proof:
  `COMP LABEL.PRG LABEL.REF` → `FILES COMPARE OK` on the C64.
* **Native reassembly** — the `command64_label_test_d64` CMake target
  builds a disk with `command64`, `casm`, `comp`, `label.s`,
  `labelver.s`, and the reviewed `label.ref`, for reproducing the run:
  `CASM LABEL.S /O:LABEL.PRG` then `COMP LABEL.PRG LABEL.REF`. Native
  CASM assembly needs a REU; the resulting `LABEL` runtime does not.
