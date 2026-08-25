---
feature: casm-progress-indication
created: 2026-07-29
status: deferred-approved-plan
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
reconciled: 2026-08-24
---

# CASM Feature Plan: Progress and Processing Indication

## Status and Authorization

This is an approved plan for a future optional CASM feature outside the numbered
phases in the CASM master plan. The feature may be deferred indefinitely. This
approval authorizes preserving the plan and task records only; it does not
activate the feature or authorize implementation.

Before implementation begins, the current code and memory layout must undergo a
design/ABI review. After implementation and automated verification, the complete
change must undergo a second review before user runtime acceptance or merge.
Material changes to this contract require a plan amendment and renewed approval.

This plan was reconciled on 2026-08-24 against the user-approved completion of
CASM Phases 9-13 at CASM `0.4.0` build `1349`. The reconciliation updates the
baseline, integration points, and verification scope; it does not activate or
authorize implementation.

## Objective

Provide visible progress while CASM loads sources, discovers and traverses
`.INCLUDE` files, executes both assembly passes, and writes the output. The
feature must reassure the user that processing continues without changing
assembly semantics, source ordering, deterministic Pass 2 replay, diagnostics,
output bytes, resource cleanup, or command-line behavior.

The completed language now includes potentially long-running `.RES`, `.FILL`,
`.ALIGN`, and `.INCBIN` operations. Progress must therefore remain visibly live
during bounded byte-heavy directives as well as between dispatched statements.
Completed Phase 10 `/L` listing and `/M` symbol-map output also share the screen;
progress must relinquish transient-line ownership before either begins.

Progress is on by default and always enabled in this revision. A future
case-insensitive `/q` option is reserved as the preferred suppression mechanism,
but this revision must not parse, consume, or advertise `/q` as implemented.

Cancellation by keypress is a possible future extension. This revision performs
no keyboard polling and introduces no cancellation state or cleanup path.

## Prerequisites and Current Baseline

- CASM Phases 9-13 are complete and user-approved. The reconciled planning
  baseline is CASM `0.4.0` build `1349`; activation must still use and measure
  the then-current `main`.
- The implementation branch must start from the then-current `main`, not from
  this plan's 2026-07-29 planning baseline.
- Phase 9 source provenance, include catalog identity, frame-stack traversal,
  zero-Pass-2-source-I/O, and diagnostic traceback contracts remain intact.
- Phase 10 listing capture/rendering and symbol-map ordering remain intact.
  Progress must not alter `/L` or `/M` output bytes, rows, ordering, or errors.
- Phase 11 diagnostic, cleanup, boundary, and repeat-run hardening remains the
  minimum safety baseline.
- Phase 12 expression/pass-agreement behavior and Phase 13 directive semantics
  remain intact. Progress may observe these paths but must not become part of
  expression evaluation, directive sizing, or emitted-byte decisions.
- The current `casmRunPass`, source-load, include-frame, diagnostics, listing,
  map, emitter, input/output, resource, zero-page, MAIN/BSS, CLI, and test
  contracts must be re-read at activation time. This plan does not freeze
  today's addresses or headroom.
- A representative large fixture and a short-statement stress fixture must be
  selected before source edits so performance has a reproducible baseline. Add
  one byte-heavy directive fixture containing large fill/alignment output and
  `.INCBIN` payload processing.

## User-Visible Contract

### Persistent Lines

Persistent output is limited to major transitions:

```text
load: ROOT.S
p1: start
p1: done 00412 statements
p2: start
p2: done 00412 statements
write: PROGRAM.PRG
done: p1 00412, p2 00412, 016384 bytes
```

- Pass messages use the literal lowercase prefixes `p1:` and `p2:`.
- The Pass 2 cumulative statement counter resets to zero at Pass 2 start.
- The final successful line replaces the transient status with a persistent
  summary containing both pass totals and final output byte count.
- Elapsed time and percentage-complete are excluded. Includes make total work
  unknown until Pass 1 discovery finishes, and elapsed timing would introduce
  CIA ownership plus PAL/NTSC policy that this feature does not need.

### Transient In-Place Line

The active status occupies at most one 40-column screen line and is redrawn in
place. Its logical fields are:

```text
p1: d03 f07 FILENAME l00128 t00412
```

- `p1:` or `p2:` is the active pass.
- `dNN` is include depth, with top-level source depth zero.
- `fNN` is numeric physical-file identity.
- The filename field retains the first eight characters. Longer names are
  right-truncated; no ellipsis is required if it would exceed the column budget.
- `lNNNNN` is the physical line in the active file.
- `tNNNNN` is the 16-bit parsed-statement count for the active pass.
- Exact spacing and field widths may be tightened during design review, but all
  fields must remain visible in 40 columns and the first eight filename bytes
  must be retained when available.
- **Frozen 2026-08-24 (Increment 5):** the status line is exactly 34
  columns, `p1: dNN fNN NAMENAME lNNNNN tNNNNN`, and the load line is
  padded to the same 34. Every transient line MUST print exactly
  `CASM_PROG_LINE_WIDTH` characters: the in-place redraw rewinds by that
  many cursor-left bytes and the erase space-fills that many columns, so a
  line shorter than the constant walks backwards into the output above it
  (a real defect found live in Increment 5 and fixed there).

**Re-amended 2026-08-24 (Increment 5):** the user reinstated the
**source-loading** byte-cadence display (top-level and included files);
`progressSourceLoadBytes` is implemented and live. The other three
byte-cadence cases (output finalization, `.INCBIN`, and
`.RES`/`.FILL`/`.ALIGN`) remain dropped. MAIN was grown a second time,
`$7000` -> `$7400` (+1024 bytes), on measured evidence, to pay for it and
to leave room for Increments 6-11. The original Increment 2 amendment
follows, superseded only for the source-loading case:

**Amended 2026-08-24 (Increment 2 design/ABI review):** the four
byte-cadence transient updates below (source loading, output finalization,
`.INCBIN`, and `.RES`/`.FILL`/`.ALIGN`) are **dropped from this revision's
scope**, per the user's split-the-difference resolution of Finding 1 in
`brain/reviews/2026-08-24-casm-progress-design-abi-review.md`. Their own
byte accumulators fed nothing else in the contract (the final summary's
byte count still comes from output-write accounting, retained), and
removing them saved 70 of the 573 measured overflow bytes -- the rest was
closed by growing MAIN `$6C00` -> `$7000`. During these four operations the
transient line simply does not update until the operation completes, at
which point the next per-statement redraw or persistent-line transition
resumes visible progress; nothing scrolls, freezes, or crashes in the
interim. Restoring this text below at implementation time would cost
roughly 70 more bytes of MAIN, well within the 1033 bytes of headroom the
grown budget left free -- noted as an easy future increment if wanted, not
attempted in this revision.

During source loading, including a newly discovered `.INCLUDE`, the transient
line reports numeric file identity, the first eight filename characters, and
cumulative bytes loaded. It updates after every completed 256-byte source block
and once at the final short block or EOF.

During output finalization, the transient line reports the first eight output
filename characters and cumulative output bytes written. Existing output
buffering remains authoritative; progress must observe successful writes rather
than introduce separate writes or change flush boundaries.

During `.INCBIN`, the transient line reports that the active directive is
processing binary payload and shows cumulative payload bytes successfully read.
It must not describe the payload as a source/include file, add it to the Phase 9
catalog, or change its existing managed stream and emitter path.

During large `.RES`, `.FILL`, or `.ALIGN` operations, the transient line may
report cumulative bytes processed for the active directive. This operation
counter is display-only and must derive from bytes successfully accepted by the
existing emitter path. It does not contribute additional statements to either
pass total and does not replace the authoritative PC, output-byte, or directive
count.

Before `/L` listing rows or `/M` symbol-map rows are printed, CASM terminates the
transient line. Progress remains inactive while those rows are printed and may
resume only at a subsequent explicit orchestration transition. The listing and
map remain authoritative for their own formatting and screen output.

### Statement Counting

- Count statements returned by the parser for actual dispatch: labels,
  instructions, and directives, including `.INCLUDE`.
- Do not count blank lines, comment-only lines, NEWLINE results, or EOF.
- Maintain separate unsigned 16-bit Pass 1 and Pass 2 totals.
- Counter overflow is fatal before wraparound and uses a reviewed bounded-limit
  diagnostic.
- At successful Pass 2 completion, unequal Pass 1 and Pass 2 totals are fatal.
  This is an additional deterministic-replay check, not a replacement for final
  PC or include-event agreement.

### Update Cadence

- Increment and bounds-check the active counter after each parsed statement.
- Redraw the transient pass line every 64 parsed statements.
- Redraw immediately at pass start/end, root-file transition, include-frame
  push/pop, and before output finalization.
- Update source loading after every 256-byte block.
- Update `.INCBIN` payload and byte-heavy directive processing after every 256
  bytes and once at the final short block or operation completion. Do not redraw
  for every emitted byte.
- Persistent lines occur only at major transitions; do not emit periodic log
  lines every 64 statements.

### Diagnostics and Failure

- Before any existing diagnostic prints, clear or terminate the transient line
  so diagnostics, source context, carets, and include traceback cannot be
  overwritten.
- Do not add a generic `failed:` progress line. Existing diagnostics remain the
  sole failure report.
- Progress rendering failure must not mask the primary assembler failure.
- Progress owns no file handle, VMM allocation, or other cleanup resource.
- Listing and map rendering are screen-output boundaries equivalent to
  diagnostics: terminate the transient line before either renderer runs, but do
  not add progress text between their rows.

## Architecture

### Module Boundary

Add an isolated `src/external/casm/progress.s` module. It owns bounded progress
state and rendering. It must not own parser, source, include, emitter, file, or
diagnostic state; call sites pass or expose only the values needed to render.

Expected public interface, with exact names frozen by design review:

- initialize/reset progress state;
- print source-load transition and update loaded-byte count;
- begin a pass and reset its active 16-bit counter;
- record one dispatched statement and conditionally redraw;
- report root/include frame transition;
- complete a pass and print its persistent total;
- report output-write progress;
- report bounded `.INCBIN` payload and byte-heavy directive progress;
- clear the transient line before diagnostics;
- suspend transient output before listing or map rendering;
- print the final successful summary;
- compare Pass 1 and Pass 2 statement totals.

Diagnostics may import only the transient-clear routine. `progress.s` may use
the established diagnostic character/string/decimal formatting primitives only
if design review proves there is no import cycle. Otherwise it owns minimal
private formatting routines. It must not route normal progress through fatal
diagnostic selection.

### Instrumentation Points

- `casm.s`: orchestration transitions, pass start/end, successful summary,
  statement-count hook in the one shared `casmRunPass` dispatch path, and fatal
  count disagreement propagation.
- `source.s`: successful 256-byte physical source-load block completion.
- Include traversal owner (`casm.s`/`source.s` at implementation time): frame
  push, frame pop, and root transition notification after state is committed.
- Output/file owner (`emit.s` or `fileio.s` at implementation time): successful
  output-byte commitment and final byte total without changing write batching.
- `emit.s`: bounded notification from the existing `.RES`/`.FILL`/`.ALIGN`
  shared byte-emission path and `.INCBIN` stream path. Notification cadence must
  not add a call per byte; use the already-counted 256-byte boundary or an
  equivalently bounded outer hook selected during design review.
- `diagnostics.s`: one call to clear/terminate transient status before all fatal
  diagnostic text.
- `listing.s` and `map.s`, or their orchestration owner in `casm.s`: terminate
  transient status once before renderer entry. Do not instrument row rendering,
  listing byte mirroring, symbol iteration, or VMM capture loops.

Do not instrument lexer byte delivery, expression evaluation, opcode lookup,
symbol lookup, relocation recording, or VMM window transfers. Those hot paths
would duplicate counts and add avoidable overhead.

## ABI and Storage Effects

- Use ordinary bounded BSS for persistent progress state. No new zero-page byte
  is authorized by this plan.
- Required logical state is expected to include two 16-bit statement totals, an
  active 16-bit count, a six-bit redraw divider or equivalent maskable state,
  active phase, transient-line-visible flag, and bounded rendering scratch.
- Reuse existing authoritative source/include/output identity and counters where
  safe; do not mirror whole filenames or frame records.
- Reuse authoritative Phase 13 directive/input counters where safe. Any
  operation-local display counter must be bounded and must not enlarge parser,
  listing, map, include, symbol, or directive records.
- Any MAIN envelope increase requires measured evidence and explicit approval at
  implementation time. Do not pre-authorize an address or size increase here.
  **Amended 2026-08-24 (Increment 2 design/ABI review):** a full-spec
  `progress.s` was written, assembled, and linked against CASM's real
  `casm_3800.cfg` and real compiled objects, producing `ld65`'s own overflow
  error at exactly 573 bytes over the Increment-1-measured 231-byte
  headroom -- measured evidence, not an estimate. The user approved growing
  MAIN from `$6C00` to `$7000` (+1024 bytes) in `casm_3800.cfg` and its
  `casm_3900.cfg` twin, combined with a scope trim (see User-Visible
  Contract amendment below), verified by a real re-link at 1033 bytes of
  fresh headroom remaining. Full detail:
  `brain/reviews/2026-08-24-casm-progress-design-abi-review.md`.
- New diagnostic identifiers, if needed for statement overflow or count
  disagreement, must be allocated contiguously with compile-time range asserts.
  **Amended 2026-08-24:** frozen as `CASM_DIAG_PROGRESS_COUNTER_OVERFLOW = $55`
  and `CASM_DIAG_PROGRESS_PASS_TOTAL_MISMATCH = $56`, contiguous after the
  last allocated Phase 13 id (`$54`). Distinct from the pre-existing
  `CASM_DIAG_PASS_MISMATCH` ($2F, Phase 6B/WP30) -- that ID belongs to
  `emitCheckPassAgreement`'s final-PC check and is not reused, matching this
  plan's own "not a replacement for final PC ... agreement" instruction.
- Existing parser statement records, include event records, physical catalog
  records, frame records, token records, and relocation records must not grow for
  this feature.

## Register, Flag, and Scratch Contract

The design review must freeze every public routine's inputs, outputs, preserved
registers, carry/zero meaning, and scratch ownership before implementation.
Minimum requirements:

- The statement hook must preserve parser/emitter-visible state and return carry
  clear on success, carry set with `A` holding a diagnostic on overflow or an
  internal progress failure.
- Transition and render calls may clobber `A`, `X`, and `Y` only where the caller
  has no live values, or must explicitly preserve them.
- No routine may assume OS/KERNAL printing preserves shared zero-page scratch.
- Decimal conversion and filename rendering scratch must not overlap source,
  include, expression, VMM, diagnostics, or output state across nested calls.
- The implementation review must audit all push/pop balance and every carry
  propagation site introduced by progress calls.

## Performance Budget

Planning estimate:

- Counter maintenance alone: under 1% to 3% slowdown.
- A redraw every 64 statements plus transition updates: typically 1% to 5%.
- Short-statement worst case may approach 5% to 10%.
- Per-line full redraw is prohibited because estimated slowdown is 20% to 60%
  or worse on simple input.

Acceptance thresholds, measured in the same VICE configuration:

- Representative large fixture: no more than 5% elapsed-time regression.
- Short-statement stress fixture: no more than 10% regression.
- Repeat each baseline and candidate timing enough times to identify emulator
  variance; record raw runs and the comparison method in the walkthrough.
- Stop and redesign if either threshold is exceeded. Do not weaken the threshold
  during implementation without a plan amendment and explicit approval.

## Atomic Implementation Increments

### Detailed Plan Index

Each increment has its own proposed plan and requires separate approval before
that increment begins:

| Increment | Detailed plan |
| --- | --- |
| 1 | `brain/plans/2026-08-24-casm-progress-increment01-activation-baseline.md` |
| 2 | `brain/plans/2026-08-24-casm-progress-increment02-design-abi-review.md` |
| 3 | `brain/plans/2026-08-24-casm-progress-increment03-progress-core.md` |
| 4 | `brain/plans/2026-08-24-casm-progress-increment04-pass-integration.md` |
| 5 | `brain/plans/2026-08-24-casm-progress-increment05-source-include-integration.md` |
| 6 | `brain/plans/2026-08-24-casm-progress-increment06-directive-integration.md` |
| 7 | `brain/plans/2026-08-24-casm-progress-increment07-output-diagnostic-listing.md` |
| 8 | `brain/plans/2026-08-24-casm-progress-increment08-automated-verification.md` |
| 9 | `brain/plans/2026-08-24-casm-progress-increment09-implementation-review.md` |
| 10 | `brain/plans/2026-08-24-casm-progress-increment10-runtime-acceptance.md` |
| 11 | `brain/plans/2026-08-24-casm-progress-increment11-completion-gate.md` |

The detailed plans were drafted as planning records only. Their proposed
technical decisions do not amend this parent contract until approved.

Increment 6 amendment, user-approved 2026-08-24: restore bounded directive-byte
cadence for `.RES`, `.FILL`, `.ALIGN`, and `.INCBIN`, superseding the directive
part of Increment 2's size-driven scope trim. Any growth beyond the current
`$7400` MAIN envelope remains separately gated on measured evidence.

1. **Activation and baseline:** confirm the recorded Phase 9-13 completion state,
   create the dedicated implementation branch, refresh graph/source traces, and
   capture current MAIN/BSS, output/listing hashes, map/listing screen output,
   fixture timings, and Taskwarrior state.
2. **Design/ABI review gate:** freeze screen layouts, exact public routines,
   storage bytes, diagnostics, register/flag contracts, and call sites. Obtain
   explicit approval before source edits.
3. **Progress core:** add `progress.s` with initialization, bounded counters,
   64-statement throttle, formatting, in-place clear/redraw, and module-level
   tests or a focused harness.
4. **Pass integration:** hook the shared statement dispatcher and pass
   transitions; implement overflow and Pass 1/Pass 2 count disagreement.
5. **Source/include integration:** hook 256-byte load completion and committed
   root/frame transitions without changing source bytes, event order, or Pass 2
   filesystem behavior.
6. **Directive integration:** hook bounded `.RES`/`.FILL`/`.ALIGN` processing and
   `.INCBIN` payload reads without changing directive sizing, source catalogs,
   stream ownership, emitted bytes, or pass agreement.
7. **Output/diagnostic/listing integration:** observe successful output writes,
   clear transient status before diagnostics and `/L`/`/M` rendering, and print
   the successful summary.
8. **Automated verification:** run focused tests, full relevant CASM regression,
   artifact comparison, resource audit, size measurement, and timing matrix.
9. **Full implementation review gate:** review UX, cycle cost, memory, all ABI
   contracts, carry/stack safety, diagnostics, include traversal, deterministic
   replay, Phase 13 directives, listing/map coexistence, output identity, and
   test evidence. Resolve findings before runtime.
10. **User runtime acceptance:** provide a walkthrough for source load, nested
    includes, both passes, byte-heavy directives, listing/map output, output,
    success summary, and representative failures.
11. **Completion gate:** only after user confirmation, update version/build,
     changelog, task records, knowledge/memory, DOX, and walkthrough; ask whether
     the optional feature is complete before marking it done.

## Verification Matrix

### Static and Build

- Configure and build through CMake; do not invoke assembler/linker directly.
- Build CASM, focused tests, and all disk images that contain affected fixtures.
- Confirm zero warnings/errors and stable no-change build number.
- Inspect link map, PRG header, R6 footer, relocation count, MAIN/BSS, imports,
  exports, and zero-page usage.
- `git diff --check` must pass.

### Functional

- Single top-level source with fewer than 64 statements.
- More than 64 statements, proving throttled redraw and exact final totals.
- Blank/comment-heavy source, proving only dispatched statements count.
- Multiple top-level files and filenames shorter/equal/longer than eight bytes.
- Nested includes with push/pop, sequential reinclusion, and maximum valid depth.
- Pass 2 performs zero source filesystem I/O with progress enabled.
- Large `.RES`, `.FILL`, and `.ALIGN` operations update at bounded byte cadence
  without changing either pass's statement total or final PC.
- `.INCBIN` reports payload processing without creating a source-catalog entry;
  both passes and final output remain identical to the trusted reference.
- `/L`, `/M`, and combined `/L /M` runs terminate transient output before rows,
  preserve exact listing/map content and ordering, and leave no stale status line.
- Static and relocatable outputs remain byte-identical to progress-free trusted
  references except for intentional version/build changes.
- Output writes report committed bytes and the final summary matches artifact
  size semantics defined during design review.
- Synthetic counter-overflow harness fails before 16-bit wraparound.
- Synthetic pass-count mismatch is fatal without replacing existing final-PC and
  event-count checks.

### Diagnostic and Cleanup

- Syntax, undefined-symbol, include-load, cycle, depth, event-replay, output,
  `.INCBIN`, assertion, listing, map, and cleanup failures clear the transient
  line before existing diagnostics.
- Source line/caret and include traceback remain readable and unchanged.
- No generic progress failure line is printed.
- Repeated success/failure runs leave shell, handles, VMM, and output cleanup
  intact.

### Performance

- Time the selected representative large fixture before and after.
- Time the selected short-statement stress fixture before and after.
- Confirm the 5% typical and 10% stress thresholds.
- Record whether disk loading, Pass 1, Pass 2, or output dominates each run.

## Expected Files

- New: `src/external/casm/progress.s`.
- Likely production changes: `src/external/casm/casm.s`, `source.s`,
  `diagnostics.s`, `common.inc`, `emit.s`, and possibly `fileio.s`.
- Phase 10 integration must be reviewed in `listing.s` and `map.s`; prefer a
  single orchestration hook in `casm.s` over changes to their row-rendering hot
  paths when the current call graph permits it.
- Build/test changes: `CMakeLists.txt`, a focused progress harness or fixtures,
  and fixture generation only where required by the approved design review.
- Records: `wiki/tasks/casm-progress-indication.md`, `wiki/tasks/casm.md`,
  `brain/task.md`, Taskwarrior, and at completion `CHANGELOG.md`,
  `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, a walkthrough, and affected DOX.

## Explicitly Out of Scope

- Implementing or parsing `/q`; it is only reserved for a future
  case-insensitive quiet mode.
- Keyboard polling, cancellation, break handling, or partial-output policy for
  user abort.
- Percentages, ETA, elapsed time, CIA timer ownership, or PAL/NTSC conversion.
- Redirectable/log-oriented progress output.
- Real-time `/M` symbol emission. Existing post-Pass-2 `/M` behavior is only a
  screen-ownership integration boundary for this feature.
- Build-duration display. It remains a separate backlog feature requiring its
  own CIA ownership and PAL/NTSC timing contract.
- Changes to assembly grammar, emitted bytes, include resolution, include-event
  ordering, symbol semantics, relocation semantics, or diagnostics content.

## Stop Conditions

Stop and request guidance if:

- The current Phase 9-13 architecture differs materially from the reconciled
  contracts above.
- The progress module requires new zero-page storage, record-layout growth, or a
  MAIN increase before measurement and approval.
- A clean diagnostics import boundary would create a module cycle.
- Accurate statement counting requires parser or lexer semantic changes.
- Progress changes output bytes, include replay, source I/O in Pass 2, cleanup,
  directive sizing, `.INCBIN` stream behavior, listing/map output, or diagnostic
  provenance.
- The deferred one-byte SEQ/EOI defect must be changed to implement progress.
  That inherited KERNAL/drive behavior remains separate work and must not be
  absorbed into this feature.
- Performance exceeds either accepted threshold.
- Implementation review finds unresolved correctness, UX, memory, cycle, stack,
  carry, or test-evidence concerns.

## Completion Gate

The feature is not complete until both reviews pass, automated evidence is clean,
the user completes the runtime walkthrough, and the user explicitly approves
marking the task done. Until activation, this plan and its task remain deferred
and pending.
