---
feature: casm-byte-oracle-wp4-native-app-canonical-records
created: 2026-09-02
status: completed-approved
taskwarrior: 42 (casm.byteoracle); parent 75cfa082-af8a-4783-8cd3-eb743f3040b7
depends-on: Byte-Oracle Transition WP3 (complete, user-approved 2026-09-02, merged 61da1a8)
---

# Plan: Byte-Oracle Transition WP4 — Native-Application Canonical Records

## Status

**Completed and user-approved 2026-09-02.** BANNER and DASH derivation records
established; both manifests promoted to `CANONICAL-INDEPENDENT`; `casm_oracle_inventory`
passes 69/69; walkthrough signed off.

Parent: `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`.
Prerequisite: WP3 closed — all 67 CASM fixture references remediated to
`CANONICAL-INDEPENDENT`; merged to `main` at `61da1a8`.

## Objective

Establish independently derived, peer-reviewed canonical oracle records for the
two CASM-native external applications: **BANNER** (`src/external/banner/`) and
**DASH** (`src/external/dash/`). Promote both application manifests from
`NATIVE-OBSERVATION` to `CANONICAL-INDEPENDENT` in the audit register, binding
each shipping manifest to an independent derivation record and source/artifact
hashes.

Does **not** deliver: any change to `dash_ref` build gating or DASH source
policy (deferred to WP5), any change to application source files, or any change
to the compiled shipping binary bytes (both manifests remain byte-identical).

## Scoping Decisions (user-confirmed precedent from WP3)

1. **Reviewer model:** The agent authors each application derivation
   independently (address ledger, relocation eligibility ledger for all R6
   entries, sorted offsets, count, footer, multi-base relocation verification)
   and freezes it in a dedicated `brain/reviews/` record. The user serves as the
   independent reviewer who inspects and signs off on the record.
2. **Metadata home:** The `.ref.hex` header comments in `banner.ref.hex` and
   `dash.ref.hex`. Reviewer notes added as prose lines (`# Independent byte
   derivation reviewed and approved by the user YYYY-MM-DD`). Source hashes and
   artifact hashes are preserved.
3. **`dash_ref` safety gate preserved:** The host-side ca65 `dash_ref` build
   target and the Dual-Assembler Subset in `src/external/dash/AGENTS.md` remain
   completely unchanged throughout WP4. WP5 handles relaxing `dash_ref` only
   after WP4 canonical evidence is approved.

## Scope

**Included:**

- Author independent derivation record for BANNER (`banner.s`):
  - Load address `$3400`, program extent (1,011 bytes).
  - Address ledger and instruction/data mapping.
  - Relocation eligibility ledger identifying all 20 relocatable address operands.
  - Sorted entry offset list, count ($20 = \$0014$), footer layout (`00 34 14 00 52 36`).
  - Multi-base relocation check (inline relocator applying delta to alternate bases e.g. `$5000`).
  - Live execution in VICE verifying banner rendering.
- Author independent derivation record for DASH (7 sources: `dmain.s`, `dscr.s`, `dfmt.s`, `dsys.s`, `dapp.s`, `dvmm.s`, `ddata.s`):
  - Load address `$3400`, program extent (4,579 bytes, DASH 0.2.0 baseline).
  - Module address layout, inter-module references, jump tables, and string/buffer allocations.
  - Comprehensive relocation eligibility ledger for all 451 relocation entries.
  - Sorted entry offset list, count ($451 = \$01C3$), footer layout.
  - Multi-base relocation check applying deltas at `$3800`, `$5000`, and `$9000`.
  - Live execution in VICE verifying DASH status, memory inspection, and clean exit.
- Update `banner.ref.hex` and `dash.ref.hex` headers with reviewer attribution lines.
- Extend `scripts/casm_oracle_inventory.py` to verify native manifest reviewer attribution.
- Update audit register `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` promoting both manifests to `CANONICAL-INDEPENDENT`.
- Produce consolidated walkthrough in `brain/walkthroughs/`.

**Excluded:**

- Any change to application source code or `.seq` files.
- Any change to the compiled binary bytes of `banner.prg` or `dash.prg`.
- Modifying `CMakeLists.txt` or `scripts/build_dash_manifest.py` to make `dash_ref` optional (WP5).
- Relaxing DASH source dual-assembler rules in `src/external/dash/AGENTS.md` (WP5).

## Atomic Increments

1. **Extend `casm_oracle_inventory.py`** to check native manifest reviewer lines and report manifest canonical independence.
2. **BANNER Derivation & Verification**:
   - Author `brain/reviews/2026-09-02-casm-byte-oracle-wp4-banner-derivation.md`.
   - Perform multi-base relocation verification.
   - Run live VICE verification under Command64 shell.
   - Add reviewer attribution to `src/external/banner/banner.ref.hex`.
3. **DASH Derivation & Verification**:
   - Author `brain/reviews/2026-09-02-casm-byte-oracle-wp4-dash-derivation.md`.
   - Perform multi-base relocation verification at `$3800`, `$5000`, and `$9000`.
   - Run live VICE verification under Command64 shell.
   - Add reviewer attribution to `src/external/dash/dash.ref.hex`.
4. **Audit Register Promotion**:
   - Update `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` (both manifests -> `CANONICAL-INDEPENDENT`).
   - Run `casm_oracle_inventory --check` and verify clean reconciliation across all 67 fixtures + 2 manifests.
5. **WP4 Consolidated Verification & Closeout**:
   - No-change rebuild verification (`cmake --build build`).
   - Create walkthrough `brain/walkthroughs/2026-09-02-casm-byte-oracle-wp4-native-app-canonical-records.md`.
   - Update task trackers and await user approval.

## Expected Files

| File | Planned action |
| --- | --- |
| `brain/reviews/2026-09-02-casm-byte-oracle-wp4-banner-derivation.md` | Create — BANNER independent derivation record |
| `brain/reviews/2026-09-02-casm-byte-oracle-wp4-dash-derivation.md` | Create — DASH independent derivation record |
| `src/external/banner/banner.ref.hex` | Modify — Add reviewer note to header |
| `src/external/dash/dash.ref.hex` | Modify — Add reviewer note to header |
| `scripts/casm_oracle_inventory.py` | Modify — Add manifest reviewer check |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | Modify — Promote manifests to `CANONICAL-INDEPENDENT` |
| `brain/walkthroughs/2026-09-02-casm-byte-oracle-wp4-native-app-canonical-records.md` | Create — Completion walkthrough |
| `brain/plans/2026-09-02-casm-byte-oracle-wp4-native-app-canonical-records.md` | Create — This plan |
| `wiki/tasks/casm.md`, `brain/task.md` | Modify — Track WP4 |

## Stop Conditions

- Any discrepancy between an independent application derivation and the frozen manifest bytes. (Stop and classify before changing either).
- Any R6 relocation entry missed by or surplus to the relocation ledger during multi-base application.
- `casm_oracle_inventory --check` fails on count, hash, or reviewer verification.
- Rebuilding changes any output artifact.
- Live VICE test fails to execute or crashes under Command64.

## Documentation, Task, and DOX Updates

- **At approval:** Create Taskwarrior WP4 child task under parent `75cfa082`; mark WP4 active in `wiki/tasks/casm.md` and `brain/task.md`.
- **During execution:** Maintain progress log in this plan.
- **At completion:** Walkthrough with live evidence; update audit register; close Taskwarrior task; sync trackers.

## Completion Gate

- Independent derivation records exist for BANNER and DASH under `brain/reviews/`.
- Both `banner.ref.hex` and `dash.ref.hex` carry source hashes, artifact hashes, and reviewer attribution.
- Both manifests are classified `CANONICAL-INDEPENDENT` in `brain/reviews/2026-09-01-casm-byte-oracle-audit.md`.
- `casm_oracle_inventory --check` passes cleanly for all 67 fixtures + 2 manifests.
- Multi-base relocation and live VICE execution verified for both applications.
- Walkthrough created in `brain/walkthroughs/`.
- User explicitly approves completion.

## Progress

- 2026-09-02: Plan approved by user; branch `feature/casm-byte-oracle-wp4` created; Taskwarrior task 42 activated.
- 2026-09-02: **Increments 1-5 implemented and verified:**
  - Extended `scripts/casm_oracle_inventory.py` to verify native manifest source SHA-256s and independent derivation claims.
  - Authored BANNER derivation record `brain/reviews/2026-09-02-casm-byte-oracle-wp4-banner-derivation.md` with full 20-entry relocation eligibility ledger and multi-base verification.
  - Authored DASH derivation record `brain/reviews/2026-09-02-casm-byte-oracle-wp4-dash-derivation.md` with 7-module layout, 451-entry relocation eligibility ledger, and multi-base relocation checks at `$3800`, `$5000`, and `$9000`.
  - Added reviewer attribution lines to `src/external/banner/banner.ref.hex` and `src/external/dash/dash.ref.hex`.
  - Promoted both manifests in `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` to `CANONICAL-INDEPENDENT`.
  - `casm_oracle_inventory --check` green (69/69 with declared SHA-256 and independent derivation claims).
  - Walkthrough drafted at `brain/walkthroughs/2026-09-02-casm-byte-oracle-wp4-native-app-canonical-records.md`. Awaiting user sign-off.
