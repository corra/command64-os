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
| 2026-07-27 | User programs default to `$3800` | Resident `ShellExt` growth consumed the old `$3400` boundary. Fresh builds use `$3800/$3900`; CASM retains its independent `$3400` R6 emission origin and external-name dispatch relocates before execution. | Active |
| 2026-08-04 | Standalone external-app architecture recommendation | Standalone DEBUG, EDLIN, and CASM are feasible, but production source forks would create unacceptable drift. Preserve one application core and use Command64/standalone platform adapters; prototype DEBUG first, use EDLIN's RAM fallback next, and defer CASM until shared file and REU runtimes are proven. | Proposed |

## Technical Findings

- **[2026-08-11] Shared 6502 fixture trampolines must not depend on indirect-JMP
  pointer placement**: `JMP (addr)` on NMOS 6502 wraps the high-byte fetch when
  its pointer lands at `$xxFF`. A relocatable test fixture cannot assume its
  vector avoids that boundary. The CASM fault stub stores the real destination
  into the operand of a RAM-resident absolute `JMP $xxxx`, avoiding the hardware
  hazard without imposing global DATA alignment.
- **[2026-08-11] VICE command entry requires PETSCII `$A4` underscores**:
  `vice_keyboard_type` maps ASCII `$5F` to the C64 left-arrow glyph, so shell
  application names containing `_` must be sent with `vice_keyboard_petscii`
  and explicit `$A4` bytes. A left-arrow spelling can pass misleadingly far
  into filename checks and appear as a loader failure. Also remove temporary
  stopping checkpoints and explicitly resume execution before classifying a
  timed run.
- **[2026-08-11] CASM listing include-device validation**: Listing filename
  resolution validates catalog devices 8-11 before subtracting 8 and indexing
  `includeDeviceStrLo/Hi`. Out-of-range metadata returns the existing listing
  replay-mismatch diagnostic and leaves resolved output non-consumable; valid
  listing bytes and public storage/ABI remain unchanged.
- **[2026-08-11] CASM listing-private handle ownership**: A successful
  `DOS_OPEN_FILE` transfers ownership to `listing.s` before central registry
  insertion can fail. `CasmListFileSlot = CASM_INVALID_SLOT` distinguishes
  this bounded unregistered state: `listingClose` calls `DOS_CLOSE_FILE`
  directly for it, while registered slots continue through `fileClose`.
  `OPEN` and `CLOSE_FAILED` each permit one caller-driven close attempt;
  failures retain ownership, and deletion occurs only after close succeeds.
  This preserves the primary create/write diagnostic and makes later
  `artifactsAbort` calls safe retries without an internal loop.
- **[2026-08-04] Standalone external-app feasibility**: Current ca65 external
  apps depend on a relocatable Command64 artifact, `OS_API=$1000`, shared
  parameter zero page, shell command-buffer/exit conventions, and application-
  specific file/VMM services. Fixed-origin standalone PRGs are feasible through
  narrow platform adapters. DEBUG has the smallest useful boundary, EDLIN has a
  credible 2 KiB no-REU fallback, and CASM's bounded architecture requires a
  multi-allocation REU runtime for practical parity. See
  `brain/plans/2026-08-04-standalone-external-apps-feasibility.md`.

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
- **[2026-07-27] Multi-device data channels and LFN 15**: Closing or switching a drive's command channel after a data channel is open can invalidate that stream. Multi-file operations must complete readiness/error-channel traffic before opening their final data channels. `COPY` follows this ordering; `COMP` still requires a public API contract for the same behavior.
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

### CASM Phase 4 Parser/Opcode/Emission Contract (WP12-15, closed 2026-07-21)

- Phase 4 is the first production output consumer: a bounded recursive-descent
  statement parser (`parser.s`) drives a packed opcode/addressing-mode matcher
  (`opcodes.s`) and a numeric static emitter (`emit.s`), with no labels,
  symbols, expressions, VMM, two-pass assembly, or relocation in scope (all
  deferred to Phase 5 onward).
- `parserParseStatement` accepts an optional label, then a mnemonic or
  directive, then a shared `parseOperandSequence` grammar covering implied,
  accumulator, immediate, absolute (zero-page/absolute promoted by operand
  width at `$00FF`/`$0100`), indexed (`,X`/`,Y`), and both indirect forms.
  `.BYTE`/`.WORD` operand lists are deliberately deferred past the parser to
  `emit.s`, so their delimiter diagnostics (empty/leading/doubled/trailing
  comma) are raised there, not in `parser.s`.
- `opcodes.s` freezes a packed 151-entry legal-opcode table
  (`.assert opcodeBytesEnd - opcodeBytes = 151`) covering every official NMOS
  6502/6510 opcode/addressing-mode combination, with `CASM_MODE_IMPLIED`
  through `CASM_MODE_RELATIVE` as the 13 `CASM_MODE_*` values
  (`CASM_MODE_COUNT = 13`). Per-mnemonic support is a split bitmap
  (`ofMaskLo` for modes 0-7, `ofMaskHi` for modes 8-12); the WP14 acceptance
  work found and fixed a real miscompilation here (`CASM_MODE_ZEROPAGE_Y` was
  dead code because ca65 silently evaluates a negative shift to `$00` with no
  diagnostic — see the negative-shift reference note), fixed by naming each
  mask bit as a compile-time-asserted constant (`OF_BIT_LO_*`/`OF_BIT_HI_*`)
  instead of re-deriving the shift inline at each use site.
- `emit.s` performs numeric static emission only: relative branch
  displacement is computed from the address following the branch (`-128`/
  `+127` accepted, `-129`/`+128` rejected), PC advance is checked through
  `$FFFF` (advancing past `$FFFF` is `ADDRESS OVERFLOW`), and `.ORG` requires
  exactly one absolute-width numeric operand (`emitOrg` rejects
  `CASM_OPKIND_IMPLIED` and every non-`CASM_OPKIND_ABSOLUTE` operand shape) —
  the WP14 acceptance work found and fixed a real defect where a bare `.ORG`
  or `.ORG A` silently set the origin to `$0000` with no diagnostic. Both
  fixes reused Phase 4's own existing diagnostic range (`CASM_DIAG_SYNTAX_ERROR`
  `$1C`), adding no new diagnostic code.
- Production orchestration lives in `casm.s`'s `start` entry, not a separate
  `compiler.s`: the WP14 audit deliberately kept the ~35-line compile loop
  in-place (cohesive, bounded, tightly coupled to the shared
  `startInitFatal`/`startFatal` fatal trampolines) rather than extracting a
  module boundary that would only add dispatch glue. `casm.s` owns
  resource/CLI/file/source/lexer init, output-name derivation, output
  creation, the dispatch loop (MNEMONIC/DIRECTIVE/NEWLINE/EOF), routing every
  failure through `outputAbort` (preserves the primary diagnostic, deletes a
  created-but-incomplete PRG) before `exitFatal`, and leaving the completed
  output registry-owned for a single checked close during
  `resourcesCleanup` — `INPUT VALIDATED` prints only after the final buffered
  write (`emitFinalize`) succeeds.
- Trusted-reference verification (`casmemit1.ref`, `casmhello.ref`,
  `casmmodes.ref`, one legal statement per `CASM_MODE_*` value) is hand-
  assembled from the 6502 instruction set, never derived from `opcodes.s`
  itself — the non-circularity rule that caught the `ZEROPAGE_Y` defect above;
  see the CASM trusted-reference-rule memory note.
- User-approved Phase 4 completion (WP15) is CASM `0.1.17`. Governing:
  `brain/plans/2026-07-20-casm-phase4-wp14-orchestration-binary-validation.md`,
  `brain/plans/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`,
  `brain/plans/2026-07-21-casm-phase4-wp14-test-plan.md`.

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

### CASM Phase 8 WP42 Verification and Completion Gate (Phase 0C.19, 2026-07-25)

Amends Phase 0C.14-0C.18 above with the final consolidated verification
that closes CASM Phase 8. Plan:
`brain/plans/2026-07-25-casm-phase8-wp42-verification-and-completion-gate.md`.
Walkthrough:
`brain/walkthroughs/2026-07-25-casm-phase8-wp42-verification-and-completion-gate.md`.

Every relocatable fixture verified across WP38-WP41 (`casmorg1`,
`casmnoorg1`, `casmordhaz1`, `casmrelop1`, `casmrelop2`) was checked
exclusively via `COMP` against a hand-derived byte reference at CASM's own
default assembly address -- proving the *file* was byte-correct, never that
the OS's existing `aptRelocate` loader (`src/command64/loader.asm`, unchanged
since Phase 6B) correctly *consumes* CASM's native R6 footer. The master
plan's own Phase 8 gate text ("Command 64 loads and runs generated R6
fixtures at several page-aligned addresses") had never actually been
exercised. Closed with a new fixture, `casmreloc1`: its one relocatable
byte is the extracted high byte of a `DOS_PRINT_STR` message pointer
(`LDY #>MSG`) -- the same immediate high-byte-extraction shape `casmrelop2`
(WP40) already established is correctly recorded, so the fixture tests
`aptRelocate`'s patch arithmetic against CASM's specific footer layout,
not a new CASM classification case. `casmreloc1` was loaded and run at
three page-aligned addresses: `$3400` (a deliberate zero-delta control,
exercising `aptRelocate`'s own `aptRelocateStoreEnd` short-circuit branch
that no `COMP`-only fixture ever reaches through the loader), `$4000`, and
`$5000` (genuinely relocated). The same message printed correctly at all
three, proving `aptRelocate` correctly patches CASM's native R6 output for
the first time.

Also re-ran WP31's 7-fixture Phase 3/4 diagnostic regression sample
(`casmwp11`, `casmzp1`, `casmcma2`, `casmorg3`, `casmzpi2`, `casmpcovf`,
`casmnumerrh`), unrun since WP36 despite WP39 making a real, material
change to the exact expression-evaluation core those fixtures depend on
(`exprEvaluate`'s new relocatable-mode parameter, `parserParseExpressionValue`'s
new commit-trigger call site) -- all 7 reproduced their established
outcomes correctly.

**One non-reproducible anomaly was noted and is recorded here rather than
silently dropped.** During this WP's verification, the user reported
`TEST_CASM_PASS1` failing with the same VMM/REU-exhaustion signature
("fffffff" across all fixtures) that WP41 diagnosed and fixed twice
(`test_casm_reloc.s`, `test_casm_symbols.s`). Unlike WP41's case, this did
not follow a stale VICE session: the user resets VICE for every build.
Re-inspection of `casm_pass1.s` and `casm_passcheck.s` found both already
correctly call `resourcesCleanup`/have no VMM allocation to leak, ruling
out a defect in either harness itself. The user could not recall the exact
test sequence that preceded the failure, and a subsequent full
from-scratch re-run of the entire consolidated matrix, taken in order,
passed clean with no failure. No root cause was identified, and no fix was
applied -- per this project's discipline of only changing source in
response to a confirmed, understood defect, this is recorded as an open,
unresolved, non-blocking observation for future awareness, not treated as
fixed.

User confirmed the full consolidated matrix (6 standalone harnesses, 22
byte-identical trusted references including `casmreloc1`, 8 diagnostic
scenarios, the 7-fixture Phase 3/4 regression sample, static-fixture
regression, and the new three-address runtime relocation proof): "All
tests pass." Final CASM `0.1.44` build 1157, no-change rebuild stable, all
three disk images build clean. All six Phase 8 Acceptance items checked in
`wiki/tasks/casm.md`.

**CASM Phase 8 (Native R6 Relocation) is complete.** That closure did not
activate the separately gated CASM Phase 9 (`.include` processing); Phase 9
was later activated through WP43 below.

## CASM Phase 9 WP43 Include Contract (Phase 0C.19, Frozen 2026-07-25)

Phase 9 extends Phase 7's immutable VMM source model rather than replacing it
with a live stack of open files. Pass 1 transiently loads each distinct include
once into the existing source VMM store, closes the handle, and records an
ordered include event. Pass 2 performs no source filesystem I/O and replays the
recorded physical spans, validating parent/site/child correspondence.

The approved bounds are: quoted-only 1-63-byte raw PETSCII filenames with no
escapes; explicit device prefix or inherited parent device; no search path; 16
active include levels; 32 distinct physical files; 128 include events; one 8KB
VMM metadata allocation; and 65,535 distinct source bytes combined across all
top-level and included files. Repeated includes expand repeatedly while sharing
one physical byte copy. Device plus folded PETSCII filename defines identity;
cycle detection scans only active frames, so sequential reinclusion is legal.

Top-level inputs remain independent depth-zero roots in one symbol/output scope.
Every include entry/return and root transition is a logical statement boundary,
so missing physical newlines never concatenate source. Diagnostics identify the
physical file/location and print the bounded parent include-site traceback.
Implementation is split across WP44-WP49, each separately planned and approved.
Parent plan: `brain/plans/2026-07-25-casm-phase9-include-processing.md`.

WP43 completed with user approval at CASM `0.1.45` build 1160. Its only source
change was the version-stage increment; the include contract above remains
planned rather than operational. Two builds held 1160 stable, all three disk
images passed, and the 15,239-byte artifact retained its `$3400` load address
and 1657-entry R6 footer. WP44 remains separately gated.

WP44 completed with user approval at CASM `0.1.46` build 1166. It implements
quoted include grammar without semantic
loading. `lexerScanIncludeOperand` consumes 1-63 original PETSCII bytes from
`$20-$7E`/`$A0-$FE` except quote, stores them in a dedicated 65-byte
parser-owned record, and preserves newline/EOF lookahead. Diagnostics `$31-$33`
cover expected/invalid/too-long filenames. `casmRunPass` intercepts valid
includes before emitter or I/O effects and temporarily returns NOT IMPLEMENTED.
The user-approved MAIN envelope is `$3A00`; CASM build 1166 is 15,800 bytes with
1722 R6 entries. The corrected 14-case `test_casm_includ` runtime passes.

WP45 (complete, user-approved) adds `src/external/casm/include.s` as a standalone
module: an 8KB metadata VMM store (`CASM_INCLUDE_META_BYTES`; the first
4096 bytes hold 32 128-byte physical-file records, `CASM_INCLUDE_PHYS_REC_*`,
the rest reserved for WP47's event log), device resolution via the OS's own
`DOS_PARSE_PREFIX` (which advances its caller's zero-page pointer past a
recognized prefix in place -- no independent colon scan needed or safe to
duplicate), live case-folded catalog identity comparison (one stored
spelling, folded only at compare time), and deduplicated catalog load with
transient child open/append. `source.s` gained `sourceAppendFile`, which
appends at the true end of loaded content
(`CasmSourceLoadedLenLo/Hi`) through a new shared stream cursor
(`CasmSourceStreamCursorLo/Hi`) distinct from the live traversal read cursor
(`CasmSourceVmmCursorLo/Hi`) -- both `sourceLoad`'s existing per-file loop
and the new entry point route through it, never simultaneously. Per the
user's confirmed scope, `include.s` has **no production call site**:
`casmRunPass`'s `.INCLUDE` dispatch is unchanged from WP44, proven only by
the new `test_casm_catalog` harness; WP46 wires frame push/traversal
switching. One new diagnostic, `$34` `CASM_DIAG_INCLUDE_CATALOG_FULL`; two
originally-planned ones (metadata alloc/transfer failure) were dropped
before implementation as unreachable, since `vmmStoreAlloc`/
`vmmWindowRead`/`vmmWindowWrite` already propagate correct diagnostics for
every failure mode those would have covered (the same class of finding as
WP23's dropped `CASM_DIAG_VMM_ALLOC_TOO_LARGE`). Linking `include.s`
overflowed the production `casm` target's `$3A00` MAIN envelope by 694
measured bytes; the user approved growing it to `$3E00` (+1024 bytes). Final
build 1170 passes and holds stable on a no-change rebuild (309 bytes MAIN
headroom); `test_casm_pass1`/`test_casm_passcheck` (both link `source.s`
whole) continue to fit their existing `$3A00` envelope unchanged.

Two real defects surfaced only through the user's runtime testing, not
static verification, both fixed with the user's approval before completion:
(1) the `test_casm_catalog` harness itself hardcoded device 8 for every
real-load case, but the user's actual two-drive VICE setup boots `test.d64`
on device 8 and runs the fixture-carrying `casm_overflow_test.d64` from
device 9 -- fixed by capturing the real `CurrentDevice` once at startup
into a `TestDevice` field instead of assuming a fixed device (confirmed via
`cmdLoad` in `shell.asm`: an embedded `LOAD "x",n` device prefix is only a
transient override, always restored to the prior `CurrentDevice` afterward,
and no separate "device loaded from" is tracked anywhere in the app table).
(2) A genuine `sourceAppendFile` bug: it stashed the file's start offset in
`CasmValue0Lo/Hi`, which `vwPrepareTransfer` (`vmm_store.s`, reached via
`slVmmWrite` on every chunk write) already documents as its own
offset+count scratch and clobbers on the first chunk -- fixed by moving the
stashed value to a new, never-shared `CasmSourceAppendStartLo/Hi`, writing
`CasmValue0Lo/Hi` only once, at the very end. The same shared-scratch
aliasing bug class as WP23-25's `vmm_store.s` and WP44's own test harness,
and one `include.s`'s own header comments explicitly warned about -- this
routine fell into it anyway, underscoring that the warning alone doesn't
prevent the mistake; only tracing every clobbering call site does.

### CASM Phase 9 WP46 Frame Stack: four runtime-only defects (2026-07-26)

WP46 added the 16-level nested-include frame stack, `sourceFramePush`, and
automatic pop inside `sourceRefill`. It built clean, passed static review,
and still failed every real-traversal case on first run. Four production
defects were involved, each masking the next. All four were found only by
running real fixtures on real hardware -- none was reachable by reading
the code.

**1. `CasmSourceVmmCursorLo/Hi` is the bulk-refill read head, not the
logical parse position.** This is the durable trap. `sourceRefill`
installs up to 256 bytes per call, so for any file smaller than the buffer
the cursor already sits at the file's *end* while the lexer is still
parsing its middle. The logical position is
`cursor - (blockLen - blockIndex)`. `sourceFramePush` originally saved the
raw cursor as the parent's resume offset, so every pop resumed past all
remaining parent content. **Any future code that needs "where is the
parser right now" -- WP47's include-event recording especially -- must
apply the same correction, never read the cursor directly.**

**2. Provenance must be captured after a fetch, not before it.**
`lexerFill` snapshotted `CasmSourceFileId`/`LineLo`/`Hi`/`Column` before
calling `sourceNextByte`. That is correct for an ordinary byte but stale
whenever the same call resolves a child frame's EOF and triggers the
automatic pop: the byte delivered belongs to the restored parent, not the
abandoned child. Fixed with `CasmSourceResultFileId`/`LineLo`/`Hi`/
`Column` (`state.s`), written by `sourceFetchPhysical` at
`sfpHaveByte`/`sfpEof` -- the only layer that knows which span the byte
truly came from. Any stand-in `sourceNextByte` (e.g.
`tests/src/casm_include/casm_include.s`, which links no `source.s`) must
honor the same contract.

**3. A growing length field cannot serve as a traversal bound.** Depth-0
traversal was capped only by `CasmSourceLoadedLenLo/Hi`, which grows every
time `sourceAppendFile` appends an `.INCLUDE` child *mid-traversal*. A
top-level file with content after its own `.INCLUDE` therefore ran past
its own end into the appended child's bytes instead of hitting EOF. Fixed
with `CasmSourceTopLevelEndLo/Hi`, a fixed snapshot taken at
`sourceLoad`'s completion, before any child can exist. Nested frames
already had the equivalent in `CasmFrameEndOffsetLo/Hi`; depth 0 simply
never got one.

**4. Inserting code before a return path can clobber the return value.**
The fix-2 provenance capture added at `sfpEof` destroyed the
`CASM_SOURCE_EOF` value in `A` that the routine must still return,
surfacing as a spurious `CASM_DIAG_INVALID_SOURCE_BYTE`.

**A green test was concealing two cancelling bugs.** `frSinglePushPop`
passed before fixes 3 and 4 landed, for entirely the wrong reason: with
the resume offset wrong and no depth-0 cap, the pop re-read the *child's*
bytes a second time, but the parent's line counter had been correctly
restored to 4, so those re-read `C1`/`C2` labels were stamped lines 4 and
5 -- exactly the `P3=4, P4=5` the assertion expected. Fixing the overrun
made the test *start* failing, which is what exposed that `P3`/`P4` had
never been read at all. **A passing assertion on derived values (line
numbers) does not prove the underlying traversal is correct; two errors
can cancel.** Where practical, assert on something the bug cannot fake --
a byte offset, a push/pop event count, an identity -- not only on a
value that a wrong path might coincidentally reproduce.

**Method note.** Static review had been exhausted twice with wrong
conclusions before instrumentation settled it. What worked was printing
real state to screen (frame depth, label-line log, push/pop counts, raw
cursor offsets, catalog indices) and having the user run it. Two of the
false starts came from misreading my own debug output: a decimal-printing
routine read as hex (`A=25` decimal `$19`, not `$25`), and an X-register
clash inside the print helper that caused an endless loop. Verify the
instrumentation itself before trusting what it reports.

### CASM Phase 9 WP47: `.INCLUDE` goes live; structural vs. trusted invariants (2026-07-29)

WP47 wired the first real production `.INCLUDE` dispatch into `casmRunPass`
and added the ordered include-event log Pass 2 replays. Final CASM `0.1.49`
build 1196. In contrast to WP46, it passed its entire runtime matrix on the
first attempt — because WP46 had already absorbed the hard traversal work,
so WP47 built on a proven engine rather than a theoretical one.

**Make an invariant structural rather than merely trusted.** Phase 0C.19
requires Pass 2 to perform zero source-filesystem I/O. `includeCatalogLoad`
opens a file on a catalog miss, so calling it in Pass 2 would have been a
latent violation — and a miss is exactly what a corrupted replay produces.
The fix was factoring `includeCatalogLookup` (resolve + capture + find, no
load) out of it, so Pass 2's path is *incapable* of an open rather than
trusted not to attempt one. The invariant is then provable by reachability
instead of by instrumentation: `inputStreamOpen` has two call sites, the
only one reachable during a pass is inside `includeCatalogLoad`, and that
routine's only production caller sits in the `CASM_PASS_MODE_MEASURE`
branch. Prefer this shape over a runtime assertion whenever the call graph
can carry the guarantee.

**Two parents in different namespaces need a discriminator.** An
`.INCLUDE`'s parent is either a top-level root (identified by
`CasmSourceFileId`) or an already-included file (identified by its catalog
index). WP45/WP46 deliberately never cataloged top-level files, so those id
spaces overlap: root 0 and catalog record 0 are different files with the
same number. The 16-byte event record therefore stores a (kind, id) pair,
and `evmismatch1` in `tests/src/casm_event` exists specifically to prove a
frame-parent 0 never compares equal to a root-parent 0.

**A missing trailing event is invisible to per-site checks.** Per-`.INCLUDE`
correspondence cannot detect a Pass 2 that simply *stops early* — a replay
that ends before reaching an `.INCLUDE` never performs a disagreeing
comparison. That needs its own end-of-pass gate
(`includeReplayFinalCheck`, cursor == count), structurally parallel to
`emitCheckPassAgreement`. Whenever a consistency check is per-item, ask
separately what happens when the loop terminates early.

**Register-carried state across a constant load.** `crpParentIdentity` took
the frame index from `A` via `tax`, but `A` had already been overwritten by
the parent-kind constant stored two instructions earlier. It would have
indexed `CasmFrameCatalogIndex[0]` at *every* depth — coincidentally
correct at depth 1 (the only depth a two-level fixture reaches) and wrong
from depth 2 up, inheriting the wrong parent's device. Caught in code review
before runtime, and precisely why the three-level `casmip2` fixture exists.
Same coincidental-correctness family as WP46's cancelling-bugs finding
above: depth 1 is not a sufficient test of depth-indexed logic.

**A verification disk must have room to hold what it verifies.**
`casm_overflow_test.d64` was down to ~10 free blocks (WP34's combined-cap
pair alone occupies 277), and WP47's end-to-end check *writes* eight output
PRGs back to the disk it reads from. The fixtures moved to a new
`casm_include_test_d64` (574 blocks free). Also note `fileCreateOutput` uses
no `@:` replace prefix, so re-running an assembly whose output already
exists fails with a DOS file-exists error — plan fixture disks for repeated
runs, not one clean pass.

### Agent-driven VICE testing contract

- Agent-driven VICE tests must boot Command64 from the selected D64 before launching an
  application. The first screen line `Command 64-DOS Version` proves OS startup.
- Applications are launched by name from the Command64 shell, never through BASIC or
  VICE Autostart after the OS is resident. A prompt matching `c64[<device>]:>` proves a
  normal return to the shell; the device number is variable.
- `image.d64` is the clean OS image, `test.d64` contains existing harnesses but has no
  free directory entries, and `casm_overflow_test.d64` carries newer harnesses and
  fixtures. Other dedicated images may be selected by their test documentation.
- Agents use bounded observations and one clean recovery. Timeouts are not product
  failures without independent evidence; results distinguish product, harness, setup,
  and inconclusive outcomes. See `.agents/workflows/vice-mcp-testing.md`.
- Application commands use their documented Command64 names, not the physically truncated
  16-character D64 rendering. The `test_casm_passcheck` canary is launched by its full
  name using the MCP's `_` → PETSCII `$A4` conversion and newline-to-Return behavior.
- Observation deadlines are workload-specific. The 63-block `test_casm_passcheck` load
  exceeded short two- and five-second windows under true-drive emulation but subsequently
  completed with `CASM PASSCHECK: PASS`; its controlled canary budget is up to 60 seconds
  before the first assertion observation, without polling.

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


### CASM Phase 9 WP48 Included-Source Diagnostics

- Source provenance uses one packed byte without growing the frozen 39-byte
  token record: bit 7 clear identifies a top-level root, bit 7 set identifies
  an include physical-catalog entry, and bits 0-6 hold the bounded id.
- `sourceFetchPhysical` computes provenance after frame EOF/pop resolution, so
  each delivered byte carries the identity of the file it actually belongs to.
- Included-file names are rendered from the immutable VMM catalog through
  `includeCatalogRead`; rendering performs no filesystem I/O and degrades to
  `<INCLUDE?>` without masking the primary diagnostic if metadata reading fails.
- Tracebacks walk bounded frame arrays from innermost parent to root. The
  include-site location uses dedicated `CasmFrameSiteLineLo/Hi` and
  `CasmFrameSiteColumn` arrays. Resume line/column are post-statement traversal
  state and must never be displayed as the include site.
- Fatal source-line draining can reach child EOF and pop a live frame. WP48
  snapshots `CasmFrameDepth` at diagnostic entry for traceback and latches the
  diagnostic's packed file identity in `sourceDrainLineTail`; a byte delivered
  after frame pop is consumed but not appended to the child source echo.
- Unterminated-token lookahead can pop frames before fatal rendering. The packed
  catalog id recovers traceback depth from retained frame slots, and
  `CasmFrameRootFileId` retains the originating CLI root across multi-pop/root
  transitions.
- Measured MAIN envelopes after runtime correction: production `$4300` (85
  bytes headroom), `test_casm_pass1` `$4200` (242 bytes), `test_casm_frame`
  `$4100` (52 bytes), `test_casm_event` `$1D00` (225 bytes), and unchanged
  `test_casm_passcheck` `$4000`.
- WP49 consolidated verification confirmed the final Phase 9 implementation
  without production changes: CASM remains `0.1.50` build 1204 with 14,478 code
  bytes and 2,104 relocation points; all six Phase 9 harnesses, affected shared
  regressions, four independently built disk images, trusted-reference cases,
  bounded failures, cleanup/reuse cases, and runtime diagnostics pass. The final
  production `$4300` headroom is 85 bytes; the earlier 196-byte CMake comment
  was an intermediate WP48 measurement and was corrected under an approved
  documentation-only WP49 amendment.
- The user explicitly approved WP49 and Phase 9 completion on 2026-07-29.
  Phase 9 closes at CASM `0.1.50` build 1204; the approved verification-only
  WP49 package changed no production behavior and required no version increment.
  Master-plan Phase 10 remains inactive and separately gated. Progress and
  processing indication is a deferred optional feature outside the numbered
  phases.
- The user approved the Phase 10 Symbol Map and Listing governing plan on
  2026-07-29. `/M` uses definition-order `$HHHH LABEL` console rows with a
  header and total. `/L` uses a derived `.LST`, raw PETSCII/CR, exact 40-column
  rows, every physical source line, 4,096 fixed 16-byte metadata records, and a
  separate 65,536-byte emitted-byte mirror. Post-finalization listing failure
  retains the valid PRG and removes only the incomplete listing. WP50-WP55 are
  sequential and pending; each requires a dedicated approved plan. The verified
  `0.1.56` phase result receives a separate completion-only `0.2.0` promotion.
- WP50 reconciliation found that exact listing spans cannot come from the
  frozen token/lexer records or refill read head. The approved Phase 0C.20
  design uses four source-internal block/line-start bytes plus a seven-byte
  completed-line sidecar and `sourceTakeCompletedLine`. A Pass 2 transaction
  snapshots PC/byte cursor before parsing and commits after dispatch, with
  `.INCLUDE` committed before frame push. The 16-byte metadata ABI, explicit
  65,536-byte full flag, and diagnostic reservation `$39-$41` are frozen.
- The approved WP51 design requests each 64 KiB store as 65,535 bytes (the VMM
  wrapper rejects a zero request and rounds 65,535 to 16 pages), uses a dedicated
  64-byte mirror stage copied through shared `CasmVmmBuffer`, mirrors only after
  `emitRawByte` succeeds, and splits verification between storage and real-path
  capture harnesses. Production/test MAIN may be measured up to `$4C00`; WP51
  remains blocked by WP50.
- The approved WP52 design adds stateless definition-order
  `symbolsReadByIndex`, a map-owned 40-byte row buffer/private formatters,
  structural symbol-record validation, and locationless diagnostic `$42`.
  `test_casm_map` captures exact `diagPrintString` rows. Map owns no VMM/file
  resources, remains uncalled in production until WP54, and is capped at a
  smallest-aligned production envelope no larger than `$4F00`.
- The approved WP53 design adds `.LST` derivation, source-owned bounded span
  reads, explicit committed PRG state, dedicated listing SEQ ownership, and a
  replay serializer. Included headers render resolved `device:name`; byte
  continuations precede source continuations; a 41-byte row buffer aggregates
  into idle `CasmIoBuffer`. Post-commit failures retain PRG, diagnostics
  `$3D-$41` become active, and production is capped at `$5800`.
- The approved WP54 production sequence allocates `/L` stores after Pass 1
  rewind but before PRG creation, then checks/finalizes capture and PRG, closes
  source, commits PRG, writes listing, prints map, and finally prints the
  existing success line. One committed-aware artifact abort handles every fatal
  stage. `test_casm_phase10` verifies exact call/failure order; the production
  envelope is capped at `$5B00`.

### DASH System Dashboard (WP1-WP9, 2026-07-26 to 2026-07-30)

- Two new public OS services back DASH and nothing else reads private state:
  `DOS_GET_SYSTEM_INFO` (`$5C`) and `DOS_GET_APP_INFO` (`$5D`), both in
  `src/command64/api.asm`, returning fixed 24-byte records with
  buffer-unchanged-on-error semantics. Their handler bodies didn't fit below
  the pinned `$1000` `ApiStub`, so a new `ApiExt` segment was added
  (packed after `ShellExt`, below `AppTable`) — the first OS segment added
  specifically because sub-`$1000` space was full, not because of a memory
  layout change elsewhere.
- DASH itself is a seven-file dual-assembler (native CASM / ca65) source set
  under `src/external/dash/` (`dmain.s` entry, `.INCLUDE`-chaining the other
  six), assembled for real only by native CASM on hardware/VICE; the ca65
  `dash_ref` target is a non-circular cross-check only (`tools/reloc.py`
  diffs two links a page apart; CASM classifies operands during emission —
  neither can reproduce the other's defects). The shipping artifact is a
  reviewed hex manifest (`dash.ref.hex`), never a live build step, with a
  per-file `source_sha256` staleness gate.
- Every DASH page (System/Applications/VMM) is capability-gated on the
  public API record alone: a value that depends on VMM/REU state renders
  `N/A` when unavailable rather than a false zero, and the Applications
  page's `R` (running) flag renders the raw `APT_FLAG_RUNNING` bit as-is
  (truthfully always `-` today — no loader path sets it, Task Warrior #42)
  rather than inferring running state any other way.
- The VMM Test page's cleanup contract: exactly one `DOS_FREE_MEM` attempt on
  every post-allocation exit path (success or failure), and a failed free
  permanently disables retesting for that run rather than risking a second
  allocation on top of an unfreed one. This is the same "one owner, one
  cleanup pass, no silent retry that could double up" shape as CASM's own
  `resourcesCleanup`.
- Interim, explicitly-labeled provenance is an accepted project pattern, not
  just a DASH one-off: WP9 shipped `dash.prg` from the `dash_ref` ca65
  cross-check (`--allow-host-bytes`) with a truthful `# provenance:` line,
  user-approved as sufficient for now rather than blocking on a native-CASM-
  on-hardware run. (Superseded: the manifest has carried real
  native-CASM-on-hardware provenance since Phase 12 WP71.)

**DASH Modernization (DASH `0.1.4` -> `0.2.0`, DASH-MOD WP1-6, closed
2026-09-01, `feature/casm-phase14`).** DASH's seven sources were rebased
onto the modern shared CASM/ca65 feature set with **no user-visible
behaviour change** and byte-for-byte ca65<->CASM identity at every step.
`4766 -> 4579` bytes; manifest sha256 `3238b786... -> 3b4d0693...`. Key
outcomes and reusable findings:

- **`@local` everywhere (WP2).** Every routine-internal helper label is a
  cheap local. The eligibility rule: a label is `@local`-safe iff every
  reference is a branch/jump within its own routine's `NAME:`-to-`NAME:`
  span; a mis-localized cross-routine label fails to assemble (it cannot
  silently produce wrong bytes), and byte-identity vs the manifest is the
  backstop.
- **Named constants (WP3), and two CASM expression-grammar limits.**
  ~110 constants in `dmain.s`'s prologue. **(a)** A CASM named-constant
  definition's RHS must be a **bare literal** — `NAME = 1<<0` gives
  `EXPECTED NEWLINE`; operators (`* + > <<`) are fine at instruction
  operands, just not in a `NAME = ...` line. **(b)** CASM's expression
  grammar has **no comparison operator** (only `+ - | ^ & << >> * /`), so
  a native-CASM `.ASSERT` is nonzero-truthiness only. DASH's structural
  invariants (`PAGECOUNT = 3`, the ZP map, the API `$40-$5F` band, the
  `PAGEROUTINETABLE` size) therefore live in `dash_wrapper.s` — the
  ca65-only wrapper, with real operators — checked on every `dash_ref`
  build; the ca65<->CASM byte cross-check covers the CASM side. Both are
  now documented in `src/external/dash/AGENTS.md`.
- **Behaviour-preserving refactors (WP4/WP5).** WP4 replaced the key
  ladder with an F-key range check (`page = key - KEY_F1`) + one
  `AND #$DF` case-fold for the `T`/`R`/`Q` shifted-charset variants
  (fold uniqueness proven: `b & $DF == $54` iff `b in {$54,$74}`). WP5
  collapsed `DRAWFRAME`'s 7 row loops into `COPYFRAMEROW` (via the
  existing `COMPUTEROWADDR`), `DAPPPRINTFLAGS`'s 4 cells into a table
  loop, `dsys.s`'s 12 row openers into `DSYSLABEL`, and removed the dead
  `PRINTAT`. Each byte-changing WP re-ran a full ca65<->CASM +
  native-CASM-under-VICE + runtime pass and re-baselined the manifest
  once at its close.
- **`dvmm.s` deferred (WP5 scope decision).** A `DVMMLABEL` opener helper
  and `.WORD` enum->string tables for its 3 state/stage ladders are clean
  wins (~-100 bytes, flatter) but touch capability-gated display logic;
  recorded as a "WP5b"/post-increment follow-up.
- **Consolidated gate (WP6).** Fresh together re-verification, version
  bump, `AGENTS.md` consolidation, relocation audit, user runtime matrix
  at `$3800` / `$5000` / `$9000` (`LOAD DASH <hex>` / `RUN <hex>`, the
  WP84 precedent). This is the baseline Phase 14 WP92's gate re-verifies
  against.

### CASM Phase 10 Symbol Map/Listing Contract (WP50-55, closed 2026-08-08)

- `/M` and `/L` add deterministic developer-usability output without changing
  assembled PRG/R6 bytes, source traversal, include replay, relocation
  behavior, diagnostics provenance, or cleanup guarantees — both were already
  parsed as duplicate-rejected flags since an earlier phase; Phase 10 removes
  only their `NOT IMPLEMENTED` runtime gate.
- `/M` prints a definition-order symbol map (`map.s`, stateless
  `symbolsReadByIndex` iteration from index 0, never hash-bucket order): a
  `SYMBOL MAP` header, `$HHHH LABEL` rows in original case-sensitive spelling,
  and a decimal `NNN SYMBOLS` total supporting the full 0-512 symbol range.
  Map printing allocates no map-specific VMM store and performs no sorting;
  it stays uncalled in production until WP54 wires it in after listing
  success (a listing failure suppresses the map).
- `/L` derives a `.LST` name from the final PRG output name (device prefix
  preserved, final dot-suffix replaced or `.LST` appended) and writes raw
  PETSCII with CR row terminators: a `FILE HH: NAME` header on every packed
  physical-file-identity change, and fixed 40-column detail rows —
  `HH:LLLLL PPPP BB BB BB BB` then up to 14 exact source bytes — with
  independent byte and source continuation rows (neither count coupled to the
  other). Every physical source line appears in actual traversal order,
  including `.INCLUDE` lines before their child traversal, blank/comment
  lines, and the final unterminated line; synthetic inter-file newlines are
  not listed rows.
- `/L` conditionally allocates exactly two VMM stores when active: a
  metadata store of 4,096 fixed 16-byte records (exactly 65,536 bytes,
  frozen offsets: packed file id, physical line, source VMM offset/length,
  starting PC, byte-stream offset/count, flags, reserved) and an
  emitted-byte mirror of up to 65,536 Pass-2 source-generated bytes (mirrored
  at `emitByte`, explicitly excluding the raw PRG header/R6 format bytes
  `emitRawByte` also carries — never a valid listing-byte hook). Worst-case
  CASM VMM registry occupancy is 6 of 8 slots with both stores active.
  `/M` without `/L` acquires neither allocation.
- Listing capture is a transaction around the shared statement path, not a
  syntax tree or general instruction-event IR: capture starting PC and mirror
  cursor before parsing, dispatch through the existing parser/emitter path
  unchanged, and commit one metadata record after dispatch using the
  source-owned completed-line sidecar (`sourceTakeCompletedLine`, frozen at
  WP50) rather than inferring parse position from the bulk-refill cursor.
- Failure ownership is split by PRG finalization state: any listing capture/
  bound/VMM failure before PRG finalization is fatal and the existing
  incomplete-PRG abort path applies; a listing create/write/short-write/close
  failure *after* the PRG is valid preserves the listing failure as primary,
  deletes only the incomplete listing, retains the valid finalized PRG,
  suppresses `/M`, and still exits through central cleanup — listing
  ownership state is tracked separately from PRG ownership/validity state.
- WP50-55 froze the design/ABI, added listing stores and capture events,
  built the map module, added `.LST` serialization/cleanup, wired production
  integration, and closed with independent verification and a user-approved
  runtime walkthrough — Phase 10 is the master plan's "CASM 0.2 developer-
  usability release." Completion promoted CASM `0.1.56` to `0.2.0` build
  `1260` as a version-only change (no assembly/listing/map behavior changed
  beyond the version/build artifact itself).
- Governing: `brain/plans/2026-07-29-casm-phase10-symbol-map-listing.md`
  (parent, with each WP50-55's own dedicated plan linked from it).

### CASM Phase 11 Base-Release Hardening Contract (WP56-63, Phase 11 complete 2026-08-13)

- Phase 11 adds no new language feature, directive, or output format. It is a
  hardening/certification phase over the complete `0.1`/`0.2` base release
  (every module built across Phases 1-10), not a features phase: across all
  of WP56-61 the only production source change in the entire phase is a
  single instruction — `CLD` added as the literal first instruction of
  `casm.s`'s `start:` entry point (WP60 Increment 3), hardening against a
  hypothetical stale decimal flag reaching a future `ADC`/`SBC` path, since
  CASM has no supported decimal-mode entry contract of its own. Every other
  work package (WP56, 57-59, 60's certification work, 61's determinism work)
  is test/verification/infrastructure, changing no assembled behavior.
- WP56 (contract reconciliation) triaged 3 carried-forward debt items from
  Phase 4: `CasmOutputCreated`'s naming was retired as a stale premise (the
  real issue is a separate `fileCreateOutput` `@0:`-replace-marker gap,
  tracked independently); the missing entry `CLD` was confirmed a real narrow
  hardening gap and assigned to WP60; the missing Phase 4
  `brain/KNOWLEDGE.md` section was confirmed and assigned to WP62 (this
  section).
- WP57 designed and built real fault-injection test infrastructure: a
  runtime hook that patches the fixed `OS_API = $1000` `jmp apiHandler` stub
  to install a `faultStubEntry`, letting file-open/read/write/close/delete
  and VMM alloc/free/transfer calls be made to fail deterministically without
  needing a genuinely full disk or exhausted registry. WP58 applied it across
  every file/VMM-touching module (`fileio.s`, `source.s`, `symbols.s`,
  `reloc.s`, `include.s`, `vmm_store.s`), closing a gap Phase 10's own WP55
  had disclosed but not resolved (`CREATE_FAILED`/`WRITE_FAILED`/
  `CLOSE_FAILED`/`DELETE_FAILED`/`SHORT_WRITE` and the no-REU/OOM branches
  had never been independently fault-injected anywhere in the codebase).
  Both changed test infrastructure only.
- WP59 hardened `listing.s`/`map.s` — the newest, least individually audited
  modules — auditing every exported routine's carry propagation, register
  clobbers, stack balance, and zero-page/BSS ownership against its own header
  contract, and fixing two harness-only defects plus one retryable-close
  compensation fix (D1/D2) with no storage/public-ABI change. No production
  defect was found beyond the close-compensation fix; CASM advanced only its
  version/build banner (`0.2.0` to `0.2.1` build `1264`).
- WP60 closed the two remaining Phase 4 carried-forward items (the `CLD`
  fix above) and exhaustively certified opcode/addressing-mode coverage:
  an independently-derived oracle for all 151 legal NMOS 6502/6510 tuples
  was mechanically reconciled one-to-one against `opcodes.s`'s mask/offset/
  byte/length tables, plus a 52-row boundary register spanning numeric
  literal, addressing width, branch, PC, source, symbol, VMM, and relocation
  domains. One real production defect was found and left explicitly
  deferred (a one-byte-source phantom-EOF-byte defect in
  `sourceLoad`/`sourceNextByte`, tracked separately, not fixed under WP60).
  CASM advanced to `0.2.2` build `1266` (version-only banner change beyond
  the single `CLD` byte).
- WP61 proved determinism — identical input produces byte-identical output
  across PRG, R6 relocation, `/L` listing, and `/M` map, verified by
  dual-assembling representative fixtures (small-static, small-relocatable,
  and the 151-statement exhaustive `casmopall.s`) and comparing both runs —
  and closed 4 of WP60's residual boundary items (`FORCE_ABS` stability
  across a genuine two-pass re-resolution; the 65,535/65,536-byte source
  extent boundary; symbol/token name-length-32 rejection; the empty-source-
  file row re-scoped as a tooling gap, since `cc1541` cannot write a
  zero-byte SEQ entry). WP61 found and fixed one build-system-only defect
  (a test-disk directory-overflow oversight) and zero production defects;
  CASM's version/build stayed at `0.2.2` build `1266` throughout (no
  production change occurred, per the project's bump-only-if-changed
  policy).
- The phantom-EOF-byte defect (Taskwarrior UUID
  `882433f0-cde1-4849-8b3c-df32613518c3`) remains open and explicitly
  deferred past Phase 11, tracked as its own item rather than blocking
  either WP60 or WP61 completion.
- WP62 (documentation sync, closed 2026-08-12) backfilled this section
  (Phase 4, 10, and 11 had all been missing from `brain/KNOWLEDGE.md`
  until WP62), clean-room re-synced `wiki/casm-programmers-reference.md`
  and the `wiki/casm-utility.md`/`docs/casm-utility.md` pair, and added
  the missing WP61 `CHANGELOG.md` entry. No production/version change.
- WP63 (verification, walkthrough, completion gate) is Phase 11's closing
  work package: the first-ever consolidated live-VICE re-run of every
  `test_casm_*` harness across all six CASM disk images in one continuous
  session (never previously exercised — WP56-61 each verified only their
  own delta). That consolidated run **found a genuine, previously-
  undetected defect**: six fault-injection test harnesses
  (`casm_faultvmm.s`, `casm_faultsource.s`, `casm_freloc.s`,
  `casm_finc.s`, `casm_fsym.s`, `casm_faultinject.s`) call `faultInstall`
  (`tests/src/casm_faultinject/faultstub.inc`), which patches the fixed,
  OS-resident `$1000` OS_API dispatch vector to redirect through that
  harness's own `faultStubEntry`, but never call `faultUninstall` to
  restore it before their own `DOS_EXIT` — leaving `$1000` dangling into
  that harness's own (about-to-be-overwritten) memory once the next
  program loads at the same address, corrupting every OS_API call the
  next program makes in the same session. `casm_flist.s`/`casm_flmeta.s`
  already showed the correct paired `faultInstall`/`faultUninstall`
  pattern; the six single-case harnesses above never picked it up. Fixed
  by adding `jsr faultUninstall` before `DOS_EXIT` in all six. Test
  infrastructure only — no production CASM source, ABI, diagnostic, or
  output byte changed; CASM's own version/build (`0.2.2` build `1266`)
  is unaffected. Full detail, root-cause evidence, and post-fix
  verification (all 28 harnesses + 3 `comp` cross-checks live-reverified
  PASS) in
  `brain/walkthroughs/2026-08-12-casm-phase11-wp63-verification-walkthrough-completion-gate.md`.
  **WP63 and Phase 11 (WP56-63) closed 2026-08-13, user-approved.**
- Governing: `brain/plans/2026-08-08-casm-phase11-base-release-hardening-documentation.md`
  (parent, with each WP56-63's own dedicated plan and review/walkthrough
  linked from it, and `brain/task.md`'s WP56-63 entries for the full
  per-increment record).

### CASM Phase 12 WP64 Contract Freeze — Expression Evaluator Architecture and Relocation Algebra (frozen 2026-08-13)

Phase 12 ("Constants and Expanded Expressions", target CASM `0.3`) is
CASM's first *feature* phase since Phase 10 — Phase 11 was hardening-only.
WP64 is a design-only contract-freeze work package, mirroring Phase 6A's
own precedent: no production code change, but subsequent Phase 12 work applies
this expression/relocation contract wherever relevant. Governing plan:
`brain/plans/2026-08-13-casm-phase12-constants-expanded-expressions.md`;
WP64's own plan:
`brain/plans/2026-08-13-casm-phase12-wp64-contract-freeze.md`. Both
approved 2026-08-13.

**Current-state findings this contract is built on** (traced directly
against source, not assumed):

- `expr.s`'s `exprEvaluate` (expr.s:68-230) is a single flat `.proc`
  implementing exactly `['<'|'>'] primary [('+'|'-') NUMBER]` — no
  operator stack, no precedence, no parentheses. `CASM_EXPR_FLAG_
  RELOCATABLE` is set (expr.s:143-154) whenever the primary is an
  identifier *and* the whole assembly is running in relocatable mode —
  never for a bare number, and stripped again by a `<` (low-byte)
  extraction (expr.s:214-220).
- `reloc.s`'s relocation table is **purely a location marker**:
  `relocRecord` (reloc.s:83-143) records only a code offset. The actual
  value (symbol + addend) is baked into the emitted bytes *before* that
  entry is recorded (`emit.s:549-594`). There is no formula stored
  anywhere. Consequence: a relocatable value can only ever be one symbol
  plus a compile-time addend — already supported today, for free. Two
  symbols together, or a relocatable symbol scaled/shifted by a new
  operator, are not representable as a single relocation entry and are
  not semantically valid under a linear +delta patch regardless.
- `symbols.s`'s symbol record (`common.inc:1006-1023`) has only one flag
  bit defined (`CASM_SYMBOL_FLAG_DEFINED`); bits 1-7 are free. Every
  symbol today is a label (only `casm.s:416`'s `crpLabel` calls
  `symbolsInsert`) — there is no existing "constant" kind.
- A leading `(` at the start of an operand is unconditionally consumed by
  `posOperandDispatch`/`posIndirect` (`parser.s:276-287, 374-415`) for
  6502 indirect addressing, before the expression evaluator ever runs —
  hand-verified directly, no fallback path exists for treating a leading
  `(` as a generic sub-expression opener.
- `parserParseExpressionValue` (`parser.s:492-587`) is the single shared
  choke point all three operand-parsing modes (immediate, absolute,
  indirect — `parser.s:309, 318, 389`) call into `exprEvaluate` through —
  the exact integration boundary the new evaluator replaces. It also
  derives `CASM_PARSER_STMT_FORCE_ABS` independently from `CASM_EXPR_
  FLAG_SYMBOL_DERIVED` (any resolver success, resolved or not),
  separately from `RELOCATABLE` — confirmed this doesn't interact with
  the new static-only-operator rule, since a rejected relocatable operand
  never reaches a successful result in the first place.
- Envelope headroom measured directly via `ld65 -m` re-link (not
  assumed): CODE+RODATA+BSS = 21,646 of 21,760 (`$5500`) bytes used —
  **114 bytes free**.

**Contract, frozen** (user-confirmed scoping decisions, 2026-08-13):

1. **Relocation representability rule**: a value is relocatable only if
   it is a single symbol reference (label, relocatable named constant, or
   the current-address symbol) optionally combined with exactly one
   static `+`/`-` addend. Any new operator (`*`, `/`, `<<`, `>>`, `&`,
   `|`, `^`, unary `-`/`~`) applied to a relocatable operand is rejected
   with `CASM_DIAG_EXPR_RELOC_UNSUPPORTED` — never silently computed.
   This is the actual representability ceiling, not a conservative
   choice.
2. **Parenthesization rule**: `(expr)` is valid only as a sub-expression
   following a binary operator, never as an operand's entire content —
   preserves indirect-addressing's existing exclusive claim on a leading
   `(` with zero lookahead disambiguation needed.
3. **Evaluator architecture**: precedence-climbing (not full recursive-
   descent), replacing `exprEvaluate`'s core while reusing its existing
   `exprParseNumeric` leaf-token helpers (expr.s:296-491) unchanged.
   Tentative precedence tiers, tightest to loosest: unary `-`/`~` →
   `*`/`/` → `<<`/`>>` → `&` → `^` → `|` → `+`/`-` (C-family/ca65
   convention). Final tier ordering is WP67's own implementation
   deliverable, not fixed here.
4. **Named constants**: new `CASM_SYMBOL_FLAG_CONSTANT = %00000010`,
   sharing the existing 512-entry table/128-bucket hash — no new table,
   no capacity change. Requires updating `map.s:130-131`'s exact-flags
   corruption check to accept the new bit. Redefinition (constant↔label
   or same-kind) reuses the existing `CASM_DIAG_DUPLICATE_SYMBOL`; a new
   `CASM_DIAG_EXPR_CIRCULAR` covers self-referential definitions
   specifically. Exact directive syntax is WP65's own deliverable.
5. **Current-address symbol**: tentatively `*`, disambiguated from
   multiplication purely by parser position (leaf/primary position is
   always current-address; binary-operator position is always
   multiplication) — no new lexer-level distinction needed. Relocatable
   by construction, via the same classification path as a label.
6. **New diagnostics** (next free slot after `CASM_DIAG_PHASE10_WP52_LAST
   = $42`):

   | Code | Name | Meaning |
   | --- | --- | --- |
   | `$43` | `CASM_DIAG_EXPR_CIRCULAR` | Named constant's definition is directly or transitively self-referential |
   | `$44` | `CASM_DIAG_EXPR_DIV_ZERO` | Division by a static zero |
   | `$45` | `CASM_DIAG_EXPR_RELOC_UNSUPPORTED` | A relocatable operand reached a static-only operator |

   `CASM_DIAG_PHASE12_WP64_LAST = $45`. Later WP65-70 increments may add
   further diagnostics sequentially from `$46`, following the same
   `.assert`-contiguity style as every prior phase
   (`common.inc:721-769`) — not reserved speculatively here.
7. **Envelope budget**: rough estimate +1,550–2,600 bytes total across
   all of Phase 12 against only 114 free bytes today. Recommends
   requesting a `$5500` → `$6000` `PRG_SIZE_HEX` bump (a round-page step,
   matching this project's existing bump convention) as part of WP65's
   own plan, once WP65 gives a firmer number for its own slice.
8. **Lowercase-PETSCII convention** applies to every new token spelling
   and design-doc/implementation example this phase introduces (see
   memory `reference-c64-lowercase-petscii-convention` — real C64
   platforms are single-case, Command64's mixed-case charset is an
   anomaly).

No production source changed by WP64. WP65 (named constants) is next,
each subsequent WP still requiring its own detailed plan and separate
approval before any source edit, per
`.agents/workflows/phased-implementation-planning.md`.

### CASM Phase 12 WP65 Named Constants — As-Built (complete 2026-08-13)

`identifier = expr` named-constant definitions, implementing WP64's own
frozen contract. Plan:
`brain/plans/2026-08-13-casm-phase12-wp65-named-constants.md`. Walkthrough
(live VICE evidence): `brain/walkthroughs/2026-08-13-casm-phase12-wp65-
named-constants.md`. Branch `feature/casm-phase12-wp65`.

**Symbol record** (`common.inc`, 64-byte record unchanged): Flags byte
gained `CASM_SYMBOL_FLAG_CONSTANT` (`%00000010`), `_RESOLVED`
(`%00000100`), `_LABEL_DERIVED` (`%00001000`) alongside the existing
`_DEFINED`. Offsets 37-43 of the previously-reserved padding now hold a
deferred-reference bookmark: `REF_VMM_LO/HI` (absolute source position),
`REF_LEN`, `REF_ADDEND_LO/HI`, `REF_SIGN`, `REF_EXTRACT` — meaningful only
while `CONSTANT` is set and `RESOLVED` is clear; zeroed once resolved
(both by `ppsConstant`'s own numeric-immediate path and by the resolution
sweep's write-back), keeping `map.s`'s "reserved padding must be
zero-filled" invariant intact for every valid record shape.

**Absolute source-position bookmark** (new, `state.s`/`source.s`/
`lexer.s`): `CasmSourceResultOffsetLo/Hi` — the absolute offset, within the
single shared VMM allocation `sourceLoad`/`sourceAppendFile` write every
file (top-level and included) into permanently, of the byte just
delivered. Computed in `sourceFetchPhysical` as `CasmSourceVmmCursor -
CasmSourceBlockLen + CasmSourceBlockIndex` (block start plus in-block
position), *not* `CasmSourceOffsetLo/Hi` (a per-span counter reset at
every file/include boundary — confirmed unusable for this purpose by
tracing, not assumed). Propagated through `CasmLookaheadOffsetLo/Hi`
(`lexerFill`) into `CasmTokenStartOffsetLo/Hi` (`lexerTokenReset`),
mirroring the existing FileId/Line/Column provenance-stamping pattern
exactly — populated for every token, not just identifiers. This is what
lets a deferred constant reference be re-fetched later (a single
`vmmWindowRead` against `CasmSourceVmmSlot`, now exported) without storing
a copy of the name or re-scanning source text.

**Resolution sweep** (`casmResolveConstants`/`crcResolveChain`, `casm.s`):
runs once at the existing Pass1→Pass2 boundary (after `CasmPass1FinalPc`
is snapshotted, before `sourceRewind`) — by then every label's address and
every constant's name (though not necessarily its value) are already in
the symbol table. For each still-unresolved constant: an iterative
(non-recursive, to bound 6502 stack usage) walk follows the deferred
reference chain, marking a 512-bit "visited this walk" bitmap
(`CrcBitmap`) for cycle detection and recording the path (`CrcChainLo/Hi`,
bounded by `CASM_CONST_CHAIN_MAX = 32`) to unwind addends from the
resolved base back to the start once found. A label, or an
already-resolved constant, terminates the walk (base value); revisiting a
bitmap-marked index is `CASM_DIAG_EXPR_CIRCULAR`; a name that resolves to
nothing at all is `CASM_DIAG_UNDEFINED_SYMBOL`; exceeding the chain bound
is treated as circular too. `CASM_SYMBOL_FLAG_LABEL_DERIVED` propagates
transitively through the whole unwound chain, not just the node adjacent
to the label — needed so `expr.s`'s relocatable classification (below) is
correct for `x = y`, `y = someLabel` as well as `x = someLabel` directly.
New `symbolsUpdateByIndex` (`symbols.s`) persists each resolved node via a
read-modify-write against its own record index.

**`symbolsInsert`/`symbolsLookup` ABI** (`symbols.s`): `symbolsInsert` no
longer hardcodes `CASM_SYMBOL_FLAG_DEFINED` — every caller (production and
test) now sets `CasmSymbolInsertFlags` explicitly first, formalizing what
was previously implicit. `symbolsLookup`'s `CASM_RESOLVE_*` view grew a
6th field, `CASM_RESOLVE_SYM_FLAGS` (the matched record's own Flags byte),
letting a caller distinguish a label from a constant — and a resolved
constant from an unresolved one — without a second lookup.

**`expr.s` relocatable classification**: previously, `CasmExprRelocatableModeIn`
applied unconditionally to any resolved identifier (correct when every
symbol was a label). Now: a label keeps that unconditional behavior
unchanged (zero regression risk on the best-tested path); a *resolved*
named constant is relocatable only when `CASM_SYMBOL_FLAG_LABEL_DERIVED`
is also set — a pure numeric constant is never relocatable regardless of
mode. An *unresolved* constant (only reachable during Pass 1, before the
sweep runs — Pass 2 never sees one) takes the unconditional path, which is
provably inert since Pass 1 never consumes `RELOCATABLE`.

**Diagnostics**: `CASM_DIAG_EXPR_CIRCULAR` ($43, WP64-reserved) is the only
one of WP64's three reserved Phase 12 codes WP65 actually raises;
`$44`/`$45` stay declared-but-unraised until WP68. Locationless (like
`CASM_DIAG_SYMBOL_MAP_INVALID`): the resolution sweep runs after the live
lexer/parser state a source-position diagnostic depends on has already
moved on, and the record's bookmark is a raw byte offset, not a
line/column, with no cheap reverse-lookup available.

**Known pre-existing limitation surfaced, not introduced**: rerunning
`casm` against a source whose output name already exists on disk fails
`OUTPUT WRITE FAILED` (`fileCreateOutput` has no `@0:`-style replace
marker — matches memory `project-casm-filecreateoutput-no-replace`,
recorded before WP65, not a regression).

**Envelope**: `PRG_SIZE_HEX` `$5500`→`$6000` (WP64's own recommendation).
Several test-harness envelopes bumped to absorb the shared-module growth
(`parser.s`/`lexer.s`/`state.s`/`source.s`/`symbols.s`/`expr.s` are linked
whole into many harnesses regardless of whether each one exercises the
constant path). `test_casm_faultvmm` relocated from
`casm_overflow_test_d64` (reached 0 free blocks) to `casm_listing_test_d64`,
mirroring `test_l15release`'s own prior identical move.

### CASM Phase 12 WP66 Current-Address Symbol — As-Built (complete 2026-08-14)

`*` as a new expression primitive, evaluating to `CasmPc` (the address the
next emitted byte will occupy — the same value a label defined at that
exact point would get), relocatable by construction, implementing WP64's
own frozen contract. Plan: `brain/plans/2026-08-14-casm-phase12-wp66-
current-address-symbol.md`. Walkthrough (live VICE evidence):
`brain/walkthroughs/2026-08-14-casm-phase12-wp66-current-address-symbol.md`.

**Token** (`common.inc`): `CASM_PETSCII_ASTERISK = $2A`, `CASM_TOKEN_STAR =
$11` (bumping `CASM_TOKEN_COUNT` to `$12`), a new `lexerPunctBytes`/
`lexerPunctTypes` row (`lexer.s`). No new diagnostic — a `*` in leaf/
primary position is never a syntax error, per WP64's own framing, and
every downstream failure mode (bad addend, unsupported continuation) is
already covered by the identifier path's existing diagnostics.

**`exprEvaluate` (`expr.s`)**: a new `curAddr` primary-dispatch arm
(alongside `NUMBER`/`IDENTIFIER`), reached without ever calling the
resolver callback — `*`'s value is always immediately known, unlike an
identifier's possible forward reference. New `.import CasmPc` from
`emit.s` (a plain exported BSS word; no ABI change to either module).
Sets `RESOLVED`+`SYMBOL_DERIVED` unconditionally (so
`parserParseExpressionValue`'s `FORCE_ABS` derivation, keyed off
`SYMBOL_DERIVED` alone, protects `*` exactly as it would a label — even
though `*` never goes through the resolver path that normally sets this
bit) and `RELOCATABLE` iff the caller's relocatable-mode input is
nonzero — the identical unconditional check the identifier path applies,
without WP65's `CONSTANT`/`LABEL_DERIVED` gating (irrelevant here, since
`*` is not symbol-table-derived at all). Falls through into the
identifier arm's own shared `consumeIdentifier` tail (addend, extraction,
continuation) rather than duplicating it — `*+N`/`*-N` and `<*`/`>*` work
for free from this reuse.

**`ppsConstant`/`crpConstant` (`parser.s`/`casm.s`)**: `name = *` ships in
this WP (a scoping fork not settled by WP64 or WP65 — user-confirmed
2026-08-14 to include it rather than defer). `ppsConstant` gained a third
`@primary` arm reusing the identifier arm's own addend-capture code
verbatim (same `exprParseAddend`/`exprGetResult` sequence into
`CasmConstantRefAddendSign/Lo/Hi`), but sets a new `CasmConstantIsCurAddr`
flag instead of leaving `CasmConstantResolved` clear — there is no name to
look up (`CasmConstantRefVmmLo/Hi/Len` stay zero) and no forward-reference
problem to defer, so resolution doesn't wait for `casmResolveConstants`'
Pass1→Pass2 sweep. `crpConstant` computes `CasmPc [+/- addend][extraction]`
inline the instant this Pass 1 statement runs (the same fact `crpLabel`
itself already relies on), then re-zeros the addend/extraction staging
fields so the record's reserved-padding invariant (`map.s`) holds for this
now-resolved record exactly as it does for a numeric RHS. Flags
computation extended: `CASM_SYMBOL_FLAG_LABEL_DERIVED` is now OR'd in
whenever `CasmConstantIsCurAddr` is set, alongside `RESOLVED` — a
combination no other RHS kind produces (a numeric RHS is resolved but
never label-derived; an unresolved identifier RHS is neither yet). Without
this, `crpConstant`'s existing RESOLVED-only flag logic (correct for a
numeric RHS) would have silently classified `name = *` as static.

**Live-verified fixtures** (`casmcuraddr1.s`/`casmcuraddr2.s`,
`cmake/GenerateCasmTestFixtures.cmake`, packed onto `casm_include_test_d64`
alongside WP65's own `casmconst1-4.s`): `bufstart = *` referenced via
`<bufstart`/`>bufstart` in later operands, and bare `*` combined with
extraction and an addend in one operand (`lda #<*+3`) — both produced
`CASM: INPUT VALIDATED` and PRG bytes matching hand-computed expectations
exactly, extracted directly from the disk image.

**Envelope**: no change to production `casm`'s own `$6000` cap (fit
inside WP65's existing headroom, matching WP64's own +50-100 byte
estimate for this sub-feature). Three test-harness envelopes bumped by
one round-page step each to absorb `expr.s`/`parser.s`/`lexer.s`'s shared
growth: `test_casm_pass1` (`$5300`→`$5400`), `test_casm_frame`
(`$5300`→`$5400`), `test_casm_include` (`$1200`→`$1300`). The
`test_casm_include` bump grew that PRG by a block, leaving
`casm_overflow_test_d64` one block short — `test_casm_freloc` (smallest,
most self-contained PRG on that disk) relocated to `casm_include_test_d64`
(~540 free blocks), mirroring WP52/WP65's own prior same-shaped disk-
capacity relocations.

### CASM Phase 12 WP67 Parentheses and Explicit Precedence — As-Built (complete 2026-08-14)

Precedence-climbing evaluator architecture (WP64's own design, built for
the first time here) plus parenthesized sub-expressions, implementing
WP64's frozen contract. Plan: `brain/plans/2026-08-14-casm-phase12-wp67-
parens-precedence.md`. Walkthrough (live VICE evidence): `brain/
walkthroughs/2026-08-14-casm-phase12-wp67-parens-precedence.md`.

**Architecture** (`expr.s`): `exprEvaluate`'s previously-flat body split
into three cooperating procs — `exprEvaluate` (extraction prefix, then
hands off), `parsePrimary` (`NUMBER`/`IDENTIFIER`/`*`/`(group)`), and
`parseOperatorTail` (the `+`/`-` loop, recursing into `parsePrimary` for
each RHS). A parenthesized group recurses into the same `parsePrimary`+
`parseOperatorTail` pair for its own content, bounded by a new
`CASM_EXPR_PAREN_MAX_DEPTH = 8` counter (`CasmExprParenDepth`) since each
nesting level costs a `JSR` against the 6502's small hardware stack.
Since `parsePrimary` reuses the same `CasmExprResultRecord` for whatever
it's currently parsing, `parseOperatorTail` saves the running
accumulator's `VAL_LO/HI`/`FLAGS`/`SYMBOL_ID_LO/HI` (5 bytes) on the
hardware stack via `PHA`/`PLA` around each recursive RHS parse — net-zero
growth per loop iteration (a long `+`/`-` chain doesn't accumulate stack,
only genuine `(` nesting does).

**A real scoping fork user-confirmed 2026-08-14, not assumed**: WP67
lifts the pre-existing restriction that only `IDENTIFIER`/`*` primaries
could take a trailing addend — `NUMBER` now reaches the same shared
operator loop, so `1+1` and `2+3` (bare or inside parens) succeed instead
of `CASM_DIAG_EXPR_UNSUPPORTED`. This changed two existing fixtures'
(`sNumAdd`/`sNumSub`) expected outcome from a diagnostic to a computed
value — a deliberate, disclosed change matching WP67's own stated purpose
(generalizing `+`/`-` into a real operator tier usable by any primary),
not a silent regression.

**Relocation representability, enforced per operator application** (WP64's
frozen rule, first implemented here even though `+`/`-` remain the only
operators): each combine checks both operands' `RELOCATABLE` bit;
combining two relocatable components (`label1+label2`,
`label+(label2)`, `(label1)+(label2)`) is `CASM_DIAG_EXPR_RELOC_
UNSUPPORTED` — the relocation table can only ever represent one symbol +
a static addend. A static value plus one relocatable value, in either
order and however deeply parenthesized, always succeeds. Both new
diagnostics (`CASM_DIAG_EXPR_RELOC_UNSUPPORTED = $45`,
`CASM_DIAG_EXPR_PAREN_TOO_DEEP = $46`, both WP64-reserved/newly-assigned)
needed message-table entries added to `diagnostics.s`
(`msgExprRelocUnsupported`/`msgExprParenTooDeep`, both printed *with*
source-location context via `diagPrintSourceContext`, unlike the
locationless `CASM_DIAG_EXPR_CIRCULAR`/`CASM_DIAG_SYMBOL_MAP_INVALID`
special cases) — otherwise both would have silently fallen through to
the generic "unknown diagnostic" message, discovered live before
shipping, not assumed correct from the code alone.

**`posImmediate`'s own token whitelist** (`parser.s`, gates what can
follow `#` before `parserParseExpressionValue` ever runs) needed
`CASM_TOKEN_LPAREN` added — without it, `lda #(1+2)` tripped
`CASM_DIAG_SYNTAX_ERROR` at the statement-dispatch level before
`exprEvaluate`'s own (already-correct) primary dispatch was ever reached.
A real integration gap caught live (the first `casmparen1.s` fixture run
produced `SYNTAX ERROR`), not found by static reading alone. `posAbsolute`
needed no equivalent fix — it has no such pre-check, and a leading `(`
at the very start of an operand (no `#`) is claimed exclusively by
indirect-addressing dispatch before either `posAbsolute` or `posImmediate`
ever run, per WP64's frozen Parenthesization Rule.

**`ppsConstant`'s own RHS grammar stays untouched** (user-confirmed
scoping decision 2026-08-14, matching WP65/66's own precedent): named
constants continue using their separate hand-rolled parser, unaffected by
WP67's evaluator rewrite.

**A live regression that turned out not to be a regression**: after
implementation, `test_casm_listcap` started failing 5 of 7 fixtures live
under VICE. Bisection (rebuilding the harness against the pre-WP67
`expr.s`/`parser.s` in isolation, then against every source/binary
combination in between) proved the *code* was correct throughout — the
actual cause was `casm_listing_test_d64` reaching **0 free blocks**
after WP67's own envelope bumps to `test_casm_pass1`/`frame`/`listcap`/
`passcheck`, leaving no runtime headroom for `test_casm_listcap`'s own
10 output-file writes (`CASMLO01`-`10`) during live execution — a
capacity crunch, not a source defect. Resolved by relocating
`test_casm_bounds`/`test_casm_cliderive`/`test_casm_lexer` (26 blocks,
genuinely self-contained — unlike `test_casm_spanread`/`spancommit`,
which need their own companion `.seq` fixtures packaged on whichever disk
they live on) to `casm_include_test_d64` (208 free blocks), restoring 30
free blocks of headroom. Same precedent as WP52/WP66's own prior
same-shaped disk-capacity relocations — this one just needed live
bisection to distinguish from a genuine code regression first.

**Live-verified fixtures** (`casmparen1.s`/`casmparen2.s`,
`cmake/GenerateCasmTestFixtures.cmake`, packed onto `casm_include_test_d64`
alongside WP65/66's own fixtures): `#<(SCREENW+2)` and `#(1+2)` (a named
constant inside a group, and pure numeric operators inside a group) both
produced `CASM: INPUT VALIDATED` with PRG bytes matching hand-computed
expectations exactly; `LBL1+(LBL2)` (two relocatable labels, default
relocatable output, no `.ORG`) correctly produced `CASM: EXPRESSION
RELOCATION UNSUPPORTED AT LINE 5, COL 17` with the source-context caret
pointing at the second label reference.

**Test coverage**: 10 new cases added to `tests/src/casm_expr/casm_expr.s`
(`CASE_COUNT` 45→55): nested parens, two-separate-groups, left-
associativity (`1+2-3`), the depth bound's own boundary (8 accepted, 9th
rejected), extraction combined with a group, `*` inside a group, and both
new relocation-representability cases (accept one relocatable component,
reject two) — all live-verified `CASM EXPR: PASS`.

**Envelope**: production `casm`'s own `$6000` cap held without a bump.
Two additional test-harness envelope bumps beyond the disk-capacity fix
above: `test_casm_pass1`/`test_casm_frame` (`$5400`→`$5500`/`$5800`→
`$5A00`), `test_casm_listcap` (`$5800`→`$5A00`), `test_casm_passcheck`
(`$5000`→`$5100`) — all one round-page step, absorbing the shared
`expr.s`/`parser.s` growth.

### CASM Phase 12 WP68 Arithmetic and Bitwise Operators — As-Built (complete 2026-08-15)

Adds the last operator group WP64's frozen contract reserved: `*`, `/`,
`<<`, `>>`, `&`, `^`, `|`, unary `~`, unary `-` — completing Phase 12's
expression evaluator. Plan: `brain/plans/2026-08-14-casm-phase12-wp68-
arithmetic-bitwise-operators.md` (nine Atomic Increments, three with
their own detailed subordinate plans: Increment 6 — multiply/division;
Increment 7 — relocation/unresolved/parser integration; Increment 8 —
harness/envelope verification; Increment 9 — live end-to-end). Walkthrough:
`brain/walkthroughs/2026-08-15-casm-phase12-wp68-arithmetic-bitwise-
operators.md`.

**Token/lexer** (`common.inc`/`lexer.s`): nine new single/two-byte
punctuation tokens, `CASM_TOKEN_SLASH`/`AMPERSAND`/`CARET`/`PIPE`/`TILDE`
(single-byte) and `CASM_TOKEN_SHL`/`SHR` (two-byte lookahead on `<<`/`>>`,
alongside the pre-existing single-`<`/`>` extraction tokens),
`CASM_TOKEN_COUNT` now `$19`.

**Precedence dispatcher** (`expr.s`): WP67's `parseOperatorTail` (a flat
`+`/`-` loop) generalized to real precedence climbing across 7 tiers
(tightest to loosest: unary `-`/`~`; `*`/`/`; `<<`/`>>`; `&`; `^`; `|`;
`+`/`-` — C-family convention, per WP64's own design). Reproduced every
pre-WP68 expression result byte/message/location-identical before any new
operator was enabled (Increment 3's own gate).

**Arithmetic/bitwise implementations** (`expr.s:640-731`): `&`/`^`/`|` are
plain `AND`/`EOR`/`ORA`. `*`/`/` are bounded unsigned 16-bit software
routines (`mulUnsigned16`/`divUnsigned16` — the 6502 has no hardware
multiply/divide); multiply overflow and shift-count/shift-overflow all
share the pre-existing `CASM_DIAG_EXPR_OVERFLOW`; division checks its
divisor for zero unconditionally *before* any division arithmetic and
raises the new `CASM_DIAG_EXPR_DIV_ZERO` (`$44`) — WP64's third and last
reserved Phase 12 diagnostic code, after `$43` (WP65's
`EXPR_CIRCULAR`) and `$45`/`$46` (WP67's `EXPR_RELOC_UNSUPPORTED`/
`EXPR_PAREN_TOO_DEEP`). `<<`/`>>` accept only a 0-15 count; `>>` is
logical (`LSR`/`ROR`), not arithmetic — proven end-to-end with
`$8001>>1 = $4000` (Increment 9), not just algebraically. Unary `-`/`~`
always produce a full 16-bit result — a nonzero `-x` (and most `~x`)
therefore correctly fails `ofRequire8Bit`'s existing `CASM_DIAG_OPERAND_
OUT_OF_RANGE` for an 8-bit immediate/`.BYTE` operand, the same rule any
other `>255` literal already hits, discovered live rewriting Increment
7's own fixture rather than the source.

**A real production-pipeline gap, found and fixed live (Increment 7)**:
`parser.s`'s two operand-entry token whitelists (the outer
`parseOperandSequence` dispatcher and `posImmediate`'s own inner one —
gating which token may *start* a non-implied operand, before
`parserParseExpressionValue` ever runs) never gained
`CASM_TOKEN_MINUS`/`TILDE`, so `LDA #-1`-shaped operand forms failed
`CASM_DIAG_SYNTAX_ERROR` before `exprEvaluate`'s own already-correct
primary handling was ever reached — the identical bug class WP67 already
fixed once for a leading `(`. The same audit found `CASM_TOKEN_STAR`
(WP66's current-address symbol) had the identical pre-existing gap since
WP66, not introduced by WP68; fixed in the same pass, disclosed and
user-approved before either fix landed.

**Live end-to-end coverage** (Increments 7 and 9, real `casm.prg`, not
just the synthetic `test_casm_expr` harness): one representative operator
per family (`*`, `&`, `<<`, unary `-`) plus relocation rejection for both
a real label and a label-derived named constant (Increment 7), and the
remaining `/`, `^`, `|`, `>>` plus the first real proof of
`CASM_DIAG_EXPR_DIV_ZERO` (Increment 9) — every WP64-frozen operator now
proven at least once through the real production pipeline, not only
algebraically. Increment 7 also proved genuine Pass 1/Pass 2 `FORCE_ABS`
width agreement for a forward-referenced named constant combined with a
new operator, the same property `casmfa2p.ref.hex` established for a bare
label (WP61 Increment 4).

**Test coverage**: `tests/src/casm_expr/casm_expr.s` grew from 55 to 97
cases (`CASE_COUNT`) across Increments 4-7, covering every operator,
chained-unary order, all 16-bit boundary patterns, shift counts 0/1/15/16,
multiply/divide identities and overflow/truncation, division by zero, and
relocation/unresolved interaction. Six new production `.seq`/`.ref.hex`
fixture pairs on `casm_phase12_test_d64` (`casmarith2`/`casmarithfwd`/
`casmareloc1`/`casmareloc2`, Increment 7; `casmarith3`/`casmdivzero`,
Increment 9) exercise the real parser/emitter pipeline the synthetic
harness cannot reach.

**Envelope**: production `casm` grew `$6000` → `$6100` (Increment 6,
activating `CASM_DIAG_EXPR_DIV_ZERO`'s message/dispatch plus the
divisor-zero check) — the only production cap change; `$6100` held with
3,351 bytes of headroom through Increment 8's consolidated final
measurement. `test_casm_expr` grew `$1600` → `$1700` (Increment 6,
tightest surviving headroom at 158 bytes); `test_casm_pass1`/`frame`
→ `$5900`, `test_casm_passcheck` → `$5B00`, `test_casm_listcap` →
`$5D00` (all absorbing the shared `expr.s`/`parser.s` growth).
`casm_phase12_test_d64` (dedicated to Phase 12 expression/operator
harnesses, created in Increment 6 when `test.d64`'s final free blocks ran
out) ended WP68 at 449 free blocks.

**A VICE MCP harness-only quirk, not a product defect** (Increment 9):
several shell-dispatch attempts for `test_casm_expr`/`test_casm_lexer`
returned spurious `BAD COMMAND OR FILE NAME` with a visibly garbled
command echo, resolved every time by a fresh `flush\n` immediately before
retyping the command — the existing recovery procedure in
`.agents/workflows/vice-mcp-testing.md` remains sufficient; not
investigated further as out of this WP's scope.

### CASM Phase 12 WP69 Character Literals — As-Built (complete 2026-08-15)

Adds `'x'`-style character literals, the last WP64-reserved token
(`brain/plans/2026-08-13-casm-phase12-wp64-contract-freeze.md` line 91)
never implemented until now. Plan: `brain/plans/2026-08-15-casm-phase12-
wp69-character-literals.md`. Walkthrough: `brain/walkthroughs/2026-08-15-
casm-phase12-wp69-character-literals.md`.

**Two real scoping decisions, user-confirmed 2026-08-15, deliberately
narrower than every other Phase 12 primitive**: no backslash escape
sequences (one literal byte between quotes, verbatim — no case folding,
matching CASM's existing identifier-byte treatment), and restricted to
immediate/`.BYTE` contexts only, never a general expression primary.
Combining with an operator, `.WORD`, a bare/absolute instruction operand,
or a named-constant RHS all correctly fail rather than silently succeed.

**Because of the second decision, `expr.s` needed no change at all** —
`CASM_TOKEN_CHAR` never reaches `exprEvaluate`/`parsePrimary`. Instead,
`posImmediate` (`parser.s`) gained a new whitelist entry routing to
`posImmediateChar`, and `emitByteList` (`emit.s`) gained an equivalent
per-item short-circuit — both read `CasmTokenText[0]` directly as the
resolved 8-bit value, unconditionally non-relocatable/non-force-abs. The
outer `parseOperandSequence` dispatcher deliberately does **not** gain
`CASM_TOKEN_CHAR` (unlike WP66/68's `*`/`-`/`~`), and `emitWordList`/
`ppsConstant` are both untouched — confirmed by reading, not assumed,
that `CASM_TOKEN_CHAR` simply isn't one of their recognized tokens, so
`.WORD 'A'` and `NAME = 'A'` both naturally fall through to
`CASM_DIAG_EXPR_MALFORMED` with zero code change required.

**Lexer** (`lnChar`, matching `lnHex`/`lnBin`'s own multi-byte-scan shape,
not a single-byte punctuation-table entry): consumes exactly one content
byte verbatim, validated against the same printable-PETSCII bounds
`.INCLUDE` filenames already enforce (`CASM_INCLUDE_PRINT_LO/HI_MIN/MAX`,
reused rather than duplicated), then requires an immediate closing `'`.
Two new diagnostics, `$47`/`$48` (`CASM_DIAG_CHAR_UNTERMINATED`/
`CHAR_INVALID_BYTE`), both source-location-context printed via
`diagSetLocFromLookahead`. The one-byte-then-close rule needs no special
case for a literal quote as content: `'''` mechanically lexes as the
quote byte itself (opener, content = the second `'`, closer = the third).
An empty `''` literal is reported as `CASM_DIAG_CHAR_UNTERMINATED` (the
second `'` is consumed as content, no third `'` follows), not a separate
"empty literal" diagnostic — deliberately not special-cased, per the
no-escapes minimalism decision. Live-verified this correction to an
existing doc claim: `diagPrintSourceContext`'s `BYTE $xx` suffix is
emitted for **any** `diagSetLocFromLookahead`-raised diagnostic, not only
`CASM_DIAG_INVALID_SOURCE_BYTE` as `wiki/casm-programmers-reference.md`
previously (incompletely) stated — both new WP69 diagnostics print it too,
confirmed live (`AT LINE 1, COL 8 (OFFSET 7) BYTE $00`).

**A branch-range overflow, found and fixed during Atomic Step 2** (not a
design defect, a direct consequence of inserting a large new scan routine
into an already-tight dispatch region): `lnAngle`'s two `beq` sites
(`lexer.s`'s main dispatch) fell out of 6502 short-branch range once
`lnChar`'s dispatch check/trampoline were added nearby. Fixed with a
`lnAngleJmp` trampoline, the same indirection `lnHexJmp`/`lnBinJmp`
already used for the same reason.

**Envelope**: production `casm` grew `$6100` → `$6200` (235 measured
bytes over $6100 once the full lexer/parser/emitter integration was
complete); `test_casm_pass1`/`test_casm_frame` `$5900` → `$5A00` (150/69
bytes respectively); `test_casm_listcap` `$5D00` → `$5E00` (249 bytes).
`test_casm_passcheck` ($5B00) absorbed the shared growth without needing
a bump. All four bumps are the smallest round-page (+256) step that fits,
user-approved 2026-08-15. `casm_phase12_test_d64` ended WP69 at 441 free
blocks (still comfortably above its `>=40` gate); `image_d64`/
`test_image_d64`/`casm_listing_test_d64` all shrank slightly from the
larger `casm.prg`/`test_casm_lexer.prg` PRG sizes consuming more disk
blocks when packaged (317/18/7 free respectively, down from 318/21/11) —
none hit zero, all builds succeeded, but `casm_listing_test_d64` in
particular is now tight enough to be worth relocating a harness off it
before the next WP that touches these shared modules, the same kind of
capacity crunch WP67 already resolved once for the same disk.

**Live-verified fixtures** (`casmchar1.s`/`casmcharbare.s`/
`casmcharunterm.s`/`casmcharinval.s`, `cmake/GenerateCasmTestFixtures.cmake`,
packed onto `casm_phase12_test_d64` alongside WP68's own fixtures):
`casmchar1.s` (`LDA #'A'`, `.BYTE 'H','I'`) produced `CASM: INPUT
VALIDATED` and `FILES COMPARE OK` against a hand-derived reference;
`casmcharbare.s` (`LDA 'A'`) produced `CASM: SYNTAX ERROR` at the bare-
operand position, confirming the excluded-context restriction holds
through the real parser, not just by design; `casmcharunterm.s`/
`casmcharinval.s` produced the exact `CASM_DIAG_CHAR_UNTERMINATED`/
`CHAR_INVALID_BYTE` messages and locations. `test_casm_lexer` (4 new
cases) and `test_casm_expr` (unaffected, confirming `expr.s` truly
untouched) both re-ran clean.

**Test coverage**: `tests/src/casm_lexer/casm_lexer.s` gained four new
cases (`caseCharValid`/`caseCharQuoteContent`/`caseCharUnterminated`/
`caseCharInvalidByte`), each a fresh `lexerInit`/`lexerNext` pair (matching
`caseAccept31`/`caseReject32`'s own minimal single-shot style) rather than
the multi-token streaming style `caseOperators` uses, since each
scenario ends in a different lexer state.

**`casmchar1.s` on cc1541's 16-character limit**: `casmcharinvalid.s` (17
characters) silently truncated to `casmcharinval.` on first build, losing
its `.s` suffix — the identical class of mistake WP68 Increment 7 already
found once for `casmarithreloc1`/`2`. Caught before any live testing;
renamed to `casmcharinval.s` (15 characters).

### CASM Phase 12 WP70 Relocation Algebra Closure — As-Built (complete 2026-08-15)

Consolidated, no-new-behavior verification that every operator/operand
combination WP65-69 shipped matches WP64's frozen representability
contract — the master plan's own risk gate, proven directly rather than
assumed from WP64's design alone. Plan: `brain/plans/2026-08-15-casm-
phase12-wp70-relocation-algebra-closure.md`. Walkthrough: `brain/
walkthroughs/2026-08-15-casm-phase12-wp70-relocation-algebra-closure.md`.

**Two distinct relocation rules, confirmed by reading `expr.s`'s
`parseOperatorTail` dispatch directly, not assumed**: `+`/`-`
(`checkAddReloc`, pre-existing) reject only when **both** operands are
relocatable — one relocatable component plus any static components
always succeeds. Every WP68 operator and both unary operators
(`checkStaticReloc`/the unary path's equivalent check) reject if
**either** operand is relocatable at all — static-only, per WP64's own
frozen rule. Both are single shared routines with no per-operator
branching before the check runs, confirmed by reading, not inferred from
behavior.

**A genuine, previously-unproven gap found by reading every Phase 12
fixture's own source, not by running anything**: no fixture anywhere —
in Phase 12 or before it — combines a relocatable label with a static
addend AND verifies the resulting R6 relocation table. Every pre-Phase-12
fixture that does full R6 verification (`casmrelop1`/`2`, `casmreloc1`)
uses the old flat single-addend grammar with a bare identifier, no
addend. Every Phase 12 fixture that reaches a real relocatable label
(`casmparen2`, `casmareloc1`/`2`) is itself a *rejection* case — none of
them assemble successfully and check the resulting table. Closed by
`casmrelacc.seq` (`JMP MID` / `LDA TARGET+(1+0)` / `NOP`, no `.ORG`):
`TARGET+(1+0)` combines relocatable `TARGET` with a static parenthesized
group via `+`, reaching WP67's recursive `parsePrimary`/
`parseOperatorTail` architecture with a genuinely relocatable operand for
the first time under full R6 verification.

**A real hand-derivation mistake, caught by the fixture's own COMP
check, not silently trusted**: the first `casmrelacc.ref.hex` draft
predicted only one R6 entry (the `LDA` line's own relocatable reference),
missing that `JMP MID` is *also* a relocatable reference in the same
assembly — `MID` is a label too, and every label in non-`.ORG` mode is
relocatable, exactly the same "absolute JMP, high-byte relocatable"
pattern `casmrelop1.ref.hex` already established at its own offset 2.
`COMP` reported two byte mismatches plus a file-size difference (17 vs
19 bytes) against the real assembled output; corrected by re-deriving
from the spec/`casmrelop1` precedent (the mismatch located the error, the
correction did not copy CASM's own bytes — non-circularity preserved).

**A second live rejection proof, closing the gap between "proven
algebraically" and "proven live for more than one operator"**:
`casmarelocb.seq` (`LOOP: NOP` / `LDA #LOOP&$FF`) applies `&` — a
distinct WP68 operator from Increment 7's `*` — to a real relocatable
label, live-confirming `checkStaticReloc`'s shared mechanism a second
time rather than resting on the "one shared routine" argument alone.

**Coverage audit** (recorded here as the direct, checkable evidence the
master plan's risk gate calls for):

| Combination | Proven where |
| --- | --- |
| `+`/`-`, one relocatable + static, flat grammar | `casmrelop1`/`2`.ref.hex (pre-Phase-12), R6-verified, still re-run every regression |
| `+`/`-`, one relocatable + static, through WP67's recursive architecture | `casmrelacc.seq` (WP70, this WP), R6-verified |
| `+`/`-`, two relocatable components (rejected) | `casmparen2.seq` (WP67), live |
| `*` applied to a real relocatable label/constant (rejected) | `casmareloc1`/`2.seq` (WP68 Increment 7), live |
| `&` applied to a real relocatable label (rejected) | `casmarelocb.seq` (WP70, this WP), live |
| `/`, `^`, `\|`, `<<`, `>>`, unary `-`/`~` applied to a relocatable operand (rejected) | `test_casm_expr`'s own `sMulReloc`/`sDivReloc`/`sShiftReloc`/`sUnaryReloc` cases (synthetic, algebraic) — shared-mechanism argument (above), not separately live-verified per operator |
| `*` (current-address symbol) as a relocatable primary | `casmcuraddr1.seq` (WP66), live |
| A relocatable named constant (`= *`) reaching a static-only operator (rejected) | `casmareloc2.seq` (WP68 Increment 7), live |

No production source change was needed — this WP's own research (its
plan's Research Findings) found no defect, only an unproven-but-correct
gap and one hand-derivation mistake in the new fixture itself, both
resolved without touching `src/external/casm/*.s`.

### CASM Phase 12 WP72 Named-Constant Zero-Page Width Selection Fix — As-Built (complete 2026-08-17)

A real, confirmed defect discovered mid-WP71 (DASH adoption): a resolved
named constant (equate, e.g. `DISPATCHVECTOR = $70`) referenced as an
instruction operand always assembled with absolute (3-byte) addressing,
never zero-page (2-byte), even when its value was in range — unlike the
identical numeric literal (`STA $70`), which correctly selected
zero-page. Plan: `brain/plans/2026-08-17-casm-phase12-wp72-constant-
zeropage-width.md`. Walkthrough: `brain/walkthroughs/2026-08-17-casm-
phase12-wp72-constant-zeropage-width.md`.

**Root cause, confirmed by reading `expr.s`/`parser.s`/`opcodes.s`
directly**: `expr.s`'s `identifier` proc set `CASM_EXPR_FLAG_
SYMBOL_DERIVED` unconditionally for *every* resolved symbol, label or
constant alike — `parser.s` then derives `CASM_PARSER_STMT_FORCE_ABS`
straight from that bit, and `opcodes.s` takes the absolute branch
whenever it's set, before ever checking the actual value. The code
already drew the correct label-vs-constant distinction four lines later,
for `RELOCATABLE` classification — it simply never applied that same
distinction to width selection. A label's address genuinely can differ
between Pass 1 and Pass 2 (hence must force absolute, unconditionally,
correctly); a named constant is always fully resolved, identically,
before either pass evaluates an instruction operand naming it (via
`casmResolveConstants`, WP65), so it never needed the same protection.

**Fix**: a single site in `identifier`'s existing "resolved,
non-label-derived constant" branch (the same branch already gating
`RELOCATABLE`) now also clears `SYMBOL_DERIVED`, letting such a constant
fall through to the same value-based zero-page/absolute check a literal
already receives. No change to label or `*` (current-address) handling.

**Two pre-existing, unrelated things found and handled, not silently
folded in**:
1. `tests/src/casm_expr/casm_expr.s`'s own `CASE_COUNT` constant was
   already wrong before this WP touched it — 97 against a true 98
   pre-existing table entries — silently skipping the table's real last
   case for an unknown prior span. Found because it caused this WP's own
   new regression case to falsely pass against deliberately-broken code
   (twice, for two different reasons — see the walkthrough). Corrected
   to 99 (98 pre-existing + this WP's own new case).
2. A second, separate, genuinely dormant control-flow quirk in the same
   `identifier` proc (a `bne` relying on a resolved value's high byte
   being nonzero, taken only when it's zero, spuriously setting the
   never-consumed `CASM_EXPR_FLAG_FORCE_ABS` bit) — confirmed harmless
   (grep: nothing reads that bit; `parser.s` derives its own `FORCE_ABS`
   from `SYMBOL_DERIVED` only) and deliberately left unfixed, out of this
   WP's scope.

**Verification**: unit-level case (`casm_expr`'s new `sConst`/`eConst`)
demonstrated fail-before/pass-after live under VICE against the actual
pre-fix and post-fix binaries. Full regression suite (`pass1`, `reloc`,
`symbol`, `opcodes`, `expr`) clean post-fix. `dash_ref` (ca65 cross-check)
confirmed byte-identical (sha256
`3238b7863cc9b7ba7b07202c94dccb8dcbd1fd0fe4c578362f311b79757b814b`,
4766 bytes) — unaffected, as expected for a native-CASM-only change. New
end-to-end fixture `casmzpconst1` (mirroring DASH's real `dmain.s`
source verbatim: `DISPATCHVECTOR = $70` / `STA DISPATCHVECTOR` / `STA
DISPATCHVECTOR+1`) assembled by real native CASM and `COMP`-verified
byte-exact against a hand-derived reference (`85 70` / `85 71`, not
`8D 70 00` / `8D 71 00`).

### CASM Phase 12 WP73 Forward-Label Resolver-State Fix — As-Built (complete 2026-08-18)

`symbolsLookup` guarantees only `CASM_RESOLVE_FLAGS = 0` on a miss and leaves
the remaining resolver view, including `CASM_RESOLVE_SYM_FLAGS`, unspecified.
WP72 made `expr.s::identifier` consume that symbol-kind byte before checking
whether the result was resolved. A preceding resolved equate lookup could
therefore leave `CONSTANT|RESOLVED` in the reusable view; a following unresolved
forward label inherited it, cleared `SYMBOL_DERIVED`, and lost parser-level
`FORCE_ABS`. Pass 1 selected zero-page from its `$0000` placeholder while Pass 2
selected absolute from the real label address, shifting all following labels and
eventually producing DASH's false branch-range diagnostic.

The fix checks `CASM_RESOLVE_FLAGS.RESOLVED` before inspecting symbol-kind flags;
unresolved identifiers retain the existing label-shaped path. No resolver ABI,
storage, opcode, branch-range, or resolved-constant behavior changed. The
existing number-primary tail changed from an unconditional-by-construction `BNE`
to `JMP` after the guard's code growth exceeded relative-branch range.

Regression evidence: `casm_expr` now runs a stale-output `CONSTVAL` then `UNABS`
sequence as case 100; native CASM assembled `casmfwdstale1.s` and COMP reported
`FILES COMPARE OK` against the 54-byte hand-derived reference. The first oracle
draft incorrectly used CPX-zero-page opcode `$E4` for `CPY MAXLEN`; COMP caught
the error at offset `$0024`, and the reference was corrected from the 6502
opcode specification to `$C4`. Live `CASM EXPR: PASS` and shell-return evidence
were then observed under VICE 3.10.

The user approved the completion gate on 2026-08-18. CASM advanced from
`0.2.5` to `0.2.6`; WP71 may resume native DASH regeneration.

### CASM Phase 12 WP71 DASH Adoption — As-Built (complete 2026-08-18)

DASH's seven dual-assembler sources now use named constants for the documented
private zero-page registers while retaining explicit keyboard/screen-code bytes
where ca65 and native CASM character mapping differs. Native CASM `0.2.6.1318`
assembled the complete include graph under VICE 3.10 with a 16MB REU; native
COMP and the host ca65 cross-check both matched all 4,766 bytes. The reviewed
`dash.ref.hex` now carries genuine native provenance and current hashes for all
seven sources, with no `--allow-host-bytes` override.

The production image and no-change rebuild are stable. Live relocation runs
rendered at `$3800`, `$5000`, and `$9000`; DASH's Applications page reported
the explicit ranges `5000-5ef3` and `9000-9ef3`. The implemented explicit
workflow is `LOAD DASH <address>` then `RUN <address>`; the previously documented
`GO <address>` spelling is not dispatched by the shell and was corrected in the
mirrored DASH manuals.

The user approved the completion gate on 2026-08-18. CASM advanced from
`0.2.6` to `0.2.7`; WP74 string literals are unblocked.

## CASM Phase 12 WP74 String Literal Contract

- WP74 completed with user approval on 2026-08-19 at CASM `0.2.8`.
- Double-quoted strings are valid only as `.BYTE` list items. They contain
  zero or more verbatim printable PETSCII bytes, with no escapes or implicit
  terminator; empty and mixed numeric/character/string lists are valid.
- `CASM_TOKEN_STRING` is `$1A`. Payload storage is the bounded lexer-owned
  `CasmStringBuffer[255]` plus `CasmStringLength`; the frozen token record did
  not grow. Diagnostics `$49/$4A` cover unterminated and invalid-byte strings.
- DASH dogfoods the feature with `.BYTE "0.1.4"`; native CASM, ca65, and the
  shipping result are byte-identical.

## BANNER Migration to Native CASM (2026-08-20)

BANNER retired its ca65 build path entirely (`add_ca65_app`, `header.s`
deleted) and now ships purely from native CASM, following DASH's
manifest-provenance model but without a ca65 cross-check step — there is
no second toolchain building BANNER to diverge from. `banner.s` adopted
CASM Phase 12 syntax throughout: named constants for the zero-page
workspace and OS/KERNAL entry points, WP74 string literals for
`USAGE_STR`, and WP69 character literals for punctuation/flag
comparisons (two case-folding literals reverted to hex: `check_casm_
source_bytes.py` rejects lowercase ASCII bytes anywhere in a CASM-packaged
source, including inside a character literal, since `cc1541 -w` copies
host bytes verbatim with no PETSCII translation — the same class of
constraint DASH's own AGENTS.md already documents for a different reason).

Verified via 4 independent live-VICE native-CASM assemblies (refactored
source, pre-refactor source at the same relocatable base, and the final
checker-compliant source, twice): all produced the identical 1011-byte
PRG. The compiled `banner.prg` now ships on `command64_casm_utils.d64`
from a new reviewed manifest (`banner.ref.hex` +
`scripts/build_banner_manifest.py`, a single-source twin of
`scripts/build_dash_manifest.py`). `image.d64`'s existing source-only
distribution of `banner.s` is unchanged.

Plan: `brain/plans/2026-08-20-banner-casm-native-migration.md`.

## DASH Further Phase 12 Syntax Adoption (2026-08-20)

Beyond WP71's named-constant-only pass, DASH's four remaining sources
(`dapp.s`, `dscr.s`, `dsys.s`, `ddata.s`) adopted WP68 shift/arithmetic
expressions (`AND #1<<0`-style bitmasks, `$0400+1*40`-style screen-row
offsets, `(25*40)-(3*256)`-style cell counts) and WP74 string literals
for the audited `$20`-`$3F` punctuation/digit range (digit runs, `": "`,
`" / "`, `"????"`), staying inside `AGENTS.md`'s Dual-Assembler Subset
rule throughout (literal-only arithmetic, no screen-code letters as
string content, no character literals).

Regenerated `dash.ref.hex` from a real native-CASM `0.2.8` build `1322`
run on a dedicated CASM-only test disk (`dash_casm_test.d64`), per
BANNER's own migration methodology — not a re-stamp of the existing
manifest. The resulting bytes are identical to both the ca65 cross-check
build and the previously-shipped manifest (`sha256 3238b786...`
unchanged), confirming this is a pure syntax refactor. `image_d64` had
been failing to build because the manifest's recorded `source_sha256`
for the four edited files no longer matched their (behaviorally
unchanged) content; it builds clean now.

## CASM Phase 12 WP76 Forward-Reference Pass-Agreement Fix (complete 2026-08-20)

Fixed a genuine Pass 1/Pass 2 instruction-width disagreement discovered
during WP75 Increment 5's fresh fixture sweep (Taskwarrior task 44,
originally logged as task 45 before Taskwarrior's session-local numeric
IDs shifted): `casmarithfwd.s` (`.ORG $0010` / `LDA FWDCONST*2` /
`FWDCONST = 5`, forward-referenced named constant + arithmetic operator)
produced `CASM: PASS 1/2 MISMATCH` instead of `CASM: INPUT VALIDATED`.

Root cause, confirmed live via direct memory read (`CasmPass1FinalPc =
$0013`, `CasmPc = $0012`): Pass 1 evaluates the forward reference while
`FWDCONST` is still undefined, forcing absolute (3-byte) addressing; by
Pass 2 the symbol table is fully populated, so the same reference sees
`FWDCONST` already resolved and WP72's zero-page exemption fires (2
bytes) -- a 1-byte width disagreement. WP72's own governing comment
("a resolved, non-label-derived constant's value can never differ
between Pass 1 and Pass 2") was true of the *value* but not of the
*resolution state at a specific reference's own position* -- true for
backward references, false for forward ones.

Fixed by extending the symbol record with a `DEFINED_AT_OFFSET_LO/HI`
bookmark (`common.inc`, offsets 44-45), stamped from the already-global
`CasmTokenStartOffsetLo/Hi` at each constant's own defining statement
(`ppsLabel`/`crpConstant`/`symbolsInsert`), and surfaced through the
resolver output view (`CASM_RESOLVE_SIZE` 6->8) at zero extra VMM-read
cost. `expr.s`'s WP72 exemption now only fires when the *current*
reference's own source position is at or after the constant's
`DEFINED_AT_OFFSET` -- both passes replay the same source top-to-bottom,
so this comparison yields the same answer in both, restoring agreement.

Live-verified: `casmarithfwd.s` now `CASM: INPUT VALIDATED` + `FILES
COMPARE OK`; a consolidated fresh re-run of all 11 WP75 Increment 5
fixtures together shows zero regressions. Found and fixed an
unanticipated build break in `tests/src/casm_expr/casm_expr.s` (a
synthetic `expr.s` unit-test harness with no real `lexer.s`) along the
way. Also found and explicitly deferred a second, unrelated defect
(Taskwarrior task 45: chaining a named constant to another named
constant breaks parsing of the following line) -- not investigated here,
per this project's disclose-and-defer norm.

The user approved this walkthrough on 2026-08-20. Plan:
`brain/plans/2026-08-20-casm-phase12-wp76-forward-reference-pass-agreement-fix.md`.
Walkthrough:
`brain/walkthroughs/2026-08-20-casm-phase12-wp76-forward-reference-pass-agreement-fix.md`.
WP75 resumes from Increment 6.

## CASM Phase 12 Complete (WP64-76, closed 2026-08-20 at `0.3.0` build `1324`)

Phase 12 added named constants (WP65), the current-address symbol `*`
(WP66), parenthesized/precedence expressions (WP67), the full
arithmetic/bitwise operator set (WP68), character literals (WP69),
relocation algebra closure (WP70), and string literals (WP74) — six real
language additions to CASM's expression grammar, none of them changing
any already-shipped Phase 1-11 program's assembled bytes. DASH (WP71,
completed by WP75's own Increment 1) adopted every one of them that
genuinely improved its source, staying inside its own `AGENTS.md`
dual-assembler subset (no character literals — a divergent ca65/native
byte-value risk for letters, not applicable to CASM itself).

Two corrective fixes were found and closed along the way, each its own
inserted WP per this project's established precedent: WP72 (a resolved,
non-label-derived named constant wrongly forced 3-byte absolute
addressing instead of the same value-based zero-page selection a bare
number gets) and WP73 (an unresolved forward label could inherit a stale
symbol-kind byte left over from a preceding resolved constant lookup,
disagreeing with Pass 2's own correct classification). A third,
deeper-latency defect (WP76) was found only by WP75's own fresh
consolidated fixture sweep — a forward-referenced named constant
combined with an arithmetic operator disagreed on instruction width
between Pass 1 (forced absolute while unresolved) and Pass 2 (always
resolved, took WP72's exemption) — exactly the kind of defect this
project's "re-run everything fresh, don't cite each WP's own individual
pass" consolidated-verification norm exists to catch (WP63 found an
analogous cross-harness defect in Phase 11 the same way).

WP75 itself (`brain/plans/2026-08-19-casm-phase12-wp75-verification-
walkthrough-completion-gate.md`) is Phase 12's consolidated closing WP:
all 30 `test_casm_*` harnesses plus all 11 Phase 12 production fixtures
re-run fresh in single continuous live-VICE sessions, DASH's regen
re-verified byte-identical after WP76's fix, a full clean regression
build and no-change rebuild both clean, this documentation reconciliation
pass (this section plus `wiki/casm-utility.md`,
`wiki/casm-programmers-reference.md`, `CHANGELOG.md`), and tracker sync
(`wiki/tasks/casm.md`, Taskwarrior tasks 42/43). The user completed their
own manual runtime walkthrough and approved closing Phase 12 on
2026-08-20. Final walkthrough:
`brain/walkthroughs/2026-08-20-casm-phase12-wp75-verification-
walkthrough-completion-gate.md`.

One genuinely new, unrelated defect was found and explicitly deferred
along the way, not fixed under Phase 12: chaining a named constant to
another named constant (`B = A`) breaks parsing of the following source
line (`CASM: EXPECTED NEWLINE`) — logged as its own Taskwarrior task,
tracked separately.

Full per-WP detail lives in each WP's own entry above (WP65 Named
Constants, WP66 Current-Address Symbol, WP67 Parentheses and Explicit
Precedence, WP68 Arithmetic and Bitwise Operators, WP69 Character
Literals, WP70 Relocation Algebra Closure, WP71 DASH Adoption, WP72
Named-Constant Zero-Page Width Selection Fix, WP73 Forward-Label
Resolver-State Fix, WP74 String Literal Contract, WP76 Forward-Reference
Pass-Agreement Fix) and in each WP's own plan/walkthrough pair under
`brain/plans/`/`brain/walkthroughs/`.

## CASM Phase 13 Complete (WP81-85, closed 2026-08-21 at `0.4.0` build `1349`)

Phase 13 ("Data Construction Directives") added four new directives —
`.RES count[, value]` (WP81, reserve N bytes), `.FILL count, value` (WP81,
required fill value), `.ALIGN boundary[, fill]` (WP81, pad to a boundary),
`.INCBIN "filename"` (WP82, include a raw binary file's bytes verbatim),
and `.ASSERT expr[, "message"]` (WP83, a compile-time expression check
with zero byte emission) — none of them changing any already-shipped
Phase 1-12 program's assembled bytes. `.RES`/`.FILL`/`.ALIGN`'s count/
boundary operands and `.ASSERT`'s own expression must fully resolve in
both passes — a forward reference is a diagnostic error, not a tolerated
Pass-1 placeholder, the same strict convention WP81 established and every
later WP this phase reused rather than re-litigating.

WP84 adopted `.RES` into DASH's real source (`ddata.s`'s five zero/fill-
byte buffers: `FMTBUF`/`SYSINFOBUF`/`APPBUF`/`BORDERROW`/`VMMBUFFER`),
narrowed from the master plan's original framing on two findings, each
confirmed with the user before implementation rather than assumed:

- **`.ASSERT` DASH adoption deferred entirely.** The master plan's own
  targets (the `DISPATCHRETURN`/`DISPATCHRETURNMINUSONE` offset-by-one
  invariant, buffer-size checks) are all equality invariants. WP83 found —
  by checking `expr.s`'s `parseOperatorTail` directly, not assuming —
  that CASM's expression grammar has **no equality/comparison operator at
  all**; `.ASSERT` can only test nonzero-arithmetic truthiness (there is
  no arithmetic identity that inverts "is zero" into "is true" without a
  real comparison operator). A real comparison operator is left as
  separate, future CASM work.
- **`.FILL` DASH adoption dropped for `.RES`.** Independently verified
  (a standalone `ca65`+`ld65` test, not assumed) that **ca65 has no
  `.FILL` directive at all** — using it in DASH's dual-assembler source
  would have broken the ca65 cross-check `AGENTS.md` requires. `.RES`
  with an explicit fill value (`.RES 38, $40` for `BORDERROW`) produces
  byte-identical output on both assemblers instead.

Both findings were real corrections to this phase's own plans, caught by
verifying claims against the actual toolchain rather than trusting a
prior assumption — the same discipline the project's `feedback-verify-
agent-hardware-claims` memory already calls for, applied here to
compiler/assembler semantics instead of hardware behavior.

WP85 is Phase 13's consolidated closing WP
(`brain/plans/2026-08-21-casm-phase13-wp85-consolidated-completion.md`):
all 29 `test_casm_*` harnesses (mapped to their six disk images by direct
`CMakeLists.txt` inspection, not assumed) plus all 14 Phase 13 production
fixtures re-run fresh in one continuous set of live-VICE sessions — the
full sweep, matching WP75's own Phase-12-closing precedent rather than a
narrower Phase-13-only pass, since WP75's own full sweep is what caught
WP76's real cross-harness defect. This sweep found the phase already
clean: no regressions, no new defects. DASH's `dash.ref.hex` was
re-confirmed (a cheap host-side SHA-256 check against a fresh `ca65`
build, not a second full hardware run — WP84 already did that this same
phase), CASM promoted `0.3.0` → `0.4.0` (completion-only, no behavior
change, live-verified via version banner and a COMP-clean fixture
re-run), and a full clean rebuild plus no-change rebuild both confirmed
stable.

Full per-WP detail lives in each WP's own plan/walkthrough pair under
`brain/plans/`/`brain/walkthroughs/` (`2026-08-21-casm-phase13-wp81-res-
fill-align`, `-wp82-incbin`, `-wp83-assert`, `-wp84-dash-adoption`,
`-wp85-consolidated-completion`).

## CASM Progress Indication Complete (optional feature, closed 2026-08-31 at `0.5.0` build `1380`)

An **optional feature outside the master plan's numbered CASM phases** —
CASM now shows what it is doing while it assembles. `src/external/casm/
progress.s` (new, ~720 lines) owns bounded progress state and its own
rendering only; it imports nothing from `diagnostics.s`/`listing.s`/
`map.s` and `diagnostics.s` imports exactly one routine back
(`progressClearTransient`, a one-way edge). No new zero page; MAIN grown
`$6C00` → `$7000` → `$7400` across the increments on measured evidence
(642 bytes headroom at close). Two internal deterministic-replay
diagnostics: `CASM_DIAG_PROGRESS_COUNTER_OVERFLOW` (`$55`),
`CASM_DIAG_PROGRESS_PASS_TOTAL_MISMATCH` (`$56`), contiguous after Phase
13's `$54` with a compile-time `.assert`.

**Screen protocol.** One in-place **transient** status line per pass
(`P1: dNN fNN NAME lNNNNN tNNNNN`), fixed 34 columns, never emits a
trailing CR so it never scrolls; redrawn on a **mod-64 statement**
throttle (`CasmProgDivider`) and immediately on every include frame
push/pop (identity keyed on `CasmFrameDepth` + `CasmSourceFileId`). The
statement counter counts label/constant/mnemonic **and directive**
statements (`.ORG` included); blank and comment-only lines do not.
Persistent lines: `P1:`/`P2: START` … `DONE nnnnn STATEMENTS`, `LOAD F...`
during source/`.INCLUDE` streaming, bounded byte-cadence during long
`.RES`/`.FILL`/`.ALIGN`/`.INCBIN`, `WRITE: <name>` at finalize, and
`DONE: P1 nnnnn, P2 nnnnn, nnnnn BYTES` before the documented `CASM: INPUT
VALIDATED`. The `nnnnn BYTES` field is the full output size (2-byte header
+ program + R6 table + 6-byte footer) — a 16-bit accumulator, so it wraps
for output > 65535 bytes (recorded, deferred: the file itself is still
correct). Transient line is cleared at `diagPrintFatal` entry and
suspended around `/M`/`/L`. **Assembled output is byte-identical with or
without the display.**

Delivered over eleven separately-approved increments (design/ABI freeze,
core, pass/source/include/directive/output integration, automated
verification with a dedicated `casm_progress_test_d64`, a full
implementation review that fixed three doc/robustness findings, live
runtime acceptance, and this completion gate — a fresh 31-harness + 10
`casmpg*` fixture consolidated live sweep against `V0.5.0.1380`, no
findings). Version promoted `0.4.0` → `0.5.0` at the gate. Parent plan
`brain/plans/2026-07-29-casm-feature-progress-indication.md`; per-increment
plans/walkthroughs `brain/{plans,walkthroughs}/2026-08-24-casm-progress-
incrementNN-*.md`; implementation review
`brain/reviews/2026-08-24-casm-progress-implementation-review.md`.

## CASM Memory Optimization Complete (optional, size-only WP, closed 2026-08-31 at `0.5.1` build `1390`)

An **optional WP outside the numbered phases** — recovered **2,068 bytes**
of CASM's MAIN envelope with a strict "identical observable behavior"
contract: no change to assembled output, progress display, or diagnostic
text/behavior. MAIN stays `$7400` (recovered bytes banked as headroom, not
returned); headroom at `$7400` went 642 → 2,710. Five independent changes,
each its own approved increment:

- **D — filename caps.** `CASM_FILENAME_MAX` and `CASM_INCLUDE_FILENAME_MAX`
  reduced **63 → 32** (~482 bytes, mostly BSS across 13 buffers in
  `cli.s`/`parser.s`/`include.s` plus two listing name buffers and the
  include open-name buffer). Established first that Command64's filesystem
  is CBM DOS end to end — the longest resolvable name is 16 (directory
  entry) + 3 (`8:`..`11:` prefix, stored verbatim in CASM's buffers) + 4
  (synthetic `.PRG`/`.LST`) = 23. User accepted that `FILENAME TOO LONG`
  now fires at 33+ chars instead of 64+ (no resolvable name affected).
  Found+fixed a latent `cliInit` bug: `ciClearNames` cleared a hardcoded
  512 bytes and would have run 248 past the shrunk `CasmSourceNames`.
  The REU-resident 128-byte include physical record was deliberately left
  alone (zero MAIN cost; the two 64-byte window transfers depend on it).
- **E — `progressPrintDec`.** Five inline `PROG_DIGIT` macro expansions →
  one divisor-table loop (−108 bytes). Output proven byte-for-byte
  identical over all 65,536 values × both field widths by a host-side
  model (`brain/walkthroughs/2026-08-31-casm-memory-optimization-
  increment04-progdec-equivalence.py`).
- **A — `diagDumpToken`.** The lexer/parser development token-dump printer
  and its ~40 token-name strings/tables gated behind
  `CASM_ENABLE_DIAG_DUMP_TOKEN` (`.ifndef` default 0 in `common.inc`; new
  `EXTRA_DEFINES` keyword in `cmake/Ca65.cmake`; `option(... OFF)` in
  `CMakeLists.txt`). **−653 bytes** because `ld65` links whole objects, so
  an exported-but-uncalled routine ships dead in every `casm.prg`.
- **B — `diagPrintMessage`.** The `"CASM: "` prefix (89 strings) and
  trailing CR (88) factored out of every diagnostic message into one new
  internal helper; `diagPrintString` unchanged (the non-message prints —
  filenames, source echo, carets, tracebacks, and `casm.s`/`map.s`'s
  banner/header text — keep calling it). **−585 bytes.** The
  `CASM_DIAG_ASSERTION_FAILED` user-message echo (`"CASM: ASSERTION
  FAILED: " + user text + CR`) is the one path that can't use the helper.
- **C — unified dispatch.** `diagPrintFatal`'s six parallel range tables
  (`diagMessageLo` / `diagListMessageLo` / `diagWp81/82/83MessageLo` /
  `diagProgressMessageLo`) and nine-way `cmp`/`beq` chain → one dense
  86-entry table `diagMsgLo`/`Hi` (`$01..$56`), one range check, one
  two-compare "locationless?" test over `CASM_DIAG_LOCLESS_FIRST..LAST`
  (`$3D..$43`, named + `.assert`-pinned in `common.inc`). **−240 bytes**
  (`+18` RODATA for the unified table, `−258` CODE). Every `id` still
  renders exactly its old text and gets `diagPrintSourceContext` for all
  but the `$3D..$43` locationless run.

**Guard**: `scripts/verify_casm_diag_table.py` (committed, run `POST_BUILD`
on the `casm` target) re-links `diagnostics.s` with `-g`/`-Ln`, decodes
the linked `casm.prg`, and checks every diagnostic identifier renders its
exact frozen text. Two lasting gotchas it encodes: `ld65` links whole
objects (Finding A), and CASM message strings are PETSCII so a host-side
decoder must mask `& 0x7F` (the `ca65 -t c64` charmap sets bit 7 / swaps
case — the audit's first verifier "failed" every check before this fix).

Live-verified under VICE: `BRANCH OUT OF RANGE` ($23, locationed),
`CIRCULAR CONSTANT DEFINITION` ($43, **locationless — no source line**),
`ALIGN BOUNDARY ZERO` ($4E) + a `9:`-prefixed filename, `ASSERTION FAILED:
<text>` ($54 echo), `INCBIN FILENAME EXPECTED` ($4F, LOC_BYTE sub-path),
`FILENAME TOO LONG` ($09) at the new cap, and a clean assembly with
unchanged progress output. **Defect exposed here, fixed separately
(task 43, closed 2026-08-31 at CASM `0.5.2` build 1392):**
`diagPrintFatal`'s `progressClearTransient` (from progress-indication
Increment 7) read uninitialized `CasmProgFlags` for any diagnostic raised
before `startPass1`, garbling the banner on an early fatal exit. Fixed by
moving the single `jsr progressInit` up into `casm.s:start`'s early-init
block (with `diagClearLoc` / `listingStateInit`). Plan
`brain/plans/2026-08-31-casm-progclear-early-fatal-fix.md`.

Parent plan `brain/plans/2026-08-24-casm-memory-optimization.md`;
walkthrough `brain/walkthroughs/2026-08-24-casm-memory-optimization.md`;
Taskwarrior 42.

## CASM Phase 14 Complete (WP86-92, closed 2026-09-01 at `0.6.0` build `1405`)

Phase 14 ("Local Labels") added **`@name` local labels** in ca65's "cheap
local" spelling: `@name:` defines, `@name` references, scoped to the
nearest preceding ordinary (non-`@`) label and closed by the next one or
EOF. The same `@name` is a distinct symbol per scope, may shadow an
ordinary label, and forward-resolves in Pass 2 like any label. Stored in
the **existing 64-byte symbol record** — flag bit `CASM_SYMBOL_FLAG_LOCAL`
(`%00010000`) plus a 2-byte owning-scope ordinal in reserved offsets
46-47 — so no new zero page, no VMM allocation change, MAIN still `$7400`
(1,902 bytes headroom at close). A source with no `@` token assembles
byte-identically to pre-Phase-14 (proven: `casmchain1`/`casmres1`/
`casmassert1` COMP-exact; DASH `dfmt.s` adopted `@local` in three routines
with byte-identical `dash.ref.hex` `3b4d0693`).

**Explicitly deferred:** anonymous labels (`:` / `:+` / `:-`) — a
materially different mechanism (lexer token, ring buffer, positional
cross-pass identity), planned as its own later phase.

**Known ca65 / Turbo Macro Pro divergence** (Research item 7, WP92 docs):
CASM rejects a local label on either side of a named constant's `=` (`@x
= 1` and `y = @x` both → `LOCAL LABEL NOT ALLOWED IN CONSTANT`). ca65 and
TMP (and ACME/64tass/KickAssembler/DASM) all allow it. This is an
implementation-simplicity choice — keeping the constant deferred-resolution
sweep from needing per-bookmark scope — not an industry norm; revisit at
the anonymous-label phase or first real TMP/ca65 import friction.

Real defects found live during the phase (each fixed): WP88 — a
scope-filter copy clobbered `A` (nameLen) before `symbolsFindChain`
(caught only by the new `test_casm_scope` harness's first run, not static
review or a clean build); WP89 — a stale fatal-diagnostic location and an
un-retargeted `diagPrintFatal` runtime range check; WP90 — `/M` on any
named constant defined past file offset 0 tripped `SYMBOL MAP INVALID`
(latent since Phase 10, `/M` never tested with constants). A standalone
diag-table hardening (single `CASM_DIAG_LAST` source of truth) landed
alongside WP89 so the runtime range check and verify script can no longer
drift behind the message table.

**WP92 consolidated gate:** a fresh 31-harness live-VICE sweep + all 11
Phase 14 production fixtures re-verified together found one regression —
`test_casm_flmeta` case 6 `resolveMaxIncludedName` — root-caused as a
**stale test fixture**, not a product bug: the memory-optimization WP's
Finding D dropped the include-filename cap 63→32 and re-pinned the
`casm_include` / `casm_cliderive` boundary fixtures but missed
`casm_flmeta.s`'s bare-literal `#66` expectation (no `CASM_*` symbol → no
build assert; not re-run live). Harness-only fix, separately approved as
Taskwarrior 43. **Lesson** (`feedback-capacity-const-change-unguarded-
literals`): when a capacity constant changes, grep `tests/src` for the
*old numeric value*, not just the symbol, and re-run **every** harness on
that path live — a "representative subset / same path" verification
shortcut hides a frozen-literal fixture.

Parent plan `brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md`;
WP92 plan `brain/plans/2026-09-01-casm-phase14-wp92-consolidated-completion.md`;
per-WP walkthroughs `brain/walkthroughs/2026-09-01-casm-phase14-wp8{6..9},wp9{0,1}-*.md`
+ `...-wp92-*` + `...-flmeta-maxincluded-regression.md`. Taskwarrior
parent `4cf10e7c`, WP92 `56711c7e`, regression `8da90f45`.

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
