# DEBUG ca65/ld65 Migration Plan

## Summary

Before any migration work begins, record this full plan in
`brain/plans/2026-07-09-debug-ca65-migration.md`. Only after that plan file
exists should implementation proceed.

Migrate `DEBUG` from KickAssembler to ca65/ld65 by using a temporary
parallel target first, running full parity verification, then replacing the
shipping `debug` target only after it passes. `DEBUG` is critical, so the
port must preserve command behavior, memory safety, zero-page layout, file
I/O behavior, trace/proceed stack handling, relocation support, and the
public `debug.prg` disk image name.

## Key Decisions

- First action: create `brain/plans/2026-07-09-debug-ca65-migration.md`
  containing the full migration plan, verification requirements, and done
  criteria.
- Use `src/external/debug/debug.s` as the ca65 source and keep
  `src/external/debug/debug.asm` untouched during the parallel phase.
- Build a temporary `debug_ca65` target first, not included in
  `IMAGE_PRG_TARGETS`.
- After full verification, switch the shipping `debug` target to
  `add_ca65_app` and remove the temporary target/counter and old Kick source.
- Keep `DEBUG` as a single ca65 translation unit for this migration.
- Use `PRG_SIZE_HEX "2000"` for DEBUG unless the parallel build proves a
  different value is required.
- Do not use `CODE_ALIGN`.
- ca65/ld65 becomes required for building the shipping `debug` target after
  the final swap.

## Implementation Changes

- Record the plan first in `brain/plans/2026-07-09-debug-ca65-migration.md`.
- Create or update a task record for this migration in `wiki/tasks/` and
  Task Warrior if available.
- Port `debug.asm` to `debug.s` with exact behavior preservation:
  - Replace Kick directives with ca65 equivalents.
  - Add `HEADER` and `CODE` segments using `__MAIN_START__`.
  - Replace `jsr $1000` with `jsr OS_API`.
  - Preserve private zero-page addresses `$70-$7F`.
  - Convert version/help/message strings to ca65-safe `.byte` sequences.
  - Replace fragile `bcc *+5` / similar skip idioms with named labels where
    needed.
  - Preserve BRK vector handling, stack-frame construction, `RTI` launch
    path, KERNAL file I/O, parser carry semantics, and all command behavior.
- Wire parallel CMake:
  - Add `DEBUG_CA65_SRCS`.
  - Add `debug_ca65` with
    `add_ca65_app(debug_ca65 "${DEBUG_CA65_ENTRY}" DEBUG_CA65_SRCS 1012 "2000")`.
  - Create `src/external/debug/BUILD_DEBUG_CA65` initialized from the current
    first line of `src/external/debug/BUILD_DEBUG`.
  - During the parallel phase, `debug.s` includes `build_debug_ca65.inc`.
- After `debug_ca65` passes verification:
  - Change `debug.s` to include `build_debug.inc`.
  - Change `DEBUG_SRCS`/`DEBUG_ENTRY` to the ca65 source set.
  - Replace `add_external_app(debug ...)` with
    `add_ca65_app(debug "${DEBUG_ENTRY}" DEBUG_SRCS 1012 "2000")`.
  - Keep target name `debug`, so disk/release output remains `debug.prg`.
  - Remove `debug_ca65`, `BUILD_DEBUG_CA65`, and the old Kick `debug.asm`.

## Verification Plan

- Static checks:
  - No remaining Kick-only syntax in `debug.s`: `#import`, `.encoding`,
    `.const`, `.label`, `.fill`, `* =`, `//`, or string `+` concatenation.
  - All OS API calls use `OS_API`.
  - All DEBUG zero-page symbols remain `$70-$7F`.
  - No `.importzp`/`.exportzp` needed because DEBUG remains single-object.
- Build checks:
  - Configure with ca65/ld65 available.
  - Build `debug_ca65`.
  - Build `image_d64` and `test_image_d64` after the final swap.
  - Verify `build/debug.prg` ends with `R6`, has base address `$2C00`, and
    has a nonzero relocation table.
  - Verify final `debug.prg` loaded byte span remains below `$5000`; if it
    does not, stop and revise the DEBUG scratch ranges in the test plan before
    behavioral testing.
- Manual verification:
  - Do not use the `c64-testing` MCP server.
  - Do not use a web emulator.
  - Ask the user to run the full `docs/debug-test-plan.md` suite on real
    hardware or a local emulator.
  - Require all 13 suites to pass before the migration can be considered
    complete.
  - Avoid monitor/screenshot/register polling while DEBUG is loading.

## Documentation And Done Criteria

- Update `CHANGELOG.md`, `brain/MEMORY.md`, and `docs/codebase-reference.md`.
- Update `wiki/debug-test-plan.md` and synced `docs/debug-test-plan.md` if
  DEBUG's final resident range changes.
- Run a DOX pass for touched paths.
- Do not mark the task done until the user confirms the full manual suite
  passed.
