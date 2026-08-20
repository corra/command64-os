---
feature: casm-phase12-wp72-constant-zeropage-width
completed: 2026-08-17
status: completed
---

# Walkthrough: CASM Phase 12 WP72 — Named-Constant Zero-Page Width Selection Fix

Plan: `brain/plans/2026-08-17-casm-phase12-wp72-constant-zeropage-width.md`
(approved 2026-08-17). Discovered mid-WP71 (DASH adoption); blocks
WP71's Atomic Step 5 (native-provenance regen). Branch:
`feature/casm-phase12-wp65`.

## What Shipped

A one-site fix in `src/external/casm/expr.s`'s `identifier` proc: a
resolved, non-label-derived named constant (a plain equate, e.g.
`DISPATCHVECTOR = $70`) no longer unconditionally forces absolute (3-byte)
addressing when referenced as an instruction operand. It now falls
through to the same value-based zero-page/absolute selection in
`opcodes.s` that a bare numeric literal (`STA $70`) already received —
so `STA DISPATCHVECTOR` now correctly assembles as 2-byte zero-page
(`85 70`), not 3-byte absolute (`8D 70 00`). Labels and the `*`
current-address symbol are unaffected — both remain genuinely
load-address-sensitive across Pass 1/Pass 2 and correctly keep forcing
absolute width.

Plus: a unit-level regression case (`tests/src/casm_expr`), a real
end-to-end native-CASM fixture with a hand-derived trusted reference
(`casmzpconst1`, packaged on `casm_phase12_test.d64`), and the fix for a
genuine, unrelated, pre-existing off-by-one in `casm_expr`'s own harness
driver that this work incidentally surfaced.

## Files Changed

| File | Change | Notes |
|------|--------|-------|
| `src/external/casm/expr.s` | Fix | `identifier`: clear the `SYMBOL_DERIVED`-equivalent bit in the already-existing "resolved, non-label-derived constant" branch (the same branch that already gates `RELOCATABLE` correctly) |
| `tests/src/casm_expr/casm_expr.s` | New case + bugfix | New `sConst`/`eConst` (`CONSTVAL` resolves to a constant, value `$1270`) proving `SYMBOL_DERIVED` is now correctly clear; also fixes `CASE_COUNT` (97→99: was already wrong at 97 against 98 real pre-existing entries before this WP added a 99th) |
| `cmake/GenerateCasmTestFixtures.cmake` | New fixture | `casmzpconst1.seq`: `DISPATCHVECTOR = $70` / `STA DISPATCHVECTOR` / `STA DISPATCHVECTOR+1`, mirroring DASH's real source verbatim |
| `tests/fixtures/casm/casmzpconst1.ref.hex` | New | Hand-derived trusted reference: `00 C0` / `85 70` / `85 71` (6 bytes) |
| `CMakeLists.txt` | Modify | `TEST_PRG_SIZE` for `casm_expr` bumped `$1700`→`$1800` (23-byte BSS overflow from the new case); `casmzpconst1` registered in `CASM_REF_NAMES` + excluded from the generic test.d64 loop + packaged onto `casm_phase12_test_d64` (mirroring WP70's `casmrelacc` precedent) |

## Testing Results (live, VICE 3.10, this session)

**Root-cause confirmation** (before any fix): extracted the leftover
native `dash.prg` (4835 bytes) and `dash.ref` (4766 bytes) directly from
`command64_casm_utils.d64`'s prior live-VICE write (no new hardware run
needed to reproduce). Byte diff showed `STA DISPATCHVECTOR` encoded as
`8D 70 00` natively vs `85 70` under ca65, and the same for
`DISPATCHVECTOR+1` — confirmed via `xxd`, not assumed.

**Unit-level proof, fail-before/pass-after** (`test_casm_expr`,
`casm_phase12_test_d64`):
- Pre-fix (via `git stash`), first attempt: false PASS — traced to the
  new case never executing at all, because `CASE_COUNT` was already
  wrong (97 against a true 98 pre-existing entries) before this WP even
  started; the harness had been silently skipping its true last case for
  an unknown prior span. Corrected to 99 (98 pre-existing + 1 new).
- Pre-fix, second attempt (value `$0070`, high byte zero): also a false
  PASS — traced to a second, separate, harmless, pre-existing dormant
  fallthrough in `identifier` (`bne lexerNextTail` after loading
  `VAL_HI`) that only triggers when a resolved value's high byte is
  zero, setting the never-consumed `CASM_EXPR_FLAG_FORCE_ABS` bit.
  Confirmed via `grep` that nothing reads this bit anywhere in
  production code (`parser.s`'s own comment explicitly says it derives
  `FORCE_ABS` from `SYMBOL_DERIVED`, "not from `CASM_EXPR_FLAG_FORCE_ABS`").
  Harmless and out of this WP's scope; sidestepped by using a nonzero
  high-byte test value (`$1270`) instead, documented inline.
- Pre-fix, third attempt (corrected case, `CASE_COUNT=99`, value
  `$1270`): genuine `CASM EXPR: FAIL` (screenshot + memory-read
  cross-verified) — exactly one `F` among 99 dots.
- Post-fix (`git stash pop`, rebuilt): `CASM EXPR: PASS` — same case,
  same build, only the production fix restored.

**Full regression, post-fix** (all via VICE, screenshot + memory-read
cross-verified after one harness desync episode — see Gotchas):
`test_casm_pass1` → PASS, `test_casm_reloc` → PASS, `test_casm_symbol`
→ PASS, `test_casm_opcodes` → PASS, `test_casm_expr` → PASS. Zero
unintended change.

**ca65 cross-check unchanged**: `dash_ref` rebuilt after the fix —
`3238b7863cc9b7ba7b07202c94dccb8dcbd1fd0fe4c578362f311b79757b814b`,
4766 bytes — byte-identical to WP71's own recorded reference, confirming
this is a native-CASM-only change.

**End-to-end native proof** (`casmzpconst1.s`, real `casm.prg` on
`casm_phase12_test.d64`): `CASM CASMZPCONST1.S /O:ZPC1.PRG` →
`CASM: INPUT VALIDATED`; `COMP ZPC1.PRG CASMZPCONST1.REF` →
`FILES COMPARE OK` — the exact `STA DISPATCHVECTOR` / `STA
DISPATCHVECTOR+1` shape from DASH's real source, assembled by real
native CASM, now matches the hand-derived 2-byte-zero-page-per-instruction
reference byte-for-byte.

## Lessons Learned & Gotchas

1. **A regression test that "passes" on the first try against
   deliberately-broken code is a red flag, not a relief** — investigate
   before trusting it. Two independent false-positive causes were found
   this way, neither of which was the thing under test.
2. **`casm_expr`'s harness driver had a real, silent, pre-existing
   off-by-one** (`CASE_COUNT` undercounting its own table by one),
   unrelated to this WP, that had apparently been skipping the table's
   true last entry for an unknown span of prior WPs. Fixed as part of
   making this WP's own new case actually run — flagged here rather than
   silently folded in.
3. **A second, separate, genuinely-dormant control-flow quirk** in
   `identifier` (spurious `CASM_EXPR_FLAG_FORCE_ABS` on a zero high
   byte) — confirmed harmless (inert flag, no consumer) and explicitly
   left unfixed as out of this WP's scope, per the phased-planning
   default of disclose-and-defer rather than silently expanding scope.
4. **VICE/MCP session hygiene**: a `vice_autostart` call timed out
   mid-session and left the emulator in a state where `vice_memory_read`
   at `$0400` returned stale/blank data while `vice_display_screenshot`
   showed real, different on-screen text — a genuine tool desync, not a
   VIC-bank/screen-relocation issue (confirmed via `$D018`/`$DD00`).
   Recovered via the documented procedure: soft reset, explicit
   `vice_disk_attach` (not autostart, once Command64 was resident again),
   fresh boot, re-verified screenshot and memory-read agreed before
   trusting either again. Screenshot was treated as authoritative during
   the desync window, per the testing workflow's own guidance.
5. **Shell dispatch of underscore-separated app names** needs
   `vice_keyboard_petscii` with byte 164 for each underscore —
   `vice_keyboard_type`'s ASCII mapping sends `_` as PETSCII left-arrow
   instead (already a recorded memory; reconfirmed live this session
   after an initial `BAD COMMAND OR FILE NAME`).

## Stop Conditions Checked

- Atomic Increment 1's preconditions (constants always resolved before
  an instruction operand references them; nothing else depends on
  `SYMBOL_DERIVED` being set for a constant) held — confirmed by reading
  `casm.s`'s pass driver and `expr.s`'s own binary-operator propagation
  sites (`combineFlags`/`staticFlags`), which only OR in whatever
  `SYMBOL_DERIVED` state an operand already carries and needed no changes.
- No existing CASM test changed behavior after the fix (full regression
  above) — only the two new/corrected `casm_expr` cases did, as intended.
- The end-to-end fixture shows the correct zero-page encoding after the
  fix (`COMP` byte-exact).
- `dash_ref` (ca65 cross-check) is untouched — confirmed via sha256.

## Documentation, Task, and DOX Sync (pending this walkthrough's approval)

- Taskwarrior task 44 to be marked done; task 43 (WP71)'s dependency on
  it clears, unblocking WP71's own Atomic Step 5 re-attempt.
- `brain/KNOWLEDGE.md`: new WP72 as-built section.
- `CHANGELOG.md`: entry under `[Unreleased]` → `Fixed`.
- `brain/task.md` / `wiki/tasks/casm.md`: completion entries.
- No `docs`/`wiki` `casm-utility.md` change needed unless it currently
  documents the (buggy) width-selection behavior explicitly — not found
  during this work; to confirm before close-out.

## Outcome

**Implementation and all planned verification complete. Awaiting user
review and explicit approval to close WP72.** Once approved, WP71
resumes its own Atomic Step 5 (native `dash.prg` regen), which should
now `COMP` byte-identical against the existing `dash_ref` reference.
