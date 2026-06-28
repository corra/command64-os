# Task Plan: Dynamic Device Number in Shell Prompt

## Description

Update the shell prompt from the static `C64:> ` to a dynamic `C64[N]:> ` where `N` is
the value of `CurrentDevice` (8–11), reflecting the active disk device at all times.

## Scope

- Print the active device number in the shell prompt on every iteration of `mainLoop`.
- Reuse the existing `printDecimal16` routine — no new memory variables or buffers.
- Leave all other device logic (`DRIVE` command, `CurrentDevice`, file ops) untouched.

## Approach

Replace the single `petPrintString promptMsg` call in `mainLoop` with a small
`printPrompt` subroutine that prints three parts in sequence: a static prefix, the device
number, and a static suffix.

## Implementation

### 1. Add `printPrompt` subroutine — `shell.asm`

Place near `cmdDrive` or just above the string literals block:

```asm
printPrompt:
    lda #<promptPrefixMsg
    ldy #>promptPrefixMsg
    jsr petPrintString          // print "C64["

    lda CurrentDevice
    tax
    ldy #0
    jsr printDecimal16          // print 8, 9, 10, or 11

    lda #<promptSuffixMsg
    ldy #>promptSuffixMsg
    jsr petPrintString          // print "]:> "
    rts
```

### 2. Update `mainLoop` — `shell.asm`

```asm
mainLoop:
    jsr printPrompt             // replaces: lda/ldy/jsr petPrintString promptMsg
    jsr shellReadLine
    jsr shellDispatch
    jmp mainLoop
```

### 3. Replace `promptMsg` string literal — `shell.asm`

```asm
promptPrefixMsg:
    .text "C64["
    .byte 0

promptSuffixMsg:
    .text "]:> "
    .byte 0
```

## Notes

- `printDecimal16` clobbers `A`, `X`, `Y`, `HexValLo/Hi` — safe here since `mainLoop`
  calls it before any command parsing, so those ZP slots are free at this point.
- Prompt grows from 6 to 9–10 characters, acceptable on the 40-column display.
- The `DRIVE` no-args display (`Current device: N`) is unaffected and remains available.
