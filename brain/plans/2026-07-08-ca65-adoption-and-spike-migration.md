# Adopt ca65/ld65 for new development; migrate spike apps to mainline

**Update 2026-07-09 (Phase 6 detail):** Phase 6 was re-planned in detail
against every candidate policy/doc file (read in full, not assumed from
this document's own wording) before implementation. Key findings:
- The master plan's file list needs two corrections. It says both root
  `AGENTS.md` and `src/AGENTS.md` contain the phrase "designed for
  assembly using Kick Assembler" — verified by grep, only
  `src/AGENTS.md:12` actually has it; root `AGENTS.md` doesn't mention any
  specific assembler and needs no edit. Conversely, `CLAUDE.md` (not
  mentioned in the master plan at all) has the same stale claim, and since
  it's injected into the assistant's own system prompt every session,
  leaving it stale is a live risk to future behavior, not just a doc gap —
  added to scope.
- `src/AGENTS.md`'s Local Contracts are phrased as a blanket "All source
  files" rule, but its own Purpose section scopes it to core OS files —
  the blanket phrasing predates `src/external/AGENTS.md` existing as a
  child doc with its own contracts. Reworded to scope the Kick
  requirement to core OS specifically.
- `src/external/AGENTS.md` is entirely Kick-only today (its
  `add_external_app`/`BUILD_<NAME>`/`IMAGE_PRG_TARGETS` workflow section
  has no ca65 equivalent) — needs a parallel ca65 workflow section
  pointing at `add_ca65_app` (Phase 3), plus the two zero-page policy
  items deferred from Phase 2's plan (`.importzp`/`.exportzp` cross-module
  guidance, and the `$70-$8F` app-private convention — `conway`/`label`
  already collide on `$70`/`$71`, accepted only because they're never
  concurrently resident). Also fixes a pre-existing, unrelated inaccuracy:
  `BUILD_<APPNAME_UPPER>` files live in the app's own directory, not the
  repository root as currently claimed.
- `docs/codebase-reference.md` has the toolchain claim in two places: a
  blanket "The assembler is KickAssembler v5.25" in §1 Project Overview,
  and needs a toolchain-split note near §13/§13.1 (confirmed §13.1's
  relocation mechanism description is already toolchain-agnostic, so it
  needs a clarifying note, not a rewrite). No ca65 program template is
  added to §13's Kick-only "Minimal Program Template" — that belongs in
  `src/external/AGENTS.md`'s new workflow section, not duplicated here.
- `tests/AGENTS.md` verified to need no edit — already toolchain-agnostic.

Full stage-by-stage breakdown (edit `CLAUDE.md`, `src/AGENTS.md`,
`src/external/AGENTS.md`, `docs/codebase-reference.md`; no changes to root
`AGENTS.md` or `tests/AGENTS.md`) lives in the Phase 6 planning session —
see the git history around this update for the full working plan if
needed. This documentation-only phase closes out the plan entirely once
implemented (all 6 phases complete).

**Update 2026-07-09 (test target follow-up):** The Phase 5 dual-test
decision has been superseded. The 9 tests that already have ca65 ports now
build as the primary `test_<name>` targets, using their existing
`BUILD_TEST_<NAME>` counters and `build_test_<name>.inc` includes. The
temporary `test_ca65_<name>` targets, `BUILD_TEST_CA65_<NAME>` counters,
and duplicate Kick sources were retired. `tests/src/reloc/reloc.asm`
remains KickAssembler-based because it specifically covers the Kick/
reloc.py relocation path and has no ca65 port.

**Update 2026-07-08 (Phase 5 detail, superseded 2026-07-09):** Phase 5 was re-planned in detail
against every spike test file (read in full), the exact `CMakeLists.txt`
test-loop wiring, and the existing built `.prg` sizes, before
implementation. Key findings:
- The original Phase 5 decision kept the 9 migrated tests dual with their
  Kick counterparts. The 2026-07-09 follow-up supersedes that: the ca65
  ports are now the primary `test_<name>` targets, while `tests/src/reloc/`
  stays KickAssembler-only because it covers Kick/reloc.py behavior and has
  no `.s` port.
- The only real gap between `spike/ca65-tests/common.inc` and the shared
  `include/ca65/{command64,vmm}.inc` is a naming mismatch: the spike names
  the OS dispatch address `API`, the shared library (Phase 2's deliberate
  improvement) calls it `OS_API`. Every other constant already matches
  exactly. Migration renames every `jsr API` call site to `jsr OS_API`
  (same mechanical rename Phase 4 did for `label.s`), then deletes
  `common.inc` outright.
- `$0700` (already used for `label`) is generously sufficient for all 9
  tests — the largest (`devtest`, 570 bytes) is under a third of that
  budget. None needs `CODE_ALIGN`.
- The intermediate `test_ca65_<name>` target-naming convention avoided
  collision during the parallel phase. It is now retired; the ca65 ports
  keep the public `test_<name>` target and PRG names.
- The Phase 3 smoke test (`ca65_app_smoketest`) still points at
  `tests/src/hello/hello.s`, but remains a separate target with its own
  `BUILD_CA65_APP_SMOKETEST` counter because it verifies the helper
  pipeline rather than the user-facing hello test.
- The primary migrated tests use the existing `BUILD_TEST_<NAME>` counter
  files and `build_test_<name>.inc` generated includes.
- This is the last of `add_ca65_spike_app`'s three call sites (conway and
  label were migrated in Phase 4) — once this lands, the spike function
  itself is deleted, closing out the "spike" branch entirely.

Full stage-by-stage breakdown (move the 9 `.s` files + rename `API`→
`OS_API`, rewire the CMake test loop via `add_ca65_app`, retire
`add_ca65_spike_app` and the empty `spike/ca65-tests/` directory, final
verification) lives in the Phase 5 planning session — see the git history
around this update for the full working plan if needed.

**Update 2026-07-08 (Phase 4 detail):** Phase 4 was re-planned in detail
against every spike/Kick source file (read in full) plus the git history
behind the recent conway relocation fix, before implementation. Key
findings:
- Zero-page layout is already byte-identical between the spike and
  currently-shipping Kick versions for both apps (`conway`'s `$70-$7D`,
  `label`'s `$70`/`$71`) — no address changes needed. The `$70`/`$71`
  overlap between conway and label already exists in the shipping Kick
  apps today; it's a pre-existing, accepted risk (apps aren't concurrently
  resident), not something migration introduces or must fix.
- The `.importzp`/`.exportzp` risk flagged during Phase 2 planning doesn't
  apply: neither spike file shares a zp symbol across the object-file
  boundary — both get their equates via a plain `.include`, not a
  linker-level `.import`.
- Real, previously-undiscovered gap: `add_ca65_app` (Phase 3) can't build
  conway as-is. The most recent commit on this branch (`3c736e7`, "resolve
  relocation crash by embedding buffers as page-aligned data") added
  `align = 256` to the `CODE` segment in conway's `.cfg` files, required
  because `conway_grid.s` embeds two 960-byte page-aligned buffers
  directly in `CODE`. Phase 3's `.cfg` template has no `align` attribute.
  Phase 4 extends `add_ca65_app` with a minimal, backward-compatible
  optional trailing argument for this (via `${ARGN}`, so label and the
  Phase 3 smoke test's existing 5-arg calls need no change) rather than
  reopening Phase 3's design.
- conway's `statusText` screencode block predates Phase 2 and should
  switch to the `screencode_mixed`/`petscii_mixed` macros — confirmed
  Phase 2's `include/ca65/screencode.inc` was built and verified
  specifically against these exact hand-encoded bytes.
- label's hex-encoded drive-protocol strings (`cmdInit`/`cmdU1`/`cmdBP`/
  `cmdU2`) must stay exactly as they are: this isn't a ca65 tooling gap,
  it's that any correct uppercase-shifted PETSCII translation (Kick's or
  ca65's) produces bytes the 1541 command parser rejects. Migration keeps
  every existing hex table byte-for-byte, touching only what's actually
  incomplete: label's `verMsg` is a hardcoded "V0.1.0 (CA65 SPIKE)"
  placeholder (explicitly out of scope per the spike's own header
  comment) and needs wiring to the real `VERSION_MAJOR`/`_MINOR`/`_STAGE`
  + `BUILD_NUMBER`, matching the shipping Kick banner format exactly.
- conway's Kick version never prints a version banner at all (defines the
  version consts but never references them) — migration preserves this
  exactly, no banner added, since the goal is parity, not new features.
- `BUILD_CONWAY` (1040) / `BUILD_LABEL` (1032) already exist at the paths
  `add_ca65_app` expects, already in the 2-line counter+hash format —
  reused as-is. The hash gate will see a genuinely different source list
  on the first ca65 build and bump each by exactly 1 — expected, not a
  bug.
- `docs/codebase-reference.md` §9.2 (label) and §9.3 (conway) have direct
  file-path links and Kick-`.encoding`-specific phrasing that go stale;
  fixed narrowly. The rest of that doc's pre-existing staleness (missing
  conway/pacman/vi from the repo-structure tree, etc.) is out of scope.
- VICE MCP verification must respect an established gotcha from prior
  debugging history in this repo: monitor-protocol calls
  (`vice_read_registers`/`vice_screenshot`/`vice_read_memory`/`vice_run`)
  halt the CPU to service the request, and interleaving them during an
  in-flight KERNAL `LOAD` can desync the software-timed IEC handshake.
  Let `vice_load_program`'s own load complete before any other monitor
  call.

Full stage-by-stage breakdown (extend `add_ca65_app` for conway's
page-aligned buffers, migrate conway with VICE verification incl. a
non-default-page relocation check, migrate label with the same, final
verification pass) lives in the Phase 4 planning session — see the git
history around this update for the full working plan if needed.

**Update 2026-07-08 (Phase 3 detail):** Phase 3 was re-planned in detail
against the actual `cmake/*.cmake` files and `CMakeLists.txt` (all read in
full, not assumed) before implementation. Key findings:
- The master plan's Phase 3 wording ("replace `add_ca65_spike_app`") needs a
  correction: `add_ca65_spike_app` is still called 3x in `CMakeLists.txt`
  (`conway_ca65`, `label_ca65`, the `spike/ca65-tests/*.s` loop) — those are
  Phase 4/5's job to retire, not Phase 3's. Deleting the spike function now
  would break configure immediately, so Phase 3 **adds** `add_ca65_app`
  alongside it instead of replacing it.
- ca65 assembles each source once; only `ld65` links twice (once per
  `.cfg`) — confirmed in the existing `add_ca65_spike_app`
  (`cmake/Ca65.cmake:52-86`). `add_ca65_app` keeps this shape.
- The `.cfg`-templating decision point from the original Phase 2 sketch is
  resolved here: `.cfg` `MAIN` size genuinely varies per app (`conway`
  uses `$0C00`, `label`/tests use `$0700`), so `add_ca65_app` takes a
  `PRG_SIZE_HEX` argument and generates both per-config `.cfg` files from a
  template instead of checking in more static pairs — the `MEMORY`/
  `SEGMENTS` structure is otherwise identical across all 6 existing files.
- ca65's `-D name=value` command-line flag only defines a *numeric* symbol
  (confirmed via `brain/ca65/ca65.md`), so it can't carry `BUILD_NUMBER` as
  the literal ASCII digit text a version-banner `.byte` list needs. Instead
  `add_ca65_app` generates a `build_<name>.inc` containing `.define
  BUILD_NUMBER "<n>"` and passes its directory via `-I`, the same
  `#import "build_<name>.inc"` shape Kick apps already use
  (`src/external/AGENTS.md`).
- `cmake/IncrementBuildNumber.cmake`'s only dialect-specific line is its
  final `file(WRITE ...)` (line 89) — an `ASM_DIALECT` parameter (default
  `"kick"`, preserving every existing Kick target's output byte-for-byte)
  branches only that line: `.const NAME = "value"` for Kick,
  `.define NAME "value"` for ca65.
- `tools/reloc.py` needs no changes — confirmed assembler-agnostic (pure
  byte-diff of two `.prg` files).
- `cmake/FindKickAss.cmake` is the direct template for a new
  `cmake/FindCa65.cmake`, replacing the inline `find_program`/`if()` block
  currently in `cmake/Ca65.cmake:9-16`, mirroring the `Oscar64_FOUND`
  "inert if absent" pattern already used identically elsewhere.

Full stage-by-stage breakdown (`cmake/FindCa65.cmake`,
`cmake/IncrementBuildNumber.cmake`'s `ASM_DIALECT` param,
`cmake/Ca65.cmake`'s `add_ca65_app(...)`, and a throwaway
`ca65_app_smoketest` target proving the pipeline via `spike/ca65-tests/
hello.s` before Phase 4 depends on it for real apps) lives in the Phase 3
planning session, not duplicated here — see the git history around this
update for the full working plan if needed.

**Update 2026-07-08 (Phase 2 detail):** Phase 2 was re-planned in detail
against the actual tree (not assumptions) before implementation. Key
findings that reshape it from the original sketch below:
- No real macro-system gap exists — `petPrintChar` (`src/command64/petsci.asm:12`)
  is the only `.macro` in the whole codebase and is never called anywhere.
  `petPrintString` (used 48x) is a plain subroutine, not a macro. External
  apps never `#import` macros or call OS routines at assemble time — they
  dispatch at runtime via `jsr $1000` + a `DOS_*` selector in `.A`. So
  `include/ca65/macros.inc` is a cheap completeness item, not a gap-closer.
- 6 external apps exist today, not 2: `conway`, `pacman`, `debug`, `label`,
  `dvorak`, `vi`. All 6 `#import` only `include/command64.inc` (never
  `vmm.inc` or `petsci.asm` directly), so that one file is what every future
  ca65 app actually needs.
- `include/command64.inc` itself `#import`s `vmm.inc` (lines 121-122) and
  `#import`s a per-target `build_config.inc` for `UserProgEnd` (lines
  116-119). The ca65 port chains `vmm.inc` the same way, but **intentionally
  omits** the `build_config.inc`/`UserProgEnd` chunk — ld65 `.cfg` `MEMORY`
  blocks already set the load address, making it redundant, and Phase 2
  documents the omission with a comment rather than silently dropping it.
- `jsr $1000` is a hardcoded magic address at every Kick call site (no named
  constant exists in `include/` or `src/` today). `spike/ca65-tests/common.inc`
  already improved on this with a named `API` equate; Phase 2 adopts that as
  `OS_API = $1000` in the canonical port, called out as a deliberate small
  improvement over the Kick source.
- Zero-page collision risk: `spike/ca65-conway/common.inc` and
  `spike/ca65-label/common.inc` each independently claim `$70` for
  app-private scratch, with no shared convention documented anywhere. Phase 2
  adds a short guidance comment in `command64.inc`; full cross-app policy
  stays in Phase 6 (`src/external/AGENTS.md`), alongside the existing
  `.importzp`/`.exportzp` guidance.
- `screencode_mixed`/`petscii_mixed` are confirmed Kick Assembler *built-in*
  encodings (`brain/kickassembler/KickAssembler.md:707-729`), not
  project-custom, so the ca65 mirror needs a real, standard PETSCII→screencode
  `.CHARMAP` table. Only `conway.asm`/`pacman.asm` use the toggle today;
  `label.asm` deliberately avoids `petscii_mixed` for its drive-protocol
  strings (uppercase-shift would corrupt 1541 command bytes) — that
  app-specific nuance is a Phase 4 migration decision, not something Phase 2's
  shared library needs to solve.
- Version banner needs no `.SPRINTF()`/`.CONCAT()`: ca65's `.define` is
  literal text substitution, so once `BUILD_NUMBER` arrives as a `.define
  BUILD_NUMBER "42"`-style token (Phase 3), a plain comma-separated `.byte
  "NAME v", VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE, ".",
  BUILD_NUMBER, CR, 0` works directly. Phase 2 documents this convention with
  a comment instead of building dedicated tooling. Also: `conway.asm` and
  `pacman.asm` define the three version consts but never print a banner today
  (verified by grep) — Phase 2 doesn't assume all future apps need this wired.

Revised Phase 2 stage breakdown (each stage a separate, verified commit):
1. Persist this plan update in place (this edit).
2. `include/ca65/vmm.inc` — straight equate-for-equate port (50 lines, no
   ca65-specific changes needed). Verified by assembling a throwaway `.s`
   referencing `VMM_SUCCESS`/`VmmSegLo`/`REU_CMD_STASH`.
3. `include/ca65/command64.inc` — equate-for-equate port of the rest of
   `include/command64.inc`, omitting the `build_config.inc`/`UserProgEnd`
   chunk (documented), adding `OS_API = $1000` and a `$70-$8F` app-private-ZP
   guidance comment, ending with `.include "vmm.inc"`. Verified by assembling
   a throwaway `.s` referencing one symbol from every section.
4. `include/ca65/macros.inc` — `petPrintChar` ported as `.MACRO`/`.ENDMACRO`,
   plus a comment-only version-banner example. Verified by assembling and
   expanding the macro, checking the emitted bytes.
5. `include/ca65/screencode.inc` — standard PETSCII→screencode `.CHARMAP`
   table plus `screencode_mixed`/`petscii_mixed` toggle macros (wrapping
   `.PUSHCHARMAP`/`.POPCHARMAP`), named to match the Kick `.encoding` call
   sites 1:1 for an easy Phase 4 migration. Verified by assembling a toggle +
   test string and diffing the emitted bytes against the known-good hand-derived
   bytes in `spike/ca65-conway/conway_grid.s:437-440`.

`ca65`/`ld65` V2.19 are installed locally (`/home/morgan/.local/bin/`), so
every stage above is verified by actually assembling, not just inspection.

**Update 2026-07-08 (post-review):** Gemini reviewed this plan as `src/external/`
scope owner (`brain/reviews/2026-07-08_ca65_adoption_and_spike_migration_review.md`).
Findings assessed and folded in below (see each phase for the specific change);
summary of the assessment:
- **Confirmed real bug, incorporated** — `cmake/IncrementBuildNumber.cmake:89`
  unconditionally emits Kick syntax (`.const NAME = "value"`), which is invalid
  ca65 (no `.const` directive, and ca65 doesn't support quoted-string `=`
  equates the way Kick does). This would break Phase 3's version-banner wiring
  as originally written. Fixed by parameterizing the emitted syntax — see Phase 3.
- **Confirmed real ca65 behavior, incorporated as guidance** — cross-module
  zero-page symbol sharing needs `.importzp`/`.exportzp`, not `.import`/`.export`
  (plain `.import` assumes a 16-bit absolute address, producing a 3-byte
  absolute instruction instead of a 2-byte zero-page one for any shared zp
  pointer). The current spike sidesteps this because `conway_main.s`/
  `conway_grid.s` each `.include "common.inc"` directly rather than importing
  zp symbols across the object-file boundary — so this hasn't bitten anyone
  yet, but it will for any future multi-module app that shares zp pointers
  across files. Added as explicit guidance in Phase 2.
- **Verified via ca65 manual, adopted (improves on original plan)** — ca65 does
  have `.PUSHCHARMAP`/`.POPCHARMAP` (manual §11.102/§11.96), which lets a single
  file toggle character mapping inline and restore it, matching Kick's
  `.encoding "screencode_mixed"` ... `.encoding "petscii_mixed"` toggle idiom
  (`conway.asm:711`) more directly than this plan's original static
  `include/ca65/screencode.inc`-with-permanent-charmap approach. Phase 2 updated
  to use push/pop instead.
- **Reasonable simplification, noted as an option rather than mandated** —
  dynamically generating `.cfg` files from a CMake template (instead of
  checking in a static `_2c00.cfg`/`_2d00.cfg` pair per app) would cut
  per-app file duplication as more apps migrate. Trade-off: static `.cfg`
  files are directly inspectable/diffable and match the "config file" mental
  model ld65 itself is documented around; a CMake-templated string is harder
  to read/debug when something goes wrong at link time. Left as an explicit
  decision point in Phase 3 rather than adopted outright — worth revisiting
  once more than 2-3 apps are on ca65 and the duplication actually hurts.
- **Restates existing plan content, no change needed** — the review's point
  about consolidating test equates into a shared include matches this plan's
  original Phase 2/5 design already.
- The review's "Relocation Safety Verification" section (branch instructions
  use relative offsets, so binary length is invariant across the page shift)
  confirms an existing invariant already relied on by the Kick-based
  relocator and documented in `docs/codebase-reference.md` §13.1 — not new,
  but good independent confirmation nothing about the ca65 path changes it.

**Note:** this supersedes the external-app scope of `2026-07-04-staged-rewrite-ca65.md`.
That earlier plan proposed a "binary bridge" (compile ca65 modules to raw
`.bin` + symbol file, `.import binary` them into a still-Kick-linked OS) before
`spike/ca65-conway`/`spike/ca65-label`/`spike/ca65-tests` actually existed. The
spike proved a simpler mechanism instead: ld65 output diffs with
`tools/reloc.py` exactly like Kick output does, so external apps can be fully
independent ca65/ld65 builds with no binary-bridge step at all. The staged
rewrite plan's *core-OS* migration stages (2-5) are still relevant future
work and are explicitly deferred here (see Context below) — only its
external-app assumptions are superseded.

## Context

The `spike/ca65-*` branch (merged into `main`) proved that ca65/ld65 can replace
Kick Assembler for building external C64 apps on this OS: `tools/reloc.py`'s
base/next-page-diff relocation trick works identically on ld65 output, so
`aptRelocate` (`src/command64/loader.asm`) needs no changes. The spike was
explicitly scoped as "no commitment to carry forward" (`spike/ca65-conway/README.md:9`)
and left real gaps: no macro system in use, PETSCII/screencode strings are
hand-encoded as `.byte` hex, no build-number/version-banner wiring, and the
ca65 targets only exist as isolated, non-production `_ca65`-suffixed targets
on the test disk (`CMakeLists.txt:119-178`, `cmake/Ca65.cmake`).

Decisions already made with the user:
- ca65-built conway/label **replace** the Kick-built versions (no dual-shipping).
- The core OS (`src/command64/*.asm`, ~7500 lines, 14 chained Kick segments,
  several load-bearing fixed addresses) is **out of scope** for this plan —
  it gets its own follow-up plan once real ca65 apps have shipped.
- This plan **does** include closing the macro/PETSCII/versioning tooling gaps,
  since ca65 turns out to have first-class answers for all three
  (`.MACRO`, `.CHARMAP`/`-t` target encoding, and a `BUILD_<NAME>`-style CMake
  layer we can mirror from `add_external_app`).

Goal of this plan: make ca65 a fully supported, production-grade toolchain
for **external apps** going forward, promote `conway`/`label` off the spike
branch and onto the real release disk, and retire their Kick sources — without
touching the core OS.

## Phase 1 — Save cc65 toolchain reference docs (mirror `brain/kickassembler/`)

`brain/kickassembler/KickAssembler.md` is the full Kick manual saved verbatim
for reference. Do the same for the cc65 toolset the project now depends on:

- `brain/ca65/ca65.md` — ca65 manual (fetch https://cc65.github.io/doc/ca65.html,
  convert to Markdown, keep full TOC/section numbers like the Kick doc does).
- `brain/ca65/ld65.md` — ld65 linker manual (config file syntax, `MEMORY`/`SEGMENTS`/
  `SYMBOLS`/`FEATURES` blocks).
- `brain/ca65/README.md` — short index noting the other tools in the suite
  (`od65`, `da65`, `sim65` are potentially useful for debugging; `cc65`/`cl65`/`grc65`/
  `sp65`/`chrcvt65` are not relevant to this pure-assembly project) with links.

## Phase 2 — Shared ca65 support library (closes the spike's tooling gaps)

**Superseded by the "Phase 2 detail" update note at the top of this
document** (added 2026-07-08, after re-planning against the actual tree
rather than assumptions). Summary of what changed and why: the macro-library
scope shrank to near-zero (no real macro gap exists — verified only one
unused `.macro` exists anywhere), the app count is 6 not 2, the
`build_config.inc`/`UserProgEnd` chunk is intentionally dropped from the
ca65 port (ld65 `.cfg` supersedes it) rather than translated, a new
`OS_API = $1000` constant is added (an improvement over Kick's hardcoded
`jsr $1000`), and the version-banner mechanism needs no `.SPRINTF()`/
`.CONCAT()` — a plain `.byte` list suffices. See the top-of-file update note
for the full rationale and the `include/ca65/{vmm,command64,macros,
screencode}.inc` stage-by-stage breakdown.

## Phase 3 — Permanent (non-spike) CMake module

**Superseded by the "Phase 3 detail" update note at the top of this
document** (added 2026-07-08, after re-planning against the actual
`cmake/*.cmake` files rather than assumptions). Summary of what changed and
why: `add_ca65_spike_app` is **added alongside**, not replaced in place —
it's still called 3x for the not-yet-migrated spike targets, and deleting
it now would break configure; the `.cfg`-templating "decision point" below
is resolved in favor of templating (via a `PRG_SIZE_HEX` argument), since
`.cfg` `MAIN` size genuinely varies per app; and `BUILD_NUMBER` is wired via
a generated `.define`-based `.inc` (not ca65's `-D` flag, which is numeric-
only and can't carry the literal digit text a version banner needs). See
the top-of-file update note for the full rationale and the
`cmake/FindCa65.cmake` / `IncrementBuildNumber.cmake` `ASM_DIALECT` /
`add_ca65_app(...)` / smoke-test stage-by-stage breakdown.

`Ca65_FOUND`-gating stays (mirrors `Oscar64_FOUND`'s "inert if absent" pattern)
so the Kick-only build path still works on machines without cc65 installed —
but note this now means **conway/label become unbuildable without ca65
installed**, which is an acceptable, explicit tradeoff since we're replacing
their Kick versions.

## Phase 4 — Migrate conway and label off the spike branch

**Superseded by the "Phase 4 detail" update note at the top of this
document** (added 2026-07-08, after re-planning against every spike/Kick
source file rather than assumptions). Summary of what changed and why:
`add_ca65_app` needs a small extension first (an optional `align`
passthrough for conway's page-aligned grid buffers — a real gap the
original sketch below didn't anticipate); label's hex-encoded
drive-protocol strings stay untouched (not a tooling gap, a protocol
constraint) while only its incomplete `verMsg` placeholder gets wired to
the real version/build number; conway's Kick version never prints a
banner today and migration preserves that (parity, not new features); and
conway's `statusText` screencode block switches to Phase 2's
`screencode_mixed`/`petscii_mixed` macros, closing the loop those macros
were built to close. See the top-of-file update note for the full
rationale and the stage-by-stage breakdown (extend `add_ca65_app`, migrate
conway with VICE verification including a non-default-page relocation
check, migrate label with the same, final verification pass).

## Phase 5 — Migrate the test spike

**Superseded by the Phase 5 and 2026-07-09 test target update notes at the
top of this document.** Summary of what changed and why: the 9 ca65 test
ports first moved out of the spike area, then were promoted from temporary
parallel targets to the primary `test_<name>` targets. `reloc` remains
KickAssembler-only because it has no ca65 port and directly tests the
Kick/reloc.py relocation path. The `common.inc` gap was an `API`→`OS_API`
naming mismatch, closed by a mechanical rename before deleting the spike
copy. The Phase 3 smoke test remains separate and continues to use
`tests/src/hello/hello.s`.

## Phase 6 — Policy documentation

**Superseded by the "Phase 6 detail" update note at the top of this
document** (added 2026-07-09, after re-planning against every candidate
file rather than assumptions). Summary of what changed and why: root
`AGENTS.md` doesn't actually contain the stale Kick-Assembler phrase this
section assumed (no edit needed there), while `CLAUDE.md` — not
mentioned here at all originally — does, and matters more since it's
injected into the assistant's own system prompt every session;
`src/external/AGENTS.md`'s new ca65 workflow section also picks up the
two zero-page policy items deferred from Phase 2 (`.importzp`/
`.exportzp`, the `$70-$8F` app-private convention) and fixes a
pre-existing, unrelated `BUILD_<NAME>`-location inaccuracy found along
the way. See the top-of-file update note for the full rationale and the
per-file edit breakdown.

## Verification

- `cmake -B build && cmake --build build --target image_d64`: confirm conway
  and label build via ca65 and land in the release disk image (no more
  `_ca65`-suffixed test-only binaries).
- Load `conway.prg` / `label.prg` in VICE via the MCP tools
  (`mcp__c64__vice_load_program`, `vice_run`, `vice_screenshot`), exercise
  each app's normal interaction path, and confirm parity with current
  Kick-built behavior before deleting the Kick sources.
- Force a non-default load page (load a second resident app first to push the
  auto-slotting allocator) and confirm `aptRelocate` still patches the ca65
  binary correctly at runtime — this is the exact hazard the spike's README
  called out (non-relocatable ca65 output silently colliding with another
  app's fixed jumps).
- `cmake --build build --target test_image_d64`: confirm the migrated
  `tests/src/*` ca65 ports still pass the same battery of tests the spike
  achieved (9 of 10 non-reloc test dirs).
- Grep for any remaining `_ca65` or `spike/ca65-*` references in
  `CMakeLists.txt`/docs to confirm the spike naming is fully retired.
