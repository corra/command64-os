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
# 'dash_ref' target is an OPTIONAL DIFFERENTIAL CROSS-CHECK ONLY: it exists so a
# native run can be verified byte-for-byte (on the C64 with COMP, or here with
# --cross-check), and its output must never become the shipped bytes.
# Passing the ca65 build path directly as the manifest input is strictly refused.

import argparse
import hashlib
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_MANIFEST = REPO_ROOT / "src" / "external" / "dash" / "dash.ref.hex"
CA65_REFERENCE = REPO_ROOT / "build" / "dash_ref.prg"
DEFAULT_SOURCE_DIR = REPO_ROOT / "src" / "external" / "dash"

# The seven ordered DASH sources (see AGENTS.md "Source Order Is
# Authoritative") -- also the exact set WP9's stale-artifact protection
# records a source_sha256 entry for, so hex_manifest_to_bin.py's
# --source-dir check can catch any one of them changing without a manifest
# regeneration.
DASH_SOURCE_NAMES = [
    "dmain.s", "dscr.s", "dfmt.s", "dsys.s", "dapp.s", "dvmm.s", "ddata.s",
]


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
                         "in the manifest header (e.g. \"native CASM 0.5.2 "
                         "build 1404 on command64_casm_utils.d64, 2026-09-01\")")
    ap.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST,
                    help="manifest to write (default: %(default)s)")
    ap.add_argument("--source-dir", type=Path, default=DEFAULT_SOURCE_DIR,
                    help="directory holding the seven DASH sources to hash "
                         "into the manifest's source_sha256 entries "
                         "(default: %(default)s)")
    ap.add_argument("--cross-check", type=Path, metavar="REF",
                    help="also compare PRG byte-for-byte against REF (optional "
                         "differential build, e.g. build/dash_ref.prg) and "
                         "record the result in the manifest header")
    args = ap.parse_args(argv)

    if not args.prg.is_file():
        fail(f"{args.prg}: not a file")

    # Refuse transcribing the host ca65 build as shipping bytes.
    if args.prg.resolve() == CA65_REFERENCE.resolve():
        fail(f"{args.prg} is the ca65 differential build, not native CASM "
             f"output.\n  The manifest must record bytes produced by CASM "
             f"running on the C64 or an independent canonical derivation.\n  "
             f"Use --cross-check to record a differential comparison instead.")

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

    # WP9 stale-artifact protection: hash the exact seven sources this run
    # was assembled from, so hex_manifest_to_bin.py's --source-dir check can
    # catch a source edited after this manifest was reviewed, before it ships
    # silently. Missing a source file here is refused, not skipped -- a
    # manifest that can't prove which sources it covers provides no
    # protection at all.
    source_shas = {}
    for name in DASH_SOURCE_NAMES:
        src_path = args.source_dir / name
        if not src_path.is_file():
            fail(f"{src_path}: not a file (required to record its "
                 "source_sha256 -- pass --source-dir to point at the seven "
                 "DASH sources this PRG was actually assembled from)")
        source_shas[name] = hashlib.sha256(src_path.read_bytes()).hexdigest()

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
    ]
    for name in DASH_SOURCE_NAMES:
        lines.append(f"# source_sha256: {name}={source_shas[name]}")
    lines.append("")
    for i in range(0, len(data), 16):
        lines.append(" ".join(f"{b:02X}" for b in data[i:i + 16]))

    args.manifest.write_text("\n".join(lines) + "\n", encoding="ascii")

    print(f"wrote {args.manifest}")
    print(f"  {len(data)} bytes, load ${load_addr:04X}, sha256={digest}")
    print(f"  provenance: {args.provenance}")
    if cross_check_note:
        print(f"  cross-check: {cross_check_note}")
    print(f"  source_sha256 recorded for {len(source_shas)} files from "
          f"{args.source_dir}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
