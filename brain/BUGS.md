# Known Bugs

Bugs found during investigation but not yet triaged/fixed. Each entry needs a decision on the correct remediation approach before implementation.

## OPEN

### BUG-001: `load` silently no-ops app-table registration when no REU is present

- **Status**: Investigated, needs remediation decision
- **Found**: 2026-07-06
- **Area**: `src/command64/shell.asm` (`cmdLoad`), `src/command64/apptable.asm` (`aptList`, `aptPrintLoadInfo`), `src/command64/vmm.asm` (`vmmInit`, `vmmReadByte`)

**Behavior**: On a system with no REU, `load` still performs the real KERNAL load into C64 RAM and prints a normal-looking "name / address / size" success line via `aptPrintLoadInfo` (`apptable.asm:666-710`). However, both the table-full check and app-table registration (`aptRelocate`/`aptRegister`) in `cmdLoad` (`shell.asm:551-637`) are silently skipped whenever `AptSegLo|AptSegHi == 0` (i.e. AppTable was never initialized because `vmmInit` found no REU). Afterward, `ps` (`aptList`, `apptable.asm:721-737`) reports `"no apps loaded"` because `vmmReadByte` (`vmm.asm:258-263`) always returns 0 when `vmmInitialized` is false.

The only diagnostic surfaced to the user is a one-time `"Warning: No REU detected. VMM disabled."` printed once at shell boot (`shell.asm:92-123`, `noReuMsg` at `shell.asm:2621-2623`). It is not repeated at `load` time and doesn't mention that app-table tracking / `ps` / `free` will be non-functional for the session.

**Net effect**: `load` looks like it fully succeeded (file loads, prints success row) but silently omits app-table bookkeeping with no per-call error or warning. User has no way to tell, from `load`'s output alone, whether the app was actually tracked.

**Needs a decision on**:

1. Should `cmdLoad` check `vmmInitialized` and print an explicit warning/error at load time (vs. relying solely on the boot-time message)?
2. Should the success line distinguish "loaded and tracked" vs. "loaded, untracked (no REU)"?
3. Should `load` refuse to proceed / require a flag to load without tracking, or is untracked-load-without-REU acceptable intended behavior for REU-less systems?

### BUG-002: `fileOpen` silently defaults unset/invalid file type to PRG, truncating file content read back by PRG-aware tools

- **Status**: Investigated, plan written (`brain/plans/2026-07-10-fileopen-prg-type-default-fix.md`), not yet implemented
- **Found**: 2026-07-10
- **Area**: `src/command64/file.asm` (`fileOpen`), `tests/src/filetest/filetest.s`, `tests/src/handletest/handletest.s`

**Behavior**: `fileOpen` (`file.asm:159-198`) requires write-mode callers to put a file-type character ('S'/'P'/'U'/'R') into `HexValHi`. If `HexValHi` isn't a valid type, it silently falls back to PRG (`file.asm:186-187`). `tests/src/filetest/filetest.s:30-38` opens `TEST.TXT` for write without ever setting `HexValHi`, so the file is silently created as PRG instead of SEQ.

The codebase has an established convention (implemented in `debug.s:1243-1336` and `shell.asm:841-843,1488-1490,2290-2292,2772-2774`) that PRG-typed file content begins with a 2-byte load-address header, and PRG-aware tools skip those 2 bytes on read. Since the plain-text `TEST.TXT` got silently mistyped as PRG, PRG-aware tools (e.g. `debug`) strip its first 2 real content bytes ("He" of "HELLO FROM COMMAND64!") on read/inspect, even though `file.asm`'s own generic `fileRead`/`fileWrite` are header-agnostic and never wrote/expect a header themselves.

`tests/src/handletest/handletest.s:33-42,52-58` has the identical omission but doesn't surface visibly because its filenames are already `.PRG`.

**Net effect**: any write-mode `DOS_OPEN_FILE` caller that forgets to set `HexValHi` gets a silently-mistyped PRG file; if any PRG-aware code later reads it back, the first 2 content bytes vanish. Matches user report of `test_filetest` losing "He" from the start of its readback, reproduced via independent inspection with the `debug` tool.

**Needs a decision on**: plan proposes (a) fix the two test call sites to set `HexValHi` explicitly, and (b) change `fileOpen`'s fallback default from PRG to SEQ as defense-in-depth. See the plan doc for full reasoning and ruled-out alternate theories (`FileLenLo`/`FileLenHi` staleness, LFN-15 error-channel cross-talk, KERNAL LOAD/SAVE header semantics — all checked and ruled out).

**Update 2026-07-11**: follow-up investigation (recorded in the plan doc's Progress section) found the PRG-mistyping above fully explains the `debug`-tool "He" discrepancy, but does not by itself explain the separate `READ FROM FILE: G` screen output — that points at a real ordering bug in `fileRead` (`file.asm`: checks `KernalREADST` before the `KernalChRIN` that would set status for the byte just read), tracked separately as Taskwarrior task 24. A related partial-drain hazard in `checkDeviceReady` (only reads 2 status digits off LFN 15 before `CLRCHN`, leaving the rest of the status line pending) was also found and folded into the same plan. Both are now part of the plan's implementation steps 4-5.
