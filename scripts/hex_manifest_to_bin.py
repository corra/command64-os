#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
#
# hex_manifest_to_bin.py - Strict hex-manifest -> binary converter for CASM
# trusted reference fixtures (Phase 4 WP14).
#
# WHY THIS EXISTS
# ---------------
# WP14 proves the native CASM assembler emits correct PRG bytes by comparing
# its output against a trusted reference. The reference must NOT be produced by
# CASM or by any code that re-implements 6502 assembly -- otherwise a defect in
# the opcode table could be copied into the "reference" and hide itself. So the
# source of truth is a human-reviewed hexadecimal manifest containing the
# complete PRG (including its two-byte little-endian load-address header). This
# script only transcribes reviewed hex into bytes and checks self-declared
# metadata; it contains no 6502 knowledge whatsoever.
#
# MANIFEST FORMAT
# ---------------
#   - Blank lines are ignored.
#   - A '#' begins a comment to end-of-line (whole-line or inline/trailing).
#   - Two metadata directives are recognised inside comments; both optional and
#     each may appear at most once:
#         # bytes: <decimal>     expected total output length
#         # sha256: <64 hex>     expected SHA-256 of the output
#     When present they are verified and a mismatch is a hard error.
#   - Every remaining token must be exactly two hexadecimal digits = one byte.
#     Tokens are whitespace-separated; any amount of whitespace is allowed.
#
# The converter rejects: unknown '# <key>:' directives, non-hex tokens, tokens
# whose hex-digit count is not exactly two, an odd total hex-digit count,
# duplicate metadata directives, and any declared byte-count / SHA-256 that does
# not match the assembled bytes. Empty output is rejected (a PRG needs at least
# its two-byte header).

import argparse
import hashlib
import re
import sys

_HEX_BYTE = re.compile(r"^[0-9A-Fa-f]{2}$")
_META = re.compile(r"^#\s*(bytes|sha256)\s*:\s*(\S+)\s*$")


def fail(path, lineno, msg):
    where = f"{path}:{lineno}" if lineno else path
    sys.stderr.write(f"hex_manifest_to_bin.py: {where}: {msg}\n")
    sys.exit(1)


def parse_manifest(path, lines):
    """Return (data_bytes, declared_count_or_None, declared_sha_or_None)."""
    out = bytearray()
    declared_count = None
    declared_sha = None

    for lineno, raw in enumerate(lines, start=1):
        line = raw.rstrip("\n")

        # Metadata lives in a comment of the exact form "# key: value". Detect
        # it before generic comment-stripping so "# foo: bar" can be rejected
        # as an unknown directive rather than silently ignored.
        stripped = line.strip()
        if stripped.startswith("#"):
            m = _META.match(stripped)
            if m:
                key, value = m.group(1).lower(), m.group(2)
                if key == "bytes":
                    if declared_count is not None:
                        fail(path, lineno, "duplicate '# bytes:' directive")
                    if not value.isdigit():
                        fail(path, lineno, f"non-numeric byte count {value!r}")
                    declared_count = int(value)
                else:  # sha256
                    if declared_sha is not None:
                        fail(path, lineno, "duplicate '# sha256:' directive")
                    if not re.fullmatch(r"[0-9A-Fa-f]{64}", value):
                        fail(path, lineno, f"malformed sha256 {value!r}")
                    declared_sha = value.lower()
                continue
            # A comment that looks like a directive ("# word: ...") but is not
            # a recognised key is almost certainly a typo -- refuse it loudly
            # rather than let a mistyped "# byte:" pass unchecked.
            if re.match(r"^#\s*\w+\s*:", stripped):
                fail(path, lineno, f"unknown directive: {stripped!r}")
            continue  # ordinary full-line comment

        # Strip a trailing/inline comment, then tokenise the rest as hex bytes.
        code = line.split("#", 1)[0]
        for tok in code.split():
            if not _HEX_BYTE.match(tok):
                fail(path, lineno, f"invalid hex byte token {tok!r} "
                                   "(expected exactly two hex digits)")
            out.append(int(tok, 16))

    return bytes(out), declared_count, declared_sha


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Convert a reviewed hex manifest into a binary fixture.")
    ap.add_argument("input", help="path to the .ref.hex manifest")
    ap.add_argument("output", help="path to the binary file to write")
    args = ap.parse_args(argv)

    try:
        with open(args.input, "r", encoding="ascii") as f:
            lines = f.readlines()
    except OSError as e:
        fail(args.input, 0, f"cannot read: {e}")
    except UnicodeDecodeError:
        fail(args.input, 0, "manifest is not plain ASCII")

    data, declared_count, declared_sha = parse_manifest(args.input, lines)

    if len(data) == 0:
        fail(args.input, 0, "manifest produced zero bytes (a PRG needs at "
                            "least a two-byte load-address header)")

    if declared_count is not None and declared_count != len(data):
        fail(args.input, 0,
             f"declared byte count {declared_count} != actual {len(data)}")

    actual_sha = hashlib.sha256(data).hexdigest()
    if declared_sha is not None and declared_sha != actual_sha:
        fail(args.input, 0,
             f"declared sha256 {declared_sha} != actual {actual_sha}")

    try:
        with open(args.output, "wb") as f:
            f.write(data)
    except OSError as e:
        fail(args.output, 0, f"cannot write: {e}")

    sys.stderr.write(
        f"hex_manifest_to_bin.py: {args.output}: {len(data)} bytes, "
        f"sha256={actual_sha}\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
