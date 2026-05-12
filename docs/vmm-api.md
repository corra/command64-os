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
    - `VmmSegLo/Hi` ($61-$62): Segment.
    - `VmmOffLo/Hi` ($63-$64): Offset.
    - `VmmBank` ($65): 64KB Bank index.

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

## 4. Implementation Details
- **MCT (Memory Control Table):** Located at **`$C000-$CFFF`**. A 4096-byte map tracking the state of 4KB pages across 16MB of REU space.
- **Page States:** 
    - `$00`: Free
    - `$01`: Head (Start of allocation)
    - `$02`: Tail (Continuation of allocation)

## 5. Memory Safety
The VMM includes a `vmmInitialized` safety check. All entry points will fail gracefully with `VMM_ERR_INVALID` if an REU was not detected at startup.
