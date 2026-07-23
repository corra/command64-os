---
feature: casm-phase6-wp28-pass1-address-assignment
created: 2026-07-22
status: complete
---

# Walkthrough: CASM Phase 6B WP28 Pass 1 Measure Engine

Plan: `brain/plans/2026-07-22-casm-phase6-wp28-pass1-address-assignment.md`

Taskwarrior: `712fe7af-1e41-46c9-9a19-49c2632cd15a`

## Outcome

WP28 wired WP27's VMM-backed symbol table into a real two-pass foundation:
a single `CasmPassMode` flag gated at exactly one point (`emitRawByte`),
colon-terminated label-statement grammar in `parser.s` that inserts into
the symbol table, `expr.s`'s resolver callback bound to `symbolsLookup` for
real, and a new `CASM_PARSER_STMT_FORCE_ABS` flag preventing Pass 1/Pass 2
operand-size disagreement for symbol-derived operands.

Two real correctness bugs were caught and fixed before any test ever ran:
the force-absolute derivation would have used the wrong expression flag
(letting resolved backward references disagree on size across passes), and
`emit.s`'s pass-mode gate as originally spec'd would have clobbered the
byte being emitted. Two further defects were found during VICE
verification, both in test infrastructure rather than production code: a
zero-page collision in the pre-existing `test_casm_expr` harness, and a
lowercase-directive-keyword bug in the newly generated `p1size1` fixture
that the lexer's uppercase-only identifier scan correctly rejected.

All 7 new `casm_pass1` fixtures and a `test_casm_expr` regression re-run
pass in VICE.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase6-wp28` |
| Branch point | `feature/casm-phase6-wp27` at `1d7d872` (not `main` — each WP branches from the previous WP's branch tip, matching the WP26->WP27 chain) |
| Baseline version | `0.1.29` build 1112 |
| Plan approval | Approved after dependency review surfaced the FORCE_ABS derivation bug (below) as a planning-time correction |

## Dependency Review Findings, Reconciled Before Implementation

1. **`expr.s`'s resolver callback was wired to a dead stub.**
   `parserRejectIdentifier` had stood in for the real resolver since Phase
   5; WP28 replaces it with `symbolsLookup`, which already matches the
   Phase 5 resolver ABI exactly (per WP27's own design), so no adapter code
   was needed.
2. **`CASM_PARSER_STMT_FORCE_ABS` must derive from
   `CASM_EXPR_FLAG_SYMBOL_DERIVED`, not `CASM_EXPR_FLAG_FORCE_ABS`.** A
   first-draft reading of the existing Phase 5 contract suggested reusing
   `CASM_EXPR_FLAG_FORCE_ABS` (set automatically whenever the resolver
   reports unresolved) as the signal for forcing absolute width. This is
   wrong: that flag is only set when the symbol is *unresolved*, so it
   would force absolute width for forward references only and let an
   already-*resolved* backward reference fall through to the
   zero-page-shrink heuristic in Pass 1 — while Pass 2 re-resolves the same
   symbol as resolved from its very first statement, disagreeing on size.
   `CASM_EXPR_FLAG_SYMBOL_DERIVED` (set on any resolver success, resolved
   or not) is the correct signal: once an operand's value came from a
   symbol at all, both passes must commit to the same absolute width
   regardless of resolution state. Caught and corrected during planning,
   before any code was written.

## Implementation

- `src/external/casm/common.inc`: `CASM_PARSER_STMT_FLAGS` (offset 6),
  `CASM_PARSER_STMT_SIZE` 6 -> 7, `CASM_PARSER_STMT_FORCE_ABS = %00000001`;
  new "Phase 6B two-pass contract" section with `CASM_PASS_MODE_MEASURE`
  (`$00`) / `CASM_PASS_MODE_EMIT` (`$01`); updated size/bitmask asserts.
- `src/external/casm/expr.s`: the `identifier:` branch now stages resolver
  arguments (`CasmPtr0Lo/Hi` = name pointer, `X/Y` = output view, `A` = name
  length) and calls `callResolver`. Fixed a real bug found while tracing
  this code: `callResolver`'s own return-address-push preamble (`PHA`)
  clobbers `A`, so the staged name length must be stashed in
  `CasmExprScratch0` across the call and reloaded before the `jmp` to the
  resolver. Also fixed a ca65 branch-range error in the pre-existing
  `addend:` block (`bcs return` -> `bcc :+ / jmp return / :`) surfaced by
  the new code shifting offsets.
- `src/external/casm/parser.s` (dispatched to a subagent): new exported
  `CasmLabelName`/`CasmLabelNameLen` BSS; new `ppsLabel` routine
  (colon-terminated label statement — copies the name out before consuming
  the colon, since `CasmTokenText` is a single transient buffer the next
  `lexerNext` call would otherwise overwrite); dispatch in
  `parserParseStatement` routes `IDENTIFIER` tokens to it; `ppsEmpty`/
  `ppsMnemonic` zero the new `Flags` field on every wholesale write;
  `parserRejectIdentifier` deleted, `symbolsLookup` bound as the resolver;
  `parserParseExpressionValue` derives `CASM_PARSER_STMT_FORCE_ABS` from
  `CASM_EXPR_FLAG_SYMBOL_DERIVED` (per the corrected design above), and its
  `pevUnresolved` branch becomes pass-mode-aware: `MEASURE` tolerates an
  unresolved symbol with a `$0000` placeholder, `EMIT` returns
  `CASM_DIAG_UNDEFINED_SYMBOL`.
- `src/external/casm/opcodes.s` (dispatched to a subagent): all three
  zero-page-eligible branches (`@notBranch`, `@notAbsX`, `@notAbsY`) now
  consult `CASM_PARSER_STMT_FORCE_ABS` before the existing `ValHi` check
  and take the absolute path unconditionally when set.
- `src/external/casm/emit.s` (dispatched to a subagent, which caught a real
  bug in the literal instructions handed to it): `emitInit` sets
  `CasmPassMode = CASM_PASS_MODE_EMIT` by default (production single-pass
  safety); `emitRawByte` stashes the byte in `X` first, then checks
  `CasmPassMode` — the originally spec'd ordering (check the mode, then
  reload the byte from `A`) would have clobbered the byte-to-emit with
  `CasmPassMode`'s own value. `MEASURE` mode returns before touching
  `CasmEmitBuffer`/`CasmEmitLen`; both modes still advance `CasmPc`.
- `src/external/casm/state.s`: comment updated to reflect the record's new
  7-byte size.
- `tests/src/casm_pass1/casm_pass1.s` (new, ~730 lines): standalone harness
  linking almost the full CASM module set (not `cli.s`/`casm.s` — see the
  file header for why). 7 fixtures: `p1label1` (bare label), `p1labelinsn1`
  (label + mnemonic same line), `p1fwd1` (forward reference), `p1back1`
  (backward reference — the flag-derivation regression case), `p1undef1`
  (undefined symbol tolerated in measure mode), `p1dup1` (duplicate-label
  detection, own custom driver), `p1size1` (comprehensive: forward
  reference + 3 labels + `.BYTE`/`.WORD` directives). Each fixture calls
  `symbolsInit` fresh so cross-fixture reuse of the label name `LOOP`
  cannot collide between fixtures.
- `cmake/GenerateCasmTestFixtures.cmake`: 7 new fixture files,
  `p1label1.seq` through `p1size1.seq`.
- `CMakeLists.txt`: `casm_pass1` special case added to `TEST_CA65_SRCS`
  (`fileio.s`, `source.s`, `state.s`, `lexer.s`, `parser.s`, `opcodes.s`,
  `emit.s`, `expr.s`, `diagnostics.s`, `resources.s`, `vmm_store.s`,
  `symbols.s`, `common.inc`), `TEST_PRG_SIZE = "3200"`; 7 fixture paths
  added to `CASM_TEST_FIXTURES`; production `casm` MAIN `$2F00` -> `$3000`.

## Bugs Found During VICE Verification (Test Infrastructure, Not Production Code)

1. **`test_casm_expr` zero-page collision (regression).** The harness's own
   mock `lexerNext` used `ScriptLo`/`ScriptHi = $70/$71` as its long-lived
   cursor — the same address as the general-purpose `CasmPtr0Lo/Hi` that
   `expr.s`'s new `identifier:` code now writes mid-`exprEvaluate`,
   clobbering the test's own cursor. Confirmed as a genuine regression (not
   pre-existing) by checking the WP21 verification walkthrough, which
   recorded this exact test passing 30/30 before WP28. Fixed by moving the
   test's cursor to `$7C`/`$7D`.
2. **`casm_pass1` case-mismatch, two rounds.** A first, wrong theory blamed
   a `cc1541 -w` content case-swap and "fixed" it by lowercasing the fixture
   source — this made things catastrophically worse (all 7 fixtures
   failing) via a cascading `CASM_DIAG_STREAM_STATE_FAILED` when an earlier
   fixture's now-malformed parse left its source open. Disproved by writing
   a throwaway script to parse the D64 image directly and confirming
   `cc1541 -w` performs zero content conversion. The real root cause,
   found after reverting to uppercase and adding temporary
   `KernalChROUT`-based hex-dump instrumentation: `ca65 -t c64`'s default
   charmap shifts uppercase ASCII letters in *quoted string literals* by
   `+$80` (`"LOOP"` assembles to `$CC,$CF,$CF,$D0`), but raw file content
   read via `cc1541 -w` is never converted — so the harness's own
   `nameLOOP`/`nameDATA`/`nameVALS` comparison strings, declared as quoted
   literals, could never byte-match the lexer's plain-ASCII token text.
   Fixed by declaring them as explicit `.byte $XX, ...` hex values. This
   does not affect `lexer.s`'s own `mnemonicTable`/`dirOrgStr`-style
   directive tables, which also use quoted literals: those compare through
   `compareTokenText`, which calls `normalizeChar` on both sides first,
   absorbing the shift.
3. **`p1size1`'s remaining failure: lowercase directive keywords.** After
   fix 2, 6 of 7 fixtures passed; `p1size1` alone still failed with
   `CASM_DIAG_INVALID_SOURCE_BYTE`. Added instrumentation reading
   `CasmDiagLocByte`/`CasmDiagLocLineLo`/`CasmDiagLocLineHi`
   (`diagnostics.s`) directly from the test harness after a `runMeasurePass`
   failure, which reported line 6, byte `$62` (`'b'`) — the `b` in
   `.byte`. `cmake/GenerateCasmTestFixtures.cmake`'s `p1size1.seq` block
   used lowercase `.byte`/`.word`, but the lexer's `isIdFirst`/`isIdCont`
   only accept unshifted uppercase (`$41`-`$5A`) or shifted PETSCII
   (`$C1`-`$DA`) — never lowercase ASCII (`$61`-`$7A`) — and every other
   fixture already used uppercase `.BYTE`/`.WORD`. Fixed by capitalizing
   both keywords in the CMake generator.

All temporary debugging instrumentation (`printHexByte`/`printHexNibble`
helpers, per-checkpoint `KernalChROUT` prints, the `CasmDiagLoc*` imports)
was removed from `casm_pass1.s` once root-caused, restoring it to a
production-clean state with only `sec`/`rts`-on-failure branches. Several
branches in `p1size1` required trampolining (`beq ok / jmp p1szFail / ok:`)
after the cleanup shifted offsets past ca65's +/-127-byte branch range,
consistent with this codebase's established convention for that situation.

## Static Verification

- All modules assemble with zero ca65 warnings/errors.
- Production `casm` MAIN grown `$2F00` -> `$3000` (23-byte measured
  overflow, 233 bytes headroom past the measured minimum — the smallest
  round-page step above it).
- `test_casm_pass1` builds cleanly; final PRG comfortably under its
  3200-byte `TEST_PRG_SIZE` budget.
- `test_casm_expr` re-assembles cleanly after the zero-page cursor move.
- A full clean rebuild (`image_d64` + `test_image_d64`, `test.d64` deleted
  and regenerated) confirmed no residual instrumentation bytes remained
  after cleanup.
- Both `image_d64` and `test_image_d64` build clean with `TEST_CASM_PASS1`
  packaged onto the test disk alongside every prior CASM test target.

## Runtime Verification

The user ran both programs from `build/test.d64` in VICE across several
iterations while the two test-infrastructure bugs above were being
root-caused:

| Program | Result |
| --- | --- |
| `TEST_CASM_PASS1` (new Pass 1 matrix, 7 fixtures) | pass, all 7 fixtures, hand-verified values confirmed via instrumentation before cleanup (`CasmPc=$C010`, `LOOP=$C003`, `DATA=$C009`, `VALS=$C00C`) |
| `TEST_CASM_EXPR` (regression check for the zero-page cursor move) | pass, all fixtures |

Both reported clean after the instrumentation was removed and the harness
rebuilt from scratch.

## Phase 6B Acceptance (partial — WP28's own scope)

Closed out in `wiki/tasks/casm.md`:

- [x] Pass 1 measure-mode address assignment exists: label statements
      insert into the symbol table at the correct `CasmPc`, both forward
      and backward references resolve correctly, and Pass 1/Pass 2 operand
      width now agrees for symbol-derived operands.
- [x] Undefined-symbol tolerance in measure mode verified (`p1undef1`).
- [x] Duplicate-label detection verified (`p1dup1`).
- [ ] Pass 2 real emission, relative branches from resolved symbols, and
      Pass 1/Pass 2 disagreement detection remain WP29-30, not yet started.

## DOX Closeout

Root, `src`, `src/external`, `src/external/casm`, `tests` contracts
rechecked. `brain/KNOWLEDGE.md` amended with a new Phase 0C.6 section
(rather than rewriting Phase 0C.5 in place) capturing the FORCE_ABS
derivation correction and the two test-infrastructure gotchas, since these
are corrections/additions to the frozen Phase 0C.5 contract rather than a
restatement of it. `AGENTS.md`'s general "stable ABI" guidance
(`src/external/casm/AGENTS.md`) does not hardcode `CasmParserStmt`'s byte
count and needed no edit; the only place that did hardcode a stale "6
bytes" figure is `wiki/casm-programmers-reference.md` (last updated at
WP15, already stale with respect to several WPs since then, e.g. mnemonics,
opcodes, directives, and symbols) — left untouched as pre-existing,
out-of-scope staleness rather than folded into this closeout.

## Completion Dry-Run and Final Increment (`0.1.29` -> `0.1.30`)

| Measurement | Value |
| --- | --- |
| Baseline | `0.1.29` build 1122 |
| Applied version | `0.1.30` |
| Build number | 1123 (incremented exactly once) |
| No-change rebuild | pass, held at 1123 |
| `image_d64` | pass |
| `test_image_d64` | pass |

## Approval

The user confirmed the final VICE run ("PASS!") after both the 7-fixture
matrix and the `test_casm_expr` regression check reported clean.

WP28 is complete. Taskwarrior (`712fe7af`), `wiki/tasks/casm.md`, and
`brain/task.md` are marked done. Taskwarrior WP29
(`8e989bdf-7aed-4bfe-ae9c-3771edb7caf5`) is unblocked but not yet planned in
detail — it requires its own dedicated plan and approval before any Pass 2
source is written, per the CASM `AGENTS.md` gate. The CASM Phase 6B
milestone remains open.
