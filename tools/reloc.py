#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
#
# reloc.py - Phase 6B Binary Relocator diff build tool.
#
# Takes two builds of the same external app, compiled at a 1-page offset
# (e.g. $2600 and $2700), diffs them byte-by-byte to find every high-byte
# address reference that shifted by exactly +1 page, and appends that list
# as a relocation table + footer to the $2600 binary. The OS loader
# (aptRelocate in loader.asm) uses this table to patch high bytes in place
# when a binary is loaded at a non-default page.
#
# Usage: reloc.py <prg_base> <prg_base_plus_one_page> <output_prg>

import sys
import struct

MAGIC = b"R6"  # $52, $36


def read_prg(path):
    """Returns (load_addr, code_bytes) for a C64 .prg file."""
    with open(path, "rb") as f:
        data = f.read()
    if len(data) < 2:
        raise ValueError(f"{path}: file too short to contain a PRG header")
    load_addr = data[0] | (data[1] << 8)
    return load_addr, data[2:]


def build_relocation_table(code_base, code_next):
    """Compares two same-length code segments (compiled 1 page apart) and
    returns the sorted list of byte offsets where a high-byte address
    reference shifted by exactly +1 (i.e. code_next[i] == code_base[i] + 1).

    Uses plain integer arithmetic (not mod 256) so a base byte of $FF next
    to a next-byte of $00 is correctly treated as an unexpected mismatch
    rather than a false-positive relocation point -- no label inside the
    user program space wraps from $FF to $00 across a one-page offset.
    """
    if len(code_base) != len(code_next):
        raise ValueError(
            f"Code segments differ in length: base={len(code_base)} bytes, "
            f"next={len(code_next)} bytes. The two builds must produce "
            f"identical-length output (only high bytes should shift)."
        )

    offsets = []
    for i, (b, n) in enumerate(zip(code_base, code_next)):
        if n == b:
            continue
        if n == b + 1:
            offsets.append(i)
            continue
        raise ValueError(
            f"Unexpected diff at offset {i:#06x}: base byte {b:#04x}, "
            f"next byte {n:#04x} (expected equal or exactly +1). This "
            f"usually means the two builds are not aligned the same way "
            f"(e.g. non-deterministic codegen or a base address that "
            f"isn't a full page apart)."
        )
    return offsets


def main():
    if len(sys.argv) != 4:
        print(f"Usage: {sys.argv[0]} <prg_base> <prg_base_plus_one_page> <output_prg>",
              file=sys.stderr)
        return 1

    prg_base_path, prg_next_path, out_path = sys.argv[1:4]

    base_addr, code_base = read_prg(prg_base_path)
    next_addr, code_next = read_prg(prg_next_path)

    if next_addr != base_addr + 0x0100:
        raise ValueError(
            f"{prg_next_path} load address {next_addr:#06x} is not exactly "
            f"one page above {prg_base_path} load address {base_addr:#06x}"
        )

    offsets = build_relocation_table(code_base, code_next)

    table_bytes = b"".join(struct.pack("<H", off) for off in offsets)
    footer = struct.pack("<HH", base_addr, len(offsets)) + MAGIC

    with open(out_path, "wb") as f:
        f.write(struct.pack("<H", base_addr))
        f.write(code_base)
        f.write(table_bytes)
        f.write(footer)

    print(f"reloc.py: {out_path}: base={base_addr:#06x}, "
          f"{len(code_base)} code bytes, {len(offsets)} relocation points")
    return 0


if __name__ == "__main__":
    sys.exit(main())
