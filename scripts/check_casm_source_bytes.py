#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
#
# check_casm_source_bytes.py - Reject host source bytes that native CASM cannot
# lex, before they are packaged onto a disk image.
#
# WHY THIS EXISTS
# ---------------
# Sources destined for native CASM are written to a .d64 by `cc1541 -w`, which
# copies host bytes verbatim with no character-set translation. The host file is
# ASCII; the C64 reads PETSCII. Those two agree on uppercase letters, digits and
# most punctuation, but NOT on lowercase: ASCII 'a'-'z' is $61-$7A, which in
# PETSCII is a block of graphics characters, not letters. CASM's lexer rejects
# them with CASM_DIAG_INVALID_SOURCE_BYTE.
#
# The failure is nasty in practice because it does not look like an encoding
# problem. The assembler gets far enough to print a banner, then reports
# something unrelated-sounding about the source, so the obvious suspects are the
# program and the assembler rather than the packaging step. Catching it at build
# time costs nothing and removes a whole class of C64-side debugging.
#
# The rule: an all-uppercase ASCII source needs no conversion, so that is what
# the build enforces. Identifier case still matters to CASM -- it compares raw
# bytes -- but uppercasing a whole file preserves identity as long as no two
# identifiers differ only by case, which this script also checks.

import argparse
import re
import sys

# Bytes CASM's lexer accepts: printable ASCII that coincides with PETSCII, plus
# the line and space whitespace it skips. Deliberately excludes $61-$7A.
TAB, LF, CR = 0x09, 0x0A, 0x0D
ALLOWED = {TAB, LF, CR} | set(range(0x20, 0x61))

IDENT = re.compile(rb'[A-Za-z_][A-Za-z0-9_]*')


def check_file(path):
    """Return a list of human-readable problems with `path`."""
    problems = []
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError as e:
        return [f"{path}: cannot read: {e}"]

    line = 1
    col = 1
    for b in data:
        if b not in ALLOWED:
            if 0x61 <= b <= 0x7A:
                why = (f"lowercase ASCII {chr(b)!r} (${b:02X}) -- PETSCII reads "
                       f"this as a graphics character, not a letter; "
                       f"uppercase it")
            else:
                why = f"byte ${b:02X} is outside CASM's accepted source range"
            problems.append(f"{path}:{line}:{col}: {why}")
            if len(problems) >= 10:
                problems.append(f"{path}: ... further problems suppressed")
                return problems
        if b == LF:
            line += 1
            col = 1
        else:
            col += 1
    return problems


def check_identifier_collisions(paths):
    """Identifiers differing only by case would merge under uppercasing."""
    seen = {}
    for path in paths:
        try:
            with open(path, "rb") as f:
                data = f.read()
        except OSError:
            continue
        # Strip comments so prose words are not treated as identifiers.
        body = b"\n".join(l.split(b";", 1)[0] for l in data.split(b"\n"))
        for m in IDENT.finditer(body):
            name = m.group(0)
            seen.setdefault(name.upper(), set()).add(name)
    out = []
    for upper, variants in sorted(seen.items()):
        if len(variants) > 1:
            spellings = ", ".join(sorted(v.decode("ascii") for v in variants))
            out.append(f"identifiers differ only by case and would merge when "
                       f"uppercased: {spellings}")
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Verify sources are safe to package for native CASM.")
    ap.add_argument("sources", nargs="+", help="host source files")
    args = ap.parse_args(argv)

    problems = []
    for path in args.sources:
        problems.extend(check_file(path))
    problems.extend(check_identifier_collisions(args.sources))

    if problems:
        sys.stderr.write("check_casm_source_bytes.py: sources are not "
                         "CASM-safe:\n")
        for p in problems:
            sys.stderr.write(f"  {p}\n")
        return 1

    print(f"check_casm_source_bytes.py: {len(args.sources)} source(s) OK "
          f"(uppercase ASCII, no case-colliding identifiers)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
