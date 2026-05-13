# PETSCII API Specification (PETSCI)

## 1. Objective
To provide a centralized abstraction layer for all character-level input and output on the C64/Ultimate platform. This API translates the underlying C64 KERNAL hardware calls (`CHROUT`, `CHRIN`, `CLSALL`) into a standard interface consumable by the `command64` shell and higher-level DOS emulators. This ensures the system treats all text output as a strict PETSCII stream, abstracting the 8086 INT 21h/10h dependencies.

## 2. Calling Conventions (6502)
- **Parameter Passing:** Single byte values are passed in the Accumulator (A). Row/Column coordinates are passed in X (Row) and Y (Col) registers.
- **Return Values:** Return codes are passed in the Accumulator (A). Standard success code is `$00`, and failure is `$FF`.
- **State Preservation:** All API functions must preserve X, Y, and the Processor Status Register (P), unless explicitly stated otherwise.

## 3. API Contracts

### PETSCII_CHROUT (Print Character to Standard Output)
- **Description:** Prints a single PETSCII character to the current cursor position.
- **Input:** `A` = PETSCII byte value.
- **Implementation:** Wraps the KERNAL `$FFD2` (`CHROUT`) routine using a subroutine JSR call. Appends a line feed/carry return (PETSCII `$0D` / `$0A`) when the cursor reaches the boundary of the physical screen display.

### PETSCII_CHRIN (Read Character from Standard Input)
- **Description:** Waits for a character from the keyboard.
- **Input:** None.
- **Output:** `A` = PETSCII byte value of the character.
- **Implementation:** Wraps the KERNAL `$FFE4` (`CHRIN`) KERNAL routine.

### PETSCII_CLALL (Clear All / Screen Clear)
- **Description:** Resets the video buffer, moving the cursor to the top-left position (Row 0, Col 0) and filling the screen with the standard background attribute.
- **Input:** None.
- **Implementation:** Direct wrapper for KERNAL `$E548` (`CLALL`). This directly satisfies the requirements for the `CLS` internal command.

### PETSCII_GETCUR (Get Cursor Position)
- **Description:** Returns the current video coordinate.
- **Input:** None.
- **Output:** `X` = Current column, `Y` = Current row.

### PETSCII_SETCUR (Set Cursor Position)
- **Description:** Moves the cursor to a specific coordinate.
- **Input:** `X` = New column (0-39), `Y` = New row (0-24).
- **Implementation:** Maps to KERNAL `$FFD9` (`SETLFS`) and subsequent video memory writes.

## 4. Data Structures
- **Cursor Pointer:** A zero-page variable `CURSOR_POS` ($0200-0201) storing the current Row and Column.

## 5. Justification
This abstraction removes the need for the `command64.com` core logic to directly address hardware. When implementing complex DOS string routing or piping (Phase 2C), the redirection logic only needs to intercept calls within this PETSCII API, rather than scouring the system for KERNAL interrupts.
