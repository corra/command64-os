---
feature: casm-native-assembler
phase: 3
work-package: 5
created: 2026-07-16
status: approved
implementation-status: complete
depends-on: casm-phase-3-wp04-rewindable-source-backend
approval-required: true
---

# CASM Phase 3 WP5 Plan: Newlines and Provenance

## Approval Gate

The user approved this plan and authorized WP5 implementation on 2026-07-16 and
selected the recommended fixture option (add the bounded newline fixtures). A
material change to the source ABI, the location/offset semantics, the state
layout, the managed buffer contract, the memory envelope, or the work-package
boundary requires an amended plan and renewed approval.

WP5 completion is separately gated. After implementation and static
verification, the user must run the supported C64/VICE or hardware fixture
matrix, approve the walkthrough, and explicitly confirm completion before WP5 is
marked done or the version advances from `0.1.6` to `0.1.7`.

## Objective

Replace WP4's transitional raw-byte semantics with the approved Phase 0C.1
normalized source layer. WP5 collapses CR, LF, and CRLF (including CRLF split
across input blocks) into a single `CASM_SOURCE_NEWLINE` result, resolves a
final CR before EOF, and tracks file-aware, one-based line and column provenance
plus the physical offset. WP5 also adds `sourceGetLocation` with a documented
snapshot ABI so a later lexer can capture a token's start position before
consuming its first result.

WP5 changes only newline semantics and location tracking on top of the existing
WP4 traversal, refill, EOF-count invariant, close, and ownership behavior.
`sourceNextByte` continues to deliver a non-newline physical byte in
`CasmSourceResultByte` as `CASM_SOURCE_BYTE`; a zero byte remains a valid BYTE
result. Rewind and the bounded line API remain WP6. The lexer remains WP7 and is
unblocked only after WP5 is complete.

## Prerequisites and Inherited Decisions

- WP4 is complete: `source.s` owns `sourceInit`, `sourceOpen`,
  `sourceNextByte`, and `sourceClose`; the consume-only entry point already
  routes through the source API; input-total overflow maps to `$15`.
- WP3 supplies the 16-byte source subrecord. WP5 activates `CasmSourceLineLo/Hi`,
  `CasmSourceColumn`, and `CasmSourcePendingCr` (WP4 initialized all three) and
  keeps writing `CasmSourceResultByte` and `CasmSourceOffsetLo/Hi`. WP5 adds no
  BSS, no zero-page alias, and no state-layout change.
- `CasmIoBuffer` remains the only source buffer, owned as a transfer block. WP5
  performs no line-window use and allocates no second buffer.
- `inputStreamOpen`, `inputStreamRead`, and `inputStreamClose` remain the only
  path to Command 64 file services and central ownership. WP5 makes no direct
  OS file call.
- Constants already exist in `common.inc` and are unchanged by WP5:
  `CASM_SOURCE_NEWLINE` = `$02`, `CASM_SOURCE_LINE_INITIAL` = `$0001`,
  `CASM_SOURCE_LINE_MAX` = `$FFFF`, `CASM_SOURCE_COLUMN_INITIAL` = `$01`,
  `CASM_SOURCE_COLUMN_MAX` = `$FF`, `CASM_PETSCII_CR` = `$0D`,
  `CASM_PETSCII_LF` = `$0A`, and `CASM_DIAG_SOURCE_LOCATION_OVERFLOW` = `$16`.
- Diagnostic `$16` display text and bounded dispatch belong to WP10. WP5 only
  returns the code, exactly as WP4 returned `$15` without message text.
- The current completed version is `0.1.6`, build 1020. The linked image uses
  2,663 code/data bytes and 512 BSS bytes, with 921 bytes of `$1000` envelope
  headroom. WP5 growth must remain inside that envelope.
- No `c64-testing` or web emulator verification is permitted. Runtime evidence
  comes from the user in the supported environment.

## Sub-Phase Dependency Audit and Resolutions

| Package | WP5 provides | Explicitly deferred |
|---|---|---|
| WP6 rewind/line API | Normalized traversal, pending-CR/line/column advance rules, `sourceGetLocation` snapshot, and the reset field set WP6's rewind must restore | `sourceRewind`, reopen failure mapping, primary-diagnostic preservation across close/reopen, `sourceNextLine`, embedded-null rejection, line-too-long `$17` |
| WP7 lexer core | Final normalized `sourceNextByte` (BYTE vs NEWLINE) and token-start `sourceGetLocation` | Any lexer state, lookahead, token capture, or classification |
| WP8-WP9 classification | Stable normalized byte/newline transport and start locations | Token scanning, numeric shape, mnemonic tables |
| WP10 diagnostics/token dump | Correct coordinates and the stable `$16` code | `$16` display text, bounded diagnostic dispatch, the token dump that first makes locations and newline collapsing runtime-observable |
| WP11 closeout | Normalization/location static evidence and the memory baseline | Cumulative Phase 3 verification |

Resolved discrepancies:

1. **Offset meaning.** The WP4 plan described `CasmSourceOffset` as "bytes
   successfully returned by `sourceNextByte`." Under normalization a CRLF
   returns one `CASM_SOURCE_NEWLINE` result for two physical bytes, so results
   returned and physical bytes consumed diverge. WP5 fixes `CasmSourceOffset` as
   the **physical consumed offset**: it advances once per physical byte read from
   the stream, including the LF swallowed inside a CRLF. This preserves the WP4
   invariant `CasmSourceOffset == CasmInputTotal` at first EOF and is the
   provenance "physical offset." The WP4 wording was correct only because WP4
   physical bytes and returned results were one-to-one.
2. **Newline result byte.** `CasmSourceResultByte` is authoritative only for a
   `CASM_SOURCE_BYTE` result. For `CASM_SOURCE_NEWLINE` and `CASM_SOURCE_EOF` it
   is `0`. The lexer must key on the result code, never on the raw byte, and
   never interprets raw CR or LF. This satisfies the Phase 0C.1 rule that the
   lexer receives one normalized newline result.
3. **`sourceGetLocation` ABI.** The parent plan names a "documented snapshot
   ABI" without a snapshot buffer. WP5 defines `sourceGetLocation` as a
   validated in-place accessor: the canonical location already lives in the
   persistent `CasmSourceFileId`, `CasmSourceOffsetLo/Hi`, `CasmSourceLineLo/Hi`,
   and `CasmSourceColumn` fields, which describe the **next** result. The routine
   validates state and location representability and returns success with those
   fields readable, or `$16` when a location overflow is pending. WP7 copies the
   fields into the token/lookahead record before the next mutating call; WP5
   adds no snapshot BSS. This is the minimal in-scope realization and is
   recorded so WP6/WP7 share one reset and capture contract.
4. **Column upper bound and the 255-byte line.** Columns are one-based 8-bit
   values (`1..255`). A byte that would occupy column 256 fails with
   `CASM_DIAG_SOURCE_LOCATION_OVERFLOW` before commit. A terminating newline is
   never blocked by the column bound. In byte mode this makes a line longer than
   255 payload bytes fail with `$16`, while WP6's line API fails the same
   physical condition with line-too-long `$17`; the two APIs keep distinct
   diagnostics by design.
5. **Runtime observability boundary.** WP5 changes no user-visible success
   output: the entry point still consumes BYTE and NEWLINE results to a
   count-validated EOF and prints `INPUT VALIDATED`. Newline collapsing and
   coordinate values become runtime-observable only with WP10's token dump.
   WP5's own runtime gate is therefore non-regression across newline forms plus
   the count invariant; coordinate-value confirmation is a recorded WP10
   dependency. See Verification for the recommended fixture decision.
6. **Pending-CR ownership.** WP4 initialized `CasmSourcePendingCr` to zero and
   never set it. WP5 owns setting and clearing it as the CRLF-join latch. WP6's
   rewind reset must clear it along with line, column, offset, result byte, and
   EOF state; WP5 documents it in the reset field set for WP6 to consume.

## Scope

### Included

- collapse CR, LF, and CRLF into one `CASM_SOURCE_NEWLINE`, including CRLF split
  across a block boundary, using the persistent pending-CR latch;
- resolve a final CR as a newline before EOF;
- advance one-based line and column and the physical offset with checked commits;
- fail line or column overflow before committing the offending result;
- keep the EOF count invariant `CasmSourceOffset == CasmInputTotal`;
- add `sourceGetLocation` as a validated in-place location accessor;
- preserve all WP4 open, refill, close, EOF-repeat, and ownership behavior;
- build, artifact, memory, relocation, and fixture verification; and
- documentation, task, walkthrough, changelog, memory, knowledge, and DOX
  closeout after completion approval, then advance `0.1.6` to `0.1.7`.

### Excluded

- `sourceRewind`, reopen failure mapping, or rewind diagnostic preservation;
- `sourceNextLine`, line-window ownership, line bounds, or embedded-null
  rejection (`$17`, `$19` remain WP6/later);
- lexer state, lookahead, tokens, classification, or the token dump;
- new persistent BSS, zero-page aliases, `common.inc` constants, or WP3 state
  layout changes;
- a second source buffer;
- diagnostic message text or dispatch for `$16` (WP10);
- output creation or assembly behavior;
- DEBUG source or table changes; and
- new fixtures unless the fixture decision below is approved.

## Planned Files

| Path | Action | Responsibility |
|---|---|---|
| `src/external/casm/source.s` | Modify | Normalized `sourceNextByte`, pending-CR/newline handling, location advance, new `sourceGetLocation` |
| `src/external/casm/casm.s` | Unchanged | The consume-only loop already treats any non-EOF result as continue; NEWLINE needs no change. Confirmed, not edited |
| `cmake/GenerateCasmTestFixtures.cmake` | Modify only if the fixture decision is approved | Add bounded CR/CRLF/split/consecutive/final-CR fixtures |
| `CMakeLists.txt` | Modify only if fixtures are added | Register any new fixture in the test-image flow |
| `wiki/tasks/casm.md` | Modify at closeout | WP5 state and evidence |
| `brain/task.md` | Modify at closeout | WP5 state and UUID sync |
| `brain/KNOWLEDGE.md` | Modify at closeout | Offset-as-physical, newline result byte, `sourceGetLocation` accessor, column bound |
| `brain/MEMORY.md` | Modify at closeout | Measured linked/BSS growth and remaining envelope |
| `CHANGELOG.md` | Modify at closeout | Observable package/version state |
| `brain/walkthroughs/2026-07-16-casm-phase3-wp05-newlines-provenance.md` | Create at closeout | Static, artifact, and user runtime evidence |
| `src/external/casm/AGENTS.md` | Review; modify only if a durable contract changes | DOX closeout pass |

`common.inc` and `state.s` are intentionally unchanged: WP5 reuses existing
constants and the WP3 state layout and adds no storage.

## Normalization and Location Contract

### Result model

Each `sourceNextByte` call returns exactly one of:

- `CASM_SOURCE_BYTE` (C clear, Z clear): `CasmSourceResultByte` = the raw
  non-newline physical byte, at provenance `(file, line, column)`;
- `CASM_SOURCE_NEWLINE` (C clear, Z clear): `CasmSourceResultByte` = 0, at the
  provenance of the byte that began the newline;
- `CASM_SOURCE_EOF` (C clear, Z clear): `CasmSourceResultByte` = 0, repeat-stable;
- failure (C set): `A` = `CASM_DIAG_*`, source state ERROR.

### Physical byte fetch

WP5 keeps WP4's exhausted-cursor refill: a byte is fetched only when block index
is strictly less than block length, refill occurs only when index equals length,
index above length is a stream-state failure, and refill installs a validated
1-256-byte block or commits EOF. Every fetched physical byte advances the block
index and the physical offset with checked 16-bit increments; the offset never
passes `$FFFF` without the mapped `$15` overflow path.

### CR, LF, CRLF, and the pending-CR latch

`CasmSourcePendingCr` records that the previous result was a CR-origin newline
and that an immediately following LF is the second half of a CRLF:

1. On entry in READY state, fetch the next physical byte `b` (refilling if
   needed; an EOF from refill goes to EOF handling below).
2. If `CasmSourcePendingCr` is set: clear it. If `b == LF`, this LF completes a
   CRLF: advance only the physical offset for it, do not emit a result or change
   line or column, and loop to fetch the next physical byte. If `b != LF`, `b`
   is an independent byte and is classified normally below.
3. Classify `b`:
   - `b == CR`: emit `CASM_SOURCE_NEWLINE`, set `CasmSourcePendingCr`, and apply
     the newline location advance.
   - `b == LF`: emit `CASM_SOURCE_NEWLINE` and apply the newline location
     advance. Pending-CR is left clear.
   - otherwise: emit `CASM_SOURCE_BYTE` with `b`, applying the byte location
     advance.

This collapses CR, LF, and CRLF to one newline; consecutive CR or consecutive LF
bytes produce consecutive newlines (consecutive empty lines); and a CRLF split
so the CR ends one block and the LF begins the next is handled because pending-CR
is persistent and the LF swallow re-enters the normal fetch/refill path.

### Final CR before EOF

A CR emits its newline immediately and sets pending-CR. If the next fetch
reaches EOF, EOF handling clears pending-CR (its newline was already emitted) and
returns EOF. A file ending in a lone CR therefore yields the CR's newline and
then EOF, satisfying "a final CR is resolved as a newline before EOF."

### Location advance

`CasmSourceLine` (16-bit) and `CasmSourceColumn` (8-bit) describe the **next**
result's coordinates, initialized to line 1, column 1.

- Byte result at column `C` (`1..255`): report at `C`, then advance the column.
  If `C < 255`, column becomes `C+1`. If `C == 255`, column enters the exhausted
  latch (internally `0`), meaning a further byte on this line would overflow.
- Producing a byte while the column is in the exhausted latch returns
  `CASM_DIAG_SOURCE_LOCATION_OVERFLOW` before any commit and sets source ERROR.
- Newline result: report at the current column (the exhausted latch is reported
  as `CASM_SOURCE_COLUMN_MAX`), then advance the line by a checked 16-bit step
  and reset the column to 1. Incrementing the line past `CASM_SOURCE_LINE_MAX`
  returns `CASM_DIAG_SOURCE_LOCATION_OVERFLOW` before committing the newline.
- A swallowed CRLF LF changes neither line nor column.

The exhausted latch keeps a legitimate 255-byte line valid: its 255 bytes occupy
columns 1-255, the terminating newline is reported and resets the line, and only
a real 256th byte on one line fails.

### EOF

EOF handling is unchanged from WP4 except that pending-CR is cleared: on the
first EOF, `CasmSourceBlockIndex == CasmSourceBlockLen` and
`CasmSourceOffset == CasmInputTotal` are verified; on success, state becomes EOF,
`CasmSourceResultByte` is cleared, and `CASM_SOURCE_EOF` is returned with carry
clear. Empty input returns EOF at offset 0, line 1, column 1. A mismatch sets
ERROR and returns `CASM_DIAG_STREAM_STATE_FAILED` without committing EOF.

### `sourceGetLocation`

`sourceGetLocation` validates that the source is in READY or EOF state and that
no column-exhausted latch or line overflow is pending, then returns success with
`CasmSourceFileId`, `CasmSourceOffsetLo/Hi`, `CasmSourceLineLo/Hi`, and
`CasmSourceColumn` describing the next result. If a location overflow is pending
it returns `CASM_DIAG_SOURCE_LOCATION_OVERFLOW` with carry set and does not
mutate state. The caller reads the persistent fields immediately and, in WP7,
copies them into the token record before the next mutating call.

## Routine ABI

### `sourceNextByte` (WP5 normalized ABI)

- Inputs: source state READY/BYTE or EOF/BYTE.
- Byte success: A=`CASM_SOURCE_BYTE`, C clear, Z clear; `CasmSourceResultByte` =
  raw byte; provenance describes that byte.
- Newline success: A=`CASM_SOURCE_NEWLINE`, C clear, Z clear;
  `CasmSourceResultByte` = 0.
- EOF success: A=`CASM_SOURCE_EOF`, C clear, Z clear; `CasmSourceResultByte` = 0.
- Failure: A=`CASM_DIAG_*` (`$13`, `$15`, `$16`, or a read/close diagnostic),
  C set; source state ERROR.
- Preserves: none. Clobbers: A, X, Y, source scratch, refill/OS volatile state
  on refill.
- The raw byte is never inferred from A or Z; a zero byte is a valid BYTE
  result.

### `sourceGetLocation`

- Inputs: source state READY or EOF.
- Success: A=`CASM_DIAG_NONE`, C clear; `CasmSourceFileId`,
  `CasmSourceOffsetLo/Hi`, `CasmSourceLineLo/Hi`, `CasmSourceColumn` hold the
  next result's provenance.
- Failure: A=`CASM_DIAG_SOURCE_LOCATION_OVERFLOW` or
  `CASM_DIAG_STREAM_STATE_FAILED`, C set; state unchanged.
- Preserves: X, Y where practical; documented precisely in implementation.
- Clobbers: A and flags.

### Unchanged routines

`sourceInit`, `sourceOpen`, and `sourceClose` keep their WP4 ABI. `sourceInit`
and `sourceOpen` already initialize line 1, column 1, pending-CR 0, and result
byte 0 through `sourceResetTraversal`, so WP5 adds no new initialization surface.

Every status-return path explicitly normalizes carry. No public ABI promises N,
V, or decimal-state preservation beyond the repository convention.

## Entry-Point Integration

`casm.s` is not edited. Its loop calls `sourceNextByte`, branches to fatal on
carry, treats `CASM_SOURCE_EOF` as done, and otherwise loops. `CASM_SOURCE_BYTE`
and `CASM_SOURCE_NEWLINE` are both non-EOF, non-carry results, so the loop
consumes them identically and still prints the existing `INPUT VALIDATED`
message. The plan verifies this by inspection rather than by change.

## Atomic Implementation Increments

1. Activate the existing WP5 task records without marking them complete.
2. Add the byte-location advance and column-exhausted latch to the normal-byte
   path; prove columns 1, 254, 255, and the 256th-byte `$16` overflow.
3. Add LF and CR newline emission with the line advance, column reset, and line
   overflow check; keep the physical offset advancing per physical byte.
4. Add the pending-CR latch and the CRLF LF swallow, including the block-boundary
   split case; keep the EOF count invariant.
5. Clear pending-CR in EOF handling and confirm final-CR resolution.
6. Implement `sourceGetLocation` and its overflow/state validation.
7. Build and perform static carry, offset, line, column, latch, newline, and EOF
   audits; confirm no BSS, constant, or state-layout change and no lexer write.
8. Inspect linked memory, PRG/R6 artifact, relocation count, and a no-change
   rebuild; stop if the envelope or build behavior regresses.
9. Decide and, if approved, add bounded newline fixtures; otherwise record the
   deferral to WP10.
10. Prepare documentation, task synchronization, changelog, walkthrough, and DOX
    closeout as a completion candidate.
11. Ask the user to run the newline fixture matrix and approve completion.
12. Only after explicit approval, mark WP5 complete and advance `0.1.6` to
    `0.1.7` without changing the independent build-number contract.

Each increment is reviewed before advancing. An implementation failure triggers
root-cause analysis; it does not authorize unplanned state or ABI changes.

## Verification

### Static and Build Verification

- assemble/link the narrow CASM target;
- confirm `source.s` still defines no BSS and imports no new symbols beyond
  existing WP3/Phase 2 storage;
- prove CR, LF, and CRLF each yield exactly one newline, including a CRLF split
  with the CR at block byte 255 and the LF at the next block byte 0;
- prove consecutive CR and consecutive LF yield consecutive newlines;
- prove a lone final CR yields a newline then EOF;
- prove the physical offset advances once per physical byte and still equals
  `CasmInputTotal` at first EOF, including for CRLF inputs;
- prove line advance rejects overflow past `$FFFF` and column rejects a 256th
  byte on one line, both before commit;
- prove a 255-byte line plus newline succeeds;
- prove `sourceGetLocation` returns the next-result coordinates and rejects a
  pending overflow;
- confirm no lexer state is written and `casm.s` is unchanged;
- inspect map size, total BSS, relocations, PRG header, and R6 footer;
- confirm the linked image remains within the `$1000` envelope;
- confirm a no-change rebuild does not increment `BUILD_CASM`; and
- build `image_d64` and confirm CASM remains present.

### Fixture Decision (requires approval at plan review)

The existing `casmshort` fixture already ends in one LF, so LF normalization and
the count invariant are exercised at runtime today. CR, CRLF, CRLF-split,
consecutive-newline, and final-CR forms are not represented, and their
coordinate values are not runtime-observable until WP10's token dump.

- **Recommended:** add a small set of bounded newline fixtures (CR-only,
  CRLF, a CRLF straddling the 255/256 block boundary, consecutive newlines, and
  a final-CR file) so the count invariant exercises the CR and CRLF-swallow paths
  at runtime now, while deferring coordinate-value confirmation to WP10. This is
  a justified fixture addition because existing fixtures cannot represent these
  forms.
- **Alternative:** add no fixtures in WP5, rely on static proof plus the
  `casmshort` LF and the count invariant, and introduce every newline fixture in
  WP10 where the token dump makes coordinates observable.

The choice is deferred to the user at plan approval and does not change the
source ABI either way.

### User Runtime Matrix

The walkthrough asks the user to run CASM against the LF `casmshort` fixture and
the new CR/CRLF/split/consecutive/final-CR fixtures, confirming the unchanged
`INPUT VALIDATED` message and clean return. `casmsplit` (260 bytes with a newline
before the block boundary) carries the multi-block count-invariant coverage.
Count equality at EOF is the internal gate against loss, duplication, or
premature termination across newline collapsing. Coordinate-value confirmation is
explicitly a WP10 dependency. No runtime result is assumed.

**Deliberate consequence for the WP4 block fixtures.** `casm256` (256 bytes) and
`casmmulti` (513 bytes) are each a single line with no newline, so they exceed
the 255-byte/8-bit-column limit. Under WP5 they correctly fail at their 256th
byte with `CASM_DIAG_SOURCE_LOCATION_OVERFLOW` (`$16`) through the existing fatal
path, rather than reaching `INPUT VALIDATED`. This is forced by resolution #4 and
the WP3 8-bit column field; the runtime matrix expects a clean `$16` diagnostic
and clean return for those two fixtures, and `casmsplit` replaces their block
traversal coverage. The fixtures are retained unchanged as the byte-mode
line-overflow cases.

## Stop Conditions

Stop and request a plan amendment if implementation requires:

- any new persistent BSS, zero-page alias, `common.inc` constant, or WP3 state
  change;
- a second input buffer or any line-window ownership in WP5;
- rewind, line access, embedded-null rejection, lexer behavior, or token output;
- direct OS file calls outside the Phase 2 wrappers;
- weakening the EOF count invariant, resource registration, or close-failure
  retention;
- an observable success behavior other than the existing consume-only message;
- diagnostic message or dispatch expansion for `$16`; or
- linked growth that cannot fit the current `$1000` envelope.

## Documentation and DOX Closeout

After meaningful edits, re-read the root and `src/external/casm/AGENTS.md`
contracts. The AGENTS.md already records file-aware, line-aware source locations
and the single-buffer rule; update it only if WP5 changes a durable source-module
contract, otherwise report it unchanged.

At completion-candidate closeout, synchronize `wiki/tasks/casm.md`, Taskwarrior,
`brain/task.md`, `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `CHANGELOG.md`, and the
WP5 walkthrough. Do not mark WP5 or Phase 3 done without explicit user approval.

## Completion Gate

WP5 is eligible for completion approval only when:

- `sourceNextByte` returns the normalized BYTE/NEWLINE/EOF model with the result
  byte separated from A/Z;
- CR, LF, and CRLF collapse to one newline, including across a block boundary,
  and a final CR resolves before EOF;
- file, line, column, and physical offset provenance are correct and
  overflow-checked before commit;
- the EOF count invariant holds, including for CRLF inputs;
- `sourceGetLocation` matches its ABI;
- no BSS, constant, state-layout, buffer, lexer, or entry-point regression
  occurred;
- the build, artifact, memory, relocation, no-change, and release-disk checks
  pass within the `$1000` envelope;
- the walkthrough contains user runtime evidence for the approved fixture set;
  and
- the user explicitly approves marking WP5 complete, advancing `0.1.6` to
  `0.1.7`.
