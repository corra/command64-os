// src/command64/file.asm
// KickAssembler v5.25 - MS-DOS 4.0 File System Module
// Manages Handle Table and C64 KERNAL File I/O.

.segment File [start=$1C00]

// --- fileInit ---
// Initializes the Handle Table by clearing all entries.
// Each entry is 2 bytes: [Status, LFN]
// We pre-assign LFNs 2-9 to handles 0-7 to avoid channel conflicts.
fileInit:
    lda #0
    ldx #0
fiLoop:
    sta HandleTable, x      // Status = 0 (Free)
    inx
    
    // Assign LFN: Handle Index + 2
    txa
    lsr                     // Get handle index (x/2)
    clc
    adc #2
    sta HandleTable, x      // Store pre-assigned LFN
    inx
    
    lda #0                  // Reset A to 0 for next status byte
    cpx #(MAX_HANDLES * 2)
    bne fiLoop
    rts

// --- fileOpen ---
// Opens a file on disk.
// Input:  X/Y = Pointer to filename (null-terminated)
// Output: A = Handle (0-7) or $FF on error
//         Carry: 0=Success, 1=Error
fileOpen:
    stx NamePtrLo
    sty NamePtrHi
    
    // 1. Find a free handle
    ldx #0
foFindLoop:
    lda HandleTable, x      // Get status
    beq foFoundFree
    inx
    inx
    cpx #(MAX_HANDLES * 2)
    bne foFindLoop
    
    sec                     // No free handles
    lda #$FF
    rts

foFoundFree:
    stx TempLo              // Save table offset
    
    // 2. Prepare KERNAL OPEN
    // We need the filename length
    ldy #0
foLenLoop:
    lda (NamePtrLo), y
    beq foGotLen
    iny
    jmp foLenLoop
foGotLen:
    tya                     // Filename length
    ldx NamePtrLo
    ldy NamePtrHi
    jsr KernalSETNAM
    
    ldx TempLo
    lda HandleTable + 1, x  // Get pre-assigned LFN
    sta TempHi              // Store LFN for later
    
    tax                     // X = LFN
    lda #8                  // Device 8
    ldy #2                  // Secondary address (2 is standard for generic data)
    jsr KernalSETLFS
    
    jsr KernalOPEN
    bcs foError             // KERNAL error (e.g., file not found)
    
    // Check if OPEN actually succeeded (Disk status)
    // On C64, OPEN can return C=0 but the drive can still have an error.
    // However, for DOS MVP, we'll rely on C=0 for now.
    
    // 3. Mark handle as open
    ldx TempLo
    lda #1                  // Status = Open
    sta HandleTable, x
    
    // Return handle index (offset / 2)
    txa
    lsr
    clc                     // Success
    rts

foError:
    sec
    lda #$FF
    rts

// --- fileClose ---
// Closes an open file.
// Input:  A = Handle
// Output: Carry: 0=Success, 1=Error
fileClose:
    asl                     // handle index to offset
    tax
    lda HandleTable, x      // Get status
    beq fcError             // Not open
    
    lda HandleTable + 1, x  // Get LFN
    jsr KernalCLOSE
    
    // Mark as free
    asl                     // Handle is still in A? No, A was LFN. 
                            // Need to save X.
    lda #0
    sta HandleTable, x
    
    clc
    rts

fcError:
    sec
    rts

// --- fileRead ---
// Reads bytes from an open file.
// Input:  A = Handle
//         X/Y = Destination Buffer Pointer
//         HexValLo/Hi = Number of bytes to read (passed via include/command64.inc)
// Output: HexValLo/Hi = Number of bytes actually read
//         Carry: 0=Success, 1=Error
fileRead:
    sta TempLo              // Save handle temporarily
    stx PrintPtrLo          // Reuse PrintPtr for buffer
    sty PrintPtrHi
    
    // 1. Validate handle
    lda TempLo
    asl
    tax
    lda HandleTable, x
    beq frError             // Not open
    
    // 2. Set input channel
    lda HandleTable + 1, x  // Get LFN
    jsr KernalCHKIN
    bcs frError
    
    // 3. Read loop
    lda #0
    sta TempLo              // Bytes read Lo
    sta TempHi              // Bytes read Hi
    
frLoop:
    // Check if we reached requested count
    lda TempLo
    cmp HexValLo
    bne frDoRead
    lda TempHi
    cmp HexValHi
    beq frDone              // Finished all bytes requested
    
frDoRead:
    jsr KernalREADST
    bne frDone              // Status non-zero? (EOF or Error)
    
    jsr KernalChRIN         // Read char from channel
    
    ldy #0
    sta (PrintPtrLo), y     // Store in buffer
    
    // Advance buffer
    inc PrintPtrLo
    bne frSkipInc
    inc PrintPtrHi
frSkipInc:

    // Increment count
    inc TempLo
    bne frLoop
    inc TempHi
    jmp frLoop

frDone:
    jsr KernalCLRCHN        // Reset to keyboard
    
    // Return actual bytes read
    lda TempLo
    sta HexValLo
    lda TempHi
    sta HexValHi
    
    clc
    rts

frError:
    sec
    rts
