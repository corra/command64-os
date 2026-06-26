---
feature: vol-label-remediation
completed: 2026-06-26
status: completed
---

# Walkthrough: VOL / LABEL Command Remediation

## Summary
Diagnosed and resolved three issues introduced during the development of the `VOL` and `LABEL` commands:
1. **70,no channel,00,00 Error:** Resolved the drive buffer conflict by executing the Initialize (`I`) command *before* opening the raw data channel (`#`). Previously, initializing the drive after opening the data channel cleared the drive's internal buffers, breaking the channel 2 buffer mapping.
2. **BAM Cache / Stuck Buffer Issue:** Fixed a bug where a new volume label written via direct access (`U2`) would not take effect immediately because the drive's DOS continued to serve directory headers from its internal in-memory BAM cache. We resolved this by sending the Initialize (`I`) command *after* a successful block write, forcing the drive to synchronize its internal cache with the new physical BAM sector immediately.
3. **Command Table Corruption & PATH Regression:** Restored the working `cmdPath` handler and corrected the `tableCmd` command table alignment to prevent shell crashes during command lookups.

## Files Changed
| File | Change | Notes |
|------|--------|-------|
| [label.asm](file:///home/morgan/development/c64/command64-os/src/external/label/label.asm) | Modified | Initialize drive before opening the data channel, and re-initialize after a successful block write; updated `U1/U2/B-P` to use standard colons (`U1:`, `B-P:`, `U2:`). |
| [shell.asm](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm) | Modified | Restored `cmdPath` code and corrected `tableCmd` alignment/word registration. |
| [CHANGELOG.md](file:///home/morgan/development/c64/command64-os/CHANGELOG.md) | Modified | Added changelog entry for shell command table and external label utility fixes. |

## Testing & Verification Results
* **Compilation:** Executed `make` to compile the updated OS (`command64.prg`) and external utility (`label.prg`) with zero errors or warnings.
* **Disk Packaging:** Verified that `image.d64` and `test.d64` correctly include `command64` (25 blocks), `debug` (13 blocks), and `label` (3 blocks).

### Manual Verification Flow
To manually verify the fix:
1. Launch Command 64 OS on a drive containing `label.prg` and `test.d64`.
2. Execute `VOL` to print the current disk label (e.g., `Volume in drive 8 is Command 64` / `Volume ID is 2A`).
3. Execute `LABEL NEWDISK` to change the volume name.
4. Verify the status returns `Label updated` (or standard `00, OK, 00, 00` equivalent) with no errors.
5. Execute `VOL` or `DIR` to verify the header name has changed to `NEWDISK` immediately.
6. Run `PATH` to verify environment paths can still be set and displayed without crashes.

## Lessons Learned & Gotchas
* **Drive Buffers and "I" (Initialize):** Sending the `"I"` command to the 1541 drive DOS will reset/clear all buffer allocations. If you allocate a raw buffer with `OPEN <ch>,<dev>,<ch>,"#"`, sending any subsequent initialize or drive-reset command before performing the operations will invalidate the allocation, causing `"70,no channel"` on subsequent read/write commands.
* **BAM Cache Synchronization:** CBM DOS caches the BAM sector (Track 18, Sector 0) in the drive's RAM. If you bypass the file system and write directly to Track 18, Sector 0 using the `U2` command, the drive's internal BAM cache will be out of sync. To make the new label visible immediately (e.g., in directory listings or `VOL` commands), you must send the Initialize (`I`) command *after* the write is completed to force the drive to reload the BAM sector from the physical disk.
* **Command Table Offsets:** The C64 shell's custom `tableCmd` command-lookup structure requires strict alignment. Each command entry must have exactly 6 bytes for name (padded with spaces) and 2 bytes for the pointer. Omitting the `.word` pointer corrupts the layout of the table, causing offset shifts and crashes for all commands defined after the corruption.
