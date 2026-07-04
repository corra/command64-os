# Raw Multi-Agent Findings: Full Codebase Review

**Date**: 2026-07-02
**Method**: 3 independent finder agents (full-codebase scope, not diff-scoped) → direct-source
verification of every candidate (no separate verifier sub-agent this pass — verified inline by
reading the actual files)
**Effort**: Medium
**Peer review (polished)**: `brain/reviews/2026-07-02_full-codebase-review.md`

---

## Phase 0 — Scope

No meaningful diff existed against `origin/main` at review time (all prior session work was
already committed), so this was run as a full-codebase sweep instead of a diff review, scoped to
`git ls-files` output (i.e. `.gitignore`d paths — `ms-dos/`, `node_modules/`, `build/` — excluded
by construction). 33 tracked `.asm`/`.inc`/`.cmake`/`CMakeLists.txt` files in scope, split across
three finder agents by area:

- **Agent 1**: core OS modules (`src/command64.asm`, `src/command64/*.asm`, `include/*.inc`)
- **Agent 2**: external apps + tests (`src/external/*/*.asm`, `tests/src/*.asm`)
- **Agent 3**: cleanup/efficiency/reuse across all assembly, plus the CMake build scripts

---

## Phase 1 — Finder Agent Raw Output

### Agent 1 — Core OS Correctness

> Reviewed the 11 named files against register/flag-clobber, carry-flag, stack-discipline,
> zero-page-reuse, off-by-one, and uninitialized-state categories.

1. **`src/command64/path.asm:56-67` — `checkExistence` reads `TempLo` after it's been
   clobbered.** `findFile` sets `TempLo` = filename length (path.asm:23), then calls
   `checkExistence`, whose first action is `jsr checkDeviceReady` (line 56). `checkDeviceReady`
   is explicitly documented (file.asm:35) as clobbering `TempLo`/`TempHi` — it unconditionally
   stores the two status-channel digit characters there (file.asm:71-73) on every call.
   `checkExistence` then does `lda TempLo // Length` (path.asm:67) for `KernalSETNAM`, using the
   leftover PETSCII status digit (typically `'0'`=$30=48) instead of the real filename length.
   *Failure scenario*: any LOAD, TYPE, DEL, REN, external-program-name lookup, or COPY against a
   device that responds normally (status "00") passes SETNAM a length of 48 instead of the
   actual name length, reading garbage bytes past the filename buffer — spurious file-not-found
   errors or wrong-file opens for essentially every disk command.

2. **`src/command64/shell.asm:1162-1174` — `ccCloseSrcErr` discards the real error status
   before reporting it.** When COPY's destination `OPEN` fails, `A` holds the specific status
   code (1/2/3). Control lands at `ccCloseSrcErr` (1166), which immediately does
   `lda SrcHandle` / `sta FileHandle` / `jsr apiHandler` (closing the source handle) — all of
   which clobber `A` — before falling into `ccOpenErr`'s `jsr printDeviceStatusMsg`
   (1162-1163). Since closing an already-open handle normally succeeds and returns A=0,
   `printDeviceStatusMsg` (file.asm:137-141) sees a status matching neither 1 nor 2 and always
   prints the generic "Load error" instead of "Device not present"/"No disk in drive" —
   contradicting the inline comment, which claims the original status is reported except on a
   rare double-fault. *Failure scenario*: `copy 8:file.prg 11:out.prg` where device 11 is
   absent — user always sees "Load error" instead of "Device not present".

3. **`src/command64/shell.asm:1697-1749` — `envAppend` only bounds-checks once, not per byte
   written.** The 4KB-segment guard (`cmp #$10` against `VmmOffHi`, lines 1699-1705) runs only
   at entry; the subsequent `eaVarLoop`/`eaValLoop` write bytes and increment
   `VmmOffLo/Hi` with no re-check. *Failure scenario*: `SET LONGVAR=<value>` issued when the
   environment block is already near the 4KB boundary can walk `VmmOffHi` past `$10`, writing
   past the allocated Env segment into adjacent REU pages instead of hitting "Environment space
   full".

4. **`src/command64/shell.asm:992-1056` — `cmdCopy`'s `ccCopySrc`/`ccCopyDest` loops write into
   `SourceBuf`/`DestBuf` (40 bytes each, contiguous at $03A2/$03CA) with no length limit.**
   *Failure scenario*: `copy <filename 45+ chars> dest.prg` overflows `SourceBuf` into
   `DestBuf`'s memory before the destination-empty short-circuit path (`ccCopySrcToDest`, line
   1063) even runs, corrupting the destination name silently rather than failing cleanly.

Noted but not escalated: `hexDigitToVal`/`parseHex` silently truncate on >4 hex digits
(utils.asm) — a leniency issue, not a clear correctness bug, left out per the "concrete line +
reachable" bar.

### Agent 2 — External Apps & Tests Correctness

> Reviewed all 13 files (conway, debug, dvorak, label, 9 test files) in depth, focusing on
> Dvorak resident-patch math, Conway toroidal wrap/buffer-swap, debug.asm breakpoint/flag/parser
> logic, label.asm buffer handling, and test-harness assertions/API usage. Most of the code is
> careful and internally consistent — several places that looked suspicious at first glance
> (`checkRangeLimit`, JMP-indirect page-wrap emulation, Conway's neighbor math, the
> double-buffer swap) turned out to be correctly implemented on closer trace-through.

1. **`tests/src/filetest.asm:50-53`** — Dead/incorrect leftover code: a line sets Y from the
   wrong label, immediately overwritten by the next two lines with the correct pointer.
   Currently harmless, but a clear leftover mistake — if a future edit "cleans up" the
   redundant-looking correct lines assuming the first block was intentional, the WRITE call
   would write from the filename buffer instead of the intended message.

2. **`src/external/debug/debug.asm:1630-1650` (`cmdSearch`)** — The inner match loop
   (`csCompLoop`) indexes `(rangeStart), y` for `y = 0..listLen-1` with no check against
   `rangeEnd`. The outer `checkRangeLimit` only fires *after* a full match attempt completes.
   *Failure scenario*: searching for a multi-byte pattern with the range's last byte(s) at/near
   `rangeEnd`, the comparison reads bytes past `rangeEnd` into unrelated memory (potentially
   across the $CFFF user-space ceiling) while still reporting a match at an address the user
   specified as in-range.

3. **`src/external/label/label.asm:108-112`** — "Recalculate Y index from advanced pointer"
   after `DOS_PARSE_PREFIX` subtracts only `PrintPtrLo - <CommandBuffer`, ignoring
   `PrintPtrHi`. Safe today only because `CommandBuffer` ($033C, 80 bytes) never crosses a page
   boundary. Not a live bug, but a landmine if `CommandBuffer` is ever relocated near a page
   boundary or grown past 196 bytes.

No confirmed correctness bugs found in `conway.asm` (neighbor counting, toroidal wrap, and
buffer swap all correct), `dvorak.asm` (its header already documents its two intentional
transliteration quirks — no additional bug found beyond what's disclosed), or in `apitest.asm`,
`banktest.asm`, `color.asm`, `extcls.asm`, `devtest.asm`, `handletest.asm`, `hello.asm`,
`vmmtest.asm` (all correctly set up ApiStub register conventions per api.asm's documented ABI,
and their pass/fail assertions check the right conditions).

### Agent 3 — Cleanup, Efficiency & Build Scripts

> Combined assembly-code reuse/simplification/efficiency scan with a CMake build-script review.

1. **`src/external/debug/debug.asm` (throughout, e.g. lines 300-340, 704-724, 3255-3272)** —
   never uses a null-terminated-string printer; every message is emitted as a chain of
   `lda #'X' / jsr KernalChROUT` pairs (118 `jsr KernalChROUT` call sites, ~101 `lda #'...'`
   literals). The main OS already has `petPrintString` (petsci.asm:22) that takes a pointer and
   loops. Cost: bloated code size, higher per-character typo risk, no reuse of the shared
   primitive available via `command64.inc`'s `DOS_PRINT_STR` API.

2. **`src/command64/vmm.asm:258-311` (`vmmReadByte`/`vmmWriteByte`)** — every single-byte REU
   transfer reloads `REU_C64_ADDR_L/H` and `REU_LEN_L/H` even though these four values are
   constant for every byte-level call. Cost: 8 redundant `lda`/`sta` instructions executed on
   every single byte read/write through the VMM — the hottest path in the whole memory manager.
   Could be primed once in `vmmInit`.

3. **`src/command64/shell.asm:2087-2089` (`notImplMsg`)** — the string "Feature not yet fully
   implemented" is defined but never referenced anywhere in the codebase (confirmed via grep
   across `src/` and `include/`). Dead data taking up assembled PRG space.

4. **`CMakeLists.txt:40-49`** — `file(GLOB_RECURSE ...)` used without `CONFIGURE_DEPENDS` for
   `CMD64_SRCS`, `DEBUG_SRCS`, `LABEL_SRCS`, `CONWAY_SRCS`. *Failure scenario*: adding a new
   `.asm`/`.inc` file to `src/command64/`, `src/external/debug/`, etc. silently omits it from
   the build until someone manually re-runs `cmake -B build` — a classic CMake glob trap
   producing a stale/incomplete PRG with no error.

5. **`cmake/Findcc1541.cmake` / `cmake/FindKickAss.cmake`** (both, `PATHS
   "${CMAKE_SOURCE_DIR}/tools"`) — search path hardcoded to the in-repo `tools/` directory, no
   fallback to system PATH, no version check. On a clean checkout where `tools/` hasn't been
   populated, `find_package(... REQUIRED)` fails with a generic "not found" rather than pointing
   at the real cause.

6. **`src/command64/vmm.asm:80-160` (`vmmAlloc` contiguous-page scan)** — full linear
   byte-by-byte scan of the 4KB Memory Control Table on every allocation, no free-list or
   last-known-free-offset cache. Allocation cost scales with fragmentation/table size rather
   than actual free space located near the last hint.

---

## Phase 2 — Verification (direct source read, no separate verifier agent)

| Candidate | Vote | Evidence |
|-----------|------|----------|
| Agent1-1: `checkExistence` TempLo clobber | **CONFIRMED** | Read `file.asm:20-46` (checkDeviceReady doc + body: stores status digits into TempLo/TempHi at lines 71-73) and `path.asm:9-92` (findFile stores length in TempLo:23; checkExistence calls checkDeviceReady:56 then reads TempLo as length:67). Clobber path is direct and unconditional. |
| Agent1-2: `ccCloseSrcErr` wrong status reported | **CONFIRMED** | Read `shell.asm:1080-1179`. Line 1099 `bcs ccCloseSrcErr` carries dest-open error in A; `ccCloseSrcErr` (1166-1174) clobbers A via `jsr apiHandler` (close) before `jmp ccOpenErr` → `printDeviceStatusMsg` (file.asm:137-144, input=A). |
| Agent1-3: `cmdCopy` SourceBuf/DestBuf overflow | **CONFIRMED** | `include/command64.inc:85-86` confirms `SourceBuf`=$03A2 (40 bytes), `DestBuf`=$03CA — exactly adjacent, no gap. `ccCopySrc` loop (shell.asm:994-1002) has no bound on X. CommandBuffer allows up to 79 chars per line comment at shell.asm:162, so a >40-char filename is reachable. |
| Agent1-4: `envAppend` bounds check once | **CONFIRMED** | Read `shell.asm:1690-1745`. Boundary check at 1698-1701 runs once; `eaVarLoop`/`eaValLoop` (1707-1730) increment VmmOffLo/Hi with no recheck, looping on SourceBuf/CommandBuffer null terminators (up to ~79 chars each). |
| Agent2-2: `cmdSearch` OOB read past rangeEnd | **CONFIRMED** | Read `debug.asm:1619-1657`. `csCompLoop` (1632-1638) indexes `(rangeStart),y` for the full pattern length; `checkRangeLimit` only runs after the compare (1649) and only tests `rangeStart`, not `rangeStart+listLen`. |
| Agent2-1: filetest.asm dead leftover code | **not carried forward** | Confirmed harmless as-written (immediately overwritten); real risk is only realized on a *future* edit, not a present failure — kept as a "noted, not scored" item in the polished review rather than a scored finding. |
| Agent2-3: label.asm PrintPtrHi landmine | **not carried forward** | Confirmed not reachable today (CommandBuffer never crosses a page boundary at its current size/location) — latent-only, kept as a noted item rather than scored. |
| Agent3-1: debug.asm reimplements print loops | **CONFIRMED** | `grep -c "jsr KernalChROUT" src/external/debug/debug.asm` → 118. `include/command64.inc:30` confirms `DOS_PRINT_STR` ($09) exists as the intended API; `petsci.asm:22`'s `petPrintString` is the OS's own implementation of it. |
| Agent3-2: vmm.asm redundant REU register reload | **CONFIRMED** | Read `vmm.asm:258-311`. Both `vmmReadByte` and `vmmWriteByte` reload the same 4 constants (`vmmTempByte` address, length=1) on every call with no caching. |
| Agent3-3: `notImplMsg` dead string | **not carried forward** | True but trivial (a handful of bytes of dead data); dropped in favor of higher-signal findings under the 8-item cap. |
| Agent3-4: CMake `GLOB_RECURSE` without `CONFIGURE_DEPENDS` | **CONFIRMED** | `grep -n "GLOB_RECURSE" CMakeLists.txt` confirms 4 call sites at lines 40/43/46/49 feed `DEPENDS` of the build-number custom_command (line 65) with no `CONFIGURE_DEPENDS`. |
| Agent3-5: Find*.cmake hardcoded tools/ path | **not carried forward** | Real but lower-signal than the GLOB_RECURDE issue; dropped under the 8-item cap in favor of higher-severity assembly-level findings. |
| Agent3-6: vmmAlloc linear MCT scan | **not carried forward** | Real algorithmic-complexity note but no concrete reachable failure scenario at current disk-image / allocation sizes; dropped under the cap. |

11 of 13 raw candidates were confirmed on direct source read; none were refuted outright. 8 were carried into the final ranked/scored list (`brain/reviews/2026-07-02_full-codebase-review.md`); 3 were downgraded to "noted, not scored" for being either not-yet-reachable landmines or too low-signal to make the cap.

---

## Final Ranked Findings

```json
[
  {
    "file": "src/command64/path.asm",
    "line": 56,
    "summary": "checkExistence calls checkDeviceReady, which clobbers TempLo/TempHi, then reuses TempLo as the filename length.",
    "failure_scenario": "findFile stores the filename length in TempLo (path.asm:23), then checkExistence calls checkDeviceReady (path.asm:56), which overwrites TempLo/TempHi with status-channel digit characters (file.asm:71-73). checkExistence then reads TempLo as the SETNAM length at path.asm:67, using the leftover status digit instead of the real filename length. Any LOAD, TYPE, DEL, REN, COPY, or external-program lookup against a responsive device passes SETNAM a wrong length."
  },
  {
    "file": "src/command64/shell.asm",
    "line": 1166,
    "summary": "ccCloseSrcErr clobbers A via the source-close apiHandler call before falling into ccOpenErr's printDeviceStatusMsg, discarding the real dest-open error code.",
    "failure_scenario": "COPY 8:file.prg 11:out.prg where device 11 is absent: dest OPEN fails with A=1 at shell.asm:1099. ccCloseSrcErr closes the source handle (clobbering A to 0) then falls through to printDeviceStatusMsg, which prints the generic 'Load error' instead of 'Device not present'."
  },
  {
    "file": "src/command64/shell.asm",
    "line": 994,
    "summary": "ccCopySrc copies the COPY source filename into the 40-byte SourceBuf with no length check, and DestBuf sits immediately after it in memory.",
    "failure_scenario": "COPY <45+ char filename> dest.prg overflows SourceBuf directly into DestBuf during the ccCopySrc loop, corrupting the destination filename before the copy begins."
  },
  {
    "file": "src/command64/shell.asm",
    "line": 1706,
    "summary": "envAppend checks the 4KB environment-segment boundary only once at entry; the write loops that follow never recheck it.",
    "failure_scenario": "SET LONGVAR=<long value> issued when the environment block is already near the 4KB boundary walks VmmOffHi past $10, writing past the allocated Env segment instead of failing with 'Environment space full'."
  },
  {
    "file": "src/external/debug/debug.asm",
    "line": 1632,
    "summary": "cmdSearch's csCompLoop compares the full search pattern against memory without checking rangeEnd until after the compare completes.",
    "failure_scenario": "Searching for a multi-byte pattern with rangeStart near rangeEnd reads bytes past the user-specified range while still reporting a match at an address declared in-range."
  },
  {
    "file": "CMakeLists.txt",
    "line": 40,
    "summary": "file(GLOB_RECURSE ...) source discovery lacks CONFIGURE_DEPENDS, so new source files are silently excluded from the build until a manual reconfigure.",
    "failure_scenario": "Adding a new .asm/.inc file under src/command64/, src/external/debug/, etc. after the initial cmake -B build is never picked up by cmake --build build, producing a stale/incomplete PRG with no error."
  },
  {
    "file": "src/command64/vmm.asm",
    "line": 267,
    "summary": "vmmReadByte/vmmWriteByte reload REU_C64_ADDR_L/H and REU_LEN_L/H with the same constants on every single-byte transfer, the hottest path in the memory manager.",
    "failure_scenario": "Every byte-level VMM read/write redundantly re-executes 8 lda/sta instructions to set values that never change between calls."
  },
  {
    "file": "src/external/debug/debug.asm",
    "line": 300,
    "summary": "debug.asm prints every UI string as a chain of individual lda #'X'/jsr KernalChROUT pairs instead of using the OS's own null-terminated string-print API.",
    "failure_scenario": "118 separate jsr KernalChROUT calls with per-character literals bloat the assembled program size and multiply the chance of a typo'd character versus defining strings as data and calling the existing petPrintString/DOS_PRINT_STR primitive."
  }
]
```
