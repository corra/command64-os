#!/usr/bin/env bash
# tools/casm_progress_inc8_matrix.sh
# SPDX-License-Identifier: MIT
#
# CASM progress-indication Increment 8 (automated verification) helper.
#
# Prints, in order, the exact `vice_keyboard_petscii` `data` arrays for every
# shell command in the Increment 8 focused matrix, so a live-VICE session
# never has to hand-derive PETSCII/case bytes (the recurring mistake called
# out in .agents/workflows/vice-mcp-testing.md step 7).
#
# It just wraps tools/vice_type_command.py. Walkthrough:
#   brain/walkthroughs/2026-08-24-casm-progress-increment08-automated-verification.md
#
# Usage: tools/casm_progress_inc8_matrix.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TC="$HERE/vice_type_command.py"

emit() {
    local label="$1" cmd="$2"
    printf '%-52s ' "$label"
    "$TC" "$cmd" 2>/dev/null \
        | python3 -c "import sys,json;print(json.load(sys.stdin)['arguments']['data'])"
}

echo "# Increment 8 focused matrix - vice_keyboard_petscii data arrays"
echo "# (send each array verbatim; then read the shell/result line from screen RAM)"
echo

echo "## Session"
emit "flush (recovery after BAD COMMAND OR FILE NAME)" "flush"
echo

echo "## 4.1-4.10  assemble + compare"
for spec in \
    "casmpg63.s|casmpg63.prg|casmpg63.ref" \
    "casmpg64.s|casmpg64.prg|casmpg64.ref" \
    "casmpg65.s|casmpg65.prg|casmpg65.ref" \
    "casmpg128.s|casmpg128.prg|casmpg128.ref" \
    "casmpgblank.s|casmpgblank.prg|casmpgblank.ref" \
    "casmpgfill.s|casmpgfill.prg|casmpgfill.ref" \
    "casmpgincbin.s|casmpgincbin.prg|casmpgincbin.ref" \
    "casmpgr6.s|casmpgr6.prg|casmpgr6.ref" ; do
    IFS='|' read -r src prg ref <<<"$spec"
    emit "casm $src" "casm $src"
    emit "comp $prg $ref" "comp $prg $ref"
done
emit "casm casmpgrta.s casmpgrtb.s /o:casmpgrt.prg" "casm casmpgrta.s casmpgrtb.s /o:casmpgrt.prg"
emit "comp casmpgrt.prg casmpgrt.ref"               "comp casmpgrt.prg casmpgrt.ref"
emit "casm casmpginca"                              "casm casmpginca"
emit "comp casmpginca.prg casmpginc.ref"            "comp casmpginca.prg casmpginc.ref"
echo

echo "## Option-identity sub-matrix (against casmpg128.s)"
emit "casm casmpg128.s /o:pa.prg"        "casm casmpg128.s /o:pa.prg"
emit "casm casmpg128.s /o:pb.prg /m"     "casm casmpg128.s /o:pb.prg /m"
emit "casm casmpg128.s /o:pc.prg /l"     "casm casmpg128.s /o:pc.prg /l"
emit "casm casmpg128.s /o:pd.prg /m /l"  "casm casmpg128.s /o:pd.prg /m /l"
emit "casm casmpg128.s /o:ps.prg /s"     "casm casmpg128.s /o:ps.prg /s"
emit "comp pa.prg casmpg128.ref"         "comp pa.prg casmpg128.ref"
emit "comp pb.prg casmpg128.ref"         "comp pb.prg casmpg128.ref"
emit "comp pc.prg casmpg128.ref"         "comp pc.prg casmpg128.ref"
emit "comp pd.prg casmpg128.ref"         "comp pd.prg casmpg128.ref"
emit "comp ps.prg pa.prg"                "comp ps.prg pa.prg"
