---
feature: casm-native-assembler
phase: 3
work-package: 4
created: 2026-07-16
status: approved
implementation-status: in-progress
depends-on: casm-phase-3-wp03-shared-abi-bounded-state
approval-required: true
---

# CASM Phase 3 WP4 Plan: Rewindable Source Backend

## Approval Gate

The user approved this plan and authorized WP4 implementation on 2026-07-16.
A material change to the ABI, state layout, managed-file behavior, memory
envelope, or work-package boundary requires an amended plan and renewed
approval.

WP4 completion also remains separately gated. After implementation and static
verification, the user must run the supported C64/VICE or hardware fixture
matrix, approve the walkthrough, and explicitly confirm completion before WP4
is marked done or the version advances.

## Objective

Create the executable byte-stream source layer over Phase 2's managed input
wrapper and WP3's bounded source state. WP4 will initialize source state, open
one source, refill and traverse the existing 256-byte `CasmIoBuffer`, expose
repeat-stable EOF, and close through central ownership rules.

WP4 intentionally returns raw physical bytes. CR, LF, CRLF, provenance
advancement, final-CR handling, and normalized newline results begin in WP5.
Rewind and line-window access begin in WP6. The lexer cannot consume the
transitional WP4 byte API until WP5 normalization is complete.

The existing consume-only CASM path will be routed through the source layer
without changing its user-visible `INPUT VALIDATED` success behavior. At EOF,
the source layer compares bytes consumed with Phase 2's checked bytes-fetched
total. This makes the 17-, 256-, and 513-byte fixtures detect lost, duplicated,
or prematurely terminated traversal without introducing WP10's token dump.

## Prerequisites and Inherited Decisions

- WP3 is complete and supplies the stable Phase 3 constants and exactly 16
  bytes of source state inside the 63-byte `state.s` allocation.
- `CasmIoBuffer` is the only source buffer. WP4 byte mode owns it as a transfer
  block; no line-window use or second buffer is permitted.
- `inputStreamOpen`, `inputStreamRead`, and `inputStreamClose` remain the only
  path to Command 64 file services and central resource ownership.
- `CasmInputTotalLo/Hi` counts bytes fetched into the buffer. It is not the
  source cursor. `CasmSourceOffsetLo/Hi` counts bytes successfully returned by
  `sourceNextByte`.
- Physical input and source offsets are bounded to 65,535 bytes. Every cursor,
  length, and offset increment is checked before commit.
- The current completed version is `0.1.5`, build 1018. The linked image uses
  2,256 code/data bytes and 512 BSS bytes, with 1,328 bytes of combined `$1000`
  envelope headroom.
- Phase 3 diagnostics `$14-$1B` are reserved. WP4 may return source-offset
  overflow `$15`; WP10 owns its final display string and bounded dispatch.
- No `c64-testing` or web emulator verification is permitted. Runtime evidence
  must come from the user in the supported environment.

## Sub-Phase Dependency Audit and Resolutions

| Package | WP4 provides | Explicitly deferred |
|---|---|---|
| WP5 newlines/provenance | Raw byte traversal, physical consumed offset, pending-CR initialized to zero | CR/LF/CRLF normalization, line/column advancement, `sourceGetLocation` |
| WP6 rewind/line API | Repeatable open/close primitives and initialized line-window state | `sourceRewind`, reopen failure mapping, primary diagnostic preservation across close/reopen, `sourceNextLine`, null rejection |
| WP7 lexer core | Eventually normalized byte API after WP5 | Any lexer call against WP4 raw-byte semantics; lexer state mutation |
| WP8-WP9 classification | Stable byte transport only | Token scanning, classification, tables |
| WP10 diagnostics/token dump | Source routines and stable diagnostic values | Diagnostic text/dispatch and token-dump orchestration |
| WP11 closeout | Raw traversal fixture evidence and memory baseline | Cumulative Phase 3 verification |

Resolved discrepancies:

1. The Phase 3 public ABI describes `sourceNextByte` as normalized, while WP5
   owns normalization. In WP4 it is a documented transitional raw-byte API:
   every `$00-$FF` input byte, including CR and LF, returns
   `CASM_SOURCE_BYTE`. WP5 replaces only the newline semantics and may then
   return `CASM_SOURCE_NEWLINE`. WP7 is gated on WP5.
2. WP4 exports only `sourceInit`, `sourceOpen`, `sourceNextByte`, and
   `sourceClose`. `sourceGetLocation` belongs to WP5; `sourceRewind` and
   `sourceNextLine` belong to WP6.
3. Preservation of a primary diagnostic across a close/reopen sequence is a
   WP6 rewind concern. WP4 preserves managed ownership on close failure and
   returns the Phase 2 close diagnostic unchanged.
4. WP4 retains the consume-only entry-point behavior but routes it through the
   source API. WP10 still owns replacement of that behavior with the temporary
   token dump.
5. The raw fixture gate is made measurable by checking at first EOF that the
   source consumed offset equals the managed fetched total. A mismatch is an
   internal stream-state failure and EOF is not committed.
6. Embedded null is a raw byte in WP4. WP6 owns its rejection in the approved
   bounded line API, and WP7 cannot run before that dependency is complete.

## Scope

### Included

- create `source.s` with documented public and private routines;
- initialize all 16 bytes of the source subrecord without touching lexer state;
- open through `inputStreamOpen` and enter byte mode only after success;
- refill from `inputStreamRead` only when the current block is exhausted;
- support block lengths 1-256 and cursor values 0-256 without wrap;
- return raw bytes separately from the nonzero source result code;
- advance the checked physical consumed offset only after selecting a byte;
- validate consumed-versus-fetched counts before committing first EOF;
- make EOF repeat-stable without another OS read;
- close successfully from READY, EOF, or retryable ERROR state;
- retain central handle ownership and retry capability after close failure;
- route current consume-only orchestration through the new source API;
- build, artifact, memory, relocation, and fixture verification;
- documentation, task, walkthrough, changelog, memory, knowledge, and DOX
  closeout after implementation approval; and
- version advancement from `0.1.5` to `0.1.6` only after explicit completion
  approval.

### Excluded

- CR/LF/CRLF normalization or `CASM_SOURCE_NEWLINE` production;
- line/column advancement or `sourceGetLocation`;
- close/reopen rewind and rewind diagnostic mapping;
- line-window buffer ownership, `sourceNextLine`, line bounds, or null rejection;
- lexer initialization, lookahead, tokens, classification, or token dump;
- new persistent BSS, zero-page aliases, or changes to the WP3 state layout;
- a second source buffer;
- output creation or assembly behavior;
- diagnostic message/dispatch expansion;
- DEBUG source or table changes;
- new fixtures unless an existing fixture is proven unsuitable; and
- WP5 or later task activation.

## Planned Files

| Path | Action | Responsibility |
|---|---|---|
| `src/external/casm/source.s` | Create | WP4 source routines and executable ownership |
| `src/external/casm/casm.s` | Modify | Replace direct Phase 2 read loop with equivalent source API loop |
| `src/external/casm/fileio.s` | Modify narrowly | Return source-offset overflow `$15` from checked input-total overflow |
| `brain/plans/2026-07-16-casm-phase3-source-stream-lexer.md` | Already corrected by this planning increment | Parent ownership and transitional ABI |
| `wiki/tasks/casm.md` | Modify during implementation/closeout | WP4 state and evidence |
| `brain/task.md` | Modify with Taskwarrior | WP4 state and UUID synchronization |
| `brain/KNOWLEDGE.md` | Modify at closeout | Raw-to-normalized boundary and source ABI decision |
| `brain/MEMORY.md` | Modify at closeout | Measured linked/BSS growth and remaining envelope |
| `CHANGELOG.md` | Modify at closeout | Observable package/version state |
| `brain/walkthroughs/2026-07-16-casm-phase3-wp04-rewindable-source-backend.md` | Create at closeout | Static, artifact, and user runtime evidence |
| `src/external/casm/AGENTS.md` | Review; modify only if contract changes | DOX closeout pass |

`common.inc` and `state.s` are intentionally unchanged. Their WP3 ABI and
storage are sufficient. `CMakeLists.txt` is unchanged because the existing
CASM source glob discovers `source.s`.

## Source-State Contract

### Initialization

`sourceInit` initializes the complete source subrecord:

```text
CasmSourceApiMode       = CASM_SOURCE_API_NONE
CasmSourceState         = CASM_SOURCE_STATE_CLOSED
CasmSourceFileId        = CASM_SOURCE_FILE_ID_INITIAL
CasmSourceBlockLen      = 0
CasmSourceBlockIndex    = 0
CasmSourceOffset        = CASM_SOURCE_OFFSET_INITIAL
CasmSourceLine          = CASM_SOURCE_LINE_INITIAL
CasmSourceColumn        = CASM_SOURCE_COLUMN_INITIAL
CasmSourcePendingCr     = 0
CasmSourceResultByte    = 0
CasmSourceLineLength    = 0
CasmSourceLineState     = CASM_SOURCE_LINE_IDLE
```

The routine does not call `fileIoInit`, close a handle, or initialize lexer
state. Orchestration calls it only after `fileIoInit` and before `sourceOpen`.

### Open

`sourceOpen` requires source state CLOSED and Phase 2 file state CLOSED. It
calls `inputStreamOpen`; only successful return commits READY and BYTE mode.
It then resets block length/index, offset, pending CR, result byte, and future
line-window fields to their initial values. File ID, line 1, and column 1 are
also restored so a later WP6 reopen can share the same reset logic.

An open failure leaves the source CLOSED/NONE and does not alter Phase 2's
central ownership outcome. Invalid state returns
`CASM_DIAG_STREAM_STATE_FAILED` without an OS call.

### Block Cursor

The block length and index are unsigned 16-bit values:

- data block length is 1-256;
- index is 0 through length;
- length 256 is encoded `$0100`;
- a byte may be read only when index is strictly less than length;
- while reading, index high must be zero and X receives index low;
- consuming the last byte of a 256-byte block advances index from `$00FF` to
  `$0100`; and
- refill is legal only when index equals length. Index greater than length is
  a stream-state failure.

`sourceRefill` copies `CasmIoLenLo/Hi` into the source block length and resets
the index to zero only after a successful DATA result. A DATA result with zero
length, length greater than 256, or inconsistent cursor state fails without
exposing a byte.

### Physical Offset

The source offset is the number of bytes already returned to the caller. It
starts at zero. For each selected byte, `sourceNextByte` validates that the
offset is not `$FFFF`, computes the next offset, then commits the result byte,
block index, and offset as one success path.

The transition `$FFFE -> $FFFF` is valid. Attempting to return another byte at
`$FFFF` fails with `CASM_DIAG_SOURCE_OFFSET_OVERFLOW` before any cursor or
result state is committed. The managed input-total overflow path returns the
same diagnostic, so files larger than 65,535 bytes have one stable code.

### EOF

On the first EOF returned by `inputStreamRead`, `sourceRefill` verifies:

```text
CasmSourceBlockIndex == CasmSourceBlockLen
CasmSourceOffset == CasmInputTotal
```

If both hold, it sets source state EOF, clears `CasmSourceResultByte`, and
returns `CASM_SOURCE_EOF` with carry clear. Empty input therefore returns EOF
at offset zero, line 1, column 1. Later calls in EOF state return the same
result without reading or mutating the cursor.

A mismatch returns `CASM_DIAG_STREAM_STATE_FAILED`, sets source state ERROR,
and does not commit EOF.

### Error and Close

Read, invariant, state, or overflow failure sets source state ERROR and returns
the original diagnostic with carry set. `sourceClose` is permitted in CLOSED,
READY, EOF, and ERROR states:

- CLOSED is repeat-safe and returns success;
- all other states call `inputStreamClose`;
- successful close commits CLOSED/NONE and clears block/result state; and
- failed close leaves source ERROR and the Phase 2 handle registered in
  CLOSE_FAILED state so a later `sourceClose` or central cleanup can retry.

`sourceClose` does not overwrite a caller's earlier diagnostic because callers
that already have a primary failure jump to central fatal cleanup. WP6 owns the
separate logic that preserves a primary rewind failure across close/reopen
cleanup operations.

## Routine ABI

### `sourceInit`

- Inputs: none.
- Success: A=`CASM_DIAG_NONE`, C clear, Z set.
- Preserves: X, Y.
- Clobbers: A and flags.
- Scratch: none.

### `sourceOpen`

- Inputs: initialized source state; parsed `CasmSourceName`; initialized Phase
  2 file services.
- Success: A=`CASM_DIAG_NONE`, C clear; state READY, API BYTE.
- Failure: A=`CASM_DIAG_*`, C set; source remains CLOSED/NONE unless a managed
  wrapper has retained ownership after its own failure.
- Preserves: none.
- Clobbers: A, X, Y, source scratch named in implementation, and documented
  `inputStreamOpen`/OS volatile state.

### `sourceNextByte` (WP4 transitional raw ABI)

- Inputs: source state READY/BYTE or EOF/BYTE.
- Byte success: A=`CASM_SOURCE_BYTE`, C clear, Z clear;
  `CasmSourceResultByte` contains the raw physical byte.
- EOF success: A=`CASM_SOURCE_EOF`, C clear, Z clear;
  `CasmSourceResultByte` is zero.
- Failure: A=`CASM_DIAG_*`, C set; source state ERROR.
- Preserves: none.
- Clobbers: A, X, Y, source scratch named in implementation, and refill/OS
  volatile state when a refill is required.
- Important: the raw byte is never inferred from A or Z. A zero byte remains a
  successful BYTE result.

### `sourceClose`

- Inputs: initialized source state.
- Success: A=`CASM_DIAG_NONE`, C clear, Z set; source CLOSED/NONE.
- Failure: A=`CASM_DIAG_INPUT_CLOSE_FAILED`, C set; source ERROR and managed
  ownership retained.
- Preserves: none.
- Clobbers: A, X, Y and documented `inputStreamClose`/OS volatile state.

### Private routines

`sourceResetTraversal` initializes the traversal/location/line fields without
touching lexer state or Phase 2 ownership. `sourceRefill` validates exhausted
cursor state, calls `inputStreamRead`, installs a nonempty block, or commits
validated EOF. Private symbols are not exported.

Every status-return path explicitly normalizes carry. No public ABI promises N,
V, or decimal-state preservation beyond the repository's existing calling
convention.

## Entry-Point Integration

After resources, CLI, and file services initialize, `casm.s` calls
`sourceInit`. After output-name derivation it calls `sourceOpen`, repeatedly
calls `sourceNextByte` until `CASM_SOURCE_EOF`, then calls `sourceClose`, prints
the existing Phase 2 ready message, and exits through central cleanup.

The loop does not inspect or print raw bytes. It therefore preserves current
success output while exercising every block boundary. Any source failure still
uses `exitFatal`; central cleanup owns an open or close-failed handle.
`CasmPhase` remains `CASM_PHASE_CLI_FILE` because the user-visible Phase 3
token-dump path does not begin until WP10.

## Atomic Implementation Increments

1. Activate the existing WP4 task records without marking them complete.
2. Create `source.s` with imports/exports, `sourceInit`, and private reset.
3. Implement `sourceOpen` and verify successful/failing state transitions.
4. Implement 16-bit cursor validation and `sourceRefill` for 1-256-byte blocks.
5. Implement raw `sourceNextByte`, checked offset commit, EOF count invariant,
   and repeat-stable EOF.
6. Implement repeat-safe/retryable `sourceClose` and audit central ownership.
7. Narrowly map managed input-total overflow to diagnostic `$15`.
8. Route the consume-only entry point through the source API.
9. Build and perform static carry, cursor, offset, state, and ownership audits.
10. Inspect linked memory, PRG/R6 artifact, relocation count, and a no-change
    rebuild; stop if the envelope or build behavior regresses.
11. Prepare documentation, task synchronization, changelog, walkthrough, and
    DOX closeout as a completion candidate.
12. Ask the user to run the raw fixture matrix and approve completion.
13. Only after explicit approval, mark WP4 complete and advance `0.1.5` to
    `0.1.6` without changing the independent build number contract.

Each increment is reviewed before advancing. An implementation failure triggers
root-cause analysis; it does not authorize unplanned state or ABI changes.

## Verification

### Static and Build Verification

- assemble/link the narrow CASM target;
- confirm `source.s` imports WP3 storage and defines no BSS;
- inspect every public routine for documented carry and result separation;
- prove 16-bit comparisons handle lengths/indexes 0, 1, 255, and 256;
- prove offset `$FFFE -> $FFFF` succeeds and a further byte fails pre-commit;
- prove EOF performs no read after the first committed EOF;
- trace every open/read/close failure to retained ownership and central cleanup;
- confirm no lexer state is written;
- inspect map size, total BSS, relocations, PRG header, and R6 footer;
- confirm the linked image remains within the `$1000` envelope;
- confirm a no-change rebuild does not increment `BUILD_CASM`; and
- build `image_d64` and confirm CASM remains present.

### User Runtime Matrix

The walkthrough asks the user to run CASM against the existing 17-, 256-, and
513-byte raw fixtures and confirm the unchanged success message and clean
return. The matrix also covers an empty openable file where supported, a
missing file, a second CASM launch, and a read/close failure if the supported
environment can induce them. Count equality at EOF is the internal gate against
loss, duplication, or premature termination.

No runtime result is assumed. WP4 remains a completion candidate until the user
reports evidence and approves completion.

## Stop Conditions

Stop and request a plan amendment if implementation requires:

- any new persistent BSS or zero-page alias;
- changing a WP3 constant, source-record field, or diagnostic number;
- a second input buffer or line-window ownership in WP4;
- newline normalization, rewind, line access, lexer behavior, or token output;
- direct OS file calls outside the Phase 2 wrappers;
- weakening immediate resource registration or close-failure retention;
- changes to DEBUG, fixtures, build topology, linker envelope, or diagnostics
  dispatch beyond the listed narrow scope;
- an observable success behavior other than the existing consume-only message;
  or
- linked growth that cannot fit the current `$1000` envelope.

## Documentation and DOX Closeout

After meaningful edits, re-read the root and `src/external/casm/AGENTS.md`
contracts. Update the local DOX only if WP4 changes a durable source-module
contract not already recorded; otherwise report that it remained unchanged
because the existing source ownership and buffer rules remain accurate.

At completion-candidate closeout, synchronize `wiki/tasks/casm.md`, Taskwarrior,
`brain/task.md`, `brain/KNOWLEDGE.md`, `brain/MEMORY.md`, `CHANGELOG.md`, and the
WP4 walkthrough. Do not mark WP4 or Phase 3 done without explicit user approval.

## Completion Gate

WP4 is eligible for completion approval only when:

- the four public routines match this ABI;
- raw 17-, 256-, and 513-byte traversal reaches count-validated EOF;
- EOF is repeat-stable;
- offset and cursor increments are checked before commit;
- read and close failures preserve central resource ownership;
- the production path retains its prior consume-only output;
- the build, artifact, memory, relocation, no-change, and release-disk checks
  pass;
- the walkthrough contains user runtime evidence; and
- the user explicitly approves marking WP4 complete.
