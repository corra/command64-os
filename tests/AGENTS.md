# Purpose

The purpose of the `tests` directory is to contain regression tests and manual integration tests for verifying the features of the command64 OS (e.g. disk commands, memory manager, loader).

## Ownership

- Primary Owner: Primary Architect (Claude)
- Peer Owner: Companion Agent (Gemini)

## Local Contracts

- Tests must be executable under VICE or on real hardware.
- All modifications to test code must not break existing test coverage.
- Test environments and manual/automated test procedures must be safe (e.g. avoiding memory segment collisions with resident utilities like DEBUG or the Shell, or clobbering system-critical zero-page locations) unless they are explicitly intended to be unsafe (destructively testing boundaries).

## Work Guidance

- Use ca65/ld65 for tests that have `.s` ports; they build as the primary
  `test_<name>` targets through `add_ca65_app`.
- Keep KickAssembler tests only when no ca65 port exists or when the test is
  explicitly covering Kick-specific behavior such as the relocation pipeline.
- Use the compiled shell load commands or CMake-built test PRGs to run test programs.
- Log success/failure of each test case.

## Verification

- Build `test_image_d64` regularly to verify the full test disk still
  includes all primary test programs, plus any intentional Kick-specific
  tests.

## Child DOX Index

- (none)
