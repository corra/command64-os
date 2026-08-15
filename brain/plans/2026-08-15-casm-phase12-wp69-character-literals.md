---
feature: casm-phase12-wp69-character-literals
created: 2026-08-15
status: approved
taskwarrior: fe24c370-a520-450d-b281-f56eab2fd7ce
depends-on: WP64 (contract freeze), complete
---

# Plan: CASM Phase 12 WP69 — Character Literals and Documented String Encoding

## Status

**Approved 2026-08-15.** The user approved this plan as drafted,
including both confirmed Scoping Decisions. Implementation of the Atomic
Steps below is authorized. Taskwarrior task 44
(`fe24c370-a520-450d-b281-f56eab2fd7ce`) created, depends on WP64.

Parent plan:
`brain/plans/2026-08-13-casm-phase12-constants-expanded-expressions.md`.
Prerequisite: WP64 (contract freeze), complete and user-approved
2026-08-13. WP69 is listed as independent of the WP64→WP67→WP68→WP70→
WP71→WP72 dependency spine — "placed late here only because it's
lower-risk and doesn't block or get blocked by anything else, not
because it's lower priority" (parent plan). WP68 (arithmetic/bitwise
operators), the last spine WP before WP69, is complete and user-approved
2026-08-15.

## Objective

Add a character-literal token (`'a'`-style) that evaluates to the single
PETSCII byte between the quotes, usable exactly where an 8-bit value is
already expected — an immediate operand (`LDA #'A'`) and `.BYTE` operand
list entries (`.BYTE 'H', 'I'`) — matching WP64's own scope note that it
"only fixes the encoding rule and token," leaving the exact grammar to
this WP. WP64 already reserved `'` as the character-literal delimiter in
its token inventory (`brain/plans/2026-08-13-casm-phase12-wp64-contract-
freeze.md` line 91) but never added it to `common.inc`/`lexer.s` —
confirmed live: no `CASM_PETSCII_APOSTROPHE`/`CASM_TOKEN_CHAR` exists
anywhere in the source today, so a bare `'` currently trips
`CASM_DIAG_INVALID_SOURCE_BYTE`.

## Scoping Decisions (user-confirmed 2026-08-15)

1. **No backslash escape sequences.** `'a'` is exactly one literal byte
   between quotes — no `\n`/`\'`/`\\` or any other escape convention.
   Matches CASM's existing minimal-grammar philosophy (no escape
   convention exists anywhere else in the language) and keeps this
   "lower-risk, independent" WP genuinely low-risk. A literal `'`
   character as content still works mechanically without any special
   escape (see Technical Design — `'''` lexes as the quote byte itself,
   no special-casing needed) since exactly one content byte is always
   consumed regardless of its value.
2. **Restricted to 8-bit contexts, not a general expression primary.**
   A character literal is valid **only** as a whole immediate operand
   (`LDA #'A'`) or a whole `.BYTE` list entry (`.BYTE 'A', 'B'`) — never
   combined with an operator (`'A'+1` is a syntax error), never inside
   `.WORD`, never as a bare (non-immediate) instruction operand
   (`LDA 'A'` is a syntax error, not "load from PETSCII-code-of-A"), and
   never on a named constant's RHS. This is a deliberate, real
   restriction other primaries don't have (WP66's `*` and WP68's new
   operators are full expression-grammar citizens; character literals
   are not) — chosen for implementation simplicity: `CASM_TOKEN_CHAR`
   never reaches `exprEvaluate`/`parsePrimary` at all, so `expr.s` needs
   **no change**, and the relocation-representability machinery
   (`checkStaticReloc` etc.) is entirely unaffected since a character
   literal is unconditionally static.

## Technical Design

### Token and lexer (`common.inc`, `lexer.s`)

New token `CASM_TOKEN_CHAR = $19` (`CASM_TOKEN_COUNT` → `$1A`). New
constant `CASM_PETSCII_APOSTROPHE = $27`.

`lexerNext`'s dispatch (`lexer.s:150-186`, alongside the existing `$`/`%`
lead-byte special cases) gets one more check: lead byte `'` routes to a
new `lnChar` scan, structured like `lnHex`/`lnBin`'s own dedicated scans,
not the generic `lexerClassifyPunct` single-byte table (character
literals are inherently multi-byte, like a number literal):

1. Consume the opening `'`.
2. Read exactly one byte as content, **no case folding, no charmap
   reinterpretation** — the raw PETSCII byte the source contains is the
   literal's value, consistent with how CASM already treats identifier
   bytes verbatim ([[reference-casm-petscii-identifier-case]]). Reject a
   content byte outside the existing printable-PETSCII range
   (`CASM_INCLUDE_PRINT_LO_MIN`/`MAX`, `CASM_INCLUDE_PRINT_HI_MIN`/`MAX`
   — the same bounds `.INCLUDE` filenames already enforce, reused rather
   than duplicated) with `CASM_DIAG_CHAR_INVALID_BYTE`.
3. Read the next byte and require it to be a closing `'`; anything else
   (including EOF/newline) is `CASM_DIAG_CHAR_UNTERMINATED`.

This mechanical one-content-byte-then-require-closing-quote rule needs no
special-casing for a literal quote as content: `'''` (three apostrophes)
consumes the first `'` as the opener, the second `'` as the one content
byte (itself in the printable range — passes), and the third `'` as the
closer — correctly lexing as the quote character's own PETSCII value. A
truly empty literal `''` consumes the first `'` as opener, the second `'`
as content (same mechanism), and then finds no third `'` immediately
following — reported as `CASM_DIAG_CHAR_UNTERMINATED`, not a separate
"empty literal" diagnostic (deliberately not special-cased, per Scoping
Decision 1's minimalism).

The literal's value (one byte, 0-255) is stored in the existing
`CasmTokenText`/`Length=1` fields — no new `CasmTokenRecord` field needed;
callers read `CasmTokenText[0]` directly.

Both new diagnostics get source-location context via
`diagSetLocFromLookahead` (matching `CASM_DIAG_INVALID_SOURCE_BYTE`'s own
raise site, since these fire mid-lexer-scan, not from the parser/emitter).

### Diagnostic numbering (`common.inc`)

Next free codes after WP67's `CASM_DIAG_EXPR_PAREN_TOO_DEEP = $46`
(confirmed live — no Phase 12 code has claimed `$47`+ yet):

| Code | Name | Trigger |
|---|---|---|
| `$47` | `CASM_DIAG_CHAR_UNTERMINATED` | No closing `'` immediately after the one content byte (includes the empty-literal case) |
| `$48` | `CASM_DIAG_CHAR_INVALID_BYTE` | Content byte outside the existing printable-PETSCII range |

### Parser and emitter (`parser.s`, `emit.s`)

- **`posImmediate`**: its token whitelist (already touched by WP67's `(`
  fix and WP68's `-`/`~`/`*` fix) gains `CASM_TOKEN_CHAR`. When the
  current token is `CASM_TOKEN_CHAR`, the immediate operand's resolved
  value is `CasmTokenText[0]` directly — `exprEvaluate` is never called
  for this case. The outer `parseOperandSequence` dispatcher does **not**
  gain `CASM_TOKEN_CHAR` (Scoping Decision 2 — no bare/absolute-operand
  use).
- **`.BYTE` list parsing** (`emit.s`, wherever it iterates comma-separated
  operands calling the expression evaluator per item): gains an
  equivalent per-item check — `CASM_TOKEN_CHAR` short-circuits straight
  to `CasmTokenText[0]` as that entry's byte, bypassing `exprEvaluate`
  the same way.
- **`.WORD` list parsing**: deliberately **not** touched (Scoping
  Decision 2 — no `.WORD 'A'`).
- **Named-constant RHS** (`ppsConstant`): deliberately **not** touched —
  already a separate, narrower hand-rolled grammar (WP65/66/67's own
  precedent); `CASM_TOKEN_CHAR` is simply not one of the tokens it
  recognizes, so `NAME = 'A'` naturally falls through to its existing
  `CASM_DIAG_SYNTAX_ERROR`-equivalent path with no code change required
  — confirmed by reading `ppsConstant`'s grammar before assuming this.

## Scope

**Included:**

- New token, two new diagnostics, lexer scan routine (above).
- `posImmediate` and `.BYTE` list parsing updated to accept
  `CASM_TOKEN_CHAR` as a direct 8-bit value source.
- `tests/src/casm_lexer/casm_lexer.s` cases: a valid character literal,
  an unterminated one, an invalid-byte one, and the `'''`/`''`
  mechanical-consequence cases above.
- Production `.seq`/`.ref.hex` fixture(s) on an appropriate disk image,
  live-verified against the real `casm.prg`: at least one success case
  (`LDA #'A'`, `.BYTE 'H','I'`) and the two forbidden-form cases
  (unterminated, invalid byte).
- Documentation: `docs/casm-utility.md`/`wiki/casm-utility.md` (kept
  byte-identical) gain a character-literal section with lowercase
  examples per
  [[reference-c64-lowercase-petscii-convention]]/[[reference-casm-petscii-identifier-case]];
  `wiki/casm-programmers-reference.md` gains the new token, lexer scan,
  and diagnostic-table rows; `brain/KNOWLEDGE.md` gains a WP69 as-built
  section; `CHANGELOG.md` entry; CASM stage-version bump per the existing
  per-WP policy.

**Excluded:**

- Any backslash escape sequence (Scoping Decision 1).
- Use as a general expression primary — arithmetic combination, `.WORD`,
  bare/absolute instruction operands, named-constant RHS (Scoping
  Decision 2).
- Any change to `expr.s` (no primary-dispatch or relocation-classifier
  change needed — confirmed by design, not just asserted).
- WP70's own relocation-algebra-closure consolidated verification sweep
  (separate WP, runs after WP69 lands).

## Atomic Steps

1. **Audit before implementing.** Confirm live: `CASM_TOKEN_COUNT`'s
   current value, the next free diagnostic code, `ppsConstant`'s exact
   token whitelist (to confirm `CASM_TOKEN_CHAR` naturally falls through
   without a code change), and `posImmediate`'s/`.BYTE`'s exact current
   dispatch structure (to confirm the short-circuit shape above fits
   cleanly). Stop and report if any assumption above is wrong.
2. **Token, lexer, diagnostics.** Add `CASM_TOKEN_CHAR`,
   `CASM_PETSCII_APOSTROPHE`, `CASM_DIAG_CHAR_UNTERMINATED`/
   `INVALID_BYTE`, the `lnChar` scan, and their message-table entries.
   Add/expand `tests/src/casm_lexer/casm_lexer.s` cases; verify narrow
   build and live VICE pass before touching the parser/emitter.
3. **`posImmediate` and `.BYTE` integration.** Wire the short-circuit
   value path in both call sites; verify against WP66/67/68's own
   `SYNTAX ERROR`-before-integration lesson — test the *real* production
   pipeline (`casm.prg`), not just a synthetic harness, before declaring
   this done.
4. **Production fixtures and live verification.** Add and package the
   success/forbidden-form fixtures; live-verify all cases against the
   real `casm.prg` under VICE; re-run every harness whose linked shared
   modules changed (`test_casm_lexer` at minimum; `test_casm_expr` only
   if any shared file it links was touched — confirm before assuming).
5. **Documentation and close-out.** Docs, `KNOWLEDGE.md`, `CHANGELOG.md`,
   version bump, walkthrough, tracker sync — same closing pattern WP68
   used.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/common.inc` | Add token, PETSCII constant, two diagnostics |
| `src/external/casm/lexer.s` | Add `lnChar` scan and dispatch |
| `src/external/casm/diagnostics.s` | Add two message-table entries |
| `src/external/casm/parser.s` | `posImmediate` short-circuit for `CASM_TOKEN_CHAR` |
| `src/external/casm/emit.s` | `.BYTE` list short-circuit for `CASM_TOKEN_CHAR` |
| `tests/src/casm_lexer/casm_lexer.s` | New character-literal cases |
| `tests/fixtures/casm/*`, `cmake/GenerateCasmTestFixtures.cmake`, `CMakeLists.txt` | New production fixtures, disk packaging |
| `docs/casm-utility.md`, `wiki/casm-utility.md` | New character-literal section (byte-identical) |
| `wiki/casm-programmers-reference.md` | Token/lexer/diagnostic-table updates |
| `brain/KNOWLEDGE.md`, `CHANGELOG.md`, `brain/task.md`, `wiki/tasks/casm.md` | As-built/completion entries |

`src/external/casm/expr.s`/`symbols.s`/`reloc.s` are **not** expected to
change (Scoping Decision 2). An unexpected need to touch any of them
requires stopping and reporting before proceeding.

## Stop Conditions

- Atomic Step 1's audit finds any assumption above wrong (token/
  diagnostic numbering, `ppsConstant`'s fallthrough, the dispatch
  shape) — stop and report before implementing against a false premise.
- A forbidden-form fixture fails to raise the correct diagnostic, or
  raises it at the wrong location.
- A success fixture's real assembled output does not byte-exact-match
  its hand-derived `.ref.hex`.
- Any approved test/production envelope cap is exceeded — report
  measured usage and request direction rather than silently raising a
  cap.
- A no-change rebuild changes any artifact or build counter.
- A genuinely new defect outside this plan's scope is discovered —
  disclose and defer unless the user explicitly approves an inline fix.

## Documentation, Task, and DOX Updates

- Create/activate a Taskwarrior task for WP69 under Phase 12, depending
  on WP64, once this plan is approved.
- At completion: `brain/KNOWLEDGE.md` as-built section, `docs`/`wiki`
  `casm-utility.md` (byte-identical) character-literal section,
  `wiki/casm-programmers-reference.md` token/lexer/diagnostic updates,
  `CHANGELOG.md` entry, CASM stage-version bump, `brain/walkthroughs/`
  completion-gate doc, `brain/task.md`/`wiki/tasks/casm.md` sync —
  matching WP68's own closing pattern exactly.

## Completion Gate

WP69 completes only when: the lexer correctly accepts/rejects every
designed case (valid literal, unterminated, invalid byte, the `'''`/`''`
mechanical cases); `posImmediate`/`.BYTE` both accept a character literal
and produce byte-exact correct output via COMP against a hand-derived
reference; the excluded contexts (`.WORD`, bare operand, operator
combination, named-constant RHS) all correctly fail rather than silently
succeed; `expr.s` is confirmed unchanged; full affected-target build and
envelope inspection pass; no-change rebuild is stable; live VICE evidence
is recorded in a walkthrough; documentation/version/tracker sync is
complete; and the user explicitly approves closing WP69.

## Progress

- 2026-08-15: Drafted this plan after WP68's closure and commit
  (`048baeb`), confirming both Scoping Decisions with the user (no
  escapes; restricted to immediate/`.BYTE` contexts only, not a general
  expression primary — deliberately simpler than WP66/68's own primaries,
  bypassing `expr.s` entirely). Live-confirmed no `CASM_PETSCII_
  APOSTROPHE`/`CASM_TOKEN_CHAR` exists in source today despite WP64
  reserving the token conceptually. User approved as drafted; Taskwarrior
  task 44 created.
- 2026-08-15: **Atomic Step 1 (audit) complete.** Confirmed live:
  `CASM_TOKEN_COUNT = $19` (next free `$1A`), next free diagnostic `$47`,
  `ppsConstant`'s `@primary` dispatch only recognizes NUMBER/IDENTIFIER/
  STAR (falls through to `CASM_DIAG_EXPR_MALFORMED` for anything else,
  no code change needed), and `posImmediate`/`emitByteList`'s exact
  dispatch shapes confirmed the planned short-circuit fits cleanly. No
  correction needed to any design assumption.
- 2026-08-15: **Atomic Step 2 (token, lexer, diagnostics) complete.**
  Added `CASM_TOKEN_CHAR`, `CASM_PETSCII_APOSTROPHE`,
  `CASM_DIAG_CHAR_UNTERMINATED`/`INVALID_BYTE` ($47/$48), the `lnChar`
  scan, and their message-table entries. Found and fixed a real 6502
  branch-range overflow (`lnAngle`'s two `beq` sites fell out of range
  once `lnChar`'s dispatch was added nearby) with an `lnAngleJmp`
  trampoline, matching `lnHexJmp`/`lnBinJmp`'s own precedent. Added four
  new `tests/src/casm_lexer/casm_lexer.s` cases. `test_casm_lexer` builds
  clean within its then-current `$1000` cap.
- 2026-08-15: **Atomic Step 3 (posImmediate/.BYTE integration)
  complete.** Wired `posImmediateChar` (parser.s) and `emitByteList`'s
  own short-circuit (emit.s), both reading `CasmTokenText[0]` directly,
  bypassing `exprEvaluate` entirely. `casm` initially overflowed its
  then-current `$6100` cap by 235 measured bytes with the full feature
  in place; user-approved `$6100` -> `$6200`. Three test harnesses
  (`test_casm_pass1`/`frame`/`listcap`) also overflowed their own caps
  (150/69/249 bytes) from the same shared-module growth; user-approved
  the same round-page bump for each. `test_casm_passcheck` absorbed the
  growth without needing a change.
- 2026-08-15: **Atomic Step 4 (production fixtures, live verification)
  complete.** Added `casmchar1.s` (success, COMP-verified),
  `casmcharbare.s`/`casmcharunterm.s`/`casmcharinval.s` (forbidden
  forms) to `casm_phase12_test_d64`. Found and fixed a cc1541
  16-character filename truncation (`casmcharinvalid.s` -> 17 chars,
  silently lost its `.s` suffix on first build) before any live testing,
  renamed to `casmcharinval.s`. Full affected-target/disk rebuild and a
  no-change rebuild proof (SHA-256 identical) both passed. Live VICE
  3.10: `casmchar1.s` -> `CASM: INPUT VALIDATED`, `comp` -> `FILES
  COMPARE OK`; `casmcharbare.s` -> `CASM: SYNTAX ERROR` at the bare-
  operand position; `casmcharunterm.s`/`casmcharinval.s` -> the exact
  `CASM_DIAG_CHAR_UNTERMINATED`/`CHAR_INVALID_BYTE` messages and
  locations (the unterminated case's `BYTE $00` suffix revealed a stale
  doc claim, corrected during Step 5). `test_casm_lexer` (4 new cases)
  and `test_casm_expr` (unaffected, confirming `expr.s` truly untouched)
  both re-ran clean after a VICE MCP keyboard-queue quirk (same as prior
  WPs) resolved by `flush\n`.
- 2026-08-15: **Atomic Step 5 (documentation and close-out) complete.**
  `brain/KNOWLEDGE.md` as-built section; new "Character Literals" section
  in `docs`/`wiki` `casm-utility.md` (byte-identical); `wiki/casm-
  programmers-reference.md` extended (token/scanning tables, a note on
  the `posImmediate`/`.BYTE` short-circuit and why `ppsConstant`/
  `emitWordList` are untouched, the `$47`/`$48` diagnostic rows, and the
  `BYTE`-suffix correction); `CHANGELOG.md` entry; CASM promoted
  `0.2.3` -> `0.2.4`, live-verified as `V0.2.4.1311` with `casm.prg`
  unchanged in size and every other artifact byte-identical in a
  no-change rebuild. Walkthrough with consolidated evidence:
  `brain/walkthroughs/2026-08-15-casm-phase12-wp69-character-
  literals.md`.

  All five Atomic Steps complete. This WP's Completion Gate is
  satisfied: every designed lexer case (valid, unterminated, invalid
  byte, `'''`/`''` mechanical cases) behaves correctly; `posImmediate`/
  `.BYTE` both produce byte-exact correct output via COMP; every
  excluded context correctly fails; `expr.s` confirmed unchanged; full
  affected-target build/envelope inspection and no-change rebuild both
  pass; live VICE evidence recorded in the walkthrough; documentation/
  version/tracker sync complete. One watch item disclosed, not a Stop
  Condition: `casm_listing_test_d64` is down to 7 free blocks from this
  WP's shared-module growth. Awaiting the user's explicit approval to
  close WP69.
