---
feature: casm-phase5-wp18-numeric-primary
created: 2026-07-21
status: complete
---

# Plan: CASM Phase 5 WP18 - Numeric Primary and Checked Arithmetic Core

## Objective

WP18 moves the existing numeric conversion implementation and its seven private
scratch bytes from `parser.s` into `expr.s` without coupling the expression
module to `CasmParserStmt`. It adds sign/magnitude addend parsing and checked
16-bit add/subtract/apply helpers. Existing Phase 4 parser and emitter behavior
must remain byte-for-byte stable through a thin compatibility wrapper.

Taskwarrior: `8f9467b6-e37d-4701-a4a6-6f90bd8fbf5b`.

Prerequisite: WP17 completed with explicit user approval at CASM `0.1.19` build
1082. WP18 remains pending with no start timestamp until this plan is approved.

## Dependency and Discrepancy Review

### Parser Coupling

The old `parseNumericValue` writes directly to `CasmParserStmt`. Moving it
unchanged into `expr.s` would require the expression core to import parser
storage, reversing the intended evaluator -> adapter dependency.

Resolution:

- `exprParseNumeric` owns conversion and returns X/Y = value low/high;
- `parser.s` retains exported `parseNumericValue` as a compatibility wrapper;
- the wrapper calls `exprParseNumeric` and stores X/Y into `CasmParserStmt`;
- existing parser and emitter call sites remain unchanged until WP20.

No circular import or duplicate numeric implementation is permitted.

### Scratch Ownership

`parser.s` currently owns seven private bytes:

```text
CasmParserValueLo/Hi/Ext/Overflow
CasmParserTempLo/Hi/Ext
```

WP18 relocates and renames them as evaluator-private BSS. Net linked BSS growth
from the move is zero. No zero-page, dynamic allocation, or exported scratch is
authorized. Addend sign is written directly to the result record, so no eighth
scratch byte is required.

### Numeric Compatibility

The Phase 4 converter already:

- accepts decimal, hexadecimal, and binary token forms;
- folds shifted-uppercase PETSCII hex letters;
- uses a 24-bit accumulator plus sticky overflow;
- rejects every value above `$FFFF`, even if later arithmetic wraps the 24-bit
  accumulator; and
- reports `CASM_DIAG_OPERAND_OUT_OF_RANGE` at the current number token.

WP18 preserves those semantics exactly. The decimal multiply-by-ten addition
must remain an explicit low/high/extension `ADC` chain; loop control may not
overwrite carry between bytes. Decimal boundaries 25/26, 255/256, 6553/6554,
65535, and 65536 receive explicit static regression review.

### Diagnostic Table Dependency

WP17 reserved `$24-$27`, but `diagnostics.s` still accepts and prints only
through `CASM_DIAG_PHASE4_LAST` (`$23`). WP18 is the first package to return
`CASM_DIAG_EXPR_MALFORMED` and `CASM_DIAG_EXPR_OVERFLOW`, so it must extend the
bounded parallel diagnostic tables through `CASM_DIAG_PHASE5_LAST` and add all
four Phase 5 messages to avoid holes:

```text
$24 CASM: MALFORMED EXPRESSION
$25 CASM: EXPRESSION UNSUPPORTED
$26 CASM: EXPRESSION OVERFLOW
$27 CASM: RESOLVER FAILED
```

WP18 adds messages only. Resolver behavior remains WP19 scope.

### Token and Location Ownership

`exprParseAddend` handles optional `+ number` or `- number` after a
symbol-derived primary:

- no operator: clear sign/magnitude, consume nothing, current token unchanged;
- operator: store sign, call `lexerNext` once, require NUMBER, parse magnitude;
- success leaves the NUMBER token current and unconsumed;
- malformed input stamps the current token and returns `$24`;
- numeric magnitude overflow retains the existing number-token location and
  returns `CASM_DIAG_OPERAND_OUT_OF_RANGE`.

Leaving the magnitude current lets `exprApplyAddend` stamp the correct token on
resolved arithmetic overflow. WP19 owns consuming that token after successful
application or deferred unresolved classification. This avoids diagnostics that
incorrectly point at the following comma/newline.

### Arithmetic Input Contract

Checked helpers read addend magnitude directly from the private result record;
they do not use numeric-conversion scratch:

- X/Y = base low/high;
- result-record magnitude = unsigned 16-bit addend;
- success returns X/Y adjusted and C clear;
- overflow/underflow returns A = `$26`, C set;
- error-path X/Y are unspecified and must not be consumed.

`exprApplyAddend` dispatches by sign, treats zero magnitude as a no-op, and
stamps the still-current magnitude token before returning arithmetic overflow.

### Memory Budget

WP17 measurements:

- CODE+RODATA: 8,741 bytes;
- BSS: 1,136 bytes;
- MAIN headroom: 363 bytes;
- relocations: 1,182.

The seven-byte scratch move is BSS-neutral, but wrapper, arithmetic, addend, and
diagnostic-message CODE/RODATA consume headroom. `$2800` remains fixed. If both
link bases do not fit with measurable positive headroom, stop for an amended
scope; do not enlarge MAIN or introduce opaque instruction-byte tricks.

## Inherited Contracts

- Phase 0C.3 grammar and result ABI in `brain/KNOWLEDGE.md` are frozen.
- WP17 offsets, flags, enums, and diagnostics cannot move.
- Numeric literals are unsigned `$0000..$FFFF`.
- Addends are sign plus unsigned 16-bit magnitude, not signed 16-bit values.
- Resolved arithmetic rejects mathematical results outside `$0000..$FFFF`.
- Evaluator routines execute neither `SED` nor `CLD`; every `ADC`/`SBC` path
  establishes carry explicitly.
- The evaluator owns no files, VMM, output, cleanup, or termination.

## Scope

Included:

- move numeric conversion and seven scratch bytes to `expr.s`;
- add parser-independent `exprParseNumeric`;
- retain a thin exported parser compatibility wrapper;
- implement `exprParseAddend`, `exprCheckedAdd`, `exprCheckedSub`, and
  `exprApplyAddend`;
- extend Phase 5 diagnostic printing through `$27`;
- preserve all existing numeric instruction/directive bytes and errors;
- add a dedicated WP18 test plan, generated valid/error numeric fixtures, and a
  hand-derived trusted reference covering carry and radix boundaries;
- inspect object/link/storage/relocation effects; and
- perform the gated `0.1.20` completion increment.

Excluded:

- expression primary dispatch or complete `exprEvaluate`;
- identifiers, resolver calls, extraction, unresolved classification;
- parser expression starts or replacing parser/emitter wrapper calls;
- fixtures that require identifier/addend evaluation before WP19;
- zero-page, VMM, symbols, two passes, relocation records, and output changes.

## Expected Files

| File | Action |
|---|---|
| `src/external/casm/expr.s` | numeric core, scratch, addend, checked arithmetic |
| `src/external/casm/parser.s` | remove scratch/core; retain compatibility wrapper |
| `src/external/casm/diagnostics.s` | append Phase 5 message table entries/strings |
| `src/external/casm/casm.s` | stage increment only after completion approval |
| `src/external/casm/BUILD_CASM` | build-managed increments |
| `cmake/GenerateCasmTestFixtures.cmake` | generated numeric valid/error sources |
| `CMakeLists.txt` | register generated fixtures and trusted reference |
| `tests/fixtures/casm/casmnum2.ref.hex` | hand-derived valid numeric reference |
| `brain/plans/2026-07-21-casm-phase5-wp18-test-plan.md` | detailed fixture matrix |
| `brain/plans/2026-07-21-casm-phase5-wp18-numeric-primary.md` | activation/progress |
| `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `brain/task.md` | evidence/status |
| `wiki/tasks/casm.md`, `CHANGELOG.md`, Taskwarrior | synchronized status |
| `brain/walkthroughs/2026-07-21-casm-phase5-wp18-numeric-primary.md` | verification walkthrough |

No `common.inc`, emitter, lexer, opcode, or state file should change. CMake and
fixture changes are limited to the approved WP18 test matrix.

## Public Routine Contracts

### `exprParseNumeric`

- Inputs: current token is a validated NUMBER; token text/record stable; D clear
  under the inherited CASM application invariant.
- Success: X/Y = value low/high, C clear; token remains current.
- Failure: A = `CASM_DIAG_OPERAND_OUT_OF_RANGE`, C set; location stamped from
  number token; X/Y unspecified.
- Clobbers: A, X, Y, N, Z, C; private seven-byte numeric scratch.
- Preserves: V, D, I, stack depth, lexer state, result record.

### `parseNumericValue` compatibility wrapper

- Inputs/outputs remain the existing Phase 4 contract.
- Calls `exprParseNumeric`, stores successful X/Y into statement value fields,
  and propagates failures unchanged.
- Clobbers A/X/Y and flags; no private BSS.

### `exprParseAddend`

- Inputs: current token is operator or first token after primary; result record
  initialized for the current expression; D clear.
- No operator: zero sign/magnitude, consume nothing, C clear.
- Operator success: sign/magnitude stored, NUMBER remains current, C clear.
- Failure: A = stable diagnostic, C set; result record invalid to caller.
- Clobbers A/X/Y, N/Z/C, lexer lookahead when an operator is present, and
  numeric scratch; preserves V/D/I and balanced stack.

### `exprCheckedAdd` / `exprCheckedSub`

- Inputs: X/Y base; addend magnitude in result record; D clear.
- Success: adjusted X/Y, C clear.
- Failure: A = `CASM_DIAG_EXPR_OVERFLOW`, C set; X/Y unspecified.
- Clobbers A/X/Y, N/Z/C; preserves V/D/I, stack, lexer, zero page, BSS other
  than no writes (result record is read-only).

### `exprApplyAddend`

- Inputs: X/Y base; sign/magnitude in result record; magnitude NUMBER current
  when nonzero arithmetic came from `exprParseAddend`; D clear.
- Success: adjusted X/Y, C clear.
- Failure: A = `$26`, C set, magnitude token location stamped.
- Clobbers A/X/Y, N/Z/C and diagnostic location only on failure; preserves
  V/D/I, stack, lexer, result record, and numeric scratch.

## Implementation Increments

1. After approval, start WP18 in Taskwarrior/wiki/brain and capture clean
   `0.1.19.1082` baseline measurements and Phase 4 reference hashes.
2. Extend `diagnostics.s` through `$27`; verify table cardinality and existing
   message indices remain unchanged.
3. Move seven numeric scratch bytes and the converter/helpers to `expr.s` as
   `exprParseNumeric`; add parser wrapper and verify existing caller graph.
4. Add the approved WP18 fixtures/reference and build integration. Build
   immediately; existing Phase 4 trusted manifests must remain unchanged.
5. Implement and statically audit addend parsing/token-position contracts.
6. Implement checked add/sub/apply; audit carry, underflow/overflow, zero
   magnitude, and error-location paths instruction by instruction.
7. Build both bases; inspect `expr.o`, `parser.o`, `diagnostics.o`, total BSS,
   CODE/RODATA, relocation count, PRG size, MAIN headroom, and no-change build.
8. Update documentation/tasks and create the walkthrough. Dry-run stage
   `19` -> `20`, verify one version-only build increment and stable rebuild,
   compare artifacts, then restore the implemented pre-approval build.
9. After explicit completion approval, apply the verified `0.1.20` increment,
   rebuild twice, close WP18, and leave WP19 pending separate plan approval.

## Verification Matrix

### Numeric Core

- decimal: 0, 25, 26, 255, 256, 6553, 6554, 65535, 65536;
- hexadecimal: `$0`, `$00FF`, `$FFFF`, `$10000`, shifted-uppercase A-F;
- binary: `%0`, `%11111111`, 16 ones, 17 ones;
- sticky overflow remains set after first crossing `$FFFF`;
- token and diagnostic location remain unchanged.

### Checked Arithmetic

- add: `$0000+0`, `$0000+1`, `$FFFE+1`, `$FFFF+0`, `$FFFF+1`;
- subtract: `$0000-0`, `$0001-1`, `$FFFF-$FFFF`, `$0000-1`;
- sign dispatch and zero-magnitude no-op for both signs;
- overflow returns `$26` with carry set and unusable X/Y.

### Structural

- no parser->expression duplicate implementation;
- `expr.s` does not import `CasmParserStmt`;
- scratch BSS moved, not duplicated;
- existing parser/emitter call sites still target parser wrapper;
- diagnostic tables contain exactly `$01-$27` entries;
- both links fit `$2800`; no zero page or new resources;
- no-change build stable; `git diff --check` clean.

WP18 has no production expression caller for addends yet. Their end-to-end token
matrix is deferred to WP19/WP21, but static routine and object verification is
mandatory here. Existing Phase 4 numeric runtime behavior remains covered by
its approved references and may receive an optional local smoke check only; the
broken C64-testing MCP and web emulators remain prohibited.

## Failure and Cleanup

WP18 acquires no resources. Any failure returns carry set and a stable
diagnostic; it never closes files, aborts output, exits, or mutates ownership.
If movement changes existing bytes, decimal carry is lost, diagnostics point at
the following token, scratch is duplicated, or MAIN headroom is exhausted,
stop and perform root-cause analysis rather than applying size tricks.

## Documentation and DOX

Update plan progress, knowledge, memory, task records, changelog, and the WP18
walkthrough. Re-read root and `src`/`external`/`casm` DOX after source edits.
AGENTS.md changes only if a durable local contract or child index changes.

## Stop Conditions

- WP17 records or artifact baseline disagree.
- Existing numeric behavior or trusted bytes change.
- `expr.s` must import parser/emitter state.
- New zero-page, dynamic allocation, non-fixture CMake, or emitter changes
  appear necessary.
- Printable diagnostics cannot extend contiguously without moving old values.
- Either link base overflows `$2800` or leaves no measurable headroom.
- WP19 implementation would begin before WP18 completion approval.

## Completion Gate

WP18 completes only after all increments and matrices pass, the walkthrough is
recorded, the user explicitly approves completion, the verified `0.1.20`
version-only increment passes, and Taskwarrior/wiki/brain agree. Completion does
not activate WP19.

## Progress

- 2026-07-21: Dependency review completed on
  `feature/casm-phase5-wp18` from WP17 commit `2bb5e4b`. Reconciled parser-core
  coupling, scratch ownership, Phase 5 diagnostic printing, number-token
  consumption/location, decimal carry regression risk, and the 363-byte MAIN
  budget. Detailed plan prepared; WP18 remains pending and inactive.
- 2026-07-21: User approved implementation and explicitly requested a test plan
  and fixtures. Scope amended to include generated numeric valid/error fixtures,
  one trusted byte manifest, and their existing CMake integration. Activated on
  `feature/casm-phase5-wp18` from WP17 commit `2bb5e4b`.
- 2026-07-21: Completion candidate implemented at build 1084. Numeric scratch is
  moved, not duplicated; parser/emitter callers retain the wrapper. Added
  checked addend helpers, printable `$24-$27` diagnostics, `casmnum2` trusted
  reference, and three radix-overflow fixtures. Both links and `test_image_d64`
  pass with 107-byte MAIN headroom. Independent audit found no arithmetic/token
  defect and clarified the inherited D-clear precondition. The verified
  `0.1.20` build 1085 dry run was restored pending runtime fixture results and
  completion approval.
- 2026-07-21: User approved completion. Applied the verified stage `19` -> `20`
  increment; build 1085, no-change rebuild, and `test_image_d64` pass. WP18 is
  complete and WP19 remains pending separate plan approval.
