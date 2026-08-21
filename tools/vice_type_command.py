#!/usr/bin/env python3
"""Compute the exact vice_keyboard_petscii byte sequence for typing a
Command64 shell command or filename -- so an agent never has to hand-derive
PETSCII bytes for underscores or letter case again.

Usage:
    tools/vice_type_command.py "test_casm_expr"
    tools/vice_type_command.py "drive 9" --no-return

Prints one JSON object on stdout: the ready-to-use vice_keyboard_petscii
tool-call arguments, e.g. {"data": [84, 69, ...]}. Call vice_keyboard_petscii
with that "data" array directly -- do not hand-edit it.

WHY THIS EXISTS
----------------
Two independent traps make Command64 shell text impossible to type
correctly by naive translation, both documented the hard way in
.agents/workflows/vice-mcp-testing.md and C64_MCP_USAGE.md:

1. Underscore. ASCII `_` ($5F) is PETSCII left-arrow, not underscore.
   `vice_keyboard_type` cannot produce a real underscore at all (it has been
   observed rendering `_` as `+`). The actual underscore byte is $A4.
2. Letter case is inverted. Command64's shell is lowercase-only, but on
   this charset the byte for uppercase ASCII ($41-$5A) renders as a
   *lowercase* glyph, and vice versa. To type the lowercase shell text
   Command64 expects, you must send the *uppercase* ASCII byte for each
   letter.

Both are correct today (2026-08) but are emulator/ROM-charset behavior, not
something this script can verify independently -- if VICE-side behavior
ever changes, this script's mapping and the workflow doc must be re-verified
together.

Only characters with a confirmed-safe mapping are accepted: lowercase
letters, digits, space, underscore, and ASCII punctuation in $20-$3F (where
PETSCII and screen code numerically coincide, per
reference-dash-no-character-literals). Anything else is rejected rather than
guessed -- verify it against C64_MCP_USAGE.md and extend this script
deliberately, don't type it by hand.
"""

import argparse
import json
import sys

UNDERSCORE_BYTE = 0xA4
RETURN_BYTE = 0x0D

# ASCII $20-$3F: space, digits, and punctuation where PETSCII and screen
# code numerically coincide -- safe to send as a literal ASCII byte.
SAFE_PUNCT_RANGE = range(0x20, 0x40)


def char_to_byte(c: str) -> int:
    if c == "_":
        return UNDERSCORE_BYTE
    if "a" <= c <= "z":
        # Inverted charset: send the uppercase ASCII byte to get the
        # lowercase glyph Command64's shell requires.
        return ord(c.upper())
    o = ord(c)
    if o in SAFE_PUNCT_RANGE:
        return o
    raise ValueError(
        f"no confirmed-safe PETSCII mapping for {c!r} (${o:02X}) -- verify "
        "against C64_MCP_USAGE.md and extend this script deliberately, "
        "don't hand-derive it. Uppercase letters are rejected outright: "
        "Command64 shell commands are lowercase-only, and mixed-case "
        "shifted/unshifted identifier typing is a separate, unconfirmed "
        "mapping out of scope for this script."
    )


def build_bytes(text: str, send_return: bool) -> list:
    if "\n" in text or "\r" in text:
        raise ValueError(
            "pass plain text with no embedded newline; use --no-return to "
            "suppress the trailing Return this script appends by default"
        )
    data = [char_to_byte(c) for c in text]
    if send_return:
        data.append(RETURN_BYTE)
    return data


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                  formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("text", help="lowercase command/filename text to type")
    ap.add_argument("--no-return", action="store_true",
                     help="do not append the trailing Return ($0D) byte")
    args = ap.parse_args()

    try:
        data = build_bytes(args.text, send_return=not args.no_return)
    except ValueError as e:
        print(f"error: {e}", file=sys.stderr)
        sys.exit(1)

    explain = " ".join(f"{c!r}->${b:02X}" for c, b in
                        zip(args.text + ("\\n" if not args.no_return else ""), data))
    print(f"# {explain}", file=sys.stderr)
    print(json.dumps({"name": "vice_keyboard_petscii", "arguments": {"data": data}}))


if __name__ == "__main__":
    main()
