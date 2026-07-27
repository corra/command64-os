# DASH WP2 - System Information API Task

## Task Metadata
- **Feature**: `casm-dash-wp2-system-information-api`
- **Branch**: `feature/casm-dash-wp2-system-information-api`
- **Status**: Complete
- **Parent Plan**: `brain/plans/2026-07-26-casm-dash-system-dashboard.md`
- **Plan File**: `brain/plans/2026-07-26-casm-dash-wp2-system-information-api.md`

## Objectives
1. Export `DOS_GET_SYSTEM_INFO` (`$5C`) and `DOS_GET_APP_INFO` (`$5D`) constants and error codes in KickAssembler and ca65 includes.
2. Implement read-only `ahGetSystemInfo` handler in `src/command64/api.asm`.
3. Validate `X/Y` buffer pointer (reject null/invalid buffers with `Carry=1`, `A=DOS_ERR_INVALID_ARG`, buffer unchanged).
4. Populate 24-byte system info record with OS version, video standard, RAM boundaries, VMM MCT page counts, and active app counts.
5. Add automated unit test in `tests/src/api/api.s`.
6. Update API reference documentation in `wiki/api-reference.md` and `docs/api-reference.md`.

## Sub-Tasks
- [x] Create feature branch `feature/casm-dash-wp2-system-information-api`.
- [x] Add task tracking files.
- [x] Add constants to `include/command64.inc` and `include/ca65/command64.inc`.
- [x] Implement `ahGetSystemInfo` handler in `src/command64/api.asm`.
- [x] Add unit test `test_get_system_info` in `tests/src/api/api.s`.
- [x] Build targets and pass automated test suite.
- [x] Update API reference documentation and CHANGELOG.md.
