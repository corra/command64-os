# Task Spec: VMM Block I/O Kernel Primitives

## Description

Add two new stable API primitives, `DOS_VMM_READ` and `DOS_VMM_WRITE`, that
let user-space applications transfer a caller-specified byte range between
C64 RAM and a previously `DOS_ALLOC_MEM`-allocated REU segment in a single
REU DMA burst.

`DOS_ALLOC_MEM`/`DOS_FREE_MEM` already let an external app claim/release REU
memory, but there is currently no way for an external app to read or write
into that memory — `vmmReadByte`/`vmmWriteByte` (`src/command64/vmm.asm`)
are kernel-internal routines, never wired into `apiHandler`'s dispatch table
(`src/command64/api.asm`), and even if they were, they only move one byte
per REU DMA setup — far too slow for the repeated line-scanning EDLIN needs.

This is a prerequisite for the [[project-edlin-port]] port
(`brain/plans/2026-07-09-edlin-implementation-phases.md`, Phase 1), which
needs a VMM-backed text buffer it can scan in reasonably sized chunks, not
byte-at-a-time.

## Scope

- New function numbers `DOS_VMM_READ = $59`, `DOS_VMM_WRITE = $5A`,
  registered in `include/command64.inc` and `include/ca65/command64.inc`.
- New kernel routines in `src/command64/vmm.asm`: `vmmReadBlock` /
  `vmmWriteBlock`. Both call the existing private `vmmComputeAddress` once
  per call (unchanged), then set `REU_C64_ADDR_L/H` from the caller's
  buffer pointer and `REU_LEN_L/H` from the caller's byte count, and issue
  a single `REU_CMD_FETCH`/`REU_CMD_STASH` — one DMA burst for the whole
  range, not a loop.
- `ahVmmRead`/`ahVmmWrite` dispatch entries in `src/command64/api.asm`,
  added to `apiHandler`'s `cmp`/`beq` chain alongside the existing
  `DOS_ALLOC_MEM`/`DOS_FREE_MEM` entries.
- ABI (mirrors `DOS_READ_FILE`/`DOS_WRITE_FILE`'s existing
  `X/Y`-pointer + `HexValLo/Hi`-count convention, and reuses
  `vmmReadByte`/`vmmWriteByte`'s existing `VmmSegLo/Hi`/`VmmOffLo/Hi`/
  `VmmBank` ZP convention for the REU-side address — no new ZP needed):
  - **`DOS_VMM_READ` input**: `VmmSegLo/Hi`, `VmmOffLo/Hi`, `VmmBank`
    (`$68-$6C`) = source Seg:Off:Bank; `X/Y` = destination C64 buffer
    pointer; `HexValLo/Hi` (`$66/$67`) = byte count. **Output**: buffer
    filled; `Carry` = 0 on success.
  - **`DOS_VMM_WRITE` input**: `VmmSegLo/Hi`, `VmmOffLo/Hi`, `VmmBank` =
    destination Seg:Off:Bank; `X/Y` = source C64 buffer pointer;
    `HexValLo/Hi` = byte count. **Output**: `Carry` = 0 on success.
  - **Error** (both): `Carry` = 1 if VMM/REU is not initialized
    (`vmmInitialized` = 0) — `vmmReadBlock`/`vmmWriteBlock` return a real
    `VMM_ERR_INVALID` status in `A` (unlike `vmmReadByte`/`vmmWriteByte`,
    which silently no-op/return 0 on failure) so callers can implement a
    REU-absent fallback, per the EDLIN feasibility plan's requirement.
- Document both in `wiki/api-reference.md` following the existing
  `DOS_ALLOC_MEM`/`DOS_SEND_COMMAND` entry format.

## Non-Goals

- No bank-crossing edge case handling beyond what the REU hardware already
  does natively — REU DMA auto-increments its internal 24-bit-ish address
  counter across a 64K bank boundary during a single transfer; this isn't
  new logic, just relying on existing hardware behavior plus
  `vmmComputeAddress`'s existing bank math.
- No transfer-length validation against the allocated block's actual size
  — callers (EDLIN's `buffer.s`) are responsible for staying within their
  own allocation, same trust model as `DOS_READ_FILE`/`DOS_WRITE_FILE`.
- Max single-call transfer is 65535 bytes (`HexValLo/Hi` is 16-bit) — no
  chunking/looping inside the primitive itself; callers moving more than
  that issue multiple calls.

## Sub-tasks

- [x] Add `vmmReadBlock`/`vmmWriteBlock` to `src/command64/vmm.asm`.
- [x] Add `DOS_VMM_READ = $59`/`DOS_VMM_WRITE = $5A` to
      `include/command64.inc` and `include/ca65/command64.inc`.
- [x] Add `ahVmmRead`/`ahVmmWrite` dispatch entries in
      `src/command64/api.asm`.
- [x] Document both functions in `wiki/api-reference.md`.
- [x] Verify via VICE: allocate a REU block via `DOS_ALLOC_MEM`, write a
      known byte pattern via `DOS_VMM_WRITE`, read it back via
      `DOS_VMM_READ` into a different C64 RAM location, confirm byte-exact
      round-trip. Extended `tests/src/vmm/vmm.s` (was alloc/free only,
      despite its description) to cover this. User ran it in VICE and
      confirmed "BLOCK READ/WRITE ROUNDTRIP OK!".
- [x] Confirm `cmake --build build --target test_image_d64` builds clean
      with the OS (`command64.prg`) rebuilt.
