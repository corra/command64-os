---
feature: phase2a-input-vmm
created: 2026-05-03
status: in-progress
---

# Plan: Phase 2A Follow-on (Input & VMM)

## Goal & Rationale
Fix the inherent C64 screen editor "quote mode" bug by replacing `CHRIN` with a raw `GETIN` polling loop. Additionally, define the VMM (Virtual Memory Manager) ABI to enable the next phase of the project (external commands and memory-mapped DOS services).

## Scope
- Implement raw keyboard input using `GETIN` ($FFE4).
- Implement manual character echo to maintain standard shell behavior.
- Define the VMM API headers in `include/vmm.inc` as a foundational layer for Phase 2B.

## Files to Create/Modify
| File | Action | Modify |
|------|--------|-------|
| `src/command64/shell.asm` | Modify | Replace `shellReadLine` with `GETIN` loop |
| `include/command64.inc` | Modify | Add `KernalGetIn` and VMM ZP equates |
| `include/vmm.inc` | Create | Formalize VMM API constants and prototypes |

## Key Design Decisions
- **Input Loop**: Use `GETIN` for raw bytes. Since `GETIN` doesn't echo to screen, `CHROUT` must be called immediately after each byte is read to maintain the user experience.
- **VMM Definition**: Based on the `docs/vmm-api.md` spec, we will use zero-page pointers for Segment/Offset andREU banking control.

## Verification Plan
- **Manual Check**: Enter a double-quote `"` in the shell and use cursor keys; verify that it no longer inserts control codes into the buffer.
- **Build Check**: Ensure `build/command64.asm` assembles without errors.

## Progress
- [x] Define `KernalGetIn` and VMM ZP equates in `include/command64.inc`
- [x] Replace `shellReadLine` with `GETIN` loop and manual echo in `src/command64/shell.asm`
- [ ] Create `include/vmm.inc`
