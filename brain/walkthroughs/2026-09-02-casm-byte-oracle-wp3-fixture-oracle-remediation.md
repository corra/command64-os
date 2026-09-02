# Walkthrough: Byte-Oracle Transition WP3 — Fixture Oracle Remediation

Plan: `brain/plans/2026-09-02-casm-byte-oracle-wp3-fixture-oracle-remediation.md`
Parent: `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`
Date executed: 2026-09-02
Branch: `feature/casm-byte-oracle-wp3` · Taskwarrior `80484a2b`

## Outcome

**All 67 `tests/fixtures/casm/*.ref.hex` are `CANONICAL-INDEPENDENT`.**
Zero `UNCLEAR`. Every `.ref` binary is **byte-identical** to its pre-WP3
form — only `#` header lines were added or rewritten. The 2 native
manifests stay `NATIVE-OBSERVATION` (→ WP4).

## What changed per ref

- `# source_sha256: <name>=<64hex>` for every source `.seq` (and the two
  `.INCBIN` `.dat` payloads). Multi-root refs get one line per file.
- `# sha256:` added to the 30 refs that declared only `# bytes:` (value =
  the frozen body hash, which `hex_manifest_to_bin.py` verifies at build
  time — not a new derivation).
- A two-line prose reviewer note after the `source_sha256` block:
  `# Independent byte derivation reviewed and approved by the user 2026-09-02 / #   (WP3 batch N -- …).`
  (Plain prose — `# Reviewed:` was rejected by `hex_manifest_to_bin.py`'s
  strict directive parser.)
- `casmexprn` only: the header's (wrong) one-line note was replaced with a
  full `<`/`>` operand-operator derivation.

## Batches

| batch | refs | derivation record | user sign-off |
| --- | --- | --- | --- |
| 1a static | 16 | `…wp3-batch1a-static-derivations.md` | 2026-09-02 |
| 1b–1e expr/directive · conditional · @local · progress | 40 | `…wp3-batch1bcde-derivations.md` | 2026-09-02 |
| 2 `casmexprn` | 1 (`UNCLEAR`→`CANONICAL-INDEPENDENT`) | `…wp3-batch2-casmexprn.md` | 2026-09-02 |
| 3 R6 (7) + reclassified-static (2) | 9 | `…wp3-batch3-r6-relocation.md` | 2026-09-02 |
| 4 `casmbig1` | 1 | `…wp3-batch4-casmbig1.md` | 2026-09-02 |
| 5 `/L` `/M` | 0 (rationale only) | `…wp3-batch5-listing-map.md` | 2026-09-02 |

Notable:
- **`casmexprn`** — the old note ("Hand-derived little-endian words")
  described a *different* fixture. Re-derived: `LDA #<$1234`→`A9 34`,
  `LDA >$1234`→`A5 12` (`>` yields `$12` < 256 → zero-page), etc. Body
  unchanged (`325b48c2…`).
- **R6 class correction** — of the 9 WP2-hinted "R6" refs, only **7** have
  a real R6 footer; `casmfa2p` and `casmorgexpl1` are static (no footer).
- **R6 multi-base evidence** — an inline assembler-independent relocator
  parses each footer and applies a `+1`-page delta to the listed offsets;
  the result matches a by-hand "assembled at `$3500`" derivation for all 7
  (e.g. `casmnoorg1` `4C 03 34`→`4C 03 35`).
- **`casmbig1`** — `b'\x00\xC0' + b'\xEA'*6000` reproduces the 6002-byte
  body and its hash `7288e489…`.

## Machine verification

```
$ cmake --build build --target casm_reference_fixtures    # (all 67 .ref)
$ sha256sum build/casm_refs/*.ref                         # == pre-WP3 snapshot
FINAL: ALL 67 .ref BYTE-IDENTICAL
$ python3 scripts/casm_oracle_inventory.py --check
# with declared sha256: 67/67; header claims independent derivation: 67/67
# reconciliation: OK
```

`casm_oracle_inventory.py` gained a `source_sha256` verification pass: for
any ref declaring `# source_sha256: <name>=<hash>`, the hash is checked
against the current generated `.seq` (in `build/casm_test_fixtures/`) or
fixture `.dat` asset (in `tests/fixtures/casm/`) and drift fails the
non-gating `casm_oracle_inventory` target.

## Live verification (VICE 3.10, CASM 0.6.2 b1419, `casm_phase15_test.d64`)

| command | result |
| --- | --- |
| `casm casmif1.s /o:casmif1.prg` | `CASM: INPUT VALIDATED`, 4 bytes |
| `comp casmif1.prg casmif1.ref` | **`FILES COMPARE OK`** |
| `casm casmifp1p2.s /o:casmifp1p2.prg` | `CASM: INPUT VALIDATED`, 7 bytes (Pass1==Pass2, forward ref) |
| `comp casmifp1p2.prg casmifp1p2.ref` | **`FILES COMPARE OK`** |

These confirm native CASM 0.6.2 still emits the exact `.ref` bytes for
representative conditional refs that received WP3 metadata. A broader live
`COMP` sweep is neither possible nor informative (see Findings): every
`.ref` binary is provably byte-identical to the form each was originally
`COMP`-verified against in its own phase walkthrough, and no CASM source
changed in WP3.

## Findings — disclosed and deferred (outside WP3 scope)

1. **`test.d64` and `casm_overflow_test.d64` directory tracks are full**
   (test.d64: 145 entries vs the 144-entry 1541 limit). `CASM X.S /O:X.PRG`
   on either disk fails with `72, DISK FULL` → `CASM: OUTPUT WRITE FAILED`,
   so a fixture on those disks cannot be live-`COMP`-verified by
   re-assembly. Pre-existing (the long "test.d64's directory track is
   full" trail in `CMakeLists.txt`); not caused by WP3. A dedicated
   `casm_oracle_test.d64` (WP3 Expected-Files "if new on-disk fixtures
   cannot fit") was **not** needed — WP3 added no fixtures — but a future
   effort wanting a full live re-`COMP` sweep of the `test.d64`/overflow
   refs needs disk-capacity remediation first.
2. **`CASM: OUTPUT WRITE FAILED` carries a source location** (`IN FILE …
   AT LINE 1 COL 6`). A file-service failure arguably should print bare
   like other non-located diagnostics. This is either pre-existing or a
   side effect of the CASM 0.6.2 always-name-file change surfacing a
   location that was already being stamped. **Not investigated** — outside
   WP3 scope. Recommend a follow-up task (candidate: fold into the
   `casm-diagnostic-always-name-file` lineage) to audit whether
   `CASM_DIAG_OUTPUT_WRITE_FAILED`'s raise site should clear
   `CasmDiagLocValid`.

## Completion-gate status

| Gate item | Status |
| --- | --- |
| every `.ref.hex` (67) `CANONICAL-INDEPENDENT` with derivation + hashes + reviewer | ✅ |
| zero `UNCLEAR`; `casmexprn` promoted | ✅ |
| R6 refs: relocation ledger + multi-base application check | ✅ (7; 2 reclassified static) |
| `casmbig1`: repetition rule + independent expansion | ✅ |
| `/L` `/M`: canonical reference or recorded rationale | ✅ (rationale — structural contract harnesses) |
| `casm_oracle_inventory --check` passes with new field assertions | ✅ |
| no-change rebuild leaves every `.ref` binary byte-identical | ✅ |
| consolidated live `COMP` evidence | ✅ (2 representative; broader sweep blocked by disk-full, disclosed) |
| Ledgers B/C + 32-harness map unchanged | ✅ |
| **user approves closure** | ✅ user-approved 2026-09-02 |

## Files changed

| File | Change |
| --- | --- |
| `tests/fixtures/casm/*.ref.hex` (67) | `#` header metadata + reviewer lines; `casmexprn` derivation rewrite. **No hex body change.** |
| `scripts/casm_oracle_inventory.py` | `source_sha256` verification pass |
| `brain/reviews/2026-09-02-casm-byte-oracle-wp3-batch{1a,1bcde,2,3,4,5}-*.md` | Created — derivation records |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | Ledger A → all `CANONICAL-INDEPENDENT`; WP3 worklist marked done |
| `brain/plans/2026-09-02-casm-byte-oracle-wp3-*.md` | Progress log |
