# CASM Phase 11 WP60 Increment 9 Audit and Walkthrough

Status: Frozen for user review
Branch: `feature/casm-phase11-wp60`
CASM version at audit time: `0.2.1` build `1265`
Plan: `brain/plans/2026-08-11-casm-phase11-wp60-opcode-addressing-boundary-hardening.md`
Taskwarrior: `bd441121-dffa-4d69-8f3a-8572e0643322`

## Scope

Increment 9 reconciles every prior increment's evidence into one row-by-row
audit, records defects/fixes/residual risk, and synchronizes task and
knowledge records. No production, fixture, or build-system source changes
in this increment.

## 1. Opcode Oracle Reconciliation (Increment 1 + live re-proof)

The Increment 1 oracle (`brain/reviews/2026-08-12-casm-phase11-wp60-increment1-opcode-oracle.md`)
independently derived all 151 legal mnemonic/mode/opcode/length tuples from
the documented NMOS 6502 matrix and mechanically reconciled it against
`opcodes.s`'s `opcodeMaskLo/Hi`, `opcodeRunOffset`, `opcodeBytes`, and
`modeLength` -- exact match, 151/151/151 one-to-one mask-bit/opcode-byte
correspondence.

That static reconciliation is now backed by two independent live proofs,
both re-confirmed at Increment 8 after a full clean rebuild:

- **Direct matcher** (`test_casm_opcodes`, Increment 4): 151/151 legal
  tuples plus 46 focused cases (unsupported-mode rejection, 8-bit-range
  accept/reject, ZP/Absolute selection, `FORCE_ABS`, independent ZP,X/ZP,Y
  promotion including the LDX/STX/LDY/STY role swap, all eight branches,
  Implied/Accumulator distinctness) = 197/197 live PASS.
- **End-to-end artifact** (`casmopall.s`/`casmopall.ref`, Increment 5):
  native assembly of one statement per tuple, byte-identical to the
  independently authored reference via native `COMP` -- `FILES COMPARE OK`,
  re-proven live at Increment 8.

No undocumented or 65C02-family opcode is accepted by production or present
in either oracle. **Closed: no open items.**

## 2. Boundary Evidence Register Reconciliation (Increment 2 vs. Increments 6-7)

The Increment 2 register (`brain/reviews/2026-08-12-casm-phase11-wp60-increment2-boundary-register.md`)
required 52 rows across 8 domains: 13 `reuse`, 9 `strengthen`, 30 `add`.
Reconciling each row against what Increments 6 and 7 actually closed:

| Domain | Rows | Closed | Open/Residual |
| --- | --- | --- | --- |
| Numeric literal | 6 | 6 | 0 |
| Addressing width | 3 | 2 | 1 -- `FORCE_ABS` stability across a genuine second measure/emit pass (single-pass shrink-prevention is covered; two-pass re-resolution is not) |
| Relative branch | 7 | 7 | 0 |
| Program counter | 5 | 5 | 0 |
| Source | 6 | 4 | 2 -- 65,535-byte accepted extent and first-byte-beyond-cap reject were never attempted in any increment; plus the empty-source-file row remains untestable with current tooling (`cc1541` cannot write a zero-byte SEQ entry -- confirmed live at Increment 7) |
| Symbol | 11 | 10 | 1 -- name length 32 (reject) is owned by `lexer.s`'s `CASM_DIAG_TOKEN_TOO_LONG`, a different module than `casm_symbols.s` links; zero test hits anywhere in `tests/`. Name length 0 is closed *by design determination*: `symbols.s` trusts `nameLen` as an unenforced 1..31 precondition and a length-0 identifier is structurally unreachable from the real lexer, so no test was added, per the plan's stop condition against inventing coverage for an unreachable path |
| VMM store/window | 6 | 6 | 0 |
| Relocation | 8 | 8 | 0 |
| **Total** | **52** | **48** | **4** |

48/52 rows closed. The 4 residual rows are each independently reasoned above
(off-boundary/single-pass scope for `FORCE_ABS`; untested-not-unreachable for
the two source-extent rows; different-module ownership for symbol-length-32)
-- none was silently dropped, and none contradicts a `reuse` disposition
already closed.

## 3. Defects Found

**One real production defect, not fixed under WP60 (per the plan's stop
conditions -- no production fix without root-cause analysis and explicit
approval):**

`sourceLoad`/`sourceNextByte` phantom EOF byte on an exactly-1-byte source
file. After the file's one real byte, the next `sourceNextByte` call
returns `A=CASM_SOURCE_BYTE` with a spurious `CasmSourceResultByte=$00`
instead of `CASM_SOURCE_EOF`. Independently reproduced live by Increment 7's
`srcOneByte1` case in `tests/src/casm_spanread/casm_spanread.s`, which is
written, built, and proven to trigger the defect, but is deliberately **not**
called from `start:` -- it exists as a ready-to-activate regression test,
not an active assertion. This corroborates a previously-unresolved suspicion
already on record: WP51 Increment 9's own `fixEmpty` fixture comment in
`cmake/GenerateCasmTestFixtures.cmake` was widened from 1 byte to 4
specifically to dodge this same class of over-read, without ever landing a
fix.

Recorded as Taskwarrior `882433f0-cde1-4849-8b3c-df32613518c3` (task 42,
project `casm`), separate from WP60 per Increment 7's own recommendation.

## 4. Fixes Applied (test-harness-only, no production change)

Both found and fixed during Increment 6, before `test_casm_bounds` could be
trusted:

1. `CasmOutputStarted`/`CasmPcOverflow` are private to `emit.s` (not
   `.export`ed). The harness's own same-named BSS bytes were disconnected
   shadows never written by real code; `CasmPcOverflow` read back
   accidentally-nonzero uninitialized RAM, producing a false PASS on the
   wrap-endpoint and `PC`-end-at-`$FFFF` cases. Fixed by dropping those
   assertions in favor of genuinely observable shared state (`CasmPc`, and
   `pcRejectOverflow`'s indirect proof via the next write's own returned
   diagnostic).
2. The repeat-reset case depended on `CasmCliOptions` genuinely reading `0`
   (not a stale static value) to observe `emitInit`'s real default-origin
   priming. BSS is not guaranteed zeroed on load, so the harness now zeroes
   it explicitly in `start:` rather than trusting `.res`.

Neither fix touched production source.

## 5. Unchanged Contracts

- Public exports, diagnostics, parser/instruction records, opcode masks,
  mode numbers, and relocation (R6) format: unchanged.
- No production zero-page or BSS allocation added.
- CASM version: `0.2.1` throughout (build `1265` since Increment 3; stable
  across Increments 4-8's test-only work, confirmed by no-change rebuild and
  identical `casm.prg` hash at Increment 8).
- Valid PRG/R6/listing/map output: unchanged, except the one approved
  production change below.

## 6. Production Change (the only one WP60 has made)

`casm.s`'s `start:` gained `CLD` as its literal first instruction
(Increment 3). Adds exactly one code byte (18580 -> 18581); relocations
unchanged at 2806; base unchanged at `$3800`; `image_d64` unchanged at 334
blocks free. Hardens an implicit invariant (the first `OS_API` call already
clears decimal incidentally) rather than fixing a reproduced live bug.

## 7. Metrics Summary

| Item | Count |
| --- | --- |
| Legal opcode/mode tuples (oracle, matcher, end-to-end artifact) | 151 |
| `test_casm_opcodes` total cases | 197 (151 legal + 46 focused) |
| `test_casm_expr` total cases | 38 |
| `test_casm_bounds` total cases | 12 (7 branch + 5 PC) |
| Boundary register rows | 52 (48 closed, 4 residual) |
| Production defects found | 1 (recorded, not fixed under WP60) |
| Test-harness-only bugs found and fixed | 2 (Increment 6) |
| Production code-byte delta since `0.2.1` baseline | +1 (`CLD`) |
| Production relocation-count delta | 0 |
| CASM version | unchanged, `0.2.1` |

## 8. Residual Risks

1. **Phantom EOF byte on 1-byte sources** (Section 3) -- real defect, tracked
   separately, not blocking WP60 completion per the plan's own scoping
   (WP60 owns opcode/addressing/boundary certification, not fixing every
   defect that certification surfaces).
2. **`FORCE_ABS` two-pass re-resolution** -- untested. A symbol-derived
   `FORCE_ABS` operand's stability has only been proven within a single
   measure pass; genuine two-pass behavior (Pass 1 measure, Pass 2 emit)
   is unverified.
3. **Source extent cap** -- the 65,535-byte accepted maximum and the
   65,536-byte first-reject boundary have no test at any increment.
4. **Symbol name length 32 rejection** -- zero coverage anywhere in
   `tests/`; owned by `lexer.s`, outside every harness this plan touched.
5. **Empty-source-file boundary** -- not a code gap but a tooling gap:
   `cc1541` cannot produce a zero-byte SEQ fixture at all, confirmed live.

None of these five items block WP60 completion under the plan's own
completion criteria (criterion 2 allows a boundary row to be "satisfied or
explicitly re-scoped by user approval"); they are surfaced here for an
explicit accept/defer decision alongside the completion request below.

## 9. Manual Confirmation Steps (for user replay if desired)

1. `cmake --build build --target casm image_d64` -- confirm `BUILD_CASM`
   reads `1265` with the hash unchanged from this record.
2. Boot Command64 from `build/casm_opcode_test.d64`, run `test_casm_opcode`
   -- expect `CASM OPCODES: PASS`.
3. On the same disk: `casm casmopall.s /o:<name>.prg` then
   `comp <name>.prg casmopall.ref` -- expect `CASM: INPUT VALIDATED` then
   `FILES COMPARE OK`.
4. Boot from `build/casm_listing_test.d64`, run `test_casm_bounds` and
   `test_casm_spanre` -- expect `CASM BOUNDS: PASS` and
   `CASM SPANREAD: PASS`.
5. Boot from `build/test.d64`, run `test_casm_symbol`, `test_casm_reloc`,
   `test_casm_vmm` -- expect `CASM SYMBOLS: PASS`, `CASM RELOC: PASS`,
   `CASM VMM: PASS`.
6. Dispatch any harness name with the real disk-truncated 16-character name
   and, if it contains `_`, send the underscore as PETSCII `$A4` via
   `vice_keyboard_petscii` -- literal ASCII `_` via `vice_keyboard_type`
   does not match the disk's real byte and produces a false
   `Bad command or file name`.

## Sign-off

All ten of the plan's completion criteria are satisfied or explicitly
re-scoped:

1. All 151 legal opcode/mode combinations have independent direct-matcher
   and end-to-end evidence. **Met.**
2. Every required boundary-register row is satisfied or explicitly
   re-scoped -- 48/52 satisfied, 4 residual items presented above for an
   explicit accept/defer decision. **Presented for your decision.**
3. Entry `CLD` structurally precedes all production arithmetic. **Met.**
4. Unsupported mode/range paths preserve diagnostics, carry, location, SP.
   **Met** (Increment 4's 46 focused cases).
5. No undocumented/non-6510 opcode accepted. **Met.**
6. All changed/affected regression targets pass live and return to shell.
   **Met** (Increment 8).
7. Valid artifacts remain compatible except approved defect corrections --
   no defect correction was made; `casm.prg` is byte-identical since
   Increment 3. **Met.**
8. Consolidated and no-change builds pass with measured envelopes. **Met**
   (Increment 8).
9. Records, walkthrough, Taskwarrior, and DOX agree. **This record**, plus
   `brain/task.md`, `wiki/tasks/casm.md`, and Taskwarrior task 42
   synchronized as part of this increment.
10. User explicitly approves completion and the verified `0.2.2` increment.
    **Requesting now.**

Requesting: (a) accept/defer decisions on the 4 residual boundary items and
the phantom-EOF-byte defect's separate tracking, and (b) approval to
activate Increment 10 (version bump to `0.2.2` and final no-change proof).
