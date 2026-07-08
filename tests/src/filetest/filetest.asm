// tests/src/filetest.asm
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Command64 project contributors
// Tests the INT 21h Service Bus: DOS_OPEN_FILE, DOS_WRITE_FILE, DOS_READ_FILE, DOS_CLOSE_FILE

.encoding "petscii_mixed"

.const DOS_PRINT_STR  = $09
.const DOS_OPEN_FILE  = $3D
.const DOS_CLOSE_FILE = $3E
.const DOS_READ_FILE  = $3F
.const DOS_WRITE_FILE = $40
.const DOS_EXIT       = $4C
.const API            = $1000

// ZP equates from command64.inc
.label HexValLo = $66
.label HexValHi = $67
.label FileHandle = $6D

.const VERSION_MAJOR = "0"
.const VERSION_MINOR = "1"
.const VERSION_STAGE = "0"
#import "build_test_filetest.inc"

#import "build_config.inc"
* = UserProgStart "FileTest"
    cld
    lda #$0E
    jsr $FFD2

    // Print start message
    lda #DOS_PRINT_STR
    ldx #<msgStart
    ldy #>msgStart
    jsr API

    // 1. Open "test.txt" for Write
    lda #1
    sta HexValLo            // mode=1 (Write)
    ldx #<fname
    ldy #>fname
    lda #DOS_OPEN_FILE
    jsr API
    bcs open_err
    sta handle

    // 2. Write string to file
    lda handle
    sta FileHandle
    ldx #<writeData
    ldy #>fname             // wait, writeData
    ldx #<writeData
    ldy #>writeData
    lda #writeDataEnd - writeData
    sta HexValLo
    lda #0
    sta HexValHi
    lda #DOS_WRITE_FILE
    jsr API
    bcs write_err

    // 3. Close file
    lda handle
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr API

    // 4. Open "test.txt" for Read
    lda #0
    sta HexValLo            // mode=0 (Read)
    ldx #<fname
    ldy #>fname
    lda #DOS_OPEN_FILE
    jsr API
    bcs open_err
    sta handle

    // 5. Read from file
    lda handle
    sta FileHandle
    ldx #<readBuf
    ldy #>readBuf
    lda #32                 // request 32 bytes
    sta HexValLo
    lda #0
    sta HexValHi
    lda #DOS_READ_FILE
    jsr API
    
    // Null terminate read buffer
    ldx HexValLo
    lda #0
    sta readBuf, x

    // 6. Print read data
    lda #DOS_PRINT_STR
    ldx #<msgRead
    ldy #>msgRead
    jsr API
    
    lda #DOS_PRINT_STR
    ldx #<readBuf
    ldy #>readBuf
    jsr API
    
    lda #$0D
    jsr $FFD2

    // 7. Close file
    lda handle
    sta FileHandle
    lda #DOS_CLOSE_FILE
    jsr API

    // 8. Exit
    lda #DOS_EXIT
    jsr API

open_err:
    lda #DOS_PRINT_STR
    ldx #<msgOpenErr
    ldy #>msgOpenErr
    jsr API
    jmp exit
    
write_err:
    lda #DOS_PRINT_STR
    ldx #<msgWriteErr
    ldy #>msgWriteErr
    jsr API

exit:
    lda #DOS_EXIT
    jsr API

fname:     .text "test.txt"
           .byte 0
writeData: .text "hello from command64!"
writeDataEnd:
readBuf:   .fill 64, 0
handle:    .byte 0

msgRead:     .text "read from file: "
             .byte 0
msgOpenErr:  .text "error opening file"
             .byte $0D, 0
msgWriteErr: .text "error writing file"
             .byte $0D, 0

msgStart:    .text "FILETEST v" + VERSION_MAJOR + "." + VERSION_MINOR + "." + VERSION_STAGE + "." + BUILD_NUMBER
              .text " - Testing file read/write"
              .byte $0d, 0
