---
feature: dir-p-paging
created: 2026-08-21
status: completed
taskwarrior: 5ae09831-1204-4204-a962-0cbf0a228197
depends-on: none
---

# Plan: `dir /p` — Paged Directory Listing

## Status

**Completed and approved for closure 2026-08-22.** User confirmed the plan
and all three Scoping Decisions on 2026-08-21, manually verified the full
five-check behavior matrix on build 2675, and approved the completion-gate
walkthrough after the final build 2676 documentation/help rebuild.

Not a numbered Phase/WP of an existing multi-WP effort (CASM/DASH/DEBUG) —
a standalone shell-command enhancement, planned under the same gate
because it changes production OS behavior.

## Objective

Add a `/p` command-line option to the shell's `dir` command
(`cmdDir`, `src/command64/shell.asm:785`) that pauses directory output
after each screenful and waits for a keypress before continuing —
matching the long-standing `dir /p` convention from DOS-family shells.

**Delivers:** `dir /p`, `dir 9: /p`, `dir /p 9:` all page. Plain `dir`
(no `/p`) behaves exactly as today — unpaged, scrolls freely.

**Does not deliver:** wildcard/filename filtering for `dir` (not
supported today, out of scope here), a `more`-style abort-on-keypress
(neither `more` nor this design cancels the listing — any key just
resumes), or paging for other commands.

## Scoping Decisions (proposed 2026-08-21 — confirm on plan approval)

1. **Flag syntax & position**: `/p` (lowercase only, matching this
   project's lowercase-only shell-command convention) is recognized
   anywhere in the `dir` argument text, independent of the optional
   device prefix (`8:`/`9:`/`10:`/`11:`) — both orders work:
   `dir 9: /p` and `dir /p 9:`. Uppercase `/P` is **not** recognized,
   for consistency with existing case-sensitivity.
2. **Pause behavior**: modeled directly on the existing `more` command's
   `morePause`/`mpWaitKey` (`shell.asm:1308-1320`) — print `-- More --`
   (reusing `morePromptMsg`, no duplicate string), poll `KernalGetIn`
   for any key, resume. No STOP-key/abort handling — `more` has none
   today, so `dir /p` won't invent new behavior the rest of the shell
   doesn't have.
3. **Page threshold**: pause after **23 printed lines** (row counter
   `>= 24`), the same threshold `more` uses (`mpcMaybePause`,
   `shell.asm:1300-1303`), for one consistent "screenful" definition
   across both commands.

If any of these should differ, flag it now — implementation starts only
after this plan (including these three points) is approved.

## Scope

**Included:**
- Parse `/p` out of `dir`'s argument text without disturbing the
  existing device-prefix parse (`parsePointerDevice`,
  `src/command64/utils.asm:783`).
- New per-invocation state: a paging-enabled flag and a line-row
  counter.
- A `dirPause` routine mirroring `morePause`, invoked once every 23
  lines while paging is enabled.
- Reuse of `morePromptMsg` ("-- More --") — no new user-facing string.

**Excluded:**
- Any change to `more`, `type`, or other commands' behavior.
- Wildcard/filename filtering of `dir` output.
- An abort/cancel key during paging.
- Changing the existing unpaged `dir` behavior when `/p` is absent.

## Design

### Argument parsing

`cmdDir` currently does: skip leading spaces → build a pointer into
`CommandBuffer` at `ParsePos` → hand that pointer to
`parsePointerDevice` (which only recognizes a leading digit+`:` token
and no-ops otherwise) → proceed to open `"$"` regardless of what
(if anything) is left in the argument text (`shell.asm:785-821`). The
remaining argument text is never otherwise consulted — `dirFname` is
always the literal `"$"`.

New step, inserted before the existing device-prefix parse: scan the
full remaining argument text (`CommandBuffer[ParsePos..]`, NUL- or
newline-terminated, bounded by the existing command-line length) for a
standalone `/p` token (preceded by start-of-arg or a space, followed by
end-of-arg or a space). If found:
- Set `dirPagingEnabled = 1`.
- Excise the two characters in place (shift the remainder of the buffer
  left by 2, same pattern `parsePointerDevice` uses for its own
  prefix-skip, just applied mid-string) so the existing device-prefix
  scan still sees a clean leading token regardless of whether `/p`
  appeared before or after it.

If not found, `dirPagingEnabled = 0` and `cmdDir` proceeds exactly as
today (skips the new pause checks entirely — zero behavior change for
plain `dir`).

### Line counting and pause

`dir` prints one CR-terminated line per KERNAL directory entry via
direct `KernalChROUT` calls scattered through `cdReadName`/`cdLineDone`
(`shell.asm:894-962`) — it does not route through `morePutChar`
(that's `more`'s file-content pager, character-oriented; `dir` is
already line-oriented, so counting per completed line is simpler and
sufficient here). Add:
- `dirPageRow` (new byte, initialized to 1 in `cmdDir` alongside the
  existing `dirIsHeader` init at `shell.asm:840-841`).
- In `cdLineDone`, immediately after the existing `PetCr` +
  `KernalChROUT` (`shell.asm:957-958`): if `dirPagingEnabled`, `inc
  dirPageRow`; if it reaches 24, `jsr dirPause` (reset to 1 inside
  `dirPause`, mirroring `morePause`'s reset of `moreCurRow`).
- `dirPause`: print `morePromptMsg` via `petPrintString`, poll
  `KernalGetIn` until nonzero (`mpWaitKey`'s exact idiom), print
  `PetCr`, reset `dirPageRow` to 1, return.

### Segment placement — real risk to verify first

`cmdDir` lives in the `CommandShell` segment
(`src/command64.asm:44`), which is packed into the fixed window between
`ApiStub` (pinned `$1000`) and `VmmData` (pinned `$1FA0`) — `Petsci`,
`CommandTable`, and `CommandShell` all share that ~4000-byte span. This
is the same kind of tight, non-relocatable cap that has repeatedly
forced CASM's linker-cap bumps this phase (see
`project-casm-post-phase12-hardening` / recent WP81-83 history), and
project memory already flags OS segments below `$1000` as full
(`project-os-sub1000-segment-full`) — this window deserves the same
suspicion before assuming the new code just fits.

New state bytes (`dirPagingEnabled`, `dirPageRow`) go in `ShellExt`
instead (alongside `dirIsHeader` et al., `shell.asm:3297-3301`) —
`ShellExt` starts after the fixed `AppTable` (`$2000`) and is not
capped the same way, so 2 extra bytes there is low-risk.

**Increment 1 below is a build-and-measure step before any real logic
is written**, specifically to confirm `CommandShell` has headroom for
the new argument-scan and `dirPause` code before committing to this
placement.

## Atomic Increments

1. **Headroom check**: build the current tree as-is (`cmake --build
   build`) and confirm it links clean today; capture how close
   `CommandShell` already sits to the `$1FA0` cap (from the KickAssembler
   build log/report) as a baseline. If there's no comfortable margin,
   stop and report back before writing new code — this may need a
   segment reshuffle first, which is its own decision.
2. Add `dirPagingEnabled` and `dirPageRow` byte declarations to
   `ShellExt` next to the existing `dir*` state bytes.
3. Implement the `/p`-token scan-and-excise step in `cmdDir`, ahead of
   the existing `parsePointerDevice` call. Verify `dir`, `dir 9:`,
   `dir /p`, `dir 9: /p`, `dir /p 9:` all parse to the correct device
   and paging flag (can be checked via a temporary VICE memory read of
   `dirPagingEnabled`/`CurrentDevice` before wiring in the pause logic).
4. Implement `dirPause` and the `cdLineDone` row-counting hook. Rebuild
   and confirm the previous build still links within the same cap
   headroom measured in Increment 1.
5. Live VICE verification (see Completion Gate) — a disk with more than
   one screenful of entries, confirm `dir /p` pauses at 23 lines,
   any key resumes, plain `dir` is unaffected, and both `/p` orderings
   and the `9:`-device combination all work.

## Expected Files

| File | Planned action |
| --- | --- |
| `src/command64/shell.asm` | Modify — `cmdDir` argument scan, `dirPause`, `cdLineDone` hook, new `ShellExt` bytes |

## Stop Conditions

- Increment 1's headroom check shows `CommandShell` too close to the
  `$1FA0` cap to safely absorb the new code — halt and report before
  writing implementation, per the risk noted in Design.
- Any live VICE verification in Increment 5 fails unexpectedly.
- A no-op rebuild (before touching code) doesn't reproduce today's
  known-good `command64.prg` — investigate before proceeding, since that
  would mean the baseline itself is unreliable.
- A genuinely new defect is found in existing `dir`/`more` code while
  working this plan — disclose and defer as a separate follow-up, not an
  inline fix, unless the user explicitly directs otherwise in the
  moment.

## Documentation, Task, and DOX Updates

- Taskwarrior: create a task for this plan on approval.
- `brain/task.md` / `wiki/tasks/*.md`: add an entry once approved.
- `CHANGELOG.md`: entry on completion.
- In-shell help text (if `dir` has a `?`/help listing anywhere in
  `shell.asm`) should be checked and updated to mention `/p` — the
  DEBUG REU work found in-app help text can silently drift
  (`project-debug-reu-feature-complete`); verify this doesn't repeat
  here.
- Memory: a short project-memory note once closed, if anything about
  the `CommandShell` segment headroom turns out to be non-obvious or
  worth remembering for the next command-line-option addition.

## Completion Gate

- Live VICE evidence recorded in
  `brain/walkthroughs/2026-08-21-dir-p-paging.md`: screenshots/register
  reads showing `dir /p` pausing correctly on a multi-screen directory,
  resuming on keypress, plain `dir` unaffected, and both flag/device
  orderings working — per this project's checkpoint-verification
  standard (`reference-vice-checkpoint-verification`), not just
  screen-text OCR.
- Trackers (Taskwarrior, `brain/task.md`, `wiki/tasks/*.md`,
  `CHANGELOG.md`) synchronized.
- Explicit user approval to close.

## Progress

- 2026-08-21: Plan drafted, not yet approved. Current `cmdDir`,
  `parsePointerDevice`, and `more`'s paging implementation reviewed in
  detail to ground the design; no code written yet.
- 2026-08-21: User confirmed the plan and all three Scoping Decisions
  as drafted. Taskwarrior task 44
  (`5ae09831-1204-4204-a962-0cbf0a228197`, project `command64.shell`,
  tags `+dir +paging`) created. `brain/task.md` and
  `wiki/tasks/dir-p-paging.md` updated. Implementation not yet started.
- 2026-08-21: Increment 1 complete. `cmake --build build` succeeded on
  the unchanged baseline. The assembler report places `CommandShell` at
  `$10D1-$1EFD`, leaving 162 bytes (`$1EFE-$1F9F`) before the fixed
  `$1FA0` `VmmData` boundary. The headroom stop condition is not
  triggered; no shell logic was changed.
- 2026-08-21: Increment 2 complete. Added `dirPagingEnabled` and
  `dirPageRow` beside the existing directory state in `ShellExt`.
  `cmake --build build` succeeded; `CommandShell` remained
  `$10D1-$1EFD` and `ShellExt` grew exactly two bytes from `$354A` to
  `$354C`.
- 2026-08-21: Increment 3 complete. Added a bounded, standalone lowercase
  `/p` token scan and in-place two-byte excision before device parsing.
  `cmake --build build` succeeded; `CommandShell` is `$10D1-$1F47`,
  leaving 88 bytes before `$1FA0`. Live VICE 3.10 verification against
  rebuilt `build/image.d64` observed `dirPagingEnabled=$01` for `dir /p`,
  `dir 8: /p`, and `dir /p 8:`; both ordered forms retained
  `CurrentDevice=$08`. Plain `dir` reset `dirPagingEnabled` to `$00`.
  Command64 startup was confirmed from screen RAM and the healthy emulator
  was left running.
- 2026-08-21: Increment 4 complete. Initialized `dirPageRow` to 1, added
  the paging-enabled line-count hook after each directory CR, and added
  `dirPause` using the shared `morePromptMsg`. During implementation,
  review found that polling `KernalGetIn` while directory LFN 13 remained
  selected would consume directory bytes rather than keyboard input. The
  user approved the necessary channel-preservation adjustment: `dirPause`
  calls `KernalCLRCHN` before waiting and reselects the still-open LFN 13
  with `KernalCHKIN` before returning. `cmake --build build` succeeded;
  `CommandShell` is `$10D1-$1F7B`, leaving 36 bytes before `$1FA0`, and
  `ShellExt` remains `$2495-$354C`.
- 2026-08-22: Increment 5 manually verified by the user on build 2675.
  All five requested checks passed: `dir /p` paused after 23 lines, any
  key resumed without corrupting the open directory stream, plain `dir`
  remained unpaged, and both `dir 8: /p` and `dir /p 8:` worked. Agent
  live-VICE verification could not proceed because VICE MCP 3.10 repeatedly
  rejected attachment of rebuilt `build/test.d64`, including after reset;
  this is classified as a setup failure, not a product failure.
- 2026-08-22: Final build 2676 succeeded after help/manual updates, with
  `CommandShell` still ending at `$1F7B` and 36 bytes free. User explicitly
  approved the completion-gate walkthrough and closure. Taskwarrior UUID
  `5ae09831-1204-4204-a962-0cbf0a228197` was completed through the CLI
  (current ID 43).
