#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
#
# build_dash_manifest.py - Transcribe a reviewed DASH PRG into the checked-in
# hex manifest that CMake ships.
#
# WHY THIS IS NOT A BUILD STEP
# ----------------------------
# DASH is assembled by the NATIVE CASM assembler running on the C64, not by any
# host tool. Nothing on the host can reproduce that run, so the shipped bytes
# live in a reviewed manifest (src/external/dash/dash.ref.hex) which
# scripts/hex_manifest_to_bin.py transcribes back to a PRG at build time.
#
# Regenerating the manifest is therefore a deliberate, human act performed once
# a native run has been reviewed -- never a build step. If it were wired into
# CMake, editing a source would silently change what ships without anyone
# having assembled or reviewed anything, which is exactly the stale-source
# hazard the manifest exists to prevent.
#
# PROVENANCE IS RECORDED, NOT ASSUMED
# -----------------------------------
# The caller must state where the bytes came from via --provenance. The ca65
# 'dash_ref' target is an INDEPENDENT CROSS-CHECK ONLY: it exists so a native
# run can be verified byte-for-byte (on the C64 with COMP, or here with
# --cross-check), and its output must never become the shipped bytes. Passing a
# path that looks like the ca65 build is refused unless --allow-host-bytes is
# given explicitly, so the misrepresentation has to be a typed, visible choice
# rather than an accident.

import argparse
import hashlib
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = REPO_ROOT / "src" / "external" / "dash" / "dash.ref.hex"
CA65_REFERENCE = REPO_ROOT / "build" / "dash_ref.prg"


def fail(msg):
    sys.stderr.write(f"build_dash_manifest.py: error: {msg}\n")
    sys.exit(1)


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Transcribe a reviewed DASH PRG into its hex manifest.")
    ap.add_argument("prg", type=Path,
                    help="the reviewed PRG, normally extracted from "
                         "command64_casm_utils.d64 after a native CASM run")
    ap.add_argument("--provenance", required=True,
                    help="how these bytes were produced -- recorded verbatim "
                         "in the manifest header (e.g. \"native CASM 0.1.48 "
                         "build 1191 on command64_casm_utils.d64, 2026-07-27\")")
    ap.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST,
                    help="manifest to write (default: %(default)s)")
    ap.add_argument("--cross-check", type=Path, metavar="REF",
                    help="also compare PRG byte-for-byte against REF (normally "
                         "build/dash_ref.prg, the independent ca65 build) and "
                         "record the result in the manifest header")
    ap.add_argument("--allow-host-bytes", action="store_true",
                    help="permit transcribing the ca65 build itself; this "
                         "ships host-assembled bytes as DASH and violates the "
                         "WP4 artifact contract")
    args = ap.parse_args(argv)

    if not args.prg.is_file():
        fail(f"{args.prg}: not a file")

    # Refuse the specific mistake this whole script exists to prevent.
    if args.prg.resolve() == CA65_REFERENCE.resolve() and not args.allow_host_bytes:
        fail(f"{args.prg} is the ca65 cross-check build, not native CASM "
             f"output.\n  The manifest must record bytes produced by CASM "
             f"running on the C64.\n  Use --cross-check to compare against it "
             f"instead, or --allow-host-bytes to override deliberately.")

    data = args.prg.read_bytes()
    if len(data) < 2:
        fail(f"{args.prg}: too short to be a PRG (needs a 2-byte load address)")

    load_addr = data[0] | (data[1] << 8)
    digest = hashlib.sha256(data).hexdigest()

    cross_check_note = None
    if args.cross_check:
        if not args.cross_check.is_file():
            fail(f"{args.cross_check}: not a file")
        ref = args.cross_check.read_bytes()
        if ref == data:
            cross_check_note = (f"MATCHES {args.cross_check.name} "
                                f"({len(ref)} bytes) byte-for-byte")
        else:
            # Report the first divergence -- a mismatch is a finding to
            # investigate, not necessarily a defect in either assembler, so
            # this is fatal here and left to a human.
            first = next((i for i, (a, b) in enumerate(zip(data, ref))
                          if a != b), min(len(data), len(ref)))
            fail(f"cross-check FAILED against {args.cross_check}: "
                 f"lengths {len(data)} vs {len(ref)}, first difference at "
                 f"offset {first} (0x{first:04X}). Manifest not written.")

    lines = [
        "# DASH relocatable skeleton -- reviewed hex manifest (WP4)",
        "#",
        "# These are the bytes that ship as DASH.PRG. They are transcribed",
        "# back to a binary at build time by scripts/hex_manifest_to_bin.py,",
        "# which contains no 6502 knowledge and no assembler of any kind.",
        "#",
        f"# provenance:  {args.provenance}",
    ]
    if cross_check_note:
        lines.append(f"# cross-check: {cross_check_note}")
    lines += [
        f"# load addr:   ${load_addr:04X}",
        "#",
        f"# bytes: {len(data)}",
        f"# sha256: {digest}",
        "",
    ]
    for i in range(0, len(data), 16):
        lines.append(" ".join(f"{b:02X}" for b in data[i:i + 16]))

    args.manifest.write_text("\n".join(lines) + "\n", encoding="ascii")

    print(f"wrote {args.manifest}")
    print(f"  {len(data)} bytes, load ${load_addr:04X}, sha256={digest}")
    print(f"  provenance: {args.provenance}")
    if cross_check_note:
        print(f"  cross-check: {cross_check_note}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
