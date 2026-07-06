// src/command64/apptable.asm
// KickAssembler v5.25 — App Table Phase A
// Manages a 16-slot loaded-program registry in one VMM-allocated 4KB page.
// Entry stride: APT_ENTRY_SIZE = 40 bytes. Header: 4 bytes at VMM offset 0.

.segment AppTable

// Overlap check temporary variables (stored in safe Cassette Buffer workspace)
.label AptTempLoadLo = $03F4
.label AptTempLoadHi = $03F5
.label AptTempSizeLo = $03F6
.label AptTempSizeHi = $03F7
.label AptTempEndLo  = $03F8
.label AptTempEndHi  = $03F9

// -----------------------------------------------------------------------
// aptSlotBase — set VmmSeg/Off to the base of slot X's entry
// Input:  X = slot index 0..APT_MAX_SLOTS-1
// Output: VmmSegLo/Hi = AptSegLo/Hi; VmmOffLo/Hi = APT_HEADER_SIZE + X*APT_ENTRY_SIZE
// Clobbers: A, DstHandle (= 0 on return)
// Preserves: X
// -----------------------------------------------------------------------
aptSlotBase:
    lda AptSegLo
    sta VmmSegLo
    lda AptSegHi
    sta VmmSegHi
    stx DstHandle           // countdown (DstHandle, not X — X is unchanged)
    lda #APT_HEADER_SIZE    // start offset = 4
    sta VmmOffLo
    lda #0
    sta VmmOffHi
    lda DstHandle
    beq asbDone
asbLoop:
    clc
    lda VmmOffLo
    adc #APT_ENTRY_SIZE     // += 40 per slot
    sta VmmOffLo
    bcc asbNoCarry
    inc VmmOffHi
asbNoCarry:
    dec DstHandle
    bne asbLoop
asbDone:
    rts

// -----------------------------------------------------------------------
// aptInit — allocate one VMM page; write table header
// Call once from shell startup after env block alloc, inside the vmmInitialized block.
// Idempotent: returns immediately if AptSegLo/Hi already non-zero.
// -----------------------------------------------------------------------
aptInit:
    lda AptSegLo
    ora AptSegHi
    bne aiDone              // non-zero: already allocated
    lda #0
    sta VmmSegLo
    lda #1                  // 256 paragraphs = 4KB = 1 VMM page
    sta VmmSegHi
    jsr vmmAlloc
    lda VmmSegLo
    sta AptSegLo
    lda VmmSegHi
    sta AptSegHi

    // Zero the entire 4KB app table segment to prevent random memory garbage from corrupting slots
    lda #0
    sta VmmOffLo
    sta VmmOffHi
    ldx #16                 // 16 pages of 256 bytes = 4096 bytes
aiZeroOuter:
aiZeroByte:
    lda #0
    jsr vmmWriteByte        // clobbers A and Y, preserves X
    inc VmmOffLo
    bne aiZeroByte          // loop until VmmOffLo wraps (256 bytes = 1 page)
    inc VmmOffHi            // next page
    dex
    bne aiZeroOuter         // repeat for all 16 pages

    // Write header at VMM offset 0: MaxSlots, UsedSlots=0, reserved×2
    lda AptSegLo
    sta VmmSegLo
    lda AptSegHi
    sta VmmSegHi
    lda #0
    sta VmmOffLo
    sta VmmOffHi
    lda #APT_MAX_SLOTS      // offset 0: MaxSlots = 16
    jsr vmmWriteByte
    inc VmmOffLo
    lda #0
    jsr vmmWriteByte        // offset 1: UsedSlots = 0
    inc VmmOffLo
    jsr vmmWriteByte        // offset 2: reserved
    inc VmmOffLo
    jsr vmmWriteByte        // offset 3: reserved
aiDone:
    rts

// -----------------------------------------------------------------------
// aptProtectedCheck — reject load addresses in protected regions
// Protected: $0000-$21FF (OS + AppTable), $C000-$FFFF (VMM MCT, I/O, KERNAL)
// Input:  HexValLo/Hi = proposed load address
// Output: carry set = protected (reject), carry clear = OK
// Clobbers: A
// -----------------------------------------------------------------------
aptProtectedCheck:
    lda HexValHi
    cmp #>UserProgStart       // addr < UserProgStart?
    bcc apcProtected
    cmp #$C0                // addr >= $C000?
    bcs apcProtected
    clc
    rts
apcProtected:
    sec
    rts

// -----------------------------------------------------------------------
// aptNameMatch — compare SrcHandle bytes from NamePtrLo/Hi against VMM name field
// Entry name starts at current VmmOffLo/Hi. Null-padded to 16 bytes.
// Input:  VmmSegLo/Hi and VmmOffLo/Hi set to name field start
//         SrcHandle = search name byte count
//         NamePtrLo/Hi = pointer to search name (NOT modified)
// Output: carry clear = full match; carry set = no match
// Clobbers: A, Y, DstHandle, VmmOffLo (advanced SrcHandle+1 bytes on any path)
// Preserves: X, NamePtrLo/Hi
// -----------------------------------------------------------------------
aptNameMatch:
    lda #0
    sta aptNameIndex        // byte index 0..SrcHandle-1
    lda SrcHandle
    sta DstHandle           // byte countdown
anmLoop:
    lda DstHandle
    beq anmCheckEnd
    jsr vmmReadByte         // A = entry name byte; Y clobbered
    ldy aptNameIndex        // reload index (Y clobbered by vmmReadByte)
    cmp (NamePtrLo), y      // compare against search name[aptNameIndex]
    bne anmMiss
    inc VmmOffLo            // advance VMM name position
    inc aptNameIndex        // advance search index
    dec DstHandle
    jmp anmLoop
anmCheckEnd:
    // All bytes matched; verify entry name is not longer (next byte must be $00)
    jsr vmmReadByte
    inc VmmOffLo
    cmp #0
    bne anmMiss             // entry name is longer → no match
    clc
    rts
anmMiss:
    sec
    rts

// -----------------------------------------------------------------------
// aptFind — scan app table for a matching name or address
// Input:  carry clear = name mode: NamePtrLo/Hi = name ptr, SrcHandle = name length
//         carry set   = address mode: HexValLo/Hi = load address to match
// Output: carry clear + X = slot index on found; carry set = not found
//         On found: HandlerVecLo/Hi = LoadAddr from the matched entry
// Clobbers: A, Y, DstHandle, VmmSegLo/Hi, VmmOffLo/Hi
// Preserves: SrcHandle, NamePtrLo/Hi, HexValLo/Hi
// -----------------------------------------------------------------------
aptFind:
    bcs afSetAddrMode
    lda #0                  // name mode
    .byte $2C               // BIT $xxxx — skip next lda #1
afSetAddrMode:
    lda #1                  // address mode
    sta aptSearchMode
    ldx #0                  // slot counter
afScanLoop:
    cpx #APT_MAX_SLOTS
    bcs afNotFound
    jsr aptSlotBase         // VmmSeg/Off = entry base; X preserved; DstHandle = 0
    jsr vmmReadByte         // A = Flags
    and #APT_FLAG_USED
    beq afNextSlot          // skip unused slots
    lda aptSearchMode
    bne afCheckAddr
    // --- Name search ---
    inc VmmOffLo            // advance to APT_OFF_NAME (base + 1)
    jsr aptNameMatch        // carry clear = match
    bcc afFound
    jmp afNextSlot
afCheckAddr:
    // --- Address search: advance to APT_OFF_ADDR (base + 17) ---
    clc
    lda VmmOffLo
    adc #APT_OFF_ADDR       // = 17
    sta VmmOffLo
    bcc afAddrRead
    inc VmmOffHi
afAddrRead:
    jsr vmmReadByte         // A = LoadAddr lo
    cmp HexValLo
    bne afNextSlot
    inc VmmOffLo
    jsr vmmReadByte         // A = LoadAddr hi
    cmp HexValHi
    bne afNextSlot
    // Address match — fall through to afFound
afFound:
    // Load HandlerVecLo/Hi from LoadAddr field (reset VmmOff to base + APT_OFF_ADDR)
    jsr aptSlotBase
    clc
    lda VmmOffLo
    adc #APT_OFF_ADDR
    sta VmmOffLo
    bcc afReadLo
    inc VmmOffHi
afReadLo:
    jsr vmmReadByte
    sta HandlerVecLo
    inc VmmOffLo
    jsr vmmReadByte
    sta HandlerVecHi
    clc
    rts
afNextSlot:
    inx
    jmp afScanLoop
afNotFound:
    sec
    rts

// -----------------------------------------------------------------------
// aptRemove — clear a slot entry and decrement UsedSlots
// Phase A: does not touch REU backing store (no REU_BACKED entries yet).
// Input:  X = slot index (from aptFind)
// Output: carry clear always
// Clobbers: A, DstHandle, VmmSegLo/Hi, VmmOffLo/Hi
// Preserves: X
// -----------------------------------------------------------------------
aptRemove:
    // Zero the Flags byte (clears SLOT_USED and all other flags)
    jsr aptSlotBase         // VmmSeg/Off = entry base
    lda #0
    jsr vmmWriteByte

    // Decrement UsedSlots (VMM header offset 1)
    lda AptSegLo
    sta VmmSegLo
    lda AptSegHi
    sta VmmSegHi
    lda #1
    sta VmmOffLo
    lda #0
    sta VmmOffHi
    jsr vmmReadByte         // A = UsedSlots
    sec
    sbc #1
    jsr vmmWriteByte
    clc
    rts

// -----------------------------------------------------------------------
// aptRemoveAll — deregister all inactive apps from the table (without APT_FLAG_RUNNING)
// Input:  None
// Output: carry clear always
// Clobbers: A, X, Y, DstHandle, VmmSegLo/Hi, VmmOffLo/Hi
// -----------------------------------------------------------------------
aptRemoveAll:
    ldx #0
araLoop:
    cpx #APT_MAX_SLOTS
    bcs araDone
    
    jsr aptSlotBase         // VmmSeg/Off = entry base; X preserved
    jsr vmmReadByte         // A = Flags
    sta aptTempFlags        // Save Flags in our temp byte
    and #APT_FLAG_USED
    beq araNext             // Unused -> skip
    
    lda aptTempFlags
    and #APT_FLAG_RUNNING
    bne araNext             // Running -> skip
    
    // It is used and NOT running, so print its name and remove it!
    // aptPrintFreedName and aptRemove preserve X
    jsr aptPrintFreedName
    jsr aptRemove
    
araNext:
    inx
    jmp araLoop
araDone:
    clc
    rts

// -----------------------------------------------------------------------
// aptPrintFreedName — print the name of the app in slot X prefixed by "freed "
// Input:  X = slot index
// Output: none
// Clobbers: A, Y, DstHandle, VmmSegLo/Hi, VmmOffLo/Hi
// Preserves: X
// -----------------------------------------------------------------------
aptPrintFreedName:
    lda #<aptFreedPrefix
    ldy #>aptFreedPrefix
    jsr petPrintString
    
    jsr aptSlotBase         // VmmSeg/Off = entry base; X preserved
    inc VmmOffLo            // VmmOff = base + 1 (APT_OFF_NAME)
    bne apfnNoCarry1
    inc VmmOffHi
apfnNoCarry1:
    lda #16
    sta aptNameIndex        // max 16 chars
apfnLoop:
    lda aptNameIndex
    beq apfnDone
    jsr vmmReadByte         // A = character; Y clobbered
    cmp #0
    beq apfnDone            // stop at null terminator
    jsr KernalChROUT
    inc VmmOffLo
    bne apfnNoCarry2
    inc VmmOffHi
apfnNoCarry2:
    dec aptNameIndex
    jmp apfnLoop
apfnDone:
    lda #PetCr
    jsr KernalChROUT
    rts

// -----------------------------------------------------------------------
// aptRegister — add or overwrite an app table entry
// If an entry with the same name already exists, it is overwritten (re-LOAD).
// Otherwise, the first free slot is used and UsedSlots is incremented.
// Enforces address-overlap eviction checking against all active slots first.
// Input:  NamePtrLo/Hi = pointer to app name; SrcHandle = name byte length (1-16)
//         HexValLo/Hi = load address
//         TempLo/Hi = end_addr+1 from KernalLOAD return
// Output: carry clear on success; carry set if table full (no free slot found)
// Clobbers: A, X, Y, DstHandle, VmmSegLo/Hi, VmmOffLo/Hi
// Preserves: NamePtrLo/Hi, HexValLo/Hi
// -----------------------------------------------------------------------
aptRegister:
    // Save TempLo/Hi — clobbered by VMM writes, needed for size computation at end
    lda TempHi
    pha
    lda TempLo
    pha

    // --- Overlap Eviction Scan ---
    ldx #0                  // slot loop index
arOverlapLoop:
    cpx #APT_MAX_SLOTS
    bcs arOverlapDone
    jsr aptSlotBase         // VmmSeg/Off = entry base
    jsr vmmReadByte         // A = Flags
    and #APT_FLAG_USED
    beq arNextOverlap       // unused slot -> skip

    // Read CurrLoadAddr (offset 17)
    clc
    lda VmmOffLo
    adc #APT_OFF_ADDR
    sta VmmOffLo
    bcc arReadLoadLo
    inc VmmOffHi
arReadLoadLo:
    jsr vmmReadByte
    sta AptTempLoadLo
    inc VmmOffLo
    jsr vmmReadByte
    sta AptTempLoadHi

    // Read CurrSize (offset 19)
    inc VmmOffLo
    jsr vmmReadByte
    sta AptTempSizeLo
    inc VmmOffLo
    jsr vmmReadByte
    sta AptTempSizeHi

    // Compute CurrEndAddr = CurrLoadAddr + CurrSize
    clc
    lda AptTempLoadLo
    adc AptTempSizeLo
    sta AptTempEndLo
    lda AptTempLoadHi
    adc AptTempSizeHi
    sta AptTempEndHi

    // Compare CurrLoadAddr >= Temp (B)
    // If true (Carry set) -> no overlap
    sec
    lda AptTempLoadLo
    sbc TempLo
    lda AptTempLoadHi
    sbc TempHi
    bcs arNextOverlap

    // Compare HexVal (A) >= CurrEndAddr (B)
    // If true (Carry set) -> no overlap
    sec
    lda HexValLo
    sbc AptTempEndLo
    lda HexValHi
    sbc AptTempEndHi
    bcs arNextOverlap

    // Overlap detected! Remove the entry at slot X
    // aptRemove preserves X
    jsr aptRemove

arNextOverlap:
    inx
    jmp arOverlapLoop
arOverlapDone:

    // --- Search / Overwrite Check ---
    clc                     // name mode
    jsr aptFind
    bcs arFindFree          // not found -> find a free slot
    // Found: X = existing slot index; overwrite without bumping UsedSlots
    jmp arWriteEntry

arFindFree:
    ldx #0
arFreeLoop:
    cpx #APT_MAX_SLOTS
    bcc arNotFull
    jmp arFull
arNotFull:
    jsr aptSlotBase
    jsr vmmReadByte         // A = Flags
    and #APT_FLAG_USED
    beq arGotFree
    inx
    jmp arFreeLoop

arGotFree:
    // Increment UsedSlots (VMM header offset 1)
    lda AptSegLo
    sta VmmSegLo
    lda AptSegHi
    sta VmmSegHi
    lda #1
    sta VmmOffLo
    lda #0
    sta VmmOffHi
    jsr vmmReadByte         // A = current UsedSlots
    clc
    adc #1
    jsr vmmWriteByte        // write incremented value

arWriteEntry:
    jsr aptSlotBase         // VmmSeg/Off = entry base for slot X

    // --- Flags: set SLOT_USED ---
    lda #APT_FLAG_USED
    jsr vmmWriteByte
    inc VmmOffLo            // -> APT_OFF_NAME (base + 1)

    // --- Name: copy SrcHandle bytes from NamePtrLo/Hi, null-pad to 16 bytes ---
    lda SrcHandle
    sta DstHandle           // byte countdown
    lda #0
    sta aptNameIndex        // source byte index
arNameLoop:
    lda DstHandle
    beq arNamePad
    ldy aptNameIndex
    lda (NamePtrLo), y      // read source name byte
    jsr vmmWriteByte
    inc VmmOffLo
    inc aptNameIndex
    dec DstHandle
    jmp arNameLoop
arNamePad:
    // Pad remaining bytes to fill 16-byte name field
    lda #16
    sec
    sbc SrcHandle           // remaining = 16 - name_length
    sta DstHandle
    beq arNameDone
arPadLoop:
    lda #0
    jsr vmmWriteByte
    inc VmmOffLo
    dec DstHandle
    bne arPadLoop
arNameDone:
    // VmmOffLo is now at base + 17 = APT_OFF_ADDR

    // --- LoadAddr lo/hi ---
    lda HexValLo
    jsr vmmWriteByte
    inc VmmOffLo
    lda HexValHi
    jsr vmmWriteByte
    inc VmmOffLo
    // VmmOffLo is now at base + 19 = APT_OFF_SIZE

    // --- Size = (end_addr+1) - LoadAddr ---
    // Restore TempLo/Hi (were pushed at top)
    pla
    sta TempLo              // end_addr+1 lo
    pla
    sta TempHi              // end_addr+1 hi
    lda TempLo
    sec
    sbc HexValLo
    pha                     // save size lo
    lda TempHi
    sbc HexValHi            // size hi (carries borrow)
    tax                     // stash size hi in X
    pla                     // restore size lo
    jsr vmmWriteByte        // write size lo (VmmOff is at base + 19)
    inc VmmOffLo
    txa
    jsr vmmWriteByte        // write size hi
    clc
    rts

arFull:
    pla                     // clean stack (TempLo)
    pla                     // clean stack (TempHi)
    sec
    rts

// -----------------------------------------------------------------------
// aptPrintHex8 — print A as two hex digits to screen
// Clobbers: A, X
// Preserves: Y
// -----------------------------------------------------------------------
aptPrintHex8:
    pha                     // save full byte
    lsr
    lsr
    lsr
    lsr                     // high nibble → A
    tax
    lda aptHexChars, x
    jsr KernalChROUT
    pla                     // restore full byte
    and #$0F                // low nibble
    tax
    lda aptHexChars, x
    jsr KernalChROUT
    rts

// -----------------------------------------------------------------------
// aptPrintLoadInfo — print load address and size after a successful LOAD,
// in the same "name / addr / size" column style as aptList (APPS/PS).
// Input:  NamePtrLo/Hi + SrcHandle = loaded file name (as typed, unpadded),
//         HexValLo/Hi = load address, TempLo/Hi = end address + 1
// Clobbers: A, X, Y
// -----------------------------------------------------------------------
aptPrintLoadInfo:
    lda #<aptListHeader
    ldy #>aptListHeader
    jsr petPrintString

    lda #16
    sta aptNameIndex        // remaining name-field columns
    ldy #0                  // source index into (NamePtrLo),y
pliNameLoop:
    lda aptNameIndex
    beq pliNameDone
    cpy SrcHandle
    bcs pliNamePad          // past end of typed name -> pad with spaces
    lda (NamePtrLo), y
    jsr KernalChROUT
    iny
    jmp pliNameCont
pliNamePad:
    lda #' '
    jsr KernalChROUT
pliNameCont:
    dec aptNameIndex
    jmp pliNameLoop
pliNameDone:

    lda #' '
    jsr KernalChROUT
    lda HexValHi
    jsr aptPrintHex8
    lda HexValLo
    jsr aptPrintHex8
    lda #' '
    jsr KernalChROUT
    sec
    lda TempLo
    sbc HexValLo
    pha                     // size lo
    lda TempHi
    sbc HexValHi            // size hi
    jsr aptPrintHex8
    pla
    jsr aptPrintHex8
    lda #PetCr
    jsr KernalChROUT
    rts

// -----------------------------------------------------------------------
// aptList — print all SLOT_USED entries to screen
// Output format (40-column):
//   name             addr  size
//   hello            2200   1a4
//   N app(s) loaded
// Input:  none
// Clobbers: A, X, Y, DstHandle, VmmSegLo/Hi, VmmOffLo/Hi
// -----------------------------------------------------------------------
aptList:
    // Read UsedSlots; print "no apps loaded" if zero
    lda AptSegLo
    sta VmmSegLo
    lda AptSegHi
    sta VmmSegHi
    lda #1
    sta VmmOffLo
    lda #0
    sta VmmOffHi
    jsr vmmReadByte         // A = UsedSlots
    sta aptUsedSlots
    bne alHasApps
    lda #<aptNoAppsMsg
    ldy #>aptNoAppsMsg
    jsr petPrintString
    rts

alHasApps:
    lda #<aptListHeader
    ldy #>aptListHeader
    jsr petPrintString

    ldx #0                  // slot counter (preserved by vmmReadByte)
alScanLoop:
    cpx #APT_MAX_SLOTS
    bcs alFooter
    jsr aptSlotBase         // VmmOff = entry base; X preserved; DstHandle = 0
    jsr vmmReadByte         // A = Flags
    and #APT_FLAG_USED
    beq alNextSlot          // X is still the current slot index here
    stx DstHandle           // save slot index before aptPrintHex8 clobbers X
    // --- Print 16-char name field (null bytes print as space) ---
    inc VmmOffLo            // → APT_OFF_NAME (base + 1)
    lda #16
    sta aptNameIndex        // loop 16 times
alNameLoop:
    lda aptNameIndex
    beq alNameDone
    jsr vmmReadByte         // A = name byte; Y clobbered
    cmp #0
    beq alNamePad
    jsr KernalChROUT
    jmp alNameCont
alNamePad:
    lda #' '
    jsr KernalChROUT
alNameCont:
    inc VmmOffLo
    dec aptNameIndex
    jmp alNameLoop
alNameDone:
    // VmmOffLo = base + 17 = APT_OFF_ADDR
    lda #' '
    jsr KernalChROUT
    // --- Print LoadAddr: hi byte then lo byte (4 hex digits) ---
    jsr vmmReadByte         // A = LoadAddr lo
    pha
    inc VmmOffLo
    jsr vmmReadByte         // A = LoadAddr hi; X clobbered below
    jsr aptPrintHex8        // print hi (X clobbered)
    pla
    jsr aptPrintHex8        // print lo (X clobbered)
    lda #' '
    jsr KernalChROUT
    // --- Print Size: hi byte then lo byte ---
    inc VmmOffLo            // → APT_OFF_SIZE (base + 19)
    jsr vmmReadByte         // A = Size lo
    pha
    inc VmmOffLo
    jsr vmmReadByte         // A = Size hi
    jsr aptPrintHex8
    pla
    jsr aptPrintHex8
    lda #PetCr
    jsr KernalChROUT
    ldx DstHandle           // restore slot index

alNextSlot:
    inx
    jmp alScanLoop

alFooter:
    ldx aptUsedSlots
    ldy #0
    jsr printDecimal16
    lda #<aptAppsMsg
    ldy #>aptAppsMsg
    jsr petPrintString
    rts

// -----------------------------------------------------------------------
// Data area (remainder of tasks append stubs here)
// -----------------------------------------------------------------------
aptSearchMode:  .byte 0    // 0 = name search, 1 = address search
aptNameIndex:   .byte 0    // byte index used in aptNameMatch and aptRegister name copy
aptUsedSlots:   .byte 0    // saved UsedSlots count for aptList footer
aptTempFlags:   .byte 0    // temp space for aptRemoveAll flags check

aptFreedPrefix:
    .text "freed "
    .byte 0

aptHexChars:
    .text "0123456789abcdef"

aptListHeader:
    .text "name             addr  size"
    .byte PetCr, 0

aptNoAppsMsg:
    .text "no apps loaded"
    .byte PetCr, 0

aptAppsMsg:
    .text " app(s) loaded"
    .byte PetCr, 0
