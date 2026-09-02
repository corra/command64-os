# Walkthrough: CASM diagnostic id-space single source of truth

Taskwarrior: `df92683b-8e68-4350-8e0e-b80ad7c80720`
Branch: `feature/casm-phase14` (standalone hardening, not a Phase 14 WP)

## Why

Phase 14 WP89 added diagnostic codes `$57-$5A` and hit a real defect: the
message table, its build-breaking length assert, and
`scripts/verify_casm_diag_table.py` were all updated, but
`diagPrintFatal`'s **runtime** range check
(`cmp #CASM_DIAG_PROGRESS_LAST + 1 / bcs dpfUnknown`) still cut off at
`$56`, so `casm` printed `CASM: INTERNAL ERROR` instead of `LOCAL LABEL
BEFORE ANY GLOBAL LABEL` for `$57`. Three separate sites each hardcoded
"the highest valid diagnostic id", and only one of them (the table
assert) was build-breaking. The user asked whether a skill/workflow was
the right prevention -- it isn't; this project's pattern for "two things
must stay in sync" is a build assert, not a human checklist.

## What changed

One canonical symbol in `common.inc`:

```
CASM_DIAG_LAST = CASM_DIAG_PHASE14_WP86_LAST
```

Every id-space bound now keys off it, not off whichever phase's own
`*_LAST` alias is current:

| Site | Before | After |
| --- | --- | --- |
| `diagnostics.s` `diagPrintFatal` range check | `cmp #CASM_DIAG_PHASE14_WP86_LAST + 1` | `cmp #CASM_DIAG_LAST + 1` |
| `diagnostics.s` `diagMsgLo`/`diagMsgHi` length asserts (x2) | `= CASM_DIAG_PHASE14_WP86_LAST` | `= CASM_DIAG_LAST` |
| `scripts/verify_casm_diag_table.py` `last_id` | `consts["CASM_DIAG_PHASE14_WP86_LAST"]` | `consts["CASM_DIAG_LAST"]` |

Because the table-length `.assert` is build-breaking and now pins
`diagMsgLoEnd - diagMsgLo == CASM_DIAG_LAST`, and `diagPrintFatal`'s
runtime check is `CASM_DIAG_LAST + 1`, the runtime check and the verify
script are structurally incapable of drifting behind the table: bumping
`CASM_DIAG_LAST` without growing the table fails the build; growing the
table without bumping `CASM_DIAG_LAST` fails the same assert. A future
phase updates **one line** (plus the contiguity asserts for its own new
codes).

Comments at `CASM_DIAG_LAST` (common.inc) and both `diagnostics.s`
call-out blocks spell out this contract and cite the WP89 defect.

## Verification

- `cmake --build build --target casm` -> clean, "all 90 diagnostic
  identifiers + 2 extras render exactly the frozen text".
- **Deliberate-break test**: temporarily set
  `CASM_DIAG_LAST = CASM_DIAG_PHASE14_WP86_LAST + 1` (claim `$5B` valid,
  no table entry) -> build fails at `diagnostics.s:1420-1421`:
  `Error: CASM diagnostic message table (lo/hi) length must equal
  CASM_DIAG_LAST`. Reverted; rebuilt clean.
- `image_d64`, `test_image_d64` rebuilt clean.
- Assembled instruction stream unchanged from WP89 (the retargeted
  symbols resolve to identical values); only the embedded version-banner
  string moved with the build counter (1399 -> 1402, content-hash bump
  from the comment/symbol edits). No live VICE run needed -- WP89 already
  exercised `$57-$5A` through `diagPrintFatal` live, and this change
  makes the bound self-consistent rather than altering any path.

## Not done (deliberately)

- No skill or workflow added -- the build assert is the guard.
- `verify_casm_diag_table.py` still reads the message table directly
  rather than driving `diagPrintFatal`'s dispatch; the single-constant +
  build-breaking assert makes an additional dispatch-level test
  redundant.
