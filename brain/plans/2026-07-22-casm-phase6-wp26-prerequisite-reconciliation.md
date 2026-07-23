---
feature: casm-phase6-wp26-prerequisite-reconciliation
created: 2026-07-22
status: planned
---

# Plan: CASM Phase 6B WP26 - Prerequisite Reconciliation and Phase 0C.5 Freeze

## Objective

WP26 is the first Phase 6B artifact, mirroring WP22's role for Phase 6A: it
verifies the Phase 6A completion gate, reconciles every dependency and
discrepancy a fresh read of the current source turned up, and freezes the
symbol-table/two-pass contract (Phase 0C.5) that WP27-WP30 implement against.
It implements no symbol-table or pass source; the only source change is the
version-only completion increment, exactly as WP22 did for Phase 6A.

Taskwarrior: to be created by this WP (see Atomic Implementation
Increments). No Phase 6B Taskwarrior record exists yet.

Prerequisite: CASM Phase 6A is complete and approved (CASM `0.1.27` build
1102, commit range ending `3fd1f10`..WP25's completion, per
`wiki/tasks/casm.md`'s "Phase 6A Acceptance" section and
`brain/plans/2026-07-21-casm-phase6-wp25-verification-closeout.md`).
Approval of this plan is required before activation or source edits, per the
CASM `AGENTS.md` gate.

## Baseline

- CASM `0.1.27` build 1102. `MAIN: start = $3400, size = $2B00` (11008
  bytes), measured with 133 bytes free as of WP24's `$2A00 -> $2B00` bump;
  WP25 added only a test harness and version digits, so headroom is
  materially unchanged.
- Zero page `$70-$8F` is fully allocated (32/32 bytes); the `CasmPassScratch0-3`
  ($88-$8B) and `CasmExprScratch0-3` ($84-$87) groups are reserved for this
  phase's use per WP22's dependency review, item 2.
- No symbol, hash, or two-pass code exists. `parserParseExpressionValue`
  (`parser.s`) hard-fails on every unresolved identifier via
  `parserRejectIdentifier`; `opcodesFindOpcode` (`opcodes.s`) has no channel
  to any expression-resolution flag; `casm.s`'s `startParseLoop` is a single
  forward pass whose own comment records that it "must not anticipate the
  later Pass 1/Pass 2 architecture."
- `CASM_DIAG_PHASE6A_LAST = $2B` is the last assigned diagnostic. No
  duplicate-symbol, undefined-symbol, symbol-table-full, or pass-mismatch
  diagnostic exists yet.

## Dependency Review and Discrepancies Reconciled

Direct research against the current source (not the Phase 6 parent plan's
description of it, which predates Phase 6A's implementation) found the
following, beyond what the parent plan's own dependency review already
flagged:

1. **`opcodesFindOpcode` has no channel to `forceAbsoluteWidth` at all --
   confirmed, not merely unaudited.** `CasmParserStmt`
   (`CASM_PARSER_STMT_SIZE = 6`: Type/Subtype/OpKind/ValLo/ValHi/RegSubtype)
   carries no flags field. `opcodesFindOpcode`'s zero-page-vs-absolute
   decision (`opcodes.s:133-187`) is purely "does `ValHi` happen to be
   zero" -- it was written before any symbol table existed and cannot
   distinguish "genuinely a zero-page constant" from "an unresolved forward
   reference that happens to read as zero right now." The parent plan's
   dependency item 4 described this as needing a static audit; the audit is
   done and the answer is that the channel does not exist and must be
   built. **Resolved per user decision below (Contract to Freeze, item 3):
   grow `CasmParserStmt` to 7 bytes.**
2. **`parserParseExpressionValue` must stop hard-failing on unresolved
   identifiers.** Its current `pevUnresolved` path (`parser.s:408-411`)
   returns `CASM_DIAG_RESOLVER_FAILED` for any unresolved result -- correct
   for Phase 5, where no symbol table exists and every identifier must fail.
   Phase 6B's Pass 1 resolver legitimately returns "not yet defined" for a
   forward-referenced label, and that must not be a hard parse failure: the
   master plan requires forward references to assemble via the two-pass
   model, using absolute width until Pass 2 resolves them. **Resolved:
   WP28's Pass 1 driver must accept an unresolved-with-`FORCE_ABS` result as
   valid (store the flag, use a placeholder value of `$0000` for sizing
   purposes only, and never emit it), while Pass 2 treats a still-unresolved
   result as `CASM_DIAG_UNDEFINED_SYMBOL` -- a real, terminal error. This
   is a pass-mode-dependent interpretation of the same resolver output, not
   a change to the Phase 5 expression ABI itself.**
3. **The statement grammar has no label-definition production yet, and a
   naive fix would silently corrupt the label name.** `parserParseStatement`'s
   `ppsSyntaxError` path (`parser.s:120-124`) rejects any statement beginning
   with `IDENTIFIER` outright ("Labels and symbols are out of scope" -- a
   Phase 4 restriction the master plan's Phase 6B scope explicitly lifts:
   "Pass 1: address assignment, label/definition insertion"). The first draft
   of this plan assumed a label production could parse `LOOP: LDA #0` as one
   combined statement and optionally continue into the trailing instruction
   grammar. Tracing it against the actual token lifecycle found a real bug in
   that assumption: `CasmTokenText`/`CasmTokenRecord` are a single transient
   buffer that `lexerNext` overwrites on every call (`state.s`'s Phase 3
   contract), so if the parser calls `lexerNext` again to check for a
   trailing instruction after consuming `LOOP` and `:`, the label's name is
   destroyed before any caller can read it back out. **Resolved below
   (Contract to Freeze, item 6): a label definition is its own complete,
   self-terminating statement ending at the colon -- it does not try to also
   parse a trailing instruction in the same call. The driver simply calls
   `parserParseStatement` again for whatever follows on the same physical
   line, exactly as it already does for any two back-to-back statements. The
   label's name is copied into a new persistent buffer *before* any further
   `lexerNext` call, precisely mirroring the existing `CasmStmtLoc*`
   precedent (state kept parallel to `CasmParserStmt` rather than crammed
   into it).**
4. **`casm.s`'s `startParseLoop` needs a real rewrite, not a patch.** Its own
   WP14 comment anticipates this ("must not anticipate the later Pass 1/Pass
   2 architecture"), confirming the loop is expected to change materially
   rather than gain a conditional branch. **Resolved below (Contract to
   Freeze, item 1): WP28/WP29 replace the single loop with two driven
   passes sharing the same per-statement dispatch, gated by `CasmPassMode`.
   `emitInit` -- which zeroes `CasmOrgSet`/`CasmPcOverflow`/`CasmEmitLen` --
   must be called once at the start of *each* pass, not once total, or Pass
   2 would silently resume from Pass 1's already-advanced state and double
   every address.**
4a. **`lexerInit`'s doc comment already anticipates exactly this reuse.**
   Confirmed by direct inspection (`lexer.s:52-56`): "Orchestration calls
   this at startup and again after any successful `sourceRewind`." This is
   pre-existing WP7 design, not a new decision Phase 6B needs to invent --
   Pass 2's restart sequence (`sourceRewind` then `lexerInit`) is already the
   documented contract, simply not yet exercised by any caller.
5. **No hash algorithm, bucket count, or symbol-record layout exists to
   reconcile against -- confirmed, as the parent plan already noted.**
   Frozen from scratch below (Contract to Freeze, items 4-5), per the user's
   confirmed scale decision (128 buckets / 512 symbols).
6. **MAIN growth is now a near-certainty, not a maybe.** WP24 already
   consumed most of the `$2A00 -> $2B00` bump for a comparatively narrow
   windowed-transfer module. Phase 6B adds a symbol table, a 256-byte RAM
   hash-bucket array (128 buckets x 2-byte head-record-index), Pass 1/Pass 2
   orchestration in `casm.s`, and label-statement parsing -- all
   substantially larger than Phase 6A's scope. **Resolved: no size is
   pre-approved here; each implementing WP (WP27 for the bucket array and
   storage, WP28/WP29 for pass orchestration) measures its own overflow and
   proposes a justified size, exactly matching the WP13/WP19/WP23/WP24
   precedent this plan does not want to break.**
7. **Diagnostic numbering must stay contiguous.** `CASM_DIAG_PHASE6A_LAST =
   $2B`. Phase 6B's new diagnostics must begin at `$2C` and each phase-range
   sentinel/assert pattern already established in `common.inc` must be
   extended, not replaced.
8. **`CasmPassMode` needs a storage location, and zero page is full.**
   Per the user's confirmed answer (single mode flag, not an event bus),
   `CasmPassMode` is read once per `emitByte`/`emitRawByte` call -- frequent,
   but not a per-cycle hot path requiring zero-page speed. **Resolved:
   `CasmPassMode` lives in ordinary BSS (`emit.s`), not zero page, since the
   $70-$8F budget is already fully committed and this cell does not need
   indirect addressing.**

## Contract to Freeze (Phase 0C.5)

Per the user's confirmed decisions (2026-07-22):

1. **Pass-mode threading: a single mode flag, gated at exactly one point.**
   `CasmPassMode` (new BSS byte in `emit.s`) takes `CASM_PASS_MODE_MEASURE`
   or `CASM_PASS_MODE_EMIT`. Tracing every byte-emission path confirmed a
   single natural gate: `emitRawByte` is the sole routine that touches
   `CasmEmitBuffer`/`fileWrite` -- `emitByte` calls it for every operand and
   instruction byte, and `emitOrg` calls it directly for the two PRG
   header bytes. Placing one check at the top of `emitRawByte` ("if
   `CasmPassMode = MEASURE`, return success immediately without touching the
   buffer or calling `fileWrite`") is sufficient and requires no second check
   anywhere else:
   - `emitByte`'s `CasmPc` advance and overflow/range checks live in
     `emitByte` itself, above its call to `emitRawByte`, so they still run
     unconditionally in `MEASURE` mode -- Pass 1 gets accurate addresses and
     overflow detection with zero duplicated logic.
   - `emitOrg`'s header write becomes a no-op in `MEASURE` mode automatically,
     which is exactly what Pass 1 needs: no output file exists yet
     (`fileCreateOutput` is not called before Pass 1).
   - `emitFinalize`/`emitFlush` need no mode check at all: since
     `CasmEmitLen` is never incremented in `MEASURE` mode, `emitFlush`'s
     existing `CasmEmitLen == 0 -> no-op` path already does the right thing.
   `parser.s` and `opcodes.s` require no pass-mode awareness for addressing-
   mode/operand resolution -- they already only consume whatever `CasmPc` and
   symbol state are current, and both passes drive them identically.
   `parser.s`'s `parserParseExpressionValue` is the one exception (see item 3
   below): it must consult `CasmPassMode` to decide whether an unresolved
   symbol is acceptable (Pass 1) or fatal (Pass 2). Structured "emission
   events" for a future listing consumer (the master plan's Phase 10 wording)
   are explicitly deferred to Phase 10 itself, when that consumer's actual
   shape is known, rather than speculatively built now against a guess.
2. **`casm.s` orchestration: two driven passes over one shared per-statement
   dispatch.** `startParseLoop`'s existing dispatch (parse statement ->
   classify -> opcode-match/emit-directive) is factored so both passes call
   it: Pass 1 runs with `CasmPassMode = MEASURE`, `sourceOpen` once, driving
   to `EOF`, inserting label definitions into the symbol table as they are
   parsed and never creating the output file. Pass 2 calls `sourceRewind`
   (closes and reopens the file, resets source/lexer state per the existing
   contract) and `lexerInit` again (lookahead is lexer-owned and
   `sourceRewind` does not invalidate it -- WP7's existing contract), sets
   `CasmPassMode = EMIT`, creates the output file, and re-drives the same
   dispatch for real. A Pass 1/Pass 2 disagreement (different final `CasmPc`,
   or a size mismatch surfaced by WP30) is `CASM_DIAG_PASS_MISMATCH`, a
   terminal internal error routed through the existing `exitFatal` path --
   never a recoverable diagnostic.
3. **`CasmParserStmt` grows from 6 to 7 bytes.** New
   `CASM_PARSER_STMT_FLAGS` byte (offset 6), bit 0 =
   `CASM_PARSER_STMT_FORCE_ABS` (mirrors `CASM_EXPR_FLAG_FORCE_ABS`).
   `CASM_PARSER_STMT_SIZE`'s assert is updated to 7 in the same change.
   Exactly three existing write sites populate `CasmParserStmt` wholesale and
   must each initialize the new byte explicitly, or it is live uninitialized
   BSS the first time a diagnostic or opcode match reads it -- the same class
   of bug `diagClearLoc` exists to prevent for `CasmDiagLoc*`. Confirmed by
   grepping every `sta CasmParserStmt` site in `parser.s`; only these three
   write the *whole* record rather than a single field:
   - `ppsEmpty` (`parser.s:76-86`, the NEWLINE/EOF empty statement) -- set
     `Flags = 0`.
   - `ppsMnemonic` (`parser.s:88-95`, before dispatching into the operand
     grammar) -- set `Flags = 0`; `parserParseExpressionValue` (below) sets
     the real value only when an operand expression is actually parsed.
   - `parserParseExpressionValue` (`parser.s:383-406`) -- this is the
     production write site. It copies `CASM_EXPR_FLAG_FORCE_ABS` from the
     Phase 5 result into `CASM_PARSER_STMT_FORCE_ABS` in the same branch that
     already copies `ValLo`/`ValHi`.
   - The new label-statement write site (item 6 below) also zeroes `Flags`
     as part of its own wholesale initialization.

   `opcodesFindOpcode` checks `CASM_PARSER_STMT_FORCE_ABS` before applying
   its zero-page-shrink heuristic: when set, the absolute/absolute-indexed
   path is taken unconditionally regardless of `ValHi`.

   **The resolver callback stays pass-agnostic; only `parserParseExpressionValue`
   becomes pass-mode-aware.** Re-reading `expr.s`'s `identifier` branch
   (`expr.s:108-138`) found that `exprEvaluate` already sets
   `CASM_EXPR_FLAG_FORCE_ABS` automatically whenever the resolver reports
   `RESOLVED` clear (`unresolved: ... ora #CASM_EXPR_FLAG_FORCE_ABS`) --
   this is existing, unchanged Phase 5 logic, not something Phase 6B adds.
   The Phase 6B resolver callback (`symbols.s`, bound in place of
   `parserRejectIdentifier`) therefore only needs to report "found and
   defined" (`RESOLVED` set, value valid) or "not found" (`RESOLVED` clear)
   uniformly in *both* passes, via `C` clear either way -- the existing
   resolver ABI's `C` set path stays reserved for a genuine resolver-internal
   failure, never for "not defined yet." Pass-mode-specific interpretation of
   an unresolved result belongs solely in `parserParseExpressionValue`'s
   `pevUnresolved` branch, which must now check `CasmPassMode`: `MEASURE`
   stores the `FORCE_ABS` bit with a placeholder `ValLo/ValHi = $0000` (never
   emitted, since `MEASURE` mode never writes bytes) and returns `C` clear;
   `EMIT` returns `C` set with `CASM_DIAG_UNDEFINED_SYMBOL`. This keeps
   `symbols.s` simple and puts the one pass-sensitive decision in the one
   place that already owned the analogous Phase 5 decision.
4. **Symbol record layout (VMM-backed, 37 bytes):**

   ```text
   Offset  Size  Field
   0       1     NameLen (1..31)
   1       31    Name (fixed 31-byte slot, unused tail undefined -- mirrors
                       CASM_TOKEN_TEXT_MAX/CASM_TOKEN_TEXT_BUFFER_SIZE)
   32      2     ValueLo/ValueHi (address assigned in Pass 1)
   34      1     Flags (bit 0 = DEFINED; remaining bits reserved)
   35      2     NextLo/NextHi (16-bit record index of the next record in
                       this bucket's collision chain; $FFFF = end of chain)
   ```

   `CASM_SYMBOL_REC_SIZE = 37`. Capacity ceiling `CASM_SYMBOL_MAX = 512`
   records, `512 * 37 = 18944` bytes -- one `vmmStoreAlloc` allocation, well
   under the existing `CASM_VMM_ALLOC_MAX_BYTES = 65536` single-allocation
   cap, so Phase 6B needs no new VMM registry slot beyond the one it
   allocates and no change to `vmm_store.s`'s existing ABI.
5. **Hash function and bucket array (bounded base-RAM, 128 buckets):**
   rotate-left-1-and-XOR fold over the identifier's exact bytes (case-
   sensitive, matching the master plan's case-sensitive-label rule), masked
   to 7 bits:

   ```text
   hash = 0
   for each byte b in name:
       hash = rol1(hash) XOR b       ; rol1: ASL, then OR #1 if the shift
                                     ;       carried out of bit 7
   bucketIndex = hash AND $7F        ; 128 buckets, power-of-two mask
   ```

   Chosen over a plain byte-sum because assembly symbol names commonly
   share prefixes (`LOOP1`/`LOOP2`/`LOOP3`) that a sum-based hash collapses
   onto adjacent buckets; the rotate spreads prefix-sharing names apart at a
   cost of 4-5 cycles/byte, cheap enough for 31-byte-bounded identifiers.
   `CasmSymbolBuckets: .res 256` (128 buckets x 2-byte head-record-index,
   `$FFFF` = empty) is new persistent BSS in `symbols.s`, consuming a
   meaningful share of whatever MAIN increase WP27 ends up proposing (item 6
   above) -- this is flagged here, not sized here.

   Records are append-only within one assembly: `CasmSymbolCount` (new
   persistent word, 0..512) is a bump allocator, never a free list --
   Phase 6B never removes a symbol mid-run, so no reclamation path is
   needed. The two operations WP27 implements are:

   ```text
   symbolsInsert(namePtr, nameLen, value) -> C clear + X/Y = record index
                                              C set + A = CASM_DIAG_DUPLICATE_SYMBOL
                                                        or CASM_DIAG_SYMBOL_TABLE_FULL
     1. bucket = hash(namePtr, nameLen) AND $7F
     2. walk CasmSymbolBuckets[bucket]'s chain via each record's Next field,
        comparing NameLen then Name bytes exactly (case-sensitive)
     3. a byte-exact match with Flags.DEFINED set -> CASM_DIAG_DUPLICATE_SYMBOL
     4. else, if CasmSymbolCount = CASM_SYMBOL_MAX -> CASM_DIAG_SYMBOL_TABLE_FULL
     5. else: new index = CasmSymbolCount; write NameLen/Name/Value/
        Flags=DEFINED/Next=<old bucket head>; bucket head = new index;
        CasmSymbolCount += 1; return C clear + new index

   symbolsLookup(namePtr, nameLen) -> C clear always;
                                       X/Y = five-byte CASM_RESOLVE_* view
                                       (RESOLVED set + Value, or RESOLVED clear)
     1. bucket = hash(namePtr, nameLen) AND $7F
     2. walk the chain exactly as symbolsInsert; a byte-exact match with
        Flags.DEFINED set returns RESOLVED set + its Value
     3. no match (chain exhausted, or bucket empty) returns RESOLVED clear
     4. never returns C set: "not found" is reported through the RESOLVE
        view precisely because the Phase 5 resolver ABI already has a slot
        for it (CASM_RESOLVE_FLAGS with RESOLVED clear), and a hard resolver
        failure (C set) is reserved for cases this table can never produce
   ```

   `symbolsLookup` is the routine bound as `exprEvaluate`'s resolver callback
   in place of Phase 5's `parserRejectIdentifier`, used identically by both
   passes (Dependency Review item 2 and Contract item 3 above cover how the
   two passes diverge in interpreting its "not found" result -- the lookup
   itself never diverges).
6. **Statement grammar: label definitions are their own atomic statement,
   not a combined "label + instruction" production.** `IDENTIFIER COLON` at
   statement start is a complete label-definition statement, terminated at
   the colon. `parserParseStatement` does not attempt to also parse a
   trailing instruction/directive in the same call: doing so would require
   a second `lexerNext` before the label name has been consumed by anyone,
   and `CasmTokenText` is a single transient buffer `lexerNext` overwrites on
   every call (Dependency Review item 3) -- there is no way to "peek past"
   the colon without destroying the name first. Instead:
   - Before calling `lexerNext` again, `parserParseStatement` copies the
     current token's `Length` and text into two new persistent, exported
     cells in `parser.s`: `CasmLabelNameLen: .res 1` and
     `CasmLabelName: .res 32` (31 usable bytes plus terminator, sized
     identically to `CASM_TOKEN_TEXT_BUFFER_SIZE`). This mirrors the
     existing `CasmStmtLoc*` precedent exactly: new state kept parallel to
     `CasmParserStmt` rather than crammed into its asserted-size record.
   - It then calls `lexerNext` once to require and consume the `COLON`
     (any other token there is `CASM_DIAG_SYNTAX_ERROR`, matching the master
     plan's "global labels end with `:`" rule -- a bare leading identifier
     with no colon is not a valid statement start in this grammar).
   - It sets `CasmParserStmt.Type = CASM_TOKEN_IDENTIFIER` (reusing the
     existing token-type-as-`Type` convention), zeroes `Subtype`/`OpKind`/
     `ValLo`/`ValHi`/`RegSubtype`/`Flags`, and returns `C` clear -- without
     consuming anything past the colon.
   - The driver (in `pass1.s`/`pass2.s`, not `parser.s`) calls
     `parserParseStatement` again for whatever follows on the same physical
     line, exactly as it already does for any two statements in sequence;
     nothing about the "one call may not span a full logical line" change is
     visible to any existing caller, since `casm.s`'s loop already treats
     each `parserParseStatement` result opaquely per call rather than
     assuming a line boundary.
   - **Label insertion happens only when the driver, not `parser.s`, is in
     `CASM_PASS_MODE_MEASURE` and sees `CasmParserStmt.Type ==
     CASM_TOKEN_IDENTIFIER`**: it calls `symbolsInsert(CasmLabelName,
     CasmLabelNameLen, CasmPc)` -- `CasmPc` is read at this point, before any
     following instruction on the same line has been parsed or emitted, so
     the label's value is correctly "the address of what comes next." This
     keeps `parser.s` a pure grammar module: it imports `CasmTokenText`
     (new) alongside its existing lexer/expression/diagnostic imports, but
     gains **no** import of `CasmPc` (`emit.s`) or `symbolsInsert`
     (`symbols.s`) -- the semantic action of defining a symbol stays in the
     pass-orchestration layer, matching how `parser.s` already never calls
     `opcodesFindOpcode` or `emitInstruction` itself. In
     `CASM_PASS_MODE_EMIT`, the driver does not call `symbolsInsert` again
     for the same `CASM_TOKEN_IDENTIFIER` result -- Pass 2 has nothing to do
     for a label statement at all (the label was already defined in Pass 1
     and is not itself an operand reference needing resolution).
7. **Duplicate/undefined/case-sensitivity rules:**
   - A second definition of an already-DEFINED name (exact byte-for-byte
     case-sensitive match) is `CASM_DIAG_DUPLICATE_SYMBOL`, raised at Pass 1
     insertion time, terminal for that assembly.
   - A resolver lookup that never finds a DEFINED record by the time Pass 2
     runs is `CASM_DIAG_UNDEFINED_SYMBOL`, terminal.
   - Maximum identifier length remains 31 bytes, already enforced by the
     Phase 3 token contract (`CASM_TOKEN_TEXT_MAX`) before a name ever
     reaches the symbol table; `symbols.s` performs no separate length check.
   - A 513th distinct symbol is `CASM_DIAG_SYMBOL_TABLE_FULL`, terminal.
8. **New diagnostics, contiguous after `CASM_DIAG_PHASE6A_LAST = $2B`:**

   ```text
   CASM_DIAG_DUPLICATE_SYMBOL  = $2C
   CASM_DIAG_UNDEFINED_SYMBOL  = $2D
   CASM_DIAG_SYMBOL_TABLE_FULL = $2E
   CASM_DIAG_PASS_MISMATCH     = $2F
   CASM_DIAG_PHASE6B_LAST      = $2F
   ```

   Each gets the same `.assert ... = CASM_DIAG_PHASE5_LAST + n` contiguity
   pattern already used for every prior phase range, plus a `diagnostics.s`
   message-table entry before any fixture can raise and print it.
9. **`CasmPassMode` storage and constants:**

   ```text
   CASM_PASS_MODE_MEASURE = $00
   CASM_PASS_MODE_EMIT    = $01
   ```

   `CasmPassMode: .res 1` lives in `emit.s`'s existing `BSS` segment, not
   zero page (Dependency Review item 8).

## Scope

Included in WP26:

- verifying the Phase 6A gate (done above);
- creating the CASM Phase 6B Taskwarrior milestone and WP26-WP31 child
  tasks in `wiki/tasks/casm.md` and `brain/task.md`;
- recording the Phase 0C.5 contract above in `brain/KNOWLEDGE.md`;
- the version-only completion increment.

Excluded from WP26 (each requires its own dedicated plan per AGENTS.md):

- any `symbols.s`, `pass1.s`, or `pass2.s` source;
- any change to `common.inc`, `parser.s`, `opcodes.s`, `emit.s`, or `casm.s`;
- any MAIN envelope size change;
- any fixture or test harness.

## Expected Files

| File | Action |
| --- | --- |
| `brain/plans/2026-07-22-casm-phase6-wp26-prerequisite-reconciliation.md` | this document |
| `wiki/tasks/casm.md` | add CASM Phase 6B milestone and WP26-WP31 child tasks |
| `brain/task.md` | synchronize active work |
| `brain/KNOWLEDGE.md` | add "CASM Phase 6B Symbol Table and Two-Pass Contract (Phase 0C.5, frozen 2026-07-22)" section |
| `src/external/casm/casm.s` | version-only stage increment at completion |
| `src/external/casm/BUILD_CASM` | build-managed increment |

No source file implementing symbols, passes, or grammar changes is
authorized by approval of this document alone; WP27-WP30 each require their
own dedicated plan and approval.

## ABI, Storage, and Runtime Effects

None from WP26 itself. This document freezes the ABI/storage effects that
WP27 (`CASM_SYMBOL_REC_SIZE`, bucket array), WP28 (`CasmParserStmt` growth to
7 bytes, `CasmPassMode`, label grammar), and WP30 (branch displacement now
consuming resolved symbol values) will implement.

## Verification and Fixture Strategy (binding on WP27-WP31)

- WP27 fixtures: insertion, lookup, duplicate rejection, table-full
  rejection, and bucket-distribution sanity (no single bucket absorbing an
  unreasonable share of a representative symbol set) -- independent of any
  parsing or pass semantics, matching Phase 6A's own "storage before
  semantics" precedent.
- WP28 fixtures: forward-reference and backward-reference label programs
  where Pass 1 correctly sizes every instruction without emitting; a static
  audit trail confirming `opcodesFindOpcode` consults
  `CASM_PARSER_STMT_FORCE_ABS` before every zero-page-shrink decision.
- WP29 fixtures: the same programs produce byte-identical output through
  Pass 2 against trusted reference binaries.
- WP30 fixtures: forward and backward relative branches resolved from real
  labels; a deliberately constructed Pass 1/Pass 2 disagreement (if one can
  be triggered deterministically) proving `CASM_DIAG_PASS_MISMATCH` fires
  and exits cleanly.
- WP31 bundles the full matrix into the CASM Phase 6B completion gate,
  matching the master plan's Phase 6B gate text exactly: "static programs
  with forward and backward references match trusted reference binaries
  byte for byte."

## Atomic Implementation Increments

1. After this plan's approval, create the CASM Phase 6B Taskwarrior
   milestone and WP26-WP31 child tasks (via the `task` CLI directly if the
   Task Warrior MCP remains unavailable this session, recording the same
   information in `wiki/tasks/casm.md`/`brain/task.md` regardless).
2. Record the Phase 0C.5 contract in `brain/KNOWLEDGE.md`, cross-referencing
   this plan.
3. Update `wiki/tasks/casm.md`'s CASM Phase 6B section with the WP26-WP31
   breakdown and mark WP26 in progress, then complete.
4. Apply the version-only completion increment (stage bump only, matching
   every prior freeze WP), rebuild, confirm a no-change rebuild holds
   stable, and request completion approval.

## Failure and Cleanup

Not applicable: WP26 implements no runtime behavior. A material deviation
found after this plan's approval (e.g., a frozen decision proving
unworkable once WP27 starts writing real code) stops implementation until
this document is amended and re-approved, per every prior CASM phase's
precedent.

## Documentation and DOX Closeout

Update this plan, `brain/KNOWLEDGE.md`, `brain/task.md`, `wiki/tasks/casm.md`,
`CHANGELOG.md`, and Taskwarrior. `AGENTS.md` is not expected to change by
WP26 itself (it already documents the ABI-amendment and per-package-plan
gates this document exercises); it will need a real update once WP28 lands
the `CasmParserStmt` growth, since AGENTS.md's own text cites the record as
an example of frozen ABI.

## Completion Gate

WP26 is complete when the Phase 0C.5 contract above is recorded in
`brain/KNOWLEDGE.md`, the CASM Phase 6B Taskwarrior milestone and WP26-WP31
child tasks exist, the version-only increment is verified, and the user
explicitly approves. This does not activate WP27; each remains separately
gated per AGENTS.md.

## Progress

- 2026-07-22: Drafted after confirming CASM Phase 6A's completion gate
  (0.1.27 build 1102) and performing fresh dependency research against the
  current source rather than the Phase 6 parent plan's pre-implementation
  description of it. Found two discrepancies beyond the parent plan's own
  review: `CasmParserStmt` has no channel to `forceAbsoluteWidth` at all
  (not merely unaudited), and the statement grammar has no label-definition
  production yet (a Phase 4 restriction the master plan's Phase 6B scope
  explicitly lifts). Asked the user three architectural questions
  (pass-mode threading, `CasmParserStmt` growth vs. a parallel cell, symbol
  table scale); all three recommended options were confirmed. Froze the
  Phase 0C.5 contract: single `CasmPassMode` flag (no event bus);
  `CasmParserStmt` grows to 7 bytes; 37-byte VMM symbol records over a
  128-bucket/512-symbol rotate-XOR hash table; new diagnostics `$2C-$2F`;
  label grammar allowing an optional trailing instruction/directive. Awaiting
  user approval before Taskwarrior creation or `brain/KNOWLEDGE.md` updates.
- 2026-07-22 (same day, second pass): user asked for a deeper
  dependency/discrepancy review of this WP26 plan specifically before
  approval. Re-traced the actual code paths rather than re-describing the
  first draft's intentions, and found two things the first draft got
  imprecise or wrong:
  - **Pass-mode gating.** The first draft said "`emitByte`/`emitRawByte`
    check it," which would have meant two redundant checks. Tracing every
    byte-emission call site found `emitRawByte` is the sole routine that
    touches `CasmEmitBuffer`/`fileWrite` (`emitByte` calls it per byte,
    `emitOrg` calls it directly for the PRG header), so exactly one gate at
    the top of `emitRawByte` is correct and sufficient; `emitFinalize`/
    `emitFlush` need no change at all as a consequence.
  - **Label statement design was actually broken.** The first draft's "a
    label may be followed by an optional trailing instruction on the same
    line" required a second `lexerNext` call before the label name had been
    read out of the transient `CasmTokenText` buffer -- which `lexerNext`
    overwrites unconditionally. That would have silently corrupted every
    label's recorded name. Corrected to: a label definition is its own
    complete, colon-terminated statement; the name is copied into a new
    persistent `CasmLabelName`/`CasmLabelNameLen` pair (mirroring the
    existing `CasmStmtLoc*` precedent) before any further token is read;
    the driver calls `parserParseStatement` again for whatever follows.
    Also clarified that `parser.s` gains no import of `CasmPc` or
    `symbolsInsert` -- the label-insertion semantic action stays in the
    pass-orchestration layer, keeping `parser.s` a pure grammar module.
  - Also confirmed by direct inspection that `lexerInit`'s doc comment
    already anticipates the Pass-2-restart reuse (not a new design), that
    `exprEvaluate` already auto-sets `FORCE_ABS` on any unresolved result
    (so the Phase 6B resolver callback stays pass-agnostic; only
    `parserParseExpressionValue` needs to consult `CasmPassMode`), and wrote
    out the exact `symbolsInsert`/`symbolsLookup` algorithms so WP27 has no
    remaining ambiguity to resolve on its own. Still awaiting user approval
    before Taskwarrior creation or `brain/KNOWLEDGE.md` updates -- no source
    has been touched.
