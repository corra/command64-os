# command64 OS Code Wiki

Welcome to the command64 Operating System Wiki. This wiki contains user manuals, developer references, virtual memory specs, zero-page memory mappings, hardware findings, and active milestones.

## Documentation Hub

- **User Documentation:**
  - [OS User Manual](user-manual.md) - Learn how to build, run, and use the shell commands.
  - [DEBUG Utility Manual](debug-utility.md) - Learn how to use the built-in and external interactive assembly debugger.
  - [DEBUG Full Feature Test Plan](debug-test-plan.md) - Manual verification test suites for all interactive memory, register, and file commands.
  - [LABEL Utility Manual](label-utility.md) - Learn how to rename disk volume labels without losing data.
  - [EDLIN Utility Manual](edlin-utility.md) - Learn how to use the ported MS-DOS line editor.
  - [CONWAY Utility Manual](conway-utility.md) - Learn how to run the Conway's Game of Life demo app.
  - [PACMAN Utility Manual](pacman-utility.md) - Learn how to run the Pac-Man demo app.
  - [CASM Utility Manual](casm-utility.md) - Learn how to assemble 6502 source into a runnable PRG on the C64 itself.

- **Developer Specifications & References:**
  - [OS Service Bus API Reference](api-reference.md) - The stable entry point (`JSR $1000`) and function codes ($02–$56).
  - [Programmer's Reference](programmers-reference.md) - Memory map zero-page structures, segment safe areas, and registers.
  - [Virtual Memory Manager (VMM) Specification](vmm-api.md) - 4KB paging, RAM Expansion Unit (REU) DMA, and MCT details.
  - [PETSCII Helper API](pet-sci-api.md) - PETSCII printing macros and lowercase normalization rules.
  - [CASM Programmer's Reference](casm-programmers-reference.md) - Internal architecture, module ABIs, and diagnostic contract of the native 6502 assembler.
  - [C64 Hardware Gotchas](hardware-gotchas.md) - Hard-won findings about C64 hardware traps, REU clobbering, and input limits.
  - [MS-DOS v4.0 Feature Completeness Comparison](ms-dos-comparison.md) - Functional and architectural comparison mapping.
  - [Codebase Knowledge Graph](codebase-knowledge-graph.md) - Mermaid diagrams of `src/` and `include/` module structure, memory layout, and runtime call graphs.

## Tasks

Status reflects each spec's own checkbox state (`[ ]` pending, `[/]` in-progress, `[x]` done).

### In Progress

- [EDLIN Port](tasks/edlin-port.md) - Porting MS-DOS EDLIN to command64 OS (current branch).
- [DEBUG ca65/ld65 Migration](tasks/debug-ca65-migration.md) - Migrating the DEBUG utility off KickAssembler.
- [Phase 5 Multi-Device Support](tasks/phase-5-multi-device.md) - Switching between/interacting with devices 8-11.

### Pending

- **Phase 5: Environment & Multi-Device Support**
  - [Dynamic Device Number in Shell Prompt](tasks/phase-5-prompt-device.md)
  - [Support Subdirectories (1581 / SD2IEC)](tasks/phase-5-subdirectories.md)
- **Phase 6: Advanced OS Features**
  - [Phase 6C: Oscar64 Runtime Support](tasks/phase-6c-oscar64-support.md)
  - [Phase 6D: Cooperative VMM Swapping & Memory Safety](tasks/phase-6d-cooperative-swap.md)
  - [In Tandem: Staged ca65 Toolset Migration](tasks/toolset-migration-ca65.md)
- **Time, Date & Shell Commands**
  - [TIME Command Implementation](tasks/time.md)
  - [DATE Command Implementation](tasks/date.md)
- **Utilities**
  - [External FORMAT Utility](tasks/format.md)

### Completed

- [Build Number Tracking Restructure](tasks/build-number-restructure.md)
- [ca65 Primary Test Migration](tasks/ca65-primary-test-migration.md)
- [DEBUG Utility Feature Completeness](tasks/debug-feature-completeness.md)
- [DOS_SEND_COMMAND Kernel Primitive](tasks/dos-send-command.md)
- [Dynamic Memory Safety & Allocation](tasks/dynamic-memory-safety.md)
- [LABEL Interactive Prompt](tasks/label-interactive-prompt.md)
- [Memory-Safe Loading (Pre-flight Validation)](tasks/memory-safe-loading.md)
- [Phase 6A: App Manager](tasks/phase-6a-app-manager.md)
- [Phase 6B: Binary Relocator](tasks/phase-6b-binary-relocator.md)
- [VMM Block I/O Kernel Primitives](tasks/vmm-block-io.md)
- [VOL / LABEL Command Implementation](tasks/vol-label.md)
