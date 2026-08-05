---
feature: casm-phase10-wp52-deterministic-symbol-map
created: 2026-07-29
status: implemented
taskwarrior: 0bf2e86b-0bd0-443a-b84b-b2c258e98181
depends-on: a64fa847-1b46-44fd-be3b-8ad7b1055c92
---

# Plan: CASM Phase 10 WP52 - Deterministic Symbol Map

## Status

Approved but blocked by WP51 completion. Approval freezes the implementation
contract and does not activate WP52. Completion target: CASM `0.1.53`.

Parent: `brain/plans/2026-07-29-casm-phase10-symbol-map-listing.md`.

## Objective

Implement and verify deterministic `/M` formatting over symbol records in
definition order. Production invocation remains gated until WP54.

## Symbol Access ABI

Add stateless `symbolsReadByIndex` to `symbols.s`:

- Input: X/Y = record index low/high.
- Valid: carry clear, `A = CASM_STREAM_DATA`, 64-byte record in
  `CasmVmmBuffer`.
- Index >= `CasmSymbolCount`: carry clear, repeat-stable
  `A = CASM_STREAM_EOF`, no VMM transfer.
- Failure: carry set, `A = CASM_DIAG_VMM_TRANSFER_FAILED`.
- Compute offset by shifting index left six bits; read exactly one record.
- Do not expose symbol slot/count or add symbol replay state.
- Clobber A/X/Y, VMM offset/length/buffer scratch, and OS volatiles.

## Map Module

Add `map.s` with a 16-bit cursor/count, private scratch, and one 40-byte row
buffer. It allocates no VMM or file resource.

### `mapPrint`

Reset cursor/count, print header, read/validate/format each record, then print
the total. Success returns carry clear and `CASM_DIAG_NONE`; failure returns
carry set with VMM transfer or invalid-map diagnostic. Repeated calls restart at
zero and are deterministic.

### Validation

Require name length 1-31, DEFINED set, reserved flag bits clear, and reserved
bytes 37-63 zero. Copy only NameLen bytes. Ignore collision-chain Next fields.
Corruption raises:

```text
$42 CASM_DIAG_SYMBOL_MAP_INVALID
```

Extend selector bounds, message tables, and Phase 10 contiguity assertions.
The diagnostic is locationless.

## Exact Formatting

`map.s` owns private buffer-writing hexadecimal and fixed-three-digit decimal
formatters and prints completed null-terminated rows through `diagPrintString`.

```text
SYMBOL MAP<CR>
$HHHH LABEL<CR>
NNN SYMBOLS<CR>
```

- Four uppercase address digits, one space, exact case-sensitive name.
- Totals are `000` through `512`, always three digits and always `SYMBOLS`.
- Maximum row is 39 bytes including CR and null.
- No direct map OS calls and no dependency on diagnostics' private formatters.

## Harness

Add `test_casm_map` with real symbols/VMM/resources and a stand-in
`diagPrintString` sink that verifies each row without retaining all 512 rows.

Fixtures: empty/one/full tables; insertion order differing from hash order;
case and 31-byte names; boundary addresses; relocatable base values; repeated
printing; read indices at/beyond bounds; VMM failure; invalid name lengths,
flags, and padding; exact hex and totals; cleanup on success/failure.

## Production Boundary

Link `map.s` into CASM but add no `casm.s` call. `/M` remains NOT IMPLEMENTED
until WP54, so normal behavior and resources are unchanged.

## Envelope

Start from WP51's final envelope, choose the smallest 256-byte-aligned increase,
and stop above preapproved `$4F00`. Measure the harness separately. No zero-page
growth.

## Expected Files

New `map.s` and `tests/src/casm_map/`; modify `symbols.s`, `common.inc`,
`diagnostics.s`, CMake/test composition/DOX, tasks, knowledge, memory, changelog,
and completion walkthrough.

## Atomic Increments

1. Freeze accessor/diagnostic/assertions.
2. Implement/test read by index.
3. Implement map validation and private formatters.
4. Implement `mapPrint` and exact-output sink.
5. Link production without invocation.
6. Measure envelopes and run regressions.
7. Review, walkthrough, approval, stable `0.1.53`, and record synchronization.

## Verification

Build through CMake at base/partner origins; verify rows byte-for-byte, ordering,
one read per symbol and none at EOF, corruption failures, no map resources,
production `/M` still gated, assembly/relocation identity, carry/bounds/null
termination, stable rebuild, `git diff --check`, and DOX closeout.

## Stop Conditions

Hash traversal, exposed symbol internals, row >40, invalid legitimate records,
map VMM/file/source/zero-page requirements, early production activation,
diagnostics refactor, envelope >`$4F00`, or changed assembly/runtime behavior.

## Completion Gate

WP52 requires WP51 completion, implementation/tests, measured envelopes, review,
user walkthrough and approval, stable `0.1.53`, and synchronized records. It
does not activate WP53.

## Progress

- 2026-07-29: User approved this plan. WP52 remains pending and blocked by
  WP51; no implementation is authorized.
- 2026-08-05: WP51 complete; implementation authorized on
  `feature/casm-phase10-wp52` (based on `casm-phase10` caught up to `main`,
  `a69ccd8`). Implemented in order:
  1. `symbolsReadByIndex` (`symbols.s`): stateless read-by-index, matching
     the plan's ABI exactly (X/Y index in; `CASM_STREAM_DATA`/`_EOF` out;
     offset computed by a 6-bit shift, mirroring `symbolsFindChain`'s own
     cursor-offset math).
  2. `CASM_DIAG_SYMBOL_MAP_INVALID` ($42) in `common.inc`, with its own
     contiguity assertion following WP53's reserved-but-unimplemented
     range. Given `diagPrintFatal`'s message table only tracks the
     `CASM_DIAG_PHASE10_WP51_LAST` bound, $42 is checked as an early
     special case in `diagPrintFatal` rather than densely filling WP53's
     unimplemented $3D-$41 gap with placeholder text that isn't this
     work package's to write.
  3. `map.s`: `mapPrint`, `mapValidateRecord`, `mapFormatRow`, and private
     buffer-writing hex/decimal formatters (deliberately independent of
     `diagnostics.s`'s own print-directly formatters, per the plan).
     Picked up automatically by CASM's source glob; no `casm.s` call site
     added, so `/M` remains NOT IMPLEMENTED as required.
  4. `tests/src/casm_map/casm_map.s`: 16 fixtures against real
     symbols/VMM/resources, with a local `diagPrintString` stand-in sink
     (captures one targeted row per `mapPrint` call via a caller-set call
     index, never retaining all rows at once). Two fixtures
     (`maporder1`/`mapcase1`, later split into `maporder1a/b` and
     `mapcase1a/b` while diagnosing) initially failed from a harness bug,
     not a `map.s` bug: `symbolsInsert`'s `X=ValLo, Y=ValHi` contract was
     read backwards when choosing test values, computing `$0011` instead
     of the intended `$1100`. Confirmed via `mapone1`'s already-correct
     fixture, which proved `map.s`'s own Hi-then-Lo hex formatting was
     right all along. Fixed and VICE-verified 16/16 PASS on
     `casm_listing_test_d64`.
  5. Envelope: production `casm` overflowed `$4900` by 362 bytes; `$4B00`
     (+512) fits with 150 bytes headroom. `symbols.s`'s growth, linked
     whole by every harness that touches it, also overflowed
     `test_casm_pass1` (`$4700`->`$4800`) and `test_casm_passcheck`
     (`$4300`->`$4400`).
  6. That same growth cascaded into two test disks already near their own
     ceiling: `test.d64` (2 blocks short) and `casm_overflow_test.d64`
     (already at 1 free block pre-WP52, confirmed via a clean baseline
     checkout). User approved relocating `test_casm_passcheck` and
     `test_l15release` (both fixture-free, no same-disk coupling) to
     `casm_listing_test_d64` (523 -> 442 blocks free there) rather than
     trimming either origin disk's real content.
  7. CASM bumped `0.1.52` -> `0.1.53` (code size unchanged; same-length
     version string).
  8. Regression: production `casm`, `test_casm_map` (16/16), and
     `test_casm_passcheck` (2/2) all VICE-verified clean under a fresh
     boot. `test_casm_symbols` was not completed -- its load hung after a
     `9:`/`8:` device switch mid-session, an apparent IEC/device-switch
     anomaly unrelated to any assertion in the harness itself; the user
     reset the machine and confirmed `test_casm_symbols` passes in full.
  User confirmed the walkthrough 2026-08-05. WP52 complete.
