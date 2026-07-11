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

- [x] `buffer.s`: `bufOpenHole`/`bufCloseHole` byte-wise VMM/RAM shift
      primitives, plus a `bufWriteBytes` helper (see detail below).
- [x] Blank-line **edit-line** command (default `current+1`), echoes the
      existing line then replaces it via close-hole/open-hole.
- [x] `I`nsert (`[line]I`, open-hole per typed line, read lines until blank).
- [x] `D`elete (`[line1][,line2]D`, defaults to current), closes the hole.
- [x] `Q`uit with "Abort edit (Y/N)?" confirmation, discards buffer
      (replaces the Phase 2 bare-exit placeholder).
- **Exit criteria**: insert/delete/edit-line round-trip correctly against
  `L`ist output in VICE; no buffer corruption across repeated hole
  open/close; `Q` prompts and only exits on Y. **Code complete, builds
  clean — VICE verification not yet run** (see Progress). `VERSION_STAGE`
  deliberately left at `'2'` (not bumped to `'3'`) until that verification
  passes, per this plan's own convention.

### Phase 3 detail

Ground truth for Delete/NOCOM(edit-line)/Insert/Replace/Quit comes from the
real source, read directly this session: `ms-dos/v4.0/src/CMD/EDLIN/
EDLCMD1.ASM` (`DELETE` line 448, `NOCOM` line 618), `EDLIN.ASM` (`INSERT`
line 1366), `EDLCMD2.ASM` (`REPLACE` line 524, `QUIT` line 876). Summarized
below in terms of our windowed-scan/VMM-block model, not the original's
`REP MOVSB` byte-block moves or its `.$$$`/abort-vector machinery (both
already cut per the feasibility plan).

#### ZP budget is exhausted — new scratch goes in plain BSS, not `$70-$8F`

`common.inc:20` already flags the app-private ZP range at 31/32 bytes used
after Phase 2 (`$8F` is the only byte left). Hole-shift bookkeeping needs
more than one byte, and — critically — **none of it needs `(zp),Y` indirect
addressing**: every new field here is either compared/added directly or
used to populate `VmmOffLo/Hi`/`WindowBaseOffLo/Hi` before a call, never
dereferenced as a 6502 zero-page pointer itself. So Phase 3's new state is
plain absolute-addressed `BSS` in `buffer.s`/`cmds.s`, not a claim on
`$70-$8F`. This sidesteps the budget problem entirely rather than fighting
over the last byte or expanding the shared range (which would need an
`AGENTS.md` update apps beyond `edlin` would have to account for).

Also a deliberate departure from Phase 1/2's "reuse transient ZP fields
aggressively" pattern: Delete/Insert/edit-line each thread a value (a byte
offset, a numeric line number, a length) across *several* nested `findLine`
calls within one command body. Phase 2's one real post-implementation bug
(`Line2Given` leaking stale state across command-loop iterations, see that
phase's Progress entry) came from exactly this kind of implicit
cross-call lifetime tracking. Phase 3 commands are long enough, and the
`BSS`-not-`ZP` decision above removes the scarcity pressure that motivated
aggressive reuse in the first place — so each command below gets its own
clearly-named field instead of overloading e.g. `Line1Lo/Hi` to silently
switch meaning mid-routine.

**New `BSS` fields** (documented alongside `scanWindow`/`fallbackBuf` in
`buffer.s`, and alongside `Line2ValLo/Hi` in `cmds.s`):

- `buffer.s`: `ShiftSrcLo/Hi`, `ShiftRemainLo/Hi`, `HoleSizeLo/Hi` (6 bytes
  — `bufOpenHole`/`bufCloseHole`'s own loop bookkeeping, see below).
- `cmds.s`: `DelStartLo/Hi` (Delete's saved range-start byte offset),
  `DelLineLo/Hi` (Delete's saved line1 *number*, for repositioning
  `EdCurrentLine` after the shift), `InsLineLen` (1 byte — Insert/edit-line's
  typed-line length, capped at 79 by `EditBuf`'s size so one byte is
  enough), `OldLineLenLo/Hi` (edit-line's saved old-line byte length),
  `SavedOffsetLo/Hi` (edit-line's saved line-start offset, snapshotted
  before `displayLineText` advances `CurPtrLo/Hi`). 13 bytes total, all
  plain `BSS`.

#### New `buffer.s` primitives

**`bufWriteBytes`** — Input: `CurPtrLo/Hi` = destination buffer offset;
`X/Y` = pointer to source bytes in C64 RAM; `A` = byte count (≤128, safe
since callers are always writing at most a 79-byte `EditBuf` line + 1 LF
byte, well under `WINDOW_SIZE`). Output: bytes written at that offset
(VMM: one `DOS_VMM_WRITE` with `VmmOffLo/Hi = CurPtr`; RAM fallback: direct
indexed copy into `fallbackBuf + CurPtr`). Does **not** touch `BufEnd` or
advance `CurPtr` — callers manage that themselves, since `bufOpenHole`
already adjusts `BufEnd` on its own and Insert needs to advance `CurPtr` in
a per-typed-line loop. Exported for `cmds.s` to call directly.

**`bufOpenHole`** — Input: `CurPtrLo/Hi` = offset to open the hole at;
`HoleSizeLo/Hi` = hole size in bytes. Output: Carry=0 and `BufEnd` increased
by `HoleSizeLo/Hi` on success; Carry=1 (no changes made) if `BufEnd +
HoleSize` would exceed the buffer's allocation ceiling (`BUF_ALLOC_PARAGRAPHS`
worth of bytes for VMM, `FALLBACK_BUF_SIZE` for RAM) — this is Phase 3's
"buffer full" error path, there is no growth-on-demand until Phase 4.
`CurPtrLo/Hi` itself is left unchanged (still the hole's start, ready for
the caller to write into via `bufWriteBytes`).

Algorithm (VMM path) — shifts `[CurPtr, BufEnd)` up to `[CurPtr+HoleSize,
BufEnd+HoleSize)`, working from the **end backward** in `WINDOW_SIZE`
chunks so a chunk is always read before the (higher, not-yet-relocated)
memory it will be written into is touched:

```text
ShiftRemain = BufEnd - CurPtr
ShiftSrc    = BufEnd
loop:
    if ShiftRemain == 0: BufEnd += HoleSize; clc; rts
    chunkLen = min(WINDOW_SIZE, ShiftRemain)
    ShiftSrc -= chunkLen                  ; this chunk's start
    read chunkLen bytes at ShiftSrc into scanWindow   ; raw VMM_READ,
                                                       ; no bufReadWindow
                                                       ; auto-clamp (exact
                                                       ; caller-known length)
    write chunkLen bytes to (ShiftSrc + HoleSize)     ; raw VMM_WRITE
    ShiftRemain -= chunkLen
    jmp loop
```

RAM fallback: same shape, but no windowing needed — a plain backward
byte-copy loop within `fallbackBuf` using `ScanPtrLo/Hi`/`EndPtrLo/Hi` as
source/dest pointers and `TmpLenLo/Hi` as the remaining-byte counter
(reusing these three existing transient names is safe here: fallback-path
shifts don't call anything else that clobbers them mid-loop, unlike the
VMM path's nested nested `bufReadWindow`-shaped calls).

**`bufCloseHole`** — same signature, opposite direction and reason: shifts
`[CurPtr+HoleSize, BufEnd)` **down** to `[CurPtr, BufEnd-HoleSize)`,
working **forward** (low to high) since the destination is always lower
than the source here, so no overlap risk copying in that order. `BufEnd -=
HoleSize` on completion. No failure mode (closing a hole never grows the
buffer), so no Carry-based error path — callers are expected to have
already validated `CurPtr + HoleSize <= BufEnd` via `findLine`.

#### `Delete` (command byte `$44`, `'D'`)

1. `ldy #0; jsr parseRange`.
2. `line1` = `Line1Given` ? `Line1Lo/Hi` : `EdCurrentLineLo/Hi`. `line2` =
   `Line2Given` ? the value `parseRange` left in `FindTargetLo/Hi` : `line1`
   (mirrors `DELETE`'s `DelParm2` default-to-`Param1`) — **capture this into
   `DelLineLo/Hi` immediately**, before any `findLine` call clobbers
   `FindTargetLo/Hi`.
3. Validate `line2 >= line1` via the subtraction-borrow check (same pattern
   as `cmdList`'s `clBadRange`) — else return, no error message needed
   beyond the existing silent-bail convention Phase 2 already established
   for bad ranges.
4. `FindTargetLo/Hi = line1; jsr findLine`. If `CurLineLo/Hi != line1`
   (out of range) → return, nothing deleted. Else stash `CurPtrLo/Hi` into
   `DelStartLo/Hi` (the range's start byte offset) and stash `line1`
   itself into `DelLineLo/Hi` (needed again in step 7, after `DelLineLo/Hi`
   is repurposed... — no, keep this in a second field; see the "new BSS
   fields" list above, `DelLineLo/Hi` holds the *numeric* line1 value
   specifically so step 4's offset stash in `DelStartLo/Hi` doesn't have to
   double as both a byte offset and a line number across the rest of the
   routine).
5. `FindTargetLo/Hi = line2 + 1; jsr findLine` → `CurPtrLo/Hi` = one past
   the deleted range (or `BufEnd`, if `line2` was the last line).
6. `HoleSizeLo/Hi = CurPtrLo/Hi - DelStartLo/Hi`.
7. `jsr bufCloseHole` with `CurPtrLo/Hi` temporarily reset to
   `DelStartLo/Hi` (the hole's start) before the call.
8. `EdCurrentLineLo/Hi = DelLineLo/Hi` (mirrors `DELETE`'s `POP Current` —
   current becomes the deleted range's starting line number, since
   whatever used to be the next line now occupies that number; if the
   deletion reached EOF this naturally becomes a "last+1"-style value,
   same as after an end-of-buffer `Insert`, which is expected/consistent).

#### `Insert` (command byte `$49`, `'I'`)

1. `ldy #0; jsr parseRange`. If `Line2Given` → return (mirrors `INSERT`'s
   `CMP ParamCt,1 / JBE OKIns` — at most one param is legal here, a real
   EDLIN would `ComErr` on `n,mI`; Phase 3 reuses the established silent-bail
   convention rather than adding a distinct error message).
2. Target line = `Line1Given` ? `Line1Lo/Hi` : `EdCurrentLineLo/Hi`. Keep
   running in `Line1Lo/Hi` itself (its job as "the parsed line1 value" is
   done once copied out; reusing it as the loop's insert-line counter is
   safe and intentional here — unlike Delete/edit-line, Insert's loop body
   never calls anything that reinterprets `Line1Lo/Hi`, so this one reuse
   doesn't reintroduce the Phase 2 stale-state risk).
3. `FindTargetLo/Hi = Line1Lo/Hi; jsr findLine` → `CurPtrLo/Hi` = insertion
   byte offset. If `CurLineLo/Hi != Line1Lo/Hi` (out of range, and not the
   legitimate "append at EOF" case, which `findLine`'s own EOF path already
   returns as an exact match against `last+1`) → return.
4. Loop:
   a. Copy `Line1Lo/Hi` into `ScanPtrLo/Hi` (non-destructively — `Line1Lo/Hi`
      keeps counting), `jsr printDec16`, print `":"` + `" "` (same prefix
      style as `displayLines`).
   b. `jsr ownLineInput` → fills `EditBuf`.
   c. Compute typed length into `InsLineLen` (scan `EditBuf` for the null
      terminator; ≤79 so one byte suffices).
   d. If `InsLineLen == 0` → blank line typed, insertion ends: go to step 5.
   e. `EditBuf[InsLineLen] = $0A` (append the line terminator in place —
      turns one `bufWriteBytes` call into "text + LF" together).
      `HoleSizeLo/Hi = InsLineLen + 1`.
   f. `jsr bufOpenHole`. If Carry=1 (buffer full): print `"ERROR: BUFFER
      FULL."`, go to step 5 (mirrors `INSERT`'s `MEMERR` path — abort the
      insert and return to the command loop, no attempt to grow the
      allocation this phase).
   g. `jsr bufWriteBytes` with `X/Y = <EditBuf,>EditBuf`, `A = InsLineLen+1`.
   h. `CurPtrLo/Hi += (InsLineLen + 1)` (16-bit add, next insertion point).
   i. Increment `Line1Lo/Hi` (next line number). Loop to (a).
5. `EdCurrentLineLo/Hi = Line1Lo/Hi` (positions current at the line after
   the last one actually inserted — or the original target, unchanged, if
   the very first prompt was answered with a blank line: a legitimate
   no-op insert).

**Known limitation, worth calling out explicitly**: this makes a truly
blank *inserted* line unreachable (blank always means "stop"), unlike real
DOS EDLIN where insertion only ends on Ctrl-Z/EOF and a bare CR inserts an
empty line. This was already the implied tradeoff in this phase's original
checklist wording ("read lines until blank/EOF") — recorded here as a
conscious scope cut, not an oversight, since there's no easy C64-keyboard
equivalent of DOS's Ctrl-Z-terminated stdin.

#### `edit-line` (blank command letter — dispatch changes in `edlin.s`)

Phase 2's `commandLoop` currently treats a blank command letter
(`cpx #0 / beq commandLoop`) as a silent reprompt. **This changes in Phase
3**: `cpx #0 / bne clNotBlank` → `jsr cmdEditLine` → `jmp commandLoop`. A
bare `[line]` + Enter (DOS EDLIN's `NOCOM`) now positions and optionally
edits a line, rather than being a no-op — flagging this since it's an easy
behavior change to miss when touching the dispatch table.

1. `ldy #0; jsr parseRange`. If `Line2Given` → return (mirrors `NOCOM`'s
   `CMP ParamCt,2 / JB NoComOK` — at most one param legal).
2. Target = `Line1Given` ? `Line1Lo/Hi` : `EdCurrentLineLo/Hi + 1` (no
   overflow clamp — not a realistic concern at this buffer's line-count
   range, same pragmatism already used in `parseLineNum`'s digit parsing).
3. `FindTargetLo/Hi = target; jsr findLine` → `CurPtrLo/Hi`, `CurLineLo/Hi`.
4. `EdCurrentLineLo/Hi = CurLineLo/Hi` **unconditionally**, before checking
   anything else (mirrors `NOCOM`'s unconditional `MOV [CURRENT],DX` ahead
   of its EOF check — this is what makes bare-CR "walk through the file"
   navigation work even when nothing gets edited).
5. If `CurPtrLo/Hi == BufEndLo/Hi` (target at/past EOF, nothing there) →
   return (mirrors `NOCOM`'s `CMP SI,[ENDTXT] / retz`).
6. Snapshot `CurPtrLo/Hi` into `SavedOffsetLo/Hi` (the line's start —
   needed again after the echo/edit steps below advance `CurPtr`). Echo the
   existing line: print the line-number prefix (same `printDec16` + `": "`
   pattern as `displayLines`), then `jsr displayLineText` (prints the text
   and advances `CurPtrLo/Hi` past the terminator — a convenient, deliberate
   reuse: it also tells us the old line's length). `OldLineLenLo/Hi =
   CurPtrLo/Hi - SavedOffsetLo/Hi - 1` if `displayLineText` stopped on an
   `$0A` (the common case), or `CurPtrLo/Hi - SavedOffsetLo/Hi` if it
   stopped by hitting `BufEnd` with no terminating LF (the file's last,
   unterminated line). Print `PetCr` to end the echoed line before
   prompting for the replacement.
7. `jsr ownLineInput` → `EditBuf`. Compute typed length into `InsLineLen`
   (same strlen loop Insert uses — the two commands never run concurrently,
   sharing the field is safe).
8. If `InsLineLen == 0` → no change, return (mirrors `NOCOM`'s `JCXZ RET12`
   — `EdCurrentLineLo/Hi` was already set in step 4, so repeated bare CRs
   walk the file one line at a time with no edits, matching real EDLIN's
   documented "quick lister" use of this command).
9. Otherwise, replace — a close-then-open pair rather than DOS `REPLACE`'s
   single signed-delta shift (simpler to build on the two primitives above;
   costs an extra shift pass when the line's length changes, an acceptable
   tradeoff on a 1541-class machine, consistent with the feasibility plan's
   existing "byte-wise VMM shift over `REP MOVSB`" tradeoff call):
   a. `CurPtrLo/Hi = SavedOffsetLo/Hi; HoleSizeLo/Hi = OldLineLenLo/Hi + 1`;
      `jsr bufCloseHole` (deletes the old line + its LF entirely).
   b. `EditBuf[InsLineLen] = $0A`; `CurPtrLo/Hi = SavedOffsetLo/Hi;
      HoleSizeLo/Hi = InsLineLen + 1`; `jsr bufOpenHole` (Carry=1 possible
      here too — print the same `"ERROR: BUFFER FULL."` message and return
      without writing if so, leaving the old line already-deleted; a real
      but narrow edge case — a replace that fails to reopen its own freed
      space would need the freed space back for the message alone, and the
      close in (a) already shrank `BufEnd`, so this can only fail if the
      *new* text is longer than the old and the buffer was already nearly
      full — acceptable to leave as a data-loss edge case for v1 rather
      than adding rollback machinery, matching the "no `.BAK`/crash-safety"
      scope cut already made for saves).
   c. `jsr bufWriteBytes` with `X/Y = <EditBuf,>EditBuf`, `A = InsLineLen+1`.

#### `Quit` (command byte `$51`, `'Q'`, replaces the Phase 2 placeholder)

`promptContinue` (`cmds.s`) is generalized to `promptYN(X/Y = message
pointer)` — a legitimate, non-speculative factor-out: Quit needs the exact
same Y/N-poll logic (`KernalGetIn` poll, checks both `$59`/`$79`) with a
different prompt string, so this is two real call sites sharing identical
logic, not a hypothetical future need. `cmdList`/`cmdPage`'s existing calls
update to `ldx #<msgContinue; ldy #>msgContinue; jsr promptYN`.

`cmdQuit`:

1. `ldx #<msgAbortEdit; ldy #>msgAbortEdit; jsr promptYN` (new string,
   `"ABORT EDIT (Y/N)? "`, in `cmds.s`'s `RODATA`).
2. If `A == 1` (yes) → `jmp exit` (the existing `DOS_EXIT` path in
   `edlin.s` — buffer is simply discarded, no save; matches the "skip
   `.BAK`/rename dance" scope cut, since Quit never had a save step to
   begin with).
3. Else → `rts` (back to the command loop). Unlike real `QUIT`'s
   reprompt-forever loop on an unrecognized answer, one prompt/one answer
   is enough here, consistent with `promptContinue`'s existing simpler
   convention from Phase 2 (any non-Y answer is treated as "no").

`edlin.s`'s dispatch: `cpx #'Q' / bne clNotQuit / jsr cmdQuit / jmp
commandLoop` (replaces the Phase 2 `jmp exit` placeholder — `cmdQuit`
itself jumps to `exit` internally on a Y answer, so it only ever falls
through to `jmp commandLoop` on N).

#### Phase 3 verification steps

1. `cmake --build build --target test_image_d64` clean.
2. Manual VICE pass against `tests/edlin_test.txt` (or a fresh scratch
   file so saves aren't needed yet — Write is Phase 4):
   - `I` at a target line, type several lines, blank line to end — `L`ist
     confirms the new lines appear in the right place with correct
     numbering, and later original lines shifted down correctly.
   - `[line1],[line2]D` — `L`ist confirms the range is gone and later lines
     renumbered down with no corruption at the hole's old boundary.
   - Bare CR (`edit-line`) repeated a few times — confirms it walks the
     file one line at a time with no edits when answered blank each time.
   - `edit-line` with an actual replacement typed — confirms the line's
     text changed and neighboring lines are intact, both when the new
     text is shorter and when it's longer than the original (exercises
     both `bufCloseHole`+`bufOpenHole` size directions).
   - Insert/delete repeated several times in sequence (not just once each)
     to catch any hole-shift-introduced buffer corruption that only shows
     up after repeated open/close cycles.
   - `Q` → confirms the `"ABORT EDIT (Y/N)?"` prompt appears; `N` returns
     to the `*` prompt with the buffer intact (confirm via `L`ist); `Y`
     exits cleanly back to the shell prompt.
   - Attempt to fill the 16KB allocation via repeated large inserts (or a
     large pasted-in test file) to confirm `bufOpenHole`'s Carry=1
     "buffer full" path prints its message and aborts the insert cleanly
     rather than corrupting state.
3. If feasible, exercise the same insert/delete/edit-line/quit sequence
   against the RAM-fallback path (no-REU VICE config) — best-effort, same
   caveat as Phase 1's fallback verification. **Deferred** — see
   `task 22` (`command64.edlin` project, `+phase3 +deferred`): "EDLIN
   Phase 3: exercise REU-absent fallback path (test section 10) against
   no-REU VICE config."

## Phase 4 — Save/streaming (`0.1.4`)

- [x] **Prerequisite bug fix** (found while planning this phase, landed
      ahead of it): `bufLoadFile` had no ceiling check against the
      buffer's allocation — loading a file bigger than 16KB (or 2KB in
      RAM-fallback) silently wrote past the VMM segment's bounds into
      whatever REU segment sits next (the REU is carved into fixed
      per-purpose segments shared with other apps/the OS's own App
      Table, not free space — this is what actually corrupted the App
      Table during earlier testing, not a Phase 4-specific issue). Fixed
      with the same Carry=1 "reject cleanly" convention `bufOpenHole`
      already established in Phase 3. An identical off-by-one in
      `bufOpenHole`'s own ceiling check (rejected a hole that would
      exactly fill the buffer, instead of only rejecting when it would
      exceed it) was caught and fixed alongside it. See Progress.
- [x] **New-file creation support** (found while planning this phase — the
      feasibility plan's own verification workflow, "create a file with
      `edlin newfile.txt`," was never actually possible: a missing file
      made `edlin.s` treat *any* open failure as fatal and exit
      immediately). `edlin.s`'s startup now distinguishes a device-level
      open failure (no device/no disk/other drive error — still fatal)
      from a generic KERNAL open failure (in practice, "file not found")
      — the latter now starts an empty buffer instead of exiting, printing
      `"NEW FILE."` rather than an error.
- [x] `W`rite command: stream the whole buffer to disk in one pass, direct
      overwrite (`DOS_DELETE_FILE` then `DOS_OPEN_FILE` mode=1 — no
      `.BAK`/`.$$$` rename dance, per feasibility plan decision 4). Code
      complete, builds clean — VICE verification not yet run (see
      Progress).
- **Scope note — `A`ppend is deferred, not part of this phase.** The
  original bullet here committed to DOS EDLIN's sliding-window Append/Write
  (fill-to-3/4, flush-to-1/4) for files bigger than one VMM allocation.
  That scheme exists specifically to work around the 8086's 64KB
  conventional-memory segment ceiling — growing the VMM allocation instead
  looked like the obvious fix (REU capacity is generous, 1MB+ per
  `vmm.inc`), but **the REU is a shared, segmented resource other apps and
  the OS's own App Table also live in — it is not free space `edlin` can
  just claim more of.** Given that constraint, real sliding-window
  streaming (keeping the 16KB buffer fixed, paging file content in/out
  through it, DOS-style) is the only way to support files bigger than one
  allocation — and that's a substantial addition (window-relative line
  numbering, two more commands, large-file test fixtures) deliberately
  **deferred to a v2 item, tracked as `task 23`** (`command64.edlin`
  project, `+v2 +deferred`). This phase's `W` only ever writes what
  Phase 1's `bufLoadFile` was able to load in one shot — which, per the
  ceiling-check fix above, is now a clean, safe failure rather than silent
  corruption for anything that doesn't fit.
- **Exit criteria**: create file (`edlin newfile.txt` on a nonexistent
  name) → insert/delete → `W`rite → reload → `L`ist matches expected
  content. A file larger than the 16KB buffer is rejected cleanly at load
  (already verified via the prerequisite fix) rather than round-tripped —
  that case is `task 23`'s job, not this phase's. **Code complete, builds
  clean — VICE verification not yet run.** `VERSION_STAGE` deliberately
  left at `'3'` (not bumped to `'4'`) until that verification passes, per
  this plan's own convention.

### Phase 4 detail

Ground truth for the file-write ABI came from reading `src/command64/
file.asm` directly (`fileOpen`, `fileWrite`, `fileDelete`) rather than
assuming generic C64 KERNAL behavior — a Task agent was used for this
lookup and its findings were spot-checked against the actual source
(`file.asm:183-303` for `fileOpen`, `:407-481` for `fileWrite`, `:483-541`
for `fileDelete`) before being relied on, per
[[feedback-verify-agent-hardware-claims]].

#### File-write ABI (new to this port — Phases 1-3 only ever read)

- **`DOS_OPEN_FILE` write mode**: `HexValLo = 1` (vs. `0` for read, already
  used by `bufLoadFile`). `HexValHi` — if nonzero — sets the file type
  character appended after the filename (`fileOpen` defaults to unshifted
  `'P'`/PRG otherwise, `file.asm:251-254`); since a text file must stay a
  SEQ file, Phase 4's write path must explicitly set `HexValHi = $53`
  (unshifted `'S'`) before opening. Output is the same as read mode: `A` =
  handle, Carry 0/1.
- **No automatic overwrite from the C64-KERNAL side** — `fileOpen`'s write
  branch is a plain KERNAL `SETNAM`+`,W`+`SETLFS`+`OPEN`
  (`file.asm:243-289`, confirmed against the one existing write caller,
  the shell's `COPY` command at `shell.asm:1347-1358`, which has the same
  shape). On real 1541 DOS, opening an existing filename for write fails
  with error 63 (FILE EXISTS) *unless* the filename itself is prefixed
  `@0:` — 1541 DOS firmware's own save-replace convention: the **drive**
  writes the new file to a fresh directory slot and only removes/renames
  over the old one once the write completes successfully and the file is
  closed, so a failed or interrupted write leaves the original file
  untouched. This is a drive-firmware feature, not something the C64-side
  kernel needs to implement — `fileOpen` just needs to not mangle the
  `@0:` prefix on the way to `SETNAM`, which it doesn't: `normalizeName`
  only touches shifted A-Z characters, and `parsePointerDevice` only
  recognizes `8:`/`9:`/`1x:` prefixes, so `@0:` passes through as literal
  filename text untouched (both checked directly in `utils.asm`).
  **`cmdWrite` builds `@0:<filename>` itself before opening for write** —
  a strictly better fit than the delete-then-open sequence originally
  planned here (see Progress: that version was implemented first, then
  replaced once this was found). Tradeoff: needs enough free disk space
  to hold both the old and new file simultaneously during the write —
  the same class of cost as the `.BAK` dance decision 4 already accepted,
  but far cheaper to implement since it's zero extra host-side round
  trips (no explicit delete/rename call at all).
- **`DOS_WRITE_FILE`** (`fileWrite`, `file.asm:407-481`): unlike open, the
  handle goes in the `FileHandle` ZP location ($6D, same field
  `bufLoadFile` already uses for read), not a register — `X/Y` = source
  pointer, `HexValLo/Hi` = byte count in, `HexValLo/Hi` = bytes actually
  written out, Carry 0/1. Working example: `tests/src/filetest/
  filetest.s:40-51`.
- **`DOS_CLOSE_FILE`**: same as the read-side close `bufLoadFile` already
  uses.
- No end-of-file marker byte needs writing (unlike DOS's `$1A`) — 1541 SEQ
  files are read until the KERNAL hits the physical end of the block
  chain, no explicit terminator required.

#### `cmdWrite` (command byte `$57`, `'W'`) — new in `cmds.s`

Takes no arguments (unlike DOS's `EWRITE`/`WRT`, which accept an optional
line count for partial sliding-window flushes — not applicable here, the
whole buffer is always already resident). `commandLoop`'s dispatch never
even parses a range for it, matching `Quit`'s zero-argument shape.

1. Build `@0:<filename>` into a new scratch buffer, `WriteNameBuf` (20
   bytes: `"@0:"` + up to 16 filename bytes + null — 16 is the 1541's own
   filename length ceiling, used as a copy-loop safety cap). The filename
   source is `FilenamePtrLo/Hi` (the same pointer `edlin.s`'s startup
   already resolved and null-terminated in `CommandBuffer` for the
   initial load — `edlin.s` exports it, `cmds.s` imports it), but that
   pointer pair is **not itself in zero page** (`edlin.s`'s `BSS` loads at
   `$2E00+`, confirmed against `edlin_2E00.cfg`), so `(FilenamePtrLo),y`
   indirect-indexed addressing is invalid as-is — copy it into a ZP
   pointer pair first (reusing `ScanPtrLo/Hi`, already established
   transient scratch) before dereferencing it byte-by-byte into
   `WriteNameBuf+3`.
2. `DOS_OPEN_FILE` mode=1, `HexValHi = $53` ('S'), target = `WriteNameBuf`
   (not the bare filename). Carry=1 → print `"ERROR: COULD NOT WRITE
   FILE."`, `rts` back to the command loop (not a hard exit — matches this
   port's established preference for recoverable errors to return to the
   prompt rather than kill the session, e.g. `bufOpenHole`'s buffer-full
   path).
3. `sta FileHandle`.
4. Stream `[0, BufEnd)` out in `WINDOW_SIZE` chunks, reusing Phase 1's
   `bufReadWindow` directly (already `BufIsVmm`-branching and
   auto-clamping its length to `BufEnd` — no new read logic needed, only a
   write side):

   ```text
   WindowBaseOff = 0
   loop:
       if WindowBaseOff >= BufEnd: goto done
       bufReadWindow                    ; fills scanWindow, sets WindowValidLen
       DOS_WRITE_FILE(X/Y=scanWindow, HexValLo=WindowValidLen, HexValHi=0)
       if Carry=1: goto writeErr
       WindowBaseOff += WindowValidLen
       jmp loop
   ```

5. `done:` → `DOS_CLOSE_FILE`, `rts`. No "SAVED" confirmation message —
   matches this port's existing terse convention (List/Page/Insert/Delete
   don't print success confirmations either; DOS EDLIN itself doesn't for
   a plain `W`).
6. `writeErr:` → `DOS_CLOSE_FILE`, print `"ERROR: WRITE FAILED - DISK
   FULL?"`, `rts`.

No new persistent state needed — `WindowBaseOffLo/Hi`/`WindowValidLen`/
`scanWindow` are exactly the fields `bufReadWindow` already expects as its
own working state, so `cmdWrite` reuses them directly rather than adding
anything to the already-tight `BSS` scratch area.

**Divergence from DOS worth noting explicitly**: real `WRT` resets
`[CURRENT]` to line 1 after a write, because DOS's sliding buffer window
shifts after a flush. Our buffer never shifts in v1 (the whole file stays
resident the entire session, per the Append deferral above), so
`EdCurrentLineLo/Hi` is intentionally left untouched by `cmdWrite` — there's
nothing to reposition relative to.

#### `edlin.s` changes

- `.export FilenamePtrLo` / `.export FilenamePtrHi` (new — `cmds.s` needs
  them for `cmdWrite`'s save target).
- `.import cmdWrite`; dispatch table gains `cpx #'W' / bne clNotWrite / jsr
  cmdWrite / jmp commandLoop`, alongside the existing `D`/`I`/blank/`Q`
  entries.
- The new-file-creation and ceiling-check changes from the prerequisite
  fixes above (already landed, see Progress).

#### Phase 4 verification steps

1. `cmake --build build --target test_image_d64` clean.
2. New-file creation: `edlin brandnew` (a filename with no existing file)
   → confirm `"NEW FILE."` prints, not an error, and the command loop
   starts normally. **Known caveat, not a blocker**: `L` right after this
   will currently show one line of garbage (`task 24` — a kernel
   `fileRead` bug, not an EDLIN bug; see Progress) instead of a truly
   empty buffer. Don't treat that specific symptom as a Phase 4
   regression — note it and move on. Everything downstream of that
   (insert, write, reload) should still work correctly once you've
   deleted the stray garbage line with `1D` first, or just insert
   starting at whatever line number the garbage occupies.
3. Insert a few lines (Phase 3's `I`), `W`, then exit and reload the same
   file — `L` output matches what was inserted.
4. Modify an existing fixture (`edlintst2`: insert/delete a line or two),
   `W`, reload, confirm the changes persisted and nothing else was
   corrupted.
5. Write, then immediately `L` again in the same session — confirm the
   in-memory buffer is unaffected by the save (no truncation, no pointer
   corruption from the streamout loop).
6. `@0:` save-replace safety (the actual property the redesign bought,
   worth confirming deliberately, not just assumed): if you can force a
   write to fail partway through in VICE (e.g. a full/write-protected
   disk), confirm the *original* file on disk is still intact and
   readable afterward, not lost — that's the difference between this
   approach and the delete-then-write version it replaced.
7. Attempt a write to a read-only or write-protected target to exercise
   `writeErr`'s path generally (message prints, returns to `*` cleanly)
   — best-effort, not a hard blocker if awkward to arrange.
8. Regression: confirm `edlinfull` (Phase 3's near-ceiling fixture) still
   loads correctly post-fix (150 bytes under the ceiling, should still
   succeed) and that a file *larger* than 16384 bytes now fails cleanly at
   load with `"ERROR: FILE TOO LARGE FOR BUFFER."` instead of silently
   corrupting anything — this is the regression test for the prerequisite
   bug fix itself, not new Phase 4 behavior, but must be confirmed before
   `VERSION_STAGE` bumps.

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
- 2026-07-10: Phase 3 detail written, grounded in the real `DELETE`/`NOCOM`/
  `INSERT`/`REPLACE`/`QUIT` source (`EDLCMD1.ASM`, `EDLIN.ASM`,
  `EDLCMD2.ASM`). Key finding while planning: the app-private ZP range
  (`$70-$8F`) is exhausted (31/32 bytes used per `common.inc`), so Phase 3
  breaks from Phase 1/2's "reuse transient ZP fields" pattern — new
  hole-shift/command bookkeeping (13 bytes across `buffer.s`/`cmds.s`) goes
  in plain `BSS` instead, since none of it needs `(zp),Y` indirect
  addressing. Also deliberately gives Delete/Insert/edit-line their own
  named fields rather than aggressively overloading `Line1Lo/Hi`-style
  transients across multi-`findLine`-call command bodies, per the lesson
  from Phase 2's one real bug (stale `Line2Given` leaking across command
  iterations). Two new `buffer.s` primitives designed: `bufOpenHole`/
  `bufCloseHole` (backward/forward chunked VMM-or-RAM shift, mirroring
  `bufReadWindow`'s existing `BufIsVmm` branch pattern) and `bufWriteBytes`.
  Insert/edit-line's blank-line-terminates-insert scope cut (already implied
  by the original phase checklist wording) is called out explicitly as a
  conscious tradeoff. `edlin.s`'s `commandLoop` gains a real dispatch change:
  a blank command letter now invokes `cmdEditLine` instead of silently
  reprompting. No implementation started.
- 2026-07-10: Phase 3 implemented per the detail above.
  - `buffer.s`: `bufWriteBytes`, `bufOpenHole`/`bufCloseHole`, and their
    internal `bufReadChunkRaw`/`bufWriteChunkRaw` helpers added, matching
    the design (chunked backward/forward shift, `BufIsVmm`-branching raw
    read/write). One implementation simplification vs. the written plan:
    the RAM-fallback shift path was specced as a separate unwindowed
    byte-copy loop, but `bufReadChunkRaw`/`bufWriteChunkRaw` turned out
    cleaner shared across both `BufIsVmm` states (RAM just stages through
    `scanWindow` too, an extra hop but far simpler than two independent
    shift implementations) — noted here since it's a real deviation from
    the recorded design, not a silent one.
  - `cmds.s`: `promptContinue` generalized to `promptYN(X/Y = message
    pointer)`; `cmdDelete`, `cmdInsert`, `cmdEditLine`, `cmdQuit`
    implemented per the detail above, with their new `BSS` scratch fields
    (`DelStartLo/Hi`, `DelLineLo/Hi`, `InsLineLen`, `OldLineLenLo/Hi`,
    `SavedOffsetLo/Hi`) and two new message strings (`msgAbortEdit`,
    `msgBufferFull`).
  - `edlin.s`: dispatch table extended (`D`/`I`/blank-letter/`Q`),
    `ownLineInput` exported so `cmds.s` can call it directly.
  - **Two long-branch assembler errors surfaced on first build** (`ca65`
    "Range error" — a `beq`/`bne` target more than 127 bytes away), in
    `findLine`'s RAM-fallback EOF check and `bufOpenHole`'s two buffer-full
    ceiling checks, plus one more in `cmdInsert`'s out-of-range check —
    all from inserting large new code blocks between an existing branch
    and its target. Fixed by inverting each branch and following it with
    an unconditional `jmp` (no range limit), the standard 6502 long-branch
    idiom. Caught entirely by the assembler at build time, not a logic bug.
  - Per this plan's "don't bump the version until VICE-verified" rule,
    `VERSION_STAGE` was deliberately **left at `'2'`**, not bumped to `'3'`,
    since no VICE pass has happened yet this session — `cmake --build
    build --target test_image_d64` is clean and `edlin.prg` (15 blocks,
    up from Phase 2's smaller size) is on `test.d64`, but that's "builds"
    not "verified," and the plan explicitly distinguishes the two.
  - **Phase 3 is code-complete but not yet VICE-verified.** A full testing
    plan for this phase was written up (given directly to the user, not
    duplicated into this doc) covering: `Insert`/`Delete`/edit-line
    round-trips against `List` output, repeated insert/delete cycles
    (hole-shift corruption stress), edit-line's shorter/longer-replacement
    cases, the `bufOpenHole` "buffer full" path, `Quit`'s Y/N prompt, and
    (best-effort) the REU-absent fallback path. Per
    [[feedback-vice-testing]], VICE execution itself is the user's to
    drive (or explicitly hand to the assistant) — not run automatically
    here.
- 2026-07-10: User-verified in VICE against `edlinfull` (Phase 3's
  buffer-full fixture): the boundary behaves exactly as designed — small
  inserts succeed until the 150-byte headroom is exhausted, then
  `bufOpenHole`'s Carry=1 path prints `"ERROR: BUFFER FULL."` and aborts
  cleanly with no corruption. `Quit`'s `"ABORT EDIT (Y/N)?"` prompt also
  confirmed working (tests 8/9 in the testing plan).
  - **Real bug found during that pass**: `promptYN` (`cmds.s:557`, the
    routine generalized from Phase 2's `promptContinue` this phase) echoes
    the typed Y/N keypress via `KernalChROUT` but never followed it with a
    carriage return, so the next output (`*` back at the command loop, or
    the shell prompt after a confirmed `Quit`) printed immediately after
    the echoed letter on the same screen line instead of starting a new
    one. Fixed by adding `lda #PetCr / jsr KernalChROUT` right after the
    echo, before the Y/N branch, so both answers get the newline
    unconditionally. Rebuilt clean.
- 2026-07-10: Testing plan sections 1-9 verified in VICE (List/Page
  interaction, Insert/Delete/edit-line round-trips, buffer-full boundary
  via `edlinfull`, Quit's Y/N prompt, no regressions in Phase 1/2
  behavior). Section 10 (REU-absent fallback path) explicitly deferred —
  recorded as `task 22` (`command64.edlin` project, `+phase3 +deferred`)
  via the `task` CLI, since the Task Warrior MCP wasn't available this
  session — per `CLAUDE.md`'s missing-MCP rule, the user was asked and
  directed to use the `task` CLI directly as a fallback rather than
  blocking on MCP activation.
  `VERSION_STAGE` bumped to `'3'` (`0.1.3`) in `edlin.s`.
  - **Phase 3 is complete** (test section 10 deferred, tracked in
    `task 22`, not a blocker for this phase).
- 2026-07-10: Phase 4 planning session. Started from the original terse
  bullets ("W`rite + auto-drain-on-exit, `A`ppend streaming mirroring
  DOS's fill-to-3/4/flush-to-1/4"). A Task agent researched the file-write
  ABI directly from `src/command64/file.asm` (spot-checked, not trusted
  blindly, per [[feedback-verify-agent-hardware-claims]]) since Phases 1-3
  only ever read files.
  - User flagged a real production incident during this discussion: REU
    memory is segmented across apps and the OS's own App Table (not free
    space), and an earlier EDLIN test run had already silently corrupted
    the App Table via a buffer overflow. Investigated and confirmed the
    root cause: `bufLoadFile` (Phase 1) had no ceiling check against the
    buffer's allocation, so loading an oversized file wrote straight past
    the VMM segment into whatever sits next. Fixed immediately (Carry=1 +
    a distinguishing sentinel in A, mirroring `bufOpenHole`'s convention)
    — this fix stands alone regardless of Phase 4's scope and was landed
    before continuing. Found and fixed the identical off-by-one in
    `bufOpenHole`'s own ceiling check at the same time (rejected an
    exactly-full buffer, not just an overflowing one).
  - This forced a real re-scope: growing the VMM allocation to sidestep
    DOS's Append/sliding-window complexity (my first instinct) was
    explicitly ruled out by the user for the REU-segmentation reason
    above. User chose Write-only for Phase 4, deferring real sliding-window
    Append/Write streaming to a v2 item — tracked as `task 23`
    (`command64.edlin` project, `+v2 +deferred`).
  - Also discovered, while grounding `cmdWrite`'s "create a new file"
    requirement against the feasibility plan's own verification workflow:
    `edlin.s` currently treats *any* file-open failure at startup as
    fatal, meaning `edlin newfile.txt` (a file that doesn't exist yet) has
    never actually worked — the feasibility plan's own stated verification
    step was unreachable since Phase 0. Fixed as part of this phase's
    prerequisites: a device-level open failure (no device/no disk/other
    drive error) stays fatal, but a generic open failure (in practice,
    file-not-found) now starts an empty buffer and prints `"NEW FILE."`
    instead of exiting.
  - Both prerequisite fixes are implemented and build clean
    (`cmake --build build --target test_image_d64`); not yet VICE-verified
    this session. `cmdWrite` itself (the actual Phase 4 command) is
    detailed above but **not yet implemented** — this was a planning
    session, the two prerequisite bugs were fixed opportunistically because
    they blocked reasoning about Phase 4's own design, not because
    implementation of Phase 4 itself has started.
- 2026-07-10: Phase 4 implemented per the detail above.
  - `cmds.s`: `cmdWrite` added exactly per the Phase 4 detail's pseudocode
    (`DOS_DELETE_FILE` ignoring Carry, `DOS_OPEN_FILE` mode=1 with
    `HexValHi=$53` for SEQ, then a `bufReadWindow`-driven streamout loop
    to `DOS_WRITE_FILE`), plus two new messages (`msgWriteOpenErr`,
    `msgWriteFailed`) and imports of `FilenamePtrLo/Hi` from `edlin.s`.
  - One addition beyond the written plan: after each `DOS_WRITE_FILE`
    call, `cmdWrite` also checks the actual bytes-written count
    (`HexValLo/Hi`) against the requested chunk length
    (`WindowValidLen`), not just Carry — matching a precedent already in
    the codebase (`shell.asm`'s `COPY` command does the same
    belt-and-suspenders check). A short write with Carry=0 would
    otherwise silently truncate the saved file.
  - `edlin.s`: exported `FilenamePtrLo/Hi`, imported `cmdWrite`, dispatch
    table gained `W` between `I` and `Q`.
  - Built clean on the first attempt — no long-branch assembler errors
    this time (unlike Phases 1/2/3, which each hit at least one `ca65`
    "Range error" from inserting code between an existing branch and its
    target). `edlin.prg` grew from 15 to 16 blocks.
  - **Phase 4 is code-complete but not yet VICE-verified.**
    `VERSION_STAGE` intentionally left at `'3'` until that verification
    passes.
- 2026-07-10: `cmdWrite` redesigned from delete-then-open to the 1541's
  native `@0:` save-replace convention, prompted directly by the user
  questioning the safety of an explicit delete-before-write (correctly —
  a failed write after a successful delete would have lost the original
  file with no recovery). Verified `@0:` would pass through this kernel's
  `fileOpen` untouched before relying on it: `normalizeName` only
  touches shifted A-Z characters, `parsePointerDevice` only recognizes
  `8:`/`9:`/`1x:` prefixes (both checked directly in `utils.asm`, not
  assumed). `DOS_DELETE_FILE` call removed entirely; `cmdWrite` now
  builds `"@0:" + filename` into a new `WriteNameBuf` (20 bytes) before
  opening for write. Caught a real addressing bug while implementing
  this: `FilenamePtrLo/Hi` isn't in zero page (`edlin.s`'s `BSS` loads at
  `$2E00+`, confirmed against the generated `edlin_2E00.cfg`), so
  `(FilenamePtrLo),y` indirect-indexed addressing would have been invalid
  — fixed by copying it into `ScanPtrLo/Hi` (a zero-page transient
  scratch pair) before dereferencing. Builds clean. Still not
  VICE-verified; `VERSION_STAGE` still `'3'`.
- 2026-07-10: User reported a real symptom while starting VICE
  verification: creating a brand-new file (`edlin brandnew`) and
  immediately running `L` showed `00001: G` — one line of garbage
  content in a file that should have started completely empty. Traced
  to a genuine kernel bug, not an EDLIN bug: `fileRead`
  (`src/command64/file.asm:369-373`) checks `KernalREADST` *before* the
  first `KernalChRIN` on a channel. On the real KERNAL, `READST` only
  reflects the status of the last actual read — checked before any read
  has happened, it's stale (leftover from whatever the last unrelated
  I/O operation was), so the check passes, `CHRIN` runs anyway, and for
  a channel with no real data (e.g. a nonexistent file — `fileOpen`
  itself doesn't reliably report failure for a missing SEQ file until
  the first read, matching a quirk already noted in Phase 1's own
  Progress log) that `CHRIN` returns whatever garbage is on the
  bus/buffer and stores it as a real byte. Only the *next* loop
  iteration's `READST` correctly reflects the error and stops — one byte
  too late. This fully explains the symptom (`bufLoadFile` ends up with
  `BufEnd=1` and one garbage byte instead of detecting "file not found"
  or a genuinely empty load), and means `edlin.s`'s new-file detection
  (checking `DOS_OPEN_FILE`'s Carry) doesn't reliably fire for this case
  either, since `OPEN` itself doesn't report the failure.
  - This is cross-cutting (every `DOS_READ_FILE` caller shares
    `fileRead`), not EDLIN-specific, and could plausibly also silently
    truncate a normal read by one byte if a channel has stale EOF status
    left over from a prior file op — a more insidious variant of the same
    root cause.
  - User chose to log this rather than fix it now, to stay focused on
    Phase 4. Tracked as **`task 24`** (`command64.kernel` project,
    `+bug +crosscutting`, `priority:H`) via the `task` CLI.
  - **Practical impact on Phase 4 right now**: "new file" creation
    (`edlin newname` for a name that doesn't exist) will load one
    spurious garbage byte instead of starting truly empty, until `task
    24` is fixed. No EDLIN-side workaround was added for this — the fix
    belongs in the kernel, not papered over app-side.
- 2026-07-10: While running the Phase 4 test suite, user hit test 3's
  first real step: `W` right after creating/populating a new file failed
  with `"ERROR: COULD NOT WRITE FILE."`. Root-caused as a second,
  actively blocking kernel bug distinct from (but closely related to)
  `task 24`'s garbage-byte symptom, both stemming from the same root
  cause: `fileOpen`'s read-mode path trusts KERNAL `OPEN`'s Carry, which
  is unreliable for SEQ file-not-found — the drive's own error channel
  (LFN 15) gets set to `62,FILE NOT FOUND` but nothing reads/clears it.
  That stale status then sits there and gets picked up by
  `checkDeviceReady`'s own preflight status query (`file.asm:36-95`, run
  at the start of *every* subsequent `fileOpen`/`fileDelete`/etc call) —
  its status-code handling only special-cases `00`/`73`/`74`, so a
  leftover `62` falls into `cdrOtherErr`, reporting a bogus "other drive
  error" for a completely unrelated later operation (here, `cmdWrite`'s
  own `DOS_OPEN_FILE`).
  - **Fixed at the root** rather than patched around: `fileOpen`
    (`src/command64/file.asm`) now verifies read-mode opens via the error
    channel (`readErrorChannel`, already used by `fileDelete`/
    `fileRename`) before trusting KERNAL `OPEN`'s success — if the status
    isn't `00`, the just-opened handle is closed and `Carry=1`/`A=$FF` is
    returned, same as a real KERNAL-level open error. This resolves
    `task 24` as a side effect too: `bufLoadFile` now takes the failure
    branch immediately for a nonexistent file instead of ever attempting
    a read, so the phantom garbage byte never gets stored, and
    `edlin.s`'s existing new-file detection (already checking for `A=$FF`
    as "file not found") now fires correctly with a genuinely empty
    buffer.
  - Hit the same long-branch issue as every prior EDLIN phase, this time
    in KickAssembler rather than `ca65` (`checkDeviceReady`'s error
    branch in `fileOpen` became unreachable within relative-branch range
    once the new verification code was inserted before it) — fixed with
    the same invert-and-`jmp` idiom.
  - `command64.prg` and `test_image_d64` both build clean.
    **Not yet VICE-verified** — annotated onto `task 24` rather than
    closing it outright, pending confirmation.
- 2026-07-11: Phase 4 manual verification in VICE completed successfully. Verified empty new-file creation, line insertion, `@0:` save-replace writing (`W`), editor quit (`Q`), reload and listing (`L`) of modified file, and buffer ceiling limits. Bumps `VERSION_STAGE` to `'4'` (`0.1.4`) in `edlin.s`.

