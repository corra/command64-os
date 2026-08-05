# Purpose

The `src/external/debug` directory owns the relocatable DEBUG monitor,
assembler, execution controls, and DEBUG-local VMM allocation state.

# Ownership

- Primary Owner: Companion Agent (Gemini)
- Peer Owner: Primary Architect (Claude)

# Local Contracts

- Access REU memory only through public `OS_API` VMM services; never access REU
  hardware registers directly.
- DEBUG owns at most four VMM allocations, represented by the parallel
  `reuActive`, `reuSegHi`, `reuBank`, `reuParagraphLo`, and `reuParagraphHi`
  arrays.
- Only nonzero `reuActive` records authorize lifecycle or transfer operations.
- Explicitly initialize every registry field at DEBUG startup; do not rely on
  loader or reserved-storage zero fill.
- Keep persistent REU state out of private zero page `$70-$7F` and OS parameter
  cells `$66-$6C`.
- Validate complete commands and address windows before execution or VMM calls.
- Report system-wide VMM status only through `DOS_GET_SYSTEM_INFO`; never read
  the OS Memory Control Table (`$C000-$CFFF`) directly.

# Work Guidance

- Document register, carry, parser-position, and state-mutation contracts for
  parser and registry helpers.
- Preserve existing base-memory command behavior; REU access belongs only to
  the explicit `XA`, `XD`, `XM`, and `XS` family.

# Verification

- Build through CMake and confirm DEBUG remains relocatable and within its
  configured `MAIN` envelope (`$2400` bytes at `$3800`, ceiling `$5C00`, set
  by `add_ca65_app(debug ...)` in `CMakeLists.txt`). Keep DEBUG's occupied
  end address below `$6000` — that address range is reserved by convention
  for manual test fixtures (`E`/`F` pokes) and must never overlap DEBUG's own
  running code.
- Run DEBUG through Command64 under `.agents/workflows/vice-mcp-testing.md`.
- Verify registry initialization, ownership checks, and cleanup behavior with
  direct memory evidence where applicable.

# Child DOX Index

- (none)
