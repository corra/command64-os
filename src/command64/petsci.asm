// src/command64/petsci.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// KickAssembler v5.25 - PETSCII API Layer for command64
// Provides character and string output via C64 KERNAL routines.

.segment Petsci

// --- petPrintChar ---
// Print a single PETSCII character.
// Input:  A = character to print
.macro petPrintChar() {
    jsr KernalChROUT
}

// --- petPrintString ---
// Subroutine to print a null-terminated PETSCII string.
// Input:  A = low byte of string address
//         Y = high byte of string address
// Uses:   PrintPtrLo ($22), PrintPtrHi ($23)
// Note:   Preserves X and Y.
petPrintString:
    sta PrintPtrLo          // store pointer low byte
    sty PrintPtrHi          // store pointer high byte
    ldy #0
_psLoop:
    lda (PrintPtrLo), y     // dereference: byte at [PrintPtrLo/Hi + Y]
    beq _psDone             // null terminator — stop
    
    // We assume KernalChROUT preserves X and Y as per standard C64 docs.
    // If it clobbered them, the prompt would also be garbled.
    jsr KernalChROUT
    
    iny
    bne _psLoop             // loop for current page
    inc PrintPtrHi          // advance to next page
    jmp _psLoop
_psDone:
    rts
