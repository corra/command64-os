// src/command64/path.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// KickAssembler v5.25 - MS-DOS 4.0 to C64 Port Path & Directory Logic
// Handles file discovery and extension appending (.prg).

.segment Path

// --- findFile ---
// Checks if a file exists on disk. 
// If not found and no extension provided, tries again with .prg.
// Input:  A = low byte of name pointer
//         Y = high byte of name pointer
//         X = name length
// Output: C=0 exists, C=1 not found.
//         A = status code on error (1=no device, 2=no disk, 3=not found)
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

    // Try finding the file with the name as-is (after normalization)
    // Note: Automatic .prg appending removed as disk entries no longer include extensions.
    jsr checkExistence
    bcc ffFound             // Found!

ffNotFound:
    sec                     // A already holds the status code from checkExistence
    rts

ffFound:
    clc
    ldx TempLo              // Return length
    rts

// --- checkExistence ---
// Helper: Checks if file in NamePtrLo/Hi with length TempLo exists.
// Uses KERNAL OPEN then CLOSE to check for existence silently.
// Output: C=0 exists, C=1 error. On error, A = status code from checkDeviceReady
//         (1=no device, 2=no disk), or 3 if the device is ready but the file
//         itself was not found.
checkExistence:
    // Preflight: bail out before touching the real file if the device isn't
    // there or has no disk — avoids reading garbage off a channel with no
    // data behind it.
    lda CurrentDevice
    jsr checkDeviceReady
    bcs ceDeviceErr

    lda #0                  // Disable KERNAL messages
    jsr KernalSETMSG

    lda #14                 // LFN 14 — clear of handle table (2-9), dir (13), command channel (15)
    ldx CurrentDevice
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

    lda #14
    jsr KernalCLOSE

    plp                     // Restore status (restore Carry)
    bcc ceOk
    lda #3                  // Device was ready; the file itself wasn't found
    sec
ceOk:
    rts

ceDeviceErr:
    rts                     // A already holds the checkDeviceReady status code
    // checkDeviceReady itself lives in file.asm (File segment) — Path's
    // fixed $0AA0-$0B30 window is too small to also hold it.
