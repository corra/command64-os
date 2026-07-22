---
feature: casm-phase5-wp19-symbol-resolver
created: 2026-07-21
status: complete
---

# Plan: CASM Phase 5 WP19 - Symbol, Extraction, and Resolver Behavior

## Objective

WP19 implements the production-neutral expression evaluator in `expr.s`: it
parses one optional extraction prefix, accepts numeric or identifier primaries,
invokes a caller-supplied resolver exactly once for an identifier, preserves the
frozen result metadata, applies a numeric addend only when the symbol is
resolved, and classifies low/high extraction without emitting bytes or creating
relocations.

Taskwarrior: `4acf22c2-8253-4673-918a-8dd38cc18221`.

WP18 is complete at commit `755fc45`, CASM `0.1.20` build 1085. This plan must be
approved before WP19 is started or source/task records are changed.

## Reconciliation Findings

- The WP18 artifact uses 10,133 of its `$2800` MAIN envelope and leaves 107
  bytes. The first WP19 link exceeded that envelope by 214 bytes. The user
  authorized expansion to `$2A00`: a 512-byte aligned increase ending at
  `$5DFF` for base `$3400` and `$5EFF` for base `$3500`, both below `$9FFF`.
- The parent plan assigns the deterministic fixture resolver and expression
  harness to WP20. WP19 therefore defines and consumes a resolver callback ABI;
  it does not embed symbol names, fixture values, or permanent test syntax.
- There is no production symbol table before Phase 6B and no `symbols.s` module.
  WP19 must not create storage, hashes, identities, or VMM records.
- The lexer keeps the current token in `CasmTokenRecord`; there is no separate
  token lookahead API. The evaluator must document exactly which token remains
  current on every success and failure.
- WP18 deliberately leaves an addend NUMBER current so arithmetic overflow is
  reported at its magnitude. WP19 must apply resolved arithmetic before
  consuming that token.
- Extraction applies to the final mathematical expression. For unresolved
  symbols there is no value to extract: metadata is retained, low extraction
  clears relocation classification, high extraction preserves it, and the
  placeholder value remains invalid and unmodified.
- The abandoned commit `0d4c336` is reference evidence only. It embedded the
  WP20 fixture resolver, exported private BSS, imported parser state, consumed
  addend tokens before checked arithmetic, used host character literals, could
  not report resolver failure, extracted unresolved zero, and used
  carry-sensitive loop folding. None of those choices is inherited.
- Existing Phase 5 diagnostics `$24-$27` are printable. `$24` reports malformed
  grammar, `$25` unsupported but well-formed algebra, `$26` checked range
  failure, and `$27` resolver failure.

## Inherited Decisions

- Grammar remains `extraction? primary addend?`; only identifier primaries may
  have one `+number` or `-number` addend.
- The nine-byte result record, all offsets, flags, extraction values, addend
  values, and diagnostic numbers are frozen.
- Resolver identities are opaque 16-bit values supplied by the resolver.
- Unresolved symbols set `symbolDerived|forceAbsoluteWidth`, preserve identity,
  relocation class, extraction, sign, and magnitude, and expose no usable value.
- Resolved arithmetic is checked against `$0000..$FFFF` before extraction.
- Low extraction clears relocatable; high extraction preserves relocatable.
- Numeric literals remain absolute and resolved. Numeric `+/-` is unsupported.
- No routine executes `SED` or `CLD`; every `ADC`/`SBC` chain establishes carry.
- No zero page, VMM, files, output, relocation records, or cleanup ownership are
  added. The private result record remains accessible only through
  `exprGetResult`. The approved WP19 MAIN envelope is `$2A00`.

## Scope

Included:

- define the resolver callback result contract in comments and implementation;
- implement one bounded indirect-call trampoline for the callback;
- implement `exprEvaluate` and private primary/extraction helpers as needed;
- accept NUMBER and IDENTIFIER primaries and call the resolver once only for an
  identifier;
- preserve resolver identity/state/value/class and addend metadata;
- apply checked addends to resolved symbols before extraction;
- classify full, low, and high extraction for resolved and unresolved results;
- reject missing primaries/addends, numeric arithmetic, repeated extraction,
  symbol-to-symbol arithmetic, and chained operators with stable diagnostics;
- measure and, only if required, perform audited semantic-preserving CODE
  compaction in `expr.s`; and
- perform the gated `0.1.21` completion increment.

Excluded:

- deterministic resolver fixtures and an executable expression harness (WP20);
- parser/emitter integration, addressing-mode selection, or output changes;
- production symbol storage/resolution, labels, passes, VMM, and hashing;
- relocation entries or R6 serialization;
- new grammar, zero-page, dynamic storage, further MAIN growth, opaque instruction-byte
  tricks, self-modifying code, or exporting `CasmExprResultRecord`.

## Resolver Callback ABI

`exprEvaluate` receives the callback address in X/Y (low/high). The address is
valid for the duration of the call and is copied to exactly two bytes of private
expression BSS. A private trampoline performs a normal subroutine call and
returns to the evaluator with the resolver's A/carry result unchanged.

Resolver input:

- current token is IDENTIFIER;
- X/Y point to a private five-byte resolver output view ordered as flags,
  identity low/high, and value low/high;
- `CasmTokenRecord` and `CasmTokenText` contain the complete case-sensitive
  identifier and source location;
- the resolver may read but must not advance or rewrite lexer state;
- D is clear under the inherited CASM application invariant.

Resolver success, C clear:

- the five-byte output view contains only the allowed resolved/relocatable flag
  bits, opaque identity, and value;
- the value bytes are meaningful only when RESOLVED is set;
- A is unspecified.

Resolver failure, C set:

- A is a stable diagnostic. WP19 propagates `$27`; a callback-specific stable
  diagnostic may be propagated only if a later approved resolver contract
  defines one;
- the identifier remains current so WP19 stamps its location before returning;
- X/Y and the output view are invalid.

The callback does not set `symbolDerived` or `forceAbsoluteWidth`; WP19 owns
those evaluator classifications. Returned flag bits outside the two allowed
bits are a contract failure and stop implementation rather than being silently
accepted.

The five-byte resolver output view and two callback-address bytes are private
BSS. Their address is passed only for the callback invocation; neither storage
label is exported. They are not added to the public nine-byte result record.
If a smaller ABI can reuse existing private scratch without weakening any
public preservation contract, that change requires a plan amendment before use.

## Evaluator and Token Contract

`exprEvaluate`:

- Inputs: current token begins an expression; X/Y callback address; D clear.
- Success: result record valid, C clear, A/X/Y and N/Z unspecified; current token
  is the first token after the expression, except an addend NUMBER may remain
  current only while checked arithmetic/extraction is still in progress.
- Failure: A is stable diagnostic, C set, result invalid; diagnostic location is
  the offending current token.
- Preserves: V, D, I, balanced stack, zero page, resources, parser/emitter state.
- Clobbers: A/X/Y, N/Z/C, lexer state according to consumption below, expression
  record, private numeric scratch during number conversion, and seven resolver
  BSS bytes.

Token sequence:

1. `exprInit`; store callback address.
2. If current token is `<` or `>`, store extraction and consume exactly once.
3. NUMBER: parse while current, store value and RESOLVED, then consume once.
   A following `+` or `-` fails `$25` at the operator.
4. IDENTIFIER: invoke callback while current, validate/store resolver output,
   add `symbolDerived`, and add `forceAbsoluteWidth` when unresolved. Consume the
   identifier once, then call `exprParseAddend`.
5. Resolved identifier: apply the addend while its NUMBER remains current, store
   the checked value, then consume that NUMBER exactly once when an operator was
   present. Unresolved identifier: retain sign/magnitude and consume the NUMBER
   once without arithmetic.
6. Reject a second `+`/`-`, `<`/`>`, NUMBER, or IDENTIFIER as unsupported algebra
   when it is a recognizable continuation. Delimiters accepted by the future
   parser adapter remain current.
7. Apply extraction metadata last. Transform value bytes only when RESOLVED.

Missing primary or addend and repeated extraction are malformed (`$24`). Numeric
arithmetic, chained arithmetic, and symbol-to-symbol arithmetic are unsupported
(`$25`). Lexer failures propagate unchanged. Resolver failure is `$27` with the
identifier location. Checked arithmetic failure remains `$26` at the magnitude.

## Extraction Matrix

| State | Full | Low | High |
|---|---|---|---|
| resolved absolute | value unchanged | low in valueLo, valueHi=0 | high in valueLo, valueHi=0 |
| resolved relocatable | relocatable retained | value extracted, relocatable cleared | value extracted, relocatable retained |
| unresolved absolute | metadata retained; value invalid | metadata retained; relocatable clear | metadata retained; relocatable clear |
| unresolved relocatable | metadata retained | relocatable cleared | relocatable retained |

All unresolved cases retain `forceAbsoluteWidth`; extraction does not make the
placeholder value consumable and does not clear symbol identity or addend.

## Expected Files

| File | Action |
|---|---|
| `src/external/casm/common.inc` | shared resolver output offsets/mask/assertions |
| `src/external/casm/expr.s` | evaluator, resolver trampoline, extraction, private BSS |
| `CMakeLists.txt` | expand CASM MAIN from `$2800` to approved `$2A00` |
| `src/external/casm/casm.s` | stage increment only after completion approval |
| `src/external/casm/BUILD_CASM` | build-managed increments |
| `brain/plans/2026-07-21-casm-phase5-wp19-symbol-resolver.md` | activation/progress |
| `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `brain/task.md` | contract/evidence/status |
| `wiki/tasks/casm.md`, `CHANGELOG.md`, Taskwarrior | synchronized status |
| `brain/walkthroughs/2026-07-21-casm-phase5-wp19-symbol-resolver.md` | verification walkthrough |

Parser, emitter, lexer, state, and fixture files are not expected to change.

## Atomic Increments

1. After approval, start WP19 in Taskwarrior/wiki/brain and capture the clean
   `0.1.20.1085` artifact, object, BSS, relocation, and 107-byte baseline.
2. Add the private callback/output BSS and indirect-call trampoline. Statically
   verify stack balance and exact carry/A/X/Y propagation with a hand trace.
3. Add extraction-prefix and primary dispatch without parser integration.
4. Add identifier resolution, returned-bit validation, identity/value/class
   storage, and unresolved force-absolute classification.
5. Integrate WP18 addend parsing and checked application. Audit every token
   transition and diagnostic source location before adding extraction.
6. Add resolved/unresolved extraction and unsupported-continuation checks.
7. Build both relocation bases after each source increment in the user-approved
   `$2A00` envelope. No compaction of existing WP18 routines is authorized.
8. Inspect exports/imports, object segments, total BSS, CODE+RODATA, relocation
   count, R6 size, and MAIN headroom. Build `test_image_d64` to prove existing
   fixtures remain registered; WP19 adds no runtime fixture.
9. Update records and walkthrough. Dry-run stage `20` -> `21`, verify exactly
   one build increment and no-change stability, compare artifacts, then restore
   the implemented pre-approval build.
10. After explicit completion approval, apply the verified `0.1.21` increment,
    rebuild twice, close WP19, and leave WP20 pending separate plan approval.

## Verification

- Both link bases build without warnings/errors inside `$2A00` with positive,
  measured headroom.
- `expr.o` adds exactly seven private resolver BSS bytes unless an approved
  amendment changes the implementation; no ZEROPAGE, DATA, resources, parser
  import, fixture names, or public record export appear.
- The trampoline's synthetic return address, stack order, target transfer, and
  carry/register propagation are audited instruction by instruction.
- Each accepted path calls the resolver zero times for NUMBER and exactly once
  for IDENTIFIER; resolver input remains the current identifier.
- A static path matrix covers resolved/unresolved x absolute/relocatable x
  full/low/high x no/positive/negative addend.
- Error paths cover missing primary, missing addend, repeated extraction,
  numeric arithmetic, chained operators, symbol-to-symbol arithmetic, resolver
  failure, and checked overflow/underflow with the intended token location.
- Unresolved value bytes are never transformed or exposed as valid; low clears
  relocatable and high preserves it.
- Existing `casmnum2` and all Phase 4 trusted references remain unchanged.
- `casm`, both explicit relocation links, and `test_image_d64` pass; generated
  disk still contains all existing WP18 fixtures.
- No-change build preserves `BUILD_CASM`; `git diff --check` passes.

WP19 has no approved runtime caller or fixture resolver, so its verification is
structural, link-level, and static path analysis. End-to-end expression result
bytes begin in WP20's separately approved fixture harness. The broken
`c64-testing` MCP and web emulators remain prohibited.

## Failure and Cleanup

WP19 acquires no resources and performs no cleanup or termination. Lexer and
resolver failures return carry set with stable diagnostics. The evaluator never
closes files, aborts output, frees VMM, writes output, or creates relocations.

On callback failure, unsupported returned bits, token ownership mismatch,
arithmetic-location loss, stack imbalance, or envelope overflow, stop and
perform root-cause analysis. Do not substitute a fixture resolver, consume an
extra token, enlarge MAIN, export private storage, or use undocumented opcode
bytes to force the build through.

## Stop Conditions

- WP18 commit/version/build/task records disagree with the baseline.
- The callback ABI cannot be implemented without zero page, self-modifying
  code, or violating the normal stack contract.
- The seven-byte private BSS or evaluator cannot fit in `$2A00` with positive
  MAIN headroom.
- Existing numeric behavior, public ABI, parser compatibility, or fixture bytes
  change.
- Parser/emitter/CMake/fixture changes become necessary before WP20.
- A resolver must manufacture identity, access VMM, or embed fixture names.
- Token advancement cannot preserve the addend magnitude through checked
  arithmetic and still return the first delimiter current.

Any stop condition requires a documented amendment and renewed approval.

## Documentation, DOX, and Completion Gate

After implementation, update this plan, knowledge, memory, task records,
changelog, and the WP19 walkthrough. Re-read the root and
`src`/`external`/`casm` DOX chain. `AGENTS.md` changes only if a durable contract
or child index changes.

WP19 completes only after all structural and build evidence is recorded, the
user reviews the walkthrough and explicitly approves completion, and the final
`0.1.21` build passes. Completion does not activate WP20 automatically.

## Progress

- 2026-07-21: Reconciled the clean WP18 baseline, parent Phase 5 contract,
  lexer/token behavior, WP18 addend-location contract, 107-byte MAIN budget,
  Taskwarrior dependency, and abandoned `0d4c336` attempt. WP19 remains pending
  without a start timestamp. Awaiting plan approval.
- 2026-07-21: User approved implementation and confirmed the test plan,
  deterministic resolver, and fixtures remain WP20 scope. Activated
  Taskwarrior and `feature/casm-phase5-wp19` from `755fc45`; baseline remains
  CASM `0.1.20` build 1085, 10,133 MAIN bytes used, and 107 bytes headroom.
- 2026-07-21: Initial implementation assembled but overflowed `$2800` by 214
  bytes. User authorized envelope growth. Amended CMake to `$2A00`; no WP18
  compaction, fixture work, or further envelope growth is authorized.
- 2026-07-21: Audit found WP20 could not implement the callback without shared
  output-view offsets. User approved adding the five-byte resolver ABI and
  assertions to `common.inc`; callback/output storage remains private.
- 2026-07-21: Completion candidate implemented at `0.1.20` build 1088. Both
  links and `test_image_d64` pass; `expr.o` is 835 CODE / 23 BSS, total MAIN use
  is 10,454 of `$2A00` with 298 bytes headroom, and R6 has 1,268 relocations.
  The `0.1.21` build 1089 dry run and no-change rebuild passed and were restored
  pending walkthrough review and explicit completion approval.
- 2026-07-21: User approved completion. Applied the verified stage `20` -> `21`
  increment, rebuilt both bases and the test image, and closed WP19. WP20
  remains pending its separate detailed-plan approval.
