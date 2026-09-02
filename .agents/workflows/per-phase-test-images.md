---
description: Give each Phase its own dedicated .d64 test image from the start, instead of reactively shuffling fixtures once a generic disk fills up
---

# Per-Phase Test Disk Images

## Why this exists

`test.d64` and its ad-hoc overflow siblings (`casm_overflow_test.d64`,
`casm_listing_test.d64`) have repeatedly hit the 1541 directory-entry
ceiling (max 144 entries) or byte-space ceiling mid-Phase, forcing
reactive fixture moves — see the long trail of "test.d64's directory
track is full, moved to X" comments across `CMakeLists.txt`. WP68
eventually created `casm_phase12_test_d64` as a **dedicated,
self-bootable image for Phase 12's own growth**, which worked well but
was created reactively, after the pain hit. Going forward, create that
dedicated image proactively, at the start of the Phase, so fixture
placement is a non-issue for the rest of it.

## The rule

**When starting a new Phase** (CASM, DASH, DEBUG, or any other
numbered multi-WP effort) that will add test fixtures, create a
Phase-scoped `.d64` test image as part of that Phase's first Work
Package, rather than adding fixtures to `test.d64` or a prior Phase's
image. Reference it in the Phase's `brain/plans/` doc under whatever
Work Package first needs on-disk fixtures.

This does not apply to:
- Single fixtures added to an already-designated Phase image later in
  that same Phase (keep using it — that's the point).
- Small one-off fixes outside the Phase/WP structure (per
  `phased-implementation-planning`, those don't need this ceremony
  either).

A byte-oracle remediation effort (see
`.agents/workflows/canonical-byte-oracles.md`) adds a dedicated image
(`casm_oracle_test.d64`) only if it introduces on-disk fixtures that
cannot safely fit an existing current-effort image; re-derivation of an
existing fixture's reference does not need a new image.

## How to create one

Follow the `casm_phase12_test_d64` target in `CMakeLists.txt` (around
line 1874) as the reference pattern:

```cmake
add_c64_disk_image(<phase>_test_d64
    OUTPUT_FILE "${CMAKE_BINARY_DIR}/<phase>_test.d64"
    DISK_LABEL "${DISK_NAME}"
    DISK_ID "${DISK_ID}"
    PRGS command64 <assembler-or-shell-under-test> <other core PRGs the harnesses need>
)
add_dependencies(<phase>_test_d64 casm_test_fixtures casm_reference_fixtures)
```

Then append fixtures via `add_custom_command(TARGET <phase>_test_d64
POST_BUILD ...)` blocks, same as every existing image. Use
`add_c64_disk_image`'s built-in `C64_THEME_DIR` overlay-event wrapping
for the image target itself; for POST_BUILD fixture-append steps that
don't go through `cmake --build`'s normal target build (i.e. any
direct `cc1541` invocation), wrap with `WRAPPER_CC1541` per
`overlay-build-events.md` so `test` overlay events still fire.

Naming convention: `<effort>_phase<N>_test_d64` (target) /
`<effort>_phase<N>_test.d64` (file), e.g. `casm_phase13_test_d64`. If
the Phase is self-bootable (carries `command64` + the assembler under
test, like `casm_phase12_test_d64` does), say so in the plan — that
determines whether it needs its own VICE two-drive slot per
`project-vice-two-drive-test-setup`.

## What this replaces

Do not default new-Phase fixtures onto `test.d64` "because that's
where fixtures normally go" — check whether the current Phase already
has its own dedicated image first, and if not, create one before
adding the first fixture. `test.d64` remains the home for
cross-cutting/non-Phase-specific OS-level fixtures only.
