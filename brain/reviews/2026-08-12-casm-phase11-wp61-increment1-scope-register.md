# CASM Phase 11 WP61 Increment 1 Scope and Spot-Check Register

Status: Frozen for user review
Branch: `feature/casm-phase11-wp60`
Baseline: CASM `0.2.2` build `1266`
Plan: `brain/plans/2026-08-12-casm-phase11-wp61-determinism-and-boundary-spot-checks.md`
Taskwarrior: `f6845310-bcce-4448-b5f2-0aa19a73723b`

## Scope and Method

This is the Increment 1 gate artifact. It freezes the disposition of WP61's
5 in-scope items (4 boundary residuals + the determinism charter itself),
records the exact production constants/routines each closure will exercise
(confirmed by source trace, not assumed), and re-surveys disk free space
across every candidate target disk immediately before implementation
begins, since builds since WP60's own survey may have shifted free space.

No production or fixture source changed while producing this register.

## Item 1: Determinism (PRG/R6/listing/map self-compare)

No new production routine is exercised beyond what already exists --
`casm`'s own assembly path and `comp`'s own byte-for-byte file diff, called
twice against independently-named outputs. Confirmed `comp.s`'s header
states it diffs "regardless of file type," so it needs no PRG-specific
handling to compare `.LST` files.

Disposition: **add** (no prior evidence of this specific self-compare
proof at any increment; every prior WP's `comp` use was against a fixed
`.ref`, not a second independent live run of the same source).

## Item 2: FORCE_ABS two-pass stability

Confirmed by source trace (`parser.s:526-575`,
`parserParseExpressionValue`): `CASM_PARSER_STMT_FORCE_ABS` is derived
fresh on every call from `CASM_EXPR_FLAG_SYMBOL_DERIVED` -- a purely
syntactic classification (is this operand symbol-derived at all), set
unconditionally before the resolved/unresolved branch, independent of the
symbol's actual value. `parserParseStatement` is called once per statement
per pass, and Pass 2 re-parses the source from scratch rather than reusing
Pass 1's parsed record -- so by construction this flag cannot differ
between passes for identical source text. WP60 Increment 2's register
correctly identified this as unproven *end-to-end*, not incorrect: the
existing evidence (`casm_pass1.s:470-517`, `p1back1`) is a real
state-commit assertion but only within one measure pass.

Disposition: **add** (end-to-end two-pass proof; single-pass unit evidence
already exists and is not being duplicated).

## Item 3: Source extent boundary (65,535 accept / 65,536 reject)

Confirmed by source trace:

- `CASM_SOURCE_VMM_MAX_BYTES = 65535` (`common.inc:1055`), asserted at
  compile time (`common.inc:1057`).
- `sourceLoad` allocates exactly this many VMM bytes up front
  (`source.s:401-404`) and tracks the *combined* multi-file running total
  via `CasmSourceStreamCursorLo/Hi`.
- `slCheckCap` (`source.s:631-643`) adds the next block's length to the
  running cursor using plain 16-bit addition and checks the carry: no
  carry means the combined total still fits in 16 bits (<= 65535, since
  the cap equals the full 16-bit range), carry set means the addition
  wrapped past 65535 -- i.e. exactly the 65,536th byte overflows.
- On overflow: `A = CASM_DIAG_SOURCE_OFFSET_OVERFLOW` (`$15`,
  `common.inc:617`), `C` set, cursor left unchanged (not committed).

This confirms the plan's proposed mechanism exactly: one ~259-block
`casmsrcmax.s` fixture at exactly 65,535 bytes (accept, alone), reused with
a second small existing fixture appended as a second source file to push
the combined total to 65,536 (reject, `CASM_DIAG_SOURCE_OFFSET_OVERFLOW`,
cursor unchanged).

Disposition: **add** (zero prior evidence at either literal boundary value;
existing large fixtures top out at 6,000-40,000-ish bytes, well under the
cap).

## Item 4: Symbol/token name-length-32 rejection

Confirmed by source trace:

- `CASM_TOKEN_TEXT_MAX = 31` (`common.inc:473`).
- `lexerTokenAppend` (`lexer.s:525-537`): compares the current payload
  length against `CASM_TOKEN_TEXT_MAX` with `cpx`/`bcs` *before* appending
  -- the 32nd append attempt (payload already holding 31 bytes) is
  rejected with `A = CASM_DIAG_TOKEN_TOO_LONG`, `C` set, and the existing
  31-byte payload is left untouched (the rejected byte is never written).
- No existing harness anywhere in `tests/` links `lexer.s` directly or
  exercises this routine (`tests/src/casm_lexer/` does not exist prior to
  this increment).

Disposition: **add**, new minimal harness required (this is a genuinely
unlinked module for testing purposes, not a strengthen of existing
coverage).

## Item 5: Empty-source-file boundary -- re-scope

Per WP60 Increment 7's live-confirmed finding (`cc1541` errors with
"Unexpected filesize when reading casmsrc0.seq" on a zero-byte SEQ write
attempt), this project's fixture-authoring toolchain has no path to
produce this input at all. Re-confirmed here: no new tool was introduced
between WP60 and WP61 that would change this.

Disposition: **closed by re-scope** -- not carried forward a third time.
Revisit only if a future WP introduces a fixture-authoring path that does
not depend on `cc1541`'s SEQ-write validation.

## Disk Free-Space Re-Survey (2026-08-12, post-WP60-completion rebuild)

Re-built every candidate disk target fresh and re-listed via
`vice_disk_list` (not host-side `c1541`, per this session's standing
preference) before picking placement for Increments 4-6's new fixtures.

| Disk | Directory entries | Blocks free | Notes |
| --- | --- | --- | --- |
| `test.d64` | 144/144 (full) | 34 (was 36 at WP60 Increment 8's survey) | still directory-full; the 2-block drift is unexplained BAM-allocation variance between rebuilds, not investigated further as it does not change this disk's disposition (unusable for new files either way) |
| `casm_overflow_test.d64` | 19 | 7 | unchanged, still effectively unusable for new files |
| `casm_listing_test.d64` | 45 | 38 | unchanged; **not enough** for the ~259-block source-extent fixture |
| `casm_opcode_test.d64` | 7 | 489 (was 491) | ample room; candidate for Increments 2 (determinism smoke) and 5 (lexer harness, small) |
| `command64_casm_utils.d64` | 13 | 245 | ample room; candidate for Increment 2's `banner.s`/`dash.s` determinism leg (already carries both sources) |
| `casm_include_test_d64` | (not previously surveyed) | 542 | largest free margin of any existing CASM disk; strong candidate to host the ~259-block Increment 6 extent fixture instead of a brand-new disk, pending a name-collision/purpose check at Increment 6 activation |

The 2-block `test.d64` drift is noted rather than silently observed and
dropped: it is bounded, does not indicate directory or content corruption
(verified: all 144 entries present, byte-identical file list to the
pre-WP61 survey), and does not affect any WP61 disposition since `test.d64`
was already excluded from every candidate placement.

## Revised Placement Proposal

Given the fresh survey, `casm_include_test_d64` (542 blocks free) likely
avoids the need for a brand-new `casm_srcbound_test_d64` disk the plan
tentatively proposed -- pending confirmation at Increment 6 activation that
adding a ~259-block fixture there does not collide with that disk's own
existing purpose (Phase 9 `.INCLUDE` catalog testing) or push it close to
its own capacity ceiling the way `casm_overflow_test.d64` and
`test.d64` are already pinned. This is a proposal, not a commitment --
Increment 6 re-confirms before creating or reusing any disk.

## Sign-off

All 5 in-scope items dispositioned with source-trace-confirmed mechanisms
and exact expected diagnostics/constants. No production or fixture change
made. Disk free-space re-survey complete; no candidate disk shows an
unexpected capacity regression that would block any increment.

Requesting user approval of this register before Increment 2 (determinism
proof: PRG/R6) activates.
