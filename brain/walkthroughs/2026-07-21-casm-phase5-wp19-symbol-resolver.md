---
feature: casm-phase5-wp19-symbol-resolver
created: 2026-07-21
status: complete
---

# Walkthrough: CASM Phase 5 WP19 Symbol Resolver

## Implemented

- Added a shared five-byte resolver output ABI containing flags, opaque identity,
  and optional resolved value.
- Added `exprEvaluate`, which accepts a resolver address in X/Y and invokes it
  exactly once for identifier primaries.
- Added a balanced-stack indirect-call trampoline with a linker assertion that
  its pointer cannot trigger the NMOS 6502 indirect-jump page-wrap behavior.
- Preserved unresolved identity, relocation class, signed addend, extraction,
  and force-absolute-width metadata without treating placeholder zero as valid.
- Applied checked symbol addends before extraction and retained the WP18
  magnitude-token diagnostic location.
- Kept deterministic resolver, test plan, fixtures, parser adapter, and runtime
  expression harness in WP20.
- Expanded only CASM MAIN from `$2800` to the approved `$2A00`.

## Static Verification

- NUMBER paths call the resolver zero times; IDENTIFIER paths call it once while
  the identifier remains current.
- Callback C-set or invalid flag bits report `$27` at the identifier.
- Resolved values receive checked arithmetic and then extraction.
- Unresolved values retain invalid zeroed value bytes; low extraction clears
  relocatable, while high/full preserve the resolver classification.
- Numeric arithmetic and recognizable chained continuations report `$25`.
- Missing primary/addend and repeated extraction report `$24`.
- The trampoline pushes `resume-1` high then low, matching JSR stack order; the
  callback's RTS reaches `resume`, whose RTS returns to `exprEvaluate`.

## Build Evidence

| Item | Result |
|---|---|
| Candidate | CASM `0.1.20` build 1088 |
| `expr.o` | 835 CODE, 23 BSS, no RODATA/DATA/ZEROPAGE |
| Total CODE+RODATA | 9,311 bytes |
| Total BSS | 1,143 bytes |
| MAIN envelope | 10,454 / 10,752 bytes; 298 bytes free |
| Relocation bases | `$3400` and `$3500` pass |
| R6 relocations | 1,268 |
| Test image | passes; CASM is 47 blocks |
| Candidate SHA-256 | `f332432bc4e7137e1c78a749c790e324a855cd15953feb8459b2bcff189a6d18` |
| Version dry run | `0.1.21` build 1089; no-change rebuild stable |

`git diff --check` passes. Existing WP18 and Phase 4 fixtures remain present;
WP19 intentionally has no executable resolver fixture before WP20.

## Manual Confirmation

No new runtime path reaches `exprEvaluate` in WP19, so there is no meaningful
manual emulator action for this package. WP20 will add the deterministic
resolver and expression result harness needed to exercise the matrix. Manual
confirmation for WP19 is review of the implementation, contracts, and evidence
above.

If this walkthrough is acceptable, approve WP19 completion. The verified final
step will apply stage `20` -> `21`, rebuild to 1089, verify no-change stability,
complete Taskwarrior, and leave WP20 pending its separate detailed plan.

The user approved completion on 2026-07-21. The final `0.1.21` build 1089 and
no-change rebuild passed; WP19 is complete.
