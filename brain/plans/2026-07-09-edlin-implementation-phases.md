---
feature: edlin-port
created: 2026-07-09
status: in-progress
---

# Plan: EDLIN Port — Phased Implementation

Builds on [2026-07-09-edlin-port-feasibility.md](2026-07-09-edlin-port-feasibility.md)
(scope, dropped features, and design decisions are defined there — not repeated
here). This plan breaks the port into phases and ties each phase to the app's
own `VERSION_MAJOR.VERSION_MINOR.VERSION_STAGE` banner, following the
`MAJOR.MINOR.STAGE.BUILD` scheme used by `label`/`format` (`VERSION_STAGE` is
the patch field; `BUILD_NUMBER` is the per-compile counter in `BUILD_EDLIN`
and isn't hand-set). Branch: `feature/edlin-external-app`.

`VERSION_MAJOR = '0'`, `VERSION_MINOR = '1'` for the whole port. Each phase
below bumps `VERSION_STAGE` by one on completion, so the shipped version
number is a direct progress indicator: `0.1.0` is scaffold-only, `0.1.6` is
the phase-complete, test-covered v1.

## Phase 0 — Scaffold (`0.1.0`) — complete, verified

- [x] Create `src/external/edlin/` with `edlin.s` entry point, `BUILD_EDLIN`
      counter (seeded `1000`), version banner per `AGENTS.md` convention.
- [x] Register `add_ca65_app(edlin ...)` in `CMakeLists.txt`, add to
      `IMAGE_PRG_TARGETS`.
- [x] App loads via shell `LOAD`/`RUN`, prints `EDLIN v0.1.0.<build>` banner,
      returns via `DOS_EXIT`. No editing logic yet.
- **Exit criteria**: builds clean via `cmake --build build --target
  test_image_d64` — **met** (`edlin.prg`, 33 code bytes, appears correctly
  in `test.d64`'s directory listing alongside `command64`/`debug`/`label`/
  `format`; build-number content-hash gate verified working — a no-op
  `touch` did not bump `BUILD_EDLIN`). Boots and prints banner in VICE —
  **met**: user manually loaded/ran `EDLIN` in a disconnected VICE session
  and confirmed the version banner prints as expected. (First automated
  VICE attempt this session hung mid-boot; rather than improvise past that
  per [[feedback-vice-testing]], the user drove the check manually instead.)

### Phase 0 detail

#### New files

- `src/external/edlin/edlin.s` — entry point + header, mirroring
  `src/external/label/label.s`'s structure (SPDX header, `.include
  "command64.inc"`/`"common.inc"`, version block, `.import __MAIN_START__`,
  `HEADER`/`CODE` segments).
- `src/external/edlin/BUILD_EDLIN` — seeded `1000\n` (matches `BUILD_LABEL`/
  `BUILD_FORMAT` convention — single line, incremented by
  `cmake/IncrementBuildNumber.cmake` on source change).

#### edlin.s contents

```asm
.include "command64.inc"
.include "common.inc"

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '0'
.include "build_edlin.inc"

.import __MAIN_START__

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    ldx #<verMsg
    ldy #>verMsg
    lda #DOS_PRINT_STR
    jsr OS_API

    lda #DOS_EXIT
    jsr OS_API

.segment "RODATA"
verMsg:
    .byte "EDLIN V", VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE
    .byte ".", 0
    ; BUILD_NUMBER appended once build_edlin.inc's macro form is confirmed
    ; against label.s's exact usage (label.s:434-440) — verify during
    ; implementation, not guessed here.
```

No zero-page allocations needed yet (Phase 1 claims from the shared
`$70-$8F` app-private range — must be documented in `edlin.s` per
`AGENTS.md` contract when first used).

#### CMakeLists.txt changes

Mirroring `label`'s block at `CMakeLists.txt:119-130`:

```cmake
# N. EDLIN External Command PRG Target — ported from MS-DOS 4.00 EDLIN
# (ms-dos/v4.0/src/CMD/EDLIN/); see
# brain/plans/2026-07-09-edlin-port-feasibility.md and
# brain/plans/2026-07-09-edlin-implementation-phases.md.
file(GLOB_RECURSE EDLIN_SRCS CONFIGURE_DEPENDS "src/external/edlin/*.s" "src/external/edlin/*.inc" "include/ca65/*.inc")
set(EDLIN_ENTRY "src/external/edlin/edlin.s")
if(Ca65_FOUND)
    add_ca65_app(edlin "${EDLIN_ENTRY}" EDLIN_SRCS 1000 "0700")
else()
    message(FATAL_ERROR "ca65/ld65 not found on PATH — required for EDLIN target")
endif()
set(EDLIN_TARGET edlin)
```

`PRG_SIZE_HEX` of `0700` (1792 bytes) matches `label`'s allotment as a
starting guess for a scaffold-only build — this will need to grow
substantially once Phase 1's VMM buffer code and Phase 2+'s command
dispatch land; revisit the size at each phase's CMake touch rather than
over-allocating now. `GLOB_RECURSE` + `file(GLOB ...)` placement should sit
alongside the existing `DEBUG_SRCS`/`LABEL_SRCS` block (`CMakeLists.txt:53-57`
today, exact line numbers will shift once other in-flight uncommitted
CMakeLists.txt changes land — locate by content, not line number, when
implementing). Add `${EDLIN_TARGET}` to the `IMAGE_PRG_TARGETS` line
(currently `CMakeLists.txt:253`).

#### Verification steps for this phase

1. `cmake -B build && cmake --build build --target test_image_d64` — must
   succeed with `EDLIN` build number visibly incrementing on a second build
   after a no-op source touch.
2. Boot the resulting `test.d64` in VICE (`mcp__c64__vice_*` tools), `LOAD
   "EDLIN",8` / `RUN`, confirm the banner text reads `EDLIN V0.1.0.1000`
   (or current build number) and the app exits cleanly back to the shell
   prompt (`DOS_EXIT`'s `ahExit` must correctly unwind the `jsr $1000` stack
   depth — confirm shell prompt is still responsive after exit, not hung).

## Phase 1 — Buffer core (`0.1.1`)

- [ ] `buffer.s`: VMM-backed flat text buffer (`vmmAlloc` at startup), current
      line/pointer tracking, `FINDLIN`-equivalent linear scan over
      `vmmReadByte` for virtual line numbering.
- [ ] Load an existing file into the buffer on startup (`DOS_OPEN_FILE` +
      streamed `DOS_READ_FILE` into VMM via `vmmWriteByte`).
- [ ] REU-absent fallback: detect `vmmAlloc` failure, degrade to a bounded
      base-RAM buffer, surface a clear error (per feasibility plan's
      Verification note) rather than crash.
- **Exit criteria**: given a small test file, app loads it, and an internal
  debug dump (temporary, stripped before Phase 2 exit) confirms correct line
  count and byte offsets.

## Phase 2 — Core read/navigate commands (`0.1.2`)

- [ ] `cmds.s`: `L`ist and `P`age (hardcoded 40x25 paging, no dynamic IOCTL
      geometry per feasibility plan).
- [ ] Line-number argument parsing: decimal, `.` (current), `#` (last+1).
- [ ] Own line-input loop (GETIN-poll pattern copied from `shellReadLine`,
      not called into it — it's shell-internal).
- **Exit criteria**: `L`/`P` correctly display ranges and page at 24 lines;
  manual VICE pass against a multi-page test file.

## Phase 3 — Edit commands (`0.1.3`)

- [ ] Blank-line **edit-line** command (default `current+1`) and `I`nsert
      (open-hole via byte-wise VMM shift, read lines until blank/EOF).
- [ ] `D`elete (`[line1][,line2]D`, defaults to current), closes the hole.
- [ ] `Q`uit with "Abort edit (Y/N)?" confirmation, discards buffer.
- **Exit criteria**: insert/delete/edit-line round-trip correctly against
  `L`ist output in VICE; no buffer corruption across repeated hole
  open/close.

## Phase 4 — Save/streaming (`0.1.4`)

- [ ] `W`rite command and auto-drain-on-exit (`ENDED` equivalent): stream
      buffer to output file via `DOS_WRITE_FILE`, direct overwrite (no
      `.BAK`/`.$$$` rename dance — deferred per feasibility plan decision 4).
- [ ] `A`ppend streaming for files larger than the VMM allocation, mirroring
      DOS EDLIN's fill-to-3/4 / flush-to-1/4 buffer thresholds.
- **Exit criteria**: create file → insert/delete → save → reload → `L`ist
  matches expected content; a file larger than a single VMM allocation
  round-trips correctly (streaming exercised, not just small-file save).

## Phase 5 — Search/Replace, simplified (`0.1.5`)

- [ ] `S`earch (`[line1][,line2]S[str]`, optional `?` query) — no `^V`
      quote-char escaping (per feasibility plan scope cut).
- [ ] `R`eplace (`[line1][,line2]R[str1]<CR>[str2]`, optional `?` query).
- **Exit criteria**: search finds correct line on a known test file;
  replace mutates buffer correctly and is reflected in subsequent `L`ist`/W`rite.

## Phase 6 — Hardening, tests, docs (`0.1.6`)

- [ ] `tests/src/edlin/` app-level test: scripted load/insert/delete/list/save,
      VICE-driven diff against expected output, following `tests/src/file/`
      and `tests/src/vmm/` patterns.
- [ ] Exercise the REU-absent fallback path explicitly in a test.
- [ ] `docs/apps/edlin.md` user-facing command reference.
- [ ] `wiki/tasks/edlin-port.md` checklist closed out; `CHANGELOG.md` entry.
- **Exit criteria**: `cmake --build build --target test_image_d64` clean;
  manual VICE pass covers full create/edit/save/reload cycle end to end.

## Deferred beyond `0.1.x` (not scheduled)

- `.BAK`/`.$$$` crash-safe save dance (feasibility plan decision 4, v2 item).
- `C`opy/`M`ove (`BLKMOVE`) — explicitly cut in the feasibility plan due to
  historical bugginess; only take up if requested.
- `T`ransfer/merge (insert-file-at-line).
- `^V` control-char quoting in Search/Replace.

## Verification Plan

Each phase's own exit criteria (above) gates the `VERSION_STAGE` bump — do
not bump the version until that phase's exit criteria is met in VICE, not
just "builds." Full-port verification (post-Phase 6) is the feasibility
plan's Verification Plan section, run in full.

## Progress

- 2026-07-09: Branch `feature/edlin-external-app` created. Phased plan
  drafted; no phase started.
- 2026-07-09: Phase 0 detail written and implemented — `src/external/edlin/`
  (`edlin.s`, `common.inc`, `BUILD_EDLIN`) created, `CMakeLists.txt`
  registration added (`EDLIN_SRCS`/`EDLIN_ENTRY` glob, `add_ca65_app(edlin
  ...)`, `EDLIN_TARGET` added to `IMAGE_PRG_TARGETS`). `test_image_d64`
  build verified clean, `edlin.prg` confirmed present in disk directory
  listing, build-number hash-gate confirmed working. VICE boot/banner
  verification initially hung under automated control (emulator hung
  mid-boot, user opted to skip rather than have raw-state poking
  attempted); user then drove VICE manually and confirmed the version
  banner prints as expected. **Phase 0 is complete.**
