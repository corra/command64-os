---
feature: edlin-port
created: 2026-07-09
status: planned
---

# Plan: Port MS-DOS EDLIN to COMMAND64OS

## Goal & Rationale

`ms-dos/v4.0/src/CMD/EDLIN/` contains the real MS-DOS 4.00 EDLIN source (8086/MASM,
Microsoft 1988). EDLIN is a line-oriented text editor with no screen addressing —
every interaction is "prompt with `*`, read a line, act on it." That interaction
model maps far more cheaply onto a 6502/40-column shell than a cursor-addressed
editor (vi) would. `src/external/vi/` already has a reserved build-number slot
with no source — a ported EDLIN is a much lower-risk way to give COMMAND64OS a
usable text editor than building vi from scratch, and can be shipped first while
vi (if ever attempted) reuses the line-input/paging plumbing this produces.

## Scope

**In scope** (the commands that carry EDLIN's actual value and are cheap to port):

- Line editing model: flat text buffer, virtual line numbers via linear scan.
- Commands: `I`nsert, `D`elete, `L`ist, `P`age, blank-line **edit-line**, `Q`uit,
  `W`rite, and plain load/save (open file → buffer → save on exit).
- `A`ppend/`W`rite streaming so files larger than the in-memory buffer still work,
  backed by the VMM (REU) heap rather than a fixed conventional-memory arena.
- Simple decimal / `.` (current) / `#` (last+1) line-number argument syntax.

**Explicitly out of scope** (drop, don't port):

- DBCS/Kanji handling (`IF KANJI` blocks in EDLCMD2/EDLIN) — dead weight, no
  target hardware relevance.
- `C`opy/`M`ove (`BLKMOVE`) — this is the module the DOS revision history calls
  out as the historically buggiest routine (three-phase pointer relocation).
  Cut for v1; revisit only if users actually ask for block move.
- `S`earch/`R`eplace with `^V`-quoted control-char literals — implement a
  simplified search/replace without the quote-char escaping machinery first;
  add escaping later if needed.
- `T`ransfer/merge (insert-another-file-at-a-line) — nice-to-have, not core.
- MS-DOS message-retriever indirection (`SYSLOADMSG`/.msg tables with `%1`/`%2`
  substitution) — replace with a plain static string table; COMMAND64OS has no
  equivalent localization infrastructure and none is wanted here.
- Ctrl-Break/INT 23h abort-mid-command handling — no KERNAL equivalent signal;
  skip unless a specific hang scenario turns up in testing.
- IOCTL-queried dynamic screen geometry — COMMAND64OS is a fixed 40x25 PET
  screen, so `List`/`Page` paging math becomes a hardcoded constant instead of
  the v4.0 `EDLIN_DISP_COUNT` dynamic lookup.

## Files to Create/Modify

| File | Action | Notes |
|------|--------|-------|
| `src/external/edlin/edlin.s` | Create | Entry point, command dispatch loop, version banner (ca65 app pattern per `src/external/AGENTS.md`) |
| `src/external/edlin/buffer.s` | Create | Flat-buffer line model: `FINDLIN` equivalent, insert/delete-hole memmove, current-line/pointer tracking |
| `src/external/edlin/cmds.s` | Create | Insert, Delete, List, Page, edit-line, Quit, Write/Append streaming |
| `src/external/edlin/BUILD_EDLIN` | Create | Build-number counter file, seeded `1000` per AGENTS.md convention |
| `CMakeLists.txt` | Modify | `add_ca65_app(edlin ...)` target + append to `IMAGE_PRG_TARGETS` |
| `wiki/edlin-utility.md` | Create | User-facing command reference (mirrors `wiki/debug-utility.md` pattern) |
| `wiki/tasks/edlin-port.md` | Create | Task tracker if this moves from plan to active work |

## Key Design Decisions

1. **Buffer backing store: VMM heap, not base RAM.** COMMAND64OS user space
   is `UserProgStart` (~$2E00) to $C000 — roughly 40KB shared with the app's
   own code, far less headroom than EDLIN's original 64KB DOS segment. Since
   `DOS_ALLOC_MEM`/`DOS_FREE_MEM` (`vmmAlloc`/`vmmFree`) provide a REU-backed
   1MB paragraph-addressable space via `vmmReadByte`/`vmmWriteByte`, the edit
   buffer should live there. This trades EDLIN's original `REP MOVSB` block-move
   speed for byte-wise VMM access on hole-open/close — acceptable given C64
   file sizes are small, but the biggest single risk item (see Verification).
   Requires a REU to be present; without one there is no heap and this port
   cannot hold a buffer larger than base RAM allows — same size ceiling as
   original DOS EDLIN in that fallback case.
2. **No seek in the file API.** COMMAND64OS's `DOS_READ_FILE`/`DOS_WRITE_FILE`
   are sequential-only (1541 KERNAL semantics), unlike DOS's `LSEEK`(42h).
   EDLIN's own I/O pattern is already sequential (open once, stream `APPEND`
   reads, stream `WRITE` writes, no random seeking) so this is a non-issue —
   confirms EDLIN ports more naturally than a random-access editor would.
3. **Line input: write our own, don't reuse `shellReadLine`.** It exists and
   the pattern is provable (GETIN-poll, destructive backspace, CR-terminated),
   but it's shell-internal, not exported via `OS_API`. Port a copy into
   `edlin.s` rather than trying to reach into shell internals.
4. **Save mechanism: skip the `.BAK`/`.$$$` rename dance initially.** DOS
   EDLIN's `ENDED` routine writes to a temp `.$$$` file then renames old→`.BAK`,
   new→original — this exists to survive a mid-write crash without losing the
   original. `DOS_RENAME_FILE` exists in COMMAND64OS so the mechanism is
   portable, but it roughly doubles disk I/O per save on a 1541. Ship v1 with
   direct overwrite-on-save; add the `.BAK` safety dance as a v2 follow-up once
   the core editor is validated, not a blocker for v1.
5. **New `edlin` app slot, not the reserved `vi` slot.** `src/external/vi/`
   is a separate reserved build-number slot with different command semantics
   (modal, cursor-addressed) — don't conflate them. EDLIN gets its own
   `src/external/edlin/` directory.

## Verification Plan

- Unit-level: exercise buffer insert/delete/list against `tests/src/file/` and
  `tests/src/vmm/` patterns — add a `tests/src/edlin/` app-level test that
  loads a known text file, inserts/deletes/lists lines, saves, and diffs
  against expected output (VICE-driven, per project convention — see
  `mcp__c64__vice_*` tools and existing test harness under `tests/`).
- Explicitly test the REU-absent fallback path (VMM alloc failure) — confirm
  it degrades to a bounded base-RAM buffer with a clear error rather than
  crashing, since this is the single biggest architectural deviation from the
  original.
- Manual pass in VICE: create a file with `edlin newfile.txt`, insert several
  lines, list, delete a line, write, reload, confirm round-trip correctness.
- Confirm `cmake --build build --target test_image_d64` builds the new app
  cleanly with no warnings, per `src/external/AGENTS.md` verification section.

## Progress

- 2026-07-09: EDLIN source reviewed in full; COMMAND64OS external-app/file/VMM
  APIs reviewed; this feasibility plan drafted. No implementation started.

- 2026-07-11: EDLIN Functional complete *not* Feature Complete.
  TODO: *Save Mechanics*, Create back-up file for write faliure/crash protection
  TODO: *Search and Replace*, Limited search and replace on the road-map
  BUGS: *Case sensitivity*, Commands are currently case sensitive which is a
        significant non-blocking UX flaw.
