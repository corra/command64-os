; src/external/format/format.s
; SPDX-License-Identifier: MIT
; Copyright (c) 2026 Command64 project contributors
;
; FORMAT: low-level-formats a 1541 floppy by sending CBM DOS's native
; N:name,id (NEW) command to the target drive's command channel via the
; DOS_SEND_COMMAND kernel primitive ($58, include/ca65/command64.inc).
; The drive firmware owns the actual format logic entirely -- this app
; only builds/validates the command string, guards the destructive
; operation behind a two-step confirmation, sends it, and reports the
; drive's real status response. See wiki/tasks/format.md.
;
; Invocation: FORMAT <dev>:<name>,<id>  (e.g. FORMAT 8:MYDISK,01)
; With no/incomplete arguments, falls back to interactive prompts for
; device, name, and ID in turn (each reprompts on invalid input). A CLI
; argument that structurally parses (has a comma) but fails validation
; (bad length/charset/device range) is a hard error -- CLI mode does not
; fall back to interactive prompting, only fully-missing/malformed
; arguments (no comma found at all) do.

.include "command64.inc"
.include "common.inc"

.define VERSION_MAJOR "0"
.define VERSION_MINOR "1"
.define VERSION_STAGE "0"
.include "build_format.inc"

.import __MAIN_START__

.segment "HEADER"
    .word __MAIN_START__

.segment "CODE"

; ---------------------------------------------------------------------------
; Entry point
; ---------------------------------------------------------------------------
start:
    ldx #<verMsg
    ldy #>verMsg
    jsr printStr

    ; --- Parse CLI args: skip our own name token, then optional spaces ---
    ldy ParsePos
pcSkipToken:
    lda CommandBuffer, y
    beq pcNoArgsNear
    iny
    cmp #' '
    bne pcSkipToken

pcSkipSpaces:
    lda CommandBuffer, y
    cmp #' '
    bne pcEndSpaces
    iny
    jmp pcSkipSpaces
pcEndSpaces:
    cmp #0
    bne pcContinue1
pcNoArgsNear:
    jmp pcNoArgs

pcContinue1:
    ; Build a pointer to CommandBuffer+y so DOS_PARSE_PREFIX can strip an
    ; optional "<dev>:" prefix (same idiom as label.s).
    tya
    clc
    adc #<CommandBuffer
    sta PrintPtrLo
    lda #>CommandBuffer
    adc #0
    sta PrintPtrHi

    ldx #PrintPtrLo
    lda #DOS_PARSE_PREFIX
    jsr OS_API
    sta DeviceNum

    ; Recompute y from the (possibly prefix-advanced) pointer.
    lda PrintPtrLo
    sec
    sbc #<CommandBuffer
    tay

pcSkipSpaces2:
    lda CommandBuffer, y
    cmp #' '
    bne pcEndSpaces2
    iny
    jmp pcSkipSpaces2
pcEndSpaces2:
    cmp #0
    beq pcNoArgs            ; nothing after the device prefix -> incomplete

    ; --- Capture the name portion up to a comma. Cap the write at 40
    ; chars but keep scanning past that so an overlong name still reaches
    ; the comma correctly and fails length validation below, rather than
    ; being misreported as "no comma found". ---
    ldx #0
pcNameLoop:
    lda CommandBuffer, y
    beq pcNoComma            ; ran off the end without a comma -> incomplete
    cmp #','
    beq pcNameFound
    cpx #40
    bcs pcNameNoWrite
    sta NameBuf, x
    inx
pcNameNoWrite:
    iny
    jmp pcNameLoop
pcNameFound:
    iny                      ; skip the comma itself
    stx NameLen
    lda #0
    sta NameBuf, x
    jsr rtrimName

    ; Skip optional spaces right after the comma (UX convenience --
    ; nothing in the spec forbids "NAME, 01").
pcSkipSpaces3:
    lda CommandBuffer, y
    cmp #' '
    bne pcEndSpaces3
    iny
    jmp pcSkipSpaces3
pcEndSpaces3:

    ; --- Capture the ID portion up to space/null. Same cap-and-keep-
    ; scanning approach as the name. ---
    ldx #0
pcIdLoop:
    lda CommandBuffer, y
    beq pcIdDone
    cmp #' '
    beq pcIdDone
    cpx #8
    bcs pcIdNoWrite
    sta IdBuf, x
    inx
pcIdNoWrite:
    iny
    jmp pcIdLoop
pcIdDone:
    stx IdLen
    lda #0
    sta IdBuf, x

    ; --- CLI mode: validate strictly. Any failure is a hard error, no
    ; reprompting (per spec). ---
    lda DeviceNum
    jsr validateDeviceNum
    bcs cliErrDevice
    jsr validateName
    bcs cliErrName
    jsr validateId
    bcs cliErrId
    jmp doConfirmAndFormat

pcNoComma:
pcNoArgs:
    jmp needInteractive

cliErrDevice:
    ldx #<msgErrDevice
    ldy #>msgErrDevice
    jsr printStr
    jmp doExit

cliErrName:
    ldx #<msgErrName
    ldy #>msgErrName
    jsr printStr
    jmp doExit

cliErrId:
    ldx #<msgErrId
    ldy #>msgErrId
    jsr printStr
    jmp doExit

; ---------------------------------------------------------------------------
; Interactive fallback: prompt for device, name, ID in turn, each looping
; until valid.
; ---------------------------------------------------------------------------
needInteractive:
    jsr promptDevice
    jsr promptName
    jsr promptId
    jmp doConfirmAndFormat

promptDevice:
pdRetry:
    ldx #<msgPromptDevice
    ldy #>msgPromptDevice
    jsr printStr

    lda #<LineBuf
    sta BufPtrLo
    lda #>LineBuf
    sta BufPtrHi
    lda #3
    sta MaxLen
    jsr readLine

    jsr parseDeviceDigits
    bcs pdInvalid
    sta DeviceNum
    jsr validateDeviceNum
    bcs pdInvalid
    rts
pdInvalid:
    ldx #<msgInvalidRetry
    ldy #>msgInvalidRetry
    jsr printStr
    jmp pdRetry

promptName:
pnRetry:
    ldx #<msgPromptName
    ldy #>msgPromptName
    jsr printStr

    lda #<NameBuf
    sta BufPtrLo
    lda #>NameBuf
    sta BufPtrHi
    lda #40
    sta MaxLen
    jsr readLine
    sty NameLen
    jsr rtrimName
    jsr validateName
    bcs pnInvalid
    rts
pnInvalid:
    ldx #<msgInvalidRetry
    ldy #>msgInvalidRetry
    jsr printStr
    jmp pnRetry

promptId:
piRetry:
    ldx #<msgPromptId
    ldy #>msgPromptId
    jsr printStr

    lda #<IdBuf
    sta BufPtrLo
    lda #>IdBuf
    sta BufPtrHi
    lda #8
    sta MaxLen
    jsr readLine
    sty IdLen
    jsr validateId
    bcs piInvalid
    rts
piInvalid:
    ldx #<msgInvalidRetry
    ldy #>msgInvalidRetry
    jsr printStr
    jmp piRetry

; ---------------------------------------------------------------------------
; Destructive-action confirmation (Y/N gate + re-typed name match), then
; send. Falls through to doExit either way.
; ---------------------------------------------------------------------------
doConfirmAndFormat:
    jsr confirmDestructive
    bcs doExit               ; aborted; message already printed
    jsr sendFormatCommand

doExit:
    lda #DOS_EXIT
    jsr OS_API

confirmDestructive:
    ldx #<msgConfirmPart1
    ldy #>msgConfirmPart1
    jsr printStr

    jsr computeDevDigits
    ldx #<DevDigits
    ldy #>DevDigits
    jsr printStr

    ldx #<msgConfirmPart2
    ldy #>msgConfirmPart2
    jsr printStr

cdPoll:
    jsr KernalGetIn
    beq cdPoll
    pha
    jsr KernalChROUT
    pla

    cmp #$79                 ; shifted 'Y'
    beq cdYes
    cmp #$59                 ; lowercase 'y' (some keyboard mapping modes)
    beq cdYes

    jsr printCrlf
    ldx #<msgCancelled
    ldy #>msgCancelled
    jsr printStr
    sec
    rts

cdYes:
    jsr printCrlf
    ldx #<msgReenterName
    ldy #>msgReenterName
    jsr printStr

    lda #<ConfirmBuf
    sta BufPtrLo
    lda #>ConfirmBuf
    sta BufPtrHi
    lda #40
    sta MaxLen
    jsr readLine
    sty ConfirmLen
    jsr rtrimConfirm
    jsr compareNames
    bcs cdMismatch
    clc
    rts

cdMismatch:
    ldx #<msgMismatch
    ldy #>msgMismatch
    jsr printStr
    sec
    rts

; ---------------------------------------------------------------------------
; Build "<dev>:N:<name>,<id>" and send it via DOS_SEND_COMMAND. No true
; concurrent animation is possible around a single blocking KERNAL call on
; this single-tasking CPU, so the "busy indicator" is a static message
; printed just before the (synchronous, non-cancellable) send.
; ---------------------------------------------------------------------------
sendFormatCommand:
    lda #0
    sta CmdIdx

    jsr computeDevDigits
    ldx #<DevDigits
    ldy #>DevDigits
    jsr appendStr

    ldx #<litNColon
    ldy #>litNColon
    jsr appendStr

    ldx #<NameBuf
    ldy #>NameBuf
    jsr appendStr

    ldx #<litComma
    ldy #>litComma
    jsr appendStr

    ldx #<IdBuf
    ldy #>IdBuf
    jsr appendStr

    ldx CmdIdx
    lda #0
    sta CmdBuf, x

    ldx #<msgFormatting
    ldy #>msgFormatting
    jsr printStr

    lda #<RespBuf
    sta PrintPtrLo
    lda #>RespBuf
    sta PrintPtrHi
    ldx #<CmdBuf
    ldy #>CmdBuf
    lda #DOS_SEND_COMMAND
    jsr OS_API
    bcs sfcTransportErr

    ldx #<msgResult
    ldy #>msgResult
    jsr printStr
    ldx #<RespBuf
    ldy #>RespBuf
    jsr printStr
    jsr printCrlf
    rts

sfcTransportErr:
    jsr printCrlf
    ldx #<msgTransportErr
    ldy #>msgTransportErr
    jsr printStr
    rts

; ---------------------------------------------------------------------------
; Helpers
; ---------------------------------------------------------------------------

; printStr: Input X/Y = pointer lo/hi to a null-terminated string.
printStr:
    lda #DOS_PRINT_STR
    jsr OS_API
    rts

printCrlf:
    lda #PetCr
    jsr KernalChROUT
    rts

; readLine: reads a line of keyboard input, echoing each char, honoring
; PetDel as destructive backspace, terminating on PetCr.
; Input:  BufPtrLo/Hi = destination buffer (must hold MaxLen+1 bytes)
;         MaxLen = max characters to accept
; Output: Y = length written; buffer null-terminated
; Clobbers: A, X, Y
readLine:
    ldy #0
rlLoop:
    tya
    pha
rlPoll:
    jsr KernalGetIn
    beq rlPoll
    tax
    pla
    tay
    txa

    cmp #PetCr
    beq rlDone

    cmp #PetDel
    bne rlHandleChar
    tya
    beq rlLoop
    dey
    lda #PetDel
    jsr KernalChROUT
    jmp rlLoop

rlHandleChar:
    cpy MaxLen
    bcs rlLoop

    jsr KernalChROUT
    sta (BufPtrLo), y
    iny
    jmp rlLoop

rlDone:
    lda #PetCr
    jsr KernalChROUT
    lda #0
    sta (BufPtrLo), y
    rts

; appendStr: appends a null-terminated string into CmdBuf at CmdIdx,
; advancing CmdIdx. Does not write the final terminator itself.
; Input: X/Y = source pointer lo/hi
; Clobbers: A, Y, BufPtrLo/Hi
appendStr:
    stx BufPtrLo
    sty BufPtrHi
    ldy #0
asLoop:
    lda (BufPtrLo), y
    beq asDone
    pha
    ldx CmdIdx
    pla
    sta CmdBuf, x
    inc CmdIdx
    iny
    jmp asLoop
asDone:
    rts

; computeDevDigits: renders DeviceNum (8-11) as decimal ASCII into
; DevDigits, null-terminated.
computeDevDigits:
    lda DeviceNum
    cmp #10
    bcc cddSingle
    lda #'1'
    sta DevDigits
    lda DeviceNum
    sec
    sbc #10
    clc
    adc #'0'
    sta DevDigits + 1
    lda #0
    sta DevDigits + 2
    rts
cddSingle:
    clc
    adc #'0'
    sta DevDigits
    lda #0
    sta DevDigits + 1
    rts

; parseDeviceDigits: parses LineBuf (null-terminated ASCII digits, up to
; 2 of them) into a byte value.
; Output: A = value, Carry clear on success; Carry set on empty/non-digit/
;         too-long input (caps at 2 digits to avoid byte wraparound).
parseDeviceDigits:
    lda LineBuf
    beq pdBad
    ldy #0
    lda #0
    sta TmpVal
pdLoop:
    lda LineBuf, y
    beq pdDone
    cpy #2
    bcs pdBad
    cmp #'0'
    bcc pdBad
    cmp #'9' + 1
    bcs pdBad
    sec
    sbc #'0'
    pha
    lda TmpVal
    asl a
    sta TmpVal2
    asl a
    asl a
    clc
    adc TmpVal2
    sta TmpVal
    pla
    clc
    adc TmpVal
    sta TmpVal
    iny
    jmp pdLoop
pdDone:
    cpy #0
    beq pdBad
    lda TmpVal
    clc
    rts
pdBad:
    sec
    rts

; validateDeviceNum: Input A = candidate device number.
; Output: Carry clear if within [DEV_MIN, DEV_MAX], else set.
validateDeviceNum:
    cmp #DEV_MIN
    bcc vdBad
    cmp #(DEV_MAX + 1)
    bcs vdBad
    clc
    rts
vdBad:
    sec
    rts

; validateName: checks NameBuf/NameLen against the 1-16 char length rule
; and rejects control chars, ',' and ':'.
validateName:
    lda NameLen
    cmp #1
    bcc vnBad
    cmp #(NAME_MAX_LEN + 1)
    bcs vnBad
    lda #<NameBuf
    sta BufPtrLo
    lda #>NameBuf
    sta BufPtrHi
    ldx NameLen
    jsr validateCharset
    bcs vnBad
    clc
    rts
vnBad:
    sec
    rts

; validateId: checks IdBuf/IdLen is exactly ID_LEN chars and rejects
; control chars, ',' and ':'.
validateId:
    lda IdLen
    cmp #ID_LEN
    bne viBad
    lda #<IdBuf
    sta BufPtrLo
    lda #>IdBuf
    sta BufPtrHi
    ldx IdLen
    jsr validateCharset
    bcs viBad
    clc
    rts
viBad:
    sec
    rts

; validateCharset: rejects bytes below $20 (control chars) and the
; delimiter characters ',' and ':', which would corrupt the assembled
; command string.
; Input: BufPtrLo/Hi = buffer, X = length
; Output: Carry set if any byte invalid
; Clobbers: A, Y
validateCharset:
    cpx #0
    beq vcOk
    ldy #0
vcLoop:
    lda (BufPtrLo), y
    cmp #$20
    bcc vcBad
    cmp #','
    beq vcBad
    cmp #':'
    beq vcBad
    iny
    dex
    bne vcLoop
vcOk:
    clc
    rts
vcBad:
    sec
    rts

; rtrimName: strips trailing spaces from NameBuf/NameLen in place.
rtrimName:
    ldx NameLen
rtnLoop:
    cpx #0
    beq rtnDone
    lda NameBuf - 1, x
    cmp #' '
    bne rtnDone
    dex
    jmp rtnLoop
rtnDone:
    stx NameLen
    lda #0
    sta NameBuf, x
    rts

; rtrimConfirm: strips trailing spaces from ConfirmBuf/ConfirmLen in place
; (mirrors rtrimName so the re-typed confirmation name is held to the same
; rule as the original before comparing).
rtrimConfirm:
    ldx ConfirmLen
rtcLoop:
    cpx #0
    beq rtcDone
    lda ConfirmBuf - 1, x
    cmp #' '
    bne rtcDone
    dex
    jmp rtcLoop
rtcDone:
    stx ConfirmLen
    lda #0
    sta ConfirmBuf, x
    rts

; compareNames: Output Carry clear if NameBuf/NameLen exactly matches
; ConfirmBuf/ConfirmLen, else Carry set.
compareNames:
    lda NameLen
    cmp ConfirmLen
    bne cnBad
    lda NameLen
    beq cnOk
    tax
cnLoop:
    lda NameBuf - 1, x
    cmp ConfirmBuf - 1, x
    bne cnBad
    dex
    bne cnLoop
cnOk:
    clc
    rts
cnBad:
    sec
    rts

; ---------------------------------------------------------------------------
; Data
; ---------------------------------------------------------------------------
verMsg:
    .byte "FORMAT V"
    .byte VERSION_MAJOR, ".", VERSION_MINOR, ".", VERSION_STAGE, "."
    .byte BUILD_NUMBER
    .byte $0D, 0

msgPromptDevice:
    .byte "DEVICE (8-11): ", 0
msgPromptName:
    .byte "DISK NAME: ", 0
msgPromptId:
    .byte "DISK ID: ", 0
msgInvalidRetry:
    .byte $0D, "INVALID, TRY AGAIN.", $0D, 0

msgErrDevice:
    .byte "ERROR: DEVICE MUST BE 8-11.", $0D, 0
msgErrName:
    .byte "ERROR: NAME MUST BE 1-16 CHARS, NO ',' OR ':'.", $0D, 0
msgErrId:
    .byte "ERROR: ID MUST BE EXACTLY 2 CHARS.", $0D, 0

msgConfirmPart1:
    .byte "FORMAT DRIVE ", 0
msgConfirmPart2:
    .byte " - ALL DATA WILL BE LOST. CONTINUE? (Y/N) ", 0
msgCancelled:
    .byte "FORMAT CANCELLED.", $0D, 0
msgReenterName:
    .byte "RE-ENTER DISK NAME TO CONFIRM: ", 0
msgMismatch:
    .byte "NAME MISMATCH. FORMAT CANCELLED.", $0D, 0

msgFormatting:
    .byte "FORMATTING...", $0D, 0
msgResult:
    .byte "RESULT: ", 0
msgTransportErr:
    .byte "FORMAT FAILED (TRANSPORT ERROR).", $0D, 0

litNColon:
    .byte ":N:", 0
litComma:
    .byte ",", 0

; ---------------------------------------------------------------------------
; Buffers (BSS)
; ---------------------------------------------------------------------------
DeviceNum:   .res 1
NameLen:     .res 1
IdLen:       .res 1
ConfirmLen:  .res 1
CmdIdx:      .res 1
TmpVal:      .res 1
TmpVal2:     .res 1

DevDigits:   .res 3
NameBuf:     .res 41
IdBuf:       .res 9
ConfirmBuf:  .res 41
LineBuf:     .res 4
CmdBuf:      .res 32
RespBuf:     .res 40
