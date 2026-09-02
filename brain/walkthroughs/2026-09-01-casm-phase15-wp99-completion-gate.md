# Walkthrough: CASM Phase 15 WP99 — Consolidated Completion Gate

Plan: `brain/plans/2026-09-01-casm-phase15-wp99-completion-gate.md`
Taskwarrior: WP99 (task `43`, project `casm.phase15`), parent `41`
Branch: `feature/casm-phase15`

Closes Phase 15 (Conditional Assembly). No new language behaviour — a
fresh *together* re-verification of WP93-98, two deferred fixtures, the
docs, the version promotion to **CASM 0.6.1**, and phase sign-off.

## Change

### Code

- `src/external/casm/casm.s`: `VERSION_STAGE "0"` → `"1"` (0.6.0 →
  0.6.1). Nothing else — `ld65 -m` shows CODE `$3800-$905F`, RODATA
  `$9060-$9D08`, BSS `$9D09-$AAB9` **identical to WP98** (the version
  string is the same length). MAIN headroom `$AC00 - $AAB9` = **327 B**,
  unchanged. `BUILD_CASM` → 1417.

### Fixtures (deferred from WP96)

- `casmifsym` — `.IF 1` defines `GOOD`, used after `.ENDIF`; `.IF 0`
  defines `BAD`, referenced after its `.ENDIF`. One file, one fatal
  outcome: the reference to `GOOD` resolves, then `JMP BAD` →
  `UNDEFINED SYMBOL`. No `.ref` (diagnostic case).
- `casmifp1p2` — a forward reference (`DATA`, after the `.ENDIF`) used
  inside a taken `.IF 1` body. PRG `00 C0 AD 04 C0 EA 60`. Hand-derived
  `casmifp1p2.ref.hex` (in `CASM_REF_NAMES`; `^casmif` already excludes
  it from the test.d64 ref loop).

### Docs

- `docs/casm-utility.md`: new `### Conditional Assembly` section under
  `## Language Reference` (the six directives, truthiness-only + the
  no-comparison-operator divergence and its workaround, `.IFDEF`
  traversal-order semantics + the define-once guard idiom, skipped-block
  rules, 16/512 limits, the five structural diagnostics, `/L`
  blank-address + `/M` non-leak). New "Example 5: Conditional Assembly"
  in Practical Examples. New "Not Yet Supported" bullet for `.IF` /
  `.ASSERT` comparison operators.
- `docs/casm-programmers-reference.md`: header note + a full "Works"
  bullet for Phase 15 (both determinism mechanisms, `cond.s` shape,
  diag range `$5B-$61`); "Not yet implemented" bullet for comparison
  operators.
- `wiki/casm-utility.md`, `wiki/casm-programmers-reference.md`
  re-mirrored (`cp`); `wiki/Home.md` + `wiki/tasks/casm.md` →
  Phase 15 complete at `0.6.1`.
- `CHANGELOG.md`: `## [Unreleased]` → new "CASM conditional assembly
  (Phase 15, WP93-99)" entry.
- `brain/KNOWLEDGE.md`: new "## CASM Phase 15 Complete" section.

## Consolidated re-verification

### Host build (fresh)

- `rm -rf build && cmake -B build && cmake --build build` — **clean, all
  74 targets**, zero warnings/errors.
- `scripts/verify_casm_diag_table.py` — `OK: all 97 diagnostic
  identifiers + 2 extras render exactly the frozen text` (includes
  `$5B-$61`).
- `ld65 -m` envelope: CASM MAIN within `$7400` (327 B headroom).
- No committed `.ref` / `.ref.hex` / `.d64` artifact changed
  (`git status` clean on generated files — ref transcription stable).

### Live VICE — fresh `CASM V0.6.1.1417`

`casm_phase15_test.d64` then `casm_phase13_test.d64`; Command64 booted
each time, FLUSH before/after (`DRIVE 8 STATUS: 00, OK,00,00`), overlay
`test` events fired.

| Fixture | Result |
| --- | --- |
| `TEST_CASM_COND` | `CASM COND: PASS` |
| `casmif1` | P1 5 == P2 5, `00004 BYTES`, `FILES COMPARE OK` |
| `casmif0` | P1 3 == P2 3, `00003 BYTES`, `FILES COMPARE OK` |
| `casmifskip` | P1 3 == P2 3 — the `.IF 0` body's `LDA UNDEFINEDXYZ` / `.WORD NOTASYMBOL` **never evaluated**; `FILES COMPARE OK` |
| `casmelif` | P1 6 == P2 6, `.ELSEIF 1` arm's 3 NOPs, `FILES COMPARE OK` |
| `casmifnest` | P1 7 == P2 7, `00004 BYTES`, `FILES COMPARE OK` |
| `casmifdefguard` | **P1 6 == P2 6** (bitmap replay — naive Pass 2 would skip the first block), `FILES COMPARE OK` |
| `casmifp1p2` (new) | **P1 7 == P2 7**, forward `DATA` → `$C004`, `00007 BYTES`, `FILES COMPARE OK` |
| `casmifsym` (new) | `JMP GOOD` (taken-branch label) resolves; `CASM: UNDEFINED SYMBOL` AT LINE 11 COL 9 on `JMP BAD` (skipped-branch label) — **skipped branch defines nothing** |
| `casmiffwd` | `CASM: .IF CONDITION NOT RESOLVED` AT LINE 2 COL 1 (forward ref in `.IF`) |
| `casmelseelse` | `CASM: .ELSEIF/.ELSE AFTER .ELSE` AT LINE 4 COL 1 |
| `casmifL1` `/L` | `TYPE CASMIFL1.LST`: lines 3-4 (suppressed body) **blank address column**; `.IF 0` / `.ENDIF` (lines 2, 5) and real `NOP` (line 6, `C000 EA`) normal |
| `casmassert1` (no `.if`) | P1 3 == P2 3, `FILES COMPARE OK` — regression witness |
| `casmincbin1` (no `.if`) | P1 2 == P2 2, `00006 BYTES`, `FILES COMPARE OK` — regression witness |

Carried forward from the WP98 session (`CASM V0.6.0.1416` — byte-for-byte
identical code to 1417, only the version string differs): `casmifM1` `/M`
lists `REAL` only, never `SKIPPED`; `casmifdef1` / `casmifndef1` /
`casmifdeffwd` COMP OK; `casmifdefname` → `IFDEF/IFNDEF EXPECTS A NAME`.

No-conditionals byte-identity is also airtight by construction: every
Phase 15 code path is gated behind a conditional directive actually
appearing in the source.

### DASH

`git diff --stat -- src/external/dash/` empty; `dash.ref.hex` unchanged;
the full build regenerated `dash` and the ca65 cross-check `dash_ref`
with no error (the manifest source-hash gate would `FATAL_ERROR` on
drift). No conditional-assembly adoption (WP98 survey).

## Status

Phase 15 (Conditional Assembly) source-complete, fresh-build- and
live-VICE-verified end to end. CASM **0.6.1** build 1417. All six
directives working; both Pass-1==Pass-2 determinism mechanisms proven;
`/L` / `/M` interaction pinned; no-conditionals output byte-identical;
docs + wiki + CHANGELOG + KNOWLEDGE reconciled. Committed.

Requesting **explicit sign-off to close Phase 15**. After sign-off the
`feature/casm-phase15` branch merges to `main` (separate step).
