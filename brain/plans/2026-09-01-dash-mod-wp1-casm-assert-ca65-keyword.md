---
feature: dash-mod-wp1-casm-assert-ca65-keyword
created: 2026-09-01
status: proposed
taskwarrior: TBD (created on approval)
depends-on: DASH Modernization parent plan (brain/plans/2026-09-01-dash-modernization.md), approved 2026-09-01
---

# Plan: DASH-MOD WP1 - CASM `.ASSERT` ca65-compatible action keyword

## Status

**Proposed, not yet approved.** First WP of the DASH Modernization
increment. Parent plan approved 2026-09-01. No implementation until this
sub-plan is approved.

Branch: continues on `feature/casm-phase14` (per the parent plan's
Scoping Decision 1 -- this CASM change rides with Phase 14 and is covered
by Phase 14 WP92's consolidated gate). Baseline: CASM `0.5.2` build
`1403` after Phase 14 WP91 (`ae2ea56`).

## Objective

CASM's `.ASSERT` (Phase 13 WP83) currently accepts only
`.ASSERT expr [, "message"]`. ca65's `.assert` **requires** an action
keyword: `.assert condition, action [, message]`, action one of
`warning` / `error` / `ldwarning` / `lderror`. The two spellings have no
overlap, so `.ASSERT` cannot be used in DASH's dual-assembler subset.

This WP extends CASM's `.ASSERT` grammar to also accept the ca65 form, so
one spelling assembles under both. It is **purely additive**:

- Every existing CASM `.ASSERT` spelling keeps working unchanged.
- The action keyword is parsed and then **ignored** -- CASM evaluates the
  assertion at pass time and is fatal on a false result, for all four
  keywords. CASM has no warning channel and no link phase; a DASH
  invariant worth stating is worth enforcing, and pass-time evaluation of
  `ldwarning`/`lderror` is stricter than ca65's link-time deferral, not
  weaker.
- No `emit.s` change, no new state, no CASM version bump (that happens at
  Phase 14 WP92), no behavior change observable to any existing source.

**Excluded:** honoring `warning`/`ldwarning` as non-fatal (CASM has no
mechanism and the parent plan settled this); a distinct diagnostic for a
failed `warning` assert; storing or acting on which keyword was used.

## Grammar

Current (kept):

```
.ASSERT expr
.ASSERT expr ',' STRING
```

Added:

```
.ASSERT expr ',' ACTION
.ASSERT expr ',' ACTION ',' STRING
```

where `ACTION` is an IDENTIFIER token whose text (case-folded, matching
ca65's case-insensitivity and CASM's existing `compareTokenText`
behavior) is one of: `ERROR`, `WARNING`, `LDERROR`, `LDWARNING`.

Disambiguation after the first `,` is by token type, no lookahead beyond
the one token `ppsAssert` already fetches:

- `STRING`  -> the message (existing CASM-legacy path, unchanged)
- `IDENTIFIER` matching an ACTION keyword -> consume it; if the next token
  is `,` then a `STRING` message must follow; else the terminator
- `IDENTIFIER` not matching, or anything else -> `CASM_DIAG_SYNTAX_ERROR`
  at that token (same diagnostic the grammar already raises for a
  non-STRING after the comma)

Note for downstream WP3: ca65 requires the action, so DASH will only ever
use `.ASSERT expr, ERROR[, "msg"]` -- the CASM-legacy no-action forms stay
for existing CASM-only fixtures but are not dual-assembler-safe.

## Technical design

### `ppsAssert` (parser.s)

The change is localized to the `@haveComma` branch (parser.s ~519-555).
Today it consumes `,`, requires a `STRING`, copies it, then requires the
terminator. New flow:

```
@haveComma:
    jsr lexerNext                 ; consume ',', fetch next token
    (propagate lexer failure)
    A = token type
    if STRING            -> @haveMessage           (unchanged legacy path)
    if not IDENTIFIER    -> @assertArgError
    ; IDENTIFIER: must be one of the 4 action keywords
    match CasmTokenText against the ACTION keyword table
    if no match          -> @assertArgError
    jsr lexerNext                 ; consume the ACTION keyword
    (propagate lexer failure)
    if token == ','      -> @actionThenMessage
    else                 -> @requireTerminator
@actionThenMessage:
    jsr lexerNext                 ; consume ',', fetch message token
    (propagate lexer failure)
    if token == STRING   -> @haveMessage
    else                 -> @assertArgError
@assertArgError:
    jsr diagSetLocFromToken
    lda #CASM_DIAG_SYNTAX_ERROR
    sec
    rts
```

`@haveMessage` and everything after (message-length check, copy,
null-terminate, `@requireTerminator`, `@terminatorOk`) is **unchanged** --
the action keyword never reaches `CasmAssert*` state, so `emitAssert`
(emit.s) sees exactly what it sees today.

### Keyword matching

`compareTokenText` (lexer.s ~1476) already does exactly the needed job:
X/Y = pointer to a null-terminated expected string, compares against
`CasmTokenText` + `CasmTokenRecord.LENGTH` with `normalizeChar`
case-folding, C clear on match. It is currently a lexer.s internal.

Plan: add `.export compareTokenText` in lexer.s and `.import` it in
parser.s (one-line change each, same pattern as every other cross-module
helper). A small RODATA table in parser.s holds the four
null-terminated keyword strings; `ppsAssert` walks it calling
`compareTokenText`. `compareTokenText` clobbers `CasmPtr0` and
`CasmLexerScratch0` -- `ppsAssert` holds nothing live in either across
this point (it has already stashed the expression result and staged
`CasmAssertValueLo/Hi`), confirmed against ppsAssert's own body.

Alternative if exporting `compareTokenText` proves entangled (it calls
`normalizeChar`, also a lexer internal -- but that is already linked into
every build): a 15-line local `ppsAssertMatchAction` in parser.s doing a
length-then-bytes compare over the four fixed strings. The plan's default
is the export; the local fallback is the stop-condition escape hatch.

## Atomic Increments

1. **Grammar + keyword match.** `.export compareTokenText` (lexer.s);
   `.import` + keyword table + `@haveComma` rework (parser.s). Build all
   CASM link configs + `image_d64` clean. Static check: every existing
   `.ASSERT` fixture source still parses (they use no action keyword, so
   they take the unchanged STRING/terminator path). `casm.prg` code-size
   delta noted; MAIN envelope headroom re-checked.
2. **Fixtures.** New `.seq` fixtures on `casm_phase13_test_d64` (the
   existing `.ASSERT` fixture home) or a small dedicated addition:
   - `casmassertkw1`: `.ASSERT 1, ERROR` -> accepted, no emission, clean.
   - `casmassertkw2`: `.ASSERT 1, ERROR, "OK MSG"` -> accepted.
   - `casmassertkw3`: `.ASSERT 0, ERROR, "BOOM"` -> `ASSERTION FAILED:
     BOOM` (proves the message still threads through with an action
     present).
   - `casmassertkw4`: `.ASSERT 1, WARNING` -> accepted (treated as ERROR).
   - `casmassertkw5`: `.ASSERT 1, LDERROR, "X"` -> accepted.
   - `casmassertkwbad`: `.ASSERT 1, BOGUS` -> `SYNTAX ERROR` at `BOGUS`.
   - `casmassertkwbad2`: `.ASSERT 1, ERROR, 5` (non-string message) ->
     `SYNTAX ERROR`.
   No `.ref` for any of these (assert emits no bytes; accepted cases are
   verified by `INPUT VALIDATED`, rejected by the diagnostic).
3. **Live VICE.** Dispatch each fixture from the Command64 shell; screen-
   decode the result. Fire `c64-overlay-api` test events (curl fallback).
4. **ca65 cross-check.** A throwaway ca65 `.assert 1, error, "x"` compile
   confirms ca65 accepts the exact spelling DASH will use -- so WP3's
   assertions are known-good on both sides before WP3 starts.

## Expected Files

| File | Action |
| --- | --- |
| `src/external/casm/lexer.s` | Modify -- `.export compareTokenText` |
| `src/external/casm/parser.s` | Modify -- `ppsAssert` grammar + keyword table |
| `src/external/casm/BUILD_CASM` | Auto-increment |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify -- new `casmassertkw*` fixtures |
| `CMakeLists.txt` | Modify -- pack fixtures onto their test disk |
| `brain/walkthroughs/2026-09-0X-dash-mod-wp1-casm-assert-ca65-keyword.md` | Create |
| `brain/plans/2026-09-01-dash-modernization.md` | Append Progress |
| `src/external/dash/AGENTS.md` | Modify -- update the WP91 `@local` bullet's neighbour: note `.ASSERT ... , ERROR[, "msg"]` is now dual-assembler-safe (full AGENTS.md rewrite is parent-plan WP6) |

## Stop Conditions

- Any existing `test_casm_*` assert harness/fixture changes result or a
  no-change rebuild alters an artifact.
- Exporting `compareTokenText` drags an unexpected dependency into a
  harness that stubs the lexer -> fall back to the local
  `ppsAssertMatchAction` (documented deviation, not a silent switch).
- ca65 rejects `.assert 1, error, "x"` (would break WP3's premise -
  stop and re-scope).
- CASM MAIN envelope ($7400) cannot absorb the grammar addition.
- A new defect outside this WP's scope -> disclose and defer.

## Documentation, Task, and Tracker Updates

- **At approval:** Taskwarrior WP1 task (child of `94ec17b3`);
  `wiki/tasks/dash-modernization.md` skeleton + WP1 row.
- **At completion:** this plan's Progress; `wiki/tasks/dash-modernization.md`
  ticked; the one-line `AGENTS.md` note above. `CHANGELOG.md` and the CASM
  version bump are deferred to Phase 14 WP92 (this change ships as part of
  that release).

## Completion Gate

- Increments 1-4 done.
- All pre-existing `.ASSERT` fixtures + harnesses green and byte-identical.
- Every new `casmassertkw*` fixture live-verified (accepted -> `INPUT
  VALIDATED`; rejected -> the exact diagnostic).
- ca65 confirmed to accept the DASH-target spelling.
- `image_d64` + all CASM link configs build clean; MAIN within `$7400`.
- Walkthrough with live evidence; trackers synced; explicit user approval.

## Progress

- 2026-09-01: Drafted for review.
