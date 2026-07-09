# Purpose

The purpose of the `src` directory is to contain the core assembly files of the command64 operating system, including the shell, file system, API dispatcher, PETSCII helper routines, loader, and virtual memory manager (VMM).

# Ownership

- Primary Owner: Primary Architect (Claude)
- Peer Owner: Companion Agent (Gemini)

# Local Contracts

- Core OS source files must be in 6502/6510 Assembly, designed for assembly using Kick Assembler. External applications are governed by `src/external/AGENTS.md`.
- Code must adhere to technical standards: zero-page layout safety, non-reentrancy awareness, stack discipline, and registers/flags preservation.
- All code modifications must update the memory map in `brain/MEMORY.md` if memory regions shift.

# Work Guidance

- Segment boundaries must be carefully aligned (64-byte padding recommended).
- Check `brain/MEMORY.md` for zero-page allocations to prevent variables collision.
- Use registers `A`, `X`, `Y` efficiently; preserve registers in routines unless they are returned values.

# Verification

- Code must compile with 0 warnings and 0 errors via `make all` or `make image`.

# Child DOX Index

- [external/AGENTS.md](external/AGENTS.md)
