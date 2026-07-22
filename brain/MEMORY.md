# Session Memory

## Project Documentation

- `GEMINI.md`: Core directives and protocols
- `README.md`: Project overview and quick start
- `docs/user-manual.md`: Comprehensive usage guide (the "whole shebang")
- `brain/KNOWLEDGE.md`: Architectural decisions and technical findings
- `brain/MEMORY.md`: Session state and task tracking (this file)
- `brain/COMMANDS.md`: Internal command status and priority
- `brain/EXTERNAL.md`: External program status and priority
- `brain/task.md`: Granular task list

## Current State (2026-07-15)

- Phase 2A, 2B, 2C, and 2D complete (2D = INT 21h BRK service bus).
- Phase 3 complete (File System Integration).
- Phase 4 complete (DEBUG external utility, including Phase 1 Peer Review corrections, prefix parsing, and custom SEQ/USR loaders).
- Phase 5: DRIVE/multi-device, Environment (`SET`/`PATH`) complete.
- Phase 6A: App Manager Phase A complete.
- Phase 6B: Binary Relocator complete.
- Phase 6C: External Editor (VI) complete.
- **Conway memory safety & relocation crash fix**: Resolved memory collisions between code and double buffers by embedding the grid buffers as relocatable, page-aligned data tables inside the binaries. Both Kick and ca65 builds generate identical size-bounded relocatable binaries (3008 bytes, 59 relocation entries).
- Project Infrastructure: Taskwarrior tasks initialized, Codebase Memory indexed, Code Wiki created.
- **CMake Migration**: Build system migrated to CMake with clean source imports, cross-platform build counters, and a root Makefile proxy wrapper.
- **Version**: 0.4.0 (command64 OS Build 2591, VI Build 1013) / DEBUG 0.4.0 (Build 1101) / LABEL 0.4.0 (Build 1034) / CONWAY 0.4.1 (Build 1058) / EDLIN 0.1.4 (Build 1017) / PACMAN 0.1.3 (Build 1055) / CASM 0.1.17 (Build 1079).
- **Generalized Multi-Digit Version Stage System**: Migrated all `ca65` external applications and test suites in the repository from character equates to preprocessor `.define` string macros. This removes the single-digit version stage limitation, allowing `casm` to advance past `0.1.8` to `0.1.9` and later `0.1.10+` without code size or compile errors. All 8 external applications and 11 test entry points have been updated.
- **DEBUG ca65 migration**: `debug.prg` now builds from `src/external/debug/debug.s` via ca65/ld65 and `add_ca65_app`; build 1100 verified with matching `$2C00` header, `R6` relocation footer, 716 relocation entries, and loaded end address `$4B36` (below the `$5000` scratch range used by the manual test plan).
- **ca65 primary test migration**: The 9 already-ported tests (`api`, `bank`, `color`, `dev`, `extcls`, `file`, `handle`, `hello`, `vmm`) now build as primary `test_<name>` ca65/ld65 targets using their existing `BUILD_TEST_<NAME>` counters. The duplicate `test_ca65_<name>` path and old Kick sources were retired; `reloc.asm` remains Kick-specific.
- **test app naming cleanup**: Redundant `<name>test` ca65 test apps now use
  feature-only public names: `test_api`, `test_bank`, `test_dev`, `test_file`,
  `test_handle`, `test_sendcmd`, and `test_vmm`. CMake watches test source and
  include globs with `CONFIGURE_DEPENDS`.
- **Verification**: VI editor compiled relocatable, verified buffer layout, scrolling, insertions, deletions, yanking, pasting, and save/load file routines.
- **Conway Multiverse Research**: Saved video transcript to `brain/research/conway_multiverse_transcript.txt` and completed implementation plan for adding main menu, preset/custom rules, and generation counter.
- **VI Code Review**: Completed comprehensive correctness and architectural code review of `vi.asm` detailing critical VMM, yank buffer, horizontal scrolling, and data loss issues.
- **FileOpen PRG Default & Read/Write Peer Review**: Completed peer review of the proposed fileopen default fix and read/write status sequencing plan ([2026-07-10_fileopen_prg_type_default_fix_peer_review.md](file:///home/morgan/development/c64/command64-os/brain/reviews/2026-07-10_fileopen_prg_type_default_fix_peer_review.md)), identifying critical logic omissions in the proposed `fileRead` assembly refactoring and specifying appropriate remediations.
- **EDLIN Port Phase 4 (Save/streaming)**: Completed and verified in VICE. Verified empty new-file creation, line insertion, `@0:` save-replace writing (`W`), editor quit (`Q`), reload and listing (`L`) of modified file, and buffer ceiling limits. Bumps `VERSION_STAGE` to `'4'` (`0.1.4`).
- **EDLIN hardware save truncation fixed**: Implemented core file API hardening for final EOI byte preservation and immediate post-`CHROUT` status checks, plus EDLIN post-close drive-status validation after `W`. `make all` passes and physical-hardware verification confirmed the fix under Task #25.
- **DATE/TIME Phase 1**: Completed CIA #1 TOD-backed internal `DATE` and `TIME` commands. User verified direct and interactive set/display round-trips, midnight rollover, and month rollover. Phase 1 uses resident kernel date bytes at `$1FFC-$1FFF` and remains intentionally non-persistent until RTC hardware phases.
- **Pac-Man Phase 3.1 remediation**: Blinky-only scatter/chase movement is active.
  Actor redraw ordering is corrected, and `autotile.py` now owns a validated
  24x28 logical topology with presentation-only corner overrides. CMake runs
  the generator before Pac-Man assembly. Exact 240-dot layout and ghost warp
  behavior remain deferred. Actor visibility and the complete Pac-Man/Blinky
  collision, life-loss, reset, and game-over flow were user-verified in build
  1054; version 0.1.3 build 1055 contains the accepted patch-stage bump.
- **Pac-Man Ghost House Code Review**: Completed comprehensive primary and secondary correctness audits of the uncommitted ghost house bouncing, release, and scheduler mechanics ([primary review](file:///home/morgan/development/c64/command64-os/brain/reviews/2026-07-15_pacman-ghost-house-review.md) and [secondary review](file:///home/morgan/development/c64/command64-os/brain/reviews/2026-07-15_pacman-ghost-house-secondary-review.md)), identifying bugs in bouncing coordinate drift, exit double-movement, scheduler mode corruption, and the door gate check, and proposing optimized direction-only refactorings.




## Phase 6A — App Manager (next up)

### Superpowers Artifacts

| Artifact | Path |
| ---------- | ------ |
| Design spec | `docs/superpowers/specs/2026-05-13-app-manager-design.md` |
| Phase A plan | `docs/superpowers/plans/2026-05-13-app-manager-phase-a.md` |

### What Phase A delivers (11 tasks, ~$350 bytes of new code)

- New segment `AppTable` at `$2000`; `UserProgStart` shifts from `$2000` → `$2200`.
- `apptable.asm`: `aptInit`, `aptProtectedCheck`, `aptSlotBase`, `aptNameMatch`, `aptFind`, `aptRegister`, `aptRemove`, `aptList`, `aptPrintHex8`.
- `LOAD` gated: protected-address check ($0000–$21FF, $C000–$FFFF) + table-full check before disk I/O; registers entry on success.
- `RUN`/`GO` gated: requires app table membership; supports `RUN <name>` and `RUN <addr>`.
- New commands: `APPS`/`PS` (list loaded programs), `FREE` (remove entry, guards APP_RUNNING).
- Historical Kick test/debug sources previously compiled at `$2200`; current external programs and ca65-migrated tests build at `UserProgStart` (`$3400`) through the CMake app helpers.

### Key implementation details

- App table stored in VMM: 1 page (4 KB), segment saved in `AptSegLo/Hi` ($03F2–$03F3).
- Entry stride 40 bytes × 16 slots + 4-byte header = 644 bytes total (fits in 1 VMM page).
- `vmmReadByte`/`vmmWriteByte` clobbers `TempLo/Hi` and `Y`; preserves `X` and `VmmOffLo/Hi`.
- `aptRegister` calling convention: `NamePtrLo/Hi` + `SrcHandle` = name, `HexValLo/Hi` = load addr, `TempLo/Hi` = KernalLOAD end+1 return.
- `aptFind` calling convention: carry clear = name mode (`NamePtrLo/Hi`, `SrcHandle`); carry set = address mode (`HexValLo/Hi`). Returns X = slot index, `HandlerVecLo/Hi` = LoadAddr on found.
- Phases B and C extend `apptable.asm` without changing the API surface.

## Memory Map (current — as of Build 2629)

| Region | Purpose |
| -------- | --------- |
| `$033C` | CommandBuffer (80 bytes, Cassette Buffer) |
| `$038C` | CommandLen (1 byte) |
| `$038D` | SpecificLoad flag (1 byte) |
| `$038E-$039D` | HandleTable (16 bytes, 8 entries) |
| `$039E` | CurrentDevice (1 byte) |
| `$039F-$03A0` | EnvSegmentLo/Hi (2 bytes) |
| `$03A1` | EnvBank (1 byte) |
| `$03A2-$03C9` | SourceBuf (40 bytes, COPY command) |
| `$03CA-$03F1` | DestBuf (40 bytes, COPY command) |
| `$0801` | BASIC SYS launcher (Main segment) |
| `$0820-$0FE8` | Chained pre-API OS Segments (Utils, Api, Loader, Path, Vmm, File consecutive) |
| `$1000` | ApiStub (Stable OS Entry Point — `JMP apiHandler`) |
| `$1003-$1018` | Petsci (petPrintString) |
| `$1019-$10F8` | CommandTable (8-byte fixed-width entries) |
| `$10F9-$1F39` | CommandShell (main loop, dispatcher, built-ins) |
| `$1FA0-$1FFF` | VmmData (vmmInitialized, vmmTempByte, fileScratch, SysDateYear/Month/Day/LastHour) |
| `$03F2-$03F3` | AptSegLo/Hi (App Table VMM segment, allocated by aptInit at startup) |
| `$03F4-$03FB` | Cassette Buffer Workspace (AptTempLoadLo/Hi, AptTempSizeLo/Hi, AptTempEndLo/Hi, AptCandEndLo/Hi) |
| `$2000-$2494` | AppTable segment (apptable.asm) |
| `$2495-$32C5` | ShellExt segment (version, help, dir size routines, date/time routines, MORE, file-status helpers, and shifted messages) |
| `$3400+` | UserProgStart (External commands loaded here — shifted from $3200 to accommodate ShellExt segment growth) |
| `$C000–$CFFF` | VMM MCT (4KB Page Byte-Map, 16MB support) |
| `$FB–$FE` | Zero-page: PrintPtrLo/Hi, NamePtrLo/Hi (User Safe) |
| `$30-$4F` | Zero-page: VI Pointers and State (External Utility) |
| `$61–$6C` | Zero-page: HandlerVec, ParsePos, Temp, HexVal, VmmSeg/Off/Bank (FAC1) |
| `$6D` | Zero-page: FileHandle (Active API Handle) |
| `$6E-$6F` | Zero-page: SrcHandle, DstHandle (Shell Scratch) |
| `$70-$8F` | Zero-page: external-utility scratch. Used by DEBUG pointers, `conway` (`$70-$82`; `$7E-$82` reserved for Multiverse menu/counter state), `pacman` (`$70-$75`), and CASM (`$70-$8F`: general, I/O/VMM, parser/expression, and pass/emission scratch categories). External apps share this range by convention since only one runs at a time. |
| `$02` | Zero-page: CmpBase (User Safe) |

CASM Phase 2 build 1014 uses 2,256 linked code/data bytes and 449 BSS bytes
inside its `$1000` `MAIN` envelope, leaving 1,391 bytes of combined envelope
headroom. The CLI module owns 131 BSS bytes: two 64-byte filename buffers and
three one-byte length/option fields. The file-I/O module owns 271 BSS bytes,
including its 256-byte transfer buffer and bounded handle, slot, state, count,
and diagnostic fields, including the close-slot byte preserved across the OS
service call. Central resources own 47 BSS bytes, including the two
bounded cleanup traversal/status bytes added for real file close handling.
Diagnostics add no BSS; their bounded Phase 2 selector and fixed messages use
45 code bytes and 599 read-only bytes.

CASM Phase 3 Work Package 1 build 1015 synchronized the approved Phase 0C.1
contract and task hierarchy without changing memory ownership or layout. User
completion approval advanced the CASM stage version from `0.1.2` to `0.1.3`.
The linked code/data remains 2,256 bytes with 449 BSS bytes and 1,391 bytes of
combined `$1000` envelope headroom.

CASM Phase 3 Work Package 2 build 1016 approved a future CASM-local 168-byte
mnemonic table but added no runtime state or table data. Completion advanced
the stage version from `0.1.3` to `0.1.4`; linked code/data remains 2,256 bytes
with 449 BSS bytes and 1,391 bytes of combined envelope headroom.

CASM Phase 3 Work Package 3 version build 1018 retains 2,256
linked code/data bytes and 241 relocation points. Storage-only `state.s` adds
exactly 63 BSS bytes with zero code, RODATA, DATA, or zero-page allocation:
16 bytes for source state and 47 bytes for lexer/lookahead/token state. Total
BSS is 512 bytes and combined `$1000` envelope headroom is 1,328 bytes. The
final R6 PRG is 2,746 bytes at `$3400`. CASM is now `0.1.5`; WP3 completion was
approved after user runtime confirmation on 2026-07-16.

CASM Phase 3 Work Package 4 build 1020 adds executable `source.s` (the
rewindable source backend) and routes the consume-only entry point through it.
Linked code/data grows from 2,256 to 2,663 bytes (CODE `$07FE` + RODATA
`$0269`); `source.s` adds no BSS, so total BSS stays 512 bytes. Envelope usage
is `$3400-$4066`, leaving 921 bytes of combined `$1000` headroom. Relocation
points are 315 and the final R6 PRG is 3,301 bytes at `$3400`. CASM is now
`0.1.6`; WP4 completion was approved after user runtime confirmation on
2026-07-16.

CASM Phase 3 Work Package 5 build 1022 adds newline normalization and provenance
inside the existing `source.s`. Linked code/data grows from 2,663 to 2,859 bytes
(CODE `$08C2` + RODATA `$0269`, unchanged RODATA); WP5 adds no BSS, so total BSS
stays 512 bytes and the WP3 state layout is untouched. Envelope usage is
`$3400-$412A`, leaving 725 bytes of combined `$1000` headroom. Relocation points
are 339. `casm.s` was not modified: its consume-only loop already treats a
non-EOF, non-carry result as continue, so `CASM_SOURCE_NEWLINE` needed no
orchestration change. CASM is now `0.1.7`; WP5 completion was approved after user
runtime confirmation on 2026-07-16.

CASM Phase 3 Work Package 6 build 1025 adds `sourceRewind` and `sourceNextLine`
and raises the CASM linker envelope from `$1000` to `$2000` because Phase 3 could
not otherwise fit (725 bytes of headroom against an estimated 1,370-1,940 for
WP6-WP10). Linked code/data grows from 2,859 to 3,171 bytes (CODE `$09FA` +
RODATA `$0269`); Option A's buffer partition adds no BSS, so total BSS stays 512
bytes and the WP3 state layout is untouched. Envelope usage is `$3400-$4262` =
3,683 bytes, leaving 4,509 bytes of `$2000` headroom. Relocation points are 388.
`casm.s` is unchanged. Runtime confirmed `casmln256`/`casm256`/`casmmulti` return
`$16` (shown as the generic `INTERNAL ERROR` until WP10 wires the text) and a
zero-size file cannot be opened. CASM is now `0.1.8`; WP6 completion was approved
after user runtime confirmation on 2026-07-17.

CASM Phase 3 Work Package 7 build 1028 adds `lexer.s`, the minimal lexer core and
first source-layer consumer, plus the `CASM_LEXER_STATE_*` enum in `common.inc`.
Linked code/data grows from 3,171 to 3,544 bytes (CODE `$0B5C` + RODATA `$027C`);
`lexer.s` defines no BSS, so total BSS stays 512 bytes. Envelope usage is
`$3400-$43D7` = 4,056 bytes, leaving 4,136 bytes of `$2000` headroom. Relocation
points are 460. WP7 is Option 1 (static-only): `casm.s` is unchanged and the
lexer has no shipped-path caller until WP10, so it was verified statically and by
non-regression. The version was pre-advanced to `0.1.9` by the separately
committed multi-digit version-stage migration; WP7 completion was approved after
user non-regression confirmation on 2026-07-17.

CASM Phase 3 Work Package 8 build 1030 adds textual and numeric token scanning to `lexer.s`, including dot-prefixed directives, case-insensitive registers, and hexadecimal, decimal, and binary numeric scanners, resolving relative branch limits. Version advanced to `0.1.10`; WP8 completion was approved after user runtime confirmation on 2026-07-17.

CASM Phase 3 Work Package 9 build 1032 adds mnemonic classification with a local 168-byte `mnemonicTable` in `lexer.s` RODATA and case-insensitive search logic in `classifyMnemonic`. Version advanced to `0.1.11`; WP9 completion was approved after user runtime confirmation on 2026-07-17.

CASM Phase 3 Work Package 10 build 1036 integrates the lexer into the main application read loop, prints a temporary token dump (type names, register/directive/number subtype names, mnemonic indices, text content, line/column location), maps contiguous Phase 3 error codes in `diagnostics.s`, fixes length-checked string comparisons, and updates `GenerateCasmTestFixtures.cmake` with alternating space-separated characters to verify source column boundaries. Version advanced to `0.1.12`; WP10 completion was approved after user runtime confirmation on 2026-07-17.

CASM Phase 4 (WP11-WP15) is **complete**, approved by the user on 2026-07-21 at
`0.1.17` build 1079. WP11 added the LL(1) statement parser and
`parseNumericValue`; WP12 the compressed opcode table and addressing-mode
matcher; WP13 the emission engine (`CasmPc`, PRG load-address header, bounded
64-byte staged writes, `.ORG`/`.BYTE`/`.WORD`, branch displacement); WP14
trusted byte-for-byte binary validation; WP15 independent verification and
closeout. Two defects were found by acceptance work rather than by
implementation: a bare `.ORG` silently assembling as `.ORG $0000`, and an
unreachable `CASM_MODE_ZEROPAGE_Y` that miscompiled every `LDX $10,Y` as
absolute,Y (now guarded by build-breaking asserts).

Final Phase 4 measurements: linked CODE `$1A41` + RODATA `$07C0` with `$0467`
BSS, occupying 9,832 of the `$2800` MAIN envelope at both `$3400` and `$3500`,
leaving 408 bytes of headroom. The R6 PRG is 11,057 bytes with 1,172 relocation
points. WP15 changed no production source; it found three record defects (a
missing Phase 4 parent Taskwarrior milestone, three phantom wiki UUIDs for
WP11-WP13, and stale Phase 3 milestone text) and closed WP14's two open
evidence gaps.

CASM Phase 5 WP16 freezes the Phase 0C.3 expression/resolver contract without
adding runtime storage. Its completion-candidate dry run retained Phase 4's
8,705 linked CODE+RODATA bytes, 1,127 BSS bytes, 408-byte `$2800` MAIN headroom,
and 1,172 relocation points at both `$3400` and `$3500` link bases. No
zero-page, BSS, linker, parser, emitter, file, VMM, or cleanup ownership changes.
After explicit WP16 completion approval, the version-only increment produced
`0.1.18` build 1080 with the verified three-banner-byte delta.

CASM Phase 5 WP17 build 1081 adds `expr.o`: 36 CODE bytes and exactly 9 BSS
bytes, with no RODATA, DATA, or ZEROPAGE. Linked CODE+RODATA becomes 8,741 bytes,
BSS becomes 1,136 bytes, and total MAIN use is 9,877 of `$2800`, leaving 363
bytes at both link bases. The R6 artifact is 11,113 bytes with 1,182 relocation
points. No existing storage region or zero-page allocation moved.
User completion approval advanced the version-only final artifact to `0.1.19`
build 1082 with all segment and relocation measurements unchanged.

CASM Phase 5 WP18 build 1084 relocates seven numeric scratch bytes from
`parser.o` to `expr.o`, so total BSS remains 1,136 bytes. `expr.o` is 521 CODE / 16
BSS; `parser.o` is 500 CODE / 6 BSS. Printable Phase 5 diagnostics and checked
arithmetic bring linked CODE+RODATA to 8,997 bytes, total MAIN use to 10,133 of
`$2800`, and headroom to 107 bytes at both link bases. The 11,419-byte R6
artifact has 1,207 relocation points. No zero-page or resource storage changed.
User completion approval advanced the version-only final artifact to `0.1.20`
build 1085 with segment and relocation measurements unchanged.

CASM Phase 5 WP19 candidate build 1088 expands MAIN from `$2800` to `$2A00`.
The evaluator adds 314 CODE bytes and seven BSS bytes: `expr.o` is 835 CODE / 23
BSS, total CODE+RODATA is 9,311 bytes, total BSS is 1,143 bytes, and MAIN use is
10,454 of 10,752 bytes, leaving 298 bytes at both `$3400` and `$3500` bases. The
R6 artifact has 1,268 relocation points. No zero-page or resource storage moved.
User completion approval advanced the version-only final artifact to `0.1.21`
build 1089 with segment and relocation measurements unchanged.

CASM Phase 5 WP20 candidate build 1092 changes parser/emit CODE only: parser.o
is 570 CODE / 6 BSS and emit.o is 460 CODE / 69 BSS. Total CODE+RODATA is 9,366
bytes, BSS remains 1,143 bytes, and MAIN uses 10,509 of `$2A00`, leaving 243
bytes at both bases. The R6 artifact has 1,271 relocation points. The separate
`test_casm_expr` build 1003 uses 2,184 CODE+RODATA and 70 BSS bytes in a `$1000`
envelope, leaving 1,842 bytes; it has no production resource storage.
User completion approval advanced the version-only final CASM artifact to
`0.1.22` build 1093 with segment and relocation measurements unchanged.

CASM Phase 5 WP21 verification leaves production CASM unchanged at 9,366
CODE+RODATA, 1,143 BSS, 10,509 of `$2A00` MAIN, 243 bytes headroom, and 1,271
relocations. The expanded 30-case `test_casm_expr` build 1005 uses 2,310
CODE+RODATA and 72 BSS bytes in its `$1000` envelope, leaving 1,714 bytes, with
296 relocations. No production memory region, zero page, or resource changed.
User completion approval advanced the version-only final CASM artifact to
`0.1.23` build 1094 with segment and relocation measurements unchanged.

Carried forward to Phase 11 hardening, none blocking: `CasmOutputCreated` is set
on any successful write-mode open, so it conflates "CASM created this file" with
"CASM opened an existing one" — assembling over an existing output is safe today
only because the latched `63,FILE EXISTS` status makes `fileDelete`'s
`checkDeviceReady` preflight bail before the delete runs. Also, CASM contains no
`SED` and every `ADC`/`SBC` establishes carry, but it has no entry `CLD` either,
so it assumes the caller left decimal mode clear. And `brain/KNOWLEDGE.md` has
CASM Phase 1/2/3 contract sections but no Phase 4 one.

Phase 5 (minimal expression evaluator) is unblocked. Parent contract:
`brain/plans/2026-07-20-casm-phase5-minimal-expression-evaluator.md`; entry work
package WP16: `brain/plans/2026-07-21-casm-phase5-wp16-prerequisite-reconciliation.md`.

**CASM Phase 6A WP22 prerequisite reconciliation and Phase 0C.4 freeze**:
active on `feature/casm-phase6-wp22` from `main` commit `dcb74bb`, baseline
CASM `0.1.23` build 1094 (PRG hash
`18d2f6cce7ffbcc7de8aa71db3da9e3b6d9ee3bb1cd07e69b072dd0d0884e703`, matching
the WP21 closeout exactly; a no-change rebuild reproduced the identical hash).
Researched the OS VMM primitive contract directly from `src/command64/vmm.asm`
rather than relying on `docs/vmm-api.md` alone, and found three facts that
materially bound Phase 6A's design: (1) `vmmAlloc` always returns
`VmmSegLo = 0`, so an allocation's identity is exactly `(VmmSegHi, VmmBank)` —
the same two fields the pre-existing 3-byte `CasmVmmRegistry` record already
stores, meaning `DOS_FREE_MEM` wiring needs no registry growth; (2) the 16-bit
`VmmOffLo/Hi` transfer cursor can only reach 65536 bytes from a fixed
`SegHi`/`Bank` pair regardless of how many pages an allocation was actually
granted, so WP22 froze a hard 65536-byte cap per CASM VMM allocation, with
larger needs spanning multiple registry slots; (3) `vmmReadBlock`/
`vmmWriteBlock` perform no bounds checking against an allocation's granted
size — an oversized transfer silently corrupts whatever REU page follows, so
CASM's own windowed wrapper (WP24) must self-enforce the bound the OS will
not. Also documented that `VMM_ERR_INVALID` conflates "no REU" with
"zero-paragraph request", and that REU contents are undefined at boot (per
the environment-variable subsystem's prior VMM use). Deliberately deferred
the MAIN-envelope-size and literal `CASM_DIAG_*` value decisions to WP23,
matching how WP13/WP19 made those calls inside their own implementing
package rather than in a preceding freeze package. Created the CASM Phase 6A
Taskwarrior milestone (`d68e6c58`) and WP22-WP25 children
(`eb7541e5`/`8782e75d`/`228daccc`/`544a04bd`), sequentially dependent, matching
the Phase 5 WP16-WP21 chain pattern. Defined a nine-case fixture matrix
binding on WP23-WP25 (allocation, reuse-after-free, registry exhaustion, REU
exhaustion, windowed read/write, replay-after-discard, boundary offset,
CASM-side bounds rejection, and no-REU failure). Parent contract:
`brain/plans/2026-07-21-casm-phase6-vmm-storage-and-symbol-table.md`; WP22
detailed plan:
`brain/plans/2026-07-21-casm-phase6-wp22-prerequisite-reconciliation.md`.

User confirmed the runtime banner at the restored `0.1.23` build 1094
baseline, then approved WP22 completion. The verified `0.1.24` increment was
applied for real: build 1095 reproduced the dry run's exact PRG hash
(`66594cd2b278b78705cacddf6e0a70d41c7574f8c2e84c6a101006bdd4958e64`), a
no-change rebuild held at 1095, and both `test_image_d64` and `image_d64`
passed. WP22 is complete; WP23 (`8782e75d`) is unblocked in Taskwarrior but
requires its own separate plan approval before activation.

**CASM Phase 6A WP23 VMM allocation core** (complete):
active on `feature/casm-phase6-wp23` from `feature/casm-phase6-wp22` at
`d0878d6`, baseline `0.1.24` build 1095. User approved the WP23 plan as
drafted; the ask for a "test harness and fixtures if needed" was resolved as
static verification only, matching the plan's own exclusion of runtime
fixtures for this package. Created `vmm_store.s` (`vmmStoreAlloc`/
`vmmStoreFree`) wired to `DOS_ALLOC_MEM`/`DOS_FREE_MEM`, and replaced
`cleanupVmmStub` with a real `vmmStoreFree` call in `resources.s`. Two ABI
questions surfaced and were resolved with the user before writing code: no
16-bit byte count can ever need more than 4,096 paragraphs (= the 65536-byte
cap), so the plan's proposed `CASM_DIAG_VMM_ALLOC_TOO_LARGE` rejection path
is unreachable and was dropped — the real hazard was the "add 15, shift
right 4" rounding trick overflowing 16-bit arithmetic for byte counts
65,521-65,535, fixed by checking the carry and clamping to the
proven-exact 4,096 paragraphs rather than rejecting anything; a zero-byte
request is still rejected locally (`CASM_DIAG_VMM_ALLOC_FAILED`), which is
what keeps a later `VMM_ERR_INVALID` unambiguous per WP22's finding. Found
and fixed two register-clobber bugs while writing this (before any build):
`vmmStoreFree` reusing one scratch byte for both the slot number and
SegHi/Bank staging, and `resourcesCleanup`'s VMM loop relying on `X`
surviving a call that documents `X` as clobbered — both fixed using the
existing `CasmVmmSegHi`/`CasmVmmBank` staging pair and `CasmCleanupOffset`
scratch-preservation pattern respectively. Reserved diagnostics `$28`-`$2B`
in `common.inc` with contiguous-range asserts. Measured MAIN usage at
10,647/10,752 bytes (105 bytes free) — no size change needed, unlike the
WP13/WP19 precedent of requiring one; user confirmed proceeding on that
basis. User ran a VICE sanity check (CASM against a trusted fixture),
confirmed clean assemble/exit, and approved completion. Final `0.1.25` build
1097 matched the dry run's exact PRG hash, a no-change rebuild held at 1097
across two more builds, and both `test_image_d64` and `image_d64` passed.
WP23 detailed plan:
`brain/plans/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md`; walkthrough:
`brain/walkthroughs/2026-07-21-casm-phase6-wp23-vmm-allocation-core.md`. WP23
was committed on `feature/casm-phase6-wp23` (`42968f0`).

**CASM Phase 6A WP24 windowed transfer and replay** (complete): active on
`feature/casm-phase6-wp24` from `a60cb89`, baseline
`0.1.25` build 1097. Reviewing the Phase 0C.4 freeze against WP23's actual
implementation surfaced a real, previously unresolved gap: the freeze
requires WP24's windowed transfer to "independently track each allocation's
granted size" and bounds-check `offset + count` against it, but
`CasmVmmRegistry`'s 3-byte record (confirmed sufficient by WP22/WP23 only
for allocation/free identity) had no field to read a granted size from.
Resolved by growing `CASM_VMM_REC_SIZE` from 3 to 4 bytes, adding a
granted-page-count field computed identically to `vmmAlloc`'s own
paragraph-to-page rounding, with `resourceRegisterVmm` remaining the
registry's sole writer (preserving the single-writer discipline WP23
established) — and as a bonus, the slot-to-byte-offset computation turned
from `ASL`+`ADC` into a plain two-`ASL` `slot*4`. Also used, from a working
precedent already in `src/external/edlin/buffer.s`: `DOS_VMM_READ`/
`DOS_VMM_WRITE` take their Seg/Off/Bank/count arguments through fixed OS
zero-page cells, not registers, unlike `DOS_ALLOC_MEM`/`DOS_FREE_MEM`. User
resolved both open questions: staging buffer sized at implementation time
(`CasmVmmBuffer`, 32 bytes, reusing already-reserved `$78-$7F` scratch, no
new zero-page byte), and a local bounds violation shares
`CASM_DIAG_VMM_TRANSFER_FAILED` with a genuine OS-level rejection.
Implemented `vwPrepareTransfer` (private, shared bounds-check/staging),
`vmmWindowRead`/`vmmWindowWrite`/`vmmReplay` in `vmm_store.s`. The
offset+count-to-page-count bounds check avoids representing 65536 as a
16-bit value (same hazard as `vmmStoreAlloc`'s rounding) via a top-nibble
extraction plus round-up check rather than an addition that could overflow.
Measured MAIN overflow (123 bytes at `$2A00`); user approved `$2A00` ->
`$2B00` (133 bytes free). User ran a VICE sanity check (CASM against a
trusted fixture), confirmed clean assemble/exit. Completion dry-run
`0.1.26.1099` verified (2-byte diff, no-change rebuild stable); baseline
`0.1.25.1098` restored exactly via `git checkout`. WP24 plan:
`brain/plans/2026-07-21-casm-phase6-wp24-windowed-transfer-and-replay.md`;
walkthrough:
`brain/walkthroughs/2026-07-21-casm-phase6-wp24-windowed-transfer-and-replay.md`.
User approved completion; final `0.1.26` build 1099 matched the dry run's
exact PRG hash, no-change rebuild stable, both images pass. WP24 is
complete; WP25 (`544a04bd`) is unblocked but requires its own separate plan
approval before activation.

## C64 Hardware Gotchas (hard-won)

- **Segment Overlaps**: Proactive realignment of segments (64-byte padding) required as shell code grows.
- **BRK Trap Model is non-viable** for high-level OS calls on C64 due to KERNAL non-reentrancy.
- **Handle LFNs**: Use LFN 2-9 for handles. LFN 13=cmdDir, LFN 14=checkExistence, LFN 15=command channel. Never use LFN 2 for built-in commands.
- **BASIC warm start = `jmp $E37B`** — not `jmp ($0338)`.
- **KA `.text` maps lowercase ASCII → PETSCII control codes** — send `$0E` at startup for mixed-case.
- **KernalGetIn ($FFE4) clobbers Y**: Always preserve Y across keyboard polling loops.
- **PETSCII lowercase mode dispatch**: Use `ora #$20` (not `and #$7F`) to normalize unshifted keys ($41-$5A) to lowercase ($61-$7A). `and #$7F` produces $01-$1A which matches nothing.
- **DEBUG Case Normalization**: Shifted letters in `petscii_mixed` are `$C1`–`$DA` whereas unshifted are `$41`–`$5A`. Use `and #$7F` to strip bit 7 and map shifted to unshifted, NOT `ora #$20`.
- **C64 Custom Byte I/O Channels**: When opening a file for byte-by-byte custom read/write using `CHKIN`/`CHKOUT` and `CHRIN`/`ChROUT`, you must use a secondary address (SA) between 2 and 14 in `KernalSETLFS`. Secondary address 0 is hardcoded for KERNAL `LOAD` and 1 for `SAVE` and cannot be used for standard custom I/O streams.
- **ahExit stack discipline**: Each program run orphans 4 bytes (jsr UserProgStart + jsr $1000). Always reset SP=`#$FF` in `ahExit` before `jmp mainLoop`.
- **6502 Relative Branch limit (127 bytes)**: Standard relative branches like `bcs`/`bcc` will trigger assembler errors if the target is further than +127/-128 bytes. Use a conditional branch to skip an absolute `jmp` trampoline (e.g. `bcc no_overflow; jmp target; no_overflow:`) for long distances.
- **KickAssembler Named Anonymous Labels**: KickAssembler anonymous labels must be exactly `!:` (without any name). Putting a name like `!name+:` triggers a token syntax error. Use standard local labels like `_name:` instead.

## Pending Tasks

- [x] Implement `DEBUG` Unassemble (U) command (Disassembler)
- [x] DEBUG code review + remediation (Build 1012 — cuOpRel ZP alias, parseList overflow)
- [x] **Execute App Manager Phase A** — plan at `docs/superpowers/plans/2026-05-13-app-manager-phase-a.md`
- [x] Binary Relocator (Phase 6B prerequisite)
- [x] Implement `DRIVE` command
- [x] Add support for multiple devices (8, 9, 10, 11)
- [ ] Support subdirectories (1581 / SD2IEC)
- [x] Environment variable storage (`SET`, `PATH`) in REU
- [x] Implement `VOL` and `LABEL` commands (disk directory header editing)
- [x] Develop external `vi` alike editor (Phase 6C) (Code review completed; remediation pending)
- [x] Implement `TIME` command using CIA 1 TOD clock
- [x] Implement `DATE` command (software calendar in resident kernel RAM)
- [ ] Phase 6D: Cooperative VMM Swapping & Memory Safety
- [/] Conway Multiverse Generalization, Menu and Counter (Plan written, transcript saved)



## Superpowers Docs Index

| Document | Path |
| ---------- | ------ |
| App Manager design | `docs/superpowers/specs/2026-05-13-app-manager-design.md` |
| App Manager Phase A plan | `docs/superpowers/plans/2026-05-13-app-manager-phase-a.md` |
| DEBUG remediation plan | `docs/superpowers/plans/2026-05-13-debug-asm-zp-alias-and-listbuf-overflow.md` |
| Unified build system design | `docs/superpowers/specs/2026-05-13-unified-build-system-design.md` |
| Unified build system plan | `docs/superpowers/plans/2026-05-13-unified-build-system.md` |
| Binary Relocator plan | `docs/superpowers/plans/2026-07-04-binary-relocator-phase-b.md` |
| Staged ca65 rewrite plan | `docs/superpowers/plans/2026-07-04-staged-rewrite-ca65.md` |
