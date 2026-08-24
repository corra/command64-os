---
feature: direct-dispatch-app-table-bookkeeping
plan: brain/plans/2026-08-21-direct-dispatch-app-table-bookkeeping.md
date: 2026-08-24
status: awaiting-approval
taskwarrior: 43
---

# Walkthrough: Direct-Dispatch App-Table Bookkeeping

## Implementation

Two changes, both confined to `src/command64/shell.asm`'s external-command
dispatch path (`sdExt*`), exactly as planned:

1. **`stx SrcHandle` after `findFile`** (`shell.asm:306`). `findFile` returns
   the normalized name length in `X`; the direct-dispatch path previously
   discarded it. `aptRegister`'s name-copy loop reads `SrcHandle` bytes from
   `NamePtrLo/Hi`, so without this the new registration would have written a
   garbage-length name into the app table.

2. **`jsr sdExtAptBookkeep` after `jsr relocateExternalCommand`**
   (`shell.asm:325`), calling a new routine that performs the planned
   guard + evict-loop + register sequence.

### Deviation from the plan: the block is a subroutine in `ShellExt`

The plan sketched the bookkeeping as an inline block at the call site. Placing
it inline overflowed the `CommandShell` segment into the fixed `VmmData` block
at `$1FA0` (Kick Assembler: *"memoryblock 'CommandShell' ($10d1-$1fb4) overlaps
'VmmData' ($1fa0-$1fff)"*), and also pushed the pre-existing
`beq sdRealBadCmd` at `shell.asm:265` out of relative-branch range.

The logic was therefore moved verbatim into `sdExtAptBookkeep` in the roomier
`ShellExt` segment (`shell.asm:3799-3849`) — the same rationale `aptRelocate`
itself already uses (`loader.asm:57-62`). With only a `jsr` left at the call
site, the branch-range problem disappeared as well and no trampoline was
needed. Behavior is identical to the planned block; only its address is
different. This is a placement change, not a scope change.

## Static Verification

Contracts checked at every new call site against each callee's documented
clobber/preserve list:

- `aptCheckRange` *"Preserves: HexValLo/Hi, TempLo/Hi, NamePtrLo/Hi,
  SrcHandle"* (`apptable.asm:382`) — so the byte-count conversion is done once
  before the loop and survives every iteration.
- `aptRemove` *"Clobbers: A, DstHandle, VmmSegLo/Hi, VmmOffLo/Hi; Preserves:
  X"* (`apptable.asm:231-234`) — touches none of `HexVal`/`Temp`/`NamePtr`/
  `SrcHandle`. `aptSlotBase` (`apptable.asm:16-17`) and
  `vmmReadByte`/`vmmWriteByte` (`vmm.asm:253-300`, REU registers +
  `vmmTempByte` only) add nothing beyond that.
- `aptRegister` requires `NamePtrLo/Hi` + `SrcHandle` + `HexValLo/Hi` +
  `TempLo/Hi` = end_addr+1 (`apptable.asm:513-518`); all four hold at the call.
- `aptRelocate` uses `NamePtrLo/Hi` as scratch but explicitly saves and
  restores it around its patch loop (`loader.asm:155-160`, `loader.asm:198-201`),
  so `relocateExternalCommand` running *before* the new block does not
  invalidate the name pointer.
- `shellLoadPrg` (`loader.asm:18-51`) never touches `SrcHandle`, so the value
  captured right after `findFile` is still valid after the load.
- No new zero-page or Cassette-Buffer scratch byte was introduced; the routine
  reuses only locations the two callees already own.

Loop termination: each `aptRemove` clears the exact slot `aptCheckRange` just
reported, so that slot cannot be reported again; the loop is bounded by
`APT_MAX_SLOTS`.

## Build Evidence

- `cmake --build build --target image_d64` — clean, build 2680.
- `cmake --build build --target test_image_d64` — clean.
- No-change rebuild stable (no build-number increment, `BUILD_OS` = 2680).
- Final segment map: `CommandShell $10d1-$1f80` (31 bytes of headroom before
  the fixed `VmmData` at `$1fa0`), `ShellExt $2495-$3587`,
  `ApiExt $3588-$37f7` (ends 8 bytes below `UserProgStart` = `$3800`).

## VICE Verification

Instance A: the user's existing `x64sc -mcpserver` on port 7000, REU attached
(16384 KiB), `build/image.d64` on unit 8, scratch `plaintest.d64` on unit 9.
Banner evidence: screen row 0 decoded to `Command 64-DOS Version 0.4.1.2680`
(the build under test). `AptSegLo/Hi` (`$03F2`) read `00 01` — table allocated.
`flush` after the run reported `Drive 8 status: 00, ok,00,00`.

Instance B: a second, throwaway `x64sc` on port 7001 started with `+reu`
(the repo's `--no-reu` flag alone is not enough — `~/.config/vice/vicerc`
carries `REU=1`, so it must be explicitly negated). `AptSegLo/Hi` read
`00 00` there, confirming a genuinely REU-less machine. Stopped afterwards;
the user's port-7000 instance was left running and healthy throughout.

| # | Matrix case | Evidence | Result |
|---|---|---|---|
| 1 | Direct-invoke with no prior app-table activity | `ps` → `no apps loaded`; `comp` → `USAGE: COMP FILE1 FILE2`, back at `C64[8]:>`; `ps` → `comp 3800 037a`, `1 app(s) loaded` — correct, uncorrupted name | PASS |
| 2 | `LOAD` then direct-invoke a *different* app at overlapping memory | `free` → `freed comp`; `load label 3800` → registered `label 3800 034c`; direct `comp` → `ps` shows only `comp 3800 037a`, `1 app(s) loaded`. The stale `label` slot is gone — no phantom entry | PASS |
| 3 | Direct-invoke the same app twice | `comp`, `ps` → `comp 3800 037a`, `1 app(s) loaded`; `comp` again, `ps` → identical single entry. No duplicate slot, no unrelated eviction | PASS |
| 4 | Direct-invoke with REU disabled (`AptSegLo/Hi == 0`) | Instance B: `ps` → `no apps loaded`; `comp` loads, runs, prints its usage line and returns to `C64[8]:>`; `ps` still `no apps loaded`; `9:plain` also loads, prints `ok`, returns. No crash, no VMM access | PASS |
| 5 | Direct-invoke a non-relocatable plain PRG (no R6 footer) | Purpose-built 23-byte `plain.prg` (load address `$3800`, three `CHROUT`s then `DOS_EXIT`) on `plaintest.d64` at unit 9. `9:plain` → `loading...`, `ok`, back at prompt; `ps` → `plain 3800 0015`. `$15` = 21 bytes = the file's exact code size, proving `aptRelocate`'s magic-mismatch path restored `TempLo/Hi` correctly and the new block registered off it | PASS |

Case 5 also incidentally re-confirms case 2 on the no-footer path: the
previously registered `comp` slot was evicted by the `plain` load
(`1 app(s) loaded`, `comp` gone).

Registered names carry no `.prg` suffix on either path (`comp`, `label`,
`plain`), matching what `LOAD` already produced — direct-dispatch registration
is indistinguishable from `cmdLoad`'s.

## Stop Conditions

None triggered. No matrix case failed, no scratch collision was found, and no
out-of-scope defect was discovered in `cmdLoad`, `aptRegister`, or
`aptCheckRange`.

## Notes

- Overlay `test` events were not fired during this run; the assertions above
  rest on direct screen-RAM and memory reads, not on overlay state.

## Completion Gate

- [x] All VICE matrix cases pass with live evidence recorded above.
- [x] `image_d64` and `test_image_d64` build clean; no-change rebuild stable.
- [ ] User explicitly approves closing this WP.
