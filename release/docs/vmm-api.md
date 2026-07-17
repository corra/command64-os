# Virtual Memory Manager (VMM) API Specification

## 1. Objective
To provide a memory management abstraction layer that maps the 1MB logical address space expected by DOS into the physical memory structure of the C64 Ultimate (64KB base + 1MB-16MB REU). The VMM handles address translation, memory banking, and allocation tracking, allowing higher-level DOS primitives to operate against a virtualized memory model.

## 2. Calling Conventions (6502)
- **Jump Table Access:** External programs MUST call VMM services via the stable OS entry point at **`$1000`** with the appropriate function number in the Accumulator (`A`).
- **Register Passing:** 
    - `A`: Function Number (e.g., `DOS_ALLOC_MEM = $48`).
    - `X/Y`: Parameter 1 (Low/Hi) or as defined by function.
    - `Carry Flag`: Returns `0` on success, `1` on error.
- **Data Passing:** Uses non-critical FAC1 zero-page workspace:
    - `VmmSegLo/Hi` ($68-$69): Segment.
    - `VmmOffLo/Hi` ($6A-$6B): Offset.
    - `VmmBank` ($6C): 1MB block index (0-15). Combined with the bank nibble derived
      from `VmmSegHi` to form the 64KB-granularity value written to `REU_REU_BANK`.

## 3. API Contracts (via JSR $1000)

### DOS_ALLOC_MEM ($48)
- **Description:** Allocates contiguous 4KB pages in the REU.
- **Input:** `X/Y` = Requested paragraphs (16-byte units).
- **Output:** 
    - `X` = Starting Page Index (`VmmSegHi`).
    - `Y` = Starting Bank (`VmmBank`).
    - `Carry` = 0 (Success).
- **Error:** `Carry` = 1, `A` = `VMM_ERR_NOMEM` ($01) or `VMM_ERR_INVALID` ($02).

### DOS_FREE_MEM ($49)
- **Description:** Releases a previously allocated block.
- **Input:** 
    - `X` = Page Index (`VmmSegHi`).
    - `Y` = Bank (`VmmBank`).
- **Output:** `Carry` = 0 (Success).
- **Error:** `Carry` = 1, `A` = `VMM_ERR_INVALID` ($02).

### VMM_READ_BYTE (Internal/Private)
- **Description:** Reads a single byte from logical DOS Seg:Off.
- **Input:** `VmmSegLo/Hi`, `VmmOffLo/Hi`.
- **Output:** `A` = Data byte.

### VMM_WRITE_BYTE (Internal/Private)
- **Description:** Writes a single byte to logical DOS Seg:Off.
- **Input:** `A` = Data byte, `VmmSegLo/Hi`, `VmmOffLo/Hi`.

### DOS_VMM_READ ($59)
- **Description:** Reads a caller-specified byte range out of a previously
  `DOS_ALLOC_MEM`'d REU segment into C64 RAM, in a single REU DMA burst.
  `DOS_ALLOC_MEM`/`DOS_FREE_MEM` alone give no way to actually move data
  into/out of allocated REU memory — this and `DOS_VMM_WRITE` are the
  primitives that close that gap. Reuses the same
  `VmmSegLo/Hi`/`VmmOffLo/Hi`/`VmmBank` convention `VMM_READ_BYTE` uses, but
  transfers the whole requested range in one DMA call rather than one byte
  at a time.
- **Input:**
    - `VmmSegLo/Hi`, `VmmOffLo/Hi`, `VmmBank` ($68-$6C): Source Seg:Off:Bank.
    - `X/Y` = Destination C64 buffer pointer (Lo/Hi).
    - `HexValLo/Hi` ($66-$67) = Byte count.
- **Output:** Destination buffer filled; `Carry` = 0 (Success).
- **Error:** `Carry` = 1 (REU/VMM not initialized).

### DOS_VMM_WRITE ($5A)
- **Description:** Writes a caller-specified byte range from C64 RAM into a
  previously `DOS_ALLOC_MEM`'d REU segment, in a single REU DMA burst. See
  `DOS_VMM_READ` above for rationale.
- **Input:**
    - `VmmSegLo/Hi`, `VmmOffLo/Hi`, `VmmBank` ($68-$6C): Destination Seg:Off:Bank.
    - `X/Y` = Source C64 buffer pointer (Lo/Hi).
    - `HexValLo/Hi` ($66-$67) = Byte count.
- **Output:** `Carry` = 0 (Success).
- **Error:** `Carry` = 1 (REU/VMM not initialized).

## 4. Implementation Details
- **MCT (Memory Control Table):** Located at **`$C000-$CFFF`**. A 4096-byte map tracking the state of 4KB pages across 16MB of REU space.
- **Page States:** 
    - `$00`: Free
    - `$01`: Head (Start of allocation)
    - `$02`: Tail (Continuation of allocation)

## 5. System Allocation: Master Environment Block
The OS shell reserves a 4KB (1 page) block in the REU during initialization for environment variable storage. 

- **Access:** Internal commands `SET` and `PATH` manage this block.
- **Format:** Double-null terminated ASCII/PETSCII strings (`VAR=VAL\0VAR=VAL\0\0`).
- **Relocatability:** The logical segment of this block is stored in the OS workspace at
  `EnvSegmentLo/Hi` ($039F-$03A0), with its `VmmBank` value preserved at `EnvBank` ($03A1)
  and restored into `VmmBank` before every VMM read/write against the environment block.

## 6. Memory Safety
The VMM includes a `vmmInitialized` safety check. All entry points will fail gracefully with `VMM_ERR_INVALID` if an REU was not detected at startup.
