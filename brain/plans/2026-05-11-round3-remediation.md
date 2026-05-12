---
feature: command64-round3-remediation
created: 2026-05-11
status: completed
---

# Plan: command64 Round 3 Remediation

## Goal
Fix the three confirmed issues from the Round 3 code review of Gemini's Phase 2D changes.

## Issues

| ID | File | Fix |
|----|------|-----|
| A  | `tests/build_tests.sh:1` | Replace `tests/bin/bash` with `#!/bin/bash` |
| B  | `tests/build_tests.sh:9-13` | Prefix all source paths with `tests/src/` |
| D  | `CHANGELOG.md` | Add `[0.2.4]` entry for Phase 2D changes |

## Fixes

### A + B: tests/build_tests.sh
```bash
#!/bin/bash
# tests/build_tests.sh

KICKASS="tools/KickAss.jar"
OUTDIR="tests/bin"

mkdir -p $OUTDIR

echo "Compiling tests..."
java -jar $KICKASS tests/src/hello.asm -odir $OUTDIR
java -jar $KICKASS tests/src/color.asm -odir $OUTDIR
java -jar $KICKASS tests/src/extcls.asm -odir $OUTDIR
java -jar $KICKASS tests/src/apitest.asm -odir $OUTDIR
java -jar $KICKASS tests/src/vmmtest.asm -odir $OUTDIR

echo "Done."
```

### D: CHANGELOG.md entry
```markdown
## [0.2.4] - 2026-05-11

### Added
- **Phase 2D (Service Bus)**: Implemented INT 21h-style BRK service bus (`api.asm`, `$1600`).
  Handles DOS_PRINT_CHAR ($02), DOS_PRINT_STR ($09), DOS_ALLOC_MEM ($48), DOS_FREE_MEM ($49), DOS_EXIT ($4C).
- **BRK Vector Install**: Shell startup installs `apiHandler` to `KernalCBINV` ($0316/$0317).
- **VMM Safety Guard**: Added `vmmInitialized` flag; `vmmAlloc` returns `VMM_ERR_INVALID` if REU not detected.
- **Test Scaffolding**: Added `tests/src/apitest.asm` and `tests/src/vmmtest.asm`.

### Fixed
- **printDecimal16**: Initialized `TempHi` to 0 at entry to prevent garbage leading zeros.

### Changed
- **Segment Layout Cascade**: api.asm→$1600, utils→$1700, loader→$1800, path→$1880, vmm→$1980, vmmData→$1C80.
- **Version**: 0.2.4 (Build 2303), Stage 4.
```

## Verification
- Run `bash tests/build_tests.sh` from project root — all 5 compiles should succeed.
- Review CHANGELOG.md for correct `[0.2.4]` entry.
