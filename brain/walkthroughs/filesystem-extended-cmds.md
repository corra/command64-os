# Walkthrough: Extended File System Commands (DEL/REN)

## Summary
Implemented `DEL` / `ERASE` and `REN` / `RENAME` internal commands using the C64 disk command channel.

## Files Changed
| File | Change |
|------|--------|
| `include/command64.inc` | Added `DOS_DELETE_FILE` and `DOS_RENAME_FILE` codes. |
| `src/command64/api.asm` | Updated service bus dispatcher. |
| `src/command64/file.asm` | Implemented `fileDelete` and `fileRename`. |
| `src/command64/shell.asm` | Added command handlers and updated help documentation. |

## Testing Results
- Deletion verified via `DEL test.txt`.
- Renaming verified via `REN old.txt new.txt`.

## Gotchas
- The "Rename" command string must be `R:newname=oldname` (destination first).
- Command channel 15 must be opened and closed for every maintenance command.
