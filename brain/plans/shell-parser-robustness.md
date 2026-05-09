---
feature: shell-parser-robustness
created: 2026-05-08
status: proposed
---

# Plan: Shell Parser Robustness (Space Trimming & Empty Lines)

## Goal & Rationale
Improve the shell's user experience by:
1.  **Ignoring Empty Lines**: Pressing *RETURN* without typing a command should simply return to the prompt instead of printing "Bad command".
2.  **Trimming Spaces**: Leading spaces should be ignored (e.g., `  cls` should work), and trailing spaces should not interfere with command matching.

## Scope
- Modify `shellDispatch` to skip leading spaces in `CommandBuffer`.
- Handle the "Empty Buffer" case (all spaces or null) by returning immediately.
- Update `cmdCompare` to use the offset determined by `shellDispatch` instead of hardcoded `ldy #0`.

## Files to Modify
| File | Action | Notes |
|------|--------|-------|
| `src/command64/shell.asm` | Modify | Add leading space skip logic to `shellDispatch`. |
| `src/command64/shell.asm` | Modify | Refactor `cmdCompare` to start from `ParsePos` instead of `0`. |

## Key Design Decisions
- **Unified ParsePos**: We will reuse the `ParsePos` Zero Page variable to store the start of the command name. `cmdCompare` will then use this as its base index.
- **KISS Early Exit**: In `shellDispatch`, if the first non-space character is a null terminator ($00), we return immediately to `mainLoop`. This satisfies the "empty line" requirement with minimal code.

## Verification Plan
1.  **Empty Line Test**: Press *RETURN* at a blank prompt. Expect: New prompt, no error.
2.  **Leading Space Test**: Type `  cls` and press *RETURN*. Expect: Screen clears.
3.  **Trailing Space Test**: Type `cls  ` and press *RETURN*. Expect: Screen clears.
4.  **Mixed Space Test**: Type `  echo  hello` and press *RETURN*. Expect: ` hello` is printed.
