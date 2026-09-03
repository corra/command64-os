#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
#
# build_comp_manifest.py - Transcribe a reviewed COMP PRG into the
# checked-in hex manifest that CMake ships. Single-file twin of
# scripts/build_comp_manifest.py.
#
# WHY THIS IS NOT A BUILD STEP
# ----------------------------
# COMP is assembled by the NATIVE CASM assembler running on the C64 -- it
# has no ca65 build (retired in the 2026-09-02 CASM-native migration).
# Nothing on the host can reproduce that run, so the shipped bytes live in a
# reviewed manifest (src/external/comp/comp.ref.hex) which
# scripts/hex_manifest_to_bin.py transcribes back to a PRG at build time.
#
# COMP emits no version banner, so -- unlike LABEL -- there is no generated
# version source; the assembled bytes depend only on comp.s. BUILD_COMP is
# recorded too (frozen at its final ca65-era value) so a stray edit to it is
# still a loud, deliberate event rather than silent drift.
#
# Regenerating the manifest is a deliberate, human act performed once a
# native run has been reviewed against the independent byte/R6 derivation
# record (src/external/comp/comp-derivation.md) -- never a build step.
#
# STALE-ARTIFACT PROTECTION
# -------------------------
# The assembled bytes depend on three checked-in inputs, all under
# src/external/comp/:
#   comp.s        the source (the sole determinant of the bytes)
#   BUILD_COMP    the retired ca65-era build counter, frozen; recorded so an
#                  accidental edit still hard-fails the build
# Both are recorded as source_sha256 entries so hex_manifest_to_bin.py's
# --source-dir check hard-fails the build if either changes without a
# manifest regeneration.

import argparse
import hashlib
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = REPO_ROOT / "src" / "external" / "comp" / "comp.ref.hex"
DEFAULT_SOURCE_DIR = REPO_ROOT / "src" / "external" / "comp"

COMP_SOURCE_NAMES = ("comp.s", "BUILD_COMP")


def fail(msg):
    sys.stderr.write(f"build_comp_manifest.py: error: {msg}\n")
    sys.exit(1)


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Transcribe a reviewed COMP PRG into its hex manifest.")
    ap.add_argument("prg", type=Path,
                    help="the reviewed PRG, extracted from the native-CASM "
                         "assembly test disk after a reviewed run")
    ap.add_argument("--provenance", required=True,
                    help="how these bytes were produced -- recorded verbatim "
                         "in the manifest header")
    ap.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST,
                    help="manifest to write (default: %(default)s)")
    ap.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE_DIR,
                    help="directory holding comp.s / BUILD_COMP this PRG "
                         "was assembled from (default: %(default)s)")
    args = ap.parse_args(argv)

    if not args.prg.is_file():
        fail(f"{args.prg}: not a file")

    data = args.prg.read_bytes()
    if len(data) < 2:
        fail(f"{args.prg}: too short to be a PRG (needs a 2-byte load address)")

    load_addr = data[0] | (data[1] << 8)
    digest = hashlib.sha256(data).hexdigest()

    source_shas = []
    for name in COMP_SOURCE_NAMES:
        p = args.source_dir / name
        if not p.is_file():
            fail(f"{p}: not a file (required to record its source_sha256 -- "
                 "pass --source-dir to point at the COMP sources this PRG "
                 "was actually assembled from)")
        source_shas.append((name, hashlib.sha256(p.read_bytes()).hexdigest()))

    lines = [
        "# COMP -- reviewed hex manifest",
        "#",
        "# These are the bytes that ship as COMP.PRG. They are transcribed",
        "# back to a binary at build time by scripts/hex_manifest_to_bin.py,",
        "# which contains no 6502 knowledge and no assembler of any kind.",
        "#",
        "# Correctness is proven by the independent byte + R6 relocation",
        "# derivation record at src/external/comp/comp-derivation.md",
        "# (peer-reviewed), NOT by this manifest -- which is the shipped",
        "# artifact and stale-source guard only.",
        "#",
        f"# provenance:  {args.provenance}",
        f"# load addr:   ${load_addr:04X}",
        "#",
        f"# bytes: {len(data)}",
        f"# sha256: {digest}",
    ]
    for name, sha in source_shas:
        lines.append(f"# source_sha256: {name}={sha}")
    lines.append("")

    for i in range(0, len(data), 16):
        lines.append(" ".join(f"{b:02X}" for b in data[i:i + 16]))

    args.manifest.write_text("\n".join(lines) + "\n", encoding="ascii")

    print(f"wrote {args.manifest}")
    print(f"  {len(data)} bytes, load ${load_addr:04X}, sha256={digest}")
    print(f"  provenance: {args.provenance}")
    for name, sha in source_shas:
        print(f"  source_sha256 {name}={sha}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
