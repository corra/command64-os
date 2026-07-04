// src/command64/apptable.asm
// KickAssembler v5.25 — App Table Phase A
// Manages a 16-slot loaded-program registry in one VMM-allocated 4KB page.
// Entry stride: APT_ENTRY_SIZE = 40 bytes. Header: 4 bytes at VMM offset 0.

.segment AppTable

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
    // Write header at VMM offset 0: MaxSlots, UsedSlots=0, reserved×2
    lda AptSegLo
    sta VmmSegLo
    lda AptSegHi
    sta AptSegHi
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
    cmp #$22                // addr < $2200?
    bcc apcProtected
    cmp #$C0                // addr >= $C000?
    bcs apcProtected
    clc
    rts
apcProtected:
    sec
    rts

// -----------------------------------------------------------------------
// Data area (remainder of tasks append stubs here)
// -----------------------------------------------------------------------
aptSearchMode:  .byte 0    // 0 = name search, 1 = address search
aptNameIndex:   .byte 0    // byte index used in aptNameMatch and aptRegister name copy
aptUsedSlots:   .byte 0    // saved UsedSlots count for aptList footer
