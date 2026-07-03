// include/vmm.inc
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// VMM (Virtual Memory Manager) API Specification
// Maps 1MB logical DOS space to C64 Ultimate REU

// --- VMM Constants ---
.label VMM_SUCCESS      = $00
.label VMM_ERR_NOMEM    = $01
.label VMM_ERR_INVALID  = $02

// --- Register / ZP Interface ---
// Using ZP locations $68-$6C (FAC1) for 16-bit segment/offset pointers.
// This avoids clobbering BASIC pointers ($2B-$32) and KERNAL I/O ($90-$FA).
.label VmmSegLo     = $68
.label VmmSegHi     = $69
.label VmmOffLo     = $6A
.label VmmOffHi     = $6B
.label VmmBank      = $6C
.label FileHandle   = $6D  // Active handle for DOS_READ/WRITE/CLOSE_FILE API calls
.label SrcHandle    = $6E  // cmdCopy: source handle scratch
.label DstHandle    = $6F  // cmdCopy: destination handle scratch

// --- REU Hardware Registers ($DF00-$DF0A) ---
.label REU_STATUS     = $DF00 // R: Status, W: Clear Interrupts
.label REU_COMMAND    = $DF01 // W: Execute DMA
.label REU_C64_ADDR_L = $DF02 // W: C64 Base Lo
.label REU_C64_ADDR_H = $DF03 // W: C64 Base Hi
.label REU_REU_ADDR_L = $DF04 // W: REU Base Lo
.label REU_REU_ADDR_H = $DF05 // W: REU Base Hi
.label REU_REU_BANK   = $DF06 // W: REU Bank (64K units)
.label REU_LEN_L      = $DF07 // W: Transfer length Lo
.label REU_LEN_H      = $DF08 // W: Transfer length Hi
.label REU_IRQ_MASK   = $DF09 // W: Interrupt mask
.label REU_ADDR_CTRL  = $DF0A // W: Address control

// --- REU Commands ---
.label REU_CMD_STASH   = $90 // C64 -> REU (Execute immediately)
.label REU_CMD_FETCH   = $91 // REU -> C64 (Execute immediately)
.label REU_CMD_SWAP    = $92 // C64 <-> REU (Execute immediately)

// --- Memory Management Structures (Base RAM) ---
// $C000 is 4KB of free RAM above BASIC, safe for MCT.
.label VmmMctBase  = $C000 // Memory Control Table (4096 bytes for 16MB)
.label VmmFreeHead = $CFFF // Pointer to first free memory block

// --- Page State Flags ---
.label PAGE_FREE   = $00
.label PAGE_HEAD   = $01
.label PAGE_TAIL   = $02
