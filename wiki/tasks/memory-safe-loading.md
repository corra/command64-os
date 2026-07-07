# Task Spec: Memory-Safe Loading (Pre-flight Validation)

## Description
Prevent `LOAD` from silently clobbering another loaded program's memory. Before
the actual KERNAL LOAD runs, pre-resolve the incoming file's byte size and
validate the candidate `[loadAddr, loadAddr+size)` range against protected OS
regions and every other registered app-table entry. If the range is unsafe —
the target overlaps a protected region, overlaps an already-loaded program, or
the file is too large for the gap and would overflow into the next program —
abort the `LOAD` with a clear message and leave memory untouched.

This is validation-only. **No auto-slotting.** If a given explicit address
isn't safe, the user must free memory or pick a different address themselves;
we do not search for or suggest an alternative slot.

## Scope
- `getFileSize`: resolve the target file's byte size before `LOAD`, via LFN 13
  directory read (`"$:filename"`) + `calcFileSize` (see `shell.asm:2661`),
  without loading the file.
- `aptCheckRange`: given a candidate `[loadAddr, loadAddr+size)` range, reject
  it (carry set) if it intersects the protected regions (`$0000–$29FF`,
  `$C000–$FFFF`) or any `APT_FLAG_USED` slot's `[LoadAddr, LoadAddr+Size)`
  range.
- Harden `cmdLoad` (`shell.asm:473`): call `getFileSize` + `aptCheckRange`
  *before* `shellLoadPrg`/`KernalLOAD` runs. Abort cleanly with a message on
  rejection, before any bytes are transferred.
- Remove `aptRegister`'s current overlap-eviction scan
  (`apptable.asm:351-417`): today it silently removes the table entry of
  whatever program the new load overwrites, *after* the KERNAL has already
  clobbered that program's memory. Once the pre-flight check blocks unsafe
  loads outright, that eviction path is unreachable and should be deleted
  rather than left as dead/misleading code.

## Out of scope (deferred)
- `aptFindFreeRegion` sliding-window allocator / auto-slotting — picking an
  address on the caller's behalf. Tracked separately (Taskwarrior #23,
  still deferred).
- Pre-flight validation for header/absolute loads (`SpecificLoad=1`): the
  target address for these isn't known until the PRG header is read as part
  of the KERNAL LOAD itself, so today's `aptProtectedCheck` call in `cmdLoad`
  already only runs for relocated loads (`SpecificLoad=0`, explicit address
  given by the user). This spec keeps that same limitation — reading just the
  2-byte header ahead of a full LOAD (e.g. via a raw sequential peek) is a
  possible follow-up, not required here.

## Relationship to existing work
Supersedes the safety-check portions of `dynamic-memory-safety.md`
(`aptCheckRange`, `getFileSize`, and the non-allocator half of "harden
cmdLoad"). That spec's `aptFindFreeRegion` allocator sub-task remains
deferred and out of scope here.

## Sub-tasks
- [ ] Confirm/extend Cassette Buffer temp register layout in
      `include/command64.inc` for range-check scratch space (reuse
      `AptTempLoadLo/Hi`, `AptTempSizeLo/Hi`, `AptTempEndLo/Hi`, currently
      declared ad hoc in `apptable.asm`)
- [ ] Implement `getFileSize` in `shell.asm` (LFN 13 directory read for
      `"$:filename"` + `calcFileSize`, no load performed)
- [ ] Implement `aptCheckRange` in `apptable.asm` (protected-region +
      all-slots overlap check over an arbitrary `[addr, size)` range)
- [ ] Wire `cmdLoad` to call `getFileSize` + `aptCheckRange` before
      `shellLoadPrg`, aborting with a message on failure
- [ ] Delete `aptRegister`'s overlap-eviction scan now that unsafe loads are
      rejected pre-flight
- [ ] Compile and verify under VICE:
      - Loading into a range occupied by another app aborts with a message
        and the occupied program's memory is untouched.
      - Loading a file too large for the gap before the next program/
        protected region aborts with a message, no bytes written.
      - Loading into genuinely free space still succeeds as before.
