---
feature: casm-phase5-minimal-expression-evaluator
created: 2026-07-20
status: planned
---

# Plan: CASM Phase 5 Minimal Expression Evaluator

## Goal and Rationale

Phase 5 introduces a bounded, relocation-aware expression evaluator between
the lexer and later symbol/emission phases. It replaces the parser-owned
numeric-only conversion path with one structured result contract while
preserving every valid Phase 4 numeric program byte-for-byte.

The evaluator must classify unresolved and relocatable symbol expressions
without implementing the VMM store, symbol table, two-pass assembly, or R6
writer that belong to Phases 6A, 6B, and 8.

## Prerequisite Gate

Phase 5 implementation must not begin until Phase 4 is complete. Completion
requires all Phase 4 acceptance checks, a walkthrough containing automated and
manual evidence, user runtime confirmation, and explicit user approval to mark
Phase 4 done.

**Dependency re-review, 2026-07-21.** The original gate below was written before
WP14 ran. Most of it is now satisfied; the remaining blocker is WP15 alone.

| Original premise (2026-07-20) | Status on 2026-07-21 |
|---|---|
| WP14 (`3e4eab43`) pending | **Resolved** — completed and merged; CASM `0.1.16` build 1078 |
| WP15 (`8612c2a2`) pending | **Still open** — the sole remaining Phase 4 blocker |
| No Phase 4 walkthrough exists | **Resolved** — `brain/walkthroughs/2026-07-20-casm-phase4-wp14-orchestration-binary-validation.md` |
| Wiki/Taskwarrior UUIDs disagree | **Resolved** — placeholder UUIDs `d1e2f3a4`/`c2a3b4c5` replaced with the real ones during WP14 |
| Phase 4 acceptance items unchecked | **Partly resolved** — still unchecked in `wiki/tasks/casm.md`, but six of the seven now have WP14 evidence; ticking them is WP15's job, not Phase 5's |

WP14 additionally produced evidence the original gate did not anticipate: three
hand-derived trusted reference PRGs, a 23-fixture acceptance matrix executed and
passed at runtime, and two defects found and fixed (a bare `.ORG` silently
assembling as `.ORG $0000`, and an unreachable `CASM_MODE_ZEROPAGE_Y` that
miscompiled every `LDX $10,Y` as absolute,Y).

The earlier note that "`casm.s` already contains parser, opcode matcher, and
emitter dispatch — that is implementation evidence, not completion evidence" was
correct and was borne out: the WP14 audit found the driver already satisfied the
production contract, but the acceptance work still surfaced two real defects.

**The gate therefore reduces to a single condition: Phase 4 WP15 must complete
and the user must explicitly approve Phase 4 done.**

**GATE SATISFIED 2026-07-21.** WP15 completed and the user explicitly approved
Phase 4 done at CASM `0.1.17` build 1079. Phase 4 milestone
`4796b60c-5f4a-43c7-8270-436075bb3f7b` is closed and
`project:command64.casm` is 37/37 complete. Phase 5 implementation is
**unblocked**, beginning with WP16.

Evidence:
`brain/walkthroughs/2026-07-20-casm-phase4-wp15-phase-verification-closeout.md`.

Two Phase 4 observations WP15 carried forward are relevant to Phase 5 and should
be read before WP17 is approved:

- CASM has no entry `CLD`. It contains no `SED` and every `ADC`/`SBC` path
  establishes carry, but it assumes the caller left decimal mode clear. The
  frozen contract below says decimal mode is "never assumed or enabled" — that
  wording should be reconciled with the code, or the evaluator should not rely
  on it being stronger than it is.
- `parseNumericValue` already enforces the unsigned `$0000..$FFFF` bound with a
  24-bit sticky-overflow check and raises `CASM_DIAG_OPERAND_OUT_OF_RANGE`
  (`$1E`). WP18's "move or reuse" decision inherits that behaviour and must not
  weaken it.

## Frozen Phase 5 Contract

### Grammar

```text
expression  := extraction? primary addend?
extraction  := "<" | ">"
primary     := number | identifier
addend      := ("+" | "-") number
```

- Extraction applies to the final `primary +/- addend` value.
- Bare numeric literals and bare symbols are valid.
- Only a symbol-derived primary may have an addend in Phase 5.
- A numeric primary followed by `+` or `-` is rejected in Phase 5.
- Parentheses, unary negation, chained operators, symbol-to-symbol arithmetic,
  and current-PC expressions are deferred.
- Existing decimal, hexadecimal, and binary literal spelling remains stable.
- Identifiers remain case-sensitive.

### Numeric and Addend Semantics

- Numeric literals are unsigned 16-bit values in `$0000..$FFFF`.
- The addend is represented as an explicit sign plus a 16-bit magnitude. This
  covers the approved `symbol-$FFFF` through `symbol+$FFFF` source range
  without imposing an unrelated signed-16-bit limit.
- When a symbol is resolved, evaluation must reject a mathematical result
  outside `$0000..$FFFF`; arithmetic must not silently wrap.
- When a symbol is unresolved, the evaluator retains the signed addend and
  defers the final range check until resolution.
- Decimal mode must not be assumed or enabled. Every `ADC` and `SBC` path must
  establish carry explicitly.

### Result Record

The bounded result contains:

```text
valueLo, valueHi
flags:
  resolved
  symbolDerived
  relocatable
  forceAbsoluteWidth
extraction: full | low | high
symbolIdLo, symbolIdHi
addendSign
addendMagnitudeLo, addendMagnitudeHi
```

- `valueLo/valueHi` is valid immediately for constants and resolved symbols.
- `symbolId` is an opaque 16-bit identity supplied by the resolver interface;
  the evaluator never manufactures identities from hashes or token addresses.
- Unresolved symbolic operands set `forceAbsoluteWidth`. They must not select
  zero-page encoding from a placeholder value, so instruction sizes remain
  stable between passes.
- Low-byte extraction is never an R6 relocation candidate.
- High-byte extraction of a relocatable symbol remains classified as
  potentially relocatable for Phase 8.
- Phase 5 classifies metadata but creates no relocation entries and writes no
  output bytes.

### Resolver Boundary

Phase 5 defines an identifier resolver ABI but does not implement the
production symbol table. The resolver returns:

- opaque 16-bit symbol identity;
- resolved/unresolved state;
- resolved 16-bit value when available; and
- absolute/relocatable classification.

A deterministic fixture resolver supplies this ABI for Phase 5 verification.
Phase 6B implements the production resolver on top of the Phase 6A VMM record
store. This keeps the dependency order:

```text
Phase 5 evaluator contract
  -> Phase 6A VMM records
  -> Phase 6B symbol table and two-pass resolution
  -> Phase 8 R6 relocation consumption
```

### Routine Result Contract

- Carry clear: the expression is accepted and the result record is valid.
- Carry set: `A` contains a stable `CASM_DIAG_*` value and callers must not
  consume the result.
- The detailed implementation plan for each work package must document all
  A/X/Y, zero-page, BSS, lexer lookahead, and status-flag clobbers before that
  package is approved.

## Scope

Included:

- structured expression result and resolver ABI;
- checked reuse or extraction of the existing numeric converter;
- numeric and identifier primaries;
- one optional symbol addend;
- full, low-byte, and high-byte extraction;
- malformed-expression and range diagnostics;
- parser adapter for expression positions;
- deterministic expression fixtures independent of instruction emission; and
- byte-for-byte Phase 4 numeric regression verification.

Excluded:

- symbol storage or definition processing;
- VMM allocation or record access;
- labels and Pass 1/Pass 2 orchestration;
- branch resolution;
- relocation record generation or R6 serialization;
- includes, maps, listings, constants, parentheses, macros, or expanded
  arithmetic.

## Proposed Work Packages

### WP16: prerequisite reconciliation and Phase 0C.3 freeze

**Scope corrected 2026-07-21.** As originally written, WP16's first bullet was
"Close Phase 4 through its existing verification and user-approval gate" — which
is the entire purpose of Phase 4 **WP15**. Two work packages in different phases
cannot both own Phase 4 closure. That bullet was a hedge written when WP14 and
WP15 were both open and Phase 5 planning assumed it might have to clean up after
an unfinished Phase 4; WP14 has since completed cleanly and WP15 is active.

Ownership is therefore split:

- **WP15 (Phase 4) owns Phase 4 closure**: the independent acceptance audit,
  ticking the Phase 4 acceptance list in `wiki/tasks/casm.md`, and obtaining the
  user's explicit "Phase 4 is done" approval.
- **WP16 (Phase 5) owns only Phase 5 entry**: it *verifies* that gate is
  satisfied rather than performing it, then freezes the Phase 5 contract.

WP16 scope:

- Verify the Phase 4 completion gate is satisfied (a precondition check, not the
  closure work itself) and stop if it is not.
- Record the Phase 0C.3 expression result and resolver contracts in
  `brain/KNOWLEDGE.md`, following the existing CASM Phase 1/2/3 contract
  sections.
- Create the Taskwarrior records for WP17-WP21, which do not yet exist, and
  register the Phase 5 milestone in `wiki/tasks/casm.md` and `brain/task.md`.
- Write and obtain approval for each later dedicated work-package plan.
- Change no CASM source and no build inputs.

Residual record-sync work from the original bullet is already done: the
placeholder wiki UUIDs were corrected during WP14, so WP16 inherits no UUID
discrepancy.

### WP17: expression ABI and bounded storage

- Declare result offsets, flags, extraction values, resolver outputs,
  diagnostics, and compile-time size/range assertions in `common.inc`.
- Create `expr.s` with evaluator-private bounded workspace.
- Add no zero-page allocation unless an amended plan proves it necessary.
- Verify linked and BSS headroom in the approved `$2800` MAIN envelope.

### WP18: numeric primary and checked arithmetic core

- Move or reuse `parseNumericValue` so parser and evaluator cannot diverge.
- Preserve decimal/hex/binary behavior and 16-bit overflow diagnostics.
- Implement sign/magnitude addend parsing and resolved range checks.
- Audit every carry-dependent arithmetic path.

### WP19: symbol, extraction, and resolver behavior

- Accept identifier primaries and invoke the resolver once per expression.
- Preserve identity, state, value, relocation class, and signed addend.
- Implement extraction after expression evaluation.
- Reject unsupported relocation algebra and malformed token sequences.

### WP20: parser adapter and expression fixture harness

- Replace direct parser calls to `parseNumericValue` with the expression API.
- Permit number, identifier, `<`, and `>` at expression starts.
- Apply one expression grammar to instruction operands and numeric directives.
- Use a deterministic fixture resolver without adding permanent test syntax.
- Keep expression verification independent of instruction emission.

### WP21: verification, walkthrough, and completion gate

- Verify expression fixtures and all error boundaries.
- Byte-compare existing Phase 4 reference programs before and after Phase 5.
- Build CASM, the test image, and release image; inspect artifact structure,
  BSS, relocation count, and MAIN headroom.
- Confirm a no-change rebuild preserves `BUILD_CASM`.
- Ask the user to execute the supported runtime matrix.
- Create the walkthrough and request explicit approval before marking Phase 5
  or its parent milestone done.

## Expected Files

| File | Action | Responsibility |
|---|---|---|
| `brain/plans/2026-07-20-casm-phase5-minimal-expression-evaluator.md` | Create | Parent contract and dependency plan |
| `brain/plans/2026-07-21-casm-phase5-wp16-prerequisite-reconciliation.md` | Created | Detailed WP16 plan |
| `brain/plans/<phase5-wp-slug>.md` | Create later | Dedicated approved plan per WP17-WP21 |
| `src/external/casm/common.inc` | Modify later | Result/resolver ABI and diagnostics |
| `src/external/casm/expr.s` | Create later | Bounded evaluator |
| `src/external/casm/parser.s` | Modify later | Expression adapter |
| `src/external/casm/state.s` | Review later | Persistent storage only if justified |
| `src/external/casm/diagnostics.s` | Modify later | Stable expression diagnostics |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify later | Expression fixtures |
| `CMakeLists.txt` | Review/modify later | Source and fixture target registration |
| `wiki/tasks/casm.md` | Modify in WP16 | Milestone and measurable subtasks |
| `brain/task.md` | Modify in WP16 | Active work synchronization |
| `brain/KNOWLEDGE.md` | Modify in WP16 | Durable contract rationale |

No source or task file listed as a later action is authorized by approval of
this parent contract alone.

## Failure and Cleanup Behavior

- Expression failures return a diagnostic and acquire no resources.
- The evaluator must not close files, abort output, free VMM, or invoke
  `DOS_EXIT`; the existing orchestration remains the resource owner.
- Resolver failures propagate through the evaluator without losing the
  original source location.
- A material ABI, grammar, memory, or dependency change stops implementation
  until the affected work-package plan is amended and re-approved.

## Verification Plan

Expression fixtures cover:

- literal minima/maxima and overflow in every radix;
- resolved absolute and relocatable symbols;
- unresolved symbols and forced-absolute-width classification;
- `+0`, `-$0000`, `+$FFFF`, and `-$FFFF` addends;
- resolved arithmetic underflow and overflow;
- full, low-byte, and high-byte extraction;
- case-sensitive symbol identities;
- missing primaries/addends, repeated operators, chained arithmetic,
  symbol-to-symbol arithmetic, numeric arithmetic, and trailing garbage; and
- identical Phase 4 numeric PRG bytes before and after parser integration.

Repository verification follows the CASM-local DOX contract: do not use the
broken `c64-testing` MCP or a web emulator; inspect build artifacts with
repository tooling and ask the user to perform runtime checks locally.

## Documentation and DOX Closeout

Every implemented work package updates the task records and required brain
artifacts. Functional completion also updates the changelog, memory/session
state, and walkthrough. The DOX chain is re-read after edits; AGENTS.md files
change only if the implementation changes a durable local contract.

## Completion Gate

Phase 5 is complete only when WP16-WP21 are complete, automated evidence and
the manual walkthrough are recorded, the user explicitly approves completion,
and task/wiki/brain records agree. Planning this phase does not activate it and
does not close Phase 4.

## Progress

- 2026-07-20: Contract saved after dependency review. Phase 5 remains planned
  and blocked from implementation by the incomplete Phase 4 WP14/WP15 gates.
- 2026-07-21: Dependency re-review after WP14 completed and merged. Three of the
  five prerequisite-gate premises were stale and have been corrected; the gate
  now reduces to the single condition that Phase 4 WP15 completes and the user
  approves Phase 4 done.

  Ownership collision resolved: WP16's original first bullet, "Close Phase 4
  through its existing verification and user-approval gate", duplicated Phase 4
  WP15's entire purpose. Two work packages in different phases cannot both own
  Phase 4 closure. WP15 now owns closure; WP16 only verifies it, with a stop
  condition if unsatisfied.

  Also found: Taskwarrior holds no WP16-WP21 tasks (36 tasks, 35 complete, WP15
  the only pending entry), so WP16 must create them before `brain/task.md` has
  anything to synchronize against. And `brain/KNOWLEDGE.md` carries CASM Phase
  1/2/3 contract sections but no Phase 4 section; WP16 adds the Phase 5 / 0C.3
  contract and deliberately does not author a retroactive Phase 4 one, which
  would create a second source of truth for a closed phase. That gap is deferred
  to Phase 11 documentation hardening.

  Detailed WP16 plan recorded at
  `brain/plans/2026-07-21-casm-phase5-wp16-prerequisite-reconciliation.md`.
  Phase 5 remains blocked; WP16 itself is blocked on WP15.

- 2026-07-21 (later): **Phase 4 closed with explicit user approval** at CASM
  `0.1.17` build 1079; the Phase 5 prerequisite gate is satisfied and Phase 5 is
  unblocked. WP15's independent audit found three record defects (a missing
  Phase 4 parent Taskwarrior milestone, three phantom wiki UUIDs for WP11-WP13,
  and stale Phase 3 milestone text) and closed WP14's two open evidence gaps: a
  predicted output-file deletion hazard was **falsified** — assembling over an
  existing output neither clobbers nor corrupts it. WP16's baseline references to
  `0.1.16` / build 1078 are superseded by `0.1.17` / 1079.
