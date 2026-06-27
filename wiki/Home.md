# command64 OS Code Wiki

Welcome to the command64 Operating System Wiki. This wiki contains user manuals, developer references, virtual memory specs, zero-page memory mappings, hardware findings, and active milestones.

## Documentation Hub

- **User Documentation:**
  - [OS User Manual](user-manual.md) - Learn how to build, run, and use the shell commands.
  - [DEBUG Utility Manual](debug-utility.md) - Learn how to use the built-in and external interactive assembly debugger.
  - [LABEL Utility Manual](label-utility.md) - Learn how to rename disk volume labels without losing data.

- **Developer Specifications & References:**
  - [OS Service Bus API Reference](api-reference.md) - The stable entry point (`JSR $1000`) and function codes ($02–$56).
  - [Programmer's Reference](programmers-reference.md) - Memory map zero-page structures, segment safe areas, and registers.
  - [Virtual Memory Manager (VMM) Specification](vmm-api.md) - 4KB paging, RAM Expansion Unit (REU) DMA, and MCT details.
  - [PETSCII Helper API](pet-sci-api.md) - PETSCII printing macros and lowercase normalization rules.
  - [C64 Hardware Gotchas](hardware-gotchas.md) - Hard-won findings about C64 hardware traps, REU clobbering, and input limits.
  - [MS-DOS v4.0 Feature Completeness Comparison](ms-dos-comparison.md) - Functional and architectural comparison mapping.

## Active & Pending Tasks

- **Phase 5: Environment & Multi-Device Support**
  - [Add Multiple Device Support (8-11)](tasks/phase-5-multi-device.md)
  - [Support Subdirectories (1581 / SD2IEC)](tasks/phase-5-subdirectories.md)

- **Phase 6: Advanced OS Features**
  - [Phase 6A: App Manager](tasks/phase-6a-app-manager.md)
  - [Phase 6B: Binary Relocator](tasks/phase-6b-binary-relocator.md)
  - [Phase 6C: Oscar64 Runtime Support](tasks/phase-6c-oscar64-support.md)

- **Time, Date & Disk Label Support**
  - [VOL / LABEL Command Implementation](tasks/vol-label.md)
  - [TIME Command Implementation](tasks/time.md)
  - [DATE Command Implementation](tasks/date.md)
