# WP3 Batch 5 — Listing (`/L`) and Map (`/M`) Coverage

Status: **Frozen for user review.**
Branch: `feature/casm-byte-oracle-wp3` · Plan:
`brain/plans/2026-09-02-casm-byte-oracle-wp3-fixture-oracle-remediation.md`

## Question

The WP1 "Listing/map" oracle class: *"Canonical text/record layout where
output is contractual, otherwise a focused structural harness plus
rationale; never infer correctness from PRG identity alone."* WP3 Batch 5
determines which applies.

## Finding — the structural harness IS the canonical contract

`/L` and `/M` output is **not** verified by inferring from PRG identity.
It has dedicated contract harnesses that assert the exact record/column
layout directly:

| output | contract harness | what it pins |
| --- | --- | --- |
| `/L` listing | `test_casm_flist` (`casm_listing_test.d64`) | the frozen listing record layout — `CasmListingRecord*` field widths, the 40-column row form, the address/bytes/source columns; the WP59 contract matrix `brain/reviews/2026-08-11-casm-phase11-wp59-increment1-contract-matrix.md` is its written spec |
| `/L` metadata / header | `test_casm_flmeta` (9 cases) | listing header + metadata fields (filename cap, counts) |
| `/L` capacity / write | `test_casm_listcap`, `test_casm_listwrite`, `test_casm_listing` | overflow behavior, on-disk write, in-memory rendering |
| `/M` symbol map | `test_casm_map` (25 cases) | the deterministic symbol-map record layout, `<owner>@<local>` rendering, `mapValidateRecord` per-field checks |
| `/L` + `/M` determinism | `brain/reviews/2026-08-12-casm-phase11-wp61-increment3-determinism-listing-map.md` | repeated runs produce identical listing + map |

These harnesses build the record structures from CASM modules and assert
field-by-field — a structural contract, exactly the form the WP1 class
permits. They are **already** treated as the authoritative check for
listing/map output.

## Ledger-A listing/map refs are PRG oracles, correctly

`casmifL1.ref` (`00 C0 EA`) and `casmifM1.ref` (`00 C0 A9 01`) are
**PRG-byte** oracles for the *assembled output* of a conditional fixture —
they prove `/L` on a skipped line and `/M` non-leak of a skipped-block
symbol **do not change the emitted bytes**. They are not, and should not
be, listing-text oracles; the text side is `test_casm_flist` /
`test_casm_map`. Both were promoted to `CANONICAL-INDEPENDENT` in Batch
1c on that basis.

## Disposition

**No new canonical listing/map reference is created.** Rationale
(recorded in the audit register): `/L` and `/M` output is contractual
text pinned field-by-field by dedicated structural harnesses
(`test_casm_flist` + WP59 contract matrix, `test_casm_flmeta`,
`test_casm_map`) and a determinism witness — not inferred from PRG
identity. This satisfies the WP1 Listing/map oracle class.

## Feature-matrix update

The audit register's `listing /L output` and `symbol map /M output` rows
change from "WP3 confirms a canonical layout row exists" to **"covered —
structural contract harness `test_casm_flist` / `test_casm_map` +
determinism witness; rationale in this record."**

## Reviewer sign-off

Nothing to add to any `.ref.hex`. On user approval this record is linked
from the audit register's Listing/map matrix rows.
