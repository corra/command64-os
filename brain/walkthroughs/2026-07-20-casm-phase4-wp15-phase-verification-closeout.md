---
feature: casm-phase4-wp15-phase-verification-closeout
created: 2026-07-21
status: complete
---

# Walkthrough: CASM Phase 4 WP15 Verification and Phase Closeout

Plan: `brain/plans/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`
Taskwarrior: `8612c2a2-afdd-4c8f-bf42-4947bc486f97`
Phase 4 milestone: `4796b60c-5f4a-43c7-8270-436075bb3f7b`

**Status: COMPLETE.** Every automated and manual gate passed. WP15 is closed and
**CASM Phase 4 is complete, approved by the user on 2026-07-21** at
`CASM V0.1.17.1079`. Phase 5 is unblocked.

## Repository State

| Item | Value |
|---|---|
| Branch | `feature/casm-phase4-wp15` |
| Branched from | `main` at `55fe474` (WP14 merge) |
| Working tree at activation | clean |
| CASM version | `0.1.17` (advanced from `0.1.16` during increment 7) |
| `BUILD_CASM` | 1079 (was 1078) |
| Banner | `CASM V0.1.17.1079` |
| `casm.prg` sha256 | `c27b2e21c3562cf2dd523018dd1291f0123569fe5e28da6357289f2a53f3cc36` |

## Activation Decisions

Four decisions were taken at activation and are recorded in full in the plan:

- **D1** — the `0.1.16` -> `0.1.17` bump is retained and moved *before* the
  manual walkthrough, so the runtime session runs once against the artifact that
  actually ships.
- **D2** — branch and clean baseline as above.
- **D3** — reduced manual smoke set; WP14's 23-fixture matrix stands as evidence
  for the syntax, addressing, numeric, branch, PC, and directive gates.
- **D4** — WP14's two unrecorded observations (G4.2, G7.1-G7.3) are captured here.

## Increment 1 — WP14 closure verified

| Check | Result |
|---|---|
| Taskwarrior `3e4eab43` | Completed 2026-07-21, annotated with the full result |
| Walkthrough | `brain/walkthroughs/2026-07-20-casm-phase4-wp14-orchestration-binary-validation.md` |
| Wiki record | `wiki/tasks/casm.md` ticked, real UUID, approval date recorded |
| `brain/task.md` | WP14 ticked with all nine increments |

## Increment 2 — record reconciliation

Three genuine defects were found and corrected. This is the increment that
justified WP15 existing as an independent audit rather than a formality.

1. **No Phase 4 parent milestone existed.** Phases 1, 2, and 3 each had a parent
   Taskwarrior record (`13a45324`, `df2f766c`, `099257cc`); Phase 4 had none, so
   WP11-WP15 were orphaned with no milestone to roll up into. Created
   `4796b60c-5f4a-43c7-8270-436075bb3f7b`. The completed Phase 3 UUID
   `099257cc` was deliberately **not** reused, per the plan.

2. **Three phantom wiki UUIDs.** `wiki/tasks/casm.md` cited `31bb2198` (WP11),
   `501bc58c` (WP12), and `83ab4f2d` (WP13). None of the three exists in
   Taskwarrior at all. Replaced with the real `82a11475`, `a3f90f05`, `ded1cfd9`.
   WP14's earlier UUID repair had covered only WP14 and WP15, so this defect
   survived it.

3. **Stale Phase 3 milestone text.** The `wiki/tasks/casm.md` header still
   declared `Taskwarrior: 29 (099257cc)` with the Phase 3 plan and a Phase 3
   "Current Milestone" paragraph, and `brain/task.md` still marked the completed
   Phase 3 milestone `[/]`. Both now describe Phase 4.

No Phase 4 acceptance box was ticked during this increment. The single
completion-box change (Phase 3 `[/]` -> `[x]`) is a record-truth correction to a
phase approved on 2026-07-17, annotated inline as such.

## Increment 3 — clean baseline

- Commit at capture: `d75adca`; tree carried only the two record files under edit.
- Source manifest: 11 `.s` files plus `common.inc` under `src/external/casm/`.
- Combined source sha256:
  `b8ee6472cac344c71b8f9a5545d67d5eea0e9da0db4e8e452225212bba66e1a6`.

## Increment 4 — build, link maps, artifact

The build emits no link maps, so both were generated out-of-tree with
`ld65 -m` against the same objects and configs the build used. This is a
read-only reproduction and does not perturb the build.

| Segment | `$3400` build | `$3500` build |
|---|---|---|
| CODE | `003400`-`004E40`, `$1A41` | `003500`-`004F40`, `$1A41` |
| RODATA | `004E41`-`005600`, `$07C0` | `004F41`-`005700`, `$07C0` |
| BSS | `005601`-`005A67`, `$0467` | `005701`-`005B67`, `$0467` |

Envelope: MAIN is `start = $3400 / $3500, size = $2800` (10240 bytes).
Occupied 9832 bytes in both configurations. **Headroom 408 bytes (`$198`)**,
identical for both, confirming the relocation pair is size-stable.

R6 artifact, cross-checked field by field:

| Field | Value | Cross-check |
|---|---|---|
| Load address | `$3400` | matches base link |
| Code + RODATA | 8705 | `$1A41` + `$07C0` = 6721 + 1984 |
| Relocation table | 2344 bytes | 1172 points x 2 |
| Footer | base `$3400`, count `$0494` = 1172, magic `R6` | matches reloc.py |
| Total | 11057 | 2 + 8705 + 2344 + 6 |

No-change rebuild held `BUILD_CASM` at 1078 (pre-bump), satisfying the "a
no-change build does not increment `BUILD_CASM`" gate.

## Increment 5 — disk images and reference provenance

`image.d64` — 9 entries: COMMAND64, DEBUG, LABEL, FORMAT, COMP, **CASM**, EDLIN,
CONWAY, PACMAN. All shipping applications present.

`test.d64` — 82 entries: the 9 applications, 12 test PRGs, RELOC,
CA65-APP-SMOKETEST, the 3 trusted `.ref` PRGs, and 57 `.seq` fixtures. Fixture
retention confirmed.

Reference chain verified **end to end by independent transcription** — a parser
written for this audit, not the project's `hex_manifest_to_bin.py`, so a defect
in that script could not hide:

| Reference | Manifest | Built | On `test.d64` |
|---|---|---|---|
| `casmemit1.ref` | 20 B | 20 B match | match |
| `casmhello.ref` | 40 B | 40 B match | match |
| `casmmodes.ref` | 30 B | 30 B match | match |

Non-circularity confirmed: no manifest derives bytes from `opcodes.s`.
`casmmodes.ref.hex` names the file only to disclaim it explicitly, recording
that `opcodes.s` was diffed against the reference afterwards as an independent
cross-check rather than as a source.

## Increment 6 — static acceptance audit

**Carry and decimal mode.** All 52 `ADC`/`SBC` sites were enumerated
mechanically and each traced back to its carry setup. 52/52 establish carry
explicitly or continue a multi-byte chain. The single site flagged by the scan,
`source.s:659`, is the canonical unsigned 16-bit compare (`cmp` lo / `lda` hi /
`sbc` hi), where `cmp` sets carry correctly. No `SED` appears anywhere in CASM.

*Observation, not a defect:* CASM contains no `CLD` at entry either, so it
relies on the caller leaving decimal mode clear. Universal for C64 code and
guaranteed by the shell, but worth noting against the Phase 5 contract's
"decimal mode is never assumed" wording.

**Stack.** Raw `pha`/`pla` counts are asymmetric in `lexer.s` (4/5) and
`fileio.s` (1/2). Every asymmetry is the two-exit pattern: one push with
mutually exclusive success and failure pops (`lnPunct`/`lnPunctAppendFail`,
`oaRecordSecondary`/`oaKeepPrimary`). All `php`/`plp` pairs balance.

**Diagnostic preservation.** `oaRecordSecondary` stores a secondary diagnostic
only when `CasmFilePrimary` is zero, so the original primary always survives
cleanup — direct evidence for the "retain the original primary diagnostic" gate.

**Output lifecycle.** Every failure path in the driver funnels through one
`startFatal` choke point, which calls `outputAbort` before `exitFatal`.
`outputAbort` closes the handle, records a close failure as secondary without
clobbering the primary, and deletes the output only when `CasmOutputCreated` is
set. See the G7 analysis below: runtime confirmed no data loss, but that
condition turns out not to be what protects the file.

## Increment 7 — version advance (D1)

`VERSION_STAGE` `"16"` -> `"17"`. `BUILD_CASM` advanced **exactly once**,
1078 -> 1079, then held stable across an immediate no-change rebuild.

Code size and relocation count are unchanged at 8705 / 1172 — the version
string is the same length, so the artifact layout is untouched. Banner verified
by byte inspection of the artifact and of the CASM copy on both disk images:
PETSCII `C3 C1 D3 CD 20 D6` + `0.1.17.1079`, i.e. `CASM V0.1.17.1079`. The CASM
file on `image.d64` and `test.d64` is byte-identical to `build/casm.prg`.

---

# Manual Runtime Session (increment 9) — COMPLETE, ALL PASS

Executed by the user on 2026-07-21 against `CASM V0.1.17.1079` from `test.d64`.
**Every step passed.** The two open WP14 observations are now recorded, closing
the D4 gap.

Summary of the two predictions:

- **G4.2 — confirmed.** The static prediction held.
- **G7 — falsified, in the safe direction.** CASM does **not** clobber or
  corrupt an existing output file. The predicted deletion does not occur. The
  mechanism is analysed below, because the reason it is safe is not the reason
  the code appears to be safe, and that distinction matters for Phase 5+.

## G7 root-cause analysis (prediction falsified)

The prediction was that assembling over an existing output would delete the
original. It does not. Tracing the actual path:

1. `fileOpen` builds `NAME,P,W` with **no `@` replace prefix** — as predicted.
2. `fileOpen` **skips error-channel verification for write-mode opens**
   (`src/command64/file.asm:207-208`, `lda OpenMode / bne foSkipReadVerify`).
   The read path checks LFN 15 for a `"00"` status; the write path does not.
   So the open returns a valid handle with `63,FILE EXISTS` latched on the
   drive's error channel — also as predicted.
3. The write consequently fails and CASM raises, routing through `startFatal`
   -> `outputAbort` — as predicted.
4. **Where the prediction broke:** `outputAbort` does reach `fileDelete` with
   `CasmOutputCreated` set, but `fileDelete` calls `checkDeviceReady`
   (`src/command64/file.asm:503`), which reads the error channel first. The
   latched `63,FILE EXISTS` is a non-`"00"` status, so the preflight bails and
   `fileDelete` returns carry set. `outputAbort` records that as a *secondary*
   diagnostic via `oaRecordSecondary`, preserving the primary, and returns
   **without deleting**.

The user's file is therefore safe — but it is saved by the stale drive error
status blocking the delete, not by CASM declining to delete a file it did not
create. `CasmOutputCreated` is set for a file CASM merely opened. The safety
depends on the drive still holding a non-`"00"` status at the moment
`fileDelete` runs.

**This is not a WP15 defect and not a Phase 4 blocker** — the observable
behaviour is correct and no data is lost. It is recorded here as a latent
fragility worth hardening later: `fileCreateOutput` should distinguish "created"
from "opened an existing file", so the delete decision does not rely on drive
error state. Filed as an observation for the Phase 11 hardening pass rather than
remediated here, since WP15 may not patch production code and no failure is
observable today.

## Detailed results

Run on the supported local emulator or hardware from `test.d64`. The broken
`c64-testing` MCP and web emulators are prohibited; these steps are yours to
execute. Record the observed result for every row, including passes.

## S. Smoke set (D3)

| Step | Command | Expected | Observed |
|---|---|---|---|
| S1 | Run `CASM` with no argument | Banner `CASM V0.1.17.1079`, then a clean missing-source diagnostic; shell returns | pass |
| S2 | `CASM CASMEMIT1` | `INPUT VALIDATED`, output `CASMEMIT1.PRG` | pass |
| S3 | `COMP CASMEMIT1.PRG CASMEMIT1.REF` | files identical | pass |
| S4 | `CASM CASMHELLO` | `INPUT VALIDATED`, output `CASMHELLO.PRG` | pass |
| S5 | `COMP CASMHELLO.PRG CASMHELLO.REF` | files identical | pass |
| S6 | `CASM CASMMODES` | `INPUT VALIDATED`, output `CASMMODES.PRG` | pass |
| S7 | `COMP CASMMODES.PRG CASMMODES.REF` | files identical | pass |
| S8 | Load and run `CASMHELLO.PRG` | prints `YES IT BUILDS! -- CASM`, returns to shell | pass |
| S9 | `CASM CASMEMIT1 /O TESTOUT` | output named `TESTOUT.PRG` | pass |
| S10 | `CASM CASMEMIT1 /S` | `/S` behaviour matches the default output behaviour | pass |
| S11 | `CASM CASMEMIT1 /M` | map option handled; **no partial output left behind** | pass |
| S12 | `CASM CASMEMIT1 /L` | listing option handled; **no partial output left behind** | pass |

## T. Shell integrity

| Step | Command | Expected | Observed |
|---|---|---|---|
| T1 | `DIR` after the above | directory lists correctly, no lost/open files | pass |
| T2 | Run another external app (e.g. `COMP` with no args) | runs and returns normally | pass |
| T3 | `CASM CASMAM1` (a failing fixture), then `CASM CASMEMIT1` twice | failure diagnoses cleanly; both later runs succeed; no handle leak | pass |

## G4.2 — the `casmzpi2` diagnostic (WP14 gap)

Fixture: `.ORG $C000` / `LDA ($100,X)` — indexed-indirect with a >8-bit operand.

**Static prediction.** `parseNumericValue` accepts `$100` (it only rejects
>65535). `opcodesFindOpcode` routes `CASM_OPKIND_INDEXED_INDIRECT` through
`ofRequire8Bit`, which fails and jumps to `ofRangeError`, raising
`CASM_DIAG_OPERAND_OUT_OF_RANGE` (`$1E`), message text
`CASM: OPERAND OUT OF RANGE`.

| Step | Command | Predicted | Observed |
|---|---|---|---|
| G4.2 | `CASM CASMZPI2` | `CASM: OPERAND OUT OF RANGE`, source position line 2 | **pass — prediction confirmed** |

A different diagnostic is a finding, not a reason to amend the prediction.

## G7.1-G7.3 — assembling over an existing output file (WP14 gap)

**This is the one step that could destroy data. Use a scratch disk copy.**

**Static prediction, and why it matters.** No `@` replace prefix appears
anywhere in the OS, so `DOS_OPEN_FILE` in write mode against an existing PRG
meets CBM DOS *FILE EXISTS* (63). The KERNAL `OPEN` itself still succeeds, so
`fileCreateOutput` proceeds to set `CasmOutputCreated = CASM_OUTPUT_CREATED`.
The first write then fails, raising through `startFatal` -> `outputAbort`, and
`outputAbort` deletes the output name **because `CasmOutputCreated` is set** —
even though CASM never actually created that file. The predicted net effect is
that a failed re-assembly **scratches the user's pre-existing file**.

| Step | Command | Predicted | Observed |
|---|---|---|---|
| G7.1 | `CASM CASMEMIT1` twice in a row | second run fails rather than silently replacing | pass — second run reported an error |
| G7.2 | After the failure, `DIR` | **check whether `CASMEMIT1.PRG` still exists** | pass — file still present, not deleted |
| G7.3 | If it exists, `COMP CASMEMIT1.PRG CASMEMIT1.REF` | still identical, i.e. the original survived intact | pass — original intact, not corrupted |

If G7.2 shows the pre-existing file was deleted, that is a **stop condition**:
it goes to RCA and a separately approved remediation plan. WP15 must not patch
it, and Phase 4 must not be marked done until it is resolved.

---

## Phase 4 Acceptance Matrix — result

| Gate | Evidence | Result |
|---|---|---|
| Parser and delimiter | WP14 23-fixture matrix (D3 standing evidence); T3 rerun | pass |
| Opcode and sizing | WP14 matrix plus `casmmodes.ref` per-mode certification (S6/S7) | pass |
| Branch and PC | WP14 matrix (`casmbrp1/2`, `casmbrn1/2`, `casmpcend`, `casmpcovf`) | pass |
| Output and resource | S2-S12, T1-T3, G7.1-G7.3; no-change build held `BUILD_CASM` | pass |
| Envelope and release | Increments 4-5: 408 B headroom both configs; both disks verified | pass |

## Completion Gates — both SATISFIED

1. **WP15 completion** — approved. Taskwarrior `8612c2a2` closed 2026-07-21.
2. **Phase 4 completion** — separately approved by the user on 2026-07-21.
   Milestone `4796b60c` closed; `project:command64.casm` is 37/37 complete.

Records synchronized: `wiki/tasks/casm.md` (all seven Phase 4 acceptance items
ticked), `brain/task.md`, `CHANGELOG.md`, `brain/MEMORY.md`, and both Phase 5
plans (the WP16 `0.1.16` / build-1078 baseline amended to `0.1.17` / 1079).

`brain/KNOWLEDGE.md` was deliberately **not** given a retroactive CASM Phase 4
contract section, per the WP16 plan's Finding 4 — authoring one now would create
a second source of truth for a closed phase. Deferred to Phase 11.

## Carried-Forward Observations

Neither blocks Phase 4; both are recorded so they are not rediscovered later.

1. **`CasmOutputCreated` conflates created with opened.** See the G7 analysis.
   The pre-existing file survives because a latched drive error blocks the
   delete, not because CASM declines to delete a file it did not create.
   Suggested for the Phase 11 hardening pass.
2. **No `CLD` at entry.** CASM contains no `SED` and every `ADC`/`SBC` path
   establishes carry, but it assumes the caller left decimal mode clear. Worth
   reconciling against the Phase 5 contract's "decimal mode is never assumed"
   wording.
3. **No CASM Phase 4 contract section in `brain/KNOWLEDGE.md`.** Phases 1-3 have
   one; Phase 4 does not. Deliberately not authored retroactively here, per the
   WP16 plan's Finding 4. Deferred to Phase 11 documentation hardening.

## Progress

- 2026-07-21: Increments 1-8 complete. Three record defects found and fixed in
  increment 2. Version advanced to `0.1.17` build 1079.
- 2026-07-21: Increment 9 complete. User executed the full session; **all steps
  pass**. G4.2 confirmed the static prediction. G7 **falsified** it in the safe
  direction — no clobbering or corruption of an existing output file — and the
  root cause was traced to `fileDelete`'s `checkDeviceReady` preflight bailing on
  the latched `63,FILE EXISTS` status. Both WP14 evidence gaps are now closed.
  Awaiting the two approval gates.
- 2026-07-21: **WP15 complete and Phase 4 approved done** by the user at CASM
  `0.1.17` build 1079. Both gates satisfied, all records synchronized, Phase 5
  unblocked.
