---
feature: vmm-abi
created: 2026-05-03
status: planned
---

# Plan: VMM ABI Specification

## Goal & Rationale
Formalize the VMM ABI (Application Binary Interface) in a dedicated header file. This separates the memory management logic from the core shell constants and allows other modules (like the file system) to use the same VMM interface without depending on the shell.

## Scope
- Create `include/vmm.inc` based on `docs/vmm-api.md`.
- Define the register passing conventions and return codes.
- Define the REU control registers.

## Files to Create/Modify
| File | Action | Notes |
|------|--------|-------|
| `include/vmm.inc` | Create | VMM ABI header |

## Key Design Decisions
- **Include guards**: Use KickAssembler's `.if` or simply rely on the build entry point's import order.
- **Symmetry**: Ensure constants match the `docs/vmm-api.md` specification exactly.

## Verification Plan
- **Build Check**: Try importing `include/vmm.inc` into a dummy file to check for syntax errors.

## Progress
- [ ] Create `include/vmm.inc`
