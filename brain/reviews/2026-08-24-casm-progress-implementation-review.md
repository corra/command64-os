---
feature: casm-progress-increment09-implementation-review
plan: brain/plans/2026-08-24-casm-progress-increment09-implementation-review.md
date: 2026-08-31
candidate: fb2fe48 (casm.prg sha256 af1bacda..., BUILD_CASM 1378, CASM V0.4.0.1378)
status: findings recorded; PR-1/PR-2/PR-4 fixed inline, PR-3/PR-5 deferred/noted
---

# Implementation Review: CASM Progress Indication (Increment 9)

## Method

Line-by-line read of the entire progress-feature production diff against the
merge-base with `main` (`4e3f921`): `progress.s` (710 lines, new), `casm.s`
(+361: orchestration, four count trampolines, `crpProgressHook`,
`crpSnapshotName`/`crpSnapshotNameFromPtr`, final-summary/write-line
sequencing), `emit.s` (+90: `progressBeginDirective`/`progressDirectiveBytes`
hooks in `emitFillLoop`/`emitIncbin`, `progressAccumulateOutputBytes` at
`emitFlush`), `diagnostics.s` (+74: `progressClearTransient` at
`diagPrintFatal` entry, `$55`/`$56` message table + asserts), `source.s`
(+29: `progressSourceLoadBytes` committed-block trampoline), `reloc.s` (+7:
`progressAccumulateOutputBytes` at the R6 table + footer writes),
`common.inc` (+14: `$55`/`$56` + contiguity asserts). Cross-checked against
the Increment 2 frozen ABI
(`brain/reviews/2026-08-24-casm-progress-design-abi-review.md`) and the
Increments 3-8 walkthroughs.

## What is correct (audited, no finding)

- **Statement counting.** `casmRunPass`'s dispatch routes IDENTIFIER /
  EQUALS / MNEMONIC / DIRECTIVE through the four `crpCount*` trampolines
  (each `jsr crpProgressHook` first); NEWLINE and EOF do not count. Matches
  Increment 4 evidence exactly (`casmpgblank` = 6, `.ORG`/directives
  counted, `casmpginc` = 12 with each `.INCLUDE` occurrence + every
  re-traversed statement).
- **Redraw cadence.** `progressStatement`'s `inc CasmProgDivider / and #$3F`
  fires "due" at exact counts 64/128/192; `progressBeginPass` resets it.
- **Cross-pass agreement.** `progressCheckPassTotals` runs *before*
  `progressCompletePass` at Pass 2 end (casm.s:409-411) and after both
  `includeReplayFinalCheck` and `emitCheckPassAgreement`, so a count
  disagreement is fatal before "P2: DONE" prints. Pass 1 total is latched
  into `CasmProgPass1TotalLo/Hi` at `progressCompletePass`; Pass 2's total
  is `CasmProgActiveLo/Hi` live, never reset between Pass 2 end and
  `progressFinalSummary`.
- **Screen width.** `CASM_PROG_LINE_WIDTH = 34`; every renderer prints
  exactly 34 columns (`progressRenderTransient` field budget sums to 34;
  `progressSourceLoadBytes` 21 + 13 pad; `progressDirectiveBytes` 16 + 18
  pad), so `progressReturnToStart` (34 `PetLeft`) always lands on column 0
  and `progressClearTransient`'s 34-space fill erases exactly what was
  drawn. Transient lines never emit `PetCr`, so they never scroll.
- **First-render guard.** `progressRenderTransient` / `progressSourceLoadBytes`
  / `progressDirectiveBytes` rewind only when `VISIBLE` is set, so the first
  render after a `PetCr`-terminated persistent line does not walk left off
  the row (the Increment 5 "P1: START" -> "P1: ST" bug).
- **Byte accounting.** `progressAccumulateOutputBytes` is called at
  `emitFlush` (emit.s:1114), each R6 table chunk (reloc.s:228), and the R6
  footer (reloc.s:271); all three sites `clc` after the call to absorb a
  possible 16-bit carry-out. Increment 4 verified the `DONE:` totals exact
  at 64/65/66/129/7/258/10/54/82/9, including R6 table + footer
  (`casmpgr6` = 54).
- **Import graph.** `progress.s` imports nothing from `diagnostics.s` /
  `listing.s` / `map.s`; `diagnostics.s` imports only
  `progressClearTransient`. One-way edge, as frozen. The full build links.
- **Stack / decimal.** Only `progressPrintChar` touches the stack
  (`pha`/`pla`, balanced). No `sed`; every `adc`/`sbc` is binary with an
  explicit `sec`/`clc` first.
- **`diagPrintFatal` stash.** `pha; jsr progressClearTransient; pla` saves
  the diagnostic id in A; the routine needs neither X nor Y preserved at
  entry (the range dispatch re-derives everything from A), and its callers
  are terminal.
- **`crpSnapshotName` failure handling.** A failed `includeCatalogRead`
  renders a blank name, never masks a real diagnostic; not fatal.
- **`progressStatement` overflow guard.** Errors at `CasmProgActive ==
  $FFFF` before wrapping; unreachable in practice (65535-byte source cap /
  >=2-byte statements) but a correct defensive check, propagated fatally by
  `crpProgressHook`.

## Findings

### PR-1 (MEDIUM) - private-helper and ABI clobber lists understate X/Y

`progress.s:202` (`progressReturnToStart`) and `progress.s:601`
(`progressClearTransient`) both document `Clobbers: A, Y`. Both actually
clobber **A, X, Y**: `progressPrintChar` does `tax` (and its `OS_API` call
does not restore X), and `progressReturnToStart` / `progressClearTransient`'s
space-fill loop call it repeatedly. The Increment 2 frozen ABI table lists
`progressClearTransient` as `Clobbers: A, X` - misses Y. `diagnostics.s:156`
repeats the wrong "`Clobbers: A, Y`".

**Not a live bug:** `diagPrintFatal` saves only A across the call and needs
neither X nor Y at entry; every other caller of `progressClearTransient`
(`progressCompletePass`, `progressSuspend`, `progressFinalSummary`) is
internal to `progress.s` and correctly declares `A, X, Y`. But a wrong
clobber list is precisely the hazard class this project has been bitten by
(the DIV10-clobbers-X defect, WP6). **Disposition: FIX inline** - correct
all three doc sites to `A, X, Y`.

### PR-2 (MEDIUM) - `CASM_PROG_FLAG_SUSPENDED` is write-only

`progressSuspend` (progress.s:627) sets `CASM_PROG_FLAG_SUSPENDED`; nothing
anywhere reads it (`grep -rn SUSPENDED src/external/casm/` = definition +
the one `ora` in `progressSuspend`). So `progressSuspend` is functionally
identical to `progressClearTransient` plus a dead flag write. The two
`progressSuspend` calls in `casm.s` (before `/L` at :478 and before `/M`
at :496) are commented as "defensive completeness against a future
increment adding rendering to any of the intervening steps" - but that
defense is inoperative, because no renderer checks the flag.

**Not a live bug today:** both suspend calls fire after Pass 2's
`casmRunPass` and `progressCompletePass`, and the only progress call after
them (`progressFinalSummary`) does not render. **Disposition: FIX inline** -
gate `progressRenderTransient`, `progressSourceLoadBytes`, and
`progressDirectiveBytes` on `!SUSPENDED` (early return). Safe in the current
flow (no render occurs after a suspend); `progressInit` already zeroes the
flag at each invocation, so nothing gets stuck suspended.

### PR-3 (LOW) - `DONE:` byte count wraps for output > 65535 bytes

`CasmProgByteLo/Hi` (and thus `progressPrintDec`'s 5-digit field) is 16-bit.
A valid but near-degenerate source (`.ORG $0000` then `.FILL 65535, 0`, or
a huge `.INCBIN`) produces an output PRG > 65535 bytes; the accumulator
wraps and `DONE: ... nnnnn BYTES` shows `total mod 65536`. The written
file is still correct (Increment 4 COMP-verified the file, not the number).
The Increment 2 ABI assumed byte counts fit 16 bits. **Disposition: DEFER**
- note it as a known display limitation; not worth a 24-bit counter for a
whole-address-space fill.

### PR-4 (LOW) - undocumented `CasmPtr0` clobber in `crpProgressHook`

`casm.s:594-597` explains why the A/X/Y register clobber from
`progressStatement` / `crpSnapshotName` is harmless (handlers read fresh
from `CasmParserStmt`), but not that `crpSnapshotName` /
`crpSnapshotNameFromPtr` also clobber **`CasmPtr0Lo/Hi`** in memory (only
on the identity-changed path: first statement of a pass, frame push/pop).
Verified safe: `emit.s` and `opcodes.s` have zero `CasmPtr0` references, so
`crpInsn` / `crpDir` / `emitInstruction` / `opcodesFindOpcode` /
`emitDirective` never read it as a carried input; `crpLabel` / `crpConstant`
/ `crpInclude` all set `CasmPtr0` fresh before use; the parser declares
`CasmPtr0` clobbered and leaves nothing durable there. **Disposition: FIX
inline** - one-line comment extension so a future `CasmPtr0` use in
`crpInsn`/`crpDir` is not introduced blind.

### PR-5 (INFO) - uppercase message literals

`progress.s`'s message table uses uppercase PETSCII string literals
(`"P1: START"` etc.), consistent with every other CASM diagnostic and
verified legible on the mixed-case charset in Increment 4. If CASM ever
adopts the lowercase-only convention
([[reference-c64-lowercase-petscii-convention]]), `progress.s` must follow.
**No action.**

## Remediation

PR-1, PR-2, PR-4 applied as one small in-tree change (doc corrections plus
the three `!SUSPENDED` render guards). PR-3 and PR-5 recorded, not actioned.
Re-verification: full build clean, exact no-change rebuild, and a live-VICE
smoke (one `casmpg*` fixture assembles + `COMP OK`) because the SUSPENDED
guards touch the render entry points. See Progress in the plan.
