---
feature: casm-phase5-wp21-verification-closeout
created: 2026-07-21
status: complete
---

# Plan: CASM Phase 5 WP21 - Verification and Closeout

## Objective

WP21 independently verifies the complete Phase 5 expression evaluator, closes
the remaining acceptance gaps, builds release and test artifacts, records one
consolidated runtime walkthrough, and closes both WP21 and the Phase 5 parent
milestone only after explicit user approval.

Taskwarrior WP21: `225a69ce-b46c-404d-a86b-d2c4494e9c3f`.
Phase 5 parent: `6b72d639-53d0-4d1a-92ba-8c4d56096388`.

Prerequisite: WP20 completed at commit `8afb438`, CASM `0.1.22` build 1093.
WP21 is pending, unblocked, and has no start timestamp. Approval of this plan is
required before task activation or test/documentation edits.

## Dependency Review

- WP16 froze the Phase 0C.3 grammar, result, resolver, relocation-class, and task
  contracts and verified Phase 4 completion.
- WP17 established the nine-byte result ABI and diagnostics `$24-$27`.
- WP18 implemented parser-independent numeric conversion, sign/magnitude
  addends, checked arithmetic, and radix-boundary fixtures.
- WP19 implemented resolver callback dispatch, symbolic state, unresolved
  force-absolute behavior, and extraction; MAIN expanded to approved `$2A00`.
- WP20 integrated production numeric-expression positions, prevented unresolved
  emission, added a standalone deterministic resolver harness, and received user
  runtime confirmation.
- All five prerequisite work-package Taskwarrior records are complete. WP21 is
  the only incomplete child blocking the Phase 5 parent.

## Discrepancies to Reconcile

1. The parent verification matrix explicitly requires `+0` and `-$0000` addends.
   The WP20 test plan mentions `ABSVAL+0`, but the implemented 27-case harness
   tests `+1` and `-$34` instead. Add exact positive-zero and negative-zero cases.
2. The parent requires repeated-operator/extraction rejection. Chained addends
   are covered, but repeated extraction is not. Add `<<$1234`, expecting `$24`
   at the second LESS token.
3. The Phase 5 wiki acceptance list still has four unchecked items: bounded
   ABI/storage, Phase 4 numeric compatibility, full expression matrix, and
   trusted reference stability. WP21 owns evidence and final reconciliation.
4. WP20 runtime confirmed the new `casmexprn` reference and resolver cleanup.
   WP21 must rerun all five trusted comparisons (`casmemit1`, `casmhello`,
   `casmmodes`, `casmnum2`, `casmexprn`) as the consolidated phase gate.
5. WP20 built `test_image_d64`; the parent closeout also requires the release
   `image_d64` and artifact inspection.
6. CASM has only 243 bytes of `$2A00` MAIN headroom. WP21 adds no production CODE
   or BSS, so any production-size change is unexpected and stops closeout.
7. The final work-package version rule requires `0.1.22` -> `0.1.23` only after
   verification and explicit completion approval. Closing WP21 and the Phase 5
   parent before that approval is forbidden.

## Inherited Acceptance Contract

- Grammar and all ABI constants remain unchanged.
- Numeric literals cover minima, maxima, and overflow in decimal/hex/binary.
- Resolved absolute/relocatable and unresolved absolute/relocatable symbols are
  verified with full, low, and high extraction.
- Addends cover positive/negative zero, one, `$FFFF`, checked overflow, and
  checked underflow.
- Malformed primary/addend, repeated extraction, chained arithmetic,
  symbol-to-symbol arithmetic, numeric arithmetic, adjacent tokens, resolver
  failure, and invalid resolver flags return stable diagnostics and locations.
- Resolver calls are zero for NUMBER and exactly one for IDENTIFIER.
- Unresolved placeholders never reach production opcode or emission paths.
- Existing Phase 4 numeric output remains byte-identical.
- No broken `c64-testing` MCP or web emulator is used; runtime checks are
  performed by the user in local VICE or hardware.

## Scope

Included:

- add three test-only cases to `test_casm_expr`: `ABSVAL+0`, `ABSVAL-$0000`, and
  repeated extraction `<<$1234`;
- update case count, expected records, and WP20/WP21 test documentation;
- independently audit evaluator/parser/emitter carry, token, unresolved, and
  diagnostic paths against the frozen contracts;
- configure and build CASM, `test_casm_expr`, `test_image_d64`, and `image_d64`;
- inspect object segments, imports/exports, both link bases, PRG/R6 headers,
  relocation counts, disk inventories, build counters, and MAIN headroom;
- run no-change rebuilds for CASM and the test harness;
- ask the user to run the consolidated harness/reference/error matrix;
- reconcile wiki, brain, knowledge, memory, changelog, walkthrough, Taskwarrior,
  and parent-plan progress;
- perform a `0.1.23` dry run, restore it for approval, then apply it finally only
  after explicit WP21/Phase 5 completion approval; and
- close WP21 followed by the Phase 5 parent milestone.

Excluded:

- any CASM production evaluator, parser, emitter, opcode, diagnostic, source,
  storage, resolver, zero-page, grammar, or MAIN-envelope change;
- production symbols, labels, passes, VMM, relocation records, or R6 writing;
- new production fixtures or syntax;
- optimizing or refactoring already approved code during closeout;
- starting Phase 6A or any later phase.

## Test-Only Additions

The harness case count changes from 27 to 30.

| Case | Tokens | Expected result |
|---|---|---|
| `ABSZERO` | `ABSVAL + 0 EOF` | `$1234`, flags `$03`, ID 1, positive magnitude `$0000`, one resolver call |
| `ABSNEGZERO` | `ABSVAL - $0000 EOF` | `$1234`, flags `$03`, ID 1, negative magnitude `$0000`, one resolver call |
| `REPEATEXTRACT` | `< < $1234` | C set, `$24`, second LESS current, one diagnostic stamp, zero resolver calls |

Negative zero deliberately retains `CASM_ADDEND_SIGN_NEGATIVE`; arithmetic is a
no-op because magnitude is zero. This verifies sign metadata rather than only
the final value.

No production SEQ or trusted output is needed for these evaluator-only cases.

## Independent Static Audit

WP21 traces and records:

- all `exprEvaluate` entry, success, and diagnostic exits;
- synthetic callback return-address push order and NMOS indirect-jump assertion;
- numeric/addend ADC/SBC carry setup and D-clear preconditions;
- resolver returned-bit validation and unresolved value non-consumption;
- extraction ordering after checked arithmetic;
- parser expression-start dispatch and delimiter ownership for immediate,
  absolute/indexed, indirect, `.ORG`, `.BYTE`, and `.WORD`;
- expression-start location preservation for `.BYTE` range errors;
- absence of `parseNumericValue` and fixture identifiers in production CASM;
- production resolver failure before any unresolved opcode selection/emission;
- fatal-path preservation and partial-output deletion; and
- public routine comments, stack balance, scratch/BSS ownership, and exports.

Any behavioral defect stops closeout and requires a separately approved repair
amendment; WP21 does not silently fix production code.

## Artifact Verification

### Narrow Targets

- `cmake -S . -B build`;
- `cmake --build build --target casm` twice;
- `cmake --build build --target test_casm_expr` twice;
- explicit `$3400`/`$3500` outputs must exist and differ only by relocation;
- CASM must remain 9,366 CODE+RODATA, 1,143 BSS, 10,509 MAIN bytes, 243 bytes
  headroom, and 1,271 R6 relocation points before the version-only increment;
- test harness growth is measured and remains within its `$1000` envelope.

### Disk Targets

- build `test_image_d64` and verify CASM, `test_casm_expr`, five references,
  `casmexprn`, `casmexpru`, and all prior fixtures are present;
- build `image_d64` and verify shipping CASM is present while test-only harness,
  references, and SEQ fixtures are absent;
- inspect CASM/test PRG load headers and R6 trailers rather than relying only on
  successful command exit.

### Trusted References

The user assembles and compares:

| Source | Reference | Purpose |
|---|---|---|
| `casmemit1` | `casmemit1.ref` | core Phase 4 emission |
| `casmhello` | `casmhello.ref` | runnable program/full output |
| `casmmodes` | `casmmodes.ref` | all addressing modes |
| `casmnum2` | `casmnum2.ref` | WP18 radix/numeric boundaries |
| `casmexprn` | `casmexprn.ref` | WP20 extraction/parser delimiters |

All comparisons must report equality. `casmexpru` must report resolver failure
at `ABSVAL` and leave no partial output.

## Expected Files

| File | Action |
|---|---|
| `tests/src/casm_expr/casm_expr.s` | add three missing cases/expectations |
| `tests/src/casm_expr/BUILD_TEST_CASM_EXPR` | build-managed increment |
| `src/external/casm/casm.s` | final stage increment only after approval |
| `src/external/casm/BUILD_CASM` | build-managed final increment |
| `brain/plans/2026-07-21-casm-phase5-wp21-verification-closeout.md` | activation/evidence |
| `brain/plans/2026-07-20-casm-phase5-minimal-expression-evaluator.md` | final parent progress/status |
| `brain/plans/2026-07-21-casm-phase5-wp20-test-plan.md` | record added coverage |
| `brain/walkthroughs/2026-07-21-casm-phase5-wp21-verification-closeout.md` | consolidated gate |
| `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `brain/task.md` | final evidence/status |
| `wiki/tasks/casm.md`, `CHANGELOG.md`, Taskwarrior | acceptance and milestone closure |

No CMake, production module other than the version string/build file, generated
fixture, trusted manifest, or `AGENTS.md` change is expected. Discovery of such
a need stops WP21 for an amended plan.

## Atomic Increments

1. After approval, start WP21 and annotate the Phase 5 parent; record clean
   `0.1.22.1093` hashes, object sizes, task states, and acceptance gaps.
2. Add the three harness cases and update the WP20 test plan; build/run the narrow
   harness and verify 30 passes.
3. Perform and document the independent source/ABI/carry/token/cleanup audit.
4. Configure; build CASM and harness twice; inspect objects, links, headers,
   trailers, sizes, relocation counts, headroom, and build-counter stability.
5. Build and inspect both test and release disk images.
6. Ask the user to run the 30-case harness, five trusted comparisons, and
   unresolved cleanup check. Record exact results.
7. Reconcile every Phase 5 acceptance checkbox and create the consolidated
   walkthrough without closing tasks.
8. Dry-run stage `22` -> `23`; verify exactly one CASM build increment, unchanged
   segments/relocations apart from version bytes, no-change stability, and both
   disk targets. Restore `0.1.22.1093` before requesting completion approval.
9. Request explicit approval that WP21 and Phase 5 are complete.
10. After approval, apply the verified `0.1.23` increment, rebuild twice, build
    both images, mark acceptance complete, complete WP21, then complete the Phase
    5 parent Taskwarrior milestone. Do not activate Phase 6A.

## Stop Conditions

- Any WP16-WP20 task, commit, version, runtime result, or dependency disagrees.
- A missing acceptance case requires production behavior changes rather than
  test-only coverage.
- CASM production CODE/BSS, ABI, exports, or MAIN usage changes before the
  version-only increment.
- Any trusted reference differs, prior diagnostic regresses, unresolved output
  is emitted, partial output survives, or harness case fails.
- CASM exceeds `$2A00`, test harness exceeds `$1000`, or relocation structure is
  unexplained.
- Release image contains test-only artifacts or test image omits required ones.
- Task/wiki/brain/Taskwarrior records cannot be reconciled without changing
  approved history.

Any stop condition triggers root-cause analysis and a plan amendment requiring
renewed approval. WP21 cannot convert a verification failure into an unplanned
production fix.

## Documentation, DOX, and Completion Gate

Re-read root, `src`/`external`/`casm`, `tests`, and `wiki/tasks` DOX chains after
edits. Update `AGENTS.md` only if a durable contract or child index changes.

WP21 and Phase 5 are complete only when:

- all 30 harness cases and five trusted comparisons pass;
- unresolved failure/cleanup, both images, artifact structure, and no-change
  rebuilds pass;
- all Phase 5 acceptance items are checked with evidence;
- the consolidated walkthrough is reviewed;
- the user explicitly approves WP21 and Phase 5 completion;
- final CASM `0.1.23` is built and stable; and
- WP21 and then the parent milestone are completed in Taskwarrior and matching
  repository records.

## Progress

- 2026-07-21: Drafted on clean `feature/casm-phase5-wp21` from WP20 commit
  `8afb438`. Reconciled all WP16-WP20 dependencies, parent acceptance items,
  runtime/reference coverage, release-image requirement, task hierarchy, 243-byte
  MAIN headroom, and three missing harness cases. WP21 remains pending without a
  start timestamp, awaiting implementation approval.
- 2026-07-21: User approved implementation. Activated WP21 and annotated the
  parent milestone; Phase 5 remains pending through the final approval gate.
- 2026-07-21: Added all three missing cases and distinct scripted-token columns.
  Test build 1005 has 30 cases, 2,310 CODE+RODATA, 72 BSS, and 296 relocations.
  Independent audit found no carry, stack, token, or unresolved-emission defect.
  Production CASM measurements remain unchanged; both images pass. Awaiting the
  consolidated user runtime matrix.
- 2026-07-21: User confirmed all 30 harness cases, all five trusted references,
  resolver diagnostic location, and partial-output cleanup. Runtime gate passed;
  final version dry run and completion approval remain.
- 2026-07-21: Dry-run `0.1.23` produced exactly build 1094 with source fingerprint
  `d9bf4165d7a1ea012a08da2d091fa5f3296b29cec2eb5aa6c00ef06384539a41`
  and PRG SHA-256
  `18d2f6cce7ffbcc7de8aa71db3da9e3b6d9ee3bb1cd07e69b072dd0d0884e703`.
  CASM no-change stability and both disk targets passed. Restored the completion
  candidate to `0.1.22` build 1093 before requesting approval.
- 2026-07-21: User explicitly approved WP21 and Phase 5 completion. Applied the
  verified `0.1.23` increment, retained build 1094 on the no-change rebuild, and
  rebuilt both disk images successfully. Closed WP21 before the Phase 5 parent;
  Phase 6A remains inactive.
