---
feature: casm-phase6-wp22-prerequisite-reconciliation
created: 2026-07-21
status: complete
---

# Walkthrough: CASM Phase 6A WP22 Prerequisite Reconciliation

Plan: `brain/plans/2026-07-21-casm-phase6-wp22-prerequisite-reconciliation.md`

Taskwarrior: `eb7541e5-c3aa-4528-bdcd-2571d96688d9`

## Outcome

WP22 researched and froze the Phase 0C.4 VMM record contract directly against
the OS's own `vmm.asm` implementation (not just its API doc), created the
CASM Phase 6A Taskwarrior milestone and WP22-WP25 child tasks, drafted the
detailed WP23 plan, and verified a version-only completion candidate. It
implements no `vmm_store.s`, no real `DOS_ALLOC_MEM`/`DOS_FREE_MEM` wiring,
and no fixtures — CASM's runtime behavior is unchanged.

## Baseline

| Item | Value |
| --- | --- |
| Branch | `feature/casm-phase6-wp22` |
| Branch point | `main` at `dcb74bb` ("Merge CASM Phase 5 expression evaluator") |
| Baseline version | `0.1.23.1094` |
| Baseline PRG SHA-256 | `18d2f6cce7ffbcc7de8aa71db3da9e3b6d9ee3bb1cd07e69b072dd0d0884e703` |
| Phase 5 status | complete and user-approved |

## Research Findings (Phase 0C.4)

Read directly from `src/command64/vmm.asm` rather than relying only on
`docs/vmm-api.md`:

- `vmmAlloc` always returns `VmmSegLo = 0`; an allocation's identity is
  exactly `(VmmSegHi, VmmBank)`. `vmmFree`'s real input is exactly those two
  bytes — confirming the pre-existing 3-byte `CasmVmmRegistry` record
  (`flag`/`SegHi`/`Bank`) needs no growth to support real `DOS_FREE_MEM`
  calls.
- `vmmComputeAddress` computes `Address = (Seg << 4) + Off` with `Seg` fixed
  at the allocation's base and `Off` a 16-bit cursor. A single allocation is
  therefore only reachable up to 65536 bytes from a fixed `SegHi:Bank` pair,
  regardless of how many pages `DOS_ALLOC_MEM` actually granted. Frozen as a
  hard per-allocation cap; larger needs use additional registry slots.
- `vmmReadBlock`/`vmmWriteBlock` perform no bounds checking against an
  allocation's granted size — only a `vmmInitialized` check. CASM's own
  windowed transfer wrapper (WP24) must self-enforce the bound the OS does
  not provide.
- `VMM_ERR_INVALID` is returned both for "no REU" and for a zero-paragraph
  request; CASM never issues the latter except as an internal bug, so the
  code is treated as VMM-unavailable.
- REU contents are undefined at boot, confirmed by the environment-variable
  subsystem's prior VMM use (`brain/walkthroughs/2026-05-14-env-var-remediation.md`).
  REU presence in the supported local test environment predates CASM.

The MAIN-envelope-size and literal `CASM_DIAG_*` value decisions were
deliberately deferred to WP23 rather than fixed here, matching how Phase 4
WP13 and Phase 5 WP19 made those calls inside their own implementing package
once real code existed to measure against.

All findings are recorded in `brain/KNOWLEDGE.md` under "CASM Phase 6A VMM
Storage Contract (Phase 0C.4, frozen 2026-07-21)".

## Task Hierarchy

Created in Taskwarrior, `wiki/tasks/casm.md`, and `brain/task.md`:

| Role | UUID | Depends on |
| --- | --- | --- |
| CASM Phase 6A parent | `d68e6c58-ac89-44f4-81a2-40b14093585b` | WP22, WP23, WP24, WP25 |
| WP22 | `eb7541e5-c3aa-4528-bdcd-2571d96688d9` | (none) |
| WP23 | `8782e75d-d935-4e15-bf3c-d0488a1533a8` | WP22 |
| WP24 | `228daccc-f389-48cf-bd52-9f1ac610234a` | WP23 |
| WP25 | `544a04bd-4ccb-47c6-9013-8af57aa37353` | WP24 |

CASM Phase 6B's WP26-WP31 slugs are reserved in the parent plan but not yet
created in Taskwarrior, matching how Phase 5's entry WP reserved (rather than
pre-created) its own later downstream tasks.

## WP23 Gate

`brain/plans/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md` defines a
separately approved `vmm_store.s` increment: real `DOS_ALLOC_MEM`/
`DOS_FREE_MEM` wiring, the `$28-$2B` diagnostic reservations, and the
measured MAIN-envelope-size decision. It is planned but not active.

## Version Dry-Run Evidence

| Measurement | Baseline | WP22 dry run |
| --- | ---: | ---: |
| Version | `0.1.23.1094` | `0.1.24.1095` |
| CODE+RODATA | 9,366 B | 9,366 B |
| Relocations | 1,271 | 1,271 |
| R6 PRG size | 11,916 B | 11,916 B |
| PRG SHA-256 | `18d2f6cc...e703` | `66594cd2...4958e64` |

`cmp -l` reported exactly two changed bytes, at one-based offsets 7280 and
7285: `'3' -> '4'` (the stage digit) and `'4' -> '5'` (the build-number
digit). No functional payload, storage, or relocation count changed. The
worktree was then restored to `0.1.23.1094` — `git checkout --
src/external/casm/BUILD_CASM src/external/casm/casm.s` reproduced the
baseline PRG hash exactly — and remains at that baseline pending completion
approval.

## Automated Verification

- `cmake -S . -B build`: pass.
- `cmake --build build --target casm` (pre-dry-run baseline): pass at
  `$3400`/`$3500`; PRG hash matched the WP21 closeout's recorded value
  exactly, confirming no drift since Phase 5 closed.
- Immediate no-change rebuild at baseline: pass, `BUILD_CASM` unchanged at
  1094.
- Dry-run changed-source build: `BUILD_CASM` 1094 -> 1095 exactly once; CODE
  and relocation counts unchanged.
- Byte-level diff of baseline vs. dry-run PRG: exactly 2 bytes changed, both
  version-banner digits; file size unchanged (11,916 bytes).
- Post-dry-run baseline restoration via `git checkout`: pass; PRG hash and
  `BUILD_CASM` both reproduced exactly.
- `cmake --build build --target test_image_d64`: pass at restored baseline.
- `cmake --build build --target image_d64`: pass at restored baseline;
  release disk contains `CASM` without losing another application.
- `git diff --check`: pass (no whitespace errors across all changed files).
- No prohibited C64-testing MCP or web emulator used.

## DOX Closeout

The root, `src`, `src/external`, `src/external/casm`, `wiki`, and
`wiki/tasks` contracts were rechecked. No `AGENTS.md` changed: WP22
introduces no new directory boundary or durable operating rule beyond the
Phase 0C.4 contract already captured in `brain/KNOWLEDGE.md`, which is the
correct home for it (matching Phase 5's WP16 precedent).

## Manual Confirmation

WP22 changes only banner version metadata and records once its final
increment is applied, so no emulator or hardware behavior matrix is
required. Optional visual confirmation after completion approval and the
final version increment:

1. Boot `build/image.d64` in the supported local environment.
2. Run `CASM` without a source filename.
3. Confirm the banner reports `CASM V0.1.24.1095`.
4. Confirm `SOURCE REQUIRED` appears and the shell remains usable.

## Approval

The user confirmed the runtime banner at the restored `0.1.23` build 1094
baseline ("the banner reports 1094 but otherwise seems normal" — expected,
since the final increment is held back until approval per this plan's gate)
and explicitly approved WP22 completion.

## Final Increment (post-approval)

| Measurement | Value |
| --- | --- |
| Applied version | `0.1.24` |
| Build number | 1095 |
| PRG SHA-256 | `66594cd2b278b78705cacddf6e0a70d41c7574f8c2e84c6a101006bdd4958e64` (matches the dry run exactly) |
| No-change rebuild | pass, held at 1095 |
| `test_image_d64` | pass |
| `image_d64` | pass |

WP22 is complete. Taskwarrior (`eb7541e5`), `wiki/tasks/casm.md`, and
`brain/task.md` are marked done. WP23 (`8782e75d-d935-4e15-bf3c-d0488a1533a8`)
is unblocked but requires its own separate plan approval before activation.
