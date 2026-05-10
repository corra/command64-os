// src/command64/path.asm
// KickAssembler v5.25 - MS-DOS 4.0 to C64 Port Path & Directory Logic
// Handles file discovery and extension appending (.prg).

.segment Path [start=$1780]

// --- findFile ---
// Checks if a file exists on disk. 
// If not found and no extension provided, tries again with .prg.
// Input:  A = low byte of name pointer
//         Y = high byte of name pointer
//         X = name length
// Output: C=0 exists, C=1 not found.
//         NamePtrLo/Hi updated to point to (possibly modified) name.
//         X = updated length.
// Clobbers: A, X, Y
findFile:
    sta NamePtrLo
    sty NamePtrHi
    stx TempLo              // Store original length
    
    // Normalize to lowercase for case-insensitive matching
    lda NamePtrLo
    ldy NamePtrHi
    ldx TempLo
    jsr normalizeName
    
    // Try finding the file with the name as-is
    jsr checkExistence
    bcc ffFound             // Found as-is!
    
    // Not found. Does it already have an extension?
    ldy #0
ffScanDot:
    cpy TempLo
    beq ffAppendPrg         // No dot found, try appending .prg
    lda (NamePtrLo), y
    cmp #'.'
    beq ffNotFound          // Already has a dot and failed, so stop
    iny
    jmp ffScanDot

ffAppendPrg:
    // Append ".prg" to the name in CommandBuffer
    ldy TempLo
    lda #'.'
    sta (NamePtrLo), y
    iny
    lda #'p'
    sta (NamePtrLo), y
    iny
    lda #'r'
    sta (NamePtrLo), y
    iny
    lda #'g'
    sta (NamePtrLo), y
    iny
    sty TempLo              // Update length
    
    // Try again with .prg
    jsr checkExistence
    bcc ffFound
    
ffNotFound:
    sec
    rts

ffFound:
    clc
    ldx TempLo              // Return updated length
    rts

// --- checkExistence ---
// Helper: Checks if file in NamePtrLo/Hi with length TempLo exists.
// Uses KERNAL OPEN then CLOSE to check for existence silently.
checkExistence:
    lda #0                  // Disable KERNAL messages
    jsr KernalSETMSG
    
    lda #2                  // File number 2
    ldx #8                  // Device 8
    ldy #0                  // Secondary address 0 (Read)
    jsr KernalSETLFS
    
    lda TempLo              // Length
    ldx NamePtrLo
    ldy NamePtrHi
    jsr KernalSETNAM
    
    jsr KernalOPEN
    
    // Carry flag is set by OPEN if file not found or drive error.
    // If it succeeded (C=0), we still need to close it.
    php                     // Save status (including carry)
    
    lda #2
    jsr KernalCLOSE
    
    plp                     // Restore status (restore Carry)
    rts
