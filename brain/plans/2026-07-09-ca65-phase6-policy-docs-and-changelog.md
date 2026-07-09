# ca65 adoption plan: Phase 6 (policy documentation)

## Context

Phases 1-5 are committed and user-verified working. Phase 6 is the last
phase of `brain/plans/2026-07-08-ca65-adoption-and-spike-migration.md`:
update the policy/reference docs that still describe this project as a
single-toolchain (KickAssembler-only) codebase, now that ca65/ld65 is the
required toolchain for new external apps. This is documentation-only — no
source or CMake changes.

**Verified directly against the tree** (every candidate file read in
full, not assumed from the master plan's wording):

- **The master plan's file list needs two corrections.** It says "AGENTS.md
  (root) and src/AGENTS.md" both contain the phrase "designed for assembly
  using Kick Assembler" — verified by grep, **only `src/AGENTS.md:12`
  actually has this phrase**; root `AGENTS.md`'s Core Directives don't
  mention any specific assembler at all, so it needs no edit. Conversely,
  **`CLAUDE.md`** (not mentioned in the master plan at all, likely written
  before the current `AGENTS.md`/DOX hierarchy existed) has the same stale
  claim ("Assembler: Use Kick Assember contained in `tools/` for building
  assembly") — and since `CLAUDE.md` is what's injected into the
  assistant's own system prompt every session, leaving it stale is a live
  risk to future behavior, not just a documentation gap. Added to scope.
- **`src/AGENTS.md`'s Local Contracts are phrased as a blanket "All source
  files"** rule, but its own Purpose section scopes it to "the core
  assembly files of the command64 operating system" — the blanket phrasing
  predates `src/external/AGENTS.md` existing as a child doc with its own
  Local Contracts. Fix: reword to scope the Kick requirement to core OS
  files, pointing at the child doc for external apps (per DOX: "the closer
  a doc is to the work, the more specific and practical it must be").
- **`src/external/AGENTS.md` is entirely Kick-only today** — its Workflow
  section (`add_external_app`, `BUILD_<NAME>` file, `IMAGE_PRG_TARGETS`)
  has no ca65 equivalent at all. Needs a parallel ca65 workflow section
  pointing at `add_ca65_app` (Phase 3), matching the actual mechanics
  (glob `.s`/`.inc` files, `PRG_SIZE_HEX`, optional `CODE_ALIGN`,
  `.include "command64.inc"` for the shared library).
- **Two Phase-2-deferred policy items land here**, exactly as promised in
  the Phase 2 plan: (1) the `.importzp`/`.exportzp` cross-module
  zero-page guidance (a plain `.import` silently emits a 3-byte absolute
  instead of 2-byte zp instruction for a shared pointer — verified this
  hasn't bitten any current app since none share zp pointers across
  object-file boundaries yet, but it's a real landmine for a future
  multi-file app), and (2) the `$70-$8F` app-private zero-page
  collision policy (`conway` and `label` already collide on `$70`/`$71`
  today, accepted as safe only because they're never concurrently
  resident — this needs to be a documented, not implicit, convention).
- **`src/external/AGENTS.md:14` has a pre-existing inaccuracy** unrelated
  to ca65: it says `BUILD_<APPNAME_UPPER>` "must be maintained in the
  repository root," but every actual `BUILD_*` file lives in the app's own
  `src/external/<name>/` directory (verified — `BUILD_CONWAY`,
  `BUILD_LABEL`, etc. are all there, never at repo root). Since a DOX pass
  is already happening on this exact section, fixing this small
  pre-existing error is in scope (DOX: "Remove stale or contradictory text
  immediately").
- **`docs/codebase-reference.md` has the toolchain claim in two places**:
  §1 Project Overview (`line 50`: "The assembler is **KickAssembler
  v5.25**.", a blanket claim) and needs the toolchain-split note near §13
  "Writing External Programs"/§13.1 (`lines 1629-1688`) per the master
  plan's own placement suggestion — confirmed §13.1's relocation mechanism
  description (`tools/reloc.py`, `aptRelocate`) is genuinely
  toolchain-agnostic already (no Kick-specific claims in that subsection),
  so it needs a clarifying note, not a rewrite. The "Minimal Program
  Template" code block just above §13.1 (`lines 1631-1659`) is pure Kick
  syntax (`#import`, `.encoding "petscii_mixed"`, `* = UserProgStart`) with
  no ca65 equivalent shown — out of scope to add one here (Phase 6 is
  policy notes, not a full parallel tutorial; `src/external/AGENTS.md`'s
  new ca65 workflow section is where that belongs).
- **`tests/AGENTS.md` verified to need no edit** — read in full, it's
  already toolchain-agnostic (no Kick/ca65-specific language at all,
  generically true for both the existing Kick tests and Phase 5's new
  ca65 tests). Left unchanged, noted explicitly rather than silently
  skipped.

## Plan

1. **`CLAUDE.md`**: reword the "Assembler" line to note the split — Kick
   Assembler for the core OS (`src/command64/*`), ca65/ld65 for new
   external apps (`src/external/*`), pointing at `src/external/AGENTS.md`
   for the workflow.
2. **`src/AGENTS.md`**: reword Local Contract line 12 to scope the Kick
   requirement to core OS files specifically, noting external apps are
   governed by `src/external/AGENTS.md`.
3. **`src/external/AGENTS.md`**:
   - Add a new "Workflow for Adding New ca65/ld65 External Applications"
     subsection under Work Guidance, mirroring the existing Kick workflow's
     structure and detail level, describing the real `add_ca65_app`
     mechanics (entry file + `SOURCES_VAR` glob including `include/ca65/
     *.inc`, `DEFAULT_VERSION`, `PRG_SIZE_HEX`, optional `CODE_ALIGN`,
     `.include "command64.inc"`, `-t c64`/`-I include/ca65` already wired
     by the CMake function).
   - Add a "Zero-Page Coordination" note to Local Contracts covering both
     deferred Phase 2 items: `.importzp`/`.exportzp` for any future
     cross-object-file shared zp pointer, and the `$70-$8F` app-private
     convention with its known, accepted collision risk.
   - Fix the `BUILD_<APPNAME_UPPER>` location claim (app's own directory,
     not repo root).
   - Add a Verification bullet for ca65 targets (`cmake --build build
     --target test_image_d64`/`image_d64` must succeed via `add_ca65_app`).
4. **`docs/codebase-reference.md`**:
   - §1 (line 50): reword the blanket "The assembler is KickAssembler
     v5.25" sentence to state the toolchain split.
   - Near §13/§13.1 (before or after line 1682): add a short note stating
     new external apps use ca65/ld65 (pointing at `src/external/AGENTS.md`
     for the workflow) and that §13.1's relocation mechanism applies
     identically to both toolchains' output.

No changes to root `AGENTS.md` or `tests/AGENTS.md` (verified above,
neither needs one).

## Verification

- Reread each edited file's DOX sections (Local Contracts/Work
  Guidance/Verification as applicable) to confirm internal consistency
  after the edit — no leftover blanket "Kick Assembler only" claims.
- Grep the 4 edited files plus root `AGENTS.md`/`tests/AGENTS.md` for
  "Kick Assembler"/"KickAssembler" afterward to confirm every remaining
  mention is correctly scoped (core OS) rather than a blanket claim.
- No CMake/source changes in this phase, so no build verification is
  needed — this closes out
  `brain/plans/2026-07-08-ca65-adoption-and-spike-migration.md` entirely
  (all 6 phases complete).

---

# Log the ca65 adoption work (Phases 1-5) in CHANGELOG.md

*(Implemented and committed — `89ed37a`. Kept here for the record.)*

## Context

`AGENTS.md` requires `CHANGELOG.md` be updated "immediately after decisions
or changes" — this wasn't done during the ca65 adoption effort (Phases
1-5, all already committed and user-tested working). The user asked to
"update the phase number versions" for the ca65 adoption plan; after
clarifying (the `docs/codebase-reference.md` "Phase 4" references are
factually correct as historical migration notes, not stale), the actual
gap was that `CHANGELOG.md`'s `[Unreleased]` section had zero entries for
any of this work.

## Plan

Add new bullet entries to `CHANGELOG.md`'s existing `[Unreleased]` section,
matching its established format (`### Added`/`### Fixed`, bold title +
description, nested sub-bullets for multi-part features — see the existing
"VI Alike External Editor" entry as the density/style reference). Not one
entry per commit — group at the phase/feature level, same granularity the
file already uses.

Three new `### Added` entries (placed with the existing `### Added` items):

1. **ca65/ld65 toolchain adoption** (Phases 1-3): `include/ca65/` shared
   library (`command64.inc`/`vmm.inc`/`macros.inc`/`screencode.inc`),
   `cmake/FindCa65.cmake`, and `cmake/Ca65.cmake`'s production
   `add_ca65_app` function — versioned, hash-gated build numbers via
   `IncrementBuildNumber.cmake`'s new `ASM_DIALECT` param, templated
   per-app `.cfg` generation, reusing `tools/reloc.py` for the base/
   next-page relocation build. Points at
   `brain/plans/2026-07-08-ca65-adoption-and-spike-migration.md` for the
   full phased plan.
2. **conway/label migrated to ca65/ld65** (Phase 4): Kick-built
   `conway.prg`/`label.prg` replaced with ca65/ld65 builds, verified
   functionally identical (matching relocation-table byte counts against
   the pre-migration reference, VICE-tested), continuing each app's
   existing `BUILD_CONWAY`/`BUILD_LABEL` sequence.
3. **ca65 test suite migrated** (Phase 5): the 9 ca65-ported test programs
   moved from the exploratory spike into `tests/src/<name>/`, built
   alongside (not replacing) their KickAssembler counterparts for
   dual-toolchain regression coverage.

One new `### Fixed` entry:

4. **ca65 test version banners**: each of the 9 tests printed a hardcoded
   placeholder banner (`"... V0.1.0 (CA65 SPIKE) - ..."`) left over from
   the spike; now prints its real `VERSION_MAJOR.MINOR.STAGE.BUILD_NUMBER`.

## Verification

- Visual proofread against the existing `[Unreleased]` section's format
  (bullet style, bold-title convention, subsection placement).
- Confirm no existing `CHANGELOG.md` content is altered or removed — this
  is purely additive.
