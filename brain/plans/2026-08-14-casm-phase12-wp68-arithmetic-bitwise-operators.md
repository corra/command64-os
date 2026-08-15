---
feature: casm-phase12-wp68-arithmetic-bitwise-operators
created: 2026-08-14
status: approved
taskwarrior: c1b8e145-0a9c-4e15-aaab-4e82fc253363
depends-on: 8d988ac6-730a-440a-bc6e-a12e0c36888d (WP67, complete)
---

# Plan: CASM Phase 12 WP68 - Arithmetic and Bitwise Operators

## Status

**Approved 2026-08-14.** The user approved this plan as drafted after
separately confirming all three Scoping Decisions. Implementation of the
Atomic Increments below is authorized. Taskwarrior task 43
(`c1b8e145-0a9c-4e15-aaab-4e82fc253363`) is active and depends on WP67.

Parent plan:
`brain/plans/2026-08-13-casm-phase12-constants-expanded-expressions.md`.
Prerequisites: WP64 (contract freeze) and WP67 (parentheses and explicit
precedence), both complete and user-approved. WP68 is the next package on
the Phase 12 dependency spine (WP64 -> WP67 -> **WP68** -> WP70 -> WP71 ->
WP72).

## Objective

Add the arithmetic and bitwise expression operators frozen by WP64 to
WP67's existing precedence-climbing evaluator: binary `*`, `/`, `<<`,
`>>`, `&`, `^`, and `|`, plus prefix unary `-` and `~`. Values remain
bounded 16-bit quantities; multiplication and shifts are checked rather
than silently overflowing, division by zero receives its reserved stable
diagnostic, and every new operator rejects relocatable operands per WP64's
representability contract.

This WP does not extend named-constant RHS grammar, add modulo, add
character literals, or perform WP70's consolidated relocation-algebra
closure.

## Scoping Decisions (user-confirmed 2026-08-14)

1. **Unsigned 16-bit arithmetic.** Multiplication is checked against
   `$FFFF`; division is unsigned and truncates toward zero. Unary `-`
   produces the operand's 16-bit two's-complement representation. This
   gives unary negation useful assembler semantics without redefining all
   other arithmetic as signed.
2. **Shift counts are bounded to 0-15.** Counts at or above 16 raise
   `CASM_DIAG_EXPR_OVERFLOW`; no silent zeroing, masking, or
   processor-dependent count behavior is permitted. Left shift also
   raises overflow if a one bit is discarded; right shift is logical and
   zero-filling.
3. **Exact operator inventory.** WP68 implements only `*`, `/`, `<<`,
   `>>`, `&`, `^`, `|`, unary `-`, and unary `~`. Modulo `%` is excluded,
   and `ppsConstant` retains the narrower named-constant RHS grammar
   confirmed in WP67.

## Inherited Contracts

- Precedence, highest to lowest: unary `-`/`~`; `*`/`/`; `<<`/`>>`; `&`;
  `^`; `|`; binary `+`/`-`. Binary operators are left-associative.
- A leading `(` remains reserved for 6502 indirect-addressing syntax; a
  parenthesized expression is reachable only as a sub-expression where
  WP67 already permits it.
- New operators require static operands. Any relocatable operand reaching
  one raises `CASM_DIAG_EXPR_RELOC_UNSUPPORTED`. Existing relocatable
  symbol plus/minus static-addend behavior remains unchanged.
- Extraction (`<`/`>`) remains a whole-expression, top-level operation.
- Expression values, records, resolver ABI, and token source-location
  fields retain their current sizes and meanings.
- Parenthesis depth remains bounded at 8. WP68 must re-check practical
  stack headroom because unary parsing and precedence recursion may add
  live stack bytes at each nested level.

## Technical Design

### Lexer and Tokens

Add stable token types for slash, ampersand, caret, pipe, tilde, left
shift, and right shift. `*` continues to use `CASM_TOKEN_STAR`; its role is
contextual: current-address primary when a primary is expected,
multiplication when an infix operator is expected. `-` similarly remains
one token and is interpreted as unary or binary from parser position.

The lexer recognizes `<<` and `>>` with deterministic two-byte lookahead
while preserving single `<`/`>` extraction tokens. Single-character new
punctuation follows the existing punctuation-table path. Every token keeps
the first source byte's location so diagnostics point at the operator,
including two-byte shifts.

### Evaluator Shape

Generalize WP67's `parseOperatorTail` from its current `+`/`-` loop into a
precedence-climbing routine with an explicit minimum-precedence input.
Operator classification returns token, precedence, and operation kind;
the evaluator consumes an operator, recursively parses the RHS at the
correct next minimum precedence, then combines the saved accumulator and
RHS. All binary operators remain left-associative.

Extend `parsePrimary` with a bounded unary-prefix path. Unary `-` and `~`
may chain and apply right-to-left (`~-1` means `~(-1)`). A unary operator
must be followed by another unary or a normal primary; malformed tails use
the existing expression diagnostic. Unary parsing must preserve the
parenthesized-depth accounting and keep every success/failure stack path
balanced.

The existing `rejectContinuation` guard is expanded to recognize all new
operator tokens so an operator omitted from the precedence dispatcher
cannot be silently left for the statement parser.

### Numeric Semantics

- `&`, `^`, `|`, and `~` operate independently on both bytes.
- `<<` performs 0-15 checked single-bit shifts and fails before returning a
  wrapped result if any high bit would be discarded.
- `>>` performs 0-15 logical, zero-filling single-bit shifts.
- `*` uses a bounded 16-iteration shift/add implementation with explicit
  overflow detection on both shifted multiplicand and accumulated product.
- `/` uses bounded unsigned binary long division, returns quotient only,
  truncates toward zero, and raises `CASM_DIAG_EXPR_DIV_ZERO` for zero RHS.
- Unary `-` computes two's-complement modulo 16 bits, including `$0000 ->
  $0000` and `$8000 -> $8000`; it does not raise arithmetic overflow.
- Existing binary `+`/`-` retain WP67's checked behavior and diagnostics.

Every combine helper has a documented input/output/register/flag/scratch
contract. Helpers use module-private bounded BSS scratch unless the
Increment 1 audit proves existing private zero-page scratch can be reused
without extending the approved `$84-$87` expression range. No new
zero-page allocation is planned.

### Classification and Diagnostics

Before applying a new unary operator, reject a relocatable operand. Before
applying a new binary operator, reject either relocatable operand. On
success, combine `RESOLVED` conservatively and preserve
`SYMBOL_DERIVED` only as provenance; no new operator may produce a
relocatable result. Unresolved operands must not be numerically evaluated.
Increment 1 traces whether unresolved symbol-shaped operands can reach a
new operator in Pass 1; the implementation must reject them deterministically
rather than operate on placeholder bytes.

Activate WP64-reserved `CASM_DIAG_EXPR_DIV_ZERO` (`$44`). Reuse
`CASM_DIAG_EXPR_OVERFLOW` for multiplication and shift overflow and
`CASM_DIAG_EXPR_RELOC_UNSUPPORTED` (`$45`) for forbidden relocation
algebra. Add or update diagnostic message-table entries and compile-time
numbering assertions as required.

## Scope

**Included:**

- Lexer/token support for every approved operator, including `<<`/`>>`
  versus extraction disambiguation.
- A real precedence-climbing operator dispatcher built on WP67's shipped
  evaluator, preserving the confirmed precedence tiers and associativity.
- Unary-prefix parsing for `-` and `~`.
- Bounded 16-bit bitwise, shift, multiply, and divide implementations with
  the semantics in Scoping Decisions 1-2.
- Per-operation static-only relocation enforcement.
- Unit/harness cases for lexer behavior, precedence, associativity,
  arithmetic boundaries, diagnostics, source locations, and stack balance.
- End-to-end CASM source fixtures proving the production binary emits the
  expected bytes for mixed expressions.
- Full affected-harness regression, production-envelope measurement, and
  no-change rebuild verification.

**Excluded:**

- Modulo `%` or any operator not listed in Scoping Decision 3.
- Signed multiplication, signed division, arithmetic right shift, or
  values wider than 16 bits.
- New operators in `identifier = expr`; `ppsConstant` remains untouched.
- Character literals (WP69).
- Consolidated relocation-algebra certification (WP70).
- DASH source adoption (WP71) and Phase 12 completion verification (WP72).

## Atomic Increments

1. **Baseline and contract audit:** capture byte/message/location-exact
   results for all current expression and lexer cases; measure current
   production/test envelopes; trace unresolved-operand behavior, private
   scratch availability, and worst-case stack use through WP67's nested
   parser before selecting exact helper scratch and call shapes.
2. **Token inventory and lexer:** add single-character operator tokens and
   two-character shift recognition; verify lone `<`/`>` extraction,
   `<<`/`>>`, punctuation adjacency, EOF/newline boundaries, and exact token
   source locations without touching evaluator behavior.
3. **Precedence dispatcher:** generalize `parseOperatorTail` to explicit
   precedence climbing and route existing `+`/`-` through it first. Before
   enabling new operators, reproduce Increment 1's existing expression
   outputs and diagnostics byte-for-byte.
4. **Cheap bitwise and unary operators:** implement `&`, `^`, `|`, unary
   `~`, and unary `-`; verify precedence, chained unary order, static-only
   enforcement, and all 16-bit boundary patterns.
5. **Checked shifts:** implement `<<`/`>>`; verify counts 0, 1, 15, and 16,
   left-shift overflow, logical right-shift zero fill, and interaction with
   extraction tokens and precedence.
6. **Checked multiplication and division:** implement bounded software
   multiply/divide; verify zero/one identities, `$FFFF` boundaries,
   multiplication overflow, quotient truncation, division by zero, and
   precedence/left-associativity in mixed chains.
7. **Relocation, unresolved, and parser integration:** exercise every new
   unary/binary operator with labels, current address, label-derived
   constants, pure numeric constants, unresolved Pass 1 references,
   immediate operands, directives, and parenthesized RHS forms. Confirm
   forbidden forms fail at the operator with the reserved diagnostic and
   valid static forms preserve Pass 1/Pass 2 width agreement.
8. **Harness and envelope verification:** expand the existing CASM lexer,
   expression, parser/pass, and diagnostics harnesses; run the full affected
   target set and disk-image build; inspect PRG/R6 sizes and relocation
   counts; confirm the `$6000` production cap and every test cap still hold,
   and confirm a no-change rebuild changes no artifact/build number.
9. **Live end-to-end verification:** add production CASM fixtures containing
   mixed-precedence, unary, shift, multiplication/division, and diagnostic
   cases; boot Command64 and run them through the real `casm.prg` under the
   approved VICE MCP workflow, then re-run every harness whose linked shared
   modules or disk placement changed.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/common.inc` | Modify token inventory, operator constants, and assertions |
| `src/external/casm/lexer.s` | Modify punctuation and two-byte shift recognition |
| `src/external/casm/expr.s` | Modify precedence/unary parser and add bounded operator implementations |
| `src/external/casm/diagnostics.s` | Modify division-by-zero message integration if not already present |
| `src/external/casm/parser.s` | Modify only if an existing operand-entry whitelist blocks a valid new expression form |
| `src/external/casm/state.s` | Modify only if Increment 1 proves additional bounded expression BSS scratch is required |
| `tests/src/casm_expr/*`, `tests/src/casm_lexer/*` | Modify expression/operator and token fixtures |
| `tests/src/casm_pass1/*`, `tests/src/casm_passcheck/*` | Modify only for Pass 1/Pass 2 and relocation integration coverage |
| `tests/fixtures/casm/*` | Add end-to-end CASM source/reference fixtures |
| `cmake/GenerateCasmTestFixtures.cmake`, `CMakeLists.txt` | Modify fixture generation, disk placement, and only measured envelope caps |
| `docs/casm-utility.md`, `wiki/casm-utility.md` | Modify together at completion with syntax, precedence, and numeric semantics |
| `wiki/casm-programmers-reference.md` | Modify evaluator/token/diagnostic internals at completion |
| `brain/KNOWLEDGE.md`, `brain/task.md`, `wiki/tasks/casm.md` | Modify at activation/completion as applicable |
| `CHANGELOG.md` | Modify at completion |

The Expected Files table is a bounded forecast, not permission to edit every
conditional entry. An unexpected production-module boundary requires renewed
direction before proceeding.

## Stop Conditions

- Increment 3 cannot reproduce WP67's existing `+`/`-` behavior and
  diagnostics exactly before new operators are enabled.
- Actual unresolved-operand behavior conflicts with the classification plan
  above and cannot be resolved without changing symbol/resolver ABI.
- Any helper requires new zero-page bytes outside CASM's approved private
  expression range, or worst-case stack analysis no longer supports the
  existing 8-level parenthesis bound.
- The real implementation cannot satisfy the approved unsigned semantics,
  overflow rules, or 0-15 shift bound without a new diagnostic/grammar
  decision.
- The production `$6000` envelope or an approved test envelope is exceeded;
  report measured usage and request direction rather than silently raising a
  cap.
- A no-change rebuild changes an artifact or build number.
- Any harness/test fails unexpectedly. Perform root-cause analysis before
  proposing a correction; do not continue layering operators on a failing
  increment.
- A genuinely new defect outside this plan's scope is discovered. Disclose
  and defer it as a separately planned follow-up unless the user explicitly
  directs an inline fix and approves the plan deviation.

## Documentation, Task, and DOX Updates

- After plan approval, create/activate the Taskwarrior WP68 task under Phase
  12 with WP67 as its dependency, then synchronize `brain/task.md` and
  `wiki/tasks/casm.md` to in-progress. Do not activate before approval.
- At completion, record the as-built operator and arithmetic contracts in
  the existing Phase 12 section of `brain/KNOWLEDGE.md`; synchronize
  Taskwarrior, `brain/task.md`, `wiki/tasks/casm.md`, `CHANGELOG.md`, and
  session memory.
- Update `wiki/casm-utility.md` first and keep `docs/casm-utility.md`
  byte-identical. Update `wiki/casm-programmers-reference.md` for lexer,
  evaluator, scratch, and diagnostic changes.
- Perform the DOX closeout pass. The existing CASM contracts already govern
  bounded arithmetic, zero-page use, stack discipline, and per-WP approval;
  update an `AGENTS.md` only if implementation changes a durable contract,
  responsibility, workflow, or child index.
- On completion approval, advance CASM's stage version exactly once under
  the existing version policy; do not alter version metadata before the
  completion gate.

## Completion Gate

WP68 completes only when all nine increments are implemented and verified;
all pre-WP68 expression results remain byte/message/location-identical unless
this approved plan explicitly changes them; every new operator satisfies the
approved precedence, associativity, 16-bit arithmetic, overflow, shift-count,
and relocation rules; full affected harnesses and disk-image builds pass; the
production and test envelopes remain approved; no-change rebuild stability is
confirmed; live production-binary evidence is recorded in
`brain/walkthroughs/2026-08-14-casm-phase12-wp68-arithmetic-bitwise-operators.md`;
documentation, task trackers, knowledge, changelog, memory, and DOX are
synchronized; and the user explicitly approves closing WP68.

## Progress

- 2026-08-14: User corrected the requested package from WP66 (already
  complete) to WP68. Read-only discovery confirmed WP67 is complete and
  WP68 is next on the Phase 12 dependency spine; no WP68 plan existed.
- 2026-08-14: Surfaced and user-approved three scoping decisions: unsigned
  16-bit arithmetic with checked multiplication and two's-complement unary
  negation; shift counts restricted to 0-15 with overflow diagnostic at 16+;
  exact operator inventory with no modulo and no named-constant RHS grammar
  expansion.
- 2026-08-14: Drafted this detailed plan against WP64's frozen contract,
  WP67's as-built evaluator and completion evidence, and the current CASM
  lexer/token source. Awaiting explicit plan approval; no source, test,
  tracker, or build-system edits have begun.
- 2026-08-14: **User approved this plan as drafted.** Created and started
  Taskwarrior task 43 (`c1b8e145-0a9c-4e15-aaab-4e82fc253363`) with WP67
  as its dependency. Implementation authorization is active; Atomic
  Increment 1 begins next.
- 2026-08-14: **Atomic Increment 1 complete.** Narrow baseline build
  (`cmake --build build --target casm test_casm_expr test_casm_lexer`)
  passed, then an immediate no-change rebuild passed without changing any
  build counter or artifact hash. Baseline counters: `casm` 1296,
  `test_casm_expr` 1047 (55 cases), `test_casm_lexer` 1005 (2 cases).
  Baseline SHA-256: `casm.prg`
  `c5e33808799b9479ed7bc7f9efe687f33ae26aec47e0159d9cbfabb15a2a0a8b`,
  `test_casm_expr.prg`
  `4e869fb2162b50d34a13b107eba4a117eae8a439f948130d37cef68bf03cd1eb`,
  `test_casm_lexer.prg`
  `9b9bdc12946e5dd4578d1566a732bc4c5ea73d7b395223a64fdf5744e04852a4`.
  Link caps confirmed from generated CMake configurations: production
  `$6000`, expression harness `$1000`; production base PRG is 20,542 bytes
  including its two-byte header (BSS is additionally link-cap-accounted but
  absent from the file). Contract audit: expression zero-page is exactly
  `$84-$87` and aliases diagnostic/opcode scratch, so WP68 allocates no new
  ZP; WP67's operator path saves five accumulator bytes plus JSR return
  addresses, so precedence recursion must restore before combining and the
  8-level paren bound remains a hard gate; unresolved resolver results have
  `RESOLVED` clear and may have `RELOCATABLE` set, so every new operator
  must reject unresolved input before reading value bytes. Prior WP67 live
  evidence remains the behavioral before-picture (55/55 expression and 2/2
  lexer cases PASS); WP68's fresh consolidated live rerun remains Increment
  9 rather than being claimed by this build-only baseline.
- 2026-08-14: **Atomic Increment 2 complete.** Added stable token IDs after
  `CASM_TOKEN_STAR` for `/`, `&`, `^`, `|`, `~`, `<<`, and `>>`, with
  contiguous compile-time assertions. `*` and `-` retain their existing
  contextual token IDs. Lexer `lnAngle` stamps the first byte's provenance,
  consumes a matching second `<`/`>` into `SHL`/`SHR`, and leaves a differing
  second lookahead buffered so lone extraction tokens are unchanged. Extended
  `test_casm_lexer` with an 11-token real-lexer fixture covering type, text
  length/content/terminator, adjacency, first-byte columns, and EOF. First
  build exposed one expected 6502 integration constraint: inserting the new
  block pushed `lnCommentBody`'s EOF branch to -129, one byte beyond relative
  range; root cause was code growth only, corrected with local conditional +
  absolute-JMP trampolines while preserving comment behavior. Final narrow
  builds and immediate no-change rebuild pass: CASM build 1298 (20,648-byte
  base code image, 3,236 relocation points) and lexer harness build 1008
  (2,357-byte base code image, 377 relocation points). The rebuilt
  `casm_include_test_d64` retains 179 free blocks. VICE 3.10 live attempt
  proved Command64 boot (`Command 64-DOS Version`) and `test_casm_lexer`
  dispatch, but both bounded post-launch observations still showed
  `LOADING...`; classified inconclusive rather than product failure and not
  polled further per workflow. Fresh live PASS remains required in Increment
  9. DOX updated in `src/external/casm/AGENTS.md` for the durable token ABI.
- 2026-08-14: **Atomic Increment 3 stopped at its approved envelope gate,
  pending user direction.** Implemented the minimum-precedence recursion
  contract with stable precedence constants and only the existing `+`/`-`
  tier classified; tighter RHS recursion (`precedence + 1`) preserves left
  associativity, and all not-yet-enabled WP68 tokens are caught by
  `rejectContinuation`. Narrow `test_casm_expr` build 1049 and production
  CASM build 1299 link successfully (3,640-byte and 20,746-byte base code
  payloads respectively). The first build exposed two forward branches in
  the enlarged classifier beyond the 6502 relative range; RCA was code
  distance only, corrected with absolute-JMP exits. Packaging
  `test_image_d64` then failed because whole-linking `test_casm_pass1`
  overflowed its approved `$5500` MAIN cap by 130 bytes. Per Stop Conditions,
  no cap was changed and no VICE result is claimed. The smallest round-page
  cap that fits the measured overflow is `$5600` (+256, leaving 126 bytes at
  the current link); explicit user approval is required before that CMake
  edit and before Increment 3 can resume.
- 2026-08-14: User approved the measured `test_casm_pass1` cap increase
  `$5500` -> `$5600`; CMake records the 130-byte overflow and smallest
  round-page fit. **Atomic Increment 3 complete.** `test_image_d64` now
  builds successfully (12 free blocks), and an immediate narrow no-change
  rebuild of `test_casm_expr`, `casm`, and `test_casm_pass1` changed no
  counters/artifacts. Live VICE 3.10 verification booted `build/test.d64`,
  proved `Command 64-DOS Version`, and ran `test_casm_expr` build 1049. The
  first launch used ASCII `_`, displayed left arrows, and correctly produced
  `BAD COMMAND OR FILE NAME`; this was a setup failure, cleared with `flush`.
  Retrying with exact PETSCII `$A4` underscores produced 55 dots,
  `CASM EXPR: PASS`, and normal return to `c64[8]:>`. Thus every pre-WP68
  expression fixture remains behaviorally identical under the new
  minimum-precedence control flow. DOX updated for the durable precedence
  ordering/left-associativity contract. VICE remains running as required.
- 2026-08-14: **Atomic Increment 4 stopped at its approved envelope gate,
  pending user direction.** Implemented static-only `&`, `^`, `|`, unary
  `~`, and two's-complement unary `-`; unary chains recurse right-to-left,
  unresolved static operands propagate with `RESOLVED` clear without reading
  placeholder values, and relocatable unary/bitwise operands raise
  `CASM_DIAG_EXPR_RELOC_UNSUPPORTED`. Production CASM build 1300 links with
  a 21,046-byte base code image. Added nine focused expression fixtures
  (`CASE_COUNT` 55 -> 64) covering each operator, `&`-before-`|` precedence,
  unary chaining, relocation rejection, and unresolved-static propagation.
  Their first link measured `test_casm_expr` 161 bytes beyond its approved
  `$1000` MAIN cap. Per Stop Conditions, no cap changed and no runtime result
  is claimed. `$1100` is the smallest round-page fit (+256, 95 bytes current
  projected headroom); explicit user approval is required before resuming.
- 2026-08-14: User approved `test_casm_expr` `$1000` -> `$1100`; CMake
  records the measured 161-byte overflow and smallest round-page fit. The
  64-case harness and CASM now link (expression base image 4,257 bytes;
  production unchanged at 21,046 bytes). `test_image_d64` then reached the
  next Stop Condition: shared evaluator growth puts whole-linking
  `test_casm_pass1` 175 bytes beyond its approved `$5600` MAIN cap. No
  second cap was changed. `$5700` is the smallest round-page fit (+256,
  81 bytes projected headroom); explicit approval is required before
  Increment 4 resumes and before live behavior is claimed.
- 2026-08-14: User approved `test_casm_pass1` `$5600` -> `$5700`; CMake
  records the measured 175-byte overflow and smallest round-page fit.
  **Atomic Increment 4 complete.** Full `test_image_d64` builds with 6 free
  blocks. Live VICE 3.10 booted the rebuilt image, proved the Command64
  banner, and launched `test_casm_expr` with exact PETSCII `$A4`
  underscores: all 64 dots printed, `CASM EXPR: PASS`, and normal return to
  `c64[8]:>`. Immediate no-change rebuild of `test_casm_expr`, `casm`, and
  `test_casm_pass1` changed no counters/artifacts. Production CASM remains
  build 1300 (21,046-byte base code image, 3,307 relocation points);
  expression harness build 1052 (4,257-byte base image, 505 relocation
  points). DOX updated with static-only bitwise, right-to-left unary, and
  unresolved-propagation contracts. VICE remains healthy and running.
- 2026-08-14: **Atomic Increment 5 stopped at its approved envelope gate,
  pending user direction.** Implemented static-only `<<`/`>>` at the frozen
  shift precedence: counts 0-15 only; checked left shift rejects any
  discarded high bit; right shift is logical and zero-filling; unresolved
  operands propagate without value access; relocation rejection reuses the
  Increment 4 path. Added seven cases (`CASE_COUNT` 64 -> 71) for left/right,
  count 0, count 16, overflow, precedence, and relocation. First assembly
  found two long unresolved-result branches after code growth; RCA was branch
  distance only and local inverse-branch/absolute-JMP exits preserve behavior.
  The resulting link measured `test_casm_expr` 225 bytes beyond `$1100`.
  No cap changed and no runtime result is claimed. `$1200` is the smallest
  round-page fit (+256, 31 bytes projected headroom); explicit approval is
  required before Increment 5 resumes.
- 2026-08-14: User approved `test_casm_expr` `$1100` -> `$1200`, but the
  relink exposed a second-stage envelope fact: ld65's original `$1100`
  failure reported RODATA's 225-byte overflow before BSS could be fully
  placed. At `$1200`, RODATA fits and ld65 then reports BSS extending 55
  bytes beyond MAIN. No source changed between measurements; this is staged
  segment reporting, not new growth. The earlier 31-byte projection is
  superseded. True total use requires `$1237`, so `$1300` is the smallest
  round-page fit (+256 from `$1200`, 201 bytes projected headroom). The
  approved `$1200` edit remains recorded but does not fit; no further cap
  change was made. Increment 5 remains stopped pending explicit approval.
- 2026-08-14: User approved the corrected `test_casm_expr` `$1200` ->
  `$1300`; the 71-case harness now links (4,577-byte base code image, 529
  relocation points), and production CASM build 1301 links (21,129-byte
  base code image, 3,320 relocation points). Full `test_image_d64` packaging
  then reached the next Stop Condition: `test_casm_pass1` exceeds its
  approved `$5700` MAIN cap by exactly 2 bytes. No cap changed. `$5800` is
  the smallest round-page fit (+256, 254 bytes projected headroom); explicit
  approval is required before Increment 5 resumes and live verification runs.
- 2026-08-14: User approved `test_casm_pass1` `$5700` -> `$5800`; CMake
  records the measured 2-byte overflow and smallest round-page fit.
  **Atomic Increment 5 complete.** Full `test_image_d64` builds with 3 free
  blocks. Live VICE 3.10 booted the rebuilt image, proved the Command64
  banner, and launched `test_casm_expr` with exact PETSCII `$A4`
  underscores: all 71 dots printed, `CASM EXPR: PASS`, and normal return to
  `c64[8]:>`. Immediate no-change rebuild of `test_casm_expr`, `casm`, and
  `test_casm_pass1` changed no counters/artifacts. Final Increment 5 builds:
  CASM 1301 (21,129-byte base code image, 3,320 relocation points),
  expression harness 1054 (4,577-byte base code image, 529 relocation
  points). DOX updated with the shift-count/overflow/logical-right contracts.
  VICE remains healthy and running.
- 2026-08-14: User requested a detailed plan before Increment 6. User
  directed creation of a new disk for Increment 6 and potentially later
  increments rather than continuing to consume `test.d64`'s final 3 blocks.
  Drafted subordinate proposed plan
  `brain/plans/2026-08-14-casm-phase12-wp68-increment6-multiply-divide.md`
  with `casm_phase12_test.d64` as the durable self-bootable Phase 12 image.
  No Increment 6 implementation is authorized until that detailed plan is
  explicitly approved.
- 2026-08-14: User approved the detailed Increment 6 plan. Atomic Step 1
  added and built self-bootable `casm_phase12_test.d64` with the four initial
  artifacts and 470 free blocks; no-change rebuild stable. No evaluator
  source change or existing-harness move occurred in this step. Detailed
  evidence remains in the subordinate plan.
- 2026-08-15: Atomic Step 2 complete. `test_casm_expr` moved off `test.d64`
  onto `casm_phase12_test.d64` (still 470 free blocks); `test.d64` recovered
  to 26 free blocks (from 3). No-change rebuild stable across both images.
  Detailed evidence remains in the subordinate plan.
- 2026-08-15: Atomic Step 3 complete. Added `*`/`/` classifier rows to
  `parseOperatorTail` (routing to `CASM_EXPR_PREC_MULDIV`) and an explicit
  `staticMulDivTemp` stub in `combineStatic` that deliberately fails with
  `CASM_DIAG_EXPR_UNSUPPORTED` rather than silently falling through into the
  `CASM_TOKEN_PIPE` handler. Two temporary harness cases (`2*3`, `2/3`,
  `CASE_COUNT` 71 -> 73) proved the dispatch reaches the deliberate stub, not
  an existing operator. Production and expression-harness builds link within
  cap; `test_casm_pass1` links within its `$5800` cap. Live VICE 3.10 rerun
  of the relocated `test_casm_expr` from `casm_phase12_test.d64` (typed via
  PETSCII bytes `$41-$5A` for lowercase letters and `$A4` for underscores)
  printed all 73 dots, `CASM EXPR: PASS`, and returned normally to
  `c64[8]:>` -- confirming the 71 pre-existing cases are unchanged and the
  two new temporary cases behave as designed. No-change rebuild confirmed
  stable. Detailed evidence remains in the subordinate plan.
- 2026-08-15: Atomic Step 4 complete. Implemented `mulUnsigned16` (checked
  unsigned 16x16->16 shift/add multiply, 6 bytes of new private BSS) and
  wired `*` to it via `combineStatic`'s new `staticMul`; `/` remains the
  Step 3 placeholder pending Atomic Step 6. Added the full multiply boundary
  matrix (identities, exact `$FFFF` boundary, two overflow cases;
  `CASE_COUNT` 73 -> 79). `test_casm_expr` overflowed its `$1300` cap by 119
  measured bytes; user approved `$1300` -> `$1400` (smallest round-page
  fit). All narrow builds link within cap; no-change rebuild stable. Live
  VICE 3.10 rerun printed all 79 dots, `CASM EXPR: PASS`, and returned
  normally to `c64[8]:>`. Detailed evidence remains in the subordinate plan.
- 2026-08-15: Atomic Step 5 complete. Activated `CASM_DIAG_EXPR_DIV_ZERO`
  ($44) with its message text and source-located dispatch in
  `diagnostics.s`; `expr.s`'s `staticDiv` now runs a real, permanent
  divisor-zero check ahead of the still-missing division loop (Atomic Step
  6). Production `casm` overflowed its `$6000` cap by 41 measured bytes;
  user approved `$6000` -> `$6100` (smallest round-page fit). Added
  `sDivZero` (`CASE_COUNT` 79 -> 80) plus a minimal production fixture
  (`casmdivzero.seq`, `.WORD 2/0`) proving the message routes correctly
  through the real `casm.prg` binary. All narrow builds link within cap;
  no-change rebuild stable. Live VICE 3.10 verification confirmed both the
  harness (80/80 dots, PASS) and the production fixture (exact message
  `CASM: EXPRESSION DIVISION BY ZERO` with correct source location, echoed
  line, and caret). Detailed evidence remains in the subordinate plan.
- 2026-08-15: Atomic Step 6 complete. Implemented `divUnsigned16` (bounded
  unsigned restoring binary long division, 16 iterations, 7 bytes of new
  private BSS -- 13 total with multiply, at the plan's ceiling) and wired it
  into `staticDivNonzero`. Added the divide boundary matrix (identities,
  truncation, wide truncation; `CASE_COUNT` 80 -> 86). Envelope work
  required three approved cap bumps for this step's own targets
  (`test_casm_expr` `$1400` -> `$1600` across two staged-segment
  corrections; `test_casm_pass1` `$5800` -> `$5900`), plus discovery and
  disclosure of a genuinely pre-existing defect: `test_casm_passcheck`,
  `test_casm_frame`, and `test_casm_listcap` had all silently drifted over
  their own caps since WP67, never rebuilt during WP68 Increments 3-5. User
  approved fixing all three inline with the same mechanical cap-bump
  pattern. All six affected targets now link within cap; no-change rebuild
  stable; live VICE 3.10 rerun printed all 86 dots, `CASM EXPR: PASS`, and
  returned normally to `c64[8]:>`. Detailed evidence remains in the
  subordinate plan.
- 2026-08-15: Atomic Step 7 complete. Added 11 cases covering left
  associativity, same-tier ordering, cross-tier precedence, current-address
  context (both roles of `*` in one expression), unary interaction,
  relocation rejection, and unresolved propagation (`CASE_COUNT` 86 -> 97).
  Disclosed and substituted one planned case: the plan's own illustrative
  `-2*3 = $FFFA` is arithmetically unreachable under the frozen unsigned
  checked-multiply semantics (it actually overflows); user approved `-1*1 =
  $FFFF` instead. `test_casm_expr` overflowed its `$1600` cap by 98 bytes;
  user approved `$1600` -> `$1700`. Production `casm` unaffected
  (test-only additions). No-change rebuild stable; live VICE 3.10 rerun
  printed all 97 dots, `CASM EXPR: PASS`, and returned normally to
  `c64[8]:>`. Detailed evidence remains in the subordinate plan.
- 2026-08-15: Atomic Step 8 complete. Full affected-target build and
  envelope inspection across `casm` and all six affected test harnesses
  (`test_casm_expr`/`pass1`/`passcheck`/`frame`/`listcap`/`lexer`) -- all
  link cleanly within their approved caps with healthy headroom. Every
  disk image touching an affected target (`casm_phase12_test_d64`,
  `test_image_d64`, `casm_listing_test_d64`, `image_d64`) builds cleanly.
  SHA-256 comparison across all seven PRGs and four disk images,
  before/after a full rebuild of every one of them, showed zero changed
  bytes -- comprehensive no-change rebuild stability confirmed. Detailed
  evidence remains in the subordinate plan.
- 2026-08-15: Increment 6 (WP68 Atomic Increments 4-6) committed
  (`a24a42c`). Drafted a detailed subordinate plan for Atomic Increment 7
  (relocation, unresolved, and parser integration):
  `brain/plans/2026-08-15-casm-phase12-wp68-increment7-parser-integration.md`.
  User confirmed all three Scoping Decisions (representative operators per
  family; fixtures packaged on `casm_phase12_test_d64`; end-to-end-only
  width-agreement proof) and approved the plan as a whole. Implementation
  begins with Atomic Step 1 (resolver-flag audit).
- 2026-08-15: Atomic Step 9 complete -- **Increment 6 (WP68 Atomic
  Increments 4-6: multiply, division-by-zero, division) fully closed**, all
  nine of its own Atomic Steps done and its Completion Gate satisfied. Final
  live VICE 3.10 rerun: `test_casm_expr` (all 97 dots, PASS) and
  `test_casm_lexer` (3 dots, PASS, confirming no regression from this
  increment's shared disk-image rebuild), both returning normally to
  `c64[8]:>`. VICE left healthy and running. Detailed evidence remains in
  the subordinate plan. Awaiting explicit user approval to proceed to
  Atomic Increment 7 (relocation, unresolved, and parser integration).
- 2026-08-15: **Atomic Increment 7 complete.** Added four production
  parser-integration fixtures on `casm_phase12_test_d64`
  (`casmarith2`/`casmarithfwd`, COMP-verified against hand-derived
  references; `casmareloc1`/`casmareloc2`, forbidden-form diagnostic
  fixtures). Live VICE confirmed all four behave exactly as designed,
  including a genuine two-pass Pass 1/Pass 2 FORCE_ABS width-agreement
  proof for a forward-referenced named constant combined with a WP68
  operator -- the same property `casmfa2p.ref.hex` established for a bare
  label (WP61 Increment 4), now proven for the new operators.

  Live testing surfaced and fixed a real, in-scope WP68 gap, disclosed and
  user-approved before touching source: `parser.s`'s instruction-operand
  dispatch (two token-type whitelists) never added `CASM_TOKEN_MINUS`/
  `CASM_TOKEN_TILDE`, so `LDA #-1`-shaped operand forms failed
  `CASM: SYNTAX ERROR` -- the identical bug class WP67 already fixed once
  for a leading `(`. Also fixed, by user approval, a related pre-existing
  WP66-era gap in the same whitelists (`CASM_TOKEN_STAR`/current-address).
  A second live finding (`LDA #-1` then failing `OPERAND OUT OF RANGE`) was
  correctly diagnosed as expected behavior, not a defect -- unary `-`
  always yields a full 16-bit result, which cannot fit an 8-bit immediate
  by design -- and resolved by correcting the fixture, not the source.

  Full affected-target build/envelope inspection and no-change rebuild both
  passed. Detailed evidence, including the exact diagnostics/locations and
  hand-derived reference bytes, is recorded in the subordinate plan:
  `brain/plans/2026-08-15-casm-phase12-wp68-increment7-parser-integration.md`.
- 2026-08-15: **Atomic Increment 8 complete.** Drafted a detailed
  subordinate plan
  (`brain/plans/2026-08-15-casm-phase12-wp68-increment8-harness-envelope-verification.md`)
  scoping Increment 8 as consolidation-only, per Increment 7's own
  forward-reference to it; user approved. Atomic Step 1's audit (WP64's
  frozen 9-operator inventory against the current `casm_lexer`/`casm_expr`/
  `casm_pass1`/`casm_passcheck` case tables) found every operator,
  precedence tier, boundary/overflow case, relocation-rejection case, and
  unresolved-reference case already covered by a prior increment's own
  harness additions -- no new test case needed.

  Consolidated build/envelope measurement, full clean rebuild
  (`build/` removed and reconfigured) of every affected target and disk
  image:

  | Target | Code bytes | Cap | Headroom |
  | --- | --- | --- | --- |
  | `casm` | 21,481 | `$6100` (24,832) | 3,351 |
  | `test_casm_lexer` | 2,357 | `$1000` (4,096) | 1,739 |
  | `test_casm_expr` | 5,730 | `$1700` (5,888) | 158 |
  | `test_casm_pass1` | 20,027 | `$5900` (22,784) | 2,757 |
  | `test_casm_passcheck` | 19,079 | `$5B00` (23,296) | 4,217 |
  | `test_casm_frame` | 19,868 | `$5900` (22,784) | 2,916 |
  | `test_casm_listcap` | 20,947 | `$5D00` (23,808) | 2,861 |

  | Disk image | Free blocks | Gate |
  | --- | --- | --- |
  | `image_d64` | 318 | unaffected (general OS release image) |
  | `test_image_d64` | 21 | unchanged from Increment 7 |
  | `casm_listing_test_d64` | 11 | unchanged from Increment 7 |
  | `casm_phase12_test_d64` | 452 | >=40 |

  No production source, harness, or build-system file required any change.
  No-change rebuild proof: SHA-256 of all seven PRGs and four disk images,
  before and after an immediate second full rebuild of every one of them,
  identical byte-for-byte. Note: the parent plan's own Increment 8 charter
  text cites a stale `$6000` production cap; the real, current, WP68
  Increment-6-approved cap is `$6100`, confirmed held above with 3,351
  bytes of headroom. Detailed evidence recorded in the subordinate plan.
  Awaiting explicit user approval to close Increment 8 and proceed to
  Atomic Increment 9 (live end-to-end verification).
- 2026-08-15: **Atomic Increment 9 complete -- WP68's own Atomic Steps are
  now all closed.** Drafted a detailed subordinate plan
  (`brain/plans/2026-08-15-casm-phase12-wp68-increment9-live-end-to-end.md`),
  user-approved, scoped around the one real gap left in live-verification
  coverage: `/`, `^`, `|`, `>>`, and `CASM_DIAG_EXPR_DIV_ZERO` had only
  ever been proven against the synthetic `test_casm_expr` harness, never
  through the real `casm.prg` production pipeline (unlike `*`, `&`, `<<`,
  unary `-`, and relocation rejection, already proven live in Increment 7).

  Added two fixtures to `casm_phase12_test_d64`: `casmarith3.seq`
  (division/XOR/OR/right-shift across immediate/`.BYTE`/`.WORD` contexts,
  including `$8001>>1 = $4000` proving the shift is logical/zero-filling
  through the real pipeline) and `casmdivzero.seq` (`LDA #5/0`, forbidden
  form). Full affected-target/disk-image rebuild and a no-change rebuild
  proof (SHA-256 identical) both passed before any live testing; disk
  landed at 449 free blocks (still comfortably above the `>=40` gate).

  Live VICE 3.10 verification: `casmarith3.s` -> `CASM: INPUT VALIDATED`,
  `comp carith3.prg casmarith3.ref` -> `FILES COMPARE OK`; `casmdivzero.s`
  -> `CASM: EXPRESSION DIVISION BY ZERO AT LINE 1, COL 9 (OFFSET 8)`,
  exactly as designed -- the first real end-to-end proof of
  `CASM_DIAG_EXPR_DIV_ZERO`, correcting `common.inc:770`'s own stale "not
  yet raised anywhere" comment. Both re-run harnesses confirmed no
  regression: `test_casm_expr` (`CASM EXPR: PASS`) and `test_casm_lexer`
  (`CASM LEXER: PASS`).

  One harness-only finding, disclosed here per this project's standard
  practice rather than silently worked around: several shell-dispatch
  attempts for `test_casm_expr`/`test_casm_lexer` returned spurious `BAD
  COMMAND OR FILE NAME` with a visibly garbled command echo (e.g.
  `test•casm•lexer`), even after `flush\n` and even when typed as a
  single `vice_keyboard_type` call with the verified underscore handling
  from `.agents/workflows/vice-mcp-testing.md`. Both harnesses ultimately
  ran cleanly (`CASM EXPR: PASS`, `CASM LEXER: PASS`) once retried with a
  fresh `flush\n` immediately before the command, with no production or
  fixture-source involvement -- classified as a VICE MCP
  keyboard-queue/timing harness issue, not a product defect, and not
  investigated further since it lies outside this increment's scope; the
  existing `flush`-based recovery in the mandatory workflow doc remains
  the correct and sufficient mitigation.

  Every WP64-frozen operator has now been proven at least once through
  the real production pipeline. No `src/external/casm/*.s` production
  source change was needed. VICE left healthy and running.

  All nine Atomic Increments of WP68 are now complete. WP68 itself is not
  yet closed: its own final close-out (`brain/KNOWLEDGE.md`,
  `wiki/casm-utility.md`/`docs/casm-utility.md`,
  `wiki/casm-programmers-reference.md`, `CHANGELOG.md`, stage-version
  bump, and a `brain/walkthroughs/` completion-gate doc) remains, per the
  phased-planning skill's closing checklist, before WP68 can be marked
  done.
- 2026-08-15: **WP68 final close-out complete (commit `50ac398`).** Added
  a `brain/KNOWLEDGE.md` as-built section; a new "Expressions and
  Operators" section in `wiki/casm-utility.md`/`docs/casm-utility.md`
  (kept byte-identical) documenting the full operator table, precedence,
  and semantics, removing the now-stale "multiplicative/parenthesized
  arithmetic not supported" bullet; extended
  `wiki/casm-programmers-reference.md`'s lexer/parser/evaluator sections
  for the new tokens and operators, plus a diagnostic-reference table
  extension for `$43`-`$46` (previously entirely missing from that table
  since WP65); a `CHANGELOG.md` entry; and promoted CASM `0.2.2` →
  `0.2.3` (`VERSION_STAGE` in `casm.s`), live-verified on the real banner
  (`CASM V0.2.3.1308`) with `casm.prg` unchanged in size and every other
  artifact byte-identical in a no-change rebuild. Walkthrough with
  consolidated live evidence:
  `brain/walkthroughs/2026-08-15-casm-phase12-wp68-arithmetic-bitwise-
  operators.md`.

  **WP68 complete, user-approved 2026-08-15.** Taskwarrior task 43
  (`c1b8e145-0a9c-4e15-aaab-4e82fc253363`) marked done; `brain/task.md`
  and `wiki/tasks/casm.md` finalized. Phase 12 itself remains open (WP69,
  character literals, still pending — see WP64's own contract freeze).
