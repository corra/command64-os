# Virtual Memory Manager (VMM) API Specification

## 1. Objective
To provide a memory management abstraction layer that maps the 1MB logical address space expected by DOS into the physical memory structure of the C64 Ultimate (64KB base + 1MB-16MB REU). The VMM handles address translation, memory banking, and allocation tracking, allowing higher-level DOS primitives to operate against a virtualized memory model.

## 2. Calling Conventions (6502)
- **Address Passing:** Logical DOS addresses (Segment:Offset) are passed by setting zero-page pointers `VMM_SEG` and `VMM_OFF`.
- **Return Values:** Return codes are passed in the Accumulator (A). `$00` = Success, `$01` = Out of memory, `$02` = Invalid segment.
- **Bank Selection:** REU bank selection uses a dedicated zero-page variable `REU_BANK` ($0202).

## 3. API Contracts

### VMM_INIT (Initialize the Virtual Memory Manager)
- **Description:** Maps the base C64 memory and initializes the REU banking structure. Must be called before any other VMM function.
- **Input:** `A` = Total memory pages to allocate in the REU (e.g., 256 for 1MB).
- **Implementation:** Performs the initial REU handshake (writing to `$D405` and `$D406`), verifies the REU is online, and creates the Memory Control Table (MCT) in zero-page.

### VMM_READ_BYTE (Read from Virtual Address)
- **Description:** Reads a single byte from a 16-bit logical DOS address.
- **Input:** `VMM_SEG` = Logical Segment, `VMM_OFF` = Logical Offset.
- **Output:** `A` = Byte read from the logical address.
- **Implementation:** Computes the 20-bit physical address, selects the correct REU bank via `$D405`, and reads the byte from the C64 I/O port.

### VMM_WRITE_BYTE (Write to Virtual Address)
- **Description:** Writes a single byte to a 16-bit logical DOS address.
- **Input:** `A` = Byte to write, `VMM_SEG` = Logical Segment, `VMM_OFF` = Logical Offset.
- **Implementation:** Computes the physical address, selects the REU bank, and writes via the C64 I/O registers.

### VMM_ALLOC (Allocate Memory Block)
- **Description:** Finds a contiguous block of free memory in the virtual space and reserves it.
- **Input:** `VMM_SEG` = Requested paragraph size (16 bytes).
- **Output:** `A` = Result code. On success, `VMM_SEG` and `VMM_OFF` are set to the allocated block's start address.

### VMM_FREE (Release Memory Block)
- **Description:** Returns a previously allocated block to the free pool.
- **Input:** `VMM_SEG` = Logical Segment of the block to free.

## 4. Data Structures
- **Memory Control Table (MCT):** A table mapping logical segment pointers to physical REU bank numbers and base offsets.
- **Free Block Head:** A zero-page linked list node tracking available memory blocks.

## 5. Justification
DOS assumes a flat, segment-able 1MB RAM space. The C64 Ultimate requires manual bank switching for any memory beyond the base 64KB. By implementing the VMM here, we can emulate DOS-style memory allocation (`$ALLOC`, `$DEALLOC`) without exposing the banking complexity to the command shell and file system modules.
