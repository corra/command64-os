# Specification Review: DEBUG Utility vs. MS-DOS 4.0

**Date:** 2026-05-12
**Reference:** [The Starman's DEBUG Guide](https://thestarman.pcministry.com/asm/debug/debug.htm)
**Status:** MVP Complete (v0.1.2); Phase 2 Planning.

## 1. Syntax & Parameter Alignment
MS-DOS DEBUG supports flexible range and addressing syntax that we should adopt for parity:

| Syntax | MS-DOS Description | C64 Implementation Plan |
|:---|:---|:---|
| **`L` (Length)** | `START L LENGTH` (e.g. `D 1000 L 40`) | High priority for Phase 2. Improves flexibility. |
| **`BANK:OFF`** | `SEGMENT:OFFSET` (e.g. `0100:0200`) | Map to `BANK:OFFSET` to allow inspection of 16MB VMM space. |
| **String Lists** | `F 1000 1100 "DATA"` | Support quoted strings in `E`, `F`, and `S` commands. |

## 2. Feature Gap Analysis (C64 Context)

| Command | MS-DOS Function | C64 Value / Feasibility |
|:--- |:--- |:---|
| **`I` / `O`** | Port Input/Output | **Critical**. Direct interaction with VIC-II ($D000), SID ($D400), CIA ($DC00). |
| **`R [reg]`** | Modify Registers | **High**. Allow `R A 00` to set register state before a `G` command. |
| **`N / L / W`** | File/Sector Disk I/O | **High**. Essential for low-level disk repair and binary patching. |
| **`XA/XD/XM`** | EMS Memory Management | **Excellent**. Direct mapping to our VMM/REU service bus functions. |
| **`U` (Unasm)** | Disassembler | **Medium**. High effort, but highly valuable for on-machine debugging. |
| **`A` (Asm)** | Inline Assembler | **Low**. Extremely high effort; deferred. |
| **`T` / `P`** | Trace / Proceed | **Complex**. Requires NMI or BRK-based state capture engine. |

## 3. Roadmap: DEBUG Development Phases

### Phase 2: Hardware & Logic (Near Term)
- Implement **`I` (Input)** and **`O` (Output)** for register poking.
- Implement **`L` (Length)** syntax for range-based commands.
- Extend **`R` (Register)** to allow modification.

### Phase 3: VMM & VMM Memory (Mid Term)
- Implement **`XA` / `XD` / `XM` / `XS`** commands using the OS Service Bus.
- Support **`BANK:OFFSET`** notation for all memory commands.

### Phase 4: Disk & Files (Long Term)
- Implement **`N` (Name)**, **`L` (Load)**, and **`W` (Write)** for binary and raw sector manipulation.

## 4. Conclusion
The current implementation provides a robust "Monitor" capability. Transitioning to Phase 2 will elevate it to a true "System Debugger" by providing direct hardware (I/O) and state (Register) control.
