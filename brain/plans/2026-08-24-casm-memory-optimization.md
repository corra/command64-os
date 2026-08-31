---
feature: casm-memory-optimization
created: 2026-08-24
status: approved
taskwarrior: 42 (33d69dd5-c96b-4d3a-a27c-9fd93cc31de3), approved 2026-08-31
depends-on: CASM progress-indication feature (task 33) closed through Increment 11
---

# Plan: CASM Memory Optimization

## Status

**Approved 2026-08-31** (Taskwarrior 42,
`33d69dd5-c96b-4d3a-a27c-9fd93cc31de3`, `depends:33`). Drafted 2026-08-24
from a measured audit, per this project's per-work-package-plan-approval
requirement (`.agents/workflows/phased-implementation-planning.md`).
Implementation remains blocked until the prerequisite lands: the
progress-indication feature (Taskwarrior 33) must close through its
Increment 11 (Increments 8-11 still open as of approval).

Prerequisite: the CASM progress-indication feature (Taskwarrior 33) closed
through Increment 11. This WP is deliberately sequenced last (Scoping
Decision 1).

Supersedes the earlier draft scoped to `diagnostics.s` alone; a follow-up
audit found two further targets, one of them larger than any single
diagnostics finding.

## Objective

Recover roughly 2 KB of CASM's MAIN envelope across five independent
findings, without changing a single byte of user-visible behavior:
no change to diagnostic text or identifiers, no change to accepted
filenames, no change to assembled output, no change to progress display.

This WP adds **no** new behavior. It is a pure size optimization with a
strict "identical observable behavior" contract.

**Explicitly excluded:** any change to `CasmDiagLineBufA`/`B` sizing
(Finding F below -- a product tradeoff, not an optimization), any envelope
shrink (Scoping Decision 4), and any change to the include catalog's
VMM-resident record format beyond what Finding D requires.

## Audit Basis (measured 2026-08-24)

All `diagnostics.s` figures were produced by real `ca65`/`ld65` assembly
and links against CASM's actual object set, re-measured in one controlled
batch after an earlier round of one-off links proved inconsistent.
Findings D and E are exact `.res` arithmetic and macro-expansion counts
respectively -- their *sizes* are certain; only D's *safe cap value* is
open (Increment 2).

Program total: 28,929 bytes. `diagnostics.o` is the largest module at
4,774 (17%), and its RODATA alone is 83% of all RODATA in CASM.

| Finding | Module(s) | Change | Saving |
| --- | --- | --- | --- |
| **D** | `cli.s`, `parser.s`, `include.s` | 13 filename buffers are 64 bytes each (832 total) off a self-imposed `*_FILENAME_MAX = 63`; real reachable names are far shorter | **~520** |
| **B** | `diagnostics.s` | `"CASM: "` repeated across all 89 messages (534 B) plus a trailing `PetCr` across 88 of them (88 B); both factor into one shared helper | **587** measured |
| **A** | `diagnostics.s` | `diagDumpToken` is exported but called by **no** production module; `ld65` links whole objects, so it and its token-name tables ship in every `casm.prg` | **509** measured |
| **C** | `diagnostics.s` | `diagPrintFatal` repeats one 20-byte table-lookup idiom 6 times plus a 9-way `cmp`/`beq` chain; one dense table replaces all of it | **231** measured |
| **E** | `progress.s` | `PROG_DIGIT` is a macro expanded **6 times** inline (~33 B each); a divisor-table loop replaces it | **~150** |
| | | **Combined** | **~2,000** |

A+B+C measured together: **1,327 bytes**, verified additive, taking
`__MAIN_LAST__` `$A901` -> `$A3D2` and headroom `767 -> 2,094` at the
current `$7400` budget. With D and E, CASM would fit its **original
`$6C00`** budget with roughly 750 bytes to spare -- meaning both envelope
growths approved during progress Increments 3 and 5 were paying for waste,
not for the feature.

Two facts that make C cheaper and safer than first estimated, both
discovered during the audit rather than assumed:

- The existing six message tables are already **dense and contiguous**
  across `$01..$56` -- exactly 86 entries, no gaps. A unified table costs
  only +18 RODATA bytes.
- The locationless diagnostics are exactly the contiguous run `$3D..$43`
  (five listing-file errors, `SYMBOL MAP INVALID`, `CIRCULAR CONSTANT
  DEFINITION`). Two compares replace what was budgeted as an 11-byte
  bitmap. **This is a latent property nobody designed for and it is
  fragile** -- see Increment 8's guard requirement.

**Finding F, recorded but NOT actioned:** `CasmDiagLineBufA`/`B`
(`state.s`) are 512 bytes -- tied with `CasmSourceNames` as the largest
structure in CASM. The full 256-byte capture is justified (the caret can
land anywhere and the display window slides afterward). Dropping the `B`
previous-line buffer would recover 256 bytes but degrades diagnostic
quality. That is a product decision, deliberately out of scope.

## Increment 1 Re-baseline (measured 2026-08-31, branch `feature/casm-memory-optimization` off `main` `f4227cf`)

CASM `V0.5.0` build 1380. Prerequisite met: progress-indication (task 33)
merged to `main` 2026-08-31 through Increment 11.

**Whole-program (real `ca65`/`ld65`, base cfg `$3800`, MAIN size `$7400`):**

| Metric | 2026-08-24 audit | 2026-08-31 re-baseline |
| --- | --- | --- |
| `casm.prg` (relocatable) | -- | **33,398 bytes** (sha256 `e8a6731f…`) |
| CODE segment | -- | `$3800..$8BE6` = `$53E7` (21,479) |
| RODATA segment | -- | `$8BE7..$9AE5` = `$0EFF` (3,839) |
| BSS segment | -- | `$9AE6..$A97D` = `$0E98` (3,736) |
| `__MAIN_LAST__` | `$A901` (at `$7400`) | **`$A97D`** |
| MAIN headroom at `$7400` | 767 | **642** (matches task 33's Increment 11 figure) |
| `diagnostics.o` (CODE+RODATA+BSS) | 4,774 | **4,779** (CODE `$650`, RODATA `$C59`, BSS 2) |
| `progress.o` (CODE+BSS) | -- | CODE `$409` (1,033), BSS `$1C` (28) |

Baseline artifact hashes and the full diagnostic-message dump are captured
in the scratchpad (`casm_baseline.map`, `casm_baseline.prg`,
`casm_diag_messages_baseline.txt`) for Increment 10's byte-identity check.

**Diagnostic ID map:** still **dense and contiguous `$01..$56`** (86 IDs)
plus `$FF` UNKNOWN -- Finding C's density precondition holds. Phases 12/13
and progress added `$44..$56` since the audit.

**Findings still valid as written:**

- **D** -- `CASM_FILENAME_MAX = 63` / `CASM_INCLUDE_FILENAME_MAX = 63`
  unchanged; all 13 buffers present. Note two *new* dependent asserts since
  the audit (`common.inc:1457`, `:1466`) size listing open/resolved-name
  buffers off `CASM_FILENAME_MAX + 3` / `CASM_INCLUDE_FILENAME_MAX` -- these
  must be updated in Increment 3 alongside the constants' own guards.
- **A** -- `diagDumpToken` still has **zero** production callers (grep of
  `src/external/casm/` outside `diagnostics.s`).
- **B** -- `"CASM: "` prefix + trailing `PetCr` pattern intact across the
  message tables.
- **E** -- `PROG_DIGIT` is now expanded **5 times** (`10000/1000/100/10/1`),
  not 6 as the audit stated; the `@narrow` path (width 2) shares the last
  two. Saving estimate revises down slightly (~100 B gross, table + loop
  overhead nets less) but the finding stands.

**Finding C -- dispatch structure has drifted materially and Increments 7-8
need re-scoping before implementation.** The audit described "six range
blocks plus a 9-way `cmp`/`beq` chain". `diagPrintFatal` now dispatches
through **seven** parallel message tables, each with its own range test:
`dpfMainRange` (`$01..$3C`), `dpfListingRange` (`$3D..$41`),
`diagWp81MessageLo/Hi` (`$4B..$4E`), `diagWp82MessageLo/Hi` (`$4F..$51`),
`diagWp83MessageLo/Hi` (`$52..$54`, with a `CASM_DIAG_ASSERTION_FAILED`
user-message echo special case), `diagProgressMessageLo/Hi` (`$55..$56`),
plus the `cmp`/`beq` chain in `dpfSymbolRange` which is now **9-way**
(`$42,$43,$44,$45,$46,$47,$48,$49,$4A`). The 231-byte saving predates
roughly 400-600 bytes of new Phase 13 / progress dispatch code that a
unified table would also subsume, so the achievable saving is likely
*larger* now -- but the increment text, the "six former dispatch ranges"
verification matrix (Increments 7 and 9), and the fault-injection plan all
reference a structure that no longer exists.

The two Finding C **hard preconditions still hold**: the ID range is dense,
and the set of dispatch paths that skip `diagPrintSourceContext` entirely
is still exactly `$3D..$43` (the listing table + `dpfSymbolMapInvalid` +
`dpfExprCircular`). The `$55..$56` progress diagnostics are *semantically*
locationless but are coded through the self-gating context call, so they do
not widen the skip set. No Stop Condition is tripped -- but Finding C's
implementation approach should be re-planned against the current
`diagnostics.s` before Increment 8, and Increments 7/9's matrices updated
to the seven-table reality.

## Increment 2 Finding D Research (executed 2026-08-31)

**Result: Finding D proceeds. Cap = 32 for both `CASM_FILENAME_MAX` and
`CASM_INCLUDE_FILENAME_MAX`. User-approved 2026-08-31, knowingly accepting a
narrow diagnostic-text change (see below).**

### True reachable maximum

Command64's filesystem is CBM DOS end to end -- there is **no long-name
path**. Confirmed by reading:

- `src/command64/path.asm` `findFile`/`checkExistence`: name goes straight
  to `KernalSETNAM` + `KernalOPEN`; matching is whatever the 1541 does (16
  significant characters).
- `src/command64/file.asm` `fileOpen`: `parsePointerDevice` strips a
  `8:`..`11:` prefix, then the remainder is copied null-terminated into
  `FileScratch` (`$1FA2..$1FFB`, 90 bytes) with **no length cap**, `,T,W`
  (4 bytes) appended for write mode, then `SETNAM`. The only hard ceiling
  the OS imposes is the 90-byte `FileScratch` overrun into `SysDate`.
- `src/command64/apptable.asm:309,753`: app-name fields are `max 16 chars`.

So the longest filename that can **actually resolve to a file on disk**:

| Component | Bytes |
| --- | --- |
| CBM DOS directory entry (hard limit) | 16 |
| Device prefix `8:`..`11:` (stored verbatim in CASM's buffers; the OS strips it) | +3 |
| Synthetic `.PRG` / `.LST` extension appended by `cliDeriveOutputName` / `cliDeriveListingName` | +4 |
| **Worst realistic case in a CASM buffer** | **23** |

`.INCLUDE` / `.INCBIN` operands are user source text but must resolve to a
real file, so the same 16 (+prefix) ceiling applies; longer operands are
accepted into the buffer today and simply never open.

### The behavior-contract tension and the decision

`cliCopySource` / `cliParseOutput` (`cli.s:229,344`) and `lnString`
(`lexer.s:434,612`) reject a filename token only at
`CASM_FILENAME_MAX` / `CASM_INCLUDE_FILENAME_MAX` = 63, raising
`FILENAME_TOO_LONG`. Names of 24..63 chars are **accepted today** and fail
later (`CANNOT OPEN INPUT`, `CANNOT CREATE OUTPUT`, include-not-found).

Lowering the cap to 32 moves that rejection boundary: inputs of 33..63
chars now raise `CASM: FILENAME TOO LONG` at parse time instead of their
current downstream diagnostic. **The outcome is identical** (assembly
fails, no output artifact) and no name that can resolve to a real file is
affected -- only the diagnostic *text* differs, and only for names that
could never have opened. This does trip the plan's stop condition as
literally worded; the user reviewed it and **approved cap = 32**
(9 bytes margin over the proven 23) on 2026-08-31.

### Buffers affected -- larger than the 2026-08-24 audit tallied

The audit's Finding-D table listed 13 buffers / 832 bytes. Re-grep found
more MAIN-resident BSS keyed off these two caps:

| Symbol | File | Current | At cap 32 |
| --- | --- | --- | --- |
| `CasmSourceNames` (8 x `FILENAME_BUFFER_SIZE`) | `cli.s:41` | 512 | 264 |
| `CasmOutputName`, `CasmListingName` | `cli.s:44,46` | 128 | 66 |
| `CasmIncludeFilename` (+len), `CasmIncbinFilename` (+len) | `parser.s:144,155` | 128 | 66 |
| `CasmIncludeKeyName` | `include.s:100` | 64 | 33 |
| `CASM_LISTING_OPEN_NAME_SIZE` | `common.inc:1456` | 68 | ~36 |
| `CASM_LISTING_RESOLVED_NAME_SIZE` | `common.inc:1465` | 68 | ~36 |
| `CASM_INCLUDE_OPEN_NAME_BUFFER_SIZE` | `common.inc:~373` | `>= 68` | `>= ~37` |
| **Approx. MAIN total** | | **~1,090** | **~540** |

Projected saving **~550 bytes**, in line with the audit's ~520.

### Constraints Increment 3 must honor

- `.assert`s to update (not drop): `common.inc:234` (`= 64`),
  `common.inc:235` (`= 64`), `common.inc:307`, `common.inc:376`,
  `common.inc:1457`, `common.inc:1466`, `common.inc:1467`;
  `parser.s:148,149,159,160` (the "exactly 65 bytes" include/incbin state
  asserts).
- `cliDeriveOutputName` / `cliDeriveListingName` use `CASM_FILENAME_MAX - 2`
  / `- 3` as the extension-write ceiling -- these keep working at 32
  (32 - 3 = 29 >= the 23 worst case + the 4-char extension still fits the
  33-byte buffer: 23 + 4 + null = 28 <= 33). Verify the exact `cpx`
  comparisons still admit every derivable name <= the proven max.
- **Include VMM physical record** (`CASM_INCLUDE_PHYS_REC_NAME` = offset 8,
  `CASM_INCLUDE_PHYS_REC_SIZE` = 128, REU-resident, **zero MAIN cost**):
  leave the 128-byte record alone. Increment 3 must check whether
  `includeCatalog*` writes/reads the name field with a hardcoded 64 or with
  `CASM_INCLUDE_FILENAME_BUFFER_SIZE`; if the latter, the on-REU name
  reservation simply shrinks with the constant and the 2 x 64-byte window
  transfer is unaffected (record stays 128). If a hardcoded 64 is found,
  keep it -- do **not** widen the MAIN buffer back to match.
- At-cap (exactly 32) and over-cap (33) fixtures for: a command-line source
  name, an `/O` name, an `.INCLUDE` operand, an `.INCBIN` operand.

## Increment 3 Finding D Implementation (executed 2026-08-31)

**Done. Net MAIN saving 482 bytes (487 BSS recovered, 5 spent on a
corrected clear loop). Full build clean, every constant `.assert` across
all 31 harnesses passed.**

### Source changes

| File | Change |
| --- | --- |
| `common.inc` | `CASM_FILENAME_MAX` 63 -> 32, `CASM_INCLUDE_FILENAME_MAX` 63 -> 32 (both `*_BUFFER_SIZE` track to 33). Added `.assert *_MAX = 32` pinning each new value with a comment pointing at the reachable-max evidence. `CASM_INCLUDE_OPEN_NAME_BUFFER_SIZE` 68 -> 40, `CASM_LISTING_OPEN_NAME_SIZE` `$44` -> 40, `CASM_LISTING_RESOLVED_NAME_SIZE` `$44` -> 40; their `>=` asserts re-checked (all still satisfied). Existing `= 64` layout asserts updated to `= 33`. |
| `common.inc` | `CASM_INCLUDE_PHYS_REC_SIZE` **left at 128** (REU-resident, zero MAIN, and the two 64-byte window transfers depend on it); comment reworded to say the name slot now spans `8 .. 8+BUFFER_SIZE-1` and that this size is deliberately not reduced. The `PHYS_REC_NAME + BUFFER_SIZE <= PHYS_REC_SIZE` assert still holds (`8 + 33 = 41 <= 128`). |
| `cli.s` | **Bug fix.** `cliInit`'s `ciClearNames` cleared a fixed 512 bytes via a wrapping two-store loop; `CasmSourceNames` is now `8 * 33 = 264`, so the old loop ran 248 bytes off the end into `CasmOutputName` and the BSS beyond. Replaced with one wrapping 256-byte pass + a `(TOTAL - 256)`-byte tail, guarded by two new `.assert`s pinning `256 < TOTAL <= 512`. |
| `parser.s` | Two `.assert` message strings de-hardcoded ("exactly 65 bytes" -> "exactly CASM_INCLUDE_FILENAME_BUFFER_SIZE + 1 bytes"). |
| `progress.s` | Stale comment `CASM_FILENAME_MAX is 63` -> `32`. |

`includeCaptureKey`, `includeCatalog` read/compare/write, `cliCopySource`,
`cliParseOutput`, `cliDeriveOutputName`/`ListingName`, `lnString` (both
`.INCLUDE` and `.INCBIN` paths), `source.s`/`listing.s` slot reads, and
`casm.s`'s frame-name reconstruction were all read and confirmed to bound
by the constants (or by a caller-supplied length / null terminator that
can't exceed them) -- no code logic change needed beyond the `cliInit`
fix. `casm.s:1124 cpy #64` is `CrcBitmap` (512-symbol / 8), unrelated.

### Fixture changes

| Harness | Change |
| --- | --- |
| `tests/src/casm_cliderive/casm_cliderive.s` | `cderoverflow1` 60 -> 29-byte name (one past `CASM_FILENAME_MAX - 3`), `cderboundary1` 59 -> 28-byte name (produces a 32-byte = `CASM_FILENAME_MAX` listing name that fits exactly). Both were poking >33-byte names into the now-33-byte `CasmOutputName`/`CasmListingName` and would have overrun. |
| `tests/src/casm_include/casm_include.s` | `valid63` (63 A's, expect OK) -> `validCap` (32 A's); `tooLong` 64 -> 33 A's; `expected63` -> `expectedCap`; `CASE` metadata (`scriptBytes` 75->44 / 76->45, `column` 74->43) updated. These pin the new at-cap / over-cap `.INCLUDE` boundary at the lexer level. |

`.INCLUDE`/`.INCBIN` names that must actually *resolve* to a real file at
the new cap are proven by Increment 9's live VICE run (they need real disk
files); the host-side fixtures cover the CLI and lexer rejection paths.

### Measurement

| | Increment 1 baseline | Increment 3 |
| --- | --- | --- |
| BSS segment | `$0E98` (3,736) | `$0CB1` (3,249) |
| CODE segment | `$53E7` | `$53EC` (+5, clear-loop tail) |
| `__MAIN_LAST__` | `$A97D` | `$A79B` |
| MAIN headroom at `$7400` | 642 | **1,124** |

CASM build auto-bumped 1380 -> 1381; `TEST_CASM_INCLUDE` -> 1039;
`TEST_CASM_CLIDERIVE` -> 1017.

## Increment 4 Finding E (executed 2026-08-31)

**Done. progress.o CODE -108 bytes. Output proven byte-for-byte identical
to the old macro across all 65,536 values x both field widths.**

`progressPrintDec`'s five inline `PROG_DIGIT` macro expansions
(`10000/1000/100/10/1`, ~34 bytes each) replaced with a divisor-table loop
over the same five 16-bit constants in `progress.s`. Equivalence points:

- Same repeated-16-bit-subtraction digit extraction, same `digit + '0'`
  emission via `progressPrintChar`.
- Same fixed 2-or-5-digit width selection (`cpy #5`). The 2-digit case
  previously fell through a shared label into the last two macro
  expansions; the loop instead starts at table index 3, which visits
  exactly those same two divisors (`10`, `1`).
- No new zero-page or BSS scratch: the tentative low byte rides the stack
  across the 16-bit borrow test, and X (the divisor index) is stack-saved
  across `progressPrintChar` (which clobbers it). ABI unchanged --
  `A`/`X` = value lo/hi, `Y` = width in; `A`/`X`/`Y` clobbered out.

**Verification:** a host-side model of both the old `PROG_DIGIT` semantics
and the new loop (`scratchpad/progdec_equiv.py`) produced **0 mismatches**
over `v` in `0..65535` for width 2 and width 5. Full build + `test_casm_progress`
build clean (its assertions are state/carry/overrun only; it documents that
on-screen digit truth is verified live -- that lands in Increment 9/10).

### Measurement

| | Increment 3 | Increment 4 |
| --- | --- | --- |
| `progress.o` CODE | `$0409` (1,033) | `$039D` (925), -108 |
| CODE segment | `$53EC` | `$5380` |
| `__MAIN_LAST__` | `$A79B` | `$A72F` |
| MAIN headroom at `$7400` | 1,124 | **1,232** |

Cumulative D + E: headroom `642 -> 1,232` (**590 bytes** recovered).
CASM build 1381 -> 1382; `TEST_CASM_PROGRESS` -> 1013.

## Increment 5 Finding A (executed 2026-08-31)

**Done. 653 bytes recovered (251 CODE + 402 RODATA in `diagnostics.o`) --
more than the audit's 509 estimate, because the token-name tables grew
with the CHAR/STRING token types since 2026-08-24. Switch-on build
restores `diagnostics.o` to byte-identical pre-Finding-A size.**

### Mechanism (Scoping Decision 2 -- gate, don't delete)

- `common.inc` new "Build-time switches" block: `CASM_ENABLE_DIAG_DUMP_TOKEN`
  defaults to 0 via an `.ifndef` guard, so a `ca65 -D CASM_ENABLE_DIAG_DUMP_TOKEN=1`
  (or the CMake cache var) overrides it.
- `diagnostics.s`: `.if CASM_ENABLE_DIAG_DUMP_TOKEN` wraps (a) the
  `.export diagDumpToken`, (b) the `.import CasmTokenText` (used only here --
  `CasmTokenRecord` stays, it is also used by `diagSetLocFromToken`), (c) the
  `diagDumpToken` routine, (d) the RODATA token-name tables + strings
  (`tokNames*`, `dirSubtypeNames*`, `regSubtypeNames*`, `numSubtypeNames*`,
  the ~40 `tokName*`/`dirName*`/`regName*`/`numName*` strings, `msgUnknownTok`,
  `msgSubUnknown`, `msgMnem*`, `msgText*`, `msgLoc*Prefix`). `msgCR`
  immediately after the block is **outside** the `.if` -- it is shared by
  `diagPrintFatal` and the source-context/traceback printers.
- `cmake/Ca65.cmake`: `add_ca65_app` gains an `EXTRA_DEFINES` multi-value
  keyword (mirrors the existing `EXTRA_INCLUDE_DIRS`), threaded into every
  ca65 call as `-D` flags so a shared-`.inc` switch is consistent across the
  whole link.
- `CMakeLists.txt`: `option(CASM_ENABLE_DIAG_DUMP_TOKEN ... OFF)` at the
  casm call site, passed through `EXTRA_DEFINES`. Toggling it re-assembles
  CASM (the ca65 command line changes, so the generator rebuilds) but does
  not bump the build number.

### Verification

- Default build (`OFF`): full `cmake --build build` clean, all harnesses
  link. `diagnostics.o` CODE `$650 -> $555`, RODATA `$C59 -> $AC7`.
- `cmake -B build -D CASM_ENABLE_DIAG_DUMP_TOKEN=ON` then build: clean,
  `diagnostics.o` back to **exactly** `$650` / `$C59` (the Inc 1 baseline),
  whole-CODE back to `$5380` (= Inc 4, pre-Finding-A). `.import CasmTokenText`
  resolves against `lexer.s`. Reverted to `OFF`, rebuilt clean.
- Every `CASM:` diagnostic message string byte-identical to the Increment 1
  baseline dump (Finding A removed only token-*name* strings, never a
  diagnostic message).

### Measurement

| | Increment 4 | Increment 5 |
| --- | --- | --- |
| `diagnostics.o` CODE | `$0650` | `$0555` |
| `diagnostics.o` RODATA | `$0C59` | `$0AC7` |
| `__MAIN_LAST__` | `$A72F` | `$A4A2` |
| MAIN headroom at `$7400` | 1,232 | **1,885** |

Cumulative D + E + A: headroom `642 -> 1,885` (**1,243 bytes** recovered).
CASM build 1382 -> 1383.

## Increment 6 Finding B (executed 2026-08-31)

**Done. 585 bytes recovered (audit projected 587). Every diagnostic renders
byte-identically: 88/88 host-side text checks pass, `casm.s`/`map.s`
untouched.**

### Mechanism

- New `diagPrintMessage` entry point (not exported; internal to
  `diagnostics.s`): pushes the caller's X/Y, prints `msgCasmPrefix`
  (`"CASM: "`), restores X/Y and prints the body, then tail-calls
  `diagPrintString` for `msgCR`. No BSS -- the body pointer rides the stack
  across the prefix print. **`diagPrintString` is byte-for-byte unchanged**
  in contract and body.
- Every message string `msgInitFailed..msgPhase2Ready` stripped of its
  leading `"CASM: "` and its trailing `PetCr` (89 strings; the transform
  was a scoped 2-rule `perl -i` over the message-data line range only).
  `msgAssertionFailedPrefix` lost its `"CASM: "` too but keeps its
  no-CR form.
- 17 message-print call sites in `diagPrintFatal` / `diagPrintPhase2Ready`
  retargeted `diagPrintString` -> `diagPrintMessage` (11 table-driven +
  `dpfSymbolMapInvalid`, `dpfExprCircular`, `dpfUnknown`,
  `diagPrintPhase2Ready`, `dpfListingRange`, `dpfMainRange`). Audited each:
  the ~30 remaining `diagPrintString` calls (in `diagPrintLineAndCaret`,
  `diagPrintSourceContext`, `diagPrintIncludeIdentity`,
  `diagPrintIncludeTraceback`, and the gated `diagDumpToken`) all print
  non-message text -- filenames, source echo, carets, location lines,
  tracebacks -- and stay on `diagPrintString`.
- **Assert-echo special case** (`dpfWp83`, `CASM_DIAG_ASSERTION_FAILED`
  with a user message): cannot use `diagPrintMessage` -- the echoed user
  text sits between the message body and the CR. Restructured to print
  `msgCasmPrefix`, then `msgAssertionFailedPrefix` (`"ASSERTION FAILED: "`),
  then `CasmAssertMessage`, then `msgCR` -- rendering
  `CASM: ASSERTION FAILED: <user text>\r`, identical to before.
- `msgCrOnly` (a second `.byte PetCr,0`, only the assert path used it)
  removed; that path now shares `msgCR`.

### Verification

- Full `cmake --build build` clean; all harnesses link (`diagPrintMessage`
  is internal to `diagnostics.o`; the stub harnesses that don't link it
  never reference it).
- Host-side check: reconstruct each diagnostic's rendered form
  (`"CASM: "` + new body + CR) and compare against the Increment 1
  baseline dump -> **88 checked, 0 mismatches**. `msgPhase2Ready`
  (`CASM: INPUT VALIDATED`, success) and `msgUnknown`
  (`CASM: INTERNAL ERROR`, fallback) both confirmed routed through
  `diagPrintMessage`.
- `git diff --stat src/external/casm/casm.s src/external/casm/map.s` empty.

### Measurement

| | Increment 5 | Increment 6 |
| --- | --- | --- |
| `diagnostics.o` CODE | `$0555` | `$0575` (+32: the helper + assert-path prefix) |
| `diagnostics.o` RODATA | `$0AC7` | `$085E` (-617) |
| `__MAIN_LAST__` | `$A4A2` | `$A259` |
| MAIN headroom at `$7400` | 1,885 | **2,470** |

Cumulative D + E + A + B: headroom `642 -> 2,470` (**1,828 bytes**).
CASM build 1383 -> 1384.

## Increment 7 Host-side diagnostic-table verifier (executed 2026-08-31)

**Done. `scripts/verify_casm_diag_table.py` created, wired POST_BUILD on
the `casm` target. Passes against the unmodified dispatch (86 ids + 2
extras); catches both an internal `--self-test` corruption and a real
injected message edit.**

### What it does

1. Re-assembles `diagnostics.s` with `ca65 -g`, relinks it with the other
   `build/out_casm/*.o` at `$3800` with `ld65 -Ln` to get every local
   label's address.
2. Reads `casm.prg`, and for each diagnostic id walks `diagPrintFatal`'s
   dispatch exactly as the 6502 code does: the six parallel `.byte <msg`
   tables (`diagMessageLo`, `diagListMessageLo`, `diagWp81/82/83MessageLo`,
   `diagProgressMessageLo`), then the nine-entry `cmp`/`beq` chain
   (`$42..$4A`). Follows each pointer to its string.
3. Demasks every byte `& 0x7F` (the `ca65 -t c64` charmap sets bit 7 /
   swaps case -- the exact trap the audit's first verifier hit), renders
   `msgCasmPrefix` + body + `msgCR`, and compares to a **frozen `EXPECTED`
   dict** transcribed from the task-42 Increment 1 baseline and
   cross-checked against `docs/casm-utility.md`.
4. Also checks id coverage is exactly `$01..$56` and that `msgPhase2Ready`
   / `msgUnknown` (the two non-table entries that share the helper) match.

`decode_id_to_body()` is the one function Finding C rewrites: when the six
tables collapse to one dense table, it becomes a single loop over that
table and `BEQ_CHAIN` is deleted. The `EXPECTED` dict is the invariant and
does not change.

### Verification of the verifier

| Run | Result |
| --- | --- |
| Current (post-Finding-B) dispatch | `OK: all 86 diagnostic identifiers + 2 extras` |
| `--self-test` (appends `X` to one decoded body) | `FAIL 0x2A ...` then `self-test OK: corruption detected as expected` |
| Real edit: `msgOrgRequired` `"ORG REQUIRED"` -> `"ORG MISSING"`, rebuild | `FAIL 0x21: 'CASM: ORG MISSING\r' != 'CASM: ORG REQUIRED\r'`, exit 1 |
| After revert + rebuild | `OK`, exit 0 |

### Wiring

`CMakeLists.txt`: `add_custom_command(TARGET casm POST_BUILD ...)` running
the script, so a broken id->message mapping fails the build. Skipped when
`CASM_ENABLE_DIAG_DUMP_TOKEN=ON` (the verifier re-assembles `diagnostics.s`
without that define). No MAIN size impact. CASM build 1384 -> 1386.

## Scoping Decisions (user-confirmed 2026-08-24)

1. **Sequencing:** run this WP only after the whole progress-indication
   feature closes (Increment 11). At drafting time Increment 6 had 29
   uncommitted files in flight; a diagnostics-wide change plus CMake
   envelope edits would near-certainly conflict, and current headroom
   (767 bytes) is sufficient for the remaining increments.
2. **`diagDumpToken`:** keep the source, gate it behind a build-time
   switch defaulting **off**, rather than deleting it.
3. **Finding C:** include it, with a compile-time guard assert pinning the
   `$3D..$43` locationless range, plus fault-injection verification across
   all six former dispatch ranges.
4. **Envelope:** keep MAIN at `$7400`. Recovered bytes are banked as
   working headroom, not given back.
5. **Finding D ordering (planner's call, 2026-08-24):** D runs **first**.
   It is the largest single finding, mechanically the simplest (constant
   changes), and unlike the diagnostics work it does not touch the
   fatal-error path. Its cap value is deliberately **not** fixed in this
   plan -- Increment 2 determines it empirically.

## Finding D: what must be proven before touching it

`CASM_FILENAME_MAX = 63` and `CASM_INCLUDE_FILENAME_MAX = 63` are
self-imposed, bounded by the 80-byte OS `CommandBuffer` rather than by any
hardware limit. They propagate a 64-byte slot into 13 MAIN-resident
buffers:

| Module | Buffer | Bytes |
| --- | --- | --- |
| `cli.s` | `CasmSourceNames` (8 x 64) | 512 |
| `cli.s` | `CasmOutputName`, `CasmListingName` | 128 |
| `parser.s` | `CasmIncludeFilename`, `CasmIncbinFilename` | 128 |
| `include.s` | `CasmIncludeKeyName` | 64 |
| | **Total** | **832** |

Evidence the real bound is far lower: a 1541 directory entry is **16
characters**; a device prefix (`8:`..`11:`) adds at most 3; and CASM's own
`cliDeriveOutputName` budgets only `MAX-2`/`MAX-3` for the `.PRG`
extension, so it never uses the tail either.

**An under-sized slot silently truncates or rejects filenames**, so
Increment 2 must establish the true reachable maximum -- not assume it --
covering at minimum:

- the longest name Command64's `findFile`/path layer can present,
  including any device prefix and appended extension;
- `cliDeriveOutputName`'s worst-case derived output and listing names;
- `.INCLUDE`/`.INCBIN` operands, which are user-authored source text and
  not obviously bounded by the 16-char directory limit;
- whether the include catalog's VMM record (`CASM_INCLUDE_PHYS_REC_NAME`,
  a 64-byte slot) must remain 64 for record-layout reasons. That slot is
  REU-resident and costs **no** MAIN, so shrinking it is not required and
  should be left alone unless the layout assert forces it.

The chosen cap must clear the proven maximum with deliberate margin, and
the existing `.assert`s guarding these constants must be updated to pin
the new values rather than silently dropped.

## Risk: Finding B has the widest blast radius

`diagPrintString` is imported by `casm.s` and `map.s` for **non-message**
text, and `diagnostics.s` itself calls it from **56 sites** -- only some of
which print a prefixed message. The rest print filenames, source lines,
carets, and include tracebacks, none of which may gain a `"CASM: "` prefix
or trailing CR.

The shared helper must therefore be a **separate entry point**
(`diagPrintMessage`), leaving `diagPrintString` byte-for-byte unchanged in
contract. Increment 6 is an explicit per-call-site audit, not a rename.

Three cases are easy to miss: `msgPhase2Ready` (`CASM: INPUT VALIDATED`,
the success path) and `msgUnknown` (`CASM: INTERNAL ERROR`, the fallback)
must both route through the helper; `msgAssertionFailedPrefix` must
**not** gain a trailing CR, since the echoed user text follows it.

## Verification Strategy

Two distinct risks need two distinct techniques.

**Wrong ID -> wrong message (Finding C)** would silently print a
misleading diagnostic -- the worst failure mode for this module.
Triggering all 86 IDs live is impractical; most need fault injection. The
audit proved a stronger, cheaper check: decode the linked PRG host-side
and verify every table entry. Increment 7 makes that a committed script
checking all 86 entries, not a sample.

*Implementation note:* the message strings are PETSCII (the ca65 charmap
sets bit 7 / swaps case), so a naive ASCII comparison reports false
mismatches. The audit's first verifier pass did exactly that and "failed"
all 16 checks before the decoder was corrected -- mask `& $7F`.

**Silent filename truncation (Finding D)** cannot be caught host-side at
all; it needs real names at the new boundary. Increment 3 adds explicit
at-cap and over-cap fixtures.

Live verification then covers what neither technique proves: that
representative diagnostics from each of the six former dispatch ranges
still render correctly on hardware, with source context exactly where it
was before.

## Atomic Increments

1. **Re-baseline.** Re-measure every module and whole-program
   `__MAIN_LAST__` against current `main`. Re-derive the diagnostic ID
   map; confirm it is still dense and that the locationless set is still
   exactly `$3D..$43`. Update this plan's tables. Capture pre-change
   artifact hashes and the full text of every diagnostic reachable by
   existing fixtures.
2. **Finding D research.** Establish the true maximum reachable filename
   length per the surfaces listed above. Record the evidence and choose
   the cap with margin. If the answer turns out to be near 63, D is
   dropped and the plan continues at Increment 4 -- that is a legitimate
   outcome, not a failure.
3. **Finding D implementation.** Reduce `CASM_FILENAME_MAX` and
   `CASM_INCLUDE_FILENAME_MAX`, update their guarding `.assert`s, and add
   at-cap / over-cap fixtures proving names at the boundary still resolve
   and over-length ones still produce the existing
   `FILENAME_TOO_LONG` diagnostics.
4. **Finding E.** Replace `PROG_DIGIT`'s six inline expansions with a
   divisor-table loop in `progress.s`. Re-run `test_casm_progress`
   unchanged -- its 20+ cases already cover the decimal boundaries.
5. **Finding A.** Gate `diagDumpToken`, its `.export`, and its token-name
   tables behind a build-time switch defaulting off. Verify production
   loses the bytes and a switch-on build still assembles and links.
6. **Finding B.** Add `diagPrintMessage` as a separate entry point; audit
   all 56 in-module call sites individually and route only true message
   prints through it. Strip the prefix from all 89 messages and the
   trailing CR from the 88 that carry one. Confirm `casm.s`/`map.s` are
   untouched.
7. **Host-side diagnostic-table verifier.** Add a committed, PETSCII-aware
   script asserting every diagnostic ID maps to its expected text. It must
   pass against the *unmodified* dispatch **and** be shown to catch a
   deliberately injected fault, before it is trusted to validate
   Increment 8.
8. **Finding C.** Replace the six range blocks and the 9-way chain with
   one dense table plus a two-compare context test. Preserve the `.ASSERT`
   message-echo special case exactly. Add compile-time asserts pinning
   **both** the table length and the `$3D..$43` locationless range, so a
   future diagnostic allocated outside that run fails the build instead of
   silently printing a bogus source location.
9. **Live verification.** Under VICE: one diagnostic from each of the six
   former ranges plus both locationless sub-cases; filename resolution at
   the new cap including an `.INCLUDE` and an `.INCBIN`; and a normal
   assembly confirming progress output is unchanged.
10. **Regression, size, and closeout.** Full build, no-change rebuild,
    affected-harness sweep, output-artifact hashes compared against
    Increment 1's baseline, final envelope measurement, walkthrough.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/common.inc` | Modify (filename caps + asserts; debug-token switch; contiguity asserts) |
| `src/external/casm/diagnostics.s` | Modify (Findings A, B, C) |
| `src/external/casm/progress.s` | Modify (Finding E) |
| `src/external/casm/cli.s`, `parser.s`, `include.s` | Modify only if a reduced cap requires bounds-logic adjustment |
| `CMakeLists.txt` | Modify (debug-token switch plumbing; harness envelope corrections if any) |
| `scripts/verify_casm_diag_table.py` | Create (host-side ID->message verifier) |
| Filename at-cap / over-cap fixtures | Create (Increment 3) |
| `tests/src/casm_*/BUILD_*` | Modify (build-number bumps only) |
| `brain/walkthroughs/2026-08-24-casm-memory-optimization.md` | Create |

## Stop Conditions

Halt and request direction rather than pushing through if:

- The re-baseline shows the diagnostic ID range is no longer dense, or a
  locationless diagnostic exists outside `$3D..$43`. Finding C's design
  assumption is broken and needs re-planning, not patching.
- Increment 2 cannot establish a filename maximum with confidence, or the
  maximum proves close to 63. Drop Finding D rather than guess.
- Any filename that resolves today fails to resolve after Finding D, or
  any `FILENAME_TOO_LONG` diagnostic changes which inputs it fires on.
- Any diagnostic's rendered text, source context, caret, or traceback
  differs from the Increment 1 baseline in any way.
- The host-side verifier fails, or fails to detect the injected fault when
  proven in Increment 7.
- Any harness fails unexpectedly, or a no-change rebuild changes an
  artifact.
- Assembled output bytes change for any fixture -- they must not; this WP
  touches only diagnostics, filename storage, and progress formatting.
- Measured savings come in materially below the audit's figures,
  suggesting the baseline moved in a way that invalidates the approach.
- A genuinely new defect is found outside this WP's scope: disclose and
  defer as a separate follow-up, do not fix inline.

## Documentation, Task, and DOX Updates

At approval: create the Taskwarrior task; record it in `brain/task.md` and
`wiki/tasks/casm.md`.

At completion: `CHANGELOG.md` (size reduction, no behavior change),
`brain/KNOWLEDGE.md`, walkthrough, and memory. Three durable lessons are
worth recording regardless of outcome -- that `ld65` links whole objects so
an exported-but-uncalled routine still ships; that CASM message strings are
PETSCII so host-side verifiers must mask `& $7F`; and that a self-imposed
filename cap silently multiplied into 832 bytes across four modules.

If Finding D changes the documented filename limit, `docs/` and `wiki/`
CASM references must be updated -- the one case in this WP that could
become user-facing.

## Completion Gate

- Re-baselined measurements recorded, and final savings measured, not
  estimated.
- Finding D's maximum-length evidence recorded, with at-cap and over-cap
  fixtures passing.
- Host-side verifier committed, proven fault-detecting, and passing across
  every diagnostic ID.
- Live evidence for all six former dispatch ranges, both locationless
  sub-cases, and filename resolution at the new cap.
- Full build clean, no-change rebuild stable, output artifacts
  byte-identical to the Increment 1 baseline.
- Envelope evidence recorded; MAIN still `$7400` per Scoping Decision 4.
- Trackers agree and the user explicitly approves closing this WP.

## Progress

- 2026-08-24: Plan drafted from a measured audit of `diagnostics.s`
  (Findings A/B/C, all figures from real ca65/ld65 links re-measured in one
  controlled batch). Four scoping decisions confirmed with the user.
- 2026-08-24: Broadened to a CASM-wide plan after a follow-up audit found
  Finding D (filename buffers, ~520 bytes across 13 buffers in 4 modules --
  larger than any single diagnostics finding) and Finding E (`progress.s`
  macro expansion, ~150 bytes). Finding D sequenced first and given its own
  gating research increment, since its size is certain but its safe cap
  value is not. Not yet approved; prerequisite (progress-indication
  Increment 11) not yet met.
- 2026-08-31: Plan approved. Taskwarrior 42 created
  (`33d69dd5-c96b-4d3a-a27c-9fd93cc31de3`, project `command64.casm`,
  `+casm +feature`, `depends:33`); recorded in `brain/task.md` and
  `wiki/tasks/casm.md`. Implementation still blocked on progress-indication
  Increment 11.
- 2026-08-31: **Increment 1 (re-baseline) executed.** Prerequisite now met
  (task 33 merged to `main`). Branch `feature/casm-memory-optimization` off
  `f4227cf`. All measurements re-taken against `V0.5.0` build 1380 -- see
  the new "Increment 1 Re-baseline" section. Headroom moved 767 -> 642 at
  `$7400` (consistent with task 33's own closeout figure). Diagnostic ID
  range still dense `$01..$56`. Findings D/A/B unchanged; E revised (5
  expansions not 6). **Finding C's dispatch structure has grown from the
  audited "six ranges + 9-way chain" to seven parallel tables + a 9-way
  chain** (Phase 13 WP81/82/83 + progress increments added their own tables
  since 2026-08-24); no Stop Condition tripped (range dense, skip-context
  set still exactly `$3D..$43`), but Increments 7-9 need re-scoping to the
  current structure before Finding C is implemented. Paused here for user
  direction on Finding C re-scoping vs. proceeding D/E/A/B first.
- 2026-08-31: **Increment 2 (Finding D research) executed.** Command64's
  filesystem is CBM DOS with no long-name path (verified in
  `path.asm`/`file.asm`/`apptable.asm`); the true reachable filename max is
  23 bytes (16-char DOS entry + 3-char device prefix + 4-char synthetic
  extension). CASM currently accepts up to 63. **User approved cap = 32**
  for both `CASM_FILENAME_MAX` and `CASM_INCLUDE_FILENAME_MAX`, knowingly
  accepting that `FILENAME_TOO_LONG` now fires for 33..63-char inputs that
  previously failed downstream with the same outcome but different
  diagnostic text. Re-grep found more cap-keyed MAIN buffers than the audit
  (~1,090 -> ~540 bytes, ~550 saved). See the new "Increment 2 Finding D
  Research" section for the affected-buffer table and Increment 3
  constraints. Increment 3 (implementation) is next.
- 2026-08-31: **Increment 3 (Finding D implementation) executed.** Both
  caps 63 -> 32; three cap-keyed buffers and the layout asserts updated;
  new `.assert`s pin the 32 values. Found and fixed a real latent bug --
  `cliInit`'s `ciClearNames` cleared a hardcoded 512 bytes and would now
  run 248 bytes past the shrunk `CasmSourceNames` into adjacent BSS.
  `casm_cliderive` and `casm_include` fixtures re-pinned to the new
  boundary. Full build clean (every constant assert across 31 harnesses
  passed). **Net MAIN saving 482 bytes**; headroom at `$7400` 642 -> 1,124.
  Host-side harness VICE run folded into Increment 9/10. See the new
  "Increment 3 Finding D Implementation" section. Increment 4 (Finding E)
  is next.
- 2026-08-31: **Increment 4 (Finding E) executed.** `progressPrintDec`'s
  five inline `PROG_DIGIT` expansions replaced with a divisor-table loop;
  no new scratch (stack-carries the tentative low byte and the divisor
  index across the print). A host-side model of both the old and new
  digit-extraction logic showed **0 mismatches over all 65,536 values x
  both field widths**. Build + `test_casm_progress` clean. **progress.o
  CODE -108 bytes**; cumulative D+E headroom `642 -> 1,232`. Increment 5
  (Finding A -- gate `diagDumpToken`) is next.
- 2026-08-31: **Increment 5 (Finding A) executed.** `diagDumpToken`, its
  `.export`, its `.import CasmTokenText`, and its ~40 token-name
  strings/tables gated behind `CASM_ENABLE_DIAG_DUMP_TOKEN` (`.ifndef`
  default 0 in `common.inc`; new `EXTRA_DEFINES` keyword in
  `cmake/Ca65.cmake`; `option(... OFF)` at the casm call site). Default
  build drops **653 bytes** (251 CODE + 402 RODATA -- above the audit's 509
  because Phase 12 grew the token tables). `-D ...=ON` build verified: clean
  link, `diagnostics.o` restored byte-for-byte to the pre-Finding-A size.
  All `CASM:` diagnostic messages byte-identical to the Increment 1
  baseline. Cumulative D+E+A headroom `642 -> 1,885`. Increment 6
  (Finding B -- `diagPrintMessage` shared prefix/CR helper) is next.
- 2026-08-31: **Increment 6 (Finding B) executed.** New internal
  `diagPrintMessage` (prefix + body + CR, body pointer on the stack, no
  BSS); `diagPrintString` unchanged. All 89 message strings stripped of
  `"CASM: "` and trailing `PetCr`; 17 message-print call sites in
  `diagPrintFatal`/`diagPrintPhase2Ready` retargeted; the ~30 non-message
  `diagPrintString` calls audited and left. Assert-echo special case
  restructured (prefix + "ASSERTION FAILED: " + user text + CR).
  **585 bytes** recovered (audit projected 587). Host-side: 88/88
  diagnostics render byte-identically to the Increment 1 baseline;
  `casm.s`/`map.s` untouched; full build clean. Cumulative D+E+A+B headroom
  `642 -> 2,470`. Increment 7 (host-side diagnostic-table verifier) is
  next.
- 2026-08-31: **Increment 7 (host-side diagnostic-table verifier)
  executed.** `scripts/verify_casm_diag_table.py` created -- re-links
  `diagnostics.s` with `-g`/`-Ln`, walks `diagPrintFatal`'s six tables +
  nine-entry `beq` chain in the linked `casm.prg`, demasks `& 0x7F`, and
  compares every id's rendered text to a frozen `EXPECTED` dict from the
  Increment 1 baseline. Passes on the current dispatch (86 ids + 2 extras);
  `--self-test` and a real `msgOrgRequired` edit both caught (exit 1).
  Wired `POST_BUILD` on the `casm` target. `decode_id_to_body()` is the
  only part Finding C rewrites; the `EXPECTED` dict is the invariant.
  Increment 8 (Finding C) is next.
