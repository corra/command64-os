---
feature: casm-native-assembler
phase: 3
work-package: 6
created: 2026-07-16
status: approved
implementation-status: complete
depends-on: casm-phase-3-wp05-newlines-provenance
approval-required: true
---

# CASM Phase 3 WP6 Plan: Deterministic Rewind and Bounded Line API

## Approval Gate

The user approved this plan and authorized WP6 implementation on 2026-07-16,
selecting **Option A** (partitioned single buffer) for buffer ownership and the
**recommended `"2000"` envelope** increase. A material change to the source ABI,
state layout, buffer contract, memory envelope, or work-package boundary
requires an amended plan and renewed approval.

WP6 completion is separately gated: after implementation and static
verification, the user must run the supported C64/VICE or hardware fixture
matrix, approve the walkthrough, and explicitly confirm completion before WP6 is
marked done or the version advances from `0.1.7` to `0.1.8`.

## Objective

Add deterministic close/reopen `sourceRewind` and the bounded `sourceNextLine`
convenience API on top of WP5's normalized source layer. A rewind must reset the
source so a second traversal is byte-, newline-, and location-identical to the
first. The line API must deliver logical lines bounded to 255 payload bytes,
reject embedded nulls and overlong lines, and keep byte-mode and line-mode
ownership of `CasmIoBuffer` explicit and mutually exclusive.

WP6 changes no newline or provenance semantics; it consumes WP5's
`sourceNextByte` unchanged. The lexer remains WP7.

## Prerequisites and Inherited Decisions

- WP5 is complete at `0.1.7`, build 1022. `sourceNextByte` returns the normalized
  BYTE/NEWLINE/EOF model; `sourceGetLocation` is a validated in-place accessor;
  `CasmSourceOffset` is the physical consumed offset and equals `CasmInputTotal`
  at first EOF.
- WP3 supplies the 16-byte source subrecord. WP6 activates `CasmSourceLineLength`
  and `CasmSourceLineState` (WP4 initialized both) and reuses `CasmSourceApiMode`.
  **WP6 adds no BSS and no state-layout change** under the recommended option.
- Existing constants are sufficient: `CASM_SOURCE_API_BYTE`/`_LINE`,
  `CASM_SOURCE_LINE_IDLE`/`_BUILDING`/`_READY`/`_EOF`,
  `CASM_SOURCE_LINE_PAYLOAD_MAX` (`$FF`), `CASM_DIAG_SOURCE_REWIND_FAILED`
  (`$14`), `CASM_DIAG_SOURCE_LINE_TOO_LONG` (`$17`),
  `CASM_DIAG_INVALID_SOURCE_BYTE` (`$19`). WP6 changes no `common.inc` value.
- Diagnostic `$14`/`$17`/`$19` display text and dispatch remain WP10, exactly as
  WP4 owned `$15` and WP5 owned `$16` without message text.
- `inputStreamOpen`/`Read`/`Close` remain the only path to file services and
  central ownership. WP6 makes no direct OS file call.
- Current measurements: 2,859 code/data bytes, 512 BSS, **725 bytes of `$1000`
  envelope headroom**. See the Envelope Decision below.
- No `c64-testing` or web emulator verification is permitted.

## Sub-Phase Dependency Audit and Resolutions

| Package | WP6 provides | Explicitly deferred |
|---|---|---|
| WP7 lexer core | Deterministic rewind for replay, a stable byte-mode contract, and the documented requirement that the lexer invalidate its own lookahead after a rewind | All lexer state, lookahead storage/invalidation, token capture |
| WP8-WP9 classification | Unchanged normalized byte transport across rewind | Token scanning and tables |
| WP10 diagnostics/token dump | Stable `$14`/`$17`/`$19` codes and the rewind/line paths | Their display text and dispatch; the token dump that first makes rewind equivalence and line coordinates runtime-observable |
| WP11 closeout | Rewind/line static evidence and the memory baseline | Cumulative Phase 3 verification |
| Phase 4+ (Pass 1/Pass 2) | The rewindable-source guarantee that Pass 2 reparses rather than holding a syntax tree | Pass orchestration |

Resolved discrepancies:

1. **The single-buffer line window is not realizable by naive reuse.** The
   parent plan and `AGENTS.md` say line mode "owns `CasmIoBuffer` as a bounded
   line window" while byte mode owns it as a transfer block. Building a line by
   appending into the same buffer that supplies the bytes is self-clobbering: a
   line spanning a block boundary is destroyed when `inputStreamRead` refills
   `CasmIoBuffer[0..255]`. This plan resolves it with an explicit partitioned
   scheme (Buffer Ownership Decision below) rather than leaving the contradiction
   implicit.
2. **Lookahead reset ownership.** Phase 0C.1 says `sourceRewind` "resets byte,
   newline, location, lookahead, and line-window state," but lookahead is lexer
   state and WP4/WP5 fixed that `source.s` writes no lexer state. Resolution:
   `sourceRewind` resets only source-owned state. Invalidating
   `CasmLookahead*` after a rewind is **WP7's responsibility**, discharged by
   `lexerInit` or an explicit lexer reset that orchestration calls after a
   successful rewind. WP6 records the obligation; it does not write lexer state.
3. **Block cursor becomes absolute.** Under the recommended option,
   `CasmSourceBlockIndex`/`BlockLen` are reinterpreted as **absolute
   `CasmIoBuffer` positions** rather than base-relative counts. Byte-mode
   behavior is bit-identical because its base is always 0 (`index` 0..256,
   `len` = bytes read). Only line mode uses a nonzero base. This is a
   documentation-level redefinition of WP4/WP5 fields with no layout change.
4. **Mode claiming and mixing.** `sourceOpen` continues to commit
   `CASM_SOURCE_API_BYTE` (unchanged WP4 ABI). `sourceNextLine` promotes the mode
   to `CASM_SOURCE_API_LINE` **only on a fresh stream** (physical offset 0, line
   state IDLE). After any byte has been consumed, `sourceNextLine` returns
   `CASM_DIAG_STREAM_STATE_FAILED`; once LINE is claimed, `sourceNextByte`
   returns the same. `sourceRewind` resets the mode to BYTE, which is the
   "explicit rewind/reset" the contract requires before switching APIs.
5. **Line result codes reuse existing constants.** `sourceNextLine` returns
   `CASM_SOURCE_NEWLINE` when a line is available and `CASM_SOURCE_EOF` when no
   further line exists. Whether the available line was newline- or
   EOF-terminated is recorded in `CasmSourceLineState`
   (`READY` vs `EOF`). This avoids a `common.inc` ABI change, which WP3 froze.
6. **Rewind diagnostics.** A close failure during rewind returns the Phase 2
   close diagnostic `$0D` with the handle retained in CLOSE_FAILED for central
   retry — that is the primary failure and `$14` must not mask it. A successful
   close followed by a failed reopen returns `CASM_DIAG_SOURCE_REWIND_FAILED`
   (`$14`) with the source left CLOSED/NONE and no leaked handle. A secondary
   cleanup failure never overwrites the primary, following the `outputAbort`
   precedent.
7. **Null rejection stays line-mode only.** WP4 resolution #6 and WP5 keep a
   `$00` byte a valid `CASM_SOURCE_BYTE` in byte mode. Only `sourceNextLine`
   rejects an embedded null with `$19`, because only the approved line contract
   declares nulls invalid source.
8. **Rewind equivalence is not runtime-observable in WP6.** The parent gate
   ("two traversals return identical bytes, newline results, and locations")
   needs WP10's token dump to observe. WP6's achievable gate is static proof plus
   the count invariant on both traversals, with coordinate-level confirmation a
   recorded WP10 dependency — the same observability boundary WP5 accepted.
9. **A new bounded read wrapper is required.** Line mode must refill only the
   region above the accumulated payload, but `inputStreamRead` hardcodes
   destination `CasmIoBuffer` and length 256. WP6 adds a narrow, additive
   `inputStreamReadInto` to `fileio.s` that takes a destination and length and
   keeps the same checked `CasmInputTotal` accounting and `$15` overflow mapping.
   `inputStreamRead` is retained and reimplemented as a thin call into it so byte
   mode is provably unchanged.

## Buffer Ownership Decision (requires approval)

Both options satisfy "byte and line ownership are explicit and mutually
exclusive." They differ in whether the no-second-buffer contract holds.

### Option A — partitioned single buffer (recommended)

`CasmIoBuffer` is partitioned while a line is being built:
`[0 .. lineLength-1]` is the accumulated line payload and
`[lineLength .. 255]` is the unread transfer region.

- `sourceNextLine` calls WP5's `sourceNextByte` unchanged, so **all newline
  normalization, pending-CR, location, and EOF logic is reused, not duplicated**.
- Each returned byte is appended at `CasmIoBuffer[lineLength]`.
- On refill in LINE mode, `sourceRefill` reads into `CasmIoBuffer + lineLength`
  with length `256 - lineLength` and sets `index = lineLength`,
  `len = lineLength + bytesRead` (absolute positions), preserving the payload.

Safety rests on one invariant, which the plan requires be proven in review:
**writePos (`lineLength`) is always ≤ readPos (`index`)**, with equality only
immediately after a LINE-mode refill. Because `sourceNextByte` loads the byte
into `CasmSourceResultByte` *before* `sourceNextLine` stores it, the
equality case is a read-then-write of the same cell and is safe. A CRLF swallow
or a newline advances readPos without advancing writePos, which only widens the
margin.

- Honors the approved no-second-buffer contract; adds no BSS.
- Costs a narrow `fileio.s` wrapper and the absolute-cursor redefinition.

### Option B — dedicated 256-byte line buffer

`sourceNextLine` appends into a separate 256-byte BSS buffer.

- Simplest possible implementation and no aliasing argument at all.
- **Violates** the approved "Phase 3 allocates no second 256-byte buffer" rule in
  Phase 0C.1, `AGENTS.md`, and `KNOWLEDGE.md`, so it requires those contracts to
  be amended and re-approved.
- Costs 256 BSS bytes, reducing headroom from 725 to 469 and worsening the
  envelope problem below.

**Recommendation: Option A.** It keeps the approved contract, adds no storage,
and — decisively — reuses WP5's normalization instead of duplicating a second
newline state machine that could silently diverge from byte mode.

## Envelope Decision (requires approval)

WP6 fits today, but Phase 3 as a whole does not. Measured and projected:

| Item | Code/data |
|---|---:|
| Current (WP5, build 1022) | 2,859 |
| WP6 rewind + line API + wrapper (est.) | ~250-320 |
| WP7 lexer core (est.) | ~300-400 |
| WP8 textual/numeric tokens (est.) | ~300-500 |
| WP9 mnemonic table (168) + classify (est.) | ~320 |
| WP10 diagnostics text + token dump (est.) | ~200-400 |

Against 512 BSS and a `$1000` (4,096) envelope, the current 725 bytes of
headroom cannot absorb the ~1,370-1,940 bytes WP6-WP10 require. **Phase 3 will
not fit in the `$1000` envelope**, and the parent plan directs implementation to
stop for approval in exactly this case.

`add_ca65_app(casm ... "1000")` sets `MAIN: size`, which covers CODE, RODATA,
DATA, and BSS. Raising it is a one-argument build change with existing
precedent: `debug` uses `2000`, `pacman` `2800`, `edlin` `1800`.

- **Recommended:** raise the CASM envelope to `"2000"` (8,192) in this work
  package, matching DEBUG's precedent and leaving roughly 4,800 bytes of
  headroom for WP7-WP10 plus Phase 4 growth. Relocation and R6 behavior are
  unchanged; only the linked size bound moves.
- **Alternative:** keep `"1000"` for WP6 and defer the increase to the first work
  package that actually fails to link. This risks discovering the wall mid-WP7
  and forces an unplanned amendment then.

Either way, WP6 must re-measure and stop if it cannot link.

## Scope

### Included

- `sourceRewind`: validated close/reopen with full source-owned reset and
  primary-diagnostic preservation;
- `sourceNextLine`: bounded logical lines with 255-byte payload, optional null
  terminator, `$17` overflow rejection before storing the offending byte, and
  `$19` embedded-null rejection;
- LINE/BYTE mode claiming and mutual exclusion with `$13` on mixing;
- LINE-mode partitioned refill and the absolute block cursor (Option A);
- additive `inputStreamReadInto` with unchanged `CasmInputTotal` accounting;
- the approved envelope change;
- build, artifact, memory, relocation, and fixture verification; and
- documentation, task, walkthrough, changelog, memory, knowledge, and DOX
  closeout after completion approval, then advance `0.1.7` to `0.1.8`.

### Excluded

- lexer state, lookahead invalidation, tokens, classification, token dump;
- newline or provenance semantic changes;
- diagnostic message text or dispatch for `$14`/`$17`/`$19`;
- new persistent BSS or `common.inc` changes (under Option A);
- VMM-backed source, includes, or multiple top-level inputs;
- output creation or assembly behavior; and
- DEBUG source or table changes.

## Planned Files

| Path | Action | Responsibility |
|---|---|---|
| `src/external/casm/source.s` | Modify | `sourceRewind`, `sourceNextLine`, mode gating, LINE-mode refill, absolute cursor |
| `src/external/casm/fileio.s` | Modify narrowly | Additive `inputStreamReadInto`; `inputStreamRead` reimplemented as a thin caller |
| `CMakeLists.txt` | Modify if the envelope change is approved | Raise the CASM `MAIN` size |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify | 255-accepted / 256-rejected line fixtures and an embedded-null fixture |
| `casm.s` | Unchanged unless a rewind smoke path is approved | See Entry-Point Integration |
| `wiki/tasks/casm.md`, `brain/task.md` | Modify at closeout | WP6 state and evidence |
| `brain/KNOWLEDGE.md` | Modify at closeout | Buffer partition, absolute cursor, rewind/lookahead split, mode claiming |
| `brain/MEMORY.md` | Modify at closeout | Measured growth, envelope decision, remaining headroom |
| `CHANGELOG.md` | Modify at closeout | Observable package/version state |
| `brain/walkthroughs/2026-07-16-casm-phase3-wp06-rewind-line-api.md` | Create at closeout | Static, artifact, and user runtime evidence |
| `src/external/casm/AGENTS.md` | Modify | The buffer-ownership rule needs the partition made explicit |

`common.inc` and `state.s` are unchanged under Option A.

## Rewind Contract

`sourceRewind` is permitted in READY and EOF (a rewind from ERROR is not
supported; callers with a primary failure go to central cleanup).

1. Validate state; otherwise `$13` with no OS call.
2. `inputStreamClose`. On failure: source ERROR, handle retained in
   CLOSE_FAILED, return `$0D` (primary; not masked by `$14`).
3. `inputStreamOpen`. On failure: source CLOSED/NONE, no leaked handle, return
   `$14`.
4. On success: commit READY/BYTE and call `sourceResetTraversal`, which already
   restores file ID, block cursor, offset, line 1, column 1, pending-CR, result
   byte, line length, and line state — the full source-owned reset.

Rewind therefore resets byte, newline, location, and line-window state.
Lookahead invalidation is WP7's (resolution #2).

## Line API Contract

`sourceNextLine` requires LINE mode (claimed per resolution #4) and READY/EOF.

- Set `CasmSourceLineLength = 0`, `CasmSourceLineState = BUILDING`.
- Loop `sourceNextByte`:
  - **BYTE**: if the byte is `$00` → `$19`. If `CasmSourceLineLength` already
    equals `CASM_SOURCE_LINE_PAYLOAD_MAX` (255) → `$17` **before storing**.
    Otherwise store at `CasmIoBuffer[lineLength]` and increment.
  - **NEWLINE**: line complete; `LineState = READY`; return
    `CASM_SOURCE_NEWLINE`.
  - **EOF**: if `lineLength > 0`, return the final unterminated line as
    `CASM_SOURCE_NEWLINE` with `LineState = EOF`; if `lineLength == 0`, set
    `LineState = EOF` and return `CASM_SOURCE_EOF`.
  - **Failure**: propagate unchanged; source is already ERROR.
- The payload is `CasmIoBuffer[0 .. CasmSourceLineLength-1]`, null-terminated at
  `[lineLength]` for convenience. A 255-byte payload plus terminator exactly
  fills the 256-byte buffer, and the terminator cell is always already-consumed
  or past valid data, never unread input.
- The line is valid only until the next source call; callers copy it.
- EOF remains repeat-stable.

## Routine ABI

### `sourceRewind`

- Inputs: source READY or EOF.
- Success: A=`CASM_DIAG_NONE`, C clear; state READY, API BYTE, traversal reset.
- Failure: A=`$0D` (close, ownership retained, source ERROR), `$14` (reopen,
  source CLOSED/NONE), or `$13` (state), C set.
- Preserves: none. Clobbers: A, X, Y, wrapper/OS volatile state.

### `sourceNextLine`

- Inputs: LINE mode claimed or claimable; state READY/EOF.
- Line: A=`CASM_SOURCE_NEWLINE`, C clear; payload in `CasmIoBuffer[0..len-1]`,
  `CasmSourceLineLength` = length, `CasmSourceLineState` = READY or EOF.
- EOF: A=`CASM_SOURCE_EOF`, C clear; `CasmSourceLineLength` = 0.
- Failure: A=`$13`, `$17`, `$19`, or a propagated byte diagnostic, C set.
- Preserves: none. Clobbers: A, X, Y, source scratch, refill/OS volatile state.

### Unchanged

`sourceInit`, `sourceOpen`, `sourceNextByte`, `sourceGetLocation`, and
`sourceClose` keep their ABI. `sourceNextByte` gains only the mode gate.

## Entry-Point Integration

`casm.s` keeps its consume-only byte loop and `INPUT VALIDATED` output; the
production path does not call `sourceRewind` or `sourceNextLine`, and WP10 still
owns the token dump. Because nothing in the shipped path exercises the new
routines, WP6 is verified statically and by fixtures; a temporary rewind or
line smoke path would be new observable behavior and is a stop condition unless
separately approved.

## Atomic Implementation Increments

1. Activate the WP6 task records without marking them complete.
2. Apply the approved envelope change and re-measure.
3. Add `inputStreamReadInto`; reimplement `inputStreamRead` on top of it and
   prove byte mode is unchanged.
4. Reinterpret the block cursor as absolute and prove byte mode is bit-identical.
5. Implement `sourceRewind` with reset and the diagnostic/ownership rules.
6. Add mode claiming and the `$13` mixing gate.
7. Implement `sourceNextLine` with `$19`, `$17`, terminator, and EOF handling.
8. Implement LINE-mode partitioned refill and prove the writePos ≤ readPos
   invariant, including the post-refill equality case.
9. Add the 255/256/null fixtures.
10. Build; run static carry, cursor, ownership, aliasing, and mode audits.
11. Inspect linked memory, artifact, relocations, and a no-change rebuild.
12. Prepare documentation, task, changelog, walkthrough, and DOX closeout.
13. Ask the user to run the matrix and approve completion.
14. Only after approval, mark WP6 complete and advance `0.1.7` to `0.1.8`.

## Verification

### Static and Build Verification

- prove byte mode is unchanged by the absolute cursor and the wrapper refactor;
- prove the writePos ≤ readPos invariant and the safe read-then-write equality
  case after a LINE-mode refill;
- prove a line spanning a block boundary survives refill;
- prove 255 payload bytes are accepted and the 256th fails with `$17` before
  storing;
- prove an embedded null fails with `$19` in line mode and remains a valid BYTE
  in byte mode;
- prove rewind resets every source-owned field and that two traversals are
  byte-, newline-, and location-identical by construction;
- prove close-failure retains ownership and returns `$0D`, and reopen-failure
  returns `$14` with no leaked handle;
- prove mode mixing returns `$13` and that rewind re-enables mode choice;
- confirm no lexer state is written and no BSS/`common.inc` change (Option A);
- inspect map, BSS, relocations, PRG header, R6 footer; confirm the linked image
  fits the approved envelope; and
- confirm a no-change rebuild does not increment `BUILD_CASM`; build `image_d64`
  and `test_image_d64`.

### User Runtime Matrix

The production path is unchanged, so the runtime matrix confirms non-regression:
the existing newline fixtures still reach `INPUT VALIDATED`, `casm256`/
`casmmulti` still return `$16`, a missing file still reports cleanly, and a
second launch is clean. Rewind equivalence and line coordinates become
observable in WP10 (resolution #8). No runtime result is assumed.

## Stop Conditions

Stop and request an amendment if implementation requires:

- a second 256-byte buffer (unless Option B is approved);
- any new BSS, zero-page alias, `common.inc` constant, or state-layout change;
- duplicating newline normalization in line mode;
- writing lexer state from `source.s`;
- direct OS file calls outside the Phase 2 wrappers;
- weakening the EOF count invariant, resource registration, or close-failure
  retention;
- new observable behavior in the shipped path; or
- linked growth that cannot fit the approved envelope.

## Documentation and DOX Closeout

`src/external/casm/AGENTS.md` **will** need updating: its current rule says line
mode owns `CasmIoBuffer` as a bounded line window, which resolution #1 shows is
only realizable as an explicit partition. The durable rule becomes the payload/
transfer partition plus the absolute cursor. Synchronize `wiki/tasks/casm.md`,
Taskwarrior, `brain/task.md`, `KNOWLEDGE.md`, `MEMORY.md`, `CHANGELOG.md`, and
the walkthrough at closeout. Do not mark WP6 or Phase 3 done without explicit
user approval.

## Completion Gate

WP6 is eligible for completion approval only when:

- `sourceRewind` and `sourceNextLine` match this ABI;
- rewind produces a byte-, newline-, and location-identical second traversal and
  resets every source-owned field;
- close/reopen failures preserve the primary diagnostic and central ownership;
- lines of 255 bytes are accepted, 256 rejected with `$17`, embedded nulls
  rejected with `$19`, and a boundary-spanning line survives refill;
- byte/line mixing is rejected and rewind restores mode choice;
- byte mode and the shipped path are provably unregressed;
- the build, artifact, memory, relocation, no-change, and release-disk checks
  pass within the approved envelope;
- the walkthrough contains user runtime evidence; and
- the user explicitly approves marking WP6 complete, advancing `0.1.7` to
  `0.1.8`.
