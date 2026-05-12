// src/command64/api.asm
// INT 21h Service Bus for C64 MS-DOS Port
// Jump Table Entry point: JSR $1600
//
// ABI:
//   Input:  A = Function Number
//           X/Y = Arguments (X=Low/Arg1, Y=High/Arg2)
//   Output: A, X, Y as per function, Carry = Status (0=Success, 1=Error)

.segment ApiStub [start=$1000]
// --- apiStub ---
// Stable entry point for external programs.
// This jump will stay at $1000 even if apiHandler moves.
    jmp apiHandler

.segment Api [start=$1800]

// --- apiHandler ---
// The centralized OS service dispatcher.
apiHandler:
    cld                     // Ensure binary mode for all OS services
    
    // Dispatch based on Function Number in A
    cmp #DOS_PRINT_CHAR
    beq ahPrintChar
    cmp #DOS_PRINT_STR
    beq ahPrintStr
    cmp #DOS_OPEN_FILE
    beq ahOpen
    cmp #DOS_CLOSE_FILE
    beq ahClose
    cmp #DOS_READ_FILE
    beq ahRead
    cmp #DOS_WRITE_FILE
    beq ahWrite
    cmp #DOS_ALLOC_MEM
    beq ahAllocMem
    cmp #DOS_FREE_MEM
    beq ahFreeMem
    cmp #DOS_EXIT
    beq ahExit
    
    // Unknown function — return with error (C=1)
    sec
    rts

ahPrintChar:
    // Input: X = character
    txa
    jsr KernalChROUT
    clc
    rts

ahPrintStr:
    // Input: X/Y = Pointer Lo/Hi
    txa
    // y is already correct (high byte)
    jsr petPrintString
    clc
    rts

ahAllocMem:
    // Input: X/Y = Requested Paragraphs
    stx VmmSegLo
    sty VmmSegHi
    jsr vmmAlloc
    // Returns status in A, SegHi in VmmSegHi, Bank in VmmBank
    // ABI: return SegHi in X, Bank in Y, Status in Carry
    ldx VmmSegHi
    ldy VmmBank
    cmp #VMM_SUCCESS
    beq _acOk
    sec
    rts
_acOk:
    clc
    rts

ahOpen:
    // Input: X/Y = Pointer to filename (null-terminated)
    //        HexValLo = Access mode (0=Read, 1=Write)
    jsr fileOpen
    rts

ahClose:
    // Input: A = Handle
    jsr fileClose
    rts

ahRead:
    // Input: A = Handle
    //        X/Y = Buffer
    //        TempLo/Hi = Bytes to read (passed via ZP)
    jsr fileRead
    rts

ahWrite:
    // Input: A = Handle
    //        X/Y = Buffer
    //        HexValLo/Hi = Bytes to write
    jsr fileWrite
    rts

ahFreeMem:
    // Input: X = Page Index (SegHi), Y = Bank (VmmBank)
    stx VmmSegHi
    sty VmmBank
    jsr vmmFree
    // Returns status in A
    cmp #VMM_SUCCESS
    beq _afOk
    sec
    rts
_afOk:
    clc
    rts

ahExit:
    // DOS_EXIT: return to shell main loop.
    // This orphans the return address from the JSR $1600 and the JSR UserProgStart,
    // but effectively terminates the program and resets the shell state.
    jmp mainLoop
