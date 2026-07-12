---
feature: type-lf-newline-remediation
created: 2026-07-11
status: implemented-build-verified
---

# Plan: TYPE LF Newline Remediation

## Goal & Rationale

`TYPE` currently prints file bytes directly to the screen. A file containing
line-feed bytes (`$0A`, `PetLl`) does not display as an expected newline on
the C64 screen. `TYPE` should treat `$0A` as a text newline and emit a
carriage-return/line-feed pair during display.

This is a display-layer fix only. The file API must remain byte-preserving:
`DOS_READ_FILE`, `DOS_WRITE_FILE`, and `COPY` should not translate file
contents.

## Investigation

`cmdType` in `src/command64/shell.asm` reads the file in 64-byte chunks via
`DOS_READ_FILE`, using `CommandBuffer` as the temporary buffer:

- `src/command64/shell.asm:1024-1032` reads up to 64 bytes.
- `src/command64/shell.asm:1040-1047` loops over those bytes and calls
  `KernalChROUT` for each byte with no translation.
- `docs/codebase-reference.md:1011-1012` currently documents this behavior as
  "Prints raw bytes to screen -- no translation."

Because the print loop is the only place where bytes become screen output,
the newline fix belongs there, not in `fileRead`.

## Scope

In scope:

- Update `cmdType` so `$0A` input bytes display as a newline by emitting
  `PetCr` (`$0D`) and `PetLl` (`$0A`) to `KernalChROUT`.
- Keep all other bytes unchanged.
- Update documentation that currently says `TYPE` prints raw bytes with no
  translation.
- Add a manual verification walkthrough because the project testing MCP is
  unavailable/broken by policy.

Out of scope:

- Do not translate bytes in `DOS_READ_FILE`, `DOS_WRITE_FILE`, `fileRead`,
  `fileWrite`, or `COPY`.
- Do not alter file contents on disk.
- Do not change EDLIN save/load newline policy in this task.

## Files to Create/Modify

| File | Action | Notes |
|------|--------|-------|
| `src/command64/shell.asm` | Modify | Add LF handling in `cmdType`'s `ctPrintLoop`. |
| `docs/codebase-reference.md` | Modify | Change `cmdType` description from raw/no translation to LF-aware text display. |
| `docs/user-manual.md` | Modify | Document that `TYPE` displays `$0A` line feeds as new lines. |
| `wiki/user-manual.md` | Modify | Mirror the user manual update if wiki docs remain in sync. |
| `brain/KNOWLEDGE.md` | Modify | Add a short finding if implementation confirms C64 `CHROUT` needs CR/LF synthesis for LF-only files. |
| `CHANGELOG.md` | Modify | Record the user-visible `TYPE` newline behavior fix. |

## Key Design Decisions

- Translate LF at the command-display layer. `TYPE` is a text-view command;
  the lower file APIs are byte streams used by `COPY`, editors, utilities,
  and binary/program files.
- Emit the requested CR/LF pair for `$0A`: `PetCr` first, then `PetLl`.
- Preserve existing behavior for all non-LF bytes, including `$0D`.
- Avoid using a new persistent buffer. The existing `CommandBuffer` chunking
  remains valid because translation expands only the screen output, not the
  file buffer.
- Keep the implementation local to `ctPrintLoop` unless register preservation
  proves awkward. A helper such as `ctOutputByte` is acceptable if it keeps
  the loop easier to audit.

## Implementation Notes

The minimal implementation shape is:

```assembly
ctPrintLoop:
    lda CommandBuffer, y
    cmp #PetLl
    beq ctPrintLf
    jsr KernalChROUT
    jmp ctPrintNext

ctPrintLf:
    lda #PetCr
    jsr KernalChROUT
    lda #PetLl
    jsr KernalChROUT

ctPrintNext:
    iny
    cpy HexValLo
    bne ctPrintLoop
```

Register caveat: the current loop already relies on `Y` surviving
`KernalChROUT`. If implementation testing or local KERNAL documentation shows
that this is unsafe, preserve `Y` around output or switch the loop to a
counter/pointer pattern that is explicit about clobbers.

CRLF edge case: the strict requested behavior is "for `$0A`, emit CR/LF."
That means a file already containing `$0D,$0A` will display `$0D,$0D,$0A`.
If manual testing shows this creates unwanted blank lines for DOS-style files,
refine the implementation to track whether the previous displayed byte was
`PetCr` and suppress the extra synthetic `PetCr` only for CRLF input. That
state can be a one-byte flag in shell scratch storage or a register-preserved
flag if one is available without increasing memory pressure.

## Verification Plan

Build verification:

- Build the OS/test disk with the existing project target, preferably
  `test_image_d64`, and confirm there are no assembler errors or warnings.

Manual verification:

1. Create or include a SEQ/text file containing LF-only lines:
   - bytes: `LINE 1,$0A,LINE 2,$0A,LINE 3`
2. Run `TYPE <file>` from the shell.
3. Expected output: each LF advances to a new displayed line using the emitted
   CR/LF pair.
4. Create or include a file containing no `$0A`.
5. Run `TYPE <file>` and confirm non-LF bytes display exactly as before.
6. Optional edge-case check: create a file containing CRLF (`$0D,$0A`) and
   decide whether the strict CR/LF-for-LF behavior is acceptable or whether
   the implementation should become CRLF-aware before completion.
7. Run a binary/PRG `TYPE` smoke test only to confirm the shell does not hang
   or corrupt handles. Binary output is not expected to become pretty.

Closeout:

- Provide a walkthrough for the user to repeat the visual confirmation.
- Ask the user whether the task is done before marking any related task as
  complete.

## Progress

- 2026-07-11: Plan created from user report. No source changes made yet.
- 2026-07-11: Implemented `cmdType` LF handling in `src/command64/shell.asm`.
  The print loop now emits `PetCr` then `PetLl` for each input `$0A` byte and
  preserves `Y` around KERNAL output calls. Updated `CHANGELOG.md`,
  `brain/KNOWLEDGE.md`, `docs/codebase-reference.md`, and the mirrored
  `wiki/`/`docs/` user manuals. Build/manual verification still pending.
- 2026-07-11: `cmake --build build --target test_image_d64` passes. Manual
  C64-side visual verification is still required.
- 2026-07-11: Refreshed memory-map documentation (`brain/MEMORY.md`,
  `docs/programmers-reference.md`, `wiki/programmers-reference.md`, and
  `docs/codebase-reference.md`) to the build 2619 segment ranges produced by
  the verified build.
