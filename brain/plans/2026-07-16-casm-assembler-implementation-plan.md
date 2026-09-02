---
feature: casm-native-assembler
created: 2026-07-16
status: in-progress
---

# Plan: CASM Native 6502/6510 Assembler

## Current Status (reconciled 2026-08-31)

- Current implementation: CASM `0.5.0` build `1380`.
- Phases 1-13 are complete and user-approved.
- Phase 12 (named constants, `*`, parens/precedence, full operator set,
  char/string literals, DASH adoption) closed at `0.3.0` build `1324`.
- Phase 13 (Data Construction Directives: `.RES`/`.FILL`/`.ALIGN`/`.INCBIN`/
  `.ASSERT`) closed at `0.4.0` build `1349`.
- **Change in scope (2026-08-31):** the optional **progress and processing
  indication** feature — an in-place transient status line plus
  `P1:`/`P2:`/`LOAD`/`WRITE`/`DONE` persistent lines, with byte-identical
  assembled output — shipped as an **optional feature outside these
  numbered phases** (parent plan
  `brain/plans/2026-07-29-casm-feature-progress-indication.md`,
  eleven separately-approved increments). CASM was promoted `0.4.0` ->
  `0.5.0` at its completion gate. See
  `wiki/tasks/casm.md` and `wiki/tasks/casm-progress-indication.md`.
- No numbered CASM phases remain on the active roadmap; further work is
  optional-feature or hardening scope.
- Phase 12 and Phase 13 shipping one minor version later than this plan
  originally targeted, plus the optional progress-indication feature's own
  `0.5.0`, pushed every future phase's (14+) target version two minor
  versions later than drafted; see `## Version Target Reconciliation
  (2026-08-31)` below for the corrected numbers.

Authoritative Phase 12 work-package map:

| WP | Scope | State |
| --- | --- | --- |
| 64 | Expression/relocation contract freeze | Complete |
| 65 | Named constants and circular-definition handling | Complete |
| 66 | Current-address symbol | Complete |
| 67 | Parentheses and explicit precedence | Complete |
| 68 | Arithmetic, shifts, bitwise, unary operators | Complete |
| 69 | Character literals | Complete |
| 70 | Relocation-algebra closure | Complete |
| 71 | DASH syntax adoption and native provenance | Complete |
| 72 | Named-constant zero-page width correction | Complete |
| 73 | Forward-label resolver-state/pass-agreement correction | Complete |
| 74 | `.BYTE` string literals | Complete |
| 75 | Consolidated verification and `0.3.0` completion gate | Complete |

## Goal and Rationale

Implement `casm` as a Command 64 OS native external application. CASM runs on
the C64's 6510, reads source through Command 64 file services, uses REU-backed
VMM for large working sets, and writes static or Command 64 R6-relocatable PRG
files without host-side assembly, linking, or post-processing.

The host CMake/ca65 pipeline builds `casm.prg` itself. Host tools may provide
development-time reference output, but they are never part of CASM's runtime or
user workflow.

## Native Runtime Contract

- CASM executes as a Command 64 user-space application.
- Parsing, symbol resolution, code generation, relocation generation, and any
  future linking execute on the 6510.
- Source, include, binary, object, listing, and output files use Command 64 OS
  file APIs.
- Large source, symbol, and metadata stores use allocations obtained through
  `DOS_ALLOC_MEM` and accessed through `DOS_VMM_READ`/`DOS_VMM_WRITE`.
- Base RAM contains bounded buffers, cursors, hash buckets, and active records.
- Every success and failure path closes owned handles and frees owned VMM
  allocations before `DOS_EXIT`.
- CASM is not a host cross-assembler and is not intended to replace ca65,
  ld65, CMake, or the repository's host build system.

## Base Product Decisions

### Language

- Official documented 6502 instructions and all standard addressing modes.
  The 6510 uses the same documented instruction set.
- Case-insensitive mnemonics and directives; case-sensitive labels.
- Global labels end with `:`.
- Comments begin with `;` and continue to end of line.
- Initial directives: `.org`, `.byte`, `.word`, `.include`, `.static`, and
  `.reloc`.
- Initial expressions: numeric literals, symbols, unary low/high-byte
  extraction (`<` and `>`), and a symbol plus or minus an absolute constant.
- Macros, conditional assembly, local labels, anonymous labels, arbitrary
  segments, undocumented opcodes, and object modules are deferred.

### Command Line

Recommended unambiguous grammar:

```text
CASM source1.asm [source2.asm ...] [/O:output.prg] [/S] [/M] [/L]
```

- `/O:<file>` explicitly names the output; otherwise CASM derives the name
  from the first source file.
- `/S` forces static output.
- `/M` prints the symbol map in deterministic definition order.
- `/L` writes a source listing derived from the output filename.
- Options override source-level mode directives.
- Multiple top-level source files form one ordered compilation unit at include
  depth zero.

### Static and Relocatable Modes

- R6 relocatable output is the default.
- Relocatable output uses CASM's configured, page-aligned default origin.
- `.org` is allowed once, before any label or emitted byte, and forces static
  mode.
- `.org` combined with `.reloc` is a fatal conflict.
- `.static` and `.reloc` are preamble-only; conflicting directives are fatal.
- Precedence is `/S`, then the source preamble directive, then the relocatable
  default.
- Labels and unresolved symbolic operands retain absolute width so instruction
  sizes cannot oscillate. Resolved non-label-derived named constants may select
  zero-page by value, matching numeric literals (WP72/WP73).

### R6 Output Contract

CASM writes the format consumed by `src/command64/loader.asm` and generated by
`tools/reloc.py`:

```text
2-byte PRG load address
program bytes
zero or more 16-bit little-endian relocation offsets
2-byte little-endian base address
2-byte little-endian relocation entry count
ASCII magic "R6"
```

Each relocation offset identifies an emitted high byte that must receive the
loader's common page delta. The table covers instruction operands, `.word`
symbol values, and supported high-byte expressions. It excludes constants,
low-byte values, zero-page operands, and branch displacements. Expressions that
cannot be represented by the R6 common-page-delta model are rejected.

## Foundational Design Constraints

These decisions must remain stable across the base phases:

- The lexer consumes a rewindable source-stream interface rather than knowing
  whether bytes came from a RAM window, VMM, or a sequence of files.
- Every source location carries file identity and line number from the start.
- Expression evaluation returns value, resolution state, relocation class,
  extraction type, referenced-symbol identity, and signed addend.
- Pass 1 and Pass 2 share one dispatch driven by a single pass-mode flag
  (measure vs. emit), gated at exactly one point in the emission engine's byte
  writer, rather than a structured event stream: WP26's Phase 0C.5 freeze
  (`brain/plans/2026-07-22-casm-phase6-wp26-prerequisite-reconciliation.md`)
  found no real consumer existed yet to design an event shape against, and
  deferred any structured "emission event" concept until the listing writer's
  actual needs were known. Phase 10 subsequently implemented direct `emitByte`
  capture plus source-owned completed-line sidecars, not an event bus. WP29
  (`brain/plans/2026-07-23-casm-phase6-wp29-pass2-resolution-emission.md`)
  implements Pass 2 against this simpler design; this bullet originally
  described the pre-Phase-6 intent and is corrected here to match.
- Symbols are stored in VMM and found through a bounded base-RAM hash bucket
  array with VMM collision chains.
- Symbol records reserve flags for definition, reference, relocation, and
  future scope, but do not embed speculative native-linker fields.
- Resource ownership is registered centrally so cleanup does not depend on
  which phase failed.
- The base assembler reparses a deterministic source stream in Pass 2 rather
  than storing a complete token or syntax tree in VMM.

## Original Expected Files and As-Built Boundaries

The table below is the original decomposition forecast, retained as historical
planning context. The approved implementation did not create separate
`pass1.s`, `pass2.s`, `codegen.s`, or `output.s` modules: `casm.s` owns pass
orchestration, `emit.s` owns addressing/emission/output sequencing, and
`fileio.s` owns native file serialization. `include.s`, `listing.s`, and
`map.s` are now implemented production modules. Current ownership is governed
by `src/external/casm/AGENTS.md` and the phase-specific as-built records.

| File | Action | Responsibility |
|---|---|---|
| `CMakeLists.txt` | Modify | Register CASM and add it to the release image |
| `src/external/casm/AGENTS.md` | Create if warranted by DOX | CASM-local contracts and verification |
| `src/external/casm/BUILD_CASM` | Create | Persistent build number |
| `src/external/casm/casm.s` | Create | Entry point and phase orchestration |
| `src/external/casm/common.inc` | Create | Shared constants, state, and module ABI |
| `src/external/casm/cli.s` | Create | Native command-line parsing |
| `src/external/casm/diagnostics.s` | Create | Diagnostics and fatal cleanup |
| `src/external/casm/fileio.s` | Create | Bounded Command 64 file wrappers |
| `src/external/casm/source.s` | Create | Rewindable source stream and provenance |
| `src/external/casm/vmm_store.s` | Create | VMM allocation and windowed transfers |
| `src/external/casm/lexer.s` | Create | Tokenization |
| `src/external/casm/expr.s` | Create | Initial expression evaluator |
| `src/external/casm/symbols.s` | Create | VMM symbol table and RAM hash index |
| `src/external/casm/opcodes.s` | Create | Official opcode/addressing table |
| `src/external/casm/pass1.s` | Create | Address assignment and definitions |
| `src/external/casm/pass2.s` | Create | Resolution and emission |
| `src/external/casm/codegen.s` | Create | Addressing resolution and byte emission |
| `src/external/casm/reloc.s` | Create | R6 relocation record generation |
| `src/external/casm/output.s` | Create | Native PRG serialization |
| `src/external/casm/include.s` | Create later | Include stack and cycle detection |
| `src/external/casm/listing.s` | Create later | `/L` listing consumer |
| `src/external/casm/map.s` | Create later | `/M` symbol reporting |

Exact module boundaries may be adjusted before implementation, but no module
should combine unrelated CLI, storage, parsing, code-generation, and reporting
responsibilities merely to reduce file count.

## Phased Base Implementation

### Phase 0: Contract Freeze and Risk Spikes — Complete

Resolve the contracts that affect foundational representations:

- Final CLI grammar, option placement, default output name, and limits.
- Identifier characters and maximum length.
- Filename, input-count, source-size, symbol-count, and relocation-count limits.
- Numeric literal syntax and 16-bit overflow behavior.
- Initial expression grammar and relocation classification.
- Default origin and page-alignment requirement.
- `.org`, `.static`, `.reloc`, and `/S` conflict rules.
- Exact R6 footer and table semantics.
- Source-stream and source-location interfaces.
- Symbol record, hash algorithm, bucket count, and collision-chain layout.
- RAM, zero-page, stack, file-handle, and VMM budgets.
- Diagnostic categories and cleanup rules.

Perform bounded design spikes for:

- Sequential VMM read/write windows and bank/offset carry behavior.
- Maximum practical base-RAM hash bucket array.
- Reopening and deterministically replaying source for Pass 2.
- Incomplete output deletion after write or disk-full failure.
- R6 serialization without seeking.
- Maximum safe CASM application size under `add_ca65_app`.

Gate: the user approves all observable language and CLI contracts and the RAM,
VMM, and zero-page maps.

### Phase 1: Native Application Scaffold — Complete

- Create the external-app directory, build counter, entry point, and common
  include.
- Add the ca65 target using `add_ca65_app` and add CASM to
  `IMAGE_PRG_TARGETS`.
- Print a version banner and exit through `DOS_EXIT`.
- Establish the private `$70-$8F` zero-page allocation and base-RAM map.
- Add central resource registration and cleanup stubs.
- Add the minimal diagnostic printer.

Verification:

- CMake configures without new warnings or errors.
- `cmake --build build --target casm` succeeds.
- `cmake --build build --target image_d64` includes `casm.prg`.
- The user launches CASM in the supported local emulator and confirms that it
  prints its version and returns to the shell intact.

Gate: CASM launches and exits without corrupting shell state.

### Phase 2: CLI and Native File-Service Foundation — Complete

- Parse one required source, `/O`, `/S`, `/M`, and `/L` from `CommandBuffer`
  using `ParsePos`.
- Parse bounded null-terminated filenames and reject malformed or duplicate
  options.
- Implement native input open/read/close wrappers.
- Implement output create/write/close/delete wrappers.
- Track every owned file handle.
- Route all fatal failures through central cleanup.
- Options whose feature is not implemented yet report a stable
  "not implemented" diagnostic after successful parsing.

Verification includes missing source, malformed `/O`, unknown options,
filename overflow, read failure, create failure, write failure, close failure,
and cleanup of partially opened resources.

Gate: CASM can safely consume a bounded input stream and survive every tested
I/O error without leaked handles or incomplete output.

### Phase 3: Source Stream and Minimal Lexer — Complete

Detailed implementation is governed by
`brain/plans/2026-07-16-casm-phase3-source-stream-lexer.md`.

Define and implement:

```text
sourceOpen
sourceNextByte
sourceNextLine
sourceGetLocation
sourceRewind
sourceClose
```

Initial behavior:

- One input file and one bounded base-RAM line window.
- CR, LF, and CRLF normalized to one internal newline.
- Filename and one-based line-number tracking.
- Whitespace, comments, identifiers, mnemonics, directives, numeric literals,
  registers, delimiters, and punctuation.
- Bounds checks for every token and line.

The interface must allow a VMM/multi-file backend without lexer changes.

Gate: a temporary token-dump mode reproduces all lexical fixtures with correct
file and line locations.

### Phase 4: Statement Parser, Opcode Table, and Numeric Static Assembly — Complete

Implement a restricted numeric-only vertical slice:

- Bounded statement parsing between the lexer and numeric code generation.
- Official opcode/addressing-mode table.
- Implied, accumulator, immediate, zero-page, zero-page indexed, absolute,
  absolute indexed, indirect, indexed-indirect, indirect-indexed, and relative
  numeric operands.
- Numeric `.byte` and `.word`.
- A single initial `.org`.
- Static PRG header and buffered native output.
- Invalid mnemonic/mode and operand-range diagnostics.

No labels, forward references, relocation, includes, maps, or listings are
included in this phase.

Gate: numeric-only fixture programs match trusted expected machine bytes.

### Phase 5: Minimal Expression Evaluator — Complete

Implement the approved expression subset and return a structured result:

```text
16-bit value
resolved or unresolved
constant or symbol-derived
absolute or relocatable
full, low-byte, or high-byte extraction
referenced symbol identity
signed constant addend
```

- Detect malformed expressions and range failures.
- Preserve relocation metadata rather than reconstructing it during output.
- Reject combinations that the base grammar or R6 model cannot represent.

Gate: expression fixtures pass without depending on instruction emission.

### Phase 6A: VMM Storage Foundation — Complete

- Implement bounded VMM-backed record storage before any symbol-table user.
- Define record capacity, allocation, access, replay, and failure contracts.
- Verify small deterministic fixtures through base-RAM and VMM-backed paths.

Gate: bounded VMM records can be written, read, and replayed without source or
symbol semantics.

### Phase 6B: Symbol Table and Two-Pass Assembly — Complete

- Allocate VMM-backed symbol storage.
- Use a documented 6502-efficient hash with bounded RAM buckets and VMM
  collision chains.
- Define duplicate, undefined, case-sensitive, and maximum-length behavior.
- Pass 1 assigns addresses, inserts definitions, and calculates stable sizes.
- Pass 2 resolves references and emits bytes.
- Symbolic operands retain absolute width unless future explicit syntax forces
  zero page.
- Calculate relative branches from the address following the branch and enforce
  the `-128..127` range.
- Detect Pass 1/Pass 2 size or final-PC disagreement as an internal fatal error.

Gate: static programs with forward and backward references match trusted
reference binaries byte for byte.

### Phase 7: VMM-Backed Source and Multiple Top-Level Inputs — Complete

- Cache the complete bounded compilation unit in VMM before Pass 1 so both
  passes traverse identical bytes and Pass 2 performs no source filesystem I/O.
- Use bounded 256-byte native file/VMM transfers and preserve the 65,535-byte
  combined distinct-source cap.
- Support up to eight ordered command-line inputs in one global symbol scope.
- Maintain file and line provenance across boundaries.
- Insert a logical newline between files when required.
- Validate every 16-bit offset increment and allocation ceiling.
- Preserve deterministic replay, synthetic boundary newlines, and per-file
  provenance across both passes.

Gate: small inputs remain byte-identical, while large and multiple inputs
assemble successfully with correct diagnostics.

### Phase 8: Native R6 Relocation — Complete

- Default to relocatable output while preserving `/S` static override.
- Record the code offset of each emitted relocatable high byte.
- Cover absolute instruction operands, supported indexed/indirect operands,
  `.word` symbols, and supported high-byte symbol expressions.
- Exclude constants, branches, low-byte extraction, and zero-page operands.
- Reject expressions that cannot be represented by a shared page delta.
- Check output-size, table-offset, and relocation-count overflow.
- Append the exact R6 table and footer directly through native file services.
- Never invoke `tools/reloc.py` at runtime.

Gate: Command 64 loads and runs generated R6 fixtures at several page-aligned
addresses; static fixtures remain ordinary PRGs.

This gate completes the CASM 0.1 minimum native assembler.

### Phase 9: Include Processing — Complete

- Add `.include` through a bounded VMM-span source-frame stack; input handles
  are transiently opened, loaded, and closed rather than retained by frames.
- Define Command 64 device-prefix and include-path resolution.
- Preserve included filename, line, and include-site provenance.
- Detect missing files, maximum depth, and direct or indirect cycles.
- Close each transient include-load handle immediately after loading; retain
  central ownership for fatal cleanup if close fails.
- Record enough include-graph information in Pass 1 to replay the same source
  graph deterministically in Pass 2.

Gate: nested includes assemble identically in both passes and every diagnostic
identifies the correct physical source location.

### Phase 10: Symbol Map and Listing — Complete

- `/M` prints symbols in deterministic definition order; sorting is deferred.
- `/L` captures generated bytes at `emitByte` (excluding raw PRG headers and R6
  metadata), while a source-owned completed-line sidecar provides exact file,
  line, and source spans.
- Statement listing transactions snapshot PC and generated-byte cursor before
  dispatch and commit afterward; `.INCLUDE` commits before frame push.
- Define continuation formatting for directives that emit many bytes.
- Included files retain their own provenance in listings.
- Track and remove incomplete listing files on failure.
- Respect Command 64's simultaneous file-handle limits.

Gate: enabling `/M` or `/L` never changes generated PRG bytes.

This gate completes the CASM 0.2 developer-usability release.

### Phase 11: Base-Release Hardening and Documentation — Complete

- Exercise every official opcode/addressing-mode combination.
- Test literal, address, PC, source, symbol, VMM, and relocation boundaries.
- Audit carry propagation, decimal-mode assumptions, register clobbers, stack
  balance, zero-page ownership, file handles, and VMM allocations.
- Exercise no-REU, out-of-memory, missing-device, no-disk, disk-full, partial
  read/write, and output-cleanup behavior.
- Confirm identical input produces identical output.
- Update user, programmer, API-adjacent, internal brain, task, changelog, and
  applicable DOX documentation required by the repository workflow.
- Create a walkthrough containing native edit-assemble-load-run confirmation.

Gate: the user performs the manual runtime walkthrough and decides whether the
base release is done. The task is not marked done without that confirmation.

## Completed Native Release Phases

### Phase 12: Constants and Expanded Expressions (CASM 0.3) — Complete

- Named constant definitions.
- Current-address symbol.
- Parentheses and explicit precedence.
- Multiplication, division, shifts, bitwise operations, unary negation, and
  complement where practical on the 6510.
- Character literals: one verbatim printable PETSCII byte in immediate and
  `.BYTE` contexts (WP69, complete).
- String literals: bounded double-quoted verbatim PETSCII entries in `.BYTE`
  lists, empty allowed, no escapes or implicit terminator (WP74, active).
- Circular-definition and division-by-zero diagnostics.
- Relocation algebra limited to combinations that remain representable.

Risk gate: expanded expressions must preserve the base relocation classifier
and must not change existing program bytes.

Corrective WP72/WP73 were discovered by WP71's required DASH dogfooding and are
part of the completed Phase 12 work, not optional follow-ups. The governing plan
and authoritative WP map above supersede earlier provisional numbering.

### Phase 13: Data Construction Directives (planned CASM 0.3, shipped CASM 0.4) — Complete

Planned directives (all implemented):

```text
.res count[, value]
.fill count, value
.align boundary[, fill]
.incbin "file"
.assert expression[, "message"]
```

- Phase 12 WP74 owns canonical ca65-compatible `.BYTE "string"` syntax and the
  shared string token/encoding. `.TEXT` is not inherited as planned Phase 13
  syntax; adding it requires a separately approved, non-duplicate semantic
  purpose. Migration plans use `.BYTE` by default.

- Large fills and binary inclusions stream through bounded buffers.
- `.align` produces identical Pass 1 and Pass 2 sizes.
- `.incbin` records and verifies native file identity/length between passes.

Closed at `0.4.0` build `1349`, one minor version later than this plan
originally targeted: Phase 12 itself consumed `0.3.0` at its own completion
gate (rather than landing inside it), pushing Phase 13's release to the next
minor version. See `## Version Target Reconciliation (2026-08-31)` below for
the full renumbering this caused to the remaining future phases.

## Version Target Reconciliation (2026-08-31)

This plan originally paired each future phase with a specific minor version
under the assumption that phases would consume minor versions in strict
numeric order with no non-phase releases between them. Two scope changes
broke that assumption, and every future-phase version target below is
corrected accordingly:

- Phase 12 (Constants and Expanded Expressions) was originally expected to
  land alongside Phase 13 inside one `0.3` release. Instead Phase 12 closed
  its own completion gate at `0.3.0` build `1324`, so Phase 13 (Data
  Construction Directives) shipped one minor version later than planned, at
  `0.4.0` build `1349`, not the `0.3` this plan originally listed.
- The optional progress-and-processing-indication feature
  (`brain/plans/2026-07-29-casm-feature-progress-indication.md`) is explicitly
  **not** a numbered phase in this plan, but it still consumed a real minor
  version at its own completion gate: CASM was promoted `0.4.0` -> `0.5.0`.
  That leaves no unused `0.5` for a future phase.

Consequently every phase target from Phase 14 onward is shifted two minor
versions later than originally drafted: Phase 14/15 now target `0.6` (was
`0.4`), Phase 16 now targets `0.7` (was `0.5`), and Phase 17's "Post-0.5"
framing is now "Post-0.7". Phase 18 (separate project) and Phase 19 (`1.0`
stabilization) are unaffected because they were never pinned to a specific
pre-1.0 minor version. Future non-phase optional features remain free to
consume additional minor versions before Phase 14 begins; if one does, this
reconciliation must be repeated rather than silently left stale.

## Future Native Release Phases

### Phase 14: Local and Anonymous Labels (CASM 0.6)

- Local labels scoped to the preceding global label.
- Optional anonymous forward/backward labels.
- Stable internal identities assigned in Pass 1.
- Scoped diagnostics and optional local-symbol map output.

### Phase 15: Conditional Assembly (CASM 0.6)

- `.if`, `.elseif`, `.else`, and `.endif`.
- Bounded nesting and deterministic Pass 1 evaluation.
- Layout-controlling conditions must resolve during Pass 1.
- Suppressed branches do not allocate symbols or emit bytes.

Conditional assembly precedes macros because it validates controlled source
suppression without parameter substitution, recursive expansion, or generated
label scopes.

### Phase 16: Macros and Repetition (CASM 0.7)

- Macro definitions and parameters.
- Macro-local labels.
- Bounded `.repeat` expansion.
- Bounded nesting, total expansion size, and recursion detection.
- VMM-backed expansion records rather than an unbounded base-RAM expansion.
- Diagnostics report invocation and definition locations.

### Phase 17: Multiple Segments (Post-0.7 Investigation)

- Named segment records with origin, size, fill policy, and relocation set.
- Overlap and address-space validation.
- Decide whether native output is one gap-filled PRG, several PRGs, or a new
  container before implementation.
- Define whether segments share one relocation delta or require a loader-format
  extension.

This phase must not weaken the base restriction that `.org` is initial-only and
static-only until a new output contract is approved.

### Phase 18: Native Object and Linker Investigation (Separate Project)

Native object generation and linking are not an incremental CASM base feature.
If approved, create a separate plan and likely a separate Command 64 external
application such as `clink`.

The native workflow would resemble:

```text
CASM MAIN.ASM /OBJ /O:MAIN.C64O
CASM DRAW.ASM /OBJ /O:DRAW.C64O
CLINK MAIN.C64O DRAW.C64O /O:GAME.PRG
```

Both programs would run on the 6510, use Command 64 file APIs, and store large
object/link state in VMM. No host linker participates. Object-format versioning,
imports, exports, segment placement, richer relocation types, and compatibility
with the existing R6 loader require their own approval gates.

### Phase 19: CASM 1.0 Native Stabilization

Acceptance objective:

> From a running Command 64 environment, a user can edit source, invoke CASM,
> produce a PRG, load it at a supported address, and run it without any
> host-side processing.

Representative workflow:

```text
EDLIN HELLO.ASM
CASM HELLO.ASM /O:HELLO.PRG /L /M
LOAD HELLO.PRG
RUN HELLO
```

Before 1.0:

- Freeze the documented grammar and CLI.
- Publish all source, symbol, include, macro, VMM, output, and relocation limits.
- Maintain a regression fixture for every corrected CASM defect.
- Confirm repeated native assembly is deterministic.
- Assemble a representative multi-file Command 64 application using CASM.
- Complete a full resource, memory-clobber, and error-path audit.

### Phase 20: Undocumented (Illegal) 6510 Opcodes — Review Item (post-1.0, not committed)

**Status: review item only.** This phase is a placeholder for a decision the
project has not made. No implementation is authorized by its presence here; it
requires its own separately approved plan and completion gate before any source
change, exactly like a numbered phase. Recorded 2026-09-01 at user request to
capture the analysis rather than lose it.

**Value proposition (audience-specific):**

- High value for demoscene / sizecoding / music-driver / fastloader work and
  for importing existing real-world C64 source (cracks, trainers, demos, SID
  players commonly use illegal opcodes). ca65 (`--cpu 6502x`) and Turbo Macro
  Pro both assemble them; CASM being the odd tool out is a source-portability
  friction point, the same theme as the local-label-in-constant divergence
  (Phase 14 Research item 7).
- Low-to-zero value for greenfield Command 64 application code (DASH, EDLIN,
  user programs), which is CASM's actual target audience and is not
  cycle-critical.

**Only the stable subset is a candidate.** The 6510's undocumented opcodes
split into a stable subset — reliable on every real C64/C64C and every accurate
emulator — and an unstable group whose result depends on page-crossing and
target-address high bytes and varies by chip revision.

- Stable subset (candidate): `LAX`, `SAX`, `SBX`/`AXS`, `DCP`, `ISC`/`ISB`,
  `SLO`, `RLA`, `SRE`, `RRA`, `ANC`, `ALR`/`ASR`, `ARR`, and the multi-byte
  `NOP` forms (`$04`/`$0C`/`$14`/…).
- Unstable group (must be hard-refused, never emitted): `SHA`/`AHX`,
  `SHX`/`SHY`, `TAS`, `LAS`. `JAM`/`KIL`/`HLT` are refused as well.

**Costs specific to CASM:**

- **MAIN envelope.** The stable subset adds ~20 mnemonics plus many
  addressing-mode rows to `opcodes.s` and the mode matcher. CASM MAIN is pinned
  at `$7400` with limited headroom; envelope pressure is the binding constraint
  and a Stop Condition.
- **Trusted-reference burden.** Every opcode's bytes must be hand-derived from
  the 6502/6510 spec, never from a table (`project-casm-trusted-reference-rule`
  memory). Illegal opcodes have contradictory naming across sources
  (`ALR`/`ASR`, `SBX`/`AXS`, `ISC`/`ISB`/`INS`) and messier documentation —
  more fixtures, higher chance of enshrining a wrong byte.
- **Relocation audit.** Every new absolute-mode illegal opcode
  (`LAX abs,Y`, `DCP abs,X`, `SAX abs`, …) must be checked against the R6
  high-byte recording logic in `emit.s` / `reloc.s`.

**Proposed shape if ever approved:**

- Stable subset only; unstable group and `JAM` hard-refused with a clear
  diagnostic.
- Opt-in, never default: a `.setcpu "6510x"` preamble directive or a `/X`
  command-line flag, so default output stays portable to documented-only
  targets and a source with no opt-in assembles byte-identically to today.
- Sequenced after macros (Phase 16) and conditional assembly (Phase 15), which
  close larger source-portability gaps for less envelope cost.
- Its own hand-derived `.ref` fixture per opcode/mode, a DASH no-regression
  sweep, and a CASM/ca65 (`--cpu 6502x`) cross-check.

**Gate:** the user approves a dedicated plan, or explicitly declines and this
review item is closed as "will not do". Until then CASM emits documented
opcodes only.

## High-Risk Feature Analysis

### Critical Risk

#### Arbitrary `.org` and Multiple Segments

These break the single-PC model, complicate gap serialization and overlap
checking, and conflict with R6's common page delta. Keep `.org` initial-only and
static-only until Phase 17 approves a new segment/output contract.

#### Automatic Zero-Page Optimization

A forward symbol may appear absolute in Pass 1 and zero-page in Pass 2, changing
all following addresses and possibly oscillating branch ranges. Symbolic
operands therefore remain absolute-width in the base release. Explicit forcing
syntax may be considered later.

#### General Relocatable Arithmetic

R6 only patches selected high bytes by one shared page delta. Subtracting
unrelated relocatable symbols, masking addresses, or multiplying relocatable
values may not be representable. The base release accepts only a relocatable
symbol plus or minus an absolute addend and supported byte extraction.

#### Macros in the Base Release

Macros introduce recursive expansion, generated scopes, unpredictable VMM use,
and multi-location diagnostics. They remain after includes, listings, local
labels, and conditional assembly.

#### Native Object Format and Linker

This expands the work from an assembler into a toolchain and requires richer
relocations, visibility rules, segments, and a versioned file format. It remains
a separate post-base project and must not drive speculative complexity into
base symbol records.

### High Risk

- `.include` multiplies filesystem, provenance, two-pass, and cleanup paths; it
  follows stable multi-file assembly.
- String literals and encoding modes can permanently constrain PETSCII,
  screen-code, and raw-byte semantics; introduce them with a documented
  encoding contract.
- Listing output adds simultaneous file-handle and partial-output paths; design
  byte capture and source-span ownership against real listing requirements, not
  a speculative event stream. Phase 10's `emitByte`/line-sidecar model is the
  as-built precedent.
- A complete token or syntax-tree IR duplicates VMM storage and cleanup burden;
  reparse deterministic source instead.
- `.incbin` adds large binary transfers and Pass 1/Pass 2 identity checks; it
  follows normal includes.

### Medium Risk

- Multiple top-level sources are manageable when treated as one ordered global
  scope at include depth zero.
- `.static` and `.reloc` are manageable only as preamble directives.
- Sorted map output is unnecessary for correctness and may be expensive with
  VMM records; use definition order initially.

## Explicitly Deferred or Out of Scope

- Host execution of CASM.
- Host-side assembly, linking, or R6 post-processing in the CASM user workflow.
- Replacement of ca65/ld65 in the repository build.
- 65C02 or 65816 support.
- Undocumented (illegal) 6510 opcode support **in the base and numbered
  language phases**. Moved 2026-09-01 from "out of scope" to a post-1.0
  review item — see `### Phase 20` — but remains unimplemented and
  uncommitted until a dedicated plan is approved.
- Source-level debugger integration.
- Link-time optimization.
- IDE language server integration.
- ELF or cc65 object compatibility.
- Arbitrary byte-granularity runtime relocation.
- Runtime overlays.
- Self-hosting the complete Command 64 OS.

## Verification Strategy

### Build Verification

```bash
cmake --build build --target casm
cmake --build build --target image_d64
```

### Development Oracles

Trusted expected byte sequences and ca65 output may be used during development
to validate the supported syntax intersection. They do not participate in
CASM's runtime or normal user workflow.

### Native Manual Verification

The required end-to-end path is:

```text
Command 64 shell
  -> CASM reads source from a mounted C64 device
  -> CASM assembles on the 6510 using native RAM/VMM services
  -> CASM writes a PRG through native file services
  -> Command 64 LOAD/RUN loads the PRG
  -> the generated program executes
```

Use the VICE-embedded C64 MCP only under
`.agents/workflows/vice-mcp-testing.md`: start/verify it through
`tools/vice_mcp_start.sh`, boot Command64 before applications, prefer exact
PETSCII shell input, and leave a healthy emulator running. If the MCP is
unavailable, ask the user to run the same workflow. Never use a web emulator.

## Dependency-Critical Path

```text
contracts and memory budgets
  -> native scaffold
  -> safe file I/O and cleanup
  -> rewindable source stream
  -> lexer
  -> numeric static code generation
  -> minimal relocation-aware expressions
  -> symbols and two passes
  -> VMM-scale and multi-file input
  -> native R6 relocation
  -> includes
  -> maps and listings
  -> hardening and user walkthrough
```

No later phase may bypass an earlier gate merely because its user-facing syntax
appears independent. In particular, includes depend on stable provenance and
two-pass replay; relocation depends on correct static emission; listings depend
on direct byte capture plus exact source-span ownership; and macros depend on stable includes, scoping, and
diagnostics.

Every CASM language or feature addition must audit DASH, perform a meaningful
byte-equivalent DASH rewrite when applicable, and re-run native CASM and ca65
cross-checks. If safe adoption is impossible, stop for explicit user direction
rather than silently waiving real-application dogfooding.

## Progress

- 2026-07-16: Initial proposal reviewed and reorganized to correct phase
  dependencies, preserve native-only execution, identify high-risk feature
  expansions, and define future native release phases.
- 2026-07-29: Phases 1-9 are complete through CASM `0.1.50` build 1204.
  Progress and processing indication is tracked as a separately gated optional
  feature outside this plan's numbered phases; it does not replace or renumber
  Phase 10, Symbol Map and Listing.
- 2026-07-29: The Phase 10 Symbol Map and Listing governing plan is approved at
  `brain/plans/2026-07-29-casm-phase10-symbol-map-listing.md`. WP50-WP55 remain
  pending and individually gated; approval of the parent plan does not activate
  WP50 or authorize source edits.
- 2026-08-08: Phase 10 is complete. WP50-WP55 all individually planned,
  approved, implemented, verified, and user-approved. CASM promoted to `0.2.0`
  build `1260` via the completion-only version change; this completes the
  CASM 0.2 developer-usability release the Phase 10 gate defined. `feature/
  casm-phase10-wp53` merged onto `casm-phase10`, then onto `main`.
  Phase 11 subsequently closed user-approved at CASM `0.2.2` build `1266`;
  see `brain/plans/2026-08-08-casm-phase11-base-release-hardening-documentation.md`.
- 2026-08-18: Reconciled the master plan to current truth. Phase 12 is active;
  WP64-WP73 are complete, CASM is `0.2.7` build `1319`,
  WP74 `.BYTE` strings is approved/active, and WP75 is the pending consolidated
  `0.3.0` completion gate. Added the mandatory per-feature DASH-adoption rule
  and corrected stale Phase 7, listing, module-boundary, testing, and Phase 13
  string assumptions.
- 2026-08-31: Corrected stale phase/version bookkeeping this file had not
  caught up to. WP75 marked Complete (was still shown Pending) after Phase 12
  closed at `0.3.0` build `1324`; Phase 12's header changed from "target CASM
  0.3 — Active" to "CASM 0.3 — Complete". Phase 13 (Data Construction
  Directives) moved out of "Future Native Release Phases" into the completed
  phases, marked Complete, and its version corrected from the originally
  planned `0.3` to the actually shipped `0.4.0` build `1349`. Added a new
  "Version Target Reconciliation" section explaining why: Phase 12 consuming
  its own `0.3` completion gate, plus the optional (non-phase) progress and
  processing indication feature consuming `0.5.0` at its own completion gate,
  together push every remaining future phase's target two minor versions
  later than originally drafted (Phase 14/15 `0.4` -> `0.6`, Phase 16 `0.5` ->
  `0.7`, Phase 17 "Post-0.5" -> "Post-0.7"). Phases 18-19 are unaffected. This
  entry does not activate, reorder, or reopen any phase; it only corrects
  version labels to match already-approved completion gates recorded
  elsewhere (`wiki/tasks/casm.md`, `CHANGELOG.md`).
- 2026-09-01: Added `### Phase 20: Undocumented (Illegal) 6510 Opcodes` as a
  post-1.0 **review item** at user request — value-proposition analysis,
  stable-vs-unstable opcode split, CASM-specific costs (MAIN envelope,
  trusted-reference burden, relocation audit), and a proposed opt-in shape
  (`.setcpu "6510x"` / `/X`, stable subset only, sequenced after Phases
  15-16). Not committed work; needs its own approved plan and gate. Split the
  "Explicitly Deferred or Out of Scope" bullet so 65C02/65816 stay fully out
  of scope while illegal opcodes now point at Phase 20.
