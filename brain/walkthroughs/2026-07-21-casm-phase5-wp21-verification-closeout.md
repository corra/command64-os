---
feature: casm-phase5-wp21-verification-closeout
created: 2026-07-21
status: complete
---

# Walkthrough: CASM Phase 5 WP21 Verification and Closeout

## Coverage Reconciliation

- Added `ABSVAL+0`, proving positive-zero parsing and unchanged value.
- Added `ABSVAL-$0000`, proving negative sign metadata survives zero magnitude.
- Added `<<$1234`, proving `$24` is stamped at the second extraction token.
- Assigned each scripted token a distinct column and verify the expected final
  or offending column for all 30 cases.

## Independent Audit

The Phase 5 production and harness paths were independently reviewed for:

- ADC/SBC carry and borrow setup;
- inherited D-clear preconditions;
- synthetic resolver callback stack order;
- NMOS indirect-JMP pointer-page assertion;
- returned resolver flag validation;
- unresolved value containment and force-absolute metadata;
- checked arithmetic before extraction;
- parser and directive delimiter ownership;
- exact diagnostic source token; and
- partial-output cleanup and absence of fixture names in production.

No production defect was found. Low extraction clearing relocatable matches the
frozen Phase 5/R6 contract. CASM's inherited application-entry D-clear assumption
remains documented later hardening debt and is not broadened by Phase 5.

## Artifact Evidence

| Item | Result |
|---|---|
| CASM | `0.1.22` build 1093 |
| CASM CODE+RODATA / BSS | 9,366 / 1,143 bytes |
| CASM MAIN | 10,509 / 10,752; 243 bytes free |
| CASM relocations | 1,271 |
| Harness | build 1005, 30 cases |
| Harness CODE+RODATA / BSS | 2,310 / 72 bytes |
| Harness MAIN | 2,382 / 4,096; 1,714 bytes free |
| Harness relocations | 296 |
| Narrow no-change builds | CASM and harness stable |
| Test image | passes; harness, five references, and SEQs present |
| Release image | passes; shipping apps only, no test artifacts |
| `git diff --check` | passes |
| `0.1.23` dry run | build 1094; no-change and both images pass |
| Dry-run PRG SHA-256 | `18d2f6cce7ffbcc7de8aa71db3da9e3b6d9ee3bb1cd07e69b072dd0d0884e703` |
| Approval candidate | restored to `0.1.22` build 1093 |

## Consolidated Runtime Procedure

Use local VICE or hardware with `build/test.d64`:

1. Run `TEST_CASM_EXPR`; confirm 30 dots, no `F`, and `CASM EXPR: PASS`.
2. Assemble each source and compare it to its reference:
   `CASMEMIT1`, `CASMHELLO`, `CASMMODES`, `CASMNUM2`, and `CASMEXPRN`.
3. Confirm all five `COMP <name> <name>.REF` operations report equality.
4. Run `CASM CASMEXPRU`; confirm `RESOLVER FAILED` at `ABSVAL` and verify no
   partial `CASMEXPRU` output remains.

These checks passed and were reported by the user before completion approval.

## Runtime Results

User-confirmed on 2026-07-21:

- all 30 `TEST_CASM_EXPR` cases passed with no failures;
- `CASMEMIT1`, `CASMHELLO`, `CASMMODES`, `CASMNUM2`, and `CASMEXPRN` assembled
  and matched their trusted references; and
- `CASMEXPRU` reported resolver failure at `ABSVAL` and left no partial output.

## Completion Approval

The user explicitly approved WP21 and Phase 5 completion on 2026-07-21. The
verified `0.1.23` increment advanced exactly once to build 1094, remained stable
on a no-change rebuild, and passed both disk-image targets. WP21 was closed
before the Phase 5 parent, and Phase 6A was not activated.
