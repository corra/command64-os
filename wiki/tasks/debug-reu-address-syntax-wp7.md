# Task Spec: DEBUG REU/Address Syntax WP7

## Objective

Close out the combined `=`-execution-syntax and REU-command feature: formalize
permanent regression suites, run the full regression under VICE (REU enabled
and disabled), bump DEBUG's minor version, perform the DOX closeout, and
produce a final combined walkthrough, per
`brain/plans/2026-08-04-debug-reu-address-syntax-wp7.md`.

Taskwarrior UUID: `683f2802-9cba-409f-b5bc-881e349e15b2`

## Scope

- Add Test Suite 14 (`=` execution syntax) and Test Suite 15 (REU command
  family) to `wiki/debug-test-plan.md`/`docs/debug-test-plan.md`.
- Run Suites 1-15 under VICE with REU enabled; Suites 1-13 plus Test 15.5
  with REU disabled.
- Bump `VERSION_MINOR` `"4"` -> `"5"` in `debug.s`; update the four
  illustrative `DEBUG v0.4.0.1101` doc strings to the real post-bump build.
- DOX closeout across `src/external/debug/AGENTS.md` and any other affected
  `AGENTS.md`.
- Final documentation sweep (`wiki/user-manual.md`,
  `wiki/programmers-reference.md`) for stale DEBUG capability claims.
- No command grammar, parsing, validation, or transfer behavior changes.

## Increments

- [ ] Increment 0: author Test Suites 14-15 in the test plan document.
- [ ] Increment 1: version bump, build, update illustrative version strings.
- [ ] Increment 2: full REU-enabled regression (Suites 1-15) under VICE.
- [ ] Increment 3: REU-disabled regression (Suites 1-13 + Test 15.5).
- [ ] Increment 4: DOX closeout.
- [ ] Increment 5: final documentation sweep; regenerate `release/`.
- [ ] Increment 6: combined walkthrough, user confirmation, parent plan
      closure.

## Acceptance

- [ ] Suites 14-15 exist, byte-identical between `wiki/` and `docs/`.
- [ ] Full regression passes in both REU environments, or every failure was
      explicitly reported to and resolved with the user.
- [ ] DEBUG reports `v0.5.0.<build>`; every doc example matches a real build.
- [ ] DOX and documentation sweep found/fixed every stale claim.
- [ ] `image_d64`, `test_image_d64`, and `release` build clean.
- [ ] The user confirms the combined walkthrough before WP7 and the parent
      plan are marked complete.
