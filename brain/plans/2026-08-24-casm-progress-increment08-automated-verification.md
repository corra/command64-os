---
feature: casm-progress-increment08-automated-verification
created: 2026-08-24
status: proposed
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment07-output-diagnostic-listing, approved and complete
---

# Plan: CASM Progress Increment 8 - Automated Verification

## Status

**Proposed, not yet approved.** This increment adds verification artifacts and
performs no intentional production behavior change.

## Objective

Run the complete automated/static matrix against one candidate, add a dedicated
self-bootable progress disk and permanent fixtures where approved, and produce
reviewable artifact, resource, size, and timing evidence.

## Verification Architecture

- Add `casm_progress_test_d64` rather than consuming `test.d64`, listing, overflow,
  or Phase 13 disk capacity. Include `command64`, `casm`, `comp`, focused harness,
  sources, includes, payloads, and trusted references with writable headroom.
- Use CMake for all configure/build/fixture/disk/toolchain operations.
- Cover <64, 64/65/128 statements, blanks/comments, multi-root, filename widths,
  nested/reincluded includes, large fixed fills/alignment, `.INCBIN`, static/R6,
  `/L`, `/M`, `/L /M`, diagnostics, cleanup, overflow, and mismatch.
- Compare emitted artifacts and listings against trusted references/native COMP.
- Run all existing relevant CASM harnesses and Phase 9-13 production fixtures.
- Inspect production/focused envelopes, BSS, imports/exports, zero page, disk
  entries/blocks, handles/VMM cleanup, and repeat-run behavior.
- Enforce <=5% representative and <=10% short-statement slowdown from Increment 1.

## Atomic Increments

1. Add fixture/reference generation and focused target dependencies.
2. Add the dedicated disk with collision-safe names and explicit writable reserve.
3. Build the focused target, candidate CASM, references, and all affected disks.
4. Run focused and complete relevant harness matrices.
5. Run static/R6/listing/map native comparisons and failure cleanup checks.
6. Run repeated timing matrix in the same VICE configuration.
7. Perform exact no-change rebuild and hash/counter comparison.
8. Record all evidence and unresolved findings in the walkthrough.

## Expected Files

| File | Planned action |
| --- | --- |
| `CMakeLists.txt` | Add fixtures, target dependencies, and dedicated disk |
| `cmake/GenerateCasmTestFixtures.cmake` | Add deterministic fixtures if required |
| `tests/fixtures/casm/*` or existing CASM fixture location | Add sources/payloads/references |
| `tests/AGENTS.md` | Update only for durable disk/launch contracts |
| Matching walkthrough | Create |

## Stop Conditions

Stop on any unexpected test failure, artifact difference, cleanup leak, disk
overflow/name collision, cap breach, no-change counter/hash drift, undeclared
generated dependency, or new defect. Disclose and defer unrelated defects.

## Documentation, Task, and DOX Updates

Record matrix state in trackers. Update tests DOX with the dedicated disk's stable
location, contents, launch contract, and capacity requirement if created. Apply
the CMake overlay-event workflow to any qualifying build-system additions.

## Completion Gate

All matrix rows pass with raw evidence, no unresolved blocker remains, artifacts
and no-change builds are stable, walkthrough exists, and user approves Increment 8.

## Progress

- 2026-08-24: Detailed verification plan drafted; no fixtures or disk added.
