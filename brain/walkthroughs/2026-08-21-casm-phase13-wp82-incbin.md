# CASM Phase 13 WP82 .INCBIN Completion Gate

## Status

**Approved by the user on 2026-08-21.** WP82 is complete.

## Result (proposed)

`.INCBIN "filename"` is implemented end-to-end in native CASM: it streams
a raw binary file's entire contents, verbatim, into the assembled output
starting at the current `CasmPc`, through bounded 256-byte chunks. Both
Scoping Decisions from the plan were confirmed before implementation: (1)
a dedicated filename scanner with its own diagnostic identity (not a reuse
of `.INCLUDE`'s), and (2) no dedicated per-occurrence Pass1/Pass2 length
check -- the existing whole-assembly `emitCheckPassAgreement` (WP30) is
relied on instead.

## Implementation

- `common.inc`: `CASM_DIRECTIVE_INCBIN` ($0A), and three new diagnostics
  `CASM_DIAG_INCBIN_FILENAME_EXPECTED` / `_INVALID_INCBIN_FILENAME` /
  `_INCBIN_FILENAME_TOO_LONG` ($4F-$51). No dedicated length-mismatch
  diagnostic (Scoping Decision 2).
- `lexer.s`: token recognition for `.INCBIN` appended to `lnDirective`'s
  chain, plus a new `lexerScanIncbinOperand` -- a near-verbatim copy of
  `lexerScanIncludeOperand`'s structure (leading whitespace, opening
  quote, printable-PETSCII payload, closing quote, trailing whitespace/
  comment, terminator), writing into new `CasmIncbinFilename`/
  `CasmIncbinFilenameLen` (parser.s-owned, mirroring `CasmIncludeFilename`'s
  own 65-byte shape) and raising its own diagnostics rather than
  `.INCLUDE`'s.
- `parser.s`: new `ppsIncbin`, dispatched from `ppsMnemonic`, mirroring
  `ppsInclude`'s thin shape -- calls the scanner, sets
  `CASM_OPKIND_IMPLIED`, returns. Performs no file I/O itself.
- `emit.s`: new `emitIncbin`, dispatched from `emitDirective`. Calls
  `emitMarkStarted`, then `inputStreamOpen`/`inputStreamRead` (fileio.s's
  existing managed-stream wrappers, the same ones `.INCLUDE`'s own loader
  uses transiently) in a bounded-chunk loop streaming each byte through
  the existing `emitByte` (pass-mode-transparent, same minimalism as
  WP81's `emitFillLoop` -- no separate measure-only path), then
  `inputStreamClose`. A read or emit failure inside the loop still
  best-effort closes the file (via a `pha`/`jsr inputStreamClose`/`pla`
  sequence) without disturbing the original failing diagnostic.

### Defects found and fixed during implementation/verification

1. **6502 `jmp (abs)` page-boundary hazard in `expr.s`.** Adding
   `lexerScanIncbinOperand` shifted CODE size enough to push
   `CasmExprResolverAddrLo`'s low byte back onto the exact `$FF` boundary
   this project has hit twice before (WP46, WP54). Fixed by widening the
   existing `CasmExprResolverAddrPad` from 2 to 3 bytes -- same targeted
   fix, third occurrence of the same hazard class.
2. **`cc1541 -f` filename-encoding mismatch (the real find of this WP).**
   The `.INCBIN` production fixture's binary asset repeatedly failed to
   open (`CASM: CANNOT OPEN INPUT`), reproducing even through Command64's
   own `TYPE` command -- not a CASM bug. Root cause: `cc1541 -f` (without
   the `#` literal-PETSCII-byte prefix) encodes an **uppercase**-typed
   argument as shifted/bit-7-set PETSCII (`'C'` -> `$C3`) but a
   **lowercase**-typed argument as unshifted PETSCII (`'c'` -> `$43`,
   numerically identical to uppercase ASCII). Since a raw `.seq` fixture's
   own quoted filename text is taken as literal, untranslated bytes
   (`reference-casm-host-source-uppercase`, `reference-casm-petscii-
   identifier-case`), the disk directory name and the source's own quoted
   string must be produced by *different-cased* command-line inputs to
   land on the *same* bytes. Confirmed by extracting the raw directory
   bytes with `cc1541 -a`'s own reconstruction output, and by cross-
   checking against this project's existing, already-working `.INCLUDE`
   fixtures (`CASMFRC1`/`CASMFRC2` in source text, `-f "casmfrc1"`/
   `"casmfrc2"` lowercase as their own packaging arguments -- the exact
   same pairing, previously unexplained in any comment). Fixed by passing
   `-f "casmincbin1.dat"` (lowercase) while keeping the `.seq` source's own
   quoted filename `"CASMINCBIN1.DAT"` (uppercase).

## New Fixtures

Packaged on the existing `casm_phase13_test_d64` (WP81's own dedicated
Phase 13 disk):

- `casmincbin1.seq` / `casmincbin1.ref.hex` -- `.ORG $C000` then
  `.INCBIN "CASMINCBIN1.DAT"`, a real 4-byte binary asset
  (`tests/fixtures/casm/casmincbin1.dat`, bytes `DE AD BE EF`). Accepted,
  COMP-verified byte-identical.
- `casmincbinmiss.seq` -- `.INCBIN "nonexistent.dat"` (file genuinely
  absent). Rejected: `CASM_DIAG_INPUT_OPEN_FAILED` (reused, not new).
- `casmincbinbadname.seq` -- `.INCBIN nofile` (no opening quote).
  Rejected: `CASM_DIAG_INCBIN_FILENAME_EXPECTED`.

No isolation harness was added this WP (unlike WP81's `test_casm_directives`)
-- `emitIncbin`'s file-I/O surface is thin enough (three managed-stream
calls plus a byte-emission loop already proven by WP81's `emitFillLoop`)
that the production fixtures alone, run through the real parser/emitter,
were judged sufficient coverage; flagged in the plan as a "TBD, confirm at
increment-planning time" item and resolved this way in practice.

## Envelope Changes

All user-approved 2026-08-21, each the smallest round-page fit above its
measured overflow:

| Target | Before | After | Reason |
| --- | --- | --- | --- |
| `casm` (production) | `$6700` | `$6800` | Increment 1: directive constant + diagnostics |
| `casm` (production) | `$6800` | `$6900` | Increment 3: `lexerScanIncbinOperand` |
| `casm` (production) | `$6900` | `$6A00` | Increment 5: `emitIncbin` |
| `test_casm_faultsource` | `$2E00` | `$2F00` | Increment 1 |
| `test_casm_listcap` | `$6300` | `$6400` | Increment 1 |
| `test_casm_listcap` | `$6400` | `$6500` | Increment 3 |
| `test_casm_listcap` | `$6500` | `$6600` | Increment 5 |
| `test_casm_pass1` | `$5F00` | `$6000` | Increment 1 |
| `test_casm_pass1` | `$6000` | `$6100` | Increment 3 |
| `test_casm_pass1` | `$6100` | `$6200` | Increment 5 |
| `test_casm_passcheck` | `$5B00` | `$5C00` | Increment 1 |
| `test_casm_passcheck` | `$5C00` | `$5D00` | Increment 3 |
| `test_casm_passcheck` | `$5D00` | `$5E00` | Increment 5 |
| `test_casm_include` | `$1600` | `$1800` | Increment 3 |
| `test_casm_frame` | `$5F00` | `$6100` | Increment 3 |

`test_casm_bounds` and the new `test_casm_directives` (WP81) needed local
one-byte/no-op stand-ins for `CasmIncbinFilename`/`CasmIoBuffer`/
`inputStreamOpen`/`inputStreamRead`/`inputStreamClose` (linked whole from
`emit.s`, unreachable by either harness's own cases) to keep linking clean.

## Regression Evidence

- Full clean rebuild from scratch (`rm -rf build && cmake -B build &&
  cmake --build build`): every target links and packs clean, no overflow,
  no unresolved externals.
- `test_casm_expr`: `CASM EXPR: PASS` (live VICE, `casm_phase12_test.d64`).
- `test_casm_pass1`: `CASM PASS1: PASS` (live VICE, same disk).
- `test_casm_frame`: `CASM FRAME: PASS` (live VICE, `casm_listing_test.d64`).

## Live VICE Evidence

- VICE 3.10 C64SC answered MCP ping throughout.
- `casmincbin1.s` assembled via `casm`, then `comp casmincbin1.prg
  casmincbin1.ref`: `FILES COMPARE OK`.
- `casmincbinmiss.s`: `CASM: CANNOT OPEN INPUT` at line 1, col 9
  (offset 8).
- `casmincbinbadname.s`: `CASM: INCBIN FILENAME EXPECTED` at line 1, col 9
  (offset 8).
- Every dispatch above ended with a clean `c64[8]:>` shell return.
- Independent confirmation of the `cc1541 -f` case-encoding defect: typing
  `type CASMINCBIN1.DAT` directly at the Command64 shell (bypassing CASM
  entirely) also failed with `LOAD ERROR` before the fix, and the same
  `TYPE` command against the corrected disk was not separately re-tested
  after the fix (superseded by the successful COMP-verified `.INCBIN`
  assembly itself, which exercises the identical KERNAL open path).

## Manual Confirmation

1. Boot `build/casm_phase13_test.d64` into Command64.
2. Run `casm casmincbin1.s`, then `comp casmincbin1.prg casmincbin1.ref`;
   expect `FILES COMPARE OK`.
3. Run `casm casmincbinmiss.s`, then `casm casmincbinbadname.s`; expect
   the two diagnostics listed above, each at its documented location.
4. Confirm CASM's own version banner still reads `CASM V0.3.0` (build
   incremented, no version bump this WP).

## Completion Gate

- [x] `.INCBIN` implemented and live-verified in VICE.
- [x] Production fixture byte-exact against a hand-derived reference.
- [x] Both documented diagnostics live-verified for message and location.
- [x] Regression witnesses (`test_casm_expr`/`test_casm_pass1`/
      `test_casm_frame`) confirmed clean.
- [x] Full clean rebuild confirmed stable.
- [x] Envelope bumps explicitly approved, not silently absorbed.
- [x] **User explicitly approves closing WP82.** Approved 2026-08-21.

WP82 is complete. Phase 13 remains open for WP83 (`.ASSERT`), WP84 (DASH
adoption), and WP85 (consolidated verification and version promotion to
`0.4.0`).
