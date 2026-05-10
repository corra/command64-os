// src/command64/loader.asm
// KickAssembler v5.25 - MS-DOS 4.0 to C64 Port Binary Loader
// Wraps KERNAL LOAD routine with support for specific target addresses.

.segment Loader [start=$1680]

// --- shellLoadPrg ---
// Loads a PRG from disk using KERNAL routines.
// Input:  A = low byte of filename pointer
//         Y = high byte of filename pointer
//         X = filename length
//         HexValLo/Hi ($F7-$F8) = target address (if SpecificLoad=1)
//         SpecificLoad ($1551) = 1 to use HexVal, 0 to use file header
// Output: C=0 success, C=1 error (A = KERNAL error code)
// Clobbers: A, X, Y
shellLoadPrg:
    stx TempLo              // Save length temporarily
    sta TempHi              // Reuse ZP for name pointer (TempHi:TempLo)
    sty PrintPtrHi          // PrintPtrLo/Hi used by SETNAM
    
    // SETNAM: A=length, X/Y=pointer
    lda TempLo
    ldx TempHi
    ldy PrintPtrHi
    jsr KernalSETNAM
    
    // SETLFS: A=channel(1), X=device(8), Y=secondary (0=Relocated, 1=Absolute)
    lda #1
    ldx #8                  // Default to device 8 for now
    ldy SpecificLoad
    jsr KernalSETLFS
    
    // Disable KERNAL messages
    lda #0
    jsr KernalSETMSG

    // Print "loading..."
    lda #<loadingMsg
    ldy #>loadingMsg
    jsr petPrintString
    lda #PetCr
    jsr KernalChROUT
    lda #PetLl
    jsr KernalChROUT
    
    // LOAD: A=0(Load), X/Y=target (ignored if secondary address was 0)
    lda #0                  // 0 = Load, 1 = Verify
    ldx HexValLo
    ldy HexValHi
    jsr KernalLOAD
    rts

loadingMsg:
    .text "loading..."
    .byte 0
