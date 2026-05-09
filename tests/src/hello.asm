// tests/src/hello.asm
.encoding "petscii_mixed"

* = $2000 "Hello"
    lda #<msg
    ldy #>msg
    jsr printString
    rts

msg: .text "Hello from the C64 Disk!"
     .byte $0d, 0

printString:
    sta $22
    sty $23
    ldy #0
loop:
    lda ($22), y
    beq done
    jsr $ffd2 // CHROUT
    iny
    jmp loop
done:
    rts
