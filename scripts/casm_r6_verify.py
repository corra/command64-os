#!/usr/bin/env python3
"""casm_r6_verify.py -- assembler-independent verification of a Command 64 R6
relocation footer.

Reads ONLY the bytes of an R6-relocatable PRG (a .ref.hex manifest body or a
raw .prg) and the documented R6 format. It never reads opcodes.s, never
disassembles code, and never decides whether the *code* bytes are correct --
it verifies the relocation table/footer structure and demonstrates
multi-base application.

Usage:
    casm_r6_verify.py <file>              # .ref.hex (hex body) or .prg (raw)
    casm_r6_verify.py <file> --bases 3800,5000,9000

R6 layout:  <program image> <count*2 LE offset words> <base LE> <count LE> "R6"
Each offset names a byte in the program image that holds the HIGH byte of a
16-bit address; at load to a new base the loader adds (new_page - base_page)
to that byte.
"""
from __future__ import annotations

import argparse
import hashlib
import sys
from pathlib import Path


def load_bytes(path: Path) -> bytes:
    raw = path.read_bytes()
    # A .ref.hex is ASCII hex with '#' comments; a .prg is binary.
    try:
        text = raw.decode("ascii")
    except UnicodeDecodeError:
        return raw
    toks = []
    for line in text.splitlines():
        line = line.split("#", 1)[0].strip()
        if line:
            toks.extend(line.split())
    if all(len(t) == 2 for t in toks) and toks:
        try:
            return bytes(int(t, 16) for t in toks)
        except ValueError:
            pass
    return raw


def verify(body: bytes, bases: list[int]) -> tuple[bool, list[str]]:
    out: list[str] = []
    ok = True

    def note(msg: str, good: bool = True) -> None:
        nonlocal ok
        out.append(("  ok  " if good else " FAIL ") + msg)
        if not good:
            ok = False

    out.append(f"bytes {len(body)}  sha256 {hashlib.sha256(body).hexdigest()}")
    if body[-2:] != b"R6":
        note("no 'R6' magic in the last two bytes", False)
        return ok, out

    count = int.from_bytes(body[-4:-2], "little")
    base = int.from_bytes(body[-6:-4], "little")
    tbl_end = len(body) - 6
    tbl_start = tbl_end - 2 * count
    if tbl_start < 2:
        note(f"declared count {count} does not fit before the footer", False)
        return ok, out

    prog = body[2:tbl_start]
    load_hdr = int.from_bytes(body[0:2], "little")
    offs = [int.from_bytes(body[tbl_start + 2 * i:tbl_start + 2 * i + 2], "little")
            for i in range(count)]

    note(f"footer: base ${base:04X}  count {count}  magic 'R6'")
    note(f"load header ${load_hdr:04X} == footer base ${base:04X}",
         load_hdr == base)
    note(f"program image {len(prog)} bytes  "
         f"${base:04X}..${base + len(prog) - 1:04X}")
    note(f"relocation table {2 * count} bytes at file offset "
         f"{tbl_start}..{tbl_end - 1}")

    top_page = (base + len(prog) - 1) >> 8
    base_page = base >> 8

    note(f"offsets strictly ascending and unique",
         offs == sorted(offs) and len(set(offs)) == len(offs))
    note(f"offset range min ${min(offs):04X}  max ${max(offs):04X}  "
         f"(< program length ${len(prog):04X})",
         0 <= min(offs) and max(offs) < len(prog))

    bad = [o for o in offs if not (base_page <= prog[o] <= top_page)]
    note(f"all {count} entries point at an in-image high byte "
         f"(pages ${base_page:02X}..${top_page:02X}); out-of-range: {len(bad)}",
         not bad)
    if bad:
        out.append(f"        first bad offsets: {[hex(o) for o in bad[:8]]}")
    touched = sorted(set(prog[o] for o in offs))
    out.append(f"        high-byte pages touched: {[hex(p) for p in touched]}")

    for nb in bases:
        delta = (nb >> 8) - base_page
        relocated = [(prog[o] + delta) & 0xFF for o in offs]
        lo, hi = (base_page + delta), (top_page + delta)
        good = all(lo <= r <= hi for r in relocated)
        note(f"relocate to ${nb:04X} (delta {delta:+d} pages): "
             f"all high bytes in ${lo:02X}..${hi:02X}", good)

    return ok, out


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("file", type=Path)
    ap.add_argument("--bases", default="3800,5000,9000",
                    help="comma-separated hex load bases for the application "
                         "check (default: 3800,5000,9000)")
    args = ap.parse_args()

    bases = [int(b, 16) for b in args.bases.split(",") if b.strip()]
    ok, lines = verify(load_bytes(args.file), bases)
    print("\n".join(lines))
    print("\nR6 VERIFY: " + ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
