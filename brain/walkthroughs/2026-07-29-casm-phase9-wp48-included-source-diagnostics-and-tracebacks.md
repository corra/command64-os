# CASM Phase 9 WP48 Walkthrough

Status: Complete; user approved 2026-07-29
Branch: `feature/casm-phase9-wp48`
Final: CASM `0.1.50` build 1204

## Implemented

- Delivered source bytes carry packed root/include-catalog provenance without
  growing the 39-byte token record.
- Diagnostics inside included files resolve the original physical filename
  from the immutable include catalog.
- Fatal diagnostics render active include sites from innermost parent to root.
- Each traceback line reports the parent filename plus the `.INCLUDE`
  statement's line and start column.
- Catalog-read failure while rendering prints `<INCLUDE?>` and cannot replace
  the primary diagnostic.
- Fatal line-tail draining stops at packed file-identity changes, so an
  unterminated child line cannot append bytes from its resumed parent.
- Post-pop diagnostics recover depth and originating root from retained bounded
  frame metadata, even if lookahead has advanced into another top-level root.

## Build Evidence

- `casm`, `test_casm_pass1`, `test_casm_passcheck`, and `test_casm_frame` link
  at both `$3800` and `$3900` relocation bases.
- `casm_include_test_d64`, `image_d64`, `test_image_d64`, and
  `casm_overflow_test_d64` build successfully.
- Production artifact: 14,478 code bytes, 2,104 relocation points.
- Approved envelopes/headroom: CASM `$4300`/85 bytes,
  `test_casm_pass1` `$4200`/242 bytes, `test_casm_frame` `$4100`/52 bytes;
  `test_casm_event` `$1D00`/225 bytes; `test_casm_passcheck` remains `$4000`.
- One parallel `image_d64` attempt observed an incomplete EDLIN intermediate
  file due to concurrent build-directory access. A standalone rerun passed;
  no WP48 source or CASM target failed.

## Manual Runtime Verification

Use the supported local VICE setup. Boot Command64 normally; do not autostart
CASM from BASIC.

The first runtime pass confirmed filenames and columns but reported traceback
sites as line 3. Build 1203 replaces post-statement resume lines with dedicated
statement-start line captures; repeat the cases below and require line 2.

1. Attach `build/image.d64` to device 8 and
   `build/casm_include_test.d64` to device 9.
2. Boot Command64 from device 8 and confirm the first line begins
   `Command 64-DOS Version` and the shell prompt appears.
3. Enter `9:` to select the include test disk.
4. Run `CASM CASMIDP1.S`.
5. Confirm the primary diagnostic is `UNDEFINED SYMBOL`.
6. Confirm the filename line is `IN FILE CASMIDC2.S`, not `CASMIDP1.S` or
   `CASMIDC1.S`.
7. Confirm the location identifies line 2 in the grandchild.
8. Confirm two traceback lines appear in this order:

```text
INCLUDED FROM CASMIDC1.S LINE 2 COLUMN 5
INCLUDED FROM CASMIDP1.S LINE 2 COLUMN 5
```

9. Confirm CASM returns to a valid `c64[9]:>` prompt.
10. Run `CASM CASMIDUP1.S`. Confirm `IN FILE CASMIDUC2.S` and both traceback
    lines still appear even though the final identifier has no trailing newline.
    The source echo may be absent after lookahead pop, but parent text must not
    be shown as child text.
11. Run `CASM CASMIDDP1.S`. Confirm `INVALID SOURCE BYTE`,
    `IN FILE CASMIDDC2.S`, both traceback lines, and a source echo containing
    `.BYTE .`; it must not append `DRAINAFTER`, `ROOTAFTER`, or parent text.
12. Run `CASM CASMERR1.S` from `test.d64` (device 8) and confirm the ordinary
    single-root diagnostic still omits `IN FILE` and all `INCLUDED FROM` lines.
13. Optionally run `TEST_CASM_FRAME` from `casm_overflow_test.d64` on device 9
    and confirm all eight case markers are dots followed by the pass message.

## Completion Gate

The user reported that all runtime tests pass and explicitly approved marking
WP48 complete on 2026-07-29. The planned version-only increment advances CASM
to `0.1.50` build 1204. The no-change rebuild was stable, and all four disk
images rebuilt successfully. WP49 is not activated by WP48 completion.
