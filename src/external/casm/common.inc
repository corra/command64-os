; src/external/casm/common.inc
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; CASM shared constants and module ABI. This file declares no storage and
; emits no code. Phase 0 contracts were approved on 2026-07-16; changes to
; these foundational limits require a new approved planning increment.

.ifndef CASM_COMMON_INC
CASM_COMMON_INC = 1

; ---------------------------------------------------------------------------
; Application-private zero page: $70-$8F
;
; These fixed-address aliases are transient scratch shared by CASM modules.
; They do not allocate linker storage. Any later linker-defined zero-page
; symbol shared across object files must use .exportzp/.importzp.
; ---------------------------------------------------------------------------

; General pointers and values ($70-$77).
CasmPtr0Lo       = $70
CasmPtr0Hi       = $71
CasmPtr1Lo       = $72
CasmPtr1Hi       = $73
CasmValue0Lo     = $74
CasmValue0Hi     = $75
CasmValue1Lo     = $76
CasmValue1Hi     = $77

; I/O and VMM transfer scratch ($78-$7F).
CasmIoPtrLo      = $78
CasmIoPtrHi      = $79
CasmIoLenLo      = $7A
CasmIoLenHi      = $7B
CasmVmmSegHi     = $7C
CasmVmmBank      = $7D
CasmVmmOffLo     = $7E
CasmVmmOffHi     = $7F

; Parser and expression transient scratch ($80-$87), reserved until the
; corresponding approved phases define narrower aliases.
CasmParseScratch0 = $80
CasmParseScratch1 = $81
CasmParseScratch2 = $82
CasmParseScratch3 = $83
CasmExprScratch0  = $84
CasmExprScratch1  = $85
CasmExprScratch2  = $86
CasmExprScratch3  = $87

; Pass and emission transient scratch ($88-$8F), reserved until the
; corresponding approved phases define narrower aliases.
CasmPassScratch0 = $88
CasmPassScratch1 = $89
CasmPassScratch2 = $8A
CasmPassScratch3 = $8B
CasmEmitScratch0 = $8C
CasmEmitScratch1 = $8D
CasmEmitScratch2 = $8E
CasmEmitScratch3 = $8F

CASM_ZP_FIRST = $70
CASM_ZP_LAST  = $8F
CASM_ZP_SIZE  = CASM_ZP_LAST - CASM_ZP_FIRST + 1
.assert CASM_ZP_SIZE = 32, error, "CASM zero-page contract must span 32 bytes"

; ---------------------------------------------------------------------------
; Bounded resource registry contract
; ---------------------------------------------------------------------------

CASM_FILE_CAPACITY = 8
CASM_VMM_CAPACITY  = 8

CASM_RESOURCE_FREE  = 0
CASM_RESOURCE_OWNED = 1
CASM_INVALID_HANDLE = $FF

; File record: occupancy flag followed by Command 64 handle.
CASM_FILE_REC_FLAG   = 0
CASM_FILE_REC_HANDLE = 1
CASM_FILE_REC_SIZE   = 2

; VMM record: occupancy flag followed by the DOS_ALLOC_MEM identity returned
; in X (segment high byte) and Y (REU bank).
CASM_VMM_REC_FLAG  = 0
CASM_VMM_REC_SEGHI = 1
CASM_VMM_REC_BANK  = 2
CASM_VMM_REC_SIZE  = 3

CASM_FILE_REGISTRY_BYTES = CASM_FILE_CAPACITY * CASM_FILE_REC_SIZE
CASM_VMM_REGISTRY_BYTES  = CASM_VMM_CAPACITY * CASM_VMM_REC_SIZE

.assert CASM_FILE_CAPACITY = 8, error, "CASM file registry contract changed"
.assert CASM_VMM_CAPACITY = 8, error, "CASM VMM registry contract changed"

; ---------------------------------------------------------------------------
; Stable diagnostic identifiers
; ---------------------------------------------------------------------------

CASM_DIAG_NONE           = $00
CASM_DIAG_INIT_FAILED    = $01
CASM_DIAG_REGISTRY_FULL  = $02
CASM_DIAG_CLEANUP_FAILED = $03
CASM_DIAG_UNKNOWN        = $FF

; Registration/release routines return carry clear on success. On failure,
; carry is set and A contains one of the CASM_DIAG_* identifiers above.

; ---------------------------------------------------------------------------
; Phase and cleanup state
; ---------------------------------------------------------------------------

CASM_PHASE_SCAFFOLD = $01

CASM_CLEANUP_IDLE   = $00
CASM_CLEANUP_ACTIVE = $01

; Phase 1 initial ld65 MAIN envelope. CMake consumes the hexadecimal string
; "1000"; this numeric mirror supports later size assertions and docs.
CASM_PHASE1_MAIN_SIZE = $1000

.endif
