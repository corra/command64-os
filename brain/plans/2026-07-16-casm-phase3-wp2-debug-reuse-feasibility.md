---
feature: casm-native-assembler
phase: 3
work-package: 2
created: 2026-07-16
status: approved
depends-on: casm-phase-3-wp1-task-contract-sync
---

# CASM Phase 3 Work Package 2: DEBUG Reuse Feasibility

Approved by the user on 2026-07-16. This work package determines which parts
of DEBUG's interactive assembler may safely inform CASM Phase 3 mnemonic
classification, which decisions belong to Phase 4, and which implementation
must not be reused.

WP2 is investigative. It does not modify DEBUG, CASM source, CMake, fixtures,
or build counters.

## Objective

Independently audit DEBUG's mnemonic and opcode metadata, document routine and
language-contract incompatibilities, compare three reuse strategies, choose a
bounded Phase 3 mnemonic-table source, and explicitly defer opcode/addressing
reuse to Phase 4.

## Evidence Baseline

DEBUG currently provides:

| Component | Current role |
|---|---|
| `parseMnemonic` | Reads three characters and searches 56 mnemonic entries |
| `parseOperand` | Converts an interactive operand into an addressing mode |
| `isBranchMnemonic` | Recognizes eight branch mnemonic indices |
| `parseHexWithDollar` | Parses an optional `$` and a hex value |
| `calcRelOffset` | Computes and checks an 8-bit branch displacement |
| `lookupOpcode` | Searches 256 opcode slots by mnemonic and mode |
| `writeInstruction` | Writes an instruction directly to `(currentAddr)` |
| `modeLength` | Maps 13 addressing modes to instruction length |
| `opStringTable` | Stores 56 documented mnemonics plus `???` |
| `opMnemonicIndex` | Maps opcode bytes to mnemonic indices |
| `opAddrMode` | Maps opcode bytes to addressing modes |

DEBUG Test Suite 9 covers mnemonic case handling, thirteen addressing modes,
fallback/promotion, branch ranges, and whitespace. Those tests are evidence of
DEBUG behavior, not proof that its ABI or language rules fit CASM.

## Scope

### Included

- static inventory of DEBUG routines, tables, state, and assumptions;
- independent verification of the 56 documented mnemonics;
- verification of table sizes, ordering, sentinels, and index ranges;
- compatibility analysis against Phase 0C.1;
- code/data-size estimates for Phase 3 mnemonic strategies;
- a Phase 3 reuse decision and explicit Phase 4 deferrals;
- `brain/reviews/2026-07-16-casm-debug-assembler-reuse.md`; and
- WP2 task-state synchronization after user approval.

### Excluded

- changing or refactoring DEBUG;
- sharing a runtime module between applications;
- moving DEBUG tables into an include;
- introducing table-generation tooling;
- implementing opcodes, addressing modes, or the CASM classifier;
- changing DEBUG tests or behavior; and
- marking WP2 complete without user approval.

## Increment 2.1: Authoritative Mnemonic Set

Construct an explicit independent list of the 56 documented NMOS 6502
mnemonics targeted by CASM. Do not use DEBUG's table as both subject and oracle.

Requirements:

- exactly 56 entries;
- every entry exactly three bytes;
- no duplicates;
- no undocumented opcodes;
- no 65C02-only mnemonics;
- `???` excluded; and
- branch set exactly `BCC BCS BEQ BMI BNE BPL BVC BVS`.

For each mnemonic record the canonical spelling, DEBUG index, DEBUG bytes,
match result, and recommended CASM subtype. Use repository-owned ca65/reference
material or another existing authoritative project source.

Gate: all 56 DEBUG names are independently accounted for. Any mismatch,
omission, duplicate, or undocumented entry stops reuse approval.

## Increment 2.2: DEBUG Table Structure Audit

Audit `opStringTable` for exact byte length, valid-entry count, `???` position,
valid index range, ordering, branch-index agreement, and sentinel consumers.

Audit `opMnemonicIndex` for exact 256-byte length, index range, invalid-opcode
sentinel, in-bounds references, reachability of every documented mnemonic, and
illegal-opcode consistency.

Audit `opAddrMode` for exact 256-byte length, mode range, invalid-opcode
mapping, documented-opcode coverage, and cross-table consistency.

Audit `modeLength` for exact entry count, invalid-mode behavior, and valid
one-to-three-byte lengths for every supported addressing mode.

WP2 does not approve these opcode tables for Phase 4; it determines whether
they are plausible candidates for a later exhaustive audit.

Gate: every table boundary and cross-table index is proven bounded.

## Increment 2.3: Routine Dependency Audit

For each DEBUG routine record input/output representation, BSS and zero-page
ownership, PETSCII assumptions, flag ABI, clobbers, side effects, provenance,
streaming/replay compatibility, Phase 3 relevance, and earliest safe CASM
phase.

Expected classifications:

| Routine | Direct reuse | Reason |
|---|---|---|
| `parseMnemonic` | Reject | Interactive RAM line, fixed read, DEBUG state, no provenance |
| `parseOperand` | Reject | Mixes syntax, evaluation, width choice, and mode deduction |
| `parseHexWithDollar` | Reject | Hex-only DEBUG parser conflicts with CASM numeric grammar |
| `isBranchMnemonic` | Defer concept | Phase 4/6 concern with hard-coded DEBUG indices |
| `calcRelOffset` | Defer concept | Later arithmetic requiring independent flag/range audit |
| `lookupOpcode` | Defer concept | Phase 4 concern and DEBUG-owned mode/index ABI |
| `writeInstruction` | Reject | Direct RAM write conflicts with CASM emission architecture |

Gate: no DEBUG routine is proposed for direct Phase 3 linkage or
transplantation.

## Increment 2.4: PETSCII and Case Audit

1. List every character comparison used by DEBUG assembler routines.
2. Record each assembled/runtime byte assumption.
3. Compare those assumptions with CASM's explicit PETSCII constants.
4. Check shifted and unshifted case handling.
5. Identify logic that cannot be reused without changing byte semantics.
6. Require explicit numeric PETSCII bytes in the eventual CASM implementation.

Expected conclusion: mnemonic spellings may be reused as reviewed data, but
DEBUG character-comparison code is not reusable.

## Increment 2.5: Language-Contract Comparison

| Feature | DEBUG | CASM Phase 3 | Decision |
|---|---|---|---|
| Input | 63-byte interactive line | Rewindable file stream | Incompatible ABI |
| Mnemonic | Exactly three bytes | Official mnemonic token | Data compatible |
| Case | DEBUG `toUpper` | Explicit PETSCII fold | Reimplement |
| Labels | None | Identifier tokens | CASM-only |
| Comments | None | Semicolon through newline | CASM-only |
| Directives | None | Six initial directive tokens | CASM-only |
| Unprefixed number | Hexadecimal | Decimal | Incompatible |
| Binary | Unsupported | `%` form | CASM-only |
| Provenance | None | File/line/column | CASM-only |
| Width selection | Numeric value selects ZP/ABS | Deferred and stability constrained | Do not reuse |
| Output | Direct memory write | Structured later output | Incompatible |

The unprefixed-number discrepancy is foundational: DEBUG numeric parsing must
not become CASM's lexical oracle.

## Increment 2.6: Strategy Evaluation

### Strategy A: CASM-Local Table

Use 56 three-byte entries for 168 bytes of RODATA. Search it with a bounded
classifier and omit `???`.

Advantages: no DEBUG coupling, narrow Phase 3 scope, simple verification.
Costs: duplicates 168 bytes and has up to 56 three-byte comparisons.

### Strategy B: Shared Declarative Include

Move neutral mnemonic declarations into an include consumed by both apps.

Advantages: one canonical list. Costs: DEBUG changes and regression burden,
macro/build design, wider scope, and index coupling risk.

### Strategy C: Build-Generated Tables

Create one canonical source and generate consumer-specific tables through the
permanent build system.

Advantages: strongest single-source model and later opcode validation. Costs:
new tooling and CMake changes, both application builds affected, and excessive
scope for Phase 3.

## Increment 2.7: Cost Measurements

For each strategy record CASM RODATA, CODE, BSS, zero-page use, worst-case
comparisons, affected files, DEBUG regression burden, build changes, fit within
the remaining 1,391-byte envelope, and Phase 4 suitability.

Distinguish source-table bytes, linked bytes, lookup code, alignment/padding,
and relocation impact. WP2 uses listings, map/symbol artifacts, and arithmetic
estimates only. If exact measurement requires source changes, defer it to WP9.

## Increment 2.8: Phase 3 Decision

Recommended decision:

> Use the independently verified DEBUG mnemonic ordering as reference data and
> implement a CASM-local 168-byte mnemonic table in WP9. Use explicit PETSCII
> bytes, omit `???`, and do not reuse DEBUG routines or runtime state.

Here, reuse means reuse of validated knowledge and ordering, not binary linkage
or source inclusion. User approval is required before WP9 implementation.

## Increment 2.9: Phase 4 Deferrals

Defer to Phase 4:

- full trust of `opMnemonicIndex`, `opAddrMode`, and `modeLength`;
- opcode-table representation and possible shared metadata;
- zero-page-to-absolute promotion and accumulator/implied fallback;
- branch recognition and displacement calculation;
- instruction writing and output-event design; and
- whether shared declarative metadata justifies DEBUG regression scope.

The Phase 4 audit must cover all 256 opcode slots using a trusted expected-byte
oracle.

## Increment 2.10: Review Record

Create `brain/reviews/2026-07-16-casm-debug-assembler-reuse.md` containing:

1. executive decision;
2. evidence sources;
3. component inventory;
4. mnemonic completeness table;
5. table structure audit;
6. routine dependency matrix;
7. PETSCII findings;
8. language-contract comparison;
9. strategy size/coupling comparison;
10. Phase 3 decision;
11. Phase 4 deferrals;
12. risks and unresolved questions;
13. verification evidence; and
14. user approval status.

WP9 cites this review as its mnemonic-table authority.

## Increment 2.11: Task and Knowledge Synchronization

After the investigation and user decision:

- mark the WP2 Taskwarrior child complete only after user approval;
- mark WP2 complete in `wiki/tasks/casm.md` and `brain/task.md`;
- record the approved reuse decision, not the full audit, in
  `brain/KNOWLEDGE.md`;
- activate WP3; and
- leave the Phase 3 parent open.

## Verification

WP2 passes when:

- all 56 mnemonics independently match;
- `???` is excluded from CASM;
- every DEBUG table boundary and index relationship is documented;
- every assembler routine has a reuse classification;
- PETSCII and numeric-language incompatibilities are explicit;
- all three strategies have size, coupling, and verification estimates;
- Phase 3 and Phase 4 reuse decisions are separated;
- no DEBUG, CASM, CMake, build-counter, or fixture file changed;
- `git diff --check` passes;
- task records agree after approval; and
- the user approves the decision and WP2 completion.

## Stop Conditions

Stop and request direction if:

- DEBUG differs from the independent 56-mnemonic set;
- a table index escapes its documented bounds;
- DEBUG tables contain documented-opcode errors;
- sharing becomes necessary to fit CASM's memory envelope;
- the audit exposes a DEBUG defect requiring remediation;
- the recommendation would require modifying DEBUG; or
- exact measurement requires unapproved experimental implementation.

