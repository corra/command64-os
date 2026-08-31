# CASM Progress Increment 11 - Completion Gate Walkthrough

Status: **COMPLETE - user signed off feature-complete 2026-08-31.**
Consolidated 31/31-harness + 10/10-`casmpg*`-fixture live sweep against
`CASM V0.5.0.1380`, no findings. The CASM progress-indication feature is
closed and merged to `main`.

Plan: `brain/plans/2026-08-24-casm-progress-increment11-completion-gate.md`

## Final candidate

Branch `feature/casm-progress-indication`, tip `881376e` + the Increment 11
version-promotion commit (pending). CASM `0.5.0` build `1380`; `casm.prg`
sha256 `e8a6731fd1248b23109a815ae7b828e3bf76b5ea19504a93deef279d8a4f7b67`
(reproduced byte-identical from a clean `rm -rf build` rebuild).

Version change: `src/external/casm/casm.s:18` `VERSION_MINOR "4"` -> `"5"`.
`casm.prg` size unchanged (33,398 bytes - the version digit is the same
width). `BUILD_CASM` 1379 -> 1380 (one increment for the real source
change).

## Atomic Increment 2 - clean build + automated harness roster

- `rm -rf build && cmake -B build && cmake --build build`: exit 0, no
  toolchain errors, **no envelope overflow** (the only `grep -i overflow`
  hits are the `casm_overflow_test.d64` disk-image name).
- **31 test PRGs** built (`ls build/test_casm_*.prg` = 30 + `test_l15release`).
- **11 disk images** built (`image`, `test`, `command64_casm_utils`,
  `casm_overflow_test`, `casm_include_test`, `casm_phase12_test`,
  `casm_phase13_test`, `casm_progress_test`, `casm_listing_test`,
  `casm_phase10_test`, `casm_opcode_test`).
- Exact no-change rebuild: `casm.prg` hash unchanged, `BUILD_CASM` stays
  1380.

## Atomic Increment 4 - memory / envelope / no-change audit (host)

`ld65 -m` against `casm_3800.cfg` (MAIN start `$3800`, size `$7400`):

| Segment | Range | Size |
|---|---|---|
| CODE | `$3800`-`$8BE6` | `$53E7` (21,479) |
| RODATA | `$8BE7`-`$9AE5` | `$0EFF` (3,839) |
| BSS | `$9AE6`-`$A97D` | `$0E98` (3,736) |

Last used `$A97D`; MAIN top `$AC00`; **headroom 642 bytes** (2.1%) - down
from Increment 7's 666 by the Increment 9 PR-2 `SUSPENDED`-guard code and
the version digit, still comfortably positive. No zero-page byte added by
the feature (confirmed in the Increment 9 review). `casm_progress_test.d64`
writable reserve: 433 blocks free.

## Atomic Increment 3 - consolidated live sweep

VICE 3.10 PAL C64SC, `WarpMode: 0`. Two-drive convention: `test.d64` on
unit 8 (bootable), `casm_overflow_test.d64` on unit 9. Each harness run
once on a disk that carries it and its fixtures. Banner check: first run
of any `casm`-linked harness must show `CASM V0.5.0.1380`.

### Roster (31 harnesses, 6 images) + progress matrix

| Image | Harnesses | Result |
|---|---|---|
| `test.d64` (u8) | faultinject, progress, reloc, symbols, vmm | ___ |
| `casm_overflow_test.d64` (u9) | include, catalog, faultsource | ___ |
| `casm_include_test.d64` (u8) | freloc, bounds, cliderive, lexer, fsym, finc, opcodes, event, directives | ___ |
| `casm_phase12_test.d64` (u8) | expr, pass1 | ___ |
| `casm_phase13_test.d64` (u8) | frame | ___ |
| `casm_listing_test.d64` (u8) | listing, listcap, map, passcheck, l15release, spanread, spancommit, listwrite, flist, flmeta, faultvmm | ___ |
| `casm_progress_test.d64` (u8) | progress + casmpg63/64/65/128/blank/fill/incbin/r6/rt/inc + option identity + casmpgbad failure | ___ |

### Live results

VICE 3.10, `test.d64` on u8 (booted; `Command 64-DOS Version 0.4.1.2680`),
`casm_overflow_test.d64` on u9. Shell dispatch uses the full documented
harness name (the shell matches it against the 16-char-truncated disk
entry).

- **`test.d64` (u8): 5/5 PASS** - `test_casm_reloc` -> `CASM RELOC: PASS`;
  `test_casm_symbols` -> `CASM SYMBOLS: PASS`; `test_casm_vmm` -> `CASM
  VMM: PASS`; `test_casm_faulti(nject)` -> `CASM FAULTINJECT: PASS`;
  `test_casm_progress` -> ran all cases (incl. `DONE: P1 00000, P2 00000,
  00150 BYTES`, `P1: DONE 65535 STATEMENTS`, `P1: INCBIN 65535`) ->
  `CASM PROGRESS: PASS`.
- **`casm_overflow_test.d64` (u9): 3/3 PASS** - `test_casm_include` ->
  `CASM INCLUDE: ALL PASS`; `test_casm_catalog` -> `CASM CATALOG: PASS`
  (its `LOAD F1100065` progress line rendered inside the harness -
  progress hook active there too); `test_casm_faultsource` -> `CASM
  FAULT SOURCE: PASS`.
- **`casm_include_test.d64` (u8): 9/9 PASS** - `test_casm_freloc` ->
  `CASM FAULT RELOC: PASS`; `test_casm_bounds` -> `CASM BOUNDS: PASS`;
  `test_casm_cliderive` -> `CASM CLIDERIVE: PASS`; `test_casm_lexer` ->
  `CASM LEXER: PASS`; `test_casm_fsym` -> `CASM FAULT SYMBOLS: PASS`;
  `test_casm_finc` -> `CASM FAULT INCLUDE: PASS`; `test_casm_opcodes` ->
  `CASM OPCODES: PASS`; `test_casm_event` -> `CASM EVENT TESTS PASS`;
  `test_casm_directives` -> `CASM DIRECTIVES: PASS`.
- **`casm_phase12_test.d64` (u8): 2/2 PASS** - `test_casm_expr` ->
  `CASM EXPR: PASS`; `test_casm_pass1` -> `CASM PASS1: PASS`.
- **`casm_phase13_test.d64` (u8): 1/1 PASS** - `test_casm_frame` ->
  `CASM FRAME: PASS`. Note: the frame harness drives `sourceLoad` in a
  loop, so its own progress `LOAD F...` transient lines interleave with
  the harness's `.` markers on screen *during* the run - cosmetic
  harness-internal noise (production `casm` calls `sourceLoad` once with a
  clean screen); the harness passes and the final screen is legible.
- **`casm_listing_test.d64` (u8): 11/11 PASS** - `test_casm_listing` ->
  `CASM LISTING: PASS`; `test_casm_listcap` -> `CASM LISTCAP: PASS`;
  `test_casm_map` -> `CASM MAP: PASS`; `test_casm_passcheck` ->
  `CASM PASSCHECK: PASS`; `test_l15release` -> 5/5 `OK` (no
  PASS/FAIL banner by design); `test_casm_spanread` -> `CASM SPANREAD:
  PASS`; `test_casm_spancommit` -> `CASM SPANCOMMIT: PASS`;
  `test_casm_listwrite` -> `CASM LISTWRITE: PASS`; `test_casm_flist` ->
  `CASM FAULT LIST: PASS`; `test_casm_flmeta` -> `CASM FAULT META: PASS`;
  `test_casm_faultvmm` -> `CASM FAULT VMM: PASS`.

**Harness roster: 31/31 PASS** against the `CASM 0.5.0` build `1380`
candidate.

- **`casm_progress_test.d64` (u8): PASS.**
  - `test_casm_progress` (the 20+-case unit harness, also on `test.d64`) ->
    `CASM PROGRESS: PASS` (32nd harness).
  - **`casmpg*` accepted matrix: 10/10 `FILES COMPARE OK`** against the
    hand-derived references, every `DONE: ... nnnnn BYTES` field exact:
    `casmpg63` (00063/00064), `casmpg64` (00064/00065), `casmpg65`
    (00065/00066), `casmpg128` (00128/00129), `casmpgblank` (**00006** -
    blank/comment lines excluded / 00007), `casmpgfill` (00004/**00258** -
    fixed-fill accounting), `casmpgincbin` (00002/00010), `casmpgr6`
    (00044/**00054** - R6 table + footer), `casmpgrt` (**00081** combined /
    00082), `casmpginca` (**00012** - nested + sequential re-inclusion /
    00009).
  - **`casmpgbad.s` failure case: PASS.** `P1: DONE 00072`, then `P2:
    START` and a blank row (transient line wiped by `diagPrintFatal`),
    then `CASM: BRANCH OUT OF RANGE` / `AT LINE 72, COL 1` / `bne $d000` /
    caret - no stale-transient overlap. `DIR` afterward lists
    `casmpgbad.s` but **not** `casmpgbad.prg` (`outputAbort` deleted the
    72-byte partial).
  - **Option identity: PASS.** `casm casmpg128.s /o:ml5.prg /m /l` ->
    `SYMBOL MAP` / `000 SYMBOLS` / `DONE` clean; `comp ml5.prg
    casmpg128.ref` -> `FILES COMPARE OK` (output bytes identical with
    `/M`+`/L`).

**Consolidated live sweep: 31/31 harnesses + 10/10 casmpg fixtures +
failure case + option identity, all PASS against `CASM V0.5.0.1380`.**
No findings.

## Atomic Increment 4 (continued) - no-change + artifact audit

- **Exact no-change rebuild:** two consecutive `cmake --build build` -
  `casm.prg` `e8a6731f...` and `casm_progress_test.d64` `eb4066e6...`
  byte-identical across both; `BUILD_CASM` stays 1380; `git diff --check`
  clean.
- **Artifact identity:** all 10 `casmpg*` `COMP` checks green against the
  hand-derived references; the `DONE:` byte counts cross-checked against
  the reference sizes exactly (Increment 4's cross-validation re-holds
  against `0.5.0`).
- **Handle / VMM cleanup:** proven by the repeated-invocation case
  (Increment 10, re-witnessed here in the `casmpg*` sweep - every fixture
  ran back-to-back against CASM's capped file/VMM registries with a clean
  `C64[8]:>` return; a leak would have failed a later run) and by the
  fault-injection harness family (`faultinject`, `faultsource`, `fsym`,
  `finc`, `faultvmm`, `flist`, `flmeta`) all PASS.
- **Disk inventory:** `casm_progress_test.d64` 422 blocks free after the
  full session (started at 433); no name collisions.

## Atomic Increment 6 - documentation / DOX closeout

- `CHANGELOG.md` `[Unreleased]`: added the progress-indication feature
  entry (`0.4.0` -> `0.5.0`).
- `docs/casm-utility.md` + `wiki/casm-utility.md` (mirror): new "Progress
  Display" subsection under "What Happens".
- `docs/casm-programmers-reference.md` + `wiki/` mirror: status header
  updated to "Phase 13 + progress indication complete (build 1380, version
  0.5.0)".
- `brain/KNOWLEDGE.md`: new "CASM Progress Indication Complete" section
  after the Phase 13 section.
- `wiki/tasks/casm.md`: Current Milestone updated; the "Optional Feature -
  Progress and Processing Indication" section marked complete with the
  increment history.
- `wiki/tasks/casm-progress-indication.md`: marked complete.
- `src/external/casm/AGENTS.md`: progress-feature note updated to complete.
- `brain/plans/2026-07-16-casm-assembler-implementation-plan.md`: Current
  Status reconciled to `0.5.0` build `1380` with the change-in-scope note
  (progress shipped as an optional feature outside the numbered phases).
- `cmake --build build --target release`: regenerated `release/` (docs +
  disk images + archives) from the `0.5.0` build; `casm-utility.md` /
  `casm-programmers-reference.md` in `release/docs/` now match `docs/`.

## Completion Gate

- [x] Clean build + no-change rebuild reproducible (`casm.prg`
      `e8a6731f...`, `BUILD_CASM` 1380).
- [x] Version promoted `0.4.0` -> `0.5.0` at the approved point; live
      banner `CASM V0.5.0.1380` confirmed.
- [x] All 31 harnesses PASS live against the `0.5.0` candidate (+ the
      progress unit harness on its own disk = 32).
- [x] `casmpg*` matrix (10/10 `COMP OK`), `/M /L` output identity, and
      the `casmpgbad` failure case (transient cleared, no orphan PRG) all
      PASS live.
- [x] Artifact / disk-inventory / handle-VMM-cleanup / shell-return
      checks (above).
- [x] CHANGELOG, KNOWLEDGE, user/programmer docs, master plan scope note,
      AGENTS DOX, `release/`, trackers, memory all updated.
- [x] User explicitly approved marking the progress feature complete
      (2026-08-31).
- [x] `feature/casm-progress-indication` merged to `main`.
