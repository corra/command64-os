; src/external/casm/diagnostics.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Allocation-free Phase 1 diagnostics. These routines remain safe while
; central resource cleanup is active.

.include "command64.inc"
.include "common.inc"

.export diagPrintString
.export diagPrintFatal

.segment "CODE"

; ---------------------------------------------------------------------------
; diagPrintString
; Print one null-terminated PETSCII string through the Command 64 API.
;
; Inputs:  X = string address low byte
;          Y = string address high byte
; Outputs: none
; Flags:   undefined after OS_API
; Clobbers: A and any registers documented as volatile by DOS_PRINT_STR;
;           callers must treat X and Y as volatile across the OS call
; ---------------------------------------------------------------------------
diagPrintString:
    lda #DOS_PRINT_STR
    jsr OS_API
    rts

; ---------------------------------------------------------------------------
; diagPrintFatal
; Select and print the stable message for a fatal diagnostic identifier.
;
; Inputs:  A = CASM_DIAG_* identifier
; Outputs: none
; Flags:   undefined after diagPrintString
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
diagPrintFatal:
    cmp #CASM_DIAG_INIT_FAILED
    beq dpfInit
    cmp #CASM_DIAG_REGISTRY_FULL
    beq dpfRegistry
    cmp #CASM_DIAG_CLEANUP_FAILED
    beq dpfCleanup
    ldx #<msgUnknown
    ldy #>msgUnknown
    jmp diagPrintString
dpfInit:
    ldx #<msgInitFailed
    ldy #>msgInitFailed
    jmp diagPrintString
dpfRegistry:
    ldx #<msgRegistryFull
    ldy #>msgRegistryFull
    jmp diagPrintString
dpfCleanup:
    ldx #<msgCleanupFailed
    ldy #>msgCleanupFailed
    jmp diagPrintString

.segment "RODATA"

msgInitFailed:
    .byte "CASM: INITIALIZATION FAILED", PetCr, 0
msgRegistryFull:
    .byte "CASM: RESOURCE REGISTRY FULL", PetCr, 0
msgCleanupFailed:
    .byte "CASM: RESOURCE CLEANUP FAILED", PetCr, 0
msgUnknown:
    .byte "CASM: INTERNAL ERROR", PetCr, 0
