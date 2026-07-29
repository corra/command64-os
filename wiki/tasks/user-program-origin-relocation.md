# User Program Origin and External Relocation

## Goal

Make `$3800` the reproducible default user-program origin and relocate R6
external commands before executing them by name.

## Status

- [x] Identify the relevant changes on the incomplete DASH branch.
- [x] Exclude unfinished DASH APIs, application sources, and packaging.
- [x] Set fresh-build origins to `$3800` and `$3900`.
- [x] Relocate external commands after loading at `UserProgStart`.
- [x] Synchronize memory-map and user documentation.
- [x] Rebuild all packaged external applications.
- [x] Smoke-test a packaged R6 external command (`CASM`).
- [ ] Smoke-test a non-relocatable external command.
- [ ] Obtain user confirmation before marking this task complete.

## Acceptance Criteria

- A fresh CMake configure defaults `USER_PROG_START_HEX` to `3800`.
- Packaged applications link at `$3800` with relocation partners at `$3900`.
- An R6 application built at a different origin runs by name at `$3800`.
- Existing non-relocatable applications retain their prior behavior.

## Verification Evidence

- Fresh CMake cache contains `USER_PROG_START_HEX=3800` and
  `USER_PROG_START_HEX_NEXT=3900`.
- `image_d64`, `test_image_d64`, and `command64_casm_utils_d64` build.
- `CASM` loads by name, prints version `0.1.48.1191`, reports its missing
  source argument, and returns to the shell.
