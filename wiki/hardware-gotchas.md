# Commodore 64 Hardware Gotchas (Hard-Won)

This document aggregates hard-won, critical technical findings and hardware behaviors encountered during the development of command64. These rules are vital to keep in mind when modifying the OS core or writing external applications.

## 1. Segment Overlaps
*   **Behavior:** As the OS shell code grows, code segments can silently overflow and clobber each other.
*   **Mitigation:** Proactive realignment of segments (with at least 64-byte padding) is required in the linker/assembler configuration files. Always verify output maps and `.sym` files when adding code to `src/command64/shell.asm` or `vmm.asm`.

## 2. KERNAL non-reentrancy & BRK Trap Model
*   **Behavior:** A Software Interrupt (using `BRK` vectors) to execute OS Service Bus calls is non-viable for high-level OS calls. The C64 KERNAL routines (such as keyboard and disk operations) are not re-entrant; interrupting a KERNAL call with a custom `BRK` handler that makes further KERNAL calls causes state corruption.
*   **Mitigation:** Use a direct dispatcher Jump Table via `JSR $1000` (INT 21h equivalent), which acts as a stable, single-entry API entry point rather than intercepting hardware vectors.

## 3. Logical File Numbers (LFNs)
*   **Behavior:** The C64 KERNAL maps file operations using LFNs (Logical File Numbers). Certain LFNs are reserved or have special meaning:
    *   LFNs `2–9` are safe for standard application file handles.
    *   LFN `13` is reserved for OS internal command directory reads (`cmdDir`).
    *   LFN `14` is reserved for checking file existence (`checkExistence`).
    *   LFN `15` is reserved for the drive command channel.
*   **Mitigation:** Never assign LFN 13, 14, or 15 to user handles. Avoid reusing active handles.

## 4. BASIC Warm Start Address
*   **Behavior:** To exit the OS and return safely to BASIC, jumping to the pointer at `($0338)` can cause hangs or soft resets depending on current memory banking.
*   **Mitigation:** Use a direct jump to the BASIC warm start ROM entry point: `jmp $E37B`.

## 5. Kick Assembler String Mapping
*   **Behavior:** Kick Assembler's `.text` directive maps standard lowercase ASCII characters directly to C64 PETSCII control codes by default.
*   **Mitigation:** Send a mixed-case control code `$0E` at OS startup to switch the C64 to mixed-case mode. Ensure all embedded strings are normalized.

## 6. Keyboard Polling (`GETIN`) Clobbers Y
*   **Behavior:** The KERNAL keyboard polling routine `$FFE4` (`GETIN`) clobbers the `Y` register.
*   **Mitigation:** Always save/restore or avoid relying on the `Y` register across keyboard polling loops in the shell or applications.

## 7. lowercase Mode Dispatch Normalization
*   **Behavior:** Normalizing user input characters for case-insensitive matching must handle unshifted keys. Using `and #$7F` on unshifted keys ($41-$5A) maps them to control characters ($01-$1A), which match nothing.
*   **Mitigation:** Use `ora #$20` to safely normalize uppercase/lowercase characters to PETSCII lowercase ($61-$7A).

## 8. Stack Pointer Discipline in ahExit
*   **Behavior:** Spawning external programs leaves return addresses on the C64 hardware stack (2 bytes from `jsr UserProgStart`, plus 2 bytes from `jsr $1000` OS entry). Running multiple external programs without reclaiming stack space causes stack overflow.
*   **Mitigation:** Reset the Stack Pointer `S` to `#$FF` inside the exit handler `ahExit` prior to returning to the shell main loop:
    ```assembly
    ldx #$ff
    txs
    jmp mainLoop
    ```
