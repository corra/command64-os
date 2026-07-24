---
feature: casm-phase7-wp33-vmm-backed-source-load
created: 2026-07-24
status: complete
---

# Walkthrough: CASM Phase 7 WP33 VMM-Backed Source Load and Traversal Equivalence

Plan: `brain/plans/2026-07-24-casm-phase7-wp33-vmm-backed-source-load.md`

Taskwarrior: `25e69c58-b1cf-4c43-8aa9-5ae79b015375` (WP33); part of the CASM
Phase 7 milestone `1a0d0dc8-3267-4885-aa83-adf923d56422`.

## Outcome

WP33 implemented Contract items 1-3 of the Phase 0C.10 freeze: a new
`sourceLoad` pre-pass that streams the (still single) input file into one
VMM allocation before Pass 1 begins, a VMM-backed `sourceRefill` that fills
`CasmIoBuffer` through chunked 64-byte `vmmWindowRead` transfers instead of
a direct OS read, and simplified `sourceOpen`/`sourceRewind`/`sourceClose`
that now perform no OS call at all -- both reduce to a pure traversal-cursor
reset over content `sourceLoad` already loaded. `sourceFetchPhysical` and
every byte-classification/newline-normalization routine needed zero
changes, confirmed by tracing that they only ever consult the block
index/length window into `CasmIoBuffer` and a checked delivered-byte
offset, both meaningful identically regardless of where the buffer's
contents came from.

Per the user's confirmed scoping decision, WP33 stayed single-file only:
`sourceLoad` opens exactly `CasmSourceName`, with no `CasmSourceNames`
array or `CasmSourceFileTable` yet -- deferred to WP34, since no WP33
fixture could exercise a multi-file loop with only one input ever
available.

Two real defects were found through user runtime testing and fixed, in
line with the WP25/WP30 precedent that a genuinely new fixture category
can surface a latent defect rather than just prove new code correct -- this
is now the third time (WP25, WP30, WP33).

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase7-wp33` |
| Branch point | `main` at `ab7445b` |
| Baseline version | `0.1.34` build 1132 |
| Plan approval | Approved as drafted, including the confirmed single-file-only scoping decision |

## Implementation

- `common.inc`: `CASM_SOURCE_VMM_MAX_BYTES = 65535` (the true single
  `vmmStoreAlloc` request ceiling -- 65536 cannot be represented in a
  16-bit count).
- `source.s`: new `sourceLoad`; rewritten `sourceOpen`, `sourceRewind`,
  `sourceClose`, `sourceRefill`; a new `.segment "BSS"` block
  (`CasmSourceVmmSlot`, `CasmSourceLoadedLenLo/Hi`,
  `CasmSourceVmmCursorLo/Hi`) kept separate from `state.s`'s frozen Phase 3
  subrecords, mirroring WP28's `CasmLabelName` precedent.
- `casm.s`: `jsr sourceLoad` inserted immediately before the existing
  `jsr sourceOpen` call.
- `tests/src/casm_pass1/casm_pass1.s`: the same `sourceLoad` call added
  before both of its own `sourceOpen` call sites, plus a `resourcesCleanup`
  call after each fixture (see Defect 2 below).
- `cmake/GenerateCasmTestFixtures.cmake` / `CMakeLists.txt`: two new
  fixtures, `casmvmm65.seq` (65 bytes: one full 64-byte VMM chunk plus a
  1-byte partial) and `casmvmm128.seq` (128 bytes: exactly two full
  64-byte chunks, no partial), targeting the new internal chunk boundary
  `casm256` (always four full chunks) never exercised.
- `CMakeLists.txt`: MAIN bumped `$3000` -> `$3200` for `casm` (a 236-byte
  overflow at the old size), and `$3200` -> `$3300` for the
  `casm_pass1`/`casm_passcheck` standalone harnesses (both link `source.s`
  whole, so the larger module grew their own envelopes too).

## Defects Found and Fixed

### 1. `sourceRefill`'s VMM-read copy omitted `CasmIoBuffer`'s low byte

`CasmIoBuffer` links at `$5FDA` -- not page-aligned (`<CasmIoBuffer = $DA`).
The buggy pointer computation in `srReadChunkStage` added only
`#>CasmIoBuffer` (the page) to `base + chunkDestOffset`, never
`#<CasmIoBuffer` (the byte offset within that page):

```asm
lda CasmLexerScratch0
clc
adc CasmLexerScratch1   ; base + chunk-dest-offset only
sta CasmIoPtrLo          ; missing: + <CasmIoBuffer
lda #>CasmIoBuffer
adc #0
sta CasmIoPtrHi
```

Every VMM-backed refill therefore wrote its chunk 218 bytes before the real
buffer, corrupting whatever BSS state happened to sit there -- producing
two seemingly unrelated symptoms depending on which fixture's chunk
offsets hit which cell:

- `casmemit1.s`: `CASM: OUTPUT WRITE FAILED` at line 9 col 14, plus a real
  Commodore drive-level `32, SYNTAX ERROR` status (consistent with a
  corrupted output filename reaching `DOS_OPEN_FILE`).
- `casmhello.s`: `CASM: DUPLICATE ORG` at line 1 col 1 (consistent with
  `CasmOrgSet`, an `emit.s` BSS cell, getting clobbered).

Same defect, different collateral damage per file -- not two separate
bugs. `sourceLoad`'s write-side counterpart (`slWriteChunkStage`) already
had the correct three-term form, which is what made the asymmetry easy to
spot once the two were compared directly.

**Fix**: add the missing term as its own correctly-carried addition:

```asm
lda CasmLexerScratch0
clc
adc CasmLexerScratch1
clc
adc #<CasmIoBuffer
sta CasmIoPtrLo
lda #>CasmIoBuffer
adc #0
sta CasmIoPtrHi
```

The intermediate `clc` matters: `base + chunkDestOffset` alone never
carries (proven bounded to <= 255 by construction), but chaining the
`<CasmIoBuffer` add directly onto that stale carry state without a fresh
`clc` would still compute the wrong result for cases where the first add's
carry flag happened to be set from something else.

### 2. `test_casm_pass1` exhausted the VMM registry

The harness calls `symbolsInit` and now also `sourceLoad` once per fixture
across 7 fixtures in one continuous process, with no explicit cleanup
between them -- by design, pre-WP33 ("7 calls total, one per fixture, well
within `CASM_VMM_CAPACITY == 8`"). WP33 doubled that to 14 allocations
needed against 8 registry slots: the registry filled exactly after 4
fixtures (`....`) and the remaining three (`p1undef1`, `p1dup1`,
`p1size1`) failed with the registry already full (`fff`).

**Fix**: `casm_pass1.s`'s main loop now calls `resourcesCleanup` after each
fixture's `reportCase`, freeing both that fixture's symbol-table and
source VMM slots before the next fixture allocates its own. Steady-state
usage is at most 2 slots at a time, not 14 accumulated. Test-harness-only
fix -- production `casm.s` calls `sourceLoad` exactly once per run and
already relies on the existing generic `resourcesCleanup` sweep at
`exitSuccess`/`exitFatal`, unaffected.

## Static Verification

- `casm` build 1136 (post-fix-1) -> 1137 (version-only completion
  increment), no-change rebuild stable at each step.
- `image_d64` and `test_image_d64` both build clean throughout.
- MAIN measured via `ld65 -m`: CODE `$21EF` (8687) + RODATA `$090C` (2316)
  + BSS `$5F4` (1524) = 12527 of 12800 bytes -- 273 bytes headroom.
- `casmvmm65.seq`/`casmvmm128.seq` self-verified at exactly 65/128 bytes
  via `wc -c` before wiring into the build.

## Runtime Verification

The user ran the full verification matrix across two sessions (before and
after the two fixes above):

**Standalone harnesses:**

| Harness | Result |
| --- | --- |
| `TEST_CASM_PASS1` | pass, all 7 sub-fixtures (`.......`) |
| `TEST_CASM_PASSCHECK` | pass |

**Byte-identical trusted references** (`CASM` + `COMP` each):

| Reference | Result |
| --- | --- |
| `casmemit1` / `casmhello` (the two that failed pre-fix) | identical |
| `casmmodes` / `casmnum2` / `casmexprn` | identical |
| `p1fwd1` / `p1back1` / `p1size1` | identical |
| `brfwd1` / `brback1` | identical |
| `casmcase1` / `casmmaxid1` | identical |

**Phase 3 traversal fixtures** (first real run through two-pass `casm.s`,
confirmed against hand-derived expected results, not a regression
re-confirmation):

| Fixture | Result |
| --- | --- |
| `casmempty` (`CANNOT OPEN INPUT`) | pass |
| `casmshort` (`UNDEFINED SYMBOL`, no output survives) | pass |
| `casm256` (`TOKEN TOO LONG` at line 1, col 32) | pass |
| `casmmulti` (same) | pass |
| `casmcr` (`SYNTAX ERROR AT LINE 1, COL 6`) | pass |
| `casmcrlf` (same location as `casmcr`) | pass |
| `casmsplit` (`TOKEN TOO LONG`, masking its own CRLF-split intent) | pass |

**New 64-byte VMM chunk-boundary fixtures:**

| Fixture | Result |
| --- | --- |
| `casmvmm65` (`TOKEN TOO LONG` at line 1, col 32) | pass |
| `casmvmm128` (same) | pass |

The user confirmed: "tests pass."

## Documentation and DOX Closeout

- `brain/KNOWLEDGE.md`: Phase 0C.11 as-built section added, amending Phase
  0C.10 with the exact implemented shape and both defects.
- `wiki/tasks/casm.md`: WP33 checked complete under CASM Phase 7 Work
  Packages.
- `brain/task.md`: WP33 entry added and closed.
- `CHANGELOG.md`: Unreleased entry added.
- Taskwarrior: WP33 (`25e69c58-b1cf-4c43-8aa9-5ae79b015375`) completed.

## Completion

**CASM Phase 7 WP33 is complete**, per the completion gate in
`brain/plans/2026-07-24-casm-phase7-wp33-vmm-backed-source-load.md`: the
full verification matrix passed, the old direct-disk refill path is fully
removed (not left dead), MAIN headroom is measured and justified, a
no-change rebuild holds `BUILD_CASM` stable, both images build clean, and
the user confirmed the runtime results. WP34 (multi-file CLI and
file-boundary provenance) remains separately gated and unstarted per
`AGENTS.md`.
