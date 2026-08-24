---
feature: dir-p-paging
plan: brain/plans/2026-08-21-dir-p-paging.md
date: 2026-08-22
status: approved
---

# Walkthrough: `dir /p` Paged Directory Listing

## Implementation

- `cmdDir` recognizes standalone lowercase `/p` before or after an optional
  device prefix and excises it before the existing device parser runs.
- Plain `dir` clears the paging flag and follows its previous unpaged path.
- Paging counts completed directory lines and pauses after 23 lines using
  the existing `-- More --` prompt.
- `dirPause` calls `KernalCLRCHN` to read a keyboard key, then reselects the
  still-open directory LFN 13 with `KernalCHKIN` before continuing. This
  channel handoff was explicitly approved by the user during Increment 4.

## Build Evidence

- The unchanged baseline built successfully with `CommandShell` at
  `$10D1-$1EFD`, leaving 162 bytes before fixed `VmmData` at `$1FA0`.
- After functional implementation, `cmake --build build` succeeded with
  `CommandShell` at `$10D1-$1F7B`, leaving 36 bytes of headroom.
- The final documentation/help rebuild completed as build 2676.
  `CommandShell` remained `$10D1-$1F7B`; `ShellExt` contains the two new
  state bytes and ended at `$3551` after the five-byte help-text addition.

## Verification Evidence

Increment 3 was verified through VICE MCP 3.10 against rebuilt
`build/image.d64`. Command64 startup was confirmed from screen RAM. Direct
memory reads showed:

- `dir /p`: `dirPagingEnabled=$01`.
- `dir 8: /p`: `dirPagingEnabled=$01`, `CurrentDevice=$08`.
- `dir /p 8:`: `dirPagingEnabled=$01`, `CurrentDevice=$08`.
- Plain `dir`: `dirPagingEnabled=$00`.

Increment 5 agent verification was blocked by a setup failure: VICE MCP
remained responsive, but repeatedly rejected attachment of rebuilt
`build/test.d64`, including after reset. No product failure was observed.

The user then manually tested build 2675 on a multi-screen directory and
explicitly confirmed all five completion checks on 2026-08-22:

1. `dir /p` paused after 23 lines.
2. Any key resumed without corrupting the directory stream.
3. Plain `dir` remained unpaged.
4. `dir 8: /p` worked.
5. `dir /p 8:` worked.

## Documentation

- Built-in `HELP` now advertises `DIR ... [/p]`.
- `wiki/user-manual.md` and its byte-identical `docs/` mirror document the
  lowercase option, paging threshold, key behavior, and both argument
  orderings.
- `CHANGELOG.md` records the feature under Unreleased.
- `cmake --build build` completed successfully after all documentation and
  help changes, and `wiki/user-manual.md` is byte-identical to its `docs/`
  mirror.

## Completion Gate

Implementation and the five-check functional matrix are complete. The user
explicitly approved closure on 2026-08-22. Taskwarrior UUID
`5ae09831-1204-4204-a962-0cbf0a228197` is completed (current ID 43).
