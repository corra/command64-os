# Task Spec: Phase 6C Oscar64 C-Runtime Support

## Description
Develop runtime library hooks and headers for the Oscar64 C Compiler, enabling developers to write command64 OS programs in C instead of assembly.

## Scope
- Write a command64 target library for Oscar64 mapping standard library operations (like file reads, console prints, and malloc) to OS Service Bus `JSR $1000` API calls.
- Create standard headers (`command64.h`) defining OS structures, Zero Page registers, and API function codes.
- Add support for command64 compiler profiles.

## Sub-tasks
- [ ] Write `command64.h` C header file.
- [ ] Implement Oscar64 mapping assembly file (`command64-oscar.asm`) wrapping standard library calls to OS dispatcher.
- [ ] Create and compile a sample C program, verifying that it correctly compiles, runs, and uses OS APIs.
