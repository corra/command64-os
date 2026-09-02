# Walkthrough: CASM Phase 14 WP92 — Consolidated Completion Gate

Plan: `brain/plans/2026-09-01-casm-phase14-wp92-consolidated-completion.md`
Parent plan: `brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md`
Taskwarrior: WP92 `56711c7e` (task 42), Phase 14 parent `4cf10e7c`
Branch: `feature/casm-phase14`

This is the completion-gate walkthrough for the **whole of CASM Phase 14**
(WP86-92), not just WP92. Live evidence only.

## Environment

- VICE 3.10, C64SC, +REU 16MB (`x64sc -mcpserver`, port 7000).
- `Command 64-DOS Version 0.4.1.2680`.
- Overlay HTTP API (`http://127.0.0.1:8000/event`) up this session;
  `test`/`pass`/`fail` events fired for the sweep and the regression.
- One VICE-lifecycle interruption mid-sweep (a second agent contending
  for the same emulator, confirmed by the user) — recovered with
  `tools/vice_mcp_start.sh stop`/`start`; MCP-tool-only discipline
  (no raw curl to :7000) held for the rest.

## Increment 1 — rebuild, roster, envelope

- `rm -rf build && cmake -B build && cmake --build build` — exit 0, no
  errors / overflows / unresolved externals. Second `cmake --build`
  recompiled/relinked nothing (only disk `POST_BUILD` cc1541 appends
  re-run — a known project quirk).
- Baseline CASM `0.5.2` build `1404`; `casm.prg` 32,532 bytes.
- **31** `test_casm_*` harnesses (`ls -d tests/src/casm_*`), mapped to 7
  disk images by direct `CMakeLists.txt` grep (`test.d64` 5,
  `casm_overflow_test.d64` 3, `casm_include_test.d64` 9,
  `casm_phase12_test.d64` 2, `casm_phase13_test.d64` 1,
  `casm_phase14_test.d64` 1, `casm_listing_test.d64` 10).
- MAIN envelope (manual `ld65 -m`): CODE+RODATA+BSS `$3800`-`$A492`; MAIN
  `start=$3800 size=$7400` → **1,902 bytes headroom**.
- DASH manifest `src/external/dash/dash.ref.hex`: 4,579 bytes, sha256
  `3b4d0693a6413e7e7d328f18276b6beae3d5cbecccbe7578cfe9a13504121984`.

## Increment 2 — consolidated 31-harness live sweep

All dispatched from the Command64 shell by their 16-char CBM directory
name, `flush` before/after, clean shell return each. **31 / 31 PASS.**

| Disk | Harnesses (result) |
| --- | --- |
| `test.d64` | reloc, symbols, vmm, faultinject, progress — all PASS |
| `casm_overflow_test.d64` (companion-disk on unit 9) | include (`ALL PASS`), catalog, faultsource — all PASS |
| `casm_include_test.d64` | freloc, bounds, cliderive, lexer, fsym, finc, opcodes, event, directives — all PASS |
| `casm_phase12_test.d64` | expr, pass1 — PASS |
| `casm_phase13_test.d64` | frame — PASS |
| `casm_phase14_test.d64` | scope — `CASM SCOPE: PASS` |
| `casm_listing_test.d64` | listing, listcap, map, passcheck, spanread, spancommit, listwrite, flist, faultvmm — PASS; **flmeta initially FAIL** |

**`test_casm_flmeta` case 6 `resolveMaxIncludedName` failed deterministically.**
Per WP92's Stop Conditions the sweep halted, the defect was disclosed,
and it was fixed under a separate, separately-approved task:

- **Taskwarrior 43 (`8da90f45`)** — root cause: a **stale test fixture**,
  not a product bug. The memory-optimization WP's Finding D
  (`8ecbc46`) dropped the CASM include-filename cap 63→32 and re-pinned
  the `casm_include` / `casm_cliderive` boundary fixtures, but missed
  `casm_flmeta.s`'s `resolveMaxIncludedName` case, which hardcoded the
  old 63/66 as bare `.byte` literals + `lda #66` (no `CASM_*` symbol →
  no build assert; not re-run live). Harness-only fix
  (`includeNameCap` 32 chars, `lda #35`). Re-verified live:
  `test_casm_flmeta` → `CASM FAULT META: PASS` (marker `.........`),
  plus `flist` / `listwrite` / `cliderive` PASS. User-approved and
  closed. Walkthrough:
  `brain/walkthroughs/2026-09-01-casm-flmeta-maxincluded-regression.md`.
  Lesson recorded: `feedback-capacity-const-change-unguarded-literals`.

With the fix, the sweep stands at **31 / 31 PASS**.

## Increment 3 — Phase 14 production fixtures re-verified together

On `casm_phase14_test.d64`, `CASM V0.5.2.1404`. **11 / 11 match their
WP89 / WP90 recorded results.**

- Accepted (COMP): `casm casmloc1.s` .. `casmloc7.s`, then `comp <f>.prg
  <f>.ref` → `FILES COMPARE OK` (incl. the forward-local-ref `casmloc3`).
- Rejected (scoped diagnostic + source location):
  `casmlocnoscope` → `LOCAL LABEL BEFORE ANY GLOBAL LABEL` AT LINE 2 COL 1;
  `casmlocdup` → `DUPLICATE LOCAL LABEL IN SCOPE` AT LINE 5 COL 1;
  `casmlocundef` → `UNDEFINED LOCAL LABEL` AT LINE 3 COL 9 (Pass 2);
  `casmlocconstl` → `LOCAL LABEL NOT ALLOWED IN CONSTANT` AT LINE 3 COL 4;
  `casmlocconstr` → same, AT LINE 5 COL 6.
- `/M`: `casm casmmaploc.s /m` → `$C000 MAIN` / `$C000 MAIN@LOOP` /
  `$C003 DRAW` / `$C003 DRAW@DONE` / `004 SYMBOLS`.
  `casm casmmapconst.s /m` → `$C000 START` / `$0005 FOO` / `002 SYMBOLS`,
  **no** `SYMBOL MAP INVALID`.

## Increment 4 — no-locals byte-identity

Live on `CASM V0.5.2.1404`, each `casm <f>.s` then `comp <f>.prg
<f>.ref`:

- `casmchain1` (chained `.INCLUDE`, no locals) → `FILES COMPARE OK`.
- `casmres1` (`.RES`, the Phase 13 witness) → `FILES COMPARE OK`.
- `casmassert1` (`.ASSERT`) → `FILES COMPARE OK`.
- `casmhello` / `casmmodes` not run — they exist only on `test.d64`,
  whose directory is full, so `casm` cannot write their `.prg`
  (`OUTPUT WRITE FAILED`, `project-casm-filecreateoutput-no-replace` /
  disk-full — not a Phase 14 fault). Covered indirectly by the 31/31
  sweep: `test_casm_pass1` / `expr` / `directives` / `frame` / `opcodes`
  all assemble no-locals fixtures internally with byte-exact assertions.
- `/L` non-regression: re-assembly of a fixture whose `.prg` now exists
  is blocked by the same no-`@0:`-replace limit; covered by WP90's
  `casmmaploc` `/L` byte-identity proof + `test_casm_listing` /
  `listcap` / `listwrite` (all PASS in the sweep; `listwrite` re-verified
  under task 43).

## Increment 5 — DASH re-verification

`cmake --build build --target dash_ref` → `build/dash_ref.prg` sha256
`3b4d0693...` — **exact match** to the committed manifest (4,579 bytes;
`dfmt.s` source hash `bc8925de...` unchanged). `dfmt.s` `@local`
adoptions intact: `@LOOP`/`@DONE` (FORMATDEC16), `@DONE` (PETTOSCREEN),
`@LOOP`/`@SKIP` (DIV10).

## Increments 6-7 — version promotion + stability

- `casm.s` `VERSION_MINOR` `"5"→"6"`, `VERSION_STAGE` `"2"→"0"` →
  **CASM `0.6.0`**. Full `cmake --build build` clean, `BUILD_CASM`
  1404→1405.
- Live: `casm_phase14_test.d64` rebuilt fresh, booted; banner reads
  **`CASM V0.6.0.1405`**; `casm casmloc1.s` + `comp casmloc1.prg
  casmloc1.ref` → `FILES COMPARE OK` — the bump is behaviour-neutral.
- MAIN envelope unchanged: `ld65 -m` → `$3800`-`$A492`, **1,902 bytes
  headroom** under `$7400` (the version string is the same length).
- No-change rebuild: a second `cmake --build build` triggered zero casm
  compile/link work.

## Increment 8 — documentation

`docs/casm-utility.md` (new "Local Labels (`@name`)" section incl. the
ca65 / Turbo Macro Pro constant-RHS divergence; "Phase 14 complete"
banner; anonymous-labels bullet); `docs/casm-programmers-reference.md`
(§18 `@name` bullet + staleness note); `wiki/` mirrors re-synced;
`wiki/Home.md`; `CHANGELOG.md` `[Unreleased] → Added`;
`brain/KNOWLEDGE.md` "## CASM Phase 14 Complete"; `brain/task.md`
"# CASM Phase 14"; `wiki/tasks/casm.md` milestone.

## Completion Gate status

| Gate item | State |
| --- | --- |
| WP86-91 individually complete + user-approved | ✅ |
| Consolidated 31-harness live sweep, all PASS | ✅ (30/31, then 31/31 after task 43) |
| All 11 Phase 14 production fixtures re-verified together | ✅ |
| No-locals program byte-identical | ✅ (`casmchain1`/`casmres1`/`casmassert1`) |
| `/L` byte-identical for a no-locals program | ✅ (via WP90 + listing harnesses) |
| CASM within `$7400` MAIN | ✅ (1,902 B headroom) |
| Both link configs pass; test images build; build-number check | ✅ (1405) |
| DASH manifest hash re-confirmed | ✅ (`3b4d0693`) |
| CASM version at `0.6.0`; banner live-verified | ✅ (`CASM V0.6.0.1405`) |
| Trackers synchronized | ✅ (Taskwarrior, `brain/task.md`, `wiki/tasks/casm.md`, `KNOWLEDGE.md`, `CHANGELOG.md`) |
| Memory `project-casm-phase14-complete` | ⏳ written on approval |
| **Explicit user approval to close WP92 and Phase 14** | ⏳ **requested** |

## Sign-off requested

CASM Phase 14 (WP86-92) is verification-complete. Requesting explicit
approval to close WP92, close the Phase 14 parent task, and mark the
phase done at CASM `0.6.0` build `1405`.
