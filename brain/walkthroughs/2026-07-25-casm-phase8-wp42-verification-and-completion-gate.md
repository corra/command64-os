---
feature: casm-phase8-wp42-verification-and-completion-gate
created: 2026-07-25
status: complete
---

# Walkthrough: CASM Phase 8 WP42 Verification, Walkthrough, and Completion Gate

Plan: `brain/plans/2026-07-25-casm-phase8-wp42-verification-and-completion-gate.md`

Taskwarrior: `186aadb1-462d-48d1-87bb-e1c9af6c75e1` (WP42); closes the CASM
Phase 8 milestone `c50df549-a7ae-4859-bd16-45a843425ce6`.

## Outcome

WP42 closed CASM Phase 8 by bundling the full accumulated WP38-WP41
fixture/harness matrix into one consolidated verification run and closing
the one real observability gap every prior Phase 8 WP had explicitly
deferred here: **no relocatable fixture had ever been loaded away from its
assembled address and actually run.** Every fixture verified in WP38-WP41
was checked exclusively via `COMP` against a hand-derived byte reference,
proving the file was byte-correct but never that the OS's existing
`aptRelocate` loader correctly consumes CASM's native R6 output. A new
fixture, `casmreloc1`, closed this gap and the master plan's Phase 8 gate
text is now proven literally, not just by inference.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase8-wp42` |
| Branch point | `feature/casm-phase8-wp41` at `7fe550f` |
| Baseline version | `0.1.43` build 1156 |
| Plan approval | Approved as drafted |

## Implementation

- `cmake/GenerateCasmTestFixtures.cmake`: new `casmreloc1.seq` (no `.ORG`,
  implicit relocatable default). Prints a fixed message via
  `DOS_PRINT_STR`, loading the message pointer with `LDX #<MSG` / `LDY
  #>MSG` -- `>MSG`'s immediate extraction is the fixture's one relocatable
  entry (program offset 3), reusing the exact classification shape
  `casmrelop2` (WP40) already established as correctly recorded. Message
  bytes are explicit hex, matching `casmhello`'s own convention.
- `tests/fixtures/casm/casmreloc1.ref.hex`: new trusted reference, 44
  bytes (36-byte PRG + 8-byte R6 table/footer: 1 entry + base/count/magic),
  hand-derived and independently confirmed byte-for-byte and
  hash-for-hash (`sha256=f888ce5a...`) via `hex_manifest_to_bin.py` before
  any runtime test.
- `CMakeLists.txt`: `casmreloc1` appended to `CASM_REF_NAMES` (22 total
  byte-identical references now) and `CASM_TEST_FIXTURES` (`test.d64`
  packaging, negligible size impact: 81 -> 79 blocks free).
- No production source change -- WP42 is verification-only except for the
  new fixture, per the plan's own scope.

## Static Verification

- `casm` build 1156 (baseline) -> 1157 (version-only completion
  increment), no-change rebuild confirmed stable at 1157.
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` all build
  clean.
- MAIN measured via `ld65 -m`: CODE `$254E` (9550) + RODATA `$93F` (2367)
  + BSS `$7DA` (2010) = 13927 of 14080 bytes -- **153 bytes headroom**,
  unchanged from WP41 (the version-stage string length is identical, so
  no code size change).
- `hex_manifest_to_bin.py` independently recomputed and confirmed
  `casmreloc1.ref`: 44 bytes, `sha256=f888ce5af9343849705b7c375fa51c0bd841d50461e7271f7e9c112006940654`,
  matching this walkthrough's own pre-computation exactly.

## Runtime Verification

The user ran the full consolidated matrix and confirmed: "All tests pass."

| Check | Result |
| --- | --- |
| `TEST_CASM_VMM` | pass |
| `TEST_CASM_SYMBOLS` | pass |
| `TEST_CASM_PASS1` | pass |
| `TEST_CASM_PASSCHECK` | pass |
| `TEST_CASM_EXPR` | pass |
| `TEST_CASM_RELOC` | pass |
| 22 byte-identical trusted references (`CASM <name>` / `COMP <name>.PRG <name>.REF`), including new `casmreloc1` | pass |
| 8 diagnostic-fixture scenarios (`p1undef1`, `p1dup1`, `brrng1`, `casmmfcr1`/`2`, `casmmfdiag1`/`2`, 9th-source-file rejection, `casmmfovf1`/`2`) | pass |
| WP31 7-fixture Phase 3/4 regression sample (`casmwp11`, `casmzp1`, `casmcma2`, `casmorg3`, `casmzpi2`, `casmpcovf`, `casmnumerrh`) -- unrun since WP36 | pass |
| Static-fixture regression (`casmemit1`, `casmhello` `RUN`, `casmorgexpl1`) | pass |
| **New:** `CASM CASMRELOC1`, `LOAD CASMRELOC1 3400` / `RUN` (zero-delta control) | pass |
| **New:** `LOAD CASMRELOC1 4000` / `RUN` | pass |
| **New:** `LOAD CASMRELOC1 5000` / `RUN` | pass |

### A Non-Reproducible Anomaly

Mid-verification, the user reported `TEST_CASM_PASS1` failing with the
same VMM/REU-exhaustion signature ("fffffff" across all fixtures) that
WP41 diagnosed and fixed twice. This was investigated rather than
dismissed: unlike WP41's case, the user resets VICE for every build, so a
stale carried-over leak was ruled out as the explanation. Re-inspection of
`casm_pass1.s` and `casm_passcheck.s` confirmed both are already correct
(`casm_pass1.s` calls `resourcesCleanup` after every fixture;
`casm_passcheck.s` allocates no VMM at all) -- ruling out a defect in
either harness itself. The user could not recall the exact test sequence
that preceded the failure and had not reproduced it since. A full
from-scratch re-run of the entire consolidated matrix, taken in order,
passed clean with no failure anywhere.

No root cause was identified, and per this project's discipline of only
changing source in response to a confirmed, understood defect, no fix was
applied. This is recorded in `brain/KNOWLEDGE.md` (Phase 0C.19) as an open,
unresolved, non-blocking observation for future awareness -- not treated
as fixed, and not blocking this WP's completion, since it did not
reproduce under controlled conditions.

## Documentation and DOX Closeout

- `brain/KNOWLEDGE.md`: Phase 0C.19 as-built section added, amending Phase
  0C.14-0C.18 with the final consolidated verification result, the
  `casmreloc1` runtime proof, and the non-reproducible anomaly.
- `wiki/tasks/casm.md`: WP42 checked complete; all six Phase 8 Acceptance
  items checked; CASM Phase 8 closing text added.
- `brain/task.md`: WP42 entry added and closed.
- `CHANGELOG.md`: Unreleased entry added.
- Taskwarrior: WP42 (`186aadb1-462d-48d1-87bb-e1c9af6c75e1`) and the CASM
  Phase 8 milestone (`c50df549-a7ae-4859-bd16-45a843425ce6`) both
  completed.

## Completion

**CASM Phase 8 WP42 is complete, and with it the CASM Phase 8 milestone
closes**, per the completion gate in
`brain/plans/2026-07-25-casm-phase8-wp42-verification-and-completion-gate.md`:
the full consolidated matrix passed, `casmreloc1` loaded and ran correctly
at all three tested addresses proving `aptRelocate` correctly consumes
CASM's native R6 output, `wiki/tasks/casm.md`'s Phase 8 Acceptance is fully
checked, the version-only completion increment is verified, all three
disk images build clean with a stable no-change rebuild, and the user
explicitly confirmed the runtime results. Final CASM `0.1.44` build 1157.
CASM Phase 8 (Native R6 Relocation) is complete. CASM Phase 9 (`.include`
processing) remains separately gated and unstarted per the master plan.
