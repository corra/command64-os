# COMP CASM-Native Increment 4 - Manifest and Build Transition

Date: 2026-09-02
Plan: `brain/plans/2026-09-02-comp-casm-native-migration.md`
Taskwarrior: `74845ecf-9e39-4253-8e78-6dfb4104d635` (task 42, project `comp`)
Status: completion candidate; Increment 4 gate approval pending

## Summary

COMP now ships from the reviewed hex manifest `src/external/comp/comp.ref.hex`
(same model as BANNER / LABEL / DASH). The ca65/ld65 build path is fully
removed. `${COMP_TARGET}` and the target name `comp` are unchanged, so every
disk image that packaged COMP still resolves to the new artifact with no
per-disk rewiring. A full `cmake --build build` is clean.

## Deliverables

### `scripts/build_comp_manifest.py` (new)

Single-file transcription tool, twin of `build_label_manifest.py`. Takes a
reviewed native PRG + `--provenance` string, writes `comp.ref.hex` with byte
count, artifact SHA-256, and one `source_sha256` line per COMP input. It is a
deliberate human act after a reviewed native run, never a build step. COMP
emits no version banner, so - unlike LABEL - there is no generated version
source; source inputs are `comp.s` and `BUILD_COMP` (the latter frozen at its
final ca65-era value `1006`, recorded so a stray edit still hard-fails).

### `src/external/comp/comp.ref.hex` (new)

- `bytes: 1228`
- `sha256: 1a0bfbf7be31a9c2844ea3ae2bfe56084f9f90571631bbe7ff212d89eec528e8`
- `source_sha256: comp.s=597b6237d9a6cbeac07216f598d60f00380aa02fc3193fde5585c922cacf6ed7`
- `source_sha256: BUILD_COMP=cc3c12ca393807ee1b8c68f2df8719037e4bd144205bfc44133950dcb823b6b0`
- provenance: native CASM 0.6.2 build 1419 on `command64_comp_test.d64`,
  byte-identical to `src/external/comp/comp-derivation.md`; `casm_r6_verify.py`
  PASS at `$3800`/`$5000`/`$9000`; CANONICAL-INDEPENDENT.

Correctness authority remains the peer-reviewed derivation record, not this
manifest. `hex_manifest_to_bin.py` round-trips it to the exact native bytes.

### CMakeLists.txt

- Removed `file(GLOB_RECURSE COMP_SRCS ...)` and `set(COMP_ENTRY ...)`;
  replaced with a comment noting COMP is CASM-native.
- Replaced the `# 3d. COMP` `add_ca65_app(comp ...)` / `Ca65_FOUND` /
  ca65-not-found `FATAL_ERROR` block with a pointer comment (same shape as the
  earlier LABEL migration).
- Added the COMP production target next to LABEL's: an `add_custom_command`
  running `hex_manifest_to_bin.py <comp.ref.hex> <comp.prg> --source-dir
  src/external/comp`, `DEPENDS` on the manifest, the script, `comp.s` and
  `BUILD_COMP`; `add_custom_target(comp ALL ...)`;
  `set_target_properties(comp PROPERTIES C64_PRG_PATH ...)`;
  `set(COMP_TARGET comp)` (moved here from its old location - its first
  consumer, `IMAGE_BASE_PRG_TARGETS`, is defined below this point).
- No `comp_ref` / dual-assembler target introduced (plan decision 3).

### Oracle bookkeeping

- `scripts/casm_oracle_inventory.py`: added `comp.ref.hex` to
  `NATIVE_MANIFESTS`. `cmake --build build --target casm_oracle_inventory` ->
  `4 native manifests`, `with declared sha256: 71/71`,
  `header claims independent derivation: 71/71`, `reconciliation: OK`.
- `brain/reviews/2026-09-01-casm-byte-oracle-audit.md`: Ledger A header count
  `67 refs + 2 manifests` -> `67 refs + 4 manifests (banner, dash, label,
  comp)`; added `label.ref.hex` and `comp.ref.hex` rows to the Ledger A table
  and a **COMP** row to the coverage matrix, both `CANONICAL-INDEPENDENT`.

## Verification

| Check | Result |
| --- | --- |
| `cmake -B build` | Configuring/Generating done, no warnings |
| `cmake --build build --target comp` | `comp.prg` 1228 B, sha256 `1a0bfbf7...` (== native observation) |
| `casm_r6_verify.py build/comp.prg` | **R6 VERIFY: PASS**; relocates `$3800`/`$5000`/`$9000` |
| No-change rebuild | byte-identical, no rebuild work |
| Stale-source guard | appended a byte to `comp.s` -> `cmake --build build --target comp` **hard-fails** with the sha mismatch; reverting restores a clean build |
| `image_d64` | built; directory shows `comp` prg |
| `test_image_d64` | built |
| `casm_oracle_test_d64` | built (packages `comp`) |
| `command64_comp_test_d64` | built |
| full `cmake --build build` | **clean**, zero errors/warnings |
| `casm_oracle_inventory` target | `reconciliation: OK` |

Note: `hex_manifest_to_bin.py`'s stale-source error text says "regenerate the
manifest with build_dash_manifest.py" for every app (shared string, predates
the per-app scripts). Cosmetic; left unchanged to avoid touching a script on
the DASH/BANNER/LABEL path in this increment.

## Deliberately Deferred

- Functional matrix (identical / mismatch / size-asymmetry / missing-arg /
  slash / raw PRG, both-handles-close, an established CASM fixture comparison,
  cross-device characterization): Increment 5.
- Full determinism sweep, no-change-rebuild identity across all COMP-carrying
  images, and the complete `${COMP_TARGET}` consumer enumeration: Increment 6.
- `CHANGELOG.md` / `brain/EXTERNAL.md` / `brain/KNOWLEDGE.md` / DOX / task
  docs / user docs: Increment 6 consolidation.
- Cross-device stream-invalidation defect
  (`wiki/tasks/comp-cross-device-regression.md`): out of scope, untouched.

## Increment 4 Gate

Requested: approve the manifest + build transition (ca65 retired, COMP ships
from `comp.ref.hex`, `${COMP_TARGET}` preserved, full build + affected image
graphs green). Approval activates Increment 5 (functional and bootstrap
verification under live VICE).
