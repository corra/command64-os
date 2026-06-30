// tests/src/devtest.asm
// Tests the DOS_PARSE_PREFIX API function ($57).

.encoding "petscii_mixed"

.const DOS_PRINT_CHAR   = $02
.const DOS_PRINT_STR    = $09
.const DOS_PARSE_PREFIX = $57
.const DOS_EXIT         = $4C
.const API              = $1000

.label PrintPtrLo    = $FB  // ZP pointer low
.label PrintPtrHi    = $FC  // ZP pointer high
.label CurrentDevice = $039e

.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "0"
#import "build_test_devtest.inc"

* = $2000 "DevTest"
    cld                     // Binary mode
    lda #$0e                // Lowercase mode
    jsr $ffd2               // CHROUT
    
    // Print start message
    lda #DOS_PRINT_STR
    ldx #<msgStart
    ldy #>msgStart
    jsr API

    // --- TEST CASE 1: "8:testfile" ---
    lda #<strCase1
    sta PrintPtrLo
    lda #>strCase1
    sta PrintPtrHi
    
    ldx #PrintPtrLo
    lda #DOS_PARSE_PREFIX
    jsr API
    sta resDev1
    php
    pla
    sta resFlags1
    ldy #0
    lda (PrintPtrLo), y
    sta resChar1

    // --- TEST CASE 2: "10:data" ---
    lda #<strCase2
    sta PrintPtrLo
    lda #>strCase2
    sta PrintPtrHi
    
    ldx #PrintPtrLo
    lda #DOS_PARSE_PREFIX
    jsr API
    sta resDev2
    php
    pla
    sta resFlags2
    ldy #0
    lda (PrintPtrLo), y
    sta resChar2

    // --- TEST CASE 3: "myfile" ---
    lda #<strCase3
    sta PrintPtrLo
    lda #>strCase3
    sta PrintPtrHi
    
    ldx #PrintPtrLo
    lda #DOS_PARSE_PREFIX
    jsr API
    sta resDev3
    php
    pla
    sta resFlags3
    ldy #0
    lda (PrintPtrLo), y
    sta resChar3

    // --- PRINT DIAGNOSTIC REPORT ---
    
    // Case 1 Report
    lda #DOS_PRINT_STR
    ldx #<msgRpt1
    ldy #>msgRpt1
    jsr API
    lda resDev1
    jsr printHex8
    jsr printCarryAndChar1
    
    // Case 2 Report
    lda #DOS_PRINT_STR
    ldx #<msgRpt2
    ldy #>msgRpt2
    jsr API
    lda resDev2
    jsr printHex8
    jsr printCarryAndChar2

    // Case 3 Report
    lda #DOS_PRINT_STR
    ldx #<msgRpt3
    ldy #>msgRpt3
    jsr API
    lda resDev3
    jsr printHex8
    jsr printCarryAndChar3

    // --- VERIFY PASS/FAIL ---
    
    // Case 1 validation
    lda resDev1
    cmp #8
    bne test_fail
    lda resFlags1
    and #$01            // Carry flag bit
    beq test_fail
    lda resChar1
    cmp #'t'
    bne test_fail

    // Case 2 validation
    lda resDev2
    cmp #10
    bne test_fail
    lda resFlags2
    and #$01
    beq test_fail
    lda resChar2
    cmp #'d'
    bne test_fail

    // Case 3 validation
    lda resDev3
    cmp CurrentDevice
    bne test_fail
    lda resFlags3
    and #$01
    bne test_fail
    lda resChar3
    cmp #'m'
    bne test_fail

    // All passed
    lda #DOS_PRINT_STR
    ldx #<msgPass
    ldy #>msgPass
    jsr API
    jmp exit

test_fail:
    lda #DOS_PRINT_STR
    ldx #<msgFail
    ldy #>msgFail
    jsr API

exit:
    lda #DOS_EXIT
    jsr API

// --- HELPERS ---

printCarryAndChar1:
    lda resFlags1
    ldx resChar1
    jmp printCarryAndCharCommon
printCarryAndChar2:
    lda resFlags2
    ldx resChar2
    jmp printCarryAndCharCommon
printCarryAndChar3:
    lda resFlags3
    ldx resChar3
printCarryAndCharCommon:
    pha                 // Save flags
    txa
    pha                 // Save char
    
    // Print space
    lda #DOS_PRINT_CHAR
    ldx #' '
    jsr API
    
    // Print C=
    lda #DOS_PRINT_CHAR
    ldx #'C'
    jsr API
    lda #DOS_PRINT_CHAR
    ldx #'='
    jsr API
    
    // Retrieve flags and isolate Carry bit
    pla
    tay                 // Y = char
    pla                 // A = flags
    and #$01            // Carry bit
    jsr printHex8
    
    // Print space
    lda #DOS_PRINT_CHAR
    ldx #' '
    jsr API
    
    // Print Char
    tya
    tax
    lda #DOS_PRINT_CHAR
    jsr API
    
    // Print Newline
    lda #DOS_PRINT_CHAR
    ldx #$0d
    jsr API
    rts

printHex8:
    pha
    lsr
    lsr
    lsr
    lsr
    jsr printNibble
    pla
    and #$0f
printNibble:
    cmp #10
    bcc pnDigit
    clc
    adc #7
pnDigit:
    adc #48
    tax
    lda #DOS_PRINT_CHAR
    jsr API
    rts

// --- DATA ---

resDev1:   .byte 0
resFlags1: .byte 0
resChar1:  .byte 0

resDev2:   .byte 0
resFlags2: .byte 0
resChar2:  .byte 0

resDev3:   .byte 0
resFlags3: .byte 0
resChar3:  .byte 0

msgStart: .text "DEVTEST v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE + "." + BUILD_NUMBER
          .text " - Testing DOS_PARSE_PREFIX API call..."
          .byte $0d, 0
msgPass:  .text "DOS_PARSE_PREFIX API: PASS"
          .byte $0d, 0
msgFail:  .text "Error: DOS_PARSE_PREFIX API mismatch: FAIL"
          .byte $0d, 0

msgRpt1:  .text "Case 1: DEV="
          .byte 0
msgRpt2:  .text "Case 2: DEV="
          .byte 0
msgRpt3:  .text "Case 3: DEV="
          .byte 0

strCase1: .text "8:testfile"
          .byte 0
strCase2: .text "10:data"
          .byte 0
strCase3: .text "myfile"
          .byte 0
