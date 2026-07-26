---
feature: label-l15-cache-release
created: 2026-07-25
status: planned
---

# Plan: DOS_RELEASE_L15 Kernel Primitive and LABEL Remediation

## Goal & Rationale

Fixes a confirmed, reproducible bug: running `LABEL` reports "DEVICE NOT
PRESENT" and, afterward, the drive appears unavailable for *all* subsequent
drive operations (`LOAD`, `DIR`, `VOL`, etc.), not just `LABEL`'s own retries.

Root cause (from `brain/analysis/label-device-not-present-investigation`,
recorded inline here since no prior doc covers it): the OS caches KERNAL
logical file 15 (the command channel) open persistently across calls, via
`L15Device`/`ensureL15Open` in `src/command64/file.asm:697-744`. This
backs `checkDeviceReady`, `readErrorChannel`, and `sendSA15Command` --
which together sit behind `LOAD`, `DIR`, `VOL`, `DELETE`, `RENAME`, `PATH`,
and `DOS_SEND_COMMAND` (call sites: `file.asm:91,503,567,982`,
`shell.asm:800,2488,3112`, `path.asm:59`). `readErrorChannel`'s own header
comment documents the exclusivity assumption explicitly: *"do not call
this when 15 is already open."*

`LABEL` (`src/external/label/label.s:194-207`) has no visibility into this
contract -- it directly `KernalOPEN`s LFN 15 itself, as any ordinary C64
program would. Sequence:

1. Any prior disk operation in the session (unavoidable in practice --
   something has to `LOAD`/`DIR` to find `LABEL.PRG` at all) calls
   `ensureL15Open`, which opens real KERNAL LFN 15 and sets
   `L15Device` to that device, and leaves it open on purpose (`file.asm:911-939`,
   `sendSA15Command`, never closes 15 -- that's the whole point of the
   cache).
2. `LABEL` runs and calls `KernalOPEN` on LFN 15. Real KERNAL OPEN on an
   already-open logical file fails with error 2, "FILE ALREADY OPEN" --
   not "device not present."
3. `label.s`'s `openErr` (`label.s:369-374`) prints a hardcoded
   `devMsg` ("DEVICE NOT PRESENT") for *any* OPEN failure -- it never
   inspects the actual KERNAL error code in `A`. This is why the reported
   message is misleading (**Bug 1**).
4. `label.s`'s `labelExit` (`label.s:376-383`) unconditionally
   `KernalCLOSE`s LFN 15 on every exit path (success, every error branch,
   interactive cancel) -- correctly closing the real channel, but with no
   way to tell `file.asm`'s `L15Device` that it did so.
5. `L15Device` still holds the stale device number. The next
   `checkDeviceReady`/`readErrorChannel`/`sendSA15Command` call for that
   device sees `L15Device` match and skips reopening LFN 15 (`file.asm:707-708`)
   -- but the channel isn't actually open. Every subsequent drive
   operation gated by `checkDeviceReady` (which is most of them) now fails,
   presenting exactly as "the drive is gone" (**Bug 2**, the real
   persistence mechanism).

This plan implements the user's chosen remediation: a new, general-purpose
kernel primitive, `DOS_RELEASE_L15`, that any external program calls after
independently closing LFN 15 itself, to tell the OS's cache the channel is
closed. `LABEL` becomes its first caller. Also fixes Bug 1 (the misleading
message) while in the area, since it's small, well-understood, and directly
surfaced by this investigation -- see Scope.

## Dependency Review

1. **Precedent**: this is structurally identical to the existing
   `DOS_SEND_COMMAND` addition (`10abc05`, spec at the now-historical
   `wiki/tasks/dos-send-command.md`) -- a new stable kernel primitive number,
   registered in both `include/command64.inc` and `include/ca65/command64.inc`,
   dispatched from `api.asm`, implemented in `file.asm`, documented in
   `wiki/api-reference.md`, and verified via a dedicated standalone ca65 test
   app (`tests/src/sendcmd/sendcmd.s` precedent) run live in VICE with true
   1541 drive emulation. This plan follows that same shape.
2. **Considered and rejected: migrate LABEL's command-channel calls to the
   existing `DOS_SEND_COMMAND` instead of adding a new primitive.**
   `DOS_SEND_COMMAND` already routes through `sendSA15Command`/`ensureL15Open`
   correctly and could replace `LABEL`'s own "I"/"U1"/"B-P"/"U2" round trips.
   However, `LABEL` also needs `LFN 2` opened as a raw drive-buffer channel
   (`"#"`) to write the 16 label bytes directly into drive RAM --
   `DOS_SEND_COMMAND` has no equivalent (it's a command-channel-only, one
   round-trip primitive; it doesn't expose an open data channel to the
   caller). Migrating `LABEL` fully would mean redesigning it around a
   second new primitive for raw buffer access, a much larger and riskier
   change than what was asked for, and would still need something like
   `DOS_RELEASE_L15` for any *other* future external program that wants
   direct LFN 15 access (this isn't `LABEL`-specific). Rejected in favor of
   the smaller, general primitive the user selected.
3. **`L15Device`'s sentinel value is confirmed to be `0`** (`file.asm:707,716-717`:
   `cmp L15Device` / `beq el15Done`, and `lda L15Device` / `beq el15SkipClose`
   treats `0` as "not open" -- real device numbers are always 8-11, so `0`
   is never a valid cached device and is already the implicit "closed"
   sentinel). No new sentinel or state byte is needed.
4. **Single call site is sufficient, placed in `labelExit`, not at entry.**
   Re-traced every exit path in `label.s`: `noArgErr`, `tooLongErr`,
   `openErr` (both the CMD_CHANNEL-fails and DATA_CHANNEL-fails branches),
   `cancelExit`, and the success path all funnel through `labelExit`, which
   *already* unconditionally closes LFN 15 there (even on paths where
   `LABEL` itself never opened it, e.g. `cancelExit` -- a harmless no-op
   `KernalCLOSE` on an unopened LFN either way). Placing the new call
   immediately after that existing `KernalCLOSE` covers every exit path
   uniformly with one addition, and needs no entry-side change: nothing
   else runs between `LABEL`'s own open/use/close of LFN 15, so `L15Device`
   cannot become stale *during* `LABEL`'s run, only after it exits.
5. **`sendSA15Command` deliberately never closes LFN 15** (`file.asm:930-939`)
   -- confirmed by reading its full body, not assumed -- so any prior
   `DOS_SEND_COMMAND`/`checkDeviceReady`/`readErrorChannel` call in the same
   session leaves LFN 15 genuinely, physically open on the real KERNAL side
   before `LABEL` ever runs. This is exactly the state the new standalone
   test (Verification Plan) must reproduce to prove the fix, not merely
   assert it.
6. **No other OS-level cache has the same hazard.** `checkDeviceReady`'s
   `CdrDevice`/`CdrRetried` are reset at the start of every call (not
   persisted across calls, unlike `L15Device`) -- re-confirmed by reading
   `checkDeviceReady`'s full body. `DATA_CHANNEL` (LFN 2) has no equivalent
   OS-level persistent-open cache anywhere in `file.asm`/`shell.asm`/`path.asm`
   (grepped for any `L2Device`-shaped pattern -- none exists), so `LABEL`'s
   own direct use of LFN 2 carries no equivalent risk.
7. **`debug.s` does not share this risk.** Its own direct `KernalOPEN` calls
   use LFN 1 with secondary addresses 0/1/2 (`debug.s:1116-1173,1322`), never
   secondary address 15 -- confirmed by reading every `KernalSETLFS` call
   site in `debug.s`. No other external program currently touches LFN 15
   directly.
8. **`src/AGENTS.md` has no plan-approval gate** (unlike
   `src/external/casm/AGENTS.md`), but the user explicitly asked for a
   detailed plan before implementation, so this document follows that
   request and the depth of the `DOS_SEND_COMMAND` precedent.

## Scope

Included:

- New kernel primitive `DOS_RELEASE_L15` (function number, next free slot
  after `DOS_VMM_WRITE = $5A`, so `$5B`), registered in both
  `include/command64.inc` and `include/ca65/command64.inc`.
- `src/command64/api.asm`: new `ahReleaseL15` dispatch handler.
- `src/command64/file.asm`: no new routine needed -- `ahReleaseL15` writes
  `L15Device` directly (it's a plain global label in the same Kick
  assembly, already referenced across files with no import ceremony,
  matching every other cross-file OS-core reference in this codebase).
- `src/external/label/label.s`: call `DOS_RELEASE_L15` once, in `labelExit`,
  immediately after the existing `KernalCLOSE #CMD_CHANNEL`.
- **Bug 1 fix, bundled in** (small, directly discovered by this
  investigation, same file): `openErr` currently discards the real KERNAL
  error code. Change it to print the actual two-digit decimal error number
  alongside the message (e.g. "DRIVE ERROR 02" instead of an always-wrong
  "DEVICE NOT PRESENT"), so a *genuine* device-absence (error 5) is still
  distinguishable from a channel conflict (error 2) or any other OPEN
  failure in the future.
- New standalone ca65 test app, `tests/src/l15release/l15release.s`
  (mirrors the `tests/src/sendcmd/sendcmd.s` precedent), proving the exact
  failure-then-fix mechanism against a real/true-emulated drive, not just
  asserting it.
- `wiki/api-reference.md`: document `DOS_RELEASE_L15` following the
  existing per-function format.
- `wiki/tasks/dos-release-l15.md`: task spec, mirroring
  `wiki/tasks/dos-send-command.md`'s role for this feature.
- `CHANGELOG.md`: Unreleased entry.

Excluded:

- Migrating `LABEL`'s command-channel round trips to `DOS_SEND_COMMAND`
  (Dependency Review item 2) -- out of scope, larger and riskier than
  requested.
- Any change to `ensureL15Open`'s own reopen logic, `checkDeviceReady`,
  `readErrorChannel`, or `sendSA15Command` -- all remain exactly as they
  are; only a new, additive way to *invalidate* the cache from outside is
  introduced.
- Auditing every other external program for the same class of bug beyond
  the check already done in Dependency Review item 7 (`debug.s`, confirmed
  clear) -- no other program currently touches LFN 15 directly.

## Contract

`DOS_RELEASE_L15` (new function number `$5B`):

- **Input:** None.
- **Output:** `Carry` = 0 (always succeeds -- this is a pure local state
  reset, no KERNAL I/O of its own).
- **Behavior:** Sets `L15Device` to `0` (the existing "not open" sentinel).
  Does **not** itself call `KernalCLOSE` -- the caller is expected to have
  already closed LFN 15 for real (as `LABEL` already does, unconditionally,
  immediately before this call). Calling it when LFN 15 was never actually
  open, or was already closed, is always safe (idempotent: resets an
  already-`0` value to `0`).
- **Contract for callers:** call this immediately after closing KERNAL LFN
  15 yourself, so the next `checkDeviceReady`/`readErrorChannel`/
  `sendSA15Command`/`DOS_SEND_COMMAND` call correctly reopens it instead of
  trusting a stale cache.

`label.s` change: `labelExit` becomes:
```
labelExit:
    lda #CMD_CHANNEL
    jsr KernalCLOSE
    lda #DATA_CHANNEL
    jsr KernalCLOSE
    lda #DOS_RELEASE_L15
    jsr OS_API
    lda SavedDevice
    sta CurrentDevice
    rts
```

`openErr` change: read the KERNAL error code (already in `A` on return from
the failed `KernalOPEN`, currently discarded) into a saved byte before
falling through to the shared error-exit path, and print it as two decimal
digits after `devMsg`'s text is shortened to a generic "DRIVE ERROR "
prefix. Exact message text and digit-conversion approach finalized during
implementation (reuses the existing `ldy #0 / lda X, y / ...` decimal-digit
pattern already present elsewhere in `label.s`'s status-printing code, or
`printDriveError`'s own loop shape, whichever proves simpler once written).

## Files to Create/Modify

| File | Action | Notes |
| --- | --- | --- |
| `brain/plans/label-l15-cache-release.md` | Create | this document |
| `include/command64.inc` | Modify | `DOS_RELEASE_L15 = $5B` |
| `include/ca65/command64.inc` | Modify | `DOS_RELEASE_L15 = $5B` |
| `src/command64/api.asm` | Modify | `ahReleaseL15` dispatch entry |
| `src/command64/BUILD_OS` | Modify (build-managed) | content-hash-gated increment |
| `src/external/label/label.s` | Modify | `labelExit` call site; `openErr` real-error-code fix |
| `src/external/label/BUILD_LABEL` | Modify (build-managed) | content-hash-gated increment |
| `tests/src/l15release/l15release.s` | Create | standalone verification harness |
| `tests/src/l15release/BUILD_TEST_L15RELEASE` | Create | starting build counter (1000) |
| `CMakeLists.txt` | Modify | register `test_l15release` ca65 app target |
| `wiki/api-reference.md` | Modify | document `DOS_RELEASE_L15` |
| `wiki/tasks/dos-release-l15.md` | Create | task spec (mirrors `dos-send-command.md`) |
| `CHANGELOG.md` | Modify | Unreleased entry |

## Key Design Decisions

See Dependency Review items 1-7 above for the full reasoning. Summary:

1. New primitive, not a migration to `DOS_SEND_COMMAND` -- smaller, general,
   matches what was approved.
2. Single call site (`labelExit`, after the existing close), not an
   entry-side call too -- sufficient because nothing else runs concurrently
   during `LABEL`'s own lifetime to desync the cache mid-run.
3. The primitive itself does no KERNAL I/O -- it only resets `L15Device`,
   keeping it trivially safe to call even when nothing was actually open.
4. Bundle the `openErr` real-error-code fix into this same plan (not a
   separate one) -- small, directly discovered here, and leaving it
   unfixed would keep misdiagnosing *any* future OPEN failure in `LABEL`,
   including genuine device-absence.

## Verification Plan

### Standalone primitive verification (`tests/src/l15release/l15release.s`)

Mirrors `tests/src/sendcmd/sendcmd.s`'s style (simple linear ca65 app, run
manually in VICE with true drive emulation -- this cannot be a pass/fail
automated harness since it depends on real IEC/KERNAL state, matching
`DOS_SEND_COMMAND`'s own precedent):

1. Call `DOS_SEND_COMMAND` with a harmless command (`"8:I0"`) -- this
   internally calls `ensureL15Open`, genuinely opening LFN 15 on device 8
   and leaving it open (per `sendSA15Command`'s documented behavior).
2. Attempt a raw `KernalOPEN` of LFN 15 directly (no filename, SA 15) --
   **expected: fails with error 2 ("FILE ALREADY OPEN")**, printed to
   screen. This step independently reproduces the exact conflict
   diagnosed above, at the KERNAL level, not just by static reading.
3. Call `DOS_RELEASE_L15`.
4. Repeat the same raw `KernalOPEN` of LFN 15 -- **expected: succeeds**,
   proving the invalidation both freed the real channel state association
   and let a fresh, independent open through.
5. `KernalCLOSE` LFN 15 (simulating `LABEL`'s own close), then call
   `DOS_RELEASE_L15` again (simulating `LABEL`'s actual `labelExit`
   sequence).
6. Call `DOS_SEND_COMMAND` once more with another harmless command --
   **expected: succeeds cleanly**, proving the cache correctly resyncs
   afterward and the fix causes no regression to the normal caching path.
7. Print PASS/FAIL for each step's expected outcome.

### End-to-end reproduction (the original bug report)

1. Run a disk operation that populates the cache: `DIR` or `LOAD` anything.
2. Run `LABEL <name>` -- **expected: succeeds** ("LABEL UPDATED"), where
   before the fix it failed immediately with the misleading message.
3. Run another disk operation immediately after (`DIR`, `VOL`, or `LOAD`)
   -- **expected: succeeds**, where before the fix the drive appeared
   permanently gone until reset.
4. Regression: confirm `LABEL` run in isolation (no prior disk op in the
   session) still works exactly as before -- `DOS_RELEASE_L15` on a
   never-cached (`L15Device` already `0`) run must be a no-op, not a new
   failure mode.
5. Regression: confirm every other command that relies on
   `ensureL15Open`/`checkDeviceReady` still works normally after `LABEL`
   has run (`LOAD`, `DIR`, `VOL`, `DELETE`, `RENAME`, `PATH`,
   `DOS_SEND_COMMAND`-based `FORMAT`) -- proves the cache resyncs correctly
   for every consumer, not just the two probed directly in the standalone
   test.
6. Confirm Bug 1's fix: force a *genuine* device-absence (switch to an
   empty/nonexistent device number) and confirm `LABEL` now reports a
   real, distinguishable error rather than always the same hardcoded text.

### Build verification

- `command64`/`BUILD_OS`, `label`/`BUILD_LABEL`, and the new
  `test_l15release` target all build with 0 warnings/errors.
- `image_d64` and `test_image_d64` build clean and include the new test
  binary.
- No-change rebuild stability confirmed for `command64` and `label` after
  the version-only state settles (this project's OS core has no
  version-stage bump convention tied to routine bug fixes, per
  `src/AGENTS.md` and recent bug-fix commit history -- only the
  content-hash-gated build counters apply here).

## Failure and Cleanup

No new failure mode: `DOS_RELEASE_L15` cannot itself fail (always returns
`Carry` = 0). If the standalone test's step 2 unexpectedly *succeeds*
(i.e. the conflict doesn't reproduce), that means the diagnosed mechanism
is wrong and this plan needs to be revisited before proceeding to the fix
-- stop and re-investigate rather than shipping a fix for an unconfirmed
cause.

## Stop Conditions

Stop if the standalone test's step 2 (raw `KernalOPEN` of LFN 15 while
`DOS_SEND_COMMAND` has it cached-open) does *not* fail as predicted --
that would mean this plan's root-cause diagnosis is incomplete or wrong,
and the fix must not proceed on an unconfirmed mechanism. Stop if any
regression case in the end-to-end verification fails after the fix is
applied, requiring investigation before completion.

## Progress

- 2026-07-25: Drafted after a full investigation (static analysis plus
  cross-referencing the `DOS_SEND_COMMAND` precedent) confirmed two real
  bugs: `label.s`'s hardcoded "DEVICE NOT PRESENT" message regardless of
  actual KERNAL error code, and the `L15Device` cache desync causing
  persistent drive unavailability. User selected the new-kernel-primitive
  remediation over migrating `LABEL` to `DOS_SEND_COMMAND` or a
  message-only fix. Awaiting approval before implementation begins.
