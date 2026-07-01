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

- Use the compiled shell load commands or custom load addresses ($2200+) to run test programs.
- Log success/failure of each test case.

## Verification

- Run tests regularly to verify core dispatcher, loader, VMM, and file system functionality.

## Child DOX Index

- (none)
