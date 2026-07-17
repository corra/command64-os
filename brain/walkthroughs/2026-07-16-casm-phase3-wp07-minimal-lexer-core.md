---
feature: casm-phase3-wp07-minimal-lexer-core
created: 2026-07-17
completed: 2026-07-17
status: completed
implementation-status: implemented-verified
---

# Walkthrough: CASM Phase 3 WP7 Minimal Lexer Core

## Summary

WP7 adds `lexer.s`, the first consumer of the WP4-WP6 source layer. It owns the
one-result lookahead and the token record in `state.s`, consumes the normalized
byte stream through `sourceNextByte`, skips whitespace and semicolon comments
(preserving the terminating newline token), and emits EOF, newline, and the
punctuation/delimiter tokens with file/line/column provenance captured before
each token's first byte. Any byte it cannot yet classify hits a single
not-implemented default arm that WP8 will replace.

Per the approved plan, this is **Option 1 (static-only)**: no entry-point change
and no new fixtures. The lexer has no shipped-path caller (the token dump is
WP10) and cannot traverse real source until WP8 adds identifiers, so WP7 is
verified statically. The shipped byte path is unchanged and still prints
`INPUT VALIDATED`.

## Files Changed

| File | Change | Notes |
|---|---|---|
| `src/external/casm/lexer.s` | Create | `lexerInit`, `lexerNext`, `lexerGetToken`, and the private lookahead/token primitives |
| `src/external/casm/common.inc` | Modify | Add the `CASM_LEXER_STATE_*` enum only (new ABI WP3 reserved) |
| `brain/plans/2026-07-16-casm-phase3-wp07-minimal-lexer-core.md` | Approved plan | Records Option 1 and the provenance-capture note |
| `wiki/tasks/casm.md`, `brain/task.md` | Task state | WP7 in progress pending completion |

`casm.s`, `state.s`, and `source.s` are unchanged by WP7. The multi-digit
`VERSION_STAGE` migration (repo-wide `.define` string macros) and the stage bump
to `9` were applied separately, which satisfies the `0.1.9` prerequisite the plan
called out; WP7 completes into the already-set `0.1.9`.

## Lexer Model (as implemented)

- **Lexer states** `CASM_LEXER_STATE_INIT/READY/EOF/ERROR` were added to
  `common.inc`; WP3 reserved the `CasmLexerState` byte and left its values to WP7.
- **Lookahead** (`lexerFill`/`lexerConsume`): one persistent result slot holding
  the source result code, byte, and provenance. It survives input-block
  transitions because it is BSS, and `lexerInit` invalidates it — discharging
  WP6's rewind obligation (the lexer owns lookahead invalidation after a rewind).
- **Provenance capture**: `lexerFill` reads the source's exported in-place
  location fields before consuming (the documented `sourceGetLocation` accessor
  surface, WP5 resolution #3) and clamps the column-exhausted latch (source
  column 0) to `CASM_SOURCE_COLUMN_MAX`. Actual column overflow stays enforced by
  `sourceNextByte`, which correctly rejects a 256th byte but allows a newline at
  the latch. It does not invoke the `sourceGetLocation` validation call, whose
  latch-`$16` is intentionally strict for byte-only queries and would otherwise
  wrongly reject a maximal-length line ending in a newline. No source-layer
  change was made.
- **Token primitives**: `lexerTokenReset` copies provenance and zeroes length;
  `lexerTokenAppend` is bounded to 31 payload bytes and returns `$18` on
  overflow; `lexerEmit` sets the type, `CASM_SUBTYPE_NONE`, and the terminator.
- **Dispatch**: whitespace (space/tab) skipped; `;` comment skipped to the
  terminating newline/EOF, which is preserved and emitted; the delimiters
  `, : # ( ) + - < >` emit their token types via a small RODATA lookup; EOF
  latches a repeat-stable EOF token; any other byte returns
  `CASM_DIAG_NOT_IMPLEMENTED` as the WP8 seam.

## Static Verification

- EOF, newline, and each punctuation token emit the correct type,
  `CASM_SUBTYPE_NONE`, length (0 for EOF/newline, 1 for punctuation), provenance,
  and null terminator.
- Whitespace is skipped and the following token's provenance is its own byte, not
  a skipped space, because each `lexerFill` re-snapshots from the advanced source
  position.
- A comment is skipped and its terminating newline is still returned; a comment
  ending at EOF returns EOF with no phantom newline.
- EOF is repeat-stable: once `_EOF` latches, `lexerNext` returns the EOF token
  with no source read.
- `lexerInit` invalidates the lookahead (the post-rewind obligation) and clears
  the token record.
- The not-implemented arm returns `$0A`; the append guard returns `$18`; a bad
  lexer state returns `$1B`.
- A source failure propagates with carry set, sets lexer `_ERROR`, and never
  closes the source.
- The exhausted-column-latch clamp preserves a valid provenance column for a
  newline following a 255-column line.

## Build and Artifact Results

- `cmake -S . -B build`: passed.
- `cmake --build build --target casm`: passed as build 1028; the CASM source glob
  discovered `lexer.s`.
- No-change CASM rebuild preserved the build number.
- Linked code/data: 3,544 bytes (CODE `$0B5C` + RODATA `$027C`), up from 3,171
  (+373, within the 300-400 estimate).
- Total BSS: 512 bytes (unchanged; `lexer.s` defines no BSS).
- Envelope usage `$3400-$43D7` = 4,056 bytes; `$2000` headroom: 4,136 bytes.
- Relocation points: 460.
- The multi-digit `CASM V0.1.9.<build>` banner assembles from `.define` string
  macros.
- `image_d64`: passed; `casm` present on `build/image.d64`.

## Verification Boundary

`lexerInit`/`lexerNext`/`lexerGetToken` have **no caller on the shipped path** —
the entry point is unchanged and the token dump is WP10. The lexer also cannot
traverse any existing fixture end-to-end because every fixture contains letters,
which hit the not-implemented seam until WP8. WP7 is therefore verified
statically; its first honest end-to-end runtime pass is WP8, and full token-level
observation is WP10.

## User Runtime Matrix (pending)

Under Option 1 the shipped path is unchanged, so the matrix confirms
non-regression only:

- [ ] The newline and line-boundary fixtures still reach `INPUT VALIDATED`.
- [ ] `casm256`/`casmmulti`/`casmln256` still return the `$16` code (shown as
      `INTERNAL ERROR` until WP10).
- [ ] `casmempty` still reports the platform open failure.
- [ ] A second CASM launch is clean, and CASM still loads from the `$2000` image.

Token-level behavior becomes observable in WP10. The user confirmed the shipped
path behaves as expected (non-regression) and approved completion on 2026-07-17.
The version was already advanced to `0.1.9` by the separately committed
multi-digit version-stage migration, so WP7 completes into `0.1.9`.
