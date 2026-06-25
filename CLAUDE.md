# Claude Project Guide - C64-Development-Agent

## Environment & Tools

- **Platform**: C64 (6502/6510) Target
- **Host**: Cross-Platform
- **Assembler**: Use Kick Assember contained in `tools/` for building assembly
- **C Language**: Oscar64 will be build and installed in `tools/oscar64` and will be the *C Compiler* available for
               Commodore 64 C lanugage conversion.
- **Source Control**: Git will be used exlusively in a local capacity. No pushes/pull requests will be performed at this time.
                      A fork may be created and pushed to at a later date.

### MCPs

- **Codebase Memory MCP**: `codebase-memory-mcp' is installed and should be prefered as a first-line option over re-reading the codebase. Do not waste tokens needlessly.
- **Task Warrior MCP**: `taskwarrior mcp' is installed and must be used for task tracking.
- **Missing MCPs**:
    +If a MCP is *unavailable*, **STOP** Ask the user to install or activate it.
    +**The User** may directy you to proceed until otherwise directed when a MCP is unavailable. Use alternative methods. **You are NOT ALLOWED to proceed without EXPLICIT PERMISION**

## Build & Test

No build or test at this time.

## Technical Standards

1. **Performance**: Every instruction counts. Focus on efficient 6502 cycles.
2. **Readability**: Code must be heavily annotated to explain logic.
3. **Documentation-Driven**: Updates to spec must precede or accompany implementation.
