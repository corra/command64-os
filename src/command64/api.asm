// src/command64/api.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
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

.segment Api

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
    cmp #DOS_DELETE_FILE
    beq ahDelete
    cmp #DOS_RENAME_FILE
    beq ahRename
    cmp #DOS_ALLOC_MEM
    beq ahAllocMem
    cmp #DOS_FREE_MEM
    beq ahFreeMem
    cmp #DOS_EXIT
    beq ahExit
    cmp #DOS_PARSE_PREFIX
    beq ahParsePrefix
    cmp #DOS_SEND_COMMAND
    beq ahSendCommand
    cmp #DOS_VMM_READ
    beq ahVmmRead
    cmp #DOS_VMM_WRITE
    bne apiNotVmmWrite
    jmp ahVmmWrite
apiNotVmmWrite:
    cmp #DOS_RELEASE_L15
    bne apiNotRelease
    jmp ahReleaseL15
apiNotRelease:
    cmp #DOS_GET_SYSTEM_INFO
    bne apiNotGetSysInfo
    jmp ahGetSystemInfo
apiNotGetSysInfo:

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
    // Output: A = Handle on success; Carry = status
    jsr fileOpen
    rts

ahClose:
    // Input: FileHandle (ZP $6D) = Handle to close
    lda FileHandle
    jsr fileClose
    rts

ahRead:
    // Input: FileHandle (ZP $6D) = Handle
    //        X/Y = Destination buffer pointer
    //        HexValLo/Hi = Byte count
    // Save HexValLo/Hi before KERNAL calls inside fileRead clobber it
    lda HexValLo
    sta FileLenLo
    lda HexValHi
    sta FileLenHi

    lda FileHandle
    jsr fileRead
    rts

ahWrite:
    // Input: FileHandle (ZP $6D) = Handle
    //        X/Y = Source buffer pointer
    //        HexValLo/Hi = Byte count
    // Save HexValLo/Hi before KERNAL calls inside fileWrite clobber it
    lda HexValLo
    sta FileLenLo
    lda HexValHi
    sta FileLenHi

    lda FileHandle
    jsr fileWrite
    rts

ahDelete:
    // Input: X/Y = Pointer to filename (null-terminated)
    jsr fileDelete
    rts

ahRename:
    // Input: X/Y = Pointer to Old Name (null-terminated)
    //        PrintPtrLo/Hi = Pointer to New Name (null-terminated)
    jsr fileRename
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
    // Each call orphans 4 bytes (jsr UserProgStart + jsr $1000); stack overflows ~63 runs.
    // Reset SP before returning to shell to prevent accumulation.
    ldx #$FF
    txs
    jmp mainLoop

ahParsePrefix:
    // Input: X = ZP offset of pointer to parse
    // Output: A = resolved device number (8-11 or CurrentDevice)
    //         Carry: 1 = prefix found, 0 = no prefix
    jsr parsePointerDevice
    rts

ahSendCommand:
    // Input: X/Y = Pointer to command string (null-terminated), optionally
    //              prefixed with "<dev>:" (defaults to CurrentDevice)
    //        PrintPtrLo/Hi = Pointer to caller-supplied output buffer
    // Output: Caller's buffer = null-terminated drive response string
    //         Carry = status
    jsr dosSendCommand
    rts

ahVmmRead:
    // Input: VmmSegLo/Hi, VmmOffLo/Hi, VmmBank = source Seg:Off:Bank
    //        X/Y = destination buffer pointer
    //        HexValLo/Hi = byte count
    // Output: destination buffer filled; Carry = status
    jsr vmmReadBlock
    cmp #VMM_SUCCESS
    beq _avrOk
    sec
    rts
_avrOk:
    clc
    rts

ahVmmWrite:
    // Input: VmmSegLo/Hi, VmmOffLo/Hi, VmmBank = destination Seg:Off:Bank
    //        X/Y = source buffer pointer
    //        HexValLo/Hi = byte count
    // Output: Carry = status
    jsr vmmWriteBlock
    cmp #VMM_SUCCESS
    beq _avwOk
    sec
    rts
_avwOk:
    clc
    rts

ahReleaseL15:
    // Ensures KERNAL LFN 15 is genuinely closed and forgets the OS's
    // persistent-open cache for it (L15Device/ensureL15Open, file.asm).
    // Actively closes LFN 15 itself if the cache believes it's open --
    // this is NOT just "tell the OS you closed it yourself" (an earlier,
    // weaker version of this primitive was exactly that, and it wasn't
    // enough: a caller like LABEL needs this BEFORE its own first OPEN of
    // LFN 15 too, when the channel may still be genuinely open from any
    // prior DOS_SEND_COMMAND/checkDeviceReady/readErrorChannel-based
    // command -- LOAD, DIR, VOL, DELETE, RENAME, PATH -- run earlier in
    // the same session; at that point the caller hasn't opened or closed
    // anything itself yet, so a pure flag reset would leave the channel
    // genuinely open and the caller's own OPEN would still conflict).
    // Safe to call whether or not anything is actually cached open.
    // Input: None
    // Output: Carry = 0 (always)
    lda #15
    jsr KernalCLOSE     // Safe even if LFN 15 isn't actually open -- real
                        // KERNAL CLOSE on an unopened logical file is
                        // always a harmless no-op (labelExit already
                        // relies on this same fact).
    lda #0
    sta L15Device
    clc
    rts

ahGetSystemInfo:
    // Input: X = Buffer Pointer Low Byte, Y = Buffer Pointer High Byte
    // Output: Carry = 0 (Success, A = $00), Carry = 1 (Error, A = DOS_ERR_INVALID_ARG)
    
    // Null pointer check: X=0 AND Y=0 is invalid
    stx PrintPtrLo
    sty PrintPtrHi
    txa
    ora PrintPtrHi
    beq _agsiErrNull

    // High address check: destination high byte must be < $D0 (must not write into I/O or ROM)
    // Also must not be in ZP/Stack range (high byte >= $02)
    lda PrintPtrHi
    cmp #$02
    bcc _agsiErrNull
    cmp #$D0
    bcs _agsiErrNull

    // Offset 0: StructVersion = 1
    ldy #SYS_INFO_OFF_VER
    lda #1
    sta (PrintPtrLo), y

    // Offset 1: StructSize = 24 ($18)
    ldy #SYS_INFO_OFF_SIZE
    lda #SYS_INFO_SIZE
    sta (PrintPtrLo), y

    // Offset 2: OsMajor = 4
    ldy #SYS_INFO_OFF_OS_MAJ
    lda #4
    sta (PrintPtrLo), y

    // Offset 3: OsMinor = 0
    ldy #SYS_INFO_OFF_OS_MIN
    lda #0
    sta (PrintPtrLo), y

    // Offset 4: OsStage = 0 (Release)
    ldy #SYS_INFO_OFF_OS_STG
    lda #0
    sta (PrintPtrLo), y

    // Offset 5: CurrentDevice (ZP $BA)
    ldy #SYS_INFO_OFF_DEV
    lda CurrentDevice
    sta (PrintPtrLo), y

    // Offset 6: VideoStandard ($02A6 KernalVideoStd)
    ldy #SYS_INFO_OFF_VIDEO
    lda KernalVideoStd
    sta (PrintPtrLo), y

    // Offset 7-8: UserProgStart ($0800 default)
    ldy #SYS_INFO_OFF_PROG_LO
    lda #<UserProgStart
    sta (PrintPtrLo), y
    ldy #SYS_INFO_OFF_PROG_HI
    lda #>UserProgStart
    sta (PrintPtrLo), y

    // Offset 9-10: UserProgEnd ($BFFF: low $FF, high $BF)
    ldy #SYS_INFO_OFF_END_LO
    lda #$FF
    sta (PrintPtrLo), y
    ldy #SYS_INFO_OFF_END_HI
    lda #$BF
    sta (PrintPtrLo), y

    // Inspect VMM state (vmmInitialized)
    lda vmmInitialized
    beq _agsiNoVmm

    // VMM is initialized!
    // Offset 11: VmmFlags = $01 (Bit 0 active)
    ldy #SYS_INFO_OFF_VMM_FLG
    lda #$01
    sta (PrintPtrLo), y

    // Offset 12-13: VmmPageSize = 4096 ($1000: low $00, high $10)
    ldy #SYS_INFO_OFF_PGSZ_LO
    lda #$00
    sta (PrintPtrLo), y
    ldy #SYS_INFO_OFF_PGSZ_HI
    lda #$10
    sta (PrintPtrLo), y

    // Offset 14-15: VmmTotalPages = 4096 ($1000: low $00, high $10)
    ldy #SYS_INFO_OFF_TOT_LO
    lda #$00
    sta (PrintPtrLo), y
    ldy #SYS_INFO_OFF_TOT_HI
    lda #$10
    sta (PrintPtrLo), y

    // Scan MCT array ($C000-$CFFF) to count allocated and free pages
    // Using HexValLo/Hi ($61/$62) as scratch counter for AllocPages
    lda HexValLo
    pha
    lda HexValHi
    pha

    lda #0
    sta HexValLo            // Alloc counter low
    sta HexValHi            // Alloc counter high

    // Scan 16 pages of 256 bytes = 4096 bytes at $C000
    lda #<VmmMctBase
    sta FileLenLo
    lda #>VmmMctBase
    sta FileLenHi           // Pointer FileLenLo/Hi = $C000

    ldx #16                 // 16 pages
    ldy #0
_agsiMctLoop:
    lda (FileLenLo), y
    cmp #PAGE_FREE          // PAGE_FREE = 0
    beq _agsiMctNext
    inc HexValLo            // non-zero -> allocated page
    bne _agsiMctNext
    inc HexValHi
_agsiMctNext:
    iny
    bne _agsiMctLoop
    inc FileLenHi
    dex
    bne _agsiMctLoop

    // Write VmmAllocPages (HexValLo/Hi)
    ldy #SYS_INFO_OFF_ALC_LO
    lda HexValLo
    sta (PrintPtrLo), y
    ldy #SYS_INFO_OFF_ALC_HI
    lda HexValHi
    sta (PrintPtrLo), y

    // Calculate VmmFreePages = 4096 - VmmAllocPages ($1000 - HexVal)
    sec
    lda #$00
    sbc HexValLo
    tax                     // Free low in X
    lda #$10
    sbc HexValHi
    tay                     // Free high in Y

    // Restore HexValLo/Hi
    pla
    sta HexValHi
    pla
    sta HexValLo

    // Write VmmFreePages (X/Y)
    tya                     // Y is Free high
    pha                     // Save Free high
    ldy #SYS_INFO_OFF_FRE_LO
    txa                     // X is Free low
    sta (PrintPtrLo), y
    ldy #SYS_INFO_OFF_FRE_HI
    pla                     // Restore Free high
    sta (PrintPtrLo), y

    jmp _agsiAppSlots

_agsiNoVmm:
    // VMM inactive
    ldy #SYS_INFO_OFF_VMM_FLG
    lda #0
    sta (PrintPtrLo), y

    // VmmPageSize = 0
    ldy #SYS_INFO_OFF_PGSZ_LO
    sta (PrintPtrLo), y
    ldy #SYS_INFO_OFF_PGSZ_HI
    sta (PrintPtrLo), y

    // VmmTotalPages = 0
    ldy #SYS_INFO_OFF_TOT_LO
    sta (PrintPtrLo), y
    ldy #SYS_INFO_OFF_TOT_HI
    sta (PrintPtrLo), y

    // VmmAllocPages = 0
    ldy #SYS_INFO_OFF_ALC_LO
    sta (PrintPtrLo), y
    ldy #SYS_INFO_OFF_ALC_HI
    sta (PrintPtrLo), y

    // VmmFreePages = 0
    ldy #SYS_INFO_OFF_FRE_LO
    sta (PrintPtrLo), y
    ldy #SYS_INFO_OFF_FRE_HI
    sta (PrintPtrLo), y

_agsiAppSlots:
    // Offset 20: AppMaxSlots = 16 ($10)
    ldy #SYS_INFO_OFF_MAX_SLOT
    lda #APT_MAX_SLOTS
    sta (PrintPtrLo), y

    // Offset 21: AppUsedSlots
    // Count active slots if vmmInitialized != 0 AND AptSegLo|AptSegHi != 0
    lda vmmInitialized
    beq _agsiNoAppSlots
    lda AptSegLo
    ora AptSegHi
    beq _agsiNoAppSlots

    // AppTable is active! Scan slots 0..15
    ldx #0                  // Slot index
    ldy #0                  // Active slots counter
_agsiAppScanLoop:
    cpx #APT_MAX_SLOTS
    bcs _agsiAppScanDone
    txa
    pha
    tya
    pha
    // Call aptSlotBase (X = slot index)
    jsr aptSlotBase         // sets VmmSeg/Off to slot X base
    jsr vmmReadByte         // A = Flags byte of slot X
    pla
    tay
    pla
    tax
    and #APT_FLAG_USED
    beq _agsiAppScanNext
    iny                     // Increment active slot counter
_agsiAppScanNext:
    inx
    jmp _agsiAppScanLoop
_agsiAppScanDone:
    tya                     // A = active slot count
    jmp _agsiWriteAppUsed

_agsiNoAppSlots:
    lda #0
_agsiWriteAppUsed:
    ldy #SYS_INFO_OFF_USD_SLOT
    sta (PrintPtrLo), y

    // Offsets 22-23: Reserved = 0
    lda #0
    ldy #SYS_INFO_OFF_RES0
    sta (PrintPtrLo), y
    ldy #SYS_INFO_OFF_RES1
    sta (PrintPtrLo), y

    // Return success
    lda #DOS_ERR_OK
    clc
    rts

_agsiErrNull:
    lda #DOS_ERR_INVALID_ARG
    sec
    rts
