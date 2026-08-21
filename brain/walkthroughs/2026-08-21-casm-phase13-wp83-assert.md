# CASM Phase 13 WP83 .ASSERT Completion Gate

## Status

**Approved by the user on 2026-08-21.** WP83 is complete.

## Result

`.ASSERT expr[, "message"]` is implemented end-to-end in native CASM: a
compile-time expression check with zero byte emission. A nonzero resolved
value passes silently; a zero value fails the whole assembly with
`CASM_DIAG_ASSERTION_FAILED`, optionally echoing a user-supplied message.
The expression must fully resolve in both passes -- an unresolved operand
is a diagnostic error (`CASM_DIAG_ASSERT_UNRESOLVED`), not a tolerated
Pass-1 placeholder, matching WP81's own `.RES`/`.FILL`/`.ALIGN` precedent.

All five Scoping Decisions from the plan were confirmed or discovered and
corrected during implementation:

1. Strict both-pass resolution (confirmed, mirrors WP81).
2. Minimal message echo on failure (confirmed, option (b)).
3. Zero-is-false truthiness (confirmed) -- **with a correction found
   during Increment 5**: the plan's own claim that `=` was usable as an
   in-expression comparison operator was wrong (not verified before
   writing it). CASM's expression grammar has no equality/comparison
   operator at all (`expr.s`'s `parseOperatorTail` only classifies
   `+ - | ^ & << >> * /`); `.ASSERT` therefore only tests nonzero-
   arithmetic truthiness, not equality/alignment invariants. Confirmed
   with the user: ship as scoped, defer a real comparison operator as a
   separate follow-up (affects WP84's real target sites -- see below).
4. 65-byte message buffer, mirroring `CASM_INCLUDE_FILENAME_MAX`/
   `_BUFFER_SIZE` exactly (confirmed).
5. **Added mid-implementation**: no dedicated `lexerScanAssertMessage`
   scanner -- the message operand reuses the lexer's existing `lnString`/
   `CASM_TOKEN_STRING` tokenizer (WP74's `.BYTE "string"` support),
   confirmed with the user during Increment 3.

## Implementation

- `common.inc`: `CASM_DIRECTIVE_ASSERT` ($0B); `CASM_ASSERT_MESSAGE_MAX`/
  `_BUFFER_SIZE` (63/64, mirroring the include-filename precedent); three
  new diagnostics `CASM_DIAG_ASSERT_UNRESOLVED`/`_MESSAGE_TOO_LONG`/
  `ASSERTION_FAILED` ($52-$54).
- `lexer.s`: token recognition for `.ASSERT` appended to `lnDirective`'s
  chain. No new scanner (Decision 5) -- the message operand is picked up
  by an ordinary `lexerNext` call landing on the existing `lnString`.
- `parser.s`: new `ppsAssert`, dispatched from `ppsMnemonic`. Parses the
  expression via `parserParseExpressionValue`, requires
  `CASM_EXPR_FLAG_RESOLVED` explicitly (diagnosing
  `CASM_DIAG_ASSERT_UNRESOLVED` otherwise), then -- if a comma follows --
  requires the next token to be `CASM_TOKEN_STRING`, copies
  `CasmStringBuffer` into a new null-terminated `CasmAssertMessage`
  buffer (own `CASM_DIAG_ASSERT_MESSAGE_TOO_LONG` cap check), and stages
  the resolved value into new `CasmAssertValueLo/Hi`.
- `emit.s`: new `emitAssert`, dispatched from `emitDirective`. No
  `emitMarkStarted` call (`.ASSERT` never emits a byte, so it can't be
  "the first statement" of a relocatable assembly). Compares
  `CasmAssertValueLo/Hi` against zero: `clc; rts` on nonzero; on zero,
  diagnoses `CASM_DIAG_ASSERTION_FAILED`.
- `diagnostics.s`: new `dpfWp83Check` dispatch block plus
  `diagWp83MessageLo/Hi` table for the three fixed-text diagnostics, and
  a carve-out in front of it: `CASM_DIAG_ASSERTION_FAILED` with
  `CasmAssertMessageLen != 0` prints a new `msgAssertionFailedPrefix`
  ("CASM: ASSERTION FAILED: "), then `CasmAssertMessage` itself, then a
  one-byte `msgCrOnly` line terminator, before falling into the normal
  `diagPrintSourceContext` call. No new "print a runtime buffer"
  primitive was needed -- `diagPrintString`/`DOS_PRINT_STR` already
  prints whatever null-terminated buffer X/Y point at.

### Defects found and fixed during implementation/verification

1. **A real error in this plan's own Decision 3** (see above) -- caught
   by verifying against `expr.s` before writing fixtures, not assumed.
   Corrected in the plan and confirmed with the user before fixtures were
   written.
2. **6502 `jmp (abs)` page-boundary hazard in `expr.s`**, fourth
   occurrence of the same class (WP46, WP54, WP82, now WP83) --
   `test_casm_passcheck` retripped it after Increment 5's growth;
   `CasmExprResolverAddrPad` widened 3->4 bytes, user-approved.
3. **`diagPrintFatal`'s own branch-range fragility**, exactly as WP81's
   comment already warned: adding the WP83 dispatch block twice pushed an
   earlier `bcc` out of 6502 branch range (once in Increment 5's initial
   wiring, again in Increment 6's message-echo carve-out). Both fixed
   with a `bcs`/`jmp` inversion, no logic change.
4. **Disk-full blocker**: `test_casm_frame`'s own envelope bump grew its
   PRG enough that `casm_listing_test.d64` (shared with several other
   harnesses) hit 0 free blocks, live-confirmed (`casmfrr2.seq` failed to
   write). Resolved by relocating `test_casm_frame` and its own fixtures
   to `casm_phase13_test_d64` (469 free blocks before the move, 343 after
   all of WP83's fixtures), user-approved -- same "move the largest
   occupant off a full disk" precedent this project has used before
   (WP52, WP67, WP53 increment 4's original move of `test_casm_frame`
   onto that disk in the first place).
5. **VICE crashed once, unprompted**, mid-session during a disk-attach
   call between regression runs. A fresh instance was started per the
   workflow's one-clean-restart allowance; Command64 reboot and a full
   regression re-run from scratch confirmed identical results.

## New Fixtures

Packaged on `casm_phase13_test_d64`:

- `casmassert1.seq` / `casmassert1.ref.hex` -- `.ORG $C000` then
  `.ASSERT 1` then `.BYTE $AA`. Accepted, COMP-verified byte-identical --
  proves `.ASSERT` itself emits zero bytes (the following `.BYTE` lands
  immediately after the `.ORG` header).
- `casmassertfail.seq` -- `.ASSERT 0`, no message. Rejected:
  `CASM_DIAG_ASSERTION_FAILED` (generic text).
- `casmassertmsg.seq` -- `.ASSERT 0, "CUSTOM MESSAGE"`. Rejected:
  `CASM_DIAG_ASSERTION_FAILED` with the custom message echoed inline.
- `casmassertfwd.seq` -- `.ASSERT COUNT` / `COUNT = 5` (forward
  reference, mirroring WP81's `casmresfwd.seq`). Rejected:
  `CASM_DIAG_ASSERT_UNRESOLVED`.

No isolation harness was added (mirroring WP82's own precedent) --
`emitAssert`'s logic (a single zero/nonzero comparison, no emission at
all) is thin enough that the production fixtures alone, run through the
real parser/emitter, were judged sufficient coverage.

## Envelope Changes

All user-approved 2026-08-21, each the smallest round-page fit above its
measured overflow:

| Target | Before | After | Reason |
| --- | --- | --- | --- |
| `casm` (production) | `$6A00` | `$6B00` | Increment 4: `ppsAssert` staging fields |
| `casm` (production) | `$6B00` | `$6C00` | Increment 6: message-echo dispatch |
| `test_casm_pass1` | `$6200` | `$6300` | Increment 5 |
| `test_casm_frame` | `$6100` | `$6300` | Increment 5 (+512, exceeded a single page) |
| `test_casm_listcap` | `$6600` | `$6700` | Increment 5 |
| `test_casm_listcap` | `$6700` | `$6800` | Increment 6 |
| `test_casm_passcheck` | `$5E00` | `$5F00` | Increment 5 |
| `test_casm_include` | `$1800` | `$1900` | Increment 2 |
| `test_casm_spanread` | `$3200` | `$3300` | Increment 6 |

`test_casm_bounds` and `test_casm_directives` (Increment 5) needed
one-byte `CasmAssertValueLo`/`CasmAssertValueHi` stand-ins.
`test_casm_faultsource` and `test_casm_spanread` (Increment 6) needed
one-byte `CasmAssertMessage`/`CasmAssertMessageLen` stand-ins. Both
pairs mirror the established `CasmFillCountLo/Hi`/`CasmIncbinFilename`
stand-in precedent -- `emit.s`/`diagnostics.s` link whole in each of
these harnesses, pulling in the new imports even though none of them
dispatch `.ASSERT`.

## Regression Evidence

- Full clean rebuild from scratch (`rm -rf build && cmake -B build &&
  cmake --build build`), performed twice (after Increment 5 and again
  after Increment 6): every target links and packs clean, no overflow,
  no unresolved externals.
- `test_casm_expr`: `CASM EXPR: PASS` (live VICE, `casm_phase12_test.d64`),
  re-confirmed fresh after Increment 6.
- `test_casm_pass1`: `CASM PASS1: PASS` (live VICE, same disk),
  re-confirmed fresh after Increment 6.
- `test_casm_frame`: `CASM FRAME: PASS` (live VICE,
  `casm_phase13_test.d64`, its new home), re-confirmed fresh after
  Increment 6.

## Live VICE Evidence

- VICE 3.10 C64SC answered MCP ping throughout (one unprompted crash and
  clean restart mid-session, see Defects above).
- `casmassert1.s` assembled via `casm`, then `comp casmassert1.prg
  casmassert1.ref`: `FILES COMPARE OK`.
- `casmassertfail.s`: `CASM: ASSERTION FAILED` at line 1, col 1
  (offset 0).
- `casmassertmsg.s`: `CASM: ASSERTION FAILED: custom message` at line 1,
  col 1 (offset 0) -- the echoed text renders lowercase per this
  project's usual raw-PETSCII-source display convention (uppercase ASCII
  source bytes read at CASM runtime, not ca65-charmap-translated),
  matching every other runtime-read string in this codebase.
- `casmassertfwd.s`: `CASM: ASSERT OPERAND NOT RESOLVED` at line 1, col 9
  (offset 8) -- exactly where `COUNT` begins.
- Every dispatch above ended with a clean `c64[8]:>` shell return, with
  correct caret-context lines in every diagnosed case.

## Manual Confirmation

1. Boot `build/casm_phase13_test.d64` into Command64.
2. Run `casm casmassert1.s`, then `comp casmassert1.prg casmassert1.ref`;
   expect `FILES COMPARE OK`.
3. Run `casm casmassertfail.s`, `casm casmassertmsg.s`, and
   `casm casmassertfwd.s`; expect the three diagnostics listed above,
   each at its documented location.
4. Confirm CASM's own version banner reads `CASM V0.3.0` (build
   incremented, no version bump this WP).

## Completion Gate

- [x] `.ASSERT` implemented and live-verified in VICE: correct pass-
      through for a true expression, correct diagnostics (generic,
      message-bearing, and unresolved-operand) for every failure case.
- [x] Production fixture byte-exact against a hand-derived reference
      (zero bytes emitted).
- [x] Full existing CASM regression suite clean, no regressions.
- [x] No-change rebuild confirmed stable.
- [x] Envelope bumps explicitly approved, not silently absorbed.
- [x] Walkthrough recorded here.
- [x] **User explicitly approves closing WP83.** Approved 2026-08-21.

WP83 is complete.

Phase 13 remains open for WP84 (DASH adoption -- will need to find
genuinely nonzero-truthy target sites given the comparison-operator gap
found in Increment 5, or restate its planned equality checks some other
way) and WP85 (consolidated verification and version promotion to
`0.4.0`).
