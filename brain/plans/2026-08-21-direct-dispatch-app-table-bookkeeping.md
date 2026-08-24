---
feature: direct-dispatch-app-table-bookkeeping
created: 2026-08-21
status: approved
taskwarrior: 41
depends-on: none
---

# Plan: Direct-Dispatch App-Table Bookkeeping

## Status

**Approved 2026-08-21. Implemented 2026-08-24, awaiting closing sign-off.**
All four atomic increments are done and all five VICE matrix cases pass —
evidence in
`brain/walkthroughs/2026-08-21-direct-dispatch-app-table-bookkeeping.md`.

Not part of a numbered Phase; a standalone bug-fix work package tracked as
Taskwarrior task **41** (the plan originally cited 43, which is the
unrelated `dir /p` task).

## Objective

Command64 has two ways to load and run an external command: `LOAD <name>
[addr]` (`cmdLoad`, `shell.asm`) and typing the app's name directly
(external command dispatch, `sdExt*`, `shell.asm`). Both call the same
underlying primitives (`shellLoadPrg`, `aptRelocate`), but only `cmdLoad`
does app-table bookkeeping (`aptCheckRange`/`aptProtectedCheck` pre-flight,
`aptRegister` after).

This WP fixes the divergence per the user's three-part resolution
(2026-08-21):

1. Direct dispatch **keeps** its ability to load over/into memory a
   registered app occupies without a pre-flight check — that's already how
   it's privileged to behave, and is not being changed.
2. Direct dispatch **must** deregister (`aptRemove`) any app-table slot(s)
   whose registered range overlaps the memory it just loaded into, so the
   table never reports a slot as still "loaded" after its memory has
   actually been overwritten by something else.
3. Direct dispatch **must** register itself (`aptRegister`) after loading,
   for the same future accounting (`APPS`/`PS`-style listing, DEBUG's app
   queries, etc.) that `LOAD` already gets.

Explicitly **not** in scope: adding `aptCheckRange`/`aptProtectedCheck`
pre-flight gating to direct dispatch (that would remove the privileged
overwrite behavior in (1), which is being kept, not fixed), and any change
to `cmdLoad`'s own behavior.

## Scoping Decisions (user-confirmed 2026-08-21)

1. Eviction of an overlapping app-table entry is **silent** — no `"freed
   <name>"` (or similar) output. Direct dispatch already prints nothing on
   a normal run; this stays a pure correctness fix with no new visible
   output.

## Background: what's already shared vs. what's missing

Both paths already share `shellLoadPrg` and `aptRelocate` (the latter via
`relocateExternalCommand`, `shell.asm:1736-1740`) — relocation itself is
not the gap (see `[[project-os-external-cmd-relocation]]`).

What `cmdLoad` does that direct dispatch (`sdExt*`, `shell.asm:260-334`)
currently does not, after a successful load:

- Set `SrcHandle` to `findFile`'s returned name length. `cmdLoad` does
  `stx SrcHandle` right after `findFile` (`shell.asm:580`); the `sdExt*`
  path calls `findFile` (`shell.asm:305`) but never captures its returned
  length into `SrcHandle` at all. `aptRegister`'s name-copy loop reads
  `SrcHandle` bytes from `NamePtrLo/Hi` (`apptable.asm:571-599`), so
  calling it today with direct dispatch's stale/uninitialized `SrcHandle`
  would copy garbage into the app-table name field. This is a real,
  necessary fix, not just wiring — without it (3) would register apps
  under corrupted names.
- Guard app-table calls on `AptSegLo/Hi != 0` (REU/table initialized).
  `cmdLoad` checks this once before `aptRelocate`/`aptRegister`
  (`shell.asm:632-636`, `clSkipRegister`). Direct dispatch must add the
  same guard around the new eviction+registration block — `aptRelocate`
  itself is REU-independent (plain ZP/CPU logic) and already runs
  unconditionally, but `aptCheckRange`/`aptRemove`/`aptRegister` all read
  the VMM-backed app table and must not run when it was never allocated.
- Evict overlapping slot(s) and register the new load. Neither happens
  today on this path at all.

## Design: eviction + registration sequence

Insert this immediately after the existing `jsr relocateExternalCommand`
(`shell.asm:324`) and before `lda SavedDevice` / `jsr UserProgStart`:

```
    lda AptSegLo
    ora AptSegHi
    beq sdExtAptDone        // no REU/app table -> skip bookkeeping entirely

    // TempLo/Hi currently holds end_addr+1 (aptRelocate's/aptRegister's
    // convention). aptCheckRange wants a byte COUNT instead, so convert
    // Temp in place: Size = Temp - HexVal (HexVal is UserProgStart,
    // unchanged since before the load).
    sec
    lda TempLo
    sbc HexValLo
    sta TempLo
    lda TempHi
    sbc HexValHi
    sta TempHi

sdExtEvictLoop:
    jsr aptCheckRange       // C=0: no more overlaps. C=1 + X=slot: overlap.
    bcc sdExtEvictDone      // C=1 + X=$FF: protected-region "overlap" --
    cpx #$FF                // can't happen here (UserProgStart is never
    beq sdExtEvictDone      // protected), but handled defensively, no-op.
    jsr aptRemove           // deregister the stale slot, then re-check
    jmp sdExtEvictLoop
sdExtEvictDone:

    // Convert Temp back to end_addr+1 for aptRegister's contract.
    clc
    lda TempLo
    adc HexValLo
    sta TempLo
    lda TempHi
    adc HexValHi
    sta TempHi

    jsr aptRegister         // register/overwrite this load like cmdLoad does
sdExtAptDone:
```

`SrcHandle` must be set from `findFile`'s returned `X` right after the
`findFile` call (`shell.asm:305`), mirroring `cmdLoad`'s `stx SrcHandle`
(`shell.asm:580`), so it's valid by the time this block runs.

Why the Temp convention conversion is safe: `aptCheckRange` documents
`Preserves: HexValLo/Hi, TempLo/Hi` (`apptable.asm:382`), so it's safe to
set `TempLo/Hi` to the byte count once before the loop and let the loop
call `aptCheckRange`/`aptRemove` repeatedly without re-deriving it each
iteration. `HexValLo/Hi` is `UserProgStart` throughout this path and is
never touched by `aptCheckRange`/`aptRemove`, so the size/end-address
conversion only needs to happen once on each side of the loop.

Loop termination: each `aptRemove` clears exactly the slot `aptCheckRange`
just reported (`apptable.asm:235-255`), so the slot can never be found
again by the next `aptCheckRange` scan; with `APT_MAX_SLOTS` slots total
the loop is bounded even in the pathological case of every slot
overlapping.

## Atomic Increments

1. Add `stx SrcHandle` immediately after the `jsr findFile` in the
   `sdExt*` path (`shell.asm:305-306`), matching `cmdLoad`'s existing
   convention.
2. Add the `AptSegLo/Hi` guard + evict-loop + `aptRegister` block after
   `jsr relocateExternalCommand` (`shell.asm:324`), as designed above.
3. Build (`image_d64`/`test_image_d64`) and static-verify: no new zero-page
   collisions, `SrcHandle`/`NamePtrLo/Hi`/`HexValLo/Hi`/`TempLo/Hi` usage
   matches each callee's documented contract at every call site in the new
   block.
4. VICE verification (see matrix below).

## VICE Verification Matrix

- Direct-invoke an app with no prior app-table activity: registers
  correctly, `APPS`/`PS`-equivalent listing shows it with the right
  name/address/size, matches what `LOAD <name>` + manual `aptRegister`
  would show.
- `LOAD` an app at an address, then direct-invoke a *different* app whose
  R6 load lands on overlapping memory at `UserProgStart`: confirm the
  first app's stale slot is gone from the table and the second app is
  registered correctly (no leftover phantom "loaded" entry).
- Direct-invoke the same app twice in a row: second invocation overwrites
  the first's own table entry cleanly (name match in `aptRegister`,
  `apptable.asm:527-532`), no duplicate slot, no eviction of unrelated
  slots.
- Direct-invoke an app while the app table has zero registered slots and
  while REU is disabled (`AptSegLo/Hi == 0`): confirm the load and
  execution still work exactly as before (no crash, no attempted VMM
  access) — this is the pre-existing `beq sdExtAptDone` skip path.
- Direct-invoke a non-relocatable plain PRG (no R6 footer): confirm
  `relocateExternalCommand`'s carry-set/ignored path is unaffected and the
  new bookkeeping block still runs correctly off of whatever `TempLo/Hi`
  `shellLoadPrg` returned.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/command64/shell.asm` | Modify (`sdExt*` external-dispatch path only) |

## Stop Conditions

- Any VICE matrix case above fails or shows unexpected app-table state —
  halt and report, don't push through with a workaround.
- Any zero-page/Cassette-Buffer scratch collision is found between this
  new block and an existing routine's documented clobber list — halt and
  report; do not silently pick a different scratch byte without recording
  why.
- Any defect found outside this exact scope (e.g. in `cmdLoad`,
  `aptRegister`, `aptCheckRange` themselves) is disclosed and deferred as
  a separate follow-up, not fixed inline, unless the user explicitly
  directs otherwise in the moment.

## Documentation, Task, and DOX Updates

- Taskwarrior task 43: mark done on completion, after user sign-off.
- `CHANGELOG.md`: `[Unreleased]` entry noting direct-dispatch app-table
  bookkeeping parity with `LOAD`.
- Memory: update `project-os-external-cmd-relocation` (or add a linked
  memory) noting relocation parity was already fixed 2026-07-27 but
  app-table bookkeeping parity was a separate, later gap closed by this WP.
- No `wiki/tasks/*.md` entry planned — this is a small, self-contained bug
  fix, not a numbered Phase/WP series; recorded in `brain/task.md` at
  completion per the standard closeout convention instead.

## Completion Gate

- All VICE matrix cases pass with live evidence recorded in
  `brain/walkthroughs/2026-08-21-direct-dispatch-app-table-bookkeeping.md`.
- `image_d64` and `test_image_d64` build clean, no-change rebuild stable.
- User explicitly approves closing this WP.

## Progress

- 2026-08-21: Plan drafted and presented for approval. Not yet implemented.
- 2026-08-21: User approved the plan but asked that work not begin yet —
  other work is in progress concurrently. Holding until explicit go-ahead.
- 2026-08-24: Go-ahead given; Increments 1-4 implemented and verified.
  One deviation: the bookkeeping block did not fit inline in the
  `CommandShell` segment (it overlapped the fixed `VmmData` block at
  `$1FA0`), so it was moved verbatim into a new `sdExtAptBookkeep`
  subroutine in `ShellExt` — placement only, same logic. All five VICE
  matrix cases PASS, including the no-REU skip path (verified on a
  throwaway second emulator started with `+reu`, since `vicerc` carries
  `REU=1` and the `--no-reu` flag alone does not negate it). No stop
  condition triggered. Awaiting user approval to close and to mark
  Taskwarrior task 41 done.
