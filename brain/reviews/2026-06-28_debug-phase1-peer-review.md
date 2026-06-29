# Peer Review: DEBUG Utility Phase 1 Feature Completeness

- **Date**: 2026-06-28
- **Reviewer**: Gemini 3.5 Flash (Medium)
- **Target**: `src/external/debug/debug.asm` (uncommitted local changes for commands `N`, `L`, `W`)
- **Plan Reference**: `brain/plans/debug-phase1-registers-io.md`

---

## 1. Overview of Reviewed Changes

The local workspace changes implement the baseline functionality for filename configuration (`N`), program loading (`L`), and segment writing (`W`):

1. **Command `N` (Name)**: Successfully reads a filename from the command line and copies it to `fileNameBuf` (up to 32 characters).
2. **Command `L` (Load)**: Connects to the KERNAL API (`SETNAM`, `SETLFS`, `LOAD`) to load the program either via the file header address or relocated to a user-provided target address.
3. **Command `W` (Write)**: Writes raw memory blocks byte-by-byte into the disk channel. The custom loop correctly handles `PRG` (prepending load address header) as well as raw `SEQ`/`USR` file types.
4. **Command Dispatcher**: Fixed the dispatcher loop boundary. When branching, it now uses an inline `rts` instruction on an empty command line to avoid branch out-of-range limits for `dExit` (`bne dSkipCheck`).
5. **Registers**: Added `KernalSAVE` equate mapping to `$FFD8` in `include/command64.inc`.

---

## 2. Key Findings & Critical Deficiencies

While the implementations of `N`, `L`, and `W` are structurally clean, the review identified four critical findings that must be resolved to meet the project's standards and complete the Phase 1 goals.

### Finding 1: Register Modification (`R [register]`) is Missing (Critical)

- **Status**: **Not Implemented**
- **Impact**: The design plan requires `R [register]` to view and modify individual registers (`A`, `X`, `Y`, `P`, or `S`). The current code only supports printing all registers and has no parsing or interactive loop for individual registers.
- **Remediation**: Expand `cmdRegs` to check for register arguments, print the select register value, prompt with a colon (`:`), wait for keyboard input using `readLine`, and overwrite the corresponding register variables (`regA`, `regX`, `regY`, `regP`, `regS`).

### Finding 2: `currentAddr` is Not Updated Upon Successful Load (Major)

- **Status**: **Bug**
- **Impact**: The design plan requires updating `currentAddr` to the program's starting address upon a successful load. Currently, `cmdLoad` executes the load but leaves `currentAddr` unchanged, meaning subsequent `D` (Dump) or `U` (Unassemble) commands still target the old address.
- **Remediation**:
  - For relocated loads, set `currentAddr` to `val1` (the user-specified address).
  - For header-based loads, read the starting address from KERNAL's `$C1/$C2` (`MEMUSS`) pointer (where the starting address is stored after a successful load).

### Finding 3: Missing Bounds Check on Write Command Range (Major)

- **Status**: **Bug**
- **Impact**: If a user runs `W` with a range where `rangeStart > rangeEnd` (e.g., `W 2010 2000`), the manual byte write loop will wrap around 64KB RAM and write indefinitely, corrupting disk files or hanging the system.
- **Remediation**: Add a 16-bit comparison (`rangeEnd >= rangeStart`) before entering `cwWriteLoop`.

### Finding 4: Silent Fallback on Parse Error in `L` (Minor)

- **Status**: **Bug**
- **Impact**: If the user provides a malformed address parameter (e.g. `L G000`), `cmdLoad` silently falls back to loading from the file header instead of aborting and reporting a syntax error.
- **Remediation**: Check if an argument exists first. If so, call `parseHexArg` and explicitly branch to `cdErr` if it fails.

---

## 3. Remediation Implementation Details

### Remediation A: Interactive Register Modification (`R [register]`)

Replace `cmdRegs` in `src/external/debug/debug.asm` with:

```asm
cmdRegs:
    jsr skipSpaces
    lda inputBuf, y
    beq printAllRegs
    
    // Save register name char, then check that it's exactly 1 character
    tax                 // X = char
    iny
    lda inputBuf, y
    beq regNameOk
    cmp #' '
    beq regNameOk
    jmp cdErr           // invalid register name if extra characters follow
regNameOk:
    txa
    ora #$20            // normalize to lowercase
    cmp #'a'
    beq modifyA
    cmp #'x'
    beq modifyX
    cmp #'y'
    beq modifyY
    cmp #'p'
    beq modifyP
    cmp #'s'
    beq modifyS
    jmp cdErr

modifyA:
    lda #'A'
    ldx #<regA
    ldy #>regA
    jmp modifyReg
modifyX:
    lda #'X'
    ldx #<regX
    ldy #>regX
    jmp modifyReg
modifyY:
    lda #'Y'
    ldx #<regY
    ldy #>regY
    jmp modifyReg
modifyP:
    lda #'P'
    ldx #<regP
    ldy #>regP
    jmp modifyReg
modifyS:
    lda #'S'
    ldx #<regS
    ldy #>regS
    jmp modifyReg

modifyReg:
    stx val1
    sty val1 + 1
    
    // Print register name and current value, e.g. "A xx"
    jsr KernalChROUT
    lda #' '
    jsr KernalChROUT
    ldy #0
    lda (val1), y
    jsr printHex8
    lda #PetCr
    jsr KernalChROUT
    
    // Print prompt and read line
    lda #':'
    jsr KernalChROUT
    jsr readLine
    
    // If empty input, leave unmodified
    ldy #0
    jsr skipSpaces
    lda inputBuf, y
    beq mrDone
    
    // Parse hex byte (must fit in 8 bits)
    jsr parseHexArg
    bcs mrErr
    lda HexValHi
    bne mrErr           // must be 8-bit
    jsr skipSpaces
    lda inputBuf, y
    bne mrErr           // extra trailing characters -> error
    
    lda HexValLo
    ldy #0
    sta (val1), y
mrDone:
    rts
mrErr:
    jmp cdErr

printAllRegs:
    // Print A=.. X=.. Y=.. P=.. S=..
    lda #'A'
    jsr KernalChROUT
    lda #'='
    jsr KernalChROUT
    lda regA
    jsr printHex8
    
    lda #' '
    jsr KernalChROUT
    lda #'X'
    jsr KernalChROUT
    lda #'='
    jsr KernalChROUT
    lda regX
    jsr printHex8

    lda #' '
    jsr KernalChROUT
    lda #'Y'
    jsr KernalChROUT
    lda #'='
    jsr KernalChROUT
    lda regY
    jsr printHex8

    lda #' '
    jsr KernalChROUT
    lda #'P'
    jsr KernalChROUT
    lda #'='
    jsr KernalChROUT
    lda regP
    jsr printHex8

    lda #' '
    jsr KernalChROUT
    lda #'S'
    jsr KernalChROUT
    lda #'='
    jsr KernalChROUT
    lda regS
    jsr printHex8
    
    lda #PetCr
    jsr KernalChROUT
    rts
```

### Remediation B: Load Address Tracking & Syntax Error Checks

Modify `cmdLoad` in `src/external/debug/debug.asm` to:

1. Return `cdErr` if the address argument is malformed.
2. Update `currentAddr` using either `val1` (relocated) or `$C1/$C2` (header).

```asm
cmdLoad:
    lda fileNameLen
    bne clHaveName
    jmp cdErr
clHaveName:
    jsr skipSpaces
    lda inputBuf, y
    beq clFromHeader
    jsr parseHexArg
    bcc clRelocate
    jmp cdErr
clRelocate:
    // Relocating load: save target address then SETNAM/SETLFS/LOAD
    lda HexValLo
    sta val1
    lda HexValHi
    sta val1 + 1
    lda fileNameLen
    ldx #<fileNameBuf
    ldy #>fileNameBuf
    jsr KernalSETNAM
    lda #1              // LFN=1
    ldx CurrentDevice
    ldy #0              // SA=0: use address from X/Y in LOAD call
    jsr KernalSETLFS
    lda #0              // 0=load (not verify)
    ldx val1
    ldy val1 + 1
    jsr KernalLOAD
    bcs clErr
    
    // Update currentAddr to the load address
    lda val1
    sta currentAddr
    lda val1 + 1
    sta currentAddr + 1
    rts
clFromHeader:
    lda fileNameLen
    ldx #<fileNameBuf
    ldy #>fileNameBuf
    jsr KernalSETNAM
    lda #1              // LFN=1
    ldx CurrentDevice
    ldy #1              // SA=1: use PRG header address
    jsr KernalSETLFS
    lda #0              // 0=load
    ldx #0
    ldy #0
    jsr KernalLOAD
    bcs clErr
    
    // Update currentAddr to start address stored in MEMUSS ($C1/$C2) by KERNAL
    lda $C1
    sta currentAddr
    lda $C2
    sta currentAddr + 1
    rts
clErr:
    lda #<errUnknown
    ldy #>errUnknown
    jsr API_PRINT_STR
    rts
```

### Remediation C: Bounds Checking in Write Command

Insert a 16-bit range check in `cmdWrite` in `src/external/debug/debug.asm` under the `cwHaveRange` label before building the filename open string:

```asm
cwHaveRange:
    // Verify rangeStart <= rangeEnd to prevent infinite wrapping loops
    lda rangeEnd + 1
    cmp rangeStart + 1
    bcc cwNoRange        // end hi < start hi -> error
    bne cwRangeValid     // end hi > start hi -> valid
    lda rangeEnd
    cmp rangeStart
    bcc cwNoRange        // end lo < start lo -> error
cwRangeValid:
    lda fileNameLen
    bne cwHaveName
    jmp cdErr
```
