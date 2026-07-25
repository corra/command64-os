---
feature: casm-phase8-wp38-default-origin-and-static-override
created: 2026-07-24
status: complete
---

# Walkthrough: CASM Phase 8 WP38 Default Relocatable Origin and `/S` Wiring

Plan: `brain/plans/2026-07-24-casm-phase8-wp38-default-origin-and-static-override.md`

Taskwarrior: `e8d31694-0602-42bd-8234-416f3af5b31a` (WP38); part of the CASM
Phase 8 milestone `c50df549-a7ae-4859-bd16-45a843425ce6`.

## Outcome

WP38 implemented Phase 0C.14 Contract item 1: `.ORG` is now optional. An
assembly with no `.ORG` defaults to relocatable mode at `CASM_DEFAULT_ORIGIN`
($3400); `/S` forces static mode and still requires an explicit `.ORG`. A
late `.ORG` (arriving after a label, byte, or another `.ORG` already started
output) is rejected by reusing `CASM_DIAG_DUPLICATE_ORG`, per the user's
confirmed decision during planning.

Implementation matched the plan closely. Two mechanism gaps found during
planning (not visible from the Phase 0C.14 freeze alone) were both closed
here: `emitInit` never primed `CasmPc` (safe only while `.ORG` was
mandatory-and-first); and `crpLabel` never guarded against a label preceding
`.ORG` at all, a latent gap since Phase 4 that no fixture had ever exercised.

No relocation table, relocation classification, or R6 footer exists yet --
output remains a plain PRG either way. WP39 (relocation classification) is
next.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase8-wp38` |
| Branch point | `feature/casm-phase8-wp37` at `a76e71f` |
| Baseline version | `0.1.39` build 1143 |
| Plan approval | Approved as drafted, including the confirmed `CASM_DIAG_DUPLICATE_ORG` reuse decision for the late-`.ORG` case |

## Implementation

- `common.inc`: new `CASM_DEFAULT_ORIGIN = $3400`.
- `emit.s`:
  - `CasmOrgSet` renamed to `CasmOutputStarted`, broadened from "an explicit
    `.ORG` has been processed" to "a label, a byte, or an explicit `.ORG`
    has already been processed this pass."
  - `emitInit` now conditionally primes `CasmPc`: to `CASM_DEFAULT_ORIGIN`
    unless `/S` (`CasmCliOptions & CASM_OPT_STATIC`) is set, in which case it
    stays zero until an explicit `.ORG` sets it or `emitMarkStarted` rejects
    the first qualifying statement.
  - `emitRequireOrg` replaced by exported `emitMarkStarted`: no-ops once
    output has started; under `/S` with no `.ORG` yet, fails with
    `CASM_DIAG_ORG_REQUIRED` (unchanged observable behavior, now reached
    only in this narrower case); otherwise writes the 2-byte header from
    `CasmPc` through the same `emitRawByte` pair `emitOrg` uses, inheriting
    the existing `CASM_PASS_MODE_MEASURE` no-op gate with no new pass-mode
    branching.
  - `emitOrg` updated to check/set `CasmOutputStarted` instead of
    `CasmOrgSet`; the late-`.ORG` case reuses `CASM_DIAG_DUPLICATE_ORG`.
  - `emitInstruction`/`emitByteList`/`emitWordList` call `emitMarkStarted`
    in place of `emitRequireOrg` (identical carry-based call shape, no
    other change).
- `casm.s`: `crpLabel` now calls `emitMarkStarted` unconditionally, before
  the pass-mode branch -- deliberately not skipped in `CASM_PASS_MODE_EMIT`,
  since Pass 1 and Pass 2 must agree identically on whether a later `.ORG`
  is late.
- `tests/src/casm_pass1/casm_pass1.s` and
  `tests/src/casm_passcheck/casm_passcheck.s`: added their own
  `CasmCliOptions` stand-in BSS byte and export, since `emit.s` now
  references it and `ld65` links whole object files -- caught by a real
  link attempt during implementation, not assumed in advance.
- `cmake/GenerateCasmTestFixtures.cmake` / `CMakeLists.txt`: three new
  fixtures (`casmorgexpl1`, `casmnoorg1`, `casmorglate1`); `casmorg1`
  (existing since Phase 4 WP13) reused unmodified as the primary positive
  case, its expected outcome flipped from `CASM_DIAG_ORG_REQUIRED` to a
  successful relocatable assembly -- the intended effect of this WP, not a
  regression. Three new trusted-reference manifests added to
  `tests/fixtures/casm/`: `casmorg1.ref.hex` and `casmorgexpl1.ref.hex`
  (deliberately byte-identical, proving implicit-default and explicit-`.ORG
  $3400` output match exactly) and `casmnoorg1.ref.hex` (a forward-reference
  label under the implicit origin, proving the full two-pass resolution
  pipeline agrees with it).

## Static Verification

- `casm` build 1143 (baseline) -> 1144 (implementation candidate) -> 1145
  (version-only completion increment), no-change rebuild stable at each
  step.
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` all build
  clean.
- MAIN measured via `ld65 -m`: CODE `$238B` (9099) + RODATA `$925` (2341) +
  BSS `$7D0` (2000) = 13440 of 13568 bytes -- **128 bytes headroom** (down
  from 189; this WP cost 61 bytes), no size bump needed.
- `test_casm_pass1` and `test_casm_passcheck` link successfully after adding
  their own `CasmCliOptions` stand-in -- confirmed by a real link attempt
  that failed first, then succeeded after the fix, not assumed.
- `test_casm_symbols`, `test_casm_vmm`, `test_casm_expr` build unaffected
  (none link `emit.s`).
- Hand-derived trusted references cross-checked against
  `hex_manifest_to_bin.py`'s own reported byte count and SHA-256 before any
  runtime test: `casmorg1.ref`/`casmorgexpl1.ref` both 4 bytes,
  `sha256=52f7bcbf...`; `casmnoorg1.ref` 6 bytes, `sha256=4ad897d7...`.

## Runtime Verification

The user ran the full verification matrix and confirmed: "All tests pass."

| Check | Result |
| --- | --- |
| `CASM CASMORG1` | pass |
| `COMP CASMORG1.PRG CASMORG1.REF` | pass |
| `CASM CASMORGEXPL1` | pass |
| `COMP CASMORGEXPL1.PRG CASMORGEXPL1.REF` | pass |
| `COMP CASMORG1.PRG CASMORGEXPL1.PRG` | pass |
| `CASM CASMNOORG1` | pass |
| `COMP CASMNOORG1.PRG CASMNOORG1.REF` | pass |
| `CASM CASMORGLATE1` -> `CASM: DUPLICATE ORG` | pass |
| `CASM CASMORG1 /S` -> `CASM: ORG REQUIRED` | pass |
| `CASM CASMORGEXPL1 /S` | pass |
| `CASM CASMORG2` -> `CASM: DUPLICATE ORG` (regression) | pass |
| `CASM CASMEMIT1` / `COMP CASMEMIT1.PRG CASMEMIT1.REF` (regression) | pass |
| `CASM CASMHELLO` / `RUN` (regression) | pass |
| `TEST_CASM_PASS1` | pass |
| `TEST_CASM_PASSCHECK` | pass |

## Documentation and DOX Closeout

- `brain/KNOWLEDGE.md`: Phase 0C.15 as-built section added, amending Phase
  0C.14 with the exact implemented mechanism.
- `wiki/tasks/casm.md`: WP38 checked complete.
- `brain/task.md`: WP38 entry added and closed.
- `CHANGELOG.md`: Unreleased entry added.
- Taskwarrior: WP38 (`e8d31694-0602-42bd-8234-416f3af5b31a`) completed;
  WP39 unblocked.

## Completion

**CASM Phase 8 WP38 is complete**, per the completion gate in
`brain/plans/2026-07-24-casm-phase8-wp38-default-origin-and-static-override.md`:
every fixture in the verification matrix passed, the implicit-default and
explicit-`.ORG $3400` outputs are proven byte-identical
(`COMP CASMORG1.PRG CASMORGEXPL1.PRG`), every existing static trusted
reference remains byte-identical, MAIN headroom is measured (128/13568, no
bump needed), a no-change rebuild holds `BUILD_CASM` stable, all three disk
images build clean, and the user confirmed the runtime results. Final CASM
`0.1.40` build 1145. WP39 (relocation classification) remains separately
gated and unstarted per `AGENTS.md`.
