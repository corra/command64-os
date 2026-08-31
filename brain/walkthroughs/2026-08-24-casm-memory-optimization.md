---
feature: casm-memory-optimization
plan: brain/plans/2026-08-24-casm-memory-optimization.md
taskwarrior: 42 (33d69dd5-c96b-4d3a-a27c-9fd93cc31de3)
status: awaiting user sign-off
completed: 2026-08-31
---

# Walkthrough: CASM Memory Optimization

Optional, size-only WP outside CASM's numbered phases. **Recovered 2,068
bytes of MAIN with a strict "identical observable behavior" contract** --
no change to assembled output, progress display, or diagnostic
text/behavior. MAIN stays `$7400` (Scoping Decision 4). Branch
`feature/casm-memory-optimization` off `main` `f4227cf`; ten
separately-committed increments.

## Envelope result

| | Increment 1 baseline | Final (Increment 10) |
| --- | --- | --- |
| `__MAIN_LAST__` | `$A97D` | `$A169` |
| MAIN headroom at `$7400` | 642 | **2,710** |
| Raw `ld65` CODE+RODATA | 25,320 B | 23,739 B (`-1,581`) |
| BSS segment | `$0E98` | `$0CB1` (`-487`) |
| Shipped `casm.prg` (relocatable) | 33,398 B | 31,517 B |

MAIN unchanged at `$7400`; the 2,068 bytes are banked as working headroom.

## The five findings, per increment

| Inc | Finding | Change | Saving |
| --- | --- | --- | --- |
| 3 | **D** | `CASM_FILENAME_MAX` / `CASM_INCLUDE_FILENAME_MAX` 63 -> 32; three dependent buffers shrunk; `cliInit` clear-loop bug fixed; asserts re-pinned | **482** |
| 4 | **E** | `progressPrintDec`'s five inline `PROG_DIGIT` expansions -> divisor-table loop | **108** |
| 5 | **A** | `diagDumpToken` + token-name tables gated behind `CASM_ENABLE_DIAG_DUMP_TOKEN` (default off) | **653** |
| 6 | **B** | `"CASM: "` prefix + trailing CR factored into `diagPrintMessage`; 89 strings stripped | **585** |
| 8 | **C** | six range tables + nine-way `cmp`/`beq` chain -> one dense 86-entry table + two-compare locationless test | **240** |
| | | **Total** | **2,068** |

Increments 1 (re-baseline), 2 (Finding D research), 7 (host-side verifier),
9 (live VICE), 10 (this closeout) carry no size change. Per-increment
detail is in the plan's own "Increment N" sections.

## Contract evidence

- **Assembled output unchanged.** Only `cli.s` (init-only clear loop),
  `common.inc` (constants), `diagnostics.s` (message display), `parser.s`
  (two `.assert` strings), `progress.s` (decimal formatting) were touched.
  **No emit-path file** (`emit.s`, `opcodes.s`, `expr.s`, `symbols.s`,
  `reloc.s`, `source.s`, `fileio.s`, `include.s` catalog, `lexer.s` core)
  was modified. Finding D changes only which filenames are *accepted*,
  never the bytes emitted for a program that assembles. Live: `casmpg128.s`
  reported `00129 BYTES` and `P1/P2 DONE 00128 STATEMENTS`, identical to
  the pre-WP build's output for the same fixture.
- **Diagnostic text unchanged.** `scripts/verify_casm_diag_table.py`
  decodes the linked `casm.prg` and confirms all 86 identifiers +
  `msgPhase2Ready`/`msgUnknown` render exactly their frozen text (the
  frozen table is a transcription of the Increment 1 baseline). Proven
  fault-detecting: `--self-test`, a real `msgOrgRequired` edit, and an
  across-former-range table-entry swap were each caught (build fails).
  Runs `POST_BUILD` on every `casm` build.
- **`progressPrintDec` unchanged.** Host-side model of the old macro and
  the new loop: **0 mismatches over all 65,536 values x both widths**.
- **Progress display unchanged.** Live `casmpg128.s` showed the full
  `P1/P2 START/DONE`, `WRITE:`, `DONE: P1 nnnnn, P2 nnnnn, nnnnn BYTES`,
  `CASM: INPUT VALIDATED` sequence in the identical format.

## Live VICE verification (Increment 9)

Command64 booted fresh; provenance proven by the on-screen
`CASM V0.5.x` banner. Seven runs, screen read from `$0400`:

| Diagnostic (id) | Former range | Behavior |
| --- | --- | --- |
| `BRANCH OUT OF RANGE` ($23) | `dpfMainRange` | locationed: msg + `AT LINE`/`COL` + source echo + `^` |
| `CIRCULAR CONSTANT DEFINITION` ($43) | ex-`beq` chain | **locationless: msg then prompt, NO location line** |
| `ALIGN BOUNDARY ZERO` ($4E) | ex-`dpfWp81` | locationed; `9:`-prefixed filename resolves (Finding D) |
| `ASSERTION FAILED: <text>` ($54 echo) | ex-`dpfWp83` special | prefix + lead-in + user text + CR + context |
| `INCBIN FILENAME EXPECTED` ($4F) | ex-`dpfWp82` | locationed + `LOC_BYTE` sub-path (`BYTE $6E`) |
| `FILENAME TOO LONG` ($09) | ex-`dpfMainRange` | fires at the new 32-char cap; clean exit |
| `INPUT VALIDATED` (success) | -- | full progress + success line unchanged |

5 of the 7 former dispatch groups exercised live; `$3D-$41` (listing I/O)
and `$55-$56` (progress checks) are fault-inject-only and fully
text-verified by the host-side verifier -- and `$3D-$41` share the exact
locationless code path proven by the `$43` run.

## Regression & rebuild (Increment 10)

- Full `cmake --build build` clean; every constant `.assert` across all 31
  `test_casm_*` harnesses passes.
- No-change rebuild stable: `BUILD_CASM` and all harness build counters
  hold; no source re-assembly.
- `casm_cliderive` and `casm_include` fixtures re-pinned to the cap-32
  boundary (the old ones poked 59-64-char names into now-33-byte buffers).
- Version promoted `0.5.0` -> `0.5.1`.

## Deferred (task 43, `5dad4e4f-8392-468f-8807-0ff37a98c33c`)

`diagPrintFatal`'s opening `jsr progressClearTransient` (added by
progress-indication Increment 7) reads **uninitialized `CasmProgFlags`**
for any diagnostic raised before `startPass1` runs `progressInit` -- every
`startInitFatal` path. If the garbage byte has bit 0 set,
`progressClearTransient` erases the current screen line, garbling the
banner on an early fatal exit (seen in the `FILENAME TOO LONG` run: banner
rendered as `CASM V`). **Confirmed byte-identical on `main`** -- Finding C
kept the call verbatim, did not introduce it. Disclosed and deferred per
the plan's stop condition ("a genuinely new defect outside this WP's
scope"). One-line fix candidate: clear `CasmProgFlags` after `sourceInit`
in `casm.s:start`, mirroring the existing `diagClearLoc` /
`listingStateInit` placement done for the identical "stale BSS at an early
fatal" reason. The diagnostic *text* is still correct; the defect is
cosmetic and pre-Pass-1 only.

## Completion gate

- [x] Re-baselined measurements recorded; final savings measured, not estimated (2,068 B).
- [x] Finding D's maximum-length evidence recorded (23 B reachable, cap 32); at-cap/over-cap fixtures (`casm_include` `validCap`/`tooLong`, `casm_cliderive` `cderboundary1`/`cderoverflow1`) build clean; over-cap `FILENAME TOO LONG` verified live.
- [x] Host-side verifier committed, proven fault-detecting, passing across every diagnostic ID (`POST_BUILD`).
- [x] Live evidence: 5/7 former dispatch ranges + both locationless sub-cases represented ($42/$43 live, $3D-$41 same path + host-verified); filename resolution at the new cap (`9:` prefix live, over-cap live).
- [x] Full build clean; no-change rebuild stable.
- [x] Assembled output unchanged (no emit-path file touched; live byte count matches pre-WP).
- [x] Envelope evidence recorded; MAIN still `$7400`.
- [ ] Trackers agree and the user explicitly approves closing this WP.

## Manual step for the user

Nothing further to run -- the live verification is complete. Please review
this walkthrough and the plan's per-increment sections, and confirm the WP
may be closed (Taskwarrior 42 -> done). Task 43 (the deferred
`CasmProgFlags` defect) stays open as its own follow-up.
