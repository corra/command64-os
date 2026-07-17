---
feature: casm-native-assembler
phase: 3
created: 2026-07-16
status: approved
depends-on: casm-phase-2-cli-file-services
prerequisite-gate: casm-phase-0c1-source-lexer-contract
---

# CASM Phase 3 Implementation Plan: Source Stream and Minimal Lexer

Approved by the user on 2026-07-16. This plan incorporates the phase-dependency
audit and requires a read-only feasibility investigation of reuse from DEBUG's
interactive assembler before CASM mnemonic classification is implemented.

## Objective

Extend the completed Phase 2 native input foundation with a rewindable,
file-aware source abstraction and a bounded minimal lexer. One source file must
be streamed through the existing managed 256-byte input buffer, normalized into
logical lines, rewound deterministically, tokenized with one-based source
locations, and exposed through a temporary token-dump verification path.

Phase 3 does not parse statements, validate addressing modes, evaluate numeric
values or expressions, define symbols, run assembly passes, or create output.

## Dependency Audit and Corrections

The following corrections govern this plan and must be synchronized into the
master and Phase 2 plans during the documentation increment:

1. Phase 4, not Phase 5, is the first production consumer of output
   create/write/close/delete, short-write handling, and `outputAbort`.
2. Phase 4 must include an explicit bounded statement parser between the lexer
   and numeric code generation. Its corrected name is **Statement Parser,
   Opcode Table, and Numeric Static Assembly**.
3. VMM storage must precede VMM-backed symbols. Phase 6 is divided into Phase
   6A, bounded VMM storage foundation, and Phase 6B, VMM symbol table and
   two-pass assembly. Public later-phase numbers remain stable.
4. Phase 0C is divided into dependency-specific gates so Phase 3 is not blocked
   by unrelated later contracts:
   - Phase 0C.1: source stream, location, newline, token grammar, and bounds;
   - Phase 0C.2: statement, numeric conversion, opcode, addressing, and static
     output contracts;
   - Phase 0C.3: expression result and relocation classification;
   - Phase 0C.4: VMM record, symbol record, hashing, capacity, and pass replay;
   - Phase 0C.5: R6 emission-event and serialization contracts.

Corrected critical path:

```text
Phase 2 managed input
  -> Phase 0C.1 source/lexer contract
  -> Phase 3 source stream and lexer
  -> Phase 0C.2 numeric/parser/output contract
  -> Phase 4 statement parser and numeric static assembly
  -> Phase 0C.3 expression contract
  -> Phase 5 expression evaluator
  -> Phase 0C.4 VMM/symbol/pass contract
  -> Phase 6A VMM storage foundation
  -> Phase 6B symbols and two-pass assembly
  -> Phase 7 VMM source and multiple top-level inputs
  -> Phase 0C.5 relocation/emission contract
  -> Phase 8 R6 relocation
  -> Phase 9 includes
  -> Phase 10 map and listing
  -> Phase 11 hardening
```

## Phase 0C.1 Contract

These approved values are prerequisites for Phase 3 source implementation.

### Source Stream

- Phase 3 accepts one top-level source file.
- Physical source size is bounded to 65,535 bytes by the existing checked
  16-bit input count.
- `sourceOpen` opens `CasmSourceName` through the managed Phase 2 file wrapper.
- `sourceNextByte` consumes the existing 256-byte `CasmIoBuffer`; Phase 3 does
  not allocate a second input-block buffer.
- `sourceRewind` closes and reopens the file, then resets byte, newline,
  location, lookahead, and line-window state.
- A rewind close or reopen failure is fatal and follows normal central
  resource ownership rules.
- An openable empty file returns EOF at line 1, column 1.
- Initial source identity is file ID zero plus `CasmSourceName`; record formats
  reserve later expansion for includes and multiple top-level files.
- Physical offsets and line numbers are checked 16-bit values.
- Lines and columns are one-based; columns are checked 8-bit values.
- Every offset, line, column, cursor, and length increment is checked before
  commit.

### Newline Normalization

- CR (`$0D`) produces one internal newline.
- LF (`$0A`) produces one internal newline.
- CRLF produces one internal newline, including when split across input blocks.
- Consecutive CR bytes or consecutive LF bytes represent consecutive empty
  lines.
- A final CR is resolved as a newline before EOF.
- The lexer receives one normalized newline result and never interprets raw CR
  or LF.
- Location advances to the next line only after the normalized newline is
  consumed.

### Line Window

- Maximum logical line payload is 255 bytes, excluding an optional terminator.
- The byte-stream lexer is the primary consumer. `sourceNextLine` is a bounded
  convenience API for fixtures and diagnostics, not the lexer's backing store.
- Phase 3 must not introduce a second 256-byte buffer. If `sourceNextLine`
  reuses `CasmIoBuffer`, transfer-block and line-window ownership must be
  explicit and mutually exclusive.
- Embedded null bytes are invalid source bytes, not EOF.
- A line exceeding 255 payload bytes fails before storing the overflowing byte.
- Byte and line APIs cannot be mixed without an explicit rewind/reset.

### Identifier and Token Text

- Identifier first byte: `A-Z`, `a-z`, or `_`.
- Identifier continuation: the first-byte set plus `0-9`.
- Label spelling remains case-sensitive.
- Mnemonic, directive, and register classification is case-insensitive without
  modifying stored token spelling.
- Maximum identifier/token-text payload is 31 bytes plus a null terminator.
- Overlong tokens fail; they are never silently truncated.
- A period starts a directive token and is not part of an ordinary identifier.
- A global-label colon is returned as punctuation for the Phase 4 parser.

### Numeric Lexical Forms

Phase 3 validates lexical shape but does not convert values:

- decimal: one or more decimal digits;
- hexadecimal: `$` followed by one or more hexadecimal digits;
- binary: `%` followed by one or more binary digits;
- bare `$` or `%` is malformed;
- invalid suffixes such as `$12G` and `%102` fail instead of being silently
  divided into unrelated tokens; and
- conversion, 16-bit overflow, and expression semantics begin in Phase 4 or
  Phase 5 as assigned by the corrected dependency chain.

### Token Record

Each returned token has bounded persistent state:

- token type;
- token subtype;
- token length;
- source file ID;
- 16-bit starting line;
- one-byte starting column; and
- original token text, bounded to 31 bytes plus terminator.

Initial token types are:

```text
EOF
newline
identifier
mnemonic
directive
register
number
comma
colon
hash
left parenthesis
right parenthesis
plus
minus
less-than
greater-than
```

Spaces and tabs are skipped. A semicolon comment is consumed through its
normalized newline, but the newline token is still returned so statement
boundaries remain deterministic.

Phase 3 recognizes all 56 documented 6502 mnemonics, the registers `A`, `X`,
and `Y`, and `.org`, `.byte`, `.word`, `.include`, `.static`, and `.reloc`.
Unknown dot-prefixed names return a directive token with an unknown subtype so
Phase 4 can issue a directive-specific diagnostic.

## DEBUG Assembler Reuse Feasibility Investigation

The investigation is mandatory before implementing CASM mnemonic
classification. It is read-only during Phase 3 unless a separate approved
increment authorizes changes to DEBUG or shared build inputs.

### Existing DEBUG Work to Inspect

- `parseMnemonic`
- `parseOperand`
- `parseHexWithDollar`
- `isBranchMnemonic`
- `calcRelOffset`
- `lookupOpcode`
- `writeInstruction`
- `opStringTable`
- `opMnemonicIndex`
- `opAddrMode`
- `modeLength`

### Feasibility Classification

| DEBUG component | Earliest CASM phase | Expected reuse |
|---|---:|---|
| 56-entry mnemonic list | 3 | High as reviewed table data |
| Mnemonic indexing scheme | 3/4 | High with stable ordering |
| Opcode-to-mnemonic table | 4 | High after exhaustive validation |
| Opcode-to-addressing-mode table | 4 | High after exhaustive validation |
| Addressing-mode length table | 4 | High after validation |
| `lookupOpcode` algorithm | 4 | Medium; redesign around CASM ABI |
| Operand syntax handled by `parseOperand` | 4 | Medium as grammar reference |
| Relative-offset arithmetic | 4/6 | Medium after flag/range audit |
| `parseMnemonic` routine | 3 | Low for direct reuse |
| `parseHexWithDollar` routine | 4 | Low for direct reuse |
| `writeInstruction` routine | 4 | Low for direct reuse |

### Investigation Tasks

1. Inventory DEBUG assembler and disassembler tables and their shared ordering.
2. Verify that the mnemonic table contains exactly the 56 documented 6502
   mnemonics with no duplicates or omissions.
3. Verify all 256 `opMnemonicIndex` and `opAddrMode` entries.
4. Verify `modeLength` for every addressing mode.
5. Compare DEBUG operand forms with the approved future CASM grammar.
6. Identify DEBUG-owned zero-page, BSS, input-buffer, direct-memory-write, and
   diagnostic dependencies.
7. Identify ca65 character-literal/PETSCII assumptions that cannot be copied.
8. Measure three implementation options:
   - validated CASM-local table data;
   - a neutral shared declarative include consumed independently by both apps;
   - one build-integrated canonical table source that produces both forms.
9. Reject any option that couples CASM runtime to DEBUG, requires a one-off
   host script, changes DEBUG without regression verification, consumes
   excessive CASM RAM/code, or makes Phase 3 depend on Phase 4 encoding.
10. Record the decision before implementing mnemonic classification.

The default recommendation is to reuse DEBUG's mnemonic ordering as reviewed
reference data and create a compact CASM-local mnemonic table in Phase 3.
Opcode/address-mode consolidation remains a Phase 4 decision.

Direct routine reuse is not presumed safe because DEBUG consumes a
null-terminated interactive RAM line, owns incompatible scratch state, uses
different diagnostics, selects zero-page width from current numeric values,
writes directly to memory, and has no file provenance, deterministic replay,
symbols, emission events, or output lifecycle.

## Scope

### Included

- synchronized Phase 3 plan and task records;
- Phase 0C.1 contract recording;
- DEBUG reuse feasibility investigation and recorded decision;
- one-file buffered source abstraction;
- CR/LF/CRLF normalization across buffer boundaries;
- filename/file-ID, physical-offset, line, and column provenance;
- deterministic close/reopen rewind;
- bounded byte and line APIs;
- minimal tokenization and classification;
- stable source and lexical diagnostics;
- temporary deterministic token dump;
- build, artifact, memory, documentation, and user runtime verification.

### Excluded

- statement parsing;
- numeric conversion and numeric overflow evaluation;
- opcode/addressing-mode lookup or instruction sizing;
- `.org`, `.byte`, or `.word` semantics;
- output creation or machine-code emission;
- expressions, labels, symbols, and passes;
- VMM-backed source or symbol storage;
- multiple top-level inputs and includes;
- R6 relocation, maps, and listings;
- changes to DEBUG unless separately planned and approved.

## Planned Files

| Path | Action | Phase 3 responsibility |
|---|---|---|
| `brain/plans/2026-07-16-casm-phase3-source-stream-lexer.md` | Create | Approved implementation plan |
| `brain/plans/2026-07-16-casm-assembler-implementation-plan.md` | Modify | Correct dependencies and reference Phase 3 plan |
| `brain/plans/2026-07-16-casm-phase2-cli-file-services.md` | Modify | Correct Phase 5 output references to Phase 4 |
| `wiki/tasks/casm.md` | Modify | Phase 3 gate, subtasks, and acceptance tracker |
| `brain/task.md` | Modify | Synchronize Taskwarrior Phase 3 state |
| `src/external/casm/common.inc` | Modify | Source/lexer constants, ABI, and diagnostics |
| `src/external/casm/state.s` | Create | WP3 bounded source, lookahead, and token BSS only |
| `src/external/casm/source.s` | Create | Rewindable source stream and provenance |
| `src/external/casm/lexer.s` | Create | Minimal bounded lexer |
| `src/external/casm/casm.s` | Modify | Temporary token-dump orchestration |
| `src/external/casm/diagnostics.s` | Modify | Stable source and lexical diagnostics |
| `CMakeLists.txt` | Modify if required | Register new CASM modules and fixtures |
| `src/external/casm/AGENTS.md` | Review/modify if needed | Durable source/lexer contracts |
| `brain/KNOWLEDGE.md` | Modify | Approved Phase 0C.1 and reuse decisions |
| `brain/MEMORY.md` | Modify | Measured Phase 3 BSS and linked size |
| `CHANGELOG.md` or dated changelog | Modify/create | Observable token-dump behavior |
| `brain/walkthroughs/2026-07-16-casm-phase3-source-stream-lexer.md` | Create | Build and user evidence |

The `$2000` `MAIN` envelope is in force (raised from `$1000` in WP6). Phase 2 build 1014 uses
2,256 linked code/data bytes and 449 BSS bytes, leaving 1,391 bytes of combined
headroom. Implementation stops for approval if Phase 3 cannot fit within the
current envelope.

## Public Module ABI

### `source.s`

```text
sourceInit
sourceOpen
sourceNextByte
sourceNextLine
sourceGetLocation
sourceRewind
sourceClose
```

- Carry clear means success and `A` contains a source result.
- Carry set means failure and `A` contains `CASM_DIAG_*`.
- `sourceNextByte` returns the normalized source byte separately from its
  result code so EOF cannot be confused with data or carry state.
- WP4 initially implements `sourceNextByte` as a transitional raw-byte API and
  returns every physical byte as `CASM_SOURCE_BYTE`. WP5 owns the approved
  normalized semantics and adds `CASM_SOURCE_NEWLINE`; WP7 cannot consume the
  API before WP5 is complete.
- State that survives an `OS_API` call is stored in CASM-owned bounded BSS.
- EOF is repeat-stable.
- Every public routine documents inputs, outputs, carry/zero meaning,
  preserved values, clobbers, and scratch.
- Every comparison on a status-return path is followed by explicit carry
  normalization before return.

Initial source results:

```text
CASM_SOURCE_BYTE
CASM_SOURCE_NEWLINE
CASM_SOURCE_EOF
```

### `lexer.s`

```text
lexerInit
lexerNext
lexerGetToken
```

- `lexerNext` returns exactly one significant token.
- One-byte lookahead is owned by the lexer/source boundary and survives input
  block transitions.
- Token start location is captured before the first token byte is consumed.
- EOF is repeat-stable.
- Lexer failures do not close the source directly; orchestration explicitly
  closes it or central cleanup retains ownership.

## Work Packages

### Detailed Planning and Version Gates

Work Packages 3 through 11 each require a dedicated detailed implementation
plan under `brain/plans/` and explicit user approval before the package becomes
active or implementation begins. Approval of this parent plan or an earlier
work package does not approve a later package. Read-only discovery needed to
prepare a plan is permitted; investigation, source/build changes, fixtures,
functional documentation, and task activation wait for plan approval.

Each plan must incorporate prerequisite findings and define its objective,
scope, files, ABI and memory effects, register/flag/scratch contracts, atomic
increments, failure and cleanup behavior, verification, documentation and task
updates, stop conditions, and completion gate. A material deviation requires
the plan to be amended and reapproved before implementation continues.

Required Phase 3 plan files are:

```text
brain/plans/2026-07-16-casm-phase3-wp03-shared-abi-bounded-state.md
brain/plans/2026-07-16-casm-phase3-wp04-rewindable-source-backend.md
brain/plans/2026-07-16-casm-phase3-wp05-newlines-provenance.md
brain/plans/2026-07-16-casm-phase3-wp06-rewind-line-api.md
brain/plans/2026-07-16-casm-phase3-wp07-minimal-lexer-core.md
brain/plans/2026-07-16-casm-phase3-wp08-textual-numeric-tokens.md
brain/plans/2026-07-16-casm-phase3-wp09-mnemonic-classification.md
brain/plans/2026-07-16-casm-phase3-wp10-diagnostics-token-dump.md
brain/plans/2026-07-16-casm-phase3-wp11-verification-closeout.md
```

Completion of every CASM work package increments the decimal stage component
of the current `major.minor.stage` version after verification and explicit user
approval. Major and minor remain fixed unless separately approved, and the
build number remains independent. The current banner stores `VERSION_STAGE` as
one byte; a separately planned multi-digit stage implementation is therefore a
hard prerequisite before any work package at `0.1.9` may be completed.

### Work Package 1: Task and Contract Synchronization

1. Add a Phase 3 milestone and one measurable subtask per work package to
   `wiki/tasks/casm.md`.
2. Create matching Taskwarrior records and synchronize UUIDs in
   `brain/task.md`.
3. Correct the master and Phase 2 dependency discrepancies recorded above.
4. Record approved Phase 0C.1 decisions in `brain/KNOWLEDGE.md`.
5. Keep Phase 3 open until the user approves its walkthrough.

Gate: plan, wiki task, Taskwarrior, and `brain/task.md` agree.

### Work Package 2: DEBUG Reuse Feasibility

Complete the mandatory read-only investigation, record evidence for each table
and routine, choose the Phase 3 mnemonic-table strategy, and explicitly defer
Phase 4-only reuse decisions.

Gate: mnemonic classification has an approved data source and no runtime or
build coupling to DEBUG has been introduced accidentally.

### Work Package 3: Shared ABI and Bounded State

Prerequisite: its dedicated detailed implementation plan is saved and
explicitly approved, incorporating the approved Work Package 2 decisions.

- Add source results, token types/subtypes, limits, PETSCII constants, phase
  identifiers, and diagnostics to `common.inc`.
- Assign only the approved `$80-$83` parser scratch aliases; retain `$84-$8F`
  for expression, pass, and emission phases.
- Add bounded BSS for source cursor, block length/index, lookahead, location,
  token record, and token text.
- Create the storage-only `state.s`; executable `source.s` and `lexer.s`
  remain owned by WP4 and WP7 respectively.
- Add compile-time assertions for every capacity and table relationship.
- Measure BSS and linked growth before continuing.

Gate: static memory audit confirms bounded state and no OS-owned or
later-phase zero page is consumed.

### Work Package 4: Rewindable Source Backend

Prerequisite: its dedicated detailed implementation plan is saved and
explicitly approved.

- Create `source.s` and integrate it with the managed Phase 2 input wrappers.
- Implement initialization, open, block refill, byte traversal, explicit close,
  and repeat-safe EOF.
- Advance physical offsets only after successful byte consumption.
- Treat `CasmSourceOffset` as bytes consumed, distinct from Phase 2's
  bytes-fetched total, and validate equality before first EOF.
- Return raw CR, LF, null, and all other byte values unchanged; WP5 owns
  normalization and WP6 owns line-API null rejection.
- Retain registered ownership when close fails.
- Route the existing consume-only entry path through the source API without
  introducing WP10's token dump or changing its success message.

Gate: raw byte fixtures traverse 17-byte, 256-byte, and 513-byte inputs with
consumed/fetched count equality, without loss, duplication, or cursor wrap.

### Work Package 5: Newlines and Provenance

Prerequisite: its dedicated detailed implementation plan is saved and
explicitly approved.

- Normalize CR, LF, and CRLF, including all block-boundary cases.
- Track file ID, physical offset, one-based line, and one-based column.
- Resolve final CR before EOF.
- Reject line or location overflow before commit.
- Implement `sourceGetLocation` with a documented snapshot ABI.

Gate: location fixtures match expected coordinates for every normalized
newline form.

### Work Package 6: Deterministic Rewind and Line API

Prerequisite: its dedicated detailed implementation plan is saved and
explicitly approved.

- Implement close/reopen `sourceRewind`.
- Preserve the primary rewind diagnostic across secondary close/reopen cleanup
  failures while following central ownership rules.
- Reset all source, line, EOF, and lookahead state.
- Implement bounded `sourceNextLine` without adding a second 256-byte buffer.
- Reject embedded null bytes and overlong lines.
- Prevent byte/line API mixing without reset.

Gate: two traversals return identical bytes, newline results, and locations;
line boundary cases pass at 255 accepted and 256 rejected bytes.

### Work Package 7: Minimal Lexer Core

Prerequisite: its dedicated detailed implementation plan is saved and
explicitly approved.

- Create `lexer.s`.
- Implement initialization, lookahead, token reset, token append, and token
  return.
- Skip spaces and tabs.
- Consume comments while preserving the terminating newline token.
- Return punctuation and delimiter tokens.
- Capture token start provenance before consumption.

Gate: punctuation, whitespace, comment, blank-line, and EOF fixtures are
deterministic across buffer boundaries and rewind.

### Work Package 8: Textual and Numeric Tokens

Prerequisite: its dedicated detailed implementation plan is saved and
explicitly approved.

- Scan bounded identifiers without modifying spelling.
- Scan dot-prefixed directives.
- Classify registers case-insensitively.
- Validate decimal, hexadecimal, and binary lexical forms.
- Reject malformed prefixes, invalid suffixes, and overlong tokens.

Gate: every accepted/rejected boundary shape produces the expected token or
stable diagnostic with the correct start location.

### Work Package 9: Mnemonic Classification

Prerequisite: its dedicated detailed implementation plan is saved and
explicitly approved, incorporating the approved Work Package 2 reuse decision.

- Implement the mnemonic-table strategy approved by Work Package 2.
- Classify all documented 6502 mnemonics case-insensitively.
- Keep opcode bytes and addressing-mode metadata out of Phase 3.
- Add table-count, subtype-range, duplicate, and completeness checks using
  existing build verification rather than a one-off script.

Gate: all 56 mnemonics classify in supported case forms; near misses remain
identifiers rather than valid mnemonics.

### Work Package 10: Diagnostics and Token Dump

Prerequisite: its dedicated detailed implementation plan is saved and
explicitly approved.

Add stable diagnostics for:

- source rewind failure;
- source offset/size overflow;
- line-number or column overflow;
- line too long;
- token too long;
- invalid source byte;
- malformed numeric token; and
- invalid lexer state.

Extend bounded diagnostic tables without renumbering Phase 2 diagnostics.
Replace the Phase 2 consume-only success path with a temporary deterministic
token dump that prints token type and source location. `/S`, `/M`, and `/L`
remain unavailable. Every terminal path uses explicit close or central cleanup.

Gate: token dump is deterministic and clearly identified as temporary
verification behavior, not final CASM output.

### Work Package 11: Verification and Closeout

Prerequisite: its dedicated detailed implementation plan is saved and
explicitly approved.

- Run static carry, bounds, ownership, provenance, and phase-scope audits.
- Build the narrow `casm` target and inspect its PRG header, R6 footer, linked
  size, BSS, and relocation count.
- Confirm a no-change rebuild does not increment `BUILD_CASM`.
- Build `image_d64` and confirm CASM remains present without losing another
  application.
- Update task, brain, changelog, walkthrough, and applicable DOX records.
- Ask the user to run the supported local C64/VICE or hardware matrix.
- Ask explicitly whether Phase 3 may be marked done.

Gate: automated evidence and user runtime evidence are recorded, all records
agree, and the user approves completion.

## Verification Matrix

Fixtures and runtime checks must cover:

- empty openable input where the device permits it;
- input without a final newline;
- CR, LF, and CRLF inputs;
- CRLF split at byte 255/256;
- consecutive newline bytes and blank lines;
- 255-byte accepted and 256-byte rejected logical lines;
- comments ending in each newline form;
- identifiers at 31 and 32 bytes;
- every official mnemonic in supported case forms;
- all initial directives and registers;
- decimal, hexadecimal, and binary lexical forms;
- malformed `$`, `%`, `$12G`, and `%102`;
- every punctuation token;
- tokens split across input-buffer boundaries;
- rewind producing byte-, token-, and location-identical traversals;
- read, close, and reopen failures;
- primary diagnostic preservation during cleanup failure;
- a second CASM launch after successful and failed source operations; and
- no progressive handle, channel, stack, keyboard, or screen corruption.

Do not use the broken `c64-testing` MCP or a web emulator. The user performs
runtime verification in the supported local emulator or on hardware.

## Atomic Implementation Order

1. Synchronize Phase 3 task records and dependency corrections.
2. Complete the DEBUG reuse feasibility investigation.
3. Record the approved reuse decision and Phase 0C.1 contracts.
4. Add shared source/lexer ABI and bounded state.
5. Implement source initialization, open, refill, and close.
6. Implement byte traversal, newline normalization, and provenance.
7. Implement deterministic rewind.
8. Implement bounded line access.
9. Implement lexer primitives, whitespace, comments, and punctuation.
10. Implement identifiers, directives, registers, and numeric lexical checks.
11. Implement mnemonic classification from the approved source data.
12. Integrate the temporary token dump.
13. Perform static, build, artifact, memory, and release-disk verification.
14. Update documentation and create the walkthrough.
15. Obtain user runtime confirmation and completion approval.

Execute one approved increment at a time. On failure, stop for root-cause
analysis before altering the design.

## Completion Gate

Phase 3 is ready for completion approval only when:

- the dependency corrections and Phase 0C.1 contracts are recorded;
- the DEBUG reuse investigation and decision are recorded;
- tokenization is deterministic before and after rewind;
- CR, LF, and CRLF normalize correctly across block boundaries;
- every token reports the correct file, line, and column;
- every line, token, cursor, offset, and location bound fails before overflow
  or truncation;
- all documented 6502 mnemonics classify correctly;
- no Phase 4 statement, opcode, expression, or emission behavior entered Phase
  3;
- all source handles are explicitly closed or retained for central cleanup;
- primary failures survive secondary cleanup failures;
- CASM remains within an approved measured memory envelope;
- the release disk remains intact;
- task, brain, changelog, walkthrough, and applicable DOX records agree;
- every completed work package has advanced the version stage and the
  multi-digit representation is complete before completion at `0.1.9`;
- the user completes the runtime walkthrough; and
- the user explicitly approves marking Phase 3 done.
