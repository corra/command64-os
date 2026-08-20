---
feature: casm-phase12-wp73-branch-range-false-positive
created: 2026-08-17
status: completed
taskwarrior: 34c11d87-811e-4aa2-b705-1cd59e91a23a
depends-on: WP72 (its fix is what exposed this defect)
---

# Plan: CASM Phase 12 WP73 — Branch-Range False Positive After WP72

## Status

**Approved 2026-08-17.** Implementation of the Atomic Increments below is
authorized. Taskwarrior task 44 (`34c11d87-811e-4aa2-b705-1cd59e91a23a`)
created and started; task 43 (WP71) now depends on both WP72 (satisfied)
and this WP.

Not a sub-WP of a parent plan — a standalone point-fix WP, same shape as
WP72, inserted into Phase 12's numbering because it was discovered
immediately after WP72 landed, while resuming WP71's own blocked Atomic
Step 5. See `brain/plans/2026-08-15-casm-phase12-wp71-dash-adoption.md`,
Progress section, 2026-08-17 entry ("Atomic Step 5 re-attempted after
WP72's fix landed"), for the original discovery and reproduction this
plan is built on.

## Objective

Fix a second, distinct CASM defect: native CASM now refuses to assemble
DASH's real source at all — `CASM: BRANCH OUT OF RANGE` at `dvmm.s`'s
`BCC DVMMRT_PATTERNLOOP` — for a branch **confirmed genuinely in valid
6502 relative-branch range** (proven live against an independent ca65
assembly of the identical source, not assumed). This is a false positive
in CASM's own range check or in whatever address it's checking against,
not a real hardware limit and not a defect in DASH's source.

**Delivers:** a fix (location not yet confirmed — this plan's own
Atomic Increment 1 establishes it) that makes CASM's relative-branch
range check agree with reality for this case, without breaking the
genuine 8-bit-range enforcement CASM correctly performs elsewhere
(`test_casm_opcodes`'s own dedicated branch-range coverage must stay
green). Plus regression coverage proving it. Plus re-verification of
WP71's still-blocked native-provenance regen once this lands.

**Does not deliver:** any change to DASH's source (ca65 already proves
it assembles correctly and is not the problem). Does not deliver WP71's
own remaining work — this plan only unblocks it a second time.

## Confirmed Facts (established before drafting this plan, by reading and
by one independent live ca65 assembly — not assumed)

1. **The branch is genuinely in range.** Assembled `dash_wrapper.s`
   directly with `ca65 ... -l` and read the resulting listing (not
   CASM's own output, preserving this project's non-circularity rule for
   ground truth): `DVMMRT_PATTERNLOOP` resolves to `$0962`; the `BCC`
   instruction is at `$09D9` with operand byte `$87` (`-121` signed);
   `nextPc ($09DB) + (-121) = $0962` exactly, matching the label, 7 bytes
   inside the valid `-128..+127` window. ca65 assembled the identical
   source with zero complaint.
2. **`emit.s`'s range-check formula is correct in isolation.**
   `eiRelative`'s `disp = target − nextPc` (`CasmParserStmt.Val` minus
   `CasmPc+1`) and its subsequent `$00`/`low<$80` vs. `$FF`/`low>=$80`
   range test are textbook-correct 6502 relative-addressing arithmetic,
   confirmed by reading, not just by the formula "looking standard."
3. **`dvmm.s` itself references none of WP71/WP72's zero-page equate
   names** (`DISPATCHVECTOR`, `CURRENTROW`, etc.) — confirmed by
   `grep`. Whatever is shifting byte counts into false-positive
   territory must originate in code assembled before `dvmm.s` in
   `dmain.s`'s `.INCLUDE` chain (`dscr.s`, `dfmt.s`, `dsys.s`, `dapp.s`,
   in that order) — the files that *do* use the new named constants.
4. **A pure, uniform address shift upstream cannot by itself explain
   this**, algebraically: if code before `dvmm.s` shrinks by some
   constant amount, *both* `DVMMRT_PATTERNLOOP`'s address and the `BCC`
   instruction's own address shift down by the identical amount, leaving
   their mutual relative displacement — the only thing the range check
   cares about — unchanged. A real explanation requires either (a) an
   asymmetric effect (something changes size specifically *between* the
   label and the branch, inside `dvmm.s`'s own loop body — ruled out by
   fact 3 unless an indirect/second-order effect exists), or (b) the two
   passes disagreeing on an address that Pass 2 then uses without
   re-deriving it from its own real-time traversal (a genuine cross-pass
   staleness bug), or (c) a mechanism not yet identified.
5. **A specific, on-point warning already exists in CASM's own source,
   written before this defect was ever hit**: `emit.s`'s
   `emitCheckPassAgreement` doc comment states the invariant the whole
   force-absolute design relied on — *"`CASM_PARSER_STMT_FORCE_ABS` is
   derived from `CASM_EXPR_FLAG_SYMBOL_DERIVED`, which is set
   **identically in both passes regardless of resolution state**"*.
   WP72's fix is exactly the change that makes `SYMBOL_DERIVED`
   *depend* on resolution state (gated on `CASM_SYMBOL_FLAG_RESOLVED`
   for the constant classification) — this is the most direct textual
   evidence connecting WP72 to this new failure mode, though the
   specific symbol/instruction where resolution state actually differs
   between passes for DASH's own source has **not yet been found live**.
6. **Ruled out**: DASH's own equates (`DISPATCHVECTOR = $70`, etc.) are
   plain numeric-literal right-hand sides, declared at the top of
   `dmain.s` before any use. `casm.s`'s `casmResolveConstants` sweep
   explicitly skips any constant already `CASM_SYMBOL_FLAG_RESOLVED`
   (`crcSweepReadOk`'s own comment: *"already resolved (a numeric
   RHS)"*) — confirming these specific equates resolve **inline**, the
   moment their own `=` statement is processed, in Pass 1 itself, before
   any later instruction in either pass could reference them
   unresolved. This rules out the simplest version of Finding 5's
   concern (a forward-referencing constant unresolved-in-Pass-1) for
   DASH's actual equates specifically — the true mechanism is still
   unconfirmed and needs Atomic Increment 1's live investigation, not
   assumed from this alone.
7. **`emitCheckPassAgreement` itself never fires for this failure** —
   it's a Pass-2-end/EOF check, and `casm.s`'s error handling
   (`bcs startFatalNear`) aborts on the *first* hard diagnostic, so a
   mid-assembly `BRANCH OUT OF RANGE` in Pass 2 is reported before
   Pass 2 ever reaches the point where a final-PC disagreement would be
   checked. A genuine cross-pass disagreement localized before `dvmm.s`
   could exist and never surface as `CASM_DIAG_PASS_MISMATCH` for this
   exact reason.

## Scope

**Included:**
- Atomic Increment 1's live investigation to pin down the actual
  mechanism (not just the leading hypothesis) — likely via CASM's own
  `/M` symbol-map feature (WP52) to directly compare CASM's own resolved
  address for `DVMMRT_PATTERNLOOP` (and other `dvmm.s` labels) against
  ca65's `$0962`, isolating whether the corruption is in the symbol
  table itself or in the branch instruction's own real-time PC at
  emission.
- The fix, once the mechanism is confirmed — narrowly scoped to
  whatever the investigation finds, not a preemptive rewrite of the
  pass-agreement design.
- Regression coverage: at minimum, an end-to-end fixture reproducing
  this exact shape (a resolved zero-page-eligible constant reference,
  followed by a backward branch spanning close to the 128-byte boundary)
  so this class of defect has a permanent regression test, plus
  confirmation that `test_casm_opcodes`'s existing branch-range coverage
  (accept/reject at the true boundary) still passes unchanged.
- Re-running WP71's own Atomic Step 5 (native DASH regen) once this
  fix lands, to confirm the underlying blocker is actually cleared —
  tracked and reported under WP71's own plan, not this one.

**Excluded:**
- Any change to DASH's source — ca65 already proves it's correct.
- Any change to WP72's own fix's scope (the constant-vs-label
  distinction itself) unless Atomic Increment 1's investigation finds
  that distinction is itself wrong, not just under-guarded — expected to
  remain correct; this WP is about restoring a broken invariant
  elsewhere, not reverting WP72.
- A general audit of every other place `SYMBOL_DERIVED`/`FORCE_ABS`
  parity might matter, beyond what's needed to fix this specific
  reproducible failure and prevent its exact class — a broader audit is
  a separate, explicitly-scoped follow-up if this investigation surfaces
  reason to believe one is needed.

## Atomic Increments

1. **Confirm the mechanism live**, not by further static reasoning.
   Build a small, targeted reproduction if possible (a short fixture
   with a resolved zero-page constant reference followed by a
   near-boundary backward branch, small enough to assemble in seconds
   under VICE) — this is both the fastest way to iterate and, if it
   reproduces the bug, becomes the permanent regression fixture from
   Scope. If it does not reproduce with a minimal case, fall back to
   instrumenting/inspecting the real `dvmm.s` failure directly: use
   CASM's `/M` symbol-map output on the real DASH assembly (it already
   fails before completing — check whether `/M` output is available for
   a failed assembly, or whether a temporarily-relaxed/diagnostic build
   is needed) to compare CASM's own resolved address for
   `DVMMRT_PATTERNLOOP` against ca65's `$0962`, and/or compare Pass 1's
   measured size for the code between `dscr.s`'s start and `dvmm.s`'s
   `DVMMRT_PATTERNLOOP` label against Pass 2's real size for the same
   span. Stop and report if the mechanism found contradicts this plan's
   own Confirmed Facts above.
2. **Implement the fix** at whatever site Increment 1 identifies.
   Minimal, targeted change — restore correct Pass 1/Pass 2 agreement
   (or correct symbol-table freshness, or whatever the actual defect
   turns out to be) without reintroducing WP72's own bug.
3. **Regression coverage**: the minimal reproduction fixture from
   Increment 1 (if one was built) becomes a permanent end-to-end test,
   COMP-verified against a hand-derived reference, following WP70/72's
   own established pattern. If no standalone minimal reproduction proved
   possible, the real DASH source itself (already exercised by WP71's
   own Atomic Step 5) is the regression proof instead — record which,
   and why, in this plan's Progress log.
4. **Full regression**: the complete existing CASM test suite
   (`casm_expr`, `casm_opcodes` — especially its branch-range-boundary
   cases — `casm_pass1`, `casm_reloc`, `casm_symbols`, and any other
   relevant harness) must pass unchanged.
5. **ca65 cross-check re-verification**: confirm `dash_ref` remains
   byte-identical (this class of fix should be native-CASM-only, same
   as WP72).
6. **Report back to close this plan**, then hand off to WP71's own plan
   to re-attempt its Atomic Step 5 a second time.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/*.s` (exact file TBD by Increment 1 — likely `casm.s`, `emit.s`, `parser.s`, or `symbols.s`) | Fix |
| `tests/fixtures/casm/*.ref.hex` (new, name TBD) | New trusted reference, if a minimal fixture is built |
| `cmake/GenerateCasmTestFixtures.cmake`, `CMakeLists.txt` | New fixture registration, if built (same pattern as WP72's `casmzpconst1`) |
| `brain/plans/2026-08-15-casm-phase12-wp71-dash-adoption.md` | Progress note once this fix lands and WP71's Step 5 is re-attempted |

## Stop Conditions

- Atomic Increment 1's live investigation contradicts any of this plan's
  Confirmed Facts (1-7 above) — stop and report before implementing
  against a false premise, exactly as WP72's own Increment 1 did.
- The mechanism found implicates WP72's own constant-vs-label
  distinction as *itself* wrong (not just under-guarded elsewhere) —
  stop and report; this would mean reopening WP72, not just adding a
  narrow fix here.
- Any existing CASM test changes behavior after the fix — a real
  regression.
- `test_casm_opcodes`'s own branch-range boundary coverage
  (accept/reject at the true 8-bit edge) changes result — the fix must
  not weaken genuine range enforcement while removing the false
  positive.
- The ca65 cross-check changes byte output — should be entirely
  unaffected by a native-CASM-only fix.
- WP71's own re-attempted Atomic Step 5 still fails after this fix
  lands — a third distinct defect, or an incomplete fix; report rather
  than layering another patch.

## Documentation, Task, and DOX Updates

- Create/activate a Taskwarrior task for this WP under Phase 12, blocking
  WP71's own task, once this plan is approved.
- At completion: `brain/KNOWLEDGE.md` Phase 12 section (as-built note),
  `CHANGELOG.md` entry, `brain/walkthroughs/` completion-gate doc,
  `brain/task.md`/`wiki/tasks/casm.md` sync.

## Completion Gate

This WP completes only when: the actual mechanism is confirmed live
(not just the leading hypothesis); the fix is implemented and narrowly
scoped to it; regression coverage exists and demonstrably fails without
the fix; the full existing CASM test suite passes unchanged, including
`test_casm_opcodes`'s own branch-range boundary cases; the ca65
cross-check remains byte-identical; a `brain/walkthroughs/` doc records
live evidence; and the user explicitly approves closing this WP. WP71's
own re-attempted Atomic Step 5 is tracked and reported under WP71's own
plan, but is the practical proof this fix actually solved the
originating problem a second time.

## Progress

- 2026-08-18: **User approved the completion gate. WP73 complete.** CASM
  promoted `0.2.5` -> `0.2.6`; Taskwarrior task 44 and repository task
  records closed. WP71 may resume its blocked native DASH regeneration.
- 2026-08-18: **Atomic Increments 1-5 implemented and verified; completion
  gate awaiting user sign-off.** Source reading confirmed the exact mechanism:
  `symbolsLookup` leaves `CASM_RESOLVE_SYM_FLAGS` unspecified on a miss, while
  WP72's `expr.s::identifier` path read it before checking RESOLVED. The
  reproduction's preceding `STA CHARSTASH` lookup left resolved-constant flags
  in the reusable view; unresolved `FWDLABEL` inherited them, cleared
  `SYMBOL_DERIVED`, and selected zero-page only in Pass 1. Added the narrow
  resolved-state guard, expression case 100, and `casmfwdstale1` fixture.
  Native CASM + COMP reports `FILES COMPARE OK`; `CASM EXPR: PASS`; relevant
  host targets and `dash_ref` build clean. The first hand reference used `$E4`
  (CPX zp) for `CPY MAXLEN`; COMP caught it at offset `$0024`, and the oracle
  was corrected from the instruction set to `$C4`. See the walkthrough for
  complete evidence. No version/task completion state changes until approval.
- 2026-08-17: **Atomic Increment 1 in progress — root cause bisected down
  to a tight, reproducible minimal case via 12 rounds of live VICE
  testing**, not yet down to the exact mechanism. Full detail:

  Confirmed directly that `emitCheckPassAgreement`'s `PASS 1/2 MISMATCH`
  diagnostic fires on the real DASH source once its own failing branch is
  neutralized (a scratch copy with `dvmm.s`'s `BCC` replaced by `JMP` so
  Pass 2 can reach EOF) — proving a genuine Pass 1/Pass 2 disagreement
  exists, exactly the invariant `emitCheckPassAgreement`'s own doc
  comment named as being at risk from WP72's change.

  Bisected via progressively smaller standalone `dmain.s` fragments
  (each packaged fresh onto a scratch utility disk and run under native
  CASM with `/M`), narrowing from all seven DASH source files down to a
  single routine:
  - `DSCR.S`+`DFMT.S`+`DDATA.S` (dropping `DSYS.S`/`DAPP.S`/`DVMM.S`,
    stubbed): still mismatches.
  - `DSCR.S` alone: still mismatches.
  - `COMPUTEROWADDR` alone (the routine with `ROL SCREENDESTPTR+1`,
    twice — the most-suspected candidate going in): **clean**. Ruled out.
  - The rest of `DSCR.S` with `COMPUTEROWADDR`'s own body stubbed:
    **still mismatches** — confirming `COMPUTEROWADDR`'s real body is
    not required at all.
  - `SCREENPUTSTRING` alone (loop + `STRINGSRCPTR`/`STRINGSRCPTR+1` +
    indirect-Y): clean.
  - `SCREENPUTCHAR` alone (first case reading FROM an `equate+1`
    expression — `LDA SCREENDESTPTR+1` — not just writing to one):
    clean.
  - `DRAWFRAME` (all row-copy loops + `DRAWMIDROWS`) alone: clean.
  - `DRAWFRAME` + `HIGHLIGHTTABS` together: **mismatches**.
  - `HIGHLIGHTTABS` alone: **mismatches** — the minimal routine.
  - Within `HIGHLIGHTTABS`: replacing `CPX CURRPAGE` (a forward
    reference to a DDATA.S label) with `CPX #0` — mismatch persists,
    ruling that reference out.
  - Replacing *both* `CPX CURRPAGE` and `LDA TABCOLSTART, X` /
    `LDA TABCOLLEN, X` (both label-indexed reads) with immediates:
    **clean**.
  - Restoring only `LDA TABCOLSTART, X` (keeping `CPX #0` and
    `LDA #5` in place of `TABCOLLEN, X`): **mismatches again** — this is
    the confirmed minimal trigger.

  **Minimal reproduction found**: `LDA TABCOLSTART, X` (an
  absolute-indexed read of a label defined later in the source, in
  `DDATA.S`, i.e. a genuine forward reference) immediately followed by
  `CLC` / `ADC #$50` / `STA COLORPTR` (a zero-page-equate store) —
  within a routine that also references `CHARSTASH`/`COLORPTR+1`/
  `MAXLEN` and has two small `JMP`-based loops. `TABCOLLEN, X` and
  `CPX CURRPAGE` are both confirmed *not* required.

  This is a forward-referenced **label** (not a constant) immediately
  adjacent to zero-page-equate code — labels are supposed to be
  completely unaffected by WP72's fix (which only touches the
  resolved-non-label-derived-constant classification branch). The
  working hypothesis is now a **shared-state/timing interaction**
  between resolving a forward-referenced label and an immediately
  following equate reference (e.g. stale resolver/mode-selection scratch
  carried from one `identifier`/`opcodesFindOpcode` call into the next),
  not a simple "equate resolves differently between passes" story as
  originally hypothesized — that simpler story is still ruled out for
  DASH's actual equates (Confirmed Fact 6).

  **Bisection 13** (2026-08-18): replaced `LDA TABCOLSTART, X` with plain
  `LDA TABCOLSTART` (no indexing) in the bisection-12 fragment — still
  `PASS 1/2 MISMATCH`. Rules out `,X` indexed addressing as a factor;
  the trigger is the forward-referenced label read itself (in any
  absolute-eligible addressing form), not anything specific to indexed
  modes. Narrows the working hypothesis to: any not-yet-defined
  (forward) label reference, positioned near equate-derived zero-page
  code, is sufficient — next test is whether *forward* reference is
  actually the operative condition (vs. just "any label reference at
  all") by substituting an already-defined (backward) label at the same
  position.

  **Bisection 14** (2026-08-18): substituted a *backward*-referenced
  label (`BACKREFLABEL`, defined immediately before `HIGHLIGHTTABS` in
  the same file) for `TABCOLSTART` at the identical code position —
  **clean**. Confirms forward-reference-ness (unresolved during Pass 1's
  own traversal, resolved by the time Pass 2 reaches the same point) is
  the operative condition, not "any label reference." This matches a
  genuine Pass 1/Pass 2 asymmetry: Pass 1 measures the forward reference
  as unresolved (placeholder), Pass 2 measures it as resolved.

  **Bisections 15-18** (2026-08-18): shrank toward a standalone minimal
  case, testing each added ingredient in isolation:
  - Bisection 15 (absolute minimal: `LDA FWDLABEL` / `STA ZPCONST`,
    nothing else): **clean**.
  - Bisection 16 (adds `CLC`/`ADC #$50` between the load and store,
    matching `HIGHLIGHTTABS`'s own arithmetic): **clean**.
  - Bisection 17 (adds the second equate write `COLORPTR+1`, `MAXLEN`,
    and a small `CPY`/`BCS`/`STA (COLORPTR),Y`/`INY`/`JMP` inner loop —
    but the fill value is a bare literal, `CHARSTASH` declared but
    unused): **clean**.
  - Bisection 18 (adds the outer `CPX #3`/`BEQ`/color-select
    `BNE`/`INX`/`JMP` loop *and* has the fill loop actually read back
    `CHARSTASH` — which is now written *before* the `FWDLABEL` reference
    and read *after* it, matching `HIGHLIGHTTABS` exactly except
    `TABCOLSTART,X` is simplified to a bare forward label):
    **mismatches**. This is now a solid, ~30-line, standalone minimal
    reproduction structurally equivalent to the real routine.

  Bisection 17→18's only two simultaneous changes were the outer loop
  control flow *and* making `CHARSTASH` a genuine write-then-read (not
  just a declared-but-unused equate) — which one (or both together) is
  strictly necessary is not yet isolated further; diminishing returns on
  continued live bisection at this point. This is a good stopping point
  for live-VICE bisection — bisection 18's source is small enough to
  hand-trace or adapt directly into a permanent regression fixture once
  the fix lands, and the next step is source-level reading of `expr.s`/
  `opcodes.s`/`parser.s` with this concrete minimal case in hand, not
  further bisection rounds.

  Full bisection artifacts (18 scratch `dmain.s`/fragment variants) are
  in the session's scratchpad, not committed — reproducible from this
  log if needed. Next step (continuing Atomic Increment 1): read
  `expr.s`'s `identifier` and `opcodes.s`'s mode-resolution code for any
  state that could leak from a label-operand instruction into the
  following equate-operand instruction's own width decision (e.g.
  `ofMaskLo`/`ofMaskHi`/`ofResolvedMode`'s aliasing onto
  `CasmExprScratch0`-family cells, or `CasmExprResolverOutput` reuse) —
  this is now a source-reading task, not further live bisection.
- 2026-08-17: Drafted this plan immediately after discovering the defect
  while resuming WP71's Atomic Step 5. Independently re-verified the
  branch-range ground truth via a fresh, separate ca65 assembly (not
  reusing the earlier session's numbers uncritically) and re-read
  `emit.s`'s `eiRelative`/`emitCheckPassAgreement` directly before
  drafting — confirmed the on-point warning already written into
  `emitCheckPassAgreement`'s own doc comment, and confirmed (not
  assumed) that DASH's actual equates resolve inline in Pass 1, which
  rules out the simplest version of the leading hypothesis and means
  Atomic Increment 1 must find the real mechanism live rather than
  assume it. Awaiting user approval before implementation begins.
