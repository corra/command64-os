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
| **VOL / LABEL** | `TCMD1B.ASM` | `cmdVol`/`cmdLabel` | **Complete** | Read/write disk directory header volume label. |

#### Key Gaps

1. **Subdirectories:** MS-DOS v4.0 has hierarchical directory navigation (`CD`, `MD`, `RD`). Command 64 OS is currently limited to flat disk operations (partially addressed by SD2IEC/1581 partitions in Phase 5).
2. **System Clock:** MS-DOS has `DATE` and `TIME` (driven by hardware interrupts and `TIME.ASM`). Command 64 OS has no clock support.
3. **Shell Customization:** MS-DOS has `PROMPT` to customize the command prompt dynamically. Command 64 OS has a static prompt (`C64:>`).

### Redirection & Piping

- **MS-DOS v4.0 (`TPIPE.ASM`):** Implements input/output redirection (`<`, `>`) and program command piping (`|`) by spooling temporary files to disk.
- **Command 64 OS:** No redirection or piping features exist. Standard input is tied to the keyboard and output is tied to the C64 screen.

### Batch Scripting (`.BAT`)

- **MS-DOS v4.0 (`TBATCH.ASM`):** Supports batch script parsing, variable expansion (`%1` to `%9`), and control flow instructions (`IF`, `GOTO`, `FOR`).
- **Command 64 OS:** No support for batch execution.

---

### 3. Kernel and System Services (`MSDOS.SYS`)

### MSDOS.SYS Kernel Feature Matrix

This matrix maps core kernel subsystems of `MSDOS.SYS` to their Command 64 OS equivalents.

| Subsystem | MS-DOS v4.0 Source File | Command 64 Equivalent | Status | C64 Implementation / Gap Notes |
| :--- | :--- | :--- | :--- | :--- |
| **API Dispatcher** | `DOS/DISPATCH.ASM`, `SRVCALL.ASM` | [api.asm](file:///home/morgan/development/c64/command64-os/src/command64/api.asm) | **Partial** | Subroutine Jump Table (`JSR $1000`) instead of CPU interrupt vector (due to 6502 stack/interrupt limits). |
| **Memory Manager** | `DOS/ALLOC.ASM` | [vmm.asm](file:///home/morgan/development/c64/command64-os/src/command64/vmm.asm) | **Complete** | Maps 16MB virtual address space in REU (4KB page byte-map), exceeding MS-DOS conventional 640KB bounds. |
| **File I/O Handle Table** | `DOS/HANDLE.ASM`, `FILE.ASM` | [file.asm](file:///home/morgan/development/c64/command64-os/src/command64/file.asm) | **Partial** | Maps handles 0-7 to C64 secondary addresses. Critical Gap: Handles are not yet exposed on public JSR service bus ($3D-$40). |
| **Program Exec / Loader** | `DOS/EXEC.ASM` | [loader.asm](file:///home/morgan/development/c64/command64-os/src/command64/loader.asm) | **Complete** | Standard binary loader loading to `UserProgStart` (`$2C00`), plus a Binary Relocator (`aptRelocate`, Phase 6B) supporting position-independent loads at arbitrary addresses via a compile-time-generated relocation table. |
| **Directory Search** | `DOS/SEARCH.ASM`, `PATH.ASM` | [path.asm](file:///home/morgan/development/c64/command64-os/src/command64/path.asm) | **Partial** | Searches filenames on disk, matches case-insensitively. Gaps: Hierarchical subdirectories and partition-walking are missing. |
| **FAT File Allocation Table** | `DOS/FAT.ASM`, `DISK.ASM` | *(C64 Drive ROM)* | **Complete** | Delegated to the Commodore floppy disk drive (e.g. 1541/1571/1581) which handles sectors and BAM directly. |
| **File Buffering** | `DOS/BUF.ASM` | [file.asm](file:///home/morgan/development/c64/command64-os/src/command64/file.asm) | **Complete** | Command 64 implements 64-byte buffered I/O read/write segments to optimize C64 IEC serial bus performance. |

---

## 4. Input/Output System (`IO.SYS` / BIOS)

### IO.SYS BIOS / Device Driver Feature Matrix

This matrix maps core BIOS low-level device drivers of `IO.SYS` to their Command 64 OS equivalents.

| Driver / Device | MS-DOS v4.0 Source File | Command 64 Equivalent | Status | C64 Implementation / Gap Notes |
| :--- | :--- | :--- | :--- | :--- |
| **CON (Console Screen)** | `BIOS/MSCON.ASM` | KERNAL ROM + [petsci.asm](file:///home/morgan/development/c64/command64-os/src/command64/petsci.asm) | **Complete** | Screen editor screen writing (`CHROUT` at `$FFD2`) and standard 40-column PETSCII character output. |
| **CON (Keyboard Input)** | `BIOS/MSCON.ASM` | KERNAL ROM | **Complete** | Keyboard scan buffer polling (`GETIN` at `$FFE4`) with backspace and input buffering. |
| **Block Device (Disk Controller)** | `BIOS/MSDISK.ASM` | KERNAL ROM | **Complete** | Uses standard serial IEC bus protocols (`TALK`/`LISTEN`/`ACPTR`/`CIOUT`) to command disk drives. |
| **PRN / LPT (Printer)** | `BIOS/MSLPT.ASM` | KERNAL ROM | **Complete** | Can direct output to device #4 (standard C64 printer address) via KERNAL serial bus. |
| **AUX / COM (Serial/RS232)** | `BIOS/MSAUX.ASM` | KERNAL ROM | **Complete** | Can stream to C64 RS-232 device vectors if serial cartridge is connected. |
| **CLOCK (System Clock)** | `BIOS/MSCLOCK.ASM` | *(None)* | **Missing** | CIA 1 / CIA 2 Time of Day (TOD) clock reads are not yet implemented. |
| **SYSINIT (System Startup)** | `BIOS/MSINIT.ASM` | [shell.asm](file:///home/morgan/development/c64/command64-os/src/command64/shell.asm) | **Complete** | Boot init clears variables, verifies REU presence, installs Jump Table, and boots prompt. |

---

## 5. Functional Completeness Gap Analysis

To achieve functional completeness compared to MS-DOS v4.0, the following major gaps must be resolved:

1. **Public File Handle API:** Exposing file handle management ($3D-$40) via the JSR `$1000` service bus so external user programs can read/write custom files.
2. **Subdirectories:** Supporting SD2IEC partition switching and 1581 directory parsing to navigate subdirectory structures.
3. **Time & Date:** Reading the C64 real-time clock (CIA 1/CIA 2 Time of Day clocks) to implement `DATE` and `TIME` commands and stamp files.
4. **Batch Processing:** Running `.BAT` script sequences.

> Note: the Dynamic Program Relocator gap previously listed here has been resolved — see the Program Exec / Loader row above.

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
