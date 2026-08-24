---
feature: casm-progress-increment05-source-include-integration
created: 2026-08-24
status: proposed
taskwarrior: 1acb36e3-2c0e-4f24-998b-279b2578bee4
depends-on: casm-progress-increment04-pass-integration, approved and complete
---

# Plan: CASM Progress Increment 5 - Source and Include Integration

## Status

**Proposed, not yet approved.** Parent plan:
`brain/plans/2026-07-29-casm-feature-progress-indication.md`.

## Objective

Report top-level and include loading plus committed root/frame transitions while
preserving Phase 9 provenance, traversal, replay, and zero-Pass-2-source-I/O.

## Hook Contract

- Notify top-level load only after each complete up-to-256-byte input block has
  committed to VMM; use cumulative committed cursor, not final 64-byte chunk.
- Apply the same rule to included-file append and report the final short block.
- Do not load, catalog, or notify include file I/O during Pass 2.
- Notify frame push only after child cursor/depth/lookahead state is committed;
  notify pop only after parent state is restored. Notifications are best-effort.
- Notify every cascading pop and each committed root transition.
- Keep top-level ID, include catalog ID, packed diagnostic ID, and displayed
  physical-file ID explicitly distinct.
- Snapshot filename/identity before OS/VMM calls; progress owns no filename copy
  beyond bounded rendering scratch.

## Atomic Increments

1. Add top-level source-load transition and 256-byte committed-block hooks.
2. Add include append/load hooks with Pass 1-only assertions.
3. Add committed frame push/pop notifications and cascading-pop tests.
4. Add root transition notifications for multi-root input.
5. Extend focused capture tests for identity, depth, filename, line, and cadence.
6. Run catalog/event/frame/include/source-fault harnesses and flattened-vs-include
   artifact comparisons; prove Pass 2 performs no source file I/O.
7. Measure performance/envelope, no-change rebuild, and write walkthrough.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/external/casm/source.s` | Modify |
| `src/external/casm/include.s` | Modify only if identity cannot be passed cleanly from source owner |
| `src/external/casm/progress.s` | Extend |
| `tests/src/casm_progress/casm_progress.s` | Extend |
| Existing source/include harnesses | Extend only where committed transitions need production evidence |

## Stop Conditions

Stop if a hook occurs before commit, requires rollback, causes Pass 2 I/O, changes
catalog/frame/event records, confuses identity namespaces, clobbers source/VMM
scratch, misses cascading pops, fails existing tests, breaches caps, or exposes a
new unrelated defect.

## Documentation, Task, and DOX Updates

Update feature trackers and technical plan evidence. Preserve existing Phase 9
manual/API contracts; no user-facing update until completion.

## Completion Gate

Boundary, identity, replay, zero-I/O, diagnostics, performance, size, and artifact
evidence is recorded, trackers agree, and the user approves Increment 5.

## Progress

- 2026-08-24: Detailed plan drafted; source/include hooks not authorized.
