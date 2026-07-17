---
feature: casm-native-assembler
phase: 3
work-package: 3
created: 2026-07-16
status: completed
implementation-status: completed
depends-on: casm-phase-3-wp2-debug-reuse-feasibility
approval-required: true
---

# CASM Phase 3 WP3 Plan: Shared ABI and Bounded State

## Approval Gate

The user approved this plan and authorized WP3 implementation on 2026-07-16.
The user confirmed runtime verification and authorized marking WP3 complete on
2026-07-16.

Implementation must stop and request renewed approval if any material ABI,
storage, zero-page, file, build, or memory-envelope decision below changes.

## Objective

Freeze the shared source/lexer identifiers and allocate the bounded base-RAM
state required by later Phase 3 work packages without implementing source
streaming or tokenization.

WP3 adds:

- source results, states, API modes, and limits;
- token types, type-specific subtypes, record offsets, and capacities;
- explicit PETSCII bytes required by the approved lexical grammar;
- stable Phase 3 diagnostic identifiers;
- narrow `$80-$83` source/lexer scratch aliases;
- exactly 63 bytes of source/lexer BSS; and
- compile-time assertions covering capacities, record layouts, ranges, and
  the current `$1000` envelope contract.

The package must build and link but must not open, read, rewind, normalize, or
tokenize source input. Runtime behavior remains the Phase 2 consume-only path.

## Prerequisites and Inherited Decisions

- Phase 2 build 1014 established one 256-byte `CasmIoBuffer`, managed input
  ownership, and a `$1000` `MAIN` envelope.
- WP1 recorded the approved Phase 0C.1 source/lexer contract.
- WP2 approved a future CASM-local 56-entry mnemonic table. WP3 reserves the
  subtype range but does not add that table or classifier.
- Current CASM `0.1.4` build 1016 uses 2,256 linked code/data bytes and 449 BSS
  bytes, leaving 1,391 bytes of combined envelope headroom.
- The existing zero-page range remains `$70-$8F`. WP3 may alias only
  `$80-$83`; `$84-$87` remains expression-owned and `$88-$8F` remains
  pass/emission-owned.
- Source and line APIs must reuse the existing I/O buffer. No second 256-byte
  buffer may be introduced.
- Physical offsets and line numbers are checked 16-bit values; columns are
  checked one-byte, one-based values.
- Token text is limited to 31 payload bytes plus one null terminator.
- Every implementation work package from WP3 onward increments the CASM stage
  only after verification and explicit user completion approval.

## Sub-Phase Dependency Audit

WP3 is the declaration/storage gate for every later Phase 3 package. The
following ownership boundaries are binding:

| Consumer | WP3 dependency | Must remain deferred |
|---|---|---|
| WP4 source backend | Source state/result constants, block length/index, physical offset, API mode | Newline normalization, location advancement, rewind, line API |
| WP5 newline/provenance | Pending-CR byte, file ID, offset, line, column, result byte | Line-window construction and lexer state |
| WP6 rewind/line API | API mode, line length/state, existing `CasmIoBuffer` ownership rule | Tokenization and token storage mutation |
| WP7 lexer core | Lexer state, lookahead record, token record and punctuation types | Text/numeric scanning and classification tables |
| WP8 textual/numeric tokens | Token text capacity, directive/register/number subtype ranges | Mnemonic table and opcode metadata |
| WP9 mnemonic classification | Reserved mnemonic subtype range 0-55 and token record | Opcode/addressing tables and DEBUG coupling |
| WP10 diagnostics/token dump | Reserved diagnostics `$14-$1B`, Phase 3 identifier, completed token record | Production assembly/output semantics |
| WP11 verification | Frozen sizes, assertions, and cumulative memory baseline | New functionality |

Resolved discrepancies:

1. WP3 creates only `state.s`. WP4 retains creation and executable ownership
   of `source.s`; WP7 retains creation and executable ownership of `lexer.s`.
2. `CasmIoBuffer` cannot be a transfer block and line window simultaneously.
   WP6 must switch ownership by API mode and perform line-mode reads directly
   into the next bounded line-window byte.
3. WP3 reserves diagnostic numbers but does not add messages. WP4-WP9 may
   return those values only on paths not activated by production orchestration;
   WP10 adds bounded display dispatch before the Phase 3 token-dump path runs.
4. WP3 reserves mnemonic subtype numbers but does not freeze mnemonic-to-number
   spelling. WP9 owns that explicit mapping under the approved WP2 ordering.
5. WP3 allocates persistent state but no initializer. WP4 owns source-state
   initialization and WP7 owns lexer/token-state initialization before either
   public API becomes callable.

No dependency requires opcode metadata, expression scratch, VMM storage, a
second input buffer, or DEBUG modification.

## Scope

### Included

- shared Phase 3 constants and assertions in `common.inc`;
- a storage-only source/lexer BSS module in `state.s`;
- exports required by later source and lexer modules;
- narrow parser-scratch aliases over `$80-$83`;
- source/lexer ABI documentation comments;
- correction of the stale `common.inc` Phase 5 output-consumer comment to
  Phase 4;
- configure/build, no-change build, artifact, map-size, BSS, relocation, and
  release-disk verification;
- memory, task, changelog, walkthrough, and DOX closeout after approval; and
- stage-version advancement from `0.1.4` to `0.1.5` only after the user
  approves WP3 completion.

### Excluded

- source initialization, open, refill, traversal, close, or EOF behavior;
- CR/LF/CRLF normalization and provenance advancement;
- rewind and line retrieval;
- lexer initialization, lookahead, token construction, or classification;
- mnemonic, directive, register, or numeric lookup tables;
- changes to `CasmIoBuffer` or Phase 2 file wrappers;
- diagnostics messages or dispatch-table extension;
- fixtures or temporary token dump behavior;
- DEBUG source, tests, tables, or build changes;
- CMake changes unless discovery proves the existing source glob insufficient;
  such a discovery is a stop condition; and
- WP4 or later task activation.

## Planned Files

| Path | Action | Responsibility |
|---|---|---|
| `src/external/casm/common.inc` | Modify | Shared constants, record offsets, scratch aliases, assertions |
| `src/external/casm/state.s` | Create | Source, lookahead, and token BSS ownership/exports only |
| `brain/MEMORY.md` | Modify at closeout | Measured linked/BSS growth and remaining headroom |
| `brain/KNOWLEDGE.md` | Modify at closeout | Approved ABI/layout decision |
| `CHANGELOG.md` | Modify at closeout | Observable version/package state |
| `wiki/tasks/casm.md` | Modify during implementation/closeout | WP3 state |
| `brain/task.md` | Modify with Taskwarrior | WP3 state |
| `brain/walkthroughs/2026-07-16-casm-phase3-wp03-shared-abi-bounded-state.md` | Create at closeout | Evidence and manual confirmation |
| `src/external/casm/AGENTS.md` | Review; modify only if needed | DOX contract pass |

`CMakeLists.txt` is intentionally unchanged: `CASM_SRCS` already uses a
`CONFIGURE_DEPENDS` recursive glob over `src/external/casm/*.s` and `.inc`.

## Shared Constant Contract

### Source Limits and Results

Add the following exact values:

```text
CASM_SOURCE_FILE_ID_INITIAL = $00
CASM_SOURCE_OFFSET_INITIAL  = $0000
CASM_SOURCE_LINE_INITIAL    = $0001
CASM_SOURCE_COLUMN_INITIAL  = $01
CASM_SOURCE_LINE_MAX        = $FFFF
CASM_SOURCE_COLUMN_MAX      = $FF
CASM_SOURCE_OFFSET_MAX      = $FFFF
CASM_SOURCE_LINE_PAYLOAD_MAX = $FF

CASM_SOURCE_BYTE    = $01
CASM_SOURCE_NEWLINE = $02
CASM_SOURCE_EOF     = $03
```

Zero remains unavailable as a successful source result so zeroed state cannot
masquerade as a consumed byte or EOF.

### Source State and API Mode

```text
CASM_SOURCE_STATE_CLOSED = $00
CASM_SOURCE_STATE_READY  = $01
CASM_SOURCE_STATE_EOF    = $02
CASM_SOURCE_STATE_ERROR  = $03

CASM_SOURCE_API_NONE = $00
CASM_SOURCE_API_BYTE = $01
CASM_SOURCE_API_LINE = $02
```

The state values describe lifetime; API mode prevents byte/line mixing without
an explicit future reset or rewind. WP3 only declares these values.

The line-window state is separately bounded:

```text
CASM_SOURCE_LINE_IDLE     = $00
CASM_SOURCE_LINE_BUILDING = $01
CASM_SOURCE_LINE_READY    = $02
CASM_SOURCE_LINE_EOF      = $03
```

WP6 must switch `CasmIoBuffer` ownership explicitly. Byte mode owns it as a
256-byte transfer block. Line mode owns it as a 255-byte payload plus optional
terminator and performs bounded reads directly into the next line-window byte;
it may not refill/overwrite the buffer as a transfer block. Mixing modes
requires rewind/reset.

### Token Capacity and Types

```text
CASM_TOKEN_TEXT_MAX         = 31
CASM_TOKEN_TEXT_BUFFER_SIZE = 32

CASM_TOKEN_EOF       = $00
CASM_TOKEN_NEWLINE   = $01
CASM_TOKEN_IDENTIFIER = $02
CASM_TOKEN_MNEMONIC  = $03
CASM_TOKEN_DIRECTIVE = $04
CASM_TOKEN_REGISTER  = $05
CASM_TOKEN_NUMBER    = $06
CASM_TOKEN_COMMA     = $07
CASM_TOKEN_COLON     = $08
CASM_TOKEN_HASH      = $09
CASM_TOKEN_LPAREN    = $0A
CASM_TOKEN_RPAREN    = $0B
CASM_TOKEN_PLUS      = $0C
CASM_TOKEN_MINUS     = $0D
CASM_TOKEN_LESS      = $0E
CASM_TOKEN_GREATER   = $0F
CASM_TOKEN_COUNT     = $10
```

There are sixteen token types, numbered `$00-$0F`. `CASM_TOKEN_COUNT` is an
exclusive upper bound and compile-time assertion target.

### Token Subtypes

Subtype values are interpreted only with their token type:

```text
CASM_SUBTYPE_NONE = $00

CASM_MNEMONIC_FIRST = $00
CASM_MNEMONIC_LAST  = $37
CASM_MNEMONIC_COUNT = 56

CASM_DIRECTIVE_UNKNOWN = $00
CASM_DIRECTIVE_ORG     = $01
CASM_DIRECTIVE_BYTE    = $02
CASM_DIRECTIVE_WORD    = $03
CASM_DIRECTIVE_INCLUDE = $04
CASM_DIRECTIVE_STATIC  = $05
CASM_DIRECTIVE_RELOC   = $06
CASM_DIRECTIVE_COUNT   = $07

CASM_REGISTER_A = $00
CASM_REGISTER_X = $01
CASM_REGISTER_Y = $02
CASM_REGISTER_COUNT = $03

CASM_NUMBER_DECIMAL = $00
CASM_NUMBER_HEX     = $01
CASM_NUMBER_BINARY  = $02
CASM_NUMBER_COUNT   = $03
```

WP3 reserves mnemonic subtypes 0-55 in the verified WP2 ordering but does not
enumerate individual mnemonic names; WP9 freezes and asserts that mapping.

### Token Record Layout

The persistent token record is exactly 39 bytes:

```text
CASM_TOKEN_REC_TYPE     = 0
CASM_TOKEN_REC_SUBTYPE  = 1
CASM_TOKEN_REC_LENGTH   = 2
CASM_TOKEN_REC_FILE_ID  = 3
CASM_TOKEN_REC_LINE_LO  = 4
CASM_TOKEN_REC_LINE_HI  = 5
CASM_TOKEN_REC_COLUMN   = 6
CASM_TOKEN_REC_TEXT     = 7
CASM_TOKEN_REC_SIZE     = 39
```

`CasmTokenRecord` owns the seven-byte header. `CasmTokenText` is an exported
label at `CasmTokenRecord + CASM_TOKEN_REC_TEXT` and covers the final 32 bytes.
This provides one contiguous record without duplicating text storage.

### PETSCII Constants

Add explicit numeric bytes needed by Phase 3 rather than ca65 host character
literals:

```text
NULL=$00 TAB=$09 LF=$0A CR=$0D SPACE=$20 HASH=$23 PERCENT=$25
LPAREN=$28 RPAREN=$29 PLUS=$2B COMMA=$2C MINUS=$2D DOT=$2E
DIGIT_0=$30 DIGIT_9=$39 COLON=$3A SEMICOLON=$3B LESS=$3C
GREATER=$3E UPPER_A=$41 UPPER_Z=$5A UNDERSCORE=$5F
SHIFTED_A=$C1 SHIFTED_Z=$DA
```

Existing Phase 2 PETSCII constants retain their numeric values. Duplicate
numeric meanings reuse the existing symbol where practical; they are not
renumbered or replaced.

### Stable Diagnostic Identifiers

Reserve the next contiguous codes without adding messages or dispatch entries:

```text
CASM_DIAG_SOURCE_REWIND_FAILED  = $14
CASM_DIAG_SOURCE_OFFSET_OVERFLOW = $15
CASM_DIAG_SOURCE_LOCATION_OVERFLOW = $16
CASM_DIAG_SOURCE_LINE_TOO_LONG  = $17
CASM_DIAG_TOKEN_TOO_LONG        = $18
CASM_DIAG_INVALID_SOURCE_BYTE   = $19
CASM_DIAG_MALFORMED_NUMBER      = $1A
CASM_DIAG_LEXER_STATE_FAILED    = $1B
CASM_DIAG_PHASE3_LAST           = $1B
```

WP3 code cannot return these diagnostics because no source/lexer routines are
implemented. WP10 adds their messages and bounded pointer-table entries without
renumbering Phase 1/2 codes `$01-$13`.

### Phase Identifier

```text
CASM_PHASE_SOURCE_LEXER = $03
```

The entry point continues to store `CASM_PHASE_CLI_FILE` until the temporary
token-dump orchestration is activated in WP10.

## Zero-Page Contract

Add only these aliases:

```text
CasmSourceScratch0 = CasmParseScratch0 ; $80
CasmSourceScratch1 = CasmParseScratch1 ; $81
CasmLexerScratch0  = CasmParseScratch2 ; $82
CasmLexerScratch1  = CasmParseScratch3 ; $83
```

They are transient call-local aliases, never persistent state. A public source
or lexer routine may clobber only the scratch aliases named in its documented
ABI. No state may be assumed to survive an `OS_API` call in zero page.

WP3 must assert the aliases equal `$80-$83` and that expression/pass/emission
scratch remains `$84-$8F` unchanged.

## Bounded BSS Layout

### Source-state subrecord: 16 bytes

```text
CasmSourceApiMode       1
CasmSourceState         1
CasmSourceFileId        1
CasmSourceBlockLenLo    1
CasmSourceBlockLenHi    1
CasmSourceBlockIndexLo  1
CasmSourceBlockIndexHi  1
CasmSourceOffsetLo      1
CasmSourceOffsetHi      1
CasmSourceLineLo        1
CasmSourceLineHi        1
CasmSourceColumn        1
CasmSourcePendingCr     1
CasmSourceResultByte    1
CasmSourceLineLength    1
CasmSourceLineState     1
```

`CasmSourceLineState` makes the future transfer-block/line-window ownership
transition explicit. `CasmSourcePendingCr` handles CRLF normalization and final
CR resolution; EOF itself is represented by `CasmSourceState`.

### Lexer-state subrecord: 47 bytes

```text
CasmLexerState           1
CasmLookaheadValid       1
CasmLookaheadResult      1
CasmLookaheadByte        1
CasmLookaheadFileId      1
CasmLookaheadLineLo      1
CasmLookaheadLineHi      1
CasmLookaheadColumn      1
CasmTokenRecord         39
```

The lookahead record is seven bytes plus its validity flag. It retains the
normalized source result, byte, and start location across input-block
transitions. `CasmLexerState` is distinct from lookahead validity and supports
repeat-stable EOF/error gating in later packages.

Combined WP3 BSS growth is exactly 63 bytes. No new general buffer, filename,
line window, table, or VMM allocation is permitted.

Expected post-WP3 BSS is 512 bytes. With no intentional CODE/RODATA growth
beyond linker metadata, expected combined envelope headroom is approximately
1,328 bytes. Actual linked growth and any padding are authoritative and must be
measured before WP3 can be offered for completion.

## Export and Future Import Contract

`state.s` exports all source-state, lexer-state, lookahead, token-record, and
token-text labels. WP3 introduces no imports and no public executable routines.
WP4's future `source.s` and WP7's future `lexer.s` import their owned state from
this module; neither module redefines storage.

Later modules import only the symbols they own or consume. Storage is defined
once. No absolute BSS address is copied into `common.inc`, and no BSS symbol is
declared as zero page.

## Future Public Routine ABI Constraints

WP3 does not implement routines, but the declared state must support these
already-approved later interfaces:

```text
sourceInit sourceOpen sourceNextByte sourceNextLine
sourceGetLocation sourceRewind sourceClose
lexerInit lexerNext lexerGetToken
```

Later detailed plans must document each routine's A/X/Y inputs and outputs,
carry and zero semantics, preserved registers, scratch aliases, BSS mutations,
and behavior across OS calls. They may not alter the WP3 record layout without
amending and reapproving this plan.

## Compile-Time Assertions

Add assertions for:

- `CASM_SOURCE_LINE_PAYLOAD_MAX = 255`;
- `CASM_TOKEN_TEXT_BUFFER_SIZE = CASM_TOKEN_TEXT_MAX + 1 = 32`;
- `CASM_TOKEN_COUNT = CASM_TOKEN_GREATER + 1 = 16`;
- mnemonic count/range equals 56 entries and `$00-$37`;
- directive/register/number subtype counts equal their exclusive bounds;
- every token-record field follows the preceding field;
- `CASM_TOKEN_REC_TEXT + CASM_TOKEN_TEXT_BUFFER_SIZE = 39`;
- source BSS size equals 16;
- lexer BSS size equals 47;
- combined new BSS equals 63;
- `CASM_IO_BUFFER_SIZE` remains 256;
- source/lexer aliases remain exactly `$80-$83`;
- expression and pass/emission scratch start at `$84` and `$88` respectively;
- Phase 2 last diagnostic remains `$13` and Phase 3 reserved range ends `$1B`;
  and
- `CASM_PHASE1_MAIN_SIZE = $1000` remains unchanged.

Where ca65 cannot assert cross-object distances, define local start/end labels
and assert sizes within the owning translation unit.

## Register, Flag, and Scratch Contract

WP3 adds no callable routine, so it has no runtime register or flag effects.
This absence is intentional: BSS declarations and constants cannot silently
introduce initialization side effects.

The future source and lexer routines inherit these mandatory conventions:

- carry clear means success; carry set means `A = CASM_DIAG_*`;
- successful source results are returned separately from source byte data;
- every status-path comparison is followed by explicit carry normalization;
- persistent values live in exported BSS, not transient zero page;
- no value needed after `OS_API` remains only in A/X/Y or shared zero page; and
- zero flag meaning must be documented per routine, never inferred from carry.

## Failure and Cleanup Behavior

WP3 acquires no handle, VMM allocation, channel, or output file. It does not
call `OS_API`, central cleanup, or `DOS_EXIT`. Therefore it adds no runtime
failure or cleanup path.

Build-time assertion or envelope failure is fatal to the increment. Do not
weaken an assertion, enlarge `MAIN`, remove existing state, or consume reserved
zero page to force a successful link. Stop for root-cause analysis and user
direction.

## Atomic Implementation Increments

### Increment 3.1: Activate and Protect State

1. Confirm explicit plan approval.
2. Protect the current working state without disturbing the unrelated PACMAN
   build-counter modification.
3. Mark WP3 in progress in Taskwarrior, `wiki/tasks/casm.md`, and
   `brain/task.md`.
4. Re-read the applicable DOX chain for every planned target.

Gate: task records agree and no unrelated file is staged or modified.

### Increment 3.2: Shared Constants and Assertions

1. Add source results, states, modes, limits, token types/subtypes, record
   offsets, PETSCII constants, diagnostics, phase identifier, and scratch
   aliases to `common.inc`.
2. Correct the stale Phase 5 output-consumer comment to Phase 4.
3. Add all same-file compile-time assertions.

Gate: constants are non-overlapping, stable Phase 2 values are unchanged, and
reserved later-phase zero page is untouched.

### Increment 3.3: Source State Skeleton

1. Create storage-only `state.s` with license header, `common.inc`, exports,
   local BSS start/end labels, and the exact 16-byte source subrecord.
2. Assert the source subrecord size locally.
3. Add no CODE or RODATA segment and no routine.

Gate: source state is bounded, exported once, and has no side effects.

### Increment 3.4: Lexer State Skeleton

1. Extend `state.s` with the exact 47-byte lexer/lookahead/token subrecord and
   token-text alias.
2. Assert the lexer subrecord and 63-byte combined module sizes locally.
3. Add no mnemonic table, CODE, RODATA, or routine.

Gate: lexer/lookahead/token storage is contiguous, bounded, and exactly 47
bytes.

### Increment 3.5: Static and Build Verification

1. Audit every new constant, range, record offset, export, and BSS byte.
2. Configure because new globbed `.s` files are introduced.
3. Build `casm`, repeat the no-change build, and build `image_d64`.
4. Inspect load address, R6 footer, linked bytes, BSS bytes, relocation count,
   build number, and release-disk presence.
5. Confirm the source manifest includes `state.s` once and does not yet include
   `source.s` or `lexer.s`.

Gate: zero warnings/errors, BSS grows by exactly 63 bytes, no-change rebuild is
stable, and CASM stays within `$1000`.

### Increment 3.6: Closeout

1. Perform the DOX pass and update `src/external/casm/AGENTS.md` only if the
   implemented state changes a durable local contract not already present.
2. Update knowledge, memory, changelog, task records, and walkthrough.
3. Present automated and manual inspection steps to the user.
4. Ask whether WP3 is complete.
5. After completion-candidate approval, advance CASM to `0.1.5`, rebuild, and
   record final artifact evidence.
6. Ask the user to confirm the `0.1.5` banner and safe shell return locally;
   only then request final authorization to mark WP3 complete.

Gate: records agree, the user approves completion, and WP4 remains pending.

Execute one increment at a time. On any failure, stop for RCA before changing
the design.

## Verification Matrix

### Static ABI Audit

- Existing Phase 1/2 constants retain their numeric values.
- Source results are distinct and nonzero.
- API modes and source states have exclusive bounded ranges.
- Token types occupy exactly `$00-$0F`.
- Mnemonic subtype range is exactly 0-55.
- Directive/register/number subtypes fit one byte and their counts match.
- Token record is exactly 39 bytes with a 32-byte trailing text field.
- Lookahead retains result, byte, and one-based start location.
- Source block length/index are 16-bit so value 256 is representable.
- Offset and line are 16-bit; column and line payload length are one byte.
- No second 256-byte buffer exists.
- Only `$80-$83` receive new aliases.
- Diagnostics `$01-$13` are unchanged; `$14-$1B` are reserved only.
- `state.s` contains no executable code or OS calls; `source.s` and `lexer.s`
  do not yet exist.

### Build and Artifact Audit

```text
cmake -S . -B build
cmake --build build --target casm
cmake --build build --target casm
cmake --build build --target image_d64
```

Record:

- initial and no-change `BUILD_CASM` values;
- base and next-page link success;
- final PRG byte count and `$3400` header;
- R6 base, relocation count, and `R6` footer;
- linked code/data and BSS totals;
- exactly 63 bytes of WP3 BSS growth;
- remaining combined envelope headroom;
- source manifest membership; and
- release disk directory retention of CASM and all prior shipping apps.

### Manual Review

No source/lexer runtime behavior changes. The user reviews:

- constant and subtype ranges;
- zero-page alias boundaries;
- source and lexer BSS layouts;
- token record offsets and size;
- measured memory-envelope result; and
- the walkthrough evidence.

After the completion-candidate approval and `0.1.5` bump, the user must confirm
the banner and safe return to an intact shell in the supported local emulator
or hardware. Do not use `c64-testing` or a web emulator.

## Documentation and DOX Closeout

- Record the approved ABI and measured memory result in `brain/KNOWLEDGE.md`
  and `brain/MEMORY.md`.
- Record WP3 and the completion version in `CHANGELOG.md`.
- Keep Taskwarrior, `wiki/tasks/casm.md`, and `brain/task.md` synchronized.
- Create the WP3 walkthrough before requesting completion approval.
- Re-check every changed path against the root and nearest child AGENTS files.
- Leave DOX unchanged only if the existing CASM contract already covers the
  new bounded state, explicit PETSCII, zero-page, and module ownership rules;
  state that conclusion in the closeout.

## Stop Conditions

Stop and request direction if:

- any Phase 1/2 constant must be renumbered;
- the exact BSS layout needs more than 63 bytes;
- a second input or line buffer appears necessary;
- source/lexer state requires `$84-$8F` or any OS-owned zero page;
- token text cannot remain within 31 bytes plus terminator;
- a new executable routine is required in WP3;
- new diagnostics need messages or runtime dispatch before WP10;
- the existing CMake glob does not integrate the new modules safely;
- BSS growth differs from 63 bytes without a clear linker-only explanation;
- cumulative linked+BSS usage exceeds the `$1000` envelope;
- build verification changes DEBUG or another external application;
- the unrelated PACMAN modification overlaps or is staged; or
- implementation materially diverges from this plan.

## Completion Gate

WP3 is ready for completion approval only when:

- the exact constants, record layouts, exports, and assertions are present;
- `state.s` owns a 16-byte source subrecord and 47-byte lexer subrecord with no
  code; `source.s` and `lexer.s` remain deferred to WP4 and WP7;
- only `$80-$83` have new Phase 3 scratch aliases;
- no second 256-byte buffer or runtime source/lexer behavior exists;
- stable Phase 2 diagnostics and ABI values are unchanged;
- configure, CASM, no-change, artifact, and release-disk checks pass;
- actual BSS growth is 63 bytes and `$1000` headroom remains positive;
- task, knowledge, memory, changelog, walkthrough, and DOX records agree;
- the user approves the walkthrough and completion-candidate gate;
- CASM is advanced to `0.1.5` only after that approval;
- the user confirms the `0.1.5` banner and safe shell return; and
- the user gives final authorization to mark WP3 complete.
