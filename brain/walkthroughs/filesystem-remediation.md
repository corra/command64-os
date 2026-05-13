# Walkthrough: File System Remediation (Load Error Fix)

## Summary
Resolved critical bugs in handle-based I/O that caused "Load error"s in `TYPE` and `COPY`.

## Files Changed
| File | Change |
|------|--------|
| `src/command64/file.asm` | Fixed `SETLFS` register order and added `tax` for `CHKIN/CHKOUT`. |
| `src/command64/file.asm` | Integrated `normalizeName` to handle case-sensitivity. |
| `src/command64/file.asm` | Used LFN as Secondary Address to resolve channel conflicts. |

## Verification Results
- `TYPE` verified with lowercase/mixed-case filenames.
- `COPY` verified; simultaneous source/destination files function without channel conflicts.

## Lessons Learned
- Always verify KERNAL register expectations (A vs X vs Y) for every API call.
- Disk drives (1541) are strictly unshifted PETSCII for filenames.
