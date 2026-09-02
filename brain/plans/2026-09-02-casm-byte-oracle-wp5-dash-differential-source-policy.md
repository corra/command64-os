---
feature: casm-byte-oracle-wp5-dash-differential-source-policy
created: 2026-09-02
status: approved-in-progress
taskwarrior: TBD (created on approval)
depends-on: Byte-Oracle Transition WP4 (complete, user-approved 2026-09-02, merged b39459c)
---

# Plan: Byte-Oracle Transition WP5 — DASH Differential & Source-Policy Transition

## Status

**Approved, in progress** (per front matter). Drafted 2026-09-02.

Parent: `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`.
Prerequisite: WP4 closed then **audit-corrected 2026-09-02** — BANNER's
manifest is `CANONICAL-INDEPENDENT`; **DASH's manifest bytes are
`NATIVE-OBSERVATION`** (a full byte derivation of 3,669 bytes is not
practical), with an independently-verified R6 relocation ledger. This
changes WP5's framing (see Scoping Decision 2 and the correction note
below) but not its mechanical scope.

> **Correction note 2026-09-02.** WP5's original text called the on-disk
> `dash.ref` a "canonical oracle". It is not — it is the reviewed shipping
> artifact (native-observation provenance for the code bytes). WP5's
> decoupling of `dash_ref` from `ALL` / configure / the utility-disk hard
> dependency is still correct, **but** because DASH's bytes are not
> `CANONICAL-INDEPENDENT`, the `dash_ref` ca65 differential is retained as
> a **standing release-verification check** (run by the release process,
> a mismatch is a blocker) for as long as DASH stays in the shared syntax
> subset — not merely an "optional nicety". See
> `brain/reviews/2026-09-02-casm-byte-oracle-wp4-dash-derivation.md` and
> `src/external/dash/AGENTS.md`.

## Objective

Decouple DASH from mandatory ca65 build and release gating:
1. Make the host-side `dash_ref` ca65 target explicitly opt-in and non-gating (`EXCLUDE_FROM_ALL`).
2. Decouple `command64_casm_utils_d64` and production image builds from `dash_ref`. On `command64_casm_utils.d64`, package `dash.ref` from the reviewed native canonical artifact (`dash.prg`) rather than requiring a ca65 build.
3. Update `scripts/build_dash_manifest.py` to remove `--allow-host-bytes` and treat `--cross-check` as optional, labelled differential evidence.
4. Update `src/external/dash/AGENTS.md` to transition the "Dual-Assembler Subset" from a load-bearing requirement into "Optional Differential Guidance".
5. Reconcile user-facing and workflow documentation (`wiki/dash-utility.md`, `docs/dash-utility.md`, `release/docs/dash-utility.md`, `.agents/workflows/overlay-build-events.md`).

Does **not** deliver: any gratuitous source rewrites of DASH (DASH sources remain stable `0.2.0`), or removing ca65/ld65 where required for CASM itself or other external applications.

## Scoping Decisions (user-confirmed in governing plan)

1. **`dash_ref` becomes opt-in:** `dash_ref` remains available for developers who specifically request `cmake --build build --target dash_ref`, but is excluded from `all` and from disk image dependencies.
2. **Utility disk packaging:** `command64_casm_utils_d64` packages `dash.ref` from `${DASH_BIN}` (transcribed from the reviewed `dash.ref.hex` manifest) instead of the ca65 `dash_ref.prg`. This makes the on-disk `dash.ref` the **reviewed shipping artifact** for an on-C64 `COMP DASH.PRG DASH.REF` sanity check — it is native-observation provenance, not a canonical oracle. The `dash_ref` ca65 differential stays the standing independent corroboration (run by the release process).
3. **No host-bytes override:** `build_dash_manifest.py` removes `--allow-host-bytes` completely. Shipped manifests must strictly represent native CASM execution.
4. **Source policy relaxation:** DASH source syntax follows native CASM semantics. If future DASH features adopt CASM-only syntax that ca65 rejects, `dash_ref` may cease to build without constituting a defect.

## Scope

**Included:**

- `CMakeLists.txt`:
  - Mark `dash_ref` target with `EXCLUDE_FROM_ALL` so it does not build during `cmake --build build` unless explicitly targeted.
  - In `command64_casm_utils_d64`, package `dash.ref` from `${DASH_BIN}` (transcribed from `dash.ref.hex`) instead of `${CMAKE_BINARY_DIR}/dash_ref.prg`.
  - Remove `add_dependencies(command64_casm_utils_d64 dash_ref)`.
  - Provide a standalone opt-in target (e.g. `dash_diff_check`) or keep `dash_ref` for differential verification.
- `scripts/build_dash_manifest.py`:
  - Remove `--allow-host-bytes` option and logic.
  - Update comments and docstrings to reflect canonical oracle policy.
- `src/external/dash/AGENTS.md`:
  - Replace "Dual-Assembler Subset (load-bearing — pending WP5 relaxation)" with "Optional Differential Guidance".
  - Clarify that DASH source authority is native CASM.
- `.agents/workflows/overlay-build-events.md`:
  - Update description of DASH build events to reflect canonical manifest transcription vs opt-in `dash_ref`.
- Documentation & mirrors:
  - Update `wiki/dash-utility.md`, `docs/dash-utility.md`, and `release/docs/dash-utility.md` byte-identically.
  - Update `packaging/RELEASE_README.md` if referencing `dash.ref`.

**Excluded:**

- Any change to DASH source files (`dmain.s`, `dscr.s`, `dfmt.s`, `dsys.s`, `dapp.s`, `dvmm.s`, `ddata.s`).
- Any change to the compiled bytes of `dash.prg` (4,579 bytes, SHA-256 `3b4d0693a641...`).
- Removing ca65 toolchain from CMake (ca65 is still used for CASM host build, debug, and other non-native apps).

## Atomic Increments

1. **Manifest Tooling Cleanup (`scripts/build_dash_manifest.py`)**:
   - Remove `--allow-host-bytes`.
   - Update help text and documentation.
2. **CMake Decoupling (`CMakeLists.txt`)**:
   - Set `dash_ref` as `EXCLUDE_FROM_ALL`.
   - Decouple `command64_casm_utils_d64` from `dash_ref` by packaging `dash.ref` from `${DASH_BIN}`.
   - Verify `cmake --build build` succeeds and builds all images without invoking ca65 for DASH.
   - Verify `cmake --build build --target dash_ref` still works as an explicit opt-in check.
3. **DOX & Workflow Updates**:
   - Update `src/external/dash/AGENTS.md` (remove load-bearing restriction, add optional differential guidance).
   - Update `.agents/workflows/overlay-build-events.md`.
   - Update `wiki/dash-utility.md`, `docs/dash-utility.md`, and `release/docs/dash-utility.md`.
4. **Verification & Completion Gate**:
   - Run `casm_oracle_inventory --check`.
   - Full build test (`cmake --build build`).
   - Opt-in `dash_ref` test (`cmake --build build --target dash_ref`).
   - Create completion walkthrough `brain/walkthroughs/2026-09-02-casm-byte-oracle-wp5-dash-differential-source-policy.md`.
   - Update trackers and await user approval.

## Expected Files

| File | Planned action |
| --- | --- |
| `scripts/build_dash_manifest.py` | Modify — Remove `--allow-host-bytes` |
| `CMakeLists.txt` | Modify — Make `dash_ref` opt-in and decouple `command64_casm_utils_d64` |
| `src/external/dash/AGENTS.md` | Modify — Update source policy from dual-assembler to differential |
| `.agents/workflows/overlay-build-events.md` | Modify — Update DASH build event documentation |
| `wiki/dash-utility.md`, `docs/dash-utility.md`, `release/docs/dash-utility.md` | Modify — Reconcile DASH build/provenance docs |
| `brain/plans/2026-09-02-casm-byte-oracle-wp5-dash-differential-source-policy.md` | Create — This plan |
| `brain/walkthroughs/2026-09-02-casm-byte-oracle-wp5-dash-differential-source-policy.md` | Create — Completion walkthrough |
| `wiki/tasks/casm.md`, `brain/task.md` | Modify — Track WP5 |

## Stop Conditions

- Any change to the compiled binary bytes of `dash.prg` or `command64_casm_utils.d64`.
- `cmake --build build` fails or attempts to require `dash_ref` during default builds.
- Opt-in `dash_ref` target fails to build or diverges from `dash.prg` while source remains in shared subset.
- `casm_oracle_inventory --check` fails.

## Documentation, Task, and DOX Updates

- **At approval:** Create Taskwarrior WP5 child task under parent `75cfa082`; mark WP5 active in `wiki/tasks/casm.md` and `brain/task.md`.
- **During execution:** Maintain progress log in this plan.
- **At completion:** Walkthrough with live evidence; update docs; close Taskwarrior task; sync trackers.

## Completion Gate

- `dash_ref` is `EXCLUDE_FROM_ALL` and not built during default `cmake --build build`.
- `command64_casm_utils_d64` packages `dash.ref` from `${DASH_BIN}` without depending on `dash_ref`.
- `scripts/build_dash_manifest.py` has no `--allow-host-bytes` option.
- `src/external/dash/AGENTS.md` documents native CASM authority and optional differential guidance.
- User documentation and workflow documents are synchronized.
- Default build and opt-in `dash_ref` build verified.
- Walkthrough created in `brain/walkthroughs/`.
- User explicitly approves completion.

## Progress

- 2026-09-02: Plan approved by user; branch `feature/casm-byte-oracle-wp5` created; Taskwarrior task 43 activated.
- 2026-09-02: **Increments 1-4 implemented and verified:**
  - `scripts/build_dash_manifest.py`: Removed `--allow-host-bytes` flag and updated help documentation.
  - `cmake/Ca65.cmake`: Extended `add_ca65_app` with `EXCLUDE_FROM_ALL` option.
  - `CMakeLists.txt`: Set `dash_ref` to `EXCLUDE_FROM_ALL`; decoupled `command64_casm_utils_d64` by packaging `dash.ref` directly from `${DASH_BIN}` and depending on `dash`.
  - `src/external/dash/AGENTS.md`: Transistioned "Dual-Assembler Subset" to "Optional Differential Guidance".
  - `wiki/dash-utility.md`, `docs/dash-utility.md`, `release/docs/dash-utility.md`: Updated to DASH 0.2.0 and canonical derivation / provenance.
  - `casm_oracle_inventory --check` verified green (69/69).
  - Walkthrough created at `brain/walkthroughs/2026-09-02-casm-byte-oracle-wp5-dash-differential-source-policy.md`. Awaiting user sign-off.
