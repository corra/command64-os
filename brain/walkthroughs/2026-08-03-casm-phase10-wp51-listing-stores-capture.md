# CASM Phase 10 WP51 Verification Walkthrough

Status: Complete; user approved 2026-08-03
Branch: `feature/casm-phase10-wp51`
Candidate: CASM `0.1.52` build `1222`

## Scope

WP51 implements source-owned physical-line completion, two conditional listing
VMM stores, fixed 16-byte metadata records, buffered Pass 2 byte mirroring,
pass-driver line transactions, include-safe capture, and both dedicated
harnesses (`test_casm_listing`, `test_casm_listcap`). `/L` remains rejected by
production orchestration until WP54; WP51 writes no `.LST` file and adds no
reachable production behavior change.

## Implementation Review

Full bullet-by-bullet re-read of every plan requirement against the actual
diff, recorded in
`brain/reviews/2026-08-03-casm-wp51-implementation-review.md`. No
discrepancies found against Storage Architecture, Metadata, Byte Mirror,
Source Capture, the Listing Module ABI, Emitter Integration, Pass/Include
Integration, Diagnostics, Harnesses, Envelopes, or the plan's Stop Conditions.

## Runtime Walkthrough

Checklist: `brain/plans/2026-08-03-wp51-increment9-walkthrough-checklist.md`.
User ran both harnesses live under VICE across several iterations:

1. `test_casm_listing` (11 fixtures, Increments 3-4): `CASM LISTING: PASS`,
   no failures on the re-run against the tightened envelope and final
   whole-object rebuild.
2. `test_casm_listcap` (7 fixtures, Increment 6): initially failed 4 of 7
   (`ff.f..f`) on first re-run. Investigated live with temporary diagnostic
   instrumentation; five real bugs found and fixed, all in the test harness
   itself (none in production `listing.s`/`source.s`/`emit.s`/`casm.s`):
   missing `resourcesCleanup` calls between two harnesses' repeated internal
   `runCaptureAssembly` calls (VMM registry exhaustion), a wrong-expected-data
   authoring bug in `expDeferred`'s table, an uninitialized `CasmCliOptions`
   stand-in in the harness's own `cli.s` shim, a dangling output write channel
   in the PRG-identity fixture, and a pre-existing (unrelated to WP51)
   `fileio.s` `fileClose` gap that never reset `CasmInputState`, worked around
   locally in the harness. All temporary instrumentation was removed once
   every fixture passed clean. **User confirmed all seven fixtures pass** on
   the final build. One separate, unresolved OS-level bug was found (a
   1-byte source file's `CHRIN`/status-channel read reporting a phantom
   4-byte length) and is explicitly out of WP51's scope, recorded as Task
   Warrior task 42, worked around by widening `fixEmpty`'s own fixture rather
   than fixing the underlying `file.asm` path.
3. Production `casm` regression sanity: confirmed unaffected running ordinary
   `.s`/`.seq` source through the normal `COMMAND64` shell without `/L` --
   same diagnostics, same PRG output, no new prompts, no crash, no slowdown.
   `listingCaptureInit` is never called from production `casm.s` (confirmed
   in the implementation review); linking `listing.s` whole into `casm.prg`
   has zero observable effect on ordinary use.

## Envelope and Regression Verification

Final envelopes (Increment 7, re-verified in Increment 8's audit): `casm`
(`$4900`), `test_casm_pass1` (`$4700`), `test_casm_passcheck` (`$4300`,
tightened), `test_casm_frame` (`$4700`), `test_casm_listing` (`$1300`),
`test_casm_listcap` (`$4C00`, final after the fixture-table fixes above),
`test_casm_catalog`/`test_casm_event` (`$1E00` each) -- all at the smallest
256-byte-aligned fit. A full clean rebuild (`rm -rf build`, reconfigure) and a
subsequent no-change rebuild both complete with zero errors across every
target, including `image_d64`, `test_image_d64`, `casm_overflow_test_d64`,
`casm_include_test_d64`, and `casm_listing_test_d64`.

## Version-Only Completion Increment

User approved WP51 completion 2026-08-03. Applied the only production change
this increment authorizes: `VERSION_STAGE` `"51"` -> `"52"` in `casm.s`.
Results:

- The hash-gated build counter advanced exactly once: `1221` -> `1222`.
- A full clean rebuild (`rm -rf build`, reconfigure, `-j4`) reproduced build
  `1222` with zero errors across every target.
- `build/casm.prg` is 20,555 bytes (up from WP50's 18,694-byte baseline --
  real growth from WP51's `listing.s` module and its call sites, not a
  version-string artifact).

## Completion Gate

Met 2026-08-03. CASM stands at `0.1.52` build `1222`, stable on a clean
rebuild. WP52 (deterministic symbol map) is unblocked but not yet activated;
it requires its own explicit activation per the parent plan.
