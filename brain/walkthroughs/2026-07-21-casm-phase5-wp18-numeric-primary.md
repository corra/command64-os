---
feature: casm-phase5-wp18-numeric-primary
created: 2026-07-21
status: complete
---

# Walkthrough: CASM Phase 5 WP18 Numeric and Checked Arithmetic Core

Plan: `brain/plans/2026-07-21-casm-phase5-wp18-numeric-primary.md`

Test plan: `brain/plans/2026-07-21-casm-phase5-wp18-test-plan.md`

Taskwarrior: `8f9467b6-e37d-4701-a4a6-6f90bd8fbf5b`

## Implementation

- Numeric conversion and seven private scratch bytes moved from `parser.s` to
  `expr.s`.
- `exprParseNumeric` returns X/Y and does not import parser state.
- Existing exported `parseNumericValue` is now a thin statement-record wrapper;
  all Phase 4 parser/emitter callers remain unchanged.
- Added `exprParseAddend`, `exprCheckedAdd`, `exprCheckedSub`, and
  `exprApplyAddend`.
- A parsed addend magnitude remains the current token for accurate overflow
  location stamping.
- Diagnostic printing now covers reserved Phase 5 codes `$24-$27`.
- Arithmetic explicitly establishes carry and requires inherited D-clear state.

## Fixtures

- `casmnum2`: decimal carry boundaries and equivalent hex/binary words.
- `casmnumerrd`: decimal 65536 rejection.
- `casmnumerrh`: hexadecimal `$10000` rejection.
- `casmnumerrb`: 17-bit binary rejection.
- `casmnum2.ref`: hand-derived 24-byte trusted PRG, SHA-256
  `0849f714d73fa213b5ee72c623094ef866f759b259c4d2f45f96c1f14971259b`.

All fixtures and the reference are present on `test.d64`.

## Artifact Evidence

| Measurement | WP17 | WP18 candidate |
|---|---:|---:|
| CODE+RODATA | 8,741 | 8,997 |
| BSS | 1,136 | 1,136 |
| MAIN headroom | 363 | 107 |
| Relocations | 1,182 | 1,207 |
| R6 size | 11,113 | 11,419 |
| Build | 1082 | 1084 |

Candidate SHA-256:
`c9c861194e2f529dc1ce104895d3bf57f5a381a3fb77cfbcb7241e3c2bf190a2`.

`expr.o`: 521 CODE, 16 BSS, no RODATA/DATA/ZEROPAGE.

`parser.o`: 500 CODE, 6 BSS; numeric scratch is absent.

## Automated Verification

- Configure and both CASM relocation links: pass.
- Immediate no-change build at 1084: pass.
- `casm_test_fixtures` and `test_image_d64`: pass.
- Disk contains all four WP18 SEQ fixtures and `casmnum2.ref`.
- Trusted reference conversion validates 24 bytes and its SHA-256.
- Object segments, exports, and imports inspected.
- Independent 6502 audit found no carry, borrow, token-consumption, table, or
  reference-byte defect; D-clear preconditions were made explicit.
- `git diff --check`: pass.
- Completion dry run `0.1.20` build 1085 and no-change rebuild: pass; restored
  to implemented stage 19/build 1084 pending approval.

## Manual Runtime Matrix

Using the supported local emulator or hardware and `build/test.d64`:

1. Assemble `casmnum2` to `casmnum2.prg`.
2. Run `COMP casmnum2.prg casmnum2.ref`; confirm byte-identical.
3. Assemble `casmnumerrd`, `casmnumerrh`, and `casmnumerrb`; each must report
   `OPERAND OUT OF RANGE` at its number.
4. Assemble and compare one existing Phase 4 trusted fixture, preferably
   `casmemit1`, to confirm compatibility.
5. Confirm the shell remains usable after all success/error cases.

Do not use the broken C64-testing MCP or a web emulator.

## Completion Gate

Record the manual results above. After explicit completion approval, apply the
verified stage `19` -> `20` increment, build to 1085, verify no-change stability,
close WP18, and leave WP19 pending separate approval.

The user approved completion on 2026-07-21. The final `0.1.20` build 1085,
no-change rebuild, and test image pass. WP18 is complete.
