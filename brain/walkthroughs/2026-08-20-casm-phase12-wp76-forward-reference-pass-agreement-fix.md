# CASM Phase 12 WP76 Forward-Reference Pass-Agreement Fix — Completion Gate

Plan: `brain/plans/2026-08-20-casm-phase12-wp76-forward-reference-pass-agreement-fix.md`

## Result

WP76 is implemented and verified. `casmarithfwd.s` (Taskwarrior task 44,
UUID `25420ff2-5dd5-46d0-a790-4d10dda0b947`) now produces
`CASM: INPUT VALIDATED` and matches its trusted reference via `COMP`,
instead of `CASM: PASS 1/2 MISMATCH`. A consolidated fresh re-run of all
11 WP75 Increment 5 production fixtures shows zero regressions.

## Root Cause

`FWDCONST` in `casmarithfwd.s` (`.ORG $0010` / `LDA FWDCONST*2` /
`FWDCONST = 5`) is referenced before its own defining statement. Pass 1
evaluates the reference while `FWDCONST` is still undefined —
`expr.s`'s `identifier:` proc takes the "label-shaped" path, forcing
absolute (3-byte) addressing. By the time Pass 1 reaches `FWDCONST`'s own
definition, it becomes a fully resolved, non-label-derived constant. Pass
2 replays the source against the now-fully-populated symbol table, so at
the same reference `FWDCONST` is already resolved — WP72's zero-page
exemption fires and the value-based selector picks zero-page (2 bytes)
for `FWDCONST*2 = 10 = $0A`. The two passes disagree by 1 byte, tripping
`emitCheckPassAgreement`.

**Confirmed live**, not just by static analysis: a direct memory read at
the mismatch point (`casm_phase12_test.d64`, pre-fix `casm.prg`) showed
`CasmPass1FinalPc = $0013` (absolute) against `CasmPc = $0012`
(zero-page) — exactly the predicted 1-byte gap.

## Fix

Extended the symbol record with `CASM_SYMBOL_REC_DEFINED_AT_OFFSET_LO/HI`
(`common.inc`, offsets 44-45, in previously-reserved padding), stamped
from the already-global `CasmTokenStartOffsetLo/Hi` (lexer.s, stamped on
every token) at the constant's own defining statement (`ppsLabel`,
`parser.s` → `crpConstant`, `casm.s` → `symbolsInsert`, `symbols.s`).
The resolver output view (`CASM_RESOLVE_*`) grew two matching fields,
populated by `symbolsLookup` from the record it already has loaded — no
extra VMM read.

`expr.s`'s WP72 exemption branch now compares the *current reference's*
own source position against the matched constant's `DEFINED_AT_OFFSET`:
strictly-before falls through to the existing unconditional label-shaped
path (same as an unresolved reference already takes); at-or-after
proceeds to WP72's original value-based zero-page/absolute selection.
Because both passes replay the identical source top-to-bottom, this
comparison yields the same answer in both passes for the same statement
— the actual property `emitCheckPassAgreement` needs.

## A Second, Unrelated Defect Found and Disclosed (Not Fixed Here)

While probing whether identifier-RHS (deferred) constants share this
defect regardless of reference order (Increment 1), a constant chained
to another constant (`DEFCONST = BASECONST`) was found to break parsing
of the *following* line with `CASM: EXPECTED NEWLINE` — reproducible with
no arithmetic operator involved, so provably a different defect. Checked
against existing coverage: WP65's own fixtures chain a constant to a
*label* (`casmconst1.seq`) and test constant-to-constant chains only for
the *circular* case (`casmconst2`/`casmconst3`, expecting
`CASM_DIAG_EXPR_CIRCULAR`) — a non-circular constant-to-constant chain
appears to have never been exercised as an expected-success case before.

Logged as Taskwarrior task 45 (UUID `b1369c8c-8fc6-4038-825c-1103a106257c`)
and explicitly deferred, per this project's disclose-and-defer Stop
Condition — not investigated or fixed as part of this WP. A label-based
probe for Increment 1's own question was skipped as uninformative once
static analysis showed a label-derived constant can never reach WP72's
exemption at all (`expr.s:352-353` forces absolute unconditionally,
regardless of resolution timing).

## Regression Evidence

Live-VICE, dedicated CASM-only test disks (`wp76_fix_test.d64`,
`wp76_consolidated.d64`), CASM `0.2.8` build `1323`:

| Fixture | Result |
| --- | --- |
| `casmarithfwd.s` | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` (was `PASS 1/2 MISMATCH`) |
| `casmzpconst1.s` (WP72's own) | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |
| `casmfwdstale1.s` (WP73's own) | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |
| `casmrelacc.s` | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |
| `casmarelocb.s` | `CASM: EXPRESSION RELOCATION UNSUPPORTED`, exact line/col/offset |
| `casmareloc1.s` | `CASM: EXPRESSION RELOCATION UNSUPPORTED`, exact line/col/offset |
| `casmareloc2.s` | `CASM: EXPRESSION RELOCATION UNSUPPORTED`, exact line/col/offset |
| `casmarith2.s` | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |
| `casmarith3.s` | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |
| `casmchar1.s` | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |
| `casmstring1.s` | `CASM: INPUT VALIDATED`, `FILES COMPARE OK` |

All 11 match their documented WP68/WP70/WP72/WP73/WP74 outcomes exactly.

## Build Evidence

- `cmake --build build --target casm`: clean, build 1323, no warnings.
- Found and fixed a real build break the plan hadn't anticipated:
  `tests/src/casm_expr/casm_expr.s` (a synthetic unit-test harness for
  `expr.s` with no real `lexer.s` linked, and its own `resolveConst`
  fixture — the exact WP72-exemption test case) didn't provide
  `CasmTokenStartOffsetLo/Hi` or populate the new resolver-view fields.
  Added both as zero-defaulted stubs (`0 >= 0`, at-or-after, safe),
  preserving that fixture's original expected outcome unchanged.
- Full project build (`cmake --build build`, no target): clean, zero
  errors/warnings.
- Full no-change rebuild: every `.d64` in `build/` byte-stable
  (`sha256sum -c` against a pre-rebuild snapshot, zero `FAILED` lines).

## Manual Confirmation

1. Boot a CASM-capable disk into Command64, run
   `CASM CASMARITHFWD.S`; expect `CASM: INPUT VALIDATED`.
2. `COMP CASMARITHFWD.PRG CASMARITHFWD.REF`; expect `FILES COMPARE OK`.
3. Re-run `CASMZPCONST1.S` and `CASMFWDSTALE1.S`; expect both to still
   pass exactly as before.

## Completion Gate

Pending user approval. Once approved: `brain/KNOWLEDGE.md` gains a WP76
entry, `CHANGELOG.md` records the fix, Taskwarrior task 44 closes, and
WP75 resumes from Increment 6.
