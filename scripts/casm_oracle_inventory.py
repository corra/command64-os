#!/usr/bin/env python3
"""casm_oracle_inventory.py -- read-only inventory + reconciliation for the
CASM canonical byte-oracle audit (Byte-Oracle Transition WP2).

WHAT THIS DOES
  * Enumerates every tests/fixtures/casm/*.ref.hex and every CASM-native
    application manifest (src/external/*/*.ref.hex).
  * Parses each manifest header for its DECLARED metadata (byte count,
    artifact sha256, source sha256s) and its free-text provenance claim.
  * Recomputes, from the manifest's own hex body, the ACTUAL assembled byte
    count and sha256, and cross-checks them against the declared values.
  * Hashes the exact generated .seq source bytes each fixture consumes
    (when a build tree is available) -- NOT a hash of the generator script,
    which unrelated edits would stale.
  * Traces packaging: CASM_REF_NAMES membership and every disk-image
    POST_BUILD step that writes the .ref.
  * Reconciles the counts/membership/packaging and exits non-zero on any
    divergence.
  * Emits a markdown table for paste/diff into
    brain/reviews/2026-09-01-casm-byte-oracle-audit.md.

WHAT THIS MUST NEVER DO  (governing plan / .agents/workflows/canonical-byte-oracles.md)
  * It never reads src/external/casm/opcodes.s or any CASM production table.
  * It never disassembles a .ref or computes what a byte "should" be.
  * It reports structure, declared claims, and hashes. HUMANS classify
    provenance. This script assigns NO provenance state.
"""
from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
FIXTURE_DIR = REPO / "tests" / "fixtures" / "casm"
CMAKELISTS = REPO / "CMakeLists.txt"
NATIVE_MANIFESTS = [
    REPO / "src" / "external" / "dash" / "dash.ref.hex",
    REPO / "src" / "external" / "banner" / "banner.ref.hex",
]


def sha256_bytes(b: bytes) -> str:
    return hashlib.sha256(b).hexdigest()


def parse_ref_hex(path: Path) -> dict:
    """Split a .ref.hex into its comment header and hex body, pull declared
    metadata, and recompute the actual bytes from the body."""
    text = path.read_text()
    header_lines: list[str] = []
    hex_tokens: list[str] = []
    for raw in text.splitlines():
        line = raw.strip()
        if not line:
            continue
        if line.startswith("#"):
            header_lines.append(line[1:].strip())
        else:
            hex_tokens.extend(line.split())

    declared_bytes = None
    declared_sha = None
    source_shas: dict[str, str] = {}
    for h in header_lines:
        m = re.match(r"bytes:\s*(\d+)", h)
        if m:
            declared_bytes = int(m.group(1))
        m = re.match(r"sha256:\s*([0-9a-fA-F]{64})", h)
        if m:
            declared_sha = m.group(1).lower()
        m = re.match(r"source_sha256:\s*([\w.\-]+)=([0-9a-fA-F]{64})", h)
        if m:
            source_shas[m.group(1)] = m.group(2).lower()

    try:
        body = bytes(int(t, 16) for t in hex_tokens)
        body_ok = True
    except ValueError:
        body = b""
        body_ok = False

    # First line of the header that isn't a bytes:/sha:/source_sha: field is
    # the human provenance claim.
    provenance_claim = ""
    for h in header_lines:
        if re.match(r"(bytes|sha256|source_sha256|cross-check|load addr|provenance):", h):
            if h.startswith("provenance:"):
                provenance_claim = h
                break
            continue
        if h:
            provenance_claim = h
            break

    return {
        "path": path,
        "name": path.name[: -len(".ref.hex")],
        "header": header_lines,
        "provenance_claim": provenance_claim,
        "declared_bytes": declared_bytes,
        "declared_sha256": declared_sha,
        "source_sha256": source_shas,
        "actual_bytes": len(body) if body_ok else None,
        "actual_sha256": sha256_bytes(body) if body_ok else None,
        "manifest_sha256": sha256_bytes(path.read_bytes()),
        "body_parsed": body_ok,
        "mentions_not_from_casm": bool(
            re.search(r"NOT (produced|assembled) by CASM|hand-derived|hand-assembled|independently",
                      " ".join(header_lines), re.I)
        ),
    }


def read_casm_ref_names() -> list[str]:
    text = CMAKELISTS.read_text()
    m = re.search(r"set\(CASM_REF_NAMES\s+(.*?)\)", text, re.S)
    if not m:
        raise SystemExit("FATAL: could not find set(CASM_REF_NAMES ...) in CMakeLists.txt")
    return m.group(1).split()


def find_packaging_steps(name: str, cmake_text: str) -> list[str]:
    """Return the COMMENT strings of POST_BUILD blocks that write <name>.ref
    or <name>.seq, plus the generic CASM_REF_NAMES -> test.d64 loop."""
    steps: list[str] = []
    # generic loops
    if re.search(rf'\$\{{REF_NAME\}}\.ref"', cmake_text) and name in read_casm_ref_names():
        steps.append("generic CASM_REF_NAMES packaging loop")
    # explicit per-name references inside custom-command blocks
    for m in re.finditer(rf'(-w\s+"[^"]*{re.escape(name)}\.(ref|seq)")', cmake_text):
        # walk back to the nearest COMMENT "..."
        pre = cmake_text[: m.start()]
        cm = None
        for c in re.finditer(r'COMMENT\s+"([^"]+)"', pre):
            cm = c.group(1)
        steps.append(f'{m.group(2)}: {cm or "(no COMMENT found)"}')
    return sorted(set(steps))


def seq_source_bytes(name: str, build_dir: Path | None) -> dict:
    if build_dir is None:
        return {"status": "no build tree given"}
    seq = build_dir / "casm_test_fixtures" / f"{name}.seq"
    if seq.is_file():
        b = seq.read_bytes()
        return {"status": "single", "seq": str(seq.relative_to(build_dir)),
                "bytes": len(b), "sha256": sha256_bytes(b)}
    # multi-root / include fixtures: list any <name>*.seq
    sibs = sorted((build_dir / "casm_test_fixtures").glob(f"{name}*.seq"))
    if sibs:
        return {"status": "multi/prefix", "seqs": [s.name for s in sibs]}
    return {"status": "no generated .seq found (multi-root? check manually)"}


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--build-dir", type=Path, default=REPO / "build",
                    help="CMake build tree, for generated-.seq hashing (default: ./build)")
    ap.add_argument("--markdown", action="store_true", help="emit the register table")
    ap.add_argument("--check", action="store_true",
                    help="run reconciliation assertions; exit non-zero on any failure")
    args = ap.parse_args()

    build_dir = args.build_dir if args.build_dir and args.build_dir.is_dir() else None

    ref_names = read_casm_ref_names()
    disk_files = sorted(p.name[: -len(".ref.hex")] for p in FIXTURE_DIR.glob("*.ref.hex"))
    tracked = sorted(
        Path(p).name[: -len(".ref.hex")]
        for p in __import__("subprocess").run(
            ["git", "-C", str(REPO), "ls-files", "tests/fixtures/casm/*.ref.hex"],
            capture_output=True, text=True, check=True).stdout.split()
    )

    cmake_text = CMAKELISTS.read_text()
    entries = [parse_ref_hex(FIXTURE_DIR / f"{n}.ref.hex") for n in disk_files]
    manifests = [parse_ref_hex(p) for p in NATIVE_MANIFESTS if p.is_file()]

    problems: list[str] = []

    # --- reconciliation ---
    if sorted(ref_names) != disk_files:
        problems.append(f"CASM_REF_NAMES ({len(ref_names)}) != on-disk .ref.hex ({len(disk_files)}): "
                        f"only-in-names={sorted(set(ref_names) - set(disk_files))} "
                        f"only-on-disk={sorted(set(disk_files) - set(ref_names))}")
    if disk_files != tracked:
        problems.append(f"on-disk != git-tracked: untracked={sorted(set(disk_files) - set(tracked))}")

    for e in entries + manifests:
        if not e["body_parsed"]:
            problems.append(f"{e['name']}: hex body did not parse")
            continue
        if e["declared_bytes"] is not None and e["declared_bytes"] != e["actual_bytes"]:
            problems.append(f"{e['name']}: declared bytes {e['declared_bytes']} != actual {e['actual_bytes']}")
        if e["declared_sha256"] and e["declared_sha256"] != e["actual_sha256"]:
            problems.append(f"{e['name']}: declared sha256 {e['declared_sha256'][:12]}.. "
                            f"!= actual {e['actual_sha256'][:12]}..")

    # --- WP3: declared source_sha256 entries must match the actual source ---
    # generated .seq fixtures live in <build>/casm_test_fixtures/; checked-in
    # .dat payloads (.INCBIN assets) live in tests/fixtures/casm/.
    for e in entries:
        for src_name, want in e["source_sha256"].items():
            candidates = []
            if build_dir:
                candidates.append(build_dir / "casm_test_fixtures" / src_name)
            candidates.append(FIXTURE_DIR / src_name)
            found = next((c for c in candidates if c.is_file()), None)
            if found is None:
                if build_dir:  # only an error when we actually had somewhere to look
                    problems.append(f"{e['name']}: source_sha256 names {src_name} "
                                    f"but no such generated .seq or fixture asset")
                continue
            got = sha256_bytes(found.read_bytes())
            if got != want:
                problems.append(f"{e['name']}: source_sha256 for {src_name} "
                                f"{want[:12]}.. != actual {got[:12]}.. (stale fixture source)")

    for e in entries:
        if not find_packaging_steps(e["name"], cmake_text):
            problems.append(f"{e['name']}: no packaging step found in CMakeLists.txt")

    # --- output ---
    if args.markdown:
        print("| ref | class-hint | decl bytes | bytes ok | sha decl | sha ok | src .seq sha | not-from-CASM claim | packaging |")
        print("| --- | --- | --- | --- | --- | --- | --- | --- | --- |")
        for e in entries + manifests:
            seq = seq_source_bytes(e["name"], build_dir)
            seqsha = seq.get("sha256", seq.get("status", "?"))
            print(f"| {e['name']} | {'manifest' if e in manifests else '?'} "
                  f"| {e['declared_bytes']} "
                  f"| {'y' if e['declared_bytes'] == e['actual_bytes'] else 'N'} "
                  f"| {'y' if e['declared_sha256'] else '-'} "
                  f"| {'y' if (e['declared_sha256'] and e['declared_sha256'] == e['actual_sha256']) else ('-' if not e['declared_sha256'] else 'N')} "
                  f"| {seqsha[:16] if len(seqsha) > 20 else seqsha} "
                  f"| {'y' if e['mentions_not_from_casm'] else 'N'} "
                  f"| {'; '.join(find_packaging_steps(e['name'], cmake_text))[:60]} |")

    print(f"\n# summary: {len(disk_files)} .ref.hex on disk, "
          f"{len(ref_names)} in CASM_REF_NAMES, {len(tracked)} tracked, "
          f"{len(manifests)} native manifests", file=sys.stderr)
    print(f"# with declared sha256: {sum(1 for e in entries if e['declared_sha256'])}/"
          f"{len(entries)}; "
          f"header claims independent derivation: "
          f"{sum(1 for e in entries if e['mentions_not_from_casm'])}/{len(entries)}", file=sys.stderr)

    if problems:
        print(f"\n# RECONCILIATION FAILURES ({len(problems)}):", file=sys.stderr)
        for p in problems:
            print(f"#   - {p}", file=sys.stderr)
        if args.check:
            return 1
    else:
        print("# reconciliation: OK", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
