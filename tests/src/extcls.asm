// tests/src/extcls.asm
* = $2000 "Cls"
    lda #$93 // Clear screen
    jsr $ffd2
    rts
