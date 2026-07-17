---
feature: casm-native-assembler
phase: 3
work-package: 7
created: 2026-07-17
status: approved
implementation-status: complete
depends-on: casm-phase-3-wp06-rewind-line-api
approval-required: true
---

# CASM Phase 3 WP7 Plan: Minimal Lexer Core

## Approval Gate

The user approved this plan and authorized WP7 implementation on 2026-07-17,
selecting **Option 1** (static-only, no entry-point change). The multi-digit
`VERSION_STAGE` migration required to complete at `0.1.9` (Scope, increment 11)
remains an open decision to be resolved at closeout before completion. A material
change to the token ABI, lexer state model, source-consumption contract, or
work-package boundary requires an amended plan and renewed approval.

Implementation note (recorded during WP7): `lexerFill` captures provenance by
reading the source's exported in-place location fields (the documented
`sourceGetLocation` accessor surface, WP5 resolution #3) and clamps the
column-exhausted latch to `CASM_SOURCE_COLUMN_MAX`; actual column overflow stays
enforced by `sourceNextByte`. It does not invoke the `sourceGetLocation`
validation call, whose latch-`$16` is intentionally strict for byte-only queries
and would wrongly reject a maximal-length line ending in a newline. No
source-layer change.

WP7 completion is separately gated: after implementation and static
verification, the user must run the supported fixture matrix, approve the
walkthrough, and explicitly confirm completion before WP7 is marked done or the
version advances from `0.1.8` to `0.1.9`.

Note the version boundary: per the parent plan and `AGENTS.md`, the one-byte
`VERSION_STAGE` banner cannot represent a two-digit stage, and a separately
planned multi-digit stage migration is a hard prerequisite **before any work
package at `0.1.9` may be completed**. WP7 completes *into* `0.1.9`, so that
migration must land as part of WP7 closeout or immediately before it. This is
called out in Scope and the Completion Gate.

## Objective

Create `lexer.s`, the first consumer of the WP4-WP6 source layer, and implement
the minimal lexer core: initialization, one-result lookahead over
`sourceNextByte`, token reset/append/emit primitives, whitespace skipping,
semicolon-comment skipping that preserves the terminating newline token, and the
punctuation and delimiter tokens. Every token captures file, line, and column
provenance taken before its first byte is consumed. EOF is a repeat-stable token.

WP7 does not scan identifiers, directives, registers, or numbers (WP8), classify
mnemonics (WP9), or wire the token dump into the entry point (WP10). It changes
no source-layer behavior.

## Prerequisites and Inherited Decisions

- WP6 is complete at `0.1.8`, build 1025. `sourceNextByte` returns the normalized
  BYTE/NEWLINE/EOF model; `sourceGetLocation` reports the next result's
  provenance; `sourceRewind` and `sourceNextLine` exist.
- WP3 froze the token ABI and allocated the 47-byte lexer/lookahead/token
  subrecord in `state.s`: `CasmLexerState`, `CasmLookaheadValid`,
  `CasmLookaheadResult`, `CasmLookaheadByte`, `CasmLookaheadFileId`,
  `CasmLookaheadLineLo/Hi`, `CasmLookaheadColumn`, the 39-byte `CasmTokenRecord`,
  and `CasmTokenText`. **WP7 adds no BSS**; it initializes and uses this
  subrecord.
- `CasmLexerState` has no defined enum yet — WP3 reserved the byte for WP7. This
  plan authorizes adding `CASM_LEXER_STATE_*` values to `common.inc` (new ABI
  that WP3 deferred, not a change to a frozen value), mirroring
  `CASM_SOURCE_STATE_*`.
- Existing constants are otherwise sufficient: token types `$00-$0F`,
  `CASM_SUBTYPE_NONE`, record offsets (`TYPE`=0 … `TEXT`=7),
  `CASM_TOKEN_TEXT_MAX`=31, the PETSCII punctuation/whitespace/semicolon bytes,
  and diagnostics `CASM_DIAG_TOKEN_TOO_LONG` (`$18`),
  `CASM_DIAG_LEXER_STATE_FAILED` (`$1B`), and `CASM_DIAG_NOT_IMPLEMENTED` (`$0A`).
- Lexer transient scratch is `CasmLexerScratch0/1` (`$82/$83`).
- Phase 3 diagnostic display text (`$14-$1B`) remains WP10; WP7 returns codes
  only.
- Envelope: `$2000`, 4,509 bytes of headroom after WP6. WP7 is estimated at
  ~300-400 bytes and does not approach the envelope.
- No `c64-testing` or web emulator verification is permitted.

## Sub-Phase Dependency Audit and Resolutions

| Package | WP7 provides | Explicitly deferred |
|---|---|---|
| WP8 textual/numeric tokens | The lookahead, the bounded token reset/append/emit primitives, and the single dispatch default arm they will replace with identifier/number scanning | Identifier/directive/register/number scanning; `$18` overflow exercise; `$1A` malformed number |
| WP9 mnemonic classification | The identifier token path (once WP8 exists) and the token record it classifies | The mnemonic table and case-insensitive classification |
| WP10 diagnostics/token dump | The complete lexer to drive, stable token types, and provenance | The token-dump wiring into the entry point and all `$14-$1B` display text |
| WP11 closeout | Lexer static evidence and the memory baseline | Cumulative Phase 3 verification |

Resolved discrepancies:

1. **The lexer has no runtime driver until WP10, and cannot traverse real source
   until WP8.** The token dump that makes tokens observable is WP10, and every
   existing fixture contains letters, which WP7's dispatch cannot yet classify
   (it hits the not-implemented default arm). So WP7 cannot be driven end-to-end
   at runtime on real source. This is the widest form of the observability
   boundary WP5 and WP6 already accepted. WP7's achievable gate is static proof;
   see the Observability Decision for the one optional lever.
2. **Lexer state enum ownership.** WP3 left `CasmLexerState`'s values undefined
   for WP7. This plan defines `CASM_LEXER_STATE_INIT`/`_READY`/`_EOF`/`_ERROR` in
   `common.inc` as new ABI. This is the only `common.inc` change and it adds
   constants without altering any frozen value; it is authorized by this plan.
3. **The unclassified-byte dispatch arm.** WP7's dispatch handles EOF, newline,
   whitespace, comments, and punctuation. Any other byte (letters, digits, `.`,
   `$`, `%`, and genuinely invalid bytes) hits a single default arm that returns
   `CASM_DIAG_NOT_IMPLEMENTED` (`$0A`) as a transitional placeholder. WP8
   replaces that one arm with identifier/number scanning; `$0A` is honest
   ("feature not implemented") rather than `$19` ("invalid source byte"), which
   would wrongly condemn valid identifier bytes.
4. **`$18` (token too long) ownership.** The bounded `lexerTokenAppend` primitive
   is built in WP7 and returns `$18` when a token would exceed 31 payload bytes.
   WP7's own tokens are one byte, so the overflow path is present but exercised by
   WP8's identifier scanning.
5. **Lookahead invalidation after rewind (discharges WP6 resolution #2).**
   `source.s` writes no lexer state, so WP6 deferred lookahead invalidation to the
   lexer. WP7 discharges it: `lexerInit` clears `CasmLookaheadValid`, and
   orchestration must call `lexerInit` after any successful `sourceRewind`. WP7
   documents this obligation for Phase 4 Pass 2.
6. **Source API choice.** The lexer consumes `sourceNextByte` (the byte stream),
   never `sourceNextLine`. Per Phase 0C.1, the line API is a fixture/diagnostic
   convenience and explicitly not the lexer's backing store. This also keeps the
   lexer clear of line mode's `CasmIoBuffer` partition.
7. **Provenance capture timing.** `lexerFill` snapshots `sourceGetLocation` into
   the lookahead provenance fields *before* calling `sourceNextByte`, so the
   lookahead carries the coordinates of the byte it holds. A token's start
   provenance is copied from the lookahead into the token record before the byte
   is consumed, satisfying "token start location captured before the first byte."
8. **Failures do not close the source.** A lexer failure returns carry set with a
   diagnostic and leaves the source open; orchestration closes it or central
   cleanup retains ownership. WP7 never calls `sourceClose`.
9. **Version-stage boundary.** WP7 completes into `0.1.9`, which the frozen
   one-byte `VERSION_STAGE` banner cannot represent past a single digit. The
   multi-digit stage migration named in the parent plan is a prerequisite for
   completing at `0.1.9` and must be handled at WP7 closeout (see Scope).

## Observability Decision (requires approval)

WP7's core cannot be runtime-observed through the shipped path, which still runs
the byte-consume loop and prints `INPUT VALIDATED`. Two ways to proceed:

- **Option 1 — static-only (recommended).** Implement and statically verify the
  lexer; add no fixtures and no entry-point change. Runtime observation arrives
  with WP8 (identifiers let the lexer traverse real source) and WP10 (the token
  dump prints types and locations). This matches the established WP5/WP6 boundary
  and keeps the token dump firmly in WP10.
- **Option 2 — WP7 lexer-only smoke path.** Add one punctuation/whitespace/
  comment/newline fixture with no letters, plus a temporary driver that runs
  `lexerNext` to the EOF token and prints the existing success message. This
  gives real WP7 runtime signal but pulls a slice of WP10's driver forward and
  adds a temporary entry-point branch, which is otherwise a stop condition.

**Recommendation: Option 1.** The lexer's first honest end-to-end runtime pass is
WP8, and a bespoke WP7-only driver is throwaway work that duplicates WP10. WP7's
tokens are simple enough for static tracing to be decisive.

## Scope

### Included

- create `lexer.s` with `lexerInit`, `lexerNext`, `lexerGetToken`;
- add `CASM_LEXER_STATE_*` to `common.inc`;
- one-result lookahead over `sourceNextByte` with provenance snapshot;
- bounded token reset/append/emit primitives with the `$18` guard;
- whitespace (space, tab) skipping;
- semicolon comment skipping preserving the terminating newline token;
- EOF, newline, comma, colon, hash, parens, plus, minus, less, greater tokens;
- a single not-implemented default arm for later WP8 replacement;
- the multi-digit `VERSION_STAGE` migration required to complete at `0.1.9`,
  preserving the independent build number (or an explicitly approved deferral);
- build, artifact, and memory verification; and
- documentation, task, walkthrough, changelog, memory, knowledge, and DOX
  closeout after completion approval, then advance `0.1.8` to `0.1.9`.

### Excluded

- identifier, directive, register, and number scanning (WP8);
- mnemonic classification and tables (WP9);
- the token dump and entry-point wiring (WP10, unless Option 2 is approved);
- Phase 3 diagnostic display text (WP10);
- source-layer behavior changes;
- new BSS or token-ABI changes; and
- statement parsing or any Phase 4 behavior.

## Planned Files

| Path | Action | Responsibility |
|---|---|---|
| `src/external/casm/lexer.s` | Create | Minimal lexer core and token primitives |
| `src/external/casm/common.inc` | Modify | Add `CASM_LEXER_STATE_*` enum only |
| `src/external/casm/casm.s` | Unchanged (Option 1) | Entry point stays byte-consume; the multi-digit banner change is separate |
| `src/external/casm/state.s` | Unchanged | The lexer subrecord already exists |
| `wiki/tasks/casm.md`, `brain/task.md` | Modify at closeout | WP7 state and evidence |
| `brain/KNOWLEDGE.md` | Modify at closeout | Lexer state model, lookahead/provenance, dispatch default arm, rewind obligation |
| `brain/MEMORY.md` | Modify at closeout | Measured growth and remaining envelope |
| `CHANGELOG.md` | Modify at closeout | Observable package/version state |
| `brain/walkthroughs/2026-07-17-casm-phase3-wp07-minimal-lexer-core.md` | Create at closeout | Static and artifact evidence |
| `src/external/casm/AGENTS.md` | Modify | Record lexer ownership, lookahead, and the rewind-invalidation obligation |

The multi-digit `VERSION_STAGE` migration touches `casm.s` and possibly the
build banner; its exact file set is defined when that sub-task is planned at
closeout.

## Lexer State and Token Model

### Lexer state

`CASM_LEXER_STATE_INIT` (before `lexerInit`), `_READY` (producing tokens),
`_EOF` (EOF token latched, repeat-stable), `_ERROR` (a failure occurred). A
lexer failure sets `_ERROR` and returns the diagnostic; the source is left to
orchestration.

### Lookahead

One result slot: `CasmLookaheadValid`, `CasmLookaheadResult` (BYTE/NEWLINE/EOF),
`CasmLookaheadByte`, and the provenance `CasmLookaheadFileId`,
`CasmLookaheadLineLo/Hi`, `CasmLookaheadColumn`.

- `lexerFill`: if not valid, snapshot `sourceGetLocation` into the lookahead
  provenance, call `sourceNextByte`, store its result code and
  `CasmSourceResultByte`, and set valid. A source failure propagates and leaves
  the lookahead invalid.
- `lexerConsume`: clear `CasmLookaheadValid` so the next fill advances.
- The slot survives input-block transitions because it is persistent BSS, and it
  is invalidated by `lexerInit` after a rewind.

### Token primitives

- `lexerTokenReset`: copy the lookahead provenance into
  `CasmTokenRecord[FILE_ID/LINE_LO/LINE_HI/COLUMN]` and set `LENGTH` = 0.
- `lexerTokenAppend`: if `LENGTH` == `CASM_TOKEN_TEXT_MAX` (31) return `$18`
  before storing; else store the byte at `CasmTokenText[LENGTH]` and increment.
- `lexerEmit`: set `TYPE` and `SUBTYPE`, null-terminate `CasmTokenText[LENGTH]`,
  return carry clear with `A` = token type.

### `lexerNext` flow

1. If `_EOF`, return the EOF token (repeat-stable). If `_ERROR` or `_INIT`,
   return `$1B`.
2. Skip loop: `lexerFill`; on BYTE space/tab, consume and repeat; on BYTE
   semicolon, consume bytes until the lookahead result is NEWLINE or EOF, then
   repeat (the newline/EOF is preserved for emission).
3. Dispatch on the lookahead:
   - EOF result: `lexerTokenReset`, set `_EOF`, emit an EOF token (length 0).
   - NEWLINE result: `lexerTokenReset`, consume, emit a NEWLINE token (length 0).
   - punctuation byte (`, : # ( ) + - < >`): `lexerTokenReset`, append the byte,
     consume, emit the mapped token type.
   - any other byte: return `CASM_DIAG_NOT_IMPLEMENTED` (`$0A`), the WP8 seam.

A comment that ends at EOF with no newline emits the EOF token, not a phantom
newline.

## Routine ABI

### `lexerInit`

- Inputs: source initialized/open. Also the required reset after a successful
  `sourceRewind`.
- Success: A=`CASM_DIAG_NONE`, C clear; lexer `_READY`, lookahead invalid, token
  record cleared.
- Preserves: none. Clobbers: A, X, Y.

### `lexerNext`

- Inputs: lexer `_READY` or `_EOF`.
- Success: C clear, A = token type; the token is in `CasmTokenRecord`.
- EOF: C clear, A = `CASM_TOKEN_EOF`, repeat-stable.
- Failure: C set, A = `$1B`, `$18`, `$0A`, or a propagated source diagnostic;
  lexer `_ERROR` (source diagnostics leave the source ERROR); source not closed.
- Preserves: none. Clobbers: A, X, Y, `CasmLexerScratch0/1`, and source volatile
  state.

### `lexerGetToken`

- Inputs: a token has been produced.
- Outputs: X/Y = `CasmTokenRecord` address (low/high); C clear.
- Preserves: the token record. Clobbers: A, X, Y.

Every status path normalizes carry explicitly.

## Entry-Point Integration

Under Option 1, `casm.s` is unchanged: the shipped path keeps its byte-consume
loop and `INPUT VALIDATED` output, and the lexer has no caller until WP10. The
multi-digit `VERSION_STAGE` banner change is the only `casm.s` edit and is a
version-representation concern, not lexer wiring.

## Atomic Implementation Increments

1. Activate the WP7 task records without marking them complete.
2. Add `CASM_LEXER_STATE_*` to `common.inc` with assertions.
3. Create `lexer.s`; implement `lexerInit` and the lookahead fill/consume.
4. Implement token reset/append (with `$18`)/emit primitives.
5. Implement whitespace skipping and the punctuation dispatch and mapping.
6. Implement comment skipping preserving the newline token.
7. Implement EOF latching and repeat-stable EOF, and the not-implemented arm.
8. Implement `lexerGetToken`.
9. Build; run static carry, state, lookahead, provenance, and dispatch audits.
10. Inspect linked memory, artifact, relocations, and a no-change rebuild.
11. Plan and land the multi-digit `VERSION_STAGE` migration (or obtain explicit
    approval to defer it, given completion targets `0.1.9`).
12. Prepare documentation, task, changelog, walkthrough, and DOX closeout.
13. Ask the user to confirm the (static) evidence and approve completion.
14. Only after approval, mark WP7 complete and advance `0.1.8` to `0.1.9`.

## Verification

### Static and Build Verification

- assemble/link the narrow CASM target; confirm the glob discovers `lexer.s`;
- confirm `lexer.s` defines no BSS and only `common.inc` gained constants;
- trace one token of each kind (EOF, newline, each punctuation) and confirm the
  type, `SUBTYPE_NONE`, length, provenance, and terminator;
- prove whitespace is skipped and the following token's provenance is its own
  byte, not the skipped space;
- prove a comment is skipped and its terminating newline is still returned, and
  that a comment at EOF returns EOF with no phantom newline;
- prove EOF is repeat-stable and performs no source read once latched;
- prove the lookahead provenance is snapshotted before `sourceNextByte`, and that
  `lexerInit` invalidates it (the post-rewind obligation);
- prove the not-implemented arm returns `$0A` and the append guard returns `$18`;
- prove a source failure propagates with carry set and the source is not closed;
- inspect map, BSS, relocations, PRG header, R6 footer; confirm the `$2000`
  envelope; confirm a no-change rebuild does not bump `BUILD_CASM`; build
  `image_d64`.

### User Runtime Matrix

Under Option 1 the shipped path is unchanged, so the matrix confirms
non-regression only: the newline and line-boundary fixtures still reach
`INPUT VALIDATED`, the overlong-line fixtures still return the `$16` code, the
empty file still reports the platform open failure, and a second launch is clean.
Token-level behavior becomes observable in WP10. No runtime result is assumed.

## Stop Conditions

Stop and request an amendment if implementation requires:

- new BSS, a token-ABI change, or a change to any frozen `common.inc` value;
- consuming `sourceNextLine` from the lexer or touching source-layer behavior;
- wiring the token dump or a permanent entry-point change (beyond an approved
  Option 2 smoke path or the banner migration);
- diagnostic display expansion for `$14-$1B`;
- classifying identifiers, numbers, or mnemonics; or
- linked growth that cannot fit the `$2000` envelope.

## Documentation and DOX Closeout

Update `src/external/casm/AGENTS.md` to record that `lexer.s` owns the lookahead
and token record, consumes `sourceNextByte`, and must re-init after a rewind.
Synchronize `wiki/tasks/casm.md`, Taskwarrior, `brain/task.md`, `KNOWLEDGE.md`,
`MEMORY.md`, `CHANGELOG.md`, and the walkthrough at closeout. Do not mark WP7 or
Phase 3 done without explicit user approval.

## Completion Gate

WP7 is eligible for completion approval only when:

- `lexerInit`, `lexerNext`, and `lexerGetToken` match this ABI;
- EOF, newline, and every punctuation token carry the correct type, subtype,
  length, provenance, and terminator;
- whitespace and comments are skipped with the newline token preserved;
- EOF is repeat-stable and the lookahead is invalidated by `lexerInit`;
- the not-implemented arm and the `$18`/`$1B` paths are correct;
- lexer failures leave the source open for orchestration;
- no BSS, token-ABI, or source-layer regression occurred and only the lexer-state
  enum was added to `common.inc`;
- the build, artifact, memory, relocation, no-change, and release-disk checks
  pass within the `$2000` envelope;
- the multi-digit `VERSION_STAGE` representation is in place (or its deferral was
  explicitly approved) so completion at `0.1.9` is valid; and
- the user explicitly approves marking WP7 complete, advancing `0.1.8` to
  `0.1.9`.
