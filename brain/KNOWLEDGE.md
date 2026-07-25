# Knowledge Base

This file serves as the shared repository for architectural decisions, technical findings, and project-specific "gotchas" discovered during the porting of MS-DOS 4.0 to the Commodore 64.

## Architectural Decisions

| Date | Decision | Rationale | Status |
| :--- | :--- | :--- | :--- |
| 2026-05-01 | C64 Ultimate with REU | Target upgraded from stock C64 to C64 Ultimate specifically because it provides an REU (1MB–16MB) to adequately support the 1MB logical address space model of MS-DOS. | Active |
| 2026-05-01 | Service Bus Model | Adopted over a monolithic kernel. The C64 KERNAL operates as a collection of system routines, and GEOS-era OSes were essentially shells rather than full kernel replacements. DOS components (`IO.SYS`, `MSDOS.SYS`, `COMMAND.COM`) are modularized as coordinated services. | Active |
| 2026-05-01 | PETSCII as Character Standard | C64 uses PETSCII (Hex 00–FF), not ASCII. All character I/O, filenames, and messaging route through a PETSCII abstraction layer. | Active |
| 2026-05-01 | VMM and RAL as Constitutional Pillars | Virtual Memory Manager (VMM) and Register Abstraction Layer (RAL) are mandatory because the 8086's segmented memory architecture and rich register set do not exist on the 6502. The port treats the entire OS as an emulation layer, not a direct translation. | Active |
| 2026-05-01 | Kick Assembler | Selected for 6502 assembly support. | Active |
| 2026-05-01 | Oscar64 | Selected as the C compiler for C64 target. | Active |
| 2026-06-25 | Code Wiki & Project Tooling | Created structured code wiki under wiki/, corrected child DOX index paths, and initialized Taskwarrior + Codebase Memory. | Active |
| 2026-07-08 | Gap-Buffer VI Editor | Implemented a user-space vi-alike text editor using a Gap Buffer for O(1) edits, supporting line numbering, word/line operations, and horizontal/vertical scrolling. | Active |
| 2026-07-15 | Pac-Man generated maze topology | `autotile.py` owns logical path/wall/gate/pellet topology; neighboring cells infer normal render shapes and validated overrides handle visually ambiguous corners. CMake regenerates `mazeWalls` before Pac-Man assembly. | Active |

## Technical Findings

- **[2026-05-01] Workspace Initialization**: Successfully established the PRAR-compliant state management structure.
- **[2026-05-01] Boot Architecture Divergence**: PC boot is modular/sequential (MBR → IO.SYS → MSDOS.SYS → COMMAND.COM). C64 boot is minimalist/direct from fixed ROM (`*$0801`). Ported system must *emulate the effect* of structured handoffs through explicit initialization in the Service Bus, not actually take over boot ROM.
- **[2026-05-01] Component Analogy Mapping**:
  - `IO.SYS` → **File System Service API** (raw disk I/O, memory allocation, device routing)
  - `MSDOS.SYS` → **VMM + PETSCII Service Layer** (system calls, memory mapping, character encoding, process control)
  - `COMMAND.COM` → **System Shell Emulator** (command parsing, command registry, execution handover, prompt management)
- **[2026-05-01] Port Scope Definition**: "Mostly functional port," not a 1:1 replica. Features may be omitted with explicit justification documented here.
- **[2026-05-01] Source Code Structure**: Core modules in `v4.0/src/MAPPER/` (file I/O primitives) and `v4.0/src/DOS/` (system services). Internal commands are embedded in `v4.0/src/CMD/COMMAND/TCMD*.ASM`.
- **[2026-05-01] MAPPER Disassembly Findings**: `EXIT.ASM` (58 lines), `DELETE.ASM` (70 lines), and `MKDIR.ASM` (53 lines) are the simplest modules. They follow a strict 8-15 instruction wrapper pattern around INT 21h calls with only `MACROS.INC` as a dependency.
- **[2026-05-01] COMMAND.COM Core Logic**: The core dispatcher logic resides in `TCODE.ASM` (400+ lines). It reads input via `STD_CON_STRING_INPUT`, preprocesses it (`PRESCAN`), parses it (`PARSERINE`), and dispatches it to internal commands or initiates a file search (`PATH_SEARCH` for external commands).
- **[2026-05-01] C64 KERNAL Integration**: C64 KERNAL routines (e.g., `CHROUT`, `CHRIN`, `LOAD`, `SAVE`, `VERIFY`) will serve as the foundational building blocks for our PETSCII and I/O abstractions.
- **[2026-07-10] KERNAL Status Byte Stale State**: Stale state in the KERNAL status byte (`$90`) from previous file reads (EOF) or error-channel queries (EOI) was found to cause subsequent file write operations (`DOS_WRITE_FILE` / `fileWrite`) to abort immediately. Resolving this requires explicitly clearing `KernalStatus = $90` at the initialization step of the I/O loops (`fileRead` and `fileWrite`).
- **[2026-07-11] `test_filetest` PRG Type Default RCA**: The apparent loss of the first two bytes (`"He"`) from `TEST.TXT` is explained by `DOS_OPEN_FILE` defaulting write-mode files to PRG when `HexValHi` is unset; PRG-aware tools interpret the first two bytes as a load address. The accompanying `READ FROM FILE: G` symptom still points to the separate `fileRead` `READST`/`CHRIN` sequencing bug and LFN 15 status-drain fragility. Full investigation and plan: `brain/plans/2026-07-10-fileopen-prg-type-default-fix.md`.
- **[2026-07-11] `TYPE` LF Display Translation**: `TYPE` is a text-display command, so LF-only text files need display-time newline synthesis on the C64. The fix belongs in `cmdType`'s screen-output loop: translate `$0A` to `PetCr`/`PetLl`, while keeping `DOS_READ_FILE`, `DOS_WRITE_FILE`, and `COPY` byte-preserving.
- **[2026-07-14] External App Return Codes Absent**: `DOS_EXIT ($4C)` resets the stack and jumps to `mainLoop`; it has no documented input status byte and no shell-visible last-status storage. External utilities such as `COMP` are screen-output-only until a separate ERRORLEVEL-style status design is implemented. Tracked as Taskwarrior #25 / `wiki/tasks/external-app-return-codes.md`.
- **[2026-07-15] Pac-Man Phase 3.1 Boundary**: Only Blinky is advanced and
  rendered. Pinky/Inky/Clyde target math exists but is inactive; frightened,
  collision, fruit, house-release, and tunnel behavior must not be documented
  as playable yet.
- **[2026-07-15] Blinky Corner Loop Classification**: During scatter mode,
  Blinky's unreachable top-right target intentionally produces a repeating
  16-tile circuit around that corner. Corner circulation during the scheduled
  scatter windows is expected; a loop persisting after chase transition would
  be a separate defect.
- **[2026-07-15] Pac-Man Collision Sequencing**: Collision must be checked after
  either Pac-Man or Blinky moves so contact cannot leave Pac-Man logically
  active but visually overwritten. A harmful collision interrupts the current
  tick before the other actor advances.

## Current Status — Build 2436 / Stage 15 (2026-06-25)

| Task | Status |
| :--- | :--- |
| Phase 2A: Core Dispatcher | ✅ Done |
| Phase 2B: External Commands | ✅ Done |
| Phase 2C: Virtual Memory Manager (VMM) | ✅ Done |
| Phase 2D: Service Bus & VMM Stabilizing | ✅ Done |
| Phase 3: File System Integration (Handles) | ✅ Done |
| Phase 4: External System Utilities (DEBUG) | ✅ Done |
| Phase 5: Env & Multi-Device Support | ⏳ In-Progress (Taskwarrior & Wiki setup done) |
| Phase 6A: App Manager (Phase A) | ✅ Done |
| Phase 6B: Binary Relocator | ✅ Done |
| Phase 6C: External Editor (VI) | ✅ Done |

## Architectural Decisions & Constraints

### CASM Phase 1 Foundation (approved 2026-07-16)

- CASM is a native ca65/ld65 Command 64 application, not a host assembler.
- CASM reserves the external-app private `$70-$8F` zero-page range in four
  eight-byte transient categories: general values, I/O/VMM, parser/expression,
  and pass/emission.
- Central ownership tracks at most eight file handles and eight VMM
  allocations. Cleanup is bounded, repeat-safe, and preserves the primary
  error over cleanup failures.
- Phase 1 uses diagnostics for initialization failure, registry exhaustion,
  cleanup failure, and unknown internal failure; its banner is
  `CASM V0.1.0.<build>`.
- The initial ld65 `MAIN` envelope is `$1000` bytes and must be enlarged only
  through a measured later-phase decision.

### CASM Phase 2 CLI/File ABI (approved 2026-07-16)

- Phase 2 parses exactly one unquoted source filename and recognizes `/O`,
  `/S`, `/M`, and `/L` without modifying the OS-owned 80-byte command buffer.
- Filename payloads are bounded to 63 bytes plus a null terminator; native
  input transfers use one 256-byte base-RAM buffer.
- A successful OS file open must be registered immediately or
  compensating-closed. Failed closes retain central ownership for cleanup.
- State required after an `OS_API` service returns must be kept in CASM-owned
  bounded storage unless that service explicitly guarantees preservation.
  In particular, `fileClose` preserves its registry slot in BSS across
  `DOS_CLOSE_FILE`, not in transient shared zero page.
- Routines whose ABI returns status in carry must normalize carry after every
  comparison on the return path. `CMP #CASM_STREAM_EOF` sets carry on equality;
  returning that flag made normal EOF `$03` look like fatal diagnostic `$03`.
- CASM command-buffer grammar and synthesized filename bytes use explicit
  PETSCII numeric constants. ca65's C64 target character mapping can make a
  source literal such as `'S'` differ from the unshifted PETSCII byte `$53`.
- Central Phase 2 cleanup visits every owned file record, clears records only
  after `DOS_CLOSE_FILE` succeeds, retains failures for a repeat attempt, and
  never replaces an existing primary fatal diagnostic with cleanup failure.
- Phase 2 consumes input only. Production output create/write/delete behavior
  and incomplete-output runtime verification begin with numeric static output.
- Language, expression, symbol, VMM-store, emission-event, and R6 contracts
  remain behind the later Phase 0C gate.
- Phase 2 diagnostic codes `$01-$13` are contiguous and map through a bounded
  allocation-free pointer table. Zero, out-of-range, and `$FF` values use the
  internal-error fallback; successful input validation has a separate fixed
  message and does not consume a fatal diagnostic code.
- Phase 2 orchestration initializes resources before CLI/file state, rejects
  parsed-but-unavailable `/S`, `/M`, and `/L` options before I/O, derives but
  does not create the future output name, consumes one input to normalized EOF,
  explicitly closes it, and routes every failure through central cleanup.
- cc1541 cannot write a zero-byte host file, and its directory-only zero-block
  SEQ entry is not openable through the current Commodore DOS/KERNAL file path.
  CASM treats that case as input-open failure; stream boundary coverage uses
  openable 17-byte, 256-byte, and 513-byte SEQ fixtures.

### CASM Phase 3 Source/Lexer Contract (approved 2026-07-16)

- WP3 freezes the source/lexer ABI in `common.inc` and owns persistent Phase 3
  storage in storage-only `state.s`. The layout is exactly 63 BSS bytes: 16
  source bytes plus 47 lexer/lookahead/token bytes. The token record is 39
  contiguous bytes with a seven-byte header and 32-byte text buffer.
- WP3 reserves diagnostics `$14-$1B`, sixteen token types, type-specific
  directive/register/number subtypes, mnemonic subtype range 0-55, and only
  `$80-$83` as transient source/lexer aliases. It adds no diagnostic messages
  or runtime source/lexer path.
- `CasmIoBuffer` remains the sole 256-byte buffer. Future byte mode uses it as
  a transfer block; line mode must switch exclusive ownership and build the
  line directly in the same buffer. Mixing APIs requires rewind/reset.
- WP3 completion-candidate approval advanced CASM from `0.1.4` to `0.1.5`;
  final WP3 closure remains gated by user runtime confirmation.
- WP4 adds executable `source.s` over the managed input wrapper and WP3 state.
  `sourceNextByte` is a deliberate transitional raw-byte API: every `$00-$FF`
  byte, including CR and LF, returns `CASM_SOURCE_BYTE` with the byte in
  `CasmSourceResultByte`, never inferred from A or Z. WP5 replaces only the
  newline semantics; the lexer is gated on WP5. The source consumed offset is a
  distinct checked 16-bit cursor from the managed fetched total; at first EOF
  they must be equal, which is the raw-fixture loss/duplication gate. Offset and
  input-total overflow share the single `$15` diagnostic. `source.s` adds no BSS
  and writes no lexer state. User completion approval advanced CASM from `0.1.5`
  to `0.1.6`.
- WP5 replaces the transitional raw API with the normalized one. CR, LF, and
  CRLF collapse to one `CASM_SOURCE_NEWLINE` via the persistent
  `CasmSourcePendingCr` latch, which is what makes a CRLF split across an input
  block boundary work: the CR emits the newline and arms the latch, and the
  following LF is swallowed after the refill. A final CR emits its newline and
  the subsequent EOF clears the latch. `CasmSourceResultByte` is authoritative
  only for `CASM_SOURCE_BYTE` and is 0 for NEWLINE/EOF; the lexer keys on the
  result code and never interprets raw CR or LF.
- `CasmSourceOffset` is the **physical** consumed offset, not a count of returned
  results: it advances once per physical byte including the LF swallowed inside a
  CRLF. That is precisely what keeps `CasmSourceOffset == CasmInputTotal` true at
  first EOF once one result can span two physical bytes.
- Because `CasmSourceColumn` is one byte and Phase 0C.1 requires checked
  one-based columns, a source line longer than 255 bytes is unrepresentable and
  fails in byte mode with `$16`. A byte at column 255 arms an exhausted latch;
  only a further *byte* on that line fails, so a legitimate 255-byte line plus
  newline succeeds. The WP4 `casm256`/`casmmulti` fixtures are single lines over
  that limit and therefore now fail with `$16` by design; `casmsplit` carries the
  multi-block traversal coverage instead. WP6's line API rejects the same
  physical condition with `$17`; the two APIs keep distinct diagnostics.
- `sourceGetLocation` is a validated in-place accessor, not a copy: the canonical
  next-result location already lives in the persistent source fields, so it adds
  no snapshot BSS and callers copy the fields before the next mutating call. User
  completion approval advanced CASM from `0.1.6` to `0.1.7`.
- WP6 adds `sourceRewind` and `sourceNextLine`. The "single buffer, line window"
  contract was contradictory as written — a full-buffer refill destroys a line
  that spans blocks. It is realized as an explicit partition: while a line builds,
  `CasmIoBuffer[0..lineLength-1]` is the payload and `[lineLength..255]` is the
  transfer region a refill reads into, and the block cursor holds absolute buffer
  positions (byte mode base is always 0, so it is bit-identical). Safety rests on
  writePos (`CasmSourceLineLength`) <= readPos (`CasmSourceBlockIndex`), equal
  only right after a LINE-mode refill where the byte is loaded before it is
  stored. `sourceNextLine` reuses WP5 normalization via the private
  `sourceNextResult` entry rather than duplicating a newline state machine.
- Byte and line modes are mutually exclusive: line mode is claimed only on a
  fresh stream (offset 0, line state IDLE), mixing returns `$13`, and a rewind
  restores the choice. `sourceRewind` resets only source-owned state; lookahead
  invalidation is WP7's because `source.s` writes no lexer state. A rewind close
  failure returns the primary `$0D` (ownership retained); a reopen failure
  returns `$14` with the source CLOSED/NONE.
- WP6 raised the CASM linker envelope from `$1000` to `$2000` because Phase 3
  could not otherwise fit; `add_ca65_app(casm ... "2000")` sets `MAIN: size`.
  `inputStreamRead` is now a thin caller of the additive `inputStreamReadInto`.
  User completion approval advanced CASM from `0.1.7` to `0.1.8`.
- WP7 adds `lexer.s`, the first source-layer consumer, with a one-result
  lookahead over `sourceNextByte`, bounded token primitives, whitespace/comment
  skipping (the comment's terminating newline is preserved as a token), and the
  EOF/newline/punctuation tokens. `CasmLexerState`'s enum
  (`CASM_LEXER_STATE_INIT/READY/EOF/ERROR`) was added to `common.inc` — the byte
  WP3 reserved. The lexer owns lookahead invalidation after a rewind
  (`lexerInit`), discharging WP6's deferral; a lexer failure never closes the
  source. Provenance subtlety: `sourceGetLocation` returns `$16` at the
  column-255 exhausted latch (correct for byte-only callers but too strict for
  the lexer, which may next get a harmless newline), so `lexerFill` reads the
  exported in-place location fields directly and clamps the latch to
  `CASM_SOURCE_COLUMN_MAX`, leaving real overflow to `sourceNextByte`; no
  source-layer change. WP7 is static-only: no shipped-path caller until WP10 and
  no end-to-end run until WP8 adds identifiers. Completion advanced CASM to
  `0.1.9` (the version was pre-advanced by the multi-digit stage migration).
- WP8 adds identifier, dot-prefixed directive, register, and decimal/hex/binary numeric token scanning to `lexer.s`. Characters are classified using custom ASCII-range helpers. Overlong tokens (exceeding 31 characters) reject with `TOKEN_TOO_LONG` (`$18`). Malformed numeric formats (lone prefixes or invalid suffixes) skip trailing invalid characters and return `MALFORMED_NUMBER` (`$1A`). Single-character registers (A/X/Y) and directives are mapped case-insensitively. Branch range errors are resolved with inverted jump logic. Version stage advanced to `10` (`0.1.10`).
- WP9 defines `mnemonicTable` in `lexer.s` RODATA with exactly 56 three-byte elements (168 bytes total), asserted at build time. The `classifyMnemonic` routine performs case-insensitive linear search on tokens of length exactly 3. Successful matches are emitted as `CASM_TOKEN_MNEMONIC` with the respective 0-55 subtype index. Unmatched identifier tokens fallback to `CASM_TOKEN_IDENTIFIER`. Version stage advanced to `11` (`0.1.11`).
- WP10 integrates the Phase 3 lexer loop (`lexerInit` -> `lexerNext` -> `diagDumpToken`) into `casm.s`, replacing Phase 2's raw byte consumption and mapping contiguous Phase 3 fatal diagnostics `$14-$1B` to user-friendly messages in `diagnostics.s`. The `diagDumpToken` utility formats and prints all token subtypes, indices, text, and starting line/column provenance. Fixes length-checked string comparison in `compareTokenText` to resolve a null-termination BSS collision. Version stage advanced to `12` (`0.1.12`).
- WP2 independently verified all 56 DEBUG mnemonic names and ordering against
  the repository's standard 6502 reference. WP9 will use a CASM-local 168-byte
  mnemonic table with explicit PETSCII bytes and no `???` entry, runtime link,
  shared include, or build coupling to DEBUG. DEBUG parsing, addressing,
  branch, opcode lookup, and direct-write routines are not reused; opcode and
  addressing-table decisions remain Phase 4 work. User completion approval
  advanced CASM from `0.1.3` to `0.1.4`.
- Work Package 1 synchronized the approved contracts and task hierarchy; user
  completion approval advanced the CASM stage version from `0.1.2` to `0.1.3`.

### CASM Phase 5 Expression/Resolver Contract (Phase 0C.3, approved 2026-07-21)

- Grammar is `extraction? primary addend?`, where extraction is `<` or `>`,
  primary is a number or identifier, and addend is `+/-` followed by a number.
  Only symbol-derived primaries accept addends; numeric arithmetic, parentheses,
  unary negation, chaining, symbol-to-symbol arithmetic, and current-PC
  expressions are deferred.
- The bounded result record holds a 16-bit value; resolved, symbol-derived,
  relocatable, and force-absolute-width flags; full/low/high extraction; an
  opaque 16-bit symbol ID; and an addend represented as sign plus unsigned
  16-bit magnitude.
- Unresolved symbols retain resolver identity, relocation class, extraction,
  and addend metadata. They force absolute-width selection so placeholder zero
  cannot destabilize instruction size between passes.
- Resolved arithmetic is checked against `$0000..$FFFF` and never wraps.
  Low-byte extraction is not relocatable; high-byte extraction preserves
  potential relocation classification for Phase 8.
- The resolver owns symbol identity and returns resolved state, optional value,
  and absolute/relocatable class. Phase 5 uses a deterministic fixture boundary;
  Phase 6A owns VMM records, Phase 6B the production resolver/two-pass model,
  and Phase 8 relocation consumption.
- Carry clear means the result record is valid. Carry set means `A` contains a
  stable diagnostic and callers must not consume the record.
- Evaluator routines execute neither `SED` nor `CLD`; every `ADC`/`SBC` path
  establishes carry explicitly. CASM's application-entry decimal-mode
  assumption remains inherited hardening debt rather than a Phase 5 guarantee.
- The evaluator emits no bytes and creates no relocation records. WP20 may pass
  resolved values into existing emission, but unresolved placeholders must not
  be emitted as zero.
- WP17 realizes the ABI as a private nine-byte BSS record with exported
  `exprInit` and `exprGetResult` routines. The record label is not exported and
  the module has no imports, zero-page, RODATA, DATA, resources, or runtime
  consumer. Diagnostics `$24-$27` are reserved but remain unprintable/unraised
  until later packages extend `diagnostics.s` with their message contracts.
- WP18 moves the single numeric implementation and its seven scratch bytes into
  `expr.s` as `exprParseNumeric`, returning X/Y without importing parser state.
  `parser.s` retains only a compatibility wrapper, so existing Phase 4 parser
  and emitter callers remain unchanged until WP20. Addends are parsed as
  sign/magnitude while leaving the NUMBER token current; checked application can
  therefore stamp arithmetic overflow at the magnitude rather than the following
  delimiter. Phase 5 diagnostics `$24-$27` are now printable.
- WP19's evaluator accepts a resolver address in X/Y and invokes it exactly once
  while the IDENTIFIER token is current. The callback receives X/Y pointing to
  a shared five-byte flags/identity/value output view. An indirect-JSR trampoline
  uses a linker-asserted non-page-crossing private pointer. Unresolved values are
  never extracted as placeholder zero: only metadata is classified, with low
  extraction clearing relocatable and high extraction preserving it.
- WP20's parser adapter stamps the expression-start diagnostic location before
  evaluation, copies only RESOLVED values into `CasmParserStmt`, and leaves the
  first delimiter current. Production identifiers deliberately resolve to `$27`
  until Phase 6B; a separate test PRG supplies deterministic symbols without
  adding fixture names or hidden syntax to CASM.
- WP21 closes the parent expression matrix with explicit `+0`, `-$0000`, and
  repeated-extraction cases. Negative zero preserves a negative sign with zero
  magnitude while leaving the resolved value unchanged. Harness tokens use
  distinct columns so diagnostics certify the exact offending token position.
  User-approved Phase 5 completion is CASM `0.1.23` build 1094; Phase 6A remains
  inactive.
- Phase 3 accepts one top-level source file, reuses the managed 256-byte input
  buffer, and bounds physical input and line numbers to checked 16-bit values.
- Source identity begins with file ID zero and the original source filename.
  Lines and columns are one-based; columns are checked 8-bit values.
- CR, LF, and CRLF each normalize to one logical newline, including CRLF split
  across input blocks. Location advances only when that newline is consumed.
- `sourceRewind` closes and reopens the file, then resets byte, newline,
  location, lookahead, EOF, and line-window state. Byte and line APIs cannot be
  mixed without an explicit rewind/reset.
- Logical line payload is limited to 255 bytes. The line convenience API and
  transfer-block use of `CasmIoBuffer` must be explicitly mutually exclusive;
  Phase 3 allocates no second 256-byte buffer.
- Token text is limited to 31 bytes plus a terminator and preserves original
  spelling. Identifier labels remain case-sensitive; mnemonic, directive, and
  register classification is case-insensitive.
- Phase 3 validates decimal, `$` hexadecimal, and `%` binary lexical shape but
  does not convert values. Malformed prefixes and invalid numeric suffixes fail
  as single lexical errors rather than splitting into unrelated tokens.
- Every token records type, subtype, length, file ID, 16-bit starting line,
  one-byte starting column, and bounded original text. Spaces/tabs are skipped;
  comments preserve their terminating logical newline token.
- Phase 4 is the first production output consumer and includes the bounded
  statement parser before opcode selection and numeric static emission.
- VMM storage precedes VMM-backed symbols: Phase 6A provides bounded storage
  and Phase 6B adds the symbol table and deterministic two-pass assembly.

### CASM Phase 6A VMM Storage Contract (Phase 0C.4, frozen 2026-07-21)

CASM-local phase numbering. Distinct from the unrelated, already-completed
top-level "Phase 6A: App Manager" / "Phase 6B: Binary Relocator" entries in
the Current Status table above — always write "CASM Phase 6A" in full in any
record that could be read alongside both namespaces.

- **Allocation identity is exactly `(SegHi, Bank)`.** `vmmAlloc`
  (`src/command64/vmm.asm`) always returns `VmmSegLo = 0`; an allocation's
  base is fully identified by the page index (`VmmSegHi`, 0-255) and bank
  (`VmmBank`, 0-15). `vmmFree`'s actual input is exactly those two bytes, so
  the pre-existing 3-byte `CasmVmmRegistry` record (`flag`/`SegHi`/`Bank`)
  does not need to grow to support real `DOS_FREE_MEM` calls.
- **A single CASM VMM allocation is capped at 65536 bytes (16 pages).**
  `vmmComputeAddress` computes `Address = (Seg << 4) + Off`, where `Seg` is
  fixed at the allocation's base and `Off` (`VmmOffLo/Hi`) is a 16-bit cursor
  CASM supplies per transfer. Since `Off` tops out at 65535, only the first
  64KB of a larger allocation is reachable through a fixed `SegHi`/`Bank`
  pair; storage needs beyond that use additional registry slots (up to
  `CASM_VMM_CAPACITY = 8`, i.e. up to 512KB total), never an `Off` value at
  or beyond the owning allocation's granted size.
- **The OS performs no bounds checking on `DOS_VMM_READ`/`DOS_VMM_WRITE`.**
  `vmmReadBlock`/`vmmWriteBlock` only check `vmmInitialized` before DMA-ing
  the requested byte count; an `offset + count` that runs past an
  allocation's granted pages silently reads or corrupts whatever REU page
  follows. CASM's own windowed transfer wrapper (WP24) must independently
  track each allocation's granted size and refuse any request that would
  exceed it — the OS provides no such protection.
- **`VMM_ERR_INVALID` is ambiguous.** `vmmAlloc` returns it both for
  "VMM not initialized" (no REU detected at boot) and for a zero-paragraph
  request. CASM never issues a zero-paragraph request except as an internal
  bug, so this return code from a CASM-sized allocation is treated as
  VMM-unavailable, not malformed input.
- **REU contents are undefined at boot** (confirmed by the environment
  variable subsystem's prior VMM use, `brain/walkthroughs/2026-05-14-env-var-remediation.md`).
  Phase 6A verification must write a known pattern before ever reading it
  back; no routine may assume implicit zero-fill.
- **REU presence in the supported local test environment predates CASM.**
  `SET`/`PATH` have used the same VMM primitives at runtime since
  2026-05-14; Phase 6A is CASM's first VMM consumer, not the OS's first.
- The MAIN-envelope-size and literal `CASM_DIAG_*` hex-value decisions for
  Phase 6A are deliberately deferred to WP23 (the implementing package),
  matching how Phase 4 WP13 and Phase 5 WP19 set their own MAIN sizes rather
  than an earlier freeze package doing it for them.
- Phase 6A gate: bounded VMM records can be written, read, and replayed
  without depending on source or symbol semantics. Phase 6B (symbol table,
  hashing, two-pass resolution) remains a separately gated, unstarted phase.
- **WP23 implementation (complete).**
  `vmm_store.s` wires `vmmStoreAlloc`/`vmmStoreFree` to `DOS_ALLOC_MEM`/
  `DOS_FREE_MEM`. No 16-bit byte count can ever require more than 4,096
  paragraphs (= the 65536-byte cap) after rounding, so there is no separate
  "too large" rejection path (`CASM_DIAG_VMM_ALLOC_TOO_LARGE`, proposed in
  the WP23 plan, was dropped as unreachable); the carry out of the rounding
  add is used only to clamp the one wraparound-prone input range (byte counts
  65,521-65,535) to the proven-exact 4,096 paragraphs. A zero-byte-count
  request is rejected locally before any OS call, which is what keeps a
  later `VMM_ERR_INVALID` unambiguous. Diagnostics `$28`-`$2B` are reserved
  (`CASM_DIAG_VMM_UNAVAILABLE`/`_ALLOC_FAILED`/`_FREE_FAILED`/
  `_TRANSFER_FAILED`, the last raised only by WP24). Measured MAIN usage
  (10,647/10,752 bytes) fits the existing `$2A00` envelope with 105 bytes
  free — no size change, unlike the WP13/WP19 precedent of needing one.
- **WP24 implementation (complete).** Closed the gap
  above: grew `CASM_VMM_REC_SIZE` from 3 to 4 bytes
  (`CASM_VMM_REC_PAGES` added), computed by `vmmStoreAlloc` identically to
  `vmmAlloc`'s own paragraph-to-page rounding, with `resourceRegisterVmm`
  remaining the registry's sole writer. Added `vmmWindowRead`/
  `vmmWindowWrite`/`vmmReplay` in `vmm_store.s`, bounds-checking slot range,
  the fixed 32-byte `CasmVmmBuffer`'s capacity, slot ownership, `offset +
  count` overflow, and the transfer's required page count against the
  slot's granted `CASM_VMM_REC_PAGES` — all before any `DOS_VMM_READ`/
  `DOS_VMM_WRITE` call, via a shared private `vwPrepareTransfer`. The
  page-count comparison avoids ever representing 65536 as a 16-bit value
  (same hazard as `vmmStoreAlloc`'s rounding): `NeededPages = ceil((offset+
  count)/4096)` is a top-nibble extraction plus a round-up check, never an
  addition that could itself overflow. No new zero-page byte: reused the
  already-reserved `$78-$7F` I/O/VMM scratch. Measured MAIN usage
  (10,875/11,008 bytes at the approved `$2B00`, up from `$2A00`) with 133
  bytes free.
- **WP25 verification (pending completion approval): first real run found
  three defects.** WP23/WP24's code had never actually executed before
  WP25's `test_casm_vmm` fixture harness ran it for the first time. Found:
  (1) a test-side wrong diagnostic expectation in `vmmalloc3` (expected
  `CASM_DIAG_REGISTRY_FULL`; `vmmStoreAlloc` actually returns
  `CASM_DIAG_VMM_ALLOC_FAILED` for a full registry, per its own WP23 ABI),
  which left the free loop unreached and cascaded into 5 more fixture
  failures; (2) `vwPrepareTransfer` incorrectly rejected the valid
  exact-65536-byte boundary case (offset+count landing exactly on the cap
  wraps the 16-bit add to zero with carry set, indistinguishable from a
  genuine overflow by carry alone — fixed by checking whether the wrapped
  remainder is zero); (3) `vmmReplay` stashed its slot in `CasmValue0Lo`,
  which `vwPrepareTransfer` (called by both of `vmmReplay`'s internal
  calls) also uses as its own offset+count scratch — the same class of
  shared zero-page clobber bug WP23 already caught twice
  (`vmmStoreFree`, `resourcesCleanup`'s VMM loop), fixed by moving the
  stash to `CasmValue1Lo`. All three fixed with explicit user approval to
  fix in place rather than opening a separate remediation plan. All 7
  automated fixtures (`vmmalloc1-3`, `vmmreplay1`, `vmmoffset1`,
  `vmmbounds1`, `vmmfree1`) pass; `vmmalloc4`/`vmmnoreu` are manually
  deferred (CASM's 512KB registry cap can never mark the OS's 16MB-tracked
  MCT full through normal calls; the harness has no per-run REU toggle).

### CASM Phase 6B Symbol Table and Two-Pass Contract (Phase 0C.5, frozen 2026-07-22)

CASM-local phase numbering. Distinct from the unrelated, already-completed
top-level "Phase 6A: App Manager" / "Phase 6B: Binary Relocator" entries in
the Current Status table above — always write "CASM Phase 6B" in full in any
record that could be read alongside both namespaces.

- **Pass-mode threading is a single flag gated at exactly one point.**
  `CasmPassMode` (new BSS byte in `emit.s`, not zero page — the `$70-$8F`
  budget is already fully committed) takes `CASM_PASS_MODE_MEASURE` (`$00`)
  or `CASM_PASS_MODE_EMIT` (`$01`). `emitRawByte` is the sole routine that
  touches `CasmEmitBuffer`/`fileWrite`, so one check at its top is sufficient:
  MEASURE mode returns success without writing. `emitByte`'s `CasmPc` advance
  and overflow checks live above that call and still run unconditionally
  in both modes, and `emitFinalize`/`emitFlush` need no change since
  `CasmEmitLen` never increments in MEASURE mode. `casm.s` factors its
  existing per-statement dispatch (parse -> classify -> match/emit) so two
  driven passes share it: Pass 1 runs MEASURE to `EOF` inserting labels and
  creating no output file; Pass 2 calls `sourceRewind`/`lexerInit` again,
  switches to EMIT, and re-drives the same dispatch for real. `parser.s` and
  `opcodes.s` need no pass-mode awareness except `parserParseExpressionValue`,
  which must consult `CasmPassMode` to decide whether an unresolved symbol is
  acceptable (Pass 1, placeholder `$0000`, never emitted) or fatal (Pass 2,
  `CASM_DIAG_UNDEFINED_SYMBOL`). This is not an event bus for a future
  listing consumer — that is explicitly deferred to Phase 10.
- **The resolver callback stays pass-agnostic.** `exprEvaluate` already sets
  `CASM_EXPR_FLAG_FORCE_ABS` automatically whenever the resolver reports
  `RESOLVED` clear — pre-existing Phase 5 behavior, not a Phase 6B addition.
  The Phase 6B resolver (`symbolsLookup`, bound in place of
  `parserRejectIdentifier`) only needs to report "found and defined" or
  "not found" identically in both passes; only
  `parserParseExpressionValue`'s `pevUnresolved` branch becomes
  pass-mode-aware.
- **`CasmParserStmt` grows from 6 to 7 bytes.** A new
  `CASM_PARSER_STMT_FLAGS` byte (offset 6, bit 0 =
  `CASM_PARSER_STMT_FORCE_ABS`) is added; `CASM_PARSER_STMT_SIZE`'s assert
  updates to 7. Exactly three existing wholesale-write sites in `parser.s`
  must each initialize the new byte explicitly, or it is live uninitialized
  BSS the first time it is read: `ppsEmpty` (the NEWLINE/EOF empty
  statement, sets `Flags = 0`), `ppsMnemonic` (sets `Flags = 0` before
  dispatching into the operand grammar), and `parserParseExpressionValue`
  (the production write site, copies `CASM_EXPR_FLAG_FORCE_ABS` from the
  Phase 5 result in the same branch that already copies `ValLo`/`ValHi`);
  the new label-statement write site (below) also zeroes `Flags` as part of
  its own wholesale initialization. `opcodesFindOpcode` checks this flag
  before its zero-page-shrink heuristic and takes the absolute path
  unconditionally when set, regardless of `ValHi`.
- **Symbol records are 64-byte VMM-backed entries** (amended by WP27 from
  WP26's original 37-byte figure, discovered unable to pass through Phase
  6A's existing 32-byte `CasmVmmBuffer` transfer window at all): 1-byte
  NameLen (offset 0), 31-byte fixed Name slot (offset 1), 2-byte Value
  (offset 32, address assigned in Pass 1), 1-byte Flags (offset 34, bit 0 =
  DEFINED), 2-byte Next (offset 35, 16-bit collision-chain record index,
  `$FFFF` = end of chain), and 27 bytes of reserved padding (offset 37-63,
  explicitly zero-filled on every write). `CASM_SYMBOL_REC_SIZE = 64`;
  capacity is capped at `CASM_SYMBOL_MAX = 512` records (512 * 64 = 32,768
  bytes total, one `vmmStoreAlloc` call, well under the existing
  65536-byte single-allocation cap — no change to `vmm_store.s`'s ABI beyond
  the buffer widening noted below). Record-index-to-VMM-offset arithmetic is
  a single unrolled 16-bit left-shift-by-6 (`recordIndex << 6`), replacing
  what the original 37-byte figure would have required (a 3-term
  shift-add multiply-by-37) with cheaper code executed on every symbol
  lookup and insert. Hashing is a rotate-left-1-XOR fold over the
  identifier's exact case-sensitive bytes, masked to 7 bits across 128
  buckets (`CasmSymbolBuckets: .res 256`, `$FFFF` = empty), chosen over a
  plain byte-sum because it spreads prefix-sharing names (`LOOP1`/`LOOP2`)
  across buckets rather than collapsing them onto adjacent ones. Records are
  append-only (`CasmSymbolCount` is a bump allocator, never a free list) —
  Phase 6B never removes a symbol mid-run.
- **`CASM_VMM_BUFFER_SIZE` (Phase 6A/WP24) amended from 32 to 64 bytes**
  as part of this same WP27 fix — a deliberate, tracked amendment to an
  already-shipped Phase 6A constant, not an oversight. `CasmVmmBuffer`'s
  size follows the constant automatically; `vwPrepareTransfer`'s bounds
  check needed no logic change, only the constant.
- **Label definitions are their own complete, colon-terminated statement,**
  not combined with a trailing instruction in one parse call. A first-draft
  design assuming the latter was found to be broken: `CasmTokenText` is a
  single transient buffer `lexerNext` overwrites unconditionally on every
  call, so a second `lexerNext` to check for a trailing instruction would
  destroy the label's name before any caller could read it back out.
  Instead, the label's name and length are copied into new persistent
  `CasmLabelName`/`CasmLabelNameLen` cells before any further token is read
  — mirroring the existing `CasmStmtLoc*` precedent of keeping new state
  parallel to `CasmParserStmt` rather than growing it further. The driver
  calls `parserParseStatement` again for whatever follows on the same
  physical line. Label insertion (`symbolsInsert` with the current `CasmPc`)
  happens only in the pass-orchestration driver during
  `CASM_PASS_MODE_MEASURE`, never inside `parser.s`, which gains no import
  of `CasmPc` or `symbolsInsert` and stays a pure grammar module.
- **New diagnostics `$2C`-`$2F`, contiguous after Phase 6A's
  `CASM_DIAG_PHASE6A_LAST = $2B`:** `CASM_DIAG_DUPLICATE_SYMBOL` (`$2C`),
  `CASM_DIAG_UNDEFINED_SYMBOL` (`$2D`), `CASM_DIAG_SYMBOL_TABLE_FULL`
  (`$2E`), `CASM_DIAG_PASS_MISMATCH` (`$2F`, `CASM_DIAG_PHASE6B_LAST` — a
  terminal internal error routed through the existing `exitFatal` path,
  never a recoverable diagnostic).
- MAIN envelope growth is flagged as near-certain — Phase 6B adds a symbol
  table, a 256-byte hash-bucket array, two-pass orchestration in `casm.s`,
  and label-statement parsing, all substantially larger in scope than Phase
  6A — but is deliberately not pre-sized here: each implementing WP (WP27
  for the bucket array and storage, WP28/WP29 for pass orchestration)
  measures its own overflow and proposes its own justified size, per the
  WP13/WP19/WP23/WP24 precedent this contract does not break.
- Phase 6B gate: static programs with forward and backward references match
  trusted reference binaries byte for byte.
- **WP26 is a documentation/task-tracking work package only.** No
  symbol-table or pass source exists yet; the only source change is a
  version-only completion increment. WP27 (symbol storage) is separately
  gated and requires its own approved plan before implementation begins.

### CASM Phase 6B WP28 Pass 1 Measure Engine (Phase 0C.6, frozen 2026-07-23)

Amends Phase 0C.5 above with as-built corrections found during WP28's actual
implementation and VICE verification, not a restatement of the whole prior
contract. `feature/casm-phase6-wp28`, CASM `0.1.30` build `1123`.

- **`CASM_PARSER_STMT_FORCE_ABS` derives from `CASM_EXPR_FLAG_SYMBOL_DERIVED`,
  never from `CASM_EXPR_FLAG_FORCE_ABS`.** Phase 0C.5's resolver description
  above ("`exprEvaluate` already sets `CASM_EXPR_FLAG_FORCE_ABS`
  automatically whenever the resolver reports `RESOLVED` clear") is correct
  Phase 5 behavior but is the wrong signal for this flag: `FORCE_ABS` is only
  set when the symbol is *unresolved*, so deriving `CASM_PARSER_STMT_FORCE_ABS`
  from it would force absolute width for forward references only, and let an
  already-*resolved* backward reference fall through to the zero-page-shrink
  heuristic in Pass 1 — the exact Pass1/Pass2 size disagreement this whole
  flag exists to prevent, since Pass 2 re-resolves the same symbol as
  resolved from the very first statement. `CASM_EXPR_FLAG_SYMBOL_DERIVED` is
  set on *any* resolver success (resolved or not) and is the correct signal:
  once an operand's value came from a symbol at all, both passes must commit
  to the same (absolute) width regardless of resolution state. Caught during
  WP28 planning, before implementation.
- **`emitRawByte`'s pass-mode gate must stash the byte before checking
  `CasmPassMode`**, not check the mode first and then reload — a first-draft
  instruction ordering would have clobbered the byte-to-emit with
  `CasmPassMode`'s own value before storing it. Caught by the implementing
  subagent before any test ran.
- **`callResolver` (`expr.s`) clobbers `A` in its own return-address-push
  preamble.** Any value staged in `A` before calling it (e.g. the identifier's
  name length, passed to the resolver ABI) must be stashed across the call
  (`CasmExprScratch0` here) and reloaded after `callResolver`'s `PHA`
  sequence, not assumed to survive it.
- **Label-name comparisons must never go through ca65's default `-t c64`
  quoted-string-literal charmap.** `ca65 -t c64` shifts uppercase ASCII
  letters in `.byte "STRING"` literals by `+$80` into PETSCII's shifted range
  (`"LOOP"` assembles to `$CC,$CF,$CF,$D0`, not `$4C,$4F,$4F,$50`), but the
  lexer's raw source-byte stream (via `cc1541 -w`-written fixture content) is
  never converted — `cc1541 -w` is a zero-conversion passthrough. Any
  hand-written comparison string that must byte-match lexer-read identifier
  text (as `test_casm_pass1.s`'s `nameLOOP`/`nameDATA`/`nameVALS` do, against
  `symbolsLookup`) must be declared as explicit unshifted `.byte $XX, ...` hex
  values, never a quoted string literal. This does not contradict
  `mnemonicTable`/`dirOrgStr`-style directive/mnemonic keyword tables in
  `lexer.s` itself, which also use quoted literals: those compare through
  `compareTokenText`, which calls `normalizeChar` on both sides first,
  absorbing the shift. Fixture *filenames* (`p1size1Name`, etc.) are also
  unaffected for a different reason — `cc1541 -f` encodes disk directory
  names with the same shifted convention ca65 applies, so both sides of
  `sourceOpen`'s filename comparison already agree.
- **The lexer's `isIdFirst`/`isIdCont` never accept lowercase ASCII.**
  Identifier and directive-name characters must be unshifted uppercase
  (`$41`-`$5A`) or shifted PETSCII (`$C1`-`$DA`) — lowercase ASCII
  (`$61`-`$7A`) falls through to `CASM_DIAG_INVALID_SOURCE_BYTE`. A
  CMake-generated test fixture that writes `.byte`/`.word` in lowercase (every
  other fixture and the production directive tables use uppercase
  `.BYTE`/`.WORD`) will fail this way; the failing byte and its 1-indexed
  source line are readable post-failure via `CasmDiagLocByte`/
  `CasmDiagLocLineLo`/`CasmDiagLocLineHi` (`diagnostics.s`), which is how this
  was root-caused rather than guessed.
- **`test_casm_pass1`** (`tests/src/casm_pass1/`) is the new WP28 harness:
  7 fixtures (`p1label1`, `p1labelinsn1`, `p1fwd1`, `p1back1`, `p1undef1`,
  `p1dup1`, `p1size1`) covering label-only, label+mnemonic-same-line, forward
  reference, backward reference, undefined-symbol Pass-1 tolerance, duplicate
  detection, and a combined label/forward-ref/`.BYTE`/`.WORD` fixture. Each
  fixture calls `symbolsInit` fresh (an isolated symbol table per fixture,
  not one shared table) so cross-fixture `LOOP` reuse cannot collide.
- MAIN envelope grown `$2F00` → `$3000` for WP28 (23-byte measured overflow).

### CASM Phase 6B WP29 Pass 2 Resolution and Emission (Phase 0C.7, frozen 2026-07-23)

Amends Phase 0C.5/0C.6 above with as-built corrections from WP29's actual
implementation, not a restatement of the prior contract.
`feature/casm-phase6-wp29`, CASM `0.1.30` build 1125 baseline.

- **`casm.s`'s `start` is now a real two-pass orchestrator sharing one
  private dispatch, `casmRunPass`.** Pass 1 runs `sourceOpen`/`lexerInit`/
  `symbolsInit`/`emitInit` with `CasmPassMode = CASM_PASS_MODE_MEASURE` and
  creates no output file; on success, Pass 2 calls `sourceRewind`/
  `lexerInit` again, `fileCreateOutput` (moved here from before Pass 1),
  `emitInit`, sets `CasmPassMode = CASM_PASS_MODE_EMIT`, and re-drives the
  identical `casmRunPass` dispatch for real. `casmRunPass` itself only
  branches on `CasmPassMode` for the label-statement case
  (`CASM_TOKEN_IDENTIFIER`): `MEASURE` calls `symbolsInsert`, `EMIT` does
  nothing (the label was already defined in Pass 1). Every other statement
  type (`MNEMONIC`/`DIRECTIVE`) was already fully pass-transparent from
  WP28's own work (`emitRawByte`'s single gate, `parserParseExpressionValue`'s
  pass-mode-aware resolver handling) — no `symbols.s`/`parser.s`/`opcodes.s`/
  `emit.s` changes were needed for WP29 at all.
- **A real ca65 branch-range defect surfaced during the rewrite, not
  anticipated by the plan.** Adding the Pass 1/Pass 2 body and the
  `casmRunPass` routine between the early init-failure checks and the
  original single `startFatal` tail pushed three `bcs` branches past the
  ±127-byte relative-branch range. Fixed with two near trampolines rather
  than one: `startInitFatal` (kept immediately after the init-only checks
  it serves — `resourcesInit` through the initial `lexerInit`) and a new
  `startFatalNear` (placed immediately after the Pass 1/Pass 2 body, before
  `casmRunPass`, serving every failure branch inside that body). Both do a
  plain `jmp startFatal`, which has no range limit. This is the same class
  of fix `source.s`'s WP15 comment and WP28's `p1size1` cleanup already
  document for this codebase — flagged here so a future WP expanding
  `casm.s` further expects to re-hit it.
- **Three already-hand-verified WP28 fixtures (`p1fwd1`, `p1back1`,
  `p1size1`) were reused directly as WP29's trusted-reference source, per
  user decision** — no new `.seq` fixtures were authored. Their real-emission
  byte derivations are recorded in each `tests/fixtures/casm/*.ref.hex`
  manifest's own header comment. `p1undef1` (also reused, unmodified) is
  WP29's one end-to-end "real `casm.s` fails cleanly on Pass 2 undefined
  symbol" fixture; the full duplicate/case-sensitivity/table-full
  error-fixture matrix through production `casm.s` remains WP31's scope.
- **Relative-branch displacement computation needed zero code changes.**
  `emitInstruction`'s `eiRelative` path already computed displacement purely
  from `CasmParserStmt.VAL_LO/VAL_HI` against `CasmPc`, with no dependency on
  whether that value came from a literal or a resolved symbol expression —
  confirmed by direct inspection during WP29 planning, not assumed. WP30's
  remaining scope is range-check verification and Pass 1/Pass 2 disagreement
  detection (`CASM_DIAG_PASS_MISMATCH`), not further branch-displacement
  plumbing.
- **The master plan and `AGENTS.md` previously described a structured
  "Pass 2 emission events" design (2026-07-16) that WP26 had already
  overridden (2026-07-22) without updating either document.** WP29 corrected
  both to state the frozen single-`CasmPassMode`-flag design, cross-
  referencing WP26's plan as the decision record.
- MAIN measured directly via `ld65 -m` after the rewrite: CODE `$2070`
  (8304) + RODATA `$090C` (2316) + BSS `$05ED` (1517) = 12137 of 12288
  bytes — **151 bytes headroom, no MAIN size increase needed** (down from
  WP28's 233-byte headroom; the ~82-byte growth is `casmRunPass` plus the
  new imports, in line with the "modest, no new module" prediction).
- Regression floor: the five pre-existing Phase 4/5 trusted references
  (`casmemit1`, `casmhello`, `casmmodes`, `casmnum2`, `casmexprn`, none using
  a label) still match byte-for-byte after the two-pass rewrite, confirming
  the control-flow change altered no observable output for non-symbol
  programs.

### CASM Phase 6B WP30 Branches and Disagreement Detection (Phase 0C.8, frozen 2026-07-23)

Amends Phase 0C.5-0C.7 above with as-built corrections from WP30's actual
implementation and VICE verification. `feature/casm-phase6-wp30`, CASM
`0.1.32` build 1130.

- **Relative-branch addressing-mode selection needed no code change.**
  `opcodesFindOpcode` resolves any branch mnemonic to `CASM_MODE_RELATIVE`
  before it ever reaches the zero-page/absolute decision that consults
  `CASM_PARSER_STMT_FORCE_ABS` — confirmed by direct inspection specifically
  for this plan, not carried forward unverified from WP29's note.
- **A real, previously-latent defect: `eiRelative` computed the branch range
  check even in `CASM_PASS_MODE_MEASURE`, using the resolver's `$0000`
  placeholder for a still-unresolved forward reference.** This produced a
  spurious `CASM_DIAG_BRANCH_OUT_OF_RANGE` in Pass 1 regardless of the real,
  in-range Pass 2 distance — exposed by `brfwd1` (`.ORG $C000` / `BNE LOOP`
  / `NOP` / `NOP` / `LOOP: RTS`, LOOP resolving to `$C004`, displacement
  `+2`), the first fixture ever to use a label as a branch target. Latent
  since Phase 4 (`eiRelative` predates Phase 6B); `brback1` (backward
  reference) never triggered it since its label is already resolved before
  the branch is parsed, and `brrng1` (deliberately out-of-range) "passed"
  before the fix only coincidentally — the *right* diagnostic for the
  *wrong* reason (Pass 1's spurious error, not Pass 2's real one). **Fixed**
  by adding a `CasmPassMode` check to `eiRelative`: `MEASURE` mode skips the
  range check entirely (the operand byte's value doesn't matter either,
  since `emitRawByte`'s single gate never writes it) and falls through
  directly to the existing `emitByte` call; `EMIT` mode enforces the range
  exactly as before. Mirrors the same tolerate-in-MEASURE/enforce-in-EMIT
  pattern already established for `CASM_DIAG_UNDEFINED_SYMBOL`
  (`parser.s`'s `pevUnresolved`). Surfaced to the user with the exact root
  cause and proposed fix before any source was touched, since it was not in
  the approved plan's scope — a real material deviation, not a planned
  change.
- **A genuine Pass 1/Pass 2 disagreement is believed unreachable through any
  legitimate CASM source today.** `CASM_PARSER_STMT_FORCE_ABS` derives from
  `CASM_EXPR_FLAG_SYMBOL_DERIVED`, set identically in both passes regardless
  of resolution (`symbolsLookup` never returns `C` set for "not found");
  branch mnemonics never consult `FORCE_ABS` at all (item 1 above). No
  combination of forward/backward reference or branch/non-branch operand
  can currently produce a different size in Pass 2 than Pass 1.
  `CASM_DIAG_PASS_MISMATCH` is implemented as a defensive internal
  invariant against future defects (e.g., a later phase's macro/include
  expansion breaking this determinism), not a demonstrated user-reachable
  path — matching the master plan's own hedged wording ("if one can be
  triggered deterministically").
- **The disagreement check lives in `emit.s`, not `casm.s`, specifically so
  it can be unit-tested.** `casm.s`'s own `HEADER`/entry point can never be
  linked by a standalone test harness (every existing harness excludes it
  for exactly this reason), so `CasmPass1FinalPc` (2-byte BSS) and
  `emitCheckPassAgreement` (compares `CasmPc` against it; `C` clear on
  match, `C` set + `CASM_DIAG_PASS_MISMATCH` on mismatch, clearing any stale
  diagnostic location first) are exported from `emit.s`, which already owns
  `CasmPc`. `casm.s` only calls it at the two right points (snapshot after
  Pass 1, check after Pass 2) and owns no comparison logic itself. A new
  standalone `test_casm_passcheck` harness pokes both cells directly
  (no real two-pass assembly) and proves both directions — the only
  positive proof of the fatal path, since no real fixture can reach it.
- **New fixtures close the "no fixture has ever used a label as a branch
  target" gap:** `brfwd1`/`brback1` (byte-exact trusted references, forward
  and backward) and `brrng1` (reuses Phase 4's exact `casmbrp2` boundary —
  displacement `+128`, one past the `+127` maximum — with a label operand
  instead of a literal).
- MAIN measured directly via `ld65 -m` after both fixes: CODE `$20A4`
  (8356) + RODATA `$090C` (2316) + BSS `$05EF` (1519) = 12191 of 12288
  bytes — **97 bytes headroom, no MAIN size increase needed** (down from
  107 bytes measured after the disagreement-check wiring alone, before the
  `eiRelative` fix and its own branch-range trampoline added the remaining
  10 bytes; down from WP29's 151-byte close overall).

### CASM Phase 6B WP31 Verification and Completion (Phase 0C.9, 2026-07-23) — Phase 6B Complete

Closes the CASM Phase 6B milestone. Proved the last unchecked acceptance
item — "duplicate, undefined, case-sensitive, and max-length behavior match
the frozen contract" — through real production `casm.s` for the first time
(WP27/28 had only proven it at the isolated `symbolsInsert`/`symbolsLookup`
or standalone-harness level). `feature/casm-phase6-wp31`, CASM `0.1.33`
build 1131.

- **A raw `.seq` fixture cannot rely on ca65's charmap the way a
  ca65-assembled `.s` test harness can.** WP27's `symcase1` fixture (`.byte
  "Case"` / `.byte "CASE"`) works because ca65's `-t c64` charmap converts
  quoted string literals automatically (empirically confirmed: uppercase
  source letters shift to `$C1-$DA`, lowercase source letters map to
  unshifted `$41-$5A`). `.seq` fixtures are raw text written directly by
  `cmake/GenerateCasmTestFixtures.cmake`'s `file(WRITE ...)` and read
  byte-for-byte by CASM's own lexer at runtime — no charmap ever touches
  them. `isIdFirst`/`isIdCont` (`lexer.s`) accept only unshifted (`$41-$5A`)
  or shifted (`$C1-$DA`) PETSCII as identifier bytes; plain ASCII lowercase
  (`$61-$7A`) is rejected as `CASM_DIAG_INVALID_SOURCE_BYTE`. A naive
  mixed-case-ASCII `.seq` fixture would therefore test nothing — it fails
  immediately on the first lowercase byte. **`casmcase1.seq`** instead
  builds its second label directly from shifted-PETSCII bytes via
  `string(ASCII 204/207/207/208 ...)` (unshifted `L`/`O`/`P` = `$4C`/`$4F`/
  `$50`; `+$80` = `$CC`/`$CF`/`$D0`), giving two genuinely different,
  lexer-valid byte sequences for "the same" name (`LOOP` unshifted vs. the
  shifted-byte-sequence variant), each resolving to a distinct address.
- **`casmmaxid1.seq`** proves the 31-byte maximum identifier
  (`CASM_TOKEN_TEXT_MAX`) round-trips through real Pass 1/Pass 2, built via
  `string(REPEAT "A" 31 ...)` (no special byte construction needed —
  unshifted uppercase is numerically identical to plain ASCII).
- **Duplicate-symbol and undefined-symbol through real `casm.s` needed no
  new fixtures** — `p1dup1.seq` (WP28) and `p1undef1.seq` (WP29 origin,
  already proven through production `casm.s`) were reused directly.
- **Symbol-table-full was deliberately not repeated as a new end-to-end
  fixture**, per user decision: neither the master plan's fixture list nor
  the acceptance checklist names it, and the same `casmRunPass` ->
  `startFatalNear` propagation path a table-full failure would take is
  already proven by the duplicate-symbol fixture.
- **Regression against the 60 pre-existing Phase 3/4 fixtures used a
  7-fixture targeted sample, not an exhaustive re-run**, per user decision:
  WP30's `eiRelative` defect was narrowly specific to a live-counter
  *difference* check (unique to relative-branch displacement); no other
  Phase 4 diagnostic shares that shape (e.g. `.BYTE`/`.WORD`'s range check
  tests the placeholder directly and can only under-, never over-report).
  `casmwp11`, `casmzp1`, `casmcma2`, `casmorg3`, `casmzpi2`, `casmpcovf`,
  `casmnumerrh` all passed unchanged against the two-pass `casm.s`.
- **No production source changed.** Unlike WP30, this WP's new fixture
  categories found no latent defect — every case passed on the first VICE
  run.
- **Phase 6B Acceptance (`wiki/tasks/casm.md`) is now fully checked; the
  CASM Phase 6B milestone is complete.** CASM Phase 7 (VMM-backed source,
  multiple top-level inputs) and Phase 8 (R6 relocation consumption) remain
  separately gated and unstarted, per the master plan's own sequencing.

### CASM Phase 7 WP32 VMM-Backed Source and Multi-File Contract (Phase 0C.10, frozen 2026-07-23)

Freezes the contract WP33-WP36 implement against, per
`brain/plans/2026-07-23-casm-phase7-wp32-prerequisite-reconciliation.md`.
WP32 itself implements no runtime behavior — version-only completion
increment.

- **The master plan's stated Phase 7 rationale is stale and was corrected,
  not implemented as written.** "Sources larger than the RAM window" and
  "byte-at-a-time OS calls" do not describe a real problem: `source.s`'s
  `sourceFetchPhysical`/`sourceRefill` already stream any file size in
  bounded 256-byte OS blocks. The only confirmed hard gap is CLI-level:
  `cli.s`'s `cliCopySource` hard-rejects a second positional source token
  (`CASM_DIAG_EXTRA_SOURCE`) — Phase 2's deliberate, documented single-file
  scope, not a defect.
- **User-confirmed decision: CASM still adopts a VMM-cached source model**,
  despite the original rationale being stale, for its real remaining
  benefit — today's `sourceRewind` closes and reopens the file, forcing a
  second full physical disk read every Pass 2; a VMM cache loaded once
  before Pass 1 makes Pass 2's rewind a pure VMM-offset reset with no OS
  calls, and gives multiple files one uniform replayable stream (also the
  natural foundation for Phase 9's include processing).
- **One pre-pass load stage** (new, runs after CLI parsing and before Pass
  1) opens each of `CasmSourceCount` (1..8) `CasmSourceNames` entries in
  order, streams each through the existing `fileRead` in 256-byte blocks,
  and `vmmWindowWrite`s each block into one VMM allocation at a running
  combined offset, recording each file's `{VmmOffset, VmmLength}` span in a
  new 8-entry `CasmSourceFileTable` (32 bytes, base RAM). A synthetic LF
  byte is written between files whose preceding file didn't already end in
  a newline — an ordinary stream byte needing no special read-time
  handling.
- **Combined multi-file source content is capped at 65535 bytes total**,
  not 65536: `vmmStoreAlloc` cannot actually request 65536 bytes (it wraps
  to `$0000` in the 16-bit `X/Y` count, indistinguishable from an explicit
  zero-size rejection). This generalizes, rather than tightens, the
  existing single-file 65535-byte limit (`CasmInputTotalLo/Hi` in
  `fileio.s` already overflows there today).
- **`CASM_VMM_BUFFER_SIZE` (64 bytes) cannot grow to match `CasmIoBuffer`
  (256 bytes)** without breaking the WP27 symbol-record contract
  (`CASM_VMM_BUFFER_SIZE = CASM_SYMBOL_REC_SIZE`, and
  `CASM_SYMBOL_MAX * CASM_SYMBOL_REC_SIZE <= CASM_VMM_ALLOC_MAX_BYTES` would
  break if the record size grew to match). VMM-backed refill therefore
  fills the existing 256-byte `CasmIoBuffer` window through up to four
  sequential 64-byte `vmmWindowRead` calls, leaving `CasmIoBuffer`'s size,
  `sourceNextLine`'s LINE-mode payload logic, and every downstream
  byte-classification/newline-normalization routine unchanged.
- **`CasmSourceNames` grows from one 64-byte buffer to an 8-slot x 64-byte
  array** (user-confirmed capacity, matching this codebase's existing
  `CASM_FILE_CAPACITY`/`CASM_VMM_CAPACITY = 8` convention). Costs 512 new
  BSS bytes against 97 bytes of current MAIN headroom (12191 of 12288, `ld65
  -m` measured, unchanged since WP31) — a MAIN size bump is a near
  certainty, not sized by WP32.
- **File-identity and per-file line numbering reset at each recorded file
  boundary during refill**: `CasmSourceFileId` (an unused Phase-3
  placeholder until now) increments, `CasmSourceLineLo/Hi` resets to 1, and
  `CasmSourceColumn` resets to 1 when the VMM-backed refill's running read
  offset reaches the next file table entry's start.
- **Diagnostic filename printing is confirmed-conditional on
  `CasmSourceCount > 1`** — the 40-column diagnostic window
  (`CASM_DIAG_WINDOW_WIDTH + CASM_DIAG_INDENT` already fills all 40
  columns) cannot also print a 63-byte filename inline. A single-file
  assembly's diagnostic text is therefore unchanged from today. New
  `CasmStmtLocFileId`/`CasmDiagLocFileId` cells carry the identity to the
  three existing `diagSetLocFrom*` write sites in `diagnostics.s`.
- **No new `CASM_DIAG_*` identifier is expected.** Every Phase 7 failure
  mode reuses an existing diagnostic: combined-size overflow reuses
  `CASM_DIAG_SOURCE_OFFSET_OVERFLOW`; a 9th source token reuses
  `CASM_DIAG_EXTRA_SOURCE`, whose message text ("CASM: TOO MANY SOURCE
  FILES") is already plural and generic; VMM/file failures during the load
  stage reuse the existing `CASM_DIAG_VMM_*`/`CASM_DIAG_INPUT_*` families —
  a contrast with every prior phase (6A added 4 diagnostics, 6B added 4).
- **Proposed WP breakdown** (each separately gated, not authorized by
  WP32): WP33 VMM-backed single-file load and traversal equivalence
  (proven byte-identical against every existing single-file trusted
  reference before the OS-refill path is retired); WP34 multi-file CLI and
  file-boundary provenance; WP35 diagnostic filename integration; WP36
  verification, walkthrough, and Phase 7 completion gate.

### CASM Phase 7 WP33 VMM-Backed Source Load (Phase 0C.11, 2026-07-24)

Amends Phase 0C.10 above with as-built detail from WP33's actual
implementation, per
`brain/plans/2026-07-24-casm-phase7-wp33-vmm-backed-source-load.md`. Final
CASM `0.1.35` build 1137.

- **Scope stayed single-file only, per the user's confirmed decision**:
  `sourceLoad` opens exactly `CasmSourceName`; no `CasmSourceNames` array or
  `CasmSourceFileTable` yet. Building the N-file loop before `CasmSourceNames`
  can ever hold more than one entry would have been untested-by-construction
  complexity, matching the project's repeated precedent against building
  ahead of a real consumer (WP26 deferred "emission events" the same way).
- **`sourceFetchPhysical` needed zero changes.** Confirmed by direct
  tracing: it only ever consults `CasmSourceBlockLenLo/Hi`/
  `CasmSourceBlockIndexLo/Hi` (the block window into `CasmIoBuffer`) and
  `CasmSourceOffsetLo/Hi` (a delivered-byte counter), both meaningful
  identically regardless of whether the block came from disk or VMM. Only
  the private `sourceRefill` plus `sourceOpen`/`sourceRewind`/`sourceClose`
  (and the new `sourceLoad`) touch the OS/VMM boundary.
- **New persistent state lives in `source.s`'s own `.segment "BSS"`**, not
  `state.s`'s frozen Phase 3 subrecords (`CasmSourceVmmSlot`,
  `CasmSourceLoadedLenLo/Hi`, `CasmSourceVmmCursorLo/Hi` -- 5 bytes),
  mirroring WP28's `CasmLabelName` precedent: new state kept parallel to a
  size-asserted shared ABI rather than crammed into it.
- **`CasmSourceVmmCursorLo/Hi` is reused for two different purposes at two
  different times, never simultaneously**: during `sourceLoad` it is the
  next VMM *write* offset; `sourceOpen`/`sourceRewind` reset it to 0 and
  every subsequent `sourceRefill` advances it as the next VMM *read*
  offset. Safe because loading always completes fully before any refill
  begins.
- **`sourceOpen`/`sourceRewind`/`sourceClose` all lost failure paths**, not
  just changed what they call: with no OS call left in any of the three,
  each can only fail on a bad precondition state now.
  `CASM_DIAG_SOURCE_REWIND_FAILED` ($14) became entirely unreachable
  through any code path -- **left declared, not removed or renumbered**,
  since `common.inc`'s diagnostic identifiers are a stable,
  sequentially-asserted-contiguous contract (matches Phase 5/WP17's
  precedent for reserved-but-unraised diagnostics).
  `CASM_DIAG_INPUT_CLOSE_FAILED` stayed reachable but moved call sites,
  from `sourceRewind`/`sourceClose` to `sourceLoad`'s own
  `inputStreamClose` call.
- **Two real defects found through user runtime testing, both only because
  a genuinely new fixture category exercised a code path for the first
  time** -- a recurring pattern now seen at WP25, WP30, and WP33:
  1. **`sourceRefill`'s VMM-read copy omitted the `<CasmIoBuffer` low-byte
     term entirely.** `CasmIoBuffer` links at `$5FDA` -- **not
     page-aligned** (`<CasmIoBuffer = $DA`, not `$00`). The buggy pointer
     computation added only `#>CasmIoBuffer` (the page) to
     `base + chunkDestOffset`, never `#<CasmIoBuffer` (the byte offset
     within that page), so every VMM-backed refill wrote its chunk 218
     bytes before the real buffer, corrupting whatever BSS state happened
     to sit there. This produced two seemingly unrelated symptoms
     depending on which fixture's chunk offsets hit which cell:
     `casmemit1.s` failed with a spurious `CASM: OUTPUT WRITE FAILED` at
     line 9 col 14 plus a real Commodore drive-level `32, SYNTAX ERROR`
     status (consistent with a corrupted output filename reaching
     `DOS_OPEN_FILE`); `casmhello.s` failed with a spurious
     `CASM: DUPLICATE ORG` at line 1 col 1 (consistent with `CasmOrgSet`,
     an `emit.s` BSS cell, getting clobbered). Same defect, different
     collateral damage per file -- not two separate bugs. **Fix**: add the
     missing term as its own correctly-carried addition
     (`clc` / `adc CasmLexerScratch1` / `clc` / `adc #<CasmIoBuffer` --
     the intermediate `clc` matters, since `base + chunkDestOffset` alone
     never carries per its own established bound, but chaining the
     `<CasmIoBuffer` add onto a stale carry from that first add would
     still be wrong), mirroring `sourceLoad`'s already-correct write-side
     pointer computation, which already had the `#<CasmIoBuffer` term.
  2. **`test_casm_pass1` never freed `sourceLoad`'s new per-fixture VMM
     allocation.** The harness calls `symbolsInit` *and* now `sourceLoad`
     once per fixture across 7 fixtures in one continuous process, with no
     explicit cleanup between them (by design, pre-WP33: "7 calls total,
     one per fixture, well within `CASM_VMM_CAPACITY == 8`"). WP33 doubled
     that to 14 allocations needed against 8 slots -- the registry filled
     exactly after 4 fixtures (`....`) and the remaining three
     (`p1undef1`, `p1dup1`, `p1size1`) failed with the registry already
     full (`fff`). **Fix**: `casm_pass1.s`'s main loop now calls
     `resourcesCleanup` after each fixture's `reportCase`, freeing both
     that fixture's symbol-table and source VMM slots before the next
     fixture allocates its own -- steady-state usage is at most 2 slots at
     a time, not 14 accumulated. This is a test-harness-only fix; no
     production `casm.s` behavior is affected (production calls
     `sourceLoad` exactly once per run and relies on the existing generic
     `resourcesCleanup` sweep at `exitSuccess`/`exitFatal`, unchanged).
- **`sourceClose` does not explicitly free `CasmSourceVmmSlot`.** Matches
  the symbol table's own established precedent (WP27's symbol allocation
  is never freed explicitly either) -- both rely on the generic
  `resourcesCleanup` sweep at final exit, not a per-module free.
- MAIN measured via `ld65 -m`: CODE `$21EF` (8687), RODATA `$090C` (2316),
  and BSS `$5F4` (1524) sum to 12527 of 12800 bytes -- **273 bytes
  headroom** (`$3000` -> `$3200`, a 512-byte bump against a 236-byte
  overflow at the old size). `casm_pass1`/`casm_passcheck` (which link
  `source.s` whole) independently bumped `$3200` -> `$3300`.
- **Verification matrix, all passing**: `TEST_CASM_PASS1` (all 7
  sub-fixtures) and `TEST_CASM_PASSCHECK`; all 12 byte-identical trusted
  references (`casmemit1`, `casmhello`, `casmmodes`, `casmnum2`,
  `casmexprn`, `p1fwd1`, `p1back1`, `p1size1`, `brfwd1`, `brback1`,
  `casmcase1`, `casmmaxid1`); all 7 Phase 3 traversal fixtures
  (`casmempty`, `casmshort`, `casm256`, `casmmulti`, `casmcr`, `casmcrlf`,
  `casmsplit`) against hand-derived expected diagnostics (a first real run
  through two-pass `casm.s` for most of these, not a regression
  re-confirmation -- no prior WP ever selected them for its own regression
  sample); both new `casmvmm65`/`casmvmm128` chunk-boundary fixtures.
- **CASM Phase 7 WP33 is complete.** WP34 (multi-file CLI and
  file-boundary provenance) remains separately gated and unstarted.

### CASM Phase 7 WP34 Multi-File CLI and Provenance (Phase 0C.12, 2026-07-24)

Amends Phase 0C.10/0C.11 above with as-built detail from WP34's actual
implementation, per
`brain/plans/2026-07-24-casm-phase7-wp34-multi-file-cli-and-provenance.md`.
Final CASM `0.1.36` build 1139.

- **`CasmSourceFileTable` records only each file's start offset (2
  bytes/entry, 16 bytes total for 8 entries), not a separate length** --
  halved from the informal 4-bytes/entry sketch once tracing showed a
  file's end is implicitly the next file's start, or
  `CasmSourceLoadedLenLo/Hi` (the grand total) for the last file.
- **The combined 65535-byte cap is genuinely not free once more than one
  file exists**, correcting the scope of WP33's own "free" finding (true
  only for exactly one file, since `inputStreamOpen` resets its per-file
  counter for every file it opens). `slCheckCap`
  (`CasmSourceVmmCursorLo/Hi + CasmIoLenLo/Hi` against
  `CASM_SOURCE_VMM_MAX_BYTES`) is a new explicit check, reusing
  `CASM_DIAG_SOURCE_OFFSET_OVERFLOW` -- collapses to a single carry-flag
  test since the cap is exactly the largest 16-bit value (a 16-bit add
  that doesn't carry is always within it; one that does always exceeds
  it).
- **`cliCopySource` writes through a compile-time slot-address lookup
  table (`cliSourceSlotLo/Hi`, exported for `source.s`'s `sourceLoad` to
  reuse), not a runtime multiply** -- `CASM_FILENAME_BUFFER_SIZE` (64)
  does not divide evenly into 256, so `CasmSourceCount * 64` cannot be
  folded into a single indexed-addressing byte the way a power-of-two
  stride could. The indirect write itself needed care: `(zp),Y` requires
  Y as the index, but Y is the established `CommandBuffer` cursor
  throughout `cli.s`'s call chain and cannot double as the destination
  index too -- resolved by advancing the destination pointer itself one
  byte at a time (Y fixed at 0 for each store) rather than indexing it,
  stashing the real Y around each store via `CasmCliDestIndex` (a
  previously-declared but never-used `cli.s` scratch alias).
- **`fileio.s`'s `inputStreamOpen` generalized from a hardcoded single
  `CasmSourceName` pointer to a caller-supplied X/Y pointer**, matching
  `fileOpenInput`'s own convention exactly -- its sole caller,
  `sourceLoad`, already needed to select a different file each loop
  iteration.
- **User-confirmed correctness fix: the pending-CR newline latch clears
  unconditionally at every file-boundary transition**
  (`srCheckFileBoundary`). Without it, a file ending in a bare CR
  immediately followed by a file starting with LF would phantom-collapse
  across the file boundary -- the leading file's blank first line would be
  silently swallowed rather than counted, shifting every subsequent line
  number in that file by one. Proven by a dedicated fixture
  (`casmmfcr1`/`casmmfcr2`) asserting the post-boundary diagnostic reports
  LINE 2, not LINE 1.
- **A single-file assembly (`CasmSourceCount == 1`) takes an identical
  code path to WP33's by construction, not by a separate equivalence
  proof.** `srCheckFileBoundary`'s and `srComputeRemaining`'s new terms are
  both gated on `CasmSourceFileId + 1 < CasmSourceCount`, false on every
  call when there is only one file -- confirmed by every existing
  single-file trusted reference and both standalone harnesses re-passing
  unmodified.
- **`test_casm_pass1`/`test_casm_passcheck` needed their own stand-in
  copies of the new `cli.s`-owned symbols** (`CasmSourceNames`,
  `CasmSourceCount`, `cliSourceSlotLo/Hi`) since neither links `cli.s` --
  caught during implementation, before it became a link failure (or worse,
  a silent behavioral regression) rather than after.
- **The real 65535-byte combined-source cap cannot be exercised with less
  than ~64KB of actual fixture content** (the check is architecturally
  "combined > 65535"), and the shared `test.d64` had no room left for
  fixtures that large alongside every other CASM/OS fixture already
  packaged there. Per the user's confirmed decision, `casmmfovf1.seq`/
  `casmmfovf2.seq` (40000/30000 bytes) get their own dedicated
  `casm_overflow_test_d64` disk image (`casm.prg` + the two fixtures only)
  rather than being dropped from WP34's verification or forcing a redesign
  of `test.d64`'s packaging.
- MAIN bumped `$3200` -> `$3500` (507-byte overflow at the old size).
  `casm_pass1` (`$3300` -> `$3500`) and `casm_passcheck` (`$3200` ->
  `$3500`), both linking `source.s` whole, needed their own independent
  bumps for the same reason.
- **Verification matrix, all passing** (user confirmed "all test pass"
  across two sessions): `TEST_CASM_PASS1` (all 7) and
  `TEST_CASM_PASSCHECK`; all 12 pre-existing byte-identical trusted
  references (confirming the single-file path is unaffected); 3 new
  multi-file byte-identical references (`casmmf1` two-file forward
  reference, `casmmf2` two-file with a required synthetic newline,
  `casmmf3` three-file chained references); the cross-file pending-CR
  fixture; 9th-source-file rejection (`CASM_DIAG_EXTRA_SOURCE`, no new
  fixture needed -- any 9 filename-shaped tokens suffice since parsing
  fails before any file opens); the combined-overflow boundary
  (`CASM_DIAG_SOURCE_OFFSET_OVERFLOW`, no location trailer since it fires
  before any `diagSetLocFrom*` call ever runs).
- `AGENTS.md`'s "Phase 2 accepts one unquoted source filename" contract
  corrected to describe the WP34 multi-file grammar.
- **CASM Phase 7 WP34 is complete.** WP35 (diagnostic filename
  integration) and WP36 (verification/closeout) remain separately gated
  and unstarted.

### CASM Phase 7 WP35 Diagnostic Filename Integration (Phase 0C.13, 2026-07-24)

Amends Phase 0C.10 above with as-built detail from WP35's actual
implementation, per
`brain/plans/2026-07-24-casm-phase7-wp35-diagnostic-filename-integration.md`.
Final CASM `0.1.37` build 1141. Closes the last unchecked item in
`wiki/tasks/casm.md`'s Phase 7 Acceptance list -- all four are now
checked, though Phase 7 itself does not close until WP36's own
consolidated verification.

- **WP32's original rationale for gating filename printing on
  `CasmSourceCount > 1` ("the 40-column diagnostic window is already
  full") described a different print statement than the one this WP
  touches.** `CASM_DIAG_WINDOW_WIDTH`/`CASM_DIAG_INDENT` bound the
  *rendered source line and caret* (`diagPrintLineAndCaret`); the "AT
  LINE n, COL c (OFFSET o)" trailer this WP extends
  (`diagPrintSourceContext`) already has no such budget and already
  silently wraps past 40 columns in its own worst case today (~45
  characters: 5 line digits + 6 + 3 column digits + 10 + 3 offset digits +
  1 + optional 9-character byte suffix). **The real, still-valid reason
  to gate on `CasmSourceCount > 1` is keeping every single-file
  diagnostic's exact printed text byte-identical to every prior phase's**,
  not a column budget -- the gating decision itself was unchanged, only
  its stated justification was corrected, the same class of correction
  WP26/WP33 each made to a stale prior-WP rationale.
- **`CasmDiagState`'s size assert (`state.s`) was grown in place** (530 ->
  532 bytes: `CasmDiagLocFileId` after `CasmDiagLocByte`,
  `CasmStmtLocFileId` after `CasmStmtLocColumn`), not kept in a separate
  external block the way `CasmLabelName` (WP28) and the WP33/34 VMM state
  were. Reasoned explicitly: `CasmDiagState`'s assert is this module's own
  bookkeeping, not a cross-module ABI another file sizes against (unlike
  `CASM_TOKEN_REC_SIZE`), and every field in the block -- old and new --
  has exactly one clear write site, unlike `CasmParserStmt`'s three
  separate wholesale-record writers that motivated keeping
  `CasmLabelName` external in the first place.
- **The filename-pointer lookup needed no new mechanism**: WP34's
  `cliSourceSlotLo`/`cliSourceSlotHi` compile-time table (`cli.s`,
  originally exported for `sourceLoad`'s own reuse) indexes directly by a
  file identifier to a ready-to-print null-terminated pointer --
  `diagPrintSourceContext` imports and indexes the same table by
  `CasmDiagLocFileId`, using the identical
  `ldx / lda,x / pha / lda,x / tay / pla / tax` staging pattern already
  established in `sourceLoad`.
- **Both standalone harnesses that link the real `diagnostics.s`
  (`test_casm_pass1`, `test_casm_passcheck`) needed zero source changes**,
  confirmed by successful build/link rather than assumed: WP34 already
  gave both stand-in copies of `CasmSourceNames`/`CasmSourceCount`/
  `cliSourceSlotLo`/`Hi` (neither links `cli.s`) for `sourceLoad`'s own
  sake, and this WP's new `diagnostics.s` imports resolve against those
  same stand-ins with no further changes.
- **New fixture `casmmfdiag1`/`casmmfdiag2`** (invalid byte in the first
  file, `CasmDiagLocFileId == 0`) complements the existing
  `casmmfcr1`/`casmmfcr2` non-first-file case, proving the filename
  prints correctly for file index 0 too, not just a nonzero index.
- MAIN unaffected: measured via `ld65 -m` at 189 of 13568 bytes headroom
  (CODE `$234E` (9038) + RODATA `$925` (2341) + BSS `$7D0` (2000) = 13379)
  -- no size bump needed, matching the WP's small scope.
- **Verification matrix, all passing** (user confirmed "all test pass"):
  single-file diagnostic text regression (byte-identical to before this
  WP); byte-identical trusted references unaffected; `casmmfcr1`/
  `casmmfcr2` now reports `IN FILE CASMMFCR2.S` before its existing `AT
  LINE 2, COL 1` trailer; `casmmfdiag1`/`casmmfdiag2` reports `IN FILE
  CASMMFDIAG1.S`; both standalone harnesses still pass.
- **CASM Phase 7 WP35 is complete. All four Phase 7 Acceptance items are
  now checked.** WP36 (verification, walkthrough, and Phase 7 completion
  gate) remains separately gated and unstarted.

### CASM Phase 7 WP36 Verification and Closeout (Phase 7 milestone close, 2026-07-24)

Closing note for the Phase 7 arc (Phase 0C.10 through 0C.13 above). WP36
implemented no ABI, storage, or CLI change -- it bundled the full
accumulated WP32-35 fixture/harness matrix into one consolidated
verification run and closed two real gaps a fresh trace found against the
master plan's own Phase 7 gate text before implementation began:

- **No fixture had ever proven a large, under-cap input actually assembles
  successfully.** The master plan's gate text ("small inputs remain
  byte-identical, while large and multiple inputs assemble successfully
  with correct diagnostics") was only half-covered by the four Phase 7
  Acceptance items WP32 derived from it -- none of the four is a large
  input that assembles *successfully*; every existing "large" fixture was
  either invalid syntax (`casm256`/`casmmulti`/`casmvmm65`/`casmvmm128`,
  pure `sourceRefill` traversal proof) or deliberately over the 65535-byte
  cap (`casmmfovf1`/`casmmfovf2`, the failure path). Closed with a new
  fixture pair, `casmbiga.s`/`casmbigb.s` (3000 `NOP` statements each, 6000
  total, spanning `$C000`..`$D747`) and its trusted reference
  `tests/fixtures/casm/casmbig1.ref.hex` (`00 C0` header + `EA` x 6000,
  sha256-checked) -- generated from one reviewed single-opcode repetition
  rule rather than a hand-typed manifest, per the user's confirmed
  verification method (the manifest format has no repeat directive, and
  hand-typing thousands of tokens would not have made the reference more
  trustworthy). File B has no `.ORG`, continuing the combined PC from file
  A -- the same convention `casmmf1`-`casmmf3` established -- so
  `casmbig1` closes both the "large" and "multiple" halves of the gate text
  in one fixture.
- **WP31's targeted 7-fixture Phase 3/4 diagnostic-category regression
  sample had never been re-run since Phase 7 replaced the entire
  source-loading layer those fixtures depend on to reach the lexer/parser
  at all.** WP33's own plan explicitly used a *different* fixture set and
  noted there was no "same as before" baseline to re-confirm at that point;
  WP34 and WP35's verification sections each used their own different,
  narrower samples. Closed by re-running `casmwp11`/`casmzp1`/`casmcma2`/
  `casmorg3`/`casmzpi2`/`casmpcovf`/`casmnumerrh` unmodified as part of this
  WP's consolidated matrix -- all seven reproduced their established WP31
  outcomes exactly, through the fully VMM-backed, multi-file-capable source
  layer.

**A real implementation-time discrepancy surfaced and was corrected with
the user's approval, not silently worked around.** `casmbiga.seq`/
`casmbigb.seq`'s raw source text (12011/12000 bytes -- source text is far
larger than its 1-byte-per-`NOP` assembled output, a distinction the
original plan's sizing didn't weigh against disk capacity) did not fit on
`test.d64` alongside every other CASM/OS fixture: only 110 blocks were free
before the change, 96 were consumed by the new pair, leaving no room for
the trailing `edlinfull` fixture (64 blocks) and failing the build with
"Disk full." Fixed by moving `casmbiga.s`/`casmbigb.s` and `casmbig1`'s
`COMP` verification (plus `comp.prg` itself, needed for that verification)
onto the existing `casm_overflow_test_d64` disk image -- the same dedicated
image `casmmfovf1`/`casmmfovf2` already used for an identical "too large
for test.d64" reason -- rather than inventing a third disk image or
shrinking the fixture to a size too small to meaningfully demonstrate
"large." `casmbig1` stayed in `CASM_REF_NAMES` (so the shared
`hex_manifest_to_bin.py`/`casm_reference_fixtures` machinery builds it
unchanged) but was excluded from the generic `CASM_REF_NAMES` ->
`test.d64` append loop, since its matching `.seq` inputs live only on
`casm_overflow_test_d64`.

No production source defect was found -- unlike WP25/WP30, this WP's new
fixture and the re-run regression sample both passed on the first VICE run.
User ran the full consolidated matrix (5 standalone harnesses -- `TEST_CASM_VMM`,
`TEST_CASM_SYMBOL`, `TEST_CASM_PASS1`, `TEST_CASM_PASSCHECK`,
`TEST_CASM_EXPR` -- 16 byte-identical trusted references including the new
`casmbig1`, 7 diagnostic-fixture scenarios, and the 7-fixture Phase 3/4
regression sample) and confirmed: "all tests pass." Final CASM `0.1.38`
build 1142, no-change rebuild stable, all three disk images (`image_d64`,
`test_image_d64`, `casm_overflow_test_d64`) build clean. MAIN headroom 189
of 13568 bytes, unchanged from WP35's close (WP36 added no production
code).

**CASM Phase 7 WP36 is complete, and with it the CASM Phase 7 milestone
closes.** All five Phase 7 Acceptance items are checked (`wiki/tasks/casm.md`).
CASM Phase 8 (native R6 relocation consumption) remains separately gated
and unstarted, per the master plan's own sequencing -- this closure does
not activate it.

### CASM Phase 8 WP37 Native R6 Relocation Contract (Phase 0C.14, frozen 2026-07-24)

Plan: `brain/plans/2026-07-24-casm-phase8-wp37-prerequisite-reconciliation.md`.
WP37 implemented no ABI, storage, or CLI change -- it verified the Phase 7
completion gate (`0.1.38` build 1142, 189 bytes MAIN headroom), reconciled
the master plan's Phase 8 text against the current source, and froze the
contract WP38-WP42 implement against. Key findings and decisions:

- **The default is inverted today, not merely absent.** `.ORG` is currently
  *required* (`CASM_DIAG_ORG_REQUIRED` fires on any byte-emitting statement
  before it); there is no relocatable output path at all. WP38 must flip
  this: `.ORG` becomes optional and forces static when present; absence
  defaults to relocatable mode at the frozen origin.
- **The relocatable-value ABI already exists end to end from Phase 5/6B
  foresight, with only a producer missing.** `CASM_EXPR_FLAG_RELOCATABLE`
  already flows unchanged from a resolver's output flags into the
  expression result (`expr.s`), is already correctly cleared on `<`
  low-byte extraction and preserved on `>` high-byte extraction and
  `symbol +/- constant` addends -- `symbols.s` just never sets it
  (its own comment: "symbols are always absolute, never RELOCATABLE").
- **No `symbols.s` change is needed to fix that.** Relocatability is a
  property of the whole assembly's output mode, not of any individual
  symbol, since no named-constant symbol kind exists before Phase 12 --
  every definable symbol today is a label (an address). The producer
  belongs in `expr.s`, at the existing resolver-merge point, gated on a
  whole-assembly relocatable-mode flag, keeping `symbols.s` unaware of
  output-mode concepts.
- **`symbol +/- constant` addends are always safely representable** under
  the R6 common-page-delta model by simple associativity of page-aligned
  address arithmetic; the current grammar has no symbol-symbol arithmetic.
  Mirroring WP32's precedent for Phase 7, **no new "unrepresentable
  expression" diagnostic is expected** -- only a relocation-table-capacity
  one. Next free `CASM_DIAG_*` value is `$30`.
- **Four emission sites need the relocation hook, found by tracing every
  `VAL_HI`/extracted-`VAL_LO` write in `emit.s`, not assumed from the
  addressing-mode table:** `emitInstruction`'s shared length-3 branch
  (covers `CASM_MODE_ABSOLUTE`/`_X`/`_Y`/`_INDIRECT` uniformly --
  `opcodes.s`'s `modeLength` table confirms all four are length 3, so one
  hook needs no per-mode branching); `emitWordList`'s `VAL_HI` emission;
  `emitByteList`'s single `VAL_LO` emission when the element used `>`
  extraction (`.BYTE >label` already parses successfully today as a
  silent, incorrectly non-relocatable constant -- a real, previously
  unnoticed gap); and `emitInstruction`'s `eiTwoByte` branch, but only for
  `CASM_MODE_IMMEDIATE` (`LDA #>label` shares its code path with
  zero-page/indexed-indirect/indirect-indexed modes and must be
  distinguished from them, which must never be relocatable).
- **`CasmParserStmt.Flags` already reserves 7 unused bits beyond
  `CASM_PARSER_STMT_FORCE_ABS`** (added by WP28 for exactly this kind of
  extension). A new `CASM_PARSER_STMT_RELOCATABLE` bit (bit 1), derived at
  the same `parser.s` site as `FORCE_ABS`, reaches all four emission sites
  above through the shared `parserParseExpressionValue` call with no
  per-caller duplication.
- **User-confirmed decisions (2026-07-24):** default relocatable origin is
  `$3400` (matches CASM's own link address and every external app's
  `add_ca65_app` base-link convention); `.STATIC`/`.RELOC` source preamble
  directives remain out of scope this phase (only CLI `/S` becomes
  meaningful; `/S` still requires an explicit `.ORG`, since static mode has
  no configured default); the relocation table is a flat VMM-backed
  append-only list of 16-bit offsets capped at 4096 entries / 8192 bytes
  (ample headroom under the existing 65535-byte single-allocation ceiling,
  and against `CASM_VMM_CAPACITY = 8` with only 2 of 8 slots normally in
  use today).
- **R6 footer contract** matches `tools/reloc.py` exactly (table of 16-bit
  LE offsets, 2-byte LE base address, 2-byte LE count, ASCII magic `"R6"`);
  CASM never invokes `reloc.py` at runtime and never diffs two builds --
  the base-address field is simply the frozen origin written directly. The
  insertion point in `casm.s`'s `start` routine is immediately after
  `emitFinalize` succeeds and before `diagPrintPhase2Ready`, gated on
  relocatable mode; static-mode output is unaffected.

Proposed WP breakdown (each requires its own dedicated plan and approval
per `AGENTS.md`, not authorized by WP37 alone): WP38 optional `.ORG` /
default origin / `/S` wiring; WP39 relocation classification (expr/parser
ABI); WP40 relocation table storage and the four emission-site hooks; WP41
native R6 footer serialization; WP42 verification, walkthrough, and Phase 8
completion gate.

**CASM Phase 8 WP37 is complete.** WP38 remains separately gated and
unstarted; this freeze does not activate it.

### CASM Phase 8 WP38 Default Origin and `/S` Wiring (Phase 0C.15, 2026-07-24)

Amends Phase 0C.14 above with as-built detail from WP38's actual
implementation. Plan:
`brain/plans/2026-07-24-casm-phase8-wp38-default-origin-and-static-override.md`.
Walkthrough:
`brain/walkthroughs/2026-07-24-casm-phase8-wp38-default-origin-and-static-override.md`.

`.ORG` is now optional. `CASM_DEFAULT_ORIGIN = $3400` (`common.inc`) is the
default relocatable origin when it is absent; `/S` forces static mode and
still requires an explicit `.ORG`.

Two mechanism gaps surfaced during planning, beyond what the Phase 0C.14
freeze itself flagged as open:

- `emitInit` never primed `CasmPc` -- safe only while `.ORG` was
  mandatory-and-first, since `emitOrg` unconditionally overwrote it before
  anything else ran. `emitInit` now conditionally primes `CasmPc` to
  `CASM_DEFAULT_ORIGIN` unless `/S` is set (in which case it stays zero
  until an explicit `.ORG` sets it, or the first qualifying statement is
  rejected).
- `crpLabel` (`casm.s`) never guarded against a label preceding `.ORG` at
  all -- a latent gap since Phase 4 that no fixture had ever exercised,
  since every prior fixture always put `.ORG` first.

Both are closed by one unified mechanism: `CasmOrgSet` (`emit.s`) is
renamed `CasmOutputStarted` and broadened from "an explicit `.ORG` has been
processed" to "a label, a byte, or an explicit `.ORG` has already been
processed this pass." A new exported `emitMarkStarted` (replacing
`emitRequireOrg`) is the shared guard for all four qualifying call sites --
`emitInstruction`, `emitByteList`, `emitWordList` (unchanged call shape,
just a renamed target), and a new call added to `crpLabel`, deliberately
run unconditionally before the pass-mode branch so Pass 1 and Pass 2 agree
identically on whether a later `.ORG` is late. On the first qualifying
statement of a relocatable (non-`/S`) assembly with no `.ORG` yet,
`emitMarkStarted` writes the 2-byte header from `CasmPc` through the same
`emitRawByte` pair `emitOrg` itself uses, inheriting the existing
`CASM_PASS_MODE_MEASURE` no-op gate with no new pass-mode branching.
`emitOrg` itself does not call `emitMarkStarted` (to avoid writing the
header twice); it checks/sets `CasmOutputStarted` directly, matching its
prior structure exactly.

**The late-`.ORG` case reuses `CASM_DIAG_DUPLICATE_ORG`** rather than a new
diagnostic identifier, per the user's confirmed decision -- both a genuine
second `.ORG` and a `.ORG` arriving after an implicit default origin
already started output are structurally "`.ORG` arrived after output had
already started," and the existing message text does not claim the earlier
event was itself an `.ORG`.

Two standalone test harnesses (`test_casm_pass1`, `test_casm_passcheck`)
needed their own `CasmCliOptions` stand-in BSS byte, since `emit.s` now
references it and `ld65` links whole object files -- found by a real link
attempt during implementation, not predicted in the WP37 freeze.

`casmorg1` (an existing Phase 4 WP13 fixture, `LDA #$01` with no `.ORG`)
was reused unmodified as the primary positive fixture: its expected outcome
flips from `CASM_DIAG_ORG_REQUIRED` (historical) to a successful
relocatable assembly at `$3400` -- the intended effect of this WP, not a
regression. `casmorgexpl1` (the same instruction with an explicit
`.ORG $3400`) has a deliberately byte-identical trusted reference, giving a
real, automated proof that the implicit default and an explicit `.ORG` at
the same address produce identical output. `casmnoorg1` (a no-`.ORG`
forward-referenced label) proves the full two-pass label-resolution
pipeline agrees with the implicit origin, not just `emitMarkStarted`'s own
state machine in isolation. `casmorglate1` (a label followed by a later
`.ORG`) proves the closed latent gap.

MAIN headroom: 128 of 13568 bytes (down from 189; this WP cost 61 bytes),
no size bump needed. User confirmed the full runtime verification matrix:
"All tests pass." Final CASM `0.1.40` build 1145.

**CASM Phase 8 WP38 is complete.** WP39 (relocation classification)
remains separately gated and unstarted; this closure does not activate it.

### CASM Phase 8 WP39 Relocation Classification (Phase 0C.16, 2026-07-24)

Amends Phase 0C.14/0C.15 above with as-built detail from WP39's actual
implementation. Plan:
`brain/plans/2026-07-24-casm-phase8-wp39-relocation-classification.md`.
Walkthrough:
`brain/walkthroughs/2026-07-24-casm-phase8-wp39-relocation-classification.md`.

`CASM_EXPR_FLAG_RELOCATABLE` is now a real, correctly-produced
classification -- previously wired end to end in the ABI (Phase 5/6B
foresight) but never set by any producer. A new `CASM_PARSER_STMT_RELOCATABLE`
bit (`CasmParserStmt.Flags` bit 1) is derived from it at the same
`parser.s` site `CASM_PARSER_STMT_FORCE_ABS` already is. No relocation
table exists yet and no emission site was touched -- WP40 consumes the
classification; this WP only makes it correct.

**A real ordering hazard, invisible from the Phase 0C.14 freeze alone, was
found and closed.** `parserParseStatement` evaluates an instruction's
operand expression *inline* (via `parseOperandSequence` ->
`parserParseExpressionValue` -> `exprEvaluate`), before `casmRunPass` ever
dispatches to `emitInstruction` -- the site WP38's mode-commit call lives
at. So a no-`.ORG` source whose very first statement is a bare instruction
with a symbol operand (`JMP TARGET`, no leading label) would classify that
symbol *before* relocatable mode was locked in. WP38's own `casmnoorg1`
fixture didn't catch this because it starts with a label, whose own
`crpLabel` commit call runs first. `.BYTE`/`.WORD` were never at risk:
their operands are deferred past `emitByteList`/`emitWordList`'s own
commit calls. Resolved by moving the commit trigger into
`parserParseExpressionValue` itself, reaching every statement kind through
the one shared adapter -- **skipped specifically when the current
statement is `.ORG`** (`.ORG`'s own operand already goes through the
identical expression path and can itself reference a symbol per WP28's
design; calling the commit unconditionally would write the default-origin
header and lock `CasmOutputStarted` before `emitOrg` runs, causing it to
reject its own `.ORG` as a spurious duplicate).

**A second new flag was needed beyond `CasmOutputStarted`.**
`CasmOutputStarted` only records *that* output began, not *which* mode was
chosen -- insufficient for a later statement's classification. New
exported `CasmRelocatableMode` (`emit.s`): reset 0 in `emitInit`, set 0 by
`emitOrg`'s success path, set 1 by `emitMarkStarted`'s implicit-default
path.

**Two module-boundary design decisions, both confirmed by the user:**
`parser.s` now calls `emit.s`'s `emitMarkStarted` directly (extending the
existing precedent that `parser.s` already reads `emit.s`'s
`CasmPassMode`), rather than duplicating the origin/header-write state
machine; and `exprEvaluate`'s input ABI grew a new `A` = relocatable-mode
parameter rather than `expr.s` importing `emit.s` state directly --
keeping `expr.s` and its standalone `test_casm_expr` harness fully
decoupled from `emit.s`, avoiding a repeat of WP38's `CasmCliOptions`
stand-in-symbol friction. `CASM_EXPR_FLAG_RELOCATABLE` is OR'd in
unconditionally alongside `SYMBOL_DERIVED` (not gated on `RESOLVED`),
mirroring `FORCE_ABS`'s own Pass 1/Pass 2 agreement precedent.

`test_casm_expr.s`'s `CASE` table gained a 9th per-case field
(`CASE_RELOC_MODE`); all 30 pre-existing cases pass `relocMode = 0`
(confirmed safe: the new OR is additive against an already-resolver-set
bit for the pre-existing `RELVAL`/`UNRES` cases, or a no-op against a
clear one for every other case). Four new `relocMode = 1` cases isolate
the new input-driven path from the pre-existing resolver-driven one --
notably a new `<ABSVAL` script (`ABSVAL`'s mock resolver never sets
`RELOCATABLE` itself, unlike `RELVAL`), proving extraction-clearing works
against the new path specifically rather than being confounded with the
resolver's own bit.

New end-to-end fixture `casmordhaz1` (no `.ORG`, `JMP TARGET` as the
literal first statement, no leading label) proves the ordering-hazard fix
assembles correctly -- deliberately byte-identical to `casmnoorg1`'s
output, since the point is proving the first-statement shape works, not a
different result. No end-to-end fixture can directly observe the
classification bit itself (no table/footer exists until WP40); the real
proof is `test_casm_expr`'s isolated harness.

MAIN headroom: 68 of 13568 bytes (down from 128; this WP cost 60 bytes),
no size bump needed. User confirmed the full runtime verification matrix:
"All tests pass." Final CASM `0.1.41` build 1147.

**CASM Phase 8 WP39 is complete.** WP40 (relocation table storage and
emission-site hooks) remains separately gated and unstarted; this closure
does not activate it.

### CASM Phase 8 WP40 Relocation Table and Emission-Site Hooks (Phase 0C.17, 2026-07-25)

Amends Phase 0C.14-0C.16 above with as-built detail from WP40's actual
implementation. Plan:
`brain/plans/2026-07-24-casm-phase8-wp40-relocation-table-and-emission-hooks.md`.
Walkthrough:
`brain/walkthroughs/2026-07-24-casm-phase8-wp40-relocation-table-and-emission-hooks.md`.

A new module, `reloc.s`, owns the relocation table: `relocInit` allocates
`CASM_RELOC_TABLE_BYTES` (8192, 4096 entries) via `vmmStoreAlloc`
unconditionally every Pass 2 run, regardless of static/relocatable mode
(VMM cost only, not the MAIN envelope -- a static assembly's table simply
stays empty, since `CASM_PARSER_STMT_RELOCATABLE` is never set outside
relocatable mode). `relocRecord` no-ops under `CASM_PASS_MODE_MEASURE`
(mirroring `emitRawByte`'s own single-gate precedent -- the table does not
exist during Pass 1) and otherwise appends `CasmPc - CASM_DEFAULT_ORIGIN`
via one immediate `vmmWindowWrite` per entry, deliberately not staged/
batched: the only shared transfer window (`CasmVmmBuffer`) is also used
transiently by `symbolsLookup` between a statement's relocatable operands,
so holding entries in it across calls would risk the same shared-scratch-
clobber bug class this codebase has hit three times before (WP23-25).

**Re-tracing every byte-emission call site (not trusting WP37's original
four-site enumeration) found a real correctness gap.** `emitInstruction`'s
absolute-family branch and `emitWordList` both emit a `VAL_LO`/`VAL_HI`
pair for one logical value, and `<`/`>` extraction turns out to be
grammatically reachable at both (`LDA >LABEL` and `.WORD >LABEL` are valid
syntax today, not only `.BYTE >LABEL`/`LDA #>LABEL`) -- confirmed by
re-reading `parseOperandSequence`'s dispatch table directly. A naive
"record `VAL_HI` when relocatable" check would have wrongly marked a
genuine constant `$00` byte (the padding `applyExtraction` leaves behind)
as needing a page-delta patch, corrupting it at load time. Resolved with
two new private `emit.s` helpers using `VAL_HI`'s own zero/nonzero state,
already available with no new ABI field: `emitMaybeRecordHi` (record iff
`RELOCATABLE` set and `VAL_HI != 0` -- the full, non-extracted value) and
`emitMaybeRecordLo` (record iff `RELOCATABLE` set and `VAL_HI == 0` -- the
`>`-extraction case). A genuine relocatable address can never legitimately
have a zero high byte in EMIT mode (`CASM_DEFAULT_ORIGIN` is `$3400`), so
this disambiguation is sound, not heuristic.

Six call sites wired: `emitInstruction`'s shared length-3 branch (both
helpers, covering `CASM_MODE_ABSOLUTE`/`_X`/`_Y`/`_INDIRECT` uniformly,
unchanged from WP37's finding); `eiTwoByte`, additionally gated on
`CasmInsn.Mode == CASM_MODE_IMMEDIATE` -- re-verified rather than
re-assumed that this guard is still needed, since `ofRequire8Bit`
(`opcodes.s`) is shared with indexed-indirect/indirect-indexed addressing,
so `LDA (>LABEL),Y` is equally reachable and must never be recorded per
the master plan's explicit pointer-byte exclusion; `emitByteList` (`Lo`
only); `emitWordList` (both helpers).

New diagnostic `CASM_DIAG_RELOC_TABLE_FULL` at `$30` (the next free
identifier); `diagPrintFatal`'s selection bound extended from
`CASM_DIAG_PHASE6B_LAST` to the new `CASM_DIAG_PHASE8_LAST`.

New standalone `test_casm_reloc` harness (mirroring the `test_casm_symbols`/
`test_casm_vmm` isolated-module-first precedent) is the only real proof of
`relocRecord`'s correctness at this stage -- no R6 footer exists until
WP41 for any end-to-end fixture to observe the table's actual contents.
Its `relocfull1` case does a genuine fill of all 4096 entries (not a
poked shortcut), matching `casm_vmm.s`'s `vmmalloc3` precedent, before
confirming the 4097th is rejected. Two new end-to-end fixtures
(`casmrelop1` covering the normal shape at each site, `casmrelop2`
covering the newly-found two-sided extraction cases) prove only that the
new hooks do not corrupt program bytes, since the table itself remains
unobservable until WP41.

MAIN size bumped `$3500` -> `$3600` (144 bytes measured overflow; 106
bytes headroom at the new size). `test_casm_pass1`/`test_casm_passcheck`
needed `reloc.s` added to their own source lists, found via a real link
failure, not assumed. User confirmed the full runtime verification
matrix: "all tests pass." Final CASM `0.1.42` build 1154.

**Separately from WP40's own scope**, `casmempty.s` was removed from
`test.d64`'s build during this session (commit `cad491a`, committed
independently before WP40's own commit): its zero-block directory entry,
created via `cc1541 -L`, sets track/sector to 0 -- a value normally
reserved as an end-of-chain marker, not a valid file start -- suspected of
corrupting `test.d64`. See `tests/AGENTS.md` and `wiki/tasks/casm.md`'s
Verification Policy section for the corrected contract.

**CASM Phase 8 WP40 is complete.** WP41 (native R6 footer serialization)
remains separately gated and unstarted; this closure does not activate it.

### CASM Phase 8 WP41 Native R6 Footer Serialization (Phase 0C.18, 2026-07-25)

Amends Phase 0C.14-0C.17 above with as-built detail from WP41's actual
implementation. Plan:
`brain/plans/2026-07-25-casm-phase8-wp41-r6-footer-serialization.md`.
Walkthrough:
`brain/walkthroughs/2026-07-25-casm-phase8-wp41-r6-footer-serialization.md`.

`reloc.s` gains `relocFinalize`, called unconditionally from `casm.s`
immediately after `emitFinalize` succeeds. No-ops (`C` clear) if
`CasmRelocatableMode` is 0 (static assembly), so static output stays
exactly the plain PRG it always was. Otherwise it copies
`CasmRelocCount * 2` bytes of table content from VMM to the output file in
`<= 64`-byte chunks (`vmmWindowRead` then an immediate `fileWrite` per
chunk, reusing `reloc.s`'s existing `CasmVmmBuffer` transfer window --
no new buffer), then stages and writes the 6-byte R6 footer
(`CASM_DEFAULT_ORIGIN` little-endian, `CasmRelocCount` little-endian, the
ASCII magic `"R6"` as explicit hex `$52 $36`, not a ca65 character literal)
in one final `fileWrite` call, matching `tools/reloc.py`'s exact byte
layout. This is the WP that makes the relocation table observable for the
first time -- WP39 and WP40 both deferred their own end-to-end proof to
"once the footer exists."

A real, easy-to-miss consequence of the master plan's own gate text
("static fixtures remain ordinary PRGs") is that five existing
relocatable-mode trusted references built across WP38-WP40 (`casmorg1`,
`casmnoorg1`, `casmordhaz1`, `casmrelop1`, `casmrelop2`) all go stale the
instant this WP lands, since each now gains a real footer it didn't have
before. All five were updated with hand-derived footers, verified
byte-for-byte and hash-for-hash against `hex_manifest_to_bin.py`'s own
independent computation before any runtime test. `casmorgexpl1.ref.hex`
(explicit `.ORG`, stays static) needed only a comment correction: its
WP38-era claim of being "deliberately byte-identical" to `casmorg1.ref.hex`
breaks by design once `casmorg1` gains a footer -- the correct, intended
outcome of R6 relocation existing at all, not a regression.

MAIN size bumped `$3600` -> `$3700` (103 bytes measured overflow; 153
bytes headroom at the new size, measured via `ld65 -m` as CODE + RODATA +
BSS against the MEMORY area's declared size -- BSS occupies address space
within `MAIN` even though it contributes no file bytes, so headroom must
account for it, not just the PRG's on-disk byte count).
`test_casm_pass1`/`test_casm_passcheck` (which link `reloc.s` whole)
bumped identically.

**Two real, pre-existing VMM-leak defects were found and fixed during this
WP's own verification**, both the same bug class: a standalone test
harness allocates VMM storage but never calls `resourcesCleanup` before
`DOS_EXIT`, leaking the allocation permanently at the OS/REU tracking
level -- not just the harness's own 8-slot registry, which a fresh
`DOS_EXIT` does not implicitly release. The user's first verification pass
reported `TEST_CASM_PASS1` failing all 7 fixtures ("fffffff"), matching
this codebase's own historical VMM-registry-exhaustion symptom (WP33).
Root-caused to `test_casm_reloc.s` (new in WP40): its `relocinit1` and
`relocfull1` fixtures each allocate their own VMM slot and neither is ever
freed, exhausting REU capacity for whatever test ran next in the same VICE
session. Fixed by adding a `resourcesCleanup` call before its final
PASS/FAIL print and `DOS_EXIT`. Auditing every other standalone harness
for the same defect class (rather than assuming this was isolated) found
`test_casm_symbols.s` (WP27, unrelated to this WP's own scope) with the
identical gap -- `syminit1`'s `symbolsInit` call allocates the symbol
table's VMM storage and it was never freed either. Fixed identically, with
the user's explicit approval to extend this WP's scope to cover it, since
it is the same well-precedented one-line fix and leaving a known leak in
place would just reproduce the same confusing symptom later.
`test_casm_vmm.s` (explicit `vmmStoreFree` within each fixture) and
`test_casm_expr.s` (no VMM allocation at all) were confirmed already safe.

User confirmed the full runtime verification matrix across two passes (the
second after both leak fixes): "all tests pass." Final CASM `0.1.43` build
1156, no-change rebuild stable, all three disk images build clean.

**CASM Phase 8 WP41 is complete.** WP42 (verification, walkthrough, and
Phase 8 completion gate) remains separately gated and unstarted; this
closure does not activate it.

### Absolute vs. Relocatable Binaries
- **Constraint**: External programs are compiled for `$3200` (UserProgStart) by default.
- **Relocation**: In Phase 6B, a **Binary Relocator** (`aptRelocate` in `loader.asm`) is implemented. Relocatable apps are compiled twice at a 1-page offset, and post-processed by `tools/reloc.py` to append a relocation table and a 6-byte footer (`BaseAddr`, `TableSize`, `'R'`,`'6'`).
- **Execution**: The OS loader automatically detects this footer, patches all absolute high-bytes in-place to run at the target load page (e.g. `LOAD debug $4000`), and truncates the registered size to exclude the table. Non-relocatable binaries fall back to being registered as-is with original bounds preserved.
- **Memory Safety & Runtime Buffers (Conway Case Study)**: Programs that utilize large uninitialized RAM buffers (such as Conway's 960-byte double grid buffers) must not hardcode fixed buffer pages (e.g. `$3000` / `$3400`). Hardcoded buffers lead to silent memory corruption if another program is auto-allocated to the buffer address space by the OS page allocator. Instead:
  - Buffers are defined in-binary as page-aligned data allocations (`.align 256` / `.align $100` with `.res` or `.fill`).
  - This embeds them in the `.prg` file size, forcing the OS memory manager to reserve the entire memory range (`[LoadAddr, LoadAddr + Size)`) and prevent allocation overlaps.
  - Buffer base addresses are retrieved dynamically via relocatable pointer references (`#<grid0` / `#>grid0`), allowing the relocator to patch them correctly when shifted.
  - Linking configurations generated from `USER_PROG_START_HEX` and `USER_PROG_START_HEX_NEXT` must have segment alignment enabled (`align = 256`) and memory boundaries increased to cover the buffers.

### App Table (Phase 6A — Completed)
- **Segment**: `AppTable` at `$2000`–`$2494`. Consecutively followed by `ShellExt` segment at `$2495`–`$311A` (storing help/version string blocks plus extended shell/date-time/file helpers).
- **UserProgStart**: Shifted from `$2000` → `$2600` → `$2C00` → `$3200` as resident OS segments grew. Configured via the CMake cache variable `USER_PROG_START_HEX`; external programs must always compile against the current value rather than a hardcoded address.
- **Storage**: VMM-allocated 4 KB page (one `vmmAlloc` call at shell startup). Segment number saved in `AptSegLo/Hi` at `$03F2`–`$03F3` (cassette buffer free area).
- **Layout**: 4-byte header (MaxSlots=16, UsedSlots, reserved×2) + 16 entries × 40 bytes = 644 bytes total.
- **Entry offsets**: Flags=0, Name=1 (16 bytes PETSCII null-padded), LoadAddr=17 (lo/hi), Size=19 (lo/hi). Offsets 21–39 reserved for Phase B/C (ReuAddr, saved CPU state).
- **Protected ranges for LOAD**: Reject if address < `UserProgStart` or >= `$C000`.
- **API**: Internal 6502 labels (`aptInit`, `aptFind`, `aptRegister`, `aptRemove`, `aptList`, `aptPrintHex8`, `aptGetSlotRange`).
- **Phase progression**: A = fixed `$2600` entry; B = Binary Relocator patches binary at arbitrary address; C = REU-resident with DMA swap on RUN.
- **Design spec**: `docs/superpowers/specs/2026-05-13-app-manager-design.md`.

### Memory-Safe Loading (Pre-flight Validation)
- **Concept**: Before any bytes of a `.PRG` are loaded from disk, the OS pre-resolves the file's size and validates the destination range against protected system areas and registered app slots.
- **Directory Size Resolution**: Implemented `getFileSize` which queries `"$0:filename"` using secondary address 0 (read directory pseudo-file). It skips the disk header line, parses the second line (which is either the file entry or `BLOCKS FREE`), counts quote characters to verify it is a valid file entry, and uses `calcFileSize` to convert blocks to bytes.
- **Pre-flight Checks**: Relocated loads (`SpecificLoad=0`) invoke `getFileSize` and `aptCheckRange`. The range `[HexVal, HexVal+size)` is validated:
  - Reject (protected address) if it wraps around 16 bits or falls under `UserProgStart` or above `$C000`.
  - Reject (address overlap) if it intersects with any active app table slot's `[LoadAddr, LoadAddr+Size)` range.
- **Safety Rejection**: On failure, the KERNAL load is aborted before memory transfer begins, keeping memory intact. The obsolete post-load eviction logic in `aptRegister` has been deleted.

### Dynamic Memory Allocation (Auto-Slotting)
- **Concept**: If the user does not specify a load address (e.g. `LOAD "PROGRAM"`), the system automatically allocates the first available page-aligned free memory gap large enough to hold the program.
- **Allocator Algorithm**: Implemented `aptFindFreeRegion` using a sliding-window scan:
  - Candidates are scanned ascending starting from `P = >UserProgStart` page-aligned address.
  - Calls `aptCheckRange` to validate candidate range. If safe (carry clear), the range is allocated (`HexValHi = P`, success).
  - If unsafe (carry set), and the conflict is with a registered slot `X` (`X != $FF`), it retrieves slot `X`'s bounds, computes its end page (`(EndAddr+255)/256`), updates the candidate search window `P` to that end page, and repeats.
  - If the conflict is with a protected region (`X == $FF`), the candidate range has hit or exceeded the `$C000` upper bound, returning an `out of memory` error.
- **Integration**: Wired into `cmdLoad` to execute dynamically when no address is specified.

### VI Alike External Editor (Phase 6C)
- **Buffer Design**: Uses a Gap Buffer split into two parts: text before cursor (`[textBufferStart, ptrGapStart)`) and text after cursor (`[ptrGapEnd, ptrBufEnd)`). This allows insertion and deletion of characters/lines in O(1) time without massive shifts.
- **Line numbering margin**: Line number mode (`lineNumMode = 1`) shifts the text viewport horizontally by 5 characters, drawing space-padded line numbers on the left (e.g. `   1 |`) and tilde `~` markers past the end of the file.
- **Horizontal & Vertical Scrolling**: Automatically tracks `topLine` and `leftCol` to align with the cursor's coordinate index. Viewport transitions happen dynamically inside `checkScrollBounds` on cursor motion.
- **Yank and Clipboard**: Implements a dedicated 2KB fixed clipboard `yankBuf` supporting line-yank (`yy`) and character-yank. Pasting (`p`/`P`) recalculates text indices to ensure stability.

### Master Environment Block
- **Storage**: Allocated in the REU via `vmmAlloc` (4KB / 1 page) during shell initialization.
- **Format**: MS-DOS standard double-null terminated strings (`VAR1=VAL1\0VAR2=VAL2\0\0`).
- **Access**: Managed via the `SET` and `PATH` internal commands. External programs can access it via the VMM API.

### Generalized Multi-Digit Version Stage (approved 2026-07-17)
- **Constraint**: ca65 equates defined using `=` are restricted to numeric expressions and cannot represent string literals. Consequently, version staging was historically limited to single-byte character constants (e.g. `'0'`–`'9'`).
- **Resolution**: Transitioning to preprocessor text macros (`.define VERSION_STAGE "10"`) allows version stage strings of arbitrary length/digits.
- **Implementation**: The preprocessor evaluates these macros during assembly time. Placing them in `.byte` declarations (e.g., `.byte VERSION_STAGE`) compiles them directly to their PETSCII character representations. This transition is completely static, resulting in zero runtime overhead or changes to execution logic.
- **Generalization**: This standard is generalized to all `ca65` external applications and test suites in the repository, ensuring uniform version representation.


## C64 Platform Constraints Discovered

| Finding | Impact | Resolution |
| :--- | :--- | :--- |
| `$0300–$033B` = KERNAL/BASIC vector table | CommandBuffer at $0300 corrupts IRQ ($0314) and CHROUT ($0326) on any input | Relocated CommandBuffer to `$1400` |
| CHRIN ($FFCF) goes through screen editor (BASIN) | Screen editor already echoes typed chars; manual re-echo garbles display | Removed echo CHROUT from shellReadLine |
| KA `.text` maps lowercase ASCII → PETSCII control codes $01–$1A | Strings like "Bad command" render as garbage in default C64 char mode | Added `lda #$0E` at startup to enter lowercase/uppercase display mode |
| KA bare `name = value` is invalid syntax | Build fails; all equates require `.label name = value` | Converted all equates to `.label` |
| KA macros require `()` in definition | Build fails without `()`: `.macro Foo() {` | Fixed macro definitions |
| cmdCompare X-register walk bug | All 3 commands dispatched to wrong addresses; crash on every command | Redesigned cmdCompare: X = immutable entry base via `CmpBase` ZP var |
| `jmp ($0338)` for EXIT | $0338 is not a BASIC warm start vector; hangs or crashes | Changed to `jmp $E37B` (BASIC ROM warm start) |
| C64 screen editor "quote mode" | `"` in input causes cursor keys to insert control codes | Known limitation; requires GETIN polling loop to fix |
| `KernalGetIn ($FFE4)` may clobber Y | Any input loop using Y as a buffer index will silently corrupt it across `GETIN` calls, causing characters stored at wrong offsets | Always push/pop Y around `jsr KernalGetIn`: `tya/pha … jsr KernalGetIn … pla/tay`. See `shellReadLine` in `shell.asm` for the canonical pattern. |
