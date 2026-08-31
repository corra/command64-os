# CASM Progress Increment 9 - Full Implementation Review Walkthrough

Status: **COMPLETE - user-approved 2026-08-31.** Review complete;
PR-1/PR-2/PR-4 remediated inline and re-verified; PR-3/PR-5 recorded
(deferred/no-action). Increments 10 (runtime acceptance) and 11
(completion gate) remain for the feature.

Plan: `brain/plans/2026-08-24-casm-progress-increment09-implementation-review.md`
Review register: `brain/reviews/2026-08-24-casm-progress-implementation-review.md`

## Candidate

Frozen at commit `fb2fe48` ("casm: close progress Increment 8"):
`casm.prg` sha256 `af1bacda...`, `BUILD_CASM` 1378, `CASM V0.4.0.1378`.
Feature diff vs merge-base `4e3f921`: `progress.s` (+710, new), `casm.s`
(+361), `emit.s` (+90), `diagnostics.s` (+74), `source.s` (+29), `reloc.s`
(+7), `common.inc` (+14), `AGENTS.md` (+12), `CMakeLists.txt` (+246).

## Review coverage

Line-by-line read of every changed production file against the Increment 2
frozen ABI and the Increments 3-8 walkthroughs. Audited: statement-counting
dispatch, redraw cadence, cross-pass agreement ordering, screen-width
arithmetic (all renderers = exactly 34 columns), the first-render guard,
byte accounting across `emitFlush` + R6 table + R6 footer, the import graph
(one-way `diagnostics.s -> progressClearTransient`), stack balance (only
`progressPrintChar`, `pha`/`pla` balanced), decimal-mode safety (no `sed`,
every `adc`/`sbc` explicitly `clc`/`sec`-primed), `diagPrintFatal`'s A-stash,
`crpSnapshotName` failure handling, the counter-overflow guard, and every
`progressStatement`/`progressRenderTransient` call site's register and
`CasmPtr0` effects.

**What is correct** is enumerated in the review register's "What is correct"
section - the audit found the core design and its integration sound, and
consistent with the Increment 4 live evidence (byte totals exact at
64/65/66/129/7/258/10/54/82/9, counter tracks counted statements, cadence
mod-64).

## Findings

| ID | Sev | Summary | Disposition |
|---|---|---|---|
| PR-1 | MEDIUM | `progressReturnToStart` / `progressClearTransient` headers say `Clobbers: A, Y`; both actually clobber **A, X, Y** (X via `progressPrintChar`'s `tax`). Frozen ABI table lists the latter as `A, X` (misses Y). `diagnostics.s:156` repeats "A, Y". No live bug (`diagPrintFatal` saves only A, needs neither X nor Y; all other callers are progress-internal with correct ABI). | **FIXED** - three doc sites corrected to `A, X, Y`. |
| PR-2 | MEDIUM | `CASM_PROG_FLAG_SUSPENDED` was write-only: set by `progressSuspend`, read nowhere. The `/L` and `/M` suspend calls in `casm.s` (commented "defensive completeness against a future increment adding rendering") enforced nothing. | **FIXED** - `progressRenderTransient` / `progressSourceLoadBytes` / `progressDirectiveBytes` now early-return when `SUSPENDED`. No current path renders after a suspend, so this is future-proofing; `progressInit` zeroes the flag each invocation. |
| PR-3 | LOW | `CasmProgByteLo/Hi` (and the `DONE: ... nnnnn BYTES` field) is 16-bit; an output PRG > 65535 bytes (`.ORG $0000` + `.FILL 65535,0`, huge `.INCBIN`) wraps the accumulator and shows `total mod 65536`. The written file is still correct (COMP-verified). | **DEFERRED** - known display limitation for a near-degenerate whole-address-space fill; not worth a wider counter. Recorded in the register. |
| PR-4 | LOW | `crpProgressHook`'s comment explains the safe A/X/Y register clobber but not that `crpSnapshotName` also clobbers `CasmPtr0Lo/Hi` (identity-changed path only). Verified safe: `emit.s`/`opcodes.s` never read `CasmPtr0`; `crpLabel`/`crpConstant`/`crpInclude` set it fresh. | **FIXED** - comment extended so a future `CasmPtr0` use in `crpInsn`/`crpDir` is not added blind. |
| PR-5 | INFO | `progress.s` message literals are uppercase PETSCII, consistent with the rest of CASM and verified legible in Increment 4. | **No action** - noted for a future lowercase-convention migration. |

## Remediation (in-tree, one change)

- `progress.s`: corrected the `progressReturnToStart` / `progressClearTransient`
  clobber-doc headers to `A, X, Y`; added a `SUSPENDED` early-return guard to
  the three render entry points.
- `diagnostics.s`: corrected the `diagPrintFatal` comment.
- `casm.s`: extended the `crpProgressHook` clobber note with the `CasmPtr0`
  caveat.

No behavioral change to any exercised path (the `SUSPENDED` guard is inert
in the current control flow).

## Re-verification

- **Full build** `cmake --build build`: exit 0, no toolchain errors, no
  envelope overflow anywhere (all 28 harnesses that link `progress.s`
  included). `casm.prg` `72549659...`, size 33368 -> 33398 (+30 bytes),
  `BUILD_CASM` 1378 -> 1379 (real code added). `$7400` MAIN still fits
  (Increment 7 measured 666 bytes headroom; +30 leaves ~636).
- **Exact no-change rebuild**: `casm.prg` hash unchanged, `BUILD_CASM`
  stays 1379.
- **`git diff --check`**: clean.
- **Live-VICE smoke** (VICE 3.10, `casm_progress_test.d64` re-attached on
  unit 8, `CASM V0.4.0.1379` banner confirmed):
  - `CASM CASMPG64.S` -> `P1/P2 DONE 00064`, `WRITE: casmpg64.prg`,
    `DONE: P1 00064, P2 00064, 00065 BYTES`, `CASM: INPUT VALIDATED` -
    byte-identical to the Increment 4 result.
  - `comp casmpg64.prg casmpg64.ref` -> `FILES COMPARE OK` (against the
    unchanged reference - output bytes are progress-independent).
  - `CASM CASMPG64.S /O:QL.PRG /M /L` -> `WRITE: ql.prg`, `SYMBOL MAP` +
    `000 SYMBOLS` printed cleanly, `DONE:` summary followed the map, no
    transient residue - the `SUSPENDED` guards did not perturb `/M`/`/L`
    screen ownership.

## Completion Gate

- [x] Every changed production file read line-by-line against the frozen ABI.
- [x] Finding register published with file:line references and dispositions.
- [x] In-scope findings (PR-1, PR-2, PR-4) fixed and re-verified; PR-3/PR-5
      recorded.
- [x] Full build + exact no-change rebuild clean; `git diff --check` clean.
- [x] Live-VICE smoke confirms no behavioral regression.
- [x] User approved closing Increment 9 (2026-08-31).
