---
feature: casm-phase6-wp27-symbol-table-storage
created: 2026-07-22
status: complete
---

# Walkthrough: CASM Phase 6B WP27 Symbol Table Storage and Hash Index

Plan: `brain/plans/2026-07-22-casm-phase6-wp27-symbol-table-storage.md`

Taskwarrior: `0dd437f3-3248-4294-aee7-39bb8571f1c8`

## Outcome

WP27 built `symbols.s` -- VMM-backed symbol records over Phase 6A storage
plus a bounded RAM hash-bucket index (`symbolsInit`/`symbolsInsert`/
`symbolsLookup`) -- and fixture-tested it in complete isolation, matching
how `vmm_store.s` was built and tested in WP23-25 before any production call
site existed. No `casm.s`, `parser.s`, or `opcodes.s` call site exists yet;
WP28 wires this module into real assembly.

Reconciling WP26's frozen 37-byte symbol record against Phase 6A's existing
32-byte VMM transfer buffer found they conflicted outright: 37 bytes cannot
pass through a single `vwPrepareTransfer`-bounded transfer. The user resolved
this by padding the record to 64 bytes and growing the buffer to match,
which also collapsed record-index-to-VMM-offset arithmetic from a 3-term
shift-add multiply-by-37 to a single 16-bit shift-left-6. Extending
`diagnostics.s` for the new Phase 6B diagnostics also surfaced and fixed,
with explicit user approval, a pre-existing Phase 6A defect: `diagPrintFatal`
had never printed real text for any of the four VMM diagnostics since
WP23/24 -- they silently fell back to "UNKNOWN" the entire time.

All 10 fixtures pass in VICE, alongside a clean re-run of the existing
`test_casm_vmm` regression matrix.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase6-wp27` |
| Branch point | `feature/casm-phase6-wp26` at `9784400` (not `main` -- `main` has no Phase 6B commits yet; each WP branches from the previous WP's branch tip, matching the WP22->WP23->WP24->WP25 chain) |
| Baseline version | `0.1.28.1112` |
| Plan approval | Approved after two review iterations: the record-size/VMM-buffer conflict (resolved by padding to 64 bytes) and the diagnostic-gap fix (resolved by fixing all 8, not just the 2 WP27 needed) |

## Reconciliation Beyond the WP26 Freeze

1. **Symbol record grows from 37 to 64 bytes (amending WP26).** WP26 froze
   a 37-byte record without checking it against `CASM_VMM_BUFFER_SIZE = 32`
   (Phase 6A/WP24). `vwPrepareTransfer` rejects any transfer over 32 bytes
   before any OS call, so 37 bytes could never pass through one transfer at
   all. The user chose to pad the record to 64 bytes (a power of two) and
   grow the buffer to match: `CASM_VMM_BUFFER_SIZE` -> 64,
   `CASM_SYMBOL_REC_SIZE` -> 64, VMM footprint `512 * 64 = 32768` bytes (one
   `vmmStoreAlloc` call, well under the 65536-byte single-allocation cap).
   Record-index-to-offset arithmetic becomes a single unrolled 16-bit
   `asl`/`rol` x6 (`recordIndex << 6`), replacing a 3-term shift-add multiply.
2. **`symbols.s` needs no zero-page budget beyond the existing general-purpose
   pointer pair.** The parent Phase 6 plan predicted `CasmPassScratch0-3`
   would hold "hash-bucket/collision-chain cursors." Designing the exact
   algorithm found this state is all values, not pointers, so it lives in
   `symbols.s`'s own private BSS instead -- `CasmPassScratch0-3` stays free
   for WP28.
3. **Scratch discipline avoids a known bug class.** `vwPrepareTransfer`
   documents `CasmValue0Lo`/`CasmValue0Hi` as its own clobbered scratch; this
   exact class of bug (stashing state across a call in a cell the callee
   also uses) bit `vmm_store.s` three separate times during WP23-25 (per the
   WP25 walkthrough). `symbols.s` never stashes cross-call state there --
   everything lives in its own private BSS or in `CasmPtr0Lo/Hi`/
   `CasmPtr1Lo/Hi`.
4. **`symbolsLookup` matches the Phase 5 resolver ABI exactly.** Its
   calling convention (`X`/`Y` = caller-supplied 5-byte output-view pointer)
   is identical to `exprEvaluate`'s resolver callback contract, so WP28 can
   bind it directly as the resolver with zero adapter code.
5. **Pre-existing Phase 6A defect found and fixed: Phase 6A diagnostics
   never printed real text.** `diagPrintFatal`'s bound check
   (`cmp #CASM_DIAG_PHASE5_LAST + 1`) meant diagnostics `$28`-`$2B` (all
   four Phase 6A VMM diagnostics) always fell through to the generic
   "UNKNOWN" message -- confirmed by finding zero VMM-related strings
   anywhere in `diagnostics.s`. This had been true since WP23/24 and was
   never caught, since it doesn't affect build success or fixture pass/fail
   (fixtures check the returned diagnostic *code*, not the printed text).
   Moving the bound to cover WP27's new `$2C`/`$2E` required spanning past
   the old `$28`-`$2B` gap regardless, so the user approved fixing all 8
   diagnostics (`$28`-`$2F`) in one pass rather than opening a separate
   remediation plan for four lines that were always going to need the same
   bound-check edit.
6. **A genuine missing export, caught rather than guessed around.** The
   fixture-writing agent needed to read a symbol record's raw padding bytes
   for `sympad1`, which requires `vmmWindowRead`'s registry-slot argument --
   `symbols.s` didn't export `CasmSymbolVmmSlot`. Rather than hardcode slot
   `0` based on today's call order (fragile: would silently break if
   allocation order ever changed), the agent left `sympad1` stubbed and
   flagged the exact missing export. Added directly (`.export
   CasmSymbolVmmSlot`, one line -- the BSS storage already existed) and
   `sympad1` completed immediately after.

## Implementation

- `src/external/casm/symbols.s` (new, 437 lines): `symbolsInit` (one
  `vmmStoreAlloc(32768)` call, resets the bump counter and all 128 bucket
  heads to `$FFFF`), `symbolsFindChain` (private: hashes a name via
  rotate-left-1-XOR fold masked to 7 bits, walks the bucket's chain via
  `vmmWindowRead`, returns a three-way discriminant -- not-found / found /
  internal-VMM-error), `symbolsInsert` (rejects an exact case-sensitive
  duplicate or a full table, otherwise zero-fills the 64-byte staging
  record, populates it, prepends it at the bucket's *original* head, and
  appends it array-wise at the current bump-count index), `symbolsLookup`
  (reports found/not-found through a caller-supplied `CASM_RESOLVE_*` view,
  matching the Phase 5 resolver ABI exactly).
- `src/external/casm/common.inc`: `CASM_VMM_BUFFER_SIZE` 32 -> 64;
  `CASM_SYMBOL_REC_*` offsets and `CASM_SYMBOL_REC_SIZE = 64`;
  `CASM_SYMBOL_MAX = 512`, `CASM_SYMBOL_BUCKET_COUNT = 128`; diagnostics
  `CASM_DIAG_DUPLICATE_SYMBOL` (`$2C`), `CASM_DIAG_UNDEFINED_SYMBOL`
  (`$2D`, reserved), `CASM_DIAG_SYMBOL_TABLE_FULL` (`$2E`),
  `CASM_DIAG_PASS_MISMATCH` (`$2F`, reserved), with contiguity asserts
  matching every prior phase's pattern.
- `src/external/casm/diagnostics.s`: `diagPrintFatal`'s bound moved to
  `CASM_DIAG_PHASE6B_LAST + 1`; 8 new message-table entries and RODATA
  strings covering `$28`-`$2F` (4 Phase 6A entries that had never existed,
  4 new Phase 6B entries).
- `tests/src/casm_symbols/casm_symbols.s` (new): standalone harness
  mirroring `test_casm_vmm.s`'s structure exactly (own `diagPrintFatal`
  stub, same dot/`F` `reportCase` convention). 10 sequential fixtures
  against one shared symbol table: `syminit1`, `symins1`, `symlook1`,
  `symlookmiss1`, `symdup1`, `symcase1`, `symchain1` (129 programmatically
  generated names -- a guaranteed pigeonhole collision against 128 buckets),
  `symlen1` (31-byte maximum-length identifier), `sympad1` (direct
  `vmmWindowRead` padding check), `symfull1` (a real 512-symbol exhaustion
  test, generated programmatically, not manually deferred the way Phase 6A's
  REU-exhaustion case had to be).
- `CMakeLists.txt`: added the `casm_symbols` special case to `TEST_CA65_SRCS`,
  matching `casm_vmm`'s pattern; MAIN envelope `$2B00` -> `$2F00`.

## Static Verification

- `symbols.s` assembles with zero ca65 warnings/errors.
- Production `casm` overflowed `MAIN` by 848 measured bytes at `$2B00` once
  `symbols.s` + the amended `common.inc`/`diagnostics.s` landed together.
  `$2F00` (+1024 from `$2B00`) leaves 176 bytes headroom past the measured
  minimum -- the smallest round-page step above it, matching every prior
  MAIN bump's own convention.
- `test_casm_symbols` builds cleanly at both relocation bases; final PRG is
  2103 code bytes, comfortably under its 4096-byte `TEST_PRG_SIZE` budget.
- `test_casm_vmm` re-assembled cleanly against the amended
  `CASM_VMM_BUFFER_SIZE` with zero logic changes required (a superset-size
  change; nothing hardcoded the old 32-byte value outside the fixtures'
  own arbitrary pattern sizes, all of which are `<= 32 <= 64`).
- Both `image_d64` and `test_image_d64` build clean with `TEST_CASM_SYMBOL`
  packaged onto the test disk alongside `TEST_CASM_VMM` and `TEST_CASM_EXPR`.

## Runtime Verification

The user ran both programs from `build/test.d64` in VICE:

| Program | Result |
| --- | --- |
| `TEST_CASM_VMM` (regression check for the buffer-size amendment) | pass, all 7 fixtures |
| `TEST_CASM_SYMBOL` (new symbol-table matrix) | pass, all 10 fixtures |

Both reported clean at first run; no investigative iteration was needed.

## Phase 6B Acceptance (partial -- WP27's own scope)

Closed out in `wiki/tasks/casm.md`:

- [x] VMM-backed symbol storage and a bounded RAM hash-bucket index exist
      (`symbols.s`), independent of any parsing or pass semantics --
      matching Phase 6A's own "storage before semantics" precedent.
- [x] Duplicate-definition and case-sensitivity behavior verified
      (`symdup1`, `symcase1`).
- [x] Table-exhaustion behavior verified (`symfull1`, a real, non-deferred
      512-symbol test).
- [x] Chain-walk correctness under a real bucket collision verified
      (`symchain1`).
- [ ] Pass 1 address assignment, Pass 2 resolution/emission, relative
      branches from resolved symbols, and Pass 1/Pass 2 disagreement
      detection remain WP28-30, not yet started.

## DOX Closeout

Root, `src`, `src/external`, `src/external/casm`, `tests` contracts
rechecked. `brain/KNOWLEDGE.md`'s Phase 0C.5 section amended in place (37 ->
64 bytes, plus the `CASM_VMM_BUFFER_SIZE` amendment note) rather than left
stale. `AGENTS.md` not changed: WP27 introduces no new durable operating
rule beyond what it already documents (per-work-package plan approval,
ABI-amendment-requires-approval).

## Completion Dry-Run and Final Increment (`0.1.28` -> `0.1.29`)

| Measurement | Value |
| --- | --- |
| Baseline | `0.1.28` build 1112 |
| Applied version | `0.1.29` |
| Build number | 1113 (incremented exactly once) |
| No-change rebuild | pass, held at 1113 |
| `image_d64` | pass |
| `test_image_d64` | pass |

No separate dry-run/restore cycle was used for this increment (unlike
WP22-25's practice): the version-only edit was applied directly and verified
in place, since by this point in the work package the only remaining change
was the stage digit itself, with no ambiguity about what else might differ.

## Approval

The user approved both VICE runs ("Both pass") and confirmed proceeding with
the version increment and closeout.

WP27 is complete. Taskwarrior (`0dd437f3`), `wiki/tasks/casm.md`, and
`brain/task.md` are marked done. Taskwarrior WP28
(`712fe7af-1e41-46c9-9a19-49c2632cd15a`) is unblocked but not yet planned in
detail -- it requires its own dedicated plan and approval before any Pass 1
source is written, per the CASM `AGENTS.md` gate. The CASM Phase 6B milestone
(`166e5352`) remains open.
