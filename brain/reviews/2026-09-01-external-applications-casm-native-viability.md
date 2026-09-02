# External Applications: CASM-Native Viability Review

Date: 2026-09-01
Status: Read-only assessment; no migration authorized

## Purpose

Assess every application under `src/external/` for viability as a native-CASM
application: source assembled by CASM under Command64, reviewed on the C64/VICE
path, and shipped from a checked-in hex manifest. This is not an implementation
plan and does not activate migration work.

The approved canonical-byte-oracle transition remains implementation-deferred:
`brain/plans/2026-09-01-casm-canonical-byte-oracle-transition.md`.

## Executive Summary

| Application | Current state | CASM-native viability | Migration effort |
| --- | --- | --- | --- |
| BANNER | CASM-native | Proven | Complete |
| DASH | CASM-native with ca65 differential | Proven | Complete/active |
| LABEL | ca65/ld65 | High | Low |
| COMP | ca65/ld65 | High | Moderate |
| FORMAT | ca65/ld65 | High | Moderate |
| CONWAY | ca65/ld65 | High | Moderate |
| EDLIN | ca65/ld65 | Conditional | High |
| PACMAN | ca65/ld65 | Blocked by prerequisites | Very high |
| DEBUG | ca65/ld65 | Blocked by prerequisites | Very high |
| DVORAK | Parked, not built | Product redesign required | High |
| CASM | ca65/ld65 | Self-hosting deferred | Very high |
| VI | No source/target | Not assessable | N/A |

Recommended migration order:

1. LABEL
2. COMP
3. FORMAT
4. CONWAY
5. EDLIN, after source-budget and flat-layout proof
6. PACMAN and DEBUG, after separate prerequisite feasibility work
7. DVORAK only after architectural redesign

CASM self-hosting should remain a separate future effort. VI has only
`src/external/vi/BUILD_VI`; there is no source or active target to assess.

## Governing CASM Constraints

### Combined source size

CASM stores all top-level and included source in one bounded VMM source store.
The combined cap is 65,535 bytes (`src/external/casm/common.inc:1468`). Splitting
a program into more `.INCLUDE` files does not evade this limit.

Measured checked-in application source totals:

| Application | Approximate source bytes | Disposition |
| --- | ---: | --- |
| LABEL | 11,424 | Comfortable |
| FORMAT | 16,500 | Comfortable |
| COMP | 10,070 | Comfortable |
| CONWAY | 35,441 | Comfortable |
| EDLIN | 62,309 | Only 3,226 bytes of headroom |
| PACMAN | 76,046 | 10,511 bytes over cap |
| DEBUG | 93,251 | 27,716 bytes over cap |
| DVORAK | 8,702 | Comfortable, but architecture blocks shipping |

These totals describe current maintainable sources, not a final packaged
CASM-safe source set. Native constants, wrappers, or generated inputs consume
the same cap.

### Symbol and relocation capacity

CASM supports 512 symbols (`src/external/casm/common.inc:1398`) and 4,096 R6
relocation entries (`src/external/casm/common.inc:435`). Existing relocation
counts observed in host-built artifacts are well below the R6 limit, including
CONWAY at 182 and PACMAN at 505. DEBUG and PACMAN still require explicit symbol
and relocation ledgers before migration because of their scale.

### Flat source and output model

CASM performs one textual assembly with one symbol table. It is not an object
linker and does not implement ca65 `.IMPORT`, `.EXPORT`, or linker segments.
Applications must use one ordered source/include graph and one linear emitted
image.

CASM normally emits R6-relocatable output at implicit base `$3400`. Current
ca65 external applications are linked at the current `UserProgStart`, `$3800`.
A byte comparison is meaningful only when both references use the same base or
when relocation and framing are normalized structurally.

### Source encoding

The proven native packaging path writes host files to D64 SEQ files verbatim.
Native-CASM source must therefore be uppercase ASCII throughout, including
comments and literals, as required by `src/external/AGENTS.md` and enforced by
`scripts/check_casm_source_bytes.py`.

Lowercase ca65 source cannot simply be packaged unchanged. Whole-file casing
also requires a collision audit because identifiers distinguished only by case
collapse. DEBUG already contains a real example: shared `ParsePos` and private
`parsePos`.

### PETSCII and string semantics

The ca65 build uses its C64 target character mapping. CASM emits character and
string source bytes according to its documented native semantics. Character
and string literals must therefore be audited; syntax accepted by both tools
does not guarantee identical bytes.

Drive commands, keyboard bytes, screen codes, and other protocol data should
prefer explicit reviewed numeric bytes. User-facing strings require canonical
expected-byte derivation rather than assuming ca65 output defines CASM
correctness.

### Build and provenance model

Native CASM is not a host executable invoked during the ordinary CMake build.
The established model, documented in `src/external/AGENTS.md`, is:

1. Package CASM, the application source, and required assets on a dedicated
   disk image.
2. Boot Command64 and assemble through native CASM.
3. Extract and independently review the PRG and R6 structure.
4. Capture approved native bytes in a checked-in hex manifest.
5. Reconstruct the production PRG from the manifest during normal builds.
6. Bind the manifest to source hashes so stale source fails the build.

Every migration also needs a native-compatible version/build-number strategy;
the current ca65 `.DEFINE` and generated `build_<app>.inc` mechanism is not
directly available on the C64 assembly disk.

## Detailed Findings

### BANNER

Disposition: **proven CASM-native**.

BANNER already follows the native manifest model. It has no ca65 build or
differential reference. Its current architecture is the simplest precedent for
single-file applications.

The canonical-byte-oracle transition must eventually add an independently
derived/reviewed correctness record. The native manifest proves artifact
provenance and reproducibility, but native output alone is circular as an
expected-byte oracle.

### DASH

Disposition: **proven CASM-native**.

DASH already uses a seven-file ordered `.INCLUDE` graph, native R6 output,
source-hash-bound shipping manifest, and runtime relocation verification. Its
ca65 `dash_ref` target is an independent differential implementation, not the
source of current shipping bytes.

The approved deferred oracle transition will eventually make that differential
optional and remove the load-bearing requirement that DASH remain inside the
ca65/CASM syntax intersection. No change is authorized while DASH and CASM are
under active development.

### LABEL

Disposition: **high viability; recommended pilot**.

Evidence:

- Single implementation file plus a small constants include.
- Current ca65 target: `CMakeLists.txt:198-209`.
- No true linker BSS and no inter-object imports/exports.
- Current source uses ordinary code, labels, fixed OS/KERNAL addresses, and
  emitted `.RES` storage.
- Existing shipping artifact is small (approximately 956 bytes including R6).

Required work:

- Remove `.SEGMENT`, `.IMPORT __MAIN_START__`, manual header, `.DEFINE`, and
  generated ca65 build include.
- Provide CASM-safe OS/application constants and version data.
- Convert the complete source to uppercase CASM-safe bytes.
- Audit character/string literals and preserve explicit drive-command bytes.
- Assemble as native R6, derive a canonical oracle, review relocation entries,
  and verify runtime behavior.

No architectural blocker was found. LABEL is the best pilot because it tests
the complete native application workflow without first requiring module, BSS,
alignment, or source-cap redesign.

### COMP

Disposition: **high viability with one explicit layout decision**.

Evidence:

- Single implementation file plus a small constants include.
- Current ca65 target: `CMakeLists.txt:240-248`.
- Straightforward file-I/O and comparison logic.
- Existing shipping artifact is approximately 1,020 bytes including R6.
- No inter-object linkage.

Primary issue:

`src/external/comp/comp.s:500-509` places 208 bytes of filename/chunk buffers in
a true ld65 BSS segment. Those bytes occupy runtime memory but are absent from
the current PRG. CASM has no un-emitted BSS; `.RES` emits fill bytes.

The simplest native design is likely to append explicit zero-filled storage,
increasing the PRG by approximately 208 bytes. This is a deliberate artifact
layout change, so byte identity with the old ca65 file is not an appropriate
completion condition. Correctness instead requires an independently derived
new layout and runtime proof.

Alternative VMM/fixed-memory buffer designs are possible but add unnecessary
runtime coupling unless another requirement justifies them.

### FORMAT

Disposition: **high viability; moderate conversion and verification risk**.

Evidence:

- Single implementation file plus a small constants include.
- Current ca65 target: `CMakeLists.txt:227-238`.
- No inter-object linkage or true BSS; current `.RES` buffers are emitted.
- Existing shipping artifact is approximately 1,865 bytes including R6.

Primary risks:

- The source is larger and string-heavy relative to LABEL and COMP.
- It constructs the CBM DOS `N:name,id` command dynamically. PETSCII command
  bytes must be frozen explicitly; ca65 character mapping cannot be assumed.
- Destructive formatting behavior requires controlled VICE and, where
  appropriate, hardware verification beyond a byte comparison.

No language, source-size, symbol, relocation, or memory architecture blocker
was found.

### CONWAY

Disposition: **high viability; recommended first multi-module migration**.

Evidence:

- Current ca65 target: `CMakeLists.txt:427-440`.
- Combined source is approximately 35,441 bytes, comfortably below CASM's cap.
- Current host artifact has 182 relocation entries, well below CASM capacity.
- Mutable grids are already emitted in CODE rather than true linker BSS.

Required work:

- Replace ca65 object imports/exports with one ordered textual include graph.
- Remove segments, linker header, generated definitions, and ca65-only source
  machinery.
- Replace ca65 screen-code macros (`.MACRO`, `.CHARMAP`, `.REPEAT`) with
  canonical numeric byte data.
- Preserve two 960-byte grid buffers and their required 256-byte alignment.
- Verify exact alignment and padding at CASM's `$3400` reference base.
- Derive and review the R6 relocation ledger and test multiple load addresses.

CONWAY is more involved than FORMAT but has no fundamental blocker. It is the
best candidate for proving module flattening, aligned emitted storage, and
larger relocation-ledger review.

### EDLIN

Disposition: **conditionally viable; high-risk migration**.

Evidence:

- Current ca65 target: `CMakeLists.txt:211-225`.
- Four source/include files total approximately 62,309 bytes.
- EDLIN uses three linked modules with extensive imports and exports.
- `src/external/edlin/buffer.s:761-774` includes a 2,048-byte no-REU fallback
  buffer plus other true BSS storage.

Blockers requiring design proof:

1. Source has only approximately 3,226 bytes of CASM headroom before conversion.
   A full shared OS include would likely exceed the cap.
2. ca65 modules must become one textual assembly and one global namespace.
3. CODE, RODATA, and BSS sections must be deliberately reordered into one flat
   image.
4. Converting true BSS to emitted `.RES` adds more than 2 KiB to the PRG and
   may affect the external-application memory envelope.
5. The no-REU fallback must remain functional after layout conversion.

Required viability gates before a migration plan:

- Produce a source-budget projection with meaningful growth headroom.
- Freeze the exact flat code/data/storage order and loaded end address.
- Decide whether fallback storage is emitted, externalized, or redesigned.
- Count symbols and derive relocation capacity.
- Preserve explicit PETSCII data and verify all command parsing.

### PACMAN

Disposition: **not presently assemblable; viable only after substantial
prerequisite work**.

Evidence:

- Current ca65 target and generator dependency: `CMakeLists.txt:484-497`.
- Combined source is approximately 76,046 bytes, 10,511 over CASM's hard cap.
- The source contains extensive ca65 anonymous labels (`:`, `:+`, `:-`), which
  current CASM does not support.
- It is a three-object application with imports/exports and separate CODE,
  RODATA, and BSS sections.
- `src/external/pacman/pacman_game.s` contains generator-owned maze data under
  `src/external/pacman/autotile.py` control.
- Current host output has approximately 505 relocation entries.

Prerequisite effort:

1. Reduce packaged source below 65,535 bytes with several KiB of headroom.
2. Rewrite anonymous labels as reviewed `@local` or ordinary labels.
3. Audit every `@local` scope against CASM's current scope rules.
4. Flatten modules and design a linear storage layout.
5. Decide whether generated maze data remains generated source or becomes a
   reviewed `.INCBIN` asset; preserve `autotile.py` ownership and checks.
6. Replace keyboard character literals with explicit PETSCII values.
7. Reconcile approximately 700 bytes of true BSS becoming emitted storage or
   design an alternative.
8. Derive and review the larger R6 relocation ledger.

PACMAN should not enter a syntax-conversion phase until source-budget and
anonymous-label prototypes pass.

### DEBUG

Disposition: **not presently assemblable; source-compaction proof required**.

Evidence:

- Current ca65 target and memory envelope: `CMakeLists.txt:187-196` and
  `src/external/debug/AGENTS.md:36-41`.
- Monolithic source is approximately 93,251 bytes, 27,716 over CASM's cap.
- DEBUG contains extensive character/string data tied to ca65's C64 mapping.
- Uppercase conversion creates at least one real symbol collision:
  `ParsePos` versus private `parsePos` (`src/external/debug/debug.s:174`).
- DEBUG's storage is already emitted in CODE, which is more favorable than
  EDLIN's BSS arrangement.

Required viability gates:

1. Demonstrate a complete maintainable CASM-safe source below 65,535 bytes,
   including its constants, with useful growth headroom.
2. Audit and rename all uppercase-colliding identifiers.
3. Count symbols against CASM's 512-entry limit.
4. Count and derive relocation entries against the 4,096-entry limit.
5. Preserve DEBUG's loaded end below `$5C00` and never above the documented
   `$6000` fixture boundary.
6. Replace or explicitly encode all parser, mnemonic-table, help, and status
   text bytes.
7. Replace tests that depend on ca65-exported internal routines, if any, with
   native-compatible harness boundaries.

DEBUG is structurally simpler than EDLIN because it is monolithic and does not
use true BSS, but its source-size and encoding burden make it the larger risk.

### DVORAK

Disposition: **not a current shipping candidate; architecture before syntax**.

CMake deliberately leaves DVORAK unwired (`CMakeLists.txt:150-152`). The source
is small enough for CASM, but it:

- installs persistent state/routine bytes at fixed `$CE00` without an OS memory
  reservation mechanism;
- risks later applications overwriting that resident area;
- contains a documented malformed resident routine/branch behavior;
- uses KickAssembler syntax and two source origins;
- does not satisfy the normal relocatable external-application ownership model.

A CASM migration cannot solve these product defects. A future effort must first
choose an OS-managed resident-memory model or redesign DVORAK as nonresident,
correct the routine contract, and define safe install/uninstall/vector
ownership. Only then should its installer be rewritten as one CASM source with
fixed numeric resident destinations and relocatable installer code.

### CASM Self-Hosting

Disposition: **defer as a separate bootstrap project**.

CASM is itself a ca65/ld65 external application (`CMakeLists.txt:250` onward).
Native external applications do not require CASM to assemble itself. A
self-hosting effort would introduce bootstrap provenance, conversion of CASM's
own ca65-only syntax, likely source-cap work, and a requirement to prove that a
CASM-built CASM reproduces the approved assembler behavior.

This should not be bundled into ordinary external-application migrations.

### VI

Disposition: **not assessable**.

`src/external/vi/` contains only `BUILD_VI`; `CMakeLists.txt:499-500` retains a
commented target, but no source exists. There is no implementation to migrate.

## Cross-Application Migration Prerequisites

Before the first migration begins, establish or explicitly plan:

1. A minimal CASM-safe OS/API constants source, avoiding wholesale inclusion of
   lowercase ca65 headers and unnecessary source-cap consumption.
2. A native-compatible version/build-number workflow that preserves the
   persistent `BUILD_<APP>` contract or replaces it through an approved durable
   contract.
3. Canonical independent byte/R6 derivation and peer-review procedures from the
   approved deferred oracle-transition plan.
4. A standard disposition for true linker BSS: emitted `.RES`, external
   storage, VMM allocation, or an app-specific alternative.
5. PETSCII classification for command bytes, keyboard input, screen codes, and
   user-facing strings.
6. A dedicated native-assembly test disk, source-hash stale-artifact gate, and
   reviewed manifest tool for each migrated application.
7. Same-base or structurally normalized comparison against any optional ca65
   differential artifact.
8. R6 relocation-ledger review and runtime verification at multiple load
   addresses.
9. Application-specific functional verification under Command64, following
   `.agents/workflows/vice-mcp-testing.md`.
10. A separate approved Phase/WP plan before changing any application.

## Recommended Program

### Stage 1: Pilot

Migrate LABEL first. It establishes the constants, versioning, manifest,
canonical-oracle, relocation, and runtime workflow with the smallest source and
fewest layout variables.

### Stage 2: Storage and protocol cases

Migrate COMP to establish an explicit true-BSS disposition. Then migrate FORMAT
to validate PETSCII-sensitive DOS command construction and destructive-command
verification.

### Stage 3: Multi-module case

Migrate CONWAY to prove textual module flattening, generated numeric display
data, page alignment, larger emitted storage, and a larger relocation ledger.

### Stage 4: Conditional large applications

Reassess EDLIN after the preceding migrations establish shared native
infrastructure. Begin only with source-budget, flat-layout, and fallback-buffer
proofs.

PACMAN and DEBUG require independent prerequisite feasibility efforts before a
migration plan. Passing those prerequisites establishes viability; it does not
automatically authorize implementation.

DVORAK requires product architecture work rather than an assembler-port plan.
CASM self-hosting remains separate. VI remains out of scope until source exists.

## Review Limitations

- Source-byte totals were measured from the current checked-in files and will
  change as active CASM/DASH/application work proceeds.
- Some symbol counts were estimated structurally rather than proven through a
  complete CASM lexical inventory; blocked/high-risk applications require exact
  counts in their feasibility gates.
- Existing ca65 relocation counts establish scale, not CASM correctness. Native
  CASM classifies relocation independently and requires its own reviewed ledger.
- No live VICE tests were required or run because this review made no source or
  artifact changes.
- No migration task was activated and no application was marked complete.

## Conclusion

CASM is mature enough to be the implementation assembler for several external
applications now, but migration suitability varies substantially. LABEL, COMP,
FORMAT, and CONWAY are viable with bounded, understandable ports. EDLIN is
viable only after source and flat-memory design proof. PACMAN and DEBUG exceed
CASM's current source capacity and need prerequisite work. DVORAK's blocker is
unsafe product architecture, not assembler capability. BANNER and DASH remain
the proven native precedents.
