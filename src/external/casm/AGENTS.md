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
- Register every acquired file handle and VMM allocation with the central
  resource owner immediately after acquisition.
- Route every successful and fatal termination path through central cleanup
  before invoking `DOS_EXIT`.
- Preserve the primary failure when cleanup encounters a secondary failure.
- Keep source locations file-aware and line-aware from the first source-stream
  implementation.
- Keep Pass 1 and Pass 2 deterministic; Pass 2 reparses a rewindable source
  stream rather than relying on an unbounded in-memory syntax tree.
- Emit structured events in Pass 2 so PRG, listing, and map consumers do not
  duplicate instruction generation.
- Do not implement Phase 1 source files until the user approves the Phase 0
  memory, resource, diagnostic, version, and initial link-size contracts.

# Work Guidance

- Follow `brain/plans/2026-07-16-casm-assembler-implementation-plan.md` for
  the product architecture and the approved phase-specific plan for each
  implementation increment.
- Keep changes atomic and update `wiki/tasks/casm.md`, Task Warrior, and
  `brain/task.md` together.
- Prefer fixed-capacity tables, explicit bounds checks, and 16-bit carry
  handling over implicit wraparound.
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
