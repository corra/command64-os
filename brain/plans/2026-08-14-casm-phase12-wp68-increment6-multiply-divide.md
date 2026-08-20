---
feature: casm-phase12-wp68-increment6-multiply-divide
created: 2026-08-14
status: approved
taskwarrior: c1b8e145-0a9c-4e15-aaab-4e82fc253363 (WP68)
depends-on: WP68 Atomic Increment 5, complete
---

# Plan: CASM Phase 12 WP68 Increment 6 - Multiplication and Division

## Status

**Approved 2026-08-14.** This is the detailed execution plan for Atomic
Increment 6 of the already-approved WP68 parent plan:
`brain/plans/2026-08-14-casm-phase12-wp68-arithmetic-bitwise-operators.md`.
It refines, but does not widen, WP68's approved multiplication/division
scope. The user approved this plan as drafted; its Atomic Steps are now
authorized in order.

Prerequisite: WP68 Increment 5 is complete and live-verified. Current
baseline: CASM build 1301, `test_casm_expr` build 1054 with 71 passing cases,
production MAIN cap `$6000`, expression-harness cap `$1300`,
`test_casm_pass1` cap `$5800`, and `test.d64` with only 3 free blocks.

## Objective

Complete WP68's operator inventory by adding static-only unsigned 16-bit
multiplication (`*`) and division (`/`) at the existing
`CASM_EXPR_PREC_MULDIV` tier. Multiplication must detect any product above
`$FFFF`; division must return the unsigned quotient truncated toward zero
and raise `CASM_DIAG_EXPR_DIV_ZERO` for a zero divisor.

The increment also creates a self-bootable Phase 12 test disk,
`build/casm_phase12_test.d64`, so expression-focused growth no longer consumes
the final blocks of general-purpose `test.d64` and later Phase 12 increments
have an intentional home.

## Scoping Decisions (user-confirmed 2026-08-14)

1. WP68 uses unsigned 16-bit multiplication/division; multiplication is
   checked, division truncates toward zero, and unary negation remains the
   separate two's-complement operation already delivered in Increment 4.
2. Division by zero raises the WP64-reserved stable diagnostic
   `CASM_DIAG_EXPR_DIV_ZERO` (`$44`).
3. Modulo is excluded; no `%` operator or remainder result is added.
4. Named-constant RHS grammar remains unchanged; `ppsConstant` does not call
   the production expression evaluator.
5. **A new disk is required for Increment 6 and potentially later Phase 12
   increments.** The proposed durable artifact is
   `build/casm_phase12_test.d64`, not an Increment 6-specific image.

## Inherited Contracts

- Precedence remains unary, multiply/divide, shifts, AND, XOR, OR,
  addition/subtraction from highest to lowest; all binary operators remain
  left-associative.
- `*` is contextual: primary position means current address; infix position
  means multiplication. Its existing `CASM_TOKEN_STAR` ID does not change.
- `/` uses `CASM_TOKEN_SLASH` from Increment 2.
- Both operands must be static. Either operand carrying
  `CASM_EXPR_FLAG_RELOCATABLE` raises
  `CASM_DIAG_EXPR_RELOC_UNSUPPORTED` before arithmetic.
- If either operand is unresolved in Pass 1, the result propagates with
  `RESOLVED` clear and no placeholder value byte is read. Pass 2 computes the
  operation only after both operands resolve.
- Expression zero-page remains exactly `$84-$87`; Increment 6 allocates no
  additional zero-page bytes.
- The expression record, resolver ABI, token record, diagnostic numbers, and
  8-level parenthesis bound remain unchanged.

## Multiplication Algorithm

Use a fixed-capacity unsigned shift/add multiply with at most 16 iterations.
The left operand is copied to a private 16-bit multiplicand, the right operand
to a private 16-bit multiplier, and the result starts at zero.

For each multiplier bit:

1. If multiplier bit 0 is set, add the multiplicand to the result with
   `CLC`/`ADC` low then high; carry from the high-byte addition is overflow.
2. Shift the multiplier right logically.
3. If the multiplier is now zero, return early; no further multiplicand shift
   is needed and a high bit in the unused multiplicand is irrelevant.
4. Shift the multiplicand left. Carry out of its high byte is overflow because
   at least one remaining multiplier bit may consume that shifted value.
5. Repeat, bounded by 16 iterations even though the zero-multiplier early-out
   normally finishes sooner.

The ordering above is load-bearing: checking multiplier-zero before shifting
the multiplicand prevents false overflow for valid products such as
`$8000*1`. Checked-add and checked-shift paths both return
`CASM_DIAG_EXPR_OVERFLOW`; no wrapped partial product is committed to the
expression record.

Boundary semantics:

| Expression | Result |
| --- | --- |
| `0*$FFFF` | `$0000` |
| `$FFFF*0` | `$0000` |
| `$FFFF*1` | `$FFFF` |
| `$00FF*$0101` | `$FFFF` |
| `$0100*$0100` | overflow |
| `$FFFF*2` | overflow |

## Division Algorithm

Use bounded unsigned restoring binary long division with 16 iterations. Keep
a 16-bit dividend/quotient, a 16-bit divisor, and a 17-bit-capable remainder
representation. The implementation may encode the remainder's 17th bit as a
separate private BSS byte; it must not rely on carry surviving subroutine calls.

For each of 16 input bits, most significant first:

1. Shift the next dividend bit into the remainder.
2. Compare the 17-bit remainder with the 16-bit divisor.
3. If remainder is at least divisor, subtract divisor and set the new quotient
   bit; otherwise leave the quotient bit clear.
4. Continue exactly 16 times.

Check the divisor for zero before entering the loop. On zero, call
`diagSetLocFromToken`, return `CASM_DIAG_EXPR_DIV_ZERO` with carry set, and do
not commit a quotient. The remainder is private scratch and is discarded.

Boundary semantics:

| Expression | Result |
| --- | --- |
| `0/1` | `$0000` |
| `$FFFF/1` | `$FFFF` |
| `$FFFF/$FFFF` | `$0001` |
| `$FFFF/$0100` | `$00FF` |
| `7/2` | `$0003` |
| `1/2` | `$0000` |
| `1/0` | `CASM_DIAG_EXPR_DIV_ZERO` |

## Evaluator Integration

Extend `parseOperatorTail`'s classifier with:

- `CASM_TOKEN_STAR` -> `CASM_EXPR_PREC_MULDIV`
- `CASM_TOKEN_SLASH` -> `CASM_EXPR_PREC_MULDIV`

No parser-control-flow rewrite is planned. Increment 3's saved token,
saved precedence, RHS-at-`precedence+1`, and left-associative loop remain the
single operator path. `combineStatic` dispatches `*` and `/` only after its
existing resolved/static checks, so relocation and unresolved behavior are
shared rather than duplicated.

On arithmetic success, write the 16-bit result to
`CasmExprResultRecord.VAL_LO/HI`, preserve combined
`SYMBOL_DERIVED` provenance, keep `RELOCATABLE` clear, and leave existing
top-level extraction behavior unchanged. `ADDEND_*` remains untouched by
multiply/divide, matching the bitwise/shift convention.

## Scratch and Routine Contracts

Add only private `expr.s` BSS scratch, expected maximum 13 bytes:

| Scratch | Bytes | Purpose |
| --- | ---: | --- |
| multiplicand | 2 | Checked multiply shifting operand |
| multiplier | 2 | Checked multiply remaining bits |
| product | 2 | Checked multiply accumulator |
| divisor | 2 | Division divisor |
| quotient/dividend | 2 | Division input and output bit stream |
| remainder | 2 | Division remainder low/high |
| remainder extension/counter | 1 | 17th bit or bounded loop counter; reuse only if lifetimes are disjoint |

The implementation should reuse bytes whose multiply/divide lifetimes are
mutually exclusive, so 13 bytes is a ceiling rather than a target. Every
helper must document:

- input operand locations;
- output result location;
- carry-set diagnostic failure and carry-clear success;
- A/X/Y and N/Z/C clobbers;
- balanced hardware stack;
- private BSS and zero-page usage.

Helpers are private to `expr.s`; no new export or cross-module ABI is planned.

## Diagnostic Integration

Activate `CASM_DIAG_EXPR_DIV_ZERO` (`$44`) in `diagnostics.s` with exact text:

`EXPRESSION DIVISION BY ZERO`

It is source-located, matching relocation/parenthesis expression diagnostics:
print the message and call `diagPrintSourceContext`. Keep numbering assertions
unchanged and add a message-table/dispatch assertion if the existing structure
supports one. Multiplication overflow continues using the existing
`EXPRESSION OVERFLOW` text.

## Phase 12 Test Disk

Create CMake target `casm_phase12_test_d64` producing
`build/casm_phase12_test.d64`.

Initial contents:

| Disk entry | Purpose |
| --- | --- |
| `command64` | Boot prerequisite |
| `casm` | Production end-to-end Phase 12 fixtures |
| `test_casm_expr` | Focused expression evaluator harness |
| `test_casm_lexer` | Operator tokenization regression |
| Phase 12 source fixtures | WP65-WP68 production syntax/runtime checks as capacity permits |

The disk must be self-bootable, use collision-safe <=16-character physical
names, and retain at least 40 free blocks after Increment 6 packaging so later
Phase 12 increments and runtime output files have explicit headroom. If the
initial content set cannot preserve 40 blocks, stop and reduce duplicated
fixtures or split the image; do not silently accept another near-full disk.

Remove `test_casm_expr` from `test.d64` once the new disk is verified. This is
a move, not duplicate permanent packaging: general `test.d64` recovers the
harness's blocks, while Phase 12 documentation identifies the new canonical
disk. `test_casm_pass1` remains on `test.d64` because it covers broader pass
integration and is not expression-only.

Use existing CMake D64 helper patterns. No standalone packaging script is
added. Because this adds a new CMake target invoking disk tooling, apply the
`cmake-overlay-events` skill/workflow before editing CMake.

## Verification Matrix

### Focused Expression Cases

Add at least these cases to `test_casm_expr`:

| Category | Cases |
| --- | --- |
| Multiply identities | `0*$FFFF`, `$FFFF*0`, `$FFFF*1`, `1*$FFFF` |
| Multiply exact boundary | `$00FF*$0101 = $FFFF` |
| Multiply overflow | `$0100*$0100`, `$FFFF*2` |
| Divide identities | `0/1`, `$FFFF/1`, `$FFFF/$FFFF` |
| Divide truncation | `7/2 = 3`, `1/2 = 0`, `$FFFF/$0100 = $00FF` |
| Divide error | `1/0` -> `$44`, exact diagnostic location/final token |
| Left associativity | `24/3/2 = 4`, not `24/(3/2)` |
| Same-tier ordering | `2*3/4 = 1` |
| Cross-tier precedence | `1+2*3 = 7`, `8>>1*2 = 2` |
| Current-address context | primary `*` remains current address; infix `2*3` multiplies |
| Unary interaction | `-2*3 = $FFFA`, `~0/2 = $7FFF` |
| Relocation rejection | `RELVAL*2`, `RELVAL/2` |
| Unresolved propagation | `UNABS*2`, `UNABS/2` remain unresolved without placeholder arithmetic |

Expected records must assert value, flags, resolver call count, final token,
and token ordinal/source column. Existing 71 cases remain byte/message/location
identical.

### Build Verification

1. Build `test_casm_expr` and `casm` narrowly.
2. Build `test_casm_pass1` because it whole-links `expr.s`.
3. Build `casm_phase12_test_d64` and inspect its directory/free blocks.
4. Build `test_image_d64` after moving `test_casm_expr`; confirm recovered
   capacity and no missing unrelated entries.
5. Inspect base PRG sizes and relocation counts.
6. Immediately repeat narrow builds; counters and SHA-256 hashes must remain
   unchanged.

### Live VICE Verification

Follow `.agents/workflows/vice-mcp-testing.md`:

1. Re-attach rebuilt `casm_phase12_test.d64` to unit 8.
2. Boot `command64`; prove row 0 decodes to `Command 64-DOS Version`.
3. Launch `test_casm_expr` using exact PETSCII `$A4` underscores.
4. Require every marker to be `.`, `CASM EXPR: PASS`, and normal
   `c64[8]:>` return.
5. Launch `test_casm_lexer`; require its PASS and normal return.
6. Production CASM end-to-end multiply/divide fixtures are deferred to
   Increment 9 unless Increment 6 adds a minimal source fixture solely to
   prove the new diagnostic dispatch. Do not duplicate Increment 9's full
   matrix here.
7. Leave healthy VICE running.

## Atomic Steps

1. Load the `cmake-overlay-events` skill and add the new Phase 12 D64 target,
   initially packaging current artifacts only; verify >=40 free blocks.
2. Move `test_casm_expr` packaging from `test.d64` to the new image; rebuild
   both images and verify directory contents/capacity.
3. Add `*`/`/` classifier rows only; before arithmetic helpers exist, confirm
   their dispatch reaches a deliberate temporary failure path rather than an
   existing operator accidentally.
4. Implement checked unsigned multiplication and its boundary cases.
5. Implement division-by-zero diagnostic dispatch and verify exact message
   routing in the narrow diagnostic surface.
6. Implement bounded unsigned division and quotient cases.
7. Add full precedence, associativity, unary, current-address-context,
   relocation, and unresolved cases.
8. Run narrow/full builds, inspect envelopes/relocations/disk capacity, and
   perform no-change rebuild proof.
9. Run focused live VICE harnesses from `casm_phase12_test.d64` and record
   evidence in the WP68 parent plan's append-only Progress log.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/expr.s` | Add `*`/`/` classification, private helpers, and bounded BSS scratch |
| `src/external/casm/diagnostics.s` | Add source-located division-by-zero message dispatch |
| `tests/src/casm_expr/casm_expr.s` | Add multiplication/division fixtures and expected records |
| `CMakeLists.txt` | Add `casm_phase12_test_d64`, move expression-harness packaging, and apply only measured caps |
| `cmake/*.cmake` | Modify only if existing D64 helper structure requires it; no new helper without overlay workflow review |
| `tests/AGENTS.md` | Record canonical Phase 12 disk and launch contract |
| `src/external/casm/AGENTS.md` | Record durable multiply/divide semantics after verification |
| Parent WP68 plan, `brain/task.md`, `wiki/tasks/casm.md` | Append implementation/progress evidence |

## Stop Conditions

- Multiplication produces a false overflow for a mathematically valid
  `$0000-$FFFF` product, or misses any product above `$FFFF`.
- Division needs unbounded/subtractive-by-divisor iteration rather than a
  fixed 16-step algorithm.
- Any path reads unresolved placeholder values.
- Any relocatable operand reaches arithmetic rather than the shared rejection
  path.
- Contextual `*` breaks either current-address primary or infix multiply.
- Existing 71 expression cases change result, diagnostic, final token, or
  location.
- New BSS scratch exceeds 13 bytes, requires new zero-page, or changes a
  public record/ABI.
- Production `$6000`, expression `$1300`, pass1 `$5800`, or another approved
  envelope is exceeded. Report measured usage and request direction; do not
  raise a cap silently.
- `casm_phase12_test.d64` has fewer than 40 free blocks after packaging, or
  moving `test_casm_expr` breaks `test_image_d64`'s required content.
- A no-change rebuild changes any artifact/build counter.
- Any unexpected harness failure or new out-of-scope defect is found. Perform
  RCA, disclose, and defer unless the user explicitly approves an inline
  deviation.

## Completion Gate

Increment 6 completes only when multiplication/division meet every approved
semantic and boundary case; all prior 71 expression cases remain unchanged;
division-by-zero prints the exact source-located diagnostic; narrow and full
builds pass within approved envelopes; the new Phase 12 disk is self-bootable
with at least 40 free blocks and is the canonical home of
`test_casm_expr`; `test.d64` builds after the move; no-change rebuilds are
stable; focused VICE harnesses pass and return normally; parent plan/task/DOX
records are synchronized; and the user approves proceeding to Increment 7.

## Progress

- 2026-08-14: User requested a detailed Increment 6 implementation plan.
  Identified that `test.d64` has only 3 free blocks before multiply/divide
  growth and asked whether to move expression testing or preserve placement.
- 2026-08-14: User directed creation of a new disk for Increment 6 and
  potentially later increments. Drafted `casm_phase12_test.d64` as a durable,
  self-bootable Phase 12 test artifact with >=40 free-block acceptance gate.
  No Increment 6 implementation has begun; awaiting explicit plan approval.
- 2026-08-14: **User approved this detailed Increment 6 plan as drafted.**
  Atomic Step 1 begins with the new disk target only; no evaluator source
  implementation or existing harness move begins in that step.
- 2026-08-14: **Atomic Step 1 complete.** Loaded the overlay workflow and
  confirmed `add_c64_disk_image` already provides the required conditional
  `C64_THEME_DIR` wrapper, so no direct external-tool command was added.
  Added `casm_phase12_test_d64` with `command64`, `casm`,
  `test_casm_expr`, and `test_casm_lexer`. The first build attempt correctly
  failed with "No rule to make target" because the existing build tree
  predated the new target; RCA was stale CMake generation, resolved with
  `cmake -S . -B build`. The target then built successfully with 470 free
  blocks, exceeding the >=40 gate by 430 blocks; immediate no-change rebuild
  ran no compile/link/package command. Updated `tests/AGENTS.md` for the
  durable disk contract. `test_casm_expr` remains on `test.d64` until Atomic
  Step 2 verifies the move independently.
- 2026-08-15: **Atomic Step 2 complete.** Added
  `list(REMOVE_ITEM TEST_IMAGE_PRG_TARGETS test_casm_expr)` to
  `CMakeLists.txt` following the same established pattern as prior
  `test_casm_lexer`/`test_casm_bounds`/etc. relocations, so `test_casm_expr`
  now packages only onto `casm_phase12_test.d64`. Regenerated CMake and
  rebuilt both images: `casm_phase12_test_d64` still shows 470 free blocks
  with its 4 entries (`command64`, `casm`, `test_casm_expr`,
  `test_casm_lexer`); `test_image_d64` builds cleanly with `test_casm_expr`
  absent from its directory listing and recovers to 26 free blocks (up from
  3). SHA-256 comparison across `casm.prg`, `test_casm_expr.prg`,
  `test_casm_lexer.prg`, `casm_phase12_test.d64`, and `test.d64` before and
  after an immediate rebuild of all five targets showed no change --
  no-change rebuild stability confirmed. No evaluator source was touched in
  this step.
- 2026-08-15: **Atomic Step 3 complete.** `parseOperatorTail`'s classify loop
  gained `CASM_TOKEN_STAR`/`CASM_TOKEN_SLASH` rows mapping to
  `CASM_EXPR_PREC_MULDIV` (a new `classifyMulDiv` label; `classifyShift`
  picked up an explicit `bne classified` since it is no longer the last
  entry). Primary-position `*` (current address) is unaffected because this
  classifier only runs after a primary has already been parsed. In
  `combineStatic`'s `staticBothResolved` dispatch, added explicit
  `CASM_TOKEN_STAR`/`CASM_TOKEN_SLASH` checks routing to a new
  `staticMulDivTemp` stub *before* the `CASM_TOKEN_PIPE` fallthrough --
  without it, an unclassified '*'/'/' token reaching this dispatch would
  have silently executed the OR handler instead of failing. The stub calls
  `diagSetLocFromToken` and fails with `CASM_DIAG_EXPR_UNSUPPORTED` (the same
  diagnostic `rejectContinuation` gave these tokens before this step), since
  no multiply/divide arithmetic exists yet. Relocation rejection for the new
  tokens needed no new code: `checkStaticReloc` already covers every
  non-`+`/`-` operator token generically.

  Added two temporary fixtures/cases to `test_casm_expr.s` (`sMulTemp`
  `2*3`, `sDivTemp` `2/3`, `CASE_COUNT` 71 -> 73) expecting
  `CASM_DIAG_EXPR_UNSUPPORTED`; Atomic Steps 4 and 6 will update these two
  cases' expected results in place once real multiply/divide arithmetic
  exists, rather than being replaced by new cases. Narrow builds link
  cleanly: production `casm` 21,158 code bytes (build 1302), `test_casm_expr`
  4,653 code bytes (build 1056), both within their `$6000`/`$1300` caps.
  `test_casm_pass1` (whole-links `expr.s`) also links within its `$5800`
  cap. `casm_phase12_test_d64` still reports 470 free blocks with its 4
  entries; `test_image_d64` builds with 25 free blocks (one less than Step
  2's 26, from `casm.prg`'s own growth on that disk -- expected, not an
  error). SHA-256 comparison across `casm.prg`, `test_casm_expr.prg`,
  `casm_phase12_test.d64`, and `test.d64` before/after an immediate rebuild
  of `casm`, `test_casm_expr`, `casm_phase12_test_d64`, and `test_image_d64`
  showed no change -- no-change rebuild stability confirmed.

  Live VICE 3.10 verification: attached the rebuilt `casm_phase12_test.d64`
  to unit 8 and hard-reset; screen memory decoded row 0 as
  `Command 64-DOS Version 0.4.1.2663`, confirming boot. First launch attempt
  used ASCII-range PETSCII bytes (`$61-$7A`) for the lowercase command name,
  which this charset renders as *uppercase* (the inverse of the naive
  assumption) -- it echoed as `TEST_CASM_EXPR` and correctly produced
  `bad command or file name`; recovered with `flush` (also mistakenly sent
  in the same wrong case at first, corrected immediately after). Retried
  with PETSCII bytes `$41-$5A` for the lowercase letters (this charset's
  actual lowercase range) and `$A4` for the underscores: screen memory
  confirmed the command echoed as lowercase `test_casm_expr`, followed by
  `loading...`, then 73 dots (40 + 33 across two rows, exactly matching
  `CASE_COUNT`), `CASM EXPR: PASS`, and a normal return to `c64[8]:>`. This
  is new, durable PETSCII-case evidence for typing lowercase Command64 shell
  commands via `vice_keyboard_petscii` and is worth carrying into session
  memory. VICE remains healthy and running.
- 2026-08-15: **Atomic Step 4 complete.** Added `mulUnsigned16`, a bounded
  unsigned 16x16->16 shift/add multiply with overflow detection on both the
  checked add and the checked multiplicand shift, using the
  multiplier-zero-before-shift ordering the plan specifies (verified against
  `$8000*1`: the early-out fires before the multiplicand's own left shift, so
  no false overflow). `combineStatic`'s dispatch split `staticMulDivTemp`
  into a real `staticMul` (calls `mulUnsigned16`, reuses the existing
  `staticOverflow` diagnostic path used by shifts) and `staticDivTemp`
  (unchanged placeholder, division stays deferred to Atomic Step 6). Added 6
  private BSS bytes (`CasmExprMulcandLo/Hi`, `CasmExprMulplierLo/Hi`,
  `CasmExprProductLo/Hi`), well under the plan's 13-byte ceiling and with 7
  bytes still available for division's own scratch in Step 6.

  Renamed `sMulTemp` to `sMul2x3` and updated its expectation from the
  temporary `CASM_DIAG_EXPR_UNSUPPORTED` to the real product (6); added the
  full multiply boundary matrix from the plan's Verification Matrix table
  (`0*$FFFF`, `$FFFF*0`, `$FFFF*1`, `1*$FFFF`, `$00FF*$0101=$FFFF` exact
  boundary, `$0100*$0100` and `$FFFF*2` overflow) -- `CASE_COUNT` 73 -> 79.
  `sDivTemp` (`2/3`) is untouched and still expects the temporary
  unsupported diagnostic.

  First `test_casm_expr` link overflowed the approved `$1300` cap by 119
  measured RODATA bytes. Per Stop Conditions, reported the measured overflow
  and requested direction rather than raising it silently; user approved
  `$1300` -> `$1400` (smallest round-page fit). At `$1400`,
  `test_casm_expr` links at 4,983 code bytes (build 1058); production `casm`
  links at 21,264 code bytes (build 1303, unaffected by the harness-only
  cap); `test_casm_pass1` (whole-links `expr.s`) links at 19,810 code bytes,
  comfortably within its `$5800` cap. `casm_phase12_test_d64` reports 467
  free blocks (4 entries); `test_image_d64` builds with 24 free blocks. A
  SHA-256 comparison across `casm.prg`, `test_casm_expr.prg`,
  `test_casm_pass1.prg`, `casm_phase12_test.d64`, and `test.d64` before/after
  an immediate rebuild of all five targets showed no change -- no-change
  rebuild stability confirmed.

  Live VICE 3.10 verification: reattached the rebuilt `casm_phase12_test.d64`
  to unit 8, autostarted `command64`, and dispatched `test_casm_expr` using
  the corrected PETSCII convention (`$41-$5A` for lowercase letters, `$A4`
  for underscores) confirmed in Atomic Step 3. Screen memory decoded the
  echoed command as lowercase `test_casm_expr`, `loading...`, then 79 dots
  (40 + 39 across two rows, exactly matching the new `CASE_COUNT`),
  `CASM EXPR: PASS`, and a normal return to `c64[8]:>`. VICE remains healthy
  and running.
- 2026-08-15: **Atomic Step 5 complete.** Activated `CASM_DIAG_EXPR_DIV_ZERO`
  ($44) in `diagnostics.s`: a new `dpfExprDivZero` dispatch case (matching
  `dpfExprRelocUnsupported`/`dpfExprParenTooDeep`'s source-located two-step
  print/`diagPrintSourceContext` shape) and `msgExprDivZero` = "CASM:
  EXPRESSION DIVISION BY ZERO". In `expr.s`, split `staticDivTemp` into
  `staticDiv` (an unconditional divisor-zero check that runs before any
  division arithmetic, per the plan's algorithm ordering) and
  `staticDivNonzero` (the still-temporary `CASM_DIAG_EXPR_UNSUPPORTED` stub
  for a nonzero divisor, pending Atomic Step 6's real division loop) -- so
  the zero-check is real and permanent independent of the missing loop.

  First build hit a 6502 branch-range error (`bcc staticFlags` in `staticMul`,
  now too far after `staticDiv`'s growth); fixed with a local `bcs` +
  absolute-`JMP` trampoline, same pattern used for earlier branch-range hits
  in this plan. Production `casm` then overflowed its `$6000` cap by 41
  measured BSS-placement bytes (new message text/dispatch code push BSS
  later in MAIN even though BSS itself didn't grow); per Stop Conditions,
  reported the measured overflow and requested direction -- user approved
  `$6000` -> `$6100` (smallest round-page fit).

  Added `sDivZero` (`2/0`, expecting `CASM_DIAG_EXPR_DIV_ZERO`) to
  `test_casm_expr.s` (`CASE_COUNT` 79 -> 80); all narrow builds link within
  cap (`casm` 21,333 code bytes build 1305 pre-cap-bump message code, final
  post-bump link clean; `test_casm_expr` 5,027 code bytes build 1060;
  `test_casm_pass1` 19,879 code bytes, within `$5800`). No-change rebuild
  confirmed stable across `casm.prg`, `test_casm_expr.prg`,
  `test_casm_pass1.prg`, `casm_phase12_test.d64`, and `test.d64`.

  Also added a minimal production fixture, `casmdivzero.seq`
  (`.ORG $C000` / `.WORD 2/0`), to `GenerateCasmTestFixtures.cmake` and
  `CASM_TEST_FIXTURES` (packaged onto `test.d64`, not `CASM_REF_NAMES` since
  it's meant to fail, matching `casmnumerrd`/`h`/`b`'s precedent) --
  per the Increment 6 plan's explicit allowance to prove the new diagnostic
  dispatch live without duplicating Increment 9's full production matrix.
  `test.d64` still builds cleanly (22 free blocks, down 1) with a confirmed
  no-change rebuild.

  Live VICE 3.10 verification, in two parts. First, the relocated
  `test_casm_expr` harness from `casm_phase12_test.d64` (dispatch via the
  established `$41-$5A`-for-lowercase/`$A4`-for-underscore PETSCII
  convention): all 80 dots, `CASM EXPR: PASS`, normal return. Second,
  `test.d64`'s new `casmdivzero.s` run through the real `casm.prg`
  (`casm casmdivzero.s`): screen memory decoded the exact message
  `CASM: EXPRESSION DIVISION BY ZERO`, followed by `AT LINE 2, COL 10
  (OFFSET 9)`, the echoed source line `.word 2/0` with a caret marker, and a
  normal return to `c64[8]:>` -- confirming the message text, dispatch
  routing, and source-location plumbing are all correct through the
  production binary, not just the harness's coded diagnostic-number
  assertion. VICE remains healthy and running.
- 2026-08-15: **Atomic Step 6 complete.** Added `divUnsigned16`, a bounded
  unsigned 16/16->16 restoring binary long division (16 iterations, standard
  wide-rotate technique across quotient:remainder:extension-bit), returning
  the truncated quotient only and discarding the remainder, per the plan's
  algorithm. `staticDivNonzero` now calls it unconditionally (always
  succeeds once reached, since `staticDiv` already rejected a zero divisor
  in Atomic Step 5). Added 7 private BSS bytes (`CasmExprDivisorLo/Hi`,
  `CasmExprQuotientLo/Hi`, `CasmExprRemainderLo/Hi`, `CasmExprRemainderExt`),
  bringing multiply+divide scratch to exactly the plan's 13-byte ceiling.

  Renamed `sDivTemp`'s role from placeholder to real (`2/3` now asserts its
  actual truncated quotient, 0) and added the divide boundary matrix from
  the plan's Verification Matrix (`0/1`, `$FFFF/1`, `$FFFF/$FFFF` identities;
  `7/2=3`, `1/2=0` truncation; `$FFFF/$0100=$00FF` wide truncation) --
  `CASE_COUNT` 80 -> 86.

  Envelope work took three rounds. First, `test_casm_expr` overflowed its
  `$1400` cap by 240 bytes (approved `$1400` -> `$1500`); at `$1500` the
  same staged-segment-reporting behavior as Increment 5 recurred -- RODATA
  fit but BSS then extended 83 bytes beyond MAIN, true total `$1583`, so
  `$1500` -> `$1600` was the corrected fit (both approved). Second,
  `test_casm_pass1` overflowed its `$5800` cap by 87 bytes; approved `$5800`
  -> `$5900`.

  Third, and more significant: building `test_casm_passcheck` (which shares
  `casm_pass1`'s exact whole-object source list) surfaced a genuinely
  pre-existing defect outside this step's own scope -- its `$5100` cap had
  never been bumped alongside `casm_pass1`'s own three WP68 increment bumps
  (Increments 3/4/5, +130/+175/+2 bytes), because no narrow WP68 build had
  rebuilt that specific target since WP67. It overflowed by 924 measured
  bytes. The same audit found two more harnesses sharing this exact gap:
  `test_casm_frame` (774 bytes over its `$5500` cap) and `test_casm_listcap`
  (698 bytes over its `$5A00` cap) -- both also last bumped at WP67 and
  never touched since. Per Stop Conditions, disclosed all three as a
  pre-existing latent defect rather than silently fixing them; user approved
  fixing inline as the same mechanical cap-bump pattern used everywhere else
  in this plan: `test_casm_passcheck` `$5100` -> `$5B00` (+2560),
  `test_casm_frame` `$5500` -> `$5900` (+1024), `test_casm_listcap` `$5A00`
  -> `$5D00` (+768) -- all smallest round-page fits for their measured
  overflows.

  All six affected targets (`casm`, `test_casm_expr`, `test_casm_pass1`,
  `test_casm_passcheck`, `test_casm_frame`, `test_casm_listcap`) now link
  cleanly: `casm` 21,457 code bytes (build 1306, unchanged since Atomic Step
  5's cap-triggering rebuild); `test_casm_expr` 5,360 code bytes (build
  1062); `test_casm_pass1` 20,003; `test_casm_passcheck` 19,055;
  `test_casm_frame` 19,844; `test_casm_listcap` 20,923.
  `casm_phase12_test_d64` builds with 464 free blocks (4 entries);
  `test_image_d64` builds with 21 free blocks. A SHA-256 comparison across
  all six PRGs plus both disk images before/after an immediate rebuild of
  every one of them showed no change -- no-change rebuild stability
  confirmed.

  Live VICE 3.10 verification: reattached the rebuilt `casm_phase12_test.d64`
  to unit 8, autostarted `command64`, and dispatched `test_casm_expr` via the
  established PETSCII convention. Screen memory decoded all 86 dots (40, 40,
  and 6 across three rows, exactly matching the new `CASE_COUNT`), `CASM
  EXPR: PASS`, and a normal return to `c64[8]:>`. VICE remains healthy and
  running.
- 2026-08-15: **Atomic Step 7 complete.** Added 11 fixtures covering the
  plan's remaining Verification Matrix categories: left associativity
  (`24/3/2 = 4`), same-tier ordering (`2*3/4 = 1`), cross-tier precedence
  (`1+2*3 = 7`, `8>>1*2 = 2`), current-address context (`* * 2` -- both a
  primary-position current-address read and an unambiguously infix multiply
  in one expression, `$4050*2 = $80A0`), unary interaction (`~0/2 = $7FFF`),
  relocation rejection (`RELVAL*2`, `RELVAL/2`), and unresolved propagation
  (`UNABS*2`, `UNABS/2`, both reusing `eBitUnresolved`'s exact expected
  record since `combineStatic`'s `staticUnresolved` path runs identically
  before any per-operator dispatch). `CASE_COUNT` 86 -> 97.

  One planned case required a substitution, disclosed and user-approved
  before writing it: the plan's own illustrative `-2*3 = $FFFA` is
  arithmetically unreachable under the frozen unsigned checked-multiply
  semantics -- unary `-` recurses through `parsePrimary` alone (not the
  full operator chain), so `-2*3` evaluates as `$FFFE*3 = 196602`, which
  genuinely exceeds `$FFFF` and correctly raises `CASM_DIAG_EXPR_OVERFLOW`
  rather than producing `$FFFA` (only reachable via a signed multiply, which
  Scoping Decision 1 explicitly did not approve). Substituted `-1*1 =
  $FFFF*1 = $FFFF`, a real non-overflowing unary+multiply interaction
  reusing `eMulFFFF`'s own boundary value.

  `test_casm_expr` overflowed its `$1600` cap by 98 measured bytes; user
  approved `$1600` -> `$1700` (smallest round-page fit). Production `casm`
  is unaffected (test-only fixture additions): unchanged at 21,457 code
  bytes. `test_casm_expr` links at 5,730 code bytes (build 1063).
  `casm_phase12_test_d64` builds with 463 free blocks. A SHA-256 comparison
  across `casm.prg`, `test_casm_expr.prg`, and `casm_phase12_test.d64`
  before/after an immediate rebuild of all three showed no change --
  no-change rebuild stability confirmed.

  Live VICE 3.10 verification: reattached the rebuilt `casm_phase12_test.d64`
  to unit 8, autostarted `command64`, and dispatched `test_casm_expr` via the
  established PETSCII convention. Screen memory decoded all 97 dots (40, 40,
  and 17 across three rows, exactly matching the new `CASE_COUNT`), `CASM
  EXPR: PASS`, and a normal return to `c64[8]:>`. VICE remains healthy and
  running.
- 2026-08-15: **Atomic Step 8 complete.** Ran the full affected-target build
  and envelope inspection: `casm`, `test_casm_expr`, `test_casm_pass1`,
  `test_casm_passcheck`, `test_casm_frame`, `test_casm_listcap`, and
  `test_casm_lexer` all link cleanly within their approved caps, with
  comfortable headroom:

  | Target | Code bytes | Cap | Headroom | Relocations |
  | --- | ---: | ---: | ---: | ---: |
  | `casm` | 21,457 | `$6100` | 3,375 | 3,393 |
  | `test_casm_expr` | 5,730 | `$1700` | 158 | 648 |
  | `test_casm_pass1` | 20,003 | `$5900` | 2,781 | 3,049 |
  | `test_casm_passcheck` | 19,055 | `$5B00` | 4,241 | 2,911 |
  | `test_casm_frame` | 19,844 | `$5900` | 2,940 | 3,023 |
  | `test_casm_listcap` | 20,923 | `$5D00` | 2,885 | 3,182 |

  Every disk image this WP touches or that packages an affected target
  builds cleanly: `casm_phase12_test_d64` (463 free blocks, 4 entries),
  `test_image_d64` (21 free blocks), `casm_listing_test_d64` (13 free
  blocks, carries `test_casm_passcheck`/`test_casm_frame`/
  `test_casm_listcap`), and `image_d64` (the general OS release image, 318
  free blocks, confirmed unaffected). A SHA-256 comparison across all seven
  PRGs and all four disk images, before and after an immediate rebuild of
  every one of them, showed zero changed bytes -- full no-change rebuild
  stability confirmed across the complete affected set, not just this
  increment's own narrow targets.
- 2026-08-15: **Atomic Step 9 complete -- Increment 6 fully closed.**
  Reattached the rebuilt `casm_phase12_test.d64` to unit 8 and autostarted
  `command64`; screen memory decoded row 0 as
  `Command 64-DOS Version 0.4.1.2663`, confirming boot. Dispatched
  `test_casm_expr` via the established PETSCII convention: all 97 dots,
  `CASM EXPR: PASS`, normal return to `c64[8]:>`. Dispatched
  `test_casm_lexer` the same way: correct echo, `loading...`, 3 dots,
  `CASM LEXER: PASS`, and a normal return -- unaffected by this increment's
  own changes, confirming no regression from the shared disk-image rebuild.
  No production end-to-end multiply/divide fixture beyond
  `casmdivzero.seq` (Atomic Step 5's minimal diagnostic-routing proof) was
  added here, per the plan's own instruction not to duplicate WP68 parent
  Increment 9's full production matrix. VICE left healthy and running.

  All nine Atomic Steps of this subordinate plan are complete. Increment 6's
  own Completion Gate is satisfied: multiplication/division meet every
  approved semantic and boundary case; all prior expression cases remain
  byte/message/location-identical (verified incrementally at every step);
  division-by-zero prints the exact source-located diagnostic (Atomic Step
  5, live-verified against the real production binary); narrow and full
  builds pass within approved envelopes (Atomic Step 8); the durable
  `casm_phase12_test.d64` is self-bootable with well over 40 free blocks and
  is the canonical home of `test_casm_expr`; `test.d64` builds after the
  move; no-change rebuilds are stable; focused VICE harnesses pass and
  return normally; and this Progress log plus the parent WP68 plan's own
  Progress log are synchronized. Awaiting the user's explicit approval to
  mark Increment 6 (WP68 Atomic Increments 4-6 combined: multiply,
  division-by-zero, division) closed and proceed to WP68's own Atomic
  Increment 7.
