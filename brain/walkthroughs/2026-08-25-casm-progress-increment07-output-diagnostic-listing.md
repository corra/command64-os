# CASM Progress Increment 7 Output, Diagnostic, Listing, And Map Walkthrough

Status: COMPLETE -- user-approved 2026-08-26

Plan: `brain/plans/2026-08-24-casm-progress-increment07-output-diagnostic-listing.md`

## Atomic Increment 1

The candidate counts physical primary-artifact bytes only after successful
writes at the three approved boundaries:

- `emitFlush` body/header/final-buffer writes;
- each relocation-table chunk;
- the six-byte R6 footer.

No renderer, throttle, listing/map hook, diagnostic hook, or orchestration
ordering change exists yet.

Build evidence:

- production `casm`: 25,249 code bytes, 4,023 relocations; 4,447 bytes remain
  in `$7400`;
- `test_casm_bounds`: 1,913/336; pass;
- `test_casm_directives`: 2,810/507; pass;
- `test_casm_reloc`: 1,926/303; pass;
- `test_casm_freloc`: 1,528/220; pass;
- `test_casm_pass1`: exceeded `$6800` by 12 bytes; the user-approved `$6900`
  envelope is the smallest round-page fit and now passes;
- passcheck, frame, listcap, faultsource, and spanread retain their envelopes;
- aggregate and exact no-change builds pass for production `casm` and all
  directly affected focused harnesses;
- `git diff --check`: pass.

Live VICE evidence used VICE 3.10 with freshly reattached images and a fresh
Command64 boot proven by screen RAM before each image's tests:

- `build/test.d64`: `test_casm_reloc` displayed `CASM RELOC: PASS`;
- `build/test.d64`: `test_casm_progress` displayed `CASM PROGRESS: PASS`, with
  final summaries including `00150 BYTES` and `00010 BYTES`;
- `build/casm_include_test.d64`: `test_casm_directives` displayed
  `CASM DIRECTIVES: PASS`;
- `build/casm_phase12_test.d64`: `test_casm_pass1` displayed
  `CASM PASS1: PASS` after its 122-block load.

Each harness returned to the `c64[8]:>` shell prompt. No recovery was needed,
and the healthy emulator remains running with `casm_phase12_test.d64` attached
to unit 8.

Atomic Increment 1 is verified but remains in progress until explicit user
approval.

## Atomic Increments 2-6

Implementation detail for these lives in the plan's Progress log
(`brain/plans/2026-08-24-casm-progress-increment07-output-diagnostic-listing.md`).
Summary of what shipped:

- **2** -- no code. The plan's throttled output-write redraw conflicted with
  the parent plan's standing amendment dropping it; the user chose to keep it
  dropped, and Atomic Increment 1 already satisfied the remaining substance.
- **3** -- `WRITE: <name>` persistent line, printed after listing finalization
  and before `emitFinalize`.
- **4** -- universal transient clear at `diagPrintFatal` entry, with the
  diagnostic identifier stashed across the call (`pha`/`jsr`/`pla`).
  `diagnostics.s` imports exactly one routine from `progress.s`
  (`progressClearTransient`); `progress.s` imports nothing back. That one-way
  edge was pre-declared in `progress.s`'s own header before this increment
  began and is honored as written.
- **5** -- `progressSuspend` before `listingWriteFile` (`/L`) and before
  `mapPrint` (`/M`).
- **6** -- `progressFinalSummary` immediately before `diagPrintPhase2Ready`.
  The plan said "replace" the success text, but `CASM: INPUT VALIDATED` is the
  documented success signal in the user manual; the user chose to keep both,
  summary first. `docs/casm-utility.md` and `wiki/casm-utility.md` updated;
  `release/docs/` deliberately untouched (versioned release snapshot, still
  `0.3.0`).

Four branch-range overflows surfaced while adding this code (three in
Atomic Increment 3, one in Atomic Increment 5) as existing `bcs` targets in
`casm.s` were pushed out of 8-bit relative range. Each was fixed by rerouting
the failing check through the existing `startFatalNear2` trampoline -- the
established pattern in this codebase, with no new trampoline introduced.

## Atomic Increment 7: Regression Sweep And Option Identity

Full detail is in the plan's Progress log. Headline results:

**31 harnesses across 6 CMake-built disk images, zero failures** --
`test.d64` (5), `casm_listing_test.d64` (11), `casm_overflow_test.d64` on
unit 9 (3), `casm_include_test.d64` (9), `casm_phase12_test.d64` (2),
`casm_phase13_test.d64` (1). `test_casm_progress` printed its own
`DONE: P1 00001, P2 00001, 00010 BYTES` and passed.

**Two false failures, both my own test disks.** An ad-hoc sweep image built
for this pass omitted fixtures, producing spurious FAILs in
`test_casm_faultsource` and `test_casm_spanread`. Established by evidence,
not inference: a non-stopping checkpoint at `diagPrintFatal` recorded **zero
hits**, and `vice_run_until` stopped at `writeFailureCleansCentrally`'s
comparison with `A=$0B` (`CASM_DIAG_INPUT_OPEN_FAILED`), not the expected
`$2B`. Both harnesses pass on the CMake images that carry their fixtures.
The ad-hoc images were discarded. **`casm_overflow_test.d64` and
`command64_casm_utils.d64` carry no `COMMAND64` and are not bootable** --
the overflow disk must be attached on unit 9 behind a `test.d64` boot.

**Option identity holds.** Default, `/M`, `/L`, `/M /L`, and `/S` all produce
`FILES COMPARE OK` against `casmopall.ref`, upholding the invariant stated at
`docs/casm-utility.md` that output bytes are identical whether or not `/M`/`/L`
are given. `optc.lst` and `optd.lst` are both 33 blocks, so `/M` does not
perturb `/L`. `casmreloc1.s` and `casmfa2p.s` also compared OK.

**`/M` screen ownership is clean** -- the symbol map and its `008 SYMBOLS`
trailer printed with no transient residue before, inside, or after, and the
`DONE:` summary followed the map rather than being overwritten.

## Atomic Increment 8: Size, Performance, No-Change

Measured against `CASM 0.4.0` build `1378`, `casm.prg` sha256
`af1bacdab72a40bf20983a8676592873d76b0bd74d2b6c0b68155b6f7c3d819c`.

### Envelope

`ld65 -Ln` against `build/build_casm_cfg/casm_3800.cfg`:

| Field | Value |
|---|---|
| `__MAIN_START__` | `$3800` |
| `__MAIN_SIZE__` | `$7400` (29,696 bytes) |
| `__MAIN_LAST__` | `$A966` |
| Used | `$7166` (29,030 bytes) |
| **Headroom** | **666 bytes (2.24%)** |

Unchanged from Atomic Increment 6's recorded 666 bytes -- Atomic Increment 7
added no code, and Atomic Increment 8 adds none.

### No-change build and cleanliness

- Targeted no-change rebuild of `casm`: `casm.prg` sha256 **unchanged**,
  `BUILD_CASM` still **1378** (the content-hash gate correctly declined to
  increment).
- Full `cmake --build build`: **exit 0**, zero real toolchain errors. (A naive
  `grep -i overflow` matches 13 lines, but every one is the substring in the
  disk-image *name* `casm_overflow_test.d64`, not a diagnostic -- checked
  rather than assumed.)
- `git diff --check`: clean.

### Performance

**Wall-clock times in this session are not comparable to the Increment 1
baseline**: `vice_machine_config_get` reports `WarpMode: 1`, so wall time is
compressed (the 160-statement run took 10.1s wall). All figures below are
**emulated PAL CPU cycles** via `vice_cycles_stopwatch`, which are
warp-independent, converted at 985,248 cycles/sec.

| Fixture | Statements | Emulated time |
|---|---|---|
| `casmfa2p.s` | 4 | 95.24s |
| `casmopall.s` | 160 | 104.76s |
| `casmbiga.s` + `casmbigb.s` (run 1) | 6,001 | 258.70s |
| `casmbiga.s` + `casmbigb.s` (run 2) | 6,001 | 255.41s |

Run-to-run variance on the large fixture is 3.3s (1.3%).

Against the Increment 1 pre-progress baseline for the same large fixture
(228.14s wall, recorded without warp), the mean 257.06s is **+28.9s
(+12.7%)** end-to-end. That figure is *not* all progress overhead:
`casm.prg` grew from 31,185 bytes at baseline to 33,368 bytes now (+2,183,
+7%), covering Phase 13 and the whole progress feature, and its own
true-drive-emulation load time grew with it -- visible directly in the floor,
which moved from the baseline's 82-88s cluster to 95.24s. Subtracting that
floor growth leaves roughly +18-24s spread across 12,002 statement events
(6,001 statements x 2 passes), on the order of 1.5-2.0ms per event.

The measurement brackets differ slightly between baseline and now (the
baseline timed dispatch-to-`VALIDATED`; this harness includes stopwatch reset,
subprocess spawn, and up to 0.5s poll granularity), so these figures are
reported as an end-to-end envelope, not a precise per-statement cost.

### Performance acceptance thresholds are NOT yet demonstrated met

The parent plan's Performance Budget sets hard acceptance thresholds:
**no more than 5% elapsed-time regression on the representative large
fixture, and no more than 10% on the short-statement stress fixture**, with
the instruction to *"stop and redesign if either threshold is exceeded"* and
not to weaken them without a plan amendment and explicit approval.

Measured raw end-to-end against Increment 1's recorded baselines, both are
exceeded:

| Fixture | Role | Baseline | Now | Delta | Cap | Verdict |
|---|---|---|---|---|---|---|
| `casmbiga.s`+`casmbigb.s` | representative large | 228.14s | 257.06s | **+12.7%** | 5% | **over** |
| `casmopall.s` | short-statement stress | 87.74s | 104.76s | **+19.4%** | 10% | **over** |

**These numbers do not yet isolate the progress feature, and should not be
read as proof the feature breaches its budget.** Three confounds are known
and material:

1. `casm.prg` grew 31,185 -> 33,368 bytes between baseline and now, covering
   **Phase 13 as well as** this feature. Under true-drive emulation that is
   pure added load time, charged to every run regardless of statement count.
   It is directly visible in the floor moving from the baseline's 82-88s
   cluster to 95.24s -- roughly +8-13s, which alone accounts for most of the
   `casmopall.s` delta.
2. The baseline was recorded as wall time without warp; this session has
   `WarpMode: 1`, so cycles were used instead. Comparing cycles to wall is
   only valid to the extent the baseline session was not itself throttled.
3. The measurement brackets differ, as described above.

**What this requires:** a like-for-like isolation before the feature can
claim its budget -- a pre-progress `casm.prg` built from the merge-base and
timed in the *same* VICE session, same warp setting, same bracket, as the
current build. Until that is done, the acceptance thresholds are recorded as
**not demonstrated**, and the corresponding tracker checkbox stays open. This
is flagged rather than resolved here because Increment 7's own Completion
Gate covers correctness, ordering, and regression -- not the feature-level
performance budget, which belongs to the feature's own completion gate
(master-plan Increment 11).

### Byte-accounting cross-checks

The summary's reported byte count was checked against each reference's real
host-side file size across four output shapes -- static, R6-relocatable,
minimal, and at scale:

| Fixture | Reported | Reference size | Match |
|---|---|---|---|
| `casmopall.s` | `00323 BYTES` | `casmopall.ref` 323 | exact |
| `casmreloc1.s` | `00044 BYTES` | `casmreloc1.ref` 44 | exact |
| `casmfa2p.s` | `00006 BYTES` | `casmfa2p.ref` 6 | exact |
| `casmbiga.s`+`casmbigb.s` | `06002 BYTES` | `casmbig1.ref` 6002 | exact |

This exercises both `emit.s`'s and `reloc.s`'s accumulate call sites.

### Incidental production evidence for Atomic Increment 4

An early large-fixture timing attempt ran on a copy of
`casm_overflow_test.d64` that had only 2 blocks free, and CASM correctly
reported `CASM: OUTPUT WRITE FAILED` / `IN FILE casmbiga.s` /
`AT LINE 1, COL 6 (OFFSET 5)`. Not a defect -- but it is a real production
fatal diagnostic raised with progress active, and it printed cleanly after
`P2: START` with no transient residue ahead of the diagnostic text or its
source context. That is Atomic Increment 4's universal clear working outside
a purpose-built fixture. The run was rebuilt on a disk with free space for
the actual timing figures above.

## Status

Atomic Increments 1-8 are implemented, verified, and **closed with explicit
user approval on 2026-08-26**. Increment 7 is complete and its Completion Gate
is satisfied. Next: master-plan Increment 8 (automated verification).
