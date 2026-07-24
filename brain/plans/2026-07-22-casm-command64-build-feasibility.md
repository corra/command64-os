---
feature: casm-command64-build-feasibility
created: 2026-07-22
status: research
---

# Feasibility Study: Building Command 64 with CASM

## Purpose

Determine the earliest CASM phase at which work can begin on assembling the
Command 64 kernel and each external application, and distinguish that point
from the later phase required to replace the current production build.

This is a research finding, not an approved migration plan. It does not change
the current KickAssembler or ca65/ld65 build contracts.

## Executive Finding

Meaningful source migration can start after **CASM Phase 6B** is complete.
Phase 6B provides the labels, symbol table, forward references, and two-pass
assembly required by every real Command 64 component. At the time of this
study, only Phase 6B WP26 is complete; WP27-WP31 remain open in
`wiki/tasks/casm.md`.

Phase 6B is only the porting threshold. It is not the production-build
threshold:

- Adapted single-compilation-unit external applications become practical after
  Phase 13, combined with Phase 8 native R6 output.
- Existing multi-file applications can be flattened through Phase 7 after the
  later language features they use are available.
- Low-change builds of the current ca65 modules require a real Phase 18 object
  and linker implementation. Phase 18 is currently only an investigation.
- The KickAssembler kernel needs fixed-layout and image-construction features
  that are not fully covered by any current CASM phase.
- Credible modular CASM self-hosting requires an implemented Phase 18 and the
  Phase 19 stabilization gate.

## Assessment Levels

The phrase "build with CASM" has three materially different meanings.

| Level | Meaning |
|---|---|
| Porting start | CASM can assemble normal labels and program structure, but source conversion and host packaging remain. |
| Adapted CASM build | A CASM-specific source profile can produce a usable native artifact. Source flattening or layout changes are acceptable. |
| Production replacement | CASM reproduces the current source architecture, layout, relocation behavior, and release artifact without relying on the current assembler/linker. |

No component should be described as migrated merely because CASM accepts a
subset of its instructions. Layout, relocation, generated inputs, cleanup,
determinism, and runtime behavior are part of the build contract.

## Relevant CASM Phases

| CASM phase | Required capability |
|---|---|
| Phase 6B | Global labels, symbol table, forward/backward references, two passes, symbolic branches |
| Phase 7 | Multiple ordered source inputs in one global scope; not object modules |
| Phase 8 | Native Command 64 R6 relocation output |
| Phase 9 | Native `.include` handling and deterministic replay |
| Phase 12 | Named constants, current-address expressions, precedence, and expanded arithmetic |
| Phase 13 | Strings, `.res`, `.fill`, `.align`, `.incbin`, and assertions |
| Phase 14 | Local and anonymous labels, if retained by a port |
| Phase 15 | Conditional assembly |
| Phase 16 | Macros |
| Phase 17 | Named/multiple segment investigation; output contract is not yet selected |
| Phase 18 | Native object and linker investigation, potentially a separate `clink` application |
| Phase 19 | Native stabilization and representative multi-file build |

Phase 8 precedes several language phases in the roadmap. Therefore an
application may have R6 output support but still be unable to express its
constants, strings, storage, or segment layout.

## Current Production Build Boundary

The kernel and external applications use different build models.

### Kernel

`src/command64.asm` is assembled by KickAssembler as one imported source graph.
It defines fixed and chained segments, emits a BASIC launcher, selects PETSCII
encoding, and produces the final static kernel PRG.

### External Applications

`add_ca65_app` in `cmake/Ca65.cmake` currently:

1. Generates a build-number include.
2. Assembles each `.s` file into an independent object.
3. Links the objects at `$3400` and `$3500`.
4. Runs `tools/reloc.py` over the two linked images.
5. Produces the final R6 PRG.

CASM Phase 8 can replace the final differential R6 generation with semantic
relocation tracking. It does not replace ca65 object files, ld65 segment
placement, CMake orchestration, build-number generation, `cc1541`, or release
packaging.

## Consolidated Feasibility Matrix

| Component | Current build | Porting start | Earliest adapted CASM build | Current-source production replacement |
|---|---|---:|---:|---:|
| Command 64 kernel | KickAssembler | Phase 6B for isolated routines | Phase 17 plus new fixed-layout work | No current roadmap phase |
| LABEL | ca65/ld65, 1 unit | Phase 6B | Phase 13 + Phase 8 | Phase 18+ |
| COMP | ca65/ld65, 1 unit | Phase 6B | Phase 13 + Phase 8 | Phase 18+ |
| FORMAT | ca65/ld65, 1 unit | Phase 6B | Phase 13 + Phase 8 | Phase 18+ |
| DEBUG | ca65/ld65, 1 unit | Phase 6B audit | Phase 13/14 + Phase 8 | Phase 18+ |
| EDLIN | ca65/ld65, 3 units | Phase 6B | Phase 7 + Phase 13 + Phase 8 | Phase 18+ |
| PACMAN | ca65/ld65, 3 units plus Python generator | Phase 6B | Phase 7 + Phase 13 + Phase 8 | Phase 18+; generator remains |
| CONWAY | ca65/ld65, 2 units with alignment | Phase 6B | Phase 7 + Phase 13 + Phase 8 | Phase 18+ |
| CASM | ca65/ld65, 13+ units | Phase 6B research | Phase 17 after extensive flattening | Phase 18+, accepted at Phase 19 |
| DVORAK | Unwired KickAssembler source | Phase 6B research | Phase 17 plus dialect conversion | Not applicable while unwired |
| VI | Disabled; expected source absent | Not assessable | Not assessable | Not applicable |

`Phase 18+` means only that Phase 18 is the earliest roadmap location that
could own the requirement. It is not a guaranteed delivery phase until the
object format, linker, and acceptance plan are approved and implemented.

## Recommended Migration Order

1. LABEL
2. COMP
3. FORMAT
4. EDLIN
5. PACMAN
6. CONWAY
7. DEBUG
8. CASM self-hosting
9. Command 64 kernel

This order grows one risk class at a time: small single-unit application,
independent native oracle, destructive device operation, flattened modules,
generated source, alignment, large debugger tables and vectors, bootstrap,
then fixed-layout kernel construction.

## Shared External-Application Strategy

All external migrations should use the same staged method.

### Stage 1: Freeze the ca65 Oracle

Record the source revision, generated build number, base and next-page linked
artifacts, final R6 artifact, segment map, relocation offsets, size, and hashes.
Both builds must consume the same version/build values during comparison.

### Stage 2: Create a CASM Source Profile

Do not attempt general ca65 compatibility. Convert only the constructs needed
by the application:

- replace `.import __MAIN_START__` and linker-generated header handling;
- replace or remove named segment directives;
- consume CASM-compatible constants and generated build data;
- preserve private zero-page allocations exactly;
- use explicit, documented PETSCII bytes or CASM's frozen string encoding;
- replace BSS assumptions with an approved reservation/initialization model;
- retain assertions for memory extent and table sizes.

Keep the ca65 source authoritative until the candidate passes all gates.

### Stage 3: Establish Static Parity

Assemble at `$3400` and compare the candidate with the ca65 base-linked image
before introducing native R6 output. Every difference must be explained by an
approved source-layout or metadata change.

### Stage 4: Establish R6 Equivalence

After Phase 8, compare:

- PRG load address;
- program bytes;
- relocation offsets and order;
- base address;
- relocation count;
- `R6` footer;
- total length and hash.

Load the candidate at several page-aligned addresses. A successful load at one
address is not sufficient evidence of relocation correctness.

### Stage 5: Runtime and Promotion

Run the component-specific walkthrough, verify repeated shell return and
resource cleanup, then promote the reviewed artifact through a separately
approved native-to-host artifact workflow. Do not make CASM responsible for
D64 construction or release packaging.

## LABEL Migration

### Recommendation

Use LABEL as the first migration candidate. It is one translation unit, small,
and has sharply bounded drive-command behavior.

### Prerequisites

- Completed Phase 6B.
- Phase 8 R6 output.
- Phase 9 if includes are retained.
- Prefer Phase 13 for initialized reservation support.
- Frozen PETSCII treatment for drive command bytes.

### Source Adaptation

- Convert `src/external/label/label.s` and its `common.inc` into one CASM source
  profile or consume the include after Phase 9.
- Replace generated `.define` version data with an immutable CASM build input.
- Replace `HEADER`/`CODE` and `__MAIN_START__` handling with CASM output policy.
- Preserve `statusBuf: .res 40, 0` and `labelBuf: .res 16, $A0` semantics.
- Preserve explicit shifted-PETSCII drive-command bytes exactly.

### Validation

- Compare static bytes with the ca65 `$3400` image.
- Compare relocation sites, especially all `<symbol`/`>symbol` references.
- Rename a disposable disk and verify with `VOL`.
- Test overlong labels, cancellation, unavailable device, and write protection.
- Confirm `CurrentDevice` and all handles are restored on every exit.

### Primary Risks

- PETSCII translation can silently corrupt drive commands.
- Initialized reservation semantics can alter emitted size or startup state.
- False relocation entries in protocol data can produce device-only failures.

## COMP Migration

### Recommendation

Migrate COMP second and retain the ca65 COMP as an independent test-only oracle
through at least one later migration.

### Prerequisites

- Completed Phase 6B.
- Phase 8 R6 output.
- Prefer Phase 13 for strings and reservations.

### Source Adaptation

- Convert `src/external/comp/comp.s` and `common.inc` to the CASM profile.
- Replace generated definitions, linker symbols, and segment directives.
- Convert message strings using frozen PETSCII semantics.
- Preserve the two filename buffers, two comparison buffers, and the private
  16-byte zero-page contract.

### Validation

Use fixed file pairs covering:

- identical empty, short, 64-byte, and multi-block files;
- mismatches at offset zero and across a chunk boundary;
- exactly ten and more than ten mismatches;
- different file lengths;
- missing files, malformed CLI, and cleanup failures.

Verify 24-bit mismatch offsets and both file-handle cleanup paths. Do not accept
the candidate solely because it reports that its own output matches.

### Primary Risks

- Self-validation creates a common-mode oracle failure.
- EOF/carry handling is sensitive to the OS file-service contract.
- Changing BSS into emitted storage changes artifact layout.

## FORMAT Migration

### Recommendation

Wait for Phase 13 before implementation even though syntax conversion can be
investigated after Phase 6B. Numericizing its strings and 177-byte state record
earlier would create a brittle port.

### Prerequisites

- Completed Phase 6B.
- Phase 8 R6 output.
- Phase 12 constants and arithmetic.
- Phase 13 strings and reservations.

### Source Adaptation

- Convert `src/external/format/format.s` and `common.inc`.
- Preserve expressions such as indexed `symbol - 1` accesses.
- Preserve command, name, ID, response, and confirmation buffer bounds.
- Preserve the private `$70-$72` zero-page allocation.

### Validation

Complete non-destructive validation before contacting a drive:

- malformed CLI;
- device outside 8-11;
- invalid name and ID lengths;
- cancellation and failed retyped-name confirmation;
- proof that invalid requests issue no drive command.

Then use only a disposable image to verify successful format, directory name
and ID, empty directory, actual drive status, and transport failure.

### Primary Risks

- Runtime verification is destructive.
- Encoding differences can alter the DOS command or disk metadata.
- Parser differences could bypass confirmation.

## DEBUG Migration

### Recommendation

Migrate DEBUG last among the existing non-self-hosted applications. Begin a
capacity and syntax audit after Phase 6B, but do not implement the full port
until Phase 12/13 and Phase 8 have been proven by smaller applications.

### Prerequisites

- Completed and hardened Phase 6B.
- Phase 8 proven by multiple migrated tools.
- Phase 12 expressions and constants.
- Phase 13 strings, reservations, fills, and assertions.
- Phase 14 if retaining local labels is preferable to global renaming.
- Measured source and symbol capacity; the planned 512-symbol table may be a
  blocker.

### Source Adaptation

- Convert `src/external/debug/debug.s` without sharing DEBUG's parser with CASM;
  their input and output contracts differ.
- Preserve all opcode, addressing-mode, and instruction-length tables.
- Preserve BRK-vector, breakpoint, stack-frame, and self-modifying-code
  behavior.
- Audit all labels against CASM limits and all branches against final spans.
- Replace linker sections and initialized reservations without moving data
  across assumptions embedded in debugger code.

### Validation

1. Measure source bytes, symbols, label lengths, branch spans, and relocation
   candidates.
2. Obtain parse-only acceptance.
3. Obtain static byte parity.
4. Verify opcode metadata independently rather than using DEBUG as its own
   oracle.
5. Verify dump, enter, fill, move, compare, search, registers, and file I/O.
6. Verify disassembly and inline assembly across all addressing modes.
7. Verify trace/proceed, BRK cleanup, and repeated shell return at multiple
   relocation pages.
8. Complete `wiki/debug-test-plan.md`.

### Primary Risks

- Source or symbol capacity may exceed Phase 6B limits.
- One missing or false R6 entry can corrupt vectors, pointers, or opcode data.
- DEBUG can overwrite its own relocated image during memory tests.
- BRK/RTI and stack defects may only appear after relocation.

## EDLIN Migration

### Recommendation

Use EDLIN as the first Phase 7 flattened multi-input candidate. Its three
modules exchange ordinary labels and do not require independent distribution.
Do not wait for Phase 18 unless preserving object boundaries becomes an
explicit requirement.

### Prerequisites

- Completed Phase 6B.
- Phase 7 ordered inputs.
- Phase 8 R6 output.
- Phase 9 shared includes or an equivalent constants input.
- Phase 13 reservation support.

### Source Adaptation

Treat `edlin.s`, `buffer.s`, and `cmds.s` as one ordered global compilation
unit. Remove `.import`/`.export` declarations while preserving a documented
module-interface manifest. Preserve the `$70-$8F` zero-page map, 16 KB VMM
buffer, 2 KB fallback, source ordering, and all shared state contracts.

Define whether BSS-like reservations are emitted zeroes or guaranteed-clear
runtime storage. Do not rely on ca65/ld65 BSS behavior implicitly.

### Validation

- Compare entry, extent, R6 table, and relocation-normalized bytes.
- Verify load, list, page, insert, edit, delete, write, and quit.
- Verify the 16 KB limit and no-REU fallback.
- Verify physical-drive close and save behavior.
- Confirm deterministic repeated assembly.

### Primary Risks

- Flattening removes import/export enforcement.
- Source order becomes part of the build contract.
- BSS conversion can change artifact size and startup state.

## PACMAN Migration

### Recommendation

Flatten PACMAN after EDLIN. Retain `autotile.py` as the authoritative generator;
CASM should consume its generated assembly data, not reproduce maze topology.

### Prerequisites

- Completed Phase 6B.
- Phase 7 ordered inputs.
- Phase 8 R6 output.
- Phase 12 parenthesized arithmetic and extraction expressions.
- Phase 13 strings and reservations.

### Source Adaptation

- Combine `pacman_main.s`, `pacman_game.s`, and `pacman_ai.s` into an ordered
  global compilation unit while preserving physical files if Phase 7 permits.
- Replace imports/exports with a checked interface manifest.
- Preserve the private zero-page map, 672-byte item grid, actor arrays, timers,
  tables, and `$2800` application envelope.
- Prefer changing `autotile.py` eventually to emit a dedicated generated CASM
  source input rather than rewriting a handwritten module, but do not make that
  cleanup a prerequisite for the first build.

### Validation

- Run `autotile.py --check` before and after assembly.
- Verify repeated generation is idempotent.
- Compare generated maze bytes with the ca65 artifact.
- Run the independent maze reachability check.
- Verify rendering, collision, tunnels, ghost-house transitions, scheduling,
  score/lives, level reset, and shell return.

### Primary Risks

- The host generator remains outside CASM and must be represented honestly in
  any self-build claim.
- Flattening removes module-interface diagnostics.
- Large mutable state and tables increase layout and relocation risk.

## CONWAY Migration

### Recommendation

Flatten CONWAY only after CASM `.align` behavior is mature. Its two-object
structure is simple; page alignment is the real migration risk.

### Prerequisites

- Completed Phase 6B.
- Phase 7 ordered inputs.
- Phase 8 R6 output.
- Phase 12 arithmetic.
- Phase 13 `.align`, `.res`, strings, and assertions.

### Source Adaptation

- Combine `conway_main.s` and `conway_grid.s` as one ordered unit.
- Preserve both 960-byte grids and their independent 256-byte alignment.
- Reproduce compile-time bounds assertions and screen-code semantics.
- Preserve the current zero-page and application envelope contracts.

### Validation

- Prove `.align 256` calculates identical padding in both passes.
- At every supported load page, verify `grid0 & $FF == 0` and
  `grid1 & $FF == 0`.
- Ensure both grids remain inside the emitted application extent.
- Verify all presets, custom rules, pause, randomize, clear, generation count,
  toroidal edges, menu return, and shell return.

### Primary Risks

- Alignment can be correct at one origin and fail after relocation.
- BSS versus emitted-buffer treatment changes both size and initialization.
- Character encoding affects fixed-width status output.

## CASM Self-Hosting

### Recommendation

Treat self-hosting as a separate bootstrap and toolchain project. Keep ca65/ld65
as the trusted Stage 0 path until native builds converge and Phase 19 is
approved.

CASM currently consists of at least 13 translation units and relies heavily on
imports/exports, zero-page symbol typing, segments, generated includes,
reservations, assertions, and complex expressions. A flattened Phase 17 build
may be useful as a diagnostic bootstrap, but it is not equivalent to the
current modular build.

### Bootstrap Stages

1. **Trusted host seed:** pin commit, source hashes, generated include, maps,
   base/next artifacts, R6 offsets, and final hash.
2. **Native language:** complete Phases 6B-8 and prove multi-file/R6 fixtures.
3. **Source intake:** complete Phase 9 includes and deterministic replay.
4. **Bootstrap source profile:** implement the required Phase 12/13 subset,
   including constants, expressions, strings, `.res`, and assertions.
5. **Segment layout:** complete Phase 17 contracts for HEADER, CODE, RODATA,
   DATA, BSS, alignment, envelope checking, and linker-generated symbols.
6. **Objects and linker:** implement Phase 18, preferably as versioned objects
   plus a separate `clink` application.
7. **Bootstrap convergence:** build CASM and CLINK through successive native
   generations until the second and third generations are byte-identical.
8. **Pipeline qualification:** compare host and native paths without replacing
   the authoritative target until Phase 19 acceptance.

### Object/Linker Requirement

R6 is a final loader relocation format, not an object format. It cannot encode
unresolved imports, arbitrary segment placement, low-byte fixups, branch
resolution, or linker expressions. Genuine modular self-hosting requires typed
object fixups and deterministic segment merging.

Recommended architecture:

```text
CASM source -> versioned C64 object files
CLINK objects + link description -> static or R6 PRG
```

### Build-Number Boundary

The assembler must not own persistent build-number mutation. The surrounding
orchestrator should compute the source hash and build value, then provide CASM
an immutable input. Host and native equivalence builds must consume the same
value.

### Acceptance

- Native and ld65 segment maps match.
- Every import resolves to the same address.
- BSS affects address assignment and envelope checks but not serialized bytes.
- Native `$3400` and `$3500` links have equal lengths and expected deltas.
- Direct native R6 output matches the host artifact field by field.
- Second- and third-generation native CASM artifacts are byte-identical.
- A clean-machine host bootstrap remains documented and operational.
- The user completes the Phase 19 runtime and resource walkthrough.

### Primary Risks

- Circular bootstrap dependency.
- Confusing final R6 relocation with object fixups.
- Expanding CASM into incomplete general ca65 compatibility.
- Segment, BSS, or character-encoding mismatch.
- Non-determinism from symbol iteration, directory order, VMM contents, or
  uninitialized state.
- CASM memory pressure; the linker should remain a separate application.

## Command 64 Kernel Migration

### Recommendation

Do not attempt direct KickAssembler compatibility. Create a portable kernel
source profile and retain KickAssembler as the authoritative path throughout
the migration.

Isolated routine conversion can start after Phase 6B. A complete adapted build
requires Phase 17 concepts plus new fixed-layout and image-construction work
not present in the roadmap.

### Current Layout Contract

`src/command64.asm` defines:

- BASIC launcher at `$0801`;
- packed utility, API, loader, path, VMM, and file regions;
- API stub fixed at `$1000`;
- PETSCII, command table, and shell regions;
- VMM data fixed at `$1FA0`;
- application table fixed at `$2000`;
- later shell extensions packed after the application table.

The source also uses `#import`, `.segmentdef`, `startAfter`, `.file`,
`BasicUpstart2`, `.encoding "petscii_mixed"`, Kick-style constants, `.text`,
compile-time string concatenation, and a brace-style macro.

### Portable Source Strategy

For the first proof, avoid general named segments and serialize one checked
linear image in final-address order:

```text
$0801 BASIC launcher
packed low kernel regions
padding to $1000
API stub
packed shell regions
padding to $1FA0
VMM data
application table
shell extensions
```

This requires reorganizing interleaved `ShellExt` sections but avoids making
the first proof depend on an unresolved Phase 17 container format.

Replace Kick-specific facilities as follows:

- emit the BASIC launcher explicitly;
- use CASM includes or ordered inputs instead of `#import`;
- use named constants from Phase 12;
- use current-address assertions and checked padding;
- replace the one macro with ordinary code or a subroutine;
- emit version strings as explicit fragments under frozen PETSCII rules;
- define every ABI address once and assert it.

### New CASM Work Required

The current roadmap should not absorb these requirements silently. A future
approved kernel-build track needs:

1. A portable kernel source profile.
2. Current-PC padding and fixed-address assertions.
3. Frozen PETSCII text semantics.
4. Large native compilation qualification.
5. Checked fixed islands or an approved absolute-segment model.
6. Defined gap-fill, overlap, backward-placement, and overflow behavior.
7. Dialect-neutral generated version/configuration inputs.
8. Native source-device and output orchestration.
9. A host integration/bootstrap decision if CASM is to replace KickAssembler
   in `cmake --build`.

### Proof-of-Concept Sequence

1. Freeze a KickAssembler kernel artifact and segment manifest.
2. Build a synthetic CASM fixture containing the `$0801`, `$1000`, `$1FA0`,
   and `$2000` layout pattern.
3. Prove checked padding, launcher bytes, PETSCII strings, and deterministic
   output.
4. Create the portable kernel profile while sharing routine bodies where
   practical.
5. Assemble one static `command64.prg` natively without maps, listings, R6, or
   object files.
6. Compare bytes and every fixed ABI address.
7. Run the complete kernel manually while KickAssembler remains authoritative.
8. Add a dual-build parity target only after sustained native success.

### Acceptance

- Load address is `$0801` and the launcher reaches `start`.
- API stub remains at `$1000`.
- VMM data remains at `$1FA0-$1FFF`.
- Application table remains at `$2000`.
- Every fixed boundary is asserted and no segment overlaps or wraps.
- Command names and messages retain exact PETSCII bytes.
- Output is byte-identical except explicitly frozen build metadata.
- Missing source, disk full, I/O failure, and VMM exhaustion preserve the last
  bootable artifact and release all resources.
- The existing CMake/KickAssembler release build remains operational until a
  separate production-toolchain decision is approved.

### Primary Risks

- CASM runs on the OS services supplied by the kernel it is rebuilding.
- Flattening named segments can silently change addresses.
- Build/configuration includes are currently generated in Kick syntax.
- Full-kernel source, symbols, output, and pass time may exceed current limits.
- A native build failure must never overwrite the last bootable kernel.
- Host replacement would require emulator automation, a host CASM port, or a
  checked-in bootstrap artifact, each of which is a separate product decision.

## Non-Production Sources

### DVORAK

`src/external/dvorak/dvorak.asm` is deliberately excluded from CMake because of
known fundamental problems. A future rewrite could be investigated after
Phase 6B and would likely need Phase 17-era layout plus Kick-dialect conversion.
There is no current production artifact to replace.

### VI

The expected VI source is absent and its target is disabled in `CMakeLists.txt`.
No phase assessment is possible until a source and build contract exist.

### Oscar64 Programs

No current C sources are discovered under `src/`. CASM does not replace a C
compiler and should not be included in an Oscar64 migration assessment.

## Cross-Cutting Acceptance Gates

Every migration should satisfy these gates before the current assembler target
is retired:

1. **Pinned baseline:** source revision, generated inputs, maps, relocation
   manifest, and hashes are recorded.
2. **Language:** every used CASM syntax form has positive and negative tests.
3. **Capacity:** source, symbols, output, VMM, stack, zero page, and handles fit
   measured bounds.
4. **Static parity:** bytes match the trusted base artifact or every difference
   is reviewed.
5. **Relocation:** R6 entries are independently validated and run at several
   page-aligned addresses.
6. **Encoding:** PETSCII and screen-code bytes match the existing behavior.
7. **Determinism:** repeated native builds produce identical output.
8. **Failure cleanup:** partial outputs, handles, and VMM allocations are
   cleaned without destroying the prior good artifact.
9. **Runtime:** the component walkthrough passes and repeated shell return is
   safe.
10. **Recovery:** the established host build remains available until a separate
    bootstrap/release decision is approved.

## Decision Summary

- Complete CASM Phase 6B before starting implementation migrations.
- Use LABEL as the first production-component experiment.
- Require Phase 8 for every deployable external application.
- Treat Phase 13 as the practical language floor for maintainable application
  ports.
- Use Phase 7 flattening for EDLIN, PACMAN, and CONWAY rather than blocking all
  three on a speculative linker.
- Implement Phase 18 only when preserving modules or self-hosting becomes the
  explicit goal.
- Accept CASM self-hosting only through Phase 19 convergence and runtime gates.
- Treat the kernel as a separate fixed-layout project after Phase 17; no current
  CASM phase is sufficient for faithful production replacement.

## Evidence Sources

Primary sources used for this study:

- `brain/plans/2026-07-16-casm-assembler-implementation-plan.md`
- `wiki/tasks/casm.md`
- `wiki/casm-programmers-reference.md`
- `CMakeLists.txt`
- `cmake/Ca65.cmake`
- `cmake/KickAssembler.cmake`
- `src/command64.asm`
- `src/command64/*.asm`
- `src/external/debug/debug.s`
- `src/external/label/`
- `src/external/format/`
- `src/external/comp/`
- `src/external/edlin/`
- `src/external/conway/`
- `src/external/pacman/`
- `src/external/casm/`
- `wiki/debug-test-plan.md`
- `wiki/label-utility.md`
- `wiki/tasks/format.md`
