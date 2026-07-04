# Task Spec: Phase 6A App Manager

## Description
Develop a centralized Application Table manager to track loaded external programs, protect their execution and memory bounds, and support clean unregistration and program listing commands.

## Scope
- Allocate a 512-byte table segment in main RAM (`AppTable`) and store tracking information in a VMM page.
- Relocate `UserProgStart` from `$2000` to `$2200` to make space.
- Write `apptable.asm` implementation with: `aptInit`, `aptProtectedCheck`, `aptSlotBase`, `aptNameMatch`, `aptFind`, `aptRegister`, `aptRemove`, `aptList`.
- Gate `LOAD` commands with memory checks to prevent overwriting critical OS segments.
- Gate `RUN`/`GO` to only allow execution of successfully registered apps.
- Implement shell commands `APPS`/`PS` and `FREE`.

## Sub-tasks
- [/] Implement `apptable.asm` routines and integrate with system boot.
- [x] Relocate external utility build addresses from `$2000` to `$2200`.
- [ ] Implement protective bounds checks in the DOS loader.
- [ ] Implement `APPS` and `FREE` shell handlers.
- [ ] Perform integration tests on App Table registration and safety limits.
