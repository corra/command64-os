# CASM Progress and Processing Indication

Status: [ ]
Type: Optional Future Feature
Phase: CASM Phase 10 (deferred)
Taskwarrior: 36 (`1acb36e3-2c0e-4f24-998b-279b2578bee4`)
Plan: `brain/plans/2026-07-29-casm-optional-phase10-progress-indication.md`

## Goal

Add an always-on, bounded progress display for CASM source loading, include
processing, Pass 1, Pass 2, and output writing without changing assembly output
or deterministic replay.

This optional phase may be deferred. The plan is approved for future use, but
implementation is not active or authorized until its design/ABI review passes.

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
      with explicit user approval on 2026-07-29; this does not activate Phase
      10 or satisfy its separate design/ABI review gate.
- [ ] Complete and approve the pre-implementation design/ABI review.
- [ ] Freeze exact screen layout, storage, diagnostics, and register/flag ABI.
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
