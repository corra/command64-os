---
feature: casm-byte-oracle-wp1-contract-workflow-schema
created: 2026-09-02
status: complete
taskwarrior: 154368e9-1fa8-4b48-b7bd-c02f2029f00f (WP1, done); parent 75cfa082-af8a-4783-8cd3-eb743f3040b7
depends-on: CASM Phase 15 closure (complete, user-approved 2026-09-02, merged to main dfe5596 baseline)
---

# Plan: Byte-Oracle Transition WP1 — Contract, Workflow, Skill, and Audit Schema

## Status

**Complete; user-approved 2026-09-02.** All 8 increments done, walkthrough
`brain/walkthroughs/2026-09-02-casm-byte-oracle-wp1-contract-workflow-schema.md`
written, no-change rebuild verified identical, contract signed off.
Taskwarrior `154368e9` done. WP2 is blocked until
`casm-diagnostic-always-name-file` merges to `main`.

Parent plan: `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`
(governing plan, `amended-approved-deferred`; user resumed the transition
2026-09-02 and directed a WP1 sub-plan draft).

Prerequisite: CASM Phase 15 fully closed and merged (user-approved 2026-09-02,
CASM 0.6.1 build 1417). Baseline is clean-committed at `dfe5596`
("casm: land oracle-transition + diagnostic-file plans and native-viability
review"). Two unrelated untracked files remain in the tree
(`docs/codebase-knowledge-graph.md` 2-line stub, `test_g2.png` stray
screenshot); neither is in an oracle-relevant path and both are out of scope
for this WP.

## Objective

WP1 delivers **definitions and governance only** — no fixture, manifest,
build, or source behavior changes:

1. A frozen vocabulary: evidence classes, oracle classes, provenance states,
   the peer-review contract, and mismatch/stop handling — lifted verbatim
   from the governing plan's Verification Model and hardened into a single
   normative document.
2. `.agents/workflows/canonical-byte-oracles.md` — the tool-neutral durable
   authority.
3. `.claude/skills/canonical-byte-oracles/SKILL.md` — a Claude adapter with
   trigger + checklist, no unique policy, pointing back to the workflow.
4. The checked-in **audit-register schema** (column set + one worked row
   format) that WP2 will populate — schema only, not the register itself.
5. Reconciliation edits to the existing workflows and DOX files that today
   assert or imply "ca65 is the authority", replacing that with local
   oracle duties at the closest owning scope.
6. A decision, recorded in the workflow, on whether native-app manifests
   stay machine-integrity records linked to separate review docs
   (preferred by the governing plan) or embed review metadata directly.
7. The WP1 gate: five sample fixtures (one traditional static, one Phase 15
   conditional whose output depends on suppression, one R6, one
   diagnostic-only, one native-app manifest) classified manually against
   the schema as a proof the schema is workable.

**Explicitly NOT in WP1:**

- No inventory of the full fixture set (WP2).
- No re-derivation, replacement, or quarantine of any reference (WP3).
- No change to `dash_ref`, `CASM_REF_NAMES`, `command64_casm_utils_d64`,
  packaging, or any `CMakeLists.txt` / `cmake/*.cmake` target behavior.
- No change to any `*.ref.hex`, `*.seq`, generated fixture, or manifest
  bytes/metadata.
- No new script and no change to `hex_manifest_to_bin.py`,
  `build_dash_manifest.py`, `build_banner_manifest.py`, or
  `check_casm_source_bytes.py`. WP1 only *decides* (per governing plan
  WP1 text) whether a new validator is needed later; it does not build one.
- No live VICE run (nothing executable changes; the gate is a paper
  classification exercise).

## What this transition is NOT (ca65 scope clarification)

The transition does **not** remove ca65/ld65 from the build for all external
applications. ca65/ld65 remains the host build toolchain:

- `casm` itself is built with ca65/ld65 (it cannot assemble itself) —
  unchanged, and `src/external/casm/AGENTS.md`'s CASM build contract is
  explicitly out of scope.
- `debug` and every other non-CASM-native app keep ca65/ld65 — out of
  scope; not migration targets.
- The repository will still require ca65 to configure and build after the
  whole transition closes.

What actually changes:

- **Authority of bytes.** Independently hand-derived + peer-reviewed
  canonical bytes become the authoritative oracle for CASM's assembled
  fixture output and for CASM-*native* apps (today: DASH and BANNER).
  ca65 output is demoted to optional differential evidence.
- **DASH only.** Its load-bearing "Dual-Assembler Subset" source
  restriction is lifted (WP5, after WP4 evidence), and `dash_ref` becomes
  opt-in / non-gating — removed from `ALL`, configure-time requirement,
  `command64_casm_utils_d64` dependency, and automatic `dash.ref`
  packaging. The `dash_ref` ca65 target still *exists* as an opt-in check
  while DASH source stays compatible.
- **BANNER** already has no ca65 path; it only gains an explicit
  independent derivation/reviewer record.

CASM's own language/diagnostic behavior is not a subject of this transition
— only its fixtures and their oracles are. That is why
`casm-diagnostic-always-name-file` (a diagnostic-text behavior change) is a
*sequencing* concern with WP2/WP3's fixture freeze, not a scope overlap.

## Scoping Decisions (user-confirmed 2026-09-02)

1. **Transition resumed now.** Phase 15 is closed; the user directed the WP1
   sub-plan draft. Parent Taskwarrior record + WP1 child are created only on
   approval of *this* plan.
2. **Clean committed baseline first** — done at `dfe5596` (doc-only
   housekeeping commit).
3. **`casm-diagnostic-always-name-file` does not conflict with WP1** — WP1
   edits no CASM source and no fixture. Its real collision is with **WP2**
   (which freezes the fixture universe for inventory) and **WP3** (which
   remediates diagnostic-rejection fixtures): the diagnostic plan rewrites
   many expected-diagnostic comments in
   `cmake/GenerateCasmTestFixtures.cmake` and may add a regression fixture.
   Recommended sequencing: **land the diagnostic plan to completion before
   WP2's inventory freeze**, so WP2 inventories a post-change frozen state.
   It must not be *in flight* once WP2 starts. **User decision 2026-09-02:
   run it now (concurrent with docs-only WP1) and merge it to `main` before
   WP2 begins its inventory freeze.** WP2's read-only inventory is taken
   from the commit that includes the diagnostic change. If the diagnostic
   plan is not merged by the time WP1 closes, WP2 planning waits on it.

## Contract content to freeze (the normative document)

The workflow doc is authored from the governing plan's existing text — it is
a consolidation, not new invention. Sections, in order:

- **Authority hierarchy** (5 levels): normative spec > canonical oracle >
  native observation > optional differential > determinism evidence.
  Verbatim from governing plan "Authority hierarchy".
- **Oracle classes** table: Static PRG, R6 PRG, Repetitive/large,
  Diagnostic rejection, Listing/map, Determinism-only, Native application
  manifest — each with its required evidence. Verbatim from governing plan
  "Oracle classes".
- **Provenance states** (exactly one per reference): `CANONICAL-INDEPENDENT`,
  `DIFFERENTIAL-ONLY`, `NATIVE-OBSERVATION`, `UNCLEAR`, `NOT-APPLICABLE`.
  Only `CANONICAL-INDEPENDENT` may be packaged as an authoritative `.ref`
  for native `COMP`; `UNCLEAR` blocks completion.
- **Prohibited circular derivation sources**: CASM output, `opcodes.s` /
  any CASM production table, a prior CASM run, a shipping manifest copied
  from CASM output, a ca65 binary used *as the answer* rather than as
  post-derivation comparison.
- **Acceptable independent sources**: documented NMOS 6502/6510 encoding,
  CASM documented language semantics, PRG framing, Command 64 R6 format,
  hand arithmetic, generic deterministic expansion tooling for repetition.
- **Mandatory metadata + peer-review evidence**: annotated byte derivation,
  source identity + SHA-256, independent reviewer sign-off, observed native
  `COMP` result. Cross-reference the
  `project-casm-trusted-reference-rule` precedent (`.ref` bytes
  hand-derived from the 6502 spec, never from `opcodes.s`).
- **Generated repetition without writing an assembler**: reviewed seed
  bytes + count/range formula, expanded by generic tooling, boundary
  spot-checks.
- **Mismatch classification + stop conditions**: native ≠ canonical →
  stop, report first differing offset + structural context, classify
  before editing either side; ca65 ≠ CASM on shared syntax → classify as
  CASM defect / ca65 behavior / source-semantic divergence / oracle
  defect, never auto-rewrite CASM.
- **Source-hash staleness protection**: a manifest source hash changing
  without an intentional reviewed regeneration is a stop condition.
- **Live verification**: defer to `.agents/workflows/vice-mcp-testing.md`
  for the Command64 boot/input/`COMP` procedure; this workflow only adds
  the "what evidence to capture" list.
- **Walkthrough + explicit completion approval** requirement.
- **Native-app manifest enforcement model decision** (see below).

### Native-app manifest enforcement model

Recommendation to record: **manifests stay machine-integrity records**
(byte count, artifact SHA-256, source SHA-256, R6 ledger) and *link by path*
to a separate peer-reviewed derivation record under
`src/external/<app>/`. Review metadata is not embedded in the `.ref.hex`
manifest. Rationale: keeps `hex_manifest_to_bin.py` and the manifest
build scripts unchanged in WP1; keeps the human review artifact in a
reviewable prose doc; matches the governing plan's stated preference. WP4
creates the actual DASH/BANNER derivation records; WP1 only fixes the
format.

## Audit-register schema (WP2 will populate; WP1 defines)

Target file (created empty-of-rows in WP1, or WP1 just specifies it and WP2
creates it — see increment 6): `brain/reviews/2026-09-01-casm-byte-oracle-audit.md`
(name retained from the governing plan's Expected Files table even though
authored later).

Columns per the governing plan "Audit and Remediation Method" list:

| Field | Notes |
| --- | --- |
| reference path | `tests/fixtures/casm/<name>.ref.hex` or app manifest |
| source fixture(s) | complete set incl. multi-root / include / payload deps |
| feature + output class | maps to an Oracle class |
| current byte count + artifact hash | as of the audit commit |
| current source hash | none exist today — expected "absent" for most |
| git state | tracked / untracked / modified |
| active-WP owner | which WP (if any) currently mutates it |
| `CASM_REF_NAMES` membership | yes/no + build output path |
| every packaging image | test.d64, casm_overflow, phase images, utils |
| generic packaging-loop exclusion reason | if excluded from the foreach |
| claimed provenance + citation | from the `.ref.hex` header text |
| actual producer path | CMake target / script that emits it |
| generator identity + generated-`.seq` byte hash | for generated fixtures |
| D64 target + native invocation/COMP command | |
| provenance state | one of the five |
| missing derivation/review evidence | gap list |
| remediation disposition | re-derive / quarantine / keep / N-A |
| reviewer record | reviewer + date, filled in WP3/WP4 |
| historical evidence paths | prior review docs |
| re-audit trigger | what change forces re-classification |

WP1 writes **one fully worked example row per oracle class** into the
workflow doc (not the register) so WP2 has a filled template to copy.

## Workflow / DOX reconciliation (the edits WP1 makes)

Read-only grep first for ca65-as-authority wording, then minimal edits:

| File | WP1 action |
| --- | --- |
| `.agents/workflows/canonical-byte-oracles.md` | **Create** |
| `.claude/skills/canonical-byte-oracles/SKILL.md` | **Create** (+ dir) |
| `.agents/workflows/phased-implementation-planning.md` | Add one bullet: WPs that add/change expected bytes must scope oracle impact and name the provenance state |
| `.agents/workflows/vice-mcp-testing.md` | Add a cross-reference: canonical-oracle `COMP` evidence capture list; preserve all existing Command64 boot/input rules |
| `.agents/workflows/per-phase-test-images.md` | One line: oracle-remediation fixtures get a dedicated image only if no current-effort image fits (defer detail to WP3) |
| `.agents/workflows/artifact-tracking.md` | Add derivation-review / audit-register / walkthrough lifecycle entries |
| `.agents/workflows/documentation-maintenance.md` | Add the mirrored CASM/DASH/BANNER/release provenance-doc update rule |
| `.agents/workflows/overlay-build-events.md` | Correct only the sentence that says DASH build evidence comes from `dash_ref`; do **not** touch event wrapping (no target execution changes in WP1) |
| `AGENTS.md` (root) | Add a short durable "canonical byte oracle" policy pointer + child-index entry if the format warrants |
| `src/external/AGENTS.md` | Replace ca65-intersection assumption for CASM-native apps with the canonical-oracle model; note DASH/BANNER specifics deferred to WP4/WP5 |
| `src/external/casm/AGENTS.md` | Add the CASM fixture/oracle + optional-differential contract; leave the CASM *build* contract (ca65/ld65 for casm itself) untouched |
| `src/external/dash/AGENTS.md` | Mark the "Dual-Assembler Subset" clause as *pending WP5 relaxation* — do not remove it yet (WP4 must land replacement evidence first) |
| `tests/AGENTS.md` | State authoritative-fixture provenance + review requirements |

`CMakeLists.txt`, `cmake/GenerateCasmTestFixtures.cmake`, all scripts, all
`*.ref.hex`, all `wiki/`+`docs/` user manuals, `packaging/`, `release/`:
**untouched in WP1.** The governing plan's "trusted reference" CMake wording
is treated as historical and left in place until WP2/WP3.

## Atomic Increments

1. **Read-only survey.** Grep every `.agents/`, `AGENTS.md`, `src/external/**/AGENTS.md`,
   `tests/AGENTS.md`, and CMake comment block for "ca65"/"trusted
   reference"/"authority"/"cross-check"/"host-bytes" wording. Produce a
   short findings list (in this plan's Progress log) of every location
   that will need an edit. Confirm the 67-on-disk vs 63-in-`CASM_REF_NAMES`
   `.ref.hex` delta is real (note it for WP2; do not investigate).
2. **Tracker reconciliation.** Bring `wiki/tasks/casm.md`, `brain/task.md`,
   and Taskwarrior into agreement on: Phase 15 closed; oracle transition
   resumed at WP1; `casm-diagnostic-always-name-file` parked; tasks #39/#33
   still deferred. No content invented — only drift corrected.
3. **Author `.agents/workflows/canonical-byte-oracles.md`** from the
   governing plan's Verification Model + Workflow/Skill Design + Audit
   Method sections, plus the one-worked-row-per-class examples and the
   native-app enforcement-model decision.
4. **Author `.claude/skills/canonical-byte-oracles/SKILL.md`** — trigger
   (adding/changing `*.ref.hex`, native-CASM manifests, expected PRG
   bytes, R6 oracles, ca65 differential comparisons), a short checklist,
   and a pointer back to the workflow. No unique policy.
5. **DOX / workflow reconciliation edits** per the table above — smallest
   edits that remove ca65-as-authority wording and point to the new
   workflow.
6. **Audit-register schema.** Add the column spec + worked rows to the
   workflow doc; create `brain/reviews/2026-09-01-casm-byte-oracle-audit.md`
   containing *only* the schema, a "populated in WP2" banner, and the
   coverage-matrix skeleton (feature axis list, no cells filled).
7. **WP1 gate — manual sample classification.** Pick five fixtures
   (candidates: `casmhello` static; `casmifskip` or `casmifp1p2`
   conditional-suppression; `casmreloc1` or `casmpgr6` R6;
   one diagnostic-only e.g. a `casmnumerr*`; `dash.ref.hex` native-app).
   Classify each by hand against the schema, including exact
   generated-source identity for the conditional case and an explanation
   of why skipped source contributes no bytes. Record in the audit doc as
   the five seed rows.
8. **Present for approval.** Governing-plan Progress log updated; ask for
   explicit user sign-off on the contract before WP2 is planned.

## Expected Files

| File | Planned action |
| --- | --- |
| `.agents/workflows/canonical-byte-oracles.md` | Create |
| `.claude/skills/canonical-byte-oracles/SKILL.md` | Create |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | Create (schema + skeleton only) |
| `.agents/workflows/phased-implementation-planning.md` | Modify (one bullet) |
| `.agents/workflows/vice-mcp-testing.md` | Modify (cross-ref) |
| `.agents/workflows/per-phase-test-images.md` | Modify (one line) |
| `.agents/workflows/artifact-tracking.md` | Modify |
| `.agents/workflows/documentation-maintenance.md` | Modify |
| `.agents/workflows/overlay-build-events.md` | Modify (one sentence) |
| `AGENTS.md` | Modify (policy pointer) |
| `src/external/AGENTS.md` | Modify |
| `src/external/casm/AGENTS.md` | Modify |
| `src/external/dash/AGENTS.md` | Modify (annotate clause as pending WP5) |
| `tests/AGENTS.md` | Modify |
| `wiki/tasks/casm.md`, `brain/task.md` | Modify (tracker reconcile) |
| `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md` | Modify (Progress log) |
| `brain/plans/2026-09-02-casm-byte-oracle-wp1-contract-workflow-schema.md` | Modify (this plan's Progress log) |

## Stop Conditions

- Any active CASM / DASH / native-app / CMake / fixture / workflow / DOX
  effort begins touching a *workflow or DOX file WP1 is editing*.
  (`casm-diagnostic-always-name-file` touches neither, so it is not a WP1
  blocker — but it must be finished, not in flight, before WP2 begins.)
- The read-only survey finds a `.ref.hex` that is untracked, generated
  from uncommitted source, or omitted from CMake in a way that changes the
  contract wording — record and raise, do not paper over.
- Tracker reconciliation surfaces a *material* disagreement (not cosmetic
  drift) about Phase 15 or transition state — stop and confirm with the
  user before writing the workflow.
- Drafting the contract reveals that the governing plan's Verification
  Model is internally inconsistent or cannot be applied to a real fixture
  class — stop, report, get direction rather than inventing policy.
- Any edit to a workflow/DOX file would require also changing executable
  behavior (a CMake target, a script, a manifest) to stay truthful — that
  is out of WP1 scope; stop and defer to the relevant later WP.
- A no-change rebuild after WP1's doc edits changes any build artifact
  (it must not — WP1 touches no build input).
- A genuinely new defect outside WP1 scope is found — disclose and defer.

## Documentation, Task, and DOX Updates

- **At approval:** create Taskwarrior parent (`casm` project, oracle
  transition) + WP1 child; mark WP1 active in `wiki/tasks/casm.md` and
  `brain/task.md`.
- **During:** increments 3–6 are themselves the DOX pass. Governing plan
  Progress log appended at increment 8.
- **At completion:** WP1 walkthrough
  `brain/walkthroughs/2026-09-02-casm-byte-oracle-wp1-contract-workflow-schema.md`
  (paper evidence: the five sample classifications, the grep findings, the
  no-change-rebuild check); trackers synced; `brain/KNOWLEDGE.md` gets the
  durable contract pointer; `CHANGELOG.md` gets a "docs/governance" entry
  (no functional change); memory updated with a
  `project-casm-byte-oracle-wp1-complete` note.
- No user-facing `wiki/`+`docs/` manual changes in WP1 (no user-visible
  behavior change).

## Completion Gate

- `.agents/workflows/canonical-byte-oracles.md` and
  `.claude/skills/canonical-byte-oracles/SKILL.md` exist, agree, contain
  no contradictory policy, and the skill triggers on all five listed
  work types.
- Every ca65-as-authority statement found in increment 1's survey is
  either edited to the new model or explicitly listed as
  "deferred to WP<n>" with a reason.
- The audit-register schema is checked in with one worked row per oracle
  class and a coverage-matrix skeleton.
- The five sample fixtures are classified by hand, each with exactly one
  provenance state; the conditional case names its exact generated source
  and explains the zero-byte skipped block.
- `wiki/tasks/casm.md`, `brain/task.md`, Taskwarrior, and the governing
  plan agree on transition state and the parked diagnostic effort.
- A no-change rebuild produces identical artifacts (spot check:
  `command64_casm_utils_d64` + `test_image_d64` hashes unchanged).
- Walkthrough written; user explicitly approves the contract before WP2
  planning begins.

## Progress

- 2026-09-02: **Increments 3-8 done; contract ready for user sign-off.**
  - Inc 3: `.agents/workflows/canonical-byte-oracles.md` authored (authority
    hierarchy, 7 oracle classes, 5 provenance states, prohibited circular
    sources, acceptable sources, mandatory peer-review metadata + live
    evidence capture list, generated-repetition rule, mismatch stop
    conditions, native-app manifest model, one worked example row per
    class, lifecycle, skill pointer).
  - Inc 4: `.claude/skills/canonical-byte-oracles/SKILL.md` authored — thin
    trigger + 7-step checklist, no unique policy.
  - Inc 5: DOX sweep — minimal edits to
    `phased-implementation-planning.md` (oracle-impact bullet),
    `vice-mcp-testing.md` (canonical-oracle `COMP` evidence cross-ref),
    `per-phase-test-images.md` (`casm_oracle_test.d64` placement line),
    `artifact-tracking.md` (derivation-record + audit-register lifecycle),
    `documentation-maintenance.md` (new §5 mirrored provenance docs),
    `overlay-build-events.md` (corrected the "DASH build events fire from
    `dash_ref`" sentence), root `AGENTS.md` (project-wide oracle Do/Don't),
    `src/external/AGENTS.md` (CASM-native app = documented CASM syntax, not
    a ca65 intersection; manifest = machine-integrity record + linked
    derivation), `src/external/casm/AGENTS.md` (fixture/oracle contract;
    softened the "re-run ca65 cross-checks" DASH-adoption clause),
    `src/external/dash/AGENTS.md` (Dual-Assembler Subset **annotated**
    "pending WP5 relaxation, keep obeying it" — not removed),
    `tests/AGENTS.md` (authoritative-fixture provenance rule). CMake
    "trusted reference" wording left untouched per governing plan.
  - Inc 6+7: `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` created —
    20-field schema, provenance-state table, coverage-matrix skeleton, and
    **five hand classifications**: `casmhello` (Static, CANONICAL-INDEPENDENT
    pending metadata), `casmifskip` (conditional/suppression, exact source
    quoted + PC-non-advance rationale, CANONICAL-INDEPENDENT pending
    metadata), `casmpgr6` (R6, one relocation entry, pending multi-base
    evidence link), `casmnumerrd` (diagnostic rejection, NOT-APPLICABLE, no
    `.ref` and none should exist), `dash.ref.hex` (native manifest,
    NATIVE-OBSERVATION today → CANONICAL-INDEPENDENT after WP4 derivation
    record). Schema validated against all five without a dead field.
  - Inc 8: no-change rebuild — `cmake --build build` clean;
    `command64_casm_utils.d64` SHA-256 `355807c5…` and `test.d64`
    `3d9e0ecb…` **byte-identical before and after** (docs-only changes are
    build-inert, as expected). Walkthrough written. **Awaiting user
    sign-off on the contract before WP2 planning.**
- 2026-09-02: **Increment 2 (tracker reconciliation) done.** Taskwarrior
  parent `75cfa082` + WP1 child `154368e9` created, WP1 started. Fixed
  `brain/task.md` WP93 `[/]`->`[x]` (Phase 15 closed). Added the
  Canonical Byte-Oracle Transition section to `brain/task.md` and
  `wiki/tasks/casm.md` (WP1 active, WP2-6 pending, diagnostic task
  concurrent, #39/#33 deferred). **Deferred to WP2:** `wiki/tasks/casm.md`
  lines ~40-73 still carry stale Phase 14 "awaiting sign-off" / "WP92
  resumes" prose that contradicts the closed-at-0.6.0 reality — a
  ~15-line historical-narrative rewrite, better done in WP2's tracker-sync
  step alongside the full fixture-universe freeze than piecemeal here.
  Taskwarrior task #43 (Phase 14 flmeta harness fix) shows pending — its
  closure is a Phase 14 loose end, not transition state; noted, not
  actioned.
- 2026-09-02: **Increment 1 (read-only survey) complete.** Findings:
  - **Workflows with NO ca65-authority wording** (cross-references only in
    WP1): `vice-mcp-testing.md`, `per-phase-test-images.md`,
    `phased-implementation-planning.md`, `documentation-maintenance.md`,
    `artifact-tracking.md` (its "canonical" refers only to the brain copy).
  - **`.agents/workflows/overlay-build-events.md:62`** — "DASH's real build
    events already fire from the `dash_ref`" — the one sentence WP1 corrects
    (lines 59, 139 are related DASH/native-assembly context, factual, leave).
  - **`src/external/AGENTS.md`** lines 54-55, 69, 73-74 — ca65 cross-check
    assumed as a normal provenance path for CASM-native apps; `--cross-check`
    / `--allow-host-bytes` machinery referenced. WP1 replaces with the
    canonical-oracle model; DASH/BANNER specifics stay deferred to WP4/WP5.
  - **`src/external/casm/AGENTS.md`** line 253 ("CASM and ca65 cross-checks
    … stop and obtain [approval]") needs softening to "optional differential";
    line 13 (build CASM with ca65/ld65) is the protected build contract —
    untouched. Lines 51/122/131/138 are language-divergence notes — leave.
  - **`src/external/dash/AGENTS.md`** — the concentrated load-bearing text:
    lines 16/37/54-64 ("Dual-Assembler Subset"), 73-74 (`--allow-host-bytes`
    refusal), 73/81-85 (`dash_ref` "independent cross-check"), 94 (utility
    disk ships `dash.ref`). WP1 only *annotates* the Subset section as
    "pending WP5 relaxation, do not remove yet"; full rewrite is WP4/WP5.
  - **`tests/AGENTS.md`** lines 23-27 — ca65 as primary test target is
    factual; WP1 adds the authoritative-fixture provenance/review rule.
  - **`src/external/banner/`** has `banner.ref.hex` + `BUILD_BANNER` but
    **no `AGENTS.md`** — noted for WP4 (BANNER derivation record).
  - **CMake wording** (`CMakeLists.txt`, `cmake/GenerateCasmTestFixtures.cmake`)
    — ~30 "trusted reference" / "hand-derived … never from CASM" comments,
    already consistent with the canonical-independent model. Per governing
    plan, treated as historical; **untouched in WP1**. `CMakeLists.txt:1664`
    (`dash_ref` "INDEPENDENT cross-check only") aligned already; WP5 owns it.
  - **Flag for WP2:** `GenerateCasmTestFixtures.cmake:1077` describes a
    fixture verified "CASM-vs-CASM rather than against a hand-derived .ref"
    — a `NATIVE-OBSERVATION` candidate. All 67 on-disk `*.ref.hex` names
    appear somewhere in `CMakeLists.txt`; the 63-vs-67 delta with
    `CASM_REF_NAMES` is because ~4 refs are packaged through separate
    per-phase append targets, not the main list — WP2 must trace every
    packaging path.
- 2026-09-02: Plan drafted. Baseline confirmed clean-committed at `dfe5596`
  after Phase 15 closure (CASM 0.6.1). Governing plan resumed by user.
  Scoping decisions confirmed: resume now; commit housekeeping first (done);
  `casm-diagnostic-always-name-file` runs concurrently with docs-only WP1
  and must merge to `main` before WP2's inventory freeze. Added the ca65
  scope clarification (transition does not remove ca65 as host toolchain;
  only DASH's required ca65 gate is relaxed). Awaiting approval.
