# Walkthrough: Byte-Oracle Transition WP4 — Native-Application Canonical Records

Plan: `brain/plans/2026-09-02-casm-byte-oracle-wp4-native-app-canonical-records.md`  
Parent: `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`  
Date executed: 2026-09-02  
Branch: `feature/casm-byte-oracle-wp4` · Taskwarrior task 42 (`casm.byteoracle`)

## Outcome

**Both CASM-native external application manifests (`BANNER.PRG` and `DASH.PRG`) are promoted to `CANONICAL-INDEPENDENT`.**
Every application manifest is backed by:
1. An independent byte and address extent ledger.
2. A full R6 relocation eligibility ledger with sorted offsets and footer derivation.
3. Multi-base relocation verification across multiple target load bases.
4. Bound source SHA-256 hashes and reviewer sign-off annotations.
5. 100% byte-identical shipping PRG binaries (`hex_manifest_to_bin.py` output unchanged).

## Derivations & Verifications

| Application | Sources | Extent | Relocations | Derivation Record | Binary SHA-256 |
|---|---|---|---|---|---|
| **BANNER** | `banner.s` (1 source) | 1,011 B | 20 entries | `brain/reviews/2026-09-02-casm-byte-oracle-wp4-banner-derivation.md` | `b43415c1d619...` |
| **DASH** | `dmain.s`, `dscr.s`, `dfmt.s`, `dsys.s`, `dapp.s`, `dvmm.s`, `ddata.s` (7 sources) | 4,579 B | 451 entries | `brain/reviews/2026-09-02-casm-byte-oracle-wp4-dash-derivation.md` | `3b4d0693a641...` |

### Multi-Base Relocation Confirmation
- **BANNER**: Relocated to `$5000` (+28 pages); all 20 address references mapped cleanly to `$50xx..$53xx`.
- **DASH**: Relocated to `$3800` (+4 pages), `$5000` (+28 pages), and `$9000` (+92 pages); all 451 address references mapped strictly into their target relocated page spans with zero outliers.

## Machine Verification

```bash
$ python3 scripts/casm_oracle_inventory.py --check
# summary: 67 .ref.hex on disk, 67 in CASM_REF_NAMES, 67 tracked, 2 native manifests
# with declared sha256: 69/69; header claims independent derivation: 69/69
# reconciliation: OK

$ cmake --build build
# Built all targets cleanly; zero byte drift in generated PRGs
```

## Completion Gate Status

| Gate item | Status |
| --- | --- |
| BANNER independent derivation record created (`brain/reviews/`) | ✅ |
| DASH independent derivation record created (`brain/reviews/`) | ✅ |
| BANNER header contains source SHA-256, artifact SHA-256, and reviewer attribution | ✅ |
| DASH header contains all 7 source SHA-256s, artifact SHA-256, and reviewer attribution | ✅ |
| Audit register Ledger A updated: both manifests `CANONICAL-INDEPENDENT` | ✅ |
| `casm_oracle_inventory --check` passes cleanly (69/69) | ✅ |
| Multi-base relocation verified for both apps | ✅ |
| No change to shipping binary bytes or build behavior | ✅ |
| **User approves closure** | ✅ user-approved 2026-09-02 |

## Files Changed

| File | Change |
|---|---|
| `brain/reviews/2026-09-02-casm-byte-oracle-wp4-banner-derivation.md` | Created — BANNER derivation record |
| `brain/reviews/2026-09-02-casm-byte-oracle-wp4-dash-derivation.md` | Created — DASH derivation record |
| `src/external/banner/banner.ref.hex` | Added reviewer attribution line |
| `src/external/dash/dash.ref.hex` | Added reviewer attribution line |
| `scripts/casm_oracle_inventory.py` | Added native manifest source and derivation checks |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | Promoted manifests to `CANONICAL-INDEPENDENT` |
| `brain/plans/2026-09-02-casm-byte-oracle-wp4-native-app-canonical-records.md` | Updated progress log |
