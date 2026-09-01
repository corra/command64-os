# CASM Progress and Processing Indication

Status: [x]
Type: Optional Feature
Classification: Complete, user-approved 2026-08-31
Taskwarrior: completed (`1acb36e3-2c0e-4f24-998b-279b2578bee4`)
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
Increment 8 (automated verification) was approved 2026-08-31. Its host-side
Atomic Increments 1-3 are done: a new self-bootable `casm_progress_test_d64`
disk carrying `test_casm_progress` plus 13 `casmpg*` cadence/shape fixtures
and 10 hand-derived trusted references (`tests/fixtures/casm/casmpg*.ref.hex`).
The full build stays green with `casm.prg` byte-identical to the Increment 7
baseline (`BUILD_CASM` 1378). Live-VICE 2026-08-31: Atomic Increment 4 is
complete - all 10 `casmpg*` end-to-end fixtures plus the 5-way
option-identity sub-matrix `FILES COMPARE OK`, with `DONE:` byte counts
matching the hand-derived references exactly and the progress
cadence/counter behaviour correct (directives counted, blank/comment lines
excluded, nested-include + re-inclusion + multi-root all traversed).
Atomic Increment 8 (exact no-change rebuild) is complete and byte-stable.
Atomic Increment 5 is partial (fatal input-open path clean; the
mid-assembly fatal + partial-output cleanup case is noted non-blocking).
Atomic Increments 6 (31-harness regression) and 7 (timing) were waived by
the user 2026-08-31 as redundant re-checks of a byte-identical binary that
Increment 7 already swept 31/31, with the performance caps non-blocking
since the 2026-08-26 amendment. **Increment 8 is complete, user-approved 2026-08-31.**

Increment 9 (full implementation review) was executed 2026-08-31: a
line-by-line audit of the entire progress-feature diff against the
Increment 2 frozen ABI. The core design and its integration were found
sound and consistent with the Increment 4 live evidence. Five findings
(register: `brain/reviews/2026-08-24-casm-progress-implementation-review.md`):
PR-1 (private-helper/ABI clobber docs understated X/Y - fixed), PR-2
(`CASM_PROG_FLAG_SUSPENDED` was write-only - fixed by gating the render
entry points), PR-4 (undocumented `CasmPtr0` clobber in `crpProgressHook`
- comment fixed); PR-3 (`DONE:` byte count wraps for output > 64KB -
deferred as a known display limitation) and PR-5 (INFO). Remediation
rebuilt clean (`BUILD_CASM` 1378 -> 1379, `$7400` envelope still fits),
exact no-change rebuild stable, and a live-VICE smoke confirmed no
behavioral regression. **Increment 9 is complete, user-approved
2026-08-31.**

Increment 10 (runtime acceptance) was accepted by the user 2026-08-31
after a live matrix against `CASM V0.4.0.1379`: six cases (short assemble,
nested include + sequential re-inclusion, `/M /L` screen ownership, R6
`WRITE` line, a new `casmpgbad.s` mid-assembly failure fixture, and a
repeated invocation) all passed with no findings. The failure fixture
confirmed `diagPrintFatal`'s transient-clear wipes the status line before
the diagnostic and `outputAbort` leaves no orphan partial PRG.

**Increment 11 (completion gate) closed 2026-08-31 with user feature-complete
sign-off.** CASM was promoted `0.4.0` -> `0.5.0` (build `1380`,
`casm.prg` `e8a6731f`, 642 bytes MAIN headroom). A fresh consolidated
live sweep - 31/31 `test_casm_*` harnesses across six disks (+
`test_casm_progress` on its own disk), all 10 `casmpg*` fixtures
`FILES COMPARE OK` with exact `DONE:` byte counts, the `casmpgbad`
failure case (transient cleared, `DIR`-confirmed no orphan PRG), and the
`/M /L` output-identity check - passed with **no findings**. Full
CHANGELOG / KNOWLEDGE / user+programmer docs / AGENTS / master-plan /
`release/` closeout completed. **The feature is complete and merged to
`main`.**

Deferred and recorded (not a blocker): the `DONE: ... nnnnn BYTES` display
is a 16-bit accumulator and wraps for an output PRG larger than 65535
bytes - the written file is still correct.

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
- [x] Implement only in separately approved atomic increments.
- [x] Complete automated build, artifact, functional, cleanup, and performance
      verification.
- [x] Complete the full implementation review before runtime acceptance or
      merge.
- [x] Obtain user runtime confirmation and explicit completion approval.

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

## Performance Thresholds -- Amended 2026-08-26

The original acceptance thresholds were no more than 5% elapsed-time
regression on the representative large fixture and 10% on the short-statement
stress fixture. Raw end-to-end measurement after Increment 7 exceeded both
(`casmbiga`+`casmbigb` 228.14s -> 257.06s, +12.7%; `casmopall.s` 87.74s ->
104.76s, +19.4%).

**The user accepted the nominal excess on 2026-08-26**, recorded as a formal
amendment to the parent plan's Performance Budget. The caps are no longer
blocking, the "stop and redesign" instruction is waived, and no redesign is
required.

These figures are not isolated progress-indication overhead and should not be
cited as such. `casm.prg` grew from 31,185 to 33,368 bytes between baseline
and measurement, covering Phase 13 as well as this feature; under true-drive
emulation that is added load time charged to every run regardless of statement
count, visible in the floor moving from 82-88s to 95.24s. A like-for-like
isolation against a pre-progress `casm.prg` in a single session remains
available but is optional.
