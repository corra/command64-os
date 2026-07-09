# Adopt ca65/ld65 for new development; migrate spike apps to mainline

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

Replace `cmake/Ca65.cmake`'s `add_ca65_spike_app` with a production
`add_ca65_app(TARGET_NAME ENTRY_FILE SOURCES_VAR DEFAULT_VERSION ...)` that
mirrors `cmake/KickAssembler.cmake`'s `add_external_app` (`cmake/KickAssembler.cmake:47-140`)
feature-for-feature:

- Enforce a persistent `BUILD_<NAME>` counter file next to the entry source
  (same `IncrementBuildNumber.cmake` reuse, content-hash gated).
- **Fix `cmake/IncrementBuildNumber.cmake:89`** before wiring it into any ca65
  target: it currently unconditionally writes Kick syntax
  (`.const ${VAR_NAME} = "${NEW_VAL}"\n`), which ca65 cannot parse (no
  `.const` directive; ca65 doesn't do quoted-string `=` equates that way).
  Add an `ASM_DIALECT` (or similarly named) argument to the script, defaulting
  to the current Kick output, with a `ca65` branch that writes
  `.define ${VAR_NAME} "${NEW_VAL}"` instead — `.define` is ca65's macro-style
  text substitution, which is what the version-banner `.CONCAT()`/`.SPRINTF()`
  call from Phase 2 needs. Confirmed by reading the script directly; this is
  a real gap, not a hypothetical.
- Generate a per-config `build_config.inc`-equivalent (`.inc` with `BUILD_NUMBER`
  equate, using the fixed `.define` form above) fed into the version-banner
  macro from Phase 2.
- Keep the existing base/next-page double-link + `tools/reloc.py` diff step
  (this part of `add_ca65_spike_app` already works and needs no change).
- **Decision point, not mandated**: consider generating each app's `.cfg`
  file from a CMake template (`MEMORY`/`SEGMENTS` blocks parameterized by
  `USER_PROG_START_HEX`/`_NEXT` and a per-app size) instead of checking in a
  static `_2c00.cfg`/`_2d00.cfg` pair per app, to cut duplication as more apps
  migrate (currently 3 apps × 2 near-identical files). Weigh against static
  `.cfg` files being directly inspectable/diffable when a link fails — revisit
  once ca65 app count grows enough that the duplication is actually painful,
  rather than deciding it up front.
- Split tool discovery into `cmake/FindCa65.cmake` (mirroring
  `cmake/FindKickAss.cmake`'s pattern) separate from the build-function module,
  for consistency with the rest of `cmake/`.
- Targets built with `add_ca65_app` go straight into `IMAGE_PRG_TARGETS`
  (the real `image_d64`), not just `TEST_IMAGE_PRG_TARGETS`.

`Ca65_FOUND`-gating stays (mirrors `Oscar64_FOUND`'s "inert if absent" pattern)
so the Kick-only build path still works on machines without cc65 installed —
but note this now means **conway/label become unbuildable without ca65
installed**, which is an acceptable, explicit tradeoff since we're replacing
their Kick versions.

## Phase 4 — Migrate conway and label off the spike branch

For each of `conway` and `label`:

1. Move sources from `spike/ca65-conway/` / `spike/ca65-label/` into
   `src/external/conway/` / `src/external/label/` (replacing the existing
   Kick `.asm` files), switching their `common.inc`/local includes over to
   the shared `include/ca65/*.inc` from Phase 2.
2. Add a `BUILD_CONWAY` / `BUILD_LABEL` counter file (continue the existing
   Kick build-number sequence rather than resetting to satisfy the versioning
   contract external apps already follow, per `src/external/AGENTS.md`).
3. Wire the version banner (Phase 2) in place of the spike's hardcoded
   `"LABEL V0.1.0 (CA65 SPIKE)"`-style literal (`spike/ca65-label/label.s:426-429`).
4. Update `CMakeLists.txt`: remove the old `add_external_app(conway ...)` /
   `add_external_app(label ...)` Kick calls and the spike's `conway_ca65`/
   `label_ca65`/`CONWAY_CA65_TARGET`/`LABEL_CA65_TARGET` blocks
   (`CMakeLists.txt:119-157`); replace both with `add_ca65_app(...)` calls
   feeding `IMAGE_PRG_TARGETS`.
5. Delete the superseded Kick sources (`src/external/conway/conway.asm`,
   `src/external/label/label.asm`) once the ca65 build is confirmed at parity
   in VICE (load, run, exercise the app's core interaction, confirm relocation
   at a non-default page still works via `aptRelocate`).
6. Update any docs referencing these apps as Kick-built (`docs/codebase-reference.md`,
   `wiki/` app pages if present).

## Phase 5 — Migrate the test spike

Move `spike/ca65-tests/*.s` into `tests/src/<name>/` alongside (or replacing,
per app-by-app confirmation) their Kick `tests/src/<name>/*.asm` counterparts,
using the same `add_ca65_app`-style wiring but into `TEST_IMAGE_PRG_TARGETS`
(tests are dev-only, not release artifacts, so no need to touch `IMAGE_PRG_TARGETS`
here). `tests/src/reloc/reloc.asm` stays Kick-only — it tests the OS's
relocation mechanism itself, not assembler-specific behavior, and has no ca65
port per the existing spike scope note (`CMakeLists.txt:159-163`).

## Phase 6 — Policy documentation

- `AGENTS.md` (root) and `src/AGENTS.md`: change "designed for assembly using
  Kick Assembler" to state ca65/ld65 is the required toolchain for **new**
  external apps; Kick Assembler remains required for `src/command64/*` (core
  OS) until the deferred core-OS migration plan lands.
- `src/external/AGENTS.md`: add a ca65-equivalent workflow section next to the
  existing `add_external_app` contract description (BUILD_<NAME> file,
  versioning, `IMAGE_PRG_TARGETS`), pointing at `add_ca65_app`.
- `docs/codebase-reference.md`: note the toolchain split (core OS = Kick,
  external apps = ca65 going forward) near the existing §13.1 relocation
  section (`docs/codebase-reference.md:1682-1688`), since that section's
  described mechanism is now explicitly shared across both toolchains.

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
