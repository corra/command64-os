// src/command64/petsci.asm
// KickAssembler v5.25 - PETSCII API Layer for command64
// Provides character and string output via C64 KERNAL routines.

.segment Petsci [start=$1000]

// --- petPrintChar ---
// Print a single PETSCII character.
// Input:  A = character to print
// Clobbers: none
.macro petPrintChar() {
    jsr KernalChROUT
}

// --- petPrintString ---
// Print a null-terminated PETSCII string.
// Input:  A = low byte of string address
//         Y = high byte of string address
// Clobbers: A, Y, PrintPtrLo ($FB), PrintPtrHi ($FC)
//
// PrintPtrLo/Hi are zero-page equates ($FB/$FC) — required for (zp),Y indirect.
.macro petPrintString() {
    sta PrintPtrLo          // store pointer low byte into ZP $FB
    sty PrintPtrHi          // store pointer high byte into ZP $FC
    ldy #0
psPrintLoop:
    lda (PrintPtrLo), y     // dereference: byte at [PrintPtrLo/Hi + Y]
    beq psPrintDone         // null terminator — stop
    jsr KernalChROUT
    iny
    bne psPrintLoop         // safe for strings < 256 bytes
    inc PrintPtrHi          // Y wrapped: advance base pointer high byte
    jmp psPrintLoop
psPrintDone:
}
