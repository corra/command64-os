// src/command64/shell.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// KickAssembler v5.25 - Command 64 OS shell for C64
// Core command loop: prompt, input, dispatch, built-in commands.

// --- Version Information ---
.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "2"
.const VERSION_STAGE = "15" // Build 2414 Remediation
#import "build_os.inc"


// ---------------------------------------------------------------------------
// Command Table  (loaded at $1100)
//
// Fixed-width entries: 6-byte space-padded name + 2-byte handler address.
// Stride = TABLE_ENTRY_SIZE = 8. Table walk steps X by 8 per entry.
// ---------------------------------------------------------------------------
.const TABLE_ENTRY_SIZE = 8
.const TABLE_NAME_LEN   = 6

.segment CommandTable [start=$1080]

tableCmd:
    .text "exit  "
    .word cmdExit
    .text "cls   "
    .word cmdCls
    .text "echo  "
    .word cmdEcho
    .text "load  "
    .word cmdLoad
    .text "dir   "
    .word cmdDir
    .text "ver   "
    .word cmdVer
    .text "help  "
    .word cmdHelp
    .text "type  "
    .word cmdType
    .text "copy  "
    .word cmdCopy
    .text "del   "
    .word cmdDel
    .text "erase "
    .word cmdDel
    .text "ren   "
    .word cmdRen
    .text "rename"
    .word cmdRen
    .text "drive "
    .word cmdDrive
    .text "device"
    .word cmdDrive
    .text "dev   "
    .word cmdDrive
    .text "run   "
    .word cmdRun
    .text "go    "
    .word cmdRun
    .text "set   "
    .word cmdSet
    .text "vol   "
    .word cmdVol
    .text "path  "
    .word cmdPath

tableEnd:

// ---------------------------------------------------------------------------
// Command Shell  (loaded at $1180)
// ---------------------------------------------------------------------------
.segment CommandShell [start=$1130]

// --- Entry point ---
start:
    lda $01
    and #$fe                // Clear bit 0 (LORAM = 0) -> bank out BASIC ROM
    sta $01

    lda #8
    sta CurrentDevice       // Default to device 8
    jsr vmmInit             // Initialize VMM and check for REU
    jsr fileInit            // Initialize File System (Handle Table)
    
    lda vmmInitialized
    bne siInitOk

    
    // VMM Init failed (No REU found)
    lda #<noReuMsg
    ldy #>noReuMsg
    jsr petPrintString
    // We proceed anyway for now, but external programs using VMM will fail.
    
siInitOk:
    lda vmmInitialized
    beq siSkipEnv           // No REU, no environment

    // Initialize Master Environment Block
    lda #0
    sta VmmSegLo
    lda #1                  // 256 paragraphs = 4KB = 1 page
    sta VmmSegHi
    jsr vmmAlloc
    cmp #VMM_SUCCESS
    beq siEnvOk
    
    lda #0
    sta vmmInitialized      // Allocation failed, disable VMM
    lda #<noReuMsg
    ldy #>noReuMsg
    jsr petPrintString
    jmp siSkipEnv

siEnvOk:
    lda VmmSegLo
    sta EnvSegmentLo
    lda VmmSegHi
    sta EnvSegmentHi
    
    // Zero the entire 4KB env segment to prevent garbage data from hanging env scans.
    // vmmComputeAddress clobbers Y (via TAY), so Y cannot be used as a loop counter.
    // vmmWriteByte/vmmComputeAddress do NOT clobber X, so X is the outer page counter.
    // VmmOffLo itself serves as the inner byte counter: inc+wrap at 256.
    lda #0
    sta VmmOffLo
    sta VmmOffHi
    ldx #16                 // 16 pages of 256 bytes = 4096 bytes
siZeroEnvOuter:
siZeroEnvByte:
    lda #0
    jsr vmmWriteByte        // writes 0 at VmmSeg:VmmOffHi:VmmOffLo; clobbers A and Y
    inc VmmOffLo            // advance to next byte; wraps at 256 naturally
    bne siZeroEnvByte       // loop until VmmOffLo wraps (256 bytes = 1 page)
    inc VmmOffHi            // next page
    dex
    bne siZeroEnvOuter      // repeat for all 16 pages

    lda #0
    sta VmmOffLo
    sta VmmOffHi

siSkipEnv:
    lda #$93                // PETSCII clear-screen character
    jsr KernalChROUT
    lda #$0E                // switch C64 to lowercase/uppercase character mode
    jsr KernalChROUT        // required for .text lowercase strings to display correctly

    jsr cmdVer              // Display version banner
mainLoop:
    jsr printPrompt

    jsr shellReadLine       // screen editor echoes input and advances cursor on RETURN

    jsr shellDispatch
    jmp mainLoop

// ---------------------------------------------------------------------------
// shellReadLine
// Reads characters via CHRIN into CommandBuffer until CR or 79 chars.
// Echoes each character. Writes $00 null terminator. Sets CommandLen.
// Clobbers: A, Y
// ---------------------------------------------------------------------------
shellReadLine:
    ldy #0
rlReadLoop:
    tya                     // KernalGetIn may clobber Y; preserve it
    pha
rlPoll:
    jsr KernalGetIn         // wait for char without screen editor (raw input)
    beq rlPoll              // GETIN is non-blocking; loop until key pressed

    tax                     // save character to X (KernalChROUT preserves X)
    pla
    tay                     // restore Y before any branching
    txa                     // restore character to A

    cmp #PetCr
    beq rlDoneRead

    cmp #PetDel             // INST/DEL key ($14) — backspace
    bne rlStoreChar
    tya
    beq rlReadLoop          // buffer already empty — ignore DEL silently
    dey                     // discard previous char from logical buffer
    lda #PetDel
    jsr KernalChROUT        // destructive backspace on screen
    jmp rlReadLoop

rlStoreChar:
    jsr KernalChROUT        // echo character (KernalChROUT preserves X)
    txa                     // restore char (KernalChROUT may clobber A)
    sta CommandBuffer, y
    iny
    cpy #79                 // reserve index 79 for null terminator
    bne rlReadLoop
rlDoneRead:
    lda #0
    sta CommandBuffer, y    // write $00 null terminator (not $0D)
    sty CommandLen
    lda #PetCr
    jsr KernalChROUT        // advance cursor to next line
    rts


// ---------------------------------------------------------------------------
// shellDispatch
// Walk command table for a match against CommandBuffer.
// Match: load handler address into zero-page vector, jump through it.
// No match: print error message.
// Clobbers: A, X, Y, HandlerVecLo, HandlerVecHi, ParsePos
// ---------------------------------------------------------------------------
shellDispatch:
    ldy #0
sdSkipLeading:
    lda CommandBuffer, y
    cmp #' '
    bne sdCheckEmpty
    iny
    jmp sdSkipLeading
sdCheckEmpty:
    cmp #0                  // if null, the line is empty or all spaces
    bne sdNotEmpty
    rts
sdNotEmpty:
    sty ParsePos            // save start of command name for cmdCompare
    ldx #0
sdSearchLoop:
    cpx #(tableEnd - tableCmd)
    bcs sdBadCmd

    jsr cmdCompare          // Z=1 on match; X advanced to handler word on match
    beq sdFoundCmd

    txa
    clc
    adc #TABLE_ENTRY_SIZE   // advance X to next table entry
    tax
    jmp sdSearchLoop

sdFoundCmd:
    lda tableCmd, x         // handler address low byte
    sta HandlerVecLo
    lda tableCmd+1, x       // handler address high byte
    sta HandlerVecHi
    jmp (HandlerVecLo)      // jump to handler; handler rts returns to mainLoop

sdBadCmd:
    // Try external command search
    // Extract first token from CommandBuffer starting at ParsePos
    ldy ParsePos
    lda CommandBuffer, y
    cmp #'$'                // Reject names starting with $ (avoids directory load crash)
    beq sdRealBadCmd
    sty TempLo
sdExtScan:
    lda CommandBuffer, y
    beq sdExtFoundEnd
    cmp #' '
    beq sdExtFoundEnd
    iny
    jmp sdExtScan
sdExtFoundEnd:
    lda #<CommandBuffer
    clc
    adc TempLo
    sta NamePtrLo
    lda #>CommandBuffer
    adc #0
    sta NamePtrHi
    
    lda CurrentDevice
    sta SavedDevice
    
    ldx #NamePtrLo
    jsr parsePointerDevice
    sta CurrentDevice
    
    ldy #0
sdExtCountLen:
    lda (NamePtrLo), y
    beq sdExtGotLen
    cmp #' '
    beq sdExtGotLen
    iny
    jmp sdExtCountLen
sdExtGotLen:
    tya
    tax                     // X = length
    beq sdExtSwitchDrive    // Length 0? Switch drive shortcut!
    
    lda NamePtrLo
    ldy NamePtrHi
    jsr findFile
    bcs sdExtError

    // Found it! Load to UserProgStart ($2000)
    lda #0                  // 0 = Relocated (uses HexVal)
    sta SpecificLoad
    lda #<UserProgStart
    sta HexValLo
    lda #>UserProgStart
    sta HexValHi

    lda NamePtrLo
    ldy NamePtrHi
    jsr shellLoadPrg
    bcs sdExtError

    lda SavedDevice
    sta CurrentDevice

    // EXECUTE
    jsr UserProgStart
    rts

sdExtSwitchDrive:
    rts

sdExtError:
    lda SavedDevice
    sta CurrentDevice
    jmp sdRealBadCmd

sdRealBadCmd:
    lda #<badCmdMsg
    ldy #>badCmdMsg
    jsr petPrintString
    lda #PetCr
    jsr KernalChROUT
sdExitDispatch:
    rts

// ---------------------------------------------------------------------------
// cmdCompare  [subroutine]
// Compare CommandBuffer against the TABLE_NAME_LEN-byte name at tableCmd+X.
//
// Design: X is NEVER walked — it always holds the entry base offset.
//         CmpBase ($FA) saves X so it can be restored on mismatch.
//         Table bytes are addressed as tableCmd[CmpBase + Y] each iteration.
//         On match, X is set to CmpBase + TABLE_NAME_LEN (handler word offset).
//         On mismatch, X is restored to CmpBase so sdSearchLoop's stride is clean.
//
// Input:  X = byte offset of entry start in tableCmd
//         ParsePos = buffer index of command start
// Output: Z=1 on match; X = entry_base + TABLE_NAME_LEN (points to handler word).
//         Z=0 on mismatch; X = entry_base (restored).
//         ParsePos = CommandBuffer index of first argument char on match.
// Clobbers: A, Y, CmpBase ($FA)
// ---------------------------------------------------------------------------
cmdCompare:
    stx CmpBase             // save entry base; restored on fail, used on match
    ldy ParsePos            // start comparison from first non-space character
ccCmpLoop:
    // Compute table index for this position: X = CmpBase + (Y - StartPos)
    tya
    sec
    sbc ParsePos            // A = current offset from command start
    tax                     // save offset to X temporarily
    
    // Check if we've compared all TABLE_NAME_LEN characters
    cpx #TABLE_NAME_LEN
    beq ccSetMatch          // matched all fixed-width chars!

    // Compute table index: CmpBase + offset
    txa
    clc
    adc CmpBase
    tax                     // X = absolute index in tableCmd

    // Load and classify input character
    lda CommandBuffer, y
    cmp #' '
    beq ccInputSpace        // input token ended (space separator)
    cmp #0
    beq ccInputNull         // input token ended (null terminator)
    
    // Compare input char against tableCmd, x
    cmp tableCmd, x
    bne ccCmpFail
    
    iny
    jmp ccCmpLoop

ccInputSpace:
    // Input ended early (space). Table must be space-padded here.
    lda tableCmd, x
    cmp #' '
    bne ccCmpFail
    // Success - skip any more spaces and set match
    iny
ccSkipSpaces:
    lda CommandBuffer, y
    cmp #' '
    bne ccSetMatch
    iny
    jmp ccSkipSpaces

ccInputNull:
    // Input ended early (null). Table must be space-padded here.
    lda tableCmd, x
    cmp #' '
    bne ccCmpFail
    // Success - fall through to ccSetMatch

ccSetMatch:
    sty ParsePos            // save pointer to first arg char (or null)
    lda CmpBase
    clc
    adc #TABLE_NAME_LEN
    tax                     // X = index of handler address in tableCmd
    lda #0                  // Z=1 (Match)
    rts

ccCmpFail:
    ldx CmpBase
    lda #1                  // Z=0 (No Match)
    rts

// ---------------------------------------------------------------------------
// Built-in command handlers
// Each handler performs its action and returns via rts → mainLoop.
// ---------------------------------------------------------------------------

// EXIT — return to BASIC cold start
// $E394 is the BASIC cold-start entry in C64 ROM: reinitializes all BASIC vectors,
// zero-page memory pointers ($2B-$38), clears variables, and prints READY.
// A warm start ($E37B) is insufficient because the shell clobbers BASIC's ZP state
// during operation, leaving pointers stale when BASIC ROM is re-mapped.
cmdExit:
    lda $01
    ora #$07                // Set bits 0-2 (LORAM, HIRAM, CHAREN = 1) -> restore BASIC/KERNAL ROM and I/O
    sta $01
    jmp $E394               // BASIC cold start: full re-init of interpreter state

// CLS — clear screen and restore lowercase mode
cmdCls:
    lda #$93
    jsr KernalChROUT
    lda #$0E                // restore lowercase mode (clear resets character set)
    jsr KernalChROUT
    rts

// ECHO — print CommandBuffer from ParsePos onward
cmdEcho:
    ldy ParsePos
echoLoop:
    lda CommandBuffer, y
    beq echoDone
    jsr KernalChROUT
    iny
    jmp echoLoop
echoDone:
    lda #PetCr
    jsr KernalChROUT
    rts

// LOAD — load a .PRG from disk [address]
cmdLoad:
    ldy ParsePos
    lda CommandBuffer, y
    beq clNoArgs
    
    // Save start position of name
    sty TempLo
clScanName:
    lda CommandBuffer, y
    beq clDoneScan
    cmp #' '
    beq clDoneScan
    iny
    jmp clScanName
clDoneScan:
    sty TempHi              // Save end position
    
    // Check for optional address (do this first, before ZP pointers are parsed)
    ldy TempHi
    jsr shellSkipSpaces
    lda CommandBuffer, y
    beq clHeaderLoad
    
    jsr parseHex
    bcs clHeaderLoad        // Invalid hex -> use header
    lda #0                  // 0 = Relocated (uses HexVal)
    sta SpecificLoad
    jmp clPostAddr
clHeaderLoad:
    lda #1                  // 1 = Absolute (uses Header)
    sta SpecificLoad
    
clPostAddr:
    // Calculate pointer: CommandBuffer + TempLo
    lda #<CommandBuffer
    clc
    adc TempLo
    sta NamePtrLo
    lda #>CommandBuffer
    adc #0
    sta NamePtrHi
    
    // Parse target device prefix
    lda CurrentDevice
    sta SavedDevice
    
    ldx #NamePtrLo
    jsr parsePointerDevice
    sta CurrentDevice
    
    // Count length of filename past the prefix
    ldy #0
clCountLen:
    lda (NamePtrLo), y
    beq clGotLen
    cmp #' '
    beq clGotLen
    iny
    jmp clCountLen
clGotLen:
    tya
    sta TempLo              // Save length in TempLo
    
clDoLoad:
    lda NamePtrLo
    ldy NamePtrHi
    ldx TempLo              // Restore length in X
    jsr findFile            // Normalize, append .prg, check disk
    bcs clFindErr           // Device missing/not ready, or file not found

    // findFile returns updated length in X
    lda NamePtrLo
    ldy NamePtrHi
    jsr shellLoadPrg
    bcs clLoadErr

    // Success: restore device and return
    lda SavedDevice
    sta CurrentDevice
    rts

clNoArgs:
    lda #<noFileMsg
    ldy #>noFileMsg
    jsr petPrintString
    rts

clFindErr:
    pha                     // Save findFile's status code across the device restore
    lda SavedDevice
    sta CurrentDevice
    pla
    jsr printDeviceStatusMsg
    rts

clLoadErr:
    lda SavedDevice
    sta CurrentDevice
    // fall through to clError

clError:
    lda #<loadErrMsg
    ldy #>loadErrMsg
    jsr petPrintString
    rts

// RUN [address] — execute a program in memory
cmdRun:
    ldy ParsePos
    jsr shellSkipSpaces
    lda CommandBuffer, y
    beq crDefault
    
    jsr parseHex
    bcs crError
    
    lda HexValLo
    sta HandlerVecLo
    lda HexValHi
    sta HandlerVecHi
    jmp crExecute

crDefault:
    lda #<UserProgStart
    sta HandlerVecLo
    lda #>UserProgStart
    sta HandlerVecHi

crExecute:
    // Execute via JSR. If the program RTS, we return to mainLoop.
    // If it uses DOS_EXIT, it resets stack and JMPs to mainLoop.
    jsr crJump
    rts

crJump:
    jmp (HandlerVecLo)

crError:
    lda #<badAddrMsg
    ldy #>badAddrMsg
    jsr petPrintString
    rts

// DIR — list directory contents (non-destructive)
cmdDir:
    ldy ParsePos
    jsr shellSkipSpaces
    sty ParsePos
    
    lda #<CommandBuffer
    clc
    adc ParsePos
    sta PrintPtrLo
    lda #>CommandBuffer
    adc #0
    sta PrintPtrHi
    
    lda CurrentDevice
    sta SavedDevice
    
    ldx #PrintPtrLo
    jsr parsePointerDevice
    sta CurrentDevice
                             // A still holds the device number (STA doesn't clobber it)
    jsr checkDeviceReady
    bcs cdDevError

    lda PrintPtrLo
    sec
    sbc #<CommandBuffer
    sta ParsePos

    ldy ParsePos
    jsr shellSkipSpaces
    sty ParsePos
    lda #1
    ldx #<dirFname
    ldy #>dirFname
    jsr KernalSETNAM

    lda #13                 // LFN 13 — clear of handle table (2-9), checkExistence (14), command channel (15)
    ldx CurrentDevice
    ldy #0                  // Secondary 0
    jsr KernalSETLFS

    jsr KernalOPEN
    bcs cdDevError            // Preflight passed but the real OPEN still failed —
                               // a rare race, not a classified device status, so A
                               // falls through to printDeviceStatusMsg's generic
                               // message rather than being forced to "device not
                               // present".

    ldx #13
    jsr KernalCHKIN

    // Skip 2-byte load address
    jsr KernalGetIn
    jsr KernalGetIn

    // CmpBase is reused below as a dir-entry safety counter — cmdCompare
    // (its usual owner) only runs during command dispatch, never inside a
    // handler. No reset needed: incrementing from whatever it was last left
    // at still wraps to 0 within at most 255 iterations either way, which
    // is all that matters — it just needs to be bounded, not exact.
cdLineLoop:
    inc CmpBase
    beq cdDone                // Wrapped past 255 entries — far more than any
                               // real disk holds; bail out.

    // Read link bytes
    jsr KernalGetIn
    sta TempLo              // Link Lo
    jsr KernalGetIn
    ora TempLo              // Link Hi
    beq cdDone              // EOF
    
    // Read block count
    jsr KernalGetIn
    pha                     // Save Count Lo on stack
    jsr KernalGetIn
    tay                     // Count Hi
    pla
    tax                     // Restore Count Lo
    
    // Clear TempHi (used by decimal printer for leading zero suppression)
    lda #0
    sta TempHi
    jsr printDecimal16
    
    lda #' '
    jsr KernalChROUT

    // Safety net for the name itself, not just the entry count: a single
    // non-terminating "filename" would otherwise loop here forever, before
    // the entry cap above ever gets a chance to apply. HexValLo is idle
    // here (printDecimal16 above is its last user until the next entry) and
    // needs no reset — incrementing from whatever it was left at still
    // wraps within at most 255 iterations either way.
cdReadName:
    inc HexValLo
    beq cdLineDone             // Wrapped past 255 chars in one name — bail
    jsr KernalGetIn
    beq cdLineDone
    jsr KernalChROUT
    jmp cdReadName
    
cdLineDone:
    lda #PetCr
    jsr KernalChROUT
    
    jsr KernalREADST
    beq cdLineLoop           // No error/EOF yet — keep reading entries

cdDone:
    jsr KernalCLRCHN
    lda #13
    jsr KernalCLOSE
    jmp dirExit

cdDevError:
    // Closing LFN13 is a harmless no-op if the preflight failed before we
    // ever opened it.
    pha
    lda #13
    jsr KernalCLOSE
    pla
    jsr printDeviceStatusMsg
    lda #PetCr
    jsr KernalChROUT
    jmp dirExit

dirExit:
    lda SavedDevice
    sta CurrentDevice
    rts

// TYPE — display contents of a file
cmdType:
    ldy ParsePos
    jsr shellSkipSpaces
    lda CommandBuffer, y
    beq ctNoArgs
    
    // Extract filename (token until space or null)
    sty TempLo              // Start index
ctScanEnd:
    lda CommandBuffer, y
    beq ctGotEnd
    cmp #' '
    beq ctGotEnd
    iny
    jmp ctScanEnd
ctGotEnd:
    // Null-terminate the name in the buffer (temporarily)
    lda #0
    sta CommandBuffer, y
    
    // Open file
    lda #0
    sta HexValLo            // Read mode
    ldx #<CommandBuffer
    stx NamePtrLo           // Use ZP to compute absolute addr
    lda NamePtrLo
    clc
    adc TempLo
    tax                     // X = Lo byte of filename
    lda #>CommandBuffer
    adc #0
    tay                     // Y = Hi byte of filename
    lda #DOS_OPEN_FILE
    jsr apiHandler
    bcs ctOpenErr

    sta FileHandle          // Save handle for subsequent read/close calls

ctReadLoop:
    ldx #<CommandBuffer     // Reuse CommandBuffer as read buffer
    ldy #>CommandBuffer
    lda #64                 // Read 64 bytes at a time
    sta HexValLo
    lda #0
    sta HexValHi
    lda #DOS_READ_FILE
    jsr apiHandler
    bcs ctReadDone

    // Check if we actually read any bytes
    lda HexValLo
    ora HexValHi
    beq ctReadDone

    // Print the bytes we read
    ldy #0
ctPrintLoop:
    lda CommandBuffer, y
    jsr KernalChROUT
    iny
    cpy HexValLo
    bne ctPrintLoop
    
    // If we read a full 64-byte block, try to read more
    lda HexValLo
    cmp #64
    beq ctReadLoop

ctReadDone:
    lda #DOS_CLOSE_FILE
    jsr apiHandler
    lda #PetCr
    jsr KernalChROUT
    rts

ctNoArgs:
    lda #<noFileMsg
    ldy #>noFileMsg
    jsr petPrintString
    rts

ctOpenErr:
    jsr printDeviceStatusMsg
    rts

// DEL / ERASE — delete a file from disk
cmdDel:
    ldy ParsePos
cdelSkipSpaces:
    lda CommandBuffer, y
    beq cdelNoArgs
    cmp #' '
    bne cdelFoundName
    iny
    jmp cdelSkipSpaces

cdelFoundName:
    // Extract filename (token until space or null)
    sty TempLo              // Start index
cdelScanEnd:
    lda CommandBuffer, y
    beq cdelGotEnd
    cmp #' '
    beq cdelGotEnd
    iny
    jmp cdelScanEnd
cdelGotEnd:
    // Null-terminate the name in the buffer (temporarily)
    lda #0
    sta CommandBuffer, y
    
    // Prepare pointer for API call
    lda #<CommandBuffer
    clc
    adc TempLo
    tax                     // X = Lo byte of filename
    lda #>CommandBuffer
    adc #0
    tay                     // Y = Hi byte of filename
    
    lda #DOS_DELETE_FILE
    jsr apiHandler
    bcs cdelErr
    
    lda #PetCr
    jsr KernalChROUT
    rts

cdelNoArgs:
    lda #<noFileMsg
    ldy #>noFileMsg
    jsr petPrintString
    rts

cdelErr:
    jmp ctOpenErr             // Identical body — device-status message + rts

// REN / RENAME — rename a file on disk
cmdRen:
    ldy ParsePos
crenSkip1:
    lda CommandBuffer, y
    beq crenNoArgs
    cmp #' '
    bne crenFoundOld
    iny
    jmp crenSkip1

crenFoundOld:
    sty TempLo              // Start of Old Name
crenScan1:
    lda CommandBuffer, y
    beq crenNoNew           // No second argument
    cmp #' '
    beq crenGotOld
    iny
    jmp crenScan1
crenGotOld:
    lda #0
    sta CommandBuffer, y    // Null-terminate Old Name
    iny
    
crenSkip2:
    lda CommandBuffer, y
    beq crenNoNew
    cmp #' '
    bne crenFoundNew
    iny
    jmp crenSkip2

crenFoundNew:
    sty TempHi              // Start of New Name
crenScan2:
    lda CommandBuffer, y
    beq crenGotNew
    cmp #' '
    beq crenGotNew
    iny
    jmp crenScan2
crenGotNew:
    lda #0
    sta CommandBuffer, y    // Null-terminate New Name
    
    // Set up API call
    // Old Name (X/Y)
    lda #<CommandBuffer
    clc
    adc TempLo
    tax
    lda #>CommandBuffer
    adc #0
    tay
    
    // New Name (PrintPtrLo/Hi)
    lda #<CommandBuffer
    clc
    adc TempHi
    sta PrintPtrLo
    lda #>CommandBuffer
    adc #0
    sta PrintPtrHi
    
    lda #DOS_RENAME_FILE
    jsr apiHandler
    bcs crenErr
    
    lda #PetCr
    jsr KernalChROUT
    rts

crenNoArgs:
crenNoNew:
    lda #<noFileMsg
    ldy #>noFileMsg
    jsr petPrintString
    rts

crenErr:
    jmp ctOpenErr             // Identical body — device-status message + rts

cmdCopy:
    lda CurrentDevice
    sta SavedDevice

    // Construct pointer to CommandBuffer + ParsePos
    lda #<CommandBuffer
    clc
    adc ParsePos
    sta PrintPtrLo
    lda #>CommandBuffer
    adc #0
    sta PrintPtrHi

    // 1. Skip spaces to find source
ccSkip1:
    ldy #0
    lda (PrintPtrLo), y
    bne ccSkip1NotNoArgs
    jmp ccNoArgs
ccSkip1NotNoArgs:
    cmp #' '
    bne ccFoundSrc
    inc PrintPtrLo
    bne ccSkip1
    inc PrintPtrHi
    jmp ccSkip1

ccFoundSrc:
    // Parse target device prefix on source
    ldx #PrintPtrLo
    jsr parsePointerDevice
    sta SrcDevice

    // Copy source name from PrintPtr to SourceBuf
    ldy #0
    ldx #0
ccCopySrc:
    lda (PrintPtrLo), y
    beq ccGotSrcNull
    cmp #' '
    beq ccGotSrcSpace
    sta SourceBuf, x
    inx
    iny
    jmp ccCopySrc

ccGotSrcNull:
    lda #0
    sta SourceBuf, x
    jmp ccNoDest            // No destination argument specified

ccGotSrcSpace:
    lda #0
    sta SourceBuf, x
    
    // Advance PrintPtr past the copied source filename
    tya
    clc
    adc PrintPtrLo
    sta PrintPtrLo
    lda #0
    adc PrintPtrHi
    sta PrintPtrHi

    // 3. Skip spaces to find dest
ccSkip2:
    ldy #0
    lda (PrintPtrLo), y
    bne ccSkip2NotNoDest
    jmp ccNoDest
ccSkip2NotNoDest:
    cmp #' '
    bne ccFoundDest
    inc PrintPtrLo
    bne ccSkip2
    inc PrintPtrHi
    jmp ccSkip2

ccFoundDest:
    // Parse target device prefix on destination
    ldx #PrintPtrLo
    jsr parsePointerDevice
    sta DstDevice

    // Copy dest name to DestBuf
    ldy #0
    ldx #0
ccCopyDest:
    lda (PrintPtrLo), y
    beq ccGotDest
    cmp #' '
    beq ccGotDest
    sta DestBuf, x
    inx
    iny
    jmp ccCopyDest
ccGotDest:
    lda #0
    sta DestBuf, x

    // Check if DestBuf is empty (first character is 0)
    lda DestBuf
    bne ccDestNotEmpty

    // DestBuf is empty: copy SourceBuf to DestBuf
    ldx #0
ccCopySrcToDest:
    lda SourceBuf, x
    sta DestBuf, x
    beq ccDestNotEmpty      // copy stops after null terminator is written
    inx
    jmp ccCopySrcToDest
    
ccDestNotEmpty:
    // Determine source file type before opening it
    jsr getSourceFileType
    sta HexValHi            // Save file type for destination open
    
    // 5. Open Source for Read
    lda SrcDevice
    sta CurrentDevice
    
    lda #0
    sta HexValLo            // mode=0 (Read)
    ldx #<SourceBuf
    ldy #>SourceBuf
    lda #DOS_OPEN_FILE
    jsr apiHandler
    bcs ccOpenErr
    sta SrcHandle           // Use dedicated ZP handle scratch

    // 6. Open Dest for Write
    lda DstDevice
    sta CurrentDevice
    
    lda #1
    sta HexValLo            // mode=1 (Write)
    ldx #<DestBuf
    ldy #>DestBuf
    lda #DOS_OPEN_FILE
    jsr apiHandler
    bcs ccCloseSrcErr       // Error opening dest, close source
    sta DstHandle           // Use dedicated ZP handle scratch

    lda #0
    sta HexValHi            // Clear HexValHi so we don't leak the type to other file opens

    // 7. Copy Loop
ccLoop:
    lda SrcHandle           // Source Handle -> FileHandle for read call
    sta FileHandle
    ldx #<CommandBuffer     // Reuse CommandBuffer as read buffer
    ldy #>CommandBuffer
    lda #64                 // 64-byte chunk
    sta HexValLo
    lda #0
    sta HexValHi
    lda #DOS_READ_FILE
    jsr apiHandler
    bcs ccDone

    // Check if read 0 bytes (EOF)
    lda HexValLo
    ora HexValHi
    beq ccDone

    // Write to dest
    lda DstHandle           // Dest Handle -> FileHandle for write call
    sta FileHandle
    ldx #<CommandBuffer
    ldy #>CommandBuffer
    // HexValLo/Hi already contains the actual count read
    lda #DOS_WRITE_FILE
    jsr apiHandler
    bcs ccDone              // Write error

    // If we read a full 64-byte block, try to read more
    lda HexValLo
    cmp #64
    beq ccLoop

ccDone:
    // 8. Close both
    lda SrcHandle
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr apiHandler

    lda DstHandle
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr apiHandler
    
    lda #PetCr
    jsr KernalChROUT
    jmp copyExit

ccNoArgs:
ccNoDest:
    lda #<noFileMsg
    ldy #>noFileMsg
    jsr petPrintString
    jmp copyExit

ccOpenErr:
    jsr printDeviceStatusMsg
    jmp copyExit

ccCloseSrcErr:
    lda SrcHandle           // source handle — TempLo holds scan index here, not the handle
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr apiHandler          // On the rare chance this ALSO fails, its status
                             // (not the dest-open failure's) is what gets
                             // reported below — an acceptable simplification
                             // for this double-fault edge case.
    jmp ccOpenErr

copyExit:
    lda SavedDevice
    sta CurrentDevice
    rts

// --- shellSkipSpaces ---
// Skips spaces in CommandBuffer starting at Y.
// Returns Y pointing to first non-space char or null.
shellSkipSpaces:
    lda CommandBuffer, y
    beq sssDone
    cmp #' '
    bne sssDone
    iny
    jmp shellSkipSpaces
sssDone:
    rts



// Local variables for device routing state
SavedDevice: .byte 0
SrcDevice:   .byte 0
DstDevice:   .byte 0

// --- getSourceFileType ---
// Finds the file type of the file in SourceBuf on SrcDevice by reading the directory.
// Output: A = 'P' ($50) or 'S' ($53) or 'U' ($55)
// Clobbers: A, X, Y
getSourceFileType:
    // Open directory on SrcDevice
    lda #1
    ldx #<dirFname          // "$"
    ldy #>dirFname
    jsr KernalSETNAM
    
    lda #13                 // LFN 13
    ldx SrcDevice
    ldy #0
    jsr KernalSETLFS
    jsr KernalOPEN
    bcc gsftOpenOk
    jmp gsftDefault         // If open fails, default to PRG
gsftOpenOk:
    
    ldx #13
    jsr KernalCHKIN
    bcc gsftChkinOk
    jmp gsftDefault
gsftChkinOk:
    
    // Skip 2-byte load address
    jsr KernalGetIn
    jsr KernalGetIn
    
    // Skip 2-byte link pointer
    jsr KernalGetIn
    jsr KernalGetIn
    
    // Skip 2-byte block count
    jsr KernalGetIn
    jsr KernalGetIn
    
    // Read header line until null
gsftSkipHeader:
    jsr KernalGetIn
    bne gsftSkipHeader
    
gsftLineLoop:
    // Read link bytes
    jsr KernalGetIn
    sta TempLo
    jsr KernalGetIn
    ora TempLo
    bne gsftLinkOk
    jmp gsftNotFound        // Link Lo/Hi is 0 -> EOF
gsftLinkOk:
    
    // Read block count (line number)
    jsr KernalGetIn
    jsr KernalGetIn
    
    // Read until first quote
gsftFindQuote:
    jsr KernalGetIn
    bne gsftQuoteCheck
    jmp gsftLineDone        // unexpected null
gsftQuoteCheck:
    cmp #$22                // double quote
    bne gsftFindQuote
    
    // Read filename and compare with SourceBuf
    ldx #0                  // Index into filename
gsftReadName:
    jsr KernalGetIn
    bne gsftCharCheck
    jmp gsftLineDone        // unexpected null
gsftCharCheck:
    cmp #$22                // second quote
    beq gsftNameDone
    
    // Compare character with SourceBuf, x
    // Normalize both characters to lowercase for comparison
    pha
    jsr petsciiToLower
    sta TempHi
    lda SourceBuf, x
    jsr petsciiToLower
    cmp TempHi
    beq gsftCharMatch
    // Character mismatch! Mark mismatch
    lda #$FF
    sta gsftMismatchFlag
gsftCharMatch:
    pla
    inx
    jmp gsftReadName

gsftNameDone:
    // Check if lengths match
    // SourceBuf is null-terminated, so SourceBuf, x should be 0!
    lda SourceBuf, x
    bne gsftNoMatch
    
    // Check mismatch flag
    lda gsftMismatchFlag
    bne gsftNoMatch
    
    // Found it! Now read characters and skip spaces to find file type
gsftFindType:
    jsr KernalGetIn
    bne gsftTypeCheck
    jmp gsftLineDone
gsftTypeCheck:
    cmp #' '
    beq gsftFindType
    
    // We found the first non-space char of the type (e.g. 'P' or 'S')
    // Save it in TempHi
    sta TempHi
    
    // Read remaining characters until null (to clear the line)
gsftClearLine:
    jsr KernalGetIn
    bne gsftClearLine
    
    // Close directory
    jsr KernalCLRCHN
    lda #13
    jsr KernalCLOSE
    
    // Return type character in A
    lda TempHi
    rts

gsftNoMatch:
    // Reset mismatch flag
    lda #0
    sta gsftMismatchFlag
    
    // Read rest of line until null
gsftSkipLine:
    jsr KernalGetIn
    bne gsftSkipLine
    jmp gsftLineLoop

gsftLineDone:
    // Line ended unexpectedly (null)
    jmp gsftLineLoop

gsftNotFound:
gsftDefault:
    jsr KernalCLRCHN
    lda #13
    jsr KernalCLOSE
    lda #$50                // Default to 'P'
    rts

gsftMismatchFlag:
    .byte 0

// Helper to convert character in A to lowercase PETSCII
petsciiToLower:
    cmp #$C1
    bcc ptlNoShift
    cmp #$DB
    bcs ptlNoShift
    and #$7F
ptlNoShift:
    rts


// DRIVE — switch active device
cmdDrive:
    ldy ParsePos
    jsr shellSkipSpaces
    lda CommandBuffer, y
    beq cdShowCurrent
    
    cmp #'8'
    beq cdSet8
    cmp #'9'
    beq cdSet9
    cmp #'1'
    beq cdCheck10
    jmp cdError

cdShowCurrent:
    lda #<currentDevMsg
    ldy #>currentDevMsg
    jsr petPrintString
    
    lda CurrentDevice
    tax
    ldy #0
    jsr printDecimal16
    lda #PetCr
    jsr KernalChROUT
    rts

cdSet8:
    lda #8
    sta CurrentDevice
    rts
cdSet9:
    lda #9
    sta CurrentDevice
    rts

cdCheck10:
    iny
    lda CommandBuffer, y
    cmp #'0'
    beq cdSet10
    cmp #'1'
    beq cdSet11
    jmp cdError

cdSet10:
    lda #10
    sta CurrentDevice
    rts
cdSet11:
    lda #11
    sta CurrentDevice
    rts

cdError:
    lda #<badDeviceMsg
    ldy #>badDeviceMsg
    jsr petPrintString
    rts

dirFname: .text "$"

// SET [VAR=VAL] — display or set environment variables
cmdSet:
    lda vmmInitialized
    bne csVmmOk
    lda #<noReuMsg
    ldy #>noReuMsg
    jsr petPrintString
    rts

csVmmOk:
    ldy ParsePos
    jsr shellSkipSpaces
    lda CommandBuffer, y
    beq cmdSetPrint

    // Parse VAR into SourceBuf, converting to unshifted (normalized case)
    ldx #0
csScanVar:
    lda CommandBuffer, y
    beq csQuery             // End of line -> Query
    cmp #'='
    beq csFoundEq
    
    cmp #$C1                // PETSCII Shifted 'A'
    bcc csNotShifted
    cmp #$DB                // PETSCII Shifted 'Z' + 1
    bcs csNotShifted
    and #$7F                // Convert shifted to unshifted
csNotShifted:
    sta SourceBuf, x
    inx
    cpx #39
    beq csFoundEq           // Buffer full
    iny
    jmp csScanVar

csFoundEq:
    lda #0
    sta SourceBuf, x        // Null terminate VAR
    iny                     // Skip '='
    sty ParsePos            // VAL starts here
    
    jsr envSearch           // Returns C=0 if found, VmmOff points to start
    php
    bcc csHasOld
    plp
    jmp csCheckAppend

csHasOld:
    jsr envDelete           // Removes string at VmmOff and shifts block down
    plp

csCheckAppend:
    ldy ParsePos
    lda CommandBuffer, y
    beq csDone              // VAL is empty, just deleted old (if any)
    
    jsr envFindEnd          // VmmOff points to first null of double-null
    jsr envAppend           // Appends SourceBuf + '=' + CommandBuffer[ParsePos]
    rts

csQuery:
    lda #0
    sta SourceBuf, x
    jsr envSearch
    bcs csNotFound
    
    jsr envPrintVal         // Print after '=' until '\0'
    rts

csNotFound:
    lda #<noEnvMsg
    ldy #>noEnvMsg
    jsr petPrintString
    rts

csDone:
    rts

cmdSetPrint:
    // Print environment from REU
    lda #0
    sta VmmOffLo
    sta VmmOffHi
    lda EnvSegmentLo
    sta VmmSegLo
    lda EnvSegmentHi
    sta VmmSegHi

cspLoop:
    jsr vmmReadByte         // A = byte from REU
    beq cspNull
    jsr KernalChROUT
    inc VmmOffLo
    bne cspLoop
    inc VmmOffHi
    jmp cspLoop

cspNull:
    // One null reached. Is the next one also null?
    inc VmmOffLo
    bne cspCheckNext
    inc VmmOffHi
cspCheckNext:
    jsr vmmReadByte
    beq cspDone             // Double null reached
    
    lda #PetCr
    jsr KernalChROUT
    jmp cspLoop             // More strings follow

cspDone:
    lda #PetCr
    jsr KernalChROUT
    rts

// --- envSearch ---
// Input: SourceBuf (null-terminated VAR)
// Output: C=0 found, VmmOff = start of string
//         C=1 not found, VmmOff = end of block (first null)
envSearch:
    lda #0
    sta VmmOffLo
    sta VmmOffHi
    lda EnvSegmentLo
    sta VmmSegLo
    lda EnvSegmentHi
    sta VmmSegHi

esNext:
    // Save start of current string
    lda VmmOffLo
    sta TempHi              // Save offset Lo
    lda VmmOffHi
    sta CmpBase             // Save offset Hi

    jsr vmmReadByte
    beq esCheckEnd          // Double null?

    ldx #0
esLoop:
    lda SourceBuf, x
    beq esFoundMatch        // End of VAR
    sta TempLo
    jsr vmmReadByte
    cmp TempLo
    bne esSkip              // Mismatch
    inc VmmOffLo
    bne esInc1
    inc VmmOffHi
esInc1:
    inx
    jmp esLoop

esFoundMatch:
    jsr vmmReadByte
    cmp #'='
    beq esReturnFound       // Match!

esSkip:
    jsr vmmReadByte
    beq esStartNext
    inc VmmOffLo
    bne esSkip
    inc VmmOffHi
    jmp esSkip

esStartNext:
    inc VmmOffLo
    bne esNext
    inc VmmOffHi
    jmp esNext

esCheckEnd:
    // Block end
    sec
    rts                     // Not found, VmmOff points to end

esReturnFound:
    lda TempHi
    sta VmmOffLo
    lda CmpBase
    sta VmmOffHi
    clc
    rts

// --- envDelete ---
// Removes the string starting at VmmOffLo/Hi by shifting everything down.
envDelete:
    lda VmmOffLo
    sta NamePtrLo           // Use NamePtr ($FD) as destination pointer
    lda VmmOffHi
    sta NamePtrHi           // $FE

edScanNext:
    jsr vmmReadByte
    beq edFoundEndStr
    inc VmmOffLo
    bne edScanNext
    inc VmmOffHi
    jmp edScanNext

edFoundEndStr:
    inc VmmOffLo            // Skip null
    bne edShiftLoop
    inc VmmOffHi

edShiftLoop:
    jsr vmmReadByte
    sta TempLo              // Byte to move
    
    // Save Source
    lda VmmOffLo
    pha
    lda VmmOffHi
    pha
    
    // Set Destination
    lda NamePtrLo
    sta VmmOffLo
    lda NamePtrHi
    sta VmmOffHi
    lda TempLo
    jsr vmmWriteByte
    
    // Increment Destination
    inc NamePtrLo
    bne edIncDstOk
    inc NamePtrHi
edIncDstOk:

    // Restore and Increment Source
    pla
    sta VmmOffHi
    pla
    sta VmmOffLo
    
    lda TempLo
    bne edNextByte
    
    // Moved a null. Is next also null?
    inc VmmOffLo
    bne edCheckDouble
    inc VmmOffHi
edCheckDouble:
    jsr vmmReadByte
    beq edDoubleDone
    jmp edShiftLoop         // More to move

edNextByte:
    inc VmmOffLo
    bne edShiftLoop
    inc VmmOffHi
    jmp edShiftLoop

edDoubleDone:
    lda NamePtrLo
    sta VmmOffLo
    lda NamePtrHi
    sta VmmOffHi
    lda #0
    jsr vmmWriteByte        // Write final double null
    rts

// --- envAppend ---
// Input: VmmOff points to the end-of-block null.
envAppend:
    // Bounds check: 4KB segment ($1000 bytes)
    lda VmmOffHi
    cmp #$10                // Offset $1000?
    bcc eaCheckSpace
    lda #<envFullMsg
    ldy #>envFullMsg
    jsr petPrintString
    rts

eaCheckSpace:
    ldx #0
eaVarLoop:
    lda SourceBuf, x
    beq eaWriteEq
    jsr vmmWriteByte
    inc VmmOffLo
    bne eaVarNext
    inc VmmOffHi
eaVarNext:
    inx
    jmp eaVarLoop

eaWriteEq:
    lda #'='
    jsr vmmWriteByte
    inc VmmOffLo
    bne eaEqNext
    inc VmmOffHi
eaEqNext:

    ldy ParsePos
eaValLoop:
    lda CommandBuffer, y
    beq eaDone
    jsr vmmWriteByte        // vmmWriteByte preserves Y (via vmmComputeAddress stack fix)
    inc VmmOffLo
    bne eaValNext
    inc VmmOffHi
eaValNext:
    iny
    jmp eaValLoop

eaDone:
    lda #0
    jsr vmmWriteByte
    inc VmmOffLo
    bne eaFinalNull
    inc VmmOffHi
eaFinalNull:
    lda #0
    jsr vmmWriteByte
    rts

// --- envFindEnd ---
// Output: VmmOff points to the correct location to append a new string.
//         For an empty environment (\0\0), returns 0.
//         For a non-empty environment (S1\0S2\0\0), returns the offset of the second \0.
envFindEnd:
    lda #0
    sta VmmOffLo
    sta VmmOffHi
    lda EnvSegmentLo
    sta VmmSegLo
    lda EnvSegmentHi
    sta VmmSegHi

    jsr vmmReadByte
    beq efeDone             // If [0] is null, environment is empty, start at 0

efeLoop:
    jsr vmmReadByte
    beq efeCheckDouble
    inc VmmOffLo
    bne efeLoop
    inc VmmOffHi
    jmp efeLoop

efeCheckDouble:
    inc VmmOffLo            // Advance to the potential second null
    bne efeCheck2
    inc VmmOffHi
efeCheck2:
    jsr vmmReadByte
    beq efeDone             // Found second null, return this position
    jmp efeLoop             // Not a double null (just end of string), keep scanning

efeDone:
    rts

// --- envPrintVal ---
envPrintVal:
epvScanEq:
    jsr vmmReadByte
    cmp #'='
    beq epvStartPrint
    inc VmmOffLo
    bne epvScanEq
    inc VmmOffHi
    jmp epvScanEq

epvStartPrint:
    inc VmmOffLo
    bne epvLoop
    inc VmmOffHi

epvLoop:
    jsr vmmReadByte
    beq epvDone
    jsr KernalChROUT
    inc VmmOffLo
    bne epvLoop
    inc VmmOffHi
    jmp epvLoop

epvDone:
    lda #PetCr
    jsr KernalChROUT
    rts

// PATH [path] — display or set search path
cmdPath:
    ldy ParsePos
    jsr shellSkipSpaces
    lda CommandBuffer, y
    beq cpQuery

    // Set up VAR="path"
    lda #'p'
    sta SourceBuf
    lda #'a'
    sta SourceBuf+1
    lda #'t'
    sta SourceBuf+2
    lda #'h'
    sta SourceBuf+3
    lda #0
    sta SourceBuf+4

    sty ParsePos            // VAL starts at current Y

    // Delete old path if it exists
    jsr envSearch
    php
    bcc cpHasOld
    plp
    jmp cpAppend
cpHasOld:
    jsr envDelete
    plp

cpAppend:
    jsr envFindEnd
    jsr envAppend
    rts

cpQuery:
    lda #'p'
    sta SourceBuf
    lda #'a'
    sta SourceBuf+1
    lda #'t'
    sta SourceBuf+2
    lda #'h'
    sta SourceBuf+3
    lda #0
    sta SourceBuf+4
    jsr envSearch
    bcs cpNotFound

    jsr envPrintVal
    rts

cpNotFound:
    lda #<noEnvMsg
    ldy #>noEnvMsg
    jsr petPrintString
    rts

// VOL — display disk volume label
cmdVol:
    ldy ParsePos
    jsr shellSkipSpaces
    sty ParsePos
    
    lda #<CommandBuffer
    clc
    adc ParsePos
    sta PrintPtrLo
    lda #>CommandBuffer
    adc #0
    sta PrintPtrHi
    
    lda CurrentDevice
    sta SavedDevice
    
    ldx #PrintPtrLo
    jsr parsePointerDevice
    sta CurrentDevice
                             // A still holds the device number (STA doesn't clobber it)
    jsr checkDeviceReady
    bcc volReady
    jmp volDevError
volReady:

    lda PrintPtrLo
    sec
    sbc #<CommandBuffer
    sta ParsePos

    ldy ParsePos
    jsr shellSkipSpaces
    sty ParsePos
    lda #1
    ldx #<dirFname
    ldy #>dirFname
    jsr KernalSETNAM

    lda #13
    ldx CurrentDevice
    ldy #0
    jsr KernalSETLFS
    jsr KernalOPEN
    bcc volOpenOk
    jmp volDevError
volOpenOk:

    ldx #13
    jsr KernalCHKIN
    bcc volChkinOk
    jmp volDevError
volChkinOk:

    // Skip 2-byte load address
    jsr KernalChRIN
    jsr KernalChRIN

    // Skip 2-byte link pointer
    jsr KernalChRIN
    jsr KernalChRIN

    // Skip 2-byte block count
    jsr KernalChRIN
    jsr KernalChRIN

    // Read characters of the header line into SourceBuf
    ldy #0
volReadLoop:
    jsr KernalREADST
    bne volReadDone
    jsr KernalChRIN
    beq volReadDone
    sta SourceBuf, y
    iny
    cpy #38
    bne volReadLoop
volReadDone:
    lda #0
    sta SourceBuf, y        // null terminate the string

    jsr KernalCLRCHN
    lda #13
    jsr KernalCLOSE

    // Parse the header string in SourceBuf
    // Format:  0 "DISK NAME       " ID 2A
    // Find the first double quote
    ldy #0
volFindFirstQuote:
    lda SourceBuf, y
    bne volFindFirstQuoteNotEnd
    jmp volParseError
volFindFirstQuoteNotEnd:
    cmp #$22                // double quote character
    beq volFoundFirstQuote
    iny
    jmp volFindFirstQuote

volFoundFirstQuote:
    iny                     // point past the first quote
    sty TempLo              // store start of disk name
    
volFindSecondQuote:
    lda SourceBuf, y
    bne volFindSecondQuoteNotEnd
    jmp volParseError
volFindSecondQuoteNotEnd:
    cmp #$22                // double quote character
    beq volFoundSecondQuote
    iny
    jmp volFindSecondQuote

volFoundSecondQuote:
    // Null terminate the disk name at the second quote
    lda #0
    sta SourceBuf, y
    
    // Parse disk ID (next non-space characters after second quote)
    iny                     // point past the second quote
volFindIdStart:
    lda SourceBuf, y
    bne volFindIdStartNotEmpty
    jmp volNoId
volFindIdStartNotEmpty:
    cmp #' '
    bne volFoundIdStart
    iny
    jmp volFindIdStart

volFoundIdStart:
    lda SourceBuf, y
    bne volFoundIdStartNotEmpty
    jmp volNoId
volFoundIdStartNotEmpty:
    sta DestBuf
    iny
    lda SourceBuf, y
    bne volFoundIdNotEmpty2
    jmp volNoId2
volFoundIdNotEmpty2:
    sta DestBuf+1
    jmp volIdDone

volNoId:
    lda #'?'
    sta DestBuf
volNoId2:
    lda #'?'
    sta DestBuf+1
volIdDone:
    lda #0
    sta DestBuf+2

    // Print: Volume in drive X is DISK NAME
    lda #<volDriveMsg
    ldy #>volDriveMsg
    jsr petPrintString

    lda CurrentDevice
    tax
    ldy #0
    jsr printDecimal16

    lda #<volIsMsg
    ldy #>volIsMsg
    jsr petPrintString

    // Print the disk name (stored in SourceBuf at offset TempLo)
    lda #<SourceBuf
    clc
    adc TempLo
    sta PrintPtrLo
    lda #>SourceBuf
    adc #0
    sta PrintPtrHi

    lda PrintPtrLo
    ldy PrintPtrHi
    jsr petPrintString

    lda #$0D
    jsr KernalChROUT

    // Print: Volume ID is AB
    lda #<volIdMsg
    ldy #>volIdMsg
    jsr petPrintString

    lda #<DestBuf
    ldy #>DestBuf
    jsr petPrintString

    lda #$0D
    jsr KernalChROUT
    jmp volExit

volParseError:
    lda #<volParseErrMsg
    ldy #>volParseErrMsg
    jsr petPrintString
    jmp volExit

volDevError:
    jmp cdDevError             // Shares cmdDir's device-error handler — same
                                // report + close + restore-device logic.

volExit:
    jmp dirExit                // Same SavedDevice-restore logic as cmdDir


notImplMsg:
    .text "Feature not yet fully implemented"
    .byte $0D, 0

noEnvMsg:
    .text "Environment variable not defined"
    .byte $0D, 0

envFullMsg:
    .text "Environment space full"
    .byte $0D, 0

cmdVer:
    lda #<verMsg
    ldy #>verMsg
    jsr petPrintString
    rts

// HELP — display help information
cmdHelp:
    lda #<helpMsg
    ldy #>helpMsg
    jsr petPrintString
    rts

// ---------------------------------------------------------------------------
// printPrompt
// Prints the dynamic shell prompt: "C64[N]:> " where N is CurrentDevice.
// ---------------------------------------------------------------------------
printPrompt:
    lda #<promptPrefixMsg
    ldy #>promptPrefixMsg
    jsr petPrintString

    lda CurrentDevice
    tax
    ldy #0
    jsr printDecimal16

    lda #<promptSuffixMsg
    ldy #>promptSuffixMsg
    jsr petPrintString
    rts

// ---------------------------------------------------------------------------
// String literals
// ---------------------------------------------------------------------------
promptPrefixMsg:
    .text "C64["
    .byte 0

promptSuffixMsg:
    .text "]:> "
    .byte 0

verMsg:
    .text "Command 64-DOS Version " + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
    .text "." + BUILD_NUMBER
    .byte $0D, $0D, 0

helpMsg:
    .text "CLS    - CLEAR SCREEN"
    .byte $0D
    .text "DIR    - LIST DIRECTORY"
    .byte $0D
    .text "ECHO   - ECHO [TEXT]"
    .byte $0D
    .text "EXIT   - RETURN TO BASIC"
    .byte $0D
    .text "HELP   - SHOW THIS HELP"
    .byte $0D
    .text "LOAD   - LOAD [FILE] [ADDR]"
    .byte $0D
    .text "TYPE   - DISPLAY FILE"
    .byte $0D
    .text "COPY   - COPY [SRC] [DST]"
    .byte $0D
    .text "DEL    - DELETE [FILE]"
    .byte $0D
    .text "REN    - RENAME [OLD] [NEW]"
    .byte $0D
    .text "RENAME - ALIAS FOR REN"
    .byte $0D
    .text "ERASE  - ALIAS FOR DEL"
    .byte $0D
    .text "DRIVE  - SWITCH DEV [8-11]"
    .byte $0D
    .text "SET    - ENV VARIABLES"
    .byte $0D
    .text "PATH   - SEARCH PATH"
    .byte $0D
    .text "VOL    - SHOW DISK LABEL"
    .byte $0D
    .text "RUN    - EXECUTE [ADDR]"
    .byte $0D
    .text "VER    - SHOW VERSION"
    .byte $0D, 0

badCmdMsg:
    .text "Bad command or file name"
    .byte 0

noFileMsg:
    .text "File name required"
    .byte 0

loadErrMsg:
    .text "Load error"
    .byte 0

noReuMsg:
    .text "Warning: No REU detected. VMM disabled."
    .byte $0D, 0

badDeviceMsg:
    .text "Invalid device"
    .byte $0D, 0

currentDevMsg:
    .text "Current device: "
    .byte 0

badAddrMsg:
    .text "Invalid address"
    .byte $0D, 0

noDeviceMsg:
    .text "Device not present"
    .byte 0

noDiskMsg:
    .text "No disk in drive"
    .byte 0

volDriveMsg:
    .text "Volume in drive "
    .byte 0

volIsMsg:
    .text " is "
    .byte 0

volIdMsg:
    .text "Volume ID is "
    .byte 0

volParseErrMsg:
    .text "Error reading volume label"
    .byte $0D, 0

