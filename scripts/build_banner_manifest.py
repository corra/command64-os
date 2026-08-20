#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
#
# build_banner_manifest.py - Transcribe a reviewed BANNER PRG into the
# checked-in hex manifest that CMake ships.
#
# WHY THIS IS NOT A BUILD STEP
# ----------------------------
# BANNER is assembled by the NATIVE CASM assembler running on the C64 -- it
# has no ca65 build to cross-check against, native CASM is the only
# assembler in the picture. Nothing on the host can reproduce that run, so
# the shipped bytes live in a reviewed manifest
# (src/external/banner/banner.ref.hex) which scripts/hex_manifest_to_bin.py
# transcribes back to a PRG at build time.
#
# Regenerating the manifest is therefore a deliberate, human act performed
# once a native run has been reviewed -- never a build step. If it were
# wired into CMake, editing banner.s would silently change what ships
# without anyone having assembled or reviewed anything, which is exactly
# the stale-source hazard the manifest exists to prevent.
#
# PROVENANCE IS RECORDED, NOT ASSUMED
# -----------------------------------
# The caller must state where the bytes came from via --provenance.

import argparse
import hashlib
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = REPO_ROOT / "src" / "external" / "banner" / "banner.ref.hex"
DEFAULT_SOURCE_DIR = REPO_ROOT / "src" / "external" / "banner"

# BANNER is a single-file app -- just this one source to hash into a
# source_sha256 entry so hex_manifest_to_bin.py's --source-dir check can
# catch it changing without a manifest regeneration.
BANNER_SOURCE_NAME = "banner.s"


def fail(msg):
    sys.stderr.write(f"build_banner_manifest.py: error: {msg}\n")
    sys.exit(1)


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Transcribe a reviewed BANNER PRG into its hex manifest.")
    ap.add_argument("prg", type=Path,
                    help="the reviewed PRG, normally extracted from "
                         "command64_casm_utils.d64 after a native CASM run")
    ap.add_argument("--provenance", required=True,
                    help="how these bytes were produced -- recorded verbatim "
                         "in the manifest header (e.g. \"native CASM 0.2.8 "
                         "build 1322 on command64_casm_utils.d64, "
                         "2026-08-20\")")
    ap.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST,
                    help="manifest to write (default: %(default)s)")
    ap.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE_DIR,
                    help="directory holding banner.s, the source this PRG "
                         "was actually assembled from (default: %(default)s)")
    args = ap.parse_args(argv)

    if not args.prg.is_file():
        fail(f"{args.prg}: not a file")

    data = args.prg.read_bytes()
    if len(data) < 2:
        fail(f"{args.prg}: too short to be a PRG (needs a 2-byte load address)")

    load_addr = data[0] | (data[1] << 8)
    digest = hashlib.sha256(data).hexdigest()

    # Stale-artifact protection: hash the exact source this run was
    # assembled from, so hex_manifest_to_bin.py's --source-dir check can
    # catch a source edited after this manifest was reviewed, before it
    # ships silently. Missing the source file here is refused, not
    # skipped -- a manifest that can't prove which source it covers
    # provides no protection at all.
    src_path = args.source_dir / BANNER_SOURCE_NAME
    if not src_path.is_file():
        fail(f"{src_path}: not a file (required to record its source_sha256 "
             "-- pass --source-dir to point at the BANNER source this PRG "
             "was actually assembled from)")
    source_sha = hashlib.sha256(src_path.read_bytes()).hexdigest()

    lines = [
        "# BANNER -- reviewed hex manifest",
        "#",
        "# These are the bytes that ship as BANNER.PRG. They are",
        "# transcribed back to a binary at build time by",
        "# scripts/hex_manifest_to_bin.py, which contains no 6502 knowledge",
        "# and no assembler of any kind.",
        "#",
        f"# provenance:  {args.provenance}",
        f"# load addr:   ${load_addr:04X}",
        "#",
        f"# bytes: {len(data)}",
        f"# sha256: {digest}",
        f"# source_sha256: {BANNER_SOURCE_NAME}={source_sha}",
        "",
    ]
    for i in range(0, len(data), 16):
        lines.append(" ".join(f"{b:02X}" for b in data[i:i + 16]))

    args.manifest.write_text("\n".join(lines) + "\n", encoding="ascii")

    print(f"wrote {args.manifest}")
    print(f"  {len(data)} bytes, load ${load_addr:04X}, sha256={digest}")
    print(f"  provenance: {args.provenance}")
    print(f"  source_sha256 recorded for {BANNER_SOURCE_NAME} from "
          f"{args.source_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
