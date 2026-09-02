#!/usr/bin/env python3
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
#
# verify_casm_diag_table.py - Prove every CASM fatal-diagnostic identifier
# ($01..$56) still renders exactly the text it rendered before, by decoding
# the linked casm.prg host-side rather than triggering all 86 diagnostics
# live (most need fault injection).
#
# WHY THIS EXISTS
# ---------------
# diagnostics.s maps a diagnostic identifier to its message string through
# several parallel tables plus a cmp/beq chain (see diagPrintFatal). A
# wrong entry there prints a *misleading* diagnostic - the worst failure
# mode for the module, and one no build-time .assert catches. The
# memory-optimization WP (task 42) collapses those tables into one dense
# table (Finding C); this script is the guard that the collapse preserved
# every id -> text mapping. It must:
#   * pass against the current (unmodified) dispatch, and
#   * be shown to catch a deliberately corrupted mapping (--self-test, and
#     a real message edit) before it is trusted to validate Finding C.
#
# PETSCII NOTE
# ------------
# The strings are assembled with `ca65 -t c64`, whose charmap sets bit 7 /
# swaps letter case. A naive ASCII compare reports false mismatches on
# every letter. Masking each byte with 0x7F recovers the original ASCII
# text (uppercase letters <-> $C1..$DA, digits/punctuation/space unchanged,
# PETSCII CR $0D unchanged). This was the exact bug the audit's first
# verifier pass hit.
#
# The EXPECTED table below is a frozen transcription of the diagnostic text
# as it stood at the WP's Increment 1 baseline (commit before any Finding
# landed), laid out by identifier. It is the contract: this WP must not
# change a single character of user-visible diagnostic text.

import argparse
import os
import re
import subprocess
import sys

# --- Frozen contract: diagnostic identifier -> message body (no "CASM: "
# prefix, no trailing CR; the renderer adds both). Transcribed from the
# task-42 Increment 1 baseline and cross-checked against docs/casm-utility.md
# where that file quotes a diagnostic. DO NOT edit to match a code change -
# a divergence here is the code changing user-visible text, which this WP
# forbids.
EXPECTED = {
    0x01: "INITIALIZATION FAILED",
    0x02: "RESOURCE REGISTRY FULL",
    0x03: "RESOURCE CLEANUP FAILED",
    0x04: "SOURCE FILE REQUIRED",
    0x05: "TOO MANY SOURCE FILES",
    0x06: "MALFORMED /O OPTION",
    0x07: "DUPLICATE OPTION",
    0x08: "UNKNOWN OPTION",
    0x09: "FILENAME TOO LONG",
    0x0A: "FEATURE NOT IMPLEMENTED",
    0x0B: "CANNOT OPEN INPUT",
    0x0C: "INPUT READ FAILED",
    0x0D: "INPUT CLOSE FAILED",
    0x0E: "CANNOT CREATE OUTPUT",
    0x0F: "OUTPUT WRITE FAILED",
    0x10: "OUTPUT CLOSE FAILED",
    0x11: "OUTPUT DELETE FAILED",
    0x12: "SHORT OUTPUT WRITE",
    0x13: "INVALID STREAM STATE",
    0x14: "SOURCE REWIND FAILED",
    0x15: "SOURCE OFFSET OVERFLOW",
    0x16: "SOURCE LOCATION OVERFLOW",
    0x17: "SOURCE LINE TOO LONG",
    0x18: "TOKEN TOO LONG",
    0x19: "INVALID SOURCE BYTE",
    0x1A: "MALFORMED NUMBER",
    0x1B: "INVALID LEXER STATE",
    0x1C: "SYNTAX ERROR",
    0x1D: "EXPECTED NEWLINE",
    0x1E: "OPERAND OUT OF RANGE",
    0x1F: "INVALID ADDRESSING MODE",
    0x20: "DUPLICATE ORG",
    0x21: "ORG REQUIRED",
    0x22: "ADDRESS OVERFLOW",
    0x23: "BRANCH OUT OF RANGE",
    0x24: "MALFORMED EXPRESSION",
    0x25: "EXPRESSION UNSUPPORTED",
    0x26: "EXPRESSION OVERFLOW",
    0x27: "RESOLVER FAILED",
    0x28: "VMM UNAVAILABLE",
    0x29: "VMM ALLOCATION FAILED",
    0x2A: "VMM FREE FAILED",
    0x2B: "VMM TRANSFER FAILED",
    0x2C: "DUPLICATE SYMBOL",
    0x2D: "UNDEFINED SYMBOL",
    0x2E: "SYMBOL TABLE FULL",
    0x2F: "PASS 1/2 MISMATCH",
    0x30: "RELOC TABLE FULL",
    0x31: "INCLUDE FILENAME EXPECTED",
    0x32: "INVALID INCLUDE FILENAME",
    0x33: "INCLUDE FILENAME TOO LONG",
    0x34: "INCLUDE CATALOG FULL",
    0x35: "INCLUDE DEPTH EXCEEDED",
    0x36: "INCLUDE CYCLE DETECTED",
    0x37: "INCLUDE EVENT LOG FULL",
    0x38: "INCLUDE REPLAY MISMATCH",
    0x39: "LISTING NAME COLLISION",
    0x3A: "LISTING RECORDS FULL",
    0x3B: "LISTING BYTES FULL",
    0x3C: "LISTING REPLAY MISMATCH",
    0x3D: "LISTING CREATE FAILED",
    0x3E: "LISTING WRITE FAILED",
    0x3F: "LISTING CLOSE FAILED",
    0x40: "LISTING DELETE FAILED",
    0x41: "LISTING SHORT WRITE",
    0x42: "SYMBOL MAP INVALID",
    0x43: "CIRCULAR CONSTANT DEFINITION",
    0x44: "EXPRESSION DIVISION BY ZERO",
    0x45: "EXPRESSION RELOCATION UNSUPPORTED",
    0x46: "EXPRESSION TOO DEEPLY NESTED",
    0x47: "CHARACTER LITERAL UNTERMINATED",
    0x48: "CHARACTER LITERAL INVALID BYTE",
    0x49: "STRING UNTERMINATED",
    0x4A: "STRING INVALID BYTE",
    0x4B: "OPERAND NOT RESOLVED",
    0x4C: ".FILL REQUIRES A VALUE",
    0x4D: "VALUE OUT OF RANGE",
    0x4E: "ALIGN BOUNDARY ZERO",
    0x4F: "INCBIN FILENAME EXPECTED",
    0x50: "INVALID INCBIN FILENAME",
    0x51: "INCBIN FILENAME TOO LONG",
    0x52: "ASSERT OPERAND NOT RESOLVED",
    0x53: "ASSERT MESSAGE TOO LONG",
    0x54: "ASSERTION FAILED",
    0x55: "STATEMENT COUNT OVERFLOW",
    0x56: "PASS 1/PASS 2 STATEMENT MISMATCH",
    0x57: "LOCAL LABEL BEFORE ANY GLOBAL LABEL",
    0x58: "DUPLICATE LOCAL LABEL IN SCOPE",
    0x59: "UNDEFINED LOCAL LABEL",
    0x5A: "LOCAL LABEL NOT ALLOWED IN CONSTANT",
    0x5B: ".ELSE/.ELSEIF/.ENDIF WITHOUT .IF",
    0x5C: "UNTERMINATED .IF",
    0x5D: ".ELSEIF/.ELSE AFTER .ELSE",
    0x5E: "CONDITIONAL NESTING TOO DEEP",
    0x5F: ".IF CONDITION NOT RESOLVED",
    0x60: ".IFDEF/.IFNDEF EXPECTS A NAME",
    0x61: "TOO MANY CONDITIONALS",
}

# Two identifiers that are printed through the same "CASM: " + body + CR
# helper but are not fatal-table entries: the success line and the
# out-of-range / $FF fallback.
EXPECTED_EXTRA = {
    "msgPhase2Ready": "INPUT VALIDATED",
    "msgUnknown": "INTERNAL ERROR",
}

LINK_BASE = 0x3800
CA65_ARGS = ["-t", "c64"]


def repo_root():
    return os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def const_values(common_inc):
    """Parse CASM_DIAG_* values (literal or single +/- from another CASM_DIAG_*)."""
    vals = {}
    for m in re.finditer(
        r"^(CASM_DIAG_\w+)\s*=\s*(\$[0-9A-Fa-f]+|\d+|CASM_DIAG_\w+(?:\s*[+-]\s*\d+)?)",
        open(common_inc).read(),
        re.M,
    ):
        name, raw = m.group(1), m.group(2).strip()
        if raw.startswith("$"):
            vals[name] = int(raw[1:], 16)
        elif raw.isdigit():
            vals[name] = int(raw)
        else:
            mm = re.match(r"(CASM_DIAG_\w+)\s*([+-])\s*(\d+)", raw)
            if mm and mm.group(1) in vals:
                d = int(mm.group(3))
                vals[name] = vals[mm.group(1)] + (d if mm.group(2) == "+" else -d)
            elif raw in vals:
                vals[name] = vals[raw]
    return vals


def link_with_labels(build_dir, workdir):
    """Re-assemble diagnostics.s with -g and link at LINK_BASE, returning
    (prg_bytes_without_load_addr, {symbol: addr})."""
    root = repo_root()
    out_casm = os.path.join(build_dir, "out_casm")
    objs = sorted(
        os.path.join(out_casm, f) for f in os.listdir(out_casm) if f.endswith(".o")
    )
    if not any(o.endswith("diagnostics.o") for o in objs):
        sys.exit(f"no diagnostics.o under {out_casm} - build the casm target first")
    diag_o = os.path.join(workdir, "diagnostics.o")
    subprocess.run(
        ["ca65", "-g", os.path.join(root, "src/external/casm/diagnostics.s"),
         "-I", os.path.join(root, "src/external/casm"),
         "-I", os.path.join(root, "include/ca65"),
         "-I", build_dir, *CA65_ARGS, "-o", diag_o],
        check=True,
    )
    objs = [diag_o if o.endswith("diagnostics.o") else o for o in objs]
    cfg = os.path.join(build_dir, "build_casm_cfg", f"casm_{LINK_BASE:04X}.cfg".lower())
    prg = os.path.join(workdir, "casm.prg")
    lbl = os.path.join(workdir, "casm.lbl")
    subprocess.run(["ld65", "-C", cfg, "-Ln", lbl, "-o", prg, *objs], check=True)
    syms = {}
    for line in open(lbl):
        p = line.split()
        if len(p) >= 3 and p[0] == "al":
            syms[p[2].lstrip(".")] = int(p[1], 16)
    data = open(prg, "rb").read()
    load = data[0] | (data[1] << 8)
    if load != LINK_BASE:
        sys.exit(f"unexpected load address ${load:04X}")
    return data[2:], syms


def read_cstr(mem, addr):
    """Null-terminated string at addr (LINK_BASE-relative), PETSCII-demasked."""
    off = addr - LINK_BASE
    end = mem.index(0, off)
    return bytes(b & 0x7F for b in mem[off:end]).decode("latin-1")


def decode_id_to_body(mem, syms, consts):
    """id -> message body text, decoded from diagPrintFatal's dispatch.

    Since Finding C (task 42) that dispatch is one dense table, diagMsgLo /
    diagMsgHi, indexed by (id - CASM_DIAG_INIT_FAILED) for every id in
    $01..CASM_DIAG_LAST. (Before Finding C this walked six separate range
    tables plus a nine-entry cmp/beq chain.)

    CASM_DIAG_LAST (common.inc) is the single id-space bound every site
    follows -- this script, diagPrintFatal's runtime range check, and the
    build-breaking table-length asserts -- so keying off it here means a
    new diagnostic can never slip past this coverage check."""
    first_id = consts["CASM_DIAG_INIT_FAILED"]
    last_id = consts["CASM_DIAG_LAST"]
    lo, hi = syms["diagMsgLo"], syms["diagMsgHi"]
    bodies = {}
    for i in range(last_id - first_id + 1):
        ptr = mem[lo - LINK_BASE + i] | (mem[hi - LINK_BASE + i] << 8)
        bodies[first_id + i] = read_cstr(mem, ptr)
    return bodies


def main():
    ap = argparse.ArgumentParser(
        description="Verify every CASM fatal-diagnostic id renders its frozen text")
    ap.add_argument("--build-dir", default=os.path.join(repo_root(), "build"))
    ap.add_argument("--self-test", action="store_true",
                    help="corrupt one decoded entry and confirm the check fails")
    args = ap.parse_args()

    workdir = os.path.join(args.build_dir, "verify_casm_diag_table")
    os.makedirs(workdir, exist_ok=True)

    root = repo_root()
    consts = const_values(os.path.join(root, "src/external/casm/common.inc"))
    mem, syms = link_with_labels(args.build_dir, workdir)

    prefix = read_cstr(mem, syms["msgCasmPrefix"])
    cr = read_cstr(mem, syms["msgCR"])
    if prefix != "CASM: ":
        sys.exit(f"msgCasmPrefix decoded as {prefix!r}, expected 'CASM: '")
    if cr != "\r":
        sys.exit(f"msgCR decoded as {cr!r}, expected '\\r'")

    bodies = decode_id_to_body(mem, syms, consts)
    for label, want in EXPECTED_EXTRA.items():
        bodies[f"extra:{label}"] = read_cstr(mem, syms[label])

    if args.self_test:
        victim = 0x2A
        bodies[victim] = bodies[victim] + "X"
        print(f"[self-test] corrupted id 0x{victim:02X}; a PASS below is a bug")

    ok = True
    got_ids = sorted(k for k in bodies if isinstance(k, int))
    want_ids = sorted(EXPECTED)
    if got_ids != want_ids:
        ok = False
        print(f"FAIL id coverage: decoded {[hex(i) for i in got_ids]}")
        print(f"          expected {[hex(i) for i in want_ids]}")

    for diag_id in want_ids:
        want = "CASM: " + EXPECTED[diag_id] + "\r"
        got = "CASM: " + bodies.get(diag_id, "<none>") + "\r"
        if got != want:
            ok = False
            print(f"FAIL 0x{diag_id:02X}: {got!r} != {want!r}")

    for label, want_body in EXPECTED_EXTRA.items():
        got = bodies[f"extra:{label}"]
        if got != want_body:
            ok = False
            print(f"FAIL {label}: {got!r} != {want_body!r}")

    if args.self_test:
        if ok:
            print("SELF-TEST FAILED: corrupted entry was not detected")
            return 1
        print("self-test OK: corruption detected as expected")
        return 0

    if ok:
        print(f"OK: all {len(want_ids)} diagnostic identifiers + "
              f"{len(EXPECTED_EXTRA)} extras render exactly the frozen text")
        return 0
    return 1


if __name__ == "__main__":
    sys.exit(main())
