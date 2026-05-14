# Claude Project Guide - C64-Development-Agent

## Project Mission

Port of Open Sourced *MS-DOS 4.0* contained in `./v4.0` to *Commodore 64* while accepting
full compatibility is not possible due to architectural differences. Tools utilized will
include *Kick Assembler* and *Oscar 64* for the build environtment. Tools may expand as
needed. 

## Concesions and Modifications

It is understood the architectures of the 8086/8088 and 6502/6510 are different 
and to that end certain reasonable concessions and source code modifications will need to be made. 

## Core Documentation

- `GEMINI.md`: Directives and persona for the companion agent.

## State Management

- `CHANGELOG.md`: **Mandatory update** for every functional change.
- `brain/KNOWLEDGE.md`: Record architectural decisions and findings.
- `brain/MEMORY.md`: Update at session end with current status and next steps.

## Environment & Tools

- **Platform**: C64 (6502/6510) Target
- **Host**: Cross-Platform
- **Python**: Use the virtual environment at `tools/python3_env/`. For shell commands, use `tools/python3_env/bin/python` 
              or ensure the environment is activated.
- **Assembler**: Use Kick Assember contained in `tools/` for building assembly 
- **C Language**: Oscar64 will be build and installed in `tools/oscar64` and will be the *C Compiler* available for 
               Commodore 64 C lanugage conversion.
- **Source Control**: Git will be used exlusively in a local capacity. No pushes/pull requests will be performed at this time.
                      A fork may be created and pushed to at a later date.

## Build & Test

No build or test at this time.

## Technical Standards

1. **Performance**: Every instruction counts. Focus on efficient 6502 cycles.
2. **Readability**: Code must be heavily annotated to explain logic.
3. **Documentation-Driven**: Updates to spec must precede or accompany implementation.
