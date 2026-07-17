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
- WP2 independently verified all 56 DEBUG mnemonic names and ordering against
  the repository's standard 6502 reference. WP9 will use a CASM-local 168-byte
  mnemonic table with explicit PETSCII bytes and no `???` entry, runtime link,
  shared include, or build coupling to DEBUG. DEBUG parsing, addressing,
  branch, opcode lookup, and direct-write routines are not reused; opcode and
  addressing-table decisions remain Phase 4 work. User completion approval
  advanced CASM from `0.1.3` to `0.1.4`.
- Work Package 1 synchronized the approved contracts and task hierarchy; user
  completion approval advanced the CASM stage version from `0.1.2` to `0.1.3`.
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
