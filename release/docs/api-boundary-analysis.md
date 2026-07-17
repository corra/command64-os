# API Boundary Analysis: Private vs. Exposed APIs

This document reviews the boundary between **Exposed (Public) APIs** (accessible via `JSR $1000` Service Bus) and **Private (Internal) APIs** in `command64-os`, evaluating which routines should remain encapsulated and justifying the design choices.

---

## 1. Summary of API Classifications

### Public (Service Bus) APIs
*   **Access Pattern**: `JSR $1000` with function code in Accumulator `A`, parameters in registers `X`, `Y`, or shared Zero-Page variables.
*   **Stability**: Address `$1000` is fixed; the kernel dispatcher handles internal pointer routing, allowing the kernel code to move during compilation without breaking application binaries.
*   **Current Exposed Routines**:
    *   `DOS_PRINT_CHAR` (`$02`), `DOS_PRINT_STR` (`$09`)
    *   `DOS_OPEN_FILE` (`$3D`), `DOS_CLOSE_FILE` (`$3E`), `DOS_READ_FILE` (`$3F`), `DOS_WRITE_FILE` (`$40`)
    *   `DOS_DELETE_FILE` (`$41`), `DOS_RENAME_FILE` (`$56`)
    *   `DOS_ALLOC_MEM` (`$48`), `DOS_FREE_MEM` (`$49`)
    *   `DOS_EXIT` (`$4C`)
    *   `DOS_PARSE_PREFIX` (`$57`)

### Private (Internal) APIs
*   **Access Pattern**: Direct `JSR` to internal symbols (e.g. `jsr fileOpen`, `jsr checkDeviceReady`).
*   **Stability**: Address is resolved statically at build time; symbols only compile internally within the OS image.
*   **Key Private Routines**:
    *   `vmmReadByte` / `vmmWriteByte` (Virtual Memory byte-level access)
    *   `checkDeviceReady` (IEC bus listener probe)
    *   `readErrorChannel` / `drainOpenErrorChannel` (Status channel reader)
    *   `aptInit` / `aptRegister` / `aptRemove` / `aptFind` (App Table registry)
    *   `normalizeName` (PETSCII filename case-folding)

---

## 2. Boundary Analysis & Justifications

### A. VMM Byte-Access Primitives (`vmmReadByte` / `vmmWriteByte`)
*   **Current Status**: Private
*   **Review**: Should they be exposed?
*   **Recommendation**: **Keep Private.**
*   **Justification**: 
    1.  **Performance overhead**: Forcing every single-byte read or write from virtual memory through the `$1000` Service Bus dispatcher introduces significant instruction overhead (Accumulator comparison, stack saves/restores, jump indexing).
    2.  **Access Pattern Design**: Applications should not write loops that read or write virtual memory one byte at a time. Instead, applications should allocate a buffer in main RAM, perform work there, and use block DMA copies (planned as block APIs) to transfer pages to/from the REU. Keeping the byte primitives private discourages inefficient access patterns.

### B. Drive Status and Draining (`readErrorChannel` / `drainOpenErrorChannel`)
*   **Current Status**: Private
*   **Review**: Should they be exposed?
*   **Recommendation**: **Keep Private.**
*   **Justification**:
    1.  **State Synchronization**: File operations depend on strict alignment between the logical file handle tables in the kernel and the physical drive channel states. Allowing applications to open and read from the command channel (LFN 15) arbitrarily could conflict with active file stream read/writes or create orphaned channels.
    2.  **Auto-draining**: The kernel's file operations (like `DOS_DELETE_FILE` or a failed `DOS_OPEN_FILE`) automatically invoke these status readers internally to clear the drive's latch. The application only needs to know the success/failure code (`Carry` flag) returned by the API call; it does not need access to the raw status channel.

### C. App Table Registry (`aptRegister` / `aptRemove` / `aptFind`)
*   **Current Status**: Private
*   **Review**: Should they be exposed?
*   **Recommendation**: **Keep Private.**
*   **Justification**:
    1.  **Kernel Privilege Isolation**: The application table is the kernel's process list. The CLI shell acts as the process manager (loading, running, and freeing resources). If applications had write access to these routines, they could maliciously or accidentally overwrite active program spaces, evict the shell, or corrupt the memory boundaries of other active slots.

### D. Device Presence Probe (`checkDeviceReady`)
*   **Current Status**: Private
*   **Review**: Should it be exposed?
*   **Recommendation**: **Keep Private.**
*   **Justification**:
    1.  **DRY (Don't Repeat Yourself)**: Application code should not have to perform pre-flight checks (like probing if device 9 is listening) before executing an file operation. The file APIs (like `DOS_OPEN_FILE`) run `checkDeviceReady` automatically and return a clean error code (`Carry=1`, `A=1` for device not present). Exposing the probe routine separately would only bloat the API footprint.

### E. Filename Normalization (`normalizeName`)
*   **Current Status**: Private
*   **Review**: Should it be exposed?
*   **Recommendation**: **Keep Private.**
*   **Justification**:
    1.  **Library vs. Kernel boundary**: Case conversion and character folding (mapping shifted/lowercase inputs to unshifted PETSCII) is a helper utility. While useful, it is not a system resource manager. Applications can easily implement their own local normalization routines (using less than 20 instructions) if needed, without wasting Service Bus entry points.
