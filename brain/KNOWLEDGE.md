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
