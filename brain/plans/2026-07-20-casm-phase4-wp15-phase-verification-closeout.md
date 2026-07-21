---
feature: casm-phase4-wp15-phase-verification-closeout
created: 2026-07-20
status: planned
---

# Plan: CASM Phase 4 WP15 Verification and Phase Closeout

## Objective

WP15 independently verifies the complete Phase 4 numeric static assembler,
captures final reproducible evidence, synchronizes every milestone record, and
asks the user whether Phase 4 is done. It is a verification and release gate;
it must not hide implementation fixes inside closeout work.

This plan governs Taskwarrior UUID `8612c2a2-afdd-4c8f-bf42-4947bc486f97`.
The task remains pending until WP14 is complete and this plan is explicitly
approved for implementation.

## Naming and Dependency Resolution

- “Phase 4 WP15” means only this verification/closeout task.
- The merged diagnostic source-context work is named **DSC1**. Historical
  source comments saying `WP15` identify DSC1 and are not evidence that this
  Phase 4 task is complete.
- WP15 depends on user-approved WP14 at CASM `0.1.16`, including trusted
  `casmemit1.ref` and `casmhello.ref` comparisons.
- Any WP15 verification failure returns to RCA and a separately approved
  remediation plan. WP15 may not patch production code opportunistically.
- Phase 5 remains planned and blocked until the user approves the Phase 4
  walkthrough and explicitly authorizes marking Phase 4 done.

## Activation Decisions (2026-07-21)

WP15 was activated on 2026-07-21 after WP14 completed and merged as `55fe474`.
Four scope decisions were taken at activation and are binding for this package.

### D1 — the version bump stands, and moves earlier

Verifying a work package as complete indicates a phase change, so WP15 advances
CASM `0.1.16` to `0.1.17` per the CASM work-package version contract. WP15 ships
a version constant; `BUILD_CASM` therefore moves past 1078 and the pre-WP15
artifact is *not* expected to be byte-identical.

The bump is **relocated from increment 9 to before the manual walkthrough**.
This plan already requires that final checks be rerun against the candidate
closeout build; leaving the bump at the end would force two runtime sessions to
satisfy that rule. Bumping first means the matrix is executed exactly once,
against the artifact that actually ships. The version gate and the Phase 4
completion gate remain separate — approving the runtime matrix still does not
authorize marking Phase 4 done.

Consequence for Phase 5: the WP16 plan
(`brain/plans/2026-07-21-casm-phase5-wp16-prerequisite-reconciliation.md`)
asserts a `0.1.16` / build-1078 baseline in its verification and stop-condition
sections. That baseline is superseded by D1 and must be amended to `0.1.17` and
the post-WP15 build number once WP15 closes.

### D2 — branch and baseline

WP15 runs on `feature/casm-phase4-wp15`, branched from `main` at `55fe474`. The
two untracked Phase 5 planning documents that were present at activation were
committed separately on `feature/casm-phase5-wp16` (`540a274`) so that WP15
begins from a genuinely clean, attributable tree, as increment 3 requires.

### D3 — reduced manual smoke set, with WP14 as standing evidence

WP14 already executed the full 23-fixture acceptance matrix at build 1078 with
user runtime confirmation. Re-executing it verbatim would re-verify rather than
verify. The WP15 manual walkthrough is therefore reduced to the checks that can
change when the version constant changes, plus the evidence WP14 left open:

- CASM banner at `V0.1.17.<build>` and clean missing-source exit;
- `casmemit1` and `casmhello` assembly with native `COMP` equality;
- load/run `casmhello`, verify message and shell return;
- `/O`, `/S`, `/M`, `/L` behavior;
- shell integrity: `DIR`, another external application, and CASM twice after a
  failure; and
- the D4 gap captures below.

WP14's matrix results are linked as standing evidence for the syntax,
addressing, numeric, branch, PC, and directive gates. This is a deliberate
narrowing of the "Manual Walkthrough" section below, not an oversight; that
section is superseded to the extent the two disagree.

### D4 — WP14's open evidence gaps are captured here

`brain/task.md` records two WP14 items whose observed values were never written
down. Both are folded into the WP15 manual walkthrough and must be recorded with
actual observations, so Phase 4 closes with no unrecorded evidence:

- **G4.2** — the `casmzpi2` diagnostic identifier and source position.
- **G7.1-G7.3** — assembling over an existing output file.

If either reveals a defect, the WP15 stop conditions apply: RCA and a separately
approved remediation plan, not an opportunistic patch.

## Scope

Included:

- clean-tree reproduction of the WP11-WP14 acceptance evidence;
- independent build, link-map, artifact, reference, and disk audits;
- final runtime regression and byte-comparison walkthrough;
- reconciliation of parent-plan package count and fixture names;
- correction of wiki UUIDs to real Taskwarrior UUIDs;
- creation/reconciliation of a Phase 4 parent milestone record if needed;
- synchronization of `wiki/tasks/casm.md`, Taskwarrior, and `brain/task.md`;
- final knowledge, memory, changelog, walkthrough, and DOX closeout; and
- explicit user decision on Phase 4 completion.

Excluded:

- new parser, opcode, directive, output, or diagnostic behavior;
- Phase 5 expression implementation;
- later opcode-exhaustion hardening; and
- marking Phase 4 done before user approval.

## Phase 4 Acceptance Matrix

### Parser and delimiter gate

- Valid statement termination at newline and EOF.
- Empty/comment lines do not emit bytes.
- Immediate, indexed, indirect, and accumulator grammar is deterministic.
- `.BYTE`/`.WORD` list delimiters reject empty, leading, doubled, and trailing
  commas.
- Trailing tokens produce the approved diagnostic and source position.
- Numeric literal overflow and malformed forms retain their original primary
  diagnostic.

### Opcode and sizing gate

- Each `CASM_MODE_*` has a representative legal encoding.
- Representative illegal mnemonic/mode pairs are rejected.
- `$FF`/`$100` boundaries select or reject 8-bit modes correctly.
- `$00FF`/`$0100` zero-page-to-absolute promotion is correct.
- Instruction lengths and emitted little-endian operands match references.

### Branch and PC gate

- Relative displacement uses the address following the branch.
- `-128` and `+127` pass; `-129` and `+128` fail.
- `.ORG` is required, accepts one initial value, and rejects duplicates.
- PC advance through `$FFFF` is distinguished from overflow past `$FFFF`.

### Output and resource gate

- Generated PRGs contain exactly one two-byte load address followed by emitted
  bytes; CASM adds no R6 trailer to its output.
- `casmemit1` and `casmhello` match trusted reference PRGs byte-for-byte.
- Default and `/S` output behavior agree; `/O` chooses the requested name.
- `/M`, `/L`, unsupported directives, and all compile failures leave no partial
  output.
- Success and failure close every owned handle and return to an intact shell.
- A no-change build does not increment `BUILD_CASM`.

### Envelope and release gate

- Both `$3400` and `$3500` CASM link configurations fit the `$2800` MAIN
  envelope.
- Final code/data/BSS sizes, headroom, relocation count, PRG load address, base,
  relocation table, count, and `R6` footer are recorded.
- `image_d64` contains CASM and all shipping applications.
- `test_image_d64` contains all source fixtures and trusted references.

## Required Evidence Package

WP15 creates one walkthrough containing:

- exact commit and working-tree state;
- CASM semantic version and build number;
- commands and results for configure/build/no-change/image targets;
- both link-map measurements and remaining headroom;
- artifact header/footer/size/relocation evidence;
- release and test disk directory listings;
- reference manifest lengths/hashes;
- native `COMP` results for both successful fixtures;
- negative-case diagnostic/location/output-cleanup table;
- runnable `casmhello` result;
- shell-integrity checks; and
- the user's explicit completion decision.

Evidence from WP11-WP14 walkthroughs may be linked, but final WP15 checks must
be rerun against the candidate Phase 4 closeout build.

## Record Reconciliation

Before activation:

- replace placeholder wiki UUIDs with the real Taskwarrior UUID prefixes:
  - WP11 `82a11475`;
  - WP12 `a3f90f05`;
  - WP13 `ded1cfd9`;
  - WP14 `3e4eab43`;
  - WP15 `8612c2a2`;
- change the parent plan from four packages to five;
- replace stale `casmnum1/casmnum2` references with
  `casmemit1/casmhello` and their `.ref` files;
- replace stale Phase 3 current-milestone text in `brain/task.md` and
  `wiki/tasks/casm.md`;
- ensure DSC1 is not represented as Phase 4 WP15; and
- create or identify a proper Phase 4 parent Taskwarrior milestone without
  reusing the completed Phase 3 UUID `099257cc`.

Task records are never deleted or moved. Historical annotations remain.

## Expected Files to Change

| File | Action | Responsibility |
|---|---|---|
| `brain/plans/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md` | Create | Detailed WP15 contract |
| `brain/plans/2026-07-17-casm-phase4-statement-parser-opcode-table.md` | Modify | Correct five-package split and fixture names |
| `brain/plans/2026-07-20-casm-diagnostic-source-context.md` | Modify | DSC1 naming/status reconciliation |
| `wiki/tasks/casm.md` | Modify | UUIDs, milestone, acceptance evidence |
| `brain/task.md` | Modify | Current phase and subtasks |
| `brain/KNOWLEDGE.md` | Modify | Final architecture/verification decisions |
| `brain/MEMORY.md` | Modify | Final CASM state and next gate |
| `CHANGELOG.md` | Modify | Phase 4 closeout/version record |
| `brain/walkthroughs/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md` | Create | Final evidence and manual instructions |
| Applicable `AGENTS.md` files | Review; modify only if contract changed | DOX closeout |

No production source change is expected. Discovery of a required source change
is a stop condition and remediation dependency, not WP15 scope.

## Atomic Verification Increments

1. Confirm WP14 is complete and its final repository/task records agree.
2. Reconcile the five-package parent plan, DSC1 naming, actual UUIDs, fixture
   names, and current-milestone records without changing completion boxes.
3. Capture clean baseline: commit, status, version/build, tool configuration,
   source manifest, and applicable DOX chain.
4. Reconfigure only if required; build `casm`; inspect both link maps and the
   R6 artifact; perform a no-change rebuild.
5. Build `image_d64` and `test_image_d64`; inspect both directories and verify
   reference hashes/contents.
6. Run the complete static acceptance audit, including carry, zero-page,
   stack, output lifecycle, and diagnostic-preservation paths.
7. **(D1, moved up)** Advance CASM `0.1.16` to `0.1.17`; rebuild, reinspect both
   link maps and the R6 artifact, and confirm `BUILD_CASM` advanced exactly once
   and then held stable across a no-change rebuild.
8. Write the in-progress WP15 walkthrough with exact pending manual steps,
   against the `0.1.17` candidate.
9. Ask the user to execute the D3 reduced smoke set plus the D4 gap captures,
   and report exact results.
10. Present the completed walkthrough and ask separately whether Phase 4 is
    done. Only after affirmative approval mark WP15 and Phase 4 complete and
    synchronize every record.

The version bump and Phase completion remain separate gates. Approval of the
runtime matrix does not implicitly authorize either one. Increments 7-9 are
reordered from the original 8-9 sequence per D1; the gate separation is
unchanged.

## Automated Verification

- `cmake -S . -B build` when configuration inputs changed.
- `cmake --build build --target casm`.
- immediate no-change rebuild with stable `BUILD_CASM`.
- `cmake --build build --target image_d64`.
- `cmake --build build --target test_image_d64`.
- inspect the generated PRG and both link maps using existing repository
  tooling; do not trust exit codes alone.
- verify reference manifests and generated `.ref` files byte-for-byte.
- inspect disk contents and fixture retention.
- `git diff --check` plus DOX-chain closeout.

Do not use the broken `c64-testing` MCP or a web emulator.

## Manual Walkthrough

The user verifies on the supported local emulator or hardware:

1. CASM banner and clean missing-source exit.
2. `casmemit1` assembly and native `COMP` equality.
3. `casmhello` assembly and native `COMP` equality.
4. Load/run `casmhello`; verify message and shell return.
5. Complete syntax, addressing, numeric, branch, PC, and directive matrix.
6. Confirm each diagnostic identifier and source position.
7. Confirm failed cases leave no partial output.
8. Confirm `/O`, `/S`, `/M`, and `/L` behavior.
9. Run `DIR`, another external application, and CASM twice after failures.
10. After the gated version bump, confirm `CASM V0.1.17.<build>` and repeat the
    shell-integrity check.

## Failure Handling and RCA

- Any failed gate leaves WP15 and Phase 4 open.
- Record actual versus expected bytes, first differing offset, fixture, build,
  and environment for a comparison failure.
- Trace the responsible parser/matcher/emitter/output path before proposing a
  fix.
- Create a dedicated remediation plan and obtain approval before source edits.
- After remediation, rerun the entire WP15 candidate verification rather than
  only the failing case.

## Stop Conditions

- WP14 is incomplete or its evidence cannot be reproduced.
- Working-tree changes cannot be attributed and safely preserved.
- Wiki, Taskwarrior, brain, version, or fixture identity remains ambiguous.
- A source or build-system behavior change is required.
- Reference provenance is not independent of CASM.
- Any artifact, resource, output-cleanup, binary, or runtime check fails.
- The user has not explicitly approved the required gate.

## Completion Gate

WP15 is complete only after the final `0.1.17` candidate passes every automated
and manual check, its walkthrough is approved, and the user explicitly allows
WP15 to be marked complete. Phase 4 is complete only after a separate explicit
user confirmation that the phase is done. Neither status is changed merely by
saving this plan.

## Progress

- 2026-07-20: Detailed plan saved. WP15 remains pending behind WP14.
- 2026-07-21: **Activated.** WP14 completed and merged as `55fe474`; the sole
  blocking dependency is cleared. Four activation decisions recorded above (D1
  version bump retained and moved earlier, D2 branch/baseline, D3 reduced manual
  smoke set, D4 WP14 gap capture). Working on `feature/casm-phase4-wp15` from a
  clean tree at `55fe474`.

  Pre-activation audit found that most of the "Record Reconciliation" list is
  already satisfied: WP14 replaced the placeholder wiki UUIDs with the real ones,
  retired `casmnum1`/`casmnum2` in favour of `casmemit1`/`casmhello`, corrected
  the parent plan to a five-package split, and settled the DSC1 naming. Increment
  2 is therefore a verification pass, not repair work. `brain/MEMORY.md` was
  confirmed to exist, so the expected-files table stands unchanged.
