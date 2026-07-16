---
feature: casm-native-assembler-phase1
created: 2026-07-16
completed: 2026-07-16
status: completed
---

# Walkthrough: CASM Phase 1 Native Application Scaffold

## Summary

Phase 1 adds CASM as a native ca65/ld65 Command 64 external application. The
scaffold reserves its approved private zero-page categories, initializes a
bounded central resource registry, prints `CASM V0.1.0.<build>`, executes
repeat-safe cleanup, and returns through `DOS_EXIT`.

No assembler language behavior is present yet. CLI parsing, file services,
VMM transfers, source streams, lexing, expressions, symbols, code generation,
and output serialization remain later phases.

## Files Changed

| File | Change | Notes |
|---|---|---|
| `src/external/casm/AGENTS.md` | Created | CASM-local DOX and verification contract |
| `src/external/casm/BUILD_CASM` | Created | Persistent build number and content hash |
| `src/external/casm/common.inc` | Created | `$70-$8F` aliases, limits, diagnostics, and ABI constants |
| `src/external/casm/resources.s` | Created | Bounded ownership registries, cleanup, and central exits |
| `src/external/casm/diagnostics.s` | Created | Allocation-free fixed-string diagnostics |
| `src/external/casm/casm.s` | Created | PRG header, initialization, banner, and clean exit |
| `CMakeLists.txt` | Modified | CASM ca65 target and `IMAGE_PRG_TARGETS` entry |
| `src/external/AGENTS.md` | Modified | Added CASM to the Child DOX Index |
| `wiki/tasks/casm.md` | Created | Durable task and acceptance tracker |
| `brain/task.md` | Modified | Synchronized CASM Task Warrior state |
| `brain/MEMORY.md` | Modified | Documented CASM's `$70-$8F` use |
| `brain/KNOWLEDGE.md` | Modified | Recorded approved Phase 1 foundation |
| `brain/plans/2026-07-16-casm-phase1-native-application-scaffold.md` | Modified | Recorded approved Phase 0 values and execution state |
| `CHANGELOG.md` | Modified | Added the CASM Phase 1 scaffold |

## Automated Build and Artifact Results

Commands completed successfully:

```text
cmake -S . -B build
cmake --build build --target casm
cmake --build build --target casm
cmake --build build --target image_d64
```

Evidence:

- CASM base link: `$3400`, 549-byte PRG.
- CASM comparison link: `$3500`, 549-byte PRG.
- Code bytes excluding the two-byte PRG header: 547.
- Final `build/casm.prg`: 687 bytes.
- R6 relocation entries: 66 (`$0042`).
- R6 footer bytes: `00 34 42 00 52 36`, representing base `$3400`, count
  `$0042`, and magic `R6`.
- Embedded banner: `CASM V0.1.0.1000`.
- A no-change second build left `BUILD_CASM` at 1000.
- `image.d64` contains `CASM` as a three-block PRG.
- The release image still contains `command64`, `debug`, `label`, `format`,
  `comp`, `edlin`, `conway`, and `pacman`.
- `git diff --check` passed.

## Manual Runtime Confirmation

The repository's `c64-testing` MCP is broken and web emulators are prohibited,
so the user must perform this check in the supported local emulator or on
hardware.

1. Boot `build/image.d64` in the normal Command 64 test environment.
2. At the Command 64 prompt, enter `CASM` using the normal external-command
   launch workflow.
3. Confirm exactly one line appears:

   ```text
   CASM V0.1.0.1000
   ```

4. Confirm the Command 64 prompt returns normally.
5. Run `DIR` and confirm keyboard input and screen output remain intact.
6. Launch one existing external application and return to the shell.
7. Run `CASM` a second time.
8. Confirm the banner prints again and the shell returns without a crash,
   malformed prompt, missing input, channel corruption, or progressive stack
   failure.

Record the emulator/hardware used and whether every step passed. Phase 1 must
remain open until the user provides this confirmation.

### User Result

On 2026-07-16, the user confirmed that all eight steps passed in local
emulation: the expected banner printed on both launches, the shell returned
intact, `DIR` and another external application worked, and no crash,
input/output corruption, channel corruption, or progressive stack failure was
observed.

## Lessons and Constraints

- Task Warrior numeric IDs compact after completed tasks; project records use
  stable UUID prefixes for CASM subtasks.
- The scaffold's physical close/free helpers intentionally invalidate only
  empty Phase 1 records. File-service and VMM phases replace them with real OS
  release calls when those phases begin acquiring resources.
- CASM currently consumes 547 linked bytes plus 45 BSS bytes within the
  approved `$1000` `MAIN` envelope.
- The unrelated `src/external/pacman/BUILD_PACMAN` worktree modification was
  preserved and excluded from CASM work.
