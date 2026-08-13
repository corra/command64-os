# CASM Phase 11 WP61 Increment 8 Audit and Walkthrough

Status: Frozen for user review
Branch: `feature/casm-phase11-wp60`
CASM version at audit time: `0.2.2` build `1266` (unchanged since WP60)
Plan: `brain/plans/2026-08-12-casm-phase11-wp61-determinism-and-boundary-spot-checks.md`
Taskwarrior: `f6845310-bcce-4448-b5f2-0aa19a73723b`

## Scope

Increment 8 reconciles every prior WP61 increment's evidence into one row-by-row audit, records defects/fixes/residual risk, and synchronizes task records. No production, fixture, or build-system source changes in this increment itself.

## Reconciliation Against the Increment 1 Register

The Increment 1 register (`brain/reviews/2026-08-12-casm-phase11-wp61-increment1-scope-register.md`) froze 5 in-scope items. All 5 are now closed:

| Item | Disposition at Increment 1 | Closed by | Evidence |
| --- | --- | --- | --- |
| Determinism (PRG/R6/listing/map) | add | Increments 2-3 | 3 self-compares (`FILES COMPARE OK`) + 2 independent-reference cross-checks for PRG/R6; `.LST` self-compare; `/M` manual live screen diff, identical both times |
| FORCE_ABS two-pass stability | add | Increment 4 | New `casmfa2p.s` forward-reference fixture; self-compare and reference cross-check both `FILES COMPARE OK`; `LDA TARGET` confirmed emitted as 3-byte absolute, never zero-page |
| Source extent 65,535/65,536 | add | Increment 6 | `casmsrcmax.s` (exactly 65,535 bytes) accepts; combined with `casmsrcbit.s` (65,536) rejects with `CASM_DIAG_SOURCE_OFFSET_OVERFLOW`, no partial commit |
| Symbol/token length-32 | add | Increment 5 | New `tests/src/casm_lexer/casm_lexer.s` (first-ever `lexer.s`-linked harness); 31-byte accept, 32-byte reject with `CASM_DIAG_TOKEN_TOO_LONG`, unmodified token state |
| Empty-source-file | closed by re-scope (Increment 1 itself) | Increment 1 | `cc1541` cannot write a zero-byte SEQ fixture; re-confirmed as a tooling gap, not a code gap, no action possible without new tooling |

All 4 actionable residual boundary items from WP60 Increment 9 are now closed. The 5th (empty-source-file) remains closed-by-re-scope, matching the disposition WP60 Increment 9 already recorded and this plan's own Increment 1 explicitly re-confirmed rather than silently re-carrying.

## Defects Found

**One build-system-only defect, found and fixed within WP61 itself** (Increment 7): Increment 4 added `casmfa2p` to `CASM_REF_NAMES` without extending the existing `casmbig1`/`casmopall` `test.d64`-exclusion list, overflowing that disk's already-full 144-entry directory on the first full unrestricted rebuild. Fixed by extending the exclusion list. No production code was involved; this was a CMake fixture-placement oversight, caught precisely because Increment 7 finally ran a full unrestricted build (the first since Increment 3). No production defect was found anywhere in WP61.

## Fixes Applied

The one fix above (build-system only). No production source was changed at any point in WP61 -- every increment's evidence confirms `casm.prg` remains byte-identical to its WP60 `0.2.2` state (18581 code bytes, 2806 relocations), independently re-verified at Increment 7.

## Unchanged Contracts

- Public exports, diagnostics, parser/instruction records, opcode masks, mode numbers, relocation (R6) format, listing (`.LST`) format, and symbol map (`/M`) output: all unchanged.
- No production zero-page or BSS allocation added.
- CASM version: `0.2.2` throughout WP61 -- no version bump, matching the user-confirmed policy (bump only if a production change occurs; none did) and WP56's own precedent for a planning/verification-only work package.

## Metrics Summary

| Item | Count |
| --- | --- |
| Determinism self-compares (PRG/R6/listing) | 3, all `FILES COMPARE OK` |
| Determinism reference cross-checks | 2 (`casmreloc1`, `casmopall`), both `FILES COMPARE OK` |
| `/M` symbol map manual live comparisons | 1 (8 symbols, identical across 2 runs) |
| New fixtures added | `casmfa2p.seq`, `casmsrcmax.seq` (65,535 bytes), `casmsrcbit.seq` (1 byte) |
| New test harnesses added | 1 (`tests/src/casm_lexer/casm_lexer.s` -- first `lexer.s`-linked harness in this codebase) |
| New reference PRGs cross-checked live | 3 (`casmfa2p.ref`, plus re-confirmed `casmreloc1.ref`/`casmopall.ref`) |
| WP60 residual boundary items closed | 4 of 4 actionable (5th closed-by-re-scope at Increment 1) |
| Production defects found | 0 |
| Build-system defects found and fixed | 1 (Increment 7, `test.d64` directory-overflow oversight) |
| Production code-byte delta since WP60 `0.2.2` baseline | 0 |
| CASM version | unchanged, `0.2.2` |

## Residual Risks

None new. All items this plan set out to close are closed. The phantom-EOF-byte defect (Taskwarrior UUID `882433f0-cde1-4849-8b3c-df32613518c3`) remains separately tracked, untouched by WP61 as agreed at plan approval, and confirmed at Increment 6 to be structurally unreachable by the source-extent reject path (a different code path: raw load-time combined-cap check vs. later per-byte lexer consumption of an already-loaded source).

## Manual Confirmation Steps (for user replay if desired)

1. `cmake --build build` (full, unrestricted) -- confirm clean, and that `src/external/casm/BUILD_CASM` reads `1266` with the hash unchanged from this record.
2. Boot Command64 from `build/casm_opcode_test.d64`; run `test_casm_opcode` -- expect `CASM OPCODES: PASS` (197/197).
3. On the same disk: assemble `casmopall.s`/`casmreloc1.s`/`casmfa2p.s` and `comp` each against its own `.ref` -- expect `FILES COMPARE OK` for all three.
4. Boot from `build/casm_listing_test.d64`; run `test_casm_lexer` -- expect `CASM LEXER: PASS` (2/2).
5. Boot from `build/casm_include_test.d64`; run `casm casmsrcmax.s casmsrcbit.s /o:<name>.prg` -- expect `CASM: SOURCE OFFSET OVERFLOW` and no output file committed.
6. Any harness/program name containing `_` must be dispatched with the underscore sent as PETSCII `$A4` via `vice_keyboard_petscii`, never literal ASCII `_` via `vice_keyboard_type`.

## Sign-off

All applicable WP61 completion criteria (per the plan) are met:

1. Determinism proven (self-compare, byte-identical) for PRG/R6 across 3 fixtures and for listing across 1. **Met.**
2. `/M` symbol map shown identical across two runs, manual/live nature explicitly noted. **Met.**
3. `FORCE_ABS` stability across a genuine two-pass real assembly proven, not just asserted at unit level. **Met.**
4. Source-extent accept (65,535) and reject (65,536 combined) boundary proven with correct diagnostic. **Met.**
5. Symbol/token name-length-32 rejection proven at the lexer layer with correct diagnostic and unmodified token state. **Met.**
6. Empty-source-file row explicitly closed by re-scope, not left unresolved. **Met.**
7. All changed/affected regression targets pass live and return to shell, including a full clean/unrestricted rebuild. **Met** (Increment 7).
8. No production change occurred, or any that did is disclosed/approved/version-bumped. **No production change occurred; no bump due, per policy.**
9. Records, walkthrough, and Taskwarrior agree. **This record**, plus `brain/task.md` and `wiki/tasks/casm.md` synchronized as part of this increment.
10. User explicitly approves completion. **Requesting now.**

Requesting approval to mark **WP61 complete** at CASM `0.2.2` build `1266` (no version bump, per the no-production-change policy) and close Taskwarrior task `f6845310-bcce-4448-b5f2-0aa19a73723b`.
