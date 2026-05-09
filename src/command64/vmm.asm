// src/command64/vmm.asm
// Virtual Memory Manager for C64 MS-DOS Port
// Maps 1MB DOS Address Space (Seg:Off) to C64 REU.

.segment Vmm [start=$1700]

// --- vmmInit ---
// Initializes the VMM and verifies REU presence.
// Output: A = VMM_SUCCESS or error code.
vmmInit:
    // Check if REU is present by writing to a register and reading back (if possible)
    // or just checking status bit 4 (Size) which is usually set for 512K/1MB+.
    lda REU_STATUS
    and #$10                // Size bit (1 = 512K or more)
    beq viNoReu
    
    // Initialize Memory Control Table (MCT) - clear it
    ldx #0
    lda #0
viClearMct:
    sta VmmMctBase, x
    inx
    bne viClearMct
    
    lda #VMM_SUCCESS
    rts
viNoReu:
    lda #VMM_ERR_INVALID
    rts

// --- vmmReadByte ---
// Reads a byte from DOS Seg:Off.
// Physical Address = (Seg << 4) + Off
// Input:  VmmSegLo/Hi, VmmOffLo/Hi
// Output: A = data byte
vmmReadByte:
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
    sta vmmTempByte         // Save data to write
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
// Calculation:
//   Address = (Seg * 16) + Off
//   Addr_L = (SegLo << 4) + OffLo
//   Addr_H = (SegLo >> 4) + (SegHi << 4) + OffHi + Carry
//   Bank   = (SegHi >> 4) + Carry
vmmComputeAddress:
    // Low byte
    lda VmmSegLo
    asl                     // * 2
    asl                     // * 4
    asl                     // * 8
    asl                     // * 16
    clc
    adc VmmOffLo
    sta REU_REU_ADDR_L
    php                     // Save carry from low byte addition
    
    // Middle byte
    lda VmmSegLo
    lsr
    lsr
    lsr
    lsr                     // SegLo >> 4
    sta TempLo              // Temporary storage
    
    lda VmmSegHi
    asl
    asl
    asl
    asl                     // SegHi << 4
    ora TempLo              // Combine with SegLo bits
    
    plp                     // Restore carry from low byte
    adc VmmOffHi            // Add Offset high byte + carry
    sta REU_REU_ADDR_H
    php                     // Save carry for bank
    
    // Bank byte (High 4 bits of SegHi)
    lda VmmSegHi
    lsr
    lsr
    lsr
    lsr                     // SegHi >> 4
    plp                     // Restore carry
    adc #0                  // Add carry
    sta REU_REU_BANK
    rts

.segment VmmData
vmmTempByte: .byte 0
