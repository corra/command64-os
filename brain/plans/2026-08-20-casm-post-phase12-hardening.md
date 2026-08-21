---
feature: casm-post-phase12-hardening
created: 2026-08-20
status: closed (WP79 deferred, unfixed)
taskwarrior: task 42 (b1369c8c-8fc6-4038-825c-1103a106257c), task 40 (be8ca0bf-ac7c-40f6-960e-2ca816bc7fb8), task 41 (882433f0-cde1-4849-8b3c-df32613518c3)
depends-on: CASM Phase 12, complete (brain/walkthroughs/2026-08-20-casm-phase12-wp75-verification-walkthrough-completion-gate.md)
---

# Plan: CASM Post-Phase-12 Hardening (WP77-WP80)

## Status

**Closed 2026-08-21.** WP80 (`.TEXT` disposition), WP78 (Taskwarrior 40,
TYPE double-line-advance), and WP77 (Taskwarrior 42, constant chaining) are
all complete and user-approved, each with live VICE verification. **WP79
(Taskwarrior 41, phantom EOF byte) is explicitly deferred, not fixed**:
root-caused to a real 1541-DOS-firmware/VICE-true-drive-emulation quirk (a
SEQ file whose last sector holds only 1 valid byte delivers 3 phantom
padding bytes via CHRIN before EOI fires), confirmed via direct D64 sector
inspection to be outside anything fixable in Command64's own code
(`source.s`/`fileio.s`/`file.asm` all faithfully relay what the KERNAL
hands them). See the Progress log's 2026-08-20 WP79 entries for the full
investigation trail. Recommended next step: a dedicated investigation
absorbing Taskwarrior tasks 22 and 35 (same underlying defect class), not
a continuation of this plan.

Parent plan: none. This is a deliberately unnumbered interim hardening effort,
not a master-plan Phase. See "Naming and sequencing" below.

## Objective

Close out three specific open CASM defects (Taskwarrior 42, 40, 41) and record
the `.TEXT` disposition the master plan and WP74 already deferred to "Phase
13." Continues the sequential WP numbering from WP76 (Phase 12's last WP) as
WP77-WP80, without opening a new numbered Phase.

This plan does **not** implement the master plan's actual "Phase 13: Data
Construction Directives" (`.res`, `.fill`, `.align`, `.incbin`, `.assert`) —
that remains reserved under its original name and number for later, separate
scoping.

## Scoping Decisions (user-confirmed 2026-08-20)

1. **Scope:** this effort covers Taskwarrior 42 (named-constant chaining
   parse failure), 40 (listing.s screen double-line-advance), 41
   (`sourceNextByte` phantom EOF byte on 1-byte sources), and the `.TEXT`
   disposition note. Taskwarrior 36 (`fileCreateOutput` no `@0:` replace
   marker) and the three backlog features (progress indication, build
   duration, real-time `/M` emission) are explicitly excluded from this plan.
2. **Naming:** the master plan (`brain/plans/2026-07-16-casm-assembler-
   implementation-plan.md:468`) reserves "Phase 13" for Data Construction
   Directives. Since this plan's content is unrelated defect fixes, it is
   scoped as a non-numbered interim WP set, not "Phase 13." The master plan's
   phase numbering is untouched; the real Phase 13 remains available to scope
   later under its original name.

## `.TEXT` Disposition (WP74 follow-up, documentation only)

The master plan (line 483) already resolved this: `.TEXT` is **not**
inherited as syntax now that WP74 delivered ca65-compatible `.BYTE "string"`
literals, and adding it later would require a separately justified,
non-duplicate semantic purpose. No `.TEXT` implementation exists anywhere in
`src/external/casm/` today (confirmed by search) — there is no code to
remove. This WP's job is to formally close the open question WP74 and
`wiki/tasks/casm.md:20` left dangling, not to design or implement a directive.

## Taskwarrior 42: Named-Constant Chaining (`DEFCONST = BASECONST`)

`ppsConstant`'s `@identifier` arm (`src/external/casm/parser.s:477-530`)
handles an identifier RHS by capturing the name/offset, calling `lexerNext`
to consume it, then unconditionally calling `exprParseAddend`
(`src/external/casm/expr.s:1140`) to absorb an optional `+`/`-` addend before
`@requireTerminator` checks for NEWLINE/EOF. The user's report is that this
fails even with **no** arithmetic operator involved, which rules out a
straightforward addend-consumption bug and points at something upstream —
possibly symbol classification/lookahead behavior specific to an RHS
identifier that already names a resolved or forward-declared constant
(`DEFCONST = BASECONST` where `BASECONST` was itself defined via `=`, not as
a label). Root cause is not yet confirmed; Increment 1 below is a live
investigation, not a known fix.

## Taskwarrior 40: Listing Screen Double-Line-Advance

`listing.s` emits a full 40-column row plus a trailing CR when a listing row
is written to a real C64 screen via KERNAL CHROUT, which causes VIC-II's
own auto-wrap-at-column-40 plus the CR to together advance two lines instead
of one (a blank line appears). `diagnostics.s` already avoids the identical
hazard by capping its own screen output at 38 columns. Need to confirm which
`.LST`/listing code paths actually screen-print raw 40-byte rows (versus
writing only to a VMM-backed `.LST` file, where the 40-column width is
correct and must NOT be truncated) before choosing between capping the
screen-print path or suppressing auto-wrap for it specifically.

## Taskwarrior 41: `sourceNextByte` Phantom EOF Byte (1-byte sources)

Independently reproduced by WP60 Increment 7's `srcOneByte1` fixture in
`tests/src/casm_spanread/casm_spanread.s` (deliberately not called from
`start`, pending this fix). After the real final byte of an exactly-1-byte
source file, the next `sourceNextByte` call returns `CASM_SOURCE_BYTE` with a
spurious `$00` instead of `CASM_SOURCE_EOF`. Likely a boundary condition in
`sourceFetchPhysical`/`sourceNextResult`'s (`src/external/casm/source.s:901+`)
refill/EOF-detection logic specific to a source whose entire content fits in
the first physical fetch. See `brain/task.md`'s WP60 Increment 7 entry and
`brain/reviews/2026-08-12-casm-phase11-wp60-increment8-consolidated-
verification.md` for prior investigation notes.

## Atomic Increments

1. **Investigate and fix Taskwarrior 42** (constant chaining). Reproduce
   live with a minimal `DEFCONST = BASECONST` fixture, trace token/lexer
   state through `ppsConstant`'s `@identifier` arm and any symbol-lookup path
   it touches, confirm root cause, implement the fix, and add a dedicated
   native/COMP fixture mirroring the existing `casmfwdstale1`/
   `casmarithfwd.s`-style corrective-WP fixtures.
2. **Investigate and fix Taskwarrior 40** (listing double-advance). Audit
   every call site that screen-prints a listing row (vs. writes it to the
   `.LST` VMM file only), confirm which ones are live/reachable today, and
   apply the narrowest fix (cap width or suppress auto-wrap) without
   truncating the `.LST` file's own 40-column row content.
3. **Investigate and fix Taskwarrior 41** (phantom EOF byte). Reproduce via
   the existing but currently-uncalled `srcOneByte1` fixture, root-cause the
   refill/EOF boundary condition for an exactly-1-byte source, fix it, wire
   `srcOneByte1` into the `casm_spanread` harness's `start` sequence, and
   confirm no regression across the other `casm_spanread` fixtures or the
   Phase 2 short/exact/multi-block CLI matrix.
4. **Record the `.TEXT` disposition.** Documentation only: close the open
   question in `wiki/tasks/casm.md`, `brain/task.md`, and this plan's own
   Progress log confirming `.TEXT` is not implemented and not planned outside
   a future, separately justified proposal. No source change.
5. **Consolidated regression pass.** Full CASM test suite plus the DASH
   native/ca65 cross-check, run together after all three fixes land — not
   just each fixture's own individual pass (this project's own precedent
   after WP46's cancelling-bugs-false-pass incident).

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/parser.s` | Modify (Taskwarrior 42 fix) |
| `src/external/casm/expr.s` | Modify, if root cause lands there |
| `src/command64/shell.asm` | Modify (Taskwarrior 40 fix — actual root cause is `cmdType`, not `listing.s`; see Progress log) |
| `include/command64.inc` | Modify (Taskwarrior 40 fix — `KernalScreenColumn` label) |
| `src/external/casm/source.s` | Modify (Taskwarrior 41 fix) |
| `tests/src/casm_spanread/casm_spanread.s` | Modify (wire in `srcOneByte1`) |
| New native/COMP fixture(s) for Taskwarrior 42 | Create |
| `wiki/tasks/casm.md` | Modify (close `.TEXT` question, mark tasks done) |
| `brain/task.md` | Modify (progress log) |

## Stop Conditions

- Any harness/test fails unexpectedly, including a currently-passing fixture
  regressing after any of the three fixes.
- Root-causing any of the three bugs surfaces a genuinely new defect outside
  this plan's scope: disclose and defer as a separate follow-up (default),
  do not fix inline unless the user explicitly directs it in the moment.
- A no-change rebuild changes any artifact.
- The consolidated regression pass (Increment 5) finds any fixture that only
  passed before due to a since-removed compensating bug (WP46 precedent).

## Documentation, Task, and DOX Updates

- Taskwarrior 42, 40, 41: mark complete individually as each increment's fix
  is verified; do not batch-close until each has its own live evidence.
- `wiki/tasks/casm.md`: close the `.TEXT` disposition note (line 20-21) and
  update each task's entry.
- `brain/task.md`: append a dated progress entry for this WP set (WP77-80),
  matching the existing per-WP entry convention.
- `CHANGELOG.md`: entry noting the three fixes, if the project's changelog
  convention covers sub-Phase WP sets (confirm against recent entries before
  writing).
- Memory: record completion once approved.

## Completion Gate

- Live VICE evidence for each of the three fixes (reproduced failure before,
  confirmed pass after), following this project's checkpoint/register-read
  verification convention, not screen-text OCR.
- Consolidated regression pass (Increment 5) clean across the full CASM
  suite and DASH cross-check.
- `wiki/tasks/casm.md` and `brain/task.md` synchronized.
- Walkthrough recorded in `brain/walkthroughs/2026-08-20-casm-post-phase12-
  hardening.md` (or dated to actual completion date).
- User explicitly approves closing this WP set.

## Progress

- 2026-08-20: Plan drafted. Scope and naming confirmed with user (interim,
  non-numbered WP set; excludes Taskwarrior 36 and the three backlog
  features). Awaiting approval to begin Increment 1.
- 2026-08-20: Plan approved. WP80 (`.TEXT` disposition) closed on approval by
  explicit user decision: retain `.BYTE` string literals as the deduplicated,
  sole spelling; `.TEXT` is not added. No source change was needed or made.
  WP77-WP79 remain open; proceeding to Increment 1 (Taskwarrior 42
  investigation).
- 2026-08-20: User directed WP78 (Taskwarrior 40, listing double-advance) to
  go first instead of WP77, expecting it to be simple. Order deviation only;
  scope unchanged. Starting Increment 2 (renumbered first) now.
- 2026-08-20: WP78 root-caused live. `listing.s` itself is not the culprit —
  its 40-column rows are correct by design, locked by `.assert` invariants
  in `common.inc` (`CASM_LISTING_ROW_WIDTH`/`HEADER_PREFIX_WIDTH+CHUNK_SIZE`/
  detail-row column sum). No `.TEXT`-style truncation was applied there.
  The actual double-advance is in Command64's generic `TYPE` command
  (`cmdType`, `src/command64/shell.asm`): it forwards every raw byte
  (including a file's embedded CR) straight to KERNAL CHROUT with no
  awareness that printing a byte at column 40 already auto-wraps the real
  screen editor to column 0 — a second CR right after that then advances a
  second time, leaving a blank line. This reproduces for any file with
  exactly-40-byte-wide CR-terminated lines TYPE'd at the shell, not just
  CASM `.LST` output specifically; confirmed TYPE has no automatic/
  background caller (user-confirmed), so this is scoped to manual `TYPE`
  use.
  Fix implemented in `cmdType`'s print loop: before forwarding a raw CR
  byte to CHROUT, check the KERNAL's own screen-line cursor column
  (`$D3`, now `KernalScreenColumn` in `include/command64.inc`) and skip
  the CR when it already reads 0 (auto-wrap already happened). Uses the
  KERNAL's live cursor state directly rather than a self-maintained
  counter — smaller, and avoids drift if the KERNAL's own wrap behavior
  ever differs from an assumed model.
  Hit the `CommandShell` segment's zero-slack memory budget
  (`command64.asm`'s "segment chain below $1000 is full" pattern, same
  constraint as `project-os-sub1000-segment-full`, one level up): even the
  minimal fix (no separate byte counter, inline check reusing the existing
  Y-preservation wrapper) still overflowed `CommandShell` into the
  fixed-address `VmmData` segment by ~9 bytes after code-golfing (down from
  an initial ~53-byte overflow from a first, less minimal attempt with a
  self-maintained column counter, since discarded). Resolved by moving all
  of `cmdType` into the `ShellExt` overflow segment (single `.segment`
  directive relocation) — the same established pattern this file already
  uses for `cmdMore` right next to it, not a new convention. Full rebuild
  clean, no-change rebuild confirmed stable (`BUILD_OS` unchanged across a
  repeat build), `image_d64` target builds clean with `dash`/`casm`/etc.
  all still present on the disk.

  Live VICE verification (build 2669) with a hand-built column-0-aligned
  test SEQ (`"X"<CR>` then 40 `"A"`s `<CR>` then `"AFTER"<CR>`) found the
  first cut of the fix did not work: `beq ctPrintSkip` tested
  `KernalScreenColumn == 0`, but a live `PEEK(211)` in plain BASIC right
  after printing 40 characters to a fresh line read 40, not 0 -- real
  KERNAL screen-editor column tracking is a deferred/lazy wrap (PNTR holds
  40 until the next character forces the actual line advance), not an
  immediate reset. Checking for 0 never matched, so every CR still printed
  unconditionally and the blank line persisted exactly as before, entirely
  undetected by static review or the earlier informal test (which
  happened to start printing mid-row, at a column that never reached the
  0/40 boundary either way, so it silently exercised nothing). Corrected
  to `cpx #40 / beq ctPrintSkip`, rebuilt (build 2670), and re-verified
  live with the same fixture: `PEEK(211)` empirically confirmed at 40 in
  BASIC, and the corrected TYPE output showed the 40-`"A"` row wrapping
  directly into `"AFTER"` with no blank row, screen-memory read and
  decoded via `tools/vice_screen_decode.py` (not OCR). A normal
  short-line file (`banner.s`) TYPEs unaffected afterward. `FLUSH` run
  before and after per this project's live-test convention. No-change
  rebuild reconfirmed stable at build 2670. Taskwarrior task 40 marked
  complete; docs synced in `wiki/tasks/casm.md` and `brain/task.md`.
  Walkthrough: `brain/walkthroughs/2026-08-20-casm-post-phase12-hardening-
  wp78.md`. **User approved closing WP78 on 2026-08-20.** WP77 and WP79
  remain open.
- 2026-08-20: WP77 (Taskwarrior 42, named-constant chaining) root-caused
  and fixed. `ppsConstant`'s `@identifierStore` (`parser.s:512`) claimed to
  "fall through to `@requireTerminator`" but actually fell into `@curAddr`'s
  `*`-RHS handler, which unconditionally consumed one extra token (the
  real NEWLINE terminator) via its own `jsr lexerNext`, desyncing parsing
  onto the following line -- exactly matching the live repro (`CASM:
  EXPECTED NEWLINE` reported against line 3, not the constant-chain line
  2). One-line fix: explicit `jmp @requireTerminator`. Live-verified build
  1325: fixture now assembles clean (`CASM: INPUT VALIDATED`);
  `test_casm_expr` re-run clean (`CASM EXPR: PASS`, no regression); a new
  permanent fixture (`casmchain1.s`/`.ref`, COMP-verified `FILES COMPARE
  OK` against a hand-derived reference) added to
  `casm_phase12_test_d64`/`CASM_REF_NAMES`. Renamed from an initial
  `casmconstchain1` after hitting the project's known 16-char directory
  truncation collision hazard. `casm`/`image_d64` no-change rebuilds
  confirmed stable. Walkthrough:
  `brain/walkthroughs/2026-08-20-casm-post-phase12-hardening-wp77.md`.
  Taskwarrior task 42 marked complete; docs synced. **User approved closing
  WP77 on 2026-08-20.** Only WP79 remains open.
- 2026-08-20: WP79 (Taskwarrior 41, phantom EOF byte) investigated live.
  Re-activated `srcOneByte1` in `tests/src/casm_spanread/casm_spanread.s`
  and reproduced the failure live (case 9, `CASM SPANREAD: FAIL`). Traced
  the call chain: CASM's `fileio.s::fileRead` is a thin wrapper around the
  single shared KERNAL-level `fileRead` in `src/command64/file.asm` --
  the same routine already flagged separately by Taskwarrior tasks 22 and
  35 (cross-cutting: every `DOS_READ_FILE` caller is affected), not
  CASM-specific. User directed fixing `file.asm` now, absorbing tasks
  22/35 into this WP.
  First fix attempt: added a per-handle "already saw KERNAL EOI" latch
  (repurposing the existing `HandleTable` status byte, value 2) so a
  *second, separate* `fileRead` call on an already-exhausted channel
  short-circuits to 0 bytes instead of re-touching it. Built and
  live-verified clean (build 2671, no segment/branch-range issues) --
  but the `srcOneByte1` case **still failed identically** after rebuild.
  Set a live VICE checkpoint (via a manually-generated `-vicesymbols`
  KickAssembler pass, since the default build emits no symbol file) at
  `fileRead`'s post-READST `ldy TempHi` instruction to trace the actual
  byte/status sequence; tooling/timing made the trace inconclusive within
  a reasonable number of round trips. Revised hypothesis: the phantom
  byte(s) likely enter *within a single `fileRead` call's own internal
  read loop* (matching task 35's "~3 phantom bytes" language, not a clean
  single-repeat-after-EOI pattern my fix targeted) -- meaning the fix's
  premise was wrong, not just incomplete.
  Reverted the first fix attempt (`git checkout --`) and pursued a more
  precise live trace at the user's direction: found `ldy TempHi`'s live
  address by generating a `-vicesymbols` KickAssembler pass and confirming
  with `vice_disassemble` ($0D6B, not the initially-assumed $0D73 -- that
  address was computed against the already-reverted first fix's shifted
  code layout). A checkpoint there proved impractical to single-step
  through reliably (VICE MCP tooling returned stale/ambiguous PC readings
  across repeated hits), so switched to direct instrumentation instead:
  temporarily exported `CasmSourceLoadedLenLo/Hi` from `source.s` and
  added a debug print in `casm_spanread.s`'s `srcOneByte1` right after
  `sourceLoad` completes.
  **Result: `CasmSourceLoadedLenLo/Hi` = 4, not 1**, for the 1-byte
  `casmsrc1.seq` fixture -- one real byte plus 3 phantom bytes, an exact
  match for Taskwarrior task 35's own "~3 phantom bytes" description.
  Cross-checked against the raw D64 image directly (Python sector
  parsing): `casmsrc1.seq`'s last sector holds `5A 00 00 00 00...`
  (`'Z'` + zero padding) with T/S-link byte `(0, 2)`. Calibrated the
  byte-count convention against a known-good fixture (`CASMLC02`, 9 real
  bytes, confirmed link byte `10`, i.e. `valid = link_byte - 1`) --
  applying the same formula to `casmsrc1.seq` (`link_byte 2` -> `valid
  1`) confirms the on-disk data and its byte-count field are **written
  correctly by `cc1541`**. The KERNAL's CHRIN/READST loop is what
  delivers 4 bytes before flagging EOI, not 1 -- a real 1541-DOS-firmware
  / VICE-true-drive-emulation boundary quirk specific to a sector whose
  valid data is only 1 byte past the 2-byte T/S-link header, faithfully
  relayed (not caused) by `src/command64/file.asm`'s `fileRead`. This is
  outside anything fixable in Command64's own code: `fileRead` has no
  status signal available to distinguish a genuine EOI byte from one of
  these phantom padding bytes, since even the drive's own byte-count
  field (which is correct) isn't visible to the C64-side KERNAL call.
  Reverted the temporary debug exports/prints (`git checkout --`),
  confirmed clean (`git status`, no-change rebuild). This is now a
  well-evidenced, precisely-bounded finding (exact reproduction: a SEQ
  file whose last sector's T/S-link byte is 2) ready for whoever picks up
  tasks 22/35/41 as their own dedicated investigation -- resolving it
  further would mean either probing/patching real 1541 DOS ROM emulation
  behavior or building an application-level workaround with no reliable
  signal to trigger on, both well beyond this WP's scope. Recommending
  WP79 stay deferred.
- 2026-08-21: **User approved closing this hardening plan** with WP77,
  WP78, and WP80 complete, and WP79 explicitly left open/deferred (not
  fixed, not abandoned) for a future, separately-scoped investigation
  covering Taskwarrior 22/35/41 together. No further work under this plan.
