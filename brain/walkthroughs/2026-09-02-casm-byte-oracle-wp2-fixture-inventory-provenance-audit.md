# Walkthrough: Byte-Oracle Transition WP2 — Fixture Inventory & Provenance Audit

Plan: `brain/plans/2026-09-02-casm-byte-oracle-wp2-fixture-inventory-provenance-audit.md`
Parent: `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`
Date executed: 2026-09-02
Branch: `feature/casm-byte-oracle-wp2` · baseline `b3193853`
Taskwarrior: WP2 `d3e4435b`, parent `75cfa082`

## Scope reminder

Read-and-classify only. **No `.ref.hex`, `.seq` generator, manifest,
packaging step, or CASM source was changed.** The one build-graph addition
is a non-gating reconciliation target.

## Increment 1 — baseline

Baseline `b3193853`; worktree clean in every oracle-relevant path.

## Increment 2 — tracker reconciliation

`wiki/tasks/casm.md` "Current Milestone": the stale Phase 15 "WP99
awaiting sign-off" tail and the ~30-line Phase 14 "WP89 awaiting sign-off /
WP92 resumes" narrative replaced with concise closed summaries (Phase 15
closed+merged 0.6.1 b1417; Phase 14 closed 0.6.0 b1405); added CASM 0.6.2
+ Byte-Oracle WP1/WP2 status. Taskwarrior `#43` confirmed resolved
(`8da90f45`; `brain/task.md:3933` already records it closed). No material
tracker disagreement remains.

## Increment 3 — `scripts/casm_oracle_inventory.py` + `casm_oracle_inventory` target

Read-only. Enumerates every `.ref.hex`, cross-checks each manifest's
declared `bytes:`/`sha256:` against its own hex body, hashes generated
`.seq` bytes, traces packaging, and asserts
`CASM_REF_NAMES == on-disk == git-tracked` with a packaging step per
reference. It never reads `opcodes.s`, never disassembles a `.ref`, and
assigns no provenance state.

```
$ cmake --build build --target casm_oracle_inventory
# summary: 67 .ref.hex on disk, 67 in CASM_REF_NAMES, 67 tracked, 2 native manifests
# with declared sha256: 37/67; header claims independent derivation: 66/67
# reconciliation: OK
```

Target is not in `ALL`, not a dependency of any image/release target, and
invokes no build tool → no overlay wrapper (per
`.agents/workflows/overlay-build-events.md`). A `cmake --build build` does
not run it.

## Increments 4–8 — the register

`brain/reviews/2026-09-01-casm-byte-oracle-audit.md`:

### Ledger A — 67 refs + 2 manifests

| provenance state | count | which |
| --- | --- | --- |
| `CANONICAL-INDEPENDENT (pending metadata)` | 66 | every ref whose `.ref.hex` documents an independent hand-derivation ("NOT produced by CASM"), bytes internally consistent; all missing source SHA-256 + generated-`.seq` hash + reviewer, 30 also missing artifact SHA-256 |
| `UNCLEAR` | 1 | `casmexprn` (WP20) — no derivation statement |
| `NATIVE-OBSERVATION` | 2 | `dash.ref.hex`, `banner.ref.hex` — machine-integrity records, not oracles; → `CANONICAL-INDEPENDENT` via WP4 |

### Ledgers B + C — 183 generated `.seq` with no `.ref.hex`

All `NOT-APPLICABLE`. Sub-bucket hint: ~56 reject/diagnostic, ~93
accepted-structural, ~34 include/multi-root support-files. The set is
exactly `comm -23 <244 generated> <67 CASM_REF_NAMES>` — confirmed none
has or claims a byte oracle.

### Harness map — 32 `tests/src/casm_*`

Every one is an in-memory unit / structural harness. None `COMP`s a PRG
against a `.ref`. No fabricated PRG oracle assigned to any.

### Feature-to-evidence matrix

Every documented axis (151 opcode tuples, branches, expressions, all
directives, conditionals, `@local`, includes, static/R6/listing/map/
diagnostics/determinism/progress, DASH, BANNER) is covered by a Ledger-A
ref and/or a structural harness. **No axis is uncovered.**

### WP3 remediation worklist (the WP2 gate)

1. Metadata completion for the 66 `pending` refs (source + `.seq` hashes +
   reviewer; artifact SHA-256 for the 30 without one). Mechanical + review,
   no byte changes.
2. `casmexprn` — reconstruct + record the derivation, or quarantine.
3. R6 class — multi-base relocation-application evidence per R6 ref.
4. `casmbig1` — reviewed repetition rule + assembler-independent expansion.
5. Listing/map — confirm a canonical text/record-layout reference exists.
6. DASH + BANNER independent derivation records → **WP4** (not WP3).

Ledgers B/C need no remediation.

## Completion-gate status

| Gate item | Status |
| --- | --- |
| every `.ref.hex` (67) + manifest (2) has a full row + one state | ✅ |
| three ledgers complete; 32 harnesses mapped; no fabricated oracle | ✅ |
| `casm_oracle_inventory` exists, non-gating, assertions pass on clean tree | ✅ |
| no-change rebuild stable; overlay events correct | ✅ (`cmake --build` unaffected; target not in ALL) |
| reference count reconciles exactly, no fixture omitted | ✅ 67=67=67; 183 no-ref set enumerated |
| feature-to-evidence matrix complete, gaps flagged | ✅ |
| WP3 worklist batched by oracle class | ✅ |
| trackers synchronized | ✅ |
| **user approves the register + WP3 worklist** | ⏳ pending |

## Files changed

| File | Change |
| --- | --- |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | Filled — Ledger A/B/C, harness map, matrix, WP3 worklist (WP1 seed rows kept as appendix) |
| `scripts/casm_oracle_inventory.py` | Created — read-only inventory + reconciliation |
| `CMakeLists.txt` | Added non-gating `casm_oracle_inventory` target |
| `.agents/workflows/canonical-byte-oracles.md` | +"Inventory reconciliation" section |
| `wiki/tasks/casm.md` | Tracker reconciliation (stale Phase 14/15 prose) + WP2 status |
| `brain/plans/2026-09-02-casm-byte-oracle-wp2-*.md` | Progress log |

## Notes

- The Ledger B/C reject-vs-structural sub-split is a WP2 hint from the
  generator/packaging comments, not a per-fixture verified classification;
  every entry is `NOT-APPLICABLE` regardless, and WP6's consolidated pass
  confirms the reject cases assert an exact diagnostic identity.
- `casmexprn` is the only `UNCLEAR` — a single Phase-5-era fixture that
  never got the "NOT produced by CASM" header the other 66 have.
