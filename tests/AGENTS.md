# Purpose

The purpose of the `tests` directory is to contain regression tests and manual integration tests for verifying the features of the command64 OS (e.g. disk commands, memory manager, loader).

## Ownership

- Primary Owner: Primary Architect (Claude)
- Peer Owner: Companion Agent (Gemini)

## Local Contracts

- Tests must be executable under VICE or on real hardware.
- All modifications to test code must not break existing test coverage.
- Test environments and manual/automated test procedures must be safe (e.g. avoiding memory segment collisions with resident utilities like DEBUG or the Shell, or clobbering system-critical zero-page locations) unless they are explicitly intended to be unsafe (destructively testing boundaries).
- Agent-driven VICE tests must follow `.agents/workflows/vice-mcp-testing.md`.
- Command64 must be booted and identified by first-line text `Command 64-DOS Version`
  before a test application is launched by name from its shell.
- A normal return is proven by a shell prompt matching `c64[<device>]:>`; the decimal
  device number is variable.

## Work Guidance

- Use ca65/ld65 for tests that have `.s` ports; they build as the primary
  `test_<name>` targets through `add_ca65_app`.
- Name test apps for the feature under test, without a redundant `test`
  suffix; for example, use `tests/src/api/api.s` for target `test_api`.
- Keep KickAssembler tests only when no ca65 port exists or when the test is
  explicitly covering Kick-specific behavior such as the relocation pipeline.
- Use the compiled shell load commands or CMake-built test PRGs to run test programs.
- Select the disk by test needs: `image.d64` is the clean OS image, `test.d64` contains
  existing harnesses but has no free directory entries, and `casm_overflow_test.d64`
  carries newer harnesses and fixtures.
- Use the documented Command64 application name; do not substitute a physically truncated
  16-character D64 directory rendering for the user-facing command.
- Log success/failure of each test case.

## Verification

- Build `test_image_d64` regularly to verify the full test disk still
  includes all primary test programs, plus any intentional Kick-specific
  tests.
- The test-image build generates CASM SEQ fixtures `casmshort` (17 bytes),
  `casm256` (256 bytes), and `casmmulti` (513 bytes) for manual
  stream-boundary verification; all three must validate successfully. A
  zero-block `casmempty` fixture existed through early CASM Phase 2/3
  development but was removed from the build (`cc1541 -L`, used to create
  its directory entry with no file content, sets track/sector to 0 --
  suspected of corrupting `test.d64`); no equivalent zero-block fixture
  remains on the disk.
- `test_casm_include` is packaged only on `casm_overflow_test_d64` under the
  16-character disk name `test_casm_includ`; `test.d64` has no directory entry
  available for it.
- `test_casm_catalog` joins it there for the same reason, under the
  16-character disk name `test_casm_catalo`, alongside five new tiny
  raw-content fixtures (`casmcat1`-`casmcat5`, bare lowercase disk names --
  not CASM source, so they skip the `.s`-suffix convention `CASM_TEST_FIXTURES`
  uses on `test_image_d64`).
- `test_casm_frame` (WP46 nested-include frame stack) joins them there too,
  needing no truncation at 14 characters, alongside ten real-CASM-syntax
  fixtures (`casmfrp1`-`casmfrp4`, `casmfrc1`-`casmfrc3`, `casmfrcr1`,
  `casmfrr1`-`casmfrr2`). Those fixtures use bare lowercase disk names
  despite being real CASM source: they reference each other by exact operand
  text, so they replicate WP45's already-proven pairing rather than risk a
  second naming mismatch. Running it needs both drives -- boot `test.d64` on
  device 8, then switch to device 9 (`9:` at the shell) where
  `casm_overflow_test.d64` is attached.
- WP48 adds `casmidp1.s`, `casmidc1.s`, and `casmidc2.s` to
  `casm_include_test.d64`. Running `CASM CASMIDP1.S` must fail in the
  grandchild, name `CASMIDC2.S`, and print two `INCLUDED FROM` lines in
  innermost-to-root order with `LINE 2 COLUMN 5`.
- `casmidup1.s`/`casmiduc1.s`/`casmiduc2.s` repeat that failure with an
  unterminated final identifier, proving packed identity and traceback depth
  can be recovered after normal lexer lookahead already popped the child.
- `casmiddp1.s`/`casmiddc1.s`/`casmiddc2.s` raise an invalid-byte diagnostic
  before an unterminated child EOF. Fatal line draining must not append
  `DRAINAFTER`, `ROOTAFTER`, or other parent bytes after frame EOF/pop.

## Child DOX Index

- (none)
