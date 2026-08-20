#!/usr/bin/env python3
"""Decode C64 screen-RAM bytes (screen codes, not PETSCII/ASCII) into text.

Usage:
    tools/vice_screen_decode.py <hex_string> [--width 40]
    echo <hex_string> | tools/vice_screen_decode.py [--width 40]

<hex_string> is the data_hex value returned by vice_memory_read against
$0400 (or any screen-RAM range). Matches the screen-code table documented
in .agents/workflows/vice-mcp-testing.md's "State verification" section
(Command64's mixed-case charset ROM).
"""

import sys
import argparse

PUNCT = {
    0x1B: "[", 0x1D: "]", 0x3A: ":", 0x3E: ">", 0x2E: ".", 0x2D: "-",
    0x1F: "<-",  # left-arrow glyph, NOT underscore -- confirmed visually
    # (vice_display_screenshot) against a $5F-typed "test_casm_expr": it
    # renders as a left-arrow, matching this project's own
    # reference-vice-shell-underscore-petscii memory note. A real
    # underscore is a different PETSCII byte (164) with its own screen
    # code, not yet independently confirmed here -- do not add it to this
    # table on assumption alone.
    0x3C: "<", 0x2C: ",", 0x3B: ";", 0x2F: "/", 0x28: "(",
    0x29: ")", 0x22: '"', 0x27: "'", 0x3D: "=", 0x2B: "+", 0x2A: "*",
}


def decode_byte(c):
    if 1 <= c <= 26:
        return chr(ord("a") + c - 1)
    if 0x41 <= c <= 0x5A:
        return chr(c)
    if c == 0x20:
        return " "
    if 0x30 <= c <= 0x39:
        return chr(c)
    if c == 0:
        return "@"
    return PUNCT.get(c, "?")


def decode_rows(data: bytes, width: int):
    return ["".join(decode_byte(c) for c in data[i:i + width])
            for i in range(0, len(data), width)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("hex_string", nargs="?",
                         help="hex bytes (data_hex from vice_memory_read); reads stdin if omitted")
    parser.add_argument("--width", type=int, default=40,
                         help="bytes per row (default 40, one C64 text row)")
    args = parser.parse_args()

    hex_string = args.hex_string or sys.stdin.read()
    data = bytes.fromhex(hex_string.strip())
    for row in decode_rows(data, args.width):
        print(row.rstrip())


if __name__ == "__main__":
    main()
