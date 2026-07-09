# Task Spec: ca65 Primary Test Migration

## Objective

Promote all already-ported ca65 test programs from parallel
`test_ca65_<name>` targets to the primary `test_<name>` targets used by
`test_image_d64`.

## Scope

- Migrate the 9 tests with existing ca65 ports:
  `apitest`, `banktest`, `color`, `devtest`, `extcls`, `filetest`,
  `handletest`, `hello`, and `vmmtest`.
- Preserve `reloc` as a KickAssembler test because its purpose is to cover
  Kick/reloc.py relocation behavior and no ca65 port exists.
- Keep public test target names and disk entries as `test_<name>`.
- Retire obsolete duplicate `test_ca65_<name>` build targets and
  `BUILD_TEST_CA65_<NAME>` counters.

## Checklist

- [x] Create Task Warrior task 22 for the migration.
- [x] Switch CMake so ca65 `.s` ports build as primary `test_<name>` targets.
- [x] Keep unported `.asm` tests on the KickAssembler path.
- [x] Update ca65 test sources to include `build_test_<name>.inc`.
- [x] Remove obsolete Kick sources for tests that now have primary ca65 ports.
- [x] Remove obsolete duplicate `BUILD_TEST_CA65_<NAME>` counters.
- [x] Split `ca65_app_smoketest` onto its own source and counter.
- [x] Update durable documentation and session memory.
- [x] Ask the user to confirm whether this task should be marked done.

## Verification

- `cmake --build build --target test_image_d64`
- Confirm `test.d64` includes the primary test entries, not duplicate
  `test_ca65_*` entries.
- Do not use the `c64-testing` MCP server or a web emulator.
