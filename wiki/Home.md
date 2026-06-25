# command64 OS Code Wiki

Welcome to the command64 Operating System Wiki. This wiki contains user manuals, developer references, virtual memory specs, zero-page memory mappings, hardware findings, and active milestones.

## Documentation Hub

- **User Documentation:**
  - [OS User Manual](file:///home/morgan/development/c64/command64-os/wiki/user-manual.md) - Learn how to build, run, and use the shell commands.
  - [DEBUG Utility Manual](file:///home/morgan/development/c64/command64-os/wiki/debug-utility.md) - Learn how to use the built-in and external interactive assembly debugger.

- **Developer Specifications & References:**
  - [OS Service Bus API Reference](file:///home/morgan/development/c64/command64-os/wiki/api-reference.md) - The stable entry point (`JSR $1000`) and function codes ($02–$56).
  - [Programmer's Reference](file:///home/morgan/development/c64/command64-os/wiki/programmers-reference.md) - Memory map zero-page structures, segment safe areas, and registers.
  - [Virtual Memory Manager (VMM) Specification](file:///home/morgan/development/c64/command64-os/wiki/vmm-api.md) - 4KB paging, RAM Expansion Unit (REU) DMA, and MCT details.
  - [PETSCII Helper API](file:///home/morgan/development/c64/command64-os/wiki/pet-sci-api.md) - PETSCII printing macros and lowercase normalization rules.
  - [C64 Hardware Gotchas](file:///home/morgan/development/c64/command64-os/wiki/hardware-gotchas.md) - Hard-won findings about C64 hardware traps, REU clobbering, and input limits.

## Active & Pending Tasks

- **Phase 5: Environment & Multi-Device Support**
  - [Add Multiple Device Support (8-11)](file:///home/morgan/development/c64/command64-os/wiki/tasks/phase-5-multi-device.md)
  - [Support Subdirectories (1581 / SD2IEC)](file:///home/morgan/development/c64/command64-os/wiki/tasks/phase-5-subdirectories.md)

- **Phase 6: Advanced OS Features**
  - [Phase 6A: App Manager](file:///home/morgan/development/c64/command64-os/wiki/tasks/phase-6a-app-manager.md)
  - [Phase 6B: Binary Relocator](file:///home/morgan/development/c64/command64-os/wiki/tasks/phase-6b-binary-relocator.md)
  - [Phase 6C: Oscar64 Runtime Support](file:///home/morgan/development/c64/command64-os/wiki/tasks/phase-6c-oscar64-support.md)
