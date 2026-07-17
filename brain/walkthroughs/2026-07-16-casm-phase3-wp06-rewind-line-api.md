---
feature: casm-phase3-wp06-rewind-line-api
created: 2026-07-16
completed: 2026-07-17
status: completed
implementation-status: implemented-verified
---

# Walkthrough: CASM Phase 3 WP6 Deterministic Rewind and Bounded Line API

## Summary

WP6 adds `sourceRewind` (close/reopen with a full source-owned reset) and
`sourceNextLine` (bounded 255-byte logical lines) on top of WP5's normalized
source layer, and raises the CASM linker envelope from `$1000` to `$2000`.

Per the approved plan, buffer ownership uses **Option A**: `CasmIoBuffer` is
partitioned while a line is built — `[0 .. lineLength-1]` is the payload and
`[lineLength .. 255]` is the transfer region a refill reads into. This keeps the
no-second-buffer contract, adds no BSS, and lets `sourceNextLine` reuse WP5's
`sourceNextByte` normalization rather than duplicating a second newline state
machine.

## Files Changed

| File | Change | Notes |
|---|---|---|
| `src/external/casm/source.s` | Modify | `sourceRewind`, `sourceNextLine`, mode gate, `sourceNextResult` split, LINE-mode partitioned refill, `sourceComputeBase`, absolute cursor |
| `src/external/casm/fileio.s` | Modify narrowly | Additive `inputStreamReadInto`; `inputStreamRead` reimplemented as a thin caller |
| `CMakeLists.txt` | Modify | CASM `MAIN` envelope `$1000` → `$2000`; register two line-boundary fixtures |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify | `casmln255` and `casmln256` boundary fixtures |
| `src/external/casm/AGENTS.md` | Modify | Buffer partition, absolute cursor, mode exclusivity, rewind/lookahead split |
| `brain/plans/2026-07-16-casm-phase3-wp06-rewind-line-api.md` | Approved plan | Records Option A and the envelope decision |
| `wiki/tasks/casm.md`, `brain/task.md` | Task state | WP6 in progress pending completion |

`casm.s`, `common.inc`, and `state.s` are unchanged. The shipped path keeps its
byte-mode consume loop and `INPUT VALIDATED` output.

## Envelope Change

Phase 3 could not fit `$1000`: 725 bytes of headroom remained at WP5 against an
estimated 1,370-1,940 bytes for WP6-WP10 (WP9's mnemonic table alone is 168).
The parent plan directs implementation to stop for approval in exactly this case.
`add_ca65_app(casm ... "2000")` raises `MAIN: size`, matching the DEBUG
precedent (`pacman` uses `2800`, `edlin` `1800`). Relocation and R6 behavior are
unchanged; only the linked size bound moved.

## Static Verification

- **Byte mode is unregressed.** `inputStreamRead` is now a thin caller of
  `inputStreamReadInto` with identical destination/length/accounting.
  `sourceComputeBase` returns 0 in byte mode, so the refill takes the
  full-buffer path and installs `index = 0`, `len = 0 + count` — bit-identical
  to the pre-WP6 cursor, including the `$0100` encoding for a 256-byte block.
- **Aliasing invariant proven.** writePos (`CasmSourceLineLength`) ≤ readPos
  (`CasmSourceBlockIndex`) always: each BYTE result advances writePos by 1 and
  consumes at least one physical byte, so writePos can never outrun readPos.
  Equality occurs only immediately after a LINE-mode refill, where the base is
  set to `lineLength`; there the byte is loaded into `CasmSourceResultByte` by
  `sourceNextResult` before `sourceNextLine` stores it, making the same-cell case
  a read-then-write (in the steady state, a byte rewritten onto itself). A CRLF
  swallow or a newline advances readPos without advancing writePos.
- **Boundary-spanning line survives refill:** the partitioned read preserves
  `[0 .. lineLength-1]` and refills only above it.
- 255 payload bytes accepted; the 256th fails `$17` **before storing**
  (`cmp #CASM_SOURCE_LINE_PAYLOAD_MAX` / `bcs`).
- Embedded null returns `$19` in line mode only; byte mode still returns it as a
  valid `CASM_SOURCE_BYTE` per WP4/WP5.
- Null terminator at `[lineLength]` is always an already-consumed cell or past
  valid data, never unread input; 255 payload + terminator exactly fills 256.
- **Rewind:** close failure returns `$0D` with the handle retained in
  CLOSE_FAILED (primary not masked by `$14`); reopen failure returns `$14` with
  the source CLOSED/NONE and no leaked handle; success commits READY/BYTE and
  `sourceResetTraversal`. The reopen resets `CasmInputTotal`, so the EOF count
  invariant holds on the second traversal.
- **Mode exclusivity:** `sourceNextByte` gates on API BYTE; `sourceNextLine`
  promotes BYTE→LINE only at offset 0 with line state IDLE; mixing returns `$13`;
  rewind restores BYTE and the mode choice.
- No lexer state is written; lookahead invalidation is left to WP7 by design.
- No new BSS, `common.inc`, or state-layout change.

## Build and Artifact Results

- `cmake -S . -B build`: passed; `MAIN: start = $3400, size = $2000` confirmed.
- `cmake --build build --target casm`: passed as build 1024.
- No-change CASM rebuild preserved build 1024.
- Linked code/data: 3,171 bytes (CODE `$09FA` + RODATA `$0269`), up from 2,859
  (+312, inside the 250-320 estimate).
- Total BSS: 512 bytes (unchanged; Option A adds no storage).
- Envelope usage `$3400-$4262` = 3,683 bytes; `$2000` headroom: **4,509 bytes**.
- Relocation points: 388.
- `image_d64`: passed; `casm` present. `test_image_d64`: passed; `casmln255` and
  `casmln256` present.

## Fixture Byte Verification (host-side)

| Fixture | Size | Content |
|---|---:|---|
| `casmln255` | 263 | 255×`L`, LF at index 255 (last byte of block 1), then `SECOND` + LF |
| `casmln256` | 257 | 256×`L` then LF; the 256th `L` sits at column 256 |

`casmln255` is stronger than designed: its newline lands exactly on the block
boundary, so it exercises a maximum-length line, the latch-clearing newline, and
the block transition together.

**No embedded-null fixture exists.** CMake cannot emit a `$00` byte in a string
(`string(ASCII 0 ...)` is rejected), and one would prove nothing here: `$19` is
line-mode only and the shipped path never calls `sourceNextLine`, so a null
fixture would only confirm byte mode passes nulls through. `$19` is static-only,
and adding a checked-in binary or a one-off host script was rejected.

## Verification Boundary

`sourceRewind` and `sourceNextLine` have **no caller on the shipped path** — the
entry point is unchanged and WP10 still owns the token dump. WP6's new routines
are therefore verified statically; adding a temporary rewind or line smoke path
would be new observable behavior and is a stop condition. Rewind equivalence and
line coordinates become runtime-observable in WP10 (resolution #8).

## User Runtime Matrix (confirmed 2026-07-17)

The user ran the matrix from the relocated `$2000` envelope image. The production
path is unchanged from WP5, so this confirms non-regression plus the two new
line-boundary cases:

- [x] `casmln255` — 255-byte line with the newline on the block boundary →
      `CASM: INPUT VALIDATED`.
- [x] `casmln256` — 256-byte line → the `$16` location-overflow diagnostic,
      displayed as `CASM: INTERNAL ERROR` (see note).
- [x] `casm256`, `casmmulti` — the `$16` diagnostic, displayed as
      `CASM: INTERNAL ERROR` (unchanged code from WP5).
- [x] `casmempty` — `CASM: CANNOT OPEN INPUT`. **Expected platform limitation:**
      the runtime environment cannot open a zero-size SEQ file, so the open fails
      before any traversal (diagnostic `$0B`). This supersedes the earlier
      EOF-at-offset-0 expectation, which is unreachable when the open itself
      fails. The empty-input EOF path remains statically correct for any
      environment that can open a zero-length file.
- [x] Byte-mode normalization is identical to WP5 (`sourceNextResult` is the WP5
      code), so `casmshort`, `casmcr`, `casmcrlf`, `casmsplit`, `casmblank`, and
      `casmfincr` remain `INPUT VALIDATED` by non-regression.

### Note: `INTERNAL ERROR` is the expected `$16` display at this phase

`diagPrintFatal` maps only the Phase 2 diagnostic range `$01-$13`; every Phase 3
code (`$14-$1B`), including `$16` location overflow, falls to the generic
`msgUnknown` = `CASM: INTERNAL ERROR`. The returned diagnostic **code** is
correct; wiring the human-readable Phase 3 diagnostic text is explicitly WP10's
scope, and expanding diagnostic display in WP6 is a stop condition. So
`casmln256`, `casm256`, and `casmmulti` correctly detect the overlong line and
report it — the message text just reads generically until WP10.

The user confirmed these results as expected and approved completion on
2026-07-17, advancing CASM from `0.1.7` to `0.1.8`.
