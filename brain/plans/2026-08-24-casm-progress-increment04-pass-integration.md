---
feature: casm-progress-increment04-pass-integration
created: 2026-08-24
status: closed
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment03-progress-core, approved and complete
---

# Plan: CASM Progress Increment 4 - Pass Integration

## Status

**Approved 2026-08-24.** Parent plan:
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
- 2026-08-24: Approved and executed. progress.s wired into casm.s's real
  orchestration: progressInit/progressBeginPass at pass start,
  progressStatement via four small dispatch trampolines
  (crpCountLabel/Constant/Insn/Dir -- one shared hook, four call sites,
  since the existing token-type cmp/beq chain can't tolerate an A-clobbering
  call mid-chain), progressCheckPassTotals + progressCompletePass at
  Pass 2 completion, ordered exactly per the Hook Contract (after
  emitCheckPassAgreement, before listing finalization). Diagnostic IDs
  moved to common.inc and wired into diagnostics.s's real dispatch table.
  Two branch-range trampolines added (casm.s, diagnostics.s) and three
  test harnesses' fixed envelopes bumped (test_casm_faultsource,
  test_casm_pass1, test_casm_passcheck) -- all the same "unused but
  linked" class of correction this codebase's own history documents
  repeatedly. Live VICE evidence: test_casm_progress still 20/20 PASS;
  a real CASM CASMOPALL.S run produced the exact P1:/P2: persistent-line
  sequence with matching totals (160=160) and output byte-identical to
  Increment 1's own baseline hash. Final envelope: 340 bytes (1.2%)
  headroom. Full detail:
  brain/walkthroughs/2026-08-24-casm-progress-increment04-pass-integration.md.
  Awaiting user approval before Increment 5.
- 2026-08-24: **Closed, user-approved.** Increment 4 complete; walkthrough's Completion Gate fully checked.
