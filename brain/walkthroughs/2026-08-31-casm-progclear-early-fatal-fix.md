---
feature: casm-progclear-early-fatal-fix
plan: brain/plans/2026-08-31-casm-progclear-early-fatal-fix.md
taskwarrior: 43 (5dad4e4f-8392-468f-8807-0ff37a98c33c)
status: awaiting user sign-off
completed: 2026-08-31
---

# Walkthrough: CASM diagPrintFatal / uninitialized CasmProgFlags fix

Small corrective WP for the defect exposed during the CASM
memory-optimization WP's Increment 9 and deferred there. Branch
`feature/casm-progclear-early-fatal-fix` off `main` `96eb057`; three
increments. CASM `0.5.1` -> `0.5.2` build 1392.

## The bug

`diagPrintFatal` (`diagnostics.s`) opens with `jsr progressClearTransient`
(from progress-indication Increment 7). That routine tests `CasmProgFlags`
bit 0, and `CasmProgFlags` is zeroed only by `progressInit` -- which
`casm.s:start` did not call until `startPass1`. Any diagnostic raised
before Pass 1 (CLI / file / lexer-init failures) therefore reached
`diagPrintFatal` with `CasmProgFlags` = uninitialized RAM; a bit-0-set
garbage byte made `progressClearTransient` erase the current screen line,
truncating the banner (`CASM V` instead of `CASM V0.5.x.nnnn`).

Pre-existing on `main` from progress-indication Increment 7. Finding C of
the memory-optimization WP rewrote `diagPrintFatal`'s dispatch but kept
the `progressClearTransient` call verbatim; it did not introduce this.

## The fix

One change in `casm.s:start`: move the single `jsr progressInit` from
`startPass1:` up into the early-init block, placed **before**
`resourcesInit`, alongside `diagClearLoc` / `listingStateInit` /
`listingFileInit` -- all pure BSS clears with no OS/VMM call, put first so
an early fatal exit is safe. `casm.s` already imports `progressInit`. No
`progress.s` or `diagnostics.s` change.

## Evidence

**Static (Increment 1).** Disassembly of `start`: `$380A JSR progressInit`
is the 4th call, ahead of `resourcesInit`, `cliParse`, the `versionBanner`
print (`$382A`), and both `JMP startPass1` / `JMP startFatal`.
`startPass1` no longer calls it (exactly one `jsr progressInit` in the
module). `resourcesInit` / `cliInit` / `fileIoInit` / `sourceInit` are all
unconditionally `clc`/`rts`, so nothing can reach `diagPrintFatal` before
`$380A`. This proves `CasmProgFlags = $00` at `progressClearTransient` for
**every** RAM state, not just a tested one -- it replaces the plan's
single-value checkpoint read with a stronger argument.

**Live (Increment 2).** Command64 booted fresh; banner `CASM V0.5.2.1392`:

| Run | Raise site | Result |
| --- | --- | --- |
| `casm <37-char name>` -> `FILENAME TOO LONG` | `cliParse` | **full `CASM V0.5.2.1392` banner**, diagnostic, prompt |
| `casm nonesuch.s` -> `CANNOT OPEN INPUT` | `fileOpenInput` (later) | **full banner**, clean return |
| `casm casmpg128.s` | -- | identical progress sequence, `00129 BYTES` unchanged, `CASM: INPUT VALIDATED` |
| `test_casm_progress` harness | -- | 20+ cases, `CASM PROGRESS: PASS` |

The first case is exactly the one that truncated to `CASM V` with the
pre-fix build in memory-optimization Increment 9.

**No regression.** Full `cmake --build build` clean;
`verify_casm_diag_table.py` passes; no-change rebuild stable. Envelope
byte-identical to the memory-optimization close (`__MAIN_LAST__` `$A169`,
headroom 2,710, CODE `$51A3`) -- the relocation is net-zero size. No
emit-path file touched; assembled output unchanged (live `00129 BYTES`).

## Completion gate

- [x] `progressInit` proven (disassembly) to run before the banner and
      every early-fatal branch; `startPass1` no longer calls it.
- [x] Deterministic evidence that `CasmProgFlags = $00` at
      `progressClearTransient` on an early fatal -- via the static proof
      (all RAM states), substituting for the checkpoint read.
- [x] User-visible: full banner + correct diagnostic on two different
      early-fatal raise sites.
- [x] No-regression: clean assembly byte count unchanged
      (`test_casm_progress` PASS, `verify_casm_diag_table.py` PASS, full +
      no-change rebuild clean).
- [x] CASM bumped `0.5.1` -> `0.5.2` (build 1392).
- [ ] Trackers agree; user approves closing task 43.

## Manual step for the user

Nothing further to run. Please review and confirm task 43 may be closed;
then the branch merges to `main`.
