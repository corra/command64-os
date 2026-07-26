# Walkthrough: CASM Phase 9 WP45 - Physical File Catalog and Dynamic Source Loading

## Implemented Behavior

- New standalone module `src/external/casm/include.s`: an 8KB metadata VMM
  store (`includeCatalogInit`), device resolution reusing the OS's own
  `DOS_PARSE_PREFIX` (`includeResolveDevice`), case-folded catalog identity
  comparison (`includeFoldByte`, `includeCatalogFind`), and deduplicated
  catalog load with transient child open/append (`includeCatalogLoad`).
- `source.s` gained `sourceAppendFile`: appends one more file's bytes at the
  true end of already-loaded content (`CasmSourceLoadedLenLo/Hi`) without
  ever touching the live traversal read cursor
  (`CasmSourceVmmCursorLo/Hi`), via a new shared stream cursor
  (`CasmSourceStreamCursorLo/Hi`) that `sourceLoad`'s existing per-file loop
  now also routes through.
- `casmRunPass`'s `.INCLUDE` dispatch is **unchanged from WP44**: a valid
  statement still reports `CASM_DIAG_NOT_IMPLEMENTED` before any emitter
  effect. `include.s` has no production call site; only the dedicated
  `test_casm_catalog` harness exercises its public ABI. `casm.s`'s stale
  comment (which had claimed WP45 would replace that boundary) is corrected
  to name WP46.
- New diagnostic `$34` `CASM_DIAG_INCLUDE_CATALOG_FULL` (the 32-record
  physical catalog is full). Two originally-planned diagnostics (metadata
  alloc/transfer failure) were dropped before implementation: tracing every
  call site found `vmmStoreAlloc`/`vmmWindowRead`/`vmmWindowWrite` already
  propagate their own correct diagnostics for every failure those would have
  covered -- the same "reserved but unreachable" situation WP23 found for
  `CASM_DIAG_VMM_ALLOC_TOO_LARGE`.
- Reused OS behavior discovered during implementation: `DOS_PARSE_PREFIX`
  (`parsePointerDevice`, `src/command64/utils.asm`) advances its caller's
  zero-page pointer past a recognized `8:`/`9:`/`10:`/`11:` prefix in place,
  so `includeResolveDevice` needs no independent colon scan at all -- using
  one would have risked disagreeing with the OS's own strict recognition on
  an edge case like `"FOO:BAR"` (colon is an accepted WP44 filename byte).
- Since `DOS_OPEN_FILE` only ever honors an explicit prefix in its filename
  string or else `CurrentDevice` -- never a caller-supplied device --
  `includeSynthesizeOpenName` always builds an explicit `<device>:<name>`
  string before the real open, so an inherited (non-`CurrentDevice`) parent
  device reaches the OS correctly.

## User-Confirmed Scope Decisions (recap)

1. Standalone module + harness only; no `casmRunPass` wiring (WP46's job).
2. Explicit device-prefix synthesis before every real open.
3. `sourceLoad`'s per-file body factored so a new shared stream cursor,
   distinct from the live read cursor, backs both the static top-level loop
   and the new dynamic append entry point.
4. A new dedicated `tests/src/casm_catalog/` harness, not an extension of
   WP44's grammar-only `test_casm_include`.

## Automated Evidence

- `casm` build 1170 passes; a second no-change build holds 1170. Measured
  directly via `ld65 -m`: MAIN uses 15,563 of 15,872 bytes at the amended
  `$3E00` envelope (309 bytes headroom). `build/casm.prg` is 16,933 bytes,
  loads at `$3400`, and ends with R6 footer `00 34 3f 07 52 36` (1855
  relocation entries).
- `test_casm_catalog` build 1009 passes and a no-change build holds 1009;
  `build/test_casm_catalog.prg` is 6,294 bytes, loads at `$3400`, R6 footer
  `00 34 da 02 52 36` (730 entries).
- `test_casm_pass1` (build 1034) and `test_casm_passcheck` (build 1016) --
  both link `source.s` whole -- build and hold stable unchanged at their
  existing `$3A00` envelope; the small `sourceAppendFile`/shared-cursor
  growth did not overflow either.
- `test_casm_include`, `test_casm_expr`, `test_casm_vmm`, `test_casm_symbols`,
  `test_casm_reloc` all rebuild successfully (each bumped once from
  `common.inc`'s shared content-hash change; no behavior change expected or
  observed in any of them).
- `image_d64`, `test_image_d64`, and `casm_overflow_test_d64` all build
  clean. `casm_overflow_test_d64` carries the new harness as
  `test_casm_catalo` (16-character disk name, same truncation pattern as
  WP44's `test_casm_includ`) plus five new tiny raw-content fixtures
  (`casmcat1`-`casmcat5`, bare lowercase disk names per the existing
  cc1541/ca65 case-pairing convention), 143 blocks free.
- `git diff --check` passes.

## Runtime Evidence

Confirmed passing. Two real defects were found and fixed across three
runtime rounds with the user before the final clean pass -- both defects
were in test infrastructure or a shared-scratch aliasing bug, not in the
frozen Phase 9 contract itself:

1. **Round 1** (`.fffff....ff`, `D1=$0B` `CASM_DIAG_INPUT_OPEN_FAILED`): the
   harness hardcoded `CASM_DEVICE_MIN` (device 8) as the "parent device" for
   every real-load test case. The user's actual VICE setup boots `test.d64`
   on device 8 and switches to device 9 to run `casm_overflow_test.d64`
   (which is not itself bootable and carries the `casmcat*` fixtures) --
   device 8 never had the fixtures. Traced `cmdLoad` (`shell.asm`) and
   confirmed it only transiently overrides `CurrentDevice` for an
   embedded `LOAD "x",n` prefix, always restoring the prior value
   afterward, with no separate "device this app loaded from" tracked
   anywhere in the app table -- but a debug probe proved `CurrentDevice`
   was already correctly 9 by the time the harness ran (a bare,
   unprefixed `sourceAppendFile` call succeeded), so capturing
   `CurrentDevice` once at startup into a new `TestDevice` field and using
   it everywhere instead of a hardcoded device was the correct, sufficient
   fix.
2. **Round 2** (`.ff.f.......`, record dump showing `START=$0012 LEN=$0000`
   instead of the expected `START=$08 LEN=$0A`): a genuine production bug
   in `sourceAppendFile` (`source.s`). It stashed the file's start offset in
   `CasmValue0Lo/Hi` -- the same shared zero-page scratch pair
   `vwPrepareTransfer` (`vmm_store.s`, reached via `slVmmWrite` on every
   chunk write) already documents as its own offset+count scratch and
   clobbers on the very first chunk. The observed `START=$12` (18) was
   exactly `vwPrepareTransfer`'s own `offset+count` (8+10) computation
   bleeding through. Fixed by moving the stashed start offset to a new,
   never-shared field (`CasmSourceAppendStartLo/Hi`), writing
   `CasmValue0Lo/Hi` only once, at the very end, after every clobbering
   call has already run -- the same aliasing bug class this project has
   hit repeatedly (WP23-25's `vmm_store.s`, WP44's own test harness), and
   one `include.s`'s own header comments explicitly warned about, yet this
   routine fell into it anyway.
3. **Round 3**: after both fixes, the user ran the rebuilt
   `test_casm_catalo` and confirmed all 12 cases pass:

```text
............
CASM CATALOG: PASS
```

Both debug instrumentation additions (a captured-diagnostic print, then a
full record-field dump) were removed from the harness once each defect was
confirmed fixed; the final harness is clean of any diagnostic-only code.

## Manual Confirmation

1. Attach `build/casm_overflow_test.d64` in the supported local emulator (or
   use the generated disk on hardware) -- never the broken `c64-testing` MCP
   or a web emulator.
2. Run `test_casm_catalo` (the truncated on-disk name).
3. Confirm twelve dots and `CASM CATALOG: PASS`. -- **done, confirmed by the
   user.**
4. Optionally re-run `test_casm_includ` (WP44's grammar harness, unaffected
   by this work) and `casm` against any existing trusted-reference `.seq`
   fixture from `test_image_d64`, confirming `.INCLUDE` statements still
   report `FEATURE NOT IMPLEMENTED` unchanged from WP44 -- proving this WP
   added no observable production behavior.

## Completion Gate

The user approved WP45 completion. CASM advanced once to `0.1.47` build
1171 (a text-only version-digit substitution of equal length, so the PRG
size and R6 footer are unchanged from the pre-increment measurement); a
no-change rebuild held 1171. All three disk images rebuilt and passed.
Taskwarrior, `wiki/tasks/casm.md`, and `brain/task.md` closed WP45. **WP45
is complete.** WP46 is unblocked in Taskwarrior but not activated; it
remains separately gated on its own dedicated plan and approval.
