// src/command64/shell.asm
// KickAssembler v5.25 - Command 64 OS shell for C64
// Core command loop: prompt, input, dispatch, built-in commands.

// --- Version Information ---
.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "2"
.const VERSION_STAGE = "15" // Build 2414 Remediation
#import "../../build/build_os.inc"


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
    .text "path  "
    .word cmdPath
tableEnd:

// ---------------------------------------------------------------------------
// Command Shell  (loaded at $1180)
// ---------------------------------------------------------------------------
.segment CommandShell [start=$1180]

// --- Entry point ---
start:
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
    lda VmmSegLo
    sta EnvSegmentLo
    lda VmmSegHi
    sta EnvSegmentHi
    
    // Initialize with double null (empty environment)
    lda #0
    sta VmmOffLo
    sta VmmOffHi
    lda #0                  // Null char
    jsr vmmWriteByte
    inc VmmOffLo
    lda #0                  // Second null
    jsr vmmWriteByte

siSkipEnv:
    lda #$93                // PETSCII clear-screen character
    jsr KernalChROUT
    lda #$0E                // switch C64 to lowercase/uppercase character mode
    jsr KernalChROUT        // required for .text lowercase strings to display correctly

    jsr cmdVer              // Display version banner
mainLoop:
    lda #<promptMsg
    ldy #>promptMsg
    jsr petPrintString

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
    beq sdExitDispatch      // early exit (NOP)
    
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
    tya
    sec
    sbc TempLo
    tax                     // X = length
    beq sdRealBadCmd        // Length 0? No search, just "Bad command"
    
    lda #<CommandBuffer
    clc
    adc TempLo
    sta NamePtrLo
    lda #>CommandBuffer
    adc #0
    sta NamePtrHi
    
    // Check if it exists as .prg
    lda NamePtrLo
    ldy NamePtrHi
    // X = length
    jsr findFile
    bcs sdRealBadCmd        // Not found, print error
    
    // Found it! Load to UserProgStart ($2000)
    lda #0                  // 0 = Relocated (uses HexVal)
    sta SpecificLoad
    lda #<UserProgStart
    sta HexValLo
    lda #>UserProgStart
    sta HexValHi
    
    lda NamePtrLo
    ldy NamePtrHi
    // X = length from findFile
    jsr shellLoadPrg
    bcs sdRealBadCmd
    
    // EXECUTE
    jsr UserProgStart
    rts

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

// EXIT — return to BASIC warm start
// $E37B is the BASIC warm-start entry in C64 ROM: clears state, prints READY., enters command mode.
// If BASIC ROM has been banked out or overwritten, this will crash — acceptable per project decision.
cmdExit:
    jmp $E37B

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
    
    // Calculate length
    tya
    sec
    sbc TempLo
    pha                     // Push length to stack
    
    // Calculate pointer: CommandBuffer + TempLo
    lda #<CommandBuffer
    clc
    adc TempLo
    sta NamePtrLo
    lda #>CommandBuffer
    adc #0
    sta NamePtrHi
    
    // Check for optional address
    ldy TempHi
    jsr shellSkipSpaces
    lda CommandBuffer, y
    beq clHeaderLoad
    
    jsr parseHex
    bcs clHeaderLoad        // Invalid hex -> use header
    lda #0                  // 0 = Relocated (uses HexVal)
    sta SpecificLoad
    jmp clDoLoad
clHeaderLoad:
    lda #1                  // 1 = Absolute (uses Header)
    sta SpecificLoad
clDoLoad:
    pla                     // Pull length to A
    tax                     // Transfer length to X
    lda NamePtrLo           // Restore A from ZP
    ldy NamePtrHi           // Restore Y from ZP
    jsr findFile            // Normalize, append .prg, check disk
    bcs clError             // Not found or error
    
    // findFile returns updated length in X
    lda NamePtrLo
    ldy NamePtrHi
    jsr shellLoadPrg
    bcs clError
    rts
clNoArgs:
    lda #<noFileMsg
    ldy #>noFileMsg
    jsr petPrintString
    rts
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
    lda #1
    ldx #<dirFname
    ldy #>dirFname
    jsr KernalSETNAM
    
    lda #13                 // LFN 13 — clear of handle table (2-9), checkExistence (14), command channel (15)
    ldx CurrentDevice
    ldy #0                  // Secondary 0
    jsr KernalSETLFS

    jsr KernalOPEN
    bcs cdDevError

    ldx #13
    jsr KernalCHKIN
    
    // Skip 2-byte load address
    jsr KernalGetIn
    jsr KernalGetIn
    
cdLineLoop:
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
    
cdReadName:
    jsr KernalGetIn
    beq cdLineDone
    jsr KernalChROUT
    jmp cdReadName
    
cdLineDone:
    lda #PetCr
    jsr KernalChROUT
    
    jsr KernalREADST
    bne cdDone
    jmp cdLineLoop
    
cdDone:
    jsr KernalCLRCHN
    lda #13
    jsr KernalCLOSE
    rts

cdDevError:
    lda #<noDeviceMsg
    ldy #>noDeviceMsg
    jsr petPrintString
    lda #PetCr
    jsr KernalChROUT
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
    lda #<loadErrMsg
    ldy #>loadErrMsg
    jsr petPrintString
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
    lda #<loadErrMsg
    ldy #>loadErrMsg
    jsr petPrintString
    rts

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
    lda #<loadErrMsg
    ldy #>loadErrMsg
    jsr petPrintString
    rts

// COPY — copy a file
cmdCopy:
    ldy ParsePos
    // 1. Skip spaces
ccSkip1:
    lda CommandBuffer, y
    bne ccCheckSpace1
    jmp ccNoArgs            // Long jump
ccCheckSpace1:
    cmp #' '
    bne ccFoundSrc
    iny
    jmp ccSkip1

ccFoundSrc:
    // 2. Copy source name to SourceBuf
    ldx #0
ccCopySrc:
    lda CommandBuffer, y
    bne ccCheckSpace2
    jmp ccNoDest            // Long jump
ccCheckSpace2:
    cmp #' '
    beq ccGotSrc
    sta SourceBuf, x
    inx
    iny
    jmp ccCopySrc
ccGotSrc:
    lda #0
    sta SourceBuf, x
    
    // 3. Skip spaces to find dest
ccSkip2:
    lda CommandBuffer, y
    bne ccCheckSpace3
    jmp ccNoDest            // Long jump
ccCheckSpace3:
    cmp #' '
    bne ccFoundDest
    iny
    jmp ccSkip2

ccFoundDest:
    // 4. Copy dest name to DestBuf
    ldx #0
ccCopyDest:
    lda CommandBuffer, y
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
    
    // 5. Open Source for Read
    lda #0
    sta HexValLo            // mode=0 (Read)
    ldx #<SourceBuf
    ldy #>SourceBuf
    lda #DOS_OPEN_FILE
    jsr apiHandler
    bcs ccOpenErr
    sta SrcHandle           // Use dedicated ZP handle scratch

    // 6. Open Dest for Write
    lda #1
    sta HexValLo            // mode=1 (Write)
    ldx #<DestBuf
    ldy #>DestBuf
    lda #DOS_OPEN_FILE
    jsr apiHandler
    bcs ccCloseSrcErr       // Error opening dest, close source
    sta DstHandle           // Use dedicated ZP handle scratch

    // 7. Copy Loop
ccLoop:
    lda SrcHandle           // Source Handle -> FileHandle for read call
    sta FileHandle
    ldx #<CommandBuffer
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
    rts

ccNoArgs:
ccNoDest:
    lda #<noFileMsg
    ldy #>noFileMsg
    jsr petPrintString
    rts

ccOpenErr:
    lda #<loadErrMsg
    ldy #>loadErrMsg
    jsr petPrintString
    rts

ccCloseSrcErr:
    lda SrcHandle           // source handle — TempLo holds scan index here, not the handle
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr apiHandler
    jmp ccOpenErr

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

    // Parse VAR=VAL
    // For Phase 1: only implementing display.
    // TODO: Implement VAR=VAL parsing and REU storage.
    lda #<notImplMsg
    ldy #>notImplMsg
    jsr petPrintString
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
    lda #PetCr
    jsr KernalChROUT
    
    inc VmmOffLo
    bne cspCheckNext
    inc VmmOffHi
cspCheckNext:
    jsr vmmReadByte
    beq cspDone             // Double null reached
    jmp cspLoop             // More strings follow

cspDone:
    rts

// PATH [path] — display or set search path
cmdPath:
    // Effectively an alias for SET PATH=...
    // For now, just print "not implemented"
    lda #<notImplMsg
    ldy #>notImplMsg
    jsr petPrintString
    rts

notImplMsg:
    .text "Feature not yet fully implemented"
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
// String literals
// ---------------------------------------------------------------------------
promptMsg:
    .text "C64:> "
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
    .text "TYPE   - PRINT FILE CONTENTS"
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
    .text "DRIVE  - SWITCH DEVICE [8-11]"
    .byte $0D
    .text "SET    - ENV VARIABLES"
    .byte $0D
    .text "PATH   - SEARCH PATH"
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
