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
- [x] Increment 2: integrate and verify permissive `=` parsing in `G`.
- [x] Increment 3: integrate and verify permissive `=` parsing in shared `T`/`P`.
- [x] Increment 4: run focused regressions, artifact review, DOX closeout, and
      the user-confirmed walkthrough.

## Acceptance

- [x] Valid bare and `=` forms select identical targets.
- [x] No-argument behavior remains unchanged.
- [x] Invalid `G` commands execute no target code.
- [x] Invalid `T` and `P` commands preserve `regPC` and breakpoint state.
- [x] DEBUG builds without warnings or errors and remains relocatable.
- [x] The user confirmed the manual walkthrough on 2026-08-04.

## Increment 1 Evidence

- Added `requireEnd` and `parseOptionalEquals` beside the existing parser
  helpers without changing `parseHexArg`, dispatch, or command handlers.
- CMake built DEBUG build 1112 successfully: 6,580 code bytes and 721
  relocation points inside the configured 8KB `MAIN` envelope.
- No BSS, zero-page, or OS parameter-cell ownership changed.

## Increment 2 Evidence

- Corrected `parseOptionalEquals` to return carry set when `=` was consumed;
  this distinguishes `G =` from a valid no-argument `G` without new storage.
- `cmdGo` now validates the complete command before committing `val1` or
  reaching `cgIndirect`.
- CMake built DEBUG build 1113 successfully: 6,593 code bytes and 723
  relocation points inside the configured 8KB `MAIN` envelope; `image_d64`
  also built successfully.
- VICE booted `build/image.d64`, proved the Command64 banner, and launched
  DEBUG 0.4.0 build 1113 by name from the shell.
- Bare `G 5000` and `G=5000`, `G =5000`, `G= 5000`, and `G = 5000` all
  executed the same `$5000` sentinel routine. Increment 3 subsequently proved
  that `$5000-$51C3` overlaps the current relocated DEBUG image, so Increment
  4 must rerun this matrix at `$6000+` before final acceptance.
- `G =`, `G ==`, `G =G000`, `G =10000`, `G =5000 EXTRA`,
  `G =0001:0000`, and `G 5000 EXTRA` printed `ERROR` and left the sentinel
  unchanged.
- A no-argument `G` used the pre-established `currentAddr`, and `Q` returned
  to the `c64[8]:>` shell prompt.

## Increment 3 Evidence

- `cmdTraceProceedCommon` now parses into `HexValLo/Hi`, validates end-of-input,
  and only then commits both bytes of `regPC`.
- CMake built DEBUG build 1114 successfully: 6,595 code bytes and 723
  relocation points inside the configured 8KB `MAIN` envelope; `image_d64`
  also built successfully.
- The first runtime setup used `$5000/$5100`, overwrote relocated DEBUG, and
  produced invalid proceed evidence. It was classified as a setup failure;
  the session was discarded and the one allowed clean recovery used `$6000+`.
- Clean-recovery `T` and `P` tests accepted bare, `=address`, spaced-before,
  spaced-after, and fully spaced forms. Five NOP steps advanced PC from `$6000`
  through `$6005`; no-argument `T` advanced to `$6006`.
- Missing, doubled, non-hex, five-digit, trailing-count, trailing-text, and
  page-qualified operands printed `ERROR`. A following `R` proved `regPC`
  remained `$6006` after all invalid `T` and `P` commands.
- `P =6100` stepped over `JSR $6110` to `$6103` and incremented the `$6201`
  subroutine sentinel. No-argument `P` then executed `INC $6200`, advanced to
  `$6106`, and left both sentinels equal to `$01`.
- Existing ROM handling remained unchanged: `T =D000` reported the ROM-target
  error; `P =D000` used its established skip-and-display behavior.
- `Q` returned to `c64[8]:>`. Increment 4 must correct the stale mirrored DEBUG
  test-plan scratch-range guidance before final acceptance.

## Increment 4 Completion Candidate

- Corrected all three mirrored test-plan safety gates with one authoritative
  translation rule: legacy `$4000/$5000` fixtures move to `$6000+`,
  `$4500/$5500` fixtures move to `$6500+`, and relocated loads use `$7000+`.
- A no-change `debug` rebuild retained build 1114. `debug`, `image_d64`, and
  `test_image_d64` all built successfully.
- Static review confirmed 6,595 code bytes, 723 relocation points, the unchanged
  8KB `MAIN` envelope, and no new zero-page or BSS ownership.
- A fresh VICE 3.10 session reran the full `G`, `T`, and `P` matrix at
  `$6000+`. Valid spacing forms were equivalent; no-argument behavior was
  preserved; all malformed, oversized, page-qualified, count, and trailing
  forms failed before execution or target-state mutation.
- Final sentinels were `06 01 01`: six `G` executions, one proceeded caller
  increment, and one proceeded subroutine increment. Invalid commands left
  these values and the established trace/proceed PCs unchanged.
- Existing ROM handling and `Q` shell return passed.
- Walkthrough:
  `brain/walkthroughs/2026-08-04-debug-reu-address-syntax-wp1.md`.
- DOX closeout found no purpose, ownership, workflow, structural, or durable
  contract change requiring an AGENTS update.
- The user confirmed the walkthrough on 2026-08-04; Increment 4 and WP1 are
  complete.
