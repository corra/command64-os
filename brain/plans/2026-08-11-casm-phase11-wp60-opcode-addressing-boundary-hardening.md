# Plan: CASM Phase 11 WP60 - Opcode, Addressing, and Boundary Hardening

## Status

Drafted 2026-08-11 for user review. No WP60 task, source change, fixture,
build-system change, or version change is authorized until this plan is
explicitly approved. After approval, each atomic increment remains separately
gated by user review of the preceding increment.

## Objective

Close WP60's reconciled Phase 4 debt and replace representative opcode/mode
sampling with exhaustive evidence for every documented NMOS 6502/6510
instruction encoding CASM claims to support. Certify parser-to-emitter behavior
at the literal, address-width, program-counter, source, symbol, VMM, and
relocation boundaries named by the Phase 11 parent plan without broadening the
language, ABI, or supported processor.

WP60 completion advances CASM from `0.2.1` to `0.2.2` only after consolidated
build/runtime verification, a user-approved walkthrough, and a verified
version-only final rebuild.

## Prerequisites

- Phase 11 WP56 is complete and owns the authoritative debt reconciliation and
  audit-priority tiers.
- WP57/WP58 fault infrastructure and file/VMM failure coverage are complete.
- WP59 listing/map hardening is complete at CASM `0.2.1.1264`.
- Phase 4's `casmmodes.ref` remains the trusted precedent: independently
  derived expected bytes, native assembly, and native `COMP` comparison.
- Phase 8's symbol/relocation and source/VMM boundary harnesses remain reusable;
  WP60 must not duplicate already-exact evidence merely to increase case count.

## Reconciled Scope

WP56 reduced the three carried-forward Phase 4 notes to these dispositions:

1. `CasmOutputCreated` conflation: stale premise, already retired by tracing.
   WP60 changes neither `fileio.s` nor this flag. Taskwarrior #36 remains the
   separately owned existing-file/IEC issue.
2. Missing entry `CLD`: not a live bug because the first current `OS_API` call
   clears decimal mode, but an unsafe implicit ordering invariant. WP60 adds
   `CLD` as the literal first instruction at `start:`.
3. Missing Phase 4 `brain/KNOWLEDGE.md` contract section: assigned to WP62's
   clean-room documentation synchronization, not WP60.

WP60 therefore owns one production hardening instruction plus exhaustive
opcode/addressing and boundary certification. It does not reopen WP56's closed
debt decisions.

## Frozen Processor Contract

- Target: documented NMOS 6502 instructions as implemented by the C64's 6510.
- Mnemonics: the existing 56 contiguous `CASM_MNEMONIC_*` subtypes.
- Addressing modes: the existing 13 `CASM_MODE_*` values.
- Legal combinations: the existing 151 documented opcode/mode encodings.
- Excluded: undocumented opcodes, 65C02/65SC02/65816/65CE02 additions,
  pseudo-instructions, cycle-count certification, and execution-semantic CPU
  testing. WP60 certifies parsing, selection, length, and emitted bytes.
- `opcodeMaskLo`, `opcodeMaskHi`, `opcodeRunOffset`, and `opcodeBytes` remain
  production implementation, never the source used to generate expected test
  values.

The number 151 is a frozen completeness assertion, not permission to preserve a
bad table entry. Any disagreement with the independent oracle is investigated
against documented NMOS 6502 encoding before either side changes.

## Independent Oracle Design

WP60 uses two complementary proofs.

### Direct matcher oracle

A new focused `test_casm_opcodes` harness links real `opcodes.s` and supplies
`CasmParserStmt` records directly. Its read-only test table independently lists
all 151 legal tuples:

- mnemonic subtype;
- parser operand kind and value/flags needed to select the mode;
- expected `CASM_MODE_*`;
- expected opcode byte;
- expected instruction length.

The expected table is transcribed and reviewed in conventional mnemonic/mode
order from a documented NMOS 6502 matrix, not copied or generated from
`opcodeBytes` or its masks. A one-to-one coverage bitmap proves every expected
tuple runs exactly once. Compile-time assertions freeze 56 mnemonics, 13 modes,
151 legal tuples, and the test-record size.

### End-to-end native artifact

A generated source fixture, `casmopall.s`, contains one legal statement for
each of the same 151 combinations. A committed `casmopall.ref.hex` contains a
load address and independently reviewed bytes. CASM assembles the fixture on a
dedicated disk; native `COMP` proves parser, matcher, emitter, PC advancement,
file output, and all operand-byte order end to end.

The source generator may format static reviewed fixture records, but it must
not read production opcode tables or derive expected opcodes. The committed
reference includes a per-statement offset manifest so the first mismatching
combination can be identified without reverse-engineering the entire output.
The assembled artifact is data-only and must never be executed.

## Matcher Contract Coverage

For each legal tuple the direct harness asserts:

- carry clear and A equals the expected opcode;
- `CasmInsn.Opcode`, `.Mode`, and `.Length` exactly match;
- `CasmParserStmt` remains byte-identical;
- stack pointer is balanced;
- the legal-combination coverage bitmap has no duplicate or missing bit.

Focused negative and selection cases additionally assert:

- every unsupported operand kind/mnemonic pair returns
  `CASM_DIAG_INVALID_ADDR_MODE`, carry set, and statement location stamped;
- immediate, indexed-indirect, and indirect-indexed accept `$00`/`$FF` and
  reject `$0100`;
- literal `$00`/`$FF` select zero-page variants where available;
- literal `$0100`/`$FFFF` select absolute variants;
- `CASM_PARSER_STMT_FORCE_ABS` prevents zero-page shrinking at `$0000`/`$00FF`;
- zero-page X and Y promotion are independent, including LDX/STX zero-page,Y;
- all eight branches resolve to relative mode and preserve 16-bit targets for
  displacement handling in `emitInstruction`;
- implied and accumulator forms remain distinct where the mnemonic permits
  only one of them.

## Boundary Evidence Register

Increment 2 freezes a row-by-row register before new boundary cases are added.
Each row records the lower-valid, upper-valid, first-invalid, exact expected
diagnostic/commit point, current fixture, and disposition: reuse, strengthen,
or add. Required domains are:

| Domain | Required boundaries |
| --- | --- |
| Numeric literal | `$0000`, `$00FF`, `$0100`, `$FFFF`, first lexical/evaluation overflow; decimal/hex/binary parity |
| Addressing width | zero-page/absolute at `$FF`/`$0100`; 8-bit indirect/immediate rejection at `$0100`; forced-absolute symbol stability |
| Relative branch | displacement `-128`, `-127`, `0`, `+127`; reject `-129`, `+128`; wrap-sensitive PC endpoints |
| Program counter | `.ORG $0000`, `$FFFE`, `$FFFF`; emit ending at `$FFFF`; reject first byte after overflow; repeat reset |
| Source | empty, one byte, 255/256 transfer split, 65,535-byte accepted extent, first byte beyond cap, exact EOF/line behavior |
| Symbol | empty, one, name length 1/31, reject 0/32, values `$0000`/`$FFFF`, 511/512 records, reject 513th, duplicate behavior |
| VMM store/window | first/last byte, 255/256 window split, 4,095/4,096 page edge, 65,535-byte request/grant endpoint, one-past-window rejection |
| Relocation | empty/one, offsets `$0000`/`$FFFF` where representable, 4,095/4,096 entries, reject 4,097th, footer count/terminator and replay bounds |

Existing exact evidence may satisfy a row only when it verifies the production
routine, expected diagnostic/flags, state commit point, and repeat cleanup. A
comment or incidental successful assembly is not sufficient.

## Production Change

`start:` in `src/external/casm/casm.s` gains `CLD` as its first instruction,
before register initialization, banner output, cleanup initialization, or any
reachable `ADC`/`SBC`. This creates a structural application-entry invariant
independent of `OS_API` ordering.

No other production change is pre-authorized. A defect found by the exhaustive
oracle may be fixed only after root-cause analysis identifies the exact table,
matcher, parser, or emitter fault and the user approves any material plan
amendment.

## ABI, Storage, and Behavioral Effects

- Public exports, diagnostics, parser records, instruction records, opcode
  masks, mode numbers, and relocation formats remain unchanged.
- No production zero-page or BSS allocation is planned.
- `CLD` intentionally changes only the entry decimal flag from unknown to clear;
  CASM has no supported decimal-mode entry contract.
- Valid PRG/R6/listing/map bytes must remain unchanged except if a confirmed
  existing opcode mis-encoding is found and explicitly approved for correction.
- Test-only storage consists of the tuple oracle, coverage bitmap, fixture
  source/reference, and bounded harness state.
- CASM version remains `0.2.1` through implementation and verification.

## Harness and Disk Architecture

- Add `tests/src/casm_opcodes/casm_opcodes.s` as an isolated matcher harness.
- Link real `opcodes.s`; provide only the minimum diagnostic-location stand-in
  required by its failure path. Do not link `parser.s`, `emit.s`, VMM, or file
  ownership into this unit harness.
- Generate `casmopall.s` through the existing
  `cmake/GenerateCasmTestFixtures.cmake`; commit the independent
  `tests/fixtures/casm/casmopall.ref.hex` oracle.
- Add a dedicated self-bootable `casm_opcode_test_d64` containing `command64`,
  production `casm`, `comp`, `test_casm_opcodes`, `casmopall.s`, and
  `casmopall.ref`. Do not consume the directory-full general `test.d64` or
  displace existing fixtures.
- Reuse existing boundary harnesses (`test_casm_expr`, `test_casm_vmm`,
  `test_casm_symbols`, `test_casm_reloc`, source/pass harnesses) and their
  current disks. Add cases in place only where Increment 2 proves a gap.

## Failure and Cleanup Contracts

- Direct matcher cases must reset statement, instruction, diagnostic-location,
  coverage, and SP baseline state between cases.
- A failed tuple must not be counted as covered and must not inherit a prior
  `CasmInsn` value as evidence.
- End-to-end source assembly uses a unique output name and removes/replaces only
  its own generated output; failure must return to the shell without a partial
  committed artifact.
- Boundary harnesses that allocate VMM stores or file resources must call their
  established cleanup on every success/failure exit and support repeated runs
  in one emulator session.
- Native reference mismatches are stop conditions; never update the oracle to
  make production output pass without independent opcode verification.

## Verification Method

### Static

- Confirm `CLD` is the first instruction reachable at `start:`.
- Trace every reachable pre-`OS_API` arithmetic path and confirm no code can
  bypass `start:` in production.
- Independently reconcile the 151 tuple oracle against mnemonic masks, packed
  run offsets, mode lengths, and the documented 6502 matrix.
- Prove every legal mask bit maps to exactly one tuple and every packed opcode
  byte is consumed exactly once.
- Verify no undocumented/65C02 opcode enters either production or expected data.

### Build and artifacts

- Build `test_casm_opcodes`, `casm_opcode_test_d64`, all strengthened boundary
  targets, `casm`, `image_d64`, and the unrestricted build.
- Inspect PRG load headers, R6 trailers, code/BSS envelopes, relocation counts,
  disk directory capacity, and persistent build counters.
- Compare representative pre-WP60 valid PRG/R6/listing/map artifacts against
  the `0.2.1` baseline.
- Run a no-change rebuild and confirm no build counter increments.

### Live VICE

Follow `.agents/workflows/vice-mcp-testing.md`:

- start/identify Command64 before application dispatch;
- relay overlay `testing` before each run and `pass`/`fail` afterward;
- launch underscore names with PETSCII `$A4`;
- run `test_casm_opcodes` and require 151 legal tuple passes plus every focused
  negative/selection case, PASS banner, and shell return;
- assemble `casmopall.s`, compare against `casmopall.ref` using native `COMP`,
  and prove identical bytes;
- run every boundary harness changed in WP60 and the inherited Phase 3/4 sample;
- smoke one production `/M /L` assembly to prove reporting remains unaffected;
- keep VICE running after verification unless recovery requires restart.

## Expected Files

Planned production change:

- `src/external/casm/casm.s`
- `src/external/casm/BUILD_CASM` (generated by approved builds)

Planned test/build changes:

- `tests/src/casm_opcodes/casm_opcodes.s`
- `tests/src/casm_opcodes/BUILD_TEST_CASM_OPCODES`
- `tests/fixtures/casm/casmopall.ref.hex`
- `cmake/GenerateCasmTestFixtures.cmake`
- `CMakeLists.txt`
- only existing boundary harness files proven incomplete by Increment 2
- generated build-counter files touched by approved rebuilds

Planned records:

- this plan
- a frozen Increment 1 opcode oracle/matrix review under `brain/reviews/`
- a frozen Increment 2 boundary evidence register under `brain/reviews/`
- WP60 walkthrough under `brain/walkthroughs/`
- `brain/task.md`, `wiki/tasks/casm.md`, `CHANGELOG.md`, `brain/KNOWLEDGE.md`,
  `brain/MEMORY.md`, and applicable DOX only when their owned facts change

## Atomic Increments

### Increment 1 - Freeze the exhaustive opcode oracle

- Record all 151 mnemonic/mode/opcode/length tuples independently.
- Map each tuple to parser input shape and end-to-end fixture statement.
- Prove every production legal mask bit and packed byte has one oracle row.
- Record unsupported processor/features explicitly.
- Request user approval before adding executable fixtures.

### Increment 2 - Freeze the boundary evidence register

- Inventory existing literal/address/PC/source/symbol/VMM/relocation evidence.
- Record exact valid/invalid endpoints, diagnostics, mutation points, cleanup,
  and missing cases.
- Choose reuse/strengthen/add disposition for every required row.
- Freeze expected target/file changes and request user approval.

### Increment 3 - Structural decimal-mode hardening

- Add `CLD` as the first instruction at production `start:`.
- Verify by source inspection and entry-path trace.
- Build CASM; compare all non-banner valid artifacts against `0.2.1`.
- Record it as hardening of an implicit invariant, not a reproduced live bug.

### Increment 4 - Direct 151-tuple matcher harness

- Add `test_casm_opcodes` with independent expected tuples and coverage bitmap.
- Assert opcode/mode/length, A/carry, statement preservation, location stamping,
  SP, repeat state, and compile-time counts.
- Add focused unsupported-mode, 8-bit range, width-promotion, FORCE_ABS,
  branch, implied, and accumulator cases.
- Build narrowly and run live before expanding end-to-end artifacts.

### Increment 5 - End-to-end exhaustive artifact

- Add `casmopall.s`, independent reference bytes, and offset manifest.
- Add `casm_opcode_test_d64` without changing general-disk contents.
- Assemble and native-COMP all 151 combinations live.
- Inspect header, size, first/last tuple, and mismatch localization data.

### Increment 6 - Numeric, addressing, branch, and PC boundaries

- Reuse or strengthen parser/expression/emitter fixtures per Increment 2.
- Prove numeric-format parity, zero-page/absolute endpoints, 8-bit rejection,
  forced-absolute symbol width, all branch edges, and PC end/overflow/reset.
- Fix no production code unless a confirmed defect is disclosed and approved.

### Increment 7 - Source, symbol, VMM, and relocation boundaries

- Reuse exact existing cases first; add only frozen gaps.
- Verify accepted maxima, first rejection, diagnostics, state commit points,
  repeat behavior, cleanup, and artifact safety for every domain.
- Run any affected WP58 fault harnesses after shared-module test changes.

### Increment 8 - Consolidated build and compatibility verification

- Build every new/changed narrow target and disk, all inherited boundary
  harnesses, production image, and unrestricted build.
- Inspect sizes, envelopes, headers/trailers, relocation counts, disk capacity,
  build counters, and no-change stability.
- Compare representative `0.2.1` artifacts and run the complete live matrix.

### Increment 9 - Audit and walkthrough

- Reconcile the final oracle, production table, fixture output, and boundary
  register row by row.
- Record defects/fixes, unchanged contracts, metrics, residual risks, and manual
  confirmation steps.
- Synchronize task, knowledge, memory, changelog, and DOX records.
- Request explicit WP60 completion approval.

### Increment 10 - Version and completion gate

- Only after completion approval, change CASM `0.2.1` to `0.2.2`.
- Build once and prove the artifact delta is only version/build banner bytes
  unless an approved production opcode correction changed valid output.
- Build again and prove no-change counter/hash stability.
- Live-verify `CASM V0.2.2.<build>` and normal shell return.
- Mark WP60 and its Taskwarrior task complete only after all evidence agrees.

## Stop Conditions

Stop and request user direction if:

- the independent oracle disagrees with production and authoritative NMOS 6502
  references do not resolve which side is wrong;
- the legal combination count is not exactly 151 or the mnemonic/mode ABI has
  changed since WP56;
- exhaustive source/reference data cannot fit a bounded harness or dedicated
  disk without displacing existing coverage;
- a proposed expected-data generator would consume production opcode tables;
- a boundary gap requires a new public diagnostic, parser record, opcode/mode,
  file format, zero-page allocation, or supported language feature;
- `CLD` exposes code that intentionally depends on decimal mode;
- a valid `0.2.1` artifact changes without a confirmed and approved bug fix;
- VICE cannot be started or identified under the required workflow;
- work expands into WP61 determinism/diagnostic spot-checks or WP62 systematic
  documentation synchronization.

## Completion Criteria

WP60 completes only when:

1. all 151 documented legal opcode/mode combinations have independent direct
   matcher and end-to-end emitted-byte evidence;
2. every required boundary-register row is satisfied or explicitly re-scoped by
   user approval;
3. entry `CLD` structurally precedes all production arithmetic;
4. unsupported mode/range paths preserve diagnostics, carry, location, and SP;
5. no undocumented or non-6510 opcode is accepted;
6. all changed and affected regression targets pass live and return to shell;
7. valid artifacts remain compatible except approved defect corrections;
8. consolidated and no-change builds pass with measured envelopes;
9. records, walkthrough, Taskwarrior, and DOX agree;
10. the user explicitly approves completion and the verified `0.2.2` increment.

## Approval Decision

Approve this ten-increment WP60 plan and activate Increment 1 only, or request
changes. Approval creates a WP60 Taskwarrior child dependent on completed WP59
and updates task records; it does not authorize later increments before their
individual gates.
