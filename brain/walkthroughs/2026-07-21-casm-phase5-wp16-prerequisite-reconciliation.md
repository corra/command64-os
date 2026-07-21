---
feature: casm-phase5-wp16-prerequisite-reconciliation
created: 2026-07-21
status: complete
---

# Walkthrough: CASM Phase 5 WP16 Prerequisite Reconciliation

Plan: `brain/plans/2026-07-21-casm-phase5-wp16-prerequisite-reconciliation.md`

Taskwarrior: `0062fd20-929d-4ffd-a2b5-032db5ec4109`

## Outcome

WP16 recovered the Phase 5 control plane without restoring the crashing WIP or
implementing evaluator code. Phase 4 remains unchanged. Phase 0C.3 is frozen,
Taskwarrior/wiki/brain agree, downstream work is dependency-blocked, and WP17
has a detailed but inactive plan.

## Baseline

| Item | Value |
|---|---|
| Branch | `feature/casm-phase5-wp16-2` |
| Branch point | `9e58b8a44647028bc392656cdcbff9bc99927279` |
| Baseline version | `0.1.17.1079` |
| Baseline PRG SHA-256 | `c27b2e21c3562cf2dd523018dd1291f0123569fe5e28da6357289f2a53f3cc36` |
| Phase 4 status | complete and user-approved |

## Dependency Reconciliation

- Preserved the existing Phase 5 parent and WP16-WP21 UUIDs.
- Reopened WP19 (`4acf22c2`) after finding it incorrectly completed by the
  rolled-back attempt.
- Stopped premature WP17, WP18, and WP20 starts.
- Recorded sequential WP16 -> WP21 dependencies and made the Phase 5 parent
  depend on all children.
- Synchronized statuses and UUIDs in `wiki/tasks/casm.md` and `brain/task.md`.
- Left WP16 as the only active Phase 5 child.

## Contract Freeze

`brain/KNOWLEDGE.md` now records:

- bounded expression grammar and result record;
- sign/magnitude addends and checked 16-bit resolved arithmetic;
- opaque resolver identity and unresolved force-absolute-width behavior;
- extraction/relocation classification;
- carry/diagnostic result convention;
- evaluator/emitter ownership boundary; and
- the accurate decimal-mode rule: evaluator carry is explicit, while CASM's
  application-entry decimal-mode assumption remains separate hardening debt.

## WP17 Gate

`brain/plans/2026-07-21-casm-phase5-wp17-expression-abi.md` defines a separately
approved nine-byte result-record increment with no zero-page allocation. It is
planned but not active. Reserved downstream slugs are recorded there.

## Version Dry-Run Evidence

| Measurement | Baseline | WP16 |
|---|---:|---:|
| Version | `0.1.17.1079` | dry run `0.1.18.1080` |
| CODE+RODATA | 8,705 B | 8,705 B |
| BSS | 1,127 B | 1,127 B |
| MAIN headroom | 408 B | 408 B |
| Relocations | 1,172 | 1,172 |
| R6 PRG size | 11,057 B | 11,057 B |
| PRG SHA-256 | `c27b2e21...cc36` | `4db3fd52...9ba5` |

`cmp -l` reported exactly three changed bytes at one-based offsets 6735, 6739,
and 6740. They are the stage digit and two changed build-number digits. No
functional payload, storage, or relocation count changed. The worktree was then
restored to `0.1.17.1079` until explicit completion approval. After approval,
the same verified increment was applied permanently.

## Automated Verification

- `cmake -S . -B build`: pass.
- `cmake --build build --target casm`: pass at `$3400` and `$3500`.
- Dry-run changed-source build: `BUILD_CASM` 1079 -> 1080 exactly once.
- Dry-run immediate no-change rebuild: pass, counter remained 1080.
- Pre-approval baseline restoration: pass.
- Post-approval final increment: pass; worktree is `0.1.18.1080`.
- Final no-change rebuild: pass; counter remains 1080.
- `cmake --build build --target image_d64`: pass; release disk contains CASM.
- Baseline worktree build and byte comparison: pass with three expected bytes.
- `git diff --check`: pass.
- No prohibited C64-testing MCP or web emulator used.

## DOX Closeout

The root, `src`, `src/external`, `src/external/casm`, `wiki`, and `wiki/tasks`
contracts were rechecked. No AGENTS.md changed because WP16 introduces no new
directory boundary or durable operating rule; it applies the existing
work-package version and approval contracts.

## Manual Confirmation

WP16 changes only banner version metadata and records, so no emulator or
hardware behavior matrix is required. Optional visual confirmation:

After completion approval and the final version increment, optionally:

1. Boot `build/image.d64` in the supported local environment.
2. Run `CASM` without a source filename.
3. Confirm the banner reports `CASM V0.1.18.1080`.
4. Confirm `SOURCE REQUIRED` appears and the shell remains usable.

The user explicitly approved this walkthrough and WP16 completion on
2026-07-21. WP16 is complete; WP17 remains pending separate approval.
