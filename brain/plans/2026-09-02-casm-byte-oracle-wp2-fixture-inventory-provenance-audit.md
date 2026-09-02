---
feature: casm-byte-oracle-wp2-fixture-inventory-provenance-audit
created: 2026-09-02
status: proposed
taskwarrior: TBD (created on approval)
depends-on: Byte-Oracle Transition WP1 (complete, user-approved 2026-09-02); casm-diagnostic-always-name-file merged to main (78e43c7)
---

# Plan: Byte-Oracle Transition WP2 — Complete Fixture Inventory and Provenance Audit

## Status

**Proposed, not yet approved.** Drafted 2026-09-02 for user review, per the
per-work-package plan-approval requirement
(`.agents/workflows/phased-implementation-planning.md`). No implementation,
task activation, or register content is authorized until this plan is
approved.

Parent plan: `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`.
Prerequisite: WP1 closed (contract + workflow
`.agents/workflows/canonical-byte-oracles.md` + skill + audit-register
**schema** at `brain/reviews/2026-09-01-casm-byte-oracle-audit.md`);
`casm-diagnostic-always-name-file` merged to `main` at `78e43c7` so the
CASM fixture universe is frozen.

## Objective

Inventory and classify **every** CASM byte-correctness evidence surface,
against the WP1 contract, and produce the checked-in audit register and
the feature-to-evidence matrix. WP2 is **read-and-classify only** — it
does not re-derive, rewrite, quarantine, or repackage any reference (that
is WP3), and it does not change any build behavior beyond adding one
non-gating inventory-reconciliation target.

Delivers:

1. `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` filled from its
   WP1 schema: a 20-field row for every `tests/fixtures/casm/*.ref.hex`
   and every CASM-native application manifest, plus the three explicit
   ledgers (fixed-byte artifacts; accepted outputs without a fixed-byte
   oracle; rejected/diagnostic-only fixtures).
2. A provenance state (`CANONICAL-INDEPENDENT` / `DIFFERENTIAL-ONLY` /
   `NATIVE-OBSERVATION` / `UNCLEAR` / `NOT-APPLICABLE`) for every entry,
   with `CANONICAL-INDEPENDENT (pending metadata)` used where the
   derivation is sound and non-circular but source-hash / generated-`.seq`
   hash / named-reviewer evidence is missing (Scoping Decision 3).
3. A mapping of every `tests/src/casm_*` harness to structural or
   `NOT-APPLICABLE` evidence — **no fabricated PRG oracles**.
4. The complete feature-to-evidence matrix, every axis either covered by a
   named fixture/harness or marked `GAP` (Scoping Decision 2).
5. `scripts/casm_oracle_inventory.py` + a non-gating
   `casm_oracle_inventory` CMake target that reconciles the register
   against the filesystem, `CASM_REF_NAMES`, the generated `.seq` set, and
   the packaging graph, and fails if they diverge (Scoping Decision 1).
6. The WP3 remediation worklist (which entries need what), for the user to
   approve as WP2's gate.

Does **not** deliver: any change to a `.ref.hex`, `.seq` generator,
manifest, packaging, harness, or CASM source; any re-derivation; any new
fixture. WP3 owns all of that.

## Scoping Decisions (user-confirmed 2026-09-02)

1. **Committed inventory script.** WP2 adds `scripts/casm_oracle_inventory.py`
   and a non-gating `casm_oracle_inventory` CMake target. The script parses
   `CASM_REF_NAMES`, each `.ref.hex` header, the generated `.seq` bytes,
   and the packaging graph, and emits the register table plus a
   reconciliation assertion (counts + membership + packaging must agree).
   Per the governing plan it inspects metadata and relationships only — it
   never decides that bytes are correct, and it never derives an expected
   byte. It invokes the `cmake-overlay-events` skill for its target.
2. **Full feature-to-evidence matrix**, gaps flagged. Every documented
   feature axis gets a row citing its covering fixture(s)/harness(es) or an
   explicit `GAP` marker. Gaps become WP3 follow-ups or, with user
   approval in WP3, deferrals.
3. **`CANONICAL-INDEPENDENT (pending metadata)`** is the provisional state
   for a reference whose `.ref.hex` shows a genuine independent
   hand-derivation with non-circular bytes but lacks source hash,
   generated-`.seq` hash, or a named reviewer. Only genuinely
   unclear/circular items get `UNCLEAR` / `NATIVE-OBSERVATION`. This keeps
   WP2's output honest about where the real work is (metadata, not
   re-derivation).

## Frozen inventory surface (survey 2026-09-02, `main` @ `78e43c7`)

- **67** `tests/fixtures/casm/*.ref.hex` — all 67 tracked, all 67 in
  `CMakeLists.txt`'s `set(CASM_REF_NAMES ...)`, each producing one
  `${CASM_REF_DIR}/<name>.ref` binary via `hex_manifest_to_bin.py`. The
  earlier "63 vs 67" note was a miscount; the sets reconcile exactly.
- **244** generated `.seq` fixture sources — **none checked in**; all
  emitted at build time by `cmake/GenerateCasmTestFixtures.cmake` (246
  `file(WRITE ...)` calls) into `${CMAKE_BINARY_DIR}/casm_test_fixtures/`.
- **32** `tests/src/casm_*` harnesses (ca65-built `test_casm_*` targets).
- **~47** per-image `POST_BUILD` fixture-append custom commands across
  **13** disk images (`test.d64`, `casm_overflow_test.d64`, the eight
  `casm_phase*/listing/opcode/progress` images, `command64_casm_utils.d64`,
  `image.d64`).
- **2** CASM-native application manifests: `src/external/dash/dash.ref.hex`,
  `src/external/banner/banner.ref.hex`.
- Scripts in scope as inventory inputs (not modified):
  `hex_manifest_to_bin.py`, `build_dash_manifest.py`,
  `build_banner_manifest.py`, `check_casm_source_bytes.py`,
  `verify_casm_diag_table.py`.

## The three ledgers

Every evidence surface lands in exactly one:

- **Ledger A — fixed-byte artifacts.** A `.ref.hex` / `.ref` compared to
  native CASM output with `COMP`. Target: all 67 refs + the 2 manifests.
  Each gets a full 20-field row + a provenance state.
- **Ledger B — accepted outputs without a fixed-byte oracle.** A native
  CASM run whose success is asserted structurally (PC, symbol count,
  determinism) with no frozen `.ref`. Example flagged in WP1:
  `GenerateCasmTestFixtures.cmake:1077` ("CASM-vs-CASM rather than against
  a hand-derived .ref"). Each row records why no byte oracle applies and
  what the actual assertion is.
- **Ledger C — rejected / diagnostic-only fixtures.** A `.seq` that CASM
  must reject; asserts a diagnostic id + location; **no `.ref.hex` and
  none should exist**. Provenance `NOT-APPLICABLE`. Row records the
  expected diagnostic identity and the harness/live path that checks it.

In-memory unit harnesses (the `casm_faultinject*`, `casm_pass1`,
`casm_symbols`, `casm_lexer`, … structural harnesses) map to Ledger C /
`NOT-APPLICABLE` structural evidence and never receive a fabricated PRG
oracle.

## Audit-register row (per the WP1 schema)

For each Ledger A / manifest entry, the 20 fields from
`.agents/workflows/canonical-byte-oracles.md`:

1 reference path · 2 source fixture(s) incl. multi-root/include/payload
deps · 3 feature + oracle class · 4 byte count + artifact SHA-256 · 5
source SHA-256 (expected "absent" for most) · 6 git state · 7 active-WP
owner · 8 `CASM_REF_NAMES` membership + build output path · 9 packaging
image(s) · 10 generic-loop exclusion reason · 11 claimed provenance +
`.ref.hex` header citation · 12 actual producer path in CMake/scripts · 13
generator identity + deterministic hash of the exact generated `.seq`
bytes · 14 D64 target + native `COMP` command · 15 provenance state · 16
missing derivation/review evidence · 17 remediation disposition (for WP3)
· 18 reviewer record (empty in WP2) · 19 historical evidence paths (prior
`brain/reviews/` docs) · 20 re-audit trigger.

Field 13 is why the inventory script exists: a hash of
`GenerateCasmTestFixtures.cmake` alone is insufficient (unrelated edits
would stale every fixture); the script hashes the **exact generated `.seq`
bytes** each ref consumes.

## `scripts/casm_oracle_inventory.py` — contract

- **Inputs (read-only):** `CMakeLists.txt` (`CASM_REF_NAMES`, the
  packaging `POST_BUILD` blocks), `tests/fixtures/casm/*.ref.hex`,
  `${CMAKE_BINARY_DIR}/casm_test_fixtures/*.seq`,
  `${CMAKE_BINARY_DIR}/casm_refs/*.ref`, `src/external/*/*.ref.hex`.
- **Outputs:** the register table (markdown, for paste/diff into the audit
  doc) and a reconciliation report.
- **Reconciliation assertions (the CMake target fails on any):**
  `.ref.hex` count on disk == tracked count == `CASM_REF_NAMES` count;
  every `CASM_REF_NAMES` entry has a `.ref.hex` and a built `.ref`; every
  `.ref.hex` is referenced by at least one packaging step; every generated
  `.seq` consumed by a ref exists.
- **Hard prohibition (asserted in the script's own docstring and the
  workflow):** it must never read `opcodes.s`, disassemble a `.ref`, or
  otherwise compute what a byte "should" be. It reports structure and
  hashes; humans classify.
- Non-gating: not in `ALL`, not a dependency of any image or release
  target. Wired for overlay events per the `cmake-overlay-events` skill
  (it invokes no external build tool, so it likely needs no wrapper —
  confirm against `overlay-build-events.md` during implementation).

## Atomic Increments

1. **Fresh read-only re-survey** from `main` @ the current commit. Confirm
   the counts above still hold; snapshot the exact commit hash into the
   audit doc as the WP2 baseline. Confirm the worktree is clean in every
   oracle-relevant path (stop condition otherwise).
2. **Tracker reconciliation.** Resolve the stale Phase 14 "awaiting
   sign-off" / "WP92 resumes" narrative in `wiki/tasks/casm.md` (deferred
   from WP1) against the closed-at-`0.6.0` reality; confirm Taskwarrior
   `#43` disposition. Any *material* disagreement about fixture or phase
   state stops the inventory until reconciled.
3. **Build `scripts/casm_oracle_inventory.py` + the CMake target.** Prove
   the reconciliation assertions pass on the clean tree. No register
   content yet.
4. **Ledger C first (rejected / diagnostic-only).** Walk every `.seq`
   generator that produces a rejection; record expected diagnostic id +
   location + the checking path; mark `NOT-APPLICABLE`. This clears the
   large, low-ambiguity bulk and de-risks the count reconciliation.
5. **Ledger B (accepted, no fixed-byte oracle).** Identify every
   structural/determinism/CASM-vs-CASM assertion; record the actual
   assertion and why no byte oracle applies.
6. **Ledger A — refs, in oracle-class batches** (static · expressions/
   directives · conditionals · local labels · R6/relocation ·
   large/repetitive · listing/map). For each ref: fill all 20 fields,
   assign a provenance state per Scoping Decision 3, and list the WP3 gap.
7. **Native-app manifests.** Full rows for `dash.ref.hex` and
   `banner.ref.hex`; both provisionally `NATIVE-OBSERVATION` (they become
   `CANONICAL-INDEPENDENT` only after WP4 derivation records). Record
   their source-hash sets and the ca65 differential status as
   `DIFFERENTIAL-ONLY` notes.
8. **Feature-to-evidence matrix.** Every axis → covering fixture(s) or
   `GAP`. Cross-check against `casmopall` + the opcode oracle review for
   the 151-tuple axis.
9. **WP3 remediation worklist.** Aggregate fields 16-17 into an ordered,
   batched worklist by oracle class. Present the full register + matrix +
   worklist for the WP2 gate.

## Expected Files

| File | Planned action |
| --- | --- |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | Fill from schema — register rows, 3 ledgers, matrix, WP3 worklist |
| `scripts/casm_oracle_inventory.py` | Create — read-only inventory + reconciliation |
| `CMakeLists.txt` | Add non-gating `casm_oracle_inventory` custom target only |
| `.agents/workflows/canonical-byte-oracles.md` | Add a one-line pointer to the inventory script + its prohibition; no policy change |
| `.claude/skills/cmake-overlay-events` (invoked, not edited) | Follow for the new target |
| `wiki/tasks/casm.md` | Increment 2 tracker reconciliation (stale Phase 14 prose) + WP2 status |
| `brain/task.md` | WP2 status; Phase 14 prose reconcile if mirrored |
| `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md` | Progress log |
| `brain/plans/2026-09-02-casm-byte-oracle-wp2-*.md` | This plan's Progress log |
| `brain/walkthroughs/2026-09-02-casm-byte-oracle-wp2-*.md` | Create at close — the reconciliation output + register summary |

No `.ref.hex`, `.seq` generator, manifest, harness, packaging step, or
CASM source is touched in WP2.

## Stop Conditions

- The worktree is dirty in an oracle-relevant path
  (`tests/fixtures/casm/`, `cmake/GenerateCasmTestFixtures.cmake`,
  `CMakeLists.txt` packaging, `src/external/*/`) at baseline, or a `.ref`
  is untracked / omitted from CMake / generated from uncommitted source.
- The inventory count does not reconcile exactly among filesystem,
  `CASM_REF_NAMES`, generated binaries, CMake packaging, and documented
  live comparisons — stop and resolve before continuing the register.
- An active CASM / DASH / diagnostic / native-app / CMake / fixture /
  workflow / DOX effort changes an audited reference, generated source,
  packaging path, or manifest while WP2 is open.
- Classifying a reference would require re-deriving or reading `opcodes.s`
  / disassembling the `.ref` to decide its state — that is WP3; mark it
  `UNCLEAR` and move on, do not start remediation.
- An active plan's front matter, body, Taskwarrior state, `brain/task.md`,
  or `wiki/tasks/*.md` materially disagree about fixture/phase state.
- A manifest source hash differs from a clean regeneration (would mean the
  artifact and its provenance drifted) — disclose, do not fix.
- A genuinely new defect outside WP2 scope is found (e.g. a ref that IS
  circular and wrong) — disclose and defer to WP3; do not fix inline.
- A no-change rebuild changes any artifact, or the new
  `casm_oracle_inventory` target perturbs any existing target's output.

## Documentation, Task, and DOX Updates

- **At approval:** create the Taskwarrior WP2 child under parent
  `75cfa082`; mark WP2 active in `wiki/tasks/casm.md` + `brain/task.md`.
- **During:** append this plan's Progress log per increment; the audit
  register itself is the primary work product.
- **At completion:** walkthrough
  `brain/walkthroughs/2026-09-02-casm-byte-oracle-wp2-fixture-inventory-provenance-audit.md`
  with the reconciliation output, the register summary counts per
  provenance state, and the WP3 worklist; trackers synced;
  `brain/KNOWLEDGE.md` / `brain/MEMORY.md` note only if the audit changes
  the durable picture (WP6 records the final policy). No user-facing
  `wiki/`+`docs/` manual change (no behavior change).

## Completion Gate

- Every `tests/fixtures/casm/*.ref.hex` (67) and every CASM-native
  manifest (2) has a complete 20-field row and exactly one provenance
  state in `brain/reviews/2026-09-01-casm-byte-oracle-audit.md`.
- The three ledgers are complete; every `tests/src/casm_*` harness (32) is
  mapped to structural / `NOT-APPLICABLE` evidence; no harness has a
  fabricated PRG oracle.
- `scripts/casm_oracle_inventory.py` + `casm_oracle_inventory` target
  exist, are non-gating, and their reconciliation assertions pass on a
  clean `main` tree; a no-change rebuild is stable; overlay events correct.
- The reference count reconciles exactly among filesystem,
  `CASM_REF_NAMES`, built `.ref` binaries, CMake packaging, and documented
  live `COMP` paths — no fixture omitted.
- The feature-to-evidence matrix is complete: every axis cites a covering
  fixture/harness or an explicit `GAP`.
- The WP3 remediation worklist is batched by oracle class and the user
  approves the remediation register.
- Trackers (Taskwarrior, `brain/task.md`, `wiki/tasks/casm.md`,
  governing plan) synchronized; the stale Phase 14 `wiki/tasks/casm.md`
  narrative is reconciled.
- A `brain/walkthroughs/` doc records the reconciliation output and
  per-state counts.
- **The user explicitly approves the register and the WP3 worklist.** WP2
  is not marked complete before that approval, and WP3 does not begin
  until it.

## Progress

- 2026-09-02: Plan drafted. Survey confirmed 67 `.ref.hex` (all tracked,
  all in `CASM_REF_NAMES`), 244 generated `.seq`, 32 harnesses, ~47
  packaging steps across 13 images, 2 native manifests. Three scoping
  decisions confirmed (committed inventory script + CMake check; full
  feature matrix with `GAP` markers; `CANONICAL-INDEPENDENT (pending
  metadata)` as the provisional state for sound-but-unhashed refs).
  Awaiting approval.
