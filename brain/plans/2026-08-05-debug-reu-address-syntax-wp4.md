# DEBUG REU and Address Syntax WP4 Detailed Plan

**Status:** Approved; implementation in progress

**Created:** 2026-08-05

**Parent plan:** `brain/plans/2026-08-03-debug-reu-and-address-syntax.md`

**Work package:** WP4, Status Reporting

**Implementation target:** `src/external/debug/debug.s`

**Implementation branch:** `feature/debug-reu-address-wp4` (branched from
`debug` after WP3 merged, commit `597ec59`)

## 1. Purpose

Give `XS` real behavior: report system-wide VMM availability and page
counters through `DOS_GET_SYSTEM_INFO`, and report DEBUG's own active
allocations from the WP2 registry. `XS handle` reports one allocation only.
This closes the loop the parent plan's Section 4 exit criterion asks for:
"users can identify each handle's capacity and page count before issuing
page-relative `XM` commands" (WP5).

## 2. Confirmed Baseline

1. WP3 is merged into `debug` (commit `597ec59`). `XA`/`XD` are real; `Q`
   routes through `freeAllReu`. `cmdReuStatus` still `jmp reuStub`.
2. `cmdExtended` already `jsr skipSpaces` before `jmp cmdReuStatus`, so `Y`
   arrives at either the null terminator (bare `XS`) or the first non-space
   byte of a handle operand (`XS handle`) — the same entry shape `XA`/`XD`
   already rely on.
3. `printReuAllocSummary` (`debug.s`, added in WP3) prints
   `<handle>: SEG=xx BANK=xx PARA=xxxx PAGES=xx SIZE=xxxx` from
   `reuXferSlot` (the handle) and `reuXferParaLo/Hi` (destroyed by the call
   to derive `PAGES`/`SIZE`). It reads `SegHi`/`Bank` itself from
   `reuSegHi,x`/`reuBank,x` using `reuXferSlot`. WP4 reuses it unmodified
   for both `XA`-triggered and `XS`-triggered output by staging
   `reuXferSlot`/`reuXferParaLo/Hi` from the registry before calling it —
   see Section 5.
4. `parseReuHandle`, `requireEnd`, `getReuRecord` are unchanged and reusable
   exactly as in WP3's `XD`.
5. `DOS_GET_SYSTEM_INFO` ($5C) is called through `OS_API` exactly as in
   `src/external/dash/dsys.s`'s `QUERYSYSTEMINFO`: `X/Y` = destination
   buffer pointer Lo/Hi, `A = DOS_GET_SYSTEM_INFO`, `jsr OS_API`. Success:
   C=0, the 24-byte record is written. Failure: C=1, `A` = an OS error code,
   buffer unchanged. In practice (`src/command64/api.asm:348`,
   `ahGetSystemInfo`) the only failure modes are a null destination pointer
   or a pointer with a high byte outside `$02-$CF`; a static DEBUG BSS
   buffer can never trigger either, so this failure path is defensive only,
   not reachable in normal operation.
6. The 24-byte record layout (`include/ca65/command64.inc:80-103`,
   `SYS_INFO_OFF_*`) relevant to WP4:
   - Offset 11 `VmmFlags`: **only bit 0 (active) is ever set by the current
     OS implementation** (`api.asm:435-438`, `:524-528`). The struct
     comment mentions a bit 1 "probed" flag, but `ahGetSystemInfo` never
     sets it — grep of `src/command64/api.asm` shows no write to any bit
     beyond bit 0. WP4 must not report a "probed" status that the OS does
     not actually populate; report only active/inactive from bit 0. This
     resolves the parent plan's Section 5.4 ambiguity about "VMM
     active/probed flags" — there is exactly one real flag today.
   - Offsets 14-15 `VmmTotalPages`, 16-17 `VmmAllocPages`, 18-19
     `VmmFreePages`: all three are 16-bit little-endian page counts, and
     `ahGetSystemInfo` zeros all three (along with `VmmFlags` and
     `VmmPageSize`) in the inactive-VMM branch (`api.asm:524-552`), so WP4
     never needs to special-case "inactive" formatting — printing the
     fields unconditionally after a successful call already shows zeros
     when VMM is inactive.
   - Total system capacity is 4096 pages (`VmmTotalPages = $1000`) of 4KB
     each — the same 4KB page unit `XA`'s derived `PAGES=` field already
     uses, and the same `$1000`-paragraph single-allocation cap `XA`
     enforces. No unit conversion is needed between `XS`'s system counters
     and `XA`'s per-allocation counters.
7. This settles the parent plan's WP0 approval question 6 ("system-wide
   counters or DEBUG-local only"): `DOS_GET_SYSTEM_INFO` is a stable,
   already-shipped contract (used unmodified by DASH's System page since
   an earlier phase), so WP4 includes system-wide counters.
8. Only `printHex8` exists for numeric output; 16-bit values print as two
   `printHex8` calls (Hi byte, then Lo byte), matching `XA`'s `PARA=`
   field.
9. DEBUG's private zero page `$70-$7F` remains fully occupied; WP4 adds no
   zero-page state. The current `MAIN` envelope (`$3800`, size `$2000` =
   8192 bytes, covering `CODE`+`RODATA`+`DATA`+`BSS`) has substantial
   headroom after WP3's build (7,349 code bytes; existing BSS — registry,
   buffers, register-save state — is on the order of 150-200 bytes, well
   under the remaining ~700 bytes before adding WP4's 24-byte buffer).

## 3. Scope

### 3.1 Included

- Implement `cmdReuStatus` for both grammars: bare `XS` and `XS handle`.
- Call `DOS_GET_SYSTEM_INFO` into a new 24-byte DEBUG-local BSS buffer for
  the bare-`XS` system section.
- Report VMM active/inactive (bit 0 of `VmmFlags` only) and
  `VmmTotalPages`/`VmmAllocPages`/`VmmFreePages`.
- List every active DEBUG-owned allocation (bare `XS`) or exactly one
  (`XS handle`), reusing `printReuAllocSummary`'s existing output line
  format unmodified.
- Print an explicit "no allocations" indicator when bare `XS` finds no
  active registry slots.
- Reject an invalid, out-of-range, or inactive handle and reject trailing
  input for `XS handle`, before any OS call, matching `XD`'s precedent.
- Build and inspect DEBUG size/relocation/BSS growth.
- Verify under VICE: no allocations, multiple allocations, an invalid
  handle, and VMM disabled.

### 3.2 Excluded

- `XM` transfer implementation and `page:offset` parsing (WP5/WP6).
- Any change to `XA`, `XD`, `Q`, or `freeAllReu`.
- Reading or exposing the OS Memory Control Table directly (parent plan
  Design Decision 3 / Section 5.4 explicitly forbids this — `XS` uses only
  the public `DOS_GET_SYSTEM_INFO` record and DEBUG's own registry).
- A "probed" VMM status distinct from "active" (Section 2, item 6 — the OS
  does not populate this bit today).
- New private zero-page state.
- DEBUG version/changelog bump for the combined REU+syntax feature
  (deferred to WP7 per the parent plan).

## 4. `XS` Contract (`cmdReuStatus`)

Grammar: `XS` or `XS handle`.

### 4.1 Dispatch

```asm
cmdReuStatus:
    lda inputBuf, y
    bne crsHandleForm
    jmp crsSystemForm
```

`Y` is already past any leading spaces (`cmdExtended`'s `jsr skipSpaces`),
so a nonzero byte here always starts a real operand, never incidental
whitespace — the same shape `cmdReuAlloc`/`cmdReuFree` already rely on for
their own "has an argument" check.

### 4.2 `XS handle`

1. `lda #1` (require active); `jsr parseReuHandle`. On C=1, `jmp reuError`
   (selector already in `A`) — reuses `XD`'s exact pattern.
2. `jsr requireEnd`. On C=1, `lda #REU_ERR_TRAILING_INPUT; jmp reuError`.
3. `X` still holds the parsed handle (unclobbered by `requireEnd`, same
   guarantee `XD` relies on).
4. Stage and print via the shared helper (Section 5): `stx reuXferSlot`,
   copy `reuParagraphLo/Hi,x` into `reuXferParaLo/Hi`, `jsr
   printReuAllocSummary`.
5. Return C=0.

No system-wide section is printed for `XS handle` — only the one
allocation's line, matching the parent plan's Section 5.4 "`XS handle`
reports one active allocation."

### 4.3 Bare `XS`

1. Call `DOS_GET_SYSTEM_INFO`: `ldx #<sysInfoBuf`, `ldy #>sysInfoBuf`,
   `lda #DOS_GET_SYSTEM_INFO`, `jsr OS_API`.
2. On C=1 (defensive only — see Section 2, item 5): report a failure via
   `reuError` (selector choice is an Approval Question, Section 12).
3. On C=0, print the system section (Section 4.4).
4. Loop `X` over the four registry slots. For each `reuActive,x <> 0`,
   stage `reuXferSlot`/`reuXferParaLo/Hi` from the registry and `jsr
   printReuAllocSummary`, exactly as in Section 4.2 step 4.
5. If no slot was active, print a single `NONE` line instead of any
   allocation rows (Approval Question, Section 12, confirms the exact
   literal).
6. Return C=0.

### 4.4 System Section Output Format

```text
-XS
VMM ACTIVE
PAGES TOTAL=1000 ALLOC=0011 FREE=0FEF
00: SEG=02 BANK=00 PARA=0001 PAGES=01 SIZE=0010
03: SEG=14 BANK=00 PARA=0001 PAGES=01 SIZE=0010
```

With no active DEBUG allocations:

```text
-XS
VMM ACTIVE
PAGES TOTAL=1000 ALLOC=0000 FREE=1000
NONE
```

With VMM inactive (REU disabled or never probed):

```text
-XS
VMM INACTIVE
PAGES TOTAL=0000 ALLOC=0000 FREE=0000
NONE
```

Fields: literal `VMM `, then `ACTIVE` or `INACTIVE` (bit 0 of
`sysInfoBuf + SYS_INFO_OFF_VMM_FLG`) — the parent plan's "probed" wording is
not implemented by this line (Section 2, item 6). CR. Literal `PAGES
TOTAL=`, `printHex8` of `VmmTotalPages` Hi then Lo, literal ` ALLOC=`,
`printHex8` of `VmmAllocPages` Hi then Lo, literal ` FREE=`, `printHex8` of
`VmmFreePages` Hi then Lo. CR. Then zero or more `printReuAllocSummary`
lines, or one `NONE` line.

`XS handle`'s single-allocation line is byte-identical in format to one of
these rows and to `XA`'s own success output, since both are produced by the
same `printReuAllocSummary` call.

## 5. Shared Helper: Staging a Registry Slot for Display

`printReuAllocSummary` (WP3) already expects `reuXferSlot` (the handle to
label the line with) and `reuXferParaLo/Hi` (destroyed in place to derive
`PAGES=`/`SIZE=`) to be pre-staged, and reads `SegHi`/`Bank` itself from the
registry via `reuXferSlot`. WP4 adds a small wrapper so both `XS` call
sites (Section 4.2 step 4, Section 4.3 step 4) share one staging sequence
instead of duplicating three instructions twice:

```asm
; In: X = an active registry slot. Stages reuXferSlot/reuXferParaLo/Hi from
; the registry and prints one XA-format summary line for it.
; Clobbers: A, X, Y; reuXferSlot and reuXferParaLo/Hi (already scratch).
printReuStatusOne:
    stx reuXferSlot
    lda reuParagraphLo, x
    sta reuXferParaLo
    lda reuParagraphHi, x
    sta reuXferParaHi
    jmp printReuAllocSummary
```

This never touches `reuParagraphLo/Hi,x` (the permanent registry copy) —
only the WP3 scratch cells, which `XA` already treats as destroyed after
every summary print. `XD`'s clear-on-success path and `freeAllReu`'s sweep
are both unaffected: neither reads `reuXferParaLo/Hi`.

## 6. New BSS State

Add one 24-byte buffer, declared with the existing registry state:

```text
sysInfoBuf: .res SYS_INFO_SIZE, 0   ; DOS_GET_SYSTEM_INFO destination record
```

`SYS_INFO_SIZE` (`= 24`) is already defined in `include/ca65/command64.inc`
and visible to `debug.s` via `command64.inc`. No new zero-page state; no
change to the 3-byte WP3 transfer scratch beyond the read-only reuse in
Section 5.

Total growth: 24 bytes, versus WP2's 20-byte registry and WP3's 3-byte
scratch. No `$70-$7F` ownership change.

## 7. Error Selector Usage Summary (WP4)

| Selector | WP4 trigger |
|---|---|
| `REU_ERR_MISSING_ARG` | not reachable — `XS` with no operand is the valid bare form, not an error |
| `REU_ERR_VALUE_RANGE` | `XS handle` with a malformed or out-of-range handle (via `parseReuHandle`) |
| `REU_ERR_TRAILING_INPUT` | extra tokens after `XS handle`'s handle |
| `REU_ERR_INACTIVE_HANDLE` | `XS handle` on a currently-inactive handle |

No existing selector cleanly names "the `DOS_GET_SYSTEM_INFO` call itself
was rejected" (Section 4.3 step 2); this is an Approval Question (Section
12) since, unlike WP3's reuse of `REU_ERR_CLEANUP` for two conceptually
identical failure sites, this failure has no existing conceptual sibling in
the fifteen-item taxonomy.

## 8. Atomic Implementation Increments

### Increment 1: `XS handle` (Single-Record Report)

1. Add `sysInfoBuf` BSS (needed by Increment 2, but harmless to add now for
   a single build-and-measure checkpoint).
2. Add `printReuStatusOne`.
3. Implement the `XS handle` branch of `cmdReuStatus` (Section 4.2).
4. Build DEBUG.
5. Verify under VICE: `XS` on an active handle prints the correct summary
   line (identical format to that handle's original `XA` output); `XS` on
   an inactive, out-of-range, or malformed handle rejects with the correct
   selector; trailing input after a valid handle rejects.

Exit criterion: `XS handle` output is byte-identical to the same
allocation's `XA` success line, and all negative cases reject before any
OS call.

### Increment 2: Bare `XS` (System and Registry Sweep)

1. Implement the `DOS_GET_SYSTEM_INFO` call and system-section printing
   (Section 4.4).
2. Implement the four-slot sweep with `printReuStatusOne`, and the `NONE`
   fallback.
3. Build DEBUG.
4. Verify under VICE: `XS` with zero, one, and four active allocations;
   confirm the system section's `ALLOC=`/`FREE=` track `XA`/`XD` activity
   correctly relative to the fixed `TOTAL=1000`.

Exit criterion: bare `XS` reports accurate system counters and lists every
currently active DEBUG allocation, matching the live registry state at the
moment of the call.

### Increment 3: WP4 Regression and Completion Gate

1. Build `debug`, `image_d64`, and `test_image_d64`.
2. Re-run WP1 `G`/`T`/`P` (with fixture bytes poked via `E` first — see the
   WP3 walkthrough's documented gap) and WP2/WP3 `XA`/`XD`/`Q` smoke cases.
3. Run the parent plan's Section 10.3 item 11 ("`XS` reflects allocation
   and release accurately") and Section 10.6 items 1-2 (REU disabled: `XS`
   reports unavailable).
4. Inspect registry/BSS storage, DEBUG envelope, and relocation output.
5. Update task, changelog, memory, and DOX records.
6. Produce the manual walkthrough and obtain user confirmation.

Exit criterion: `XS` and `XS handle` behavior passes with no regression to
WP1/WP2/WP3 behavior.

## 9. Build and Static Verification

Use CMake only; do not invoke ca65/ld65 directly.

1. Build `debug` after each increment.
2. Build `image_d64` before VICE work.
3. Build `test_image_d64` at the completion gate.
4. Require no warnings or errors attributable to WP4.
5. Record DEBUG code bytes and relocation count against WP3's merged
   baseline (build 1122: 7,349 code bytes, 851 relocation points).
6. Confirm the binary remains within the existing 8KB `MAIN` envelope.
7. Confirm BSS growth is exactly 24 bytes beyond WP3's state.
8. Confirm no new `$70-$7F` symbol or ownership.
9. Confirm `DOS_VMM_READ` and `DOS_VMM_WRITE` remain uncalled from any WP4
   code path (only `DOS_GET_SYSTEM_INFO` is newly introduced, alongside the
   existing `DOS_ALLOC_MEM`/`DOS_FREE_MEM` call sites from WP3).
10. Let CMake update `BUILD_DEBUG`; never edit generated includes.

## 10. VICE Verification Matrix

Follow `.agents/workflows/vice-mcp-testing.md`. Test REU-enabled and
REU-disabled as separate environments (REU must be cleared on the VICE
`REU` resource *before* Command64's own boot — the OS's VMM-active flag
latches at Command64 startup, confirmed during WP3's negative-environment
testing).

### `XS handle` Cases

```text
XA 0001              ; allocate a known handle first
XS 0                 ; expect the identical line XA 0001 just printed
XS 9                 ; expect error (out of range)
XD 0
XS 0                 ; expect error (inactive)
XS 0 EXTRA           ; expect error (trailing input) -- allocate 0 again first
```

### Bare `XS` Cases

```text
XS                   ; fresh DEBUG, zero allocations: VMM ACTIVE, ALLOC=0000, NONE
XA 0001
XA 0100
XS                   ; two rows, ALLOC= reflects both
XD 0
XS                   ; one row (handle 1), ALLOC= decreased
```

### REU-Disabled Cases

```text
XS                   ; VMM INACTIVE, all counters 0000, NONE
```

### Existing Command Smoke

- `G =6000` (after `E 6000 60`), `T =6100`/`P =6100` (after
  `E 6100 EA EA EA 60`), `Q` behave as in WP1/WP2/WP3.
- `XA`/`XD`/`Q` allocation lifecycle behaves as in WP3.

## 11. Documentation and Tracking

After plan approval and before source implementation:

1. Create `wiki/tasks/debug-reu-address-syntax-wp4.md`.
2. Create and activate the matching Taskwarrior task via the `task` CLI
   directly.
3. Synchronize `brain/task.md`.

During implementation:

- Record build and verification evidence after each increment.
- Add `CHANGELOG.md` behavior only when `XS`/`XS handle` land and are
  verified.
- Update `brain/MEMORY.md` when `sysInfoBuf` is added.
- Defer public DEBUG user-guide command syntax for the full `X` family to
  WP7's documentation pass, consistent with WP2/WP3 precedent.
- Perform the mandatory DOX closeout: root `AGENTS.md`, `src/AGENTS.md`,
  `src/external/AGENTS.md`, and `src/external/debug/AGENTS.md` (the latter
  already documents the registry-ownership contract WP4 reads from but does
  not change; confirm no wording drift rather than assuming no edit is
  needed).

## 12. Approval Questions

Resolved 2026-08-05:

1. Bare `XS` with no active allocations prints the literal `NONE` line
   (Section 4.3 step 5, Section 4.4). Approved as written.
2. A rejected `DOS_GET_SYSTEM_INFO` call (Section 7) uses no new selector
   for WP4: print the existing generic `errUnknown` message via
   `reuError`-style plumbing, documented as an unreachable-in-practice
   defensive path. **Flagged for a future work package**: if this path is
   ever observed to actually fire (it should not, per Section 2 item 5's
   analysis of `ahGetSystemInfo`'s only two failure conditions, neither of
   which a static DEBUG BSS pointer can trigger), add a dedicated selector
   then, informed by real evidence of how it failed, rather than guessing
   its shape now.
3. WP4 reports only `ACTIVE`/`INACTIVE` from `VmmFlags` bit 0 and does not
   expand scope into `src/command64/api.asm` to add a real "probed" bit.
   Approved as written (Section 2 item 6, Section 4.4).
4. The `XS` field layout and ordering in Section 4.4 (`VMM ACTIVE`/
   `INACTIVE` line, then `PAGES TOTAL=/ALLOC=/FREE=` line, then
   per-allocation rows) is approved as written.

## 13. Completion Gate

WP4 may be presented for user confirmation when:

1. `XS handle` prints one allocation's summary in the exact format `XA`
   already produces for it, and rejects invalid/inactive/out-of-range
   handles and trailing input before any OS call.
2. Bare `XS` prints accurate VMM active/inactive status and
   total/allocated/free page counts from `DOS_GET_SYSTEM_INFO`.
3. Bare `XS` lists every currently active DEBUG allocation, or prints the
   approved empty-registry indicator when none are active.
4. No OS Memory Control Table access, and no `DOS_VMM_READ`/`DOS_VMM_WRITE`
   call, is reachable from any WP4 code path.
5. No new private zero-page state exists; BSS growth is exactly 24 bytes.
6. DEBUG remains relocatable and inside its linker envelope.
7. WP1, WP2, and WP3 smoke tests still pass.
8. Task, changelog, memory, and DOX records are synchronized.
9. A manual walkthrough is available, covering REU-enabled and
   REU-disabled environments and both `XS` grammars.

Do not mark WP4 complete until the user confirms the walkthrough.
