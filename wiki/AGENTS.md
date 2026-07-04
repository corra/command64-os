# Purpose

The purpose of the `wiki` directory is to store the comprehensive user and programmer manuals, OS specification documents, API references, zero-page allocations, memory maps, hardware findings, and active task files.

# Ownership

- Primary Owner: Companion Agent (Gemini)
- Peer Owner: Primary Architect (Claude)

# Local Contracts

- Document changes in real time when APIs or user commands are modified.
- Keep the wiki synchronized with the main project repository states.
- The detailed memory map in [wiki/programmers-reference.md](wiki/programmers-reference.md) MUST be kept synchronized with segment definitions in [src/command64.asm](src/command64.asm) and constants in [include/command64.inc](include/command64.inc) whenever memory layout changes occur.

# Work Guidance

- Use clear markdown, tables, and lists.
- Avoid duplicate info; link to `wiki/Home.md` or other specific files.

# Verification

- Perform manual/visual verification of markdown links and format.

# Child DOX Index

- [tasks/AGENTS.md](tasks/AGENTS.md)
