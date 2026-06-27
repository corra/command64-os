// src/external/label/label.asm
// C64 port of MS-DOS LABEL.COM (non-interactive mode)
// Sets the disk volume label via CBM DOS direct access commands.
//
// Invocation: LABEL <new-label>  (1-16 characters)
//
// Protocol flow:
//   1. Open command channel (LFN 15, SA 15)
//   2. Open raw buffer channel (LFN 2, SA 2, name "#")
//   3. Send "I\r"             — Initialize drive
//   4. Send "U1 2 0 18 0\r"  — Block Read T18/S0 into drive buffer
//   5. Send "B-P 2 144\r"    — Set block pointer to volume name offset
//   6. Write 16 name bytes to data channel (padded with $A0)
//   7. Send "U2 2 0 18 0\r"  — Block Write drive buffer back to T18/S0
//   8. Close data channel, read drive status, close command channel
//
// CRITICAL: All drive command strings use explicit byte literals ($49, $55,
// $42, $50 etc.) rather than uppercase character literals ('I', 'U', 'B', 'P').
// Under .encoding "petscii_mixed", uppercase source literals assemble to shifted
// PETSCII ($C9, $D5, $C2, $D0), which the 1541 command parser rejects with
// "31,syntax error". Explicit bytes bypass this encoding entirely.
//
// Drive parameters (track, sector, drive number) are sent as space-separated
// ASCII decimal digit characters, not as raw binary bytes, as required by the
// 1541 text-based command protocol.

#import "../../../include/command64.inc"

.encoding "petscii_mixed"

// Zero-page scratch ($70 is free for external program use)
.label ArgIdx = $70     // CommandBuffer index of first label char
.label SavedDevice = $71 // Saved device number

// Drive protocol constants
.const CMD_CHANNEL  = 15    // CBM DOS command channel (always LFN/SA 15)
.const DATA_CHANNEL = 2     // Direct buffer channel LFN/SA
.const VOL_NAME_LEN = 16    // Volume name field length (PETSCII, padded $A0)
                            // BAM occupies T18/S0 bytes 4..143 (35 tracks x 4).
                            // Volume name follows immediately at bytes 144..159.

* = $2000 "LabelEntry"

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------
start:
    // Save original CurrentDevice
    lda CurrentDevice
    sta SavedDevice

    // The shell sets ParsePos ($63) to the CommandBuffer index of the first
    // character of the typed command ("label ..."). Scan past that token
    // to find where the label argument begins.
    ldy ParsePos

    // Advance Y past the command name token, stopping at space or null.
    // 6502 BEQ/BNE only reach ±127 bytes; use JMP for distant error targets.
skipToken:
    lda CommandBuffer, y
    bne notTokenNull        // non-null char: check if it's the delimiter
    jmp noArgErr            // null before any space → no argument given
notTokenNull:
    iny
    cmp #' '
    bne skipToken           // not a space → still inside the command name token

    // Skip any spaces between the command name and the label argument.
skipSpaces:
    lda CommandBuffer, y
    cmp #' '
    bne endSpaces           // non-space: either null or first arg char
    iny
    jmp skipSpaces

endSpaces:
    cmp #0                  // null after all the spaces → nothing to set
    beq labelNoArg
    
    // Parse device prefix
    jsr parseDevicePrefix
    bcc labelNoPrefix
    sta CurrentDevice
    
    // Skip spaces after prefix
skipSpacesPostPrefix:
    lda CommandBuffer, y
    cmp #' '
    bne checkNullPostPrefix
    iny
    jmp skipSpacesPostPrefix
checkNullPostPrefix:
    cmp #0
    bne labelNoPrefix
    
labelNoArg:
    jmp noArgErr

labelNoPrefix:
    // -----------------------------------------------------------------------
    // Count label characters; enforce maximum length of 16.
    // -----------------------------------------------------------------------
countStart:
    sty ArgIdx              // save CommandBuffer index of label start
    ldx #0
countChars:
    lda CommandBuffer, y
    beq countDone           // null terminator — done (forward ≈9 bytes, in range)
    inx
    iny
    cpx #17                 // 17 chars without null → exceeds 16-char max
    bne countChars
    jmp tooLongErr

countDone:
    // X holds char count (1–16 guaranteed by the checks above).

    // -----------------------------------------------------------------------
    // Copy label into local buffer; pad remaining bytes with $A0.
    // -----------------------------------------------------------------------
    ldy ArgIdx
    ldx #0
copyLabel:
    lda CommandBuffer, y
    beq padLabel            // null terminator: pad remainder (forward ≈15 bytes)
    sta labelBuf, x
    inx
    iny
    cpx #VOL_NAME_LEN
    bne copyLabel
    jmp openChannels        // exactly 16 chars: no padding needed

padLabel:
    lda #$A0                // PETSCII shifted space (standard CBM name padding)
    sta labelBuf, x
    inx
    cpx #VOL_NAME_LEN
    bne padLabel

    // -----------------------------------------------------------------------
    // Open the CBM DOS command channel (LFN 15, secondary address 15).
    // -----------------------------------------------------------------------
openChannels:
    lda #0                  // filename length = 0 (no filename for cmd channel)
    jsr KernalSETNAM
    lda #CMD_CHANNEL
    ldx CurrentDevice
    ldy #CMD_CHANNEL
    jsr KernalSETLFS
    jsr KernalOPEN
    bcc openCmdOk
    jmp openErr             // carry set = device not present / error
openCmdOk:

    // -----------------------------------------------------------------------
    // Initialize drive (Send "I\r") to clear any stuck buffers before opening data channel.
    // -----------------------------------------------------------------------
    ldx #CMD_CHANNEL
    jsr KernalCHKOUT
    ldx #0
sendInitLoop:
    lda cmdInit, x
    beq sendInitDone
    jsr KernalChROUT
    inx
    jmp sendInitLoop
sendInitDone:
    jsr KernalCLRCHN

    // Open the raw data buffer channel (LFN 2, SA 2, filename "#").
    // The "#" filename requests a free drive RAM buffer.
    lda #1                  // filename length = 1
    ldx #<bufName
    ldy #>bufName
    jsr KernalSETNAM
    lda #DATA_CHANNEL
    ldx CurrentDevice
    ldy #DATA_CHANNEL
    jsr KernalSETLFS
    jsr KernalOPEN
    bcc openDataOk
    lda #CMD_CHANNEL        // clean up: close the command channel we already opened
    jsr KernalCLOSE
    jmp openErr
openDataOk:

    // -----------------------------------------------------------------------
    // Step 2: Send "U1:2 0 18 0\r" — Block Read T18/S0 into drive buffer.
    // -----------------------------------------------------------------------
    ldx #CMD_CHANNEL
    jsr KernalCHKOUT
    ldx #0
sendU1Loop:
    lda cmdU1, x
    beq sendU1Done
    jsr KernalChROUT
    inx
    jmp sendU1Loop
sendU1Done:
    jsr KernalCLRCHN

    // -----------------------------------------------------------------------
    // Step 3: Send "B-P:2 144\r" — Position data channel at volume name offset.
    // -----------------------------------------------------------------------
    ldx #CMD_CHANNEL
    jsr KernalCHKOUT
    ldx #0
sendBPLoop:
    lda cmdBP, x
    beq sendBPDone
    jsr KernalChROUT
    inx
    jmp sendBPLoop
sendBPDone:
    jsr KernalCLRCHN

    // -----------------------------------------------------------------------
    // Step 4: Write 16 label bytes through the data channel into drive buffer.
    // -----------------------------------------------------------------------
    ldx #DATA_CHANNEL
    jsr KernalCHKOUT
    ldx #0
writeLabel:
    lda labelBuf, x
    jsr KernalChROUT
    inx
    cpx #VOL_NAME_LEN
    bne writeLabel
    jsr KernalCLRCHN

    // -----------------------------------------------------------------------
    // Step 5: Send "U2:2 0 18 0\r" — Block Write drive buffer back to T18/S0.
    // -----------------------------------------------------------------------
    ldx #CMD_CHANNEL
    jsr KernalCHKOUT
    ldx #0
sendU2Loop:
    lda cmdU2, x
    beq sendU2Done
    jsr KernalChROUT
    inx
    jmp sendU2Loop
sendU2Done:
    jsr KernalCLRCHN

    // -----------------------------------------------------------------------
    // Close the data buffer channel (flushes drive buffer).
    // -----------------------------------------------------------------------
    lda #DATA_CHANNEL
    jsr KernalCLOSE

    // -----------------------------------------------------------------------
    // Read drive status from command channel into statusBuf.
    // Status format: "NN,message,tt,ss\r" — NN is the two-digit error code.
    // -----------------------------------------------------------------------
    ldx #CMD_CHANNEL
    jsr KernalCHKIN
    jsr KernalChRIN
    sta statusBuf           // first digit of error code
    jsr KernalChRIN
    sta statusBuf+1         // second digit of error code

    ldy #2                  // continue filling statusBuf from index 2
readStatus:
    jsr KernalREADST
    bne readStatusDone      // I/O status non-zero (EOF or error) → stop
    jsr KernalChRIN
    cmp #$0D                // carriage return = end of status line
    beq readStatusDone
    sta statusBuf, y
    iny
    cpy #38                 // guard against buffer overrun
    bne readStatus
readStatusDone:
    lda #0
    sta statusBuf, y        // null-terminate the status string
    jsr KernalCLRCHN

    // Check if the write was successful (code "00")
    lda statusBuf
    cmp #'0'
    bne closeCommandChannel
    lda statusBuf+1
    cmp #'0'
    bne closeCommandChannel

    // Write succeeded! Send "I\r" to force the drive to re-read Track 18, Sector 0
    // and sync its internal BAM cache with the disk.
    ldx #CMD_CHANNEL
    jsr KernalCHKOUT
    ldx #0
sendFinalInitLoop:
    lda cmdInit, x
    beq sendFinalInitDone
    jsr KernalChROUT
    inx
    jmp sendFinalInitLoop
sendFinalInitDone:
    jsr KernalCLRCHN

closeCommandChannel:
    lda #CMD_CHANNEL
    jsr KernalCLOSE

    // -----------------------------------------------------------------------
    // Check for "00" success code and print result.
    // -----------------------------------------------------------------------
    lda statusBuf
    cmp #'0'
    bne printDriveError
    lda statusBuf+1
    cmp #'0'
    bne printDriveError

    ldx #<okMsg
    ldy #>okMsg
    lda #DOS_PRINT_STR
    jsr $1000
    jmp labelExit

printDriveError:
    // Print the raw drive status string for diagnostics.
    ldy #0
printErrLoop:
    lda statusBuf, y
    beq printErrDone
    jsr KernalChROUT
    iny
    jmp printErrLoop
printErrDone:
    lda #$0D
    jsr KernalChROUT
    jmp labelExit

    // -----------------------------------------------------------------------
    // Error paths (argument / length / device errors)
    // -----------------------------------------------------------------------
noArgErr:
    ldx #<reqMsg
    ldy #>reqMsg
    lda #DOS_PRINT_STR
    jsr $1000
    jmp labelExit

tooLongErr:
    ldx #<lenMsg
    ldy #>lenMsg
    lda #DOS_PRINT_STR
    jsr $1000
    jmp labelExit

openErr:
    ldx #<devMsg
    ldy #>devMsg
    lda #DOS_PRINT_STR
    jsr $1000
    jmp labelExit

// --- parseDevicePrefix ---
// Parses a device prefix (8:, 9:, 10:, 11:) in CommandBuffer starting at Y.
// Output: 
//   Carry: 1 = Prefix found, target device in A, Y advanced past the prefix.
//          0 = No prefix found, Y unchanged.
//   A = Target device number (8-11), or unchanged if Carry=0.
// Clobbers: A
parseDevicePrefix:
    lda CommandBuffer, y
    cmp #'8'
    beq pdpCheck8
    cmp #'9'
    beq pdpCheck9
    cmp #'1'
    beq pdpCheck10or11
    clc                     // No match
    rts

pdpCheck8:
    iny
    lda CommandBuffer, y
    cmp #':'
    beq pdpFound8
    dey                     // Restore Y
    clc
    rts
pdpFound8:
    iny                     // Skip ':'
    lda #8
    sec
    rts

pdpCheck9:
    iny
    lda CommandBuffer, y
    cmp #':'
    beq pdpFound9
    dey                     // Restore Y
    clc
    rts
pdpFound9:
    iny                     // Skip ':'
    lda #9
    sec
    rts

pdpCheck10or11:
    iny
    lda CommandBuffer, y
    cmp #'0'
    beq pdpCheck10
    cmp #'1'
    beq pdpCheck11
    dey                     // Restore Y
    clc
    rts

pdpCheck10:
    iny
    lda CommandBuffer, y
    cmp #':'
    beq pdpFound10
    dey                     // Restore Y for ':'
    dey                     // Restore Y for '0'
    clc
    rts
pdpFound10:
    iny                     // Skip ':'
    lda #10
    sec
    rts

pdpCheck11:
    iny
    lda CommandBuffer, y
    cmp #':'
    beq pdpFound11
    dey                     // Restore Y for ':'
    dey                     // Restore Y for '1'
    clc
    rts
pdpFound11:
    iny                     // Skip ':'
    lda #11
    sec
    rts

labelExit:
    lda SavedDevice
    sta CurrentDevice
    rts

// ---------------------------------------------------------------------------
// Data
// ---------------------------------------------------------------------------

bufName:
    .byte $23               // '#': requests a free drive RAM buffer

// All command strings are encoded as explicit hex bytes to bypass the
// petscii_mixed directive's shifting of uppercase letters.

cmdInit:
    // "I\r\0" — Initialize drive
    .byte $49, $0D, $00

cmdU1:
    // "U1:2 0 18 0\r\0" — Block Read: channel 2, drive 0, track 18, sector 0
    .byte $55, $31, $3A, $32, $20, $30, $20, $31, $38, $20, $30, $0D, $00

cmdBP:
    // "B-P:2 144\r\0" — Block Pointer: channel 2, byte offset 144
    .byte $42, $2D, $50, $3A, $32, $20, $31, $34, $34, $0D, $00

cmdU2:
    // "U2:2 0 18 0\r\0" — Block Write: channel 2, drive 0, track 18, sector 0
    .byte $55, $32, $3A, $32, $20, $30, $20, $31, $38, $20, $30, $0D, $00

okMsg:
    .text "Label updated"
    .byte $0D, $00

lenMsg:
    .text "Label too long (max 16)"
    .byte $0D, $00

reqMsg:
    .text "Label name required"
    .byte $0D, $00

devMsg:
    .text "Device not present"
    .byte $0D, $00

// Runtime buffers (initialized at load time)
statusBuf:
    .fill 40, 0             // drive status response string

labelBuf:
    .fill 16, $A0           // padded volume name (16 bytes, $A0 = shifted space)
