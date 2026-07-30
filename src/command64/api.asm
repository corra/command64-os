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
//
// WHY A TABLE AND NOT A COMPARE CHAIN
// -----------------------------------
// This was a linear `cmp #FUNC / beq handler` chain until the service count
// reached 18, at which point the earliest entries' branches had to clear the
// whole rest of the chain and blew the 6502's 128-byte relative range
// ("jump distance is too far: 131"). Rewriting each entry as `bne skip / jmp
// handler` cures the range but costs +3 bytes per service -- the wrong
// direction, because the Api segment must fit below the ApiStub pinned at
// $1000 and that region is full.
//
// A table costs a fixed 3 bytes per service and never branches across the
// dispatch body, so neither ceiling can be hit again by adding a service.
// Adding one now means adding one row to the three tables below; nothing else
// in this routine changes.
//
// Cost: dispatch is a scan rather than a straight-line compare, so a service
// at index i costs roughly 11*i cycles plus a ~24-cycle trampoline. That is
// real but immaterial next to what the services themselves do (disk I/O, REU
// transfers, screen output), and the table is ordered hottest-first to keep
// the common cases at the front.
apiHandler:
    cld                     // Ensure binary mode for all OS services

    // X is an ARGUMENT register in this ABI (X = Low/Arg1), but it is also the
    // only sane index for the tables below, so stash the caller's value and put
    // it back immediately before entering the handler. The old compare chain
    // never touched X, and every pointer-taking service (DOS_PRINT_STR,
    // DOS_OPEN_FILE, DOS_ALLOC_MEM, ...) depends on that.
    stx apiSavedX

    // Dispatch based on Function Number in A. Scanning upward (rather than
    // down from the end) is what makes the hottest services the cheapest,
    // since they sit at the front of apiFuncTable.
    ldx #0
apiFindLoop:
    cmp apiFuncTable, x
    beq apiFound
    inx
    cpx #API_SERVICE_COUNT
    bne apiFindLoop

    // Unknown function — return with error (C=1). Restore X here too: the
    // scan clobbered it, and the old compare chain returned the caller's
    // registers untouched on this path.
    ldx apiSavedX
    sec
    rts

apiFound:
    // Reach the handler by RTS-trampoline: push its address minus one (high
    // byte first, as RTS pops low-then-high and increments), then RTS.
    //
    // The alternative -- patching a `jmp $FFFF` operand in place -- would be a
    // few cycles cheaper but makes the dispatcher non-reentrant, so an API
    // call from interrupt context could corrupt one already in flight. Not
    // worth it for a handful of cycles.
    lda apiVectorHi, x
    pha
    lda apiVectorLo, x
    pha
    // Restore A = function number. No current handler reads it (every one
    // opens with txa/jsr/lda/stx/ldx), but the published ABI at the top of
    // this file states A holds the function number on entry, so honour it
    // rather than silently narrowing the contract.
    lda apiFuncTable, x
    // Restore the caller's X argument, which the table scan above consumed.
    // Must be the last thing before RTS: nothing after it may use X.
    ldx apiSavedX
    // Register state entering the handler now matches the old compare chain:
    // A = function number, X/Y = the caller's arguments, C = 1 (set by the
    // matching CMP above; LDA/LDX do not touch it). Only Z/N differ -- the
    // chain left Z=1 from its CMP, this leaves them from the final LDX. No
    // handler branches on flags before setting them, so that is safe.
    rts

// Service dispatch tables. The three are parallel: row i of apiFuncTable is
// the function number reached via row i of apiVectorLo/apiVectorHi. Ordered
// hottest-first (character and string output dominate call volume).
//
// Vectors store handler-minus-one because RTS increments the popped address.
//
// These live in ApiExt, not Api: absolute-indexed reads resolve at link time
// and do not care which segment the data sits in, so keeping 3 bytes per
// service out of the scarce sub-$1000 region costs nothing. It also means
// adding a service consumes no space below the pinned ApiStub at all.
.segment ApiExt

// Holding pen for the caller's X across the table scan. One byte, static:
// that makes the dispatcher non-reentrant, which is the same constraint the
// OS already has everywhere else (no service is safe to re-enter from an
// interrupt mid-call).
apiSavedX:
    .byte 0

apiFuncTable:
    .byte DOS_PRINT_CHAR, DOS_PRINT_STR
    .byte DOS_OPEN_FILE, DOS_CLOSE_FILE, DOS_READ_FILE, DOS_WRITE_FILE
    .byte DOS_DELETE_FILE, DOS_RENAME_FILE
    .byte DOS_ALLOC_MEM, DOS_FREE_MEM, DOS_EXIT
    .byte DOS_PARSE_PREFIX, DOS_SEND_COMMAND
    .byte DOS_VMM_READ, DOS_VMM_WRITE, DOS_RELEASE_L15
    .byte DOS_GET_SYSTEM_INFO, DOS_GET_APP_INFO
.label API_SERVICE_COUNT = * - apiFuncTable

apiVectorLo:
    .byte <(ahPrintChar - 1), <(ahPrintStr - 1)
    .byte <(ahOpen - 1), <(ahClose - 1), <(ahRead - 1), <(ahWrite - 1)
    .byte <(ahDelete - 1), <(ahRename - 1)
    .byte <(ahAllocMem - 1), <(ahFreeMem - 1), <(ahExit - 1)
    .byte <(ahParsePrefix - 1), <(ahSendCommand - 1)
    .byte <(ahVmmRead - 1), <(ahVmmWrite - 1), <(ahReleaseL15 - 1)
    .byte <(ahGetSystemInfo - 1), <(ahGetAppInfo - 1)

apiVectorHi:
    .byte >(ahPrintChar - 1), >(ahPrintStr - 1)
    .byte >(ahOpen - 1), >(ahClose - 1), >(ahRead - 1), >(ahWrite - 1)
    .byte >(ahDelete - 1), >(ahRename - 1)
    .byte >(ahAllocMem - 1), >(ahFreeMem - 1), >(ahExit - 1)
    .byte >(ahParsePrefix - 1), >(ahSendCommand - 1)
    .byte >(ahVmmRead - 1), >(ahVmmWrite - 1), >(ahReleaseL15 - 1)
    .byte >(ahGetSystemInfo - 1), >(ahGetAppInfo - 1)

// Build-time guard: the three tables must stay the same length, or a service
// would dispatch through another's vector -- a silent, hard-to-trace fault.
// Adding a row to one table and forgetting another now fails the build here.
// (.errorif, not .if -- label arithmetic is not available in Kick's first
// parse, which is the only place .if conditions may be evaluated.)
.errorif ((apiVectorHi - apiVectorLo) != API_SERVICE_COUNT), "apiVectorLo length does not match apiFuncTable"
.errorif ((* - apiVectorHi) != API_SERVICE_COUNT), "apiVectorHi length does not match apiFuncTable"

// Back to Api for the handler bodies that still fit below $1000.
.segment Api

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

// ---------------------------------------------------------------------------
// Everything below lives in ApiExt, packed after ShellExt, NOT in the Api
// segment with the dispatcher.
//
// The Api/Loader/Path/Vmm/File chain has to fit entirely below the ApiStub
// pinned at $1000 (external apps hardcode `jsr $1000`, so it can never move),
// and that region is full -- these two handlers alone overflowed File by 628
// bytes into the stub. They are reached through apiHandler's dispatch table,
// which does not care where a handler lives, so relocating the bodies costs
// nothing at the call site.
//
// New API services with more than a trivial body belong here for the same
// reason. Keep the dispatcher and its tables in Api; put the work here.
// ---------------------------------------------------------------------------
.segment ApiExt

ahGetSystemInfo:
    // Input: X = Buffer Pointer Low Byte, Y = Buffer Pointer High Byte
    // Output: Carry = 0 (Success, A = $00), Carry = 1 (Error, A = DOS_ERR_INVALID_ARG)
    
    // Null pointer check: X=0 AND Y=0 is invalid
    stx PrintPtrLo
    sty PrintPtrHi
    txa
    ora PrintPtrHi
    bne _agsiPtrNotNull
    jmp _agsiErrNull
_agsiPtrNotNull:

    // High address check: destination high byte must be < $D0 (must not write into I/O or ROM)
    // Also must not be in ZP/Stack range (high byte >= $02)
    lda PrintPtrHi
    cmp #$02
    bcs _agsiNotLow
    jmp _agsiErrNull
_agsiNotLow:
    cmp #$D0
    bcc _agsiNotHigh
    jmp _agsiErrNull
_agsiNotHigh:

    // Offset 0: StructVersion = 2 (WP6 amendment: offset 22 is now OsPatch,
    // not Reserved0 -- see brain/plans/2026-07-26-casm-dash-wp1-api-contract-
    // freeze.md section 7)
    ldy #SYS_INFO_OFF_VER
    lda #SYS_INFO_STRUCT_VER
    sta (PrintPtrLo), y

    // Offset 1: StructSize = 24 ($18)
    ldy #SYS_INFO_OFF_SIZE
    lda #SYS_INFO_SIZE
    sta (PrintPtrLo), y

    // Offset 2: OsMajor -- from VERSION via build_config.inc (OsVersionMajor),
    // not a hardcoded immediate (WP6 amendment)
    ldy #SYS_INFO_OFF_OS_MAJ
    lda #OsVersionMajor
    sta (PrintPtrLo), y

    // Offset 3: OsMinor -- from VERSION via build_config.inc (OsVersionMinor)
    ldy #SYS_INFO_OFF_OS_MIN
    lda #OsVersionMinor
    sta (PrintPtrLo), y

    // Offset 4: OsStage -- from VERSION's optional "-dev" suffix via
    // build_config.inc (OsVersionStage): 0=Release, 1=Dev
    ldy #SYS_INFO_OFF_OS_STG
    lda #OsVersionStage
    sta (PrintPtrLo), y

    // Offset 5: CurrentDevice (ZP $BA)
    ldy #SYS_INFO_OFF_DEV
    lda CurrentDevice
    sta (PrintPtrLo), y

    // Offset 6: VideoStandard ($02A6 KernalVideoStd)
    ldy #SYS_INFO_OFF_VIDEO
    lda KernalVideoStd
    sta (PrintPtrLo), y

    // Offset 7-8: UserProgStart (the configured origin, $3800 in the default
    // build -- comes from build_config.inc, so it tracks USER_PROG_START_HEX
    // rather than any fixed address)
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

    // Offset 22: OsPatch -- from VERSION via build_config.inc (OsVersionPatch)
    // (formerly Reserved0/$00; WP6 amendment bumped StructVersion to 2)
    ldy #SYS_INFO_OFF_OS_PAT
    lda #OsVersionPatch
    sta (PrintPtrLo), y

    // Offset 23: Reserved1 = 0
    lda #0
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

ahGetAppInfo:
    // Input: HexValLo ($61) = Requested Slot Index (0..15)
    //        X = Buffer Pointer Low Byte
    //        Y = Buffer Pointer High Byte
    // Output: Carry = 0 (Success, A = $00), Carry = 1 (Error, A = Error Code)

    // 1. Validate Slot Index: HexValLo must be < APT_MAX_SLOTS (16)
    lda HexValLo
    cmp #APT_MAX_SLOTS
    bcc _agaiIndexOk
    lda #DOS_ERR_INVALID_INDEX  // $01
    sec
    rts

_agaiIndexOk:
    pha                         // Save slot index on stack

    // 2. Validate Buffer Pointer (X/Y)
    stx PrintPtrLo
    sty PrintPtrHi
    txa
    ora PrintPtrHi
    beq _agaiErrNull

    // High address check: destination high byte must be < $D0 and >= $02
    lda PrintPtrHi
    cmp #$02
    bcc _agaiErrNull
    cmp #$D0
    bcs _agaiErrNull

    // 3. Validate AppTable Subsystem (vmmInitialized != 0 AND AptSegLo|AptSegHi != 0)
    lda vmmInitialized
    beq _agaiErrUnavail
    lda AptSegLo
    ora AptSegHi
    beq _agaiErrUnavail

    // 4. Position to slot entry base using aptSlotBase (X = slot index)
    pla                         // Restore slot index into A
    pha                         // Save again for record writing
    tax                         // X = slot index
    jsr aptSlotBase             // sets VmmSegLo/Hi and VmmOffLo/Hi (APT_HEADER_SIZE + X*40)
                                // clobbers A, DstHandle (= 0), preserves X

    // Read Flags byte (offset 0 in entry)
    jsr vmmReadByte             // A = Flags byte
    tay                         // Y = Flags byte
    and #APT_FLAG_USED
    bne _agaiSlotOccupied

    // Slot is unallocated! Return DOS_ERR_SLOT_EMPTY ($02) with buffer UNCHANGED
    pla                         // Clean stack
    lda #DOS_ERR_SLOT_EMPTY
    sec
    rts

_agaiErrNull:
    pla                         // Clean stack
    lda #DOS_ERR_INVALID_ARG
    sec
    rts

_agaiErrUnavail:
    pla                         // Clean stack
    lda #DOS_ERR_UNAVAILABLE
    sec
    rts

_agaiSlotOccupied:
    // Y contains raw Flags byte
    // Stack contains requested slot index

    // Write Offset 0: StructVersion = 1
    ldx #APP_INFO_OFF_VER
    lda #1
    sta (PrintPtrLo), x

    // Write Offset 1: StructSize = 24 ($18)
    ldx #APP_INFO_OFF_SIZE
    lda #APP_INFO_SIZE
    sta (PrintPtrLo), x

    // Write Offset 2: SlotIndex (from stack)
    pla                         // A = SlotIndex
    ldx #APP_INFO_OFF_SLOT
    sta (PrintPtrLo), x

    // Write Offset 3: Flags (Y)
    tya                         // A = Flags
    ldx #APP_INFO_OFF_FLAGS
    sta (PrintPtrLo), x

    // Read LoadAddr (offset 17 in entry, APT_OFF_ADDR)
    // Advance VmmOffLo by 17
    clc
    lda VmmOffLo
    adc #APT_OFF_ADDR
    sta VmmOffLo
    bcc _agaiReadLoad
    inc VmmOffHi
_agaiReadLoad:
    jsr vmmReadByte             // LoadAddr lo
    ldx #APP_INFO_OFF_LOAD_LO
    sta (PrintPtrLo), x

    inc VmmOffLo
    bne _agaiReadLoadHi
    inc VmmOffHi
_agaiReadLoadHi:
    jsr vmmReadByte             // LoadAddr hi
    ldx #APP_INFO_OFF_LOAD_HI
    sta (PrintPtrLo), x

    // Read Size (offset 19 in entry, APT_OFF_SIZE)
    inc VmmOffLo
    bne _agaiReadSizeLo
    inc VmmOffHi
_agaiReadSizeLo:
    jsr vmmReadByte             // Size lo
    ldx #APP_INFO_OFF_SIZE_LO
    sta (PrintPtrLo), x

    inc VmmOffLo
    bne _agaiReadSizeHi
    inc VmmOffHi
_agaiReadSizeHi:
    jsr vmmReadByte             // Size hi
    ldx #APP_INFO_OFF_SIZE_HI
    sta (PrintPtrLo), x

    // Read 16-byte Name field (offset 1 in entry, APT_OFF_NAME)
    ldx #APP_INFO_OFF_SLOT
    lda (PrintPtrLo), x         // reload SlotIndex
    tax
    jsr aptSlotBase             // VmmOff = entry base
    inc VmmOffLo                // base + 1 = APT_OFF_NAME

    // Read up to 16 raw PETSCII bytes into fileScratch
    ldx #0                      // name byte index 0..15
_agaiNameLoop:
    cpx #16
    bcs _agaiNameMeasured
    txa
    pha
    jsr vmmReadByte             // A = name byte
    pla
    tax
    sta fileScratch, x
    inc VmmOffLo
    bne _agaiNextChar
    inc VmmOffHi
_agaiNextChar:
    inx
    jmp _agaiNameLoop

_agaiNameMeasured:
    // Count string length: number of bytes before first $00 (max 15)
    ldx #0                      // length counter
_agaiLenLoop:
    cpx #15
    bcs _agaiLenDone
    lda fileScratch, x
    beq _agaiLenDone
    inx
    jmp _agaiLenLoop
_agaiLenDone:
    txa                         // A = NameLen (0..15)
    ldy #APP_INFO_OFF_NAME_LEN
    sta (PrintPtrLo), y

    // Copy 15 bytes from fileScratch into destination NameData (offset 9..23)
    ldy #0
_agaiCopyNameLoop:
    cpy #15
    bcs _agaiCopyDone
    tya
    clc
    adc #APP_INFO_OFF_NAME_DATA // = 9
    tax                         // X = destination index (9..23)
    tya
    pha
    lda fileScratch, y
    sta (PrintPtrLo), x
    pla
    tay
    iny
    jmp _agaiCopyNameLoop

_agaiCopyDone:
    // Success
    lda #DOS_ERR_OK
    clc
    rts
