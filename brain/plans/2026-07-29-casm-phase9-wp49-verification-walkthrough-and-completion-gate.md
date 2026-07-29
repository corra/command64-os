---
feature: casm-phase9-wp49-verification-walkthrough-and-completion-gate
created: 2026-07-29
status: complete
---

# Plan: CASM Phase 9 WP49 - Verification, Walkthrough, and Completion Gate

## Objective

Consolidate and independently verify the complete Phase 9 `.INCLUDE`
implementation delivered by WP43-WP48. WP49 is verification and closeout only:
it adds no production behavior. A discovered defect stops WP49 until its root
cause, exact remediation, tests, and resource impact receive an amended plan
and explicit approval.

Parent plan: `brain/plans/2026-07-25-casm-phase9-include-processing.md`.
Prerequisite plans: WP43-WP48, all complete and user-approved. WP48 finished at
CASM `0.1.50` build 1204.

Taskwarrior: `a8c3dbf0-9333-4489-9c3b-3e752049b693`.

Branch: `feature/casm-phase9-wp49`, created from
`feature/casm-phase9-wp48` at its completed WP48 commit.

## Scope

Included:

- Reconcile WP43-WP48 requirements against the final implementation.
- Review the complete parser, load, traversal, replay, diagnostic, and cleanup
  paths, including carry/error propagation at module boundaries.
- Run all Phase 9 standalone harnesses and affected Phase 3-8 regressions.
- Verify all end-to-end include fixture pairs and flattened trusted references.
- Verify malformed input, bounded-resource failures, and cleanup/reuse.
- Prove Pass 2 performs no source-file I/O.
- Verify production and harness envelopes, artifact stability, relocation data,
  the content-driven build counter, and all four disk images.
- Produce the consolidated user walkthrough and synchronize closeout records.

Excluded:

- New directives, syntax, diagnostics, include behavior, refactoring, or
  optimization.
- Unapproved memory-envelope or Phase 9 contract changes.
- Phase 10 progress indication or automatic activation of later work.

## Frozen Acceptance Contract

- `.INCLUDE` accepts one quoted 1-63-byte raw PETSCII filename and rejects
  malformed operands deterministically.
- Explicit devices override inherited parent devices; no search path or
  fallback probing occurs.
- Include traversal supports 16 active frames, rejects depth 17 and active-chain
  cycles, and permits sequential reinclusion.
- Identity follows Command 64 DOS case folding and distinguishes equal names on
  different devices.
- Limits remain 32 physical files, 128 include events, and 65,535 distinct
  source bytes.
- Pass 1 records ordered traversal; Pass 2 performs no source I/O and exactly
  replays the recorded graph.
- Included and equivalent flattened source produce identical static and
  relocatable output.
- Diagnostics name the physical source and render bounded include-site
  traceback without masking the primary failure.
- Every success and failure path releases transient file and VMM resources.

## Baseline Reconciliation

Before substantive verification:

1. Confirm WP43-WP48 are complete in Taskwarrior, `wiki/tasks/casm.md`, and
   `brain/task.md`.
2. Confirm CASM `0.1.50` build 1204 and a stable WP48 no-change rebuild.
3. Re-measure the approved envelopes: production `$4300`, `test_casm_pass1`
   `$4200`, `test_casm_frame` `$4100`, `test_casm_event` `$1D00`, and
   `test_casm_passcheck` `$4000`.
4. Confirm expected harnesses and fixtures are present on their documented
   images.
5. Record the starting revision, version, build number, artifact size,
   relocation count, and image checksums.

Any unexplained discrepancy blocks further verification.

## Full-Path Review

Trace the implementation rather than inferring behavior from names:

1. Parser recognition and quoted-operand validation.
2. Device resolution and folded physical identity.
3. Pass 1 catalog lookup/load and bounded immutable source append.
4. Frame push, nested refill, physical EOF pop, and parent continuation.
5. Depth and active-chain cycle enforcement.
6. Ordered event recording.
7. Filesystem-free Pass 2 lookup and replay correspondence.
8. Physical token/diagnostic provenance and traceback reconstruction.
9. Success and failure cleanup of files, VMM slots, frames, and cursors.

The review explicitly checks carry, zero, register, and error contracts at
cross-module calls and rejects continuation with partially initialized state.

## Verification Matrix

### Grammar and Devices

- Accept 1- and 63-byte names; reject empty, 64-byte, missing-quote,
  unterminated, control-byte, and trailing-token operands.
- Verify inherited child/grandchild devices and explicit overrides.
- Verify same names on different devices remain distinct, alternate-case names
  share identity on one device, and no fallback device is probed.

### Traversal and Limits

- Verify one-level, multi-level, depth-16, and rejected depth-17 traversal.
- Verify direct, indirect, longer-chain, and alternate-case cycles.
- Verify sequential reinclusion and correct parent byte/line/column resumption.
- Cover parent/child CR, LF, CRLF, and missing-final-newline combinations.
- Verify exact limits and one-overflow cases for 32 files, 128 events, 65,535
  source bytes, 16 frames, catalog metadata, event storage, and VMM allocation.

### Replay and Assembly Semantics

- Prove Pass 2 opens zero source files.
- Verify unchanged replay plus parent-kind/id, catalog-id, source-offset,
  missing-event, extra-event, and final-count mismatch failures.
- Compare included and flattened trusted references byte-for-byte for forward
  and backward labels, cross-boundary branches, parent/child expressions,
  reinclusion, nested source, static output, and relocatable R6 output.
- Compare relocation count and offsets, not only assembly success.

### Diagnostics and Cleanup

- Verify physical included filenames, single-root filename suppression, maximum
  traceback depth, innermost-to-root ordering, include-site line/column, and
  current-site reporting after reinclusion.
- Verify unterminated children cannot append parent text and post-pop failures
  retain their original root and depth.
- Verify rendering failure cannot mask the primary diagnostic.
- Exercise missing/open/read/close, VMM, catalog, event, cycle, depth, source
  size, replay, lexer, and parser failures.
- After each representative failure, run a known-good assembly in the same OS
  session to prove no stale handle, channel, frame, cursor, or VMM ownership.

## Harness and Build Verification

Build and run the complete Phase 9 harness set:

- `TEST_CASM_INCLUDE`
- `TEST_CASM_CATALOG`
- `TEST_CASM_FRAME`
- `TEST_CASM_EVENT`
- `TEST_CASM_PASS1`
- `TEST_CASM_PASSCHECK`

Also run existing lexer, parser, source, emission, relocation, overflow, and
diagnostic regressions affected by shared Phase 9 modules.

Use only CMake targets. Build narrow targets and `casm`, record size/envelope/
relocation measurements, then build `casm` again without changes and require
`BUILD_CASM` to remain stable. Build these images independently, not in
parallel, to avoid the WP48 build-directory collision:

- `image_d64`
- `test_image_d64`
- `casm_overflow_test_d64`
- `casm_include_test_d64`

Verify image contents, run `git diff --check`, and investigate every unexpected
artifact or generated-file change.

## VICE and User Walkthrough

All automated emulator work follows
`.agents/workflows/vice-mcp-testing.md`: boot Command64 first, prove its banner,
launch applications only from its shell, use bounded observations and one clean
recovery, require shell return, and classify product/harness/setup/inconclusive
failures from evidence. If the MCP is unavailable, the user performs the same
workflow in supported local VICE; no web emulator is permitted.

The final walkthrough has four sessions:

1. Run all six Phase 9 harnesses and require complete pass text and shell return.
2. Assemble every static and relocatable include fixture and require each
   flattened-reference comparison to report `FILES COMPARE OK`.
3. Repeat WP48 cases `CASM CASMIDP1.S`, `CASM CASMIDUP1.S`, and
   `CASM CASMIDDP1.S`; verify physical names, line 2/column 5 sites, traceback
   order, no parent-text contamination, and shell return. Run
   `CASM CASMERR1.S` and verify ordinary single-root filename suppression.
4. Run representative grammar, missing-file, cycle, depth, event, source-size,
   and replay failures, following each with a successful assembly without an OS
   reboot.

Record image, application, start evidence, assertions, shell-return evidence,
VICE information, checkpoints, recovery, and classification for each runtime
group.

## Atomic Increments

1. Persist this approved plan and activate WP49 in Taskwarrior,
   `wiki/tasks/casm.md`, `brain/task.md`, and `brain/MEMORY.md`.
2. Reconcile the frozen baseline and produce the full-path review evidence.
3. Run static, narrow harness, regression, envelope, and artifact verification.
4. Run trusted-reference, failure-injection, resource-reuse, image, and
   no-change-build verification.
5. Create
   `brain/walkthroughs/2026-07-29-casm-phase9-wp49-verification-walkthrough-and-completion-gate.md`
   and present the bounded runtime walkthrough.
6. After the user performs the walkthrough and explicitly approves completion,
   synchronize Taskwarrior, task/acceptance records, knowledge, memory,
   changelog, walkthrough, and applicable DOX files. Do not activate Phase 10.

## Expected Files

| File | Planned action |
| --- | --- |
| This plan | Approved WP49 verification contract and progress |
| `brain/walkthroughs/2026-07-29-casm-phase9-wp49-verification-walkthrough-and-completion-gate.md` | Consolidated evidence and manual steps |
| `wiki/tasks/casm.md`, `brain/task.md` | Synchronized activation, acceptance, and closeout state |
| `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `CHANGELOG.md` | Durable verified result at closeout |
| Applicable `AGENTS.md` files | Only if the DOX pass identifies a changed durable contract |

No production, harness, fixture, or build-system change is expected. A
verification result alone does not require a CASM version increment.

Approved amendment (2026-07-29): baseline reconciliation may correct the stale
WP48 measurement comment in `CMakeLists.txt` from 196 to 85 bytes of production
headroom. This is documentation-only: it changes no target, envelope, source,
artifact, or runtime behavior. The amendment is complete only if a CMake `casm`
build preserves build 1204 and the existing artifact sizes.

## Stop Conditions

Stop, preserve evidence, perform root-cause analysis, amend this plan, and seek
renewed approval if any acceptance case fails; output or relocation data differ;
Pass 2 performs source I/O; cleanup leaks state; a no-change build increments;
an approved envelope is exceeded; an artifact changes unexpectedly; an expected
harness or fixture is absent; documentation materially disagrees with behavior;
or verification requires any production, harness, fixture, or build edit.

Leave WP49 active and Phase 9 incomplete while remediation is pending. Add
measurable subtasks and repeat affected checks plus regressions after an approved
fix.

## Documentation, Task, and DOX Updates

- Keep Taskwarrior, `wiki/tasks/casm.md`, and `brain/task.md` synchronized at
  activation, verification, and closeout.
- Record stable findings in `brain/KNOWLEDGE.md`, session state in
  `brain/MEMORY.md`, and reproducible evidence in the walkthrough.
- Update `CHANGELOG.md` only at user-approved Phase 9 closeout.
- Re-read every applicable DOX chain before edits and perform the required
  closeout pass. Change an `AGENTS.md` only when verification changes a durable
  contract; otherwise record that it was intentionally unchanged.

## Completion Gate

WP49 and Phase 9 complete only after this approved plan's full static, build,
artifact, trusted-reference, failure, resource, and runtime matrix passes; the
no-change build and all images are stable; the walkthrough contains reproducible
evidence; the user completes the walkthrough and explicitly approves marking
WP49 and Phase 9 complete; and every task, knowledge, memory, changelog,
walkthrough, and applicable DOX record agrees. Completion never activates Phase
10 automatically.

## Progress

- 2026-07-29: User approved the detailed WP49 plan. Activated the verification
  package; no production behavior or version change is authorized.
- 2026-07-29: Created `feature/casm-phase9-wp49` from the completed WP48
  baseline and began the baseline-reconciliation increment.
- 2026-07-29: Baseline reconciliation confirmed CASM `0.1.50`, build 1204,
  the `$4300` production envelope, all six Phase 9 harness targets, all four
  disk images, and a stable no-change `casm` build. Full-path review confirmed
  the production split: Pass 1 alone reaches `includeCatalogLoad`; Pass 2 uses
  load-free `includeCatalogLookup`, validates `includeEventReplay`, and runs
  `includeReplayFinalCheck`; both paths push through `sourceFramePush`, nested
  EOF pops through `sourceRefill`, and fatal/success exits reach central
  cleanup. Reconciliation also found `CMakeLists.txt`'s final WP48 envelope
  comment still claims 196 bytes headroom, while the final WP48 walkthrough and
  `brain/KNOWLEDGE.md` record 85 bytes after later runtime corrections. Stopped
  under this plan's build-file/documentation discrepancy gate pending approval
  of a narrow amendment to correct that comment and verify the measured value.
- 2026-07-29: User approved the narrow amendment. Corrected only the stale
  production-envelope comment; no target, size, or production source changed.
  CMake reconfiguration and link confirmed 14,478 code bytes and 2,104
  relocation points at build 1204; the immediate no-change rebuild was stable.
  Baseline reconciliation and full-path review are complete with no production
  defect found.
- 2026-07-29: Static host verification passed. The six Phase 9 harnesses
  (`test_casm_include`, `test_casm_catalog`, `test_casm_frame`,
  `test_casm_event`, `test_casm_pass1`, and `test_casm_passcheck`) and shared
  expression/VMM/symbol/relocation regressions linked at both relocation bases
  within their approved envelopes. Persistent counters remained content-stable,
  and an immediate no-change rebuild rebuilt no artifacts. Independently built
  `image_d64`, `test_image_d64`, `casm_overflow_test_d64`, and
  `casm_include_test_d64`; all are complete 174,848-byte images with their
  documented programs and fixtures. No unexpected tracked worktree drift.
- 2026-07-29: MCP runtime verification proved `TEST_CASM_PASS1`,
  `TEST_CASM_PASSCHECK`, and `TEST_CASM_INCLUDE` pass with shell return. The
  catalog session was classified inconclusive due to MCP/media synchronization,
  after which the MCP-owned process was terminated at the user's request. The
  user completed the remaining supported runtime work and reported that all
  tests pass. Consolidated walkthrough created; awaiting explicit approval to
  mark WP49 and Phase 9 complete.
- 2026-07-29: User explicitly approved completion. WP49 and CASM Phase 9 are
  complete at CASM `0.1.50` build 1204. The approved verification-only package
  required no version increment and Phase 10 remains inactive.
