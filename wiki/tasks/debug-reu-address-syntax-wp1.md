# Task Spec: DEBUG REU/Address Syntax WP1

## Objective

Add the parser foundation and permissive `=` execution-address syntax defined
by `brain/plans/2026-08-03-debug-reu-and-address-syntax-wp1.md`.

Taskwarrior UUID: `adfecaf3-212c-4e91-bcf5-f1c79f673eae`

## Scope

- Add `requireEnd` and `parseOptionalEquals` without changing `parseHexArg`.
- Accept bare and optional-`=` addresses for `G`, `T`, and `P`.
- Validate complete commands before execution or `regPC` mutation.
- Preserve existing no-argument and execution behavior.
- Build and verify DEBUG through CMake and the mandatory VICE workflow.

## Increments

- [x] Increment 1: add the parser helpers and build the focused `debug` target.
- [ ] Increment 2: integrate and verify permissive `=` parsing in `G`.
- [ ] Increment 3: integrate and verify permissive `=` parsing in shared `T`/`P`.
- [ ] Increment 4: run focused regressions, artifact review, DOX closeout, and
      the user-confirmed walkthrough.

## Acceptance

- [ ] Valid bare and `=` forms select identical targets.
- [ ] No-argument behavior remains unchanged.
- [ ] Invalid `G` commands execute no target code.
- [ ] Invalid `T` and `P` commands preserve `regPC` and breakpoint state.
- [ ] DEBUG builds without warnings or errors and remains relocatable.
- [ ] The user confirms the manual walkthrough before WP1 is marked complete.

## Increment 1 Evidence

- Added `requireEnd` and `parseOptionalEquals` beside the existing parser
  helpers without changing `parseHexArg`, dispatch, or command handlers.
- CMake built DEBUG build 1112 successfully: 6,580 code bytes and 721
  relocation points inside the configured 8KB `MAIN` envelope.
- No BSS, zero-page, or OS parameter-cell ownership changed.
