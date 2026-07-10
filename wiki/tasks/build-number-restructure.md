# Task Spec: Build Number Tracking Restructure

## Description

Restructure how per-target build counters (`BUILD_<NAME>` files) are stored and
incremented across the project. Today, every external app and every test
program has a flat `BUILD_<NAME>` file at the repository root (14 files as of
2026-07-08: `BUILD_OS`, `BUILD_LABEL`, `BUILD_CONWAY`, `BUILD_PACMAN`,
`BUILD_DEBUG`, `BUILD_DVORAK`, `BUILD_VI`, and one `BUILD_TEST_*` per test in
`tests/src/`). This clutters the repo root, gives no semantic grouping between
OS-core, external-app, and test build numbers, and increments on any touched
dependency rather than on real content changes.

## Scope

- **Relocate build counters to target source directories**: `BUILD_<NAME>`
  moves from repo root into the owning target's own directory (e.g.
  `src/external/pacman/BUILD_PACMAN`), keeping the existing `BUILD_<NAME>`
  filename convention.
- **Restructure tests into per-test subdirectories**: `tests/src/hello.asm`
  becomes `tests/src/hello/hello.asm` (mirroring the `src/external/<app>/`
  layout), with its `BUILD_HELLO` file alongside it. Add `tests/src/common/`
  as a reserved location for future shared test code (no shared code exists
  yet — this just establishes the convention).
- **Hash-based increment trigger**: replace the current "bump on any touched
  dependency" behavior in `cmake/IncrementBuildNumber.cmake` with a hash of
  the concatenated target sources. Only increment (and rewrite the
  `BUILD_<NAME>` file) when that hash differs from the last recorded hash.
  Applies uniformly to OS, external apps, and test targets — no
  per-target-type exceptions.
- **Out of scope**: no change to what the build number is used for at
  runtime (still emitted as `.const BUILD_NUMBER` into a generated `.inc`),
  no change to `add_external_app`'s public signature beyond internal path
  resolution.

## Rollout Stages

Staged and reviewed one at a time rather than as a single pass.

### Stage 1 — Relocate `BUILD_*` files into target directories — DONE (2026-07-08)
- [x] Move all root `BUILD_*` files into their owning target's source
      directory: `BUILD_OS` → `src/command64/`, `BUILD_DEBUG` →
      `src/external/debug/`, `BUILD_LABEL` → `src/external/label/`,
      `BUILD_CONWAY` → `src/external/conway/`, `BUILD_PACMAN` →
      `src/external/pacman/`, `BUILD_VI` → `src/external/vi/`,
      `BUILD_DVORAK` → `src/external/dvorak/`. `BUILD_TEST_*` (10 files)
      moved into `tests/src/` (shared, flat — per-test subdirs come in
      Stage 2, at which point each `BUILD_TEST_<NAME>` travels with its
      `.asm` automatically since resolution is now directory-of-entry-file
      based).
- [x] Update `cmake/KickAssembler.cmake` (`add_external_app`) to resolve
      `BUILD_FILE` as `<directory of ENTRY_FILE>/BUILD_<NAME_UPPER>` instead
      of `${CMAKE_SOURCE_DIR}/BUILD_<NAME_UPPER>`.
- [x] Update the `VERSIONING VIOLATION` FATAL_ERROR message and function
      doc-comment to reference the new expected path.
- [x] Update the OS build's separate hardcoded `add_custom_command` in
      `CMakeLists.txt` to point at `src/command64/BUILD_OS`.
- [x] Verify a full `cmake -B build && cmake --build build` succeeds with no
      path errors, build numbers continue incrementing correctly, and both
      `image_d64`/`test_image_d64` still assemble all PRGs onto their disk
      images.

### Stage 2 — Restructure tests into per-test subdirectories — DONE (2026-07-08)
- [x] Move each `tests/src/<name>.asm` into `tests/src/<name>/<name>.asm`
      (all 10 tests: api, bank, color, dev, extcls, file, handle, hello,
      reloc, vmm).
- [x] Create `tests/src/common/` (reserved, `.gitkeep` placeholder — no
      shared test code exists yet).
- [x] Update `file(GLOB TEST_SRCS "tests/src/*.asm")` to
      `file(GLOB TEST_SRCS "tests/src/*/*.asm")` in `CMakeLists.txt`.
- [x] Move each `BUILD_TEST_<NAME>` into its corresponding
      `tests/src/<name>/` directory — no further CMake change needed since
      Stage 1 already made `add_external_app` resolve `BUILD_FILE` from the
      entry file's own directory.
- [x] Verify `cmake --build build --target test_image_d64` still builds all
      10 test PRGs and registers them on the test disk image; build counters
      confirmed incrementing at their new colocated paths.
- Note: `tests/src/bin/*.prg` is a pre-existing, unrelated set of checked-in
  binary fixtures — left untouched, not part of this restructure.

### Stage 3 — Hash-based increment trigger — DONE (2026-07-08)
- [x] `cmake/IncrementBuildNumber.cmake` now computes a combined SHA-256
      hash across all tracked source files (via per-file `file(SHA256 ...)`
      then `string(SHA256 ...)` over the concatenation).
- [x] `BUILD_<NAME>` format extended to two lines: line 1 = build number,
      line 2 = the content hash as of the last recorded state. Rewritten
      unconditionally each run, but bytes are identical when nothing
      changed, so git sees no diff.
- [x] Only increments (and regenerates the `.inc`) when the computed hash
      differs from the stored one. A missing/legacy hash line (first run
      after this change) adopts the current hash as a baseline *without*
      bumping, so migrating existing counters was a no-op.
- [x] Source lists are passed via a generated manifest file
      (`build_<target>_sources.txt` per external app, `build_os_sources.txt`
      for the OS target) rather than a `-D` command-line list, since an
      unescaped CMake list embedded in a `COMMAND` argument silently splits
      on semicolons.
- [x] Applied uniformly: `add_external_app` (covers external apps and all
      test targets) and the OS target's standalone custom command in
      `CMakeLists.txt` both route through the same hash logic. The OS
      target's hash inputs now also explicitly include `CMD64_ENTRY`
      (`src/command64.asm`), which sat outside the `src/command64/*` glob
      and was previously missing from its own dependency list.
- [x] Verified: fresh clean build establishes hash baselines with zero
      bumps; a no-op `touch` on a tracked source re-runs the check but
      leaves the counter unchanged; an actual content edit bumps the
      counter (confirmed on `tests/src/hello/hello.asm`: 1012 → 1013);
      full `cmake -B build && cmake --build build` still produces both
      disk images correctly end to end.

## Notes

- This spec was produced from an interview (2026-07-08) rather than
  pre-existing design docs; see conversation history for the tradeoffs
  considered (single manifest file vs. per-target files vs. auto-create,
  and whether test build files should be tracked in git — decided: yes,
  tracked, split by relocation only).
