// src/command64/loader.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// KickAssembler v5.25 - MS-DOS 4.0 to C64 Port Binary Loader
// Wraps KERNAL LOAD routine with support for specific target addresses.

.segment Loader

// --- shellLoadPrg ---
// Loads a PRG from disk using KERNAL routines.
// Input:  A = low byte of filename pointer
//         Y = high byte of filename pointer
//         X = filename length
//         HexValLo/Hi ($66-$67) = target address (if SpecificLoad=0)
//         SpecificLoad ($038D) = 0 to use HexVal, 1 to use file header
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
    
    // SETLFS: A=channel(1), X=device(CurrentDevice), Y=secondary (0=Relocated, 1=Absolute)
    lda #1
    ldx CurrentDevice
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
    
    // LOAD: A=0(Load), X/Y=target (ignored if secondary address was 0)
    lda #0                  // 0 = Load, 1 = Verify
    ldx HexValLo
    ldy HexValHi
    jsr KernalLOAD
    rts

loadingMsg:
    .text "loading..."
    .byte 0

// aptRelocate lives in ShellExt (roomy space after the fixed $2000 AppTable,
// well before UserProgStart) rather than here: the Loader/Path/Vmm/File
// segment chain is packed tightly against the fixed $1000 ApiStub jump
// table with no slack for a routine this size. JSR works fine across
// segments, so cmdLoad's call site in shell.asm is unaffected.
.segment ShellExt

// --- aptRelocate ---
// Phase 6B Binary Relocator. External apps are built twice one page apart
// ($2600/$2700) and diffed by tools/reloc.py, which appends a high-byte
// relocation table plus a 6-byte footer (BaseAddrLo/Hi, TableSizeLo/Hi,
// Magic 'R','6') to the end of the compiled binary. This routine reads
// that footer, patches every recorded high byte by (load page - compile
// page) when the program was loaded away from its compiled address, and
// truncates the registered program size so the table/footer are excluded
// from the active program's bounds.
//
// If the trailing magic doesn't match (e.g. a plain, non-relocatable PRG
// loaded via LOAD), the routine leaves TempLo/Hi untouched and returns
// with carry set -- the caller (cmdLoad) does not branch on this, so the
// program is simply registered at its full as-loaded size, unpatched.
//
// Input:  HexValLo/Hi ($66-$67) = target load address (always page-aligned: HexValLo=$00)
//         TempLo/Hi ($64-$65) = end address + 1 (returned by KERNAL LOAD)
// Output: TempLo/Hi ($64-$65) = truncated end address + 1 (clean code size)
//         Carry: clear on success, set if the footer magic doesn't match
// Clobbers: A, X, Y
// ZP/Cassette Buffer Workspace usage:
//   PrintPtrLo/Hi ($FB-$FC): relocation table walk pointer
//   NamePtrLo/Hi  ($FD-$FE): computed patch address for each table entry
//   AptTempSizeLo/Hi ($03F6-$03F7): TableSize, then re-used to hold the computed table-start/truncated-end value
//   AptTempEndLo     ($03F8):       PageOffset (load page - compile page)
// These are the same labels apptable.asm's aptRegister uses for its overlap
// check; safe to re-use here because aptRelocate always completes before
// aptRegister runs next (see cmdLoad in shell.asm). TempLo/Hi itself (zero
// page) doubles as the footer pointer/loop bound once it holds FooterPtr,
// so no separate scratch copy of it is needed.
aptRelocate:
    // FooterPtr = TempLo/Hi - 6 (fixed-size footer at the very end of the load).
    // TempLo/Hi is zero page, so it can be used directly as an indirect pointer.
    sec
    lda TempLo
    sbc #6
    sta TempLo
    lda TempHi
    sbc #0
    sta TempHi

    // Read footer fields (PageOffset, TableSize, Magic) via TempLo/Hi
    ldy #1
    lda HexValHi
    sec
    sbc (TempLo),y          // PageOffset = HexValHi - BaseAddrHi (BaseAddrLo is always $00)
    sta AptTempEndLo
    ldy #2
    lda (TempLo),y          // TableSizeLo
    sta AptTempSizeLo
    ldy #3
    lda (TempLo),y          // TableSizeHi
    sta AptTempSizeHi
    ldy #4
    lda (TempLo),y          // Magic byte 0: 'R'
    cmp #$52
    beq aptRelocateMagic0Ok
    jmp aptRelocateFail
aptRelocateMagic0Ok:
    ldy #5
    lda (TempLo),y          // Magic byte 1: '6'
    cmp #$36
    beq aptRelocateMagic1Ok
    jmp aptRelocateFail
aptRelocateMagic1Ok:

    // TableSize -> byte count (each entry is a 16-bit offset)
    asl AptTempSizeLo
    rol AptTempSizeHi

    // TableStart = FooterPtr - TableSize*2 == start of table == truncated end+1.
    // Stash the low byte in X since AptTempSizeLo is consumed as the subtrahend.
    sec
    lda TempLo
    sbc AptTempSizeLo
    tax
    lda TempHi
    sbc AptTempSizeHi
    sta AptTempSizeHi       // Final Temp storage: truncated end+1 (hi)
    stx AptTempSizeLo       // Final Temp storage: truncated end+1 (lo)

    lda AptTempSizeLo
    sta PrintPtrLo
    lda AptTempSizeHi
    sta PrintPtrHi

    // Loaded at its compiled address: nothing to patch, just truncate below.
    lda AptTempEndLo
    beq aptRelocateStoreEnd

    // The patch loop below uses NamePtrLo/Hi as scratch, but aptRegister
    // (called next by cmdLoad) requires NamePtrLo/Hi to still point at the
    // filename -- save/restore across the loop so its contract holds.
    lda NamePtrLo
    pha
    lda NamePtrHi
    pha

aptRelocateLoop:
    lda PrintPtrLo
    cmp TempLo
    bne aptRelocatePatchOne
    lda PrintPtrHi
    cmp TempHi
    beq aptRelocateLoopDone // table pointer caught up to FooterPtr: done

aptRelocatePatchOne:
    // Read this entry's code offset -> absolute patch address (HexValLo is always $00)
    ldy #0
    lda (PrintPtrLo),y
    sta NamePtrLo
    iny
    lda (PrintPtrLo),y
    clc
    adc HexValHi
    sta NamePtrHi

    // Patch the high byte in place
    ldy #0
    lda (NamePtrLo),y
    clc
    adc AptTempEndLo
    sta (NamePtrLo),y

    // Advance the table pointer to the next entry
    clc
    lda PrintPtrLo
    adc #2
    sta PrintPtrLo
    lda PrintPtrHi
    adc #0
    sta PrintPtrHi

    jmp aptRelocateLoop

aptRelocateLoopDone:
    pla
    sta NamePtrHi
    pla
    sta NamePtrLo

aptRelocateStoreEnd:
    lda AptTempSizeLo
    sta TempLo
    lda AptTempSizeHi
    sta TempHi
    clc                     // success
    rts

aptRelocateFail:
    clc
    lda TempLo
    adc #6
    sta TempLo
    lda TempHi
    adc #0
    sta TempHi
    sec                     // indicate failure
    rts
