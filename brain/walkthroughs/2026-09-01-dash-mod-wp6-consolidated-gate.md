# Walkthrough: DASH-MOD WP6 - Consolidated gate + re-baseline

Plan: `brain/plans/2026-09-01-dash-mod-wp6-consolidated-gate.md`
Parent: `brain/plans/2026-09-01-dash-modernization.md`
Taskwarrior: WP6 task 55 (child of `94ec17b3`)
Branch: `feature/casm-phase14`

**Closes the DASH Modernization increment (WP1-6).**

## The increment, end to end

| WP | delivered | output |
| --- | --- | --- |
| 1 | CASM `.ASSERT` ca65 action-keyword form | CASM only, no DASH byte change |
| 2 | ~90 routine-internal labels -> `@local` (all 7 files) | byte-identical (`3238b786`, 4766 B) |
| 3 | ~110 named constants; 16 ca65-only `.assert` invariants | byte-identical (`3238b786`) |
| 4 | event loop / key dispatch: F-key range compute, `AND #$DF` fold, `SELECT*` collapse, `MARKREDRAW` | **`3238b786` -> `08f8f7ce`**, 4766 -> 4713 B |
| 5 | renderer helpers: `COPYFRAMEROW`, table `DAPPPRINTFLAGS`, `DSYSLABEL`; dead `PRINTAT` removed | **`08f8f7ce` -> `4a49612e`**, 4713 -> 4579 B |
| 6 | version bump, consolidation, consolidated gate | **`4a49612e` -> `3b4d0693`**, 4579 B (2 version bytes) |

**Net:** DASH `0.1.4` -> `0.2.0`; `4766 -> 4579` bytes (-187); ~30 global
labels removed; every routine constant-driven and helper-backed; no
user-visible behaviour change, verified byte-identical or
behaviour-identical at every step.

## WP6 changes

- **`ddata.s`** `DASHVERSTR` `"0.1.4"` -> `"0.2.0"` (2 bytes; the row-24
  banner reads `DASH v0.2.0`).
- **`AGENTS.md`** consolidated (no information loss): Purpose gains a
  modernization summary + version; new "Version" and "Named constants"
  contracts; the Dual-Assembler Subset bullets fold the per-WP notes into
  current-state framing (broad string/constant adoption, the two CASM
  expression-grammar limits, `@local` everywhere); "Current provenance"
  refreshed (CASM `0.5.2` b1404, 4579 B, `3b4d0693`); the
  `$3800`/`$5000`/`$9000` spot-check mechanism spelled out.
- **`dash.ref.hex`** re-baselined a final time.
- **`CHANGELOG.md`** `[Unreleased]` -> `### Changed`: a "DASH
  Modernization" block (WP1-6 summary).
- **`brain/KNOWLEDGE.md`** DASH section: a modernization closing note
  with the reusable findings (`@local` eligibility rule; CASM
  constant-RHS-must-be-literal; CASM `.ASSERT` has no comparison
  operator; fold-uniqueness; the `dvmm.s` deferral).

## Consolidated live re-verification (fresh, together)

Run from the current tree in one pass, not per-WP citation:

1. **`check_casm_source_bytes.py`** on all 7 shipped sources -> clean.
2. **Clean `dash_ref` rebuild** (`rm`'d `dash_ref.prg` / `dash.prg` /
   `command64_casm_utils.d64` first): 4579 bytes, 3669 code bytes, **451
   relocation points**, link succeeded (all 21 `.assert`s pass -- a false
   one aborts the ld65 link), `tools/reloc.py` clean.
3. **Native CASM under VICE** (`CASM V0.5.2.1404`, 16MB REU): fresh
   `command64_casm_utils_d64`, `CASM DMAIN.S /O:DW6.PRG` -> `P1: DONE
   01659 STATEMENTS`, `P2: DONE 01659`, `DONE: P1 01659, P2 01659, 04579
   BYTES`, `CASM: INPUT VALIDATED`. `COMP DW6.PRG DASH.REF` ->
   **`FILES COMPARE OK`**.
4. Extracted native `DW6.PRG` (`cc1541 -X`): `cmp`-identical to
   `build/dash_ref.prg` (4579 bytes) -- ca65 and native CASM produce the
   identical binary, relocation table included.
5. **Manifest re-baselined:** `build_dash_manifest.py <native DW6.PRG>
   --cross-check build/dash_ref.prg` -> **4579 bytes, sha256
   `3b4d0693a6413e7e7d328f18276b6beae3d5cbecccbe7578cfe9a13504121984`**
   (was `4a49612e...`), `cross-check: MATCHES dash_ref.prg byte-for-byte`,
   all 7 `source_sha256` refreshed, **no `--allow-host-bytes`**. `cmp -l`
   vs the pre-WP6 bytes = **exactly 2 bytes** (offsets 2557, 2559 -- the
   `1`->`2` and `4`->`0` of the version string; the `.` at 2558
   unchanged).
6. `cmake --build build --target dash` (`dash.prg` == native,
   `3b4d0693...`); full `cmake --build build`; `image_d64`;
   `test_image_d64` -> all clean.

## Relocation audit

`AGENTS.md`'s Verification-section rules hold for the final code:
- **Entries:** `PAGEROUTINETABLE`'s 3 `.WORD` renderer pointers; absolute
  label operands; `#>label` high bytes (the `COPYFRAMEROW` / `DSYSLABEL`
  call sites).
- **No entries:** `$1000` (`OS_API`), `$FFE4` (`KERNAL_GETIN`),
  screen/colour RAM, ZP `$70-$8F`, `#<label` low bytes, `(ptr),Y`.
- Final count **451**, accounted for: WP4 465 -> 459 (-6, `SELECT*`
  collapse), WP5 459 -> 451 (-8, `#>label` operands replacing inline
  `LDA label,X` + `PRINTAT` removal), WP6 +0 (data-string edit moves no
  entry).

## User runtime matrix

Agent drove all three load bases live under VICE (16MB REU). Banner reads
**`DASH v0.2.0`** at every base.

| base | result |
| --- | --- |
| **$3800** (shell default) | System page renders every field; F3 -> Applications `dash 3800-4654 ... u---`; F5 -> VMM Test; `T` -> `status: PASSED` (pattern 3/3); `R` -> redraw; F1 -> System; `Q` -> `c64[8]:>` -- **full agent pass** |
| **$5000** (`LOAD DASH 5000` / `RUN 5000`) | System renders; F3 -> `dash 5000-5e54 ... u---`; F5 -> VMM Test; `T` -> `PASSED`; F1; `Q` -> shell -- **full agent pass** |
| **$9000** (`LOAD DASH 9000` / `RUN 9000`) | System renders every field; F3 -> `dash 9000-9e54 ... u---` -- **relocated correctly** (agent). The agent's keyboard feed starved the query-heavy VICE session for the remaining keys (PC snapshots showed DASH inside KERNAL `GETIN` with the sent key in X -- polling fine, just no continuous run-time between the pausing queries). **User ran the $9000 base manually and confirmed it is fine** (2026-09-01). |

All three bases: correct render + relocation + navigation + VMM test +
exit. Overlay `test`/`pass` fired.

## Build evidence

- `dash_ref`, `dash`, `command64_casm_utils_d64`, `image_d64`,
  `test_image_d64`, full `cmake --build build` -> all clean.
- `casm.prg` unchanged (no CASM source touched in WP2-6).
- `check_casm_source_bytes.py` clean on all 7 shipped sources.

## Notes

- **Phase 14 WP92:** the modernized DASH (`0.2.0`, manifest `3b4d0693`)
  is the baseline WP92's consolidated gate re-verifies against; WP92
  re-cites this gate rather than re-running DASH's runtime matrix.
- **Deferred `dvmm.s` refactor** (`DVMMLABEL` + enum->string tables):
  recorded in the WP5 walkthrough and `KNOWLEDGE.md` as a small
  post-increment follow-up.
- A stale WP5 doc figure (post-WP5 relocation count stated as 443) was
  corrected to 451 during WP6 (commit `casm: DASH-MOD WP5 doc fix`).

## Sign-off requested

WP6 and the whole DASH Modernization increment are complete: DASH
`0.2.0`, ca65 == native CASM == re-baselined manifest byte-for-byte
(`3b4d0693`, 4579 bytes), relocation-audited, `AGENTS.md` consolidated,
`CHANGELOG` + `KNOWLEDGE.md` updated, runtime matrix passed at all three
bases (user-confirmed at `$9000`). Requesting approval to close WP6, mark
the parent Taskwarrior task `94ec17b3` done, and consider the DASH
Modernization increment closed.
