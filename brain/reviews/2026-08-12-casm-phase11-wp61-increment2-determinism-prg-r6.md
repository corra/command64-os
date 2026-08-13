# CASM Phase 11 WP61 Increment 2 Determinism Proof: PRG/R6

Status: Frozen for user review
Branch: `feature/casm-phase11-wp60`
Baseline: CASM `0.2.2` build `1266`
Plan: `brain/plans/2026-08-12-casm-phase11-wp61-determinism-and-boundary-spot-checks.md`
Taskwarrior: `f6845310-bcce-4448-b5f2-0aa19a73723b`

## Scope and Method

This is the Increment 2 gate artifact: proves that re-assembling identical
CASM source twice, in the same live session, produces byte-identical PRG
(and, for a relocatable source, R6 footer) output. Uses native `comp`'s
own file-type-agnostic diff as a **self-compare** between two independently
named live runs, not a compare against a fixed `.ref` -- a different (and
here, primary) proof from every prior WP's `comp` usage.

## Build Change

`casmhello.s` and `casmreloc1.s` (both pre-existing generated fixtures, not
duplicated) plus `casmreloc1.ref` were appended to `casm_opcode_test_d64`
(`CMakeLists.txt`), which already carries `command64`/`casm`/`comp` and had
489 blocks free -- avoids needing multi-drive setup or a new disk for this
increment. Final disk state: 480 blocks free, 15 directory entries (well
under the 144-entry ceiling), all three source fixtures plus their outputs
present.

## Live VICE Results (VICE 3.10, `casm_opcode_test.d64`)

| Fixture | Run 1 | Run 2 | Self-compare | Cross-check vs. `.ref` |
| --- | --- | --- | --- | --- |
| `casmhello.s` (static, no relocation) | `CASM: INPUT VALIDATED` (`h1.prg`) | `CASM: INPUT VALIDATED` (`h2.prg`) | `comp h1.prg h2.prg` -> `FILES COMPARE OK` | not applicable (no fixed `.ref` for this fixture in this increment's scope) |
| `casmreloc1.s` (relocatable, real R6 footer) | `CASM: INPUT VALIDATED` (`r1.prg`) | `CASM: INPUT VALIDATED` (`r2.prg`) | `comp r1.prg r2.prg` -> `FILES COMPARE OK` | `comp r1.prg casmreloc1.ref` -> `FILES COMPARE OK` |
| `casmopall.s` (151-statement exhaustive-opcode) | `CASM: INPUT VALIDATED` (`o1.prg`) | `CASM: INPUT VALIDATED` (`o2.prg`) | `comp o1.prg o2.prg` -> `FILES COMPARE OK` | `comp o1.prg casmopall.ref` -> `FILES COMPARE OK` |

All 6 assembly runs succeeded, all 3 self-compares matched byte-for-byte,
and both cross-checks against independently-trusted references also
matched -- meaning the self-compare proof is not merely internally
consistent (both runs could in principle drift together from a shared
non-deterministic seed) but externally anchored to bytes derived
independently of this live session.

Note: `casmhello.s` uses only literal absolute addresses and no symbol
references, so it carries no R6 footer -- its `comp` covers PRG bytes only,
by design (this is the intended "flat/absolute" leg; R6 determinism is
covered by `casmreloc1.s`). `casmopall.s` similarly assembles to a fixed
`.ORG` with only local same-file branch targets (PC-relative, not R6
relocation entries), so its `comp` is also PRG-bytes-only, at the largest
single-file scale exercised anywhere in WP60/WP61.

## Findings

No determinism mismatch found across 3 fixtures spanning small-static,
small-relocatable, and large-exhaustive-opcode source shapes. No production
defect found. No production source change; the only change is the build-
system fixture-placement addition described above.

## Disposition

PRG determinism: **closed**, 3/3 fixtures. R6 relocation determinism:
**closed**, 1/1 relocatable fixture exercised (`casmreloc1.s`), with an
additional independent-reference cross-check beyond what the plan required.

Requesting user approval before Increment 3 (determinism proof: listing and
map) activates.
