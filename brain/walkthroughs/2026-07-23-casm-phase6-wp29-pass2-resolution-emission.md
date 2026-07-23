---
feature: casm-phase6-wp29-pass2-resolution-emission
created: 2026-07-23
status: complete
---

# Walkthrough: CASM Phase 6B WP29 Pass 2 Resolution and Emission

Plan: `brain/plans/2026-07-23-casm-phase6-wp29-pass2-resolution-emission.md`

Taskwarrior: `8e989bdf-7aed-4bfe-ae9c-3771edb7caf5`

## Outcome

WP29 replaced `casm.s`'s single-pass `startParseLoop` with a real two-pass
orchestrator: Pass 1 drives WP28's already-fixture-tested "measure engine"
(label definitions, no output file) to completion, then Pass 2 rewinds the
identical source and re-drives the same dispatch in `CASM_PASS_MODE_EMIT` to
produce real output, now that every label resolves through the WP27 symbol
table. Direct research at planning time found WP29's real scope narrower than
the parent Phase 6 plan's prose suggested: WP28 had already bound
`symbolsLookup` as the production resolver and made
`parserParseExpressionValue` pass-mode-aware, so zero changes were needed to
`symbols.s`, `parser.s`, `opcodes.s`, or `emit.s` — WP29 is exclusively a
`casm.s` orchestration rewrite plus new trusted-reference fixtures.

Building the rewrite surfaced one real defect before any test ran: three
`bcs` branches were pushed past ca65's ±127-byte relative-branch range by the
new code between them, caught immediately by the assembler and fixed with two
near trampolines. All 5 pre-existing Phase 4/5 trusted references, 3 new
label-bearing trusted references (reusing WP28's already-hand-verified
`p1fwd1`/`p1back1`/`p1size1` fixtures), and 1 undefined-symbol failure case
(`p1undef1`) pass in VICE.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase6-wp29` |
| Branch point | `feature/casm-phase6-wp28` at `0bc9374` (each WP branches from the previous WP's branch tip) |
| Baseline version | `0.1.30` build 1123 |
| Plan approval | Approved as drafted, including all three confirmed decisions (stale-doc correction, 3 new trusted references, 1 undefined-symbol fixture) |

## Dependency Review Findings, Reconciled Before Implementation

1. **WP29's real scope is narrower than the parent Phase 6 plan's prose.**
   WP28 already bound `symbolsLookup` as the production resolver and made
   `parserParseExpressionValue` pass-mode-aware; it just never drove
   `CASM_PASS_MODE_EMIT` outside `emit.s`'s own default. WP29 needed no
   `symbols.s`/`parser.s`/`opcodes.s`/`emit.s` changes at all.
2. **The master plan and `AGENTS.md` both still described a structured
   "Pass 2 emission events" design (2026-07-16) that WP26 had already
   overridden (2026-07-22) without either document being updated.** Fixed
   both, cross-referencing WP26's plan as the decision record.
3. **Relative-branch displacement computation needed zero code changes.**
   `emitInstruction`'s `eiRelative` path already computes displacement purely
   from `CasmParserStmt.VAL_LO/VAL_HI` against `CasmPc`, independent of
   whether that value came from a literal or a resolved symbol — confirmed
   by direct inspection, not assumed. WP30's remaining work is range-check
   verification and disagreement detection, not further plumbing.
4. **`fileCreateOutput` had to move from before Pass 1 to between the two
   passes**, matching WP26's frozen "no output file exists yet before
   Pass 1" contract exactly.

## Implementation

- `src/external/casm/casm.s`: `start` rewritten as a two-pass orchestrator.
  `symbolsInit` is called once before Pass 1. Pass 1 (`sourceOpen`/
  `lexerInit`/`emitInit` with `CasmPassMode = CASM_PASS_MODE_MEASURE`) drives
  the new private `casmRunPass` dispatch with no output file created. On
  success, Pass 2 calls `sourceRewind`/`lexerInit` again, `fileCreateOutput`
  (moved here from its old pre-Pass-1 position), `emitInit`, sets
  `CasmPassMode = CASM_PASS_MODE_EMIT`, and re-drives the identical
  `casmRunPass`. `casmRunPass` is the single shared per-statement dispatch:
  it branches on `CasmPassMode` only for the label-statement case
  (`CASM_TOKEN_IDENTIFIER`) — `MEASURE` calls `symbolsInsert`, `EMIT` does
  nothing (a label has nothing left to do in Pass 2). Every other statement
  type (`MNEMONIC`/`DIRECTIVE`) was already fully pass-transparent.
- New imports added to `casm.s`: `symbolsInit`, `symbolsInsert`,
  `CasmLabelName`, `CasmLabelNameLen`, `sourceRewind`, `CasmPassMode`,
  `CasmPc` — all already exported by their owning modules from WP27/28.
- `tests/fixtures/casm/p1fwd1.ref.hex`, `p1back1.ref.hex`, `p1size1.ref.hex`
  (new): hand-derived real-emission byte sequences for WP28's already-
  hand-verified fixture sources, each self-validated against
  `scripts/hex_manifest_to_bin.py`'s byte-count/SHA-256 check before use.
  `p1back1` in particular is the regression case that would fail if
  `CASM_PARSER_STMT_FORCE_ABS` were ever derived incorrectly (a resolved,
  small-valued backward reference must still emit absolute-width, not
  shrink to zero-page).
- `CMakeLists.txt`: `p1fwd1`, `p1back1`, `p1size1` appended to
  `CASM_REF_NAMES`. No new `.seq` fixtures — WP28's existing
  `p1fwd1.seq`/`p1back1.seq`/`p1size1.seq`/`p1undef1.seq` are reused
  directly as both WP29's byte-emission trusted-reference source and its
  undefined-symbol failure fixture.
- `brain/plans/2026-07-16-casm-assembler-implementation-plan.md` and
  `src/external/casm/AGENTS.md`: corrected the stale "Pass 2 emits
  structured emission events" text to describe the frozen single-
  `CasmPassMode`-flag design, cross-referencing WP26's plan.

## Bug Found During Implementation (Before Any Test Run)

**ca65 branch-range error, three sites.** The first draft of the two-pass
`start` kept the original `startInitFatal` trampoline in its old position
(right before the dispatch loop) and used direct `bcs startFatal` branches
from the new Pass 1/Pass 2 body to the unmodified `startFatal` tail, which now
sat past the entire new `casmRunPass` routine. `ca65` rejected the build
immediately:

```text
casm.s:81: Error: Range error (129 not in [-128..127])
casm.s:127: Error: Range error (136 not in [-128..127])
casm.s:134: Error: Range error (131 not in [-128..127])
```

Fixed with two near trampolines rather than widening one: `startInitFatal`
stayed immediately after the init-only checks it serves (everything through
the initial `lexerInit`, before Pass 1 begins), and a new `startFatalNear`
was placed immediately after the Pass 1/Pass 2 body (right before
`casmRunPass`), serving every failure branch inside that body. Both are a
plain `jmp startFatal`, which has no range limit. Rebuilding after the fix
assembled clean on the first try. This is the same class of fix `source.s`'s
WP15 comment and WP28's `p1size1` cleanup already document for this codebase.

## Static Verification

- All modules assemble with zero ca65 warnings/errors after the trampoline
  fix.
- MAIN measured directly via `ld65 -m` (a manual re-link against the
  already-built `.cfg`/`.o` files, since the CMake build path has no map-file
  output step): `CODE 0x2070` (8304) + `RODATA 0x090C` (2316) +
  `BSS 0x05ED` (1517) = 12137 of 12288 bytes — **151 bytes headroom, no MAIN
  size increase needed** (down from WP28's 233-byte headroom; the ~82-byte
  growth is `casmRunPass` plus the new imports, matching the "modest, no new
  module" prediction).
- All three new `.ref.hex` manifests self-validated against
  `hex_manifest_to_bin.py` (byte count and SHA-256 both checked) before being
  wired into the build.
- A no-change rebuild of `casm` alone held `BUILD_CASM` at 1125 (pre-version-
  bump) and then at 1126 (post-bump) across repeated builds.
- Both `image_d64` and `test_image_d64` build clean with the three new
  reference PRGs packaged onto `test.d64` alongside every existing CASM
  fixture and reference.

## Runtime Verification

The user ran the full matrix from `build/test.d64` and `build/image.d64` in
VICE:

| Fixture | Command | Expected | Result |
| --- | --- | --- | --- |
| Regression | `CASM CASMEMIT1.S` -> `COMP CASMEMIT1.PRG CASMEMIT1.REF` | identical | pass |
| Regression | `CASM CASMHELLO.S` -> `COMP CASMHELLO.PRG CASMHELLO.REF` | identical | pass |
| Regression | `CASM CASMMODES.S` -> `COMP CASMMODES.PRG CASMMODES.REF` | identical | pass |
| Regression | `CASM CASMNUM2.S` -> `COMP CASMNUM2.PRG CASMNUM2.REF` | identical | pass |
| Regression | `CASM CASMEXPRN.S` -> `COMP CASMEXPRN.PRG CASMEXPRN.REF` | identical | pass |
| New (forward ref) | `CASM P1FWD1.S` -> `COMP P1FWD1.PRG P1FWD1.REF` | identical | pass |
| New (backward ref, forced-abs regression) | `CASM P1BACK1.S` -> `COMP P1BACK1.PRG P1BACK1.REF` | identical | pass |
| New (comprehensive mix) | `CASM P1SIZE1.S` -> `COMP P1SIZE1.PRG P1SIZE1.REF` | identical | pass |
| Undefined symbol | `CASM P1UNDEF1.S` | prints `CASM: UNDEFINED SYMBOL`, no `P1UNDEF1.PRG` left on disk | pass |

The user confirmed: "All tests pass."

## Phase 6B Acceptance (partial — through WP29's own scope)

Closed out in `wiki/tasks/casm.md`:

- [x] Pass 1 assigns addresses and definitions without emitting output
      (carried forward from WP28, re-confirmed by this WP's regression run).
- [x] Pass 2 resolves symbols and emits final output.
- [x] Static programs with forward and backward references match trusted
      reference binaries byte-for-byte.
- [ ] Symbol table duplicate, undefined, case-sensitive, and max-length
      behavior match the frozen contract (full matrix remains WP31).
- [ ] Relative branches are computed from resolved symbols (range-check
      verification remains WP30, though the underlying computation already
      works unmodified per Dependency Review item 3 above).
- [ ] A Pass 1/Pass 2 disagreement is treated as fatal (WP30).

## DOX Closeout

Root, `src`, `src/external`, `src/external/casm`, `tests` contracts
rechecked. `brain/KNOWLEDGE.md` amended with a new Phase 0C.7 section
(rather than rewriting Phase 0C.5/0C.6 in place), recording the `casmRunPass`
design, the branch-range fix, the fixture-reuse decision, the relative-branch
finding, and the MAIN measurement. The master plan
(`brain/plans/2026-07-16-casm-assembler-implementation-plan.md`) and
`src/external/casm/AGENTS.md` were corrected in place (Dependency Review
item 2) rather than left stale.

## Completion Dry-Run and Final Increment (`0.1.30` -> `0.1.31`)

| Measurement | Value |
| --- | --- |
| Baseline | `0.1.30` build 1123 |
| Applied version | `0.1.31` |
| Build number | 1126 (incremented exactly once, from 1125 after the implementation-time builds) |
| No-change rebuild | pass, held at 1126 |
| `image_d64` | pass |
| `test_image_d64` | pass |

## Approval

The user confirmed the full VICE verification matrix ("All tests pass").

WP29 is complete. Taskwarrior (`8e989bdf`), `wiki/tasks/casm.md`, and
`brain/task.md` are marked done. Taskwarrior WP30 (`a9a117d2`) is unblocked
but not yet planned in detail — it requires its own dedicated plan and
approval before any relative-branch or disagreement-detection source is
written, per the CASM `AGENTS.md` gate. The CASM Phase 6B milestone remains
open.
