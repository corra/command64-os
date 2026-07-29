---
feature: casm-optional-phase10-progress-indication
created: 2026-07-29
status: deferred-approved-plan
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
---

# Plan: CASM Optional Phase 10 - Progress and Processing Indication

## Status and Authorization

This is an approved plan for a future, optional CASM Phase 10. The feature may
be deferred indefinitely. This approval authorizes preserving the plan and task
records only; it does not activate the phase or authorize implementation.

Before implementation begins, the current code and memory layout must undergo a
design/ABI review. After implementation and automated verification, the complete
change must undergo a second review before user runtime acceptance or merge.
Material changes to this contract require a plan amendment and renewed approval.

## Objective

Provide visible progress while CASM loads sources, discovers and traverses
`.INCLUDE` files, executes both assembly passes, and writes the output. The
feature must reassure the user that processing continues without changing
assembly semantics, source ordering, deterministic Pass 2 replay, diagnostics,
output bytes, resource cleanup, or command-line behavior.

Progress is on by default and always enabled in this revision. A future
case-insensitive `/q` option is reserved as the preferred suppression mechanism,
but this revision must not parse, consume, or advertise `/q` as implemented.

Cancellation by keypress is a possible future extension. This revision performs
no keyboard polling and introduces no cancellation state or cleanup path.

## Prerequisites

- CASM Phase 9 must be complete and user-approved before this optional phase is
  activated.
- The implementation branch must start from the then-current `main`, not from
  this plan's 2026-07-29 planning baseline.
- Phase 9 source provenance, include catalog identity, frame-stack traversal,
  zero-Pass-2-source-I/O, and diagnostic traceback contracts remain intact.
- The current `casmRunPass`, source-load, include-frame, diagnostics, output,
  resource, zero-page, MAIN/BSS, CLI, and test contracts must be re-read at
  activation time. This plan does not freeze today's addresses or headroom.
- A representative large fixture and a short-statement stress fixture must be
  selected before source edits so performance has a reproducible baseline.

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

During source loading, including a newly discovered `.INCLUDE`, the transient
line reports numeric file identity, the first eight filename characters, and
cumulative bytes loaded. It updates after every completed 256-byte source block
and once at the final short block or EOF.

During output finalization, the transient line reports the first eight output
filename characters and cumulative output bytes written. Existing output
buffering remains authoritative; progress must observe successful writes rather
than introduce separate writes or change flush boundaries.

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
- clear the transient line before diagnostics;
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
- `diagnostics.s`: one call to clear/terminate transient status before all fatal
  diagnostic text.

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
- Any MAIN envelope increase requires measured evidence and explicit approval at
  implementation time. Do not pre-authorize an address or size increase here.
- New diagnostic identifiers, if needed for statement overflow or count
  disagreement, must be allocated contiguously with compile-time range asserts.
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

1. **Activation and baseline:** confirm Phase 9 completion, create the dedicated
   implementation branch, refresh graph/source traces, capture current MAIN/BSS,
   output hashes, fixture timings, and Taskwarrior state.
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
6. **Output/diagnostic integration:** observe successful output writes, clear
   transient status before diagnostics, and print the successful summary.
7. **Automated verification:** run focused tests, full relevant CASM regression,
   artifact comparison, resource audit, size measurement, and timing matrix.
8. **Full implementation review gate:** review UX, cycle cost, memory, all ABI
   contracts, carry/stack safety, diagnostics, include traversal, deterministic
   replay, output identity, and test evidence. Resolve findings before runtime.
9. **User runtime acceptance:** provide a walkthrough for source load, nested
   includes, both passes, output, success summary, and representative failures.
10. **Completion gate:** only after user confirmation, update version/build,
    changelog, task records, knowledge/memory, DOX, and walkthrough; ask whether
    the optional phase is complete before marking it done.

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
- Static and relocatable outputs remain byte-identical to progress-free trusted
  references except for intentional version/build changes.
- Output writes report committed bytes and the final summary matches artifact
  size semantics defined during design review.
- Synthetic counter-overflow harness fails before 16-bit wraparound.
- Synthetic pass-count mismatch is fatal without replacing existing final-PC and
  event-count checks.

### Diagnostic and Cleanup

- Syntax, undefined-symbol, include-load, cycle, depth, event-replay, output,
  and cleanup failures clear the transient line before existing diagnostics.
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
  `diagnostics.s`, `common.inc`, and either `emit.s` or `fileio.s`.
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
- Changes to assembly grammar, emitted bytes, include resolution, include-event
  ordering, symbol semantics, relocation semantics, or diagnostics content.

## Stop Conditions

Stop and request guidance if:

- Phase 9 is not complete or its final architecture differs materially from this
  plan's prerequisites.
- The progress module requires new zero-page storage, record-layout growth, or a
  MAIN increase before measurement and approval.
- A clean diagnostics import boundary would create a module cycle.
- Accurate statement counting requires parser or lexer semantic changes.
- Progress changes output bytes, include replay, source I/O in Pass 2, cleanup,
  or diagnostic provenance.
- Performance exceeds either accepted threshold.
- Implementation review finds unresolved correctness, UX, memory, cycle, stack,
  carry, or test-evidence concerns.

## Completion Gate

The phase is not complete until both reviews pass, automated evidence is clean,
the user completes the runtime walkthrough, and the user explicitly approves
marking the task done. Until activation, this plan and its task remain deferred
and pending.
