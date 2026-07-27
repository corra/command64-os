# DASH WP3 - Application Query API Task

## Task Metadata
- **Feature**: `casm-dash-wp3-application-query-api`
- **Branch**: `feature/casm-dash-wp3-application-query-api`
- **Status**: Complete
- **Parent Plan**: `brain/plans/2026-07-26-casm-dash-system-dashboard.md`
- **Plan File**: `brain/plans/2026-07-26-casm-dash-wp3-application-query-api.md`

## Objectives
1. Export `APP_INFO_SIZE` (24) and `APP_INFO_OFF_*` constants in KickAssembler and ca65 include files.
2. Implement read-only `ahGetAppInfo` handler in `src/command64/api.asm`.
3. Validate arguments:
   - Reject slot index >= 16 with `Carry=1`, `A=DOS_ERR_INVALID_INDEX` (`$01`), buffer untouched.
   - Reject null/invalid buffer pointer with `Carry=1`, `A=DOS_ERR_INVALID_ARG` (`$04`), buffer untouched.
   - Reject uninitialized AppTable with `Carry=1`, `A=DOS_ERR_UNAVAILABLE` (`$03`), buffer untouched.
   - Reject unallocated slot with `Carry=1`, `A=DOS_ERR_SLOT_EMPTY` (`$02`), buffer untouched.
4. Populate 24-byte application record (slot index, flags, load address, size, 1-byte PETSCII name length + 15 padded name bytes).
5. Add automated unit test in `tests/src/api/api.s`.
6. Update API reference documentation in `wiki/api-reference.md` and `docs/api-reference.md`.

## Sub-Tasks
- [x] Create feature branch `feature/casm-dash-wp3-application-query-api`.
- [x] Add task tracking files.
- [x] Add constants to `include/command64.inc` and `include/ca65/command64.inc`.
- [x] Implement `ahGetAppInfo` handler in `src/command64/api.asm`.
- [x] Add unit test `test_get_app_info` in `tests/src/api/api.s`.
- [x] Build targets and pass automated test suite.
- [x] Update API reference documentation and CHANGELOG.md.
