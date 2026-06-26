# Command-64OS

## Project Mission

Port of Open Sourced **MS-DOS 4.0** contained in `./v4.0` to *Commodore 64* while accepting
full compatibility is not possible due to architectural differences. Tools utilized will
include *Kick Assembler* and *Oscar 64* for the build environtment. Tools may expand as
needed.

## Concesions and Modifications

It is understood the architectures of the 8086/8088 and 6502/6510 are different
and to that end certain reasonable concessions and source code modifications will need to be made

## State Management

- `CHANGELOG.md`: **Mandatory update** for every functional change.
- Code Wiki:
    -**Mandatory Update**: For all *git commit* events the code wiki will
    be updated to remain in sync with commited development state.
    **Directed Update**: Per *user instruction* you will explicitly update
    the code wiki
    -**Discretionary Update**: Under your discresion update the code wiki
    if it will aid your development.
- `brain/KNOWLEDGE.md`: Record architectural decisions and findings.
- `brain/MEMORY.md`: Update at session end with current status and next steps.
