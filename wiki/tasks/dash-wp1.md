# DASH WP1 - API Contract Freeze Task

## Task Metadata
- **Feature**: `casm-dash-wp1-api-contract-freeze`
- **Branch**: `feature/casm-dash-wp1-api-contract-freeze`
- **Status**: Complete
- **Parent Plan**: `brain/plans/2026-07-26-casm-dash-system-dashboard.md`
- **Plan File**: `brain/plans/2026-07-26-casm-dash-wp1-api-contract-freeze.md`

## Objectives
1. Freeze service numbers `$5C` (`DOS_GET_SYSTEM_INFO`) and `$5D` (`DOS_GET_APP_INFO`).
2. Reconcile all 17 plan discrepancies (pointer conventions, status codes, error buffer safety, record structures, memory ceiling, VMM page counts, app name layout, running state lifecycle, register preservation).
3. Record byte-exact layout contracts for system and application information records.
4. Document CASM-specific constraints for downstream work packages.

## Sub-Tasks
- [x] Create feature branch `feature/casm-dash-wp1-api-contract-freeze`.
- [x] Re-read DOX chain and inspect current API service definitions.
- [x] Reconcile pointer and status conventions (`X/Y` buffer pointer, `A` error code, `Carry` status, buffer unchanged on error).
- [x] Specify 24-byte System Information output record structure.
- [x] Specify 24-byte Application Information output record structure (1-byte length + 15-byte PETSCII name).
- [x] Reconcile VMM logical MCT page count semantics vs physical REU detection.
- [x] Update `brain/plans/2026-07-26-casm-dash-wp1-api-contract-freeze.md` with status `complete` and frozen contract.
- [x] Update parent plan DOX index and references.
