# Implementation Plan: CASM Phase 4 WP13 — Directives and Emission Engine

## Objective

WP13 makes CASM produce a real Commodore PRG. It adds a new module, `emit.s`,
that tracks the program counter, writes the 2-byte PRG load-address header and
the assembled bytes to the CLI-derived output file, processes the `.ORG`,
`.BYTE`, and `.WORD` directives, and encodes each matched instruction's operand
bytes — including the relative-branch displacement and range check deferred
here from WP12. A single forward pass suffices because Phase 4 has no symbols
or forward references (see §2).

Labels, symbols, expressions, relocation (`.STATIC`/`.RELOC`), `.INCLUDE`,
listings, and maps remain out of scope.

---

## Prerequisites

- WP12 complete (CASM `0.1.14`): `opcodesFindOpcode` produces `CasmInsn`
  (opcode, resolved `CASM_MODE_*`, length) for a mnemonic statement.
- WP11 `parserParseStatement` and `CasmParserStmt` exist; the temporary
  `casm.s` driver already parses each statement and matches mnemonic opcodes.
- `fileio.s` output lifecycle exists: `fileCreateOutput` (X/Y = name pointer),
  `fileWrite` (X/Y = source pointer, `CasmIoLenLo/Hi` = count), `outputAbort`
  (delete a partial output), and the `CasmOutput*` state.
- `cli.s` exports `CasmOutputName`/`CasmOutputLen`; `cliDeriveOutputName` is
  already called in `casm.s`.

## Inherited Decisions

- Only documented instructions/modes and the three numeric directives are
  supported. `.STATIC`, `.RELOC`, `.INCLUDE`, and `DIRECTIVE_UNKNOWN` are
  rejected (see §5), not emitted.
- Output is a plain absolute PRG: a 2-byte little-endian load address (the
  `.ORG` value) followed by raw assembled bytes. No R6 relocation trailer — that
  format belongs to the ca65-built external apps, not to CASM's own output.

---

## Technical Specifications

### 1. Emission state (`emit.s` BSS)

```
CasmPc        (2 bytes)  ; current program counter (next emit address)
CasmOrgSet    (1 byte)   ; 0 until the initial .ORG is processed
CasmEmitLen   (1 byte)   ; staged byte count in CasmEmitBuffer
CasmEmitBuffer(64 bytes) ; bounded output staging buffer (see §6)
```

`CasmEmitBuffer` is a small, bounded buffer distinct from the 256-byte
`CasmIoBuffer`; the source (input) buffer is live throughout the single emit
pass, so output cannot reuse it.

### 2. Single-pass model (and forward compatibility)

Phase 4 has no symbols, so every operand value is a literal and every
instruction size is fixed the moment it is parsed (zero-page vs absolute is a
value-magnitude decision made in WP12). Branch targets are literal addresses,
and `CasmPc` is known at each instruction, so displacements compute in one
forward pass. WP13 therefore emits directly during the existing single parse of
the source.

This is forward-compatible with the two-pass architecture in
`src/external/casm/AGENTS.md`: when symbols arrive in a later phase, a Pass 1
(rewind + symbol collection via `sourceRewind`) will precede this emitting pass,
which becomes Pass 2. WP13 introduces no state that blocks that.

### 3. Program counter and `.ORG`

- `.ORG addr` (parsed as a DIRECTIVE with a single 16-bit operand in
  `CasmParserStmt.Val`):
  - If `CasmOrgSet` is already 1 -> `CASM_DIAG_DUPLICATE_ORG`.
  - Else set `CasmPc = addr`, `CasmOrgSet = 1`, and write the 2-byte PRG header
    (`addr` low, `addr` high) to the output.
- Any instruction or data directive processed while `CasmOrgSet == 0` ->
  `CASM_DIAG_ORG_REQUIRED`.
- Every emitted byte advances `CasmPc`. If an advance would carry past `$FFFF`
  -> `CASM_DIAG_ADDRESS_OVERFLOW`.

### 4. Instruction emission

Given `CasmInsn` (from `opcodesFindOpcode`) and `CasmParserStmt.Val`:
- Emit `CasmInsn.Opcode`.
- By `CasmInsn.Length`:
  - 1: opcode only.
  - 2, non-relative modes: emit `Val` low byte (the 8-bit operand; WP12 already
    range-checked it).
  - 2, `CASM_MODE_RELATIVE`: compute `disp = Val - (CasmPc_after)` where
    `CasmPc_after = CasmPc + 2` (address of the instruction following the
    branch). If `disp` is outside `-128..+127` -> `CASM_DIAG_BRANCH_OUT_OF_RANGE`.
    Emit the low byte of `disp`.
  - 3: emit `Val` low then high (little-endian).
- `CasmPc` advances by `Length` (checked for overflow).

### 5. Data directives

The WP11 parser's single-operand addressing-mode grammar cannot express a
comma-separated numeric list, so WP13 handles `.BYTE`/`.WORD` operands directly
from the lexer (see the parser refinement in §7):
- `.BYTE v1, v2, ...`: each `v` must satisfy `ValHi == 0` else
  `CASM_DIAG_OPERAND_OUT_OF_RANGE` ($1E, reused); emit one byte per value.
- `.WORD v1, v2, ...`: emit each value low then high.
- At least one value is required; a missing/garbage operand ->
  `CASM_DIAG_SYNTAX_ERROR`. The list ends at NEWLINE/EOF.
- `.STATIC`, `.RELOC`, `.INCLUDE` -> `CASM_DIAG_NOT_IMPLEMENTED` ($0A, existing).
- `DIRECTIVE_UNKNOWN` -> `CASM_DIAG_SYNTAX_ERROR`.

### 6. Output writes (bounded)

`emitByte` appends to `CasmEmitBuffer` and, when it reaches 64 bytes, flushes via
`fileWrite`. `emitFinalize` flushes any remainder and is the caller's signal to
close the output. This bounds staging to 64 bytes while supporting
arbitrarily long `.BYTE`/`.WORD` lines, and keeps `CasmIoBuffer` reserved for
input.

### 7. Parser refinement (`parser.s`)

`parserParseStatement`, on a DIRECTIVE whose subtype is `BYTE` or `WORD`,
returns after the directive token **without** consuming the operand list
(leaving the lexer positioned at the first operand token) so the WP13 directive
handler can read and emit the list. `.ORG` and all other statements keep their
WP11 behavior. This is a documented refinement of the WP11 parser contract, not
a grammar change to instructions.

---

## Proposed Changes

### Build System
No `CMakeLists.txt` source-list edit: `emit.s` is picked up by the
glob-recursive `CASM_SRCS` on reconfigure.

### CASM Codebase

#### [MODIFY] `common.inc`
- Add `CASM_DIAG_DUPLICATE_ORG` ($20), `CASM_DIAG_ORG_REQUIRED` ($21),
  `CASM_DIAG_ADDRESS_OVERFLOW` ($22), `CASM_DIAG_BRANCH_OUT_OF_RANGE` ($23);
  advance `CASM_DIAG_PHASE4_LAST` to `$23` with contiguity asserts.
- Add `CASM_EMIT_BUFFER_SIZE = 64` with an assert.

#### [NEW] `emit.s`
- BSS: `CasmPc`, `CasmOrgSet`, `CasmEmitLen`, `CasmEmitBuffer` (exported as
  needed).
- Code: `emitInit`, `emitOrg`, `emitInstruction`, `emitDirective`
  (dispatches ORG/BYTE/WORD/unsupported and drives the lexer for BYTE/WORD),
  `emitByte`, `emitFinalize`. Uses `CasmEmitScratch0-3` (`$8C`-`$8F`).

#### [MODIFY] `parser.s`
- The §7 BYTE/WORD early-return refinement.

#### [MODIFY] `diagnostics.s`
- Append the four messages; extend `diagMessageLo/Hi` and the completeness
  asserts to `CASM_DIAG_PHASE4_LAST` ($23).

#### [MODIFY] `casm.s` (temporary verification scaffolding)
- After `cliDeriveOutputName`/`sourceOpen`, call `fileCreateOutput` with
  `CasmOutputName` and `emitInit`.
- In the temporary loop, dispatch each statement: MNEMONIC ->
  `opcodesFindOpcode` then `emitInstruction`; DIRECTIVE -> `emitDirective`;
  NEWLINE/EOF -> continue. On EOF, `emitFinalize` then close the output, print
  the validated banner, and exit success.
- On the fatal path, call `outputAbort` to delete a partial output so failed
  runs leave no junk file. WP14 formalizes this orchestration and its cleanup.

### Options Gate (decided 2026-07-17)
- Output is the default result of a successful assembly. Change the `casm.s`
  gate to reject only `CASM_OPT_MAP | CASM_OPT_LIST`; `/S` (static) is accepted
  as the now-default output mode. This deliberately advances the Phase 0B CLI
  contract, which anticipated output beginning in the numeric static-output
  phase.

### Test Fixtures
#### [MODIFY] `cmake/GenerateCasmTestFixtures.cmake` + `CMakeLists.txt`
- `casmemit1`: a small valid program (`.ORG`, a few instructions across modes,
  `.BYTE`/`.WORD` lines) that assembles to a PRG.
- `casmorg1`: `.ORG` missing before code -> `ORG REQUIRED`.
- `casmorg2`: two `.ORG` lines -> `DUPLICATE ORG`.
- `casmbr1`: a branch whose target is far from `.ORG` -> `BRANCH OUT OF RANGE`.

---

## Register / Flag / Scratch Contract

- `emitInit`: clears `CasmOrgSet`, `CasmEmitLen`. C clear.
- `emitOrg`/`emitInstruction`/`emitDirective`/`emitByte`/`emitFinalize`:
  C clear on success; C set with `A = CASM_DIAG_*` on failure. Clobber A, X, Y,
  `CasmEmitScratch0-3`, and `fileWrite`'s documented volatile set. `emitByte`
  advances `CasmPc`. None preserve registers.
- Uses only the approved `$8C`-`$8F` emit scratch; adds no zero-page aliases.

## Atomic Increments

1. `common.inc`: four diagnostics + emit-buffer size + asserts.
2. `diagnostics.s`: messages + table extension. Build `casm`.
3. `parser.s`: BYTE/WORD early-return refinement. Build `casm`.
4. `emit.s`: state + emit primitives + `.ORG`/instruction emission. Build `casm`.
5. `emit.s`: `.BYTE`/`.WORD` directive list handling. Build `casm`.
6. `casm.s`: create output, dispatch loop, finalize/abort. Build `casm`.
7. Fixtures + list registration. Build `test_image_d64`.

Each increment builds cleanly and preserves `BUILD_CASM` on a no-change rebuild.

## Failure and Cleanup Behavior

Emission failures return carry + a diagnostic and never close resources
themselves. The temporary driver routes them through `startFatal`/`exitFatal`
(central cleanup closes the source and output handles) and additionally calls
`outputAbort` to delete the partial output file. A short/failed `fileWrite`
already marks the output invalid in `fileio.s`.

## Verification Plan

### Automated
- `cmake --build build --target casm` assembles/links; asserts pass; image stays
  within the `$2000` MAIN envelope (current 7199 bytes; monitor headroom).
- No-change rebuild does not bump `BUILD_CASM`.
- A host-side 6502 encoder model (reused from the WP12 verification) predicts the
  expected bytes for `casmemit1` for cross-check during review.

### Manual (user, local VICE)
- `casm casmemit1` -> `INPUT VALIDATED`; a PRG appears in the directory with the
  correct load address (the `.ORG` value) and expected length. Optionally load
  it and inspect the first bytes.
- `casm casmorg1` -> `ORG REQUIRED`; `casm casmorg2` -> `DUPLICATE ORG`;
  `casm casmbr1` -> `BRANCH OUT OF RANGE`.
- Note: byte-for-byte reference comparison (`comp` against a `.ref`) is WP14's
  job; WP13 confirms a well-formed PRG is produced and the error paths fire.

## Documentation / Task / DOX Updates (on completion)
- `wiki/tasks/casm.md`, Task Warrior, `CHANGELOG.md`, a WP13 walkthrough, and a
  memory update if any non-obvious runtime behavior emerges.

## Stop Conditions
- If emission pushes the linked image past the MAIN envelope, stop and raise an
  amended plan (envelope increase) before continuing.
  - **Amendment 2026-07-17 (resolved)**: emission overflowed the `$2000`
    envelope by 108 bytes (CODE 5827 + RODATA 1940 + BSS 534 = 8300). With user
    approval the MAIN envelope was raised `$2000` -> `$2800` (10 KB) in
    `CMakeLists.txt` (`add_ca65_app(casm ... "2800")`), giving ~1.9 KB headroom
    through the rest of Phase 4. CASM now occupies `$3400`-`$5BFF` (base build).
- Any material deviation from §1–§7 requires an amended plan and renewed
  approval.

## Completion Gate
Version stage advances `14` -> `15` (CASM `0.1.15`), recorded only after
automated verification, user runtime confirmation of the cases above, user
approval of the walkthrough, and the task/changelog/memory updates — together.
