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

## Phase 2 — Core read/navigate commands (`0.1.2`) — complete, verified

- [x] `cmds.s`: `L`ist and `P`age (hardcoded 40x25 paging, no dynamic IOCTL
      geometry per feasibility plan).
- [x] Line-number argument parsing: decimal, `.` (current), `#` (last+1).
- [x] Own line-input loop (GETIN-poll pattern copied from `shellReadLine`,
      not called into it — it's shell-internal).
- **Exit criteria**: `L`/`P` correctly display ranges and page at 24 lines;
  manual VICE pass against a multi-page test file — **met**. User verified
  in VICE against the 30-line `edlintest` fixture: bare `L` shows lines
  1-24; `1,5L` shows exactly lines 1-5; bare `P` shows lines 1-24 and
  repositions the current line to 24; a second bare `P` continues from
  25-30 with no overlap (confirms repositioning); `<N>,<N>P` used as a
  "jump to line N" workaround (documented below, since a dedicated jump
  command is Phase 3 scope). A real bug was found and fixed during this
  verification — see Progress below.

### Phase 2 detail

Ground truth for List/Page defaults comes straight from the real source —
read directly this session: `ms-dos/v4.0/src/CMD/EDLIN/EDLCMD1.ASM`,
`LIST` (line 569) and `PAGER` (line 499). Summarized below in terms of our
windowed-scan `findLine`, not the original's byte-pointer `FINDLIN`.

#### New file: `src/external/edlin/cmds.s`

Holds: line-number/range parsing, `L`ist, `P`age, the shared line-display
routine, and (new, see below) the interactive command loop's dispatch
table. `edlin.s`'s `start` shrinks to: load the buffer (Phase 1 logic,
unchanged), delete the Phase 1 temporary debug-dump block entirely (its
job is superseded by real `L`ist), then hand off to `cmds.s`'s command
loop.

**`printDec16` is promoted, not deleted.** The original phase note said
"temporary... delete before Phase 2" — that was about the *debug-dump
call site*, not the decimal-printing routine itself, which List/Page
need for line-number prefixes. Move it from `edlin.s` into `cmds.s`
(it's app-shared, not buffer-internal) and drop the "temporary" framing
from its header comment. (Also worth knowing for next time: there's
already a `printDecimal16` in `src/command64/utils.asm:117` — but that's
kernel-internal, not reachable via `OS_API` from an external `.prg`, so
`edlin`'s own copy was never actually redundant; the earlier "duplicate
work" note in Phase 1's Progress log was a false alarm.)

#### Persistent vs. transient zero-page — a needed distinction

Phase 1's `CurPtrLo/Hi`/`CurLineLo/Hi` were documented as EDLIN's
`POINTER`/`CURRENT` globals, but the Phase 1 implementation actually
treats them as `findLine`'s *transient per-call output* — fine for the
debug dump (one `findLine` call, read the result, done), but wrong now:
`List` must call `findLine` internally (to locate its start line) *without*
disturbing the editor's actual "current line," so a real persistent
"current line" needs to be a separate field `findLine` never touches.

- **New persistent field**: `EdCurrentLineLo`/`EdCurrentLineHi` (16-bit,
  1-based) — the editor's actual current line, initialized to `1` after
  `bufLoadFile` succeeds. Only commands documented as moving the current
  line (`Page` here; `edit-line`/`Insert`/`Delete`/`Quit` in Phase 3) ever
  write it, and only by explicitly copying `findLine`'s result into it
  after the fact. `List` never touches it.
- **Everything else stays transient/reusable scratch** — `CurPtr*`/
  `CurLine*` (raw `findLine` output), `WindowBaseOff*`/`WindowValidLen`,
  `TmpLen*`, `FindTarget*`, `ScanPtr*`/`EndPtr*`, `LineCount*`,
  `PdTableIdx`/`PdDigit`. None of these need to survive across a command
  boundary (the command loop is strictly sequential, never re-entrant),
  so new phases should default to **reusing** an existing transient field
  over claiming a fresh byte. The `$70-$8F` app-private range is getting
  tight (Phase 2 brings total usage to `$70-$8E`, 31 of 32 bytes) — worth
  flagging explicitly for Phase 3 planning rather than discovering it
  mid-implementation the way the VMM gap was discovered mid-Phase-1.

**New ZP for Phase 2** (documented in `common.inc` when implemented):

- `$88/$89` — `Line1Lo`/`Line1Hi`: holds the parsed line1 value while
  line2 is being parsed (transient, command-scratch category).
- `$8A` — `Line1Given`: 1 = a value was present for line1, 0 = defaulted.
- `$8B` — `Line2Given`: same, for line2.
- `$8C` — `PageRowCount`: rows printed since the last "Continue (Y/N)?"
  prompt, reset each screen (transient, command-scratch category).
- `$8D/$8E` — `EdCurrentLineLo`/`EdCurrentLineHi`: the one genuinely new
  **persistent** field this phase adds.

#### Line-number/range parsing

`parseLineNum` — input: index into the current input line buffer
(`EditBuf`, see below); output: parsed value in `FindTargetLo/Hi` (reused
directly — it's already "a line number destined for `findLine`"), a
1-byte "was anything present" flag, and the advanced buffer index.

- `.` → consume one char, value = `EdCurrentLineLo/Hi`.
- `#` → consume one char, value = call `findLine` with target `$FFFF`
  (full-buffer scan), then use `CurLineLo/Hi` (that's the real "last+1"
  meaning of a full scan's result, per the Phase 1 fix/finding).
- digit → accumulate a run of digits into a 16-bit value (`×10`, add
  digit, standard loop; no overflow checking — not worth it for a
  40-column screen's realistic line-count range).
- anything else → nothing present; flag = 0, `FindTargetLo/Hi` untouched
  (caller must not read it).

`parseRange` — parses `[line1][,line2]`, called with the input index
sitting right after the command's leading spaces are skipped:

1. `parseLineNum` → if present, copy `FindTargetLo/Hi` into `Line1Lo/Hi`,
   set `Line1Given=1`; else `Line1Given=0`.
2. Skip spaces; if next char is `,`, consume it, then `parseLineNum`
   again for line2 → if present, leave the value in `FindTargetLo/Hi`
   (that's exactly where the caller needs it next) and set
   `Line2Given=1`; else `Line2Given=0`.
3. Skip spaces; the next non-space byte is the command letter — return
   its buffer index for the dispatcher.
No `ParamCt`-style "too many params" error in this phase (original
EDLIN's `CMP ParamCt,2 / JA ComErr`) — with only `[line1][,line2]` legal
syntax and no third number possible, a malformed extra token just gets
treated as an unrecognized command letter and falls into the existing
"unrecognized command" error path. Revisit if a real need for a sharper
error message shows up.

#### `List` (command byte `$4C`, `'L'`)

1. `parseRange`.
2. line1: if `Line1Given`, use `Line1Lo/Hi`; else default =
   `max(1, EdCurrentLine - 11)` (mirrors `LIST`'s `SUB BX,11 / JA CHKP2 /
   MOV BX,1` exactly).
3. `findLine(line1)` → start offset in `CurPtrLo/Hi`. If `line1` is past
   EOF (`CurLineLo/Hi` from the call didn't reach the requested target —
   i.e. `findLine` hit its own EOF path), print nothing and return to the
   command loop (mirrors `LIST`'s `retnz` bail-out).
4. line count to print: if `Line2Given`, `count = Line2 - line1 + 1`
   (must be `> 0`, else fall into the unrecognized-command-style error
   path — no backwards listing, mirrors `LIST`/`PAGER`'s `comerr` on
   `param2 < param1`); else default `count = SCREEN_LINES - 1` (24, one
   screen minus a row for the prompt — mirrors the real source's
   `disp_len - 1`).
5. Call the shared display routine (below) with `(start offset, count)`.
6. Does **not** touch `EdCurrentLine*` — `List` is read-only positioning,
   confirmed by the real `LIST` routine never writing `[CURRENT]`.

#### `Page` (command byte `$50`, `'P'`)

1. `parseRange`.
2. line1: if `Line1Given`, use it; else default = `EdCurrentLine + 1`,
   unless `EdCurrentLine` is `1`, in which case default = `1` (mirrors
   `PAGER`'s `CMP BX,1 / JE frstok`).
3. line2: if `Line2Given`, use it; else default = `line1 + (SCREEN_LINES
   - 2)` (mirrors `PAGER`'s `disp_len - 2` end-line math), clamped to the
   real last line (call `findLine($FFFF)` once to get it if needed).
4. Validate `line2 >= line1` (else error, no backwards paging).
5. `findLine(line1)` → start offset. Call the shared display routine
   with `(start offset, line2 - line1 + 1)`.
6. **Reposition the current line**: `findLine(line2)` again → copy its
   `CurLineLo/Hi`/`CurPtrLo/Hi` result into `EdCurrentLineLo/Hi` (only the
   line number is actually needed persistently, per the ZP-budget note
   above — no persistent pointer field). This is `Page`'s distinguishing
   behavior vs. `List`, straight from `PAGER`'s own `MOV [CURRENT],DX`.

#### Shared display routine: `displayLines(startOffsetLo/Hi, countLo/Hi)`

Not a reuse of `findLine`'s internals (different job — printing, not
counting — and trying to share control flow between the two would cost
more clarity than it saves in 6502 asm). Structure, mirroring
`findLine`'s existing `BufIsVmm` branch:

1. `CurPtrLo/Hi = startOffsetLo/Hi`; line-number-being-printed counter =
   `EdCurrentLine`-independent — actually the line *number* of the first
   printed line must be tracked separately for the `NNNNN:` prefix; reuse
   `CurLineLo/Hi` for this (set from whatever `findLine(line1)` returned
   just before the call).
2. Loop `count` times:
   - Copy the current line number into `ScanPtrLo/Hi`, `jsr printDec16`
     (this destroys `ScanPtrLo/Hi`/`TmpLenLo/Hi` — expected, they're
     transient scratch, not needed again until the next line), then print
     `:` and a space via `DOS_PRINT_CHAR`.
   - Print line text: scan forward from `CurPtrLo/Hi` (VMM: through
     `scanWindow`/`bufReadWindow`, refilling as needed, exactly like
     `findLine`'s inner scan loop; RAM fallback: direct indexed byte
     read) printing each byte via `DOS_PRINT_CHAR` until hitting `$0A`
     (don't print it) or `BufEnd` (stop the whole routine — ran out of
     buffer before `count` was reached, not an error). Advance
     `CurPtrLo/Hi` past the terminator; increment `CurLineLo/Hi`.
   - Print `PetCr` (end the screen line).
   - `inc PageRowCount`; if it hits `SCREEN_LINES - 1` (24): print the
     `"Continue (Y/N)?"` prompt (own line-input-style single-keypress
     read via `KernalGetIn` poll, not a full `EditBuf` line), reset
     `PageRowCount = 0`; if the answer isn't `Y`/`y` ($59/$79), stop the
     whole display routine early and return to the command loop (this is
     a genuine early-abort, distinct from the "ran out of buffer" case
     above, but both just return to the command loop the same way, so no
     separate status needed by the caller for this phase).

#### Own line-input loop

New routine in `edlin.s` (entry-point-local, not `cmds.s` — it's the
outermost interactive loop, not a command implementation), copying
`shellReadLine`'s pattern (`src/command64/shell.asm:178`) verbatim in
structure: `KernalGetIn` poll, `PetDel` destructive backspace, `PetCr`
terminates, writes into a new `EditBuf` (80 bytes, `.res` in `BSS`,
mirroring `CommandBuffer`'s size) with a null terminator (not the CR) at
the end, tracked length not needed beyond the null terminator itself
since all parsing here is null/space/comma-delimited scanning, same as
`CommandBuffer` parsing elsewhere in the codebase.

#### Command loop (in `edlin.s`, replaces the deleted Phase 1 debug dump)

```text
commandLoop:
    print "*" prompt (DOS_PRINT_CHAR)
    call ownLineInput          ; fills EditBuf
    skip leading spaces in EditBuf
    call parseRange            ; -> Line1/Line2/Given flags, index of command letter
    lda EditBuf,y               ; the command letter
    cmp #'L' ($4C) -> jsr cmdList
    cmp #'P' ($50) -> jsr cmdPage
    cmp #'Q' ($51) -> jmp exit  ; PLACEHOLDER ONLY -- see note below
    else -> print "?" error message
    jmp commandLoop
```

**`Q` is a deliberate, explicitly-scoped-down placeholder.** Phase 2's
stated scope is List/Page only, and real `Quit` (with its "Abort edit
(Y/N)?" confirmation) is Phase 3 work — but the command loop needs *some*
way to exit for this phase to be testable at all in VICE. Bare `Q` →
`DOS_EXIT` with no confirmation is the minimum needed; Phase 3 replaces
this dispatch entry with the real thing, it's not additive scope.

#### Verification steps for this phase

1. `cmake --build build --target test_image_d64` clean.
2. Extend `tests/edlin_test.txt` (or add a second fixture) to have more
   than 24 lines, so `List`/`Page`'s default screen-full behavior and the
   `"Continue (Y/N)?"` pagination both get exercised — the current
   4-line fixture can't exercise pagination at all.
3. Manual VICE pass: `edlin <multi-line file>`, then at the `*` prompt:
   - Bare `L` → shows a screen starting near the top, line numbers correct.
   - `1,5L` → shows exactly lines 1-5, no pagination prompt.
   - Bare `P` repeated a few times → each call advances through the file
     in screen-sized chunks (confirms `EdCurrentLine` repositioning).
   - A range large enough to trigger `"Continue (Y/N)?"` → confirm `Y`
     continues and `N` stops cleanly, back at the `*` prompt either way.
   - An out-of-range line number (e.g. `9999L`) → confirm it fails
     quietly (per `LIST`'s `retnz` bail) rather than crashing or printing
     garbage.
   - `Q` → exits cleanly back to the shell prompt.

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
- 2026-07-09: Phase 2 detail written, grounded directly in the real
  `LIST`/`PAGER` source (`ms-dos/v4.0/src/CMD/EDLIN/EDLCMD1.ASM`) rather
  than re-deriving defaults from memory. Key design decision: split
  zero-page into a small persistent-state category (now includes the new
  `EdCurrentLineLo/Hi`, decoupled from `findLine`'s transient
  `CurLine*`/`CurPtr*` output, since `List` must call `findLine` without
  disturbing the editor's actual current line) versus a reusable
  transient command-scratch category, and flagged that the `$70-$8F`
  budget will be down to 1 free byte after this phase — Phase 3 planning
  needs to either reuse transient fields or reconsider the range. Also
  corrected a Phase 1 Progress note: `printDec16` was never actually
  redundant with the kernel's `printDecimal16` (kernel-internal, not
  reachable from an external `.prg`) — it's promoted to permanent
  (moved into `cmds.s`) rather than deleted. No implementation started.
- 2026-07-10: Phase 2 implemented and verified.
  - `src/external/edlin/cmds.s` created: `parseLineNum`/`parseRange`,
    `cmdList`/`cmdPage`, shared `displayLines`/`displayLineText`,
    `promptContinue` (mirrors `format.s`'s `confirmDestructive` — checks
    both `$59` and `$79` for 'y', since some keyboard mapping modes
    deliver the shifted byte), and `printDec16` (moved from `edlin.s`,
    promoted from temporary to permanent per the Phase 2 detail note).
  - `edlin.s` rewritten: Phase 1's temporary debug dump deleted; added
    `EdCurrentLineLo/Hi` init (`=1`) after a successful load,
    `ownLineInput` (copies `shellReadLine`'s structure), `peekCommandByte`
    (scans past a range without touching `Line1`/`Line2`/`FindTarget`
    state, just to find the dispatch letter), and `commandLoop` (`*`
    prompt, dispatch on `L`/`P`/bare-placeholder `Q`/unknown-command `?`).
  - `common.inc` updated with the full Phase 2 ZP layout (`Line1Lo/Hi`,
    `Line1Given`, `Line2Given`, `PageRowCount`, and the new persistent
    `EdCurrentLineLo/Hi`) and the persistent-vs-transient documentation
    split. Budget now sits at `$70-$8E`, 31 of 32 bytes used.
  - `buffer.s` gained three new exports (`bufReadWindow`, `scanWindow`,
    `fallbackBuf`) so `cmds.s` can drive its own windowed line-text scan.
  - Test fixture (`tests/edlin_test.txt`) regenerated from 4 lines to 30
    numbered lines, specifically to exercise the `"Continue (Y/N)?"`
    pagination path the old fixture was too short to reach.
  - **Caught two bugs before ever touching VICE**, both by re-reading the
    code after ca65 assembled it clean: (1) `cmdList`/`cmdPage` never
    reset `Y` to `0` before calling `parseRange`, so it would've inherited
    whatever index `peekCommandByte` left it at instead of re-scanning
    the range from the start of `EditBuf` — fixed by adding `ldy #0`
    before each call. (2) `cmdList`'s range-validity check tested the
    sign of `LineCountHi` *after* adding 1 for the inclusive count,
    which isn't a reliable "line2 < line1" test — fixed to check the
    subtraction's own borrow (`bcc`) before the `+1`, matching the
    (correct) pattern `cmdPage` already used.
  - **A third bug only surfaced during live testing**: bare `P` right
    after `1,5L` only showed line 1 instead of a full screen. Root cause:
    `parseRange` only cleared `Line2Given` inside the "comma present but
    no number follows" branch — when there's no comma at all, it fell
    through without ever resetting the flag, so a stale `Line2Given=1`
    (and stale `FindTargetLo/Hi=1`) from the *previous* command's
    execution leaked into the next one, since `Line1Given`/`Line2Given`
    are zero-page scratch that persist across command-loop iterations,
    not per-call locals. Fixed by resetting `Line2Given` on the no-comma
    path too (`bne prNoLine2` instead of `bne prSkipSpaces2`). This is
    the kind of bug static review alone likely wouldn't have caught
    without deliberately tracing a *sequence* of commands, not just one
    in isolation — worth remembering for Phase 3, which has even more
    persistent state (`EdCurrentLine*`) that later commands must not
    assume is freshly initialized.
  - Also picked up mid-session: a stray VICE checkpoint left armed from
    Phase 1 debugging (never deleted, only disconnected-from) kept
    interrupting the user's manual testing by popping the monitor open
    on every file load. Deleted once identified. Lesson for future
    sessions: always delete checkpoints (not just disconnect) before
    handing control back for manual testing.
  - User-verified in VICE against the 30-line `edlintest` fixture: bare
    `L` (lines 1-24), `1,5L` (exact range), bare `P` (lines 1-24,
    current line -> 24), a second bare `P` (lines 25-30, no overlap,
    confirming the reposition), `<N>,<N>P` as a "jump to line N"
    workaround (no dedicated jump command exists yet — that's Phase 3's
    `NOCOM`/edit-line territory), and both special line-number tokens,
    `.` (current line) and `#` (last+1). `9999L` (out-of-range) and `Q`
    (exit) were not explicitly re-confirmed after the bug fixes, though
    their code paths are unchanged from what static review already
    covered.
  - `.`/`#` verification surfaced a user-education point worth recording,
    not a bug: `#` alone or as line1 (`#L`, `#P`) correctly displays
    nothing, since `#` means "one past the last line" — there's nothing
    to show *at* the insertion point after a file's real content. `#P`
    still has a real side effect even when it displays nothing, though:
    `Page` always repositions the current line to the end of its range,
    so `#P` silently moves the current line to `last+1`. That combination
    (a command that visibly does nothing but silently changes state) is
    exactly the kind of thing worth calling out to a user testing this,
    and worth remembering as real EDLIN-inherited behavior when Phase 3
    builds edit-line/Insert/Delete on top of the current-line concept.
    `#`'s actually-useful role is as line2 (e.g. `1,#L`/`.,#L`, "to the
    end of the file"), confirmed working once tried that way.
  - `VERSION_STAGE` bumped to `2` (`0.1.2`) in `edlin.s`.
  - **Phase 2 is complete.**
