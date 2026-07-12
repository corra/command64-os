; tests/src/file/file.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
; ca65 file I/O API test.

.include "command64.inc"

VERSION_MAJOR = '0'
VERSION_MINOR = '1'
VERSION_STAGE = '0'
.include "build_test_file.inc"

.import __MAIN_START__

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

start:
    cld
    lda #$0E
    jsr KernalChROUT

    lda #DOS_PRINT_STR
    ldx #<msgStart
    ldy #>msgStart
    jsr OS_API

    ; 1. Open "TEST.TXT" for Write
    lda #1
    sta HexValLo            ; mode=1 (Write)
    lda #'S'                ; type='S' (SEQ)
    sta HexValHi
    ldx #<fname
    ldy #>fname
    lda #DOS_OPEN_FILE
    jsr OS_API
    bcs open_err
    sta handle

    ; 2. Write string to file
    lda handle
    sta FileHandle
    ldx #<writeData
    ldy #>writeData
    lda #writeDataEnd - writeData
    sta HexValLo
    lda #0
    sta HexValHi
    lda #DOS_WRITE_FILE
    jsr OS_API
    bcs write_err

    ; 3. Close file
    lda handle
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr OS_API

    ; 4. Open "TEST.TXT" for Read
    lda #0
    sta HexValLo            ; mode=0 (Read)
    ldx #<fname
    ldy #>fname
    lda #DOS_OPEN_FILE
    jsr OS_API
    bcs open_err
    sta handle

    ; 5. Read from file
    lda handle
    sta FileHandle
    ldx #<readBuf
    ldy #>readBuf
    lda #32
    sta HexValLo
    lda #0
    sta HexValHi
    lda #DOS_READ_FILE
    jsr OS_API

    ldx HexValLo
    lda #0
    sta readBuf, x

    ; 6. Print read data
    lda #DOS_PRINT_STR
    ldx #<msgRead
    ldy #>msgRead
    jsr OS_API

    lda #DOS_PRINT_STR
    ldx #<readBuf
    ldy #>readBuf
    jsr OS_API

    lda #$0D
    jsr KernalChROUT

    ; 7. Close file
    lda handle
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr OS_API

    ; 8. Exit
    lda #DOS_EXIT
    jsr OS_API

open_err:
    lda #DOS_PRINT_STR
    ldx #<msgOpenErr
    ldy #>msgOpenErr
    jsr OS_API
    jmp exit

write_err:
    lda #DOS_PRINT_STR
    ldx #<msgWriteErr
    ldy #>msgWriteErr
    jsr OS_API

exit:
    lda #DOS_EXIT
    jsr OS_API

; "TEST.TXT"
fname:
    .byte $54, $45, $53, $54, $2E, $54, $58, $54, $00

; "HELLO FROM COMMAND64!" (no terminator -- length computed via writeDataEnd)
writeData:
    .byte $48, $45, $4C, $4C, $4F, $20, $46, $52, $4F, $4D, $20, $43, $4F
    .byte $4D, $4D, $41, $4E, $44, $36, $34, $21
writeDataEnd:
readBuf:
    .res 64, 0
handle:
    .byte 0

; "READ FROM FILE: "
msgRead:
    .byte $52, $45, $41, $44, $20, $46, $52, $4F, $4D, $20, $46, $49, $4C
    .byte $45, $3A, $20, $00
; "ERROR OPENING FILE"
msgOpenErr:
    .byte $45, $52, $52, $4F, $52, $20, $4F, $50, $45, $4E, $49, $4E, $47
    .byte $20, $46, $49, $4C, $45, $0D, $00
; "ERROR WRITING FILE"
msgWriteErr:
    .byte $45, $52, $52, $4F, $52, $20, $57, $52, $49, $54, $49, $4E, $47
    .byte $20, $46, $49, $4C, $45, $0D, $00

; "FILETEST V" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE
; + "." + BUILD_NUMBER + " - Testing file read/write"
msgStart:
    .byte $46, $49, $4C, $45, $54, $45, $53, $54, $20, $56
    .byte VERSION_MAJOR, $2E, VERSION_MINOR, $2E, VERSION_STAGE, $2E
    .byte BUILD_NUMBER
    .byte $20, $2D, $20, $54, $45, $53, $54, $49, $4E, $47, $20
    .byte $46, $49, $4C, $45, $20, $52, $45, $41, $44, $2F, $57, $52, $49
    .byte $54, $45, $0D, $00
