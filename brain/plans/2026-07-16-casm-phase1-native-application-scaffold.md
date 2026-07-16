---
feature: casm-native-assembler
phase: 1
created: 2026-07-16
status: planned
depends-on: casm-phase-0-contract-freeze
---

# CASM Phase 1 Implementation Plan: Native Application Scaffold

## Objective

Build the smallest valid native `casm` external application: a ca65/ld65
program that is converted to Command 64's R6 format, ships on `image.d64`,
prints its complete version, executes the central cleanup path, and returns to
the shell without corrupting shell state.

Phase 1 establishes the application and module ABI needed by later phases. It
does not parse arguments, access files or VMM, tokenize source, or assemble
code.

## Prerequisite Gate

Implementation must not begin until Phase 0 freezes and the user approves:

- CASM's private `$70-$8F` zero-page layout;
- bounded base-RAM state and initial link-size budget;
- maximum simultaneously owned file handles and VMM allocations;
- resource record representation and invalid-handle sentinel;
- diagnostic categories and fatal-cleanup rules; and
- initial version and banner text.

If any of these contracts remain open, resolve them in Phase 0 rather than
embedding a temporary representation in the scaffold.

## Scope

### Included

- CASM-local DOX contract and task records;
- external-application directory and persistent build counter;
- ca65 entry point, header, common declarations, and module ABI;
- private zero-page and bounded base-RAM declarations;
- central resource registry initialization and cleanup skeleton;
- successful and fatal exit paths;
- minimal fixed-string diagnostic output;
- `add_ca65_app` and release-disk integration;
- build, artifact, disk-image, and manual launch verification; and
- architecture, memory-map, changelog, and walkthrough updates required by
  the repository contract.

### Excluded

- command-line parsing and all CASM options;
- file open, read, write, close, or delete operations;
- VMM allocation, free, read, or write operations;
- source streams, line normalization, and provenance;
- lexer, expressions, symbols, opcode tables, and assembly passes;
- static or relocatable output generation by CASM itself; and
- listings, maps, includes, or multiple source inputs.

## Planned Files

| Path | Action | Phase 1 responsibility |
|---|---|---|
| `wiki/tasks/casm.md` | Create | Durable meta-task and measurable phase checklist |
| `src/external/casm/AGENTS.md` | Create | CASM-local contracts, memory rules, ABI, and verification |
| `src/external/AGENTS.md` | Modify | Add CASM to the Child DOX Index |
| `src/external/casm/BUILD_CASM` | Create | Persistent build counter, initially `1000` |
| `src/external/casm/casm.s` | Create | PRG header, entry point, banner, and exit orchestration |
| `src/external/casm/common.inc` | Create | Shared constants, zero-page names, limits, and module ABI |
| `src/external/casm/resources.s` | Create | Resource registry and cleanup/exit routines |
| `src/external/casm/diagnostics.s` | Create | Minimal fixed-string diagnostics |
| `CMakeLists.txt` | Modify | Source discovery, target registration, and disk inclusion |
| `brain/MEMORY.md` | Modify | Document CASM's private memory allocation |
| `brain/KNOWLEDGE.md` | Modify | Record stable CASM scaffold and ownership decisions |
| `CHANGELOG.md` or dated changelog | Modify/Create | Record the new shipping application scaffold |
| `brain/walkthroughs/<date>-casm-phase1.md` | Create | Build and manual confirmation procedure |

`resources.s` is intentionally separate even though Phase 1 owns no live
resources. Resource ownership is a foundational CASM contract and must not
later be distributed across CLI, file, source, and VMM modules.

## Work Package 1: Tasks and DOX

1. Create `wiki/tasks/casm.md` as the CASM meta-task.
2. Add one measurable subtask for each work package in this plan.
3. Mirror the meta-task and subtasks in Task Warrior.
4. Keep every task open until its evidence is recorded.
5. Create `src/external/casm/AGENTS.md` with the standard DOX sections:
   Purpose, Ownership, Local Contracts, Work Guidance, Verification, and
   Child DOX Index.
6. Add `casm/AGENTS.md` to `src/external/AGENTS.md`'s Child DOX Index.

The CASM-local contract must state:

- CASM is a native 6510 application built with ca65/ld65;
- modules share zero-page symbols only through `.exportzp`/`.importzp`;
- routine comments document inputs, outputs, carry meaning, and clobbers;
- all owned resources are registered centrally;
- all terminal paths call central cleanup before `DOS_EXIT`;
- large future working sets belong in VMM, not unbounded BSS; and
- Phase 1 verification does not claim real file/VMM cleanup coverage.

## Work Package 2: Memory and Module ABI

### Zero Page

Declare the user-approved allocation within `$70-$8F` in `common.inc`.
Categorize every byte as persistent state, transient scratch, or reserved for a
named later subsystem. Do not assign speculative parser or linker meanings to
bytes whose representation was not frozen in Phase 0.

Rules:

- define each shared zero-page symbol in exactly one translation unit;
- export definitions with `.exportzp` and consume them with `.importzp`;
- never use plain `.export`/`.import` for zero-page storage;
- document which routines may clobber every transient field; and
- do not touch OS-owned zero-page locations outside the app-private range and
  the established shared API fields in `command64.inc`.

### Base RAM

Create only bounded Phase 1 state in `BSS`:

- current phase/status;
- last primary diagnostic code;
- cleanup-in-progress guard;
- owned-file registry or bitset with Phase 0-approved capacity;
- owned-VMM registry with Phase 0-approved capacity; and
- registry counts or occupancy flags.

Do not allocate source, token, symbol, relocation, or output buffers.

### Shared Include

`common.inc` contains declarations only:

- zero-page addresses;
- resource capacities and record offsets;
- invalid-resource sentinels;
- diagnostic and phase identifiers;
- public routine calling conventions; and
- compile-time assertions supported by ca65.

It must not contain storage or executable routines.

## Work Package 3: Resource Ownership and Exit Paths

Implement these public routines in `resources.s`:

```text
resourcesInit
resourceRegisterHandle
resourceReleaseHandle
resourceRegisterVmm
resourceReleaseVmm
resourcesCleanup
exitSuccess
exitFatal
```

### Registry Behavior

- `resourcesInit` clears every record and resets status and cleanup guards.
- Registration finds a free fixed-capacity record or returns a stable
  registry-full error.
- Release of an unused record is harmless.
- Cleanup visits only records still marked owned.
- A record is cleared when its underlying release succeeds.
- Cleanup over an empty registry is valid and repeat-safe.
- A cleanup-in-progress guard prevents recursive fatal cleanup.

Phase 1 does not acquire real handles or VMM allocations. Private close/free
helpers therefore remain explicit stubs. They must not call `DOS_CLOSE_FILE`
or `DOS_FREE_MEM` with invented identities, and comments must identify the
future phase that replaces each stub.

### Terminal Paths

`exitSuccess`:

1. Records successful status.
2. Calls `resourcesCleanup`.
3. Loads `DOS_EXIT` and calls `OS_API`.
4. Enters a defensive terminal loop if `DOS_EXIT` unexpectedly returns.

`exitFatal`:

1. Preserves the primary error code.
2. Prints the associated diagnostic when safe.
3. Calls `resourcesCleanup`.
4. Preserves the primary failure if cleanup reports a secondary failure.
5. Calls `DOS_EXIT` and defensively does not fall through.

## Work Package 4: Minimal Diagnostics

Implement in `diagnostics.s`:

```text
diagPrintString
diagPrintFatal
```

Recommended Phase 1 ABI:

- `diagPrintString`: `X/Y` points to a null-terminated PETSCII-safe string;
  it dispatches `DOS_PRINT_STR` through `OS_API`.
- `diagPrintFatal`: `A` contains a stable diagnostic code; it selects a fixed
  message and calls `diagPrintString`.

Document outputs, carry behavior, and all clobbered registers. Diagnostics
must not allocate resources and must be safe during cleanup.

Initial messages are limited to:

- internal initialization failure;
- resource registry full;
- internal cleanup failure; and
- unknown fatal error.

Filename and line provenance are intentionally deferred to the source-stream
phase, but later provenance must be addable without changing every caller.

## Work Package 5: Entry Point and Version Banner

Implement `casm.s` using the established ca65 external-app structure:

1. Include `command64.inc` and `common.inc`.
2. Define `VERSION_MAJOR`, `VERSION_MINOR`, and `VERSION_STAGE`.
3. Include generated `build_casm.inc`.
4. Import `__MAIN_START__`.
5. Emit `.word __MAIN_START__` in the `HEADER` segment.
6. At `start`, call `resourcesInit` before any fallible operation.
7. Print one null-terminated version banner.
8. Call `exitSuccess`; do not invoke `DOS_EXIT` directly elsewhere.

The recommended initial display is:

```text
CASM V0.1.0.<build>
```

The build suffix must use generated `BUILD_NUMBER`. Encode the message in the
same PETSCII-safe form as other ca65 external applications.

## Work Package 6: CMake and Disk Integration

Add source discovery beside the existing ca65 applications:

```cmake
file(GLOB_RECURSE CASM_SRCS CONFIGURE_DEPENDS
    "src/external/casm/*.s"
    "src/external/casm/*.inc"
    "include/ca65/*.inc")
set(CASM_ENTRY "src/external/casm/casm.s")
```

Register the target:

```cmake
if(Ca65_FOUND)
    add_ca65_app(casm "${CASM_ENTRY}" CASM_SRCS 1000 "<PHASE_0_SIZE>")
else()
    message(FATAL_ERROR
        "ca65/ld65 not found on PATH — required for CASM target")
endif()
set(CASM_TARGET casm)
```

Append `${CASM_TARGET}` to `IMAGE_PRG_TARGETS`.

Do not create a custom assembler, linker configuration, relocation script, or
temporary build script. `add_ca65_app` already provides the generated build
include, content-hash build counter, two ld65 links, R6 conversion, target
metadata, and final `casm.prg`.

Use the Phase 0-approved `PRG_SIZE_HEX`. If Phase 0 approves a 4 KiB initial
link envelope, use `1000`; otherwise use the approved value and record why.

## Atomic Implementation Order

Execute one approved increment at a time:

1. Create Task Warrior and `wiki/tasks/casm.md` records.
2. Create and index the CASM-local `AGENTS.md`.
3. Create `BUILD_CASM` and `common.inc`.
4. Implement and inspect `resources.s`.
5. Implement and inspect `diagnostics.s`.
6. Implement and inspect `casm.s`.
7. Register CASM in `CMakeLists.txt`.
8. Configure and build only the `casm` target.
9. Build and inspect `image_d64`.
10. Update memory, knowledge, changelog, and walkthrough documents.
11. Perform the DOX closeout pass.
12. Ask the user to run the manual verification and confirm completion.

If any increment fails, stop and perform root-cause analysis before changing
the design or attempting another fix.

## Verification

### Static Review

Confirm before building:

- every cross-module zero-page reference uses `.exportzp`/`.importzp`;
- every public routine documents inputs, outputs, flags, and clobbers;
- no Phase 1 module directly exits except through central exit routines;
- no unbounded buffer exists in BSS;
- all registry loops are bounded by compile-time capacities;
- cleanup cannot recursively invoke itself; and
- no excluded Phase 2+ behavior has entered the scaffold.

### Configure

```text
cmake -S . -B build
```

Acceptance evidence:

- exit status is zero;
- no new warning or error appears;
- CASM source manifest and link configurations are generated; and
- existing targets remain configured.

### Standalone Build

```text
cmake --build build --target casm
```

Acceptance evidence:

- every CASM translation unit assembles;
- both base and next-page images link;
- R6 conversion succeeds;
- `build/casm.prg` exists and is non-empty;
- its PRG header and R6 footer are structurally valid;
- generated `build_casm.inc` contains the persistent build number; and
- the source manifest includes all CASM `.s` and `.inc` dependencies.

Rebuild without source changes and verify `BUILD_CASM` does not increment.
Then make an intentional CASM source change in an approved increment, rebuild,
and verify it increments exactly once.

### Release Image

```text
cmake --build build --target image_d64
```

Acceptance evidence:

- the build succeeds without regressing existing applications;
- `casm.prg` is present on `image.d64`;
- the disk directory shows `CASM`; and
- no previously shipping target disappears.

Do not use the broken `c64-testing` MCP or a web emulator.

## Manual Confirmation Walkthrough

The user performs this check in the supported local emulator or on hardware:

1. Boot the newly built `image.d64`.
2. Launch `CASM` through the normal Command 64 external-command workflow.
3. Confirm exactly one `CASM V0.1.0.<build>` banner appears.
4. Confirm the Command 64 prompt returns normally.
5. Run a directory listing to confirm shell input and output remain intact.
6. Run one existing external application and return to the shell.
7. Launch CASM a second time.
8. Confirm there is no crash, prompt corruption, missing input, channel
   corruption, or progressive stack failure.

## Completion Gate

Phase 1 is ready to be marked done only when:

- the Phase 0 prerequisite contracts were approved;
- all durable and Task Warrior subtasks have recorded evidence;
- CASM builds through `add_ca65_app` as an R6 application;
- the release disk contains CASM;
- the banner includes the persistent build number;
- every exit uses central repeat-safe cleanup;
- zero-page and base-RAM ownership are documented;
- existing build targets remain intact;
- the walkthrough records the exact build and manual checks; and
- the user explicitly confirms that CASM launches and returns safely.

Until that confirmation, leave Phase 1 and its tasks in verification or
awaiting-confirmation status rather than marking them done.
