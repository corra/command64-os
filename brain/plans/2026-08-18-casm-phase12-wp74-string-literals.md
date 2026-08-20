---
feature: casm-phase12-wp74-string-literals
created: 2026-08-18
status: approved
taskwarrior: a61634af-b482-476b-a20b-5442334d1315
depends-on: WP71 (DASH adoption), complete; WP69 character literals, complete
---

# Plan: CASM Phase 12 WP74 String Literals

## Status

**Original plan and bounded envelope amendment approved 2026-08-18.** The user
approved the complete amended plan, including ca65-compatible `.BYTE` strings,
the Phase 13 `.TEXT` disposition gate, and mandatory DASH adoption. Taskwarrior
task 44 (`a61634af-b482-476b-a20b-5442334d1315`) is active; WP71 completed and
was user-approved on 2026-08-18. Atomic Increment 1 proved the original
no-envelope-growth assumption false; implementation remains paused pending
approval of the bounded amendment below. The amendment was subsequently
approved and Atomic Increment 2 may proceed.

Parent plan:
`brain/plans/2026-08-13-casm-phase12-constants-expanded-expressions.md`.
WP74 is inserted after WP71 and before Phase 12's renumbered consolidated
completion gate, WP75. WP72 and WP73 are already-consumed corrective WPs.

## Objective

Add bounded double-quoted string literals to native CASM as `.BYTE` list
entries. Each content byte is emitted verbatim as PETSCII, with no host
charmap conversion. Strings may be empty and may be mixed with numeric,
expression, and character-literal entries in the same comma-separated list.

This WP does not add string-valued symbols, string expressions, implicit
terminators, escape sequences, or strings in instruction operands, `.WORD`,
`.ORG`, named-constant definitions, or any directive other than `.BYTE`.

## Scoping Decisions (user-confirmed 2026-08-18)

1. **Syntax:** double-quoted literals, for example `.BYTE "hello", 0`.
2. **Encoding:** every content byte is emitted verbatim as PETSCII; CASM does
   no case folding, ASCII conversion, screen-code conversion, or ca65-style
   charmap remapping.
3. **Initial grammar:** strings are `.BYTE`-only, empty strings are valid, and
   there are no escape sequences. Quotes and control bytes must be represented
   as explicit numeric or character-literal operands where applicable.
4. **ca65 convention is canonical:** CASM follows ca65 by allowing string
   literals directly in `.BYTE`'s comma-separated list. Phase 13 must evaluate
   removing or replacing its tentative `.TEXT` directive rather than adding a
   redundant second spelling by default.
5. **Language features dogfood through DASH:** this and every future CASM
   language/feature addition triggers a scoped DASH rewrite. WP74 must identify
   byte-equivalent DASH data runs suitable for `.BYTE "..."`, rewrite them, and
   prove native CASM/ca65 identity. An unsafe encoding conversion is a stop
   condition, not permission to skip the DASH increment silently.

## Language Contract

Informal grammar extension:

```text
byte-list  := byte-item (',' byte-item)*
byte-item  := expression | character-literal | string-literal
string-literal := '"' printable-petscii* '"'
```

- Opening and closing delimiters are PETSCII double quote (`$22`).
- Content is restricted to the existing printable-PETSCII ranges used by
  `.INCLUDE` and character literals: `$20-$7E` and `$A0-$FE`, excluding `$22`
  because it closes the literal.
- `""` is one valid byte-list item and emits zero bytes.
- No byte is appended automatically. `.BYTE "ok", 0` emits `OK`'s exact source
  bytes followed by one explicit zero.
- A newline or EOF before a closing quote is `STRING UNTERMINATED`.
- A non-printable content byte is `STRING INVALID BYTE` at that byte.
- Adjacent strings without a comma are rejected by the existing byte-list
  delimiter rule; there is no implicit concatenation.
- A string token in any non-`.BYTE` context remains a syntax error.

## Token, Storage, and ABI Design

Add `CASM_TOKEN_STRING = $1A` and advance `CASM_TOKEN_COUNT` to `$1B`.
Add `CASM_PETSCII_QUOTE = $22` if no shared constant already owns that value.

The frozen 31-byte `CasmTokenText` payload must not grow. String scanning uses
new lexer-owned bounded BSS instead:

- `CasmStringLength`: one byte.
- `CasmStringBuffer`: 255 bytes, with no terminator requirement.

The existing physical source-line limit is 255 payload bytes, so no accepted
literal can exceed the buffer. The scanner still checks the bound explicitly;
line syntax and delimiters make the practical maximum smaller. This storage is
lexer-private base RAM, not zero page, VMM, `state.s`, `CasmIoBuffer`, or the
token record.

Atomic Increment 1 measured every target that links `lexer.s`. The amendment
preapproves the following upper bounds; implementation keeps each current
envelope unless an actual link failure proves a page increase is required, and
then uses only the smallest fitting page up to the listed ceiling:

| Target | Audited baseline | Current envelope | WP74 ceiling |
| --- | ---: | ---: | ---: |
| `casm` | `$61FB` | `$6200` | `$6500` |
| `test_casm_lexer` | `$0B48` | `$1000` | unchanged `$1000` |
| `test_casm_pass1` | `$59A6` | `$5A00` | `$5D00` |
| `test_casm_passcheck` | `$55EB` | `$5B00` | unchanged `$5B00` |
| `test_casm_include` | `$1369` | `$1400` | `$1600` |
| `test_casm_frame` | `$5955` | `$5A00` | `$5C00` |
| `test_casm_listcap` | `$5E09` | `$5F00` | `$6100` |

The ceilings cover the fixed 256-byte BSS addition plus bounded scanner,
diagnostic, emitter, and target-specific fixture growth. Exceeding any ceiling
is still a stop condition requiring another measured amendment.

On a successful scan, `CasmTokenRecord.TYPE` is STRING and LENGTH remains the
8-bit content length; `CasmTokenText` is not the content source for STRING.
Callers must read only `CasmStringBuffer[0..CasmStringLength-1]`. Existing token
consumers remain unchanged for every other token type.

## Lexer and Emitter Design

`lexerNext` routes `$22` to a dedicated `lnString` scanner:

1. Reset `CasmStringLength` and consume the opening quote.
2. Refill lookahead.
3. If the next byte is `$22`, consume it and emit an empty STRING token.
4. If newline/EOF appears first, raise `CASM_DIAG_STRING_UNTERMINATED`.
5. Validate printable PETSCII, append the raw byte to `CasmStringBuffer`, and
   continue until `$22` closes the literal.

`emitByteList` gains a STRING branch before expression parsing. It loops over
the buffer and calls `emitByte` once per content byte, preserving the existing
measure/emit split, PC overflow checks, listing capture, and output-failure
handling. It then advances once to the delimiter and rejoins the existing
comma/newline/EOF validation. Empty strings perform no `emitByte` call but are
still a syntactically present list item.

No parser or expression-evaluator integration is planned: `.BYTE` operands are
already deferred directly to `emitByteList`. `parser.s`, `expr.s`, `symbols.s`,
`opcodes.s`, and `reloc.s` should remain unchanged unless the implementation
audit proves an assumption wrong and the plan is amended and re-approved.

## Diagnostics

Atomic Increment 1 must confirm the live next-free diagnostic values. Expected
allocation after WP69's `$47/$48` character diagnostics:

| Expected code | Name | Trigger |
| --- | --- | --- |
| `$49` | `CASM_DIAG_STRING_UNTERMINATED` | Newline or EOF before closing `$22` |
| `$4A` | `CASM_DIAG_STRING_INVALID_BYTE` | Content outside printable PETSCII |

Both diagnostics use the offending lookahead location and receive stable
message-table entries. If either code is already occupied, stop and amend this
plan before implementation.

## Verification Design

Unit lexer coverage must include:

- Empty, one-byte, and multi-byte strings.
- Lowercase, uppercase, digits, spaces, and high printable PETSCII preserved
  byte-for-byte.
- Unterminated at newline and EOF.
- Invalid low control byte and `$7F`/`$FF` boundary rejection.
- Closing quote leaves comma/newline/EOF available to the emitter.

Production fixtures must prove through native CASM and COMP:

- `.BYTE "hello", 0` emits the literal's exact PETSCII bytes plus explicit NUL.
- Mixed list: numeric, empty string, character literal, string, expression.
- No implicit terminator and no implicit concatenation.
- Forbidden contexts (`LDA #"x"`, `.WORD "x"`, `name = "x"`) fail.
- Unterminated and invalid-byte diagnostics report exact locations.
- Identical source assembles deterministically on repeated runs.

Existing character-literal, include-filename, expression, listing, pass-check,
and output-boundary coverage must remain unchanged. A ca65 comparison may be
used only where raw source-byte mapping is explicitly controlled; the trusted
reference remains independently hand-derived to avoid importing ca65 charmap
semantics into CASM's verbatim-PETSCII contract.

### DASH adoption

Audit every explicit data/string run in DASH before selecting candidates.
DASH stores a mixture of screen codes, PETSCII, binary tables, and numeric
version text; only runs whose source bytes remain identical under both native
CASM's verbatim rule and ca65's active charmap may be rewritten. At least one
meaningful safe run must adopt `.BYTE "..."`; then:

- rebuild `dash_ref` and require no byte change from the pre-rewrite artifact;
- assemble the identical seven sources with native CASM and COMP against the
  ca65 reference;
- regenerate `dash.ref.hex` from the native run with true provenance and current
  source hashes, never `--allow-host-bytes`;
- live-check DASH at its documented relocation addresses under the owning DASH
  plan's verification contract.

If no non-gratuitous byte-identical candidate exists because DASH's strings are
screen codes or ca65 remaps the source characters, stop and ask the user whether
to add an explicit encoding facility, choose a different dogfooding target, or
amend the mandatory rewrite rule for this WP.

## Scope

**Included:**

- STRING token, quote constant, two diagnostics, bounded lexer storage/scanner.
- `.BYTE` emitter integration for zero or more literal bytes per string item.
- Lexer and production fixtures, native COMP verification, determinism check.
- User and programmer documentation for syntax, PETSCII behavior, limits, and
  explicit terminators.
- CASM stage-version bump after completion approval.

**Excluded:**

- Escape sequences, interpolation, concatenation operators, string functions,
  string-valued constants/symbols, implicit NUL or length prefixes.
- Strings in instructions, `.WORD`, `.ORG`, `.INCLUDE` semantics, or named
  constant definitions.
- Screen-code or ASCII conversion and ca65 charmap emulation.
- `.TEXT` implementation or aliasing. Phase 13 owns the explicit decision to
  remove/replace its tentative `.TEXT` entry now that `.BYTE` strings are the
  canonical ca65-compatible form.

## Atomic Increments

1. **Prerequisite and envelope audit.** Confirm WP71 completion, token and
   diagnostic next-free values, quote dispatch, source-line bounds, byte-list
   delimiter flow, affected link envelopes, and that planned untouched modules
   truly need no change. Stop on any disagreement.
2. **Token, storage, scanner, diagnostics.** Add constants, lexer BSS and
   `lnString`, diagnostics, and focused lexer cases. Build and live-run the
   lexer harness before emitter integration.
3. **`.BYTE` integration.** Add bounded STRING emission to `emitByteList`, with
   explicit zero-length handling and unchanged delimiter/error flow. Add narrow
   emitter/pass tests.
4. **Production fixtures.** Add hand-derived references and accepted/rejected
   fixtures to `casm_phase12_test.d64`; verify real native CASM output with COMP,
   exact diagnostics, repeated determinism, and normal shell returns using exact
   PETSCII input.
5. **DASH adoption.** Audit encoding classes, perform at least one meaningful
   byte-equivalent `.BYTE` string rewrite, rebuild `dash_ref`, assemble/COMP
   natively, regenerate native-provenance `dash.ref.hex`, and run DASH's required
   relocation checks. Stop for direction if no safe candidate exists.
6. **Full affected regression and documentation.** Rebuild all consumers of
   lexer/emit shared modules, inspect code/BSS/relocation sizes, build disk
   images, prove no-change stability, update docs and trackers, and prepare the
   completion-gate walkthrough for user approval.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/common.inc` | Add STRING token, quote constant, diagnostics, bounds |
| `src/external/casm/lexer.s` | Add bounded string storage and scanner |
| `src/external/casm/diagnostics.s` | Add two messages |
| `src/external/casm/emit.s` | Add `.BYTE` STRING emission path |
| `tests/src/casm_lexer/casm_lexer.s` | Add scanner cases |
| Relevant emitter/pass harnesses under `tests/src/` | Add `.BYTE` integration cases after Increment 1 audit |
| `cmake/GenerateCasmTestFixtures.cmake`, `CMakeLists.txt` | Generate/package native fixtures |
| `tests/fixtures/casm/*.ref.hex` | Add hand-derived references |
| `src/external/dash/*` | Adopt `.BYTE` strings in audited byte-equivalent data runs |
| `src/external/dash/dash.ref.hex` | Regenerate from native CASM after DASH rewrite |
| `docs/casm-utility.md`, `wiki/casm-utility.md` | Add byte-identical user documentation |
| `wiki/casm-programmers-reference.md` | Add token/storage/scanner/emitter/diagnostic contract |
| `src/external/casm/AGENTS.md` | Record durable string-literal contract after implementation |
| `brain/KNOWLEDGE.md`, `CHANGELOG.md`, `brain/task.md`, `wiki/tasks/casm.md` | Completion records |
| `brain/walkthroughs/2026-08-18-casm-phase12-wp74-string-literals.md` | Completion-gate evidence |

## Stop Conditions

- WP71 is not complete when implementation is ready to begin.
- Token `$1A`, diagnostics `$49/$4A`, source-line limits, or byte-list control
  flow differ from this plan's audited assumptions.
- The 256-byte BSS addition plus code/fixture growth exceeds any amended target
  ceiling above, or requires unplanned storage sharing, VMM allocation, or
  token-record growth.
- Empty strings disturb delimiter handling, PC, listing spans, or pass agreement.
- Any accepted fixture differs from its independently derived reference, or a
  forbidden context succeeds.
- Existing character/include/expression/relocation behavior changes.
- No meaningful DASH candidate is byte-identical under both assemblers, or the
  DASH native/ca65 outputs diverge after adoption.
- A no-change rebuild changes an artifact or build counter.
- A new defect outside this WP appears; disclose and defer unless the user
  explicitly approves an inline deviation and plan amendment.

## Documentation, Task, and DOX Updates

On plan approval, create and start a Phase 12 Taskwarrior child task depending
on WP71, and synchronize `brain/task.md`/`wiki/tasks/casm.md` as in-progress.
At completion, update the paired user manuals byte-identically, programmer
reference, CASM local DOX, `brain/KNOWLEDGE.md`, `CHANGELOG.md`, task trackers,
version, and matching walkthrough. WP75's consolidated Phase 12 completion
gate remains separate and cannot close from WP74's individual evidence alone.

## Completion Gate

WP74 completes only when all accepted/rejected grammar cases behave exactly as
specified; native output byte-matches independent references; empty/mixed/
boundary strings and diagnostics pass live; existing Phase 12 and shared-module
regressions remain clean; measured storage fits approved envelopes; no-change
builds are stable; DASH contains a meaningful byte-equivalent adoption and
passes native/ca65/relocation verification; Phase 13's `.TEXT` disposition is
recorded as pending its own plan; documentation and trackers are synchronized; live evidence
is recorded in the matching walkthrough; and the user explicitly approves
closing WP74. Phase 12 remains open for WP75's consolidated verification.

## Progress

- 2026-08-18: User directed that string literals receive a dedicated plan and
  properly belong to Phase 12. User confirmed double-quoted syntax, verbatim
  PETSCII encoding, and `.BYTE`-only initial scope with empty strings and no
  escapes. Drafted this proposed WP74 plan and the corresponding proposed
  parent-plan sequencing amendment. No implementation or task activation has
  begun; awaiting explicit plan approval.
- 2026-08-18: User selected ca65 convention as canonical: strings belong in
  `.BYTE` lists. Amended WP74 to require a real DASH rewrite for this and every
  future language feature, and amended the Phase 13 master-plan entry so
  `.TEXT` must be removed, replaced, or separately justified there rather than
  automatically duplicating `.BYTE` strings. Still proposed; no implementation.
- 2026-08-18: User approved the amended WP74 plan. Created and started
  Taskwarrior task 44 (`a61634af-b482-476b-a20b-5442334d1315`) with dependency
  on WP71. WP74 is approved but blocked; no implementation begins until WP71
  closes.
- 2026-08-18: User approved WP71 complete. WP74 is unblocked and may begin its
  approved Atomic Increment 1 in the next implementation increment.
- 2026-08-18: Atomic Increment 1 read-only audit confirmed WP71 completion,
  `CASM_TOKEN_STRING = $1A` availability, diagnostic `$49/$4A` availability,
  the existing shared `$22` quote constant, the 255-byte source-line payload
  bound, and `emitByteList`'s direct CHAR-before-expression/delimiter flow.
  `parser.s`, `expr.s`, `symbols.s`, `opcodes.s`, and `reloc.s` need no planned
  STRING integration. DASH's `DASHVERSTR` numeric/version suffix is a meaningful
  candidate for a dual-assembler-safe string because it uses only digits and
  punctuation, avoiding ca65's known C64 letter remapping; byte identity still
  requires build proof during Increment 5.
- 2026-08-18: The measured envelope gate failed. Existing linked objects and
  base PRGs show production CASM uses `$61FB` of its `$6200` MAIN envelope
  (5 bytes free), `test_casm_lexer` uses `$0B48` of `$1000` (1,208 bytes free),
  and `test_casm_pass1` uses `$59A6` of `$5A00` (90 bytes free). The planned
  256-byte lexer BSS addition alone would overflow production CASM by 251 bytes
  and `test_casm_pass1` by 166 bytes, before scanner, diagnostics, or fixture
  code. Per the approved stop condition, no implementation began; an envelope
  increase or revised storage design requires explicit user direction.
- 2026-08-18: User authorized drafting explicit envelope amendments. The
  comprehensive lexer-consumer measurement then exposed a pre-existing failure
  before WP74 changes: `test_casm_include` cannot link in its current `$1300`
  envelope, with ld65 reporting BSS overflow by 105 bytes. The preceding
  `test_casm_passcheck` baseline build succeeded, but the chained build stopped
  at `test_casm_include`; `test_casm_frame` and `test_casm_listcap` were not
  built. Per the new-defect stop condition, further audit/build work and the
  envelope amendment stopped pending explicit user direction to defer this
  defect or fix its envelope inline under WP74.
- 2026-08-18: User explicitly approved fixing the pre-existing
  `test_casm_include` envelope defect inline. Raised its MAIN envelope from
  `$1300` to `$1400`, the smallest round-page step above the measured 105-byte
  overflow, and resumed Atomic Increment 1's affected-consumer audit.
- 2026-08-18: `test_casm_include` then linked successfully at `$1400`, and
  `test_casm_frame` built successfully at its existing envelope. The resumed
  baseline audit exposed a second pre-existing stale envelope:
  `test_casm_listcap` overflows its current `$5E00` MAIN area by 9 bytes before
  WP74 changes. Per the same new-defect stop condition, work stopped pending
  explicit user direction for this separate inline correction.
- 2026-08-18: User explicitly approved correcting the second pre-existing
  defect inline. Raised `test_casm_listcap` from `$5E00` to `$5F00`, the
  smallest round-page step above its measured 9-byte baseline overflow, and
  resumed the affected-consumer audit.
- 2026-08-18: The complete lexer-consumer baseline measured `casm=$61FB/6200`,
  `test_casm_lexer=$0B48/1000`, `test_casm_pass1=$59A6/5A00`,
  `test_casm_passcheck=$55EB/5B00`, `test_casm_include=$1369/1400`,
  `test_casm_frame=$5955/5A00`, and `test_casm_listcap=$5E09/5F00`. Drafted a
  bounded envelope amendment with ceilings of `$6400`, `$5C00`, `$1600`,
  `$5C00`, and `$6100` respectively for the five targets that may need growth;
  the lexer and pass-check harnesses retain their current caps. Implementation
  remains paused pending explicit approval of this amendment.
- 2026-08-18: User approved the bounded envelope amendment. Before Atomic
  Increment 2 edits, the required token-consumer audit exposed another
  pre-existing defect: `diagDumpToken` accepts every type below
  `CASM_TOKEN_COUNT` (`$1A`) but `tokNamesLo`/`tokNamesHi` contain entries only
  through `CASM_TOKEN_EQUALS` (`$10`). Dumping STAR through CHAR (`$11-$19`)
  therefore indexes beyond both tables. STRING cannot safely extend this
  already-invalid consumer. No scanner/token implementation began; per the
  new-defect stop condition, work paused for explicit fix-or-defer direction.
- 2026-08-18: User approved fixing the token-name table inline. Added the
  missing STAR-through-CHAR names together with STRING, then implemented the
  STRING token/constants, 255-byte lexer-owned buffer plus length, bounded raw
  PETSCII scanner, two diagnostics, and focused lexer cases. The narrow
  `test_casm_lexer` target links within its unchanged `$1000` envelope.
  Building the production disk then measured CASM overflowing `$6200` by 529
  bytes: the approved `$6400` ceiling would still be 17 bytes short, making
  `$6500` the smallest page-aligned fit. Per the amended envelope stop
  condition, no production-envelope change or VICE run occurred; work paused
  for explicit approval of a `$6500` CASM ceiling.
- 2026-08-18: User approved the measured CASM ceiling amendment to `$6500`.
  Updated the production envelope to that smallest fitting round-page size and
  resumed Increment 2 build and live verification.
- 2026-08-18: Atomic Increment 2 completed. Added STRING `$1A`, the 255-byte
  lexer-owned buffer plus length, raw-printable-PETSCII scanning with empty
  strings, `$49/$4A` diagnostics, and complete token-dump names through STRING.
  The focused lexer harness covers empty and multi-byte strings, raw `$7E/$A0/
  $FE` preservation, EOF/newline unterminated failures, and `$7F/$FF` invalid
  boundaries. `casm_phase12_test_d64` built successfully; measured production
  use is `$6411/$6500` (239 bytes free) and lexer-harness use is `$0DCD/$1000`
  (563 bytes free). Under VICE 3.10, Command64 booted from the rebuilt image,
  the first row proved `Command 64-DOS Version`, exact PETSCII launched
  `TEST_CASM_LEXER`, the harness displayed `CASM LEXER: PASS`, and the shell
  prompt returned as `c64[8]:>`. VICE was left running. Increment 3 is next.
- 2026-08-18: Increment 3 added direct STRING iteration to `emitByteList`,
  preserving `emitByte` and the existing delimiter tail, plus a generated
  `p1string1.s` measure fixture mixing empty STRING, numeric, character,
  non-empty STRING, and expression entries. Production CASM still links within
  `$6500`. Shared Increment 2/3 growth first overflowed the pass harness's old
  `$5A00` envelope by 480 bytes, so it was raised to its approved `$5C00`
  ceiling. Adding the actual mixed-list fixture then overflowed `$5C00` by 21
  bytes; `$5D00` is the smallest page-aligned fit. Per the ceiling stop
  condition, no further envelope change or live pass-harness run occurred
  pending explicit approval.
- 2026-08-18: User approved the measured `test_casm_pass1` ceiling amendment
  to `$5D00`; updated the target to that smallest fitting page and resumed
  Increment 3 verification.
- 2026-08-18: Atomic Increment 3 completed. `emitByteList` now iterates STRING
  bytes through the existing `emitByte` path, handles zero-length strings
  without a byte call, advances once to the delimiter, and rejoins the existing
  comma/newline/EOF tail. Added `p1string1.s`, which mixes empty STRING,
  numeric, character, non-empty STRING, and expression items and proves a
  four-byte PC advance in measure mode. The generic `test_image_d64` attempt
  hit its documented full directory track, so the expanded pass harness and
  complete eight-file fixture set were moved to canonical
  `casm_phase12_test.d64`; the first live run with only the new fixture was a
  setup failure (seven old fixtures absent, seven `F`s, new case passed), not a
  product failure. After packaging all fixtures and reattaching the rebuilt
  disk, VICE 3.10 showed eight dots, `CASM PASS1: PASS`, and normal return to
  `c64[8]:>`. The disk retains 313 free blocks. Measured use is production
  `$6435/$6500` (203 bytes free) and pass harness `$5C15/$5D00` (235 bytes
  free). `git diff --check` passes; VICE remains running. Increment 4 is next.
- 2026-08-18: Atomic Increment 4 completed. Added fixed-origin
  `casmstring1.s` and an independently hand-derived 12-byte reference proving
  verbatim `HELLO`, explicit NUL, numeric, empty STRING, character, one-byte
  STRING, and expression output with no implicit terminator. Added rejected
  immediate, `.WORD`, equate, adjacent-STRING, unterminated, and raw-control
  fixtures. On rebuilt `casm_phase12_test.d64` under VICE 3.10, native CASM
  assembled `casmstring1.s` twice; COMP reported `FILES COMPARE OK` against
  the trusted reference and between both native outputs. Rejected results were:
  immediate `SYNTAX ERROR` line 1 column 6 offset 5; `.WORD` `MALFORMED
  EXPRESSION` column 7 offset 6; equate `MALFORMED EXPRESSION` column 8 offset
  7; adjacent STRING `SYNTAX ERROR` column 11 offset 10; unterminated `STRING
  UNTERMINATED` column 11 offset 10 byte `$00`; invalid control `STRING INVALID
  BYTE` column 8 offset 7 byte `$01`. Every command returned to `c64[8]:>`.
  The image retains 305 free blocks, above its 40-block floor. VICE remains
  running. Increment 5 is next.
- 2026-08-18: Atomic Increment 5 completed. Rewrote DASH's visible version
  suffix from explicit `$30,$2E,$31,$2E,$34` bytes to meaningful
  `.BYTE "0.1.4"`, the audited digits/punctuation subset that is identical
  under native CASM's verbatim rule and ca65's active C64 charmap. The ca65
  `dash_ref.prg` SHA-256 remained exactly
  `3238b7863cc9b7ba7b07202c94dccb8dcbd1fd0fe4c578362f311b79757b814b`.
  Native CASM 0.2.7 build 1321 assembled the identical include-chain source;
  COMP reported `FILES COMPARE OK` for all 4,766 bytes. Extracted native output
  and ca65 reference had the same hash. Regenerated `dash.ref.hex` from native
  bytes with current seven-source hashes and `--cross-check`, without
  `--allow-host-bytes`; rebuilt shipping `dash.prg` retained that same hash.
  Live DASH rendered its `DASH V0.1.4` banner at `$3800`; explicit relocation
  runs showed `DASH.PRG 5000-5EF3` and `DASH.PRG 9000-9EF3` on the Applications
  page. `image_d64` built with DASH at 19 blocks and 315 free blocks. DASH
  exited normally to `c64[9]:>` and VICE remains running. Increment 6 is next.
- 2026-08-18: Increment 6 affected-target linking raised only preapproved
  envelopes: `test_casm_include` `$1400->$1500` (223-byte overflow),
  `test_casm_frame` `$5A00->$5C00` (399-byte overflow; `$5B00` insufficient),
  and `test_casm_listcap` `$5F00->$6100` (323-byte overflow; `$6000`
  insufficient). `test_casm_bounds` required one-byte unreachable-path
  stand-ins for emit.s's new token-text/string imports and then linked at its
  unchanged envelope. User and programmer documentation and CASM DOX were
  updated. Full disk regression then found an unplanned diagnostics consumer:
  `test_casm_faultsource` overflows its `$2D00` envelope by 39 bytes because it
  whole-links the expanded `diagnostics.s`. It had no approved WP74 ceiling;
  work paused before changing it, completing later disk builds, or preparing
  closeout, pending explicit approval of `$2E00`, the smallest page fit.
- 2026-08-18: User approved the measured `test_casm_faultsource` envelope
  correction to `$2E00`; applied that smallest fitting page and resumed full
  regression.
- 2026-08-18: `test_casm_faultsource` then linked successfully at `$2E00`.
  Rebuilding `casm_overflow_test_d64` exposed a capacity failure: harness
  growth leaves 22 blocks before appending the 23-block `casmbig1.ref`, so the
  image is at least one block short. The smallest fixture-free resident is
  `test_casm_fsym` (11 blocks); moving it to `casm_listing_test_d64` follows
  this CMake section's existing `test_l15release`/`test_casm_faultvmm`/
  `test_casm_freloc` relocation precedent without deleting coverage. This is
  an unplanned disk-layout change, so work paused pending explicit approval.
- 2026-08-18: User approved moving fixture-free `test_casm_fsym` (11 blocks)
  from `casm_overflow_test_d64` to `casm_listing_test_d64`. The overflow image
  then built successfully with 4 blocks free and all fixtures retained. The
  listing-image rebuild exposed another unplanned diagnostics consumer:
  `test_casm_spanread` overflows its `$3000` envelope by 89 bytes after WP74's
  diagnostic growth. Work paused pending explicit approval of `$3100`, the
  smallest page-aligned fit.
- 2026-08-19: User approved `test_casm_spanread` `$3000` -> `$3100`.
- 2026-08-19: `test_casm_spanread` links successfully at `$3100`. The approved
  `test_casm_fsym` listing-image destination proved non-viable under a complete
  image build: it consumed the remaining fixture capacity, leaving 0 blocks
  before existing frame fixtures were appended. Work paused for approval to
  move fixture-free `test_casm_fsym` to `casm_include_test_d64`, whose existing
  disk-layout contract records 208 free blocks.
- 2026-08-19: User approved moving `test_casm_fsym` to
  `casm_include_test_d64` instead of the capacity-constrained listing image.
- 2026-08-19: Overflow, include, listing, and shipping images plus their
  immediate no-change rebuild passed. Final free blocks are 4, 156, 1, and
  315 respectively; `git diff --check` passed. VICE 3.10 booted the rebuilt
  include image, proved Command64 `0.4.1.2663`, and exact PETSCII launched
  `test_casm_fsym`, which reported `CASM FAULT SYMBOLS: PASS` and returned to
  `c64[8]:>`. Prepared the completion walkthrough; WP74 remains in progress
  pending explicit user sign-off.
- 2026-08-19: User explicitly approved the completion walkthrough. WP74 is
  complete; CASM advanced from `0.2.7` to `0.2.8`. Phase 12 remains open for
  WP75 consolidated verification.
