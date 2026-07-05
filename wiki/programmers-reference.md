# command64 Programmer's Reference

This document provides technical details for developing applications for the command64 operating system.

## 1. Memory Map

When Command 64 OS starts, the shell banks out the **C64 BASIC ROM** at `$A000-$BFFF` by writing to the 6510 CPU Port register at `$0001` (clearing bit 0, `LORAM`). This exposes the underlying RAM, providing a contiguous user program space from `$2600` up to `$CFFF` (since `$C000-$CFFF` is reserved for the VMM Memory Control Table). The **KERNAL ROM** (`$E000-$FFFF`) and **I/O space** (`$D000-$DFFF`) remain active to support system calls, hardware devices, and REU operations.

### C64 RAM Banking Control ($0001 CPU Port)

* **Bit 0 (`LORAM`) = 0**: Banks out BASIC ROM, exposing RAM at `$A000-$BFFF`.
* **Bit 1 (`HIRAM`) = 1**: Keeps KERNAL ROM active at `$E000-$FFFF`.
* **Bit 2 (`CHAREN`) = 1**: Keeps I/O registers mapped at `$D000-$DFFF`.

### Base RAM Layout

```text
  Address |    Region Size / Description                          | Access / State          |
+---------+-------------------------------------------------------+------------------------ +
|  $FFFF  |  Interrupt Vectors ($FFFA-$FFFF)                      |  KERNAL ROM (Active)    |
|         |  KERNAL ROM Jump Table ($FF00-$FFF9)                  |                         |
|  $E000  |  C64 KERNAL ROM Code Space                            |                         |
+---------+-------------------------------------------------------+------------------------ +
|  $DFFF  |  REU Hardware Registers ($DF00-$DF0A)                 |  Hardware Registers     |
|  $D000  |  I/O Registers (VIC-II, SID, CIA-1, CIA-2)            |  (CHAREN = 1)           |
+---------+-------------------------------------------------------+------------------------ +
|  $CFFF  |  VMM Memory Control Table (MCT)                       |  OS Reserved RAM        |
|  $C000  |  Tracks 4096 pages (4KB each) over 16MB REU space     |  (4KB Base RAM)         |
+---------+-------------------------------------------------------+------------------------ +
|  $BFFF  |                                                       |                         |
|         |  User Program Space (RAM)                             |  User Application Area  |
|         |  (Note: BASIC ROM banked out at $A000-$BFFF to        |  (RAM replacing ROM)    |
|         |   provide contiguous program RAM)                     |                         |
|  $2600  |                                                       |                         |
+---------+-------------------------------------------------------+------------------------ +
|  $25FF  |  Unallocated Padding / Alignment Room                 |  Free RAM (approx. 274B)|
|  $24EE  |                                                       |                         |
+---------+-------------------------------------------------------+------------------------ +
|  $24ED  |  ShellExt Segment                                     |  OS Shell Data          |
|  $235D  |  Contains help strings, version info, utility text    |  (RAM)                  | 
+---------+-------------------------------------------------------+------------------------ +
|  $235C  |  AppTable Segment                                     |  OS Resident Registry   |
|  $2000  |  Application Registry Management API                  |  (RAM)                  |
+---------+-------------------------------------------------------+------------------------ +        
|  $1FFF  |  VMM Data Segment                                     |  OS VMM Data            |
|         |  vmmInitialized ($1FA0), vmmTempByte ($1FA1)          |  (RAM)                  |
|  $1FA0  |  fileScratch ($1FA2-$1FFC)                            |                         |
+---------+-------------------------------------------------------+------------------------ +
|  $1F9F  |  Command Shell                                        |  OS Shell Code          |
|  $1180  |  Command parser, command tables, built-in handlers    |  (RAM)                  |
+---------+-------------------------------------------------------+------------------------ +
|  $117F  |  Command Table / System Tables                        |  OS Data                |
|  $1080  |  Command name listings and dispatcher mapping         |  (RAM)                  |
+---------+-------------------------------------------------------+------------------------ +
|  $107F  |  PETSCII Library                                      |  OS Library             |
|  $1040  |  Print character / print string utilities             |  (RAM)                  |
+---------+-------------------------------------------------------+------------------------ +
|  $103F  |  ApiStub (OS Stable Jump Table Entry Point)           |  OS Entry Point         |
|  $1000  |  Jump to apiHandler (jmp $1200+); JSR $1000 target    |  (RAM)                  |
+---------+-------------------------------------------------------+------------------------ +
|  $0FFF  |  OS Core Code Space                                   |  OS Kernel Code         |
|         |  $0D00-$0FFF: OS Core (Loader, Path, File System)     |  (RAM)                  |
|  $0820  |  $0820-$0CFF: OS Utils (Hex parsing, Decimal printer) |                         |
+---------+-------------------------------------------------------+------------------------ +
|  $081F  |  Main BASIC SYS Launcher                              |  BASIC Stub             |
|  $0801  |  Contains 10 SYS 4608 / sys 4096 (Upstart launcher)   |  (RAM)                  |
+---------+-------------------------------------------------------+------------------------ +
|  $0800  |  Unused / BASIC Start Marker                          |  RAM                    |
+---------+-------------------------------------------------------+------------------------ +
|  $07FF  |  C64 Screen Memory                                    |  Standard Screen RAM    |
|  $0400  |  1000 character matrices (40x25 character display)    |  (RAM)                  |
+---------+-------------------------------------------------------+------------------------ +
|  $03FF  |  C64 KERNAL & OS Workspace / Buffers                  |  System / Tape Buffer   |
|  $0200  |  Includes keyboard buffer and Cassette Buffer ($033C)  |  (RAM)                 |
+---------+-------------------------------------------------------+------------------------ +
|  $01FF  |  C64 System Stack                                     |  Standard 6502 Stack    |
|  $0100  |  Used for JSR returns and PHA/PHP storage             |  (RAM)                  |
+---------+-------------------------------------------------------+------------------------ +
|  $00FF  |  Zero Page RAM                                        |  Processor Workspace    |
|  $0000  |  OS scratch pointers, VMM registers, KERNAL system ZP |  (RAM)                  |
+---------+-------------------------------------------------------+------------------------ +
```

---

## 2. Zero Page Layout ($0000 - $00FF)

Applications MUST respect the following zero page allocations to prevent corrupting operating system operations or standard KERNAL subsystems.

| Range | Constant / Label | Purpose | State Owner |
|-------|------------------|---------|-------------|
| `$00 - $01` | `D6510` / `R6510` | 6510 CPU Port Direction & Data Register | Hardware |
| `$02` | `CmpBase` | String comparison scratch workspace base offset | OS Core |
| `$03 - $60` | - | **Safe Area for User Applications** | User Apps |
| `$61 - $62` | `HandlerVecLo/Hi` | Dynamic Shell handler vector for API dispatcher | OS Shell |
| `$63` | `ParsePos` | Pointer offset inside the CommandBuffer command parser | OS Shell |
| `$64 - $65` | `TempLo/Hi` | Operating System general utility scratch bytes | OS Core |
| `$66 - $67` | `HexValLo/Hi` | Hex parsing output storage / Address pointer | OS Core |
| `$68 - $69` | `VmmSegLo/Hi` | VMM 16-bit logical Segment address parameter | OS VMM |
| `$6A - $6B` | `VmmOffLo/Hi` | VMM 16-bit logical Offset address parameter | OS VMM |
| `$6C` | `VmmBank` | VMM 1MB block index (0-15) for physical mapping | OS VMM |
| `$6D` | `FileHandle` | Current active file handle for handle-based I/O | OS File System |
| `$6E` | `SrcHandle` | Source file handle scratch for utility routines (`cmdCopy`) | OS Shell |
| `$6F` | `DstHandle` | Destination file handle scratch for utility routines (`cmdCopy`) | OS Shell |
| `$70 - $8F` | - | **Safe for User Application use** (Note: `DEBUG.PRG` uses `$70-$7F`) | User Apps |
| `$90 -`$FA` | - | Standard C64 KERNAL I/O and hardware vectors | KERNAL |
| `$FB - $FC` | `PrintPtrLo/Hi` | String print pointer workspace (`petPrintString`) | OS Core |
| `$FD - $FE` | `NamePtrLo/Hi` | File loader wrapper filename pointer | OS Core |
| `$FF` | - | KERNAL keyboard scan tracker / Stack boundary marker | KERNAL |

---

## 3. Cassette Buffer Workspace Layout ($033C - $03FF)

The 192-byte cassette buffer region (`$033C-$03FB`) is reused as the persistent workspace for OS variables, file handles, and shell configurations. Because tape storage is bypassed by Command 64 OS, this region provides a secure, non-clobbered RAM page.

```text
  Address       Byte-by-Byte Cassette Buffer Allocation Map
+---------+-------------------------------------------------------+
|  $03FF  |  Remaining C64 KERNAL Workspace / System Pointers     |
|  $03FC  |                                                       |
+---------+-------------------------------------------------------+
|  $03FB  |  Reserved / Unallocated Free Space                    |
|  $03FA  |  (2 bytes of headroom)                                |
+---------+-------------------------------------------------------+
|  $03F9  |  AptTempEndLo/Hi                                      |
|  $03F8  |  App Table overlapping check end address (2 bytes)    |
+---------+-------------------------------------------------------+
|  $03F7  |  AptTempSizeLo/Hi                                     |
|  $03F6  |  App Table overlapping check size register (2 bytes)  |
+---------+-------------------------------------------------------+
|  $03F5  |  AptTempLoadLo/Hi                                     |
|  $03F4  |  App Table overlapping check load address (2 bytes)   |
+---------+-------------------------------------------------------+
|  $03F3  |  AptSegLo/Hi                                          |
|  $03F2  |  VMM logical segment pointer to App Table (2 bytes)   |
+---------+-------------------------------------------------------+
|  $03F1  |  DestBuf                                              |
|  $03CA  |  General destination scratch path buffer (40 bytes)   |
+---------+-------------------------------------------------------+
|  $03C9  |  SourceBuf                                            |
|  $03A2  |  General source scratch path buffer (40 bytes)        |
+---------+-------------------------------------------------------+
|  $03A1  |  EnvBank (Environment block REU bank index)           |
+---------+-------------------------------------------------------+
|  $03A0  |  EnvSegmentLo/Hi                                      |
|  $039F  |  VMM logical segment pointer to Environment (2 bytes) |
+---------+-------------------------------------------------------+
|  $039E  |  CurrentDevice (C64 active drive device: 8, 9, 10, 11) |
+---------+-------------------------------------------------------+
|  $039D  |  HandleTable                                          |
|         |  8 slots * 2 bytes = 16 bytes.                        |
|  $038E  |  For each slot: Byte 0 = Status (0=Free, 1=Open)       |
|         |                 Byte 1 = KERNAL LFN (Logical File No.)|
+---------+-------------------------------------------------------+
|  $038D  |  SpecificLoad (0 = Relocate program, 1 = Absolute)    |
+---------+-------------------------------------------------------+
|  $038C  |  CommandLen (Active length of CommandBuffer input)    |
+---------+-------------------------------------------------------+
|  $038B  |  CommandBuffer                                        |
|  $033C  |  Active shell command line text buffer (80 bytes)     |
+---------+-------------------------------------------------------+
```

---

## 4. REU Virtual Memory Space (Up to 16MB)

The Virtual Memory Manager (VMM) virtualizes up to 16MB of Ram Expansion Unit (REU) memory into 4KB pages. Page allocation is tracked using a 4096-byte **Memory Control Table (MCT)** located in base RAM at `$C000-$CFFF`.

### VMM Page Allocation Logic

* **MCT Position `$C000 + i`**: Represents the status of REU Page `i` (representing 4KB).
* **MCT Status Codes**:
  * `$00` (`PAGE_FREE`): Page is unallocated.
  * `$01` (`PAGE_HEAD`): Page is the starting point of an allocation.
  * `$02` (`PAGE_TAIL`): Page is a continuation block of a multi-page allocation.

### System Allocated Pages in REU

Upon boot, the OS initializes two structures in REU space:

1. **Master Environment Block (Page 0)**: Located at VMM segment pointer stored in `EnvSegment` ($039F-$03A0). Allocates a 4KB page. Stores shell environment variables configured by `SET` and `PATH` as double-null terminated strings (`VAR=VAL\0VAR=VAL\0\0`).
2. **Application Table Block (Page 1)**: Located at VMM segment pointer stored in `AptSegment` ($03F2-$03F3). Allocates a 4KB page. Manages a 16-slot registered application index (40 bytes per entry stride, 4-byte header at offset 0).

---

## 5. VMM Address Translation (C64 RAM -> REU Registers)

To read or write bytes located in virtual memory, user applications pass a 16-bit logical Segment (`VmmSegLo/Hi`), 16-bit logical Offset (`VmmOffLo/Hi`), and 1MB Bank index (`VmmBank`). The VMM routine translates this logical format into the C64 REU hardware DMA register layout.

### Translation Formula

A logical segment pointer represents a block of 16-byte paragraphs. The physical address is derived by:

$$\text{Physical Address (24-bit)} = (\text{VmmSeg} \times 16) + \text{VmmOff}$$

$$\text{REU Bank Offset} = \text{VmmBank} \times 16 + \text{Physical Address High Byte (Bits 16-23)}$$

### Register Mapping Diagram

```text
    LOGICAL SPECIFIERS                       REU DMA HARDWARE REGISTERS ($DF00-$DF0A)
    
   +--------------------+
   |   VmmSegLo / Hi    | --[ Shift Left 4 Bits (x16) ]---------+
   +--------------------+                                       |
                                                                v
   +--------------------+                               [ 24-bit Addr Base ]
   |   VmmOffLo / Hi    | ------------------------------------> +  (Addition)
   +--------------------+                                       |
                                                                v
                                                       [ 24-Bit Result ]
                                                        /       |       \
                                                       /        |        \
                                                  Low Byte   Mid Byte   High Byte
                                                    (0-7)     (8-15)     (16-23)
                                                     |          |          |
                                                     v          v          |
                                                +---------+ +---------+    |
                                                | REU_REU | | REU_REU |    |
                                                | _ADDR_L | | _ADDR_H |    |
                                                +---------+ +---------+    |
                                                  ($DF04)     ($DF05)      v
   +--------------------+                                                  |
   |      VmmBank       | --[ Shift Left 4 (x16) ]---------------------> + | (Addition)
   |       (0-15)       |                                                | |
   v--------------------+                                                v v
                                                                    +---------+
                                                                    | REU_REU |
                                                                    |  BANK   |
                                                                    +---------+
                                                                      ($DF06)
```

During execution, standard C64 RAM pointer target addresses are written to `$DF02-$DF03` (`REU_C64_ADDR_L/H`), the byte size (1 byte for single accesses, or larger blocks for dynamic program swaps) is written to `$DF07-$DF08` (`REU_LEN_L/H`), and the DMA execution trigger `REU_COMMAND` ($DF01) is set to execute a `STASH` ($90 - write) or `FETCH` ($91 - read) transfer.

---

## 6. Development Guidelines

### 6.1 OS Integration

Always use the stable entry point at **`$1000`** for OS services. Never jump directly into the OS kernel ($1200+) as these addresses may change between builds.

### 6.2 Compatibility

* **Binary Mode:** Always start your program with `CLD` to ensure binary arithmetic mode.
* **Character Set:** The OS starts in lowercase/mixed mode. Use PETSCII mixed-case encoding for strings.
* **Exit Strategy:** Always terminate your program via `DOS_EXIT ($4C)` to ensure the shell state is correctly reset.

### 6.3 Memory Management

Use the VMM API (`DOS_ALLOC_MEM`, `DOS_FREE_MEM`) to manage memory in the REU. Do not write directly to REU registers unless you are managing your own banked memory and are certain it does not conflict with the OS MCT.

## 7. Build System

The project is built using a cross-platform **CMake** build system (minimum version 3.20) and **Kick Assembler v5.25**.

* **Main Entry Point**: `src/command64.asm`
* **CMake Configuration**: Run `cmake -B build` followed by `cmake --build build` to compile the operating system, utilities, and test suites.
* **GNU Make Wrapper**: A `Makefile` proxy is provided at the repository root for convenience. You can run standard targets like `make all`, `make image`, or `make clean` which are forwarded directly to CMake.
* **Output**: Output binaries (`command64.prg`, `debug.prg`, etc.) are placed under the `build/` directory.

### 7.1 External Application Versioning Workflow

External user-space applications (located in `src/external/`) must follow a strict versioning workflow that increments a build counter at compile time whenever the application source files are modified.

1. **Subdirectory**: Place the application sources in a new folder `src/external/<appname>/` with a main entry assembler file (e.g., `<appname>.asm`).
2. **Persistent Build Counter File**: Create a file named `BUILD_<APPNAME_UPPER>` at the repository root containing the initial build number (usually `1000`).
3. **Assembly Integration**:
   * Define version major, minor, and stage in the main assembly file:

     ```assembly
     .const VERSION_MAJOR = "0"
     .const VERSION_MINOR = "1"
     .const VERSION_STAGE = "0"
     #import "build_<appname>.inc"
     ```

   * Embed the version and build number in the application startup/identification text using `BUILD_NUMBER`:

     ```assembly
     .text "MYAPP v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE + "." + BUILD_NUMBER
     ```

4. **CMake Target**: Update `CMakeLists.txt` to define the target using the `add_external_app` helper function:

   ```cmake
   file(GLOB_RECURSE MYAPP_SRCS "src/external/myapp/*.asm" "include/*.inc")
   set(MYAPP_ENTRY "src/external/myapp/myapp.asm")
   add_external_app(myapp "${MYAPP_ENTRY}" MYAPP_SRCS 1000)
   ```

   This helper automatically configures the target, schedules the build number increment script on modification of source files, and enforces that the `BUILD_MYAPP` file exists at configure time.
