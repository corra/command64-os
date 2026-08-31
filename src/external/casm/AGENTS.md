# Purpose

The `src/external/casm` directory owns CASM, a native Command 64
6502/6510 assembler that runs as a user-space external application.

# Ownership

- Primary Owner: Companion Agent (Gemini)
- Peer Owner: Primary Architect (Claude)

# Local Contracts

- Build CASM with ca65/ld65 through `add_ca65_app`; CASM is not a host-side
  assembler or a replacement for the repository build toolchain.
- Keep the entry point in `casm.s`, shared declarations in `common.inc`, and
  separate modules for resource ownership, diagnostics, storage, parsing,
  assembly passes, emission, and reporting as those phases are implemented.
- Use only the Phase 0-approved portion of the external-app private zero-page
  range `$70-$8F`. Define shared zero-page storage once and use `.exportzp`
  and `.importzp` across translation units.
- Document every public routine's inputs, outputs, carry/zero flag meaning,
  preserved values, and clobbered registers.
- Keep base-RAM storage bounded. Allocate large source, symbol, relocation,
  and metadata stores through Command 64 VMM services.
- CASM accepts up to `CASM_SOURCE_COUNT_MAX` (8) ordered unquoted top-level
  source filenames on one command line (Phase 7 WP34; Phase 2 originally
  accepted exactly one), uses 63-byte filename payloads plus null
  terminators per slot, and transfers input through a 256-byte bounded
  buffer. It parses `/O`, `/S`, `/M`, and `/L` without creating production
  output; output runtime behavior begins with the numeric static-output
  phase. Every top-level source is loaded into one combined VMM stream
  (`sourceLoad`, `source.s`) before Pass 1 begins; a synthetic newline is
  inserted between files whose content does not already end in one, and
  file identity/line numbering reset at each file boundary during
  traversal.
- Register every acquired file handle and VMM allocation with the central
  resource owner immediately after acquisition.
- Listing-file ownership begins immediately after `DOS_OPEN_FILE` succeeds,
  before central handle registration can fail. `CasmListFileSlot =
  CASM_INVALID_SLOT` denotes a listing-private unregistered handle: close it
  directly through `DOS_CLOSE_FILE`; registered handles close through
  `fileClose`. Both `OPEN` and `CLOSE_FAILED` permit one caller-driven close
  attempt, retain ownership on failure, and delete an uncommitted listing only
  after close succeeds.
- Route every successful and fatal termination path through central cleanup
  before invoking `DOS_EXIT`.
- Preserve the primary failure when cleanup encounters a secondary failure.
- Preserve state needed after `OS_API` calls in bounded application storage;
  do not rely on transient shared zero-page values surviving an OS service.
- Use explicit PETSCII byte constants for command-buffer parsing, option
  matching, and synthesized filenames; do not depend on ca65 host character
  literals for runtime byte comparisons.
- Keep source locations file-aware and line-aware from the first source-stream
  implementation.
- Keep Phase 3 persistent source, lookahead, and token storage in the bounded
  storage-only `state.s`. Executable `source.s` and `lexer.s` import their
  subrecords when WP4 and WP7 implement them; they must not redefine storage.
- Phase 3 state is exactly 63 BSS bytes: a 16-byte source subrecord and a
  47-byte lexer/lookahead/token subrecord containing one contiguous 39-byte
  token record with 31 payload bytes plus terminator.
- `CasmIoBuffer` remains the only 256-byte source buffer. Byte mode owns the
  whole buffer as a transfer block. Line mode partitions it:
  `[0 .. lineLength-1]` holds the accumulated line payload and
  `[lineLength .. 255]` is the transfer region a refill reads into, so a logical
  line survives a block boundary without a second buffer. Naive reuse is invalid:
  a full-buffer refill would destroy a line that spans blocks.
- The source block cursor holds absolute `CasmIoBuffer` positions, not
  base-relative counts. Byte mode always has base 0, so its cursor is unchanged;
  only line mode uses a nonzero base.
- Byte mode and line mode are mutually exclusive. Line mode is claimed only on a
  fresh stream; mixing the APIs is rejected, and switching requires an explicit
  `sourceRewind`.
- `sourceRewind` resets only source-owned state. Lookahead is lexer state and
  `source.s` writes none; the lexer owns invalidating its lookahead after a
  rewind.
- Keep Pass 1 and Pass 2 deterministic; Pass 2 reparses a rewindable source
  stream rather than relying on an unbounded in-memory syntax tree.
- Phase 9 include work follows the approved parent plan
  `brain/plans/2026-07-25-casm-phase9-include-processing.md`: quoted 1-63-byte
  raw-PETSCII filenames, inherited parent devices unless explicitly prefixed,
  immutable Pass 1 VMM loading, filesystem-free Pass 2 event replay, 16 include
  levels, 32 physical files, 128 include events, and a 65,535-byte combined
  distinct-source cap. **As of WP47 (`0.1.49`) `.INCLUDE` is operational**:
  it loads, traverses, and assembles nested includes through `casmRunPass`'s
  own dispatch. WP48 added included-source diagnostic filenames and bounded
  include-site tracebacks at `0.1.50`; WP49's consolidated verification and
  user-approved completion gate passed at build 1204. Phase 9 is complete.
  Phase 10 (Symbol Map and Listing, WP50-WP55) followed: approved, planned,
  implemented, and closed 2026-08-08 at CASM `0.2.0` build `1260` — `/M` and
  `/L` are both fully implemented and production-active (see the durable
  Phase 10 architecture notes below). Phase 11 (base-release hardening,
  WP56-WP61) followed that: closed 2026-08-12 at CASM `0.2.2` build `1266`
  (see the Phase 11 notes below). The optional **progress and processing
  indication** feature (`progress.s`, outside the numbered phases) is
  **complete** — user-approved 2026-08-31 at CASM `0.4.0` -> `0.5.0` build
  `1380`. `progress.s` owns bounded progress state and its own rendering
  only; it imports nothing from `diagnostics.s`/`listing.s`/`map.s`, and
  `diagnostics.s` imports exactly one routine back (`progressClearTransient`,
  a one-way edge). No new zero page. The statement counter counts
  label/constant/mnemonic AND directive statements (`.ORG` included), not
  blank/comment lines; redraw throttle is mod-64. Assembled output is
  byte-identical with or without the display.
- Progress directive cadence keeps its own ordinary-BSS snapshot only:
  `progressBeginDirective` takes the directive subtype in A and resets the
  cumulative count; `progressDirectiveBytes` takes caller-authoritative
  cumulative successfully accepted bytes in A/X. Neither routine owns emitter
  state, zero page, parser/directive records, or resources. Callers must notify
  only after `emitByte` succeeds and must preserve existing carry/diagnostic
  precedence.
- WP44 implements only the quoted include operand grammar: 1-63 original
  printable PETSCII bytes are stored outside the frozen token record, and valid
  syntax returns NOT IMPLEMENTED before file, VMM, PC, output, or emitter
  effects. Do not describe include loading or traversal as operational.
- WP45 added `include.s` (metadata VMM store, device resolution via the OS's
  own `DOS_PARSE_PREFIX`, case-folded catalog identity, deduplicated catalog
  load) and `source.s`'s `sourceAppendFile`. The frozen 128-byte physical
  record layout (`CASM_INCLUDE_PHYS_REC_*`, `common.inc`) stores only the
  original (unfolded) spelling; identity comparison folds case live at
  compare time rather than storing a second copy.
- WP47 froze the 16-byte include-event record
  (`CASM_INCLUDE_EVENT_*`, `common.inc`) in the second half of the same 8KB
  metadata allocation, at `CASM_INCLUDE_EVENT_BASE` — anchored to the
  catalog's own extent, never a literal, so growing the catalog cannot
  silently overlap the log. An event stores no byte span: Pass 2 re-reads
  the child's span from the catalog, so a duplicated span could only
  disagree with the record that actually governs traversal. Parent identity
  is a (kind, id) pair because a top-level root (`CasmSourceFileId`) and an
  included parent (catalog index) occupy overlapping id spaces — top-level
  files are still not catalog entries; unifying them is WP48's job.
- **Pass 2 must never call `includeCatalogLoad`.** That entry point opens a
  file on a catalog miss, and a miss is exactly what a corrupted replay
  produces. Pass 2 calls `includeCatalogLookup` (resolve + capture + find,
  no load), which makes "zero Pass 2 source I/O" structural rather than
  merely trusted: the guarantee is provable from the call graph, since the
  only open path reachable during a pass sits inside `crpInclude`'s
  `CASM_PASS_MODE_MEASURE` branch. Preserve that property when touching
  either routine.
- `casmRunPass` is the one production bridge between `include.s` and
  `source.s`. Neither module imports the other, and that layering is
  deliberate — the shared caller sequences catalog lookup and frame push.
- Pass 1 and Pass 2 share one per-statement dispatch, driven twice and gated
  by a single `CasmPassMode` flag (measure vs. emit) checked at exactly one
  point in the emission engine's byte writer -- not a structured event
  stream. Phase 6 deliberately deferred listing/map capture design rather than
  inventing a speculative event shape. Phase 10 subsequently implemented the direct
  `emitByte` capture and completed-line-sidecar design documented below. See
  `brain/plans/2026-07-22-casm-phase6-wp26-prerequisite-reconciliation.md`
  (Phase 0C.5 freeze) for the decision record.
- **Phase 10 architecture (WP50-55, closed 2026-08-08 at CASM `0.2.0` build
  `1260` — durable, production-active contracts, not forward-looking gating
  language):**
  - `/L` conditionally allocates exactly two VMM stores: 4,096 fixed 16-byte
    physical-line metadata records (exactly 65,536 bytes) and a 65,536-byte
    source-generated-byte mirror. Capture hooks `emitByte`, not
    `emitRawByte`, so PRG headers and R6 metadata are excluded from the
    mirror. `/M` without `/L` acquires neither allocation.
  - Listing output is raw PETSCII with CR row terminators and fixed 40-byte
    rows; `/M` walks symbol records via `symbolsReadByIndex` in definition
    order without sorting or touching hash buckets.
  - Exact listing spans come from a source-owned seven-byte completed-line
    sidecar (`sourceTakeCompletedLine`) plus four internal block-base/
    line-start bytes, never from token growth or `CasmSourceVmmCursor`. A
    listing transaction snapshots PC and byte cursor before parse, commits
    after dispatch, and commits `.INCLUDE` before frame push.
  - Production ordering in `casm.s` is: rewind, conditional capture
    allocation, PRG emission, capture/PRG finalization, source close, PRG
    commit, listing commit, map print, then the existing success output. One
    committed-aware artifact abort owns all fatal paths — a listing failure
    after PRG finalization retains the valid PRG, deletes only the
    incomplete listing, and suppresses `/M`.
  - `map.s` owns no VMM/file resource; `symbolsReadByIndex` and its 40-byte
    row buffer/formatters are stateless.
  - Full per-work-package design detail (offsets, register/flag contracts,
    fixture matrices) lives in each WP50-55 dedicated plan under
    `brain/plans/2026-07-29-casm-phase10-*` and
    `brain/KNOWLEDGE.md`'s "CASM Phase 10 Symbol Map/Listing Contract"
    section; this file keeps only the still-load-bearing shape.
- **Phase 11 (WP56-61, base-release hardening, closed 2026-08-12 at CASM
  `0.2.2` build `1266`):** a hardening/certification phase, not a features
  phase — no new language feature, directive, or output format was added.
  The only production source change across all six work packages is `CLD`
  as the literal first instruction of `casm.s`'s `start:` entry, ahead of
  every other init step, since CASM has no supported decimal-mode entry
  contract of its own. Everything else this phase did was test/verification
  infrastructure: fault-injection tooling for file/VMM failure paths
  (WP57-58), a full audit of `listing.s`/`map.s` (WP59), and exhaustive
  certification that CASM's opcode/addressing-mode support and boundary
  behavior (numeric literals, addressing width, branches, PC, and the
  source/symbol/VMM/relocation boundaries) matches the documented 6502/6510
  instruction set across all 151 legal opcode/mode combinations (WP60), plus
  a determinism proof that identical input produces byte-identical PRG/R6/
  listing/map output (WP61). Treat this certification as load-bearing
  confidence, not merely "implemented": these behaviors were independently
  re-derived and mechanically reconciled against the shipped tables, not
  just exercised by the existing happy-path test suites. See
  `brain/plans/2026-08-08-casm-phase11-base-release-hardening-documentation.md`
  (governing plan) and `brain/KNOWLEDGE.md`'s "CASM Phase 11 Base-Release
  Hardening Contract" section for the full per-work-package record.
- Do not implement a phase until the user approves that phase's prerequisite
  contract gate. Phase 0A governs the scaffold; Phase 0B governs Phase 2 CLI
  and file services; later language/storage contracts remain Phase 0C work.
- Every CASM work package from Phase 3 Work Package 3 onward must have a
  dedicated detailed implementation plan saved under `brain/plans/` and
  explicitly approved by the user before that package becomes active or
  implementation begins. Parent-phase approval and approval of an earlier
  package do not approve a later package.
- Read-only discovery may precede work-package plan approval. Investigation,
  source or build edits, fixture creation, functional documentation changes,
  and task activation must wait for the dedicated plan. Material deviations
  discovered during implementation require an amended plan and renewed user
  approval before work continues.
- Each detailed work-package plan must define its objective, prerequisites,
  inherited decisions, scope, expected files, ABI and storage effects,
  register/flag/scratch contracts, atomic increments, failure and cleanup
  behavior, verification, documentation/task/DOX updates, stop conditions, and
  completion gate.
- Every CASM language or feature addition must include a DASH adoption
  increment: audit `src/external/dash/` for applicable uses, perform a
  byte-equivalent DASH rewrite when the feature applies, and re-run both native
  CASM and ca65 cross-checks. If safe adoption is impossible, stop and obtain
  explicit user direction rather than silently declaring the feature complete
  without real-application dogfooding.
- Completing a CASM work package increments the stage component of the current
  `major.minor.stage` version while preserving the current major and minor
  components. The new stage is recorded only after verification and explicit
  user completion approval, together with task, knowledge, memory, changelog,
  and walkthrough updates.
- Version stages are unbounded decimal values, not single digits. The current
  one-byte `VERSION_STAGE` banner representation may remain temporarily, but a
  separately planned and approved multi-digit representation must be completed
  before any work package at version `0.1.9` may be completed. That migration
  must preserve the independent build-number component.
  **Status (2026-08-12): this threshold never activated.** The project moved
  to a `0.2.x` minor-version series (Phase 10's completion promotion,
  `0.1.56` -> `0.2.0`) before `VERSION_STAGE` ever reached `9` under `0.1.x` —
  the stage component reset to a fresh single-digit count under the new
  minor version, and CASM is now at `0.2.2` with the one-byte representation
  still sufficient. The underlying constraint is not retired, only
  unreached: it re-applies verbatim to the next analogous threshold, i.e.
  before any work package may be completed that would advance
  `VERSION_STAGE` to `9` under the current `0.2.x` series (a stage value of
  `0.2.9`). Watch for it again as Phase 12 and later work packages accumulate
  stage increments within `0.2.x` (or whatever minor series is current at
  the time).
- CASM assembly-source SEQ fixtures (`tests/fixtures/casm/*`,
  `cmake/GenerateCasmTestFixtures.cmake` output) carry an explicit `.s` suffix
  in their on-disk PETSCII name when written to a D64 image (e.g.
  `casmhello.s`), distinct from PRG binaries and from the `.ref`
  trusted-reference PRGs — a directory listing's TYPE column is easy to miss,
  so the name itself must make "this is source, not a program" obvious. This
  applies only to real CASM assembly source text; other SEQ text fixtures
  (e.g. `testseq`, `edlintest`) are not source code and keep bare names.

# Work Guidance

- Follow `brain/plans/2026-07-16-casm-assembler-implementation-plan.md` for
  the product architecture and the approved phase-specific plan for each
  implementation increment.
- Keep changes atomic and update `wiki/tasks/casm.md`, Task Warrior, and
  `brain/task.md` together.
- Prefer fixed-capacity tables, explicit bounds checks, and 16-bit carry
  handling over implicit wraparound.
- Treat `common.inc` Phase 3 token types, record offsets, diagnostic numbers,
  source results, and `$80-$83` scratch aliases as stable ABI. Later work
  packages require an approved plan amendment before changing them.
- Treat resource cleanup, source provenance, expression relocation class, and
  instruction-size stability as foundational interfaces rather than late
  error handling.
- Phase 12 WP68 extends the stable token inventory with `/`, `&`, `^`, `|`,
  `~`, `<<`, and `>>`. `*` and `-` retain their existing token IDs and are
  interpreted contextually as primary/infix and unary/infix respectively.
  Shift tokens consume two matching bytes but retain the first byte's source
  location; lone `<`/`>` remain extraction tokens.
- Phase 12 expression precedence is lowest-to-highest: binary `+`/`-`, `|`,
  `^`, `&`, `<<`/`>>`, `*`/`/`, unary `-`/`~`. Binary operators are
  left-associative; the evaluator parses an RHS at its operator precedence
  plus one.
- Phase 12 bitwise operators `&`, `^`, `|`, and unary `~` are static-only
  16-bit operations. Unary `-` computes 16-bit two's-complement and chains
  right-to-left. Relocatable operands are rejected; unresolved static Pass 1
  values propagate unresolved without reading placeholder value bytes.
- Phase 12 shifts are static-only: counts are limited to 0-15, left shift
  raises expression overflow when any high bit is discarded, and right shift
  is logical and zero-filling.
- Phase 12 WP74 adds `CASM_TOKEN_STRING` (`$1A`) for double-quoted `.BYTE`
  list entries. Content is zero or more verbatim printable-PETSCII bytes with
  no escapes or implicit terminator, stored in lexer-owned
  `CasmStringBuffer[255]` plus `CasmStringLength`; the frozen 39-byte token
  record does not grow. Only `emitByteList` consumes STRING tokens.
- `CasmSourceVmmCursorLo/Hi` is the **bulk-refill read head, not the logical
  parse position**. `sourceRefill` installs up to 256 bytes per call, so for
  a source file smaller than the buffer the cursor already sits at that
  file's end while the lexer is still parsing its middle. The parse position
  is `cursor - (CasmSourceBlockLen - CasmSourceBlockIndex)`. Anything needing
  "where is the parser right now" (include-event recording especially) must
  apply that correction; WP46's frame push saved the raw cursor and silently
  skipped all remaining parent content after every pop.
- A delivered byte's provenance lives in `CasmSourceResultFileId`/`LineLo`/
  `Hi`/`Column` (`state.s`), written by `sourceFetchPhysical` at
  `sfpHaveByte`/`sfpEof`. Read those **after** calling `sourceNextByte`;
  never snapshot `CasmSourceFileId`/`LineLo`/`Hi`/`Column` before the call,
  because that call may resolve a child frame's EOF and pop mid-flight, so
  the byte returned belongs to the restored parent. Any stand-in
  `sourceNextByte` (e.g. `tests/src/casm_include/casm_include.s`, which links
  no `source.s`) must populate the same fields.
- WP48 bit-packs every delivered byte's `FILE_ID`: bit 7 clear means bits
  0-6 are a top-level root index; bit 7 set means bits 0-6 are an include
  physical-catalog index. This meaning propagates through
  `CasmLookaheadFileId`, token `CASM_TOKEN_REC_FILE_ID`, `CasmStmtLocFileId`,
  and `CasmDiagLocFileId`. Readers must decode
  `CASM_DIAG_FILEID_FRAME_FLAG`/`CASM_DIAG_FILEID_ID_MASK`, not assume a raw
  CLI source index. The token record remains 39 bytes.
- Depth-0 traversal is bounded by `CasmSourceTopLevelEndLo/Hi`, a fixed
  snapshot taken when `sourceLoad` completes -- not by
  `CasmSourceLoadedLenLo/Hi`, which keeps growing as `sourceAppendFile`
  appends `.INCLUDE` children mid-traversal. Nested frames use their own
  `CasmFrameEndOffsetLo/Hi`.
- Use `command64.inc` for OS API and KERNAL symbols; do not duplicate shared
  numeric constants locally.
- Do not add one-off host scripts. Integrate reusable development tooling into
  the existing build system when a later approved phase requires it.

# Verification

- Run `cmake -S . -B build` after build-system changes.
- Build the current phase's narrow target before building `image_d64`.
- Inspect generated PRG headers, R6 trailers, sizes, and relocation counts
  rather than relying only on command exit status.
- Confirm a no-change rebuild does not increment `BUILD_CASM`.
- Do not use the broken `c64-testing` MCP or a web emulator.
- Ask the user to perform runtime checks in the supported local emulator or on
  hardware and record the result in a walkthrough.
- Do not mark a phase done until the user approves its walkthrough.

# Child DOX Index

- (none)
