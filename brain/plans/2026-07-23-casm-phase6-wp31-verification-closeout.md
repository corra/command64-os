---
feature: casm-phase6-wp31-verification-closeout
created: 2026-07-23
status: complete
---

# Plan: CASM Phase 6B WP31 - Verification, Walkthrough, and Completion Gate

## Objective

WP31 closes the one remaining unchecked item in `wiki/tasks/casm.md`'s Phase
6B Acceptance list ("Symbol table duplicate, undefined, case-sensitive, and
max-length behavior match the frozen contract") with real end-to-end proof
through production `casm.s` — not just the isolated module-level proof
WP27/28 already built — then bundles every CASM Phase 6A/6B fixture and
trusted reference into one final consolidated verification run, records the
walkthrough, and closes the CASM Phase 6B milestone itself. This is
structurally the same kind of work package as WP25 (CASM Phase 6A's own
closeout): it implements no new symbol-table or pass behavior, only exercises
what WP26-30 already built, following the same "verification, walkthrough,
completion gate" shape.

Taskwarrior: `86d8ac7e-0725-44b8-81ae-dcef143a20ad` (WP31); parent CASM
Phase 6B milestone `166e5352-5aa0-45bd-8bee-5baf0e878798` closes when WP31
does.

Prerequisite: WP30 is complete and approved (CASM `0.1.32` build 1130).
Approval of this plan is required before activation or source edits, per the
CASM `AGENTS.md` gate.

## Baseline

- CASM `0.1.32` build 1130. MAIN currently `12191` of `12288` bytes used
  (97 bytes headroom, measured directly via `ld65 -m` at WP30's close).
- Phase 6B Acceptance (`wiki/tasks/casm.md`) has five of six items checked:
  Pass 1 addressing, Pass 2 emission, relative branches from resolved
  symbols, Pass 1/Pass 2 disagreement detection, and byte-identical
  forward/backward-reference output are all done. Only "duplicate, undefined,
  case-sensitive, and max-length behavior" remains unchecked.
- **Undefined** is already proven through real `casm.s` (WP29's `p1undef1`
  fixture: `CASM_DIAG_UNDEFINED_SYMBOL` fires cleanly in Pass 2, no partial
  output left). Not a new fixture for WP31 — just re-confirmed in the final
  consolidated run.
- **Duplicate, case-sensitive, and max-length** have only ever been proven at
  the isolated `symbolsInsert`/`symbolsLookup` level (WP27's
  `symdup1`/`symcase1`/`symlen1`) or, for duplicate specifically, through
  WP28's standalone Pass-1-only `casm_pass1` harness (`p1dup1`) — never
  through production `casm.s`'s real two-pass orchestration.
  `p1dup1.seq` already exists and is already packaged on `test.d64` as
  `p1dup1.s`, and production `casm.prg` is already on the same disk, so
  duplicate-through-real-`casm.s` needs no new fixture file — just a new
  verification step against an existing one (mirroring WP29/30's reuse
  precedent).
- No fixture, ever, has exercised case-sensitive or maximum-length identity
  through real `casm.s`.
- 60 pre-existing Phase 3/4 `.seq` fixtures exist; none has been re-run
  against the two-pass `casm.s` (WP29-30) yet.
- WP30 found a real, previously-latent Phase-4-vintage defect
  (`eiRelative`'s Pass-1 range-check bug) the first time a genuinely new
  fixture category (forward-referenced branches) exercised code that had
  gone unexercised since Phase 4 — this WP treats that as a live precedent,
  not a one-off.

## Dependency Review and Discrepancies Reconciled

1. **A real, non-obvious byte-encoding pitfall: a naive case-sensitivity
   fixture would silently fail to test anything.** `isIdFirst`/`isIdCont`
   (`lexer.s:707-738`, confirmed by direct inspection) accept only
   `CASM_PETSCII_UPPER_A..Z` (`$41-$5A`) or `CASM_PETSCII_SHIFTED_A..Z`
   (`$C1-$DA`) as identifier bytes — plain ASCII lowercase (`$61-$7A`) is
   rejected outright as `CASM_DIAG_INVALID_SOURCE_BYTE`. WP27's own
   `symcase1` fixture (`.byte "Case"` / `.byte "CASE"` in a ca65-*assembled*
   `.s` harness) relies on ca65's `-t c64` charmap to convert those quoted
   literals automatically — empirically confirmed here by compiling both
   strings directly: `"Case"` assembles to `C3 41 53 45` (uppercase source
   letters shift to `$C1-$DA`, lowercase source letters map to unshifted
   `$41-$5A`) and `"CASE"` to `C3 C1 D3 C5` (all shifted). **`.seq` fixtures
   are raw text files written directly by `cmake/GenerateCasmTestFixtures.cmake`'s
   `file(WRITE ...)` and read byte-for-byte by CASM's own lexer at
   runtime — no ca65 charmap ever touches them.** A naive `casmcase1.seq`
   written with ordinary mixed-case ASCII text (e.g., ``"Loop"``) would
   therefore *not* test case-sensitivity at all — it would fail immediately
   with `CASM_DIAG_INVALID_SOURCE_BYTE` on the first lowercase byte, before
   ever reaching the symbol table. **Resolved:** the fixture generator
   constructs the shifted-case variant explicitly via `string(ASCII <code>
   ...)` (the same technique already used elsewhere in the same file for
   CR/LF bytes), producing genuine `$C1-$DA`-range bytes — Contract item 1
   below gives the exact derivation.
2. **Symbol-table-full is out of WP31's scope, per the user's confirmed
   decision.** Neither the master plan's Phase 6B fixture list nor the
   `wiki/tasks/casm.md` acceptance line names it (both say "duplicate,
   undefined, case-sensitive, and max-length" — four items, not five).
   WP27's own `symfull1` already exhaustively proved `symbolsInsert`'s
   exhaustion behavior with 512 real inserts through the real API, and the
   *only* thing a new end-to-end 513-real-label fixture through `casm.s`
   could add — proof that `casmRunPass`'s label-statement dispatch correctly
   propagates a `symbolsInsert` failure up through `startFatalNear` — is
   already proven by the *duplicate*-symbol fixture (Contract item 2 below),
   which takes the exact same propagation path with a different diagnostic
   value. Not attempted.
3. **Regression scope against the 60 pre-existing Phase 3/4 fixtures is
   deliberately targeted, not exhaustive, per the user's confirmed
   decision.** Tracing exactly *why* `eiRelative` was vulnerable (it
   computes a *difference* against a live `CasmPc`, which a `$0000`
   placeholder can push arbitrarily far out of range in either direction)
   and confirming no sibling diagnostic shares that shape: `.BYTE`/`.WORD`'s
   `CASM_DIAG_OPERAND_OUT_OF_RANGE` check (`emitByteList`) tests the
   placeholder's high byte directly (`bne eblRange`) — a `$0000` placeholder
   always passes that check (it *is* in range), so it can only under-report
   in `MEASURE` mode, never falsely fail the way `eiRelative` did; Pass 2
   still catches a real out-of-range value for real. No other Phase 4
   diagnostic depends on a live, monotonically-advancing counter the way
   relative-branch displacement does. **Resolved:** a 7-fixture
   representative sample stands in for the full 60, spanning distinct
   diagnostic categories the WP29/30 regression set never touched:
   addressing-mode boundary (`casmzpi2`), numeric-format overflow
   (`casmnumerrh`), directive malformation (`casmorg3`), PC/address-overflow
   boundary (`casmpcovf`), delimiter/syntax error (`casmcma2`), a clean
   zero-page/absolute boundary assembly (`casmzp1`), and the original
   comprehensive addressing-mode acceptance matrix (`casmwp11`). All seven
   already exist and are already packaged on `test.d64` — no new fixture
   files, just re-running already-established cases against the new
   two-pass orchestration.
4. **`casmcma2`'s "partial output" framing may no longer apply literally,
   which is a documentation nuance to confirm, not a defect.** Its original
   Phase 4 comment says "`$01` is emitted BEFORE the failure, so this is
   also a partial-output case" — true under the old single-pass model. Under
   the two-pass model, Pass 1 (`MEASURE`, no output file) hits the same
   `CASM_DIAG_SYNTAX_ERROR` first, before Pass 2 ever runs or
   `fileCreateOutput` is ever called — so the diagnostic still fires
   identically, but the "partial output on disk" characterization is now
   inaccurate (there is no output file at all when this fires, matching
   every other Pass-1-caught syntax error). **Resolved:** the walkthrough
   records this as an observed, harmless behavioral nuance of the
   architecture change, not a regression to investigate further.
5. **MAIN growth is not assumed to be zero, given WP30's own precedent.**
   The plan expects no new production code (the three new/reused fixtures
   exercise only already-implemented behavior), but WP30 demonstrated that a
   never-before-exercised code path can still hide a real defect. Any defect
   found is handled exactly as WP30's was: stop, present the root cause and
   a proposed fix to the user, get explicit approval, then proceed — not
   silently patched.

## Contract / Implementation Details

1. **`tests/fixtures/casm/casmcase1.ref.hex` (new) and its `.seq` source**
   prove case-sensitive identity through real `casm.s`:

   ```text
   Source (.ORG $C000):
     LOOP: NOP              ; unshifted PETSCII: $4C $4F $4F $50
     <shifted-LOOP>: RTS    ; shifted PETSCII:   $CC $CF $CF $D0
     LDA LOOP
     LDA <shifted-LOOP>
   ```

   `LOOP` (unshifted) is defined at `$C000` (`NOP`, 1 byte); the
   shifted-byte-sequence label is defined at `$C001` (`RTS`, 1 byte).
   `LDA LOOP` resolves to `$C000` (`FORCE_ABS` forces absolute, 3 bytes);
   `LDA <shifted-LOOP>` resolves to `$C001` (3 bytes). If case-sensitivity
   were ever broken (the two names collapsed into one symbol), this would
   surface either as `CASM_DIAG_DUPLICATE_SYMBOL` at the second label
   statement or as both `LDA`s resolving to the same address — either way
   a mismatch against the trusted reference:

   ```text
   00 C0           PRG load-address header ($C000, little-endian)
   EA              NOP        (at $C000, defines unshifted LOOP)
   60              RTS        (at $C001, defines shifted-byte-sequence LOOP)
   AD 00 C0        LDA $C000  (resolves the unshifted name)
   AD 01 C0        LDA $C001  (resolves the shifted-byte-sequence name)
   ```

   `cmake/GenerateCasmTestFixtures.cmake` constructs the shifted-byte label
   via `string(ASCII 204 ...)`/`string(ASCII 207 ...)`/`string(ASCII 208
   ...)` (empirically confirmed: unshifted `L`/`O`/`P` = `$4C`/`$4F`/`$50`;
   `+$80` = `$CC`/`$CF`/`$D0`), concatenated into the label text at both its
   definition and its `LDA` reference sites. The unshifted `LOOP` needs no
   special construction — plain text in a CMake string already produces
   valid unshifted-PETSCII bytes (numerically identical to standard ASCII
   uppercase).
2. **`tests/fixtures/casm/casmmaxid1.ref.hex` (new) and its `.seq` source**
   prove the 31-byte maximum-length identifier round-trips correctly through
   real `casm.s`:

   ```text
   Source (.ORG $C000):
     <31-character label>: RTS
     LDA <31-character label>
   ```

   The label (31 `A` characters, generated via `string(REPEAT "A" 31 ...)` —
   plain unshifted-uppercase text, no special byte construction needed)
   resolves to `$C000` (`RTS`, 1 byte); `LDA` resolves to `$C000` (absolute,
   3 bytes):

   ```text
   00 C0           PRG load-address header ($C000, little-endian)
   60              RTS        (at $C000, defines the 31-character label)
   AD 00 C0        LDA $C000  (resolves the 31-character label)
   ```
3. **Duplicate-symbol through real `casm.s` reuses `p1dup1.seq` unmodified**
   (already exists, already packaged as `p1dup1.s`, per the user's confirmed
   reuse precedent from WP29/30): `CASM P1DUP1.S` must print `CASM:
   DUPLICATE SYMBOL` and leave no output PRG on disk.
4. **Undefined-symbol through real `casm.s` re-confirms `p1undef1.seq`**
   (already exists and already proven in WP29 — re-run here only as part of
   the final consolidated matrix, not new work).
5. **Seven pre-existing Phase 3/4 fixtures form the targeted regression
   sample** (Dependency Review item 3): `casmwp11`, `casmcma2`, `casmorg3`,
   `casmzp1`, `casmzpi2`, `casmpcovf`, `casmnumerrh` — all already exist and
   are already packaged; no new files, just re-running each against the
   current two-pass `casm.s` and confirming the same outcome Phase 4/5
   already established.
6. **`CASM_REF_NAMES`/`CASM_TEST_FIXTURES` in `CMakeLists.txt`** gain
   `casmcase1`/`casmmaxid1` (both new `.ref.hex` + `.seq`); no other
   `CMakeLists.txt` change (the reused/regression fixtures are already
   wired).

## Scope

Included:

- `cmake/GenerateCasmTestFixtures.cmake`: new `casmcase1.seq` (shifted-byte
  construction via `string(ASCII ...)`) and `casmmaxid1.seq`
  (`string(REPEAT "A" 31 ...)`).
- `tests/fixtures/casm/casmcase1.ref.hex`, `casmmaxid1.ref.hex`: new
  trusted-reference manifests.
- `CMakeLists.txt`: `casmcase1`/`casmmaxid1` appended to `CASM_REF_NAMES`;
  `casmcase1.seq`/`casmmaxid1.seq` appended to `CASM_TEST_FIXTURES`.
- The full consolidated verification run (Verification Plan below) covering
  every CASM Phase 6A/6B standalone test harness and every production
  `casm.s` fixture/reference accumulated across WP14 through WP30, plus the
  two new fixtures and the reused `p1dup1`/`p1undef1`.
- Closing the CASM Phase 6B milestone (Taskwarrior parent
  `166e5352-5aa0-45bd-8bee-5baf0e878798`, `wiki/tasks/casm.md`,
  `brain/task.md`, `brain/KNOWLEDGE.md`) upon explicit user approval.
- Any production source fix a newly-discovered defect requires, handled
  exactly as WP30's `eiRelative` fix was — presented to the user before any
  change, applied only with explicit approval, scoped narrowly.

Excluded:

- a new end-to-end symbol-table-full fixture through real `casm.s`
  (Dependency Review item 2, user-confirmed);
- a full re-run of all 60 historical Phase 3/4 fixtures (Dependency Review
  item 3, user-confirmed — the targeted 7-fixture sample stands in);
- CASM Phase 7 or Phase 8 activation — a separate, later gate.

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-23-casm-phase6-wp31-verification-closeout.md` | this document |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify: new `casmcase1.seq`, `casmmaxid1.seq` |
| `tests/fixtures/casm/casmcase1.ref.hex` | Create |
| `tests/fixtures/casm/casmmaxid1.ref.hex` | Create |
| `CMakeLists.txt` | Modify: `CASM_REF_NAMES`, `CASM_TEST_FIXTURES` |
| `src/external/casm/*.s` | Unplanned: only if a newly-discovered defect requires a fix, per explicit user approval (WP30 precedent) |
| `wiki/tasks/casm.md`, `brain/task.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md` | Closeout updates; closes the CASM Phase 6B milestone |

## ABI, Storage, and Runtime Effects

None planned. No new record layout, diagnostic, or exported routine. If a
defect surfaces during verification (per Dependency Review item 5), any
resulting change is scoped, presented, and approved exactly as WP30's
`eiRelative` fix was, and this section is amended in the walkthrough to
record it.

## Verification Plan

The full consolidated matrix, run once at the end after both new fixtures
and the CMake wiring are in place:

1. **Standalone test harnesses** (unchanged since their own WPs; re-run here
   only to confirm nothing regressed): `TEST_CASM_VMM` (7 fixtures),
   `TEST_CASM_SYMBOL` (10 fixtures), `TEST_CASM_PASS1` (7 fixtures),
   `TEST_CASM_PASSCHECK` (2 fixtures), `TEST_CASM_EXPR`.
2. **Production `casm.s` byte-identical trusted references** (10 total):
   `casmemit1`/`casmhello`/`casmmodes`/`casmnum2`/`casmexprn` (Phase 4/5),
   `p1fwd1`/`p1back1`/`p1size1` (WP29), `brfwd1`/`brback1` (WP30) — each via
   `CASM <name>.S` then `COMP <name>.PRG <name>.REF`.
3. **New: `casmcase1`/`casmmaxid1`** — same `CASM` + `COMP` procedure against
   their new trusted references (Contract items 1-2).
4. **Diagnostic fixtures through real `casm.s`:** `p1undef1`
   (`CASM_DIAG_UNDEFINED_SYMBOL`, re-confirmed from WP29), `p1dup1`
   (`CASM_DIAG_DUPLICATE_SYMBOL`, new for WP31), `brrng1`
   (`CASM_DIAG_BRANCH_OUT_OF_RANGE`, re-confirmed from WP30).
5. **Targeted Phase 3/4 regression sample** (Contract item 5): `casmwp11`
   (assembles cleanly), `casmzp1` (assembles cleanly), `casmcma2`
   (`SYNTAX ERROR`, and confirm the partial-output framing no longer
   applies per Dependency Review item 4), `casmorg3` (`SYNTAX ERROR`),
   `casmzpi2` (its established range/addressing-mode diagnostic),
   `casmpcovf` (`ADDRESS OVERFLOW`), `casmnumerrh` (its established
   numeric-overflow diagnostic).
6. Build both relocation bases and `test_image_d64`; confirm a no-change
   rebuild holds `BUILD_CASM` stable before any source edit and increments
   exactly once after (or not at all, if no production source changes).
7. Every failing case is investigated before completion is requested. A
   newly-discovered defect is presented to the user with its root cause and
   a proposed fix before any source is touched, matching WP30's precedent
   exactly — this is the Phase 6B completion gate itself, so nothing is
   waved through.

## Atomic Implementation Increments

1. Add `casmcase1.seq`/`casmmaxid1.seq` to
   `cmake/GenerateCasmTestFixtures.cmake`; hand-derive and write
   `casmcase1.ref.hex`/`casmmaxid1.ref.hex`, self-validating each against
   `hex_manifest_to_bin.py` before wiring them in.
2. Append both to `CASM_REF_NAMES` and `CASM_TEST_FIXTURES` in
   `CMakeLists.txt`; build both relocation bases and `test_image_d64`;
   confirm clean build.
3. Run the full consolidated matrix in VICE (ask the user): standalone
   harnesses, all 10 byte-identical references plus the 2 new ones, the 3
   diagnostic fixtures, and the 7-fixture targeted regression sample.
   Record every result.
4. If any case fails: stop, root-cause it, present the finding and a
   proposed fix to the user (per Dependency Review item 5 and the Stop
   Conditions below), apply only with explicit approval, then re-run the
   full matrix again before proceeding.
5. Update `wiki/tasks/casm.md`'s Phase 6B Acceptance (check the final box)
   and close the CASM Phase 6B milestone section.
6. Apply the version-only completion increment, rebuild, confirm no-change
   rebuild stability, both images pass.
7. Update `brain/task.md`, `brain/KNOWLEDGE.md` (record the final
   consolidated verification, close Phase 0C's Phase 6B arc), `CHANGELOG.md`,
   Taskwarrior (complete WP31 *and* the CASM Phase 6B parent milestone).
8. Draft the walkthrough with the complete matrix result and request
   explicit completion approval — this closes the CASM Phase 6B milestone,
   per this plan's own definition (mirroring WP25's role for Phase 6A).

## Failure and Cleanup

No new failure mode expected. If verification surfaces a genuine defect, it
is handled exactly as WP30's `eiRelative` fix: presented to the user with
root cause and proposed fix before any source change, applied only with
explicit approval, scoped as narrowly as the defect allows. The standalone
test harnesses have no new cleanup requirements (unchanged since their own
WPs).

## Documentation and DOX Closeout

Update this plan, `brain/KNOWLEDGE.md` (a closing note under the Phase
6B arc — 0C.5 through 0C.8 — recording the final consolidated verification
result, or a new Phase 0C.9 section if a defect fix requires recording new
as-built detail, matching WP25/WP30's own precedent for when a closeout WP
finds something worth freezing), `brain/task.md`, `wiki/tasks/casm.md`
(check the final Phase 6B Acceptance box, close the milestone section),
`CHANGELOG.md`, Taskwarrior (WP31 and the CASM Phase 6B parent milestone),
and a new walkthrough. `AGENTS.md` needs no change unless a defect fix
touches a durable local contract (unlikely, per Dependency Review item 5's
expectation of no new production code). Re-read the `src`/`external`/`casm`/
`tests` DOX chain after any source edits.

## Stop Conditions

Stop if WP30 is not complete and approved. Stop if any fixture reveals a
defect whose scope or fix is not small and well-understood enough for the
user to approve fixing in place — matching WP25 and WP30's precedent, a
defect requiring an ABI change or non-obvious redesign gets its own
remediation plan rather than being folded into WP31 silently. Stop if a
further material discrepancy is found during implementation, requiring this
plan to be amended and re-approved.

## Completion Gate

WP31 is complete — and with it, the CASM Phase 6B milestone closes — when:
the full consolidated matrix (standalone harnesses, 12 byte-identical
references, 3 diagnostic fixtures, 7-fixture targeted regression sample)
passes in VICE; any defect found along the way has been fixed with explicit
user approval and re-verified; `wiki/tasks/casm.md`'s Phase 6B Acceptance is
fully checked; the version-only completion increment is verified; both
images build clean with a stable no-change rebuild; and the user explicitly
approves the walkthrough. This closes CASM Phase 6B but does not activate
CASM Phase 7 or Phase 8, which remain separately gated per the master plan.

## Progress

- 2026-07-23: Drafted after WP30 closed (CASM `0.1.32` build 1130). Found a
  real, non-obvious byte-encoding pitfall before writing any fixture: a
  case-sensitivity `.seq` fixture using ordinary mixed-case ASCII text would
  not test anything at all, since CASM's lexer only accepts unshifted
  (`$41-$5A`) or shifted (`$C1-$DA`) PETSCII as identifier bytes and `.seq`
  files receive no ca65 charmap conversion (unlike WP27's `symcase1`, which
  relies on ca65 assembling its quoted string literals). Confirmed the
  correct byte values empirically by compiling `"Case"`/`"CASE"` directly
  with ca65 and inspecting the output. Also traced exactly why WP30's
  `eiRelative` defect was narrowly scoped (a live-counter *difference*
  check, unique to relative branches) to responsibly narrow the regression
  re-verification scope rather than either assuming zero risk or demanding
  an exhaustive 60-fixture re-run. Asked the user two scope questions:
  whether to skip a new end-to-end symbol-table-full fixture as already
  covered by WP27's isolated proof plus the duplicate-symbol fixture's
  shared propagation path, and whether a 7-fixture targeted Phase 3/4
  regression sample can stand in for a full historical re-run given the
  analyzed, narrowly-bounded risk. Both of the user's confirmed decisions
  matched the recommended options. Awaiting user approval before
  implementation begins.
- 2026-07-23: Approved and implemented on `feature/casm-phase6-wp31`. Built
  `casmcase1.seq`/`casmmaxid1.seq` and verified their exact byte content
  directly (the shifted-PETSCII bytes and the 31-character run) before
  writing the trusted-reference manifests. No production source changes
  were needed at all — unlike WP30, this WP's new fixture categories found
  no latent defect; the user ran the full consolidated matrix (5 standalone
  test harnesses, 12 byte-identical trusted references, 3 diagnostic
  fixtures through real `casm.s`, 7-fixture Phase 3/4 regression sample) in
  one pass and confirmed "All tests pass." Version-only completion
  increment applied: final CASM `0.1.33` build 1131, no-change rebuild
  stable, both `image_d64` and `test_image_d64` build clean. Walkthrough:
  `brain/walkthroughs/2026-07-23-casm-phase6-wp31-verification-closeout.md`.
  **WP31 is complete, and with it the CASM Phase 6B milestone closes** —
  Taskwarrior's `command64.casm` project reports 100% complete. CASM Phase 7
  and Phase 8 remain separately gated and unstarted.
