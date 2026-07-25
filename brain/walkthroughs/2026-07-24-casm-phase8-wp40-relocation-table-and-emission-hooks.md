---
feature: casm-phase8-wp40-relocation-table-and-emission-hooks
created: 2026-07-25
status: complete
---

# Walkthrough: CASM Phase 8 WP40 Relocation Table Storage and Emission-Site Hooks

Plan: `brain/plans/2026-07-24-casm-phase8-wp40-relocation-table-and-emission-hooks.md`

Taskwarrior: `2175e962-2221-4308-8e3b-920065852d2d` (WP40); part of the CASM
Phase 8 milestone `c50df549-a7ae-4859-bd16-45a843425ce6`.

## Outcome

WP40 implemented Phase 0C.14 Contract item 4: a VMM-backed, append-only
relocation table (`reloc.s`, new module), and wired the six call sites
(across four logical emission sites) that must record an entry into it.
Program bytes are unaffected -- this WP adds a side-channel recording, not
a code-generation change. No R6 footer exists yet; WP41 appends the table
to the output file.

Re-tracing every byte-emission call site during planning (rather than
trusting WP37's original four-site enumeration) found a real correctness
gap: `emitInstruction`'s absolute-family branch and `emitWordList` both
emit a `VAL_LO`/`VAL_HI` pair, and `<`/`>` extraction turns out to be
reachable at both (not only `.BYTE`/immediate). A naive "record `VAL_HI`
when relocatable" check would have wrongly marked a genuine constant `$00`
padding byte as needing a page-delta patch. Resolved using `VAL_HI`'s own
zero/nonzero state to disambiguate, with no new ABI field. Implementation
matched the plan closely, with no material deviations beyond the expected
branch-range trampolines (see Implementation).

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase8-wp40` |
| Branch point | `feature/casm-phase8-wp39` at `9f1ee71` |
| Baseline version | `0.1.41` build 1147 |
| Plan approval | Approved as drafted |

## Implementation

- `common.inc`: `CASM_RELOC_MAX = 4096`, `CASM_RELOC_TABLE_BYTES = 8192`
  (with asserts), `CASM_DIAG_RELOC_TABLE_FULL = $30` and its Phase 8
  diagnostic-range asserts.
- `diagnostics.s`: `diagPrintFatal`'s selection bound extended from
  `CASM_DIAG_PHASE6B_LAST + 1` to `CASM_DIAG_PHASE8_LAST + 1`; new
  `msgRelocTableFull` ("CASM: RELOC TABLE FULL") added to both message
  tables and their length asserts.
- `reloc.s` (new): `relocInit` (allocates `CASM_RELOC_TABLE_BYTES`
  unconditionally via `vmmStoreAlloc`, resets the entry count) and
  `relocRecord` (no-ops under `CASM_PASS_MODE_MEASURE`; otherwise appends
  `CasmPc - CASM_DEFAULT_ORIGIN` via one immediate `vmmWindowWrite`,
  rejecting with `CASM_DIAG_RELOC_TABLE_FULL` once the count reaches
  `CASM_RELOC_MAX`). Exports `CasmRelocVmmSlot` for the standalone harness
  to read the table back.
- `emit.s`: two new private helpers, `emitMaybeRecordHi` (records iff
  `CASM_PARSER_STMT_RELOCATABLE` set and `ValHi != 0` -- the full,
  non-extracted value case) and `emitMaybeRecordLo` (records iff
  `RELOCATABLE` set and `ValHi == 0` -- the `>`-extraction case). Wired at
  six call sites: `emitInstruction`'s shared length-3 branch (both `Lo`
  before the `VAL_LO` byte and `Hi` before the `VAL_HI` byte, covering
  `CASM_MODE_ABSOLUTE`/`_X`/`_Y`/`_INDIRECT` uniformly); `eiTwoByte`,
  gated additionally on `CasmInsn.Mode == CASM_MODE_IMMEDIATE` to exclude
  indexed-indirect/indirect-indexed, which share the same code path and
  are structurally reachable with `RELOCATABLE` set via `>` extraction but
  must never be recorded; `emitByteList` (`Lo` only, `.BYTE >LABEL`); and
  `emitWordList` (both `Lo` and `Hi`, `.WORD LABEL`/`.WORD >LABEL`).
- `casm.s`: one new `relocInit` call, immediately after `fileCreateOutput`
  and before Pass 2's `emitInit`, unconditional regardless of mode.
- Two branch-range trampolines needed in `emitInstruction` (`eiOpcodeFail`/
  `eiLenOneDone`/`eiLenThree`), the same class of fix this codebase has
  hit at nearly every prior WP that added code to `emit.s` -- the new
  relocation hooks pushed two existing short branches (`bcs eiRet`,
  `beq eiDone`) out of 6502 branch range.
- `tests/src/casm_reloc/casm_reloc.s` (new standalone harness): `relocinit1`
  (allocation), `relocrecord1` (three entries at distinct `CasmPc` values,
  read back via `vmmWindowRead` and checked byte-for-byte), `relocmeasure1`
  (a MEASURE-mode call proven to append nothing, by confirming a
  subsequent EMIT-mode entry lands at the expected untouched offset), and
  `relocfull1` (a real fill of all 4096 entries, not a poked shortcut,
  matching `casm_vmm.s`'s `vmmalloc3` precedent, then confirms the 4097th
  fails with `CASM_DIAG_RELOC_TABLE_FULL` specifically). Provides its own
  `CasmPc`/`CasmPassMode` stand-ins (`reloc.s` imports both from `emit.s`,
  which this harness deliberately does not link) -- directly useful, not
  just link-satisfying, since the harness's own test logic drives them.
- `cmake/GenerateCasmTestFixtures.cmake` / `CMakeLists.txt` /
  `tests/fixtures/casm/casmrelop{1,2}.ref.hex`: two new end-to-end
  fixtures. `casmrelop1` covers one instance of each site under the normal
  (non-extraction) shape: `JMP LABEL`, `LDA #>DATA`, `LDX #<DATA` (negative
  case), `.WORD DATA`, `.BYTE >DATA`. `casmrelop2` covers the two-sided
  extraction cases found during this WP's own research: `LDA >TARGET`
  (absolute mode via `FORCE_ABS` promotion, not immediate) and
  `.WORD >TARGET`, both putting the real relocatable byte in the `VAL_LO`
  position. Neither fixture can observe the relocation table itself (no
  footer until WP41) -- both prove only that the new hooks do not corrupt
  program bytes.
- MAIN size bump: `$3500` -> `$3600` (144 measured bytes overflow from the
  new module plus six call sites; 106 bytes headroom at the new size, the
  smallest round-page step above the overflow, matching every prior
  phase's precedent). `test_casm_pass1`/`test_casm_passcheck` (which link
  `emit.s` whole, and now transitively `reloc.s`) bumped identically;
  `reloc.s` added to both harnesses' source lists after a real link
  failure (`Unresolved external 'relocRecord'`), not assumed in advance.

## A Drive-By Fix During This Session

Separately from WP40's own scope, removed `casmempty.s` from `test.d64`'s
build (`cad491a`, committed independently before WP40's own commit): its
zero-block directory entry was created via `cc1541 -L`, which sets that
entry's track/sector to 0 -- a value normally reserved as an end-of-chain
marker, not a valid file start, suspected of corrupting `test.d64`. Removed
from `GenerateCasmTestFixtures.cmake`/`CASM_TEST_FIXTURES` and the
now-single-case packaging branch that special-cased it; the two living docs
that described it as part of the current contract (`tests/AGENTS.md`,
`wiki/tasks/casm.md`'s Verification Policy section) were corrected.
Historical plan/walkthrough records mentioning it were left untouched.

## Static Verification

- `casm` build 1147 (baseline) -> 1153 (implementation candidate) -> 1154
  (version-only completion increment), no-change rebuild stable at each
  step.
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` all build
  clean.
- MAIN measured via `ld65 -m`: CODE `$2482` (9346) + RODATA `$93F` (2367)
  + BSS `$7D5` (2005) = 13718 of 13824 bytes -- **106 bytes headroom**.
- `test_casm_pass1`, `test_casm_passcheck`, `test_casm_symbols`,
  `test_casm_vmm`, `test_casm_expr`, and the new `test_casm_reloc` all
  link and build clean.
- Hand-derived `casmrelop1.ref`/`casmrelop2.ref` cross-checked against
  `hex_manifest_to_bin.py`'s own reported byte count and SHA-256 before
  any runtime test: 13 bytes / `sha256=b6de4129...` and 8 bytes /
  `sha256=5e0a399d...` respectively.

## Runtime Verification

The user ran the full verification matrix and confirmed: "all tests pass."

| Check | Result |
| --- | --- |
| `TEST_CASM_RELOC` (`relocinit1`, `relocrecord1`, `relocmeasure1`, `relocfull1`) | pass |
| `CASM CASMRELOP1` / `COMP CASMRELOP1.PRG CASMRELOP1.REF` | pass |
| `CASM CASMRELOP2` / `COMP CASMRELOP2.PRG CASMRELOP2.REF` | pass |
| `CASM CASMORG1` / `COMP CASMORG1.PRG CASMORG1.REF` (regression) | pass |
| `CASM CASMNOORG1` / `COMP CASMNOORG1.PRG CASMNOORG1.REF` (regression) | pass |
| `CASM CASMORDHAZ1` / `COMP CASMORDHAZ1.PRG CASMORDHAZ1.REF` (regression) | pass |
| `CASM CASMEMIT1` / `COMP CASMEMIT1.PRG CASMEMIT1.REF` (regression) | pass |
| `CASM CASMHELLO` / `RUN` (regression) | pass |
| `TEST_CASM_PASS1` | pass |
| `TEST_CASM_PASSCHECK` | pass |
| `TEST_CASM_EXPR` | pass |
| `TEST_CASM_SYMBOLS` | pass |
| `TEST_CASM_VMM` | pass |

## Documentation and DOX Closeout

- `brain/KNOWLEDGE.md`: Phase 0C.17 as-built section added, amending Phase
  0C.14-0C.16 with the exact implemented mechanism.
- `wiki/tasks/casm.md`: WP40 checked complete.
- `brain/task.md`: WP40 entry added and closed.
- `CHANGELOG.md`: Unreleased entry added.
- Taskwarrior: WP40 (`2175e962-2221-4308-8e3b-920065852d2d`) completed;
  WP41 unblocked.

## Completion

**CASM Phase 8 WP40 is complete**, per the completion gate in
`brain/plans/2026-07-24-casm-phase8-wp40-relocation-table-and-emission-hooks.md`:
`test_casm_reloc`'s full fixture matrix passed, every existing static and
WP38/39 fixture remains byte-identical, the two new end-to-end fixtures
assemble successfully with correct program bytes, MAIN headroom is
measured (106/13824, size bumped to `$3600`), a no-change rebuild holds
`BUILD_CASM` stable, all three disk images build clean, and the user
confirmed the runtime results. Final CASM `0.1.42` build 1154. WP41 (native
R6 footer serialization) remains separately gated and unstarted per
`AGENTS.md`.
