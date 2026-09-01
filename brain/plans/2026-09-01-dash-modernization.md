---
feature: dash-modernization
created: 2026-09-01
status: proposed
taskwarrior: 94ec17b3-3d55-4ea6-a720-a1c51dec1e9d (parent); sub-WP UUIDs created on each sub-plan's approval
depends-on: CASM Phase 14 WP91 (DASH @local seed, done -- brain/walkthroughs/2026-09-01-casm-phase14-wp91-dash-adoption.md)
---

# Plan: DASH Modernization

## Status

**Proposed, not yet approved.** This is the PARENT plan -- it fixes the
increment's scope, sequencing, verification contract, and WP breakdown.
Per `.agents/workflows/phased-implementation-planning.md` and
`feedback-phased-plans-detail-first`, **each sub-WP below gets its own
detailed plan in `brain/plans/`, approved, before that WP is implemented.**
Approval of THIS plan authorizes only WP1's detailed sub-plan to be
drafted next.

## Scoping Decisions (user-confirmed 2026-09-01)

1. **Sequencing: now, before Phase 14 WP92.** Phase 14 pauses at WP91.
   This increment runs on the same `feature/casm-phase14` branch (it
   includes a small CASM change, WP1 below). Phase 14's WP92 consolidated
   completion gate then covers BOTH the local-labels work and the
   modernized DASH in one re-verification pass.
2. **Scope: features + design, including routine architecture.** Not just
   CASM-feature adoption -- reorganize/split routines, the key-dispatch
   and page-dispatch mechanisms, and shared helpers where it improves the
   design. Assembled output MAY change; every change is re-verified
   ca65<->CASM byte-for-byte AND against expected runtime behavior.
3. **CASM `.ASSERT` gets ca65-compatible syntax (WP1).** CASM's
   `.ASSERT expr[, "msg"]` (Phase 13 WP83) gains an optional ca65-style
   action keyword so `.ASSERT cond, error, "msg"` -- the spelling ca65
   requires -- also assembles under native CASM. DASH then uses `.ASSERT`
   for its structural invariants. This makes the increment cross-cutting
   (one CASM WP + several DASH WPs).

## Objective

Bring DASH from "works, dual-assembler-safe, but written before CASM had
cheap locals / computed constants / assertions" to a well-designed
utility that uses the shared CASM/ca65 feature set idiomatically and has
a cleaner internal structure, with **no regression** to what a user sees
on screen or to the relocation contract.

**Delivered:**
- CASM `.ASSERT` accepts the ca65 action-keyword form (WP1).
- Every routine-local helper label in DASH is a `@local` (WP2).
- Magic sizes/counts become computed constants; structural invariants are
  `.ASSERT`ed (WP3).
- The event loop, key dispatch, page-select blocks, and page-dispatch
  trampoline are refactored to remove duplication (WP4).
- The frame/screen/page-renderer helpers are refactored to remove
  duplication (`DRAWFRAME`'s 7 near-identical row loops, the `DAPPF*_*`
  flag-print repetition, etc.) (WP5).
- `AGENTS.md` rewritten to describe the new design; DASH re-baselined
  (fresh `dash.ref.hex`), version-bumped, runtime-signed-off (WP6).

**Excluded:**
- Any change to DASH's user-visible behavior, screen layout, key bindings,
  or the OS APIs it calls.
- Any change to the R6 relocatable output contract ($3400 base, `R6`
  footer, the relocation-entry rules in `AGENTS.md`'s Verification
  section).
- Anonymous labels (`:+`/`:-`) -- no CASM equivalent yet (deferred past
  Phase 14).
- The dual-assembler subset itself stays a hard constraint: nothing enters
  DASH that ca65 and native CASM don't both accept and produce identical
  bytes for.

## The verification contract (applies to every WP)

Three independent checks, all required before a WP is complete:

1. **ca65 <-> CASM byte identity.** `dash_ref` (ca65) and a native-CASM
   `DASH.PRG` (under VICE) must be byte-for-byte identical, and match the
   `dash_ref.prg` the WP produced. `build_dash_manifest.py --cross-check`
   is the mechanism.
2. **Output-delta discipline.**
   - WP2 (pure `@local` rename) must be byte-identical to the PRE-increment
     shipping manifest -- proving it changed nothing.
   - WP3-5 may change bytes; each such change is justified in that WP's
     plan (what moved and why), and the new bytes are re-baselined only at
     that WP's close, never mid-WP.
3. **Runtime.** DASH LOADed/RUN under VICE at its `$3400` base and at one
   relocated address (per `AGENTS.md`'s "runs identically at `$3800`,
   `$5000`, `$9000`"): all three pages (System / Applications / VMM Test)
   render correctly, F1/F3/F5 navigation works, `R` redraws, `T` runs the
   VMM test on the VMM page (REU present), `Q` exits to the shell. The
   final runtime pass (WP6) is a **user runtime sign-off** (the "User
   Runtime Matrix" every prior DASH WP used -- `feedback-vice-testing`:
   the agent drives and reports, the user confirms the hardware/visual
   result).

## Work Packages

Numbered DASH-MOD WP1..WP6. Each starts with its own detailed
`brain/plans/YYYY-MM-DD-dash-mod-wpN-*.md`, approved before implementation.

### WP1 -- CASM: ca65-compatible `.ASSERT`

CASM's `.ASSERT` grammar gains an optional trailing action keyword before
the optional message: `.ASSERT expr` / `.ASSERT expr, "msg"` /
`.ASSERT expr, ERROR` / `.ASSERT expr, ERROR, "msg"` (and `WARNING`, which
CASM treats identically to its current fatal behavior -- CASM has no
warning channel, and a DASH invariant that is worth stating is worth
enforcing). ca65's `ldwarning`/`lderror` (link-time) forms are parsed and
accepted as synonyms of `warning`/`error` -- CASM evaluates at pass time
regardless, which is stricter, not weaker.

- Lexer/parser: `.ASSERT`'s operand scanner accepts the keyword token.
- All existing `test_casm_*` assert fixtures unchanged and green.
- New fixtures for each new spelling (accepted) plus a bad-keyword case
  (rejected).
- No behavior change for any existing source (the keyword is purely
  additive).
- CASM version unaffected until the Phase 14 WP92 bump.

### WP2 -- DASH: full `@local` migration (output-preserving)

Every routine-local helper label -> `@local`, across `dscr.s`, `dfmt.s`
(already partly done, WP91), `dsys.s`, `dapp.s`, `dvmm.s`, and `dmain.s`'s
own internal labels. `ddata.s` is data -- its labels stay global (they are
the cross-file symbol surface).

- Per file: confirm each candidate label is referenced only within its own
  routine (`grep`), then rename, keeping `@name` unique within each CASM
  scope (the `NAME:` label to the next).
- Verify no mid-code `=` equate splits a scope differently between the two
  assemblers (DASH has none today -- WP2's plan re-confirms per file).
- **Byte-identical to the pre-increment manifest** at every step (pure
  rename). Manifest regenerated once at WP2 close (source hashes only --
  bytes unchanged).

### WP3 -- DASH: computed constants + `.ASSERT` invariants

- `PAGECOUNT = (* - PAGEROUTINETABLE) / 2` (or equivalent), used for
  `DISPATCHPAGE`'s bounds check instead of the literal `#3`.
- `.ASSERT` (WP1 syntax) for: `PAGECOUNT` == 3; the ZP equates
  (`$70`-`$8F`) are in range and the two-byte pairs do not overlap; the
  output's header/footer base and `R6` magic offset. Assertions emit no
  bytes.
- Any other magic number with a derivable source (buffer sizes already use
  `.RES`; screen-row constants; tab column math) -- adopt where it clarifies.
- Output delta: expected zero (a computed `PAGECOUNT` of 3 assembles
  identically to `#3`; asserts emit nothing). Any non-zero delta is a
  stop-and-explain.

### WP4 -- DASH: event loop / key dispatch / page dispatch refactor

- `dmain.s` key handling: replace the `CPX #$54 / BEQ ... / CPX #$74 /
  BEQ ...` shifted-variant duplication with a single normalization
  (`AND #$7F` after excluding the F-keys, or a small key->action table).
- Collapse `SELECTSYS`/`SELECTAPP`/`SELECTVMM` (three near-identical
  `LDA #n / STA CURRPAGE / LDA #1 / STA NEEDREDRAW / JMP EVENTLOOP`
  blocks) into one parametrized path.
- `DISPATCHPAGE` trampoline: keep the mechanism (it is sound and
  `AGENTS.md`-documented) but tidy with the WP3 `PAGECOUNT`.
- Output changes; each step re-verified ca65<->CASM + a runtime pass
  (navigation, redraw, exit).

### WP5 -- DASH: frame / screen / renderer helper refactor

- `DRAWFRAME`'s 7 near-identical 40-byte row-copy loops -> one `COPYROW`
  helper (source ptr in, dest row in), called 7 times.
- `dapp.s`'s `DAPPF{U,R,V,S}_{OFF,PRINT}` flag-rendering repetition ->
  one flag-cell helper.
- Survey `dsys.s`/`dvmm.s` for the same "N near-identical row renderers"
  pattern; refactor where the shared helper is a clear win and does not
  obscure the page's own layout.
- Dead code / unreachable labels removed if any surface.
- Scope may split into WP5a/WP5b if the survey finds more than one
  file's worth of clear work; the parent plan is updated if so.

### WP6 -- Consolidated gate + re-baseline

- Full ca65<->CASM byte identity on the final sources; native CASM under
  VICE; `build_dash_manifest.py` regenerates `dash.ref.hex` with the new
  shipping bytes and fresh source hashes; `--cross-check` MATCHES.
- Full **user runtime sign-off**: all three pages at `$3400` and one
  relocated address; F1/F3/F5, R, T (VMM page, REU present), Q.
- Relocation audit: reloc-entry rules in `AGENTS.md`'s Verification
  section still hold for the refactored code (`.WORD` renderer pointers,
  absolute label operands, `#>label` high bytes; no entries for fixed
  targets or `#<label`).
- `src/external/dash/AGENTS.md` rewritten: the "Local Contracts" and
  "Work Guidance" sections describe the new structure and the now-larger
  shared-feature set (`@local`, computed constants, `.ASSERT` with the
  action keyword).
- `CHANGELOG.md` entry; DASH version banner (`DASHVERSTR` in `ddata.s`)
  bumped; `wiki/tasks/*` and memory synchronized.

## Expected Files

| File | WPs | Action |
| --- | --- | --- |
| `src/external/casm/lexer.s`, `parser.s`, `emit.s` (as needed) | WP1 | Modify -- `.ASSERT` action keyword |
| `cmake/GenerateCasmTestFixtures.cmake`, `CMakeLists.txt`, `tests/fixtures/casm/` | WP1 | Modify -- new assert fixtures |
| `src/external/dash/dscr.s` `dfmt.s` `dsys.s` `dapp.s` `dvmm.s` `dmain.s` | WP2-5 | Modify |
| `src/external/dash/ddata.s` | WP3 | Modify -- computed constants / asserts only |
| `src/external/dash/dash.ref.hex` | WP2 (hashes), WP6 (bytes) | Regenerate via `build_dash_manifest.py` |
| `src/external/dash/AGENTS.md` | WP1 (assert clause), WP6 (full rewrite) | Modify |
| `brain/plans/2026-09-*-dash-mod-wp*.md` | each WP | Create |
| `brain/walkthroughs/2026-09-*-dash-mod-wp*.md` | each WP | Create |
| `CHANGELOG.md`, `wiki/tasks/*`, memory `MEMORY.md` + files | WP6 | Modify |

## Stop Conditions

- ca65 `dash_ref` and native CASM disagree by a single byte at any WP.
- WP2 produces any byte different from the pre-increment shipping manifest.
- A WP3-5 output delta the WP's plan did not predict and justify.
- A runtime pass shows any page rendering wrong, a key not working, the
  VMM test misbehaving, or a relocated-address failure.
- The relocation audit finds a new or missing reloc entry.
- A refactor would require a construct outside the dual-assembler subset.
- `build_dash_manifest.py` needs `--allow-host-bytes` (it must never).
- Any genuinely new defect outside a WP's scope -> disclose and defer.

## Documentation, Task, and Tracker Updates

- **At approval of this parent plan:** parent Taskwarrior task
  (`94ec17b3`) stays open; a `wiki/tasks/dash-modernization.md` skeleton
  is created; each sub-WP gets its Taskwarrior task at its own sub-plan's
  approval.
- **Per WP:** its own walkthrough; this parent plan's Progress log
  appended; `wiki/tasks/dash-modernization.md` ticked.
- **At WP6:** `AGENTS.md` full rewrite, `CHANGELOG.md`, DASH version,
  `brain/KNOWLEDGE.md` closing note, memory (`project-dash-modernization`
  record; update `reference-dash-no-character-literals` /
  `project-casm-future-feature-backlog` cross-links).

## Completion Gate (whole increment)

- WP1-6 each individually complete and user-approved.
- Final DASH: ca65 == native CASM, byte-for-byte, and `dash.ref.hex`
  regenerated from reviewed native bytes with `--cross-check` MATCHES.
- User runtime sign-off recorded in a `brain/walkthroughs/` doc.
- Relocation contract re-audited and unchanged.
- `AGENTS.md` describes the delivered design.
- All trackers synchronized; DASH version bumped; explicit user approval
  to close the increment.
- Phase 14 WP92 then resumes and its consolidated gate re-verifies the
  full tree (CASM local labels + `.ASSERT` keyword + modernized DASH).

## Progress

- 2026-09-01: Parent plan drafted for review. Scoping decisions 1-3
  captured from the user (run now before WP92; architecture in scope;
  CASM `.ASSERT` ca65-compat in scope). Awaiting approval before drafting
  WP1's detailed sub-plan.
- 2026-09-01: **Parent plan approved.** WP1 detailed sub-plan drafted
  (`brain/plans/2026-09-01-dash-mod-wp1-casm-assert-ca65-keyword.md`) and
  **approved**. Taskwarrior WP1 `4e682aa2-3930-47f3-9b5b-8999fadf2104`
  (child of parent).
- 2026-09-01: WP1 source-complete. `.export compareTokenText` (lexer.s);
  `ppsAssert` `@haveComma` reworked to accept `expr, ACTION[, "msg"]`
  alongside the legacy forms; 4 keyword strings in a new parser.s RODATA
  block; `ppsAssertMatchAction` (4 unrolled compareTokenText calls).
  `casm.prg` +110 code bytes (24502), MAIN headroom ~1945. AGENTS.md
  `.ASSERT` dual-assembler bullet added. 7 `casmakw*` fixtures on
  `casm_phase13_test_d64` + 2 legacy regression, all live-verified on
  `CASM V0.5.2.1404` (accepted -> INPUT VALIDATED; rejected -> SYNTAX
  ERROR at the right token; WARNING fatal same as ERROR; message threads
  with an action present). ca65 cross-checked (accepts computed
  `PAGECOUNT` under plain `error`, no message -- de-risks WP3). Full
  `cmake --build build` green. Walkthrough:
  `brain/walkthroughs/2026-09-01-dash-mod-wp1-casm-assert-ca65-keyword.md`.
  Awaiting user sign-off before WP2.
- 2026-09-01: WP2 detailed sub-plan
  (`brain/plans/2026-09-01-dash-mod-wp2-full-local-migration.md`)
  **approved**; Taskwarrior WP2 task 51 (child of parent).
- 2026-09-01: WP2 source-complete. 84 routine-local helper labels demoted
  to `@local` across `dscr.s` (13), `dsys.s` (14), `dapp.s` (10),
  `dvmm.s` (44), `dmain.s` (3 -- `DISPATCHPAGE` only). Five atomic
  increments, each ca65 byte-identity-checked. DASH.PRG byte-identical to
  the pre-increment shipping manifest (sha256 `3238b786`, 4766 bytes)
  three ways: ca65 `dash_ref`; native `CASM V0.5.2.1404` under VICE
  (`P1/P2 01621`, `04766 BYTES`, `INPUT VALIDATED`, `COMP` -> `FILES
  COMPARE OK`); host `cmp` of the extracted native `dash.prg`.
  `dash.ref.hex` regenerated -- same bytes/sha256, `--cross-check`
  MATCHES, fresh source hashes for the 5 changed files, no
  `--allow-host-bytes`. `DRAWFRAME` / `DAPPPRINTFLAGS` / dmain event-loop
  label sets explicitly deferred to WP4/WP5. Full `cmake --build build` +
  `image_d64` green. Walkthrough:
  `brain/walkthroughs/2026-09-01-dash-mod-wp2-full-local-migration.md`.
- 2026-09-01: **WP2 closed — user-approved.** Taskwarrior task 51 done.
  WP3 (computed constants + `.ASSERT` invariants) needs its own detailed
  sub-plan before implementation.
- 2026-09-01: WP3 detailed sub-plan
  (`brain/plans/2026-09-01-dash-mod-wp3-computed-constants-assert-invariants.md`)
  drafted, revised, **approved**; Taskwarrior task 52. Scoping: broad
  constant adoption, all in `dmain.s` prologue, R6 assert dropped.
  Blocking finding mid-plan — CASM has no comparison operator, so the
  `.assert` invariants moved to `dash_wrapper.s` (ca65-only); CASM side
  covered by the byte cross-check.
- 2026-09-01: **WP3 source-complete.** ~110 named constants across all 7
  DASH sources + 16 ca65-only structural `.assert`s in `dash_wrapper.s`.
  8 atomic increments, ca65 byte-identity per step. DASH.PRG
  byte-identical to the pre-WP3 shipping manifest (`3238b786`, 4766
  bytes) three ways: ca65 `dash_ref`; native `CASM V0.5.2.1404`
  (`P1/P2 01728`, `INPUT VALIDATED`, `COMP` -> `FILES COMPARE OK`); host
  `cmp` of the extracted native prg. `dash.ref.hex` regenerated —
  payload untouched, hashes only, `--cross-check MATCHES`. Two
  dual-assembler findings recorded in AGENTS.md (no comparison operator;
  constant-def RHS must be a bare literal). Full `cmake --build build` +
  `image_d64` green. Walkthrough:
  `brain/walkthroughs/2026-09-01-dash-mod-wp3-computed-constants-assert-invariants.md`.
  Awaiting user sign-off before WP4.
- 2026-09-01: **WP3 closed — user-approved.** Taskwarrior task 52 done.
  WP4 (event loop / key dispatch / page dispatch refactor) needs its own
  detailed sub-plan before implementation; it is the first WP that
  changes shipped bytes, so runtime re-verification resumes there.
