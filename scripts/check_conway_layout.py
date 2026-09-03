#!/usr/bin/env python3
# scripts/check_conway_layout.py
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Command64 project contributors
#
# Host-side replacement for the ~23 compile-time `.assert` layout guards that
# the retired ca65 CONWAY source carried (in common.inc, conway_main.s, and
# conway_grid.s). Native CASM `.ASSERT` is truthiness-only with a bare
# expression -- it has no `<=` / `<>` and cannot compare -- so these
# screen-layout invariants are re-checked here and wired in as a build gate
# (PRE_BUILD on command64_conway_test_d64 and in the full-build verification).
#
# The menu/status string lengths come straight from gen_conway_menu.py's
# STRINGS table (the single source of truth); the version length from
# CONWAY_VERSION + BUILD_CONWAY (as gen_conway_version.py computes it).
#
# Exit non-zero and print every failing invariant on any violation.

import re
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from gen_conway_menu import STRINGS  # noqa: E402

# --- constants mirrored from common.inc (the migration inlines these into
# conway.s as bare literals; kept here to check the arithmetic) --------------
GRID_W = 40
GRID_H = 24
RULE_COUNT = 9
STATUS_ROW_OFFSET = 960
MENU_PROMPT_OFFSET = 23 * GRID_W               # 920
MENU_BIRTH_FIELD_OFFSET = 15 * GRID_W + 12     # 612
MENU_SURV_FIELD_OFFSET = 16 * GRID_W + 12      # 652
GEN_DIGITS_OFFSET = STATUS_ROW_OFFSET + 35     # 995
PAUSE_TEXT_OFFSET = STATUS_ROW_OFFSET + 3      # 963
PAUSE_TEXT_LEN = 5

TEXT = {label: text for label, text, _ in STRINGS}


def strlen(label: str) -> int:
    return len(TEXT[label])


def menu_version_len() -> int:
    ver = (HERE.parent / "src/external/conway/CONWAY_VERSION").read_text().strip()
    build = (HERE.parent / "src/external/conway/BUILD_CONWAY").read_text().splitlines()[0].strip()
    return len(f"{ver}.{build}")


def conway_s_equate(name: str) -> int | None:
    src = (HERE.parent / "src/external/conway/conway.s").read_text()
    m = re.search(rf"^{name}\s*=\s*(\d+)\b", src, re.MULTILINE)
    return int(m.group(1)) if m else None


def main() -> int:
    mvl = menu_version_len()
    mv_col = GRID_W - mvl
    fails: list[str] = []

    # conway.s must define the text-length constants inline (an .INCLUDE'd
    # named constant is relocatable under CASM 0.6.2). Verify they match.
    for name, want in (
        ("MENU_NONE_LEN", len(TEXT["menuNoneText"])),
        ("STATUS_TEXT_LEN", len(TEXT["statusText"])),
        ("MENU_VERSION_LEN", mvl),
    ):
        got = conway_s_equate(name)
        if got is None:
            fails.append(f"conway.s is missing inline `{name} = {want}`")
        elif got != want:
            fails.append(f"conway.s `{name} = {got}` but computed length is {want}")

    def chk(cond: bool, msg: str) -> None:
        if not cond:
            fails.append(msg)

    # --- conway_main.s menu descriptors: column offset + text must fit row ---
    for label, col in (
        ("menuTitle", 10), ("menuRule", 10), ("menuSelect", 2),
        ("menuPreset1", 4), ("menuPreset2", 4), ("menuPreset3", 4),
        ("menuPreset4", 4), ("menuPreset5", 4), ("menuPreset6", 4),
        ("menuPreset7", 4), ("menuPreset8", 4), ("menuPreset9", 4),
        ("menuCurrent", 2), ("menuBirthLabel", 2), ("menuSurvLabel", 2),
        ("menuControls1", 2), ("menuControls2", 2), ("menuControls3", 2),
    ):
        chk(col + strlen(label) <= GRID_W,
            f"{label}: col {col} + len {strlen(label)} > {GRID_W} (crosses row)")

    for label in ("menuPromptNormal", "menuPromptBirth", "menuPromptSurvival"):
        chk(strlen(label) <= GRID_W, f"{label}: len {strlen(label)} > {GRID_W}")

    # --- menu version placement (conway_main.s) ---
    chk(mvl <= GRID_W, f"menu version len {mvl} > row width {GRID_W}")
    chk(strlen("menuPromptSurvival") + 1 <= mv_col,
        f"menu version overlaps prompt: {strlen('menuPromptSurvival')} + 1 > {mv_col}")
    chk(MENU_PROMPT_OFFSET + mv_col + mvl <= 1000,
        f"menu version crosses screen: {MENU_PROMPT_OFFSET + mv_col + mvl} > 1000")

    # --- conway_grid.s simulation status row ---
    chk(strlen("statusText") == 40,
        f"simulation status must fill exactly 40 columns, got {strlen('statusText')}")
    chk(GEN_DIGITS_OFFSET + 5 == 1000,
        f"generation digits must end at screen cell 999 (GEN_DIGITS_OFFSET+5 = {GEN_DIGITS_OFFSET + 5})")

    # --- common.inc field bounds ---
    chk(MENU_BIRTH_FIELD_OFFSET + RULE_COUNT <= 16 * GRID_W,
        "birth rule field crosses row")
    chk(MENU_SURV_FIELD_OFFSET + RULE_COUNT <= 17 * GRID_W,
        "survival rule field crosses row")
    chk(PAUSE_TEXT_OFFSET + PAUSE_TEXT_LEN <= 1000,
        "pause color field crosses screen")

    if fails:
        print("check_conway_layout: FAIL", file=sys.stderr)
        for f in fails:
            print(f"  - {f}", file=sys.stderr)
        return 1
    print("check_conway_layout: OK (%d strings, menu version len %d)" % (len(STRINGS), mvl))
    return 0


if __name__ == "__main__":
    sys.exit(main())
