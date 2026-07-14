# Task: Conway Multiverse Rules, Menu, and Counter

## Tracking

- Branch: `feature/conway-multiverse`
- Taskwarrior: #26 (`f4eba87e-a46d-47d2-986e-a707c57af1fd`)
- High-level specification: `brain/plans/conway-multiverse-rules-and-menu.md`
- Detailed plan: `brain/plans/2026-07-14-conway-multiverse-implementation-plan.md`

## Goal

Add a menu, nine Life-like presets, custom Birth/Survival editing, and a
16-bit generation counter to the existing relocatable ca65 Conway utility.

## Subtasks

- [x] Research Life-like rules and write high-level specification.
- [x] Update the specification for the production ca65/ld65 toolchain.
- [x] Reconcile design with current source, ZP, linker capacity, and relocation.
- [x] Create the detailed phased implementation plan.
- [x] Obtain explicit approval to implement.
- [x] Phase 1: contracts and build/memory headroom implemented, audited, and
  confirmed by the user.
- [x] Phase 2: presets, active rule tables, and generic solver implemented;
  automated builds and user runtime verification pass.
- [x] Phase 3: generation counter implemented and integrated; automated builds
  and user runtime verification pass.
- [ ] Phase 4: implement compact menu rendering and dynamic fields.
- [ ] Phase 5: integrate menu/simulation input state machine and shell exit.
- [ ] Phase 6: update documentation and create walkthrough.
- [ ] Complete user-run C64/VICE verification.
- [ ] Ask the user whether the task is done before closing this task or
  Taskwarrior #26.

## Required Verification

- Build `conway`, `image_d64`, and `test_image_d64` successfully.
- Verify final linked size, grid alignment, relocation footer, and app-manager
  reserved extent.
- Manually verify every preset, custom rule editing, counter lifecycle,
  pause/randomize/clear behavior, menu transitions, shell exit, and at least
  one non-default relocation.

Do not use `c64-testing`; project instructions mark it broken. Do not use a web
emulator as a substitute for user-run verification.
