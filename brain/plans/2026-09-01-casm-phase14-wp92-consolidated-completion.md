---
feature: casm-phase14-wp92-consolidated-completion
created: 2026-09-01
status: complete
taskwarrior: 56711c7e-8cb8-44ed-8215-4f092cab69d6 (task 42, "WP92: Phase
  14 consolidated completion gate, version promotion to 0.6.0", project
  casm.phase14)
depends-on: CASM Phase 14 WP86/87/88/89/90/91, all complete and
  user-approved, all merged into feature/casm-phase14
---

# Plan: CASM Phase 14 WP92 - Consolidated Completion Gate

## Status

**Complete — user-approved 2026-09-01.** CASM Phase 14 (WP86-92) fully
closed at `0.6.0` build `1405`. Walkthrough:
`brain/walkthroughs/2026-09-01-casm-phase14-wp92-consolidated-completion.md`.
One regression the sweep found (`test_casm_flmeta` case 6) was
root-caused as a stale test fixture (memory-opt Finding D cap 63→32) and
fixed harness-only under separate task 43 (`8da90f45`, user-approved and
closed).

Parent plan:
`brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md` — see its
own **Completion Gate** and the **WP92** Atomic Increment for the frozen
scope this plan expands.

Branch: continue on `feature/casm-phase14` (WP86-91 already merged in; the
unrelated DASH Modernization WP1-6 increment also landed on this branch
after WP91 and is closed/approved — `project-dash-modernization-complete`).

## Objective

Close the whole of CASM Phase 14 (WP86-91: `@name` cheap-local labels
scoped to the nearest preceding global label — lexer, symbol-layer scope
filtering, pass-driver wiring, scoped diagnostics, `/M` qualified-name
rendering, DASH adoption) per the parent plan's completion gate:

- a **fresh consolidated regression sweep** — every `test_casm_*` harness
  and every Phase 14 production fixture re-run *together* in one
  continuous set of live-VICE sessions, not by citing each WP's own
  individual pass (the project's WP46 / WP63 / WP76 precedent: a full
  re-run together has repeatedly caught cross-harness defects a narrower
  pass missed);
- proof that a **no-locals program still assembles byte-identical** to its
  pre-Phase-14 output (the parent plan's central risk gate);
- **version promotion to CASM `0.6.0`** (completion-only bump, no behavior
  change in the same commit — the `0.3.0`→`0.4.0` WP85 / `0.2.8`→`0.3.0`
  WP75 precedent);
- **documentation reconciliation** — user-facing docs gain a "Local
  labels" section, trackers and CHANGELOG/KNOWLEDGE synchronized;
- a **consolidated completion-gate walkthrough** in `brain/walkthroughs/`
  with live evidence, submitted for explicit user sign-off of the whole
  phase.

**Not in scope:** any new local-label behavior, any fix to a defect found
during the sweep (default is disclose-and-defer as a separate,
separately-approved follow-up — see Stop Conditions), anonymous labels
(`:`/`:+`/`:-`, deferred to their own phase per the parent plan).

## Scoping Decisions (user-confirmed 2026-09-01)

1. **WP91 is approved.** Confirmed retroactively this session; the DASH
   Modernization increment had already been built on top of it. Logged in
   the parent plan's Progress.
2. **Dedicated WP92 plan file** (this document), mirroring Phase 13's
   `2026-08-21-casm-phase13-wp85-consolidated-completion.md`, rather than
   proceeding under the parent plan's one-paragraph WP92 bullet.
3. **Full sweep** (not a Phase-14-only subset): re-run *every*
   `test_casm_*` harness live, matching the WP85 / WP75 phase-closing
   precedent, because that precedent's own sessions found real
   cross-harness defects (WP76) a narrower sweep would have missed.

## Research / open items to settle at Increment 1

- **Exact harness roster.** Phase 13 WP85 swept 29 harnesses. Phase 14
  added `test_casm_scope` (WP88); the earlier unnumbered progress feature
  added `test_casm_progress`. Working assumption: **31 harnesses**.
  Increment 1 re-derives the authoritative list and the harness→disk map
  by direct `grep` against `CMakeLists.txt` / `cmake/*.cmake`
  (`add_c64_disk_image` `PRGS` lines, `REMOVE_ITEM` relocations), not from
  this plan or from WP85's now-potentially-stale table.
- **DASH baseline.** WP91's own byte-identity check recorded DASH at
  `4766 B` / manifest `3238b786`. The **DASH Modernization increment then
  changed DASH after WP91** (`0.1.4`→`0.2.0`, `4766`→`4579 B`, manifest
  `3238b786`→`3b4d0693` — `project-dash-modernization-complete`). WP92's
  DASH re-verification therefore checks against the **current committed
  `dash.ref.hex` manifest** (`3b4d0693`), and additionally confirms the
  WP91 `@local` adoptions in `dfmt.s` (`FORMATDEC16`/`PETTOSCREEN`/`DIV10`
  → `@LOOP`/`@DONE`/`@SKIP`) survived the DASH-MOD refactor intact.
- **No-locals regression set.** Parent plan names "at minimum `casmhello`,
  `casmmodes`, `casmchain1`, a Phase 13 `.res`/`.fill` fixture". Increment
  1 confirms these fixture names still exist and picks the Phase 13
  witness (`casmassert1` / `casmres1`), each COMP-verified against its
  unchanged committed `.ref`.
- **`c64-overlay-api` MCP** was down for the entire WP89/WP90/WP91 session
  (`feedback-overlay-api-curl-fallback`). If still down, fire test events
  via `curl http://127.0.0.1:8000/event`; if the HTTP API is also down,
  note it and proceed (build events still auto-fire via `cmake --build`).

## Atomic Increments

1. **Roster + map + full clean rebuild.** Re-derive the authoritative
   `test_casm_*` harness list and harness→disk-image map from
   `CMakeLists.txt` / `cmake/*.cmake` (direct grep, recorded in the
   Progress log). Confirm the no-locals regression fixture names and the
   current DASH manifest hash. Then `rm -rf build && cmake -B build &&
   cmake --build build` — zero errors, overflows, or unresolved externals.
   Record the pre-promotion CASM version banner (`0.5.2` build N) as the
   baseline every subsequent check runs against.
2. **Consolidated harness sweep, disk-session leg per shared disk.**
   Group the harnesses by disk image (from Increment 1's map) and run
   each group in one boot/attach, per `vice-mcp-testing` (boot Command64,
   `FLUSH` before/after, fire `c64-overlay-api` test/pass/fail events).
   Every harness dispatched from the Command64 shell, each confirmed
   `... PASS` with a clean shell return. `casm_phase14_test.d64` carries
   `test_casm_scope` — run it in that leg. Non-bootable
   `casm_overflow_test.d64` uses the companion-disk-on-unit-9 pattern
   (`project-vice-two-drive-test-setup`).
3. **Phase 14 production fixtures, re-run together** on
   `casm_phase14_test.d64` in one continuous session:
   - accepted / COMP-verified: `casmloc1`, `casmloc2`, `casmloc3`,
     `casmloc7` → each `FILES COMPARE OK` against its committed
     hand-derived `.ref`;
   - rejected / scoped-diagnostic: `casmlocnoscope` → `LOCAL WITHOUT
     SCOPE`; `casmlocdup` → scoped `DUPLICATE`; `casmlocundef` → scoped
     `UNDEFINED`; `casmlocconstl` / `casmlocconstr` → `LOCAL IN CONSTANT`
     — each at its documented source location, matching WP89's own
     recorded result;
   - `/M` rendering: `casmmaploc` → qualified rows (`MAIN@LOOP`,
     `DRAW@DONE`); `casmmapconst` → no `SYMBOL MAP INVALID` (WP90's
     folded-in latent constant fix), matching WP90's recorded output.
4. **No-locals byte-identity gate.** For each fixture in the regression
   set from Increment 1: assemble live on the current CASM build and
   `COMP` the output against its unchanged committed `.ref` →
   `FILES COMPARE OK`. Additionally re-confirm one `/L` listing
   byte-identical to its pre-Phase-14 baseline for a no-locals program
   (WP90's `/L` non-regression check).
5. **DASH re-verification.** Fresh `dash_ref` (ca65) build's SHA-256
   matches the current committed `dash.ref.hex` manifest hash
   (`3b4d0693...`, confirmed at Increment 1). Confirm the `dfmt.s`
   `@local` adoptions are still present and still locally-referenced
   (grep). No full hardware re-run — WP91 did that this phase, and
   DASH-MOD WP6 did its own consolidated runtime matrix; re-doing it here
   would be redundant, not a fresh cross-check. (If the host-side hash
   check disagrees → Stop Condition.)
6. **Version promotion.** `src/external/casm/casm.s`: `VERSION_MINOR`
   `"5"`→`"6"`, `VERSION_STAGE` `"2"`→`"0"` (`0.5.2` → `0.6.0`). Rebuild
   `casm`; live-verify the banner reads `CASM V0.6.0.<build>` and that one
   Phase 14 accepted fixture still `COMP`s `FILES COMPARE OK` — proving
   the bump is behavior-neutral (same-commit precedent, WP85/WP75).
7. **MAIN envelope + no-change rebuild.** Confirm CASM MAIN is still
   within the approved `$7400` envelope (map/size check). A second
   `cmake --build build` after Increment 6 triggers zero further
   compile/link work; only the version-bump commit differs from
   Increment 1's baseline.
8. **Documentation reconciliation.**
   - `docs/casm-programmers-reference.md`: new "Local labels" section —
     `@name:` definition / `@name` reference, the one-level scope rule
     (opened by a global label, closed by the next or EOF), the four
     diagnostics (`LOCAL WITHOUT SCOPE`, scoped `DUPLICATE`, scoped
     `UNDEFINED`, `LOCAL IN CONSTANT`), `/M` qualified-name rendering
     (`<owner>@<local>`), and — stated explicitly, not left as an
     internal limit — the **constant-RHS restriction as a known
     ca65 / Turbo Macro Pro divergence** (parent plan Research item 7).
   - `docs/casm-utility.md`: brief mention in the syntax overview.
   - `wiki/casm-programmers-reference.md`, `wiki/casm-utility.md`,
     `wiki/Home.md`: mirror the doc changes.
   - `wiki/tasks/casm.md` + `brain/task.md`: Phase 14 closeout paragraph,
     WP86-92 all ticked, "Current Milestone" advanced (the tracker is
     currently stale at WP89/WP90 — bring it fully current).
   - `brain/KNOWLEDGE.md`: new "CASM Phase 14 Complete" closing section,
     mirroring the existing Phase 12 / Phase 13 sections' shape (scope
     delivered, deferred anonymous labels, the real defects WP88/WP89
     found live, the ca65/TMP divergence).
   - `CHANGELOG.md`: new `[Unreleased] → Added` entry for Phase 14
     `@local` labels (CASM `0.5.x` → `0.6.0`), mirroring the Phase 13
     entry's shape.
9. **Memory.** New top-level `project-casm-phase14-complete` record;
   update `MEMORY.md` index line. Supersede nothing that isn't actually
   superseded. Note the ca65/TMP divergence cross-links
   `reference-local-label-in-constant-precedent` and
   `reference-casm-constant-rhs-and-assert-operator-limits`.
10. **Consolidated walkthrough.**
    `brain/walkthroughs/2026-09-01-casm-phase14-wp92-consolidated-completion.md`
    — every leg's live evidence (COMP transcripts, VICE screenshots /
    register reads, overlay test events, the `0.6.0` banner), for the
    whole phase, not just WP92. Submit for explicit user sign-off.

## Expected Files

| File | Planned action |
| --- | --- |
| `brain/plans/2026-09-01-casm-phase14-wp92-consolidated-completion.md` | Create (this file); append Progress |
| `brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md` | Modify — append Progress (WP91 approval, WP92 close) |
| `src/external/casm/casm.s` | Modify — version bump `0.5.2` → `0.6.0` (Increment 6) |
| `docs/casm-programmers-reference.md` | Modify — new "Local labels" section |
| `docs/casm-utility.md` | Modify — syntax-overview mention |
| `wiki/casm-programmers-reference.md`, `wiki/casm-utility.md`, `wiki/Home.md` | Modify — mirror |
| `wiki/tasks/casm.md`, `brain/task.md` | Modify — Phase 14 closeout, WP86-92 ticked |
| `brain/KNOWLEDGE.md` | Modify — new "CASM Phase 14 Complete" section |
| `CHANGELOG.md` | Modify — `[Unreleased] → Added` Phase 14 entry |
| `brain/walkthroughs/2026-09-01-casm-phase14-wp92-consolidated-completion.md` | Create |
| memory: `MEMORY.md` + `project_casm_phase14_complete.md` | Modify / Create |

No CASM source (other than the version bump) and no DASH source changes
expected — this WP is verification and documentation, not new
implementation.

## Stop Conditions

Halt and get renewed direction if:

- any `test_casm_*` harness fails unexpectedly, including a
  currently-passing one regressing;
- any Phase 14 production fixture (COMP-verified or diagnostic-verified)
  disagrees with its own WP's original recorded result;
- **any no-locals regression fixture fails to `COMP` byte-identical**, or
  a no-change rebuild alters any assembled `.ref` artifact — this is the
  parent plan's central risk gate;
- the DASH manifest hash check disagrees with the current committed
  `dash.ref.hex`, or the `dfmt.s` `@local` adoptions are missing;
- CASM MAIN cannot be confirmed within the approved `$7400` envelope
  (raising it is a separate, separately-approved decision);
- a no-change rebuild (Increment 7) changes anything beyond the version
  bump itself;
- a genuinely new defect surfaces (the whole point of a full sweep, per
  WP76's precedent): **disclose and defer** as a separate,
  separately-approved follow-up — do not fix inline as part of closing the
  phase, unless the user explicitly directs it in the moment (record the
  deviation in this plan and the walkthrough).

## Documentation, Task, and DOX Updates

- Taskwarrior: WP92 task `56711c7e` (task 42) created under project
  `casm.phase14` on approval of this plan; marked complete alongside the
  Phase 14 parent task (`4cf10e7c`) at close.
- `wiki/tasks/casm.md` / `brain/task.md`: WP92 entry, Phase 14 marked
  fully closed, milestone advanced — at completion (Increment 8).
- `CHANGELOG.md` / `brain/KNOWLEDGE.md`: whole-phase closing entries — at
  completion (Increment 8).
- User-facing docs (`docs/*.md`, `wiki/*.md`): at completion (Increment
  8), per the parent plan's own Documentation section.
- Memory: at completion (Increment 9).

## Completion Gate

Phase 14 is complete only when **all** of:

- every `test_casm_*` harness re-run live in VICE in one continuous set of
  sessions, all PASS;
- all Phase 14 production fixtures re-verified together (COMP-exact or
  correct scoped diagnostic, matching each WP's original result);
- a no-locals program proven byte-identical to its pre-Phase-14 output,
  and one `/L` listing proven byte-identical;
- DASH manifest hash re-confirmed against the current committed value;
- CASM promoted to `0.6.0`, banner confirmed live; MAIN within `$7400`;
  both link configs pass; test images build; build-number check passes;
- full clean rebuild and no-change rebuild both stable;
- `docs/casm-programmers-reference.md` "Local labels" section written
  (including the ca65/TMP divergence), wiki mirrors updated;
- all trackers synchronized (Taskwarrior, `brain/task.md`,
  `wiki/tasks/casm.md`, `brain/KNOWLEDGE.md`, `CHANGELOG.md`, memory);
- consolidated completion-gate walkthrough recorded in
  `brain/walkthroughs/` with real evidence — not per-WP citations;
- **explicit user approval** to close WP92 and the whole of Phase 14. No
  self-declared completion.

## Progress

- 2026-09-01: Plan drafted for review. Scoping decisions 1-3 captured
  from the user (WP91 approved; dedicated WP92 plan file; full sweep).
  Taskwarrior task 42 (`56711c7e`) created under project `casm.phase14`,
  depends on WP91.
- 2026-09-01: **Plan approved** ("go for it all unless there are
  problems").
- 2026-09-01: **Increment 1 complete.**
  - Authoritative harness roster: **31** `test_casm_*` harnesses
    (`ls -d tests/src/casm_*`), target name = `test_<basename>` via the
    `file(GLOB ... tests/src/*/*.s)` loop at `CMakeLists.txt:525`.
  - Harness -> disk-image map (from `add_c64_disk_image` `PRGS` lines +
    the `REMOVE_ITEM TEST_IMAGE_PRG_TARGETS` block at
    `CMakeLists.txt:1735-1837`):
    - `test.d64` (bootable): reloc, symbols, vmm, faultinject, progress (5)
    - `casm_overflow_test.d64` (NOT bootable, companion-disk pattern):
      include, catalog, faultsource (3)
    - `casm_include_test.d64` (bootable): freloc, bounds, cliderive,
      lexer, fsym, finc, opcodes, event, directives (9)
    - `casm_phase12_test.d64` (bootable): expr, pass1 (2) [lexer dup, run once]
    - `casm_phase13_test.d64` (bootable): frame (1)
    - `casm_phase14_test.d64` (bootable): scope (1) + all Phase 14
      production fixtures
    - `casm_listing_test.d64` (bootable): listing, listcap, map,
      passcheck, spanread, spancommit, listwrite, flist, flmeta,
      faultvmm (10)
    - Total 5+3+9+2+1+1+10 = 31.
  - No-locals regression set confirmed present
    (`tests/fixtures/casm/`): `casmhello`, `casmmodes`, `casmchain1`,
    plus Phase 13 witnesses `casmres1` / `casmassert1` (all `.ref.hex`).
  - Current committed DASH manifest (`src/external/dash/dash.ref.hex`):
    4579 bytes, sha256
    `3b4d0693a6413e7e7d328f18276b6beae3d5cbecccbe7578cfe9a13504121984`
    (DASH 0.2.0, post DASH-MOD WP6).
  - `rm -rf build && cmake -B build && cmake --build build` -> exit 0,
    no errors / overflows / unresolved externals. A second
    `cmake --build build` recompiled/relinked nothing (only the disk
    `POST_BUILD` cc1541 append commands re-run, a known project quirk).
  - Baseline CASM version: `0.5.2` build `1404` (`BUILD_CASM` = 1404,
    unchanged by the rebuild). `casm.prg` 32532 bytes.
  - MAIN envelope: manual `ld65 -m` link -> CODE+RODATA+BSS occupy
    `$3800`-`$A492`; MAIN `start=$3800 size=$7400` (end `$AC00`) ->
    **1902 bytes headroom**, within the approved `$7400` envelope.
- 2026-09-01: **Increment 2 (harness sweep) PARTIAL, then halted on a
  Stop Condition (VICE instability).** Overlay `test/testing` event fired
  (HTTP API up this session). Baseline banner: `Command 64-DOS Version
  0.4.1.2680` on `test.d64`.
  - Leg 1 (`test.d64`, unit 8): all 5 PASS, each with clean shell return
    - `test_casm_reloc` -> `CASM RELOC: PASS`
    - `test_casm_symbols` -> `CASM SYMBOLS: PASS`
    - `test_casm_vmm` -> `CASM VMM: PASS`
    - `test_casm_faultinject` -> `CASM FAULTINJECT: PASS`
    - `test_casm_progress` -> `CASM PROGRESS: PASS` (full name gave
      `BAD COMMAND OR FILE NAME`; dispatched as the 16-char directory
      name `test_casm_progre` after `flush` -- worth noting for the
      walkthrough, not a product fault)
  - Leg 2 (`casm_overflow_test.d64`, unit 9, companion-disk pattern):
    - `test_casm_include` -> `CASM INCLUDE: ALL PASS`
    - `test_casm_catalog` -> `CASM CATALOG: PASS`
    - `test_casm_faultsource` -> **NOT VERIFIED**: the VICE instance
      died (port 7000 stopped answering) during/just after this
      harness's load. Restarted via `tools/vice_mcp_start.sh start`,
      re-attached both disks, re-booted Command64 cleanly (banner
      confirmed) -- then the instance **died a second time** on a bare
      `vice_keyboard_petscii` call, before `test_casm_faultsource` was
      even re-dispatched. Second crash is not faultsource-specific.
    - Process state is now confused: a stray `x64sc` on port **7001**
      (PID 1165641) is running alongside the dead 7000; the MCP tool
      targets 7000.
  - **Halted per the workflow's "if the same stage fails again, stop
    calling tools and preserve the evidence" rule and the plan's
    Stop Conditions (harness/VICE lifecycle failure).** This is a
    harness/environment failure, not a product failure -- every CASM
    harness that actually ran passed. Awaiting user direction on the
    VICE instance before resuming the sweep (legs 2-tail through 7).
- 2026-09-01: **Increment 2 resumed.** User confirmed a second agent was
  interfering with the VICE instance; instructed to restart the MCP
  server and continue. `tools/vice_mcp_start.sh stop`+`start` -> single
  clean instance PID 1170027 on port 7000. Root cause of the crashes:
  the interfering agent, compounded by my own direct `curl` JSON-RPC to
  port 7000 racing the MCP tool client on the same single-threaded
  embedded server (one more crash during `test_casm_lexer`). Switched to
  **MCP tool calls only** (no raw curl to :7000) -- stable thereafter.
  - Leg 2 tail (`casm_overflow_test.d64`, unit 9): `test_casm_faultsource`
    -> `CASM FAULT SOURCE: PASS`. Leg 2 now complete (3/3).
  - Leg 3 (`casm_include_test.d64`, unit 8): all 9 PASS, clean shell
    return each --
    - `test_casm_freloc` -> `CASM FAULT RELOC: PASS`
    - `test_casm_bounds` -> `CASM BOUNDS: PASS`
    - `test_casm_cliderive` -> `CASM CLIDERIVE: PASS`
    - `test_casm_lexer` -> `CASM LEXER: PASS`
    - `test_casm_fsym` -> `CASM FAULT SYMBOLS: PASS`
    - `test_casm_finc` -> `CASM FAULT INCLUDE: PASS`
    - `test_casm_opcodes` -> `CASM OPCODES: PASS`
    - `test_casm_event` -> `CASM EVENT TESTS PASS`
    - `test_casm_directives` -> `CASM DIRECTIVES: PASS`
  - Running total: 16 / 31 harnesses PASS (legs 1-3). Dispatch note:
    all harnesses dispatched by their 16-char CBM directory name
    (`_`->`.`) to sidestep the `test_casm_progress` full-name miss seen
    in leg 1.
  - Leg 4 (`casm_phase12_test.d64`): `test_casm_expr` -> `CASM EXPR:
    PASS`; `test_casm_pass1` -> `CASM PASS1: PASS`.
  - Leg 5 (`casm_phase13_test.d64`): `test_casm_frame` -> `CASM FRAME:
    PASS`.
  - Leg 6 (`casm_phase14_test.d64`): `test_casm_scope` -> `CASM SCOPE:
    PASS`.
  - Increment 3 (Phase 14 production fixtures, `casm_phase14_test.d64`,
    all on `CASM V0.5.2.1404`): **11 / 11 match their WP89/WP90 recorded
    results.**
    - `casmloc1` / `casmloc2` / `casmloc3` / `casmloc7` -> `casm <f>.s`
      then `comp <f>.prg <f>.ref` -> `FILES COMPARE OK` (incl. the
      forward-local-ref `casmloc3`).
    - `casmlocnoscope` -> `LOCAL LABEL BEFORE ANY GLOBAL LABEL` AT LINE 2,
      COL 1; `casmlocdup` -> `DUPLICATE LOCAL LABEL IN SCOPE` AT LINE 5,
      COL 1; `casmlocundef` -> `UNDEFINED LOCAL LABEL` AT LINE 3, COL 9
      (Pass 2); `casmlocconstl` -> `LOCAL LABEL NOT ALLOWED IN CONSTANT`
      AT LINE 3, COL 4; `casmlocconstr` -> same, AT LINE 5, COL 6.
    - `casm casmmaploc.s /m` -> `$C000 MAIN` / `$C000 MAIN@LOOP` /
      `$C003 DRAW` / `$C003 DRAW@DONE` / `004 SYMBOLS`.
    - `casm casmmapconst.s /m` -> `$C000 START` / `$0005 FOO` /
      `002 SYMBOLS`, **no** `SYMBOL MAP INVALID`.
  - Leg 7 (`casm_listing_test.d64`): 9 PASS, **1 FAIL** --
    `test_casm_listing` `LISTING: PASS`, `test_casm_listcap` `LISTCAP:
    PASS`, `test_casm_map` `MAP: PASS`, `test_casm_passcheck` `PASSCHECK:
    PASS`, `test_casm_spanread` `SPANREAD: PASS`, `test_casm_spancommit`
    `SPANCOMMIT: PASS`, `test_casm_listwrite` `LISTWRITE: PASS`,
    `test_casm_flist` `FAULT LIST: PASS`, `test_casm_faultvmm` `FAULT
    VMM: PASS`; **`test_casm_flmeta` -> `CASM FAULT META: FAIL`**.
- 2026-09-01: **STOP CONDITION HIT -- `test_casm_flmeta` regression.**
  - `test_casm_flmeta` (`casm_faultinject_listing_meta`) FAILS its
    **case 6, `resolveMaxIncludedName`** (marker line `.....f...`).
    Deterministic: re-run twice more, identical `.....f...` /
    `CASM FAULT META: FAIL` each time; drive channel clean (`00, ok`)
    between runs. The other 8 cases pass.
  - `resolveMaxIncludedName` exercises `listing`/`include` filename
    resolution for a **63-char (max) include name** with a `"11:"`
    device prefix -> expected resolved length 66. Unrelated to
    local-label scope -- this is the listing/include catalog path
    (cf. `project-casm-include-listing-mismatch`, resolved 2026-08-07).
  - **Regression window narrowed:** `test_casm_flmeta` was
    `CASM FAULT META: PASS` at the **progress-feature completion gate
    (`brain/walkthroughs/2026-08-24-casm-progress-increment11-completion-
    gate.md:110`)**, so the regression landed **after 2026-08-24**.
    Candidates: memory-optimization WP (task 42, closed 2026-08-31, CASM
    `0.5.1`, "5 findings, zero behavior change"); `progclear` early-fatal
    fix (task 43, `0.5.2` b1392); Phase 14 WP86-91; the diag-table
    single-source-of-truth hardening. (DASH-MOD is DASH-only.)
  - Per this plan's Stop Conditions ("a currently-passing harness
    regressing" + "do not fix forward, stop" + "disclose and defer as a
    separate, separately-approved follow-up"): **sweep halted at 30/31**.
    All other 30 harnesses PASS, all 11 Phase 14 fixtures match. Overlay
    `test/fail` event fired. VICE flushed and left healthy at the shell.
    No version bump, no doc changes, no fix attempted -- awaiting user
    direction (open a separate bisect/fix task vs. other).
  - Remaining WP92 work still pending behind this: Increment 4 (no-locals
    byte-identity + `/L` non-regression), Increment 5 (DASH hash),
    Increments 6-10 (version bump, docs, walkthrough).
- 2026-09-01: **Task 43 fixed + user-approved + closed** (stale
  `casm_flmeta.s` cap-63 literal -> cap-32; harness-only; `flmeta` /
  `flist` / `listwrite` / `cliderive` re-verified PASS live). The
  Increment 2 sweep now stands at **31 / 31 harnesses PASS**. **WP92
  resumed at Increment 4.**
- 2026-09-01: **Increment 4 -- no-locals byte-identity gate.** Live on
  `CASM V0.5.2.1404`:
  - `casm casmchain1.s` + `comp casmchain1.prg casmchain1.ref` ->
    `FILES COMPARE OK` (chained includes, no locals -- `casm_phase12_
    test.d64`).
  - `casm casmres1.s` + `comp` -> `FILES COMPARE OK` (`.RES`, the
    Phase 13 witness -- `casm_phase13_test.d64`).
  - `casm casmassert1.s` + `comp` -> `FILES COMPARE OK` (`.ASSERT` --
    same disk).
  - `casmhello` / `casmmodes` **not run**: they live only on `test.d64`,
    whose directory is full, so `casm` cannot create their `.prg`
    (`OUTPUT WRITE FAILED` -- `project-casm-filecreateoutput-no-replace`
    / disk-full, not a Phase 14 fault). Covered indirectly: the 31/31
    harness sweep includes `test_casm_pass1` / `test_casm_expr` /
    `test_casm_directives` / `test_casm_frame` / `test_casm_opcodes`,
    which internally assemble no-locals fixtures with byte-exact
    assertions.
  - **`/L` non-regression:** `casm casmres1.s /l` re-assembly is blocked
    by the now-existing `casmres1.prg` (same no-`@0:`-replace limit).
    Covered by WP90's `casmmaploc` `/L` byte-identity proof +
    `test_casm_listing` / `test_casm_listcap` / `test_casm_listwrite`
    (all PASS in the sweep; `listwrite` re-verified under task 43).
  - Net: no-locals output is byte-identical -- Phase 14 `@local` support
    is confirmed additive.
- 2026-09-01: **Increment 5 -- DASH re-verification.** Fresh
  `cmake --build build --target dash_ref` -> `build/dash_ref.prg`
  SHA-256 `3b4d0693a6413e7e7d328f18276b6beae3d5cbecccbe7578cfe9a13504121984`,
  **exact match** to the committed `src/external/dash/dash.ref.hex`
  manifest (4579 bytes; `dfmt.s` source hash `bc8925de...` also
  unchanged). `dfmt.s` `@local` adoptions intact: `@LOOP`/`@DONE`
  (FORMATDEC16), `@DONE` (PETTOSCREEN), `@LOOP`/`@SKIP` (DIV10). No full
  hardware re-run -- WP91 did that this phase and DASH-MOD WP6 ran its
  own consolidated runtime matrix; a host-side hash match is the fresh
  cross-check the gate calls for.
- 2026-09-01: **Increments 6 + 7 -- version promotion + stability.**
  `casm.s` `VERSION_MINOR` `"5"->"6"`, `VERSION_STAGE` `"2"->"0"`
  (`0.5.2` -> **`0.6.0`**). Full `cmake --build build` clean, `BUILD_CASM`
  1404 -> 1405. Live: `casm_phase14_test.d64` rebuilt fresh, booted;
  banner reads **`CASM V0.6.0.1405`**; `casm casmloc1.s` + `comp
  casmloc1.prg casmloc1.ref` -> `FILES COMPARE OK` -- the bump is
  behaviour-neutral (same-commit precedent, WP85 `0.3.0->0.4.0` / WP75
  `0.2.8->0.3.0`). MAIN envelope: manual `ld65 -m` link identical to
  Increment 1 -- CODE+RODATA+BSS `$3800`-`$A492`, **1902 bytes headroom**
  under the `$7400` MAIN (the two-char version string is the same
  length). No-change rebuild: a second `cmake --build build` triggered
  **zero** casm compile/link work. Root `VERSION` is the OS version
  (`0.4.1`), not CASM's -- not touched (the parent plan's "`VERSION` ->
  0.6.0" Expected-Files line was a template carry-over; CASM has no
  VERSION file, only `casm.s`'s `.define`s).
- 2026-09-01: **Increment 8 -- documentation reconciliation.**
  - `docs/casm-utility.md`: new "Local Labels (`@name`)" section (syntax,
    scope rule, forward refs, shadowing, the 4-diagnostic table, `/M`
    `<owner>@<local>` rendering, and the ca65 / Turbo Macro Pro
    constant-RHS divergence stated explicitly); top "Phase 12 complete"
    banner -> "Phase 14 complete (CASM `0.6.0`)"; "Not Yet Supported"
    gains an anonymous-labels bullet.
  - `docs/casm-programmers-reference.md`: `@name` local-label bullet in
    §18 (storage layout, `CasmCurrentScope`, diag `$57-$5A`, the
    divergence) + an anonymous-labels "not yet" bullet + a §18 staleness
    note pointing to the utility manual as the authoritative language
    surface.
  - `wiki/casm-utility.md`, `wiki/casm-programmers-reference.md`:
    re-mirrored from `docs/` (were byte-identical at HEAD; `cp`).
  - `wiki/Home.md`: CASM line -> "Phase 14 complete (CASM `0.6.0`)".
  - `CHANGELOG.md`: `[Unreleased] -> Added` Phase 14 `@name` entry
    (mirrors the Phase 13 entry's shape).
  - `brain/KNOWLEDGE.md`: new "## CASM Phase 14 Complete (WP86-92 ...)"
    section (scope, deferred anonymous labels, the ca65/TMP divergence,
    the WP88/89/90 live-found defects, the WP92 flmeta regression +
    lesson).
  - `brain/task.md`: new "# CASM Phase 14 (Local Labels)" section;
    `wiki/tasks/casm.md` Current Milestone updated.
- 2026-09-01: **Increment 9 -- memory.** (deferred to after phase
  sign-off -- `project-casm-phase14-complete` written on approval.)
- 2026-09-01: **Increment 10 -- consolidated walkthrough** drafted:
  `brain/walkthroughs/2026-09-01-casm-phase14-wp92-consolidated-completion.md`.
  **Submitted for explicit user sign-off to close WP92 and the whole of
  Phase 14.**
- 2026-09-01: **WP92 and CASM Phase 14 CLOSED, user-approved.**
  Taskwarrior WP92 (`56711c7e` / task 42) and Phase 14 parent
  (`4cf10e7c`) marked done. Memory `project-casm-phase14-complete`
  written; `brain/task.md` / `wiki/tasks/casm.md` flipped to closed.
  **CASM Phase 14 (WP86-92) fully closed at `0.6.0` build `1405`.**
