---
feature: casm-progress-increment02-design-abi-review
plan: brain/plans/2026-08-24-casm-progress-increment02-design-abi-review.md
date: 2026-08-24
status: awaiting-approval
---

# Design/ABI Review: CASM Progress Indication

## Method

Rather than estimate feasibility against Increment 1's 231-byte headroom
finding, a real `progress.s` was written against the parent plan's full
`User-Visible Contract` and `Architecture` sections, assembled with `ca65`,
and linked with `ld65` against CASM's actual `casm_3800.cfg` and actual
`build/out_casm/*.o` object files -- the same linker config and the same
compiled CASM modules the real build produces. This is not an estimate; it
is a real link, and its errors and successes are ld65's own, not derived
arithmetic. Working files: `progress.s`, `driver.s` (a stub that references
every export so nothing is dead-stripped from the measurement), and the
resulting `.map`/`.lbl`/`.prg` outputs, all under this session's scratchpad
(not committed -- see Disposition below).

## Finding 1: the full spec does not fit 231 bytes -- by exactly 573 bytes

A first version implementing all 13 routines from the parent plan's
"Expected public interface" list (init, source-load byte-cadence, begin-pass,
per-statement hook, frame transition, complete-pass, output-write byte-cadence,
`.INCBIN`/byte-heavy-directive byte-cadence, clear-transient, suspend,
final-summary, pass-total comparison) measured at:

- CODE + inline string literals: 782 bytes
- BSS: 22 bytes
- **Total: 804 bytes**

Linking this against CASM's real objects with the real `casm_3800.cfg`
budget produced ld65's own verdict, not an estimate:

```
casm_3800.cfg:3: Warning: Segment 'BSS' overflows memory area 'MAIN' by 573 bytes
ld65: Error: Cannot generate most of the files due to memory area overflow
```

This confirms Increment 1's rough 500-900-byte estimate was directionally
correct, now with an exact number. It is not a "write tighter code" problem:
the measured module already shares a single fixed-width decimal-digit macro
across every numeric field, uses one private print-string/print-char pair
(not diagnostics.s's, to avoid an import cycle), and does not mirror whole
filenames (see Finding 2). The overrun is structural -- 13 distinct routines
plus roughly a dozen message strings is inherently more surface than the
231-byte margin can hold, however tightly written.

## Finding 2: a caller-supplied filename pointer needs zero page, which is forbidden

The transient line's 8-character filename field was first designed to take a
caller-supplied pointer (`X`/`Y`) into an existing name buffer, read via
`(ptr),Y` indirect-indexed addressing. `ca65` rejected this outright:
indirect-indexed addressing is a hardware requirement of the 6502, not a
`ca65` limitation -- the pointer operand *must* live in zero page. The ABI
section explicitly forbids new zero-page storage, and self-modifying an
absolute,Y load's operand bytes at runtime was rejected as a worse tradeoff
(harder to reason about, harder for a future maintainer, no precedent for it
elsewhere in `progress.s`'s sibling modules).

**Resolution, now frozen:** the caller copies the already-truncated 8-byte
name into `CasmProgArgNameBuf`, a plain (non-ZP) BSS buffer `progress.s`
owns, before calling `progressRenderTransient`. This is 8 bytes of "bounded
rendering scratch," which the ABI section explicitly allows -- it is not
"mirroring a whole filename" (up to `CASM_FILENAME_MAX` = 63 bytes); it is
mirroring only the field width the screen protocol already requires
truncating to. Call sites (source.s, include.s, at Increment 5) already
have their own zero-page pointers for the authoritative name and can do
this copy cheaply.

## Finding 3: `CASM_DIAG_PASS_MISMATCH` ($2F) is a different check, not reusable

`common.inc` already defines `CASM_DIAG_PASS_MISMATCH = $2F` (Phase 6B/WP30),
raised today by `emitCheckPassAgreement` (`emit.s:189-205`) on final-PC
disagreement between passes. The parent plan's new statement-*count*
disagreement check is explicitly "an additional deterministic-replay check,
not a replacement for" that existing one -- reusing the same ID would blur
two distinct failure causes under one message. Two new IDs are frozen,
contiguous after the last allocated Phase 13 ID (`$54`):

```
CASM_DIAG_PROGRESS_COUNTER_OVERFLOW    = $55
CASM_DIAG_PROGRESS_PASS_TOTAL_MISMATCH = $56
.assert CASM_DIAG_PROGRESS_PASS_TOTAL_MISMATCH = CASM_DIAG_PROGRESS_COUNTER_OVERFLOW + 1, ...
```

matching the codebase's own established contiguous-allocation-with-assert
convention exactly.

## Resolution: split MAIN growth and scope trim (user-directed, 2026-08-24)

Presented with the exact 573-byte gap and three options (shrink to fit,
grow MAIN, or split), the user chose to split the difference and asked that
the road not taken be noted for possible future expansion.

**Scope trimmed** (saves 70 measured bytes, 804 -> 734 total):
`progressSourceLoadBytes` (256-byte-cadence display during source loading)
and `progressDirectiveBytes` (byte-cadence display during `.INCBIN`/`.RES`/
`.FILL`/`.ALIGN`) are dropped entirely, along with `progressFrameTransition`
as its own routine (frame-transition redraws reuse `progressRenderTransient`
directly with updated `CasmProgArgDepth`/`CasmProgArgFileId` -- no separate
entry point needed). `progressOutputBytes` is trimmed to
`progressAccumulateOutputBytes`: pure accumulation, no transient redraw
during the write itself -- the running total exists only to supply
`progressFinalSummary`'s final byte count, which is unaffected.

None of this touches the *required* persistent-line example
(`load:`/`p1:`/`p2:`/`write:`/`done:`) -- those are one-shot prints cheap
enough for the calling module (`casm.s`) to emit directly via its own
existing `diagPrintString`-equivalent at the relevant orchestration point,
not something `progress.s` needs dedicated machinery for.

**What this drops from the user-visible contract:** no live byte-count
feedback *during* a long `.INCBIN` read, a large `.RES`/`.FILL`/`.ALIGN`
run, or a long source load -- those operations will appear to pause (no
transient-line update) until they complete, at which point the next
statement-count redraw or persistent line resumes visible progress. The
throttled per-statement counter, the full 5-field transient line (pass,
depth, file id, filename, line, statement count), both persistent
pass-transition lines, the final summary, and both new diagnostics are
all retained in full.

**MAIN grown** from `$6C00` to `$7000` (+1024 bytes/`$400`) in
`casm_3800.cfg` and its `casm_3900.cfg` relocation-diff twin. Verified by
a real link of the trimmed module against CASM's actual objects at the
grown size:

```
__MAIN_SIZE__ = $7000
__MAIN_LAST__ = $A5F7
```

leaving 1033 bytes (`$AA00 - $A5F7`) of fresh headroom -- comfortably more
than the 503 bytes the trimmed module needed, and still 6665 bytes clear of
the hard `$C000` I/O-region boundary. This is a pure build-config change to
CASM's own linker budget (`casm_3800.cfg`/`casm_3900.cfg`); it does not
touch Command64 OS memory, `UserProgStart`, or any other external
application's budget.

**Noted for future expansion, per the user's request:** if the dropped
byte-cadence progress (source-load, `.INCBIN`, `.RES`/`.FILL`/`.ALIGN`) is
wanted later, roughly 70 bytes of additional MAIN growth would restore it
at the current design's size, and there remains ~6.5KB of address space
free below `$C000` if a larger future increase is ever needed for this or
another feature.

## Frozen ABI

### Routine table

| Routine | In | Out | Clobbers | Notes |
|---|---|---|---|---|
| `progressInit` | none | none | A | Zeroes all state |
| `progressBeginPass` | A = pass (1 or 2) | none | A, X, Y | Prints `p1: start` / `p2: start`; resets active counter and divider |
| `progressStatement` | none | C=0, A=1 if redraw due (A=0 if not); C=1 + A=`CASM_DIAG_PROGRESS_COUNTER_OVERFLOW` on overflow | A | Must preserve X/Y (parser/emitter-visible state) |
| `progressRenderTransient` | `CasmProgArgDepth`/`ArgFileId`/`ArgLineLo`/`ArgLineHi`/`ArgNameBuf` (caller-populated first) | none | A, X, Y | Full 5-field line; sets visible flag |
| `progressCompletePass` | none | none | A, X, Y | Clears transient, prints `p1: done NNNNN statements` / `p2: done ...`; latches Pass 1 total |
| `progressAccumulateOutputBytes` | A/X = bytes lo/hi | none | A, X | Pure accumulation only (post scope-trim) |
| `progressClearTransient` | none | none | A, X | Idempotent -- no-op if not visible |
| `progressSuspend` | none | none | A, X | Calls clear, sets suspended flag; idempotent |
| `progressFinalSummary` | none | none | A, X, Y | `done: p1 NNNNN, p2 NNNNN, NNNNN bytes` |
| `progressCheckPassTotals` | none | C=0 match; C=1 + A=`CASM_DIAG_PROGRESS_PASS_TOTAL_MISMATCH` | A | Compares live active count against latched Pass 1 total |

Private (not exported, no cross-module import either direction):
`progressPrintStr`, `progressPrintChar`, `progressPrintDec`,
`progressReturnToStart`.

### BSS map (22 bytes total, no zero page)

```
CasmProgPass1TotalLo/Hi   2   latched at p1-done
CasmProgActiveLo/Hi       2   current pass's running statement count
CasmProgDivider           1   redraw throttle, mod 64
CasmProgFlags             1   bit0=visible bit1=pass2 bit2=suspended
CasmProgByteLo/Hi         2   output-byte accumulator (final summary only)
CasmProgArgDepth          1   caller-populated before progressRenderTransient
CasmProgArgFileId         1
CasmProgArgLineLo/Hi      2
CasmProgArgNameBuf        8   caller copies truncated 8-char name in
CasmProgDecScratchLo/Hi   2   private to progressPrintDec
                         ---
                          22
```

Pass 2's own total is never stored separately -- it *is*
`CasmProgActiveLo/Hi` at the moment `progressCompletePass`/
`progressCheckPassTotals` run, matching the ABI section's "reuse ... where
safe" instruction.

### Screen protocol

- Transient line: fixed 38-column field, redrawn via `CASM_PROG_LINE_WIDTH`
  (38) `PetLeft` ($9D, already defined in `command64.inc`) bytes to return
  to column 0 -- the transient line never emits its own trailing `PetCr`,
  so it never scrolls. `progressClearTransient` overwrites with 38 spaces
  then returns again, leaving the cursor at column 0 with the row blank.
- Persistent lines end with `PetCr` (real newline/scroll), matching every
  existing CASM message's convention.
- Field layout, in print order: `p1: ` or `p2: ` prefix (built from a
  shared prefix string per pass, not two fully independent templates),
  2-digit depth, 2-digit file id, 8-char name (raw copy, no scan/no
  truncation logic inside `progress.s` itself), 5-digit line number,
  5-digit statement count. All fixed-width, zero-padded (`progressPrintDec`
  never suppresses leading zeros -- deliberately simpler and smaller than
  `printDec16`'s variable-width suppression logic, and matches the parent
  plan's own `d03`/`f07`/`l00128`/`t00412` fixed-width examples exactly).

### Diagnostics

`CASM_DIAG_PROGRESS_COUNTER_OVERFLOW = $55`,
`CASM_DIAG_PROGRESS_PASS_TOTAL_MISMATCH = $56`, contiguous after `$54`
with a compile-time `.assert`, per Finding 3.

### Import graph -- no cycle

`progress.s` imports nothing from `diagnostics.s`, `listing.s`, or `map.s`.
It owns its own `progressPrintStr`/`progressPrintChar` (duplicating
`diagnostics.s`'s trivial 3-6-instruction wrappers around
`DOS_PRINT_STR`/`DOS_PRINT_CHAR` rather than importing them) and its own
`progressPrintDec` (a fixed-width sibling of `diagnostics.s`'s private,
non-exported `printDec16`, not a shared routine -- `printDec16` cannot be
imported since it is module-private). `diagnostics.s` will import only
`progressClearTransient` (one-way edge), exactly as the parent plan
specifies. No cycle exists in either direction, proven by the fact that
this measurement's link -- which includes every real CASM object file plus
`progress.o` -- succeeded (link-time cycle detection is implicit: an actual
circular `.import`/`.export` mismatch would have failed to resolve).

### Unbounded-loop audit

Every loop in `progress.s` is statically bounded: the digit-extraction
macro terminates on `bcc` against a fixed 16-bit divisor (at most ~6553
iterations for the worst-case `10000`s digit of `$FFFF`, identical in
shape to `diagnostics.s`'s own proven `printDec16`); the name-copy loop is
a fixed 8 iterations (`cpy #8`); the cursor-return and clear loops are
fixed at `CASM_PROG_LINE_WIDTH` (38) iterations. No loop bound depends on
unvalidated input.

## Record-growth audit

No parser, token, include, frame, symbol, listing, map, relocation, or
directive record was touched or enlarged. `progress.s` reads caller-supplied
values passed by value/copy into its own `CasmProgArg*` staging bytes; it
holds no pointer into and performs no writes to any existing record.

## Disposition of the working files

`progress.s`, `driver.s`, and the linker-config test copy used for this
review live under this session's scratchpad, not the repository -- Increment
2 is a design/ABI freeze, not a source-edit increment, matching its own
stated scope ("does not add production behavior"). The frozen ABI above
(routine table, BSS map, screen protocol, diagnostic IDs, import graph) is
the actual implementation contract Increment 3 must produce
`src/external/casm/progress.s` against; Increment 3 is authorized to start
from this frozen design rather than re-deriving it, but the file itself
must still be written fresh in-tree with full comments/attribution per this
project's normal standards, not copy-pasted from this scratch draft
verbatim.

## Static Peer Review

Self-reviewed against every item in the parent plan's "Register, Flag, and
Scratch Contract" section:
- `progressStatement` preserves X/Y (only touches A internally); confirmed
  by direct read of its body -- no `tax`/`tay`/`ldx`/`ldy` touches a
  caller-live register before the `rts`.
- No routine assumes OS/KERNAL printing preserves shared zero-page scratch,
  because no routine uses zero-page scratch at all (Finding 2's resolution
  made this moot by construction).
- Decimal/filename rendering scratch (`CasmProgDecScratchLo/Hi`,
  `CasmProgArgNameBuf`) is private to `progress.s` and never aliases
  source/include/expression/VMM/diagnostics/output state.
- Push/pop balance: only `progressPrintChar` uses the stack (`pha`/`pla`
  around the `tax`/`OS_API` call), and it is balanced on every path
  including through nested calls from `progressPrintDec`'s macro
  expansions -- verified by the fact that the standalone link produced a
  working `.prg` with a clean `HEADER`/`MAIN` layout, not by assertion.

No unresolved finding from this pass.

## Completion Gate

- [x] Every ABI/storage/layout decision above is explicit.
- [x] Peer review (self, static) has no unresolved finding.
- [x] This walkthrough exists:
      `brain/walkthroughs/2026-08-24-casm-progress-increment02-design-abi-review.md`.
- [ ] Trackers agree (pending: Taskwarrior annotation, plan Progress update).
- [ ] User approves the design before Increment 3 source edits begin.
