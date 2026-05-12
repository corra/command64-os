---
description: Ensure user, programmer, and API documentation are synchronized with project state
---

# Documentation Maintenance Workflow

This workflow ensures that the public-facing documentation (`README.md`, `docs/*.md`) and the internal architectural record (`brain/*.md`) are consistently maintained and synchronized during the development lifecycle.

## When to Run

- **Start of Phase:** When beginning a new development phase (e.g., Phase 3).
- **Post-Implementation:** Immediately after verifying a feature or architectural change.
- **API Change:** Every time the OS Service Bus or ABI is modified.
- **Build Update:** Every time the build/version number is incremented.

## Documentation Tiers

| Tier | Files | Target Audience | Source of Truth |
|------|-------|-----------------|-----------------|
| **User** | `README.md` | General Users | Feature list, building instructions. |
| **Programmer** | `docs/programmers-reference.md` | App Developers | Memory map, Zero Page usage, binary mode safety. |
| **API Reference** | `docs/api-reference.md` | App Developers | OS Entry points, register ABI, function codes. |
| **Internal Brain** | `brain/MEMORY.md`, `brain/plans/` | Maintainers/Agents | Architectural rationale, task status, WIP notes. |

## Workflow Steps

### 1. Architectural Sync (Internal)
Whenever a design decision is made (e.g., "Pivot to Jump Table"):
1. Update `brain/KNOWLEDGE.md` with the rationale and date.
2. Update the `Memory Map` section in `brain/MEMORY.md`.
3. Update `brain/task.md` to reflect progress.

### 2. API & Spec Sync (Technical)
Whenever the code in `api.asm`, `vmm.asm`, or `file.asm` changes:
1. Review `docs/api-reference.md`. Ensure all function numbers and register conventions match the code.
2. Review `docs/programmers-reference.md`. Ensure the memory map and ZP safe areas are current.
3. If VMM logic changed, update `docs/vmm-api.md`.

### 3. User & Release Sync (Public)
Whenever a new feature is added to the shell or a build is performed:
1. Update `CHANGELOG.md` with the build number and summary of changes.
2. If new commands were added (e.g., `TYPE`), update the table in `README.md`.
3. Verify that "Getting Started" or build commands in `README.md` are still accurate.

### 4. Build Metadata
1. Ensure `src/command64/shell.asm` reflects the correct `BUILD_NUMBER`.
2. Synchronize the `Version` line in `brain/MEMORY.md`.

## Verification

Before declaring a task "Done", perform a **Documentation Audit**:
- [ ] Does the `README.md` reflect the current feature set?
- [ ] Does `docs/api-reference.md` match the dispatch table in `api.asm`?
- [ ] Does the memory map in `docs/programmers-reference.md` match `include/command64.inc`?
- [ ] Is the `CHANGELOG.md` updated with the current build?

## Quality Bar

- **No stale addresses:** All hardcoded addresses in documentation must be verified against the current build's `.sym` or memory map.
- **Self-Describing:** A developer should be able to write a functional app using *only* the contents of the `docs/` folder.
