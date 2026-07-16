---
feature: casm-native-assembler-phase2
created: 2026-07-16
completed: 2026-07-16
status: completed
---

# Walkthrough: CASM Phase 2 CLI and Native File Services

## Summary

Phase 2 adds bounded single-source command-line parsing, deterministic future
output-name derivation, managed native input streaming, centralized real file
cleanup, and stable allocation-free diagnostics. It recognizes `/O`, `/S`,
`/M`, and `/L`; only `/O` is accepted for Phase 2 execution, and no output file
is created yet.

Build 1011 fixes normal EOF propagation by explicitly returning carry clear
after the EOF comparison. This allows orchestration to close the input and
release its ownership record before successful cleanup.

## Automated Verification

The following commands pass:

```text
cmake -S . -B build
cmake --build build --target casm
cmake --build build --target casm
cmake --build build --target image_d64
cmake --build build --target test_image_d64
```

Measured build 1011 evidence:

- 2,256 linked code/data bytes and 449 BSS bytes.
- 1,391 bytes of combined headroom in the `$1000` `MAIN` envelope.
- 241 R6 relocation entries and a 2,746-byte final artifact.
- A no-change rebuild preserves `BUILD_CASM` 1011.
- `image.d64` retains all nine release applications.
- `test.d64` retains all existing test programs and provides the CASM fixtures
  `casmempty`, `casmshort`, `casm256`, and `casmmulti`.
- Generated host fixture sizes are exactly 0, 17, 256, and 513 bytes.
- `git diff --check` passes.

## Confirmed Runtime Results

- No source reports `CASM: SOURCE FILE REQUIRED`.
- Recognized unavailable options are rejected before input I/O.
- A normal text input reports `CASM: INPUT VALIDATED` and returns without a
  cleanup failure.
- `casmshort`, `casm256`, and `casmmulti` report `CASM: INPUT VALIDATED`.
- Build 1014 reports `CASM: FEATURE NOT IMPLEMENTED` for `/S`.
- Build 1014 accepts `/O:OUT.PRG`, validates `CASMSHORT`, and does not create
  `OUT.PRG`.
- Build 1014 passes the complete rejection/unsupported-option matrix: extra
  source, unknown option, duplicate option, both malformed `/O` forms,
  malformed flag suffix, `/M`, and `/L` all report their expected diagnostics.
- The zero-block directory-only `casmempty` entry reports
  `CASM: CANNOT OPEN INPUT`; the user accepted this as a Commodore DOS/device
  limitation.
- The 63-byte filename boundary is accepted through input open, the 64-byte
  filename is rejected as too long, and a final `CASM CASMSHORT` succeeds after
  all error cases without leaked state.

## Confirmed CLI Runtime Matrix

Build 1014 uses explicit PETSCII constants for all CLI grammar comparisons and
synthesized `.PRG` bytes. The build 1012-1013 option diagnostics have been
removed. Resume the matrix below against build 1014.

The user ran these commands from `build/test.d64` and confirmed every displayed
diagnostic. Option matching is case-insensitive.

| Command | Expected result |
|---|---|
| `CASM` | `CASM: SOURCE FILE REQUIRED` |
| `CASM CASMSHORT` | `CASM: INPUT VALIDATED` |
| `CASM CASMSHORT EXTRA` | `CASM: TOO MANY SOURCE FILES` |
| `CASM CASMSHORT /X` | `CASM: UNKNOWN OPTION` |
| `CASM CASMSHORT /S /S` | `CASM: DUPLICATE OPTION` |
| `CASM CASMSHORT /O` | `CASM: MALFORMED /O OPTION` |
| `CASM CASMSHORT /O:` | `CASM: MALFORMED /O OPTION` |
| `CASM CASMSHORT /SX` | `CASM: UNKNOWN OPTION` |
| `CASM CASMSHORT /S` | Confirmed: `CASM: FEATURE NOT IMPLEMENTED` |
| `CASM CASMSHORT /M` | `CASM: FEATURE NOT IMPLEMENTED` |
| `CASM CASMSHORT /L` | `CASM: FEATURE NOT IMPLEMENTED` |
| `CASM /o:out.prg CASMSHORT` | Confirmed: `CASM: INPUT VALIDATED`; no `OUT.PRG` created |

Filename boundary checks:

```text
CASM AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA.ASM
```

The 63-byte source token is accepted by the parser and then reports
`CASM: CANNOT OPEN INPUT` because that file does not exist.

```text
CASM AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA.ASM
```

The 64-byte source token reports `CASM: FILENAME TOO LONG` without attempting
to open a file.

After the valid `/O` case, run `DIR` and confirm `OUT.PRG` is absent. Then run
`CASM CASMSHORT` once more to confirm parser failures did not leave a channel,
handle, or cleanup-state leak.

## Completion Gate

All build, artifact, stream, CLI, filename-boundary, cleanup, and post-error
checks are confirmed. On 2026-07-16, the user explicitly approved completing
Phase 2 and its Phase 2.8 verification task.

### User Result

On 2026-07-16, the user confirmed the complete build 1014 CLI matrix, both
filename boundaries, the post-error clean-state invocation, the stream-size
fixtures, the accepted zero-block device limitation, and the absence of an
output file for `/O`.
