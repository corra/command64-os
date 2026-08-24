---
feature: casm-progress-increment04-pass-integration
created: 2026-08-24
status: proposed
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment03-progress-core, approved and complete
---

# Plan: CASM Progress Increment 4 - Pass Integration

## Status

**Proposed, not yet approved.** Parent plan:
`brain/plans/2026-07-29-casm-feature-progress-indication.md`.

## Objective

Integrate pass start/end, one shared statement-count hook, overflow propagation,
and cross-pass count agreement without changing parser or emitter semantics.

## Hook Contract

- Initialize progress after CASM state/resources are valid and before the first
  visible load/pass transition.
- Begin Pass 1 only after `CasmPassMode=MEASURE`; begin Pass 2 only after
  `CasmPassMode=EMIT`.
- In `casmRunPass`, count only IDENTIFIER, EQUALS, MNEMONIC, and DIRECTIVE after
  successful parse and before dispatch. Reload the statement type after calls.
- Exclude NEWLINE and EOF. `.INCLUDE` counts exactly once through DIRECTIVE.
- Fail before a 16-bit counter wraps, returning carry set and the contiguous
  approved diagnostic ID.
- Run count agreement after include replay and PC agreement, before listing
  capture finalization. Print `p2: done` only after all agreement checks pass.
- Preserve current carry paths and branch-range trampolines.

## Atomic Increments

1. Add progress initialization and pass-begin calls with explicit carry handling.
2. Add the allowlisted shared statement hook and focused classification tests.
3. Add Pass 1 completion and Pass 2 reset/independent total behavior.
4. Add overflow and count-disagreement diagnostics and synthetic harness cases.
5. Add agreement ordering and persistent pass transition output.
6. Run `test_casm_progress`, `test_casm_passcheck`, `test_casm_pass1`, parser,
   include, and representative production fixtures.
7. Measure size/cycles, perform no-change build, and write walkthrough evidence.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/casm.s` | Modify |
| `src/external/casm/progress.s` | Modify |
| `src/external/casm/diagnostics.s`, `common.inc` | Add approved diagnostics/constants |
| `tests/src/casm_progress/casm_progress.s` | Extend |
| Existing pass harnesses | Modify only if production-path observability requires it |

## Stop Conditions

Stop for duplicate/missed counts, parser semantic changes, disagreement ordering
changes, carry/stack ambiguity, branch-range failure, unexpected harness failure,
performance/envelope cap breach, no-change drift, or unrelated defects.

## Documentation, Task, and DOX Updates

Update trackers and plan progress. User-facing docs wait until feature completion;
update programmer docs only if an approved diagnostic becomes externally stable.

## Completion Gate

Exact totals, exclusions, overflow, disagreement, ordering, regressions, size,
and no-change behavior have evidence in the walkthrough and user approval.

## Progress

- 2026-08-24: Detailed plan drafted; pass integration not authorized.
