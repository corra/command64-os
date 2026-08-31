---
feature: casm-progress-increment04-pass-integration
plan: brain/plans/2026-08-24-casm-progress-increment04-pass-integration.md
date: 2026-08-24
status: approved
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
---

# Walkthrough: CASM Progress Increment 4 -- Pass Integration

## Summary

`progress.s` is now wired into `casm.s`'s real orchestration: pass
start/end, the shared per-statement count hook, overflow propagation, and
cross-pass count agreement. Live under VICE, a real assembly of
`casmopall.s` (151 opcode statements plus labels/directives, 160 total)
produced exactly the persistent-line sequence the parent plan specifies --
`P1: START` / `P1: DONE 00160 STATEMENTS` / `P2: START` / `P2: DONE 00160
STATEMENTS` -- both pass totals agreeing, assembly completing normally
afterward (`CASM: INPUT VALIDATED`), and **output bytes byte-identical**
to the pre-wiring baseline hash.

## Hook Contract compliance

- **Initialize before the first visible transition**: `progressInit`
  is the first instruction under `startPass1:`, before `emitInit` and
  before `progressBeginPass(1)` prints the first `p1: start` line.
- **Begin Pass 1 only after `CasmPassMode=MEASURE`**: `progressBeginPass`
  (A=1) is called immediately after `sta CasmPassMode`, before `casmRunPass`.
- **Begin Pass 2 only after `CasmPassMode=EMIT`**: same pattern, A=2, at
  the Pass 2 setup site.
- **Count only IDENTIFIER/EQUALS/MNEMONIC/DIRECTIVE, after successful
  parse, before dispatch**: see design note below -- four small
  trampolines (`crpCountLabel`/`crpCountConstant`/`crpCountInsn`/
  `crpCountDir`) each call `progressStatement` once, immediately before
  jumping to the unmodified original handler.
- **Exclude NEWLINE and EOF**: the existing `casmRunPass` dispatch chain
  already routes those to `crpDone`/the NEWLINE fallthrough without
  touching the four `crpCount*` trampolines at all -- unchanged.
- **`.INCLUDE` counts exactly once through DIRECTIVE**: `.INCLUDE` is
  `CASM_TOKEN_DIRECTIVE` with `CASM_DIRECTIVE_INCLUDE` subtype, so it
  flows through `crpCountDir` like every other directive, counted once,
  before `crpDir`'s own `.INCLUDE`/emit split runs unmodified.
- **Fail before a 16-bit counter wraps**: `progressStatement`'s own
  overflow guard (Increment 3, unchanged) checks for `$FFFF` before
  incrementing; each `crpCount*` trampoline propagates `C=1`/
  `A=CASM_DIAG_PROGRESS_COUNTER_OVERFLOW` straight to `crpFail`, the same
  path every other internal `casmRunPass` failure already uses.
- **Agreement after include replay and PC agreement, before listing
  finalization; `p2: done` only after all agreement checks pass**:
  `progressCheckPassTotals` is called immediately after
  `emitCheckPassAgreement`'s own success check and before the
  `CASM_OPT_LIST`/`listingCaptureFinalize` gate; `progressCompletePass`
  (which prints `p2: done`) is called only after
  `progressCheckPassTotals`'s own `bcs startFatalNear` has been cleared.
- **Preserve current carry paths and branch-range trampolines**: two new
  near trampolines were needed (design note below); no existing carry
  convention was changed.

## Design note: why four trampolines, not one shared call site

`casmRunPass`'s existing token-type dispatch is a single `lda
CasmParserStmt + CASM_PARSER_STMT_TYPE` followed by a sequential
`cmp`/`beq` chain testing that one loaded `A` against four values in turn.
Calling `progressStatement` (which clobbers `A` -- see Increment 2's
frozen ABI) partway through that chain would corrupt the still-pending
comparisons for token types tested later in the sequence. Routing all four
recognized types through one shared label first would require saving the
token type somewhere before the call and reloading it after -- extra
state and complexity for no real benefit, since each of the four original
`crpLabel`/`crpConstant`/`crpInsn`/`crpDir` handlers already reads
whatever it needs fresh from `CasmParserStmt` in memory rather than
trusting a register carried in from dispatch (confirmed by re-reading all
four before making this change). Four tiny trampolines -- each a
statically-known jump target, so nothing needs reloading -- calling the
one shared `progressStatement` routine is simpler and matches the ABI's
own "shared hook" framing (the routine is shared; the four call sites are
just where the dispatch chain already forks).

## Diagnostics: moved to common.inc, wired into diagPrintFatal

`CASM_DIAG_PROGRESS_COUNTER_OVERFLOW`/`PASS_TOTAL_MISMATCH` moved from
`progress.s` (Increment 3's placeholder location) into `common.inc`,
alongside every other `CASM_DIAG_*` constant, with the codebase's
standard contiguous-allocation `.assert`s. A new `dpfProgressCheck` range
block was added to `diagnostics.s`'s `diagPrintFatal` dispatch (mirroring
`dpfWp81Check`/`dpfWp82Check`/`dpfWp83Generic`'s exact structure) plus a
two-entry `diagProgressMessageLo/Hi` table and two new message strings.
Neither diagnostic's call site stamps a source location first (both are
locationless, like `emitCheckPassAgreement`'s own final-PC check) --
`diagPrintSourceContext` is still called for structural consistency with
every other range in this dispatch and is self-gating, so this prints
nothing extra when no location was set. (An earlier draft of this
comment incorrectly claimed a location was set; caught on self-review
before commit, not by any test failure.)

## Branch-range trampolines added

Two, both a direct consequence of code growing near existing 8-bit
relative branches -- the exact class of issue this file's own comment
history documents repeatedly for every prior WP:

- `casm.s`: `startFatalNear2`, reached by `sourceRewind`'s and
  `includeReplayReset`'s own `bcs` checks, which the new
  `progressInit`/`progressBeginPass`/`progressCompletePass` call sites
  pushed out of range of the existing `startFatalNear` trampoline.
- `diagnostics.s`: converted one `bcc dpfSymbolRange` (in `dpfNotListing`)
  to an explicit `bcs :+ / jmp dpfSymbolRange / :` idiom -- the new
  `dpfProgressCheck` block, inserted just before `dpfSymbolRange`, pushed
  that early branch out of 8-bit range.

## Test-harness envelope corrections (three, all expected)

`diagnostics.s`'s new dispatch block and message table are linked whole
into any harness that links `diagnostics.s`, whether or not that harness's
own coverage ever reaches the new code -- the same "unused but linked"
pattern this codebase's `CMakeLists.txt` comment history has recorded for
every prior WP's `diagnostics.s` growth. Three harnesses needed their
fixed `TEST_PRG_SIZE` bumped to the next round-page fit, each with a
comment recording the exact measured overflow:

| Harness | Overflow | Old -> New |
|---|---|---|
| `test_casm_faultsource` | 104 bytes | `$2F00` -> `$3000` |
| `test_casm_pass1` | 88 bytes | `$6300` -> `$6400` |
| `test_casm_passcheck` | 102 bytes | `$5F00` -> `$6000` |

(One misattribution during this process: an edit was first applied to
`casm_listcap`'s block by mistake -- `casm_listcap` had already built
successfully in the same run, so the edit was reverted and the real
failing block, `casm_pass1`, was found and fixed instead. Caught before
commit by re-reading the actual generated `.cfg` file rather than trusting
line-number proximity in a very long, densely-commented file.)

## Live VICE Evidence

Two checks, one continuous VICE session, port 7000, `image.d64` reattached
and left running afterward.

1. **`test_casm_progress` regression** (unaffected in logic by this
   increment, but its constants moved to `common.inc`): rebuilt, redeployed,
   dispatched by truncated name `test_casm_progre`. Result: `CASM PROGRESS:
   PASS`, all 20 cases, identical to Increment 3's own result.

2. **Real production wiring**, scratch disk (`command64.prg` + newly-built
   `casm.prg`, `casmopall.s`): `CASM CASMOPALL.S /O:WIRED.PRG`. Screen
   output:
   ```
   CASM V0.4.0.1355
   P1: START
   P1: DONE 00160 STATEMENTS
   P2: START
   P2: DONE 00160 STATEMENTS
   CASM: INPUT VALIDATED
   ```
   `WIRED.PRG` extracted and hashed:
   `0bccfbc18392bb108c26b91b9c6b289b1a4537c40b995bdde2e7409939c9f6fc` --
   **identical** to Increment 1's own recorded baseline for this exact
   fixture (`OPALL2.PRG`). Confirms the new wiring changes zero output
   bytes while adding real, correct, visible progress reporting.

Both pass totals matching (160 = 160) is itself live confirmation that
`progressCheckPassTotals` ran and passed silently -- a synthetic
mismatch/overflow harness case was not built this increment (that
remains Atomic Increment 4's own synthetic-harness item, partially
covered already by `test_casm_progress`'s existing `caseCheckPassTotalsMismatch`/
`caseOverflowBeforeWrap` cases at the module level; a production-source
fixture that reaches these paths through real dispatch is not yet
selected and is a reasonable candidate for Increment 8's automated
verification pass rather than this one).

## Build and Envelope Evidence

- Full build: clean, zero warnings/errors, across every target including
  all Phase 9-13 disk images.
- No-change rebuild: `casm.prg` SHA-256 and `BUILD_CASM`'s build number
  both stable across a repeated build with no source changes.
- Final envelope: `__MAIN_SIZE__`=`$7000`, `__MAIN_LAST__`=`$A6AC`. Used
  28332 of 28672 bytes; **340 bytes (1.2%) headroom** -- down from
  Increment 3's 521 bytes, the wiring itself (four trampolines, two new
  pass-boundary call sequences, two branch-range trampolines) costing
  roughly 181 bytes. Still comfortably positive.
- Zero page: unchanged (no `ZEROPAGE` memory area exists in
  `casm_3800.cfg`; no new zero-page storage was added anywhere in this
  increment).

## Stop Conditions

None triggered. No duplicate or missed counts (confirmed live: 160 = 160
across both passes on a real fixture); no parser semantic change (the
four `crpCount*` trampolines wrap the existing handlers without modifying
them); disagreement-check ordering matches the Hook Contract exactly;
carry/stack conventions unchanged (`crpFail`'s existing `C`/`A` contract
reused as-is); the two branch-range failures were fixed the same way this
codebase always fixes them, not worked around; `test_casm_progress` and
the three envelope-corrected harnesses all pass; no envelope cap was
breached (340 bytes remain inside the Increment 2-approved `$7000`
budget); no-change rebuild is stable; and no unrelated defect was found.

## Completion Gate

- [x] Exact totals confirmed live (160/160, matching).
- [x] Exclusions confirmed by code inspection (NEWLINE/EOF untouched by
      the new trampolines).
- [x] Overflow propagation confirmed by code path (shares `crpFail`);
      module-level overflow/mismatch behavior already proven by
      `test_casm_progress` (Increment 3).
- [x] Agreement ordering matches the Hook Contract exactly.
- [x] No regressions: `test_casm_progress` PASS, full build clean, three
      envelope corrections applied and verified, output bytes
      byte-identical to baseline.
- [x] Size (340 bytes / 1.2% headroom) and no-change behavior recorded.
- [x] Trackers agree (Taskwarrior annotation and plan Progress update
      follow this walkthrough).
- [x] User approves Increment 4.
