---
feature: casm-phase5-wp20-parser-adapter
created: 2026-07-21
status: complete
---

# Walkthrough: CASM Phase 5 WP20 Parser Adapter

## Implemented

- Replaced NUMBER-only parser/emitter conversion with `exprEvaluate` adaptation.
- Preserved NEWLINE, EOF, COMMA, RPAREN, and register token ownership.
- Kept production symbols disabled through a resolver that returns `$27` until
  Phase 6B, preventing unresolved zero from reaching opcode selection/emission.
- Preserved expression-start location for post-evaluation `.BYTE` width errors.
- Added `test_casm_expr`, which links production `expr.s` and executes 27
  deterministic numeric, resolved, unresolved, extraction, arithmetic, malformed,
  unsupported, and resolver-failure cases without instruction emission.
- Added `casmexprn`, trusted `casmexprn.ref`, and `casmexpru` production fixtures.

## Build Evidence

| Item | Result |
|---|---|
| CASM candidate | `0.1.21` build 1092 |
| CASM CODE+RODATA / BSS | 9,366 / 1,143 bytes |
| CASM MAIN | 10,509 / 10,752; 243 bytes free |
| CASM relocations | 1,271 |
| CASM SHA-256 | `2efb2dc39acccb622b11b9a1ada683da59faf3fad628266747d3db460ff78614` |
| Test candidate | `test_casm_expr` build 1003 |
| Test CODE+RODATA / BSS | 2,184 / 70 bytes |
| Test MAIN | 2,254 / 4,096; 1,842 bytes free |
| Test relocations | 288 |
| Test SHA-256 | `2f3c234cd6506589c6ad8b1293aa60dc46e612dc262bf04778aea7a7280f4fc5` |
| Test image | passes; harness, two SEQs, and reference present |

Both relocation bases pass for CASM and the harness. `parseNumericValue` has no
remaining source occurrence. `git diff --check` passes.

## Runtime Procedure

Use the supported local VICE installation or hardware with `build/test.d64`.

1. Load and run `TEST_CASM_EXPR` using the normal shell commands.
2. Confirm it prints 27 dots, no `F`, then `CASM EXPR: PASS`.
3. Run `CASM CASMEXPRN`; confirm assembly succeeds.
4. Run `COMP CASMEXPRN CASMEXPRN.REF`; confirm byte equality.
5. Run `CASM CASMEXPRU`; confirm `RESOLVER FAILED` at `ABSVAL` and no partial
   `CASMEXPRU` output PRG remains in the directory.
6. Optionally rerun the established `CASMNUM2`, `CASMMODES`, `CASMEMIT1`, and
   `CASMHELLO` comparisons to confirm Phase 4/WP18 compatibility.

Report the output of steps 2-5. Runtime confirmation is required before the
`0.1.22` dry run and WP20 completion review.

## Runtime Results

User-confirmed on 2026-07-21:

- `TEST_CASM_EXPR`: all 27 cases passed with no failures;
- `CASM CASMEXPRN`: assembled successfully;
- `COMP CASMEXPRN CASMEXPRN.REF`: byte equality confirmed; and
- `CASM CASMEXPRU`: resolver failure and partial-output cleanup confirmed.

## Completion Candidate

The stage `21` -> `22` dry run produced build 1093, passed both relocation links,
and remained stable on a no-change rebuild. Its SHA-256 was
`3bc2ff92b0b1a605759b3f419b301fc2c30b5747882d3b578676bca4e47ba92b`.
The tree is restored to `0.1.21` build 1092 pending explicit completion approval.

If this walkthrough is acceptable, approve WP20 completion. The final step will
apply the verified `0.1.22` increment, rebuild CASM/test image, complete the task,
and leave WP21 pending its separate detailed plan.

The user approved completion on 2026-07-21. Final CASM `0.1.22` build 1093 and
the test image passed; WP20 is complete.
