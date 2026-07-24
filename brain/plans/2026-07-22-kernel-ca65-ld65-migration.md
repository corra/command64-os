---
feature: kernel-ca65-ld65-migration
created: 2026-07-22
status: proposed
---

# Plan: Migrate the Command 64 Kernel to ca65/ld65

## Goal

Transition the Command 64 kernel from KickAssembler to `ca65` and `ld65`,
unifying active assembly builds on the cc65 assembler/linker suite already used
by external applications. Remove Java and KickAssembler from the active build,
test, image, and release toolchain after a byte-identical ca65 kernel passes the
full runtime gate.

This plan does not replace Oscar64 as the C compiler. Only `ca65` and `ld65`
from the cc65 suite are used for assembly sources.

## Approved Decisions

- Use a **parallel full-kernel port**, followed by an atomic production-target
  switch. Do not use the binary/symbol bridge proposed by the older staged
  migration plan.
- Require a **byte-identical `command64.prg`** before cutover, except only a
  generated build-number difference separately approved by the user.
- Remove KickAssembler from the **active toolchain**. Historical plans and
  records may retain accurate KickAssembler references.
- Keep parked `dvorak` source as explicitly non-buildable reference material;
  it must not retain an active Java or KickAssembler dependency.
- Preserve existing module boundaries during translation. Do not split,
  refactor, optimize, or add features while changing assembler syntax.
- Build the kernel as an ordinary fixed-address PRG. Do not pass it through
  `tools/reloc.py` or append an R6 footer.
- Keep initialized and mutable kernel storage file-backed. Do not introduce
  BSS until an explicit startup-clear contract exists.

This plan supersedes the implementation strategy in
`brain/plans/2026-07-04-staged-rewrite-ca65.md`. That file remains a historical
record and should be marked superseded rather than rewritten.

## Current Build Contract

The current kernel is assembled from `src/command64.asm` and nine imported
modules through `add_kickass_target`. The source relies on KickAssembler for:

- `.file`, `.segmentdef`, fixed starts, and `startAfter` packing;
- `#import` source aggregation;
- `.encoding "petscii_mixed"`;
- `BasicUpstart2(start)`;
- `.label`, `.const`, `.text`, and string concatenation;
- brace-style macros and `.fill`;
- Java/JAR execution through `cmake/KickAssembler.cmake`.

The existing external-app helper cannot be reused unchanged. `add_ca65_app`
links applications at `$3400` and `$3500`, then derives R6 relocation data.
The kernel instead requires one static link with multiple fixed and packed
resident regions.

## Target Source Layout

Use a temporary parallel tree during migration:

```text
src/command64-ca65/
    launcher.s
    petsci.s
    api.s
    utils.s
    loader.s
    path.s
    vmm.s
    file.s
    apptable.s
    shell.s
    common.inc
    command64.cfg
```

After parity and runtime approval, promote those sources to the existing kernel
scope under `src/command64/` and remove the corresponding production `.asm`
files and Kick entry manifest.

Keep `shell.s`, `file.s`, and `vmm.s` monolithic during migration. Their current
segment-fragment ordering, branch spans, labels, and clobber contracts are part
of the parity baseline.

## Target Build Architecture

Add a dedicated helper, preferably `add_ca65_kernel`, rather than adding kernel
conditionals to `add_ca65_app`.

The helper must:

1. Consume an explicit ordered source list.
2. Assemble one object per `.s` file using `ca65 -t c64`.
3. Pass source-local, `include/ca65`, and generated include directories.
4. Use collision-safe object paths derived from source-relative paths.
5. Link once through the kernel linker configuration.
6. Emit `.prg`, `.map`, `.lbl`, and `.dbg` artifacts.
7. Run static layout and artifact checks.
8. Set `C64_PRG_PATH` for disk-image integration.
9. Build initially as `command64_ca65`, outside `IMAGE_PRG_TARGETS`.

Use this deterministic object order:

```text
launcher.o
petsci.o
api.o
utils.o
loader.o
path.o
vmm.o
file.o
apptable.o
shell.o
```

Object order is behavior because ld65 concatenates same-named segment
fragments in object order. In particular, the `SHELLEXT` contributions must
retain the current order:

```text
utils.o -> loader.o -> file.o -> shell.o
```

## Fixed Memory Contract

The linker must preserve these architectural boundaries:

| Region | Required placement |
|---|---|
| PRG load address | `$0801` |
| BASIC launcher | starts `$0801`, ends before `$0820` |
| `UTILS` | starts `$0820` |
| Pre-API chain | ends before `$1000` |
| `APISTUB` | exactly `$1000`, one three-byte `JMP apiHandler` |
| `PETSCI` | immediately after `APISTUB` |
| `COMMANDTABLE` | immediately after `PETSCI` |
| `COMMANDSHELL` | immediately after `COMMANDTABLE`, ends before `$1FA0` |
| `VMMDATA` | exactly `$1FA0-$1FFF` |
| `APPTABLE` | starts exactly `$2000` |
| `SHELLEXT` | immediately after `APPTABLE` |
| Resident kernel maximum | below `UserProgStart`, currently `$3400` |

The current measured floating boundaries in `brain/MEMORY.md` are a baseline,
not substitutes for a freshly generated KickAssembler map:

```text
$0820-$0FE8  pre-API chain
$1000-$1002  APISTUB
$1003-$1018  PETSCI
$1019-$10F8  COMMANDTABLE
$10F9-$1F39  COMMANDSHELL
$1FA0-$1FFF  VMMDATA
$2000-$2494  APPTABLE
$2495-$32C5  SHELLEXT
```

## Linker Configuration Design

Use separate file-backed memory regions so the required internal gaps are
present in the PRG while the final high region ends with actual `SHELLEXT`
content instead of being padded unnecessarily to `$33FF`.

Conceptual configuration:

```cfg
SYMBOLS {
    UserProgStart: type = export, value = $3400;
}

MEMORY {
    PRGHEADER:
        start = $0000, size = $0002, file = %O;

    LOW:
        start = $0801, size = $07FF, file = %O,
        fill = yes, fillval = $00;

    MIDDLE:
        start = $1000, size = $0FA0, file = %O,
        fill = yes, fillval = $00;

    VMMDATA_MEM:
        start = $1FA0, size = $0060, file = %O,
        fill = yes, fillval = $00;

    HIGH:
        start = $2000, size = $1400, file = %O;
}

SEGMENTS {
    LOADADDR:     load = PRGHEADER,   type = ro;

    MAIN:         load = LOW,         type = ro, start = $0801;
    UTILS:        load = LOW,         type = ro, start = $0820;
    API:          load = LOW,         type = ro;
    LOADER:       load = LOW,         type = ro;
    PATH:         load = LOW,         type = ro;
    VMM:          load = LOW,         type = ro;
    FILE:         load = LOW,         type = ro;

    APISTUB:      load = MIDDLE,      type = ro, start = $1000;
    PETSCI:       load = MIDDLE,      type = ro;
    COMMANDTABLE: load = MIDDLE,      type = ro;
    COMMANDSHELL: load = MIDDLE,      type = rw;

    VMMDATA:      load = VMMDATA_MEM, type = rw, start = $1FA0;

    APPTABLE:     load = HIGH,        type = rw, start = $2000;
    SHELLEXT:     load = HIGH,        type = rw;
}
```

This is a design candidate, not a frozen cfg. Its file-gap and final-length
behavior must first be proven by a linker fixture against reviewed bytes.

## Mandatory Link Assertions

The final cfg must reject all boundary drift:

```cfg
ASSERT(__MAIN_RUN__ = $0801,
       error, "MAIN must start at $0801");
ASSERT(__MAIN_SIZE__ <= $001F,
       error, "BASIC launcher overlaps UTILS");
ASSERT(__UTILS_RUN__ = $0820,
       error, "UTILS moved");
ASSERT(__FILE_LAST__ < $1000,
       error, "pre-API kernel overlaps APISTUB");
ASSERT(__APISTUB_RUN__ = $1000,
       error, "stable API entry moved");
ASSERT(__APISTUB_SIZE__ = 3,
       error, "APISTUB must remain one JMP");
ASSERT(__COMMANDSHELL_LAST__ < $1FA0,
       error, "COMMANDSHELL overlaps VMMDATA");
ASSERT(__VMMDATA_RUN__ = $1FA0,
       error, "VMMDATA moved");
ASSERT(__VMMDATA_SIZE__ = $0060,
       error, "VMMDATA must cover $1FA0-$1FFF");
ASSERT(__APPTABLE_RUN__ = $2000,
       error, "APPTABLE moved");
ASSERT(__SHELLEXT_RUN__ = __APPTABLE_RUN__ + __APPTABLE_SIZE__,
       error, "SHELLEXT is not packed after APPTABLE");
ASSERT(__SHELLEXT_LAST__ < UserProgStart,
       error, "kernel overlaps external applications");
ASSERT(UserProgStart = $3400,
       error, "kernel and application origins disagree");
```

Add equivalent checks for:

- `vmmInitialized == $1FA0`;
- `vmmTempByte == $1FA1`;
- `fileScratch == $1FA2`;
- date bytes at `$1FFC-$1FFF`;
- opcode `$4C` at `$1000`;
- PRG header bytes `$01,$08`.

## Work Packages

### WP0: Task and Contract Reconciliation

Replace the obsolete binary-bridge task structure with this approved parallel
port while preserving existing task identities where possible.

Actions:

- update `wiki/tasks/toolset-migration-ca65.md`;
- synchronize Taskwarrior and `brain/task.md`;
- mark the older bridge plan as superseded;
- record the parallel-port, active-toolchain, byte-parity, static-output, and
  no-BSS decisions;
- create separately approved implementation packages rather than activating
  the whole migration at once.

Acceptance:

- task records and dependencies agree;
- every package has measurable acceptance criteria;
- the user approves the reconciled task contract.

### WP1: Freeze the KickAssembler Oracle

Capture the authoritative pre-migration baseline:

- Git revision and dirty-state note;
- `BUILD_OS` value and source hash;
- Java and KickAssembler versions;
- ca65 and ld65 versions;
- PRG SHA-256, length, and load address;
- segment map and all fixed/public symbols;
- gap ranges and fill bytes;
- BASIC launcher bytes;
- command table bytes and handler addresses;
- `VMMDATA` bytes;
- final resident extent and `UserProgStart`.

Use repository build infrastructure for any reusable manifest generation. Do
not create an untracked one-off script.

Acceptance:

- a no-change Kick build reproduces the same artifact;
- the baseline manifest can be regenerated;
- build-number handling is frozen for candidate comparisons.

### WP2: ld65 Kernel Layout Fixture

Before porting kernel code, prove the proposed linker model with a small ca65
fixture containing:

- PRG header `$01,$08`;
- launcher region at `$0801`;
- fixed transition at `$0820`;
- gap before `$1000`;
- three-byte API stub at `$1000`;
- fixed `$1FA0-$1FFF` data;
- high code at `$2000` with a dynamic final end.

Add negative fixtures for each linker assertion.

Acceptance:

- exact expected bytes and file length;
- correct map/label/debug output;
- each boundary violation fails linking;
- no R6 footer and no `tools/reloc.py` invocation.

### WP3: Parallel ca65 Kernel Infrastructure

Implement `add_ca65_kernel` and register `command64_ca65` outside production
images.

Build-number policy during coexistence:

- the shipping Kick target remains the owner of `BUILD_OS`;
- candidate builds consume the same frozen displayed build number;
- candidate edits do not increment shipping `BUILD_OS`;
- the source-manifest cutover may increment `BUILD_OS` once;
- host and candidate parity artifacts always use the same value.

Acceptance:

- existing CMake configure/build remains unchanged;
- candidate builds independently;
- candidate build does not modify production images or `BUILD_OS`;
- object order and outputs are deterministic.

### WP4: Kernel Include Reconciliation

Reconcile:

- `include/command64.inc`;
- `include/vmm.inc`;
- `include/ca65/command64.inc`;
- `include/ca65/vmm.inc`.

Add kernel-only definitions omitted from the app-oriented ca65 mirror, while
keeping the external ABI compatible. Prefer linker-exported `UserProgStart`
over duplicated values. Preserve all zero-page addresses and case-sensitive
symbols.

Acceptance:

- shared symbols match equate-for-equate;
- no zero-page allocation changes;
- external applications still assemble;
- all kernel modules consume the approved ca65 include chain.

### WP5: PETSCII and BASIC Launcher Compatibility

Implement a ca65 character map matching KickAssembler's
`petscii_mixed` behavior. Cover every source character used by command names,
messages, version output, environment keys, and parser character literals.
Keep protocol bytes numeric where byte identity matters.

Replace `BasicUpstart2(start)` with explicit tokenized BASIC data that:

- starts at `$0801`;
- fits before `$0820`;
- emits decimal `SYS` text for the linked `start` address;
- preserves next-line pointers and terminators;
- matches the frozen launcher bytes exactly.

Acceptance:

- character-map fixture matches Kick bytes;
- command-table text matches exactly;
- launcher bytes match exactly;
- BASIC `RUN` reaches the same `start` address.

### WP6: Mechanical Module Translation

Translate without refactoring, in this order:

1. `petsci.asm` -> `petsci.s`
2. `utils.asm` -> `utils.s`
3. `path.asm` -> `path.s`
4. `loader.asm` -> `loader.s`
5. `vmm.asm` -> `vmm.s`
6. `file.asm` -> `file.s`
7. `apptable.asm` -> `apptable.s`
8. `api.asm` -> `api.s`
9. `shell.asm` -> `shell.s`

Mechanical conversion includes:

- `//` to `;` comments;
- quoted ca65 segment names;
- `.label`/`.const` to fixed equates or macros;
- `.text` to encoding-controlled byte strings;
- `.fill` to file-backed initialized storage;
- macro braces to `.macro`/`.endmacro`;
- explicit imports and exports;
- safe scope for underscore-prefixed labels;
- preservation of all low/high-byte expressions.

Critical rules:

- do not use plain imports for linker-defined zero-page symbols; use
  `.importzp`/`.exportzp` where applicable;
- do not convert initialized kernel storage to BSS;
- preserve the intentional `.byte $2C` opcode in `apptable`;
- preserve carry, zero, register, stack, and interrupt contracts;
- do not let ca65 change zero-page instructions to absolute instructions;
- preserve all repeated segment-fragment order.

Per-module acceptance:

- zero warnings and errors;
- no unresolved symbols;
- candidate links;
- segment map is reviewed;
- relevant byte ranges match the Kick artifact;
- existing related tests still build.

### WP7: Whole-Kernel Binary Parity

With one frozen build number:

1. build the Kick kernel;
2. build the ca65 kernel;
3. compare maps and public symbols;
4. compare complete PRG bytes;
5. compare lengths and SHA-256 hashes;
6. stop at and classify the first difference;
7. do not create a standing exception list without user approval.

Verify explicitly:

- PRG header and launcher;
- every gap byte;
- all segment starts and ends;
- API stub;
- command table and pointers;
- `VMMDATA` layout;
- version banner;
- final resident extent.

Acceptance:

- complete binary comparison succeeds;
- hashes match;
- all fixed and public symbols match;
- no unexplained differences remain.

### WP8: Runtime Regression Gate

The user performs runtime verification in the supported local emulator or on
hardware. Do not use the broken `c64-testing` MCP or a web emulator.

Walkthrough coverage:

- BASIC `RUN`, version banner, and prompt;
- uppercase/lowercase command recognition;
- `DIR`, `TYPE`, `COPY`, `DEL`, `REN`, `LOAD`, and `RUN`;
- `DATE`, `TIME`, environment, and PATH behavior;
- VMM allocation/read/write/free and no-REU behavior;
- app registration and R6 relocation;
- device changes and file-handle cleanup;
- repeated launch and return for DEBUG, EDLIN, and CASM;
- repeated startup and shell integrity.

Acceptance:

- user confirms the walkthrough;
- no carry, register, zero-page, stack, vector, or memory-map regression;
- user explicitly approves the production target switch.

### WP9: Atomic Production Cutover

After WP7 and WP8:

- make the public `command64` target use ca65/ld65;
- retain `command64.prg` and disk naming;
- promote ca65 sources to final paths;
- remove production Kick kernel sources and entry manifest;
- remove temporary `command64_ca65` naming;
- perform a clean configure and build;
- verify no-change build-number stability;
- build production image, test image, and release.

Acceptance:

- target and artifact names are unchanged;
- clean build produces the approved byte-identical artifact;
- disk directory loses or renames no program;
- release packaging succeeds;
- `BUILD_OS` advances at most once for the source-manifest transition.

### WP10: Port the Kick-Only Relocation Test

Port `tests/src/reloc/reloc.asm` to `tests/src/reloc/reloc.s` while preserving
the public `test_reloc` target and dual-origin relocation coverage.

Acceptance:

- test builds through `add_ca65_app`;
- base/next output lengths and relocation entries are validated;
- `test_reloc` remains on `test.d64`;
- no active `.asm` test target remains.

### WP11: Remove Active KickAssembler and Java

Remove active CMake dependencies:

- `find_package(Java REQUIRED)`;
- `find_package(KickAss REQUIRED)`;
- `include(KickAssembler)`;
- Kick `.asm` test discovery;
- `add_kickass_target` and `add_external_app` callers.

Delete after the last caller is gone:

- `cmake/FindKickAss.cmake`;
- `cmake/KickAssembler.cmake`;
- `tools/KickAss.jar`.

Then:

- make `find_package(Ca65 REQUIRED)` represent the unified assembler suite;
- remove Kick dialect generation from `IncrementBuildNumber.cmake` if no active
  consumer remains;
- retain Python and `tools/reloc.py` for external applications;
- retain `cc1541`, Oscar64, and release packaging unchanged;
- mark `dvorak` clearly as parked and non-buildable.

Acceptance:

- clean configure succeeds without Java;
- clean configure succeeds without the JAR;
- no active command references KickAssembler or Java;
- `all`, `image_d64`, `test_image_d64`, and `release` succeed.

### WP12: Documentation and DOX Closeout

Update active contracts and documentation:

- `src/AGENTS.md`;
- `src/external/AGENTS.md`;
- `tests/AGENTS.md`;
- applicable root agent instructions;
- `README.md` and `tools/README.md`;
- `brain/KNOWLEDGE.md` and `brain/MEMORY.md`;
- `wiki/programmers-reference.md` and mirrored docs;
- `docs/codebase-reference.md`;
- `wiki/codebase-knowledge-graph.md`;
- `wiki/hardware-gotchas.md`;
- `CHANGELOG.md`;
- task records and final walkthrough.

Historical plans, reviews, walkthroughs, and changelog entries retain their
original KickAssembler context.

Acceptance:

- current docs contain no stale Java/Kick build requirement;
- required wiki/docs mirrors are byte-identical;
- DOX contracts and child indexes are current;
- Taskwarrior, `wiki/tasks`, and `brain/task.md` agree;
- user approves the final walkthrough before the migration task is marked done.

## Verification Matrix

| Gate | Check | Required result |
|---|---|---|
| Configure | `cmake -S . -B build` | No warning or error |
| Candidate | `cmake --build build --target command64_ca65` | Success |
| Static layout | ld65 assertions and map inspection | Every fixed boundary exact |
| Binary parity | complete comparison and SHA-256 | Identical |
| Production image | `cmake --build build --target image_d64` | Success |
| Test image | `cmake --build build --target test_image_d64` | Success |
| Release | `cmake --build build --target release` | Success |
| No-change build | rebuild unchanged targets | No counter increment |
| Java removal | clean configure without Java/JAR | Success |
| Runtime | user-operated walkthrough | Explicit approval |

## Stop Conditions

Stop implementation and perform root-cause analysis if:

- ca65 selects absolute addressing where Kick used zero page;
- any instruction changes size;
- a branch moves or exceeds range;
- PETSCII or command-table bytes differ;
- any public or fixed symbol moves;
- `APISTUB` differs from one absolute jump;
- `VMMDATA` becomes BSS;
- object order changes segment-fragment order;
- candidate builds increment `BUILD_OS` during coexistence;
- the candidate enters production images before approval;
- resident code reaches `$3400`;
- binary comparison fails without an understood first difference.

## Expected End State

Kernel build:

```text
ca65 + ld65
    -> command64.prg
    -> image.d64 / test.d64
```

External application build:

```text
ca65 + ld65 at $3400 and $3500
    -> tools/reloc.py
    -> R6 relocatable PRG
```

The active build no longer requires Java, `KickAss.jar`, Kick CMake modules,
Kick-format generated includes, or Kick-only tests.
