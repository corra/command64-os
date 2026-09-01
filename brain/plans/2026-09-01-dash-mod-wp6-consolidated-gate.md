---
feature: dash-mod-wp6-consolidated-gate
created: 2026-09-01
status: approved -- in progress
taskwarrior: task 55 (child of 94ec17b3)
depends-on: DASH-MOD WP2-WP5 (all done + user-approved 2026-09-01); DASH-MOD WP1 (CASM .ASSERT ca65 keyword, done)
---

# Plan: DASH-MOD WP6 - Consolidated gate + re-baseline

## Status

**Proposed, not yet approved.** Sixth and final WP of the DASH
Modernization increment. Parent:
`brain/plans/2026-09-01-dash-modernization.md`. WP1-5 done + approved.
Branch: `feature/casm-phase14`.

Closes the whole increment. Baseline: post-WP5 shipping manifest sha256
`4a49612e...`, 4579 bytes, 451 relocation entries.

## Objective

One **fresh, together** re-verification of the fully modernized DASH
(not a per-WP citation), the version bump to **DASH `0.2.0`**, the
`AGENTS.md` consolidation, `CHANGELOG` / `KNOWLEDGE.md` / memory / tracker
close-out, a relocation audit, and the **user hardware runtime matrix**
at three load addresses. Establishes the modernized DASH as the baseline
Phase 14 WP92's consolidated gate re-verifies against.

**Delivered:**
- `DASHVERSTR` (`ddata.s`) `"0.1.4"` -> `"0.2.0"` -- the on-screen banner
  (row 24) becomes `DASH v0.2.0`. Minor bump: no user-visible behaviour
  change across the whole increment, but a substantial internal rebase
  (~200 fewer global labels, every routine constant-driven and
  helper-backed, -187 bytes since WP91).
- `src/external/dash/AGENTS.md` **consolidated** (user decision
  2026-09-01: reorganize, no information loss): the scattered per-WP
  additions (`@local`, computed constants, `.ASSERT` action keyword,
  computed key dispatch, renderer helpers) merged into coherent sections
  that describe the current structure *as designed*; now-stale framing
  removed (notably "the dual-assembler subset has no equates" -- WP3
  added them).
- `CHANGELOG.md` `[Unreleased]` gains a "DASH Modernization" block.
- `brain/KNOWLEDGE.md` DASH section (the WP1-WP9 as-built) gets a
  modernization closing note.
- `dash.ref.hex` **re-baselined** one last time (the 2-byte version
  string change): new sha256, `--cross-check MATCHES`, fresh source
  hashes.
- Relocation audit against `AGENTS.md`'s Verification-section rules for
  the final refactored code.
- The **consolidated live re-verification** (below) and the **user
  runtime matrix** (below), both recorded in the walkthrough.
- Memory `project-dash-modernization` (top-level, durable); parent plan
  status -> done; `wiki/tasks/dash-modernization.md` closed.

**Excluded (deferred / out of scope):**
- Any code change beyond the 2-byte version string. No routine touched.
- The deferred `dvmm.s` refactor (`DVMMLABEL` + enum->string tables) --
  recorded in the WP5 walkthrough as a "WP5b"/post-increment follow-up;
  not part of WP6.
- Anonymous labels (`:+`/`:-`) -- no CASM equivalent.
- Phase 14's own WP92 work (CASM `0.6.0`, all `test_casm_*` harnesses) --
  a separate Phase 14 gate on the same branch. WP6 only ensures the
  DASH side is closed and cited-able there.
- Sourcing DASHVERSTR from a generated `.inc` -- `ddata.s`'s own comment
  explains why the banner stays a hand-edited static string (immune to
  the `PRINTDEC16` spacing bug it exists to help diagnose); unchanged.

## Scoping Decisions (user-confirmed 2026-09-01)

1. **DASH version -> `0.2.0`.** Minor bump marks the modernization
   milestone; patch would under-state a full structural rebase, `1.0.0`
   would over-claim.
2. **`AGENTS.md`: consolidate + reorganize, no information loss.** Every
   hard-won ca65/CASM gotcha in the per-WP notes is kept; the file is
   restructured to read as current-state design docs, not a diff log.

## Consolidated live re-verification (the "fresh, together" part)

Run from the current tree in one pass -- *not* "each WP passed":

1. `check_casm_source_bytes.py` on all 7 shipped sources -> clean.
2. `rm build/dash_ref.prg build/dash.prg build/command64_casm_utils.d64`;
   `cmake --build build --target dash_ref` -> builds, **all 21 `.assert`s
   pass**, `tools/reloc.py` clean. Record final code size + relocation
   count.
3. **Native CASM under VICE** (`CASM V0.5.2.xxxx`, 16MB REU): fresh
   `command64_casm_utils_d64`, `CASM DMAIN.S /O:DW6.PRG` -> `INPUT
   VALIDATED`; `COMP DW6.PRG DASH.REF` -> **`FILES COMPARE OK`**. Extract
   `DW6.PRG`; `cmp` vs `build/dash_ref.prg` -> byte-identical.
4. `build_dash_manifest.py <native DW6.PRG> --cross-check
   build/dash_ref.prg` -> **new sha256** (version bytes), `--cross-check
   MATCHES`, **all 7** `source_sha256` fresh, **no `--allow-host-bytes`**.
5. `cmake --build build --target dash` (`dash.prg` == native), full
   `cmake --build build`, `image_d64`, `test_image_d64`, `release` (if
   present) -> all clean.

## Relocation audit

Walk `AGENTS.md`'s Verification-section rules against the final code:
- **Entries expected:** `PAGEROUTINETABLE`'s 3 `.WORD` renderer pointers;
  absolute label operands (`JSR`/`JMP`/`LDA label`); `#>label` high bytes
  (the `dscr.s` `COPYFRAMEROW` call sites, `dsys.s` `DSYSLABEL` sites,
  etc.).
- **No entries:** `$1000` (`OS_API`), `$FFE4` (`KERNAL_GETIN`),
  screen/colour RAM (`$0400`-`$07FF` / `$D800`-`$DBFF`), ZP `$70`-`$8F`,
  `#<label` low bytes, ZP-indirect `(ptr),Y`.
- Confirm `reloc.py`'s final count is fully accounted for (WP4: 465->459,
  WP5: 459->451, both audited in their walkthroughs; WP6 changes only a
  data string -> **0 reloc delta expected**).

## User hardware runtime matrix

Agent drives live under VICE; **user confirms the hardware/visual
result and gives the sign-off** (`feedback-vice-testing`: the agent
reports, the user confirms). On `build/image.d64`, at each of three load
addresses (the `LOAD DASH <hex>` / `RUN <hex>` mechanism used for the
WP84 relocation spot-check):

| base | checks |
| --- | --- |
| `$3800` (shell default) | System page renders every field; F3 -> Applications (slot 0 `dash 3800-....`, flag column `u---`); F5 -> VMM Test; `T` -> VMM test runs to a terminal state (`PASSED` with REU present); `R` -> redraw; F1 -> System; `Q` -> `c64[<dev>]:>` |
| `LOAD DASH 5000` / `RUN 5000` | System page renders; F3 -> Applications reports `dash 5000-....`; F1/F3/F5 nav, `R`, `Q` |
| `LOAD DASH 9000` / `RUN 9000` | System page renders; F3 -> Applications reports `dash 9000-....`; F1/F3/F5 nav, `R`, `Q` |

At every base the row-24 banner reads **`DASH v0.2.0`**. Screen-RAM /
screenshot evidence in the walkthrough for each.

## Atomic Increments

1. **Version bump.** `DASHVERSTR` `"0.1.4"` -> `"0.2.0"` (`ddata.s`).
   `cmake --build build --target dash_ref`: builds, `.assert`s pass,
   `reloc.py` clean. `cmp` vs the WP5 manifest transcription -> **exactly
   2 bytes differ** (positions of `1`->`2` and `4`->`0` in the version
   string); nothing else moved.
2. **`AGENTS.md` consolidation.** No code impact; `check_casm_source_
   bytes` unaffected (`AGENTS.md` is not assembled).
3. **Consolidated re-verify + native CASM + manifest re-baseline** (the
   6-step pass above).
4. **User runtime matrix.** Agent runs the three-base matrix live;
   records evidence; requests the user's hardware confirmation.
5. **Close-out.** `CHANGELOG.md` "DASH Modernization" block;
   `brain/KNOWLEDGE.md` DASH-section closing note; memory
   `project-dash-modernization`; `wiki/tasks/dash-modernization.md` ->
   closed; parent plan status -> done + final Progress; walkthrough
   (consolidated -- WP1-6 summary + this WP's fresh evidence).

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/dash/ddata.s` | Modify -- `DASHVERSTR` `"0.1.4"` -> `"0.2.0"` |
| `src/external/dash/AGENTS.md` | Modify -- consolidate/reorganize (no info loss) |
| `src/external/dash/dash.ref.hex` | **Re-baseline** -- new sha256 (2 version bytes), fresh source hashes |
| `src/external/dash/BUILD_DASH_REF` | Auto |
| `CHANGELOG.md` | Modify -- `[Unreleased]` "DASH Modernization" block |
| `brain/KNOWLEDGE.md` | Modify -- DASH section modernization closing note |
| `brain/plans/2026-09-01-dash-modernization.md` | Modify -- status -> done, final Progress |
| `wiki/tasks/dash-modernization.md` | Modify -- close |
| `brain/walkthroughs/2026-09-0X-dash-mod-wp6-consolidated-gate.md` | Create -- consolidated |
| memory `MEMORY.md` + `project-dash-modernization.md` | Create/Modify |

## Stop Conditions

- ca65 `dash_ref` and native CASM disagree by a single byte.
- The byte delta vs the WP5 manifest is anything **other than** the 2
  version-string bytes.
- `reloc.py`'s entry count changes (a data-string edit must not move any
  relocation entry -- if it does, stop and investigate).
- Any runtime failure at any of the three bases: a page renders wrong, a
  key is dead or does the wrong thing, the VMM test misbehaves, a
  relocated load fails, or the banner is not `DASH v0.2.0`.
- The relocation audit finds an unaccounted or missing entry.
- `build_dash_manifest.py` would need `--allow-host-bytes`.
- A construct outside the dual-assembler subset is somehow needed.
- A genuinely new defect outside this increment's scope -> disclose and
  defer (a separate follow-up), not an inline fix, unless the user
  directs otherwise in the moment.

## Documentation, Task, and Tracker Updates

- **At approval:** Taskwarrior WP6 (child of `94ec17b3`).
- **At completion:** consolidated walkthrough; `CHANGELOG.md`;
  `brain/KNOWLEDGE.md` closing note; memory `project-dash-modernization`
  (durable top-level record of the whole increment) + `MEMORY.md`
  pointer; parent plan Progress + status -> done;
  `wiki/tasks/dash-modernization.md` -> closed; the parent Taskwarrior
  task `94ec17b3` -> done (after user sign-off).

## Completion Gate

- **DASH `0.2.0`:** `DASHVERSTR` bumped; the `DASH v0.2.0` banner
  verified on screen at all three load bases.
- **Consolidated fresh verification:** ca65 `dash_ref` == native CASM
  `DASH.PRG` == re-baselined manifest, byte-for-byte; all 21 `.assert`s
  pass; `reloc.py` clean; final size + reloc count recorded. `dash.ref.
  hex` re-baselined -- new sha256, `--cross-check MATCHES`, all 7 source
  hashes fresh, **no `--allow-host-bytes`**; the walkthrough states the
  old (`4a49612e...`) and new sha256.
- **Relocation audit:** `AGENTS.md`'s rules hold for the final code;
  entry count fully accounted for.
- **`AGENTS.md` consolidated:** reads as current-state design docs; no
  technical detail lost; no stale framing.
- **`CHANGELOG.md`** "DASH Modernization" block present.
- **User runtime matrix:** all three bases (`$3800` / `LOAD DASH 5000` /
  `LOAD DASH 9000`), all three pages, F1/F3/F5 / `R` / `T` / `Q` --
  agent-run with evidence, **user-confirmed**.
- `brain/KNOWLEDGE.md` closing note; memory `project-dash-modernization`;
  parent plan status -> done; wiki closed.
- Full `cmake --build build` + `image_d64` + `test_image_d64` clean.
- **Explicit user approval closing WP6 AND the DASH Modernization
  increment.**
- **Note for Phase 14 WP92:** the modernized DASH (`0.2.0`, this
  manifest) is the baseline WP92's consolidated gate re-verifies
  against; WP92 re-cites this gate (or does a fresh DASH build for its
  own records) rather than re-running DASH's runtime matrix.

## Progress

- 2026-09-01: Drafted for review. Scoping decisions 1-2 captured
  (version -> `0.2.0`; `AGENTS.md` consolidate, no info loss). The
  three-base user runtime matrix uses the established `LOAD DASH <hex>` /
  `RUN <hex>` mechanism (WP84 relocation spot-check precedent).
- 2026-09-01: **Approved.** Taskwarrior task 55. Pre-WP6 bytes
  (`4a49612e...`, 4579 B) snapshot.
- 2026-09-01: **Increment 1 complete -- version bump.** `DASHVERSTR`
  `"0.1.4"` -> `"0.2.0"` (`ddata.s`). ca65 `dash_ref` builds, all 21
  `.assert`s pass, `reloc.py` **451** points (unchanged -- a data-string
  edit moves no relocation entry). `cmp -l` vs the WP5 manifest: **exactly
  2 bytes differ** (offsets 2557 `$31`->`$32`, 2559 `$34`->`$30` -- the
  `1`->`2` and `4`->`0` of the version string; the `.` at 2558 unchanged).
  Size 4579, unchanged. (Also corrected a stale WP5 doc figure: the
  post-WP5 reloc count is 451, not the "443" the WP5 inc6-7 commit
  mis-stated -- fixed in the WP5 walkthrough, parent plan, wiki, memory.)
