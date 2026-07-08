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
