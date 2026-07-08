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

### Stage 2 — Restructure tests into per-test subdirectories
- [ ] Move each `tests/src/<name>.asm` into `tests/src/<name>/<name>.asm`.
- [ ] Create `tests/src/common/` (empty/reserved, for future shared includes).
- [ ] Update the `file(GLOB TEST_SRCS ...)` logic in `CMakeLists.txt` to
      discover tests under the new subdirectory layout.
- [ ] Move each `BUILD_TEST_<NAME>` into its corresponding
      `tests/src/<name>/` directory (following Stage 1's convention).
- [ ] Verify `cmake --build build --target test_image_d64` still builds all
      test PRGs and registers them on the test disk image.

### Stage 3 — Hash-based increment trigger
- [ ] Update `cmake/IncrementBuildNumber.cmake` to compute a hash (e.g.
      SHA-256 via `file(SHA256 ...)`) over the concatenated dependency
      sources for a target.
- [ ] Store the last-recorded hash alongside (or within) each `BUILD_<NAME>`
      file so it persists across builds.
- [ ] Only increment and rewrite `BUILD_<NAME>` (and the generated `.inc`)
      when the computed hash differs from the stored one.
- [ ] Verify: touching a source file with a no-op edit (e.g. re-save,
      whitespace-only change that Kick Assembler would still treat as
      identical output) does *not* bump the build number, while an actual
      content change does.
- [ ] Verify across all target types (OS, external apps, tests) — no
      type-specific exceptions.

## Notes

- This spec was produced from an interview (2026-07-08) rather than
  pre-existing design docs; see conversation history for the tradeoffs
  considered (single manifest file vs. per-target files vs. auto-create,
  and whether test build files should be tracked in git — decided: yes,
  tracked, split by relocation only).
