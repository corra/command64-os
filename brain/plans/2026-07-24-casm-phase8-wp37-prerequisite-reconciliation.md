---
feature: casm-phase8-wp37-prerequisite-reconciliation
created: 2026-07-24
status: planned
---

# Plan: CASM Phase 8 WP37 - Prerequisite Reconciliation and Phase 0C.14 Freeze

## Objective

WP37 is the first Phase 8 artifact, mirroring WP32's role for Phase 7, WP26's
role for Phase 6B, and WP22's role for Phase 6A: it verifies the Phase 7
completion gate, reconciles every dependency and discrepancy a fresh read of
the current source turned up against the master plan's Phase 8 text, and
freezes the native-R6-relocation contract (Phase 0C.14) that WP38-WP42
implement against. It implements no source, symbol, emission, or CLI change;
the only source change is the version-only completion increment, exactly as
WP22/WP26/WP32 did for their phases.

Taskwarrior: to be created by this WP. No Phase 8 Taskwarrior record exists
yet (confirmed via `task project:command64.casm all`).

Prerequisite: CASM Phase 7 is complete and approved (CASM `0.1.38` build 1142,
per `wiki/tasks/casm.md`'s Phase 7 Acceptance section and
`brain/plans/2026-07-24-casm-phase7-wp36-verification-closeout.md`). Approval
of this plan is required before activation or source edits, per the CASM
`AGENTS.md` gate.

## Baseline

- CASM `0.1.38` build 1142. MAIN headroom 189 of 13568 bytes (unchanged since
  WP36 added no production code).
- Zero page `$70-$8F` is fully allocated (32/32 bytes); no bytes remain for
  any new persistent Phase 8 zero-page state. Any new transient scratch Phase
  8 needs must reuse an existing aliased range within its own documented
  call-boundary discipline, exactly as every prior phase has.
- The master plan's Phase 8 gate text (`brain/plans/2026-07-16-casm-assembler-implementation-plan.md`,
  "Phase 8: Native R6 Relocation") calls for: defaulting to relocatable
  output while preserving `/S`; recording the code offset of each emitted
  relocatable high byte; covering absolute instruction operands, supported
  indexed/indirect operands, `.WORD` symbols, and supported high-byte symbol
  expressions; excluding constants, branches, low-byte extraction, and
  zero-page operands; rejecting non-representable expressions; checking
  output-size/table-offset/relocation-count overflow; and appending the exact
  R6 table and footer directly through native file services, never invoking
  `tools/reloc.py` at runtime.
- The R6 output contract (master plan, "R6 Output Contract" section) is: a
  2-byte PRG load address, program bytes, zero or more 16-bit little-endian
  relocation offsets, a 2-byte little-endian base address, a 2-byte
  little-endian relocation entry count, then the ASCII magic `"R6"`.
  `tools/reloc.py` (lines 84-91) is the authoritative reference
  implementation of this exact byte layout and remains a host-side
  diff-build tool for other external apps; CASM must reproduce its output
  format natively without ever invoking it.
- The user confirmed three architectural decisions ahead of this freeze
  (2026-07-24): default relocatable origin is `$3400`; Phase 8 implements
  `/S` only, deferring `.STATIC`/`.RELOC` source preamble directives to a
  later increment; the relocation table capacity cap is 4096 entries (8192
  bytes).

## Dependency Review and Discrepancies Reconciled

Direct research against the current source (not the master plan's
pre-implementation description of it) found the following:

1. **The default is inverted today, not merely absent.** `.ORG` is currently
   *required*: any byte-emitting statement before it raises
   `CASM_DIAG_ORG_REQUIRED` (`emitRequireOrg`, `emit.s`). There is no
   relocatable code path at all -- `emit.s`'s own header comment states
   "Output is a plain absolute PRG (no relocation trailer)." Phase 8 must
   flip this: `.ORG` becomes optional and, when present, forces static mode
   (unchanged behavior otherwise); when absent, the assembly defaults to
   relocatable mode at the frozen `$3400` origin. This is a bigger change
   than "add relocation on top of the existing static path" -- the existing
   `CasmOrgSet`/`emitRequireOrg` gate is the wrong shape and needs restating
   as "has any label or byte been emitted yet" rather than "has `.ORG` been
   seen yet," so a late `.ORG` (arriving after the implicit default origin
   already produced output) can still be rejected. The exact diagnostic
   mechanics (new state cell, and whether the late-`.ORG` case reuses
   `CASM_DIAG_DUPLICATE_ORG` or needs a new identifier) are left to WP38's
   own detailed plan rather than resolved here, matching this project's
   established pattern of deferring implementation mechanism while freezing
   the observable contract (see Contract item 1 below).
2. **`/S` is parsed today but is a complete no-op.** `CASM_OPT_STATIC`
   (`cli.s:299`) sets a bit in `CasmCliOptions` that is never read anywhere
   in `casm.s` or `emit.s` -- only `CASM_OPT_MAP`/`CASM_OPT_LIST` are checked
   (`casm.s:104-108`) and rejected as not-implemented. Today this is
   harmless only because static output is the *only* mode that exists;
   Phase 8 must give `/S` real meaning (force static, still requiring an
   explicit `.ORG` since static mode has no configured default -- there is
   no origin to fall back to without one).
3. **`.STATIC`/`.RELOC` are lexed but explicitly rejected as out of scope.**
   `CASM_DIRECTIVE_STATIC`/`CASM_DIRECTIVE_RELOC` tokens exist
   (`lexer.s:469,477`), but `emitDirective`'s catch-all
   (`emit.s:250-253`, comment: "`.STATIC` / `.RELOC` / `.INCLUDE`: out of
   scope this phase") raises `CASM_DIAG_NOT_IMPLEMENTED` unconditionally.
   Per the user's confirmed decision, Phase 8 leaves this exactly as it is;
   only `/S` becomes meaningful this phase. This narrows Phase 8's grammar
   surface to no new source-level directive at all -- a real scope
   reduction versus the master plan's original Phase 0 language sketch
   (which listed `.static`/`.reloc` as initial directives) that the user has
   now explicitly re-confirmed rather than left ambiguous.
4. **The relocatable-value ABI is already wired end to end and unusually
   well anticipated -- this is the single biggest scope reducer found.**
   `CASM_EXPR_FLAG_RELOCATABLE` (`common.inc:650`) already exists inside
   `CASM_RESOLVE_FLAG_MASK`, already flows unchanged from a resolver's
   output flags into the expression result (`expr.s:127-139`,
   `ora #CASM_EXPR_FLAG_SYMBOL_DERIVED` preserves whatever
   `CASM_RESOLVE_FLAGS` bits the resolver returned), and is already
   correctly *cleared* on `<` low-byte extraction while being correctly
   *preserved* on `>` high-byte extraction and on `symbol + constant` addend
   application (`expr.s:194-205`, `consumeAddend`/`applyExtraction`) -- all
   built during Phase 5/6B without a live producer, on the explicit
   assumption a later phase would supply one. The only thing missing is a
   producer: `symbols.s:388` documents today, in its own comment, that
   "symbols are always absolute, never RELOCATABLE." No `symbols.s` change
   is actually required to fix this -- see item 5.
5. **Relocatability is a property of the whole assembly's output mode, not
   of any individual symbol, given the current language's scope.** Named
   constants (a `.EQU`-like non-address symbol) do not exist until Phase 12;
   every symbol definable today is a label, i.e. an address. Under
   relocatable-mode output every label reference is therefore relocatable,
   and under static-mode (explicit `.ORG`) output no label reference is --
   there is no case in today's grammar where some labels are relocatable
   and others are not within the same assembly. This means the flag can be
   set once, generically, at `exprEvaluate`'s existing
   `resolverReturned` merge point (`expr.s:126-139`) by ORing in
   `CASM_EXPR_FLAG_RELOCATABLE` when a global relocatable-output-mode flag
   is set and the resolver reported `RESOLVED` -- **no `symbols.s` change is
   needed at all**, keeping symbol storage/lookup fully unaware of
   output-mode concepts, consistent with the module boundary discipline
   `AGENTS.md` already expects. This is a materially smaller change than the
   master plan's Base Product Decisions section implies ("Symbol records
   reserve flags for definition, reference, relocation..." -- the reserved
   record bits remain unused; classification lives in `expr.s`, not
   `symbols.s`).
6. **`symbol +/- constant` addends are always safely representable under the
   R6 common-page-delta model; no new "unrepresentable expression"
   diagnostic is provably reachable under the current grammar.** Address
   arithmetic is associative: `(base + delta) + offset + constant` equals
   `(base + offset + constant) + delta` for any page-aligned `delta`, so a
   relocatable symbol's low-byte carry into its high byte behaves
   identically regardless of which page-aligned base the program is loaded
   at, and the high byte still shifts by exactly the uniform per-page delta
   the R6 loader applies. Phase 5's grammar only supports `symbol +/-
   absoluteConstant` (no symbol-symbol arithmetic, no multiplication/shift,
   which do not exist until Phase 12) so there is no reachable combination
   today that produces a non-uniform, unrepresentable shift. This mirrors
   WP32's finding that Phase 7 needed no new diagnostic identifier: **Phase
   8 is expected to need only a relocation-table-capacity diagnostic, not an
   unrepresentable-expression one.** An implementing WP that finds a real
   counterexample amends this finding rather than inventing an ad hoc
   silent acceptance.
7. **The relocation hook has more emission sites than "wherever a high byte
   is emitted," found by tracing every VAL_HI/extracted-VAL_LO write in
   `emit.s`, not assumed from the addressing-mode table alone:**
   - `emitInstruction`'s shared "length == 3" branch (`emit.s:147-157`) is
     the single point `CASM_MODE_ABSOLUTE`, `_ABSOLUTE_X`, `_ABSOLUTE_Y`,
     and `_INDIRECT` (JMP `($nnnn)`) all pass through --
     `opcodes.s`'s `modeLength` table (`6:1,1,2,2,2,2,3,3,3,3,2,2,2`
     indexed by `CASM_MODE_*`) confirms all four addressing modes are
     length 3 and every zero-page/indexed-indirect/indirect-indexed/relative
     mode is length 2. **This means one shared hook, gated on "was this
     value symbol-derived and relocatable, and is this the VAL_HI byte of a
     full (non-extracted) operand," covers all four addressing modes with
     no per-mode branching** -- a genuine simplification over treating each
     mode separately.
   - `emitWordList`'s `VAL_HI` emission (`emit.s:366-368`, `.WORD label`) is
     a second, independent site with the identical full-16-bit-value shape.
   - **`emitByteList`'s single `VAL_LO` emission (`emit.s:319-353`) is a
     third site, easy to miss: `.BYTE >label` is already valid syntax
     today.** `applyExtraction`'s HI-extraction branch
     (`expr.s:194-196`) moves the resolved value's high byte down into
     `VAL_LO` and zeroes `VAL_HI`, which already satisfies
     `emitByteList`'s existing "`VAL_HI` must be 0" range check
     (`eblRange`, `emit.s:327-328`) -- so a relocatable `>label` value
     already assembles successfully through `.BYTE` today, silently, as an
     ordinary (currently non-relocatable) constant byte. This is a real gap
     the master plan's prose ("supported high-byte symbol expressions")
     names but does not spell out the emission site for.
   - **`emitInstruction`'s `eiTwoByte` branch (`emit.s:159-167`, length 2)
     also needs the same `>`-extraction case, but only for
     `CASM_MODE_IMMEDIATE`** -- `LDA #>label` is ordinary, common 6502
     idiom for loading a relocatable page byte, and it reaches `eiTwoByte`
     exactly like a zero-page operand does. The other length-2 modes
     (zero-page/indexed/indexed-indirect/indirect-indexed) must never be
     treated as relocatable even if a relocatable symbol's value happens to
     end up there, since those operands are inherently 8-bit zero-page
     addresses, not code/data addresses -- consistent with the master
     plan's explicit "excludes ... zero-page operands."
   Precise call-site wiring (which exact `CASM_MODE_*`/`CASM_OPKIND_*`/
   extraction combination gates each of these four sites) is left to WP40's
   own detailed plan; the contract below freezes only the observable
   classification rule.
8. **`CasmParserStmt`'s `Flags` byte already has 7 reserved, unused bits
   beyond `CASM_PARSER_STMT_FORCE_ABS` (bit 0)** (`common.inc:503-506,521`),
   added by WP28 for exactly this kind of per-statement classification. A
   `CASM_PARSER_STMT_RELOCATABLE` bit (bit 1) can be derived at the same
   site `FORCE_ABS` already is (`parser.s:491-498`, "derive from the
   expression result's flags unconditionally, before the resolved/unresolved
   branch"), from `CASM_EXPR_FLAG_RELOCATABLE` instead of
   `CASM_EXPR_FLAG_SYMBOL_DERIVED`. Because `parserParseExpressionValue` is
   the shared routine both `emitInstruction`'s operand parse and
   `emitByteList`/`emitWordList`'s per-element parse already call
   (confirmed at `emit.s:325`, `:361`), this one derivation site naturally
   reaches all four emission sites in item 7 with no per-caller duplication.
9. **No new diagnostic identifiers exist yet for Phase 8; `$30` is the next
   free value.** The highest allocated diagnostic today is
   `CASM_DIAG_PASS_MISMATCH = $2F` (Phase 6B); Phase 7 needed none (WP32
   finding, confirmed still true -- no `CASM_DIAG_` addition appears in any
   Phase 7 WP). Phase 8 needs at minimum a relocation-table-capacity
   diagnostic (item 6 above); the late-`.ORG` case (item 1) may reuse
   `CASM_DIAG_DUPLICATE_ORG` or need its own -- left to WP38.
10. **The finalize/close sequence has one clear, existing insertion point
    for the R6 table and footer.** `casm.s`'s `start` routine
    (`casm.s:161-182`) runs: `fileCreateOutput` -> Pass 2 dispatch ->
    `emitCheckPassAgreement` -> `emitFinalize` (flushes staged program
    bytes) -> `diagPrintPhase2Ready` -> `sourceClose` -> `exitSuccess`. A
    new relocation-finalize call (writing the accumulated table, base
    address, count, and `"R6"` magic through the same bounded `fileWrite`
    primitive `emitFinalize` already uses) belongs immediately after
    `emitFinalize` succeeds and before `diagPrintPhase2Ready`, gated on
    relocatable mode; static-mode output skips it entirely and the file
    closes exactly as it does today. `exitSuccess`'s existing generic
    handle-close path needs no change.
11. **VMM registry headroom is ample for a new relocation-table
    allocation.** `CASM_VMM_CAPACITY = 8`; a single assembly today uses at
    most 2 of 8 slots (the Phase 7 combined-source load and the Phase 6B
    symbol table). A third slot for the relocation table leaves 5 free,
    with no capacity pressure. Per the user's confirmed 4096-entry/8192-byte
    cap, the table fits in one `vmmStoreAlloc` request (well under the
    65535-byte single-allocation ceiling WP32 already established) and, as
    a flat append-only list of 2-byte offsets with no lookup requirement
    (unlike the hashed, padded symbol-table records), needs none of
    `symbols.s`'s chain/hash machinery -- only sequential
    `vmmWindowWrite` appends through the existing 64-byte transfer window,
    the same primitive Phase 6A already built and Phase 7 already reused
    unmodified.
12. **The R6 footer's base address is the relocatable origin itself
    (`$3400`), not a computed value.** `tools/reloc.py`'s footer
    (`struct.pack("<HH", base_addr, len(offsets))`, `reloc.py:86`) writes
    the *lower* of the two diffed builds' load addresses as the base; CASM
    has no second build to diff against, so its native footer's base field
    is simply the frozen default origin (or a future configurable one, per
    the "not this phase" branch of the origin question) written directly,
    with no arithmetic needed.

## Contract to Freeze (Phase 0C.14)

Per the user's confirmed decisions (2026-07-24):

1. **Default relocatable origin is `$3400`.** When `.ORG` is absent by the
   time the first label or byte-emitting statement is reached, the
   assembly runs in relocatable mode starting at `$3400`; when `.ORG`
   appears (as today, before any label or emitted byte), it forces static
   mode at the given address, unchanged from current behavior.
   Precedence, per the master plan's own wording, is: `/S` first (forces
   static; still requires an explicit `.ORG`, since static mode has no
   configured default), then the relocatable default. There is no
   preamble-directive tier this phase (Contract item 2 below).
2. **`.STATIC`/`.RELOC` source preamble directives remain out of scope this
   phase**, unchanged from their current `CASM_DIAG_NOT_IMPLEMENTED`
   rejection in `emitDirective`. Only the CLI `/S` option becomes
   meaningful. This is a deliberate, user-confirmed scope reduction from
   the master plan's original Phase 0 language sketch, recorded here so a
   later phase does not assume it was an oversight.
3. **A byte position is relocatable output if and only if:** (a) the
   assembly is running in relocatable mode; (b) the underlying resolved
   expression's value is symbol-derived and was classified
   `CASM_EXPR_FLAG_RELOCATABLE` (Dependency Review items 4-6: every label
   reference under relocatable mode, with any `symbol +/- constant` addend
   safely preserving that classification); and (c) the byte position is
   either the high byte of a full, non-extracted 16-bit operand or word
   value, or a single byte produced by explicit `>` high-byte extraction.
   Low-byte (`<`) extraction, zero-page operand bytes, indexed-indirect/
   indirect-indexed pointer bytes, and relative branch displacements are
   never relocatable, matching the master plan's exclusion list exactly.
   The classification bit is derived once, at `parser.s`'s existing
   `CASM_PARSER_STMT_FORCE_ABS` derivation site, as a new
   `CASM_PARSER_STMT_RELOCATABLE` bit (`CasmParserStmt.Flags` bit 1) from
   `CASM_EXPR_FLAG_RELOCATABLE` -- reaching every emission site through the
   shared `parserParseExpressionValue` call (Dependency Review items 7-8)
   with no per-caller duplication. `symbols.s` requires no change; the
   classification is applied once, generically, at `expr.s`'s existing
   resolver-merge point, gated on the relocatable-mode flag rather than on
   any per-symbol property (Dependency Review item 5).
4. **The relocation table is a flat, VMM-backed, append-only list of 16-bit
   little-endian code offsets, capped at 4096 entries (8192 bytes)**, per
   the user's confirmed decision. One `vmmStoreAlloc` request for 8192
   bytes happens once, before Pass 2's real emission begins (mirroring the
   symbol table's and Phase 7 source load's existing "pre-allocate the
   frozen bound up front" precedent); entries append sequentially through
   the existing 64-byte `vmmWindowWrite` transfer primitive; exceeding the
   cap is a new fatal diagnostic (exact identifier assigned by the
   implementing WP, starting at `$30`, the next free value).
5. **CASM never invokes `tools/reloc.py` at runtime and never diffs two
   builds.** The native table is generated directly from the classification
   in item 3 during single-pass emission, not by comparing two linked
   images. `tools/reloc.py` remains an unrelated host-side tool for other
   external applications' `add_ca65_app` builds and is not touched by this
   phase.
6. **The R6 footer's base-address field is the frozen default origin
   (`$3400`)**, written directly with no diff arithmetic (Dependency
   Review item 12). The footer byte layout matches `tools/reloc.py`
   exactly: table of 16-bit LE offsets, then 2-byte LE base address, then
   2-byte LE relocation count, then the ASCII magic `"R6"` -- written
   through the same bounded native `fileWrite` primitive `emitFinalize`
   already uses, immediately after `emitFinalize` succeeds and before
   `diagPrintPhase2Ready` (Dependency Review item 10), with no seeking.
7. **Static-mode output (`.ORG` present or `/S` given) is unaffected byte
   for byte.** Every existing static trusted-reference fixture must remain
   byte-identical; the R6 table/footer path is gated entirely on
   relocatable mode and never runs for a static assembly.
8. **No new diagnostic identifier is expected for "unrepresentable
   expression"** (Dependency Review item 6); only a relocation-table-
   capacity diagnostic is expected to be new. An implementing WP that finds
   a real counterexample amends this finding rather than adding a silent
   acceptance path.
9. **No zero-page growth.** `$70-$8F` stays fully allocated; any new
   transient scratch reuses an existing aliased range within its own
   call-boundary discipline, not frozen further here.
10. **MAIN growth is not pre-sized.** Matches every prior phase's precedent:
    each implementing WP measures its own overflow against the 189-byte
    baseline headroom and proposes a justified `add_ca65_app` size bump.

## Scope

Included in WP37:

- verifying the Phase 7 completion gate (done above);
- creating the CASM Phase 8 Taskwarrior milestone and WP37-WP42 child tasks
  in `wiki/tasks/casm.md` and `brain/task.md`;
- recording the Phase 0C.14 contract above in `brain/KNOWLEDGE.md`;
- the version-only completion increment.

Excluded from WP37 (each requires its own dedicated plan per `AGENTS.md`):

- any `emit.s`, `parser.s`, `expr.s`, `cli.s`, or `casm.s` change
  implementing optional `.ORG`, the default origin, `/S` wiring, relocation
  classification, relocation-table storage, or R6 footer serialization;
- any `common.inc` constant/record addition (`CASM_PARSER_STMT_RELOCATABLE`,
  new `CASM_DIAG_*` values, relocation-table capacity constants);
- creation of `reloc.s` or `output.s` (or an equivalent module split decided
  by the implementing WP);
- any MAIN envelope size change;
- any fixture or test harness.

Proposed WP breakdown for the implementing packages (subject to each
package's own approval, not authorized by this document):

- **WP38**: Optional `.ORG`, default relocatable origin, and `/S` wiring --
  Contract item 1. Flips `emitRequireOrg`'s gate from "has `.ORG` been seen"
  to "has any label or byte been emitted yet"; introduces the default-origin
  header write when the first such event occurs with no prior `.ORG`; wires
  `/S` to force static (Dependency Review item 2); resolves the exact
  late-`.ORG` diagnostic mechanics left open by Dependency Review item 1.
  Verified independently of relocation-table content: programs assemble and
  load correctly at the default origin with no `.ORG`, existing static
  fixtures remain unaffected, and `/S` without `.ORG` still raises
  `CASM_DIAG_ORG_REQUIRED`.
- **WP39**: Relocation classification -- Contract item 3. Adds
  `CASM_PARSER_STMT_RELOCATABLE`, the `expr.s` resolver-merge gate on a
  relocatable-mode flag (WP38's output), and the `parser.s` derivation site.
  No table storage or emission-site wiring yet; verified through a
  standalone harness proving the classification bit is set/clear correctly
  across relocatable-mode label references, `<`/`>` extraction, and addend
  combinations, mirroring WP27's isolated-module-first precedent.
- **WP40**: Relocation table storage and the four emission-site hooks --
  Contract items 4 and 3(c). New VMM-backed append-only table (`reloc.s` or
  equivalent), the capacity-overflow diagnostic, and wiring at
  `emitInstruction`'s length-3 branch, `eiTwoByte`'s `CASM_MODE_IMMEDIATE`
  case, `emitWordList`, and `emitByteList` (Dependency Review item 7).
- **WP41**: Native R6 footer serialization -- Contract items 5-6. Appends
  the table, base address, count, and magic through native file services at
  the `casm.s` insertion point identified in Dependency Review item 10;
  static-mode output path is proven unaffected.
- **WP42**: Verification, walkthrough, and Phase 8 completion gate (mirrors
  WP31/WP36's role). Loads generated R6 fixtures at multiple page-aligned
  addresses per the master plan's literal gate text, confirms static
  fixtures remain ordinary PRGs, confirms `/S` and capacity-overflow
  behavior, and independently verifies R6 footer bytes rather than treating
  CASM's own output as its own oracle (mirroring the feasibility study's
  COMP-migration principle against common-mode self-validation failures).

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-24-casm-phase8-wp37-prerequisite-reconciliation.md` | this document |
| `wiki/tasks/casm.md` | add CASM Phase 8 milestone and WP37-WP42 child tasks |
| `brain/task.md` | synchronize active work |
| `brain/KNOWLEDGE.md` | add "CASM Phase 8 WP37 Native R6 Relocation Contract (Phase 0C.14, frozen 2026-07-24)" section |
| `src/external/casm/casm.s` | version-only stage increment at completion |
| `src/external/casm/BUILD_CASM` | build-managed increment |

No source file implementing optional `.ORG`, relocation classification,
table storage, or R6 serialization is authorized by approval of this
document alone; WP38-WP42 each require their own dedicated plan and
approval.

## ABI, Storage, and Runtime Effects

None from WP37 itself. This document freezes the ABI/storage effects that
WP38 (origin/`.ORG`/`/S` state), WP39 (`CASM_PARSER_STMT_RELOCATABLE`,
`CASM_EXPR_FLAG_RELOCATABLE` producer), WP40 (relocation-table VMM record
and capacity diagnostic), and WP41 (footer serialization) will implement.

## Verification and Fixture Strategy (binding on WP38-WP42)

- WP38 fixtures: a no-`.ORG` program assembling successfully at `$3400`
  with a plausible (not-yet-relocatable) output; every existing static
  (`.ORG`-bearing) trusted-reference fixture re-confirmed byte-identical;
  `/S` with and without `.ORG`; a late-`.ORG`-after-implicit-origin failure
  case.
- WP39 fixtures: a standalone harness (mirroring `test_casm_expr`'s
  precedent) proving `CASM_PARSER_STMT_RELOCATABLE` is set for a plain
  relocatable label reference and a `symbol + constant` addend, and clear
  for `<symbol`, a numeric literal, and (once WP38 exists) any reference
  under static mode.
- WP40 fixtures: one fixture per emission site in Dependency Review item 7
  (absolute operand, absolute,X, absolute,Y, indirect JMP, `.WORD label`,
  `.BYTE >label`, `LDA #>label`), plus a relocation-table-capacity overflow
  case.
- WP41 fixtures: R6 footer field-by-field verification (load address,
  program bytes, table entries and order, base address, count, magic)
  against a hand-derived expected footer, not against CASM's own claimed
  output -- matching the codebase's trusted-reference-generation discipline
  used since Phase 4.
- WP42 bundles the full matrix into the CASM Phase 8 completion gate,
  matching the master plan's Phase 8 gate text exactly: "Command 64 loads
  and runs generated R6 fixtures at several page-aligned addresses; static
  fixtures remain ordinary PRGs."

## Atomic Implementation Increments

1. After this plan's approval, create the CASM Phase 8 Taskwarrior milestone
   and WP37-WP42 child tasks (via the `task` CLI directly if the Task
   Warrior MCP remains unavailable this session, recording the same
   information in `wiki/tasks/casm.md`/`brain/task.md` regardless).
2. Record the Phase 0C.14 contract in `brain/KNOWLEDGE.md`, cross-referencing
   this plan.
3. Update `wiki/tasks/casm.md`'s CASM Phase 8 section with the WP37-WP42
   breakdown and mark WP37 in progress, then complete.
4. Apply the version-only completion increment (stage bump only, matching
   every prior freeze WP), rebuild, confirm a no-change rebuild holds
   stable, and request completion approval.

## Failure and Cleanup

Not applicable: WP37 implements no runtime behavior. A material deviation
found after this plan's approval (e.g., a frozen decision proving
unworkable once WP38 starts writing real code) stops implementation until
this document is amended and re-approved, per every prior CASM phase's
precedent.

## Documentation and DOX Closeout

Update this plan, `brain/KNOWLEDGE.md`, `brain/task.md`, `wiki/tasks/casm.md`,
`CHANGELOG.md`, and Taskwarrior. `AGENTS.md` is not expected to change by
WP37 itself; it will need a real update once WP38 lands optional `.ORG` and
a real default output mode, since `AGENTS.md` does not currently describe
relocatable output at all.

## Stop Conditions

Stop if CASM Phase 7 is not complete and approved. Stop if a further
material discrepancy against this freeze is found during WP38-WP42
implementation, requiring this document to be amended and re-approved --
in particular, if WP40 finds a real counterexample to Dependency Review
item 6 (an expression the R6 model cannot represent), this document must be
amended before proceeding rather than adding a silent acceptance path.

## Completion Gate

WP37 is complete when the Phase 0C.14 contract above is recorded in
`brain/KNOWLEDGE.md`, the CASM Phase 8 Taskwarrior milestone and WP37-WP42
child tasks exist, the version-only increment is verified, and the user
explicitly approves. This does not activate WP38; each remains separately
gated per `AGENTS.md`.

## Progress

- 2026-07-24: Drafted after confirming CASM Phase 7's completion gate
  (`0.1.38` build 1142, 189 bytes MAIN headroom, `task project:command64.casm
  all` confirming no Phase 8 Taskwarrior record exists yet) and performing
  fresh dependency research directly against `emit.s`, `expr.s`, `parser.s`,
  `symbols.s`, `opcodes.s`, `common.inc`, `cli.s`, `casm.s`, and
  `tools/reloc.py` rather than the master plan's pre-implementation
  description of Phase 8. Found the default is inverted today (`.ORG`
  required, not optional) rather than merely absent; found the
  `CASM_EXPR_FLAG_RELOCATABLE`/`CASM_PARSER_STMT_FORCE_ABS`-sibling ABI
  plumbing already exists end to end from Phase 5/6B foresight, with only a
  producer missing, and that the producer belongs in `expr.s` (gated on a
  whole-assembly relocatable-mode flag) rather than `symbols.s`, since no
  named-constant symbol kind exists until Phase 12 and every current symbol
  is a label; found by tracing every `VAL_HI`/extracted-`VAL_LO` write in
  `emit.s` that there are four emission sites needing the relocation hook,
  not one -- including two easy-to-miss cases (`.BYTE >label` already
  parses successfully today as a silent non-relocatable constant, and
  `LDA #>label` reaches the same length-2 path as zero-page modes and must
  be distinguished from them); and found, mirroring WP32's precedent, that
  `symbol +/- constant` addend arithmetic is always safely representable
  under the R6 common-page-delta model by associativity, so no new
  "unrepresentable expression" diagnostic is expected, only a
  relocation-table-capacity one. Asked the user three architectural
  questions given these findings: default relocatable origin (recommended
  and confirmed `$3400`, matching CASM's own link address and every
  external app's `add_ca65_app` convention); whether to implement
  `.STATIC`/`.RELOC` source directives this phase (recommended and
  confirmed `/S`-only, deferring the directives); and the relocation-table
  capacity cap (recommended and confirmed 4096 entries / 8192 bytes). All
  three of the user's confirmed decisions matched the recommended options.
  Awaiting user approval before Taskwarrior creation or
  `brain/KNOWLEDGE.md` updates -- no source has been touched.
