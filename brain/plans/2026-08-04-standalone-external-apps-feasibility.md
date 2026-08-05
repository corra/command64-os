---
feature: standalone-external-applications
created: 2026-08-04
status: feasibility-study
---

# Feasibility Study: Standalone Command64 External Applications

## Executive Summary

Creating standalone Commodore 64 editions of selected Command64 external
applications is technically feasible. Maintaining them as independent source
forks is not advisable. The recommended architecture keeps one application core
and supplies two platform implementations:

1. A Command64 platform adapter that preserves the current `OS_API` ABI.
2. A standalone C64 platform adapter built on KERNAL, CBM DOS, and an optional
   shared REU runtime.

This approach allows the Command64 and standalone artifacts to be built and
tested from the same functional sources. Platform differences remain explicit
at a narrow boundary instead of being scattered through command, parser, editor,
or assembler logic.

The three applications have different feasibility profiles:

| Application | Standalone feasibility | Initial useful edition | Full parity difficulty |
| :--- | :---: | :--- | :---: |
| DEBUG | High | Monitor/file tools without REU commands | Moderate |
| EDLIN | High | Editor with the existing 2 KiB RAM fallback | Moderate |
| CASM | Conditional but viable | REU-required assembler with bounded features | High |

The recommended sequence is DEBUG first, EDLIN second, a shared standalone REU
runtime third, and CASM only after the platform layer has proven stable. A
standalone CASM without REU support would contradict its current bounded-storage
architecture and would either require severe feature limits or a separate
storage design.

This document is a feasibility study, not authorization to implement any phase.
Every proof of concept or production conversion requires a dedicated approved
plan.

## 1. Study Question

Can applications currently built under `src/external/`, especially DEBUG, CASM,
and EDLIN, also ship as ordinary C64 PRGs that:

- load and run without Command64;
- use the C64 KERNAL and CBM DOS directly;
- optionally use an REU;
- preserve the Command64 editions;
- share fixes and features between both editions; and
- avoid doubling maintenance and regression risk?

The answer is yes if the project treats standalone support as a platform port of
the existing application cores. The answer is economically unfavorable if each
standalone edition becomes a manually synchronized fork.

## 2. Definitions and Target Assumptions

### 2.1 Standalone

For this study, a standalone application is a normal C64 PRG that can be loaded
from BASIC or a conventional loader without first booting Command64. A baseline
launch sequence is:

```text
LOAD"DEBUG",8,1
SYS <entry-address>
```

A friendlier artifact may include a BASIC stub and start with `RUN`. That is a
packaging choice, not an application-core requirement.

### 2.2 Parallel Maintenance

Parallel maintenance means:

- one authoritative implementation of application behavior;
- platform-specific code only for services that actually differ;
- two independently buildable artifacts;
- shared functional tests where behavior is meant to match; and
- explicit platform tests where behavior intentionally differs.

It does not mean copying `debug.s`, `casm/`, or `edlin/` into a second tree and
manually applying every fix twice.

### 2.3 Hardware Tiers

The standalone products should define two hardware tiers:

| Tier | Hardware | Expected behavior |
| :--- | :--- | :--- |
| Base C64 | 64 KiB C64, no REU | Core console and file features; bounded RAM-only behavior where practical. |
| C64 + REU | Supported REU size | Extended buffers, DEBUG REU commands, and full CASM storage architecture. |

CASM should be allowed to require the second tier. Pretending full CASM can run
comfortably in the first tier would move complexity into overlays, disk-backed
temporary stores, or reduced limits and produce a different product.

## 3. Current Coupling Baseline

All three applications are ca65/ld65 external programs built by
`add_ca65_app`. The current build path:

- links once at `UserProgStart` and once one page higher;
- derives relocation information by comparing the two outputs;
- emits a Command64-relocatable PRG;
- includes `include/ca65/command64.inc`;
- expects application-private zero page at `$70-$8F`; and
- expects OS services and shared parameter cells at fixed addresses.

### 3.1 Command64 ABI Dependencies

The shared include establishes these important contracts:

| Contract | Current location or convention | Standalone consequence |
| :--- | :--- | :--- |
| Service dispatcher | `OS_API = $1000` | Must be replaced, wrapped, or emulated. |
| Command line | `CommandBuffer = $033C`, `ParsePos = $63` | BASIC does not populate this convention. |
| File/VMM parameters | Shared zero-page cells `$66-$6D` | A standalone runtime may preserve these internally, but they are not a stock C64 ABI. |
| Application scratch | `$70-$8F` | Usually reusable standalone after checking BASIC/KERNAL and resident-tool conflicts. |
| Program termination | `DOS_EXIT` resets stack and enters the Command64 shell | Must restore machine state and return to BASIC or a caller. |
| Relocation | Command64 R6 artifact and loader | Standalone needs a fixed-origin artifact or its own relocator. |

### 3.2 Service Dependency Matrix

The source uses the following Command64 service families:

| Service family | DEBUG | EDLIN | CASM |
| :--- | :---: | :---: | :---: |
| Print character/string | Yes | Yes | Yes |
| Exit to shell | Yes | Yes | Yes |
| Command buffer/parse position | No normal CLI dependency | Yes | Yes |
| File open/read/write/close | Mostly direct KERNAL code | Yes | Yes |
| Delete or command channel | Existing file features use direct KERNAL; no central OS file dependency | Yes | Yes |
| Device-prefix parsing | No | No current core dependency | Yes |
| VMM allocate/free | Yes | Yes, with RAM fallback | Extensive |
| VMM block read/write | Yes | Yes | Extensive |
| System information | Yes, for `XS` | No | No |
| Central resource cleanup | DEBUG-local REU registry | Application-local | Foundational eight-file/eight-VMM registry |

Direct KERNAL use already exists in DEBUG and EDLIN for console or file
operations. This is useful evidence that application logic is not inherently
tied to the Command64 dispatcher. The difficult coupling is state and service
semantics, not the 6510 instruction code itself.

## 4. Standalone Runtime Requirements

### 4.1 Startup and Packaging

The standalone linker target should produce a conventional fixed-origin PRG.
The Command64 R6 relocation trailer should not be present in the standalone
artifact.

Two packaging forms are feasible:

| Form | Advantages | Disadvantages |
| :--- | :--- | :--- |
| BASIC stub plus machine code | `LOAD`, then `RUN`; accessible to ordinary users | Stub and load-layout maintenance; may constrain origin choices. |
| Machine-code PRG | Small and simple; compatible with machine-code loaders | User must know the `SYS` entry address. |

The first proof of concept should use a fixed machine-code PRG. A BASIC stub can
be added after the memory map is stable.

Startup must:

1. Record the caller's stack pointer and relevant machine state.
2. Establish the application's expected zero-page and BSS state.
3. Acquire arguments through a standalone mechanism.
4. Initialize platform services.
5. Enter the unchanged application core.

Termination must release files and REU allocations, restore channels and stack
state, and return with `RTS` to a BASIC `SYS` caller or use a documented warm
start policy. Jumping to Command64's shell is not available.

### 4.2 Command-Line Replacement

Stock BASIC has no Command64-style external-command tail. EDLIN and CASM cannot
assume `CommandBuffer` and `ParsePos` contain arguments.

Candidate argument strategies are:

| Strategy | Suitability |
| :--- | :--- |
| Interactive startup prompt | Recommended baseline. Works everywhere and reuses application parsing after copying input into a private buffer. |
| BASIC stub with `DATA` or fixed variables | Poor user experience and weak interoperability. |
| Loader-defined argument convention | Useful optional integration, but not standalone in the broad sense. |
| Multiple launcher PRGs | Simple for fixed workflows, unmaintainable for general CASM options. |

The platform API should expose a bounded `platformGetCommandLine` routine. The
Command64 adapter copies or references the existing command buffer. The
standalone adapter prompts and fills the same application-owned normalized
buffer. CASM already copies bounded filename data instead of mutating the OS
buffer, which makes this separation practical.

### 4.3 Console Services

Console output maps directly to KERNAL `CHROUT`. Polling input maps to `GETIN` or
blocking input to `CHRIN`, depending on the application's current UX. Static
PETSCII strings remain reusable.

The platform layer needs only narrow operations:

```text
platformPrintChar
platformPrintString
platformGetKey
platformReadLine
```

DEBUG and EDLIN already contain local line-input behavior, so the first adapter
can be thin. Consolidating line input is optional and should not be a
prerequisite if doing so changes editing behavior.

### 4.4 File and Device Services

Standalone file operations can use KERNAL `SETLFS`, `SETNAM`, `OPEN`, `CHKIN`,
`CHKOUT`, `CHRIN`, `CHROUT`, `READST`, `CLOSE`, and `CLRCHN`. Delete, rename,
replace, and drive-status operations require commands over logical file 15.

The complexity lies in reproducing Command64 semantics:

- bounded logical-file handle allocation;
- PRG versus SEQ/USR type selection;
- device-prefix parsing;
- stale KERNAL status-byte handling;
- command-channel lifetime and cache behavior;
- partial read/write reporting;
- cleanup after primary failures; and
- error-code translation expected by each application.

The standalone layer must be specified from observed Command64 contracts, not
merely implemented as similarly named routines. CASM in particular relies on
deterministic cleanup and on Pass 2 performing no filesystem access for include
replay.

### 4.5 REU and Memory Services

A full standalone runtime needs:

- REU detection and size determination;
- allocation in 4 KiB pages;
- contiguous allocation identity;
- free validation;
- bounded C64-to-REU and REU-to-C64 transfers;
- 64 KiB boundary handling;
- state initialization and cleanup; and
- optional system counters for DEBUG `XS`.

Two implementation levels are possible:

| Runtime | Description | Suitable applications |
| :--- | :--- | :--- |
| Single-owner/simple allocator | One application owns the REU session; compact extent table or bump allocator with bounded frees | DEBUG prototype, EDLIN |
| Command64-compatible VMM semantics | Multiple extents, validated identity, page counters, bounded transfers, deterministic reuse | Full DEBUG, CASM |

A direct compatibility port of the Command64 VMM is possible, but the standalone
runtime should not assume it owns C64 RAM at Command64's `VmmMctBase = $C000`.
That area may be RAM under ROM, but stock-machine ROM banking and interrupt
behavior make it a poor implicit public requirement. The standalone linker must
assign allocator metadata deliberately inside the application's fixed memory
budget or in a reserved banked-RAM region with explicit banking discipline.

### 4.6 Interrupts, ROM Banking, and Machine Restoration

Standalone programs run in a less controlled environment than Command64. They
must define:

- expected ROM/I/O banking in processor port `$01`;
- whether IRQ remains enabled during REU transfers;
- preservation/restoration of IRQ/BRK vectors used by DEBUG;
- restoration of KERNAL channels;
- screen and character-set assumptions; and
- behavior after a target program crashes under DEBUG.

DEBUG has the largest restoration risk because it deliberately changes BRK
handling, stack state, and target execution context. A standalone DEBUG must
have a reliable return-to-monitor and return-to-BASIC contract before it is
considered safe.

## 5. Build and Memory Feasibility

The current configured `MAIN` envelopes provide useful upper bounds:

| Application | Current envelope | Approximate fixed range at `$3800` | Observation |
| :--- | ---: | :--- | :--- |
| DEBUG | `$2400` (9 KiB) | `$3800-$5BFF` | Comfortable fixed-origin candidate; leaves substantial upper RAM. |
| EDLIN | `$1800` (6 KiB) | `$3800-$4FFF` | Comfortable; RAM fallback adds a bounded 2 KiB buffer within its linked state. |
| CASM | `$4900` (18.25 KiB) | `$3800-$80FF` | Fits below BASIC/KERNAL ROM, but consumes enough RAM that large stores must remain in REU. |

These are linker envelopes, not guaranteed final file sizes. A proof of concept
must inspect CODE, RODATA, DATA, BSS, stack use, zero-page ownership, and the
standalone runtime together.

Potential fixed origins should be evaluated rather than copied blindly:

- `$3800` minimizes divergence from current links.
- Lower origins leave more contiguous upper RAM but may collide with BASIC
  program text or standalone runtime metadata.
- Higher origins preserve BASIC workspace but reduce application headroom and
  may overlap ROM windows or common cartridge conventions.

The standalone target should fail at link time when its declared envelope is
exceeded.

## 6. Architecture Alternatives

### 6.1 Alternative A: Independent Source Forks

Create separate standalone copies such as `standalone/debug/debug.s` and apply
changes manually to both editions.

Advantages:

- Fastest first prototype.
- Maximum freedom to alter standalone UX and internals.

Disadvantages:

- Every defect fix must be discovered and applied twice.
- CASM's many modules and frozen internal contracts will drift rapidly.
- Review cannot easily distinguish intentional divergence from missed merges.
- Build counters, versions, manuals, and tests become reconciliation work.

Verdict: reject for production. A disposable spike may copy code outside the
source tree, but no fork should become authoritative.

### 6.2 Alternative B: Pervasive Conditional Assembly

Retain one source tree but surround OS interactions with
`.ifdef STANDALONE` branches.

Advantages:

- One file contains both implementations.
- Low up-front structural cost.

Disadvantages:

- Platform conditions spread through failure paths and resource ownership.
- Both variants become difficult to reason about locally.
- CASM's service calls span CLI, diagnostics, files, includes, resources, and
  VMM modules, creating broad conditional complexity.

Verdict: acceptable only for entry packaging or a few compile-time constants.
Do not use as the primary service architecture.

### 6.3 Alternative C: Shared Core and Platform Adapters

Define a narrow application-facing platform ABI and provide separate Command64
and standalone implementations.

Advantages:

- Application behavior remains shared.
- Platform semantics are reviewable in one place.
- Tests can run against both adapters.
- Future applications can reuse the standalone runtime.
- Command64 remains the reference implementation while standalone behavior is
  introduced incrementally.

Disadvantages:

- Requires careful extraction of current implicit ABI assumptions.
- Initial patches touch call boundaries even when behavior should not change.
- Adapter interfaces can become an accidental second OS API if designed too
  broadly.

Verdict: recommended.

### 6.4 Alternative D: Compatibility Kernel at `$1000`

Build a standalone support runtime that implements the subset of `OS_API` used
by an application at the same `$1000` address. Existing service calls remain
unchanged.

Advantages:

- Minimal changes to application call sites.
- Command64 API semantics provide an existing specification.
- Good diagnostic spike for discovering hidden dependencies.

Disadvantages:

- Occupies low memory and couples standalone products permanently to the
  Command64 ABI.
- Packaging code at `$1000` plus an application at `$3800` creates a sparse or
  multi-stage load problem.
- `CommandBuffer`, shared zero page, shell exit, and relocation still require
  adaptation.
- It can accidentally grow into a second Command64 kernel.

Verdict: useful as a temporary feasibility harness, not the preferred product
architecture. Adapter routines may internally preserve register conventions
where that lowers migration risk without residing at `$1000`.

## 7. Recommended Architecture

### 7.1 Boundary Shape

Use application-specific platform facades backed by a small shared C64 runtime:

```text
Application core
  |-- console facade
  |-- command-line facade
  |-- file/device facade
  |-- memory/REU facade
  `-- termination facade

Command64 build                 Standalone build
  `-- Command64 adapter           `-- KERNAL/CBM DOS/REU adapter
```

Avoid a universal high-level framework in the first phase. Start with the
smallest functions needed by DEBUG. Promote operations into a shared runtime
only after a second application demonstrates identical semantics.

### 7.2 Candidate Repository Shape

The final shape should be decided during implementation planning, but this
study recommends the following direction:

```text
src/external/debug/
  debug.s                    shared application core
  platform_command64.s       Command64 service bindings
  platform_standalone.s      standalone bindings and entry/exit

src/external/edlin/
  ...shared editor modules...
  platform_command64.s
  platform_standalone.s

src/external/casm/
  ...shared assembler modules...
  platform_command64.s
  platform_standalone.s

src/standalone/runtime/
  console.s
  fileio.s
  command_line.s
  reu.s                      added only after a dedicated REU phase
```

This is illustrative, not an instruction to create directories now. The nearest
DOX contracts must be designed before adding a durable standalone boundary.

### 7.3 Build Targets

Each application should expose independent targets, for example:

```text
debug                  existing Command64 relocatable artifact
debug_standalone       fixed-origin standalone PRG
edlin
edlin_standalone
casm
casm_standalone
```

The existing artifact names must not silently change. Standalone outputs need
distinct names on disk and in release archives. The standalone helper should:

- compile the same core source modules;
- select exactly one platform adapter;
- use a fixed-origin ld65 configuration;
- omit R6 relocation generation;
- optionally prepend a BASIC loader stub;
- enforce memory bounds;
- preserve content-hash build numbering or adopt a documented product-version
  policy; and
- expose map/label files for memory verification.

### 7.4 Version Policy

Recommended policy:

- Share semantic application version numbers while behavior remains common.
- Give each artifact an independent build identity or include a platform suffix
  in build metadata.
- Record platform-specific deviations in the same application changelog entry.
- Do not bump the shared semantic version merely because packaging differs.
- Require both variants to pass before declaring a shared-core feature complete.

If standalone behavior intentionally diverges, the divergence must be documented
as a platform capability, not hidden behind the same claim of parity.

## 8. Application-Specific Assessment

### 8.1 DEBUG

#### Existing Advantages

- Most monitor, assembler, disassembler, register, trace, and memory logic is
  self-contained.
- Console and file paths already use many KERNAL routines directly.
- DEBUG does not depend on the Command64 command tail for its normal interactive
  operation.
- Its local four-record REU ownership model is already bounded.

#### Required Adaptation

- Replace `DOS_PRINT_STR` with a standalone string printer.
- Replace `DOS_EXIT` with state restoration and return to BASIC.
- Split or adapt REU allocate/free/read/write and `DOS_GET_SYSTEM_INFO`.
- Audit BRK/IRQ vector handling against stock KERNAL entry conditions.
- Produce a fixed-origin PRG and document safe target-memory ranges.

#### Product Tiers

1. DEBUG Core Standalone: memory, registers, assembly, disassembly, file tools,
   and execution controls; reject or omit `XA`/`XD`/`XM`/`XS` clearly.
2. DEBUG REU Standalone: add the shared REU allocator and status facade.

#### Feasibility Verdict

High. DEBUG is the best proof of concept because the useful no-REU core is large
and the OS boundary is narrow. The main technical risk is safe restoration after
debugged code corrupts machine state, not ordinary console operation.

### 8.2 EDLIN

#### Existing Advantages

- Own interactive command loop and line input.
- Existing bounded 2 KiB base-RAM fallback when VMM allocation fails.
- Sequential file access maps naturally to KERNAL channels.
- Fixed 40x25 geometry already matches a stock C64.

#### Required Adaptation

- Obtain the startup filename from an interactive standalone command line.
- Implement standalone file create/read/write/delete and command-channel
  behavior with matching error semantics.
- Return to BASIC after deterministic cleanup.
- Keep the existing fallback buffer for the first edition.
- Add REU-backed 16 KiB editing only after the shared REU runtime exists.

#### Product Tiers

1. EDLIN RAM Standalone: 2 KiB maximum file/edit buffer, clear size reporting.
2. EDLIN REU Standalone: existing 16 KiB VMM-backed behavior through the shared
   runtime.

#### Feasibility Verdict

High. EDLIN may require more file-service work than DEBUG, but it already has a
credible no-REU operating mode. Its first standalone release can be useful
without solving general REU allocation.

### 8.3 CASM

#### Existing Advantages

- Modular ca65 design with explicit public routine contracts.
- Bounded resource registries and centralized cleanup.
- CLI copies bounded filenames into private storage.
- File, VMM, resource, and diagnostic operations are already separated into
  modules rather than embedded entirely in parser logic.

#### Structural Dependencies

CASM uses Command64 services across:

- CLI/device-prefix parsing;
- source and include file loading;
- output creation, abort, and deletion;
- diagnostic output;
- eight-file ownership;
- eight-allocation VMM ownership;
- source, symbol, relocation, include metadata, and reporting stores;
- bounded VMM window transfers; and
- cleanup before every exit.

Its architecture intentionally assumes large stores are outside base RAM. The
current MAIN envelope can contain code and bounded staging state, but it cannot
absorb all current VMM stores without redesign.

#### Required Adaptation

- Standalone interactive CLI with multiple source names and options.
- Device-prefix parser matching current accepted grammar.
- Full standalone file lifecycle and command-channel support.
- A multi-allocation REU runtime with at least CASM's eight-slot semantics.
- Exact window bounds and the 64 KiB single-allocation boundary.
- Deterministic include behavior and zero Pass 2 source I/O.
- Existing primary-error/secondary-cleanup precedence.

#### Feasibility Verdict

Technically viable but high effort. CASM should not be the runtime prototype.
Begin only after DEBUG and EDLIN have validated console, file, packaging, and
REU components. A standalone CASM should initially require an REU rather than
introducing a weak disk-backed or severely reduced variant under the same name.

## 9. Maintenance and Quality Model

### 9.1 Source-of-Truth Rules

- Application algorithms remain in their existing app-owned modules.
- Platform modules may translate services but may not duplicate parser,
  command, editor, assembler, or diagnostic policy.
- Shared constants with identical meaning remain shared.
- Platform-only constants live in the owning adapter.
- No bug fix is complete until both affected artifacts are assessed.

### 9.2 Test Layers

| Layer | Purpose |
| :--- | :--- |
| Host/static | Build both variants; inspect headers, origins, maps, sizes, relocation presence/absence, imports, and forbidden references. |
| Shared functional fixtures | Prove parsers, assembler output, editor transforms, and monitor calculations remain identical. |
| Command64 runtime | Preserve current shell launch, OS service, VMM, and cleanup behavior. |
| Standalone runtime | Verify BASIC launch/return, KERNAL channels, machine restoration, and optional REU behavior. |
| Cross-artifact comparison | Compare deterministic output files and diagnostics for identical inputs where platform behavior should match. |

Every standalone target needs a static check that it has no unresolved or
literal dependency on `OS_API`, `CommandBuffer`, `ParsePos`, Command64 R6
trailers, or OS-private memory unless that dependency is intentionally provided
by its selected adapter.

### 9.3 Documentation

Each application manual should have one shared command reference with a
capability table rather than two copied manuals. Platform-specific launch,
memory, REU, and file limitations should be clearly marked.

Release documentation must state:

- required hardware;
- load and start commands;
- fixed memory range;
- REU requirement or fallback limit;
- file/device syntax differences; and
- safe exit/recovery behavior.

## 10. Risk Analysis

| Risk | Probability | Impact | Mitigation |
| :--- | :---: | :---: | :--- |
| Source forks drift | High under fork design | High | One core plus adapters; reject durable copies. |
| Platform ABI becomes too broad | Medium | High | Add only operations demanded by proven call sites; review per app. |
| Standalone file semantics differ subtly | High | High for CASM/EDLIN | Contract tests for status, EOF, partial I/O, command channel, and cleanup. |
| REU allocator corrupts memory | Medium | Critical | Separate approved design; bounds checks; direct evidence in emulator/hardware. |
| Fixed origin collides with BASIC/cartridge/tooling | Medium | High | Publish memory map; link-time bounds; test common launch environments. |
| DEBUG cannot recover from target code | Medium | High | Machine-state contract, vector restoration, destructive-target limitations. |
| CASM exceeds RAM budget | High without REU | High | Make REU a stated requirement; retain external stores. |
| Conditional code becomes pervasive | Medium | Medium | Keep conditions in entry/configuration and adapter modules. |
| Product versions become ambiguous | Medium | Medium | Shared semantic version plus platform build identity. |
| MS-DOS-derived provenance is unclear | Unknown | High release risk | Complete source-by-source licensing/provenance audit before standalone distribution. |

## 11. Licensing and Provenance Gate

The current source headers use the MIT SPDX identifier, while DEBUG and EDLIN
are described as ports of MS-DOS utilities and the repository contains MS-DOS
reference material. Before distributing standalone artifacts separately from
Command64, the project must verify:

- which files are original implementations versus translated/copied material;
- whether any tables, messages, or code sequences came from restricted source;
- whether the repository's MIT declaration is sufficient for each artifact;
- required attribution and source-offer obligations, if any; and
- whether names such as DEBUG and EDLIN create distribution or trademark
  concerns in the intended channels.

This is a release gate, not a technical blocker for an internal proof of
concept. It requires qualified legal review if provenance cannot be established
from repository history and source records.

## 12. Effort Estimate

The following ranges are engineering estimates, not commitments. They include
design, implementation, static checks, runtime verification, and documentation,
but exclude prolonged hardware-specific debugging and legal review.

| Work package | Estimate |
| :--- | ---: |
| Fixed-origin standalone build helper and packaging spike | 3-6 engineer-days |
| Minimal console/entry/exit platform layer | 3-5 engineer-days |
| DEBUG core standalone | 5-10 engineer-days |
| Standalone file/device layer | 6-12 engineer-days |
| EDLIN RAM standalone | 5-10 engineer-days after file layer |
| Shared standalone REU runtime | 10-20 engineer-days |
| Full DEBUG REU support | 3-7 engineer-days after REU runtime |
| EDLIN REU support | 2-5 engineer-days after REU runtime |
| CASM standalone integration | 20-40 engineer-days after shared layers |
| Release/CI/cross-artifact hardening | 5-10 engineer-days |

An end-to-end program through full CASM parity is therefore approximately
54-105 engineer-days, with substantial uncertainty concentrated in file error
semantics, REU correctness, DEBUG recovery, and CASM runtime verification.

## 13. Phased Roadmap

### Phase 0: Contract and Measurement

- Freeze the platform facade needed by DEBUG only.
- Measure current segment sizes, BSS, zero page, stack, imports, and artifact
  format.
- Select a standalone fixed origin and launch convention.
- Define restoration and failure contracts.
- Complete an initial provenance review.

Go gate: a standalone target can be added without changing the Command64
artifact's bytes or behavior.

### Phase 1: DEBUG Core Proof of Concept

- Build fixed-origin DEBUG.
- Implement standalone print and exit.
- Disable unsupported REU commands with explicit diagnostics.
- Verify memory, assembler/disassembler, and safe return to BASIC.

Go gate: useful core behavior works and all shared DEBUG tests remain unchanged
under Command64.

### Phase 2: Standalone File Layer

- Specify KERNAL/CBM DOS file contracts.
- Migrate only through adapters.
- Verify DEBUG file operations and error cleanup.

Go gate: deterministic file round trips and no leaked logical files/channels.

### Phase 3: EDLIN RAM Standalone

- Add interactive startup filename/options.
- Reuse the 2 KiB fallback buffer.
- Verify create, load, edit, write, delete/replace, and exit behavior.

Go gate: useful editor operation without REU and unchanged Command64 EDLIN.

### Phase 4: Shared REU Runtime

- Design metadata placement and allocator semantics.
- Implement detection, allocation, free, block transfer, and counters.
- Test exact page, bank, and 64 KiB boundaries.
- Integrate DEBUG first, then EDLIN.

Go gate: no memory corruption across exhaustive bounded transfer tests and
manual hardware/emulator confirmation.

### Phase 5: CASM Standalone Prototype

- Implement command-line and device-prefix adapter.
- Integrate file and REU facades without changing parser/emitter policy.
- Assemble trusted fixtures and compare output byte-for-byte.
- Verify include replay and cleanup invariants.

Go gate: representative Phase 9/10-era workloads fit, produce identical output,
and preserve deterministic cleanup.

### Phase 6: Productization

- Finalize BASIC loaders if desired.
- Establish release naming and version policy.
- Complete provenance/licensing gate.
- Add standalone manuals and release artifacts.
- Run full Command64 and standalone regression matrices.

## 14. Stop Conditions

Pause and re-evaluate if any phase establishes that:

- the Command64 artifact changes merely from introducing the platform boundary;
- the platform ABI duplicates most of Command64 instead of remaining narrow;
- fixed-origin memory leaves insufficient room for core state and runtime;
- EDLIN file behavior cannot match safely without invasive editor changes;
- REU metadata or DMA cannot be made safe under normal ROM/IRQ conditions;
- CASM requires parser/emitter forks rather than service adapters;
- maintaining both variants doubles feature implementation effort in practice;
  or
- licensing/provenance prevents separate distribution.

## 15. Recommendation

Proceed only with a narrowly scoped Phase 0 and DEBUG core proof of concept.
Adopt shared cores plus platform adapters as a non-negotiable architectural
rule. Treat the following as explicit decisions for future planning:

1. Do not create production source forks.
2. Do not start with CASM.
3. Do not require a general REU runtime for the first proof of concept.
4. Preserve existing Command64 artifacts and behavior as the regression
   baseline.
5. Promote code into a shared standalone runtime only after at least two
   applications require equivalent semantics.
6. Require an REU for full standalone CASM unless a later study proves a
   bounded alternative without weakening the product.
7. Complete licensing/provenance review before public standalone release.

The project should approve a separate Phase 0 plan before creating source,
build, fixture, or release artifacts.
