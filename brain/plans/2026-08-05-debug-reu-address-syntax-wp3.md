# DEBUG REU and Address Syntax WP3 Detailed Plan

**Status:** Approved; implementation in progress

**Created:** 2026-08-05

**Parent plan:** `brain/plans/2026-08-03-debug-reu-and-address-syntax.md`

**Work package:** WP3, Allocation Lifecycle

**Implementation target:** `src/external/debug/debug.s`

**Implementation branch:** `feature/debug-reu-address-wp3` (branched from `debug`
after WP2 merged, commit `bd5539d`)

## 1. Purpose

Give `XA` and `XD` real behavior: allocate and free VMM-backed REU memory
through `DOS_ALLOC_MEM`/`DOS_FREE_MEM`, register successful grants in the
WP2 registry, and route `Q` through cleanup of every DEBUG-owned allocation
before exit. `XM` and `XS` remain WP2 stubs; no transfer or status reporting
is implemented here.

## 2. Confirmed Baseline

1. WP2 is merged into `debug` (commit `bd5539d`). `cmdExtended` routes exact
   `XA`/`XD`/`XM`/`XS` tokens to `cmdReuAlloc`/`cmdReuFree`/`cmdReuMove`/
   `cmdReuStatus`; all four currently `jmp reuStub`.
2. `initReuRegistry` clears `reuActive/reuSegHi/reuBank/reuParagraphLo/
   reuParagraphHi` (4 bytes each) at `start`, before the welcome message.
3. `parseReuHandle` (`debug.s:412`), `findFreeReuHandle` (`:453`), and
   `getReuRecord` (`:473`) exist with the contracts documented at their call
   sites; WP3 uses all three unmodified.
4. `parseHexArg` (`debug.s:3432`) parses 1-4 hex digits into `HexValLo/Hi`,
   rejects zero digits and a 5th digit, and returns C=1 on either failure.
   `requireEnd`/`skipSpaces` are available from WP1.
5. `reuError` (`debug.s:379`) prints the existing generic `errUnknown`
   message and returns with the selector restored in `A`, C=1. WP3 does not
   add new user-facing strings for negative paths, matching WP2's deferred
   diagnostics.
6. `DOS_ALLOC_MEM` ($48) and `DOS_FREE_MEM` ($49) are called through
   `OS_API` ($1000) exactly as in `src/external/casm/vmm_store.s`
   (`vmmStoreAlloc`/`vmmStoreFree`):
   - Alloc: `A=DOS_ALLOC_MEM`, `X/Y = paragraphs Lo/Hi`, `jsr OS_API`.
     Success: C=0, `X=SegHi`, `Y=Bank`. Failure: C=1, `A=VMM_ERR_INVALID`
     (no REU / not initialized) or `VMM_ERR_NOMEM`.
   - Free: `A=DOS_FREE_MEM`, `X=SegHi`, `Y=Bank`, `jsr OS_API`. Failure: C=1.
   - `VMM_ERR_NOMEM = $01`, `VMM_ERR_INVALID = $02` (`include/ca65/vmm.inc`),
     already visible to `debug.s` via `command64.inc`'s `.include "vmm.inc"`.
7. `DOS_ALLOC_MEM` takes a **paragraph** count (16 bytes/paragraph) directly
   in `X/Y`; unlike CASM's `vmmStoreAlloc`, WP3 does not need a byte-to-
   paragraph rounding step because `XA`'s public grammar is already
   paragraphs (parent plan 5.2).
8. No `VmmSegLo/VmmOffLo/Hi`-style OS parameter staging is needed for WP3:
   those cells matter only for `DOS_VMM_READ`/`DOS_VMM_WRITE` (WP5/WP6).
9. `cmdQuit` (`debug.s:292`) is currently `jmp API_EXIT` with no cleanup.
10. Only `printHex8` exists for numeric output (prints `A` as two hex
    digits via `KernalChROUT`); there is no `printHex16` helper. 16-bit
    values print as two `printHex8` calls (Hi byte, then Lo byte).
11. DEBUG's private zero page `$70-$7F` remains fully occupied; WP3 adds no
    zero-page state.

## 3. Scope

### 3.1 Included

- Implement `cmdReuAlloc` (`XA paragraphs`): parse, validate range, find a
  free slot, call `DOS_ALLOC_MEM`, register on success, roll back an
  unregistrable grant, print the WP2-documented allocation summary.
- Implement `cmdReuFree` (`XD handle`): parse an active handle, call
  `DOS_FREE_MEM`, clear the record only after success, preserve it on
  failure.
- Implement `freeAllReu`: attempt release of every active slot; report
  aggregate success/failure without partial silent state.
- Route `Q` through `freeAllReu`; exit only when cleanup fully succeeds.
- Distinguish VMM-unavailable, out-of-memory, registry-full, invalid-handle,
  inactive-handle, and cleanup-failure paths using the WP2 selectors.
- Build and inspect DEBUG size/relocation growth.
- Verify allocation, free, and `Q`-cleanup behavior under VICE with REU
  enabled and disabled.

### 3.2 Excluded

- `XM` transfer implementation (WP5/WP6).
- `XS` status reporting (WP4).
- `page:offset` parsing (WP5).
- New private zero-page state.
- New user-facing diagnostic text beyond the existing generic error message.
- DEBUG version/changelog bump for the combined REU+syntax feature (deferred
  to WP7 per the parent plan).

## 4. `XA` Contract (`cmdReuAlloc`)

Grammar: `XA paragraphs` (one hex operand, 1-4 digits).

Algorithm:

1. `Y` arrives past `XA` and any leading spaces (per `cmdExtended`).
2. If `inputBuf,y` is null, report `REU_ERR_MISSING_ARG` via `reuError`.
3. `jsr parseHexArg`. On C=1, report `REU_ERR_VALUE_RANGE` (covers both
   non-hex input and a 5th digit; WP2's error taxonomy does not split parse
   syntax from magnitude for numeric operands, matching `parseReuHandle`'s
   existing precedent).
4. `jsr requireEnd`. On C=1, report `REU_ERR_TRAILING_INPUT`.
5. Validate paragraph range `$0001-$1000` against `HexValHi:HexValLo`:
   - Reject `HexValHi==0 && HexValLo==0` (zero) as `REU_ERR_VALUE_RANGE`.
   - Reject `HexValHi > $10` as `REU_ERR_VALUE_RANGE`.
   - Reject `HexValHi == $10 && HexValLo != 0` as `REU_ERR_VALUE_RANGE`.
   - Otherwise in range.
6. Stash the validated paragraph count (e.g. `DebugTemp`/a new BSS pair;
   see Section 6) before calling `findFreeReuHandle`, since it clobbers `A/X`.
7. `jsr findFreeReuHandle`. On C=1 (`REU_ERR_REGISTRY_FULL`), report via
   `reuError` without calling the OS.
8. Stage `A=DOS_ALLOC_MEM`, `X/Y` from the stashed paragraph count, `jsr
   OS_API`.
9. On C=1: `cmp #VMM_ERR_INVALID` — if equal, report
   `REU_ERR_VMM_UNAVAILABLE`; otherwise report `REU_ERR_VMM_NOMEM`. Do not
   touch the registry (the slot was never marked active).
10. On C=0: `X=SegHi`, `Y=Bank`. Immediately stash both (`A/X/Y` are about
    to be reused for registry writes and the free-slot index must be
    preserved across them — see Section 6 for exact scratch cells).
11. Write `reuSegHi,slot`, `reuBank,slot`, `reuParagraphLo,slot`,
    `reuParagraphHi,slot`, then `reuActive,slot = 1` last, so a failure
    between field writes can never be observed as a fully active record.
    (WP3 has no failure path between these writes; the ordering is a
    forward-looking invariant, not a rollback mechanism.)
12. Print the allocation summary (Section 4.1) and return with C=0.

There is no "unregistrable successful grant" case in WP3: `findFreeReuHandle`
runs *before* the OS call (step 7), so by the time `DOS_ALLOC_MEM` succeeds a
free slot is already known and reserved by construction. This differs from
`vmmStoreAlloc`'s allocate-then-register order (which needs a rollback path
because CASM's registry insertion can independently fail) and is a
deliberate simplification: DEBUG's registry has no capacity-only failure
mode once a free slot was already confirmed. Document this explicitly so a
later reviewer does not expect dead rollback code that the parent plan's
Section 5.2 anticipated for a different registration order.

### 4.1 `XA` Output Format

Match the parent plan's example (Section 2.2):

```text
-XA 0100
0: SEG=20 BANK=00 PARA=0100 PAGES=01 SIZE=1000
```

Fields, in order: handle (`printHex8` of the zero-extended slot index,
single digit is fine — DEBUG only ever shows `0-3`, so print as `printHex8`
on the 8-bit slot value for consistent two-digit width), literal `: SEG=`,
`printHex8 SegHi`, literal ` BANK=`, `printHex8 Bank`, literal ` PARA=`,
`printHex8 HexValHi` then `printHex8 HexValLo` (4 hex digits), literal
` PAGES=`, computed page count (Section 4.2), literal ` SIZE=`, computed
byte capacity as either a 4-digit hex value or `10000` for the full 64KB
case (Section 4.2 notes the 17-bit edge case). Terminate with CR.

### 4.2 Derived Page Count and Byte Capacity (Display Only)

Per WP2's decision (parent plan Section 7.2), the registry stores only the
exact paragraph count; page count and byte capacity are derived for display:

- `pageCount = ceil(paragraphs / 256)`, i.e. the high byte of
  `(paragraphs + 255)`, mirroring `vmmStoreAlloc`'s identical derivation
  (`vmm_store.s:106-111`). For `paragraphs` in `$0001-$1000`, this yields
  `$01-$10`.
- `byteCapacity = paragraphs * 16`. For `paragraphs <= $0FFF` this fits in
  16 bits (max `$FFF0`). For `paragraphs == $1000` the true value is
  `$10000` (17 bits) — print the literal string `10000` for that one case
  rather than computing a wrapped 16-bit value. Detect it directly: it is
  exactly the case where the validated paragraph count equals `$1000`,
  already known from step 5's range check, so no extra arithmetic is
  needed — branch on that condition before the generic 16-bit shift-left-4
  multiply.

## 5. `XD` Contract (`cmdReuFree`)

Grammar: `XD handle`.

Algorithm:

1. `jsr parseReuHandle` with `A<>0` (active required) on entry, per its
   existing contract. On C=1, `reuError` with the selector `parseReuHandle`
   returned (`REU_ERR_MISSING_ARG`, `REU_ERR_VALUE_RANGE`, or
   `REU_ERR_INACTIVE_HANDLE`).
2. `jsr requireEnd`. On C=1, report `REU_ERR_TRAILING_INPUT`. Do not free
   anything if trailing input is present — the handle is valid and active,
   but the command as a whole is malformed.
3. Preserve the handle (`X`) across `requireEnd` (it does not clobber `X`
   per its documented contract) and across `getReuRecord`.
4. `jsr getReuRecord` with the parsed handle in `X`. This re-validates range
   and active state (already known good from step 1) and returns
   `X=SegHi`, `Y=Bank`. Re-checking is cheap and keeps `XD`'s free path
   independent of `parseReuHandle`'s internal state, matching the parent
   plan's "reject before any OS call" rule per handle-touching command
   rather than only once per command family.
5. Stage `A=DOS_FREE_MEM`, `X=SegHi`, `Y=Bank` (from step 4's output; stash
   the handle itself first since `X` is about to be overwritten — see
   Section 6), `jsr OS_API`.
6. On C=1: report `REU_ERR_CLEANUP` is *not* used here (that selector is
   reserved for `Q`'s aggregate failure per Section 7). Report a rejected
   single-handle free using the existing generic error path; the record
   stays active so the user can retry. Reuse `REU_ERR_VMM_NOMEM` is wrong
   (that means allocation failure); introduce no new selector — print the
   existing `reuError` path with the selector already defined for this
   purpose in the WP2 taxonomy: none of the fifteen selectors is named for
   "free rejected." Resolve this before coding (see Section 4 of the
   Approval Questions below); the working assumption is to reuse
   `REU_ERR_CLEANUP` for both the single-`XD` rejection and `Q`'s aggregate
   failure, since both mean "an OS free call was rejected," and the parent
   plan's selector list does not budget a16th, single-handle-only code.
7. On C=0: clear `reuActive,x` (and, for deterministic inspection parity
   with `initReuRegistry`, also clear `reuSegHi/reuBank/reuParagraphLo/
   reuParagraphHi,x`). Return C=0. `XD` currently has no success output in
   the parent plan's examples beyond returning to the prompt; do not print
   a message on success unless the user requests one (Approval Questions).

## 6. New BSS/Scratch State

No new zero-page bytes. Add ordinary linked BSS scratch, declared with the
existing registry arrays near `debug.s:3747`:

```text
reuXferParaLo:  .res 1   ; XA: validated paragraph count, staged across
reuXferParaHi:  .res 1   ;     findFreeReuHandle and the DOS_ALLOC_MEM call
reuXferSlot:    .res 1   ; XA: free slot returned by findFreeReuHandle,
                         ;     staged across the DOS_ALLOC_MEM call
```

Rationale: `findFreeReuHandle` and `OS_API` both clobber `A/X/Y`, and the
validated paragraph count must survive from step 5 to step 8 (`cmdReuAlloc`,
Section 4) while the slot index must survive from step 7 to step 11. Three
bytes is simpler and more auditable under VICE than reusing `DebugTemp`
(single byte, already used by other command paths) or the hardware stack
across an `OS_API` call. `cmdReuFree` needs no persistent scratch: it stages
`SegHi/Bank` directly from `getReuRecord`'s `X/Y` output into the `A/X/Y`
call inputs on the same instruction sequence, and only needs to remember the
handle (`X`) across that one restage, which fits in a single `pha`/`pla` or
a reused single-byte scratch cell.

Total growth: 3 bytes, versus WP2's 20-byte registry. No `$70-$7F`
ownership change.

## 7. `Q` Cleanup (`freeAllReu`)

### 7.1 `freeAllReu`

Contract:

- Input: none.
- Attempts `DOS_FREE_MEM` for every slot where `reuActive,x <> 0`.
- Clears a slot's full record only after its individual free succeeds.
- Leaves a slot untouched (still active) if its free is rejected.
- Output: C=0 if every active slot ended inactive; C=1 with
  `A=REU_ERR_CLEANUP` if at least one slot remains active after the pass.
- Clobbers: `A`, `X`, `Y`, flags.

Algorithm:

1. `ldx #0`; loop over `REU_HANDLE_COUNT` slots.
2. For each slot, skip if `reuActive,x == 0`.
3. Otherwise stage `A=DOS_FREE_MEM`, `X=reuSegHi,x`, `Y=reuBank,x` (read
   both into scratch before loading `A`, since `X` is both the loop index
   and the call's `SegHi` input — stash the loop index first).
4. `jsr OS_API`. On C=0, clear the slot's five fields; on C=1, leave the
   slot active and set a "one or more failures" flag in scratch.
5. Restore the loop index, advance, repeat for all four slots.
6. After the loop, return C=1 with `A=REU_ERR_CLEANUP` if the failure flag
   is set; otherwise C=0.

This single-pass, no-early-exit design matches the parent plan's Section
7.5 requirement ("`freeAllReu` attempts to release every active record")
and Section 5.4's "preserve the active record after failure so cleanup can
be retried" — a later `Q` retry will only attempt the slots still active.

### 7.2 `cmdQuit` Routing

Replace:

```asm
cmdQuit:
    jmp API_EXIT
```

with:

```asm
cmdQuit:
    jsr freeAllReu
    bcs cqCleanupFailed
    jmp API_EXIT
cqCleanupFailed:
    jmp reuError            ; A already holds REU_ERR_CLEANUP; returns to mainLoop's rts chain
```

`reuError` prints the existing generic message and returns with C=1; `Q`'s
caller (`dispatch`) already `rts`s back into `mainLoop` for every command,
so no additional control-flow change is needed to "remain in DEBUG" per the
parent plan's Design Decision 6 — falling through to the normal command
return *is* remaining in DEBUG.

## 8. Error Selector Usage Summary (WP3)

| Selector | WP3 trigger |
|---|---|
| `REU_ERR_MISSING_ARG` | `XA`/`XD` with no operand |
| `REU_ERR_VALUE_RANGE` | `XA` non-hex/out-of-range/5-digit paragraphs; `XD` malformed/out-of-range handle (via `parseReuHandle`) |
| `REU_ERR_TRAILING_INPUT` | extra tokens after `XA`'s paragraph count or `XD`'s handle |
| `REU_ERR_INACTIVE_HANDLE` | `XD` on a currently-inactive handle |
| `REU_ERR_REGISTRY_FULL` | `XA` when all four slots are active |
| `REU_ERR_VMM_UNAVAILABLE` | `DOS_ALLOC_MEM` returns `VMM_ERR_INVALID` |
| `REU_ERR_VMM_NOMEM` | `DOS_ALLOC_MEM` returns any other failure code |
| `REU_ERR_CLEANUP` | `DOS_FREE_MEM` rejected in `XD` or in `freeAllReu`/`Q` |

`REU_ERR_INVALID_HANDLE` is reachable through `parseReuHandle`'s existing
range check only in the sense that an out-of-range handle is classified as
`REU_ERR_VALUE_RANGE` (see `parseReuHandle`'s own contract at `debug.s:410`
— it does not return `REU_ERR_INVALID_HANDLE` itself); `XD` therefore never
surfaces `REU_ERR_INVALID_HANDLE` directly in WP3. This mirrors the existing
WP2 helper contract rather than introducing new classification.

## 9. Atomic Implementation Increments

### Increment 1: `XA` Allocation

1. Add `reuXferParaLo/Hi`/`reuXferSlot` BSS scratch.
2. Implement paragraph parsing, `requireEnd`, and range validation.
3. Implement free-slot lookup, `DOS_ALLOC_MEM` call, and failure
   classification (unavailable vs. out-of-memory).
4. Implement registry write-back and the WP2-documented output line.
5. Build DEBUG.
6. Verify `XA 0001`, `XA 0100`, `XA 1000`, `XA 0000` (rejected), `XA 1001`
   (rejected), and registry-full (`XA` after four successful allocations)
   under VICE with REU enabled.

Exit criterion: valid `XA` calls allocate, register, and print the correct
summary; invalid/boundary calls report the correct selector and touch no
registry state.

### Increment 2: `XD` Release

1. Implement handle parsing (reusing `parseReuHandle`), `requireEnd`, and
   `getReuRecord`-based `DOS_FREE_MEM` staging.
2. Implement clear-only-on-success registry update.
3. Build DEBUG.
4. Verify `XD` on a valid handle, a repeated `XD` (already inactive), and
   an out-of-range handle.

Exit criterion: successful `XD` clears exactly one record; rejected or
invalid `XD` leaves the registry unchanged.

### Increment 3: `freeAllReu` and `Q` Routing

1. Implement `freeAllReu`'s no-early-exit sweep.
2. Route `cmdQuit` through it.
3. Build DEBUG.
4. Verify `Q` with zero, one, and multiple active allocations exits
   cleanly and leaves no active registry record.
5. Verify (via VICE memory inspection, not a live unrecoverable failure
   injection unless the user directs otherwise per the VICE-testing
   feedback on not improvising raw state pokes) that `Q` with all
   allocations already freed behaves identically to WP2's unconditional
   exit.

Exit criterion: `Q` never leaks a DEBUG-owned allocation on a clean REU
path, and always returns to the Command64 shell when cleanup fully
succeeds.

### Increment 4: WP3 Regression and Completion Gate

1. Build `debug`, `image_d64`, and `test_image_d64`.
2. Re-run WP1 `G`/`T`/`P` and WP2 dispatch/malformed-token smoke cases.
3. Run the full allocation matrix from the parent plan's Section 10.3.
4. Run the negative-environment matrix (REU disabled) from Section 10.6,
   items 1-4 and 6 (item 5's "ordinary DEBUG commands" check is WP1/WP2
   territory, re-run here only as smoke).
5. Inspect registry storage, DEBUG envelope, and relocation output.
6. Update task, changelog, memory, and DOX records.
7. Produce the manual walkthrough and obtain user confirmation.

Exit criterion: allocation and free lifecycle behavior, including `Q`
cleanup, passes with no regression to WP1/WP2 behavior.

## 10. Build and Static Verification

Use CMake only; do not invoke ca65/ld65 directly.

1. Build `debug` after each increment.
2. Build `image_d64` before VICE work.
3. Build `test_image_d64` at the completion gate.
4. Require no warnings or errors attributable to WP3.
5. Record DEBUG code bytes and relocation count against WP2's baseline
   (build 1114 numbers recorded in WP2's plan Section 2, item 8 — confirm
   the actual WP2-merged baseline from the current `BUILD_DEBUG` before
   comparing).
6. Confirm the binary remains within the existing 8KB `MAIN` envelope.
7. Confirm BSS growth is exactly 3 bytes beyond WP2's registry.
8. Confirm no new `$70-$7F` symbol or ownership.
9. Confirm `DOS_VMM_READ`, `DOS_VMM_WRITE`, and `DOS_GET_SYSTEM_INFO` remain
   uncalled from any WP3 code path (only `DOS_ALLOC_MEM`/`DOS_FREE_MEM` are
   introduced).
10. Let CMake update `BUILD_DEBUG`; never edit generated includes.

## 11. VICE Verification Matrix

Follow `.agents/workflows/vice-mcp-testing.md`: boot Command64 from the
selected image, prove the banner, launch DEBUG by name, prove shell return.
Test REU-enabled and REU-disabled as separate environments per the parent
plan's Section 10.8.

### Allocation Cases (REU Enabled)

```text
XS                  ; (still a WP2 stub; only used here to sanity-check no crash)
XA 0001             ; expect handle 0, PARA=0001, PAGES=01
XA 0100             ; expect handle 1, PARA=0100, PAGES=01
XA 1000             ; expect handle 2, PARA=1000, PAGES=10, SIZE=10000
XA 0000             ; expect error, no registry change
XA 1001             ; expect error, no registry change
XA 0001             ; expect handle 3 (fourth slot)
XA 0001             ; expect REU_ERR_REGISTRY_FULL, no OS call side effect visible
XD 0                ; expect success, slot 0 cleared
XD 0                ; expect REU_ERR_INACTIVE_HANDLE
XD 9                ; expect REU_ERR_VALUE_RANGE (out of $0-$3)
XA 0001             ; expect handle 0 reused (lowest free slot)
Q                   ; expect clean exit; restart DEBUG; confirm all 4 slots zero
```

### Negative Environment (REU Disabled)

```text
XS                  ; WP2 stub output only
XA 0001             ; expect REU_ERR_VMM_UNAVAILABLE
XD 0                ; expect REU_ERR_INACTIVE_HANDLE (rejected before any OS call)
G =6000 / T =6100 / P =6100   ; confirm unaffected
Q                   ; expect clean exit with no active allocations to clean up
```

### Existing Command Smoke

- `G =6000`, `T =6100`, `P =6100` behave as in WP1/WP2.
- `Q` with no allocations exits identically to pre-WP3 behavior.

## 12. Documentation and Tracking

After plan approval and before source implementation:

1. Create a measurable `wiki/tasks/debug-reu-address-syntax-wp3.md` task.
2. Create and activate the matching Taskwarrior task (or, per the
   Taskwarrior-MCP-fallback precedent, use the `task` CLI directly if the
   MCP remains unavailable, and still record progress in this plan doc).
3. Synchronize `brain/task.md`.

During implementation:

- Record build and verification evidence after each increment.
- Add `CHANGELOG.md` behavior only when `XA`/`XD`/`Q` cleanup lands and is
  verified (defer the public DEBUG-version bump to WP7 per the parent
  plan).
- Update `brain/MEMORY.md` when the 3-byte transfer scratch is added.
- Defer public DEBUG user-guide command syntax for `XA`/`XD` to WP7's
  documentation pass, consistent with WP2's precedent of not publishing
  partial command families early — though note `XA`/`XD` are now
  functionally complete at the end of WP3, so this defer is purely about
  batching the doc pass with `XM`/`XS`, not about hiding working commands.
- Perform the mandatory DOX closeout. Applicable source contracts are root
  `AGENTS.md`, `src/AGENTS.md`, and `src/external/AGENTS.md`; task changes
  also require `wiki/AGENTS.md` and `wiki/tasks/AGENTS.md`.

## 13. Risks and Controls

- **Register clobber across `OS_API`:** `A/X/Y` are all volatile across the
  call. Control: every value needed after `jsr OS_API` (paragraph count,
  free slot, loop index, handle) is staged in the 3-byte BSS scratch or the
  registry itself before the call, never left in a register.
- **Partial registration on success:** writing `reuActive` before the other
  four fields would let a concurrent read (there is none — DEBUG is
  single-threaded — but a later WP4 `XS` call reading mid-write is not
  possible either, since DEBUG has no interrupts active during command
  execution) observe an incomplete record. Control: write `reuActive` last
  regardless (Section 4, step 11), as a documented invariant even though no
  WP3 code path can currently violate it.
- **`XD`/`Q` selector collision:** reusing `REU_ERR_CLEANUP` for both a
  single rejected `XD` and an aggregate `Q` failure could make VICE
  evidence ambiguous. Control: the completion-gate VICE matrix (Section 11)
  exercises both paths separately and records which command produced the
  error; flag this as an Approval Question (Section 14) since the parent
  plan does not explicitly settle it.
- **17-bit `SIZE=10000` display:** the one paragraph value (`$1000`) whose
  byte capacity does not fit 16 bits could be miscomputed as `$0000` by a
  naive multiply. Control: branch on the already-known-exact `paragraphs ==
  $1000` condition from range validation (Section 4.2) rather than
  detecting overflow after the fact.
- **Envelope pressure:** `XA`/`XD` logic, `freeAllReu`, and 3 bytes of BSS
  add to DEBUG's existing WP1+WP2 growth. Control: measure against the 8KB
  `MAIN` envelope at every increment (Section 10).

## 14. Approval Questions

Resolve before implementation:

1. Does a rejected single-handle `XD` reuse `REU_ERR_CLEANUP`, or should a
   new selector be added? (Working assumption: reuse `REU_ERR_CLEANUP`;
   Section 5, step 6.)
2. Does successful `XD` print any confirmation output, or return silently
   to the prompt like most other DEBUG commands on success? (Working
   assumption: silent, matching `E`/`F`/`M` precedent.)
3. Is the `XA` output field order and literal formatting in Section 4.1
   (`SEG=`/`BANK=`/`PARA=`/`PAGES=`/`SIZE=`) approved as written, matching
   the parent plan's Section 2.2 example exactly?
4. Should `freeAllReu`'s slot-clear-on-partial-failure behavior be
   observable through any command in WP3 (there is no `XS` yet), or is
   VICE memory inspection sufficient verification until WP4 lands? (Working
   assumption: VICE memory inspection is sufficient for WP3's own gate;
   `XS`-based verification is added retroactively when WP4 lands.)

## 15. Completion Gate

WP3 may be presented for user confirmation when:

1. `XA` allocates within `$0001-$1000` paragraphs, registers on success,
   and prints the documented summary.
2. `XA` rejects zero, out-of-range, non-hex, and trailing-input operands
   without registry or OS side effects.
3. `XA` reports `REU_ERR_VMM_UNAVAILABLE` and `REU_ERR_VMM_NOMEM`
   distinctly and reports `REU_ERR_REGISTRY_FULL` before any OS call.
4. `XD` releases a valid active handle and clears its record only after
   `DOS_FREE_MEM` succeeds.
5. `XD` rejects inactive, out-of-range, and trailing-input operands without
   an OS call, and leaves a record active if the OS call is rejected.
6. `freeAllReu` releases every active slot it can and leaves only rejected
   slots active, with no early exit.
7. `Q` exits only when cleanup fully succeeds, and otherwise reports
   `REU_ERR_CLEANUP` and returns to the DEBUG prompt with allocations
   intact.
8. No `DOS_VMM_READ`, `DOS_VMM_WRITE`, or `DOS_GET_SYSTEM_INFO` call is
   reachable from any WP3 code path.
9. No new private zero-page state exists; BSS growth is exactly 3 bytes.
10. DEBUG remains relocatable and inside its linker envelope.
11. WP1 and WP2 smoke tests still pass.
12. Task, changelog, memory, and DOX records are synchronized.
13. A manual walkthrough is available, covering REU-enabled and
    REU-disabled environments.

Do not mark WP3 complete until the user confirms the walkthrough.
