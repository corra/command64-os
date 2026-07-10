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

#### Phase 0 verification steps

1. `cmake -B build && cmake --build build --target test_image_d64` — must
   succeed with `EDLIN` build number visibly incrementing on a second build
   after a no-op source touch.
2. Boot the resulting `test.d64` in VICE (`mcp__c64__vice_*` tools), `LOAD
   "EDLIN",8` / `RUN`, confirm the banner text reads `EDLIN V0.1.0.1000`
   (or current build number) and the app exits cleanly back to the shell
   prompt (`DOS_EXIT`'s `ahExit` must correctly unwind the `jsr $1000` stack
   depth — confirm shell prompt is still responsive after exit, not hung).

## Phase 1 — Buffer core (`0.1.1`) — complete, verified

- [x] **Prerequisite** (kernel, not app): add `DOS_VMM_READ`/`DOS_VMM_WRITE`
      block I/O primitives — see [Phase 1 detail](#phase-1-detail) below.
      Discovered while planning this phase: `DOS_ALLOC_MEM`/`DOS_FREE_MEM`
      exist, but no `OS_API` function lets an external app read/write bytes
      into REU memory it has allocated (`vmmReadByte`/`vmmWriteByte` are
      kernel-internal, never dispatched in `apiHandler`, and are
      single-byte-per-DMA-call besides). Full spec:
      `wiki/tasks/vmm-block-io.md`.
- [x] `buffer.s`: VMM-backed flat text buffer (`DOS_ALLOC_MEM` at startup),
      current line/pointer tracking, windowed-scan `findLine` (see detail)
      for virtual line numbering — **not** a literal byte-at-a-time
      `FINDLIN` port, since VMM access is block-oriented now.
- [x] Load an existing file into the buffer on startup (`DOS_OPEN_FILE` +
      streamed `DOS_READ_FILE` into a small C64-RAM chunk buffer, then
      `DOS_VMM_WRITE` each chunk into the VMM buffer).
- [ ] REU-absent fallback: `BufIsVmm`/fallback branch logic is implemented
      in `buffer.s`, but not exercised against an actual no-REU VICE
      config this session — carried forward, not a hard blocker (matches
      the "best-effort" note in this phase's verification steps below).
- **Exit criteria**: kernel — `DOS_VMM_READ`/`WRITE` round-trip verified in
  VICE (see `wiki/tasks/vmm-block-io.md`) — **met**. App — given a small
  test file, `edlin` loads it, and a temporary internal debug dump
  (stripped before Phase 2 exit) confirms correct line count and byte
  offsets — **met**: `BUFEND: 00084`, `LINE COUNT: 00004`,
  `LINE 1 OFFSET: 00000`, `LINE 2 OFFSET: 00024`, all correct against the
  4-line `edlintest` file, confirmed by the user in VICE.

Two real bugs were found and fixed while closing this phase out (both
recorded in Progress below): a `cc1541` filename-case mismatch that broke
the file load (nothing to do with the buffer/VMM code itself), and a
genuine off-by-one in `findLine`'s EOF handling that double-counted a
file's trailing line when it ends with a line-feed.

### Phase 1 detail

#### Part A — kernel prerequisite: VMM block I/O

Full scope/ABI/sub-tasks are in `wiki/tasks/vmm-block-io.md` (mirrors the
`DOS_SEND_COMMAND` prerequisite task that unblocked `format`). Summary:
`vmmReadBlock`/`vmmWriteBlock` in `src/command64/vmm.asm`, each a single
`vmmComputeAddress` call followed by one REU DMA burst (`REU_LEN_L/H` = the
caller's byte count, not a byte-count loop); `ahVmmRead`/`ahVmmWrite`
dispatch entries in `src/command64/api.asm`; `DOS_VMM_READ = $59`/
`DOS_VMM_WRITE = $5A` in both `include/command64.inc` and
`include/ca65/command64.inc`. This must land, build clean
(`command64.prg` rebuilt), and be verified in VICE **before** `buffer.s`
work starts — `buffer.s`'s design below depends on its exact ABI.

#### Part B — app-side buffer design

**Initial allocation.** On startup, `DOS_ALLOC_MEM` with `X/Y = $0400`
(1024 paragraphs = 16KB — `vmmAlloc` rounds up to whole 4KB pages, and
1024 paragraphs is already an exact 4-page multiple, so this requests
precisely 16KB, not 16KB-rounded-up-from-something-smaller). 16KB is a
starting size for Phase 1's "small test file" exit criteria, not a hard
ceiling — Phase 4's Append/Write streaming is what actually handles files
bigger than one allocation, same as DOS EDLIN's own sliding-window design.
Store the returned `X` (SegHi)/`Y` (Bank) as the buffer's base segment
identity (`VmmSegLo` is always 0 for a fresh page-aligned allocation, so
only SegHi/Bank need to be remembered).

**App-private zero page** (claims from the shared `$70-$8F` range per
`src/external/AGENTS.md`; document in `src/external/edlin/common.inc`
when implemented):

- `$70/$71` — `BufBaseSegHi`/`BufBaseBank`: VMM allocation identity
  (returned `X`/`Y` from `DOS_ALLOC_MEM`).
- `$72/$73` — `BufEndLo`/`BufEndHi`: end-of-text offset from buffer base
  (EDLIN's `ENDTXT`).
- `$74/$75` — `CurPtrLo`/`CurPtrHi`: byte offset of current line's start
  (EDLIN's `POINTER`).
- `$76/$77` — `CurLineLo`/`CurLineHi`: virtual current line number
  (EDLIN's `CURRENT`).
- `$78/$79` — `WindowBaseOffLo`/`WindowBaseOffHi`: VMM offset the scan
  window was last loaded from.
- `$7A` — `WindowValidLen`: bytes currently valid in the scan window
  (0 = empty/invalid).
- `$7B` — `BufIsVmm`: 1 = VMM-backed buffer, 0 = base-RAM fallback active.

`$7C-$8F` left open for Phase 3+ (insert/delete hole-shift scratch,
Phase 5 search/replace scratch).

**Scan window.** A 128-byte `scanWindow` array in `BSS` (sized to fit
`WindowValidLen` in a single byte with room to spare — not zero page, no
need). `findLine(target)` (the `FINDLIN` equivalent): decide whether to
scan forward from the cached `CurLine`/`CurPtr` or from buffer offset 0,
whichever is closer to `target` (mirrors DOS EDLIN's own fast-path
optimization — same rationale, cheaper on a windowed scan than a byte
loop). Then repeatedly: if the byte offset being scanned falls outside
`[WindowBaseOff, WindowBaseOff+WindowValidLen)`, issue one `DOS_VMM_READ`
to refill `scanWindow` from that offset (length = `min(128, BufEnd -
offset)`), then scan the window bytes for `$0A` (LF), counting lines and
advancing the offset until `target` is reached or the window is
exhausted (triggering another refill). Update `CurLine`/`CurPtr` to the
result before returning, so the next nearby lookup is cheap.

**File load.** `DOS_OPEN_FILE` (mode 0/read) on the given filename, then
loop: `DOS_READ_FILE` into a 128-byte C64-RAM chunk buffer, `DOS_VMM_WRITE`
that chunk to the VMM buffer at the current `BufEnd` offset, advance
`BufEnd` by the bytes actually read, repeat until `DOS_READ_FILE` reports
0 bytes (EOF). Phase 1's own exit criteria only requires this to work for
a file that fits the 16KB allocation — overflow handling is explicitly
Phase 4's job, not this phase's.

**REU-absent fallback.** If `DOS_ALLOC_MEM`'s `Carry` = 1 (no REU present,
or `VMM_ERR_NOMEM`), set `BufIsVmm = 0` and use a fixed `.res` array in
`BSS` (size TBD at implementation time, budgeted against whatever's left
of the app's `PRG_SIZE_HEX` allocation — likely a few KB) as the buffer
instead. Every buffer routine (`findLine`, and Phase 3's insert/delete)
branches on `BufIsVmm`: the fallback path is a direct indexed
read/write into the RAM array, no windowing needed since it's already
in addressable C64 RAM. Print a one-line notice (`DOS_PRINT_STR`) on
this path so the user knows they're in the reduced-capacity mode, rather
than silently capping file size with no explanation.

**Temporary debug dump** (Phase 1 exit criteria only, deleted before
Phase 2): a single extra keypress/branch in `edlin.s` that, after loading
a file, prints the computed line count (via repeated `findLine` calls
walking to EOF, or a dedicated one-pass line-counting routine reusing the
same windowed-scan primitive) and a couple of sampled byte offsets, so
correctness can be eyeballed in VICE without needing List/Page (Phase 2)
built yet.

#### Phase 1 verification steps

1. **Kernel first**: build `command64.prg` with the new
   `DOS_VMM_READ`/`DOS_VMM_WRITE` primitives, run the extended
   `tests/src/vmm/vmm.s` round-trip test in VICE (write a known pattern,
   read it back into a different C64 RAM location, byte-compare).
2. **App**: `cmake --build build --target test_image_d64`; boot `edlin`
   in VICE against a small (~1-2KB) known test file; confirm the debug
   dump's line count matches the file's actual line count and sampled
   byte offsets are correct.
3. If feasible, exercise the REU-absent fallback path (VICE machine
   config without a REU) and confirm the fallback notice prints and line
   counting still works against the bounded RAM buffer — best-effort if
   awkward to set up, not a hard blocker for the phase.

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
- 2026-07-09: Phase 1 detail written. Discovered mid-planning that the
  feasibility plan's assumption ("buffer lives in VMM via
  `vmmReadByte`/`vmmWriteByte`") doesn't hold — those are kernel-internal
  routines never wired into `apiHandler`'s dispatch, and are single-byte
  anyway. User chose to add a proper block-oriented kernel primitive
  (`DOS_VMM_READ`/`DOS_VMM_WRITE`) as a prerequisite rather than fall back
  to single-byte calls or drop VMM entirely — spec written to
  `wiki/tasks/vmm-block-io.md`, mirroring the `DOS_SEND_COMMAND`
  prerequisite precedent from the FORMAT app. Phase 1 detail now covers
  both the kernel primitive (Part A) and the app-side windowed-scan
  buffer design (Part B) that depends on it. No implementation started.
- 2026-07-09: Phase 1 implemented and verified.
  - Part A (kernel): `vmmReadBlock`/`vmmWriteBlock` added to
    `src/command64/vmm.asm`; `DOS_VMM_READ`/`DOS_VMM_WRITE` constants
    added to both `include/command64.inc` and `include/ca65/command64.inc`;
    `ahVmmRead`/`ahVmmWrite` dispatch added to `src/command64/api.asm`;
    documented in `wiki/api-reference.md`. `tests/src/vmm/vmm.s` extended
    with a write/read-back byte-compare round-trip. User ran it in VICE:
    "BLOCK READ/WRITE ROUNDTRIP OK!".
  - Part B (app): `src/external/edlin/buffer.s` created (`bufInit`,
    `bufLoadFile`, `bufReadWindow`, `findLine`); `common.inc` updated with
    the full ZP layout (grew from the original 7-field sketch to 20 bytes,
    `$70-$87`, once `bufReadWindow`/RAM-fallback scratch and the temporary
    `printDec16` debug-print needs were accounted for — documented inline).
    `edlin.s` wired up: command-line filename parsing (mirrors `label.s`'s
    `CommandBuffer`/`ParsePos` pattern), a temporary debug dump (line
    count + first two line offsets), and a temporary `printDec16` decimal
    printer — **note for Phase 2 cleanup**: a real `printDecimal16` utility
    already exists at `src/command64/utils.asm:117` and was only noticed
    after writing a duplicate; not worth reverting now since this whole
    debug-dump block is deleted before Phase 2 anyway, but don't repeat
    the duplication in real Phase 2+ code.
  - Added `tests/edlin_test.txt` (4 lines) and a `cc1541`-based
    `EDLINTEST`/`edlintest` SEQ-file append step in `CMakeLists.txt` for
    the load test.
  - **Bug #1 (real, load-breaking)**: the `cc1541 -f "EDLINTEST"` call
    used uppercase, which `cc1541`'s ASCII→PETSCII conversion stores as
    *shifted* PETSCII bytes in the directory entry — but a user typing
    `edlintest` unshifted at the keyboard produces *unshifted* bytes, so
    `KernalOPEN` couldn't byte-match the name. It didn't surface as an
    open error (well-known KERNAL quirk: SEQ open failures only appear on
    the first read), so the app perceived a "successful" open followed by
    a 1-byte read then immediate EOF. Root-caused entirely through static
    analysis — extracted the raw directory-entry and file-content bytes
    straight from the built `.d64` with a throwaway Python script to
    confirm the byte-level mismatch — no emulator needed. Fixed by
    lowercasing the `cc1541 -f` argument to match the existing `testseq`
    convention.
  - **Bug #2 (real, off-by-one)**: `findLine`'s EOF path unconditionally
    added 1 for "a trailing partial line," double-counting when the
    file's last byte is itself a line-feed (the normal case for a text
    file). Fixed by only adding that increment when `CurPtr != BufEnd` at
    EOF. Verified correct by hand-simulating the algorithm in Python
    against the real file bytes before touching VICE again, then
    confirmed live: `edlin edlintest` now reports `BUFEND: 00084`,
    `LINE COUNT: 00004`, `LINE 1 OFFSET: 00000`, `LINE 2 OFFSET: 00024` —
    all correct.
  - REU-absent fallback path exists in the code but was not exercised
    against an actual no-REU VICE config this session (see Phase 1
    checklist above) — carried forward, not a blocker.
  - `VERSION_STAGE` bumped to `1` (`0.1.1`) in `edlin.s`, matching this
    phase's completion per the version-per-phase convention.
  - Notable process point: mid-debugging, live VICE interaction became
    unavailable (user couldn't interact; prior automated attempts had
    hung ~30 minutes) and [[feedback-vice-testing]] explicitly rules out
    improvising with raw memory/keyboard-buffer pokes as a workaround —
    both bugs were ultimately root-caused through static code review and
    direct `.d64`/Python byte-level inspection instead, with live VICE
    checks used only to confirm the fix once ready, not to iteratively
    hunt for the bug.
  - **Phase 1 is complete.**
