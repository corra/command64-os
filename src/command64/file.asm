// src/command64/file.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// KickAssembler v5.25 - MS-DOS 4.0 File System Module
// Manages Handle Table and C64 KERNAL File I/O.

.segment File

// --- checkDeviceReady ---
// Verifies a device is present on the IEC bus and has a disk ready.
// Two phases:
//   1. A pure ATN-handshake presence probe (LISTEN/UNLSN, no data phase).
//      This is essential, not cosmetic: OPEN's carry flag is NOT reliable
//      for "device not present" on its own. Empirically (verified under
//      VICE), OPEN/CHKIN can report success against a device address with
//      nothing listening, and the actual byte transfer that follows
//      (CHRIN -> the KERNAL's low-level serial bit-receive routine) then
//      spins forever waiting for a byte that will never arrive, since only
//      the initial LISTEN handshake has a bounded timeout — the data phase
//      does not. Probing with LISTEN/UNLSN alone never enters that data
//      phase, so it can't hang, and STATUS bit 7 after it reliably reports
//      whether anything answered.
//   2. Only once a device is confirmed present do we open its command/error
//      channel (secondary 15) and read the status — this is what tells us
//      "74,DRIVE NOT READY" (no disk) vs. ready, and is itself safe now
//      because a real, present drive always services its command channel
//      regardless of disk state. "73" (the DOS-version power-on banner) is
//      special: a drive reports it only on the very first status read after
//      reset, regardless of whether a disk is actually in it, so seeing it
//      does NOT confirm readiness — this routine re-queries once more in
//      that case to get the real, current status.
// Input:  A = device number to check
// Output: A = 0 ready / 1 no device / 2 no disk / 3 other drive error
//         Carry: 0 = ready, 1 = error (mirrors A<>0)
// Clobbers: A, X, Y, TempLo, TempHi
checkDeviceReady:
    pha                     // Stash device number across the presence probe
    jsr KernalLISTEN        // A = device number (still set from before the push)
    jsr KernalUNLSN
    jsr KernalREADST
    and #$80                // Bit 7 = device did not respond to LISTEN
    beq cdrPresent
    pla                     // Discard the stashed device number
    lda #1
    sec
    rts

cdrPresent:
    pla
    sta CdrDevice           // Remember device number across the status re-query
    lda #0
    sta CdrRetried

cdrQueryStatus:
    ldx CdrDevice           // Device number for SETLFS
    lda #0                  // No filename — just open the status channel
    ldy #0
    jsr KernalSETNAM

    lda #15                 // LFN 15 = command/error channel
    ldy #15                 // Secondary address 15
    jsr KernalSETLFS
    jsr KernalOPEN
    bcs cdrNoDevice         // Device answered LISTEN but OPEN still failed

    ldx #15
    jsr KernalCHKIN
    bcs cdrCloseNoDevice

    jsr KernalChRIN         // Status digit 1 (tens)
    sta TempLo
    jsr KernalChRIN         // Status digit 2 (units)
    sta TempHi

    jsr KernalCLRCHN
    lda #15
    jsr KernalCLOSE

    // "00" = OK
    lda TempLo
    cmp #'0'
    bne cdrCheck73
    lda TempHi
    cmp #'0'
    beq cdrOk

cdrCheck73:
    lda TempLo
    cmp #'7'
    bne cdrCheck74
    lda TempHi
    cmp #'3'
    bne cdrCheck74
    lda CdrRetried          // Power-on banner: re-query once for the real status
    bne cdrOk               // already retried — trust it this time
    inc CdrRetried
    jmp cdrQueryStatus

cdrCheck74:
    lda TempLo
    cmp #'7'
    bne cdrOtherErr
    lda TempHi
    cmp #'4'
    beq cdrNotReady

cdrOtherErr:
    lda #3
    sec
    rts

cdrOk:
    lda #0
    clc
    rts

cdrNotReady:
    lda #2
    sec
    rts

cdrCloseNoDevice:
    lda #15
    jsr KernalCLOSE
cdrNoDevice:
    lda #1
    sec
    rts

// --- printDeviceStatusMsg ---
// Prints the message matching a checkDeviceReady/fileOpen/fileDelete/
// fileRename/findFile error status code, without a trailing carriage return
// (callers that want one add it themselves, matching each command's existing
// error-message convention). Message strings live in shell.asm.
// Input: A = status code (1=no device, 2=no disk, anything else=generic error)
// Clobbers: A, X, Y
printDeviceStatusMsg:
    cmp #1
    beq pdsmNoDevice
    cmp #2
    beq pdsmNoDisk
    lda #<loadErrMsg
    ldy #>loadErrMsg
    jmp pdsmPrint
pdsmNoDevice:
    lda #<noDeviceMsg
    ldy #>noDeviceMsg
    jmp pdsmPrint
pdsmNoDisk:
    lda #<noDiskMsg
    ldy #>noDiskMsg
pdsmPrint:
    jsr petPrintString
    rts

// --- fileInit ---
// Initializes the Handle Table by clearing all entries.
// Each entry is 2 bytes: [Status, LFN]
// We pre-assign LFNs 2-9 to handles 0-7 to avoid channel conflicts.
fileInit:
    lda #$60                // RTS opcode — seeds UserProgStart so a bare
    sta UserProgStart        // RUN/GO with nothing loaded there yet just
                              // returns instead of executing garbage RAM.
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

    ldx #NamePtrLo
    jsr parsePointerDevice
    sta TargetDevice

    // Preflight: fail fast (with a specific reason) if the device is
    // missing or has no disk, instead of opening a channel with no data.
    lda TargetDevice
    jsr checkDeviceReady
    bcs foDeviceErr

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
    
    // Append ",<type>,W" for Write (using standard unshifted ASCII characters)
    lda #','
    sta FileScratch, y
    iny
    lda HexValHi            // Check if caller specified a custom file type (e.g. 'P' or 'S')
    bne foUseType
    lda #$50                // Default to unshifted 'P' (PRG) if not specified
foUseType:
    sta FileScratch, y
    iny
    lda #','
    sta FileScratch, y
    iny
    lda #$57                // unshifted 'W'
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
    ldx TargetDevice        // X = Target Device
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

foDeviceErr:
    sec                     // A already holds the checkDeviceReady status code
    rts

foError:
    ldx TempLo
    lda HandleTable + 1, x  // A = LFN
    jsr KernalCLOSE
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
    jsr KernalCLRCHN        // defensive: ensure channel restored if future paths reach here post-CHKIN
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
    jsr KernalCLRCHN        // defensive: ensure channel restored if future paths reach here post-CHKOUT
    sec
    rts

// --- fileDelete ---
// Deletes a file from disk using the "Scratch" command.
// Input:  X/Y = Pointer to filename (null-terminated)
// Output: Carry: 0=Success, 1=Error
fileDelete:
    stx NamePtrLo
    sty NamePtrHi

    ldx #NamePtrLo
    jsr parsePointerDevice
    sta TargetDevice

    lda TargetDevice
    jsr checkDeviceReady
    bcs fdDeviceErr

    // 1. Prepare "S0:" in FileScratch (using standard unshifted ASCII 'S')
    lda #$53                // unshifted 'S'
    sta FileScratch
    lda #'0'
    sta FileScratch + 1
    lda #':'
    sta FileScratch + 2
    
    // 2. Append filename
    ldy #0
fdCopyLoop:
    lda (NamePtrLo), y
    beq fdCopyDone
    sta FileScratch + 3, y
    iny
    jmp fdCopyLoop
fdCopyDone:
    // Total length = Y + 3
    tya
    clc
    adc #3
    tay                     // Y = Total length
    
    // 3. Normalize filename (starting from index 3 or whole string)
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
    
    // 5. SETLFS: A=LFN(15), X=Device(TargetDevice), Y=Secondary(15)
    lda #15                 // LFN 15 is standard for command channel
    ldx TargetDevice
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
    lda #3                  // Device was ready; some other drive error occurred
    sec
    rts

fdDeviceErr:
    sec                     // A already holds the checkDeviceReady status code
    rts

// --- fileRename ---
// Renames a file on disk using the "Rename" command.
// Input:  X/Y = Pointer to Old Name (null-terminated)
//         PrintPtrLo/Hi = Pointer to New Name (null-terminated)
// Output: Carry: 0=Success, 1=Error
fileRename:
    stx NamePtrLo           // Use NamePtr as temporary for Old Name
    sty NamePtrHi
    
    ldx #NamePtrLo
    jsr parsePointerDevice
    sta TargetDevice        // Resolve device from Old Name

    ldx #PrintPtrLo
    jsr parsePointerDevice  // Strip prefix from New Name if present

    lda TargetDevice
    jsr checkDeviceReady
    bcs frDeviceErr
    
    // 1. Prepare "R0:" in FileScratch (using standard unshifted ASCII 'R')
    lda #$52                // unshifted 'R'
    sta FileScratch
    lda #'0'
    sta FileScratch + 1
    lda #':'
    sta FileScratch + 2
    
    // 2. Append New Name from PrintPtrLo/Hi
    ldy #0
frCopyNew:
    lda (PrintPtrLo), y
    beq frGotNew
    sta FileScratch + 3, y
    iny
    jmp frCopyNew
frGotNew:
    // FileScratch index now at Y + 3
    
    // 3. Append "="
    lda #'='
    sta FileScratch + 3, y
    iny
    
    // 4. Append Old Name from NamePtrLo/Hi
    sty TempLo              // Save current index in FileScratch
    ldy #0
frCopyOld:
    lda (NamePtrLo), y
    beq frGotOld
    ldx TempLo
    sta FileScratch + 3, x
    inc TempLo
    iny
    jmp frCopyOld
frGotOld:
    // Total length = TempLo + 3
    lda TempLo
    clc
    adc #3
    tay                     // Y = Total length
    
    // 5. Normalize string
    tya
    tax                     // X = Total length
    lda #<FileScratch
    ldy #>FileScratch
    jsr normalizeName
    
    // 6. SETNAM: A=length, X/Y=pointer
    txa                     // Length was in X
    ldx #<FileScratch
    ldy #>FileScratch
    jsr KernalSETNAM
    
    // 7. SETLFS: A=LFN(15), X=Device(TargetDevice), Y=Secondary(15)
    lda #15                 // LFN 15 is standard for command channel
    ldx TargetDevice
    ldy #15                 // Secondary 15 is command channel
    jsr KernalSETLFS
    
    // 8. OPEN and CLOSE
    jsr KernalOPEN
    bcs frenError
    
    lda #15
    jsr KernalCLOSE
    clc
    rts

frenError:
    lda #15
    jsr KernalCLOSE         // Ensure channel is closed even on error
    lda #3                  // Device was ready; some other drive error occurred
    sec
    rts

frDeviceErr:
    sec                     // A already holds the checkDeviceReady status code
    rts

TargetDevice:
    .byte 0

CdrDevice:
    .byte 0
CdrRetried:
    .byte 0
