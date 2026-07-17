# CASM Phase 4 WP13 — Directives and Emission Engine Walkthrough

- **Date**: 2026-07-17
- **Version**: CASM `0.1.15`, build 1053
- **Plan**: `brain/plans/2026-07-17-casm-phase4-wp13-directives-emission.md`
- **Parent plan**: `brain/plans/2026-07-17-casm-phase4-statement-parser-opcode-table.md`

## Scope Delivered

- `emit.s` (new): `CasmPc` tracking, PRG load-address header + bounded 64-byte
  staged writes through `fileWrite`, `.ORG`/`.BYTE`/`.WORD` handling,
  per-instruction operand encoding, and the relative-branch displacement +
  `-128..+127` range check (moved here from WP12 with the program counter it
  depends on). Output is a plain absolute PRG.
- `common.inc`: diagnostics `$20`–`$23` and `CASM_EMIT_BUFFER_SIZE` with asserts.
- `diagnostics.s`: the four new messages and table extension.
- `parser.s`: `.BYTE`/`.WORD` deferral refinement; `parseNumericValue` exported.
- `casm.s`: output creation, the emit dispatch loop, `emitFinalize`, and
  `outputAbort` on the fatal path; options gate now accepts `/S` and rejects
  only `/M`/`/L`. Added a branch trampoline for the grown routine.
- Fixtures: `casmemit1`, `casmorg1`, `casmorg2`, `casmbr1`, and the runnable
  `casmhello` demo.

## Plan Adherence and Deviations

- Implemented per plan, single forward pass (no symbols in Phase 4).
- **Envelope amendment (approved)**: emission overflowed the `$2000` MAIN
  envelope by 108 bytes (CODE 5827 + RODATA 1940 + BSS 534 = 8300). Per the plan
  Stop Condition, work paused for approval; the envelope was raised
  `$2000` -> `$2800` (10 KB) in `CMakeLists.txt`. CASM now occupies
  `$3400`-`$5BFF` (base build); linked image is 7815 bytes.
- **Options decision (approved)**: output is operational by default; `/S`
  accepted, `/M`/`/L` rejected.
- No `CMakeLists.txt` source-list edit for `emit.s` (glob-recursive).

## Automated Verification

- `cmake --build build --target casm` assembles/links cleanly; all size, range,
  and contiguity asserts pass.
- No-change rebuild does not increment `BUILD_CASM` (held at 1053).
- `test_image_d64` places all WP13 fixtures on `test.d64`.

## Runtime Verification (user-confirmed in local VICE)

| Command | Expected | Result |
|---------|----------|--------|
| `casm casmemit1` | `INPUT VALIDATED`; 20-byte PRG at `$C000` | pass |
| `casm casmorg1` | `CASM: ORG REQUIRED` | pass |
| `casm casmorg2` | `CASM: DUPLICATE ORG` | pass |
| `casm casmbr1` | `CASM: BRANCH OUT OF RANGE` | pass |
| `casm casmhello` then `LOAD CASMHELLO` / `GO 3400` | prints `YES IT BUILDS! -- CASM` + newline, returns to shell | pass |

- `casmemit1` expected bytes: `00 C0 A9 01 8D 20 D0 A2 10 E8 D0 FD 60 01 02 FF 34 12 CD AB`.
- `casmhello` is a plain PRG loading at the current UserProgStart (`$3400`); it
  prints via `DOS_PRINT_STR` and returns via `DOS_EXIT`, using literal addresses
  because labels are not yet supported. The message renders in the default
  uppercase charset.

## Known Limitations / Follow-ups

- Byte-for-byte reference comparison (`comp` against a `.ref`) is WP14's job;
  WP13 confirms a well-formed PRG is produced and the error paths fire.
- The `casm.s` emit driver is temporary scaffolding; WP14 replaces it with the
  production parser/emitter orchestration and formal partial-output cleanup.

## Completion

- User confirmed all testing passed and approved marking WP13 done on
  2026-07-17.
- Version stage advanced `14` -> `15` (CASM `0.1.15`), build 1053.
