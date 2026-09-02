# Walkthrough: CASM Phase 14 WP86 - Design Freeze

Plan: `brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md`
Taskwarrior: WP86 `5224c364-6181-4408-81a7-0c3519d0ac98`
Branch: `feature/casm-phase14`

## What this WP delivers

Purely additive declarations, no new behavior, no code path reads or
writes any of it yet:

- `common.inc`: `CASM_SYMBOL_FLAG_LOCAL` (flag bit 4, disjoint from the
  four existing flag bits, asserted); `CASM_SYMBOL_REC_SCOPE_LO/HI`
  (record offsets 46/47, inside the previously-reserved padding, asserted
  contiguous and in-bounds); four new diagnostic identifiers
  (`CASM_DIAG_LOCAL_WITHOUT_SCOPE` $57, `CASM_DIAG_DUPLICATE_LOCAL` $58,
  `CASM_DIAG_UNDEFINED_LOCAL` $59, `CASM_DIAG_LOCAL_IN_CONSTANT` $5A),
  contiguity-asserted after the existing progress-diagnostic range.
  `CASM_PETSCII_AT` ($40) already existed (WP53) and is reused as-is.
- `symbols.s`: `CasmSymbolInsertScopeLo/Hi` and
  `CasmSymbolLookupScopeLo/Hi` module-global storage, exported, documented,
  not yet read by `symbolsInsert`/`symbolsFindChain`/`symbolsLookup`.
- `casm.s`: `CasmCurrentScopeLo/Hi` BSS storage, documented, not yet read
  or written by `crpLabel` or anything else.

No lexer, parser, pass-driver, diagnostic-message-table, or map.s changes
in this WP — those are WP87-90.

## Why the diagnostic message table is untouched

`diagnostics.s`'s dense message table is length-pinned by
`.assert diagMsgLoEnd - diagMsgLo = CASM_DIAG_PROGRESS_LAST` (currently
`$56`). The four new WP86 codes ($57-$5A) sit above that pin, so they
exist as identifiers but have no table entry yet and cannot be produced by
any code path — consistent with "no readers/writers yet." Wiring them into
the table is WP89, when `crpLabel` actually raises them.

## Build evidence (this session, 2026-09-01)

All native, on the `feature/casm-phase14` branch, baseline `main@79f98b2`:

```
$ cmake -B build                        # configure clean
$ cmake --build build --target casm
...
[100%] ld65: linking CASM at $3800 (relocation base build)
[100%] ld65: linking CASM at $3900 (relocation +1 page build)
[100%] Building relocatable CASM.prg
reloc.py: .../build/casm.prg: base=0x3800, 23737 code bytes, 3886 relocation points
Verifying CASM diagnostic id -> message table
OK: all 86 diagnostic identifiers + 2 extras render exactly the frozen text
[100%] Built target casm
```

`$ cmake --build build --target image_d64` — full OS disk image, all 10
apps including `casm` and `dash`, built clean, no assembler/linker errors.

`$ cmake --build build --target casm_phase13_test_d64` — Phase 13's own
test image (32 production fixtures + `test_casm_frame`) packed clean.

`$ cmake --build build --target test_image_d64` — full standalone
`test_casm_*` harness set (lexer, symbols, VMM, reloc, faultinject,
progress, and the rest) built and packed clean.

No assembler diagnostic, no linker error, no build-breaking `.assert`
tripped by the new constants. Six `tests/src/casm_*` `BUILD_TEST_CASM_*`
counters auto-incremented because `symbols.s` (an import of those
harnesses) changed content hash — expected, not evidence of a defect.

## Regression argument (why no COMP/VICE run this WP)

WP86 adds zero new instructions and zero new call sites — only unused
constants and unread/unwritten storage cells. Every existing code path is
byte-for-byte unchanged (confirmed: `casm.prg` still assembles as
`23737 code bytes` at the same load address with the same relocation
count as the pre-WP86 baseline reported in the Phase 13/progress
walkthroughs). A live VICE/COMP pass would necessarily reproduce every
existing result unchanged, since no instruction stream differs. Live
verification resumes at WP87 (lexer fixtures) once there is real new
behavior to exercise.

## Outstanding open items carried into later WPs

- Exact wording for `CASM_DIAG_LOCAL_WITHOUT_SCOPE` /
  `CASM_DIAG_DUPLICATE_LOCAL` / `CASM_DIAG_UNDEFINED_LOCAL` /
  `CASM_DIAG_LOCAL_IN_CONSTANT` message strings — drafted in the plan's
  Technical Design section, finalized when WP89 wires them into
  `diagnostics.s`.
- `CASM_DIAG_LOCAL_WITHOUT_SCOPE` vs. reusing
  `CASM_DIAG_INVALID_SOURCE_BYTE` for a malformed `@` token (bare `@`,
  `@@`, `@1`) — WP87's own decision, not this one (that diagnostic is
  about the token, not the scope).

## Sign-off requested

WP86 is source-complete and build-verified as described above. Requesting
approval to close WP86 and proceed to WP87 (lexer `@`-prefixed identifier
scanning).
