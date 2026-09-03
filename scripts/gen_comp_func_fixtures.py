#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
#
# gen_comp_func_fixtures.py - deterministic fixture pairs for the COMP
# CASM-native migration functional matrix (Increment 5 of
# brain/plans/2026-09-02-comp-casm-native-migration.md).
#
# Every file is raw bytes, written verbatim onto command64_comp_func_test.d64
# with `cc1541 -w`. Contents are fully determined by this script so a reviewer
# can recompute every expected COMP offset/byte by hand.
#
#   id1  / id2    200 bytes, identical                      -> FILES COMPARE OK
#   one1 / one2   100 bytes, differ at offset $000032 only  -> one COMPARE ERROR line
#   many1/ many2  200 bytes, differ at 15 offsets           -> 10 lines + STOPPING
#   long1/ long2  150 / 100 bytes, first 100 identical      -> FILES ARE DIFFERENT SIZES
#   prga / prgb   22-byte PRGs, load addr $2000 vs $3000    -> COMPARE ERROR AT $000001: $20 $30
#
# Missing-file / too-many-args / slash-option cases need no fixture (they are
# argument-parse rejections); the harness just names id1 / a bogus file.

import sys
from pathlib import Path

MANY_OFFSETS = [3, 10, 20, 33, 47, 61, 74, 88, 99, 112, 130, 151, 168, 180, 199]


def build():
    files = {}

    body200 = bytes((i * 7 + 11) & 0xFF for i in range(200))
    files["id1"] = body200
    files["id2"] = body200

    one = bytearray((i * 3 + 5) & 0xFF for i in range(100))
    files["one1"] = bytes(one)
    two = bytearray(one)
    two[0x32] ^= 0xFF
    files["one2"] = bytes(two)

    m1 = bytearray((i * 5 + 1) & 0xFF for i in range(200))
    m2 = bytearray(m1)
    for off in MANY_OFFSETS:
        m2[off] = (m2[off] + 0x40) & 0xFF
    files["many1"] = bytes(m1)
    files["many2"] = bytes(m2)

    long_common = bytes((i * 9 + 2) & 0xFF for i in range(100))
    files["long1"] = long_common + bytes((i * 2 + 1) & 0xFF for i in range(50))
    files["long2"] = long_common

    prg_body = bytes(range(20))
    files["prga"] = bytes([0x00, 0x20]) + prg_body
    files["prgb"] = bytes([0x00, 0x30]) + prg_body

    return files


def main(argv):
    if len(argv) != 2:
        sys.stderr.write("usage: gen_comp_func_fixtures.py <output-dir>\n")
        return 2
    out = Path(argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for name, data in build().items():
        (out / name).write_bytes(data)
        print(f"  {name}: {len(data)} bytes")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
