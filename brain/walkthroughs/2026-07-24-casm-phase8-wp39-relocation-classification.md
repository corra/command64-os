---
feature: casm-phase8-wp39-relocation-classification
created: 2026-07-24
status: complete
---

# Walkthrough: CASM Phase 8 WP39 Relocation Classification

Plan: `brain/plans/2026-07-24-casm-phase8-wp39-relocation-classification.md`

Taskwarrior: `4a26fc20-3fcf-4d77-b41b-a46704af1491` (WP39); part of the CASM
Phase 8 milestone `c50df549-a7ae-4859-bd16-45a843425ce6`.

## Outcome

WP39 implemented Phase 0C.14 Contract item 3: `CASM_EXPR_FLAG_RELOCATABLE`
is now a real, correctly-produced classification (previously wired end to
end in the ABI but never set by any producer), and a new
`CASM_PARSER_STMT_RELOCATABLE` bit is derived from it at the same
`parser.s` site `CASM_PARSER_STMT_FORCE_ABS` already is. No relocation
table exists yet and no emission site (`emitInstruction`, `emitByteList`,
`emitWordList`) was touched -- WP40 consumes the classification; this WP
only makes it correct.

A real ordering hazard, invisible from the Phase 0C.14 freeze alone, was
found and closed during planning: `parserParseStatement` evaluates an
instruction's operand expression *inline*, before `casmRunPass` ever
dispatches to `emitInstruction` (where WP38's mode-commit call lives). A
no-`.ORG` source whose very first statement is a bare instruction with a
symbol operand (`JMP TARGET`, no leading label) would otherwise classify
that symbol before relocatable mode was locked in. Resolved by moving the
commit call into `parserParseExpressionValue` itself, skipped specifically
for `.ORG`'s own operand.

Implementation matched the plan closely, with no material deviations.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase8-wp39` |
| Branch point | `feature/casm-phase8-wp38` at `3f180df` |
| Baseline version | `0.1.40` build 1145 |
| Plan approval | Approved as drafted, including both confirmed design decisions (parser.s calling emit.s's emitMarkStarted; exprEvaluate gaining a new input parameter rather than expr.s importing emit.s state) |

## Implementation

- `common.inc`: new `CASM_PARSER_STMT_RELOCATABLE = %00000010`
  (`CasmParserStmt.Flags` bit 1) and its single-bit assert.
- `emit.s`: new exported `CasmRelocatableMode` BSS byte -- records *which*
  mode `CasmOutputStarted` committed to (0 = explicit `.ORG`/static, 1 =
  implicit default/relocatable), since `CasmOutputStarted` alone cannot
  answer that for a later statement. Reset in `emitInit`; set 0 in
  `emitOrg`'s `eoSet`; set 1 in `emitMarkStarted`'s `emsDefault`.
- `expr.s`: `exprEvaluate`'s input contract grows to include `A` =
  relocatable-mode flag. Stashed into a new private
  `CasmExprRelocatableModeIn` before `exprInit` clobbers `A`. At the
  resolver-merge point, `CASM_EXPR_FLAG_RELOCATABLE` is OR'd in
  unconditionally alongside `CASM_EXPR_FLAG_SYMBOL_DERIVED` (not gated on
  `RESOLVED`), mirroring `FORCE_ABS`'s own precedent for Pass 1/Pass 2
  agreement on an unresolved forward reference. `expr.s` still imports
  nothing from `emit.s` -- the caller supplies the flag as an ABI input,
  keeping the module boundary and `test_casm_expr`'s isolation from
  `emit.s` intact.
- `parser.s`: `parserParseExpressionValue` now, before calling
  `exprEvaluate`: (1) commits the relocatable/static mode decision via
  `emitMarkStarted`, skipped when the current statement is `.ORG`
  (`CasmParserStmt.Type`/`.Subtype` check, both already populated by
  `ppsMnemonic`); (2) loads `A` from `CasmRelocatableMode` for the
  `exprEvaluate` call. After the existing `FORCE_ABS` derivation, derives
  `CASM_PARSER_STMT_RELOCATABLE` from `CASM_EXPR_FLAG_RELOCATABLE`,
  OR'd into (not overwriting) the `Flags` byte already stored.
- `tests/src/casm_expr/casm_expr.s`: `CASE` table grew a 9th per-case field
  (`CASE_RELOC_MODE`), threaded through to the `exprEvaluate` call as `A`.
  All 30 pre-existing cases pass `relocMode = 0`, preserving their exact
  expected results (confirmed safe by re-reading the exact instruction
  sequence: the new OR is either additive against an already-resolver-set
  bit, for `RELVAL`/`UNRES`, or a no-op against a clear one, for everything
  else). Four new cases (`relocMode = 1`) added: `ABSVAL` (whose
  `fixtureResolver` entry never sets `RELOCATABLE` itself) with and without
  addend, proving the new input-driven path; a new `<ABSVAL` script
  (`sAbsLo`) isolating extraction-clearing from the new path specifically,
  distinct from the pre-existing `sRelLo` (which would confound it with the
  resolver's own already-set bit); and an unresolved case (`UNABS`),
  proving `RELOCATABLE` is set even when unresolved, matching
  `FORCE_ABS`'s precedent.
- `cmake/GenerateCasmTestFixtures.cmake` / `CMakeLists.txt` /
  `tests/fixtures/casm/casmordhaz1.ref.hex`: new end-to-end fixture
  `casmordhaz1` (no `.ORG`, `JMP TARGET` as the literal first statement,
  no leading label) -- the one shape WP38's four commit sites alone could
  not reach. Deliberately byte-identical to `casmnoorg1`'s output (same
  addresses, same opcode): the point is proving the first-statement shape
  assembles correctly, not a different result.

## Static Verification

- `casm` build 1145 (baseline) -> 1146 (implementation candidate) -> 1147
  (version-only completion increment), no-change rebuild stable at each
  step.
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` all build
  clean.
- MAIN measured via `ld65 -m`: CODE `$23C5` (9157) + RODATA `$925` (2341) +
  BSS `$7D2` (2002) = 13500 of 13568 bytes -- **68 bytes headroom** (down
  from 128; this WP cost 60 bytes), no size bump needed.
- `test_casm_pass1`, `test_casm_passcheck`, `test_casm_symbols`,
  `test_casm_vmm`, and `test_casm_expr` all link and build clean.
- Hand-derived `casmordhaz1.ref` cross-checked against
  `hex_manifest_to_bin.py`'s own reported byte count and SHA-256 before any
  runtime test: 6 bytes, `sha256=4ad897d7...` -- confirmed identical to
  `casmnoorg1.ref`'s hash, matching the deliberate byte-identity design.

## Runtime Verification

The user ran the full verification matrix and confirmed: "All tests pass."

| Check | Result |
| --- | --- |
| `TEST_CASM_EXPR` (34 cases: 30 original + 4 new relocatable-mode cases) | pass |
| `CASM CASMORDHAZ1` | pass |
| `COMP CASMORDHAZ1.PRG CASMORDHAZ1.REF` | pass |
| `COMP CASMORDHAZ1.PRG CASMNOORG1.REF` | pass |
| `CASM CASMORG1` / `COMP CASMORG1.PRG CASMORG1.REF` (regression) | pass |
| `CASM CASMORGEXPL1` / `COMP CASMORGEXPL1.PRG CASMORGEXPL1.REF` (regression) | pass |
| `CASM CASMNOORG1` / `COMP CASMNOORG1.PRG CASMNOORG1.REF` (regression) | pass |
| `CASM CASMORGLATE1` -> `CASM: DUPLICATE ORG` (regression) | pass |
| `CASM CASMORG2` -> `CASM: DUPLICATE ORG` (regression) | pass |
| `CASM CASMORG1 /S` -> `CASM: ORG REQUIRED` (regression) | pass |
| `CASM CASMEMIT1` / `COMP CASMEMIT1.PRG CASMEMIT1.REF` (regression) | pass |
| `CASM CASMHELLO` / `RUN` (regression) | pass |
| `TEST_CASM_PASS1` | pass |
| `TEST_CASM_PASSCHECK` | pass |

## Documentation and DOX Closeout

- `brain/KNOWLEDGE.md`: Phase 0C.16 as-built section added, amending Phase
  0C.14/0C.15 with the exact implemented mechanism.
- `wiki/tasks/casm.md`: WP39 checked complete.
- `brain/task.md`: WP39 entry added and closed.
- `CHANGELOG.md`: Unreleased entry added.
- Taskwarrior: WP39 (`4a26fc20-3fcf-4d77-b41b-a46704af1491`) completed;
  WP40 unblocked.

## Completion

**CASM Phase 8 WP39 is complete**, per the completion gate in
`brain/plans/2026-07-24-casm-phase8-wp39-relocation-classification.md`:
every fixture in the verification matrix passed, `TEST_CASM_EXPR`
independently proves the classification correct in isolation, the
ordering-hazard fix is proven end to end (`casmordhaz1`) without changing
any existing fixture's output, MAIN headroom is measured (68/13568, no
bump needed), a no-change rebuild holds `BUILD_CASM` stable, all three disk
images build clean, and the user confirmed the runtime results. Final CASM
`0.1.41` build 1147. WP40 (relocation table storage and emission-site
hooks) remains separately gated and unstarted per `AGENTS.md`.
