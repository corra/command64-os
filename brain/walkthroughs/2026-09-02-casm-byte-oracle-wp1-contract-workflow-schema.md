# Walkthrough: Byte-Oracle Transition WP1 — Contract, Workflow, Skill, Audit Schema

Plan: `brain/plans/2026-09-02-casm-byte-oracle-wp1-contract-workflow-schema.md`
Parent: `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`
Date executed: 2026-09-02
Taskwarrior: WP1 `154368e9-1fa8-4b48-b7bd-c02f2029f00f`; parent `75cfa082-af8a-4783-8cd3-eb743f3040b7`

## Scope reminder

Docs and governance only. No `*.ref.hex`, `*.seq`, generated fixture,
manifest, `CMakeLists.txt`, `cmake/*.cmake`, script, or CASM source was
changed. No live VICE run (nothing executable changed).

## What was done

### Baseline
- Phase 15 confirmed closed/merged to `main` (user-approved 2026-09-02,
  CASM 0.6.1 build 1417).
- Clean committed baseline established at `dfe5596` (doc-only housekeeping:
  oracle plan, diagnostic plan, native-viability review). Two unrelated
  untracked files (`docs/codebase-knowledge-graph.md`, `test_g2.png`) left
  alone — not oracle-relevant.

### Increment 1 — read-only survey
Grepped `.agents/`, all `AGENTS.md`, `tests/AGENTS.md`, and CMake comment
blocks for ca65-as-authority wording. Findings recorded in the plan
Progress log. Key results: 5 workflows carry no ca65-authority wording;
the concentrated load-bearing text is in `src/external/dash/AGENTS.md`;
CMake "trusted reference / hand-derived … never from CASM" comments are
already model-consistent (left untouched); 67 on-disk `*.ref.hex` vs 63 in
`CASM_REF_NAMES` — delta is separate per-phase append targets, flagged for
WP2.

### Increment 2 — tracker reconciliation
- Taskwarrior parent + WP1 child created; WP1 started.
- `brain/task.md`: WP93 `[/]` → `[x]` (Phase 15 closed); Canonical
  Byte-Oracle Transition section added (WP1 active, WP2–6 pending).
- `wiki/tasks/casm.md`: transition section added.
- Deferred to WP2: stale Phase 14 "awaiting sign-off" prose in
  `wiki/tasks/casm.md` (~15-line historical rewrite, better with the WP2
  fixture-universe freeze).

### Increment 3 — the workflow
`.agents/workflows/canonical-byte-oracles.md` created. Consolidates the
governing plan's Verification Model, Workflow/Skill Design, and Audit
Method into one normative document: authority hierarchy (5 levels), oracle
classes (7) with required evidence, provenance states (5), prohibited
circular sources, acceptable independent sources, mandatory metadata +
peer review, live-evidence capture list, generated-repetition rule,
mismatch classification + stop conditions, native-app manifest model
(machine-integrity record + linked derivation record — the governing
plan's preferred option, recorded as the decision), one worked example row
per oracle class, lifecycle, and the skill pointer.

### Increment 4 — the skill
`.claude/skills/canonical-byte-oracles/SKILL.md` created — trigger
(ref.hex / native manifest / expected PRG bytes / R6 oracle / ca65
differential), the single most-violated rule stated up front, a 7-step
checklist, native-app manifest note. No unique policy. Registered and
visible in-session after creation.

### Increment 5 — DOX / workflow reconciliation
Minimal edits (see plan Progress log for the per-file list). Notable:
`overlay-build-events.md` sentence "DASH's real build events already fire
from the `dash_ref` target" corrected — DASH's shipped `dash.prg` comes
from the reviewed native manifest transcription, not ca65.
`src/external/dash/AGENTS.md` "Dual-Assembler Subset" was **annotated** as
"pending WP5 relaxation — keep obeying it", not removed. CMake wording
untouched.

### Increments 6 + 7 — audit-register schema + sample classification
`brain/reviews/2026-09-01-casm-byte-oracle-audit.md` created: 20-field row
schema, provenance-state table, coverage-matrix skeleton (feature axis,
no cells), and five hand classifications against the schema:

| Reference | Class | Provisional state |
| --- | --- | --- |
| `casmhello.ref.hex` | Static PRG | `CANONICAL-INDEPENDENT` pending metadata (no source hash / generated-`.seq` hash / named reviewer) |
| `casmifskip.ref.hex` | Static PRG defined by conditional suppression | `CANONICAL-INDEPENDENT` pending metadata — exact source quoted, PC-non-advance rationale recorded, expected `00 C0 EA` |
| `casmpgr6.ref.hex` | R6 PRG (1 relocation entry) | `CANONICAL-INDEPENDENT` pending metadata + linked multi-base evidence |
| `casmnumerrd` | Diagnostic rejection | `NOT-APPLICABLE` — no `.ref`, none should exist, not in `CASM_REF_NAMES` |
| `src/external/dash/dash.ref.hex` | Native application manifest | `NATIVE-OBSERVATION` today → `CANONICAL-INDEPENDENT` after WP4 derivation record |

Schema accommodated all five with no dead field. Feedback into the
contract: expect a large "strengthen metadata" column in WP2, not mass
re-derivation.

### Increment 8 — no-change rebuild
```
$ sha256sum build/command64_casm_utils.d64 build/test.d64
355807c55e940304e2666395f4c48bdedbbaa5b5e385851dbe240c9a4a3a804f  build/command64_casm_utils.d64
3d9e0ecba24cf3a0d62249093dd6f6dd91d9b4ee1209ef3663274847b9f4b896  build/test.d64
$ cmake --build build      # → [100%] clean, no errors
$ sha256sum build/command64_casm_utils.d64 build/test.d64
355807c55e940304e2666395f4c48bdedbbaa5b5e385851dbe240c9a4a3a804f  build/command64_casm_utils.d64
3d9e0ecba24cf3a0d62249093dd6f6dd91d9b4ee1209ef3663274847b9f4b896  build/test.d64
```
Both key artifacts byte-identical before/after — docs-only changes are
build-inert, as expected.

## Files changed

| File | Change |
| --- | --- |
| `.agents/workflows/canonical-byte-oracles.md` | Created |
| `.claude/skills/canonical-byte-oracles/SKILL.md` | Created |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | Created (schema + 5 seed rows) |
| `.agents/workflows/phased-implementation-planning.md` | +oracle-impact bullet |
| `.agents/workflows/vice-mcp-testing.md` | +canonical-oracle COMP evidence cross-ref |
| `.agents/workflows/per-phase-test-images.md` | +oracle-remediation image line |
| `.agents/workflows/artifact-tracking.md` | +derivation-record / audit-register lifecycle |
| `.agents/workflows/documentation-maintenance.md` | +§5 mirrored provenance docs |
| `.agents/workflows/overlay-build-events.md` | Corrected DASH build-evidence sentence |
| `AGENTS.md` | +project-wide oracle Do/Don't |
| `src/external/AGENTS.md` | CASM-native app model; manifest = integrity record + linked derivation |
| `src/external/casm/AGENTS.md` | +fixture/oracle contract; softened ca65-cross-check DASH clause |
| `src/external/dash/AGENTS.md` | Dual-Assembler Subset annotated "pending WP5", not removed |
| `tests/AGENTS.md` | +authoritative-fixture provenance rule |
| `brain/task.md`, `wiki/tasks/casm.md` | Transition trackers; WP93 `[/]`→`[x]` |
| `brain/plans/2026-09-02-casm-byte-oracle-wp1-*.md` | Progress log |
| `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md` | Progress log |

## Open / deferred

- **Stale Phase 14 prose** in `wiki/tasks/casm.md` — WP2 tracker-sync.
- **Metadata gaps** on nearly every existing `.ref.hex` (source hash,
  generated-`.seq` hash, named reviewer) — WP3 remediation.
- **DASH independent derivation record** — WP4.
- **`casm-diagnostic-always-name-file`** — runs concurrently, must merge to
  `main` before WP2's inventory freeze.
- Taskwarrior #43 (Phase 14 flmeta harness fix) still pending — Phase 14
  loose end, not transition state.

## Completion gate status

- [x] workflow + skill exist, agree, skill triggers on all 5 work types
- [x] every ca65-as-authority statement from the survey edited or listed
      as deferred-to-WP with a reason
- [x] audit-register schema checked in with 1 worked row per class + matrix skeleton
- [x] 5 samples classified, one provenance state each, conditional case
      names its exact source + zero-byte rationale
- [x] `wiki/tasks/casm.md`, `brain/task.md`, Taskwarrior, governing plan agree
- [x] no-change rebuild → identical artifacts
- [ ] **user explicitly approves the contract** — pending
