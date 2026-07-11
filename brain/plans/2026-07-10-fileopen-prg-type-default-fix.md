---
feature: fileopen-prg-type-default-fix
created: 2026-07-10
status: planned
---

# Plan: Fix file read/write losing first 2 bytes (filetest / all file I/O)

## Goal & Rationale

`test_filetest` reports reading back truncated content, and independent
inspection of `TEST.TXT` with the `debug` tool shows the file is missing its
first two characters ("He" of "HELLO FROM COMMAND64!"). The user reports
this "impacts all forms of file operations," which pointed at the shared OS
file I/O layer (`src/command64/file.asm`) rather than the test itself.

### Root cause

`fileOpen` (`src/command64/file.asm:159-198`) requires callers opening a file
for **write** to put the desired file type character (`'S'`, `'P'`, `'U'`,
`'R'`) into `HexValHi` before calling `DOS_OPEN_FILE`. If `HexValHi` doesn't
hold one of those valid type bytes, `fileOpen` **silently defaults the file
to type PRG** (`file.asm:186-187`, "Default to 'P' if not specified or
invalid").

`tests/src/filetest/filetest.s:30-38` opens `TEST.TXT` for write and only
sets `HexValLo` (mode); it never sets `HexValHi` (type). So the file is
silently created as **PRG**, not SEQ, even though it's plain text.

This matters because this codebase already has an established, documented
convention that PRG-typed file content begins with a 2-byte load-address
header, and several places implement it explicitly:
- `src/external/debug/debug.s:1243-1336` — writes a 2-byte load-address
  header when writing PRG (skips it for SEQ/USR), and by symmetry treats a
  loaded/inspected PRG's first 2 bytes as that header, not data.
- `src/command64/shell.asm:841-843, 1488-1490, 2290-2292, 2772-2774` — each
  explicitly skips "2-byte load address" when reading back a PRG-typed file.
- `src/external/edlin/cmds.s:1132-1135` and `shell.asm:1330-1332` show the
  *correct* pattern: explicitly setting `HexValHi = 'S'` ($53) before a
  write-mode open.

`file.asm`'s own generic `fileRead`/`fileWrite` (`file.asm:306-387,
389-464`) are header-agnostic — they read/write exactly the requested byte
count with no header logic. That's correct for SEQ but means any tool in
the system that *does* apply PRG header semantics (like `debug`'s
loader/viewer) will strip the first 2 bytes of a file that was only
accidentally tagged PRG, which is exactly what the user observed via
`debug`. This explains why the bug "impacts all forms of file operations":
it's a systemic default in `fileOpen`, not a `file.asm` byte-counting bug —
any write-mode open that forgets to set `HexValHi` is affected.

Confirmed this is not an isolated mistake: `tests/src/handletest/handletest.s:33-42,
52-58` has the exact same omission (no `HexValHi` set before write-mode
open); it just doesn't visibly break because its test files are literally
named `T0.PRG`..`T8.PRG`, so the accidental PRG default happens to match.

### Ruled out during investigation

- `FileLenLo`/`FileLenHi` byte-count plumbing: `api.asm`'s `ahRead`/`ahWrite`
  (`api.asm:106-132`) always freshly copy `HexValLo/Hi` → `FileLenLo/Hi`
  immediately before calling `fileRead`/`fileWrite`, so the stale filename
  length that `fileOpen` stashes in `FileLenLo` (`file.asm:202`) is always
  overwritten before it could matter. Not a bug.
- `readErrorChannel`/`checkDeviceReady` (`file.asm:707-844`) target LFN 15
  exclusively via their own `CHKIN`, never the file's own LFN — they can't be
  consuming bytes from the file's data stream.
- The secondary address used for the file's own channel is always `LFN =
  handle + 2` (2-9), never the special KERNAL-LOAD-triggering values 0/1, and
  `fileRead`/`fileWrite` use manual `CHKIN/CHRIN`/`CHKOUT/CHROUT` loops, not
  the KERNAL `LOAD`/`SAVE` vector — so `file.asm` itself never inserts or
  strips a load-address header. The header handling is purely an
  application-level convention other tools (`debug`, `shell`) implement on
  top of whatever type `fileOpen` picked.

## Scope

In scope: `fileOpen`'s default file-type fallback, and the two test programs
that rely on it implicitly (`filetest.s`, `handletest.s`).

Out of scope: the PRG-header read/write conventions in `debug.s`/`shell.asm`
themselves — those are already correct and consistent; nothing there needs
to change.

## Files to Create/Modify

| File | Action | Notes |
|------|--------|-------|
| `tests/src/filetest/filetest.s` | Modify | Set `HexValHi = $53` ('S', SEQ) before the write-mode `DOS_OPEN_FILE` call (lines 30-38), matching the pattern in `edlin/cmds.s:1132-1135`. |
| `tests/src/handletest/handletest.s` | Modify | Set `HexValHi = $50` ('P') explicitly before both write-mode opens (lines 33-42, 52-58) — content doesn't matter for this test, but files are named `.PRG` so keep that consistent, just make it explicit instead of accidental. |
| `src/command64/file.asm` | Modify | Change the "unspecified/invalid type" fallback (lines 186-187) from defaulting to `'P'` to defaulting to `'S'` (SEQ) — defense in depth so future callers that forget `HexValHi` fail safe instead of silently becoming PRG. |

## Key Design Decisions

- Default file type on unspecified/invalid `HexValHi` changes from PRG to
  SEQ. SEQ carries no header-convention baggage anywhere else in the
  codebase, making it the safe "no special semantics" default. This is a
  behavior change for any *other*, not-yet-discovered caller that also
  relies on the implicit PRG default — none are currently known, but this is
  the risk being accepted in exchange for closing the footgun.
- Fixing the two call sites is necessary regardless of the default-fallback
  change, since relying on a silent default (of either type) is fragile.

## Verification Plan

- Rebuild: `cmake --build build --target test_image_d64` (or the specific
  `test_filetest`/`test_handletest` targets).
- Run `test_filetest.prg` under VICE (via the `mcp__c64` tools): confirm the
  printed output is `READ FROM FILE: HELLO FROM COMMAND64!` with no dropped
  characters.
- Use the `debug` external app to load/inspect `TEST.TXT` directly from the
  disk image and confirm its raw content is the full, untruncated string
  (and that its directory-listed type is now SEQ, not PRG).
- Run `test_handletest.prg` under VICE to confirm the 8-handle-limit test
  still passes (it isn't asserting on file content, so behavior should be
  unchanged besides the type now being explicit).
- Re-grep for `DOS_OPEN_FILE` write-mode call sites to confirm no other
  caller was missed (as of this writing: `api.asm:30` (dispatch, N/A),
  `edlin/cmds.s:1015,1138`, `shell.asm:1018,1342,1355`, `edlin/buffer.s:78`,
  `filetest.s:35,64`, `handletest.s:40,57` — all non-test call sites already
  set `HexValHi` correctly).

## Progress

- 2026-07-10: Investigated and root-caused via static analysis (see above).
  Plan written; not yet implemented pending user review.
- 2026-07-11: Codex re-investigated the `test_filetest` report after the
  observed screen output was `READ FROM FILE: G` while `debug`-based
  inspection appeared to show `LLO FROM COMMAND64!`. The two observations
  are related but not identical:
  - The apparent missing `"He"` in `debug` is fully explained by accidental
    PRG typing. `fileOpen` defaults write-mode opens to `P` when `HexValHi`
    is unset, and `test_filetest` does not set `HexValHi` before opening
    `TEST.TXT` for write. The first two bytes written are `$48,$45`
    (`"HE"`), so a PRG-style load naturally treats them as the load address
    `$4548` and presents memory beginning with the third byte (`"LLO..."`).
    This does not prove those bytes were absent on disk.
  - The screen output `READ FROM FILE: G` still indicates a real read-path
    problem. `fileRead` currently checks `KernalREADST` before the `CHRIN`
    that would update status for the current data byte. This means stale
    status from previous I/O can stop a valid read early, or can allow one
    invalid/stale byte to be stored before EOF/error is detected. That issue
    is tracked separately as Taskwarrior task 24 and should be fixed in
    `fileRead`, not papered over in callers.
  - A secondary hazard was also identified in `checkDeviceReady`: it reads
    only the first two characters of the command-channel status (`00`, `73`,
    `74`, etc.) and then calls `KernalCLRCHN`, leaving the rest of the status
    line pending on LFN 15. Because LFN 15 is intentionally kept open, this
    partial-drain behavior can poison later status queries. It does not
    explain the two-byte `"He"` symptom by itself, but it is part of the same
    shared file-operation fragility and should be corrected by draining the
    full status line after capturing the first two status digits.

## Implementation Plan

1. Make `test_filetest` explicit about file type:
   - Before its write-mode `DOS_OPEN_FILE`, set `HexValHi = 'S'`.
   - Expected result: `TEST.TXT` is created as SEQ, so tools that apply PRG
     load-address semantics no longer reinterpret the first two data bytes.

2. Make `test_handletest` explicit about file type:
   - Before each write-mode `DOS_OPEN_FILE`, set `HexValHi = 'P'`, matching
     the existing `.PRG` test filenames.
   - Expected result: no behavior change for the handle-limit test, but the
     test no longer depends on an implicit kernel default.

3. Change the kernel's write-mode default type:
   - In `src/command64/file.asm`, change the fallback for invalid/unspecified
     `OpenType` from `'P'` to `'S'`.
   - Rationale: SEQ is the safer DOS-like default for the generic file API
     because it has no 2-byte load-address convention.

4. Fix `fileRead` status sequencing:
   - Clear `KernalStatus` before entering the loop, as already done.
   - For each byte, call `KernalChRIN` first, then inspect `KernalREADST`.
   - Store/count the byte only when it is valid for the API contract. EOF or
     transport error must not leave a garbage byte in the caller's buffer.
   - Preserve the existing returned count in `HexValLo/Hi` and `Carry`
     behavior unless the implementation deliberately formalizes new error
     semantics.

5. Drain LFN 15 completely in `checkDeviceReady`:
   - Capture the first two status digits for classification.
   - Continue reading until carriage return, EOI, or the existing safety cap,
     using the same full-line behavior as `drainOpenErrorChannel`.
   - Expected result: repeated preflight checks do not leave partial command
     channel responses pending.

6. Update API documentation:
   - Document `HexValHi` as the optional write-mode file type input for
     `DOS_OPEN_FILE`.
   - State that omitted/invalid type now defaults to SEQ.
   - Keep PRG load-address handling documented as an application/tool
     convention, not behavior performed by `fileRead`/`fileWrite`.

7. Verification:
   - Build `test_image_d64`.
   - Ask the user to run `test_filetest`; expected screen output is
     `READ FROM FILE: HELLO FROM COMMAND64!`.
   - Ask the user to inspect the directory entry and/or raw file with
     `debug`; expected type is SEQ and raw data begins with `$48,$45`.
   - Ask the user to run `test_handletest`; expected behavior remains
     unchanged.
   - Re-run or manually exercise EDLIN new-file/read/write behavior because
     it previously exposed the stale `READST` bug.
