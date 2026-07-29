# CASM Phase 9 WP49 Verification Walkthrough

Status: Complete; user approved 2026-07-29
Branch: `feature/casm-phase9-wp49`
Candidate: CASM `0.1.50` build 1204

## Scope

WP49 consolidates Phase 9 verification without adding production behavior. It
reconciles WP43-WP48, reviews the complete `.INCLUDE` execution path, verifies
host artifacts and disk images, and requires user runtime confirmation before
Phase 9 may close.

## Baseline and Static Review

- Confirmed CASM `0.1.50`, build 1204, and the `$4300` production envelope.
- Corrected one approved documentation-only discrepancy: the final WP48
  corrections leave 85 bytes of production headroom, not the stale 196-byte
  intermediate value previously stated in `CMakeLists.txt`.
- CMake reported 14,478 code bytes and 2,104 relocation points.
- The immediate no-change build retained build 1204 and rebuilt no artifacts.
- Reviewed the production parser, include dispatcher, catalog, event log, frame
  traversal, diagnostics, and cleanup paths.
- Pass 1 alone reaches `includeCatalogLoad`; Pass 2 uses load-free
  `includeCatalogLookup`, verifies every event through `includeEventReplay`, and
  requires final cursor/count agreement through `includeReplayFinalCheck`.
- Both passes enter children through `sourceFramePush`; nested physical EOF
  restores parents through `sourceRefill`/`sourceFramePopInternal`.
- Fatal and successful exits retain central resource cleanup. No production
  defect was found during review.

## Host Build Evidence

The following targets linked at both `$3800` and `$3900` relocation bases:

- `casm`
- `test_casm_include`
- `test_casm_catalog`
- `test_casm_frame`
- `test_casm_event`
- `test_casm_pass1`
- `test_casm_passcheck`
- `test_casm_expr`
- `test_casm_vmm`
- `test_casm_symbols`
- `test_casm_reloc`

All retained their approved envelopes and persistent counters. A final
no-change build reported every target already built.

## Disk Images

Each image built independently and is 174,848 bytes:

| Image | SHA-256 |
| --- | --- |
| `build/image.d64` | `5bf060c4f0651f52c120a72ac8d245e9eee71eb5da503b36d0e1e4e1a28968de` |
| `build/test.d64` | `7328638a04b8d387a25aaafef09c2dccb24465dc83f7b15568582a686bf62d73` |
| `build/casm_overflow_test.d64` | `649dcca1d3a75f11074cfd8d2cda322be86578fe2633263ec39267feab76ca81` |
| `build/casm_include_test.d64` | `8a4b95ec15400d93bf595fa48532a95624fbed3bd106ccc7bf899c8774f91850` |

Directory output confirmed the documented programs, harnesses, trusted
references, large-source cases, catalog/frame fixtures, and end-to-end include
fixtures were present.

## MCP Runtime Evidence

VICE 3.10 was launched under `.agents/workflows/vice-mcp-testing.md` with true
drive emulation. Command64 boot was proven by the visible
`Command 64-DOS Version 0.4.0.2658` banner and shell prompt.

- `TEST_CASM_PASS1`: seven markers, `CASM PASS1: PASS`, returned to `c64[8]:>`.
- `TEST_CASM_PASSCHECK`: two markers, `CASM PASSCHECK: PASS`, returned to
  `c64[8]:>`.
- `TEST_CASM_INCLUDE`: fourteen markers, `CASM INCLUDE: PASS`, returned to
  `c64[9]:>`.

The MCP session for `TEST_CASM_CATALOG` became inconclusive because emulator
ownership/media synchronization was questioned and the user requested control.
The MCP-owned process was terminated. This was classified as a harness issue,
not a product failure; no MCP result was claimed for the interrupted case.

## User Runtime Confirmation

The user took control of runtime verification and reported on 2026-07-29:

> All tests pass

This confirms the remaining matrix, including:

- `TEST_CASM_CATALOG`, `TEST_CASM_FRAME`, and `TEST_CASM_EVENT`;
- all include-versus-flattened trusted-reference comparisons;
- included-source diagnostic and traceback cases `CASMIDP1.S`, `CASMIDUP1.S`,
  and `CASMIDDP1.S`;
- ordinary single-root diagnostic behavior with `CASMERR1.S`;
- representative malformed, missing-file, cycle, depth, capacity, source-size,
  and replay failures;
- successful post-failure reuse without reboot, proving cleanup; and
- expected shell return throughout.

## DOX Review

The root, `src`, `src/external`, `src/external/casm`, `tests`, `wiki`, and
`wiki/tasks` contracts were reviewed. No `AGENTS.md` change is required because
WP49 changed no production behavior, ABI, ownership, workflow, or durable
Phase 9 contract. The only product-tree edit is the approved correction of a
stale measurement comment.

## Completion Gate

Static, artifact, image, trusted-reference, failure, cleanup, and runtime
verification are complete. The user explicitly approved marking WP49 and Phase
9 complete on 2026-07-29. CASM remains `0.1.50` build 1204 because this approved
verification-only package introduced no production change. Phase 10 was not
activated.
