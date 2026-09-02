# Walkthrough: Byte-Oracle Transition WP5 — DASH Differential & Source-Policy Transition

Plan: `brain/plans/2026-09-02-casm-byte-oracle-wp5-dash-differential-source-policy.md`
Parent: `brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`
Date executed: 2026-09-02
Branch: `feature/casm-byte-oracle-wp5`

## Outcome

`dash_ref` (ca65) is decoupled from ordinary builds and from the utility
disk; DASH's shipping bytes and source policy are unchanged.

1. **`dash_ref` is `EXCLUDE_FROM_ALL`.** `cmake --build build` never
   invokes ca65 for DASH. `add_ca65_app` gained an `EXCLUDE_FROM_ALL`
   option (`cmake/Ca65.cmake`); existing call sites are unaffected.
2. **Utility disk decoupled.** `command64_casm_utils_d64` packages
   `dash.ref` from `${DASH_BIN}` (transcribed from the reviewed
   `dash.ref.hex` manifest) and depends on `dash`, not `dash_ref`.
3. **`--allow-host-bytes` removed** from `scripts/build_dash_manifest.py`;
   passing the ca65 build path as the manifest input is a hard refusal
   with no override. `--cross-check` stays as optional differential
   evidence.
4. **DOX** — `src/external/dash/AGENTS.md`'s "Dual-Assembler Subset
   (load-bearing — pending WP5 relaxation)" became "Differential Guidance";
   `.agents/workflows/overlay-build-events.md` updated for the
   `EXCLUDE_FROM_ALL` reality; `wiki`/`docs`/`release/docs` `dash-utility.md`
   and `packaging/RELEASE_README.md` reconciled.

## DASH provenance — the honest position (post WP4 audit correction)

The original WP4 close claimed a full independent byte derivation of DASH
and promoted `dash.ref.hex` to `CANONICAL-INDEPENDENT`. **That was
withdrawn 2026-09-02** — a byte-by-byte derivation of 3,669 code/data
bytes across seven files is not practical. Corrected classification:

| evidence | state |
| --- | --- |
| DASH's 3,669 code/data bytes | **`NATIVE-OBSERVATION`** — reviewed native CASM run (`0.5.2` b1404) + ca65 `dash_ref` differential (`DIFFERENTIAL-ONLY`, byte-identical) + `source_sha256` guard + DASH-MOD runtime evidence |
| DASH's 451-entry R6 relocation table + footer | **`CANONICAL-INDEPENDENT`** — derived + verified by `scripts/casm_r6_verify.py` (new): every entry in-image, ascending, unique; multi-base application consistent |
| BANNER's manifest (963 code bytes, 20-entry table) | **`CANONICAL-INDEPENDENT`** — full address ledger + table verified entry-for-entry against the body |

**Because DASH's bytes are not `CANONICAL-INDEPENDENT`, `dash_ref` is
retained as a *standing* release-verification check** (not merely
"optional") for as long as DASH source stays in the shared syntax subset —
it is the only independent corroboration of the code bytes. A mismatch is
a release blocker. Only when a future WP deliberately adopts CASM-only
syntax that ca65 rejects does `dash_ref` stop building without being a
defect, and that WP records the loss and adds a fresh native `COMP`.

## Disk layout (governing-plan "dash.prg vs dash.ref" discrepancy — resolved)

Not a discrepancy — two disks, two roles, byte-identical content
(`3b4d0693…`):

- **Production `image.d64`** carries `dash` (the app users run) —
  `IMAGE_PRG_TARGETS ... dash`, from the `dash` target's `C64_PRG_PATH`
  = `DASH_BIN`.
- **Utility `command64_casm_utils.d64`** carries `dash.ref` (the reviewed
  reference) + the seven `.s` sources — for the on-C64 `CASM DMAIN.S
  /O:DASH.PRG` then `COMP DASH.PRG DASH.REF` developer workflow. No
  separate `dash.prg` on the utility disk.

## Verification (all on the WP5 working tree)

```
$ cmake -B build                      # configure OK
$ cmake --build build                 # green; dash_ref NOT built
      [ 85%] Built target dash
      [ 85%] Built target banner
      [97%]  Built target command64_casm_utils_d64
$ cmake --build build --target dash_ref
      [100%] Built target dash_ref
$ cmp build/dash_ref.prg build/dash.prg && echo MATCH
      MATCH                           # differential valid; DASH still in shared subset
$ sha256sum build/dash.prg build/banner.prg
      3b4d0693…  build/dash.prg       # unchanged
      b43415c1…  build/banner.prg     # unchanged
$ python3 scripts/casm_oracle_inventory.py --check
      reconciliation: OK   (69/69 declare sha256)
$ python3 scripts/casm_r6_verify.py src/external/dash/dash.ref.hex
      R6 VERIFY: PASS      (451 entries)
$ python3 scripts/casm_r6_verify.py src/external/banner/banner.ref.hex
      R6 VERIFY: PASS      (20 entries)
```

Disk contents confirmed via `tools/cc1541`: `image.d64` → `dash` (19
blocks); `command64_casm_utils.d64` → `dash.ref` (19 blocks) + `dmain.s`…
`ddata.s` + `banner`/`banner.s`; **no `dash_ref` build artifact anywhere
in a default build**.

## Completion gate

| Gate item | Status |
| --- | --- |
| `dash_ref` `EXCLUDE_FROM_ALL`, not built by default | ✅ |
| utility disk packages `dash.ref` from `${DASH_BIN}`, no `dash_ref` dependency | ✅ |
| `build_dash_manifest.py` has no `--allow-host-bytes` | ✅ |
| `dash/AGENTS.md` differential-guidance (with standing-check caveat) | ✅ |
| overlay / user-manual / release docs reconciled, mirrors identical | ✅ |
| `casm_oracle_inventory --check` green | ✅ |
| default build + opt-in `dash_ref` verified; differential still matches | ✅ |
| `dash.prg` / `banner.prg` / all 67 fixture `.ref` byte-unchanged | ✅ |
| WP4 audit correction folded in (DASH → `NATIVE-OBSERVATION`) | ✅ |
| **user approves closure** | ⏳ pending |

## Files changed (WP5 + folded-in WP4 audit correction)

| File | Change |
| --- | --- |
| `cmake/Ca65.cmake` | `add_ca65_app` `EXCLUDE_FROM_ALL` option |
| `CMakeLists.txt` | `dash_ref` `EXCLUDE_FROM_ALL`; utility disk packages `${DASH_BIN}`; drop `dash_ref` dependency; honest comment |
| `scripts/build_dash_manifest.py` | Remove `--allow-host-bytes` |
| `scripts/casm_r6_verify.py` | **Created** — assembler-independent R6 verifier |
| `src/external/dash/AGENTS.md` | Differential Guidance + standing-check caveat |
| `src/external/dash/dash.ref.hex` | Header reworded — `NATIVE-OBSERVATION` bytes, independent R6 ledger |
| `.agents/workflows/overlay-build-events.md` | `EXCLUDE_FROM_ALL` DASH build-events reality |
| `.agents/workflows/canonical-byte-oracles.md` | `casm_r6_verify.py` documented |
| `wiki`/`docs`/`release/docs` `dash-utility.md` | Provenance reworded, mirrors synced |
| `packaging/RELEASE_README.md` | `dash.ref` role clarified |
| `brain/reviews/2026-09-02-casm-byte-oracle-wp4-{dash,banner}-derivation.md` | Corrected / re-verified |
| `brain/reviews/2026-09-01-casm-byte-oracle-audit.md` | DASH → `NATIVE-OBSERVATION`; BANNER stands |
| `brain/plans/2026-09-02-casm-byte-oracle-wp4-*.md`, governing plan, WP5 plan | Correction recorded |
| `wiki/tasks/casm.md` | WP5 status; OUTPUT_WRITE_FAILED follow-up noted |
