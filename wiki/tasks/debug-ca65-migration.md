# Task Spec: DEBUG ca65/ld65 Migration

## Description

Migrate the critical `DEBUG` external utility from KickAssembler to ca65/ld65
without changing its public behavior, disk-image name, command set, zero-page
layout, relocation support, or manual verification standard.

## Scope

- Record and follow `brain/plans/2026-07-09-debug-ca65-migration.md`.
- Port `src/external/debug/debug.asm` to `src/external/debug/debug.s` as a
  single ca65 translation unit.
- Prove the port first through a temporary parallel `debug_ca65` target.
- Replace the shipping `debug` target only after the parallel target builds and
  passes static relocation checks.
- Require the full `docs/debug-test-plan.md` manual suite before the task can
  be marked done.

## Sub-tasks

### Phase 1: Planning and Tracking

- [x] Record the full migration plan in `brain/plans/2026-07-09-debug-ca65-migration.md`.
- [x] Create this measurable task file.
- [x] Update Task Warrior if an MCP or local task command is available (`task 21`).

### Phase 2: Parallel ca65 Port

- [x] Create `src/external/debug/debug.s` from the current Kick source.
- [x] Convert all KickAssembler directives and syntax to ca65 equivalents.
- [x] Preserve DEBUG's private zero-page allocation at `$70-$7F`.
- [x] Preserve BRK vector, stack-frame, KERNAL I/O, parser, assembler, and disassembler behavior.
- [x] Add a temporary `debug_ca65` target and `BUILD_DEBUG_CA65` counter.
- [x] Build and statically verify `debug_ca65`.

### Phase 3: Shipping Target Swap

- [x] Switch the shipping `debug` target to `add_ca65_app`.
- [x] Keep output target and disk-image name as `debug.prg`.
- [x] Remove the temporary `debug_ca65` target/counter after the shipping target builds.
- [x] Retire the old KickAssembler DEBUG source after the ca65 target is verified.

### Phase 4: Verification and Documentation

- [x] Build `image_d64` and `test_image_d64`.
- [x] Verify `debug.prg` relocation footer and loaded byte span.
- [x] Update `CHANGELOG.md`, `brain/MEMORY.md`, and `docs/codebase-reference.md`.
- [x] Update DEBUG test-plan resident-range notes if the ca65 binary changes the range.
- [/] Ask the user to run the full `docs/debug-test-plan.md` suite.
- [ ] Mark the task done only after the user confirms all manual suites pass.

## Verification

- Static syntax grep confirms no Kick-only syntax remains in `debug.s`.
- ca65/ld65 build succeeds for the parallel and final shipping targets.
- The final `debug.prg` remains relocatable and preserves the public filename.
- Full manual DEBUG suite passes on user-provided real hardware or local emulator.
