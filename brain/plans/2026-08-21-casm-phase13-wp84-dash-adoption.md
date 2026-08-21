---
feature: casm-phase13-wp84-dash-adoption
created: 2026-08-21
status: proposed
taskwarrior: 7a1fb5c0-d8d8-4cfc-bfc0-e9618525e571 (task "WP84: DASH
  adoption of .RES", project casm.phase13)
depends-on: CASM Phase 13 WP81/WP82/WP83, all complete and merged into
  feature/casm-phase13
---

# Plan: CASM Phase 13 WP84 - DASH Adoption of .RES

## Status

**Approved 2026-08-21.** All three Scoping Decisions confirmed (see
below). Implementation authorized on `feature/casm-phase13-wp84`.

Parent plan: `brain/plans/2026-08-21-casm-phase13-data-construction-
directives.md`. Branch: `feature/casm-phase13-wp84`, to be cut from
`feature/casm-phase13` (WP81/82/83 already merged in).

## Objective

Convert DASH's real source (`src/external/dash/`) to use `.RES` in place
of long hand-written zero-byte `.BYTE` lists, at every genuine site
identified by the master plan's own research pass, then regenerate
`dash.ref.hex` from a real native-CASM-on-hardware run, closing the
provenance gap the same way WP71 did for Phase 12 syntax. Runtime bytes
must not change — this is a syntax adoption, not a behavior change.

**Not in scope** (both narrowed from the master plan's original framing,
per findings below, each confirmed with the user):

- `.ASSERT` DASH adoption. The master plan's own targets
  (`DISPATCHRETURN`/`DISPATCHRETURNMINUSONE`'s offset-by-one invariant,
  the buffer-size checks) are all **equality** invariants. WP83 found
  CASM's expression grammar has no comparison operator at all, so
  `.ASSERT` can only test nonzero-arithmetic truthiness — it cannot
  express "A must equal B" (the naive `A - B - 1` expression is zero
  exactly when the invariant *holds*, the opposite of `.ASSERT`'s
  nonzero-means-pass convention, and there is no arithmetic identity that
  inverts "is zero" into "is true" without a real comparison operator).
  Deferred until a comparison operator exists as separate, future CASM
  work — confirmed with the user 2026-08-21.
- `.FILL` DASH adoption. **ca65 has no `.FILL` directive at all**
  (verified directly: `ca65 -o test.o test.s` on a file containing
  `.fill 3, $40` fails with `'.FILL' is not a recognized control
  command`). Using CASM's `.FILL` for `BORDERROW`'s nonzero fill run
  would break the dual-assembler cross-check `AGENTS.md` requires.
  **`.RES` already covers this case**: CASM's own `.RES count, value`
  (WP81) takes an optional explicit fill value, and ca65's `.RES`/`.res`
  accepts the identical two-argument form — independently verified
  end-to-end (`ca65` + `ld65` against a `type = ro` segment) to emit the
  literal fill bytes into the output, not just reserve BSS space. So
  `BORDERROW` is adopted as `.RES`, not `.FILL`; `.FILL` gets no DASH
  adoption this WP, joining `.ALIGN`/`.INCBIN` on the already-waived list.
- `.ALIGN`/`.INCBIN` DASH adoption. Already explicitly waived by the
  master plan (no genuine use case in DASH) — unaffected by this WP.

## Research Summary

A pre-planning research pass (this session, 2026-08-21) re-surveyed
`src/external/dash/ddata.s` against the master plan's original candidate
list, since line numbers/content may have shifted since Phase 12's own
WP71 adoption pass:

1. **All four originally-identified `.RES` candidates still exist,
   confirmed at their current lines**:
   - `FMTBUF` (`ddata.s:29-30`): 5 zero bytes.
   - `SYSINFOBUF` (`ddata.s:74-77`): 24 zero bytes.
   - `APPBUF` (`ddata.s:165-168`): 24 zero bytes.
   - `VMMBUFFER` (`ddata.s:342-358`): 256 zero bytes (16 rows of 16).
   Each already carries a comment naming CASM's then-missing reserve
   directive as the reason for the manual zero-fill (e.g. `ddata.s:339-
   341`: "CASM HAS NO RESERVE-SPACE DIRECTIVE... SO THIS IS 256 LITERAL
   ZERO BYTES") — these comments become stale once `.RES` lands and are
   removed/updated as part of this WP.
2. **`BORDERROW` (`ddata.s:43-47`)**: 40 bytes, `$5B` (corner) + 38x`$40`
   (repeated screen-code fill) + `$5B` (corner). The master plan's own
   research called this a `.FILL` candidate; per the ca65-incompatibility
   finding above, it converts to `.BYTE $5B` / `.RES 38,$40` / `.BYTE
   $5B` instead — byte-identical output, dual-assembler-safe.
3. **DASH's dual-assembler contract (`AGENTS.md`) doesn't yet document
   `.RES`/Phase 13 syntax at all** — it was last updated for WP71's
   Phase 12 adoption. This WP updates it the same way WP71 did for its
   own syntax (see that plan's own Research Finding 1: "the contract's
   restrictions existed only because native CASM couldn't do it yet; the
   dual-assembler intersection widens to match").
4. **`dash.ref.hex`'s regeneration is a heavier, hands-on-hardware step**,
   per `AGENTS.md`'s "Native Assembly Workflow"/"Artifact Provenance"
   sections and WP71's own walkthrough precedent: native CASM assembles
   `DMAIN.S` (whose own `.INCLUDE` chain pulls in the other six sources,
   `DDATA.S` last) on `command64_casm_utils.d64` under VICE with a real
   REU, `COMP`-verified against the independent `dash_ref` (ca65) build,
   then `scripts/build_dash_manifest.py --cross-check` regenerates the
   reviewed manifest. This is not a fixture-based WP like WP81-83 — the
   "fixture" IS the real production artifact.
5. **No source or manifest changes needed for DASH's non-`ddata.s` files**
   — all five conversion sites live in `ddata.s` alone; `dmain.s`,
   `dscr.s`, `dfmt.s`, `dsys.s`, `dapp.s`, `dvmm.s` are untouched.

## Scoping Decisions (need user confirmation before implementation)

### Decision 1: explicit fill value on the all-zero `.RES` sites, or rely on the default?

`FMTBUF`/`SYSINFOBUF`/`APPBUF`/`VMMBUFFER` are all currently all-zero.
CASM's `.RES count` (no second operand) already defaults to `0`, and
ca65's `.res count` (no fillval) independently verified to also emit
literal `$00` bytes (not BSS) in a `type = ro` segment — so a bare
`.RES 5` etc. is already byte-identical and dual-assembler-safe with no
explicit value needed.

- **(a) Bare `.RES count`** (no explicit `0`) for the four all-zero
  sites, explicit `.RES 38, $40` only where a real nonzero value is
  needed (`BORDERROW`). Shorter source, matches CASM's own documented
  default-value convention directly.
- **(b) Always spell out `.RES count, 0`** explicitly on every site,
  including the all-zero ones, for uniform readability/self-documentation
  regardless of which assembler reads it.

**Confirmed: (a)** — shorter, and the default-value behavior is
already an audited, verified CASM/ca65 convention (WP81's own
`.RES`/default-`0` design).

### Decision 2: remove or update the now-stale "CASM has no reserve
directive" comments?

`ddata.s`'s existing comments at `FMTBUF`/`SYSINFOBUF`/`APPBUF`/
`VMMBUFFER` explain *why* each is a manual zero-byte list (CASM lacked
`.RES` at the time). Once converted, these comments describe a
now-resolved limitation.

- **(a) Remove them entirely** — the `.RES` line is self-explanatory,
  matching this project's own "no comments unless the WHY is non-obvious"
  convention once the workaround they explained no longer exists.
- **(b) Replace with a one-line note** identifying which Phase/WP adopted
  `.RES` here (e.g. "WP84: converted from a manual zero-byte list").

**Confirmed: (a)**, consistent with the general instruction to
avoid comments that explain removed code.

### Decision 3: `AGENTS.md` update scope

Mirroring WP71's own precedent (its Research Finding 1: the dual-assembler
contract's restrictions existed only because CASM lacked the feature, not
because ca65 does): update `AGENTS.md`'s "Dual-Assembler Subset" bullet
list to note that `.RES` (with or without an explicit fill value) is now
part of the shared subset, and update the "Expressions are bounded" bullet
or add a new one for this. Confirm this is in scope for WP84 itself
(matching WP71's own bundling of the same two pieces: syntax adoption +
documentation contract update) rather than a separate follow-up.

**Confirmed: in scope**, same bundling WP71 used.

## Technical Design

### Conversion sites (`src/external/dash/ddata.s`)

| Site | Current | Converts to |
| --- | --- | --- |
| `FMTBUF` | `.BYTE 0, 0, 0, 0, 0` | `.RES 5` |
| `SYSINFOBUF` | 3 `.BYTE` rows, 24 zero bytes | `.RES 24` |
| `APPBUF` | 3 `.BYTE` rows, 24 zero bytes | `.RES 24` |
| `BORDERROW` | 4 `.BYTE` rows, `$5B`+38x`$40`+`$5B` | `.BYTE $5B` / `.RES 38, $40` / `.BYTE $5B` |
| `VMMBUFFER` | 16 `.BYTE` rows, 256 zero bytes | `.RES 256` |

No relocation interaction for any site (matches `.RES`'s own design --
inert filler, never calls `relocRecord` on either assembler side; ca65's
`.res` in a non-BSS segment is equally inert with respect to its own
relocation table for a pure fill).

### `AGENTS.md` update

Add `.RES` to the documented dual-assembler-safe subset (Decision 3),
following WP71's own precedent for how it recorded Phase 12 syntax
adoption in this same file.

### `dash.ref.hex` regeneration

Follow `AGENTS.md`'s existing "Native Assembly Workflow" verbatim (same
steps WP71's walkthrough recorded):

1. Boot `command64_casm_utils.d64` (carries `casm`, `comp`, the seven
   real DASH sources as SEQ, and the `dash_ref` ca65 cross-check as a PRG)
   under VICE with a real REU attached.
2. `CASM DMAIN.S /O:DASH.PRG` (native assembly; `DMAIN.S`'s own
   `.INCLUDE` chain pulls in the updated `DDATA.S`).
3. `COMP DASH.PRG DASH.REF` -- expect `FILES COMPARE OK` against the
   independent ca65 build.
4. `scripts/build_dash_manifest.py --cross-check build/dash_ref.prg` on
   the host, extracting the verified native bytes and regenerating
   `dash.ref.hex` with fresh `source_sha256` entries for all seven
   sources. No `--allow-host-bytes`.
5. Relocation spot-check at `$3800`/`$5000`/`$9000` (WP71's own three
   addresses), confirming the dashboard still renders and dispatches
   correctly at each.

## Atomic Increments

1. **Source conversion**: edit `ddata.s`'s five sites per the table
   above; remove/update the now-stale explanatory comments (Decision 2).
   No behavior change intended -- pure syntax substitution.
2. **`AGENTS.md` update**: document `.RES` in the dual-assembler subset
   (Decision 3).
3. **ca65 cross-check build**: `dash_ref` (ca65) builds clean against the
   edited source -- proves the dual-assembler subset claim before
   spending any hardware/VICE time.
4. **Native CASM assembly + COMP**: real native-CASM run under VICE
   (`command64_casm_utils.d64`), `COMP DASH.PRG DASH.REF` expect `FILES
   COMPARE OK`. Any mismatch is a Stop Condition (see below) -- pause and
   investigate before regenerating the manifest.
5. **Manifest regeneration**: `build_dash_manifest.py --cross-check`,
   confirm the new `dash.ref.hex` byte-count and hashes match the
   pre-conversion manifest exactly (syntax-only change must produce
   identical shipping bytes) -- same `FILES COMPARE OK`-then-diff
   precedent WP71's own walkthrough used ("the syntax pass changed
   nothing observable").
6. **Relocation spot-check**: `$3800`/`$5000`/`$9000`, confirm the
   dashboard renders/dispatches correctly at each (WP71's own three
   addresses).
7. **Regression**: rebuild `image_d64` (production) and confirm a
   no-change rebuild is stable; re-run the CASM regression witnesses
   (`test_casm_expr`/`test_casm_pass1`/`test_casm_frame`) untouched by
   this WP, confirmed clean as a baseline sanity check.
8. **Consolidated walkthrough**: record every step above with live
   evidence in `brain/walkthroughs/`, submitted for user sign-off.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/dash/ddata.s` | Modify (five `.RES` conversions) |
| `src/external/dash/AGENTS.md` | Modify (dual-assembler subset documentation) |
| `src/external/dash/dash.ref.hex` | Modify (regenerated manifest, new `source_sha256` entries) |

No `CMakeLists.txt`/fixture-generation changes expected -- this WP edits
DASH's own real source, not a CASM test fixture.

## Stop Conditions

- The ca65 `dash_ref` build fails against the edited source (would mean
  Decision 1/2's `.RES` usage isn't actually dual-assembler-safe as
  verified -- pause and re-investigate before any hardware time is
  spent).
- `COMP DASH.PRG DASH.REF` reports a mismatch (any byte difference means
  this "syntax-only" change actually altered output -- a real defect,
  not expected).
- The regenerated manifest's byte count or content differs from the
  pre-conversion `dash.ref.hex` in any way.
- Relocation spot-check fails at any of the three addresses.
- A no-change `image_d64` rebuild changes any artifact.
- A genuinely new defect is discovered outside this WP's own scope:
  disclose and defer as a separate follow-up (default), do not fix inline
  unless explicitly directed in the moment.

## Documentation, Task, and DOX Updates

- Taskwarrior: WP84 task created under the Phase 13 parent on approval of
  this plan.
- `wiki/tasks/casm.md`/`brain/task.md`: WP84 entry, updated at completion.
- `src/external/dash/AGENTS.md`: updated per Decision 3.
- No `CHANGELOG.md`/`KNOWLEDGE.md` update yet -- those land with WP85
  (the master plan's own whole-phase completion gate).

## Completion Gate

- All five `.RES` conversions live-verified: ca65 cross-check clean,
  native CASM assembly COMP-identical to the ca65 reference.
- Regenerated `dash.ref.hex` proven byte-identical to the pre-conversion
  manifest (syntax-only change, no observable difference).
- Relocation spot-check clean at `$3800`/`$5000`/`$9000`.
- `AGENTS.md` updated to document `.RES` in the dual-assembler subset.
- Full production rebuild (`image_d64`) confirmed stable, no-change
  rebuild verified.
- CASM's own regression witnesses (untouched by this WP) confirmed clean
  as a sanity baseline.
- Walkthrough recorded in `brain/walkthroughs/`.
- User explicitly approves closing WP84.

## Progress

- 2026-08-21: Plan drafted after re-surveying `ddata.s`'s five candidate
  sites (confirmed all still present at their expected lines) and
  independently verifying two things not previously checked: (1) ca65 has
  no `.FILL` directive at all (`'.FILL' is not a recognized control
  command`), so `BORDERROW`'s nonzero fill run must use `.RES` with an
  explicit value instead, verified byte-identical on both assemblers via
  a standalone `ca65`+`ld65` test; (2) `.ASSERT`'s DASH targets are all
  equality invariants CASM's comparison-operator-free expression grammar
  cannot express (carried over from WP83's own finding), so `.ASSERT`
  adoption is deferred entirely, not attempted this WP. Both narrowings
  confirmed with the user before this plan was finalized. Three Scoping
  Decisions drafted for confirmation: (1) bare `.RES count` vs. explicit
  `.RES count, 0` on the all-zero sites, (2) remove vs. update the
  now-stale explanatory comments, (3) bundling the `AGENTS.md` dual-
  assembler-subset documentation update into this WP (mirroring WP71's
  own precedent).
- 2026-08-21: All three Scoping Decisions confirmed by the user: (1) bare
  `.RES count` on the all-zero sites, (2) remove the stale comments
  entirely, (3) bundle the `AGENTS.md` update into this WP. Plan approved.
  Branch `feature/casm-phase13-wp84` cut from `feature/casm-phase13`
  (WP81/82/83 merged in). Taskwarrior task created (project
  `casm.phase13`, `+wp84`).
- 2026-08-21: Increment 1 (source conversion) complete. All five
  `ddata.s` sites converted: `FMTBUF` -> `.RES 5`, `SYSINFOBUF` -> `.RES
  24`, `APPBUF` -> `.RES 24`, `BORDERROW` -> `.BYTE $5B` / `.RES 38, $40`
  / `.BYTE $5B`, `VMMBUFFER` -> `.RES 256`. **Correction to the plan's own
  Research Summary**: on closer reading, only `VMMBUFFER`'s comment
  actually explained the "CASM has no reserve directive" workaround
  (trimmed per Decision 2); `FMTBUF`/`SYSINFOBUF`/`APPBUF`'s comments are
  purely descriptive (what the buffer is for, not why it's a manual
  zero-list) and were left untouched, not four stale comments as
  originally assumed. `dash_ref` (ca65) builds clean against the edited
  source — confirms the dual-assembler subset claim (Increment 3's own
  check, done early as a cheap sanity confirmation of Increment 1).
