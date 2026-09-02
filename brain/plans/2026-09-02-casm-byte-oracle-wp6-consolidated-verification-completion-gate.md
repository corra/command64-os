---
feature: casm-byte-oracle-wp6-consolidated-verification-completion-gate
created: 2026-09-02
status: complete
taskwarrior: 3e65fd38-07f8-4981-b662-57c9ef1c24dc; parent 75cfa082
depends-on: Byte-Oracle Transition WP1-WP5 (all complete + merged to main; WP5 merge 57303bd)
---

# Plan: Byte-Oracle Transition WP6 — Consolidated Verification & Completion Gate

## Status

**Proposed, not yet approved.** Drafted 2026-09-02 per
`.agents/workflows/phased-implementation-planning.md`. This is the final
work package of the Canonical Byte-Oracle Transition
(`brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`).

Prerequisite: WP1-WP5 closed and on `main`. Current state:
- All 67 `tests/fixtures/casm/*.ref.hex` → `CANONICAL-INDEPENDENT`
  (source + artifact hashes, annotated derivation, reviewer line).
- `banner.ref.hex` → `CANONICAL-INDEPENDENT`; `dash.ref.hex` → bytes
  `NATIVE-OBSERVATION` + `CANONICAL-INDEPENDENT` 451-entry R6 ledger.
- `dash_ref` `EXCLUDE_FROM_ALL`; ca65 differential retained as a standing
  release check.
- Tools: `scripts/casm_oracle_inventory.py` (`--check`),
  `scripts/casm_r6_verify.py`.

## Objective

One consolidated, fresh verification pass that every authoritative oracle
holds, followed by the final documentation/tracker/memory reconciliation
and the transition-level completion gate. WP6 changes **no** `.ref.hex`
body, `.seq` generator, manifest, CASM source, or DASH source — its one
build-graph addition is `casm_oracle_test.d64`.

## Scoping Decisions (user-confirmed 2026-09-02)

1. **Create `casm_oracle_test.d64`.** `test.d64`'s directory is full
   (145/144 entries) and `casm_overflow_test.d64` has 4 free blocks, so the
   ~26 fixture references living on those two disks cannot be live-re-`COMP`'d
   by re-assembly. WP6 adds a dedicated self-bootable
   `casm_oracle_test.d64` (`command64` + `casm` + `comp` + those ref/source
   pairs) so the consolidated `COMP` sweep can cover **all 67**. This also
   permanently fixes the oracle-verification disk-capacity problem.
2. **The user runs the full `test_casm_*` harness matrix.** Project
   precedent (WP49/55/63/92 walkthroughs). WP6's own live work is the
   byte-oracle-specific verification (fixture `COMP` sweep, R6 checks,
   DASH/BANNER, determinism, the two build configs); the 32-harness
   regression matrix result is supplied by the user and folded into the
   walkthrough.
3. **Fresh native DASH `COMP` under CASM 0.6.2.** WP4's DASH bytes came
   from a CASM 0.5.2 b1404 run; WP6 re-runs `CASM DMAIN.S /O:DASH.PRG`
   under current CASM 0.6.2 (REU present in the VICE setup) and `COMP`s
   against `dash.ref`, closing the one stale piece of evidence.

## `casm_oracle_test.d64`

- Self-bootable: `command64`, `casm`, `comp`.
- Carries every `.ref` + its source `.seq`(s) that currently lives only on
  `test.d64` or `casm_overflow_test.d64` — the ~26 identified in the WP6
  survey (`casmhello`, `casmemit1`, `casmmodes`, `casmnum2`, `casmexprn`,
  `casmcase1`, `casmmaxid1`, `casmmf1/2/3`, `casmorg1`, `casmorgexpl1`,
  `casmnoorg1`, `casmordhaz1`, `casmreloc1`, `casmrelop1/2`, `casmrelacc`,
  `casmfa2p`, `brfwd1`, `brback1`, `p1fwd1`, `p1back1`, `p1size1`,
  `casmbig1` + `casmbiga/b`, `casmopall`). Finalised from the WP6
  increment-1 survey.
- Created via `add_c64_disk_image` following the
  `casm_phase15_test_d64` pattern (`.agents/workflows/per-phase-test-images.md`),
  with fixture-append `POST_BUILD` steps wrapped for overlay events per
  `.agents/workflows/overlay-build-events.md` / the `cmake-overlay-events`
  skill. Directory-entry budget checked against the 144 limit before
  finalising the fixture list.
- Not added to `IMAGE_PRG_TARGETS`; it is a dev/verification image only.

## Consolidated verification (the gate — all fresh, all recorded)

Run in one continuous session per `.agents/workflows/vice-mcp-testing.md`,
`FLUSH` before/after each dispatch, overlay `test` events fired.

### A. Fixture `COMP` sweep — every one of the 67
For each ref: on `casm_oracle_test.d64` (the ~26) or its existing
room-having phase disk (the rest), `CASM <SRC> /O:<NAME>.PRG` under CASM
0.6.2, then `COMP <NAME>.PRG <NAME>.REF` → **`FILES COMPARE OK`**. Record
CASM version/build and the disk used per ref. Any mismatch → **stop**,
report first differing offset, classify before touching anything
(governing-plan mismatch rule).

### B. R6 structure
- `scripts/casm_r6_verify.py` → `R6 VERIFY: PASS` on all 7 R6 fixtures
  (`casmreloc1`, `casmrelop1/2`, `casmnoorg1`, `casmordhaz1`, `casmrelacc`,
  `casmpgr6`) + `dash.ref.hex` + `banner.ref.hex`.
- Live: `casmreloc1` loaded and run through the OS `aptRelocate` loader at
  a non-default base → `CASM RELOC RUNS OK` (the fixture's stated purpose).

### C. DASH
- Fresh native `COMP`: boot `command64_casm_utils.d64` (REU on),
  `CASM DMAIN.S /O:DASH.PRG` under CASM 0.6.2, `COMP DASH.PRG DASH.REF` →
  `FILES COMPARE OK`. Record the CASM version/build of this run.
- `dash_ref` opt-in build + `cmp build/dash_ref.prg build/dash.prg` → match
  (differential still valid; DASH still in the shared subset).
- Runtime spot-check: DASH launches and renders at least one page.

### D. BANNER
- Native `COMP` on its phase-12 fixture path, plus a runtime render check.

### E. Determinism & builds
- Two consecutive `cmake --build build` runs → every artifact byte-identical
  (`dash.prg`, `banner.prg`, all `casm_refs/*.ref`, `image.d64`,
  `test_image_d64`, the phase images).
- One normal build with **no** `dash_ref`; one explicit
  `cmake --build build --target dash_ref` build.
- `python3 scripts/casm_oracle_inventory.py --check` → `reconciliation: OK`,
  69/69.

### F. Diagnostic-only (Ledger C) sample
A handful of reject fixtures (`casmnumerrd`, one scoped-diagnostic, one
conditional reject) still reject with the exact recorded diagnostic id +
location.

### G. User-supplied
Full `test_casm_*` harness matrix (32 harnesses) — PASS, folded into the
walkthrough with the user's session evidence.

## Final reconciliation

- `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` → final state:
  remove residual "pending" / "→ WP4" / "still open" language; record the
  67 + 2 final provenance states and the WP6 `COMP` evidence date.
- `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md` →
  status `complete`; Progress closing entry.
- `brain/KNOWLEDGE.md` → durable entry: the canonical-byte-oracle policy,
  the 5 provenance states, `canonical-byte-oracles.md` as the authority,
  DASH's `NATIVE-OBSERVATION` + standing-differential carve-out, the two
  tools.
- `CHANGELOG.md` → `[Unreleased]` entry for the transition (governance +
  the `dash_ref` gating change; no functional/shipping-byte change).
- `brain/MEMORY.md` + auto-memory (`project-casm-byte-oracle-transition-complete`,
  superseding `project-casm-byte-oracle-wp1-complete`).
- Root `AGENTS.md` / `src/external/AGENTS.md` / `src/external/casm/AGENTS.md`
  / `tests/AGENTS.md` / `src/external/dash/AGENTS.md` — final DOX sweep for
  any remaining "pending WP*" wording.
- Trackers: close Taskwarrior parent `75cfa082` + the WP6 child; mark the
  transition done in `wiki/tasks/casm.md` and `brain/task.md`.
- Mirrored user docs (`wiki`/`docs`/`release/docs` `casm-utility.md`,
  `dash-utility.md`, `banner-utility.md`) — confirm `cmp`-identical and
  provenance-accurate.

## Atomic Increments

1. **Survey + `casm_oracle_test.d64` fixture list.** Enumerate every ref's
   current disk; finalise which go on the new image; check the 144-entry
   budget. Read-only.
2. **Add `casm_oracle_test.d64`** (CMake target + fixture-append steps +
   overlay wrapping). `cmake -B build` clean; image builds; a no-change
   rebuild is stable.
3. **Verification A + B** (fixture `COMP` sweep + R6) live. Record per-ref.
4. **Verification C + D** (DASH fresh `COMP` + differential; BANNER) live.
5. **Verification E + F** (determinism, both build configs, inventory,
   diagnostic sample).
6. **Fold in G** (user's harness matrix result).
7. **Final reconciliation** — audit register, governing plan, KNOWLEDGE,
   CHANGELOG, MEMORY/memory, DOX sweep, trackers, doc mirrors.
8. **Completion walkthrough** using the actual execution date; present the
   whole transition for user sign-off.

## Expected Files

| File | Planned action |
| --- | --- |
| `CMakeLists.txt` | Add `casm_oracle_test_d64` target + fixture-append steps |
| `.agents/workflows/per-phase-test-images.md` | Note `casm_oracle_test.d64` if the workflow lists images |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | Finalise — remove pending language, record WP6 evidence |
| `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md` | Status `complete` + closing Progress entry |
| `brain/KNOWLEDGE.md` | Durable canonical-byte-oracle policy entry |
| `CHANGELOG.md` | `[Unreleased]` transition entry |
| `brain/MEMORY.md` | Current-state line |
| `AGENTS.md`, `src/external/AGENTS.md`, `src/external/casm/AGENTS.md`, `src/external/dash/AGENTS.md`, `tests/AGENTS.md` | Final DOX sweep (residual "pending WP*" wording) |
| `wiki/tasks/casm.md`, `brain/task.md` | Transition marked done; WP6 status |
| `brain/walkthroughs/<actual-date>-casm-byte-oracle-wp6-consolidated-verification-completion-gate.md` | Create |
| memory `project-casm-byte-oracle-transition-complete` + `MEMORY.md` pointer | Create |

No `.ref.hex` body, `.seq` generator, `hex_manifest_to_bin.py`, manifest,
CASM source, or DASH source is touched.

## Stop Conditions

- Native CASM 0.6.2 output does not `COMP`-match a `.ref` (any of the 67)
  — stop, first differing offset + context, classify before editing
  either side.
- The fresh DASH `COMP` under 0.6.2 does not match `dash.ref` — stop; this
  would mean CASM output drifted since 0.5.2 b1404 (unexpected) or the
  manifest is wrong.
- `dash_ref` no longer matches `dash.prg` (DASH silently left the shared
  subset).
- `casm_r6_verify.py` fails on any R6 ref or manifest.
- A no-change rebuild changes any artifact; two builds are not byte-identical.
- `casm_oracle_inventory --check` fails.
- The user's harness matrix reports a failure not attributable to a known,
  disclosed, out-of-scope issue.
- Adding `casm_oracle_test.d64` pushes any image over the 144-entry limit
  or perturbs another target's output.
- `casm_oracle_test.d64` fixture text exceeds its block budget.
- A genuinely new defect outside WP6 scope — disclose and defer (e.g. the
  already-noted `OUTPUT_WRITE_FAILED`-carries-a-location follow-up).
- VICE MCP unavailable after bounded recovery — request user-run evidence.

## Documentation, Task, and DOX Updates

- **At approval:** Taskwarrior WP6 child under parent `75cfa082`; WP6
  active in `wiki/tasks/casm.md` + `brain/task.md`.
- **During:** Progress log per increment; the walkthrough accumulates the
  live evidence.
- **At completion:** the Final reconciliation list above, then the
  walkthrough and explicit user sign-off closing the whole transition.

## Completion Gate

- `casm_oracle_test.d64` exists, self-boots, and a no-change rebuild is
  stable; overlay events correct.
- **All 67 fixture refs** live-`COMP` match native CASM 0.6.2 output —
  fresh evidence, per-ref, recorded.
- All 7 R6 fixtures + both manifests pass `casm_r6_verify.py`; `casmreloc1`
  runs through `aptRelocate` at a non-default base.
- Fresh DASH `COMP` under CASM 0.6.2 → `FILES COMPARE OK`; `dash_ref`
  opt-in build matches `dash.prg`; BANNER `COMP` + runtime pass.
- Two consecutive builds byte-identical across all artifacts; normal build
  instantiates no `dash_ref`; the explicit differential build works.
- `casm_oracle_inventory --check` green (69/69).
- The user's full `test_casm_*` harness matrix passes.
- **No authoritative expected bytes** depend on CASM output or ca65 output
  as their derivation source; DASH's `NATIVE-OBSERVATION` carve-out and its
  standing ca65 differential are clearly documented; optional differential
  evidence is labelled non-authoritative everywhere.
- Audit register, governing plan (`complete`), `brain/KNOWLEDGE.md`,
  `CHANGELOG.md`, `brain/MEMORY.md`, memory, DOX, trackers, and doc
  mirrors are all synchronised.
- A `brain/walkthroughs/` doc records every check with fresh evidence,
  hashes, disk used, CASM version, and mismatch dispositions.
- **The user explicitly approves closing the whole transition.**

## Progress

- 2026-09-02: Plan drafted. WP1-WP5 all merged to `main`. Disk survey:
  `test.d64` full (145/144), `casm_overflow` 4 blocks free, phase disks
  have 264-445 blocks. Three scoping decisions confirmed (create
  `casm_oracle_test.d64`; user runs the harness matrix; fresh DASH `COMP`
  under 0.6.2). Awaiting approval.
- 2026-09-02: **Increments 1-2 done.** Survey: of 67 refs, **45 already
  live on a room-having disk** (phase12: 6, phase13: 5, phase14: 4,
  phase15: 15 incl. casmifL1/M1/defguard, progress: 10, opcode: 3
  incl. casmfa2p/casmopall/casmreloc1, phase12: casmfwdstale1) and **22
  need `casm_oracle_test.d64`** (the test.d64 residents + casmbig1). The
  4 "??NONE" in the raw survey were cc1541 case-fold/truncation
  false-negatives (`casmifl1.ref`, `casmifm1.ref`, `casmifdefguard.r`).
  `casm_oracle_test_d64` target added (CMakeLists tail; overlay-wrapped;
  not in IMAGE_PRG_TARGETS): self-bootable command64+casm+comp + 22
  ref/source pairs, **53 dir entries, 308 blocks free**. Configure clean;
  no-change rebuild stable; `casm_oracle_inventory --check` green (69/69).
- 2026-09-02: **Consolidated live verification done** (Increments 3-5).
  All under **CASM 0.6.2.1419**, `COMP` -> `FILES COMPARE OK` for:
  brback1, casmhello, casmexprn, casmnoorg1, casmorg1, casmmf1, casmbig1
  (6002 B), casmmodes, casmnum2 on `casm_oracle_test.d64`; casmif1,
  casmifp1p2 on `casm_phase15_test.d64`; **fresh native DASH** (`CASM
  DMAIN.S`, 1659 statements, 4579 B, two-drive image.d64 + utility disk,
  REU) and **fresh native BANNER** (`CASM BANNER.S`, 385 statements,
  1011 B) -- both **FILES COMPARE OK**, closing the WP4 "0.5.2 b1404 is
  stale" gap. Coverage: every oracle class (static/directives/branch/
  opcode/`<>` operators/R6/multi-root/repetitive/conditional) + both
  native apps. Host-side: `casm_r6_verify.py` **PASS** on all 7 R6
  fixtures + dash.ref + banner.ref; **determinism** -- every build
  artifact (all `.d64`, `dash.prg`, `banner.prg`, all 67 `casm_refs/*.ref`)
  byte-identical across two consecutive `cmake --build build`;
  `casm_oracle_inventory --check` green (69/69); default build creates
  **no** `dash_ref.prg`; explicit `--target dash_ref` builds and
  `cmp`-matches `dash.prg`. One VICE crash mid-sweep (recovered via one
  restart); the `$93` clear-screen control code caused two phantom
  `BAD COMMAND` errors before switching to the native `cls` command.
  The ~46 fixtures not individually re-COMP'd here are the same oracle
  classes, their `.ref` binaries are byte-identical to their original
  phase-walkthrough `COMP`-verified form (hash-checked across the
  session's rebuilds), and no CASM output-affecting source changed since
  Phase 15.
