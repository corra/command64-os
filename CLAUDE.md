# Claude Project Guide - C64-Development-Agent

## Environment & Tools

- **Platform**: C64 (6502/6510) Target
- **Host**: Cross-Platform
- **Assemblers**: Use Kick Assembler from `tools/` for the core OS assembly. Use ca65/ld65 for new external applications under `src/external/`; follow `src/external/AGENTS.md` for the external-app workflow.
- **C Language**: Oscar64 will be build and installed in `tools/oscar64` and will be the *C Compiler* available for
               Commodore 64 C lanugage conversion.
- **Source Control**: Git will be used exlusively in a local capacity. No pushes/pull requests will be performed at this time.
                      A fork may be created and pushed to at a later date.

### MCPs

- **Codebase Memory MCP**: `codebase-memory-mcp` is installed and **MUST BE** prefered as the first-line
    option for searching the codebase. Do not waste tokens unnecesarily by `find`ing and
    `grep`ing or making custom tools.
- **Task Warrior MCP**: `taskwarrior mcp` is installed and **MUST BE** used for task tracking if available.
- **C64 Overlay API MCP**: `c64-overlay-api` is available (OpenAPI bridge at `http://127.0.0.1:8000/openapi.json`) to trigger build and test overlay events. Note: `cmake --build` already fires build events automatically for every compile/link/pack step via the `C64_THEME_DIR` cache var (see `.agents/workflows/overlay-build-events.md`) — this MCP tool is only needed for direct/manual tool invocations that bypass `cmake --build`, and for `test` events.
- **Missing MCPs**:
    +If a MCP is *unavailable*, **STOP** Ask the user to install or activate it.
    +**The User** may directy you to proceed until otherwise directed when a MCP is unavailable. Use alternative methods. **You are NOT ALLOWED to proceed without EXPLICIT PERMISION**

## Build & Test

- **Configure CMake**: `cmake -B build`
- **Build All**: `cmake --build build` (or `make`)
- **Build OS Disk Image**: `cmake --build build --target image_d64` (or `make image`)
- **Build Test Disk Image**: `cmake --build build --target test_image_d64` (or `make testimage`)
- **Create Release Package**: `cmake --build build --target release` (or `make release`)
- **Clean Build**: `make clean` (removes `build/`)

## Technical Standards

1. **Performance**: Every instruction counts. Focus on efficient 6502 cycles.
2. **Readability**: Code must be heavily annotated to explain logic.
3. **Documentation-Driven**: Updates to spec must precede or accompany implementation.
4. **Phased Planning**: Every Phase and Work Package (CASM, DASH, DEBUG, or
   any other numbered multi-WP effort) requires a detailed, user-approved
   plan in `brain/plans/` *before* implementation begins, and a
   completion-gate walkthrough in `brain/walkthroughs/` with explicit user
   sign-off *before* it's marked done. See
   `.agents/workflows/phased-implementation-planning.md` and the
   `phased-implementation-planning` skill.
