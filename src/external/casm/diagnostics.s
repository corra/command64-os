; src/external/casm/diagnostics.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; Allocation-free CASM diagnostics. These routines remain safe while central
; resource cleanup is active and never acquire file or VMM resources.

.include "command64.inc"
.include "common.inc"

.export diagPrintString
.export diagPrintFatal
.export diagPrintPhase2Ready

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
; Select and print the stable message for a fatal diagnostic identifier. Phase
; 2 diagnostic values $01-$13 are contiguous and index bounded parallel tables;
; zero, out-of-range, and $FF values use the unknown fallback.
;
; Inputs:  A = CASM_DIAG_* identifier
; Outputs: none
; Flags:   undefined after diagPrintString
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
diagPrintFatal:
    cmp #CASM_DIAG_INIT_FAILED
    bcc dpfUnknown
    cmp #CASM_DIAG_STREAM_STATE_FAILED + 1
    bcs dpfUnknown
    sec
    sbc #CASM_DIAG_INIT_FAILED
    tax
    lda diagMessageLo, x
    pha
    lda diagMessageHi, x
    tay
    pla
    tax
    jmp diagPrintString
dpfUnknown:
    ldx #<msgUnknown
    ldy #>msgUnknown
    jmp diagPrintString

; ---------------------------------------------------------------------------
; diagPrintPhase2Ready
; Print the stable successful-input-validation message.
;
; Inputs:  none
; Outputs: none
; Flags:   undefined after diagPrintString
; Clobbers: A, X, Y and OS API-defined volatile registers
; ---------------------------------------------------------------------------
diagPrintPhase2Ready:
    ldx #<msgPhase2Ready
    ldy #>msgPhase2Ready
    jmp diagPrintString

.segment "RODATA"

diagMessageLo:
    .byte <msgInitFailed
    .byte <msgRegistryFull
    .byte <msgCleanupFailed
    .byte <msgSourceRequired
    .byte <msgExtraSource
    .byte <msgMalformedOutput
    .byte <msgDuplicateOption
    .byte <msgUnknownOption
    .byte <msgFilenameTooLong
    .byte <msgNotImplemented
    .byte <msgInputOpenFailed
    .byte <msgInputReadFailed
    .byte <msgInputCloseFailed
    .byte <msgOutputCreateFailed
    .byte <msgOutputWriteFailed
    .byte <msgOutputCloseFailed
    .byte <msgOutputDeleteFailed
    .byte <msgOutputShortWrite
    .byte <msgStreamStateFailed
diagMessageLoEnd:

diagMessageHi:
    .byte >msgInitFailed
    .byte >msgRegistryFull
    .byte >msgCleanupFailed
    .byte >msgSourceRequired
    .byte >msgExtraSource
    .byte >msgMalformedOutput
    .byte >msgDuplicateOption
    .byte >msgUnknownOption
    .byte >msgFilenameTooLong
    .byte >msgNotImplemented
    .byte >msgInputOpenFailed
    .byte >msgInputReadFailed
    .byte >msgInputCloseFailed
    .byte >msgOutputCreateFailed
    .byte >msgOutputWriteFailed
    .byte >msgOutputCloseFailed
    .byte >msgOutputDeleteFailed
    .byte >msgOutputShortWrite
    .byte >msgStreamStateFailed
diagMessageHiEnd:

.assert diagMessageLoEnd - diagMessageLo = CASM_DIAG_STREAM_STATE_FAILED, error, "CASM diagnostic low table is incomplete"
.assert diagMessageHiEnd - diagMessageHi = CASM_DIAG_STREAM_STATE_FAILED, error, "CASM diagnostic high table is incomplete"

msgInitFailed:
    .byte "CASM: INITIALIZATION FAILED", PetCr, 0
msgRegistryFull:
    .byte "CASM: RESOURCE REGISTRY FULL", PetCr, 0
msgCleanupFailed:
    .byte "CASM: RESOURCE CLEANUP FAILED", PetCr, 0
msgSourceRequired:
    .byte "CASM: SOURCE FILE REQUIRED", PetCr, 0
msgExtraSource:
    .byte "CASM: TOO MANY SOURCE FILES", PetCr, 0
msgMalformedOutput:
    .byte "CASM: MALFORMED /O OPTION", PetCr, 0
msgDuplicateOption:
    .byte "CASM: DUPLICATE OPTION", PetCr, 0
msgUnknownOption:
    .byte "CASM: UNKNOWN OPTION", PetCr, 0
msgFilenameTooLong:
    .byte "CASM: FILENAME TOO LONG", PetCr, 0
msgNotImplemented:
    .byte "CASM: FEATURE NOT IMPLEMENTED", PetCr, 0
msgInputOpenFailed:
    .byte "CASM: CANNOT OPEN INPUT", PetCr, 0
msgInputReadFailed:
    .byte "CASM: INPUT READ FAILED", PetCr, 0
msgInputCloseFailed:
    .byte "CASM: INPUT CLOSE FAILED", PetCr, 0
msgOutputCreateFailed:
    .byte "CASM: CANNOT CREATE OUTPUT", PetCr, 0
msgOutputWriteFailed:
    .byte "CASM: OUTPUT WRITE FAILED", PetCr, 0
msgOutputCloseFailed:
    .byte "CASM: OUTPUT CLOSE FAILED", PetCr, 0
msgOutputDeleteFailed:
    .byte "CASM: OUTPUT DELETE FAILED", PetCr, 0
msgOutputShortWrite:
    .byte "CASM: SHORT OUTPUT WRITE", PetCr, 0
msgStreamStateFailed:
    .byte "CASM: INVALID STREAM STATE", PetCr, 0
msgUnknown:
    .byte "CASM: INTERNAL ERROR", PetCr, 0
msgPhase2Ready:
    .byte "CASM: INPUT VALIDATED", PetCr, 0
