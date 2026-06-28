---
feature: label-build-tracking
created: 2026-06-27
status: planned
---

# Plan: LABEL Build Tracking Support

## Goal & Rationale
Integrate the external `LABEL` utility into the OS build tracking system, matching `COMMAND64` and `DEBUG`. This increments a build counter upon code modification, generates a `build_label.inc` file, and displays the version string on execution.

## Scope
- Create `BUILD_LABEL` containing the starting build number (`1000`).
- Update `CMakeLists.txt` to increment the build counter and dependency list.
- Modify `src/external/label/label.asm` to import the generated build file and print the version header.

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `BUILD_LABEL` | Create | Initial build number string "1000". |
| `CMakeLists.txt` | Modify | Build system commands & dependencies. |
| `src/external/label/label.asm` | Modify | Add imports, version printing logic, and string literal. |
| `CHANGELOG.md` | Modify | Document additions. |

## Key Design Decisions
Implement an `add_custom_command` matching the pattern of other utilities, and print version info using `DOS_PRINT_STR` at `start:` entry point.

## Verification Plan
- Clean compilation with `make`.
- Verify `BUILD_LABEL` increments.
- Run `label` with no arguments, verifying output shows `LABEL v0.1.0.1001` (or next build index) and `Label name required`.
