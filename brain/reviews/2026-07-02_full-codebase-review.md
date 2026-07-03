---
feature: command64-full-codebase-review
reviewed: 2026-07-02
status: remediation-pending
---

# Code Review: Command64 OS — Full Codebase Sweep (post-license-commit)

## Scope

Full-codebase review (not diff-scoped) of every git-tracked assembly source and CMake build
file, run via three parallel finder angles (core OS correctness, external-apps/tests
correctness, cleanup/efficiency/build) followed by direct-source verification of every
candidate. `.gitignore`d paths (`ms-dos/`, `node_modules/`, `build/`, etc.) were out of scope
by construction — the file list was taken from `git ls-files`.

| File | Role |
|------|------|
| `src/command64.asm` | KickAssembler root build file, segment layout |
| `src/command64/shell.asm` | Command loop, dispatcher, built-in handlers |
| `src/command64/path.asm` | File discovery, `.prg` extension appending |
| `src/command64/file.asm` | Handle table, KERNAL file I/O, `checkDeviceReady` |
| `src/command64/vmm.asm` | Virtual Memory Manager (REU mapping) |
| `src/command64/api.asm`, `loader.asm`, `utils.asm`, `petsci.asm` | Service bus, loader, hex/string utils |
| `include/command64.inc`, `include/vmm.inc` | KERNAL equates, ZP labels, VMM ABI |
| `src/external/debug/debug.asm` | DEBUG utility (disassembler, breakpoints, search) |
| `src/external/conway/conway.asm`, `label.asm`, `dvorak.asm` | External apps |
| `tests/src/*.asm` | Service-bus / VMM / file-handle smoke tests |
| `CMakeLists.txt`, `cmake/*.cmake` | Build system |

## Findings

### HIGH

| ID | File | Lines | Issue |
|----|------|-------|-------|
| R1 | `path.asm` | 56, 67 | `checkExistence` calls `checkDeviceReady`, which clobbers `TempLo`/`TempHi` (documented at `file.asm:35`), then reuses `TempLo` as the SETNAM filename length. Breaks the length argument on nearly every disk operation (LOAD/TYPE/DEL/REN/COPY/external-program lookup) against a responsive device. |
| R2 | `shell.asm` | 1166–1174 | `ccCloseSrcErr` (COPY's dest-open-failed handler) clobbers `A` via the source-handle `apiHandler` close call before falling into `ccOpenErr`'s `printDeviceStatusMsg`, discarding the real dest-open error code. Users see generic "Load error" instead of "Device not present"/"No disk in drive". |
| R3 | `shell.asm` | 994–1002 | `cmdCopy`'s `ccCopySrc` loop copies the source filename into the 40-byte `SourceBuf` with no length check; `DestBuf` sits immediately after it in memory (`include/command64.inc:85-86`). A `COPY <45+ char name> dest.prg` (CommandBuffer allows up to 79 chars) overflows into `DestBuf`. |
| R4 | `shell.asm` | 1697–1730 | `envAppend`'s 4KB environment-segment boundary check (`VmmOffHi` vs `$10`) runs once at entry only; the `eaVarLoop`/`eaValLoop` write loops never recheck it. A long `SET VAR=value` issued near the boundary can write past the Env segment into adjacent REU pages instead of erroring. |

### MEDIUM

| ID | File | Lines | Issue |
|----|------|-------|-------|
| R5 | `src/external/debug/debug.asm` | 1632–1649 | `cmdSearch`'s `csCompLoop` compares the full search pattern against `(rangeStart),y` before `checkRangeLimit` is ever consulted (it only checks `rangeStart` itself, after the compare, not `rangeStart+listLen`). A pattern search whose match window straddles `rangeEnd` reads past the user-declared range, potentially into memory-mapped I/O, while still reporting an in-range match. |
| R6 | `CMakeLists.txt` | 40–49 | `file(GLOB_RECURSE ...)` source discovery for `CMD64_SRCS`/`DEBUG_SRCS`/`LABEL_SRCS`/`CONWAY_SRCS` lacks `CONFIGURE_DEPENDS`. These lists feed the build-number custom command's `DEPENDS`. A newly added `.asm`/`.inc` file is silently excluded from the build until someone manually re-runs `cmake -B build`, producing a stale/incomplete PRG with no error. |

### LOW / CLEANUP

| ID | File | Lines | Issue |
|----|------|-------|-------|
| R7 | `src/command64/vmm.asm` | 258–311 | `vmmReadByte`/`vmmWriteByte` reload `REU_C64_ADDR_L/H` and `REU_LEN_L/H` with the same constants on every single-byte transfer — the hottest path in the VMM (called once per byte for all REU-backed file/disk I/O). Priming these once (e.g. in `vmmInit`) removes 8 redundant instructions per byte. |
| R8 | `src/external/debug/debug.asm` | throughout (e.g. ~300) | Prints every UI string as a chain of individual `lda #'X'`/`jsr KernalChROUT` pairs (118 call sites) instead of using the OS's own `DOS_PRINT_STR` API (`include/command64.inc:30`) / `petPrintString` (`src/command64/petsci.asm:22`). Bloats assembled size and multiplies the chance of a typo'd literal versus a data string + one shared print routine. |

### NOTED, NOT CARRIED FORWARD (latent / non-reachable today)

| Candidate | File | Reason not scored |
|-----------|------|--------------------|
| `PrintPtrHi` ignored after `DOS_PARSE_PREFIX` | `src/external/label/label.asm:108-112` | Only safe today because `CommandBuffer` (80 bytes at `$033C`) never crosses a page boundary; a landmine if the buffer moves/grows, not a live bug. |
| Leftover dead instruction pair (`ldy #<writeData... wait, writeData`) | `tests/src/filetest.asm:50-53` | Immediately overwritten by the following two correct lines; harmless as written, but a trap for a future "cleanup" edit. |
| `hexDigitToVal`/`parseHex` silently truncate on >4 hex digits | `src/command64/utils.asm` | Leniency, not incorrect behavior — no reachable failure scenario named. |

No correctness bugs were found in `conway.asm` (neighbor counting, toroidal wrap, double-buffer swap all verified correct), `dvorak.asm` (its own header already documents its two intentional transliteration quirks; it is also deliberately not wired into the CMake build per `CMakeLists.txt:52-54`), or in any of `apitest.asm`, `banktest.asm`, `color.asm`, `extcls.asm`, `devtest.asm`, `handletest.asm`, `hello.asm`, `vmmtest.asm`.

## Scoring

| ID | Severity | Status |
|----|----------|--------|
| R1 | High | Confirmed |
| R2 | High | Confirmed |
| R3 | High | Confirmed |
| R4 | High | Confirmed |
| R5 | Medium | Confirmed |
| R6 | Medium | Confirmed |
| R7 | Low | Confirmed (efficiency) |
| R8 | Low | Confirmed (reuse) |

## Remediation Priority

1. **Blocker**: R1 (`checkExistence` TempLo clobber) — silently breaks the majority of disk commands.
2. **High**: R2 (COPY error message), R3 (SourceBuf/DestBuf overflow), R4 (envAppend bounds check).
3. **Medium**: R5 (DEBUG search OOB read), R6 (CMake `CONFIGURE_DEPENDS`).
4. **Low**: R7 (VMM byte-transfer overhead), R8 (DEBUG print-routine reuse).

## Remediation Status — IN PROGRESS

Remediation plan: `brain/plans/2026-07-02-code-review-remediation.md` (mirrored at
`docs/superpowers/plans/2026-07-02-code-review-remediation.md`), following the same
mirrored-pair convention used for the 2026-05-13 pass.

R1 (checkExistence TempLo clobber) is **implemented and verified** in
`src/command64/path.asm` (uncommitted) — confirmed via direct memory reads that it was
corrupting the KernalSETNAM filename length, and confirmed the fix resolves it.

R8 (DEBUG print-routine reuse) has been implemented in `src/external/debug/debug.asm`
ahead of the rest of the plan (uncommitted). R2–R7 are specified but not yet applied.

A candidate finding — **R9**, an apparent KERNAL `LOAD` hang on a named, track-crossing
file — was investigated and then **retracted**: the user confirmed the identical `LOAD`
completes without issue on physical hardware. The apparent hangs in VICE were an
artifact of this session's testing methodology — monitor-tool calls (screenshots,
register reads) made during an in-flight true-drive-emulated transfer can desync the
timing-sensitive IEC handshake and stall it. No code or disk-image defect. See Task 9
in the remediation plan for the full account and the testing-methodology lesson for
future VICE-based verification.

A pre-existing DEBUG shell-load bug (`debug` command fails with "Bad command or file
name" even on an unmodified tree) was discovered while attempting to smoke-test R8 —
it blocks in-shell verification of both R5 and R8 and is tracked as a candidate R9 in
the plan, not yet root-caused.
