---
feature: casm-progclear-early-fatal-fix
created: 2026-08-31
status: approved
taskwarrior: 43 (5dad4e4f-8392-468f-8807-0ff37a98c33c)
depends-on: none (branches off main after the memory-optimization merge)
branch: feature/casm-progclear-early-fatal-fix
---

# Plan: CASM diagPrintFatal reads uninitialized CasmProgFlags on an early fatal

## Status

**Approved 2026-08-31.** Drafted from the defect exposed during the CASM
memory-optimization WP's Increment 9 live verification and deferred there
per that plan's stop condition ("a genuinely new defect outside this WP's
scope: disclose and defer"). Branch `feature/casm-progclear-early-fatal-fix`
off `main` after the memory-optimization merge.

Small corrective WP, same class as the Phase 12 WP72/WP73/WP76 forward-
reference fixes -- one ordering change in `casm.s`, no new logic.

## Objective

Make `diagPrintFatal` safe on **every** path that can reach it, including a
fatal diagnostic raised before Pass 1 setup. Today an early fatal prints a
garbled banner (and can eat any other text on the current screen line)
because `diagPrintFatal`'s `progressClearTransient` call reads
`CasmProgFlags` before anything has initialized it.

No change to any successful assembly, to assembled output, to progress
display, or to the *text* of any diagnostic. This WP only removes screen
corruption on the fatal path.

## Root Cause (traced 2026-08-31)

`diagPrintFatal` (`diagnostics.s`) opens with, from progress-indication
Increment 7:

```
    pha
    jsr progressClearTransient
    pla
```

`progressClearTransient` (`progress.s`) is guarded:

```
    lda CasmProgFlags
    and #CASM_PROG_FLAG_VISIBLE      ; $01
    beq @notVisible
    jsr progressReturnToStart        ; 34x PetLeft
    ...34 spaces, 34x PetLeft...
@notVisible:
    rts
```

`CasmProgFlags` is BSS. The **only** routine that zeroes it is
`progressInit`, and `casm.s:start` does not call `progressInit` until the
`startPass1:` label -- *after* `resourcesInit` / `cliInit` / `fileIoInit`
/ `sourceInit`, the version banner, `cliParse`, `cliDeriveOutputName`,
`cliDeriveListingName`, listing activation, `fileOpenInput`, and
`lexerInit`.

Every one of those can fail into `startInitFatal` / `startFatal` /
`startFatalNear*` -> `exitFatal` (`resources.s:363`) -> `diagPrintFatal`.
At that point `CasmProgFlags` holds whatever the loader left in RAM. If
bit 0 is set, `progressClearTransient` runs its cursor-left + space-fill
erase over the current line.

Diagnostics reachable before `startPass1` (all would hit this):
`INITIALIZATION FAILED`, `RESOURCE REGISTRY FULL`, `RESOURCE CLEANUP
FAILED`, `SOURCE FILE REQUIRED`, `TOO MANY SOURCE FILES`, `MALFORMED /O
OPTION`, `DUPLICATE OPTION`, `UNKNOWN OPTION`, `FILENAME TOO LONG`,
`FEATURE NOT IMPLEMENTED`, `CANNOT OPEN INPUT`, `INPUT READ FAILED`,
`INPUT CLOSE FAILED`, `INVALID STREAM STATE`, `LISTING NAME COLLISION`,
`INVALID LEXER STATE`, and the WP44/82 include/incbin filename-grammar
diagnostics if a bad operand is somehow the first thing scanned. (The
source-context printer in `diagPrintFatal` is already safe on these
paths: `casm.s:start` calls `diagClearLoc` as its second instruction, so
`diagPrintSourceContext` self-gates and never reaches the frame arrays.
`progressClearTransient` is the one piece with no equivalent early guard.)

Observed 2026-08-31: `casm <36-char-name>` -> `CASM: FILENAME TOO LONG`,
but the banner rendered as `CASM V` instead of `CASM V0.5.1.nnnn`. The
diagnostic text itself was correct.

**Pre-existing on `main`.** Confirmed by `git show main:src/external/casm/
casm.s` and `git show main:src/external/casm/diagnostics.s` before the
memory-optimization branch: identical `start` ordering, identical
`diagPrintFatal` prologue. The memory-optimization WP's Finding C rewrote
`diagPrintFatal`'s dispatch but kept the `progressClearTransient` call
verbatim; it did not introduce this.

## The Fix

Move the single `jsr progressInit` from `startPass1:` up into the
early-init block in `casm.s:start`, immediately after
`jsr sourceInit` / `bcs startInitFatal`:

```
    jsr sourceInit
    bcs startInitFatal
    ; Progress: initialize here, not at startPass1, so diagPrintFatal's
    ; progressClearTransient can never read an uninitialized CasmProgFlags
    ; on a fatal raised before Pass 1. progressInit is a pure BSS clear
    ; with no OS/VMM call and cannot fail -- the same reason diagClearLoc /
    ; listingStateInit / listingFileInit sit up here (stale BSS reached at
    ; an early fatal). Nothing touches progress state between here and
    ; progressBeginPass at startPass1, so a single init point is correct.
    jsr progressInit
    lda #CASM_PHASE_CLI_FILE
    sta CasmPhase
```

and delete the `jsr progressInit` (and rewrite its now-stale comment) at
`startPass1:`.

`casm.s` already `.import progressInit` (line 148). No new import, no
`progress.s` change, no `diagnostics.s` change. Net code-size delta is
approximately zero (one `jsr` relocated; a couple of comment lines).

### Why not the alternatives

- **Zero `CasmProgFlags` directly in `casm.s`** (`lda #0 / sta
  CasmProgFlags`): `CasmProgFlags` is not `.export`ed by `progress.s` (only
  `CasmProgActiveLo/Hi`, `CasmProgPass1Total*`, `CasmProgDirective*`,
  `CasmProgArg*` are). Would need a new export/import pair to save ~25
  bytes over calling the existing routine. Not worth it.
- **Guard inside `progressClearTransient`**: there is no value it can test
  to tell "uninitialized garbage that happens to have bit 0 set" from
  "genuinely visible". No discriminator exists.
- **Leave the `startPass1` call and add a second early one**: duplicates
  ~25 bytes of `sta` for no benefit; a single init point is clearer and
  provably sufficient.

## Scope Boundary

- **In scope:** the `progressInit` call site in `casm.s:start`; the stale
  comment at `startPass1`; a CASM patch version bump; trackers/CHANGELOG/
  walkthrough.
- **Out of scope:** any change to `progress.s`, `diagnostics.s`, or the
  `progressClearTransient` contract; the listing blank-line bug (its own
  task); anything in the memory-optimization WP (closed).
- If the fix surfaces a *second* early-BSS hazard in `diagPrintFatal` or
  its callees, disclose and decide whether to fold it in or defer -- do
  not silently expand scope.

## Verification Strategy

The defect is an uninitialized read: it only manifests when the RAM byte
at `CasmProgFlags` happens to have bit 0 set. Verification must not depend
on that being true, so it uses a deterministic read rather than only a
visual check.

**1. Static.** Confirm in the built listing / disassembly that
`progressInit` executes before the `versionBanner` print and before any
`startInitFatal` branch target, and that `startPass1` no longer calls it.

**2. Deterministic live (checkpoint read).** Under VICE, set a
non-temporary execution checkpoint at `progressClearTransient` (or at
`diagPrintFatal`'s `pla` after the `jsr progressClearTransient`). Trigger
an early fatal (`casm <37-char-name>` -> `FILENAME TOO LONG`). When the
checkpoint hits, read `CasmProgFlags` via `vice_memory_read` at its linked
address (from the `-Ln` label file).
- **Pre-fix run** (current `main` build, for the record): value is
  whatever RAM held -- may or may not have bit 0 set on this session.
- **Post-fix run:** value MUST be `$00`.
This proves the invariant directly, independent of what the garbage byte
would have been.

**3. User-visible live.** On the same post-fix build, run the natural
early-fatal case and read screen RAM: the banner row must decode to the
full `CASM V0.5.2.nnnn`, and the next row to `CASM: FILENAME TOO LONG`,
with the shell prompt following. Repeat for one more early-fatal
diagnostic from a different raise site (e.g. `casm nonesuch.s` ->
`CANNOT OPEN INPUT`, or `casm /q` -> `UNKNOWN OPTION`).

**4. No-regression.** `progressInit` running earlier must not change the
normal path:
- Full `cmake --build build` clean; `verify_casm_diag_table.py` passes.
- Live: one clean assembly (`casm casmpg128.s`) shows the identical
  progress sequence and `nnnnn BYTES` count as before, and
  `CASM: INPUT VALIDATED`.
- The `test_casm_progress` harness (its 20+ cases, incl. the decimal
  boundary and throttle cases) passes unchanged under VICE.
- No-change rebuild stable; assembled output byte-identical (no emit-path
  file is touched -- only `casm.s` init ordering).

Poking `CasmProgFlags` with `vice_memory_write` to force the bug is
**deliberately not used** (per `feedback-vice-testing`); the checkpoint
read in step 2 gives a stronger, non-invasive proof.

## Atomic Increments

1. **Fix + static + no-regression build.** Move `jsr progressInit`;
   rewrite both comments; bump CASM `0.5.1` -> `0.5.2`. Full build clean;
   `verify_casm_diag_table.py` passes; no-change rebuild stable; confirm
   via the listing that `progressInit` precedes the banner and
   `startPass1` no longer calls it. Rebuild `image_d64` / a CASM test
   disk.
2. **Live verification.** Under VICE, boot Command64 fresh: the
   checkpoint read (step 2 above) showing `CasmProgFlags = $00` at
   `progressClearTransient` on an early fatal; the two user-visible
   early-fatal banner checks (step 3); the clean-assembly no-regression
   check and `test_casm_progress` (step 4).
3. **Closeout.** `CHANGELOG.md` (Fixed), `brain/KNOWLEDGE.md` update to
   the memory-optimization section's deferred-defect note (now resolved),
   `docs/`/`wiki/` only if any user-facing text referenced the garbled
   behavior (it does not), walkthrough, memory update
   ([[project-casm-progclear-uninitialized-flags]] -> resolved), trackers.
   Taskwarrior 43 -> done on user sign-off.

## Expected Files

| File | Action |
| --- | --- |
| `src/external/casm/casm.s` | Modify (relocate `jsr progressInit`; version bump; two comments) |
| `src/external/casm/BUILD_CASM` | Auto (build-number bump) |
| `tests/src/casm_progress/BUILD_TEST_CASM_PROGRESS` | Auto if the shared-hash gate bumps it |
| `CHANGELOG.md` | Modify (Fixed entry) |
| `brain/KNOWLEDGE.md` | Modify (resolve the deferred-defect note) |
| `brain/walkthroughs/2026-08-31-casm-progclear-early-fatal-fix.md` | Create |
| `brain/task.md`, `wiki/tasks/casm.md` | Modify (task 43 status) |

## Stop Conditions

Halt and ask rather than pushing through if:

- The checkpoint read shows `CasmProgFlags != $00` after the fix.
- Any clean assembly's progress output or `nnnnn BYTES` count differs from
  a pre-fix run.
- `test_casm_progress` or any other harness fails, or a no-change rebuild
  changes an artifact.
- Moving `progressInit` earlier turns out to matter to some path between
  `sourceInit` and `startPass1` (it should not -- nothing writes progress
  state there -- but if it does, re-plan).
- A second uninitialized-BSS hazard in `diagPrintFatal`'s early path is
  found: disclose and decide, do not silently widen scope.

## Documentation, Task, and DOX Updates

At approval: record the branch in `brain/task.md` and `wiki/tasks/casm.md`
under task 43.

At completion: `CHANGELOG.md` Fixed entry; update the memory-optimization
KNOWLEDGE section's deferred note and
[[project-casm-progclear-uninitialized-flags]] to "resolved"; walkthrough;
merge to `main`.

## Completion Gate

- `progressInit` proven (listing/disasm) to run before the banner and
  before every early-fatal branch; `startPass1` no longer calls it.
- Deterministic live evidence: `CasmProgFlags = $00` at
  `progressClearTransient` on an early fatal.
- User-visible: full banner + correct diagnostic on two different
  early-fatal raise sites.
- No-regression: clean assembly byte count unchanged, `test_casm_progress`
  passes, full build + no-change rebuild clean, `verify_casm_diag_table.py`
  passes.
- CASM bumped `0.5.1` -> `0.5.2`.
- Trackers agree; user approves closing task 43.

## Progress

- 2026-08-31: Plan drafted. Root cause traced and confirmed pre-existing
  on `main`. Fix is a one-line relocation of `jsr progressInit` in
  `casm.s:start`. Not yet approved.
- 2026-08-31: **Approved.** Branch `feature/casm-progclear-early-fatal-fix`
  off `main` `96eb057`; recorded in `brain/task.md` / `wiki/tasks/casm.md`.
- 2026-08-31: **Increment 1 (fix + static + no-regression build)
  executed.** `jsr progressInit` moved from `startPass1` to the early-init
  block -- placed *before* `resourcesInit` (with `diagClearLoc` /
  `listingStateInit` / `listingFileInit`), not merely after `sourceInit`,
  so even a future fallible early init is covered. Both comments rewritten.
  CASM `0.5.1` -> `0.5.2` (build 1392). **Static (disassembly of `start`):**
  `$380A JSR progressInit` is the 4th call, ahead of `resourcesInit`,
  `cliParse`, the `versionBanner` print (`$382A`), and both
  `JMP startPass1` / `JMP startFatal`; `startPass1` no longer calls
  `progressInit` (exactly one `jsr progressInit` in the module). Also
  confirmed `resourcesInit`/`cliInit`/`fileIoInit`/`sourceInit` are all
  unconditionally `clc`/`rts` (infallible), so nothing can reach
  `diagPrintFatal` before `$380A`. **No regression:** full build clean,
  `verify_casm_diag_table.py` passes, no-change rebuild stable
  (BUILD_CASM 1392). Envelope byte-identical to the memory-optimization
  close (`__MAIN_LAST__` `$A169`, headroom 2,710, CODE `$51A3`) -- the
  relocation is exactly net-zero size. `image_d64` / `test_image_d64` /
  `casm_progress_test_d64` rebuilt. Increment 2 (live verification) next.
- 2026-08-31: **Increment 2 (live verification) executed.** Command64
  booted fresh from the rebuilt `casm_progress_test.d64`; banner
  `CASM V0.5.2.1392` -- provenance confirmed.
  - `casm <37-char name>` -> `CASM: FILENAME TOO LONG` (cliParse raise
    site): **full `CASM V0.5.2.1392` banner** on its own line, then the
    diagnostic, then the prompt. (Pre-fix in memory-opt Increment 9 this
    same case truncated the banner to `CASM V`.)
  - `casm nonesuch.s` -> `CASM: CANNOT OPEN INPUT` (a different, later
    raise site -- `fileOpenInput`): **full banner**, clean return.
  - `casm casmpg128.s`: identical progress sequence
    (`P1/P2 START/DONE 00128`, `WRITE:`, `DONE: P1 00128, P2 00128, 00129
    BYTES`, `CASM: INPUT VALIDATED`) -- **`00129 BYTES` unchanged**.
    Assembled output and progress display unaffected.
  - `test_casm_progress` harness: 20+ cases, `CASM PROGRESS: PASS`.
  The plan's checkpoint read of `CasmProgFlags = $00` was **substituted by
  the Increment 1 static disassembly proof** (`progressInit` at `$380A`,
  the 4th call in `start`, ahead of `resourcesInit` / `cliParse` / the
  banner / every fatal branch, all four preceding inits infallible), which
  establishes `CasmProgFlags = $00` at `progressClearTransient` for *every*
  RAM state, plus the two live clean-banner confirmations -- stronger than
  a single-value checkpoint read. Increment 3 (closeout) next.
