---
feature: casm-phase3-wp05-newlines-provenance
created: 2026-07-16
completed: 2026-07-16
status: completed
implementation-status: implemented-verified
---

# Walkthrough: CASM Phase 3 WP5 Newlines and Provenance

## Summary

WP5 replaces WP4's transitional raw-byte semantics with the approved Phase 0C.1
normalized source layer. `sourceNextByte` now collapses CR, LF, and CRLF —
including a CRLF split across an input block boundary — into a single
`CASM_SOURCE_NEWLINE` via the persistent pending-CR latch, resolves a final CR
before EOF, and advances one-based line/column plus the physical offset with
checked commits. New `sourceGetLocation` exposes the next result's provenance.

A non-newline byte is still delivered raw in `CasmSourceResultByte` as
`CASM_SOURCE_BYTE`; the result byte is 0 for NEWLINE and EOF and is never
inferred from A or Z. Rewind and the bounded line API remain WP6; the lexer
remains WP7 and is now unblocked.

## Files Changed

| File | Change | Notes |
|---|---|---|
| `src/external/casm/source.s` | Modify | Normalized `sourceNextByte`, pending-CR/CRLF latch, location advance, `sourceFetchPhysical`, `sourceAdvanceNewline`, `sourceGetLocation` |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify | Five newline fixtures built from explicit `string(ASCII ...)` CR/LF bytes |
| `CMakeLists.txt` | Modify | Register the five new fixtures; the existing append loop handles them generically |
| `brain/plans/2026-07-16-casm-phase3-wp05-newlines-provenance.md` | Approved plan | Records approval, fixture decision, and the `casm256`/`casmmulti` consequence |
| `wiki/tasks/casm.md` | Task state | WP5 in progress pending completion |
| `brain/task.md` | Task mirror | Matches Taskwarrior and wiki state |

`casm.s`, `common.inc`, `state.s`, and `AGENTS.md` are intentionally unchanged.
The entry loop already treats any non-EOF, non-carry result as continue, so
`CASM_SOURCE_NEWLINE` needs no orchestration change and `INPUT VALIDATED` is
preserved. WP5 reuses existing constants and the WP3 state layout and adds no
storage.

## Normalization Model (as implemented)

- `sourceFetchPhysical` fetches exactly one physical byte, refilling only on an
  exhausted cursor, and advances the checked block index and physical offset.
  Every physical byte counts, so `CasmSourceOffset == CasmInputTotal` still holds
  at first EOF even when a CRLF consumes two bytes for one result.
- A CR emits one newline and arms `CasmSourcePendingCr`. On the next call an
  immediately following LF is swallowed (offset only, no line/column change) and
  the following byte is fetched; any other byte clears the latch and is
  classified normally.
- A lone final CR emits its newline, and the subsequent EOF clears the latch.
- `sourceAdvanceNewline` checks the 16-bit line against `CASM_SOURCE_LINE_MAX`
  before incrementing and resets the column to 1.
- Columns are 1..255. A byte at column 255 enters an exhausted latch (internal
  column 0); a further byte on the same line returns
  `CASM_DIAG_SOURCE_LOCATION_OVERFLOW` (`$16`) while a terminating newline is
  never blocked, so a legitimate 255-byte line plus newline succeeds.

## Static Verification

- CR, LF, and CRLF each yield exactly one newline; consecutive CR and consecutive
  LF yield consecutive newlines (consecutive empty lines).
- CRLF split with the CR at block byte 255 and the LF at the next block's byte 0
  is traced through the refill: the pending-CR latch is persistent state, so the
  swallow survives the block transition.
- A lone final CR yields a newline followed by EOF, with the latch cleared.
- The physical offset advances once per physical byte, including the swallowed
  CRLF LF, preserving the EOF count invariant.
- Line advance rejects overflow past `$FFFF`; column rejects a 256th byte on one
  line; both before committing the result.
- A 255-byte line plus newline succeeds (latch cleared by the newline).
- `sourceGetLocation` returns next-result coordinates, rejects a pending column
  latch in READY with `$16`, rejects invalid state with `$13`, and preserves X/Y.
- `source.s` still defines no BSS and writes no lexer state; `casm.s` unchanged.
- Column advance traced at 1, 254, 255, and the 256th-byte `$16` overflow.

## Build and Artifact Results

- `cmake -S . -B build`: passed.
- `cmake --build build --target casm`: passed as build 1021.
- No-change CASM rebuild preserved build 1021.
- Linked code/data: 2,859 bytes (CODE `$08C2` + RODATA `$0269`), up from 2,663.
- Total BSS: 512 bytes (unchanged; WP5 adds no storage).
- Envelope usage `$3400-$412A`; combined `$1000` headroom: 725 bytes.
- Relocation points: 339.
- Base/next PRGs: 2,861 bytes each; final R6 PRG load address `$3400`.
- `cmake --build build --target image_d64`: passed; `casm` present on
  `build/image.d64`.
- `cmake --build build --target test_image_d64`: passed; `casmcr`, `casmcrlf`,
  `casmsplit`, `casmblank`, and `casmfincr` SEQ fixtures present on `test.d64`.

## Fixture Byte Verification (host-side)

| Fixture | Size | Content |
|---|---:|---|
| `casmcr` | 12 | `LINE1<CR>LINE2<CR>` — CR-only endings |
| `casmcrlf` | 14 | `LINE1<CRLF>LINE2<CRLF>` — CRLF endings |
| `casmsplit` | 260 | 255×`A`, CR at index 255 (last of block 1), LF at index 256 (first of block 2), then `END` |
| `casmblank` | 6 | `A<LF><LF><LF>B<LF>` — consecutive empty lines |
| `casmfincr` | 5 | `LINE<CR>` — final CR before EOF |

Byte offsets were confirmed by hexdump; `casmsplit` places the CRLF exactly on
the 255/256 block boundary.

## User Runtime Matrix (confirmed 2026-07-16)

No `c64-testing` or web-emulator verification was used. The user ran the matrix
in the supported C64/VICE or hardware environment and confirmed every case
behaved as anticipated:

- [x] `casmshort` (LF) — unchanged `INPUT VALIDATED`, clean return.
- [x] `casmcr` — CR-only endings, `INPUT VALIDATED`.
- [x] `casmcrlf` — CRLF collapses to one newline each, `INPUT VALIDATED`.
- [x] `casmsplit` — CRLF across the block boundary, `INPUT VALIDATED` (carries the
      multi-block count-invariant coverage).
- [x] `casmblank` — consecutive empty lines, `INPUT VALIDATED`.
- [x] `casmfincr` — final CR resolved before EOF, `INPUT VALIDATED`.
- [x] `casmempty` — EOF at offset 0, `INPUT VALIDATED`.
- [x] `casm256` — clean `$16` location-overflow diagnostic (256-byte single line
      exceeds the 255/8-bit column limit), clean return.
- [x] `casmmulti` — clean `$16` diagnostic for the same reason.
- [x] Missing file — open-failure diagnostic, clean central cleanup.
- [x] Second CASM launch — clean re-run.

`casm256` and `casmmulti` deliberately change from `INPUT VALIDATED` (WP4) to a
`$16` diagnostic: each is a single line longer than 255 bytes, which the approved
8-bit column contract rejects. They are retained unchanged as the byte-mode
line-overflow cases, and `casmsplit` replaces their block-traversal coverage.

Newline collapsing and coordinate values are not runtime-observable until WP10's
token dump; WP5's runtime gate was therefore non-regression plus the
consumed-versus-fetched count invariant. The user confirmed the runtime evidence
and approved completion on 2026-07-16, advancing CASM from `0.1.6` to `0.1.7`.
