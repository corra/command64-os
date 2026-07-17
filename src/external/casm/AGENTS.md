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
- Phase 2 accepts one unquoted source filename, uses 63-byte filename payloads
  plus null terminators, and transfers input through a 256-byte bounded buffer.
  It parses `/O`, `/S`, `/M`, and `/L` without creating production output;
  output runtime behavior begins with the numeric static-output phase.
- Register every acquired file handle and VMM allocation with the central
  resource owner immediately after acquisition.
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
- `CasmIoBuffer` remains the only 256-byte source buffer. Byte mode owns it as
  a transfer block; future line mode owns it as a bounded line window. The two
  modes are mutually exclusive until rewind/reset.
- Keep Pass 1 and Pass 2 deterministic; Pass 2 reparses a rewindable source
  stream rather than relying on an unbounded in-memory syntax tree.
- Emit structured events in Pass 2 so PRG, listing, and map consumers do not
  duplicate instruction generation.
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
