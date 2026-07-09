; include/ca65/vmm.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; VMM (Virtual Memory Manager) API Specification
; Maps 1MB logical DOS space to C64 Ultimate REU
;
; ca65 port of include/vmm.inc — equate-for-equate mirror, kept in sync by
; hand. See include/ca65/README.md (once it exists) for the sync policy.

; --- VMM Constants ---
VMM_SUCCESS     = $00
VMM_ERR_NOMEM   = $01
VMM_ERR_INVALID = $02

; --- Register / ZP Interface ---
; Using ZP locations $68-$6C (FAC1) for 16-bit segment/offset pointers.
; This avoids clobbering BASIC pointers ($2B-$32) and KERNAL I/O ($90-$FA).
VmmSegLo    = $68
VmmSegHi    = $69
VmmOffLo    = $6A
VmmOffHi    = $6B
VmmBank     = $6C
FileHandle  = $6D  ; Active handle for DOS_READ/WRITE/CLOSE_FILE API calls
SrcHandle   = $6E  ; cmdCopy: source handle scratch
DstHandle   = $6F  ; cmdCopy: destination handle scratch

; --- REU Hardware Registers ($DF00-$DF0A) ---
REU_STATUS     = $DF00 ; R: Status, W: Clear Interrupts
REU_COMMAND    = $DF01 ; W: Execute DMA
REU_C64_ADDR_L = $DF02 ; W: C64 Base Lo
REU_C64_ADDR_H = $DF03 ; W: C64 Base Hi
REU_REU_ADDR_L = $DF04 ; W: REU Base Lo
REU_REU_ADDR_H = $DF05 ; W: REU Base Hi
REU_REU_BANK   = $DF06 ; W: REU Bank (64K units)
REU_LEN_L      = $DF07 ; W: Transfer length Lo
REU_LEN_H      = $DF08 ; W: Transfer length Hi
REU_IRQ_MASK   = $DF09 ; W: Interrupt mask
REU_ADDR_CTRL  = $DF0A ; W: Address control

; --- REU Commands ---
REU_CMD_STASH = $90 ; C64 -> REU (Execute immediately)
REU_CMD_FETCH = $91 ; REU -> C64 (Execute immediately)
REU_CMD_SWAP  = $92 ; C64 <-> REU (Execute immediately)

; --- Memory Management Structures (Base RAM) ---
; $C000 is 4KB of free RAM above BASIC, safe for MCT.
VmmMctBase  = $C000 ; Memory Control Table (4096 bytes for 16MB)
VmmFreeHead = $CFFF ; Pointer to first free memory block

; --- Page State Flags ---
PAGE_FREE = $00
PAGE_HEAD = $01
PAGE_TAIL = $02
