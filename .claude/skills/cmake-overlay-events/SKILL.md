---
name: cmake-overlay-events
description: Use when adding a new cmake/*.cmake file, a new add_*_target/add_*_app helper function, or a new add_custom_command/add_custom_target in CMakeLists.txt that invokes an external build tool (KickAssembler, ca65, ld65, cc1541, oscar64, or any future toolchain). Triggers on: new CMake helper, new build target, wiring a new assembler/compiler into the build, PackRelease-style packaging step, overlay build events, C64_THEME_DIR.
---

# CMake Overlay Events

Full contract: `.agents/workflows/overlay-build-events.md`. That workflow
doc — referenced from `AGENTS.md`'s MCP section — is the canonical,
agent-neutral rule; it binds any agent working in this repo (Primary
Architect, Companion Agent, or otherwise), not just Claude. This file is
only a Claude Code-specific at-edit-time reminder layered on top of that
contract — the `.claude/skills/` mechanism itself isn't available to other
agents, so nothing load-bearing should live only here. If you're an agent
without access to this skill, read the workflow doc directly instead.

## The rule

Every `add_custom_command`/`add_custom_target` that shells out to an
external build tool (assembler, compiler, linker, disk-image packer) must
wrap that invocation in the same `scripts/build_event_wrapper.py` pattern
already used throughout `cmake/*.cmake`, gated on `if(C64_THEME_DIR)`. A new
CMake file that invokes a build tool without this wrapper is a bug, not
something to defer.

## Copy from

- **Single-step** (one command does the whole job) — `cmake/cc1541.cmake` or
  `cmake/Oscar64.cmake`:
  ```cmake
  set(WRAPPER_CMD "")
  if(C64_THEME_DIR)
      set(WRAPPER_CMD "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/scripts/build_event_wrapper.py"
          "--theme-dir" "${C64_THEME_DIR}" "--target" "${TARGET_NAME}" "--building" "--success" "--error" "--")
  endif()
  add_custom_command(... COMMAND ${WRAPPER_CMD} <real command> ...)
  ```
- **Multi-step** (compile → link → post-process) — `cmake/Ca65.cmake`'s
  `add_ca65_app`: separate `WRAPPER_*` vars per step, `--building` only on
  the first step, `--success` only on the terminal step, `--error` on every
  step.

## Checklist

1. External build tool invoked? If no (pure `file()`/`execute_process(cmake
   -E ...)`), skip — add a one-line comment saying why (see
   `cmake/IncrementBuildNumber.cmake`).
2. Single-step or multi-step? Copy the matching pattern above.
3. `--building` on exactly one (first) step, `--success` on exactly one
   (last) step, `--error` on every step.
4. Wrapper resolves to `""` when `C64_THEME_DIR` is unset — build behavior
   must be unchanged without it.

Direct/ad-hoc tool invocations that bypass `cmake --build`, and all
`type: test` events, are **not** covered by this pattern — those stay a
manual `mcp__c64-overlay-api__trigger-event-event-pst` call; see the
workflow doc's "Stays Manual" table.
