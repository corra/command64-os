---
feature: casm-phase9-wp44-quoted-include-operand-grammar
created: 2026-07-25
status: complete
---

# Plan: CASM Phase 9 WP44 - Quoted Include Operand Grammar

## Objective

Implement and verify the bounded `.INCLUDE "filename"` operand grammar without
opening, cataloging, or traversing an included file. A valid include statement
will parse completely and then terminate through `casmRunPass` with
`CASM_DIAG_NOT_IMPLEMENTED` until WP45 supplies the first semantic consumer.

Parent plan: `brain/plans/2026-07-25-casm-phase9-include-processing.md`.

Taskwarrior: `2682d04b-05b0-4828-b88f-852234e3d006` (approved and active).

## Prerequisites and Baseline

- WP43 is user-approved and complete at CASM `0.1.45` build 1160.
- `.INCLUDE` already lexes as `CASM_TOKEN_DIRECTIVE` with subtype
  `CASM_DIRECTIVE_INCLUDE`.
- Directive scanning stops before horizontal whitespace, newline, or EOF and
  leaves that source result in the one-byte lexer lookahead.
- The stable token record carries only 31 payload bytes and must not grow.
- `parserParseStatement` currently sends all directives except `.BYTE` and
  `.WORD` through numeric operand grammar.
- `casmRunPass` currently sends every parsed directive to `emitDirective`,
  where `.INCLUDE` shares the generic not-implemented arm with `.STATIC` and
  `.RELOC`.
- Diagnostics are contiguous through `$30`; MAIN had 153 bytes free in the
  WP43 `$3700` baseline. The first increment measured a 16-byte overflow after
  adding the 65-byte operand state and three diagnostic messages/table entries.
  The user approved a reviewed `$3700` -> `$3A00` amendment before scanner work.

## Inherited Decisions

- Syntax is exactly `.INCLUDE "filename"`, case-insensitive only for the
  directive name. Filename bytes retain their original spelling.
- Payload length is 1 through 63 bytes. There is no escape syntax.
- Accepted payload bytes are raw printable PETSCII `$20-$7E` and `$A0-$FE`,
  except quote `$22`. Controls `$00-$1F` and `$7F-$9F`, null, CR, LF, and `$FF`
  are invalid.
- Space and tab may appear before the opening quote and after the closing quote.
  A semicolon comment may follow the closing quote. Any other trailing byte is
  a syntax error.
- Reserve `$31` `CASM_DIAG_INCLUDE_FILENAME_EXPECTED`, `$32`
  `CASM_DIAG_INVALID_INCLUDE_FILENAME`, and `$33`
  `CASM_DIAG_INCLUDE_FILENAME_TOO_LONG`.
- An unterminated quoted operand reports `$32` at the opening quote.
- Valid syntax reports `CASM_DIAG_NOT_IMPLEMENTED` at the `.INCLUDE` statement
  until WP45 replaces that temporary semantic boundary.
- A dedicated embedded-script `test_casm_include` harness is packaged on
  `casm_overflow_test_d64`.

## Grammar and Diagnostic Mapping

| Input after `.INCLUDE` | Result | Diagnostic location |
| --- | --- | --- |
| only space/tab then newline or EOF | `$31` filename expected | newline/EOF lookahead location |
| first non-space/tab byte is not quote | `$31` filename expected | unexpected byte |
| `""` | `$32` invalid filename | opening quote |
| invalid payload byte | `$32` invalid filename | offending byte |
| newline or EOF before closing quote | `$32` invalid filename | opening quote |
| 64th payload byte before a closing quote | `$33` filename too long | 64th byte |
| valid close then non-space/tab/non-comment byte | existing `$1D` expected newline | trailing byte |
| valid close then space/tab, comment, newline, or EOF | parse success | statement location remains `.INCLUDE` |

The opening quote location is copied into bounded parser-owned state before it
is consumed. No diagnostic path may infer it from the live source cursor after
scanning has advanced.

## Scanner and Parser ABI

### `lexerScanIncludeOperand`

Add one public lexer routine called only immediately after
`parserParseStatement` has consumed a `CASM_DIRECTIVE_INCLUDE` token.

- Input: lexer READY; lookahead is either already valid or fillable and points
  at the first result after the directive token.
- Success: copy 1-63 original PETSCII payload bytes to `CasmIncludeFilename`,
  append null, store `CasmIncludeFilenameLen`, leave newline/EOF buffered and
  unconsumed, return `A = CASM_DIAG_NONE`, carry clear.
- Failure: set lexer ERROR, set the prescribed diagnostic location, return its
  `CASM_DIAG_*` value in A with carry set; buffer contents are invalid.
- Clobbers: A, X, Y, flags, `CasmLexerScratch0/1`, lookahead, source volatile
  state, and include operand state.
- Preserves: balanced stack, decimal/interrupt mode, token record contents,
  resources, pass/emitter state, and all persistent source state except normal
  forward consumption.

The scanner reuses `lexerFill`/`lexerConsume` internally so lookahead provenance
remains authoritative. It performs these phases in order:

1. Skip only space and tab.
2. Require and remember an opening quote.
3. Copy printable non-quote bytes with a pre-write 63-byte bound check.
4. Require a closing quote and reject an empty payload.
5. Skip trailing space and tab.
6. If a semicolon follows, consume comment bytes up to but not including
   newline/EOF; otherwise require newline/EOF.

### Parser Ownership

- Add `CasmIncludeFilename` (64 bytes including null) and
  `CasmIncludeFilenameLen` (1 byte) as parser-owned BSS in `parser.s` rather
  than enlarging `CasmTokenRecord`, `CasmParserStmt`, or `state.s`'s frozen
  Phase 3 spans.
- Export both fields for WP45 and the standalone harness.
- In `ppsMnemonic`, branch on `CASM_DIRECTIVE_INCLUDE` before numeric operand
  parsing, call `lexerScanIncludeOperand`, set `CASM_OPKIND_IMPLIED`, and return
  the populated directive statement.
- Do not add a string token type or expose private lexer fill/consume helpers.

### Dispatch Ownership

- In `casmRunPass`, detect a parsed include before `emitDirective`, call
  `diagSetLocFromStmt`, and return `CASM_DIAG_NOT_IMPLEMENTED` with carry set.
- Remove `.INCLUDE` from `emitDirective`'s generic ownership comment and make
  an unexpected include reaching that routine an internal routing failure, not
  the supported path. `.STATIC` and `.RELOC` remain unchanged.
- WP44 performs no `emitMarkStarted`, PC change, output write, source rewind,
  file operation, VMM operation, or include traversal.

## Constants and Storage Effects

- Add explicit `CASM_PETSCII_QUOTE = $22`, printable-range constants, and
  `CASM_INCLUDE_FILENAME_MAX = 63` /
  `CASM_INCLUDE_FILENAME_BUFFER_SIZE = 64` to `common.inc` with compile-time
  assertions.
- Add diagnostics `$31-$33`, set `CASM_DIAG_PHASE9_WP44_LAST = $33`, extend
  both diagnostic pointer tables and their completeness assertions, and add
  stable messages.
- Base-RAM growth is exactly 65 BSS bytes for the parser-owned operand state;
  no zero-page, token-record, parser-statement, file-registry, VMM-registry, or
  VMM allocation growth is authorized.
- Code/RODATA growth must fit the amended `$3A00` MAIN envelope or trigger the
  stop condition below; do not silently enlarge MAIN again.

## Scope

Included:

- dedicated quoted scanner and parser path;
- bounded operand storage and exports;
- diagnostics `$31-$33` and messages;
- temporary valid-include dispatch failure;
- dedicated embedded test harness and disk-image wiring;
- task, plan, walkthrough, knowledge, changelog, and DOX synchronization.

Excluded:

- device-prefix interpretation or canonicalization;
- child file open/read/close, source append, catalog, or metadata VMM storage;
- frame stack, nesting, cycle detection, event recording, or Pass 2 replay;
- included-file provenance, traceback, or diagnostic filename lookup;
- any operational `.INCLUDE` behavior.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/common.inc` | grammar constants and diagnostics `$31-$33` |
| `src/external/casm/lexer.s` | `lexerScanIncludeOperand` |
| `src/external/casm/parser.s` | operand BSS, include parser branch, exports |
| `src/external/casm/casm.s` | temporary include semantic boundary |
| `src/external/casm/emit.s` | remove include from generic emitter ownership |
| `src/external/casm/diagnostics.s` | messages and table bounds |
| `tests/src/casm_include/casm_include.s` | embedded-script grammar harness |
| `CMakeLists.txt` | target and `casm_overflow_test_d64` packaging |
| `wiki/tasks/casm.md`, `brain/task.md` | synchronized task state |
| `brain/KNOWLEDGE.md`, `CHANGELOG.md` | durable verified result at closeout |
| `brain/walkthroughs/2026-07-25-casm-phase9-wp44-quoted-include-operand-grammar.md` | evidence and manual steps |
| `src/external/casm/AGENTS.md` | only if implementation changes a durable local contract |

## Harness Design and Test Matrix

`test_casm_include` embeds source cases in its PRG and links the real source,
lexer, parser, and diagnostic-location state needed to exercise the public ABI.
It does not depend on filesystem fixtures or implement WP45 behavior. Package
it on `casm_overflow_test_d64`, not the directory-full `test.d64`.

Required cases:

- one-byte and 63-byte payload success with exact length, bytes, and null;
- 64-byte payload -> `$33` at byte 64;
- empty payload, unterminated-at-newline, and unterminated-at-EOF -> `$32`,
  with both unterminated cases pointing at the opening quote;
- every accepted range boundary: `$20`, `$21`, `$23`, `$7E`, `$A0`, `$FE`;
- rejected boundaries `$00`, `$1F`, `$7F`, `$80`, `$9F`, and `$FF`, with
  invalid-byte location checks; an early quote closes the payload, so following
  bytes are tested as invalid trailing source rather than as payload;
- missing operand and unquoted operand -> `$31`;
- leading/trailing space and tab, trailing semicolon comment, and EOF directly
  after the closing quote succeed;
- unexpected trailing source -> existing `$1D` at that byte;
- directive name remains case-insensitive while filename bytes remain exact;
- parser statement subtype/opkind and exported buffer are correct;
- production `casmRunPass` valid syntax reaches `$0A` at statement location;
- malformed syntax never reaches emitter, changes PC/output, or acquires a
  resource;
- existing lexer/parser/emit harnesses remain unchanged and pass.

## Atomic Increments

1. After explicit approval, mark WP44 active in Taskwarrior,
   `wiki/tasks/casm.md`, and `brain/task.md`; do not activate WP45.
2. Add constants, 65-byte parser-owned state, and diagnostics with compile-time
   layout/table assertions.
3. Implement `lexerScanIncludeOperand` and its exact diagnostic provenance.
4. Add the parser include branch and temporary `casmRunPass` semantic boundary;
   remove generic emitter ownership.
5. Add and build `test_casm_include`; package it only on
   `casm_overflow_test_d64`.
6. Run static, narrow, regression, image, artifact, and no-change-build checks;
   create the walkthrough and present runtime instructions to the user.
7. After user runtime verification and explicit completion approval only,
   increment CASM from `0.1.45` to `0.1.46`, rebuild, synchronize closeout
   records, and complete WP44. Do not activate WP45 automatically.

## Failure and Cleanup

- Scanner failures acquire no resources and return directly through existing
  central fatal cleanup.
- The scanner latches lexer ERROR on every grammar failure so callers cannot
  continue from a partially consumed quoted operand.
- Buffer length is committed only after successful close/trailer validation;
  a failure leaves the buffer semantically invalid.
- `casmRunPass` stamps the valid-but-unimplemented diagnostic before returning;
  cleanup preserves that primary failure.
- No new cleanup branch, file handle, or VMM ownership exists in WP44.

## Verification

- `git diff --check` and all relevant ca65 compile-time assertions pass.
- `test_casm_include` passes its complete embedded matrix in the supported local
  emulator or hardware, as performed by the user.
- Existing standalone lexer, parser, expression, symbol, relocation, and CASM
  regression targets build without behavior changes.
- Two consecutive `cmake --build build --target casm` builds hold the same
  `BUILD_CASM` value after the first content-driven increment.
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` build clean.
- Inspect `build/casm.prg` load address, byte size, and R6 footer/relocation
  count; compare MAIN use against the WP43 baseline.
- Confirm no source file is opened by `.INCLUDE`, Pass 2 behavior is unchanged,
  and WP45 remains pending/unstarted.
- Do not use the broken `c64-testing` MCP or a web emulator.

## Documentation, Task, and DOX Updates

- Keep Taskwarrior, `wiki/tasks/casm.md`, and `brain/task.md` synchronized at
  activation, verification, and closeout.
- Record stable implementation findings in `brain/KNOWLEDGE.md`, user-visible
  change in `CHANGELOG.md`, and evidence/manual confirmation in the walkthrough.
- Re-read the root, `src`, `src/external`, `src/external/casm`, `wiki`, and
  `wiki/tasks` DOX chain before implementation and perform a closeout DOX pass.
- Update `src/external/casm/AGENTS.md` only if implementation establishes or
  changes a durable local contract. Planning alone does not require a DOX edit.

## Stop Conditions

Stop, amend this plan, and request renewed approval if:

- quote scanning cannot preserve the current token record and lookahead ABI;
- correct parsing requires a second source buffer, zero-page growth, or more
  than the approved 65 BSS bytes;
- a valid include cannot be intercepted before emitter/output side effects;
- grammar requires filesystem access or any WP45 behavior;
- diagnostic provenance cannot distinguish opening quote, offending byte, and
  trailing byte as specified;
- `test_casm_include` cannot exercise the real scanner/parser ABI without
  duplicating production logic;
- code/RODATA no longer fits MAIN's approved `$3A00` envelope, or artifact/R6
  structure changes unexpectedly;
- any existing parser, emitter, two-pass, or relocation behavior regresses.

## Completion Gate

WP44 is complete only after its plan is explicitly approved, implementation and
the full verification matrix pass, the user performs the runtime walkthrough,
the user explicitly approves completion, CASM advances to `0.1.46` with a stable
no-change build, and all durable records agree. Completion does not activate
WP45.

## Progress

- 2026-07-25: User approved and activated WP44.
- 2026-07-25: Atomic increment 2 added grammar constants, diagnostics `$31-$33`,
  and exactly 65 bytes of parser-owned operand state. The first link measured a
  16-byte `$3700` MAIN overflow. Implementation stopped without a workaround;
  the user approved amending MAIN to `$3A00` (+768 bytes) before work resumed.
- 2026-07-25: The amended link passes at build 1161 and a no-change rebuild
  holds 1161. `build/casm.prg` is 15,349 bytes, loads at `$3400`, and retains an
  R6 footer (`00 34 7c 06 52 36`, 1660 relocation entries).
- 2026-07-25: Atomic increment 3 implemented `lexerScanIncludeOperand` and a
  position-only lookahead diagnostic helper. The first assembly exposed seven
  6502 relative-branch range errors; local inverse-branch/absolute-jump
  trampolines resolved them without changing behavior. The successful build
  advanced to 1163 (1162 was the failed assembly attempt), and a no-change
  rebuild held 1163. The 15,744-byte artifact loads at `$3400` and ends with R6
  footer `00 34 b4 06 52 36` (1716 entries). Parser/pass dispatch is not wired.
- 2026-07-25: Atomic increment 4 wired the scanner into the dedicated parser
  path and intercepted valid includes in `casmRunPass` before emitter effects.
  `emitDirective` now treats an include reaching it as an internal routing
  failure. One pre-existing parser failure branch crossed the 6502 relative
  range after growth and was converted to a local trampoline. Build 1165 passes
  and is stable (1164 was the failed branch-range assembly); the 15,800-byte
  artifact loads at `$3400` and ends with R6 footer
  `00 34 ba 06 52 36` (1722 entries). No include file I/O exists yet.
- 2026-07-25: Atomic increment 5 added the embedded, length-bounded
  `test_casm_include` harness with 14 grammar cases and real lexer/parser/state
  objects. Two initial harness-only assembly failures exposed unsupported label
  `.sizeof` inference and non-zero-page indirect pointers; explicit script
  lengths and existing CASM private zero-page pointer aliases resolved them.
  Build 1002 passes and is stable (1001 was the failed pointer assembly); its
  4,420-byte PRG loads at `$3400` and has R6 footer
  `00 34 ef 01 52 36` (495 entries). `casm_overflow_test_d64` builds with the
  harness stored under the 16-character disk name `test_casm_includ`. Runtime
  execution remains user-gated.
- 2026-07-25: The first user run produced `.fffffffffffff`. RCA found the
  harness retained its case-table and expected-data pointers in `CasmPtr0/1`,
  which the real directive classifier is documented to clobber. Case 1 passed,
  then the corrupted table cursor made every later case fail. Persistent
  addresses now live in harness BSS and are copied to zero page only around
  immediate indirect accesses. Harness build 1003 and its no-change rebuild
  pass; `casm_overflow_test_d64` was regenerated for user re-test.
- 2026-07-25: User re-test passed all 14 cases. Consolidated verification then
  found `test_casm_pass1`'s legacy `$3700` whole-object envelope overflowed by
  161 bytes after inheriting WP44 state/code; `test_casm_passcheck` uses the
  same source set. The user approved matching both harnesses to production's
  reviewed `$3A00` envelope before verification resumed.
- 2026-07-25: Both whole-object harnesses and all three disk images pass after
  the approved envelope change. CASM remains stable at `0.1.45` build 1165;
  artifact size/load/footer are 15,800 bytes, `$3400`, and
  `00 34 ba 06 52 36`. Walkthrough records the user's passing 14-case runtime.
  Awaiting explicit completion approval before the version-only increment.
- 2026-07-25: User approved completion. CASM advanced once to `0.1.46` build
  1166, a no-change build held 1166, and all three disk images passed again.
  The final artifact remains 15,800 bytes with load address `$3400` and R6
  footer `00 34 ba 06 52 36` (1722 entries). WP44 closed; WP45 remains pending
  separate planning approval and activation.
