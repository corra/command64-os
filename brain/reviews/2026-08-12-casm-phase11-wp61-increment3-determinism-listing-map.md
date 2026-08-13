# CASM Phase 11 WP61 Increment 3 Determinism Proof: Listing and Map

Status: Frozen for user review
Branch: `feature/casm-phase11-wp60`
Baseline: CASM `0.2.2` build `1266`
Plan: `brain/plans/2026-08-12-casm-phase11-wp61-determinism-and-boundary-spot-checks.md`
Taskwarrior: `f6845310-bcce-4448-b5f2-0aa19a73723b`

## Scope and Method

This is the Increment 3 gate artifact: extends Increment 2's determinism
proof to `/L` listing output (file-based, `comp`-verified) and `/M` symbol
map output (screen-print-only, verified by manual live decode-and-diff,
per this plan's own documented limitation -- `/M` writes no file). Uses
`casmopall.s` throughout as the single representative fixture (151
statements, already proven byte-correct and self-consistent at Increment
2), on the same `casm_opcode_test.d64` Increment 2 left attached. No new
fixture or disk change needed for this increment.

## Live VICE Results (VICE 3.10, `casm_opcode_test.d64`)

### `/L` listing determinism

| Run | Command | Result |
| --- | --- | --- |
| 1 | `casm casmopall.s /o:m1.prg /l` | `CASM: INPUT VALIDATED`; `m1.lst` committed (33 blocks) |
| 2 | `casm casmopall.s /o:m2.prg /l` | `CASM: INPUT VALIDATED`; `m2.lst` committed (33 blocks) |
| self-compare | `comp m1.lst m2.lst` | `FILES COMPARE OK` |

### `/M` symbol map determinism

| Run | Command | Screen output |
| --- | --- | --- |
| 1 | `casm casmopall.s /o:mm1.prg /m` | `SYMBOL MAP` -- 8 rows (`$C033 tg22`, `$C035 tg23`, `$C037 tg24`, `$C03E tg27`, `$C040 tg28`, `$C042 tg29`, `$C045 tg31`, `$C047 tg32`), `008 SYMBOLS`, then `CASM: INPUT VALIDATED` |
| 2 | `casm casmopall.s /o:mm2.prg /m` | Identical: same 8 rows in the same order with the same addresses/labels, same `008 SYMBOLS`, then `CASM: INPUT VALIDATED` |

Both runs' screen RAM were independently decoded via `vice_memory_read`
(not screenshots) and compared row-by-row by this agent -- byte-identical
across every address, label, and count. This is manual/live evidence, not
an automated regression, exactly as the plan's Determinism Method section
anticipated (`/M` has no file to `comp`).

## Findings

No determinism mismatch found for either `/L` listing bytes or `/M` symbol
map content. No production defect found. No production or fixture source
change -- this increment needed neither a new fixture nor a disk change,
reusing Increment 2's already-placed `casmopall.s` and its already-proven
self-compare/cross-check evidence.

## Disposition

Listing (`/L`) determinism: **closed**. Symbol map (`/M`) determinism:
**closed**, with the manual/live nature of the evidence explicitly
recorded per the plan rather than overstated as file-based proof.

Together with Increment 2, WP61's full determinism charter (PRG, R6,
listing, map) is now closed across all four output types the plan named.

Requesting user approval before Increment 4 (FORCE_ABS two-pass closure)
activates.
