# Task Spec: Phase 6D Cooperative VMM Swapping & Memory Safety

## Description
Develop the App Manager Phase C cooperative swapping system to support resident program multitasking safety. Programs are stored in the REU (backed by VMM segment allocations) and swapped into the C64 main memory execution window dynamically on run/resume, preserving CPU registers and the system stack.

## Scope
- Add support to store app binary images in REU backing storage upon loading, setting `APT_FLAG_REU` ($04) flag.
- Implement cooperative memory swapping routines `aptSwapIn` and `aptSwapOut` in `apptable.asm` using REU DMA.
- Implement stack save/restore mechanism (backing up page 1 stack `$0100–$01FF` to REU, setting `APT_FLAG_STACK` ($08)).
- Save/restore CPU registers (`A`, `X`, `Y`, `P`, `SP`, and `PC`) in the App Table slot during program swapping/suspension.
- Extend OS Service Bus (`api.asm`) with four new service codes: `DOS_APP_REGISTER` ($60), `DOS_APP_FREE` ($61), `DOS_APP_LIST` ($62), and `DOS_APP_RUN` ($63).
- Harden the loader to prevent active memory corruption by validating header load addresses against protected space before disk transfer.

## Sub-tasks
- [ ] Implement VMM backing store allocation and REU DMA routines (`aptSwapIn`/`aptSwapOut`)
- [ ] Implement CPU register and stack `$0100-$01FF` save/restore logic
- [ ] Extend OS Service Bus (`api.asm`) jump table with App Manager APIs
- [ ] Modify `cmdLoad` to read PRG header address first and run safety checks before launching disk LOAD
- [ ] Integrate swapping with `RUN`/`GO` command execution flow and verify multiple resident programs
