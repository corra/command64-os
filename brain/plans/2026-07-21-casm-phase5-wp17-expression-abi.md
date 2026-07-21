---
feature: casm-phase5-wp17-expression-abi
created: 2026-07-21
status: awaiting-approval
---

# Plan: CASM Phase 5 WP17 - Expression ABI and Bounded Storage

## Objective

WP17 declares the Phase 0C.3 expression ABI in `common.inc` and creates the
bounded evaluator module with one nine-byte BSS record plus deterministic
initialization/accessor CODE routines. It implements no parsing, arithmetic,
symbol resolution, extraction, parser integration, or fixtures.

Taskwarrior: `3b09ea77-c325-4072-90fc-9812181a4e04`.

Prerequisite: WP16 completed with explicit user approval at CASM `0.1.18` build
1080. WP17 Taskwarrior UUID exists, is pending, has no start timestamp, and is
unblocked. Approval of this plan is required before activation or source edits.

## Reconciliation Findings

- `CASM_DIAG_PHASE4_LAST` is `$23`, so `$24-$27` are the next contiguous stable
  values. `diagnostics.s` still prints only through `$23`; WP17 reserves names
  but adds no messages and no raise sites.
- `CMakeLists.txt` already discovers `src/external/casm/*.s` with
  `GLOB_RECURSE CONFIGURE_DEPENDS`. Adding `expr.s` requires reconfiguration for
  verification but no CMake edit.
- Phase 4/WP16 measurements are 8,705 CODE+RODATA bytes, 1,127 BSS bytes, and
  408 bytes MAIN headroom. WP17 adds 9 BSS bytes plus measured CODE and must not
  enlarge `$2800`.
- The zeroed record is an initialized empty/unresolved record. It is not a valid
  accepted constant until a later evaluator routine sets `resolved`.
- The work-package version rule requires a verified `0.1.19` dry run, baseline
  restoration, explicit completion approval, and only then the final version
  and build-number increment.

## Inherited Contract

- Grammar and semantic ownership are frozen by Phase 0C.3 in
  `brain/KNOWLEDGE.md`.
- The result record contains value, flags, extraction, opaque symbol ID, and
  sign/magnitude addend fields.
- No zero-page allocation is authorized.
- The existing `$2800` MAIN envelope remains fixed.
- Existing `common.inc` ABI and diagnostics `$00-$23` remain stable. WP17
  reserves `$24-$27` without extending the printable diagnostic table.
- The evaluator acquires no resources and owns no cleanup.

## Scope

Included:

- declare named offsets and exact record size;
- declare bit masks for resolved, symbol-derived, relocatable, and
  force-absolute-width flags;
- declare full/low/high extraction and positive/negative addend values;
- reserve stable Phase 5 diagnostic constants with compile-time range checks;
- create `expr.s` with one private fixed-size result record;
- implement `exprInit` and `exprGetResult` only; and
- rely on existing `CONFIGURE_DEPENDS` source discovery and explicitly rerun
  CMake configuration; no CMake source edit is authorized.

Excluded:

- numeric conversion, checked arithmetic, lexer advancement, resolver calls,
  expression parsing, parser/emitter changes, fixtures, VMM, and relocation;
- zero-page or dynamic allocation; and
- changing existing token, parser, opcode, or diagnostic values.

## Expected Files

| File | Action |
|---|---|
| `src/external/casm/common.inc` | add expression ABI constants/assertions |
| `src/external/casm/expr.s` | add bounded record and init/accessor routines |
| `src/external/casm/casm.s` | stage increment only at completion |
| `src/external/casm/BUILD_CASM` | build-managed increment |
| `brain/plans/2026-07-21-casm-phase5-wp17-expression-abi.md` | activate/update progress |
| `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `brain/task.md` | synchronize implementation evidence |
| `wiki/tasks/casm.md`, `CHANGELOG.md` | synchronize status and functional record |
| `brain/walkthroughs/2026-07-21-casm-phase5-wp17-expression-abi.md` | verification walkthrough |

No parser, emitter, lexer, opcode, state, fixture, or CMake file is expected to
change. Discovery of such a need stops WP17 for an amended plan.

## ABI and Storage Layout

The exact record order is:

```text
+0 valueLo
+1 valueHi
+2 flags
+3 extraction
+4 symbolIdLo
+5 symbolIdHi
+6 addendSign
+7 addendMagnitudeLo
+8 addendMagnitudeHi
size = 9 bytes
```

All fields initialize to zero, which means an empty unresolved record, full
extraction, positive addend, zero identity, and zero magnitude. Callers must not
treat that record as a valid expression result until a later approved routine
sets the resolved/symbol metadata. Constants must be asserted so offsets remain
contiguous and record size remains exactly 9.

Exact constants:

```text
CASM_EXPR_VAL_LO        = 0
CASM_EXPR_VAL_HI        = 1
CASM_EXPR_FLAGS         = 2
CASM_EXPR_EXTRACTION    = 3
CASM_EXPR_SYMBOL_ID_LO  = 4
CASM_EXPR_SYMBOL_ID_HI  = 5
CASM_EXPR_ADDEND_SIGN   = 6
CASM_EXPR_ADDEND_MAG_LO = 7
CASM_EXPR_ADDEND_MAG_HI = 8
CASM_EXPR_REC_SIZE      = 9

CASM_EXPR_FLAG_RESOLVED       = %00000001
CASM_EXPR_FLAG_SYMBOL_DERIVED = %00000010
CASM_EXPR_FLAG_RELOCATABLE    = %00000100
CASM_EXPR_FLAG_FORCE_ABS      = %00001000
CASM_EXPR_FLAG_MASK           = %00001111

CASM_EXTRACTION_FULL = 0
CASM_EXTRACTION_LO   = 1
CASM_EXTRACTION_HI   = 2
CASM_EXTRACTION_COUNT = 3

CASM_ADDEND_SIGN_POSITIVE = 0
CASM_ADDEND_SIGN_NEGATIVE = 1
CASM_ADDEND_SIGN_COUNT    = 2
```

Assertions cover every adjacent offset, exact size, one-hot/non-overlapping flag
bits, mask value, and contiguous enum counts.

`exprInit`:

- inputs: none;
- outputs: record reset, A = 0, Z set, N clear;
- preserves: X, Y, C, V, D, I, zero page, and stack depth;
- implementation: explicit stores so X/Y remain preserved; no loop counter.

`exprGetResult`:

- inputs: none;
- outputs: X/Y = low/high pointer to the stable result record, C clear; N/Z
  reflect the final high-byte load into Y;
- preserves: A, V, D, I, zero page, and stack depth;
- clobbers: X, Y, N, Z, C.

The record label remains private; only `exprInit` and `exprGetResult` are
exported. Later packages use the accessor unless an amended, measured plan
authorizes exporting storage directly.

## Diagnostics

Reserve exactly:

```text
CASM_DIAG_EXPR_MALFORMED   = $24
CASM_DIAG_EXPR_UNSUPPORTED = $25
CASM_DIAG_EXPR_OVERFLOW    = $26
CASM_DIAG_RESOLVER_FAILED  = $27
CASM_DIAG_PHASE5_LAST      = $27
```

Assert `$24 = CASM_DIAG_PHASE4_LAST + 1`, contiguous values through `$27`, and
`CASM_DIAG_PHASE5_LAST = $27`. Existing numeric-literal overflow continues to
use `CASM_DIAG_OPERAND_OUT_OF_RANGE`; `$26` is for resolved expression
arithmetic overflow/underflow. WP17 does not change `diagPrintFatal`, message
tables, strings, or runtime raise sites, so invoking `$24-$27` remains forbidden
until the package that adds messages explicitly extends diagnostics.

## Atomic Increments

1. After plan approval, start WP17 in Taskwarrior and mark it active in wiki and
   brain. Capture clean baseline, build 1080, artifact measurements, and the
   `$00-$23` diagnostic range.
2. Add expression constants and compile-time assertions to `common.inc`.
3. Add bounded `expr.s` plus `exprInit`/`exprGetResult`; audit exports,
   clobbers, stack balance, and absence of zero-page/resources.
4. Run `cmake -S . -B build`, then build CASM at both bases. Inspect `expr.o`,
   linked segment sizes, relocation count, and MAIN headroom.
5. Verify record defaults statically from the explicit stores and object
   disassembly. WP17 has no runtime consumer, so do not create throwaway test
   source, fixtures, exports, or emulator-only dependencies.
6. Update records and walkthrough. Dry-run stage `18` -> `19`, verify exactly one
   build-number increment and no-change stability, compare artifacts, then
   restore `0.1.18.1080` before requesting completion approval.
7. After explicit completion approval, apply the verified `0.1.19` increment,
   rebuild twice, complete WP17, and leave WP18 pending separate approval.

## Failure and Cleanup

WP17 acquires no files, VMM blocks, handles, or output ownership. Any failure is
build-time or plan-contract failure. If record layout, diagnostic range, MAIN
headroom, or module registration conflicts, stop and amend the plan rather than
changing unrelated modules.

## Verification

- ca65/ld65 builds both relocation bases without warning/error.
- `expr.o` has exactly 9 BSS bytes, only the expected init/accessor CODE, and no
  RODATA/DATA/ZEROPAGE.
- Record offsets, flag masks, enum ranges, and diagnostic ranges are asserted.
- Public routine comments state inputs, outputs, carry/zero behavior,
  preserved/clobbered registers, stack, and scratch.
- MAIN remains within `$2800` with measured headroom.
- The completion dry run increments the build number exactly once, remains
  stable on no-change rebuild, and is restored before approval. The final
  post-approval increment reproduces those results.
- Existing Phase 4 reference manifests and disk targets remain unchanged.
- `git diff --check` passes and changed paths match this plan.

## Stop and Completion Gates

Stop if WP16 is not complete, zero page/dynamic storage becomes necessary,
existing ABI values would move, CMake/parser/emitter changes are needed, or MAIN
headroom becomes unsafe. Also stop if `expr.s` requires imports, resources,
runtime diagnostics, self-modifying code, or direct storage export. WP17
completes only after all evidence is recorded, the user explicitly approves the
walkthrough, and the verified post-approval `0.1.19` increment passes. Completion
does not activate WP18 automatically.

## Documentation and DOX

Update the plan, `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `brain/task.md`,
`wiki/tasks/casm.md`, `CHANGELOG.md`, Taskwarrior, and the WP17 walkthrough.
Re-read the root and `src`/`external`/`casm` DOX chain after source edits.
AGENTS.md changes only if a durable local contract or child index changes.

## Reserved Downstream Plan Slugs

- WP18: `2026-07-21-casm-phase5-wp18-numeric-primary.md`
- WP19: `2026-07-21-casm-phase5-wp19-symbol-resolver.md`
- WP20: `2026-07-21-casm-phase5-wp20-parser-adapter.md`
- WP21: `2026-07-21-casm-phase5-wp21-verification-closeout.md`

## Progress

- 2026-07-21: Drafted by WP16; WP17 remained inactive.
- 2026-07-21: Reconciled against the `0.1.18.1080` baseline. Fixed the
  storage-only/CODE contradiction, assigned exact `$24-$27` reservations,
  clarified zero-record semantics and complete status contracts, confirmed
  automatic source discovery and 408-byte baseline headroom, and moved the
  version increment behind the explicit completion gate. Awaiting implementation
  approval; Taskwarrior remains pending without a start timestamp.
