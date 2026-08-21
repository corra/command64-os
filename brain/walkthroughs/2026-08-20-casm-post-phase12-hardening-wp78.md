---
feature: casm-post-phase12-hardening-wp78
plan: brain/plans/2026-08-20-casm-post-phase12-hardening.md
date: 2026-08-20
---

# Walkthrough: WP78 — TYPE Screen Double-Line-Advance Fix

## Scope

Taskwarrior task 40. Reported as a `listing.s` bug (40-column row + trailing
CR double-advancing the screen), but root-caused during this WP to Command64's
generic `TYPE` command instead — see the plan's Progress log for the full
investigation trail, including a first fix attempt that silently didn't work.

## Root Cause

`cmdType` (`src/command64/shell.asm`) forwards every raw byte of a file to
KERNAL CHROUT, including an embedded CR. The real KERNAL screen editor
defers its line wrap: after printing the 40th column, the cursor-column
byte (`$D3`/PNTR) reads **40**, not 0 — the actual row advance and column
reset happen lazily, on the *next* character. `cmdType` had no awareness of
this, so a CR immediately following a full 40-column line triggered its own
independent line advance on top of the pending deferred wrap, producing a
blank line.

## Fix

In `cmdType`'s print loop: before forwarding a raw CR byte to CHROUT, check
`KernalScreenColumn` (`$D3`, added to `include/command64.inc`); skip the CR
when it already reads 40. A CR reached at any other column still prints
normally. `include/command64.inc` and `src/command64/shell.asm` are the only
source changes.

A `CommandShell`-segment build failure (zero slack against the fixed-address
`VmmData` segment) was hit and resolved by moving all of `cmdType` into the
existing `ShellExt` overflow segment — the same pattern already used for
`cmdMore` immediately following it in the same file, not a new convention.

## Verification (live VICE 3.10, C64SC)

1. **Empirical KERNAL column-timing check** (BASIC immediate mode, plain
   reset machine, no Command64 involved): `FOR I=1 TO 40:PRINT"A";:NEXT:PRINT
   PEEK(211)` printed **40**, confirming the deferred-wrap model and
   invalidating a first fix attempt that checked for 0.
2. **Regression fixture**: a hand-built SEQ file (`"X"<CR>`, then exactly 40
   `"A"` bytes `<CR>`, then `"AFTER"<CR>`) written with `cc1541 -T SEQ`,
   attached as disk unit 8, booted through Command64.
3. `flush` run before and after per this project's live-test convention.
4. `type typewrap2` — screen RAM read via `vice_memory_read` at `$0400` and
   decoded with `tools/vice_screen_decode.py` (not OCR). Output:
   ```
   C64[8]:> type typewrap2
   x
   aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
   after

   C64[8]:>
   ```
   The 40-`a` row wraps directly into `after` with no blank row between them.
   (One blank row before the final prompt is the same trailing-CR behavior
   every file gets, unrelated to this bug.)
5. Regression: `type banner.s` (an ordinary short-line file) prints
   unaffected, confirming the CR-suppression logic doesn't touch normal
   lines.
6. Build: `cmake --build build --target command64` clean at build 2670; a
   repeat build left `BUILD_OS` unchanged (true no-change rebuild).
   `cmake --build build --target image_d64` builds clean with all
   applications (`dash`, `casm`, etc.) still present.

## Outcome

Fix confirmed working live. Taskwarrior task 40 marked complete. User
approved closing WP78 on 2026-08-20.
