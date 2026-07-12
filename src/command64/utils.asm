// src/command64/utils.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// KickAssembler v5.25 - MS-DOS 4.0 to C64 Port Utility Routines
// Hex string to 16-bit integer conversion.

.segment Utils

// --- parseHex ---
// Parses a hex string in CommandBuffer starting at Y.
// Result stored in HexValLo ($66) and HexValHi ($67).
// Input:  Y = starting index in CommandBuffer
// Output: C=0 on success, C=1 on invalid char or overflow.
//         HexValLo/Hi updated.
// Clobbers: A, X, Y
parseHex:
    lda #0
    sta HexValLo
    sta HexValHi
phLoop:
    lda CommandBuffer, y
    beq phDone
    cmp #' '
    beq phDone
    
    jsr hexDigitToVal
    bcs phError             // Invalid hex digit
    
    // Shift HexValLo/Hi left 4 bits: (HexValHi:HexValLo) << 4
    // We only support up to 4 digits (16-bit)
    pha                     // Save nibble value
    ldx #4
phShift:
    asl HexValLo
    rol HexValHi
    dex
    bne phShift
    
    pla                     // Restore nibble value
    ora HexValLo            // HexValLo was cleared by shift? No, ASL clears bit 0.
    sta HexValLo
    
    iny
    jmp phLoop
phDone:
    clc
    rts
phError:
    sec
    rts

// --- hexDigitToVal ---
// Convert PETSCII hex char in A to value 0-15 in A.
// Handles '0'-'9' and 'a'-'f' (lowercase PETSCII $41-$46).
// Output: A = value 0-15. C=0 on success, C=1 on failure.
hexDigitToVal:
    cmp #'0'
    bcc hdvError
    cmp #':'                // '9' + 1
    bcc hdvNum
    
    // Check for a-f (petscii_mixed unshifted)
    cmp #'a'
    bcc hdvError
    cmp #'g'                // 'f' + 1
    bcs hdvError
    sec
    sbc #('a'-10)           // 'a'-10 = $41 - 10 = $37
    clc
    rts
hdvNum:
    sec
    sbc #'0'
    clc
    rts
hdvError:
    sec
    rts

// --- normalizeName ---
// Converts a string to lowercase PETSCII ($41-$5A).
// Input:  A = low byte of string pointer
//         Y = high byte of string pointer
//         X = string length
// Output: Y = string length (loop exits when Y == TempLo == input X)
//         X = preserved (unchanged — callers rely on this after the call)
// Clobbers: A, TempLo, PrintPtrLo/Hi
normalizeName:
    sta PrintPtrLo
    sty PrintPtrHi
    stx TempLo
    ldy #0
nnLoop:
    cpy TempLo
    beq nnDone
    lda (PrintPtrLo), y
    
    // 1. Convert shifted characters (A-Z) to unshifted
    // In petscii_mixed, unshifted is lowercase, shifted is uppercase.
    // Disk entries are unshifted. So we normalize everything to unshifted.
    cmp #$C1                // PETSCII Shifted 'A'
    bcc nnNext
    cmp #$DB                // PETSCII Shifted 'Z' + 1
    bcs nnNext
    and #$7F                // Convert shifted to unshifted
    sta (PrintPtrLo), y
nnNext:
    iny
    jmp nnLoop
nnDone:
    rts

// Date/time subroutines below are placed in ShellExt (rather than Utils) —
// Utils/Api/Loader/Path/Vmm/File must all fit in the fixed $0820-$1000
// window before ApiStub; this block is too large for that budget.
.segment ShellExt

// --- bcdToDec ---
// Converts a BCD byte to decimal.
// Input:  A = BCD byte (each nibble 0-9)
// Output: A = decimal value (0-99)
// Clobbers: A, Y, TempLo
bcdToDec:
    tay                     // Y = BCD value
    and #$F0                // A = tens * 16
    lsr
    sta TempLo
    lsr
    lsr                     // A = tens * 2
    clc
    adc TempLo              // A = tens * 10
    sta TempLo
    tya
    and #$0F                // A = units
    clc
    adc TempLo
    rts

// --- decToBcd ---
// Converts a decimal byte (0-99) to BCD.
// Input:  A = decimal value (0-99)
// Output: A = BCD value
// Clobbers: A, X, TempLo
decToBcd:
    ldx #0
dtbLoop:
    cmp #10
    bcc dtbDone
    sbc #10                 // Carry is set on entry (from cmp), SBC subtracts cleanly
    inx
    jmp dtbLoop
dtbDone:
    sta TempLo
    txa
    asl
    asl
    asl
    asl
    ora TempLo
    rts

// --- isLeapYear ---
// Determines if a year offset (from 1980) is a leap year.
// Input:  A = year offset (0-255)
// Output: C=1 if leap year, C=0 if not. A/Y clobbered.
isLeapYear:
    tay
    and #3
    bne ilyNotLeap
    cpy #120                // Offset 120 = year 2100 (not a leap year)
    beq ilyNotLeap
    cpy #220                // Offset 220 = year 2200 (not a leap year)
    beq ilyNotLeap
    sec
    rts
ilyNotLeap:
    clc
    rts

// --- getDaysInMonth ---
// Returns the number of days in a given month/year.
// Input:  A = Month (1-12), X = Year offset (0-255)
// Output: A = number of days in that month
// Clobbers: A, Y
getDaysInMonth:
    tay
    lda gdimTable-1, y      // Table is 1-indexed by month
    cpy #2                  // February?
    bne gdimDone
    txa                     // A = year offset
    jsr isLeapYear
    bcc gdimDone
    lda #29
gdimDone:
    rts

gdimTable:
    .byte 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31

// --- clockInit ---
// Initializes CIA #1 TOD clock standard and default date/time at boot.
// Clobbers: A, X, Y
clockInit:
    lda KernalVideoStd      // 0 = NTSC, 1 = PAL
    tax
    lda CIA1_CRA
    and #$7F                // Clear TOD frequency bit (default NTSC/60Hz)
    cpx #0
    beq ciSetCra
    ora #$80                // PAL/50Hz
ciSetCra:
    sta CIA1_CRA

    lda CIA1_CRB
    and #$7F                // Ensure TOD clock registers (not alarm) are selected
    sta CIA1_CRB

    lda #0
    sta SysDateYear
    lda #1
    sta SysDateMonth
    sta SysDateDay
    lda #0
    sta SysDateLastHour

    lda #0
    ldx #0
    ldy #0
    jsr writeTimeToCIA      // 00:00:00
    rts

// --- readTimeFromCIA ---
// Reads time from CIA #1 TOD registers and converts to 24-hour decimal.
// Output: A = Hour (0-23), X = Minute (0-59), Y = Second (0-59)
// Clobbers: A, X, Y, TempLo, TempHi, HexValLo, PrintPtrLo, PrintPtrHi
readTimeFromCIA:
    lda CIA1_CRB
    and #$7F
    sta CIA1_CRB

    lda CIA1_TOD_HR         // Latches TOD registers
    sta HexValLo            // Raw BCD hour; bcdToDec below clobbers TempLo, not HexValLo
    lda CIA1_TOD_MIN
    sta PrintPtrLo
    lda CIA1_TOD_SEC
    sta PrintPtrHi
    lda CIA1_TOD_10THS      // Unlatches TOD registers; value discarded

    lda PrintPtrLo
    jsr bcdToDec
    tax                     // X = Minute (decimal)

    lda PrintPtrHi
    jsr bcdToDec
    sta TempHi              // Save second; hour conversion below clobbers Y

    lda HexValLo
    and #$1F                // Strip PM bit and unused bit 5/6
    jsr bcdToDec            // A = 1-12 decimal hour
    cmp #12
    bne rtcNot12
    // Hour is 12: noon (PM) -> 12, midnight (AM) -> 0
    bit HexValLo            // bit 7 of HexValLo -> N flag
    bmi rtcDone             // PM: stays 12
    lda #0
    jmp rtcDone
rtcNot12:
    bit HexValLo
    bpl rtcDone             // AM: value unchanged
    clc
    adc #12                 // PM: add 12
rtcDone:
    ldy TempHi              // Y = Second (decimal)
    rts

// --- writeTimeToCIA ---
// Converts 24-hour decimal time to 12-hour BCD + AM/PM and writes to CIA #1.
// Input:  A = Hour (0-23), X = Minute (0-59), Y = Second (0-59)
// Clobbers: A, X, Y, TempLo, TempHi, PrintPtrLo, PrintPtrHi
writeTimeToCIA:
    sta TempLo              // TempLo = Hour
    stx TempHi              // TempHi = Minute
    sty PrintPtrLo          // PrintPtrLo = Second

    lda CIA1_CRB
    and #$7F
    sta CIA1_CRB

    lda TempLo
    bne wtcNotMidnight
    lda #$12                // Midnight -> 12 AM
    jmp wtcHaveHourBcd
wtcNotMidnight:
    cmp #12
    bne wtcNotNoon
    lda #$92                // Noon -> 12 PM ($12 | $80)
    jmp wtcHaveHourBcd
wtcNotNoon:
    bcc wtcAmHour            // < 12 -> AM, 1-11
    sec
    sbc #12                  // >= 13 -> PM, subtract 12
    jsr decToBcd
    ora #$80
    jmp wtcHaveHourBcd
wtcAmHour:
    jsr decToBcd
wtcHaveHourBcd:
    sta PrintPtrHi           // PrintPtrHi = Hour BCD (+ PM bit)

    lda TempHi
    jsr decToBcd
    sta TempHi                // TempHi = Minute BCD

    lda PrintPtrLo
    jsr decToBcd
    sta PrintPtrLo             // PrintPtrLo = Second BCD

    lda PrintPtrHi
    sta CIA1_TOD_HR            // Write Hour (stops TOD clock)
    lda TempHi
    sta CIA1_TOD_MIN
    lda PrintPtrLo
    sta CIA1_TOD_SEC
    lda #0
    sta CIA1_TOD_10THS         // Write Tenths (restarts TOD clock)
    rts

// --- incrementDate ---
// Increments SysDateDay/Month/Year with carry (leap-year aware).
// Clobbers: A, X
incrementDate:
    lda SysDateDay
    clc
    adc #1
    sta SysDateDay

    lda SysDateMonth
    ldx SysDateYear
    jsr getDaysInMonth      // A = max days in current month
    cmp SysDateDay
    bcs idDone              // max days >= day -> no rollover

    lda #1
    sta SysDateDay
    inc SysDateMonth
    lda SysDateMonth
    cmp #13
    bcc idDone
    lda #1
    sta SysDateMonth
    inc SysDateYear
idDone:
    rts

// --- checkDateRollover ---
// Reads current time and advances the date if a midnight hour-wrap occurred
// since the last check.
// Clobbers: A, X, Y, TempLo, HexValLo, PrintPtrLo, PrintPtrHi
checkDateRollover:
    jsr readTimeFromCIA     // A = Hour (0-23)
    cmp SysDateLastHour
    bcs cdrNoRollover       // Hour >= LastHour -> no midnight wrap
    pha
    jsr incrementDate
    pla
cdrNoRollover:
    sta SysDateLastHour
    rts

.segment Utils

// --- printDecimal16 ---
// Prints a 16-bit value in decimal to standard output.
// Input:  X = Low byte, Y = High byte
// Clobbers: A, X, Y, HexValLo/Hi (used as temporary)
printDecimal16:
    stx HexValLo
    sty HexValHi
    
    lda #0
    sta TempHi              // Initialize leading-zero suppression flag
    
    // Check for zero
    lda HexValLo
    ora HexValHi
    bne pdStart
    lda #'0'
    jsr KernalChROUT
    rts

pdStart:
    // We use a simple subtraction loop for powers of 10
    // 10000, 1000, 100, 10, 1
    
    // 10000s
    ldx #0
pd10000:
    lda HexValLo
    sec
    sbc #<10000
    tay
    lda HexValHi
    sbc #>10000
    bcc pdDone10000
    sta HexValHi
    sty HexValLo
    inx
    jmp pd10000
pdDone10000:
    jsr pdPrintDigit
    
    // 1000s
    ldx #0
pd1000:
    lda HexValLo
    sec
    sbc #<1000
    tay
    lda HexValHi
    sbc #>1000
    bcc pdDone1000
    sta HexValHi
    sty HexValLo
    inx
    jmp pd1000
pdDone1000:
    jsr pdPrintDigit

    // 100s
    ldx #0
pd100:
    lda HexValLo
    sec
    sbc #100
    tay
    lda HexValHi
    sbc #0
    bcc pdDone100
    sta HexValHi
    sty HexValLo
    inx
    jmp pd100
pdDone100:
    jsr pdPrintDigit

    // 10s
    ldx #0
pd10:
    lda HexValLo
    sec
    sbc #10
    tay
    lda HexValHi
    sbc #0
    bcc pdDone10
    sta HexValHi
    sty HexValLo
    inx
    jmp pd10
pdDone10:
    jsr pdPrintDigit

    // 1s
    lda HexValLo
    clc
    adc #'0'
    jsr KernalChROUT
    rts

// Helper to print digit in X and suppress leading zeros
pdPrintDigit:
    txa
    beq pdZero
    clc
    adc #'0'
    jsr KernalChROUT
    lda #1                  // Mark that we've printed a non-zero
    sta TempHi
    rts
pdZero:
    lda TempHi              // Have we printed a non-zero yet?
    beq pdNoPrint
    lda #'0'
    jsr KernalChROUT
pdNoPrint:
    rts

.segment ShellExt

// --- printDec2 ---
// Prints a 1-byte decimal value (0-99), zero-padded to 2 digits.
// Input: A = value (0-99)
// Clobbers: A, X
printDec2:
    ldx #0
pd2Loop:
    cmp #10
    bcc pd2Done
    sec
    sbc #10
    inx
    jmp pd2Loop
pd2Done:
    pha                     // Save units digit
    txa
    clc
    adc #'0'
    jsr KernalChROUT        // Print tens digit (always, even if 0)
    pla
    clc
    adc #'0'
    jsr KernalChROUT        // Print units digit
    rts

// --- printCurrentDate ---
// Prints the current date as YYYY-MM-DD.
// Clobbers: A, X, Y, HexValLo, HexValHi
printCurrentDate:
    lda SysDateYear
    clc
    adc #<1980
    tax
    lda #0
    adc #>1980
    tay
    jsr printDecimal16      // Prints (SysDateYear + 1980)

    lda #'-'
    jsr KernalChROUT
    lda SysDateMonth
    jsr printDec2
    lda #'-'
    jsr KernalChROUT
    lda SysDateDay
    jsr printDec2
    rts

// --- printCurrentTime ---
// Prints the current time as HH:MM:SS.
// Clobbers: A, X, Y, TempLo, TempHi, HexValLo, PrintPtrLo, PrintPtrHi
printCurrentTime:
    jsr readTimeFromCIA     // A = Hour, X = Minute, Y = Second
    stx TempLo              // TempLo = Minute
    sty TempHi              // TempHi = Second

    jsr printDec2           // Hour (still in A)
    lda #':'
    jsr KernalChROUT
    lda TempLo
    jsr printDec2           // Minute
    lda #':'
    jsr KernalChROUT
    lda TempHi
    jsr printDec2           // Second
    rts

// --- pnDigitVal [Private] ---
// Converts a single PETSCII decimal digit char to its 0-9 value.
// Input:  A = PETSCII char
// Output: A = 0-9, C=0 on success; C=1 if char is not '0'-'9'
pnDigitVal:
    cmp #'0'
    bcc pdvErr
    cmp #':'                // '9' + 1
    bcs pdvErr
    sec
    sbc #'0'
    clc
    rts
pdvErr:
    sec
    rts

// --- parseNum2 ---
// Parses a 2-digit decimal number from CommandBuffer.
// Input:  Y = current parse position in CommandBuffer
// Output: A = numeric value (0-99), Y advanced by 2.
//         C=0 on success, C=1 on invalid (non-digit) characters.
// Clobbers: A, TempLo, TempHi, PrintPtrLo
parseNum2:
    lda CommandBuffer, y
    jsr pnDigitVal
    bcs pn2Err
    sta TempLo              // tens digit (0-9)
    iny
    lda CommandBuffer, y
    jsr pnDigitVal
    bcs pn2Err
    sta TempHi              // units digit (0-9)
    iny

    lda TempLo
    asl                     // *2
    sta PrintPtrLo
    lda TempLo
    asl
    asl
    asl                     // *8
    clc
    adc PrintPtrLo          // *8 + *2 = *10
    clc
    adc TempHi              // + units
    clc                     // success
    rts
pn2Err:
    sec
    rts

// --- parseNum4 ---
// Parses a 4-digit decimal number from CommandBuffer.
// Input:  Y = current parse position in CommandBuffer
// Output: HexValLo/HexValHi = numeric value (0-9999), Y advanced by 4.
//         C=0 on success, C=1 on invalid (non-digit) characters.
// Clobbers: A, X, Y, TempLo, TempHi, PrintPtrLo, HexValLo, HexValHi
parseNum4:
    jsr parseNum2           // A = first two digits (0-99)
    bcs pn4Err
    sta PrintPtrHi          // PrintPtrHi = hundreds pair (0-99); parseNum2's own
                             // scratch use of TempLo/TempHi would clobber it otherwise
    jsr parseNum2           // A = last two digits (0-99)
    bcs pn4Err
    sta TempHi              // TempHi = units pair (0-99)

    lda #0
    sta HexValLo
    sta HexValHi
    ldx PrintPtrHi
    beq pn4SkipMul
pn4MulLoop:                 // HexVal += 100, TempLo times
    clc
    lda HexValLo
    adc #100
    sta HexValLo
    lda HexValHi
    adc #0
    sta HexValHi
    dex
    bne pn4MulLoop
pn4SkipMul:
    clc
    lda HexValLo
    adc TempHi
    sta HexValLo
    lda HexValHi
    adc #0
    sta HexValHi
    clc                     // success
    rts
pn4Err:
    sec
    rts

// --- parseDateArg ---
// Parses a date string matching YYYY-MM-DD from CommandBuffer.
// Input:  ParsePos = starting index in CommandBuffer
// Output: X = year offset from 1980 (0-255), TempLo = month (1-12),
//         TempHi = day (1-31). C=0 on success, C=1 on invalid input.
//         ParsePos advanced past the parsed date.
// Clobbers: A, X, Y, TempLo, TempHi, PrintPtrLo, HexValLo, HexValHi
parseDateArg:
    ldy ParsePos
    jsr parseNum4           // HexValLo/Hi = year (0-9999)
    bcs pdaErr

    lda HexValLo
    sec
    sbc #<1980
    tax                     // X = tentative year offset low byte
    lda HexValHi
    sbc #>1980
    bne pdaErr              // Non-zero high byte -> year outside 1980-2235

    lda CommandBuffer, y
    cmp #'-'
    bne pdaErr
    iny

    jsr parseNum2           // A = month (0-99)
    bcs pdaErr
    cmp #1
    bcc pdaErr
    cmp #13
    bcs pdaErr
    sta HexValHi            // Preserve month; parseNum2 below clobbers TempLo

    lda CommandBuffer, y
    cmp #'-'
    bne pdaErr
    iny

    jsr parseNum2           // A = day (0-99)
    bcs pdaErr
    sta TempHi              // TempHi = day (tentative)
    beq pdaErr              // day 0 is invalid
    lda HexValHi
    sta TempLo              // TempLo = month

    tya
    pha                     // Preserve parse index; getDaysInMonth clobbers Y
    lda TempLo
    jsr getDaysInMonth      // A = max days in month (X = year offset, preserved)
    cmp TempHi
    bcc pdaErrRestoreY      // max days < day -> invalid
    pla
    tay

    jsr shellSkipSpaces
    lda CommandBuffer, y
    bne pdaErr              // trailing garbage after date

    sty ParsePos
    clc                     // success
    rts
pdaErr:
    sty ParsePos
    sec
    rts
pdaErrRestoreY:
    pla
    tay
    jmp pdaErr

// --- parseTimeArg ---
// Parses a time string matching HH:MM:SS from CommandBuffer.
// Input:  ParsePos = starting index in CommandBuffer
// Output: X = Hour (0-23), TempLo = Minute (0-59), TempHi = Second (0-59).
//         C=0 on success, C=1 on invalid input.
//         ParsePos advanced past the parsed time.
// Clobbers: A, X, Y, TempLo, TempHi, PrintPtrLo
parseTimeArg:
    ldy ParsePos
    jsr parseNum2           // A = Hour (0-99)
    bcs ptaErr
    cmp #24
    bcs ptaErr
    tax                     // X = Hour

    lda CommandBuffer, y
    cmp #':'
    bne ptaErr
    iny

    jsr parseNum2           // A = Minute (0-99)
    bcs ptaErr
    cmp #60
    bcs ptaErr
    sta PrintPtrHi          // Preserve minute; parseNum2 below clobbers TempLo

    lda CommandBuffer, y
    cmp #':'
    bne ptaErr
    iny

    jsr parseNum2           // A = Second (0-99)
    bcs ptaErr
    cmp #60
    bcs ptaErr
    sta TempHi              // TempHi = Second
    lda PrintPtrHi
    sta TempLo              // TempLo = Minute

    jsr shellSkipSpaces
    lda CommandBuffer, y
    bne ptaErr              // trailing garbage after time

    sty ParsePos
    clc                     // success
    rts
ptaErr:
    sty ParsePos
    sec
    rts

.segment Utils

// --- parsePointerDevice ---
// Parses a device prefix (8:, 9:, 10:, 11:) from the filename pointer stored
// at ZP offset X.
// Input:  X = ZP offset of the pointer (e.g. $FD for NamePtrLo)
// Output: A = resolved device number (8-11, or CurrentDevice if not found)
//         Carry: 1 = prefix found (pointer advanced), 0 = no prefix (pointer unchanged)
// Clobbers: A, Y, TempLo, TempHi
parsePointerDevice:
    // Copy the pointer at ZP offset X to TempLo/Hi
    lda $00, x
    sta TempLo
    lda $01, x
    sta TempHi
    
    ldy #0
    lda (TempLo), y
    cmp #'8'
    beq ppdCheck8
    cmp #'9'
    beq ppdCheck9
    cmp #'1'
    beq ppdCheck10or11
    
ppdNoMatch:
    lda CurrentDevice
    clc                     // Carry=0: no prefix
    rts

ppdCheck8:
    iny
    lda (TempLo), y
    cmp #':'
    beq ppdFound8
    jmp ppdNoMatch

ppdFound8:
    // Advance pointer in ZP by 2 bytes (skip '8:')
    lda $00, x
    clc
    adc #2
    sta $00, x
    lda $01, x
    adc #0
    sta $01, x
    lda #8
    sec                     // Carry=1: prefix found
    rts

ppdCheck9:
    iny
    lda (TempLo), y
    cmp #':'
    beq ppdFound9
    jmp ppdNoMatch

ppdFound9:
    // Advance pointer in ZP by 2 bytes (skip '9:')
    lda $00, x
    clc
    adc #2
    sta $00, x
    lda $01, x
    adc #0
    sta $01, x
    lda #9
    sec                     // Carry=1: prefix found
    rts

ppdCheck10or11:
    iny
    lda (TempLo), y
    cmp #'0'
    beq ppdCheck10
    cmp #'1'
    beq ppdCheck11
    jmp ppdNoMatch

ppdCheck10:
    iny
    lda (TempLo), y
    cmp #':'
    beq ppdFound10
    jmp ppdNoMatch

ppdFound10:
    // Advance pointer in ZP by 3 bytes (skip '10:')
    lda $00, x
    clc
    adc #3
    sta $00, x
    lda $01, x
    adc #0
    sta $01, x
    lda #10
    sec                     // Carry=1: prefix found
    rts

ppdCheck11:
    iny
    lda (TempLo), y
    cmp #':'
    beq ppdFound11
    jmp ppdNoMatch

ppdFound11:
    // Advance pointer in ZP by 3 bytes (skip '11:')
    lda $00, x
    clc
    adc #3
    sta $00, x
    lda $01, x
    adc #0
    sta $01, x
    lda #11
    sec                     // Carry=1: prefix found
    rts
