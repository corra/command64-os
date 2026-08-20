# CASM Phase 12 WP74 String Literals Completion Gate

## Result

WP74 is implemented, verified, and explicitly user-approved. Native CASM
accepts ca65-compatible double-quoted strings in `.BYTE` lists, emits their
printable PETSCII bytes verbatim, accepts empty and mixed lists, and rejects
unterminated or non-printable strings. Strings remain invalid outside `.BYTE`;
there are no escapes or implicit terminators.

## Implementation

- `CASM_TOKEN_STRING` uses the lexer-owned 255-byte `CasmStringBuffer` and
  `CasmStringLength`; the frozen token record is unchanged.
- `.BYTE` emits each string byte through the normal `emitByte` path, preserving
  bounds and output behavior.
- Diagnostics `$49` and `$4A` report unterminated and invalid-byte strings.
- DASH adopts `.BYTE "0.1.4"`; native CASM, ca65, and the shipping artifact are
  byte-identical with SHA-256
  `3238b7863cc9b7ba7b07202c94dccb8dcbd1fd0fe4c578362f311b79757b814b`.

## Regression Evidence

- `cmake --build build --target casm_overflow_test_d64 casm_include_test_d64 casm_listing_test_d64 image_d64`: pass.
- Immediate no-change rebuild of the same targets: pass.
- `git diff --check`: pass.
- Final disk capacity: overflow 4 blocks, include 156 blocks, listing 1 block,
  shipping image 315 blocks.
- `test_casm_spanread` links at the approved smallest page-aligned `$3100`
  envelope after an 89-byte WP74 overflow at `$3000`.
- Fixture-free `test_casm_fsym` moved from the overflow image to the include
  image after the fully packed listing image proved unsuitable.

## Live VICE Evidence

- VICE 3.10 C64SC answered MCP ping and remained running after verification.
- Booted rebuilt `build/casm_include_test.d64`; screen row 0 decoded to
  `Command 64-DOS Version 0.4.1.2663` and was cross-checked by screenshot.
- Launched `test_casm_fsym` with exact PETSCII keyboard-buffer bytes.
- Result: `CASM FAULT SYMBOLS: PASS` followed by `c64[8]:>`.
- Screenshots: `/tmp/opencode/wp74-command64-boot.png` and
  `/tmp/opencode/wp74-fsym-result.png` (session evidence, not repository files).

## Manual Confirmation

1. Boot `build/casm_phase12_test.d64` into Command64.
2. Run the WP74 accepted STRING fixture and compare its output with
   `casmstring1.ref`; expect exact equality.
3. Run the six rejected STRING fixtures; expect the documented STRING or
   syntax diagnostics and no committed partial output.
4. Boot `build/casm_include_test.d64`, run `test_casm_fsym`, and expect
   `CASM FAULT SYMBOLS: PASS` followed by the Command64 prompt.
5. Inspect DASH's version display and confirm `0.1.4` remains unchanged.

## Completion Gate

The user approved this walkthrough on 2026-08-19. WP74 is complete and CASM
advanced from `0.2.7` to `0.2.8` build `1322`. Phase 12 remains open for WP75
consolidated verification.
