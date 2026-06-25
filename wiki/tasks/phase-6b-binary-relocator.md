# Task Spec: Phase 6B Binary Relocator

## Description
Build a relocator module that allows programs compiled with relocation headers to be loaded and run at arbitrary main memory addresses, resolving address references dynamically at load time.

## Scope
- Define relocation header/metadata format for command64 executables.
- Write loading relocation resolver that patches absolute 16-bit address fields (e.g. absolute jumps and loads/stores) based on actual load offset.
- Add support in `LOAD` command to automatically trigger relocation.

## Sub-tasks
- [ ] Design relocatable executable file format.
- [ ] Implement loading patching engine in `src/command64/loader.asm` or a dedicated module.
- [ ] Create test relocatable binary and verify correct execution at arbitrary memory addresses.
