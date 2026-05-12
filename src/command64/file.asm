// src/command64/file.asm
// KickAssembler v5.25 - MS-DOS 4.0 File System Module
// Manages Handle Table and C64 KERNAL File I/O.

.segment File [start=$1E00]

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
//         HexValLo = Access Mode (0=Read, 1=Write)
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
    
    // 2. Prepare filename in FileScratch
    ldy #0
foCopyLoop:
    lda (NamePtrLo), y
    beq foCopyDone
    sta FileScratch, y
    iny
    jmp foCopyLoop
foCopyDone:
    // Normalize filename in FileScratch
    tya                     // Y holds string length from copy loop
    tax                     // X = string length for normalizeName
    lda TempLo              // Save handle table offset (clobbered by normalizeName)
    pha
    
    lda #<FileScratch       // A = string pointer low
    ldy #>FileScratch       // Y = string pointer high
    jsr normalizeName
    
    pla
    sta TempLo              // Restore handle table offset
    // Note: normalizeName returns with Y = string length, which is required below.

    // Check mode
    lda HexValLo
    beq foSkipMode          // Read mode (default)
    
    // Append ",S,W" for Write
    lda #','
    sta FileScratch, y
    iny
    lda #'S'
    sta FileScratch, y
    iny
    lda #','
    sta FileScratch, y
    iny
    lda #'W'
    sta FileScratch, y
    iny
    
foSkipMode:
    // 3. Prepare KERNAL SETNAM
    tya                     // Filename length
    ldx #<FileScratch
    ldy #>FileScratch
    jsr KernalSETNAM
    
    ldx TempLo
    lda HandleTable + 1, x  // A = LFN
    tay                     // Y = LFN (use LFN as secondary address for uniqueness)
    ldx #8                  // X = Device 8
    jsr KernalSETLFS
    
    jsr KernalOPEN
    bcs foError             // KERNAL error (e.g., file not found)
    
    // 4. Mark handle as open
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
    
    stx TempLo              // Save table offset; KernalCLOSE clobbers X
    lda HandleTable + 1, x  // Get LFN
    jsr KernalCLOSE

    ldx TempLo              // Restore table offset
    lda #0
    sta HandleTable, x      // Mark slot as free
    
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
    tax                     // X = LFN (Required by CHKIN)
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

// --- fileWrite ---
// Writes bytes to an open file.
// Input:  A = Handle
//         X/Y = Destination Buffer Pointer
//         HexValLo/Hi = Number of bytes to write
// Output: HexValLo/Hi = Number of bytes actually written
//         Carry: 0=Success, 1=Error
fileWrite:
    sta TempLo              // Save handle temporarily
    stx PrintPtrLo          // Reuse PrintPtr for buffer
    sty PrintPtrHi
    
    // 1. Validate handle
    lda TempLo
    asl
    tax
    lda HandleTable, x
    beq fwError             // Not open
    
    // 2. Set output channel
    lda HandleTable + 1, x  // Get LFN
    tax                     // X = LFN (Required by CHKOUT)
    jsr KernalCHKOUT
    bcs fwError
    
    // 3. Write loop
    lda #0
    sta TempLo              // Bytes written Lo
    sta TempHi              // Bytes written Hi
    
fwLoop:
    // Check if we reached requested count
    lda TempLo
    cmp HexValLo
    bne fwDoWrite
    lda TempHi
    cmp HexValHi
    beq fwDone              // Finished all bytes requested
    
fwDoWrite:
    ldy #0
    lda (PrintPtrLo), y     // Get char from buffer
    jsr KernalChROUT        // Write char to channel
    
    jsr KernalREADST
    bne fwDone              // Status non-zero? (Error)
    
    // Advance buffer
    inc PrintPtrLo
    bne fwSkipInc
    inc PrintPtrHi
fwSkipInc:

    // Increment count
    inc TempLo
    bne fwLoop
    inc TempHi
    jmp fwLoop

fwDone:
    jsr KernalCLRCHN        // Reset to screen
    
    // Return actual bytes written
    lda TempLo
    sta HexValLo
    lda TempHi
    sta HexValHi
    
    clc
    rts

fwError:
    sec
    rts

// --- fileDelete ---
// Deletes a file from disk using the "Scratch" command.
// Input:  X/Y = Pointer to filename (null-terminated)
// Output: Carry: 0=Success, 1=Error
fileDelete:
    stx NamePtrLo
    sty NamePtrHi
    
    // 1. Prepare "S:" in FileScratch
    lda #'S'
    sta FileScratch
    lda #':'
    sta FileScratch + 1
    
    // 2. Append filename
    ldy #0
fdCopyLoop:
    lda (NamePtrLo), y
    beq fdCopyDone
    sta FileScratch + 2, y
    iny
    jmp fdCopyLoop
fdCopyDone:
    // Total length = Y + 2
    tya
    clc
    adc #2
    tay                     // Y = Total length
    
    // 3. Normalize filename (starting from index 2)
    // We can just normalize the whole "S:filename" string
    tya
    tax                     // X = Total length
    lda #<FileScratch
    ldy #>FileScratch
    jsr normalizeName
    
    // 4. SETNAM: A=length, X/Y=pointer
    txa                     // Length was in X
    ldx #<FileScratch
    ldy #>FileScratch
    jsr KernalSETNAM
    
    // 5. SETLFS: A=LFN(15), X=Device(8), Y=Secondary(15)
    lda #15                 // LFN 15 is standard for command channel
    ldx #8                  // Device 8
    ldy #15                 // Secondary 15 is command channel
    jsr KernalSETLFS
    
    // 6. OPEN and CLOSE
    jsr KernalOPEN
    bcs fdError
    
    lda #15
    jsr KernalCLOSE
    clc
    rts

fdError:
    lda #15
    jsr KernalCLOSE         // Ensure channel is closed even on error
    sec
    rts
