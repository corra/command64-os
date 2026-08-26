# CASM Progress and Processing Indication

Status: [/]
Type: Optional Feature
Classification: Active, incrementally approved
Taskwarrior: 33 (`1acb36e3-2c0e-4f24-998b-279b2578bee4`)
Plan: `brain/plans/2026-07-29-casm-feature-progress-indication.md`

## Goal

Add an always-on, bounded progress display for CASM source loading, include
processing, Pass 1, Pass 2, and output writing without changing assembly output
or deterministic replay.

This optional feature is active under separately approved increments. The
design/ABI review and Increments 1-7 are complete and user-approved; Increment 6
closed 2026-08-24 with bounded directive cadence restored. Increment 7 (output,
diagnostic, listing, and map integration) was approved and activated 2026-08-25
and closed 2026-08-26, delivering primary-output byte accounting, the
`WRITE: <name>` line, a universal fatal-diagnostic transient clear, `/L` and
`/M` suspension, and the `DONE: P1 nnnnn, P2 nnnnn, nnnnn BYTES` final summary.
Increment 8 (automated verification) is next and not yet approved.
It is not a numbered phase in the CASM master plan and does not replace or
renumber Phase 10, Symbol Map and Listing.

## Approved Behavior

- Print persistent lines only at major load, pass, write, and completion
  transitions.
- Maintain one in-place 40-column status line during active processing.
- Show numeric file identity plus the first eight filename characters.
- Show active pass, include depth, physical line, and per-pass parsed-statement
  total.
- Count dispatched statements, not blank or comment-only lines.
- Reset the total at Pass 2 start and retain both pass totals for the summary.
- Redraw every 64 statements and at immediate source/include/pass transitions.
- Update source loading after each 256-byte block.
- Treat 16-bit counter overflow and unequal Pass 1/Pass 2 statement totals as
  fatal.
- Clear transient output before existing diagnostics; add no generic failure
  line.
- Exclude percentages, elapsed time, and cancellation.
- Reserve a future case-insensitive `/q` suppression option without implementing
  it in this revision.

## Review Gates

- [x] Confirm CASM Phase 9 is complete before activation. Phase 9 completed
      with explicit user approval on 2026-07-29; this does not activate this
      feature or master-plan Phase 10, or satisfy the feature's separate
      design/ABI review gate.
- [x] Complete and approve the pre-implementation design/ABI review.
- [x] Freeze exact screen layout, storage, diagnostics, and register/flag ABI.
- [ ] Implement only in separately approved atomic increments.
- [ ] Complete automated build, artifact, functional, cleanup, and performance
      verification.
- [ ] Complete the full implementation review before runtime acceptance or
      merge.
- [ ] Obtain user runtime confirmation and explicit completion approval.

## Performance Limits

- Representative large fixture: at most 5% slowdown.
- Short-statement stress fixture: at most 10% slowdown.
- Exceeding either threshold stops implementation for redesign.

## Future Considerations

- Implement case-insensitive `/q` to suppress progress.
- Consider keypress cancellation as a separately planned feature with its own
  cleanup and partial-output contract.

## Manual Verification Outline

1. Assemble short, long, multi-root, and nested-include sources.
2. Confirm load progress, `p1:` and `p2:` transitions, in-place updates, and the
   final summary.
3. Confirm blank/comment-only lines do not increase statement totals.
4. Confirm filenames retain their first eight characters and numeric identity.
5. Trigger representative fatal diagnostics and confirm no transient status
   overwrites the diagnostic, source caret, or include traceback.
6. Compare static and R6 outputs byte-for-byte with trusted references.
7. Run the timing matrix and confirm both performance limits.

Do not mark this task done until the user approves the completed walkthrough.

## Open Performance Item (as of 2026-08-26)

The approved acceptance thresholds -- no more than 5% elapsed-time regression
on the representative large fixture and 10% on the short-statement stress
fixture -- are **not yet demonstrated met**. Raw end-to-end measurement after
Increment 7 is over both (`casmbiga`+`casmbigb` +12.7%, `casmopall.s` +19.4%),
but that measurement does not isolate this feature: `casm.prg` grew from
31,185 to 33,368 bytes since the baseline, covering Phase 13 as well as
progress, which adds true-drive load time to every run regardless of statement
count. A like-for-like isolation against a pre-progress `casm.prg` in the same
VICE session is required before the budget can be claimed or a redesign judged
necessary. This must be settled before the feature's completion gate.
