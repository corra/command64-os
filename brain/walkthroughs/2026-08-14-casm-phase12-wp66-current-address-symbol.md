# Walkthrough: CASM Phase 12 WP66 — Current-Address Symbol

Plan: `brain/plans/2026-08-14-casm-phase12-wp66-current-address-symbol.md`
(approved 2026-08-14, including the confirmed scoping decision that
`name = *` ships in this WP rather than deferring). Prerequisite: WP64
(contract freeze), complete. Branch: `feature/casm-phase12-wp65` (WP66
implemented on the same branch as WP65; not yet merged to
`casm-phase12`/`main`).

## What Shipped

- New `*` expression primitive (`CASM_TOKEN_STAR`, `CASM_PETSCII_ASTERISK
  = $2A`), evaluating to `CasmPc` — relocatable by construction, exactly
  like a label.
- `exprEvaluate`'s new `curAddr` primary-dispatch arm (`expr.s`): resolved
  inline (never through the resolver callback), `RESOLVED`+
  `SYMBOL_DERIVED` set unconditionally, `RELOCATABLE` conditional on the
  caller's relocatable-mode input, then falls through into the identifier
  arm's own shared addend/extraction/continuation tail — `*+N`, `*-N`,
  `<*`, `>*` all work without any dedicated code of their own.
- `name = *` (`ppsConstant`/`crpConstant`, `parser.s`/`casm.s`): a new
  `CasmConstantIsCurAddr` staging flag drives inline `CasmPc`-based
  resolution at Pass 1 (no Pass1→Pass2 resolution-sweep involvement
  needed — `CasmPc` is already final the instant the statement runs) and
  correct `RESOLVED`+`CASM_SYMBOL_FLAG_LABEL_DERIVED` classification.

## Increment 4 Finding (disclosed, fixed before any code shipped)

The plan's own Increment 4 called for tracing `crpConstant` live before
assuming `*`'s RHS handling could simply mirror the existing numeric-RHS
path. That trace found a real gap: `crpConstant`'s existing flag logic
only ORs in `RESOLVED` for an immediately-resolved constant — it never
sets `LABEL_DERIVED`, because no pre-WP66 RHS kind is both immediately
resolved *and* label-derived (a numeric RHS is resolved but static; an
identifier RHS is label-derived only via the deferred resolution sweep).
A naive numeric-shaped implementation of `*` would have silently
classified `bufstart = *` as a static, non-relocatable value — wrong,
since `*`'s value is exactly as load-address-sensitive as a label's. Fixed
by adding `CasmConstantIsCurAddr` and an explicit second OR in
`crpConstant`'s flags computation. This is exactly the kind of thing the
plan's Increment 4 was designed to catch before implementation, not after.

## Live VICE Evidence

Both new fixtures run against the real `casm.prg` (build 1289) via
`casm_include_test.d64`, Command64 shell dispatch (`casm <name>.s`), per
`.agents/workflows/vice-mcp-testing.md`:

- **`casmcuraddr1.s`** (`.ORG $C000`; `bufstart = *` as the first
  statement, capturing `$C000` itself since a constant definition never
  advances `CasmPc`; referenced afterward via `<bufstart`/`>bufstart`):
  `CASM: INPUT VALIDATED`. Extracted `casmcuraddr1.prg` directly from the
  disk image (after a clean VICE detach to flush the write-behind cache)
  and confirmed its bytes exactly: `A9 00 8D 20 D0 A9 C0 8D 21 D0 4C 00
  C0` — `LDA #$00` (`<bufstart`, correct), `STA $D020`, `LDA #$C0`
  (`>bufstart`, correct), `STA $D021`, `JMP $C000` (`bufstart`, correct).
- **`casmcuraddr2.s`** (`.ORG $C000`; `NOP`; `LDA #<*+3` — bare `*` with
  both extraction and an addend in one expression; `STA $D020`):
  `CASM: INPUT VALIDATED`. Extracted bytes: `EA A9 04 8D 20 D0` — `NOP`
  (`$C000`), `LDA #$04` (`*` evaluated to `$C001`, the address of this
  very `LDA` instruction, `+3` = `$C004`, low byte `$04`, correct), `STA
  $D020`.

Regression evidence (existing, pre-WP66 harnesses re-run live after the
`expr.s`/`parser.s`/`casm.s` changes): `test_casm_expr` (extended with 7
new `*` cases, `CASE_COUNT` 38→45) → `CASM EXPR: PASS`; `test_casm_symbols`
→ `CASM SYMBOLS: PASS`; `test_casm_pass1` → `CASM PASS1: PASS`;
`test_casm_include` → `CASM INCLUDE: ALL PASS`; `test_casm_frame` → `CASM
FRAME: PASS` (the latter two specifically because their own envelope caps
were bumped to absorb this WP's shared-module growth — direct regression
proof those bumps didn't break anything). All five returned cleanly to the
Command64 shell prompt.

Full disk-image tree (`image_d64`, `test_image_d64`,
`command64_casm_utils_d64`, `casm_overflow_test_d64`,
`casm_include_test_d64`, `casm_listing_test_d64`, `casm_phase10_test_d64`,
`casm_opcode_test_d64`) rebuilds with zero errors and zero envelope
overflows as of the final commit.

## Harness/Workflow Hazards Hit and Resolved

Two non-product issues surfaced while running this session's VICE
verification, both resolved per this project's own testing workflow
rather than mistaken for CASM defects:

1. **Hot-swapping a disk image on an already-attached, in-use unit mid-
   Command64-session left the shell reporting `DEVICE NOT PRESENT`**, even
   though `vice_disk_list` confirmed VICE itself had the correct media
   attached. Root cause: per `.agents/workflows/vice-mcp-testing.md`'s own
   Recovery table, "Machine/OS state is wrong" → `vice_machine_reset
   {mode: soft}` then re-boot Command64 with every needed unit attached
   *before* boot, not hot-swapped into a live session. Fixed by adopting
   that exact recovery sequence for every subsequent disk switch in this
   session.
2. **Shell dispatch of an underscore-bearing name via `vice_keyboard_type`
   silently mismatched** (`test_casm_expr` read back as `test←casm←expr`
   on screen — ASCII `_` ($5F) is left-arrow in PETSCII, not underscore),
   producing `BAD COMMAND OR FILE NAME` that could easily be misread as a
   real dispatch failure. Fixed per memory
   `reference-vice-shell-underscore-petscii`: `vice_keyboard_petscii` with
   explicit byte 164 for each underscore. Confirmed visually via
   `vice_display_screenshot` before trusting the fix, per the workflow's
   own "verify the decode table against a screenshot" guidance — also
   used to write a new reusable `tools/vice_screen_decode.py` (screen-code
   → text) instead of ad hoc one-off decoding.

## Stop Conditions Checked

- No existing harness/fixture failed unexpectedly that wasn't already
  root-caused and fixed (the three envelope overflows were expected
  shared-module growth, not defects, and are documented per this
  project's own `PriorSize -> NewSize` comment convention in
  `CMakeLists.txt`).
- No no-change rebuild changed an artifact.
- The `$6000` production envelope held without a bump, matching WP64's
  own +50-100 byte estimate for this sub-feature.
- No genuinely new defect outside this WP's own scope was found.

## Documentation and Tracker Sync

- `brain/KNOWLEDGE.md`: new WP66 as-built section recorded, immediately
  after WP65's own section.
- `brain/task.md`, `wiki/tasks/casm.md`: completion entries recorded.
- `docs/casm-utility.md`/`wiki/casm-utility.md` (kept byte-identical):
  new "Named Constants" and "The Current-Address Symbol (`*`)" sections
  added — closing the documentation gap WP65's own walkthrough explicitly
  flagged and recommended closing "before or alongside WP66".
- `wiki/casm-programmers-reference.md`: §11 (Expression Evaluator) and
  §12 (Symbol Table) updated to describe the current, accumulated
  WP65+WP66 grammar and symbol-record flag set, rather than the stale
  pre-WP65 description that predated both.
- `CHANGELOG.md`: entries added for both WP65 and WP66 under
  `[Unreleased]` → `Added` (WP65 had none yet either — added together).
- Taskwarrior task (`074c9d56-f6d9-4d65-8de4-96421d4c21b1`) marked done.

## Outcome

**WP66 complete, user-approved 2026-08-14.** All 7 Atomic Increments
implemented, build-verified across the full disk-image tree, and
live-verified against the real production binary under VICE — including
regression coverage of the two harnesses whose envelope caps were
directly bumped by this WP's own growth. WP67 (parentheses and explicit
precedence) is next and requires its own detailed plan and separate
approval before any source edit, per
`.agents/workflows/phased-implementation-planning.md`.
