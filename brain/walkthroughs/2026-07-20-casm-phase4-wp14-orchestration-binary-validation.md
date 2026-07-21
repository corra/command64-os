# CASM Phase 4 WP14 — Orchestration and Binary Validation Walkthrough

- **Date**: 2026-07-21
- **Version**: CASM `0.1.15`, build 1070 (advances to `0.1.16` only at the
  approved WP14 completion gate)
- **Plan**: `brain/plans/2026-07-20-casm-phase4-wp14-orchestration-binary-validation.md`
- **Parent plan**: `brain/plans/2026-07-17-casm-phase4-statement-parser-opcode-table.md`
- **Branch**: `feature/casm-phase4-wp14`

## Scope Delivered

- **Trusted reference infrastructure.** `scripts/hex_manifest_to_bin.py`
  transcribes reviewed hex manifests to binary and verifies declared byte count
  and SHA-256. It contains no 6502 knowledge, so a CASM opcode-table defect
  cannot be reproduced inside its own reference.
- **Reviewed reference manifests.** `tests/fixtures/casm/casmemit1.ref.hex` and
  `casmhello.ref.hex`, hand-assembled from the fixture sources independently of
  CASM, installed on `test.d64` as PRGs for native `COMP`.
- **Production orchestration documented.** The WP13 "temporary driver" was
  audited and found to already implement the full production contract; it was
  documented in place rather than rewritten (see Plan Adherence below).
- **Acceptance-matrix fixtures.** 22 new fixtures covering syntax/delimiter,
  addressing/numeric, PC, and cleanup boundaries.
- **Defect fix.** A bare `.ORG` silently assembled as `.ORG $0000`; `emitOrg`
  now requires `CASM_OPKIND_ABSOLUTE`.

## Plan Adherence and Deviations

**Deviation (approved): no `compiler.s`, and no orchestration rewrite.** The
plan allowed the loop to remain in `casm.s` if the audit proved it cohesive and
bounded. The increment-4 audit went further: the existing driver already
satisfied every clause of the production contract — entry ownership, the
`emitFinalize` → `INPUT VALIDATED` → `sourceClose` → cleanup success ordering,
the registry-owned checked close of the output, `startFatal` → `outputAbort` →
`exitFatal` with the primary diagnostic printed *before* cleanup, exactly-once
handle closing, and a safe `outputAbort` no-op before output creation. So
increment 5 became comment-only: the stale "WP13 temporary driver / WP14
replaces this" framing was replaced with the documented contract. Verified by a
filtered diff showing no changed non-comment line, and by `casm.prg` differing
from the pre-increment baseline in exactly one byte (`$1A45`, the build-number
digit in CASM's own banner).

**Deviation (approved): a defect fix inside WP14.** `casmorg3` exposed that
`.ORG` with no operand parsed as `OPKIND_IMPLIED` with value 0 and `emitOrg`
never inspected OpKind, so the origin became `$0000` with no diagnostic. The
acceptance matrix requires this case to be rejected, so it was fixed rather
than deferred, reusing `CASM_DIAG_SYNTAX_ERROR ($1C)` so the Phase 4 diagnostic
range and its contiguity asserts are untouched. The guard requires
`CASM_OPKIND_ABSOLUTE`, which also rejects `.ORG A`, `.ORG #$10`, `.ORG $10,X`
and `.ORG ($10)` — the same silent-origin class. It runs before the
duplicate-`.ORG` check so a malformed `.ORG` always reports as malformed;
`casmorg2` still reports DUPLICATE ORG.

**Correction carried in:** post-DSC1 MAIN headroom was recorded as 432 bytes;
the measured value after the `cf31a33` fix was 422, and after this WP's
`.ORG` guard it is 408.

## Automated Verification (host, complete)

| Check | Result |
|---|---|
| `casm`, `image_d64`, `test_image_d64` build | pass |
| No-change rebuild preserves `BUILD_CASM` (1070) | pass |
| Reference manifests regenerate byte-identically to build artifacts | pass |
| Converter rejects malformed manifests (8 guard cases) | pass |
| `reloc.py` output byte-identical to `build/casm.prg` | pass |
| Load address `$3400`; `R6` footer present; 11057 bytes; 1172 reloc points | pass |
| `$3400` map: CODE `$3400-$4E40` (`$1A41`), RODATA `$7C0`, BSS `$467`, end `$5A67` | pass |
| `$3500` map: same sizes, end `$5B67`; both within `$2800`, headroom 408 | pass |
| `image.d64`: all 9 shipping apps intact, 464 blocks free | pass |
| `test.d64`: 23 PRG + 57 SEQ, both `.ref` PRGs present, 315 blocks free | pass |
| `git diff --check` | pass |

These checks never execute CASM. The broken `c64-testing` MCP and web emulators
are prohibited.

## Runtime Verification (to be performed by the user)

Attach `build/test.d64`. **Every expected result below is derived from static
reading of `parser.s`/`emit.s`, not from executing CASM.** Record actual results
in the Result column; a mismatch is a finding, not necessarily a fixture error.

### A. Binary equality (the primary WP14 gate)

| Step | Command | Expected | Result |
|---|---|---|---|
| A1 | `CASM CASMEMIT1` | `INPUT VALIDATED`, output `CASMEMIT1.PRG` | |
| A2 | `COMP CASMEMIT1.PRG CASMEMIT1.REF` | files identical | |
| A3 | `CASM CASMHELLO` | `INPUT VALIDATED`, output `CASMHELLO.PRG` | |
| A4 | `COMP CASMHELLO.PRG CASMHELLO.REF` | files identical | |
| A5 | `LOAD"CASMHELLO",8` then `GO 3400` | prints `YES IT BUILDS! -- CASM`, returns to shell | |

> A1–A4 passed on the pre-increment-5 build. They must be re-run here because
> the `.ORG` guard changed `emit.s`.

### B. Positive fixtures (must assemble cleanly)

| Step | Command | Expected | Result |
|---|---|---|---|
| B1 | `CASM CASMCMNT` | `INPUT VALIDATED` (comments/blank lines tolerated) | |
| B2 | `CASM CASMIMM1` | `INPUT VALIDATED` (`#$FF` is the 8-bit max) | |
| B3 | `CASM CASMZP1` | `INPUT VALIDATED` (`$FF` zero-page, `$0100` absolute) | |
| B4 | `CASM CASMZPI1` | `INPUT VALIDATED` (ZP-indirect at `$FF`) | |
| B5 | `CASM CASMBRP1` | `INPUT VALIDATED` (branch +127) | |
| B6 | `CASM CASMBRN1` | `INPUT VALIDATED` (branch −128) | |
| B7 | `CASM CASMPCEND` | `INPUT VALIDATED` (last byte lands on `$FFFF`) | |

### C. Syntax and delimiter diagnostics

| Step | Command | Expected | Result |
|---|---|---|---|
| C1 | `CASM CASMBYTE0` | `SYNTAX ERROR` (empty `.BYTE`) | |
| C2 | `CASM CASMWORD0` | `SYNTAX ERROR` (empty `.WORD`) | |
| C3 | `CASM CASMCMA1` | `SYNTAX ERROR` (leading comma) | |
| C4 | `CASM CASMCMA2` | `SYNTAX ERROR` (doubled comma) | |
| C5 | `CASM CASMCMA3` | `SYNTAX ERROR` (trailing comma) | |
| C6 | `CASM CASMBYRNG` | `OPERAND OUT OF RANGE` (`.BYTE $100`) | |
| C7 | `CASM CASMORG3` | `SYNTAX ERROR` — **the fixed defect**; must NOT succeed | |
| C8 | `CASM CASMORG5` | `SYNTAX ERROR` (`.ORG A`) | |
| C9 | `CASM CASMORG4` | `EXPECTED NEWLINE` (trailing `.ORG` token) | |

### D. Addressing, range, and PC diagnostics

| Step | Command | Expected | Result |
|---|---|---|---|
| D1 | `CASM CASMIMM2` | `OPERAND OUT OF RANGE` (`#$100`) | |
| D2 | `CASM CASMZPI2` | a range or addressing-mode diagnostic — **record which** | |
| D3 | `CASM CASMBRP2` | `BRANCH OUT OF RANGE` (+128) | |
| D4 | `CASM CASMBRN2` | `BRANCH OUT OF RANGE` (−129) | |
| D5 | `CASM CASMPCOVF` | `ADDRESS OVERFLOW` (past `$FFFF`) | |

Each diagnostic should print with its source line and caret (DSC1 behavior).

### E. Cleanup and partial-output deletion

| Step | Command | Expected | Result |
|---|---|---|---|
| E1 | `CASM CASMPART` | `SYNTAX ERROR` after several statements assembled | |
| E2 | `DIR` | **no** `CASMPART.PRG` — the partial output was deleted | |
| E3 | `CASM CASMCMA2` then `DIR` | `SYNTAX ERROR`; no `CASMCMA2.PRG` left behind | |
| E4 | `CASM CASMEMIT1` again, then `COMP` as in A2 | still identical after the failures | |
| E5 | `DIR`, then run another app (e.g. `COMP` with no args), then `CASM CASMEMIT1` | shell intact and CASM still works after every failure | |

### F. CLI options

| Step | Command | Expected | Result |
|---|---|---|---|
| F1 | `CASM CASMEMIT1 /S` | accepted (static is the default output mode) | |
| F2 | `CASM CASMEMIT1 /M` | `NOT IMPLEMENTED`, and `DIR` shows no output left behind | |
| F3 | `CASM CASMEMIT1 /L` | `NOT IMPLEMENTED`, and `DIR` shows no output left behind | |
| F4 | `CASM CASMEMIT1 /O:MYOUT.PRG` then `COMP MYOUT.PRG CASMEMIT1.REF` | identical (explicit `/O` name) | |

## Known Limitations / Follow-ups

- Labels, symbols, expressions, `.STATIC`/`.RELOC`/`.INCLUDE`, `/M`, `/L`, VMM,
  two-pass assembly, and relocation remain out of scope (later phases).
- `casmshort` still reports `SYNTAX ERROR` by design: it ends in
  `JMP START_LABEL` and label operands are deferred.
- `casmwp11` predates emission and has no `.ORG`, so it now reports
  `ORG REQUIRED`. That is expected, not a regression.
- No all-151-opcode certification matrix; that is Phase 11 hardening. A
  per-addressing-mode reference PRG (a `casmmodes.ref`) was considered and not
  added, since the plan names only the two references; it is a candidate
  follow-up that would strengthen opcode coverage considerably.
- MAIN headroom is down to 408 bytes. Future CASM growth has little room before
  the `$2800` envelope needs review.

## Completion

WP14 completes only after every runtime step above is confirmed, the
walkthrough is approved, CASM advances `0.1.15` → `0.1.16`, and the Taskwarrior
UUID `3e4eab43-0f48-4db5-843f-c749bcb79d8a` plus the wiki/brain/CHANGELOG
records agree. WP14 completion does not complete Phase 4; it unblocks WP15.
