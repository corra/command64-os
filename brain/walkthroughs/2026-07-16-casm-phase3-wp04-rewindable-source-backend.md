---
feature: casm-phase3-wp04-rewindable-source-backend
created: 2026-07-16
completed: 2026-07-16
status: completed
implementation-status: implemented-verified
---

# Walkthrough: CASM Phase 3 WP4 Rewindable Source Backend

## Summary

WP4 adds the executable byte-stream source layer over Phase 2's managed input
wrapper and WP3's bounded source subrecord. New `source.s` initializes source
state, opens one source, refills and traverses the shared 256-byte
`CasmIoBuffer`, exposes a repeat-stable EOF, and closes through central resource
ownership. `sourceNextByte` is a documented transitional raw-byte API: every
`$00-$FF` byte (including CR and LF) returns `CASM_SOURCE_BYTE`. Normalization,
rewind, line access, and the lexer remain deferred to WP5+.

The consume-only entry point now runs through `sourceInit` / `sourceOpen` /
`sourceNextByte` / `sourceClose` while preserving the existing `INPUT VALIDATED`
success output. At first EOF the source verifies the consumed offset equals the
managed fetched total, so the raw fixtures detect lost, duplicated, or
prematurely terminated traversal.

## Files Changed

| File | Change | Notes |
|---|---|---|
| `src/external/casm/source.s` | Create | WP4 source routines and executable ownership |
| `src/external/casm/casm.s` | Modify | Route consume-only path through the source API; add `sourceInit` |
| `src/external/casm/fileio.s` | Modify narrowly | Map input-total overflow to diagnostic `$15` |
| `brain/walkthroughs/2026-07-16-casm-phase3-wp04-rewindable-source-backend.md` | Create | This evidence record |
| `wiki/tasks/casm.md` | Task state | WP4 remains in progress pending completion |
| `brain/task.md` | Task mirror | Matches Taskwarrior and wiki state |

`common.inc`, `state.s`, `AGENTS.md`, and `CMakeLists.txt` are intentionally
unchanged. The WP3 ABI/storage are sufficient, the existing source-ownership DOX
already describes the transitional buffer/state contract, and the CASM source
glob discovers `source.s` automatically.

## Public Routine ABI (as implemented)

- `sourceInit` — initializes all 16 source-record bytes to CLOSED/NONE with an
  initialized cursor; A=`CASM_DIAG_NONE`, C clear, Z set; preserves X, Y.
- `sourceOpen` — requires source CLOSED and Phase 2 input CLOSED; commits
  READY/BYTE and resets the cursor only on a successful `inputStreamOpen`;
  invalid state returns `CASM_DIAG_STREAM_STATE_FAILED` with no OS call.
- `sourceNextByte` (transitional raw) — returns `CASM_SOURCE_BYTE` with the raw
  byte in `CasmSourceResultByte`, or repeat-stable `CASM_SOURCE_EOF` with a
  cleared result byte, or a `CASM_DIAG_*` failure with source ERROR. The raw
  byte is never inferred from A or Z; a zero byte is a valid BYTE result.
- `sourceClose` — repeat-safe in CLOSED; closes through `inputStreamClose` in
  READY/EOF/ERROR; a failed close leaves source ERROR with the managed handle
  retained in CLOSE_FAILED for retry.

Private `sourceResetTraversal` (A-only, preserves X/Y) and `sourceRefill`
(validated 1-256-byte block install or count-checked EOF commit) are not
exported.

## Static Verification

- `source.s` imports the WP3 source subrecord and Phase 2 wrappers and defines
  no BSS; total BSS is unchanged at 512 bytes.
- No lexer/lookahead/token state is written by `source.s`.
- Every public and private status path explicitly normalizes carry and keeps
  the result byte separate from A/Z.
- Unsigned 16-bit index-vs-length handling was traced for lengths 0, 1, 255, and
  256 (`$0100`): index `<` length reads, index `==` length refills, index `>`
  length is a stream-state failure.
- Offset guard traced: `$FFFE -> $FFFF` returns a byte; a further byte at
  `$FFFF` fails with `CASM_DIAG_SOURCE_OFFSET_OVERFLOW` before any commit.
- EOF is committed only when block index equals block length and consumed
  offset equals `CasmInputTotal`; empty input returns EOF at offset 0, line 1,
  column 1.
- After the first committed EOF, `sourceNextByte` returns the same result with
  no OS read and no cursor mutation.
- Open, read, and close failures preserve central resource ownership; a failed
  close is retryable and does not overwrite a caller's primary diagnostic.
- `fileio.s` input-total overflow now returns the same `$15`
  (`CASM_DIAG_SOURCE_OFFSET_OVERFLOW`) so oversized input shares one stable code.

## Build and Artifact Results

- `cmake -S . -B build`: passed.
- `cmake --build build --target casm`: passed as build 1019.
- No-change CASM rebuild preserved build 1019.
- Linked code/data: 2,663 bytes (CODE `$07FE` + RODATA `$0269`).
- Total BSS: 512 bytes (unchanged from the WP3 baseline; `source.s` adds none).
- Envelope usage `$3400-$4066`; combined `$1000` headroom: 921 bytes.
- Relocation points: 315.
- Base/next PRGs: 2,665 bytes each.
- Final R6 PRG: 3,301 bytes, load address `$3400`, footer ends `52 36` ("R6").
- `source.s` appears once in the link manifest.
- `cmake --build build --target image_d64`: passed; `casm` PRG present on
  `build/image.d64`.

## User Runtime Matrix (confirmed 2026-07-16)

No `c64-testing` or web-emulator verification was used. The user ran CASM in the
supported C64/VICE or hardware environment and confirmed results as expected:

- [x] 17-byte raw fixture — unchanged `INPUT VALIDATED` success and clean return.
- [x] 256-byte raw fixture — exercises the exact single-block/EOF boundary.
- [x] 513-byte raw fixture — exercises multi-block traversal (256+256+1).
- [x] Empty openable file (where supported) — EOF at offset 0.
- [x] Missing file — open-failure diagnostic, clean central cleanup.
- [x] Second CASM launch — re-initialization and repeat traversal.
- [x] Read/close failure (if inducible) — retained ownership and retry.

Count equality at EOF is the internal gate against loss, duplication, or
premature termination. The user confirmed the runtime evidence and explicitly
approved completion on 2026-07-16, advancing CASM from `0.1.5` to `0.1.6`.
