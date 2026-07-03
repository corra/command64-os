// src/command64/vmm.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// Virtual Memory Manager for C64 MS-DOS Port
// Maps 1MB DOS Address Space (Seg:Off) to C64 REU.

.segment Vmm

// --- vmmInit ---
// Initializes the VMM and verifies REU presence.
// Output: A = VMM_SUCCESS or error code.
vmmInit:
    // Check if REU is present
    lda REU_STATUS
    and #$10                // Size bit (1 = 512K or more)
    beq viNoReu
    
    // Initialize Memory Control Table (MCT) - clear 4KB ($3000-$3FFF)
    lda #<VmmMctBase
    sta PrintPtrLo
    lda #>VmmMctBase
    sta PrintPtrHi
    
    ldx #16                 // 16 pages of 256 bytes = 4096 bytes
    ldy #0
    lda #PAGE_FREE
viClearLoop:
    sta (PrintPtrLo), y
    iny
    bne viClearLoop
    inc PrintPtrHi
    dex
    bne viClearLoop
    
    lda #1
    sta vmmInitialized      // Mark VMM as ready
    lda #VMM_SUCCESS
    rts
viNoReu:
    lda #0
    sta vmmInitialized      // Mark VMM as not available
    lda #VMM_ERR_INVALID
    rts

// --- vmmAlloc ---
// Allocates contiguous 4KB pages in the REU.
// Input:  VmmSegLo/Hi = requested paragraphs (16-byte units)
// Output: A = return code
//         VmmSegLo/Hi = starting logical segment on success
vmmAlloc:
    lda vmmInitialized
    bne vaInitOk
    lda #VMM_ERR_INVALID
    rts

vaInitOk:
    // Guard: zero-paragraph request is invalid (commit step does ldx #0; dex → X=$FF, marks 255 pages)
    lda VmmSegLo
    ora VmmSegHi
    beq vaZeroErr

    // 1. Round up paragraphs to pages (1 page = 256 paragraphs = $0100)
    // PageCount = (Paragraphs + 255) >> 8
    lda VmmSegLo
    clc
    adc #$FF
    lda VmmSegHi
    adc #0
    // A now contains the required page count. If 0 (and input was >0), it means overflow or exactly 0 requested.
    sta TempHi              // TempHi = Required Page Count
    
    // 2. Scan MCT for contiguous free pages
    lda #<VmmMctBase
    sta PrintPtrLo
    lda #>VmmMctBase
    sta PrintPtrHi
    
    ldx #0                  // Current Page Index (0-255 within current 256-byte block)
    stx TempLo              // TempLo = Global Block Offset (0-15)
vaBlockLoop:
    ldy #0
vaSearchLoop:
    lda (PrintPtrLo), y
    beq vaFoundPotential
vaResetSearch:
    iny
    bne vaSearchLoop
    
    // Next 256-byte block
    inc PrintPtrHi
    inc TempLo
    lda TempLo
    cmp #16                 // Finished all 4096 bytes?
    bcc vaBlockLoop
    
    lda #VMM_ERR_NOMEM
    rts

vaFoundPotential:
    // Check if we have enough contiguous pages starting at Y
    sty VmmOffLo            // Store starting Y
    lda TempLo
    sta VmmOffHi            // Store starting block offset
    
    ldx #0                  // Count of found pages
vaContigLoop:
    lda (PrintPtrLo), y
    bne vaSearchReset       // Not free, reset search from where we failed
    inx
    cpx TempHi              // Found enough?
    beq vaCommitAlloc
    
    iny
    bne vaContigLoop
    
    // Crosses 256-byte boundary
    inc PrintPtrHi
    inc TempLo
    lda TempLo
    cmp #16
    bcs vaNoMem             // End of MCT
    jmp vaContigLoop

vaSearchReset:
    // Restore pointer and continue search
    // VmmOffHi is the raw block index (0-15); reconstruct actual MCT page address
    lda #>VmmMctBase
    clc
    adc VmmOffHi
    sta PrintPtrHi
    ldy VmmOffLo
    iny
    bne vaSearchLoop
    inc PrintPtrHi
    inc TempLo
    jmp vaBlockLoop

vaZeroErr:
    lda #VMM_ERR_INVALID
    rts
vaNoMem:
    lda #VMM_ERR_NOMEM
    rts

vaCommitAlloc:
    // Mark pages in MCT.
    // Start page = PAGE_HEAD, Tail pages = PAGE_TAIL

    // Restore start position; reconstruct MCT page addr from block index
    lda #>VmmMctBase
    clc
    adc VmmOffHi
    sta PrintPtrHi
    ldy VmmOffLo
    
    lda #PAGE_HEAD
    sta (PrintPtrLo), y
    
    ldx TempHi
    dex                     // One page already marked
    beq vaDoneCommit
    
vaMarkTail:
    iny
    bne vaDoMark
    inc PrintPtrHi
vaDoMark:
    lda #PAGE_TAIL
    sta (PrintPtrLo), y
    dex
    bne vaMarkTail

vaDoneCommit:
    // Calculate returning segment: (GlobalPageIndex * 256)
    // GlobalPageIndex = (VmmOffHi * 256) + VmmOffLo
    // Since 1 page = $0100 paragraphs, Segment = GlobalPageIndex * $0100
    // SegmentLo = 0, SegmentHi = GlobalPageIndex (low 8 bits)
    // Actually, Segment is 20-bit in effect, but we return a 16-bit paragraph pointer.
    // 16MB = $000000 to $FFFFFF. Segment = Addr >> 4.
    // Page 0 (Addr $0000) -> Seg $0000
    // Page 1 (Addr $1000) -> Seg $0100
    // Page N (Addr N*$1000) -> Seg N*$0100
    // GlobalPageIndex N = (Block * 256) + Offset
    // Segment = N * $0100 = (Block * $010000) + (Offset * $0100)
    // VmmSegLo = 0
    // VmmSegHi = VmmOffLo (Offset within 256-byte block)
    // Wait, the upper 8 bits of the segment are also needed for 16MB.
    // DOS segments are 16-bit, so they max at $FFFF (1MB).
    // To support 16MB, we must use 24-bit segments or a different model.
    // PROJECT DECISION: We will use the VmmSegLo/Hi as the *bank-relative* segment,
    // and the VMM will handle the bank switching. Or, we treat Segment as a 24-bit value.
    // Given include/vmm.inc: VmmSegLo/Hi are $2E/$2F.
    // We will return: VmmSegLo = 0, VmmSegHi = VmmOffLo.
    // And we need another ZP to hold the Bank/Upper bits.
    
    lda #0
    sta VmmSegLo
    lda VmmOffLo
    sta VmmSegHi
    // For 16MB, VmmOffHi (0-15) is the bank index (64K units).
    // Let's store it in a new ZP: VmmBank = $32
    lda VmmOffHi
    sta VmmBank
    
    lda #VMM_SUCCESS
    rts

// --- vmmFree ---
// Frees a previously allocated block.
// Input: VmmSegHi = Page index low, VmmBank = Page index high (Bank)
vmmFree:
    lda vmmInitialized
    bne vfInitOk
    lda #VMM_ERR_INVALID
    rts
vfInitOk:
    // Convert Segment to MCT pointer
    lda #>VmmMctBase
    clc
    adc VmmBank
    sta PrintPtrHi
    lda #<VmmMctBase
    sta PrintPtrLo
    ldy VmmSegHi            // Offset within 256-byte block
    
    lda (PrintPtrLo), y
    cmp #PAGE_HEAD
    bne vfError             // Not a start of a block
    
vfFreeLoop:
    lda #PAGE_FREE
    sta (PrintPtrLo), y
    iny
    bne vfCheckNext
    inc PrintPtrHi
vfCheckNext:
    // Stop if we hit end of MCT or a non-tail page
    lda PrintPtrHi
    cmp #>(VmmMctBase + $1000)
    bcs vfDone
    
    lda (PrintPtrLo), y
    cmp #PAGE_TAIL
    beq vfFreeLoop
    
vfDone:
    lda #VMM_SUCCESS
    rts
vfError:
    lda #VMM_ERR_INVALID
    rts

// --- vmmReadByte ---
// Reads a byte from DOS Seg:Off.
// Physical Address = (Seg << 4) + Off
// Input:  VmmSegLo/Hi, VmmOffLo/Hi
// Output: A = data byte
vmmReadByte:
    cld
    lda vmmInitialized
    bne vrbInitOk
    lda #0                  // Return 0 if not initialized
    rts
vrbInitOk:
    jsr vmmComputeAddress   // Compute REU address and bank
    
    // Set C64 target to a temp location (using a ZP scratch for speed)
    lda #<vmmTempByte
    sta REU_C64_ADDR_L
    lda #>vmmTempByte
    sta REU_C64_ADDR_H
    
    // Set transfer length to 1 byte
    lda #1
    sta REU_LEN_L
    lda #0
    sta REU_LEN_H
    
    // Execute Fetch (REU -> C64)
    lda #REU_CMD_FETCH
    sta REU_COMMAND
    
    lda vmmTempByte         // Return the fetched byte
    rts

// --- vmmWriteByte ---
// Writes a byte to DOS Seg:Off.
// Input:  A = byte to write, VmmSegLo/Hi, VmmOffLo/Hi
vmmWriteByte:
    cld
    sta vmmTempByte         // Save data to write
    lda vmmInitialized
    bne vwbInitOk
    rts                     // Silently ignore write if not initialized
vwbInitOk:
    jsr vmmComputeAddress
    
    lda #<vmmTempByte
    sta REU_C64_ADDR_L
    lda #>vmmTempByte
    sta REU_C64_ADDR_H
    
    lda #1
    sta REU_LEN_L
    lda #0
    sta REU_LEN_H
    
    // Execute Stash (C64 -> REU)
    lda #REU_CMD_STASH
    sta REU_COMMAND
    rts

// --- vmmComputeAddress [Private] ---
// Computes 20-bit REU address from 16-bit Seg and 16-bit Off.
// Result: REU_REU_ADDR_L/H and REU_REU_BANK set.
//
// Calculation: Address = (Seg << 4) + Off
vmmComputeAddress:
    // Preserve scratch registers and Y
    tya
    pha
    lda TempLo
    pha
    lda TempHi
    pha

    // 1. Calculate base address bits (Seg << 4)
    // Low byte: (SegLo << 4)
    lda VmmSegLo
    asl
    asl
    asl
    asl
    sta TempLo              // TempLo = base Addr_L
    
    // Middle byte: (SegLo >> 4) | (SegHi << 4)
    lda VmmSegLo
    lsr
    lsr
    lsr
    lsr
    sta TempHi              // TempHi = (SegLo >> 4)
    
    lda VmmSegHi
    asl
    asl
    asl
    asl
    ora TempHi
    sta TempHi              // TempHi = (SegLo >> 4) | (SegHi << 4) = base Addr_H
    
    // Bank byte: (SegHi >> 4)
    lda VmmSegHi
    lsr
    lsr
    lsr
    lsr
    tay                     // Y = base Addr_B
    
    // 2. Add Offset (VmmOffHi:VmmOffLo) to the base
    lda TempLo
    clc
    adc VmmOffLo
    sta REU_REU_ADDR_L
    
    lda TempHi
    adc VmmOffHi
    sta REU_REU_ADDR_H
    
    tya                     // Base Bank
    adc #0
    sta REU_REU_BANK

    // Restore scratch registers and Y
    pla
    sta TempHi
    pla
    sta TempLo
    pla
    tay
    rts

.segment VmmData
vmmInitialized: .byte 0
vmmTempByte: .byte 0
fileScratch: .fill 90, 0    // 90 bytes: covers 79-char name + write suffix ",S,W" + rename "R:new=old" overhead
