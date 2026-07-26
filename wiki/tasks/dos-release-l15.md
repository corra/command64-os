# Task Spec: DOS_RELEASE_L15 Kernel Primitive

## Description

Add a new stable API primitive, `DOS_RELEASE_L15`, that closes KERNAL logical
file 15 (the command channel) and clears the OS's persistent-open cache for
LFN 15 (`L15Device`/`ensureL15Open` in `src/command64/file.asm`).

This closes a real, reproducible bug: `LABEL` (`src/external/label/label.s`)
opens/closes LFN 15 directly for its own BAM direct-access protocol, with
no visibility into the OS's cache. Any prior disk operation in the same
session (`LOAD`, `DIR`, `VOL`, `DELETE`, `RENAME`, `PATH`,
`DOS_SEND_COMMAND`) leaves LFN 15 genuinely open and cached
(`sendSA15Command` never closes it, by design). `LABEL`'s own raw
`KernalOPEN` of LFN 15 then fails with KERNAL error 2 ("FILE ALREADY
OPEN") -- which `LABEL` misreported as "DEVICE NOT PRESENT" (a separate,
bundled fix; see the plan). Worse, `LABEL` always closes LFN 15 on exit,
desyncing the cache: every subsequent `checkDeviceReady`-gated operation
then believes LFN 15 is still open, skips reopening it, and fails --
presenting as "the drive is gone" for all further disk operations until a
full reset.

Full root-cause writeup and design rationale:
`brain/plans/label-l15-cache-release.md`.

## Scope

- New function number `DOS_RELEASE_L15 = $5B`, registered in
  `include/command64.inc` and `include/ca65/command64.inc`.
- Input: none. Output: `Carry` = 0 (always).
- Behavior: calls `KernalCLOSE` for LFN 15, then sets `L15Device` to `0`
  (the existing "not open" sentinel; real device numbers are 8-11).
- `LABEL` calls it before its first direct LFN 15 open and again from
  `labelExit` after direct use. The entry call releases a channel retained by
  prior OS disk activity; the exit call keeps the cache synchronized.

## Non-Goals

- No migration of `LABEL`'s command-channel round trips to the existing
  `DOS_SEND_COMMAND` primitive (considered and rejected -- `LABEL` also
  needs raw LFN 2 buffer access that `DOS_SEND_COMMAND` doesn't provide;
  see the plan's Dependency Review item 2).
- No change to `ensureL15Open`, `checkDeviceReady`, `readErrorChannel`, or
  `sendSA15Command` themselves -- only a new, additive way to invalidate
  the cache from outside.
- No audit of every external program for the same class of bug beyond
  `debug.s` (confirmed clear -- it never touches LFN 15).

## Sub-tasks

- [x] Add `DOS_RELEASE_L15 = $5B` to `include/command64.inc` and
      `include/ca65/command64.inc`.
- [x] Add `ahReleaseL15` dispatch entry in `src/command64/api.asm`.
- [x] Wire `LABEL`'s `labelExit` to call it after closing LFN 15.
- [x] Bundled fix: `LABEL`'s `openErr` now prints the real KERNAL error
      code instead of a hardcoded, often-wrong "DEVICE NOT PRESENT".
- [x] New standalone ca65 test, `tests/src/l15release/l15release.s`,
      reproducing the exact conflict against a real/true-emulated drive
      before proving the fix.
- [x] Document `DOS_RELEASE_L15` in `wiki/api-reference.md`.
- [ ] Verify via VICE: the standalone test's 5 steps, plus the end-to-end
      reproduction (a disk op, then `LABEL`, then another disk op, then a
      no-prior-disk-op `LABEL` regression check).
