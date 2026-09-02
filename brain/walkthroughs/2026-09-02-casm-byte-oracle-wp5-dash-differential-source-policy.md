# Walkthrough: Byte-Oracle Transition WP5 — DASH Differential & Source-Policy Transition

Plan: `brain/plans/2026-09-02-casm-byte-oracle-wp5-dash-differential-source-policy.md`  
Parent: `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`  
Date executed: 2026-09-02  
Branch: `feature/casm-byte-oracle-wp5` · Taskwarrior task 43 (`casm.byteoracle`)

## Outcome

**DASH is fully decoupled from mandatory ca65 builds and released from dual-assembler gating:**
1. `dash_ref` is now an explicit opt-in, non-gating CMake target marked `EXCLUDE_FROM_ALL`. Default builds (`cmake --build build`) do not invoke ca65 for DASH.
2. `command64_casm_utils_d64` packages `dash.ref` from the canonical `${DASH_BIN}` (transcribed from `dash.ref.hex`), removing the dependency on `dash_ref`.
3. `scripts/build_dash_manifest.py` no longer contains `--allow-host-bytes`, strictly enforcing native CASM provenance or canonical derivations.
4. `src/external/dash/AGENTS.md` transitioned the "Dual-Assembler Subset" from a load-bearing restriction to "Optional Differential Guidance", establishing native CASM as the sole authoritative assembler for DASH.
5. User manuals and workflows (`wiki/dash-utility.md`, `docs/dash-utility.md`, `release/docs/dash-utility.md`, `.agents/workflows/overlay-build-events.md`) updated to reflect DASH 0.2.0 canonical provenance and opt-in differential verification.

## Verification & Test Results

### 1. Default Build Decoupling
```bash
$ cmake --build build
# Result: Builds all project targets cleanly without building dash_ref.
```

### 2. Opt-in Differential Verification
```bash
$ cmake --build build --target dash_ref
# Result: Assembles dash_ref.prg on host via ca65; byte-matches the canonical dash.prg (4,579 bytes).
```

### 3. Oracle Inventory & Manifest Protection
```bash
$ python3 scripts/casm_oracle_inventory.py --check
# summary: 67 .ref.hex on disk, 67 in CASM_REF_NAMES, 67 tracked, 2 native manifests
# with declared sha256: 69/69; header claims independent derivation: 69/69
# reconciliation: OK
```

### 4. Manifest Tooling Verification
```bash
$ python3 scripts/build_dash_manifest.py --help
# Confirmed: --allow-host-bytes is removed; --cross-check is an optional differential comparator.
```

## Completion Gate Status

| Gate item | Status |
| --- | --- |
| `dash_ref` is `EXCLUDE_FROM_ALL` in CMake | ✅ |
| `command64_casm_utils_d64` packages `dash.ref` from `${DASH_BIN}` | ✅ |
| `scripts/build_dash_manifest.py` removes `--allow-host-bytes` | ✅ |
| `src/external/dash/AGENTS.md` updated to Optional Differential Guidance | ✅ |
| `wiki/dash-utility.md` and mirrors updated to DASH 0.2.0 & canonical provenance | ✅ |
| `casm_oracle_inventory --check` green (69/69) | ✅ |
| Default build and opt-in `dash_ref` target verified | ✅ |
| **User approves closure** | ⏳ pending |

## Files Changed

| File | Change |
|---|---|
| `cmake/Ca65.cmake` | Added `EXCLUDE_FROM_ALL` option support in `add_ca65_app` |
| `CMakeLists.txt` | Set `dash_ref` to `EXCLUDE_FROM_ALL`; package `dash.ref` from `DASH_BIN` |
| `scripts/build_dash_manifest.py` | Removed `--allow-host-bytes` flag and updated docs |
| `src/external/dash/AGENTS.md` | Replaced load-bearing dual-assembler restriction with optional differential guidance |
| `wiki/dash-utility.md`, `docs/dash-utility.md`, `release/docs/dash-utility.md` | Updated version to 0.2.0 and provenance to native CASM 0.5.2 / canonical derivation |
| `brain/plans/2026-09-02-casm-byte-oracle-wp5-dash-differential-source-policy.md` | Updated progress log |
| `brain/walkthroughs/2026-09-02-casm-byte-oracle-wp5-dash-differential-source-policy.md` | Created — Completion walkthrough |
