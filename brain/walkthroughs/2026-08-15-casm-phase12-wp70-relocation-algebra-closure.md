# Walkthrough: CASM Phase 12 WP70 — Relocation Algebra Closure

Plan: `brain/plans/2026-08-15-casm-phase12-wp70-relocation-algebra-closure.md`
(approved 2026-08-15). Prerequisite: WP65-69, all complete and
user-approved. Branch: `feature/casm-phase12-wp65` (WP70 implemented on
the same branch as WP65-69; not yet merged to `casm-phase12`/`main`).

## What Shipped

No new production behavior — this WP's own research found no defect.
Two new production fixtures and a coverage audit closing the gap between
"algebraically proven" and "directly, live proven" for WP64's relocation
representability contract:

- `casmrelacc.seq`: a relocatable label combined with a static addend via
  `+`, reached through WP67's recursive parenthesized/precedence-climbing
  architecture for the first time under full R6 relocation-table
  verification — no fixture anywhere in or before Phase 12 had ever done
  both at once.
- `casmarelocb.seq`: a second, distinct WP68 static-only operator (`&`)
  applied to a real relocatable label, live-confirming the shared
  `checkStaticReloc` rejection mechanism a second time.
- A coverage-audit table (recorded in `brain/KNOWLEDGE.md`) enumerating
  exactly which representability-contract combination is proven where.

## Real Findings, Not Assumed Correct

1. **The genuine gap this WP was scoped to close was found by reading,
   not by running anything** (drafting the plan, before any fixture was
   written): every pre-Phase-12 fixture that fully verifies an R6
   relocation table (`casmrelop1`/`2`, `casmreloc1`) uses the old flat
   grammar with a bare identifier — none combine a relocatable label with
   an addend. Every Phase 12 fixture that reaches a real relocatable
   label (`casmparen2`, `casmareloc1`/`2`) is itself a rejection case —
   none assemble successfully and check the resulting table. The
   combination "relocatable label + addend, R6-verified" had simply never
   been tested, in any WP, ever.
2. **A real hand-derivation mistake, caught by the fixture's own COMP
   check, not silently trusted** (Atomic Step 4). The first
   `casmrelacc.ref.hex` draft predicted a single R6 entry (the `LDA`
   line's own relocatable reference) and 17 total bytes. Live COMP
   against the real assembled output reported two byte mismatches and a
   file-size difference (17 vs 19 bytes): `JMP MID` is *also* a
   relocatable reference in the same assembly (`MID` is a label too, and
   every label in non-`.ORG` mode is relocatable) — a mistake in framing
   ("TARGET is the test subject") that overlooked a second, unrelated
   relocatable reference in the same fixture. Corrected by re-deriving
   from the specification and `casmrelop1.ref.hex`'s own established
   "absolute JMP, high-byte relocatable" pattern, not by copying CASM's
   own output — the live mismatch located the error, it did not supply
   the fix, preserving this project's non-circularity rule for trusted
   references.
3. **A `hex_manifest_to_bin.py` formatting gotcha, caught by the build,
   not live** (Atomic Step 2): a hand-written comment line
   (`#   START: JMP MID`) matched the manifest parser's "looks like an
   unrecognized directive" guard (`^#\s*\w+\s*:`) and failed the build
   with `unknown directive`. Fixed by following `casmrelop1.ref.hex`'s
   own established convention (`#   - START: JMP MID`, a leading `-`
   after the `#` avoids the pattern) — twice, since a second comment line
   later in the same file (`# TARGET: NOP ...`) hit the identical guard
   and needed the same rewording.
4. **A stale disk image from the live VICE session, caught before
   re-verifying, not silently reused**: after fixing the reference and
   rebuilding, `casm_phase12_test_d64`'s `POST_BUILD` step ran against
   the *same host file* the running VICE instance had just written
   `crelacc.prg` onto directly (both point at `build/casm_phase12_test.d64`),
   leaving a stray extra file on the packaged disk. Not a defect — the
   packaging step correctly overwrote every fixture/reference it owns —
   but re-verification used a freshly deleted-and-rebuilt disk image to
   avoid re-attaching a VICE-contaminated file.

## Live Evidence (VICE 3.10)

- **`casmrelacc.s`** (`JMP MID` / `LDA TARGET+(1+0)` / `NOP`, no `.ORG`)
  → `CASM: INPUT VALIDATED`; `comp crelacc.prg casmrelacc.ref` → `FILES
  COMPARE OK` — the corrected two-entry R6 table (offsets 2 and 5) and
  footer (count 2) verified byte-exact, after the mismatch-and-correction
  above.
- **`casmarelocb.s`** (`LOOP: NOP` / `LDA #LOOP&$FF`) → `CASM: EXPRESSION
  RELOCATION UNSUPPORTED AT LINE 3, COL 14 (OFFSET 13)`, echoed
  `lda #loop&$ff` with caret — `&` (distinct from Increment 7's `*`)
  correctly rejects a real relocatable label through the real pipeline.
- **`test_casm_expr`** re-run (unaffected — no production source
  changed) → `CASM EXPR: PASS`.
- **`test_casm_lexer`** re-run (unaffected) → `CASM LEXER: PASS`.
- **Version bump verification**: after promoting CASM to `0.2.5`, a
  fresh boot of the rebuilt `casm_phase12_test.d64` showed `CASM
  V0.2.5.1312` on the real banner, with `casm.prg` unchanged in size
  (21,776 bytes) and every other artifact byte-identical to the pre-bump
  build in a no-change rebuild.

## Coverage Audit

Recorded in full in `brain/KNOWLEDGE.md`'s WP70 as-built section. Summary:
every accepted combination (`+`/`-` with one relocatable component,
including now through the new recursive architecture) and every rejected
combination this plan scoped (two relocatable components via `+`/`-`;
`*` and `&` — two distinct operator families — applied to a real
relocatable label or label-derived constant) is proven with live
production evidence. The remaining WP68 static-only operators (`/`, `^`,
`|`, `<<`, `>>`, unary `-`/`~`) applied to a relocatable operand rest on
the synthetic harness's own algebraic proof plus the shared-mechanism
argument (one routine, no per-operator branching, confirmed by reading)
rather than a separate live fixture per operator — a deliberate scope
decision (this plan's own Excluded section), not an oversight.

## Envelope

No production source changed; no cap change needed. `casm_phase12_test_d64`
ended WP70 at 438 free blocks (comfortably above its `>=40` gate, down 3
from WP69's 441 for the two new fixtures). `image_d64`/`test_image_d64`/
`casm_listing_test_d64` all unaffected (no shared-module growth this WP).

## Stop Conditions Checked

- Atomic Step 1's audit confirmed every Research Finding in the plan
  before any fixture was written; no correction needed to the two-rule
  model or the shared-mechanism claim.
- `casmarelocb.seq` raised the correct diagnostic at the correct
  location.
- `casmrelacc.seq`'s real assembled output byte-exact-matched its
  hand-derived reference — after one real correction, found by the
  fixture's own COMP check and re-derived from spec, not from CASM's own
  bytes.
- `casm_phase12_test_d64`'s free-block gate was not threatened.
- No no-change rebuild changed any artifact or build counter, including
  after the final version bump.
- No genuinely new defect was found — the shared relocation-check
  mechanism is exactly as uniform as Research Finding 1 claimed.

## Documentation and Tracker Sync

- `brain/KNOWLEDGE.md`: new WP70 as-built section (including the
  coverage-audit table), recorded immediately after WP69's own section.
- `brain/task.md`, `wiki/tasks/casm.md`: completion entries recorded
  alongside this walkthrough.
- No `docs`/`wiki` `casm-utility.md` change (no new user-facing syntax or
  semantics — this WP proves existing documented behavior).
- `CHANGELOG.md`: entry added under `[Unreleased]` → `Added`.
- CASM version promoted `0.2.4` → `0.2.5`, live-verified on the real
  banner (`CASM V0.2.5.1312`).
- Taskwarrior task 45 to be marked done alongside this walkthrough's
  approval.

## Outcome

**WP70 complete, user-approved 2026-08-15.** Both new fixtures behave
exactly as designed after one genuine hand-derivation mistake was found
and corrected via the fixture's own COMP check (not silently trusted).
No production source change was needed. The relocation-representability
contract WP64 froze is now directly proven, not merely assumed from
design: the "accepted" side through the new recursive architecture for
the first time, and the "rejected" side confirmed live for a second
distinct operator family. This is the last dependency-spine WP before
WP71 (DASH adoption of Phase 12 syntax) and WP72 (Phase 12 completion
gate), both of which require their own detailed plans and separate
approval before any implementation.
