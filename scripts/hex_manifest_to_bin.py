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
#   - Three metadata directives are recognised inside comments:
#         # bytes: <decimal>             expected total output length
#         # sha256: <64 hex>             expected SHA-256 of the output
#         # source_sha256: <name>=<64 hex>   expected SHA-256 of one source file
#     'bytes' and 'sha256' are each optional and may appear at most once; when
#     present they are verified and a mismatch is a hard error. 'source_sha256'
#     is optional and repeatable (one line per DASH source file) -- see
#     WP9's stale-artifact protection: with --source-dir, every recorded
#     source_sha256 entry is checked against the real file in that directory,
#     so a source edit made without regenerating the manifest fails the build
#     loudly instead of silently shipping stale bytes.
#   - 'provenance', 'cross-check', and 'load addr' header comments (written by
#     build_dash_manifest.py) are recognised as informational and skipped --
#     never validated, just not rejected as unknown directives.
#   - Every remaining token must be exactly two hexadecimal digits = one byte.
#     Tokens are whitespace-separated; any amount of whitespace is allowed.
#
# The converter rejects: unknown '# <key>:' directives, non-hex tokens, tokens
# whose hex-digit count is not exactly two, an odd total hex-digit count,
# duplicate 'bytes'/'sha256' directives, a malformed 'source_sha256' entry, and
# any declared byte-count / SHA-256 (output or source) that does not match the
# assembled bytes or the real source files. Empty output is rejected (a PRG
# needs at least its two-byte header).

import argparse
import hashlib
import re
import sys
from pathlib import Path

_HEX_BYTE = re.compile(r"^[0-9A-Fa-f]{2}$")
_META = re.compile(r"^#\s*(bytes|sha256|source_sha256)\s*:\s*(\S+)\s*$")
_SOURCE_SHA_VALUE = re.compile(r"^([^=\s]+)=([0-9A-Fa-f]{64})$")

# Human-readable header lines build_dash_manifest.py writes alongside the
# machine-checked directives above (provenance note, ca65 cross-check result,
# load address restated for a human reader). Recognized so they don't trip
# the "unknown directive" rejection below, but their values are never
# validated -- they are notes, not facts this script verifies.
_INFO_KEYS = {"provenance", "cross-check", "load addr"}
_INFO_LINE = re.compile(r"^#\s*([A-Za-z][A-Za-z \-]*?)\s*:\s*.*$")


def fail(path, lineno, msg):
    where = f"{path}:{lineno}" if lineno else path
    sys.stderr.write(f"hex_manifest_to_bin.py: {where}: {msg}\n")
    sys.exit(1)


def parse_manifest(path, lines):
    """Return (data_bytes, declared_count_or_None, declared_sha_or_None,
    declared_source_shas) where declared_source_shas is a dict of
    {source_filename: sha256_hex} built from every 'source_sha256' entry."""
    out = bytearray()
    declared_count = None
    declared_sha = None
    declared_source_shas = {}

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
                elif key == "sha256":
                    if declared_sha is not None:
                        fail(path, lineno, "duplicate '# sha256:' directive")
                    if not re.fullmatch(r"[0-9A-Fa-f]{64}", value):
                        fail(path, lineno, f"malformed sha256 {value!r}")
                    declared_sha = value.lower()
                else:  # source_sha256, repeatable
                    sm = _SOURCE_SHA_VALUE.match(value)
                    if not sm:
                        fail(path, lineno,
                             f"malformed source_sha256 entry {value!r} "
                             "(expected 'name=64hexdigits')")
                    name, sha = sm.group(1), sm.group(2).lower()
                    if name in declared_source_shas:
                        fail(path, lineno,
                             f"duplicate source_sha256 entry for {name!r}")
                    declared_source_shas[name] = sha
                continue
            info_m = _INFO_LINE.match(stripped)
            if info_m and info_m.group(1).lower() in _INFO_KEYS:
                continue  # recognized informational header line, unchecked
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

    return bytes(out), declared_count, declared_sha, declared_source_shas


def check_source_freshness(path, source_dir, declared_source_shas):
    """Hard-fails if source_dir's files don't match every recorded
    source_sha256 entry -- the WP9 stale-artifact protection. Requires at
    least one recorded entry (an old manifest with none is a separate,
    pre-existing-data problem, not silently accepted as 'fresh')."""
    if not declared_source_shas:
        fail(path, 0,
             "--source-dir given but the manifest has no 'source_sha256' "
             "entries to check against -- it predates WP9's stale-artifact "
             "protection and must be regenerated with build_dash_manifest.py")
    for name, expected in sorted(declared_source_shas.items()):
        src_path = source_dir / name
        if not src_path.is_file():
            fail(path, 0,
                 f"manifest records source_sha256 for {name!r}, but "
                 f"{src_path} does not exist")
        actual = hashlib.sha256(src_path.read_bytes()).hexdigest()
        if actual != expected:
            fail(path, 0,
                 f"source file {name!r} has changed since the manifest was "
                 f"generated (expected sha256 {expected}, got {actual}) -- "
                 "regenerate the manifest with build_dash_manifest.py after "
                 "reviewing a fresh native CASM run")


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Convert a reviewed hex manifest into a binary fixture.")
    ap.add_argument("input", help="path to the .ref.hex manifest")
    ap.add_argument("output", help="path to the binary file to write")
    ap.add_argument("--source-dir", type=Path,
                    help="directory to check the manifest's 'source_sha256' "
                         "entries against (WP9 stale-artifact protection); "
                         "if omitted, source freshness is not checked")
    args = ap.parse_args(argv)

    try:
        with open(args.input, "r", encoding="ascii") as f:
            lines = f.readlines()
    except OSError as e:
        fail(args.input, 0, f"cannot read: {e}")
    except UnicodeDecodeError:
        fail(args.input, 0, "manifest is not plain ASCII")

    data, declared_count, declared_sha, declared_source_shas = \
        parse_manifest(args.input, lines)

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

    if args.source_dir is not None:
        check_source_freshness(args.input, args.source_dir,
                                declared_source_shas)

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
