# Walkthrough: CASM Phase 14 WP89 - Pass-Driver Wiring + Production Fixtures

Plan: `brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md`
Taskwarrior: WP89 `bb4e956b-ec93-4216-97b1-f1f29ee7e0f7`
Branch: `feature/casm-phase14`

## What this WP delivers

`@local` labels now work end to end through the real production
parser + pass driver.

### Scope tracking (`casm.s`)

- `CasmCurrentScopeLo/Hi` is a **global-label ordinal**, not a record
  index: reset to `CASM_SYMBOL_CHAIN_END` ($FFFF, "no scope open") at the
  start of each pass, bumped ($FFFF -> 0 -> 1 ...) by `crpLabel` on every
  global label, identically in Pass 1 and Pass 2. This avoids any
  record-index lookup in Pass 2 (where `crpLabel` skips `symbolsInsert`
  entirely) -- the ordinal is stable across the Pass1->Pass2 boundary
  because globals dispatch in the same order each pass.
- `crpLabel` splits on `CasmLabelName[0] == '@'`:
  - global label: bump the ordinal, then the existing Pass-1-only
    `symbolsInsert` path unchanged;
  - `@local` label: require `CasmCurrentScope != $FFFF` (else
    `CASM_DIAG_LOCAL_WITHOUT_SCOPE`), then Pass-1-only `symbolsInsert`
    with `CASM_SYMBOL_FLAG_LOCAL` set and `CasmSymbolInsertScope` =
    `CasmCurrentScope`; a `CASM_DIAG_DUPLICATE_SYMBOL` from
    `symbolsInsert` is translated to the scoped `CASM_DIAG_DUPLICATE_
    LOCAL`.
- `casmRunPass` publishes `CasmSymbolLookupScope = CasmCurrentScope`
  before every `parserParseStatement` (operand expressions are evaluated
  inline inside it, via the `symbolsLookup` resolver). A label is always
  its own statement, so a `@local` reference can never appear in the same
  statement that opened its scope.
- The Pass1->Pass2 constant-resolution sweep forces
  `CasmSymbolLookupScope = $FFFF` first (defensive -- constants can't
  reference locals, but this keeps the sweep off the last statement's
  stale scope).

### Diagnostics (`parser.s`, `expr.s`, `diagnostics.s`)

- `CASM_DIAG_LOCAL_IN_CONSTANT`: `ppsLabel` rejects a `@`-prefixed
  named-constant LHS (`@x = expr`); `ppsConstant`'s `@identifier` arm
  rejects a `@`-prefixed RHS operand (`y = @x`).
- `CASM_DIAG_UNDEFINED_LOCAL`: `expr.s`'s `identifier` arm stamps a new
  exported `CasmExprPrimaryWasLocal` flag (1 when the identifier primary's
  name starts with `@`, cleared at every `exprEvaluate` entry);
  `parser.s`'s `pevUnresolved` reads it to raise the scoped code instead
  of the generic `CASM_DIAG_UNDEFINED_SYMBOL` for an unresolved Pass-2
  operand. The bounded grammar's addend is always numeric, so the single
  identifier primary is the only symbol reference that can be unresolved.
- The four `$57-$5A` message strings are wired into `diagnostics.s`'s
  dense `diagMsgLo`/`diagMsgHi` table; both the assemble-time length
  assert and `diagPrintFatal`'s own runtime range check
  (`cmp #CASM_DIAG_PROGRESS_LAST + 1`) are retargeted to
  `CASM_DIAG_PHASE14_WP86_LAST`. `scripts/verify_casm_diag_table.py`'s
  frozen `EXPECTED` map and `last_id` are extended to cover them (build
  step now reports "all 90 diagnostic identifiers").
- `crpLabel`'s two local error paths call `diagSetLocFromStmt` so the
  diagnostic points at the label statement (`CasmStmtLoc`), not at
  wherever the previous statement's operand-expression parse left
  `CasmDiagLoc` -- caught live: the first run of `casmlocnoscope` reported
  "AT LINE 1" (the `.ORG` operand's stale location) instead of the
  `@X:` line.

## Two real defects found and fixed live

1. **Stale fatal-diagnostic location** (above) -- `casmlocnoscope`
   reported the wrong source line until `diagSetLocFromStmt` was added to
   `crpLabel`'s local error paths. Static review missed it; the first
   live fixture run showed it.
2. **`diagPrintFatal` runtime range check not retargeted** -- the
   assemble-time table-length assert passed and
   `verify_casm_diag_table.py` was green, but `diagPrintFatal`'s own
   `cmp #CASM_DIAG_PROGRESS_LAST + 1 / bcs dpfUnknown` still cut off at
   $56, so the first `casmlocnoscope` run printed
   `CASM: INTERNAL ERROR` instead of `LOCAL LABEL BEFORE ANY GLOBAL
   LABEL`. Fixed by retargeting the runtime check too.

## Production fixtures: `casm_phase14_test.d64`

Nine new fixtures added to `cmake/GenerateCasmTestFixtures.cmake` and
packed onto `casm_phase14_test_d64` (alongside `test_casm_scope`).

### Accepted (COMP-verified against hand-derived `tests/fixtures/casm/casmloc*.ref.hex`)

| Fixture | Proves | Result |
| --- | --- | --- |
| `casmloc1` | `@local` as a backward branch target in one scope | `FILES COMPARE OK` |
| `casmloc2` | same local name `@X` under two globals -> two distinct symbols, displacements -4 and -2 | `FILES COMPARE OK` |
| `casmloc3` | a **forward** `@local` reference, resolved in Pass 2 | `FILES COMPARE OK` |
| `casmloc7` | `@LOOP` (local) vs `LOOP` (global) -> `JMP LOOP` and `JMP @LOOP` hit different addresses | `FILES COMPARE OK` |

### Rejected (live-verified for the scoped diagnostic + correct source location)

| Fixture | Diagnostic | Location |
| --- | --- | --- |
| `casmlocnoscope` | `LOCAL LABEL BEFORE ANY GLOBAL LABEL` | line 2, col 1 (`@x:`) |
| `casmlocdup` | `DUPLICATE LOCAL LABEL IN SCOPE` | line 5, col 1 (the redefinition) |
| `casmlocundef` | `UNDEFINED LOCAL LABEL` (Pass 2) | line 3, col 9 (`jmp @missing`) |
| `casmlocconstl` | `LOCAL LABEL NOT ALLOWED IN CONSTANT` | line 3, col 4 (`@x = 1`) |
| `casmlocconstr` | `LOCAL LABEL NOT ALLOWED IN CONSTANT` | line 5, col 6 (`y1 = @x`) |

## Envelope

`casm.prg`: 24202 code bytes (WP88 baseline 23873, +329). Full link map
check: BSS ends at `$A33B`, MAIN ends at `$AC00` -> **2245 bytes
headroom**. No envelope concern; MAIN stays `$7400`.

## Build evidence (this session, 2026-09-01)

```
$ cmake --build build --target casm
...
reloc.py: .../build/casm.prg: base=0x3800, 24202 code bytes, 3960 relocation points
Verifying CASM diagnostic id -> message table
OK: all 90 diagnostic identifiers + 2 extras render exactly the frozen text
[100%] Built target casm
```

`image_d64`, `test_image_d64`, `casm_phase12_test_d64`,
`casm_phase13_test_d64`, `casm_phase14_test_d64` all rebuilt clean.
`test.d64` hit its directory ceiling once more when the generic
`CASM_REF_NAMES -> test.d64` loop tried to pack `casmloc*.ref` -- the
loop's exclusion list was extended with `^casmloc` (same treatment as
`^casmpg`, `casmres1`, etc.).

## Live VICE evidence

Continuing the takeover-approved VICE instance (it crashed once
mid-session with a closed socket -- restarted via
`tools/vice_mcp_start.sh start`; nothing to kill, it had exited on its
own). All on `CASM V0.5.2.1399` unless noted:

- Booted `casm_phase14_test.d64`, `flush` -> `00, ok,00,00`.
- All 4 accepted fixtures: `casm <name>.s` then `comp <name>.prg
  <name>.ref` -> `FILES COMPARE OK` (all re-verified on 1399 after the
  two live-found defect fixes).
- All 5 rejected fixtures: correct scoped diagnostic text and correct
  `AT LINE n, COL c` source location, screen-decoded.
- No-locals regression: `casm casmassert1.s` + `comp casmassert1.prg
  casmassert1.ref` on `casm_phase13_test.d64` -> `FILES COMPARE OK` on
  1399. `test_casm_symbols` (Phase 6B/WP60) passed live at WP88 against
  the shared `symbolsInsert`/`symbolsLookup`.
- `flush` after tests -> clean. VICE left running, healthy, at the shell
  prompt. No checkpoints created.

### Overlay test-event gap (WP87-89)

The `c64-overlay-api` MCP failed to connect for this whole session
(CONNECT_TIMEOUT at startup), so the stream-overlay `test` events
(`testing`->`pass`/`fail`) that `.agents/workflows/overlay-build-events.md`
requires for every VICE-driven harness/fixture run did **not** fire
during WP87 (`test_casm_lexer`), WP88 (`test_casm_scope`,
`test_casm_symbols`), or the WP89 fixture sweep. The underlying HTTP API
(`http://127.0.0.1:8000/event`) was live the whole time -- only the MCP
bridge was down. Flagged by the user mid-WP89; fixed by firing events
via `curl` directly from then on (recorded as
`feedback-overlay-api-curl-fallback` in memory). A retroactive
`test`/`pass` event for the WP89 suite was relayed once the 9/9 result
was in.

## Sign-off requested

WP89 is source-complete, build-verified (90-identifier diag table,
2245-byte MAIN headroom), and live-VICE-verified (9/9 production fixtures,
2 real defects found live and fixed, no-locals regression confirmed).
Requesting approval to close WP89 and proceed to WP90 (`/M` symbol-map
qualified-name rendering for locals + `/L` non-regression).
