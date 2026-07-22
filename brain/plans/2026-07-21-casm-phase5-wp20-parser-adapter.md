---
feature: casm-phase5-wp20-parser-adapter
created: 2026-07-21
status: complete
---

# Plan: CASM Phase 5 WP20 - Parser Adapter and Expression Fixture Harness

## Objective

WP20 integrates the Phase 5 evaluator into every production numeric-expression
position while preserving Phase 4 output bytes and delimiter ownership. It also
adds a separate ca65 test application with a deterministic resolver and embedded
expression fixtures, so symbol, addend, extraction, and failure behavior can be
verified without adding fixture names or test syntax to CASM and without relying
on instruction emission.

Taskwarrior: `41d120ed-b550-4551-9694-e66bd6f65cef`.

Prerequisite: WP19 completed at commit `56d8078`, CASM `0.1.21` build 1089.
Taskwarrior is pending, unblocked, and has no start timestamp. This plan requires
explicit approval before WP20 activation, production edits, or fixture creation.

## Dependency and Discrepancy Review

- `exprEvaluate` expects the first expression token already current and leaves
  the first following delimiter current. Phase 4 parser and `.BYTE`/`.WORD`
  loops currently call `lexerNext` before and after `parseNumericValue`. WP20
  must remove only the post-number advancement now owned by the evaluator;
  otherwise commas, closing parentheses, newlines, and EOF are skipped.
- `parserParseStatement` calls `lexerNext` before operand dispatch. Immediate
  and parenthesized forms call it once more after `#` or `(`. These initial
  advances remain required; the adapter starts from the resulting current token.
- The production symbol table does not exist until Phase 6B. CASM therefore
  needs a production resolver callback that rejects identifiers with carry set;
  it must not invent identities, map fixture names, or emit unresolved zero.
  Identifier expression starts are recognized and routed through the evaluator,
  but production assembly reports `CASM_DIAG_RESOLVER_FAILED` until Phase 6B.
- The parent Phase 5 contract requires a deterministic fixture resolver but
  forbids permanent test syntax. A dedicated `test_casm_expr` PRG linked with
  `expr.s` and test-owned lexer/diagnostic stubs satisfies both constraints.
- The current six-byte `CasmParserStmt` has value fields sufficient for WP20's
  production-resolved numeric results. Expression metadata remains in the
  private evaluator record and is inspected by the fixture harness through
  `exprGetResult`. Expanding the statement record merely for future Phase 6B/8
  would duplicate state and is not authorized.
- Opcode selection chooses zero page by value. No unresolved value may reach it.
  The production resolver failure enforces this now; Phase 6B must later consume
  `forceAbsoluteWidth` when it installs a real resolver.
- `.BYTE` currently enforces an 8-bit final value, `.WORD` accepts 16 bits,
  `.ORG` accepts one absolute operand shape, and immediate/indexed-indirect modes
  enforce 8-bit values downstream. These checks remain after evaluation and
  apply to the final extracted/adjusted value.
- Branches remain numeric-only in effective production behavior because symbols
  cannot resolve before Phase 6B. Resolved fixture symbols are tested only in
  the independent harness, not emitted as branch targets.
- WP19 leaves 298 bytes in CASM's approved `$2A00` MAIN envelope. The parser
  adapter should remove the compatibility wrapper and duplicate NUMBER-only
  branches, but every increment must measure actual CODE/BSS. Further envelope
  growth is not approved.
- WP21 owns full Phase 5 acceptance and runtime closeout. WP20 owns implementation
  and focused fixture evidence, not completion of the parent phase.

## Inherited Contracts

- Grammar remains `extraction? primary addend?`, with addends legal only for
  symbol-derived primaries.
- `exprEvaluate` callback, result, token, carry, diagnostic, and scratch
  contracts from WP19 are frozen.
- The resolver is called zero times for NUMBER and exactly once for IDENTIFIER.
- Unresolved placeholders are never copied into `CasmParserStmt`, matched by
  `opcodesFindOpcode`, or emitted.
- Numeric literals remain byte-compatible with Phase 4 in decimal, hex, and
  binary forms.
- Existing statement, opcode, emitter, diagnostic, token, and source ABI values
  do not move.
- No production zero page, VMM, symbol storage, labels, two-pass orchestration,
  relocation entries, or R6 serialization are added.
- Test code must execute under VICE or hardware, log each case, and use no
  broken `c64-testing` MCP or web emulator.

## Scope

Included:

- add one production resolver callback that rejects identifiers without
  advancing or modifying the current token;
- add a parser-local expression adapter that calls `exprEvaluate`, obtains the
  result through `exprGetResult`, verifies RESOLVED, and copies value low/high
  into `CasmParserStmt`;
- permit NUMBER, IDENTIFIER, `<`, and `>` at expression-start positions after
  mnemonic operands, `#`, `(`, `.ORG`, `.BYTE`, and `.WORD`;
- replace direct `parseNumericValue` calls in parser and directive list paths;
- preserve all delimiter, register, terminator, and diagnostic-location rules;
- remove the obsolete exported parser compatibility wrapper after its final
  callers are migrated;
- add `test_casm_expr`, a test-only ca65 PRG linked with production `expr.s`;
- add deterministic test resolver, scripted token stream, diagnostic-location
  stub, result assertions, and per-case PASS/FAIL logging;
- add a dedicated WP20 fixture/test plan with exact cases and expected records;
- register the test PRG on `test_image_d64` without adding production syntax;
- verify all existing trusted reference manifests and fixture registration; and
- perform the gated `0.1.22` completion increment.

Excluded:

- production symbol definitions, storage, lookup, labels, forward references,
  Pass 1/Pass 2, VMM, branch-symbol resolution, relocation generation, or R6;
- changing opcode selection to consume expression metadata before Phase 6B;
- emitting unresolved placeholders;
- fixture symbol names, fixture mode, command-line switches, or hidden test
  entry points in the production CASM binary;
- expanding `CasmParserStmt`, changing the nine-byte expression record, adding
  production BSS/zero page beyond measured adapter needs, or growing `$2A00`;
- trusted machine-code output for symbolic programs, which cannot be production
  output before the symbol-table phase.

## Production Resolver and Adapter ABI

### `parserRejectIdentifier`

- Inputs: current token is IDENTIFIER; X/Y point to the five-byte resolver view.
- Outputs: A = `CASM_DIAG_RESOLVER_FAILED`, C set.
- Preserves: current token/text, lexer state, X/Y, D, I, V, zero page, stack.
- Writes: none. It does not populate identity, flags, or value.

### `parseExpressionValue`

- Inputs: current token is a valid expression-start candidate; D clear.
- Calls `exprEvaluate` with `parserRejectIdentifier` in X/Y.
- Success: confirms `CASM_EXPR_FLAG_RESOLVED`, copies result value into
  `CasmParserStmt.ValLo/ValHi`, leaves evaluator's first following delimiter
  current, and returns C clear.
- Failure: propagates A/carry and diagnostic location; statement value is
  invalid. A defensive unresolved result returns `$27` rather than copying zero.
- Clobbers: A/X/Y, N/Z/C, evaluator and lexer scratch documented by WP19.
- Preserves: stack balance, D/I/V, resource ownership, emitter state.

The adapter is private unless the test harness proves a direct parser seam is
required. The independent harness targets `exprEvaluate`, not parser internals.

## Token Ownership by Context

| Context | Token current before adapter | Token current after adapter | Existing owner after return |
|---|---|---|---|
| immediate | first token after `#` | NEWLINE/EOF | `posExpectTerminator` validates without advancing first |
| absolute/indexed | expression start | NEWLINE/EOF/COMMA | absolute path dispatches terminator or index register |
| indirect | first token after `(` | RPAREN/COMMA | indirect grammar consumes close/index punctuation |
| `.ORG` | expression start | NEWLINE/EOF | parser validates terminator; emitter consumes stored value |
| `.BYTE` element | expression start | COMMA/NEWLINE/EOF | emitter list loop emits/checks then dispatches delimiter |
| `.WORD` element | expression start | COMMA/NEWLINE/EOF | emitter list loop emits then dispatches delimiter |

`posExpectTerminator` currently advances before validation. WP20 must split or
replace it so paths returning from the evaluator validate the already-current
delimiter, while accumulator/index-register paths that leave the register
current still advance once. This distinction is mandatory; globally deleting
or retaining the advance is incorrect.

## Test Harness Architecture

`tests/src/casm_expr/casm_expr.s` is a standalone external test application:

- includes `command64.inc` and CASM `common.inc`;
- links the production `src/external/casm/expr.s` object, but no parser, emitter,
  source, file, resource, or CASM entry object;
- defines test-owned `CasmTokenRecord`, contiguous `CasmTokenText`, `lexerNext`,
  and `diagSetLocFromToken` symbols required by `expr.s`;
- loads each embedded token descriptor into the same 39-byte token ABI used by
  production and scripts subsequent tokens through `lexerNext`;
- implements a case-sensitive deterministic resolver using explicit PETSCII
  constants and exact length/content checks;
- maps fixed fixture symbols to distinct opaque identities and states:
  `ABSVAL` = resolved absolute `$1234`, `RELVAL` = resolved relocatable `$2000`,
  `UNRES` = unresolved relocatable, and `UNABS` = unresolved absolute;
- includes explicit resolver-failure and invalid-returned-flag cases;
- calls `exprGetResult`, compares all nine result bytes on success, and verifies
  A/carry, diagnostic stamp count, offending token type/location, resolver call
  count, and final delimiter on failure/success;
- prints one compact PASS/FAIL line per case, a summary, and exits through
  `DOS_EXIT`; no test case writes files or invokes CASM emission.

The harness may use test-private BSS and zero-page within the external-app
`$70-$8F` convention because it runs independently of CASM. Its allocations and
clobbers must be documented in the source. It must not require changes to
production `expr.s` solely for observability.

## Fixture Matrix

The dedicated test plan will enumerate exact token arrays and expected records.
At minimum it covers:

### Numeric and Delimiters

- `0`, `$FFFF`, `%1111111111111111` as resolved absolute/full;
- `<$1234` -> `$0034`, `>$1234` -> `$0012`;
- NUMBER followed by COMMA, RPAREN, NEWLINE, and EOF remains on that delimiter;
- `1+1` and `1-1` -> `$25` at the operator.

### Resolved Symbols

- `ABSVAL`, `ABSVAL+0`, `ABSVAL+1`, `ABSVAL-$34`;
- `RELVAL+$0100` retains relocatable and becomes `$2100`;
- `<RELVAL` clears relocatable and yields `$0000`;
- `>RELVAL` retains relocatable and yields `$0020`;
- resolved add overflow/underflow -> `$26` at magnitude.

### Unresolved Symbols

- `UNRES`, `UNRES+$FFFF`, `UNRES-$FFFF` retain identity, sign/magnitude,
  relocatable, and force-absolute with unresolved value bytes untouched;
- `<UNRES` clears relocatable; `>UNRES` preserves it;
- `UNABS+5` remains unresolved absolute with force-absolute;
- case variant `absval` does not alias `ABSVAL` and follows the unknown/failure
  resolver expectation defined in the test plan.

### Malformed, Unsupported, and Resolver Failures

- `<` followed by NEWLINE, `+1`, `ABSVAL+`, and `ABSVAL+RELVAL` -> `$24` at the
  missing/invalid primary or magnitude;
- repeated extraction, chained addends, adjacent NUMBER/IDENTIFIER, and numeric
  arithmetic -> `$24` or `$25` exactly as WP19 defines;
- resolver carry-set -> `$27` at identifier;
- resolver output with bits outside `CASM_RESOLVE_FLAG_MASK` -> `$27`;
- resolver call count is zero for numeric and exactly one for every identifier.

### Production Regression

- build and byte-compare `casmemit1`, `casmhello`, `casmmodes`, and `casmnum2`
  outputs against their trusted references through the established native
  workflow;
- retain all Phase 4 diagnostic fixtures and expected errors;
- verify `.BYTE`/`.WORD` comma boundaries and immediate/indirect/indexed
  punctuation remain correctly owned after adapter migration.

## Expected Files

| File | Action |
|---|---|
| `src/external/casm/parser.s` | production resolver and expression adapter; migrate operand paths |
| `src/external/casm/emit.s` | migrate `.BYTE`/`.WORD` expression elements and delimiter handling |
| `src/external/casm/casm.s` | stage increment only after completion approval |
| `src/external/casm/BUILD_CASM` | build-managed increments |
| `tests/src/casm_expr/casm_expr.s` | standalone deterministic expression harness |
| `tests/src/casm_expr/BUILD_TEST_CASM_EXPR` | persistent test-app build number |
| `CMakeLists.txt` | register/link `test_casm_expr` with production `expr.s` and test image |
| `brain/plans/2026-07-21-casm-phase5-wp20-test-plan.md` | exact token/result/error matrix |
| `brain/plans/2026-07-21-casm-phase5-wp20-parser-adapter.md` | activation/progress |
| `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `brain/task.md` | contract/evidence/status |
| `wiki/tasks/casm.md`, `CHANGELOG.md`, Taskwarrior | synchronized status |
| `brain/walkthroughs/2026-07-21-casm-phase5-wp20-parser-adapter.md` | verification walkthrough |

`common.inc`, `expr.s`, opcode tables, diagnostics, state, source, resource, and
generated CASM SEQ fixtures are not expected to change. A need to change WP19's
evaluator or resolver ABI stops implementation for an amended plan.

## Storage, Register, and Flag Effects

- Production CASM: no new zero page or persistent expression record. Parser CODE
  changes and any BSS delta are measured; obsolete wrapper removal is expected
  to offset part of the adapter.
- Test app: bounded token record, scripted-token cursor, expected record, result
  counters, and resolver state only. Exact BSS and zero-page allocations are
  declared in the test plan before implementation.
- Every new public test/production routine documents inputs, outputs, carry/zero
  meaning, preserved/clobbered A/X/Y and P flags, stack, lexer state, and scratch.
- All arithmetic continues to inherit D-clear; no new ADC/SBC path may omit an
  explicit carry setup.

## Atomic Increments

1. After approval, start WP20 in Taskwarrior/wiki/brain and capture clean
   `0.1.21.1089` production hashes, object/MAIN measurements, trusted references,
   and test-image inventory.
2. Write the dedicated WP20 test plan with exact token descriptors, result bytes,
   diagnostic locations, resolver calls, and PASS/FAIL presentation.
3. Add `parseExpressionValue` and rejecting resolver without switching callers;
   inspect imports/exports, stack, carry, and object-size effects.
4. Migrate immediate, absolute/indexed, and indirect parser paths one context at
   a time. Build after each and audit current-token ownership.
5. Migrate `.ORG`, `.BYTE`, and `.WORD`; remove the final `parseNumericValue`
   wrapper/callers only after graph/text search proves none remain.
6. Build both bases and run existing numeric sources. Stop if unresolved state
   can reach opcode/emission code or `$2A00` lacks positive headroom.
7. Add `test_casm_expr` scaffolding and stubs, then deterministic resolver and
   embedded cases in small groups: numeric, resolved, unresolved, failures.
8. Configure and build the narrow test target; inspect its header, segments,
   imports/exports, disk name, and safe memory placement. Add it to test image.
9. Build `test_image_d64`; manually run `test_casm_expr` locally/on hardware and
   record every case and summary. Run established CASM trusted-reference
   comparisons for unchanged numeric output.
10. Inspect CASM/test object sizes, total BSS, relocation count, R6 size, MAIN
    headroom, fixture inventory, and no-change build stability.
11. Update records and walkthrough. Dry-run stage `21` -> `22`, verify one build
    increment and no-change stability, compare artifacts, then restore the
    implemented pre-approval build.
12. After explicit completion approval, apply the verified `0.1.22` increment,
    rebuild twice, complete WP20, and leave WP21 pending separate approval.

## Verification

- CMake configures without warning/error after adding the test target.
- CASM links at `$3400` and `$3500` within `$2A00` with positive measured
  headroom; no new production zero page/resources appear.
- Search proves production parser/emitter no longer call or export
  `parseNumericValue`.
- Every expression start accepts NUMBER/IDENTIFIER/LESS/GREATER dispatch; only
  the absent production symbol table causes identifiers to return `$27`.
- Delimiter matrix proves no skipped or double-consumed NEWLINE, EOF, COMMA,
  RPAREN, or index REGISTER token.
- No unresolved result reaches `CasmParserStmt` value consumption,
  `opcodesFindOpcode`, `emitInstruction`, `emitOrg`, or directive byte writes.
- `test_casm_expr` links production `expr.s`, contains no parser/emitter object,
  runs all cases, logs each result, and reports zero failures.
- Existing trusted PRGs remain byte-identical and all prior diagnostic fixtures
  remain registered on `test.d64`.
- Both CASM and test-app no-change rebuilds preserve build counters.
- `git diff --check` passes and changed paths match this plan.

## Failure and Cleanup

The adapter and harness acquire no production resources. Expression failures
return carry set and existing orchestration owns output abort/cleanup. The test
app performs no file I/O and exits through `DOS_EXIT` after printing its summary.

If adapter failure occurs after CASM has created output, existing `startFatal ->
outputAbort -> exitFatal` behavior remains responsible for deleting the partial
file while preserving the primary diagnostic.

## Stop Conditions

- WP19 commit/version/task records or resolver ABI disagree with the baseline.
- Correct delimiter ownership requires changing lexer behavior or WP19's
  evaluator token contract.
- Production needs a fixture resolver, hidden syntax, manufactured identity, or
  unresolved emission.
- `CasmParserStmt` expansion, opcode/emitter metadata changes, production symbol
  storage, VMM, or two-pass behavior becomes necessary.
- CASM exceeds `$2A00` or has no positive measured headroom.
- The test harness cannot link production `expr.s` without production-only
  resources or changes made solely for test observability.
- Existing trusted numeric bytes or diagnostics change unexpectedly.

Any stop condition requires root-cause analysis, a documented plan amendment,
and renewed user approval before implementation continues.

## Documentation, DOX, and Completion Gate

Update the WP20 plan/test plan, knowledge, memory, task records, changelog, and
walkthrough. Re-read root, `src`/`external`/`casm`, and `tests` DOX chains after
edits. Update `AGENTS.md` only if a durable contract or child index changes.

WP20 completes only after the focused fixture matrix and production regressions
pass, the user reviews the walkthrough and explicitly approves completion, and
the final `0.1.22` build is stable. Completion does not activate or complete
WP21 or Phase 5.

## Progress

- 2026-07-21: Drafted on clean `feature/casm-phase5-wp20` from WP19 commit
  `56d8078`. Reconciled parser/emitter token ownership, absent production symbol
  table, unresolved emission prohibition, independent fixture-harness boundary,
  Phase 4 regression obligations, Taskwarrior dependency, and 298-byte MAIN
  budget. WP20 remains pending without a start timestamp, awaiting approval.
- 2026-07-21: User approved implementation including the dedicated test plan
  and test-only fixtures. Activated Taskwarrior from `56d8078`; baseline is
  CASM `0.1.21` build 1089 with 298-byte `$2A00` MAIN headroom.
- 2026-07-21: Implementation candidate complete at build 1092. Parser/directive
  call sites use the evaluator, no `parseNumericValue` symbol remains, and the
  standalone 27-case harness builds as test build 1003. CASM leaves 243 MAIN
  bytes; both targets and `test_image_d64` pass. Awaiting local runtime results.
- 2026-07-21: User confirmed all 27 harness cases, `casmexprn` trusted-reference
  equality, `casmexpru` resolver failure, and partial-output cleanup. Runtime
  gate satisfied; completion dry run follows.
- 2026-07-21: Verified `0.1.22` build 1093 and no-change stability; candidate
  SHA-256 was `3bc2ff92b0b1a605759b3f419b301fc2c30b5747882d3b578676bca4e47ba92b`.
  Restored `0.1.21` build 1092 pending explicit completion approval.
- 2026-07-21: User approved completion. Applied the verified stage `21` -> `22`
  increment, rebuilt production and test targets, and closed WP20. WP21 remains
  pending its separate detailed-plan approval.
