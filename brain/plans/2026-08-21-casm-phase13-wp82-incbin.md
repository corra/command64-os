---
feature: casm-phase13-wp82-incbin
created: 2026-08-21
status: proposed
taskwarrior: TBD (created on approval)
depends-on: CASM Phase 13 WP81 (.RES/.FILL/.ALIGN), complete and merged into
  feature/casm-phase13 (brain/walkthroughs/2026-08-21-casm-phase13-wp81-
  res-fill-align.md)
---

# Plan: CASM Phase 13 WP82 - .INCBIN

## Status

**Complete.** Approved 2026-08-21 on `feature/casm-phase13-wp82`. See the
completion walkthrough:
`brain/walkthroughs/2026-08-21-casm-phase13-wp82-incbin.md`.

Parent plan: `brain/plans/2026-08-21-casm-phase13-data-construction-
directives.md`. Branch: `feature/casm-phase13-wp82`, cut from
`feature/casm-phase13` (which now includes WP81's merge).

## Objective

Add `.INCBIN "filename"`: include a raw binary file's bytes directly into
the assembled output, streamed through bounded buffers, with Pass 1/Pass 2
file identity and length verified independently (the master plan's own
line, `brain/plans/2026-07-16-casm-assembler-implementation-plan.md:470-
489`: "`.incbin` records and verifies native file identity/length between
passes"). Does **not** deliver `.ASSERT` (WP83), DASH adoption (WP84), or
`.STATIC`/`.RELOC` (out of Phase 13 scope).

**Risk gate**, mirroring WP81's own: `.INCBIN` is a new byte-emitting
construct with no existing syntax to collide with. The real risk is
entirely in its own file-I/O correctness (a truncated/misread include must
never silently under- or over-emit bytes) rather than in existing-program
regression.

## Research Summary

A pre-planning research pass (this session, 2026-08-21) traced
`.INCLUDE`'s existing pipeline as the closest precedent:

1. **`.INCLUDE`'s quoted-filename grammar** lives in `lexer.s`'s
   `lexerScanIncludeOperand` (`lexer.s:370`): leading whitespace, opening
   quote, payload restricted to printable-PETSCII bytes, closing quote,
   trailing whitespace/comment, then NEWLINE/EOF. Diagnostics
   `CASM_DIAG_INCLUDE_FILENAME_EXPECTED`/`CASM_DIAG_INVALID_INCLUDE_
   FILENAME`/`CASM_DIAG_INCLUDE_FILENAME_TOO_LONG` are specific to that
   scanner. `parser.s`'s `ppsInclude` (`parser.s:250`) is a thin wrapper:
   call the scanner, set `CASM_OPKIND_IMPLIED`, return.
2. **`.INCLUDE`'s actual semantics are far heavier than `.INCBIN` needs.**
   `include.s` is a VMM-backed catalog + event log: `includeCatalogLoad`
   streams a child file's entire contents into the shared VMM source store
   via `sourceAppendFile` (source.s:723, itself calling
   `inputStreamOpen`/`inputStreamRead`/`slVmmWrite` in
   `CASM_VMM_BUFFER_SIZE`-byte chunks) and writes a catalog record;
   `includeEventRecord`/`includeEventReplay` log/replay one event per
   include *occurrence* so Pass 2 can diagnose
   `CASM_DIAG_INCLUDE_REPLAY_MISMATCH` without re-reading the file. This
   whole apparatus exists because an included file's *text* becomes new
   source statements for the lexer/parser to re-tokenize identically in
   both passes -- a fundamentally different job than `.INCBIN`'s, which
   only needs to emit the same raw bytes twice (once measured, once
   written), never re-lex them. **`.INCBIN` does not need a catalog, an
   event log, or VMM involvement at all.**
3. **File I/O primitives are already transient-safe for this use.**
   `fileOpenInput`/`fileRead`/`fileClose` (`fileio.s:111/221/337`) require
   `CasmInputState == CASM_FILE_STATE_CLOSED` on entry. Confirmed:
   `sourceLoad` (source.s:406) loads the *entire* top-level source (and
   every `.INCLUDE`d child, via `sourceAppendFile`) into VMM and closes the
   file immediately once loading finishes, *before* lexing/parsing ever
   starts (source.s:1804's own comment: "the input file was already closed
   by `sourceLoad` once loading finished"). So `CasmInputState` is
   guaranteed `CLOSED` throughout every statement's parse/emit, in both
   passes -- `.INCBIN` can safely open/read/close its own file transiently
   mid-statement, exactly like `.INCLUDE`'s own loader already does,
   without any handle conflict.
4. **`emitByte` is already pass-mode-transparent** (`emit.s:833` in this
   session's numbering -- WP81 relied on the identical property for
   `.RES`/`.FILL`/`.ALIGN`'s own loops): in `CASM_PASS_MODE_MEASURE` it
   discards the byte and advances `CasmPc`; in `CASM_PASS_MODE_EMIT` it
   writes the real byte. `.INCBIN` reuses this unconditionally, same as
   WP81's `emitFillLoop` -- no separate measure-only code path needed.
5. **Reusable diagnostics**: `CASM_DIAG_INPUT_OPEN_FAILED` ($0B),
   `_INPUT_READ_FAILED` ($0C), `_INPUT_CLOSE_FAILED` ($0D),
   `_STREAM_STATE_FAILED` ($13) already exist and are generic enough to
   reuse verbatim for `.INCBIN`'s own file I/O failures -- no new "file not
   found" diagnostic needed.
6. **DASH dogfooding**: per the master plan's own Scoping Decisions
   (inherited from the Phase 13 master plan, confirmed 2026-08-21), no
   external binary asset (font, charset, sprite data) exists anywhere in
   DASH's source today -- `.INCBIN`'s DASH-adoption requirement is
   explicitly waived, same treatment as `.ALIGN`. WP84 will not touch
   `.INCBIN`.
7. **Envelope**: every WP so far this Phase has needed at least one
   mid-increment envelope bump (WP81 needed nine, across `casm` itself and
   several test harnesses). Budget for the same here.

## Scoping Decisions (user-confirmed 2026-08-21)

The master plan's one-line spec ("records and verifies native file
identity/length between passes") under-specified the mechanism, unlike
WP81 where the fixed-fill directives' shape was obvious from the master
plan text alone -- both were resolved by explicit user confirmation before
implementation.

### Decision 1: dedicated filename scanner, or reuse `lexerScanIncludeOperand`?

The quoted-filename grammar is byte-for-byte identical to `.INCLUDE`'s own.
Two options:

- **(a) New dedicated `lexerScanIncbinOperand`**, a near-verbatim copy of
  `lexerScanIncludeOperand`'s structure, with its own
  `CASM_DIAG_INCBIN_FILENAME_EXPECTED`/`CASM_DIAG_INVALID_INCBIN_FILENAME`/
  `CASM_DIAG_INCBIN_FILENAME_TOO_LONG` diagnostics. Matches this project's
  established convention that every directive gets its own diagnostic
  identity even when grammar is shared (WP81's `.RES`/`.FILL`/`.ALIGN`
  each got directive-specific diagnostics despite sharing almost all
  mechanism). Costs `CasmIncbinFilename`/`CasmIncbinFilenameLen` bytes
  (mirrors `CasmIncludeFilename`/`Len`, `CASM_INCLUDE_FILENAME_BUFFER_
  SIZE` = 65 bytes) plus the scanner code itself (~duplicated cost of
  `lexerScanIncludeOperand`), non-trivial given this Phase's already-tight
  envelope.
- **(b) Literally reuse `lexerScanIncludeOperand`** (call it directly from
  `.INCBIN`'s own lexer dispatch), accepting that a filename-grammar error
  on an `.INCBIN` statement prints an `.INCLUDE`-branded message (e.g.
  "CASM: INCLUDE FILENAME EXPECTED" for a malformed `.INCBIN` operand) --
  misleading but functionally correct, and the smallest-footprint option.

**Confirmed: (a)**, consistent with WP81's own precedent and this
project's general preference for correct diagnostic identity over code
reuse when the two trade off directly.

### Decision 2: how strict should Pass 1/Pass 2 length agreement be?

The master plan asks for `.INCBIN` to "record and verify native file
identity/length between passes." Since `.INCBIN` (unlike `.INCLUDE`) opens
and reads its file **independently in each pass** rather than caching it,
there are two ways to satisfy this:

- **(a) Rely on the existing project-wide `emitCheckPassAgreement`**
  (`emit.s`, WP30's own final-`CasmPc` comparison between Pass 1 and
  Pass 2) as sufficient. Any length disagreement on *any* statement,
  including `.INCBIN`, already fails the whole assembly with
  `CASM_DIAG_PASS_MISMATCH` -- just not localized to which statement or
  file caused it. Zero new state, matches WP81's own "no separate
  measure-only path" minimalism.
- **(b) A dedicated per-occurrence check**: Pass 1 records each
  `.INCBIN` occurrence's measured byte count into a small fixed-capacity
  array (indexed by an occurrence counter reset at the start of each
  pass, mirroring `CASM_INCLUDE_PHYS_CAPACITY`'s own precedent, e.g. a new
  `CASM_INCBIN_MAX_OCCURRENCES = 16` or similar); Pass 2 compares its own
  freshly-measured count against the recorded one *at that specific
  statement*, raising a new, localized `CASM_DIAG_INCBIN_LENGTH_MISMATCH`
  (with source location) instead of a generic end-of-assembly failure.
  Costs a new small BSS array plus overflow bookkeeping (a new
  `CASM_DIAG_INCBIN_TOO_MANY`-style diagnostic if the occurrence count
  exceeds capacity), the same shape of cost `.INCLUDE`'s own catalog paid
  for a much richer feature.

**Confirmed: (a)** -- the master plan's wording is satisfied by the
existing whole-assembly guarantee, `.INCBIN`'s own file read is fully
transient (no caching, no risk of stale VMM state), and a localized
diagnostic is a nice-to-have polish item, not a correctness gap, given how
vanishingly unlikely a file changing size *during a single CASM invocation*
actually is on real hardware.

## Language Contract

```
directive-stmt ::= '.INCBIN' STRING
```

- The quoted filename uses a new dedicated scanner
  (`lexerScanIncbinOperand`) with the same shape as `.INCLUDE`'s own.
- No second operand, no offset/length slice syntax (matches the master
  plan's own terse spec; a future WP could add `.INCBIN "file", offset,
  length` if ever needed -- explicitly out of scope here).
- The file's *entire* contents are emitted verbatim, in order, starting at
  the current `CasmPc`.
- No relocation interaction (identical byte-emission shape to `.RES`/
  `.FILL`/`.ALIGN` -- inert filler, never calls `relocRecord`).
- A missing/unreadable file is a diagnostic error in *both* passes (unlike
  `.RES`/`.FILL`/`.ALIGN`'s count operand, there is no "tolerate in Pass 1"
  concept here -- the file must exist for the assembly to succeed at all,
  since Pass 1 needs its real length to advance `CasmPc` correctly).

## Technical Design

### Directive constant (`common.inc`)

```
CASM_DIRECTIVE_INCBIN = $0A
CASM_DIRECTIVE_COUNT  = $0B
```

### Lexer (`lexer.s`)

New `dirIncbinStr` constant and `compareTokenText`/`lexerEmitWithSubtype`
block appended to `lnDirective`'s chain (WP81's own precedent), before the
final `CASM_DIRECTIVE_UNKNOWN` fallback.

### Parser (`parser.s`)

New `ppsIncbin`, dispatched from `ppsMnemonic` for the new subtype
(mirroring `ppsInclude`'s own dispatch, not `ppsFillDirective`'s -- this is
a dedicated-scanner shape, not a bounded-expression shape). Calls the new
`lexerScanIncbinOperand` (Decision 1(a)), stages the filename into new
`CasmIncbinFilename`/`CasmIncbinFilenameLen` (mirroring `CasmIncludeFilename`/
`Len`'s own precedent, `CASM_INCLUDE_FILENAME_BUFFER_SIZE` = 65 bytes),
sets `CASM_OPKIND_IMPLIED`, returns.

### Emission (`emit.s`)

New `emitIncbin`, dispatched from `emitDirective`:

1. `emitMarkStarted` (a bare `.INCBIN` can be a relocatable assembly's
   first statement, same as `.RES`/`.BYTE`/an instruction).
2. `fileOpenInput` against `CasmIncbinFilename`. On failure, propagate
   `CASM_DIAG_INPUT_OPEN_FAILED` (reused, not new).
3. Loop: `fileRead` into `CasmIoBuffer` in `CASM_IO_BUFFER_SIZE`-byte
   chunks (mirroring `sourceAppendFile`'s own `safReadLoop` shape,
   source.s:741-811, but calling `emitByte` per byte instead of
   `slVmmWrite`) until `CASM_STREAM_EOF`. On a read failure, propagate
   `CASM_DIAG_INPUT_READ_FAILED` (reused) -- but first call `fileClose`
   (best-effort) so the handle is not leaked even on the failure path.
4. `fileClose`. On failure, propagate `CASM_DIAG_INPUT_CLOSE_FAILED`
   (reused).
5. No Pass 1/Pass 2 recorded-length comparison beyond `emitByte`'s own
   pass-mode-transparent behavior and the existing whole-assembly
   `emitCheckPassAgreement` (Decision 2(a)).

### Diagnostics (`common.inc`)

New contiguous block starting at `CASM_DIAG_PHASE13_WP81_LAST + 1` ($4F):

- `CASM_DIAG_INCBIN_FILENAME_EXPECTED` -- no opening quote / bad leading
  byte (Decision 1(a) only).
- `CASM_DIAG_INVALID_INCBIN_FILENAME` -- empty operand or disallowed byte
  (Decision 1(a) only).
- `CASM_DIAG_INCBIN_FILENAME_TOO_LONG` -- filename exceeds the 63-byte
  payload bound (Decision 1(a) only).
- `CASM_DIAG_PHASE13_WP82_LAST` sentinel, plus the matching `.assert`
  chain entries.

`CASM_DIAG_INPUT_OPEN_FAILED`/`_READ_FAILED`/`_CLOSE_FAILED`/
`_STREAM_STATE_FAILED` are reused verbatim, no new identifiers.

## Atomic Increments

1. **Contract freeze**: `CASM_DIRECTIVE_INCBIN` constant, the three new
   filename diagnostics (if Decision 1(a)), `.assert` chain updates. No
   behavior change yet.
2. **Lexer recognition**: `.INCBIN` token recognition in `lnDirective`.
3. **Filename scanner** (if Decision 1(a)): `lexerScanIncbinOperand`,
   mirroring `lexerScanIncludeOperand`'s structure exactly.
4. **Parser dispatch**: `ppsIncbin`, staging `CasmIncbinFilename`/`Len`.
5. **Emission**: `emitIncbin`, the open/read-loop/close sequence. First
   fixture(s) added here: a small accepted binary file included at a fixed
   `.ORG`, COMP-verified byte-identical against a hand-derived reference
   that concatenates the `.ORG` header with the raw file bytes.
6. **Diagnostic fixtures**: missing file (`CASM_DIAG_INPUT_OPEN_FAILED`),
   malformed filename operand (whichever of the three filename
   diagnostics applies), matching WP81's rejected-fixture pattern.
7. **Regression**: existing CASM test suite re-run clean (mirroring which
   suites WP81 re-ran: `test_casm_expr`, `test_casm_pass1`,
   `test_casm_frame`, plus the new `.INCBIN`-specific isolation harness if
   Increment 8 below adds one).
8. **Isolation harness** (TBD whether needed): a `casm_bounds.s`-style
   direct `emitDirective`-driven harness proving `emitIncbin`'s own
   open/read/close/PC-advance behavior against a small fixture binary
   packaged alongside the harness, independent of the lexer/parser. Given
   `.INCBIN`'s file I/O has more failure surface than `.RES`/`.FILL`/
   `.ALIGN`'s pure arithmetic, this is likely worth the same two-tier
   proof WP81 used (and which caught WP81's own real
   `ppsFillDirective` bug) -- confirm at increment-planning time.
9. **Envelope check**: measure CASM's actual size after all of the above;
   negotiate a bump if the current `$6700` ceiling is exceeded (expected,
   per every prior WP this Phase).
10. **Consolidated live-VICE verification + walkthrough**: every new
    fixture plus a clean regression run, recorded in
    `brain/walkthroughs/`, submitted for user sign-off.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/common.inc` | Modify (directive constant, diagnostics) |
| `src/external/casm/lexer.s` | Modify (token recognition, new filename scanner if Decision 1(a)) |
| `src/external/casm/parser.s` | Modify (new `ppsIncbin`) |
| `src/external/casm/emit.s` | Modify (new `emitIncbin`) |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify (new fixtures) |
| `tests/fixtures/casm/*.ref.hex` | Create (hand-derived trusted references) |
| A small binary asset fixture (e.g. `tests/fixtures/casm/casmincbin1.bin` or generated inline) | Create -- exact mechanism TBD (a raw binary fixture needs its own on-disk packaging step, distinct from `.seq`/`.ref` PRG conventions; needs its own look at `cc1541`'s raw-binary (`-T PRG` vs. a generic byte-content type) options before finalizing) |
| `CMakeLists.txt` | Modify (fixture/reference registration, possible new disk or reuse of `casm_phase13_test_d64`) |
| `tests/src/casm_incbin/casm_incbin.s` (if Increment 8 confirms an isolation harness is warranted) | Create |

## Stop Conditions

- Any harness/test fails unexpectedly, including a currently-passing
  fixture regressing after this WP's changes.
- The envelope bump needs approval before proceeding past it.
- A no-change rebuild changes any artifact.
- A genuinely new defect is discovered outside this WP's own scope:
  disclose and defer as a separate follow-up (default), do not fix inline
  unless explicitly directed in the moment.
- Decision 1 or 2 (above) turns out to need revisiting once real
  implementation work starts: pause and confirm before deviating.

## Documentation, Task, and DOX Updates

- Taskwarrior: WP82 task created under the Phase 13 parent (task 41) on
  approval of this plan.
- `wiki/tasks/casm.md`/`brain/task.md`: WP82 entry, updated at completion.
- No `CHANGELOG.md`/`KNOWLEDGE.md` update yet -- those land with WP85.

## Completion Gate

- `.INCBIN` live-verified in VICE: correct byte output for an accepted
  binary file, correct diagnostics for every error case.
- Native/COMP production fixtures byte-exact against hand-derived
  references.
- Full existing CASM regression suite clean, no regressions.
- No-change rebuild confirmed stable.
- Envelope bump (if any) explicitly approved, not silently absorbed.
- Walkthrough recorded in `brain/walkthroughs/`.
- User explicitly approves closing WP82.

## Progress

- 2026-08-21: Plan drafted after tracing `.INCLUDE`'s full existing
  pipeline (lexer/parser/catalog/emission) as precedent, and confirming
  `.INCBIN` needs a much lighter mechanism (no catalog, no VMM, no event
  log -- `emitByte`'s existing pass-mode transparency plus a plain
  transient file read suffices). Two Scoping Decisions need explicit
  approval before implementation: (1) a dedicated filename scanner vs.
  reusing `.INCLUDE`'s, and (2) whether the master plan's Pass1/Pass2
  identity requirement is satisfied by the existing whole-assembly
  `emitCheckPassAgreement`, or needs a new dedicated per-occurrence check.
  Awaiting approval of both before implementation begins.
- 2026-08-21: Both Scoping Decisions confirmed (dedicated scanner; rely on
  existing `emitCheckPassAgreement`). Increments 1-6 complete: contract
  freeze, lexer recognition, `lexerScanIncbinOperand`, `ppsIncbin`,
  `emitIncbin`, and production fixtures (1 accepted COMP-verified, 2
  rejected diagnostics verified), all live-verified in VICE. No isolation
  harness added (Increment 8 skipped as unnecessary -- see walkthrough).
  Found and fixed two real defects: a recurring `jmp (abs)` page-boundary
  hazard in `expr.s` (widened `CasmExprResolverAddrPad` 2->3 bytes, third
  occurrence of this hazard class), and a `cc1541 -f` filename-encoding
  mismatch (uppercase-typed argument encodes as bit-7-set PETSCII,
  lowercase-typed as unshifted -- fixed by pairing an uppercase `.seq`
  source filename with a lowercase `-f` packaging argument, matching this
  project's existing but previously-unexplained `.INCLUDE` fixture
  convention). Regression witnesses (`test_casm_expr`/`test_casm_pass1`/
  `test_casm_frame`) confirmed clean; full clean rebuild stable. Fifteen
  envelope bumps across `casm` and six test harnesses recorded in the
  completion walkthrough
  (`brain/walkthroughs/2026-08-21-casm-phase13-wp82-incbin.md`), awaiting
  user sign-off.
