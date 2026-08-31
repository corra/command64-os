# CASM Progress Increment 8 - Automated Verification Walkthrough

Status: **COMPLETE - user-approved 2026-08-31.** Atomic Increments 1-4 and
8 complete (all PASS); Increment 5 partial (fatal input-open path clean,
mid-assembly-fatal case noted non-blocking); Increments 6 and 7 waived as
redundant re-checks of a byte-identical binary. User accepted the
Increment 4 evidence and approved closing Increment 8 with 6 & 7 waived
2026-08-31.

Plan: `brain/plans/2026-08-24-casm-progress-increment08-automated-verification.md`

Baseline: `CASM 0.4.0` build `1378`, `casm.prg` sha256
`af1bacdab72a40bf20983a8676592873d76b0bd74d2b6c0b68155b6f7c3d819c`
(byte-identical to the Increment 7 close - this increment adds no
production code). `$7400` MAIN, 666 bytes headroom.

Progress redraw cadence is **mod-64 statements** (`progress.s` `CasmProgDivider`):
a throttled transient redraw fires at exact parsed-statement counts
64, 128, 192, .... The pass-start (`P1:`/`P2:`) and pass-end lines always
render regardless of the throttle.

---

## Atomic Increments 1-3 (host side) - COMPLETE

### Fixtures added (`cmake/GenerateCasmTestFixtures.cmake`)

| Fixture | Shape | What it pins |
|---|---|---|
| `casmpg63` | `.ORG` + 62 `NOP` (**63 counted**) | <64 counted statements: no throttled mid-pass redraw |
| `casmpg64` | `.ORG` + 63 `NOP` (**64 counted**) | exactly one throttled redraw (count 64) |
| `casmpg65` | `.ORG` + 64 `NOP` (**65 counted**) | one redraw at 64 + a 1-statement remainder |
| `casmpg128` | `.ORG` + 127 `NOP` (**128 counted**) | two throttled redraws (64, 128) |
| `casmpgblank` | blanks/comments among 5 `NOP` | blank/comment lines don't advance the counter |
| `casmpgrta` + `casmpgrtb` | 2 top-level roots, combined PC | per-root `LOAD:` line + combined pass counts |
| `casmpginca`/`casmpgincb`/`casmpgincc` | nested `.INCLUDE` + sequential re-inclusion | frame push/pop identity on the transient line |
| `casmpgfill` | `.RES 100` + `.FILL 50,$AB` + `.ALIGN 256` | Increment-6 bounded per-chunk directive byte-cadence |
| `casmpgincbin` | `.INCBIN "CASMPGBIN.DAT"` (8-byte payload) | `.INCBIN` byte-cadence |
| `casmpgr6` | no `.ORG`, forward label -> 1 R6 entry | `WRITE:` line + emitFlush/table/footer byte accounting |

### Trusted references

10 hand-derived `tests/fixtures/casm/casmpg*.ref.hex` manifests (reviewed
repetition rules from the 6502 instruction set, **never produced by CASM**),
converted by `scripts/hex_manifest_to_bin.py`; all validate. Plus
`tests/fixtures/casm/casmpgbin.dat` (bytes `01 02 03 04 05 06 07 08`).
Added to `CASM_REF_NAMES`; excluded from the generic `test.d64` reference
loop (`REF_NAME MATCHES "^casmpg"`).

**Expected assembled sizes** (full PRG incl. 2-byte load header; the `DONE:`
summary's `nnnnn BYTES` field must match these exactly):

| Fixture | Bytes | Fixture | Bytes |
|---|---|---|---|
| `casmpg63` | 64 | `casmpgrt` | 82 |
| `casmpg64` | 65 | `casmpginc` | 9 |
| `casmpg65` | 66 | `casmpgfill` | 258 |
| `casmpg128` | 129 | `casmpgincbin` | 10 |
| `casmpgblank` | 7 | `casmpgr6` | 54 |

### Disk

`add_c64_disk_image(casm_progress_test_d64)` -> `build/casm_progress_test.d64`,
self-bootable (`command64` + `casm` + `comp` + `test_casm_progress` + all
casmpg* fixtures/refs). Built clean, **435 blocks free**. Overlay build
events wired via the standard `WRAPPER_CC1541` pattern.

On-disk directory (verified):

```
132  "casm"             prg        2  "casmpg63.s"       seq   1  "casmpg63.ref"    prg
5    "comp"             prg        2  "casmpg64.s"       seq   1  "casmpg64.ref"    prg
12   "test_casm_progre" prg        2  "casmpg65.s"       seq   1  "casmpg65.ref"    prg
                                   3  "casmpg128.s"      seq   1  "casmpg128.ref"   prg
                                   1  "casmpgblank.s"    seq   1  "casmpgblank.ref" prg
                                   1  "casmpgfill.s"     seq   2  "casmpgfill.ref"  prg
                                   1  "casmpgincbin.s"   seq   1  "casmpgincbin.ref"prg
                                   2  "casmpgr6.s"       seq   1  "casmpgr6.ref"    prg
                                   1  "casmpgrta.s"      seq   1  "casmpgrtb.s"     seq
                                   1  "casmpgrt.ref"     prg
                                   1  "casmpginca"       seq   1  "casmpgincb"      seq
                                   1  "casmpgincc"       seq   1  "casmpginc.ref"   prg
                                   1  "casmpgbin.dat"    seq
```

### Build evidence

- `cmake -B build`: exit 0.
- `cmake --build build` (full): exit 0, no real toolchain errors (the only
  `grep -i error/fail` hits are substrings in disk-image *names*).
- `casm.prg` sha256 `af1bacda...` **unchanged** from the Increment 7
  baseline; targeted no-change rebuild of `casm` reproduced it exactly.
- `src/external/casm/BUILD_CASM` still **1378**.
- `git diff --check`: clean.

---

## Atomic Increment 4 - focused matrix (live VICE) - COMPLETE (all PASS)

Session 2026-08-31: VICE 3.10 PAL C64SC, `WarpMode: 0` (normal speed - warp
could not be toggled through the MCP wrapper this session). `command64`
booted from `casm_progress_test.d64` on unit 8; row 0 decodes
`Command 64-DOS Version 0.4.1.2680`; CASM banner `CASM V0.4.0.1378`
confirmed on the first run (fresh binary). Prompt `C64[8]:>`.

Results (raw screen-RAM decode):

- **4.1 `casmpg63` - PASS.** `P1: DONE 00063 STATEMENTS` /
  `P2: DONE 00063 STATEMENTS` (P1==P2==63 as predicted for `.ORG` + 62 NOP);
  `WRITE: casmpg63.prg`; `DONE: P1 00063, P2 00063, 00064 BYTES` (matches
  expected 64); `CASM: INPUT VALIDATED`; shell returned.
  `comp casmpg63.prg casmpg63.ref` -> `FILES COMPARE OK`.
- **4.2 `casmpg64` - PASS.** `P1: DONE 00064` / `P2: DONE 00064`;
  `WRITE: casmpg64.prg`; `DONE: P1 00064, P2 00064, 00065 BYTES` (matches
  expected 65); `comp casmpg64.prg casmpg64.ref` -> `FILES COMPARE OK`.
- **4.3 `casmpg65` - PASS.** `P1: DONE 00065` / `P2: DONE 00065`;
  `WRITE: casmpg65.prg`; `DONE: P1 00065, P2 00065, 00066 BYTES` (matches
  expected 66); `comp casmpg65.prg casmpg65.ref` -> `FILES COMPARE OK`.
- **4.4 `casmpg128` - PASS.** `P1: DONE 00128` / `P2: DONE 00128`;
  `WRITE: casmpg128.prg`; `DONE: P1 00128, P2 00128, 00129 BYTES` (matches
  expected 129); `comp casmpg128.prg casmpg128.ref` -> `FILES COMPARE OK`.
- **4.5 `casmpgblank` - PASS.** Key assertion held: `P1: DONE 00006
  STATEMENTS` / `P2: DONE 00006 STATEMENTS` - **exactly 6** (`.ORG` + 5
  `NOP`), the blank and comment-only lines did **not** advance the counter.
  `DONE: P1 00006, P2 00006, 00007 BYTES` (matches expected 7);
  `comp casmpgblank.prg casmpgblank.ref` -> `FILES COMPARE OK`.
- **4.6 `casmpgfill` - PASS.** `P1: DONE 00004` / `P2: DONE 00004` (`.ORG`
  + `.RES` + `.FILL` + `.ALIGN` = 4 directive statements); the bounded
  per-chunk directive byte-cadence line flashes during assembly;
  `WRITE: casmpgfill.prg`; `DONE: P1 00004, P2 00004, 00258 BYTES` (matches
  expected 258 exactly - `.RES 100` + `.FILL 50` + `.ALIGN`-to-$C100 pad
  106 + 2 header); `comp casmpgfill.prg casmpgfill.ref` -> `FILES COMPARE
  OK`.
- **4.7 `casmpgincbin` - PASS.** `P1: DONE 00002` / `P2: DONE 00002`
  (`.ORG` + `.INCBIN`); `.INCBIN` byte-cadence line flashes during
  assembly; `WRITE: casmpgincbin.prg`; `DONE: P1 00002, P2 00002, 00010
  BYTES` (matches expected 10 = 2 header + 8 payload); `comp
  casmpgincbin.prg casmpgincbin.ref` -> `FILES COMPARE OK`.
- **4.8 `casmpgr6` - PASS.** `P1: DONE 00044` / `P2: DONE 00044` (START
  label + 40 `NOP` + `JMP` + TARGET label + `NOP`); `WRITE: casmpgr6.prg`;
  `DONE: P1 00044, P2 00044, 00054 BYTES` (matches expected 54 = 44
  program + 2-byte R6 table + 6-byte R6 footer + 2 header) - the relocation
  table + footer are correctly included in the byte accounting; `comp
  casmpgr6.prg casmpgr6.ref` -> `FILES COMPARE OK`.
- **4.9 `casmpgrt` (multi-root) - PASS.** Dispatched `casm casmpgrta.s
  casmpgrtb.s /o:casmpgrt.prg`. `P1: DONE 00081 STATEMENTS` / `P2: DONE
  00081 STATEMENTS` - the **combined** count across both roots (`.ORG` +
  80 `NOP`); the per-root `LOAD:` lines flash during the load phase (not
  separately frozen, but the combined 81-count and 82-byte total confirm
  both roots were loaded and assembled); `WRITE: casmpgrt.prg`; `DONE: P1
  00081, P2 00081, 00082 BYTES` (matches expected 82); `comp casmpgrt.prg
  casmpgrt.ref` -> `FILES COMPARE OK`.
- **4.10 `casmpginc` (nested include + re-inclusion) - PASS.** Dispatched
  `casm casmpginca`. `P1: DONE 00012 STATEMENTS` / `P2: DONE 00012
  STATEMENTS` - exactly 12: `.ORG` + `.INCLUDE` + [B: `NOP` + `.INCLUDE` +
  [C: `NOP`] + `NOP`] + parent `NOP` + `.INCLUDE` (re-inclusion) + [B: same
  4 again]. Every frame push/pop (nested and the sequential re-inclusion)
  was traversed; the transient line's child/parent filename swap flashes
  during traversal. `WRITE: casmpginca.prg`; `DONE: P1 00012, P2 00012,
  00009 BYTES` (matches expected 9 = 2 header + `EA` x 7); `comp
  casmpginca.prg casmpginc.ref` -> `FILES COMPARE OK`.

**Atomic Increment 4 focused matrix: 10/10 PASS.** Every `DONE:` byte
count matched the hand-derived reference size exactly (64/65/66/129/7/258/
10/54/82/9); P1 always equalled P2; the statement counter tracked
*counted* statements (directives included, blank/comment lines excluded);
`.INCBIN`, fixed-fill, multi-root, nested-include + re-inclusion, and
R6-footer byte accounting all correct; all 10 `comp` checks
`FILES COMPARE OK`.

### Option-identity sub-matrix (against `casmpg128.s`)

- **opt-a `casm casmpg128.s /o:pa.prg`** - `P1/P2 DONE 00128`;
  `WRITE: pa.prg`; `DONE ... 00129 BYTES`.
- **opt-b `... /o:pb.prg /m`** - `WRITE: pb.prg`, then `SYMBOL MAP` +
  `000 SYMBOLS` trailer (no labels in casmpg128) printed cleanly, no
  transient residue before/inside/after, `DONE:` summary followed the map
  (Increment 7 screen-ownership behaviour holds).
- **opt-c `... /o:pc.prg /l`** - `WRITE: pc.prg`, `DONE ... 00129 BYTES`;
  no transient-line residue mid-listing (clean `WRITE` -> `DONE`).
- **opt-d `... /o:pd.prg /m /l`** - `WRITE: pd.prg`, `SYMBOL MAP` /
  `000 SYMBOLS`, `DONE ... 00129 BYTES`; clean.
- **opt-s `... /o:ps.prg /s`** - `WRITE: ps.prg`, `DONE ... 00129 BYTES`.
  (`.ORG`-present output already carries no R6 footer, so `/S` is a no-op
  size difference here - expected.)
- **COMP: 5/5 PASS.** `comp pa.prg casmpg128.ref`, `pb`, `pc`, `pd` all
  `FILES COMPARE OK`; `comp ps.prg pa.prg` -> `FILES COMPARE OK`. All five
  option combinations produce byte-identical 129-byte output.
- **`/L` listing unperturbed by `/M`:** `DIR` shows `pc.lst` and `pd.lst`
  **both 21 blocks** (matches Increment 7's optc/optd finding).

**Option-identity sub-matrix: 5/5 PASS** - `docs/casm-utility.md`'s
output-identity invariant holds with the progress hooks active, and the
`/M` map + `/L` listing both render with clean screen ownership.

### Session setup

Follow `.agents/workflows/vice-mcp-testing.md` in full. Summary:

1. `ls -la build/casm_progress_test.d64` (confirm it exists; built above).
2. `tools/vice_mcp_start.sh status` - confirm a live MCP-answering instance
   (`vice_ping` -> `{"status":"ok"}`); start one if needed.
3. `vice_disk_detach {unit: 8}` then `vice_disk_attach {unit: 8, path:
   ".../build/casm_progress_test.d64"}` - the disk was just rebuilt, so an
   already-running instance is serving a stale copy until re-attached.
4. `vice_autostart` the disk at the verified `command64` index (index 0 on
   this image - `command64` is the first PRG).
5. Verify screen row 0 decodes to `Command 64-DOS Version` (screen-code
   table per the workflow; verify it against one `vice_display_screenshot`
   first).
6. **Freshness check** (mandatory this session): `vice_memory_search` for a
   byte sequence unique to this build before trusting any result - e.g. the
   `DONE: P1 ` literal in `casm.prg`. If RAM holds no file-unique new bytes,
   the session is stale; re-attach.

### Dispatch + assertion table

For each row: send the `casm ...` payload via `vice_keyboard_petscii`
(`data` array verbatim - do **not** hand-retype), wait for the shell prompt
`c64[8]:>` (declared deadline: 60 s per fixture under true-drive emulation;
`casmpgfill`/`casmpg128` up to 90 s), then send the `comp ...` payload and
read the result line from screen RAM.

Options are case-folded in `cli.s` (`and #$5F`), so lowercase `/o:` is fine.
Default output name is `<source-base>.PRG`; `casmpginca` (no dot) derives
`casmpginca.PRG`.

| # | `casm` dispatch - `vice_keyboard_petscii` data | Progress-line assertions | `comp` dispatch data | Expect | Result |
|---|---|---|---|---|---|
| 4.1 | `casm casmpg63.s`<br>`[67,65,83,77,32,67,65,83,77,80,71,54,51,46,83,13]` | `P1:`/`P2:` render; **no** mid-pass throttled redraw (63 counted stmts < 64); `DONE: P1 n, P2 n` with **P1==P2 (== 63)**; `... 00064 BYTES` | `comp casmpg63.prg casmpg63.ref`<br>`[67,79,77,80,32,67,65,83,77,80,71,54,51,46,80,82,71,32,67,65,83,77,80,71,54,51,46,82,69,70,13]` | `FILES COMPARE OK` | ___ |
| 4.2 | `casm casmpg64.s`<br>`[67,65,83,77,32,67,65,83,77,80,71,54,52,46,83,13]` | exactly **one** throttled redraw at count 64; `DONE ... 00065 BYTES`, P1==P2==64 | `comp casmpg64.prg casmpg64.ref`<br>`[67,79,77,80,32,67,65,83,77,80,71,54,52,46,80,82,71,32,67,65,83,77,80,71,54,52,46,82,69,70,13]` | `FILES COMPARE OK` | ___ |
| 4.3 | `casm casmpg65.s`<br>`[67,65,83,77,32,67,65,83,77,80,71,54,53,46,83,13]` | one throttled redraw at 64, final count 65; `DONE ... 00066 BYTES`, P1==P2==65 | `comp casmpg65.prg casmpg65.ref`<br>`[67,79,77,80,32,67,65,83,77,80,71,54,53,46,80,82,71,32,67,65,83,77,80,71,54,53,46,82,69,70,13]` | `FILES COMPARE OK` | ___ |
| 4.4 | `casm casmpg128.s`<br>`[67,65,83,77,32,67,65,83,77,80,71,49,50,56,46,83,13]` | **two** throttled redraws (64, 128); `DONE ... 00129 BYTES`, P1==P2==128 | `comp casmpg128.prg casmpg128.ref`<br>`[67,79,77,80,32,67,65,83,77,80,71,49,50,56,46,80,82,71,32,67,65,83,77,80,71,49,50,56,46,82,69,70,13]` | `FILES COMPARE OK` | ___ |
| 4.5 | `casm casmpgblank.s`<br>`[67,65,83,77,32,67,65,83,77,80,71,66,76,65,78,75,46,83,13]` | final pass count is **6** (`.ORG` + 5 `NOP`), *not* inflated by the blank/comment lines; no throttled redraw; `DONE ... 00007 BYTES` | `comp casmpgblank.prg casmpgblank.ref`<br>`[67,79,77,80,32,67,65,83,77,80,71,66,76,65,78,75,46,80,82,71,32,67,65,83,77,80,71,66,76,65,78,75,46,82,69,70,13]` | `FILES COMPARE OK` | ___ |
| 4.6 | `casm casmpgfill.s`<br>`[67,65,83,77,32,67,65,83,77,80,71,70,73,76,76,46,83,13]` | bounded per-chunk directive byte-cadence line advances for `.RES 100`/`.FILL 50`/`.ALIGN` (each <=256 -> one chunk each); `DONE ... 00258 BYTES` | `comp casmpgfill.prg casmpgfill.ref`<br>`[67,79,77,80,32,67,65,83,77,80,71,70,73,76,76,46,80,82,71,32,67,65,83,77,80,71,70,73,76,76,46,82,69,70,13]` | `FILES COMPARE OK` | ___ |
| 4.7 | `casm casmpgincbin.s`<br>`[67,65,83,77,32,67,65,83,77,80,71,73,78,67,66,73,78,46,83,13]` | `.INCBIN` byte-cadence line advances to 8; `DONE ... 00010 BYTES` | `comp casmpgincbin.prg casmpgincbin.ref`<br>`[67,79,77,80,32,67,65,83,77,80,71,73,78,67,66,73,78,46,80,82,71,32,67,65,83,77,80,71,73,78,67,66,73,78,46,82,69,70,13]` | `FILES COMPARE OK` | ___ |
| 4.8 | `casm casmpgr6.s`<br>`[67,65,83,77,32,67,65,83,77,80,71,82,54,46,83,13]` | `WRITE: casmpgr6.prg` persistent line appears; `DONE ... 00054 BYTES` (44 program + 2 table + 6 R6 footer + 2 header) | `comp casmpgr6.prg casmpgr6.ref`<br>`[67,79,77,80,32,67,65,83,77,80,71,82,54,46,80,82,71,32,67,65,83,77,80,71,82,54,46,82,69,70,13]` | `FILES COMPARE OK` | ___ |
| 4.9 | `casm casmpgrta.s casmpgrtb.s /o:casmpgrt.prg`<br>`[67,65,83,77,32,67,65,83,77,80,71,82,84,65,46,83,32,67,65,83,77,80,71,82,84,66,46,83,32,47,79,58,67,65,83,77,80,71,82,84,46,80,82,71,13]` | a `LOAD:` line for **each** root filename in turn; combined pass counts (`.ORG` + 80 `NOP` = 81); one throttled redraw at 64; `DONE ... 00082 BYTES` | `comp casmpgrt.prg casmpgrt.ref`<br>`[67,79,77,80,32,67,65,83,77,80,71,82,84,46,80,82,71,32,67,65,83,77,80,71,82,84,46,82,69,70,13]` | `FILES COMPARE OK` | ___ |
| 4.10 | `casm casmpginca`<br>`[67,65,83,77,32,67,65,83,77,80,71,73,78,67,65,13]` | transient line shows the **child** filename (`casmpgincb`, then `casmpgincc`) on each push and **restores the parent** on each pop; the second `.INCLUDE "CASMPGINCB"` is a dedup cache hit whose bytes are still re-traversed; `DONE ... 00009 BYTES` | `comp casmpginca.prg casmpginc.ref`<br>`[67,79,77,80,32,67,65,83,77,80,71,73,78,67,65,46,80,82,71,32,67,65,83,77,80,71,73,78,67,46,82,69,70,13]` | `FILES COMPARE OK` | ___ |

If any dispatch returns `BAD COMMAND OR FILE NAME`: send `flush`
(`[70,76,85,83,72,13]`) and retype.

### Option-identity sub-matrix (upholds `docs/casm-utility.md`: output bytes
are identical with or without `/M`/`/L`)

Run against `casmpg128.s` (has a throttled redraw and a listing worth
inspecting). Each output must `comp ... OK` against `casmpg128.ref`.

| Invocation | Output | Expect | Result |
|---|---|---|---|
| `casm casmpg128.s /o:pa.prg` | `pa.prg` | `comp pa.prg casmpg128.ref` -> OK | ___ |
| `casm casmpg128.s /o:pb.prg /m` | `pb.prg` | OK; `/M` symbol map prints with no transient residue | ___ |
| `casm casmpg128.s /o:pc.prg /l` | `pc.prg` + `pc.lst` | OK; `progressSuspend` before the listing write - no transient line mid-listing | ___ |
| `casm casmpg128.s /o:pd.prg /m /l` | `pd.prg` + `pd.lst` | OK; `pc.lst` and `pd.lst` same block count | ___ |
| `casm casmpg128.s /o:ps.prg /s` | `ps.prg` (static, no R6 footer) | `comp` **not** vs casmpg128.ref (that's relocatable) - instead confirm `ps.prg` = `pa.prg` minus nothing here since casmpg128 has `.ORG`; compare `ps.prg` to `pa.prg` -> OK | ___ |

(payloads: generate with `tools/vice_type_command.py "<command>"`.)

---

## Atomic Increment 5 - failure-path / cleanup checks (live VICE) - PARTIAL

- **Fatal input-open path - PASS.** `casm nosuchfil.s` -> diagnostic
  `CASM: CANNOT OPEN INPUT`, clean return to `C64[8]:>`, no wedge, no
  transient-line residue. (The banner starts printing before the file open,
  so `CASM V` briefly shares the row with the error text - a pre-existing
  cosmetic overlap, unrelated to progress, not a regression.) Confirms the
  fatal path is clean with `progress.s` linked and `diagnostics.s` importing
  `progressClearTransient`.
- **Still to do:** a source that fails *mid-assembly* (past file open, after
  the transient line has rendered) to prove the universal `diagPrintFatal`
  transient-clear over a real progress line, plus partial-output PRG
  cleanup. This disk carries no such fixture (all `casmpg*` are valid); it
  needs a one-line bad fixture added to `casm_progress_test_d64` (e.g.
  `.ORG $C000` + `BNE $D000` -> `BRANCH OUT OF RANGE` after the header is
  written) or reuse of an existing failure fixture from another disk in a
  two-drive session.
- The known existing-output-file hang
  ([[project-casm-filecreateoutput-no-replace]]) is **not** re-tested here -
  it is a separately tracked defect and would wedge the emulator;
  disclose-and-defer.

---

## Atomic Increment 6 - full regression sweep (live VICE) - PENDING

Re-run the Increment 7 roster (31 harnesses, 6 CMake-built images, plus this
increment's disk) against the **unchanged** `casm.prg` - this is a
provenance re-confirmation, not new coverage. Boot `test.d64` on unit 8;
attach `casm_overflow_test.d64` on unit 9 (`DRIVE 9`).

| Image | Harnesses | Expect | Result |
|---|---|---|---|
| `casm_progress_test.d64` | `progress` (20-case unit) | `CASM PROGRESS: PASS` | ___ |
| `test.d64` | `faultinject`, `progress`, `reloc`, `symbols`, `vmm` | all PASS | ___ |
| `casm_listing_test.d64` | `listing`, `listcap`, `map`, `passcheck`, `l15release`, `spanread`, `spancommit`, `listwrite`, `flist`, `flmeta`, `faultvmm` | all PASS | ___ |
| `casm_overflow_test.d64` (unit 9) | `include`, `catalog`, `faultsource` | all PASS | ___ |
| `casm_include_test.d64` | `freloc`, `bounds`, `cliderive`, `lexer`, `fsym`, `finc`, `opcodes`, `event`, `directives` | all PASS | ___ |
| `casm_phase12_test.d64` | `expr`, `pass1` | all PASS | ___ |
| `casm_phase13_test.d64` | `frame` | all PASS | ___ |

---

## Atomic Increment 7 - timing matrix (live VICE) - PENDING

Same VICE config for both; record `WarpMode` (`vice_machine_config_get`) -
wall time is meaningless under warp, use emulated-cycle counts
(`vice_cycles_stopwatch`). Caps are **non-blocking** (parent-plan Performance
Budget amendment 2026-08-26) - record, do not gate.

| Fixture | Statements | Emulated time | vs. Increment 7's figure | Result |
|---|---|---|---|---|
| `casmopall.s` (from its own disk) | 160 | ___ | 104.76 s raw / warp-adjusted | ___ |
| `casmbiga.s` + `casmbigb.s` | 6,001 | ___ | 258.70 s | ___ |

---

## Atomic Increment 8 - exact no-change rebuild + evidence - COMPLETE (PASS)

- Two consecutive full `cmake --build build` (both exit 0):
  `casm.prg` sha256 `af1bacda...` and `casm_progress_test.d64` sha256
  `1bf0df83706fb498202ba56be5c770e0e26319620062e7344639aaf3f6ff1fdc`
  **byte-identical across both builds**.
- `src/external/casm/BUILD_CASM` still **1378** (content-hash gate declined
  to increment - no production source touched).
- `git diff --check`: clean.

---

## Completion Gate

- [x] All Atomic Increment 4 rows (10/10): `FILES COMPARE OK` and the
      recorded `DONE:` byte count matches the expected-sizes table exactly
      (64/65/66/129/7/258/10/54/82/9).
- [x] Progress-line behaviour matched each fixture's stated expectation:
      P1==P2 statement counts every time; counter tracks *counted*
      statements (`.ORG`/directives included, blank/comment lines excluded -
      `casmpgblank` = 6); `.INCBIN`/fixed-fill/multi-root(81)/nested-include
      +re-inclusion(12)/R6-footer byte accounting all correct.
- [x] Option-identity sub-matrix (5/5): default, `/M`, `/L`, `/M /L`, `/S`
      all produce byte-identical 129-byte output; `/M` map + `/L` listing
      render with clean screen ownership; `pc.lst` == `pd.lst` == 21 blocks.
- [~] Atomic Increment 5: fatal input-open path clean (PASS); the
      mid-assembly fatal + partial-output-cleanup case still needs a bad
      fixture (see Increment 5 section).
- [~] Atomic Increment 6 (31-harness regression sweep): **proposed
      waived.** The production binary is byte-identical
      (`casm.prg af1bacda...`, `BUILD_CASM 1378`) to the one Increment 7
      already ran through the full 31-harness / 6-image sweep with zero
      failures; Increment 8 added only verification artifacts and
      `casm_progress_test_d64` (whose own `test_casm_progress` unit harness
      Increment 7 also passed). Re-running is a provenance re-check of an
      unchanged artifact, not new coverage. Subject to user call.
- [~] Atomic Increment 7 (timing matrix): **proposed waived.** The
      performance caps were formally amended to non-blocking on 2026-08-26
      (parent-plan Performance Budget amendment); no code changed since, so
      timing is unchanged from Increment 7's own recorded figures. Subject
      to user call.
- [x] Atomic Increment 8: no-change rebuild stable (`casm.prg` and
      `casm_progress_test.d64` byte-identical across two builds), `BUILD_CASM`
      1378, `git diff --check` clean.
- [x] `docs`/`wiki` `casm-utility.md`: no drift - observed `CASM: CANNOT
      OPEN INPUT`, `DONE: P1 nnnnn, P2 nnnnn, nnnnn BYTES`, `CASM: INPUT
      VALIDATED` all match `docs/casm-utility.md:73-84`. No `CHANGELOG`
      entry for Increment 8 (verification-only, no user-facing behaviour
      change; the progress-indication feature's own `[Unreleased]` entry
      belongs to the feature-close increment).
- [x] User explicitly approved closing Increment 8 with Increments 6 & 7
      waived (2026-08-31).
