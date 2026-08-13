# Plan: CASM Phase 11 WP61 - Determinism and Remaining Boundary Spot-Checks

## Status

Drafted 2026-08-12 for user review. No WP61 task, source change, fixture,
build-system change, or version change is authorized until this plan is
explicitly approved. After approval, each atomic increment remains
separately gated by user review of the preceding increment, per this
project's established convention.

## Objective

Close WP61's two-part charter from the Phase 11 parent plan
(`brain/plans/2026-08-08-casm-phase11-base-release-hardening-documentation.md`):

1. **Determinism.** Prove that re-assembling identical input twice, in the
   same live session, produces byte-identical output -- PRG, R6 relocation
   table, `.LST` listing, and `/M` symbol map -- across a representative
   sample of production source shapes (static, exhaustive-opcode,
   relocatable/symbol-heavy).
2. **Remaining spot-checks.** Close the 4 boundary items WP60's Increment 9
   audit found and explicitly deferred (user-confirmed 2026-08-12 as WP61's
   scope, not a separately floating item):
   - `FORCE_ABS` stability for a symbol-derived operand across a genuine
     two-pass assembly (only single-pass, unit-level evidence exists today).
   - The source domain's 65,535-byte accepted extent and 65,536-byte
     first-reject boundary (never attempted at any prior increment).
   - Symbol/token name-length-32 rejection (`lexer.s`'s own
     `CASM_DIAG_TOKEN_TOO_LONG`, zero coverage anywhere in `tests/`).
   - The empty-source-file boundary is explicitly **not** actionable by this
     plan: `cc1541` cannot write a zero-byte SEQ fixture at all (confirmed
     live at WP60 Increment 7). This row is re-scoped by user approval as
     "closed: tooling gap, not a code gap" rather than carried forward again.

The one-byte-source phantom-EOF-byte defect (Taskwarrior task 42,
`882433f0-cde1-4849-8b3c-df32613518c3`) is explicitly **out of scope**
(user-confirmed 2026-08-12) -- it stays its own separately tracked item.
WP61 does not investigate or fix it, though Increment 3 below notes it as a
design constraint (determinism fixtures must not rely on exactly-1-byte
inputs).

WP61 adds no new language feature, directive, or output format, matching
every other Phase 11 work package.

## Prerequisites

- WP60 (opcode, addressing, and boundary hardening) is complete at CASM
  `0.2.2` build `1266`, Taskwarrior task 40 closed.
- WP56's audit-priority triage and 3 carried-forward Phase 4 items are
  fully dispositioned (WP60 closed the `CLD` item; the other two are
  WP62's, not WP61's).
- No standalone file for WP56's full 4-tier/18-file module register was
  locatable beyond the summary in `brain/task.md` (confirmed with the user
  2026-08-12). This plan therefore does not attempt to re-derive or close
  out unnamed WP56 register rows beyond the 4 WP60-flagged items above --
  if the user later locates the register and it names additional
  unaddressed items, those are a plan amendment, not silently absorbed here.

## Baseline

CASM `0.2.2` build `1266`. `casm.prg`: 18581 code bytes, 2806 relocations,
base `$3800`. `image_d64`: 334 blocks free.

## Frozen Scope

- **In scope:** the two charter items above, exactly as user-confirmed.
- **Out of scope:** the phantom-EOF-byte defect (task 42); WP56's broader
  unnamed register rows (see Prerequisites); any new language feature,
  diagnostic, or ABI change; WP62's documentation-sync work; WP63's phase
  completion gate.
- **No production change is pre-authorized.** A defect found by any
  increment below (e.g., `FORCE_ABS` genuinely misbehaving across passes,
  or a determinism mismatch) may be fixed only after root-cause analysis
  identifies the exact routine and the user approves a plan amendment,
  matching every prior WP60 increment's rule.

## Determinism Method

No new production infrastructure is required. CASM already has everything
needed: assemble the same source twice to two different output names in one
live session, then use native `comp` (file-type-agnostic, confirmed from
`comp.s`'s own header) to diff the two outputs directly -- a **self-compare**,
not a compare-to-golden-reference, which is a different (and for this
purpose, better) proof than every prior WP's use of `comp` against a fixed
`.ref` file.

- **PRG bytes:** `casm <src> /o:a.prg` then `casm <src> /o:b.prg` then
  `comp a.prg b.prg` -> expect `FILES COMPARE OK`.
- **R6 relocation table:** for a relocatable source, the R6 footer is part
  of the same PRG `comp` above -- no separate step needed (WP60 Increment 5
  already established that the trailing R6 footer is covered by a whole-file
  `comp`, not a separate mechanism).
- **Listing (`/L`):** `casm <src> /o:a.prg /l` then `casm <src> /o:b.prg /l`
  produces `a.lst`/`b.lst`; `comp a.lst b.lst` -> expect `FILES COMPARE OK`.
- **Symbol map (`/M`):** `/M` is screen-print-only (confirmed live at WP60
  Increment 8 -- no `.MAP` file is ever written to disk), so it cannot be
  `comp`'d as a file. Verified instead by two live runs' screen output
  independently decoded via `vice_memory_read` and diffed by this agent --
  a manual/live comparison, not an automated regression, and documented as
  such rather than silently claimed as equivalent-strength evidence to the
  file-based checks.

## Representative Fixtures (user-confirmed 2026-08-12)

| Fixture | Why | Disk |
| --- | --- | --- |
| `casmhello.s` | Smallest real static fixture; cheap baseline | any disk with free directory capacity (not `test.d64`, its directory is full) |
| `casmopall.s` | 151-statement exhaustive-opcode fixture from WP60; widest single-file opcode/mode coverage, already has a trusted `.ref` for an independent sanity check alongside the self-compare | `casm_opcode_test.d64` (491 blocks free) |
| `banner.s` (or `dash.s`) | Real multi-file relocatable production source with symbols and an R6 table -- proves determinism holds for relocation output, not just flat static PRG bytes | `command64_casm_utils.d64` (245 blocks free) |
| One of the above under `/M /L` | Extends the proof to listing and map output per WP61's own charter | same disk as the chosen source |

## FORCE_ABS Two-Pass Closure (residual item 1)

**Design:** a small new fixture, `casmfa2p.s`, with one forward-referenced
label whose resolved value lands in the zero-page range (`$00`-`$FF`) used
as a `FORCE_ABS`-flagged operand (e.g. `LDA TARGET+0` or an explicit
absolute-forcing syntax the parser already recognizes per
`parser.s:562-579`). Because `FORCE_ABS` is derived from
`CASM_EXPR_FLAG_SYMBOL_DERIVED` (syntactic -- is the operand symbol-derived
at all) rather than from the symbol's resolved value, the correctness claim
is: Pass 1 measures the instruction as 3 bytes (absolute), Pass 2 re-parses
the same statement from scratch and must independently re-derive the same
`FORCE_ABS` flag and therefore emit the same 3-byte absolute opcode, even
though the label now resolves to a zero-page-range value. This has never
been proven end-to-end in a real two-pass run -- only via a hand-built
single-pass unit case (`casm_pass1.s:470-517`, `p1back1`).

- Independently author expected bytes by hand (not derived from production
  tables), matching every other WP60/61 fixture's non-circularity rule.
- Assemble once, `comp` against the independently authored `.ref`.
- Additionally include it as a third leg of the determinism self-compare
  (assemble twice, `comp` the two outputs against each other) so this
  increment produces both an absolute-correctness proof and a
  determinism proof for the same fixture in one pass.

## Source Extent Closure (residual item 2)

**Design, chosen for disk economy:** one new fixture, `casmsrcmax.s`,
exactly 65,535 bytes of valid CASM source (e.g. a long repeated sequence of
single-byte `.BYTE` directives or comment-padded no-op lines -- exact
content decided at Increment 6 activation, structurally reviewed before
generation). ~259 blocks on a 1541 disk.

- **Accept case:** `casm casmsrcmax.s /o:x.prg` alone -- expect
  `CASM: INPUT VALIDATED`, proving the exact 65,535-byte combined extent is
  accepted (`CASM_SOURCE_VMM_MAX_BYTES = 65535`, `common.inc:1055`).
- **Reject case:** re-run as `casm casmsrcmax.s casmsrc1b.s /o:y.prg`, where
  `casmsrc1b.s` is a trivial pre-existing 1-byte-class fixture appended as a
  second source file, pushing the *combined* multi-file total to 65,536 --
  expect a clean `CASM_DIAG_*` extent-cap diagnostic (exact code confirmed
  by source trace at increment activation, likely from `slCheckCap` per
  `source.s:369-373`), not a crash or partial commit.
- This reuses `sourceLoad`'s already-documented combined-cap mechanism
  (`source.s:369-373`) instead of requiring a second ~259-block fixture,
  keeping the disk-space cost to one large file.
- **Disk placement:** neither `test.d64` (directory full) nor
  `casm_overflow_test.d64` (7 blocks free) can hold this. Requires either a
  new dedicated disk (matching `casm_opcode_test_d64`'s WP60 precedent) or
  joining `casm_listing_test.d64` (38 blocks free -- **not enough**, a
  259-block fixture will not fit there either). A new
  `casm_srcbound_test_d64` (command64, casm, comp, `casmsrcmax.s`,
  `casmsrc1b.s`) is the concrete proposal, sized and reviewed at Increment 6
  activation before creation.

## Symbol/Token Length-32 Closure (residual item 3)

**Design:** no existing `tests/src/casm_lexer/` harness exists (confirmed by
search -- this is a new unit). Following `casm_opcodes.s`/`casm_bounds.s`'s
established precedent of linking only the one module under test:

- New `tests/src/casm_lexer/casm_lexer.s`, linking only `lexer.s` (no
  parser/source/emit/VMM), feeding `CasmLexerState`/token-append calls
  directly, mirroring `casm_bounds.s`'s direct-`emit.s`-call pattern from
  WP60 Increment 6.
- Case 1: a 31-byte token payload (`CASM_TOKEN_TEXT_MAX = 31`,
  `common.inc:473`) -- accept, length recorded as exactly 31 (already
  covered by `casm_symbols.s:434`'s `symlen1` at the *symbol* layer per
  WP60 Increment 2's register, but never at the *lexer* layer that actually
  enforces it -- this closes the layer gap, not a duplicate).
- Case 2: a 32-byte append attempt -- expect `C` set,
  `A = CASM_DIAG_TOKEN_TOO_LONG` (`lexer.s:535`), and the token payload
  left at its pre-overflow state (length still 31, not corrupted or
  silently truncated further).
- Small, narrow harness; no new disk needed (joins an existing
  low-occupancy disk, decided at increment activation from current free-space
  survey, not `test.d64`).

## Empty-Source-File Row: Explicit Re-Scope

Per WP60 Increment 7's live-confirmed finding (`cc1541` errors with
`Unexpected filesize when reading casmsrc0.seq` on a zero-byte SEQ write
attempt) and WP60 Increment 9's audit, this row has zero tooling path to
exercise today. This plan proposes closing it as **"satisfied by explicit
re-scope"** per the WP60 completion criteria's own allowance (a boundary row
may be closed by re-scoping, not only by adding a test) -- not silently
dropped, not carried forward a third time. If a future WP builds a
different fixture-authoring path (e.g. a host-side raw sector writer
bypassing `cc1541`), this row can be revisited then.

## ABI, Storage, and Behavioral Effects

- No production zero-page or BSS allocation is planned by the determinism
  or FORCE_ABS/length-32/extent verification work itself.
- No production change is pre-authorized (see Frozen Scope). If any spot-
  check discloses a genuine defect, this section and the plan's Stop
  Conditions govern -- fix only after separate approval.
- CASM version remains `0.2.2` through implementation and verification.

## Harness and Disk Architecture

- New `tests/src/casm_lexer/casm_lexer.s` (length-32 closure).
- New fixture `casmfa2p.s` + independently authored `.ref` (FORCE_ABS
  closure), generated via the existing
  `cmake/GenerateCasmTestFixtures.cmake` pattern.
- New fixtures `casmsrcmax.s` (~259 blocks) and reuse of an existing 1-byte
  fixture (source-extent closure).
- Possible new `casm_srcbound_test_d64` disk if no existing disk has
  sufficient free space at increment activation (re-survey before creating
  a new disk, since builds since WP60 may have changed free-block counts).
- Determinism increments (2-3) need no new harness source at all -- they
  are live-VICE CLI/`comp` sequences against already-existing fixtures
  (`casmhello.s`, `casmopall.s`, `banner.s`/`dash.s`), run twice per
  fixture. If the user prefers a permanent recorded regression (e.g. a
  small host-side or in-VICE script) over a one-time manual live sequence,
  that is a design choice to confirm at Increment 2 activation, not assumed
  here.

## Failure and Cleanup Contracts

- Each live self-compare run uses unique output names per attempt and does
  not leave a partial/half-written PRG or `.LST` on a diagnostic exit,
  matching every prior WP's contract.
- The `casm_lexer.s` harness resets `CasmTokenRecord`/lexer scratch state
  between cases; a failed case is not counted as covered.
- Native `comp` mismatches (for either self-compare or `.ref`-comparison
  legs) are stop conditions -- never edited or waived without root-cause
  analysis.

## Verification Method

### Static

- Confirm `FORCE_ABS`'s derivation site (`parser.s:562-579`) is genuinely
  re-executed per statement per pass (not cached across passes) before
  claiming the two-pass fixture is a meaningful test, not a foregone
  conclusion.
- Confirm `CASM_SOURCE_VMM_MAX_BYTES`/`slCheckCap`'s combined-cap logic
  (`source.s:369-373`) before generating the extent fixtures, to pick the
  exact byte counts that land on the true boundary.
- Confirm `lexerTokenAppend`'s exact comparison (`cpx #CASM_TOKEN_TEXT_MAX`,
  `lexer.s:527`) to pick 31/32 as the true accept/reject pair.

### Build

- Build every new/changed narrow target, any new disk, `image_d64`, and the
  unrestricted build, mirroring WP60 Increment 8's consolidated pattern.
- No-change rebuild proof after the final increment.

### Live VICE

Follow `.agents/workflows/vice-mcp-testing.md`, with particular attention to
two mistakes this agent made twice during WP60 and must not repeat:

- **Underscore dispatch:** any harness/program name containing `_` must be
  typed with the literal segments via `vice_keyboard_type` and the
  underscore itself sent as PETSCII `$A4` via `vice_keyboard_petscii`, one
  call per segment, never a single `vice_keyboard_type` call containing a
  literal ASCII `_`.
- **Disk selection:** confirm free block/directory-entry capacity via
  `vice_disk_list` *before* attempting any new output write, especially the
  ~259-block extent fixture and its outputs -- do not default to `test.d64`
  or `casm_overflow_test.d64` for anything that writes new files.

## Expected Files

Planned test/build changes:

- `tests/src/casm_lexer/casm_lexer.s`
- `tests/src/casm_lexer/BUILD_TEST_CASM_LEXER` (generated)
- New fixtures: `casmfa2p.s` (+ `.ref`), `casmsrcmax.s`
- `cmake/GenerateCasmTestFixtures.cmake`
- `CMakeLists.txt`
- Possibly a new `casm_srcbound_test_d64` disk target

Planned records:

- this plan
- a frozen Increment 1 determinism/spot-check register under `brain/reviews/`
- WP61 walkthrough under `brain/walkthroughs/`
- `brain/task.md`, `wiki/tasks/casm.md`, `CHANGELOG.md` (only if a
  production change occurs), `brain/MEMORY.md` (on completion)

No production source change is planned. `src/external/casm/casm.s`'s
`VERSION_STAGE` changes only if WP61 ends with a production change to bump
against (per the user's 2026-08-12 confirmation) -- otherwise this WP closes
at `0.2.2`, matching WP56's own precedent (planning/verification-only WPs
do not bump version).

## Atomic Increments

### Increment 1 - Freeze scope and spot-check register

- Record this plan's 4-item disposition (FORCE_ABS, extent, length-32,
  empty-file re-scope) as a frozen register, one row each, mirroring WP60
  Increment 2's register format (required boundary / evidence / strength /
  disposition).
- Confirm current free-block/directory-entry state on every disk this plan
  might touch (re-survey; builds since WP60 may have shifted free space).
- Request user approval before any fixture or harness source is written.

### Increment 2 - Determinism proof: PRG/R6

- Live dual-assemble `casmhello.s`, `casmopall.s`, and `banner.s`/`dash.s`
  each to two independently named outputs; `comp` each pair.
- For `casmopall.s`, additionally `comp` one of the two runs against the
  existing trusted `casmopall.ref` as a sanity cross-check alongside the
  self-compare.
- Record exact commands, disks, and `comp` results.

### Increment 3 - Determinism proof: listing and map

- Live dual-assemble one representative fixture under `/L`; `comp` the two
  `.LST` files.
- Live dual-assemble the same fixture under `/M`; decode and diff both
  runs' screen output manually (documented as live/manual evidence, not an
  automated regression).
- Explicitly avoid any exactly-1-byte source in these fixtures, given the
  known (separately tracked) phantom-EOF-byte defect.

### Increment 4 - FORCE_ABS two-pass closure

- Add `casmfa2p.s` and its independently authored `.ref`.
- Assemble once, `comp` against `.ref`; assemble twice more, `comp`
  self-compare.
- No production change unless a genuine defect is disclosed and separately
  approved.

### Increment 5 - Symbol/token length-32 closure

- Add `tests/src/casm_lexer/casm_lexer.s` with the 31-accept/32-reject
  cases described above.
- Build narrowly, run live before proceeding.

### Increment 6 - Source extent closure

- Re-survey disk free space; create `casm_srcbound_test_d64` if needed.
- Generate `casmsrcmax.s` (~259 blocks); confirm the exact accept/reject
  byte counts against `slCheckCap`'s real logic first.
- Run the accept case, then the combined-file reject case; record the
  returned diagnostic.

### Increment 7 - Consolidated build and compatibility verification

- Build every new/changed target, any new disk, `image_d64`, and the
  unrestricted build; no-change rebuild proof.
- Re-run every harness touched or added by Increments 2-6 live, from a
  clean rebuild, mirroring WP60 Increment 8's pattern exactly (including
  its underscore-dispatch and disk-selection lessons).

### Increment 8 - Audit and walkthrough

- Reconcile the frozen Increment 1 register against what Increments 2-6
  actually closed, row by row.
- Record any defect found (expected: none, given the frozen-scope
  no-production-change default), unchanged contracts, metrics, and any new
  residual risk.
- Synchronize `brain/task.md`, `wiki/tasks/casm.md`, `brain/MEMORY.md`, and
  `CHANGELOG.md` (only if a production change occurred).
- Request explicit WP61 completion approval.

### Increment 9 - Version gate (conditional)

- If and only if a production change occurred during Increments 2-6 (found
  and approved), bump `VERSION_STAGE` `0.2.2` -> `0.2.3` after completion
  approval, build once, prove the delta is version/build-banner bytes only,
  build again for no-change stability, live-verify the new banner.
- If no production change occurred, this increment is skipped by design
  (matching WP56's precedent) and WP61 closes at `0.2.2` -- explicitly
  recorded as a deliberate non-bump, not an oversight.

## Stop Conditions

Stop and request user direction if:

- a determinism self-compare mismatches for any fixture -- this would be a
  correctness-class production defect, not a coverage gap;
- `FORCE_ABS` genuinely re-derives differently between Pass 1 and Pass 2 for
  the same statement;
- the source-extent or length-32 boundary constants
  (`CASM_SOURCE_VMM_MAX_BYTES`, `CASM_TOKEN_TEXT_MAX`) differ from what this
  plan assumes (65535, 31) at increment activation;
- a new disk is required and cannot be sized without displacing existing
  coverage;
- work expands into WP56's broader unnamed register items, WP62 systematic
  documentation sync, or WP63's phase completion gate;
- VICE cannot be started or identified under the required workflow;
- any dispatch requires an underscore and the agent is about to send it via
  plain `vice_keyboard_type` -- stop and use `vice_keyboard_petscii` for
  that byte instead, given this exact mistake occurred twice during WP60.

## Completion Criteria

WP61 completes only when:

1. determinism is proven (self-compare, byte-identical) for PRG/R6 across
   3 representative fixtures and for listing across at least 1;
2. the `/M` symbol map is shown identical across two runs of at least 1
   fixture, with the manual/live nature of that evidence explicitly noted;
3. `FORCE_ABS` stability across a genuine two-pass real assembly is proven,
   not just asserted at the unit level;
4. the source-extent accept (65,535) and reject (65,536 combined) boundary
   is proven with the correct diagnostic on rejection;
5. symbol/token name-length-32 rejection is proven at the lexer layer with
   the correct diagnostic and unmodified token state;
6. the empty-source-file row is explicitly closed by re-scope, not left as
   an unresolved carry-forward;
7. all changed and affected regression targets pass live and return to
   shell, including a full clean/unrestricted rebuild;
8. no production change occurred, or any that did is disclosed, approved,
   and reflected in a version bump per Increment 9;
9. records, walkthrough, Taskwarrior (if a task is created upon plan
   approval), and DOX (only where owned facts changed) agree;
10. the user explicitly approves completion.

## Approval Decision

Approve this nine-increment WP61 plan and activate Increment 1 only, or
request changes. Approval creates a WP61 Taskwarrior task dependent on
completed WP60 (task 40) and updates task records; it does not authorize
later increments before their individual gates.
