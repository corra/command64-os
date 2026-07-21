---
feature: casm-phase4-wp15-phase-verification-closeout
created: 2026-07-21
status: in-progress
---

# Walkthrough: CASM Phase 4 WP15 Verification and Phase Closeout

Plan: `brain/plans/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`
Taskwarrior: `8612c2a2-afdd-4c8f-bf42-4947bc486f97`
Phase 4 milestone: `4796b60c-5f4a-43c7-8270-436075bb3f7b`

**Status: awaiting the user's runtime session (increment 9).** Every host-side
gate below has passed. Phase 4 is not closed and must not be marked closed until
the manual section is executed and separately approved.

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
set. See the G7 hazard below for the one case where that last condition is
load-bearing.

## Increment 7 — version advance (D1)

`VERSION_STAGE` `"16"` -> `"17"`. `BUILD_CASM` advanced **exactly once**,
1078 -> 1079, then held stable across an immediate no-change rebuild.

Code size and relocation count are unchanged at 8705 / 1172 — the version
string is the same length, so the artifact layout is untouched. Banner verified
by byte inspection of the artifact and of the CASM copy on both disk images:
PETSCII `C3 C1 D3 CD 20 D6` + `0.1.17.1079`, i.e. `CASM V0.1.17.1079`. The CASM
file on `image.d64` and `test.d64` is byte-identical to `build/casm.prg`.

---

# Manual Runtime Session (increment 9) — PENDING

Run on the supported local emulator or hardware from `test.d64`. The broken
`c64-testing` MCP and web emulators are prohibited; these steps are yours to
execute. Record the observed result for every row, including passes.

## S. Smoke set (D3)

| Step | Command | Expected | Observed |
|---|---|---|---|
| S1 | Run `CASM` with no argument | Banner `CASM V0.1.17.1079`, then a clean missing-source diagnostic; shell returns | |
| S2 | `CASM CASMEMIT1` | `INPUT VALIDATED`, output `CASMEMIT1.PRG` | |
| S3 | `COMP CASMEMIT1.PRG CASMEMIT1.REF` | files identical | |
| S4 | `CASM CASMHELLO` | `INPUT VALIDATED`, output `CASMHELLO.PRG` | |
| S5 | `COMP CASMHELLO.PRG CASMHELLO.REF` | files identical | |
| S6 | `CASM CASMMODES` | `INPUT VALIDATED`, output `CASMMODES.PRG` | |
| S7 | `COMP CASMMODES.PRG CASMMODES.REF` | files identical | |
| S8 | Load and run `CASMHELLO.PRG` | prints `YES IT BUILDS! -- CASM`, returns to shell | |
| S9 | `CASM CASMEMIT1 /O TESTOUT` | output named `TESTOUT.PRG` | |
| S10 | `CASM CASMEMIT1 /S` | `/S` behaviour matches the default output behaviour | |
| S11 | `CASM CASMEMIT1 /M` | map option handled; **no partial output left behind** | |
| S12 | `CASM CASMEMIT1 /L` | listing option handled; **no partial output left behind** | |

## T. Shell integrity

| Step | Command | Expected | Observed |
|---|---|---|---|
| T1 | `DIR` after the above | directory lists correctly, no lost/open files | |
| T2 | Run another external app (e.g. `COMP` with no args) | runs and returns normally | |
| T3 | `CASM CASMAM1` (a failing fixture), then `CASM CASMEMIT1` twice | failure diagnoses cleanly; both later runs succeed; no handle leak | |

## G4.2 — the `casmzpi2` diagnostic (WP14 gap)

Fixture: `.ORG $C000` / `LDA ($100,X)` — indexed-indirect with a >8-bit operand.

**Static prediction.** `parseNumericValue` accepts `$100` (it only rejects
>65535). `opcodesFindOpcode` routes `CASM_OPKIND_INDEXED_INDIRECT` through
`ofRequire8Bit`, which fails and jumps to `ofRangeError`, raising
`CASM_DIAG_OPERAND_OUT_OF_RANGE` (`$1E`), message text
`CASM: OPERAND OUT OF RANGE`.

| Step | Command | Predicted | Observed |
|---|---|---|---|
| G4.2 | `CASM CASMZPI2` | `CASM: OPERAND OUT OF RANGE`, source position line 2 | |

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
| G7.1 | `CASM CASMEMIT1` twice in a row | second run fails rather than silently replacing | |
| G7.2 | After the failure, `DIR` | **check whether `CASMEMIT1.PRG` still exists** | |
| G7.3 | If it exists, `COMP CASMEMIT1.PRG CASMEMIT1.REF` | still identical, i.e. the original survived intact | |

If G7.2 shows the pre-existing file was deleted, that is a **stop condition**:
it goes to RCA and a separately approved remediation plan. WP15 must not patch
it, and Phase 4 must not be marked done until it is resolved.

---

## Completion Gates — both PENDING

1. **WP15 completion** — requires every gate above to pass and your explicit
   approval to mark WP15 complete.
2. **Phase 4 completion** — a *separate* explicit confirmation that the phase is
   done. Approving the runtime matrix does not imply either.

Phase 5 remains planned and blocked behind gate 2. On closure, the WP16 plan's
`0.1.16` / build-1078 baseline must be amended to `0.1.17` / 1079.

## Progress

- 2026-07-21: Increments 1-8 complete. Three record defects found and fixed in
  increment 2. Version advanced to `0.1.17` build 1079. Awaiting the user's
  runtime session for increment 9, including two static predictions to confirm
  or falsify (G4.2 diagnostic identity, G7 pre-existing-output deletion hazard).
