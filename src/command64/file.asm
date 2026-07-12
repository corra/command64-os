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
// (checkDeviceReady moved to ShellExt segment below to free up space in File segment)

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
    // Stash HexValLo/Hi immediately before any clobbering calls (checkDeviceReady, etc.)
    lda HexValLo
    sta OpenMode
    lda HexValHi
    sta OpenType

    stx NamePtrLo
    sty NamePtrHi

    ldx #NamePtrLo
    jsr parsePointerDevice
    sta TargetDevice

    // Preflight: fail fast (with a specific reason) if the device is
    // missing or has no disk, instead of opening a channel with no data.
    lda TargetDevice
    jsr checkDeviceReady
    bcc foDeviceOk
    jmp foDeviceErr
foDeviceOk:

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
    lda OpenMode
    beq foSkipMode          // Read mode (default)
    
    // Append ",<type>,W" for Write (using standard unshifted ASCII characters)
    lda #','
    sta FileScratch, y
    iny
    lda OpenType            // Check if caller specified a custom file type (e.g. 'P' or 'S')
    // Validate that it is a valid file type (P, p, S, s, U, u, R, r)
    cmp #$50                // 'P'
    beq foTypeOk
    cmp #$70                // 'p'
    beq foTypeOk
    cmp #$53                // 'S'
    beq foTypeOk
    cmp #$73                // 's'
    beq foTypeOk
    cmp #$55                // 'U'
    beq foTypeOk
    cmp #$75                // 'u'
    beq foTypeOk
    cmp #$52                // 'R'
    beq foTypeOk
    cmp #$72                // 'r'
    beq foTypeOk
    
    // Default to 'S' if not specified or invalid
    lda #$53
foTypeOk:
    and #$DF                // Convert lowercase to uppercase (e.g. $73 -> $53)
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
    sta FileLenLo           // Stash for potential reopen
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

    // KERNAL OPEN's carry is NOT reliable for "file not found" on a SEQ
    // read -- the 1541 drive only reports it via the error channel (LFN
    // 15), which OPEN alone doesn't surface. Left unchecked, a read-mode
    // open of a nonexistent file silently "succeeds" here, the caller's
    // first fileRead then stores one garbage byte before the read loop's
    // own status check catches the error one byte too late, AND the
    // drive's error status (typically "62,FILE NOT FOUND") is left
    // dangling on LFN 15 for a completely unrelated later operation to
    // trip over (checkDeviceReady's own preflight, run at the start of
    // the *next* fileOpen/fileDelete/etc call, sees the stale non-"00"
    // status and reports a bogus "other drive error"). Verify via the
    // Skip read verification for write-mode opens
    lda OpenMode
    bne foSkipReadVerify

    lda TempLo               // save the handle table offset across the
    pha                       // LFN 15 round trip (readErrorChannel reuses
                               // TempLo itself for the device number)
    lda TargetDevice
    jsr readErrorChannel      // fills SourceBuf with the status string
    pla
    sta TempLo

    lda SourceBuf
    cmp #'0'
    bne foReadNotFound
    lda SourceBuf + 1
    cmp #'0'
    bne foReadNotFound       // Not "00" (e.g. "62") -> file not found or error
    
    beq foSkipReadVerify      // "00" = OK, this open found real data
foReadNotFound:
    ldx TempLo
    lda HandleTable + 1, x
    jsr KernalCLOSE
    sec
    lda #$FF
    rts

foSkipReadVerify:
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
    lda TargetDevice        // Drain the leftover error latch (see readErrorChannel)
    jsr readErrorChannel
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
    // 1. Validate handle
    sta TempLo
    stx PrintPtrLo
    sty PrintPtrHi
    
    asl
    tax
    lda HandleTable, x
    bne _handleOk
    jmp frError             // Not open
_handleOk:
    
    // 2. Set input channel
    lda HandleTable + 1, x  // Get LFN
    tax                     // X = LFN (Required by CHKIN)
    jsr KernalCHKIN
    bcc _chkinOk
    jmp frError
_chkinOk:
    
    // 3. Read loop
    lda #0
    sta KernalStatus        // Clear stale KERNAL status
    sta ReadCountLo         // Bytes read Lo
    sta ReadCountHi         // Bytes read Hi
    
frLoop:
    // Check if we reached requested count
    lda ReadCountLo
    cmp FileLenLo
    bne frDoRead
    lda ReadCountHi
    cmp FileLenHi
    beq frDoneOK            // Finished all bytes requested
    
frDoRead:
    jsr KernalChRIN         // Read char from channel
    
    pha                     // Save the character read
    jsr KernalREADST        // Check status immediately after read
    sta TempHi              // Save status in TempHi
    pla                     // Restore character
    
    ldy TempHi              // Look at status
    beq frStore             // If status is 0, normal read: store and continue
    
    tya
    and #$BF                // Mask out EOI bit (bit 6 = $40)
    bne frReadError         // Any other error bits? If yes, exit with error
    
    // EOI case: store the final byte, increment count, and then exit successfully
    ldy #0
    sta (PrintPtrLo), y
    inc ReadCountLo
    bne frDoneOK
    inc ReadCountHi
    jmp frDoneOK

frStore:
    ldy #0
    sta (PrintPtrLo), y     // Store in buffer
    
    // Advance buffer
    inc PrintPtrLo
    bne frSkipInc
    inc PrintPtrHi
frSkipInc:

    // Increment count
    inc ReadCountLo
    bne frLoop
    inc ReadCountHi
    jmp frLoop

frDoneOK:
    jsr KernalCLRCHN        // Reset to keyboard
    
    // Return actual bytes read
    lda ReadCountLo
    sta HexValLo
    lda ReadCountHi
    sta HexValHi
    
    clc                     // Success status
    rts

frReadError:
    jsr KernalCLRCHN        // Reset to keyboard
    
    // Return actual bytes read so far
    lda ReadCountLo
    sta HexValLo
    lda ReadCountHi
    sta HexValHi
    
    sec                     // Error status
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
    // 1. Validate handle
    sta TempLo
    stx PrintPtrLo
    sty PrintPtrHi
    
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
    sta KernalStatus        // Clear stale KERNAL status
    sta WriteCountLo         // Bytes written Lo
    sta WriteCountHi         // Bytes written Hi
    
fwLoop:
    // Check if we reached requested count
    lda WriteCountLo
    cmp FileLenLo
    bne fwDoWrite
    lda WriteCountHi
    cmp FileLenHi
    beq fwDone              // Finished all bytes requested
    
fwDoWrite:
    jsr KernalREADST
    bne fwDone              // Status non-zero? (Error)
    
    ldy #0
    lda (PrintPtrLo), y     // Get char from buffer
    jsr KernalChROUT        // Write char to channel
    
    // Advance buffer
    inc PrintPtrLo
    bne fwSkipInc
    inc PrintPtrHi
fwSkipInc:

    // Increment count
    inc WriteCountLo
    bne fwLoop
    inc WriteCountHi
    jmp fwLoop

fwDone:
    jsr KernalCLRCHN        // Reset to screen
    
    // Return actual bytes written
    lda WriteCountLo
    sta HexValLo
    lda WriteCountHi
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
    
    // 4. SETNAM+SETLFS+OPEN+CHKIN+drain+CLOSE: A=length (from X above).
    // The Scratch command's result (e.g. "01,FILES SCRATCHED,00,00") is only
    // available by reading LFN 15 after OPEN — OPEN's own carry only reports
    // the KERNAL-level handshake, not the DOS command result. sendSA15Command
    // reads it before closing so it can't linger and confuse the next
    // checkDeviceReady call.
    txa                     // Length was in X
    jsr sendSA15Command
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
    
    // 6. SETNAM+SETLFS+OPEN+CHKIN+drain+CLOSE: A=length (from X above).
    // Reads the Rename command's result before closing — see the matching
    // comment in fileDelete above for why this can't be skipped.
    txa                     // Length was in X
    jsr sendSA15Command
    rts

frDeviceErr:
    sec                     // A already holds the checkDeviceReady status code
    rts

TargetDevice:
    .byte 0

// CdrDevice and CdrRetried moved to ShellExt segment below to free up space in File segment

// File's fixed $0D00 window (packed tightly against the fixed $1000 ApiStub
// jump table) has no slack left, so these live in ShellExt instead — same
// reasoning as aptRelocate in loader.asm. JSR works fine across segments.
.segment ShellExt

CdrDevice:
    .byte 0
CdrRetried:
    .byte 0

FileLenLo:
    .byte 0
FileLenHi:
    .byte 0

ReadCountLo:
    .byte 0
ReadCountHi:
    .byte 0
WriteCountLo:
    .byte 0
WriteCountHi:
    .byte 0
IoBufPtrLo:
    .byte 0
IoBufPtrHi:
    .byte 0

SaveOffset:
    .byte 0

OpenMode:
    .byte 0
OpenType:
    .byte 0

L15Device:
    .byte 0

// --- ensureL15Open ---
// Ensures LFN 15 is open on the specified device. If LFN 15 is already open
// on a different device, it closes it first before reopening.
// Input:  A = device number
// Output: None (LFN 15 open on device)
// Clobbers: None (Preserves A, X, Y)
ensureL15Open:
    cmp L15Device
    beq el15Done
    
    pha
    txa
    pha
    tya
    pha
    
    lda L15Device
    beq el15SkipClose
    
    lda #15
    jsr KernalCLOSE
    
el15SkipClose:
    // Update active device
    tsx
    lda $103, x             // Get stashed target device from stack (A is at offset $103 on stack after 3 pushes)
    sta L15Device
    
    lda #0                  // No filename
    ldy #0
    jsr KernalSETNAM
    
    lda #15
    ldx L15Device
    ldy #15
    jsr KernalSETLFS
    jsr KernalOPEN
    
    pla
    tay
    pla
    tax
    pla
el15Done:
    rts

// --- checkDeviceReady ---
// Verifies a device is present on the IEC bus and has a disk ready.
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
    lda CdrDevice
    jsr ensureL15Open

    ldx #15
    jsr KernalCHKIN
    bcs cdrNoDevice         // Device not present or not open

    jsr KernalChRIN         // Status digit 1 (tens)
    sta TempLo
    jsr KernalChRIN         // Status digit 2 (units)
    sta TempHi

    // Drain remainder of the status channel line so no pending bytes block next queries
cdrDrainLoop:
    jsr KernalREADST
    bne cdrDrainDone        // EOI or error -> nothing more to read
    jsr KernalChRIN
    cmp #$0D                // PETSCII Carriage Return
    bne cdrDrainLoop
cdrDrainDone:
    jsr KernalCLRCHN

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

cdrNoDevice:
    lda #1
    sec
    rts

// --- readErrorChannel ---
// Reads and clears the device's command/error channel (LFN 15). The 1541
// (and compatible drives) latch the result of the last DOS operation there
// until it is read; if nothing ever reads it, the *next* unrelated
// checkDeviceReady preflight reads this stale message instead of a fresh
// status, misreports it as "other drive error", and blocks an otherwise
// healthy device. Call this right after any operation that can leave a
// fresh error/result on the channel (a failed OPEN of a data file, or a
// completed S0:/R0: command) so nothing is left for the next caller to trip
// over. Opens LFN 15 itself — do not call this when 15 is already open
// (e.g. mid S0:/R0: — see drainOpenErrorChannel for that case).
// Input:  A = device number
// Output: SourceBuf = null-terminated status string (up to 39 chars)
//         Carry: 0 = read ok, 1 = device didn't respond to OPEN
// Clobbers: A, X, Y
readErrorChannel:
    jsr ensureL15Open
    
    ldx #15
    jsr KernalCHKIN
    bcs recError
    
    jsr drainOpenErrorChannel
    clc
    rts

recError:
    lda #0
    sta SourceBuf
    lda #1                  // Matches checkDeviceReady's "no device" code
    sec
    rts

// --- drainOpenErrorChannel ---
// Reads the status string from an *already open and CHKIN'd* LFN 15 into
// SourceBuf, then CLRCHNs. Does not OPEN or CLOSE 15 — used by fileDelete/
// fileRename, which already have 15 open to issue the S0:/R0: command
// itself and just need to read its result before closing it.
// Output: SourceBuf = null-terminated status string (up to 39 chars)
// Clobbers: A, Y
drainOpenErrorChannel:
    ldy #0
docLoop:
    jsr KernalREADST
    bne docDone              // EOI or error — nothing more to read
    jsr KernalChRIN
    cmp #PetCr
    beq docDone
    sta SourceBuf, y
    iny
    cpy #39
    bne docLoop
docDone:
    lda #0
    sta SourceBuf, y
    jsr KernalCLRCHN
    rts

// --- sendSA15Command ---
// Shared tail for any command-channel operation: SETNAM the command already
// staged in FileScratch, SETLFS to LFN/SA 15 on TargetDevice, OPEN, read the
// drive's response via drainOpenErrorChannel (see its header for why this
// can't be skipped), then CLOSE. Used by fileDelete/fileRename (which stage
// "S0:"/"R0:" commands) and dosSendCommand (which stages the caller's raw
// command string) so the open/write/read-result pattern lives in one place.
// Input:  A = command length in FileScratch
//         TargetDevice = device number
// Output: SourceBuf = null-terminated drive response string
//         Carry: 0 = success, 1 = error (A = status code, 3 = other drive error)
// Clobbers: A, X, Y
sendSA15Command:
    sta SaveOffset          // Store command length
    
    lda TargetDevice
    jsr ensureL15Open
    
    ldx #15
    jsr KernalCHKOUT
    bcs sscError
    
    ldy #0
sscWriteLoop:
    cpy SaveOffset
    beq sscWriteDone
    lda FileScratch, y
    jsr KernalChROUT
    iny
    jmp sscWriteLoop
    
sscWriteDone:
    jsr KernalCLRCHN
    
    ldx #15
    jsr KernalCHKIN
    bcs sscError
    
    jsr drainOpenErrorChannel
    clc
    rts

sscError:
    lda #3
    sec
    rts

// --- dosSendCommand ---
// DOS_SEND_COMMAND primitive: sends an arbitrary command-channel string to a
// drive unmodified (no ",<type>,W" style wrapping/mangling, unlike fileOpen)
// and returns the drive's actual response text to the caller. This is the
// general-purpose sibling of fileDelete/fileRename's S0:/R0: commands —
// intended for callers like format's "N:name,id" that need the raw drive
// response rather than a generic pass/fail.
// Input:  X/Y = Pointer to command string (null-terminated), optionally
//               prefixed with "<dev>:" per the parsePointerDevice convention
//               (defaults to CurrentDevice if absent)
//         PrintPtrLo/Hi = Pointer to caller-supplied output buffer (must
//               hold at least 40 bytes, matching SourceBuf's max length)
// Output: Caller's buffer = null-terminated drive response string
//         Carry: 0 = success (transport-level; the drive may still have
//               reported an error in the response text), 1 = error
// Clobbers: A, X, Y, TargetDevice, NamePtrLo/Hi, TempLo/Hi, FileScratch,
//           SourceBuf
dosSendCommand:
    stx NamePtrLo
    sty NamePtrHi

    // The caller's output-buffer pointer arrives in PrintPtrLo/Hi, but
    // normalizeName below uses PrintPtrLo/Hi as its own working pointer and
    // will clobber it — stash it in HexValLo/Hi (untouched by everything
    // else in this call chain) and restore it before the response is
    // copied out.
    lda PrintPtrLo
    sta HexValLo
    lda PrintPtrHi
    sta HexValHi

    ldx #NamePtrLo
    jsr parsePointerDevice
    sta TargetDevice

    lda TargetDevice
    jsr checkDeviceReady
    bcs dscDeviceErr

    // Stage the caller's command string in FileScratch, unmodified apart
    // from the same shifted->unshifted normalization S0:/R0: get.
    ldy #0
dscCopyLoop:
    lda (NamePtrLo), y
    beq dscCopyDone
    sta FileScratch, y
    iny
    jmp dscCopyLoop
dscCopyDone:
    tya
    tax                     // X = command length
    lda #<FileScratch
    ldy #>FileScratch
    jsr normalizeName

    txa                     // Length was in X
    jsr sendSA15Command

    // Restore the caller's output-buffer pointer clobbered by normalizeName
    // above, needed by both the success and error paths below.
    lda HexValLo
    sta PrintPtrLo
    lda HexValHi
    sta PrintPtrHi
    bcs dscError

    // Copy the drive's response from SourceBuf into the caller's buffer.
    ldy #0
dscCopyOut:
    lda SourceBuf, y
    sta (PrintPtrLo), y
    beq dscCopyOutDone
    iny
    jmp dscCopyOut
dscCopyOutDone:
    clc
    rts

dscError:
    pha                     // Preserve sendSA15Command's status code
    ldy #0
    lda #0
    sta (PrintPtrLo), y     // No response text on a transport-level failure
    pla
    sec
    rts

dscDeviceErr:
    sec                     // A already holds the checkDeviceReady status code
    rts
