# Walkthrough: CASM Phase 14 WP88 - Symbol-Layer Scope Support

Plan: `brain/plans/2026-09-01-casm-phase14-local-anonymous-labels.md`
Taskwarrior: WP88 `c345de9c-b450-4266-912d-e5c075f77cd5`
Branch: `feature/casm-phase14`

## What this WP delivers

`symbols.s` now supports scoped local records end to end:

- `symbolsInsert` copies `CasmSymbolInsertScopeLo/Hi` into a new record's
  `CASM_SYMBOL_REC_SCOPE_LO/HI` whenever `CasmSymbolInsertFlags` has
  `CASM_SYMBOL_FLAG_LOCAL` set (independent of the pre-existing CONSTANT
  gate — the two flags are mutually exclusive per WP86).
- `symbolsFindChain`'s `sfcMatch` path now requires, for any candidate
  record that itself carries `CASM_SYMBOL_FLAG_LOCAL`, that its stored
  `SCOPE` equal the caller's filter scope before treating it as a match; a
  mismatch falls through to `sfcAdvance` exactly like a name mismatch
  would (continues the chain walk, not "not found"). A non-local candidate
  is never scope-checked at all.
- `symbolsInsert`/`symbolsLookup` each copy their own
  `CasmSymbolInsertScopeLo/Hi` / `CasmSymbolLookupScopeLo/Hi` into a new
  shared private `CasmSymScratchFilterScopeLo/Hi` immediately before
  calling `symbolsFindChain`, so the one shared chain-walk helper has a
  single place to read the filter from regardless of caller.

**Design simplified from WP86's original doc comment.** WP86 described a
"query name starts with `@`" mode-dispatch; WP88 found that unnecessary —
a local's stored name bytes already include the literal `@` (the lexer's
token text does, WP87), so a local and a global can never collide by name
comparison alone. The only case name comparison alone cannot resolve is
two *different* locals sharing one name under two *different* scopes, and
that only requires checking the matched candidate's own LOCAL flag, not
the query. Recorded in `symbols.s`'s own updated doc comments, not just
here.

**Still not wired into real assembly.** `casm.s`/`parser.s` never set
`CASM_SYMBOL_FLAG_LOCAL`, `CasmSymbolInsertScopeLo/Hi`, or
`CasmSymbolLookupScopeLo/Hi` yet — that is WP89. A `@name:` label in real
source today still inserts as an ordinary global (per WP87's own note).

## A real defect found and fixed live, not just in review

The first implementation clobbered `A` (the caller's `nameLen`, which
`symbolsFindChain` reads as its own first instruction) in both
`symbolsInsert` and `symbolsLookup`: the new scope-filter copy
(`lda CasmSymbolInsert/LookupScopeLo` / `sta ...` / `lda ...ScopeHi` /
`sta ...`) sat between the caller's `A = nameLen` and the
`jsr symbolsFindChain`, with nothing preserving `A` across it. This is
exactly the clobber-across-a-call bug class this project has hit before
(`feedback-static-analysis-cant-catch-runtime-clobbers`) — static review
and a clean assemble did **not** catch it; only the live harness run did.

- First `test_casm_scope` run: `CASM SCOPE: FAIL`, cases 10 and 11
  (`scpGlobalLookupScopeIndependent1`, `scpLocalNeverMatchesGlobal1`) of
  12 failed, screen-RAM-decoded dot/F sequence
  `.........ff.` confirmed via direct `$0400` reads.
- Root cause traced by re-reading the exact instruction sequence in both
  routines against `symbolsFindChain`'s own documented `A = nameLen`
  input contract.
- Fixed with a `pha`/`pla` bracketing the scope-filter copy in both
  routines (see `symbols.s`'s own WP88 fix comments at each site).
- Re-run: `CASM SCOPE: PASS`, 12/12.
- Regression proof: `test_casm_symbols` (the pre-existing Phase 6B/WP60
  harness, 13 sequential fixtures against the *same* `symbolsInsert`/
  `symbolsLookup` routines with no scope fields ever set) re-run live
  after the fix: `CASM SYMBOLS: PASS`. Confirms the fix is general and
  correct for the unscoped call shape too, not just the new scoped one.

## New standalone harness: `test_casm_scope`

`tests/src/casm_scope/casm_scope.s`, one shared symbol table, 12
sequential fixtures (same narrow-link/sequential-fixture shape as
`casm_symbols.s`, its own `symbolsLinkTable`/`diagPrintFatal`-stub
precedent included):

| Case | Proves |
| --- | --- |
| `scpInit1` | fresh-table local-shaped lookup is "not found" |
| `scpGlobalMain1` / `scpGlobalDraw1` | two ordinary global inserts, own scope indices captured (never hardcoded) |
| `scpLocalUnderMain1` / `scpLocalUnderDraw1` | the *same* local name (`@LOOP`) under two different scopes succeeds both times, landing at **different** record indices |
| `scpDuplicateSameScope1` | the *same* local name under the *same* scope a second time is rejected `CASM_DIAG_DUPLICATE_SYMBOL` |
| `scpLookupMainScope1` / `scpLookupDrawScope1` | a scoped lookup resolves to the *correct* scope's own value/id, not the other one's |
| `scpLookupWrongScope1` | a scope that owns no `@LOOP` at all reports not-found, even though `@LOOP` exists under two *other* scopes |
| `scpGlobalLookupScopeIndependent1` | a global lookup ignores an irrelevant filter scope entirely |
| `scpLocalNeverMatchesGlobal1` | a local literally named `@MAIN` never gets confused with the global `MAIN` |
| `scpRawRecordFields1` | direct VMM read confirms the on-disk `FLAGS`/`SCOPE_LO/HI` bytes, not just `symbolsLookup`'s own view |

New CMake wiring: `tests/src/casm_scope/BUILD_TEST_CASM_SCOPE` (seeded
`1000`), a `casm_scope` override block in `CMakeLists.txt` (mirrors
`casm_symbols`'s own: `symbols.s` + `vmm_store.s` + `resources.s` +
`common.inc`, `$1000` MAIN).

## Disk placement: a new dedicated `casm_phase14_test_d64`

Adding `test_casm_scope` to `test_image_d64`'s default target list first
hit `test.d64`'s 1541 directory-entry ceiling live (`ERROR: Dir track
full` while packing an unrelated EDLIN fixture appended after it) —
confirming the skill's own documented note that `test.d64`'s directory is
already full. `test_casm_scope` is `REMOVE_ITEM`'d from
`TEST_IMAGE_PRG_TARGETS` and instead lives on a new, dedicated,
self-bootable `casm_phase14_test_d64` (`command64` + `casm` + `comp` +
`test_casm_scope`, 471 blocks free) — created now rather than deferred to
WP89, per the per-phase-test-images convention, since this WP already
needed the disk home WP89 was going to create anyway.

## Build evidence (this session, 2026-09-01)

```
$ cmake --build build --target casm
...
reloc.py: .../build/casm.prg: base=0x3800, 23873 code bytes, 3918 relocation points
Verifying CASM diagnostic id -> message table
OK: all 86 diagnostic identifiers + 2 extras render exactly the frozen text
[100%] Built target casm
```

`casm.prg` +4 code bytes over the WP87 baseline (23869 -> 23873) — just
the two `pha`/`pla` pairs; the rest of WP88's logic was already linked in
from WP86/87's dormant declarations plus this WP's own new branches.

`test_casm_scope` (2503 code bytes), `image_d64`, `test_image_d64`,
`casm_phase12_test_d64`, `casm_phase13_test_d64`, and the new
`casm_phase14_test_d64` all rebuilt clean after the fix.

## Live VICE evidence

Continuing the same already-approved-for-takeover VICE instance from
WP87 (still Command64-resident, no reboot needed):

- Detached/attached `casm_phase14_test.d64` on unit 8 (rebuilt fresh).
- Dispatched `test_casm_scope` via `tools/vice_type_command.py` ->
  `vice_keyboard_petscii`.
- First run: `CASM SCOPE: FAIL` (cases 10/11 of 12), decoded via direct
  screen-RAM read, not just the screenshot glyphs.
- Fixed the `A`-clobber defect, rebuilt, redispatched (no reboot needed —
  same Command64 session, re-attach was enough): `CASM SCOPE: PASS`,
  12/12.
- Regression: detached/attached `build/test.d64`, dispatched
  `test_casm_symbols` (pre-existing WP60 harness): `CASM SYMBOLS: PASS`.
- VICE left running, healthy, at the shell prompt. No checkpoints were
  created; nothing to clean up.

## Sign-off requested

WP88 is source-complete, a real defect was found and fixed live (not
just caught by review), and both the new scoped harness and the
pre-existing unscoped harness pass. Requesting approval to close WP88 and
proceed to WP89 (pass-driver wiring: `casm.s` `CasmCurrentScope`
maintenance, `crpLabel` local stamping, scoped diagnostics, and the first
real production fixtures on `casm_phase14_test.d64`).
