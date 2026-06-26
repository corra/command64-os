# MS-DOS v4.0 Feature Completeness Comparison

This is a running document comparing the features of **Command 64 OS** to the reference **MS-DOS v4.0** codebase. It tracks functional completeness, architectural alignments, and implementation gaps.

---

## 1. Feature Mapping Matrix

| Functional Area | MS-DOS v4.0 Source Path | Command 64 OS Implementation | Completeness Status |
| :--- | :--- | :--- | :--- |
| **CLI Shell / Parser** | `CMD/COMMAND/` | [shell.asm](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm), [utils.asm](file:///home/morgan/development/c64/command64-os/src/command64/utils.asm) | **Partial** |
| **Memory Manager** | `DOS/ALLOC.ASM` | [vmm.asm](file:///home/morgan/development/c64/command64-os/src/command64/vmm.asm) | **Complete** (Custom page-map) |
| **File Handle Table** | `DOS/HANDLE.ASM` | [file.asm](file:///home/morgan/development/c64/command64-os/src/command64/file.asm) | **Partial** |
| **Binary Loader** | `DOS/EXEC.ASM` | [loader.asm](file:///home/morgan/development/c64/command64-os/src/command64/loader.asm) | **Partial** |
| **Path Search** | `DOS/PATH.ASM` | [path.asm](file:///home/morgan/development/c64/command64-os/src/command64/path.asm) | **Complete** |
| **Device Drivers (BIOS)** | `BIOS/` & `DOS/DEV.ASM` | C64 KERNAL ROM + [petsci.asm](file:///home/morgan/development/c64/command64-os/src/command64/petsci.asm) | **Complete** (Platform delegation) |
| **System Clock / Time** | `DOS/TIME.ASM` | *(None)* | **Missing** |
| **Batch Processing** | `CMD/COMMAND/TBATCH.ASM` | *(None)* | **Missing** |
| **I/O Redirection & Pipes** | `CMD/COMMAND/TPIPE.ASM` | *(None)* | **Missing** |

---

## 2. Core Shell & CLI Interpreter (`COMMAND.COM`)

### Internal Commands Feature Matrix

This matrix maps each internal CLI command, identifying its MS-DOS implementation file, its Command 64 OS equivalent code/handler, its completeness status, and C64-specific considerations.

| Command | MS-DOS v4.0 Source File | Command 64 Handler | Status | C64 Implementation / Gap Notes |
| :--- | :--- | :--- | :--- | :--- |
| **CLS** | `TCMD2A.ASM` | `cmdCls` | **Complete** | Clears screen and resets cursor via standard KERNAL screen editor call. |
| **DIR** | `TCMD1A.ASM` | `cmdDir` | **Complete** | Streams and lists filenames from C64 disk drive via KERNAL channel. |
| **TYPE** | `TCMD1A.ASM` | `cmdType` | **Complete** | Prints file contents using standard KERNAL streaming. |
| **COPY** | `COPY.ASM` | `cmdCopy` | **Complete** | Copies files via open source/destination handles using 64-byte buffering. |
| **DEL / ERASE** | `TCMD1B.ASM` | `cmdDel` | **Complete** | Scratches disk files using the floppy disk command channel. |
| **REN / RENAME** | `TCMD1B.ASM` | `cmdRename` | **Complete** | Renames files via the disk command channel. |
| **VER** | `TCMD1A.ASM` | `cmdVer` | **Complete** | Displays kernel version and build number. |
| **HELP** | *(None - External)* | `cmdHelp` | **Complete** | Command 64 custom command displaying help text for internal functions. |
| **SET** | `TENV.ASM` | `cmdSet` | **Complete** | Lists environment variables stored persistently in the REU. |
| **PATH** | `TENV.ASM` | `cmdPath` | **Complete** | Manages executable search path stored in the REU. |
| **DRIVE / DEV** | *(Drive letters, e.g., `A:`)* | `cmdDrive` | **Complete** | Command 64 custom command to switch the active device (8-11). |
| **EXIT** | `TCMD2B.ASM` | `cmdExit` | **Complete** | Terminates Command 64 and warm-starts BASIC (`JMP $E37B`). |
| **CD / CHDIR** | `TCMD1B.ASM` | *(None)* | **Missing** | Planned for partition/directory navigation (1581/SD2IEC). |
| **MD / MKDIR** | `TCMD1B.ASM` | *(None)* | **Missing** | Planned for subdirectories. |
| **RD / RMDIR** | `TCMD1B.ASM` | *(None)* | **Missing** | Planned for subdirectory removal. |
| **DATE** | `TCMD2A.ASM` | *(None)* | **Missing** | Requires reading C64 CIA Real Time Clock. |
| **TIME** | `TCMD2A.ASM` | *(None)* | **Missing** | Requires reading C64 CIA Real Time Clock. |
| **PROMPT** | `TENV.ASM` | *(None)* | **Missing** | Prompts are currently static. |
| **VOL / LABEL** | `TCMD1B.ASM` | *(None)* | **Missing** | Read/write disk header label. |

#### Key Gaps:
1. **Subdirectories:** MS-DOS v4.0 has hierarchical directory navigation (`CD`, `MD`, `RD`). Command 64 OS is currently limited to flat disk operations (partially addressed by SD2IEC/1581 partitions in Phase 5).
2. **System Clock:** MS-DOS has `DATE` and `TIME` (driven by hardware interrupts and `TIME.ASM`). Command 64 OS has no clock support.
3. **Shell Customization:** MS-DOS has `PROMPT` to customize the command prompt dynamically. Command 64 OS has a static prompt (`C64:> `).

### Redirection & Piping
- **MS-DOS v4.0 (`TPIPE.ASM`):** Implements input/output redirection (`<`, `>`) and program command piping (`|`) by spooling temporary files to disk.
- **Command 64 OS:** No redirection or piping features exist. Standard input is tied to the keyboard and output is tied to the C64 screen.

### Batch Scripting (`.BAT`)
- **MS-DOS v4.0 (`TBATCH.ASM`):** Supports batch script parsing, variable expansion (`%1` to `%9`), and control flow instructions (`IF`, `GOTO`, `FOR`).
- **Command 64 OS:** No support for batch execution.

---

## 3. Kernel and System Services (`MSDOS.SYS`)

### Memory Allocation
- **MS-DOS v4.0 (`ALLOC.ASM`):** Manages host conventional memory ($0000-$9FFF / 640KB limit) using a chain of **Memory Control Blocks (MCBs)**. Supports first-fit, best-fit, and last-fit allocation policies.
- **Command 64 OS (`vmm.asm`):** Bypasses C64 conventional RAM constraints by mapping a 16MB virtual address space via a Commodore **RAM Expansion Unit (REU)**. Uses a 4KB Page Byte-Map strategy for allocation.
- **Analysis:** Command 64 OS is functionally complete in memory management, providing advanced memory capacity compared to MS-DOS's 640KB limit.

### Process Management & Executable Loader
- **MS-DOS v4.0 (`EXEC.ASM`):** Relocates executables dynamically (MZ header relocation table), creates the **Program Segment Prefix (PSP)** containing execution metadata, and handles parent/child environment block inheritance via INT 21h call `$4B` (EXEC).
- **Command 64 OS (`loader.asm`):** Relies on static load addresses (standard user program space at `$2200`). Relocation is not yet supported (prerequisite for Phase 6B relocator).
- **Analysis:** Command 64 OS is partially complete. A dynamic binary relocator is required to achieve MS-DOS parity.

### File Handle Table
- **MS-DOS v4.0 (`HANDLE.ASM`):** Tracks open file descriptors, maps handles to system File Control Blocks (FCBs), and implements seek (`LSEEK`), flush, and duplicate handle functions.
- **Command 64 OS (`file.asm`):** Implements a handle table mapping LFNs to C64 KERNAL channels. 
- **Analysis:** Command 64 OS internally implements handle operations for shell commands (`TYPE`, `COPY`). However, the public INT 21h service bus (`api.asm`) does *not* yet expose hooks like `DOS_OPEN_FILE` ($3D), `DOS_CLOSE_FILE` ($3E), `DOS_READ_FILE` ($3F), and `DOS_WRITE_FILE` ($40) for external user programs to utilize.

---

## 4. Input/Output System (`IO.SYS` / BIOS)

- **MS-DOS v4.0 (`BIOS/` & `DOS/DEV.ASM`):** Configures device headers and driver tables for character devices (`CON`, `PRN`, `AUX`) and block device sectors.
- **Command 64 OS:** Completely delegates character output and sector read/write execution to the built-in **C64 KERNAL ROM** (e.g., `CHROUT` at `$FFD2`, `GETIN` at `$FFE4`, `OPEN`/`CLOSE`/`LISTEN`/`TALK` vectors).
- **Analysis:** Complete. Reusing the KERNAL ROM is the correct architectural choice for the C64 platform, minimizing OS footprint.

---

## 5. Functional Completeness Gap Analysis

To achieve functional completeness compared to MS-DOS v4.0, the following major gaps must be resolved:

1. **Public File Handle API:** Exposing file handle management ($3D-$40) via the JSR `$1000` service bus so external user programs can read/write custom files.
2. **Dynamic Program Relocator:** Supporting MZ-style position-independent loading or relocation, shifting executables away from hardcoded `$2200` addresses.
3. **Subdirectories:** Supporting SD2IEC partition switching and 1581 directory parsing to navigate subdirectory structures.
4. **Time & Date:** Reading the C64 real-time clock (CIA 1/CIA 2 Time of Day clocks) to implement `DATE` and `TIME` commands and stamp files.
5. **Batch Processing:** Running `.BAT` script sequences.

---

## 6. Actionable Recommendations

### Short-Term (Priority 1)
- **Expose Handle API on Service Bus:** Add dispatch wrappers in `api.asm` pointing to the existing file functions in `file.asm` for `$3D` (Open), `$3E` (Close), `$3F` (Read), and `$40` (Write).

### Medium-Term (Priority 2)
- **Integrate Directory Walking:** Complete the pending Phase 5 subdirectory parsing tasks to support nested structures.
- **Implement Binary Relocator:** Proceed with Phase 6B relocator design to decouple program execution from static memory boundaries.

### Long-Term (Priority 3)
- **Time of Day CIA Clock:** Read C64 CIA registers to drive system time tracking.
- **I/O Redirection:** Implement basic output redirection (e.g., `DIR > OUTFILE.TXT`) by intercepting character output vectors.
