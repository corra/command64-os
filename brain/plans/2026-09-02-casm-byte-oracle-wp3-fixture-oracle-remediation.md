---
feature: casm-byte-oracle-wp3-fixture-oracle-remediation
created: 2026-09-02
status: approved-in-progress
taskwarrior: 80484a2b-20f6-40d7-9d45-da1072381d61 (WP3); parent 75cfa082-af8a-4783-8cd3-eb743f3040b7
depends-on: Byte-Oracle Transition WP2 (complete, user-approved 2026-09-02, merged a04c8bb)
---

# Plan: Byte-Oracle Transition WP3 — Fixture Oracle Remediation

## Status

**Proposed, not yet approved.** Drafted 2026-09-02 per
`.agents/workflows/phased-implementation-planning.md`. No implementation,
task activation, `.ref.hex` edit, or derivation record is authorized until
this plan is approved.

Parent: `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`.
Prerequisite: WP2 closed — audit register
`brain/reviews/2026-09-01-casm-byte-oracle-audit.md` with the 6-batch
worklist; `casm_oracle_inventory` reconciliation target on `main`.

## Objective

Bring every authoritative CASM fixture reference to
`CANONICAL-INDEPENDENT` under the WP1 contract, so no packaged `.ref`
depends on CASM output (or ca65) as its derivation source and every one
carries source-hash, generated-`.seq` hash, an annotated derivation, and a
reviewer sign-off.

Delivers, per the WP2 worklist:

1. **Metadata completion** for the 66 `CANONICAL-INDEPENDENT (pending
   metadata)` refs — `source_sha256:`, `seq_sha256:`, `reviewed_by:` lines
   in each `.ref.hex` header; `sha256:` added to the 30 that lack it. **No
   assembled byte changes** (`hex_manifest_to_bin.py` ignores `#` lines).
2. **`casmexprn`** re-derived from the 6502 encoding + its `.seq` source,
   full derivation statement added, promoted `UNCLEAR` →
   `CANONICAL-INDEPENDENT`. Coverage (`<`/`>` byte-extraction operators in
   operands) is unique — not quarantined.
3. **R6 class** — a reviewed relocation-eligibility ledger and live
   multi-base relocation-application evidence for the 9 R6 refs
   (`casmreloc1`, `casmrelop1/2`, `casmnoorg1`, `casmordhaz1`,
   `casmrelacc`, `casmfa2p`, `casmorgexpl1`, `casmpgr6`).
4. **`casmbig1`** — a reviewed repetition rule (seed bytes + count/range
   formula) with an assembler-independent expansion and boundary
   spot-checks.
5. **Listing / map** — confirm (or create) a canonical text/record-layout
   reference for `/L` and `/M`, or record why the focused structural
   harness is the correct assertion.
6. Per-batch derivation records under `brain/reviews/`; the audit register
   updated to `CANONICAL-INDEPENDENT` as each batch is signed off.

Does **not** deliver: any change to a `.seq` generator, a CASM source
file, packaging, or the 2 native-app manifests (WP4). No new fixture
unless an audit-proven coverage gap requires one (none identified in WP2 —
the feature matrix has no uncovered axis).

## Scoping Decisions (user-confirmed 2026-09-02)

1. **Reviewer model:** the agent authors each derivation independently
   (from documented NMOS 6502/6510 encoding + the fixture's own `.seq`
   source, never from CASM output, `opcodes.s`, or ca65), freezes it in a
   `brain/reviews/` record, and **the user is the independent reviewer**
   who signs off per batch — the same model as the WP60 opcode oracle
   ("Frozen for user review"). The `.ref.hex` gets `reviewed_by: user,
   YYYY-MM-DD` only after that sign-off.
2. **Metadata home:** the `.ref.hex` header comment. New `#` lines
   `source_sha256: <file>=<hash>`, `seq_sha256: <hash>`, `reviewed_by:
   user, <date>` — exactly how `dash.ref.hex` / `banner.ref.hex` already
   carry `source_sha256`. `hex_manifest_to_bin.py` skips `#` lines, so
   **zero code change** to the transcription path; `casm_oracle_inventory`
   is extended to read and verify the new fields.
3. **`casmexprn`:** re-derive and keep (its `<`/`>` operand-operator
   coverage is not duplicated by `casmnum2` / `casmarith*`).

## What "metadata completion" actually changes (Batch 1)

For each of the 66 refs, in the `#` header:

- `seq_sha256:` — SHA-256 of the exact generated `.seq` byte stream the
  fixture consumes (from `casm_oracle_inventory`; for multi-root fixtures,
  one line per source file).
- `source_sha256:` — same value keyed by source filename, for parity with
  the native-app manifest format and so a `.seq` generator edit is a
  detectable stale-artifact condition.
- `sha256:` — added to the 30 refs that only declare `bytes:` (value is
  the frozen body hash the inventory script already computes and
  cross-checks; **not** a new derivation).
- `reviewed_by: user, <date>` — added only after the batch's derivation
  record is user-approved.

The assembled `.ref` binary is byte-identical before and after every Batch
1 edit (proven by `casm_oracle_inventory` declared-vs-actual body check +
a spot `COMP`). The `.ref.hex` **file** hash changes — that is expected
and is not an oracle-relevant value.

## Derivation records

One per oracle-class batch, under `brain/reviews/`:

- `2026-09-02-casm-byte-oracle-wp3-batch1a-static-derivations.md`
- `...-batch1b-expr-directive-derivations.md`
- `...-batch1c-conditional-derivations.md`
- `...-batch1d-local-label-derivations.md`
- `...-batch1e-progress-path-derivations.md`
- `...-batch2-casmexprn-derivation.md`
- `...-batch3-r6-relocation-derivations.md`
- `...-batch4-casmbig1-repetition-rule.md`

Each record: for every ref in the batch, the load address, the address
ledger, and every byte or byte-range traced to a 6502-encoding rule or an
arithmetic step a reviewer can redo; the source identity + hash; and (R6)
the relocation-eligibility ledger + sorted entry offsets + footer
derivation. Authored **without** consulting CASM output as the answer;
native `COMP` is recorded afterwards as confirmation.

## Atomic Increments

1. **Extend `casm_oracle_inventory.py`** to (a) read `seq_sha256:` /
   `source_sha256:` / `reviewed_by:` and (b) assert, for any ref that
   declares them, that `seq_sha256` matches the current generated `.seq`
   and `sha256` matches the body. Still non-gating. Prove it passes on the
   clean tree (no ref declares the new fields yet, so nothing to check).
2. **Batch 1a — static PRGs** (`casmhello`, `casmemit1`, `casmmodes`,
   `casmnum2`, `casmnoorg1`… the ~30 plain-static refs). Author the
   derivation record; add `seq_sha256`/`source_sha256`/`sha256` lines;
   `casm_oracle_inventory --check` green; spot-`COMP` 3-4 of them live to
   confirm the `.ref` binaries are unmoved. Freeze the record; request
   user sign-off; on approval add `reviewed_by:` and flip the register
   rows to `CANONICAL-INDEPENDENT`.
3. **Batch 1b — expressions / directives** (`casmarith2/3`, `casmarithfwd`,
   `casmchain1`, `casmzpconst1`, `casmchar1`, `casmstring1`, `casmres1`,
   `casmfill1`, `casmalign1`, `casmincbin1`, `casmassert1`, `casmcase1`,
   `casmmaxid1`, `casmfwdstale1`, `casmrelacc`). Same cycle.
4. **Batch 1c — conditionals** (the 14 `casmif*` refs). Same cycle;
   `casmifskip`/`casmif0` derivations state the PC-non-advance rule for
   the skipped branch.
5. **Batch 1d — `@local`** (`casmloc1/2/3/7`). Same cycle.
6. **Batch 1e — progress-path** (`casmpg63/64/65/128`, `casmpgblank`,
   `casmpgfill`, `casmpgincbin`, `casmpgrt`, `casmpginc`, plus `casmbig1`
   deferred to Batch 4, `casmpgr6` to Batch 3). Same cycle; note the
   assembled output is identical with/without progress indication.
7. **Batch 2 — `casmexprn`.** Re-derive `00 C0 A9 34 A5 12 B1 34 34 12 34
   00 12 00` from `LDA #<$1234` / `LDA >$1234` / `LDA (<$1234),Y` /
   `.BYTE </>` / `.WORD </>`; add the full derivation statement + all
   metadata; live `COMP`; user sign-off → `CANONICAL-INDEPENDENT`.
8. **Batch 3 — R6 class.** For each of the 9 R6 refs: reviewed relocation
   eligibility ledger, sorted entry offsets, count/terminator/footer
   derivation, and a **live** two-base check (assemble under CASM, load at
   two bases a page apart, confirm the relocated operand bytes) via
   `.agents/workflows/vice-mcp-testing.md`. Record in the batch-3 doc +
   the `.ref.hex` headers.
9. **Batch 4 — `casmbig1`.** Record the seed (`EA` × N per file) + the
   count formula + `casmbiga`/`casmbigb` split; an independent Python
   expansion reproducing the 6002-byte body; boundary spot-checks
   (offsets 0, mid, end); whole-file hash; live `COMP`.
10. **Batch 5 — listing / map.** Determine whether `/L` and `/M` output
    is contractual text that warrants a canonical layout reference beyond
    `casmifL1`/`casmifM1` + the `casm_listing`/`casm_map` harnesses;
    either add the reference or record the rationale in the register.
11. **WP3 consolidated verification.** Fresh: `casm_oracle_inventory
    --check` green with all 67 refs carrying full metadata and
    `reviewed_by`; a no-change rebuild proves every `.ref` binary
    byte-stable; a focused live `COMP` sweep of every ref whose header
    changed a *declared* value (not just added `#` lines); the R6 and
    `casmbig1` live checks re-run together. Walkthrough; register shows
    **67/67 `CANONICAL-INDEPENDENT`, 0 `UNCLEAR`**; user close approval.

## Expected Files

| File | Planned action |
| --- | --- |
| `tests/fixtures/casm/*.ref.hex` (67) | Add `#` metadata lines; **no hex-body change**. `casmexprn` also gains a derivation statement |
| `brain/reviews/2026-09-02-casm-byte-oracle-wp3-batch*.md` | Create — per-batch annotated derivation records |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | Update Ledger A states `pending` → `CANONICAL-INDEPENDENT` per signed-off batch |
| `scripts/casm_oracle_inventory.py` | Extend — read/verify `seq_sha256`/`source_sha256`/`reviewed_by` |
| `.agents/workflows/canonical-byte-oracles.md` | Note the header-field names in the metadata section |
| `brain/plans/2026-09-02-casm-byte-oracle-wp3-*.md` | Progress log |
| `brain/walkthroughs/2026-09-02-casm-byte-oracle-wp3-*.md` | Create at close |
| `wiki/tasks/casm.md`, `brain/task.md` | WP3 status |
| `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md` | Progress log |

No `cmake/GenerateCasmTestFixtures.cmake`, `CMakeLists.txt` packaging,
CASM source, `hex_manifest_to_bin.py`, or native-app manifest is touched.

## Stop Conditions

- A ref's frozen hex body would need to change to make a derivation come
  out right — that means the ref (or CASM) is actually wrong. **Stop**,
  record first differing offset + structural context, classify before
  editing either side (governing-plan mismatch rule). Do not "fix" the
  body to match.
- Native CASM output no longer `COMP`-matches a ref after a rebuild (the
  `.ref` body must be byte-stable across Batch 1).
- A derivation cannot be authored without reading CASM output / `opcodes.s`
  / a ca65 binary as the answer — the ref stays `UNCLEAR`; escalate.
- `casm_oracle_inventory --check` fails (count, packaging, or
  declared-vs-actual mismatch).
- The R6 two-base live check shows a relocation the ledger did not predict,
  or a predicted entry that does not move.
- `casmbig1`'s independent expansion does not reproduce the frozen body.
- A `.seq` generator edit lands from any other effort while WP3 is open
  (would invalidate `seq_sha256` mid-batch).
- A genuinely new defect outside WP3 scope (a circular-and-wrong ref, a
  CASM bug) — disclose and defer.
- A no-change rebuild changes any `.ref` binary or any other artifact.

## Documentation, Task, and DOX Updates

- **At approval:** Taskwarrior WP3 child under parent `75cfa082`; WP3
  active in `wiki/tasks/casm.md` + `brain/task.md`.
- **Per batch:** append this plan's Progress log; update the audit
  register's Ledger A states on sign-off.
- **At completion:** walkthrough with the consolidated verification
  evidence; register shows 67/67 `CANONICAL-INDEPENDENT`; trackers synced;
  `CHANGELOG.md` note (docs/provenance, no functional change); memory
  updated. WP6 records the final durable policy — WP3 does not touch
  `brain/KNOWLEDGE.md`.
- No user-facing `wiki/`+`docs/` manual change (no behavior change).

## Completion Gate

- Every `tests/fixtures/casm/*.ref.hex` (67) is `CANONICAL-INDEPENDENT` in
  the audit register: annotated derivation record, `seq_sha256`,
  `source_sha256`, `sha256`, and `reviewed_by: user, <date>`.
- **Zero `UNCLEAR`** remain; `casmexprn` promoted.
- Every R6 ref has a reviewed relocation ledger + a recorded live
  two-base relocation-application check.
- `casmbig1` has a reviewed repetition rule + a reproduced independent
  expansion.
- `/L` and `/M` coverage has a canonical reference or a recorded rationale.
- `casm_oracle_inventory --check` passes with the new field assertions;
  a no-change rebuild leaves every `.ref` binary byte-identical.
- Consolidated live `COMP` evidence recorded in `brain/walkthroughs/`.
- Ledgers B/C and the 32-harness map are unchanged (WP3 does not touch
  them).
- **The user explicitly approves closure.**

## Progress

- 2026-09-02: **Increment 1 (extend `casm_oracle_inventory.py`) done.**
  Added a `source_sha256` verification pass — for any ref declaring
  `# source_sha256: <seqname>=<hash>`, the script checks the hash against
  the current generated `.seq` and fails on drift. Still non-gating.
  **Design correction:** WP3 Scoping Decision 2 assumed `hex_manifest_to_bin.py`
  "ignores `#` lines" — it does **not**; it is a strict parser that
  rejects any unrecognized `# word:` directive. So the generated-`.seq`
  hash is recorded as `# source_sha256:` (already an accepted repeatable
  directive, same as the native-app manifests) rather than a new
  `# seq_sha256:` key, and the reviewer line will be plain prose
  (`# Reviewed: ...`) not a `# key:` directive. No `hex_manifest_to_bin.py`
  change — the zero-code-change intent holds.
- 2026-09-02: **Increment 2 / Batch 1a (static PRGs) — metadata added,
  derivation frozen for review.** 16 refs (`brback1`, `brfwd1`,
  `casmhello`, `casmemit1`, `casmmodes`, `casmnum2`, `casmorg1`,
  `casmcase1`, `casmmaxid1`, `casmopall`, `casmmf1/2/3`, `p1back1`,
  `p1fwd1`, `p1size1`) each gained `# source_sha256:` line(s). **All 67
  `.ref` binaries byte-identical** before/after
  `casm_reference_fixtures` + `test_image_d64` rebuild;
  `casm_oracle_inventory --check` green with the new verification.
  `casmnum2` (previously a one-line note) fully derived;
  `casmopall`/`casmmf*`/`casmhello` etc. header ledgers re-checked against
  the 6502 encoding. Record:
  `brain/reviews/2026-09-02-casm-byte-oracle-wp3-batch1a-static-derivations.md`
  — **frozen for user review**; on sign-off the reviewer line is added and
  the 16 rows flip to `CANONICAL-INDEPENDENT`.
- 2026-09-02: Plan drafted. WP2 register is the input: 66 refs
  `CANONICAL-INDEPENDENT (pending metadata)`, 1 `UNCLEAR` (`casmexprn`), 2
  manifests `NATIVE-OBSERVATION` (WP4). Three scoping decisions confirmed
  (user-as-reviewer per WP60 precedent; metadata in the `.ref.hex` header;
  re-derive `casmexprn`). Awaiting approval.
