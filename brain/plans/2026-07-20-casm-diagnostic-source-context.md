---
feature: casm-diagnostic-source-context
created: 2026-07-20
status: planned
---

# Plan: CASM Diagnostic Source Context (WP15)

## Goal & Rationale

Today a source-position failure prints one bare line:

```
CASM: INVALID SOURCE BYTE
```

The message is accurate but unactionable: the user has no line, no column, and
no indication of which byte offended. On a 200-line source this forces a manual
binary search. Every ingredient needed to fix this already exists in the
codebase but none of it reaches the screen.

This work package plumbs a source location through the fatal path and renders a
three-line diagnostic:

```
CASM: INVALID SOURCE BYTE $93
AT LINE 12, COL 9 (OFFSET 8)
  LDA #$0A.,X  ; TRAILING TEXT
          ^
```

## Current State (verified 2026-07-20)

What already exists:

- `CasmSourceLineLo/Hi` + `CasmSourceColumn` (`state.s`) track a live 1-based
  line/column for the *next* result, maintained by `sourceAdvanceNewline` and
  the column latch in `sourceNextResult` (`source.s`).
- `CasmLookaheadLineLo/Hi` + `CasmLookaheadColumn` (`state.s`) hold the
  provenance of the pending lookahead byte — this is exactly the location of
  the offending byte at `lexer.s:148`.
- `CasmTokenRecord + CASM_TOKEN_REC_LINE_LO/_LINE_HI/_COLUMN`
  (`common.inc:302-304`) hold each token's start location.
- `printDec16` and `diagPrintString` (`diagnostics.s`) already render decimal
  numbers and strings; `diagDumpToken` already prints `L:<n> C:<n>`.

What is missing:

1. **Plumbing.** `exitFatal` (`resources.s:360`) accepts a diagnostic in `A`
   and nothing else. No location travels with it.
2. **Line text.** The lexer drives the source in **BYTE mode**, so
   `CasmIoBuffer` holds a 256-byte *block* window, not a line window. By the
   time an error fires mid-line, the start of that line may already have been
   overwritten by a refill. There is no buffer holding the offending line.
3. **Statement location.** `CasmParserStmt` is 6 bytes
   (`TYPE/SUBTYPE/OPKIND/VAL_LO/VAL_HI/REG_SUBTYPE`, `common.inc:396-402`) and
   carries **no** line/column. Emit-stage diagnostics ($1E, $20, $21, $23) have
   no location source today.

## Scope

**In scope** — these diagnostics gain location + caret context:

| Diag | Name | Location source |
|------|------|-----------------|
| $17 | SOURCE_LINE_TOO_LONG | live source cursor |
| $18 | TOKEN_TOO_LONG | token record |
| $19 | INVALID_SOURCE_BYTE | lookahead (+ offending byte) |
| $1A | MALFORMED_NUMBER | token record |
| $1C | SYNTAX_ERROR | token record |
| $1D | EXPECTED_NEWLINE | token record |
| $1E | OPERAND_OUT_OF_RANGE | token record (parser) / stmt loc (emit) |
| $1F | INVALID_ADDR_MODE | stmt loc |
| $20 | DUPLICATE_ORG | stmt loc |
| $21 | ORG_REQUIRED | stmt loc |
| $23 | BRANCH_OUT_OF_RANGE | stmt loc |

**Out of scope** — these stay bare, they have no meaningful source position:
CLI diagnostics ($04-$0A), file/stream diagnostics ($0B-$16), internal state
failures ($1B LEXER_STATE_FAILED, $22 ADDRESS_OVERFLOW), and $01-$03.

Also out of scope: multi-error recovery (CASM still stops at the first error),
`.INCLUDE` file attribution (`CasmSourceFileId` is plumbed but always 0 until
include support lands), and any listing-file output.

## Key Design Decisions

### D1. Line text via echo buffer + forward drain

A new 256-byte `CasmDiagLineBuf` accumulates the current line as the lexer
consumes it. On the fatal path, a drain routine reads forward to the next
newline so text to the *right* of the caret is also shown.

Rejected alternatives:

- **Rewind and replay at report time** — zero extra BSS, but duplicates the
  newline-normalization logic, requires a bespoke path because the source is
  already in `ERROR` state, and re-reads the disk on every error.
- **Switch the lexer to LINE mode** — `sourceNextLine` already buffers a whole
  line with a protected payload region, which would give this for free. But the
  lexer is built on `sourceNextByte` plus a one-byte lookahead, and `source.s`
  explicitly forbids mixing the two APIs without a rewind. This is the *right*
  long-term shape and should be revisited if the lexer is ever reworked, but it
  is far too large a refactor to carry this feature.
- **Line/column with no text** — cheapest, but loses the caret, which is the
  part that actually makes the message self-explanatory.

### D2. Echo capture point

Capture in `source.s`, inside `sourceNextResult`, not in the lexer. The lexer
skips whitespace and comment bodies without recording them, so capturing there
would render a line with holes in it and misalign the caret. The source layer
sees every byte in order.

Cost on the hot path: ~8 cycles per source byte (an `ldx`/`sta abs,x`/`inc`
plus a bounds check). Acceptable — this is disk-bound I/O, not a render loop.

Capture is gated on a flag so LINE-mode callers (which already have the line in
`CasmIoBuffer`) do not pay for it twice.

### D3. Drain is terminal and diagnostic-only

`sourceDrainLineTail` lives in `source.s` so it can use the private
`sourceFetchPhysical`. Its contract is deliberately narrow and must be
documented as such in the routine header:

> Diagnostic-only. May only be called on the fatal path immediately before
> central cleanup. It bypasses the source state gate, may leave the source in
> an unusable state, and never returns a diagnostic of its own — any failure
> silently truncates the displayed line rather than masking the primary
> diagnostic.

Ordering check: `casm.s startFatal` → `outputAbort` → `exitFatal` →
`diagPrintFatal` (drains) → `resourcesCleanup` (closes input). The input stream
is still open when the drain runs. Verified against `resources.s:360-372`.

The drain must be gated on `CasmDiagLocValid`, because `diagPrintFatal` is also
called from the cleanup-failure path at `resources.s:347`, where draining would
be both meaningless and unsafe.

### D4. Statement location without growing the parser ABI

`CASM_PARSER_STMT_SIZE = 6` is guarded by a hard `.assert` and is documented as
a shared ABI. Rather than growing it, add a separate 3-byte `CasmStmtLoc`
(line lo/hi, column) in `state.s`, stamped by `parserParseStatement` from the
first token of each statement. Emit-stage raises read it directly.

### D5. Sanitizing and windowing

- Any byte outside safe printable PETSCII renders as `.`. This is not optional
  polish: `INVALID SOURCE BYTE` fires precisely *because* the byte is unusual,
  and echoing a raw `$93` (clear screen) or `$12` (reverse on) would corrupt or
  erase the very message being printed.
- The offending byte's hex value is appended to the message line for $19 only,
  so the substituted `.` does not hide the information.
- The screen is 40 columns. A line may be 255. Print a 38-char window
  positioned to keep the error column visible, with `<..` / `..>` clipping
  markers. The caret offset is computed relative to the window, not the line.
- The caret row is emitted as its own string so it never depends on the OS
  print routine's wrapping behaviour.

### D6. Byte offset vs column

`COL` is 1-based (matching the existing `CasmSourceColumn` convention and
`diagDumpToken` output); `OFFSET` is the 0-based byte index into the line, i.e.
`COL - 1`. Both are printed because the two conventions are each what a
different tool expects. This is cheap and avoids an ambiguity bug report later.

## Memory Budget

`MAIN` is `$3400`-`$5BFF` (`$2800` = 10240 bytes) for CODE+RODATA+DATA+BSS
(`build/build_casm_cfg/casm_3400.cfg`). Current `casm_base.prg` is 7817 bytes
loaded, plus existing BSS on top. Estimated headroom before this work: ~1.9 KB.

This WP adds roughly:

- 256 bytes BSS (`CasmDiagLineBuf`)
- ~10 bytes BSS (`CasmDiagLoc*`, `CasmStmtLoc*`, capture flag)
- ~400 bytes CODE+RODATA (render, sanitize, window, drain, stamp helpers)

Total ~670 bytes against ~1.9 KB free. Comfortable, but **step 8 must confirm
the actual link result for both the `3400` and `3500` configs** — this is the
single most likely way this WP fails.

## Files to Create/Modify

| File | Action | Notes |
|------|--------|-------|
| `brain/plans/2026-07-20-casm-diagnostic-source-context.md` | Create | This document |
| `src/external/casm/common.inc` | Modify | `CASM_DIAG_LINE_BUF_SIZE`, window/caret constants, printable-range bounds, `CasmDiagLoc` field offsets |
| `src/external/casm/state.s` | Modify | `CasmDiagLineBuf` (256), `CasmDiagLineLen`, `CasmDiagCaptureOn`, `CasmDiagLocValid/LineLo/LineHi/Column/Byte`, `CasmStmtLocLineLo/Hi/Column`; update the three `.assert` size guards |
| `src/external/casm/source.s` | Modify | Echo capture in `sourceNextResult`; reset on newline; new exported `sourceDrainLineTail`; reset hooks in `sourceResetTraversal` |
| `src/external/casm/diagnostics.s` | Modify | `diagSetLocFromLookahead` / `diagSetLocFromToken` / `diagSetLocFromStmt` / `diagClearLoc` helpers; `diagPrintSourceContext`; `printHex8`; sanitize + window logic; extend `diagPrintFatal` |
| `src/external/casm/lexer.s` | Modify | Stamp location before raising $18, $19, $1A |
| `src/external/casm/parser.s` | Modify | Stamp `CasmStmtLoc` at statement start; stamp location before raising $1C, $1D, $1E |
| `src/external/casm/emit.s` | Modify | Stamp from `CasmStmtLoc` before raising $1E, $1F, $20, $21, $23 |
| `src/external/casm/resources.s` | Modify | Ensure `diagClearLoc` on the cleanup-failure path so a stale location cannot attach to an unrelated diagnostic |
| `wiki/casm-utility.md` | Modify | Document the new error format |
| `wiki/casm-programmers-reference.md` | Modify | Document the diagnostic context contract |

## Implementation Steps

Ordered so each step leaves the tree building and testable.

1. **Constants + state.** Add the `common.inc` constants and the `state.s` BSS
   fields. Update the `.assert` size guards. Build — no behaviour change.
2. **Location record + clear/stamp helpers.** Add `diagSetLocFrom*` and
   `diagClearLoc` in `diagnostics.s`. Nothing calls them yet.
3. **Echo capture.** Add capture to `sourceNextResult` and the newline reset.
   Verify byte-mode traversal is otherwise unchanged.
4. **Render without drain.** Implement `printHex8`, the sanitizer, the window
   calculation, the caret row, and `diagPrintSourceContext`. Wire it into
   `diagPrintFatal` behind `CasmDiagLocValid`.
5. **Lexer raise sites.** Stamp before $18/$19/$1A. **At this point the
   original bug is fixed** — everything after is completeness.
6. **Forward drain.** Add `sourceDrainLineTail` and call it from the render
   path. Text right of the caret now appears.
7. **Parser + emit raise sites.** Stamp `CasmStmtLoc`; cover $1C-$21, $23.
8. **Link check.** Confirm both `casm_3400.cfg` and `casm_3500.cfg` link within
   `$2800`. If tight, the first thing to cut is the drain (step 6), which is
   the largest optional piece.
9. **Docs.** Update the two wiki pages.

## Verification Plan

Fixture sources under the CASM test image, each asserted for exact expected
output:

| Fixture | Content | Expected |
|---------|---------|----------|
| `casmbadb` | `LDA #$0A@` on line 12 | $19, `LINE 12, COL 9 (OFFSET 8)`, caret under `@` |
| `casmctrl` | line containing a raw `$93` | `.` substitution, hex shown, **screen not cleared** |
| `casmlong` | error at column 96 of a 200-char line | window slides, `<..`/`..>` markers, caret aligned |
| `casmcol1` | error at column 1 | caret at position 0, no left clipping marker |
| `casmeol` | error at the final byte before EOF | drain terminates at EOF, no hang |
| `casmtail` | error mid-line with trailing text | full line shown including text right of caret |
| `casmclip` | error at column 7 of a 97-char line | right clip marker `.>`; **step 6 onward only** (see note) |
| `casmcrer` | `casmbadb`'s error in a CRLF file | geometry identical to `casmbadb`; no column drift |
| `casmsyn` | parser `SYNTAX ERROR` | location from the token record |
| `casmbranch` | out-of-range branch | location from `CasmStmtLoc` |
| `casmcli` | missing source file | bare message, **no** location, no drain attempted |

Right clipping is unreachable until the forward drain (step 6) exists: without
it the echo buffer always ends at the offending byte, so no buffered line can
have content to the right of the caret. `casmclip` therefore shows an
unclipped 7-character line at step 5 and only takes its final windowed form
once the drain lands. A right clip appearing before step 6 indicates a bug in
the window solver, not a passing test.

Manual checks:

- Column arithmetic against a CRLF file and an LF-only file — the pending-CR
  latch in `sourceNextResult` must not shift the reported column.
- A file whose error line straddles a 256-byte block boundary. This is the
  case the echo buffer exists to handle; confirm the line start survives the
  refill.
- Confirm `casm_3400.prg` and `casm_3500.prg` both link and still run.

Per project convention, VICE verification runs the real binary against the real
fixtures. Do not poke memory or registers to synthesize an error state — if a
fixture cannot reproduce a case, stop and raise it.

## Open Risks

- **Link budget** (step 8). Highest-probability failure. Mitigation: the drain
  is severable.
- **Drain safety.** `sourceDrainLineTail` deliberately bypasses the state gate.
  If it is ever called outside the fatal path it will corrupt traversal. The
  `CasmDiagLocValid` gate and the routine header contract are the only
  defences; both must be explicit.
- **Stale location.** A location stamped by one raise site and not cleared
  could attach to a later unrelated diagnostic. `diagClearLoc` on the cleanup
  path (step 7 / `resources.s`) addresses this; the `casmcli` fixture tests it.

## Progress

- 2026-07-20: Plan written. Codebase state verified against `source.s`,
  `lexer.s`, `diagnostics.s`, `parser.s`, `emit.s`, `resources.s`,
  `common.inc`, and `build/build_casm_cfg/casm_3400.cfg`. Not yet implemented.
- 2026-07-20: Steps 1-5 complete and verified in VICE against the WP15
  fixtures, the regression set, and the gating checks. The original
  INVALID SOURCE BYTE diagnostic now reports line, column, byte offset, the
  offending byte in hex, and a caret under the failing column.

  Deviations from the plan as written:
  - The offending byte's hex value prints on the location line
    (`AT LINE n, COL m (OFFSET k) BYTE $xx`) rather than appended to the
    message line. The message table stores each string with its trailing
    `PetCr` baked in and is documented as stable; appending to the message
    line would have required splitting every string or special-casing $19.
  - Added `CasmDiagLineNoLo/Hi` (not in the original design). The echo buffer
    holds one line at a time, so a diagnostic whose token started on an
    earlier line would have drawn a caret into unrelated text. The renderer
    now suppresses the line and caret when the buffered line number does not
    match the diagnostic's, printing the location line alone.
  - Diagnostic state lives outside the `CasmPhase3State` span rather than
    inside it, leaving the existing exact-size asserts untouched.
  - `sourceNextResult` needed three branch trampolines (`snbEofNear`,
    `snbBadStateNear`, `snbFailNear`) once the echo lengthened the byte-return
    path.

  Bug found in verification: the window body loop called `printChar` with the
  loop index in `A` instead of the sanitized character, printing PETSCII
  control codes and rendering the source line blank. Static review and
  hand-derived expectations did not catch this; only execution did.

  Size after step 5: 8462 bytes of the $2800 envelope, plus 269 bytes BSS.

  Remaining: steps 6-9. Note that `casmclip` cannot pass until step 6.
