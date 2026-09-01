# CASM Progress Display Documentation Walkthrough

Status: **COMPLETE - user approved 2026-09-01.**

## Scope

Document the shipped CASM progress-indication displays from the production
implementation rather than the superseded design notes.

## Documentation Changes

- Expanded `wiki/casm-utility.md` and its `docs/` and `release/docs/` mirrors
  with the exact 34-character transient layouts, field definitions, cadence,
  persistent transitions, failure behavior, and known limitations.
- Added programmer-level `progress.s` architecture, screen protocol, state,
  hook ABI, counting rules, and failure contracts to
  `wiki/casm-programmers-reference.md` and both mirrors.
- Corrected the `LOAD` and directive displays from persistent to transient in
  `CHANGELOG.md`.
- Reconciled `wiki/tasks/casm-progress-indication.md` with its existing
  2026-08-31 user-approved completion record, removed its stale reused numeric
  Taskwarrior id while retaining the completed UUID, and moved it from Pending
  to Completed in `wiki/Home.md`.

## Verification

- `cmake --build build --target release`: passed; release `0.4.1` packaged.
- Wiki, `docs/`, and `release/docs/` copies of both CASM manuals are
  byte-identical (`cmp`).
- `git diff --check`: passed.
- DOX pass: `wiki/AGENTS.md` and `wiki/tasks/AGENTS.md` remain current; this
  work documents existing behavior and changes no ownership, workflow, API,
  source contract, or Child DOX Index.

## Manual Confirmation

1. Open `wiki/casm-utility.md` at **Progress Display** and confirm the examples
   and field table are clear from an assembler user's perspective.
2. Open `wiki/casm-programmers-reference.md` at **17A. Progress Indication**
   and confirm the module ABI and screen protocol provide enough detail for a
   maintainer changing `progress.s`.
3. Confirm the documented limitation is acceptable: during include traversal,
   the numeric `F` field can remain the top-level source id, while depth and
   filename identify the active include.
4. Confirm `wiki/Home.md` now lists the already-approved feature under
   Completed.

The user explicitly confirmed the documentation task complete on 2026-09-01.
