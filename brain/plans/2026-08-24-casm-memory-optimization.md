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
