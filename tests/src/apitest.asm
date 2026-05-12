// tests/src/apitest.asm
// Tests the INT 21h Service Bus: DOS_PRINT_STR and DOS_EXIT

.encoding "petscii_mixed"

.const DOS_PRINT_STR  = $09
.const DOS_EXIT       = $4C
.const API            = $1000

* = $2000 "ApiTest"
    cld                     // Ensure binary mode
    lda #$0E                // Switch to lowercase mode
    jsr $FFD2               // CHROUT
    
    // Print the welcome message using the API
    lda #DOS_PRINT_STR
    ldx #<msg
    ldy #>msg
    jsr API

    // Terminate via API
    lda #DOS_EXIT
    jsr API

msg: .text "Service Bus API: String output works!"
     .byte $0d, 0
